# Guard Directory Supabase Contract

This contract defines the onboarding directory tables used to create and manage:
- clients
- sites
- employees (central staff registry)
- vehicles
- incidents evidence chain

Migration source:
- [202603120001_create_guard_directory_tables.sql](/Users/zaks/omnix_dashboard/supabase/migrations/202603120001_create_guard_directory_tables.sql)
- [202603120002_expand_onyx_operational_registry.sql](/Users/zaks/omnix_dashboard/supabase/migrations/202603120002_expand_onyx_operational_registry.sql)
- [202603120003_seed_guard_directory_baseline.sql](/Users/zaks/omnix_dashboard/supabase/migrations/202603120003_seed_guard_directory_baseline.sql)
- [202603120004_sync_legacy_directory_from_employees.sql](/Users/zaks/omnix_dashboard/supabase/migrations/202603120004_sync_legacy_directory_from_employees.sql)
- [202603120005_add_directory_delete_policies.sql](/Users/zaks/omnix_dashboard/supabase/migrations/202603120005_add_directory_delete_policies.sql)
- [202603120007_create_client_messaging_bridge_tables.sql](/Users/zaks/omnix_dashboard/supabase/migrations/202603120007_create_client_messaging_bridge_tables.sql)

## Tables

### `public.clients`
Client-level directory metadata.

Required fields:
- `client_id`
- `display_name`

Notes:
- `client_id` is the tenant key already used by operational tables.
- `metadata` is a JSON object for extensible client settings.

### `public.sites`
Site records for each client.

Required fields:
- `site_id`
- `client_id`
- `site_name`
- `timezone`

Notes:
- `site_code` is optional but unique per client when provided.
- Includes optional address, geofence, and map fields.

### `public.employees`
Unified ONYX staff registry with role discriminator and compliance fields.

Required fields:
- `client_id`
- `full_name`
- `surname`
- `employee_code`
- `id_number`
- `primary_role` (`controller`, `supervisor`, `guard`, `reaction_officer`, `manager`, `admin`)

Optional:
- `reporting_to_employee_id`
- `psira_number`
- `psira_grade`
- `psira_expiry`
- `has_driver_license`, `driver_license_code`, `driver_license_expiry`
- `has_pdp`, `pdp_expiry`
- `firearm_competency` (JSON object)
- `issued_firearm_serials` (array)
- `device_uid`
- `biometric_template_hash` (hash only)
- `auth_user_id`
- `employment_status` (`active`, `suspended`, `on_leave`, `terminated`)

### `public.employee_site_assignments`
Employee-to-site scope mapping.

Required fields:
- `client_id`
- `employee_id`
- `site_id`

### `public.vehicles`
Fleet records for reaction and supervisors.

Required fields:
- `client_id`
- `vehicle_callsign`
- `license_plate`
- `vehicle_type`
- `maintenance_status`

### `public.incidents`
Immutable-closure event chain records.

Required fields:
- `event_uid`
- `client_id`
- `site_id`
- `incident_type`
- `priority`
- `signal_received_at`

Timeline fields:
- `triage_time`
- `dispatch_time`
- `arrival_time`
- `resolution_time`

### `public.client_contacts`
Client/site messaging contacts used for delivery lanes.

Required fields:
- `client_id`
- `full_name`
- `role`

Optional:
- `site_id`
- `phone`
- `email`
- `telegram_user_id`
- `consent_at`
- `is_primary`
- `is_active`

### `public.client_messaging_endpoints`
Delivery endpoints per client/site for Telegram and in-app routing.

Required fields:
- `client_id`
- `provider` (`telegram`, `in_app`)
- `display_label`

Telegram-specific:
- `telegram_chat_id`
- `telegram_thread_id`

### `public.client_contact_endpoint_subscriptions`
Contact-to-endpoint routing rules and incident scope policy.

Required fields:
- `client_id`
- `contact_id`
- `endpoint_id`

Optional:
- `site_id`
- `incident_priorities` (JSON array, default `["p1","p2","p3","p4"]`)
- `incident_types` (JSON array)
- `quiet_hours` (JSON object)
- `is_active`

## RLS Summary

All directory tables have RLS enabled.

- `clients`: select scoped to `onyx_client_id()`, manage allowed for control roles.
- `sites`: control roles can read/manage all client sites; non-control users can read allowed site IDs only.
- `employees`: control-role read/write; guard-role users read their own employee row via `employee_code = jwt.guard_id`.
- `employee_site_assignments`: control-role read/write; guards read their own assignments.
- `vehicles`: control-role read/write; site-scoped read for authenticated users with site scope.
- `incidents`: site-scoped read/insert; control-role update.
- `client_contacts/client_messaging_endpoints/client_contact_endpoint_subscriptions`: select is client-scoped, write/delete is control-role scoped.
- `clients/sites/employees/employee_site_assignments/vehicles/incidents/controllers/staff/guards`: control-role delete policy added for scoped cleanup and admin maintenance.

## Legacy Sync Bridge

`202603120004_sync_legacy_directory_from_employees.sql` adds a compatibility bridge so canonical `employees` rows can still populate older integrations that read:
- `public.guards`
- `public.controllers`
- `public.staff`

How it works:
- adds `source_employee_id` to each legacy table
- upserts the mapped legacy row when `employees` changes
- refreshes site/home-site assignment when `employee_site_assignments` changes
- re-binds deterministic legacy IDs (`CTL-/GRD-/STF-<employee_uuid>`) globally (client-agnostic) before insert to avoid role-transition or client-transfer PK collisions
- reuses matching existing legacy rows first (employee code/device/email/name heuristics) to prevent duplicate active entries during rollout
- detaches non-target legacy links (`source_employee_id = null`) on role transitions so one canonical employee maps to one legacy lane at a time
- enforces deterministic-row upserts via legacy primary keys, then writes `source_employee_id` onto that canonical row
- deactivates legacy rows automatically when a canonical employee is deleted
- marks role-mismatched legacy rows inactive instead of deleting history

## Onboarding Insert Flow (Example)

```sql
insert into public.clients (client_id, display_name, legal_name)
values ('CLIENT-001', 'Acme Estates', 'Acme Estates Pty Ltd')
on conflict (client_id) do update
set
  display_name = excluded.display_name,
  legal_name = excluded.legal_name;

insert into public.sites (
  site_id,
  client_id,
  site_name,
  site_code,
  timezone
)
values (
  'SITE-SANDTON',
  'CLIENT-001',
  'Sandton Estate',
  'SANDTON',
  'Africa/Johannesburg'
)
on conflict (site_id) do update
set
  site_name = excluded.site_name,
  site_code = excluded.site_code,
  timezone = excluded.timezone;
```

Employee-centric onboarding example:

```sql
insert into public.employees (
  client_id,
  employee_code,
  full_name,
  surname,
  id_number,
  primary_role,
  psira_number,
  psira_grade,
  psira_expiry
)
values (
  'CLIENT-001',
  'GUARD-001',
  'Thabo',
  'Mokoena',
  '8001015009087',
  'guard',
  'PSIRA-1234567',
  'C',
  date '2027-02-28'
);

insert into public.employee_site_assignments (
  client_id,
  employee_id,
  site_id,
  is_primary
)
select
  e.client_id,
  e.id,
  'SITE-SANDTON',
  true
from public.employees e
where e.client_id = 'CLIENT-001'
  and e.employee_code = 'GUARD-001';
```

## Seed Baseline

`202603120003_seed_guard_directory_baseline.sql` provides idempotent bootstrap data for:
- clients
- sites
- controllers
- staff
- guards
- employees
- employee_site_assignments
- vehicles
- incidents (append-only with `on conflict do nothing`)

The seed is designed for local/dev bootstrapping and can be re-run safely:
- upserts are used for directory/fleet rows
- incident inserts avoid updates to respect closed-row immutability

## Post-Migration Verification

Run after applying `202603120004` and `202603120005`:

```sql
-- 1) Legacy sync coverage from canonical employees
select
  (select count(*) from public.employees) as employees_total,
  (select count(*) from public.controllers where source_employee_id is not null) as controllers_linked,
  (select count(*) from public.staff where source_employee_id is not null) as staff_linked,
  (select count(*) from public.guards where source_employee_id is not null) as guards_linked;

-- 2) Ensure no duplicate source mapping in legacy tables
select source_employee_id, count(*)
from (
  select source_employee_id from public.controllers where source_employee_id is not null
  union all
  select source_employee_id from public.staff where source_employee_id is not null
  union all
  select source_employee_id from public.guards where source_employee_id is not null
) links
group by source_employee_id
having count(*) > 1;

-- 3) Check delete policies exist
select tablename, policyname, cmd
from pg_policies
where schemaname = 'public'
  and policyname in (
    'clients_delete_policy',
    'sites_delete_policy',
    'employees_delete_policy',
    'employee_site_assignments_delete_policy',
    'vehicles_delete_policy',
    'incidents_delete_policy',
    'controllers_delete_policy',
    'staff_delete_policy',
    'guards_delete_policy'
  )
order by tablename, policyname;
```

Or run the bundled validation script:
- [guard_directory_registry_validation.sql](/Users/zaks/omnix_dashboard/supabase/verification/guard_directory_registry_validation.sql)
  - checks table/column presence, trigger existence + INSERT/UPDATE/DELETE coverage, delete policies, and duplicate legacy source mappings.
- [guard_directory_registry_sync_smoke.sql](/Users/zaks/omnix_dashboard/supabase/verification/guard_directory_registry_sync_smoke.sql)
  - runs a transactional smoke test for guard -> controller -> staff role transitions and employee delete detachment behavior.
