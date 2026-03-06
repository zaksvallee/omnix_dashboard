-- ONYX guard readiness smoke checks
-- Run in Supabase SQL editor (linked project).

select * from public.apply_guard_projection_retention(90, 30, 'pilot_readiness_dry_run');
select * from public.apply_guard_ops_retention_plan(90, 30, 365, 'pilot_readiness_dry_run');

select check_type, check_name, result
from public.guard_storage_readiness_checks
order by 1, 2;

select check_type, check_name, result
from public.guard_rls_readiness_checks
order by 1, 2;
