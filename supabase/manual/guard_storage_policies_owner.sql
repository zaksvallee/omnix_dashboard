-- ONYX Guard Storage Policies (Owner-Level Apply Script)
--
-- Use this script in Supabase SQL editor with an owner-level role.
-- This is required because migration role may not own storage.objects.
--
-- Bucket/path model currently used by app:
-- guards/{guard_id}/...

alter table storage.objects enable row level security;

drop policy if exists guard_media_select_policy on storage.objects;
create policy guard_media_select_policy
on storage.objects
for select
to authenticated
using (
  bucket_id in (
    'guard-shift-verification',
    'guard-patrol-images',
    'guard-incident-media'
  )
  and (
    (
      public.onyx_role_type() = 'guard'
      and split_part(name, '/', 1) = 'guards'
      and split_part(name, '/', 2) = public.onyx_guard_id()
    )
    or public.onyx_is_control_role()
  )
);

drop policy if exists guard_media_insert_policy on storage.objects;
create policy guard_media_insert_policy
on storage.objects
for insert
to authenticated
with check (
  bucket_id in (
    'guard-shift-verification',
    'guard-patrol-images',
    'guard-incident-media'
  )
  and (
    (
      public.onyx_role_type() = 'guard'
      and split_part(name, '/', 1) = 'guards'
      and split_part(name, '/', 2) = public.onyx_guard_id()
    )
    or public.onyx_is_control_role()
  )
);

drop policy if exists guard_media_update_policy on storage.objects;
create policy guard_media_update_policy
on storage.objects
for update
to authenticated
using (
  bucket_id in (
    'guard-shift-verification',
    'guard-patrol-images',
    'guard-incident-media'
  )
  and (
    (
      public.onyx_role_type() = 'guard'
      and split_part(name, '/', 1) = 'guards'
      and split_part(name, '/', 2) = public.onyx_guard_id()
    )
    or public.onyx_is_control_role()
  )
)
with check (
  bucket_id in (
    'guard-shift-verification',
    'guard-patrol-images',
    'guard-incident-media'
  )
  and (
    (
      public.onyx_role_type() = 'guard'
      and split_part(name, '/', 1) = 'guards'
      and split_part(name, '/', 2) = public.onyx_guard_id()
    )
    or public.onyx_is_control_role()
  )
);

drop policy if exists guard_media_delete_policy on storage.objects;
create policy guard_media_delete_policy
on storage.objects
for delete
to authenticated
using (
  bucket_id in (
    'guard-shift-verification',
    'guard-patrol-images',
    'guard-incident-media'
  )
  and (
    (
      public.onyx_role_type() = 'guard'
      and split_part(name, '/', 1) = 'guards'
      and split_part(name, '/', 2) = public.onyx_guard_id()
    )
    or public.onyx_is_control_role()
  )
);
