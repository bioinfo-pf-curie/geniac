#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""install.py: Geniac init command"""

import logging
import os
from pathlib import Path
import subprocess

from geniac.cli.commands.base import GeniacCommand

__author__ = "Fabrice Allain"
__copyright__ = "Institut Curie 2021"

_logger = logging.getLogger(__name__)


class GeniacInit(GeniacCommand):
    """Geniac working directory initialization"""

    def __init__(
        self,
        *args,
        src_path: str = None,
        init_build: bool = False,
        pre_clean: bool = True,
        post_clean: bool = False,
        **kwargs
    ):
        """Init flags specific to GCheck command"""
        self.post_clean = post_clean
        self.pre_clean = pre_clean

        super().__init__(*args, src_path=src_path, init_work_path=True, **kwargs)

        # First cmake call into the build folder
        if init_build:
            self.init_build_folder()

    def init_build_folder(self):
        """Call cmake without options into the build folder"""
        self._subprocess_run(
            ["cmake", (self.working_dirs["src"] / "geniac").as_posix()],
            check=True,
            cwd=self.working_dirs["build"],
            cmd_name="CMake init",
        )

    def create_sub_shell(self):
        """Create a sub shell with the current conda env if it exists"""
        conda_prefix = os.environ.get("CONDA_PREFIX")
        # Force conda to activate the actual env with default_env var
        shell_env = os.environ | {
            "CONDA_DEFAULT_ENV": conda_prefix.split("/")[-1] if conda_prefix else ""
        }
        conda_env = Path(conda_prefix).name if conda_prefix else ""
        shell_env["CONDA_DEFAULT_ENV"] = conda_env or ""
        self.info(
            "Opening a sub shell with working directory set to %s",
            self.working_dir.resolve(),
        )
        
        self._subprocess_run(
            [os.environ.get("SHELL", os.environ.get("COMSPEC", "sh")), "cd"],
            cwd=self.working_dir.resolve(),
            env=shell_env,
            capture_output=False,
        )

    def run(self):
        """Entry point for init command"""
        if not self.post_clean:
            self.info("geniac init completed")

    def __exit__(self, *args):
        """Delete temporary folder if it has been correctly initialized and post_clean flag"""
        if self._tmp_dir and self.post_clean:
            self._tmp_dir.cleanup()
