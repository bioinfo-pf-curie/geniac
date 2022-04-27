#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""options.py: Geniac CMake option class"""

import logging
import re
import shutil
import os
from pathlib import Path

from geniac.cli.commands.init import GeniacInit

__author__ = "Fabrice Allain"
__copyright__ = "Institut Curie 2020"

_logger = logging.getLogger(__name__)


class GeniacClean(GeniacInit):
    """Geniac CMake Recipes class"""

    def __init__(
        self,
        *args,
        src_path: str = None,
        **kwargs,
    ):
        """Init flags specific to GRecipes command"""
        super().__init__(
            *args, src_path=src_path, post_clean=True, init_build=True, **kwargs
        )

    def clean_build(self):
        """Clean build directory"""

        build_dir = self.working_dirs["build"].as_posix()
        if os.path.isdir(build_dir):
            shutil.rmtree(build_dir)
            os.mkdir(build_dir)
            self.info("The folder '%s' has been cleaned.", build_dir)

    def run(self):
        """

        Returns:

        """
        self.clean_build()
