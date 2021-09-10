#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""confor.py: Geniac configuration file generator"""

import logging

from geniac.commands.base import GCommand

__author__ = "Fabrice Allain"
__copyright__ = "Institut Curie 2020"

_logger = logging.getLogger(__name__)


class GConfor(GCommand):
    """Geniac configuration file generator"""

    def __init__(self, project_dir, *args, **kwargs):
        """Init flags specific to GCheck command"""
        super().__init__(*args, project_dir=project_dir, **kwargs)

    def run(self):
        """

        Returns:

        """
        # Create build dir
        # Run cmake command with all arguments
        # Run make command
        # Get generated config files from result folder
        # copy them to conf folder
        # Get generated config files from result folder
        # copy them to conf folder
        # warning if file already exists
        # ask if you want to update or not
        # Do the same for recipe files
        # /!\ NOT POSSIBLE FOR THE MOMENT GENIAC DOESNT ALLOW TO SAVE GENERATED RECIPES
        print(self.project_dir)
