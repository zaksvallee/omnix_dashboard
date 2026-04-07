# Audit: governance_page.dart (v2)

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/ui/governance_page.dart` (14,904 lines)
- Read-only: yes

---

## Executive Summary

`governance_page.dart` is the largest single file in the repo at ~14,900 lines and is structurally a god object. The page renders correctly because the sovereign report path is solid, but two systemic problems undermine the entire governance surface:

1. **All fleet, guard vigilance, and compliance data are hardcoded stub values.** The Governance War Room shows fabricated employees, callsigns, and vehicle counts regardless of live system state.
2. **`_visibleGovernanceEvents()` and several baseline-stat methods are called repeatedly per build**, producing O(N × builds) computation without caching.

Beyond those two, the file has five near-identical action-label methods, three near-identical baseline-stat patterns, repeated recovery-deck blocks, and a 70-field DTO (`_GovernanceReportView`) whose copy-constructor is the most dangerous maintenance surface in the codebase. Test coverage for the core derivation logic is absent.

---

## What Looks Good

- `_generateMorningReport` correctly guards with `mounted` before all `setState` calls, including the `finally` block.
- `_applyScopeFilter` and `_currentGovernanceLedgerScope` implement careful fallback chains (partner scope → site scope → first event → first chain).
- `didUpdateWidget` reconciles scene focus, prunes stale exception keys, and fires `onSceneActionFocusChanged` via `addPostFrameCallback` to avoid calling it mid-build.
- The `_effectiveSceneActionFocus` / `_validatedIncomingSceneActionFocus` pair prevents a parent from locking the page into a focus state that no longer has backing data.
- `_eventScope` uses an exhaustive `switch` pattern with a `_ => null` fallback, so unrecognised event types are safe.
- `_applyVehicleExceptionReviewOverlay` and `_publishCanonicalVehicleExceptionReview` form a clean optimistic-UI + upstream-sync pattern.

---

## Findings

### P1 — Hardcoded stub: fleet status

- **Action: REVIEW**
- Fleet data is hardcoded at `build()` line 907–914 with static values (12 ready, 2 maintenance, 1 critical, 24 available, 8 dispatched, 3 off-duty, 2 suspended).
- These values are used to compute `readiness` (line 923), which drives the hero chip, the ops-rail chip, and the posture score displayed to operators.
- `_readinessPercent` at line 14867 mixes hardcoded fleet penalty with real compliance data — the resulting score is meaningless against live state.
- **Evidence:** `lib/ui/governance_page.dart:907–914`, `14867–14878`
- **Suggested follow-up:** Confirm whether `GovernancePage` is intended to receive fleet data as a widget input or derive it from the event stream. If input: add a `FleetStatus` parameter. If derived: wire `GuardCheckedIn` / dispatch events through a fleet service.

---

### P1 — Hardcoded stub: guard vigilance

- **Action: REVIEW**
- `_buildVigilance` (line 13084) returns four hardcoded guard records: Echo-3, Bravo-2, Delta-1, Alpha-5, all with fabricated `lastCheckIn` values relative to `now` and fake sparkline data.
- The Vigilance Monitor card renders these as live guard posture.
- **Evidence:** `lib/ui/governance_page.dart:13084–13111`
- **Suggested follow-up:** `GovernancePage` already receives `widget.events`; `GuardCheckedIn` events carry `callsign`-equivalent data. A service or adapter should derive real vigilance from these events rather than returning stubs.

---

### P1 — Hardcoded stub: compliance issues

- **Action: REVIEW**
- `_buildCompliance` (line 13113) returns four hardcoded employees: John Nkosi (EMP-0912, expired), Sizwe Moyo (EMP-0417), Mandla Khumalo (EMP-0288), Thato Dlamini (EMP-1304). Two are blocking.
- These populate the READINESS BLOCKERS and NON-BLOCKERS surfaces. Operators see fake names and fake expiry states.
- `_resolveComplianceIssue` (line 2648) adds keys to `_resolvedComplianceIssueKeys` — those keys are derived from stubbed employee IDs, so "resolving" a blocker is meaningless.
- **Evidence:** `lib/ui/governance_page.dart:13113–13148`
- **Suggested follow-up:** Compliance issues should be derived from `widget.morningSovereignReport` (which already exposes `complianceBlockage.psiraExpired`, `pdpExpired`, `totalBlocked`) or passed as a typed widget parameter. The stub data should be removed entirely.

---

### P1 — `_currentGovernanceReportForFocusValidation` double-computes compliance

- **Action: AUTO**
- Line 4430: `_currentGovernanceReportForFocusValidation()` calls `_buildCompliance(DateTime.now())` independently, outside the main `build()` cycle.
- This method is called from `_validatedIncomingSceneActionFocus` which is called in both `initState` and `didUpdateWidget`.
- With real compliance data this means every widget update runs the compliance derivation twice: once in `build()` and once in `didUpdateWidget`.
- **Evidence:** `lib/ui/governance_page.dart:4430–4432`
- **Suggested follow-up:** Codex should cache or reuse the compliance result. In `didUpdateWidget`, pass the already-computed `compliance` list to the focus validation helper rather than re-deriving it.

---

### P2 — `_visibleGovernanceEvents()` called on every build without memoisation

- **Action: REVIEW**
- `_visibleGovernanceEvents()` (line 1715) iterates over the entire `widget.events` list with scope filtering.
- It is called in: `_governanceOpsRail` (×1), `_heroHeader` (×1), `_complianceSummarySurface` (×2 — once for Evidence button, once for Response-Time), `_partnerDispatchChainSurface` (×1), `_canOpenGovernanceEventsReview` (×1 called from `_governanceContextRail`, ×1 from `_quickActionsSurface`, ×1 in `_openGovernanceEventsAction`).
- Total: ~7–8 iterations per build frame over the full event list.
- **Evidence:** `lib/ui/governance_page.dart:1715–1733`, callsites at ~1312, 1897, 2432, 2507, 2535, 2545, 2575, 2590
- **Suggested follow-up:** Compute once at the top of `build()` alongside `vigilance`, `compliance`, and `fleet`, then thread the result through as a parameter. This converts O(N × 8) to O(N × 1) per frame.

---

### P2 — Baseline-stat methods call `_globalReadinessSnapshotForWindow` inside build synchronously per history point

- **Action: REVIEW**
- `_globalReadinessBaselineStats` (line ~5870), `_syntheticWarRoomBaselineStats` (line ~5935), and `_siteActivityBaselineStats` (line ~5982) each iterate up to 3 history items and call `_globalPostureService.buildSnapshot` or `_syntheticWarRoomService.buildSimulationPlans` on each — all during build.
- `_globalReadinessHistory` (line 6027) also calls `_globalReadinessSnapshotForWindow` and `_globalReadinessIntentsForWindow` for every item in `morningSovereignReportHistory`, meaning the event list is iterated once per history point per call.
- These are called during rendering of `_morningReportCard`, `_globalReadinessTrendCard`, `_syntheticWarRoomTrendCard`, `_siteActivityTrendCard`.
- **Evidence:** `lib/ui/governance_page.dart:5870–6130`
- **Suggested follow-up:** Results should be derived once in `build()` (or cached in state with invalidation on widget changes) rather than recomputed on every render. Alternatively, extract these to lazy-loading sub-widgets.

---

### P2 — Five near-identical action-label methods

- **Action: AUTO**
- `_copyMorningJsonActionLabel`, `_copyMorningCsvActionLabel`, `_downloadMorningJsonActionLabel`, `_downloadMorningCsvActionLabel`, `_shareMorningPackActionLabel`, `_emailMorningReportActionLabel` (lines 4042–4108) all have identical structure:
  1. Compute `focusLabel = _focusedSceneActionActionLabel(report)`
  2. Compute `readinessFocusLabel = _historicalMorningReportFocusLabel(report)`
  3. Compute `suffix = _combinedMorningActionSuffix(...)`
  4. Return `suffix == null ? '<base>' : '<base> ($suffix)'`
- Only the base string differs.
- **Evidence:** `lib/ui/governance_page.dart:4042–4108`
- **Suggested follow-up:** Extract `_morningActionLabel(report, base: String)` and call it from each method.

---

### P2 — Three near-identical baseline-stat patterns

- **Action: AUTO**
- `_globalReadinessBaselineStats`, `_syntheticWarRoomBaselineStats`, `_siteActivityBaselineStats` all:
  1. Filter history to exclude current report
  2. Sort by `generatedAtUtc` descending
  3. Take 3 items
  4. Compute averages from those 3 items
- The filtering/sorting/taking logic is repeated verbatim three times with no shared helper.
- **Evidence:** `lib/ui/governance_page.dart:5870–6025`
- **Suggested follow-up:** Extract `_baselineReports(_GovernanceReportView report)` returning `List<SovereignReport>` (the filtered, sorted, limited list) and reuse it.

---

### P2 — Recovery deck duplicated three times

- **Action: AUTO**
- The same three-action recovery deck (Open Reports Workspace, Open Sovereign Ledger, Refresh Morning Report) is constructed identically in:
  1. `_governanceContextRail` — receipt summary pending block (lines ~1583–1623)
  2. `_governanceContextRail` — events recovery block (lines ~1624–1666)
  3. `_showReceiptPolicyDrillIn` dialog — empty events recovery (lines ~7855–7907)
- The only differences are the key values, accent colour, and dialog-pop before callback.
- **Evidence:** `lib/ui/governance_page.dart:1583, 1624, 7855`
- **Suggested follow-up:** Extract a `_governanceStandardRecoveryDeck` method that accepts optional `onTap` wrappers.

---

### P2 — `_applyScopeFilter` is a 100-line manual copy-constructor

- **Action: REVIEW**
- `_applyScopeFilter` (lines 4538–4733) constructs a new `_GovernanceReportView` by copying every one of the 70+ fields, substituting only the 8 partner-related fields.
- Adding or removing any field from `_GovernanceReportView` requires updating this constructor call, the `_resolveReport` constructor call, and potentially the `_GovernanceReportView` class itself — three synchronised edits.
- **Evidence:** `lib/ui/governance_page.dart:4538–4733`
- **Suggested follow-up (DECISION):** Consider whether `_GovernanceReportView` should use a `copyWith` pattern, or whether the scope-filtered fields should be a separate sub-struct, so `_applyScopeFilter` only replaces the partner sub-struct.

---

### P2 — `catch (_)` in `_generateMorningReport` swallows all exceptions silently

- **Action: AUTO**
- Line 1834: `catch (_)` catches any throwable and updates the command receipt with a generic failure message, discarding the actual error.
- If the sovereign report pipeline fails due to a network error, type error, or assertion, no diagnostic information is captured.
- **Evidence:** `lib/ui/governance_page.dart:1834`
- **Suggested follow-up:** Log the error (e.g., `debugPrint` or a logger service) before updating the command receipt.

---

### P3 — Reference identity comparison for `morningSovereignReport` in `didUpdateWidget`

- **Action: REVIEW (suspicion, not confirmed)**
- Line 857: `widget.morningSovereignReport != oldWidget.morningSovereignReport` uses reference equality (Dart `==` on a domain object).
- If `SovereignReport` does not override `==`, any parent rebuild that creates a new `SovereignReport` instance from identical data will trigger the full focus reconciliation, exception key pruning, and `onSceneActionFocusChanged` callback — producing spurious state churn and potentially a spurious callback to the parent.
- **Evidence:** `lib/ui/governance_page.dart:857–893`
- **Suggested follow-up:** Confirm whether `SovereignReport` overrides `==`. If not, consider comparing by `date` + `generatedAtUtc` instead, or ensuring the parent holds a stable instance reference.

---

### P3 — Five near-identical badge/chip widget builders

- **Action: REVIEW**
- `_heroChip`, `_governanceWorkspaceChip`, `_summaryTag`, `_statusBadge`, `_partnerTrendMetricChip` are all pill-shaped tinted containers with text (lines ~2060, 1495, 3368, 2802, scattered).
- They differ only in padding, border-radius, font size, and whether they show a label+value or label only.
- **Evidence:** `lib/ui/governance_page.dart:2060–2092, 1495–1530, 3368–3386, 2802–2820`
- **Suggested follow-up:** A shared `GovernancePillChip` widget with named parameters would halve the rendering code for these components and make colour consistency testable.

---

## Duplication

| Pattern | Locations | Centralisation Candidate |
|---|---|---|
| Action label (base + suffix) | lines 4042–4108 (×6 methods) | `_morningActionLabel(report, base)` |
| Baseline history filter+sort+take(3) | lines 5870, 5935, 5982 | `_baselineReports(report)` |
| Standard recovery deck | lines 1583, 1624, 7855 | `_governanceStandardRecoveryDeck(...)` |
| Pill/chip badge | lines 2060, 1495, 3368, 2802, ~9690 | `GovernancePillChip` widget |
| `_GovernanceReportView` 70-field constructor | lines 4637–4732 (scope filter) + 13174–13350 (resolve) | `copyWith` on `_GovernanceReportView` |
| Scene focus switch (`latestAction / recentActions / filteredPattern`) | `_focusedSceneActionLabel`, `_focusedSceneActionDetailValue`, `_focusedSceneActionActionLabel`, `_focusedSceneActionFilenameSuffix`, `_focusedSceneActionMetricDetail` (×5 nearly identical switches) | Single `_sceneActionFocusData(report, focus)` record return |

---

## Coverage Gaps

- **`_applyScopeFilter`** — no test. This is the most complex derivation in the file: it filters 4 list types across 2 scope modes (partner scope vs site scope), recomputes counts, and reconstructs the 70-field DTO. A scope-filter mismatch silently shows the wrong data to operators.
- **`didUpdateWidget` focus reconciliation** — no test. The logic at lines 848–893 must: (a) validate incoming focus against backing data, (b) prune stale exception keys, (c) fire `onSceneActionFocusChanged` only when appropriate.
- **`_readinessPercent`** — no test. Currently computed against stubs, but when real data is wired, the penalty formula (line 14873–14876) should be locked.
- **`_buildVigilance` / `_buildCompliance`** — untestable in current form because they return hardcoded stubs. Once real data is wired, edge cases (all expired, all clear, zero guards) need coverage.
- **`_effectiveSceneActionFocus` with empty backing fields** — three enum branches × two data states = 6 combinations. Only the null branch is trivially safe; the other 6 should be covered.
- **`_applyStatusToWorkflowSummary` regex replacement** — line 14786. The regex `\s*\([A-Z_]+\)\s*$` may fail to match when the existing status suffix contains digits or lowercase. Not confirmed, but untested.
- **`_partnerTrendRows` and `_partnerScoreboardHistoryRows`** — the trend aggregation logic is non-trivial and currently has no test coverage mentioned.

---

## Performance / Stability Notes

- **Build-time event scans**: `_visibleGovernanceEvents()` is called ~7–8× per build frame. With 500+ events and nested scope checks, this is a measurable hot path at the desktop layout where `build()` fires on constraint changes.
- **Build-time service calls**: `_globalPostureService.buildSnapshot` and `_orchestratorService.buildActionIntents` are called synchronously during rendering (via `_globalReadinessHistory`, `_syntheticWarRoomHistory`, baseline stat methods). If these services do anything heavier than list filtering, they will block the raster thread.
- **`_shadowMoHistoryForView`**: Calls `_globalReadinessSnapshotForWindow` three times inside a single method (line ~5290–5336), each iterating over the full event list. Called during `_morningReportCard` rendering.
- **`_listenerAlarmFeedCyclesForReport`, `_listenerAlarmAdvisoriesForReport`, `_listenerAlarmParityCyclesForReport`**: Three separate full-list sweeps with `whereType` + window filtering, all called within `_summaryMetricChildren` on the same frame. Should be one pass.

---

## Recommended Fix Order

1. **Remove the three hardcoded stubs** (`_buildVigilance`, `_buildCompliance`, fleet literal) and wire real data — either from `widget.morningSovereignReport` or new widget parameters. Until this is done, the governance surface is misleading in production. *(REVIEW — architecture decision needed on input shape)*

2. **Memoize `_visibleGovernanceEvents()`** — compute once at the top of `build()` and pass through. This is a safe, narrow change with no downstream risk. *(AUTO)*

3. **Fix `catch (_)` to log the exception** before swallowing it. One-line change. *(AUTO)*

4. **Extract the 5 action-label methods into one** `_morningActionLabel(report, base)`. Purely mechanical, no logic change. *(AUTO)*

5. **Extract `_baselineReports(report)`** and reuse across the three baseline-stat methods. Reduces duplication and makes the history-window boundary easier to adjust. *(AUTO)*

6. **Extract the standard recovery deck** into a helper. Reduces three near-identical blocks to one. *(AUTO)*

7. **Add `copyWith` to `_GovernanceReportView`** and reduce `_applyScopeFilter` to a targeted patch. This is the highest-risk structural change and should be the last in the sequence after the stubs are replaced with real data. *(REVIEW)*

8. **Add tests for `_applyScopeFilter`**, `didUpdateWidget` focus reconciliation, and `_readinessPercent` formula once real data is wired. *(REVIEW)*
