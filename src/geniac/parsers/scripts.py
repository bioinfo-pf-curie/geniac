#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""scripts.py: Nextflow scripts parser."""

import json
import logging
import re
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
    ECOMRE = re.compile(r"^ *\*/")
    # process flag
    PROCESSRE = re.compile(r"^ *process +(?P<processName>\w+) {")
    # process label
    LABELRE = re.compile(r"^ *label +['\"](?P<labelName>\w+)['\"] *")
    ESCOPERE = re.compile(r"")

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
            def_flag = False
            scope_idx = ""
            for line in config_file:
                # Skip if one line comment
                if self.UCOMRE.match(line):
                    continue
                # Skip if new multi line comment
                if self.MCOMRE.match(line):
                    mcom_flag = True
                    continue
                # Skip if multi line comment
                if mcom_flag and not self.ECOMRE.match(line):
                    continue
                # Skip if end multi line comment
                if self.ECOMRE.match(line):
                    mcom_flag = False
                    continue
                # Pop scope index list if we find a curly bracket
                # Turn off def flag if we reach the last scope in a def
                if self.ESCOPERE.match(line):
                    scope_idx = ".".join(scope_idx.split(".")[:-1])
                    if not scope_idx and def_flag:
                        def_flag = False
                    continue
                if match := self.SCOPERE.match(line):
                    values = match.groupdict()
                    # If scope add it to the scopes dict
                    if scope := values.get("scope"):
                        scope_idx = (
                            scope if not scope_idx else ".".join((scope_idx, scope))
                        )
                    if (selector := values.get("selector")) and (
                        label := values.get("label")
                    ):
                        scope_idx = (
                            ".".join((selector, label))
                            if not scope_idx
                            else ".".join((scope_idx, selector, label))
                            if selector not in scope_idx
                            else ".".join((scope_idx, label))
                        )
                    if values.get("close"):
                        scope_idx = ".".join(scope_idx.split(".").pop())
                    if scope := values.get("other"):
                        def_flag = True if "def" in scope else def_flag
                        scope_idx = (
                            "other" if not scope_idx else ".".join((scope_idx, "other"))
                        )
                    continue
                if not def_flag and (match := self.PARAMRE.match(line)):
                    values = match.groupdict()
                    prop = values.get("property")
                    param_list = list(
                        filter(None, (scope_idx, values.get("scope"), prop))
                    )
                    param_idx = (
                        ".".join(param_list) if len(param_list) > 1 else param_list[0]
                    )
                    _logger.debug(
                        f"FOUND property {values.get('property')} "
                        f"with value {values.get('value')} "
                        f"in scope {param_idx}"
                    )
                    value = values.get("value")
                    self.content[param_idx] = (
                        value.strip('"')
                        if '"' in value
                        else value.strip("'")
                        if "'" in value
                        else value
                    )
                    continue
        _logger.debug(
            f"LOADED {config_path} scope:\n{json.dumps(dict(self.content), indent=2)}"
        )
