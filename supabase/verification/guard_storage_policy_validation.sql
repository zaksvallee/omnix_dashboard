-- ONYX Guard Storage Policy Validation (Metadata Checks)
--
-- Run in Supabase SQL editor after applying:
-- supabase/manual/guard_storage_policies_owner.sql
--
-- This script validates:
-- 1) target buckets exist
-- 2) buckets are not public
-- 3) storage.objects has RLS enabled
-- 4) required policies exist on storage.objects

with required_buckets as (
  select unnest(array[
    'guard-shift-verification',
    'guard-patrol-images',
    'guard-incident-media'
  ]) as bucket_id
),
bucket_status as (
  select
    rb.bucket_id,
    b.id is not null as exists,
    coalesce(b.public, true) as is_public
  from required_buckets rb
  left join storage.buckets b on b.id = rb.bucket_id
),
policy_status as (
  select
    p.policyname,
    p.cmd
  from pg_policies p
  where p.schemaname = 'storage'
    and p.tablename = 'objects'
    and p.policyname in (
      'guard_media_select_policy',
      'guard_media_insert_policy',
      'guard_media_update_policy',
      'guard_media_delete_policy'
    )
)
select
  'bucket' as check_type,
  bucket_id as check_name,
  case
    when not exists then 'FAIL: missing'
    when is_public then 'FAIL: public=true'
    else 'PASS'
  end as result
from bucket_status
union all
select
  'storage_rls' as check_type,
  'storage.objects' as check_name,
  case
    when c.relrowsecurity then 'PASS'
    else 'FAIL: RLS disabled'
  end as result
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'storage' and c.relname = 'objects'
union all
select
  'policy' as check_type,
  required.policyname as check_name,
  case
    when ps.policyname is null then 'FAIL: missing'
    else 'PASS'
  end as result
from (
  select unnest(array[
    'guard_media_select_policy',
    'guard_media_insert_policy',
    'guard_media_update_policy',
    'guard_media_delete_policy'
  ]) as policyname
) required
left join policy_status ps on ps.policyname = required.policyname
order by check_type, check_name;
