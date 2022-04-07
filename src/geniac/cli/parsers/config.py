#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""config.py: Nextflow configuration file parser"""

import re
import typing
from collections import ChainMap, OrderedDict

from geniac.cli.parsers.base import DEFAULT_ENCODING, GeniacBase, GeniacParser, PathLike

__author__ = "Fabrice Allain"
__copyright__ = "Institut Curie 2020"


class NextflowConfig(GeniacParser):
    """Nextflow config file parser"""

    # Param = value
    PARAM_RE = re.compile(
        r"^ *(?P<scope>[\w.]+(?=\.))?\.?(((?P<property>[\w]+)\s*=\s*"
        r"(?P<elvis>[.\w]+\s*\?:\s*)?(?P<value>([\"\']?.*[\"\']?)|(\d+\.?\w*)|"
        r"(\[[\w\s\'\"/,-]*])|({[\w\s\'\"/,.\-*()]*})))|"
        r"((?P<includeConfig>includeConfig) +['\"](?P<confPath>[\w/.]+))['\"].*) *$"
    )
    SCOPE_RE = re.compile(
        r"^ *(['\"]?(?P<scope>[\w]+)(?<!try)['\"]?|"
        r"(?P<selector>[\w]+) *: *(?P<label>[\w]+)|"
        r"(?P<beforeClose>})?(?P<other>.+)(?<!\$)) *{ *(?P<afterClose>})?$"
    )
    ESCOPE_RE = re.compile(r"^ *}\s*$")

    def _check_config_scope_format(self, nxf_config_scope: str, scope: dict):
        """Check all the properties in a Nextflow config scope if there is a pattern related to the
        format.

        Args:
            nxf_config_scope (str): Name of the Nextflow config scope
            scope (dict): related scope with the nested Nextflow parameters
        """
        properties_pattern = [
            re.compile(pattern)
            for pattern in self.get_config_scope_option_list(
                nxf_config_scope, "patterns"
            )
        ]
        if properties_pattern:
            for property_name, [property_value] in scope.items():
                is_formatted = False
                for reg in properties_pattern:
                    if reg.search(property_value):
                        is_formatted = True
                        break
                if not is_formatted:
                    self.warning(
                        "Parameter %s is not correctly formatted. Read the documentation for more "
                        "details.",
                        ".".join((nxf_config_scope, property_name)),
                    )

    def _check_config_scope(self, nxf_config_scope: str, scope: dict):
        """Do all the checks related to a specific Nextflow config scope

        Args:
            nxf_config_scope (str): Name of the Nextflow config scope
            scope (dict): related scope with the nested Nextflow parameters
        """
        # If there is a pattern related to the format of the scope, we check all the properties
        self._check_config_scope_format(nxf_config_scope=nxf_config_scope, scope=scope)

        config_properties = [
            *self.get_config_scope_option_list(nxf_config_scope, "paths"),
            *self.get_config_scope_option_list(nxf_config_scope, "properties"),
        ]
        # If there is mandatory properties, we check against default values and/or prohibited
        # patterns
        for config_prop in config_properties:
            default_values = self.get_config_section_items(
                f"scope.{nxf_config_scope}.values.default"
            ).get(config_prop, [])
            prohibited_patterns = self.get_config_section_items(
                f"scope.{nxf_config_scope}.values.prohibited"
            ).get(config_prop)
            cfg_vals = scope.get(config_prop, [None])

            for cfg_val in cfg_vals:
                # If the values doesn't match default values
                if (
                    config_prop
                    and default_values
                    and cfg_val not in [_.strip("'\"") for _ in default_values]
                ):
                    # Check for prohibited pattern only if the value doesn't match default values
                    for reg in (
                        [re.compile(pattern) for pattern in prohibited_patterns]
                        if prohibited_patterns
                        else []
                    ):
                        if match := reg.search(cfg_val):
                            matches = match.groupdict()
                            cfg_val_without_pro = cfg_val.replace(
                                matches.get("prohibited"), ""
                            )
                            warn_flag = cfg_val_without_pro != cfg_val.replace(
                                matches.get("values"), ""
                            )
                            self.error(
                                'Value "%s" of %s.%s parameter match the following prohibited '
                                'pattern "%s". %s%s',
                                cfg_val,
                                nxf_config_scope,
                                config_prop,
                                matches.get("prohibited_pattern"),
                                "It should normally correspond to the string below:\n\t"
                                if warn_flag
                                else "",
                                cfg_val_without_pro if warn_flag else "",
                            )

                    if cfg_val is not None:
                        self.warning(
                            'Value "%s" of %s.%s parameter'
                            " in file %s doesn't correspond to one of the expected values [%s].",
                            cfg_val,
                            nxf_config_scope,
                            config_prop,
                            self.path.relative_to(self.src_path),
                            ", ".join(
                                [
                                    _ if '"' in _ or "'" in _ else f"'{_}'"
                                    for _ in filter(None, default_values)
                                ]
                            ),
                        )
                    else:
                        self.error(
                            "Missing %s.%s parameter in file %s.",
                            nxf_config_scope,
                            config_prop,
                            self.path.relative_to(self.src_path),
                        )

    def check_config_scope(self, nxf_config_scope: str, skip_nested_scopes=None):
        """Check if the given scope is in an NextflowConfig instance

        Args:
            nxf_config_scope (str): Scope checked in the Nextflow configuration
            skip_nested_scopes:
        """
        self.info(
            "Checking %s scope in %s.",
            nxf_config_scope,
            self.path.relative_to(self.src_path),
        )

        skip_nested_scopes = [""] if skip_nested_scopes is None else skip_nested_scopes

        scope = self.get(nxf_config_scope, "missing")
        # If scope is empty and required
        if (
            nxf_config_scope
            and scope == "missing"
            and self.default_config.getboolean(f"scope.{nxf_config_scope}", "required")
        ):
            self.error(
                "Required section %s in Nextflow configuration file %s is missing.",
                nxf_config_scope,
                self.path.relative_to(self.src_path),
            )
        # Else if the scope is empty
        elif nxf_config_scope and not scope:
            self.error(
                "Section %s in Nextflow configuration file %s is empty.",
                nxf_config_scope,
                self.path.relative_to(self.src_path),
            )

        # Check if config_paths/config_props in the Nextflow config corresponds to
        # their default values and are not prohibited (if a prohibited pattern is available)
        if scope != "missing":
            self._check_config_scope(nxf_config_scope, scope)

        # Recursive call to do checks on nested scopes
        for nested_scope in self.get_config_scope_option_list(
            nxf_config_scope, "scopes"
        ):
            if nested_scope not in skip_nested_scopes:
                self.check_config_scope(".".join((nxf_config_scope, nested_scope)))

    @staticmethod
    def check_labels_in_section(nxf_config, section_name, labels):
        """Check if given labels exists within a section"""
        if x_section := nxf_config.get(section_name):
            # For each label in the section scope
            for label in x_section:
                # If label is not present in labels
                if label not in labels:
                    nxf_config.error(
                        "Label %s of %s is not defined neither in params.geniac.tools nor availabe as a module.",
                        label,
                        section_name,
                    )

    def _set_scope(self, values: dict, scope_idx: str, def_flag: bool):
        """Set a new scope according to the actual scope_idx

        Args:
            values (dict): group dict from matching pattern
            scope_idx (str): Index of the last scope in content tree structure
            def_flag (bool): Flag corresponding to definition groovy blocks

        Returns:
            scope_idx (str): Index of the last scope in content tree structure
            selector (str): Setup if there is any with* nextflow selector
            def_flag (bool): Flag corresponding to definition groovy blocks
        """
        # If scope add it to the scopes dict
        if scope := values.get("scope"):
            scope_idx = scope if not scope_idx else ".".join((scope_idx, scope))
        # If there is also a selector on the line add them to scope_idx
        if (selector := values.get("selector")) and (label := values.get("label")):
            scope_idx = (
                ".".join((selector, label))
                if not scope_idx
                else ".".join((scope_idx, selector, label))
                if selector not in scope_idx
                else ".".join((scope_idx, label))
            )
        # If close pattern, remove the last scope_idx
        if values.get("beforeClose"):
            scope_idx = ".".join(scope_idx.split(".").pop()) if "." in scope_idx else ""
        # Add the rest of the line in other section
        if scope := values.get("other"):
            def_flag = True if "def" in scope else def_flag
            scope_idx = (
                "other"
                if not scope_idx or scope_idx == "other"
                else ".".join((scope_idx, "other"))
            )
        # Init the scope with the scope_idx only if it does not exist
        if scope_idx not in self.content:
            self.content[scope_idx] = OrderedDict()
        # Update scope_idx if there is a closing bracket at the end of the match
        if values.get("afterClose"):
            scope_idx = ".".join(scope_idx.split(".").pop())
        return scope_idx, selector, def_flag

    def _set_param(
        self, values: dict, scope_idx: str, line_idx: int, warnings: bool = True
    ):
        """Set Nextflow parameter in content property

        Args:
            values (dict): group dict from matching pattern
            scope_idx (str): Index of the scope in content tree structure
            line_idx (int): Index of the current line in the file
        """
        prop_key = "property" if values.get("property") else "includeConfig"
        value_key = "value" if values.get("value") else "confPath"
        prop = values.get(prop_key, "")
        value = values.get(value_key, "")
        param_list = list(filter(None, (scope_idx, values.get("scope"), prop)))
        param_idx = ".".join(param_list) if len(param_list) > 1 else param_list[0]
        self.debug(
            "FOUND property %s with value %s in scope %s.",
            values.get(prop_key),
            values.get(value_key),
            param_idx,
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
            and warnings
            and param_idx in self.content
            and self.content[param_idx]
            and prop_key != "includeConfig"
        ):
            history_paths = [
                conf_path.relative_to(self.src_path).name
                for conf_path in self.loaded_paths
            ]
            extra_msg = (
                f" in a previous configuration file {history_paths}"
                if self.loaded_paths
                else " in the same file"
            )
            self.warning(
                "Parameter %s from %s at line %s has already been defined%s.",
                param_idx,
                self.path.relative_to(self.src_path),
                line_idx + 1,
                extra_msg,
            )
        self.content[param_idx] = (
            [value]
            if param_idx not in self.content
            else self.content[param_idx] + [value]
        )

    def _read(
        self,
        in_file: typing.Union[typing.IO, typing.BinaryIO],
        encoding: str = DEFAULT_ENCODING,
        in_path: PathLike = None,
        flush_content: bool = False,
        warnings: bool = True,
        **kwargs,
    ):
        """Load a Nextflow config file into content property

        Args:
            in_file (BinaryIO): input Nextflow config file
            encoding (str): encoding type used to read the input file
            in_path (PathLike): path to input file
            flush_content (bool): flag used to flush previous content before reading
            warnings (bool): flag to turn on/off warning messages

        Returns:
            content (
        """
        def_flag = False
        selector = None
        scope_idx = ""
        content_cache = self.content
        for line_idx, line in enumerate(
            super()._read(in_file, encoding=encoding, flush_content=True, **kwargs)
        ):
            # Pop scope index list if we find a curly bracket
            # Turn off def flag if we reach the last scope in a def
            if self.ESCOPE_RE.match(line):
                depth = 1 if not selector else 2
                scope_idx = ".".join(scope_idx.split(".")[:-depth])
                selector = None
                if not scope_idx and def_flag:
                    def_flag = False
                continue
            # If we find a new scope
            if match := self.SCOPE_RE.match(line):
                (scope_idx, selector, def_flag) = self._set_scope(
                    match.groupdict(), scope_idx, def_flag
                )
                continue
            # If we are not in a def scope and we find a parameter
            if not def_flag and (match := self.PARAM_RE.match(line)):
                self._set_param(
                    match.groupdict(), scope_idx, line_idx, warnings=warnings
                )
                continue
        content = self.content.copy()
        # If we don't want to flush, then we merge with previous content
        if not flush_content:
            self.content.update(content_cache)
        return content


class NextflowConfigContainer(GeniacBase, ChainMap):
    """Container object to save nextflow config files"""

    def append(self, item: NextflowConfig):
        """Add a new Nextflow Config"""
        self.maps.append(item.content)

    def check_labels_in_section(self, section_name, labels):
        """Check if given labels exists within a section"""
        return NextflowConfig.check_labels_in_section(self, section_name, labels)
