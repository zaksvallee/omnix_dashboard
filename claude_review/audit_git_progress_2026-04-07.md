# Audit: Git Progress — 2026-04-07

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: git history + uncommitted working tree
- Read-only: yes

---

## Executive Summary

**No commits have been made today (2026-04-07).** The last commit landed 12 days ago on 2026-03-26. Since then, a very large volume of new work has accumulated in the working tree — both modifications to tracked files and a substantial body of untracked new files. The uncommitted surface spans roughly 110 modified tracked files and 200+ untracked new files, representing multiple full feature lanes (HikConnect integration, ONYX agent architecture, YOLO detection, BI infrastructure, camera bridge UI, route registry decomposition) that have never been snapshotted.

The 5 most recent committed slices (2026-03-18 → 2026-03-26) were all UI-heavy checkpoint-style commits. The uncommitted work is architecturally deeper: new application services, domain authority models, infrastructure layers, and Supabase migrations.

---

## Recent Commits (Most Recent First)

### 1. `5a9e4ce` — 2026-03-26 — *Checkpoint controller redesign and restore command board*

- **Files changed:** 47 | **Lines:** +18,890 / −16,259
- **What changed:**
  - Sweeping rework of 14 UI pages: `admin_page`, `ai_queue_page`, `app_shell`, `client_app_page`, `client_intelligence_reports_page`, `clients_page`, `dashboard_page`, `dispatch_page`, `events_page`, `events_review_page`, `governance_page`, `guards_page`, `ledger_page`, `live_operations_page`, `sites_command_page`, `sites_page`, `sovereign_ledger_page`, `tactical_page`.
  - Added `controller_login_page.dart` (441 lines — new login surface for the controller role).
  - Minor `main.dart` adjustments (+106/−106) and `layout_breakpoints.dart` tuning.
  - Widget tests updated for most pages; new `onyx_app_login_widget_test.dart` added.
  - Report filter control revised (`report_receipt_filter_control.dart`).
- **Character:** Stabilisation pass — restoring command board layout after the large redesign in the previous commit. High churn across UI but net-neutral on feature surface.

---

### 2. `33fae1c` — 2026-03-22 — *Refresh Onyx dashboard layouts and widget tests*

- **Files changed:** 197 | **Lines:** +119,164 / −29,699 (largest commit in recent history)
- **What changed:**
  - Full UI layout refresh across all 16 major pages. `sovereign_ledger_page` (+2,450), `live_operations_page` (+4,775), `admin_page` (+40,813 net) among the largest.
  - Introduced `layout_breakpoints.dart` (47 lines — responsive breakpoint constants).
  - Introduced `onyx_surface.dart` (122 lines — shared surface shell).
  - Added `tmp/review_design_20260320/` — a complete React/TypeScript design reference prototype built with Vite, Tailwind, and shadcn/ui. Contains full page implementations (Dashboard, Dispatch, Governance, Sites, Tactical, AI Queue, Reports, etc.) plus an ONYX design system reference. This is a design artefact, not production code.
  - Widget tests overhauled for all pages; `guard_mobile_shell_page_widget_test` and `ledger_page_widget_test` added.
- **Character:** Wholesale layout generation pass using a reference design. The `tmp/` artefact was committed alongside production changes — it should likely be in `.gitignore` or archived separately.

---

### 3. `39d1db2` — 2026-03-19 — *Push dashboard body fidelity and action mapping*

- **Files changed:** 20 | **Lines:** +4,620 / −2,726
- **What changed:**
  - Deeper body content added to 6 UI pages: `admin_page` (+896), `ai_queue_page` (+1,134), `client_intelligence_reports_page` (+1,126), `clients_page` (+2,014), `governance_page` (+1,055), `live_operations_page` (+275).
  - Minor sovereign_ledger edits; `events_review_page` had 117 lines removed.
  - New route test: `onyx_app_ops_navigation_route_widget_test`.
  - Admin route test harness updated (+35 lines).
- **Character:** Incremental fidelity push — wiring action handlers and filling in body content that was placeholder in the previous commit.

---

### 4. `756cf2e` — 2026-03-19 — *Refresh ONYX command surfaces and harden coverage*

- **Files changed:** 86 | **Lines:** +23,562 / −5,677
- **What changed:**
  - **Telegram AI assistant** major expansion: `telegram_ai_assistant_service.dart` restructured (+1,210 changes); `telegram_ai_starter_examples.dart` added (777 lines — curated example set for the assistant).
  - `telegram_client_quick_action_service.dart` significantly expanded (+422 lines).
  - `monitoring_watch_availability_service.dart` added (72 lines — new watch availability gate).
  - `dispatch_persistence_service.dart` introduced (60 lines).
  - Live operations page major expansion (+2,093 lines); admin page large expansion (+2,579).
  - **New route tests added** for: dispatch, forensics, guards, live ops, ops navigation, sites, tactical, sites command — substantially broadening route-level coverage.
  - New test support files: `admin_route_state_harness.dart` (461 lines), `watch_drilldown_route_test_harness.dart` (71 lines).
  - `.gitignore` updated (+5 lines).
- **Character:** Dual-track commit — backend intelligence layer (Telegram AI) and full route test coverage expansion landed together.

---

### 5. `5bfa0bd` — 2026-03-18 — *Assess ONYX priority update*

- **Files changed:** ~59 | **Lines:** large net-positive
- **What changed:**
  - **Client comms lane introduced:** `client_comms_delivery_policy_service.dart`, `client_conversation_repository.dart`, `client_delivery_message_formatter.dart`, `client_messaging_bridge_repository.dart` — full client push delivery stack added.
  - `dispatch_persistence_service.dart` added (305 lines — first version).
  - `voip_call_service.dart` (305 lines) and `sms_delivery_service.dart` (280 lines) added.
  - `monitoring_site_narrative_service.dart` (252 lines) and `monitoring_watch_client_notification_gate_service.dart` (92 lines) added.
  - `telegram_ai_assistant_service.dart` major expansion (+1,554 lines).
  - `main.dart` very large expansion (+4,838 lines) — significant wiring additions.
  - **Scripts added:** `onyx_dvr_cors_proxy.py` (394 lines), `telegram_quick_action_live_smoke.sh` (205 lines), `watch_onyx_quick_actions.py` (67), `watch_telegram_updates.py` (154).
  - Supabase `.temp/` metadata files committed.
  - Matching tests added for all new services.
  - Docs: `docs/telegram_quick_action_live_smoke.md`.
- **Character:** Foundation commit — laid down client comms, VoIP/SMS delivery, Telegram quick actions, and DVR proxy in a single checkpoint. Large `main.dart` growth is a concern (see working tree notes below).

---

## Uncommitted Working Tree (as of 2026-04-07)

The working tree contains a very large amount of uncommitted work. This is not a clean checkpoint.

### Modified Tracked Files (~110 files)

All layers are touched. Key clusters:

| Layer | Representative files modified |
|---|---|
| `lib/application/` | All major services — cctv, dvr, dispatch, monitoring, telegram, video, guard, report, client comms |
| `lib/domain/` | Aggregate, events, incidents, evidence, intelligence, projections, CRM reporting |
| `lib/ui/` | All major pages; `dispatch_models.dart` **deleted** |
| `lib/engine/` | `dispatch_state_machine.dart`, `vertical_slice_runner.dart`, `action_status.dart` |
| `lib/infrastructure/` | `supabase_client_ledger_repository.dart`, `in_memory_client_ledger_repository.dart`, `news_intelligence_service.dart` |
| `lib/main.dart` | Modified |
| `test/` | ~55 test files modified across application, domain, infrastructure, UI |
| `docs/` | `client_conversation_supabase_contract.md`, `onyx_future_feature_backlog.md` |
| `config/onyx.local.example.json` | Modified |
| `pubspec.yaml`, `analysis_options.yaml`, `.gitignore` | Modified |

**Deleted:** `lib/ui/dispatch_models.dart` — appears to have been moved to `lib/application/dispatch_models.dart` (untracked).

---

### Untracked New Files (~200+ files)

Grouped by subsystem:

#### HikConnect Integration (30+ files)
New files in `lib/application/hik_connect_*`:
- Full OpenAPI client and runtime config
- Bootstrap orchestrator, packet service, runtime config
- Camera catalog, resolver, bootstrap service
- Alarm batch, payload loader, smoke service
- Bundle sanitizer, status service, bundle collector
- Preflight suite: health, manifest status, next step, payload inventory, report, runner
- Seed formatters, video payload loader, video session, video smoke service
- Matching test files for every service

#### ONYX Agent / Camera Bridge (20+ files)
New in `lib/application/onyx_agent_*` and `lib/application/onyx_*`:
- `onyx_agent_camera_bridge_server.dart` (+ contract, IO, stub, receiver, health service)
- `onyx_agent_camera_probe_service.dart`, `onyx_agent_camera_change_service.dart`
- `onyx_agent_local_brain_service.dart`, `onyx_agent_cloud_boost_service.dart`
- `onyx_agent_context_snapshot_service.dart`, `onyx_agent_client_draft_service.dart`
- `onyx_agent_tcp_probe_io.dart`, `onyx_agent_tcp_probe_stub.dart`
- `onyx_command_brain_orchestrator.dart`, `onyx_command_parser.dart`
- `onyx_command_specialist_assessment_service.dart`, `onyx_operator_orchestrator.dart`
- `onyx_scope_guard.dart`, `onyx_tool_bridge.dart`
- `onyx_telegram_command_gateway.dart`, `onyx_telegram_operational_command_service.dart`
- `reports_workspace_agent.dart`, `onyx_claude_report_config.dart`

#### YOLO Detection (4 service files)
- `monitoring_yolo_detection_service.dart`
- `monitoring_yolo_detector_health_service.dart`
- `monitoring_yolo_semantic_probe_scheduler.dart`
- `monitoring_watch_continuous_visual_service.dart`
- **Model weights untracked:** `yolov8l.pt`, `yolov8n.pt` (binary blobs — should be in `.gitignore`)

#### Alarm Infrastructure
- `lib/application/alarm_account_registry.dart`
- `lib/application/alarm_triage_gateway.dart`
- `lib/domain/alarms/` (directory)
- `lib/infrastructure/alarm/` (directory)
- `test/domain/alarms/`, `test/infrastructure/alarm/`

#### BI Infrastructure
- `lib/infrastructure/bi/` directory
- `test/infrastructure/bi/` directory
- `lib/ui/vehicle_bi_dashboard_panel.dart`
- `test/ui/vehicle_bi_dashboard_panel_test.dart`

#### Camera Bridge UI Shell (20+ components)
All in `lib/ui/onyx_camera_bridge_*`:
- Shell: surface, panel, card, body, actions, shell_actions
- Status: badge, lead badge, status detail list, metadata block, metadata panel
- Health: card, card body, health panel
- Summary, validation panel, validation summary
- Chip list, chip wrap, clipboard, detail line, tone resolver, action button, action stack

#### New Pages
- `lib/ui/onyx_agent_page.dart`
- `lib/ui/vip_protection_page.dart`
- `lib/ui/risk_intelligence_page.dart`
- `lib/ui/client_comms_queue_board.dart`
- `lib/ui/track_overview_board.dart`
- `lib/ui/operator_stream_embed_view.dart` (+ web + stub)

#### Route Registry Decomposition (8 files)
`lib/ui/onyx_route_registry.dart` split into sections:
- `onyx_route_builders.dart`
- `onyx_route_command_center_builders.dart`
- `onyx_route_dispatcher.dart`
- `onyx_route_evidence_builders.dart`
- `onyx_route_governance_builders.dart`
- `onyx_route_operations_builders.dart`
- `onyx_route_registry_sections.dart`
- `onyx_route_system_builders.dart`

#### New Domain Authority Layer
- `lib/domain/authority/onyx_authority_scope.dart`
- `lib/domain/authority/onyx_command_brain_contract.dart`
- `lib/domain/authority/onyx_command_intent.dart`
- `lib/domain/authority/onyx_task_protocol.dart`
- `lib/domain/authority/telegram_role_policy.dart`
- `lib/domain/authority/telegram_scope_binding.dart`

#### Supabase Migrations (untracked — never committed)
- `supabase/migrations/202604070001_default_site_coordinates.sql`
- `supabase/migrations/202604070002_create_alarm_receiver_registry.sql`
- `supabase/migrations/202604070003_create_bi_vehicle_persistence.sql`

#### Telegram / Comms Additions
- `lib/application/telegram/` (directory)
- `lib/application/telegram_bridge_delivery_memory.dart`
- `lib/application/telegram_bridge_resolver.dart`
- `lib/application/telegram_client_prompt_signals.dart`
- `lib/application/telegram_client_router_policy.dart`
- `lib/application/telegram_endpoint_scope_resolution.dart`
- `lib/application/telegram_high_risk_classifier.dart`
- `lib/application/telegram_push_coordinator.dart`
- `lib/application/telegram_ai_assistant_camera_health.dart`
- `lib/application/telegram_ai_assistant_clarifiers.dart`
- `lib/application/telegram_ai_assistant_site_view.dart`

#### Scripts / Tooling
- `scripts/install-hooks.sh`
- `scripts/post-commit-hook.sh`
- `scripts/run_claude_audit.sh`
- `tool/` directory

#### Docs (untracked)
- `docs/design_handoff.md`
- `docs/hik_connect_openapi_rollout_prep.md`
- `docs/onyx_simulation_case_schema_v1.md`
- `docs/onyx_telegram_admin_handoff_2026-03-29.md`

#### Other
- `lib/application/dispatch_models.dart` — model layer extracted from deleted `lib/ui/dispatch_models.dart`
- `lib/application/admin/` directory
- `lib/application/simulation/` directory
- `test/application/simulation/` directory
- `simulations/` top-level directory
- `ONYX_BACKLOG.md`, `onyx_nav_dump.txt`
- `clickup_dump/` directory

---

## Commit Risk Flags (From History)

- **`main.dart` is growing very large.** Across just 3 commits (5bfa0bd → 756cf2e → 5a9e4ce) it absorbed +4,838, +1,127, and +106 lines. It is still modified in the working tree. This is a god-file risk.
- **`tmp/review_design_20260320/` was committed.** That directory belongs in `.gitignore` or should be removed from git history. It is a React prototype with 150+ files and adds significant noise to `git log` and `git blame` on production code.
- **`sovereign_ledger_page.dart` is the largest UI file** — 5,676 lines of churn in commit `33fae1c` alone. Combined with current modified status, it is a stabilisation risk.

---

## Working Tree Risk Flags

- **YOLO model weights (`yolov8l.pt`, `yolov8n.pt`) are untracked** but present in the repo root. These are large binary files that must not be committed to git. They should be in `.gitignore` immediately. Action: `AUTO`.
- **3 Supabase migrations are untracked and dated 2026-04-07.** These are schema changes that will not apply to any environment until committed and deployed. If they are production-ready, they are overdue. Action: `REVIEW`.
- **`lib/ui/dispatch_models.dart` was deleted (tracked)** but a new `lib/application/dispatch_models.dart` is untracked. The move has not been committed — the deletion is staged but the replacement is not. Any consumer of the old import path will break on compile until both are committed together. Action: `REVIEW`.
- **200+ untracked files represent zero recovery point.** If the working tree is corrupted, all of this work is lost. No checkpoint exists since 2026-03-26.

---

## Recommended Actions

1. **Immediately add `yolov8l.pt` and `yolov8n.pt` to `.gitignore`.** Do not commit binary model weights to git. `AUTO`.
2. **Commit the `dispatch_models.dart` move atomically** — deletion + new file in the same commit to avoid import breakage. `REVIEW`.
3. **Commit the 3 Supabase migrations** if schema changes are ready for review. `REVIEW`.
4. **Create a working-tree checkpoint commit** for the full uncommitted body (HikConnect, ONYX agent, YOLO, BI, camera bridge UI, route registry) — even as a work-in-progress branch snapshot. 12 days without a commit is a high-risk position. `REVIEW`.
5. **Move `tmp/review_design_20260320/` to `.gitignore`** or remove from git history to keep the production repo clean. `REVIEW`.
6. **Audit `main.dart` size.** Its current size trajectory makes it a god-file. `DECISION`.
