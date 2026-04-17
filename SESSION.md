# ONYX Platform — Session State
> Human-authored session context. Read this at the start of every session. Last-commit state is in SESSION_STATE.md.

## Project
- **Repo:** /Users/zaks/omnix_dashboard
- **Stack:** Flutter Web · Supabase v2+ · Ollama · OpenAI
- **Theme:** Dark mode · Accent #9D4BFF · OnyxTheme
- **Router:** go_router — /dashboard /operations /clients /guards /intelligence /hr /settings /help
- **Rules:** Full file replacements only · Extend not rewrite · supabase_flutter v2+ only

## Last session
> Auto-generated — see `SESSION_STATE.md` (gitignored, updated by post-commit hook).

## Completed today (2026-04-10)
- [x] YOLO in pipeline — false positive filter active (0814e25)
- [x] Camera worker watchdog + Telegram alert on disconnect (35c0920)
- [x] Camera worker keepalive — TCP nodelay + 60s heartbeat (9038560)
- [x] Proactive alert engine — configurable windows, suspicious movement (6fa0217)
- [x] Expected visitor suppression — cleaner/staff schedules (253571a)
- [x] Universal site intelligence profiles — all industry types (b447367)
- [x] Guard patrol system — QR checkpoints, compliance reports (9f409e4)
- [x] FR person registry — private by architecture, client+AI only (019a508)
- [x] FR enrollment tool — enroll_person.py (019a508)
- [x] Client onboarding wizard — onboard_new_site.py (2a66a8c)
- [x] Status API live — api.onyxsecurity.co.za/v1/status (0a252bb)
- [x] Siri shortcut working — voice status via iPhone
- [x] Zone mapping — all 16 MS Valee channels mapped (f428044)
- [x] FR enrollment — all 5 people (Zaks, Shaheda, Muhammed Saeed, Fatima, Jonathan)
- [x] Live FR pipeline wired (f5a5e5b, 0bab897)
- [x] Vehicle registry — 4 cars, driver assigned
- [x] Vehicle presence + manual confirmation
- [x] On-demand visitor system (Jonathan)
- [x] Real names throughout
- [x] Combined "who is on site" response
- [x] RTSP frame server hardening — URL encoding, warmup, reconnect logic (1c81b93)
- [x] FR pipeline — RTSP frames, direct FR fallback, no silent drops (14b7b7f)
- [x] LPR from HD RTSP frames — detector-side OCR crop improvements (505e507)
- [x] Channel 0 filter in status output and worker summaries (e091e57)
- [x] Server-side Telegram AI processor + Dockerfile scaffold (e091e57)
- [x] RTSP frame server — warmup, URL encoding, background frame buffer (712c354)
- [x] FR at 1280x720 from RTSP — HD frame path active in worker + detector (a771b66)
- [x] LPR at 1280x720 — extra HD crop regions added, garage frame tested (e895c66)
- [x] Ghost CH0 filtered at ingest/persistence/proactive paths (58e8deb)
- [x] Server-side Telegram AI processor — Hetzner deploy artifacts + CLI bundle path (49a48e1)
- [x] Resident alerts suppressed + animal detections downgraded to log-only (33f84ff)


## Completed (this sprint)
- [x] Command Center grid polish — layout, sizing, icon, border radius (e23e65a, c1ae4c1)
- [x] ai_queue_page — shadow sites rebuild, desktopWorkspace layout, selectedFocusId clear (03a0ce4)
- [x] Local brain upgrade — ONYX system prompt, smart routing matrix (5328538)
- [x] events_page state mutation + DateTime fix, clients_page hardcoded room (638a6b2)
- [x] SESSION.md + post-commit hook + three-model workflow established (43a37cc)
- [x] OnyxStatusBanner + OnyxPageHeader wired across all 13 pages (9748ec6)
- [x] Duplicate OnyxPageHeader titles fixed — test suite restored to green (095bf92)
- [x] JUMP TO QUEUE wired to /ai-queue + _generateReport try/finally (e17122f)
- [x] P0 demo polish — hardcoded data, fake strings, stale dates, HikConnect defaults (4624d76)
- [x] Tactical map P1 — stable FlutterMap key, GlobalKeys to State, DateTime.now() (4e7a831)
- [x] BI demo — exceptionVisits panel, peak hour annotation, pharmacy fixture (a4d805a)
- [x] Telegram assistant P1 — error handling, waterfall fallback, await fix (09e2791)
- [x] Dispatch mock cleanup — gated behind kDebugMode, proper empty states (12a1cd4)
- [x] ONVIF bridge — discovery, streams, snapshots, PTZ, presets via easy_onvif (2054128)
- [x] P1 Route labels — already correct in HEAD, no change needed
- [x] P2 Agent routing — intent-driven default already wired (_resolvePreferredBrainProvider), confirmed
- [x] Dahua camera worker — CGI param API, 8 tests (feat: Dahua...)
- [x] Axis camera worker — VAPIX v3, tests (feat: Axis...)
- [x] Governance badge color — locked to 0xFF60A5FA (resolves P1 audit flag)
- [x] Telegram MS Valee Residence — diagnosed and fixed (RLS, chat ID, boot grace period, stale reports)
- [x] Hikvision ISAPI event stream — live, human detection working on CH5/CH16
- [x] Site awareness service — Hikvision ISAPI stream, snapshot model, Supabase repository
- [x] Site awareness → Telegram pipeline LIVE — humans:7 detected on CH4/CH16, Supabase writing, bot responding with live data (2026-04-09 morning)
- [x] Camera worker CLI — standalone dart process, launch script
- [x] Vendor cameras — Dahua, Axis, Uniview workers implemented
- [x] ONVIF bridge — discovery, streams, snapshots, PTZ, presets
- [x] Telegram AI processor on Hetzner — 24/7 independent
- [x] Webhook routing fixed
- [x] Honest occupancy messaging
- [x] CH0 → CH11 fix
- [x] Stack watchdog + resilient restart
- [x] Supabase reconnect on camera worker
- [x] Persistent RTSP reader (ready for new cameras)
- [x] Double alert dedup
- [x] Visitor context in AI processor

## Blocked on hardware
- [ ] FR — needs new cameras (H.264 standard, not H.264+)
- [ ] LPR — same, waiting for new cameras Monday

## Priority queue (Monday)
- P0: Install new 2MP cameras — Main Gate, Back Kitchen, Interior Passage, Garage
- P1: Test RTSP at proper resolution
- P2: FR live test
- P3: LPR live test
- P4: Olarm device installation

## Next hardware to acquire
- Olarm communicator for IDS panel (~R600-800)
- Discuss with technician re: alarm panel activation

## Blocked / needs decision
- [ ] dispatch_performance_projection.dart — per-contract value, waiting on contract model

## Audit reports
- Latest: /claude_review/ — check most recent file
- Hygiene audit: audit_demo_hygiene_2026-04-07.md

## Key files
- Brain service: lib/application/onyx_agent_cloud_boost_service.dart
- Routing: lib/domain/authority/onyx_route.dart
- Theme: lib/ui/onyx_surface.dart (OnyxPageHeader lives here)
- Status banner: lib/ui/components/onyx_status_banner.dart
- AI queue: lib/ui/ai_queue_page.dart

## Health check — 2026-04-08
- dart analyze: 0 errors · 0 warnings · 0 hints
- Test suite: 2935 passed · 0 failed (was 2926 at session start, +9 today)
- Commits today: 15
- Remaining TODOs in lib/: 4 (all pre-existing, scoped vendor/model items)
- Unguarded mock data in UI layer: 0

## Zara Theatre smoke
- Launch command:
```bash
flutter run -d chrome -t lib/smoke/zara_theatre_smoke.dart --dart-define-from-file=config/onyx.smoke.local.json --web-port 7410
```
- Cleanup command:
```bash
dart run scripts/clean_zara_smoke.dart --config config/onyx.smoke.local.json
```
- This smoke harness renders Zara Theatre inside the real AppShell chrome, signs into Supabase anonymously for authenticated RLS, and persists a reusable alarmTriage scenario under sentinel IDs like `SCENARIO-SMOKE-*`. On refresh, it reuses the newest smoke scenario instead of creating duplicates; run the cleanup script when you want a fresh seed. During the loop, Zara writes to `zara_scenarios` and `zara_action_log` in live Supabase, but outbound client messaging and dispatch side effects are stubbed so nothing operational is sent to a real site.

## Model roles
- Claude (claude.ai): spec · decisions · verification · SESSION.md authoring
- Codex: queue execution · bulk edits · commits · SESSION.md update
- Claude Code: surgical fixes · grep checks · audit reads

## Session startup checklist
1. Read this file
2. Check git log -3 for recent commits
3. Check /claude_review/ for latest audit report
4. Confirm current priority from queue above
5. Report status in one line before starting work

## Standing items — 2026-04-17 night

**Active-sweep gap (NEW, critical for productization)**
Camera-worker is event-driven only. It calls YOLO when Hikvision DVR
pushes a motion event via /alertStream. It does NOT actively pull frames
from the RTSP frame server on a schedule. Confirmed by walk-past test:
5 cameras walked, zero detections in the worker log, while direct YOLO
probe of the same channels showed vehicles/motion with 76% confidence.

This is a design gap, not a bug. Hikvision motion triggers are
conservative and sometimes miss obvious activity. Without active-sweep,
the heartbeat "perimeter: clear, humans:0" is a lagging indicator of
DVR triggers, not a live read.

Decision needed:
- Sweep frequency (N seconds)
- Replace event-driven or supplement it
- Where sweep runs (cloud worker vs Pi edge-compute)
- Aggregator and suppression integration

Likely best addressed as part of the Pi/edge-compute deployment session.

**RTSP frame server — not broken**
Previously suspected broken due to 6-day-old JPGs in tmp/onyx_rtsp_frames/.
Investigation revealed disk persistence was removed by design in commit
8091999 (2026-04-11). Current architecture is in-memory HTTP server on
port 11638. Proven working: /health shows 4 channels connected with
live timestamps, /frame/<ch> serves valid JPEGs, YOLO direct probe
against live frames returned vehicle@0.767 on CH12. Orphan JPG files
cleaned up 2026-04-17 night.

**Hetzner state**
- Hetzner `onyx-camera-worker.service` was disabled on 2026-04-17 night.
  Cloud cannot reach 192.168.0.117 without a tunnel, so the service was
  permanently stopped to prevent pointless SYN flood / crash churn.
- Camera-worker is now local-only on the MS-Vallee-Mac until Pi deployment.

**Architecture**
- Pi 4B on order — deploy plan is edge-compute per site, camera-worker at
  residence, Hetzner keeps cloud-facing services only. Next proper session.
- Endpoint contract ambiguity: tonight we aligned worker config to proxy's
  /alertStream. Inverse (proxy accepts full ISAPI path) is cleaner long-term.
  Decide in follow-up.

**Local stack hygiene**
- DVR proxy is now in the `make start` stack.
- `scripts/onyx_watchdog.sh` is restored on disk and the local runtime is back
  on the maintained watchdog path via `ensure_camera_worker.sh`.
- `make status` now reports uptime + respawn heuristics instead of a shallow
  pgrep-only "RUNNING".

**Monitoring**
- No alerting when camera-worker crash-loops, when DVR proxy dies, or when
  Supabase returns 402. 24h of silence before I noticed Telegram was down.
  "N consecutive failed polls = DOWN" alerting would have caught tonight's
  outage in ~15 minutes.

**Design follow-ups (from polish pass 2026-04-17)**
- Reports line 6326 and Ledger line 1156: mixed ID+timestamp strings. Need
  design call on whether to split into two Text widgets (ID mono, prose Inter)
  or full-string mono.
- Reports _partnerScopeChip (8+ call sites): chip API embeds IDs in prose.
  Proper fix is chip refactor with separate prose+ID slots.
- Risk Intelligence page: signal IDs exist in data model but aren't rendered.
  Product decision needed — surface them or not?
- Org Chart amber hue: swapped Color(0xFFFFB830) to OnyxColorTokens.accentAmber
  (F5A623). Visual verification pending — may want to add accentGold token if
  original yellow was intentional.

**Events page**
- Stages 2 (lane tabs replace priority chain) and 3 (temporal rail + mono IDs)
  still pending. Previous session diagnosed and scoped. One session,
  contained to events_review_page.dart.

**Supabase**
- Migration-history drift: 14+ repo migrations not recorded remotely. 3 files
  silently skipped by CLI (filename pattern mismatch). Reconcile in dedicated
  session — not urgent while applying new migrations directly via psql works.

**Product**
- Zara Theatre smoke run: harness ready, migrations live, not yet run because
  of tonight's incidents. Next session when head is fresh. Six evaluation
  questions already drafted.
- Zara action log is live, but the doctrine layer that turns Zara's proposed
  actions into validated controller protocol still needs a design session
  before autonomy expands beyond supervised execution.
