# Audit: track_overview_board.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/ui/track_overview_board.dart` (2765 lines)
- Read-only: yes

---

## Executive Summary

The file is a well-structured pure-UI shell: clean widget decomposition, consistent naming, good use of `ValueKey` for testability, and proper `shouldRepaint` guards on custom painters. However, all data is compile-time static fixtures. The widget presents itself as a live operational map ("LIVE GRID", "LIVE STATUS", real-time clock) but nothing is live. Beyond the fixture issue, there are four concrete bugs — a selection desync, a redundant `_filterSites()` fan-out on every build, stale hardcoded counts in layer labels, and a misleading incident severity branch — plus a passthrough class with no purpose and zero test coverage.

---

## What Looks Good

- Widget decomposition is appropriately sized. No single method exceeds ~120 lines.
- `ValueKey` applied to all interactive map elements — layer buttons, scroll view, rail, workspace button — gives test hooks a clean handle.
- `shouldRepaint` on both `_TrackMapFallbackPainter` and `_TrackMapLinkPainter` is correct and minimal.
- `AnimatedContainer` on layer buttons and site cards gives smooth transitions without an explicit animation controller.
- `ScrollController` is created in `initState` and disposed in `dispose` — no leak.
- `_buildTopPill` correctly wraps in `InkWell` only when `onTap != null`.
- `_TrackMapPin` uses `GestureDetector` correctly for tap-through in an `IgnorePointer` overlay context.

---

## Findings

### P1 — Selection Desync After Client Filter Change
- **Action: AUTO**
- When the user selects a client filter, `setState` sets `_selectedSiteId = null` (line 1870). The `highlightedSite` resolution in `build()` (lines 372–376) then falls back to `filteredSites.first` (or `_trackSites.first` if filtered list is empty). The spotlight panel renders that fallback site. However, no site pin on the map satisfies `_selectedSiteId == site.id` (null never equals a string), so the map shows no selected pin while the spotlight shows a site as if selected.
- **Why it matters:** The spotlight and the map are visually desynchronized immediately after any client filter tap. The user sees a site summary with no corresponding map highlight.
- **Evidence:** lines 351–352 (`_selectedSiteId = 'MO-05'`), line 1870 (`_selectedSiteId = null`), lines 372–376 (fallback resolves to non-null site), line 914 (`_selectedSiteId == site.id` determines map pin highlight).
- **Suggested fix for Codex to validate:** After setting `_selectedSiteId = null`, immediately resolve it to `filteredSites.isNotEmpty ? filteredSites.first.id : null` so the spotlight and map always agree.

---

### P1 — `_filterSites()` Called Four Times Per Build
- **Action: AUTO**
- `build()` calls `_filterSites()` once (line 368), then `_filterGuards()` (line 369), `_filterCameras()` (line 370), and `_filterIncidents()` (line 371). Each of the three derived filters calls `_filterSites()` internally (lines 808, 815, 822). Total: 4 calls to `_filterSites()` per frame.
- **Why it matters:** With static data this is cheap, but the pattern will become expensive once real data is wired. The derived filter methods should accept `siteIds` as a parameter, or the build method should pass the already-computed `filteredSites` to each.
- **Evidence:** lines 807–826 (`_filterGuards`, `_filterCameras`, `_filterIncidents` each call `_filterSites()`), lines 368–371 (all four called in `build`).
- **Suggested fix for Codex to validate:** Refactor derived filters to accept a `Set<String> siteIds` parameter. Compute once in `build`, pass to each. Eliminates 3 redundant scans.

---

### P2 — Layer Button Count Labels Hardcoded and Wrong
- **Action: AUTO**
- Layer toggle labels read `'Sites (25)'`, `'Guards (40)'`, `'Cameras (64)'` (lines 1011, 1025, 1039, 1054). Actual fixture data contains 6 sites, 6 guards, 8 cameras. These numbers do not update when the client filter is applied.
- **Why it matters:** The label misrepresents the filtered dataset to the operator. After filtering to a single client, the layer count still reads 25/40/64.
- **Evidence:** lines 1011, 1025, 1039, 1054 (literal strings with counts), `_trackSites` has 6 entries (lines 114–181), `_trackGuards` has 6 entries (lines 183–244), `_trackCameras` has 8 entries (lines 246–303).
- **Suggested fix for Codex to validate:** Pass `filteredSites.length`, `filteredGuards.length`, `filteredCameras.length` into the layer button labels. These are already computed in `build()`.

---

### P2 — Incident Severity 'ALERT' Falls Through to Amber — Inconsistent with Data Intent
- **Action: REVIEW**
- All incident color logic uses a binary `severityLabel == 'ALARM' ? _trackRed : _trackAmber` check (lines 902–904, 951–953, 1932). The fixture data includes `INC-SE-1` with `severityLabel: 'ALERT'` (line 320). 'ALERT' maps to amber on both the map link line and the map pin, but 'ALERT' and 'ALARM' are distinct terms in security operations and may warrant different visual treatment.
- **Why it matters:** If 'ALERT' is semantically a sub-alarm priority, amber is correct. If it is equivalent to alarm, the map pin color is wrong and could cause an operator to deprioritize an active alarm.
- **Evidence:** lines 320 (`severityLabel: 'ALERT'`), lines 902–904, 951–953, 1932 (binary ALARM check).
- **Suggested fix for Codex to validate:** Confirm the intended severity hierarchy with Zaks. If a three-tier model (ALARM > ALERT > WATCH) is correct, introduce a `_severityAccent(String label)` helper and apply it consistently.

---

### P3 — Spotlight–Rail Guard Count Asymmetry (Suspicion, Not Confirmed Bug)
- **Action: REVIEW**
- The right rail header at line 1184 shows `incidents.length` under the label 'ALARMS'. `incidents` here is all filtered incidents (not only those for the highlighted site). The spotlight at line 1395 shows `guards.length` where `guards` is `highlightedGuards` (only the selected site's guards). These two metrics have different scopes (fleet-wide vs. site-scoped) but sit at the same visual level.
- **Why it matters:** An operator glancing at both panels may misread fleet-wide alarm count as site-specific and vice versa. Not a code bug, but a UX ambiguity.
- **Evidence:** lines 1184–1186 (rail `incidents.length`, fleet-scope), lines 1394–1395 (spotlight `guards.length`, site-scope).

---

### P3 — `_TrackStaticMapBackground` is a Zero-Logic Passthrough
- **Action: AUTO**
- `_TrackStaticMapBackground` (lines 2294–2303) is a `StatelessWidget` whose entire `build` method returns `_TrackMapFallback(highlightedSite: highlightedSite)`. It adds no behavior, no theming override, no error boundary, and no test surface.
- **Why it matters:** Dead wrapper classes obscure intent and inflate the widget tree with no benefit.
- **Evidence:** lines 2294–2303.
- **Suggested fix for Codex to validate:** Replace `_TrackStaticMapBackground` at its call site (line 849) with `_TrackMapFallback` directly, then delete the wrapper class.

---

### P3 — Search Bar is Non-Functional UI
- **Action: DECISION**
- The search bar in `_buildTopBar()` (lines 611–642) is a decorative container with no `TextField`, no `TextEditingController`, and no `onTap` handler. The placeholder `'Quick jump... (⌘K)'` implies a keyboard shortcut that is not wired.
- **Why it matters:** If this is intentional (placeholder for a future feature), it should be documented. If it was intended to function, it is silently broken.
- **Evidence:** lines 611–642 (no `TextField`, no `FocusNode`, no `onTap`).

---

### P3 — Clock and Shift Timer Are Static Strings
- **Action: DECISION**
- `'22:45:22'` (line 710) and `'Shift: 55h 56m'` (line 665) are string literals. Neither updates. The compressed format `'22:45'` (line 710) is also a literal.
- **Why it matters:** A frozen clock on a live operations dashboard is a trust signal problem. Operators rely on timestamps to determine data freshness.
- **Evidence:** lines 665, 710.

---

## Duplication

### 1. Positioning Boilerplate Across Map Marker Widgets
- `_TrackMapRangeRing`, `_TrackMapDot`, `_TrackMapStar`, `_TrackMapPin` all use identical structure: `Positioned.fill → LayoutBuilder → Stack → Positioned(left: constraints.maxWidth * x …, top: constraints.maxHeight * y …)`.
- Files: lines 2341–2378 (`_TrackMapRangeRing`), 2432–2471 (`_TrackMapPin`), 2483–2525 (`_TrackMapDot`), 2537–2567 (`_TrackMapStar`).
- Centralization candidate: a shared `_TrackMapMarker` base widget or a `_positioned(double x, double y, Widget child)` helper that handles the layout math once.

### 2. Severity Color Derivation Repeated Three Times
- `incident.severityLabel == 'ALARM' ? _trackRed : _trackAmber` appears at lines 902, 951, and 1932.
- Centralization candidate: a private top-level `_incidentAccent(String severity)` function.

### 3. Status Badge (pill) Pattern Repeated in `_buildSiteCard` and `_buildGuardCard`
- Both cards build an inline `Container` badge with `BorderRadius.circular(999)`, `alpha: 0.16` background, and accent text (lines 2105–2125 in site card, lines 2223–2241 in guard card). The structure is identical.
- Centralization candidate: a `_buildStatusBadge(String label, Color accent)` widget method.

### 4. `_buildInlineMetric` vs `_buildSpotlightMetric` vs `_buildOverviewMetric`
- Three near-identical two-text metric widgets (lines 2266–2291, 1555–1589, 1519–1553). All render a label + value pair with minor style differences (padding, font size).
- Centralization candidate: a single `_TrackMetricCell` widget with configurable font sizes and padding.

---

## Coverage Gaps

- **Zero widget tests.** `Glob` finds no test file referencing `TrackOverviewBoard` or `track_overview_board`.
- **Client filter state machine untested.** Selecting a client, confirming filtered sites render, confirming the selection desync bug, and resetting to 'All Clients' are all untested paths.
- **Layer toggle interactions untested.** Toggle sites/guards/incidents/cameras on/off, confirm pins appear/disappear.
- **`_selectedSiteId` null path untested.** The fallback to `filteredSites.first` and `_trackSites.first` is exercised by the client filter but has no test.
- **`_buildTopBar` responsive breakpoints untested.** The `compact` and `condensed` branches at lines 558–743 are layout paths with no coverage.
- **`_buildSelectedSiteSpotlight` compact branch untested.** Line 1327 breakpoint at `< 720` is an untested layout path.
- **Custom painter `shouldRepaint` logic has no regression test.** No test forces a repaint with a changed/unchanged site and asserts the outcome.

---

## Performance / Stability Notes

- **`_buildTopBar` uses nested closure functions** (`titleBlock`, `searchBar`, `statusRow`) defined inside a `LayoutBuilder` builder. These closures are recreated on every layout pass. Not a hot path issue with static data, but worth noting if the top bar is ever driven by a stream.
- **`_buildMapBoard` renders all map pins unconditionally inside the `Stack`**, including hidden ones (guarded by `if (_showGuards)` etc.). The `for...if` pattern inside a `Stack` still allocates each `_TrackMapRangeRing`/`_TrackMapPin`/`_TrackMapDot` widget object even when the layer is off. Once real data populates hundreds of guards, visible or not, all widget objects are created. Consider `if (_showGuards) for (final g in guards) ...` ordering instead, which is already the correct Dart pattern here — this is actually fine as written at lines 886–961. No action needed currently.
- **`_filterGuards`/`_filterCameras`/`_filterIncidents` triple `_filterSites()` fan-out** — covered under P1 above.

---

## Recommended Fix Order

1. **P1 — Selection desync after client filter** (`_selectedSiteId = null` → spotlight/map mismatch). High operator-trust impact.
2. **P1 — `_filterSites()` fan-out** (4 calls per build). Cheap now, costly when real data arrives. Safe structural cut.
3. **P2 — Layer count labels** (Sites 25 / Guards 40 / Cameras 64 are wrong). Single-line fix per label, no logic risk.
4. **P3 — Delete `_TrackStaticMapBackground` wrapper**. Zero-risk cleanup.
5. **P3 — Centralize `_incidentAccent()` severity helper**. Removes duplication in three sites, reduces future bug surface on severity changes.
6. **DECISION — Search bar and clock**. Needs product decision before Codex touches.
7. **DECISION — Incident ALERT severity tier**. Needs product decision on severity hierarchy.
8. **Coverage** — widget tests for client filter, layer toggles, and selection state machine.
