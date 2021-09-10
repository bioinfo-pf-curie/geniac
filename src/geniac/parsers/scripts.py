#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""scripts.py: Nextflow scripts parser."""

import json
import logging
import re
import typing
from collections import OrderedDict, defaultdict

from geniac.parsers.base import GParser

__author__ = "Fabrice Allain"
__copyright__ = "Institut Curie 2021"

_logger = logging.getLogger(__name__)


class NextflowScript(GParser):
    """Nextflow script file parser"""

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

    def _read(
        self,
        config_file: typing.Union[typing.IO, typing.BinaryIO],
        config_path="",
        encoding=None,
    ):
        """Load a Nextflow script file into content property

        Args:
            config_file (BinaryIO): path to nextflow config file
            encoding (str): name of the encoding use to decode config files
        """
        script_flag = False
        process = ""
        self.content["process"] = self.content.get("process") or OrderedDict()
        # TODO: add if condition within scripts who should break the actual
        #       process scope
        for idx, line in enumerate(super()._read(config_file, encoding=encoding)):
            if match := self.PROCESSRE.match(line):
                values = match.groupdict()
                # If process add it to the process dict
                process = values.get("processName")
                self.content["process"][process] = defaultdict(list)
                self.content["process"][process]["NextflowScriptPath"] = str(
                    config_path
                )
            if match := self.LABELRE.match(line):
                values = match.groupdict()
                label = values.get("labelName")
                _logger.debug("FOUND label %s in process %s.", label, process)
                self.content["process"][process]["label"].append(label)
                continue
            # TODO: what about conditionals nextflow scripts ?
            if match := self.SCRIPTRE.match(line):
                values = match.groupdict()
                if process:
                    script_flag = not script_flag
                    if values.get("script"):
                        self.content["process"][process]["script"].append(line.strip())
                continue
            # Add to script part if script_flag
            if process and script_flag:
                _logger.debug("Add line %s to process %s scope.", idx, process)
                self.content["process"][process]["script"].append(line.strip())
                continue
        _logger.debug(
            "LOADED %s scope:\n%s.", in_file, json.dumps(dict(self.content), indent=2)
        )
