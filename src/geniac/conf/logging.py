#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""handlers.py: Custom logging handlers."""

import logging

__author__ = "Fabrice Allain"
__copyright__ = "Institut Curie 2021"


class LogMixin:
    """Add logger property and error/warning/info tracking"""

    def __init__(self, *args, **kwargs):
        self._error_flag = False
        super().__init__(*args, **kwargs)

    @property
    def logger(self):
        """Logging logger instance"""
        return logging.getLogger(".".join([__name__, self.__class__.__name__]))

    @property
    def error_flag(self):
        """Trace of error message"""
        return self._error_flag

    @error_flag.setter
    def error_flag(self, value: bool):
        """Set the error flag"""
        self._error_flag = value

    def error(self, *args, **kwargs):
        """Log error message and keep a trace of it"""
        self.error_flag = True
        return self.logger.error(*args, **kwargs)

    def info(self, *args, **kwargs):
        """Log info messages"""
        return self.logger.info(*args, **kwargs)

    def warning(self, *args, **kwargs):
        """Log warning messages"""
        return self.logger.warning(*args, **kwargs)

    def debug(self, *args, **kwargs):
        """Log debug messages"""
        return self.logger.debug(*args, **kwargs)

    def critical(self, *args, **kwargs):
        """Log critical messages"""
        return self.logger.critical(*args, **kwargs)

    def exception(self, *args, **kwargs):
        """Log exception messages"""
        return self.logger.exception(*args, **kwargs)


class ExitOnExceptionHandler(logging.StreamHandler):
    """Custom handler that exit if the log level is critical"""

    def emit(self, record):
        """Pass log messages on to its super and exit if the log level is critical"""
        super().emit(record)
        if record.levelno is logging.CRITICAL:
            raise SystemExit(-1)
