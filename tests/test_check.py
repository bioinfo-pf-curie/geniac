#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""Foobar.py: Description of what foobar does."""

import os

import pytest

from geniac.check import GCheck

__author__ = "Fabrice Allain"
__copyright__ = "Institut Curie 2020"


@pytest.fixture
def default_gcheck():
    """Define a GConfor instance for testing"""
    return GCheck()


def test_gcheck(default_gcheck):
    """Check if we can instantiate a GConfor object with a folder"""
    assert default_gcheck.project_dir == os.getcwd()
