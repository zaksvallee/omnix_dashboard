# Audit: events_page.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/ui/events_page.dart` (~4034 lines)
- Read-only: yes

---

## Executive Summary

`events_page.dart` is a functional, well-keyed forensic workspace UI with solid empty-state recovery, multi-panel layout handling, and useful viewport-aware breakpoints. The main risks are structural rather than runtime-critical: the file is a god widget at ~4000 lines, domain classification logic (lane mapping, event description, triage copy) lives entirely in `_EventsPageState`, and a state mutation inside `build()` bypasses Flutter's reactive model. The type-switch chains are duplicated six times across the file, making new event type additions an error-prone multi-site update. Performance is acceptable at current scale but `DateTime.now()` is called per-row on every build, and `_activeFilterCount()` is recomputed 6-8 times per build pass.

---

## What Looks Good

- All interactive widgets carry stable `ValueKey` identifiers — good for widget tests and golden coverage
- Empty-state recovery paths are thorough: lane-outside, window-empty, and scope-empty cases are all handled with targeted escape hatches
- `_copyEventId` has a correct `!mounted` guard before `setState` after `await`
- `_setLaneFilter`, `_setTimeWindow`, `_setWorkspaceView` all guard against no-op calls before calling `setState`
- `_relatedRows` is bounded (`.take(8)`) preventing unbounded chain display
- `IntegrityCertificatePreviewCard` correctly uses `SelectableText` so hash values are copyable in the dialog
- `_TimeWindow.threshold` cleanly isolates the time boundary logic in the enum itself

---

## Findings

### P1 — State mutation inside `build()` without `setState`

- **Action: REVIEW**
- `_selected` and the `_selected = null` branch are mutated directly inside `build()` at lines 91–95, without calling `setState`. Flutter's contract requires that state changes that affect the next frame pass through `setState`. This direct mutation works incidentally today because it happens during the same build pass, but it bypasses the scheduler, cannot be tracked by hot reload, and will silently break under any refactor that moves this logic into a `didUpdateWidget` or async path.
- **Evidence:** `lib/ui/events_page.dart:91–95`
- **Suggested follow-up:** Move the selection-sync logic into `didUpdateWidget` using a `WidgetsBinding.instance.addPostFrameCallback` or a computed selection value passed into `build` without mutating state.

---

### P1 — `DateTime.now()` called per-row inside `_matchesFilters`

- **Action: AUTO**
- `_matchesFilters` calls `_timeWindow.threshold(DateTime.now().toUtc())` on line 2620. This is invoked once per row during the `where(...)` filter pass. For 50+ events this means 50+ clock reads per build cycle. The threshold is a constant for a given build frame and should be computed once before the filter pass.
- **Evidence:** `lib/ui/events_page.dart:2620`
- **Suggested follow-up:** Compute `final threshold = _timeWindow.threshold(DateTime.now().toUtc())` once inside `build()` and pass it to a `_matchesFilters(row, threshold)` signature, or capture it as a local in the `where` closure.

---

### P2 — God widget: domain logic living in `_EventsPageState`

- **Action: DECISION**
- `_EventsPageState` is ~3600 lines and handles at least three distinct responsibilities: (1) layout/rendering, (2) domain-to-display mapping, (3) business triage interpretation. The following methods contain logic that belongs in a domain or application layer, not in a stateful widget:
  - `_toForensicRow` (line 2840) — maps `DispatchEvent` subtypes to `siteId`/`guardId`
  - `_detailsFor` (line 2888) — extracts field-level detail rows per event type
  - `_describe` (line 3102) — constructs label, color, and summary per event type
  - `_eventNextMoveLabel` / `_eventNextMoveDetail` (lines 1817–1867) — triage copy per event type
  - `_matchesLaneFilter` / `_laneForEvent` (lines 2628–2665) — lane classification per event type
- **Evidence:** `lib/ui/events_page.dart:2840–3214`
- **Suggested follow-up:** Extract a `ForensicRowMapper` (or equivalent) in the application layer that owns `_toForensicRow`, `_describe`, `_detailsFor`, `_eventNextMoveLabel`, `_eventNextMoveDetail`, `_laneForEvent`. The UI class keeps only rendering and filter state.

---

### P2 — Six independent type-switch chains over the same 11 event subtypes

- **Action: REVIEW**
- The same 11 `DispatchEvent` subtypes are pattern-matched in six separate methods: `_toForensicRow`, `_detailsFor`, `_describe`, `_eventNextMoveLabel`, `_eventNextMoveDetail`, `_matchesLaneFilter`, and `_laneForEvent`. Adding a 12th event type requires updates in all six places with no compiler enforcement. The fallthrough in `_describe` (line 3209) and `_eventNextMoveLabel` (line 1829) silently returns a generic result instead of erroring — new events degrade quietly.
- **Evidence:** `lib/ui/events_page.dart:1817, 2628, 2652, 2840, 2888, 3102`
- **Suggested follow-up:** A sealed class hierarchy for `DispatchEvent` with exhaustive `switch` expressions would make missing cases a compile error. Alternatively, a single `ForensicRowMapper.describe(event)` that returns a `ForensicRowDescriptor` carrying all display fields in one pass eliminates the duplication.

---

### P2 — Duplicate key on `Container` and its `KeyedSubtree` child in `_workspacePanelContainer`

- **Action: AUTO**
- In the non-`shellless` branch of `_workspacePanelContainer` (line 2212–2229), the outer `Container` receives `key: key`, and the inner `KeyedSubtree` also receives `key: key`. Flutter does not error on parent-child key sharing (only sibling duplicates throw), but the inner key is completely redundant and misleading — it adds no reconciliation value and suggests the author intended the key on one of these widgets, not both.
- **Evidence:** `lib/ui/events_page.dart:2212–2229`
- **Suggested follow-up:** Remove `key: key` from the inner `KeyedSubtree`. The outer `Container` already carries the stable key.

---

### P2 — `EvidenceProvenanceCertificate.fromIntelligence(event)` constructed twice per dialog open

- **Action: AUTO**
- `IntegrityCertificatePreviewCard.build` calls `EvidenceProvenanceCertificate.fromIntelligence(event)` at line 3694. `_showIntegrityCertificatePreview` calls it again at line 3801. The second construction is redundant — the result from `build` is discarded and not passed into the open action.
- **Evidence:** `lib/ui/events_page.dart:3694, 3801`
- **Suggested follow-up:** Pass the already-constructed `certificate` from `build` into `_showIntegrityCertificatePreview` as a parameter, or cache it as a `final` local before the `return Container(...)` block.

---

## Duplication

### `_shortHash` vs `_shortValue` — identical truncation logic in two classes

- `IntegrityCertificatePreviewCard._shortHash` (line 3960) and `_EventsPageState._shortValue` (line 2829) both trim a string and return a truncated version with `...`. The only difference is the default `maxLength` (12 vs 18).
- **Files:** `lib/ui/events_page.dart:2829` and `lib/ui/events_page.dart:3960`
- **Centralization candidate:** A single file-level `_truncate(String value, {int maxLength})` helper. Both callsites already live in the same file.

---

### Recovery deck rendered in three separate code paths

- The "open all / intelligence lane / all time / reset scope" recovery action cluster is rendered independently in:
  - `_selectedEventOverviewCard` lines 608–638
  - `_emptyDetailPane` lines 3292–3321
  - `_focusSnapshotCard` lines 1484–1519
- Each call site constructs the same conditional set of `_forensicRecoveryAction` / `_overviewCardAction` children based on the same three boolean guards (`canWidenWindow`, `_laneFilter != all`, `intelligenceCount > 0`).
- **Centralization candidate:** A `_recoveryActionSet(...)` method returning `List<Widget>` parameterized on available options and callbacks.

---

### `_pill` and `_previewPill` near-identical micro-widgets

- `_EventsPageState._pill` (line 3216) and `IntegrityCertificatePreviewCard._previewPill` (line 3971) render near-identical pill containers. Both use `BorderRadius.circular(999)`, a border, and `GoogleFonts.inter`. The only differences are default color and padding values.
- **Centralization candidate:** A single file-level `_onyxPill` widget accepting optional color and padding overrides, replacing both.

---

### `_laneCountForFilter(..., intelligence)` computed twice per build path

- `_selectedEventOverviewCard` (line 556) and `_focusSnapshotCard` (line 1382) each call `_laneCountForFilter(filteredRows, _EventLaneFilter.intelligence)` independently. Both receive the same `filteredRows` list in the same build pass.
- **Centralization candidate:** Compute `intelligenceCount` once in `build()` and pass it as a parameter to both methods.

---

## Coverage Gaps

1. **No test for chain panel rendering** — `_chainPanel` and its "Focus" tap interaction on related rows have no widget test coverage. The chain panel is the primary path for multi-event forensic review.

2. **No test for evidence panel** — `_evidencePanel` with `IntelligenceReceived` and `ReportGenerated` branches, including the `IntegrityCertificatePreviewCard` and its dialog open/copy interactions, is entirely untested.

3. **No test for `_copyEventId` clipboard interaction** — the clipboard path in `events-copy-event-id-button` and the resulting `_lastActionFeedback` text render are not covered.

4. **No test for `_focusLinkedEvent`** — the `events-context-focus-related-button` tap and the resulting lane and workspace view transitions have no coverage.

5. **No test for filter persistence across lane switches** — scenario: set a site filter, switch lane, verify the site filter survives the lane change and the visible row count reflects both constraints.

6. **`events_review_page_widget_test.dart` does not reference `EventsPage`** — the file exists but imports show it covers a different widget. Confirm this is correctly scoped or rename/consolidate.

7. **No regression test for state-mutation-in-build edge case** — if the P1 bug is fixed, a test should lock the correct behavior: `_selected` auto-advances to `visibleRows.first` only when the previously selected event is no longer in the visible set.

8. **No test for `_TimeWindow` filter with events straddling the boundary** — events with `occurredAt` exactly equal to the threshold are not tested. The current predicate is `isBefore(threshold)` (strict), so an event at exactly the threshold is visible — this edge case should be locked.

---

## Performance / Stability Notes

1. **`DateTime.now()` per-row** — confirmed above (P1). Multiply by rebuild frequency (filter taps, lane switches) and this is measurable on slower devices with 50+ events. Threshold should be a build-local constant.

2. **`_activeFilterCount()` called 6-8 times per build** — called in `_heroHeader`, `_overviewGrid`, `_selectedEventOverviewCard` (twice), `_filterBar`, `_eventLaneRail`, `_emptyState`, `_emptyDetailPane`. Each call is three comparisons, so the cost is negligible today, but it signals that the filter count is not modeled as a derived value — it's recomputed on every render. Computing it once in `build()` and passing it down is a zero-risk cleanup.

3. **`[...widget.events]..sort(...)` on every build** — line 64 copies and sorts the full event list on every rebuild, including filter-only changes. If `widget.events` is large (>100), this is O(n log n) per rebuild. A `didUpdateWidget` memo would avoid the re-sort when `widget.events` has not changed.

4. **`_toForensicRow` called for every event on every build** — line 66 maps all events to `_ForensicRow` on every rebuild. This includes all the type-cast logic per event. For 50+ events on a frame that only changed a filter value, all rows are remapped unnecessarily. A stable memo (keyed on `widget.events` identity) would eliminate the redundant work.

---

## Recommended Fix Order

1. **P1 — State mutation in `build()`** — high risk, low effort to fix correctly with `didUpdateWidget`/post-frame callback. Fixes a Flutter anti-pattern before it causes a harder-to-debug regression.
2. **P1 — `DateTime.now()` per-row** — AUTO, one-line fix, immediate performance improvement for any event set >10 rows.
3. **P2 — Duplicate key on `_workspacePanelContainer`** — AUTO, one-line fix, removes misleading key.
4. **P2 — `EvidenceProvenanceCertificate` double construction** — AUTO, extract and reuse from `build`.
5. **Coverage — Chain panel + evidence panel widget tests** — no code changes needed; tests lock the existing behavior before structural refactors.
6. **Duplication — `_shortHash`/`_shortValue` merge** — AUTO, small cleanup, reduces footprint before further extraction.
7. **Duplication — Recovery action set extraction** — REVIEW, reduces 3 copy-paste blocks to one parameterized helper.
8. **Structural — Extract `ForensicRowMapper`** — DECISION, largest change, requires architectural agreement before Codex implements.
9. **Performance — Memo for sort + `_toForensicRow`** — REVIEW, warranted once event lists grow beyond demo scale.
