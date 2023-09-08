#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""scripts.py: Nextflow scripts parser."""

import re
import typing
from collections import OrderedDict, defaultdict

from geniac.cli.parsers.base import GeniacParser, PathLike

__author__ = "Fabrice Allain"
__copyright__ = "Institut Curie 2021"


class NextflowScript(GeniacParser):
    """Nextflow script file parser"""

    # process flag
    PROCESS_RE = re.compile(r"^ *process +(?P<processName>\w+) *{")
    # process label
    LABEL_RE = re.compile(r"^ *label +['\"](?P<labelName>\w+)['\"] *")
    # process label defined by a variable
    LABEL_VARIABLE_RE = re.compile(r"^ *label +[(](?P<labelParamsValue>.*) \?\: ['\"'](?P<labelName>.*)['\"'][)] *")
    # script flag
    SCRIPT_RE = re.compile(
        r"^ *(?P<startScript>[\"']{3})"
        r"((?P<script>.+)(?<=(?P<endScript>[\"']{3})))? *$"
    )
    # output/input flag
    INOUT_RE=re.compile(r"^[ \t]*(?P<inout>input|output|script):[ \t]*")
    # renvInit invokation
    RENV_INIT_RE = re.compile(r"\s*(?P<renvInit>renv\w+Init)\(['\"'](?P<renvLabel>\w+)['\"']\)")
    RENV_INIT_OUT_RE = re.compile(r"\s*(?P<renvProcess>\w+)\((?P<renvInit>\w+).*\.out\.renvInitDone\)")
    RENV_INIT_INCLUDE_RE = re.compile(r"\s*include\s*{\s*renvInit\s+as\s+(?P<renvInitInclude>\w+)\s*}\s+from\s+['\"'](?P<renvInitFile>.*)['\"']")


    def _read(
        self,
        in_file: typing.Union[typing.IO, typing.BinaryIO],
        in_path: PathLike = None,
        **kwargs,
    ):
        """Load a Nextflow script file into content property

        Args:
            in_file (BinaryIO): path to nextflow script file
            encoding (str): name of the encoding use to decode config files
            in_path (PathLike): path to the input file
            flush_content (bool): flag used to flush previous content before reading
            warnings (bool): flag to turn on/off warning messages
        """
        script_flag = False
        process = ""
        inout = ""
        output_flag = False
        input_flag = False
        # TODO: change process keys to ("processName", filePath)
        self.content["process"] = self.content.get("process") or OrderedDict()
        self.content["renvInitLabel"] = self.content.get("renvInitLabel") or OrderedDict()
        self.content["renvInitOut"] = self.content.get("renvInitOut") or OrderedDict()
        self.content["renvInitInclude"] = self.content.get("renvInitInclude") or OrderedDict()
        for idx, line in enumerate(super()._read(in_file, **kwargs)):
            if match := self.RENV_INIT_RE.match(line):
                values = match.groupdict()
                renvInit = values.get("renvInit")
                renvLabel = values.get("renvLabel")
                self.content["renvInitLabel"][renvLabel] = renvInit
            if match := self.RENV_INIT_OUT_RE.match(line):
                values = match.groupdict()
                renvInit = values.get("renvInit")
                renvProcess = values.get("renvProcess")
                self.content["renvInitOut"][renvInit] = renvProcess
            if match := self.RENV_INIT_INCLUDE_RE.match(line):
                values = match.groupdict()
                renvInitInclude = values.get("renvInitInclude")
                renvInitFile = values.get("renvInitFile")
                self.content["renvInitInclude"][renvInitInclude] = renvInitFile
            if match := self.PROCESS_RE.match(line):
                inout = ""
                input_flag = False
                output_flag = False
                script_flag = False
                values = match.groupdict()
                # If process add it to the process dict
                process = values.get("processName")
                self.content["process"][process] = defaultdict(list)
                # Save the path to the nextflow script for future logs
                self.content["process"][process]["NextflowScriptPath"] = str(in_path)
            if match := self.LABEL_RE.match(line):
                values = match.groupdict()
                label = values.get("labelName")
                self.debug("FOUND label '%s' in process '%s'.", label, process)
                self.content["process"][process]["label"].append(label)
                continue
            if match := self.LABEL_VARIABLE_RE.match(line):
                values = match.groupdict()
                label = values.get("labelName")
                paramsValue = values.get("labelParamsValue")
                self.info("FOUND label '%s' in process '%s' defined using the variable '%s'.", label, process, paramsValue)
                self.content["process"][process]["labelVariable"].append(label)
                self.content["process"][process]["labelVariableParams"].append(paramsValue)
                continue
            # For the moment we append everything into the same list even with conditional nextflow
            # script
            if match := self.SCRIPT_RE.match(line):
                inout = ""
                input_flag = False
                output_flag = False
                values = match.groupdict()
                if process:
                    script_flag = not script_flag
                    if values.get("script"):
                        self.content["process"][process]["script"].append(line.strip())
                continue
            if match := self.INOUT_RE.match(line):
                input_flag = False
                output_flag = False
                script_flag = False
                values = match.groupdict()
                if values.get("inout") == "output":
                    output_flag = True
                if values.get("inout") == "input":
                    input_flag = True
                continue
            # Add to script part if script_flag
            if process and script_flag:
                self.debug("Add line %s to process %s scope for script part.", idx, process)
                self.content["process"][process]["script"].append(line.strip())
                continue
            # Add to output part if output_flag
            if process and output_flag:
                self.debug("Add line %s to process %s scope for output part.", idx, process)
                self.content["process"][process]["output"].append(line.strip())
                continue
            # Add to input part if input_flag
            if process and input_flag:
                self.debug("Add line %s to process %s scope for input part.", idx, process)
                self.content["process"][process]["input"].append(line.strip())
                continue
