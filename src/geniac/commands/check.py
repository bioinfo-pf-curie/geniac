#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""check.py: Linter command for geniac"""

import logging
import re
import subprocess
from pathlib import Path

from ..commands.base import GCommand
from ..parsers.config import NextflowConfig
from ..parsers.scripts import NextflowScript

__author__ = "Fabrice Allain"
__copyright__ = "Institut Curie 2020"

_logger = logging.getLogger(__name__)


class GCheck(GCommand):
    """Linter command for geniac"""

    CONDA_RECIPES_RE = re.compile(
        r"(?P<recipes>(([\w-]+::[\w-]+==?[\d.]+==?[\w]+) ?)+)"
    )
    CONDA_PATH_RE = re.compile(
        r"(?P<nxfvar>\${(baseDir|projectDir)})/(?P<basepath>[/\w]+\.(?P<ext>yml|yaml))"
    )
    MODULE_CMAKE_RE_TEMP = (
        r"ExternalProject_Add\(\s*{label}[\s\w_${{}}\-/=]*SOURCE_"
        r"DIR +\$\{{pipeline_source_dir\}}/modules/{label}"
    )

    # Name of config sections used in this class
    TREE_SUFFIX = "tree"
    PROJECT_CONFIG = "project.config"
    PROJECT_WORKFLOW = "project.workflow"
    GENIAC_FLAGS = "geniac.flags"
    GENIAC_DIRS = "geniac.directories"
    GENIAC_CONFIG_FILES = "geniac.generated.config"

    def __init__(self, project_dir, *args, **kwargs):
        """Init flags specific to GCheck command"""
        super().__init__(*args, project_dir=project_dir, **kwargs)
        self._project_tree = self._format_tree_config()

    @property
    def project_tree(self):
        """Formatted tree configuration"""
        return self._project_tree

    def _format_tree_config(self):
        """Format configuration tree from ini config

        Returns:
            config_tree (dict)
        """
        config_tree = {
            tree_section.removeprefix(self.TREE_SUFFIX + "."): {
                # Is the folder required ?
                "required": self.config.getboolean(tree_section, "required")
                if self.config.has_option(tree_section, "required")
                else False,
                # Is the folder recommended ?
                "recommended": self.config.getboolean(tree_section, "recommended")
                if self.config.has_option(tree_section, "recommended")
                else False,
                # Path to the folder
                "path": Path(self.config.get(tree_section, "path"))
                if self.config.get(tree_section, "path")
                else Path(Path.cwd()),
                # Path(s) to mandatory file(s)
                "required_files": self.config_path(tree_section, "files"),
                # Path(s) to optional file(s)
                "optional_files": self.config_path(tree_section, "optional"),
                # Path(s) to file(s) excluded from the analysis
                "excluded_files": self.config_path(tree_section, "exclude"),
            }
            for tree_section in self.config_subsection(self.TREE_SUFFIX)
        }
        return {
            tree_section: {
                # Get a list all the files in the folder
                "current_files": (
                    [
                        _
                        for _ in config_tree.get(tree_section).get("path").iterdir()
                        if _ not in config_tree.get(tree_section).get("excluded_files")
                    ]
                    if config_tree.get(tree_section).get("path").exists()
                    else []
                ),
                **section,
            }
            for tree_section, section in config_tree.items()
        }

    def check_tree_folder(self):
        """Check the directory in order to set the flags"""
        _logger.info("Check tree folder")

        # TODO: rewrite get_sections to have a nested dict instead of a list
        _logger.debug(f"Sections parsed from config file: {self.config.sections()}")

        for tree_section, section in self.project_tree.items():
            [_logger.debug(msg) for msg in ("\n", f"SECTION {tree_section}")]

            required = section.get("required")
            recommended = section.get("recommended")
            path = section.get("path")
            required_files = section.get("required_files")
            optional_files = section.get("optional_files")
            current_files = section.get("current_files")

            [
                _logger.debug(msg)
                for msg in (
                    f"required: {required}",
                    f"path: {path}",
                    f"expected files: {required_files}",
                    f"optional files: {optional_files}",
                    f"excluded files: {section.get('excluded_files')}",
                    f"current files: {current_files}",
                )
            ]

            # If folder exists and is not empty (excluded files are ignored)
            if required and not path.exists():
                _logger.error(
                    f"Directory {path.name} does not exist. Add it to you project if "
                    f"you want your workflow to be compatible with geniac tools"
                )
            elif recommended and not path.exists():
                _logger.warning(
                    f"Directory {path.name} does not exist. It is recommended to have "
                    f"one"
                )

            # Trigger an error or warning for each required or optional files in the
            # current section
            for file in current_files:
                if not file.exists():
                    if required and file in required_files:
                        # TODO: if config folder check if the file has been included in
                        #  nextflow.config
                        # Trigger an error if a mandatory file is missing
                        _logger.error(
                            f"File {file.name} is missing. Add it to you project if you"
                            f" want to be compatible with geniac tools"
                        )
                    elif file in optional_files:
                        # Trigger a warning if an optional file is missing
                        _logger.warning(
                            f"Optional file {file.name} does not exist: it is "
                            f"recommended to have one"
                        )

    def get_processes_from_workflow(self):
        """Parse workflow file(s)

        Returns:
            labels_from_main (dict): dictionary of processes in the main nextflow file
        """
        script = NextflowScript()

        # Link config path to their method
        script_paths = {
            config_key: self.config_path(
                GCheck.PROJECT_WORKFLOW, config_key, single_path=True
            )
            for config_key in self.config.options(GCheck.PROJECT_WORKFLOW)
        }

        # TODO: Check for DSL 2 support
        for script_name, script_path in script_paths.items():
            if script_path.exists():
                script.read(script_path)
            else:
                _logger.error(f"Worfklow script {script_path} does not exists")

        # Check if there is processes without label in the actual workflow
        # fmt: off
        for process in (processes := script.content.get("process")):
            if not processes.get(process).get("label"):
                _logger.error(f"Process {process} does not have any label")
        # fmt: on

        return script.content.get("process", {})

    def check_geniac_config(
        self,
        config: NextflowConfig,
        conda_check: bool = True,
        **kwargs,
    ):
        """Check the content of params scope in a geniac config file

        Args:
            conda_check:
            config: Nextflow config object

        Returns:
            labels_geniac_tools (list): list of geniac tool labels in params.geniac.tools
        """
        labels_geniac_tools = []

        # Check parameters according to their default values
        config.check_config_scope("params")

        # Check if conda command exists
        if subprocess.run(["conda", "-h"], capture_output=True).returncode != 0:
            _logger.error(
                "Conda is not available in your path. Geniac will not check if tool recipes are correct"
            )
            conda_check = False

        # Check each label in params.geniac.tools
        if conda_check:
            _logger.info("Checking conda recipes in params.geniac.tools")
            for label, recipe in config.get("params.geniac.tools").items():
                labels_geniac_tools.append(label)
                # If the tool value is a conda recipe
                if match := GCheck.CONDA_RECIPES_RE.match(recipe):
                    # The related recipe is a correct conda recipe
                    # Check if the recipes exists in the actual OS with conda search
                    for conda_recipe in match.groupdict().get("recipes").split(" "):
                        conda_search = subprocess.run(
                            ["conda", "search", conda_recipe], capture_output=True
                        )
                        if conda_search and (conda_search.returncode != 0):
                            _logger.error(
                                f"Conda recipe {conda_recipe} for the tool {label} "
                                f"does not link to an existing package or build. "
                                f"Check if the requested build is still available on "
                                f"conda:\n\t> conda search {conda_recipe}"
                            )
                # Elif the tool value is a path to an environment file (yml or yaml ext),
                # check if the path exists
                elif match := GCheck.CONDA_PATH_RE.match(recipe):
                    if (
                        conda_path := Path(
                            self.project_dir / match.groupdict().get("basepath")
                        )
                    ) and not conda_path.exists():
                        _logger.warning(
                            f"Conda file {conda_path} related to {label} tool does not exists."
                        )
                # else check if it's a valid path
                else:
                    _logger.error(
                        f"Value {recipe} of {label} tool does not look like a valid conda file or recipe"
                    )
        else:
            _logger.info("Checking of conda recipes turned off")

        for extra_section in (
            "params.geniac.containers.yum",
            "params.geniac.containers.git",
        ):
            if x_section := config.get(extra_section):
                # For each label in yum or git scope
                for label in x_section:
                    # If label is not present in geniac.tools
                    if label not in labels_geniac_tools:
                        _logger.error(
                            f"Label {label} of {extra_section} is not defined in params.geniac.tools"
                        )
            else:
                _logger.warning(
                    f"Section {extra_section} is not defined in params.geniac.tools"
                )

        return labels_geniac_tools

    def check_process_config(
        self,
        config: NextflowConfig,
        processes_from_workflow: dict = None,
        **kwargs,
    ):
        """Check the content of a process config file

        Args:
            config: Nextflow config object
            processes_from_workflow: dict of processes names associated with their labels

        Returns:
            labels_process (list): list of process labels in params.process with withName
        """
        # Check parameters according to their default values
        config.check_config_scope("process")

        # For each process used with withName selector, check their existence in the
        # workflow
        for config_process in config.get("process", {}).get("withName"):
            if config_process not in processes_from_workflow:
                _logger.error(
                    f"Process {config_process} used with the withName selector in "
                    f"{config.path} does not correspond to any process in the workflow."
                )

        # Return list of labels defined with withLabel selector in the process.config file
        return [
            process_label
            for process_label in config.get("process", {}).get("withLabel")
        ]

    def check_nextflow_config(
        self,
        nxf_config: NextflowConfig,
        default_config_paths: list = (),
        default_geniac_files_paths: list = (),
        **kwargs,
    ):
        """Check the content of a nextflow config file

        Args:
            default_geniac_files_paths:
            nxf_config (NextflowConfig):
            default_config_paths (list):

        Returns:

        """
        include_config_paths = [
            self.project_dir / Path(include_path)
            for include_path in nxf_config.get("includeConfig")
        ]
        profile_config_paths = [
            self.project_dir / Path(conf_path)
            for conf_profile in nxf_config.get("profiles", {})
            for conf_path in nxf_config.get("profiles", {})
            .get(conf_profile)
            .get("includeConfig")
        ]
        for default_config_path in default_config_paths:
            # We do not check if the path corresponds to nextflow.config path
            # Check if config files are included
            if (
                default_config_path != nxf_config.path
                and Path(default_config_path) not in include_config_paths
            ):
                _logger.error(
                    f"Nextflow configuration file {nxf_config.path} does not include {default_config_path}"
                )

        # Check if geniac config profiles are included
        for geniac_file in default_geniac_files_paths:
            if Path(geniac_file) not in profile_config_paths:
                _logger.error(
                    f"Nextflow configuration file {nxf_config.path} does not "
                    f"include {geniac_file} within profiles"
                )

    def get_labels_from_config_files(self, processes_from_workflow: dict):
        """Check the structure of the repo

        Args:
            processes_from_workflow: dict of processes names associated with their labels

        Returns:
            labels_geniac_tools (list): list of geniac tool labels in params.geniac.tools
            labels_process (list): list of process labels in params.process with withName
        """
        nxf_config = NextflowConfig()

        labels = {}
        # Link config path to their method
        default_config_scopes = {
            default_config_name: {
                "path": self.config_path(
                    GCheck.PROJECT_CONFIG, default_config_name, single_path=True
                ),
                "check_config": getattr(
                    self, f"check_{default_config_name}_config", None
                ),
            }
            for default_config_name in self.config.options(GCheck.PROJECT_CONFIG)
        }

        # get labels from geniac.config
        default_config_paths = [
            default_config_scopes[config_scope]["path"]
            for config_scope in default_config_scopes
        ]

        default_geniac_files_paths = [
            self.config_path(
                GCheck.GENIAC_CONFIG_FILES, geniac_config_file, single_path=True
            )
            for geniac_config_file in self.config.options(GCheck.GENIAC_CONFIG_FILES)
        ]

        for config_key, default_config_scope in default_config_scopes.items():
            default_config_path = default_config_scope["path"]
            config_method = default_config_scope["check_config"]
            if not default_config_path.exists():
                _logger.error(
                    f"Nextflow config file {default_config_path} does not exists"
                )
                continue
            nxf_config.read(default_config_path)
            if config_method:
                _logger.info(
                    f"Checking Nextflow configuration file {default_config_path}"
                )
                labels[config_key] = config_method(
                    nxf_config,
                    default_config_paths=default_config_paths,
                    default_geniac_files_paths=default_geniac_files_paths,
                    processes_from_workflow=processes_from_workflow,
                    conda_check=self.config.getboolean(self.GENIAC_FLAGS, "condaCheck"),
                )

        return labels

    def get_labels_from_modules_dir(self, input_dir: Path):
        """Get geniac labels from modules directory"""
        labels_from_modules = {"modules": []}
        cmake_lists = input_dir / "CMakeLists.txt"
        if not input_dir.exists():
            return []
        elif not cmake_lists.exists():
            # TODO: initialize CmakeLists.txt from the template ?
            _logger.error(
                "Folder modules requires a CMakeLists.txt file in order to have the "
                "container automatically built."
            )
            return []

        with open(cmake_lists) as cmake_file:
            cmake_lists_content = cmake_file.read()

        for module_child in input_dir.iterdir():
            # If child correspond to a folder and the name of this folder is linked to
            # an existing bash script
            label_script = (module_child.parent / module_child.stem).with_suffix(".sh")
            if module_child.is_dir():
                _logger.debug(f"Found module directory with label {module_child.stem}")
                # Parse the CMakeLists.txt file to see if the label is correctly defined
                label_reg = re.compile(
                    GCheck.MODULE_CMAKE_RE_TEMP.format(label=module_child.stem)
                )
                if label_reg.search(cmake_lists_content):
                    _logger.debug(f"Found module {module_child.stem} in {cmake_lists}")
                else:
                    _logger.error(
                        f"Module {module_child.stem} not found in {cmake_lists}"
                    )

                if not label_script.exists():
                    _logger.error(
                        f"Module {module_child.stem} does not have an "
                        f"installation script ({label_script})"
                    )
                else:
                    labels_from_modules["modules"] += [module_child.stem]

        return labels_from_modules

    # TODO
    def get_labels_from_recipes_dir(self, input_dir):
        """Get geniac labels from conda, singularity and docker recipes"""
        labels_from_recipes = {}

        for recipe_child in input_dir.iterdir():
            pass

        return labels_from_recipes

    # TODO
    def check_dependencies_dir(self, dependencies_dir: Path):
        """

        Args:
            dependencies_dir:

        Returns:

        """
        pass

    # TODO
    def check_env_dir(self, env_dir: Path):
        """

        Args:
            env_dir:

        Returns:

        """
        pass

    # TODO
    def get_labels_from_folders(self, modules_dir, recipes_dir):
        """Parse information from recipes and modules folders

        Args:
            modules_dir:
            recipes_dir:

        Returns:
            labels_from_folders(list): list of tools related to modules, conda, singularity and docker files
        """
        labels_from_folders = {}
        geniac_dirs = {
            geniac_dir: {
                "path": self.config_path(
                    GCheck.GENIAC_DIRS, geniac_dir, single_path=True
                ),
                "get_labels": getattr(self, f"get_labels_from_{geniac_dir}_dir", None),
                "check_dir": getattr(self, f"check_{geniac_dir}_dir", None),
            }
            for geniac_dir in self.config.options(GCheck.GENIAC_DIRS)
        }
        for geniac_dirname, geniac_dir in geniac_dirs.items():
            if not geniac_dir.get("path").exists():
                _logger.error(f"Folder {geniac_dir.get('path')} does not exists")
                continue
            if check_dir := geniac_dir.get("check_dir"):
                check_dir(geniac_dir.get("path"))
            if get_label := geniac_dir.get("get_labels"):
                labels_from_folders |= get_label(geniac_dir.get("path"))

        return labels_from_folders

    # TODO
    def check_labels(
        self,
        processes_from_workflow: dict,
        labels_from_configs: dict,
        labels_from_folders: dict,
    ):
        """Check lab

        Args:
            processes_from_workflow:
            labels_from_configs:
            labels_from_folders:
        """
        pass

    def run(self):
        """Execute the main routine

        Returns:

        """

        # Check directory and setup directory flags
        self.check_tree_folder()

        # Get list of labels from main nextflow script
        processes_from_workflow = self.get_processes_from_workflow()

        # Get list of labels from project.config and geniac.config files
        labels_from_configs = self.get_labels_from_config_files(processes_from_workflow)

        # Get labels from folders
        labels_from_folders = self.get_labels_from_folders(
            self.config_path(GCheck.GENIAC_DIRS, "modules", single_path=True),
            self.config_path(GCheck.GENIAC_DIRS, "recipes", single_path=True),
        )

        # Check if there is any inconsistency between the labels from configuration
        # files and the main script
        self.check_labels(
            processes_from_workflow,
            labels_from_configs,
            labels_from_folders,
        )
