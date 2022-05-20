#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""base.py: Define GBase class and several utils functions"""

import errno
import logging
import os
import re
import sys
from abc import ABC
from configparser import ConfigParser, ExtendedInterpolation
from distutils.dir_util import copy_tree
from json import loads as json_loads
from os.path import basename, dirname, isfile
from pathlib import Path
from shutil import rmtree
from sys import exit as sys_exit
from tempfile import TemporaryDirectory, mkdtemp
from typing import NamedTuple

import shutil

import validators
from git import Repo

# TODO: use importlib.resources in the future
# https://importlib-resources.readthedocs.io/en/latest/migration.html#pkg-resources-resource-filename
from pkg_resources import resource_filename, resource_stream

from geniac.cli.utils.logging import LogMixin
from geniac import __version__

__author__ = "Fabrice Allain"
__copyright__ = "Institut Curie 2021"

_logger = logging.getLogger(__name__)
CMAKE_OPTION_PREFIX = "cmake_"
# Sadly, Python fails to provide the following magic number for us.
ERROR_INVALID_NAME = 123
"""
Windows-specific error code indicating an invalid pathname.

See Also
----------
https://docs.microsoft.com/en-us/windows/win32/debug/system-error-codes--0-499-
    Official listing of all such codes.
"""

### Geniac variables
GENIAC_CONFIG_FILES=['conda.config',
        'multiconda.config',
        'path.config',
        'multipath.config',
        'docker.config',
        'podman.config',
        'singularity.config',
        'cluster.config']

def load_logging_config(logging_config_path) -> dict:
    """Read logging config file in json format and return it as a dict"""
    with logging_config_path.open("rb") as logging_config_file:
        return json_loads(logging_config_file.read().decode())


def _dir_checker(value: str):
    """
    Exit if the path is not correct
    """
    path = value if isinstance(value, Path) else Path(value)
    if not path and not path.is_dir():
        _logger.critical("Path %s does not exist.", path)
        sys_exit(1)
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


def is_pathname_valid(pathname: str) -> bool:
    """
    CF https://stackoverflow.com/a/34102855
    `True` if the passed pathname is a valid pathname for the current OS;
    `False` otherwise.
    """
    # If this pathname is either not a string or is but is empty, this pathname
    # is invalid.
    try:
        if not isinstance(pathname, str) or not pathname:
            return False

        # Strip this pathname's Windows-specific drive specifier (e.g., `C:\`)
        # if any. Since Windows prohibits path components from containing `:`
        # characters, failing to strip this `:`-suffixed prefix would
        # erroneously invalidate all valid absolute Windows pathnames.
        _, pathname = os.path.splitdrive(pathname)

        # Directory guaranteed to exist. If the current OS is Windows, this is
        # the drive to which Windows was installed (e.g., the "%HOMEDRIVE%"
        # environment variable); else, the typical root directory.
        root_dirname = (
            os.environ.get("HOMEDRIVE", "C:")
            if sys.platform == "win32"
            else os.path.sep
        )
        assert os.path.isdir(root_dirname)  # ...Murphy and her ironclad Law

        # Append a path separator to this directory if needed.
        root_dirname = root_dirname.rstrip(os.path.sep) + os.path.sep

        # Test whether each path component split from this pathname is valid or
        # not, ignoring non-existent and non-readable path components.
        for pathname_part in pathname.split(os.path.sep):
            try:
                os.lstat(root_dirname + pathname_part)
            # If an OS-specific exception is raised, its error code
            # indicates whether this pathname is valid or not. Unless this
            # is the case, this exception implies an ignorable kernel or
            # filesystem complaint (e.g., path not found or inaccessible).
            #
            # Only the following exceptions indicate invalid pathnames:
            #
            # * Instances of the Windows-specific "WindowsError" class
            #   defining the "winerror" attribute whose value is
            #   "ERROR_INVALID_NAME". Under Windows, "winerror" is more
            #   fine-grained and hence useful than the generic "errno"
            #   attribute. When a too-long pathname is passed, for example,
            #   "errno" is "ENOENT" (i.e., no such file or directory) rather
            #   than "ENAMETOOLONG" (i.e., file name too long).
            # * Instances of the cross-platform "OSError" class defining the
            #   generic "errno" attribute whose value is either:
            #   * Under most POSIX-compatible OSes, "ENAMETOOLONG".
            #   * Under some edge-case OSes (e.g., SunOS, *BSD), "ERANGE".
            except OSError as exc:
                if hasattr(exc, "winerror"):
                    if exc.winerror == ERROR_INVALID_NAME:
                        return False
                elif exc.errno in {errno.ENAMETOOLONG, errno.ERANGE}:
                    return False
    # If a "TypeError" exception was raised, it almost certainly has the
    # error message "embedded NUL character" indicating an invalid pathname.
    except TypeError:
        return False
    # If no exception was raised, all path components and hence this
    # pathname itself are valid. (Praise be to the curmudgeonly python.)
    else:
        return True
    # If any other exception was raised, this is an unrelated fatal issue
    # (e.g., a bug). Permit this exception to unwind the call stack.
    #
    # Did we mention this should be shipped with Python already?


class MethodRecord(NamedTuple):
    """Default class to fill args and kwargs for a method"""

    args: list
    kwargs: dict


class GeniacBase(ABC, LogMixin):
    """Abstract base class for Geniac commands"""

    DEFAULT_CONFIG = ("geniac", "cli/data/conf/geniac.ini")
    CACHE_NAME = ".geniac"
    SRC_NAME = "src"
    BUILD_NAME = "build"

    def __init__(
        self,
        src_path: str = Path.cwd(),
        config_file: str = None,
        working_dir: str = None,
        pre_clean: bool = False,
        post_clean: bool = True,
        init_work_path: bool = False,
        **kwargs,
    ) -> None:
        """

        Args:
            src_path (str): path to the Nextflow Project Dir
            config_file (str): path to a configuration file (INI format)
            working_dir (str): path to a geniac working directory
            pre_clean (bool): should we clean every build folder before running any cmd ?
            post_clean (bool): should we clean every temporary folder at the end of the execution ?
            init_work_path (bool): should we init a working directory with source files inside ?
        """
        super().__init__()
        self.config_section = (
            re.sub(r"(?<!^)(?=[A-Z])", ".", self.__class__.__name__).lower()
            if not (_config_section := kwargs.get("config_section"))
            else _config_section
        )

        # Project path is optional but if it is not a valid url or a valid path, it will correspond
        # to the default config project.metadata.url
        self._src_path = None
        (self.project_type, self.src_is_working_dir) = self._get_src_type(src_path)
        self.src_path = src_path

        # Init and load config files
        self.default_config_file = Path(resource_filename(*self.DEFAULT_CONFIG))
        self.config_file = Path(config_file) if config_file else None
        self.default_config = self._load_config(config_file=self.config_file)
        self._update_default_config(**kwargs)

        self._tmp_dir = None

        self.working_dir_is_valid = self._check_working_dir(working_dir)
        # Working dir correspond to tmp dir or working_dir
        self.working_dir = (
            self.src_path.parent.resolve()
            if self.project_type == "wd"
            else Path(working_dir).resolve()
            if working_dir and self.working_dir_is_valid
            else Path().cwd()
        )
        self.working_dirs = {
            "build": self.working_dir / self.BUILD_NAME,
            "src": self.working_dir / self.SRC_NAME,
            "cache": self.working_dir / self.CACHE_NAME,
        }

        if src_path and init_work_path:
            self.init_working_path(
                working_dir,
                post_clean,
                pre_clean,
                kwargs.get(
                    "branch", self.default_config["project.metadata"].get("branch")
                ),
            )

    def _load_config(self, config_file: Path = None):
        """Load default configuration file and update option with config_file

        Returns:
            :obj:`configparser.ConfigParser`: config instance
        """
        config = ConfigParser(
            interpolation=ExtendedInterpolation(), allow_no_value=True
        )

        # Read default config file
        config.optionxform = str
        config.read_string(resource_stream(*self.DEFAULT_CONFIG).read().decode())
        if config_file:
            # Read configuration file
            config.read(config_file)
        return config

    def _update_default_config(self, **kwargs):
        """Update default config according to arguments in kwargs which should come from argparse
        in the constructor"""
        if self.config_section in self.default_config.sections():
            for option in self.default_config.options(self.config_section):
                if option_value := kwargs.get(option):
                    self.default_config.set(self.config_section, option, option_value)

    def _check_working_dir(self, working_dir: str, info: bool = True) -> bool:
        """Check if given working dir is valid"""
        if working_dir and (
            not str(working_dir).startswith("ssh")
            or not str(working_dir).startswith("http")
        ):
            working_path = Path(working_dir)
            cache_path = working_path / self.CACHE_NAME
            is_existing_path = working_path.exists()
            is_valid_path = is_pathname_valid(working_path.as_posix())
            is_empty_dir = working_path.is_dir() and not list(working_path.iterdir())
            has_cache_dir = is_existing_path and cache_path.exists()
            # If empty folder or uninitialized folder or folder with .geniac sub folder
            if (
                (working_dir and is_empty_dir)
                or (is_valid_path and not is_existing_path)
                or has_cache_dir
            ):
                return True
        if info:
            self.info(
                "Working directory %s is not an empty directory, a valid path or doesn't have "
                "expected cache folder %s. A temporary folder will be created instead",
                working_dir or "",
                self.CACHE_NAME,
            )
        return False

    def _get_src_type(self, src_path: [str, None]) -> (str, bool):
        """Check if given input is a valid url or a valid project path"""
        self.debug("Checking if source path %s is a path or an url", src_path)
        is_working_dir = self._check_working_dir(src_path, info=False)
        return (
            ("url", False)
            if src_path and validators.url(str(src_path))
            or (src_path and str(src_path).startswith("ssh"))
            or (src_path and str(src_path).startswith("http"))
            else ("wd", is_working_dir)
            if is_working_dir
            else ("path", False)
            if src_path and Path(src_path).exists()
            else ("default", False)
        )

    def init_working_tree(self):
        """Initialize working directory with basic tree structure"""
        self.info(
            "Initializing geniac working directory tree at %s",
            self.working_dir.as_posix(),
        )
        if not self.working_dir.exists():
            self.working_dir.mkdir(parents=True)
        for nested_dir_name, nested_dir_path in self.working_dirs.items():
            if not nested_dir_path.exists():
                nested_dir_path.mkdir()
            elif nested_dir_path.is_dir():
                self.warning(
                    "%s folder %s already exists",
                    nested_dir_name.capitalize(),
                    nested_dir_path.as_posix(),
                )
            else:
                self.error(
                    "Path %s should be an empty folder", nested_dir_path.as_posix()
                )

    def init_working_src_folder(self, git_branch: str):
        """Copy or clone the project into src temp folder"""
        # If src_path, copy it into src
        if self.project_type == "path":
            self.info(
                "Copy content of %s into geniac working directory %s",
                self.src_path.as_posix(),
                self.working_dirs["src"].as_posix(),
            )
            copy_tree(self.src_path.as_posix(), self.working_dirs["src"].as_posix())
        # Else try to clone project.metadata.url into src folder
        elif self.project_type in ("url", "default"):
            self.info(
                "Using the URL %s to clone %s branch into geniac working directory %s",
                self.src_path,
                git_branch or "default",
                self.working_dirs["src"].as_posix(),
            )

            try:
                Repo.clone_from(
                    self.src_path,
                    self.working_dirs["src"],
                    branch=git_branch,
                    multi_options=["--recurse-submodules"],
                )
            except Exception as error:
                self.error(
                    "Unable to clone the project into the temporary directory.\n%s",
                    error,
                )
           
        else:
            self.error("Unable to initialize src folder at %s", self.src_path)

        ############################################################################
        ### Delete files generated by geniac if they have been pushed in the src dir
        ############################################################################
        for config_file in GENIAC_CONFIG_FILES:
            config_file_path = self.working_dirs["src"].as_posix() + "/conf/" + config_file
            if os.path.isfile(config_file_path):
                os.remove(config_file_path)
                self.info(f"File {config_file} was present in the repo. It has been deleted such that it can be generated by geniac.")

        ######################################################################
        ### Use src/geniac which corresponds to the same version of geniac CLI
        ######################################################################
        if os.path.isdir(self.working_dirs["src"].as_posix()+'/geniac'):
            shutil.rmtree(self.working_dirs["src"].as_posix()+'/geniac')
            shutil.copytree(os.path.dirname(__file__) + '/../../repo', self.working_dirs["src"].as_posix()+'/geniac')
            self.info(f"The geniac folder bas been replaced using the geniac folder from the python package.")
        else:
            shutil.copytree(os.path.dirname(__file__) + '/../../repo', self.working_dirs["src"].as_posix()+'/geniac')
            self.info(f"The geniac directory does not exist. It has been created using the geniac folder from the python package.")

    def init_working_path(
        self, working_dir: str, post_clean: bool, pre_clean: bool, git_branch: str
    ):
        """Init working dir and source dir"""
        # Setup working dir

        # IF working_dir has been given and source path is a valid geniac working directory then
        # stop the program
        if self.src_is_working_dir and self.working_dir_is_valid:
            self.critical(
                "Both source path and working directory are geniac working directory. "
                "If the working directory has been given, the source path should be a "
                "valid Nextflow project"
            )

        self.info("project_type: %s", self.project_type)

        if self.project_type != "wd":
            if not self.working_dir_is_valid:
                # Initialize TMP dir if there is no working directory
                self._tmp_dir = TemporaryDirectory() if post_clean else mkdtemp()

                if not post_clean:
                    self.warning(
                        "Post clean option hasn't been set. The temporary folder '%s' will "
                        "not been cleaned at the end !",
                        self._tmp_dir,
                    )

                self.working_dir = (
                    Path(self._tmp_dir.name).resolve()
                    if post_clean
                    else Path(self._tmp_dir).resolve()
                )
                self.working_dirs = {
                    "build": self.working_dir / self.BUILD_NAME,
                    "src": self.working_dir / self.SRC_NAME,
                    "cache": self.working_dir / self.CACHE_NAME,
                }

            # Create basic tree structure
            self.init_working_tree()

        # Clean build directory if asked
        if pre_clean:
            self.clean_build()

        # Copy or clone the project into src temp folder
        if self.project_type != "wd":
            self.init_working_src_folder(git_branch)

    def clean_build(self):
        """Clean build directory"""
        if self.working_dirs["build"].exists():
            self.info("Cleaning build directory %s", self.working_dirs["build"])
            # TODO: catcher l'erreur
            rmtree(self.working_dirs["build"], ignore_errors=True)
            self.working_dirs["build"].mkdir()

    @property
    def src_path(self):
        """Project Dir path property"""
        return self._src_path

    @src_path.setter
    def src_path(self, value):
        """If value is not a directory, set the project dir to the current directory"""
        self._src_path = (
            (Path(value) / "src").resolve()
            if self.project_type == "wd"
            else _dir_checker(value)
            if self.project_type == "path"
            else value
            if self.project_type == "url"
            else value
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
    def default_config(self):
        """ConfigParser property

        Returns:
            :obj:`configparser.ConfigParser`: config instance
        """
        return self._config

    @default_config.setter
    def default_config(self, value):
        """Update base dir with project dir"""
        value.set("tree.base", "path", str(self.src_path))
        self._config = value

    def get_config_path(
        self,
        section: str,
        option_name: str,
        single_path: bool = False,
        lazy_glob: bool = False,
    ):
        """Format config option to list of Path objects or Path object if there is only one path

        Args:
            section (str): name of config section
            option_name (str): name of config option
            single_path (bool): flag to enable the return of single path
            lazy_glob (bool): use lazy glob solver without any check

        Returns:
            config_paths (list, Path)
        """

        option = (
            self.default_config.get(section, option_name).split()
            if self.default_config.get(section, option_name)
            else []
        )
        # Get Path instance for each file in the related configparser option. Glob
        # patterns are unpacked here
        result = sorted(
            [
                Path(in_path) if "*" not in in_path else glob_path
                for in_path in option
                for glob_path in glob_solver(in_path, lazy_flag=lazy_glob)
            ]
        )
        return result[0] if len(result) == 1 and single_path else result

    def get_config_subsection(self, subsection):
        """Filter sections to a uniq sub section"""
        return (
            section
            for section in self.default_config.sections()
            if section.startswith(f"{subsection}.")
        )

    def get_config_scope_option_list(self, section: str, option: str) -> list:
        """
        Format option values related to a specific scope section in geniac.ini configuration
        file as a list

        Args:
            section (str): Name of the section in the configuration file (geniac.ini)
            option: Name of the option within the section

        Returns:
            list
        """
        return (
            list(filter(None, config_option.split("\n")))
            if (config_option := self.default_config.get(f"scope.{section}", option))
            else []
        )

    def get_config_section_items(self, section: str) -> dict:
        """Get section items if they exist or return an empty dic"""
        return {
            key: value.split("\n")
            for key, value in (
                self.default_config.items(section)
                if self.default_config.has_section(section)
                else []
            )
        }

    def __exit__(self, *args):
        """Delete temporary folder if it has been correctly initialized"""
        if self._tmp_dir:
            self._tmp_dir.cleanup()
