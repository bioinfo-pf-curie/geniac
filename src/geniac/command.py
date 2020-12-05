#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""Foobar.py: Description of what foobar does."""

import logging
from abc import ABC, abstractmethod
from configparser import ConfigParser
from os.path import isdir, isfile

from pkg_resources import resource_stream

__author__ = "Fabrice Allain"
__copyright__ = "Institut Curie 2020"

_logger = logging.getLogger(__name__)


class GCommand(ABC):
    """Abstract base class for Geniac commands"""

    default_config = "conf/geniac.ini"

    def __init__(self, project_dir=None, config_file=None):
        """

        Args:
            project_dir (str): path to the Nextflow Project Dir
            config_file (str): path to a configuration file (INI format)
        """
        self._project_dir = project_dir if project_dir and isdir(project_dir) else None
        self._config_file = config_file if config_file and isfile(config_file) else None
        self._config = self.load_config()

    def load_config(self):
        """Load configuration file(s)

        Returns:
            :obj:`configparser.ConfigParser`: config instance
        """
        config = ConfigParser(allow_no_value=True)
        # Read default config file
        with resource_stream(__name__, self.default_config) as conf:
            config.read_file(conf)
        if self._config_file:
            # Read configuration file
            config.read(self._config_file)
        return config

    @property
    def project_dir(self):
        """Project Dir path property

        Returns:

        """
        return self._project_dir

    @property
    def config(self):
        """ConfigParser property

        Returns:
            :obj:`configparser.ConfigParser`: config instance
        """
        return self._config

    @abstractmethod
    def run(self):
        """Main entry point for every geniac sub command"""
        pass
