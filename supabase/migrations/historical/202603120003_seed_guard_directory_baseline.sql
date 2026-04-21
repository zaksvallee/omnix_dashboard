begin;

-- ---------------------------------------------------------------------------
-- Seed clients (legal entities / billing counterparties)
-- ---------------------------------------------------------------------------
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'clients'
      and column_name = 'name'
  ) then
    insert into public.clients (
      client_id,
      name,
      display_name,
      legal_name,
      client_type,
      contact_name,
      contact_email,
      contact_phone,
      billing_address,
      vat_number,
      sovereign_contact,
      contract_start,
      metadata,
      is_active
    )
    values
      (
        'CLT-001',
        'Waterfall Estates Group',
        'Waterfall Estates Group',
        'Waterfall Estates Group (Pty) Ltd',
        'guarding',
        'David Wilson',
        'david.wilson@waterfall.co.za',
        '+27 11 888 0001',
        '123 Waterfall Drive, Midrand, 1686',
        '4710123456',
        'David Wilson',
        date '2024-01-01',
        jsonb_build_object(
          'sla_tier', 'platinum',
          'onboarding_source', 'seed_migration',
          'service_lane', 'estate_guarding'
        ),
        true
      ),
      (
        'CLT-002',
        'Blue Ridge Properties',
        'Blue Ridge Properties',
        'Blue Ridge Properties (Pty) Ltd',
        'hybrid',
        'Lisa Anderson',
        'lisa.a@blueridge.co.za',
        '+27 11 888 0002',
        '45 Ridge Road, Johannesburg, 2001',
        '4510987654',
        'Lisa Anderson',
        date '2024-03-01',
        jsonb_build_object(
          'sla_tier', 'gold',
          'onboarding_source', 'seed_migration',
          'service_lane', 'hybrid_guarding_response'
        ),
        true
      )
    on conflict (client_id) do update
    set
      name = excluded.name,
      display_name = excluded.display_name,
      legal_name = excluded.legal_name,
      client_type = excluded.client_type,
      contact_name = excluded.contact_name,
      contact_email = excluded.contact_email,
      contact_phone = excluded.contact_phone,
      billing_address = excluded.billing_address,
      vat_number = excluded.vat_number,
      sovereign_contact = excluded.sovereign_contact,
      contract_start = excluded.contract_start,
      metadata = excluded.metadata,
      is_active = excluded.is_active;
  else
    insert into public.clients (
      client_id,
      display_name,
      legal_name,
      client_type,
      contact_name,
      contact_email,
      contact_phone,
      billing_address,
      vat_number,
      sovereign_contact,
      contract_start,
      metadata,
      is_active
    )
    values
      (
        'CLT-001',
        'Waterfall Estates Group',
        'Waterfall Estates Group (Pty) Ltd',
        'guarding',
        'David Wilson',
        'david.wilson@waterfall.co.za',
        '+27 11 888 0001',
        '123 Waterfall Drive, Midrand, 1686',
        '4710123456',
        'David Wilson',
        date '2024-01-01',
        jsonb_build_object(
          'sla_tier', 'platinum',
          'onboarding_source', 'seed_migration',
          'service_lane', 'estate_guarding'
        ),
        true
      ),
      (
        'CLT-002',
        'Blue Ridge Properties',
        'Blue Ridge Properties (Pty) Ltd',
        'hybrid',
        'Lisa Anderson',
        'lisa.a@blueridge.co.za',
        '+27 11 888 0002',
        '45 Ridge Road, Johannesburg, 2001',
        '4510987654',
        'Lisa Anderson',
        date '2024-03-01',
        jsonb_build_object(
          'sla_tier', 'gold',
          'onboarding_source', 'seed_migration',
          'service_lane', 'hybrid_guarding_response'
        ),
        true
      )
    on conflict (client_id) do update
    set
      display_name = excluded.display_name,
      legal_name = excluded.legal_name,
      client_type = excluded.client_type,
      contact_name = excluded.contact_name,
      contact_email = excluded.contact_email,
      contact_phone = excluded.contact_phone,
      billing_address = excluded.billing_address,
      vat_number = excluded.vat_number,
      sovereign_contact = excluded.sovereign_contact,
      contract_start = excluded.contract_start,
      metadata = excluded.metadata,
      is_active = excluded.is_active;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Seed sites (deployment environments)
-- ---------------------------------------------------------------------------
insert into public.sites (
  site_id,
  client_id,
  site_name,
  site_code,
  name,
  code,
  timezone,
  physical_address,
  address_line_1,
  city,
  region,
  postal_code,
  country_code,
  latitude,
  longitude,
  geofence_radius_meters,
  entry_protocol,
  site_layout_map_url,
  hardware_ids,
  zone_labels,
  risk_profile,
  risk_rating,
  guard_nudge_frequency_minutes,
  escalation_trigger_minutes,
  metadata,
  is_active
)
values
  (
    'WTF-MAIN',
    'CLT-001',
    'Waterfall Estate Main',
    'WTF-MAIN',
    'Waterfall Estate Main',
    'WTF-MAIN',
    'Africa/Johannesburg',
    '123 Waterfall Drive, Midrand, 1686',
    '123 Waterfall Drive',
    'Midrand',
    'Gauteng',
    '1686',
    'ZA',
    -26.0285,
    28.1122,
    500,
    'Gate 1 intercom + remote unlock. Security code required after 22:00.',
    'https://cdn.onyx.local/site-layouts/wtf-main.pdf',
    jsonb_build_array('FSK-WTF-001', 'HIK-WTF-GATE-01', 'CAM-WTF-PERIM-04'),
    jsonb_build_object(
      'zone_1', 'North Fence Mesh',
      'zone_2', 'South Gate Motor',
      'zone_3', 'Clubhouse Perimeter'
    ),
    'residential',
    3,
    15,
    2,
    jsonb_build_object(
      'onboarding_source', 'seed_migration',
      'baseline_capture_required', true
    ),
    true
  ),
  (
    'WTF-SOUTH',
    'CLT-001',
    'Waterfall Estate South Gate',
    'WTF-SOUTH',
    'Waterfall Estate South Gate',
    'WTF-SOUTH',
    'Africa/Johannesburg',
    '97 Waterfall Drive, Midrand, 1686',
    '97 Waterfall Drive',
    'Midrand',
    'Gauteng',
    '1686',
    'ZA',
    -26.0348,
    28.1179,
    350,
    'RFID boom with fallback keypad and radio verification.',
    'https://cdn.onyx.local/site-layouts/wtf-south.pdf',
    jsonb_build_array('FSK-WTF-002', 'HIK-WTF-SOUTH-02'),
    jsonb_build_object(
      'zone_1', 'South Perimeter',
      'zone_2', 'Visitor Parking',
      'zone_3', 'Delivery Access'
    ),
    'mixed_use',
    4,
    12,
    2,
    jsonb_build_object(
      'onboarding_source', 'seed_migration',
      'baseline_capture_required', true
    ),
    true
  ),
  (
    'BLR-MAIN',
    'CLT-002',
    'Blue Ridge Security Campus',
    'BLR-MAIN',
    'Blue Ridge Security Campus',
    'BLR-MAIN',
    'Africa/Johannesburg',
    '45 Ridge Road, Johannesburg, 2001',
    '45 Ridge Road',
    'Johannesburg',
    'Gauteng',
    '2001',
    'ZA',
    -26.1234,
    28.0567,
    300,
    'Armed response keypad at gatehouse. Two-factor code required.',
    'https://cdn.onyx.local/site-layouts/blr-main.pdf',
    jsonb_build_array('FSK-BLR-001', 'HIK-BLR-CTRL-01', 'CAM-BLR-YARD-07'),
    jsonb_build_object(
      'zone_1', 'Warehouse North Fence',
      'zone_2', 'Fuel Bay',
      'zone_3', 'Dispatch Yard'
    ),
    'industrial',
    5,
    10,
    1,
    jsonb_build_object(
      'onboarding_source', 'seed_migration',
      'baseline_capture_required', true
    ),
    true
  )
on conflict (site_id) do update
set
  client_id = excluded.client_id,
  site_name = excluded.site_name,
  site_code = excluded.site_code,
  name = excluded.name,
  code = excluded.code,
  timezone = excluded.timezone,
  physical_address = excluded.physical_address,
  address_line_1 = excluded.address_line_1,
  city = excluded.city,
  region = excluded.region,
  postal_code = excluded.postal_code,
  country_code = excluded.country_code,
  latitude = excluded.latitude,
  longitude = excluded.longitude,
  geofence_radius_meters = excluded.geofence_radius_meters,
  entry_protocol = excluded.entry_protocol,
  site_layout_map_url = excluded.site_layout_map_url,
  hardware_ids = excluded.hardware_ids,
  zone_labels = excluded.zone_labels,
  risk_profile = excluded.risk_profile,
  risk_rating = excluded.risk_rating,
  guard_nudge_frequency_minutes = excluded.guard_nudge_frequency_minutes,
  escalation_trigger_minutes = excluded.escalation_trigger_minutes,
  metadata = excluded.metadata,
  is_active = excluded.is_active;

-- ---------------------------------------------------------------------------
-- Seed controller roster (legacy table kept for compatibility)
-- ---------------------------------------------------------------------------
insert into public.controllers (
  controller_id,
  client_id,
  home_site_id,
  full_name,
  role_label,
  employee_code,
  contact_phone,
  contact_email,
  metadata,
  is_active
)
values
  (
    'CTL-001',
    'CLT-001',
    'WTF-MAIN',
    'Zak Naidoo',
    'controller',
    'CTRL-001',
    '+27 82 400 0101',
    'zak.naidoo@onyx-security.co.za',
    jsonb_build_object('shift_pattern', 'Night (18:00-06:00)'),
    true
  ),
  (
    'CTL-002',
    'CLT-002',
    'BLR-MAIN',
    'Mpho Dlamini',
    'controller',
    'CTRL-002',
    '+27 82 400 0102',
    'mpho.dlamini@onyx-security.co.za',
    jsonb_build_object('shift_pattern', 'Day (06:00-18:00)'),
    true
  )
on conflict (controller_id) do update
set
  client_id = excluded.client_id,
  home_site_id = excluded.home_site_id,
  full_name = excluded.full_name,
  role_label = excluded.role_label,
  employee_code = excluded.employee_code,
  contact_phone = excluded.contact_phone,
  contact_email = excluded.contact_email,
  metadata = excluded.metadata,
  is_active = excluded.is_active;

-- ---------------------------------------------------------------------------
-- Seed staff roster (legacy table kept for compatibility)
-- ---------------------------------------------------------------------------
insert into public.staff (
  staff_id,
  client_id,
  site_id,
  full_name,
  staff_role,
  employee_code,
  contact_phone,
  contact_email,
  metadata,
  is_active
)
values
  (
    'STF-001',
    'CLT-001',
    'WTF-MAIN',
    'Ruth Maseko',
    'control_room_assistant',
    'STF-101',
    '+27 82 410 0101',
    'ruth.maseko@onyx-security.co.za',
    jsonb_build_object('department', 'operations'),
    true
  ),
  (
    'STF-002',
    'CLT-002',
    'BLR-MAIN',
    'Kagiso Molefe',
    'dispatcher',
    'STF-201',
    '+27 82 410 0102',
    'kagiso.molefe@onyx-security.co.za',
    jsonb_build_object('department', 'dispatch'),
    true
  )
on conflict (staff_id) do update
set
  client_id = excluded.client_id,
  site_id = excluded.site_id,
  full_name = excluded.full_name,
  staff_role = excluded.staff_role,
  employee_code = excluded.employee_code,
  contact_phone = excluded.contact_phone,
  contact_email = excluded.contact_email,
  metadata = excluded.metadata,
  is_active = excluded.is_active;

-- ---------------------------------------------------------------------------
-- Seed guards roster (legacy table kept for compatibility)
-- ---------------------------------------------------------------------------
do $$
begin
  create temporary table _seed_guards (
    guard_id text,
    client_id text,
    primary_site_id text,
    full_name text,
    first_name text,
    last_name text,
    badge_number text,
    ptt_identity text,
    device_serial text,
    contact_phone text,
    contact_email text,
    metadata jsonb,
    is_active boolean
  ) on commit drop;

  insert into _seed_guards (
    guard_id,
    client_id,
    primary_site_id,
    full_name,
    first_name,
    last_name,
    badge_number,
    ptt_identity,
    device_serial,
    contact_phone,
    contact_email,
    metadata,
    is_active
  )
  values
    (
      'GRD-001',
      'CLT-001',
      'WTF-MAIN',
      'Thabo Mokoena',
      'Thabo',
      'Mokoena',
      'BADGE-441',
      'ptt://onyx/guard/thabo-mokoena',
      'BV5300P-THABO-001',
      '+27 82 555 0441',
      'thabo.m@onyx-security.co.za',
      jsonb_build_object('psira_number', 'PSI-441-2024'),
      true
    ),
    (
      'GRD-002',
      'CLT-001',
      'WTF-SOUTH',
      'Sipho Ndlovu',
      'Sipho',
      'Ndlovu',
      'BADGE-442',
      'ptt://onyx/guard/sipho-ndlovu',
      'BV5300P-SIPHO-001',
      '+27 83 444 0442',
      'sipho.n@onyx-security.co.za',
      jsonb_build_object('psira_number', 'PSI-442-2024'),
      true
    ),
    (
      'GRD-003',
      'CLT-002',
      'BLR-MAIN',
      'Lerato Moletsane',
      'Lerato',
      'Moletsane',
      'BADGE-552',
      'ptt://onyx/guard/lerato-moletsane',
      'BV5300P-LERATO-001',
      '+27 84 333 0552',
      'lerato.m@onyx-security.co.za',
      jsonb_build_object('psira_number', 'PSI-552-2024'),
      true
    );

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'guards'
      and column_name = 'first_name'
  ) then
    update public.guards g
    set
      client_id = s.client_id,
      primary_site_id = s.primary_site_id,
      full_name = s.full_name,
      first_name = s.first_name,
      last_name = s.last_name,
      badge_number = s.badge_number,
      ptt_identity = s.ptt_identity,
      device_serial = s.device_serial,
      contact_phone = s.contact_phone,
      contact_email = s.contact_email,
      metadata = s.metadata,
      is_active = s.is_active
    from _seed_guards s
    where g.guard_id = s.guard_id;

    insert into public.guards (
      guard_id,
      client_id,
      primary_site_id,
      full_name,
      first_name,
      last_name,
      badge_number,
      ptt_identity,
      device_serial,
      contact_phone,
      contact_email,
      metadata,
      is_active
    )
    select
      s.guard_id,
      s.client_id,
      s.primary_site_id,
      s.full_name,
      s.first_name,
      s.last_name,
      s.badge_number,
      s.ptt_identity,
      s.device_serial,
      s.contact_phone,
      s.contact_email,
      s.metadata,
      s.is_active
    from _seed_guards s
    where not exists (
      select 1
      from public.guards g
      where g.guard_id = s.guard_id
    );
  else
    update public.guards g
    set
      client_id = s.client_id,
      primary_site_id = s.primary_site_id,
      full_name = s.full_name,
      badge_number = s.badge_number,
      ptt_identity = s.ptt_identity,
      device_serial = s.device_serial,
      contact_phone = s.contact_phone,
      contact_email = s.contact_email,
      metadata = s.metadata,
      is_active = s.is_active
    from _seed_guards s
    where g.guard_id = s.guard_id;

    insert into public.guards (
      guard_id,
      client_id,
      primary_site_id,
      full_name,
      badge_number,
      ptt_identity,
      device_serial,
      contact_phone,
      contact_email,
      metadata,
      is_active
    )
    select
      s.guard_id,
      s.client_id,
      s.primary_site_id,
      s.full_name,
      s.badge_number,
      s.ptt_identity,
      s.device_serial,
      s.contact_phone,
      s.contact_email,
      s.metadata,
      s.is_active
    from _seed_guards s
    where not exists (
      select 1
      from public.guards g
      where g.guard_id = s.guard_id
    );
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Seed unified employees registry (source of truth for onboarding)
-- ---------------------------------------------------------------------------
insert into public.employees (
  client_id,
  employee_code,
  full_name,
  surname,
  id_number,
  date_of_birth,
  primary_role,
  psira_number,
  psira_grade,
  psira_expiry,
  has_driver_license,
  driver_license_code,
  driver_license_expiry,
  has_pdp,
  pdp_expiry,
  firearm_competency,
  issued_firearm_serials,
  device_uid,
  contact_phone,
  contact_email,
  employment_status,
  metadata
)
values
  (
    'CLT-001',
    'EMP-441',
    'Thabo',
    'Mokoena',
    '8001015009087',
    date '1980-01-01',
    'guard',
    'PSI-441-2024',
    'C',
    date '2026-10-31',
    false,
    null,
    null,
    false,
    null,
    jsonb_build_object('handgun', false, 'shotgun', false, 'rifle', false),
    array[]::text[],
    'BV5300P-THABO-001',
    '+27 82 555 0441',
    'thabo.m@onyx-security.co.za',
    'active',
    jsonb_build_object(
      'shift_pattern', 'Night (18:00-06:00)',
      'onboarding_source', 'seed_migration'
    )
  ),
  (
    'CLT-001',
    'EMP-442',
    'Sipho',
    'Ndlovu',
    '8204045011088',
    date '1982-04-04',
    'reaction_officer',
    'PSI-442-2024',
    'B',
    date '2026-08-15',
    true,
    'Code 10',
    date '2028-09-30',
    true,
    date '2027-12-31',
    jsonb_build_object('handgun', true, 'shotgun', true, 'rifle', false),
    array['FH-778211', 'SG-224189']::text[],
    'BV5300P-SIPHO-001',
    '+27 83 444 0442',
    'sipho.n@onyx-security.co.za',
    'active',
    jsonb_build_object(
      'shift_pattern', 'Night (18:00-06:00)',
      'onboarding_source', 'seed_migration'
    )
  ),
  (
    'CLT-001',
    'EMP-443',
    'Nomsa',
    'Khumalo',
    '8607070067089',
    date '1986-07-07',
    'supervisor',
    'PSI-443-2024',
    'B',
    date '2027-01-20',
    true,
    'Code 8',
    date '2029-05-31',
    false,
    null,
    jsonb_build_object('handgun', true, 'shotgun', false, 'rifle', false),
    array['FH-118732']::text[],
    'BV5300P-NOMSA-001',
    '+27 84 333 0443',
    'nomsa.k@onyx-security.co.za',
    'active',
    jsonb_build_object(
      'shift_pattern', 'Day (06:00-18:00)',
      'onboarding_source', 'seed_migration'
    )
  ),
  (
    'CLT-001',
    'EMP-444',
    'Zak',
    'Naidoo',
    '8502125099081',
    date '1985-02-12',
    'controller',
    null,
    null,
    null,
    false,
    null,
    null,
    false,
    null,
    '{}'::jsonb,
    array[]::text[],
    'ONYX-CTRL-ZAK-001',
    '+27 82 400 0101',
    'zak.naidoo@onyx-security.co.za',
    'active',
    jsonb_build_object(
      'shift_pattern', 'Night (18:00-06:00)',
      'onboarding_source', 'seed_migration'
    )
  ),
  (
    'CLT-002',
    'EMP-552',
    'Lerato',
    'Moletsane',
    '9005050040083',
    date '1990-05-05',
    'guard',
    'PSI-552-2024',
    'C',
    date '2026-11-30',
    false,
    null,
    null,
    false,
    null,
    '{}'::jsonb,
    array[]::text[],
    'BV5300P-LERATO-001',
    '+27 84 333 0552',
    'lerato.m@onyx-security.co.za',
    'active',
    jsonb_build_object(
      'shift_pattern', 'Night (18:00-06:00)',
      'onboarding_source', 'seed_migration'
    )
  ),
  (
    'CLT-002',
    'EMP-553',
    'Kabelo',
    'Mabena',
    '8709095077084',
    date '1987-09-09',
    'reaction_officer',
    'PSI-553-2024',
    'B',
    date '2027-03-31',
    true,
    'Code 10',
    date '2029-07-31',
    true,
    date '2028-02-28',
    jsonb_build_object('handgun', true, 'shotgun', true, 'rifle', false),
    array['FH-991210']::text[],
    'BV5300P-KABELO-001',
    '+27 82 422 0553',
    'kabelo.m@onyx-security.co.za',
    'active',
    jsonb_build_object(
      'shift_pattern', 'Day (06:00-18:00)',
      'onboarding_source', 'seed_migration'
    )
  )
on conflict (client_id, employee_code) do update
set
  full_name = excluded.full_name,
  surname = excluded.surname,
  id_number = excluded.id_number,
  date_of_birth = excluded.date_of_birth,
  primary_role = excluded.primary_role,
  psira_number = excluded.psira_number,
  psira_grade = excluded.psira_grade,
  psira_expiry = excluded.psira_expiry,
  has_driver_license = excluded.has_driver_license,
  driver_license_code = excluded.driver_license_code,
  driver_license_expiry = excluded.driver_license_expiry,
  has_pdp = excluded.has_pdp,
  pdp_expiry = excluded.pdp_expiry,
  firearm_competency = excluded.firearm_competency,
  issued_firearm_serials = excluded.issued_firearm_serials,
  device_uid = excluded.device_uid,
  contact_phone = excluded.contact_phone,
  contact_email = excluded.contact_email,
  employment_status = excluded.employment_status,
  metadata = excluded.metadata;

with seeded_employees as (
  select e.id, e.client_id
  from public.employees e
  where (e.client_id, e.employee_code) in (
    ('CLT-001', 'EMP-441'),
    ('CLT-001', 'EMP-442'),
    ('CLT-001', 'EMP-443'),
    ('CLT-001', 'EMP-444'),
    ('CLT-002', 'EMP-552'),
    ('CLT-002', 'EMP-553')
  )
)
update public.employee_site_assignments esa
set
  is_primary = false,
  updated_at = timezone('utc', now())
where esa.employee_id in (select id from seeded_employees)
  and esa.assignment_status = 'active'
  and esa.is_primary = true;

insert into public.employee_site_assignments (
  client_id,
  employee_id,
  site_id,
  is_primary,
  assignment_status,
  starts_on
)
select
  e.client_id,
  e.id,
  mapping.site_id,
  true,
  'active',
  mapping.starts_on
from (
  values
    ('CLT-001', 'EMP-441', 'WTF-MAIN', date '2024-01-01'),
    ('CLT-001', 'EMP-442', 'WTF-SOUTH', date '2024-01-01'),
    ('CLT-001', 'EMP-443', 'WTF-MAIN', date '2024-01-01'),
    ('CLT-001', 'EMP-444', 'WTF-MAIN', date '2024-01-01'),
    ('CLT-002', 'EMP-552', 'BLR-MAIN', date '2024-03-01'),
    ('CLT-002', 'EMP-553', 'BLR-MAIN', date '2024-03-01')
) as mapping(client_id, employee_code, site_id, starts_on)
join public.employees e
  on e.client_id = mapping.client_id
 and e.employee_code = mapping.employee_code
on conflict (employee_id, site_id) do update
set
  is_primary = excluded.is_primary,
  assignment_status = excluded.assignment_status,
  ends_on = null,
  starts_on = least(public.employee_site_assignments.starts_on, excluded.starts_on),
  updated_at = timezone('utc', now());

-- ---------------------------------------------------------------------------
-- Seed vehicles (reaction & supervisor fleet)
-- ---------------------------------------------------------------------------
insert into public.vehicles (
  client_id,
  site_id,
  vehicle_callsign,
  license_plate,
  vehicle_type,
  maintenance_status,
  service_due_date,
  roadworthy_expiry,
  odometer_km,
  fuel_percent,
  assigned_employee_id,
  metadata,
  is_active
)
values
  (
    'CLT-001',
    'WTF-SOUTH',
    'Echo 1',
    'CA 458-901',
    'armed_response_vehicle',
    'ok',
    date '2026-06-15',
    date '2027-01-31',
    118240,
    74.50,
    (
      select e.id
      from public.employees e
      where e.client_id = 'CLT-001'
        and e.employee_code = 'EMP-442'
    ),
    jsonb_build_object('tracker_id', 'GPS-ECHO-1'),
    true
  ),
  (
    'CLT-001',
    'WTF-MAIN',
    'Sigma 2',
    'CA 774-336',
    'supervisor_bakkie',
    'tires_check',
    date '2026-05-20',
    date '2026-12-31',
    92410,
    58.00,
    (
      select e.id
      from public.employees e
      where e.client_id = 'CLT-001'
        and e.employee_code = 'EMP-443'
    ),
    jsonb_build_object('tracker_id', 'GPS-SIGMA-2'),
    true
  ),
  (
    'CLT-002',
    'BLR-MAIN',
    'Delta 1',
    'CA 910-224',
    'armed_response_vehicle',
    'ok',
    date '2026-07-10',
    date '2027-03-31',
    132775,
    66.20,
    (
      select e.id
      from public.employees e
      where e.client_id = 'CLT-002'
        and e.employee_code = 'EMP-553'
    ),
    jsonb_build_object('tracker_id', 'GPS-DELTA-1'),
    true
  )
on conflict (client_id, vehicle_callsign) do update
set
  site_id = excluded.site_id,
  license_plate = excluded.license_plate,
  vehicle_type = excluded.vehicle_type,
  maintenance_status = excluded.maintenance_status,
  service_due_date = excluded.service_due_date,
  roadworthy_expiry = excluded.roadworthy_expiry,
  odometer_km = excluded.odometer_km,
  fuel_percent = excluded.fuel_percent,
  assigned_employee_id = excluded.assigned_employee_id,
  metadata = excluded.metadata,
  is_active = excluded.is_active;

-- ---------------------------------------------------------------------------
-- Seed incidents (append-only style; do not mutate existing closed rows)
-- ---------------------------------------------------------------------------
insert into public.incidents (
  event_uid,
  client_id,
  site_id,
  incident_type,
  priority,
  status,
  signal_received_at,
  triage_time,
  dispatch_time,
  arrival_time,
  resolution_time,
  controller_notes,
  field_report,
  media_attachments,
  evidence_hash,
  linked_employee_id,
  linked_guard_ops_event_id,
  metadata
)
values
  (
    'EVT-20260310-0001',
    'CLT-001',
    'WTF-MAIN',
    'breach',
    'p1',
    'closed',
    timestamptz '2026-03-10 20:01:00+00',
    timestamptz '2026-03-10 20:02:00+00',
    timestamptz '2026-03-10 20:03:30+00',
    timestamptz '2026-03-10 20:08:10+00',
    timestamptz '2026-03-10 20:14:45+00',
    'Perimeter beam breach near north fence; verified with camera feed.',
    'Reaction officer found loose panel, re-secured and confirmed no intrusion.',
    array[
      'https://cdn.onyx.local/evidence/evt-20260310-0001/photo-1.jpg',
      'https://cdn.onyx.local/evidence/evt-20260310-0001/photo-2.jpg'
    ]::text[],
    'sha256:6f1d4a908d90a5d2d8db9fce1fe59a58d93f6b73ca9132741fd736c7d9f4a8aa',
    (
      select e.id
      from public.employees e
      where e.client_id = 'CLT-001'
        and e.employee_code = 'EMP-442'
    ),
    'ops_evt_wtf_0001',
    jsonb_build_object(
      'source', 'seed_migration',
      'cluster', 'WTF-PERIM-01'
    )
  ),
  (
    'EVT-20260311-0012',
    'CLT-002',
    'BLR-MAIN',
    'technical_failure',
    'p3',
    'detected',
    timestamptz '2026-03-11 04:11:00+00',
    null,
    null,
    null,
    null,
    'Signal jitter on warehouse north panel channel.',
    null,
    array[]::text[],
    'sha256:cb4639ff07a739f5a8da40ec52bcca2f0438da4d08e2c4f6220907f4ba6f53bb',
    null,
    'ops_evt_blr_0012',
    jsonb_build_object(
      'source', 'seed_migration',
      'requires_maintenance', true
    )
  ),
  (
    'EVT-20260311-0045',
    'CLT-001',
    'WTF-SOUTH',
    'panic',
    'p2',
    'on_site',
    timestamptz '2026-03-11 22:15:00+00',
    timestamptz '2026-03-11 22:16:00+00',
    timestamptz '2026-03-11 22:17:30+00',
    timestamptz '2026-03-11 22:23:40+00',
    null,
    'Panic press from gatehouse keypad, client contacted, no safeword issued.',
    'Officer arrived and initiated physical sweep.',
    array[
      'https://cdn.onyx.local/evidence/evt-20260311-0045/audio-1.ogg'
    ]::text[],
    'sha256:ea7ced1f5f9062ef6334a44f7b2f0dc2776c42f4941045926ece4b7d561bd2ff',
    (
      select e.id
      from public.employees e
      where e.client_id = 'CLT-001'
        and e.employee_code = 'EMP-442'
    ),
    'ops_evt_wtf_0045',
    jsonb_build_object(
      'source', 'seed_migration',
      'ai_escalated', true
    )
  )
on conflict (event_uid) do nothing;

commit;
