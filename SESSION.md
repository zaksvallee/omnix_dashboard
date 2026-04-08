# ONYX Platform — Session State
> Auto-updated on every commit. Read this at the start of every session.

## Project
- **Repo:** /Users/zaks/omnix_dashboard
- **Stack:** Flutter Web · Supabase v2+ · Ollama · OpenAI
- **Theme:** Dark mode · Accent #9D4BFF · OnyxTheme
- **Router:** go_router — /dashboard /operations /clients /guards /intelligence /hr /settings /help
- **Rules:** Full file replacements only · Extend not rewrite · supabase_flutter v2+ only

## Last session
- **Date:** 2026-04-08
- **Last commit:** polish: Command Center grid — layout, sizing, icon
- **Commit hash:** 03a0ce4

## Completed (this sprint)
- [x] Command Center grid polish — layout, sizing, icon, border radius
- [x] ai_queue_page — shadow sites rebuild, desktopWorkspace layout, selectedFocusId clear
- [x] Local brain upgrade — ONYX system prompt, smart routing matrix (OnyxAgentRoutingTier)
- [x] Governance badge color — locked to 0xFF60A5FA (resolves P1 audit flag)

## In progress
- [ ] OnyxStatusBanner + OnyxPageHeader — 13 pages (command ready, not yet fired)
- [ ] Demo hygiene — audit_demo_hygiene_2026-04-07.md items pending

## Priority queue (next to action)
- P0: Remaining demo polish items (see audit_demo_hygiene_2026-04-07.md)
- P1: 226 failing tests — CLIENT-MS-VALLEE IDs + prompt wording
- P2: Tactical map fixes — FlutterMap key, GlobalKeys, DateTime.now()
- P3: BI demo fixes — exceptionVisits, peak hour, pharmacy fixture
- P4: Dispatch mock cleanup
- P5: Telegram assistant P1
- P6: Camera ONVIF implementation

## Blocked / needs decision
- [ ] Agent routing — wire onyxAgentRoutingTierFor() as intent-based default with operator toggle as override. Requires UI decision on toggle behaviour. Insertion point: onyx_agent_page.dart lines 5302–5461.

## Audit reports
- Latest: /claude_review/ — check most recent file
- Hygiene audit: audit_demo_hygiene_2026-04-07.md

## Key files
- Brain service: lib/application/onyx_agent_cloud_boost_service.dart
- Routing: lib/domain/authority/onyx_route.dart
- Theme: lib/ui/onyx_surface.dart (OnyxPageHeader lives here)
- Status banner: lib/ui/components/onyx_status_banner.dart
- AI queue: lib/ui/ai_queue_page.dart

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
