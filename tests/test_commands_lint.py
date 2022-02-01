#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""test_check.py: Test geniac.check module"""

from pathlib import Path

import pytest

from geniac.cli.commands.lint import GeniacLint

__author__ = "Fabrice Allain"
__copyright__ = "Institut Curie 2020"


@pytest.fixture
def gcheck_data(shared_datadir):
    """Instantiate GCheck command with shared datadir from pytest-datadir"""
    return GeniacLint(shared_datadir)


def test_data_gcheck(gcheck_data, shared_datadir):
    """Check if  GChek with data has been instantiated correctly"""
    assert gcheck_data.src_path == Path(shared_datadir)
