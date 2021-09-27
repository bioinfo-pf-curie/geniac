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

from geniac.conf.logging import LogMixin

__author__ = "Fabrice Allain"
__copyright__ = "Institut Curie 2020"

_logger = logging.getLogger(__name__)


def _path_checker(value: str):
    """
    Exit if the path is not correct
    """
    if not (path := Path(value)) and not path.is_dir():
        _logger.critical("Path %s does not exist.", path)
        sys.exit(1)
    return path.resolve()


def glob_solver(input_path: str, lazy_flag: bool = False):
    """
    Use native glob solver to expand glob patterns from an input path

    Args:
        input_path (str): input file path
        lazy_flag (bool): expand to existing paths or generate paths without any check

    Returns:
        output_paths (list): list of expanded paths
    """
    for glob_string in ("**", "*"):
        if glob_string in input_path:
            # Get the tuple of elements with 3 parts (base_dir, glob_pattern, filename)
            input_path_parts = input_path.partition(glob_string)
            (stem_path, file_name) = (
                Path(dirname(input_path_parts[0])).resolve(),
                basename(input_path),
            )
            no_glob_file = "*" not in file_name
            # IF LAZY
            #   IF no_glob_file THEN we make a pattern without the file_name and add it
            #       to the path after the glob expansion
            #   ELSE THEN we make a pattern with the file_name and doesn't add it after the glob
            #       expansion
            # ELSE THEN we make a pattern with the file_name and doesn't add it after the glob
            #   expansion
            glob_pattern = "/".join(
                [
                    path_elt
                    for path_elt in [
                        basename(input_path_parts[0]),
                        input_path_parts[1] + dirname(input_path_parts[2]).rstrip("/")
                        if basename(input_path_parts[2]) == file_name
                        else "" + dirname(input_path_parts[2]).rstrip("/"),
                        "" if lazy_flag and no_glob_file else file_name,
                    ]
                    if path_elt
                ]
            )
            return (
                [
                    path / Path(file_name)
                    for path in stem_path.glob(glob_pattern)
                    if path.is_dir()
                    and not path.resolve().samefile(stem_path.resolve())
                ]
                if lazy_flag and no_glob_file
                else sorted(stem_path.glob(glob_pattern))
            )
    return [""]


class GBase(ABC, LogMixin):
    """Abstract base class for Geniac commands"""

    DEFAULT_CONFIG = ("geniac", "conf/geniac.ini")

    def __init__(
        self,
        project_dir: str = None,
        build_dir: str = None,
        config_file: str = None,
        **kwargs,
    ) -> None:
        """

        Args:
            project_dir (str): path to the Nextflow Project Dir
            config_file (str): path to a configuration file (INI format)
        """
        super().__init__()
        self._project_dir = None
        self._build_dir = None
        if project_dir:
            self.project_dir = project_dir
        if build_dir:
            self.build_dir = build_dir
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
        self._project_dir = _path_checker(value)

    @property
    def build_dir(self):
        """Build Dir path property"""
        return self._build_dir

    @build_dir.setter
    def build_dir(self, value):
        """If value is not a directory, set the project dir to the current directory"""
        self._build_dir = _path_checker(value)

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

    def config_path(
        self,
        section: str,
        option_name: str,
        single_path: bool = False,
        lazy_glob: bool = False,
    ):
        """Format config option to list of Path objects or Path object if there is only one path

        Args:
            option_name:
            section (str): name of config section
            option_name (str): name of config option
            single_path (bool): flag to enable the return of single path
            lazy_glob (bool): use lazy glob solver without any check

        Returns:
            config_paths (list, Path)
        """

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
            for glob_path in glob_solver(in_path, lazy_flag=lazy_glob)
        ]
        return result[0] if len(result) == 1 and single_path else result

    def config_subsection(self, subsection):
        """Filter sections to a uniq sub section"""
        return (
            section
            for section in self.config.sections()
            if section.startswith(f"{subsection}.")
        )

    def get_config_option_list(self, section: str, option: str) -> list:
        """Get option list related to a specific section from config
        Args:
            section:
            option:

        Returns:
            list
        """
        return (
            list(filter(None, config_option.split("\n")))
            if (config_option := self.config.get(f"scope.{section}", option))
            else []
        )

    def get_config_section_items(self, section: str) -> dict:
        """Get section items if they exist or return an empty dic"""
        return {
            key: value.split("\n")
            for key, value in (
                self.config.items(section) if self.config.has_section(section) else []
            )
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
