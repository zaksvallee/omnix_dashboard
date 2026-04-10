#!/usr/bin/env python3
import argparse
import json
import os
import signal
import subprocess
import sys
import threading
import time
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Dict, Optional

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(line_buffering=True)
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(line_buffering=True)


def _load_config(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def _config_value(config: dict, key: str, fallback: str = "") -> str:
    value = config.get(key, fallback)
    if value is None:
        return fallback
    return str(value)


def _channel_state_path(frame_dir: Path, channel_id: int) -> Path:
    return frame_dir / f"channel_{channel_id}.json"


def _channel_frame_path(frame_dir: Path, channel_id: int) -> Path:
    return frame_dir / f"channel_{channel_id}.jpg"


def _initial_channel_state() -> dict:
    return {
        "connected": False,
        "latest_frame_at_epoch": None,
        "latest_resolution": None,
        "error": "idle",
    }


def _read_channel_state(frame_dir: Path, channel_id: int) -> dict:
    path = _channel_state_path(frame_dir, channel_id)
    if not path.exists():
        return _initial_channel_state()
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {
            "connected": False,
            "latest_frame_at_epoch": None,
            "latest_resolution": None,
            "error": "state read failed",
        }


def _write_channel_state(frame_dir: Path, channel_id: int, payload: dict) -> None:
    path = _channel_state_path(frame_dir, channel_id)
    temp_path = path.with_suffix(".json.tmp")
    temp_path.write_text(json.dumps(payload), encoding="utf-8")
    temp_path.replace(path)


def _run_worker(args: argparse.Namespace) -> int:
    import cv2

    os.environ.setdefault(
        "OPENCV_FFMPEG_CAPTURE_OPTIONS",
        "rtsp_transport;tcp|fflags;nobuffer|flags;low_delay|max_delay;500000|stimeout;5000000",
    )

    frame_dir = Path(args.frame_dir)
    frame_dir.mkdir(parents=True, exist_ok=True)
    state = _initial_channel_state()
    _write_channel_state(frame_dir, args.channel_id, state)

    while True:
        cap = None
        try:
            cap = cv2.VideoCapture(args.rtsp_url, cv2.CAP_FFMPEG)
            cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
            if not cap.isOpened():
                state.update({"connected": False, "error": "RTSP open failed"})
                _write_channel_state(frame_dir, args.channel_id, state)
                time.sleep(args.reconnect_delay_seconds)
                continue

            state.update({"connected": True, "error": ""})
            _write_channel_state(frame_dir, args.channel_id, state)

            while True:
                ok, frame = cap.read()
                if not ok or frame is None:
                    state.update({"connected": False, "error": "RTSP frame decode failed"})
                    _write_channel_state(frame_dir, args.channel_id, state)
                    break

                encoded = cv2.imencode(
                    ".jpg",
                    frame,
                    [int(cv2.IMWRITE_JPEG_QUALITY), args.jpeg_quality],
                )
                if not encoded[0]:
                    state.update({"connected": False, "error": "JPEG encode failed"})
                    _write_channel_state(frame_dir, args.channel_id, state)
                    continue

                frame_bytes = encoded[1].tobytes()
                frame_path = _channel_frame_path(frame_dir, args.channel_id)
                temp_frame = frame_path.with_suffix(".jpg.tmp")
                temp_frame.write_bytes(frame_bytes)
                temp_frame.replace(frame_path)

                height, width = frame.shape[:2]
                state.update(
                    {
                        "connected": True,
                        "latest_frame_at_epoch": time.time(),
                        "latest_resolution": [int(width), int(height)],
                        "error": "",
                    }
                )
                _write_channel_state(frame_dir, args.channel_id, state)
        except KeyboardInterrupt:
            break
        except Exception as exc:
            state.update({"connected": False, "error": str(exc)})
            _write_channel_state(frame_dir, args.channel_id, state)
        finally:
            if cap is not None:
                cap.release()
        time.sleep(args.reconnect_delay_seconds)
    return 0


class RtspFrameHandler(BaseHTTPRequestHandler):
    server_version = "OnyxRtspFrameServer/1.0"

    def do_GET(self) -> None:  # noqa: N802
        if self.path == "/health":
            self._serve_health()
            return
        if self.path.startswith("/frame/"):
            self._serve_frame()
            return
        self.send_error(404, "Not found")

    def log_message(self, fmt: str, *args) -> None:
        return

    @property
    def app(self) -> "RtspFrameServer":
        return self.server.app  # type: ignore[attr-defined]

    def _serve_health(self) -> None:
        body = json.dumps(self.app.health_payload()).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def _serve_frame(self) -> None:
        channel_raw = self.path.rsplit("/", 1)[-1]
        try:
            channel_id = int(channel_raw)
        except ValueError:
            self.send_error(400, "Invalid channel id")
            return

        if not self.app.ensure_worker(channel_id):
            self.send_error(404, "Unknown channel")
            return

        frame_path = _channel_frame_path(self.app.frame_dir, channel_id)
        deadline = time.time() + 8.0
        while time.time() < deadline:
            if frame_path.exists() and frame_path.stat().st_size > 0:
                break
            time.sleep(0.2)

        if not frame_path.exists() or frame_path.stat().st_size <= 0:
            self.send_error(503, "Frame unavailable")
            return

        jpeg = frame_path.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", "image/jpeg")
        self.send_header("Content-Length", str(len(jpeg)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(jpeg)


class RtspFrameServer:
    def __init__(
        self,
        *,
        host: str,
        port: int,
        python_bin: str,
        script_path: Path,
        config_path: str,
        frame_dir: Path,
        rtsp_urls: Dict[int, str],
        jpeg_quality: int,
    ) -> None:
        self.host = host
        self.port = port
        self.python_bin = python_bin
        self.script_path = script_path
        self.config_path = config_path
        self.frame_dir = frame_dir
        self.rtsp_urls = rtsp_urls
        self.jpeg_quality = jpeg_quality
        self._workers: Dict[int, subprocess.Popen] = {}
        self._lock = threading.Lock()
        self._stop_event = threading.Event()
        self._supervisor = threading.Thread(target=self._supervise, daemon=True, name="rtsp-supervisor")
        self.httpd = ThreadingHTTPServer((host, port), RtspFrameHandler)
        self.httpd.app = self  # type: ignore[attr-defined]

    def start(self) -> None:
        self.frame_dir.mkdir(parents=True, exist_ok=True)
        for channel_id in sorted(self.rtsp_urls):
            _write_channel_state(self.frame_dir, channel_id, _initial_channel_state())
        self._supervisor.start()
        for channel_id in sorted(self.rtsp_urls):
            self.ensure_worker(channel_id)

    def serve_forever(self) -> None:
        self.httpd.serve_forever(poll_interval=0.5)

    def shutdown(self) -> None:
        self._stop_event.set()
        self.httpd.shutdown()
        self.httpd.server_close()
        with self._lock:
            workers = list(self._workers.values())
        for worker in workers:
            if worker.poll() is None:
                worker.terminate()
        for worker in workers:
            try:
                worker.wait(timeout=3)
            except Exception:
                pass

    def ensure_worker(self, channel_id: int) -> bool:
        if channel_id not in self.rtsp_urls:
            return False
        with self._lock:
            worker = self._workers.get(channel_id)
            if worker is not None and worker.poll() is None:
                return True
            command = [
                self.python_bin,
                str(self.script_path),
                "--worker",
                "--channel-id",
                str(channel_id),
                "--rtsp-url",
                self.rtsp_urls[channel_id],
                "--frame-dir",
                str(self.frame_dir),
                "--jpeg-quality",
                str(self.jpeg_quality),
                "--config",
                self.config_path,
            ]
            worker = subprocess.Popen(command)
            self._workers[channel_id] = worker
        print(f"[ONYX] RTSP frame worker started for CH{channel_id} -> {self.rtsp_urls[channel_id]}")
        return True

    def health_payload(self) -> dict:
        channels = {}
        ready = False
        for channel_id in sorted(self.rtsp_urls):
            state = _read_channel_state(self.frame_dir, channel_id)
            if state.get("latest_frame_at_epoch") is not None:
                ready = True
            channels[str(channel_id)] = state
        return {
            "status": "ok",
            "ready": ready,
            "channel_count": len(channels),
            "channels": channels,
        }

    def _supervise(self) -> None:
        while not self._stop_event.is_set():
            time.sleep(2)
            with self._lock:
                items = list(self._workers.items())
            for channel_id, worker in items:
                exit_code = worker.poll()
                if exit_code is None:
                    continue
                print(f"[ONYX] Restarting RTSP frame worker for CH{channel_id} (exit={exit_code})")
                with self._lock:
                    self._workers.pop(channel_id, None)
                self.ensure_worker(channel_id)


def main() -> int:
    parser = argparse.ArgumentParser(description="ONYX persistent RTSP frame server")
    parser.add_argument("--config", default="config/onyx.local.json")
    parser.add_argument("--host", default=os.environ.get("ONYX_RTSP_FRAME_SERVER_HOST", "127.0.0.1"))
    parser.add_argument(
        "--port",
        type=int,
        default=int(os.environ.get("ONYX_RTSP_FRAME_SERVER_PORT", "11638")),
    )
    parser.add_argument(
        "--channels",
        default=os.environ.get("ONYX_RTSP_FRAME_SERVER_CHANNELS", "5,12,16,4"),
    )
    parser.add_argument(
        "--jpeg-quality",
        type=int,
        default=int(os.environ.get("ONYX_RTSP_FRAME_SERVER_JPEG_QUALITY", "92")),
    )
    parser.add_argument("--worker", action="store_true")
    parser.add_argument("--channel-id", type=int)
    parser.add_argument("--rtsp-url")
    parser.add_argument(
        "--frame-dir",
        default=os.environ.get("ONYX_RTSP_FRAME_SERVER_FRAME_DIR", "tmp/onyx_rtsp_frames"),
    )
    parser.add_argument(
        "--reconnect-delay-seconds",
        type=float,
        default=float(os.environ.get("ONYX_RTSP_FRAME_SERVER_RECONNECT_SECONDS", "2.0")),
    )
    args = parser.parse_args()

    if args.worker:
        if args.channel_id is None or not args.rtsp_url:
            print("[ONYX] RTSP worker missing required args", file=sys.stderr)
            return 2
        return _run_worker(args)

    config = _load_config(args.config)
    nvr_host = _config_value(
        config,
        "ONYX_DVR_PROXY_UPSTREAM_HOST",
        _config_value(config, "ONYX_HIK_HOST", "192.168.0.117"),
    )
    nvr_user = _config_value(
        config,
        "ONYX_DVR_PROXY_UPSTREAM_USER",
        _config_value(config, "ONYX_HIK_USERNAME", "admin"),
    )
    nvr_password = _config_value(
        config,
        "ONYX_DVR_PROXY_UPSTREAM_PASSWORD",
        _config_value(config, "ONYX_HIK_PASSWORD", ""),
    )
    if not nvr_password:
        print("[ONYX] RTSP frame server: missing NVR password", file=sys.stderr)
        return 1

    encoded_password = urllib.parse.quote(nvr_password, safe="")
    channel_ids = [int(part.strip()) for part in args.channels.split(",") if part.strip()]
    rtsp_urls = {
        channel_id: (
            f"rtsp://{nvr_user}:{encoded_password}@{nvr_host}:554/"
            f"Streaming/Channels/{channel_id}01"
        )
        for channel_id in channel_ids
    }

    frame_dir = Path(args.frame_dir)
    server = RtspFrameServer(
        host=args.host,
        port=args.port,
        python_bin=sys.executable,
        script_path=Path(__file__).resolve(),
        config_path=args.config,
        frame_dir=frame_dir,
        rtsp_urls=rtsp_urls,
        jpeg_quality=args.jpeg_quality,
    )

    def _shutdown(*_args) -> None:
        server.shutdown()

    signal.signal(signal.SIGTERM, _shutdown)
    signal.signal(signal.SIGINT, _shutdown)

    print(f"[ONYX] RTSP frame server listening on http://{args.host}:{args.port}")
    server.start()
    try:
        server.serve_forever()
    finally:
        server.shutdown()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
