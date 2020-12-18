#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""config.py: Nextflow script parser"""

import json
import logging
import re
from collections import defaultdict
from os import PathLike
from pathlib import Path

from dotty_dict import dotty

from .base import GBase

__author__ = "Fabrice Allain"
__copyright__ = "Institut Curie 2020"

_logger = logging.getLogger(__name__)


def _scope_tmpl():
    """"""
    return {"properties": defaultdict(dict), "selectors": ()}


class NextflowConfig(GBase):
    """Nextflow config file"""

    # Uniq comment line
    UCOMRE = re.compile(r"\s*//")
    # Multi comment line
    MCOMRE = re.compile(r"\s*/\*")
    # End multi line comment
    ECOMRE = re.compile(r"\s*\*/")
    # Param = value
    PARAMRE = re.compile(
        r"^\s*(?P<scope>[\w.]+(?=\.))?\.?(?P<property>[\w]+)\s*=\s*"
        r"(?P<elvis>[.\w]+\s*\?:\s*)?"
        r"(?P<value>[\"\'].*[\"\']|\d*\.?\w*|\[[\w\s\'\"/,-]*]|"
        r"{[\w\s\'\"/,.\-*()]*})\s*$"
    )
    SCOPERE = re.compile(
        r"^\s*((?P<scope>[\w]+)(?<!try)|"
        r"(?P<selector>[\w]+):(?P<label>[\w]+)|"
        r"(?P<close>})?(?P<other>.+)(?<!\$))\s*{\s*$"
    )
    ESCOPERE = re.compile(r"^ *}\s*$")

    def __init__(self, *args, **kwargs):
        """Constructor for NextflowConfigParser"""
        super().__init__(*args, **kwargs)
        self.params = None
        self._scopes = self._format_scopes_config()
        self._content = dotty()

    @property
    def scopes(self):
        """Expected Nextflow config scopes"""
        return self._scopes

    @property
    def content(self):
        """Config loaded from config files with read method"""
        return self._content

    def __getitem__(self, item):
        """Get a config option"""
        return self._content[item]

    def __setitem__(self, key, value):
        """Set an option in config"""
        self._content[key] = value

    def __repr__(self):
        """List only values in content dict"""
        return repr(self.content)

    def __contains__(self, item):
        """Check if item is in content dict"""
        return item in self._content

    def __delitem__(self, key):
        """Remove a key from content dict"""
        del self._content[key]

    def get(self, key, default=None):
        """Get method with default option"""
        if key in self.content:
            return self[key]
        return default

    def _format_scopes_config(self):
        """Format scopes from ini config"""
        return {
            scope_section: {
                scope_property: ""
                for scope_property in (
                    self.config.get(scope_section, "properties").split()
                    if self.config.get(scope_section, "properties")
                    else []
                )
            }
            for scope_section in self.config_subsection("scope")
        }

    def _read(self, config_path: Path, encoding=None):
        """Load a Nextflow config file into content property

        Args:
            config_path (Path): path to nextflow config file
            encoding (str): name of the encoding use to decode config files
        """

        with config_path.open(encoding=encoding) as config_file:
            # _logger.debug(f.read())
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

    def read(self, config_paths, encoding=None):
        """Read and parse a Nextflow config file or an iterable of config files

        Args:
            config_paths: path to nextflow config file
            encoding (str): name of the encoding use to decode config files

        Returns:
            read_ok (list): list of successfully read files
        """
        if isinstance(config_paths, (str, bytes, PathLike)):
            config_paths = [config_paths]
        read_ok = []
        for filename in config_paths:
            filename = Path(filename)
            try:
                self._read(filename, encoding=encoding)
            except OSError:
                continue
            read_ok.append(filename)
        return read_ok
