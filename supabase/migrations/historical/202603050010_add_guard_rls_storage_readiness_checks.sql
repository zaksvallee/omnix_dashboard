-- ONYX guard readiness checks for storage + RLS policy coverage.

create or replace view public.guard_storage_readiness_checks as
with expected_buckets(bucket_name) as (
  values
    ('guard-shift-verification'::text),
    ('guard-patrol-images'::text),
    ('guard-incident-media'::text)
),
expected_storage_policies(policy_name) as (
  values
    ('guard_media_select_policy'::text),
    ('guard_media_insert_policy'::text),
    ('guard_media_update_policy'::text),
    ('guard_media_delete_policy'::text)
),
storage_rls as (
  select
    case when c.relrowsecurity then 'PASS' else 'FAIL' end as result
  from pg_class c
  join pg_namespace n
    on n.oid = c.relnamespace
  where n.nspname = 'storage'
    and c.relname = 'objects'
)
select
  'bucket'::text as check_type,
  bucket_name as check_name,
  case
    when exists (
      select 1
      from storage.buckets b
      where b.name = expected_buckets.bucket_name
    ) then 'PASS'
    else 'FAIL'
  end as result
from expected_buckets
union all
select
  'policy'::text as check_type,
  policy_name as check_name,
  case
    when exists (
      select 1
      from pg_policies p
      where p.schemaname = 'storage'
        and p.tablename = 'objects'
        and p.policyname = expected_storage_policies.policy_name
    ) then 'PASS'
    else 'FAIL'
  end as result
from expected_storage_policies
union all
select
  'storage_rls'::text as check_type,
  'storage.objects'::text as check_name,
  coalesce((select result from storage_rls), 'FAIL') as result;

create or replace view public.guard_rls_readiness_checks as
with expected_guard_tables(table_name) as (
  values
    ('guard_ops_events'::text),
    ('guard_ops_media'::text),
    ('guard_sync_operations'::text),
    ('guard_assignments'::text),
    ('guard_location_heartbeats'::text),
    ('guard_checkpoint_scans'::text),
    ('guard_incident_captures'::text),
    ('guard_panic_signals'::text)
),
expected_guard_policies(table_name, policy_name) as (
  values
    ('guard_ops_events'::text, 'guard_ops_events_select_policy'::text),
    ('guard_ops_events'::text, 'guard_ops_events_insert_policy'::text),
    ('guard_ops_media'::text, 'guard_ops_media_select_policy'::text),
    ('guard_ops_media'::text, 'guard_ops_media_insert_policy'::text),
    ('guard_ops_media'::text, 'guard_ops_media_update_policy'::text),
    ('guard_sync_operations'::text, 'guard_sync_operations_select_policy'::text),
    ('guard_sync_operations'::text, 'guard_sync_operations_insert_policy'::text),
    ('guard_sync_operations'::text, 'guard_sync_operations_update_policy'::text),
    ('guard_assignments'::text, 'guard_assignments_select_policy'::text),
    ('guard_assignments'::text, 'guard_assignments_insert_policy'::text),
    ('guard_assignments'::text, 'guard_assignments_update_policy'::text),
    ('guard_location_heartbeats'::text, 'guard_location_heartbeats_select_policy'::text),
    ('guard_location_heartbeats'::text, 'guard_location_heartbeats_insert_policy'::text),
    ('guard_checkpoint_scans'::text, 'guard_checkpoint_scans_select_policy'::text),
    ('guard_checkpoint_scans'::text, 'guard_checkpoint_scans_insert_policy'::text),
    ('guard_incident_captures'::text, 'guard_incident_captures_select_policy'::text),
    ('guard_incident_captures'::text, 'guard_incident_captures_insert_policy'::text),
    ('guard_panic_signals'::text, 'guard_panic_signals_select_policy'::text),
    ('guard_panic_signals'::text, 'guard_panic_signals_insert_policy'::text)
)
select
  'table_rls'::text as check_type,
  table_name as check_name,
  case
    when exists (
      select 1
      from pg_class c
      join pg_namespace n
        on n.oid = c.relnamespace
      where n.nspname = 'public'
        and c.relname = expected_guard_tables.table_name
        and c.relrowsecurity
    ) then 'PASS'
    else 'FAIL'
  end as result
from expected_guard_tables
union all
select
  'table_policy'::text as check_type,
  format('%s.%s', table_name, policy_name) as check_name,
  case
    when exists (
      select 1
      from pg_policies p
      where p.schemaname = 'public'
        and p.tablename = expected_guard_policies.table_name
        and p.policyname = expected_guard_policies.policy_name
    ) then 'PASS'
    else 'FAIL'
  end as result
from expected_guard_policies;
