#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""scripts.py: Nextflow scripts parser."""

import json
import logging
import re
from collections import defaultdict
from pathlib import Path

from geniac.parsers.base import GParser

__author__ = "Fabrice Allain"
__copyright__ = "Institut Curie 2021"

_logger = logging.getLogger(__name__)


class NextflowScript(GParser):
    """Nextflow script file parser"""

    # Uniq comment line
    UCOMRE = re.compile(r"^ *//")
    # Multi comment line
    MCOMRE = re.compile(r"^ */\*")
    # End multi line comment
    ECOMRE = re.compile(r"^ *\*+/")
    # process flag
    PROCESSRE = re.compile(r"^ *process +(?P<processName>\w+) *{")
    # process label
    LABELRE = re.compile(r"^ *label +['\"](?P<labelName>\w+)['\"] *")
    # script flag
    SCRIPTRE = re.compile(
        r"^ *(?P<startScript>[\"']{3})"
        r"((?P<script>.+)(?<=(?P<endScript>[\"']{3})))? *$"
    )

    def __init__(self, *args, **kwargs):
        """Constructor for NextflowScript parser"""
        super().__init__(*args, **kwargs)

    def _read(self, config_path: Path, encoding=None):
        """Load a Nextflow script file into content property

        Args:
            config_path (Path): path to nextflow config file
            encoding (str): name of the encoding use to decode config files
        """

        with config_path.open(encoding=encoding) as config_file:
            mcom_flag = False
            script_flag = False
            process = ""
            self.content["process"] = {}
            # TODO: add if condition within scripts who should break the actual
            #       process scope
            for idx, line in enumerate(config_file):
                # Skip if one line comment
                if self.UCOMRE.match(line):
                    continue
                # Skip if new multi line comment
                if self.MCOMRE.match(line):
                    mcom_flag = True
                    continue
                # Skip if end multi line comment
                if self.ECOMRE.match(line):
                    mcom_flag = False
                    continue
                # Skip if multi line comment
                if mcom_flag and not self.ECOMRE.match(line):
                    continue
                # Pop scope index list if we find a curly bracket
                # Turn off def flag if we reach the last scope in a def
                # if self.ESCOPERE.match(line):
                #     scope_idx = ".".join(scope_idx.split(".")[:-1])
                #     if not scope_idx and def_flag:
                #         def_flag = False
                #    continue
                if match := self.PROCESSRE.match(line):
                    values = match.groupdict()
                    # If process add it to the process dict
                    process = values.get("processName")
                    self.content["process"][process] = defaultdict(list)
                if match := self.LABELRE.match(line):
                    values = match.groupdict()
                    label = values.get("labelName")
                    _logger.debug(f"FOUND label {label} " f"in process {process}.")
                    self.content["process"][process]["label"].append(label)
                    continue
                # TODO: what about conditionals nextflow scripts ?
                if match := self.SCRIPTRE.match(line):
                    values = match.groupdict()
                    if process:
                        script_flag = False if script_flag else True
                        if values.get("script"):
                            self.content["process"][process]["script"].append(
                                line.strip()
                            )
                    continue
                # Add to script part if script_flag
                if process and script_flag:
                    _logger.debug(f"Add line {idx} to process {process} scope.")
                    self.content["process"][process]["script"].append(line.strip())
                    continue
        _logger.debug(
            f"LOADED {config_path} scope:\n{json.dumps(dict(self.content), indent=2)}."
        )
