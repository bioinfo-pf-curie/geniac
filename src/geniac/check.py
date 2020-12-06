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

    def run(self):
        """Execute the main routine

        Returns:

        """
        pass
