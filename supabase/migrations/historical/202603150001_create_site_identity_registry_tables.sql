create extension if not exists pgcrypto;

create table if not exists public.site_identity_profiles (
  id uuid primary key default gen_random_uuid(),
  client_id text not null
    references public.clients (client_id)
    on delete cascade,
  site_id text not null,
  identity_type text not null,
  category text not null default 'unknown',
  status text not null default 'pending',
  display_name text not null,
  face_match_id text,
  plate_number text,
  external_reference text,
  notes text,
  valid_from timestamptz,
  valid_until timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint site_identity_profiles_site_fk
    foreign key (client_id, site_id)
    references public.sites (client_id, site_id)
    on delete cascade,
  constraint site_identity_profiles_type_valid
    check (identity_type in ('person', 'vehicle')),
  constraint site_identity_profiles_category_valid
    check (
      category in (
        'employee',
        'family',
        'resident',
        'visitor',
        'contractor',
        'delivery',
        'unknown'
      )
    ),
  constraint site_identity_profiles_status_valid
    check (status in ('allowed', 'flagged', 'pending', 'expired')),
  constraint site_identity_profiles_display_name_not_blank
    check (length(btrim(display_name)) > 0),
  constraint site_identity_profiles_identity_required
    check (
      coalesce(length(btrim(face_match_id)), 0) > 0
      or coalesce(length(btrim(plate_number)), 0) > 0
      or coalesce(length(btrim(external_reference)), 0) > 0
    ),
  constraint site_identity_profiles_valid_window
    check (valid_until is null or valid_from is null or valid_until >= valid_from),
  constraint site_identity_profiles_metadata_is_object
    check (jsonb_typeof(metadata) = 'object')
);

create unique index if not exists site_identity_profiles_face_unique
  on public.site_identity_profiles (client_id, site_id, identity_type, face_match_id)
  where face_match_id is not null and length(btrim(face_match_id)) > 0;

create unique index if not exists site_identity_profiles_plate_unique
  on public.site_identity_profiles (client_id, site_id, identity_type, plate_number)
  where plate_number is not null and length(btrim(plate_number)) > 0;

create index if not exists site_identity_profiles_scope_status_idx
  on public.site_identity_profiles (client_id, site_id, status, category, updated_at desc);

create table if not exists public.site_identity_approval_decisions (
  id uuid primary key default gen_random_uuid(),
  client_id text not null
    references public.clients (client_id)
    on delete cascade,
  site_id text not null,
  profile_id uuid,
  intelligence_id text,
  decision text not null,
  source text not null default 'admin',
  decided_by text not null,
  decision_summary text,
  decided_at timestamptz not null default timezone('utc', now()),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  constraint site_identity_approval_decisions_site_fk
    foreign key (client_id, site_id)
    references public.sites (client_id, site_id)
    on delete cascade,
  constraint site_identity_approval_decisions_profile_fk
    foreign key (profile_id)
    references public.site_identity_profiles (id)
    on delete set null,
  constraint site_identity_approval_decisions_decision_valid
    check (decision in ('approve_once', 'approve_always', 'review', 'escalate', 'revoke')),
  constraint site_identity_approval_decisions_source_valid
    check (source in ('admin', 'telegram', 'ai_proposal', 'system')),
  constraint site_identity_approval_decisions_decided_by_not_blank
    check (length(btrim(decided_by)) > 0),
  constraint site_identity_approval_decisions_metadata_is_object
    check (jsonb_typeof(metadata) = 'object')
);

create index if not exists site_identity_approval_decisions_scope_idx
  on public.site_identity_approval_decisions (client_id, site_id, decided_at desc);

create index if not exists site_identity_approval_decisions_intel_idx
  on public.site_identity_approval_decisions (client_id, site_id, intelligence_id)
  where intelligence_id is not null and length(btrim(intelligence_id)) > 0;

create table if not exists public.telegram_identity_intake (
  id uuid primary key default gen_random_uuid(),
  client_id text not null
    references public.clients (client_id)
    on delete cascade,
  site_id text not null,
  endpoint_id uuid,
  raw_text text not null,
  parsed_display_name text,
  parsed_face_match_id text,
  parsed_plate_number text,
  parsed_category text not null default 'unknown',
  valid_from timestamptz,
  valid_until timestamptz,
  ai_confidence double precision not null default 0,
  approval_state text not null default 'pending',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint telegram_identity_intake_site_fk
    foreign key (client_id, site_id)
    references public.sites (client_id, site_id)
    on delete cascade,
  constraint telegram_identity_intake_endpoint_fk
    foreign key (endpoint_id)
    references public.client_messaging_endpoints (id)
    on delete set null,
  constraint telegram_identity_intake_raw_text_not_blank
    check (length(btrim(raw_text)) > 0),
  constraint telegram_identity_intake_category_valid
    check (
      parsed_category in (
        'employee',
        'family',
        'resident',
        'visitor',
        'contractor',
        'delivery',
        'unknown'
      )
    ),
  constraint telegram_identity_intake_confidence_range
    check (ai_confidence >= 0 and ai_confidence <= 1),
  constraint telegram_identity_intake_approval_state_valid
    check (approval_state in ('pending', 'proposed', 'approved', 'rejected', 'expired')),
  constraint telegram_identity_intake_valid_window
    check (valid_until is null or valid_from is null or valid_until >= valid_from),
  constraint telegram_identity_intake_metadata_is_object
    check (jsonb_typeof(metadata) = 'object')
);

create index if not exists telegram_identity_intake_scope_idx
  on public.telegram_identity_intake (client_id, site_id, created_at desc);

create index if not exists telegram_identity_intake_approval_state_idx
  on public.telegram_identity_intake (client_id, site_id, approval_state, created_at desc);

drop trigger if exists set_site_identity_profiles_updated_at
  on public.site_identity_profiles;
create trigger set_site_identity_profiles_updated_at
before update on public.site_identity_profiles
for each row
execute function public.set_guard_directory_updated_at();

drop trigger if exists set_telegram_identity_intake_updated_at
  on public.telegram_identity_intake;
create trigger set_telegram_identity_intake_updated_at
before update on public.telegram_identity_intake
for each row
execute function public.set_guard_directory_updated_at();

alter table public.site_identity_profiles enable row level security;
alter table public.site_identity_approval_decisions enable row level security;
alter table public.telegram_identity_intake enable row level security;

drop policy if exists site_identity_profiles_select_policy on public.site_identity_profiles;
create policy site_identity_profiles_select_policy
on public.site_identity_profiles
for select
to authenticated
using (
  client_id = public.onyx_client_id()
  and (
    public.onyx_is_control_role()
    or public.onyx_has_site(site_id)
  )
);

drop policy if exists site_identity_profiles_insert_policy on public.site_identity_profiles;
create policy site_identity_profiles_insert_policy
on public.site_identity_profiles
for insert
to authenticated
with check (
  client_id = public.onyx_client_id()
  and public.onyx_is_control_role()
);

drop policy if exists site_identity_profiles_update_policy on public.site_identity_profiles;
create policy site_identity_profiles_update_policy
on public.site_identity_profiles
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

drop policy if exists site_identity_profiles_delete_policy on public.site_identity_profiles;
create policy site_identity_profiles_delete_policy
on public.site_identity_profiles
for delete
to authenticated
using (
  client_id = public.onyx_client_id()
  and public.onyx_is_control_role()
);

drop policy if exists site_identity_approval_decisions_select_policy on public.site_identity_approval_decisions;
create policy site_identity_approval_decisions_select_policy
on public.site_identity_approval_decisions
for select
to authenticated
using (
  client_id = public.onyx_client_id()
  and (
    public.onyx_is_control_role()
    or public.onyx_has_site(site_id)
  )
);

drop policy if exists site_identity_approval_decisions_insert_policy on public.site_identity_approval_decisions;
create policy site_identity_approval_decisions_insert_policy
on public.site_identity_approval_decisions
for insert
to authenticated
with check (
  client_id = public.onyx_client_id()
  and public.onyx_is_control_role()
);

drop policy if exists telegram_identity_intake_select_policy on public.telegram_identity_intake;
create policy telegram_identity_intake_select_policy
on public.telegram_identity_intake
for select
to authenticated
using (
  client_id = public.onyx_client_id()
  and (
    public.onyx_is_control_role()
    or public.onyx_has_site(site_id)
  )
);

drop policy if exists telegram_identity_intake_insert_policy on public.telegram_identity_intake;
create policy telegram_identity_intake_insert_policy
on public.telegram_identity_intake
for insert
to authenticated
with check (
  client_id = public.onyx_client_id()
  and public.onyx_is_control_role()
);

drop policy if exists telegram_identity_intake_update_policy on public.telegram_identity_intake;
create policy telegram_identity_intake_update_policy
on public.telegram_identity_intake
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
