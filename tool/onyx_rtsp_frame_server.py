#!/usr/bin/env python3
import argparse
import json
import io
import os
import signal
import subprocess
import sys
import threading
import time
import urllib.parse
from dataclasses import dataclass, field
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Dict, Optional

from PIL import Image

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


@dataclass
class ChannelState:
    channel_id: int
    latest_jpeg: Optional[bytes] = None
    latest_frame_at_epoch: Optional[float] = None
    latest_resolution: Optional[list[int]] = None
    connected: bool = False
    error: str = "warming_up"
    started_at_epoch: float = field(default_factory=time.time)
    lock: threading.Lock = field(default_factory=threading.Lock)


def _capture_rtsp_frame_once(
    rtsp_url: str,
    *,
    timeout_seconds: int = 40,
) -> tuple[Optional[bytes], Optional[list[int]], str]:
    command = [
        "ffmpeg",
        "-hide_banner",
        "-loglevel",
        "error",
        "-rtsp_transport",
        "tcp",
        "-fflags",
        "nobuffer",
        "-flags",
        "low_delay",
        "-i",
        rtsp_url,
        "-frames:v",
        "1",
        "-q:v",
        "2",
        "-f",
        "image2pipe",
        "-vcodec",
        "mjpeg",
        "-",
    ]
    try:
        completed = subprocess.run(
            command,
            capture_output=True,
            timeout=timeout_seconds,
            check=False,
        )
    except subprocess.TimeoutExpired:
        return None, None, "RTSP frame timeout"
    if completed.returncode != 0 or not completed.stdout:
        stderr = completed.stderr.decode("utf-8", errors="ignore").strip()
        return None, None, stderr or "RTSP frame decode failed"
    try:
        image = Image.open(io.BytesIO(completed.stdout))
        image.load()
        resolution = [int(image.size[0]), int(image.size[1])]
    except Exception as exc:  # pragma: no cover - defensive
        return None, None, f"JPEG decode failed: {exc}"
    return completed.stdout, resolution, ""


class RtspChannelWorker(threading.Thread):
    def __init__(
        self,
        *,
        state: ChannelState,
        rtsp_url: str,
        stop_event: threading.Event,
        poll_interval_seconds: float = 1.5,
        reconnect_delay_seconds: float = 10.0,
    ) -> None:
        super().__init__(daemon=True, name=f"rtsp-channel-{state.channel_id}")
        self._state = state
        self._rtsp_url = rtsp_url
        self._stop_event = stop_event
        self._poll_interval_seconds = poll_interval_seconds
        self._reconnect_delay_seconds = reconnect_delay_seconds

    def run(self) -> None:
        while not self._stop_event.is_set():
            jpeg, resolution, error = _capture_rtsp_frame_once(
                self._rtsp_url,
                timeout_seconds=30,
            )
            now = time.time()
            with self._state.lock:
                if jpeg:
                    self._state.latest_jpeg = jpeg
                    self._state.latest_resolution = resolution
                    self._state.latest_frame_at_epoch = now
                    self._state.connected = True
                    self._state.error = ""
                else:
                    self._state.connected = False
                    if self._state.latest_frame_at_epoch is None and (
                        now - self._state.started_at_epoch
                    ) < 30:
                        self._state.error = "warming_up"
                    else:
                        self._state.error = error or "RTSP frame decode failed"
            time.sleep(
                self._poll_interval_seconds if jpeg else self._reconnect_delay_seconds
            )


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
        state = self.app.channel_states.get(channel_id)
        if state is None:
            self.send_error(404, "Unknown channel")
            return
        self.app.ensure_worker(channel_id)
        deadline = time.time() + 3
        jpeg = None
        error = "Frame unavailable"
        while time.time() < deadline and jpeg is None:
            with state.lock:
                jpeg = state.latest_jpeg
                error = state.error
            if jpeg is not None:
                break
            time.sleep(0.1)
        if not jpeg:
            self.send_error(503, error or "Frame unavailable")
            return

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
        channel_states: Dict[int, ChannelState],
        rtsp_urls: Dict[int, str],
        stop_event: threading.Event,
    ) -> None:
        self.host = host
        self.port = port
        self.channel_states = channel_states
        self.rtsp_urls = rtsp_urls
        self.stop_event = stop_event
        self._workers: Dict[int, RtspChannelWorker] = {}
        self._lock = threading.Lock()
        self.httpd = ThreadingHTTPServer((host, port), RtspFrameHandler)
        self.httpd.app = self  # type: ignore[attr-defined]

    def serve_forever(self) -> None:
        self.httpd.serve_forever(poll_interval=0.5)

    def shutdown(self) -> None:
        self.httpd.shutdown()
        self.httpd.server_close()

    def health_payload(self) -> dict:
        channels = {}
        ready = False
        for channel_id, state in self.channel_states.items():
            with state.lock:
                latest_at = state.latest_frame_at_epoch
                latest_resolution = state.latest_resolution
                connected = state.connected
                error = state.error
            if latest_at is not None:
                ready = True
            channels[str(channel_id)] = {
                "connected": connected,
                "latest_frame_at_epoch": latest_at,
                "latest_resolution": latest_resolution,
                "error": error,
            }
        return {
            "status": "ok",
            "ready": ready,
            "channel_count": len(self.channel_states),
            "channels": channels,
        }

    def ensure_worker(self, channel_id: int) -> None:
        with self._lock:
            existing = self._workers.get(channel_id)
            if existing is not None and existing.is_alive():
                return
            state = self.channel_states[channel_id]
            with state.lock:
                state.started_at_epoch = time.time()
                if state.latest_frame_at_epoch is None:
                    state.error = "warming_up"
            worker = RtspChannelWorker(
                state=state,
                rtsp_url=self.rtsp_urls[channel_id],
                stop_event=self.stop_event,
            )
            worker.start()
            self._workers[channel_id] = worker
            print(
                f"[ONYX] RTSP frame worker started for CH{channel_id} -> "
                f"{self.rtsp_urls[channel_id]}"
            )

    def ensure_all_workers(self) -> None:
        for channel_id in sorted(self.channel_states.keys()):
            self.ensure_worker(channel_id)

    def warmup_channels(self, timeout_seconds: float = 30.0) -> None:
        deadline = time.time() + timeout_seconds
        pending = set(self.channel_states.keys())
        while pending and time.time() < deadline and not self.stop_event.is_set():
            ready_now = set()
            for channel_id in pending:
                state = self.channel_states[channel_id]
                with state.lock:
                    if state.latest_jpeg:
                        ready_now.add(channel_id)
            pending -= ready_now
            if pending:
                time.sleep(0.25)
        if pending:
            print(
                "[ONYX] RTSP frame warmup incomplete for "
                + ", ".join(f"CH{channel_id}" for channel_id in sorted(pending)),
                file=sys.stderr,
            )
        else:
            print("[ONYX] RTSP frame warmup complete for all configured channels")


def main() -> int:
    parser = argparse.ArgumentParser(description="ONYX persistent RTSP frame server")
    parser.add_argument("--config", default="config/onyx.local.json")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=11638)
    parser.add_argument("--channels", default="5,12,16,4")
    args = parser.parse_args()

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
    channel_states = {channel_id: ChannelState(channel_id=channel_id) for channel_id in channel_ids}
    stop_event = threading.Event()
    rtsp_urls = {
        channel_id: (
            f"rtsp://{nvr_user}:{encoded_password}@{nvr_host}:554/"
            f"Streaming/Channels/{channel_id}01"
        )
        for channel_id in channel_ids
    }

    server = RtspFrameServer(
        host=args.host,
        port=args.port,
        channel_states=channel_states,
        rtsp_urls=rtsp_urls,
        stop_event=stop_event,
    )

    def _shutdown(*_args) -> None:
        stop_event.set()
        server.shutdown()

    signal.signal(signal.SIGTERM, _shutdown)
    signal.signal(signal.SIGINT, _shutdown)

    server.ensure_all_workers()
    server.warmup_channels(timeout_seconds=30.0)
    print(f"[ONYX] RTSP frame server listening on http://{args.host}:{args.port}")
    try:
        server.serve_forever()
    finally:
        stop_event.set()
        for worker in list(server._workers.values()):
            worker.join(timeout=2)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
