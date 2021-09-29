#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""base.py: CLI geniac interface"""

import logging
from abc import abstractmethod

from geniac.base import GBase

__author__ = "Fabrice Allain"
__copyright__ = "Institut Curie 2020"

_logger = logging.getLogger(__name__)


class GCommand(GBase):
    """Base geniac command"""

    def __init__(self, *args, **kwargs):
        """"""
        super().__init__(*args, **kwargs)

    @abstractmethod
    def run(self):
        """Main entry point for every geniac sub command"""
        raise NotImplementedError("This class should implement a basic run command")
