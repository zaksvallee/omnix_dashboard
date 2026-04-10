# ONYX Platform — Session State
> Auto-updated on every commit. Read this at the start of every session.

## Project
- **Repo:** /Users/zaks/omnix_dashboard
- **Stack:** Flutter Web · Supabase v2+ · Ollama · OpenAI
- **Theme:** Dark mode · Accent #9D4BFF · OnyxTheme
- **Router:** go_router — /dashboard /operations /clients /guards /intelligence /hr /settings /help
- **Rules:** Full file replacements only · Extend not rewrite · supabase_flutter v2+ only

## Last session
- **Date:** 2026-04-11 01:25
- **Last commit:** feat: server-side AI processor + CH0 filter
- **Commit hash:** e091e57

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

## In progress
- [ ] RTSP live validation — confirm frame server returns stable 1280x720 frames on CH12 / CH16
- [ ] Live FR validation — confirm cropped RTSP frames produce real matches during walk tests
- [ ] Live LPR validation — confirm LF05CFGP reads from HD garage frames

## Priority queue (next session)
- P0: Validate RTSP frame server delivers stable HD frames on CH12 / CH16
- P1: Verify live FR walk test from RTSP frames and capture first real match
- P2: Verify HD LPR reads LF05CFGP and other registered plates reliably
- P3: Deploy onyx-telegram-ai-processor to Hetzner systemd
- P4: Alert suppression — enrolled residents no alerts
- P5: Olarm device installation

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
