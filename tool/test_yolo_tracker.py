#!/usr/bin/env python3
"""
Smoke test: ByteTrack vs. predict() on the Pi.

Reads /tmp/yolo_clean.json (the same fixture the service exercises with
curl), pulls out `items[0].image_url` as a base64 JPEG data-URL, decodes
it, and runs the same Ultralytics model twice — once via `model.predict`
and once via `model.track(persist=True, tracker="bytetrack.yaml")` — with
a wall-clock time budget on each.

Use this to check whether tracking has become viable on a given Pi after:
  - a new lap wheel lands on PyPI
  - an ultralytics version bump
  - a torch / numpy pin change
  - a different tracker config (e.g. `--tracker=strongsort.yaml`)

Usage (on the Pi):
    /opt/onyx/.venv-monitoring-yolo/bin/python /opt/onyx/tool/test_yolo_tracker.py
    /opt/onyx/.venv-monitoring-yolo/bin/python /opt/onyx/tool/test_yolo_tracker.py \\
        --fixture /tmp/yolo_clean.json \\
        --model yolov8s.pt \\
        --imgsz 640 \\
        --conf 0.4 \\
        --tracker bytetrack.yaml \\
        --timeout 60

Exit code 0 if BOTH paths complete (track may still be broken but it
returned before the timeout). Exit code 2 if either hangs.
"""

from __future__ import annotations

import argparse
import base64
import io
import json
import re
import sys
import threading
import time
from pathlib import Path
from typing import Any, Dict, Optional


def _decode_data_url(raw_url: str) -> bytes:
    match = re.match(r"^data:.*?;base64,(.+)$", raw_url.strip(), re.IGNORECASE | re.DOTALL)
    if not match:
        raise ValueError("Expected a base64 data URL image.")
    return base64.b64decode(match.group(1))


def _load_fixture_image(path: Path) -> bytes:
    payload = json.loads(path.read_text(encoding="utf-8"))
    items = payload.get("items")
    if not isinstance(items, list) or not items:
        raise RuntimeError(f"{path} has no items[]")
    image_url = str(items[0].get("image_url", ""))
    if not image_url:
        raise RuntimeError(f"{path} items[0] missing image_url")
    return _decode_data_url(image_url)


def _run_with_watchdog(
    fn, *, timeout: float, label: str
) -> Dict[str, Any]:
    result_box: Dict[str, Any] = {}
    error_box: Dict[str, BaseException] = {}

    def _runner() -> None:
        try:
            result_box["value"] = fn()
        except BaseException as exc:  # noqa: BLE001
            error_box["value"] = exc

    thread = threading.Thread(target=_runner, name=f"yolo-{label}", daemon=True)
    started = time.monotonic()
    thread.start()
    thread.join(timeout=timeout)
    elapsed_ms = (time.monotonic() - started) * 1000.0
    if thread.is_alive():
        return {
            "label": label,
            "status": "HUNG",
            "elapsed_ms": elapsed_ms,
            "error": f"did not return within {timeout:.0f}s",
            "detections": None,
        }
    if "value" in error_box:
        return {
            "label": label,
            "status": "ERROR",
            "elapsed_ms": elapsed_ms,
            "error": str(error_box["value"]),
            "detections": None,
        }
    return {
        "label": label,
        "status": "OK",
        "elapsed_ms": elapsed_ms,
        "error": None,
        "detections": result_box.get("value"),
    }


def main(argv: Optional[list] = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--fixture", default="/tmp/yolo_clean.json")
    ap.add_argument("--model", default="yolov8s.pt")
    ap.add_argument("--imgsz", type=int, default=640)
    ap.add_argument("--conf", type=float, default=0.4)
    ap.add_argument("--tracker", default="bytetrack.yaml")
    ap.add_argument(
        "--timeout",
        type=float,
        default=60.0,
        help="Per-path wall-clock budget in seconds.",
    )
    args = ap.parse_args(argv)

    fixture = Path(args.fixture).expanduser().resolve()
    print(f"[test] loading fixture {fixture}")
    image_bytes = _load_fixture_image(fixture)
    print(f"[test] fixture JPEG: {len(image_bytes)} bytes")

    try:
        from PIL import Image  # noqa: F401 — used for decode path
        import numpy as np  # noqa: F401
        from ultralytics import YOLO
    except Exception as exc:
        print(f"[test] ERROR: missing deps: {exc}", file=sys.stderr)
        return 3

    from PIL import Image
    import numpy as np

    image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    image_arr = np.array(image)
    print(f"[test] decoded image shape: {image_arr.shape}")

    print(f"[test] loading model {args.model}")
    model = YOLO(args.model)

    def _predict_count() -> int:
        res = model.predict(
            source=image,
            imgsz=args.imgsz,
            conf=args.conf,
            verbose=False,
        )[0]
        return len(getattr(res, "boxes", []) or [])

    def _track_count() -> int:
        res = model.track(
            source=image,
            imgsz=args.imgsz,
            conf=args.conf,
            tracker=args.tracker,
            persist=True,
            verbose=False,
        )[0]
        return len(getattr(res, "boxes", []) or [])

    # Warm the model first with a cheap predict so weights are JIT'd.
    print("[test] warming model with dummy predict")
    dummy = np.zeros((args.imgsz, args.imgsz, 3), dtype=np.uint8)
    try:
        model.predict(source=dummy, imgsz=args.imgsz, conf=args.conf, verbose=False)
    except Exception as exc:
        print(f"[test] warmup raised: {exc}", file=sys.stderr)

    print(f"[test] running predict() with timeout={args.timeout:.0f}s")
    pr = _run_with_watchdog(_predict_count, timeout=args.timeout, label="predict")
    print(
        f"[test] predict: status={pr['status']} elapsed_ms={pr['elapsed_ms']:.0f} "
        f"detections={pr['detections']} error={pr['error']}"
    )

    print(f"[test] running track({args.tracker}) with timeout={args.timeout:.0f}s")
    tr = _run_with_watchdog(_track_count, timeout=args.timeout, label="track")
    print(
        f"[test] track:   status={tr['status']} elapsed_ms={tr['elapsed_ms']:.0f} "
        f"detections={tr['detections']} error={tr['error']}"
    )

    if pr["status"] != "OK" or tr["status"] == "HUNG":
        # Any hang or predict failure is a non-zero exit for scripting.
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
