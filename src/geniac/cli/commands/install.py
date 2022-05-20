#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""install.py: Geniac install command"""

import logging
import re
import os
from gettext import gettext as _
from importlib.resources import files
from pathlib import Path

from geniac.cli.commands.init import GeniacInit
from geniac.cli.utils.base import CMAKE_OPTION_PREFIX, MethodRecord

__author__ = "Fabrice Allain"
__copyright__ = "Institut Curie 2020"

_logger = logging.getLogger(__name__)


class GeniacInstall(GeniacInit):
    """Geniac configuration file generator"""

    # CMAKE FILES ANALYZED TO GET CACHE VARIABLES
    CMAKE_CACHE_FILES = [files("geniac").joinpath("cmake/stepSetVariables.cmake")]
    # https://regex101.com/r/bppizX/1
    CMAKE_CACHE_RE = re.compile(
        r"(?P<cmake_set>set\((?P<cmake_var>\w+)\s+(?P<cmake_values>("
        r"(?P<cmake_value_quote>[\"'])(?P<cmake_value>[\"':.\w/,\-(]*))"
        r"(?P=cmake_value_quote)\s+)*CACHE\s+(?P<cmake_type>\w+)\s+"
        r"(?P<cmake_docstring>(?P<quote>(?P<simple>')|(?P<double>\"))"
        r"(?(simple)[\":.\w\s/,\-()]+|[\':.\w\s/,\-()]+)(?P=quote))\s*\))"
    )

    def __init__(
        self,
        *args,
        project_path: str = None,
        install_path: str = None,
        no_pre_clean: bool = False,
        no_post_clean: bool = False,
        **kwargs,
    ):
        """Init flags specific to GCheck command"""

        super().__init__(
            *args,
            project_path=project_path,
            init_build=True,
            pre_clean=True,
            post_clean=not no_post_clean,
            **kwargs,
        )
        # Should we clean build dir if it has been initialized
        self.pre_clean = not no_pre_clean
        self.install_path = (
            Path(install_path).resolve()
            if install_path
            else self.working_dir / "install"
        )
        # add cmake options in a specific scope
        self.cmake_options = self._get_cmake_options(**kwargs)
        self._is_sudo = None

    @property
    def is_sudo(self):
        """Should we launch make step in sudo mode ?"""
        if not self._is_sudo:
            self._is_sudo = self._check_sudo()
        return self._is_sudo

    def _get_cmake_options(self, mode: str = None, **kwargs) -> list:
        """
        Get cmake options in kwargs and merge them with the ones coming from a specific mode
        (if mode_option is not empty)

        Args:
            mode_option: install mode configured in geniac.install.modes section
            **kwargs:

        Returns:

        """
        cmake_options = [
            "".join(
                [
                    f"-D{option.removeprefix(CMAKE_OPTION_PREFIX)}",
                    f'={value}'.strip()
                    if not isinstance(value, bool) and value
                    else "=ON"
                    if value
                    else "=OFF",
                ]
            )
            for option, value in kwargs.items()
            if option.startswith(CMAKE_OPTION_PREFIX) and value
        ]
        if mode:
            mode_section = f"{self.config_section}.modes"
            cmake_mode_options = (
                self.default_config.get(mode_section, mode).strip().split("\n")
                if self.default_config.has_option(mode_section, mode)
                else []
            )
            cmake_options = [
                _ for _ in cmake_options if _ not in cmake_mode_options
            ] + cmake_mode_options
        return cmake_options

    def _check_sudo(self) -> bool:
        """Guess if the CMake/Make commands should be run in sudo mode"""

        is_sudo = False

        cmake_sudo_options = (
            self.default_config.get(self.config_section, "cmakeSudoOptions")
            .strip()
            .split("\n")
        )
        cmake_fakeroot_options = (
            self.default_config.get(self.config_section, "cmakeFakeRootOptions")
            .strip()
            .split("\n")
        )
        for cmake_option in self.cmake_options:
            if cmake_option in cmake_sudo_options:
                is_sudo = True
            if cmake_option in cmake_fakeroot_options:
                return False
        return is_sudo

    @staticmethod
    def _get_cmake_cache_vars(content: str) -> list:
        """Get content of CMake CACHE variables from CMake file content"""
        return [
            match.groupdict()
            for match in GeniacInstall.CMAKE_CACHE_RE.finditer(content)
        ]

    @staticmethod
    def get_cmake_cache_vars():
        """Get cmake cache vars from cmake files found in the package"""
        cmake_cache_vars = []
        for cmake_file in GeniacInstall.CMAKE_CACHE_FILES:
            if cmake_file.is_file():
                cmake_cache_vars += GeniacInstall._get_cmake_cache_vars(
                    cmake_file.read_text()
                )
        return cmake_cache_vars

    @classmethod
    def get_cmake_cache_args(cls) -> list[MethodRecord]:
        """Return a list of methodRecord for argparse corresponding to cmake cahe options"""

        cmake_cache_args = []

        def _format_cmake_default(cmake_type, cmake_value):
            """Format CMake variable default value according to cmake type"""
            return (
                False
                if cmake_value == "OFF" and cmake_type == "BOOL"
                else True
                if cmake_value == "ON" and cmake_type == "BOOL"
                else cmake_value
            )

        def _get_argument_action(default_value):
            """Get correct argparse action according to default value"""
            return (
                "store_true"
                if default_value is False
                else "store_false"
                if default_value is True
                else "store"
            )

        cmake_cache_vars = cls.get_cmake_cache_vars()

        for cmake_cache_var in cmake_cache_vars:
            formatted_default = _format_cmake_default(
                cmake_cache_var.get("cmake_type").strip(),
                cmake_cache_var.get("cmake_value").strip(),
            )
            formatted_action = _get_argument_action(formatted_default)

            cmake_cache_args.append(
                MethodRecord(
                    args=[f"--{cmake_cache_var.get('cmake_var')}"],
                    kwargs={
                        "help": _(
                            cmake_cache_var.get("cmake_docstring", "").strip(
                                cmake_cache_var.get("quote")
                            )
                        ),
                        "dest": f"{CMAKE_OPTION_PREFIX}{cmake_cache_var.get('cmake_var')}",
                        "default": formatted_default,
                        "action": formatted_action,
                    },
                )
            )

        return cmake_cache_args

    def build(self):
        """Launch CMake build command with cmake options inferred from mode"""
        self._subprocess_run(
            f'cmake {(self.working_dirs["src"] / "geniac").as_posix()} '
            f"-DCMAKE_INSTALL_PREFIX={self.install_path.as_posix()} "
            f"{' '.join(self.cmake_options)}".split(),
            capture_output=False,
            cmd_name="CMake build",
            check=True,
            cwd=self.working_dirs["build"],
        )

    def install(self):
        """Launch Make installation command in the folder"""
        if self.is_sudo:
            self.warning(
                "Detected options require sudo privileges. Will try to launch in sudo mode"
            )
        user_uid=str(os.getuid())
        user_gid=str(os.getgid())
        chown_command='sudo -S -k chown -R ' + user_uid + ':' + user_gid + ' ' + (self.working_dirs["build"]).as_posix()
        commands = {
            "make": f"{'sudo -S -k ' if self.is_sudo else ''}make",
            "chown": f"{chown_command if self.is_sudo else 'echo OK'}",
            "make install": "make install",
        }
        for command_name, command in commands.items():
            self._subprocess_run(
                command.split(),
                capture_output=(command.split()[0] != "sudo"),
                cmd_name=command_name,
                check=True,
                cwd=self.working_dirs["build"],
            )

    def run(self):
        """Geniac Install entry point"""
        self.build()
        self.install()
