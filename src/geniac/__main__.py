#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""Geniac CLI interface"""

import argparse
import logging
import sys

from . import __version__
from .check import GCheck
from .confor import GConfor

__author__ = "Fabrice Allain"
__copyright__ = "Institut Curie 2020"

_logger = logging.getLogger(__name__)


def check(args):
    """Geniac Lint subcommand

    Args:

    Returns:
        :obj:`geniac.linter.GLinter`: geniac linter
    """
    _logger.debug("Starting geniac lint command...")
    return GCheck(args.get("project_dir"))


def conf(args):
    """Geniac conf subcommand

    Args:

    Returns:

    """
    _logger.debug("Starting geniac conf command...")
    return GConfor(args.get("project_dir"))


def parse_args(args):
    """Parse command line parameters

    Args:
      args ([str]): command line parameters as list of strings

    Returns:
      :obj:`argparse.Namespace`: command line parameters namespace
    """
    # Top command
    parser = argparse.ArgumentParser(
        prog="geniac", description="Geniac Command Line Interface"
    )
    parser.add_argument(
        "--version",
        action="version",
        version="geniac {ver}".format(ver=__version__),
    )
    parser.add_argument(
        "-v",
        "--verbose",
        dest="loglevel",
        help="set loglevel to INFO",
        action="store_const",
        const=logging.INFO,
    )
    parser.add_argument(
        "-vv",
        "--very-verbose",
        dest="loglevel",
        help="set loglevel to DEBUG",
        action="store_const",
        const=logging.DEBUG,
    )

    # Add sub command (lint and conf)
    subparsers = parser.add_subparsers(title="commands")

    # Geniac Check
    parser_lint = subparsers.add_parser(
        "lint", help="Evaluate the compatibility of a Nextflow project with Geniac"
    )
    parser_lint.add_argument("project_dir", metavar="DIR")
    parser_lint.set_defaults(func=check)

    # Geniac Conf
    parser_conf = subparsers.add_parser(
        "conf", help="Generate configuration files in a Nextflow project"
    )
    parser_conf.add_argument(
        "project_dir",
        help="Path to Nextflow project directory",
        type=str,
        metavar="INT",
    )
    parser_conf.set_defaults(func=conf)

    return parser.parse_args(args)


def setup_logging(loglevel):
    """Setup basic logging

    Args:
      loglevel (int): minimum loglevel for emitting messages
    """
    logformat = "[%(asctime)s] %(levelname)s:%(name)s:%(message)s"
    logging.basicConfig(
        level=loglevel, stream=sys.stdout, format=logformat, datefmt="%Y-%m-%d %H:%M:%S"
    )


def main(args):
    """Main entry point allowing external calls

    Args:
      args ([str]): command line parameter list
    """
    args = parse_args(args)
    setup_logging(args.loglevel)
    args.func(args).run()
    _logger.info("Script ends here")


def run():
    """Entry point for console_scripts"""
    main(sys.argv[1:])


if __name__ == "__main__":
    run()
