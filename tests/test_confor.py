#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""Foobar.py: Description of what foobar does."""

import pytest

from geniac.confor import GConfor

__author__ = "Fabrice Allain"
__copyright__ = "Institut Curie 2020"

# TODO: use temporary directory/files fixtures in pytest to generate test data
# https://docs.pytest.org/en/latest/tmpdir.html


@pytest.fixture
def gconfor_data(shared_datadir):
    """Define a GConfor instance for testing"""
    return GConfor(shared_datadir)


def test_gconfor(gconfor_data):
    """Check if we can instantiate a GConfor object with a folder"""
    # assert default_gconfor.project_dir == Path().cwd()
    pass
