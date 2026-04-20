# Enhancement Tier — YOLO / FR / LPR

ONYX runs on a two-tier model.

- **Always-on core (Pi 4B @ MS Vallée):** the DVR proxy, the camera worker,
  and the RTSP frame server. These do the non-negotiable work — ingest
  motion from the Hikvision DVR, dispatch alerts to Telegram with the raw
  snapshot, and post everything to the ledger. They must keep running
  whether or not anything else is available.

- **Enhancement tier (anywhere):** an optional HTTP service that adds
  YOLO object detection, face recognition, license-plate reading, weapon
  detection, and track IDs on top of the core alerts. When it's
  reachable and fast, the camera worker calls into it and enriches the
  alert. When it's not, the worker falls through to raw-snapshot
  delivery and the core pipeline is unaffected.

The enhancement tier is an **additive nicety**, not a dependency.

---

## Why the split

Pi 4B CPU can't run real-time YOLO. A yolov8s predict at imgsz=640 takes
30–120 seconds per 1280×720 frame with no accelerator — worse than the
3-second budget the camera worker now enforces. The DVR already
classifies events as "human" reliably; YOLO's role was always to reduce
false positives and enrich captions, not to be the primary classifier.

Mac (Apple Silicon MPS) and future Hetzner / Pi 5 can run yolo11l at
under a second per frame, so running enhancement *off* the Pi is where
the architecture naturally lands.

---

## Running enhancement on a Mac

**First-time setup** (~5–10 min on a cold cache):

```bash
scripts/mac_enhancement_setup.sh
```

This creates `.venv-mac-enhancement/`, installs PyTorch with MPS,
ultralytics, face_recognition, easyocr, and the `lap` tracker solver
(which works fine on Apple Silicon; it's only broken on the Pi's ARM64
build). Downloads `yolo11l.pt` into `models/`. Re-run safely if
something in the stack changes.

**Boot the enhancement server** (run this whenever you're on Vallée
WiFi and want enriched alerts):

```bash
scripts/mac_enhancement_start.sh
```

Output shows your Mac's LAN IP and the env var to set on the Pi.
`Ctrl-C` to stop cleanly. When the server is running, anything on
`192.168.0.0/24` can POST to `http://<mac-ip>:11636/detect`.

**Point the Pi camera worker at the Mac.** Edit
`/opt/onyx/config/onyx.local.json` on the Pi and set the endpoint:

```json
"ONYX_MONITORING_YOLO_ENDPOINT": "http://192.168.0.7:11636/detect"
```

Then restart the worker:

```bash
scripts/deploy_to_pi.sh --target=camera-worker
```

The worker's startup log confirms the endpoint:

```
[ONYX] Enhancement tier endpoint: http://192.168.0.7:11636/detect (timeout 3000ms)
```

---

## What you see with enhancement on vs. off

**On (Mac reachable, responses < 3s):**
- Alert Telegram message includes inferred object labels, confidences,
  and bounding box summaries.
- Face matches fire when a known person is in-frame (enrollment gallery
  driven by the FR module's config).
- License plate reads attach to vehicle events.
- Track IDs persist across frames for the same camera, so multi-frame
  events correlate.

**Off (Mac unreachable, timeout fires, 500, etc.):**
- Alert Telegram message is the DVR's classification (e.g. "Human
  detected at Zone 3") with the raw snapshot attached.
- No bounding boxes, no face matches, no plate reads, no track IDs.
- Synthetic confidence 0.99 on the worker side so the alert still
  passes the downstream confidence gate (commit `85ca876`).

The camera worker decides per-request: a timeout on enhancement never
blocks the alert pipeline. Worst-case extra latency is the configured
timeout (default 3s) before raw-snapshot fallback runs.

---

## Configuration reference

Set these in `/opt/onyx/config/onyx.local.json` on the Pi to control
how the camera worker talks to the enhancement tier:

| Key | Default | Notes |
|---|---|---|
| `ONYX_MONITORING_YOLO_ENDPOINT` | `http://127.0.0.1:11636/detect` | Any URL. LAN Mac while developing, Hetzner later. |
| `ONYX_MONITORING_YOLO_REQUEST_TIMEOUT_MS` | `3000` | Per-request timeout in ms. 3s is right for LAN + internet. |
| `ONYX_MONITORING_YOLO_AUTH_TOKEN` | _(empty)_ | Bearer token if the enhancement server is token-guarded. |

Set these in `config/onyx.mac_enhancement.json` for the enhancement
service itself:

| Key | Default | Notes |
|---|---|---|
| `ONYX_MONITORING_YOLO_HOST` | `0.0.0.0` | Bind all interfaces so the Pi can reach it. |
| `ONYX_MONITORING_YOLO_PORT` | `11636` | Match the Pi-side endpoint. |
| `ONYX_MONITORING_YOLO_MODEL` | `models/yolo11l.pt` | yolo11l for Mac; Pi would have used yolov8s. |
| `ONYX_MONITORING_YOLO_DEVICE` | `mps` | Apple Silicon GPU. Use `cuda` on Hetzner, `cpu` as fallback. |
| `ONYX_MONITORING_YOLO_TRACKING_ENABLED` | `true` | ByteTrack via lap — works on x86_64/Apple Silicon, broken on Pi ARM64. |
| `ONYX_MONITORING_FR_ENABLED` | `true` | Face recognition. |
| `ONYX_MONITORING_LPR_ENABLED` | `true` | License plate reading. |

---

## Future home: Hetzner (or Pi 5 with NPU)

Same `monitoring_yolo_detector_service.py` runs on Hetzner without
code changes — only the host, port, model, and `DEVICE` config values
differ. The Pi-side config just points at the Hetzner URL with a
Bearer token. Multi-site deployments share the same enhancement
server; each site's camera worker calls into it independently.

Today the service is single-tenant — cross-site auth, rate-limiting,
and tenant isolation are open follow-up items. The HTTP shape and the
per-source concurrency model (one lock per camera channel, 30s
watchdog around each inference) are already in place from today's
work.
