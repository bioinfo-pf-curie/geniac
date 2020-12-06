#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""Foobar.py: Description of what foobar does."""

import pytest

from geniac.confor import GConfor

__author__ = "Fabrice Allain"
__copyright__ = "Institut Curie 2020"


@pytest.fixture
def default_gconfor():
    """Define a GConfor instance for testing"""
    return GConfor()


def test_gconfor(default_gconfor):
    """Check if we can instantiate a GConfor object with a folder"""
    assert default_gconfor.project_dir is None
