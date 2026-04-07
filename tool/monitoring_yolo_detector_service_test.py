#!/usr/bin/env python3
import base64
import json
import os
import socket
import subprocess
import sys
import tempfile
import time
import unittest
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SERVICE = ROOT / "tool" / "monitoring_yolo_detector_service.py"


def _free_port() -> int:
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


class MonitoringYoloDetectorServiceContractTest(unittest.TestCase):
    def test_mock_backend_serves_health_and_detect(self) -> None:
        port = _free_port()
        with tempfile.TemporaryDirectory() as temp_dir:
            config_path = Path(temp_dir) / "onyx.local.json"
            config_path.write_text(
                json.dumps(
                    {
                        "ONYX_MONITORING_YOLO_ENABLED": "true",
                        "ONYX_MONITORING_YOLO_HOST": "127.0.0.1",
                        "ONYX_MONITORING_YOLO_PORT": str(port),
                        "ONYX_MONITORING_YOLO_BACKEND": "mock",
                    }
                )
            )
            process = subprocess.Popen(
                [sys.executable, str(SERVICE), "--config", str(config_path)],
                cwd=str(ROOT),
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            try:
                self._wait_for_health(port)
                health = self._get_json(f"http://127.0.0.1:{port}/health")
                self.assertEqual(health["backend"], "mock")
                self.assertTrue(health["ready"])
                self.assertEqual(health["successful_request_count"], 0)
                self.assertIsNone(health["last_request_error"])
                self.assertIn("modules", health)
                options = self._options(f"http://127.0.0.1:{port}/detect")
                self.assertEqual(options["status"], 204)
                self.assertEqual(options["allow_origin"], "*")
                self.assertIn("POST", options["allow_methods"])
                self.assertIn("Content-Type", options["allow_headers"])

                payload = {
                    "items": [
                        {
                            "record_key": "test-record",
                            "headline": "Front gate resident alert with backpack and plate",
                            "summary": "Possible person activity near front gate with backpack and plate.",
                            "object_label": "movement",
                            "image_url": "data:image/jpeg;base64,"
                            + base64.b64encode(b"fake-image").decode("ascii"),
                        }
                    ]
                }
                detect = self._post_json(
                    f"http://127.0.0.1:{port}/detect",
                    payload,
                )
                self.assertEqual(len(detect["results"]), 1)
                self.assertEqual(detect["results"][0]["record_key"], "test-record")
                self.assertEqual(detect["results"][0]["primary_label"], "person")
                self.assertTrue(
                    str(detect["results"][0]["track_id"]).endswith("|track:person-1")
                )
                self.assertEqual(detect["results"][0]["face_match_id"], "RESIDENT-01")
                self.assertEqual(detect["results"][0]["plate_number"], "CA123456")
                self.assertTrue(
                    str(detect["results"][0]["detections"][0]["track_id"]).endswith(
                        "|track:person-1"
                    )
                )
                self.assertEqual(
                    detect["results"][0]["detections"][1]["label"], "backpack"
                )
                health_after = self._get_json(f"http://127.0.0.1:{port}/health")
                self.assertEqual(health_after["successful_request_count"], 1)
                self.assertIsNone(health_after["last_request_error"])
                self.assertIsNotNone(health_after["last_success_at_epoch"])
            finally:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)
                if process.stdout is not None:
                    process.stdout.close()
                if process.stderr is not None:
                    process.stderr.close()

    def _wait_for_health(self, port: int) -> None:
        deadline = time.time() + 8
        health_url = f"http://127.0.0.1:{port}/health"
        while time.time() < deadline:
            try:
                self._get_json(health_url)
                return
            except Exception:
                time.sleep(0.2)
        self.fail(f"Timed out waiting for {health_url}")

    def _get_json(self, url: str):
        with urllib.request.urlopen(url, timeout=4) as response:
            return json.loads(response.read().decode("utf-8"))

    def _post_json(self, url: str, payload):
        request = urllib.request.Request(
            url,
            data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(request, timeout=4) as response:
            return json.loads(response.read().decode("utf-8"))

    def _options(self, url: str):
        request = urllib.request.Request(
            url,
            headers={
                "Origin": "http://localhost:52292",
                "Access-Control-Request-Method": "POST",
                "Access-Control-Request-Headers": "content-type",
                "Access-Control-Request-Private-Network": "true",
            },
            method="OPTIONS",
        )
        with urllib.request.urlopen(request, timeout=4) as response:
            return {
                "status": response.status,
                "allow_origin": response.headers.get("Access-Control-Allow-Origin"),
                "allow_methods": response.headers.get("Access-Control-Allow-Methods", ""),
                "allow_headers": response.headers.get("Access-Control-Allow-Headers", ""),
                "allow_private_network": response.headers.get(
                    "Access-Control-Allow-Private-Network"
                ),
            }


if __name__ == "__main__":
    unittest.main()
