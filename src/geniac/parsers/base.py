#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""parser.py: Geniac file parser"""

import logging
from abc import abstractmethod
from os import PathLike
from pathlib import Path

from dotty_dict import dotty

from geniac.commands.base import GBase

__author__ = "Fabrice Allain"
__copyright__ = "Institut Curie 2020"

_logger = logging.getLogger(__name__)


class GParser(GBase):
    """Geniac file parser"""

    def __init__(self, *args, **kwargs):
        """Constructor for GParser"""
        super().__init__(*args, **kwargs)
        self.params = None
        self._content = dotty()

    @property
    def content(self):
        """Content loaded from input file with read method"""
        return self._content

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

    @abstractmethod
    def _read(self, in_path: Path, encoding=None):
        """Load a file into content property

        Args:
            in_path (Path): path to nextflow config file
            encoding (str): name of the encoding use to decode config files
        """
        raise NotImplementedError(
            "This class should implement a private read method in order to fill content property"
        )

    def read(self, in_paths, encoding=None):
        """Read and parse a file or an iterable of files

        Args:
            in_paths: path to input file(s)
            encoding (str): name of the encoding used to decode files

        Returns:
            read_ok (list): list of successfully read files
        """
        if isinstance(in_paths, (str, bytes, PathLike)):
            in_paths = [in_paths]
        read_ok = []
        for filename in in_paths:
            filename = Path(filename)
            try:
                self._read(filename, encoding=encoding)
            except OSError:
                continue
            read_ok.append(filename)
        return read_ok
