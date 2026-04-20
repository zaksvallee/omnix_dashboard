# ONYX Platform — Phase 2a Backend Capability Verification

**Date:** 2026-04-20
**Scope:** runtime evidence for every capability/service inventoried in phase 1a. Not a code audit — whether the code *runs* and produces *correct* output in the production environment.
**Out of scope:** dashboard features (phase 2b), schema drift (phase 4), incident diagnosis (phase 3a).

---

## 0. Access confirmation and input review

| Target | Method | Result |
|---|---|---|
| `audit/phase_1a_backend_inventory.md` | local read | re-read in full (617 lines), last commit `f216695` on top of `58fa062` |
| `audit/phase_1b_dashboard_parity.md` | local read | referenced only; not primary input (812 lines, commit `d7ad444`) |
| Pi `onyx@192.168.0.67` | ssh | ok — uptime 6d 6h 35m at start of pass |
| Hetzner `root@api.onyxsecurity.co.za` | ssh | ok — uptime 11d 10h 17m |
| Mac local | shell + `ps aux` + log tails | ok — Mac enhancement process alive (pid 29468), started 2026-04-20 21:49 SAST (~8 min of uptime at start of pass) |
| Supabase PostgREST | curl with service-role key from `config/onyx.local.json` | ok — reads + row-counts working |
| Supabase Studio / pg_cron | not accessed | edge-function CRON schedules still `unknown` per phase 1a flag |

**Phase 1a anchor:** `58fa062` + appendix `f216695` on `omnix_dashboard/main`.
**Phase 1b anchor:** `d7ad444` on `omnix_dashboard/main`.
**Current HEAD at start of pass:** `d7ad444`.

**Time windows in use:**
- Default: **2026-04-13 00:00 SAST → 2026-04-20 21:57 SAST** (last 7 days; today is 2026-04-20).
- Low-frequency (expanded to 30 days / 2026-03-21 onwards) for: dispatch workflows, ledger writes, report generation, Telegram callback handlers that gate rare events. Expansion will be stated per-capability when used.

**In-progress stoppage flag (for phase 3a, not diagnosed here):**
The Pi camera worker is, at the time of this pass, in a tight reconnect loop against the Hikvision DVR at `192.168.0.117:80`. The last ~30 entries of `/opt/onyx/tmp/onyx_camera_worker.log` are exclusively:
```
[ONYX] ⚠️ Camera stream disconnected from 192.168.0.117:80 — reconnecting in 5s (attempt 1). Reason: Alert stream closed unexpectedly.. Error: null
```
repeating every ~5s. Total count of `Camera stream disconnected`/`Alert stream closed` entries in the current camera-worker log (since the 17:03:38 SAST restart, ~5h ago): **7,926**. The Apr-20 row in `site_alarm_events` day-by-day count is **7** total alarm events for today — against a 7-day daily mean of 1,535 — consistent with a current stoppage. Noted and continuing.

---

## 1. Inference pipeline verification

### 1.1 YOLO object detection

**What it's supposed to produce (phase 1a §8.2):** object-detection results via HTTP at `127.0.0.1:11636/detect` (Pi) or `0.0.0.0:11636/detect` (Mac enhancement) — JSON response containing detections + per-detection class/confidence, plus `primary` type, `face_match`, `plate`, and latency metadata.

**Evidence query (Pi):**
```
ssh onyx@192.168.0.67 \
  "grep -oE 'elapsed_ms=[0-9]+' /opt/onyx/tmp/onyx_yolo_server.log \
  | sed 's/elapsed_ms=//' | sort -n > /tmp/yolo_ms.txt"
```
Dataset: **103 detect invocations** in `/opt/onyx/tmp/onyx_yolo_server.log` (systemd unit append-mode log; spans from an earlier `yolov8l.pt` configuration through the 2026-04-20 17:03:18 SAST restart with `yolov8s.pt`).

**Evidence result — Pi YOLO latency distribution (7d, n=103):**

| statistic | ms |
|---|---:|
| min | 2,909 |
| p50 | 14,095 |
| p95 | 161,950 |
| p99 | 178,144 |
| max | 213,479 |
| count >30s | 23 (22.3%) |
| count >60s | 19 (18.4%) |

**Sample detect-complete log lines (10 most recent, verbatim):**
```
2026-04-20 12:43:30,666 ... elapsed_ms=13888 object_ms=13808 detections=1 primary=person face_match=no plate=no
2026-04-20 12:50:59,900 ... elapsed_ms=27631 object_ms=27520 detections=0 primary=None face_match=no plate=no
2026-04-20 12:55:44,151 ... elapsed_ms=82014 object_ms=81878 detections=1 primary=person face_match=no plate=no
2026-04-20 12:56:18,834 ... elapsed_ms=86077 object_ms=85882 detections=0 primary=None face_match=no plate=no
2026-04-20 12:58:34,345 ... elapsed_ms=46284 object_ms=36678 detections=0 primary=None face_match=no plate=no
2026-04-20 12:58:56,091 ... elapsed_ms=34484 object_ms=28577 detections=0 primary=None face_match=no plate=no
2026-04-20 13:01:35,201 ... elapsed_ms=117630 object_ms=116454 detections=1 primary=person face_match=no plate=no
2026-04-20 13:19:04,158 ... elapsed_ms=13947  object_ms=4154   detections=0 primary=None face_match=no plate=no
2026-04-20 13:20:34,206 ... elapsed_ms=2909   object_ms=2887   detections=0 primary=None face_match=no plate=no
2026-04-20 13:28:13,104 ... elapsed_ms=18735  object_ms=18704  detections=0 primary=None face_match=no plate=no
```

**Watchdog / BrokenPipe:**
- `ONYX-YOLO-WATCHDOG` log-line count: **248** (= 124 trips × 2 — each trip emits both `print()` and `logger.ERROR()`; confirmed against the companion marker `err=inference watchdog tripped` with **124** matches).
- `BrokenPipeError` occurrences: **3**.
- `Broken pipe` (camera-worker-disconnected-before-response): **4**.
- Oldest in-file: 2026-04-20 12:43. Newest in-file: 2026-04-20 13:31.
- Single oom-kill on `onyx-yolo-detector.service` at **2026-04-20 13:16:50 SAST** (phase 1a §2 already recorded this).

**Outlier correlation:**
- Source breakdown of the 23 outliers (>30s): all carry `source=CLIENT-MS-VALLEE|SITE-MS-VALLEE-RESIDENCE|<ch>` where `<ch>` ∈ {4, 5, 9, 14, 16}. Distribution: `5` dominates (11 of 23), followed by `14` (4), `4` (3), `9` (3), `16` (2).
- Frame size across all 103: all lines state `image=704x576` — no size variance; size is not a correlator.
- Queue depth: `detect_items batch_size=1` on every line — no batching, so depth is not a correlator. Outliers are serial.
- Tracking: `tracking=False imgsz=640 conf=0.35` across all 103 — Pi ByteTrack is disabled (per startup log `tracking disabled — using predict() path (set ONYX_MONITORING_YOLO_TRACKING_ENABLED=true to opt in; known-broken on Pi 4B / aarch64 as of 2026-04-20)` and `config/onyx.local.json` `"ONYX_MONITORING_YOLO_TRACKING_ENABLED": "false"`).

**Per-stage `[ONYX-YOLO-TIMING]` instrumentation (phase 1a mention of commits `370fa10` + `1be22c3`):** the literal marker `[ONYX-YOLO-TIMING]` appears **0 times** in the Pi YOLO log. The per-stage timing columns (`object_ms=...`, `face_ms=`, `plate_ms=`) partially appear on `detect complete` lines but the named commits' full instrumentation is not visible in Pi output. Possible explanations: the commits landed but with a different marker string, or they apply only to the Mac enhancement config. This is **evidence-level acceptable** — the `object_ms=` breakdown is enough to tell total-vs-object-time.

**Mac enhancement YOLO (9 min of uptime):**
- Model `models/yolo11l.pt`, device `mps`, warmup **917 ms** (`2026-04-20 21:52:02,214 INFO onyx.yolo [ONYX-YOLO] model warmup complete in 917 ms`).
- `/detect` POST count since 21:49 start: **0**. Only `GET /health` probes every ~30 seconds (33 lines of the form `127.0.0.1 - - [20/Apr/2026 21:52:45] "GET /health HTTP/1.1" 200 -` in `tmp/onyx_mac_enhancement.log`).
- Tracking is **enabled** (`tracking enabled — using model.track() with bytetrack`).

**Verdict (YOLO object detection):** **verified** — the capability executes and produces detections. 103 completed calls in window on Pi, with detection outputs (`primary=person` seen in log). Latency is outside the 3s enhancement-timeout budget on almost every call (p50 14.1s is ~4.7× budget; p95 162s; 22.3% of calls exceed the 30s watchdog). The *consequence* of this latency (raw-snapshot fallback firing on the camera worker) is covered in §1.6.

Evidence quality: **good** (per-call log lines with timestamps + latency + output).

---

### 1.2 Face recognition (FR)

**What it's supposed to produce (phase 1a §8.3):** face-encoding extraction from detected persons + match against `tool/face_gallery/` using either `face_recognition` (dlib) or OpenCV ONNX `FaceDetectorYN` + `FaceRecognizerSF`, returning `face_match_id` on match. Threshold `ONYX_MONITORING_FR_MATCH_THRESHOLD` (Mac config: `0.37`).

**Configuration audit at time of pass:**

| Node | `ONYX_FR_ENABLED` | `ONYX_MONITORING_FR_ENABLED` | Gallery filesystem | Gallery DB |
|---|---|---|---|---|
| Pi (`/opt/onyx/config/onyx.local.json`) | `"false"` | `"true"` | `/opt/onyx/tool/face_gallery/` — **50** images present (`find -type f -iname "*.jpg" -o -iname "*.png"`), across at minimum `MSVALLEE_RESIDENT_DAD`, `MSVALLEE_RESIDENT_MUM` sub-folders | `fr_person_registry` table has **5** rows (Zaks, Jonathan, Shaheda, + 2 more) each with `photo_count=5, is_enrolled=true, is_active=true` |
| Mac (`config/onyx.mac_enhancement.json`) | `"true"` | `"true"` | `tool/face_gallery/…/SITE-MS-VALLEE-RESIDENCE/MSVALLEE_VISITOR_JONATHAN/*.jpg` etc. — **50** images at depth ≥ 3 | same 5 registry rows |

Per `tool/monitoring_yolo_detector_service.py:60–62` (phase 1a §4) the FR module-load path is **gated by `ONYX_FR_ENABLED`**. Consequence: FR **does not run on the Pi YOLO service** (env says `false`).

**Evidence query (Pi):**
```
grep -cE "face_match=yes" /opt/onyx/tmp/onyx_yolo_server.log
grep -cE "face_match=no"  /opt/onyx/tmp/onyx_yolo_server.log
grep -cE "face_recognition|FaceDetectorYN|FR: HD" /opt/onyx/tmp/onyx_yolo_server.log
```

**Evidence result — FR honest numbers, 7d window:**

| metric | Pi | Mac | total |
|---|---:|---:|---:|
| face detections (pre-matching encodings attempted) | **0** (FR disabled by env) | **0** (0 detect POSTs in 9-min uptime — see §1.5) | **0** |
| face matches (above threshold) | **0** | **0** | **0** |
| match rate (matches/detections) | — (div-by-zero) | — | **— (no denominator)** |
| `face_match=yes` log lines | 0 | 0 | 0 |
| `face_match=no` log lines | 63 (these are the DEFAULT value emitted in the JSON response when FR is disabled; **not** evidence of FR running and finding no match) | 0 | 63 (default, not a match-attempt) |
| Gallery size | 5 people × 5 photos = 25 gallery shots enrolled per DB; 50 image files present on both Pi and Mac filesystems | — | — |
| Model | (not loaded on Pi — FR_ENABLED=false) | `face_recognition` lib (Python) + OpenCV YuNet + SFace ONNX per config | — |
| Threshold | n/a | `0.37` | — |

**Evidence of encodings being extracted:** none in window. Pi grep for `face_recognition` / `FaceDetectorYN_create` / `FaceRecognizerSF_create` / `FR: ` inside `onyx_yolo_server.log` returns zero hits. Mac log does not yet have any detect POSTs to trigger FR.

**Verdict (FR):** **dormant — sub-type split by node:**
- Pi: **`dormant_no_trigger`** — capability is wired (code path exists, lazy import gated on `ONYX_FR_ENABLED`), but the env flag is `"false"` in the Pi config, so the handler never enters. Trigger = flipping the env flag, not a runtime event.
- Mac: **`dormant_no_input`** — capability is wired and enabled; gallery is present; model loaded at warmup; but the Mac enhancement tier only came up at 21:49 tonight (~8 min before this pass started) and has received **0 detect POSTs**. No frames → no FR executions → no matches possible.

**Combined honest number: 0 face matches, 0 face encodings extracted, in the 7-day window.** The 5-person gallery is enrolled in DB and files are on disk on both nodes; the pipeline is not consuming it.

Evidence quality: **good** (config file + DB row counts + log-marker absence + uptime window is all timestamped).

---

### 1.3 LPR (EasyOCR)

**What it's supposed to produce (phase 1a §8.4):** plate-region OCR over detected vehicle bounding boxes, returning plate-string + confidence, persisted. Gate env `ONYX_LPR_ENABLED`; allowlist / regex config in `config/onyx.local.example.json`.

**Configuration audit:**

| Node | `ONYX_LPR_ENABLED` | `ONYX_MONITORING_LPR_ENABLED` | Languages | Min confidence | Regex |
|---|---|---|---|---|---|
| Pi | `"false"` (via `ONYX_LPR_ENABLED` — the **module-load gate**) | `"true"` | `en` | `0.55` | standard allowlist + regex |
| Mac | `"true"` | `"true"` | `en` | `0.55` | same |

Per phase 1a §4 the EasyOCR module load is gated by `ONYX_LPR_ENABLED` (lazy import at `tool/monitoring_yolo_detector_service.py:79,189`). Pi therefore does **not** load EasyOCR.

**Evidence query:**
```
grep -cE "plate=yes" /opt/onyx/tmp/onyx_yolo_server.log
grep -cE "plate=no"  /opt/onyx/tmp/onyx_yolo_server.log
grep -cE "easyocr|LPR.*HD|plate_candidate|plate_string" /opt/onyx/tmp/onyx_yolo_server.log
```

**Evidence result — LPR honest numbers, 7d window:**

| metric | Pi | Mac | total |
|---|---:|---:|---:|
| plate candidate regions detected (pre-OCR) | **0** (EasyOCR module not loaded per `ONYX_LPR_ENABLED=false`; plate-region detection requires vehicle bounding box as input, and the detections observed were `primary=person` or `primary=None` with **no `primary=vehicle` in any of the 103 lines**) | **0** (0 detect POSTs) | **0** |
| successful OCR reads | 0 | 0 | **0** |
| plate strings persisted to DB | 0 (searched `site_alarm_events`, `incidents`, `onyx_evidence_certificates` — no `plate_text`/`plate_string`/`license_plate` columns surfaced in returned rows in window) | 0 | **0** |
| `plate=yes` log lines | 0 | 0 | 0 |
| `plate=no` log lines | 63 (default value in response; not evidence of OCR running) | 0 | 63 |

**Are candidates being detected at all?** Evidence says **no**. The 103 YOLO detect-complete lines show `primary=person` or `primary=None`; there is no `primary=vehicle` or `primary=car` in window. Upstream input for LPR — a vehicle bounding box — is absent. (Note: the Hikvision DVR is still detecting "vehicle" events inside `site_alarm_events` — 11,220 over 7d — but those are DVR-internal VMD classifications that don't flow into the Pi YOLO service while the Pi `ONYX_LPR_ENABLED=false` gates plate-region work out of the module.)

**Verdict (LPR):** **`dormant_no_input`** — module not loaded on Pi (env gate); on Mac it is loaded but has received 0 detect POSTs; even if detect POSTs were flowing, none of the 7-day YOLO detections showed a `primary=vehicle`, so LPR would have no input crop to OCR.

**Total plate strings read in window: 0. Zero.**

Evidence quality: **good** (env flag + log-marker absence + upstream-class distribution all timestamped).

---

### 1.4 ByteTrack (multi-object tracking)

**What it's supposed to produce (phase 1a §8.5):** persistent object IDs across frames via `model.track(..., tracker="bytetrack.yaml", persist=True)`, with `track_ttl_seconds=180` retention.

**Configuration audit:**

| Node | `ONYX_MONITORING_YOLO_TRACKING_ENABLED` | Runtime log line |
|---|---|---|
| Pi | `"false"` | `2026-04-20 17:03:19,225 INFO onyx.yolo [ONYX-YOLO] tracking disabled — using predict() path (set ONYX_MONITORING_YOLO_TRACKING_ENABLED=true to opt in; known-broken on Pi 4B / aarch64 as of 2026-04-20)` |
| Mac | `"true"` | `2026-04-20 21:49:46,862 INFO onyx.yolo [ONYX-YOLO] tracking enabled — using model.track() with bytetrack` |

**Evidence result:**
- Pi: `model.track(...)` never called in window (`tracking=False` on every one of 103 detect lines — the code path that runs is `predict()`, not `track()`).
- Mac: tracking is enabled and announced, but 0 `/detect` POSTs have reached it → 0 track operations executed.
- No `track_id` column in `site_alarm_events`, `incidents`, or `onyx_evidence_certificates` output observed in window. Track persistence has zero visible product in the DB.

**Verdict (ByteTrack):**
- Pi: **`dormant_no_trigger`** — capability disabled by env (documented as "known-broken on Pi 4B / aarch64" in the service's own startup banner).
- Mac: **`dormant_no_input`** — enabled and healthy at startup, but no frames through the pipe in its 9-min uptime.

Total ByteTrack track IDs produced in window: **0**.

Evidence quality: **good**.

---

### 1.5 Pi → Mac enhancement handoff

**What it's supposed to produce (phase 1a §8.7):** HTTP POST of JPEG frame from Pi camera worker to `ONYX_MONITORING_YOLO_ENDPOINT` (Mac at `http://192.168.0.7:11636/detect`) with `ONYX_MONITORING_YOLO_REQUEST_TIMEOUT_MS=3000` timeout; fallback to raw-snapshot Telegram on timeout.

**Configuration audit:**

| Key | Value (Pi) |
|---|---|
| `ONYX_MONITORING_YOLO_ENDPOINT` (in `/opt/onyx/config/onyx.local.json`) | `http://192.168.0.7:11636/detect` |
| `ONYX_MONITORING_YOLO_REQUEST_TIMEOUT_MS` | (defaults to 3000 per phase 1a §8.7 note; not overridden in file) |

**Evidence query (Mac side — only the Mac can tell whether Pi's POSTs actually landed):**
```
wc -l /Users/zaks/omnix_dashboard/tmp/onyx_mac_enhancement.log       # 31
grep -c '"POST /detect'         tmp/onyx_mac_enhancement.log          # 0
grep -c '"GET /health'          tmp/onyx_mac_enhancement.log          # 26
```

Mac uptime window: 2026-04-20 21:49 SAST onwards (~13 min at time of pass). Zero `/detect` POSTs; 26 `/health` pings from what appears to be a local liveness probe on `127.0.0.1` (not from `192.168.0.67`). No Pi-origin requests visible on the Mac.

**Evidence query (Pi side):**
```
grep "YOLO result:" /opt/onyx/tmp/onyx_camera_worker.log | tail -5   # result: null (5/5)
grep "YOLO/FR:" /opt/onyx/tmp/onyx_camera_worker.log | head -1
  # → "[ONYX] YOLO/FR: http://127.0.0.1:11636/detect"
```

The camera worker's startup banner reports `http://127.0.0.1:11636/detect` — the **Pi local YOLO**, not the Mac. This contradicts the `onyx.local.json` config value. The camera-worker process was started 2026-04-20 17:03:38 SAST; the config file was last edited on 2026-04-20 (per phase 1a work). Whether the config change post-dated the worker's last env read is not traced here (phase 3a territory). Runtime behaviour is that POSTs are going to `127.0.0.1:11636` (Pi local), not `192.168.0.7:11636` (Mac).

**Verdict (Pi → Mac enhancement handoff):** **`dormant_pipeline_break`** — config intent is to use Mac, but runtime is using Pi local. Mac has received **0 detect POSTs** in its entire 13-min uptime window. The handoff is not functioning as the config describes.

(Note: **the underlying inference is still occurring** — via Pi local YOLO — so the *downstream* alert emission still works, just without the Mac's faster/better model. See §1.6.)

Evidence quality: **good** (Mac log has zero inbound POSTs + Pi banner shows local endpoint, both timestamped).

---

### 1.6 Raw-snapshot fallback

**What it's supposed to produce (phase 1a §8.6, §8.7):** when YOLO POST times out or returns null, the camera worker emits a raw-snapshot Telegram alert with a **synthetic confidence value of 0.99** rather than blocking on enhancement.

**Evidence query:**
```
grep -c "confidence=0.99" /opt/onyx/tmp/onyx_camera_worker.log
grep -c "YOLO result: null" /opt/onyx/tmp/onyx_camera_worker.log
grep -c "proceeding to send" /opt/onyx/tmp/onyx_camera_worker.log
grep -c "suppressed="      /opt/onyx/tmp/onyx_camera_worker.log
```

Since the 2026-04-20 17:03:38 SAST camera-worker restart (current log):
- Gate-check lines emitted with `confidence=0.99`: **422** (the fallback synthetic value).
- `YOLO result: null` lines: appear on every flushed frame; tail sample shows 5 consecutive nulls.
- `proceeding to send` (actual Telegram dispatch attempts): **81**.
- `suppressed=` (gate logic held back — e.g. "awaiting consecutive human detection"): **160**.

**Sample fallback dispatch lines (verbatim):**
```
[ONYX-TELEGRAM] Gate check: proceeding to send channel=13 alert_id=alesidence13menthhryz6gups snapshot=true
[ONYX-TELEGRAM] Gate check: proceeding to send channel=14 alert_id=alesidence14menthhryzjke0w snapshot=true
[ONYX-TELEGRAM] Gate check: proceeding to send channel=4  alert_id=alesidence4seqhhrz10jyv4  snapshot=true
[ONYX-TELEGRAM] Gate check: proceeding to send channel=16 alert_id=alesidence16menthhsdcmja0w snapshot=true
```

**Verdict (raw-snapshot fallback):** **verified** — capability executes and produces user-visible output (Telegram alerts with `confidence=0.99` synthetic marker + `snapshot=true`). 81 dispatches attempted in ~5h of camera-worker uptime. Alerts carry a correlation `alert_id` (e.g. `alesidence16menthhsdcmja0w`) suitable for cross-referencing against Telegram message IDs (not traced in this pass).

Evidence quality: **good** (gate-check log with timestamp + alert_id + channel + snapshot flag — **best** quality would require a Telegram message-ID trace per alert, which §7 (cross-capability flow verification) will attempt for one sample).

---

### 1.7 Section 1 summary table

| Capability | Verdict | Sub-type | Honest number in 7d window |
|---|---|---|---|
| YOLO object detection | verified | — | 103 calls; p50 14.1s, p95 162s, 23/103 over 30s watchdog |
| Face recognition (Pi) | dormant | `dormant_no_trigger` | 0 matches, 0 encodings (FR_ENABLED=false) |
| Face recognition (Mac) | dormant | `dormant_no_input` | 0 matches (0 detect POSTs in 13-min uptime) |
| LPR (EasyOCR) | dormant | `dormant_no_input` | 0 plate strings persisted (no `primary=vehicle` in upstream detections) |
| ByteTrack (Pi) | dormant | `dormant_no_trigger` | 0 tracks (TRACKING_ENABLED=false, known-broken on Pi 4B per service banner) |
| ByteTrack (Mac) | dormant | `dormant_no_input` | 0 tracks (no detect POSTs) |
| Pi → Mac enhancement handoff | dormant | `dormant_pipeline_break` | 0 POSTs reach Mac; Pi camera worker using `127.0.0.1:11636` per startup banner despite config pointing at `192.168.0.7` |
| Raw-snapshot fallback | verified | — | 81 Telegram dispatch attempts with `confidence=0.99` synthetic in ~5h |

---

*§2 (service health and throughput), §3 (Telegram bot surface), §4 (API endpoints), §5 (external integrations), §6 (data layer), §7 (cross-capability flows) pending — to be committed separately per per-section rule.*
