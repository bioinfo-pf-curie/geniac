#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""Geniac main script"""

import logging
from argparse import ArgumentDefaultsHelpFormatter, ArgumentParser
from gettext import gettext as _
from importlib.resources import files
from logging.config import dictConfig
from sys import argv

from geniac import __version__
from geniac.cli.commands.clean import GeniacClean
from geniac.cli.commands.configs import GeniacConfigs
from geniac.cli.commands.init import GeniacInit
from geniac.cli.commands.install import GeniacInstall
from geniac.cli.commands.lint import GeniacLint
from geniac.cli.commands.options import GeniacOptions
from geniac.cli.commands.recipes import GeniacRecipes
from geniac.cli.commands.test import GeniacTest
from geniac.cli.utils.base import MethodRecord, load_logging_config

__author__ = "Fabrice Allain"
__copyright__ = "Institut Curie 2020"

# noinspection PyTypeChecker
_PKG_NAME = "geniac.cli"
_logging_config_path = files(f"{_PKG_NAME}.data.conf").joinpath("logging.json")
_logger = logging.getLogger()
_logging_config = load_logging_config(_logging_config_path)


def setup_logging(log_level=logging.WARNING):
    """Setup basic logging

    Args:
      log_level (int): minimum log_level for emitting messages
    """
    # Setup a default logger
    logging.basicConfig(level=log_level)
    # Update with file handlers defined in _logging_config
    dictConfig(_logging_config)
    logging.captureWarnings(True)


def update_logger(
    logging_config: dict, log_level: int = None, only_stream: bool = False
):
    """Update logging config

    Args:
        logging_config (dict): dict config
        log_level (int): minimum log_level for emitting messages
        only_stream (bool): keep only Stream handlers
    """
    if log_level and logging_config.get("handlers"):
        _logger.setLevel(log_level)
        for handler in _logger.handlers:
            handler.setLevel(log_level)
    if only_stream and logging_config.get("handlers"):
        logging_config["handlers"] = {
            handler: handler_config
            for (handler, handler_config) in logging_config["handlers"].items()
            if handler == "console"
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


def main():
    """Main entry point"""
    # Initialize logger
    setup_logging()
    GeniacEntryPoint(argv[1:]).main()


class GeniacEntryPoint:
    """Geniac basic entry point"""

    DEFAULT_LOG_LEVELS = {
        "init": logging.INFO,
        "lint": logging.WARNING,
        "install": logging.INFO,
        "options": logging.INFO,
        "clean": logging.INFO,
        "configs": logging.INFO,
        "recipes": logging.INFO,
    }
    DEFAULT_OPTS = (
        MethodRecord(
            args=["--version"],
            kwargs={"action": "version", "version": f"geniac version-{__version__}"},
        ),
        MethodRecord(
            args=["-v", "--verbose"],
            kwargs={
                "dest": "log_level",
                "help": _("Set log level to INFO"),
                "action": "store_const",
                "const": logging.INFO,
            },
        ),
        MethodRecord(
            args=["-vv", "--very-verbose"],
            kwargs={
                "dest": "log_level",
                "help": _("Set log level to DEBUG"),
                "action": "store_const",
                "const": logging.DEBUG,
            },
        ),
        MethodRecord(
            args=["--no-logfiles"],
            kwargs={
                "dest": "only_stream",
                "help": _("Disable generation of log files"),
                "action": "store_true",
            },
        ),
        MethodRecord(
            args=["-c", "--config"],
            kwargs={
                "dest": "config_file",
                "help": _("Path to geniac config file (INI format)"),
                "type": str,
                "metavar": "CONF.INI",
            },
        ),
        MethodRecord(
            args=["-b", "--branch"],
            kwargs={
                "help": _(
                    "Git branch used to clone the project if project path is a correct git URL"
                ),
                "dest": "branch",
                "default": None,
                "metavar": "BRANCH",
            },
        ),
    )
    DEFAULT_ARGS = (
        MethodRecord(
            args=["src_path"],
            kwargs={
                "help": _(
                    "Path or URL to the Nextflow repository where geniac has been setup. "
                    "The path can be a geniac working directory initialized with "
                    "`geniac init`."
                ),
                "metavar": "SRC_PATH",
                "nargs": "?",
                "default": ".",
            },
        ),
    )
    LINT_ARGS = (
        MethodRecord(
            args=["--conda-check"],
            kwargs={
                "dest": "condaCheck",
                "help": _("Enable check of conda packages with conda"),
                "action": "store_true",
            },
        ),
    )
    INIT_ARGS = (
        MethodRecord(
            args=["-w", "--working-dir"],
            kwargs={
                "help": _(
                    "Path where the geniac working directory will be initialized"
                ),
                "dest": "working_dir",
                "metavar": "WORK_DIR",
            },
        ),
    )
    OPTIONS_ARGS = tuple(
        list(INIT_ARGS)
        + [
            # Put here specific args for options cmd
        ]
    )
    CLEAN_ARGS = tuple(
        list(INIT_ARGS)
        + [
            # Put here specific args for options cmd
        ]
    )
    CONFIGS_ARGS = tuple(
        list(INIT_ARGS)
        + [
            # Put here specific args for options cmd
        ]
    )
    RECIPES_ARGS = tuple(
        list(INIT_ARGS)
        + [
            # Put here specific args for options cmd
        ]
    )
    TEST_ARGS = tuple(
        [
            MethodRecord(
                args=["profile"],
                kwargs={
                    "help": _("Nextflow profile to be tested"),
                    "choices": [
                        "standard",
                        "conda",
                        "multiconda",
                        "singularity",
                        "docker",
                        "path",
                        "multipath",
                    ],
                    "nargs": "+",
                    "metavar": "NXF_PROFILE",
                },
            ),
            MethodRecord(
                args=["--check-cluster"],
                kwargs={
                    "dest": "check_cluster",
                    "help": _("Check also generated cluster executor"),
                    "action": "store_true",
                },
            ),
        ]
        + GeniacInstall.get_cmake_cache_args()
    )
    INSTALL_ARGS = tuple(
        [
            MethodRecord(
                args=["install_path"],
                kwargs={
                    "help": _("PATH where the nextflow repository will be installed"),
                    "metavar": "INSTALL_PATH",
                },
            ),
            MethodRecord(
                args=["--no-post-clean"],
                kwargs={
                    "help": _("Disable cleaning of working folder after installation"),
                    "dest": "no_post_clean",
                    "action": "store_true",
                },
            ),
            MethodRecord(
                args=["--no-pre-clean"],
                kwargs={
                    "help": _("Disable cleaning of working folder before installation"),
                    "dest": "no_pre_clean",
                    "action": "store_true",
                },
            ),
            MethodRecord(
                args=["-m", "--mode"],
                kwargs={
                    "help": _(
                        "Use a predefined mode to build and install the pipeline with all build "
                        "flags turned on [all] or only images [images], docker images [docker], "
                        "singularity images [singularity], Nextflow config files [configs], "
                        "container recipes [recipes]."
                    ),
                    "dest": "mode",
                    "default": None,
                    "choices": [
                        "all",
                        "images",
                        "docker",
                        "podman",
                        "singularity",
                        "singularityfakeroot",
                        "configs",
                        "recipes",
                    ],
                    "metavar": "MODE",
                },
            ),
        ]
        + GeniacInstall.get_cmake_cache_args()
    )

    def __init__(self, args):
        """

        Args:
            args: list of command line arguments passed to the CLI (sys.argv output)
        """
        self.parser = ArgumentParser(
            prog="geniac", description="Geniac Command Line Interface"
        )
        for record in self.DEFAULT_OPTS:
            self.parser.add_argument(*record.args, **record.kwargs)
        self.args = args
        self.parsed_args = None

    def clean_cmd(self):
        """geniac clean subcommand"""
        return GeniacClean(**self.parsed_args, parser=self.parser)

    def configs_cmd(self):
        """geniac configs subcommand"""
        return GeniacConfigs(**self.parsed_args, parser=self.parser)

    def recipes_cmd(self):
        """Geniac recipes subcommand"""
        return GeniacRecipes(**self.parsed_args, parser=self.parser)

    def lint_cmd(self):
        """Geniac Lint subcommand"""
        return GeniacLint(**self.parsed_args, parser=self.parser)

    def install_cmd(self):
        """Geniac install subcommand"""
        return GeniacInstall(**self.parsed_args, parser=self.parser)

    def init_cmd(self):
        """Geniac init subcommand"""
        return GeniacInit(**self.parsed_args, parser=self.parser)

    def options_cmd(self):
        """Geniac options subcommand"""
        return GeniacOptions(**self.parsed_args, parser=self.parser)

    def test_cmd(self):
        """Geniac tests subcommand"""
        return GeniacTest(**self.parsed_args, parser=self.parser)

    def parse_args(self):
        """Parse command line parameters"""

        # Add sub command (lint and conf)
        subparsers = self.parser.add_subparsers(title="commands")

        # Define a parent parser to share common set of arguments
        parent_parser = ArgumentParser(add_help=False)
        for record in self.DEFAULT_OPTS + self.DEFAULT_ARGS:
            parent_parser.add_argument(*record.args, **record.kwargs)

        # Geniac Check
        parser_lint = subparsers.add_parser(
            "lint",
            help=_("Evaluate the compatibility of a Nextflow project with Geniac"),
            parents=[parent_parser],
            formatter_class=ArgumentDefaultsHelpFormatter,
        )
        parser_lint.set_defaults(func=self.lint_cmd, which="lint")

        # Geniac install
        parser_install = subparsers.add_parser(
            "install",
            help=_("Installation utility of a Nextflow project compatible with geniac"),
            parents=[parent_parser],
            formatter_class=ArgumentDefaultsHelpFormatter,
        )
        parser_install.set_defaults(func=self.install_cmd, which="install")

        # Geniac options
        parser_options = subparsers.add_parser(
            "options",
            help=_(
                "Call CMake help utility on a Nextflow project compatible with geniac"
            ),
            parents=[parent_parser],
            formatter_class=ArgumentDefaultsHelpFormatter,
        )
        parser_options.set_defaults(func=self.options_cmd, which="options")

        # Geniac clean
        parser_clean = subparsers.add_parser(
            "clean",
            help=_(
                "Clean build directoty"
            ),
            parents=[parent_parser],
            formatter_class=ArgumentDefaultsHelpFormatter,
        )
        parser_clean.set_defaults(func=self.clean_cmd, which="clean")

        # Geniac configs
        parser_configs = subparsers.add_parser(
            "configs",
            help=_(
                "Generate config files a Nextflow project compatible with geniac"
            ),
            parents=[parent_parser],
            formatter_class=ArgumentDefaultsHelpFormatter,
        )
        parser_configs.set_defaults(func=self.configs_cmd, which="configs")

        # Geniac recipes
        parser_recipes = subparsers.add_parser(
            "recipes",
            help=_(
                "Generate container recipes on a Nextflow project compatible with geniac"
            ),
            parents=[parent_parser],
            formatter_class=ArgumentDefaultsHelpFormatter,
        )
        parser_recipes.set_defaults(func=self.recipes_cmd, which="recipes")

        # Geniac test
        parser_test = subparsers.add_parser(
            "test",
            help=_("Test Nextflow profile(s) generated with geniac"),
            parents=[parent_parser],
            formatter_class=ArgumentDefaultsHelpFormatter,
        )
        parser_test.set_defaults(func=self.test_cmd, which="test")

        # Geniac init
        parser_init = subparsers.add_parser(
            "init",
            help=_("Initialize a geniac working directory"),
            parents=[parent_parser],
            formatter_class=ArgumentDefaultsHelpFormatter,
        )
        parser_init.set_defaults(func=self.init_cmd, which="init")

        for (argparse_args, parser) in (
            (self.LINT_ARGS, parser_lint),
            (self.INSTALL_ARGS, parser_install),
            (self.OPTIONS_ARGS, parser_options),
            (self.TEST_ARGS, parser_test),
            (self.INIT_ARGS, parser_init),
        ):
            for argparse_arg in argparse_args:
                parser.add_argument(*argparse_arg.args, **argparse_arg.kwargs)

        self.parsed_args = vars(self.parser.parse_args(self.args))

    def main(self):
        """Main entry point allowing external calls"""
        self.parse_args()
        # Initialize logging instance
        update_logger(
            _logging_config,
            self.parsed_args.get("log_level"),
            self.parsed_args.get("only_stream", False),
        )
        if "func" in self.parsed_args:
            _logger.info(
                "Start geniac %s command.", self.parsed_args.get("which", None)
            )
            # Run method is actually the main entry point for any geniac subcommand
            self.parsed_args.get("func")().run()
        else:
            self.parser.print_help()
        _logger.debug("Script ends here.")


if __name__ == "__main__":
    main()
