#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""base.py: CLI geniac interface"""

import logging
from abc import ABC, abstractmethod
from configparser import ConfigParser, ExtendedInterpolation
from os.path import basename, dirname, isdir, isfile
from pathlib import Path

from pkg_resources import resource_stream

__author__ = "Fabrice Allain"
__copyright__ = "Institut Curie 2020"

_logger = logging.getLogger(__name__)


class GBase(ABC):
    """Abstract base class for Geniac commands"""

    default_config = "conf/geniac.ini"

    def __init__(self, project_dir=None, config_file=None):
        """

        Args:
            project_dir (str): path to the Nextflow Project Dir
            config_file (str): path to a configuration file (INI format)
        """
        self.project_dir = project_dir
        self.config_file = config_file
        self.config = self._load_config(self.config_file)

    def _load_config(self, config_file=None):
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
        config.read_string(
            resource_stream(__name__, self.default_config).read().decode()
        )
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
        self._project_dir = (
            Path(value).resolve() if value and isdir(value) else Path().cwd()
        )

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

    def config_paths(self, section, option):
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
            for glob_path in sorted(Path(dirname(in_path)).glob(basename(in_path)))
        ]

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
