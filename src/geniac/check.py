#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""check.py: Linter command for geniac"""

import logging
import re
import subprocess
from pathlib import Path

from .base import GCommand
from .config import NextflowConfig

__author__ = "Fabrice Allain"
__copyright__ = "Institut Curie 2020"

_logger = logging.getLogger(__name__)


class GCheck(GCommand):
    """Linter command for geniac"""

    CONDARECIPESRE = re.compile(r"(?P<recipes>(([\w-]+::[\w-]+==?[\d.]+==?[\w]+) ?)+)")
    CONDAPATHRE = re.compile(
        r"(?P<nxfvar>\${(baseDir|projectDir)})/(?P<basepath>[/\w]+\.(?P<ext>yml|yaml))"
    )

    def __init__(self, project_dir, *args, **kwargs):
        """Init flags specific to GCheck command"""
        super().__init__(*args, project_dir=project_dir, **kwargs)
        self._dir_flags = []
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
            tree_section: {
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
                "required_files": self.config_paths(tree_section, "files"),
                # Path(s) to optional file(s)
                "optional_files": self.config_paths(tree_section, "optional"),
                # Path(s) to file(s) excluded from the analysis
                "excluded_files": self.config_paths(tree_section, "exclude"),
            }
            for tree_section in self.config_subsection("tree")
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
        """Check the directory d in order to set the flags"""
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
            if path.exists() and path.is_dir() and len(current_files) >= 1:
                _logger.debug("Add section to directory flags")
                self._dir_flags.append(tree_section)
            elif required and not path.exists():
                _logger.error(
                    f"Directory {path.name} does not exist. Add it to you project if "
                    f"you want to be compatible with geniac tools"
                )
            elif recommended and not path.exists():
                _logger.warning(
                    "Directory %s does not exist. It is recommended to have one",
                    path.name,
                )

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

        _logger.debug(f"Directory flags: {self._dir_flags}")

    def _check_config_scope(
        self,
        nxf_config: NextflowConfig,
        nxf_config_scope: str,
        nxf_config_path: str = "",
    ):
        """Check if the given scope is in an NextflowConfig instance

        Args:
            nxf_config (NextflowConfig): Nextflow configuration object
            nxf_config_scope (str): Scope checked in the Nextflow configuration
        """
        _logger.debug(f"Checking {nxf_config_scope} in {nxf_config_path}")

        def get_config_list(config, scope, option):
            """Get option list from configparser object
            Args:
                scope:
                option:

            Returns:
                list
            """
            return (
                list(filter(None, config_option.split("\n")))
                if (config_option := config.get(f"scope.{scope}", option))
                else []
            )

        config_scopes = get_config_list(self.config, nxf_config_scope, "scopes")
        config_paths = get_config_list(self.config, nxf_config_scope, "paths")
        config_props = get_config_list(self.config, nxf_config_scope, "properties")
        config_values = {
            key: value
            for key, value in (
                self.config.items(f"scope.{nxf_config_scope}.values")
                if self.config.has_section(f"scope.{nxf_config_scope}.values")
                else []
            )
        }

        # Check if the actual scope exists in the Nextflow config
        if nxf_config_scope and not (scope := nxf_config.get(nxf_config_scope)):
            _logger.error(
                f"Config file {nxf_config_path} doesn't have {nxf_config_scope} scope"
            )

        # Check if config_paths in the Nextflow config corresponds to their default values
        if config_paths:
            for config_path in config_paths:
                if config_path and (cfg_val := scope.get(config_path)) != (
                    def_val := config_values.get(config_path)
                ):
                    _logger.warning(
                        f"Value {cfg_val} of {nxf_config_scope}.{config_path} parameter in file {nxf_config_path} "
                        f"doesn't correspond to the default value {def_val}"
                    )

        # Check if config_props exists in the Nextflow config
        if config_props:
            for config_prop in config_props:
                if config_prop and (cfg_val := scope.get(config_prop)) != (
                    def_val := config_values.get(config_prop)
                ):
                    _logger.info(
                        f"Value {cfg_val} of {nxf_config_scope}.{config_prop} parameter in file {nxf_config_path} "
                        f"doesn't correspond to the default value ('{def_val}')"
                    )

        # Call same checks on nested scopes
        for nested_scope in config_scopes:
            self._check_config_scope(
                nxf_config,
                ".".join((nxf_config_scope, nested_scope)),
                nxf_config_path=nxf_config_path,
            )

    def check_geniac_config(self):
        """Check the content of params scope in a geniac config file

        Returns:
            labels_geniac_tools (list): list of geniac tool labels in params.geniac.tools
        """
        conda_check = True
        labels_geniac_tools = []

        conf_path = self.config.get("project.config", "geniac")

        # Parse geniac config files
        config = NextflowConfig()
        config.read(conf_path)

        # Check parameters according to their default values
        self._check_config_scope(config, "params", nxf_config_path=conf_path)

        # Check if conda command exists
        if subprocess.run(["conda", "-h"], capture_output=True).returncode != 0:
            _logger.error(
                "Conda is not available in your path. Geniac will not check if tool recipes are correct"
            )
            conda_check = False

        # Check each label in params.geniac.tools
        for label, recipe in config.get("params.geniac.tools").items():
            labels_geniac_tools.append(label)
            # If conda recipes
            if match := self.CONDARECIPESRE.match(recipe):
                # The related recipe is a correct conda recipe
                # Check if the recipes exists in the actual OS with conda search
                for conda_recipe in match.groupdict().get("recipes").split(" "):
                    if (
                        conda_check
                        and self.config.getboolean("project.config", "condaCheck")
                        and subprocess.run(
                            ["conda", "search", conda_recipe], capture_output=True
                        ).returncode
                        != 0
                    ):
                        _logger.error(
                            f"Conda recipe {conda_recipe} for the tool {label} does not link to an existing "
                            f"package or build. Please look at the result of the conda search command"
                        )
            elif match := self.CONDAPATHRE.match(recipe):
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
        for extra_section in (
            "params.geniac.containers.yum",
            "params.geniac.containers.git",
        ):
            if x_section := config.get(extra_section):
                for label in x_section:
                    if label not in labels_geniac_tools:
                        _logger.error(
                            f"Label {label} of {extra_section} is not defined in params.geniac.tools"
                        )
            else:
                _logger.warning(
                    f"Section {extra_section} is not defined in params.geniac.tools"
                )

        return labels_geniac_tools

    def check_process_config(self):
        """Check the content of a process config file

        Returns:

        """
        pass

    def check_nextflow_config(self):
        """Check the content of a nextflow config file

        Returns:

        """
        pass

    def check_config_file_content(self):
        """Check the structure of the repo

        Returns:

        """
        self.check_geniac_config()
        self.check_process_config()
        self.check_nextflow_config()

    def get_labels_from_folders(self):
        """Parse information from recipes and modules folders

        Returns:

        """
        pass

    def get_labels_from_main(self):
        """Parse only the main.nf file

        Returns:

        """
        pass

    def get_labels_from_process_config(self):
        """Parse only the conf/process.config

        Returns:

        """
        pass

    def check_labels(self):
        """

        Returns:

        """
        pass

    def check_dependencies_dir(self):
        """

        Returns:

        """
        pass

    def check_env_dir(self):
        """

        Returns:

        """
        pass

    def run(self):
        """Execute the main routine

        Returns:

        """
        self.check_tree_folder()
        self.check_config_file_content()
        self.get_labels_from_folders()
        self.get_labels_from_main()
        self.get_labels_from_process_config()
        self.check_labels()
        self.check_dependencies_dir()
        self.check_env_dir()
