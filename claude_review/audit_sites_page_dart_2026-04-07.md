# Audit: lib/ui/sites_page.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/ui/sites_page.dart`, `test/ui/sites_page_widget_test.dart`
- Read-only: yes

---

## Executive Summary

`SitesPage` is the largest single-file page in the dashboard (~2670 lines). The layout machinery is well-structured and the `ValueKey` discipline is solid, enabling reasonable test coverage. However, the file carries a serious layer violation: a full event-sourcing accumulator (`_buildSiteDrillSnapshots`) lives inside `_SitesPageState` and is called on every `build()` call with no memoization. There are also two confirmed dead-code bugs, a stale-selection race, a duplicate panel section shared across workspace views, and scoring logic that collapses to its clamp boundary for virtually all active sites.

---

## What Looks Good

- `ValueKey` on every interactive widget and panel — enables precise widget test targeting without fragile text finders.
- `_setSiteLaneFilter` guards against no-op state transitions (line 1830) and proactively resets selection to the first visible site when the filter empties the current selection.
- `_SiteDrillSnapshot` is an immutable value class — safe to pass around, no mutation risk.
- `_workspaceDeck` uses an exhaustive switch with no default — new view enum values will fail at compile time rather than silently rendering nothing.
- `_ratioBar` guards `total <= 0` correctly (line 2218), preventing NaN display.
- Nested `LayoutBuilder` breakpoints are all named constants or locally scoped — readable layout contract.

---

## Findings

### P1 — Layer Violation: Full event accumulator inside `_SitesPageState`
- **Action:** REVIEW
- `_buildSiteDrillSnapshots` (lines 2418–2569) is a full O(n) event-sourcing pass that iterates all `widget.events`, builds accumulators, joins against the projection, and scores every site. This is domain/application logic. It lives inside `_SitesPageState` and is called unconditionally on every `build()` invocation.
- **Why it matters:** Every parent `setState` call (including unrelated ones) triggers a full event scan. At 10k+ events the UI will stutter on any rebuild. More critically, this is domain computation that belongs in the application layer, not in a `State` object.
- **Evidence:** `lib/ui/sites_page.dart:40–41` — both `OperationsHealthProjection.build` and `_buildSiteDrillSnapshots` are called inside `build()` with no caching.
- **Suggested follow-up:** Move `_buildSiteDrillSnapshots` to the application layer or memoize it with a `late final` or cached field that regenerates only when `widget.events` changes (using `didUpdateWidget`).

---

### P1 — Stale selection key not cleared on events change
- **Action:** REVIEW
- `_selectedSiteKey` is initialized lazily in `build()` (line 54: `_selectedSiteKey ??= selectedPool.first.siteKey`). If `widget.events` changes so that the previously selected site is no longer in the event set, `_selectedSiteKey` retains its stale value. The `orElse: () => selectedPool.first` fallback on line 56 silently renders the fallback site in the workspace — but the roster shows no card highlighted (since no site matches `_selectedSiteKey`). The `??=` guard on line 54 prevents self-correction because `_selectedSiteKey` is not null.
- **Why it matters:** After a live event stream update that removes a site, the selection is visually incoherent: roster shows no selection, workspace shows a ghost site.
- **Evidence:** `lib/ui/sites_page.dart:54–58`. No `didUpdateWidget` override resets `_selectedSiteKey`.
- **Suggested follow-up:** Override `didUpdateWidget` and clear `_selectedSiteKey` when `widget.events` reference changes, or validate it against the new site list before use.

---

### P1 — Dead branch in `_overviewGrid` (`columns == 4` is unreachable)
- **Action:** AUTO
- `_overviewGrid` (lines 533–580) computes `columns` as 1, 2, or 3 (lines 535–539). The `childAspectRatio` branch on line 545 checks `columns == 4 ? 6.0 : ...`. The value 4 is never produced. The aspect ratio for `columns == 3` therefore always falls through to the final `3.7` branch, which may or may not be the intended value for three columns.
- **Why it matters:** The intended aspect ratio for 3 columns may be `6.0` (the dead branch) rather than `3.7`. The wrong ratio produces either compressed or stretched overview cards.
- **Evidence:** `lib/ui/sites_page.dart:535–539` (column computation), `lib/ui/sites_page.dart:545` (dead branch).
- **Suggested follow-up:** Codex to verify intended ratio for the 3-column case and remove or correct the dead branch.

---

### P2 — `_statusColor` has no case for `STRONG`
- **Action:** REVIEW
- `_statusColor` (lines 2400–2411) handles `CRITICAL`, `WARNING`, `STABLE` explicitly but falls through `default` for `STRONG`. The default color (`Color(0xFF40C6FF)`) is an ice-blue that does not match the green/teal accent used elsewhere for strong/healthy state.
- **Why it matters:** STRONG sites get the same fallback color as any unknown status string. On the roster card, the health badge, progress bars, and focus banner all derive their accent from `_statusColor`, so STRONG sites show ice-blue health indicators rather than a positive green signal.
- **Evidence:** `lib/ui/sites_page.dart:2400–2411`. Compare to `_laneAccent` which returns `Color(0xFF34D399)` for `_SiteLaneFilter.strong`.
- **Suggested follow-up:** Add an explicit `case 'STRONG'` returning a semantically correct green accent.

---

### P2 — `_patrolCoverageScore` saturates at 100 for any moderately active site
- **Action:** REVIEW
- The formula at lines 1930–1935 is: `(patrols * 14) + (checkIns * 10) + (guards * 8)`. A site with 8 patrols, 0 check-ins, and 0 guards already produces 112, which clamps to 100. Any site with more than 7 completed patrols shows 100% coverage regardless of actual posture variation.
- **Why it matters:** The patrol coverage bar on the roster card (line 1234) becomes a constant 100% for all but the most minimal sites, providing no operational signal. The metric is effectively useless for ranking or comparison.
- **Evidence:** `lib/ui/sites_page.dart:1929–1935`, `lib/ui/sites_page.dart:1234`.
- **Suggested follow-up:** Normalise against a target (e.g. expected patrols per shift) rather than a fixed multiplier, or express the raw count instead of a percentage if no target is available.

---

### P2 — `_buildSiteDrillSnapshots` discards events for sites not in the projection
- **Action:** REVIEW  
- Sites that appear in events but have no matching entry in `projectionBySite` still accumulate data correctly. However, their `healthScore` defaults to `0.0` (line 2553) and `healthStatus` defaults to `'STABLE'` (line 2554). A site with `0.0` health and `'STABLE'` status reads as healthy on the roster, even if it has active failures.
- **Why it matters:** A site appearing only in events (not yet in the projection — possible during lag between event ingestion and projection rebuild) could have failing dispatches but show STABLE/0.0. The sort on line 2562 puts 0.0 first (ascending healthScore), so these phantom sites surface at the top of the roster.
- **Evidence:** `lib/ui/sites_page.dart:2553–2554`, `lib/ui/sites_page.dart:2562–2566`.
- **Suggested follow-up:** Consider deriving health from the accumulator when the projection entry is absent, or explicitly marking projection-absent sites with a distinct status.

---

### P3 — `_siteKeyFromEvent` requires manual extension for every new event type
- **Action:** REVIEW
- `_siteKeyFromEvent` (lines 2571–2594) uses 7 sequential `if (event is X)` branches, each repeating the same string interpolation. If a new event type carries `clientId/regionId/siteId`, adding it here is a manual requirement with no compile-time reminder.
- **Why it matters:** A new event type that is not added to this method will silently produce a null site key and be dropped. There is no exhaustive dispatch, no compile-time check, and no warning logged.
- **Evidence:** `lib/ui/sites_page.dart:2571–2594`.
- **Suggested follow-up:** Add a `SiteLocatable` mixin or interface to `DispatchEvent` carrying `clientId/regionId/siteId`, then replace the chain with a single type check.

---

### P3 — Sub-pixel `contentPadding` constants
- **Action:** REVIEW
- Line 68: `const contentPadding = EdgeInsets.fromLTRB(0.65, 0.65, 0.65, 1.45)`. These are logical pixel values of less than 1px on all four sides. Depending on device pixel ratio and layout engine rounding, this may render as zero padding on standard DPR displays.
- **Why it matters:** If the intent was to express real spacing (e.g. 6.5 and 14.5 device-independent units), the factor is off by 10. If the intent is truly sub-pixel insets, a comment explaining why would prevent future confusion.
- **Evidence:** `lib/ui/sites_page.dart:68`.
- **Suggested follow-up:** Codex to verify design intent and compare against other page padding constants in the codebase.

---

## Duplication

### D1 — `Dispatch Outcome Mix` panel constructed twice
- `_commandWorkspace` (lines 1418–1450) and `_outcomesWorkspace` (lines 1593–1625) both build an identical `_panel('Dispatch Outcome Mix', ...)` containing the same four `_ratioBar` calls with the same labels, values, and colors.
- Files involved: `lib/ui/sites_page.dart:1418–1450`, `lib/ui/sites_page.dart:1593–1625`.
- Centralization candidate: extract an `_outcomeMixPanel(_SiteDrillSnapshot site, {bool shellless})` method and call it from both workspace views.

### D2 — Status pills constructed twice in `_workspaceStatusBanner`
- The `summaryOnly` branch (lines 874–887) manually rebuilds `_statusPill` for "Visible" and "Watch" counts — the same two pills already constructed in the `controls` Wrap at lines 803–814. They share identical arguments; only the containing column structure differs.
- Files involved: `lib/ui/sites_page.dart:799–814`, `lib/ui/sites_page.dart:874–887`.
- Centralization candidate: extract a `_siteSummaryPills` method and reference it in both paths.

### D3 — `_siteKeyFromEvent` repeats `'${event.clientId}|${event.regionId}|${event.siteId}'` seven times
- All seven branches (lines 2572–2593) produce the same string interpolation. If the separator character ever changes, all seven must be updated.
- Files involved: `lib/ui/sites_page.dart:2571–2594`.
- Centralization candidate: inline helper `_siteKey(String c, String r, String s) => '$c|$r|$s'`.

---

## Coverage Gaps

- **No test for `ExecutionDenied` events.** The watch lane filter depends on `deniedCount > 0`, but no test exercises denied events accumulating correctly into the roster card or watch lane filter count.
- **No test for `IncidentClosed` events.** These accumulate into `incidentsClosed` but there is no test that verifies the count surfaces correctly in the Outcomes workspace.
- **No test for the stale-selection bug.** No test pumps a first event set, then pumps a second event set that removes the previously selected site, and asserts the roster and workspace remain coherent.
- **No test for the `_patrolCoverageScore` / `_responseScore` logic.** These are computed and shown on roster cards; they have no unit tests.
- **No test for lane filter returning empty results.** The "No sites match the active lane" empty state path in `_siteRoster` (line 1012) is not exercised.
- **No test for the `_siteDirective` branches.** Four distinct narrative strings are returned based on site state — none are asserted in tests.
- **No widescreen / ultrawide layout test.** The page has three distinct layout profiles (phone/tablet/widescreen/ultrawide) but only desktop-1440 and phone-390 are exercised. The horizontal roster layout (≥1320px) is tested but the ultrawide surface (no max-width constraint) is not.
- **`_overviewGrid` dead aspect-ratio branch** has no test that would detect the wrong ratio.

---

## Performance / Stability Notes

- **`_buildSiteDrillSnapshots` on every `build()`** — O(n) over all events with map insertions per event. No caching. For large event histories (thousands of events) this produces measurable frame lag on any parent-triggered rebuild. Severity: medium-high in live streaming contexts.
- **`_siteCountForFilter` called 3 times per build in `_siteRoster`** (lines 1038–1067). Each call iterates all sites. For moderate site counts (<100) this is negligible, but it adds unnecessary work to an already expensive build path. Could be computed once and passed down.
- **`OperationsHealthProjection.build(widget.events)` on every `build()`** — if this projection is also O(n), it compounds the accumulator cost on every frame.

---

## Recommended Fix Order

1. **P1 — Layer violation / memoize accumulator** — Extract `_buildSiteDrillSnapshots` or cache it in `didUpdateWidget`. Highest impact on correctness and performance.
2. **P1 — Stale selection key** — Add `didUpdateWidget` to reset `_selectedSiteKey` when events change. Small change, high UX correctness value.
3. **P1 — Dead `columns == 4` branch** — Verify intended aspect ratio and remove dead code. AUTO candidate.
4. **P2 — `STRONG` missing from `_statusColor`** — Add explicit green case. Simple and high visual correctness value.
5. **D1 — Deduplicate `Dispatch Outcome Mix` panel** — Extract shared method. Reduces future divergence risk.
6. **P2 — `_patrolCoverageScore` saturation** — Requires a product decision on the target denominator. DECISION.
7. **P2 — Projection-absent site default health** — Requires a product decision on sentinel status for un-projected sites. DECISION.
8. **D3 — `_siteKeyFromEvent` repeated interpolation** — Minor cleanup. AUTO.
9. **Coverage gaps** — Add tests for denied/incident events, empty lane state, stale selection, and directive branches.
