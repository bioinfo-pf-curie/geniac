#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""Geniac main script"""

import logging
from argparse import ArgumentParser
from json import loads
from logging.config import dictConfig
from sys import argv

from pkg_resources import resource_stream

from geniac import __version__
from geniac.commands.check import GCheck
from geniac.commands.confor import GConfor
from geniac.commands.deploy import GDeploy

__author__ = "Fabrice Allain"
__copyright__ = "Institut Curie 2020"

_logging_config = ("geniac", "conf/logging.json")
_logger = logging.getLogger(__name__)


def check_cmd(args):
    """Geniac Lint subcommand

    Args:

    Returns:
        :obj:`geniac.commands.check.GCheck`: geniac checker
    """
    return GCheck(**vars(args))


def conf_cmd(args):
    """Geniac conf subcommand

    Args:

    Returns:
        :obj:`geniac.commands.confor.GConfor`: geniac configurator
    """
    return GConfor(**vars(args))


# TODO: geniac run command
def deploy_cmd(args):
    """Geniac run subcommand

    Args:

    Returns:
        :obj:`geniac.commands.run.GRun`: geniac configurator
    """
    #
    # Use build Dir to run make install ?
    #
    return GDeploy(**vars(args))


def parse_args(args):
    """Parse command line parameters

    Args:
      args ([str]): command line parameters as list of strings

    Returns:
      :obj:`argparse.ArgumentParser`: argument parser
      :obj:`argparse.Namespace`: command line parameters namespace
    """
    # Top command
    parser = ArgumentParser(prog="geniac", description="Geniac Command Line Interface")
    parser.add_argument(
        "--version",
        action="version",
        version=f"geniac version-{__version__}",
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
    parser.add_argument(
        "--no-logfiles",
        dest="only_stream",
        help="Disable generation of log files",
        action="store_true",
    )
    parser.add_argument(
        "-c",
        "--config",
        help="Path to geniac config file (INI format)",
        dest="config_file",
        type=str,
        metavar="CONF.INI",
    )

    # Add sub command (lint and conf)
    subparsers = parser.add_subparsers(title="commands")

    # Geniac Check
    parser_lint = subparsers.add_parser(
        "lint", help="Evaluate the compatibility of a Nextflow project with Geniac"
    )
    parser_lint.add_argument(
        "project_dir",
        help="Path to Nextflow project directory",
        type=str,
        metavar="DIR",
    )
    parser_lint.set_defaults(func=check_cmd, which="lint")

    # Geniac Conf
    # parser_conf = subparsers.add_parser(
    #     "conf", help="Generate configuration files in a Nextflow project"
    # )
    # parser_conf.add_argument(
    #     "project_dir",
    #     help="Path to Nextflow project directory",
    #     type=str,
    #     metavar="INT",
    # )
    # parser_conf.set_defaults(func=conf_cmd, which="conf")

    # Geniac Conf
    # parser_deploy = subparsers.add_parser(
    #     "deploy", help="Deploy files in a Nextflow project"
    # )
    # parser_deploy.add_argument(
    #     "build_dir",
    #     help="Path to Geniac build directory",
    #     type=str,
    #     metavar="INT",
    # )
    # parser_deploy.set_defaults(func=deploy_cmd, which="deploy")

    return parser, parser.parse_args(args)


def setup_logging(loglevel, only_stream=False):
    """Setup basic logging

    Args:
      loglevel (int): minimum loglevel for emitting messages
      only_stream (bool): keep only Stream handlers
    """
    # Setup a default logger
    logging.basicConfig(level=loglevel if loglevel else logging.WARNING)
    # Update with file handlers defined in _logging_config file
    logging_config = loads(resource_stream(*_logging_config).read().decode())
    if only_stream and logging_config.get("handlers"):
        logging_config["handlers"] = {
            handler: handler_config
            for (handler, handler_config) in logging_config["handlers"].items()
            if handler_config.get("class") == "logging.StreamHandler"
        }
        # And remove them within loggers and root section
        for config_section in ("root", "loggers"):
            if logging_config.get(config_section, {}).get("handlers"):
                logging_config[config_section]["handlers"] = [
                    handler
                    for handler in logging_config[config_section]["handlers"]
                    if handler in logging_config["handlers"]
                ]

    dictConfig(logging_config)
    logging.captureWarnings(True)


def main(args):
    """Main entry point allowing external calls

    Args:
      args ([str]): command line parameter list
    """
    parser, args = parse_args(args)
    setup_logging(args.loglevel, args.only_stream)
    if "func" in args:
        _logger.info(
            "Start geniac %s command.", args.which if "which" in args else None
        )
        args.func(args).run()
    else:
        parser.print_help()
    _logger.debug("Script ends here.")


def run():
    """Entry point for console_scripts"""
    main(argv[1:])


if __name__ == "__main__":
    run()
