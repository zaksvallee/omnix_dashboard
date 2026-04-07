# Spec Review: BI Analytics Migration SQL

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `202604070002_bi_analytics_tables.sql` — `vehicle_visits`, `hourly_throughput`, `zone_analytics`
- Read-only: yes
- Upstream spec: `spec_bi_persistence_2026-04-07.md`

---

## Role Boundary Note

The task requested creating a `.sql` file at
`supabase/migrations/202604070002_bi_analytics_tables.sql`.

Per `CLAUDE_CODE_ROLE.md`:

> Claude Code writes only to `/claude_review/`. Allowed file types: `*.md`.

This report contains the fully-reviewed migration SQL as a code block.
**Codex must create the actual `.sql` file** at the target path using the corrected SQL below.

---

## Executive Summary

The spec SQL is structurally correct and schema-complete. However, it was written using raw
`auth.jwt()` calls and a generic policy-naming style that diverges from every existing ONYX
migration. Five categories of deviation must be corrected before the migration will align with
the live codebase conventions. All deviations are mechanical — no schema design changes required.

The corrected SQL is provided in full in Section 3.

---

## Deviations Found

### DEV-1 — RLS uses raw `auth.jwt()` instead of codebase helpers
- **Action: AUTO**
- **Spec pattern:** `client_id = (auth.jwt() ->> 'client_id')`
- **Codebase pattern:** `client_id = public.onyx_client_id()`
- The ONYX codebase defines `public.onyx_client_id()`, `public.onyx_has_site()`, and
  `public.onyx_is_control_role()` in migration `202603050003`. All subsequent RLS policies
  use these helpers — see `202603150001_create_site_identity_registry_tables.sql` lines 183–193.
- Using raw `auth.jwt()` is not wrong at the Postgres level, but it diverges from the
  established abstraction and creates inconsistency if the JWT claim name ever changes.
- **Fix:** Replace `(auth.jwt() ->> 'client_id')` with `public.onyx_client_id()` in all policies.

### DEV-2 — Policies missing `to authenticated` role scoping
- **Action: AUTO**
- **Spec pattern:** `CREATE POLICY "..." ON ... FOR SELECT USING (...)`
- **Codebase pattern:** `create policy ... on ... for select to authenticated using (...)`
- Every ONYX policy includes `to authenticated`. Without it the policy applies to all roles
  including `anon`, which is overly permissive.
- **Fix:** Add `to authenticated` to all three SELECT policies.

### DEV-3 — Policy names use quoted mixed-case; codebase uses unquoted snake_case
- **Action: AUTO**
- **Spec pattern:** `"operator_select_own_client_vehicle_visits"`
- **Codebase pattern:** `vehicle_visits_select_policy` (unquoted, snake_case suffix `_select_policy`)
- Double-quoted names are case-sensitive in Postgres. Using unquoted names matches the
  existing migration convention throughout the codebase.
- **Fix:** Rename policies to `vehicle_visits_select_policy`,
  `hourly_throughput_select_policy`, `zone_analytics_select_policy`.

### DEV-4 — `created_at` default uses `now()` instead of `timezone('utc', now())`
- **Action: AUTO**
- **Spec pattern:** `DEFAULT now()`
- **Codebase pattern:** `default timezone('utc', now())`
- All ONYX tables use the explicit UTC form. `now()` returns a `timestamptz` which is
  always UTC in Postgres, so this is a convention issue not a bug — but it should match.
- **Fix:** Replace `DEFAULT now()` with `default timezone('utc', now())` on all `created_at`
  and `updated_at` column defaults.

### DEV-5 — `hourly_throughput.updated_at` has no trigger
- **Action: REVIEW**
- The `hourly_throughput` table has an `updated_at` column but the spec defines no trigger to
  keep it current on `UPDATE`. The codebase pattern uses
  `public.set_guard_directory_updated_at()` triggered `before update` (see
  `202603150001` lines 164–169).
- Without a trigger, `updated_at` will be set at row creation time and never advance on upsert,
  making it useless for change detection.
- **Decision for Codex:** Confirm `public.set_guard_directory_updated_at()` is a generic helper
  (not guard-specific) before wiring it. If it is generic, add the trigger. If it is guard-only,
  either create a new generic helper or drop `updated_at` from `hourly_throughput` entirely.
- The corrected SQL below adds the trigger assuming the function is generic (it is — the
  function body is `new.updated_at := now(); return new;` based on the source migration).

### DEV-6 — `if not exists` guards absent from `CREATE TABLE` and `CREATE INDEX`
- **Action: AUTO**
- All existing migrations use `create table if not exists` and `create index if not exists`.
- Without guards, a re-run of the migration (e.g. during local reset) will error on conflict.
- **Fix:** Add `if not exists` to all `CREATE TABLE` and `CREATE INDEX` statements.

### DEV-7 — `drop policy if exists` absent before `create policy`
- **Action: AUTO**
- Migration `202603150001` drops each policy before recreating it:
  `drop policy if exists <name> on <table>;`
- This makes migrations idempotent on re-run. The spec omits this pattern.
- **Fix:** Add `drop policy if exists` before each `create policy`.

### DEV-8 — FK references to `public.sites` absent
- **Action: REVIEW**
- Every ONYX table with `(client_id, site_id)` references `public.sites (client_id, site_id)`
  via a named FK constraint (e.g. `constraint <table>_site_fk foreign key (client_id, site_id)
  references public.sites (client_id, site_id) on delete cascade`).
- The spec omits these FK constraints on all three BI tables.
- **Decision for Codex:** Adding FK constraints means rows cannot be inserted for
  `(client_id, site_id)` pairs that do not exist in `public.sites`. This is correct for all
  existing ONYX tables. Confirm that every site monitored by the BI pipeline will always have
  a matching row in `public.sites` before the first visit write. If yes, add the FKs as shown
  in the corrected SQL. If there is a race (site created lazily), defer the FK.

### DEV-9 — `zone_analytics` included in spec but omitted from task title
- **Action: REVIEW**
- The task description specifies "vehicle_visits and hourly_throughput tables". The upstream
  spec `spec_bi_persistence_2026-04-07.md` defines a third table `zone_analytics`.
- The corrected SQL below includes all three tables as defined in the spec, since they are
  part of the same migration file described in the spec. Codex should confirm with Zaks whether
  all three are in scope for this migration or only two.

---

## Corrected Migration SQL

This SQL uses ONYX migration conventions throughout. Codex should copy this verbatim to
`supabase/migrations/202604070002_bi_analytics_tables.sql`.

```sql
-- BI Analytics Tables: vehicle_visits, hourly_throughput, zone_analytics
-- Spec: claude_review/spec_bi_persistence_2026-04-07.md
-- Codex target: supabase/migrations/202604070002_bi_analytics_tables.sql

-- ============================================================
-- vehicle_visits
-- One row per closed VehicleVisitRecord.
-- Written at exit detection (completed) or stale sweep (incomplete).
-- ============================================================

create table if not exists public.vehicle_visits (
  id                    uuid        primary key default gen_random_uuid(),

  -- Scope keys
  client_id             text        not null
    references public.clients (client_id)
    on delete cascade,
  site_id               text        not null,

  -- Identity
  vehicle_key           text        not null,   -- normalised: uppercase, no spaces
  plate_number          text        not null,   -- raw plate label for display

  -- Timing (all UTC)
  started_at_utc        timestamptz not null,
  last_seen_at_utc      timestamptz not null,
  completed_at_utc      timestamptz,            -- null when incomplete or active at write time

  -- Zone funnel booleans
  saw_entry             boolean     not null default false,
  saw_service           boolean     not null default false,
  saw_exit              boolean     not null default false,

  -- Derived metrics
  dwell_minutes         double precision,
  visit_status          text        not null,

  -- Exception flags
  is_suspicious_short   boolean     not null default false,
  is_loitering          boolean     not null default false,

  -- Evidence linkage
  event_count           int         not null default 0,
  event_ids             text[]      not null default '{}',
  intelligence_ids      text[]      not null default '{}',
  zone_labels           text[]      not null default '{}',

  created_at            timestamptz not null default timezone('utc', now()),

  constraint vehicle_visits_site_fk
    foreign key (client_id, site_id)
    references public.sites (client_id, site_id)
    on delete cascade,

  constraint vehicle_visits_visit_status_valid
    check (visit_status in ('completed', 'incomplete', 'active')),

  constraint vehicle_visits_plate_number_not_blank
    check (length(btrim(plate_number)) > 0),

  constraint vehicle_visits_vehicle_key_not_blank
    check (length(btrim(vehicle_key)) > 0)
);

-- Upsert key: idempotent re-writes on exit/stale trigger
create unique index if not exists vehicle_visits_upsert_key
  on public.vehicle_visits (client_id, site_id, vehicle_key, started_at_utc);

-- Primary query path: per-scope historical range reads
create index if not exists vehicle_visits_scope_started
  on public.vehicle_visits (client_id, site_id, started_at_utc desc);

-- Repeat-visitor queries
create index if not exists vehicle_visits_scope_plate
  on public.vehicle_visits (client_id, site_id, vehicle_key, started_at_utc desc);

-- Exception queries
create index if not exists vehicle_visits_scope_exception
  on public.vehicle_visits (client_id, site_id, is_loitering, is_suspicious_short, started_at_utc desc);

-- ============================================================
-- hourly_throughput
-- One row per (client_id, site_id, visit_date, hour_of_day).
-- Upserted at end of each monitoring session.
-- ============================================================

create table if not exists public.hourly_throughput (
  id                    uuid        primary key default gen_random_uuid(),

  -- Scope keys
  client_id             text        not null
    references public.clients (client_id)
    on delete cascade,
  site_id               text        not null,

  -- Time bucket
  visit_date            date        not null,
  hour_of_day           int         not null,

  -- Counts
  visit_count           int         not null default 0,
  completed_count       int         not null default 0,
  entry_count           int         not null default 0,
  exit_count            int         not null default 0,
  service_count         int         not null default 0,

  -- Dwell average over completed visits in this hour
  avg_dwell_minutes     double precision,

  created_at            timestamptz not null default timezone('utc', now()),
  updated_at            timestamptz not null default timezone('utc', now()),

  constraint hourly_throughput_site_fk
    foreign key (client_id, site_id)
    references public.sites (client_id, site_id)
    on delete cascade,

  constraint hourly_throughput_hour_range
    check (hour_of_day >= 0 and hour_of_day <= 23),

  -- Upsert key
  unique (client_id, site_id, visit_date, hour_of_day)
);

-- Primary query path: date-range reads for chart rendering
create index if not exists hourly_throughput_scope_date
  on public.hourly_throughput (client_id, site_id, visit_date desc, hour_of_day);

-- Trigger: keep updated_at current on upsert
drop trigger if exists set_hourly_throughput_updated_at
  on public.hourly_throughput;
create trigger set_hourly_throughput_updated_at
  before update on public.hourly_throughput
  for each row
  execute function public.set_guard_directory_updated_at();

-- ============================================================
-- zone_analytics
-- One row per (client_id, site_id, report_date, zone_stage).
-- Upserted once per day after the daily sovereign report runs.
-- ============================================================

create table if not exists public.zone_analytics (
  id                    uuid        primary key default gen_random_uuid(),

  -- Scope keys
  client_id             text        not null
    references public.clients (client_id)
    on delete cascade,
  site_id               text        not null,

  -- Time key
  report_date           date        not null,

  -- Zone stage
  zone_stage            text        not null,

  -- Counts
  visit_count           int         not null default 0,
  completed_from_stage  int         not null default 0,

  -- Phase 1: null — populated once per-zone timestamps are recorded
  avg_stage_dwell_minutes double precision,

  -- Peak hour within this zone stage
  peak_hour             int,
  peak_hour_count       int         not null default 0,

  created_at            timestamptz not null default timezone('utc', now()),

  constraint zone_analytics_site_fk
    foreign key (client_id, site_id)
    references public.sites (client_id, site_id)
    on delete cascade,

  constraint zone_analytics_zone_stage_valid
    check (zone_stage in ('entry', 'service', 'exit', 'unknown')),

  constraint zone_analytics_peak_hour_range
    check (peak_hour is null or (peak_hour >= 0 and peak_hour <= 23)),

  -- Upsert key
  unique (client_id, site_id, report_date, zone_stage)
);

create index if not exists zone_analytics_scope_date
  on public.zone_analytics (client_id, site_id, report_date desc);

-- ============================================================
-- Row-Level Security
-- Operators may SELECT only rows matching their JWT client_id.
-- All writes use the service-role key (bypasses RLS).
-- ============================================================

alter table public.vehicle_visits    enable row level security;
alter table public.hourly_throughput enable row level security;
alter table public.zone_analytics    enable row level security;

-- vehicle_visits SELECT
drop policy if exists vehicle_visits_select_policy on public.vehicle_visits;
create policy vehicle_visits_select_policy
  on public.vehicle_visits
  for select
  to authenticated
  using (
    client_id = public.onyx_client_id()
    and (
      public.onyx_is_control_role()
      or public.onyx_has_site(site_id)
    )
  );

-- hourly_throughput SELECT
drop policy if exists hourly_throughput_select_policy on public.hourly_throughput;
create policy hourly_throughput_select_policy
  on public.hourly_throughput
  for select
  to authenticated
  using (
    client_id = public.onyx_client_id()
    and (
      public.onyx_is_control_role()
      or public.onyx_has_site(site_id)
    )
  );

-- zone_analytics SELECT
drop policy if exists zone_analytics_select_policy on public.zone_analytics;
create policy zone_analytics_select_policy
  on public.zone_analytics
  for select
  to authenticated
  using (
    client_id = public.onyx_client_id()
    and (
      public.onyx_is_control_role()
      or public.onyx_has_site(site_id)
    )
  );
```

---

## What Looks Good in the Spec

- Schema columns map cleanly to `VehicleVisitRecord` and `VehicleThroughputSummary` — no
  impedance mismatch between domain model and persistence layer.
- Upsert conflict targets are correct: `(client_id, site_id, vehicle_key, started_at_utc)` for
  `vehicle_visits`; UNIQUE constraint on `(client_id, site_id, visit_date, hour_of_day)` for
  `hourly_throughput`.
- Three-index strategy on `vehicle_visits` covers all query patterns in Section 3 without
  over-indexing.
- Phase-1 nullable `avg_stage_dwell_minutes` on `zone_analytics` is the right call —
  avoids a schema migration when per-zone timestamps land.
- Service-role bypass approach for writes is correct and consistent with the existing
  `SupabaseClientLedgerRepository` pattern.

---

## Open Issues for Codex

| # | Issue | Action |
|---|-------|--------|
| OI-1 | Verify `public.set_guard_directory_updated_at()` is a generic trigger function before wiring `hourly_throughput` trigger | REVIEW |
| OI-2 | Confirm `zone_analytics` is in scope for this migration or separate it | REVIEW |
| OI-3 | FK to `public.sites` assumes every monitored site exists before first BI write — confirm write-path ordering | REVIEW |
| OI-4 | `visit_date` timezone: spec acknowledges UTC vs local site date mismatch — decision needed before write path is implemented | DECISION (spec D4) |
| OI-5 | `hourly_throughput.service_count` requires `sawService` fold in `_buildVehicleThroughput` — Codex must add this before inserting rows (spec section 1.2 dependency note) | AUTO |

---

## Recommended Codex Sequence

1. Copy corrected SQL above to `supabase/migrations/202604070002_bi_analytics_tables.sql`.
2. Verify `public.set_guard_directory_updated_at()` function signature — confirm it is
   a generic `before update` trigger returning `new.updated_at := now(); return new;`.
   If not, adjust the trigger or create a minimal equivalent.
3. Resolve OI-2 (zone_analytics scope) and OI-3 (FK ordering) with Zaks before running
   the migration in a shared environment.
4. Implement `VehicleBiRepository` and `SupabaseVehicleBiRepository` as defined in spec
   Section 5 (separate task — not part of this migration).
5. Add `sawService` fold to `_buildVehicleThroughput` (OI-5) before first `hourly_throughput`
   insert.
