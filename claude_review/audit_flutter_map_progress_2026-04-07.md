# Audit: flutter_map Integration Progress

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: flutter_map integration state across `pubspec.yaml`, `pubspec.lock`, `lib/ui/tactical_page.dart`, `lib/domain/`, `lib/application/`, `test/`
- Read-only: yes

---

## Executive Summary

flutter_map has been added to `pubspec.yaml` and resolved to version 8.2.2 in `pubspec.lock`. That is the only concrete progress made. No Dart file in the entire project imports or uses flutter_map, `FlutterMap`, `TileLayer`, `LatLng`, or `MapController`. `tactical_page.dart` is structurally unchanged from the state described in `audit_tactical_map_integration_2026-04-07.md`: it still uses a custom `CustomPaint` grid with hardcoded normalized-coordinate `(x, y)` stubs for all markers, geofences, and anomalies. Steps 3–7 of the tactical map implementation have not begun.

One prior audit document (`audit_tactical_map_2026-04-07.md`, authored by Codex on 2026-04-07) explicitly states that flutter_map is not in `pubspec.yaml`. That claim is now false. That audit is stale and should not be treated as a current baseline per the staleness rule.

---

## What Looks Good

- flutter_map 8.2.2 is correctly declared as a direct dependency in `pubspec.yaml:26` and is fully resolved in `pubspec.lock` with a pinned sha256. The pub resolution is clean — no version conflicts were detected.
- The package chosen (flutter_map) avoids the Google Maps API key and billing requirement, and provides canvas-based rendering that avoids the iframe interaction problems that `google_maps_flutter` has on web. This was the right call if web is the primary platform.
- `GuardLocationHeartbeat` latitude/longitude domain model remains clean (`lib/domain/guard/guard_mobile_ops.dart:94–95`). Nothing was broken in the domain layer.

---

## Findings

### F1 — flutter_map installed but zero integration code exists anywhere
- **Action: REVIEW**
- **Finding:** `flutter_map: ^8.2.2` appears in `pubspec.yaml:26` and `pubspec.lock` (version 8.2.2, sha256 pinned). Codebase-wide search for `flutter_map`, `FlutterMap`, `TileLayer`, `LatLng`, and `MapController` across all `lib/` and `test/` files returns zero matches. The dependency is declared but completely unused.
- **Why it matters:** The package cost (dependency resolution, compile time, bundle size) is paid but the feature value is zero. More importantly, DEMO-1 (tactical map is entirely stub data) remains fully open. A client demo today shows `Echo-3`, `Alpha-1`, and `INC-8829-QX` regardless of which site or incident is active.
- **Evidence:**
  - `pubspec.yaml:26` — `flutter_map: ^8.2.2`
  - `pubspec.lock` — `version: "8.2.2"`, sha256 confirmed
  - `lib/ui/tactical_page.dart:1-22` — imports: `dart:math`, `flutter/material.dart`, `google_fonts`, and 10 local application/domain/ui files. No flutter_map import.
  - Repo-wide grep for `flutter_map`, `FlutterMap`, `TileLayer`, `LatLng`: 0 matches in `lib/`, 0 matches in `test/`
- **Suggested follow-up:** Codex to begin Step 3 (see below). The package is ready; the integration work is the blocker.

---

### F2 — audit_tactical_map_2026-04-07.md is stale and contains a false claim
- **Action: AUTO**
- **Finding:** `claude_review/audit_tactical_map_2026-04-07.md` (authored by Codex) states at lines 21–30: *"pubspec.yaml:10-23 lists the app dependencies. Present: google_fonts. Not present: google_maps_flutter, flutter_map, mapbox_gl, or similar map packages. Conclusion: No Flutter map package is currently being used."* This is false. `flutter_map` is present in `pubspec.yaml:26` and resolved in `pubspec.lock`. Per the staleness rule, that report should not be treated as a current baseline. Any downstream work referencing that finding (e.g. "the package decision is still open") is operating on outdated information.
- **Why it matters:** If Codex re-reads that audit before implementing the map integration, it will mistakenly re-add flutter_map or treat the package decision as unresolved. The DECISION on package choice (F1 from `audit_tactical_map_integration_2026-04-07.md`) has been resolved — flutter_map was selected and added.
- **Evidence:** `claude_review/audit_tactical_map_2026-04-07.md:21–30` vs. `pubspec.yaml:26` and `pubspec.lock`.
- **Suggested follow-up:** Codex to annotate or supersede `audit_tactical_map_2026-04-07.md` with a note that the package-absent finding is stale. Alternatively, treat this audit as the authoritative current-state document.

---

### F3 — tactical_page.dart: all markers, geofences, anomalies are unchanged hardcoded const stubs
- **Action: REVIEW**
- **Finding:** `TacticalPage._markers` is still a `static const List<_MapMarker>` with five fictitious entries at `tactical_page.dart:327–374`. `_geofences` at `:376–396` and `_anomalies` at `:398–426` are identical to the state described in the prior audits. The `_MapMarker` model uses `x`/`y` normalized floats (0.0–1.0) — not `LatLng`. The `TacticalPage` constructor (`:257–325`) carries no `guardPositions`, `siteCoordinates`, or equivalent injection parameter. `_resolvedMarkers()` still prepends one synthetic seeded marker at fixed coordinates `(0.67, 0.49)` when a focus reference is set.
- **Why it matters:** The map surface provides zero operational signal. Nothing about the current stub state changes when different sites, guards, or incidents are active.
- **Evidence:**
  - `tactical_page.dart:327–374` — `_markers` const block unchanged
  - `tactical_page.dart:376–426` — `_geofences` and `_anomalies` const blocks unchanged
  - `tactical_page.dart:46–70` — `_MapMarker` model: fields `x`, `y` as `double`, no `LatLng`
  - `tactical_page.dart:257–325` — constructor: no position injection parameters

---

### F4 — No GuardPositionSummary value object and no readLatestGuardPositions() method exist
- **Action: REVIEW**
- **Finding:** `GuardSyncRepository` (interface at `lib/application/guard_sync_repository.dart`) has no `readLatestGuardPositions()` method. No `GuardPositionSummary` value object exists anywhere in `lib/domain/` or `lib/application/`. These were the two extraction targets flagged as F3 in `audit_tactical_map_integration_2026-04-07.md`. Neither has been implemented.
- **Why it matters:** Even if a `FlutterMap` widget were placed in `tactical_page.dart` today, it would have no data source. The Supabase read path from `guard_sync_operations WHERE type = 'locationHeartbeat'` to an injectable position list does not exist.
- **Evidence:**
  - `lib/application/guard_sync_repository.dart:6–17` — interface definition; no position query method present
  - Repo-wide grep for `GuardPositionSummary`, `readLatestGuardPositions`: 0 matches in `lib/`

---

### F5 — _MapMarker coordinate model is incompatible with flutter_map's LatLng; no projection bridge exists
- **Action: REVIEW**
- **Finding:** flutter_map markers are positioned using `LatLng(latitude, longitude)` objects. The current `_MapMarker` model uses `x`/`y` normalized widget-relative floats. There is no `LatLng` import, no `MapLatLngBounds` bounding box definition, and no projection function anywhere in the codebase. Adopting flutter_map requires replacing `_MapMarker.x`/`.y` with `LatLng`, defining a bounding box for each site, and re-writing the marker placement logic in `_mapPanel`.
- **Why it matters:** This is the largest single code change in the integration path — it touches `_MapMarker`, all three const stub lists, `_mapPanel`, `_fenceOverlay`, `_markerOverlay`, and the `TacticalPage` constructor API. It cannot be done in a single AUTO pass without Zaks review of the new `TacticalPage` API surface.
- **Evidence:**
  - `tactical_page.dart:46–70` — `_MapMarker` with `x: double`, `y: double`
  - `tactical_page.dart:4496–4504` — marker placement: `left: width * marker.x`, `top: height * marker.y` (approximate — line range from prior audit; confirmed architecture still present)
  - Repo-wide grep for `LatLng`: 0 matches in `lib/`

---

## Steps 3–7: Implementation State

The tactical map implementation plan from `audit_launch_readiness_2026-04-07.md` (DEMO-1) and `audit_tactical_map_integration_2026-04-07.md` lists these steps:

| Step | Description | Status |
|---|---|---|
| 1 | DECISION: Choose map package (flutter_map vs google_maps_flutter) | **DONE** — flutter_map selected |
| 2 | Add chosen package to `pubspec.yaml` and resolve | **DONE** — flutter_map 8.2.2 in pubspec.yaml + pubspec.lock |
| 3 | Add `readLatestGuardPositions()` to `GuardSyncRepository` + `GuardPositionSummary` value object | **NOT STARTED** — method and value object are absent |
| 4 | Replace `_MapMarker.x/y` with `LatLng`; define site bounding boxes | **NOT STARTED** — model unchanged |
| 5 | Extend `TacticalPage` constructor with `guardPositions` / `siteCoordinates` injection parameters | **NOT STARTED** — constructor unchanged |
| 6 | Replace `CustomPaint` grid with `FlutterMap` + `TileLayer` + `MarkerLayer` | **NOT STARTED** — no flutter_map import in tactical_page.dart |
| 7 | Add real-time Supabase subscription for guard positions with debounced setState | **NOT STARTED** |

Steps 3–7 are fully open. The integration is at step 2 of 7.

---

## Duplication

No new duplication introduced. The stub-data pattern (hardcoded normalized coordinates) remains in one place (`tactical_page.dart:327–426`). Not a duplication concern.

---

## Coverage Gaps

- No test for `GuardPositionSummary` (value object does not exist yet).
- No test for `readLatestGuardPositions()` (method does not exist yet).
- `test/ui/tactical_page_widget_test.dart` — if this file exists — tests the stub marker state only. No test asserts that injected `LatLng` positions reach the map surface (impossible until step 5 is done).
- Once flutter_map is integrated, the tile network call must be intercepted in widget tests to avoid real HTTP fetches.

---

## Performance / Stability Notes

- flutter_map 8.2.2 uses `canvas` rendering on web — this avoids the iframe interaction issues of `google_maps_flutter`. No platform-specific concern for the web-primary deployment.
- When the Supabase real-time subscription for guard positions is added (step 7), debouncing is mandatory before the subscription output reaches `setState` on `TacticalPage`. Multiple guards updating at sub-second intervals with uncoalesced `setState` calls will re-render the entire map panel on every event. A dedicated position store or `StreamController` with a throttle should sit between the subscription and the widget.
- The `TileLayer` tile provider choice (OpenStreetMap, Stadia, Stamen, or self-hosted) needs a decision before step 6 can be completed. OSM tiles work without an API key for development but OSM's usage policy prohibits high-volume production use without a tile hosting arrangement. This is a low-urgency DECISION but should be resolved before the demo environment runs live against OSM servers.

---

## Recommended Fix Order

1. **Step 3 — `GuardPositionSummary` + `readLatestGuardPositions()`** (REVIEW): Smallest discrete deliverable with independent value. Codex can write the Supabase query and value object without touching any UI code. Validate with a unit test against a mocked Supabase client.
2. **Step 4–5 — `_MapMarker` LatLng conversion + TacticalPage constructor extension** (REVIEW): Requires agreement on the site bounding box strategy (fixed per deployment in local config JSON, or fetched from Supabase `sites` table). The F4 finding in `audit_tactical_map_integration_2026-04-07.md` — site coordinate source decision — must be resolved first.
3. **Step 6 — Replace CustomPaint with FlutterMap + TileLayer** (REVIEW): The largest change. Agree on tile provider before starting. `FlutterMap` widget replaces the `CustomPaint` block in `_mapPanel`. Marker and geofence overlays become `MarkerLayer` and `PolygonLayer` children.
4. **Step 7 — Real-time Supabase subscription + debounced position store** (REVIEW): Wire after step 6 produces a visually correct static map with live-seeded positions.

---

## Open Decisions Blocking Progress

| Decision | Who Must Decide | Blocks |
|---|---|---|
| Tile provider for production (OSM fair-use vs. paid tile service) | Zaks | Step 6 |
| Site coordinate authority source (Supabase `sites` table vs. local config JSON) | Zaks | Step 4–5 |
