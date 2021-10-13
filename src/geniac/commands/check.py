#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""check.py: Linter command for geniac"""

import re
import subprocess
from collections import OrderedDict
from inspect import getfullargspec
from pathlib import Path

from geniac.commands.base import GCommand
from geniac.parsers.base import DEFAULT_ENCODING
from geniac.parsers.config import NextflowConfig, NextflowConfigContainer
from geniac.parsers.scripts import NextflowScript

__author__ = "Fabrice Allain"
__copyright__ = "Institut Curie 2020"


class GCheck(GCommand):
    """Linter command for geniac"""

    CONDA_RECIPES_RE = re.compile(
        r"(?P<recipes>(([\w-]+::[\w-]+==?[\d.]+==?[\w]+) ?)+)"
    )
    CONDA_PATH_RE = re.compile(
        r"(?P<nxfvar>\${(baseDir|projectDir)})/(?P<basepath>[/\w]+\.(?P<ext>yml|yaml))"
    )
    INSTALL_MAIN_CMAKE_RE = re.compile(
        r"install\([\s\w_${}\-/=]*DESTINATION +"
        r"(?P<destination>\${CMAKE_INSTALL_PREFIX}/\${pipeline_dir}/bin/fromSource)[\s)]"
    )
    INSTALL_MODULE_CMAKE_RE = re.compile(
        r"install\([\s\w_${}\-/=]*DESTINATION +[\s\w_${}\-/=]*\)"
    )
    PROJECT_ADD_MAIN_CMAKE_RE_TEMP = (
        r"ExternalProject_Add\(\s*{label}[\s\w_${{}}\-/=]*SOURCE_"
        r"DIR +(\$\{{pipeline_source_dir\}}/modules/fromSource|"
        r"\$\{{CMAKE_CURRENT_SOURCE_DIR\}})/{label}"
    )
    SINGULARITY_DEP_RE_TEMP = (
        r"\%files[\/\w.\s]*\s+(?P<mydep>{tool}/{dependency} +[\/\w.]+{dependency})"
    )
    DOCKER_DEP_RE_TEMP = r"ADD +{tool}/{dependency} [\/\w.]+{dependency}"

    # Name of config sections used in this class
    TREE_SUFFIX = "tree"
    PROJECT_WORKFLOW = "project.workflow"
    GENIAC_FLAGS = "geniac.flags"
    GENIAC_DIRS = "geniac.directories"
    GENIAC_CONFIG_FILES = "geniac.generated.config"
    GENIAC_CHECK_CONFIG = "geniac.check.config"

    def __init__(self, project_dir, *args, **kwargs):
        """Init flags specific to GCheck command"""
        super().__init__(*args, project_dir=project_dir, **kwargs)
        self._project_tree = self._format_tree_config()
        self._labels_from_folders = OrderedDict()
        self._labels_from_configs = OrderedDict()
        self._processes_from_workflow = OrderedDict()
        self._labels_from_workflow = []
        self._labels_all = []
        self._nxf_config_container = NextflowConfigContainer()

    @property
    def project_tree(self):
        """Formatted tree configuration"""
        return self._project_tree

    @property
    def nxf_config_container(self):
        """Namespace for Nextflow configuration files"""
        return self._nxf_config_container

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
        return list(dict.fromkeys(list(self.labels_from_configs.get("geniac", []))))

    @property
    def labels_from_process_config(self):
        """Process config labels from Nextflow folders"""
        return list(dict.fromkeys(list(self.labels_from_configs.get("process", []))))

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

    def _get_current_files(self, config_tree: dict, tree_section: str):
        """
        Get current file list from a specific section

        Args:
            config_tree:
            tree_section:

        Returns:

        """
        dir_path = config_tree.get(tree_section).get("path")
        recursive_flag = config_tree.get(tree_section).get("recursive")
        excluded_files = config_tree.get(tree_section).get("excluded_files")
        self.debug(
            "Browse current files in %s directory%s",
            dir_path,
            " recursively" if recursive_flag else "",
        )
        return (
            sorted(
                [
                    _
                    for _ in dir_path.glob("**/*" if recursive_flag else "*")
                    if _ not in excluded_files and not _.is_dir()
                ]
            )
            if dir_path.exists()
            else ()
        )

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
                    "required": self.default_config.getboolean(tree_section, "required")
                    if self.default_config.has_option(tree_section, "required")
                    else False,
                    # Is the folder recommended ?
                    "recommended": self.default_config.getboolean(
                        tree_section, "recommended"
                    )
                    if self.default_config.has_option(tree_section, "recommended")
                    else False,
                    # Should we analyze files and sub directories recursively ?
                    "recursive": self.default_config.getboolean(
                        tree_section, "recursive"
                    )
                    if self.default_config.has_option(tree_section, "recursive")
                    else False,
                    # Path to the folder
                    "path": Path(self.default_config.get(tree_section, "path"))
                    if self.default_config.get(tree_section, "path")
                    else Path(self.project_dir),
                    # Path(s) to mandatory file(s)
                    "required_files": self.get_config_path(
                        tree_section, "mandatory", lazy_glob=True
                    ),
                    # Path(s) to optional file(s)
                    "optional_files": sorted(
                        list(
                            set(
                                [
                                    path
                                    for path in self.get_config_path(
                                        tree_section, "optional"
                                    )
                                    if path
                                    not in self.get_config_path(
                                        tree_section, "mandatory", lazy_glob=True
                                    )
                                ]
                            )
                        )
                    ),
                    # Path(s) to file(s) excluded from the analysis
                    "excluded_files": self.get_config_path(tree_section, "excluded"),
                    # Path(s) to file(s) excluded from the analysis
                    "prohibited_files": self.get_config_path(
                        tree_section, "prohibited"
                    ),
                },
            )
            for tree_section in self.get_config_subsection(self.TREE_SUFFIX)
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
        self.info("Checking tree structure of %s.", self.project_dir)
        self.debug(
            "Sections parsed from config file: %s.", self.default_config.sections()
        )

        for tree_section, section in self.project_tree.items():
            for msg in ("\n", f"Folder {tree_section}"):
                self.debug(msg)

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
                self.debug(msg)

            # If folder exists and is not empty (excluded files are ignored)
            if path:
                is_project_dir = path.resolve() == self.project_dir.resolve()
                formatted_path = (
                    path.relative_to(self.project_dir)
                    if not is_project_dir
                    else self.project_dir.relative_to(Path.cwd())
                    if self.project_dir.is_relative_to(Path.cwd())
                    else self.project_dir
                )
                if required and not path.exists():
                    extra_msg = (
                        " Add it to your project if you want your "
                        "workflow to be compatible with geniac tools."
                        if not is_project_dir
                        else ""
                    )
                    self.critical(
                        "Directory %s does not exist.%s", formatted_path, extra_msg
                    )
                elif recommended and not path.exists():
                    self.warning(
                        "Directory %s does not exist. It is recommended to have one in your "
                        "project.",
                        formatted_path,
                    )

            # Trigger an error if a mandatory file is missing
            for file in required_files:
                # If the folder is actually required but the required file is not
                # present or if the folder is recommended and non empty
                if (required or (recommended and current_files)) and (
                    file not in current_files
                ):
                    self.error(
                        "File %s is missing. Add it to your project if you want to be compatible "
                        "with geniac.",
                        file.relative_to(self.project_dir),
                    )

            # Trigger a warning if an optional file is missing
            for file in optional_files:
                # If the folder is actually required but the optional file is not
                # present
                if required and file not in current_files:
                    self.warning(
                        "Optional file %s does not exist. It is recommended to have one in your "
                        "project.",
                        file.relative_to(self.project_dir),
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
            for config_key in self.default_config.options(GCheck.PROJECT_WORKFLOW)
            for index, path in enumerate(
                self.get_config_path(GCheck.PROJECT_WORKFLOW, config_key)
            )
            if not path.is_relative_to(geniac_dir)
        )

        for _, script_path in script_paths.items():
            if script_path.exists():
                script.read(script_path)
            else:
                self.error(
                    "Workflow script %s does not exist.",
                    script_path.relative_to(self.project_dir),
                )

        # Check if there is processes without label in the actual workflow
        # fmt: off
        for process in (processes := script.content.get("process")):
            if not processes.get(process).get("label"):
                process_path = Path(
                    processes.get(process).get('NextflowScriptPath')
                ).relative_to(self.project_dir)
                self.error(
                    "Process %s in %s does not have any label.",
                    process, process_path
                )
        # fmt: on

        self.processes_from_workflow = script.content.get("process", OrderedDict())

    def _check_geniac_config(self, config: NextflowConfig, conda_check: bool = True):
        """Check the content of params scope in a geniac config file

        Args:
            conda_check (bool): trigger conda search calls with conda recipes in params.geniac.tools

        Returns:
            labels_geniac_tools (list): list of geniac tool labels in params.geniac.tools
        """
        labels_geniac_tools = []

        # Check parameters according to their default values
        config.check_config_scope("params")

        # Check if conda command exists
        try:
            subprocess.run(["conda", "-h"], capture_output=True, check=True)
        except subprocess.CalledProcessError:
            self.error(
                "Conda is not available in your path. Geniac will not check if tool "
                "recipes are correct."
            )
            conda_check = False

        # Check each label in params.geniac.tools
        self.info(
            "Checking conda recipes in params.geniac.tools."
            if conda_check
            else "Checking of conda recipes turned off."
        )
        for label, [recipe] in config.get("params.geniac.tools", OrderedDict()).items():
            labels_geniac_tools.append(label)
            # If the tool value is a conda recipe
            if match := GCheck.CONDA_RECIPES_RE.match(recipe):
                if not conda_check:
                    continue
                # The related recipe is a correct conda recipe
                # Check if the recipes exists in the actual OS with conda search
                for conda_recipe in match.groupdict().get("recipes").split(" "):
                    try:
                        conda_search = subprocess.run(
                            ["conda", "search", conda_recipe],
                            capture_output=True,
                            check=True,
                        )
                    except subprocess.CalledProcessError:
                        self.error(
                            "Conda search command returned non-zero exit status for the recipe "
                            "%s[%s]. Either conda is not available or the recipe does not link "
                            "to an existing package or build. Check if the requested build is "
                            "still available on conda with the following command:"
                            "\n\t> conda search %s.",
                            conda_recipe,
                            label,
                            conda_recipe,
                        )
                    else:
                        self.debug("Conda search output:\n%s", conda_search.stdout)
            # Elif the tool value is a path to an environment file (yml or yaml ext),
            # check if the path exists
            elif match := GCheck.CONDA_PATH_RE.search(recipe):
                if (
                    conda_path := Path(
                        self.project_dir / match.groupdict().get("basepath")
                    )
                ) and not conda_path.exists():
                    self.error(
                        "Conda file %s related to %s tool does not exist.",
                        conda_path.relative_to(self.project_dir),
                        label,
                    )
            # else check if it's a valid path
            else:
                self.error(
                    "Value %s of %s tool does not follow the pattern "
                    '"condaChannelName::softName=version=buildString".',
                    recipe,
                    label,
                )

        for extra_section in (
            "params.geniac.containers.yum",
            "params.geniac.containers.git",
        ):
            NextflowConfig.check_labels_in_section(
                config, extra_section, labels_geniac_tools
            )

        return labels_geniac_tools

    def _check_process_config(self, config: NextflowConfig, config_path):
        """Check the content of a process config file

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
                self.error(
                    "withName:%s is defined in %s file but the process %s is not used anywhere.",
                    config_process,
                    config_path.relative_to(self.project_dir),
                    config_process,
                )

        # Return list of labels defined with withLabel selector in the process.config file
        return list(config.get("process", OrderedDict()).get("withLabel", []))

    def _check_nextflow_config(
        self,
        config: NextflowConfig,
        config_path,
        default_config_paths: list = (),
        default_geniac_files_paths: list = (),
    ):
        """Check the content of a nextflow config file

        Args:
            config_path:
            default_geniac_files_paths (list):
            default_config_paths (list):
        """
        include_config_paths = [
            self.project_dir / Path(include_path)
            for include_path in config.get("includeConfig", [])
        ]
        profile_config_paths = [
            self.project_dir / Path(conf_path)
            for conf_profile in config.get("profiles", OrderedDict())
            for conf_path in config.get("profiles", OrderedDict())
            .get(conf_profile, {})
            .get("includeConfig", {})
        ]
        for default_config_path in default_config_paths + default_geniac_files_paths:
            # We do not check if the path corresponds to nextflow.config path
            # Check if config files are included
            if default_config_path != config_path and (
                default_config_path not in include_config_paths + profile_config_paths
            ):
                msg = (
                    f"Main configuration file "
                    f"{config_path.relative_to(self.project_dir)} does not "
                    f"include configuration file "
                    f"{default_config_path.relative_to(self.project_dir)}."
                )
                # Trigger a warning if optional file. Otherwise trigger an error
                if default_config_path in self.get_config_path(
                    ".".join([GCheck.TREE_SUFFIX, "conf"]), "optional"
                ):
                    self.warning(msg)
                else:
                    self.error(msg)

    def _check_base_config(self, config: NextflowConfig):
        """Check the content of a base config file"""
        self.debug("Check content of base config file without analyzing geniac scope")
        config.check_config_scope("params", skip_nested_scopes=["geniac"])

    def get_labels_from_config_files(self):
        """Check the structure of the repo

        Returns:
            labels_geniac_tools (list): list of geniac tool labels in params.geniac.tools
            labels_process (list): list of process labels in params.process with withName
        """

        # Link config path to their method
        project_config_scopes = OrderedDict(
            (
                default_config_name,
                {
                    "expected": True,
                    "path": self.get_config_path(
                        GCheck.GENIAC_CHECK_CONFIG,
                        default_config_name,
                        single_path=default_config_name,
                    ),
                    "check_config": getattr(
                        self, f"_check_{default_config_name}_config", None
                    ),
                },
            )
            for default_config_name in self.get_config_section_items(
                GCheck.GENIAC_CHECK_CONFIG
            )
            if default_config_name != "all"
        )
        project_config_scopes |= OrderedDict(
            (
                default_config_path.stem,
                {
                    "expected": default_config_path.stem
                    in self.get_config_section_items(GCheck.GENIAC_CHECK_CONFIG),
                    "path": default_config_path,
                    "check_config": getattr(
                        self, f"_check_{default_config_path.stem}_config", None
                    ),
                },
            )
            for default_config_path in self.get_config_path(
                GCheck.GENIAC_CHECK_CONFIG, "all", single_path=False
            )
            if default_config_path.stem not in project_config_scopes
        )

        # Generate path to configuration files produced by geniac
        generated_geniac_config_paths = [
            self.get_config_path(
                GCheck.GENIAC_CONFIG_FILES, geniac_config_file, single_path=True
            )
            for geniac_config_file in self.default_config.options(
                GCheck.GENIAC_CONFIG_FILES
            )
        ]

        expected_geniac_config_paths = [
            config_scope.get("path")
            for config, config_scope in project_config_scopes.items()
            if config_scope.get("expected")
        ]

        # For each Nextflow configuration file analyzed
        for config_key, project_config_scope in project_config_scopes.items():
            project_config_path = project_config_scope["path"]
            config_method = project_config_scope["check_config"]
            config_args = {
                "config_path": project_config_path,
                "default_config_paths": expected_geniac_config_paths,
                "default_geniac_files_paths": generated_geniac_config_paths,
                "conda_check": self.default_config.getboolean(
                    self.GENIAC_FLAGS, "condaCheck"
                ),
            }

            # If the project config file does not exists and does not belong to default
            # geniac files
            if not project_config_path.exists():
                if project_config_path not in expected_geniac_config_paths:
                    self.error(
                        "Nextflow config file %s does not exist.",
                        project_config_path.relative_to(self.project_dir),
                    )
                continue

            # Read the Nextflow configuration file
            nxf_config = NextflowConfig(project_dir=self.project_dir)
            nxf_config.read(
                project_config_path,
                warnings=config_key
                not in self.default_config.options(GCheck.GENIAC_CHECK_CONFIG),
            )
            self.nxf_config_container.append(nxf_config)

            if config_method:
                self.info(
                    "Checking Nextflow configuration file. %s",
                    project_config_path.relative_to(self.project_dir),
                )
                self.labels_from_configs[config_key] = config_method(
                    **{
                        arg: config_args.get(arg)
                        for arg in getfullargspec(config_method).args
                        if arg != "self"
                    }
                    | {"config": nxf_config}
                )

    def _get_labels_from_modules_dir(self, modules_tree: dict):
        """Get geniac labels from modules directory"""
        labels_from_modules = []
        modules_dir = modules_tree.get("path")
        main_cmake_lists = modules_dir / "CMakeLists.txt"
        if not main_cmake_lists.exists():
            # Output an error if modules directory is not empty
            if any(modules_dir.iterdir()):
                self.error(
                    "Folder %s requires a CMakeLists.txt file in order to automatically "
                    "build containers.",
                    modules_dir.relative_to(self.project_dir),
                )
            return []

        with open(main_cmake_lists, encoding=DEFAULT_ENCODING) as cmake_file:
            main_cmake_lists_content = cmake_file.read()

        for module_dir in [
            module for module in modules_dir.iterdir() if module.is_dir()
        ]:
            # If child correspond to a folder and the name of this folder is linked to
            # an existing bash script
            # If the actual file is not the main cmakelists file, it should correspond to a module
            module_name = module_dir.stem
            cmakelists_child = module_dir / "CMakeLists.txt"
            labels_from_modules += [module_name]

            if cmakelists_child.exists():
                self.debug("Found module directory with label %s.", module_name)
                # Parse the CMakeLists.txt file to see if the label is correctly defined
                check_main_cmlist_reg = re.compile(
                    GCheck.PROJECT_ADD_MAIN_CMAKE_RE_TEMP.format(label=module_name)
                )

                with open(
                    cmakelists_child, encoding=DEFAULT_ENCODING
                ) as cmake_module_file:
                    module_cmake_lists_content = cmake_module_file.read()

                # First look if the is correctly added within the main CMakeLists.txt file
                if check_main_cmlist_reg.search(main_cmake_lists_content):
                    self.debug(
                        "Module %s correctly added within %s.",
                        module_name,
                        main_cmake_lists.relative_to(self.project_dir),
                    )
                else:
                    self.error(
                        "Module %s not added with ExternalProject_Add directive within %s file.",
                        module_name,
                        main_cmake_lists.relative_to(self.project_dir),
                    )

                # Then look in the CMakeLists.txt if install DESTINATION is correct
                if GCheck.INSTALL_MAIN_CMAKE_RE.search(main_cmake_lists_content):
                    self.debug(
                        "Module %s correctly setup in %s to install tools inside "
                        "${projectDir}/bin/fromSource",
                        module_name,
                        main_cmake_lists.relative_to(self.project_dir),
                    )
                else:
                    self.error(
                        "DESTINATION in '%s' is not set to '${projectDir}/bin/fromSource'. Please "
                        "update DESTINATION section in this file to "
                        '"DESTINATION ${CMAKE_INSTALL_PREFIX}/${pipeline_dir}/bin/fromSource."',
                        main_cmake_lists.relative_to(self.project_dir),
                    )

                # Then look in the module cmakeLists.txt if install directive has been set
                if GCheck.INSTALL_MODULE_CMAKE_RE.search(module_cmake_lists_content):
                    self.debug("Module %s have an install directive", module_name)
                else:
                    self.warning(
                        "Module %s doesn't setup an install directive within %s file. "
                        "It needs one in order to install sources inside this module.",
                        module_name,
                        cmakelists_child.relative_to(self.project_dir),
                    )

        return OrderedDict([("modules", labels_from_modules)])

    @staticmethod
    def _get_labels_from_conda_dir(conda_tree):
        """Get geniac labels from conda, singularity and docker recipes"""
        labels_from_recipes = []

        for recipe_child in conda_tree.get("current_files", []):
            labels_from_recipes += [recipe_child.stem]

        return OrderedDict([("conda", labels_from_recipes)])

    @staticmethod
    def _get_labels_from_singularity_dir(singularity_tree):
        """Get geniac labels from conda, singularity and docker recipes"""
        labels_from_recipes = []

        for recipe_child in singularity_tree.get("current_files", []):
            labels_from_recipes += [recipe_child.stem]

        return OrderedDict([("singularity", labels_from_recipes)])

    @staticmethod
    def _get_labels_from_docker_dir(docker_tree):
        """Get geniac labels from conda, singularity and docker recipes"""
        labels_from_recipes = []

        for recipe_child in docker_tree.get("current_files", []):
            labels_from_recipes += [recipe_child.stem]

        return OrderedDict([("docker", labels_from_recipes)])

    def _check_dependencies_dir(
        self,
        dependencies_tree: dict,
        docker_tree: dict = None,
        singularity_tree: dict = None,
    ):
        """

        Args:
            dependencies_tree:
            singularity_tree:
            docker_tree:

        Returns:

        """
        dependencies_dir = dependencies_tree.get("path")

        for dependency_path in dependencies_tree.get("current_files", []):
            # The dependency should be inside a sub folder (recipes/dependencies/tool_name/dep.ext)
            tool_name = dependency_path.parent.name
            if (
                tool_name == "dependencies"
                or not dependency_path.parent.parent.resolve().samefile(
                    dependencies_dir.resolve()
                )
            ):
                self.error(
                    "Dependency %s can't be used for container recipes. It should be located "
                    "inside a custom folder with the name corresponding to the container recipe "
                    "file.",
                    dependency_path.relative_to(self.project_dir),
                )
                continue

            for recipe_type, recipe_ext, tree in (
                ("singularity", ".def", singularity_tree),
                ("docker", ".Dockerfile", docker_tree),
            ):
                recipe_files = tree.get("current_files", [])
                recipe_flag = False

                # Check if the file is used in recipe files
                for recipe_path in recipe_files:
                    if recipe_path.suffix == recipe_ext:
                        dependency_reg = re.compile(
                            getattr(
                                GCheck, f"{recipe_type.upper()}_DEP_RE_TEMP", ""
                            ).format(dependency=dependency_path.name, tool=tool_name)
                        )
                        with open(
                            recipe_path, encoding=DEFAULT_ENCODING
                        ) as recipe_file:
                            recipe_flag = (
                                True
                                if dependency_reg.search(recipe_file.read())
                                else recipe_flag
                            )

                # Throw an error if dependency not found in any recipe file
                if not recipe_flag:
                    self.warning(
                        "Dependency file %s not used in any %s recipe files %s.",
                        dependency_path.name,
                        recipe_type,
                        tree.get("path").relative_to(self.project_dir),
                    )

    def _check_env_dir(self, env_tree: dict):
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
                self.warning(
                    "Environment file %s does not correspond to any process label.",
                    env_path.name,
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
                        self.warning(
                            "Process %s with label %s does not source %s.",
                            process,
                            env_path.stem,
                            env_path.relative_to(self.project_dir),
                        )

        if envs_unsourced := set(envs_found) - set(envs_sourced):
            for env_path in sorted(envs_unsourced):
                self.warning(
                    "Env file %s not used in the workflow.",
                    env_path.relative_to(self.project_dir),
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
                        self.default_config.get(GCheck.GENIAC_DIRS, geniac_dir)
                    ),
                    "get_labels": getattr(
                        self, f"_get_labels_from_{geniac_dir}_dir", None
                    ),
                    "check_dir": getattr(self, f"_check_{geniac_dir}_dir", None),
                },
            )
            for geniac_dir in self.default_config.options(GCheck.GENIAC_DIRS)
        )

        geniac_trees = OrderedDict(
            (f"{geniac_dir}_tree", geniac_scope.get("tree", {}))
            for geniac_dir, geniac_scope in geniac_dirs.items()
        )

        # Get labels first
        for _, geniac_dir in geniac_dirs.items():
            if geniac_dirpath := geniac_dir.get("tree", {}).get("path"):
                if not geniac_dirpath.exists():
                    continue
            if get_label := geniac_dir.get("get_labels"):
                self.labels_from_folders |= get_label(
                    **{
                        arg: geniac_trees.get(arg)
                        for arg in getfullargspec(get_label).args
                        if arg != "self"
                    }
                )

        # Then check directories
        for _, geniac_dir in geniac_dirs.items():
            if geniac_dirpath := geniac_dir.get("tree", {}).get("path"):
                if not geniac_dirpath.exists():
                    continue
            if check_dir := geniac_dir.get("check_dir"):
                check_dir(
                    **{
                        arg: geniac_trees.get(arg)
                        for arg in getfullargspec(check_dir).args
                        if arg != "self"
                    }
                )

        # Check if singularity and docker have the same labels
        if container_diff := sorted(
            list(
                set(
                    self.labels_from_folders.get("singularity", [])
                ).symmetric_difference(set(self.labels_from_folders.get("docker", [])))
            )
        ):
            self.warning(
                "Some recipes are missing either in docker or singularity folder %s.",
                container_diff,
            )

        return self.labels_from_folders

    def check_labels(
        self,
    ):
        """Check labels"""
        # Get the difference with labels from geniac tools and folders and labels used
        # in the workflow
        cross_labels = [
            label
            for label in self.labels_all
            if label not in self.labels_from_workflow and label != "onlyLinux"
        ]
        if len(cross_labels) >= 1:
            self.warning(
                "You have recipes, modules or geniac.tools label(s) that are not used in workflow "
                "scripts %s.",
                cross_labels,
            )

        # Check if there is any inconsistencies with labels in other parts of config files (post,
        # envCustom) in global nxf_config scope
        for extra_section in (
            "params.geniac.containers.cmd.post",
            "params.geniac.containers.cmd.envCustom",
        ):
            self.nxf_config_container.check_labels_in_section(
                extra_section, self.labels_all
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
                self.error(
                    "Use only one recipes, modules or geniac.tools label for the process %s %s. "
                    "A process should have only one geniac.tools label.",
                    process,
                    matched_labels,
                )
            unmatched_labels = [
                label
                for label in process_scope.get("label")
                if label not in self.labels_all
                and label not in self.labels_from_process_config
            ]
            if len(unmatched_labels) >= 1:
                process_path = self.get_config_path(
                    GCheck.GENIAC_CHECK_CONFIG, "process", single_path=True
                ).relative_to(self.project_dir)
                self.error(
                    "Label(s) %s from process %s in the file %s not defined in the file %s.",
                    unmatched_labels,
                    process,
                    Path(process_scope.get("NextflowScriptPath")).relative_to(
                        self.project_dir
                    ),
                    process_path,
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
        if self.error_flag:
            raise SystemExit(1)
