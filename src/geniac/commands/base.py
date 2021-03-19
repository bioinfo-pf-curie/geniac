#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""base.py: CLI geniac interface"""

import logging
import sys
from abc import ABC, abstractmethod
from configparser import ConfigParser, ExtendedInterpolation
from os.path import basename, dirname, isfile
from pathlib import Path

from pkg_resources import resource_filename, resource_stream

__author__ = "Fabrice Allain"
__copyright__ = "Institut Curie 2020"

_logger = logging.getLogger(__name__)


class GBase(ABC):
    """Abstract base class for Geniac commands"""

    DEFAULT_CONFIG = ("geniac", "conf/geniac.ini")

    def __init__(self, project_dir=None, config_file=None, **kwargs):
        """

        Args:
            project_dir (str): path to the Nextflow Project Dir
            config_file (str): path to a configuration file (INI format)
        """
        self.project_dir = project_dir
        self.default_config_file = Path(resource_filename(*self.DEFAULT_CONFIG))
        self.config_file = Path(config_file) if config_file else None
        self.config = self._load_config(config_file=self.config_file)

    def _load_config(self, config_file: Path = None):
        """Load default configuration file and update option with config_file

        Returns:
            :obj:`configparser.ConfigParser`: config instance
        """
        config = ConfigParser(
            interpolation=ExtendedInterpolation(), allow_no_value=True
        )
        # TODO: add defauldict in order to init tree. sections with required, path,
        #  files, opt_files and exclude keys
        # TODO: remove has_section checks in GCheck after previous todo
        # Read default config file
        config.optionxform = str
        config.read_string(resource_stream(*self.DEFAULT_CONFIG).read().decode())
        if config_file:
            # Read configuration file
            config.read(config_file)
        return config

    @property
    def project_dir(self):
        """Project Dir path property

        Returns:

        """
        return self._project_dir

    @project_dir.setter
    def project_dir(self, value):
        """If value is not a directory, set the project dir to the current directory"""
        if (path := Path(value)) and path.is_dir():
            self._project_dir = path.resolve()
        else:
            _logger.critical(f"Path {path} does not exist")
            sys.exit(1)

    @property
    def config_file(self):
        """Configuration file (optional)

        Returns:

        """
        return self._config_file

    @config_file.setter
    def config_file(self, value):
        """"""
        self._config_file = value if value and isfile(value) else None

    @property
    def config(self):
        """ConfigParser property

        Returns:
            :obj:`configparser.ConfigParser`: config instance
        """
        return self._config

    @config.setter
    def config(self, value):
        """Update base dir with project dir"""
        value.set("tree.base", "path", str(self.project_dir))
        self._config = value

    def config_path(self, section: str, option_name: str, single_path: bool = False):
        """Format config option to list of Path objects or Path object if there is only one path

        Args:
            section (str): name of config section
            option (str): name of config option
            single_path (bool): flag to enable the return of single path

        Returns:
            config_paths (list, Path)
        """

        def glob_solver(input_path):
            """

            Args:
                input_path:

            Returns:

            """
            return (
                sorted(Path(dirname(input_path)).glob(basename(input_path)))
                if "*" in input_path
                else [""]
            )

        option = (
            self.config.get(section, option_name).split()
            if self.config.get(section, option_name)
            else []
        )
        # Get Path instance for each file in the related configparser option. Glob
        # patterns are unpacked here
        result = [
            Path(in_path) if "*" not in in_path else glob_path
            for in_path in option
            for glob_path in glob_solver(in_path)
        ]
        return result[0] if len(result) == 1 and single_path else result

    def config_subsection(self, subsection):
        """Filter sections to a uniq sub section"""
        return {
            section
            for section in self.config.sections()
            if section.startswith(f"{subsection}.")
        }


class GCommand(GBase):
    """Base geniac command"""

    def __init__(self, *args, **kwargs):
        """"""
        super().__init__(*args, **kwargs)

    @abstractmethod
    def run(self):
        """Main entry point for every geniac sub command"""
        raise NotImplementedError("This class should implement a basic run command")
