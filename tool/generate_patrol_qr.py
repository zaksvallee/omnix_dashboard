#!/usr/bin/env python3

import argparse
import pathlib
import re
import sys

try:
    import qrcode
except ImportError as exc:  # pragma: no cover - runtime dependency
    raise SystemExit(
        "qrcode package is required. Install with: pip3 install 'qrcode[pil]'"
    ) from exc


def _slugify(value: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9]+", "_", value.strip())
    cleaned = cleaned.strip("_")
    return cleaned or "checkpoint"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate ONYX guard patrol QR checkpoint PNG."
    )
    parser.add_argument("--site-id", required=True, help="Site identifier")
    parser.add_argument(
        "--checkpoint-name", required=True, help="Human label for the checkpoint"
    )
    parser.add_argument(
        "--checkpoint-code", required=True, help="Unique QR checkpoint code"
    )
    parser.add_argument(
        "--output-dir",
        default="tool/patrol_qr",
        help="Base output directory for QR PNG files",
    )
    args = parser.parse_args()

    payload = (
        f"onyx://patrol/scan?site={args.site_id.strip()}"
        f"&checkpoint={args.checkpoint_code.strip()}"
    )
    output_dir = pathlib.Path(args.output_dir).expanduser().resolve() / args.site_id
    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / f"{_slugify(args.checkpoint_name)}.png"

    image = qrcode.make(payload)
    image.save(output_path)

    print(f"[ONYX] QR generated: {output_path}")
    print(f"[ONYX] Payload: {payload}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
