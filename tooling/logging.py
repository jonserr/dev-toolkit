"""Copyable structured logging for Python 3.11+, standard library only

Format: TIMESTAMP | LEVEL | COMPONENT | MESSAGE
Env: LOG_LEVEL, LOG_FORMAT (text|json), LOG_FILE

Copy into a project as log_config.py, never as logging.py
A project module named logging shadows stdlib logging for every library

Usage:
    from log_config import setup_logging, log_execution

    log = setup_logging("etl")
    with log_execution(log, "load"):
        ...
"""

from __future__ import annotations

import contextlib
import json
import logging
import os
import sys
import time
from collections.abc import Generator
from datetime import UTC, datetime
from pathlib import Path
from types import TracebackType

TEXT_FORMAT = "%(asctime)s | %(levelname)-5s | %(name)s | %(message)s"
DATE_FORMAT = "%Y-%m-%dT%H:%M:%SZ"


class UTCFormatter(logging.Formatter):
    """Text formatter with UTC timestamps"""

    converter = time.gmtime


class JSONFormatter(logging.Formatter):
    """One JSON object per line for log shippers"""

    def format(self, record: logging.LogRecord) -> str:
        payload = {
            "timestamp": datetime.fromtimestamp(record.created, tz=UTC).strftime(DATE_FORMAT),
            "level": record.levelname,
            "component": record.name,
            "message": record.getMessage(),
        }
        # Extra fields passed via logger.info(..., extra={...})
        for key, value in record.__dict__.items():
            if key not in _RESERVED and not key.startswith("_"):
                payload[key] = value
        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)
        return json.dumps(payload, default=str)


_RESERVED = set(vars(logging.makeLogRecord({}))) | {"message", "asctime"}


def setup_logging(
    component: str,
    level: str | None = None,
    log_file: str | Path | None = None,
    fmt: str | None = None,
) -> logging.Logger:
    """Configures root handlers once and returns named component logger"""
    level = (level or os.getenv("LOG_LEVEL", "INFO")).upper()
    fmt = (fmt or os.getenv("LOG_FORMAT", "text")).lower()
    log_file = log_file or os.getenv("LOG_FILE")

    formatter: logging.Formatter = (
        JSONFormatter() if fmt == "json" else UTCFormatter(TEXT_FORMAT, DATE_FORMAT)
    )

    root = logging.getLogger()
    root.handlers.clear()
    root.setLevel(level)

    console = logging.StreamHandler(sys.stderr)
    console.setFormatter(formatter)
    root.addHandler(console)

    if log_file:
        Path(log_file).parent.mkdir(parents=True, exist_ok=True)
        file_handler = logging.FileHandler(log_file, encoding="utf-8")
        file_handler.setFormatter(formatter)
        root.addHandler(file_handler)

    logger = logging.getLogger(component)
    _install_excepthook(logger)
    return logger


def _install_excepthook(logger: logging.Logger) -> None:
    """Logs uncaught exceptions before interpreter exit"""

    def hook(
        exc_type: type[BaseException],
        exc: BaseException,
        tb: TracebackType | None,
    ) -> None:
        if issubclass(exc_type, KeyboardInterrupt):
            sys.__excepthook__(exc_type, exc, tb)
            return
        logger.critical("uncaught exception", exc_info=(exc_type, exc, tb))

    sys.excepthook = hook


@contextlib.contextmanager
def log_execution(logger: logging.Logger, step: str) -> Generator[None, None, None]:
    """Logs step start, duration, and status, then re-raises failures"""
    start = time.perf_counter()
    logger.info("step start: %s", step)
    try:
        yield
    except Exception:
        elapsed = time.perf_counter() - start
        logger.exception("step failed: %s elapsed=%.2fs", step, elapsed)
        raise
    elapsed = time.perf_counter() - start
    logger.info("step done: %s elapsed=%.2fs", step, elapsed)
