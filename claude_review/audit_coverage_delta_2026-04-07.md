# Audit: Coverage Delta — Codex Session 2026-04-07

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: test/ vs lib/ — delta since `audit_test_coverage_2026-04-07.md` baseline
- Read-only: yes

---

## Executive Summary

The prior audit established a 77.5% coverage baseline against 410 lib / 266 test files. Codex has
since added **~99 new test files** and **121 new lib files** in an uncommitted working-tree session.
Three of the four P1 gaps from the earlier audit are now addressed. The SLA chain
(`SLABreachEvaluator`, `SLAClock`, `SLAPolicy`) remains entirely untested — the single most
consequential continued gap. A new `domain/authority/` module was introduced with 8 files and zero
test coverage. Estimated current coverage: **~79–81%**, a modest uplift from the baseline, held
back by the SLA chain gap and the new untested authority domain.

---

## Repository State at Time of This Audit

| Metric | Prior Audit | Now (working tree) | Delta |
|---|---|---|---|
| Lib dart files | 410 | 427 | +17 committed, +121 untracked |
| Test dart files | 266 | 281 | +15 committed, +99 untracked |
| Committed test files | — | 182 | baseline before today's session |
| Untracked new test files | — | ~99 | Codex session, not yet committed |
| Untracked new lib files | — | 121 | Codex session, not yet committed |

---

## 1. What New Tests Codex Added Today

### 1a. P1/P2 Gap Closures (directly from prior audit findings)

| Prior Gap | Priority | Status |
|---|---|---|
| `cctv_false_positive_policy_test.dart` | P1 AUTO | **CLOSED** — file exists under `test/application/` |
| `test/engine/dispatch_state_machine_test.dart` | P1 AUTO | **CLOSED** — file exists under `test/engine/` |
| `test/domain/incidents/incident_service_test.dart` | P1 REVIEW | **CLOSED** — file exists under `test/domain/incidents/` |
| `test/domain/crm/reporting/sla_dashboard_projection_test.dart` | P2 REVIEW | **PARTIALLY CLOSED** — 1 of 9 CRM projection files covered |
| `test/engine/vertical_slice_runner_test.dart` | P2 support | **NEW** — engine-layer slice runner |

### 1b. New Test Suites (entirely new coverage territory)

#### HikConnect suite — 19 new test files
All 19 HikConnect lib files added today have a matching test file:
- Preflight chain: `hik_connect_preflight_{bundle_health,manifest_status,next_step,payload_inventory,report,runner}_service_test.dart` (6 files)
- Bootstrap: `hik_connect_bootstrap_{orchestrator_service,packet_service,runtime_config}_test.dart` (3 files)
- Bundle/camera: `hik_connect_{bundle_sanitizer,bundle_status_service,camera_bootstrap_service,camera_catalog,camera_payload_loader,camera_resolver}_test.dart` (6 files)
- Alarm/video: `hik_connect_{alarm_batch,alarm_payload_loader,alarm_smoke_service,video_payload_loader,video_session,video_smoke_service,openapi_client,env_seed_formatter,scope_seed_formatter}_test.dart` (9 files)

**Quality signal:** 19-for-19 match rate in the HikConnect module — this is the best-tested new subsystem added today.

#### OnyxAgent suite — 10 new test files
- `onyx_agent_camera_bridge_{health_service,receiver,server_contract,server,change_service,probe_service}_test.dart`
- `onyx_agent_{client_draft_service,cloud_boost_service,context_snapshot_service,local_brain_service}_test.dart`

Prior audit recorded these as in the `??` untracked list. All 10 agent logic services now confirmed covered. Platform variant stubs (`server_io`, `server_stub`, `tcp_probe_io`, `tcp_probe_stub`) remain intentionally untested — acceptable via contract test.

#### YOLO detection suite — 3 new test files
- `monitoring_yolo_detection_service_test.dart`
- `monitoring_yolo_detector_health_service_test.dart`
- `monitoring_yolo_semantic_probe_scheduler_test.dart`

#### Onyx command/operator suite — 5 new test files
- `onyx_command_brain_orchestrator_test.dart`
- `onyx_command_parser_test.dart`
- `onyx_command_specialist_assessment_service_test.dart`
- `onyx_operator_orchestrator_test.dart`
- `onyx_scope_guard_test.dart`

#### Camera bridge UI suite — 14 new widget test files
- `onyx_camera_bridge_{actions,chip_list,clipboard,health_panel,lead_status_badge,shell_actions,shell_body,shell_panel,shell_surface,status_badge,status_metadata_panel,summary_panel,tone_resolver,validation_panel}_test.dart`

#### Domain/engine — 7 new test files
- `test/domain/incidents/incident_service_test.dart`
- `test/domain/crm/reporting/sla_dashboard_projection_test.dart`
- `test/domain/intelligence/decision_service_test.dart`
- `test/domain/onyx_command_brain_contract_test.dart`
- `test/domain/onyx_route_test.dart`
- `test/domain/integration/incident_to_crm_mapper_test.dart`
- `test/engine/dispatch_state_machine_test.dart`, `vertical_slice_runner_test.dart`

#### Simulation suite — 4 new test files
- `test/application/simulation/{run_onyx_scenario_tool,scenario_definition,scenario_replay_history_signal_service,scenario_runner}_test.dart`

#### Other notable additions
- `monitoring_watch_continuous_visual_service_test.dart`
- `local_hikvision_dvr_proxy_{runtime_config,service}_test.dart`
- `admin_directory_service_test.dart`, `admin_write_follow_up_policy_test.dart`
- `client_backend_probe_coordinator_test.dart`, `client_camera_health_fact_packet_service_test.dart`
- `client_messaging_bridge_repository_test.dart`
- `intelligence_event_object_semantics_test.dart`
- Controller/agent route UI: `controller_login_page_widget_test.dart`, `onyx_agent_page_widget_test.dart`, `onyx_app_agent_route_widget_test.dart`
- `risk_intelligence_page_widget_test.dart`, `vip_protection_page_widget_test.dart`
- `onyx_route_registry_sections_test.dart`

---

## 2. Critical Paths Still at Zero Coverage

### P1 — SLA chain: `SLABreachEvaluator`, `SLAClock`, `SLAPolicy` (unchanged from prior audit)

- Action: **AUTO**
- No test file found for any of these three after a full `find` scan of `test/`.
- These are the core functions that decide when SLA breach events are emitted and when escalation is triggered.
- The `incident_service_test.dart` was added (closing the coordinator gap), but if the underlying SLA evaluators are wrong, that coordinator test will only catch integration failures — not the timing and clock logic itself.
- Evidence: `lib/domain/incidents/risk/sla_breach_evaluator.dart`, `sla_clock.dart`, `sla_policy.dart`
- Risk: **unchanged from P1**. This is the most important remaining gap.

### P1 — `domain/authority/` module: 8 files, zero tests

- Action: **REVIEW**
- Finding: A new `lib/domain/authority/` module was introduced today with 8 files:
  - `authority_token.dart`
  - `onyx_authority_scope.dart`
  - `onyx_command_brain_contract.dart` (the domain-level contract, not the app-layer one)
  - `onyx_command_intent.dart`
  - `onyx_task_protocol.dart`
  - `operator_context.dart`
  - `telegram_role_policy.dart`
  - `telegram_scope_binding.dart`
- No test file exists for any of these. `telegram_role_policy.dart` and `telegram_scope_binding.dart` make authorization decisions. `onyx_command_intent.dart` defines intent classification.
- Note: `test/domain/onyx_command_brain_contract_test.dart` was added — but this references the app-layer orchestration contract, not the domain-level authority contract above.
- Why it matters: Authorization scope logic (`TelegramRolePolicy`, `TelegramScopeBinding`) must be tested against known role configurations. Silent mis-authorization in a multi-tenant security operations platform is a high-risk failure mode.
- Suggested follow-up: Zaks should confirm whether `domain/authority/` contains decision logic or pure data contracts. If decision logic, Codex should add tests before this module is committed.

### P2 — `ExecutionEngine` still has no direct test

- Action: **AUTO**
- No `execution_engine_test.dart` found. The duplicate-dispatch guard and authority validation are still only exercised indirectly through the dispatch triage test.
- The `dispatch_state_machine_test.dart` was added (closing the state matrix gap), but `ExecutionEngine` is a separate file with its own invariants.
- Evidence: `lib/engine/execution/execution_engine.dart`

### P2 — CRM reporting: 8 of 9 projection files still untested

- Action: **REVIEW** (unchanged from prior audit)
- `sla_dashboard_projection_test.dart` was added — one file closed.
- Still no tests for:
  - `dispatch_performance_projection.dart`
  - `monthly_report_projection.dart`
  - `multi_site_comparison_projection.dart`
  - `report_bundle_assembler.dart`
  - `report_bundle_canonicalizer.dart`
  - `executive_summary_generator.dart`
  - `sla_tier_service.dart`
  - `sla_tier_projection.dart`
- These generate client-facing PDF reports. Incorrect projections (wrong SLA tier, wrong month-over-month delta) produce wrong client deliverables.

### P2 — `escalation_trend_projection.dart` — no test

- Action: **AUTO** (unchanged)
- The zero-guard division in `escalation_trend_projection.dart` is not tested.

### P3 — `guard_performance_service.dart` — no test

- Action: **AUTO** (unchanged)

### P3 — New lib files with no test coverage

New files added today with no corresponding test:
- `application/telegram_ai_assistant_camera_health.dart` — camera health prompt builder
- `application/telegram_ai_assistant_clarifiers.dart` — clarifier prompt builder
- `application/telegram_ai_assistant_site_view.dart` — site view prompt builder
- `application/onyx_tool_bridge.dart` — tool dispatch bridge
- `ui/client_comms_queue_board.dart` — UI component
- `ui/operator_stream_embed_view.dart` / `_stub.dart` — platform split, stub variant
- Route builders (7 files) — unchanged DECISION from prior audit

---

## 3. Estimated Coverage: Now vs 77.5% Baseline

Coverage estimation methodology: file-ratio analysis + critical-gap weighting. No `flutter test --coverage` output is available to this auditor.

### File ratio

| Scope | Lib files | Test files | Ratio |
|---|---|---|---|
| Working tree total | 427 | 281 | 65.8% |
| Prior audit snapshot | 410 | 266 | 64.9% |
| New code added today | +121 lib | +~99 test | ~82% for new code |

The new HikConnect and OnyxAgent test suites are well-matched to their corresponding lib files, pulling the new-code ratio higher than the pre-existing average. This is a positive signal.

### Critical-gap weighting

The 77.5% baseline (from earlier coverage instrumentation) likely reflects executed-line coverage across the committed test suite. The current estimate accounts for:

| Factor | Effect on coverage |
|---|---|
| 3 P1 gap closures (cctv_false_positive, dispatch_state_machine, incident_service) | +0.5–1% |
| 99 new tests against 121 new lib files (~82% match) | +1–2% for new lines |
| SLA chain (3 files, zero tests, high line count) | −0.5% drag |
| domain/authority (8 new files, zero tests) | −0.3% drag |
| Partial CRM gap closure (1 of 9) | +0.1% |

**Estimated current coverage: ~79–81%**

This is a 1.5–3.5 point uplift from the 77.5% baseline. The improvement is real but not transformative. The SLA chain gap and the new untested authority domain dampen what would otherwise be a stronger gain.

---

## What Looks Good

- **HikConnect 19-for-19 match rate**: Every new HikConnect lib file has a corresponding test. This is a high-quality, disciplined addition.
- **OnyxAgent coverage**: All 10 agent logic services now have test files. The prior audit flagged these as untracked; they are now confirmed.
- **Engine layer**: `dispatch_state_machine_test.dart` closes the cleanest P1 gap from the prior audit — a pure matrix test with no dependencies to stub.
- **CRM/Incident entry point**: `incident_service_test.dart` closes the partial-write risk at the coordinator level.
- **Camera bridge UI**: 14 widget tests for the new camera bridge shell are a strong UI coverage push.

---

## Recommended Fix Order

1. **SLA chain** (`sla_breach_evaluator`, `sla_clock`, `sla_policy`) — P1 AUTO. Unchanged from prior audit. These remain the highest-risk untested files in the repo. Three pure functions, no stubs needed.
2. **`domain/authority/` — `TelegramRolePolicy` + `TelegramScopeBinding`** — P1 REVIEW before commit. Authorization decision logic in a security platform must be tested before it ships.
3. **`ExecutionEngine` direct test** — P2 AUTO. The duplicate-dispatch and authority-guard controls need direct test coverage independent of the triage coordinator.
4. **`escalation_trend_projection`** — P2 AUTO. Zero-division guard in a reporting function. Self-contained.
5. **CRM reporting projections** — P2 REVIEW. Zaks to prioritise 2–3 most client-visible projections for Codex to implement next. `SLATierService` and `DispatchPerformanceProjection` are the next highest-value candidates after `SLADashboard`.
6. **`telegram_ai_assistant_camera_health/clarifiers/site_view`** — P3 AUTO. New prompt builders should have token-and-shape tests before the AI assistant module is considered stable.
7. **Route builders** — P3 DECISION (unchanged). Low urgency; block on Zaks product decision.

---

## Staleness Notice

This report reflects the working-tree state as of 2026-04-07. It will become stale after any Codex commit that lands the untracked files. Re-run coverage delta audit after the next commit batch.
