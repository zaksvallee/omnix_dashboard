#!/usr/bin/env python3
import argparse
import io
import json
import os
import select
import signal
import subprocess
import sys
import threading
import time
import urllib.parse
from dataclasses import dataclass, field
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
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
        reconnect_delay_seconds: float = 5.0,
    ) -> None:
        super().__init__(daemon=True, name=f"rtsp-channel-{state.channel_id}")
        self._state = state
        self._rtsp_url = rtsp_url
        self._stop_event = stop_event
        self._poll_interval_seconds = poll_interval_seconds
        self._reconnect_delay_seconds = reconnect_delay_seconds

    def run(self) -> None:
        while not self._stop_event.is_set():
            process = self._spawn_ffmpeg()
            buffer = bytearray()
            connected_at = time.time()
            last_frame_at: Optional[float] = None
            error = "warming_up"
            try:
                while not self._stop_event.is_set():
                    if process.poll() is not None:
                        error = f"FFmpeg exited ({process.returncode})"
                        break

                    ready, _, _ = select.select([process.stdout], [], [], 1.0)
                    if ready:
                        chunk = os.read(process.stdout.fileno(), 65536)
                        if not chunk:
                            error = "RTSP frame stream ended"
                            break
                        buffer.extend(chunk)
                        while True:
                            soi = buffer.find(b"\xff\xd8")
                            if soi < 0:
                                if len(buffer) > 2_000_000:
                                    del buffer[:-2]
                                break
                            eoi = buffer.find(b"\xff\xd9", soi + 2)
                            if eoi < 0:
                                if soi > 0:
                                    del buffer[:soi]
                                break
                            jpeg = bytes(buffer[soi:eoi + 2])
                            del buffer[:eoi + 2]
                            try:
                                image = Image.open(io.BytesIO(jpeg))
                                image.load()
                                resolution = [int(image.size[0]), int(image.size[1])]
                            except Exception:
                                continue
                            now = time.time()
                            last_frame_at = now
                            with self._state.lock:
                                self._state.latest_jpeg = jpeg
                                self._state.latest_resolution = resolution
                                self._state.latest_frame_at_epoch = now
                                self._state.connected = True
                                self._state.error = ""
                            time.sleep(self._poll_interval_seconds)
                    else:
                        now = time.time()
                        if last_frame_at is None:
                            if now - connected_at >= 30:
                                error = "RTSP warmup timeout"
                                break
                            with self._state.lock:
                                self._state.connected = False
                                self._state.error = "warming_up"
                        elif now - last_frame_at >= 15:
                            error = "RTSP frame stalled"
                            break
            finally:
                self._terminate_process(process)

            with self._state.lock:
                self._state.connected = False
                if self._state.latest_frame_at_epoch is None and (
                    time.time() - self._state.started_at_epoch
                ) < 30:
                    self._state.error = "warming_up"
                else:
                    self._state.error = error
            time.sleep(self._reconnect_delay_seconds)

    def _spawn_ffmpeg(self) -> subprocess.Popen:
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
            self._rtsp_url,
            "-vf",
            "fps=1",
            "-q:v",
            "2",
            "-f",
            "image2pipe",
            "-vcodec",
            "mjpeg",
            "-",
        ]
        return subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            bufsize=0,
        )

    def _terminate_process(self, process: subprocess.Popen) -> None:
        if process.poll() is not None:
            return
        process.terminate()
        try:
            process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            process.kill()


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
        jpeg = self.app.capture_frame(channel_id)
        with state.lock:
            error = state.error
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

    def capture_frame(self, channel_id: int) -> Optional[bytes]:
        state = self.channel_states[channel_id]
        rtsp_url = self.rtsp_urls[channel_id]
        jpeg, resolution, error = _capture_rtsp_frame_once(rtsp_url, timeout_seconds=40)
        with state.lock:
            state.started_at_epoch = time.time()
            if jpeg:
                state.latest_jpeg = jpeg
                state.latest_resolution = resolution
                state.latest_frame_at_epoch = time.time()
                state.connected = True
                state.error = ""
            else:
                state.connected = False
                state.error = error or "RTSP frame decode failed"
        return jpeg


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
