-- ONYX Guard Directory Legacy Sync Smoke Test
--
-- Validates functional behavior of:
-- public.sync_legacy_directory_employee(uuid)
-- and its triggers on employees + employee_site_assignments.
--
-- Behavior:
-- - creates disposable directory rows
-- - verifies guard -> controller -> staff role transitions
-- - verifies delete path detaches legacy mappings
-- - rolls back everything at the end

begin;

do $$
declare
  run_tag text := 'SMOKE-' || floor(extract(epoch from clock_timestamp()))::bigint::text;
  test_client_id text := 'DEMO-SMOKE-CLT-' || floor(extract(epoch from clock_timestamp()))::bigint::text;
  test_site_id text := 'DEMO-SMOKE-SITE-' || floor(extract(epoch from clock_timestamp()))::bigint::text;
  test_employee_id uuid;
  test_employee_code text := 'DEMO-SMOKE-EMP-' || floor(extract(epoch from clock_timestamp()))::bigint::text;
  expected_guard_id text;
  expected_controller_id text;
  expected_staff_id text;
  guard_links integer;
  controller_links integer;
  staff_links integer;
begin
  insert into public.clients (
    client_id,
    display_name,
    legal_name,
    is_active,
    metadata
  ) values (
    test_client_id,
    'Smoke Test Client ' || run_tag,
    'Smoke Test Client ' || run_tag || ' Pty Ltd',
    true,
    jsonb_build_object('source', 'guard_directory_registry_sync_smoke')
  );

  insert into public.sites (
    site_id,
    client_id,
    site_name,
    timezone,
    physical_address,
    is_active,
    metadata
  ) values (
    test_site_id,
    test_client_id,
    'Smoke Test Site ' || run_tag,
    'Africa/Johannesburg',
    '1 Smoke Test Avenue, Johannesburg',
    true,
    jsonb_build_object('source', 'guard_directory_registry_sync_smoke')
  );

  insert into public.employees (
    client_id,
    employee_code,
    full_name,
    surname,
    id_number,
    primary_role,
    contact_phone,
    contact_email,
    metadata
  ) values (
    test_client_id,
    test_employee_code,
    'Smoke',
    'Operator',
    '9001015009087',
    'guard',
    '+27 82 000 0000',
    lower(test_employee_code) || '@example.com',
    jsonb_build_object('source', 'guard_directory_registry_sync_smoke')
  )
  returning id into test_employee_id;

  insert into public.employee_site_assignments (
    client_id,
    employee_id,
    site_id,
    is_primary,
    assignment_status
  ) values (
    test_client_id,
    test_employee_id,
    test_site_id,
    true,
    'active'
  );

  expected_guard_id := 'GRD-' || replace(test_employee_id::text, '-', '');
  expected_controller_id := 'CTL-' || replace(test_employee_id::text, '-', '');
  expected_staff_id := 'STF-' || replace(test_employee_id::text, '-', '');

  select count(*) into guard_links
  from public.guards
  where source_employee_id = test_employee_id
    and guard_id = expected_guard_id;

  if guard_links <> 1 then
    raise exception
      'Smoke test failed: expected 1 guard legacy link, got %',
      guard_links;
  end if;

  select count(*) into controller_links
  from public.controllers
  where source_employee_id = test_employee_id;

  if controller_links <> 0 then
    raise exception
      'Smoke test failed: expected 0 controller links in guard phase, got %',
      controller_links;
  end if;

  select count(*) into staff_links
  from public.staff
  where source_employee_id = test_employee_id;

  if staff_links <> 0 then
    raise exception
      'Smoke test failed: expected 0 staff links in guard phase, got %',
      staff_links;
  end if;

  update public.employees
  set primary_role = 'controller'
  where id = test_employee_id;

  select count(*) into controller_links
  from public.controllers
  where source_employee_id = test_employee_id
    and controller_id = expected_controller_id;

  if controller_links <> 1 then
    raise exception
      'Smoke test failed: expected 1 controller legacy link after role transition, got %',
      controller_links;
  end if;

  select count(*) into guard_links
  from public.guards
  where source_employee_id = test_employee_id;

  if guard_links <> 0 then
    raise exception
      'Smoke test failed: expected 0 guard links after controller transition, got %',
      guard_links;
  end if;

  update public.employees
  set primary_role = 'admin'
  where id = test_employee_id;

  select count(*) into staff_links
  from public.staff
  where source_employee_id = test_employee_id
    and staff_id = expected_staff_id;

  if staff_links <> 1 then
    raise exception
      'Smoke test failed: expected 1 staff legacy link after admin transition, got %',
      staff_links;
  end if;

  select count(*) into controller_links
  from public.controllers
  where source_employee_id = test_employee_id;

  if controller_links <> 0 then
    raise exception
      'Smoke test failed: expected 0 controller links after admin transition, got %',
      controller_links;
  end if;

  delete from public.employees where id = test_employee_id;

  select count(*) into guard_links
  from public.guards
  where source_employee_id = test_employee_id;
  select count(*) into controller_links
  from public.controllers
  where source_employee_id = test_employee_id;
  select count(*) into staff_links
  from public.staff
  where source_employee_id = test_employee_id;

  if guard_links <> 0 or controller_links <> 0 or staff_links <> 0 then
    raise exception
      'Smoke test failed: expected all source links detached after employee delete. guard=% controller=% staff=%',
      guard_links, controller_links, staff_links;
  end if;
end;
$$;

rollback;
