#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""options.py: Geniac CMake option class"""

import logging
import re

from geniac.cli.commands.init import GeniacInit

__author__ = "Fabrice Allain"
__copyright__ = "Institut Curie 2020"

_logger = logging.getLogger(__name__)


class GeniacOptions(GeniacInit):
    """Geniac CMake option class"""

    def __init__(
        self,
        *args,
        src_path: str = None,
        **kwargs,
    ):
        """Init flags specific to GOptions command"""
        super().__init__(
            *args, src_path=src_path, post_clean=True, init_build=True, **kwargs
        )

    def _format_cmake_help(self, cmake_output: list) -> list:
        """Format CMake -LAH output as a comprehensible list"""
        formatted_output = []
        cmake_reg = re.compile(
            self.default_config.get("geniac.install", "cmakeOutputPattern")
        )
        for line in cmake_output:
            if match := cmake_reg.match(line):
                groups = match.groupdict()
                formatted_output += [
                    (
                        groups.get("option_name"),
                        groups.get("option_type"),
                        groups.get("option_value"),
                    )
                ]
        return formatted_output

    def cmake_help(self, format_output: bool = False) -> list:
        """Return help formatted from cmake -LAH command"""

        cmake_lah = (
            self._subprocess_run(
                ["cmake", "-LAH", (self.working_dirs["src"] / "geniac").as_posix()],
                check=True,
                cwd=self.working_dirs["build"],
                cmd_name="CMake -LAH",
            )
            if self.working_dirs.get("src")
            else None
        )

        return (
            self._format_cmake_help([_ for _ in cmake_lah.stdout.split("\n") if _])
            if cmake_lah and cmake_lah.stdout and format_output
            else [cmake_lah.stdout]
            if cmake_lah and cmake_lah.stdout
            else []
        )

    def run(self):
        """

        Returns:

        """
        cmake_help = self.cmake_help(format_output=True)
        # Print in the console cmake_help if
        if self.logger.root.level >= logging.WARNING:
            for _ in cmake_help:
                print(f"{_[0]}:{_[1]}='{_[2]}'")
