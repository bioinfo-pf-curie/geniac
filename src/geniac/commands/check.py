#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""check.py: Linter command for geniac"""

import logging
import re
import subprocess
import sys
from collections import OrderedDict
from pathlib import Path

from geniac.commands.base import GCommand
from geniac.parsers.base import DEFAULT_ENCODING
from geniac.parsers.config import NextflowConfig
from geniac.parsers.scripts import NextflowScript

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
        r"DIR +(\$\{{pipeline_source_dir\}}/modules/fromSource|\$\{{CMAKE_CURRENT_SOURCE_DIR\}})/{label}"
    )
    SINGULARITY_DEP_RE_TEMP = r"\%files\s+{dependency} [\/\w.]+{dependency}"
    DOCKER_DEP_RE_TEMP = r"ADD +{dependency} [\/\w.]+{dependency}"

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
        self._labels_from_folders = OrderedDict()
        self._labels_from_configs = OrderedDict()
        self._processes_from_workflow = OrderedDict()
        self._labels_from_workflow = []
        self._labels_all = []

    @property
    def project_tree(self):
        """Formatted tree configuration"""
        return self._project_tree

    @property
    def labels_from_folders(self):
        """Geniac labels from Nextflow folders"""
        return self._labels_from_folders

    @labels_from_folders.setter
    def labels_from_folders(self, value: dict):
        """Merge geniac labels from Nextflow folders"""
        self._labels_from_folders |= value

    @property
    def labels_from_configs(self):
        """Geniac labels from Nextflow configs"""
        return self._labels_from_configs

    @labels_from_configs.setter
    def labels_from_configs(self, value: dict):
        """Merge geniac labels from Nextflow configs"""
        self._labels_from_configs |= value

    @property
    def labels_from_geniac_config(self):
        """Geniac labels from Nextflow folders"""
        return list(
            dict.fromkeys(
                list(self.labels_from_configs.get("geniac", []))
            )
        )

    @property
    def labels_from_process_config(self):
        """Process config labels from Nextflow folders"""
        return list(
            dict.fromkeys(
                list(self.labels_from_configs.get("process", []))
            )
        )

    @property
    def processes_from_workflow(self):
        """Workflow labels from Nextflow folders"""
        return self._processes_from_workflow

    @processes_from_workflow.setter
    def processes_from_workflow(self, value: dict):
        """Merge geniac labels from Nextflow configs"""
        self._processes_from_workflow |= value

    @property
    def labels_from_workflow(self):
        """Workflow labels from Nextflow folders"""
        # Init labels list if empty
        labels = list(
            dict.fromkeys(
                [
                    label
                    for process, process_scope in self.processes_from_workflow.items()
                    for label in process_scope["label"]
                    if label is not None
                ]
            )
        )
        self._labels_from_workflow += set(labels + self._labels_from_workflow)
        return self._labels_from_workflow

    @property
    def labels_all(self):
        """Gather labels from Nextflow folders and geniac tools"""
        # Init labels all if empty
        if not self._labels_all:
            self._labels_all = list(
                dict.fromkeys(
                    [
                        label
                        for folder, labels in self.labels_from_folders.items()
                        for label in labels
                    ]
                    + self.labels_from_geniac_config
                    + ["onlyLinux"]
                )
            )
        return self._labels_all

    @staticmethod
    def _get_current_files(config_tree: dict, tree_section: str):
        """
        Get current file list from a specific section

        Args:
            config_tree:
            section:

        Returns:

        """
        dir_path = config_tree.get(tree_section).get("path")
        recursive_flag = config_tree.get(tree_section).get("recursive")
        excluded_files = config_tree.get(tree_section).get("excluded_files")
        _logger.debug("Browse current files in %s directory%s",
                      dir_path, " recursively" if recursive_flag else "")
        if dir_path.exists():
            return [
                _ for _ in dir_path.glob("**/*" if recursive_flag else "*")
                if _ not in excluded_files and not _.is_dir()
            ]
        else:
            return ()

    def _format_tree_config(self):
        """Format configuration tree from ini config

        Returns:
            config_tree (dict)
        """
        config_tree = OrderedDict(
            (
                tree_section.removeprefix(self.TREE_SUFFIX + "."),
                {
                    # Is the folder required ?
                    "required": self.config.getboolean(tree_section, "required")
                    if self.config.has_option(tree_section, "required")
                    else False,
                    # Is the folder recommended ?
                    "recommended": self.config.getboolean(tree_section, "recommended")
                    if self.config.has_option(tree_section, "recommended")
                    else False,
                    # Should we analyze files and sub directories recursively ?
                    "recursive": self.config.getboolean(tree_section, "recursive")
                    if self.config.has_option(tree_section, "recursive")
                    else False,
                    # Path to the folder
                    "path": Path(self.config.get(tree_section, "path"))
                    if self.config.get(tree_section, "path")
                    else Path(Path.cwd()),
                    # Path(s) to mandatory file(s)
                    "required_files": self.config_path(tree_section, "mandatory"),
                    # Path(s) to optional file(s)
                    "optional_files": self.config_path(tree_section, "optional"),
                    # Path(s) to file(s) excluded from the analysis
                    "excluded_files": self.config_path(tree_section, "exclude"),
                    # Path(s) to file(s) excluded from the analysis
                    "prohibited_files": self.config_path(tree_section, "prohibit"),
                },
            )
            for tree_section in self.config_subsection(self.TREE_SUFFIX)
        )
        return OrderedDict(
            (
                tree_section,
                {
                    # Get a list all the files in the folder
                    "current_files": (
                        self._get_current_files(config_tree, tree_section)
                    ),
                    **section,
                },
            )
            for tree_section, section in config_tree.items()
        )

    def check_tree_folder(self):
        """Check the directory in order to set the flags"""
        _logger.info("Checking tree structure of %s.", self.project_dir)
        _logger.debug("Sections parsed from config file: %s.", self.config.sections())

        for tree_section, section in self.project_tree.items():
            for msg in ("\n", f"Folder {tree_section}"):
                _logger.debug(msg)

            # Is the actual folder required
            required = section.get("required")
            # Is the actual folder recommended
            recommended = section.get("recommended")
            # Path to the sub directory analyzed
            path = section.get("path")
            # List of required files requested in configuration file(s)
            required_files = section.get("required_files")
            # List of optional files requested in configuration file(s)
            optional_files = section.get("optional_files")
            # List of files actually present in the directory
            current_files = section.get("current_files")

            for msg in (
                f"required: {required}",
                f"path: {path}",
                f"expected files: {required_files}",
                f"optional files: {optional_files}",
                f"excluded files: {section.get('excluded_files')}",
                f"current files: {current_files}",
            ):
                _logger.debug(msg)

            # If folder exists and is not empty (excluded files are ignored)
            if path:
                if required and not path.exists():
                    _logger.error(
                        "Directory %s does not exist. Add it to your project if you want your "
                        "workflow to be compatible with geniac tools.",
                        path.relative_to(self.project_dir)
                    )
                elif recommended and not path.exists():
                    _logger.warning(
                        "Directory %s does not exist. It is recommended to have one in your "
                        "project.", path.relative_to(self.project_dir)
                    )

            # Trigger an error if a mandatory file is missing
            for file in required_files:
                # If the folder is actually required but the required file is not
                # present or if the folder is recommended and non empty
                if (required or (recommended and current_files)) and (
                    file not in current_files
                ):
                    _logger.error(
                        "File %s is missing. Add it to your project if you want to be compatible "
                        "with geniac.", file.relative_to(self.project_dir)
                    )

            # Trigger a warning if an optional file is missing
            for file in optional_files:
                # If the folder is actually required but the optional file is not
                # present
                if required and file not in current_files:
                    _logger.warning(
                        "Optional file %s does not exist. It is recommended to have one in your "
                        "project.", file.relative_to(self.project_dir)
                    )

    def get_processes_from_workflow(self):
        """Parse workflow file(s)

        Returns:
            labels_from_main (dict): dictionary of processes in the main nextflow file
        """
        script = NextflowScript(project_dir=self.project_dir)

        geniac_dir = self.project_tree.get("geniac").get("path")

        # Link config path to their method
        script_paths = OrderedDict(
            (
                f"{config_key}_{index}",
                path,
            )
            for config_key in self.config.options(GCheck.PROJECT_WORKFLOW)
            for index, path in enumerate(
                self.config_path(GCheck.PROJECT_WORKFLOW, config_key)
            )
            if not path.is_relative_to(geniac_dir)
        )

        for _, script_path in script_paths.items():
            if script_path.exists():
                script.read(script_path)
            else:
                _logger.error(
                    "Workflow script %s does not exist.",
                    script_path.relative_to(self.project_dir)
                )

        # Check if there is processes without label in the actual workflow
        # fmt: off
        for process in (processes := script.content.get("process")):
            if not processes.get(process).get("label"):
                process_path = Path(
                    processes.get(process).get('NextflowScriptPath')
                ).relative_to(self.project_dir)
                _logger.error(
                    "Process %s in %s does not have any label.",
                    process, process_path
                )
        # fmt: on

        self.processes_from_workflow = script.content.get("process", OrderedDict())

    def _check_geniac_config(
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
                "Conda is not available in your path. Geniac will not check if tool "
                "recipes are correct."
            )
            conda_check = False

        # Check each label in params.geniac.tools
        _logger.info(
            "Checking conda recipes in params.geniac.tools."
            if conda_check
            else "Checking of conda recipes turned off."
        )
        for label, recipe in config.get("params.geniac.tools", OrderedDict()).items():
            labels_geniac_tools.append(label)
            # If the tool value is a conda recipe
            if match := GCheck.CONDA_RECIPES_RE.match(recipe):
                if not conda_check:
                    continue
                # The related recipe is a correct conda recipe
                # Check if the recipes exists in the actual OS with conda search
                for conda_recipe in match.groupdict().get("recipes").split(" "):
                    conda_search = subprocess.run(
                        ["conda", "search", conda_recipe], capture_output=True
                    )
                    if conda_search and (conda_search.returncode != 0):
                        _logger.error(
                            "Conda search command returned non-zero exit status for the recipe "
                            "%s[%s]. Either conda is not available or the recipe does not link "
                            "to an existing package or build. Check if the requested build is "
                            "still available on conda with the following command:"
                            "\n\t> conda search %s.",
                            conda_recipe, label, conda_recipe
                        )
            # Elif the tool value is a path to an environment file (yml or yaml ext),
            # check if the path exists
            elif match := GCheck.CONDA_PATH_RE.search(recipe):
                if (
                    conda_path := Path(
                        self.project_dir / match.groupdict().get("basepath")
                    )
                ) and not conda_path.exists():
                    _logger.error(
                        "Conda file %s related to %s tool does not exist.",
                        conda_path.relative_to(self.project_dir), label
                    )
            # else check if it's a valid path
            else:
                _logger.error(
                    "Value %s of %s tool does not follow the pattern "
                    '"condaChannelName::softName=version=buildString".', recipe, label
                )

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
                            "Label %s of %s is not defined in params.geniac.tools.",
                            label, extra_section
                        )

        return labels_geniac_tools

    def _check_process_config(
        self,
        config: NextflowConfig,
        **kwargs,
    ):
        """Check the content of a process config file

        Args:
            config: Nextflow config object

        Returns:
            labels_process (list): list of process labels in params.process with withName
        """
        # Check parameters according to their default values
        config.check_config_scope("process")

        # For each process used with withName selector, check their existence in the
        # workflow
        for config_process in config.get("process", OrderedDict()).get(
            "withName", OrderedDict()
        ):
            if config_process not in self.processes_from_workflow:
                _logger.error(
                    "withName:%s is defined in %s file but the process %s is not used anywhere.",
                    config_process, config.path.relative_to(self.project_dir), config_process
                )

        # Return list of labels defined with withLabel selector in the process.config file
        return list(config.get("process", OrderedDict()).get("withLabel"))

    def _check_nextflow_config(
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
            for conf_profile in nxf_config.get("profiles", OrderedDict())
            for conf_path in nxf_config.get("profiles", OrderedDict())
            .get(conf_profile, {})
            .get("includeConfig", {})
        ]
        for default_config_path in default_config_paths + default_geniac_files_paths:
            # We do not check if the path corresponds to nextflow.config path
            # Check if config files are included
            if default_config_path != nxf_config.path and (
                default_config_path not in include_config_paths + profile_config_paths
            ):
                msg = (
                    f"Main configuration file "
                    f"{nxf_config.path.relative_to(self.project_dir)} does not "
                    f"include configuration file "
                    f"{default_config_path.relative_to(self.project_dir)}."
                )
                # Trigger a warning if optional file. Otherwise trigger an error
                if default_config_path in self.config_path(
                        ".".join([GCheck.TREE_SUFFIX, "conf"]), "optional"):
                    _logger.warning(msg)
                else:
                    _logger.error(msg)

    @staticmethod
    def _check_base_config(
        nxf_config: NextflowConfig,
        **kwargs,
    ):
        """Check the content of a base config file

        Args:
            nxf_config (NextflowConfig):

        Returns:

        """
        nxf_config.check_config_scope("params", skip_nested_scopes=["geniac"])

    def get_labels_from_config_files(self):
        """Check the structure of the repo

        Returns:
            labels_geniac_tools (list): list of geniac tool labels in params.geniac.tools
            labels_process (list): list of process labels in params.process with withName
        """
        nxf_config = NextflowConfig(project_dir=self.project_dir)

        # Link config path to their method
        project_config_scopes = OrderedDict(
            (
                default_config_name,
                {
                    "path": self.config_path(
                        GCheck.PROJECT_CONFIG, default_config_name, single_path=True
                    ),
                    "check_config": getattr(
                        self, f"_check_{default_config_name}_config", None
                    ),
                },
            )
            for default_config_name in self.config.options(GCheck.PROJECT_CONFIG)
        )

        # Configuration files analyzed
        project_config_paths = [
            project_config_scopes[config_scope]["path"]
            for config_scope in project_config_scopes
        ]

        # Configuration files generated by geniac
        generated_geniac_config_paths = [
            self.config_path(
                GCheck.GENIAC_CONFIG_FILES, geniac_config_file, single_path=True
            )
            for geniac_config_file in self.config.options(GCheck.GENIAC_CONFIG_FILES)
        ]

        for config_key, project_config_scope in project_config_scopes.items():
            project_config_path = project_config_scope["path"]
            config_method = project_config_scope["check_config"]
            default_config_paths = (
                self.config_path(".".join([GCheck.TREE_SUFFIX, "conf"]), "mandatory")
                + self.config_path(".".join([GCheck.TREE_SUFFIX, "conf"]), "optional")
                + self.config_path(".".join([GCheck.TREE_SUFFIX, "base"]), "mandatory")
                + self.config_path(".".join([GCheck.TREE_SUFFIX, "base"]), "optional")
            )
            # If the project config file does not exists and does not belong to default
            # geniac files
            if not project_config_path.exists():
                if project_config_path not in default_config_paths:
                    _logger.error(
                        "Nextflow config file %s does not exist.",
                        project_config_path.relative_to(self.project_dir)
                    )
                continue
            nxf_config.read(project_config_path)
            if config_method:
                _logger.info(
                    "Checking Nextflow configuration file. %s",
                    project_config_path.relative_to(self.project_dir)
                )
                self.labels_from_configs[config_key] = config_method(
                    nxf_config,
                    default_config_paths=project_config_paths,
                    default_geniac_files_paths=generated_geniac_config_paths,
                    conda_check=self.config.getboolean(self.GENIAC_FLAGS, "condaCheck"),
                )

    def _get_labels_from_modules_dir(self, input_dir: Path):
        """Get geniac labels from modules directory"""
        labels_from_modules = []
        main_cmake_lists = input_dir / "CMakeLists.txt"
        if not main_cmake_lists.exists():
            # Output an error if module directory is not empty
            if any(input_dir.iterdir()):
                _logger.error(
                    "Folder %s requires a CMakeLists.txt file in order to automatically "
                    "build containers.", input_dir.relative_to(self.project_dir)
                )
            return []

        with open(main_cmake_lists, encoding=DEFAULT_ENCODING) as cmake_file:
            main_cmake_lists_content = cmake_file.read()

        for module_child in input_dir.iterdir():
            # If child correspond to a folder and the name of this folder is linked to
            # an existing bash script
            if module_child.is_dir():
                _logger.debug("Found module directory with label %s.", module_child.stem)
                # Parse the CMakeLists.txt file to see if the label is correctly defined
                label_reg = re.compile(
                    GCheck.MODULE_CMAKE_RE_TEMP.format(label=module_child.stem)
                )
                # First look if the is correctly added within the main CMakeLists.txt file
                if label_reg.search(main_cmake_lists_content):
                    labels_from_modules += [module_child.stem]
                    _logger.debug(
                        "Module %s correctly added within %s.",
                        module_child.stem, main_cmake_lists.relative_to(self.project_dir)
                    )
                else:
                    _logger.error(
                        "Module %s not added with ExternalProject_Add directive within %s file.",
                        module_child.stem, main_cmake_lists.relative_to(self.project_dir)
                    )
                # Then look in the CMakeLists.txt file of the actual module
                # TODO

        return OrderedDict([("modules", labels_from_modules)])

    @staticmethod
    def _get_labels_from_conda_dir(input_dir):
        """Get geniac labels from conda, singularity and docker recipes"""
        labels_from_recipes = []

        for recipe_child in input_dir.iterdir():
            if recipe_child.is_file() and recipe_child.suffix in (".yml", ".yaml"):
                labels_from_recipes += [recipe_child.stem]

        return OrderedDict([("conda", labels_from_recipes)])

    @staticmethod
    def _get_labels_from_singularity_dir(input_dir):
        """Get geniac labels from conda, singularity and docker recipes"""
        labels_from_recipes = []

        for recipe_child in input_dir.iterdir():
            if recipe_child.is_file() and recipe_child.suffix == ".def":
                labels_from_recipes += [recipe_child.stem]

        return OrderedDict([("singularity", labels_from_recipes)])

    @staticmethod
    def _get_labels_from_docker_dir(input_dir):
        """Get geniac labels from conda, singularity and docker recipes"""
        labels_from_recipes = []

        for recipe_child in input_dir.iterdir():
            if recipe_child.is_file() and recipe_child.suffix == ".Dockerfile":
                labels_from_recipes += [recipe_child.stem]

        return OrderedDict([("docker", labels_from_recipes)])

    def _check_dependencies_dir(
        self,
        dependencies_tree: dict,
        docker_tree: dict = None,
        singularity_tree: dict = None,
        **kwargs,
    ):
        """

        Args:
            dependency_tree:
            singularity_path:
            docker_path:

        Returns:

        """
        for dependency_path in tree.get("current_files", []):
            singularity_flag = False
            docker_flag = False

            # Check if the file is used in singularity files
            if singularity_path:
                for singularity_path in singularity_path.iterdir():
                    if singularity_path.suffix == ".def":
                        dependency_reg = re.compile(
                            GCheck.SINGULARITY_DEP_RE_TEMP.format(
                                dependency=dependency_path.name
                            )
                        )
                        with open(singularity_path) as singularity_file:
                            singularity_flag = (
                                True
                                if dependency_reg.search(singularity_file.read())
                                else singularity_flag
                            )

            # Check if the file is used in docker files
            if docker_path:
                for docker_path in docker_path.iterdir():
                    if docker_path.suffix == ".Dockerfile":
                        dependency_reg = re.compile(
                            GCheck.DOCKER_DEP_RE_TEMP.format(
                                dependency=dependency_path.name
                            )
                        )
                        with open(docker_path) as docker_file:
                            docker_flag = (
                                True
                                if dependency_reg.search(docker_file.read())
                                else docker_flag
                            )

            if not singularity_flag:
                _logger.warning(
                    f"Dependency file {dependency_path.name} not used in "
                    f"singularity definition file {singularity_path.relative_to(self.project_dir)}."
                )
            if not docker_flag:
                _logger.warning(
                    f"Dependency file {dependency_path.name} not used in "
                    f"docker definition files {docker_path.relative_to(self.project_dir)}."
                )

    def _check_env_dir(self, env_tree: dict, **kwargs):
        """

        Args:
            env_tree:

        Returns:

        """
        envs_found = []
        envs_sourced = []
        for env_path in env_tree.get("current_files", []):
            # Skip if not env file
            if env_path.suffix != ".env":
                continue
            envs_found += [env_path]
            # Check if basename of env file is present in label list
            if env_path.stem not in self.labels_all:
                _logger.warning(
                    "Environment file %s does not correspond to any process label.", env_path.name
                )
            # Check if this file has been sourced in main.nf (script score in
            # processes_from_workflow)
            for process, process_scope in self.processes_from_workflow.items():
                source_flag = False
                # If basename of env file correspond to one of the labels used in process
                if env_path.stem in process_scope.get("label", []):
                    # If there is a script scope in the process
                    if script := process_scope.get("script", []):
                        for line in script:
                            if re.search(
                                f"{env_path.relative_to(self.project_dir)}", line
                            ):
                                source_flag = True
                                envs_sourced += [env_path]
                    # If env file not sourced in the actual process
                    if not source_flag:
                        _logger.warning(
                            "Process %s with label %s does not source %s.",
                            process, env_path.stem, env_path.relative_to(self.project_dir)
                        )

        if envs_unsourced := set(envs_found) - set(envs_sourced):
            for env_path in sorted(envs_unsourced):
                _logger.warning(
                    "Env file %s not used in the workflow.",
                    env_path.relative_to(self.project_dir)
                )

    def get_labels_from_folders(self):
        """Parse information from recipes and modules folders

        Returns:
            labels_from_folders(list): list of tools related to modules, conda, singularity and
            docker files
        """
        geniac_dirs = OrderedDict(
            (
                geniac_dir,
                {
                    "tree": self.project_tree.get(
                        self.config.get(GCheck.GENIAC_DIRS, geniac_dir)
                    ),
                    "get_labels": getattr(
                        self, f"_get_labels_from_{geniac_dir}_dir", None
                    ),
                    "check_dir": getattr(self, f"_check_{geniac_dir}_dir", None),
                },
            )
            for geniac_dir in self.config.options(GCheck.GENIAC_DIRS)
        )

        geniac_trees = OrderedDict(
            (f"{geniac_dir}_tree", geniac_scope.get("tree", {}))
            for geniac_dir, geniac_scope in geniac_dirs.items()
        )

        # Get labels first
        for geniac_dirname, geniac_dir in geniac_dirs.items():
            if geniac_dirpath := geniac_dir.get("tree", {}).get("path"):
                if not geniac_dirpath.exists():
                    continue
            if get_label := geniac_dir.get("get_labels"):
                self.labels_from_folders |= get_label(geniac_dirpath)

        # Then check directories
        for geniac_dirname, geniac_dir in geniac_dirs.items():
            if geniac_dirpath := geniac_dir.get("tree", {}).get("path"):
                if not geniac_dirpath.exists():
                    continue
            if check_dir := geniac_dir.get("check_dir"):
                check_dir(**geniac_trees)

        # Check if singularity and docker have the same labels
        if container_diff := sorted(
            list(
                set(
                    self.labels_from_folders.get("singularity", [])
                ).symmetric_difference(set(self.labels_from_folders.get("docker", [])))
            )
        ):
            _logger.warning(
                "Some recipes are missing either in docker or singularity folder %s.",
                container_diff
            )

        return self.labels_from_folders

    def check_labels(
        self,
    ):
        """Check lab"""
        # Get the difference with labels from geniac tools and folders and labels used
        # in the workflow
        cross_labels = [
            label
            for label in self.labels_all
            if label not in self.labels_from_workflow and label != "onlyLinux"
        ]
        if len(cross_labels) >= 1:
            _logger.warning(
                "You have recipes, modules or geniac.tools label(s) that are not used in workflow "
                "scripts %s.", cross_labels
            )

        for process, process_scope in self.processes_from_workflow.items():
            # Get the diff of process labels not present in process scope in config
            # files and present within geniac tools scope
            matched_labels = [
                label
                for label in process_scope.get("label")
                if label not in self.labels_from_process_config
                and label in self.labels_all
            ]
            if len(matched_labels) > 1:
                _logger.error(
                    "Use only one recipes, modules or geniac.tools label for the process %s %s. "
                    "A process should have only one geniac.tools label.",
                    process, matched_labels
                )
            unmatched_labels = [
                label
                for label in process_scope.get("label")
                if label not in self.labels_all
                and label not in self.labels_from_process_config
            ]
            if len(unmatched_labels) >= 1:
                process_path = self.config_path(
                    GCheck.PROJECT_CONFIG, "process", single_path=True
                ).relative_to(self.project_dir)
                _logger.error(
                    "Label(s) %s from process %s in the file %s not defined in the file %s.",
                    unmatched_labels,
                    process,
                    Path(process_scope.get('NextflowScriptPath')).relative_to(self.project_dir),
                    process_path
                )

    def run(self):
        """Execute the main routine

        Returns:

        """

        # Check directory and setup directory flags
        self.check_tree_folder()

        # Get list of labels from main nextflow script
        self.get_processes_from_workflow()

        # Get list of labels from project.config and geniac.config files
        self.get_labels_from_config_files()

        # Get labels from folders
        self.get_labels_from_folders()

        # Check if there is any inconsistency between the labels from configuration
        # files and the main script
        self.check_labels()

        # End the run with exit code
        sys.exit(
            1
            if (
                (logging.ERROR in _logger._cache and _logger._cache[logging.ERROR])
                or (
                    logging.CRITICAL in _logger._cache
                    and _logger._cache[logging.CRITICAL]
                )
            )
            else 0
        )
