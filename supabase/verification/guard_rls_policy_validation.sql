-- ONYX Guard RLS Policy Validation Script
--
-- Run after:
-- 1) guard table migrations are applied
-- 2) 20260304_apply_guard_rls_storage_policies.sql is applied
--
-- Recommended execution:
-- - Supabase SQL editor (staging/pilot first), or
-- - psql against linked project
--
-- Behavior:
-- - runs in a transaction
-- - performs positive and negative checks using controlled JWT claims
-- - rolls back all inserted rows

begin;

set local role authenticated;

do $$
declare
  allowed_sequence integer := floor(extract(epoch from clock_timestamp()))::integer;
begin
  -- ------------------------------------------------------------
  -- CASE 1: guard can insert own-site, own-guard event
  -- ------------------------------------------------------------
  perform set_config(
    'request.jwt.claims',
    json_build_object(
      'role_type', 'guard',
      'client_id', 'CLIENT-001',
      'guard_id', 'GUARD-001',
      'site_ids', json_build_array('SITE-SANDTON')
    )::text,
    true
  );

  insert into public.guard_ops_events (
    event_id,
    guard_id,
    site_id,
    shift_id,
    event_type,
    sequence,
    occurred_at,
    device_id,
    app_version,
    payload
  ) values (
    'RLS-TEST-EVT-ALLOW-' || allowed_sequence::text,
    'GUARD-001',
    'SITE-SANDTON',
    'SHIFT-RLS-TEST',
    'statusChanged',
    allowed_sequence,
    timezone('utc', now()),
    'TEST-DEVICE-001',
    'test',
    json_build_object('source', 'rls-validation')
  );

  -- ------------------------------------------------------------
  -- CASE 2: guard cannot insert for another guard_id
  -- ------------------------------------------------------------
  begin
    insert into public.guard_sync_operations (
      operation_id,
      operation_type,
      operation_status,
      client_id,
      site_id,
      guard_id,
      occurred_at,
      payload
    ) values (
      'RLS-TEST-OP-DENY-GUARD-' || allowed_sequence::text,
      'statusUpdate',
      'queued',
      'CLIENT-001',
      'SITE-SANDTON',
      'GUARD-999',
      timezone('utc', now()),
      json_build_object('source', 'rls-validation')
    );

    raise exception 'RLS validation failed: guard unexpectedly inserted cross-guard row';
  exception
    when insufficient_privilege then
      null;
  end;

  -- ------------------------------------------------------------
  -- CASE 3: guard cannot insert for unauthorized site
  -- ------------------------------------------------------------
  begin
    insert into public.guard_sync_operations (
      operation_id,
      operation_type,
      operation_status,
      client_id,
      site_id,
      guard_id,
      occurred_at,
      payload
    ) values (
      'RLS-TEST-OP-DENY-SITE-' || allowed_sequence::text,
      'statusUpdate',
      'queued',
      'CLIENT-001',
      'SITE-UNAUTHORIZED',
      'GUARD-001',
      timezone('utc', now()),
      json_build_object('source', 'rls-validation')
    );

    raise exception 'RLS validation failed: guard unexpectedly inserted cross-site row';
  exception
    when insufficient_privilege then
      null;
  end;

  -- ------------------------------------------------------------
  -- CASE 4: controller can insert site-scoped row for any guard
  -- ------------------------------------------------------------
  perform set_config(
    'request.jwt.claims',
    json_build_object(
      'role_type', 'controller',
      'client_id', 'CLIENT-001',
      'site_ids', json_build_array('SITE-SANDTON')
    )::text,
    true
  );

  insert into public.guard_sync_operations (
    operation_id,
    operation_type,
    operation_status,
    client_id,
    site_id,
    guard_id,
    occurred_at,
    payload
  ) values (
    'RLS-TEST-OP-CTRL-ALLOW-' || allowed_sequence::text,
    'statusUpdate',
    'queued',
    'CLIENT-001',
    'SITE-SANDTON',
    'GUARD-777',
    timezone('utc', now()),
    json_build_object('source', 'rls-validation')
  );

  -- ------------------------------------------------------------
  -- CASE 5: controller cannot insert outside allowed site
  -- ------------------------------------------------------------
  begin
    insert into public.guard_sync_operations (
      operation_id,
      operation_type,
      operation_status,
      client_id,
      site_id,
      guard_id,
      occurred_at,
      payload
    ) values (
      'RLS-TEST-OP-CTRL-DENY-SITE-' || allowed_sequence::text,
      'statusUpdate',
      'queued',
      'CLIENT-001',
      'SITE-OUT-OF-SCOPE',
      'GUARD-777',
      timezone('utc', now()),
      json_build_object('source', 'rls-validation')
    );

    raise exception 'RLS validation failed: controller unexpectedly inserted out-of-scope site row';
  exception
    when insufficient_privilege then
      null;
  end;
end $$;

-- Smoke read checks with valid claims
set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object(
    'role_type', 'guard',
    'client_id', 'CLIENT-001',
    'guard_id', 'GUARD-001',
    'site_ids', json_build_array('SITE-SANDTON')
  )::text,
  true
);

select
  count(*) as guard_visible_events
from public.guard_ops_events
where guard_id = 'GUARD-001'
  and site_id = 'SITE-SANDTON';

select
  count(*) as guard_visible_sync_ops
from public.guard_sync_operations
where guard_id = 'GUARD-001'
  and site_id = 'SITE-SANDTON';

-- If script reaches here without exception, policy checks passed.
-- Roll back inserted validation rows by design.
rollback;
