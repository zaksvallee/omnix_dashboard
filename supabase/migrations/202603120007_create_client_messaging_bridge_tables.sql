create extension if not exists pgcrypto;

create table if not exists public.client_contacts (
  id uuid primary key default gen_random_uuid(),
  client_id text not null
    references public.clients (client_id)
    on delete cascade,
  site_id text,
  full_name text not null,
  role text not null default 'client_contact',
  phone text,
  email text,
  telegram_user_id text,
  is_primary boolean not null default false,
  consent_at timestamptz,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint client_contacts_full_name_not_blank
    check (length(btrim(full_name)) > 0),
  constraint client_contacts_role_not_blank
    check (length(btrim(role)) > 0),
  constraint client_contacts_metadata_is_object
    check (jsonb_typeof(metadata) = 'object'),
  constraint client_contacts_client_site_fk
    foreign key (client_id, site_id)
    references public.sites (client_id, site_id)
    on delete cascade,
  constraint client_contacts_client_id_id_unique
    unique (client_id, id)
);

create table if not exists public.client_messaging_endpoints (
  id uuid primary key default gen_random_uuid(),
  client_id text not null
    references public.clients (client_id)
    on delete cascade,
  site_id text,
  provider text not null,
  telegram_chat_id text,
  telegram_thread_id text,
  display_label text not null,
  verified_at timestamptz,
  is_active boolean not null default true,
  last_delivery_status text,
  last_error text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint client_messaging_endpoints_provider_valid
    check (provider in ('telegram', 'in_app')),
  constraint client_messaging_endpoints_display_label_not_blank
    check (length(btrim(display_label)) > 0),
  constraint client_messaging_endpoints_telegram_chat_required
    check (
      provider <> 'telegram'
      or (telegram_chat_id is not null and length(btrim(telegram_chat_id)) > 0)
    ),
  constraint client_messaging_endpoints_metadata_is_object
    check (jsonb_typeof(metadata) = 'object'),
  constraint client_messaging_endpoints_client_site_fk
    foreign key (client_id, site_id)
    references public.sites (client_id, site_id)
    on delete cascade,
  constraint client_messaging_endpoints_client_id_id_unique
    unique (client_id, id)
);

create table if not exists public.client_contact_endpoint_subscriptions (
  id uuid primary key default gen_random_uuid(),
  client_id text not null
    references public.clients (client_id)
    on delete cascade,
  site_id text,
  contact_id uuid not null,
  endpoint_id uuid not null,
  incident_priorities jsonb not null default '["p1","p2","p3","p4"]'::jsonb,
  incident_types jsonb not null default '[]'::jsonb,
  quiet_hours jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint client_contact_endpoint_subscriptions_unique
    unique (contact_id, endpoint_id),
  constraint client_contact_endpoint_subscriptions_priorities_is_array
    check (jsonb_typeof(incident_priorities) = 'array'),
  constraint client_contact_endpoint_subscriptions_types_is_array
    check (jsonb_typeof(incident_types) = 'array'),
  constraint client_contact_endpoint_subscriptions_quiet_hours_is_object
    check (jsonb_typeof(quiet_hours) = 'object'),
  constraint client_contact_endpoint_subscriptions_client_contact_fk
    foreign key (client_id, contact_id)
    references public.client_contacts (client_id, id)
    on delete cascade,
  constraint client_contact_endpoint_subscriptions_client_endpoint_fk
    foreign key (client_id, endpoint_id)
    references public.client_messaging_endpoints (client_id, id)
    on delete cascade,
  constraint client_contact_endpoint_subscriptions_client_site_fk
    foreign key (client_id, site_id)
    references public.sites (client_id, site_id)
    on delete cascade
);

create index if not exists client_contacts_client_scope_idx
  on public.client_contacts (client_id, site_id, is_active);

create index if not exists client_messaging_endpoints_scope_idx
  on public.client_messaging_endpoints (client_id, site_id, provider, is_active);

create index if not exists client_messaging_endpoints_telegram_chat_idx
  on public.client_messaging_endpoints (client_id, telegram_chat_id)
  where provider = 'telegram';

create index if not exists client_contact_endpoint_subscriptions_scope_idx
  on public.client_contact_endpoint_subscriptions (client_id, site_id, is_active);

create index if not exists client_contact_endpoint_subscriptions_contact_idx
  on public.client_contact_endpoint_subscriptions (contact_id, is_active);

create index if not exists client_contact_endpoint_subscriptions_endpoint_idx
  on public.client_contact_endpoint_subscriptions (endpoint_id, is_active);

drop trigger if exists set_client_contacts_updated_at
  on public.client_contacts;
create trigger set_client_contacts_updated_at
before update on public.client_contacts
for each row
execute function public.set_guard_directory_updated_at();

drop trigger if exists set_client_messaging_endpoints_updated_at
  on public.client_messaging_endpoints;
create trigger set_client_messaging_endpoints_updated_at
before update on public.client_messaging_endpoints
for each row
execute function public.set_guard_directory_updated_at();

drop trigger if exists set_client_contact_endpoint_subscriptions_updated_at
  on public.client_contact_endpoint_subscriptions;
create trigger set_client_contact_endpoint_subscriptions_updated_at
before update on public.client_contact_endpoint_subscriptions
for each row
execute function public.set_guard_directory_updated_at();

alter table public.client_contacts enable row level security;
alter table public.client_messaging_endpoints enable row level security;
alter table public.client_contact_endpoint_subscriptions enable row level security;

drop policy if exists client_contacts_select_policy on public.client_contacts;
create policy client_contacts_select_policy
on public.client_contacts
for select
to authenticated
using (
  client_id = public.onyx_client_id()
  and (
    public.onyx_is_control_role()
    or (site_id is not null and public.onyx_has_site(site_id))
  )
);

drop policy if exists client_contacts_insert_policy on public.client_contacts;
create policy client_contacts_insert_policy
on public.client_contacts
for insert
to authenticated
with check (
  client_id = public.onyx_client_id()
  and public.onyx_is_control_role()
);

drop policy if exists client_contacts_update_policy on public.client_contacts;
create policy client_contacts_update_policy
on public.client_contacts
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

drop policy if exists client_contacts_delete_policy on public.client_contacts;
create policy client_contacts_delete_policy
on public.client_contacts
for delete
to authenticated
using (
  client_id = public.onyx_client_id()
  and public.onyx_is_control_role()
);

drop policy if exists client_messaging_endpoints_select_policy on public.client_messaging_endpoints;
create policy client_messaging_endpoints_select_policy
on public.client_messaging_endpoints
for select
to authenticated
using (
  client_id = public.onyx_client_id()
  and (
    public.onyx_is_control_role()
    or (site_id is not null and public.onyx_has_site(site_id))
  )
);

drop policy if exists client_messaging_endpoints_insert_policy on public.client_messaging_endpoints;
create policy client_messaging_endpoints_insert_policy
on public.client_messaging_endpoints
for insert
to authenticated
with check (
  client_id = public.onyx_client_id()
  and public.onyx_is_control_role()
);

drop policy if exists client_messaging_endpoints_update_policy on public.client_messaging_endpoints;
create policy client_messaging_endpoints_update_policy
on public.client_messaging_endpoints
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

drop policy if exists client_messaging_endpoints_delete_policy on public.client_messaging_endpoints;
create policy client_messaging_endpoints_delete_policy
on public.client_messaging_endpoints
for delete
to authenticated
using (
  client_id = public.onyx_client_id()
  and public.onyx_is_control_role()
);

drop policy if exists client_contact_endpoint_subscriptions_select_policy on public.client_contact_endpoint_subscriptions;
create policy client_contact_endpoint_subscriptions_select_policy
on public.client_contact_endpoint_subscriptions
for select
to authenticated
using (
  client_id = public.onyx_client_id()
  and (
    public.onyx_is_control_role()
    or (site_id is not null and public.onyx_has_site(site_id))
  )
);

drop policy if exists client_contact_endpoint_subscriptions_insert_policy on public.client_contact_endpoint_subscriptions;
create policy client_contact_endpoint_subscriptions_insert_policy
on public.client_contact_endpoint_subscriptions
for insert
to authenticated
with check (
  client_id = public.onyx_client_id()
  and public.onyx_is_control_role()
);

drop policy if exists client_contact_endpoint_subscriptions_update_policy on public.client_contact_endpoint_subscriptions;
create policy client_contact_endpoint_subscriptions_update_policy
on public.client_contact_endpoint_subscriptions
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

drop policy if exists client_contact_endpoint_subscriptions_delete_policy on public.client_contact_endpoint_subscriptions;
create policy client_contact_endpoint_subscriptions_delete_policy
on public.client_contact_endpoint_subscriptions
for delete
to authenticated
using (
  client_id = public.onyx_client_id()
  and public.onyx_is_control_role()
);

comment on table public.client_contacts is
  'Client and site communication contacts used for operational messaging lanes.';

comment on table public.client_messaging_endpoints is
  'Delivery endpoints (Telegram / in-app) for client communications.';

comment on table public.client_contact_endpoint_subscriptions is
  'Routing rules mapping contacts to messaging endpoints and incident scopes.';
