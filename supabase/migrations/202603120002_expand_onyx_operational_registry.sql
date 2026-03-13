do $$
begin
  create type public.employee_role as enum (
    'controller',
    'supervisor',
    'guard',
    'reaction_officer',
    'manager',
    'admin'
  );
exception
  when duplicate_object then null;
end;
$$;

do $$
begin
  create type public.employment_status as enum (
    'active',
    'suspended',
    'on_leave',
    'terminated'
  );
exception
  when duplicate_object then null;
end;
$$;

do $$
begin
  create type public.psira_grade as enum (
    'A',
    'B',
    'C',
    'D',
    'E'
  );
exception
  when duplicate_object then null;
end;
$$;

do $$
begin
  create type public.client_service_type as enum (
    'guarding',
    'armed_response',
    'remote_watch',
    'hybrid'
  );
exception
  when duplicate_object then null;
end;
$$;

do $$
begin
  create type public.site_risk_profile as enum (
    'residential',
    'industrial',
    'commercial',
    'mixed_use'
  );
exception
  when duplicate_object then null;
end;
$$;

do $$
begin
  create type public.incident_type as enum (
    'breach',
    'fire',
    'medical',
    'panic',
    'loitering',
    'technical_failure'
  );
exception
  when duplicate_object then null;
end;
$$;

do $$
begin
  create type public.incident_priority as enum (
    'p1',
    'p2',
    'p3',
    'p4'
  );
exception
  when duplicate_object then null;
end;
$$;

do $$
begin
  create type public.incident_status as enum (
    'detected',
    'verified',
    'dispatched',
    'on_site',
    'secured',
    'closed'
  );
exception
  when duplicate_object then null;
end;
$$;

do $$
begin
  create type public.vehicle_type as enum (
    'armed_response_vehicle',
    'supervisor_bakkie',
    'patrol_bike',
    'general_patrol_vehicle'
  );
exception
  when duplicate_object then null;
end;
$$;

do $$
begin
  create type public.vehicle_maintenance_status as enum (
    'service_due',
    'tires_check',
    'roadworthy_due',
    'ok'
  );
exception
  when duplicate_object then null;
end;
$$;

alter table public.clients
  add column if not exists client_type public.client_service_type,
  add column if not exists vat_number text,
  add column if not exists sovereign_contact text,
  add column if not exists contract_start date;

create unique index if not exists clients_vat_number_unique_idx
  on public.clients (vat_number)
  where vat_number is not null and length(btrim(vat_number)) > 0;

alter table public.sites
  add column if not exists physical_address text,
  add column if not exists site_layout_map_url text,
  add column if not exists entry_protocol text,
  add column if not exists hardware_ids jsonb not null default '[]'::jsonb,
  add column if not exists zone_labels jsonb not null default '{}'::jsonb,
  add column if not exists risk_rating integer not null default 3,
  add column if not exists risk_profile public.site_risk_profile,
  add column if not exists guard_nudge_frequency_minutes integer,
  add column if not exists escalation_trigger_minutes integer;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'sites_risk_rating_valid'
      and conrelid = 'public.sites'::regclass
  ) then
    alter table public.sites
      add constraint sites_risk_rating_valid
      check (risk_rating between 1 and 5);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'sites_hardware_ids_is_array'
      and conrelid = 'public.sites'::regclass
  ) then
    alter table public.sites
      add constraint sites_hardware_ids_is_array
      check (jsonb_typeof(hardware_ids) = 'array');
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'sites_zone_labels_is_object'
      and conrelid = 'public.sites'::regclass
  ) then
    alter table public.sites
      add constraint sites_zone_labels_is_object
      check (jsonb_typeof(zone_labels) = 'object');
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'sites_nudge_frequency_positive'
      and conrelid = 'public.sites'::regclass
  ) then
    alter table public.sites
      add constraint sites_nudge_frequency_positive
      check (
        guard_nudge_frequency_minutes is null
        or guard_nudge_frequency_minutes >= 1
      );
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'sites_escalation_trigger_positive'
      and conrelid = 'public.sites'::regclass
  ) then
    alter table public.sites
      add constraint sites_escalation_trigger_positive
      check (
        escalation_trigger_minutes is null
        or escalation_trigger_minutes >= 1
      );
  end if;
end;
$$;

create or replace function public.apply_site_risk_defaults()
returns trigger
language plpgsql
as $$
begin
  if new.risk_profile = 'industrial' and new.guard_nudge_frequency_minutes is null then
    new.guard_nudge_frequency_minutes = 10;
  elsif new.risk_profile = 'residential' and new.guard_nudge_frequency_minutes is null then
    new.guard_nudge_frequency_minutes = 15;
  elsif new.guard_nudge_frequency_minutes is null then
    new.guard_nudge_frequency_minutes = 12;
  end if;

  if new.risk_profile = 'industrial' and new.escalation_trigger_minutes is null then
    new.escalation_trigger_minutes = 1;
  elsif new.risk_profile = 'residential' and new.escalation_trigger_minutes is null then
    new.escalation_trigger_minutes = 2;
  elsif new.escalation_trigger_minutes is null then
    new.escalation_trigger_minutes = 2;
  end if;

  return new;
end;
$$;

drop trigger if exists apply_site_risk_defaults_before_write
  on public.sites;
create trigger apply_site_risk_defaults_before_write
before insert or update on public.sites
for each row
execute function public.apply_site_risk_defaults();

create table if not exists public.employees (
  id uuid primary key default gen_random_uuid(),
  client_id text not null
    references public.clients (client_id)
    on delete restrict,
  employee_code text not null,
  full_name text not null,
  surname text not null,
  id_number text not null,
  date_of_birth date,
  primary_role public.employee_role not null,
  reporting_to_employee_id uuid,
  psira_number text,
  psira_grade public.psira_grade,
  psira_expiry date,
  has_driver_license boolean not null default false,
  driver_license_code text,
  driver_license_expiry date,
  has_pdp boolean not null default false,
  pdp_expiry date,
  firearm_competency jsonb not null default '{}'::jsonb,
  issued_firearm_serials text[] not null default '{}'::text[],
  device_uid text,
  biometric_template_hash text,
  auth_user_id uuid,
  contact_phone text,
  contact_email text,
  employment_status public.employment_status not null default 'active',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint employees_client_id_id_unique
    unique (client_id, id),
  constraint employees_client_employee_code_unique
    unique (client_id, employee_code),
  constraint employees_client_id_number_unique
    unique (client_id, id_number),
  constraint employees_employee_code_not_blank
    check (length(btrim(employee_code)) > 0),
  constraint employees_full_name_not_blank
    check (length(btrim(full_name)) > 0),
  constraint employees_surname_not_blank
    check (length(btrim(surname)) > 0),
  constraint employees_id_number_not_blank
    check (length(btrim(id_number)) > 0),
  constraint employees_firearm_competency_is_object
    check (jsonb_typeof(firearm_competency) = 'object'),
  constraint employees_metadata_is_object
    check (jsonb_typeof(metadata) = 'object'),
  constraint employees_driver_license_consistency
    check (
      has_driver_license = true
      or (
        driver_license_code is null
        and driver_license_expiry is null
      )
    ),
  constraint employees_pdp_consistency
    check (
      has_pdp = false
      or (
        has_driver_license = true
        and pdp_expiry is not null
      )
    ),
  constraint employees_reporting_not_self
    check (reporting_to_employee_id is null or reporting_to_employee_id <> id)
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'employees_reporting_fk'
      and conrelid = 'public.employees'::regclass
  ) then
    alter table public.employees
      add constraint employees_reporting_fk
      foreign key (reporting_to_employee_id)
      references public.employees (id)
      on delete set null;
  end if;
end;
$$;

create unique index if not exists employees_client_auth_user_unique_idx
  on public.employees (client_id, auth_user_id)
  where auth_user_id is not null;

create unique index if not exists employees_client_psira_unique_idx
  on public.employees (client_id, psira_number)
  where psira_number is not null and length(btrim(psira_number)) > 0;

create unique index if not exists employees_client_device_uid_unique_idx
  on public.employees (client_id, device_uid)
  where device_uid is not null and length(btrim(device_uid)) > 0;

create index if not exists employees_client_role_status_idx
  on public.employees (client_id, primary_role, employment_status);

create index if not exists employees_client_psira_expiry_idx
  on public.employees (client_id, psira_expiry)
  where psira_expiry is not null;

create table if not exists public.employee_site_assignments (
  id uuid primary key default gen_random_uuid(),
  client_id text not null,
  employee_id uuid not null,
  site_id text not null,
  is_primary boolean not null default false,
  assignment_status text not null default 'active',
  starts_on date not null default current_date,
  ends_on date,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint employee_site_assignments_status_valid
    check (assignment_status in ('active', 'inactive')),
  constraint employee_site_assignments_dates_valid
    check (ends_on is null or ends_on >= starts_on),
  constraint employee_site_assignments_unique
    unique (employee_id, site_id),
  constraint employee_site_assignments_employee_fk
    foreign key (client_id, employee_id)
    references public.employees (client_id, id)
    on delete cascade,
  constraint employee_site_assignments_site_fk
    foreign key (client_id, site_id)
    references public.sites (client_id, site_id)
    on delete restrict
);

create unique index if not exists employee_site_assignments_primary_unique_idx
  on public.employee_site_assignments (employee_id)
  where is_primary = true and assignment_status = 'active';

create index if not exists employee_site_assignments_client_site_status_idx
  on public.employee_site_assignments (client_id, site_id, assignment_status);

create table if not exists public.vehicles (
  id uuid primary key default gen_random_uuid(),
  client_id text not null,
  site_id text,
  vehicle_callsign text not null,
  license_plate text not null,
  vehicle_type public.vehicle_type not null default 'general_patrol_vehicle',
  maintenance_status public.vehicle_maintenance_status not null default 'ok',
  service_due_date date,
  roadworthy_expiry date,
  odometer_km integer,
  fuel_percent numeric(5,2),
  assigned_employee_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint vehicles_callsign_not_blank
    check (length(btrim(vehicle_callsign)) > 0),
  constraint vehicles_license_plate_not_blank
    check (length(btrim(license_plate)) > 0),
  constraint vehicles_odometer_non_negative
    check (odometer_km is null or odometer_km >= 0),
  constraint vehicles_fuel_percent_valid
    check (fuel_percent is null or (fuel_percent >= 0 and fuel_percent <= 100)),
  constraint vehicles_metadata_is_object
    check (jsonb_typeof(metadata) = 'object'),
  constraint vehicles_client_callsign_unique
    unique (client_id, vehicle_callsign),
  constraint vehicles_client_license_unique
    unique (client_id, license_plate),
  constraint vehicles_site_fk
    foreign key (client_id, site_id)
    references public.sites (client_id, site_id)
    on delete restrict,
  constraint vehicles_assigned_employee_fk
    foreign key (client_id, assigned_employee_id)
    references public.employees (client_id, id)
    on delete set null
);

create index if not exists vehicles_client_status_idx
  on public.vehicles (client_id, is_active, maintenance_status);

create index if not exists vehicles_service_due_idx
  on public.vehicles (client_id, service_due_date)
  where service_due_date is not null;

create table if not exists public.incidents (
  id uuid primary key default gen_random_uuid(),
  event_uid text not null unique,
  client_id text not null,
  site_id text not null,
  incident_type public.incident_type not null,
  priority public.incident_priority not null,
  status public.incident_status not null default 'detected',
  signal_received_at timestamptz not null,
  triage_time timestamptz,
  dispatch_time timestamptz,
  arrival_time timestamptz,
  resolution_time timestamptz,
  controller_notes text,
  field_report text,
  media_attachments text[] not null default '{}'::text[],
  evidence_hash text,
  linked_employee_id uuid,
  linked_guard_ops_event_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint incidents_event_uid_not_blank
    check (length(btrim(event_uid)) > 0),
  constraint incidents_media_attachments_not_null
    check (media_attachments is not null),
  constraint incidents_metadata_is_object
    check (jsonb_typeof(metadata) = 'object'),
  constraint incidents_timeline_order
    check (
      (triage_time is null or triage_time >= signal_received_at)
      and (dispatch_time is null or (triage_time is null or dispatch_time >= triage_time))
      and (arrival_time is null or (dispatch_time is null or arrival_time >= dispatch_time))
      and (resolution_time is null or (arrival_time is null or resolution_time >= arrival_time))
    ),
  constraint incidents_site_fk
    foreign key (client_id, site_id)
    references public.sites (client_id, site_id)
    on delete restrict,
  constraint incidents_employee_fk
    foreign key (client_id, linked_employee_id)
    references public.employees (client_id, id)
    on delete set null
);

do $$
begin
  if to_regclass('public.sites') is not null then
    with duplicates as (
      select ctid, site_id, row_number() over (partition by site_id order by ctid) as rn
      from public.sites
      where site_id is not null and length(btrim(site_id)) > 0
    )
    update public.sites s
    set site_id = duplicates.site_id || '-' || duplicates.rn::text
    from duplicates
    where s.ctid = duplicates.ctid
      and duplicates.rn > 1;

    create unique index if not exists sites_site_id_global_unique_idx
      on public.sites (site_id);
  end if;

  if to_regclass('public.vehicles') is not null then
    alter table public.vehicles
      add column if not exists client_id text,
      add column if not exists site_id text,
      add column if not exists vehicle_callsign text,
      add column if not exists license_plate text,
      add column if not exists vehicle_type public.vehicle_type,
      add column if not exists maintenance_status public.vehicle_maintenance_status,
      add column if not exists service_due_date date,
      add column if not exists roadworthy_expiry date,
      add column if not exists odometer_km integer,
      add column if not exists fuel_percent numeric(5,2),
      add column if not exists assigned_employee_id uuid,
      add column if not exists metadata jsonb not null default '{}'::jsonb,
      add column if not exists is_active boolean not null default true,
      add column if not exists created_at timestamptz not null default timezone('utc', now()),
      add column if not exists updated_at timestamptz not null default timezone('utc', now());

    update public.vehicles
    set
      metadata = coalesce(metadata, '{}'::jsonb),
      is_active = coalesce(is_active, true),
      created_at = coalesce(created_at, timezone('utc', now())),
      updated_at = coalesce(updated_at, timezone('utc', now()));
  end if;

  if to_regclass('public.incidents') is not null then
    alter table public.incidents
      add column if not exists event_uid text,
      add column if not exists client_id text,
      add column if not exists site_id text,
      add column if not exists incident_type public.incident_type,
      add column if not exists priority public.incident_priority,
      add column if not exists status public.incident_status,
      add column if not exists signal_received_at timestamptz,
      add column if not exists triage_time timestamptz,
      add column if not exists dispatch_time timestamptz,
      add column if not exists arrival_time timestamptz,
      add column if not exists resolution_time timestamptz,
      add column if not exists controller_notes text,
      add column if not exists field_report text,
      add column if not exists media_attachments text[] default '{}'::text[],
      add column if not exists evidence_hash text,
      add column if not exists linked_employee_id uuid,
      add column if not exists linked_guard_ops_event_id text,
      add column if not exists metadata jsonb not null default '{}'::jsonb,
      add column if not exists created_at timestamptz not null default timezone('utc', now()),
      add column if not exists updated_at timestamptz not null default timezone('utc', now());

    if exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'incidents'
        and column_name = 'timestamp_ingest'
    ) then
      execute '
        update public.incidents
        set signal_received_at = coalesce(signal_received_at, timestamp_ingest)
      ';
    end if;

    if exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'incidents'
        and column_name = 'event_id'
    ) then
      execute '
        update public.incidents
        set event_uid = coalesce(nullif(btrim(event_uid), ''''), event_id::text)
      ';
    end if;

    update public.incidents
    set event_uid = coalesce(nullif(btrim(event_uid), ''), id::text)
    where event_uid is null or length(btrim(event_uid)) = 0;

    with duplicates as (
      select ctid, event_uid, row_number() over (partition by event_uid order by ctid) as rn
      from public.incidents
      where event_uid is not null and length(btrim(event_uid)) > 0
    )
    update public.incidents i
    set event_uid = duplicates.event_uid || '-' || duplicates.rn::text
    from duplicates
    where i.ctid = duplicates.ctid
      and duplicates.rn > 1;

    update public.incidents i
    set client_id = s.client_id
    from public.sites s
    where (i.client_id is null or length(btrim(i.client_id)) = 0)
      and i.site_id = s.site_id;

    update public.incidents i
    set client_id = fallback.client_id
    from (
      select client_id
      from public.clients
      where client_id is not null and length(btrim(client_id)) > 0
      order by client_id
      limit 1
    ) fallback
    where i.client_id is null or length(btrim(i.client_id)) = 0;

    if exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'incidents'
        and column_name = 'incident_type'
        and udt_schema = 'public'
        and udt_name = 'incident_type'
    ) then
      execute '
        update public.incidents
        set incident_type = coalesce(incident_type, ''technical_failure''::public.incident_type)
      ';
    else
      execute '
        update public.incidents
        set incident_type = coalesce(nullif(btrim(incident_type::text), ''''), ''technical_failure'')
      ';
    end if;

    if exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'incidents'
        and column_name = 'priority'
        and udt_schema = 'public'
        and udt_name = 'incident_priority'
    ) then
      execute '
        update public.incidents
        set priority = coalesce(priority, ''p3''::public.incident_priority)
      ';
    else
      execute '
        update public.incidents
        set priority = coalesce(nullif(btrim(priority::text), ''''), ''p3'')
      ';
    end if;

    if exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'incidents'
        and column_name = 'status'
        and udt_schema = 'public'
        and udt_name = 'incident_status'
    ) then
      execute '
        update public.incidents
        set status = coalesce(status, ''detected''::public.incident_status)
      ';
    else
      execute '
        update public.incidents
        set status = coalesce(nullif(btrim(status::text), ''''), ''detected'')
      ';
    end if;

    update public.incidents
    set
      signal_received_at = coalesce(signal_received_at, timezone('utc', now())),
      metadata = coalesce(metadata, '{}'::jsonb),
      created_at = coalesce(created_at, timezone('utc', now())),
      updated_at = coalesce(updated_at, timezone('utc', now()));

    create unique index if not exists incidents_event_uid_unique_idx
      on public.incidents (event_uid);
  end if;
end;
$$;

create index if not exists incidents_client_site_status_idx
  on public.incidents (client_id, site_id, status, signal_received_at desc);

create index if not exists incidents_priority_status_idx
  on public.incidents (priority, status, signal_received_at desc);

create index if not exists incidents_signal_received_idx
  on public.incidents (signal_received_at desc);

create or replace function public.incidents_lock_closed_rows()
returns trigger
language plpgsql
as $$
begin
  if old.status = 'closed' then
    raise exception 'incidents row is immutable after status=closed';
  end if;
  return new;
end;
$$;

drop trigger if exists incidents_lock_closed_rows_before_update
  on public.incidents;
create trigger incidents_lock_closed_rows_before_update
before update on public.incidents
for each row
execute function public.incidents_lock_closed_rows();

drop trigger if exists set_employees_updated_at
  on public.employees;
create trigger set_employees_updated_at
before update on public.employees
for each row
execute function public.set_guard_directory_updated_at();

drop trigger if exists set_employee_site_assignments_updated_at
  on public.employee_site_assignments;
create trigger set_employee_site_assignments_updated_at
before update on public.employee_site_assignments
for each row
execute function public.set_guard_directory_updated_at();

drop trigger if exists set_vehicles_updated_at
  on public.vehicles;
create trigger set_vehicles_updated_at
before update on public.vehicles
for each row
execute function public.set_guard_directory_updated_at();

drop trigger if exists set_incidents_updated_at
  on public.incidents;
create trigger set_incidents_updated_at
before update on public.incidents
for each row
execute function public.set_guard_directory_updated_at();

alter table public.employees enable row level security;
alter table public.employee_site_assignments enable row level security;
alter table public.vehicles enable row level security;
alter table public.incidents enable row level security;

drop policy if exists employees_select_policy on public.employees;
create policy employees_select_policy
on public.employees
for select
to authenticated
using (
  client_id = public.onyx_client_id()
  and (
    public.onyx_is_control_role()
    or (public.onyx_role_type() = 'guard' and employee_code = public.onyx_guard_id())
  )
);

drop policy if exists employees_insert_policy on public.employees;
create policy employees_insert_policy
on public.employees
for insert
to authenticated
with check (
  client_id = public.onyx_client_id()
  and public.onyx_is_control_role()
);

drop policy if exists employees_update_policy on public.employees;
create policy employees_update_policy
on public.employees
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

drop policy if exists employee_site_assignments_select_policy on public.employee_site_assignments;
create policy employee_site_assignments_select_policy
on public.employee_site_assignments
for select
to authenticated
using (
  client_id = public.onyx_client_id()
  and (
    public.onyx_is_control_role()
    or (
      public.onyx_role_type() = 'guard'
      and exists (
        select 1
        from public.employees e
        where e.id = employee_site_assignments.employee_id
          and e.client_id = employee_site_assignments.client_id
          and e.employee_code = public.onyx_guard_id()
      )
    )
  )
);

drop policy if exists employee_site_assignments_insert_policy on public.employee_site_assignments;
create policy employee_site_assignments_insert_policy
on public.employee_site_assignments
for insert
to authenticated
with check (
  client_id = public.onyx_client_id()
  and public.onyx_is_control_role()
);

drop policy if exists employee_site_assignments_update_policy on public.employee_site_assignments;
create policy employee_site_assignments_update_policy
on public.employee_site_assignments
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

drop policy if exists vehicles_select_policy on public.vehicles;
create policy vehicles_select_policy
on public.vehicles
for select
to authenticated
using (
  client_id = public.onyx_client_id()
  and (
    public.onyx_is_control_role()
    or (site_id is not null and public.onyx_has_site(site_id))
  )
);

drop policy if exists vehicles_insert_policy on public.vehicles;
create policy vehicles_insert_policy
on public.vehicles
for insert
to authenticated
with check (
  client_id = public.onyx_client_id()
  and public.onyx_is_control_role()
);

drop policy if exists vehicles_update_policy on public.vehicles;
create policy vehicles_update_policy
on public.vehicles
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

drop policy if exists incidents_select_policy on public.incidents;
create policy incidents_select_policy
on public.incidents
for select
to authenticated
using (
  client_id = public.onyx_client_id()
  and public.onyx_has_site(site_id)
);

drop policy if exists incidents_insert_policy on public.incidents;
create policy incidents_insert_policy
on public.incidents
for insert
to authenticated
with check (
  client_id = public.onyx_client_id()
  and public.onyx_has_site(site_id)
);

drop policy if exists incidents_update_policy on public.incidents;
create policy incidents_update_policy
on public.incidents
for update
to authenticated
using (
  client_id = public.onyx_client_id()
  and public.onyx_has_site(site_id)
  and public.onyx_is_control_role()
)
with check (
  client_id = public.onyx_client_id()
  and public.onyx_has_site(site_id)
  and public.onyx_is_control_role()
);

comment on table public.employees is
  'Unified ONYX employee registry with role discriminator and SA compliance fields (PSIRA, licensing, PDP).';

comment on table public.employee_site_assignments is
  'Employee-to-site assignment map for operational scope, dispatch, and access checks.';

comment on table public.vehicles is
  'Vehicle registry for reaction/supervisor fleets including maintenance and assignment data.';

comment on table public.incidents is
  'Immutable-closure incident chain table for operational timeline, evidence links, and legal reporting.';
