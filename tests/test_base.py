#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""test_base.py: Test geniac.base module"""

from configparser import ConfigParser

import pytest

from geniac.cli.utils.base import GeniacBase, glob_solver

__author__ = "Fabrice Allain"
__copyright__ = "Institut Curie 2020"


@pytest.fixture
def default_gbase():
    """Define a GCommand instance for testing"""
    return GeniacBase()


def test_glob_solver(shared_datadir):
    """"""
    assert glob_solver(input_path=str(shared_datadir / "modules" / "*.txt")) == []
    assert glob_solver(
        input_path=str(shared_datadir / "modules" / "fromSource" / "*.txt")
    ) == [shared_datadir / "modules" / "fromSource" / "CMakeLists.txt"]
    assert glob_solver(
        input_path=str(shared_datadir / "modules" / "**" / "*.txt")
    ) == sorted(
        [
            shared_datadir / "modules" / "fromSource" / "CMakeLists.txt",
            shared_datadir / "modules" / "fromSource" / "helloWorld" / "CMakeLists.txt",
            shared_datadir / "modules" / "fromSource" / "dolorSit" / "CMakeLists.txt",
        ]
    )
    assert glob_solver(
        input_path=str(shared_datadir / "modules" / "**/hello*" / "*.txt")
    ) == sorted(
        [
            (
                shared_datadir
                / "modules"
                / "fromSource"
                / "helloWorld"
                / "CMakeLists.txt"
            ),
        ]
    )


def test_gbase(default_gbase):
    """Check if default GBase has been instantiated correctly with all default GBase properties"""
    assert default_gbase.config_file is None
    assert isinstance(default_gbase.default_config, ConfigParser)
