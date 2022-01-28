#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""options.py: Geniac CMake option class"""

import logging

from geniac.cli.commands.install import GeniacInstall

__author__ = "Fabrice Allain"
__copyright__ = "Institut Curie 2020"

_logger = logging.getLogger(__name__)


class GeniacTest(GeniacInstall):
    """Geniac CMake option class"""

    def __init__(
        self,
        profile: list,
        *args,
        src_path: str = None,
        check_cluster: bool = False,
        **kwargs,
    ):
        """Init flags specific to GOptions command"""
        self.check_cluster = check_cluster
        self.nxf_profiles = profile
        # Give the profile asked as mode opt in install cmd
        super().__init__(
            *args,
            src_path=src_path,
            mode=profile,
            config_section="install",
            **kwargs,
        )

    def test(self):
        """Launch Make test commands in the folder"""
        for nxf_profile in self.nxf_profiles:
            self._subprocess_run(
                [
                    "make",
                    f"test_{nxf_profile + '_cluster' if self.check_cluster else nxf_profile}",
                ],
                capture_output=True,
                cmd_name="Make Test",
                check=True,
                cwd=self.working_dirs["build"],
            )

    def run(self):
        """

        Returns:

        """
        #self.build()
        self.test()
