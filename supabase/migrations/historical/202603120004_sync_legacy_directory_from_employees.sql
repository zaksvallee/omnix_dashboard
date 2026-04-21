begin;

alter table if exists public.controllers
  add column if not exists source_employee_id uuid;
alter table if exists public.controllers
  add column if not exists first_name text;
alter table if exists public.controllers
  add column if not exists last_name text;

alter table if exists public.staff
  add column if not exists source_employee_id uuid;
alter table if exists public.staff
  add column if not exists first_name text;
alter table if exists public.staff
  add column if not exists last_name text;

alter table if exists public.guards
  add column if not exists source_employee_id uuid;
alter table if exists public.guards
  add column if not exists first_name text;
alter table if exists public.guards
  add column if not exists last_name text;

create unique index if not exists controllers_source_employee_unique_idx
  on public.controllers (source_employee_id);

create unique index if not exists staff_source_employee_unique_idx
  on public.staff (source_employee_id);

create unique index if not exists guards_source_employee_unique_idx
  on public.guards (source_employee_id);

create or replace function public.sync_legacy_directory_employee(target_employee_id uuid)
returns void
language plpgsql
as $$
declare
  employee_row public.employees%rowtype;
  primary_site text;
  legacy_full_name text;
  legacy_first_name text;
  legacy_last_name text;
  legacy_active boolean;
  legacy_metadata jsonb;
  controller_legacy_id text;
  guard_legacy_id text;
  staff_legacy_id text;
begin
  if target_employee_id is null then
    return;
  end if;

  select *
  into employee_row
  from public.employees e
  where e.id = target_employee_id;

  if not found then
    update public.controllers
    set
      is_active = false,
      source_employee_id = null,
      updated_at = timezone('utc', now())
    where source_employee_id = target_employee_id;

    update public.staff
    set
      is_active = false,
      source_employee_id = null,
      updated_at = timezone('utc', now())
    where source_employee_id = target_employee_id;

    update public.guards
    set
      is_active = false,
      source_employee_id = null,
      updated_at = timezone('utc', now())
    where source_employee_id = target_employee_id;

    return;
  end if;

  select esa.site_id
  into primary_site
  from public.employee_site_assignments esa
  where esa.client_id = employee_row.client_id
    and esa.employee_id = employee_row.id
    and esa.assignment_status = 'active'
  order by esa.is_primary desc, esa.starts_on asc nulls last, esa.created_at asc nulls last
  limit 1;

  legacy_full_name := btrim(
    concat_ws(' ', employee_row.full_name, employee_row.surname)
  );
  if legacy_full_name = '' then
    legacy_full_name := employee_row.employee_code;
  end if;
  legacy_first_name := nullif(btrim(employee_row.full_name), '');
  if legacy_first_name is null then
    legacy_first_name := legacy_full_name;
  end if;
  legacy_last_name := nullif(btrim(employee_row.surname), '');
  if legacy_last_name is null then
    legacy_last_name := legacy_first_name;
  end if;

  legacy_active := employee_row.employment_status in (
    'active'::public.employment_status,
    'on_leave'::public.employment_status
  );

  legacy_metadata := coalesce(employee_row.metadata, '{}'::jsonb)
    || jsonb_build_object(
      'source_table', 'employees',
      'source_employee_id', employee_row.id::text,
      'source_employee_code', employee_row.employee_code,
      'source_employee_role', employee_row.primary_role::text
    );

  controller_legacy_id := 'CTL-' || replace(employee_row.id::text, '-', '');
  guard_legacy_id := 'GRD-' || replace(employee_row.id::text, '-', '');
  staff_legacy_id := 'STF-' || replace(employee_row.id::text, '-', '');

  if employee_row.primary_role = 'controller'::public.employee_role then
    update public.staff
    set
      is_active = false,
      source_employee_id = null,
      updated_at = timezone('utc', now())
    where source_employee_id = employee_row.id;

    update public.guards
    set
      is_active = false,
      source_employee_id = null,
      updated_at = timezone('utc', now())
    where source_employee_id = employee_row.id;

    update public.controllers c
    set source_employee_id = employee_row.id
    where c.controller_id = controller_legacy_id
      and (
        c.source_employee_id is null
        or c.source_employee_id = employee_row.id
      );

    update public.controllers c
    set source_employee_id = employee_row.id
    where c.ctid in (
      select candidate.ctid
      from public.controllers candidate
      where candidate.source_employee_id is null
        and not exists (
          select 1
          from public.controllers existing
          where existing.source_employee_id = employee_row.id
        )
        and candidate.client_id = employee_row.client_id
        and (
          (
            nullif(btrim(candidate.employee_code), '') is not null
            and nullif(btrim(employee_row.employee_code), '') is not null
            and candidate.employee_code = employee_row.employee_code
          )
          or (
            nullif(btrim(candidate.contact_email), '') is not null
            and nullif(btrim(employee_row.contact_email), '') is not null
            and lower(candidate.contact_email) = lower(employee_row.contact_email)
          )
          or lower(btrim(candidate.full_name)) = lower(legacy_full_name)
        )
      order by
        case
          when candidate.employee_code = employee_row.employee_code then 0
          when lower(coalesce(candidate.contact_email, '')) =
               lower(coalesce(employee_row.contact_email, '')) then 1
          else 2
        end,
        candidate.updated_at desc nulls last,
        candidate.created_at desc nulls last,
        candidate.controller_id
      limit 1
    );

    update public.controllers
    set
      is_active = false,
      source_employee_id = null,
      updated_at = timezone('utc', now())
    where source_employee_id = employee_row.id
      and controller_id <> controller_legacy_id;

    insert into public.controllers (
      controller_id,
      client_id,
      home_site_id,
      first_name,
      last_name,
      full_name,
      role_label,
      employee_code,
      auth_user_id,
      contact_phone,
      contact_email,
      metadata,
      is_active,
      source_employee_id
    )
    select
      controller_legacy_id,
      employee_row.client_id,
      primary_site,
      legacy_first_name,
      legacy_last_name,
      legacy_full_name,
      employee_row.primary_role::text,
      employee_row.employee_code,
      employee_row.auth_user_id,
      employee_row.contact_phone,
      employee_row.contact_email,
      legacy_metadata,
      legacy_active,
      employee_row.id
    where not exists (
      select 1
      from public.controllers c
      where c.controller_id = controller_legacy_id
    );

    update public.controllers
    set
      client_id = employee_row.client_id,
      home_site_id = primary_site,
      first_name = legacy_first_name,
      last_name = legacy_last_name,
      full_name = legacy_full_name,
      role_label = employee_row.primary_role::text,
      employee_code = employee_row.employee_code,
      auth_user_id = employee_row.auth_user_id,
      contact_phone = employee_row.contact_phone,
      contact_email = employee_row.contact_email,
      metadata = legacy_metadata,
      is_active = legacy_active,
      source_employee_id = employee_row.id,
      updated_at = timezone('utc', now())
    where controller_id = controller_legacy_id;
  elsif employee_row.primary_role in (
    'guard'::public.employee_role,
    'reaction_officer'::public.employee_role
  ) then
    update public.controllers
    set
      is_active = false,
      source_employee_id = null,
      updated_at = timezone('utc', now())
    where source_employee_id = employee_row.id;

    update public.staff
    set
      is_active = false,
      source_employee_id = null,
      updated_at = timezone('utc', now())
    where source_employee_id = employee_row.id;

    update public.guards g
    set source_employee_id = employee_row.id
    where g.guard_id = guard_legacy_id
      and (
        g.source_employee_id is null
        or g.source_employee_id = employee_row.id
      );

    update public.guards g
    set source_employee_id = employee_row.id
    where g.ctid in (
      select candidate.ctid
      from public.guards candidate
      where candidate.source_employee_id is null
        and not exists (
          select 1
          from public.guards existing
          where existing.source_employee_id = employee_row.id
        )
        and candidate.client_id = employee_row.client_id
        and (
          (
            nullif(btrim(candidate.device_serial), '') is not null
            and nullif(btrim(employee_row.device_uid), '') is not null
            and candidate.device_serial = employee_row.device_uid
          )
          or (
            nullif(btrim(candidate.contact_email), '') is not null
            and nullif(btrim(employee_row.contact_email), '') is not null
            and lower(candidate.contact_email) = lower(employee_row.contact_email)
          )
          or lower(btrim(candidate.full_name)) = lower(legacy_full_name)
        )
      order by
        case
          when candidate.device_serial = employee_row.device_uid then 0
          when lower(coalesce(candidate.contact_email, '')) =
               lower(coalesce(employee_row.contact_email, '')) then 1
          else 2
        end,
        candidate.updated_at desc nulls last,
        candidate.created_at desc nulls last,
        candidate.guard_id
      limit 1
    );

    update public.guards
    set
      is_active = false,
      source_employee_id = null,
      updated_at = timezone('utc', now())
    where source_employee_id = employee_row.id
      and guard_id <> guard_legacy_id;

    insert into public.guards (
      guard_id,
      client_id,
      primary_site_id,
      first_name,
      last_name,
      full_name,
      badge_number,
      ptt_identity,
      device_serial,
      auth_user_id,
      contact_phone,
      contact_email,
      metadata,
      is_active,
      source_employee_id
    )
    select
      guard_legacy_id,
      employee_row.client_id,
      primary_site,
      legacy_first_name,
      legacy_last_name,
      legacy_full_name,
      nullif(btrim(coalesce(employee_row.metadata ->> 'badge_number', '')), ''),
      nullif(btrim(coalesce(employee_row.metadata ->> 'ptt_identity', '')), ''),
      employee_row.device_uid,
      employee_row.auth_user_id,
      employee_row.contact_phone,
      employee_row.contact_email,
      legacy_metadata,
      legacy_active,
      employee_row.id
    where not exists (
      select 1
      from public.guards g
      where g.guard_id = guard_legacy_id
    );

    update public.guards
    set
      client_id = employee_row.client_id,
      primary_site_id = primary_site,
      first_name = legacy_first_name,
      last_name = legacy_last_name,
      full_name = legacy_full_name,
      badge_number = nullif(
        btrim(coalesce(employee_row.metadata ->> 'badge_number', '')),
        ''
      ),
      ptt_identity = nullif(
        btrim(coalesce(employee_row.metadata ->> 'ptt_identity', '')),
        ''
      ),
      device_serial = employee_row.device_uid,
      auth_user_id = employee_row.auth_user_id,
      contact_phone = employee_row.contact_phone,
      contact_email = employee_row.contact_email,
      metadata = legacy_metadata,
      is_active = legacy_active,
      source_employee_id = employee_row.id,
      updated_at = timezone('utc', now())
    where guard_id = guard_legacy_id;
  else
    update public.controllers
    set
      is_active = false,
      source_employee_id = null,
      updated_at = timezone('utc', now())
    where source_employee_id = employee_row.id;

    update public.guards
    set
      is_active = false,
      source_employee_id = null,
      updated_at = timezone('utc', now())
    where source_employee_id = employee_row.id;

    update public.staff s
    set source_employee_id = employee_row.id
    where s.staff_id = staff_legacy_id
      and (
        s.source_employee_id is null
        or s.source_employee_id = employee_row.id
      );

    update public.staff s
    set source_employee_id = employee_row.id
    where s.ctid in (
      select candidate.ctid
      from public.staff candidate
      where candidate.source_employee_id is null
        and not exists (
          select 1
          from public.staff existing
          where existing.source_employee_id = employee_row.id
        )
        and candidate.client_id = employee_row.client_id
        and (
          (
            nullif(btrim(candidate.employee_code), '') is not null
            and nullif(btrim(employee_row.employee_code), '') is not null
            and candidate.employee_code = employee_row.employee_code
          )
          or (
            nullif(btrim(candidate.contact_email), '') is not null
            and nullif(btrim(employee_row.contact_email), '') is not null
            and lower(candidate.contact_email) = lower(employee_row.contact_email)
          )
          or lower(btrim(candidate.full_name)) = lower(legacy_full_name)
        )
      order by
        case
          when candidate.employee_code = employee_row.employee_code then 0
          when lower(coalesce(candidate.contact_email, '')) =
               lower(coalesce(employee_row.contact_email, '')) then 1
          else 2
        end,
        candidate.updated_at desc nulls last,
        candidate.created_at desc nulls last,
        candidate.staff_id
      limit 1
    );

    update public.staff
    set
      is_active = false,
      source_employee_id = null,
      updated_at = timezone('utc', now())
    where source_employee_id = employee_row.id
      and staff_id <> staff_legacy_id;

    insert into public.staff (
      staff_id,
      client_id,
      site_id,
      first_name,
      last_name,
      full_name,
      staff_role,
      employee_code,
      auth_user_id,
      contact_phone,
      contact_email,
      metadata,
      is_active,
      source_employee_id
    )
    select
      staff_legacy_id,
      employee_row.client_id,
      primary_site,
      legacy_first_name,
      legacy_last_name,
      legacy_full_name,
      employee_row.primary_role::text,
      employee_row.employee_code,
      employee_row.auth_user_id,
      employee_row.contact_phone,
      employee_row.contact_email,
      legacy_metadata,
      legacy_active,
      employee_row.id
    where not exists (
      select 1
      from public.staff s
      where s.staff_id = staff_legacy_id
    );

    update public.staff
    set
      client_id = employee_row.client_id,
      site_id = primary_site,
      first_name = legacy_first_name,
      last_name = legacy_last_name,
      full_name = legacy_full_name,
      staff_role = employee_row.primary_role::text,
      employee_code = employee_row.employee_code,
      auth_user_id = employee_row.auth_user_id,
      contact_phone = employee_row.contact_phone,
      contact_email = employee_row.contact_email,
      metadata = legacy_metadata,
      is_active = legacy_active,
      source_employee_id = employee_row.id,
      updated_at = timezone('utc', now())
    where staff_id = staff_legacy_id;
  end if;
end;
$$;

create or replace function public.sync_legacy_directory_employee_trigger()
returns trigger
language plpgsql
as $$
declare
  target_employee_id uuid;
begin
  if tg_op = 'DELETE' then
    target_employee_id := old.id;
  else
    target_employee_id := new.id;
  end if;
  if target_employee_id is not null then
    perform public.sync_legacy_directory_employee(target_employee_id);
  end if;
  return coalesce(new, old);
end;
$$;

create or replace function public.sync_legacy_directory_assignment_trigger()
returns trigger
language plpgsql
as $$
declare
  target_employee_id uuid;
begin
  if tg_op = 'DELETE' then
    target_employee_id := old.employee_id;
  else
    target_employee_id := new.employee_id;
  end if;
  if target_employee_id is not null then
    perform public.sync_legacy_directory_employee(target_employee_id);
  end if;
  if tg_op = 'UPDATE'
      and old.employee_id is not null
      and old.employee_id is distinct from new.employee_id then
    perform public.sync_legacy_directory_employee(old.employee_id);
  end if;
  return coalesce(new, old);
end;
$$;

drop trigger if exists sync_legacy_directory_employee_after_write
  on public.employees;
create trigger sync_legacy_directory_employee_after_write
after insert or update or delete on public.employees
for each row
execute function public.sync_legacy_directory_employee_trigger();

drop trigger if exists sync_legacy_directory_assignment_after_write
  on public.employee_site_assignments;
create trigger sync_legacy_directory_assignment_after_write
after insert or update or delete on public.employee_site_assignments
for each row
execute function public.sync_legacy_directory_assignment_trigger();

do $$
begin
  if to_regclass('public.employees') is null then
    return;
  end if;

  perform public.sync_legacy_directory_employee(e.id)
  from public.employees e;
end;
$$;

comment on function public.sync_legacy_directory_employee(uuid) is
  'Keeps legacy guards/controllers/staff tables synchronized from canonical employees + employee_site_assignments records.';

commit;
