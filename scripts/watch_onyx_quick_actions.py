#!/usr/bin/env python3
"""Follow an ONYX app log and print handled Telegram quick-action audit lines."""

from __future__ import annotations

import argparse
import sys
import time
from pathlib import Path


MATCH = "ONYX Telegram quick action handled:"


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Watch an ONYX app log for handled Telegram quick actions.",
    )
    parser.add_argument(
        "--log-file",
        default="tmp/telegram_quick_action_live.log",
        help="Path to the ONYX app log file.",
    )
    parser.add_argument(
        "--poll-seconds",
        type=float,
        default=0.5,
        help="Sleep interval while waiting for new log lines.",
    )
    parser.add_argument(
        "--timeout-seconds",
        type=float,
        default=0.0,
        help="Optional timeout. Use 0 to wait indefinitely.",
    )
    return parser.parse_args()


def main() -> int:
    args = _parse_args()
    log_path = Path(args.log_file)
    deadline = None
    if args.timeout_seconds > 0:
        deadline = time.monotonic() + args.timeout_seconds

    print(f"Watching ONYX quick-action log: {log_path}")
    while not log_path.exists():
        if deadline is not None and time.monotonic() >= deadline:
            print("Timed out waiting for log file.", file=sys.stderr)
            return 1
        time.sleep(max(args.poll_seconds, 0.1))

    with log_path.open("r", encoding="utf-8", errors="replace") as handle:
        handle.seek(0, 2)
        while True:
            line = handle.readline()
            if line:
                if MATCH in line:
                    print(line.rstrip())
                continue
            if deadline is not None and time.monotonic() >= deadline:
                return 0
            time.sleep(max(args.poll_seconds, 0.1))


if __name__ == "__main__":
    raise SystemExit(main())
