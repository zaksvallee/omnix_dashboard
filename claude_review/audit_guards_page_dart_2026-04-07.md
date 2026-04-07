# Audit: guards_page.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/ui/guards_page.dart`, `test/ui/guards_page_widget_test.dart`
- Read-only: yes

---

## Executive Summary

`GuardsPage` is a large but well-organised single-file widget (~3 635 lines). It covers three distinct views (Active Now, Month Planner, Shift History) with correct responsive breakpoints and clean callback delegation. The core architecture is sound: no direct Supabase calls, no domain logic that belongs elsewhere, and all action callbacks are properly null-guarded. The main risks are (1) all guard, roster, and history data is hardcoded static state — there is no live-data path at all, (2) the `_buildRosterCalendarDays` helper is a pseudo-planning algorithm running in `build` on every repaint, (3) `_GuardRecord` identity and filtering are coupled by string sentinel values (`'--'`) rather than a typed `null`/enum path, and (4) test coverage is good for happy-path but has three concrete gaps.

---

## What Looks Good

- All external actions (`onOpenGuardSchedule`, `onOpenGuardReportsForSite`, `onOpenClientLaneForSite`, `onStageGuardVoipCall`) are null-checked before use; the page gracefully degrades without any wired callbacks.
- `didUpdateWidget` correctly compares `auditId` before re-ingesting an `evidenceReturnReceipt`, preventing stale banner flash.
- `_ingestEvidenceReturnReceipt` correctly uses `addPostFrameCallback` to defer consumption acknowledgement and guards on `mounted` before calling back.
- `_setSiteFilter` pre-selects the first visible guard after a filter change, preventing a stale selection pointing to an invisible record.
- `_GuardRecord`, `_ShiftRosterRow`, `_ShiftHistoryRow`, and the two calendar types are all `const`-constructible value objects — clean data layer for a static prototype.
- VoIP `Future` result is correctly `await`ed and the `mounted` guard is checked before calling `ScaffoldMessenger.of(context)` (line 3534).
- `ValueKey` coverage on all interactive elements is thorough, enabling reliable widget tests.
- Test suite exercises: initial render, view switching, site filter, evidence receipt, schedule and report routing, contact sheet message/VoIP paths, and offline fallback. That is strong coverage for a UI prototype.

---

## Findings

### P1 — Confirmed Bug
- **Action: AUTO**
- **Finding:** `_guardRosterCard` calls `_filteredGuards()` inside `itemBuilder` (line 1086), recomputing the filtered list on every card render. Combined with `_selectedGuard()` being called there as well, each card incurs an O(n) scan of `_guards`. With a static list this is invisible, but if `_guards` ever becomes dynamic or grows, every list rebuild will be O(n²).
- **Why it matters:** The card selection logic at lines 1084–1087 already reads `_filteredGuards()` inside the builder that itself receives `guards` as a parameter — the caller (`_guardRosterPanel`) passes `guards` through. The inner call at 1086 is redundant and wrong: it ignores any `siteCodeOverride` that might be in flight.
- **Evidence:** `lib/ui/guards_page.dart:1083–1087`
  ```dart
  final selected =
      guard.id == _selectedGuardId ||
      (_selectedGuard(_filteredGuards())?.id == guard.id &&   // ← redundant call
          _selectedGuardId.isEmpty);
  ```
- **Suggested follow-up for Codex:** Remove the `_selectedGuard(_filteredGuards())` branch. Selection is already driven by `_selectedGuardId`; the fallback can be `guards.first.id == guard.id && _selectedGuardId.isEmpty`.

---

### P1 — Structural Risk
- **Action: REVIEW**
- **Finding:** All guard data (`_guards`, `_shiftRosterRows`, `_shiftHistoryRows`) is hardcoded `static const` inside `_GuardsPageState`. The page presents as live operational data (real guard IDs, clock-in times, sync status) but has no live-data path. When real data is wired, the widget will need to be restructured to accept data from outside.
- **Why it matters:** The three static lists are deeply interleaved with the UI logic. `_shiftHistoryRows` even references specific guard employee IDs that match `_guards`. When the page is data-wired, the risk of stale cross-list mismatch is high (e.g., history rows referencing guards no longer in the active roster).
- **Evidence:** `lib/ui/guards_page.dart:229–575` — all three lists are `static const` on `_GuardsPageState`.
- **Suggested follow-up for Codex:** Validate whether a live-data props interface is planned. If so, the three static lists should become `widget` props or ViewModel objects, not state-class statics. The current shape is fine as a prototype scaffold only.

---

### P2 — Bug Candidate
- **Action: AUTO**
- **Finding:** `_buildRosterCalendarDays` is called unconditionally inside `build` via `_shiftRosterView` every time the widget rebuilds, even when the roster view is not the selected view. The method constructs a `List` of 31 `_RosterCalendarDay` objects (each with a nested `List<_RosterCalendarAssignment>`) and runs modular arithmetic on every element.
- **Why it matters:** Roster tab is hidden behind a tab switch. Rebuilds triggered by `_selectedGuardId` changes (on every guard card tap) or `_selectedRosterDate` changes will re-execute this allocation even when on the Active tab. The `switch` expression on line 667 already handles view selection, but `_shiftRosterView` is called as a branch result — however, `_buildRosterCalendarDays` is called inside `_shiftRosterView`, so it is only called when the roster view is selected. **Suspicion downgraded: this is not a confirmed rebuild path issue.** The real concern is that the method has no memoisation — every `setState` on the roster view (e.g., tapping a calendar day) regenerates the entire 31-day calendar.
- **Evidence:** `lib/ui/guards_page.dart:1627, 3164–3232`
- **Suggested follow-up for Codex:** Cache the calendar days in `_selectedRosterDate`'s `setState` when the input guards haven't changed, or extract to a computed getter that memoises on `_siteFilter`.

---

### P2 — Structural / Data Quality
- **Action: REVIEW**
- **Finding:** Off-duty guard state is encoded by sentinel string `'--'` in `siteCode` (lines 298, 404) rather than using a nullable field or relying solely on the `_GuardStatus.offDuty` enum. The same guard (`GRD-444`) also has `routeSiteId: ''` (empty string), which is a second sentinel. UI code branches on `guard.siteCode == '--'` at line 1174.
- **Why it matters:** Three different state representations for "no site assigned": `siteCode == '--'`, `routeSiteId.isEmpty`, and `status == _GuardStatus.offDuty`. When live data is wired this will create inconsistency in filtering and display. `_filteredGuards` already uses `guard.siteCode == filter` — a guard with `siteCode == '--'` will never match any real filter and will silently drop out.
- **Evidence:** `lib/ui/guards_page.dart:298–314, 1092–1099, 1174`
- **Suggested follow-up for Codex:** Confirm whether `siteCode` should be `String?` for unassigned guards, with null-safety driving the display branch, rather than the `'--'` sentinel.

---

### P2 — Alias Table Correctness
- **Action: REVIEW**
- **Finding:** The `_resolveSiteFilter` alias table at lines 3120–3134 maps `'wtf-main'` → `'SE-01'` and `'waterfall estate main'` → `'SE-01'`, but the guard record for SE-01 (`GRD-441`) uses `routeSiteId: 'WTF-MAIN'` which is a different site than `WF-02` (Waterfall Estate). The alias `'blue ridge security'` maps to `WF-02` but `BR-03` is Blue Ridge Residence. These aliases are semantically inconsistent.
- **Why it matters:** External routing passes `initialSiteFilter` through `_resolveSiteFilter`. A mismatch in alias resolution will silently show the wrong site without any error.
- **Evidence:** `lib/ui/guards_page.dart:3120–3136`
- **Suggested follow-up for Codex:** Validate the alias table against the canonical site registry. `'blue ridge security'` → `WF-02` looks wrong; `BR-03` is the Blue Ridge site. `WTF-MAIN` and `SE-01` may be intentional aliases but should be documented.

---

### P3 — Minor UI Logic
- **Action: AUTO**
- **Finding:** `_statusAndFiltersBar` computes `activeShifts = onDutyCount` at line 831 — then displays both "X On Duty" and "X Active Shifts" pills using the same count. The second pill is always a duplicate of the first.
- **Evidence:** `lib/ui/guards_page.dart:828–881`
- **Suggested follow-up for Codex:** Either differentiate "Active Shifts" (e.g., number of distinct site slots covered) from "On Duty" (head count), or remove the duplicate pill.

---

### P3 — Hardcoded Calendar Header
- **Action: REVIEW**
- **Finding:** The roster calendar panel header is hardcoded as `'March 2026'` at line 1919, and `_rosterMonth` / `_rosterReferenceDate` are `static final` pointing to March 2026 (lines 227–228). The calendar will always show March 2026 regardless of the real current date.
- **Why it matters:** On 2026-04-07 the page is already one month stale. If the page goes live, this will confuse operators.
- **Evidence:** `lib/ui/guards_page.dart:227–228, 1919`
- **Suggested follow-up for Codex:** Replace with `DateTime.now()` or a prop-driven month reference. This is a known prototype limitation; flag as DECISION if month navigation is out of scope for the next slice.

---

## Duplication

### 1. Status pill colour triples repeated across three sites
The `(foreground, background, border)` colour triples for ACTIVE/COMPLETED status appear identically in:
- `_shiftHistoryRows` inline Color literals (lines 435–437, 450–452, 464–466, 479–481, 493–495)
- `_guardRosterCard` computed variables (lines 1089–1097)
- `_selectedGuardPanel` Container decoration (lines 1266–1286)

All three sites hardcode `Color(0xFF63E6A1) / Color(0x1A10B981) / Color(0x5510B981)` for green and `Color(0xFF98A6BA) / Color(0x1A64748B) / Color(0x5564748B)` for muted grey.

**Centralisation candidate:** A `_guardStatusColors(_GuardStatus)` → `({Color fg, Color bg, Color border})` helper, or dedicated constants like `_onDutyColors` / `_offDutyColors`.

---

### 2. `publish-roster` action string duplicated
`'publish-roster'` is passed to `_openGuardScheduleForAction` at both line 1706 and line 1860 from two different buttons (header Wrap vs. command card). These are independent UI entry points to the same action, which is correct, but the string is a raw literal in both places with no shared constant.

**Centralisation candidate:** A `const String _kPublishRosterAction = 'publish-roster'` or similar action key constants.

---

### 3. Responsive stacked/row pattern repeated seven times
The `LayoutBuilder` → `if (stacked) Column(...) else Row(...)` pattern appears at lines 842, 931, 1213, 1341, 1474, 1753, 1800 with minor threshold variation (500, 620, 760, 820, 860, 1080, 1120). Each instance duplicates the same `LayoutBuilder` shell. This is a structural concern for a large page; worth noting if the page is ever extracted into smaller sub-widgets.

---

## Coverage Gaps

### 1. Site filter chip interaction not widget-tested
The test at line 74 (`'applies initial site filter from routing'`) tests `initialSiteFilter` prop but no test taps a `_siteFilterChip` at runtime to verify that guard selection resets correctly and the filtered roster updates. The `_setSiteFilter` / `_selectedGuardId` reset path (lines 3079–3085) is untested.

### 2. `_resolveSiteFilter` alias resolution not tested
No test verifies that passing `'sandton estate north'` or `'wtf-main'` as `initialSiteFilter` resolves to `'SE-01'` and shows only SE-01 guards. The alias table is complex enough to warrant direct unit-level coverage.

### 3. Clock-out button behaviour when guard is off-duty
The clock-out button disables when `!active`, but no test checks that it is disabled for an off-duty guard. A test selecting `GRD-444` and verifying `onPressed == null` on `guards-clock-out-button` is missing.

### 4. `didUpdateWidget` evidence receipt refresh
No test verifies that a new `evidenceReturnReceipt` prop (with a different `auditId`) arriving after initial render causes the banner to update. The `didUpdateWidget` guard on line 593 is logic-bearing and untested.

### 5. Empty calendar (no on-duty guards)
`_buildRosterCalendarDays` returns `const <_RosterCalendarDay>[]` when `planningPool.isEmpty` (line 3173). No test covers the roster view when all guards are off-duty, which would trigger a `calendarDays.first` `orElse` guard fallback at line 3630 but would return a degenerate empty day.

---

## Performance / Stability Notes

### 1. `_buildRosterCalendarDays` allocates on every roster-view `setState`
31 `_RosterCalendarDay` objects × N `_RosterCalendarAssignment` objects are created on every `setState` triggered by `_selectRosterDate`. For a static list this is negligible; for a live-data page with frequent stream updates, this will produce GC pressure. Cache the result or compute it outside `setState`.
**Evidence:** `lib/ui/guards_page.dart:1627, 3164–3232`

### 2. `GridView.builder` used for a static 7-item weekday header row
Line 1947 uses `GridView.builder` to render 7 fixed weekday labels. A `Row` with 7 `Expanded` children would be both simpler and avoid the builder overhead for a static, always-visible list.
**Evidence:** `lib/ui/guards_page.dart:1947–1969`

### 3. Nested `LayoutBuilder` inside `_viewTab` inside `_viewTabs` `LayoutBuilder`
`_viewTabs` wraps in a `LayoutBuilder` (line 931), and `_viewTab` itself contains another `LayoutBuilder` (line 2584). This creates nested layout passes. The inner `LayoutBuilder` checks `constraints.maxWidth < 132` to hide the icon. This threshold could be driven by the outer `compact` flag passed as a parameter, eliminating the nested measurement.
**Evidence:** `lib/ui/guards_page.dart:931–970, 2584–2612`

---

## Recommended Fix Order

1. **(P1 / AUTO)** Remove redundant `_filteredGuards()` call in `_guardRosterCard` selection check — low risk, purely additive simplification.
2. **(P2 / AUTO)** Remove duplicate "Active Shifts" pill or differentiate it from "On Duty" count.
3. **(P3 / AUTO)** Extract the three `(fg, bg, border)` status colour triples into named constants to eliminate duplication across `_guardRosterCard`, `_selectedGuardPanel`, and `_shiftHistoryRows`.
4. **(Coverage / AUTO)** Add widget test: tap site filter chip and verify guard selection resets.
5. **(Coverage / AUTO)** Add widget test: off-duty guard selected → clock-out button is disabled.
6. **(Coverage / AUTO)** Add widget test: `didUpdateWidget` evidence receipt update shows new banner.
7. **(P2 / REVIEW)** Audit the `_resolveSiteFilter` alias table for correctness and add unit tests.
8. **(P1 / REVIEW)** Decide on live-data props interface — the three `static const` lists need a migration plan before the page can be data-wired.
9. **(P3 / DECISION)** Replace hardcoded `'March 2026'` / `_rosterMonth` with a dynamic month reference or confirm prototype-only scope.
