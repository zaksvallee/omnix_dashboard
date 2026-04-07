# Audit: sites_page.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/ui/sites_page.dart` — full file (~2680 lines)
- Read-only: yes

---

## Executive Summary

`SitesPage` is a well-structured, self-contained dashboard page. The layout strategy is clear, state ownership is correct, and the accumulator/snapshot pipeline is readable. The primary risks are: (1) the entire projection + snapshot pipeline runs inside `build()` on every rebuild with no memoization; (2) `_buildSiteDrillSnapshots` and `_siteKeyFromEvent` contain repeated if-chains that diverge from the domain event hierarchy; (3) `_workspaceStatusBanner` has meaningful layout duplication — the `summaryOnly` path duplicates the `_statusPill` block verbatim; (4) test coverage for the snapshot computation pipeline is absent. Overall quality is good for a UI-heavy file, but the rebuild surface is the highest-priority risk.

---

## What Looks Good

- State ownership is clean: `_selectedSiteKey`, `_siteLaneFilter`, and `_workspaceView` are the only mutable fields. All derived data flows from `widget.events` with no ambient service calls in the widget tree.
- `_setSiteLaneFilter` preserves the current selection if it remains valid in the new lane — solid selection continuity logic.
- `_siteRoster` correctly caps visible rows at `_maxRosterRows` and surfaces a `OnyxTruncationHint` for overflow — no silent truncation.
- `_overviewGrid` uses `GridView.count` with `shrinkWrap: true` + `NeverScrollableScrollPhysics`, which is the correct pattern inside a scroll parent.
- `_selectedSiteKey` is initialized lazily (`??=`) on the first `build`, not in `initState`, which is correct for data-driven pages.
- The `_workspaceDeck` switch is exhaustive — adding a new `_SiteWorkspaceView` will produce a compile error, not a silent missing branch.

---

## Findings

### P1 — Projection + snapshot pipeline runs on every rebuild
- **Action:** REVIEW
- **Finding:** Lines 40–41 — `OperationsHealthProjection.build(widget.events)` and `_buildSiteDrillSnapshots(widget.events, projection)` are called unconditionally inside `build()`. Both are O(n) over `widget.events`. Any `setState` call (lane filter change, site selection, view switch) triggers a full re-projection and re-accumulation over the full event list.
- **Why it matters:** On a live dashboard with hundreds of events, every tap causes re-aggregation. At 1 000+ events, this will produce visible frame drops.
- **Evidence:** `sites_page.dart:40–41`
- **Suggested follow-up for Codex:** Validate whether `OperationsHealthProjection.build` and `_buildSiteDrillSnapshots` are idempotent and can be cached via `didUpdateWidget` + a stored result, or whether they should be lifted to the parent and passed in pre-built.

---

### P1 — `_siteKeyFromEvent` is a fragile if-chain over event subtypes
- **Action:** REVIEW
- **Finding:** Lines 2571–2594 — `_siteKeyFromEvent` tests every known event type with `is` checks and extracts `clientId|regionId|siteId` from each. If a new event type is added that carries site coordinates, this method silently returns `null` and the event is dropped from the accumulator without any warning.
- **Why it matters:** Silent data loss. A new event type that should contribute to site health is invisible until the method is updated. There is no compile-time guard.
- **Evidence:** `sites_page.dart:2571–2594`
- **Suggested follow-up for Codex:** Check whether `DispatchEvent` or a subtype interface exposes `clientId`/`regionId`/`siteId` as a shared contract. If so, the method can be replaced with a single `event.siteKey` accessor, making the if-chain unnecessary.

---

### P1 — `_buildSiteDrillSnapshots` mixes accumulation + projection override in one pass; `decisions` field is not cross-checked
- **Action:** REVIEW
- **Finding:** Lines 2418–2568 — The accumulator counts `decisions` from `DecisionCreated` events, but the snapshot prefers `projectionSite?.executedCount ?? acc.executed` for all other counts. The `decisions` field on `_SiteDrillSnapshot` comes only from `acc.decisions` (line 2541) — there is no projection override for it. If `OperationsHealthProjection` holds a different decision count (e.g., because it uses a different event window), the denominator used in `_ratioBar` (lines 1424–1445, 1598–1621) will be inconsistent with the numerators sourced from the projection.
- **Why it matters:** Ratio bars showing `x / decisions` could show > 100% or incoherent fractions if projection counts diverge from the accumulated count.
- **Evidence:** `sites_page.dart:2541` (decisions field), `sites_page.dart:1424–1445`, `sites_page.dart:1598–1621` (ratio bar calls)
- **Suggested follow-up for Codex:** Verify whether `OperationsHealthSnapshot` exposes a `decisions` count per site. If yes, prefer it as the denominator too. If not, document that `decisions` is accumulator-only and confirm all numerators also come from the accumulator.

---

### P2 — `_workspaceStatusBanner`: `summaryOnly` path duplicates `_statusPill` block verbatim
- **Action:** AUTO
- **Finding:** Lines 862–917 — When `summaryOnly: true` and `showInlineFocusCard` is true, the banner builds a new `Wrap` with two `_statusPill` calls (lines 875–886). These are character-for-character copies of the `controls` Wrap built at lines 799–860. The only difference is the `summaryOnly` path omits the lane filter and workspace view buttons.
- **Why it matters:** If `_statusPill` styling or pill order changes, the duplicate will drift silently. The duplication is about 30 lines.
- **Evidence:** `sites_page.dart:799–860` vs. `sites_page.dart:875–886`
- **Suggested follow-up for Codex:** Extract the two status pills into a local variable `statusPillRow` before the `summaryOnly` branch and reuse it in both paths.

---

### P2 — `_commandWorkspace` and `_outcomesWorkspace` duplicate the "Dispatch Outcome Mix" ratio bar panel
- **Action:** AUTO
- **Finding:** Lines 1418–1449 (`_commandWorkspace`) and lines 1593–1625 (`_outcomesWorkspace`) build identical `_panel('Dispatch Outcome Mix', ...)` blocks with the same four `_ratioBar` calls and identical colors.
- **Why it matters:** Any change to the outcome mix panel — an added bar, a renamed label, a color change — must be made in both places.
- **Evidence:** `sites_page.dart:1418–1449`, `sites_page.dart:1593–1625`
- **Suggested follow-up for Codex:** Extract a `_dispatchOutcomeMixPanel(site, {bool shellless})` method and call it from both workspaces.

---

### P2 — `_responseScore` returns magic fallback values (42, 86) with no explanation
- **Action:** REVIEW
- **Finding:** Lines 1921–1927 — When `averageResponseMinutes <= 0`, the method returns `42` (if there are active dispatches) or `86` (otherwise). These are arbitrary constants with no comment or named reference explaining their meaning.
- **Why it matters:** The values appear in visible UI progress bars. A reviewer has no way to determine if `42` represents "in-progress unknown" or a miscalculated default. Tests validating these paths would need to know the magic numbers.
- **Evidence:** `sites_page.dart:1921–1927`
- **Suggested follow-up for Codex:** Add named constants (`_kResponseScoreInProgress = 42`, `_kResponseScoreNoData = 86`) or replace with a documented formula.

---

### P2 — `_patrolCoverageScore` can overflow 100 without clamping context
- **Action:** AUTO
- **Finding:** Lines 1929–1935 — The formula `(patrols * 14) + (checkIns * 10) + (guards * 8)` can exceed 100 for any site with more than 8 patrols. `.clamp(0, 100)` is applied, so the displayed value is safe, but the un-clamped intermediate (e.g., 10 patrols → 140 before clamping) means the score saturates at 100% for almost any active site, reducing its diagnostic value.
- **Why it matters:** A score that always reads 100% for active sites conveys no signal. It is a suspicion, not confirmed bad behavior — but worth flagging.
- **Evidence:** `sites_page.dart:1929–1935`
- **Suggested follow-up for Codex:** Verify what the maximum realistic patrol count per site is in the test fixtures and confirm whether the score intentionally saturates.

---

### P2 — `_statusColor` uses `switch` with a default that maps unknown statuses to cyan
- **Action:** REVIEW
- **Finding:** Lines 2400–2411 — The `default` branch returns `Color(0xFF40C6FF)` (cyan), which is visually identical to the "STRONG" implied state, but is actually the fallback for any unrecognized `healthStatus` string.
- **Why it matters:** If the projection ever emits an unexpected status string (e.g., `'UNKNOWN'`, `'DEGRADED'`), the UI silently renders it as a positive blue signal rather than a neutral or warning color. The `switch` on a raw `String` has no compile-time coverage guarantee.
- **Evidence:** `sites_page.dart:2400–2411`
- **Suggested follow-up for Codex:** Check what values `healthStatus` can actually take from `OperationsHealthProjection`. If it is a closed set, consider converting it to an enum.

---

### P3 — `contentPadding` uses sub-pixel values that are semantically suspicious
- **Action:** REVIEW (low priority)
- **Finding:** Line 68 — `const contentPadding = EdgeInsets.fromLTRB(0.65, 0.65, 0.65, 1.45)`. Sub-pixel padding values below 1 logical pixel are rendered as 0 or 1 depending on device pixel ratio and rounding. The intent (fine-grained inset control) may not survive across device densities.
- **Why it matters:** Visual regression risk on non-3× displays. Low severity — visual only.
- **Evidence:** `sites_page.dart:68`
- **Suggested follow-up for Codex:** Confirm the pattern matches other pages in the codebase (e.g., `tactical_page.dart`) and document the intent if it is intentional.

---

### P3 — `_overviewGrid` has unreachable `columns == 4` branch
- **Action:** AUTO
- **Finding:** Lines 535–549 — The column count is calculated as `3`, `2`, or `1` (line 535–539), but the `childAspectRatio` ternary checks `columns == 4` first. This branch is dead code.
- **Why it matters:** Dead code is noise that signals an incomplete refactor — possibly a 4-column layout was planned and removed without cleaning up the aspect ratio logic.
- **Evidence:** `sites_page.dart:545`
- **Suggested follow-up for Codex:** Remove the `columns == 4 ? 6.0 :` branch from the `childAspectRatio` expression.

---

## Duplication

| Block | Locations | Candidate |
|---|---|---|
| `_statusPill` pair in `_workspaceStatusBanner` | Lines 803–814 (controls) vs. 875–886 (summaryOnly path) | Extract `statusPillRow` local variable |
| `_panel('Dispatch Outcome Mix', ...)` with four ratio bars | Lines 1418–1449 (`_commandWorkspace`) vs. 1593–1625 (`_outcomesWorkspace`) | Extract `_dispatchOutcomeMixPanel` method |
| `clientId\|regionId\|siteId` key construction | Lines 2573, 2575, 2577, 2579, 2581, 2583, 2585 in `_siteKeyFromEvent`; also line 2517 in `projectionBySite` map | Should be a shared helper or event interface property |
| `stacked < 920` LayoutBuilder pattern | `_commandWorkspace` (lines 1415, 1493), `_outcomesWorkspace` (line 1591), `_traceWorkspace` (line 1684) | Repeated 3×; could be a shared helper `_twoColumnOrStack` that accepts two widgets |

---

## Coverage Gaps

1. **`_buildSiteDrillSnapshots` has no unit test.** The accumulation pipeline (decisions, execution, denial, check-ins, patrol, response delta, active dispatch count) is business logic embedded in `_SitesPageState`. It is untested. This is the most complex logic in the file.
   - Untested failure cases: event with no matching site key; `decisions == 0` denominator in ratio bars; `responseDeltaMinutes` empty vs. populated; projection site override overwriting accumulator counts.
2. **`_filteredSites` logic for `STRONG` lane** (`healthStatus == 'STRONG' && failedCount == 0 && deniedCount == 0 && activeDispatches == 0`) is not covered. The `STRONG` filter definition should be tested as a unit to lock the exclusion criteria.
3. **`_responseScore` magic fallback paths** (lines 1921–1922) have no test. The `42` and `86` values are undocumented and untested.
4. **`_setSiteLaneFilter` selection-preservation logic** (lines 1826–1843) — specifically the path where the current selection is NOT in the new filtered set — has no widget test or unit test verifying that `filtered.first.siteKey` is correctly adopted.
5. **`_showTacticalLinkDialog`** — no widget test confirms the dialog opens, displays expected text, and dismisses correctly.
6. **Empty-state path** (`allSites.isEmpty`) is structurally testable but absent from widget tests.

---

## Performance / Stability Notes

1. **Rebuild amplification (P1 above):** `OperationsHealthProjection.build` + `_buildSiteDrillSnapshots` are called inside `build()` with no guard. Every `setState` — including the trivial `_setWorkspaceView` — repeats the full event scan. On large event streams this is a concrete frame-budget risk.
2. **`_siteRoster` uses `ListView.separated` with `shrinkWrap: true` in the non-embedded path.** `shrinkWrap` on a `ListView` is O(n) layout and disables virtualization. For the roster list this is bounded to `_maxRosterRows = 12`, so the risk is minor, but it is worth noting that if `_maxRosterRows` is raised, the non-embedded path loses lazy rendering.
3. **`acc.recentTrace` is unbounded during accumulation.** Lines 2440–2502 append to `recentTrace` for every matching event. Only the final `.take(10)` at line 2557 limits the snapshot. For large event streams, the accumulator list can grow very large before the take. This is a memory concern, not a crash, but could be tightened with an early length guard.

---

## Recommended Fix Order

1. **[P1] Cache projection + snapshots** — lift `OperationsHealthProjection.build` and `_buildSiteDrillSnapshots` out of `build()` and memoize in `didUpdateWidget`. Largest performance risk.
2. **[P1] Validate `decisions` denominator consistency** — confirm ratio bars use coherent numerator/denominator sources (both projection or both accumulator).
3. **[P1] Audit `_siteKeyFromEvent` against domain event interface** — determine if a shared property can replace the if-chain.
4. **[P1] Write unit tests for `_buildSiteDrillSnapshots`** — extract it as a pure function so it can be unit-tested without a widget tree.
5. **[AUTO] Remove dead `columns == 4` branch** in `_overviewGrid` aspect ratio.
6. **[AUTO] Deduplicate `_dispatchOutcomeMixPanel`** — extract shared method to reduce future drift.
7. **[AUTO] Deduplicate `statusPillRow`** in `_workspaceStatusBanner`.
8. **[REVIEW] Name the magic fallback constants** in `_responseScore`.
9. **[REVIEW] Convert `healthStatus` string to enum** if the value set is closed from the projection.
10. **[LOW] Add widget tests** for empty state, lane filter selection preservation, and tactical dialog.
