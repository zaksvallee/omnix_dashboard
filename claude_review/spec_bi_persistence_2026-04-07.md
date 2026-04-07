# Spec: Supabase BI Persistence Layer — ONYX Vehicle Analytics

- Date: 2026-04-07
- Author: Claude Code
- Scope: `vehicle_visits`, `zone_analytics`, `hourly_throughput` Supabase tables
- Read-only: yes — this is a design spec, not implemented code
- Upstream audit: `audit_bi_foundation_2026-04-07.md`

---

## Context

The BI analytics engine is fully built in-memory. `VehicleVisitLedgerProjector` projects
`IntelligenceReceived` events into `VehicleVisitRecord` objects. `MorningSovereignReportService`
aggregates these into `SovereignReportVehicleThroughput`. Neither writes to Supabase — the full
pipeline is ephemeral and resets each session.

This spec defines the minimal Supabase persistence layer to support:

- per-visit historical records (license plate, dwell, zone funnel, exceptions)
- hourly throughput timeseries (bar charts, peak-hour comparisons)
- zone-stage aggregates (entry → service → exit funnel per day)
- day-over-day and week-over-week BI queries
- row-level security isolating each client's data

The design is grounded in the actual domain models at:

- `lib/application/vehicle_visit_ledger_projector.dart` — `VehicleVisitRecord`, `VehicleThroughputSummary`
- `lib/application/morning_sovereign_report_service.dart:1097` — `SovereignReportVehicleThroughput`
- `lib/domain/events/intelligence_received.dart` — `IntelligenceReceived`
- `lib/infrastructure/events/supabase_client_ledger_repository.dart` — existing Supabase pattern

---

## 1. Table Schemas

### 1.1 `vehicle_visits`

One row per closed `VehicleVisitRecord`. Maps directly to the domain model. Written when a visit
is finalised — either at exit detection or when the visit goes stale (`>= 45 min` since last seen).

```sql
CREATE TABLE public.vehicle_visits (
  id                    uuid        PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Scope keys — match VehicleVisitRecord.clientId / siteId
  client_id             text        NOT NULL,
  site_id               text        NOT NULL,

  -- Identity — match VehicleVisitRecord.vehicleKey / plateNumber
  vehicle_key           text        NOT NULL,   -- normalised: uppercase, no spaces
  plate_number          text        NOT NULL,   -- raw plate label for display

  -- Timing — all UTC, match VehicleVisitRecord timestamps
  started_at_utc        timestamptz NOT NULL,
  last_seen_at_utc      timestamptz NOT NULL,
  completed_at_utc      timestamptz,            -- NULL when incomplete or active at write time

  -- Zone funnel booleans — match VehicleVisitRecord.sawEntry/sawService/sawExit
  saw_entry             boolean     NOT NULL DEFAULT false,
  saw_service           boolean     NOT NULL DEFAULT false,
  saw_exit              boolean     NOT NULL DEFAULT false,

  -- Derived metrics — stored for query efficiency (avoids recomputing on read)
  dwell_minutes         double precision,       -- (completed_at_utc ?? last_seen_at_utc) - started_at_utc
  visit_status          text        NOT NULL,   -- 'completed' | 'incomplete' | 'active'

  -- Exception flags — match VehicleThroughputSummary exception classification
  is_suspicious_short   boolean     NOT NULL DEFAULT false,  -- dwell < 2 min AND completed
  is_loitering          boolean     NOT NULL DEFAULT false,  -- dwell >= 30 min

  -- Evidence linkage — match VehicleVisitRecord.eventIds / intelligenceIds / zoneLabels
  event_count           int         NOT NULL DEFAULT 0,
  event_ids             text[]      NOT NULL DEFAULT '{}',
  intelligence_ids      text[]      NOT NULL DEFAULT '{}',
  zone_labels           text[]      NOT NULL DEFAULT '{}',

  created_at            timestamptz NOT NULL DEFAULT now()
);

-- Primary query path: per-scope historical range reads
CREATE INDEX vehicle_visits_scope_started
  ON public.vehicle_visits (client_id, site_id, started_at_utc DESC);

-- Repeat-visitor queries: group by plate within scope
CREATE INDEX vehicle_visits_scope_plate
  ON public.vehicle_visits (client_id, site_id, vehicle_key, started_at_utc DESC);

-- Exception queries: filter by flag within scope
CREATE INDEX vehicle_visits_scope_exception
  ON public.vehicle_visits (client_id, site_id, is_loitering, is_suspicious_short, started_at_utc DESC);
```

**Field mapping to `VehicleVisitRecord`:**

| Dart field              | Column                | Notes                                          |
|-------------------------|-----------------------|------------------------------------------------|
| `clientId`              | `client_id`           | Direct                                         |
| `siteId`                | `site_id`             | Direct                                         |
| `vehicleKey`            | `vehicle_key`         | `_normalizePlate()` output — uppercased, trimmed |
| `plateNumber`           | `plate_number`        | Raw plate for display                          |
| `startedAtUtc`          | `started_at_utc`      | Direct ISO 8601 UTC                            |
| `lastSeenAtUtc`         | `last_seen_at_utc`    | Direct                                         |
| `completedAtUtc`        | `completed_at_utc`    | Nullable                                       |
| `sawEntry`              | `saw_entry`           | Direct                                         |
| `sawService`            | `saw_service`         | Direct                                         |
| `sawExit`               | `saw_exit`            | Direct                                         |
| `dwell` (computed)      | `dwell_minutes`       | `dwell.inSeconds / 60.0` — stored for indexing |
| `statusAt(nowUtc)`      | `visit_status`        | Computed at write time                         |
| `eventCount`            | `event_count`         | Direct                                         |
| `eventIds`              | `event_ids`           | List<String> → text[]                          |
| `intelligenceIds`       | `intelligence_ids`    | List<String> → text[]                          |
| `zoneLabels`            | `zone_labels`         | List<String> → text[]                          |

---

### 1.2 `hourly_throughput`

One row per `(client_id, site_id, visit_date, hour_of_day)`. Written (upserted) at the end of
each monitoring session when `MorningSovereignReportService` finalises its report. The `visitsByHour`
map computed at `morning_sovereign_report_service.dart:2178` (currently discarded after peak-hour
extraction — see P1 audit finding) feeds directly into these rows.

```sql
CREATE TABLE public.hourly_throughput (
  id                    uuid        PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Scope keys
  client_id             text        NOT NULL,
  site_id               text        NOT NULL,

  -- Time bucket — local date + 0-23 hour slot
  visit_date            date        NOT NULL,   -- e.g. 2026-04-07 (local site date)
  hour_of_day           int         NOT NULL CHECK (hour_of_day >= 0 AND hour_of_day <= 23),

  -- Counts — derived from the visitsByHour + per-status folds
  visit_count           int         NOT NULL DEFAULT 0,     -- total visits started in this hour
  completed_count       int         NOT NULL DEFAULT 0,     -- completed visits started in this hour
  entry_count           int         NOT NULL DEFAULT 0,     -- visits with sawEntry=true
  exit_count            int         NOT NULL DEFAULT 0,     -- visits with sawExit=true
  service_count         int         NOT NULL DEFAULT 0,     -- visits with sawService=true

  -- Dwell — avg over completed visits in this hour
  avg_dwell_minutes     double precision,

  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),

  -- One row per (client, site, date, hour) — upsert on conflict
  UNIQUE (client_id, site_id, visit_date, hour_of_day)
);

-- Primary query path: date-range reads for chart rendering
CREATE INDEX hourly_throughput_scope_date
  ON public.hourly_throughput (client_id, site_id, visit_date DESC, hour_of_day);
```

**Dependency note:** populating `service_count` requires retaining `sawService` per visit in the
per-hour fold. The current `_buildVehicleThroughput` loop (`morning_sovereign_report_service.dart:2189`)
does not aggregate `sawService` — Codex must add this fold alongside the existing `sawEntry`/`sawExit`
counts before inserting `hourly_throughput` rows.

---

### 1.3 `zone_analytics`

One row per `(client_id, site_id, report_date, zone_stage)`. Written once per day per scope after
the daily sovereign report runs. Provides the funnel shape for a given day — how many vehicles were
seen at each stage and what fell out between stages.

```sql
CREATE TABLE public.zone_analytics (
  id                    uuid        PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Scope keys
  client_id             text        NOT NULL,
  site_id               text        NOT NULL,

  -- Time key
  report_date           date        NOT NULL,

  -- Zone stage — maps to VehicleVisitZoneStage enum values
  zone_stage            text        NOT NULL CHECK (
                          zone_stage IN ('entry', 'service', 'exit', 'unknown')
                        ),

  -- Counts
  visit_count           int         NOT NULL DEFAULT 0,   -- distinct visits that reached this stage
  completed_from_stage  int         NOT NULL DEFAULT 0,   -- completed visits that saw this stage (funnel denominator)

  -- Dwell at this stage — applicable to service stage when per-zone timestamps exist
  -- Phase 1: NULL (per-zone timestamps not yet recorded)
  -- Phase 2: populated once _MutableVehicleVisit.absorb() records zone-entry timestamps
  avg_stage_dwell_minutes double precision,

  -- Peak hour within this zone stage
  peak_hour             int CHECK (peak_hour >= 0 AND peak_hour <= 23),
  peak_hour_count       int         NOT NULL DEFAULT 0,

  created_at            timestamptz NOT NULL DEFAULT now(),

  UNIQUE (client_id, site_id, report_date, zone_stage)
);

CREATE INDEX zone_analytics_scope_date
  ON public.zone_analytics (client_id, site_id, report_date DESC);
```

**Phase 1 limitation:** `avg_stage_dwell_minutes` will be NULL for all rows until the audit P2
finding (per-zone dwell) is addressed — `_MutableVehicleVisit.absorb()` must record zone-entry
timestamps. This column is defined now so the schema does not need migration when Phase 2 lands.

---

## 2. What Gets Written After Each YOLO Detection Event

An `IntelligenceReceived` event with `sourceType = 'dvr'` and a non-empty `plateNumber` arrives
from the DVR bridge. The write sequence has three distinct triggers:

### Trigger A — Visit closure (near-real-time, per-vehicle)

Fires when `VehicleVisitLedgerProjector` sees an exit zone event for a tracked plate, setting
`sawExit = true` and `completedAtUtc` on the `_MutableVehicleVisit`. At this point the visit is
fully resolved and safe to write.

```
IntelligenceReceived (zone='Exit Lane', plateNumber='CA123456', sourceType='dvr')
  → VehicleVisitLedgerProjector._classifyZoneStage() → VehicleVisitZoneStage.exit
  → _MutableVehicleVisit.absorb() → sawExit=true, completedAtUtc=event.occurredAt
  → VehicleVisitRecord toRecord() → write to vehicle_visits (upsert on vehicle_key + started_at_utc)
```

**Row written to `vehicle_visits`:**

```json
{
  "client_id": "client_abc",
  "site_id": "site_main",
  "vehicle_key": "CA123456",
  "plate_number": "CA123456",
  "started_at_utc": "2026-04-07T07:42:15Z",
  "last_seen_at_utc": "2026-04-07T07:51:03Z",
  "completed_at_utc": "2026-04-07T07:51:03Z",
  "saw_entry": true,
  "saw_service": true,
  "saw_exit": true,
  "dwell_minutes": 8.8,
  "visit_status": "completed",
  "is_suspicious_short": false,
  "is_loitering": false,
  "event_count": 4,
  "event_ids": ["evt_001", "evt_002", "evt_003", "evt_004"],
  "intelligence_ids": ["int_a", "int_b", "int_c", "int_d"],
  "zone_labels": ["Entry Lane", "Wash Bay 1", "Exit Lane"]
}
```

### Trigger B — Stale visit sweep (deferred, batch)

When the monitoring watch runtime sweeps for stale visits (`statusAt(nowUtc)` returns `incomplete`),
incomplete `VehicleVisitRecord` objects are upserted to `vehicle_visits` with `visit_status = 'incomplete'`
and `completed_at_utc = NULL`. This captures drive-offs and vehicles that bypassed the exit zone.

### Trigger C — Daily sovereign report (end of session, batch)

When `MorningSovereignReportService` finalises its report, all `hourly_throughput` and
`zone_analytics` rows for the session date are upserted. This is a single write pass per scope.

**Rows written to `hourly_throughput`** (one per non-zero hour):

```json
[
  {
    "client_id": "client_abc",
    "site_id": "site_main",
    "visit_date": "2026-04-07",
    "hour_of_day": 7,
    "visit_count": 12,
    "completed_count": 10,
    "entry_count": 12,
    "exit_count": 10,
    "service_count": 11,
    "avg_dwell_minutes": 8.3
  }
]
```

**Rows written to `zone_analytics`** (one per stage observed):

```json
[
  { "zone_stage": "entry",   "visit_count": 47, "completed_from_stage": 43 },
  { "zone_stage": "service", "visit_count": 44, "completed_from_stage": 43 },
  { "zone_stage": "exit",    "visit_count": 43, "completed_from_stage": 43 }
]
```

### Upsert key per table

| Table                | Upsert conflict target                                        |
|----------------------|---------------------------------------------------------------|
| `vehicle_visits`     | `(client_id, site_id, vehicle_key, started_at_utc)` — add unique index |
| `hourly_throughput`  | `(client_id, site_id, visit_date, hour_of_day)` — already UNIQUE |
| `zone_analytics`     | `(client_id, site_id, report_date, zone_stage)` — already UNIQUE |

Note: `vehicle_visits` needs a composite unique index on
`(client_id, site_id, vehicle_key, started_at_utc)` to enable safe upserts. The primary key `id`
is internal and cannot be used for idempotent re-writes.

```sql
CREATE UNIQUE INDEX vehicle_visits_upsert_key
  ON public.vehicle_visits (client_id, site_id, vehicle_key, started_at_utc);
```

---

## 3. Historical Data Query Patterns

All queries are scoped to `client_id` and filtered by `site_id`. RLS enforces `client_id` at the
database level — see Section 4. Queries are shown as parameterised SQL; the Flutter layer uses the
Supabase Dart client with `.eq()` / `.gte()` / `.lte()` chaining.

### 3.1 Day-over-day throughput (week or month summary)

```sql
SELECT
  visit_date,
  SUM(visit_count)           AS total_visits,
  SUM(completed_count)       AS completed_visits,
  SUM(entry_count)           AS entry_count,
  SUM(exit_count)            AS exit_count,
  AVG(avg_dwell_minutes)     AS avg_dwell_minutes
FROM public.hourly_throughput
WHERE client_id = $1
  AND site_id   = $2
  AND visit_date BETWEEN $3 AND $4   -- e.g. '2026-03-31' to '2026-04-07'
GROUP BY visit_date
ORDER BY visit_date DESC;
```

Feeds: weekly/monthly KPI cards — total visits per day, completion rate trend, dwell trend.

### 3.2 Hourly bar chart for a single day

```sql
SELECT
  hour_of_day,
  visit_count,
  completed_count,
  avg_dwell_minutes
FROM public.hourly_throughput
WHERE client_id  = $1
  AND site_id    = $2
  AND visit_date = $3                 -- e.g. '2026-04-07'
ORDER BY hour_of_day;
```

Returns up to 24 rows. Missing hours (zero traffic) are absent — the UI fills gaps with zero.
Feeds: hourly bar chart widget for `VehicleBiDashboardPanel` (audit Step 2).

### 3.3 Entry → Service → Exit funnel for a day

```sql
SELECT
  COUNT(*)                             FILTER (WHERE saw_entry)                          AS entry_count,
  COUNT(*)                             FILTER (WHERE saw_service)                        AS service_count,
  COUNT(*)                             FILTER (WHERE saw_exit)                           AS exit_count,
  COUNT(*)                             FILTER (WHERE saw_entry AND saw_service AND saw_exit) AS full_funnel_count,
  COUNT(*)                             FILTER (WHERE saw_entry AND NOT saw_exit)         AS queue_abandonment_count,
  ROUND(AVG(dwell_minutes)::numeric, 1) FILTER (WHERE visit_status = 'completed')        AS avg_completed_dwell
FROM public.vehicle_visits
WHERE client_id  = $1
  AND site_id    = $2
  AND started_at_utc >= $3::date::timestamptz
  AND started_at_utc <  ($3::date + 1)::timestamptz;
```

Feeds: funnel widget — entry bucket → service bucket → exit bucket with drop-off percentages.
`queue_abandonment_count` surfaces vehicles that entered but never reached exit — key KPI for
carwash / filling station.

### 3.4 Repeat visitor plates (loyal customers — trailing 7 days)

```sql
SELECT
  vehicle_key,
  COUNT(*)                        AS visit_count,
  MAX(started_at_utc)             AS last_seen_utc,
  ROUND(AVG(dwell_minutes)::numeric, 1) AS avg_dwell_minutes
FROM public.vehicle_visits
WHERE client_id  = $1
  AND site_id    = $2
  AND started_at_utc >= NOW() - INTERVAL '7 days'
GROUP BY vehicle_key
HAVING COUNT(*) > 1
ORDER BY visit_count DESC
LIMIT 20;
```

Feeds: repeat-visitor list widget (audit P2 finding — `topRepeatPlates` surface).

### 3.5 Exception visits — loitering / suspicious short (last 24 h)

```sql
SELECT
  plate_number,
  dwell_minutes,
  visit_status,
  zone_labels,
  started_at_utc,
  is_suspicious_short,
  is_loitering
FROM public.vehicle_visits
WHERE client_id      = $1
  AND site_id        = $2
  AND (is_loitering OR is_suspicious_short)
  AND started_at_utc >= NOW() - INTERVAL '24 hours'
ORDER BY started_at_utc DESC;
```

Feeds: exception table in `VehicleBiDashboardPanel` (audit Step 2 — `exceptionVisits` list).

### 3.6 Zone funnel by stage (from `zone_analytics`)

```sql
SELECT zone_stage, visit_count, completed_from_stage, peak_hour, peak_hour_count
FROM public.zone_analytics
WHERE client_id   = $1
  AND site_id     = $2
  AND report_date = $3
ORDER BY
  CASE zone_stage
    WHEN 'entry'   THEN 1
    WHEN 'service' THEN 2
    WHEN 'exit'    THEN 3
    ELSE 4
  END;
```

Returns 3–4 rows (one per stage). Feeds zone funnel view when individual `vehicle_visits` rows are
not needed.

### 3.7 Peak-hour comparison across days

```sql
SELECT
  visit_date,
  hour_of_day       AS peak_hour,
  visit_count       AS peak_visit_count
FROM public.hourly_throughput
WHERE client_id  = $1
  AND site_id    = $2
  AND visit_date BETWEEN $3 AND $4
ORDER BY visit_date DESC, visit_count DESC;
```

Returns the highest-traffic hour per day when the application takes the first row per date. Feeds
a "peak hour shifts over the week" trend table.

---

## 4. Row-Level Security Per Client

### 4.1 Threat model

Each ONYX operator is scoped to exactly one `client_id`. An operator for `client_abc` must never
read `vehicle_visits` rows for `client_xyz`. Supabase RLS enforces this at the database level so
that even a misconfigured application layer cannot leak cross-client data.

Writes are made exclusively by the ONYX backend service using the Supabase service-role key. The
service-role key bypasses RLS by design. No INSERT / UPDATE / DELETE policies are granted to
authenticated operators.

### 4.2 JWT claim approach (preferred)

The ONYX backend embeds `client_id` as a custom JWT claim when issuing the Supabase session token
for an operator. This mirrors the pattern already used for `client_evidence_ledger`
(`lib/infrastructure/events/supabase_client_ledger_repository.dart`).

```sql
-- Enable RLS on all three tables
ALTER TABLE public.vehicle_visits      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hourly_throughput   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.zone_analytics      ENABLE ROW LEVEL SECURITY;

-- SELECT: operators may read only rows matching their JWT client_id claim
CREATE POLICY "operator_select_own_client_vehicle_visits"
  ON public.vehicle_visits
  FOR SELECT
  USING (client_id = (auth.jwt() ->> 'client_id'));

CREATE POLICY "operator_select_own_client_hourly_throughput"
  ON public.hourly_throughput
  FOR SELECT
  USING (client_id = (auth.jwt() ->> 'client_id'));

CREATE POLICY "operator_select_own_client_zone_analytics"
  ON public.zone_analytics
  FOR SELECT
  USING (client_id = (auth.jwt() ->> 'client_id'));

-- No INSERT / UPDATE / DELETE policies for authenticated role.
-- All writes go through the service role key (bypasses RLS).
```

The `client_id` claim must be a non-forgeable server-set claim embedded at session creation time.
Supabase supports this via `supabase.auth.admin.createToken({ claims: { client_id: '...' } })` on
the backend.

### 4.3 Membership table approach (fallback if JWT claim is not available)

If the JWT claim path is not available during Phase 1, a membership ACL table can gate reads:

```sql
CREATE TABLE public.client_memberships (
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  client_id  text NOT NULL,
  PRIMARY KEY (user_id, client_id)
);

-- RLS policy uses ACL join instead of JWT claim
CREATE POLICY "operator_select_own_client_via_membership"
  ON public.vehicle_visits
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.client_memberships
      WHERE user_id   = auth.uid()
        AND client_id = vehicle_visits.client_id
    )
  );
```

Apply the same policy pattern to `hourly_throughput` and `zone_analytics`.

**Trade-off:** The membership join adds latency on every query. The JWT claim approach avoids the
join entirely. The JWT approach is recommended; the membership table is a safe interim.

### 4.4 Multi-site operators

Some operators may have access to multiple sites within the same `client_id`. Site-level isolation
within a client is an application-layer concern (filter by `site_id` in queries). RLS enforces
`client_id` isolation; site filtering is applied in the query `WHERE` clause, not in the RLS
policy. This matches the existing pattern in `SupabaseClientLedgerRepository` where queries filter
both `client_id` and `dispatch_id` explicitly.

---

## 5. Write Architecture — Where the Repository Lives

The Flutter codebase follows the pattern established by `SupabaseClientLedgerRepository`:
one repository class per table group, injected via the existing service locator.

**Recommended repository interface (read-only spec — not implemented):**

```
VehicleBiRepository (interface, in lib/domain/bi/)
  └── SupabaseVehicleBiRepository (impl, in lib/infrastructure/bi/)
        ├── upsertVisit(VehicleVisitRecord, DateTime nowUtc) → Future<void>
        ├── upsertHourlyThroughput(String clientId, String siteId, DateTime date, Map<int,int> visitsByHour, ...) → Future<void>
        ├── upsertZoneAnalytics(String clientId, String siteId, DateTime date, VehicleThroughputSummary) → Future<void>
        ├── queryVisitsByDateRange(String clientId, String siteId, DateTime from, DateTime to) → Future<List<VehicleVisitRow>>
        ├── queryHourlyBreakdown(String clientId, String siteId, DateTime date) → Future<List<HourlyThroughputRow>>
        └── queryRepeatPlates(String clientId, String siteId, int trailingDays) → Future<List<RepeatPlateRow>>
```

**Write trigger integration points:**

| Trigger | Caller | Method |
|---------|--------|--------|
| Visit closure (exit event) | `MonitoringWatchRuntimeStore` or equivalent coordinator | `upsertVisit()` |
| Stale sweep | Existing stale-detection path in watch runtime | `upsertVisit()` (incomplete status) |
| Daily report finalisation | `MorningSovereignReportService` or its caller | `upsertHourlyThroughput()` + `upsertZoneAnalytics()` |

---

## 6. Decisions Required Before Implementation

| # | Decision | Options | Impact |
|---|----------|---------|--------|
| D1 | JWT claim vs. membership table for RLS | JWT claim (no join latency) vs. ACL table (simpler backend) | Blocks RLS implementation |
| D2 | Write trigger location for visit closure | `MonitoringWatchRuntimeStore` vs. post-projection hook in `MorningSovereignReportService` | Affects how near-real-time the `vehicle_visits` table is |
| D3 | `hourly_throughput` write frequency | Once at end of day vs. rolling upsert per visit | More frequent upserts give live chart refresh; once-per-day is simpler |
| D4 | `visit_date` timezone convention | UTC calendar date vs. local site date | Carwash clients will expect local dates on reports |
| D5 | Phase 1 scope | Implement all three tables at once vs. `vehicle_visits` only first | `vehicle_visits` alone unblocks repeat-visitor and exception queries |

---

## 7. Phase 1 Minimum Viable Persistence

If the goal is a working carwash BI demo without over-engineering:

1. Implement `vehicle_visits` only.
2. All three historical query patterns (funnel, repeat visitors, exceptions) work from `vehicle_visits` alone.
3. `hourly_throughput` can be derived at query time with a `date_trunc('hour', started_at_utc)` GROUP BY — slower but correct for demo volumes.
4. `zone_analytics` is a pre-aggregation optimisation for production scale. Not needed for PoC.

This reduces the initial implementation to one table, one repository class, and three query methods.

---

## 8. Open Risks

| Risk | Severity | Note |
|------|----------|------|
| `hourlyBreakdown` not retained by `_buildVehicleThroughput` (P1 audit finding) | High | `hourly_throughput` rows cannot be populated without this fix. Codex must retain `visitsByHour` before inserting rows. |
| No per-zone timestamps — `avg_stage_dwell_minutes` cannot be populated | Medium | `zone_analytics.avg_stage_dwell_minutes` will be NULL in Phase 1. Acceptable for PoC. |
| `vehicle_visits` upsert requires composite unique index | Medium | Without `(client_id, site_id, vehicle_key, started_at_utc)` unique index, concurrent writes may duplicate rows. Must be created before writes begin. |
| JWT custom claim setup is a backend task | Low | ONYX backend must embed `client_id` in the Supabase JWT. If this is not already done, the membership table fallback must be used in Phase 1. |
| `visit_date` timezone mismatch | Low | If `started_at_utc` is used directly as a date, a visit starting at 23:00 UTC in Africa/Johannesburg (UTC+2) will land on the wrong date. The write layer must convert to local site date before writing `visit_date`. |
