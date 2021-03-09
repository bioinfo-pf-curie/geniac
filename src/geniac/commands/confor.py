#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""confor.py: Geniac configuration file generator"""

import logging

from ..commands.base import GCommand

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
        pass
