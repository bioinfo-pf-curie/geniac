#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""parser.py: Geniac file parser"""

import logging
import re
import tempfile
import typing
from abc import abstractmethod
from collections import OrderedDict
from io import StringIO
from os import PathLike
from pathlib import Path

from dotty_dict import dotty

from geniac.commands.base import GBase

__author__ = "Fabrice Allain"
__copyright__ = "Institut Curie 2020"

_logger = logging.getLogger(__name__)
DEFAULT_ENCODING = "UTF-8"


class GParser(GBase):
    """Geniac file parser"""

    COMRE = re.compile(
        r"(?P<tdquote>\"{3}[\S\s]*?\"{3})|"
        r"(?P<tquote>\'{3}[\S\s]*?\'{3})|"
        r"(?P<squote>\'[^\']*\')|"
        r"(?P<dquote>\"[^\"]*?\")|"
        r"(?P<scom>//.*?$)|"
        r"(?P<mcom>/\*([\s\S]*?)\*/)",
        re.MULTILINE,
    )

    def __init__(self, *args, **kwargs):
        """Constructor for GParser"""
        super().__init__(*args, **kwargs)
        self.params = None
        self._path = ""
        self._loaded_paths = []
        self._content = dotty(OrderedDict())

    @property
    def content(self):
        """Content loaded from input file with read method"""
        return self._content

    @property
    def path(self):
        """Content loaded from input file with read method"""
        return self._path

    @path.setter
    def path(self, value):
        """Content loaded from input file with read method"""
        self._path = value

    @property
    def loaded_paths(self):
        """Content(s) loaded from input file with read method"""
        return self._loaded_paths

    @loaded_paths.setter
    def loaded_paths(self, value):
        """Content loaded from input file with read method"""
        self._loaded_paths = value

    def __getitem__(self, item):
        """Get a content item"""
        return self._content[item]

    def __setitem__(self, key, value):
        """Set an item in content"""
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

    def _remove_comments(self, in_file, temp_file):
        # Remove comments for the analysis
        # input_content = self.UCOMRE.sub("", self.MCOMRE.sub("", in_file.read()))

        def match_comments(match):
            """Filter comments from match object"""
            return "" if match.group("mcom") or match.group("scom") else match.group(0)

        input_content = self.COMRE.sub(match_comments, in_file.read())
        temp_file.write(bytes(input_content, encoding=DEFAULT_ENCODING))
        temp_file.seek(0)
        return temp_file

    @abstractmethod
    def _read(
        self,
        in_file: typing.Union[typing.IO, typing.BinaryIO],
        encoding=DEFAULT_ENCODING,
        config_path="",
    ):
        """Load a file into content property

        Args:
            in_file (TextIO): path to nextflow config file
        """
        return StringIO(in_file.read().decode(encoding))

    def read(self, in_paths, encoding=DEFAULT_ENCODING):
        """Read and parse a file or an iterable of files

        Args:
            in_paths: path to input file(s)
            encoding (str): name of the encoding used to decode files

        Returns:
            read_ok (list): list of successfully read files
        """
        self.path = in_paths
        if isinstance(in_paths, (str, bytes, PathLike)):
            in_paths = [in_paths]
        read_ok = []
        for filename in in_paths:
            filename = Path(filename)
            try:
                with filename.open(
                    mode="r", encoding=encoding
                ) as input_file, tempfile.TemporaryFile() as temp_file:
                    temp_file = self._remove_comments(input_file, temp_file)
                    self._read(temp_file, encoding=encoding, config_path=filename)
                    self.loaded_paths += [filename]
            except OSError:
                continue
            read_ok.append(filename)
        return read_ok
