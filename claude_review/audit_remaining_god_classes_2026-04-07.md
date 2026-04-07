# Audit: Remaining God Classes — lib/ui/ (Unaudited Files)

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: All `lib/ui/*.dart` files over 500 lines with no audit report dated 2026-04-07
- Read-only: yes

---

## Executive Summary

22 files in `/lib/ui/` exceed 500 lines and have not been individually audited today.
The top 8 files alone total **62,093 lines** and every one of them is a structural god class mixing UI layout, state management, domain logic, export orchestration, and in two cases infrastructure access.
The problem is systemic: the pattern from `admin_page.dart`, `live_operations_page.dart`, and `governance_page.dart` repeats across the entire page layer with no sign of extraction discipline.

Files already audited today and excluded from this report:
`admin_page.dart`, `live_operations_page.dart`, `governance_page.dart`, `onyx_agent_page.dart`, `app_shell.dart`, `vip_protection_page.dart`, `controller_login_page.dart`.

---

## Already-Audited File Sizes (Context)

| File | Lines |
|---|---|
| admin_page.dart | 45,148 |
| live_operations_page.dart | 18,671 |
| governance_page.dart | 14,774 |
| onyx_agent_page.dart | 11,361 |
| app_shell.dart | 1,684 |
| vip_protection_page.dart | 1,191 |

---

## Unaudited Files — Triage Table

| Priority | File | Lines | Classes | Key Violations |
|---|---|---|---|---|
| P1 | client_intelligence_reports_page.dart | 11,306 | 10 | Report orchestration + export formatting + clipboard I/O + history comparison all in state class |
| P1 | client_app_page.dart | 10,950 | 18 | Messaging UI + push queue + AI assist + backend probe + voice profile + notification building |
| P1 | dispatch_page.dart | 8,264 | 15 | Dispatch command UI + partner trend analysis + suppressed review + CCTV fleet health |
| P1 | events_review_page.dart | 7,724 | 20 | Event timeline + shadow MO analysis + synthetic promotion decisions + 6 CSV/JSON export methods |
| P1 | tactical_page.dart | 7,063 | 13 | Map UI + geofence/marker domain models + CCTV lens telemetry + custom canvas painters |
| P1 | guard_mobile_shell_page.dart | 6,839 | 2 | Single 6,500-line state class — guard ops event processing + coaching policy + stream loops |
| P1 | ai_queue_page.dart | 5,844 | 10 | AI queue view + CCTV board alert models + monitoring posture + autonomy orchestration |
| P1 | dashboard_page.dart | 5,543 | 29 | Dashboard layout + triage compute + lane filtering + export panel + email bridge + clipboard |
| P2 | clients_page.dart | 4,313 | 9 | Client list + messaging composer + evidence receipt tracking + live follow-up notices |
| P2 | events_page.dart | 4,033 | 5 | Events timeline + forensic evidence + CRM report config + integrity certificate preview widget |
| P2 | sovereign_ledger_page.dart | 3,975 | 8 | Ledger display + **sha256 hashing in page layer** + audit entry management |
| P2 | guards_page.dart | 3,634 | 9 | Guard list + shift/roster/calendar models embedded in UI file |
| P2 | sites_command_page.dart | 2,828 | 7 | Sites command view + view model building + KPI computation + audit receipts |
| P2 | ledger_page.dart | 2,769 | 4 | **Direct `Supabase.instance.client` in UI layer** (line 83) + ledger timeline |
| P2 | track_overview_board.dart | 2,764 | 15 | Overview board + custom map canvas painters + site/guard/camera/incident summary models |
| P2 | sites_page.dart | 2,669 | 4 | Sites list + health projection computation + drill scenario models |
| P3 | risk_intelligence_page.dart | 1,380 | 13 | Relatively clean decomposition; audit receipt + intel panels — model classes in UI layer only |
| P3 | dispatch_models.dart | 1,045 | 6 | **Pure domain/application models in `/lib/ui/`** — wrong layer entirely |
| P3 | onyx_surface.dart | 838 | 10 | Shared UI primitives — acceptable; `OnyxStoryMetric` data model embedded |
| P3 | client_comms_queue_board.dart | 768 | 3 | `ClientCommsQueueItem` model embedded in widget file |
| P4 | video_fleet_scope_health_sections.dart | 548 | 0 | Compositional builder — likely acceptable |
| P4 | onyx_route_command_center_builders.dart | 538 | 0 | Route builder — likely acceptable |

---

## Findings

### P1 — `client_intelligence_reports_page.dart` (11,306 lines)

- **Action: REVIEW**
- Single `_ClientIntelligenceReportsPageState` class owns the entire lifecycle from line 129 to ~11,140.
- **Responsibilities mixed:** report generation request orchestration, report preview lifecycle, receipt history lookup, partner comparison window logic, scene filter management, JSON/CSV export payload assembly, clipboard I/O (15 occurrences), evidence return receipts, `ReportsEvidenceReturnReceipt` handoff class defined in the UI file.
- **Why it matters:** Any change to export format, receipt history, or report generation requires editing an 11K-line state class, making regression risk very high.
- **Evidence:** Lines 99–128 (command receipt + evidence return receipt classes). Line 129 (state class). `_ReceiptRow`, `_PartnerComparisonRow`, `_ReceiptInvestigationHistorySummary` at lines 11,145–11,249 are data structures that belong in the application layer.
- **Suggested follow-up for Codex:** Validate whether `_ClientIntelligenceReportsPageState` contains any business logic that duplicates `ReportGenerationService` or `ReportReceiptHistoryLookup`.

---

### P1 — `client_app_page.dart` (10,950 lines)

- **Action: REVIEW**
- 18 top-level classes. State class at line 251 runs to approximately line 7,800.
- **Responsibilities mixed:** UI layout for messaging lanes, push queue building (`_buildPushQueue`, line 7,717), push queue merging with acknowledgements (`_mergeStoredPushQueueWithAcknowledgements`, line 7,747), AI assist orchestration (`_aiAssistClientMessage`, line 6,381), backend probe execution (`_retryPushSyncSafely`, line 3,250; `_runBackendProbeSafely`, line 3,271), voice profile management (`_setLaneVoiceProfile`, line 5,785), notification building (`_buildNotifications`, line 7,637), incident feed grouping (`_buildIncidentFeed`, line 7,808), room/role selection maps, composer state.
- **Why it matters:** Backend probe and push queue merge logic are application-layer concerns running inside a StatefulWidget. Any Supabase contract change requires editing the page directly.
- **Evidence:** Lines 3,250–3,271 (async backend probe in widget state). Lines 7,637–7,808 (notification and feed builders). `ClientAppComposerPrefill` (line 60) and `ClientAppEvidenceReturnReceipt` (line 83) are cross-page handoff contracts defined in the page file.
- **Suggested follow-up for Codex:** Check whether `_buildPushQueue` + `_mergeStoredPushQueueWithAcknowledgements` duplicate logic from `ClientMessagingBridgeRepository` or `ClientCommsDeliveryPolicyService`.

---

### P1 — `dispatch_page.dart` (8,264 lines)

- **Action: REVIEW**
- 15 top-level classes. Main state class starts at line 466 and runs ~7,600 lines.
- **Responsibilities mixed:** Dispatch command surface, partner dispatch progress tracking (`_PartnerDispatchProgressSummary`, line 105), partner trend computation (`_PartnerTrendSummary`, line 127), suppressed dispatch review (`_SuppressedDispatchReviewEntry`, line 95), auto audit receipt (`DispatchAutoAuditReceipt`, line 155), evidence return receipt (`DispatchEvidenceReturnReceipt`, line 171), CCTV/video fleet health sections (imports `video_fleet_scope_health_*`), morning sovereign report access, monitoring scene review store access.
- **Why it matters:** The page directly imports infrastructure intelligence (`news_intelligence_service.dart`) — a layer violation. Partner trend/progress classes belong in application or domain.
- **Evidence:** Line 13 imports `../infrastructure/intelligence/news_intelligence_service.dart`. Classes `DispatchAutoAuditReceipt` (line 155) and `DispatchEvidenceReturnReceipt` (line 171) are cross-page contract objects defined inside the page file.
- **Suggested follow-up for Codex:** Confirm whether `_PartnerTrendSummary` duplicates any projection logic in `DispatchPersistenceService` or `DispatchApplicationService`.

---

### P1 — `events_review_page.dart` (7,724 lines)

- **Action: REVIEW**
- 20 top-level classes. State class at line 102 runs ~6,900 lines.
- **Responsibilities mixed:** Event timeline display, AI decision filter state, shadow MO dossier logic (`_shadowMoSitesForReport`, line 3,324), synthetic promotion decisions (`_acceptSyntheticPromotion`, line 6,604; `_rejectSyntheticPromotion`, line 6,619), tomorrow posture draft building (`_tomorrowPostureDraftsForReport`, line 3,883), 6 distinct CSV export methods (lines 5,895–6,287) and 5 JSON payload builder methods (lines 6,298–6,509), identity policy filtering, monitoring orchestrator imports.
- **Why it matters:** Synthetic promotion decisions (`_acceptSyntheticPromotion` / `_rejectSyntheticPromotion`) mutate application state from within a widget state method — this is a domain decision being made in the UI layer. The 6 CSV builders generate formatted export strings inline; if any format changes, the page must be edited.
- **Evidence:** Lines 6,604–6,628 (promotion decision methods with `setState` coupling). Lines 5,895–6,186 (CSV builders). Lines 6,298–6,509 (JSON payload builders). Import of `MonitoringOrchestratorService` and `MoPromotionDecisionStore` directly in the UI file.
- **Suggested follow-up for Codex:** Validate whether `_acceptSyntheticPromotion` / `_rejectSyntheticPromotion` call through to `MoPromotionDecisionStore` or perform the state mutation themselves.

---

### P1 — `tactical_page.dart` (7,063 lines)

- **Action: REVIEW**
- 13 top-level classes. Outer host widget at line 170; main page at line 257.
- **Responsibilities mixed:** Tactical map display, custom canvas painters (`_GridBackdropPainter` line 7,024; `_RouteOverlayPainter` line 7,046), geofence domain models (`_SafetyGeofence`, line 72), CCTV lens anomaly detection models (`_LensAnomaly`, line 88; `_CctvLensTelemetry`, line 108), map marker domain models (`_MapMarker`, line 46), video fleet scope health (imports all 4 health view files), monitoring scene review store.
- **Why it matters:** `_CctvLensTelemetry` and `_LensAnomaly` are sensor/domain models embedded inside a UI file. The map geofence (`_SafetyGeofence`) is a domain safety concept living in the page.
- **Evidence:** Lines 46–140 — all four pre-page classes are domain/application models. Lines 7,024–7,063 — canvas painters are reusable visual components that should be standalone.
- **Suggested follow-up for Codex:** Verify whether `_CctvLensTelemetry` and `_LensAnomaly` duplicate anything in `cctv_bridge_service.dart` or `cctv_evidence_probe_service.dart`.

---

### P1 — `guard_mobile_shell_page.dart` (6,839 lines)

- **Action: REVIEW**
- Only 2 top-level classes. State class at line 316 runs ~6,520 lines. 193 `setState`/async/stream operations.
- **Responsibilities mixed:** Guard mobile UI shell, guard ops event processing (domain imports from `guard_ops_event.dart`, `guard_mobile_ops.dart`), outcome label governance (`outcome_label_governance.dart`), coaching policy (`guard_sync_coaching_policy.dart`), timer/stream lifecycle management, serialization (`dart:convert`).
- **Why it matters:** This is the most extreme single-class concentration in the non-admin portion of the codebase. 193 async/state mutations in a single state class is a high regression risk surface. Domain governance and coaching policy are being applied directly in the widget.
- **Evidence:** Lines 53–315 (all pre-state setup). Line 316 (`_GuardMobileShellPageState`). Domain imports at lines 7–10. `dart:convert` import for inline serialization.
- **Suggested follow-up for Codex:** Determine what fraction of the 6,520-line state class is widget build methods vs. event processing logic. If >30% is non-build logic, extraction into a coordinator is warranted.

---

### P1 — `ai_queue_page.dart` (5,844 lines)

- **Action: REVIEW**
- 10 top-level classes. State at line 201.
- **Responsibilities mixed:** AI queue display, CCTV board alert models (`_CctvBoardAlert`, line 124; `_CctvBoardFeed`, line 146), daily stats computation (`_AiQueueDailyStats`, line 80), evidence return receipt (`AiQueueEvidenceReturnReceipt`, line 108), monitoring global posture access, monitoring watch autonomy service, shadow MO dossier access, serialization.
- **Why it matters:** `_CctvBoardAlert` and `_CctvBoardFeed` are domain-level alert models living in a UI page. Daily stats computation (`_AiQueueDailyStats`) belongs in the application layer.
- **Evidence:** Lines 80–160 — pre-page model classes. Import of `MonitoringWatchAutonomyService` directly in the UI file.
- **Suggested follow-up for Codex:** Check whether `_AiQueueDailyStats` duplicates any stats available from `MonitoringGlobalPostureService`.

---

### P1 — `dashboard_page.dart` (5,543 lines)

- **Action: REVIEW**
- 29 top-level classes — highest class count in the non-admin portion of the codebase.
- **Responsibilities mixed:** Dashboard layout orchestration, signal/dispatch/site lane filtering (`_filteredSignalItems`, `_filteredDispatchItems`, `_filteredSiteItems`, lines 1,621–1,681), triage summary computation (`_DashboardTriageSummary`, line 236), report receipt policy trend analysis (lines 3,308–3,412), site activity history date computation (line 3,538), export panel with clipboard/download/email (`_DashboardAdvancedExportPanelState`, line 4,602), email bridge integration, snapshot file download, `_guardFailureTraceClipboard` (line 3,111), `_ThreatState` model (line 5,516).
- **Why it matters:** The dashboard is the entry point for operators. Triage computation, receipt policy trends, and guard failure trace formatting are analytics tasks that belong in the application layer — they inflate the rebuild surface and make the dashboard harder to test.
- **Evidence:** Lines 1,621–1,681 (three filter methods with sorting logic). Lines 3,308–3,455 (receipt policy trend and site activity series builders). Lines 4,627–4,692 (file download + clipboard + mail bridge calls in widget state). Line 5,516 (`_ThreatState` domain model inside a widget file).
- **Suggested follow-up for Codex:** Confirm whether filter/sort methods in `_DashboardOperationsWorkspaceState` duplicate any projection in `OperationsHealthProjection`.

---

### P2 — `sovereign_ledger_page.dart` (3,975 lines) — Crypto in UI Layer

- **Action: REVIEW**
- **Critical finding:** `package:crypto/crypto.dart` imported at line 3. `sha256` hash computation performed at lines 2,747 and 3,285 directly inside the page state.
- This is the only page outside `ledger_page.dart` that performs cryptographic operations inline. Integrity hash generation is an application/domain concern.
- **Why it matters:** Cryptographic operations in a widget state class cannot be independently tested. If the hash algorithm or input structure changes, both UI tests and hash-validity tests must change together.
- **Evidence:** Lines 2,747 and 3,285 — `sha256` calls inside `_SovereignLedgerPageState`.
- **Suggested follow-up for Codex:** Determine whether these hashes are also computed in `EvidenceCertificateExportService` or any other service — if so this is a duplication risk.

---

### P2 — `ledger_page.dart` (2,769 lines) — Direct Supabase Instantiation

- **Action: AUTO**
- **Layer violation:** `SupabaseClientLedgerRepository(Supabase.instance.client)` constructed at line 83 directly inside a StatefulWidget.
- This is the only confirmed direct `Supabase.instance.client` call in the `/lib/ui/` layer (all other pages delegate to application services).
- **Why it matters:** Repository construction belongs in the infrastructure/DI layer. If the Supabase client changes or auth tokens need injection, this page is a hidden dependency.
- **Evidence:** `lib/ui/ledger_page.dart:83` — `SupabaseClientLedgerRepository(Supabase.instance.client)`.
- **Suggested follow-up for Codex:** Replace with a passed-in repository abstraction. Confirm `ClientLedgerRepository` interface exists in `lib/domain/evidence/client_ledger_repository.dart` (it does — already imported on the same page).

---

### P2 — `dispatch_models.dart` (1,045 lines) — Domain Models in UI Layer

- **Action: AUTO**
- File lives at `lib/ui/dispatch_models.dart` but contains 6 pure domain/application model classes: `IntakeStressProfile`, `IntakeTelemetry`, `IntakeRunSummary`, `DispatchProfileDraft`, `DispatchBenchmarkFilterPreset`, `DispatchSnapshot`.
- 35 `toJson`/`fromJson`/`Map<String` serialization usages confirm these are data transfer objects.
- **Why it matters:** Domain models in the UI layer cannot be imported by application or domain files without introducing circular dependencies. Any future application-layer service that needs `DispatchSnapshot` must either duplicate it or import from UI — both are wrong.
- **Evidence:** `lib/ui/dispatch_models.dart` — entire file. Classes `IntakeStressProfile` (line 78), `IntakeTelemetry` (line 217), `IntakeRunSummary` (line 590), `DispatchProfileDraft` (line 809), `DispatchBenchmarkFilterPreset` (line 892), `DispatchSnapshot` (line 955).
- **Suggested follow-up for Codex:** Move to `lib/application/dispatch_models.dart` or `lib/domain/dispatch/dispatch_models.dart` and update all import paths.

---

### P2 — `track_overview_board.dart` (2,764 lines) — Embedded Canvas Painters + Summary Models

- **Action: REVIEW**
- 15 top-level classes, 8 of which are custom visual map primitives (`_TrackMapPin`, `_TrackMapDot`, `_TrackMapStar`, `_TrackMapRangeRing`, `_TrackMapLink`, painters).
- `_TrackSiteSummary`, `_TrackGuardSummary`, `_TrackCameraSummary`, `_TrackIncidentSummary` (lines 32–93) are domain-level snapshot models.
- State class at line 345 manages live board updates.
- **Why it matters:** Map visual primitives are reusable across tactical and overview contexts but are locked inside this file. Summary models belong in the application layer.
- **Evidence:** Lines 32–93 (4 summary model classes). Lines 2,294–2,764 (8 standalone visual component classes and 2 painters).

---

### P2 — `guards_page.dart` (3,634 lines) — Roster Domain Models in UI

- **Action: REVIEW**
- `_GuardRecord` (line 29), `_ShiftBlock` (line 75), `_ShiftRosterRow` (line 91), `_ShiftHistoryRow` (line 107), `_RosterCalendarAssignment` (line 139), `_RosterCalendarDay` (line 157) — 6 domain-level workforce models embedded in the UI file.
- `GuardsEvidenceReturnReceipt` (line 175) is a cross-page handoff contract also defined in the page.
- **Why it matters:** Roster/shift domain models are needed by scheduling and reporting logic but are stranded in the UI layer.

---

### P2 — `sites_page.dart` (2,669 lines) — Health Projection Computation in Widget

- **Action: REVIEW**
- Imports `OperationsHealthProjection` from domain layer and performs projection logic inside `_SitesPageState`.
- `_SiteAccumulator` (line 2,602) and `_SiteDrillSnapshot` (line 2,623) are application-layer models in the UI file.
- **Why it matters:** Site health accumulation should be computed in the application layer and passed as read-only state; computing it in the page ties the projection lifecycle to widget rebuilds.

---

### P3 — `events_page.dart` (4,033 lines) — CRM Config in UI

- **Action: REVIEW**
- Imports `ReportSectionConfiguration` from `lib/domain/crm/reporting/` and `EvidenceProvenance` from `lib/domain/evidence/` directly into the UI page.
- `IntegrityCertificatePreviewCard` (line 3,687) is a reusable display widget embedded in the page file.
- **Why it matters:** `IntegrityCertificatePreviewCard` is referenced from evidence certificate export flows — if it's buried in `events_page.dart`, it cannot be reused without importing the entire page.

---

### P3 — `clients_page.dart` (4,313 lines)

- **Action: REVIEW**
- `ClientsAgentDraftHandoff` (line 16), `ClientsEvidenceReturnReceipt` (line 47), `ClientsLiveFollowUpNotice` (line 63) are three application-layer handoff contracts defined in the page file.
- These are passed across page boundaries (`ClientsPage` → `ClientAppPage`) which means consuming pages import the entire `clients_page.dart` for a small contract class.
- **Why it matters:** Cross-page contract objects embedded in page files create hidden coupling — changing `clients_page.dart` forces recompilation of `client_app_page.dart`.

---

## Duplication

### Export/Clipboard Pattern
Every major page (dashboard, events_review, dispatch, client_intelligence_reports, client_app) independently implements:
- `_copy*Json(...)` methods calling `Clipboard.setData(ClipboardData(text: jsonEncode(...)))`
- `_copy*Csv(...)` methods assembling CSV strings inline
- `_download*File(...)` methods via `DispatchSnapshotFileService`

This is at least 30+ duplicated clipboard/export methods across 5 files. A shared `ExportCoordinator` or `ClipboardExportService` does not appear to exist in the application layer.

**Files involved:** `events_review_page.dart`, `dashboard_page.dart`, `client_intelligence_reports_page.dart`, `dispatch_page.dart`, `client_app_page.dart`.
**Centralization candidate:** `lib/application/export_coordinator.dart` or extend existing `EvidenceCertificateExportService`.

### Evidence Return Receipt Pattern
`DispatchEvidenceReturnReceipt`, `AiQueueEvidenceReturnReceipt`, `ReportsEvidenceReturnReceipt`, `ClientAppEvidenceReturnReceipt`, `GuardsEvidenceReturnReceipt`, `ClientsEvidenceReturnReceipt` are all defined inside their respective page files.

These are handoff contracts used for cross-page data passing. They are structurally identical in purpose but defined in 6 different files, making them impossible to use without importing the full page.

**Centralization candidate:** `lib/application/evidence_return_receipts.dart` — collect all receipt types.

### Auto Audit Receipt Pattern
`DispatchAutoAuditReceipt` (dispatch_page.dart), `SitesAutoAuditReceipt` (sites_command_page.dart), `RiskIntelAutoAuditReceipt` (risk_intelligence_page.dart) follow the same structure — audit confirmation objects defined in page files.

---

## Coverage Gaps

- No tests observed for the 6 CSV export builder methods in `events_review_page.dart` — these are complex format transformations with no coverage.
- `_DashboardTriageSummary` computation (dashboard_page.dart, line 236) has no corresponding unit test observable from the test structure — triage logic is buried in widget state.
- `sovereign_ledger_page.dart` sha256 operations are untestable in isolation.
- `dispatch_models.dart` domain models likely have no tests since the file is in `/lib/ui/` and test coverage of UI-layer model files is typically absent.
- `ledger_page.dart` direct Supabase instantiation makes the `LedgerPage` non-injectable and therefore untestable with mocked repositories.

---

## Performance / Stability Notes

- **`guard_mobile_shell_page.dart`** — 193 setState/async/stream operations in a single state class is a high rebuild-surface risk. Any stream event that triggers setState will rebuild the entire 6,839-line page.
- **`client_app_page.dart`** — Delayed futures used for composer highlight animations (lines 6,529, 6,546, 6,605) using `Future<void>.delayed` without cancellation guards — if the widget is disposed before the delay completes, `setState` is called on a dead widget.
- **`events_review_page.dart`** — 20 top-level classes and 6 export methods suggest the build method for this page is extremely large; without subtree caching (const constructors or RepaintBoundary), any filter change will trigger a full page rebuild.
- **`dashboard_page.dart`** — 29 classes is the highest class count outside admin_page. The `_DashboardOperationsWorkspace` holds 5 separate lane filter methods each calling `setState` — five independent filter states in one widget means filter changes can cascade rebuilds.

---

## Recommended Fix Order

1. **`ledger_page.dart:83`** — Remove direct `Supabase.instance.client` construction. Inject `ClientLedgerRepository` through the widget constructor. `AUTO` — interface already exists.

2. **`dispatch_models.dart`** — Move to `lib/application/` or `lib/domain/`. Update import paths across all pages. `AUTO` — pure rename/move, no logic change.

3. **Evidence Return Receipt consolidation** — Extract all 6 `*EvidenceReturnReceipt` classes into a shared `lib/application/evidence_return_receipts.dart`. `AUTO` — structural extraction, no logic change.

4. **Export/clipboard centralization** — Extract shared clipboard/CSV/JSON export logic from the 5 pages into a single coordinator service. `REVIEW` — requires deciding ownership model.

5. **`sovereign_ledger_page.dart` crypto** — Move sha256 operations at lines 2,747 and 3,285 into `EvidenceCertificateExportService` or a new `LedgerIntegrityService`. `REVIEW` — need to confirm if these hashes feed downstream trust chains.

6. **`events_review_page.dart` synthetic promotion methods** — Extract `_acceptSyntheticPromotion` / `_rejectSyntheticPromotion` into `MoPromotionDecisionStore`. `REVIEW` — confirm current store interface.

7. **`guard_mobile_shell_page.dart`** — Extract event-processing and coaching-policy application logic from `_GuardMobileShellPageState` into a coordinator. `REVIEW` — 6,500-line state class warrants full audit before extraction.

8. **`client_app_page.dart` push queue + backend probe** — Extract `_buildPushQueue`, `_mergeStoredPushQueueWithAcknowledgements`, `_retryPushSyncSafely`, `_runBackendProbeSafely` into `ClientMessagingBridgeRepository` or a new `ClientAppCoordinator`. `REVIEW`.

9. **`dashboard_page.dart` triage + filter methods** — Extract `_DashboardTriageSummary` and the 3 filter methods into a `DashboardPostureCoordinator`. `REVIEW`.

10. **`track_overview_board.dart` map primitives** — Extract 8 map visual components into a shared `lib/ui/track_map/` widget library. `AUTO` — pure widget extraction.
