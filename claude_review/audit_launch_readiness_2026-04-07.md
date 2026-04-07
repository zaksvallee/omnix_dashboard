# Audit: Launch Readiness Checklist

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: All 2026-04-07 Codex summaries + audit reports vs. demo-readiness bar
- Read-only: yes

---

## How to Read This Report

Items are assessed against a single bar: **first real client demo** — a live walkthrough of the
ONYX security operations platform where a client can see real data flowing through every surface
they are shown.

Estimated days remaining are working-day estimates for Codex implementation time only. They do not
include Zaks decision time for DECISION-labelled items, which must come first.

**Staleness note on supporting audits:** `audit_coverage_delta_2026-04-07.md` and
`audit_backlog_gaps_2026-04-07.md` were written as point-in-time Claude Code findings earlier in
the session. Several gaps they flagged (SLA chain tests, dispatch state machine, execution engine
tests, demo credential security, governance stub data) were subsequently implemented by Codex and
are confirmed done in this report. Per the staleness rule, those prior findings should not be
treated as open once the corresponding codex summary confirms implementation.

---

## 1. Fully Done

All items below were implemented and validated by Codex today (2026-04-07). Focused tests pass.
`dart analyze` is clean on touched files.

### Core Safety and Correctness

| Item | Summary | Evidence |
|---|---|---|
| CCTV false-positive policy critical bugs | Missing JSON hour fields no longer widen into all-day suppression; confidence semantics corrected | `codex_summary_critical_fixes_2026-04-07.md` |
| Guard sync delete-first race | `saveAssignments` / `saveQueuedOperations` upsert before prune; failed upsert can no longer wipe live data | `codex_summary_critical_fixes_2026-04-07.md` |
| Login security hardening | Demo credentials gated behind `kDebugMode`; plaintext passwords removed from login card UI | `codex_summary_login_security_2026-04-07.md` |
| Evidence ledger serialization | `sealDispatch` now stores real event JSON, not `"Instance of ..."` strings | `codex_summary_evidence_critical_2026-04-07.md` |
| Evidence ledger idempotency | Duplicate intelligence re-seals return existing row instead of appending duplicate chain entries | `codex_summary_evidence_critical_2026-04-07.md` |
| Evidence ledger durability | Persistence failures queue and retry instead of silently discarding evidence | `codex_summary_evidence_critical_2026-04-07.md` |
| Export hash re-verification | Certificate export re-derives expected hash and refuses to issue on mismatch | `codex_summary_evidence_critical_2026-04-07.md` |
| Dispatch ledger sealing ordering | `sealDispatch` occurs before `ExecutionCompleted` is appended | `codex_summary_dispatch_service_p1s_2026-04-07.md` |
| Dispatch sequence allocation | Sequence: 0 placeholders replaced with explicit monotonic per-dispatch allocation | `codex_summary_dispatch_service_p1s_2026-04-07.md` |
| Dispatch ID collision hardening | Full provider string + deterministic UUID suffix; truncation collisions eliminated | `codex_summary_dispatch_service_p1s_2026-04-07.md` |
| Dispatch state machine semantics | `executed` = attempted; `confirmed` = terminal success; full transition matrix tests locked | `codex_summary_state_machine_decisions_2026-04-07.md` |
| SLA breach no longer forces escalation | `slaBreached` flag added; `incidentSlaBreached` preserves current status; CRM projections corrected | `codex_summary_state_machine_decisions_2026-04-07.md` |
| SLA clock drift tolerance | 120-second tolerance window; drift emits `unverifiable_clock_event` instead of false breach | `codex_summary_sla_decisions_2026-04-07.md` |
| SLA retroactive breach on restart | `IncidentService.initialize` evaluates all open incidents on restart; retroactive breach metadata included | `codex_summary_sla_decisions_2026-04-07.md` |
| SLA UTC enforcement | `SLAClock.evaluate` rejects non-UTC timestamps | `codex_summary_sla_decisions_2026-04-07.md` |
| Obfuscation-safe audit type keys | `runtimeType.toString()` replaced with explicit `toAuditTypeKey()` on all dispatch event subclasses | `codex_summary_bi_foundation_2026-04-07.md` |

### Operator-Facing UI Fixes

| Item | Summary | Evidence |
|---|---|---|
| Governance live data wired | Hardcoded fleet/vigilance/compliance stubs replaced with live feeds from guard sync, admin directory, and dispatch persistence | `codex_summary_governance_p1_2026-04-07.md` |
| Governance staging mode disclosure | `Pending live feed` shown when data is unavailable; no fabricated operational values | `codex_summary_governance_p1_2026-04-07.md` |
| Camera staging mode visibility | Visible `Camera control in staging mode` indicator on CCTV agent UI and admin bridge controls | `codex_summary_reporting_decisions_2026-04-07.md` |
| Hardcoded report narratives removed | Supervisor assessment, company achievements, emerging threats fields use empty/default until AI agent provides real content | `codex_summary_reporting_decisions_2026-04-07.md` |
| Dispatch page polling race | Operator intent (cleared / dispatched) preserved across polling cycles via `_dispatchOverrides` | `codex_summary_auto_batch_3_2026-04-07.md` |
| Dispatch page GlobalKey stability | Workspace `GlobalKey`s moved from `build()` into persistent `State` fields | `codex_summary_auto_batch_3_2026-04-07.md` |
| Events review page build-time mutations | Post-frame sync via `_queueSelectedEventSync` / `_queueDesktopWorkspaceSync` | `codex_summary_auto_batch_3_2026-04-07.md` |
| Guard mobile shell build-time mutations | Post-frame `_queueSelectedOperationClear`; `didUpdateWidget` uses `setState` | `codex_summary_auto_batch_3_2026-04-07.md` |
| Client intelligence reports month anchor | `_reportGenerationNowUtc()` anchors to latest site event; historical previews now show correct content | `codex_summary_auto_batch_3_2026-04-07.md` |
| Clients page fake VoIP state | Default state changed to unconfigured; staged/active panel only renders when VoIP is actually configured | `codex_summary_ui_p1_batch_2026-04-07.md` |
| AI queue paused progress bar | `LinearProgressIndicator` uses `0.0` when paused; no misleading countdown | `codex_summary_ui_p1_batch_2026-04-07.md` |
| AI queue CCTV dismiss race | Feed selection not cleared by dismissal of unrelated alert | `codex_summary_ui_p1_batch_2026-04-07.md` |
| Guards page live data | Live repository path added; roster/history derived from real data with seeded fallback | `codex_summary_ui_p1_batch_2026-04-07.md` |
| App shell `LateInitializationError` | Nullable `OnyxRoute? selection`; route-change handoff behind null-safe mounted check | `codex_summary_shell_vip_authority_2026-04-07.md` |
| App shell build-time side effects | `_syncAutoScrollState` moved out of `build()`; user interaction fallback reset timer added | `codex_summary_shell_vip_authority_2026-04-07.md` |
| VIP protection hardcoded badges | Badge colors, labels, and fact titles use live `detail.*` fields | `codex_summary_shell_vip_authority_2026-04-07.md` |
| Ledger page Supabase injection | `SupabaseClientLedgerRepository` constructed via injected seam, not inline | `codex_summary_auto_batch_2_2026-04-07.md` |
| Admin page Supabase injection seams | `siteIdentityRegistryRepositoryBuilder` + `clientMessagingBridgeRepositoryBuilder` injected via constructor | `codex_summary_auto_batch_2_2026-04-07.md` |
| Live operations camera health distinction | Separates empty/null camera packet from load failure; logs with scope context | `codex_summary_auto_batch_resume_2026-04-07.md` |
| DVR reconnect state | Proxy exposes `reconnecting` / `connected` / `disconnected`; UI surfaces `Proxy RECONNECTING...` label | `codex_summary_bridge_dvr_batch_2026-04-07.md` |
| Bridge server JSON hardening | Malformed JSON returns structured 400; server exceptions return structured error envelope | `codex_summary_bridge_dvr_batch_2026-04-07.md` |
| Agent brain error signals | Cloud/local brain failures surface as operator-visible tool messages instead of silent null advisories | `codex_summary_agent_brain_error_signals_2026-04-07.md` |
| Telegram AI fallback on ONYX errors | Assistant falls back to direct provider when ONYX cloud returns structured error | `codex_summary_agent_brain_error_signals_2026-04-07.md` |
| Monitoring watch transient-error streak | Active detection streak preserved through transient HTTP/decode errors | `codex_summary_auto_batch_2_2026-04-07.md` |
| Telegram regex fix | `RegExp(r'\\s+')` → `RegExp(r'\s+')` in `_humanizeScopeLabel` | `codex_summary_auto_batch_2_2026-04-07.md` |

### Reporting and Intelligence

| Item | Summary | Evidence |
|---|---|---|
| Reports workspace agent Phase 1 | Claude API integration for narrative generation; fallback-safe; receipt hash integrity preserved | `codex_summary_reports_agent_phase1_2026-04-07.md` |
| BI foundation: hourly breakdown | `hourlyBreakdown` field added to `SovereignReportVehicleThroughput`; serialized and tested | `codex_summary_bi_foundation_2026-04-07.md` |
| BI foundation: vehicle dashboard panel | `VehicleBiDashboardPanel` with totals, dwell, repeat rate, hourly bar chart, entry/service/exit funnel | `codex_summary_bi_foundation_2026-04-07.md` |
| BI foundation: carwash demo fixture | Synthetic carwash shift fixture JSON for demo use (`test/fixtures/carwash_bi_demo_report.json`) | `codex_summary_bi_foundation_2026-04-07.md` |
| Export coordinator | `ExportCoordinator` centralises clipboard/JSON/CSV export with uniform logging; migrated from 2 pages | `codex_summary_auto_batch_3_2026-04-07.md` |

### Test Infrastructure

| Item | Summary | Evidence |
|---|---|---|
| SLA clock and breach evaluator tests | Direct unit tests for timing, drift, and UTC enforcement; locked by `sla_clock_test.dart` + `sla_breach_evaluator_test.dart` | `codex_summary_auto_batch_resume_2026-04-07.md`, `codex_summary_sla_decisions_2026-04-07.md` |
| Execution engine tests | `execution_engine_test.dart` added covering duplicate-dispatch guard and authority validation | `codex_summary_auto_batch_resume_2026-04-07.md` |
| Dispatch state machine transition matrix | Full legal/illegal transition matrix locked by `dispatch_state_machine_test.dart` | `codex_summary_state_machine_decisions_2026-04-07.md` |
| Vertical slice runner test | Success path rebuilds into `CONFIRMED` state locked by test | `codex_summary_state_machine_decisions_2026-04-07.md` |
| Authority domain tests | `onyx_scope_guard_test` + `onyx_telegram_command_gateway_test` expanded with route/scope coverage | `codex_summary_shell_vip_authority_2026-04-07.md` |
| HikConnect 19-for-19 test coverage | Every HikConnect lib file has a matching test; highest-quality new subsystem | `audit_coverage_delta_2026-04-07.md` |
| OnyxAgent 10/10 test coverage | All 10 agent logic services have test files | `audit_coverage_delta_2026-04-07.md` |
| Camera bridge UI 14-for-14 test coverage | Full widget test suite for camera bridge shell panels, badges, tones, validation | `audit_coverage_delta_2026-04-07.md` |
| Simulation suite | 4 new test files covering scenario runner, replay history, and scenario definitions | `audit_coverage_delta_2026-04-07.md` |

---

## 2. In Progress (Started, Not Complete)

### Admin Page Decomposition

**Status:** Injection seams added (2 of ~5 extraction steps). The 45,595-line `admin_page.dart` still
owns direct Supabase upserts, employee/site/client CRUD, demo seed/clear logic, and identity policy
mutations in `_AdministrationPageState`. No coordinator or `AdminDemoSeedService` has been
extracted yet.

**Blocking for demo?** No — it functions. It is a structural debt and maintenance risk, not a
runtime failure.

**Remaining scope:**
- Extract employee/client/site CRUD into `AdminDirectoryService` mutation methods
- Extract demo seed/clear into `AdminDemoSeedService`
- Move remaining inline Supabase dependencies into service constructors
- Reduce `_AdministrationPageState` to thin coordinator

**Estimated remaining:** 3–5 days (REVIEW — extraction boundaries need Zaks alignment)

---

### CRM Reporting Correctness

**Status:** Partial. Three confirmed bugs are still live:

1. `ReportBundleAssembler.build` force-unwraps `slaProfile!` — crash for any client with incomplete CRM event stream
2. `DispatchPerformanceProjection` synthesises `'Guard $guardId'` and `'PSIRA-$guardId'` — fabricated PII visible in client-facing PDF reports
3. `breachedIncidents` count includes overridden incidents while compliance formula excludes them — same client can show "3 breaches, 100% compliance" simultaneously
4. Three divergent `slaComplianceRate` formulas in use across projections for the same client in the same period
5. 8 of 9 CRM reporting projection files have zero test coverage (`dispatch_performance_projection`, `monthly_report_projection`, `multi_site_comparison_projection`, `report_bundle_canonicalizer`, `executive_summary_generator`, `sla_tier_service`, `sla_tier_projection`, `report_bundle_assembler`)

**Blocking for demo?** Yes for items 1 and 2. A crash in report generation or fabricated PSIRA
numbers in a delivered PDF are client-visible failures.

**Estimated remaining:**
- `slaProfile!` force-unwrap fix: 0.5 days (AUTO)
- Fabricated guard PII: 1 day (REVIEW — sourcing strategy needs decision)
- Breach/compliance formula unification: 1 day (AUTO once formulas are agreed)
- Minimum test coverage (3 highest-risk projections): 1–2 days

---

### Theme Migration

**Status:** Spec exists for 5 files (`admin_page`, `governance_page`, `dispatch_page`,
`client_intelligence_reports_page`, `tactical_page`). Each file uses a private file-local "shadow
palette" of light-mode hex literals instead of `OnyxDesignTokens`. Login page was migrated to dark
tokens today. Remaining 5 screens in the batch spec are not yet implemented.

**Blocking for demo?** Partially — `Colors.white` card backgrounds on `dispatch_page` and
`tactical_page` cause visible breakage on the dark theme. The admin and governance pages are the
largest violations but may be acceptable for an internal demo.

**Estimated remaining:**
- Dispatch + tactical (`Colors.white` breakage): 1 day (AUTO once token mapping is approved)
- Admin + governance + reports: 2–3 days (AUTO, volume of substitutions)

---

### Test Suite Commit and Flakiness

**Status:** 96 untracked test files (~541 test cases) and 178 modified committed test files are not
yet committed. CI cannot see them. At least 6 widget test files use `DateTime.now()` inside test
bodies to drive relative-time assertions — these are flaky by design and will fail intermittently
near minute boundaries.

**Blocking for demo?** Not a runtime blocker, but CI is meaningless until committed. Flaky tests
mask real failures.

**Estimated remaining:**
- Commit and validate untracked files: 1–2 days (verification + fix any compile failures)
- Fix `DateTime.now()` in test bodies to fixed anchors: 1 day

---

### Authority Domain Tests

**Status:** `onyx_scope_guard_test` and `onyx_telegram_command_gateway_test` expanded today.
However `TelegramRolePolicy` and `TelegramScopeBinding` — the two files that make actual
authorization decisions — still have zero test coverage. The full `domain/authority/` module (8
files: `authority_token.dart`, `onyx_authority_scope.dart`, `operator_context.dart`,
`telegram_role_policy.dart`, `telegram_scope_binding.dart`, plus 3 contract files) was introduced
today with no corresponding tests.

**Blocking for demo?** Low risk for a supervised demo. Would be blocking for any production use
with real operators making Telegram commands.

**Estimated remaining:** 1 day (REVIEW — Zaks to confirm which authority files contain decision
logic vs. pure data contracts. Decision logic must be tested before this module ships.)

---

### `domain/authority/` Module: AuthorityToken and OperatorContext Not Wired

**Status:** `AuthorityToken` is defined (2 fields: `authorizedBy`, `timestamp`) but imported
nowhere in the live authorization path. No expiry, no revocation. `OperatorContext.canExecute()`
exists in `app_state.dart` but is not checked by `OnyxScopeGuard` or `OnyxTelegramCommandGateway`.
The `propose` and `execute` actions exist in the role policy but no Telegram command requires them
— a supervisor can do everything an admin can do.

**Blocking for demo?** No visible impact in a supervised demo. Would silently fail to enforce
privilege boundaries if a real hostile operator sent Telegram commands.

**Estimated remaining:** DECISION required — Zaks must decide whether to wire the token lifecycle
now or document it as scaffolding. If scaffolding, add a `// TODO(authority): not yet wired`
comment. If active, implementation is 1–2 days.

---

## 3. Still Needed Before First Real Client Demo

Items in this section will produce incorrect, embarrassing, or broken behavior visible to a client
during a live demo.

### BLOCKING — Must Fix

---

#### DEMO-1: Tactical Map Is Entirely Stub Data

**What the client will see:** A tactical map showing `Echo-3`, `Alpha-1`, `Vehicle R-12`, a `Sandton North` site marker, and `INC-8829-QX` — the same hardcoded positions on every launch, with no relationship to any live guard, site, or incident.

**Current state:**
- No Google Maps API key configured
- No Flutter map package installed (`google_maps_flutter`, `flutter_map`, etc. are absent from `pubspec.yaml`)
- All `_markers`, `_geofences`, `_anomalies` in `lib/ui/tactical_page.dart:327–418` are hardcoded normalized-coordinate stubs
- Guard telemetry coordinates exist in `GuardLocationHeartbeat` (lat/lng fields) and site coordinates in `AdminDirectorySiteRow` — neither is wired to the map

**What needs to happen:**
1. **DECISION** (1–2 hours): Choose map package — `google_maps_flutter` (requires API key + billing) or `flutter_map` (OpenStreetMap, free)
2. Add the chosen package to `pubspec.yaml`
3. Wire guard coordinate stream from `GuardLocationHeartbeat` events into map markers
4. Wire site coordinates from `AdminDirectorySiteRow` into site markers
5. Replace hardcoded `_markers` / `_geofences` / `_anomalies` with live data or empty state when data is absent

**Estimated remaining:** 3–5 days after decision is made
**Action label:** DECISION then REVIEW

---

#### DEMO-2: Camera Vendor Workers Return Hardcoded Success

**What the client will see:** Operator approves a camera change. The UI shows a green receipt. The physical camera is unchanged. When the client checks the DVR interface, nothing happened.

**Current state:**
- All five vendor workers (Hikvision, Dahua, Axis, Uniview, Generic ONVIF) return `success: true` with no network call
- `OnyxAgentCameraExecutionPacket.credentialHandling` is a plain-text operator note, not a `DvrHttpAuthConfig`
- Hikvision digest auth infrastructure exists in `LocalHikvisionDvrProxyService`; it is not wired into the camera worker
- CCTV probes fail silently on 401 because no auth is injected

**What needs to happen:**
1. **DECISION** (1–2 hours): Choose credential carrier design — credentials injected into worker at construction, or carried in the execution packet
2. Wire `DvrHttpAuthConfig` into `HikvisionOnyxAgentCameraWorker`
3. Replace stub worker body with real ISAPI calls: `GET /deviceInfo`, `GET /channels`, `PUT /channels/{id}`, `GET /channels/{id}` (verify after write)
4. Add visible UI notice that intent-only mode is active until real device write is confirmed
5. Add `success: false` on non-2xx or verify-read mismatch

**Estimated remaining:** 3–5 days after credential decision
**Action label:** DECISION then REVIEW

---

#### DEMO-3: CRM Report Crash and Fabricated PII (see In Progress above)

**What the client will see:** Either a crash when viewing any client whose CRM event stream has a reordered or incomplete SLA profile, or a PDF showing `Guard 42` and `PSIRA-42` as legitimate guard records.

**Estimated remaining:** 2–3 days total (partial AUTO + one REVIEW decision)
**Action label:** AUTO for crash fix; REVIEW for PII sourcing

---

### IMPORTANT — Visible but Not Immediately Crashing

---

#### DEMO-4: Governance Fleet and Vigilance Surfaces Need Verification

**Status unclear:** The Codex governance P1 summary states the hardcoded `_buildCompliance`,
`_buildVigilance`, and `_FleetStatus` seed values were removed and replaced with live feeds. The v2
audit was written before that fix landed. **Codex should verify live that `lib/ui/governance_page.dart:907–914`, `:13084`, and `:13113` no longer contain hardcoded stub objects**, and that the `Pending live feed` path shows correctly when no data is available from a fresh demo environment.

If any stub block survived the governance P1 batch, it must be cleaned before demo.

**Estimated remaining:** 0.5 days verification + cleanup if stubs survive
**Action label:** AUTO (verification)

---

#### DEMO-5: Dark Theme Visual Breakage on Dispatch and Tactical Pages

`dispatch_page.dart` uses `Colors.white` directly on card backgrounds. `tactical_page.dart` uses
`Colors.white` at lines 1366 and 1597. Both cause visible white-box rendering artifacts on the dark
theme shell that clients will immediately notice.

**Estimated remaining:** 1 day (AUTO — substitute `OnyxColorTokens.card` / `OnyxColorTokens.surface`)
**Action label:** AUTO

---

#### DEMO-6: Governance Page Performance

`_visibleGovernanceEvents()` and several baseline-stat methods are called repeatedly per build (O(N × builds)). On a live demo environment with real event history, the governance surface may stutter noticeably. No caching is in place.

**Estimated remaining:** 1 day (AUTO — cache result in `didUpdateWidget`)
**Action label:** AUTO

---

#### DEMO-7: `dispatch_models.dart` in Wrong Layer

Six pure domain/application model classes (`IntakeStressProfile`, `IntakeTelemetry`,
`DispatchSnapshot`, etc.) live in `lib/ui/dispatch_models.dart`. This prevents any future
application-layer service from importing them without a circular dependency. Not a runtime demo
blocker but creates import confusion during a live coding walkthrough.

**Estimated remaining:** 0.5 days (AUTO — move to `lib/application/dispatch_models.dart`)
**Action label:** AUTO

---

### DEFERRED — Not Needed for First Demo

The following items are confirmed future work. None will cause visible failures in a first real
client demo. They should be entered into the backlog.

| Item | Why Deferred | When to Revisit |
|---|---|---|
| SIA DC-09 alarm receiver | Research phase; no panel available for demo | Phase 1 of alarm receiver roadmap |
| ONYX-BI full product layer | Hold until core security platform is launch-ready | After first client contract signed |
| DispatchPersistenceService → Drift migration | SharedPreferences is stable; migration is a 7-phase project requiring Phase 0 decision first | Before production scale beyond first client |
| Admin page full god-object decomposition | Functional as-is; structural debt, not runtime failure | Ongoing, can be done incrementally |
| PSIRA evidence multi-writer atomic constraint | Single writer is safe for demo; DB advisory lock or `ON CONFLICT` needs schema decision | Before multi-operator concurrent sealing |
| Authority domain `AuthorityToken` / `OperatorContext` wiring | Not active in any gate today; won't affect demo authorization | Before Telegram-based privilege escalation is needed |
| `dispatch_models.dart` move to application layer | Import confusion but no demo runtime failure | Before adding new application-layer dispatch services |
| Remaining export/clipboard centralization | `ExportCoordinator` partially in place; `client_app_page` and `dashboard_page` not yet migrated | Ongoing cleanup after demo |
| Evidence Return Receipt consolidation | 6 separate receipt classes across 6 page files; functional but creates cross-page coupling | Ongoing cleanup |
| God-class extraction for `guard_mobile_shell_page`, `client_app_page`, `events_review_page` | All functional; 193 setState calls in guard shell is a stability watch item | Incrementally after demo |
| Full domain layer test coverage (currently 21%) | Only authorization decision logic is urgently needed; entity model tests can wait | After Zaks confirms domain coverage strategy |

---

## 4. Estimated Days Remaining per Demo-Blocking Item

| # | Item | Days | Blocked On | Action |
|---|---|---|---|---|
| DEMO-1 | Tactical map live data | 3–5 | Map package DECISION (1–2 hrs) | DECISION → REVIEW |
| DEMO-2 | Camera workers real ONVIF calls | 3–5 | Credential carrier DECISION (1–2 hrs) | DECISION → REVIEW |
| DEMO-3 | CRM report crash + fabricated PII | 2–3 | Guard PII source REVIEW | AUTO + REVIEW |
| DEMO-4 | Governance stub verification | 0.5 | None — verification only | AUTO |
| DEMO-5 | Dark theme `Colors.white` breakage | 1 | None | AUTO |
| DEMO-6 | Governance page performance | 1 | None | AUTO |
| DEMO-7 | `dispatch_models.dart` layer move | 0.5 | None | AUTO |
| — | CRM reporting minimum test coverage | 1–2 | None | AUTO |
| — | Test suite commit + flakiness fixes | 1–2 | None | AUTO |
| — | Governance stub survival verification | 0.5 | None | AUTO |

**Total estimated remaining (no decisions blocking): ~8–12 days of Codex work**

**Zaks decisions needed first (total decision time: ~1 day):**
1. Tactical map package choice (Google Maps vs. flutter_map)
2. Camera worker credential carrier design
3. Fabricated guard PII sourcing strategy for CRM reports (use real guard domain model or output `unknown`/`unresolved`)

---

## 5. Overall Assessment

The platform is materially further along than its git HEAD suggests. 96 uncommitted test files and
121 uncommitted lib files represent a significant session of work that is not yet visible to CI or
code review.

**What is demo-safe today:**
- Evidence ledger (sealing, idempotency, durability, hash verification)
- SLA engine (clock, breach evaluation, retroactive breach, drift tolerance)
- Dispatch application service (sequence, IDs, ordering, state machine)
- Governance page (live compliance/vigilance/fleet feeds replacing stubs)
- AI queue, clients, guards, events review, dispatch page (major UI race conditions resolved)
- Agent brain (cloud/local failure signals surface to operators)
- Reports workspace agent Phase 1 (Claude narrative injection)
- BI vehicle dashboard panel and carwash fixture
- Login security (credentials gated, passwords hidden)
- Bridge/DVR reconnect state and JSON hardening

**What will visibly fail in front of a client:**
1. Tactical map shows static fictional markers
2. Camera changes show green receipt but do nothing to the camera
3. CRM reports may crash or show fabricated guard names
4. Dispatch and tactical pages render white boxes on the dark theme

**Recommended focus order before demo:**
1. Make the three DECISION calls (map package, credential carrier, guard PII) — 1 day, Zaks only
2. Fix CRM crash (`slaProfile!`) and fabricated PII — 2–3 days, Codex
3. Fix dark theme `Colors.white` breakage — 1 day, Codex
4. Wire tactical map (at minimum: site markers from live site coordinates) — 3 days, Codex
5. Commit all working-tree changes and validate CI — 1 day, Codex
6. Camera workers: ONVIF wire-up for Hikvision (most common demo hardware) — 3 days, Codex
