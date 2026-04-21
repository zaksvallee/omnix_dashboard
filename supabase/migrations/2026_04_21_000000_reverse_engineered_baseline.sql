-- ============================================================================
-- Reverse-Engineered Schema Baseline — ONYX Supabase (omnix-core)
-- ============================================================================
--
-- Generated: 2026-04-21 07:54 SAST by Layer 1 Step 1 of the audit remediation.
-- Source:    Live production Supabase schema as-of the generation timestamp.
--            Project: omnix-core (ref mnbloeoiiwenlywnnoxe)
--            Host:    aws-1-ap-northeast-1.pooler.supabase.com:5432
--            Server:  PostgreSQL 17.6
--            Client:  pg_dump 17.9 (Homebrew)
--
-- Method:    pg_dump via the script emitted by `supabase db dump --dry-run
--            --linked` (the same invocation the Supabase CLI would run under
--            Docker, minus the container wrapper). Flags: --schema-only
--            --quote-all-identifier --role postgres with the Supabase CLI's
--            standard --exclude-schema list (auth, storage, realtime,
--            extensions, graphql, pgsodium, supabase_*, information_schema,
--            pg_*, etc.) and the CLI's sed-chain sanitisation (CREATE ->
--            CREATE IF NOT EXISTS, event triggers / supabase_realtime
--            publication commented out, comment lines stripped).
--
-- Purpose:   Establish the live schema as the new authoritative source of
--            truth. Prior to this file, the version-controlled migrations in
--            supabase/migrations/ + deploy/supabase_migrations/ described
--            only ~46% of live tables (60 of 129) and ~7% of FK constraints
--            (4 of 57) — the rest were applied out of band (Studio SQL
--            editor, direct psql, or deleted migrations). A fresh
--            `supabase db reset` from the previous migration set would have
--            produced a schema missing 69 tables, 22 views, 12 functions,
--            53 FKs. This baseline closes that gap.
--
-- ⚠️  PRE-REMEDIATION STATE WARNING ⚠️
--
-- This baseline captures the schema as it is — NOT as it should be. It
-- PRESERVES every integrity issue documented in phase 4 of the audit
-- (audit/phase_4_data_integrity.md at commit a1fb7e8). In particular:
--
--   * `incidents.status` has mixed casing: 19 rows `OPEN` vs 78 `open`
--     (phase 4 §4, §12 finding #3). The column type is plain `text`; no
--     enum was defined.
--   * `incidents.priority` mixes 4 competing vocabularies (critical, p3,
--     medium, CRITICAL, high, MEDIUM, HIGH, LOW, p1, p2) (§4).
--   * `incidents.site_id` is NULL in 238 of 241 rows (98.8%) (§7, §12 #4).
--   * `onyx_evidence_certificates.incident_id` + `.face_match_id` are
--     NULL in every one of 282 rows (§7, §12 #5).
--   * `dispatch_current_state.incident_id` is NULL in every one of 27
--     rows (§7, §12 #6).
--   * `client_evidence_ledger.dispatch_id` carries 16,388 orphaned values
--     that do not resolve against any parent table (§1, §12 #2).
--   * `client_conversation_messages` / `client_conversation_ack*` carry
--     `CLIENT-001` references that do not resolve against `clients` (§1).
--   * `guard_ops_events.guard_id` is the literal string
--     `guard_actor_contract` in all 3 rows — test pollution (§1).
--   * `clients` contains 3 rows named "test" with UUID-format client_ids;
--     `guards` contains 5 placeholder rows with NULL identity; 3 real
--     guards appear twice each (old `GRD-NNN` inactive + new
--     UUID-suffixed active) (§7, §8, §12 #9).
--   * Only 4 of 57 live FK constraints were in version-controlled
--     migrations. The other 53 were applied out of band; they are now
--     captured here (§6, §12 #8).
--
-- DO NOT apply this file to a production database expecting clean data.
-- DO NOT apply this file to an environment where the integrity issues
-- above would be actively harmful; the data that exercises those issues
-- is not in this file (schema only) — but the shape that permits them
-- IS here, by design.
--
-- Reconciliation work (consolidating the ghost-applied DDL with the
-- version-controlled migrations that were left behind) is Layer 1 Step 2,
-- not this step. Constraint additions (NOT NULL, hard FKs, CHECK
-- constraints, enum types) are Layer 1 Step 4, not this step.
--
-- Reproducibility: verified against a scratch Postgres 17.9 instance on
-- 2026-04-21 with pg_dump structural analysis + partial apply. 127 of
-- 129 tables, 100% of functions/enums/sequences, 100% of non-PostGIS FKs
-- applied cleanly. The 2 non-applied tables and 7 non-applied views are
-- PostGIS-dependent (`geography(Point,4326)` columns); on any Supabase
-- target PostGIS is pre-installed and all 129 tables will apply. See
-- `audit/layer_1_step_1_schema_baseline_inventory.md` §6 for full
-- reproducibility evidence.
--
-- Parent audit artefacts at omnix_dashboard/main:
--   58fa062  phase 1a backend inventory
--   f216695  phase 1a hetzner appendix
--   d7ad444  phase 1b dashboard parity
--   0582a47  phase 2a backend capability verification (final)
--   37c7760  phase 2b dashboard feature verification (final)
--   a1fb7e8  phase 4 data integrity (final)
--   1887166  layer 1 step 1 schema baseline inventory (this file's sibling)
--
-- ============================================================================




SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH SCHEMA "pg_catalog";






COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "postgis" WITH SCHEMA "public";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE TYPE "public"."client_service_type" AS ENUM (
    'guarding',
    'armed_response',
    'remote_watch',
    'hybrid'
);


ALTER TYPE "public"."client_service_type" OWNER TO "postgres";


CREATE TYPE "public"."duty_state_enum" AS ENUM (
    'OFF_DUTY',
    'STAGED',
    'ON_POST',
    'PATROLLING',
    'RESPONDING',
    'ESCALATED',
    'UNACCOUNTED'
);


ALTER TYPE "public"."duty_state_enum" OWNER TO "postgres";


CREATE TYPE "public"."employee_role" AS ENUM (
    'controller',
    'supervisor',
    'guard',
    'reaction_officer',
    'manager',
    'admin'
);


ALTER TYPE "public"."employee_role" OWNER TO "postgres";


CREATE TYPE "public"."employment_status" AS ENUM (
    'active',
    'suspended',
    'on_leave',
    'terminated'
);


ALTER TYPE "public"."employment_status" OWNER TO "postgres";


CREATE TYPE "public"."incident_priority" AS ENUM (
    'p1',
    'p2',
    'p3',
    'p4'
);


ALTER TYPE "public"."incident_priority" OWNER TO "postgres";


CREATE TYPE "public"."incident_status" AS ENUM (
    'detected',
    'verified',
    'dispatched',
    'on_site',
    'secured',
    'closed'
);


ALTER TYPE "public"."incident_status" OWNER TO "postgres";


CREATE TYPE "public"."incident_type" AS ENUM (
    'breach',
    'fire',
    'medical',
    'panic',
    'loitering',
    'technical_failure'
);


ALTER TYPE "public"."incident_type" OWNER TO "postgres";


CREATE TYPE "public"."ops_order_type_enum" AS ENUM (
    'DEPLOY',
    'REASSIGN',
    'CHECK',
    'RESPOND',
    'STANDBY',
    'WITHDRAW'
);


ALTER TYPE "public"."ops_order_type_enum" OWNER TO "postgres";


CREATE TYPE "public"."patrol_trigger_status_enum" AS ENUM (
    'PENDING',
    'STARTED',
    'COMPLETED',
    'MISSED'
);


ALTER TYPE "public"."patrol_trigger_status_enum" OWNER TO "postgres";


CREATE TYPE "public"."psira_grade" AS ENUM (
    'A',
    'B',
    'C',
    'D',
    'E'
);


ALTER TYPE "public"."psira_grade" OWNER TO "postgres";


CREATE TYPE "public"."site_risk_profile" AS ENUM (
    'residential',
    'industrial',
    'commercial',
    'mixed_use'
);


ALTER TYPE "public"."site_risk_profile" OWNER TO "postgres";


CREATE TYPE "public"."vehicle_maintenance_status" AS ENUM (
    'service_due',
    'tires_check',
    'roadworthy_due',
    'ok'
);


ALTER TYPE "public"."vehicle_maintenance_status" OWNER TO "postgres";


CREATE TYPE "public"."vehicle_type" AS ENUM (
    'armed_response_vehicle',
    'supervisor_bakkie',
    'patrol_bike',
    'general_patrol_vehicle'
);


ALTER TYPE "public"."vehicle_type" OWNER TO "postgres";


CREATE TYPE "public"."violation_severity_enum" AS ENUM (
    'LOW',
    'MEDIUM',
    'HIGH',
    'CRITICAL'
);


ALTER TYPE "public"."violation_severity_enum" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."abort_dispatch"("p_dispatch_id" "uuid", "p_operator_id" "text", "p_reason" "text") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
declare
  last_state text;
  execute_time timestamptz;
begin
  select to_state into last_state
  from dispatch_transitions
  where dispatch_id = p_dispatch_id
  order by created_at desc
  limit 1;

  if last_state <> 'COMMITTING' then
    raise exception 'Abort only allowed during COMMITTING';
  end if;

  select execute_after into execute_time
  from dispatch_intents
  where dispatch_id = p_dispatch_id;

  if now() > execute_time then
    raise exception 'DCW expired, abort not allowed';
  end if;

  insert into dispatch_transitions (
    dispatch_id,
    from_state,
    to_state,
    transition_reason,
    actor_type,
    actor_id,
    metadata
  )
  values (
    p_dispatch_id,
    'COMMITTING',
    'ABORTED',
    'OPERATOR_ABORT',
    'HUMAN',
    p_operator_id,
    jsonb_build_object('reason', p_reason)
  );
end;
$$;


ALTER FUNCTION "public"."abort_dispatch"("p_dispatch_id" "uuid", "p_operator_id" "text", "p_reason" "text") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."guard_ops_retention_runs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "ran_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "projection_keep_days" integer NOT NULL,
    "synced_operation_keep_days" integer NOT NULL,
    "guard_ops_keep_days" integer NOT NULL,
    "projection_run_id" "uuid" NOT NULL,
    "replay_safety_check_id" "uuid" NOT NULL,
    "guard_ops_pruned" boolean DEFAULT false NOT NULL,
    "replay_safe" boolean DEFAULT false NOT NULL,
    "note" "text"
);


ALTER TABLE "public"."guard_ops_retention_runs" OWNER TO "postgres";


COMMENT ON TABLE "public"."guard_ops_retention_runs" IS 'Retention orchestration runs combining projection pruning + canonical replay-safety checks. guard_ops_events pruning remains disabled by policy.';



CREATE OR REPLACE FUNCTION "public"."apply_guard_ops_retention_plan"("projection_keep_days" integer DEFAULT 90, "synced_operation_keep_days" integer DEFAULT 30, "guard_ops_keep_days" integer DEFAULT 365, "note" "text" DEFAULT NULL::"text") RETURNS "public"."guard_ops_retention_runs"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  projection_run public.guard_projection_retention_runs;
  replay_check public.guard_ops_replay_safety_checks;
  run_row public.guard_ops_retention_runs;
begin
  projection_run := public.apply_guard_projection_retention(
    projection_keep_days,
    synced_operation_keep_days,
    note
  );

  replay_check := public.assess_guard_ops_replay_safety(guard_ops_keep_days);

  insert into public.guard_ops_retention_runs (
    projection_keep_days,
    synced_operation_keep_days,
    guard_ops_keep_days,
    projection_run_id,
    replay_safety_check_id,
    guard_ops_pruned,
    replay_safe,
    note
  )
  values (
    projection_keep_days,
    synced_operation_keep_days,
    guard_ops_keep_days,
    projection_run.id,
    replay_check.id,
    false,
    replay_check.replay_safe,
    note
  )
  returning *
  into run_row;

  return run_row;
end;
$$;


ALTER FUNCTION "public"."apply_guard_ops_retention_plan"("projection_keep_days" integer, "synced_operation_keep_days" integer, "guard_ops_keep_days" integer, "note" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."apply_guard_ops_retention_plan"("projection_keep_days" integer, "synced_operation_keep_days" integer, "guard_ops_keep_days" integer, "note" "text") IS 'Runs projection retention and logs canonical replay-safety assessment in one operation.';



CREATE TABLE IF NOT EXISTS "public"."guard_projection_retention_runs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "ran_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "keep_days" integer NOT NULL,
    "synced_operation_keep_days" integer NOT NULL,
    "deleted_location_heartbeats" bigint DEFAULT 0 NOT NULL,
    "deleted_checkpoint_scans" bigint DEFAULT 0 NOT NULL,
    "deleted_incident_captures" bigint DEFAULT 0 NOT NULL,
    "deleted_panic_signals" bigint DEFAULT 0 NOT NULL,
    "deleted_synced_operations" bigint DEFAULT 0 NOT NULL,
    "note" "text"
);


ALTER TABLE "public"."guard_projection_retention_runs" OWNER TO "postgres";


COMMENT ON TABLE "public"."guard_projection_retention_runs" IS 'Audit log for projection-table retention runs. Canonical guard_ops_events are never pruned by this job.';



CREATE OR REPLACE FUNCTION "public"."apply_guard_projection_retention"("keep_days" integer DEFAULT 90, "synced_operation_keep_days" integer DEFAULT 30, "note" "text" DEFAULT NULL::"text") RETURNS "public"."guard_projection_retention_runs"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  keep_cutoff timestamptz;
  synced_cutoff timestamptz;
  location_deleted bigint := 0;
  checkpoint_deleted bigint := 0;
  incident_deleted bigint := 0;
  panic_deleted bigint := 0;
  synced_ops_deleted bigint := 0;
  run_row public.guard_projection_retention_runs;
begin
  if keep_days < 1 then
    raise exception 'keep_days must be >= 1';
  end if;
  if synced_operation_keep_days < 1 then
    raise exception 'synced_operation_keep_days must be >= 1';
  end if;

  keep_cutoff := timezone('utc', now()) - make_interval(days => keep_days);
  synced_cutoff := timezone('utc', now())
    - make_interval(days => synced_operation_keep_days);

  delete from public.guard_location_heartbeats
  where recorded_at < keep_cutoff;
  get diagnostics location_deleted = row_count;

  delete from public.guard_checkpoint_scans
  where scanned_at < keep_cutoff;
  get diagnostics checkpoint_deleted = row_count;

  delete from public.guard_incident_captures
  where captured_at < keep_cutoff;
  get diagnostics incident_deleted = row_count;

  delete from public.guard_panic_signals
  where triggered_at < keep_cutoff;
  get diagnostics panic_deleted = row_count;

  delete from public.guard_sync_operations
  where operation_status = 'synced'
    and occurred_at < synced_cutoff;
  get diagnostics synced_ops_deleted = row_count;

  insert into public.guard_projection_retention_runs (
    keep_days,
    synced_operation_keep_days,
    deleted_location_heartbeats,
    deleted_checkpoint_scans,
    deleted_incident_captures,
    deleted_panic_signals,
    deleted_synced_operations,
    note
  )
  values (
    keep_days,
    synced_operation_keep_days,
    location_deleted,
    checkpoint_deleted,
    incident_deleted,
    panic_deleted,
    synced_ops_deleted,
    note
  )
  returning *
  into run_row;

  return run_row;
end;
$$;


ALTER FUNCTION "public"."apply_guard_projection_retention"("keep_days" integer, "synced_operation_keep_days" integer, "note" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."apply_guard_projection_retention"("keep_days" integer, "synced_operation_keep_days" integer, "note" "text") IS 'Prunes high-volume guard projection tables while preserving canonical append-only guard_ops_events.';



CREATE OR REPLACE FUNCTION "public"."apply_site_risk_defaults"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  if new.risk_profile = 'industrial' and new.guard_nudge_frequency_minutes is null then
    new.guard_nudge_frequency_minutes = 10;
  elsif new.risk_profile = 'residential' and new.guard_nudge_frequency_minutes is null then
    new.guard_nudge_frequency_minutes = 15;
  elsif new.guard_nudge_frequency_minutes is null then
    new.guard_nudge_frequency_minutes = 12;
  end if;

  if new.risk_profile = 'industrial' and new.escalation_trigger_minutes is null then
    new.escalation_trigger_minutes = 1;
  elsif new.risk_profile = 'residential' and new.escalation_trigger_minutes is null then
    new.escalation_trigger_minutes = 2;
  elsif new.escalation_trigger_minutes is null then
    new.escalation_trigger_minutes = 2;
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."apply_site_risk_defaults"() OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."guard_ops_replay_safety_checks" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "checked_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "keep_days" integer NOT NULL,
    "cutoff_at" timestamp with time zone NOT NULL,
    "high_volume_event_types" "text"[] NOT NULL,
    "high_volume_events_before_cutoff" bigint DEFAULT 0 NOT NULL,
    "non_high_volume_events_before_cutoff" bigint DEFAULT 0 NOT NULL,
    "oldest_high_volume_event_at" timestamp with time zone,
    "oldest_non_high_volume_event_at" timestamp with time zone,
    "replay_safe" boolean DEFAULT false NOT NULL,
    "recommendation" "text" NOT NULL
);


ALTER TABLE "public"."guard_ops_replay_safety_checks" OWNER TO "postgres";


COMMENT ON TABLE "public"."guard_ops_replay_safety_checks" IS 'Audit rows for canonical guard_ops_events replay-safety assessments prior to any archival planning.';



CREATE OR REPLACE FUNCTION "public"."assess_guard_ops_replay_safety"("keep_days" integer DEFAULT 365, "high_volume_event_types" "text"[] DEFAULT ARRAY['GPS_HEARTBEAT'::"text", 'WEARABLE_HEARTBEAT'::"text", 'DEVICE_HEALTH'::"text"]) RETURNS "public"."guard_ops_replay_safety_checks"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  cutoff timestamptz;
  high_volume_count bigint := 0;
  non_high_volume_count bigint := 0;
  oldest_high_volume timestamptz;
  oldest_non_high_volume timestamptz;
  safe_for_prune boolean := false;
  recommendation_text text;
  check_row public.guard_ops_replay_safety_checks;
begin
  if keep_days < 1 then
    raise exception 'keep_days must be >= 1';
  end if;

  if array_length(high_volume_event_types, 1) is null then
    raise exception 'high_volume_event_types must contain at least one event type';
  end if;

  cutoff := timezone('utc', now()) - make_interval(days => keep_days);

  select count(*), min(occurred_at)
  into high_volume_count, oldest_high_volume
  from public.guard_ops_events
  where occurred_at < cutoff
    and event_type = any(high_volume_event_types);

  select count(*), min(occurred_at)
  into non_high_volume_count, oldest_non_high_volume
  from public.guard_ops_events
  where occurred_at < cutoff
    and event_type <> all(high_volume_event_types);

  safe_for_prune := non_high_volume_count = 0;
  recommendation_text := case
    when safe_for_prune and high_volume_count > 0 then
      'Replay safety check passed. Only high-volume heartbeat classes are older than the keep window; candidate archival can be planned without touching non-heartbeat evidence.'
    when safe_for_prune and high_volume_count = 0 then
      'Replay safety check passed. No canonical events are older than the keep window.'
    else
      'Replay safety check failed for prune planning. Non-high-volume canonical events exist before cutoff; do not prune guard_ops_events.'
  end;

  insert into public.guard_ops_replay_safety_checks (
    keep_days,
    cutoff_at,
    high_volume_event_types,
    high_volume_events_before_cutoff,
    non_high_volume_events_before_cutoff,
    oldest_high_volume_event_at,
    oldest_non_high_volume_event_at,
    replay_safe,
    recommendation
  )
  values (
    keep_days,
    cutoff,
    high_volume_event_types,
    high_volume_count,
    non_high_volume_count,
    oldest_high_volume,
    oldest_non_high_volume,
    safe_for_prune,
    recommendation_text
  )
  returning *
  into check_row;

  return check_row;
end;
$$;


ALTER FUNCTION "public"."assess_guard_ops_replay_safety"("keep_days" integer, "high_volume_event_types" "text"[]) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."assess_guard_ops_replay_safety"("keep_days" integer, "high_volume_event_types" "text"[]) IS 'Evaluates whether only high-volume heartbeat classes are older than cutoff; used before any canonical event archival decision.';



CREATE OR REPLACE FUNCTION "public"."capture_incident_snapshot"("p_incident_id" "text") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  INSERT INTO incident_snapshots (
    incident_id,
    captured_at,
    threats,
    recommendations,
    patrol_state
  )
  SELECT
    p_incident_id,
    now(),
    (SELECT jsonb_agg(t) FROM latest_relevant_threats t),
    (SELECT jsonb_agg(r) FROM command_patrol_recommendations r),
    (SELECT jsonb_agg(p) FROM active_patrol_orders p);
END;
$$;


ALTER FUNCTION "public"."capture_incident_snapshot"("p_incident_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_initial_transition"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  insert into dispatch_transitions (
    dispatch_id,
    from_state,
    to_state,
    transition_reason,
    actor_type,
    actor_id
  )
  values (
    new.dispatch_id,
    null,
    'DECIDED',
    'INITIAL_DECISION',
    'AI',
    'SYSTEM'
  );

  return new;
end;
$$;


ALTER FUNCTION "public"."create_initial_transition"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."guard_ops_events_reject_mutation"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  raise exception 'guard_ops_events is append-only; UPDATE/DELETE is not permitted';
end;
$$;


ALTER FUNCTION "public"."guard_ops_events_reject_mutation"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."incidents_lock_closed_rows"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  if old.status = 'closed' then
    raise exception 'incidents row is immutable after status=closed';
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."incidents_lock_closed_rows"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."mark_missed_patrols"() RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
begin
  -- 1. Mark expired patrols as MISSED
  update patrol_triggers
  set status = 'MISSED'
  where
    status = 'PENDING'
    and expires_at < now();

  -- 2. Insert violations (only once per patrol)
  insert into patrol_violations (
    patrol_trigger_id,
    guard_id,
    site_id,
    violation_type,
    severity,
    occurred_at
  )
  select
    pt.id,
    pt.guard_id,
    pt.site_id,
    'MISSED_PATROL',
    'MEDIUM',
    pt.expires_at
  from patrol_triggers pt
  where
    pt.status = 'MISSED'
    and not exists (
      select 1
      from patrol_violations pv
      where pv.patrol_trigger_id = pt.id
    );
end;
$$;


ALTER FUNCTION "public"."mark_missed_patrols"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."onyx_client_id"() RETURNS "text"
    LANGUAGE "sql" STABLE
    AS $$
  select coalesce(auth.jwt() ->> 'client_id', '');
$$;


ALTER FUNCTION "public"."onyx_client_id"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."onyx_client_id"() IS 'Returns client_id from auth.jwt claims for ONYX RLS policies.';



CREATE OR REPLACE FUNCTION "public"."onyx_guard_id"() RETURNS "text"
    LANGUAGE "sql" STABLE
    AS $$
  select coalesce(auth.jwt() ->> 'guard_id', '');
$$;


ALTER FUNCTION "public"."onyx_guard_id"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."onyx_guard_id"() IS 'Returns guard_id from auth.jwt claims for ONYX RLS policies.';



CREATE OR REPLACE FUNCTION "public"."onyx_has_site"("target_site_id" "text") RETURNS boolean
    LANGUAGE "sql" STABLE
    AS $$
  select exists (
    select 1
    from jsonb_array_elements_text(
      coalesce(auth.jwt() -> 'site_ids', '[]'::jsonb)
    ) as site(site_id)
    where site.site_id = target_site_id
  );
$$;


ALTER FUNCTION "public"."onyx_has_site"("target_site_id" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."onyx_has_site"("target_site_id" "text") IS 'Returns true if target site_id exists in auth.jwt site_ids claim.';



CREATE OR REPLACE FUNCTION "public"."onyx_is_control_role"() RETURNS boolean
    LANGUAGE "sql" STABLE
    AS $$
  select public.onyx_role_type() in ('controller', 'supervisor', 'admin');
$$;


ALTER FUNCTION "public"."onyx_is_control_role"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."onyx_is_control_role"() IS 'True when role_type is controller, supervisor, or admin.';



CREATE OR REPLACE FUNCTION "public"."onyx_role_type"() RETURNS "text"
    LANGUAGE "sql" STABLE
    AS $$
  select coalesce(auth.jwt() ->> 'role_type', '');
$$;


ALTER FUNCTION "public"."onyx_role_type"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."onyx_role_type"() IS 'Returns role_type from auth.jwt claims for ONYX RLS policies.';



CREATE OR REPLACE FUNCTION "public"."override_dispatch"("p_dispatch_id" "uuid", "p_operator_id" "text", "p_reason" "text") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
declare
  last_state text;
begin
  select to_state into last_state
  from dispatch_transitions
  where dispatch_id = p_dispatch_id
  order by created_at desc
  limit 1;

  if last_state not in ('DECIDED','COMMITTING') then
    raise exception 'Override only allowed before terminal state';
  end if;

  insert into dispatch_transitions (
    dispatch_id,
    from_state,
    to_state,
    transition_reason,
    actor_type,
    actor_id,
    metadata
  )
  values (
    p_dispatch_id,
    last_state,
    'OVERRIDDEN',
    'HUMAN_OVERRIDE',
    'HUMAN',
    p_operator_id,
    jsonb_build_object('reason', p_reason)
  );
end;
$$;


ALTER FUNCTION "public"."override_dispatch"("p_dispatch_id" "uuid", "p_operator_id" "text", "p_reason" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."process_patrol_lifecycle"() RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
declare
  v_incident_id uuid;
begin
  -- COMPLETE ACKNOWLEDGED
  update patrol_triggers
  set status = 'completed',
      completed_at = now()
  where status = 'acknowledged'
    and acknowledged_at + interval '3 minutes' <= now();

  -- MARK MISSED
  update patrol_triggers
  set status = 'missed',
      missed_at = now()
  where status = 'pending'
    and expires_at <= now();

  -- CREATE INCIDENTS (DEDUPED)
  insert into incidents (patrol_trigger_id, type, severity)
  select pt.id, 'missed_patrol', 'high'
  from patrol_triggers pt
  where pt.status = 'missed'
  on conflict (patrol_trigger_id, type) do nothing;

  -- CREATE DECISION TRACE FOR MISSED PATROLS
  insert into decision_traces (
    incident_id,
    patrol_trigger_id,
    decision_type,
    trigger_rule,
    source_category,
    explanation,
    confidence
  )
  select
    i.id,
    pt.id,
    'incident_creation',
    'patrol_missed_timeout',
    'ground',
    'Scheduled patrol was not acknowledged within the allowed execution window.',
    0.95
  from patrol_triggers pt
  join incidents i
    on i.patrol_trigger_id = pt.id
   and i.type = 'missed_patrol'
  left join decision_traces dt
    on dt.incident_id = i.id
   and dt.trigger_rule = 'patrol_missed_timeout'
  where pt.status = 'missed'
    and dt.id is null;
end;
$$;


ALTER FUNCTION "public"."process_patrol_lifecycle"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."promote_to_committing"("p_dispatch_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
declare
  last_state text;
begin
  select to_state into last_state
  from dispatch_transitions
  where dispatch_id = p_dispatch_id
  order by created_at desc
  limit 1;

  if last_state <> 'DECIDED' then
    raise exception 'Only DECIDED can transition to COMMITTING';
  end if;

  insert into dispatch_transitions (
    dispatch_id,
    from_state,
    to_state,
    transition_reason,
    actor_type,
    actor_id
  )
  values (
    p_dispatch_id,
    'DECIDED',
    'COMMITTING',
    'DCW_STARTED',
    'SYSTEM',
    'ENGINE'
  );
end;
$$;


ALTER FUNCTION "public"."promote_to_committing"("p_dispatch_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."promote_to_executed_if_ready"("p_dispatch_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
declare
  last_state text;
  execute_time timestamptz;
begin
  select to_state into last_state
  from dispatch_transitions
  where dispatch_id = p_dispatch_id
  order by created_at desc
  limit 1;

  if last_state <> 'COMMITTING' then
    raise exception 'Only COMMITTING can transition to EXECUTED';
  end if;

  select execute_after into execute_time
  from dispatch_intents
  where dispatch_id = p_dispatch_id;

  if now() < execute_time then
    raise exception 'DCW not expired yet';
  end if;

  insert into dispatch_transitions (
    dispatch_id,
    from_state,
    to_state,
    transition_reason,
    actor_type,
    actor_id
  )
  values (
    p_dispatch_id,
    'COMMITTING',
    'EXECUTED',
    'DCW_EXPIRED',
    'SYSTEM',
    'ENGINE'
  );
end;
$$;


ALTER FUNCTION "public"."promote_to_executed_if_ready"("p_dispatch_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."purge_old_events"() RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
begin
  delete from global_events
  where occurred_at < now() - interval '30 days';
end;
$$;


ALTER FUNCTION "public"."purge_old_events"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."run_intel_scoring"() RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- Insert new threat scores
  INSERT INTO threat_scores (
    entity_type,
    entity_id,
    score,
    computed_at
  )
  SELECT
    isc.entity_type,
    isc.entity_id,
    isc.score,
    isc.computed_at
  FROM intel_scoring_candidates isc;

  -- Mark intel as processed
  UPDATE intel_events
  SET processed = true
  WHERE id IN (
    SELECT intel_event_id
    FROM intel_scoring_candidates
  );
END;
$$;


ALTER FUNCTION "public"."run_intel_scoring"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_client_conversation_push_queue_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;


ALTER FUNCTION "public"."set_client_conversation_push_queue_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_client_conversation_push_sync_state_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;


ALTER FUNCTION "public"."set_client_conversation_push_sync_state_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_client_conversation_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;


ALTER FUNCTION "public"."set_client_conversation_updated_at"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."set_client_conversation_updated_at"() IS 'Shared updated_at trigger used by ONYX client conversation tables.';



CREATE OR REPLACE FUNCTION "public"."set_guard_directory_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;


ALTER FUNCTION "public"."set_guard_directory_updated_at"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."set_guard_directory_updated_at"() IS 'Shared updated_at trigger for ONYX guard directory tables.';



CREATE OR REPLACE FUNCTION "public"."set_guard_ops_media_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;


ALTER FUNCTION "public"."set_guard_ops_media_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_guard_sync_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;


ALTER FUNCTION "public"."set_guard_sync_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_timestamp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;


ALTER FUNCTION "public"."set_timestamp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_legacy_directory_assignment_trigger"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
declare
  target_employee_id uuid;
begin
  if tg_op = 'DELETE' then
    target_employee_id := old.employee_id;
  else
    target_employee_id := new.employee_id;
  end if;
  if target_employee_id is not null then
    perform public.sync_legacy_directory_employee(target_employee_id);
  end if;
  if tg_op = 'UPDATE'
      and old.employee_id is not null
      and old.employee_id is distinct from new.employee_id then
    perform public.sync_legacy_directory_employee(old.employee_id);
  end if;
  return coalesce(new, old);
end;
$$;


ALTER FUNCTION "public"."sync_legacy_directory_assignment_trigger"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_legacy_directory_employee"("target_employee_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
declare
  employee_row public.employees%rowtype;
  primary_site text;
  legacy_full_name text;
  legacy_first_name text;
  legacy_last_name text;
  legacy_active boolean;
  legacy_metadata jsonb;
  controller_legacy_id text;
  guard_legacy_id text;
  staff_legacy_id text;
begin
  if target_employee_id is null then
    return;
  end if;

  select *
  into employee_row
  from public.employees e
  where e.id = target_employee_id;

  if not found then
    update public.controllers
    set
      is_active = false,
      source_employee_id = null,
      updated_at = timezone('utc', now())
    where source_employee_id = target_employee_id;

    update public.staff
    set
      is_active = false,
      source_employee_id = null,
      updated_at = timezone('utc', now())
    where source_employee_id = target_employee_id;

    update public.guards
    set
      is_active = false,
      source_employee_id = null,
      updated_at = timezone('utc', now())
    where source_employee_id = target_employee_id;

    return;
  end if;

  select esa.site_id
  into primary_site
  from public.employee_site_assignments esa
  where esa.client_id = employee_row.client_id
    and esa.employee_id = employee_row.id
    and esa.assignment_status = 'active'
  order by esa.is_primary desc, esa.starts_on asc nulls last, esa.created_at asc nulls last
  limit 1;

  legacy_full_name := btrim(
    concat_ws(' ', employee_row.full_name, employee_row.surname)
  );
  if legacy_full_name = '' then
    legacy_full_name := employee_row.employee_code;
  end if;
  legacy_first_name := nullif(btrim(employee_row.full_name), '');
  if legacy_first_name is null then
    legacy_first_name := legacy_full_name;
  end if;
  legacy_last_name := nullif(btrim(employee_row.surname), '');
  if legacy_last_name is null then
    legacy_last_name := legacy_first_name;
  end if;

  legacy_active := employee_row.employment_status in (
    'active'::public.employment_status,
    'on_leave'::public.employment_status
  );

  legacy_metadata := coalesce(employee_row.metadata, '{}'::jsonb)
    || jsonb_build_object(
      'source_table', 'employees',
      'source_employee_id', employee_row.id::text,
      'source_employee_code', employee_row.employee_code,
      'source_employee_role', employee_row.primary_role::text
    );

  controller_legacy_id := 'CTL-' || replace(employee_row.id::text, '-', '');
  guard_legacy_id := 'GRD-' || replace(employee_row.id::text, '-', '');
  staff_legacy_id := 'STF-' || replace(employee_row.id::text, '-', '');

  if employee_row.primary_role = 'controller'::public.employee_role then
    update public.staff
    set
      is_active = false,
      source_employee_id = null,
      updated_at = timezone('utc', now())
    where source_employee_id = employee_row.id;

    update public.guards
    set
      is_active = false,
      source_employee_id = null,
      updated_at = timezone('utc', now())
    where source_employee_id = employee_row.id;

    update public.controllers c
    set source_employee_id = employee_row.id
    where c.controller_id = controller_legacy_id
      and (
        c.source_employee_id is null
        or c.source_employee_id = employee_row.id
      );

    update public.controllers c
    set source_employee_id = employee_row.id
    where c.ctid in (
      select candidate.ctid
      from public.controllers candidate
      where candidate.source_employee_id is null
        and not exists (
          select 1
          from public.controllers existing
          where existing.source_employee_id = employee_row.id
        )
        and candidate.client_id = employee_row.client_id
        and (
          (
            nullif(btrim(candidate.employee_code), '') is not null
            and nullif(btrim(employee_row.employee_code), '') is not null
            and candidate.employee_code = employee_row.employee_code
          )
          or (
            nullif(btrim(candidate.contact_email), '') is not null
            and nullif(btrim(employee_row.contact_email), '') is not null
            and lower(candidate.contact_email) = lower(employee_row.contact_email)
          )
          or lower(btrim(candidate.full_name)) = lower(legacy_full_name)
        )
      order by
        case
          when candidate.employee_code = employee_row.employee_code then 0
          when lower(coalesce(candidate.contact_email, '')) =
               lower(coalesce(employee_row.contact_email, '')) then 1
          else 2
        end,
        candidate.updated_at desc nulls last,
        candidate.created_at desc nulls last,
        candidate.controller_id
      limit 1
    );

    update public.controllers
    set
      is_active = false,
      source_employee_id = null,
      updated_at = timezone('utc', now())
    where source_employee_id = employee_row.id
      and controller_id <> controller_legacy_id;

    insert into public.controllers (
      controller_id,
      client_id,
      home_site_id,
      first_name,
      last_name,
      full_name,
      role_label,
      employee_code,
      auth_user_id,
      contact_phone,
      contact_email,
      metadata,
      is_active,
      source_employee_id
    )
    select
      controller_legacy_id,
      employee_row.client_id,
      primary_site,
      legacy_first_name,
      legacy_last_name,
      legacy_full_name,
      employee_row.primary_role::text,
      employee_row.employee_code,
      employee_row.auth_user_id,
      employee_row.contact_phone,
      employee_row.contact_email,
      legacy_metadata,
      legacy_active,
      employee_row.id
    where not exists (
      select 1
      from public.controllers c
      where c.controller_id = controller_legacy_id
    );

    update public.controllers
    set
      client_id = employee_row.client_id,
      home_site_id = primary_site,
      first_name = legacy_first_name,
      last_name = legacy_last_name,
      full_name = legacy_full_name,
      role_label = employee_row.primary_role::text,
      employee_code = employee_row.employee_code,
      auth_user_id = employee_row.auth_user_id,
      contact_phone = employee_row.contact_phone,
      contact_email = employee_row.contact_email,
      metadata = legacy_metadata,
      is_active = legacy_active,
      source_employee_id = employee_row.id,
      updated_at = timezone('utc', now())
    where controller_id = controller_legacy_id;
  elsif employee_row.primary_role in (
    'guard'::public.employee_role,
    'reaction_officer'::public.employee_role
  ) then
    update public.controllers
    set
      is_active = false,
      source_employee_id = null,
      updated_at = timezone('utc', now())
    where source_employee_id = employee_row.id;

    update public.staff
    set
      is_active = false,
      source_employee_id = null,
      updated_at = timezone('utc', now())
    where source_employee_id = employee_row.id;

    update public.guards g
    set source_employee_id = employee_row.id
    where g.guard_id = guard_legacy_id
      and (
        g.source_employee_id is null
        or g.source_employee_id = employee_row.id
      );

    update public.guards g
    set source_employee_id = employee_row.id
    where g.ctid in (
      select candidate.ctid
      from public.guards candidate
      where candidate.source_employee_id is null
        and not exists (
          select 1
          from public.guards existing
          where existing.source_employee_id = employee_row.id
        )
        and candidate.client_id = employee_row.client_id
        and (
          (
            nullif(btrim(candidate.device_serial), '') is not null
            and nullif(btrim(employee_row.device_uid), '') is not null
            and candidate.device_serial = employee_row.device_uid
          )
          or (
            nullif(btrim(candidate.contact_email), '') is not null
            and nullif(btrim(employee_row.contact_email), '') is not null
            and lower(candidate.contact_email) = lower(employee_row.contact_email)
          )
          or lower(btrim(candidate.full_name)) = lower(legacy_full_name)
        )
      order by
        case
          when candidate.device_serial = employee_row.device_uid then 0
          when lower(coalesce(candidate.contact_email, '')) =
               lower(coalesce(employee_row.contact_email, '')) then 1
          else 2
        end,
        candidate.updated_at desc nulls last,
        candidate.created_at desc nulls last,
        candidate.guard_id
      limit 1
    );

    update public.guards
    set
      is_active = false,
      source_employee_id = null,
      updated_at = timezone('utc', now())
    where source_employee_id = employee_row.id
      and guard_id <> guard_legacy_id;

    insert into public.guards (
      guard_id,
      client_id,
      primary_site_id,
      first_name,
      last_name,
      full_name,
      badge_number,
      ptt_identity,
      device_serial,
      auth_user_id,
      contact_phone,
      contact_email,
      metadata,
      is_active,
      source_employee_id
    )
    select
      guard_legacy_id,
      employee_row.client_id,
      primary_site,
      legacy_first_name,
      legacy_last_name,
      legacy_full_name,
      nullif(btrim(coalesce(employee_row.metadata ->> 'badge_number', '')), ''),
      nullif(btrim(coalesce(employee_row.metadata ->> 'ptt_identity', '')), ''),
      employee_row.device_uid,
      employee_row.auth_user_id,
      employee_row.contact_phone,
      employee_row.contact_email,
      legacy_metadata,
      legacy_active,
      employee_row.id
    where not exists (
      select 1
      from public.guards g
      where g.guard_id = guard_legacy_id
    );

    update public.guards
    set
      client_id = employee_row.client_id,
      primary_site_id = primary_site,
      first_name = legacy_first_name,
      last_name = legacy_last_name,
      full_name = legacy_full_name,
      badge_number = nullif(
        btrim(coalesce(employee_row.metadata ->> 'badge_number', '')),
        ''
      ),
      ptt_identity = nullif(
        btrim(coalesce(employee_row.metadata ->> 'ptt_identity', '')),
        ''
      ),
      device_serial = employee_row.device_uid,
      auth_user_id = employee_row.auth_user_id,
      contact_phone = employee_row.contact_phone,
      contact_email = employee_row.contact_email,
      metadata = legacy_metadata,
      is_active = legacy_active,
      source_employee_id = employee_row.id,
      updated_at = timezone('utc', now())
    where guard_id = guard_legacy_id;
  else
    update public.controllers
    set
      is_active = false,
      source_employee_id = null,
      updated_at = timezone('utc', now())
    where source_employee_id = employee_row.id;

    update public.guards
    set
      is_active = false,
      source_employee_id = null,
      updated_at = timezone('utc', now())
    where source_employee_id = employee_row.id;

    update public.staff s
    set source_employee_id = employee_row.id
    where s.staff_id = staff_legacy_id
      and (
        s.source_employee_id is null
        or s.source_employee_id = employee_row.id
      );

    update public.staff s
    set source_employee_id = employee_row.id
    where s.ctid in (
      select candidate.ctid
      from public.staff candidate
      where candidate.source_employee_id is null
        and not exists (
          select 1
          from public.staff existing
          where existing.source_employee_id = employee_row.id
        )
        and candidate.client_id = employee_row.client_id
        and (
          (
            nullif(btrim(candidate.employee_code), '') is not null
            and nullif(btrim(employee_row.employee_code), '') is not null
            and candidate.employee_code = employee_row.employee_code
          )
          or (
            nullif(btrim(candidate.contact_email), '') is not null
            and nullif(btrim(employee_row.contact_email), '') is not null
            and lower(candidate.contact_email) = lower(employee_row.contact_email)
          )
          or lower(btrim(candidate.full_name)) = lower(legacy_full_name)
        )
      order by
        case
          when candidate.employee_code = employee_row.employee_code then 0
          when lower(coalesce(candidate.contact_email, '')) =
               lower(coalesce(employee_row.contact_email, '')) then 1
          else 2
        end,
        candidate.updated_at desc nulls last,
        candidate.created_at desc nulls last,
        candidate.staff_id
      limit 1
    );

    update public.staff
    set
      is_active = false,
      source_employee_id = null,
      updated_at = timezone('utc', now())
    where source_employee_id = employee_row.id
      and staff_id <> staff_legacy_id;

    insert into public.staff (
      staff_id,
      client_id,
      site_id,
      first_name,
      last_name,
      full_name,
      staff_role,
      employee_code,
      auth_user_id,
      contact_phone,
      contact_email,
      metadata,
      is_active,
      source_employee_id
    )
    select
      staff_legacy_id,
      employee_row.client_id,
      primary_site,
      legacy_first_name,
      legacy_last_name,
      legacy_full_name,
      employee_row.primary_role::text,
      employee_row.employee_code,
      employee_row.auth_user_id,
      employee_row.contact_phone,
      employee_row.contact_email,
      legacy_metadata,
      legacy_active,
      employee_row.id
    where not exists (
      select 1
      from public.staff s
      where s.staff_id = staff_legacy_id
    );

    update public.staff
    set
      client_id = employee_row.client_id,
      site_id = primary_site,
      first_name = legacy_first_name,
      last_name = legacy_last_name,
      full_name = legacy_full_name,
      staff_role = employee_row.primary_role::text,
      employee_code = employee_row.employee_code,
      auth_user_id = employee_row.auth_user_id,
      contact_phone = employee_row.contact_phone,
      contact_email = employee_row.contact_email,
      metadata = legacy_metadata,
      is_active = legacy_active,
      source_employee_id = employee_row.id,
      updated_at = timezone('utc', now())
    where staff_id = staff_legacy_id;
  end if;
end;
$$;


ALTER FUNCTION "public"."sync_legacy_directory_employee"("target_employee_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sync_legacy_directory_employee"("target_employee_id" "uuid") IS 'Keeps legacy guards/controllers/staff tables synchronized from canonical employees + employee_site_assignments records.';



CREATE OR REPLACE FUNCTION "public"."sync_legacy_directory_employee_trigger"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
declare
  target_employee_id uuid;
begin
  if tg_op = 'DELETE' then
    target_employee_id := old.id;
  else
    target_employee_id := new.id;
  end if;
  if target_employee_id is not null then
    perform public.sync_legacy_directory_employee(target_employee_id);
  end if;
  return coalesce(new, old);
end;
$$;


ALTER FUNCTION "public"."sync_legacy_directory_employee_trigger"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validate_transition"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
declare
  last_state text;
begin
  -- get last state
  select to_state into last_state
  from dispatch_transitions
  where dispatch_id = new.dispatch_id
  order by created_at desc
  limit 1;

  -- first transition must be DECIDED
  if last_state is null and new.to_state <> 'DECIDED' then
    raise exception 'First state must be DECIDED';
  end if;

  -- illegal backward transitions
  if last_state = 'EXECUTED' then
    raise exception 'Cannot transition from EXECUTED';
  end if;

  if last_state = 'ABORTED' then
    raise exception 'Cannot transition from ABORTED';
  end if;

  if last_state = 'OVERRIDDEN' then
    raise exception 'Cannot transition from OVERRIDDEN';
  end if;

  if last_state = 'FAILED' then
    raise exception 'Cannot transition from FAILED';
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."validate_transition"() OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ThreatCategories" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text",
    "description" "text",
    "default_level" "uuid"
);


ALTER TABLE "public"."ThreatCategories" OWNER TO "postgres";


COMMENT ON TABLE "public"."ThreatCategories" IS 'Groups of crime types';



CREATE TABLE IF NOT EXISTS "public"."ThreatLevels" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "level" "text",
    "score" bigint,
    "description" "text"
);


ALTER TABLE "public"."ThreatLevels" OWNER TO "postgres";


COMMENT ON TABLE "public"."ThreatLevels" IS 'Defines the 5 threat levels';



CREATE TABLE IF NOT EXISTS "public"."ThreatMatrix" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "category_id" "uuid" NOT NULL,
    "keyword_pattern" "text" NOT NULL,
    "weight" bigint NOT NULL,
    "auto_escalate_to" "uuid"
);


ALTER TABLE "public"."ThreatMatrix" OWNER TO "postgres";


COMMENT ON TABLE "public"."ThreatMatrix" IS 'Rule engine: how incoming text becomes a threat';



CREATE TABLE IF NOT EXISTS "public"."abort_logs" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "justification" "text" NOT NULL,
    "snapshot_id" "text",
    "user_id" "uuid",
    "extra_data" "jsonb" DEFAULT '{}'::"jsonb"
);


ALTER TABLE "public"."abort_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."actions_log" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "incident_id" "text" NOT NULL,
    "action" "text" NOT NULL,
    "operator_id" "text" NOT NULL,
    "role" "text" NOT NULL,
    "override_reason" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."actions_log" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."patrol_triggers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "patrol_id" "uuid" NOT NULL,
    "guard_id" "uuid" NOT NULL,
    "site_id" "uuid" NOT NULL,
    "trigger_time" timestamp with time zone NOT NULL,
    "window_start" timestamp with time zone NOT NULL,
    "window_end" timestamp with time zone NOT NULL,
    "expires_at" timestamp with time zone NOT NULL,
    "status" "public"."patrol_trigger_status_enum" DEFAULT 'PENDING'::"public"."patrol_trigger_status_enum" NOT NULL
);


ALTER TABLE "public"."patrol_triggers" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."active_patrol_orders" AS
 SELECT "id",
    "patrol_id",
    "guard_id",
    "site_id",
    "status",
    "trigger_time" AS "created_at",
    "window_start",
    "window_end",
    "expires_at"
   FROM "public"."patrol_triggers" "pt"
  WHERE ("status" = ANY (ARRAY['PENDING'::"public"."patrol_trigger_status_enum", 'STARTED'::"public"."patrol_trigger_status_enum"]));


ALTER VIEW "public"."active_patrol_orders" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."threat_scores" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "entity_type" "text",
    "entity_id" "uuid",
    "score" numeric,
    "computed_at" timestamp with time zone DEFAULT "now"(),
    "is_derived" boolean DEFAULT false
);


ALTER TABLE "public"."threat_scores" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."patrol_threats_with_decay" AS
 SELECT "id",
    "entity_type",
    "entity_id",
    "is_derived",
    "score" AS "original_score",
    "computed_at",
    (
        CASE
            WHEN ("is_derived" = false) THEN "score"
            ELSE GREATEST((0)::numeric, ("score" * ((1)::numeric - (EXTRACT(epoch FROM ("now"() - "computed_at")) / EXTRACT(epoch FROM '06:00:00'::interval)))))
        END)::integer AS "decayed_score"
   FROM "public"."threat_scores" "ts"
  WHERE ("entity_type" = 'patrol'::"text");


ALTER VIEW "public"."patrol_threats_with_decay" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."patrol_threats_decayed_with_level" AS
 SELECT "id",
    "entity_id",
    "decayed_score",
        CASE
            WHEN ("decayed_score" >= 70) THEN 'HIGH'::"text"
            WHEN ("decayed_score" >= 30) THEN 'MEDIUM'::"text"
            ELSE 'LOW'::"text"
        END AS "threat_level",
    "computed_at"
   FROM "public"."patrol_threats_with_decay" "ptd";


ALTER VIEW "public"."patrol_threats_decayed_with_level" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."active_ops_with_threats" AS
 SELECT "apo"."id",
    "apo"."patrol_id",
    "apo"."guard_id",
    "apo"."site_id",
    "apo"."status",
    "apo"."created_at",
    "apo"."window_start",
    "apo"."window_end",
    "apo"."expires_at",
    "ptd"."decayed_score" AS "threat_score",
    "ptd"."threat_level",
    "ptd"."computed_at" AS "threat_computed_at"
   FROM ("public"."active_patrol_orders" "apo"
     LEFT JOIN "public"."patrol_threats_decayed_with_level" "ptd" ON (("ptd"."entity_id" = "apo"."patrol_id")));


ALTER VIEW "public"."active_ops_with_threats" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."alarm_accounts" (
    "account_number" "text" NOT NULL,
    "client_id" "text" NOT NULL,
    "site_id" "text" NOT NULL,
    "aes_key_override" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."alarm_accounts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."alert_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "rule_id" "uuid",
    "entity_type" "text",
    "entity_id" "uuid",
    "threat_score" integer,
    "threat_level" "text",
    "triggered_at" timestamp with time zone DEFAULT "now"(),
    "acknowledged" boolean DEFAULT false
);


ALTER TABLE "public"."alert_events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."alert_rules" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "rule_name" "text" NOT NULL,
    "entity_type" "text",
    "min_threat_level" "text",
    "min_score" integer,
    "cooldown" interval DEFAULT '00:30:00'::interval,
    "enabled" boolean DEFAULT true
);


ALTER TABLE "public"."alert_rules" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."area_sites" (
    "area_key" "text" NOT NULL,
    "site_id" "uuid" NOT NULL
);


ALTER TABLE "public"."area_sites" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."intel_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "source_type" "text" NOT NULL,
    "source_name" "text" NOT NULL,
    "source_ref" "text",
    "title" "text",
    "content" "text" NOT NULL,
    "language" "text" DEFAULT 'en'::"text",
    "entity_type" "text",
    "entity_id" "uuid",
    "geo" "jsonb",
    "tags" "text"[],
    "severity" integer,
    "confidence" integer,
    "event_time" timestamp with time zone,
    "ingested_at" timestamp with time zone DEFAULT "now"(),
    "processed" boolean DEFAULT false,
    "archived" boolean DEFAULT false,
    "geo_point" "public"."geography"(Point,4326)
);


ALTER TABLE "public"."intel_events" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."latest_threat_per_entity" AS
 SELECT DISTINCT ON ("entity_type", "entity_id") "id",
    "entity_type",
    "entity_id",
    "score",
    "computed_at" AS "created_at"
   FROM "public"."threat_scores" "ts"
  ORDER BY "entity_type", "entity_id", "computed_at" DESC;


ALTER VIEW "public"."latest_threat_per_entity" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."latest_threat_with_level" AS
 SELECT "id",
    "entity_type",
    "entity_id",
    "score",
    "created_at",
        CASE
            WHEN ("score" >= (70)::numeric) THEN 'HIGH'::"text"
            WHEN ("score" >= (30)::numeric) THEN 'MEDIUM'::"text"
            ELSE 'LOW'::"text"
        END AS "threat_level"
   FROM "public"."latest_threat_per_entity" "lt";


ALTER VIEW "public"."latest_threat_with_level" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."latest_relevant_threats" AS
 SELECT "id",
    "entity_type",
    "entity_id",
    "score",
    "threat_level",
    "created_at"
   FROM "public"."latest_threat_with_level" "ltl"
  WHERE ("created_at" >= ("now"() - '24:00:00'::interval));


ALTER VIEW "public"."latest_relevant_threats" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."area_intel_patrol_links" AS
 SELECT "lrt"."id" AS "area_threat_id",
    "lrt"."score" AS "area_score",
    "lrt"."threat_level" AS "area_threat_level",
    "lrt"."created_at" AS "area_computed_at",
    "apo"."patrol_id",
    "apo"."site_id",
    "apo"."created_at" AS "patrol_started_at"
   FROM ((("public"."latest_relevant_threats" "lrt"
     JOIN "public"."intel_events" "ie" ON ((("ie"."ingested_at" = "lrt"."created_at") AND ("lrt"."entity_type" = 'area'::"text"))))
     JOIN "public"."area_sites" "asg" ON (("asg"."area_key" = ANY ("ie"."tags"))))
     JOIN "public"."active_patrol_orders" "apo" ON (("apo"."site_id" = "asg"."site_id")));


ALTER VIEW "public"."area_intel_patrol_links" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."checkins" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "guard_id" "uuid" NOT NULL,
    "site_id" "uuid" NOT NULL,
    "patrol_trigger_id" "uuid",
    "post_id" "uuid",
    "method" "text" NOT NULL,
    "latitude" numeric,
    "longitude" numeric,
    "nfc_tag_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."checkins" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."civic_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "type" "text" NOT NULL,
    "severity" integer NOT NULL,
    "latitude" double precision,
    "longitude" double precision,
    "active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."civic_events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."client_contact_endpoint_subscriptions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "client_id" "text" NOT NULL,
    "site_id" "text",
    "contact_id" "uuid" NOT NULL,
    "endpoint_id" "uuid" NOT NULL,
    "incident_priorities" "jsonb" DEFAULT '["p1", "p2", "p3", "p4"]'::"jsonb" NOT NULL,
    "incident_types" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "quiet_hours" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    CONSTRAINT "client_contact_endpoint_subscriptions_priorities_is_array" CHECK (("jsonb_typeof"("incident_priorities") = 'array'::"text")),
    CONSTRAINT "client_contact_endpoint_subscriptions_quiet_hours_is_object" CHECK (("jsonb_typeof"("quiet_hours") = 'object'::"text")),
    CONSTRAINT "client_contact_endpoint_subscriptions_types_is_array" CHECK (("jsonb_typeof"("incident_types") = 'array'::"text"))
);


ALTER TABLE "public"."client_contact_endpoint_subscriptions" OWNER TO "postgres";


COMMENT ON TABLE "public"."client_contact_endpoint_subscriptions" IS 'Routing rules mapping contacts to messaging endpoints and incident scopes.';



CREATE TABLE IF NOT EXISTS "public"."client_contacts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "client_id" "text" NOT NULL,
    "site_id" "text",
    "full_name" "text" NOT NULL,
    "role" "text" DEFAULT 'client_contact'::"text" NOT NULL,
    "phone" "text",
    "email" "text",
    "telegram_user_id" "text",
    "is_primary" boolean DEFAULT false NOT NULL,
    "consent_at" timestamp with time zone,
    "is_active" boolean DEFAULT true NOT NULL,
    "metadata" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    CONSTRAINT "client_contacts_full_name_not_blank" CHECK (("length"("btrim"("full_name")) > 0)),
    CONSTRAINT "client_contacts_metadata_is_object" CHECK (("jsonb_typeof"("metadata") = 'object'::"text")),
    CONSTRAINT "client_contacts_role_not_blank" CHECK (("length"("btrim"("role")) > 0))
);


ALTER TABLE "public"."client_contacts" OWNER TO "postgres";


COMMENT ON TABLE "public"."client_contacts" IS 'Client and site communication contacts used for operational messaging lanes.';



CREATE TABLE IF NOT EXISTS "public"."client_conversation_acknowledgements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "client_id" "text" NOT NULL,
    "site_id" "text" NOT NULL,
    "message_key" "text" NOT NULL,
    "channel" "text" NOT NULL,
    "acknowledged_by" "text" NOT NULL,
    "acknowledged_at" timestamp with time zone NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    CONSTRAINT "client_conversation_acknowledgements_message_key_not_blank" CHECK (("length"("btrim"("message_key")) > 0))
);


ALTER TABLE "public"."client_conversation_acknowledgements" OWNER TO "postgres";


COMMENT ON TABLE "public"."client_conversation_acknowledgements" IS 'ONYX client app acknowledgement state, scoped by client_id and site_id.';



CREATE TABLE IF NOT EXISTS "public"."client_conversation_messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "client_id" "text" NOT NULL,
    "site_id" "text" NOT NULL,
    "author" "text" NOT NULL,
    "body" "text" NOT NULL,
    "room_key" "text" NOT NULL,
    "viewer_role" "text" NOT NULL,
    "incident_status_label" "text" DEFAULT 'Update'::"text" NOT NULL,
    "occurred_at" timestamp with time zone NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "message_source" "text" DEFAULT 'in_app'::"text" NOT NULL,
    "message_provider" "text" DEFAULT 'in_app'::"text" NOT NULL,
    CONSTRAINT "client_conversation_messages_body_not_blank" CHECK (("length"("btrim"("body")) > 0)),
    CONSTRAINT "client_conversation_messages_provider_not_blank" CHECK (("length"("btrim"("message_provider")) > 0)),
    CONSTRAINT "client_conversation_messages_source_valid" CHECK (("message_source" = ANY (ARRAY['in_app'::"text", 'telegram'::"text", 'system'::"text"])))
);


ALTER TABLE "public"."client_conversation_messages" OWNER TO "postgres";


COMMENT ON TABLE "public"."client_conversation_messages" IS 'ONYX client app thread messages, scoped by client_id and site_id.';



COMMENT ON COLUMN "public"."client_conversation_messages"."message_source" IS 'Source lane for the conversation message (in_app, telegram, system).';



COMMENT ON COLUMN "public"."client_conversation_messages"."message_provider" IS 'Provider identity for delivery/origin (e.g., in_app, telegram, openai).';



CREATE TABLE IF NOT EXISTS "public"."client_conversation_push_queue" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "client_id" "text" NOT NULL,
    "site_id" "text" NOT NULL,
    "message_key" "text" NOT NULL,
    "title" "text" NOT NULL,
    "body" "text" NOT NULL,
    "occurred_at" timestamp with time zone NOT NULL,
    "target_channel" "text" NOT NULL,
    "priority" boolean DEFAULT false NOT NULL,
    "status" "text" DEFAULT 'queued'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "delivery_provider" "text" DEFAULT 'in_app'::"text" NOT NULL,
    CONSTRAINT "client_conversation_push_queue_body_not_blank" CHECK (("length"("btrim"("body")) > 0)),
    CONSTRAINT "client_conversation_push_queue_delivery_provider_valid" CHECK (("delivery_provider" = ANY (ARRAY['in_app'::"text", 'telegram'::"text"]))),
    CONSTRAINT "client_conversation_push_queue_status_valid" CHECK (("status" = ANY (ARRAY['queued'::"text", 'acknowledged'::"text"]))),
    CONSTRAINT "client_conversation_push_queue_target_channel_valid" CHECK (("target_channel" = ANY (ARRAY['client'::"text", 'control'::"text", 'resident'::"text"])))
);


ALTER TABLE "public"."client_conversation_push_queue" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."client_conversation_push_sync_state" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "client_id" "text" NOT NULL,
    "site_id" "text" NOT NULL,
    "status_label" "text" DEFAULT 'idle'::"text" NOT NULL,
    "last_synced_at" timestamp with time zone,
    "failure_reason" "text",
    "retry_count" integer DEFAULT 0 NOT NULL,
    "history" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "probe_status_label" "text" DEFAULT 'idle'::"text" NOT NULL,
    "probe_last_run_at" timestamp with time zone,
    "probe_failure_reason" "text",
    "probe_history" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    CONSTRAINT "client_conversation_push_sync_state_history_is_array" CHECK (("jsonb_typeof"("history") = 'array'::"text")),
    CONSTRAINT "client_conversation_push_sync_state_probe_history_is_array" CHECK (("jsonb_typeof"("probe_history") = 'array'::"text")),
    CONSTRAINT "client_conversation_push_sync_state_retry_count_non_negative" CHECK (("retry_count" >= 0))
);


ALTER TABLE "public"."client_conversation_push_sync_state" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."client_evidence_ledger" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "client_id" "text" NOT NULL,
    "dispatch_id" "text" NOT NULL,
    "canonical_json" "jsonb" NOT NULL,
    "hash" "text" NOT NULL,
    "previous_hash" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."client_evidence_ledger" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."client_messaging_endpoints" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "client_id" "text" NOT NULL,
    "site_id" "text",
    "provider" "text" NOT NULL,
    "telegram_chat_id" "text",
    "telegram_thread_id" "text",
    "display_label" "text" NOT NULL,
    "verified_at" timestamp with time zone,
    "is_active" boolean DEFAULT true NOT NULL,
    "last_delivery_status" "text",
    "last_error" "text",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "endpoint_role" "text" DEFAULT 'client'::"text",
    CONSTRAINT "client_messaging_endpoints_display_label_not_blank" CHECK (("length"("btrim"("display_label")) > 0)),
    CONSTRAINT "client_messaging_endpoints_metadata_is_object" CHECK (("jsonb_typeof"("metadata") = 'object'::"text")),
    CONSTRAINT "client_messaging_endpoints_provider_valid" CHECK (("provider" = ANY (ARRAY['telegram'::"text", 'in_app'::"text"]))),
    CONSTRAINT "client_messaging_endpoints_telegram_chat_required" CHECK ((("provider" <> 'telegram'::"text") OR (("telegram_chat_id" IS NOT NULL) AND ("length"("btrim"("telegram_chat_id")) > 0))))
);


ALTER TABLE "public"."client_messaging_endpoints" OWNER TO "postgres";


COMMENT ON TABLE "public"."client_messaging_endpoints" IS 'Delivery endpoints (Telegram / in-app) for client communications.';



CREATE TABLE IF NOT EXISTS "public"."clients" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "contact_name" "text",
    "contact_phone" "text",
    "email" "text",
    "address" "text",
    "notes" "text",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "client_id" "text" NOT NULL,
    "display_name" "text" NOT NULL,
    "legal_name" "text",
    "contact_email" "text",
    "billing_address" "text",
    "is_active" boolean DEFAULT true NOT NULL,
    "client_type" "public"."client_service_type",
    "vat_number" "text",
    "sovereign_contact" "text",
    "contract_start" "date"
);


ALTER TABLE "public"."clients" OWNER TO "postgres";


COMMENT ON TABLE "public"."clients" IS 'Tenant-level client directory records used for ONYX onboarding and scope metadata.';



CREATE TABLE IF NOT EXISTS "public"."command_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "operator_id" "uuid",
    "intelligence_id" "text" NOT NULL,
    "event_type" "text" NOT NULL,
    "posture" "text" NOT NULL,
    "posture_intent" "text" NOT NULL,
    "assets" "jsonb",
    "zones" "jsonb",
    "duration_minutes" integer,
    "requires_confirmation" boolean DEFAULT false NOT NULL,
    "confirmed" boolean DEFAULT false NOT NULL,
    "notes" "text"
);


ALTER TABLE "public"."command_events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."patrol_route_recommendations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "patrol_id" "uuid" NOT NULL,
    "recommendation" "text" NOT NULL,
    "reason" "text",
    "threat_refs" "uuid"[],
    "confidence" integer,
    "generated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."patrol_route_recommendations" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."command_patrol_recommendations" AS
 SELECT "pr"."patrol_id",
    "pr"."recommendation",
    "pr"."reason",
    "pr"."confidence",
    "pr"."generated_at",
    "ao"."site_id",
    "ao"."guard_id"
   FROM ("public"."patrol_route_recommendations" "pr"
     JOIN "public"."active_patrol_orders" "ao" ON (("ao"."patrol_id" = "pr"."patrol_id")));


ALTER VIEW "public"."command_patrol_recommendations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."command_summaries" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "summary_type" "text" NOT NULL,
    "entity_type" "text",
    "entity_id" "uuid",
    "title" "text" NOT NULL,
    "summary" "text" NOT NULL,
    "threat_level" "text",
    "confidence" integer,
    "source_threat_ids" "uuid"[],
    "generated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."command_summaries" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."controllers" (
    "controller_id" "text" NOT NULL,
    "client_id" "text" NOT NULL,
    "home_site_id" "text",
    "full_name" "text" NOT NULL,
    "role_label" "text" DEFAULT 'controller'::"text" NOT NULL,
    "employee_code" "text",
    "auth_user_id" "uuid",
    "contact_phone" "text",
    "contact_email" "text",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "source_employee_id" "uuid",
    "first_name" "text",
    "last_name" "text",
    CONSTRAINT "controllers_controller_id_not_blank" CHECK (("length"("btrim"("controller_id")) > 0)),
    CONSTRAINT "controllers_full_name_not_blank" CHECK (("length"("btrim"("full_name")) > 0)),
    CONSTRAINT "controllers_metadata_is_object" CHECK (("jsonb_typeof"("metadata") = 'object'::"text")),
    CONSTRAINT "controllers_role_label_not_blank" CHECK (("length"("btrim"("role_label")) > 0))
);


ALTER TABLE "public"."controllers" OWNER TO "postgres";


COMMENT ON TABLE "public"."controllers" IS 'Controller operator directory records for client/site operations.';



CREATE TABLE IF NOT EXISTS "public"."decision_audit_log" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "decision_type" "text",
    "entity_type" "text",
    "entity_id" "uuid",
    "justification" "text",
    "source_refs" "uuid"[],
    "decided_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."decision_audit_log" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."decision_traces" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "incident_id" "uuid" NOT NULL,
    "patrol_trigger_id" "uuid",
    "decision_type" "text" NOT NULL,
    "trigger_rule" "text" NOT NULL,
    "source_category" "text" NOT NULL,
    "explanation" "text" NOT NULL,
    "confidence" numeric DEFAULT 0.9 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_by" "text" DEFAULT 'system'::"text" NOT NULL
);


ALTER TABLE "public"."decision_traces" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."demo_state" (
    "id" boolean DEFAULT true NOT NULL,
    "demo_mode" boolean DEFAULT true NOT NULL,
    "last_reset" timestamp with time zone
);


ALTER TABLE "public"."demo_state" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."deployments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "guard_id" "uuid" NOT NULL,
    "site_id" "uuid" NOT NULL,
    "shift_start" timestamp with time zone NOT NULL,
    "shift_end" timestamp with time zone,
    "supervisor_name" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."deployments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."dispatch_actions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "action_type" "text" NOT NULL,
    "status" "text" NOT NULL,
    "risk_score" numeric,
    "confidence" numeric,
    "geo_lat" double precision,
    "geo_lng" double precision,
    "source" "text",
    "decision_trace" "jsonb",
    "metadata" "jsonb",
    "dcw_seconds" integer,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "decided_at" timestamp with time zone,
    "executed_at" timestamp with time zone,
    "aborted_at" timestamp with time zone
);

ALTER TABLE ONLY "public"."dispatch_actions" REPLICA IDENTITY FULL;


ALTER TABLE "public"."dispatch_actions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."dispatch_intents" (
    "dispatch_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "action_type" "text" NOT NULL,
    "risk_level" "text" NOT NULL,
    "risk_score" double precision NOT NULL,
    "confidence" double precision NOT NULL,
    "decision_trace" "jsonb" NOT NULL,
    "geo_scope" "jsonb" NOT NULL,
    "dcw_seconds" integer NOT NULL,
    "decided_at" timestamp with time zone NOT NULL,
    "execute_after" timestamp with time zone NOT NULL,
    "units" "text"[],
    "route_id" "text",
    "ati_snapshot" "jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "geo_lat" double precision,
    "geo_lng" double precision,
    CONSTRAINT "dispatch_intents_risk_level_check" CHECK (("risk_level" = ANY (ARRAY['LOW'::"text", 'MEDIUM'::"text", 'HIGH'::"text"])))
);


ALTER TABLE "public"."dispatch_intents" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."dispatch_transitions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "dispatch_id" "uuid",
    "from_state" "text",
    "to_state" "text" NOT NULL,
    "transition_reason" "text",
    "failure_type" "text",
    "actor_type" "text",
    "actor_id" "text",
    "metadata" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "dispatch_transitions_actor_type_check" CHECK (("actor_type" = ANY (ARRAY['AI'::"text", 'HUMAN'::"text", 'SYSTEM'::"text"]))),
    CONSTRAINT "dispatch_transitions_to_state_check" CHECK (("to_state" = ANY (ARRAY['DECIDED'::"text", 'COMMITTING'::"text", 'EXECUTED'::"text", 'ABORTED'::"text", 'OVERRIDDEN'::"text", 'FAILED'::"text"])))
);


ALTER TABLE "public"."dispatch_transitions" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."dispatch_current_state" AS
 SELECT "di"."dispatch_id",
    "di"."action_type",
    "di"."risk_level",
    "di"."risk_score",
    "di"."confidence",
    "di"."geo_scope",
    "di"."dcw_seconds",
    "di"."decided_at",
    "di"."execute_after",
    "di"."units",
    "di"."route_id",
    "di"."ati_snapshot",
    "dt"."to_state" AS "current_state",
    "dt"."created_at" AS "state_changed_at"
   FROM ("public"."dispatch_intents" "di"
     JOIN LATERAL ( SELECT "dispatch_transitions"."to_state",
            "dispatch_transitions"."created_at"
           FROM "public"."dispatch_transitions"
          WHERE ("dispatch_transitions"."dispatch_id" = "di"."dispatch_id")
          ORDER BY "dispatch_transitions"."created_at" DESC
         LIMIT 1) "dt" ON (true));


ALTER VIEW "public"."dispatch_current_state" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."duty_states" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "guard_id" "uuid" NOT NULL,
    "site_id" "uuid" NOT NULL,
    "state" "public"."duty_state_enum" NOT NULL,
    "entered_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "exited_at" timestamp with time zone,
    "triggered_by" "text" NOT NULL
);


ALTER TABLE "public"."duty_states" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."employee_site_assignments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "client_id" "text" NOT NULL,
    "employee_id" "uuid" NOT NULL,
    "site_id" "text" NOT NULL,
    "is_primary" boolean DEFAULT false NOT NULL,
    "assignment_status" "text" DEFAULT 'active'::"text" NOT NULL,
    "starts_on" "date" DEFAULT CURRENT_DATE NOT NULL,
    "ends_on" "date",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    CONSTRAINT "employee_site_assignments_dates_valid" CHECK ((("ends_on" IS NULL) OR ("ends_on" >= "starts_on"))),
    CONSTRAINT "employee_site_assignments_status_valid" CHECK (("assignment_status" = ANY (ARRAY['active'::"text", 'inactive'::"text"])))
);


ALTER TABLE "public"."employee_site_assignments" OWNER TO "postgres";


COMMENT ON TABLE "public"."employee_site_assignments" IS 'Employee-to-site assignment map for operational scope, dispatch, and access checks.';



CREATE TABLE IF NOT EXISTS "public"."employees" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "client_id" "text" NOT NULL,
    "employee_code" "text" NOT NULL,
    "full_name" "text" NOT NULL,
    "surname" "text" NOT NULL,
    "id_number" "text" NOT NULL,
    "date_of_birth" "date",
    "primary_role" "public"."employee_role" NOT NULL,
    "reporting_to_employee_id" "uuid",
    "psira_number" "text",
    "psira_grade" "public"."psira_grade",
    "psira_expiry" "date",
    "has_driver_license" boolean DEFAULT false NOT NULL,
    "driver_license_code" "text",
    "driver_license_expiry" "date",
    "has_pdp" boolean DEFAULT false NOT NULL,
    "pdp_expiry" "date",
    "firearm_competency" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "issued_firearm_serials" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "device_uid" "text",
    "biometric_template_hash" "text",
    "auth_user_id" "uuid",
    "contact_phone" "text",
    "contact_email" "text",
    "employment_status" "public"."employment_status" DEFAULT 'active'::"public"."employment_status" NOT NULL,
    "metadata" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    CONSTRAINT "employees_driver_license_consistency" CHECK ((("has_driver_license" = true) OR (("driver_license_code" IS NULL) AND ("driver_license_expiry" IS NULL)))),
    CONSTRAINT "employees_employee_code_not_blank" CHECK (("length"("btrim"("employee_code")) > 0)),
    CONSTRAINT "employees_firearm_competency_is_object" CHECK (("jsonb_typeof"("firearm_competency") = 'object'::"text")),
    CONSTRAINT "employees_full_name_not_blank" CHECK (("length"("btrim"("full_name")) > 0)),
    CONSTRAINT "employees_id_number_not_blank" CHECK (("length"("btrim"("id_number")) > 0)),
    CONSTRAINT "employees_metadata_is_object" CHECK (("jsonb_typeof"("metadata") = 'object'::"text")),
    CONSTRAINT "employees_pdp_consistency" CHECK ((("has_pdp" = false) OR (("has_driver_license" = true) AND ("pdp_expiry" IS NOT NULL)))),
    CONSTRAINT "employees_reporting_not_self" CHECK ((("reporting_to_employee_id" IS NULL) OR ("reporting_to_employee_id" <> "id"))),
    CONSTRAINT "employees_surname_not_blank" CHECK (("length"("btrim"("surname")) > 0))
);


ALTER TABLE "public"."employees" OWNER TO "postgres";


COMMENT ON TABLE "public"."employees" IS 'Unified ONYX employee registry with role discriminator and SA compliance fields (PSIRA, licensing, PDP).';



CREATE TABLE IF NOT EXISTS "public"."escalation_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "site_id" "uuid" NOT NULL,
    "source" "text" NOT NULL,
    "source_id" "uuid" NOT NULL,
    "level" integer NOT NULL,
    "escalated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "resolved_at" timestamp with time zone
);


ALTER TABLE "public"."escalation_events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."evidence_bundles" (
    "bundle_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "bundle_type" "text" NOT NULL,
    "dispatch_id" "uuid",
    "contents" "jsonb" NOT NULL,
    "integrity_hash" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."evidence_bundles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."execution_locks" (
    "dispatch_id" "uuid" NOT NULL,
    "execution_key" "text" NOT NULL,
    "locked_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."execution_locks" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."execution_system_health" AS
 SELECT 'SIMULATION'::"text" AS "execution_mode",
    true AS "kill_switch_armed",
    ( SELECT "count"(*) AS "count"
           FROM "public"."dispatch_current_state"
          WHERE ("dispatch_current_state"."current_state" = 'COMMITTING'::"text")) AS "committing_count",
    ( SELECT "count"(*) AS "count"
           FROM "public"."dispatch_current_state"
          WHERE ("dispatch_current_state"."current_state" = 'FAILED'::"text")) AS "failure_count",
    (EXISTS ( SELECT 1
           FROM "public"."dispatch_current_state"
          WHERE (("dispatch_current_state"."current_state" = 'COMMITTING'::"text") AND ("dispatch_current_state"."execute_after" <= "now"())))) AS "ready_to_execute";


ALTER VIEW "public"."execution_system_health" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."external_signals" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "geo_lat" double precision NOT NULL,
    "geo_lng" double precision NOT NULL,
    "country" "text",
    "source_type" "text",
    "confidence" numeric,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."external_signals" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."fr_person_registry" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "site_id" "text" NOT NULL,
    "person_id" "text" NOT NULL,
    "display_name" "text" NOT NULL,
    "role" "text" DEFAULT 'resident'::"text" NOT NULL,
    "is_private" boolean DEFAULT true NOT NULL,
    "expected_days" "text"[] DEFAULT '{}'::"text"[],
    "expected_start" time without time zone,
    "expected_end" time without time zone,
    "photo_count" integer DEFAULT 0 NOT NULL,
    "gallery_path" "text",
    "is_enrolled" boolean DEFAULT false NOT NULL,
    "enrolled_at" timestamp with time zone,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."fr_person_registry" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."global_clusters" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "centroid_lat" double precision,
    "centroid_lng" double precision,
    "event_count" integer,
    "avg_severity" double precision,
    "cluster_score" double precision,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."global_clusters" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."global_events" (
    "source_id" "text" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "latitude" double precision,
    "longitude" double precision,
    "severity" double precision,
    "published_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."global_events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."global_patterns" (
    "id" "text" NOT NULL,
    "description" "text",
    "pattern_type" "text",
    "region_scope" "text",
    "event_count" integer,
    "avg_severity" numeric,
    "velocity_score" numeric,
    "confidence_score" numeric,
    "detected_at" timestamp without time zone,
    "last_updated" timestamp without time zone,
    "is_active" boolean DEFAULT true,
    "evidence_snapshot" "jsonb"
);


ALTER TABLE "public"."global_patterns" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."guard_assignments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "assignment_id" "text" NOT NULL,
    "dispatch_id" "text" NOT NULL,
    "client_id" "text" NOT NULL,
    "site_id" "text" NOT NULL,
    "guard_id" "text" NOT NULL,
    "duty_status" "text" DEFAULT 'available'::"text" NOT NULL,
    "issued_at" timestamp with time zone NOT NULL,
    "acknowledged_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    CONSTRAINT "guard_assignments_assignment_id_not_blank" CHECK (("length"("btrim"("assignment_id")) > 0)),
    CONSTRAINT "guard_assignments_dispatch_id_not_blank" CHECK (("length"("btrim"("dispatch_id")) > 0)),
    CONSTRAINT "guard_assignments_status_not_blank" CHECK (("length"("btrim"("duty_status")) > 0))
);


ALTER TABLE "public"."guard_assignments" OWNER TO "postgres";


COMMENT ON TABLE "public"."guard_assignments" IS 'Guard dispatch assignments and duty-state transitions.';



CREATE TABLE IF NOT EXISTS "public"."guard_checkpoint_scans" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "scan_id" "text" NOT NULL,
    "client_id" "text" NOT NULL,
    "site_id" "text" NOT NULL,
    "guard_id" "text" NOT NULL,
    "checkpoint_id" "text" NOT NULL,
    "nfc_tag_id" "text" NOT NULL,
    "latitude" double precision,
    "longitude" double precision,
    "scanned_at" timestamp with time zone NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    CONSTRAINT "guard_checkpoint_scans_checkpoint_id_not_blank" CHECK (("length"("btrim"("checkpoint_id")) > 0)),
    CONSTRAINT "guard_checkpoint_scans_nfc_tag_id_not_blank" CHECK (("length"("btrim"("nfc_tag_id")) > 0)),
    CONSTRAINT "guard_checkpoint_scans_scan_id_not_blank" CHECK (("length"("btrim"("scan_id")) > 0))
);


ALTER TABLE "public"."guard_checkpoint_scans" OWNER TO "postgres";


COMMENT ON TABLE "public"."guard_checkpoint_scans" IS 'NFC checkpoint verification scans for patrol compliance.';



CREATE TABLE IF NOT EXISTS "public"."guard_documents" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "guard_id" "uuid" NOT NULL,
    "type" "text" NOT NULL,
    "file_url" "text" NOT NULL,
    "notes" "text",
    "uploaded_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."guard_documents" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."guard_incident_captures" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "capture_id" "text" NOT NULL,
    "client_id" "text" NOT NULL,
    "site_id" "text" NOT NULL,
    "guard_id" "text" NOT NULL,
    "media_type" "text" NOT NULL,
    "local_reference" "text" NOT NULL,
    "dispatch_id" "text",
    "captured_at" timestamp with time zone NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    CONSTRAINT "guard_incident_captures_capture_id_not_blank" CHECK (("length"("btrim"("capture_id")) > 0)),
    CONSTRAINT "guard_incident_captures_local_ref_not_blank" CHECK (("length"("btrim"("local_reference")) > 0)),
    CONSTRAINT "guard_incident_captures_media_type_not_blank" CHECK (("length"("btrim"("media_type")) > 0))
);


ALTER TABLE "public"."guard_incident_captures" OWNER TO "postgres";


COMMENT ON TABLE "public"."guard_incident_captures" IS 'Guard-captured incident media metadata (photo/video references).';



CREATE TABLE IF NOT EXISTS "public"."guard_location_heartbeats" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "heartbeat_id" "text" NOT NULL,
    "client_id" "text" NOT NULL,
    "site_id" "text" NOT NULL,
    "guard_id" "text" NOT NULL,
    "latitude" double precision NOT NULL,
    "longitude" double precision NOT NULL,
    "accuracy_meters" double precision,
    "recorded_at" timestamp with time zone NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    CONSTRAINT "guard_location_heartbeats_accuracy_non_negative" CHECK ((("accuracy_meters" IS NULL) OR ("accuracy_meters" >= (0)::double precision))),
    CONSTRAINT "guard_location_heartbeats_heartbeat_id_not_blank" CHECK (("length"("btrim"("heartbeat_id")) > 0))
);


ALTER TABLE "public"."guard_location_heartbeats" OWNER TO "postgres";


COMMENT ON TABLE "public"."guard_location_heartbeats" IS 'Periodic guard GPS heartbeats from mobile device tracking.';



CREATE TABLE IF NOT EXISTS "public"."guard_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "site_id" "uuid",
    "event_type" "text",
    "geo_lat" double precision,
    "geo_lng" double precision,
    "timestamp" timestamp with time zone DEFAULT "now"(),
    "notes" "text"
);


ALTER TABLE "public"."guard_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."guard_ops_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "event_id" "text" NOT NULL,
    "guard_id" "text" NOT NULL,
    "site_id" "text" NOT NULL,
    "shift_id" "text" NOT NULL,
    "event_type" "text" NOT NULL,
    "sequence" integer NOT NULL,
    "occurred_at" timestamp with time zone NOT NULL,
    "received_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "device_id" "text" NOT NULL,
    "app_version" "text" NOT NULL,
    "payload" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    CONSTRAINT "guard_ops_events_app_version_not_blank" CHECK (("length"("btrim"("app_version")) > 0)),
    CONSTRAINT "guard_ops_events_device_id_not_blank" CHECK (("length"("btrim"("device_id")) > 0)),
    CONSTRAINT "guard_ops_events_event_id_not_blank" CHECK (("length"("btrim"("event_id")) > 0)),
    CONSTRAINT "guard_ops_events_event_type_not_blank" CHECK (("length"("btrim"("event_type")) > 0)),
    CONSTRAINT "guard_ops_events_guard_id_not_blank" CHECK (("length"("btrim"("guard_id")) > 0)),
    CONSTRAINT "guard_ops_events_sequence_positive" CHECK (("sequence" > 0)),
    CONSTRAINT "guard_ops_events_shift_id_not_blank" CHECK (("length"("btrim"("shift_id")) > 0)),
    CONSTRAINT "guard_ops_events_site_id_not_blank" CHECK (("length"("btrim"("site_id")) > 0))
);


ALTER TABLE "public"."guard_ops_events" OWNER TO "postgres";


COMMENT ON TABLE "public"."guard_ops_events" IS 'Canonical append-only guard operations event log.';



CREATE TABLE IF NOT EXISTS "public"."guard_ops_media" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "media_id" "text" NOT NULL,
    "event_id" "text" NOT NULL,
    "guard_id" "text" NOT NULL,
    "site_id" "text" NOT NULL,
    "shift_id" "text" NOT NULL,
    "bucket" "text" NOT NULL,
    "path" "text" NOT NULL,
    "local_path" "text" NOT NULL,
    "captured_at" timestamp with time zone NOT NULL,
    "uploaded_at" timestamp with time zone,
    "sha256" "text",
    "upload_status" "text" DEFAULT 'queued'::"text" NOT NULL,
    "retry_count" integer DEFAULT 0 NOT NULL,
    "failure_reason" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "visual_norm_mode" "text",
    "visual_norm_metadata" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    CONSTRAINT "guard_ops_media_bucket_not_blank" CHECK (("length"("btrim"("bucket")) > 0)),
    CONSTRAINT "guard_ops_media_event_id_not_blank" CHECK (("length"("btrim"("event_id")) > 0)),
    CONSTRAINT "guard_ops_media_guard_id_not_blank" CHECK (("length"("btrim"("guard_id")) > 0)),
    CONSTRAINT "guard_ops_media_local_path_not_blank" CHECK (("length"("btrim"("local_path")) > 0)),
    CONSTRAINT "guard_ops_media_media_id_not_blank" CHECK (("length"("btrim"("media_id")) > 0)),
    CONSTRAINT "guard_ops_media_path_not_blank" CHECK (("length"("btrim"("path")) > 0)),
    CONSTRAINT "guard_ops_media_retry_non_negative" CHECK (("retry_count" >= 0)),
    CONSTRAINT "guard_ops_media_shift_id_not_blank" CHECK (("length"("btrim"("shift_id")) > 0)),
    CONSTRAINT "guard_ops_media_site_id_not_blank" CHECK (("length"("btrim"("site_id")) > 0)),
    CONSTRAINT "guard_ops_media_status_not_blank" CHECK (("length"("btrim"("upload_status")) > 0)),
    CONSTRAINT "guard_ops_media_visual_norm_ir_required" CHECK ((("visual_norm_mode" IS DISTINCT FROM 'ir'::"text") OR (COALESCE("lower"(("visual_norm_metadata" ->> 'ir_required'::"text")), 'false'::"text") = 'true'::"text"))),
    CONSTRAINT "guard_ops_media_visual_norm_min_match_score_valid" CHECK (((NOT ("visual_norm_metadata" ? 'min_match_score'::"text")) OR (("jsonb_typeof"(("visual_norm_metadata" -> 'min_match_score'::"text")) = 'number'::"text") AND (((("visual_norm_metadata" ->> 'min_match_score'::"text"))::integer >= 0) AND ((("visual_norm_metadata" ->> 'min_match_score'::"text"))::integer <= 100))))),
    CONSTRAINT "guard_ops_media_visual_norm_mode_valid" CHECK ((("visual_norm_mode" IS NULL) OR ("visual_norm_mode" = ANY (ARRAY['day'::"text", 'night'::"text", 'ir'::"text"]))))
);


ALTER TABLE "public"."guard_ops_media" OWNER TO "postgres";


COMMENT ON TABLE "public"."guard_ops_media" IS 'Guard media metadata and upload state linked to guard_ops_events.';



COMMENT ON COLUMN "public"."guard_ops_media"."visual_norm_mode" IS 'Visual normalization environment mode: day, night, or ir.';



COMMENT ON COLUMN "public"."guard_ops_media"."visual_norm_metadata" IS 'Visual normalization metadata payload (baseline, profile, thresholds, IR requirement).';



CREATE TABLE IF NOT EXISTS "public"."guard_panic_signals" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "signal_id" "text" NOT NULL,
    "client_id" "text" NOT NULL,
    "site_id" "text" NOT NULL,
    "guard_id" "text" NOT NULL,
    "latitude" double precision,
    "longitude" double precision,
    "triggered_at" timestamp with time zone NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    CONSTRAINT "guard_panic_signals_signal_id_not_blank" CHECK (("length"("btrim"("signal_id")) > 0))
);


ALTER TABLE "public"."guard_panic_signals" OWNER TO "postgres";


COMMENT ON TABLE "public"."guard_panic_signals" IS 'Emergency panic activations from guards.';



CREATE TABLE IF NOT EXISTS "public"."guard_profiles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "guard_id" "uuid" NOT NULL,
    "national_id" "text",
    "address" "text",
    "bank_name" "text",
    "account_number" "text",
    "branch_code" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."guard_profiles" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."guard_rls_readiness_checks" AS
 WITH "expected_guard_tables"("table_name") AS (
         VALUES ('guard_ops_events'::"text"), ('guard_ops_media'::"text"), ('guard_sync_operations'::"text"), ('guard_assignments'::"text"), ('guard_location_heartbeats'::"text"), ('guard_checkpoint_scans'::"text"), ('guard_incident_captures'::"text"), ('guard_panic_signals'::"text")
        ), "expected_guard_policies"("table_name", "policy_name") AS (
         VALUES ('guard_ops_events'::"text",'guard_ops_events_select_policy'::"text"), ('guard_ops_events'::"text",'guard_ops_events_insert_policy'::"text"), ('guard_ops_media'::"text",'guard_ops_media_select_policy'::"text"), ('guard_ops_media'::"text",'guard_ops_media_insert_policy'::"text"), ('guard_ops_media'::"text",'guard_ops_media_update_policy'::"text"), ('guard_sync_operations'::"text",'guard_sync_operations_select_policy'::"text"), ('guard_sync_operations'::"text",'guard_sync_operations_insert_policy'::"text"), ('guard_sync_operations'::"text",'guard_sync_operations_update_policy'::"text"), ('guard_assignments'::"text",'guard_assignments_select_policy'::"text"), ('guard_assignments'::"text",'guard_assignments_insert_policy'::"text"), ('guard_assignments'::"text",'guard_assignments_update_policy'::"text"), ('guard_location_heartbeats'::"text",'guard_location_heartbeats_select_policy'::"text"), ('guard_location_heartbeats'::"text",'guard_location_heartbeats_insert_policy'::"text"), ('guard_checkpoint_scans'::"text",'guard_checkpoint_scans_select_policy'::"text"), ('guard_checkpoint_scans'::"text",'guard_checkpoint_scans_insert_policy'::"text"), ('guard_incident_captures'::"text",'guard_incident_captures_select_policy'::"text"), ('guard_incident_captures'::"text",'guard_incident_captures_insert_policy'::"text"), ('guard_panic_signals'::"text",'guard_panic_signals_select_policy'::"text"), ('guard_panic_signals'::"text",'guard_panic_signals_insert_policy'::"text")
        )
 SELECT 'table_rls'::"text" AS "check_type",
    "expected_guard_tables"."table_name" AS "check_name",
        CASE
            WHEN (EXISTS ( SELECT 1
               FROM ("pg_class" "c"
                 JOIN "pg_namespace" "n" ON (("n"."oid" = "c"."relnamespace")))
              WHERE (("n"."nspname" = 'public'::"name") AND ("c"."relname" = "expected_guard_tables"."table_name") AND "c"."relrowsecurity"))) THEN 'PASS'::"text"
            ELSE 'FAIL'::"text"
        END AS "result"
   FROM "expected_guard_tables"
UNION ALL
 SELECT 'table_policy'::"text" AS "check_type",
    "format"('%s.%s'::"text", "expected_guard_policies"."table_name", "expected_guard_policies"."policy_name") AS "check_name",
        CASE
            WHEN (EXISTS ( SELECT 1
               FROM "pg_policies" "p"
              WHERE (("p"."schemaname" = 'public'::"name") AND ("p"."tablename" = "expected_guard_policies"."table_name") AND ("p"."policyname" = "expected_guard_policies"."policy_name")))) THEN 'PASS'::"text"
            ELSE 'FAIL'::"text"
        END AS "result"
   FROM "expected_guard_policies";


ALTER VIEW "public"."guard_rls_readiness_checks" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."guard_sites" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "guard_id" "uuid" NOT NULL,
    "site_id" "uuid" NOT NULL,
    "role" "text" DEFAULT 'primary'::"text",
    "assigned_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "guard_sites_role_check" CHECK (("role" = ANY (ARRAY['primary'::"text", 'secondary'::"text"])))
);


ALTER TABLE "public"."guard_sites" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."guard_storage_readiness_checks" AS
 WITH "expected_buckets"("bucket_name") AS (
         VALUES ('guard-shift-verification'::"text"), ('guard-patrol-images'::"text"), ('guard-incident-media'::"text")
        ), "expected_storage_policies"("policy_name") AS (
         VALUES ('guard_media_select_policy'::"text"), ('guard_media_insert_policy'::"text"), ('guard_media_update_policy'::"text"), ('guard_media_delete_policy'::"text")
        ), "storage_rls" AS (
         SELECT
                CASE
                    WHEN "c"."relrowsecurity" THEN 'PASS'::"text"
                    ELSE 'FAIL'::"text"
                END AS "result"
           FROM ("pg_class" "c"
             JOIN "pg_namespace" "n" ON (("n"."oid" = "c"."relnamespace")))
          WHERE (("n"."nspname" = 'storage'::"name") AND ("c"."relname" = 'objects'::"name"))
        )
 SELECT 'bucket'::"text" AS "check_type",
    "expected_buckets"."bucket_name" AS "check_name",
        CASE
            WHEN (EXISTS ( SELECT 1
               FROM "storage"."buckets" "b"
              WHERE ("b"."name" = "expected_buckets"."bucket_name"))) THEN 'PASS'::"text"
            ELSE 'FAIL'::"text"
        END AS "result"
   FROM "expected_buckets"
UNION ALL
 SELECT 'policy'::"text" AS "check_type",
    "expected_storage_policies"."policy_name" AS "check_name",
        CASE
            WHEN (EXISTS ( SELECT 1
               FROM "pg_policies" "p"
              WHERE (("p"."schemaname" = 'storage'::"name") AND ("p"."tablename" = 'objects'::"name") AND ("p"."policyname" = "expected_storage_policies"."policy_name")))) THEN 'PASS'::"text"
            ELSE 'FAIL'::"text"
        END AS "result"
   FROM "expected_storage_policies"
UNION ALL
 SELECT 'storage_rls'::"text" AS "check_type",
    'storage.objects'::"text" AS "check_name",
    COALESCE(( SELECT "storage_rls"."result"
           FROM "storage_rls"), 'FAIL'::"text") AS "result";


ALTER VIEW "public"."guard_storage_readiness_checks" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."guard_sync_operations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "operation_id" "text" NOT NULL,
    "operation_type" "text" NOT NULL,
    "operation_status" "text" DEFAULT 'queued'::"text" NOT NULL,
    "client_id" "text" NOT NULL,
    "site_id" "text" NOT NULL,
    "guard_id" "text" NOT NULL,
    "occurred_at" timestamp with time zone NOT NULL,
    "payload" "jsonb" NOT NULL,
    "failure_reason" "text",
    "retry_count" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "facade_id" "text",
    "facade_mode" "text",
    CONSTRAINT "guard_sync_operations_facade_mode_valid" CHECK ((("facade_mode" IS NULL) OR ("facade_mode" = ANY (ARRAY['live'::"text", 'stub'::"text", 'unknown'::"text"])))),
    CONSTRAINT "guard_sync_operations_operation_id_not_blank" CHECK (("length"("btrim"("operation_id")) > 0)),
    CONSTRAINT "guard_sync_operations_retry_count_non_negative" CHECK (("retry_count" >= 0)),
    CONSTRAINT "guard_sync_operations_status_not_blank" CHECK (("length"("btrim"("operation_status")) > 0)),
    CONSTRAINT "guard_sync_operations_type_not_blank" CHECK (("length"("btrim"("operation_type")) > 0))
);


ALTER TABLE "public"."guard_sync_operations" OWNER TO "postgres";


COMMENT ON TABLE "public"."guard_sync_operations" IS 'Offline guard operations queued and synchronized from Android guard devices.';



CREATE TABLE IF NOT EXISTS "public"."guards" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "first_name" "text" NOT NULL,
    "last_name" "text" NOT NULL,
    "grade" "text",
    "active" boolean DEFAULT true,
    "phone" "text",
    "site" "text",
    "competent" boolean DEFAULT false,
    "competency_type" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "meta" "jsonb" DEFAULT '{}'::"jsonb",
    "guard_id" "text",
    "client_id" "text",
    "primary_site_id" "text",
    "full_name" "text",
    "badge_number" "text",
    "ptt_identity" "text",
    "device_serial" "text",
    "auth_user_id" "uuid",
    "contact_phone" "text",
    "contact_email" "text",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "source_employee_id" "uuid"
);


ALTER TABLE "public"."guards" OWNER TO "postgres";


COMMENT ON TABLE "public"."guards" IS 'Guard directory records used to onboard and activate field devices per site.';



CREATE TABLE IF NOT EXISTS "public"."hourly_throughput" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "client_id" "text" NOT NULL,
    "site_id" "text" NOT NULL,
    "visit_date" "date" NOT NULL,
    "hour_of_day" integer NOT NULL,
    "visit_count" integer DEFAULT 0 NOT NULL,
    "completed_count" integer DEFAULT 0 NOT NULL,
    "entry_count" integer DEFAULT 0 NOT NULL,
    "exit_count" integer DEFAULT 0 NOT NULL,
    "service_count" integer DEFAULT 0 NOT NULL,
    "avg_dwell_minutes" double precision,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    CONSTRAINT "hourly_throughput_hour_of_day_check" CHECK ((("hour_of_day" >= 0) AND ("hour_of_day" <= 23)))
);


ALTER TABLE "public"."hourly_throughput" OWNER TO "postgres";


COMMENT ON TABLE "public"."hourly_throughput" IS 'Phase 1 ONYX BI persistence for UTC-dated per-hour throughput buckets. Writes are backend/service-role only; reads are client-scoped via RLS.';



CREATE TABLE IF NOT EXISTS "public"."incident_actions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "incident_id" "text" NOT NULL,
    "action_code" "text" NOT NULL,
    "action_label" "text" NOT NULL,
    "notes" "text",
    "triggered_by" "text" DEFAULT 'operator'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."incident_actions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."incident_outcomes" (
    "incident_id" "text" NOT NULL,
    "outcome" "text",
    "lessons_learned" "text",
    "closed_at" timestamp with time zone
);


ALTER TABLE "public"."incident_outcomes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."incident_snapshots" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "incident_id" "text",
    "captured_at" timestamp with time zone NOT NULL,
    "threats" "jsonb",
    "recommendations" "jsonb",
    "patrol_state" "jsonb"
);


ALTER TABLE "public"."incident_snapshots" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."incident_replay_timeline" AS
 SELECT "s"."incident_id",
    "s"."captured_at" AS "event_time",
    'SNAPSHOT'::"text" AS "event_type",
    "jsonb_build_object"('threats', "s"."threats", 'recommendations', "s"."recommendations", 'patrol_state', "s"."patrol_state") AS "event_payload"
   FROM "public"."incident_snapshots" "s"
UNION ALL
 SELECT "a"."incident_id",
    "a"."created_at" AS "event_time",
    'ACTION'::"text" AS "event_type",
    "jsonb_build_object"('action_code', "a"."action_code", 'action_label', "a"."action_label", 'notes', "a"."notes", 'triggered_by', "a"."triggered_by") AS "event_payload"
   FROM "public"."incident_actions" "a"
UNION ALL
 SELECT "o"."incident_id",
    "o"."closed_at" AS "event_time",
    'OUTCOME'::"text" AS "event_type",
    "jsonb_build_object"('outcome', "o"."outcome", 'lessons_learned', "o"."lessons_learned") AS "event_payload"
   FROM "public"."incident_outcomes" "o"
  WHERE ("o"."closed_at" IS NOT NULL);


ALTER VIEW "public"."incident_replay_timeline" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."incident_aar_metrics" AS
 SELECT "incident_id",
    (EXTRACT(epoch FROM ("min"(
        CASE
            WHEN ("event_type" = 'ACTION'::"text") THEN "event_time"
            ELSE NULL::timestamp with time zone
        END) - "min"(
        CASE
            WHEN ("event_type" = 'SNAPSHOT'::"text") THEN "event_time"
            ELSE NULL::timestamp with time zone
        END))))::integer AS "response_seconds",
    "count"(*) FILTER (WHERE ("event_type" = 'ACTION'::"text")) AS "action_count",
    "count"(*) FILTER (WHERE ("event_type" = 'SNAPSHOT'::"text")) AS "snapshot_count"
   FROM "public"."incident_replay_timeline" "r"
  GROUP BY "incident_id";


ALTER VIEW "public"."incident_aar_metrics" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."incident_aar_score_calc" AS
 SELECT "incident_id",
    "response_seconds",
    "action_count",
    "snapshot_count",
    LEAST(100, ((100 - (COALESCE("response_seconds", 300) / 3)) -
        CASE
            WHEN ("action_count" = 0) THEN 20
            ELSE 0
        END)) AS "aar_score"
   FROM "public"."incident_aar_metrics" "m";


ALTER VIEW "public"."incident_aar_score_calc" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."incident_aar_grade_calc" AS
 SELECT "incident_id",
    "response_seconds",
    "action_count",
    "snapshot_count",
    "aar_score",
        CASE
            WHEN ("aar_score" >= 85) THEN 'A'::"text"
            WHEN ("aar_score" >= 70) THEN 'B'::"text"
            WHEN ("aar_score" >= 55) THEN 'C'::"text"
            WHEN ("aar_score" >= 40) THEN 'D'::"text"
            ELSE 'F'::"text"
        END AS "aar_grade"
   FROM "public"."incident_aar_score_calc" "s";


ALTER VIEW "public"."incident_aar_grade_calc" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."incident_aar_scores" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "incident_id" "text" NOT NULL,
    "response_time_seconds" integer,
    "action_count" integer,
    "snapshot_count" integer,
    "outcome" "text",
    "aar_score" integer,
    "aar_grade" "text",
    "breakdown" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."incident_aar_scores" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."incident_intelligence" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "incident_id" "text" NOT NULL,
    "risk_score" numeric(4,2) NOT NULL,
    "risk_level" integer NOT NULL,
    "confidence" numeric(3,2) NOT NULL,
    "matched_mos" "text"[] NOT NULL,
    "decision_trace" "jsonb" NOT NULL,
    "human_required" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."incident_intelligence" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."incident_replay_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "incident_id" "text" NOT NULL,
    "event_time" timestamp with time zone NOT NULL,
    "event_type" "text" NOT NULL,
    "event_payload" "jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."incident_replay_events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."incident_replays" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "incident_name" "text",
    "start_time" timestamp with time zone,
    "end_time" timestamp with time zone,
    "summary" "text",
    "lessons_learned" "text"
);


ALTER TABLE "public"."incident_replays" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."incidents" (
    "id" "text" DEFAULT "gen_random_uuid"() NOT NULL,
    "external_id" "text",
    "source" "text",
    "risk_level" "text",
    "category" "text",
    "score" integer,
    "location" "text",
    "zone_id" "text",
    "zone_name" "text",
    "action_code" "text",
    "action_label" "text",
    "action_hint" "text",
    "raw_text" "text",
    "occurred_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "status" "text" DEFAULT 'OPEN'::"text" NOT NULL,
    "operator_notes" "text",
    "priority" "text",
    "channel" "text",
    "description" "text",
    "engine_data" "jsonb",
    "scope" "text" DEFAULT 'AREA'::"text" NOT NULL,
    "site_id" "text",
    "engine_message" "text",
    "payload" "jsonb",
    "risk_score" double precision,
    "type" "text",
    "zone" "text",
    "acknowledged_at" timestamp with time zone,
    "acknowledged_by" "uuid",
    "event_uid" "text",
    "client_id" "text",
    "incident_type" "public"."incident_type",
    "signal_received_at" timestamp with time zone,
    "triage_time" timestamp with time zone,
    "dispatch_time" timestamp with time zone,
    "arrival_time" timestamp with time zone,
    "resolution_time" timestamp with time zone,
    "controller_notes" "text",
    "field_report" "text",
    "media_attachments" "text"[] DEFAULT '{}'::"text"[],
    "evidence_hash" "text",
    "linked_employee_id" "uuid",
    "linked_guard_ops_event_id" "text",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "simulated" boolean DEFAULT false NOT NULL,
    "simulation_id" "text",
    "revealed_at" timestamp with time zone
);


ALTER TABLE "public"."incidents" OWNER TO "postgres";


COMMENT ON TABLE "public"."incidents" IS 'Immutable-closure incident chain table for operational timeline, evidence links, and legal reporting.';



CREATE OR REPLACE VIEW "public"."intel_keyword_events" AS
 SELECT "ie"."id" AS "intel_event_id",
    "lower"(TRIM(BOTH FROM "tag"."tag")) AS "keyword",
    "ie"."ingested_at",
    "ie"."severity",
    "ie"."confidence"
   FROM "public"."intel_events" "ie",
    LATERAL "unnest"("ie"."tags") "tag"("tag")
  WHERE ("ie"."archived" = false);


ALTER VIEW "public"."intel_keyword_events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."intel_patrol_links" (
    "intel_threat_id" "uuid" NOT NULL,
    "patrol_id" "uuid" NOT NULL,
    "linked_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."intel_patrol_links" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."intel_source_weights" (
    "source_type" "text" NOT NULL,
    "base_score" integer NOT NULL,
    "enabled" boolean DEFAULT true,
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "intel_source_weights_base_score_check" CHECK ((("base_score" >= 0) AND ("base_score" <= 100)))
);


ALTER TABLE "public"."intel_source_weights" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."intel_scoring_candidates" AS
 SELECT "ie"."id" AS "intel_event_id",
    "ie"."entity_type",
    "ie"."entity_id",
    LEAST(100, COALESCE("ie"."severity", (COALESCE("isw"."base_score", 20) + (COALESCE("ie"."confidence", 50) / 2)))) AS "score",
    "ie"."ingested_at" AS "computed_at"
   FROM ("public"."intel_events" "ie"
     LEFT JOIN "public"."intel_source_weights" "isw" ON ((("isw"."source_type" = "ie"."source_type") AND ("isw"."enabled" = true))))
  WHERE (("ie"."processed" = false) AND ("ie"."entity_type" IS NOT NULL) AND ("ie"."entity_id" IS NOT NULL));


ALTER VIEW "public"."intel_scoring_candidates" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."intel_scoring_candidates_strategic" AS
 SELECT "ie"."id" AS "intel_event_id",
    "ie"."entity_type",
    "ie"."entity_id",
    LEAST(100, COALESCE("ie"."severity", (COALESCE("isw"."base_score", 20) + (COALESCE("ie"."confidence", 50) / 2)))) AS "score",
    "ie"."ingested_at" AS "computed_at"
   FROM ("public"."intel_events" "ie"
     LEFT JOIN "public"."intel_source_weights" "isw" ON ((("isw"."source_type" = "ie"."source_type") AND ("isw"."enabled" = true))))
  WHERE (("ie"."processed" = false) AND ("ie"."entity_type" = ANY (ARRAY['area'::"text", 'keyword'::"text"])));


ALTER VIEW "public"."intel_scoring_candidates_strategic" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."intel_scoring_candidates_unlinked" AS
 SELECT "ie"."id" AS "intel_event_id",
    "ie"."entity_type",
    "ie"."entity_id",
    LEAST(100, COALESCE("ie"."severity", (COALESCE("isw"."base_score", 20) + (COALESCE("ie"."confidence", 50) / 2)))) AS "score",
    "ie"."ingested_at" AS "computed_at"
   FROM ("public"."intel_events" "ie"
     LEFT JOIN "public"."intel_source_weights" "isw" ON ((("isw"."source_type" = "ie"."source_type") AND ("isw"."enabled" = true))))
  WHERE (("ie"."processed" = false) AND ("ie"."entity_type" = ANY (ARRAY['area'::"text", 'keyword'::"text"])));


ALTER VIEW "public"."intel_scoring_candidates_unlinked" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."intelligence_snapshots" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "incident_id" "uuid" NOT NULL,
    "site_id" "uuid",
    "risk_score" integer NOT NULL,
    "risk_level" "text" NOT NULL,
    "trace" "jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."intelligence_snapshots" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."keyword_escalations" (
    "keyword" "text" NOT NULL,
    "last_escalated_at" timestamp with time zone NOT NULL
);


ALTER TABLE "public"."keyword_escalations" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."keyword_trend_spikes" AS
 WITH "recent" AS (
         SELECT "intel_keyword_events"."keyword",
            "count"(*) AS "recent_count",
            "avg"("intel_keyword_events"."severity") AS "recent_avg_severity"
           FROM "public"."intel_keyword_events"
          WHERE ("intel_keyword_events"."ingested_at" >= ("now"() - '00:30:00'::interval))
          GROUP BY "intel_keyword_events"."keyword"
        ), "baseline" AS (
         SELECT "intel_keyword_events"."keyword",
            "count"(*) AS "baseline_count"
           FROM "public"."intel_keyword_events"
          WHERE (("intel_keyword_events"."ingested_at" < ("now"() - '00:30:00'::interval)) AND ("intel_keyword_events"."ingested_at" >= ("now"() - '24:00:00'::interval)))
          GROUP BY "intel_keyword_events"."keyword"
        )
 SELECT "r"."keyword",
    "r"."recent_count",
    COALESCE("b"."baseline_count", (0)::bigint) AS "baseline_count",
    "r"."recent_avg_severity",
        CASE
            WHEN (("r"."recent_count" >= 3) AND ("r"."recent_count" > (COALESCE("b"."baseline_count", (0)::bigint) * 2))) THEN true
            ELSE false
        END AS "is_spike"
   FROM ("recent" "r"
     LEFT JOIN "baseline" "b" ON (("b"."keyword" = "r"."keyword")));


ALTER VIEW "public"."keyword_trend_spikes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."logs" (
    "id" bigint NOT NULL,
    "user_id" "uuid",
    "site_code" "text",
    "log_type" "text" NOT NULL,
    "message" "text" NOT NULL,
    "meta" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."logs" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."logs_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."logs_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."logs_id_seq" OWNED BY "public"."logs"."id";



CREATE TABLE IF NOT EXISTS "public"."mo_library" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "code" "text",
    "description" "text",
    "tags" "text"[],
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."mo_library" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."omnix_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "log_type" "text" NOT NULL,
    "message" "text",
    "meta" "jsonb",
    "incident_id" "text"
);


ALTER TABLE "public"."omnix_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."onyx_alert_outcomes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "alert_id" "text" NOT NULL,
    "site_id" "text" NOT NULL,
    "client_id" "text" NOT NULL,
    "zone_id" "text",
    "outcome" "text" NOT NULL,
    "operator_id" "text",
    "note" "text",
    "occurred_at" timestamp with time zone DEFAULT "now"(),
    "confidence_at_time" double precision,
    "power_mode_at_time" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."onyx_alert_outcomes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."onyx_awareness_latency" (
    "alert_id" "text" NOT NULL,
    "event_id" "text" NOT NULL,
    "site_id" "text" NOT NULL,
    "client_id" "text" NOT NULL,
    "dvr_event_at" timestamp with time zone NOT NULL,
    "snapshot_at" timestamp with time zone,
    "yolo_at" timestamp with time zone,
    "telegram_at" timestamp with time zone,
    "total_ms" integer,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."onyx_awareness_latency" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."onyx_client_trust_snapshots" (
    "client_id" "text" NOT NULL,
    "site_id" "text" NOT NULL,
    "period_start" timestamp with time zone NOT NULL,
    "period_end" timestamp with time zone NOT NULL,
    "period_label" "text" NOT NULL,
    "incidents_handled" integer DEFAULT 0 NOT NULL,
    "avg_response_seconds" double precision DEFAULT 0 NOT NULL,
    "false_alarm_rate" double precision DEFAULT 0 NOT NULL,
    "false_alarms_reduced" double precision DEFAULT 0 NOT NULL,
    "guard_patrol_compliance" double precision DEFAULT 0 NOT NULL,
    "checkpoints_completed" integer DEFAULT 0 NOT NULL,
    "system_uptime" double precision DEFAULT 0 NOT NULL,
    "cameras_online" integer DEFAULT 0 NOT NULL,
    "cameras_total" integer DEFAULT 0 NOT NULL,
    "alerts_delivered" integer DEFAULT 0 NOT NULL,
    "avg_awareness_seconds" double precision DEFAULT 0 NOT NULL,
    "evidence_certificates_issued" integer DEFAULT 0 NOT NULL,
    "top_incident_zones" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "safer_score" integer DEFAULT 0 NOT NULL,
    "safer_score_trend" "text" DEFAULT 'stable'::"text" NOT NULL,
    "snapshot_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."onyx_client_trust_snapshots" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."onyx_event_store" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "sequence" bigint NOT NULL,
    "site_id" "text" NOT NULL,
    "client_id" "text" DEFAULT ''::"text" NOT NULL,
    "event_type" "text" NOT NULL,
    "event_data" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "occurred_at" timestamp with time zone NOT NULL,
    "hash" "text" NOT NULL,
    "previous_hash" "text" NOT NULL
);


ALTER TABLE "public"."onyx_event_store" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."onyx_evidence_certificates" (
    "certificate_id" "uuid" NOT NULL,
    "event_id" "text" NOT NULL,
    "incident_id" "text",
    "site_id" "text" NOT NULL,
    "client_id" "text" NOT NULL,
    "camera_id" "text" NOT NULL,
    "detected_at" timestamp with time zone NOT NULL,
    "issued_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "snapshot_hash" "text",
    "event_hash" "text" NOT NULL,
    "chain_position" bigint NOT NULL,
    "previous_certificate_hash" "text" DEFAULT 'GENESIS'::"text" NOT NULL,
    "certificate_hash" "text" NOT NULL,
    "confidence" double precision,
    "face_match_id" "text",
    "zone_id" "text",
    "issuer" "text" NOT NULL,
    "version" "text" NOT NULL,
    "valid" boolean DEFAULT true NOT NULL,
    "event_data" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL
);


ALTER TABLE "public"."onyx_evidence_certificates" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."onyx_operator_scores" (
    "operator_id" "text" NOT NULL,
    "site_id" "text" NOT NULL,
    "period" "text" NOT NULL,
    "avg_response_seconds" double precision DEFAULT 0 NOT NULL,
    "correct_decisions" integer DEFAULT 0 NOT NULL,
    "incorrect_decisions" integer DEFAULT 0 NOT NULL,
    "missed_escalations" integer DEFAULT 0 NOT NULL,
    "simulations_completed" integer DEFAULT 0 NOT NULL,
    "score" double precision DEFAULT 0 NOT NULL,
    "weaknesses" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "recommendations" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."onyx_operator_scores" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."onyx_operator_simulations" (
    "id" "text" NOT NULL,
    "incident_id" "text" NOT NULL,
    "incident_event_uid" "text" NOT NULL,
    "operator_id" "text" NOT NULL,
    "site_id" "text" NOT NULL,
    "client_id" "text" DEFAULT ''::"text" NOT NULL,
    "simulated" boolean DEFAULT true NOT NULL,
    "scenario_type" "text" NOT NULL,
    "expected_decision" "text" NOT NULL,
    "injected_at" timestamp with time zone NOT NULL,
    "response_at" timestamp with time zone,
    "revealed_at" timestamp with time zone,
    "response_seconds" double precision,
    "action_taken" "text",
    "escalation_decision" "text",
    "completed" boolean DEFAULT false NOT NULL,
    "score_delta" double precision DEFAULT 0 NOT NULL,
    "result_label" "text" DEFAULT 'pending'::"text" NOT NULL,
    "headline" "text" DEFAULT ''::"text" NOT NULL,
    "summary" "text" DEFAULT ''::"text" NOT NULL
);


ALTER TABLE "public"."onyx_operator_simulations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."onyx_power_mode_events" (
    "site_id" "text" NOT NULL,
    "mode" "text" NOT NULL,
    "reason" "text" NOT NULL,
    "occurred_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."onyx_power_mode_events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."onyx_settings" (
    "key" "text" NOT NULL,
    "value_text" "text" DEFAULT ''::"text" NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."onyx_settings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."operational_nodes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "latitude" double precision NOT NULL,
    "longitude" double precision NOT NULL,
    "status" "text" NOT NULL,
    "radius" integer DEFAULT 5000,
    "node_type" "text" DEFAULT 'site'::"text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "operational_nodes_status_check" CHECK (("status" = ANY (ARRAY['green'::"text", 'amber'::"text", 'red'::"text"])))
);


ALTER TABLE "public"."operational_nodes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ops_orders" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "order_type" "public"."ops_order_type_enum" NOT NULL,
    "issued_by" "uuid" NOT NULL,
    "issued_to" "uuid" NOT NULL,
    "site_id" "uuid" NOT NULL,
    "related_entity_id" "uuid",
    "issued_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "expires_at" timestamp with time zone NOT NULL,
    "acknowledged_at" timestamp with time zone,
    "status" "text" DEFAULT 'OPEN'::"text" NOT NULL
);


ALTER TABLE "public"."ops_orders" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."patrol_checkpoint_scans" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "guard_id" "text" NOT NULL,
    "site_id" "text" NOT NULL,
    "client_id" "text" DEFAULT ''::"text" NOT NULL,
    "checkpoint_id" "text" NOT NULL,
    "checkpoint_name" "text" NOT NULL,
    "scanned_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "lat" double precision,
    "lon" double precision,
    "method" "text" DEFAULT 'qr'::"text" NOT NULL,
    "valid" boolean DEFAULT true NOT NULL,
    "notes" "text"
);


ALTER TABLE "public"."patrol_checkpoint_scans" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."patrol_checkpoints" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "route_id" "uuid",
    "site_id" "text" NOT NULL,
    "checkpoint_name" "text" NOT NULL,
    "checkpoint_code" "text" NOT NULL,
    "sequence_order" integer DEFAULT 0 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."patrol_checkpoints" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."patrol_compliance" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "site_id" "text" NOT NULL,
    "guard_id" "text" NOT NULL,
    "compliance_date" "date" DEFAULT CURRENT_DATE NOT NULL,
    "expected_patrols" integer DEFAULT 0 NOT NULL,
    "completed_patrols" integer DEFAULT 0 NOT NULL,
    "missed_checkpoints" "text"[] DEFAULT '{}'::"text"[],
    "compliance_percent" numeric DEFAULT 0 NOT NULL
);


ALTER TABLE "public"."patrol_compliance" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."patrol_route_cooldowns" (
    "patrol_id" "uuid" NOT NULL,
    "last_recommended_at" timestamp with time zone NOT NULL
);


ALTER TABLE "public"."patrol_route_cooldowns" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."patrol_routes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "site_id" "text" NOT NULL,
    "route_name" "text" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."patrol_routes" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."patrol_routing_candidates" AS
 SELECT "patrol_id",
    "guard_id",
    "site_id",
    "status",
    "created_at" AS "patrol_started_at",
    "threat_level",
    "threat_score",
    "threat_computed_at"
   FROM "public"."active_ops_with_threats" "ao"
  WHERE (("threat_level" = ANY (ARRAY['HIGH'::"text", 'MEDIUM'::"text"])) AND ("threat_computed_at" >= ("now"() - '01:00:00'::interval)));


ALTER VIEW "public"."patrol_routing_candidates" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."patrol_scans" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "site_id" "text" NOT NULL,
    "guard_id" "text" NOT NULL,
    "checkpoint_id" "uuid",
    "checkpoint_name" "text" NOT NULL,
    "scanned_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "lat" numeric,
    "lon" numeric,
    "note" "text"
);


ALTER TABLE "public"."patrol_scans" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."patrol_violations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "patrol_trigger_id" "uuid" NOT NULL,
    "guard_id" "uuid" NOT NULL,
    "site_id" "uuid" NOT NULL,
    "violation_type" "text" NOT NULL,
    "severity" "text" DEFAULT 'MEDIUM'::"text" NOT NULL,
    "occurred_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "resolved" boolean DEFAULT false NOT NULL,
    "resolved_at" timestamp with time zone,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."patrol_violations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."patrols" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "site_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "patrol_type" "text" NOT NULL,
    "min_interval_minutes" integer NOT NULL,
    "max_interval_minutes" integer NOT NULL,
    "max_idle_minutes" integer NOT NULL,
    "required_nfc_scans" integer NOT NULL,
    "threat_weight" integer DEFAULT 1 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    CONSTRAINT "patrols_patrol_type_check" CHECK (("patrol_type" = ANY (ARRAY['FIXED'::"text", 'RANDOMISED'::"text"])))
);


ALTER TABLE "public"."patrols" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."posts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "site_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "required_guard_level" integer NOT NULL,
    "start_time" time without time zone NOT NULL,
    "end_time" time without time zone NOT NULL,
    "geofence_id" "uuid",
    "required_checkins" integer DEFAULT 1 NOT NULL,
    "sla_tolerance_minutes" integer DEFAULT 5 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL
);


ALTER TABLE "public"."posts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."regional_risk_snapshots" (
    "region_code" "text" NOT NULL,
    "risk_score" numeric,
    "velocity_score" numeric,
    "sentiment_pressure" numeric,
    "last_updated" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."regional_risk_snapshots" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."roles" (
    "id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "permissions" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."roles" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."roles_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."roles_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."roles_id_seq" OWNED BY "public"."roles"."id";



CREATE TABLE IF NOT EXISTS "public"."site_alarm_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "site_id" "text" NOT NULL,
    "device_id" "text" NOT NULL,
    "event_type" "text" NOT NULL,
    "zone_id" "text",
    "area_id" "text",
    "zone_name" "text",
    "area_name" "text",
    "armed_state" "text",
    "occurred_at" timestamp with time zone NOT NULL,
    "raw_payload" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL
);


ALTER TABLE "public"."site_alarm_events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."site_alert_config" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "site_id" "text" NOT NULL,
    "alert_window_start" time without time zone DEFAULT '23:00:00'::time without time zone NOT NULL,
    "alert_window_end" time without time zone DEFAULT '08:00:00'::time without time zone NOT NULL,
    "timezone" "text" DEFAULT 'Africa/Johannesburg'::"text" NOT NULL,
    "perimeter_sensitivity" "text" DEFAULT 'suspicious_only'::"text" NOT NULL,
    "semi_perimeter_sensitivity" "text" DEFAULT 'suspicious_only'::"text" NOT NULL,
    "indoor_sensitivity" "text" DEFAULT 'off'::"text" NOT NULL,
    "loiter_detection_minutes" integer DEFAULT 3 NOT NULL,
    "perimeter_sequence_alert" boolean DEFAULT true NOT NULL,
    "quiet_hours_sensitivity" "text" DEFAULT 'all_motion'::"text" NOT NULL,
    "day_sensitivity" "text" DEFAULT 'suspicious_only'::"text" NOT NULL
);


ALTER TABLE "public"."site_alert_config" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."site_api_tokens" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "site_id" "text" NOT NULL,
    "token" "text" NOT NULL,
    "label" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "last_used_at" timestamp with time zone
);


ALTER TABLE "public"."site_api_tokens" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."site_awareness_snapshots" (
    "site_id" "text" NOT NULL,
    "client_id" "text" NOT NULL,
    "snapshot_at" timestamp with time zone NOT NULL,
    "channels" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "detections" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "perimeter_clear" boolean DEFAULT true NOT NULL,
    "known_faults" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "active_alerts" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."site_awareness_snapshots" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."site_camera_zones" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "site_id" "text" NOT NULL,
    "channel_id" integer NOT NULL,
    "zone_name" "text" NOT NULL,
    "zone_type" "text" NOT NULL,
    "is_perimeter" boolean DEFAULT false NOT NULL,
    "is_indoor" boolean DEFAULT false NOT NULL,
    "notes" "text"
);


ALTER TABLE "public"."site_camera_zones" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."site_expected_visitors" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "site_id" "text" NOT NULL,
    "visitor_name" "text" NOT NULL,
    "visitor_role" "text" DEFAULT 'visitor'::"text" NOT NULL,
    "visit_days" "text"[] DEFAULT '{}'::"text"[],
    "visit_start" time without time zone,
    "visit_end" time without time zone,
    "visit_type" "text" DEFAULT 'scheduled'::"text",
    "visit_date" "date",
    "is_active" boolean DEFAULT true,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "expires_at" timestamp with time zone
);


ALTER TABLE "public"."site_expected_visitors" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."site_identity_approval_decisions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "client_id" "text" NOT NULL,
    "site_id" "text" NOT NULL,
    "profile_id" "uuid",
    "intelligence_id" "text",
    "decision" "text" NOT NULL,
    "source" "text" DEFAULT 'admin'::"text" NOT NULL,
    "decided_by" "text" NOT NULL,
    "decision_summary" "text",
    "decided_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "metadata" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    CONSTRAINT "site_identity_approval_decisions_decided_by_not_blank" CHECK (("length"("btrim"("decided_by")) > 0)),
    CONSTRAINT "site_identity_approval_decisions_decision_valid" CHECK (("decision" = ANY (ARRAY['approve_once'::"text", 'approve_always'::"text", 'review'::"text", 'escalate'::"text", 'revoke'::"text"]))),
    CONSTRAINT "site_identity_approval_decisions_metadata_is_object" CHECK (("jsonb_typeof"("metadata") = 'object'::"text")),
    CONSTRAINT "site_identity_approval_decisions_source_valid" CHECK (("source" = ANY (ARRAY['admin'::"text", 'telegram'::"text", 'ai_proposal'::"text", 'system'::"text"])))
);


ALTER TABLE "public"."site_identity_approval_decisions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."site_identity_profiles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "client_id" "text" NOT NULL,
    "site_id" "text" NOT NULL,
    "identity_type" "text" NOT NULL,
    "category" "text" DEFAULT 'unknown'::"text" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "display_name" "text" NOT NULL,
    "face_match_id" "text",
    "plate_number" "text",
    "external_reference" "text",
    "notes" "text",
    "valid_from" timestamp with time zone,
    "valid_until" timestamp with time zone,
    "metadata" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    CONSTRAINT "site_identity_profiles_category_valid" CHECK (("category" = ANY (ARRAY['employee'::"text", 'family'::"text", 'resident'::"text", 'visitor'::"text", 'contractor'::"text", 'delivery'::"text", 'unknown'::"text"]))),
    CONSTRAINT "site_identity_profiles_display_name_not_blank" CHECK (("length"("btrim"("display_name")) > 0)),
    CONSTRAINT "site_identity_profiles_identity_required" CHECK (((COALESCE("length"("btrim"("face_match_id")), 0) > 0) OR (COALESCE("length"("btrim"("plate_number")), 0) > 0) OR (COALESCE("length"("btrim"("external_reference")), 0) > 0))),
    CONSTRAINT "site_identity_profiles_metadata_is_object" CHECK (("jsonb_typeof"("metadata") = 'object'::"text")),
    CONSTRAINT "site_identity_profiles_status_valid" CHECK (("status" = ANY (ARRAY['allowed'::"text", 'flagged'::"text", 'pending'::"text", 'expired'::"text"]))),
    CONSTRAINT "site_identity_profiles_type_valid" CHECK (("identity_type" = ANY (ARRAY['person'::"text", 'vehicle'::"text"]))),
    CONSTRAINT "site_identity_profiles_valid_window" CHECK ((("valid_until" IS NULL) OR ("valid_from" IS NULL) OR ("valid_until" >= "valid_from")))
);


ALTER TABLE "public"."site_identity_profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."site_intelligence_profiles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "site_id" "text" NOT NULL,
    "industry_type" "text" DEFAULT 'residential'::"text" NOT NULL,
    "operating_hours_start" time without time zone DEFAULT '08:00:00'::time without time zone,
    "operating_hours_end" time without time zone DEFAULT '18:00:00'::time without time zone,
    "operating_days" "text"[] DEFAULT '{monday,tuesday,wednesday,thursday,friday}'::"text"[],
    "timezone" "text" DEFAULT 'Africa/Johannesburg'::"text",
    "is_24h_operation" boolean DEFAULT false,
    "expected_staff_count" integer DEFAULT 0,
    "expected_resident_count" integer DEFAULT 0,
    "expected_vehicle_count" integer DEFAULT 0,
    "has_guard" boolean DEFAULT false,
    "has_armed_response" boolean DEFAULT false,
    "after_hours_sensitivity" "text" DEFAULT 'high'::"text",
    "during_hours_sensitivity" "text" DEFAULT 'medium'::"text",
    "monitor_staff_activity" boolean DEFAULT false,
    "inactive_staff_alert_minutes" integer DEFAULT 30,
    "monitor_till_attendance" boolean DEFAULT false,
    "till_unattended_minutes" integer DEFAULT 5,
    "monitor_restricted_zones" boolean DEFAULT false,
    "monitor_vehicle_movement" boolean DEFAULT true,
    "after_hours_vehicle_alert" boolean DEFAULT true,
    "send_shift_start_briefing" boolean DEFAULT true,
    "send_shift_end_report" boolean DEFAULT true,
    "send_daily_summary" boolean DEFAULT true,
    "daily_summary_time" time without time zone DEFAULT '07:00:00'::time without time zone,
    "custom_rules" "jsonb" DEFAULT '[]'::"jsonb"
);


ALTER TABLE "public"."site_intelligence_profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."site_occupancy_config" (
    "site_id" "text" NOT NULL,
    "expected_occupancy" integer DEFAULT 0 NOT NULL,
    "occupancy_label" "text" DEFAULT 'people'::"text" NOT NULL,
    "site_type" "text" DEFAULT 'private_residence'::"text" NOT NULL,
    "reset_hour" integer DEFAULT 3 NOT NULL,
    "has_gate_sensors" boolean DEFAULT false
);


ALTER TABLE "public"."site_occupancy_config" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."site_occupancy_sessions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "site_id" "text" NOT NULL,
    "session_date" "date" DEFAULT CURRENT_DATE NOT NULL,
    "peak_detected" integer DEFAULT 0 NOT NULL,
    "last_detection_at" timestamp with time zone,
    "channels_with_detections" "text"[] DEFAULT '{}'::"text"[],
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."site_occupancy_sessions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."site_vehicle_registry" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "site_id" "text" NOT NULL,
    "plate_number" "text" NOT NULL,
    "vehicle_description" "text",
    "owner_name" "text",
    "owner_role" "text" DEFAULT 'resident'::"text",
    "is_active" boolean DEFAULT true,
    "visit_type" "text" DEFAULT 'permanent'::"text",
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."site_vehicle_registry" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."site_zone_rules" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "site_id" "text" NOT NULL,
    "zone_name" "text" NOT NULL,
    "zone_type" "text" NOT NULL,
    "allowed_roles" "text"[] DEFAULT '{}'::"text"[],
    "access_hours_start" time without time zone,
    "access_hours_end" time without time zone,
    "access_days" "text"[] DEFAULT '{}'::"text"[],
    "violation_action" "text" DEFAULT 'alert'::"text",
    "max_dwell_minutes" integer,
    "requires_escort" boolean DEFAULT false,
    "is_restricted" boolean DEFAULT false
);


ALTER TABLE "public"."site_zone_rules" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."site_zones" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "site_id" "uuid" NOT NULL,
    "code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."site_zones" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sites" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "client_name" "text",
    "description" "text",
    "address" "text",
    "city" "text",
    "latitude" double precision DEFAULT '-26.2041'::numeric,
    "longitude" double precision DEFAULT 28.0473,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "risk_class" "text",
    "active" boolean DEFAULT true NOT NULL,
    "geo_point" "public"."geography"(Point,4326),
    "site_id" "text" NOT NULL,
    "client_id" "text" NOT NULL,
    "site_name" "text" NOT NULL,
    "site_code" "text",
    "timezone" "text" DEFAULT 'UTC'::"text" NOT NULL,
    "address_line_1" "text",
    "address_line_2" "text",
    "region" "text",
    "postal_code" "text",
    "country_code" "text",
    "geofence_radius_meters" double precision,
    "metadata" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "physical_address" "text",
    "site_layout_map_url" "text",
    "entry_protocol" "text",
    "hardware_ids" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "zone_labels" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "risk_rating" integer DEFAULT 3 NOT NULL,
    "risk_profile" "public"."site_risk_profile",
    "guard_nudge_frequency_minutes" integer,
    "escalation_trigger_minutes" integer,
    CONSTRAINT "sites_escalation_trigger_positive" CHECK ((("escalation_trigger_minutes" IS NULL) OR ("escalation_trigger_minutes" >= 1))),
    CONSTRAINT "sites_hardware_ids_is_array" CHECK (("jsonb_typeof"("hardware_ids") = 'array'::"text")),
    CONSTRAINT "sites_nudge_frequency_positive" CHECK ((("guard_nudge_frequency_minutes" IS NULL) OR ("guard_nudge_frequency_minutes" >= 1))),
    CONSTRAINT "sites_risk_rating_valid" CHECK ((("risk_rating" >= 1) AND ("risk_rating" <= 5))),
    CONSTRAINT "sites_zone_labels_is_object" CHECK (("jsonb_typeof"("zone_labels") = 'object'::"text"))
);


ALTER TABLE "public"."sites" OWNER TO "postgres";


COMMENT ON TABLE "public"."sites" IS 'Site directory records linked to clients; source of site metadata for guard and control flows.';



CREATE TABLE IF NOT EXISTS "public"."staff" (
    "staff_id" "text" NOT NULL,
    "client_id" "text" NOT NULL,
    "site_id" "text",
    "full_name" "text" NOT NULL,
    "staff_role" "text" DEFAULT 'staff'::"text" NOT NULL,
    "employee_code" "text",
    "auth_user_id" "uuid",
    "contact_phone" "text",
    "contact_email" "text",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "source_employee_id" "uuid",
    "first_name" "text",
    "last_name" "text",
    CONSTRAINT "staff_full_name_not_blank" CHECK (("length"("btrim"("full_name")) > 0)),
    CONSTRAINT "staff_metadata_is_object" CHECK (("jsonb_typeof"("metadata") = 'object'::"text")),
    CONSTRAINT "staff_role_not_blank" CHECK (("length"("btrim"("staff_role")) > 0)),
    CONSTRAINT "staff_staff_id_not_blank" CHECK (("length"("btrim"("staff_id")) > 0))
);


ALTER TABLE "public"."staff" OWNER TO "postgres";


COMMENT ON TABLE "public"."staff" IS 'Staff directory records for non-controller site personnel.';



CREATE TABLE IF NOT EXISTS "public"."telegram_identity_intake" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "client_id" "text" NOT NULL,
    "site_id" "text" NOT NULL,
    "endpoint_id" "uuid",
    "raw_text" "text" NOT NULL,
    "parsed_display_name" "text",
    "parsed_face_match_id" "text",
    "parsed_plate_number" "text",
    "parsed_category" "text" DEFAULT 'unknown'::"text" NOT NULL,
    "valid_from" timestamp with time zone,
    "valid_until" timestamp with time zone,
    "ai_confidence" double precision DEFAULT 0 NOT NULL,
    "approval_state" "text" DEFAULT 'pending'::"text" NOT NULL,
    "metadata" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    CONSTRAINT "telegram_identity_intake_approval_state_valid" CHECK (("approval_state" = ANY (ARRAY['pending'::"text", 'proposed'::"text", 'approved'::"text", 'rejected'::"text", 'expired'::"text"]))),
    CONSTRAINT "telegram_identity_intake_category_valid" CHECK (("parsed_category" = ANY (ARRAY['employee'::"text", 'family'::"text", 'resident'::"text", 'visitor'::"text", 'contractor'::"text", 'delivery'::"text", 'unknown'::"text"]))),
    CONSTRAINT "telegram_identity_intake_confidence_range" CHECK ((("ai_confidence" >= (0)::double precision) AND ("ai_confidence" <= (1)::double precision))),
    CONSTRAINT "telegram_identity_intake_metadata_is_object" CHECK (("jsonb_typeof"("metadata") = 'object'::"text")),
    CONSTRAINT "telegram_identity_intake_raw_text_not_blank" CHECK (("length"("btrim"("raw_text")) > 0)),
    CONSTRAINT "telegram_identity_intake_valid_window" CHECK ((("valid_until" IS NULL) OR ("valid_from" IS NULL) OR ("valid_until" >= "valid_from")))
);


ALTER TABLE "public"."telegram_identity_intake" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."telegram_inbound_updates" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "update_id" bigint NOT NULL,
    "chat_id" "text",
    "update_json" "jsonb" NOT NULL,
    "received_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "processed" boolean DEFAULT false NOT NULL
);


ALTER TABLE "public"."telegram_inbound_updates" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."threat_assessments" AS
 SELECT "id",
    "entity_type",
    "entity_id",
    "score",
    "computed_at" AS "created_at"
   FROM "public"."threat_scores" "ts";


ALTER VIEW "public"."threat_assessments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."threat_decay_profiles" (
    "threat_type" "text" NOT NULL,
    "decay_interval" interval NOT NULL
);


ALTER TABLE "public"."threat_decay_profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."threats" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "risk_score" double precision,
    "risk_level" "text",
    "dcw_seconds" integer,
    "source" "text",
    "evaluated_at" timestamp with time zone,
    "data" "jsonb",
    "decision_trace" "jsonb",
    "geo_scope" "jsonb",
    "confidence" double precision DEFAULT 0.5
);

ALTER TABLE ONLY "public"."threats" FORCE ROW LEVEL SECURITY;


ALTER TABLE "public"."threats" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."users" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "full_name" "text" NOT NULL,
    "phone" "text",
    "email" "text",
    "role_id" bigint,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."users" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."vehicle_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "plate" "text",
    "site_id" "uuid",
    "timestamp" timestamp with time zone DEFAULT "now"(),
    "matched_mo" boolean DEFAULT false,
    "notes" "text"
);


ALTER TABLE "public"."vehicle_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."vehicle_visits" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "client_id" "text" NOT NULL,
    "site_id" "text" NOT NULL,
    "vehicle_key" "text" NOT NULL,
    "plate_number" "text" NOT NULL,
    "started_at_utc" timestamp with time zone NOT NULL,
    "last_seen_at_utc" timestamp with time zone NOT NULL,
    "completed_at_utc" timestamp with time zone,
    "saw_entry" boolean DEFAULT false NOT NULL,
    "saw_service" boolean DEFAULT false NOT NULL,
    "saw_exit" boolean DEFAULT false NOT NULL,
    "dwell_minutes" double precision,
    "visit_status" "text" NOT NULL,
    "is_suspicious_short" boolean DEFAULT false NOT NULL,
    "is_loitering" boolean DEFAULT false NOT NULL,
    "event_count" integer DEFAULT 0 NOT NULL,
    "event_ids" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "intelligence_ids" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "zone_labels" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    CONSTRAINT "vehicle_visits_visit_status_check" CHECK (("visit_status" = ANY (ARRAY['completed'::"text", 'incomplete'::"text", 'active'::"text"])))
);


ALTER TABLE "public"."vehicle_visits" OWNER TO "postgres";


COMMENT ON TABLE "public"."vehicle_visits" IS 'Phase 1 ONYX BI persistence for per-visit vehicle analytics. Writes are backend/service-role only; reads are client-scoped via RLS.';



CREATE TABLE IF NOT EXISTS "public"."vehicles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "client_id" "text" NOT NULL,
    "site_id" "text",
    "vehicle_callsign" "text" NOT NULL,
    "license_plate" "text" NOT NULL,
    "vehicle_type" "public"."vehicle_type" DEFAULT 'general_patrol_vehicle'::"public"."vehicle_type" NOT NULL,
    "maintenance_status" "public"."vehicle_maintenance_status" DEFAULT 'ok'::"public"."vehicle_maintenance_status" NOT NULL,
    "service_due_date" "date",
    "roadworthy_expiry" "date",
    "odometer_km" integer,
    "fuel_percent" numeric(5,2),
    "assigned_employee_id" "uuid",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    CONSTRAINT "vehicles_callsign_not_blank" CHECK (("length"("btrim"("vehicle_callsign")) > 0)),
    CONSTRAINT "vehicles_fuel_percent_valid" CHECK ((("fuel_percent" IS NULL) OR (("fuel_percent" >= (0)::numeric) AND ("fuel_percent" <= (100)::numeric)))),
    CONSTRAINT "vehicles_license_plate_not_blank" CHECK (("length"("btrim"("license_plate")) > 0)),
    CONSTRAINT "vehicles_metadata_is_object" CHECK (("jsonb_typeof"("metadata") = 'object'::"text")),
    CONSTRAINT "vehicles_odometer_non_negative" CHECK ((("odometer_km" IS NULL) OR ("odometer_km" >= 0)))
);


ALTER TABLE "public"."vehicles" OWNER TO "postgres";


COMMENT ON TABLE "public"."vehicles" IS 'Vehicle registry for reaction/supervisor fleets including maintenance and assignment data.';



CREATE TABLE IF NOT EXISTS "public"."violations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "guard_id" "uuid" NOT NULL,
    "site_id" "uuid" NOT NULL,
    "patrol_trigger_id" "uuid",
    "post_id" "uuid",
    "violation_type" "text" NOT NULL,
    "detected_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "severity" "public"."violation_severity_enum" NOT NULL,
    "auto_generated" boolean DEFAULT true NOT NULL
);


ALTER TABLE "public"."violations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."watch_archive" (
    "id" "uuid" NOT NULL,
    "geo_lat" double precision NOT NULL,
    "geo_lng" double precision NOT NULL,
    "peak_cluster_size" integer,
    "peak_risk_score" numeric,
    "peak_confidence" numeric,
    "total_lifecycle_minutes" integer,
    "closed_at" timestamp with time zone NOT NULL,
    "archived_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."watch_archive" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."watch_current_state" (
    "id" "uuid" NOT NULL,
    "geo_lat" double precision NOT NULL,
    "geo_lng" double precision NOT NULL,
    "cluster_size" integer NOT NULL,
    "risk_score" numeric,
    "confidence" numeric,
    "last_event_type" "text" NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "peak_cluster_size" integer,
    "peak_risk_score" numeric,
    "peak_confidence" numeric
);


ALTER TABLE "public"."watch_current_state" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."watch_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "center_lat" double precision NOT NULL,
    "center_lng" double precision NOT NULL,
    "cluster_size" integer NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."watch_events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."zara_action_log" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "text" DEFAULT COALESCE(NULLIF(("auth"."jwt"() ->> 'org_id'::"text"), ''::"text"), 'global'::"text") NOT NULL,
    "scenario_id" "text" NOT NULL,
    "action_kind" "text" NOT NULL,
    "proposed_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "outcome" "text" NOT NULL,
    "executed_at" timestamp with time zone,
    "payload_jsonb" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "result_jsonb" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL
);


ALTER TABLE "public"."zara_action_log" OWNER TO "postgres";


COMMENT ON TABLE "public"."zara_action_log" IS 'Append-only forensic trail of Zara Theatre action proposals and outcomes.';



CREATE TABLE IF NOT EXISTS "public"."zara_scenarios" (
    "id" "text" NOT NULL,
    "org_id" "text" DEFAULT COALESCE(NULLIF(("auth"."jwt"() ->> 'org_id'::"text"), ''::"text"), 'global'::"text") NOT NULL,
    "kind" "text" NOT NULL,
    "summary" "text" NOT NULL,
    "origin_event_ids" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "lifecycle_state" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "resolved_at" timestamp with time zone,
    "controller_user_id" "uuid" DEFAULT "auth"."uid"()
);


ALTER TABLE "public"."zara_scenarios" OWNER TO "postgres";


COMMENT ON TABLE "public"."zara_scenarios" IS 'Auditable Zara Theatre scenarios persisted across controller sessions.';



COMMENT ON COLUMN "public"."zara_scenarios"."origin_event_ids" IS 'Dispatch-event ids that caused Zara to surface the scenario.';



ALTER TABLE ONLY "public"."logs" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."logs_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."roles" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."roles_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."ThreatCategories"
    ADD CONSTRAINT "ThreatCategories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ThreatLevels"
    ADD CONSTRAINT "ThreatLevels_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ThreatMatrix"
    ADD CONSTRAINT "ThreatMatrix_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."abort_logs"
    ADD CONSTRAINT "abort_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."actions_log"
    ADD CONSTRAINT "actions_log_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."alarm_accounts"
    ADD CONSTRAINT "alarm_accounts_pkey" PRIMARY KEY ("account_number");



ALTER TABLE ONLY "public"."alert_events"
    ADD CONSTRAINT "alert_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."alert_rules"
    ADD CONSTRAINT "alert_rules_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."area_sites"
    ADD CONSTRAINT "area_sites_pkey" PRIMARY KEY ("area_key", "site_id");



ALTER TABLE ONLY "public"."checkins"
    ADD CONSTRAINT "checkins_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."civic_events"
    ADD CONSTRAINT "civic_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."client_contact_endpoint_subscriptions"
    ADD CONSTRAINT "client_contact_endpoint_subscriptions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."client_contact_endpoint_subscriptions"
    ADD CONSTRAINT "client_contact_endpoint_subscriptions_unique" UNIQUE ("contact_id", "endpoint_id");



ALTER TABLE ONLY "public"."client_contacts"
    ADD CONSTRAINT "client_contacts_client_id_id_unique" UNIQUE ("client_id", "id");



ALTER TABLE ONLY "public"."client_contacts"
    ADD CONSTRAINT "client_contacts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."client_conversation_acknowledgements"
    ADD CONSTRAINT "client_conversation_acknowledgements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."client_conversation_acknowledgements"
    ADD CONSTRAINT "client_conversation_acknowledgements_unique_key" UNIQUE ("client_id", "site_id", "message_key", "channel");



ALTER TABLE ONLY "public"."client_conversation_messages"
    ADD CONSTRAINT "client_conversation_messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."client_conversation_push_queue"
    ADD CONSTRAINT "client_conversation_push_queue_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."client_conversation_push_sync_state"
    ADD CONSTRAINT "client_conversation_push_sync_state_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."client_conversation_push_sync_state"
    ADD CONSTRAINT "client_conversation_push_sync_state_unique" UNIQUE ("client_id", "site_id");



ALTER TABLE ONLY "public"."client_evidence_ledger"
    ADD CONSTRAINT "client_evidence_ledger_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."client_messaging_endpoints"
    ADD CONSTRAINT "client_messaging_endpoints_client_id_id_unique" UNIQUE ("client_id", "id");



ALTER TABLE ONLY "public"."client_messaging_endpoints"
    ADD CONSTRAINT "client_messaging_endpoints_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."clients"
    ADD CONSTRAINT "clients_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."command_events"
    ADD CONSTRAINT "command_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."command_summaries"
    ADD CONSTRAINT "command_summaries_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."controllers"
    ADD CONSTRAINT "controllers_client_controller_unique" UNIQUE ("client_id", "controller_id");



ALTER TABLE ONLY "public"."controllers"
    ADD CONSTRAINT "controllers_pkey" PRIMARY KEY ("controller_id");



ALTER TABLE ONLY "public"."decision_audit_log"
    ADD CONSTRAINT "decision_audit_log_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."decision_traces"
    ADD CONSTRAINT "decision_traces_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."demo_state"
    ADD CONSTRAINT "demo_state_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."deployments"
    ADD CONSTRAINT "deployments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."dispatch_actions"
    ADD CONSTRAINT "dispatch_actions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."dispatch_intents"
    ADD CONSTRAINT "dispatch_intents_pkey" PRIMARY KEY ("dispatch_id");



ALTER TABLE ONLY "public"."dispatch_transitions"
    ADD CONSTRAINT "dispatch_transitions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."duty_states"
    ADD CONSTRAINT "duty_states_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."employee_site_assignments"
    ADD CONSTRAINT "employee_site_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."employee_site_assignments"
    ADD CONSTRAINT "employee_site_assignments_unique" UNIQUE ("employee_id", "site_id");



ALTER TABLE ONLY "public"."employees"
    ADD CONSTRAINT "employees_client_employee_code_unique" UNIQUE ("client_id", "employee_code");



ALTER TABLE ONLY "public"."employees"
    ADD CONSTRAINT "employees_client_id_id_unique" UNIQUE ("client_id", "id");



ALTER TABLE ONLY "public"."employees"
    ADD CONSTRAINT "employees_client_id_number_unique" UNIQUE ("client_id", "id_number");



ALTER TABLE ONLY "public"."employees"
    ADD CONSTRAINT "employees_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."escalation_events"
    ADD CONSTRAINT "escalation_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."evidence_bundles"
    ADD CONSTRAINT "evidence_bundles_pkey" PRIMARY KEY ("bundle_id");



ALTER TABLE ONLY "public"."execution_locks"
    ADD CONSTRAINT "execution_locks_pkey" PRIMARY KEY ("dispatch_id");



ALTER TABLE ONLY "public"."external_signals"
    ADD CONSTRAINT "external_signals_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."fr_person_registry"
    ADD CONSTRAINT "fr_person_registry_person_id_key" UNIQUE ("person_id");



ALTER TABLE ONLY "public"."fr_person_registry"
    ADD CONSTRAINT "fr_person_registry_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."global_clusters"
    ADD CONSTRAINT "global_clusters_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."global_events"
    ADD CONSTRAINT "global_events_pkey" PRIMARY KEY ("source_id");



ALTER TABLE ONLY "public"."global_patterns"
    ADD CONSTRAINT "global_patterns_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."guard_assignments"
    ADD CONSTRAINT "guard_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."guard_assignments"
    ADD CONSTRAINT "guard_assignments_unique_assignment" UNIQUE ("client_id", "site_id", "guard_id", "assignment_id");



ALTER TABLE ONLY "public"."guard_checkpoint_scans"
    ADD CONSTRAINT "guard_checkpoint_scans_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."guard_checkpoint_scans"
    ADD CONSTRAINT "guard_checkpoint_scans_unique_scan" UNIQUE ("client_id", "site_id", "guard_id", "scan_id");



ALTER TABLE ONLY "public"."guard_documents"
    ADD CONSTRAINT "guard_documents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."guard_incident_captures"
    ADD CONSTRAINT "guard_incident_captures_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."guard_incident_captures"
    ADD CONSTRAINT "guard_incident_captures_unique_capture" UNIQUE ("client_id", "site_id", "guard_id", "capture_id");



ALTER TABLE ONLY "public"."guard_location_heartbeats"
    ADD CONSTRAINT "guard_location_heartbeats_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."guard_location_heartbeats"
    ADD CONSTRAINT "guard_location_heartbeats_unique_id" UNIQUE ("client_id", "site_id", "guard_id", "heartbeat_id");



ALTER TABLE ONLY "public"."guard_logs"
    ADD CONSTRAINT "guard_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."guard_ops_events"
    ADD CONSTRAINT "guard_ops_events_event_id_unique" UNIQUE ("event_id");



ALTER TABLE ONLY "public"."guard_ops_events"
    ADD CONSTRAINT "guard_ops_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."guard_ops_events"
    ADD CONSTRAINT "guard_ops_events_shift_sequence_unique" UNIQUE ("shift_id", "sequence");



ALTER TABLE ONLY "public"."guard_ops_media"
    ADD CONSTRAINT "guard_ops_media_event_path_unique" UNIQUE ("event_id", "path");



ALTER TABLE ONLY "public"."guard_ops_media"
    ADD CONSTRAINT "guard_ops_media_media_id_unique" UNIQUE ("media_id");



ALTER TABLE ONLY "public"."guard_ops_media"
    ADD CONSTRAINT "guard_ops_media_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."guard_ops_replay_safety_checks"
    ADD CONSTRAINT "guard_ops_replay_safety_checks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."guard_ops_retention_runs"
    ADD CONSTRAINT "guard_ops_retention_runs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."guard_panic_signals"
    ADD CONSTRAINT "guard_panic_signals_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."guard_panic_signals"
    ADD CONSTRAINT "guard_panic_signals_unique_signal" UNIQUE ("client_id", "site_id", "guard_id", "signal_id");



ALTER TABLE ONLY "public"."guard_profiles"
    ADD CONSTRAINT "guard_profiles_guard_id_key" UNIQUE ("guard_id");



ALTER TABLE ONLY "public"."guard_profiles"
    ADD CONSTRAINT "guard_profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."guard_projection_retention_runs"
    ADD CONSTRAINT "guard_projection_retention_runs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."guard_sites"
    ADD CONSTRAINT "guard_sites_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."guard_sync_operations"
    ADD CONSTRAINT "guard_sync_operations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."guard_sync_operations"
    ADD CONSTRAINT "guard_sync_operations_unique_op" UNIQUE ("client_id", "site_id", "guard_id", "operation_id");



ALTER TABLE ONLY "public"."guards"
    ADD CONSTRAINT "guards_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."hourly_throughput"
    ADD CONSTRAINT "hourly_throughput_client_id_site_id_visit_date_hour_of_day_key" UNIQUE ("client_id", "site_id", "visit_date", "hour_of_day");



ALTER TABLE ONLY "public"."hourly_throughput"
    ADD CONSTRAINT "hourly_throughput_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."incident_aar_scores"
    ADD CONSTRAINT "incident_aar_scores_incident_id_key" UNIQUE ("incident_id");



ALTER TABLE ONLY "public"."incident_aar_scores"
    ADD CONSTRAINT "incident_aar_scores_incident_id_unique" UNIQUE ("incident_id");



ALTER TABLE ONLY "public"."incident_aar_scores"
    ADD CONSTRAINT "incident_aar_scores_incident_unique" UNIQUE ("incident_id");



ALTER TABLE ONLY "public"."incident_aar_scores"
    ADD CONSTRAINT "incident_aar_scores_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."incident_actions"
    ADD CONSTRAINT "incident_actions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."incident_intelligence"
    ADD CONSTRAINT "incident_intelligence_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."incident_outcomes"
    ADD CONSTRAINT "incident_outcomes_pkey" PRIMARY KEY ("incident_id");



ALTER TABLE ONLY "public"."incident_replay_events"
    ADD CONSTRAINT "incident_replay_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."incident_replays"
    ADD CONSTRAINT "incident_replays_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."incident_snapshots"
    ADD CONSTRAINT "incident_snapshots_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."incidents"
    ADD CONSTRAINT "incidents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."intel_events"
    ADD CONSTRAINT "intel_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."intel_patrol_links"
    ADD CONSTRAINT "intel_patrol_links_pkey" PRIMARY KEY ("intel_threat_id", "patrol_id");



ALTER TABLE ONLY "public"."intel_source_weights"
    ADD CONSTRAINT "intel_source_weights_pkey" PRIMARY KEY ("source_type");



ALTER TABLE ONLY "public"."intelligence_snapshots"
    ADD CONSTRAINT "intelligence_snapshots_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."keyword_escalations"
    ADD CONSTRAINT "keyword_escalations_pkey" PRIMARY KEY ("keyword");



ALTER TABLE ONLY "public"."logs"
    ADD CONSTRAINT "logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."mo_library"
    ADD CONSTRAINT "mo_library_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."omnix_logs"
    ADD CONSTRAINT "omnix_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."onyx_alert_outcomes"
    ADD CONSTRAINT "onyx_alert_outcomes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."onyx_awareness_latency"
    ADD CONSTRAINT "onyx_awareness_latency_pkey" PRIMARY KEY ("alert_id");



ALTER TABLE ONLY "public"."onyx_client_trust_snapshots"
    ADD CONSTRAINT "onyx_client_trust_snapshots_pkey" PRIMARY KEY ("client_id", "site_id", "period_start", "period_end");



ALTER TABLE ONLY "public"."onyx_event_store"
    ADD CONSTRAINT "onyx_event_store_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."onyx_evidence_certificates"
    ADD CONSTRAINT "onyx_evidence_certificates_pkey" PRIMARY KEY ("certificate_id");



ALTER TABLE ONLY "public"."onyx_operator_scores"
    ADD CONSTRAINT "onyx_operator_scores_pkey" PRIMARY KEY ("operator_id", "site_id", "period");



ALTER TABLE ONLY "public"."onyx_operator_simulations"
    ADD CONSTRAINT "onyx_operator_simulations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."onyx_settings"
    ADD CONSTRAINT "onyx_settings_pkey" PRIMARY KEY ("key");



ALTER TABLE ONLY "public"."operational_nodes"
    ADD CONSTRAINT "operational_nodes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ops_orders"
    ADD CONSTRAINT "ops_orders_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."patrol_checkpoint_scans"
    ADD CONSTRAINT "patrol_checkpoint_scans_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."patrol_checkpoints"
    ADD CONSTRAINT "patrol_checkpoints_checkpoint_code_key" UNIQUE ("checkpoint_code");



ALTER TABLE ONLY "public"."patrol_checkpoints"
    ADD CONSTRAINT "patrol_checkpoints_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."patrol_compliance"
    ADD CONSTRAINT "patrol_compliance_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."patrol_compliance"
    ADD CONSTRAINT "patrol_compliance_site_id_guard_id_compliance_date_key" UNIQUE ("site_id", "guard_id", "compliance_date");



ALTER TABLE ONLY "public"."patrol_route_cooldowns"
    ADD CONSTRAINT "patrol_route_cooldowns_pkey" PRIMARY KEY ("patrol_id");



ALTER TABLE ONLY "public"."patrol_route_recommendations"
    ADD CONSTRAINT "patrol_route_recommendations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."patrol_routes"
    ADD CONSTRAINT "patrol_routes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."patrol_scans"
    ADD CONSTRAINT "patrol_scans_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."patrol_triggers"
    ADD CONSTRAINT "patrol_triggers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."patrol_violations"
    ADD CONSTRAINT "patrol_violations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."patrols"
    ADD CONSTRAINT "patrols_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."posts"
    ADD CONSTRAINT "posts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."regional_risk_snapshots"
    ADD CONSTRAINT "regional_risk_snapshots_pkey" PRIMARY KEY ("region_code");



ALTER TABLE ONLY "public"."roles"
    ADD CONSTRAINT "roles_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."roles"
    ADD CONSTRAINT "roles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."site_alarm_events"
    ADD CONSTRAINT "site_alarm_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."site_alert_config"
    ADD CONSTRAINT "site_alert_config_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."site_alert_config"
    ADD CONSTRAINT "site_alert_config_site_id_key" UNIQUE ("site_id");



ALTER TABLE ONLY "public"."site_api_tokens"
    ADD CONSTRAINT "site_api_tokens_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."site_api_tokens"
    ADD CONSTRAINT "site_api_tokens_token_key" UNIQUE ("token");



ALTER TABLE ONLY "public"."site_awareness_snapshots"
    ADD CONSTRAINT "site_awareness_snapshots_pkey" PRIMARY KEY ("site_id");



ALTER TABLE ONLY "public"."site_camera_zones"
    ADD CONSTRAINT "site_camera_zones_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."site_camera_zones"
    ADD CONSTRAINT "site_camera_zones_site_id_channel_id_key" UNIQUE ("site_id", "channel_id");



ALTER TABLE ONLY "public"."site_expected_visitors"
    ADD CONSTRAINT "site_expected_visitors_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."site_identity_approval_decisions"
    ADD CONSTRAINT "site_identity_approval_decisions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."site_identity_profiles"
    ADD CONSTRAINT "site_identity_profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."site_intelligence_profiles"
    ADD CONSTRAINT "site_intelligence_profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."site_intelligence_profiles"
    ADD CONSTRAINT "site_intelligence_profiles_site_id_key" UNIQUE ("site_id");



ALTER TABLE ONLY "public"."site_occupancy_config"
    ADD CONSTRAINT "site_occupancy_config_pkey" PRIMARY KEY ("site_id");



ALTER TABLE ONLY "public"."site_occupancy_sessions"
    ADD CONSTRAINT "site_occupancy_sessions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."site_occupancy_sessions"
    ADD CONSTRAINT "site_occupancy_sessions_site_id_session_date_key" UNIQUE ("site_id", "session_date");



ALTER TABLE ONLY "public"."site_vehicle_registry"
    ADD CONSTRAINT "site_vehicle_registry_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."site_vehicle_registry"
    ADD CONSTRAINT "site_vehicle_registry_site_id_plate_number_key" UNIQUE ("site_id", "plate_number");



ALTER TABLE ONLY "public"."site_zone_rules"
    ADD CONSTRAINT "site_zone_rules_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."site_zones"
    ADD CONSTRAINT "site_zones_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."site_zones"
    ADD CONSTRAINT "site_zones_site_id_code_key" UNIQUE ("site_id", "code");



ALTER TABLE ONLY "public"."sites"
    ADD CONSTRAINT "sites_code_key" UNIQUE ("code");



ALTER TABLE ONLY "public"."sites"
    ADD CONSTRAINT "sites_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."staff"
    ADD CONSTRAINT "staff_client_staff_unique" UNIQUE ("client_id", "staff_id");



ALTER TABLE ONLY "public"."staff"
    ADD CONSTRAINT "staff_pkey" PRIMARY KEY ("staff_id");



ALTER TABLE ONLY "public"."telegram_identity_intake"
    ADD CONSTRAINT "telegram_identity_intake_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."telegram_inbound_updates"
    ADD CONSTRAINT "telegram_inbound_updates_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."telegram_inbound_updates"
    ADD CONSTRAINT "telegram_inbound_updates_update_id_key" UNIQUE ("update_id");



ALTER TABLE ONLY "public"."threat_decay_profiles"
    ADD CONSTRAINT "threat_decay_profiles_pkey" PRIMARY KEY ("threat_type");



ALTER TABLE ONLY "public"."threat_scores"
    ADD CONSTRAINT "threat_scores_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."threats"
    ADD CONSTRAINT "threats_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."vehicle_logs"
    ADD CONSTRAINT "vehicle_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."vehicle_visits"
    ADD CONSTRAINT "vehicle_visits_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."vehicles"
    ADD CONSTRAINT "vehicles_client_callsign_unique" UNIQUE ("client_id", "vehicle_callsign");



ALTER TABLE ONLY "public"."vehicles"
    ADD CONSTRAINT "vehicles_client_license_unique" UNIQUE ("client_id", "license_plate");



ALTER TABLE ONLY "public"."vehicles"
    ADD CONSTRAINT "vehicles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."violations"
    ADD CONSTRAINT "violations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."watch_archive"
    ADD CONSTRAINT "watch_archive_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."watch_current_state"
    ADD CONSTRAINT "watch_current_state_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."watch_events"
    ADD CONSTRAINT "watch_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."zara_action_log"
    ADD CONSTRAINT "zara_action_log_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."zara_scenarios"
    ADD CONSTRAINT "zara_scenarios_pkey" PRIMARY KEY ("id");



CREATE INDEX "alarm_accounts_client_site_idx" ON "public"."alarm_accounts" USING "btree" ("client_id", "site_id");



CREATE INDEX "client_contact_endpoint_subscriptions_contact_idx" ON "public"."client_contact_endpoint_subscriptions" USING "btree" ("contact_id", "is_active");



CREATE INDEX "client_contact_endpoint_subscriptions_endpoint_idx" ON "public"."client_contact_endpoint_subscriptions" USING "btree" ("endpoint_id", "is_active");



CREATE INDEX "client_contact_endpoint_subscriptions_scope_idx" ON "public"."client_contact_endpoint_subscriptions" USING "btree" ("client_id", "site_id", "is_active");



CREATE INDEX "client_contacts_client_scope_idx" ON "public"."client_contacts" USING "btree" ("client_id", "site_id", "is_active");



CREATE INDEX "client_conversation_ack_acknowledged_at_idx" ON "public"."client_conversation_acknowledgements" USING "btree" ("client_id", "site_id", "acknowledged_at" DESC);



CREATE INDEX "client_conversation_ack_client_site_idx" ON "public"."client_conversation_acknowledgements" USING "btree" ("client_id", "site_id");



CREATE INDEX "client_conversation_acknowledgements_client_site_ack_idx" ON "public"."client_conversation_acknowledgements" USING "btree" ("client_id", "site_id", "acknowledged_at" DESC);



CREATE INDEX "client_conversation_acknowledgements_client_site_idx" ON "public"."client_conversation_acknowledgements" USING "btree" ("client_id", "site_id");



CREATE INDEX "client_conversation_messages_client_site_idx" ON "public"."client_conversation_messages" USING "btree" ("client_id", "site_id");



CREATE INDEX "client_conversation_messages_client_site_occurred_idx" ON "public"."client_conversation_messages" USING "btree" ("client_id", "site_id", "occurred_at" DESC);



CREATE INDEX "client_conversation_messages_occurred_at_idx" ON "public"."client_conversation_messages" USING "btree" ("client_id", "site_id", "occurred_at" DESC);



CREATE UNIQUE INDEX "client_conversation_push_queue_message_key_idx" ON "public"."client_conversation_push_queue" USING "btree" ("client_id", "site_id", "message_key");



CREATE INDEX "client_conversation_push_queue_occurred_idx" ON "public"."client_conversation_push_queue" USING "btree" ("client_id", "site_id", "occurred_at" DESC);



CREATE INDEX "client_conversation_push_sync_state_scope_idx" ON "public"."client_conversation_push_sync_state" USING "btree" ("client_id", "site_id");



CREATE INDEX "client_messaging_endpoints_scope_idx" ON "public"."client_messaging_endpoints" USING "btree" ("client_id", "site_id", "provider", "is_active");



CREATE INDEX "client_messaging_endpoints_telegram_chat_idx" ON "public"."client_messaging_endpoints" USING "btree" ("client_id", "telegram_chat_id") WHERE ("provider" = 'telegram'::"text");



CREATE UNIQUE INDEX "clients_client_id_compat_unique_idx" ON "public"."clients" USING "btree" ("client_id");



CREATE UNIQUE INDEX "clients_vat_number_unique_idx" ON "public"."clients" USING "btree" ("vat_number") WHERE (("vat_number" IS NOT NULL) AND ("length"("btrim"("vat_number")) > 0));



CREATE INDEX "controllers_client_active_idx" ON "public"."controllers" USING "btree" ("client_id", "is_active", "full_name");



CREATE UNIQUE INDEX "controllers_client_auth_user_unique_idx" ON "public"."controllers" USING "btree" ("client_id", "auth_user_id") WHERE ("auth_user_id" IS NOT NULL);



CREATE UNIQUE INDEX "controllers_client_employee_code_unique_idx" ON "public"."controllers" USING "btree" ("client_id", "employee_code") WHERE (("employee_code" IS NOT NULL) AND ("length"("btrim"("employee_code")) > 0));



CREATE UNIQUE INDEX "controllers_source_employee_unique_idx" ON "public"."controllers" USING "btree" ("source_employee_id");



CREATE INDEX "employee_site_assignments_client_site_status_idx" ON "public"."employee_site_assignments" USING "btree" ("client_id", "site_id", "assignment_status");



CREATE UNIQUE INDEX "employee_site_assignments_primary_unique_idx" ON "public"."employee_site_assignments" USING "btree" ("employee_id") WHERE (("is_primary" = true) AND ("assignment_status" = 'active'::"text"));



CREATE UNIQUE INDEX "employees_client_auth_user_unique_idx" ON "public"."employees" USING "btree" ("client_id", "auth_user_id") WHERE ("auth_user_id" IS NOT NULL);



CREATE UNIQUE INDEX "employees_client_device_uid_unique_idx" ON "public"."employees" USING "btree" ("client_id", "device_uid") WHERE (("device_uid" IS NOT NULL) AND ("length"("btrim"("device_uid")) > 0));



CREATE INDEX "employees_client_psira_expiry_idx" ON "public"."employees" USING "btree" ("client_id", "psira_expiry") WHERE ("psira_expiry" IS NOT NULL);



CREATE UNIQUE INDEX "employees_client_psira_unique_idx" ON "public"."employees" USING "btree" ("client_id", "psira_number") WHERE (("psira_number" IS NOT NULL) AND ("length"("btrim"("psira_number")) > 0));



CREATE INDEX "employees_client_role_status_idx" ON "public"."employees" USING "btree" ("client_id", "primary_role", "employment_status");



CREATE INDEX "guard_assignments_client_site_guard_idx" ON "public"."guard_assignments" USING "btree" ("client_id", "site_id", "guard_id", "issued_at" DESC);



CREATE INDEX "guard_assignments_dispatch_idx" ON "public"."guard_assignments" USING "btree" ("dispatch_id");



CREATE INDEX "guard_checkpoint_scans_client_site_guard_idx" ON "public"."guard_checkpoint_scans" USING "btree" ("client_id", "site_id", "guard_id", "scanned_at" DESC);



CREATE INDEX "guard_incident_captures_client_site_guard_idx" ON "public"."guard_incident_captures" USING "btree" ("client_id", "site_id", "guard_id", "captured_at" DESC);



CREATE INDEX "guard_incident_captures_dispatch_idx" ON "public"."guard_incident_captures" USING "btree" ("dispatch_id");



CREATE INDEX "guard_location_heartbeats_client_site_guard_idx" ON "public"."guard_location_heartbeats" USING "btree" ("client_id", "site_id", "guard_id", "recorded_at" DESC);



CREATE INDEX "guard_ops_events_guard_occurred_idx" ON "public"."guard_ops_events" USING "btree" ("guard_id", "occurred_at" DESC);



CREATE INDEX "guard_ops_events_shift_sequence_idx" ON "public"."guard_ops_events" USING "btree" ("shift_id", "sequence");



CREATE INDEX "guard_ops_events_site_occurred_idx" ON "public"."guard_ops_events" USING "btree" ("site_id", "occurred_at" DESC);



CREATE INDEX "guard_ops_media_guard_captured_idx" ON "public"."guard_ops_media" USING "btree" ("guard_id", "captured_at" DESC);



CREATE INDEX "guard_ops_media_shift_captured_idx" ON "public"."guard_ops_media" USING "btree" ("shift_id", "captured_at" DESC);



CREATE INDEX "guard_ops_media_site_captured_idx" ON "public"."guard_ops_media" USING "btree" ("site_id", "captured_at" DESC);



CREATE INDEX "guard_ops_media_status_idx" ON "public"."guard_ops_media" USING "btree" ("upload_status", "created_at" DESC);



CREATE INDEX "guard_ops_media_visual_norm_mode_idx" ON "public"."guard_ops_media" USING "btree" ("visual_norm_mode", "captured_at" DESC);



CREATE INDEX "guard_panic_signals_client_site_guard_idx" ON "public"."guard_panic_signals" USING "btree" ("client_id", "site_id", "guard_id", "triggered_at" DESC);



CREATE INDEX "guard_sync_operations_client_site_guard_facade_idx" ON "public"."guard_sync_operations" USING "btree" ("client_id", "site_id", "guard_id", "facade_mode", "occurred_at" DESC);



CREATE INDEX "guard_sync_operations_client_site_guard_idx" ON "public"."guard_sync_operations" USING "btree" ("client_id", "site_id", "guard_id", "occurred_at" DESC);



CREATE INDEX "guard_sync_operations_facade_mode_idx" ON "public"."guard_sync_operations" USING "btree" ("facade_mode", "occurred_at" DESC);



CREATE INDEX "guard_sync_operations_status_idx" ON "public"."guard_sync_operations" USING "btree" ("operation_status", "occurred_at" DESC);



CREATE INDEX "guards_client_active_idx" ON "public"."guards" USING "btree" ("client_id", "is_active", "full_name");



CREATE UNIQUE INDEX "guards_client_auth_user_unique_idx" ON "public"."guards" USING "btree" ("client_id", "auth_user_id") WHERE ("auth_user_id" IS NOT NULL);



CREATE UNIQUE INDEX "guards_client_badge_number_unique_idx" ON "public"."guards" USING "btree" ("client_id", "badge_number") WHERE (("badge_number" IS NOT NULL) AND ("length"("btrim"("badge_number")) > 0));



CREATE INDEX "guards_client_site_active_idx" ON "public"."guards" USING "btree" ("client_id", "primary_site_id", "is_active");



CREATE UNIQUE INDEX "guards_source_employee_unique_idx" ON "public"."guards" USING "btree" ("source_employee_id");



CREATE INDEX "hourly_throughput_scope_date" ON "public"."hourly_throughput" USING "btree" ("client_id", "site_id", "visit_date" DESC, "hour_of_day");



CREATE INDEX "idx_abort_logs_created_at" ON "public"."abort_logs" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_alert_outcomes_alert_id" ON "public"."onyx_alert_outcomes" USING "btree" ("alert_id");



CREATE INDEX "idx_alert_outcomes_site_id" ON "public"."onyx_alert_outcomes" USING "btree" ("site_id");



CREATE INDEX "idx_awareness_latency_client" ON "public"."onyx_awareness_latency" USING "btree" ("client_id", "telegram_at" DESC);



CREATE INDEX "idx_awareness_latency_site" ON "public"."onyx_awareness_latency" USING "btree" ("site_id", "telegram_at" DESC);



CREATE INDEX "idx_client_chain" ON "public"."client_evidence_ledger" USING "btree" ("client_id", "created_at");



CREATE UNIQUE INDEX "idx_client_dispatch_unique" ON "public"."client_evidence_ledger" USING "btree" ("dispatch_id");



CREATE INDEX "idx_client_ledger_client_created" ON "public"."client_evidence_ledger" USING "btree" ("client_id", "created_at");



CREATE INDEX "idx_deployments_active" ON "public"."deployments" USING "btree" ("shift_end");



CREATE INDEX "idx_deployments_guard" ON "public"."deployments" USING "btree" ("guard_id");



CREATE INDEX "idx_deployments_site" ON "public"."deployments" USING "btree" ("site_id");



CREATE UNIQUE INDEX "idx_dispatch_unique" ON "public"."client_evidence_ledger" USING "btree" ("dispatch_id");



CREATE INDEX "idx_guard_documents_guard" ON "public"."guard_documents" USING "btree" ("guard_id");



CREATE INDEX "idx_guard_documents_type" ON "public"."guard_documents" USING "btree" ("type");



CREATE INDEX "idx_guards_active" ON "public"."guards" USING "btree" ("active");



CREATE INDEX "idx_guards_site" ON "public"."guards" USING "btree" ("site");



CREATE INDEX "idx_incident_actions_incident_id" ON "public"."incident_actions" USING "btree" ("incident_id", "created_at" DESC);



CREATE INDEX "idx_incidents_created_at" ON "public"."incidents" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_incidents_risk_level" ON "public"."incidents" USING "btree" ("risk_level");



CREATE INDEX "idx_incidents_scope" ON "public"."incidents" USING "btree" ("scope");



CREATE INDEX "idx_incidents_scope_site" ON "public"."incidents" USING "btree" ("scope", "site_id");



CREATE INDEX "idx_incidents_site" ON "public"."incidents" USING "btree" ("site_id");



CREATE INDEX "idx_incidents_site_created_at" ON "public"."incidents" USING "btree" ("site_id", "created_at" DESC);



CREATE INDEX "idx_incidents_site_id" ON "public"."incidents" USING "btree" ("site_id");



CREATE INDEX "idx_incidents_status" ON "public"."incidents" USING "btree" ("status");



CREATE INDEX "idx_incidents_zone_id" ON "public"."incidents" USING "btree" ("zone_id");



CREATE INDEX "idx_incidents_zone_time" ON "public"."incidents" USING "btree" ("zone_id", "created_at" DESC);



CREATE INDEX "idx_intel_events_entity" ON "public"."intel_events" USING "btree" ("entity_type", "entity_id");



CREATE INDEX "idx_intel_events_ingested_at" ON "public"."intel_events" USING "btree" ("ingested_at" DESC);



CREATE INDEX "idx_intel_events_processed" ON "public"."intel_events" USING "btree" ("processed");



CREATE INDEX "idx_intel_events_source" ON "public"."intel_events" USING "btree" ("source_type", "source_name");



CREATE INDEX "idx_intel_snapshots_incident" ON "public"."intelligence_snapshots" USING "btree" ("incident_id");



CREATE INDEX "idx_intel_snapshots_site" ON "public"."intelligence_snapshots" USING "btree" ("site_id");



CREATE INDEX "idx_intel_snapshots_time" ON "public"."intelligence_snapshots" USING "btree" ("created_at");



CREATE INDEX "idx_telegram_inbound_chat" ON "public"."telegram_inbound_updates" USING "btree" ("chat_id", "received_at" DESC);



CREATE INDEX "idx_telegram_inbound_unprocessed" ON "public"."telegram_inbound_updates" USING "btree" ("received_at") WHERE ("processed" = false);



CREATE INDEX "idx_threats_created_at_desc" ON "public"."threats" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_threats_dcw_seconds" ON "public"."threats" USING "btree" ("dcw_seconds");



CREATE INDEX "idx_threats_risk_level" ON "public"."threats" USING "btree" ("risk_level");



CREATE INDEX "idx_vehicle_logs_plate" ON "public"."vehicle_logs" USING "btree" ("lower"("plate"));



CREATE INDEX "incidents_client_site_status_idx" ON "public"."incidents" USING "btree" ("client_id", "site_id", "status", "signal_received_at" DESC);



CREATE UNIQUE INDEX "incidents_event_uid_unique_idx" ON "public"."incidents" USING "btree" ("event_uid");



CREATE INDEX "incidents_priority_status_idx" ON "public"."incidents" USING "btree" ("priority", "status", "signal_received_at" DESC);



CREATE INDEX "incidents_signal_received_idx" ON "public"."incidents" USING "btree" ("signal_received_at" DESC);



CREATE INDEX "logs_created_at_idx" ON "public"."logs" USING "btree" ("created_at" DESC);



CREATE INDEX "logs_log_type_idx" ON "public"."logs" USING "btree" ("log_type");



CREATE INDEX "logs_site_created_idx" ON "public"."logs" USING "btree" ("site_code", "created_at" DESC);



CREATE INDEX "logs_type_created_idx" ON "public"."logs" USING "btree" ("log_type", "created_at" DESC);



CREATE UNIQUE INDEX "one_active_state_per_guard" ON "public"."duty_states" USING "btree" ("guard_id") WHERE ("exited_at" IS NULL);



CREATE UNIQUE INDEX "onyx_alert_outcomes_alert_id_uidx" ON "public"."onyx_alert_outcomes" USING "btree" ("alert_id");



CREATE INDEX "onyx_alert_outcomes_client_occurred_idx" ON "public"."onyx_alert_outcomes" USING "btree" ("client_id", "occurred_at" DESC);



CREATE INDEX "onyx_alert_outcomes_site_occurred_idx" ON "public"."onyx_alert_outcomes" USING "btree" ("site_id", "occurred_at" DESC);



CREATE INDEX "onyx_alert_outcomes_zone_occurred_idx" ON "public"."onyx_alert_outcomes" USING "btree" ("site_id", "zone_id", "occurred_at" DESC);



CREATE INDEX "onyx_client_trust_snapshots_client_site_snapshot_idx" ON "public"."onyx_client_trust_snapshots" USING "btree" ("client_id", "site_id", "snapshot_at" DESC);



CREATE UNIQUE INDEX "onyx_client_trust_snapshots_conflict_uidx" ON "public"."onyx_client_trust_snapshots" USING "btree" ("client_id", "site_id", "period_start", "period_end");



CREATE INDEX "onyx_event_store_client_occurred_at_idx" ON "public"."onyx_event_store" USING "btree" ("client_id", "occurred_at" DESC);



CREATE INDEX "onyx_event_store_site_occurred_at_idx" ON "public"."onyx_event_store" USING "btree" ("site_id", "occurred_at" DESC);



CREATE UNIQUE INDEX "onyx_event_store_site_sequence_idx" ON "public"."onyx_event_store" USING "btree" ("site_id", "sequence");



CREATE UNIQUE INDEX "onyx_evidence_certificates_certificate_id_uidx" ON "public"."onyx_evidence_certificates" USING "btree" ("certificate_id");



CREATE INDEX "onyx_evidence_certificates_client_detected_idx" ON "public"."onyx_evidence_certificates" USING "btree" ("client_id", "detected_at" DESC);



CREATE INDEX "onyx_evidence_certificates_event_idx" ON "public"."onyx_evidence_certificates" USING "btree" ("event_id");



CREATE UNIQUE INDEX "onyx_evidence_certificates_site_chain_idx" ON "public"."onyx_evidence_certificates" USING "btree" ("site_id", "chain_position");



CREATE INDEX "onyx_evidence_certificates_site_detected_idx" ON "public"."onyx_evidence_certificates" USING "btree" ("site_id", "detected_at" DESC);



CREATE UNIQUE INDEX "onyx_operator_scores_conflict_uidx" ON "public"."onyx_operator_scores" USING "btree" ("operator_id", "site_id", "period");



CREATE INDEX "onyx_operator_scores_site_period_idx" ON "public"."onyx_operator_scores" USING "btree" ("site_id", "period", "score" DESC);



CREATE INDEX "onyx_operator_simulations_client_idx" ON "public"."onyx_operator_simulations" USING "btree" ("client_id", "injected_at" DESC);



CREATE UNIQUE INDEX "onyx_operator_simulations_id_uidx" ON "public"."onyx_operator_simulations" USING "btree" ("id");



CREATE INDEX "onyx_operator_simulations_operator_idx" ON "public"."onyx_operator_simulations" USING "btree" ("operator_id", "injected_at" DESC);



CREATE INDEX "onyx_operator_simulations_site_idx" ON "public"."onyx_operator_simulations" USING "btree" ("site_id", "injected_at" DESC);



CREATE INDEX "onyx_power_mode_events_site_occurred_idx" ON "public"."onyx_power_mode_events" USING "btree" ("site_id", "occurred_at" DESC);



CREATE INDEX "patrol_checkpoint_scans_client_site_idx" ON "public"."patrol_checkpoint_scans" USING "btree" ("client_id", "site_id", "scanned_at" DESC);



CREATE UNIQUE INDEX "patrol_checkpoint_scans_id_uidx" ON "public"."patrol_checkpoint_scans" USING "btree" ("id");



CREATE INDEX "patrol_checkpoint_scans_site_checkpoint_idx" ON "public"."patrol_checkpoint_scans" USING "btree" ("site_id", "checkpoint_id", "scanned_at" DESC);



CREATE INDEX "patrol_checkpoint_scans_site_guard_scanned_idx" ON "public"."patrol_checkpoint_scans" USING "btree" ("site_id", "guard_id", "scanned_at" DESC);



CREATE INDEX "site_alarm_events_device_occurred_idx" ON "public"."site_alarm_events" USING "btree" ("device_id", "occurred_at" DESC);



CREATE INDEX "site_alarm_events_site_occurred_idx" ON "public"."site_alarm_events" USING "btree" ("site_id", "occurred_at" DESC);



CREATE INDEX "site_identity_approval_decisions_intel_idx" ON "public"."site_identity_approval_decisions" USING "btree" ("client_id", "site_id", "intelligence_id") WHERE (("intelligence_id" IS NOT NULL) AND ("length"("btrim"("intelligence_id")) > 0));



CREATE INDEX "site_identity_approval_decisions_scope_idx" ON "public"."site_identity_approval_decisions" USING "btree" ("client_id", "site_id", "decided_at" DESC);



CREATE UNIQUE INDEX "site_identity_profiles_face_unique" ON "public"."site_identity_profiles" USING "btree" ("client_id", "site_id", "identity_type", "face_match_id") WHERE (("face_match_id" IS NOT NULL) AND ("length"("btrim"("face_match_id")) > 0));



CREATE UNIQUE INDEX "site_identity_profiles_plate_unique" ON "public"."site_identity_profiles" USING "btree" ("client_id", "site_id", "identity_type", "plate_number") WHERE (("plate_number" IS NOT NULL) AND ("length"("btrim"("plate_number")) > 0));



CREATE INDEX "site_identity_profiles_scope_status_idx" ON "public"."site_identity_profiles" USING "btree" ("client_id", "site_id", "status", "category", "updated_at" DESC);



CREATE INDEX "sites_client_active_idx" ON "public"."sites" USING "btree" ("client_id", "is_active", "site_name");



CREATE UNIQUE INDEX "sites_client_site_code_unique_idx" ON "public"."sites" USING "btree" ("client_id", "site_code") WHERE (("site_code" IS NOT NULL) AND ("length"("btrim"("site_code")) > 0));



CREATE UNIQUE INDEX "sites_client_site_compat_unique_idx" ON "public"."sites" USING "btree" ("client_id", "site_id");



CREATE UNIQUE INDEX "sites_site_id_global_unique_idx" ON "public"."sites" USING "btree" ("site_id");



CREATE INDEX "staff_client_active_idx" ON "public"."staff" USING "btree" ("client_id", "is_active", "full_name");



CREATE UNIQUE INDEX "staff_client_auth_user_unique_idx" ON "public"."staff" USING "btree" ("client_id", "auth_user_id") WHERE ("auth_user_id" IS NOT NULL);



CREATE UNIQUE INDEX "staff_client_employee_code_unique_idx" ON "public"."staff" USING "btree" ("client_id", "employee_code") WHERE (("employee_code" IS NOT NULL) AND ("length"("btrim"("employee_code")) > 0));



CREATE UNIQUE INDEX "staff_source_employee_unique_idx" ON "public"."staff" USING "btree" ("source_employee_id");



CREATE INDEX "telegram_identity_intake_approval_state_idx" ON "public"."telegram_identity_intake" USING "btree" ("client_id", "site_id", "approval_state", "created_at" DESC);



CREATE INDEX "telegram_identity_intake_scope_idx" ON "public"."telegram_identity_intake" USING "btree" ("client_id", "site_id", "created_at" DESC);



CREATE INDEX "vehicle_visits_scope_exception" ON "public"."vehicle_visits" USING "btree" ("client_id", "site_id", "is_loitering", "is_suspicious_short", "started_at_utc" DESC);



CREATE INDEX "vehicle_visits_scope_plate" ON "public"."vehicle_visits" USING "btree" ("client_id", "site_id", "vehicle_key", "started_at_utc" DESC);



CREATE INDEX "vehicle_visits_scope_started" ON "public"."vehicle_visits" USING "btree" ("client_id", "site_id", "started_at_utc" DESC);



CREATE UNIQUE INDEX "vehicle_visits_upsert_key" ON "public"."vehicle_visits" USING "btree" ("client_id", "site_id", "vehicle_key", "started_at_utc");



CREATE INDEX "vehicles_client_status_idx" ON "public"."vehicles" USING "btree" ("client_id", "is_active", "maintenance_status");



CREATE INDEX "vehicles_service_due_idx" ON "public"."vehicles" USING "btree" ("client_id", "service_due_date") WHERE ("service_due_date" IS NOT NULL);



CREATE INDEX "zara_action_log_org_idx" ON "public"."zara_action_log" USING "btree" ("org_id", "proposed_at" DESC);



CREATE INDEX "zara_action_log_scenario_idx" ON "public"."zara_action_log" USING "btree" ("scenario_id", "proposed_at");



CREATE INDEX "zara_scenarios_lifecycle_idx" ON "public"."zara_scenarios" USING "btree" ("lifecycle_state", "created_at" DESC);



CREATE INDEX "zara_scenarios_org_created_idx" ON "public"."zara_scenarios" USING "btree" ("org_id", "created_at" DESC);



CREATE OR REPLACE TRIGGER "apply_site_risk_defaults_before_write" BEFORE INSERT OR UPDATE ON "public"."sites" FOR EACH ROW EXECUTE FUNCTION "public"."apply_site_risk_defaults"();



CREATE OR REPLACE TRIGGER "auto_decided_transition" AFTER INSERT ON "public"."dispatch_intents" FOR EACH ROW EXECUTE FUNCTION "public"."create_initial_transition"();



CREATE OR REPLACE TRIGGER "enforce_transition_rules" BEFORE INSERT ON "public"."dispatch_transitions" FOR EACH ROW EXECUTE FUNCTION "public"."validate_transition"();



CREATE OR REPLACE TRIGGER "guard_ops_events_reject_delete" BEFORE DELETE ON "public"."guard_ops_events" FOR EACH ROW EXECUTE FUNCTION "public"."guard_ops_events_reject_mutation"();



CREATE OR REPLACE TRIGGER "guard_ops_events_reject_update" BEFORE UPDATE ON "public"."guard_ops_events" FOR EACH ROW EXECUTE FUNCTION "public"."guard_ops_events_reject_mutation"();



CREATE OR REPLACE TRIGGER "incidents_lock_closed_rows_before_update" BEFORE UPDATE ON "public"."incidents" FOR EACH ROW EXECUTE FUNCTION "public"."incidents_lock_closed_rows"();



CREATE OR REPLACE TRIGGER "set_client_contact_endpoint_subscriptions_updated_at" BEFORE UPDATE ON "public"."client_contact_endpoint_subscriptions" FOR EACH ROW EXECUTE FUNCTION "public"."set_guard_directory_updated_at"();



CREATE OR REPLACE TRIGGER "set_client_contacts_updated_at" BEFORE UPDATE ON "public"."client_contacts" FOR EACH ROW EXECUTE FUNCTION "public"."set_guard_directory_updated_at"();



CREATE OR REPLACE TRIGGER "set_client_conversation_ack_updated_at" BEFORE UPDATE ON "public"."client_conversation_acknowledgements" FOR EACH ROW EXECUTE FUNCTION "public"."set_client_conversation_updated_at"();



CREATE OR REPLACE TRIGGER "set_client_conversation_acknowledgements_updated_at" BEFORE UPDATE ON "public"."client_conversation_acknowledgements" FOR EACH ROW EXECUTE FUNCTION "public"."set_client_conversation_updated_at"();



CREATE OR REPLACE TRIGGER "set_client_conversation_messages_updated_at" BEFORE UPDATE ON "public"."client_conversation_messages" FOR EACH ROW EXECUTE FUNCTION "public"."set_client_conversation_updated_at"();



CREATE OR REPLACE TRIGGER "set_client_conversation_push_queue_updated_at" BEFORE UPDATE ON "public"."client_conversation_push_queue" FOR EACH ROW EXECUTE FUNCTION "public"."set_client_conversation_push_queue_updated_at"();



CREATE OR REPLACE TRIGGER "set_client_conversation_push_sync_state_updated_at" BEFORE UPDATE ON "public"."client_conversation_push_sync_state" FOR EACH ROW EXECUTE FUNCTION "public"."set_client_conversation_push_sync_state_updated_at"();



CREATE OR REPLACE TRIGGER "set_client_messaging_endpoints_updated_at" BEFORE UPDATE ON "public"."client_messaging_endpoints" FOR EACH ROW EXECUTE FUNCTION "public"."set_guard_directory_updated_at"();



CREATE OR REPLACE TRIGGER "set_clients_updated_at" BEFORE UPDATE ON "public"."clients" FOR EACH ROW EXECUTE FUNCTION "public"."set_guard_directory_updated_at"();



CREATE OR REPLACE TRIGGER "set_controllers_updated_at" BEFORE UPDATE ON "public"."controllers" FOR EACH ROW EXECUTE FUNCTION "public"."set_guard_directory_updated_at"();



CREATE OR REPLACE TRIGGER "set_employee_site_assignments_updated_at" BEFORE UPDATE ON "public"."employee_site_assignments" FOR EACH ROW EXECUTE FUNCTION "public"."set_guard_directory_updated_at"();



CREATE OR REPLACE TRIGGER "set_employees_updated_at" BEFORE UPDATE ON "public"."employees" FOR EACH ROW EXECUTE FUNCTION "public"."set_guard_directory_updated_at"();



CREATE OR REPLACE TRIGGER "set_guard_assignments_updated_at" BEFORE UPDATE ON "public"."guard_assignments" FOR EACH ROW EXECUTE FUNCTION "public"."set_guard_sync_updated_at"();



CREATE OR REPLACE TRIGGER "set_guard_checkpoint_scans_updated_at" BEFORE UPDATE ON "public"."guard_checkpoint_scans" FOR EACH ROW EXECUTE FUNCTION "public"."set_guard_sync_updated_at"();



CREATE OR REPLACE TRIGGER "set_guard_incident_captures_updated_at" BEFORE UPDATE ON "public"."guard_incident_captures" FOR EACH ROW EXECUTE FUNCTION "public"."set_guard_sync_updated_at"();



CREATE OR REPLACE TRIGGER "set_guard_location_heartbeats_updated_at" BEFORE UPDATE ON "public"."guard_location_heartbeats" FOR EACH ROW EXECUTE FUNCTION "public"."set_guard_sync_updated_at"();



CREATE OR REPLACE TRIGGER "set_guard_ops_media_updated_at" BEFORE UPDATE ON "public"."guard_ops_media" FOR EACH ROW EXECUTE FUNCTION "public"."set_guard_ops_media_updated_at"();



CREATE OR REPLACE TRIGGER "set_guard_panic_signals_updated_at" BEFORE UPDATE ON "public"."guard_panic_signals" FOR EACH ROW EXECUTE FUNCTION "public"."set_guard_sync_updated_at"();



CREATE OR REPLACE TRIGGER "set_guard_sync_operations_updated_at" BEFORE UPDATE ON "public"."guard_sync_operations" FOR EACH ROW EXECUTE FUNCTION "public"."set_guard_sync_updated_at"();



CREATE OR REPLACE TRIGGER "set_guards_updated_at" BEFORE UPDATE ON "public"."guards" FOR EACH ROW EXECUTE FUNCTION "public"."set_guard_directory_updated_at"();



CREATE OR REPLACE TRIGGER "set_hourly_throughput_updated_at" BEFORE UPDATE ON "public"."hourly_throughput" FOR EACH ROW EXECUTE FUNCTION "public"."set_guard_directory_updated_at"();



CREATE OR REPLACE TRIGGER "set_incidents_updated_at" BEFORE UPDATE ON "public"."incidents" FOR EACH ROW EXECUTE FUNCTION "public"."set_guard_directory_updated_at"();



CREATE OR REPLACE TRIGGER "set_site_identity_profiles_updated_at" BEFORE UPDATE ON "public"."site_identity_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."set_guard_directory_updated_at"();



CREATE OR REPLACE TRIGGER "set_sites_updated_at" BEFORE UPDATE ON "public"."sites" FOR EACH ROW EXECUTE FUNCTION "public"."set_guard_directory_updated_at"();



CREATE OR REPLACE TRIGGER "set_staff_updated_at" BEFORE UPDATE ON "public"."staff" FOR EACH ROW EXECUTE FUNCTION "public"."set_guard_directory_updated_at"();



CREATE OR REPLACE TRIGGER "set_telegram_identity_intake_updated_at" BEFORE UPDATE ON "public"."telegram_identity_intake" FOR EACH ROW EXECUTE FUNCTION "public"."set_guard_directory_updated_at"();



CREATE OR REPLACE TRIGGER "set_timestamp_on_site_zones" BEFORE UPDATE ON "public"."site_zones" FOR EACH ROW EXECUTE FUNCTION "public"."set_timestamp"();



CREATE OR REPLACE TRIGGER "set_timestamp_on_sites" BEFORE UPDATE ON "public"."sites" FOR EACH ROW EXECUTE FUNCTION "public"."set_timestamp"();



CREATE OR REPLACE TRIGGER "set_vehicles_updated_at" BEFORE UPDATE ON "public"."vehicles" FOR EACH ROW EXECUTE FUNCTION "public"."set_guard_directory_updated_at"();



CREATE OR REPLACE TRIGGER "sync_legacy_directory_assignment_after_write" AFTER INSERT OR DELETE OR UPDATE ON "public"."employee_site_assignments" FOR EACH ROW EXECUTE FUNCTION "public"."sync_legacy_directory_assignment_trigger"();



CREATE OR REPLACE TRIGGER "sync_legacy_directory_employee_after_write" AFTER INSERT OR DELETE OR UPDATE ON "public"."employees" FOR EACH ROW EXECUTE FUNCTION "public"."sync_legacy_directory_employee_trigger"();



ALTER TABLE ONLY "public"."ThreatMatrix"
    ADD CONSTRAINT "ThreatMatrix_auto_escalate_to_fkey" FOREIGN KEY ("auto_escalate_to") REFERENCES "public"."ThreatLevels"("id");



ALTER TABLE ONLY "public"."ThreatMatrix"
    ADD CONSTRAINT "ThreatMatrix_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "public"."ThreatCategories"("id");



ALTER TABLE ONLY "public"."actions_log"
    ADD CONSTRAINT "actions_log_incident_id_fkey" FOREIGN KEY ("incident_id") REFERENCES "public"."incidents"("id");



ALTER TABLE ONLY "public"."alert_events"
    ADD CONSTRAINT "alert_events_rule_id_fkey" FOREIGN KEY ("rule_id") REFERENCES "public"."alert_rules"("id");



ALTER TABLE ONLY "public"."checkins"
    ADD CONSTRAINT "checkins_patrol_trigger_id_fkey" FOREIGN KEY ("patrol_trigger_id") REFERENCES "public"."patrol_triggers"("id");



ALTER TABLE ONLY "public"."checkins"
    ADD CONSTRAINT "checkins_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "public"."posts"("id");



ALTER TABLE ONLY "public"."client_contact_endpoint_subscriptions"
    ADD CONSTRAINT "client_contact_endpoint_subscriptions_client_contact_fk" FOREIGN KEY ("client_id", "contact_id") REFERENCES "public"."client_contacts"("client_id", "id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."client_contact_endpoint_subscriptions"
    ADD CONSTRAINT "client_contact_endpoint_subscriptions_client_endpoint_fk" FOREIGN KEY ("client_id", "endpoint_id") REFERENCES "public"."client_messaging_endpoints"("client_id", "id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."client_contact_endpoint_subscriptions"
    ADD CONSTRAINT "client_contact_endpoint_subscriptions_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "public"."clients"("client_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."client_contact_endpoint_subscriptions"
    ADD CONSTRAINT "client_contact_endpoint_subscriptions_client_site_fk" FOREIGN KEY ("client_id", "site_id") REFERENCES "public"."sites"("client_id", "site_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."client_contacts"
    ADD CONSTRAINT "client_contacts_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "public"."clients"("client_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."client_contacts"
    ADD CONSTRAINT "client_contacts_client_site_fk" FOREIGN KEY ("client_id", "site_id") REFERENCES "public"."sites"("client_id", "site_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."client_messaging_endpoints"
    ADD CONSTRAINT "client_messaging_endpoints_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "public"."clients"("client_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."client_messaging_endpoints"
    ADD CONSTRAINT "client_messaging_endpoints_client_site_fk" FOREIGN KEY ("client_id", "site_id") REFERENCES "public"."sites"("client_id", "site_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."controllers"
    ADD CONSTRAINT "controllers_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "public"."clients"("client_id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."controllers"
    ADD CONSTRAINT "controllers_client_site_fk" FOREIGN KEY ("client_id", "home_site_id") REFERENCES "public"."sites"("client_id", "site_id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."deployments"
    ADD CONSTRAINT "deployments_guard_id_fkey" FOREIGN KEY ("guard_id") REFERENCES "public"."guards"("id");



ALTER TABLE ONLY "public"."deployments"
    ADD CONSTRAINT "deployments_site_id_fkey" FOREIGN KEY ("site_id") REFERENCES "public"."sites"("id");



ALTER TABLE ONLY "public"."dispatch_transitions"
    ADD CONSTRAINT "dispatch_transitions_dispatch_id_fkey" FOREIGN KEY ("dispatch_id") REFERENCES "public"."dispatch_intents"("dispatch_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."employee_site_assignments"
    ADD CONSTRAINT "employee_site_assignments_employee_fk" FOREIGN KEY ("client_id", "employee_id") REFERENCES "public"."employees"("client_id", "id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."employee_site_assignments"
    ADD CONSTRAINT "employee_site_assignments_site_fk" FOREIGN KEY ("client_id", "site_id") REFERENCES "public"."sites"("client_id", "site_id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."employees"
    ADD CONSTRAINT "employees_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "public"."clients"("client_id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."employees"
    ADD CONSTRAINT "employees_reporting_fk" FOREIGN KEY ("reporting_to_employee_id") REFERENCES "public"."employees"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."evidence_bundles"
    ADD CONSTRAINT "evidence_bundles_dispatch_id_fkey" FOREIGN KEY ("dispatch_id") REFERENCES "public"."dispatch_intents"("dispatch_id");



ALTER TABLE ONLY "public"."execution_locks"
    ADD CONSTRAINT "execution_locks_dispatch_id_fkey" FOREIGN KEY ("dispatch_id") REFERENCES "public"."dispatch_intents"("dispatch_id");



ALTER TABLE ONLY "public"."guard_documents"
    ADD CONSTRAINT "guard_documents_guard_id_fkey" FOREIGN KEY ("guard_id") REFERENCES "public"."guards"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."guard_logs"
    ADD CONSTRAINT "guard_logs_site_id_fkey" FOREIGN KEY ("site_id") REFERENCES "public"."sites"("id");



ALTER TABLE ONLY "public"."guard_ops_media"
    ADD CONSTRAINT "guard_ops_media_event_fk" FOREIGN KEY ("event_id") REFERENCES "public"."guard_ops_events"("event_id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."guard_ops_retention_runs"
    ADD CONSTRAINT "guard_ops_retention_runs_projection_run_id_fkey" FOREIGN KEY ("projection_run_id") REFERENCES "public"."guard_projection_retention_runs"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."guard_ops_retention_runs"
    ADD CONSTRAINT "guard_ops_retention_runs_replay_safety_check_id_fkey" FOREIGN KEY ("replay_safety_check_id") REFERENCES "public"."guard_ops_replay_safety_checks"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."guard_profiles"
    ADD CONSTRAINT "guard_profiles_guard_id_fkey" FOREIGN KEY ("guard_id") REFERENCES "public"."guards"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."guard_sites"
    ADD CONSTRAINT "guard_sites_guard_id_fkey" FOREIGN KEY ("guard_id") REFERENCES "public"."guards"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."guard_sites"
    ADD CONSTRAINT "guard_sites_site_id_fkey" FOREIGN KEY ("site_id") REFERENCES "public"."sites"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."incident_intelligence"
    ADD CONSTRAINT "incident_intelligence_incident_id_fkey" FOREIGN KEY ("incident_id") REFERENCES "public"."incidents"("id");



ALTER TABLE ONLY "public"."incident_outcomes"
    ADD CONSTRAINT "incident_outcomes_incident_id_fkey" FOREIGN KEY ("incident_id") REFERENCES "public"."incidents"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."incident_snapshots"
    ADD CONSTRAINT "incident_snapshots_incident_id_fkey" FOREIGN KEY ("incident_id") REFERENCES "public"."incidents"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."logs"
    ADD CONSTRAINT "logs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."patrol_checkpoints"
    ADD CONSTRAINT "patrol_checkpoints_route_id_fkey" FOREIGN KEY ("route_id") REFERENCES "public"."patrol_routes"("id");



ALTER TABLE ONLY "public"."patrol_scans"
    ADD CONSTRAINT "patrol_scans_checkpoint_id_fkey" FOREIGN KEY ("checkpoint_id") REFERENCES "public"."patrol_checkpoints"("id");



ALTER TABLE ONLY "public"."patrol_triggers"
    ADD CONSTRAINT "patrol_triggers_patrol_id_fkey" FOREIGN KEY ("patrol_id") REFERENCES "public"."patrols"("id");



ALTER TABLE ONLY "public"."patrol_violations"
    ADD CONSTRAINT "patrol_violations_patrol_trigger_id_fkey" FOREIGN KEY ("patrol_trigger_id") REFERENCES "public"."patrol_triggers"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."site_identity_approval_decisions"
    ADD CONSTRAINT "site_identity_approval_decisions_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "public"."clients"("client_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."site_identity_approval_decisions"
    ADD CONSTRAINT "site_identity_approval_decisions_profile_fk" FOREIGN KEY ("profile_id") REFERENCES "public"."site_identity_profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."site_identity_approval_decisions"
    ADD CONSTRAINT "site_identity_approval_decisions_site_fk" FOREIGN KEY ("client_id", "site_id") REFERENCES "public"."sites"("client_id", "site_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."site_identity_profiles"
    ADD CONSTRAINT "site_identity_profiles_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "public"."clients"("client_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."site_identity_profiles"
    ADD CONSTRAINT "site_identity_profiles_site_fk" FOREIGN KEY ("client_id", "site_id") REFERENCES "public"."sites"("client_id", "site_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."site_zones"
    ADD CONSTRAINT "site_zones_site_id_fkey" FOREIGN KEY ("site_id") REFERENCES "public"."sites"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."staff"
    ADD CONSTRAINT "staff_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "public"."clients"("client_id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."staff"
    ADD CONSTRAINT "staff_client_site_fk" FOREIGN KEY ("client_id", "site_id") REFERENCES "public"."sites"("client_id", "site_id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."telegram_identity_intake"
    ADD CONSTRAINT "telegram_identity_intake_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "public"."clients"("client_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."telegram_identity_intake"
    ADD CONSTRAINT "telegram_identity_intake_endpoint_fk" FOREIGN KEY ("endpoint_id") REFERENCES "public"."client_messaging_endpoints"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."telegram_identity_intake"
    ADD CONSTRAINT "telegram_identity_intake_site_fk" FOREIGN KEY ("client_id", "site_id") REFERENCES "public"."sites"("client_id", "site_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_role_id_fkey" FOREIGN KEY ("role_id") REFERENCES "public"."roles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."vehicle_logs"
    ADD CONSTRAINT "vehicle_logs_site_id_fkey" FOREIGN KEY ("site_id") REFERENCES "public"."sites"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."vehicles"
    ADD CONSTRAINT "vehicles_assigned_employee_fk" FOREIGN KEY ("client_id", "assigned_employee_id") REFERENCES "public"."employees"("client_id", "id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."vehicles"
    ADD CONSTRAINT "vehicles_site_fk" FOREIGN KEY ("client_id", "site_id") REFERENCES "public"."sites"("client_id", "site_id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."zara_action_log"
    ADD CONSTRAINT "zara_action_log_scenario_id_fkey" FOREIGN KEY ("scenario_id") REFERENCES "public"."zara_scenarios"("id") ON DELETE CASCADE;



CREATE POLICY "Allow anon read dispatch" ON "public"."dispatch_actions" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Allow authenticated insert" ON "public"."threats" FOR INSERT WITH CHECK (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Allow authenticated read" ON "public"."threats" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Allow authenticated read dispatch" ON "public"."dispatch_actions" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow realtime read" ON "public"."dispatch_actions" FOR SELECT USING (true);



CREATE POLICY "Allow select for authenticated" ON "public"."dispatch_actions" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Anon read access" ON "public"."onyx_alert_outcomes" FOR SELECT USING (true);



CREATE POLICY "Authenticated insert abort logs" ON "public"."abort_logs" FOR INSERT WITH CHECK (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Authenticated insert access" ON "public"."threats" FOR INSERT WITH CHECK (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Authenticated read abort logs" ON "public"."abort_logs" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Authenticated read access" ON "public"."threats" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Public read clusters" ON "public"."global_clusters" FOR SELECT USING (true);



CREATE POLICY "Public read global events" ON "public"."global_events" FOR SELECT USING (true);



CREATE POLICY "Service role full access" ON "public"."onyx_alert_outcomes" USING (("auth"."role"() = 'service_role'::"text"));



ALTER TABLE "public"."ThreatCategories" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."ThreatLevels" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."ThreatMatrix" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."abort_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."actions_log" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "allow all inserts" ON "public"."command_events" FOR INSERT WITH CHECK (true);



CREATE POLICY "allow authenticated read guards" ON "public"."guards" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "allow_all_read" ON "public"."ThreatCategories" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "allow_all_read" ON "public"."ThreatLevels" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "allow_all_read" ON "public"."ThreatMatrix" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "anon_can_insert_site_alarm_events" ON "public"."site_alarm_events" FOR INSERT TO "anon" WITH CHECK (true);



CREATE POLICY "anon_can_read_site_alarm_events" ON "public"."site_alarm_events" FOR SELECT TO "anon" USING (true);



CREATE POLICY "anon_can_read_site_awareness" ON "public"."site_awareness_snapshots" FOR SELECT TO "anon" USING (true);



CREATE POLICY "anon_read_alert_config" ON "public"."site_alert_config" FOR SELECT TO "anon" USING (true);



CREATE POLICY "anon_read_camera_zones" ON "public"."site_camera_zones" FOR SELECT TO "anon" USING (true);



CREATE POLICY "anon_read_site_profiles" ON "public"."site_intelligence_profiles" FOR SELECT TO "anon" USING (true);



CREATE POLICY "anon_read_vehicles" ON "public"."site_vehicle_registry" FOR SELECT TO "anon" USING (true);



CREATE POLICY "anon_read_visitors" ON "public"."site_expected_visitors" FOR SELECT TO "anon" USING (true);



CREATE POLICY "authenticated read incident intelligence" ON "public"."incident_intelligence" FOR SELECT TO "authenticated" USING (true);



ALTER TABLE "public"."client_contact_endpoint_subscriptions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "client_contact_endpoint_subscriptions_delete_policy" ON "public"."client_contact_endpoint_subscriptions" FOR DELETE TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



CREATE POLICY "client_contact_endpoint_subscriptions_insert_policy" ON "public"."client_contact_endpoint_subscriptions" FOR INSERT TO "authenticated" WITH CHECK ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



CREATE POLICY "client_contact_endpoint_subscriptions_select_policy" ON "public"."client_contact_endpoint_subscriptions" FOR SELECT TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND ("public"."onyx_is_control_role"() OR (("site_id" IS NOT NULL) AND "public"."onyx_has_site"("site_id")))));



CREATE POLICY "client_contact_endpoint_subscriptions_update_policy" ON "public"."client_contact_endpoint_subscriptions" FOR UPDATE TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"())) WITH CHECK ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



ALTER TABLE "public"."client_contacts" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "client_contacts_delete_policy" ON "public"."client_contacts" FOR DELETE TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



CREATE POLICY "client_contacts_insert_policy" ON "public"."client_contacts" FOR INSERT TO "authenticated" WITH CHECK ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



CREATE POLICY "client_contacts_select_policy" ON "public"."client_contacts" FOR SELECT TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND ("public"."onyx_is_control_role"() OR (("site_id" IS NOT NULL) AND "public"."onyx_has_site"("site_id")))));



CREATE POLICY "client_contacts_update_policy" ON "public"."client_contacts" FOR UPDATE TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"())) WITH CHECK ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



ALTER TABLE "public"."client_messaging_endpoints" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "client_messaging_endpoints_delete_policy" ON "public"."client_messaging_endpoints" FOR DELETE TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



CREATE POLICY "client_messaging_endpoints_insert_policy" ON "public"."client_messaging_endpoints" FOR INSERT TO "authenticated" WITH CHECK ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



CREATE POLICY "client_messaging_endpoints_select_policy" ON "public"."client_messaging_endpoints" FOR SELECT TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND ("public"."onyx_is_control_role"() OR (("site_id" IS NOT NULL) AND "public"."onyx_has_site"("site_id")))));



CREATE POLICY "client_messaging_endpoints_update_policy" ON "public"."client_messaging_endpoints" FOR UPDATE TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"())) WITH CHECK ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



ALTER TABLE "public"."clients" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "clients_all" ON "public"."clients" TO "authenticated", "anon" USING (true) WITH CHECK (true);



CREATE POLICY "clients_delete_policy" ON "public"."clients" FOR DELETE TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



CREATE POLICY "clients_insert" ON "public"."clients" FOR INSERT TO "authenticated", "anon" WITH CHECK (true);



CREATE POLICY "clients_insert_policy" ON "public"."clients" FOR INSERT TO "authenticated" WITH CHECK ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



CREATE POLICY "clients_select" ON "public"."clients" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "clients_select_policy" ON "public"."clients" FOR SELECT TO "authenticated" USING (("client_id" = "public"."onyx_client_id"()));



CREATE POLICY "clients_update_policy" ON "public"."clients" FOR UPDATE TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"())) WITH CHECK ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



ALTER TABLE "public"."command_events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."controllers" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "controllers_delete_policy" ON "public"."controllers" FOR DELETE TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



CREATE POLICY "controllers_insert_policy" ON "public"."controllers" FOR INSERT TO "authenticated" WITH CHECK ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



CREATE POLICY "controllers_select_policy" ON "public"."controllers" FOR SELECT TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



CREATE POLICY "controllers_update_policy" ON "public"."controllers" FOR UPDATE TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"())) WITH CHECK ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



ALTER TABLE "public"."employee_site_assignments" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "employee_site_assignments_delete_policy" ON "public"."employee_site_assignments" FOR DELETE TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



CREATE POLICY "employee_site_assignments_insert_policy" ON "public"."employee_site_assignments" FOR INSERT TO "authenticated" WITH CHECK ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



CREATE POLICY "employee_site_assignments_select_policy" ON "public"."employee_site_assignments" FOR SELECT TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND ("public"."onyx_is_control_role"() OR (("public"."onyx_role_type"() = 'guard'::"text") AND (EXISTS ( SELECT 1
   FROM "public"."employees" "e"
  WHERE (("e"."id" = "employee_site_assignments"."employee_id") AND ("e"."client_id" = "employee_site_assignments"."client_id") AND ("e"."employee_code" = "public"."onyx_guard_id"()))))))));



CREATE POLICY "employee_site_assignments_update_policy" ON "public"."employee_site_assignments" FOR UPDATE TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"())) WITH CHECK ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



ALTER TABLE "public"."employees" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "employees_delete_policy" ON "public"."employees" FOR DELETE TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



CREATE POLICY "employees_insert_policy" ON "public"."employees" FOR INSERT TO "authenticated" WITH CHECK ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



CREATE POLICY "employees_select_policy" ON "public"."employees" FOR SELECT TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND ("public"."onyx_is_control_role"() OR (("public"."onyx_role_type"() = 'guard'::"text") AND ("employee_code" = "public"."onyx_guard_id"())))));



CREATE POLICY "employees_update_policy" ON "public"."employees" FOR UPDATE TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"())) WITH CHECK ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



ALTER TABLE "public"."fr_person_registry" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."global_clusters" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."global_events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."guard_assignments" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "guard_assignments_insert_policy" ON "public"."guard_assignments" FOR INSERT TO "authenticated" WITH CHECK ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_has_site"("site_id") AND ((("public"."onyx_role_type"() = 'guard'::"text") AND ("guard_id" = "public"."onyx_guard_id"())) OR "public"."onyx_is_control_role"())));



CREATE POLICY "guard_assignments_select_policy" ON "public"."guard_assignments" FOR SELECT TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_has_site"("site_id") AND ((("public"."onyx_role_type"() = 'guard'::"text") AND ("guard_id" = "public"."onyx_guard_id"())) OR "public"."onyx_is_control_role"())));



CREATE POLICY "guard_assignments_update_policy" ON "public"."guard_assignments" FOR UPDATE TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_has_site"("site_id") AND ((("public"."onyx_role_type"() = 'guard'::"text") AND ("guard_id" = "public"."onyx_guard_id"())) OR "public"."onyx_is_control_role"()))) WITH CHECK ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_has_site"("site_id") AND ((("public"."onyx_role_type"() = 'guard'::"text") AND ("guard_id" = "public"."onyx_guard_id"())) OR "public"."onyx_is_control_role"())));



ALTER TABLE "public"."guard_checkpoint_scans" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "guard_checkpoint_scans_insert_policy" ON "public"."guard_checkpoint_scans" FOR INSERT TO "authenticated" WITH CHECK ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_has_site"("site_id") AND ((("public"."onyx_role_type"() = 'guard'::"text") AND ("guard_id" = "public"."onyx_guard_id"())) OR "public"."onyx_is_control_role"())));



CREATE POLICY "guard_checkpoint_scans_select_policy" ON "public"."guard_checkpoint_scans" FOR SELECT TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_has_site"("site_id") AND ((("public"."onyx_role_type"() = 'guard'::"text") AND ("guard_id" = "public"."onyx_guard_id"())) OR "public"."onyx_is_control_role"())));



ALTER TABLE "public"."guard_documents" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."guard_incident_captures" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "guard_incident_captures_insert_policy" ON "public"."guard_incident_captures" FOR INSERT TO "authenticated" WITH CHECK ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_has_site"("site_id") AND ((("public"."onyx_role_type"() = 'guard'::"text") AND ("guard_id" = "public"."onyx_guard_id"())) OR "public"."onyx_is_control_role"())));



CREATE POLICY "guard_incident_captures_select_policy" ON "public"."guard_incident_captures" FOR SELECT TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_has_site"("site_id") AND ((("public"."onyx_role_type"() = 'guard'::"text") AND ("guard_id" = "public"."onyx_guard_id"())) OR "public"."onyx_is_control_role"())));



ALTER TABLE "public"."guard_location_heartbeats" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "guard_location_heartbeats_insert_policy" ON "public"."guard_location_heartbeats" FOR INSERT TO "authenticated" WITH CHECK ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_has_site"("site_id") AND ((("public"."onyx_role_type"() = 'guard'::"text") AND ("guard_id" = "public"."onyx_guard_id"())) OR "public"."onyx_is_control_role"())));



CREATE POLICY "guard_location_heartbeats_select_policy" ON "public"."guard_location_heartbeats" FOR SELECT TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_has_site"("site_id") AND ((("public"."onyx_role_type"() = 'guard'::"text") AND ("guard_id" = "public"."onyx_guard_id"())) OR "public"."onyx_is_control_role"())));



ALTER TABLE "public"."guard_ops_events" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "guard_ops_events_insert_policy" ON "public"."guard_ops_events" FOR INSERT TO "authenticated" WITH CHECK (("public"."onyx_has_site"("site_id") AND ((("public"."onyx_role_type"() = 'guard'::"text") AND ("guard_id" = "public"."onyx_guard_id"())) OR "public"."onyx_is_control_role"())));



CREATE POLICY "guard_ops_events_select_policy" ON "public"."guard_ops_events" FOR SELECT TO "authenticated" USING (("public"."onyx_has_site"("site_id") AND ((("public"."onyx_role_type"() = 'guard'::"text") AND ("guard_id" = "public"."onyx_guard_id"())) OR "public"."onyx_is_control_role"())));



ALTER TABLE "public"."guard_ops_media" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "guard_ops_media_insert_policy" ON "public"."guard_ops_media" FOR INSERT TO "authenticated" WITH CHECK (("public"."onyx_has_site"("site_id") AND ((("public"."onyx_role_type"() = 'guard'::"text") AND ("guard_id" = "public"."onyx_guard_id"())) OR "public"."onyx_is_control_role"())));



CREATE POLICY "guard_ops_media_select_policy" ON "public"."guard_ops_media" FOR SELECT TO "authenticated" USING (("public"."onyx_has_site"("site_id") AND ((("public"."onyx_role_type"() = 'guard'::"text") AND ("guard_id" = "public"."onyx_guard_id"())) OR "public"."onyx_is_control_role"())));



CREATE POLICY "guard_ops_media_update_policy" ON "public"."guard_ops_media" FOR UPDATE TO "authenticated" USING (("public"."onyx_has_site"("site_id") AND ((("public"."onyx_role_type"() = 'guard'::"text") AND ("guard_id" = "public"."onyx_guard_id"())) OR "public"."onyx_is_control_role"()))) WITH CHECK (("public"."onyx_has_site"("site_id") AND ((("public"."onyx_role_type"() = 'guard'::"text") AND ("guard_id" = "public"."onyx_guard_id"())) OR "public"."onyx_is_control_role"())));



ALTER TABLE "public"."guard_panic_signals" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "guard_panic_signals_insert_policy" ON "public"."guard_panic_signals" FOR INSERT TO "authenticated" WITH CHECK ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_has_site"("site_id") AND ((("public"."onyx_role_type"() = 'guard'::"text") AND ("guard_id" = "public"."onyx_guard_id"())) OR "public"."onyx_is_control_role"())));



CREATE POLICY "guard_panic_signals_select_policy" ON "public"."guard_panic_signals" FOR SELECT TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_has_site"("site_id") AND ((("public"."onyx_role_type"() = 'guard'::"text") AND ("guard_id" = "public"."onyx_guard_id"())) OR "public"."onyx_is_control_role"())));



ALTER TABLE "public"."guard_profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "guard_profiles_deny_all" ON "public"."guard_profiles" TO "authenticated" USING (false);



ALTER TABLE "public"."guard_sync_operations" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "guard_sync_operations_insert_policy" ON "public"."guard_sync_operations" FOR INSERT TO "authenticated" WITH CHECK ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_has_site"("site_id") AND ((("public"."onyx_role_type"() = 'guard'::"text") AND ("guard_id" = "public"."onyx_guard_id"())) OR "public"."onyx_is_control_role"())));



CREATE POLICY "guard_sync_operations_select_policy" ON "public"."guard_sync_operations" FOR SELECT TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_has_site"("site_id") AND ((("public"."onyx_role_type"() = 'guard'::"text") AND ("guard_id" = "public"."onyx_guard_id"())) OR "public"."onyx_is_control_role"())));



CREATE POLICY "guard_sync_operations_update_policy" ON "public"."guard_sync_operations" FOR UPDATE TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_has_site"("site_id") AND ((("public"."onyx_role_type"() = 'guard'::"text") AND ("guard_id" = "public"."onyx_guard_id"())) OR "public"."onyx_is_control_role"()))) WITH CHECK ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_has_site"("site_id") AND ((("public"."onyx_role_type"() = 'guard'::"text") AND ("guard_id" = "public"."onyx_guard_id"())) OR "public"."onyx_is_control_role"())));



ALTER TABLE "public"."guards" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "guards see own patrol orders" ON "public"."patrol_triggers" FOR SELECT USING (("auth"."uid"() = "guard_id"));



CREATE POLICY "guards_all" ON "public"."guards" TO "authenticated", "anon" USING (true) WITH CHECK (true);



CREATE POLICY "guards_delete_policy" ON "public"."guards" FOR DELETE TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



CREATE POLICY "guards_insert" ON "public"."guards" FOR INSERT TO "authenticated", "anon" WITH CHECK (true);



CREATE POLICY "guards_insert_policy" ON "public"."guards" FOR INSERT TO "authenticated" WITH CHECK ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



CREATE POLICY "guards_read_authenticated" ON "public"."guards" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "guards_select" ON "public"."guards" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "guards_select_policy" ON "public"."guards" FOR SELECT TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND ("public"."onyx_is_control_role"() OR ("guard_id" = "public"."onyx_guard_id"()))));



CREATE POLICY "guards_update_policy" ON "public"."guards" FOR UPDATE TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"())) WITH CHECK ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



CREATE POLICY "guards_write_authenticated" ON "public"."guards" TO "authenticated" USING (true) WITH CHECK (true);



ALTER TABLE "public"."hourly_throughput" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "hourly_throughput_select_policy" ON "public"."hourly_throughput" FOR SELECT TO "authenticated" USING (("client_id" = "public"."onyx_client_id"()));



ALTER TABLE "public"."incident_actions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "incident_actions_insert" ON "public"."incident_actions" FOR INSERT WITH CHECK (true);



CREATE POLICY "incident_actions_select" ON "public"."incident_actions" FOR SELECT USING (true);



ALTER TABLE "public"."incident_intelligence" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."incidents" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "incidents_delete_policy" ON "public"."incidents" FOR DELETE TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



CREATE POLICY "incidents_insert_policy" ON "public"."incidents" FOR INSERT TO "authenticated" WITH CHECK ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_has_site"("site_id")));



CREATE POLICY "incidents_select_policy" ON "public"."incidents" FOR SELECT TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_has_site"("site_id")));



CREATE POLICY "incidents_update_policy" ON "public"."incidents" FOR UPDATE TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_has_site"("site_id") AND "public"."onyx_is_control_role"())) WITH CHECK ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_has_site"("site_id") AND "public"."onyx_is_control_role"()));



ALTER TABLE "public"."onyx_alert_outcomes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "onyx_alert_outcomes_anon_read" ON "public"."onyx_alert_outcomes" FOR SELECT TO "anon" USING (true);



CREATE POLICY "onyx_alert_outcomes_service_all" ON "public"."onyx_alert_outcomes" TO "service_role" USING (true) WITH CHECK (true);



ALTER TABLE "public"."onyx_awareness_latency" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "onyx_awareness_latency_anon_read" ON "public"."onyx_awareness_latency" FOR SELECT TO "anon" USING (true);



CREATE POLICY "onyx_awareness_latency_service_all" ON "public"."onyx_awareness_latency" TO "service_role" USING (true) WITH CHECK (true);



ALTER TABLE "public"."onyx_client_trust_snapshots" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "onyx_client_trust_snapshots_anon_read" ON "public"."onyx_client_trust_snapshots" FOR SELECT TO "anon" USING (true);



CREATE POLICY "onyx_client_trust_snapshots_service_all" ON "public"."onyx_client_trust_snapshots" TO "service_role" USING (true) WITH CHECK (true);



ALTER TABLE "public"."onyx_event_store" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "onyx_event_store_anon_read" ON "public"."onyx_event_store" FOR SELECT TO "anon" USING (true);



CREATE POLICY "onyx_event_store_service_all" ON "public"."onyx_event_store" TO "service_role" USING (true) WITH CHECK (true);



ALTER TABLE "public"."onyx_evidence_certificates" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "onyx_evidence_certificates_anon_read" ON "public"."onyx_evidence_certificates" FOR SELECT TO "anon" USING (true);



CREATE POLICY "onyx_evidence_certificates_service_all" ON "public"."onyx_evidence_certificates" TO "service_role" USING (true) WITH CHECK (true);



ALTER TABLE "public"."onyx_operator_scores" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "onyx_operator_scores_anon_read" ON "public"."onyx_operator_scores" FOR SELECT TO "anon" USING (true);



CREATE POLICY "onyx_operator_scores_service_all" ON "public"."onyx_operator_scores" TO "service_role" USING (true) WITH CHECK (true);



ALTER TABLE "public"."onyx_operator_simulations" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "onyx_operator_simulations_anon_read" ON "public"."onyx_operator_simulations" FOR SELECT TO "anon" USING (true);



CREATE POLICY "onyx_operator_simulations_service_all" ON "public"."onyx_operator_simulations" TO "service_role" USING (true) WITH CHECK (true);



ALTER TABLE "public"."onyx_power_mode_events" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "onyx_power_mode_events_anon_read" ON "public"."onyx_power_mode_events" FOR SELECT TO "anon" USING (true);



CREATE POLICY "onyx_power_mode_events_service_all" ON "public"."onyx_power_mode_events" TO "service_role" USING (true) WITH CHECK (true);



ALTER TABLE "public"."patrol_checkpoint_scans" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "patrol_checkpoint_scans_anon_read" ON "public"."patrol_checkpoint_scans" FOR SELECT TO "anon" USING (true);



CREATE POLICY "patrol_checkpoint_scans_service_all" ON "public"."patrol_checkpoint_scans" TO "service_role" USING (true) WITH CHECK (true);



ALTER TABLE "public"."patrol_checkpoints" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."patrol_compliance" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."patrol_routes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."patrol_scans" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."patrol_triggers" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "service_all_guard_assignments" ON "public"."guard_assignments" TO "service_role" USING (true);



CREATE POLICY "service_all_patrol_checkpoints" ON "public"."patrol_checkpoints" TO "service_role" USING (true);



CREATE POLICY "service_all_patrol_compliance" ON "public"."patrol_compliance" TO "service_role" USING (true);



CREATE POLICY "service_all_patrol_routes" ON "public"."patrol_routes" TO "service_role" USING (true);



CREATE POLICY "service_all_patrol_scans" ON "public"."patrol_scans" TO "service_role" USING (true);



CREATE POLICY "service_all_site_profiles" ON "public"."site_intelligence_profiles" TO "service_role" USING (true);



CREATE POLICY "service_all_zone_rules" ON "public"."site_zone_rules" TO "service_role" USING (true);



CREATE POLICY "service_full_access_fr_registry" ON "public"."fr_person_registry" TO "service_role" USING (true);



CREATE POLICY "service_full_access_vehicles" ON "public"."site_vehicle_registry" TO "service_role" USING (true);



CREATE POLICY "service_full_access_visitors" ON "public"."site_expected_visitors" TO "service_role" USING (true);



CREATE POLICY "service_manage_camera_zones" ON "public"."site_camera_zones" TO "service_role" USING (true);



ALTER TABLE "public"."site_alarm_events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."site_alert_config" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "site_awareness_snapshots_select_policy" ON "public"."site_awareness_snapshots" FOR SELECT TO "authenticated", "anon" USING (true);



ALTER TABLE "public"."site_camera_zones" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."site_expected_visitors" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."site_identity_approval_decisions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "site_identity_approval_decisions_insert_policy" ON "public"."site_identity_approval_decisions" FOR INSERT TO "authenticated" WITH CHECK ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



CREATE POLICY "site_identity_approval_decisions_select_policy" ON "public"."site_identity_approval_decisions" FOR SELECT TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND ("public"."onyx_is_control_role"() OR "public"."onyx_has_site"("site_id"))));



ALTER TABLE "public"."site_identity_profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "site_identity_profiles_delete_policy" ON "public"."site_identity_profiles" FOR DELETE TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



CREATE POLICY "site_identity_profiles_insert_policy" ON "public"."site_identity_profiles" FOR INSERT TO "authenticated" WITH CHECK ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



CREATE POLICY "site_identity_profiles_select_policy" ON "public"."site_identity_profiles" FOR SELECT TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND ("public"."onyx_is_control_role"() OR "public"."onyx_has_site"("site_id"))));



CREATE POLICY "site_identity_profiles_update_policy" ON "public"."site_identity_profiles" FOR UPDATE TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"())) WITH CHECK ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



ALTER TABLE "public"."site_intelligence_profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."site_vehicle_registry" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."site_zone_rules" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sites" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "sites_delete_policy" ON "public"."sites" FOR DELETE TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



CREATE POLICY "sites_insert_policy" ON "public"."sites" FOR INSERT TO "authenticated" WITH CHECK ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



CREATE POLICY "sites_select_policy" ON "public"."sites" FOR SELECT TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND ("public"."onyx_is_control_role"() OR "public"."onyx_has_site"("site_id"))));



CREATE POLICY "sites_update_policy" ON "public"."sites" FOR UPDATE TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"())) WITH CHECK ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



ALTER TABLE "public"."staff" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "staff_delete_policy" ON "public"."staff" FOR DELETE TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



CREATE POLICY "staff_insert_policy" ON "public"."staff" FOR INSERT TO "authenticated" WITH CHECK ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



CREATE POLICY "staff_select_policy" ON "public"."staff" FOR SELECT TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



CREATE POLICY "staff_update_policy" ON "public"."staff" FOR UPDATE TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"())) WITH CHECK ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



ALTER TABLE "public"."telegram_identity_intake" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "telegram_identity_intake_insert_policy" ON "public"."telegram_identity_intake" FOR INSERT TO "authenticated" WITH CHECK ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



CREATE POLICY "telegram_identity_intake_select_policy" ON "public"."telegram_identity_intake" FOR SELECT TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND ("public"."onyx_is_control_role"() OR "public"."onyx_has_site"("site_id"))));



CREATE POLICY "telegram_identity_intake_update_policy" ON "public"."telegram_identity_intake" FOR UPDATE TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"())) WITH CHECK ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



CREATE POLICY "telegram_inbound_authenticated_select" ON "public"."telegram_inbound_updates" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "telegram_inbound_service_insert" ON "public"."telegram_inbound_updates" FOR INSERT TO "service_role" WITH CHECK (true);



ALTER TABLE "public"."telegram_inbound_updates" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."threats" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."vehicle_visits" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "vehicle_visits_select_policy" ON "public"."vehicle_visits" FOR SELECT TO "authenticated" USING (("client_id" = "public"."onyx_client_id"()));



ALTER TABLE "public"."vehicles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "vehicles_delete_policy" ON "public"."vehicles" FOR DELETE TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



CREATE POLICY "vehicles_insert_policy" ON "public"."vehicles" FOR INSERT TO "authenticated" WITH CHECK ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



CREATE POLICY "vehicles_select_policy" ON "public"."vehicles" FOR SELECT TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND ("public"."onyx_is_control_role"() OR (("site_id" IS NOT NULL) AND "public"."onyx_has_site"("site_id")))));



CREATE POLICY "vehicles_update_policy" ON "public"."vehicles" FOR UPDATE TO "authenticated" USING ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"())) WITH CHECK ((("client_id" = "public"."onyx_client_id"()) AND "public"."onyx_is_control_role"()));



ALTER TABLE "public"."zara_action_log" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "zara_action_log_authenticated_insert" ON "public"."zara_action_log" FOR INSERT TO "authenticated" WITH CHECK (("org_id" = COALESCE(NULLIF(("auth"."jwt"() ->> 'org_id'::"text"), ''::"text"), 'global'::"text")));



CREATE POLICY "zara_action_log_authenticated_select" ON "public"."zara_action_log" FOR SELECT TO "authenticated" USING (("org_id" = COALESCE(NULLIF(("auth"."jwt"() ->> 'org_id'::"text"), ''::"text"), 'global'::"text")));



CREATE POLICY "zara_action_log_service_all" ON "public"."zara_action_log" TO "service_role" USING (true) WITH CHECK (true);



ALTER TABLE "public"."zara_scenarios" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "zara_scenarios_authenticated_insert" ON "public"."zara_scenarios" FOR INSERT TO "authenticated" WITH CHECK (("org_id" = COALESCE(NULLIF(("auth"."jwt"() ->> 'org_id'::"text"), ''::"text"), 'global'::"text")));



CREATE POLICY "zara_scenarios_authenticated_select" ON "public"."zara_scenarios" FOR SELECT TO "authenticated" USING (("org_id" = COALESCE(NULLIF(("auth"."jwt"() ->> 'org_id'::"text"), ''::"text"), 'global'::"text")));



CREATE POLICY "zara_scenarios_authenticated_update" ON "public"."zara_scenarios" FOR UPDATE TO "authenticated" USING (("org_id" = COALESCE(NULLIF(("auth"."jwt"() ->> 'org_id'::"text"), ''::"text"), 'global'::"text"))) WITH CHECK (("org_id" = COALESCE(NULLIF(("auth"."jwt"() ->> 'org_id'::"text"), ''::"text"), 'global'::"text")));



CREATE POLICY "zara_scenarios_service_all" ON "public"."zara_scenarios" TO "service_role" USING (true) WITH CHECK (true);





ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";






ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."ThreatCategories";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."ThreatLevels";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."ThreatMatrix";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."abort_logs";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."dispatch_actions";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."threats";






GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT ALL ON FUNCTION "public"."box2d_in"("cstring") TO "postgres";
GRANT ALL ON FUNCTION "public"."box2d_in"("cstring") TO "anon";
GRANT ALL ON FUNCTION "public"."box2d_in"("cstring") TO "authenticated";
GRANT ALL ON FUNCTION "public"."box2d_in"("cstring") TO "service_role";



GRANT ALL ON FUNCTION "public"."box2d_out"("public"."box2d") TO "postgres";
GRANT ALL ON FUNCTION "public"."box2d_out"("public"."box2d") TO "anon";
GRANT ALL ON FUNCTION "public"."box2d_out"("public"."box2d") TO "authenticated";
GRANT ALL ON FUNCTION "public"."box2d_out"("public"."box2d") TO "service_role";



GRANT ALL ON FUNCTION "public"."box2df_in"("cstring") TO "postgres";
GRANT ALL ON FUNCTION "public"."box2df_in"("cstring") TO "anon";
GRANT ALL ON FUNCTION "public"."box2df_in"("cstring") TO "authenticated";
GRANT ALL ON FUNCTION "public"."box2df_in"("cstring") TO "service_role";



GRANT ALL ON FUNCTION "public"."box2df_out"("public"."box2df") TO "postgres";
GRANT ALL ON FUNCTION "public"."box2df_out"("public"."box2df") TO "anon";
GRANT ALL ON FUNCTION "public"."box2df_out"("public"."box2df") TO "authenticated";
GRANT ALL ON FUNCTION "public"."box2df_out"("public"."box2df") TO "service_role";



GRANT ALL ON FUNCTION "public"."box3d_in"("cstring") TO "postgres";
GRANT ALL ON FUNCTION "public"."box3d_in"("cstring") TO "anon";
GRANT ALL ON FUNCTION "public"."box3d_in"("cstring") TO "authenticated";
GRANT ALL ON FUNCTION "public"."box3d_in"("cstring") TO "service_role";



GRANT ALL ON FUNCTION "public"."box3d_out"("public"."box3d") TO "postgres";
GRANT ALL ON FUNCTION "public"."box3d_out"("public"."box3d") TO "anon";
GRANT ALL ON FUNCTION "public"."box3d_out"("public"."box3d") TO "authenticated";
GRANT ALL ON FUNCTION "public"."box3d_out"("public"."box3d") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_analyze"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_analyze"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_analyze"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_analyze"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_in"("cstring", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_in"("cstring", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."geography_in"("cstring", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_in"("cstring", "oid", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_out"("public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_out"("public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_out"("public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_out"("public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_recv"("internal", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_recv"("internal", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."geography_recv"("internal", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_recv"("internal", "oid", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_send"("public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_send"("public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_send"("public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_send"("public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_typmod_in"("cstring"[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_typmod_in"("cstring"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."geography_typmod_in"("cstring"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_typmod_in"("cstring"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_typmod_out"(integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_typmod_out"(integer) TO "anon";
GRANT ALL ON FUNCTION "public"."geography_typmod_out"(integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_typmod_out"(integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_analyze"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_analyze"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_analyze"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_analyze"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_in"("cstring") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_in"("cstring") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_in"("cstring") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_in"("cstring") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_out"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_out"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_out"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_out"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_recv"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_recv"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_recv"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_recv"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_send"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_send"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_send"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_send"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_typmod_in"("cstring"[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_typmod_in"("cstring"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_typmod_in"("cstring"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_typmod_in"("cstring"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_typmod_out"(integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_typmod_out"(integer) TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_typmod_out"(integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_typmod_out"(integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."gidx_in"("cstring") TO "postgres";
GRANT ALL ON FUNCTION "public"."gidx_in"("cstring") TO "anon";
GRANT ALL ON FUNCTION "public"."gidx_in"("cstring") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gidx_in"("cstring") TO "service_role";



GRANT ALL ON FUNCTION "public"."gidx_out"("public"."gidx") TO "postgres";
GRANT ALL ON FUNCTION "public"."gidx_out"("public"."gidx") TO "anon";
GRANT ALL ON FUNCTION "public"."gidx_out"("public"."gidx") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gidx_out"("public"."gidx") TO "service_role";



GRANT ALL ON FUNCTION "public"."spheroid_in"("cstring") TO "postgres";
GRANT ALL ON FUNCTION "public"."spheroid_in"("cstring") TO "anon";
GRANT ALL ON FUNCTION "public"."spheroid_in"("cstring") TO "authenticated";
GRANT ALL ON FUNCTION "public"."spheroid_in"("cstring") TO "service_role";



GRANT ALL ON FUNCTION "public"."spheroid_out"("public"."spheroid") TO "postgres";
GRANT ALL ON FUNCTION "public"."spheroid_out"("public"."spheroid") TO "anon";
GRANT ALL ON FUNCTION "public"."spheroid_out"("public"."spheroid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."spheroid_out"("public"."spheroid") TO "service_role";



GRANT ALL ON FUNCTION "public"."box3d"("public"."box2d") TO "postgres";
GRANT ALL ON FUNCTION "public"."box3d"("public"."box2d") TO "anon";
GRANT ALL ON FUNCTION "public"."box3d"("public"."box2d") TO "authenticated";
GRANT ALL ON FUNCTION "public"."box3d"("public"."box2d") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry"("public"."box2d") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry"("public"."box2d") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry"("public"."box2d") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry"("public"."box2d") TO "service_role";



GRANT ALL ON FUNCTION "public"."box"("public"."box3d") TO "postgres";
GRANT ALL ON FUNCTION "public"."box"("public"."box3d") TO "anon";
GRANT ALL ON FUNCTION "public"."box"("public"."box3d") TO "authenticated";
GRANT ALL ON FUNCTION "public"."box"("public"."box3d") TO "service_role";



GRANT ALL ON FUNCTION "public"."box2d"("public"."box3d") TO "postgres";
GRANT ALL ON FUNCTION "public"."box2d"("public"."box3d") TO "anon";
GRANT ALL ON FUNCTION "public"."box2d"("public"."box3d") TO "authenticated";
GRANT ALL ON FUNCTION "public"."box2d"("public"."box3d") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry"("public"."box3d") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry"("public"."box3d") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry"("public"."box3d") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry"("public"."box3d") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography"("bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography"("bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."geography"("bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography"("bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry"("bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry"("bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry"("bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry"("bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."bytea"("public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."bytea"("public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."bytea"("public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."bytea"("public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography"("public"."geography", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."geography"("public"."geography", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."geography"("public"."geography", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography"("public"."geography", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry"("public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry"("public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry"("public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry"("public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."box"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."box"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."box"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."box"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."box2d"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."box2d"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."box2d"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."box2d"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."box3d"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."box3d"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."box3d"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."box3d"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."bytea"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."bytea"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."bytea"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."bytea"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geography"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry"("public"."geometry", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry"("public"."geometry", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."geometry"("public"."geometry", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry"("public"."geometry", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."json"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."json"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."json"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."json"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."jsonb"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."jsonb"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."jsonb"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."jsonb"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."path"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."path"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."path"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."path"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."point"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."point"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."point"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."point"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."polygon"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."polygon"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."polygon"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."polygon"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."text"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."text"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."text"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."text"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry"("path") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry"("path") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry"("path") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry"("path") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry"("point") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry"("point") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry"("point") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry"("point") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry"("polygon") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry"("polygon") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry"("polygon") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry"("polygon") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry"("text") TO "service_role";














































































































































































GRANT ALL ON FUNCTION "public"."_postgis_deprecate"("oldname" "text", "newname" "text", "version" "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."_postgis_deprecate"("oldname" "text", "newname" "text", "version" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."_postgis_deprecate"("oldname" "text", "newname" "text", "version" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_postgis_deprecate"("oldname" "text", "newname" "text", "version" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."_postgis_index_extent"("tbl" "regclass", "col" "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."_postgis_index_extent"("tbl" "regclass", "col" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."_postgis_index_extent"("tbl" "regclass", "col" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_postgis_index_extent"("tbl" "regclass", "col" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."_postgis_join_selectivity"("regclass", "text", "regclass", "text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."_postgis_join_selectivity"("regclass", "text", "regclass", "text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."_postgis_join_selectivity"("regclass", "text", "regclass", "text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_postgis_join_selectivity"("regclass", "text", "regclass", "text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."_postgis_pgsql_version"() TO "postgres";
GRANT ALL ON FUNCTION "public"."_postgis_pgsql_version"() TO "anon";
GRANT ALL ON FUNCTION "public"."_postgis_pgsql_version"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."_postgis_pgsql_version"() TO "service_role";



GRANT ALL ON FUNCTION "public"."_postgis_scripts_pgsql_version"() TO "postgres";
GRANT ALL ON FUNCTION "public"."_postgis_scripts_pgsql_version"() TO "anon";
GRANT ALL ON FUNCTION "public"."_postgis_scripts_pgsql_version"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."_postgis_scripts_pgsql_version"() TO "service_role";



GRANT ALL ON FUNCTION "public"."_postgis_selectivity"("tbl" "regclass", "att_name" "text", "geom" "public"."geometry", "mode" "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."_postgis_selectivity"("tbl" "regclass", "att_name" "text", "geom" "public"."geometry", "mode" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."_postgis_selectivity"("tbl" "regclass", "att_name" "text", "geom" "public"."geometry", "mode" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_postgis_selectivity"("tbl" "regclass", "att_name" "text", "geom" "public"."geometry", "mode" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."_postgis_stats"("tbl" "regclass", "att_name" "text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."_postgis_stats"("tbl" "regclass", "att_name" "text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."_postgis_stats"("tbl" "regclass", "att_name" "text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_postgis_stats"("tbl" "regclass", "att_name" "text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_3ddfullywithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_3ddfullywithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."_st_3ddfullywithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_3ddfullywithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_3ddwithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_3ddwithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."_st_3ddwithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_3ddwithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_3dintersects"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_3dintersects"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_3dintersects"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_3dintersects"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_asgml"(integer, "public"."geometry", integer, integer, "text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_asgml"(integer, "public"."geometry", integer, integer, "text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_asgml"(integer, "public"."geometry", integer, integer, "text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_asgml"(integer, "public"."geometry", integer, integer, "text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_asx3d"(integer, "public"."geometry", integer, integer, "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_asx3d"(integer, "public"."geometry", integer, integer, "text") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_asx3d"(integer, "public"."geometry", integer, integer, "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_asx3d"(integer, "public"."geometry", integer, integer, "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_bestsrid"("public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_bestsrid"("public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_bestsrid"("public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_bestsrid"("public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_bestsrid"("public"."geography", "public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_bestsrid"("public"."geography", "public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_bestsrid"("public"."geography", "public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_bestsrid"("public"."geography", "public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_contains"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_contains"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_contains"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_contains"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_containsproperly"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_containsproperly"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_containsproperly"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_containsproperly"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_coveredby"("geog1" "public"."geography", "geog2" "public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_coveredby"("geog1" "public"."geography", "geog2" "public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_coveredby"("geog1" "public"."geography", "geog2" "public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_coveredby"("geog1" "public"."geography", "geog2" "public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_coveredby"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_coveredby"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_coveredby"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_coveredby"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_covers"("geog1" "public"."geography", "geog2" "public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_covers"("geog1" "public"."geography", "geog2" "public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_covers"("geog1" "public"."geography", "geog2" "public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_covers"("geog1" "public"."geography", "geog2" "public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_covers"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_covers"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_covers"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_covers"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_crosses"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_crosses"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_crosses"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_crosses"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_dfullywithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_dfullywithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."_st_dfullywithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_dfullywithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_distancetree"("public"."geography", "public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_distancetree"("public"."geography", "public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_distancetree"("public"."geography", "public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_distancetree"("public"."geography", "public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_distancetree"("public"."geography", "public"."geography", double precision, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_distancetree"("public"."geography", "public"."geography", double precision, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."_st_distancetree"("public"."geography", "public"."geography", double precision, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_distancetree"("public"."geography", "public"."geography", double precision, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_distanceuncached"("public"."geography", "public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_distanceuncached"("public"."geography", "public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_distanceuncached"("public"."geography", "public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_distanceuncached"("public"."geography", "public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_distanceuncached"("public"."geography", "public"."geography", boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_distanceuncached"("public"."geography", "public"."geography", boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."_st_distanceuncached"("public"."geography", "public"."geography", boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_distanceuncached"("public"."geography", "public"."geography", boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_distanceuncached"("public"."geography", "public"."geography", double precision, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_distanceuncached"("public"."geography", "public"."geography", double precision, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."_st_distanceuncached"("public"."geography", "public"."geography", double precision, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_distanceuncached"("public"."geography", "public"."geography", double precision, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_dwithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_dwithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."_st_dwithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_dwithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_dwithin"("geog1" "public"."geography", "geog2" "public"."geography", "tolerance" double precision, "use_spheroid" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_dwithin"("geog1" "public"."geography", "geog2" "public"."geography", "tolerance" double precision, "use_spheroid" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."_st_dwithin"("geog1" "public"."geography", "geog2" "public"."geography", "tolerance" double precision, "use_spheroid" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_dwithin"("geog1" "public"."geography", "geog2" "public"."geography", "tolerance" double precision, "use_spheroid" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_dwithinuncached"("public"."geography", "public"."geography", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_dwithinuncached"("public"."geography", "public"."geography", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."_st_dwithinuncached"("public"."geography", "public"."geography", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_dwithinuncached"("public"."geography", "public"."geography", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_dwithinuncached"("public"."geography", "public"."geography", double precision, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_dwithinuncached"("public"."geography", "public"."geography", double precision, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."_st_dwithinuncached"("public"."geography", "public"."geography", double precision, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_dwithinuncached"("public"."geography", "public"."geography", double precision, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_equals"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_equals"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_equals"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_equals"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_expand"("public"."geography", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_expand"("public"."geography", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."_st_expand"("public"."geography", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_expand"("public"."geography", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_geomfromgml"("text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_geomfromgml"("text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."_st_geomfromgml"("text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_geomfromgml"("text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_intersects"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_intersects"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_intersects"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_intersects"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_linecrossingdirection"("line1" "public"."geometry", "line2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_linecrossingdirection"("line1" "public"."geometry", "line2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_linecrossingdirection"("line1" "public"."geometry", "line2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_linecrossingdirection"("line1" "public"."geometry", "line2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_longestline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_longestline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_longestline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_longestline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_maxdistance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_maxdistance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_maxdistance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_maxdistance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_orderingequals"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_orderingequals"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_orderingequals"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_orderingequals"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_overlaps"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_overlaps"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_overlaps"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_overlaps"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_pointoutside"("public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_pointoutside"("public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_pointoutside"("public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_pointoutside"("public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_sortablehash"("geom" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_sortablehash"("geom" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_sortablehash"("geom" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_sortablehash"("geom" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_touches"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_touches"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_touches"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_touches"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_voronoi"("g1" "public"."geometry", "clip" "public"."geometry", "tolerance" double precision, "return_polygons" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_voronoi"("g1" "public"."geometry", "clip" "public"."geometry", "tolerance" double precision, "return_polygons" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."_st_voronoi"("g1" "public"."geometry", "clip" "public"."geometry", "tolerance" double precision, "return_polygons" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_voronoi"("g1" "public"."geometry", "clip" "public"."geometry", "tolerance" double precision, "return_polygons" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."_st_within"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."_st_within"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."_st_within"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_st_within"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."abort_dispatch"("p_dispatch_id" "uuid", "p_operator_id" "text", "p_reason" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."abort_dispatch"("p_dispatch_id" "uuid", "p_operator_id" "text", "p_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."abort_dispatch"("p_dispatch_id" "uuid", "p_operator_id" "text", "p_reason" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."addauth"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."addauth"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."addauth"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."addauth"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."addgeometrycolumn"("table_name" character varying, "column_name" character varying, "new_srid" integer, "new_type" character varying, "new_dim" integer, "use_typmod" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."addgeometrycolumn"("table_name" character varying, "column_name" character varying, "new_srid" integer, "new_type" character varying, "new_dim" integer, "use_typmod" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."addgeometrycolumn"("table_name" character varying, "column_name" character varying, "new_srid" integer, "new_type" character varying, "new_dim" integer, "use_typmod" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."addgeometrycolumn"("table_name" character varying, "column_name" character varying, "new_srid" integer, "new_type" character varying, "new_dim" integer, "use_typmod" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."addgeometrycolumn"("schema_name" character varying, "table_name" character varying, "column_name" character varying, "new_srid" integer, "new_type" character varying, "new_dim" integer, "use_typmod" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."addgeometrycolumn"("schema_name" character varying, "table_name" character varying, "column_name" character varying, "new_srid" integer, "new_type" character varying, "new_dim" integer, "use_typmod" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."addgeometrycolumn"("schema_name" character varying, "table_name" character varying, "column_name" character varying, "new_srid" integer, "new_type" character varying, "new_dim" integer, "use_typmod" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."addgeometrycolumn"("schema_name" character varying, "table_name" character varying, "column_name" character varying, "new_srid" integer, "new_type" character varying, "new_dim" integer, "use_typmod" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."addgeometrycolumn"("catalog_name" character varying, "schema_name" character varying, "table_name" character varying, "column_name" character varying, "new_srid_in" integer, "new_type" character varying, "new_dim" integer, "use_typmod" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."addgeometrycolumn"("catalog_name" character varying, "schema_name" character varying, "table_name" character varying, "column_name" character varying, "new_srid_in" integer, "new_type" character varying, "new_dim" integer, "use_typmod" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."addgeometrycolumn"("catalog_name" character varying, "schema_name" character varying, "table_name" character varying, "column_name" character varying, "new_srid_in" integer, "new_type" character varying, "new_dim" integer, "use_typmod" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."addgeometrycolumn"("catalog_name" character varying, "schema_name" character varying, "table_name" character varying, "column_name" character varying, "new_srid_in" integer, "new_type" character varying, "new_dim" integer, "use_typmod" boolean) TO "service_role";



GRANT ALL ON TABLE "public"."guard_ops_retention_runs" TO "anon";
GRANT ALL ON TABLE "public"."guard_ops_retention_runs" TO "authenticated";
GRANT ALL ON TABLE "public"."guard_ops_retention_runs" TO "service_role";



GRANT ALL ON FUNCTION "public"."apply_guard_ops_retention_plan"("projection_keep_days" integer, "synced_operation_keep_days" integer, "guard_ops_keep_days" integer, "note" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."apply_guard_ops_retention_plan"("projection_keep_days" integer, "synced_operation_keep_days" integer, "guard_ops_keep_days" integer, "note" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."apply_guard_ops_retention_plan"("projection_keep_days" integer, "synced_operation_keep_days" integer, "guard_ops_keep_days" integer, "note" "text") TO "service_role";



GRANT ALL ON TABLE "public"."guard_projection_retention_runs" TO "anon";
GRANT ALL ON TABLE "public"."guard_projection_retention_runs" TO "authenticated";
GRANT ALL ON TABLE "public"."guard_projection_retention_runs" TO "service_role";



GRANT ALL ON FUNCTION "public"."apply_guard_projection_retention"("keep_days" integer, "synced_operation_keep_days" integer, "note" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."apply_guard_projection_retention"("keep_days" integer, "synced_operation_keep_days" integer, "note" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."apply_guard_projection_retention"("keep_days" integer, "synced_operation_keep_days" integer, "note" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."apply_site_risk_defaults"() TO "anon";
GRANT ALL ON FUNCTION "public"."apply_site_risk_defaults"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."apply_site_risk_defaults"() TO "service_role";



GRANT ALL ON TABLE "public"."guard_ops_replay_safety_checks" TO "anon";
GRANT ALL ON TABLE "public"."guard_ops_replay_safety_checks" TO "authenticated";
GRANT ALL ON TABLE "public"."guard_ops_replay_safety_checks" TO "service_role";



GRANT ALL ON FUNCTION "public"."assess_guard_ops_replay_safety"("keep_days" integer, "high_volume_event_types" "text"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."assess_guard_ops_replay_safety"("keep_days" integer, "high_volume_event_types" "text"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."assess_guard_ops_replay_safety"("keep_days" integer, "high_volume_event_types" "text"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."box3dtobox"("public"."box3d") TO "postgres";
GRANT ALL ON FUNCTION "public"."box3dtobox"("public"."box3d") TO "anon";
GRANT ALL ON FUNCTION "public"."box3dtobox"("public"."box3d") TO "authenticated";
GRANT ALL ON FUNCTION "public"."box3dtobox"("public"."box3d") TO "service_role";



GRANT ALL ON FUNCTION "public"."capture_incident_snapshot"("p_incident_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."capture_incident_snapshot"("p_incident_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."capture_incident_snapshot"("p_incident_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."checkauth"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."checkauth"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."checkauth"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."checkauth"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."checkauth"("text", "text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."checkauth"("text", "text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."checkauth"("text", "text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."checkauth"("text", "text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."checkauthtrigger"() TO "postgres";
GRANT ALL ON FUNCTION "public"."checkauthtrigger"() TO "anon";
GRANT ALL ON FUNCTION "public"."checkauthtrigger"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."checkauthtrigger"() TO "service_role";



GRANT ALL ON FUNCTION "public"."contains_2d"("public"."box2df", "public"."box2df") TO "postgres";
GRANT ALL ON FUNCTION "public"."contains_2d"("public"."box2df", "public"."box2df") TO "anon";
GRANT ALL ON FUNCTION "public"."contains_2d"("public"."box2df", "public"."box2df") TO "authenticated";
GRANT ALL ON FUNCTION "public"."contains_2d"("public"."box2df", "public"."box2df") TO "service_role";



GRANT ALL ON FUNCTION "public"."contains_2d"("public"."box2df", "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."contains_2d"("public"."box2df", "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."contains_2d"("public"."box2df", "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."contains_2d"("public"."box2df", "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."contains_2d"("public"."geometry", "public"."box2df") TO "postgres";
GRANT ALL ON FUNCTION "public"."contains_2d"("public"."geometry", "public"."box2df") TO "anon";
GRANT ALL ON FUNCTION "public"."contains_2d"("public"."geometry", "public"."box2df") TO "authenticated";
GRANT ALL ON FUNCTION "public"."contains_2d"("public"."geometry", "public"."box2df") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_initial_transition"() TO "anon";
GRANT ALL ON FUNCTION "public"."create_initial_transition"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_initial_transition"() TO "service_role";



GRANT ALL ON FUNCTION "public"."disablelongtransactions"() TO "postgres";
GRANT ALL ON FUNCTION "public"."disablelongtransactions"() TO "anon";
GRANT ALL ON FUNCTION "public"."disablelongtransactions"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."disablelongtransactions"() TO "service_role";



GRANT ALL ON FUNCTION "public"."dropgeometrycolumn"("table_name" character varying, "column_name" character varying) TO "postgres";
GRANT ALL ON FUNCTION "public"."dropgeometrycolumn"("table_name" character varying, "column_name" character varying) TO "anon";
GRANT ALL ON FUNCTION "public"."dropgeometrycolumn"("table_name" character varying, "column_name" character varying) TO "authenticated";
GRANT ALL ON FUNCTION "public"."dropgeometrycolumn"("table_name" character varying, "column_name" character varying) TO "service_role";



GRANT ALL ON FUNCTION "public"."dropgeometrycolumn"("schema_name" character varying, "table_name" character varying, "column_name" character varying) TO "postgres";
GRANT ALL ON FUNCTION "public"."dropgeometrycolumn"("schema_name" character varying, "table_name" character varying, "column_name" character varying) TO "anon";
GRANT ALL ON FUNCTION "public"."dropgeometrycolumn"("schema_name" character varying, "table_name" character varying, "column_name" character varying) TO "authenticated";
GRANT ALL ON FUNCTION "public"."dropgeometrycolumn"("schema_name" character varying, "table_name" character varying, "column_name" character varying) TO "service_role";



GRANT ALL ON FUNCTION "public"."dropgeometrycolumn"("catalog_name" character varying, "schema_name" character varying, "table_name" character varying, "column_name" character varying) TO "postgres";
GRANT ALL ON FUNCTION "public"."dropgeometrycolumn"("catalog_name" character varying, "schema_name" character varying, "table_name" character varying, "column_name" character varying) TO "anon";
GRANT ALL ON FUNCTION "public"."dropgeometrycolumn"("catalog_name" character varying, "schema_name" character varying, "table_name" character varying, "column_name" character varying) TO "authenticated";
GRANT ALL ON FUNCTION "public"."dropgeometrycolumn"("catalog_name" character varying, "schema_name" character varying, "table_name" character varying, "column_name" character varying) TO "service_role";



GRANT ALL ON FUNCTION "public"."dropgeometrytable"("table_name" character varying) TO "postgres";
GRANT ALL ON FUNCTION "public"."dropgeometrytable"("table_name" character varying) TO "anon";
GRANT ALL ON FUNCTION "public"."dropgeometrytable"("table_name" character varying) TO "authenticated";
GRANT ALL ON FUNCTION "public"."dropgeometrytable"("table_name" character varying) TO "service_role";



GRANT ALL ON FUNCTION "public"."dropgeometrytable"("schema_name" character varying, "table_name" character varying) TO "postgres";
GRANT ALL ON FUNCTION "public"."dropgeometrytable"("schema_name" character varying, "table_name" character varying) TO "anon";
GRANT ALL ON FUNCTION "public"."dropgeometrytable"("schema_name" character varying, "table_name" character varying) TO "authenticated";
GRANT ALL ON FUNCTION "public"."dropgeometrytable"("schema_name" character varying, "table_name" character varying) TO "service_role";



GRANT ALL ON FUNCTION "public"."dropgeometrytable"("catalog_name" character varying, "schema_name" character varying, "table_name" character varying) TO "postgres";
GRANT ALL ON FUNCTION "public"."dropgeometrytable"("catalog_name" character varying, "schema_name" character varying, "table_name" character varying) TO "anon";
GRANT ALL ON FUNCTION "public"."dropgeometrytable"("catalog_name" character varying, "schema_name" character varying, "table_name" character varying) TO "authenticated";
GRANT ALL ON FUNCTION "public"."dropgeometrytable"("catalog_name" character varying, "schema_name" character varying, "table_name" character varying) TO "service_role";



GRANT ALL ON FUNCTION "public"."enablelongtransactions"() TO "postgres";
GRANT ALL ON FUNCTION "public"."enablelongtransactions"() TO "anon";
GRANT ALL ON FUNCTION "public"."enablelongtransactions"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."enablelongtransactions"() TO "service_role";



GRANT ALL ON FUNCTION "public"."equals"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."equals"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."equals"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."equals"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."find_srid"(character varying, character varying, character varying) TO "postgres";
GRANT ALL ON FUNCTION "public"."find_srid"(character varying, character varying, character varying) TO "anon";
GRANT ALL ON FUNCTION "public"."find_srid"(character varying, character varying, character varying) TO "authenticated";
GRANT ALL ON FUNCTION "public"."find_srid"(character varying, character varying, character varying) TO "service_role";



GRANT ALL ON FUNCTION "public"."geog_brin_inclusion_add_value"("internal", "internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geog_brin_inclusion_add_value"("internal", "internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geog_brin_inclusion_add_value"("internal", "internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geog_brin_inclusion_add_value"("internal", "internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_cmp"("public"."geography", "public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_cmp"("public"."geography", "public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_cmp"("public"."geography", "public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_cmp"("public"."geography", "public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_distance_knn"("public"."geography", "public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_distance_knn"("public"."geography", "public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_distance_knn"("public"."geography", "public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_distance_knn"("public"."geography", "public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_eq"("public"."geography", "public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_eq"("public"."geography", "public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_eq"("public"."geography", "public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_eq"("public"."geography", "public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_ge"("public"."geography", "public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_ge"("public"."geography", "public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_ge"("public"."geography", "public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_ge"("public"."geography", "public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_gist_compress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_gist_compress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_gist_compress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_gist_compress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_gist_consistent"("internal", "public"."geography", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_gist_consistent"("internal", "public"."geography", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."geography_gist_consistent"("internal", "public"."geography", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_gist_consistent"("internal", "public"."geography", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_gist_decompress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_gist_decompress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_gist_decompress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_gist_decompress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_gist_distance"("internal", "public"."geography", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_gist_distance"("internal", "public"."geography", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."geography_gist_distance"("internal", "public"."geography", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_gist_distance"("internal", "public"."geography", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_gist_penalty"("internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_gist_penalty"("internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_gist_penalty"("internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_gist_penalty"("internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_gist_picksplit"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_gist_picksplit"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_gist_picksplit"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_gist_picksplit"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_gist_same"("public"."box2d", "public"."box2d", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_gist_same"("public"."box2d", "public"."box2d", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_gist_same"("public"."box2d", "public"."box2d", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_gist_same"("public"."box2d", "public"."box2d", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_gist_union"("bytea", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_gist_union"("bytea", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_gist_union"("bytea", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_gist_union"("bytea", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_gt"("public"."geography", "public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_gt"("public"."geography", "public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_gt"("public"."geography", "public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_gt"("public"."geography", "public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_le"("public"."geography", "public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_le"("public"."geography", "public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_le"("public"."geography", "public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_le"("public"."geography", "public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_lt"("public"."geography", "public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_lt"("public"."geography", "public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_lt"("public"."geography", "public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_lt"("public"."geography", "public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_overlaps"("public"."geography", "public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_overlaps"("public"."geography", "public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_overlaps"("public"."geography", "public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_overlaps"("public"."geography", "public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_spgist_choose_nd"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_spgist_choose_nd"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_spgist_choose_nd"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_spgist_choose_nd"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_spgist_compress_nd"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_spgist_compress_nd"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_spgist_compress_nd"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_spgist_compress_nd"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_spgist_config_nd"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_spgist_config_nd"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_spgist_config_nd"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_spgist_config_nd"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_spgist_inner_consistent_nd"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_spgist_inner_consistent_nd"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_spgist_inner_consistent_nd"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_spgist_inner_consistent_nd"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_spgist_leaf_consistent_nd"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_spgist_leaf_consistent_nd"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_spgist_leaf_consistent_nd"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_spgist_leaf_consistent_nd"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geography_spgist_picksplit_nd"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geography_spgist_picksplit_nd"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geography_spgist_picksplit_nd"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geography_spgist_picksplit_nd"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geom2d_brin_inclusion_add_value"("internal", "internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geom2d_brin_inclusion_add_value"("internal", "internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geom2d_brin_inclusion_add_value"("internal", "internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geom2d_brin_inclusion_add_value"("internal", "internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geom3d_brin_inclusion_add_value"("internal", "internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geom3d_brin_inclusion_add_value"("internal", "internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geom3d_brin_inclusion_add_value"("internal", "internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geom3d_brin_inclusion_add_value"("internal", "internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geom4d_brin_inclusion_add_value"("internal", "internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geom4d_brin_inclusion_add_value"("internal", "internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geom4d_brin_inclusion_add_value"("internal", "internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geom4d_brin_inclusion_add_value"("internal", "internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_above"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_above"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_above"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_above"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_below"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_below"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_below"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_below"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_cmp"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_cmp"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_cmp"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_cmp"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_contained_3d"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_contained_3d"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_contained_3d"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_contained_3d"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_contains"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_contains"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_contains"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_contains"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_contains_3d"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_contains_3d"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_contains_3d"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_contains_3d"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_contains_nd"("public"."geometry", "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_contains_nd"("public"."geometry", "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_contains_nd"("public"."geometry", "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_contains_nd"("public"."geometry", "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_distance_box"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_distance_box"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_distance_box"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_distance_box"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_distance_centroid"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_distance_centroid"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_distance_centroid"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_distance_centroid"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_distance_centroid_nd"("public"."geometry", "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_distance_centroid_nd"("public"."geometry", "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_distance_centroid_nd"("public"."geometry", "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_distance_centroid_nd"("public"."geometry", "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_distance_cpa"("public"."geometry", "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_distance_cpa"("public"."geometry", "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_distance_cpa"("public"."geometry", "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_distance_cpa"("public"."geometry", "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_eq"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_eq"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_eq"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_eq"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_ge"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_ge"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_ge"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_ge"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_gist_compress_2d"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_gist_compress_2d"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_gist_compress_2d"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_gist_compress_2d"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_gist_compress_nd"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_gist_compress_nd"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_gist_compress_nd"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_gist_compress_nd"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_gist_consistent_2d"("internal", "public"."geometry", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_gist_consistent_2d"("internal", "public"."geometry", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_gist_consistent_2d"("internal", "public"."geometry", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_gist_consistent_2d"("internal", "public"."geometry", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_gist_consistent_nd"("internal", "public"."geometry", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_gist_consistent_nd"("internal", "public"."geometry", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_gist_consistent_nd"("internal", "public"."geometry", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_gist_consistent_nd"("internal", "public"."geometry", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_gist_decompress_2d"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_gist_decompress_2d"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_gist_decompress_2d"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_gist_decompress_2d"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_gist_decompress_nd"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_gist_decompress_nd"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_gist_decompress_nd"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_gist_decompress_nd"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_gist_distance_2d"("internal", "public"."geometry", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_gist_distance_2d"("internal", "public"."geometry", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_gist_distance_2d"("internal", "public"."geometry", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_gist_distance_2d"("internal", "public"."geometry", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_gist_distance_nd"("internal", "public"."geometry", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_gist_distance_nd"("internal", "public"."geometry", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_gist_distance_nd"("internal", "public"."geometry", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_gist_distance_nd"("internal", "public"."geometry", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_gist_penalty_2d"("internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_gist_penalty_2d"("internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_gist_penalty_2d"("internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_gist_penalty_2d"("internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_gist_penalty_nd"("internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_gist_penalty_nd"("internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_gist_penalty_nd"("internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_gist_penalty_nd"("internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_gist_picksplit_2d"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_gist_picksplit_2d"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_gist_picksplit_2d"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_gist_picksplit_2d"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_gist_picksplit_nd"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_gist_picksplit_nd"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_gist_picksplit_nd"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_gist_picksplit_nd"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_gist_same_2d"("geom1" "public"."geometry", "geom2" "public"."geometry", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_gist_same_2d"("geom1" "public"."geometry", "geom2" "public"."geometry", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_gist_same_2d"("geom1" "public"."geometry", "geom2" "public"."geometry", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_gist_same_2d"("geom1" "public"."geometry", "geom2" "public"."geometry", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_gist_same_nd"("public"."geometry", "public"."geometry", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_gist_same_nd"("public"."geometry", "public"."geometry", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_gist_same_nd"("public"."geometry", "public"."geometry", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_gist_same_nd"("public"."geometry", "public"."geometry", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_gist_sortsupport_2d"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_gist_sortsupport_2d"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_gist_sortsupport_2d"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_gist_sortsupport_2d"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_gist_union_2d"("bytea", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_gist_union_2d"("bytea", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_gist_union_2d"("bytea", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_gist_union_2d"("bytea", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_gist_union_nd"("bytea", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_gist_union_nd"("bytea", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_gist_union_nd"("bytea", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_gist_union_nd"("bytea", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_gt"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_gt"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_gt"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_gt"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_hash"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_hash"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_hash"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_hash"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_le"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_le"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_le"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_le"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_left"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_left"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_left"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_left"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_lt"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_lt"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_lt"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_lt"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_overabove"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_overabove"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_overabove"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_overabove"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_overbelow"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_overbelow"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_overbelow"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_overbelow"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_overlaps"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_overlaps"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_overlaps"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_overlaps"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_overlaps_3d"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_overlaps_3d"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_overlaps_3d"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_overlaps_3d"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_overlaps_nd"("public"."geometry", "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_overlaps_nd"("public"."geometry", "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_overlaps_nd"("public"."geometry", "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_overlaps_nd"("public"."geometry", "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_overleft"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_overleft"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_overleft"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_overleft"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_overright"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_overright"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_overright"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_overright"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_right"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_right"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_right"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_right"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_same"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_same"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_same"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_same"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_same_3d"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_same_3d"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_same_3d"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_same_3d"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_same_nd"("public"."geometry", "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_same_nd"("public"."geometry", "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_same_nd"("public"."geometry", "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_same_nd"("public"."geometry", "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_sortsupport"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_sortsupport"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_sortsupport"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_sortsupport"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_spgist_choose_2d"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_spgist_choose_2d"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_spgist_choose_2d"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_spgist_choose_2d"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_spgist_choose_3d"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_spgist_choose_3d"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_spgist_choose_3d"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_spgist_choose_3d"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_spgist_choose_nd"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_spgist_choose_nd"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_spgist_choose_nd"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_spgist_choose_nd"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_spgist_compress_2d"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_spgist_compress_2d"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_spgist_compress_2d"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_spgist_compress_2d"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_spgist_compress_3d"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_spgist_compress_3d"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_spgist_compress_3d"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_spgist_compress_3d"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_spgist_compress_nd"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_spgist_compress_nd"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_spgist_compress_nd"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_spgist_compress_nd"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_spgist_config_2d"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_spgist_config_2d"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_spgist_config_2d"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_spgist_config_2d"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_spgist_config_3d"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_spgist_config_3d"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_spgist_config_3d"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_spgist_config_3d"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_spgist_config_nd"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_spgist_config_nd"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_spgist_config_nd"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_spgist_config_nd"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_spgist_inner_consistent_2d"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_spgist_inner_consistent_2d"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_spgist_inner_consistent_2d"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_spgist_inner_consistent_2d"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_spgist_inner_consistent_3d"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_spgist_inner_consistent_3d"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_spgist_inner_consistent_3d"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_spgist_inner_consistent_3d"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_spgist_inner_consistent_nd"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_spgist_inner_consistent_nd"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_spgist_inner_consistent_nd"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_spgist_inner_consistent_nd"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_spgist_leaf_consistent_2d"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_spgist_leaf_consistent_2d"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_spgist_leaf_consistent_2d"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_spgist_leaf_consistent_2d"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_spgist_leaf_consistent_3d"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_spgist_leaf_consistent_3d"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_spgist_leaf_consistent_3d"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_spgist_leaf_consistent_3d"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_spgist_leaf_consistent_nd"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_spgist_leaf_consistent_nd"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_spgist_leaf_consistent_nd"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_spgist_leaf_consistent_nd"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_spgist_picksplit_2d"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_spgist_picksplit_2d"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_spgist_picksplit_2d"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_spgist_picksplit_2d"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_spgist_picksplit_3d"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_spgist_picksplit_3d"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_spgist_picksplit_3d"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_spgist_picksplit_3d"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_spgist_picksplit_nd"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_spgist_picksplit_nd"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_spgist_picksplit_nd"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_spgist_picksplit_nd"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_within"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_within"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_within"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_within"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometry_within_nd"("public"."geometry", "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometry_within_nd"("public"."geometry", "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometry_within_nd"("public"."geometry", "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometry_within_nd"("public"."geometry", "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometrytype"("public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometrytype"("public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."geometrytype"("public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometrytype"("public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."geometrytype"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."geometrytype"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."geometrytype"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geometrytype"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."geomfromewkb"("bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."geomfromewkb"("bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."geomfromewkb"("bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geomfromewkb"("bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."geomfromewkt"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."geomfromewkt"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."geomfromewkt"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."geomfromewkt"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_proj4_from_srid"(integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."get_proj4_from_srid"(integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_proj4_from_srid"(integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_proj4_from_srid"(integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."gettransactionid"() TO "postgres";
GRANT ALL ON FUNCTION "public"."gettransactionid"() TO "anon";
GRANT ALL ON FUNCTION "public"."gettransactionid"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."gettransactionid"() TO "service_role";



GRANT ALL ON FUNCTION "public"."gserialized_gist_joinsel_2d"("internal", "oid", "internal", smallint) TO "postgres";
GRANT ALL ON FUNCTION "public"."gserialized_gist_joinsel_2d"("internal", "oid", "internal", smallint) TO "anon";
GRANT ALL ON FUNCTION "public"."gserialized_gist_joinsel_2d"("internal", "oid", "internal", smallint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."gserialized_gist_joinsel_2d"("internal", "oid", "internal", smallint) TO "service_role";



GRANT ALL ON FUNCTION "public"."gserialized_gist_joinsel_nd"("internal", "oid", "internal", smallint) TO "postgres";
GRANT ALL ON FUNCTION "public"."gserialized_gist_joinsel_nd"("internal", "oid", "internal", smallint) TO "anon";
GRANT ALL ON FUNCTION "public"."gserialized_gist_joinsel_nd"("internal", "oid", "internal", smallint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."gserialized_gist_joinsel_nd"("internal", "oid", "internal", smallint) TO "service_role";



GRANT ALL ON FUNCTION "public"."gserialized_gist_sel_2d"("internal", "oid", "internal", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."gserialized_gist_sel_2d"("internal", "oid", "internal", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."gserialized_gist_sel_2d"("internal", "oid", "internal", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."gserialized_gist_sel_2d"("internal", "oid", "internal", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."gserialized_gist_sel_nd"("internal", "oid", "internal", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."gserialized_gist_sel_nd"("internal", "oid", "internal", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."gserialized_gist_sel_nd"("internal", "oid", "internal", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."gserialized_gist_sel_nd"("internal", "oid", "internal", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."guard_ops_events_reject_mutation"() TO "anon";
GRANT ALL ON FUNCTION "public"."guard_ops_events_reject_mutation"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."guard_ops_events_reject_mutation"() TO "service_role";



GRANT ALL ON FUNCTION "public"."incidents_lock_closed_rows"() TO "anon";
GRANT ALL ON FUNCTION "public"."incidents_lock_closed_rows"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."incidents_lock_closed_rows"() TO "service_role";



GRANT ALL ON FUNCTION "public"."is_contained_2d"("public"."box2df", "public"."box2df") TO "postgres";
GRANT ALL ON FUNCTION "public"."is_contained_2d"("public"."box2df", "public"."box2df") TO "anon";
GRANT ALL ON FUNCTION "public"."is_contained_2d"("public"."box2df", "public"."box2df") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_contained_2d"("public"."box2df", "public"."box2df") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_contained_2d"("public"."box2df", "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."is_contained_2d"("public"."box2df", "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."is_contained_2d"("public"."box2df", "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_contained_2d"("public"."box2df", "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_contained_2d"("public"."geometry", "public"."box2df") TO "postgres";
GRANT ALL ON FUNCTION "public"."is_contained_2d"("public"."geometry", "public"."box2df") TO "anon";
GRANT ALL ON FUNCTION "public"."is_contained_2d"("public"."geometry", "public"."box2df") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_contained_2d"("public"."geometry", "public"."box2df") TO "service_role";



GRANT ALL ON FUNCTION "public"."lockrow"("text", "text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."lockrow"("text", "text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."lockrow"("text", "text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."lockrow"("text", "text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."lockrow"("text", "text", "text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."lockrow"("text", "text", "text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."lockrow"("text", "text", "text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."lockrow"("text", "text", "text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."lockrow"("text", "text", "text", timestamp without time zone) TO "postgres";
GRANT ALL ON FUNCTION "public"."lockrow"("text", "text", "text", timestamp without time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."lockrow"("text", "text", "text", timestamp without time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."lockrow"("text", "text", "text", timestamp without time zone) TO "service_role";



GRANT ALL ON FUNCTION "public"."lockrow"("text", "text", "text", "text", timestamp without time zone) TO "postgres";
GRANT ALL ON FUNCTION "public"."lockrow"("text", "text", "text", "text", timestamp without time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."lockrow"("text", "text", "text", "text", timestamp without time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."lockrow"("text", "text", "text", "text", timestamp without time zone) TO "service_role";



GRANT ALL ON FUNCTION "public"."longtransactionsenabled"() TO "postgres";
GRANT ALL ON FUNCTION "public"."longtransactionsenabled"() TO "anon";
GRANT ALL ON FUNCTION "public"."longtransactionsenabled"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."longtransactionsenabled"() TO "service_role";



GRANT ALL ON FUNCTION "public"."mark_missed_patrols"() TO "anon";
GRANT ALL ON FUNCTION "public"."mark_missed_patrols"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."mark_missed_patrols"() TO "service_role";



GRANT ALL ON FUNCTION "public"."onyx_client_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."onyx_client_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."onyx_client_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."onyx_guard_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."onyx_guard_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."onyx_guard_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."onyx_has_site"("target_site_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."onyx_has_site"("target_site_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."onyx_has_site"("target_site_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."onyx_is_control_role"() TO "anon";
GRANT ALL ON FUNCTION "public"."onyx_is_control_role"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."onyx_is_control_role"() TO "service_role";



GRANT ALL ON FUNCTION "public"."onyx_role_type"() TO "anon";
GRANT ALL ON FUNCTION "public"."onyx_role_type"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."onyx_role_type"() TO "service_role";



GRANT ALL ON FUNCTION "public"."overlaps_2d"("public"."box2df", "public"."box2df") TO "postgres";
GRANT ALL ON FUNCTION "public"."overlaps_2d"("public"."box2df", "public"."box2df") TO "anon";
GRANT ALL ON FUNCTION "public"."overlaps_2d"("public"."box2df", "public"."box2df") TO "authenticated";
GRANT ALL ON FUNCTION "public"."overlaps_2d"("public"."box2df", "public"."box2df") TO "service_role";



GRANT ALL ON FUNCTION "public"."overlaps_2d"("public"."box2df", "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."overlaps_2d"("public"."box2df", "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."overlaps_2d"("public"."box2df", "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."overlaps_2d"("public"."box2df", "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."overlaps_2d"("public"."geometry", "public"."box2df") TO "postgres";
GRANT ALL ON FUNCTION "public"."overlaps_2d"("public"."geometry", "public"."box2df") TO "anon";
GRANT ALL ON FUNCTION "public"."overlaps_2d"("public"."geometry", "public"."box2df") TO "authenticated";
GRANT ALL ON FUNCTION "public"."overlaps_2d"("public"."geometry", "public"."box2df") TO "service_role";



GRANT ALL ON FUNCTION "public"."overlaps_geog"("public"."geography", "public"."gidx") TO "postgres";
GRANT ALL ON FUNCTION "public"."overlaps_geog"("public"."geography", "public"."gidx") TO "anon";
GRANT ALL ON FUNCTION "public"."overlaps_geog"("public"."geography", "public"."gidx") TO "authenticated";
GRANT ALL ON FUNCTION "public"."overlaps_geog"("public"."geography", "public"."gidx") TO "service_role";



GRANT ALL ON FUNCTION "public"."overlaps_geog"("public"."gidx", "public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."overlaps_geog"("public"."gidx", "public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."overlaps_geog"("public"."gidx", "public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."overlaps_geog"("public"."gidx", "public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."overlaps_geog"("public"."gidx", "public"."gidx") TO "postgres";
GRANT ALL ON FUNCTION "public"."overlaps_geog"("public"."gidx", "public"."gidx") TO "anon";
GRANT ALL ON FUNCTION "public"."overlaps_geog"("public"."gidx", "public"."gidx") TO "authenticated";
GRANT ALL ON FUNCTION "public"."overlaps_geog"("public"."gidx", "public"."gidx") TO "service_role";



GRANT ALL ON FUNCTION "public"."overlaps_nd"("public"."geometry", "public"."gidx") TO "postgres";
GRANT ALL ON FUNCTION "public"."overlaps_nd"("public"."geometry", "public"."gidx") TO "anon";
GRANT ALL ON FUNCTION "public"."overlaps_nd"("public"."geometry", "public"."gidx") TO "authenticated";
GRANT ALL ON FUNCTION "public"."overlaps_nd"("public"."geometry", "public"."gidx") TO "service_role";



GRANT ALL ON FUNCTION "public"."overlaps_nd"("public"."gidx", "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."overlaps_nd"("public"."gidx", "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."overlaps_nd"("public"."gidx", "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."overlaps_nd"("public"."gidx", "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."overlaps_nd"("public"."gidx", "public"."gidx") TO "postgres";
GRANT ALL ON FUNCTION "public"."overlaps_nd"("public"."gidx", "public"."gidx") TO "anon";
GRANT ALL ON FUNCTION "public"."overlaps_nd"("public"."gidx", "public"."gidx") TO "authenticated";
GRANT ALL ON FUNCTION "public"."overlaps_nd"("public"."gidx", "public"."gidx") TO "service_role";



GRANT ALL ON FUNCTION "public"."override_dispatch"("p_dispatch_id" "uuid", "p_operator_id" "text", "p_reason" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."override_dispatch"("p_dispatch_id" "uuid", "p_operator_id" "text", "p_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."override_dispatch"("p_dispatch_id" "uuid", "p_operator_id" "text", "p_reason" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_asflatgeobuf_finalfn"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_asflatgeobuf_finalfn"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_asflatgeobuf_finalfn"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_asflatgeobuf_finalfn"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_asflatgeobuf_transfn"("internal", "anyelement") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_asflatgeobuf_transfn"("internal", "anyelement") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_asflatgeobuf_transfn"("internal", "anyelement") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_asflatgeobuf_transfn"("internal", "anyelement") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_asflatgeobuf_transfn"("internal", "anyelement", boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_asflatgeobuf_transfn"("internal", "anyelement", boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_asflatgeobuf_transfn"("internal", "anyelement", boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_asflatgeobuf_transfn"("internal", "anyelement", boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_asflatgeobuf_transfn"("internal", "anyelement", boolean, "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_asflatgeobuf_transfn"("internal", "anyelement", boolean, "text") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_asflatgeobuf_transfn"("internal", "anyelement", boolean, "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_asflatgeobuf_transfn"("internal", "anyelement", boolean, "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_asgeobuf_finalfn"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_asgeobuf_finalfn"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_asgeobuf_finalfn"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_asgeobuf_finalfn"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_asgeobuf_transfn"("internal", "anyelement") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_asgeobuf_transfn"("internal", "anyelement") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_asgeobuf_transfn"("internal", "anyelement") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_asgeobuf_transfn"("internal", "anyelement") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_asgeobuf_transfn"("internal", "anyelement", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_asgeobuf_transfn"("internal", "anyelement", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_asgeobuf_transfn"("internal", "anyelement", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_asgeobuf_transfn"("internal", "anyelement", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_asmvt_combinefn"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_combinefn"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_combinefn"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_combinefn"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_asmvt_deserialfn"("bytea", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_deserialfn"("bytea", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_deserialfn"("bytea", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_deserialfn"("bytea", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_asmvt_finalfn"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_finalfn"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_finalfn"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_finalfn"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_asmvt_serialfn"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_serialfn"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_serialfn"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_serialfn"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_asmvt_transfn"("internal", "anyelement") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_transfn"("internal", "anyelement") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_transfn"("internal", "anyelement") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_transfn"("internal", "anyelement") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_asmvt_transfn"("internal", "anyelement", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_transfn"("internal", "anyelement", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_transfn"("internal", "anyelement", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_transfn"("internal", "anyelement", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_asmvt_transfn"("internal", "anyelement", "text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_transfn"("internal", "anyelement", "text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_transfn"("internal", "anyelement", "text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_transfn"("internal", "anyelement", "text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_asmvt_transfn"("internal", "anyelement", "text", integer, "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_transfn"("internal", "anyelement", "text", integer, "text") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_transfn"("internal", "anyelement", "text", integer, "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_transfn"("internal", "anyelement", "text", integer, "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_asmvt_transfn"("internal", "anyelement", "text", integer, "text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_transfn"("internal", "anyelement", "text", integer, "text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_transfn"("internal", "anyelement", "text", integer, "text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_asmvt_transfn"("internal", "anyelement", "text", integer, "text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_geometry_accum_transfn"("internal", "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_geometry_accum_transfn"("internal", "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_geometry_accum_transfn"("internal", "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_geometry_accum_transfn"("internal", "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_geometry_accum_transfn"("internal", "public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_geometry_accum_transfn"("internal", "public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_geometry_accum_transfn"("internal", "public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_geometry_accum_transfn"("internal", "public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_geometry_accum_transfn"("internal", "public"."geometry", double precision, integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_geometry_accum_transfn"("internal", "public"."geometry", double precision, integer) TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_geometry_accum_transfn"("internal", "public"."geometry", double precision, integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_geometry_accum_transfn"("internal", "public"."geometry", double precision, integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_geometry_clusterintersecting_finalfn"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_geometry_clusterintersecting_finalfn"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_geometry_clusterintersecting_finalfn"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_geometry_clusterintersecting_finalfn"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_geometry_clusterwithin_finalfn"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_geometry_clusterwithin_finalfn"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_geometry_clusterwithin_finalfn"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_geometry_clusterwithin_finalfn"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_geometry_collect_finalfn"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_geometry_collect_finalfn"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_geometry_collect_finalfn"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_geometry_collect_finalfn"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_geometry_makeline_finalfn"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_geometry_makeline_finalfn"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_geometry_makeline_finalfn"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_geometry_makeline_finalfn"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_geometry_polygonize_finalfn"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_geometry_polygonize_finalfn"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_geometry_polygonize_finalfn"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_geometry_polygonize_finalfn"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_combinefn"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_combinefn"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_combinefn"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_combinefn"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_deserialfn"("bytea", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_deserialfn"("bytea", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_deserialfn"("bytea", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_deserialfn"("bytea", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_finalfn"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_finalfn"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_finalfn"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_finalfn"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_serialfn"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_serialfn"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_serialfn"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_serialfn"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_transfn"("internal", "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_transfn"("internal", "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_transfn"("internal", "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_transfn"("internal", "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_transfn"("internal", "public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_transfn"("internal", "public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_transfn"("internal", "public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."pgis_geometry_union_parallel_transfn"("internal", "public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."populate_geometry_columns"("use_typmod" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."populate_geometry_columns"("use_typmod" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."populate_geometry_columns"("use_typmod" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."populate_geometry_columns"("use_typmod" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."populate_geometry_columns"("tbl_oid" "oid", "use_typmod" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."populate_geometry_columns"("tbl_oid" "oid", "use_typmod" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."populate_geometry_columns"("tbl_oid" "oid", "use_typmod" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."populate_geometry_columns"("tbl_oid" "oid", "use_typmod" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_addbbox"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_addbbox"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_addbbox"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_addbbox"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_cache_bbox"() TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_cache_bbox"() TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_cache_bbox"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_cache_bbox"() TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_constraint_dims"("geomschema" "text", "geomtable" "text", "geomcolumn" "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_constraint_dims"("geomschema" "text", "geomtable" "text", "geomcolumn" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_constraint_dims"("geomschema" "text", "geomtable" "text", "geomcolumn" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_constraint_dims"("geomschema" "text", "geomtable" "text", "geomcolumn" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_constraint_srid"("geomschema" "text", "geomtable" "text", "geomcolumn" "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_constraint_srid"("geomschema" "text", "geomtable" "text", "geomcolumn" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_constraint_srid"("geomschema" "text", "geomtable" "text", "geomcolumn" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_constraint_srid"("geomschema" "text", "geomtable" "text", "geomcolumn" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_constraint_type"("geomschema" "text", "geomtable" "text", "geomcolumn" "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_constraint_type"("geomschema" "text", "geomtable" "text", "geomcolumn" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_constraint_type"("geomschema" "text", "geomtable" "text", "geomcolumn" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_constraint_type"("geomschema" "text", "geomtable" "text", "geomcolumn" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_dropbbox"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_dropbbox"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_dropbbox"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_dropbbox"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_extensions_upgrade"() TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_extensions_upgrade"() TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_extensions_upgrade"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_extensions_upgrade"() TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_full_version"() TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_full_version"() TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_full_version"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_full_version"() TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_geos_noop"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_geos_noop"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_geos_noop"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_geos_noop"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_geos_version"() TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_geos_version"() TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_geos_version"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_geos_version"() TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_getbbox"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_getbbox"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_getbbox"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_getbbox"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_hasbbox"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_hasbbox"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_hasbbox"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_hasbbox"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_index_supportfn"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_index_supportfn"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_index_supportfn"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_index_supportfn"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_lib_build_date"() TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_lib_build_date"() TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_lib_build_date"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_lib_build_date"() TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_lib_revision"() TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_lib_revision"() TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_lib_revision"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_lib_revision"() TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_lib_version"() TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_lib_version"() TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_lib_version"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_lib_version"() TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_libjson_version"() TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_libjson_version"() TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_libjson_version"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_libjson_version"() TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_liblwgeom_version"() TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_liblwgeom_version"() TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_liblwgeom_version"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_liblwgeom_version"() TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_libprotobuf_version"() TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_libprotobuf_version"() TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_libprotobuf_version"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_libprotobuf_version"() TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_libxml_version"() TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_libxml_version"() TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_libxml_version"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_libxml_version"() TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_noop"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_noop"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_noop"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_noop"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_proj_version"() TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_proj_version"() TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_proj_version"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_proj_version"() TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_scripts_build_date"() TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_scripts_build_date"() TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_scripts_build_date"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_scripts_build_date"() TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_scripts_installed"() TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_scripts_installed"() TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_scripts_installed"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_scripts_installed"() TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_scripts_released"() TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_scripts_released"() TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_scripts_released"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_scripts_released"() TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_svn_version"() TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_svn_version"() TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_svn_version"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_svn_version"() TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_transform_geometry"("geom" "public"."geometry", "text", "text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_transform_geometry"("geom" "public"."geometry", "text", "text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_transform_geometry"("geom" "public"."geometry", "text", "text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_transform_geometry"("geom" "public"."geometry", "text", "text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_type_name"("geomname" character varying, "coord_dimension" integer, "use_new_name" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_type_name"("geomname" character varying, "coord_dimension" integer, "use_new_name" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_type_name"("geomname" character varying, "coord_dimension" integer, "use_new_name" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_type_name"("geomname" character varying, "coord_dimension" integer, "use_new_name" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_typmod_dims"(integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_typmod_dims"(integer) TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_typmod_dims"(integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_typmod_dims"(integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_typmod_srid"(integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_typmod_srid"(integer) TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_typmod_srid"(integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_typmod_srid"(integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_typmod_type"(integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_typmod_type"(integer) TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_typmod_type"(integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_typmod_type"(integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_version"() TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_version"() TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_version"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_version"() TO "service_role";



GRANT ALL ON FUNCTION "public"."postgis_wagyu_version"() TO "postgres";
GRANT ALL ON FUNCTION "public"."postgis_wagyu_version"() TO "anon";
GRANT ALL ON FUNCTION "public"."postgis_wagyu_version"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."postgis_wagyu_version"() TO "service_role";



GRANT ALL ON FUNCTION "public"."process_patrol_lifecycle"() TO "anon";
GRANT ALL ON FUNCTION "public"."process_patrol_lifecycle"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."process_patrol_lifecycle"() TO "service_role";



GRANT ALL ON FUNCTION "public"."promote_to_committing"("p_dispatch_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."promote_to_committing"("p_dispatch_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."promote_to_committing"("p_dispatch_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."promote_to_executed_if_ready"("p_dispatch_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."promote_to_executed_if_ready"("p_dispatch_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."promote_to_executed_if_ready"("p_dispatch_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."purge_old_events"() TO "anon";
GRANT ALL ON FUNCTION "public"."purge_old_events"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."purge_old_events"() TO "service_role";



GRANT ALL ON FUNCTION "public"."run_intel_scoring"() TO "anon";
GRANT ALL ON FUNCTION "public"."run_intel_scoring"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."run_intel_scoring"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_client_conversation_push_queue_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_client_conversation_push_queue_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_client_conversation_push_queue_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_client_conversation_push_sync_state_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_client_conversation_push_sync_state_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_client_conversation_push_sync_state_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_client_conversation_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_client_conversation_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_client_conversation_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_guard_directory_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_guard_directory_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_guard_directory_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_guard_ops_media_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_guard_ops_media_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_guard_ops_media_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_guard_sync_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_guard_sync_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_guard_sync_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_timestamp"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_timestamp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_timestamp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."st_3dclosestpoint"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_3dclosestpoint"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_3dclosestpoint"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_3dclosestpoint"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_3ddfullywithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_3ddfullywithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_3ddfullywithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_3ddfullywithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_3ddistance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_3ddistance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_3ddistance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_3ddistance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_3ddwithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_3ddwithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_3ddwithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_3ddwithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_3dintersects"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_3dintersects"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_3dintersects"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_3dintersects"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_3dlength"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_3dlength"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_3dlength"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_3dlength"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_3dlineinterpolatepoint"("public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_3dlineinterpolatepoint"("public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_3dlineinterpolatepoint"("public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_3dlineinterpolatepoint"("public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_3dlongestline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_3dlongestline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_3dlongestline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_3dlongestline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_3dmakebox"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_3dmakebox"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_3dmakebox"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_3dmakebox"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_3dmaxdistance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_3dmaxdistance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_3dmaxdistance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_3dmaxdistance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_3dperimeter"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_3dperimeter"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_3dperimeter"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_3dperimeter"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_3dshortestline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_3dshortestline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_3dshortestline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_3dshortestline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_addmeasure"("public"."geometry", double precision, double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_addmeasure"("public"."geometry", double precision, double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_addmeasure"("public"."geometry", double precision, double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_addmeasure"("public"."geometry", double precision, double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_addpoint"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_addpoint"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_addpoint"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_addpoint"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_addpoint"("geom1" "public"."geometry", "geom2" "public"."geometry", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_addpoint"("geom1" "public"."geometry", "geom2" "public"."geometry", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_addpoint"("geom1" "public"."geometry", "geom2" "public"."geometry", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_addpoint"("geom1" "public"."geometry", "geom2" "public"."geometry", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_affine"("public"."geometry", double precision, double precision, double precision, double precision, double precision, double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_affine"("public"."geometry", double precision, double precision, double precision, double precision, double precision, double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_affine"("public"."geometry", double precision, double precision, double precision, double precision, double precision, double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_affine"("public"."geometry", double precision, double precision, double precision, double precision, double precision, double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_affine"("public"."geometry", double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_affine"("public"."geometry", double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_affine"("public"."geometry", double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_affine"("public"."geometry", double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_angle"("line1" "public"."geometry", "line2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_angle"("line1" "public"."geometry", "line2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_angle"("line1" "public"."geometry", "line2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_angle"("line1" "public"."geometry", "line2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_angle"("pt1" "public"."geometry", "pt2" "public"."geometry", "pt3" "public"."geometry", "pt4" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_angle"("pt1" "public"."geometry", "pt2" "public"."geometry", "pt3" "public"."geometry", "pt4" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_angle"("pt1" "public"."geometry", "pt2" "public"."geometry", "pt3" "public"."geometry", "pt4" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_angle"("pt1" "public"."geometry", "pt2" "public"."geometry", "pt3" "public"."geometry", "pt4" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_area"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_area"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_area"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_area"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_area"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_area"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_area"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_area"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_area"("geog" "public"."geography", "use_spheroid" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_area"("geog" "public"."geography", "use_spheroid" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_area"("geog" "public"."geography", "use_spheroid" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_area"("geog" "public"."geography", "use_spheroid" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_area2d"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_area2d"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_area2d"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_area2d"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asbinary"("public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asbinary"("public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asbinary"("public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asbinary"("public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asbinary"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asbinary"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asbinary"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asbinary"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asbinary"("public"."geography", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asbinary"("public"."geography", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asbinary"("public"."geography", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asbinary"("public"."geography", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asbinary"("public"."geometry", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asbinary"("public"."geometry", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asbinary"("public"."geometry", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asbinary"("public"."geometry", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asencodedpolyline"("geom" "public"."geometry", "nprecision" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asencodedpolyline"("geom" "public"."geometry", "nprecision" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_asencodedpolyline"("geom" "public"."geometry", "nprecision" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asencodedpolyline"("geom" "public"."geometry", "nprecision" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asewkb"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asewkb"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asewkb"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asewkb"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asewkb"("public"."geometry", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asewkb"("public"."geometry", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asewkb"("public"."geometry", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asewkb"("public"."geometry", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asewkt"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asewkt"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asewkt"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asewkt"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asewkt"("public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asewkt"("public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asewkt"("public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asewkt"("public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asewkt"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asewkt"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asewkt"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asewkt"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asewkt"("public"."geography", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asewkt"("public"."geography", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_asewkt"("public"."geography", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asewkt"("public"."geography", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asewkt"("public"."geometry", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asewkt"("public"."geometry", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_asewkt"("public"."geometry", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asewkt"("public"."geometry", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asgeojson"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asgeojson"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asgeojson"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asgeojson"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asgeojson"("geog" "public"."geography", "maxdecimaldigits" integer, "options" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asgeojson"("geog" "public"."geography", "maxdecimaldigits" integer, "options" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_asgeojson"("geog" "public"."geography", "maxdecimaldigits" integer, "options" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asgeojson"("geog" "public"."geography", "maxdecimaldigits" integer, "options" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asgeojson"("geom" "public"."geometry", "maxdecimaldigits" integer, "options" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asgeojson"("geom" "public"."geometry", "maxdecimaldigits" integer, "options" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_asgeojson"("geom" "public"."geometry", "maxdecimaldigits" integer, "options" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asgeojson"("geom" "public"."geometry", "maxdecimaldigits" integer, "options" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asgeojson"("r" "record", "geom_column" "text", "maxdecimaldigits" integer, "pretty_bool" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asgeojson"("r" "record", "geom_column" "text", "maxdecimaldigits" integer, "pretty_bool" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_asgeojson"("r" "record", "geom_column" "text", "maxdecimaldigits" integer, "pretty_bool" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asgeojson"("r" "record", "geom_column" "text", "maxdecimaldigits" integer, "pretty_bool" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asgml"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asgml"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asgml"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asgml"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asgml"("geom" "public"."geometry", "maxdecimaldigits" integer, "options" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asgml"("geom" "public"."geometry", "maxdecimaldigits" integer, "options" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_asgml"("geom" "public"."geometry", "maxdecimaldigits" integer, "options" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asgml"("geom" "public"."geometry", "maxdecimaldigits" integer, "options" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asgml"("geog" "public"."geography", "maxdecimaldigits" integer, "options" integer, "nprefix" "text", "id" "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asgml"("geog" "public"."geography", "maxdecimaldigits" integer, "options" integer, "nprefix" "text", "id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asgml"("geog" "public"."geography", "maxdecimaldigits" integer, "options" integer, "nprefix" "text", "id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asgml"("geog" "public"."geography", "maxdecimaldigits" integer, "options" integer, "nprefix" "text", "id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asgml"("version" integer, "geog" "public"."geography", "maxdecimaldigits" integer, "options" integer, "nprefix" "text", "id" "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asgml"("version" integer, "geog" "public"."geography", "maxdecimaldigits" integer, "options" integer, "nprefix" "text", "id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asgml"("version" integer, "geog" "public"."geography", "maxdecimaldigits" integer, "options" integer, "nprefix" "text", "id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asgml"("version" integer, "geog" "public"."geography", "maxdecimaldigits" integer, "options" integer, "nprefix" "text", "id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asgml"("version" integer, "geom" "public"."geometry", "maxdecimaldigits" integer, "options" integer, "nprefix" "text", "id" "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asgml"("version" integer, "geom" "public"."geometry", "maxdecimaldigits" integer, "options" integer, "nprefix" "text", "id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asgml"("version" integer, "geom" "public"."geometry", "maxdecimaldigits" integer, "options" integer, "nprefix" "text", "id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asgml"("version" integer, "geom" "public"."geometry", "maxdecimaldigits" integer, "options" integer, "nprefix" "text", "id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_ashexewkb"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_ashexewkb"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_ashexewkb"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_ashexewkb"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_ashexewkb"("public"."geometry", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_ashexewkb"("public"."geometry", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_ashexewkb"("public"."geometry", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_ashexewkb"("public"."geometry", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_askml"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_askml"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_askml"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_askml"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_askml"("geog" "public"."geography", "maxdecimaldigits" integer, "nprefix" "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_askml"("geog" "public"."geography", "maxdecimaldigits" integer, "nprefix" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_askml"("geog" "public"."geography", "maxdecimaldigits" integer, "nprefix" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_askml"("geog" "public"."geography", "maxdecimaldigits" integer, "nprefix" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_askml"("geom" "public"."geometry", "maxdecimaldigits" integer, "nprefix" "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_askml"("geom" "public"."geometry", "maxdecimaldigits" integer, "nprefix" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_askml"("geom" "public"."geometry", "maxdecimaldigits" integer, "nprefix" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_askml"("geom" "public"."geometry", "maxdecimaldigits" integer, "nprefix" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_aslatlontext"("geom" "public"."geometry", "tmpl" "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_aslatlontext"("geom" "public"."geometry", "tmpl" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_aslatlontext"("geom" "public"."geometry", "tmpl" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_aslatlontext"("geom" "public"."geometry", "tmpl" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asmarc21"("geom" "public"."geometry", "format" "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asmarc21"("geom" "public"."geometry", "format" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asmarc21"("geom" "public"."geometry", "format" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asmarc21"("geom" "public"."geometry", "format" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asmvtgeom"("geom" "public"."geometry", "bounds" "public"."box2d", "extent" integer, "buffer" integer, "clip_geom" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asmvtgeom"("geom" "public"."geometry", "bounds" "public"."box2d", "extent" integer, "buffer" integer, "clip_geom" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_asmvtgeom"("geom" "public"."geometry", "bounds" "public"."box2d", "extent" integer, "buffer" integer, "clip_geom" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asmvtgeom"("geom" "public"."geometry", "bounds" "public"."box2d", "extent" integer, "buffer" integer, "clip_geom" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_assvg"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_assvg"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_assvg"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_assvg"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_assvg"("geog" "public"."geography", "rel" integer, "maxdecimaldigits" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_assvg"("geog" "public"."geography", "rel" integer, "maxdecimaldigits" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_assvg"("geog" "public"."geography", "rel" integer, "maxdecimaldigits" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_assvg"("geog" "public"."geography", "rel" integer, "maxdecimaldigits" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_assvg"("geom" "public"."geometry", "rel" integer, "maxdecimaldigits" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_assvg"("geom" "public"."geometry", "rel" integer, "maxdecimaldigits" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_assvg"("geom" "public"."geometry", "rel" integer, "maxdecimaldigits" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_assvg"("geom" "public"."geometry", "rel" integer, "maxdecimaldigits" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_astext"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_astext"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_astext"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_astext"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_astext"("public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_astext"("public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."st_astext"("public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_astext"("public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_astext"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_astext"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_astext"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_astext"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_astext"("public"."geography", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_astext"("public"."geography", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_astext"("public"."geography", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_astext"("public"."geography", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_astext"("public"."geometry", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_astext"("public"."geometry", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_astext"("public"."geometry", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_astext"("public"."geometry", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_astwkb"("geom" "public"."geometry", "prec" integer, "prec_z" integer, "prec_m" integer, "with_sizes" boolean, "with_boxes" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_astwkb"("geom" "public"."geometry", "prec" integer, "prec_z" integer, "prec_m" integer, "with_sizes" boolean, "with_boxes" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_astwkb"("geom" "public"."geometry", "prec" integer, "prec_z" integer, "prec_m" integer, "with_sizes" boolean, "with_boxes" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_astwkb"("geom" "public"."geometry", "prec" integer, "prec_z" integer, "prec_m" integer, "with_sizes" boolean, "with_boxes" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_astwkb"("geom" "public"."geometry"[], "ids" bigint[], "prec" integer, "prec_z" integer, "prec_m" integer, "with_sizes" boolean, "with_boxes" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_astwkb"("geom" "public"."geometry"[], "ids" bigint[], "prec" integer, "prec_z" integer, "prec_m" integer, "with_sizes" boolean, "with_boxes" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_astwkb"("geom" "public"."geometry"[], "ids" bigint[], "prec" integer, "prec_z" integer, "prec_m" integer, "with_sizes" boolean, "with_boxes" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_astwkb"("geom" "public"."geometry"[], "ids" bigint[], "prec" integer, "prec_z" integer, "prec_m" integer, "with_sizes" boolean, "with_boxes" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asx3d"("geom" "public"."geometry", "maxdecimaldigits" integer, "options" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asx3d"("geom" "public"."geometry", "maxdecimaldigits" integer, "options" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_asx3d"("geom" "public"."geometry", "maxdecimaldigits" integer, "options" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asx3d"("geom" "public"."geometry", "maxdecimaldigits" integer, "options" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_azimuth"("geog1" "public"."geography", "geog2" "public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_azimuth"("geog1" "public"."geography", "geog2" "public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."st_azimuth"("geog1" "public"."geography", "geog2" "public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_azimuth"("geog1" "public"."geography", "geog2" "public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_azimuth"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_azimuth"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_azimuth"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_azimuth"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_bdmpolyfromtext"("text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_bdmpolyfromtext"("text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_bdmpolyfromtext"("text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_bdmpolyfromtext"("text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_bdpolyfromtext"("text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_bdpolyfromtext"("text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_bdpolyfromtext"("text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_bdpolyfromtext"("text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_boundary"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_boundary"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_boundary"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_boundary"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_boundingdiagonal"("geom" "public"."geometry", "fits" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_boundingdiagonal"("geom" "public"."geometry", "fits" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_boundingdiagonal"("geom" "public"."geometry", "fits" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_boundingdiagonal"("geom" "public"."geometry", "fits" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_box2dfromgeohash"("text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_box2dfromgeohash"("text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_box2dfromgeohash"("text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_box2dfromgeohash"("text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_buffer"("text", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_buffer"("text", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_buffer"("text", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_buffer"("text", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_buffer"("public"."geography", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_buffer"("public"."geography", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_buffer"("public"."geography", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_buffer"("public"."geography", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_buffer"("text", double precision, integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_buffer"("text", double precision, integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_buffer"("text", double precision, integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_buffer"("text", double precision, integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_buffer"("text", double precision, "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_buffer"("text", double precision, "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_buffer"("text", double precision, "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_buffer"("text", double precision, "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_buffer"("public"."geography", double precision, integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_buffer"("public"."geography", double precision, integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_buffer"("public"."geography", double precision, integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_buffer"("public"."geography", double precision, integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_buffer"("public"."geography", double precision, "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_buffer"("public"."geography", double precision, "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_buffer"("public"."geography", double precision, "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_buffer"("public"."geography", double precision, "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_buffer"("geom" "public"."geometry", "radius" double precision, "quadsegs" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_buffer"("geom" "public"."geometry", "radius" double precision, "quadsegs" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_buffer"("geom" "public"."geometry", "radius" double precision, "quadsegs" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_buffer"("geom" "public"."geometry", "radius" double precision, "quadsegs" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_buffer"("geom" "public"."geometry", "radius" double precision, "options" "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_buffer"("geom" "public"."geometry", "radius" double precision, "options" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_buffer"("geom" "public"."geometry", "radius" double precision, "options" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_buffer"("geom" "public"."geometry", "radius" double precision, "options" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_buildarea"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_buildarea"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_buildarea"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_buildarea"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_centroid"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_centroid"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_centroid"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_centroid"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_centroid"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_centroid"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_centroid"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_centroid"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_centroid"("public"."geography", "use_spheroid" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_centroid"("public"."geography", "use_spheroid" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_centroid"("public"."geography", "use_spheroid" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_centroid"("public"."geography", "use_spheroid" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_chaikinsmoothing"("public"."geometry", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_chaikinsmoothing"("public"."geometry", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_chaikinsmoothing"("public"."geometry", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_chaikinsmoothing"("public"."geometry", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_cleangeometry"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_cleangeometry"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_cleangeometry"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_cleangeometry"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_clipbybox2d"("geom" "public"."geometry", "box" "public"."box2d") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_clipbybox2d"("geom" "public"."geometry", "box" "public"."box2d") TO "anon";
GRANT ALL ON FUNCTION "public"."st_clipbybox2d"("geom" "public"."geometry", "box" "public"."box2d") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_clipbybox2d"("geom" "public"."geometry", "box" "public"."box2d") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_closestpoint"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_closestpoint"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_closestpoint"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_closestpoint"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_closestpointofapproach"("public"."geometry", "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_closestpointofapproach"("public"."geometry", "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_closestpointofapproach"("public"."geometry", "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_closestpointofapproach"("public"."geometry", "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_clusterdbscan"("public"."geometry", "eps" double precision, "minpoints" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_clusterdbscan"("public"."geometry", "eps" double precision, "minpoints" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_clusterdbscan"("public"."geometry", "eps" double precision, "minpoints" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_clusterdbscan"("public"."geometry", "eps" double precision, "minpoints" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_clusterintersecting"("public"."geometry"[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_clusterintersecting"("public"."geometry"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."st_clusterintersecting"("public"."geometry"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_clusterintersecting"("public"."geometry"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_clusterkmeans"("geom" "public"."geometry", "k" integer, "max_radius" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_clusterkmeans"("geom" "public"."geometry", "k" integer, "max_radius" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_clusterkmeans"("geom" "public"."geometry", "k" integer, "max_radius" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_clusterkmeans"("geom" "public"."geometry", "k" integer, "max_radius" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_clusterwithin"("public"."geometry"[], double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_clusterwithin"("public"."geometry"[], double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_clusterwithin"("public"."geometry"[], double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_clusterwithin"("public"."geometry"[], double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_collect"("public"."geometry"[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_collect"("public"."geometry"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."st_collect"("public"."geometry"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_collect"("public"."geometry"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_collect"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_collect"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_collect"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_collect"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_collectionextract"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_collectionextract"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_collectionextract"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_collectionextract"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_collectionextract"("public"."geometry", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_collectionextract"("public"."geometry", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_collectionextract"("public"."geometry", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_collectionextract"("public"."geometry", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_collectionhomogenize"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_collectionhomogenize"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_collectionhomogenize"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_collectionhomogenize"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_combinebbox"("public"."box2d", "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_combinebbox"("public"."box2d", "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_combinebbox"("public"."box2d", "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_combinebbox"("public"."box2d", "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_combinebbox"("public"."box3d", "public"."box3d") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_combinebbox"("public"."box3d", "public"."box3d") TO "anon";
GRANT ALL ON FUNCTION "public"."st_combinebbox"("public"."box3d", "public"."box3d") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_combinebbox"("public"."box3d", "public"."box3d") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_combinebbox"("public"."box3d", "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_combinebbox"("public"."box3d", "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_combinebbox"("public"."box3d", "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_combinebbox"("public"."box3d", "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_concavehull"("param_geom" "public"."geometry", "param_pctconvex" double precision, "param_allow_holes" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_concavehull"("param_geom" "public"."geometry", "param_pctconvex" double precision, "param_allow_holes" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_concavehull"("param_geom" "public"."geometry", "param_pctconvex" double precision, "param_allow_holes" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_concavehull"("param_geom" "public"."geometry", "param_pctconvex" double precision, "param_allow_holes" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_contains"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_contains"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_contains"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_contains"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_containsproperly"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_containsproperly"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_containsproperly"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_containsproperly"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_convexhull"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_convexhull"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_convexhull"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_convexhull"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_coorddim"("geometry" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_coorddim"("geometry" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_coorddim"("geometry" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_coorddim"("geometry" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_coveredby"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_coveredby"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_coveredby"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_coveredby"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_coveredby"("geog1" "public"."geography", "geog2" "public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_coveredby"("geog1" "public"."geography", "geog2" "public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."st_coveredby"("geog1" "public"."geography", "geog2" "public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_coveredby"("geog1" "public"."geography", "geog2" "public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_coveredby"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_coveredby"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_coveredby"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_coveredby"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_covers"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_covers"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_covers"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_covers"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_covers"("geog1" "public"."geography", "geog2" "public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_covers"("geog1" "public"."geography", "geog2" "public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."st_covers"("geog1" "public"."geography", "geog2" "public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_covers"("geog1" "public"."geography", "geog2" "public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_covers"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_covers"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_covers"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_covers"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_cpawithin"("public"."geometry", "public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_cpawithin"("public"."geometry", "public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_cpawithin"("public"."geometry", "public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_cpawithin"("public"."geometry", "public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_crosses"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_crosses"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_crosses"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_crosses"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_curvetoline"("geom" "public"."geometry", "tol" double precision, "toltype" integer, "flags" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_curvetoline"("geom" "public"."geometry", "tol" double precision, "toltype" integer, "flags" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_curvetoline"("geom" "public"."geometry", "tol" double precision, "toltype" integer, "flags" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_curvetoline"("geom" "public"."geometry", "tol" double precision, "toltype" integer, "flags" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_delaunaytriangles"("g1" "public"."geometry", "tolerance" double precision, "flags" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_delaunaytriangles"("g1" "public"."geometry", "tolerance" double precision, "flags" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_delaunaytriangles"("g1" "public"."geometry", "tolerance" double precision, "flags" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_delaunaytriangles"("g1" "public"."geometry", "tolerance" double precision, "flags" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_dfullywithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_dfullywithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_dfullywithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_dfullywithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_difference"("geom1" "public"."geometry", "geom2" "public"."geometry", "gridsize" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_difference"("geom1" "public"."geometry", "geom2" "public"."geometry", "gridsize" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_difference"("geom1" "public"."geometry", "geom2" "public"."geometry", "gridsize" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_difference"("geom1" "public"."geometry", "geom2" "public"."geometry", "gridsize" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_dimension"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_dimension"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_dimension"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_dimension"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_disjoint"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_disjoint"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_disjoint"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_disjoint"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_distance"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_distance"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_distance"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_distance"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_distance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_distance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_distance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_distance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_distance"("geog1" "public"."geography", "geog2" "public"."geography", "use_spheroid" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_distance"("geog1" "public"."geography", "geog2" "public"."geography", "use_spheroid" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_distance"("geog1" "public"."geography", "geog2" "public"."geography", "use_spheroid" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_distance"("geog1" "public"."geography", "geog2" "public"."geography", "use_spheroid" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_distancecpa"("public"."geometry", "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_distancecpa"("public"."geometry", "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_distancecpa"("public"."geometry", "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_distancecpa"("public"."geometry", "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_distancesphere"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_distancesphere"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_distancesphere"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_distancesphere"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_distancesphere"("geom1" "public"."geometry", "geom2" "public"."geometry", "radius" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_distancesphere"("geom1" "public"."geometry", "geom2" "public"."geometry", "radius" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_distancesphere"("geom1" "public"."geometry", "geom2" "public"."geometry", "radius" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_distancesphere"("geom1" "public"."geometry", "geom2" "public"."geometry", "radius" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_distancespheroid"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_distancespheroid"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_distancespheroid"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_distancespheroid"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_distancespheroid"("geom1" "public"."geometry", "geom2" "public"."geometry", "public"."spheroid") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_distancespheroid"("geom1" "public"."geometry", "geom2" "public"."geometry", "public"."spheroid") TO "anon";
GRANT ALL ON FUNCTION "public"."st_distancespheroid"("geom1" "public"."geometry", "geom2" "public"."geometry", "public"."spheroid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_distancespheroid"("geom1" "public"."geometry", "geom2" "public"."geometry", "public"."spheroid") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_dump"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_dump"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_dump"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_dump"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_dumppoints"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_dumppoints"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_dumppoints"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_dumppoints"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_dumprings"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_dumprings"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_dumprings"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_dumprings"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_dumpsegments"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_dumpsegments"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_dumpsegments"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_dumpsegments"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_dwithin"("text", "text", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_dwithin"("text", "text", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_dwithin"("text", "text", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_dwithin"("text", "text", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_dwithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_dwithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_dwithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_dwithin"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_dwithin"("geog1" "public"."geography", "geog2" "public"."geography", "tolerance" double precision, "use_spheroid" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_dwithin"("geog1" "public"."geography", "geog2" "public"."geography", "tolerance" double precision, "use_spheroid" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_dwithin"("geog1" "public"."geography", "geog2" "public"."geography", "tolerance" double precision, "use_spheroid" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_dwithin"("geog1" "public"."geography", "geog2" "public"."geography", "tolerance" double precision, "use_spheroid" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_endpoint"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_endpoint"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_endpoint"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_endpoint"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_envelope"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_envelope"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_envelope"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_envelope"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_equals"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_equals"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_equals"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_equals"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_estimatedextent"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_estimatedextent"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_estimatedextent"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_estimatedextent"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_estimatedextent"("text", "text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_estimatedextent"("text", "text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_estimatedextent"("text", "text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_estimatedextent"("text", "text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_estimatedextent"("text", "text", "text", boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_estimatedextent"("text", "text", "text", boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_estimatedextent"("text", "text", "text", boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_estimatedextent"("text", "text", "text", boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_expand"("public"."box2d", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_expand"("public"."box2d", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_expand"("public"."box2d", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_expand"("public"."box2d", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_expand"("public"."box3d", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_expand"("public"."box3d", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_expand"("public"."box3d", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_expand"("public"."box3d", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_expand"("public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_expand"("public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_expand"("public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_expand"("public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_expand"("box" "public"."box2d", "dx" double precision, "dy" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_expand"("box" "public"."box2d", "dx" double precision, "dy" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_expand"("box" "public"."box2d", "dx" double precision, "dy" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_expand"("box" "public"."box2d", "dx" double precision, "dy" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_expand"("box" "public"."box3d", "dx" double precision, "dy" double precision, "dz" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_expand"("box" "public"."box3d", "dx" double precision, "dy" double precision, "dz" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_expand"("box" "public"."box3d", "dx" double precision, "dy" double precision, "dz" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_expand"("box" "public"."box3d", "dx" double precision, "dy" double precision, "dz" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_expand"("geom" "public"."geometry", "dx" double precision, "dy" double precision, "dz" double precision, "dm" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_expand"("geom" "public"."geometry", "dx" double precision, "dy" double precision, "dz" double precision, "dm" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_expand"("geom" "public"."geometry", "dx" double precision, "dy" double precision, "dz" double precision, "dm" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_expand"("geom" "public"."geometry", "dx" double precision, "dy" double precision, "dz" double precision, "dm" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_exteriorring"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_exteriorring"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_exteriorring"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_exteriorring"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_filterbym"("public"."geometry", double precision, double precision, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_filterbym"("public"."geometry", double precision, double precision, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_filterbym"("public"."geometry", double precision, double precision, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_filterbym"("public"."geometry", double precision, double precision, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_findextent"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_findextent"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_findextent"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_findextent"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_findextent"("text", "text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_findextent"("text", "text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_findextent"("text", "text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_findextent"("text", "text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_flipcoordinates"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_flipcoordinates"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_flipcoordinates"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_flipcoordinates"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_force2d"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_force2d"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_force2d"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_force2d"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_force3d"("geom" "public"."geometry", "zvalue" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_force3d"("geom" "public"."geometry", "zvalue" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_force3d"("geom" "public"."geometry", "zvalue" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_force3d"("geom" "public"."geometry", "zvalue" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_force3dm"("geom" "public"."geometry", "mvalue" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_force3dm"("geom" "public"."geometry", "mvalue" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_force3dm"("geom" "public"."geometry", "mvalue" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_force3dm"("geom" "public"."geometry", "mvalue" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_force3dz"("geom" "public"."geometry", "zvalue" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_force3dz"("geom" "public"."geometry", "zvalue" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_force3dz"("geom" "public"."geometry", "zvalue" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_force3dz"("geom" "public"."geometry", "zvalue" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_force4d"("geom" "public"."geometry", "zvalue" double precision, "mvalue" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_force4d"("geom" "public"."geometry", "zvalue" double precision, "mvalue" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_force4d"("geom" "public"."geometry", "zvalue" double precision, "mvalue" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_force4d"("geom" "public"."geometry", "zvalue" double precision, "mvalue" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_forcecollection"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_forcecollection"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_forcecollection"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_forcecollection"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_forcecurve"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_forcecurve"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_forcecurve"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_forcecurve"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_forcepolygonccw"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_forcepolygonccw"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_forcepolygonccw"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_forcepolygonccw"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_forcepolygoncw"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_forcepolygoncw"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_forcepolygoncw"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_forcepolygoncw"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_forcerhr"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_forcerhr"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_forcerhr"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_forcerhr"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_forcesfs"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_forcesfs"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_forcesfs"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_forcesfs"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_forcesfs"("public"."geometry", "version" "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_forcesfs"("public"."geometry", "version" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_forcesfs"("public"."geometry", "version" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_forcesfs"("public"."geometry", "version" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_frechetdistance"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_frechetdistance"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_frechetdistance"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_frechetdistance"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_fromflatgeobuf"("anyelement", "bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_fromflatgeobuf"("anyelement", "bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."st_fromflatgeobuf"("anyelement", "bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_fromflatgeobuf"("anyelement", "bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_fromflatgeobuftotable"("text", "text", "bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_fromflatgeobuftotable"("text", "text", "bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."st_fromflatgeobuftotable"("text", "text", "bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_fromflatgeobuftotable"("text", "text", "bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_generatepoints"("area" "public"."geometry", "npoints" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_generatepoints"("area" "public"."geometry", "npoints" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_generatepoints"("area" "public"."geometry", "npoints" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_generatepoints"("area" "public"."geometry", "npoints" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_generatepoints"("area" "public"."geometry", "npoints" integer, "seed" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_generatepoints"("area" "public"."geometry", "npoints" integer, "seed" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_generatepoints"("area" "public"."geometry", "npoints" integer, "seed" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_generatepoints"("area" "public"."geometry", "npoints" integer, "seed" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geogfromtext"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geogfromtext"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_geogfromtext"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geogfromtext"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geogfromwkb"("bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geogfromwkb"("bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."st_geogfromwkb"("bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geogfromwkb"("bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geographyfromtext"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geographyfromtext"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_geographyfromtext"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geographyfromtext"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geohash"("geog" "public"."geography", "maxchars" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geohash"("geog" "public"."geography", "maxchars" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_geohash"("geog" "public"."geography", "maxchars" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geohash"("geog" "public"."geography", "maxchars" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geohash"("geom" "public"."geometry", "maxchars" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geohash"("geom" "public"."geometry", "maxchars" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_geohash"("geom" "public"."geometry", "maxchars" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geohash"("geom" "public"."geometry", "maxchars" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geomcollfromtext"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geomcollfromtext"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_geomcollfromtext"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geomcollfromtext"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geomcollfromtext"("text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geomcollfromtext"("text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_geomcollfromtext"("text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geomcollfromtext"("text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geomcollfromwkb"("bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geomcollfromwkb"("bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."st_geomcollfromwkb"("bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geomcollfromwkb"("bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geomcollfromwkb"("bytea", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geomcollfromwkb"("bytea", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_geomcollfromwkb"("bytea", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geomcollfromwkb"("bytea", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geometricmedian"("g" "public"."geometry", "tolerance" double precision, "max_iter" integer, "fail_if_not_converged" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geometricmedian"("g" "public"."geometry", "tolerance" double precision, "max_iter" integer, "fail_if_not_converged" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_geometricmedian"("g" "public"."geometry", "tolerance" double precision, "max_iter" integer, "fail_if_not_converged" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geometricmedian"("g" "public"."geometry", "tolerance" double precision, "max_iter" integer, "fail_if_not_converged" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geometryfromtext"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geometryfromtext"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_geometryfromtext"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geometryfromtext"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geometryfromtext"("text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geometryfromtext"("text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_geometryfromtext"("text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geometryfromtext"("text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geometryn"("public"."geometry", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geometryn"("public"."geometry", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_geometryn"("public"."geometry", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geometryn"("public"."geometry", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geometrytype"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geometrytype"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_geometrytype"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geometrytype"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geomfromewkb"("bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geomfromewkb"("bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."st_geomfromewkb"("bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geomfromewkb"("bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geomfromewkt"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geomfromewkt"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_geomfromewkt"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geomfromewkt"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geomfromgeohash"("text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geomfromgeohash"("text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_geomfromgeohash"("text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geomfromgeohash"("text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geomfromgeojson"(json) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geomfromgeojson"(json) TO "anon";
GRANT ALL ON FUNCTION "public"."st_geomfromgeojson"(json) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geomfromgeojson"(json) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geomfromgeojson"("jsonb") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geomfromgeojson"("jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."st_geomfromgeojson"("jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geomfromgeojson"("jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geomfromgeojson"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geomfromgeojson"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_geomfromgeojson"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geomfromgeojson"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geomfromgml"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geomfromgml"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_geomfromgml"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geomfromgml"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geomfromgml"("text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geomfromgml"("text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_geomfromgml"("text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geomfromgml"("text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geomfromkml"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geomfromkml"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_geomfromkml"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geomfromkml"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geomfrommarc21"("marc21xml" "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geomfrommarc21"("marc21xml" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_geomfrommarc21"("marc21xml" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geomfrommarc21"("marc21xml" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geomfromtext"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geomfromtext"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_geomfromtext"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geomfromtext"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geomfromtext"("text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geomfromtext"("text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_geomfromtext"("text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geomfromtext"("text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geomfromtwkb"("bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geomfromtwkb"("bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."st_geomfromtwkb"("bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geomfromtwkb"("bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geomfromwkb"("bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geomfromwkb"("bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."st_geomfromwkb"("bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geomfromwkb"("bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_geomfromwkb"("bytea", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_geomfromwkb"("bytea", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_geomfromwkb"("bytea", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_geomfromwkb"("bytea", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_gmltosql"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_gmltosql"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_gmltosql"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_gmltosql"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_gmltosql"("text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_gmltosql"("text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_gmltosql"("text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_gmltosql"("text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_hasarc"("geometry" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_hasarc"("geometry" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_hasarc"("geometry" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_hasarc"("geometry" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_hausdorffdistance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_hausdorffdistance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_hausdorffdistance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_hausdorffdistance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_hausdorffdistance"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_hausdorffdistance"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_hausdorffdistance"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_hausdorffdistance"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_hexagon"("size" double precision, "cell_i" integer, "cell_j" integer, "origin" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_hexagon"("size" double precision, "cell_i" integer, "cell_j" integer, "origin" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_hexagon"("size" double precision, "cell_i" integer, "cell_j" integer, "origin" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_hexagon"("size" double precision, "cell_i" integer, "cell_j" integer, "origin" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_hexagongrid"("size" double precision, "bounds" "public"."geometry", OUT "geom" "public"."geometry", OUT "i" integer, OUT "j" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_hexagongrid"("size" double precision, "bounds" "public"."geometry", OUT "geom" "public"."geometry", OUT "i" integer, OUT "j" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_hexagongrid"("size" double precision, "bounds" "public"."geometry", OUT "geom" "public"."geometry", OUT "i" integer, OUT "j" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_hexagongrid"("size" double precision, "bounds" "public"."geometry", OUT "geom" "public"."geometry", OUT "i" integer, OUT "j" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_interiorringn"("public"."geometry", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_interiorringn"("public"."geometry", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_interiorringn"("public"."geometry", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_interiorringn"("public"."geometry", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_interpolatepoint"("line" "public"."geometry", "point" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_interpolatepoint"("line" "public"."geometry", "point" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_interpolatepoint"("line" "public"."geometry", "point" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_interpolatepoint"("line" "public"."geometry", "point" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_intersection"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_intersection"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_intersection"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_intersection"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_intersection"("public"."geography", "public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_intersection"("public"."geography", "public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."st_intersection"("public"."geography", "public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_intersection"("public"."geography", "public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_intersection"("geom1" "public"."geometry", "geom2" "public"."geometry", "gridsize" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_intersection"("geom1" "public"."geometry", "geom2" "public"."geometry", "gridsize" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_intersection"("geom1" "public"."geometry", "geom2" "public"."geometry", "gridsize" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_intersection"("geom1" "public"."geometry", "geom2" "public"."geometry", "gridsize" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_intersects"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_intersects"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_intersects"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_intersects"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_intersects"("geog1" "public"."geography", "geog2" "public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_intersects"("geog1" "public"."geography", "geog2" "public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."st_intersects"("geog1" "public"."geography", "geog2" "public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_intersects"("geog1" "public"."geography", "geog2" "public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_intersects"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_intersects"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_intersects"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_intersects"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_isclosed"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_isclosed"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_isclosed"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_isclosed"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_iscollection"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_iscollection"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_iscollection"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_iscollection"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_isempty"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_isempty"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_isempty"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_isempty"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_ispolygonccw"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_ispolygonccw"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_ispolygonccw"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_ispolygonccw"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_ispolygoncw"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_ispolygoncw"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_ispolygoncw"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_ispolygoncw"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_isring"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_isring"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_isring"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_isring"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_issimple"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_issimple"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_issimple"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_issimple"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_isvalid"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_isvalid"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_isvalid"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_isvalid"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_isvalid"("public"."geometry", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_isvalid"("public"."geometry", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_isvalid"("public"."geometry", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_isvalid"("public"."geometry", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_isvaliddetail"("geom" "public"."geometry", "flags" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_isvaliddetail"("geom" "public"."geometry", "flags" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_isvaliddetail"("geom" "public"."geometry", "flags" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_isvaliddetail"("geom" "public"."geometry", "flags" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_isvalidreason"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_isvalidreason"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_isvalidreason"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_isvalidreason"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_isvalidreason"("public"."geometry", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_isvalidreason"("public"."geometry", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_isvalidreason"("public"."geometry", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_isvalidreason"("public"."geometry", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_isvalidtrajectory"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_isvalidtrajectory"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_isvalidtrajectory"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_isvalidtrajectory"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_length"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_length"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_length"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_length"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_length"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_length"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_length"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_length"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_length"("geog" "public"."geography", "use_spheroid" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_length"("geog" "public"."geography", "use_spheroid" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_length"("geog" "public"."geography", "use_spheroid" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_length"("geog" "public"."geography", "use_spheroid" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_length2d"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_length2d"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_length2d"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_length2d"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_length2dspheroid"("public"."geometry", "public"."spheroid") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_length2dspheroid"("public"."geometry", "public"."spheroid") TO "anon";
GRANT ALL ON FUNCTION "public"."st_length2dspheroid"("public"."geometry", "public"."spheroid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_length2dspheroid"("public"."geometry", "public"."spheroid") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_lengthspheroid"("public"."geometry", "public"."spheroid") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_lengthspheroid"("public"."geometry", "public"."spheroid") TO "anon";
GRANT ALL ON FUNCTION "public"."st_lengthspheroid"("public"."geometry", "public"."spheroid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_lengthspheroid"("public"."geometry", "public"."spheroid") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_letters"("letters" "text", "font" json) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_letters"("letters" "text", "font" json) TO "anon";
GRANT ALL ON FUNCTION "public"."st_letters"("letters" "text", "font" json) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_letters"("letters" "text", "font" json) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_linecrossingdirection"("line1" "public"."geometry", "line2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_linecrossingdirection"("line1" "public"."geometry", "line2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_linecrossingdirection"("line1" "public"."geometry", "line2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_linecrossingdirection"("line1" "public"."geometry", "line2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_linefromencodedpolyline"("txtin" "text", "nprecision" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_linefromencodedpolyline"("txtin" "text", "nprecision" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_linefromencodedpolyline"("txtin" "text", "nprecision" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_linefromencodedpolyline"("txtin" "text", "nprecision" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_linefrommultipoint"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_linefrommultipoint"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_linefrommultipoint"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_linefrommultipoint"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_linefromtext"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_linefromtext"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_linefromtext"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_linefromtext"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_linefromtext"("text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_linefromtext"("text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_linefromtext"("text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_linefromtext"("text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_linefromwkb"("bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_linefromwkb"("bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."st_linefromwkb"("bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_linefromwkb"("bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_linefromwkb"("bytea", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_linefromwkb"("bytea", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_linefromwkb"("bytea", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_linefromwkb"("bytea", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_lineinterpolatepoint"("public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_lineinterpolatepoint"("public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_lineinterpolatepoint"("public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_lineinterpolatepoint"("public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_lineinterpolatepoints"("public"."geometry", double precision, "repeat" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_lineinterpolatepoints"("public"."geometry", double precision, "repeat" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_lineinterpolatepoints"("public"."geometry", double precision, "repeat" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_lineinterpolatepoints"("public"."geometry", double precision, "repeat" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_linelocatepoint"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_linelocatepoint"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_linelocatepoint"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_linelocatepoint"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_linemerge"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_linemerge"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_linemerge"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_linemerge"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_linemerge"("public"."geometry", boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_linemerge"("public"."geometry", boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_linemerge"("public"."geometry", boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_linemerge"("public"."geometry", boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_linestringfromwkb"("bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_linestringfromwkb"("bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."st_linestringfromwkb"("bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_linestringfromwkb"("bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_linestringfromwkb"("bytea", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_linestringfromwkb"("bytea", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_linestringfromwkb"("bytea", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_linestringfromwkb"("bytea", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_linesubstring"("public"."geometry", double precision, double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_linesubstring"("public"."geometry", double precision, double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_linesubstring"("public"."geometry", double precision, double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_linesubstring"("public"."geometry", double precision, double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_linetocurve"("geometry" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_linetocurve"("geometry" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_linetocurve"("geometry" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_linetocurve"("geometry" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_locatealong"("geometry" "public"."geometry", "measure" double precision, "leftrightoffset" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_locatealong"("geometry" "public"."geometry", "measure" double precision, "leftrightoffset" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_locatealong"("geometry" "public"."geometry", "measure" double precision, "leftrightoffset" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_locatealong"("geometry" "public"."geometry", "measure" double precision, "leftrightoffset" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_locatebetween"("geometry" "public"."geometry", "frommeasure" double precision, "tomeasure" double precision, "leftrightoffset" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_locatebetween"("geometry" "public"."geometry", "frommeasure" double precision, "tomeasure" double precision, "leftrightoffset" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_locatebetween"("geometry" "public"."geometry", "frommeasure" double precision, "tomeasure" double precision, "leftrightoffset" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_locatebetween"("geometry" "public"."geometry", "frommeasure" double precision, "tomeasure" double precision, "leftrightoffset" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_locatebetweenelevations"("geometry" "public"."geometry", "fromelevation" double precision, "toelevation" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_locatebetweenelevations"("geometry" "public"."geometry", "fromelevation" double precision, "toelevation" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_locatebetweenelevations"("geometry" "public"."geometry", "fromelevation" double precision, "toelevation" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_locatebetweenelevations"("geometry" "public"."geometry", "fromelevation" double precision, "toelevation" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_longestline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_longestline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_longestline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_longestline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_m"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_m"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_m"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_m"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_makebox2d"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_makebox2d"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_makebox2d"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_makebox2d"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_makeenvelope"(double precision, double precision, double precision, double precision, integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_makeenvelope"(double precision, double precision, double precision, double precision, integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_makeenvelope"(double precision, double precision, double precision, double precision, integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_makeenvelope"(double precision, double precision, double precision, double precision, integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_makeline"("public"."geometry"[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_makeline"("public"."geometry"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."st_makeline"("public"."geometry"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_makeline"("public"."geometry"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_makeline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_makeline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_makeline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_makeline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_makepoint"(double precision, double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_makepoint"(double precision, double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_makepoint"(double precision, double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_makepoint"(double precision, double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_makepoint"(double precision, double precision, double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_makepoint"(double precision, double precision, double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_makepoint"(double precision, double precision, double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_makepoint"(double precision, double precision, double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_makepoint"(double precision, double precision, double precision, double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_makepoint"(double precision, double precision, double precision, double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_makepoint"(double precision, double precision, double precision, double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_makepoint"(double precision, double precision, double precision, double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_makepointm"(double precision, double precision, double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_makepointm"(double precision, double precision, double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_makepointm"(double precision, double precision, double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_makepointm"(double precision, double precision, double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_makepolygon"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_makepolygon"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_makepolygon"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_makepolygon"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_makepolygon"("public"."geometry", "public"."geometry"[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_makepolygon"("public"."geometry", "public"."geometry"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."st_makepolygon"("public"."geometry", "public"."geometry"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_makepolygon"("public"."geometry", "public"."geometry"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_makevalid"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_makevalid"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_makevalid"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_makevalid"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_makevalid"("geom" "public"."geometry", "params" "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_makevalid"("geom" "public"."geometry", "params" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_makevalid"("geom" "public"."geometry", "params" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_makevalid"("geom" "public"."geometry", "params" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_maxdistance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_maxdistance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_maxdistance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_maxdistance"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_maximuminscribedcircle"("public"."geometry", OUT "center" "public"."geometry", OUT "nearest" "public"."geometry", OUT "radius" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_maximuminscribedcircle"("public"."geometry", OUT "center" "public"."geometry", OUT "nearest" "public"."geometry", OUT "radius" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_maximuminscribedcircle"("public"."geometry", OUT "center" "public"."geometry", OUT "nearest" "public"."geometry", OUT "radius" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_maximuminscribedcircle"("public"."geometry", OUT "center" "public"."geometry", OUT "nearest" "public"."geometry", OUT "radius" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_memsize"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_memsize"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_memsize"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_memsize"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_minimumboundingcircle"("inputgeom" "public"."geometry", "segs_per_quarter" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_minimumboundingcircle"("inputgeom" "public"."geometry", "segs_per_quarter" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_minimumboundingcircle"("inputgeom" "public"."geometry", "segs_per_quarter" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_minimumboundingcircle"("inputgeom" "public"."geometry", "segs_per_quarter" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_minimumboundingradius"("public"."geometry", OUT "center" "public"."geometry", OUT "radius" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_minimumboundingradius"("public"."geometry", OUT "center" "public"."geometry", OUT "radius" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_minimumboundingradius"("public"."geometry", OUT "center" "public"."geometry", OUT "radius" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_minimumboundingradius"("public"."geometry", OUT "center" "public"."geometry", OUT "radius" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_minimumclearance"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_minimumclearance"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_minimumclearance"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_minimumclearance"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_minimumclearanceline"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_minimumclearanceline"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_minimumclearanceline"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_minimumclearanceline"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_mlinefromtext"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_mlinefromtext"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_mlinefromtext"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_mlinefromtext"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_mlinefromtext"("text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_mlinefromtext"("text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_mlinefromtext"("text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_mlinefromtext"("text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_mlinefromwkb"("bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_mlinefromwkb"("bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."st_mlinefromwkb"("bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_mlinefromwkb"("bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_mlinefromwkb"("bytea", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_mlinefromwkb"("bytea", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_mlinefromwkb"("bytea", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_mlinefromwkb"("bytea", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_mpointfromtext"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_mpointfromtext"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_mpointfromtext"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_mpointfromtext"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_mpointfromtext"("text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_mpointfromtext"("text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_mpointfromtext"("text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_mpointfromtext"("text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_mpointfromwkb"("bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_mpointfromwkb"("bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."st_mpointfromwkb"("bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_mpointfromwkb"("bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_mpointfromwkb"("bytea", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_mpointfromwkb"("bytea", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_mpointfromwkb"("bytea", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_mpointfromwkb"("bytea", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_mpolyfromtext"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_mpolyfromtext"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_mpolyfromtext"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_mpolyfromtext"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_mpolyfromtext"("text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_mpolyfromtext"("text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_mpolyfromtext"("text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_mpolyfromtext"("text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_mpolyfromwkb"("bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_mpolyfromwkb"("bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."st_mpolyfromwkb"("bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_mpolyfromwkb"("bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_mpolyfromwkb"("bytea", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_mpolyfromwkb"("bytea", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_mpolyfromwkb"("bytea", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_mpolyfromwkb"("bytea", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_multi"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_multi"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_multi"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_multi"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_multilinefromwkb"("bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_multilinefromwkb"("bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."st_multilinefromwkb"("bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_multilinefromwkb"("bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_multilinestringfromtext"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_multilinestringfromtext"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_multilinestringfromtext"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_multilinestringfromtext"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_multilinestringfromtext"("text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_multilinestringfromtext"("text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_multilinestringfromtext"("text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_multilinestringfromtext"("text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_multipointfromtext"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_multipointfromtext"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_multipointfromtext"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_multipointfromtext"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_multipointfromwkb"("bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_multipointfromwkb"("bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."st_multipointfromwkb"("bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_multipointfromwkb"("bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_multipointfromwkb"("bytea", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_multipointfromwkb"("bytea", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_multipointfromwkb"("bytea", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_multipointfromwkb"("bytea", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_multipolyfromwkb"("bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_multipolyfromwkb"("bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."st_multipolyfromwkb"("bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_multipolyfromwkb"("bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_multipolyfromwkb"("bytea", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_multipolyfromwkb"("bytea", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_multipolyfromwkb"("bytea", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_multipolyfromwkb"("bytea", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_multipolygonfromtext"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_multipolygonfromtext"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_multipolygonfromtext"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_multipolygonfromtext"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_multipolygonfromtext"("text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_multipolygonfromtext"("text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_multipolygonfromtext"("text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_multipolygonfromtext"("text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_ndims"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_ndims"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_ndims"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_ndims"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_node"("g" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_node"("g" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_node"("g" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_node"("g" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_normalize"("geom" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_normalize"("geom" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_normalize"("geom" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_normalize"("geom" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_npoints"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_npoints"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_npoints"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_npoints"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_nrings"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_nrings"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_nrings"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_nrings"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_numgeometries"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_numgeometries"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_numgeometries"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_numgeometries"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_numinteriorring"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_numinteriorring"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_numinteriorring"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_numinteriorring"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_numinteriorrings"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_numinteriorrings"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_numinteriorrings"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_numinteriorrings"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_numpatches"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_numpatches"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_numpatches"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_numpatches"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_numpoints"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_numpoints"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_numpoints"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_numpoints"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_offsetcurve"("line" "public"."geometry", "distance" double precision, "params" "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_offsetcurve"("line" "public"."geometry", "distance" double precision, "params" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_offsetcurve"("line" "public"."geometry", "distance" double precision, "params" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_offsetcurve"("line" "public"."geometry", "distance" double precision, "params" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_orderingequals"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_orderingequals"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_orderingequals"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_orderingequals"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_orientedenvelope"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_orientedenvelope"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_orientedenvelope"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_orientedenvelope"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_overlaps"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_overlaps"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_overlaps"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_overlaps"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_patchn"("public"."geometry", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_patchn"("public"."geometry", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_patchn"("public"."geometry", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_patchn"("public"."geometry", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_perimeter"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_perimeter"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_perimeter"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_perimeter"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_perimeter"("geog" "public"."geography", "use_spheroid" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_perimeter"("geog" "public"."geography", "use_spheroid" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_perimeter"("geog" "public"."geography", "use_spheroid" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_perimeter"("geog" "public"."geography", "use_spheroid" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_perimeter2d"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_perimeter2d"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_perimeter2d"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_perimeter2d"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_point"(double precision, double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_point"(double precision, double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_point"(double precision, double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_point"(double precision, double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_point"(double precision, double precision, "srid" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_point"(double precision, double precision, "srid" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_point"(double precision, double precision, "srid" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_point"(double precision, double precision, "srid" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_pointfromgeohash"("text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_pointfromgeohash"("text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_pointfromgeohash"("text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_pointfromgeohash"("text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_pointfromtext"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_pointfromtext"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_pointfromtext"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_pointfromtext"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_pointfromtext"("text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_pointfromtext"("text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_pointfromtext"("text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_pointfromtext"("text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_pointfromwkb"("bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_pointfromwkb"("bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."st_pointfromwkb"("bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_pointfromwkb"("bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_pointfromwkb"("bytea", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_pointfromwkb"("bytea", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_pointfromwkb"("bytea", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_pointfromwkb"("bytea", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_pointinsidecircle"("public"."geometry", double precision, double precision, double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_pointinsidecircle"("public"."geometry", double precision, double precision, double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_pointinsidecircle"("public"."geometry", double precision, double precision, double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_pointinsidecircle"("public"."geometry", double precision, double precision, double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_pointm"("xcoordinate" double precision, "ycoordinate" double precision, "mcoordinate" double precision, "srid" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_pointm"("xcoordinate" double precision, "ycoordinate" double precision, "mcoordinate" double precision, "srid" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_pointm"("xcoordinate" double precision, "ycoordinate" double precision, "mcoordinate" double precision, "srid" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_pointm"("xcoordinate" double precision, "ycoordinate" double precision, "mcoordinate" double precision, "srid" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_pointn"("public"."geometry", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_pointn"("public"."geometry", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_pointn"("public"."geometry", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_pointn"("public"."geometry", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_pointonsurface"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_pointonsurface"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_pointonsurface"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_pointonsurface"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_points"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_points"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_points"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_points"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_pointz"("xcoordinate" double precision, "ycoordinate" double precision, "zcoordinate" double precision, "srid" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_pointz"("xcoordinate" double precision, "ycoordinate" double precision, "zcoordinate" double precision, "srid" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_pointz"("xcoordinate" double precision, "ycoordinate" double precision, "zcoordinate" double precision, "srid" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_pointz"("xcoordinate" double precision, "ycoordinate" double precision, "zcoordinate" double precision, "srid" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_pointzm"("xcoordinate" double precision, "ycoordinate" double precision, "zcoordinate" double precision, "mcoordinate" double precision, "srid" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_pointzm"("xcoordinate" double precision, "ycoordinate" double precision, "zcoordinate" double precision, "mcoordinate" double precision, "srid" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_pointzm"("xcoordinate" double precision, "ycoordinate" double precision, "zcoordinate" double precision, "mcoordinate" double precision, "srid" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_pointzm"("xcoordinate" double precision, "ycoordinate" double precision, "zcoordinate" double precision, "mcoordinate" double precision, "srid" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_polyfromtext"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_polyfromtext"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_polyfromtext"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_polyfromtext"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_polyfromtext"("text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_polyfromtext"("text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_polyfromtext"("text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_polyfromtext"("text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_polyfromwkb"("bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_polyfromwkb"("bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."st_polyfromwkb"("bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_polyfromwkb"("bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_polyfromwkb"("bytea", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_polyfromwkb"("bytea", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_polyfromwkb"("bytea", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_polyfromwkb"("bytea", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_polygon"("public"."geometry", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_polygon"("public"."geometry", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_polygon"("public"."geometry", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_polygon"("public"."geometry", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_polygonfromtext"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_polygonfromtext"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_polygonfromtext"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_polygonfromtext"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_polygonfromtext"("text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_polygonfromtext"("text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_polygonfromtext"("text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_polygonfromtext"("text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_polygonfromwkb"("bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_polygonfromwkb"("bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."st_polygonfromwkb"("bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_polygonfromwkb"("bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_polygonfromwkb"("bytea", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_polygonfromwkb"("bytea", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_polygonfromwkb"("bytea", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_polygonfromwkb"("bytea", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_polygonize"("public"."geometry"[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_polygonize"("public"."geometry"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."st_polygonize"("public"."geometry"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_polygonize"("public"."geometry"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_project"("geog" "public"."geography", "distance" double precision, "azimuth" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_project"("geog" "public"."geography", "distance" double precision, "azimuth" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_project"("geog" "public"."geography", "distance" double precision, "azimuth" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_project"("geog" "public"."geography", "distance" double precision, "azimuth" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_quantizecoordinates"("g" "public"."geometry", "prec_x" integer, "prec_y" integer, "prec_z" integer, "prec_m" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_quantizecoordinates"("g" "public"."geometry", "prec_x" integer, "prec_y" integer, "prec_z" integer, "prec_m" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_quantizecoordinates"("g" "public"."geometry", "prec_x" integer, "prec_y" integer, "prec_z" integer, "prec_m" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_quantizecoordinates"("g" "public"."geometry", "prec_x" integer, "prec_y" integer, "prec_z" integer, "prec_m" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_reduceprecision"("geom" "public"."geometry", "gridsize" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_reduceprecision"("geom" "public"."geometry", "gridsize" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_reduceprecision"("geom" "public"."geometry", "gridsize" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_reduceprecision"("geom" "public"."geometry", "gridsize" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_relate"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_relate"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_relate"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_relate"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_relate"("geom1" "public"."geometry", "geom2" "public"."geometry", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_relate"("geom1" "public"."geometry", "geom2" "public"."geometry", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_relate"("geom1" "public"."geometry", "geom2" "public"."geometry", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_relate"("geom1" "public"."geometry", "geom2" "public"."geometry", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_relate"("geom1" "public"."geometry", "geom2" "public"."geometry", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_relate"("geom1" "public"."geometry", "geom2" "public"."geometry", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_relate"("geom1" "public"."geometry", "geom2" "public"."geometry", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_relate"("geom1" "public"."geometry", "geom2" "public"."geometry", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_relatematch"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_relatematch"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_relatematch"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_relatematch"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_removepoint"("public"."geometry", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_removepoint"("public"."geometry", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_removepoint"("public"."geometry", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_removepoint"("public"."geometry", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_removerepeatedpoints"("geom" "public"."geometry", "tolerance" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_removerepeatedpoints"("geom" "public"."geometry", "tolerance" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_removerepeatedpoints"("geom" "public"."geometry", "tolerance" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_removerepeatedpoints"("geom" "public"."geometry", "tolerance" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_reverse"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_reverse"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_reverse"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_reverse"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_rotate"("public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_rotate"("public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_rotate"("public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_rotate"("public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_rotate"("public"."geometry", double precision, "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_rotate"("public"."geometry", double precision, "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_rotate"("public"."geometry", double precision, "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_rotate"("public"."geometry", double precision, "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_rotate"("public"."geometry", double precision, double precision, double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_rotate"("public"."geometry", double precision, double precision, double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_rotate"("public"."geometry", double precision, double precision, double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_rotate"("public"."geometry", double precision, double precision, double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_rotatex"("public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_rotatex"("public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_rotatex"("public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_rotatex"("public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_rotatey"("public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_rotatey"("public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_rotatey"("public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_rotatey"("public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_rotatez"("public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_rotatez"("public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_rotatez"("public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_rotatez"("public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_scale"("public"."geometry", "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_scale"("public"."geometry", "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_scale"("public"."geometry", "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_scale"("public"."geometry", "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_scale"("public"."geometry", double precision, double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_scale"("public"."geometry", double precision, double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_scale"("public"."geometry", double precision, double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_scale"("public"."geometry", double precision, double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_scale"("public"."geometry", "public"."geometry", "origin" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_scale"("public"."geometry", "public"."geometry", "origin" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_scale"("public"."geometry", "public"."geometry", "origin" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_scale"("public"."geometry", "public"."geometry", "origin" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_scale"("public"."geometry", double precision, double precision, double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_scale"("public"."geometry", double precision, double precision, double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_scale"("public"."geometry", double precision, double precision, double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_scale"("public"."geometry", double precision, double precision, double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_scroll"("public"."geometry", "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_scroll"("public"."geometry", "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_scroll"("public"."geometry", "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_scroll"("public"."geometry", "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_segmentize"("geog" "public"."geography", "max_segment_length" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_segmentize"("geog" "public"."geography", "max_segment_length" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_segmentize"("geog" "public"."geography", "max_segment_length" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_segmentize"("geog" "public"."geography", "max_segment_length" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_segmentize"("public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_segmentize"("public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_segmentize"("public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_segmentize"("public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_seteffectivearea"("public"."geometry", double precision, integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_seteffectivearea"("public"."geometry", double precision, integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_seteffectivearea"("public"."geometry", double precision, integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_seteffectivearea"("public"."geometry", double precision, integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_setpoint"("public"."geometry", integer, "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_setpoint"("public"."geometry", integer, "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_setpoint"("public"."geometry", integer, "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_setpoint"("public"."geometry", integer, "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_setsrid"("geog" "public"."geography", "srid" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_setsrid"("geog" "public"."geography", "srid" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_setsrid"("geog" "public"."geography", "srid" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_setsrid"("geog" "public"."geography", "srid" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_setsrid"("geom" "public"."geometry", "srid" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_setsrid"("geom" "public"."geometry", "srid" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_setsrid"("geom" "public"."geometry", "srid" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_setsrid"("geom" "public"."geometry", "srid" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_sharedpaths"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_sharedpaths"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_sharedpaths"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_sharedpaths"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_shiftlongitude"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_shiftlongitude"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_shiftlongitude"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_shiftlongitude"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_shortestline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_shortestline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_shortestline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_shortestline"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_simplify"("public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_simplify"("public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_simplify"("public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_simplify"("public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_simplify"("public"."geometry", double precision, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_simplify"("public"."geometry", double precision, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_simplify"("public"."geometry", double precision, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_simplify"("public"."geometry", double precision, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_simplifypolygonhull"("geom" "public"."geometry", "vertex_fraction" double precision, "is_outer" boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_simplifypolygonhull"("geom" "public"."geometry", "vertex_fraction" double precision, "is_outer" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_simplifypolygonhull"("geom" "public"."geometry", "vertex_fraction" double precision, "is_outer" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_simplifypolygonhull"("geom" "public"."geometry", "vertex_fraction" double precision, "is_outer" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_simplifypreservetopology"("public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_simplifypreservetopology"("public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_simplifypreservetopology"("public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_simplifypreservetopology"("public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_simplifyvw"("public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_simplifyvw"("public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_simplifyvw"("public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_simplifyvw"("public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_snap"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_snap"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_snap"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_snap"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_snaptogrid"("public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_snaptogrid"("public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_snaptogrid"("public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_snaptogrid"("public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_snaptogrid"("public"."geometry", double precision, double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_snaptogrid"("public"."geometry", double precision, double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_snaptogrid"("public"."geometry", double precision, double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_snaptogrid"("public"."geometry", double precision, double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_snaptogrid"("public"."geometry", double precision, double precision, double precision, double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_snaptogrid"("public"."geometry", double precision, double precision, double precision, double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_snaptogrid"("public"."geometry", double precision, double precision, double precision, double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_snaptogrid"("public"."geometry", double precision, double precision, double precision, double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_snaptogrid"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision, double precision, double precision, double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_snaptogrid"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision, double precision, double precision, double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_snaptogrid"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision, double precision, double precision, double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_snaptogrid"("geom1" "public"."geometry", "geom2" "public"."geometry", double precision, double precision, double precision, double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_split"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_split"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_split"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_split"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_square"("size" double precision, "cell_i" integer, "cell_j" integer, "origin" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_square"("size" double precision, "cell_i" integer, "cell_j" integer, "origin" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_square"("size" double precision, "cell_i" integer, "cell_j" integer, "origin" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_square"("size" double precision, "cell_i" integer, "cell_j" integer, "origin" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_squaregrid"("size" double precision, "bounds" "public"."geometry", OUT "geom" "public"."geometry", OUT "i" integer, OUT "j" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_squaregrid"("size" double precision, "bounds" "public"."geometry", OUT "geom" "public"."geometry", OUT "i" integer, OUT "j" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_squaregrid"("size" double precision, "bounds" "public"."geometry", OUT "geom" "public"."geometry", OUT "i" integer, OUT "j" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_squaregrid"("size" double precision, "bounds" "public"."geometry", OUT "geom" "public"."geometry", OUT "i" integer, OUT "j" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_srid"("geog" "public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_srid"("geog" "public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."st_srid"("geog" "public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_srid"("geog" "public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_srid"("geom" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_srid"("geom" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_srid"("geom" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_srid"("geom" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_startpoint"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_startpoint"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_startpoint"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_startpoint"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_subdivide"("geom" "public"."geometry", "maxvertices" integer, "gridsize" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_subdivide"("geom" "public"."geometry", "maxvertices" integer, "gridsize" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_subdivide"("geom" "public"."geometry", "maxvertices" integer, "gridsize" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_subdivide"("geom" "public"."geometry", "maxvertices" integer, "gridsize" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_summary"("public"."geography") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_summary"("public"."geography") TO "anon";
GRANT ALL ON FUNCTION "public"."st_summary"("public"."geography") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_summary"("public"."geography") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_summary"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_summary"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_summary"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_summary"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_swapordinates"("geom" "public"."geometry", "ords" "cstring") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_swapordinates"("geom" "public"."geometry", "ords" "cstring") TO "anon";
GRANT ALL ON FUNCTION "public"."st_swapordinates"("geom" "public"."geometry", "ords" "cstring") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_swapordinates"("geom" "public"."geometry", "ords" "cstring") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_symdifference"("geom1" "public"."geometry", "geom2" "public"."geometry", "gridsize" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_symdifference"("geom1" "public"."geometry", "geom2" "public"."geometry", "gridsize" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_symdifference"("geom1" "public"."geometry", "geom2" "public"."geometry", "gridsize" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_symdifference"("geom1" "public"."geometry", "geom2" "public"."geometry", "gridsize" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_symmetricdifference"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_symmetricdifference"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_symmetricdifference"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_symmetricdifference"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_tileenvelope"("zoom" integer, "x" integer, "y" integer, "bounds" "public"."geometry", "margin" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_tileenvelope"("zoom" integer, "x" integer, "y" integer, "bounds" "public"."geometry", "margin" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_tileenvelope"("zoom" integer, "x" integer, "y" integer, "bounds" "public"."geometry", "margin" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_tileenvelope"("zoom" integer, "x" integer, "y" integer, "bounds" "public"."geometry", "margin" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_touches"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_touches"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_touches"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_touches"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_transform"("public"."geometry", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_transform"("public"."geometry", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_transform"("public"."geometry", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_transform"("public"."geometry", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_transform"("geom" "public"."geometry", "to_proj" "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_transform"("geom" "public"."geometry", "to_proj" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_transform"("geom" "public"."geometry", "to_proj" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_transform"("geom" "public"."geometry", "to_proj" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_transform"("geom" "public"."geometry", "from_proj" "text", "to_srid" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_transform"("geom" "public"."geometry", "from_proj" "text", "to_srid" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_transform"("geom" "public"."geometry", "from_proj" "text", "to_srid" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_transform"("geom" "public"."geometry", "from_proj" "text", "to_srid" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_transform"("geom" "public"."geometry", "from_proj" "text", "to_proj" "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_transform"("geom" "public"."geometry", "from_proj" "text", "to_proj" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_transform"("geom" "public"."geometry", "from_proj" "text", "to_proj" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_transform"("geom" "public"."geometry", "from_proj" "text", "to_proj" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_translate"("public"."geometry", double precision, double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_translate"("public"."geometry", double precision, double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_translate"("public"."geometry", double precision, double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_translate"("public"."geometry", double precision, double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_translate"("public"."geometry", double precision, double precision, double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_translate"("public"."geometry", double precision, double precision, double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_translate"("public"."geometry", double precision, double precision, double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_translate"("public"."geometry", double precision, double precision, double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_transscale"("public"."geometry", double precision, double precision, double precision, double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_transscale"("public"."geometry", double precision, double precision, double precision, double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_transscale"("public"."geometry", double precision, double precision, double precision, double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_transscale"("public"."geometry", double precision, double precision, double precision, double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_triangulatepolygon"("g1" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_triangulatepolygon"("g1" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_triangulatepolygon"("g1" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_triangulatepolygon"("g1" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_unaryunion"("public"."geometry", "gridsize" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_unaryunion"("public"."geometry", "gridsize" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_unaryunion"("public"."geometry", "gridsize" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_unaryunion"("public"."geometry", "gridsize" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_union"("public"."geometry"[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_union"("public"."geometry"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."st_union"("public"."geometry"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_union"("public"."geometry"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_union"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_union"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_union"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_union"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_union"("geom1" "public"."geometry", "geom2" "public"."geometry", "gridsize" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_union"("geom1" "public"."geometry", "geom2" "public"."geometry", "gridsize" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_union"("geom1" "public"."geometry", "geom2" "public"."geometry", "gridsize" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_union"("geom1" "public"."geometry", "geom2" "public"."geometry", "gridsize" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_voronoilines"("g1" "public"."geometry", "tolerance" double precision, "extend_to" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_voronoilines"("g1" "public"."geometry", "tolerance" double precision, "extend_to" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_voronoilines"("g1" "public"."geometry", "tolerance" double precision, "extend_to" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_voronoilines"("g1" "public"."geometry", "tolerance" double precision, "extend_to" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_voronoipolygons"("g1" "public"."geometry", "tolerance" double precision, "extend_to" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_voronoipolygons"("g1" "public"."geometry", "tolerance" double precision, "extend_to" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_voronoipolygons"("g1" "public"."geometry", "tolerance" double precision, "extend_to" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_voronoipolygons"("g1" "public"."geometry", "tolerance" double precision, "extend_to" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_within"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_within"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_within"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_within"("geom1" "public"."geometry", "geom2" "public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_wkbtosql"("wkb" "bytea") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_wkbtosql"("wkb" "bytea") TO "anon";
GRANT ALL ON FUNCTION "public"."st_wkbtosql"("wkb" "bytea") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_wkbtosql"("wkb" "bytea") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_wkttosql"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_wkttosql"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_wkttosql"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_wkttosql"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_wrapx"("geom" "public"."geometry", "wrap" double precision, "move" double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_wrapx"("geom" "public"."geometry", "wrap" double precision, "move" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_wrapx"("geom" "public"."geometry", "wrap" double precision, "move" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_wrapx"("geom" "public"."geometry", "wrap" double precision, "move" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_x"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_x"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_x"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_x"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_xmax"("public"."box3d") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_xmax"("public"."box3d") TO "anon";
GRANT ALL ON FUNCTION "public"."st_xmax"("public"."box3d") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_xmax"("public"."box3d") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_xmin"("public"."box3d") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_xmin"("public"."box3d") TO "anon";
GRANT ALL ON FUNCTION "public"."st_xmin"("public"."box3d") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_xmin"("public"."box3d") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_y"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_y"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_y"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_y"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_ymax"("public"."box3d") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_ymax"("public"."box3d") TO "anon";
GRANT ALL ON FUNCTION "public"."st_ymax"("public"."box3d") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_ymax"("public"."box3d") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_ymin"("public"."box3d") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_ymin"("public"."box3d") TO "anon";
GRANT ALL ON FUNCTION "public"."st_ymin"("public"."box3d") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_ymin"("public"."box3d") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_z"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_z"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_z"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_z"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_zmax"("public"."box3d") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_zmax"("public"."box3d") TO "anon";
GRANT ALL ON FUNCTION "public"."st_zmax"("public"."box3d") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_zmax"("public"."box3d") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_zmflag"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_zmflag"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_zmflag"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_zmflag"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_zmin"("public"."box3d") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_zmin"("public"."box3d") TO "anon";
GRANT ALL ON FUNCTION "public"."st_zmin"("public"."box3d") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_zmin"("public"."box3d") TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_legacy_directory_assignment_trigger"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_legacy_directory_assignment_trigger"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_legacy_directory_assignment_trigger"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_legacy_directory_employee"("target_employee_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."sync_legacy_directory_employee"("target_employee_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_legacy_directory_employee"("target_employee_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_legacy_directory_employee_trigger"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_legacy_directory_employee_trigger"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_legacy_directory_employee_trigger"() TO "service_role";



GRANT ALL ON FUNCTION "public"."unlockrows"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."unlockrows"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."unlockrows"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."unlockrows"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."updategeometrysrid"(character varying, character varying, integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."updategeometrysrid"(character varying, character varying, integer) TO "anon";
GRANT ALL ON FUNCTION "public"."updategeometrysrid"(character varying, character varying, integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."updategeometrysrid"(character varying, character varying, integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."updategeometrysrid"(character varying, character varying, character varying, integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."updategeometrysrid"(character varying, character varying, character varying, integer) TO "anon";
GRANT ALL ON FUNCTION "public"."updategeometrysrid"(character varying, character varying, character varying, integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."updategeometrysrid"(character varying, character varying, character varying, integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."updategeometrysrid"("catalogn_name" character varying, "schema_name" character varying, "table_name" character varying, "column_name" character varying, "new_srid_in" integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."updategeometrysrid"("catalogn_name" character varying, "schema_name" character varying, "table_name" character varying, "column_name" character varying, "new_srid_in" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."updategeometrysrid"("catalogn_name" character varying, "schema_name" character varying, "table_name" character varying, "column_name" character varying, "new_srid_in" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."updategeometrysrid"("catalogn_name" character varying, "schema_name" character varying, "table_name" character varying, "column_name" character varying, "new_srid_in" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."validate_transition"() TO "anon";
GRANT ALL ON FUNCTION "public"."validate_transition"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."validate_transition"() TO "service_role";












GRANT ALL ON FUNCTION "public"."st_3dextent"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_3dextent"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_3dextent"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_3dextent"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asflatgeobuf"("anyelement") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asflatgeobuf"("anyelement") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asflatgeobuf"("anyelement") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asflatgeobuf"("anyelement") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asflatgeobuf"("anyelement", boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asflatgeobuf"("anyelement", boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."st_asflatgeobuf"("anyelement", boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asflatgeobuf"("anyelement", boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asflatgeobuf"("anyelement", boolean, "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asflatgeobuf"("anyelement", boolean, "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asflatgeobuf"("anyelement", boolean, "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asflatgeobuf"("anyelement", boolean, "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asgeobuf"("anyelement") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asgeobuf"("anyelement") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asgeobuf"("anyelement") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asgeobuf"("anyelement") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asgeobuf"("anyelement", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asgeobuf"("anyelement", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asgeobuf"("anyelement", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asgeobuf"("anyelement", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asmvt"("anyelement") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asmvt"("anyelement") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asmvt"("anyelement") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asmvt"("anyelement") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asmvt"("anyelement", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asmvt"("anyelement", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asmvt"("anyelement", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asmvt"("anyelement", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asmvt"("anyelement", "text", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asmvt"("anyelement", "text", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."st_asmvt"("anyelement", "text", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asmvt"("anyelement", "text", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asmvt"("anyelement", "text", integer, "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asmvt"("anyelement", "text", integer, "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asmvt"("anyelement", "text", integer, "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asmvt"("anyelement", "text", integer, "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_asmvt"("anyelement", "text", integer, "text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_asmvt"("anyelement", "text", integer, "text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."st_asmvt"("anyelement", "text", integer, "text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_asmvt"("anyelement", "text", integer, "text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_clusterintersecting"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_clusterintersecting"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_clusterintersecting"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_clusterintersecting"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_clusterwithin"("public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_clusterwithin"("public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_clusterwithin"("public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_clusterwithin"("public"."geometry", double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."st_collect"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_collect"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_collect"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_collect"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_extent"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_extent"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_extent"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_extent"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_makeline"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_makeline"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_makeline"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_makeline"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_memcollect"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_memcollect"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_memcollect"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_memcollect"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_memunion"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_memunion"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_memunion"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_memunion"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_polygonize"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_polygonize"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_polygonize"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_polygonize"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_union"("public"."geometry") TO "postgres";
GRANT ALL ON FUNCTION "public"."st_union"("public"."geometry") TO "anon";
GRANT ALL ON FUNCTION "public"."st_union"("public"."geometry") TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_union"("public"."geometry") TO "service_role";



GRANT ALL ON FUNCTION "public"."st_union"("public"."geometry", double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."st_union"("public"."geometry", double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."st_union"("public"."geometry", double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."st_union"("public"."geometry", double precision) TO "service_role";















GRANT ALL ON TABLE "public"."ThreatCategories" TO "anon";
GRANT ALL ON TABLE "public"."ThreatCategories" TO "authenticated";
GRANT ALL ON TABLE "public"."ThreatCategories" TO "service_role";



GRANT ALL ON TABLE "public"."ThreatLevels" TO "anon";
GRANT ALL ON TABLE "public"."ThreatLevels" TO "authenticated";
GRANT ALL ON TABLE "public"."ThreatLevels" TO "service_role";



GRANT ALL ON TABLE "public"."ThreatMatrix" TO "anon";
GRANT ALL ON TABLE "public"."ThreatMatrix" TO "authenticated";
GRANT ALL ON TABLE "public"."ThreatMatrix" TO "service_role";



GRANT ALL ON TABLE "public"."abort_logs" TO "anon";
GRANT ALL ON TABLE "public"."abort_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."abort_logs" TO "service_role";



GRANT ALL ON TABLE "public"."actions_log" TO "anon";
GRANT ALL ON TABLE "public"."actions_log" TO "authenticated";
GRANT ALL ON TABLE "public"."actions_log" TO "service_role";



GRANT ALL ON TABLE "public"."patrol_triggers" TO "anon";
GRANT ALL ON TABLE "public"."patrol_triggers" TO "authenticated";
GRANT ALL ON TABLE "public"."patrol_triggers" TO "service_role";



GRANT ALL ON TABLE "public"."active_patrol_orders" TO "anon";
GRANT ALL ON TABLE "public"."active_patrol_orders" TO "authenticated";
GRANT ALL ON TABLE "public"."active_patrol_orders" TO "service_role";



GRANT ALL ON TABLE "public"."threat_scores" TO "anon";
GRANT ALL ON TABLE "public"."threat_scores" TO "authenticated";
GRANT ALL ON TABLE "public"."threat_scores" TO "service_role";



GRANT ALL ON TABLE "public"."patrol_threats_with_decay" TO "anon";
GRANT ALL ON TABLE "public"."patrol_threats_with_decay" TO "authenticated";
GRANT ALL ON TABLE "public"."patrol_threats_with_decay" TO "service_role";



GRANT ALL ON TABLE "public"."patrol_threats_decayed_with_level" TO "anon";
GRANT ALL ON TABLE "public"."patrol_threats_decayed_with_level" TO "authenticated";
GRANT ALL ON TABLE "public"."patrol_threats_decayed_with_level" TO "service_role";



GRANT ALL ON TABLE "public"."active_ops_with_threats" TO "anon";
GRANT ALL ON TABLE "public"."active_ops_with_threats" TO "authenticated";
GRANT ALL ON TABLE "public"."active_ops_with_threats" TO "service_role";



GRANT ALL ON TABLE "public"."alarm_accounts" TO "anon";
GRANT ALL ON TABLE "public"."alarm_accounts" TO "authenticated";
GRANT ALL ON TABLE "public"."alarm_accounts" TO "service_role";



GRANT ALL ON TABLE "public"."alert_events" TO "anon";
GRANT ALL ON TABLE "public"."alert_events" TO "authenticated";
GRANT ALL ON TABLE "public"."alert_events" TO "service_role";



GRANT ALL ON TABLE "public"."alert_rules" TO "anon";
GRANT ALL ON TABLE "public"."alert_rules" TO "authenticated";
GRANT ALL ON TABLE "public"."alert_rules" TO "service_role";



GRANT ALL ON TABLE "public"."area_sites" TO "anon";
GRANT ALL ON TABLE "public"."area_sites" TO "authenticated";
GRANT ALL ON TABLE "public"."area_sites" TO "service_role";



GRANT ALL ON TABLE "public"."intel_events" TO "anon";
GRANT ALL ON TABLE "public"."intel_events" TO "authenticated";
GRANT ALL ON TABLE "public"."intel_events" TO "service_role";



GRANT ALL ON TABLE "public"."latest_threat_per_entity" TO "anon";
GRANT ALL ON TABLE "public"."latest_threat_per_entity" TO "authenticated";
GRANT ALL ON TABLE "public"."latest_threat_per_entity" TO "service_role";



GRANT ALL ON TABLE "public"."latest_threat_with_level" TO "anon";
GRANT ALL ON TABLE "public"."latest_threat_with_level" TO "authenticated";
GRANT ALL ON TABLE "public"."latest_threat_with_level" TO "service_role";



GRANT ALL ON TABLE "public"."latest_relevant_threats" TO "anon";
GRANT ALL ON TABLE "public"."latest_relevant_threats" TO "authenticated";
GRANT ALL ON TABLE "public"."latest_relevant_threats" TO "service_role";



GRANT ALL ON TABLE "public"."area_intel_patrol_links" TO "anon";
GRANT ALL ON TABLE "public"."area_intel_patrol_links" TO "authenticated";
GRANT ALL ON TABLE "public"."area_intel_patrol_links" TO "service_role";



GRANT ALL ON TABLE "public"."checkins" TO "anon";
GRANT ALL ON TABLE "public"."checkins" TO "authenticated";
GRANT ALL ON TABLE "public"."checkins" TO "service_role";



GRANT ALL ON TABLE "public"."civic_events" TO "anon";
GRANT ALL ON TABLE "public"."civic_events" TO "authenticated";
GRANT ALL ON TABLE "public"."civic_events" TO "service_role";



GRANT ALL ON TABLE "public"."client_contact_endpoint_subscriptions" TO "anon";
GRANT ALL ON TABLE "public"."client_contact_endpoint_subscriptions" TO "authenticated";
GRANT ALL ON TABLE "public"."client_contact_endpoint_subscriptions" TO "service_role";



GRANT ALL ON TABLE "public"."client_contacts" TO "anon";
GRANT ALL ON TABLE "public"."client_contacts" TO "authenticated";
GRANT ALL ON TABLE "public"."client_contacts" TO "service_role";



GRANT ALL ON TABLE "public"."client_conversation_acknowledgements" TO "anon";
GRANT ALL ON TABLE "public"."client_conversation_acknowledgements" TO "authenticated";
GRANT ALL ON TABLE "public"."client_conversation_acknowledgements" TO "service_role";



GRANT ALL ON TABLE "public"."client_conversation_messages" TO "anon";
GRANT ALL ON TABLE "public"."client_conversation_messages" TO "authenticated";
GRANT ALL ON TABLE "public"."client_conversation_messages" TO "service_role";



GRANT ALL ON TABLE "public"."client_conversation_push_queue" TO "anon";
GRANT ALL ON TABLE "public"."client_conversation_push_queue" TO "authenticated";
GRANT ALL ON TABLE "public"."client_conversation_push_queue" TO "service_role";



GRANT ALL ON TABLE "public"."client_conversation_push_sync_state" TO "anon";
GRANT ALL ON TABLE "public"."client_conversation_push_sync_state" TO "authenticated";
GRANT ALL ON TABLE "public"."client_conversation_push_sync_state" TO "service_role";



GRANT ALL ON TABLE "public"."client_evidence_ledger" TO "anon";
GRANT ALL ON TABLE "public"."client_evidence_ledger" TO "authenticated";
GRANT ALL ON TABLE "public"."client_evidence_ledger" TO "service_role";



GRANT ALL ON TABLE "public"."client_messaging_endpoints" TO "anon";
GRANT ALL ON TABLE "public"."client_messaging_endpoints" TO "authenticated";
GRANT ALL ON TABLE "public"."client_messaging_endpoints" TO "service_role";



GRANT ALL ON TABLE "public"."clients" TO "anon";
GRANT ALL ON TABLE "public"."clients" TO "authenticated";
GRANT ALL ON TABLE "public"."clients" TO "service_role";



GRANT ALL ON TABLE "public"."command_events" TO "anon";
GRANT ALL ON TABLE "public"."command_events" TO "authenticated";
GRANT ALL ON TABLE "public"."command_events" TO "service_role";



GRANT ALL ON TABLE "public"."patrol_route_recommendations" TO "anon";
GRANT ALL ON TABLE "public"."patrol_route_recommendations" TO "authenticated";
GRANT ALL ON TABLE "public"."patrol_route_recommendations" TO "service_role";



GRANT ALL ON TABLE "public"."command_patrol_recommendations" TO "anon";
GRANT ALL ON TABLE "public"."command_patrol_recommendations" TO "authenticated";
GRANT ALL ON TABLE "public"."command_patrol_recommendations" TO "service_role";



GRANT ALL ON TABLE "public"."command_summaries" TO "anon";
GRANT ALL ON TABLE "public"."command_summaries" TO "authenticated";
GRANT ALL ON TABLE "public"."command_summaries" TO "service_role";



GRANT ALL ON TABLE "public"."controllers" TO "anon";
GRANT ALL ON TABLE "public"."controllers" TO "authenticated";
GRANT ALL ON TABLE "public"."controllers" TO "service_role";



GRANT ALL ON TABLE "public"."decision_audit_log" TO "anon";
GRANT ALL ON TABLE "public"."decision_audit_log" TO "authenticated";
GRANT ALL ON TABLE "public"."decision_audit_log" TO "service_role";



GRANT ALL ON TABLE "public"."decision_traces" TO "anon";
GRANT ALL ON TABLE "public"."decision_traces" TO "authenticated";
GRANT ALL ON TABLE "public"."decision_traces" TO "service_role";



GRANT ALL ON TABLE "public"."demo_state" TO "anon";
GRANT ALL ON TABLE "public"."demo_state" TO "authenticated";
GRANT ALL ON TABLE "public"."demo_state" TO "service_role";



GRANT ALL ON TABLE "public"."deployments" TO "anon";
GRANT ALL ON TABLE "public"."deployments" TO "authenticated";
GRANT ALL ON TABLE "public"."deployments" TO "service_role";



GRANT ALL ON TABLE "public"."dispatch_actions" TO "anon";
GRANT ALL ON TABLE "public"."dispatch_actions" TO "authenticated";
GRANT ALL ON TABLE "public"."dispatch_actions" TO "service_role";



GRANT ALL ON TABLE "public"."dispatch_intents" TO "anon";
GRANT ALL ON TABLE "public"."dispatch_intents" TO "authenticated";
GRANT ALL ON TABLE "public"."dispatch_intents" TO "service_role";



GRANT ALL ON TABLE "public"."dispatch_transitions" TO "anon";
GRANT ALL ON TABLE "public"."dispatch_transitions" TO "authenticated";
GRANT ALL ON TABLE "public"."dispatch_transitions" TO "service_role";



GRANT ALL ON TABLE "public"."dispatch_current_state" TO "anon";
GRANT ALL ON TABLE "public"."dispatch_current_state" TO "authenticated";
GRANT ALL ON TABLE "public"."dispatch_current_state" TO "service_role";



GRANT ALL ON TABLE "public"."duty_states" TO "anon";
GRANT ALL ON TABLE "public"."duty_states" TO "authenticated";
GRANT ALL ON TABLE "public"."duty_states" TO "service_role";



GRANT ALL ON TABLE "public"."employee_site_assignments" TO "anon";
GRANT ALL ON TABLE "public"."employee_site_assignments" TO "authenticated";
GRANT ALL ON TABLE "public"."employee_site_assignments" TO "service_role";



GRANT ALL ON TABLE "public"."employees" TO "anon";
GRANT ALL ON TABLE "public"."employees" TO "authenticated";
GRANT ALL ON TABLE "public"."employees" TO "service_role";



GRANT ALL ON TABLE "public"."escalation_events" TO "anon";
GRANT ALL ON TABLE "public"."escalation_events" TO "authenticated";
GRANT ALL ON TABLE "public"."escalation_events" TO "service_role";



GRANT ALL ON TABLE "public"."evidence_bundles" TO "anon";
GRANT ALL ON TABLE "public"."evidence_bundles" TO "authenticated";
GRANT ALL ON TABLE "public"."evidence_bundles" TO "service_role";



GRANT ALL ON TABLE "public"."execution_locks" TO "anon";
GRANT ALL ON TABLE "public"."execution_locks" TO "authenticated";
GRANT ALL ON TABLE "public"."execution_locks" TO "service_role";



GRANT ALL ON TABLE "public"."execution_system_health" TO "anon";
GRANT ALL ON TABLE "public"."execution_system_health" TO "authenticated";
GRANT ALL ON TABLE "public"."execution_system_health" TO "service_role";



GRANT ALL ON TABLE "public"."external_signals" TO "anon";
GRANT ALL ON TABLE "public"."external_signals" TO "authenticated";
GRANT ALL ON TABLE "public"."external_signals" TO "service_role";



GRANT ALL ON TABLE "public"."fr_person_registry" TO "anon";
GRANT ALL ON TABLE "public"."fr_person_registry" TO "authenticated";
GRANT ALL ON TABLE "public"."fr_person_registry" TO "service_role";



GRANT ALL ON TABLE "public"."global_clusters" TO "anon";
GRANT ALL ON TABLE "public"."global_clusters" TO "authenticated";
GRANT ALL ON TABLE "public"."global_clusters" TO "service_role";



GRANT ALL ON TABLE "public"."global_events" TO "anon";
GRANT ALL ON TABLE "public"."global_events" TO "authenticated";
GRANT ALL ON TABLE "public"."global_events" TO "service_role";



GRANT ALL ON TABLE "public"."global_patterns" TO "anon";
GRANT ALL ON TABLE "public"."global_patterns" TO "authenticated";
GRANT ALL ON TABLE "public"."global_patterns" TO "service_role";



GRANT ALL ON TABLE "public"."guard_assignments" TO "anon";
GRANT ALL ON TABLE "public"."guard_assignments" TO "authenticated";
GRANT ALL ON TABLE "public"."guard_assignments" TO "service_role";



GRANT ALL ON TABLE "public"."guard_checkpoint_scans" TO "anon";
GRANT ALL ON TABLE "public"."guard_checkpoint_scans" TO "authenticated";
GRANT ALL ON TABLE "public"."guard_checkpoint_scans" TO "service_role";



GRANT ALL ON TABLE "public"."guard_documents" TO "anon";
GRANT ALL ON TABLE "public"."guard_documents" TO "authenticated";
GRANT ALL ON TABLE "public"."guard_documents" TO "service_role";



GRANT ALL ON TABLE "public"."guard_incident_captures" TO "anon";
GRANT ALL ON TABLE "public"."guard_incident_captures" TO "authenticated";
GRANT ALL ON TABLE "public"."guard_incident_captures" TO "service_role";



GRANT ALL ON TABLE "public"."guard_location_heartbeats" TO "anon";
GRANT ALL ON TABLE "public"."guard_location_heartbeats" TO "authenticated";
GRANT ALL ON TABLE "public"."guard_location_heartbeats" TO "service_role";



GRANT ALL ON TABLE "public"."guard_logs" TO "anon";
GRANT ALL ON TABLE "public"."guard_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."guard_logs" TO "service_role";



GRANT ALL ON TABLE "public"."guard_ops_events" TO "anon";
GRANT ALL ON TABLE "public"."guard_ops_events" TO "authenticated";
GRANT ALL ON TABLE "public"."guard_ops_events" TO "service_role";



GRANT ALL ON TABLE "public"."guard_ops_media" TO "anon";
GRANT ALL ON TABLE "public"."guard_ops_media" TO "authenticated";
GRANT ALL ON TABLE "public"."guard_ops_media" TO "service_role";



GRANT ALL ON TABLE "public"."guard_panic_signals" TO "anon";
GRANT ALL ON TABLE "public"."guard_panic_signals" TO "authenticated";
GRANT ALL ON TABLE "public"."guard_panic_signals" TO "service_role";



GRANT ALL ON TABLE "public"."guard_profiles" TO "anon";
GRANT ALL ON TABLE "public"."guard_profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."guard_profiles" TO "service_role";



GRANT ALL ON TABLE "public"."guard_rls_readiness_checks" TO "anon";
GRANT ALL ON TABLE "public"."guard_rls_readiness_checks" TO "authenticated";
GRANT ALL ON TABLE "public"."guard_rls_readiness_checks" TO "service_role";



GRANT ALL ON TABLE "public"."guard_sites" TO "anon";
GRANT ALL ON TABLE "public"."guard_sites" TO "authenticated";
GRANT ALL ON TABLE "public"."guard_sites" TO "service_role";



GRANT ALL ON TABLE "public"."guard_storage_readiness_checks" TO "anon";
GRANT ALL ON TABLE "public"."guard_storage_readiness_checks" TO "authenticated";
GRANT ALL ON TABLE "public"."guard_storage_readiness_checks" TO "service_role";



GRANT ALL ON TABLE "public"."guard_sync_operations" TO "anon";
GRANT ALL ON TABLE "public"."guard_sync_operations" TO "authenticated";
GRANT ALL ON TABLE "public"."guard_sync_operations" TO "service_role";



GRANT ALL ON TABLE "public"."guards" TO "anon";
GRANT ALL ON TABLE "public"."guards" TO "authenticated";
GRANT ALL ON TABLE "public"."guards" TO "service_role";



GRANT ALL ON TABLE "public"."hourly_throughput" TO "anon";
GRANT ALL ON TABLE "public"."hourly_throughput" TO "authenticated";
GRANT ALL ON TABLE "public"."hourly_throughput" TO "service_role";



GRANT ALL ON TABLE "public"."incident_actions" TO "anon";
GRANT ALL ON TABLE "public"."incident_actions" TO "authenticated";
GRANT ALL ON TABLE "public"."incident_actions" TO "service_role";



GRANT ALL ON TABLE "public"."incident_outcomes" TO "anon";
GRANT ALL ON TABLE "public"."incident_outcomes" TO "authenticated";
GRANT ALL ON TABLE "public"."incident_outcomes" TO "service_role";



GRANT ALL ON TABLE "public"."incident_snapshots" TO "anon";
GRANT ALL ON TABLE "public"."incident_snapshots" TO "authenticated";
GRANT ALL ON TABLE "public"."incident_snapshots" TO "service_role";



GRANT ALL ON TABLE "public"."incident_replay_timeline" TO "anon";
GRANT ALL ON TABLE "public"."incident_replay_timeline" TO "authenticated";
GRANT ALL ON TABLE "public"."incident_replay_timeline" TO "service_role";



GRANT ALL ON TABLE "public"."incident_aar_metrics" TO "anon";
GRANT ALL ON TABLE "public"."incident_aar_metrics" TO "authenticated";
GRANT ALL ON TABLE "public"."incident_aar_metrics" TO "service_role";



GRANT ALL ON TABLE "public"."incident_aar_score_calc" TO "anon";
GRANT ALL ON TABLE "public"."incident_aar_score_calc" TO "authenticated";
GRANT ALL ON TABLE "public"."incident_aar_score_calc" TO "service_role";



GRANT ALL ON TABLE "public"."incident_aar_grade_calc" TO "anon";
GRANT ALL ON TABLE "public"."incident_aar_grade_calc" TO "authenticated";
GRANT ALL ON TABLE "public"."incident_aar_grade_calc" TO "service_role";



GRANT ALL ON TABLE "public"."incident_aar_scores" TO "anon";
GRANT ALL ON TABLE "public"."incident_aar_scores" TO "authenticated";
GRANT ALL ON TABLE "public"."incident_aar_scores" TO "service_role";



GRANT ALL ON TABLE "public"."incident_intelligence" TO "anon";
GRANT ALL ON TABLE "public"."incident_intelligence" TO "authenticated";
GRANT ALL ON TABLE "public"."incident_intelligence" TO "service_role";



GRANT ALL ON TABLE "public"."incident_replay_events" TO "anon";
GRANT ALL ON TABLE "public"."incident_replay_events" TO "authenticated";
GRANT ALL ON TABLE "public"."incident_replay_events" TO "service_role";



GRANT ALL ON TABLE "public"."incident_replays" TO "anon";
GRANT ALL ON TABLE "public"."incident_replays" TO "authenticated";
GRANT ALL ON TABLE "public"."incident_replays" TO "service_role";



GRANT ALL ON TABLE "public"."incidents" TO "anon";
GRANT ALL ON TABLE "public"."incidents" TO "authenticated";
GRANT ALL ON TABLE "public"."incidents" TO "service_role";



GRANT ALL ON TABLE "public"."intel_keyword_events" TO "anon";
GRANT ALL ON TABLE "public"."intel_keyword_events" TO "authenticated";
GRANT ALL ON TABLE "public"."intel_keyword_events" TO "service_role";



GRANT ALL ON TABLE "public"."intel_patrol_links" TO "anon";
GRANT ALL ON TABLE "public"."intel_patrol_links" TO "authenticated";
GRANT ALL ON TABLE "public"."intel_patrol_links" TO "service_role";



GRANT ALL ON TABLE "public"."intel_source_weights" TO "anon";
GRANT ALL ON TABLE "public"."intel_source_weights" TO "authenticated";
GRANT ALL ON TABLE "public"."intel_source_weights" TO "service_role";



GRANT ALL ON TABLE "public"."intel_scoring_candidates" TO "anon";
GRANT ALL ON TABLE "public"."intel_scoring_candidates" TO "authenticated";
GRANT ALL ON TABLE "public"."intel_scoring_candidates" TO "service_role";



GRANT ALL ON TABLE "public"."intel_scoring_candidates_strategic" TO "anon";
GRANT ALL ON TABLE "public"."intel_scoring_candidates_strategic" TO "authenticated";
GRANT ALL ON TABLE "public"."intel_scoring_candidates_strategic" TO "service_role";



GRANT ALL ON TABLE "public"."intel_scoring_candidates_unlinked" TO "anon";
GRANT ALL ON TABLE "public"."intel_scoring_candidates_unlinked" TO "authenticated";
GRANT ALL ON TABLE "public"."intel_scoring_candidates_unlinked" TO "service_role";



GRANT ALL ON TABLE "public"."intelligence_snapshots" TO "anon";
GRANT ALL ON TABLE "public"."intelligence_snapshots" TO "authenticated";
GRANT ALL ON TABLE "public"."intelligence_snapshots" TO "service_role";



GRANT ALL ON TABLE "public"."keyword_escalations" TO "anon";
GRANT ALL ON TABLE "public"."keyword_escalations" TO "authenticated";
GRANT ALL ON TABLE "public"."keyword_escalations" TO "service_role";



GRANT ALL ON TABLE "public"."keyword_trend_spikes" TO "anon";
GRANT ALL ON TABLE "public"."keyword_trend_spikes" TO "authenticated";
GRANT ALL ON TABLE "public"."keyword_trend_spikes" TO "service_role";



GRANT ALL ON TABLE "public"."logs" TO "anon";
GRANT ALL ON TABLE "public"."logs" TO "authenticated";
GRANT ALL ON TABLE "public"."logs" TO "service_role";



GRANT ALL ON SEQUENCE "public"."logs_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."logs_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."logs_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."mo_library" TO "anon";
GRANT ALL ON TABLE "public"."mo_library" TO "authenticated";
GRANT ALL ON TABLE "public"."mo_library" TO "service_role";



GRANT ALL ON TABLE "public"."omnix_logs" TO "anon";
GRANT ALL ON TABLE "public"."omnix_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."omnix_logs" TO "service_role";



GRANT ALL ON TABLE "public"."onyx_alert_outcomes" TO "anon";
GRANT ALL ON TABLE "public"."onyx_alert_outcomes" TO "authenticated";
GRANT ALL ON TABLE "public"."onyx_alert_outcomes" TO "service_role";



GRANT ALL ON TABLE "public"."onyx_awareness_latency" TO "anon";
GRANT ALL ON TABLE "public"."onyx_awareness_latency" TO "authenticated";
GRANT ALL ON TABLE "public"."onyx_awareness_latency" TO "service_role";



GRANT ALL ON TABLE "public"."onyx_client_trust_snapshots" TO "anon";
GRANT ALL ON TABLE "public"."onyx_client_trust_snapshots" TO "authenticated";
GRANT ALL ON TABLE "public"."onyx_client_trust_snapshots" TO "service_role";



GRANT ALL ON TABLE "public"."onyx_event_store" TO "anon";
GRANT ALL ON TABLE "public"."onyx_event_store" TO "authenticated";
GRANT ALL ON TABLE "public"."onyx_event_store" TO "service_role";



GRANT ALL ON TABLE "public"."onyx_evidence_certificates" TO "anon";
GRANT ALL ON TABLE "public"."onyx_evidence_certificates" TO "authenticated";
GRANT ALL ON TABLE "public"."onyx_evidence_certificates" TO "service_role";



GRANT ALL ON TABLE "public"."onyx_operator_scores" TO "anon";
GRANT ALL ON TABLE "public"."onyx_operator_scores" TO "authenticated";
GRANT ALL ON TABLE "public"."onyx_operator_scores" TO "service_role";



GRANT ALL ON TABLE "public"."onyx_operator_simulations" TO "anon";
GRANT ALL ON TABLE "public"."onyx_operator_simulations" TO "authenticated";
GRANT ALL ON TABLE "public"."onyx_operator_simulations" TO "service_role";



GRANT ALL ON TABLE "public"."onyx_power_mode_events" TO "anon";
GRANT ALL ON TABLE "public"."onyx_power_mode_events" TO "authenticated";
GRANT ALL ON TABLE "public"."onyx_power_mode_events" TO "service_role";



GRANT ALL ON TABLE "public"."onyx_settings" TO "anon";
GRANT ALL ON TABLE "public"."onyx_settings" TO "authenticated";
GRANT ALL ON TABLE "public"."onyx_settings" TO "service_role";



GRANT ALL ON TABLE "public"."operational_nodes" TO "anon";
GRANT ALL ON TABLE "public"."operational_nodes" TO "authenticated";
GRANT ALL ON TABLE "public"."operational_nodes" TO "service_role";



GRANT ALL ON TABLE "public"."ops_orders" TO "anon";
GRANT ALL ON TABLE "public"."ops_orders" TO "authenticated";
GRANT ALL ON TABLE "public"."ops_orders" TO "service_role";



GRANT ALL ON TABLE "public"."patrol_checkpoint_scans" TO "anon";
GRANT ALL ON TABLE "public"."patrol_checkpoint_scans" TO "authenticated";
GRANT ALL ON TABLE "public"."patrol_checkpoint_scans" TO "service_role";



GRANT ALL ON TABLE "public"."patrol_checkpoints" TO "anon";
GRANT ALL ON TABLE "public"."patrol_checkpoints" TO "authenticated";
GRANT ALL ON TABLE "public"."patrol_checkpoints" TO "service_role";



GRANT ALL ON TABLE "public"."patrol_compliance" TO "anon";
GRANT ALL ON TABLE "public"."patrol_compliance" TO "authenticated";
GRANT ALL ON TABLE "public"."patrol_compliance" TO "service_role";



GRANT ALL ON TABLE "public"."patrol_route_cooldowns" TO "anon";
GRANT ALL ON TABLE "public"."patrol_route_cooldowns" TO "authenticated";
GRANT ALL ON TABLE "public"."patrol_route_cooldowns" TO "service_role";



GRANT ALL ON TABLE "public"."patrol_routes" TO "anon";
GRANT ALL ON TABLE "public"."patrol_routes" TO "authenticated";
GRANT ALL ON TABLE "public"."patrol_routes" TO "service_role";



GRANT ALL ON TABLE "public"."patrol_routing_candidates" TO "anon";
GRANT ALL ON TABLE "public"."patrol_routing_candidates" TO "authenticated";
GRANT ALL ON TABLE "public"."patrol_routing_candidates" TO "service_role";



GRANT ALL ON TABLE "public"."patrol_scans" TO "anon";
GRANT ALL ON TABLE "public"."patrol_scans" TO "authenticated";
GRANT ALL ON TABLE "public"."patrol_scans" TO "service_role";



GRANT ALL ON TABLE "public"."patrol_violations" TO "anon";
GRANT ALL ON TABLE "public"."patrol_violations" TO "authenticated";
GRANT ALL ON TABLE "public"."patrol_violations" TO "service_role";



GRANT ALL ON TABLE "public"."patrols" TO "anon";
GRANT ALL ON TABLE "public"."patrols" TO "authenticated";
GRANT ALL ON TABLE "public"."patrols" TO "service_role";



GRANT ALL ON TABLE "public"."posts" TO "anon";
GRANT ALL ON TABLE "public"."posts" TO "authenticated";
GRANT ALL ON TABLE "public"."posts" TO "service_role";



GRANT ALL ON TABLE "public"."regional_risk_snapshots" TO "anon";
GRANT ALL ON TABLE "public"."regional_risk_snapshots" TO "authenticated";
GRANT ALL ON TABLE "public"."regional_risk_snapshots" TO "service_role";



GRANT ALL ON TABLE "public"."roles" TO "anon";
GRANT ALL ON TABLE "public"."roles" TO "authenticated";
GRANT ALL ON TABLE "public"."roles" TO "service_role";



GRANT ALL ON SEQUENCE "public"."roles_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."roles_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."roles_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."site_alarm_events" TO "anon";
GRANT ALL ON TABLE "public"."site_alarm_events" TO "authenticated";
GRANT ALL ON TABLE "public"."site_alarm_events" TO "service_role";



GRANT ALL ON TABLE "public"."site_alert_config" TO "anon";
GRANT ALL ON TABLE "public"."site_alert_config" TO "authenticated";
GRANT ALL ON TABLE "public"."site_alert_config" TO "service_role";



GRANT ALL ON TABLE "public"."site_api_tokens" TO "anon";
GRANT ALL ON TABLE "public"."site_api_tokens" TO "authenticated";
GRANT ALL ON TABLE "public"."site_api_tokens" TO "service_role";



GRANT ALL ON TABLE "public"."site_awareness_snapshots" TO "anon";
GRANT ALL ON TABLE "public"."site_awareness_snapshots" TO "authenticated";
GRANT ALL ON TABLE "public"."site_awareness_snapshots" TO "service_role";



GRANT ALL ON TABLE "public"."site_camera_zones" TO "anon";
GRANT ALL ON TABLE "public"."site_camera_zones" TO "authenticated";
GRANT ALL ON TABLE "public"."site_camera_zones" TO "service_role";



GRANT ALL ON TABLE "public"."site_expected_visitors" TO "anon";
GRANT ALL ON TABLE "public"."site_expected_visitors" TO "authenticated";
GRANT ALL ON TABLE "public"."site_expected_visitors" TO "service_role";



GRANT ALL ON TABLE "public"."site_identity_approval_decisions" TO "anon";
GRANT ALL ON TABLE "public"."site_identity_approval_decisions" TO "authenticated";
GRANT ALL ON TABLE "public"."site_identity_approval_decisions" TO "service_role";



GRANT ALL ON TABLE "public"."site_identity_profiles" TO "anon";
GRANT ALL ON TABLE "public"."site_identity_profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."site_identity_profiles" TO "service_role";



GRANT ALL ON TABLE "public"."site_intelligence_profiles" TO "anon";
GRANT ALL ON TABLE "public"."site_intelligence_profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."site_intelligence_profiles" TO "service_role";



GRANT ALL ON TABLE "public"."site_occupancy_config" TO "anon";
GRANT ALL ON TABLE "public"."site_occupancy_config" TO "authenticated";
GRANT ALL ON TABLE "public"."site_occupancy_config" TO "service_role";



GRANT ALL ON TABLE "public"."site_occupancy_sessions" TO "anon";
GRANT ALL ON TABLE "public"."site_occupancy_sessions" TO "authenticated";
GRANT ALL ON TABLE "public"."site_occupancy_sessions" TO "service_role";



GRANT ALL ON TABLE "public"."site_vehicle_registry" TO "anon";
GRANT ALL ON TABLE "public"."site_vehicle_registry" TO "authenticated";
GRANT ALL ON TABLE "public"."site_vehicle_registry" TO "service_role";



GRANT ALL ON TABLE "public"."site_zone_rules" TO "anon";
GRANT ALL ON TABLE "public"."site_zone_rules" TO "authenticated";
GRANT ALL ON TABLE "public"."site_zone_rules" TO "service_role";



GRANT ALL ON TABLE "public"."site_zones" TO "anon";
GRANT ALL ON TABLE "public"."site_zones" TO "authenticated";
GRANT ALL ON TABLE "public"."site_zones" TO "service_role";



GRANT ALL ON TABLE "public"."sites" TO "anon";
GRANT ALL ON TABLE "public"."sites" TO "authenticated";
GRANT ALL ON TABLE "public"."sites" TO "service_role";



GRANT ALL ON TABLE "public"."staff" TO "anon";
GRANT ALL ON TABLE "public"."staff" TO "authenticated";
GRANT ALL ON TABLE "public"."staff" TO "service_role";



GRANT ALL ON TABLE "public"."telegram_identity_intake" TO "anon";
GRANT ALL ON TABLE "public"."telegram_identity_intake" TO "authenticated";
GRANT ALL ON TABLE "public"."telegram_identity_intake" TO "service_role";



GRANT ALL ON TABLE "public"."telegram_inbound_updates" TO "anon";
GRANT ALL ON TABLE "public"."telegram_inbound_updates" TO "authenticated";
GRANT ALL ON TABLE "public"."telegram_inbound_updates" TO "service_role";



GRANT ALL ON TABLE "public"."threat_assessments" TO "anon";
GRANT ALL ON TABLE "public"."threat_assessments" TO "authenticated";
GRANT ALL ON TABLE "public"."threat_assessments" TO "service_role";



GRANT ALL ON TABLE "public"."threat_decay_profiles" TO "anon";
GRANT ALL ON TABLE "public"."threat_decay_profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."threat_decay_profiles" TO "service_role";



GRANT ALL ON TABLE "public"."threats" TO "anon";
GRANT ALL ON TABLE "public"."threats" TO "authenticated";
GRANT ALL ON TABLE "public"."threats" TO "service_role";



GRANT ALL ON TABLE "public"."users" TO "anon";
GRANT ALL ON TABLE "public"."users" TO "authenticated";
GRANT ALL ON TABLE "public"."users" TO "service_role";



GRANT ALL ON TABLE "public"."vehicle_logs" TO "anon";
GRANT ALL ON TABLE "public"."vehicle_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."vehicle_logs" TO "service_role";



GRANT ALL ON TABLE "public"."vehicle_visits" TO "anon";
GRANT ALL ON TABLE "public"."vehicle_visits" TO "authenticated";
GRANT ALL ON TABLE "public"."vehicle_visits" TO "service_role";



GRANT ALL ON TABLE "public"."vehicles" TO "anon";
GRANT ALL ON TABLE "public"."vehicles" TO "authenticated";
GRANT ALL ON TABLE "public"."vehicles" TO "service_role";



GRANT ALL ON TABLE "public"."violations" TO "anon";
GRANT ALL ON TABLE "public"."violations" TO "authenticated";
GRANT ALL ON TABLE "public"."violations" TO "service_role";



GRANT ALL ON TABLE "public"."watch_archive" TO "anon";
GRANT ALL ON TABLE "public"."watch_archive" TO "authenticated";
GRANT ALL ON TABLE "public"."watch_archive" TO "service_role";



GRANT ALL ON TABLE "public"."watch_current_state" TO "anon";
GRANT ALL ON TABLE "public"."watch_current_state" TO "authenticated";
GRANT ALL ON TABLE "public"."watch_current_state" TO "service_role";



GRANT ALL ON TABLE "public"."watch_events" TO "anon";
GRANT ALL ON TABLE "public"."watch_events" TO "authenticated";
GRANT ALL ON TABLE "public"."watch_events" TO "service_role";



GRANT ALL ON TABLE "public"."zara_action_log" TO "anon";
GRANT ALL ON TABLE "public"."zara_action_log" TO "authenticated";
GRANT ALL ON TABLE "public"."zara_action_log" TO "service_role";



GRANT ALL ON TABLE "public"."zara_scenarios" TO "anon";
GRANT ALL ON TABLE "public"."zara_scenarios" TO "authenticated";
GRANT ALL ON TABLE "public"."zara_scenarios" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";


-- ============================================================================
-- End of reverse-engineered baseline.
--
-- Verification note (2026-04-21):
-- Applied to scratch Postgres 17.9 at localhost:55432 database
-- `baseline_verify2`, pre-populated with:
--   * schemas: extensions, graphql, vault, auth, storage
--   * roles:   service_role, authenticated, anon
--   * extensions: pgcrypto, uuid-ossp (both in schema `extensions`)
--   * stubs:   auth.uid() -> NULL::uuid, auth.jwt() -> '{}'::jsonb,
--              storage.objects (minimal table)
-- Extensions commented out (unavailable in Homebrew Postgres 17, present
-- on any Supabase target): pg_cron, pg_graphql, postgis, supabase_vault.
--
-- Object count after apply (live on left, scratch on right):
--   tables                   129  |  127   (sites + intel_events missing: PostGIS)
--   views                     24  |   17   (7 PostGIS/storage dependents)
--   functions (public)        32  |   32   MATCH
--   triggers                  37  |   34   (cascade of missing tables)
--   policies                 157  |  146   (cascade of missing tables)
--   enums                     14  |   14   MATCH
--   sequences                  2  |    2   MATCH
--   RLS-enabled               63  |   62   (sites cascade)
--   FK constraints            57  |   42   (cascade to missing tables)
--
-- On a Supabase project target with PostGIS + pg_graphql + pg_cron
-- + supabase_vault installed and the standard auth + storage schemas
-- live, all 129 tables are expected to apply cleanly.
-- ============================================================================
