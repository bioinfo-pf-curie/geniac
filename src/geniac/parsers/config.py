#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""config.py: Nextflow configuration file parser"""

import json
import logging
import re
import typing
from collections import OrderedDict, defaultdict

from ..parsers.base import GParser

__author__ = "Fabrice Allain"
__copyright__ = "Institut Curie 2020"

_logger = logging.getLogger(__name__)


def _scope_tmpl():
    """"""
    return {"properties": defaultdict(dict), "selectors": ()}


class NextflowConfig(GParser):
    """Nextflow config file parser"""

    # Param = value
    PARAMRE = re.compile(
        r"^ *(?P<scope>[\w.]+(?=\.))?\.?(((?P<property>[\w]+)\s*=\s*"
        r"(?P<elvis>[.\w]+\s*\?:\s*)?(?P<value>([\"\']?.*[\"\']?)|(\d+\.?\w*)|"
        r"(\[[\w\s\'\"/,-]*])|({[\w\s\'\"/,.\-*()]*})))|"
        r"((?P<includeConfig>includeConfig) +['\"](?P<confPath>[\w/.]+))['\"].*) *$"
    )
    SCOPERE = re.compile(
        r"^ *(['\"]?(?P<scope>[\w]+)(?<!try)['\"]?|"
        r"(?P<selector>[\w]+) *: *(?P<label>[\w]+)|"
        r"(?P<beforeClose>})?(?P<other>.+)(?<!\$)) *{ *(?P<afterClose>})?$"
    )
    ESCOPERE = re.compile(r"^ *}\s*$")

    def __init__(self, *args, **kwargs):
        """Constructor for NextflowConfigParser"""
        super().__init__(*args, **kwargs)

    @staticmethod
    def get_config_list(config, config_scope, option):
        """Get option list from configparser object
        Args:
            config:
            config_scope:
            option:

        Returns:
            list
        """
        return (
            list(filter(None, config_option.split("\n")))
            if (config_option := config.get(f"scope.{config_scope}", option))
            else []
        )

    def check_config_scope(self, nxf_config_scope: str, skip_nested_scopes=[""]):
        """Check if the given scope is in an NextflowConfig instance

        Args:
            nxf_config_scope (str): Scope checked in the Nextflow configuration
        """
        _logger.info(
            f"Checking {nxf_config_scope} scope in "
            f"{self.path.relative_to(self.project_dir)}."
        )

        default_config_scopes = self.get_config_list(
            self.config, nxf_config_scope, "scopes"
        )
        default_config_paths = self.get_config_list(
            self.config, nxf_config_scope, "paths"
        )
        default_config_props = self.get_config_list(
            self.config, nxf_config_scope, "properties"
        )
        required_flag = self.config.getboolean(f"scope.{nxf_config_scope}", "required")
        default_config_values = {
            key: value.split("\n")
            for key, value in (
                self.config.items(f"scope.{nxf_config_scope}.values")
                if self.config.has_section(f"scope.{nxf_config_scope}.values")
                else []
            )
        }

        scope = self.get(nxf_config_scope, "missing")
        cfg_val = None
        # If scope is empty and required
        if nxf_config_scope and scope == "missing" and required_flag:
            _logger.error(
                f"Required section {nxf_config_scope} in Nextflow configuration file "
                f"{self.path.relative_to(self.project_dir)} is missing."
            )
        # Else if the scope is empty
        elif nxf_config_scope and not scope:
            _logger.error(
                f"Section {nxf_config_scope} in Nextflow configuration file "
                f"{self.path.relative_to(self.project_dir)} is empty."
            )
        # Check if config_paths/config_props in the Nextflow config corresponds to
        # their default values
        if scope != "missing":
            for config_prop in default_config_paths + default_config_props:
                def_val = default_config_values.get(config_prop, [])
                if (
                    config_prop
                    and (cfg_val := scope.get(config_prop))
                    not in [_.strip("'\"") for _ in def_val]
                    and def_val
                ):
                    form_def_val = ", ".join(
                        [
                            _ if '"' in _ or "'" in _ else f"'{_}'"
                            for _ in filter(None, def_val)
                        ]
                    )
                    _logger.warning(
                        f'Value "{cfg_val}" of {nxf_config_scope}.{config_prop} parameter'
                        f" in file {self.path.relative_to(self.project_dir)} doesn't "
                        f"correspond to one of the expected values [{form_def_val}]."
                    ) if cfg_val is not None else _logger.error(
                        f"Missing {nxf_config_scope}.{config_prop} parameter in file "
                        f"{self.path.relative_to(self.project_dir)}."
                    )

        # Call same checks on nested scopes
        for nested_scope in default_config_scopes:
            if nested_scope not in skip_nested_scopes:
                self.check_config_scope(".".join((nxf_config_scope, nested_scope)))

    def _read(
        self,
        config_file: typing.Union[typing.IO, typing.BinaryIO],
        encoding="UTF-8",
        config_path="",
    ):
        """Load a Nextflow config file into content property

        Args:
            config_file (BinaryIO): nextflow config file
            encoding (str): name of the encoding use to decode config files
        """
        # TODO: should we flush content dict before reading another file ?
        #       or propose a flag if we want to overwrite content
        def_flag = False
        selector = None
        scope_idx = ""
        for line_idx, line in enumerate(super()._read(config_file, encoding=encoding)):
            # Pop scope index list if we find a curly bracket
            # Turn off def flag if we reach the last scope in a def
            if self.ESCOPERE.match(line):
                depth = 1 if not selector else 2
                scope_idx = ".".join(scope_idx.split(".")[:-depth])
                selector = None
                if not scope_idx and def_flag:
                    def_flag = False
                continue
            if match := self.SCOPERE.match(line):
                values = match.groupdict()
                # If scope add it to the scopes dict
                if scope := values.get("scope"):
                    scope_idx = scope if not scope_idx else ".".join((scope_idx, scope))
                # If there is also a selector on the line add them to scope_idx
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
                # If close pattern, remove
                if values.get("beforeClose"):
                    scope_idx = ".".join(scope_idx.split(".").pop())
                # Add the rest of the line in other section
                if scope := values.get("other"):
                    def_flag = True if "def" in scope else def_flag
                    scope_idx = (
                        "other" if not scope_idx else ".".join((scope_idx, "other"))
                    )
                self.content[scope_idx] = OrderedDict()
                if values.get("afterClose"):
                    scope_idx = ".".join(scope_idx.split(".").pop())
                continue
            # If we are not in a def scope and we find a parameter
            if not def_flag and (match := self.PARAMRE.match(line)):
                values = match.groupdict()
                prop_key = "property" if values.get("property") else "includeConfig"
                value_key = "value" if values.get("value") else "confPath"
                prop = values.get(prop_key, "")
                value = values.get(value_key, "")
                param_list = list(filter(None, (scope_idx, values.get("scope"), prop)))
                param_idx = (
                    ".".join(param_list) if len(param_list) > 1 else param_list[0]
                )
                _logger.debug(
                    f"FOUND property {values.get(prop_key)} "
                    f"with value {values.get(value_key)} "
                    f"in scope {param_idx}."
                )
                value = (
                    value.strip('"')
                    if '"' in value
                    else value.strip("'")
                    if "'" in value
                    else value
                )
                # If parameter has already been defined in a previous configuration
                # file
                if (
                    value
                    and param_idx in self.content
                    and self.content[param_idx]
                    and prop_key != "includeConfig"
                ):
                    history_paths = [
                        conf_path.relative_to(self.project_dir).name
                        for conf_path in self.loaded_paths
                    ]
                    extra_msg = (
                        f" in a previous configuration file " f"{history_paths}"
                        if self.loaded_paths
                        else " in the same file"
                    )
                    _logger.warning(
                        f"Parameter {param_idx} from "
                        f"{self.path.relative_to(self.project_dir)} at line {line_idx + 1} has already "
                        f"been defined{extra_msg}."
                    )
                self.content[param_idx] = (
                    self.content[param_idx] + [value]
                    if prop_key == "includeConfig" and param_idx in self.content
                    else [value]
                    if prop_key == "includeConfig"
                    else value
                )
                continue
        _logger.debug(
            f"LOADED {config_file} scope:\n{json.dumps(dict(self.content), indent=2)}."
        )
