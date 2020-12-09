#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""check.py: Linter command for geniac"""

import logging

from .command import GCommand

__author__ = "Fabrice Allain"
__copyright__ = "Institut Curie 2020"

_logger = logging.getLogger(__name__)


class GCheck(GCommand):
    """Linter command for geniac"""


    def check_config_file_content(self):
        """Check the structure of the repo

        Returns:

        """
        pass

    def get_labels_from_folders(self):
        """Parse information from recipes and modules folders

        Returns:

        """
        pass

    def get_labels_from_main(self):
        """Parse only the main.nf file

        Returns:

        """
        pass

    def get_labels_from_process_config(self):
        """Parse only the conf/process.config

        Returns:

        """
        pass

    def check_labels(self):
        """

        Returns:

        """
        pass

    def check_dependencies_dir(self):
        """

        Returns:

        """
        pass

    def check_env_dir(self):
        """

        Returns:

        """
        pass

    def run(self):
        """Execute the main routine

        Returns:

        """
        pass
        self.check_config_file_content()
        self.get_labels_from_folders()
        self.get_labels_from_main()
        self.get_labels_from_process_config()
        self.check_labels()
        self.check_dependencies_dir()
        self.check_env_dir()
