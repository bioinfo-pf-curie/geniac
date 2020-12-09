#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""check.py: Linter command for geniac"""

import logging
from pathlib import Path

from .command import GCommand

__author__ = "Fabrice Allain"
__copyright__ = "Institut Curie 2020"

_logger = logging.getLogger(__name__)


class GCheck(GCommand):
    """Linter command for geniac"""

    def __init__(self, *args, **kwargs):
        """Init flags specific to GCheck command"""
        super().__init__(*args, **kwargs)
        self._dir_flags = []

    def check_tree_folder(self):
        """Check the directory d in order to set the flags"""
        _logger.info("Check tree folder")

        def opt_paths(section, option):
            """Format config option to list of Path objects"""
            option = (
                self.config.get(section, option).split()
                if self.config.get(section, option)
                else []
            )
            # Get Path instance for each file in the related configparser option. Glob
            # patterns are unpacked here
            return [
                Path(in_path) if "*" not in in_path else glob_path
                for in_path in option
                for glob_path in sorted(Path().glob(in_path))
            ]

        # TODO: rewrite get_sections to have a nested dict instead of a list
        config_sections = [
            section for section in self.config.sections() if section.startswith("tree.")
        ]
        _logger.debug(f"Sections parsed from config file: {self.config.sections()}")

        for config_section in config_sections:
            [_logger.debug(msg) for msg in ("\n", f"SECTION {config_section}")]
            # Is the folder required ?
            required = (
                self.config.getboolean(config_section, "required")
                if self.config.has_option(config_section, "required")
                else False
            )
            recommended = (
                self.config.getboolean(config_section, "recommended")
                if self.config.has_option(config_section, "recommended")
                else False
            )
            # Path to the folder
            path = (
                Path(self.config.get(config_section, "path"))
                if self.config.get(config_section, "path")
                else Path(Path.cwd())
            )
            # Path(s) to mandatory file(s)
            required_files = opt_paths(config_section, "files")
            # Path(s) to optional file(s)
            optional_files = opt_paths(config_section, "optional")
            # Path(s) to file(s) excluded from the analysis
            excluded_files = opt_paths(config_section, "exclude")
            # Get a list all the files in the folder
            cwd_files = (
                [_ for _ in path.iterdir() if _ not in excluded_files]
                if path.exists()
                else []
            )

            [
                _logger.debug(msg)
                for msg in (
                    f"required: {required}",
                    f"path: {path}",
                    f"expected files: {required_files}",
                    f"optional files: {optional_files}",
                    f"excluded files: {excluded_files}",
                    f"current files: {cwd_files}",
                )
            ]

            # If folder exists and is not empty (excluded files are ignored)
            if path.exists() and path.is_dir() and len(cwd_files) >= 1:
                _logger.debug("Add section to directory flags")
                self._dir_flags.append(config_section)
            elif required and not path.exists():
                _logger.error(
                    f"Directory {path.name} does not exist. Add it to you project if "
                    f"you want to be compatible with geniac tools"
                )
            elif recommended and not path.exists():
                _logger.warning(
                    f"Directory {path.name} does not exist. It is recommended to have"
                    f" one"
                )

            for file in cwd_files:
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

    def check_config_file_content(self):
        """Check the structure of the repo

        Returns:

        """
        pass

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
