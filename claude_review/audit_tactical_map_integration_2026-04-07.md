# Audit: Tactical Map Integration

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: Google Maps / real coordinate wiring — `lib/ui/tactical_page.dart`, `lib/domain/guard/guard_mobile_ops.dart`, `lib/application/guard_sync_repository.dart`, `lib/application/guard_telemetry_ingestion_adapter.dart`, `pubspec.yaml`
- Read-only: yes

---

## Executive Summary

The tactical map is entirely cosmetic. There is no mapping SDK in the project — no `google_maps_flutter`, no `flutter_map`, no Mapbox. The visible map surface is a custom `CustomPaint` widget that draws a grid backdrop and static route lines with markers positioned using normalized `(x, y)` floats (0.0–1.0) relative to the widget's pixel bounds. Every guard, vehicle, site, and incident marker is a hardcoded `const` value with a placeholder name.

Real guard GPS data exists in the domain layer and is serialized to Supabase via `GuardSyncOperation.payload`. However, it is never read back into the UI. The `TacticalPage` constructor has no `guardPositions`, `siteCoordinates`, or equivalent parameter. The gap between the data that exists and the map that is shown is complete.

Four ordered concerns below: SDK selection is a `DECISION`, data projection is `REVIEW`, the TacticalPage wiring is `REVIEW`, and the site coordinate model is `DECISION`.

---

## What Looks Good

- `GuardLocationHeartbeat` carries required `latitude`/`longitude` fields — the domain model is clean and ready to use (`guard_mobile_ops.dart:94-95`).
- `GuardCheckpointScan` and `GuardPanicSignal` carry optional lat/lng — correct optionality given GPS may not be available at those moments (`guard_mobile_ops.dart:117-118`, `161-162`).
- `GuardSyncOperation.payload` serializes `'latitude'`/`'longitude'` as JSON keys before Supabase write — the persistence contract is already correct (`guard_mobile_ops.dart:350-351`, `377-378`, `420-421`).
- `SupabaseGuardSyncRepository` already reads from `guard_sync_operations` with status/facade filtering — a position projection query could be added there without touching existing methods (`guard_sync_repository.dart:339`).
- The custom-paint map's `x`/`y` float scheme is self-consistent inside the stub. Replacing it with a real SDK later is a contained swap — the `_MapMarker` class is private and the map render block is in one method (`_mapPanel` starting at `tactical_page.dart:4366`).

---

## Findings

### F1 — No mapping SDK in pubspec.yaml
- **Action: DECISION**
- **Finding:** `pubspec.yaml` contains no map rendering dependency. `google_fonts` is present but `google_maps_flutter` is not. No alternative (flutter_map, mapbox_gl) is listed.
- **Why it matters:** Nothing can render a real tile map without a dependency. This is a blocker before any other wiring work begins.
- **Evidence:** `pubspec.yaml:10-24` — full dependency block contains no mapping package.
- **Decision required for Zaks:** Choose between `google_maps_flutter` (requires Google Maps API key, strong ecosystem, heavier setup on web), `flutter_map` (OpenStreetMap or tile provider of choice, no API key needed, good web support), or a custom tile-fetching approach. Each has platform-config, cost, and licensing implications.

---

### F2 — All map markers are hardcoded const stubs; no live data path exists
- **Action: REVIEW**
- **Finding:** `TacticalPage._markers` is a `static const List<_MapMarker>` with five fully fictitious entries. `_geofences` and `_anomalies` are similarly static. None are populated from application state or an injected data source. The `TacticalPage` constructor carries no guard-position or site-coordinate parameter.
- **Why it matters:** The map board provides no operational value. Operators see "Echo-3" and "Sandton North" regardless of which site or incident is active.
- **Evidence:**
  - `tactical_page.dart:327-374` — `_markers` const block.
  - `tactical_page.dart:376-396` — `_geofences` const block.
  - `tactical_page.dart:257-325` — `TacticalPage` constructor: no position parameters.
  - `tactical_page.dart:5166-5184` — `_resolvedMarkers()` adds one extra seeded marker when `focusReference` is set but still returns the same stubs otherwise.
- **Suggested follow-up:** Codex to validate that no position stream or list is injected from `main.dart` or anywhere the `TacticalPage` is instantiated before treating this as a confirmed full stub.

---

### F3 — Guard location heartbeats are enqueued to Supabase but never read back for display
- **Action: REVIEW**
- **Finding:** `GuardMobileOpsService.recordLocationHeartbeat` enqueues a `GuardSyncOperation` with `type: locationHeartbeat` and payload keys `latitude`/`longitude` (`guard_mobile_ops.dart:339-357`). `SupabaseGuardSyncRepository.readOperations` can query the `guard_sync_operations` table filtered by status/facade. However no consumer ever queries for `locationHeartbeat` operation type and projects those positions into a UI-visible data structure.
- **Why it matters:** The data pipeline from guard device → Supabase is at least structurally present, but there is a dead-end between Supabase and the map surface. A position projection query is missing entirely.
- **Evidence:**
  - `guard_mobile_ops.dart:339-357` — heartbeat enqueueing with lat/lng payload.
  - `guard_sync_repository.dart:339` — Supabase reads from `guard_sync_operations`.
  - `guard_sync_repository.dart:6-17` — `GuardSyncRepository` interface: no `readLatestGuardPositions()` method.
  - `tactical_page.dart:257-325` — `TacticalPage` constructor: no injected position list.
- **Suggested follow-up:** Codex to add a `readLatestGuardPositions()` method to `GuardSyncRepository` that queries `guard_sync_operations WHERE type = 'locationHeartbeat' ORDER BY created_at DESC` grouped by `guard_id`, then project to a `GuardPositionSummary` value object carrying `guardId`, `clientId`, `siteId`, `latitude`, `longitude`, `recordedAt`. This is the minimum extraction needed before any map widget can show real data.

---

### F4 — No site geo-coordinate model exists anywhere in the domain or application layer
- **Action: DECISION**
- **Finding:** Searched all domain and application Dart files for `latitude`, `longitude`, `coordinates`, `site_location`. No site entity carries a geo-coordinate. The tactical map has a `_MarkerType.site` type and shows a "Sandton North" stub, but there is no data model backing it.
- **Why it matters:** Site markers on the map require a source of truth for site location. Without it, even after guard positions are live, the map cannot anchor to a known perimeter.
- **Evidence:** No file match across `lib/domain/**/*.dart` for site-level coordinate fields. `tactical_page.dart:358-364` — `SITE-NORTH` marker with fictitious `x: 0.76, y: 0.74`.
- **Decision required for Zaks:** Where does site coordinate data live? Options: (a) site coordinates stored in Supabase `sites` or `clients` table and fetched into the app, (b) coordinates are fixed config per deployment in the local config JSON, (c) operators input site boundaries manually. Codex cannot add a coordinate model without knowing the authority source.

---

### F5 — Coordinate system mismatch between custom map and real GPS
- **Action: REVIEW**
- **Finding:** The current `_MapMarker` model uses `x` and `y` as normalized widget-relative floats (`0.0–1.0`). Real GPS data uses WGS-84 `latitude`/`longitude` doubles. There is no projection function anywhere in the codebase. If a real SDK map is adopted, `_MapMarker.x/y` are irrelevant and would be replaced by `LatLng`. If the custom-paint map is kept (not recommended for a production ops surface), a geo-to-pixel projection function must be written against a known bounding box.
- **Why it matters:** Adopting a real map SDK changes the marker model from normalized floats to lat/lng. All marker placement code in `_mapPanel` would need to change. The scope of this change depends on F1's decision.
- **Evidence:** `tactical_page.dart:46-70` — `_MapMarker` schema with `x`, `y` doubles. `tactical_page.dart:4496-4504` — marker positioned via `Positioned` with `left: width * marker.x`, `top: height * marker.y`.

---

### F6 — GuardTelemetryIngestionAdapter does NOT capture guard position
- **Action: REVIEW** (suspicion, not confirmed bug — clarification needed)
- **Finding:** `GuardTelemetryIngestionAdapter` captures wearable biometrics (`heartRate`, `movementLevel`) and device health (`gpsAccuracyMeters`, `batteryPercent`). It does NOT capture or return `latitude`/`longitude`. GPS accuracy is tracked but not GPS position. Position is only captured through `GuardMobileOpsService.recordLocationHeartbeat`, which is a separate call path.
- **Why it matters:** If the intent is that the telemetry heartbeat loop (which polls the adapter) should also refresh guard map position, there is a structural gap — the telemetry adapter contract has no position field and its HTTP response parser has no lat/lng key extraction.
- **Evidence:** `guard_telemetry_ingestion_adapter.dart:30-52` — `DeviceHealthSample` fields: no lat/lng. `guard_telemetry_ingestion_adapter.dart:328-330` — only `gps_accuracy_meters` extracted from HTTP payload.
- **Suspicion, not confirmed:** It may be that position updates are intended to come from a separate mobile SDK call (separate from the wearable telemetry pipeline). Zaks to clarify whether the heartbeat HTTP endpoint is expected to also return position.

---

## Duplication

No duplication specific to map integration. The marker-positioning pattern (`left: width * marker.x, top: height * marker.y`) appears at `tactical_page.dart:4496-4504` and within `_fenceOverlay` and `_markerOverlay` methods — consistent use, not duplication to fix now.

---

## Coverage Gaps

- No test for any guard position data flow: `guard_mobile_ops_test.dart` covers the queue operations but does not assert lat/lng values are preserved through the payload round-trip.
- No test for `SupabaseGuardSyncRepository` position projection (this method does not exist yet — F3).
- `tactical_page_widget_test.dart` tests map rendering with stub markers only. No test asserts that injected positions reach the map surface (impossible today since the injection path does not exist).

---

## Performance / Stability Notes

- Once a real-time Supabase subscription for guard positions is added, care is needed to debounce `setState` calls. Multiple guards updating at sub-second intervals on a `StatefulBuilder` that re-renders the entire map panel will be expensive. A dedicated position store with coalesced updates should wrap the subscription before it reaches `TacticalPage`.
- `google_maps_flutter` on web uses an iframe and has known interaction issues with Flutter overlays. If the web platform is primary, `flutter_map` (canvas-based) avoids that class of problem.

---

## Recommended Fix Order

1. **F1 — SDK decision** (DECISION): Zaks must choose the map package. All subsequent work is blocked on this choice.
2. **F4 — Site coordinate model decision** (DECISION): Agree on the authority source for site lat/lng. Can be done in parallel with F1.
3. **F3 — Add `readLatestGuardPositions()` to GuardSyncRepository** (REVIEW): Codex can draft the Supabase query and `GuardPositionSummary` value object once F1 and F4 directions are set.
4. **F2 / F5 — Replace `_MapMarker` stubs and coordinate scheme** (REVIEW): Once F1 (SDK chosen) and F3 (projection query ready) are resolved, `_MapMarker` can be updated and `TacticalPage` extended with a `guardPositions` parameter. This is the largest single change.
5. **F6 — Telemetry adapter GPS clarification** (REVIEW): Low blocking priority. Clarify intent with Zaks, then extend `DeviceHealthSample` or keep it as a health-only adapter.

---

## Complexity Estimate

| Step | Effort | Blocker |
|---|---|---|
| SDK selection + pubspec + platform config (Android/iOS/web) | 0.5–1 day | F1 DECISION |
| Site coordinate model + Supabase source | 0.5 day | F4 DECISION |
| `GuardPositionSummary` + Supabase query | 0.5 day | F3 |
| `TacticalPage` API extension + marker model swap | 1–1.5 days | F2, F5 |
| Real-time subscription + debounced position store | 0.5–1 day | F3 complete |
| **Total** | **3–4.5 days** | Sequential on decisions |

This is medium-high complexity. The domain data exists and is correctly modeled. The blocking gap is (a) the absent SDK, (b) the absent site coordinate source, and (c) the missing read-path that projects Supabase position rows into a UI-injectable data structure.
