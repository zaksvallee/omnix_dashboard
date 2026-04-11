#!/usr/bin/env python3
import argparse
import io
import json
import os
import signal
import sys
import threading
import time
import urllib.parse
import urllib.request
import cv2
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
    source: str = "warming_up"
    started_at_epoch: float = field(default_factory=time.time)
    first_frame_logged: bool = False
    first_hd_frame_logged: bool = False
    low_resolution_warned: bool = False
    lock: threading.Lock = field(default_factory=threading.Lock)


def _capture_isapi_snapshot_once(
    snapshot_url: str,
    *,
    username: str,
    password: str,
    timeout_seconds: int = 10,
) -> tuple[Optional[bytes], Optional[list[int]], str]:
    password_manager = urllib.request.HTTPPasswordMgrWithDefaultRealm()
    password_manager.add_password(None, snapshot_url, username, password)
    opener = urllib.request.build_opener(
        urllib.request.HTTPDigestAuthHandler(password_manager)
    )
    request = urllib.request.Request(snapshot_url)
    try:
        with opener.open(request, timeout=timeout_seconds) as response:
            jpeg = response.read()
    except Exception as exc:  # pragma: no cover - network/auth defensive
        return None, None, f"ISAPI snapshot failed: {exc}"
    if not jpeg:
        return None, None, "ISAPI snapshot returned no data"
    try:
        image = Image.open(io.BytesIO(jpeg))
        image.load()
        resolution = [int(image.size[0]), int(image.size[1])]
    except Exception as exc:  # pragma: no cover - defensive
        return None, None, f"ISAPI JPEG decode failed: {exc}"
    return jpeg, resolution, ""


class RtspChannelWorker(threading.Thread):
    def __init__(
        self,
        *,
        state: ChannelState,
        rtsp_url: str,
        snapshot_url: Optional[str],
        snapshot_username: str,
        snapshot_password: str,
        stop_event: threading.Event,
        reconnect_delay_seconds: float = 5.0,
        publish_interval_seconds: float = 0.25,
        startup_stabilization_seconds: float = 15.0,
        stale_frame_seconds: float = 5.0,
        fallback_snapshot_delay_seconds: float = 15.0,
    ) -> None:
        super().__init__(daemon=True, name=f"rtsp-channel-{state.channel_id}")
        self._state = state
        self._rtsp_url = rtsp_url
        self._snapshot_url = snapshot_url
        self._snapshot_username = snapshot_username
        self._snapshot_password = snapshot_password
        self._stop_event = stop_event
        self._reconnect_delay_seconds = reconnect_delay_seconds
        self._publish_interval_seconds = publish_interval_seconds
        self._startup_stabilization_seconds = startup_stabilization_seconds
        self._stale_frame_seconds = stale_frame_seconds
        self._fallback_snapshot_delay_seconds = fallback_snapshot_delay_seconds

    def _open_capture(self) -> cv2.VideoCapture:
        # Persistent readers perform best when we prefer TCP and discard corrupt
        # startup packets instead of tearing the session down on first decode errors.
        os.environ.setdefault(
            "OPENCV_FFMPEG_CAPTURE_OPTIONS",
            "rtsp_transport;tcp|fflags;discardcorrupt|max_delay;500000",
        )
        capture = cv2.VideoCapture(self._rtsp_url, cv2.CAP_FFMPEG)
        if hasattr(cv2, "CAP_PROP_BUFFERSIZE"):
            capture.set(cv2.CAP_PROP_BUFFERSIZE, 1)
        return capture

    def _publish_frame(
        self,
        frame,
        *,
        source: str,
        now: float,
    ) -> tuple[bool, Optional[list[int]], str]:
        ok, encoded = cv2.imencode(
            ".jpg",
            frame,
            [int(cv2.IMWRITE_JPEG_QUALITY), 90],
        )
        if not ok:
            return False, None, "JPEG encode failed"
        resolution = [int(frame.shape[1]), int(frame.shape[0])]
        jpeg = encoded.tobytes()
        first_frame_logged = False
        first_hd_frame_logged = False
        with self._state.lock:
            self._state.latest_jpeg = jpeg
            self._state.latest_resolution = resolution
            self._state.latest_frame_at_epoch = now
            self._state.connected = True
            self._state.error = ""
            self._state.source = source
            if not self._state.first_frame_logged:
                self._state.first_frame_logged = True
                first_frame_logged = True
            if (
                resolution[0] >= 1280
                and resolution[1] >= 720
                and not self._state.first_hd_frame_logged
            ):
                self._state.first_hd_frame_logged = True
                first_hd_frame_logged = True
        if first_frame_logged:
            print(
                f"[ONYX] First clean frame buffered for CH{self._state.channel_id} "
                f"at {resolution[0]}x{resolution[1]} via {source}."
            )
        if first_hd_frame_logged:
            print(
                f"[ONYX] First clean HD frame buffered for CH{self._state.channel_id} "
                f"at {resolution[0]}x{resolution[1]}."
            )
        self._warn_if_low_resolution(now)
        return True, resolution, ""

    def _mark_reader_state(self, *, now: float, error: str) -> None:
        with self._state.lock:
            has_frame = self._state.latest_frame_at_epoch is not None
            if not has_frame and (now - self._state.started_at_epoch) < 30:
                self._state.connected = False
                self._state.error = "warming_up"
                self._state.source = "warming_up"
                return
            self._state.connected = False
            self._state.error = error
            if not has_frame:
                self._state.source = "unavailable"
        self._warn_if_low_resolution(now)

    def _warn_if_low_resolution(self, now: float) -> None:
        with self._state.lock:
            if self._state.low_resolution_warned:
                return
            age_seconds = now - self._state.started_at_epoch
            resolution = list(self._state.latest_resolution or [])
            source = self._state.source
        if age_seconds < 30:
            return
        if len(resolution) == 2 and resolution[0] >= 1280 and resolution[1] >= 720:
            return
        if len(resolution) == 2:
            detail = f"{resolution[0]}x{resolution[1]} via {source}"
        else:
            detail = "no clean frame buffered"
        with self._state.lock:
            if self._state.low_resolution_warned:
                return
            self._state.low_resolution_warned = True
        print(
            f"[ONYX] RTSP warning for CH{self._state.channel_id}: "
            f"resolution still below 1280x720 after 30 seconds ({detail}).",
            file=sys.stderr,
        )

    def _refresh_snapshot_fallback(self, now: float) -> bool:
        if (
            not self._snapshot_url
            or not self._snapshot_username
            or not self._snapshot_password
        ):
            return False
        snapshot_jpeg, snapshot_resolution, snapshot_error = _capture_isapi_snapshot_once(
            self._snapshot_url,
            username=self._snapshot_username,
            password=self._snapshot_password,
        )
        if snapshot_jpeg is None or snapshot_resolution is None:
            self._mark_reader_state(
                now=now,
                error=snapshot_error or "ISAPI snapshot fallback failed",
            )
            return False
        with self._state.lock:
            self._state.latest_jpeg = snapshot_jpeg
            self._state.latest_resolution = snapshot_resolution
            self._state.latest_frame_at_epoch = now
            self._state.connected = True
            self._state.error = ""
            self._state.source = "isapi_snapshot"
            if not self._state.first_frame_logged:
                self._state.first_frame_logged = True
                print(
                    f"[ONYX] First clean frame buffered for CH{self._state.channel_id} "
                    f"at {snapshot_resolution[0]}x{snapshot_resolution[1]} via isapi_snapshot."
                )
        self._warn_if_low_resolution(now)
        return True

    def run(self) -> None:
        while not self._stop_event.is_set():
            capture = self._open_capture()
            opened_at = time.time()
            last_publish_at = 0.0
            last_snapshot_at = 0.0
            last_good_frame_at: Optional[float] = None
            if not capture.isOpened():
                self._mark_reader_state(
                    now=opened_at,
                    error="RTSP open failed",
                )
                capture.release()
                time.sleep(self._reconnect_delay_seconds)
                continue

            while not self._stop_event.is_set():
                now = time.time()
                frame = None
                grabbed = capture.grab()
                if grabbed:
                    ok, candidate = capture.retrieve()
                    if ok and candidate is not None and getattr(candidate, "size", 0) > 0:
                        frame = candidate
                        last_good_frame_at = now

                if frame is not None and (now - last_publish_at) >= self._publish_interval_seconds:
                    published, _, error = self._publish_frame(
                        frame,
                        source="rtsp",
                        now=now,
                    )
                    if published:
                        last_publish_at = now
                    else:
                        self._mark_reader_state(
                            now=now,
                            error=error or "JPEG encode failed",
                        )

                if last_good_frame_at is None:
                    if (now - opened_at) < self._startup_stabilization_seconds:
                        self._warn_if_low_resolution(now)
                        time.sleep(0.02)
                        continue
                    fallback_succeeded = False
                    if (
                        self._snapshot_url
                        and (now - last_snapshot_at) >= self._fallback_snapshot_delay_seconds
                    ):
                        if self._refresh_snapshot_fallback(now):
                            last_snapshot_at = now
                            fallback_succeeded = True
                    if fallback_succeeded:
                        break
                    self._mark_reader_state(
                        now=now,
                        error="RTSP startup never produced a clean frame",
                    )
                    break

                if (now - last_good_frame_at) < self._stale_frame_seconds:
                    self._warn_if_low_resolution(now)
                    time.sleep(0.02)
                    continue

                if (
                    self._snapshot_url
                    and (now - last_snapshot_at) >= self._fallback_snapshot_delay_seconds
                ):
                    if self._refresh_snapshot_fallback(now):
                        last_snapshot_at = now
                        break
                self._mark_reader_state(
                    now=now,
                    error="RTSP stream stalled",
                )
                break

            capture.release()
            if self._stop_event.wait(self._reconnect_delay_seconds):
                return


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
        try:
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
            return

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
        try:
            self.wfile.write(jpeg)
        except (BrokenPipeError, ConnectionResetError):
            return


class RtspFrameServer:
    def __init__(
        self,
        *,
        host: str,
        port: int,
        channel_states: Dict[int, ChannelState],
        rtsp_urls: Dict[int, str],
        snapshot_urls: Dict[int, Optional[str]],
        snapshot_username: str,
        snapshot_password: str,
        stop_event: threading.Event,
    ) -> None:
        self.host = host
        self.port = port
        self.channel_states = channel_states
        self.rtsp_urls = rtsp_urls
        self.snapshot_urls = snapshot_urls
        self.snapshot_username = snapshot_username
        self.snapshot_password = snapshot_password
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
                source = state.source
            if latest_at is not None:
                ready = True
            channels[str(channel_id)] = {
                "connected": connected,
                "latest_frame_at_epoch": latest_at,
                "latest_resolution": latest_resolution,
                "error": error,
                "source": source,
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
                snapshot_url=self.snapshot_urls.get(channel_id),
                snapshot_username=self.snapshot_username,
                snapshot_password=self.snapshot_password,
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
    snapshot_urls = {
        channel_id: f"http://{nvr_host}/ISAPI/Streaming/channels/{channel_id}01/picture"
        for channel_id in channel_ids
    }

    server = RtspFrameServer(
        host=args.host,
        port=args.port,
        channel_states=channel_states,
        rtsp_urls=rtsp_urls,
        snapshot_urls=snapshot_urls,
        snapshot_username=nvr_user,
        snapshot_password=nvr_password,
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
