# ONYX Platform — Session State
> Auto-updated on every commit. Read this at the start of every session.

## Project
- **Repo:** /Users/zaks/omnix_dashboard
- **Stack:** Flutter Web · Supabase v2+ · Ollama · OpenAI
- **Theme:** Dark mode · Accent #9D4BFF · OnyxTheme
- **Router:** go_router — /dashboard /operations /clients /guards /intelligence /hr /settings /help
- **Rules:** Full file replacements only · Extend not rewrite · supabase_flutter v2+ only

## Last session
- **Date:** 2026-04-08 23:50
- **Last commit:** chore: SESSION.md — end of session 2026-04-08 night
- **Commit hash:** 620b5e0


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
- [ ] Detection reset + alert dedup + clear action + perimeter wording (Claude Code running)

## Priority queue (next session)
- P0: Detection reset + alert dedup + clear action + perimeter wording (Claude Code running)
- P1: Hikvision proxy — gate ServerSocket.bind behind Platform.isLinux/isMacOS check, suppress on web
- P2: YOLO local detector — wire to camera snapshot feed when Ollama is running
- P3: Telegram bot response quality — natural language tuning
- P4: dispatch_performance_projection.dart — per-contract value to client config (deferred, contract model not ready)
- P5: onyx_agent_camera_bridge_receiver.dart Dahua/Axis/Uniview — integration test with real hardware when available

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
