-- ONYX Guard Directory Registry Validation
--
-- Run after applying migrations:
-- - 202603120001_create_guard_directory_tables.sql
-- - 202603120002_expand_onyx_operational_registry.sql
-- - 202603120004_sync_legacy_directory_from_employees.sql
-- - 202603120005_add_directory_delete_policies.sql
--
-- Behavior:
-- - metadata-only checks (no persistent writes)
-- - raises exceptions for missing schema/policy/trigger requirements

begin;

do $$
declare
  missing_tables text[];
  missing_columns text[];
  missing_policies text[];
  missing_triggers text[];
  missing_trigger_events text[];
  duplicate_source_count integer;
begin
  select coalesce(array_agg(required.table_name order by required.table_name), '{}'::text[])
  into missing_tables
  from (
    values
      ('clients'),
      ('sites'),
      ('employees'),
      ('employee_site_assignments'),
      ('vehicles'),
      ('incidents'),
      ('controllers'),
      ('staff'),
      ('guards')
  ) as required(table_name)
  where to_regclass(format('public.%s', required.table_name)) is null;

  if cardinality(missing_tables) > 0 then
    raise exception
      'Guard directory validation failed: missing tables: %',
      array_to_string(missing_tables, ', ');
  end if;

  select coalesce(
    array_agg(format('%s.%s', required.table_name, required.column_name) order by 1),
    '{}'::text[]
  )
  into missing_columns
  from (
    values
      ('controllers', 'source_employee_id'),
      ('staff', 'source_employee_id'),
      ('guards', 'source_employee_id')
  ) as required(table_name, column_name)
  where not exists (
    select 1
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = required.table_name
      and c.column_name = required.column_name
  );

  if cardinality(missing_columns) > 0 then
    raise exception
      'Guard directory validation failed: missing columns: %',
      array_to_string(missing_columns, ', ');
  end if;

  if to_regprocedure('public.sync_legacy_directory_employee(uuid)') is null then
    raise exception
      'Guard directory validation failed: function public.sync_legacy_directory_employee(uuid) is missing.';
  end if;

  select coalesce(
    array_agg(format('%s@%s', required.trigger_name, required.table_name) order by 1),
    '{}'::text[]
  )
  into missing_triggers
  from (
    values
      ('sync_legacy_directory_employee_after_write', 'employees'),
      ('sync_legacy_directory_assignment_after_write', 'employee_site_assignments')
  ) as required(trigger_name, table_name)
  where not exists (
    select 1
    from pg_trigger t
    join pg_class rel on rel.oid = t.tgrelid
    join pg_namespace ns on ns.oid = rel.relnamespace
    where ns.nspname = 'public'
      and rel.relname = required.table_name
      and t.tgname = required.trigger_name
      and not t.tgisinternal
  );

  if cardinality(missing_triggers) > 0 then
    raise exception
      'Guard directory validation failed: missing triggers: %',
      array_to_string(missing_triggers, ', ');
  end if;

  select coalesce(
    array_agg(required.trigger_name order by required.trigger_name),
    '{}'::text[]
  )
  into missing_trigger_events
  from (
    values
      ('sync_legacy_directory_employee_after_write', 'employees'),
      ('sync_legacy_directory_assignment_after_write', 'employee_site_assignments')
  ) as required(trigger_name, table_name)
  where not exists (
    select 1
    from pg_trigger t
    join pg_class rel on rel.oid = t.tgrelid
    join pg_namespace ns on ns.oid = rel.relnamespace
    where ns.nspname = 'public'
      and rel.relname = required.table_name
      and t.tgname = required.trigger_name
      and not t.tgisinternal
      and (t.tgtype::int & 4) <> 0   -- INSERT
      and (t.tgtype::int & 8) <> 0   -- DELETE
      and (t.tgtype::int & 16) <> 0  -- UPDATE
  );

  if cardinality(missing_trigger_events) > 0 then
    raise exception
      'Guard directory validation failed: triggers missing INSERT/UPDATE/DELETE coverage: %',
      array_to_string(missing_trigger_events, ', ');
  end if;

  select coalesce(array_agg(required.policy_name order by required.policy_name), '{}'::text[])
  into missing_policies
  from (
    values
      ('clients_delete_policy'),
      ('sites_delete_policy'),
      ('employees_delete_policy'),
      ('employee_site_assignments_delete_policy'),
      ('vehicles_delete_policy'),
      ('incidents_delete_policy'),
      ('controllers_delete_policy'),
      ('staff_delete_policy'),
      ('guards_delete_policy')
  ) as required(policy_name)
  where not exists (
    select 1
    from pg_policies p
    where p.schemaname = 'public'
      and p.policyname = required.policy_name
  );

  if cardinality(missing_policies) > 0 then
    raise exception
      'Guard directory validation failed: missing delete policies: %',
      array_to_string(missing_policies, ', ');
  end if;

  select count(*)
  into duplicate_source_count
  from (
    select source_employee_id
    from (
      select source_employee_id from public.controllers where source_employee_id is not null
      union all
      select source_employee_id from public.staff where source_employee_id is not null
      union all
      select source_employee_id from public.guards where source_employee_id is not null
    ) source_map
    group by source_employee_id
    having count(*) > 1
  ) duplicates;

  if duplicate_source_count > 0 then
    raise exception
      'Guard directory validation failed: % employee source mappings are duplicated across legacy tables.',
      duplicate_source_count;
  end if;
end;
$$;

select
  (select count(*) from public.clients) as clients_total,
  (select count(*) from public.sites) as sites_total,
  (select count(*) from public.employees) as employees_total,
  (select count(*) from public.controllers where source_employee_id is not null) as controllers_linked,
  (select count(*) from public.staff where source_employee_id is not null) as staff_linked,
  (select count(*) from public.guards where source_employee_id is not null) as guards_linked;

rollback;
