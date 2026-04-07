# Codex Summary — BI Persistence Layer

Date: 2026-04-07

## Scope Completed

Implemented Phase 1 BI persistence for the locked scope:

- `vehicle_visits`
- `hourly_throughput`

Skipped `zone_analytics` as requested.

## Decisions Applied

- D1: RLS uses the existing JWT custom claim helper path via `public.onyx_client_id()`.
- D2: Persistence is triggered from `MorningSovereignReportService`.
- D3: Writes happen once per report generation, not in real time.
- D4: `visit_date` and all timestamps are written in UTC.
- D5: Only `vehicle_visits` and `hourly_throughput` were implemented.

## Files Added

- `supabase/migrations/202604070003_create_bi_vehicle_persistence.sql`
- `lib/infrastructure/bi/vehicle_visit_repository.dart`
- `test/infrastructure/bi/vehicle_visit_repository_test.dart`

## Files Updated

- `lib/application/morning_sovereign_report_service.dart`
- `lib/main.dart`
- `test/application/morning_sovereign_report_service_test.dart`

## Implementation Notes

- Migration
  - Added `public.vehicle_visits` with the composite upsert key on:
    - `(client_id, site_id, vehicle_key, started_at_utc)`
  - Added `public.hourly_throughput` with the unique key on:
    - `(client_id, site_id, visit_date, hour_of_day)`
  - Enabled RLS on both tables.
  - Added select policies scoped by `public.onyx_client_id()`.
  - Left writes to service-role/backend paths only.

- Repository
  - Added `VehicleVisitRepository` interface plus `SupabaseVehicleVisitRepository`.
  - Added:
    - `upsertVisit(VehicleVisitRecord visit, {required DateTime nowUtc})`
    - `upsertHourlyThroughput(..., {required Iterable<VehicleVisitRecord> visits, required DateTime nowUtc})`
    - `listVisitsForClient(...)` for persistence verification / read-path tests
  - Visit rows persist:
    - UTC timestamps
    - visit status
    - dwell
    - exception flags
    - event/intelligence/zone linkage arrays
  - Hourly rows persist:
    - UTC `visit_date`
    - `visit_count`
    - `completed_count`
    - `entry_count`
    - `exit_count`
    - `service_count`
    - `avg_dwell_minutes`

- Morning sovereign report hook
  - `MorningSovereignReportService` now accepts an optional BI repository.
  - After throughput is computed, it schedules persistence in a non-blocking async path.
  - Persistence is per scope and then per UTC date bucket.
  - Any persist failure is logged and swallowed so report generation never throws.

- Runtime wiring
  - `main.dart` now constructs `MorningSovereignReportService` with `SupabaseVehicleVisitRepository(Supabase.instance.client)` in the live morning report generation path.

- Step 5 verification
  - `SovereignReportVehicleThroughput.hourlyBreakdown` was already present in repo state before this batch.
  - No additional model patch was required there.

## Validation

- Targeted analyze after migration: passed
- Targeted analyze after repository: passed
- Targeted analyze after service/runtime wiring: passed
- Final full `dart analyze`: passed

- Focused tests passed:
  - `test/infrastructure/bi/vehicle_visit_repository_test.dart`
  - `test/application/morning_sovereign_report_service_test.dart`

## Test Coverage Added

- Repository
  - upsert creates a new vehicle visit row
  - upsert updates an existing row idempotently
  - cross-client read is rejected in the RLS-style path

- Service
  - failed BI persistence logs an error and does not crash report generation

## Follow-Up

- `hourly_throughput` currently writes only non-zero hours.
- No `zone_analytics` schema or write path exists yet by design.
- No dashboard read/query layer was added in this batch beyond the minimal repository verification seam.
