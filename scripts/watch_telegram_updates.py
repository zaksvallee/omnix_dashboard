#!/usr/bin/env python3
"""Watch recent Telegram bot updates for a configured ONYX chat."""

from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.parse
import urllib.request
import urllib.error
from pathlib import Path


def _load_config(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Watch Telegram bot updates for the ONYX client chat.",
    )
    parser.add_argument(
        "--config",
        default="config/onyx.local.json",
        help="Path to ONYX dart-define JSON config.",
    )
    parser.add_argument(
        "--chat-id",
        default="",
        help="Override Telegram chat id. Defaults to ONYX_TELEGRAM_CHAT_ID.",
    )
    parser.add_argument(
        "--thread-id",
        type=int,
        default=None,
        help="Optional Telegram thread id filter.",
    )
    parser.add_argument(
        "--polls",
        type=int,
        default=12,
        help="Number of poll cycles to run.",
    )
    parser.add_argument(
        "--interval-seconds",
        type=float,
        default=5.0,
        help="Sleep between polls.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=20,
        help="Telegram getUpdates limit.",
    )
    return parser.parse_args()


def _fetch_updates(token: str, limit: int) -> list[dict]:
    url = (
        f"https://api.telegram.org/bot{token}/getUpdates?"
        + urllib.parse.urlencode({"limit": limit, "timeout": 0})
    )
    with urllib.request.urlopen(url, timeout=20) as response:
        payload = json.load(response)
    if payload.get("ok") is not True:
        raise RuntimeError(f"Telegram getUpdates failed: {payload}")
    return list(payload.get("result", []))


def _format_fetch_error(error: Exception) -> str:
    if isinstance(error, urllib.error.HTTPError):
      return f"HTTP {error.code}: {error.reason}"
    if isinstance(error, urllib.error.URLError):
      return f"network error: {error.reason}"
    return str(error).strip() or error.__class__.__name__


def _extract_row(item: dict) -> dict:
    message = (
        item.get("message")
        or item.get("edited_message")
        or item.get("channel_post")
        or item.get("edited_channel_post")
        or {}
    )
    callback = item.get("callback_query") or {}
    callback_message = callback.get("message") or {}
    chat = message.get("chat") or callback_message.get("chat") or {}
    sender = message.get("from") or callback.get("from") or {}
    return {
        "update_id": item.get("update_id"),
        "chat_id": str(chat.get("id", "")),
        "thread_id": message.get("message_thread_id")
        or callback_message.get("message_thread_id"),
        "from": sender.get("username") or sender.get("id"),
        "text": (message.get("text") or callback.get("data") or "").strip(),
    }


def main() -> int:
    args = _parse_args()
    config_path = Path(args.config)
    if not config_path.exists():
        print(f"Missing config: {config_path}", file=sys.stderr)
        return 1

    config = _load_config(config_path)
    token = str(config.get("ONYX_TELEGRAM_BOT_TOKEN", "")).strip()
    chat_id = args.chat_id.strip() or str(config.get("ONYX_TELEGRAM_CHAT_ID", "")).strip()
    if not token:
        print("ONYX_TELEGRAM_BOT_TOKEN is missing.", file=sys.stderr)
        return 1
    if not chat_id:
        print("Telegram chat id is missing.", file=sys.stderr)
        return 1

    print(
        f"Watching Telegram updates for chat={chat_id}"
        + (
            f" thread={args.thread_id}"
            if args.thread_id is not None
            else ""
        )
    )
    for poll_index in range(args.polls):
        try:
            updates = _fetch_updates(token=token, limit=args.limit)
        except Exception as error:  # pragma: no cover - defensive live-watch path
            print(f"poll {poll_index}: error={_format_fetch_error(error)}")
            if poll_index < args.polls - 1:
                time.sleep(max(args.interval_seconds, 0))
            continue
        rows = []
        for item in updates:
            row = _extract_row(item)
            if row["chat_id"] != chat_id:
                continue
            if args.thread_id is not None and row["thread_id"] != args.thread_id:
                continue
            rows.append(row)
        print(f"poll {poll_index}: count={len(rows)}")
        for row in rows[-5:]:
            print(json.dumps(row, ensure_ascii=False))
        if poll_index < args.polls - 1:
            time.sleep(max(args.interval_seconds, 0))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
