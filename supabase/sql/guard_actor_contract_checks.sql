-- ONYX guard actor-contract compatibility checks
-- Run in Supabase SQL editor (linked project).
--
-- Purpose:
-- Validate that recent guard_ops_events rows include required actor-context
-- payload keys written by the mobile shell:
-- - actor_role
-- - actor_guard_id
-- - actor_client_id
-- - actor_site_id
-- - actor_shift_id

with recent_events as (
  select
    event_id,
    occurred_at,
    event_type,
    payload
  from public.guard_ops_events
  order by occurred_at desc
  limit 200
),
key_presence as (
  select
    event_id,
    occurred_at,
    event_type,
    (payload ? 'actor_role') as has_actor_role,
    (payload ? 'actor_guard_id') as has_actor_guard_id,
    (payload ? 'actor_client_id') as has_actor_client_id,
    (payload ? 'actor_site_id') as has_actor_site_id,
    (payload ? 'actor_shift_id') as has_actor_shift_id
  from recent_events
)
select
  'actor_contract' as check_type,
  'recent_rows' as check_name,
  count(*)::text as result
from recent_events
union all
select
  'actor_contract',
  'missing_actor_role',
  count(*)::text
from key_presence
where not has_actor_role
union all
select
  'actor_contract',
  'missing_actor_guard_id',
  count(*)::text
from key_presence
where not has_actor_guard_id
union all
select
  'actor_contract',
  'missing_actor_client_id',
  count(*)::text
from key_presence
where not has_actor_client_id
union all
select
  'actor_contract',
  'missing_actor_site_id',
  count(*)::text
from key_presence
where not has_actor_site_id
union all
select
  'actor_contract',
  'missing_actor_shift_id',
  count(*)::text
from key_presence
where not has_actor_shift_id
union all
select
  'actor_contract',
  'overall_status',
  case
    when exists (
      select 1
      from key_presence
      where not (
        has_actor_role
        and has_actor_guard_id
        and has_actor_client_id
        and has_actor_site_id
        and has_actor_shift_id
      )
    ) then 'FAIL'
    else 'PASS'
  end
order by check_name;

-- Optional drill-down:
-- select *
-- from (
--   select
--     event_id,
--     occurred_at,
--     event_type,
--     (payload ? 'actor_role') as has_actor_role,
--     (payload ? 'actor_guard_id') as has_actor_guard_id,
--     (payload ? 'actor_client_id') as has_actor_client_id,
--     (payload ? 'actor_site_id') as has_actor_site_id,
--     (payload ? 'actor_shift_id') as has_actor_shift_id
--   from public.guard_ops_events
--   order by occurred_at desc
--   limit 50
-- ) rows
-- where not (
--   has_actor_role
--   and has_actor_guard_id
--   and has_actor_client_id
--   and has_actor_site_id
--   and has_actor_shift_id
-- );
