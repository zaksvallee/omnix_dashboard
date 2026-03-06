-- ONYX guard data RLS and storage policies
-- Source: docs/supabase_rls_storage_policy_spec.md

create or replace function public.onyx_role_type()
returns text
language sql
stable
as $$
  select coalesce(auth.jwt() ->> 'role_type', '');
$$;

create or replace function public.onyx_guard_id()
returns text
language sql
stable
as $$
  select coalesce(auth.jwt() ->> 'guard_id', '');
$$;

create or replace function public.onyx_client_id()
returns text
language sql
stable
as $$
  select coalesce(auth.jwt() ->> 'client_id', '');
$$;

create or replace function public.onyx_has_site(target_site_id text)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from jsonb_array_elements_text(
      coalesce(auth.jwt() -> 'site_ids', '[]'::jsonb)
    ) as site(site_id)
    where site.site_id = target_site_id
  );
$$;

create or replace function public.onyx_is_control_role()
returns boolean
language sql
stable
as $$
  select public.onyx_role_type() in ('controller', 'supervisor', 'admin');
$$;

-- ============================================================
-- guard_ops_events (no client_id column; scoped by site + guard)
-- ============================================================

alter table public.guard_ops_events enable row level security;

drop policy if exists guard_ops_events_select_policy on public.guard_ops_events;
create policy guard_ops_events_select_policy
on public.guard_ops_events
for select
to authenticated
using (
  public.onyx_has_site(site_id)
  and (
    (public.onyx_role_type() = 'guard' and guard_id = public.onyx_guard_id())
    or public.onyx_is_control_role()
  )
);

drop policy if exists guard_ops_events_insert_policy on public.guard_ops_events;
create policy guard_ops_events_insert_policy
on public.guard_ops_events
for insert
to authenticated
with check (
  public.onyx_has_site(site_id)
  and (
    (public.onyx_role_type() = 'guard' and guard_id = public.onyx_guard_id())
    or public.onyx_is_control_role()
  )
);

-- UPDATE/DELETE blocked by append-only trigger in existing migration.

-- ============================================================
-- guard_ops_media (no client_id column; scoped by site + guard)
-- ============================================================

alter table public.guard_ops_media enable row level security;

drop policy if exists guard_ops_media_select_policy on public.guard_ops_media;
create policy guard_ops_media_select_policy
on public.guard_ops_media
for select
to authenticated
using (
  public.onyx_has_site(site_id)
  and (
    (public.onyx_role_type() = 'guard' and guard_id = public.onyx_guard_id())
    or public.onyx_is_control_role()
  )
);

drop policy if exists guard_ops_media_insert_policy on public.guard_ops_media;
create policy guard_ops_media_insert_policy
on public.guard_ops_media
for insert
to authenticated
with check (
  public.onyx_has_site(site_id)
  and (
    (public.onyx_role_type() = 'guard' and guard_id = public.onyx_guard_id())
    or public.onyx_is_control_role()
  )
);

drop policy if exists guard_ops_media_update_policy on public.guard_ops_media;
create policy guard_ops_media_update_policy
on public.guard_ops_media
for update
to authenticated
using (
  public.onyx_has_site(site_id)
  and (
    (public.onyx_role_type() = 'guard' and guard_id = public.onyx_guard_id())
    or public.onyx_is_control_role()
  )
)
with check (
  public.onyx_has_site(site_id)
  and (
    (public.onyx_role_type() = 'guard' and guard_id = public.onyx_guard_id())
    or public.onyx_is_control_role()
  )
);

-- ============================================================
-- Existing guard sync/projection tables (client + site + guard)
-- ============================================================

alter table public.guard_sync_operations enable row level security;
alter table public.guard_assignments enable row level security;
alter table public.guard_location_heartbeats enable row level security;
alter table public.guard_checkpoint_scans enable row level security;
alter table public.guard_incident_captures enable row level security;
alter table public.guard_panic_signals enable row level security;

drop policy if exists guard_sync_operations_select_policy on public.guard_sync_operations;
create policy guard_sync_operations_select_policy
on public.guard_sync_operations
for select
to authenticated
using (
  client_id = public.onyx_client_id()
  and public.onyx_has_site(site_id)
  and (
    (public.onyx_role_type() = 'guard' and guard_id = public.onyx_guard_id())
    or public.onyx_is_control_role()
  )
);

drop policy if exists guard_sync_operations_insert_policy on public.guard_sync_operations;
create policy guard_sync_operations_insert_policy
on public.guard_sync_operations
for insert
to authenticated
with check (
  client_id = public.onyx_client_id()
  and public.onyx_has_site(site_id)
  and (
    (public.onyx_role_type() = 'guard' and guard_id = public.onyx_guard_id())
    or public.onyx_is_control_role()
  )
);

drop policy if exists guard_sync_operations_update_policy on public.guard_sync_operations;
create policy guard_sync_operations_update_policy
on public.guard_sync_operations
for update
to authenticated
using (
  client_id = public.onyx_client_id()
  and public.onyx_has_site(site_id)
  and (
    (public.onyx_role_type() = 'guard' and guard_id = public.onyx_guard_id())
    or public.onyx_is_control_role()
  )
)
with check (
  client_id = public.onyx_client_id()
  and public.onyx_has_site(site_id)
  and (
    (public.onyx_role_type() = 'guard' and guard_id = public.onyx_guard_id())
    or public.onyx_is_control_role()
  )
);

drop policy if exists guard_assignments_select_policy on public.guard_assignments;
create policy guard_assignments_select_policy
on public.guard_assignments
for select
to authenticated
using (
  client_id = public.onyx_client_id()
  and public.onyx_has_site(site_id)
  and (
    (public.onyx_role_type() = 'guard' and guard_id = public.onyx_guard_id())
    or public.onyx_is_control_role()
  )
);

drop policy if exists guard_assignments_insert_policy on public.guard_assignments;
create policy guard_assignments_insert_policy
on public.guard_assignments
for insert
to authenticated
with check (
  client_id = public.onyx_client_id()
  and public.onyx_has_site(site_id)
  and (
    (public.onyx_role_type() = 'guard' and guard_id = public.onyx_guard_id())
    or public.onyx_is_control_role()
  )
);

drop policy if exists guard_assignments_update_policy on public.guard_assignments;
create policy guard_assignments_update_policy
on public.guard_assignments
for update
to authenticated
using (
  client_id = public.onyx_client_id()
  and public.onyx_has_site(site_id)
  and (
    (public.onyx_role_type() = 'guard' and guard_id = public.onyx_guard_id())
    or public.onyx_is_control_role()
  )
)
with check (
  client_id = public.onyx_client_id()
  and public.onyx_has_site(site_id)
  and (
    (public.onyx_role_type() = 'guard' and guard_id = public.onyx_guard_id())
    or public.onyx_is_control_role()
  )
);

drop policy if exists guard_location_heartbeats_select_policy on public.guard_location_heartbeats;
create policy guard_location_heartbeats_select_policy
on public.guard_location_heartbeats
for select
to authenticated
using (
  client_id = public.onyx_client_id()
  and public.onyx_has_site(site_id)
  and (
    (public.onyx_role_type() = 'guard' and guard_id = public.onyx_guard_id())
    or public.onyx_is_control_role()
  )
);

drop policy if exists guard_location_heartbeats_insert_policy on public.guard_location_heartbeats;
create policy guard_location_heartbeats_insert_policy
on public.guard_location_heartbeats
for insert
to authenticated
with check (
  client_id = public.onyx_client_id()
  and public.onyx_has_site(site_id)
  and (
    (public.onyx_role_type() = 'guard' and guard_id = public.onyx_guard_id())
    or public.onyx_is_control_role()
  )
);

drop policy if exists guard_checkpoint_scans_select_policy on public.guard_checkpoint_scans;
create policy guard_checkpoint_scans_select_policy
on public.guard_checkpoint_scans
for select
to authenticated
using (
  client_id = public.onyx_client_id()
  and public.onyx_has_site(site_id)
  and (
    (public.onyx_role_type() = 'guard' and guard_id = public.onyx_guard_id())
    or public.onyx_is_control_role()
  )
);

drop policy if exists guard_checkpoint_scans_insert_policy on public.guard_checkpoint_scans;
create policy guard_checkpoint_scans_insert_policy
on public.guard_checkpoint_scans
for insert
to authenticated
with check (
  client_id = public.onyx_client_id()
  and public.onyx_has_site(site_id)
  and (
    (public.onyx_role_type() = 'guard' and guard_id = public.onyx_guard_id())
    or public.onyx_is_control_role()
  )
);

drop policy if exists guard_incident_captures_select_policy on public.guard_incident_captures;
create policy guard_incident_captures_select_policy
on public.guard_incident_captures
for select
to authenticated
using (
  client_id = public.onyx_client_id()
  and public.onyx_has_site(site_id)
  and (
    (public.onyx_role_type() = 'guard' and guard_id = public.onyx_guard_id())
    or public.onyx_is_control_role()
  )
);

drop policy if exists guard_incident_captures_insert_policy on public.guard_incident_captures;
create policy guard_incident_captures_insert_policy
on public.guard_incident_captures
for insert
to authenticated
with check (
  client_id = public.onyx_client_id()
  and public.onyx_has_site(site_id)
  and (
    (public.onyx_role_type() = 'guard' and guard_id = public.onyx_guard_id())
    or public.onyx_is_control_role()
  )
);

drop policy if exists guard_panic_signals_select_policy on public.guard_panic_signals;
create policy guard_panic_signals_select_policy
on public.guard_panic_signals
for select
to authenticated
using (
  client_id = public.onyx_client_id()
  and public.onyx_has_site(site_id)
  and (
    (public.onyx_role_type() = 'guard' and guard_id = public.onyx_guard_id())
    or public.onyx_is_control_role()
  )
);

drop policy if exists guard_panic_signals_insert_policy on public.guard_panic_signals;
create policy guard_panic_signals_insert_policy
on public.guard_panic_signals
for insert
to authenticated
with check (
  client_id = public.onyx_client_id()
  and public.onyx_has_site(site_id)
  and (
    (public.onyx_role_type() = 'guard' and guard_id = public.onyx_guard_id())
    or public.onyx_is_control_role()
  )
);

-- ============================================================
-- Storage object policies for guard media buckets
-- Path currently expected: guards/{guard_id}/...
-- ============================================================
do $$
begin
  begin
    execute 'alter table storage.objects enable row level security';

    execute 'drop policy if exists guard_media_select_policy on storage.objects';
    execute $sql$
      create policy guard_media_select_policy
      on storage.objects
      for select
      to authenticated
      using (
        bucket_id in (
          ''guard-shift-verification'',
          ''guard-patrol-images'',
          ''guard-incident-media''
        )
        and (
          (
            public.onyx_role_type() = ''guard''
            and split_part(name, ''/'', 1) = ''guards''
            and split_part(name, ''/'', 2) = public.onyx_guard_id()
          )
          or public.onyx_is_control_role()
        )
      )
    $sql$;

    execute 'drop policy if exists guard_media_insert_policy on storage.objects';
    execute $sql$
      create policy guard_media_insert_policy
      on storage.objects
      for insert
      to authenticated
      with check (
        bucket_id in (
          ''guard-shift-verification'',
          ''guard-patrol-images'',
          ''guard-incident-media''
        )
        and (
          (
            public.onyx_role_type() = ''guard''
            and split_part(name, ''/'', 1) = ''guards''
            and split_part(name, ''/'', 2) = public.onyx_guard_id()
          )
          or public.onyx_is_control_role()
        )
      )
    $sql$;

    execute 'drop policy if exists guard_media_update_policy on storage.objects';
    execute $sql$
      create policy guard_media_update_policy
      on storage.objects
      for update
      to authenticated
      using (
        bucket_id in (
          ''guard-shift-verification'',
          ''guard-patrol-images'',
          ''guard-incident-media''
        )
        and (
          (
            public.onyx_role_type() = ''guard''
            and split_part(name, ''/'', 1) = ''guards''
            and split_part(name, ''/'', 2) = public.onyx_guard_id()
          )
          or public.onyx_is_control_role()
        )
      )
      with check (
        bucket_id in (
          ''guard-shift-verification'',
          ''guard-patrol-images'',
          ''guard-incident-media''
        )
        and (
          (
            public.onyx_role_type() = ''guard''
            and split_part(name, ''/'', 1) = ''guards''
            and split_part(name, ''/'', 2) = public.onyx_guard_id()
          )
          or public.onyx_is_control_role()
        )
      )
    $sql$;

    execute 'drop policy if exists guard_media_delete_policy on storage.objects';
    execute $sql$
      create policy guard_media_delete_policy
      on storage.objects
      for delete
      to authenticated
      using (
        bucket_id in (
          ''guard-shift-verification'',
          ''guard-patrol-images'',
          ''guard-incident-media''
        )
        and (
          (
            public.onyx_role_type() = ''guard''
            and split_part(name, ''/'', 1) = ''guards''
            and split_part(name, ''/'', 2) = public.onyx_guard_id()
          )
          or public.onyx_is_control_role()
        )
      )
    $sql$;
  exception
    when insufficient_privilege then
      raise notice 'Skipping storage.objects policies: insufficient privilege for migration role.';
  end;
end $$;

comment on function public.onyx_role_type() is
  'Returns role_type from auth.jwt claims for ONYX RLS policies.';
comment on function public.onyx_guard_id() is
  'Returns guard_id from auth.jwt claims for ONYX RLS policies.';
comment on function public.onyx_client_id() is
  'Returns client_id from auth.jwt claims for ONYX RLS policies.';
comment on function public.onyx_has_site(text) is
  'Returns true if target site_id exists in auth.jwt site_ids claim.';
comment on function public.onyx_is_control_role() is
  'True when role_type is controller, supervisor, or admin.';
