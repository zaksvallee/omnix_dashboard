# Codex Summary — Tactical Map Steps 3-7

Date: 2026-04-07
Repo: `/Users/zaks/omnix_dashboard`

## Scope completed

Implemented the remaining tactical map decisions after Step 2:

1. Added guard position domain model and latest-position repository read path.
2. Converted tactical map marker/geofence models from normalized `x/y` values to real `LatLng` coordinates.
3. Extended `TacticalPage` to accept live `guardPositions` and `siteMarkers`.
4. Replaced the old `CustomPaint` tactical canvas with `FlutterMap` using OpenStreetMap tiles.
5. Wired real guard GPS markers from `guard_sync_operations`.
6. Wired real site coordinate markers from the admin directory / Supabase site rows.
7. Added tactical live refresh and Supabase realtime subscription with debounce.

## Files added

- `lib/domain/guard/guard_position_summary.dart`

## Files updated

- `pubspec.yaml`
- `lib/application/guard_sync_repository.dart`
- `lib/main.dart`
- `lib/ui/onyx_route_command_center_builders.dart`
- `lib/ui/tactical_page.dart`
- `test/application/guard_sync_repository_test.dart`
- `test/ui/guards_page_widget_test.dart`
- `test/ui/tactical_page_widget_test.dart`

## Implementation notes

### Guard positions

- Added `GuardPositionSummary` as the tactical-map-friendly projection of the latest known guard GPS point.
- Added `readLatestGuardPositions()` to `GuardSyncRepository`.
- Supabase implementation reads `guard_sync_operations` where the operation type is `locationHeartbeat`, then groups by `guard_id` and keeps the most recent point per guard.
- Fallback/shared-preferences repos expose the same method so route code stays uniform.

### Tactical map model changes

- `_MapMarker` now stores `LatLng point`.
- `_SafetyGeofence` now stores `LatLng point`.
- Seed/demo map markers were converted to real Johannesburg-area coordinates so the map still renders useful fallback content without live data.
- `TacticalPage` now accepts:
  - `guardPositions`
  - `siteMarkers`

### Flutter map migration

- Replaced the old tactical `CustomPaint` surface with `FlutterMap`.
- Tile source:
  - `https://tile.openstreetmap.org/{z}/{x}/{y}.png`
- Added separate marker layers for:
  - site markers
  - guard markers
  - incident markers
  - geofence overlays / highlighted regions

### Live tactical data wiring

- Added tactical live state and refresh wiring in `main.dart`.
- Tactical data is refreshed every 30 seconds.
- Added Supabase realtime subscription to `guard_sync_operations`.
- Rapid updates are debounced before refresh so the map is not thrashed by clustered heartbeat events.
- Tactical route entry points now configure live map data before opening the page.

## Validation

### Analyze

Passed:

```bash
dart analyze /Users/zaks/omnix_dashboard/lib/domain/guard/guard_position_summary.dart \
  /Users/zaks/omnix_dashboard/lib/application/guard_sync_repository.dart \
  /Users/zaks/omnix_dashboard/test/application/guard_sync_repository_test.dart \
  /Users/zaks/omnix_dashboard/test/ui/guards_page_widget_test.dart
```

Passed:

```bash
dart analyze /Users/zaks/omnix_dashboard/lib/ui/tactical_page.dart \
  /Users/zaks/omnix_dashboard/test/ui/tactical_page_widget_test.dart
```

Passed:

```bash
dart analyze /Users/zaks/omnix_dashboard/lib/main.dart \
  /Users/zaks/omnix_dashboard/lib/ui/onyx_route_command_center_builders.dart \
  /Users/zaks/omnix_dashboard/lib/ui/tactical_page.dart \
  /Users/zaks/omnix_dashboard/lib/application/guard_sync_repository.dart \
  /Users/zaks/omnix_dashboard/lib/domain/guard/guard_position_summary.dart \
  /Users/zaks/omnix_dashboard/test/application/guard_sync_repository_test.dart \
  /Users/zaks/omnix_dashboard/test/ui/tactical_page_widget_test.dart \
  /Users/zaks/omnix_dashboard/test/ui/guards_page_widget_test.dart
```

### Tests

Passed:

```bash
flutter test /Users/zaks/omnix_dashboard/test/application/guard_sync_repository_test.dart \
  /Users/zaks/omnix_dashboard/test/ui/tactical_page_widget_test.dart
```

## Repo-first notes

- `flutter_map` had already been added earlier; this batch also required `latlong2`.
- `flutter pub get` completed successfully after the dependency update.

## Known limitations / next follow-up

- Incident markers are currently placed from site coordinates because the repo still does not expose a dedicated incident latitude/longitude source in the domain/application layer.
- DVR/camera coordinates are still not modeled as first-class geospatial data, so tactical camera placement remains a future follow-up.
