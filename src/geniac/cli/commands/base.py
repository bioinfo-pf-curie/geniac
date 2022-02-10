#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""base.py: CLI geniac interface"""

import logging
import os
import subprocess
from abc import abstractmethod
from shutil import which

from geniac.cli.utils.base import GeniacBase

__author__ = "Fabrice Allain"
__copyright__ = "Institut Curie 2020"

_logger = logging.getLogger(__name__)


class GeniacCommand(GeniacBase):
    """Base geniac command"""

    def __init__(self, *args, **kwargs):
        """"""
        super().__init__(*args, **kwargs)

    def _subprocess_run(
        self,
        cmd: list,
        cmd_name: str = "",
        error_msg: str = "",
        debug_msg: str = "",
        **kwargs
    ):
        """Call subprocess run and log output"""
        cmd_out = None
        cmd = [which(cmd[0])] + cmd[1:]
        working_directory = kwargs.get("cwd", os.getcwd())
        self.info(
            "Running '%s' command:\n%s\n> %s",
            cmd_name,
            working_directory,
            " ".join(cmd),
        )
        try:
            cmd_out = subprocess.run(
                cmd,
                capture_output=kwargs.get("capture_output", True),
                check=kwargs.get("check", True),
                cwd=working_directory,
                encoding="utf8",
            )
        except subprocess.CalledProcessError as error:
            if error and error.stdout:
                self.info(
                    "%sCommand%s standard output:\n%s",
                    debug_msg + "\n" if debug_msg else "",
                    " " + cmd_name if cmd_name else "",
                    str(error.stdout).rstrip(),
                )
            self.critical(
                "%sCommand%s returned non-zero exit status:\n%s",
                error_msg + "\n" if error_msg else "",
                " " + cmd_name if cmd_name else "",
                str(error.stderr).rstrip(),
            )
        else:
            if cmd_out and cmd_out.stdout:
                self.info(
                    "%sCommand%s standard output:\n%s",
                    debug_msg + "\n" if debug_msg else "",
                    " " + cmd_name if cmd_name else "",
                    str(cmd_out.stdout).rstrip(),
                )
            if cmd_out and cmd_out.stderr:
                self.warning(
                    "Command%s standard error:\n%s",
                    " " + cmd_name if cmd_name else "",
                    str(cmd_out.stderr).rstrip(),
                )
        return cmd_out

    @abstractmethod
    def run(self):
        """Main entry point for every geniac sub command"""
        raise NotImplementedError("This class should implement a basic run command")
