#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""test_base.py: Test geniac.base module"""

from configparser import ConfigParser

import pytest

from geniac.commands.base import GBase

__author__ = "Fabrice Allain"
__copyright__ = "Institut Curie 2020"


@pytest.fixture
def default_gbase():
    """Define a GCommand instance for testing"""
    return GBase()


def test_gbase(default_gbase):
    """Check if default GConfor has been instantiated correctly with all default GBase properties"""
    assert default_gbase.project_dir is None
    assert default_gbase.config_file is None
    assert isinstance(default_gbase.config, ConfigParser)
