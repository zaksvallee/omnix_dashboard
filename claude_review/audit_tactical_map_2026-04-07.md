# Audit: Tactical Map

- Date: 2026-04-07
- Auditor: Codex
- Scope: tactical map readiness, Google Maps configuration, real marker data sources
- Read-only: yes

## 1. Google Maps API key configuration

I searched the repo for `google_maps`, `GoogleMap`, `MAPS_API`, and `maps_api_key`.

Result:
- No Google Maps API key configuration was found in app code, platform config, or local config.
- The only matches were in the prior audit note at `claude_review/audit_tactical_map_integration_2026-04-07.md`.
- There is no evidence of `google_maps_flutter` platform setup in Android/iOS/web files, which is consistent with there being no configured key.

Conclusion:
- The repo does not currently have a Google Maps API key configured.

## 2. Flutter Google Maps package

`pubspec.yaml` does not include a Flutter Google Maps package.

Evidence:
- `pubspec.yaml:10-23` lists the app dependencies.
- Present: `google_fonts`
- Not present: `google_maps_flutter`, `google_maps_flutter_web`, `flutter_map`, `mapbox_gl`, or similar map packages.

Conclusion:
- No Flutter Google Maps package is currently being used.

## 3. Real data sources that exist for map markers

### Guard telemetry (GPS coordinates)

Real coordinate-capable guard telemetry exists.

Evidence:
- `lib/domain/guard/guard_mobile_ops.dart:90-107`
  - `GuardLocationHeartbeat` has required `latitude` and `longitude`.
- `lib/domain/guard/guard_mobile_ops.dart:110-131`
  - `GuardCheckpointScan` has optional `latitude` and `longitude`.
- `lib/domain/guard/guard_mobile_ops.dart:156-170`
  - `GuardPanicSignal` has optional `latitude` and `longitude`.

Status:
- The data model exists.
- I did not find `TacticalPage` consuming those coordinates directly.

### Site coordinates (from Supabase)

Real site coordinates exist in the admin directory / Supabase site mapping flow.

Evidence:
- `lib/application/admin/admin_directory_service.dart:471-499`
  - `AdminDirectorySiteRow _mapSiteRow(...)` maps:
  - `lat: _doubleFromDynamic(row['latitude'])`
  - `lng: _doubleFromDynamic(row['longitude'])`

Status:
- Site latitude/longitude exists in the site row mapping.
- I did not find those coordinates wired into the tactical map page.

### Incident locations

I did not find a real incident latitude/longitude source.

Evidence:
- `lib/domain/events/intelligence_received.dart:3-28`
  - `IntelligenceReceived` carries `clientId`, `regionId`, `siteId`, `cameraId`, `zone`, and event metadata.
  - It does not carry latitude/longitude.
- `lib/ui/tactical_page.dart:257-325`
  - `TacticalPage` accepts events and scope references, but no incident coordinate list.

Status:
- Incident references exist.
- Incident geolocation does not appear to exist as a real coordinate model in the inspected repo paths.

### DVR / camera locations

I did not find a real DVR/camera latitude/longitude source.

Evidence:
- The inspected camera/intelligence layers consistently use `cameraId` and labels, not coordinates.
- `lib/domain/events/intelligence_received.dart:10-12`
  - Events carry `siteId` and optional `cameraId`, but not camera coordinates.
- Repo-wide searches surfaced many camera ID and label usages, but no camera/DVR latitude/longitude model.

Status:
- Camera identity exists.
- Camera/DVR geographic coordinates were not found.

## 4. Current tactical map stubs

The tactical map is currently driven by hardcoded normalized-position stub data in `lib/ui/tactical_page.dart`, not by real geographic coordinates.

### `_markers`

Evidence:
- `lib/ui/tactical_page.dart:327-374`

Current contents:
- Guard marker: `GUARD-ECHO-3` at `(0.20, 0.34)`, label `Echo-3`, status `active`, last ping `45s ago`, battery `82`
- Guard marker: `GUARD-ALPHA-1` at `(0.47, 0.58)`, label `Alpha-1`, status `sos`, last ping `12s ago`, battery `18`
- Vehicle marker: `VEHICLE-R12` at `(0.58, 0.26)`, label `Vehicle R-12`, status `responding`, ETA `4m 12s`
- Site marker: `SITE-NORTH` at `(0.76, 0.74)`, label `Sandton North`, status `staticMarker`
- Incident marker: `INC-8829-QX` at `(0.63, 0.54)`, label `INC-8829-QX`, status `sos`, priority `P1-CRITICAL`

### `_geofences`

Evidence:
- `lib/ui/tactical_page.dart:376-396`

Current contents:
- Fence centered on `Echo-3` at `(0.20, 0.34)`, status `safe`
- Fence centered on `Alpha-1` at `(0.47, 0.58)`, status `breach`
- Fence centered on `Delta-6` at `(0.36, 0.75)`, status `stationary`, stationary time `163`

### `_anomalies`

Evidence:
- `lib/ui/tactical_page.dart:398-418`

Current contents:
- `ANOM-1` at `(0.14, 0.28)`, size `(0.22 x 0.20)`, `Gate status changed`, confidence `94`
- `ANOM-2` at `(0.56, 0.33)`, size `(0.28 x 0.22)`, `Perimeter breach line`, confidence `91`
- `ANOM-3` at `(0.44, 0.68)`, size `(0.25 x 0.18)`, `Unauthorized vehicle`, confidence `86`

### Seeded incident overlay

There is one small dynamic exception: `_resolvedMarkers(...)` can prepend a synthetic seeded incident marker when the page has a focus reference but no exact marker match.

Evidence:
- `lib/ui/tactical_page.dart:5166-5184`

Current behavior:
- If seeded, it adds a synthetic incident marker at fixed coordinates `(0.67, 0.49)` with priority `P2-SEEDED`, then appends the same hardcoded `_markers` list.

## Bottom line

- No Google Maps API key is configured.
- No Flutter map package is installed.
- Real coordinate-capable data exists for guard telemetry and site records.
- Real coordinate-capable data was not found for incidents or camera/DVR locations.
- The tactical map is still a custom normalized-coordinate surface backed by hardcoded `_markers`, `_geofences`, and `_anomalies` stubs.
