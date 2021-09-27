# !/usr/bin/env python
# -*- coding: utf-8 -*-

"""Geniac Module"""

from importlib.metadata import PackageNotFoundError, version  # pragma: no cover

try:
    # Change here if project is renamed and does not equal the package name
    __version__ = version(__name__)
except PackageNotFoundError:
    __version__ = "unknown"  # pragma: no cover
finally:
    del version, PackageNotFoundError
