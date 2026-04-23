#!/usr/bin/env python3
"""Local CORS-friendly proxy for ONYX DVR alert streams."""

from __future__ import annotations

import argparse
import collections
import json
import re
import socket
import socketserver
import sys
import threading
import urllib.error
import urllib.request
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import time

_ALERT_PATTERN = re.compile(
    r"<EventNotificationAlert\b[^>]*>[\s\S]*?</EventNotificationAlert>",
)
_UPSTREAM_READ_SIZE = 512
_RECENT_ALERT_MAX_COUNT = 24


class _ProxyConfig:
    def __init__(
        self,
        *,
        upstream_url: str,
        username: str,
        password: str,
    ) -> None:
        self.upstream_url = upstream_url.strip()
        self.username = username.strip()
        self.password = password


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Expose a CORS-friendly local proxy for the configured DVR alert stream.",
    )
    parser.add_argument(
        "--config",
        default="config/onyx.local.json",
        help="Path to the ONYX dart-define JSON config.",
    )
    parser.add_argument(
        "--host",
        default="127.0.0.1",
        help="Interface to bind.",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=9081,
        help="Port to bind.",
    )
    parser.add_argument(
        "--upstream-url",
        default="",
        help="Override the DVR upstream URL instead of reading config.",
    )
    parser.add_argument(
        "--username",
        default="",
        help="Override DVR username instead of reading config.",
    )
    parser.add_argument(
        "--password",
        default="",
        help="Override DVR password instead of reading config.",
    )
    return parser.parse_args()


def _load_proxy_config(args: argparse.Namespace) -> _ProxyConfig:
    if args.upstream_url.strip():
        return _ProxyConfig(
            upstream_url=args.upstream_url,
            username=args.username,
            password=args.password,
        )

    config_path = Path(args.config)
    if not config_path.exists():
        raise FileNotFoundError(f"Missing config: {config_path}")
    config = json.loads(config_path.read_text(encoding="utf-8"))
    upstream_url = str(config.get("ONYX_DVR_PROXY_UPSTREAM_URL", "")).strip()
    username = str(config.get("ONYX_DVR_PROXY_UPSTREAM_USERNAME", "")).strip()
    password = str(config.get("ONYX_DVR_PROXY_UPSTREAM_PASSWORD", ""))
    raw_scopes = config.get("ONYX_DVR_SCOPE_CONFIGS_JSON", "")
    scopes = json.loads(raw_scopes) if raw_scopes else []
    if not upstream_url:
        if not scopes:
            raise RuntimeError(
                "Missing DVR upstream configuration. Set ONYX_DVR_PROXY_UPSTREAM_URL "
                "or provide a non-empty ONYX_DVR_SCOPE_CONFIGS_JSON scope."
            )
        scope = scopes[0]
        upstream_url = str(scope.get("events_url", "")).strip()
        username = username or str(scope.get("username", "")).strip()
        password = password or str(scope.get("password", ""))
    if not upstream_url:
        raise RuntimeError("Configured DVR events_url is empty.")
    return _ProxyConfig(
        upstream_url=upstream_url,
        username=username,
        password=password,
    )


def _build_upstream_opener(config: _ProxyConfig) -> urllib.request.OpenerDirector:
    password_manager = urllib.request.HTTPPasswordMgrWithDefaultRealm()
    upstream_parts = urllib.parse.urlsplit(config.upstream_url)
    origin = urllib.parse.urlunsplit(
        (upstream_parts.scheme, upstream_parts.netloc, "", "", ""),
    )
    uris = {
        config.upstream_url,
        origin,
        f"{origin}/",
    }
    for uri in uris:
        password_manager.add_password(
            realm=None,
            uri=uri,
            user=config.username,
            passwd=config.password,
        )
    auth_handler = urllib.request.HTTPDigestAuthHandler(password_manager)
    return urllib.request.build_opener(auth_handler)


class _ProxyHandler(BaseHTTPRequestHandler):
    server_version = "OnyxDvrCorsProxy/1.0"

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self._write_cors_headers()
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Accept")
        self.end_headers()

    def do_GET(self) -> None:
        if self.path.split("?", 1)[0] != "/alertStream":
            self._proxy_passthrough(method="GET")
            return
        try:
            body = self.server.render_recent_alert_stream()
            self.send_response(200)
            self._write_cors_headers()
            self.send_header(
                "Content-Type",
                'multipart/x-mixed-replace; boundary="boundary"',
            )
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            if body:
                self.wfile.write(body)
                self.wfile.flush()
        except (urllib.error.URLError, socket.timeout, TimeoutError) as error:
            self.send_response(502)
            self._write_cors_headers()
            self.end_headers()
            self.wfile.write(
                f"Upstream DVR fetch failed: {error}".encode(
                    "utf-8",
                    errors="replace",
                ),
            )

    def do_HEAD(self) -> None:
        if self.path.split("?", 1)[0] == "/alertStream":
            self.send_response(200)
            self._write_cors_headers()
            self.send_header(
                "Content-Type",
                'multipart/x-mixed-replace; boundary="boundary"',
            )
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            return
        self._proxy_passthrough(method="HEAD")

    def log_message(self, format: str, *args: object) -> None:
        sys.stdout.write(
            "%s - - [%s] %s\n"
            % (self.address_string(), self.log_date_time_string(), format % args)
        )

    def _write_cors_headers(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Credentials", "false")

    def _proxy_passthrough(self, *, method: str) -> None:
        upstream_url = self.server.build_upstream_passthrough_url(self.path)
        request = urllib.request.Request(
            upstream_url,
            method=method,
            headers={
                "Accept": "*/*",
            },
        )
        try:
            with self.server.upstream_opener.open(request, timeout=15) as response:
                self.send_response(response.status)
                self._write_cors_headers()
                for header, value in response.headers.items():
                    if header.lower() in {
                        "connection",
                        "keep-alive",
                        "proxy-authenticate",
                        "proxy-authorization",
                        "te",
                        "trailers",
                        "transfer-encoding",
                        "upgrade",
                        "access-control-allow-origin",
                        "access-control-allow-credentials",
                    }:
                        continue
                    self.send_header(header, value)
                self.end_headers()
                if method != "HEAD":
                    while True:
                        chunk = response.read(8192)
                        if not chunk:
                            break
                        self.wfile.write(chunk)
                    self.wfile.flush()
        except urllib.error.HTTPError as error:
            self.send_response(error.code)
            self._write_cors_headers()
            self.end_headers()
        except (urllib.error.URLError, socket.timeout, TimeoutError) as error:
            self.send_response(502)
            self._write_cors_headers()
            self.end_headers()
            self.wfile.write(
                f"Upstream DVR passthrough failed: {error}".encode(
                    "utf-8",
                    errors="replace",
                ),
            )


class _ThreadedProxyServer(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True

    def __init__(
        self,
        server_address: tuple[str, int],
        handler_class: type[BaseHTTPRequestHandler],
        *,
        proxy_config: _ProxyConfig,
    ) -> None:
        super().__init__(server_address, handler_class)
        self.proxy_config = proxy_config
        self.upstream_opener = _build_upstream_opener(proxy_config)
        self.recent_alerts = collections.deque()
        self.recent_alert_window_seconds = 90
        self.recent_alert_max_count = _RECENT_ALERT_MAX_COUNT
        self._buffer_lock = threading.Lock()
        self._upstream_thread = threading.Thread(
            target=self._consume_upstream_forever,
            name="onyx-dvr-upstream-buffer",
            daemon=True,
        )
        self._upstream_thread.start()

    def build_upstream_passthrough_url(self, request_path: str) -> str:
        base = urllib.parse.urlsplit(self.proxy_config.upstream_url)
        requested = urllib.parse.urlsplit(request_path)
        path = requested.path or "/"
        query = requested.query
        return urllib.parse.urlunsplit(
            (base.scheme, base.netloc, path, query, ""),
        )

    def _consume_upstream_forever(self) -> None:
        while True:
            request = urllib.request.Request(
                self.proxy_config.upstream_url,
                headers={
                    "Accept": "multipart/x-mixed-replace, application/xml, text/xml",
                },
            )
            try:
                with self.upstream_opener.open(request, timeout=30) as response:
                    buffer = ""
                    while True:
                        chunk = response.read(_UPSTREAM_READ_SIZE)
                        if not chunk:
                            break
                        buffer += chunk.decode("utf-8", errors="replace")
                        matches = list(
                            _ALERT_PATTERN.finditer(buffer)
                        )
                        if not matches:
                            continue
                        last_end = 0
                        for match in matches:
                            payload = match.group(0).strip()
                            if payload:
                                self._store_alert(payload)
                            last_end = match.end()
                        if last_end > 0:
                            buffer = buffer[last_end:]
            except Exception as error:
                sys.stdout.write(f"Upstream DVR buffer reconnecting after error: {error}\n")
                sys.stdout.flush()
                time.sleep(1.0)

    def _store_alert(self, payload: str) -> None:
        now = time.time()
        with self._buffer_lock:
            self.recent_alerts.append((now, payload))
            dropped_count = self._prune_recent_alerts_locked(now)
            buffered_count = len(self.recent_alerts)
        sys.stdout.write(
            "ONYX DVR proxy buffered alert"
            f" • buffered={buffered_count}"
            f" • dropped={dropped_count}"
            f" • preview={_single_line_preview(payload)}\n"
        )
        sys.stdout.flush()

    def _prune_recent_alerts_locked(self, now: float) -> int:
        dropped_count = 0
        while self.recent_alerts and now - self.recent_alerts[0][0] > self.recent_alert_window_seconds:
            self.recent_alerts.popleft()
            dropped_count += 1
        while len(self.recent_alerts) > self.recent_alert_max_count:
            self.recent_alerts.popleft()
            dropped_count += 1
        return dropped_count

    def render_recent_alert_stream(self) -> bytes:
        now = time.time()
        with self._buffer_lock:
            self._prune_recent_alerts_locked(now)
            payloads = [payload for _, payload in self.recent_alerts]
        chunks = []
        for payload in payloads:
            encoded = payload.encode("utf-8")
            chunks.append(
                b"--boundary\r\n"
                + b'Content-Type: application/xml; charset="UTF-8"\r\n'
                + f"Content-Length: {len(encoded)}\r\n\r\n".encode("utf-8")
                + encoded
                + b"\r\n"
            )
        if chunks:
            chunks.append(b"--boundary--\r\n")
        sys.stdout.write(
            "ONYX DVR proxy served alert buffer"
            f" • alerts={len(payloads)}"
            f" • bytes={sum(len(payload.encode('utf-8')) for payload in payloads)}\n"
        )
        sys.stdout.flush()
        return b"".join(chunks)


def _single_line_preview(payload: str, *, limit: int = 140) -> str:
    flattened = " ".join(payload.split())
    if len(flattened) <= limit:
        return flattened
    return f"{flattened[: limit - 1]}…"


def main() -> int:
    args = _parse_args()
    try:
        proxy_config = _load_proxy_config(args)
    except Exception as error:
        print(f"Failed to load DVR proxy config: {error}", file=sys.stderr)
        return 1

    server = _ThreadedProxyServer(
        (args.host, args.port),
        _ProxyHandler,
        proxy_config=proxy_config,
    )
    print(
        f"ONYX DVR CORS proxy listening on http://{args.host}:{args.port}/alertStream"
    )
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
