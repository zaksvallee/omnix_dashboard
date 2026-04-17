#!/usr/bin/env python3
"""Line-buffered rotating sink for long-running ONYX service logs."""

from __future__ import annotations

import argparse
import logging
import sys
from logging.handlers import RotatingFileHandler
from pathlib import Path


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Read stdin and write it to a rotating log file.",
    )
    parser.add_argument("--file", required=True, help="Log file path.")
    parser.add_argument(
        "--max-bytes",
        type=int,
        default=50 * 1024 * 1024,
        help="Rotate after this many bytes.",
    )
    parser.add_argument(
        "--backups",
        type=int,
        default=3,
        help="How many rotated files to keep.",
    )
    parser.add_argument(
        "--tee",
        action="store_true",
        help="Echo each line back to stdout while logging it.",
    )
    return parser.parse_args()


def main() -> int:
    args = _parse_args()
    log_path = Path(args.file)
    log_path.parent.mkdir(parents=True, exist_ok=True)

    logger = logging.getLogger("onyx.rotating_log_sink")
    logger.setLevel(logging.INFO)
    logger.propagate = False
    logger.handlers.clear()

    handler = RotatingFileHandler(
        log_path,
        maxBytes=max(args.max_bytes, 1),
        backupCount=max(args.backups, 1),
        encoding="utf-8",
    )
    handler.setFormatter(logging.Formatter("%(message)s"))
    logger.addHandler(handler)

    try:
        for raw_line in sys.stdin:
            line = raw_line.rstrip("\n")
            logger.info(line)
            for attached_handler in logger.handlers:
                attached_handler.flush()
            if args.tee:
                print(line, flush=True)
    finally:
        for attached_handler in logger.handlers:
            attached_handler.flush()
            attached_handler.close()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
