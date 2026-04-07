# Audit: Reports Workspace Agent — Build Plan

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: All report-related files in `lib/` — application, domain, presentation, UI layers
- Read-only: yes

---

## Executive Summary

The reports subsystem is structurally solid and event-sourced end-to-end. `ReportGenerationService`, `ReportBundleAssembler`, `ReportBundleCanonicalizer`, and `PDFReportExporter` form a coherent deterministic pipeline. Receipt hashing with SHA-256 and replay verification are implemented correctly.

However, **no Claude API integration exists anywhere in the codebase**. All "AI" content (`ExecutiveSummaryGenerator`, `SupervisorAssessment`, `CompanyAchievementsSnapshot`, `EmergingThreatSnapshot`) is produced by hardcoded template strings and threshold rules. `ReportsPage` is a fully static widget with hardcoded status pills and no live data binding. A Reports Workspace Agent — one that calls Claude API, generates per-client narratives, and outputs to the Reports screen — does not exist in any form.

Eight distinct gaps must be filled to build it.

---

## What Looks Good

- `ReportBundleAssembler.build()` already collects all the data needed as prompt input: incident events, CRM events, dispatch events, guard performance, patrol performance, scene review highlights, SLA metrics, client snapshot.
- `ReportBundle` data model is complete and strongly typed — every field a Claude prompt would need is already projected.
- `ReportBundleCanonicalizer` produces deterministic canonical JSON — this can double as the structured input payload for a Claude messages call.
- `ReportGenerationService` is a clean async coordinator with well-defined `IncidentEventsProvider` / `CRMEventsProvider` typedefs — an AI narrative step fits naturally as an additional async stage.
- `ReportGenerated` event is event-sourced and immutable — extending it to carry a `narrativeHash` field is a backward-compatible addition.
- `ReportOutputMode` already lists `excel` and `json` alongside `pdf` — the architecture anticipates multiple output paths.
- `ReportAudience` enum (`client`, `internal`) exists and maps directly to narrative tone segmentation.
- `http` package is already in `pubspec.yaml` — an Anthropic messages call can be made with it before any SDK is added.

---

## Files Inventory

### Domain — `lib/domain/crm/`

| File | Role |
|---|---|
| `reporting/report_bundle.dart` | Data container for all report sections |
| `reporting/report_bundle_assembler.dart` | Static factory; projects events into ReportBundle |
| `reporting/report_bundle_canonicalizer.dart` | Serialises bundle to canonical JSON for hashing |
| `reporting/monthly_report.dart` | Core stats value object |
| `reporting/monthly_report_projection.dart` | Projects IncidentEvents + CRMEvents → MonthlyReport |
| `reporting/executive_summary.dart` | Value object for executive summary fields |
| `reporting/executive_summary_generator.dart` | **Template-only**: threshold-based strings, no AI |
| `reporting/report_sections.dart` | Value objects: ClientSnapshot, GuardPerformanceSnapshot, PatrolPerformanceSnapshot, IncidentDetailSnapshot, SceneReviewSnapshot, SupervisorAssessment, CompanyAchievementsSnapshot, EmergingThreatSnapshot |
| `reporting/report_branding_configuration.dart` | Branding overrides value object |
| `reporting/report_section_configuration.dart` | Section toggle value object |
| `reporting/report_audience.dart` | Enum: `client`, `internal` |
| `export/pdf_report_exporter.dart` | Generates PDF bytes from ReportBundle |
| `export/plain_text_report_exporter.dart` | Plain-text export |
| `export/report_export.dart` | Export wrapper |
| `events/report_generated.dart` | Event-sourced receipt with content + PDF hashes |

### Application — `lib/application/`

| File | Role |
|---|---|
| `report_generation_service.dart` | Main async orchestrator: collects events, builds bundle, generates PDF, hashes, emits receipt |
| `morning_sovereign_report_service.dart` | Builds internal SovereignReport from shift data |
| `report_shell_state.dart` | Immutable UI state for report shell |
| `report_shell_binding.dart` | Bidirectional binding: UI state ↔ business state |
| `report_entry_context.dart` | Entry context enum (governance branding drift) |
| `report_output_mode.dart` | Enum: pdf / excel / json |
| `report_preview_surface.dart` | Enum for preview routing |
| `report_preview_request.dart` | Value object for opening a preview |
| `report_partner_comparison_window.dart` | Enum for partner scope windowing |
| `report_receipt_export_payload.dart` | Export payload for receipt sharing |
| `report_receipt_history_copy.dart` | History copy logic |
| `report_receipt_history_lookup.dart` | Receipt lookup |
| `report_receipt_history_presenter.dart` | Receipt history presentation |
| `report_receipt_scene_filter.dart` | Filter enum |
| `report_receipt_scene_review_presenter.dart` | Scene review presenter for receipt |
| `report_scene_review_snapshot_builder.dart` | Builds SceneReviewSnapshot from IntelligenceReceived events |
| `hik_connect_preflight_report_service.dart` | Preflight check for HikConnect before report run |

### Presentation — `lib/presentation/reports/`

| File | Role |
|---|---|
| `report_preview_page.dart` | Full-screen PDF viewer using `printing` package |
| `report_preview_controller.dart` | Preview controller |
| `report_preview_dock_card.dart` | Preview dock card widget |
| `report_preview_presenter.dart` | Presenter for preview state |
| `report_preview_target_banner.dart` | Banner showing current preview target |
| `report_receipt_filter_banner.dart` | Filter state banner |
| `report_receipt_filter_control.dart` | Filter toggle control widget |
| `report_scene_review_narrative_box.dart` | Box displaying AI-generated scene review narrative |
| `report_scene_review_pill_builder.dart` | Pill builder for scene review posture labels |
| `report_shell_binding_host.dart` | Widget host for shell binding lifecycle |
| `report_status_badge.dart` | Status badge widget |
| `report_meta_pill.dart` | Metadata pill widget |
| `report_test_harness.dart` | Test harness widget |

### UI — `lib/ui/` + `lib/presentation/`

| File | Role |
|---|---|
| `presentation/reports_page.dart` | **The public Reports tab** — currently a static info dashboard, hardcoded status pills, no live data |
| `ui/client_intelligence_reports_page.dart` | Full operational reports workspace tied to a selected client |

---

## What Is Missing — Gap Analysis

### Gap 1 — No Claude API / Anthropic SDK integration (CRITICAL)

**Evidence:**
- `grep anthropic pubspec.yaml` → no match.
- `grep -r "anthropic\|claude-3\|claude-4\|messages.create" lib/` → no matches.
- `executive_summary_generator.dart:21-56` — all text is produced by threshold rules.
- `report_bundle_assembler.dart:121-143` — `SupervisorAssessment`, `CompanyAchievementsSnapshot`, `EmergingThreatSnapshot` are hardcoded static strings that never change regardless of client data.

**What is missing:** An Anthropic package (`anthropic_sdk_dart` or direct HTTP calls to `api.anthropic.com/v1/messages`) and a service that drives prompt construction and response parsing.

---

### Gap 2 — No `ReportsWorkspaceAgent` service

**Evidence:** No file matching `report.*agent`, `workspace.*agent`, or `narrative.*agent` exists in `lib/application/`.

**What is missing:**
A `ReportsWorkspaceAgent` (or `ReportNarrativeAgentService`) class that:
1. Accepts a `ReportBundle` (already fully assembled) + `ReportAudience`.
2. Formats a structured prompt from bundle data.
3. Calls the Claude messages API (streaming or single-turn).
4. Parses the response into a `ClientNarrativeResult` value object.
5. Returns the narrative for injection into the bundle or PDF.

---

### Gap 3 — `ReportBundleAssembler` has no AI injection point

**Evidence:**
- `report_bundle_assembler.dart:19` — `static ReportBundle build(...)` — fully synchronous.
- `report_bundle_assembler.dart:121-143` — `SupervisorAssessment`, `CompanyAchievementsSnapshot`, `EmergingThreatSnapshot` are hardcoded. They never reflect actual client data.

**What is missing:**
An async overload or a second factory (e.g. `buildWithNarrative`) that accepts an optional `ClientNarrativeResult` and replaces the three hardcoded sections with AI-generated text. Alternatively, a post-assembly `ReportBundle.withNarrative(ClientNarrativeResult)` copyWith method.

The assembler must **not** be made to call Claude directly — the AI call belongs in the agent service layer.

---

### Gap 4 — `ExecutiveSummaryGenerator` is template-only

**Evidence:**
- `executive_summary_generator.dart:21-56` — three threshold branches cover all possible inputs. Produces identical text for any client with the same compliance rate band.

**What is missing:**
Either (a) an `ExecutiveSummaryGenerator.generateWithNarrative(MonthlyReport, ClientNarrativeResult)` that injects AI prose into the existing `ExecutiveSummary` structure, or (b) the agent agent service replaces `headline` / `performanceSummary` / `slaSummary` / `riskSummary` directly with Claude-generated text before the bundle is passed to the PDF exporter. Option (b) is cleaner — the generator stays deterministic as a fallback.

---

### Gap 5 — No `ClientNarrativeResult` domain type

**Evidence:** No file matching `client_narrative`, `narrative_result`, or `narrative_request` in `lib/domain/` or `lib/application/`.

**What is missing:**
```
// Suggested domain contract (Codex to implement):
class ClientNarrativeResult {
  final String clientId;
  final String month;
  final ReportAudience audience;
  final String executiveSummaryProse;     // replaces generated headline + paragraphs
  final String supervisorAssessmentProse; // replaces hardcoded SupervisorAssessment
  final String companyAchievementsProse;  // replaces hardcoded CompanyAchievements
  final String emergingThreatsProse;      // replaces hardcoded EmergingThreats
  final String modelId;                   // e.g. claude-sonnet-4-6
  final DateTime generatedAt;
  final int inputTokens;
  final int outputTokens;
}
```
This type provides the injection boundary between the agent service and `ReportBundleAssembler`.

---

### Gap 6 — `ReportsPage` is disconnected from all real data

**Evidence:**
- `presentation/reports_page.dart:486-510` — status pills show hardcoded `'2 Verified'`, `'1 Pending'`, `'1 Failed'` strings.
- `presentation/reports_page.dart:561-596` — overview grid shows hardcoded values `'12'`, `'89'`, `'3'`, `'Ready'`.
- `presentation/reports_page.dart:630-689` — `_showGenerateReportDialog` closes the dialog and fires a SnackBar placeholder instead of triggering `ReportGenerationService`.
- `presentation/reports_page.dart` is a `StatelessWidget` — no access to `EventStore`, `ReportGenerationService`, `ReportShellState`, or any injected provider.

**What is missing:**
1. State injection into `ReportsPage` — at minimum a `ReportShellState` and a callback to trigger generation.
2. Live count of `ReportGenerated` events from the `EventStore` to replace hardcoded pill values.
3. A real generation trigger that calls `ReportGenerationService.generatePdfReport()` (and optionally the narrative agent) from the dialog.

---

### Gap 7 — No Claude API key configuration

**Evidence:**
- `pubspec.yaml` has only `http: ^1.5.0` for HTTP.
- `onyx_agent_cloud_boost_service.dart:1-60` calls a custom backend endpoint, not the Anthropic API directly. No API key management for Anthropic exists.

**What is missing:**
A config value object (e.g. `OnyxClaudeReportConfig`) carrying:
- `apiKey` (from environment variable or secure local config, never hardcoded)
- `model` (default: `claude-sonnet-4-6`)
- `maxTokens` (default: 1024 for narrative sections)
- `timeoutSeconds`

The existing `config/onyx.local.example.json` should be extended with a `claude` block. The config loader that reads it must surface this object to the agent service.

---

### Gap 8 — No multi-client batch narrative orchestration

**Evidence:** No file matching `batch_report`, `report_batch`, `multi_client_report`, or `report_queue` in `lib/`.

**What is missing:**
A `ReportBatchNarrativeOrchestrator` (or similar) that:
1. Accepts a list of `{clientId, siteId}` pairs.
2. Iterates, calling the agent service per client with error isolation (one client failure must not abort others).
3. Tracks per-client generation state: `pending` / `generating` / `complete` / `failed`.
4. Emits progress events or a `Stream<ReportBatchProgress>` that `ReportsPage` can subscribe to.

This is the "Reports Workspace Agent" at the batch orchestration level.

---

## Prompt Engineering — What the Claude Call Should Contain

The prompt fed to Claude should be assembled from the already-projected `ReportBundle`. Suggested structure (Codex to implement):

```
System:
  You are the ONYX Intelligence Reporting Agent. 
  You write professional, concise security operations narratives for client-facing reports.
  Tone: formal, factual, no speculation. Audience: [client | internal].
  Output: structured JSON with keys: executiveSummary, supervisorAssessment, 
          companyAchievements (list), emergingThreats (list).

User:
  CLIENT: {clientSnapshot.clientName} | SITE: {clientSnapshot.siteName}
  PERIOD: {currentMonth} | SLA TIER: {clientSnapshot.slaTier}
  
  METRICS:
  - Incidents: {monthlyReport.totalIncidents}
  - Escalations: {monthlyReport.totalEscalations}
  - SLA compliance: {(slaComplianceRate * 100).toStringAsFixed(1)}%
  - SLA breaches: {monthlyReport.totalSlaBreaches}
  - Patrols completed: {patrolPerformance.completedPatrols}/{patrolPerformance.scheduledPatrols}
  - Guards on record: {guardPerformance.length}
  
  SCENE REVIEW SUMMARY:
  - Total reviews: {sceneReview.totalReviews}
  - Model-reviewed: {sceneReview.modelReviews}
  - Suppressed actions: {sceneReview.suppressedActions}
  - Escalation candidates: {sceneReview.escalationCandidates}
  - Top posture: {sceneReview.topPosture}
  
  INCIDENT HIGHLIGHTS (top 5):
  {incidentDetails.take(5).map(...)}
  
  Write the four narrative sections as JSON.
```

The response should be parsed as structured JSON, not free-form text, to guarantee injection into `ReportBundle` without regex parsing.

---

## Duplication

- `ReportShellState` and `ReportShellBinding` are structurally identical value objects with identical field sets and mirrored `copyWith` logic. They serve different lifecycle roles (state vs. binding), but the duplication is 400+ lines. A shared mixin or a single canonical state class with a binding adapter would halve this surface.
  - Files: `report_shell_state.dart`, `report_shell_binding.dart`
  - Centralization candidate: `ReportShellParams` base mixin.

- `SupervisorAssessment`, `CompanyAchievementsSnapshot`, `EmergingThreatSnapshot` are hardcoded in three separate places in `ReportBundleAssembler` (lines 121–143) and in `ReportBundleCanonicalizer` serialization (lines 146–156). Once AI generation is added, the assembler's static strings become dead code — they should be removed, not worked around.

---

## Coverage Gaps

- **Zero tests** exist for the narrative generation path (it doesn't exist yet), but once added:
  - The prompt builder must have a pure unit test asserting correct field injection from a known `ReportBundle`.
  - The Claude response parser must have a unit test for malformed JSON (the API can return partial JSON or refusals).
  - The batch orchestrator must have a test asserting that a single-client failure does not halt the batch.

- `ReportBundleAssembler` has no test asserting that `SupervisorAssessment` text changes when breach count changes — because it doesn't: the hardcoded strings are unconditional. This is both a test gap and a product bug.
  - Evidence: `report_bundle_assembler.dart:121-130` — `SupervisorAssessment` text is always `"Operational stability maintained under structured event review."` regardless of actual breach count.

- `ExecutiveSummaryGenerator` has no edge-case test for `slaComplianceRate == 0.0` (produces the third branch) or `slaComplianceRate == 1.0`.

- `ReportsPage._showGenerateReportDialog` is untested — it fires a SnackBar with no generation side-effect, so any test that checks "report was generated" would silently pass without doing anything.

---

## Performance / Stability Notes

- The Claude API call will be the dominant latency source in the generation path (~1–4 seconds). `ReportGenerationService.generatePdfReport()` is already `async`, so the narrative call fits naturally as an awaited step before `PDFReportExporter.generate()`. Do not fire it in parallel with PDF generation — the PDF depends on the narrative output.

- If the narrative call times out or returns a refusal, the assembler must fall back to the existing template strings (already implemented in `ExecutiveSummaryGenerator`), not crash the generation. The agent service must never throw on a Claude API failure — it should return a `ClientNarrativeResult?` (nullable) and the assembler treats `null` as "use template fallback."

- `morning_sovereign_report_service.dart` is 37k tokens — the largest file in the application layer. It should not be touched for this feature. Narrative generation for sovereign reports is a separate concern.

---

## Recommended Build Order

### Phase 1 — Domain contract (no Claude yet)
1. **`DECISION`** — Confirm whether to use `anthropic_sdk_dart` package or raw HTTP calls to `api.anthropic.com/v1/messages`. Raw HTTP is already available (`http: ^1.5.0`) and avoids a new dependency. Recommended: raw HTTP with structured JSON response parsing. Zaks to decide.

2. **`AUTO`** — Add `OnyxClaudeReportConfig` value object to `lib/application/` or `lib/domain/authority/`. Fields: `apiKey`, `model` (default `claude-sonnet-4-6`), `maxTokens` (default `1024`), `timeoutSeconds` (default `30`). Read from `config/onyx.local.json` under a `claude` key.

3. **`AUTO`** — Add `ClientNarrativeResult` to `lib/domain/crm/reporting/`. Fields as specified in Gap 5. Include a `ClientNarrativeResult.fallback(String clientId, String month, ReportAudience audience)` factory that mirrors current template output, so tests can use it without a live API key.

4. **`AUTO`** — Add `withNarrative(ClientNarrativeResult narrative)` method to `ReportBundle` (in `report_bundle.dart`) returning a new `ReportBundle` with the three narrative sections replaced. Keep the existing constructor unchanged.

### Phase 2 — Agent service
5. **`REVIEW`** — Implement `ReportsWorkspaceAgent` in `lib/application/reports_workspace_agent.dart`:
   - Constructor: `const ReportsWorkspaceAgent({required OnyxClaudeReportConfig config})`.
   - Method: `Future<ClientNarrativeResult?> generateNarrative({required ReportBundle bundle, required ReportAudience audience})`.
   - On HTTP error or parse failure: log, return `null` (let caller fall back to templates).
   - Prompt structure: as specified in the Prompt Engineering section above.
   - Response parsing: `jsonDecode` the Claude output; if `json['executiveSummary']` is absent, return `null`.
   - Unit-testable with a fake HTTP client.

6. **`AUTO`** — Update `ReportGenerationService.generatePdfReport()` to accept an optional `ReportsWorkspaceAgent? narrativeAgent` and an optional `ReportAudience audience`. If agent is non-null, call it after `ReportBundleAssembler.build()` and before `PDFReportExporter.generate()`. Apply `bundle.withNarrative(result)` if result is non-null.

### Phase 3 — Batch orchestration
7. **`REVIEW`** — Implement `ReportBatchOrchestrator` in `lib/application/report_batch_orchestrator.dart`. Stream-based progress: `Stream<ReportBatchProgress>` where `ReportBatchProgress` carries `{clientId, siteId, status, errorMessage?}`. Per-client errors must be caught and recorded without aborting the batch.

### Phase 4 — Reports screen wiring
8. **`REVIEW`** — Convert `ReportsPage` from `StatelessWidget` to receive injected state:
   - Inject live `ReportGenerated` event count (verified / pending / failed) from the event store.
   - Wire `_showGenerateReportDialog` → `'Start Generation'` button to call `ReportGenerationService` (and optionally `ReportBatchOrchestrator`) for real.
   - Display generation progress inline (spinner or progress indicator per client).
   - On success, push `ReportPreviewPage` via `Navigator` with the resulting `ReportBundle` and `pdfBytes`.

---

## Action Label Summary

| Gap | Item | Action |
|---|---|---|
| Gap 1 | Claude API decision (SDK vs HTTP) | DECISION |
| Gap 2 | `OnyxClaudeReportConfig` value object | AUTO |
| Gap 3 | `ClientNarrativeResult` domain type | AUTO |
| Gap 4 | `ReportBundle.withNarrative()` method | AUTO |
| Gap 5 | `ReportsWorkspaceAgent` service | REVIEW |
| Gap 6 | `ReportGenerationService` narrative injection | AUTO |
| Gap 7 | `ReportBatchOrchestrator` | REVIEW |
| Gap 8 | `ReportsPage` live wiring | REVIEW |
| Duplication | `ReportShellState`/`ReportShellBinding` merge | REVIEW |
| Bug | `SupervisorAssessment` always static regardless of breach count | AUTO |
