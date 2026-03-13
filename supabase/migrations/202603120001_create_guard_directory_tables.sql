create extension if not exists pgcrypto;

create or replace function public.set_guard_directory_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

do $$
begin
  -- Compatibility bridge: some linked projects already had clients/sites tables
  -- without ONYX directory keys. Add and backfill canonical columns first.
  if to_regclass('public.clients') is not null then
    alter table public.clients
      add column if not exists client_id text,
      add column if not exists name text,
      add column if not exists display_name text,
      add column if not exists legal_name text,
      add column if not exists contact_name text,
      add column if not exists contact_email text,
      add column if not exists contact_phone text,
      add column if not exists billing_address text,
      add column if not exists metadata jsonb not null default '{}'::jsonb,
      add column if not exists is_active boolean not null default true,
      add column if not exists created_at timestamptz not null default timezone('utc', now()),
      add column if not exists updated_at timestamptz not null default timezone('utc', now());

    if exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'clients'
        and column_name = 'id'
    ) then
      execute 'update public.clients set client_id = coalesce(nullif(btrim(client_id), ''''), id::text)';
    end if;

    if exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'clients'
        and column_name = 'name'
    ) then
      execute 'update public.clients set display_name = coalesce(nullif(btrim(display_name), ''''), nullif(btrim(name::text), ''''))';
    end if;

    update public.clients
    set client_id = 'LEGACY-CLT-' || lpad(row_number::text, 4, '0')
    from (
      select ctid, row_number() over (order by ctid) as row_number
      from public.clients
      where client_id is null or length(btrim(client_id)) = 0
    ) numbered
    where public.clients.ctid = numbered.ctid;

    with duplicates as (
      select ctid, client_id, row_number() over (partition by client_id order by ctid) as rn
      from public.clients
      where client_id is not null and length(btrim(client_id)) > 0
    )
    update public.clients c
    set client_id = duplicates.client_id || '-' || duplicates.rn::text
    from duplicates
    where c.ctid = duplicates.ctid
      and duplicates.rn > 1;

    update public.clients
    set
      name = coalesce(nullif(btrim(name), ''), nullif(btrim(display_name), ''), nullif(btrim(legal_name), ''), client_id),
      display_name = coalesce(nullif(btrim(display_name), ''), nullif(btrim(legal_name), ''), client_id),
      metadata = coalesce(metadata, '{}'::jsonb),
      is_active = coalesce(is_active, true),
      created_at = coalesce(created_at, timezone('utc', now())),
      updated_at = coalesce(updated_at, timezone('utc', now()));

    alter table public.clients
      alter column client_id set not null,
      alter column display_name set not null;

    create unique index if not exists clients_client_id_compat_unique_idx
      on public.clients (client_id);
  end if;

  if to_regclass('public.sites') is not null then
    alter table public.sites
      add column if not exists site_id text,
      add column if not exists client_id text,
      add column if not exists site_name text,
      add column if not exists site_code text,
      add column if not exists name text,
      add column if not exists code text,
      add column if not exists timezone text not null default 'UTC',
      add column if not exists address_line_1 text,
      add column if not exists address_line_2 text,
      add column if not exists city text,
      add column if not exists region text,
      add column if not exists postal_code text,
      add column if not exists country_code text,
      add column if not exists latitude double precision,
      add column if not exists longitude double precision,
      add column if not exists geofence_radius_meters double precision,
      add column if not exists metadata jsonb not null default '{}'::jsonb,
      add column if not exists is_active boolean not null default true,
      add column if not exists created_at timestamptz not null default timezone('utc', now()),
      add column if not exists updated_at timestamptz not null default timezone('utc', now());

    if exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'sites'
        and column_name = 'id'
    ) then
      execute 'update public.sites set site_id = coalesce(nullif(btrim(site_id), ''''), id::text)';
    end if;

    if exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'sites'
        and column_name = 'name'
    ) then
      execute 'update public.sites set site_name = coalesce(nullif(btrim(site_name), ''''), nullif(btrim(name::text), ''''))';
    end if;

    if exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'sites'
        and column_name = 'client'
    ) then
      execute 'update public.sites set client_id = coalesce(nullif(btrim(client_id), ''''), nullif(btrim(client::text), ''''))';
    end if;

    if exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'sites'
        and column_name = 'client_uuid'
    ) then
      execute 'update public.sites set client_id = coalesce(nullif(btrim(client_id), ''''), nullif(btrim(client_uuid::text), ''''))';
    end if;

    update public.sites
    set site_id = 'LEGACY-SITE-' || lpad(row_number::text, 4, '0')
    from (
      select ctid, row_number() over (order by ctid) as row_number
      from public.sites
      where site_id is null or length(btrim(site_id)) = 0
    ) numbered
    where public.sites.ctid = numbered.ctid;

    update public.sites s
    set client_id = fallback.client_id
    from (
      select client_id
      from public.clients
      where client_id is not null and length(btrim(client_id)) > 0
      order by client_id
      limit 1
    ) fallback
    where s.client_id is null or length(btrim(s.client_id)) = 0;

    update public.sites s
    set client_id = fallback.client_id
    from (
      select client_id
      from public.clients
      where client_id is not null and length(btrim(client_id)) > 0
      order by client_id
      limit 1
    ) fallback
    where not exists (
      select 1
      from public.clients c
      where c.client_id = s.client_id
    );

    with duplicates as (
      select ctid, client_id, site_id, row_number() over (partition by client_id, site_id order by ctid) as rn
      from public.sites
      where client_id is not null
        and length(btrim(client_id)) > 0
        and site_id is not null
        and length(btrim(site_id)) > 0
    )
    update public.sites s
    set site_id = duplicates.site_id || '-' || duplicates.rn::text
    from duplicates
    where s.ctid = duplicates.ctid
      and duplicates.rn > 1;

    update public.sites
    set
      site_name = coalesce(nullif(btrim(site_name), ''), site_id),
      name = coalesce(nullif(btrim(name), ''), nullif(btrim(site_name), ''), site_id),
      code = coalesce(nullif(btrim(code), ''), nullif(btrim(site_code), ''), site_id),
      timezone = coalesce(nullif(btrim(timezone), ''), 'UTC'),
      metadata = coalesce(metadata, '{}'::jsonb),
      is_active = coalesce(is_active, true),
      created_at = coalesce(created_at, timezone('utc', now())),
      updated_at = coalesce(updated_at, timezone('utc', now()));

    alter table public.sites
      alter column site_id set not null,
      alter column client_id set not null,
      alter column site_name set not null;

    create unique index if not exists sites_client_site_compat_unique_idx
      on public.sites (client_id, site_id);
  end if;
end;
$$;

create table if not exists public.clients (
  client_id text primary key,
  name text,
  display_name text not null,
  legal_name text,
  contact_name text,
  contact_email text,
  contact_phone text,
  billing_address text,
  metadata jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint clients_client_id_not_blank
    check (length(btrim(client_id)) > 0),
  constraint clients_display_name_not_blank
    check (length(btrim(display_name)) > 0),
  constraint clients_metadata_is_object
    check (jsonb_typeof(metadata) = 'object')
);

create table if not exists public.sites (
  site_id text primary key,
  client_id text not null
    references public.clients (client_id)
    on delete restrict,
  site_name text not null,
  site_code text,
  name text,
  code text,
  timezone text not null default 'UTC',
  address_line_1 text,
  address_line_2 text,
  city text,
  region text,
  postal_code text,
  country_code text,
  latitude double precision,
  longitude double precision,
  geofence_radius_meters double precision,
  metadata jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint sites_site_id_not_blank
    check (length(btrim(site_id)) > 0),
  constraint sites_site_name_not_blank
    check (length(btrim(site_name)) > 0),
  constraint sites_timezone_not_blank
    check (length(btrim(timezone)) > 0),
  constraint sites_country_code_valid
    check (
      country_code is null
      or country_code = upper(country_code)
      and length(country_code) = 2
    ),
  constraint sites_geofence_radius_non_negative
    check (geofence_radius_meters is null or geofence_radius_meters >= 0),
  constraint sites_metadata_is_object
    check (jsonb_typeof(metadata) = 'object'),
  constraint sites_client_site_unique
    unique (client_id, site_id)
);

create table if not exists public.controllers (
  controller_id text primary key,
  client_id text not null
    references public.clients (client_id)
    on delete restrict,
  home_site_id text,
  full_name text not null,
  role_label text not null default 'controller',
  employee_code text,
  auth_user_id uuid,
  contact_phone text,
  contact_email text,
  metadata jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint controllers_controller_id_not_blank
    check (length(btrim(controller_id)) > 0),
  constraint controllers_full_name_not_blank
    check (length(btrim(full_name)) > 0),
  constraint controllers_role_label_not_blank
    check (length(btrim(role_label)) > 0),
  constraint controllers_metadata_is_object
    check (jsonb_typeof(metadata) = 'object'),
  constraint controllers_client_controller_unique
    unique (client_id, controller_id),
  constraint controllers_client_site_fk
    foreign key (client_id, home_site_id)
    references public.sites (client_id, site_id)
    on delete restrict
);

create table if not exists public.staff (
  staff_id text primary key,
  client_id text not null
    references public.clients (client_id)
    on delete restrict,
  site_id text,
  full_name text not null,
  staff_role text not null default 'staff',
  employee_code text,
  auth_user_id uuid,
  contact_phone text,
  contact_email text,
  metadata jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint staff_staff_id_not_blank
    check (length(btrim(staff_id)) > 0),
  constraint staff_full_name_not_blank
    check (length(btrim(full_name)) > 0),
  constraint staff_role_not_blank
    check (length(btrim(staff_role)) > 0),
  constraint staff_metadata_is_object
    check (jsonb_typeof(metadata) = 'object'),
  constraint staff_client_staff_unique
    unique (client_id, staff_id),
  constraint staff_client_site_fk
    foreign key (client_id, site_id)
    references public.sites (client_id, site_id)
    on delete restrict
);

create table if not exists public.guards (
  guard_id text primary key,
  client_id text not null
    references public.clients (client_id)
    on delete restrict,
  primary_site_id text,
  full_name text not null,
  badge_number text,
  ptt_identity text,
  device_serial text,
  auth_user_id uuid,
  contact_phone text,
  contact_email text,
  metadata jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint guards_guard_id_not_blank
    check (length(btrim(guard_id)) > 0),
  constraint guards_full_name_not_blank
    check (length(btrim(full_name)) > 0),
  constraint guards_metadata_is_object
    check (jsonb_typeof(metadata) = 'object'),
  constraint guards_client_guard_unique
    unique (client_id, guard_id),
  constraint guards_client_site_fk
    foreign key (client_id, primary_site_id)
    references public.sites (client_id, site_id)
    on delete restrict
);

do $$
begin
  if to_regclass('public.controllers') is not null then
    alter table public.controllers
      add column if not exists controller_id text,
      add column if not exists client_id text,
      add column if not exists home_site_id text,
      add column if not exists full_name text,
      add column if not exists role_label text not null default 'controller',
      add column if not exists employee_code text,
      add column if not exists auth_user_id uuid,
      add column if not exists contact_phone text,
      add column if not exists contact_email text,
      add column if not exists metadata jsonb not null default '{}'::jsonb,
      add column if not exists is_active boolean not null default true,
      add column if not exists created_at timestamptz not null default timezone('utc', now()),
      add column if not exists updated_at timestamptz not null default timezone('utc', now());

    if exists (
      select 1 from information_schema.columns
      where table_schema = 'public' and table_name = 'controllers' and column_name = 'id'
    ) then
      execute 'update public.controllers set controller_id = coalesce(nullif(btrim(controller_id), ''''), id::text)';
    end if;
    if exists (
      select 1 from information_schema.columns
      where table_schema = 'public' and table_name = 'controllers' and column_name = 'name'
    ) then
      execute 'update public.controllers set full_name = coalesce(nullif(btrim(full_name), ''''), nullif(btrim(name::text), ''''))';
    end if;
    update public.controllers
    set
      metadata = coalesce(metadata, '{}'::jsonb),
      is_active = coalesce(is_active, true),
      created_at = coalesce(created_at, timezone('utc', now())),
      updated_at = coalesce(updated_at, timezone('utc', now()));
  end if;

  if to_regclass('public.staff') is not null then
    alter table public.staff
      add column if not exists staff_id text,
      add column if not exists client_id text,
      add column if not exists site_id text,
      add column if not exists full_name text,
      add column if not exists staff_role text not null default 'staff',
      add column if not exists employee_code text,
      add column if not exists auth_user_id uuid,
      add column if not exists contact_phone text,
      add column if not exists contact_email text,
      add column if not exists metadata jsonb not null default '{}'::jsonb,
      add column if not exists is_active boolean not null default true,
      add column if not exists created_at timestamptz not null default timezone('utc', now()),
      add column if not exists updated_at timestamptz not null default timezone('utc', now());

    if exists (
      select 1 from information_schema.columns
      where table_schema = 'public' and table_name = 'staff' and column_name = 'id'
    ) then
      execute 'update public.staff set staff_id = coalesce(nullif(btrim(staff_id), ''''), id::text)';
    end if;
    if exists (
      select 1 from information_schema.columns
      where table_schema = 'public' and table_name = 'staff' and column_name = 'name'
    ) then
      execute 'update public.staff set full_name = coalesce(nullif(btrim(full_name), ''''), nullif(btrim(name::text), ''''))';
    end if;
    update public.staff
    set
      metadata = coalesce(metadata, '{}'::jsonb),
      is_active = coalesce(is_active, true),
      created_at = coalesce(created_at, timezone('utc', now())),
      updated_at = coalesce(updated_at, timezone('utc', now()));
  end if;

  if to_regclass('public.guards') is not null then
    alter table public.guards
      add column if not exists guard_id text,
      add column if not exists client_id text,
      add column if not exists primary_site_id text,
      add column if not exists full_name text,
      add column if not exists badge_number text,
      add column if not exists ptt_identity text,
      add column if not exists device_serial text,
      add column if not exists auth_user_id uuid,
      add column if not exists contact_phone text,
      add column if not exists contact_email text,
      add column if not exists metadata jsonb not null default '{}'::jsonb,
      add column if not exists is_active boolean not null default true,
      add column if not exists created_at timestamptz not null default timezone('utc', now()),
      add column if not exists updated_at timestamptz not null default timezone('utc', now());

    if exists (
      select 1 from information_schema.columns
      where table_schema = 'public' and table_name = 'guards' and column_name = 'id'
    ) then
      execute 'update public.guards set guard_id = coalesce(nullif(btrim(guard_id), ''''), id::text)';
    end if;
    if exists (
      select 1 from information_schema.columns
      where table_schema = 'public' and table_name = 'guards' and column_name = 'name'
    ) then
      execute 'update public.guards set full_name = coalesce(nullif(btrim(full_name), ''''), nullif(btrim(name::text), ''''))';
    end if;
    update public.guards
    set
      metadata = coalesce(metadata, '{}'::jsonb),
      is_active = coalesce(is_active, true),
      created_at = coalesce(created_at, timezone('utc', now())),
      updated_at = coalesce(updated_at, timezone('utc', now()));
  end if;
end;
$$;

create unique index if not exists sites_client_site_code_unique_idx
  on public.sites (client_id, site_code)
  where site_code is not null and length(btrim(site_code)) > 0;

create unique index if not exists controllers_client_employee_code_unique_idx
  on public.controllers (client_id, employee_code)
  where employee_code is not null and length(btrim(employee_code)) > 0;

create unique index if not exists controllers_client_auth_user_unique_idx
  on public.controllers (client_id, auth_user_id)
  where auth_user_id is not null;

create unique index if not exists staff_client_employee_code_unique_idx
  on public.staff (client_id, employee_code)
  where employee_code is not null and length(btrim(employee_code)) > 0;

create unique index if not exists staff_client_auth_user_unique_idx
  on public.staff (client_id, auth_user_id)
  where auth_user_id is not null;

create unique index if not exists guards_client_badge_number_unique_idx
  on public.guards (client_id, badge_number)
  where badge_number is not null and length(btrim(badge_number)) > 0;

create unique index if not exists guards_client_auth_user_unique_idx
  on public.guards (client_id, auth_user_id)
  where auth_user_id is not null;

create index if not exists sites_client_active_idx
  on public.sites (client_id, is_active, site_name);

create index if not exists controllers_client_active_idx
  on public.controllers (client_id, is_active, full_name);

create index if not exists staff_client_active_idx
  on public.staff (client_id, is_active, full_name);

create index if not exists guards_client_active_idx
  on public.guards (client_id, is_active, full_name);

create index if not exists guards_client_site_active_idx
  on public.guards (client_id, primary_site_id, is_active);

drop trigger if exists set_clients_updated_at
  on public.clients;
create trigger set_clients_updated_at
before update on public.clients
for each row
execute function public.set_guard_directory_updated_at();

drop trigger if exists set_sites_updated_at
  on public.sites;
create trigger set_sites_updated_at
before update on public.sites
for each row
execute function public.set_guard_directory_updated_at();

drop trigger if exists set_controllers_updated_at
  on public.controllers;
create trigger set_controllers_updated_at
before update on public.controllers
for each row
execute function public.set_guard_directory_updated_at();

drop trigger if exists set_staff_updated_at
  on public.staff;
create trigger set_staff_updated_at
before update on public.staff
for each row
execute function public.set_guard_directory_updated_at();

drop trigger if exists set_guards_updated_at
  on public.guards;
create trigger set_guards_updated_at
before update on public.guards
for each row
execute function public.set_guard_directory_updated_at();

alter table public.clients enable row level security;
alter table public.sites enable row level security;
alter table public.controllers enable row level security;
alter table public.staff enable row level security;
alter table public.guards enable row level security;

drop policy if exists clients_select_policy on public.clients;
create policy clients_select_policy
on public.clients
for select
to authenticated
using (client_id = public.onyx_client_id());

drop policy if exists clients_insert_policy on public.clients;
create policy clients_insert_policy
on public.clients
for insert
to authenticated
with check (
  client_id = public.onyx_client_id()
  and public.onyx_is_control_role()
);

drop policy if exists clients_update_policy on public.clients;
create policy clients_update_policy
on public.clients
for update
to authenticated
using (
  client_id = public.onyx_client_id()
  and public.onyx_is_control_role()
)
with check (
  client_id = public.onyx_client_id()
  and public.onyx_is_control_role()
);

drop policy if exists sites_select_policy on public.sites;
create policy sites_select_policy
on public.sites
for select
to authenticated
using (
  client_id = public.onyx_client_id()
  and (
    public.onyx_is_control_role()
    or public.onyx_has_site(site_id)
  )
);

drop policy if exists sites_insert_policy on public.sites;
create policy sites_insert_policy
on public.sites
for insert
to authenticated
with check (
  client_id = public.onyx_client_id()
  and public.onyx_is_control_role()
);

drop policy if exists sites_update_policy on public.sites;
create policy sites_update_policy
on public.sites
for update
to authenticated
using (
  client_id = public.onyx_client_id()
  and public.onyx_is_control_role()
)
with check (
  client_id = public.onyx_client_id()
  and public.onyx_is_control_role()
);

drop policy if exists controllers_select_policy on public.controllers;
create policy controllers_select_policy
on public.controllers
for select
to authenticated
using (
  client_id = public.onyx_client_id()
  and public.onyx_is_control_role()
);

drop policy if exists controllers_insert_policy on public.controllers;
create policy controllers_insert_policy
on public.controllers
for insert
to authenticated
with check (
  client_id = public.onyx_client_id()
  and public.onyx_is_control_role()
);

drop policy if exists controllers_update_policy on public.controllers;
create policy controllers_update_policy
on public.controllers
for update
to authenticated
using (
  client_id = public.onyx_client_id()
  and public.onyx_is_control_role()
)
with check (
  client_id = public.onyx_client_id()
  and public.onyx_is_control_role()
);

drop policy if exists staff_select_policy on public.staff;
create policy staff_select_policy
on public.staff
for select
to authenticated
using (
  client_id = public.onyx_client_id()
  and public.onyx_is_control_role()
);

drop policy if exists staff_insert_policy on public.staff;
create policy staff_insert_policy
on public.staff
for insert
to authenticated
with check (
  client_id = public.onyx_client_id()
  and public.onyx_is_control_role()
);

drop policy if exists staff_update_policy on public.staff;
create policy staff_update_policy
on public.staff
for update
to authenticated
using (
  client_id = public.onyx_client_id()
  and public.onyx_is_control_role()
)
with check (
  client_id = public.onyx_client_id()
  and public.onyx_is_control_role()
);

drop policy if exists guards_select_policy on public.guards;
create policy guards_select_policy
on public.guards
for select
to authenticated
using (
  client_id = public.onyx_client_id()
  and (
    public.onyx_is_control_role()
    or guard_id = public.onyx_guard_id()
  )
);

drop policy if exists guards_insert_policy on public.guards;
create policy guards_insert_policy
on public.guards
for insert
to authenticated
with check (
  client_id = public.onyx_client_id()
  and public.onyx_is_control_role()
);

drop policy if exists guards_update_policy on public.guards;
create policy guards_update_policy
on public.guards
for update
to authenticated
using (
  client_id = public.onyx_client_id()
  and public.onyx_is_control_role()
)
with check (
  client_id = public.onyx_client_id()
  and public.onyx_is_control_role()
);

comment on function public.set_guard_directory_updated_at() is
  'Shared updated_at trigger for ONYX guard directory tables.';

comment on table public.clients is
  'Tenant-level client directory records used for ONYX onboarding and scope metadata.';

comment on table public.sites is
  'Site directory records linked to clients; source of site metadata for guard and control flows.';

comment on table public.controllers is
  'Controller operator directory records for client/site operations.';

comment on table public.staff is
  'Staff directory records for non-controller site personnel.';

comment on table public.guards is
  'Guard directory records used to onboard and activate field devices per site.';
