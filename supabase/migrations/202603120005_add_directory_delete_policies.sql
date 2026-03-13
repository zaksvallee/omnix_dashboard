begin;

drop policy if exists clients_delete_policy on public.clients;
create policy clients_delete_policy
on public.clients
for delete
to authenticated
using (
  client_id = public.onyx_client_id()
  and public.onyx_is_control_role()
);

drop policy if exists sites_delete_policy on public.sites;
create policy sites_delete_policy
on public.sites
for delete
to authenticated
using (
  client_id = public.onyx_client_id()
  and public.onyx_is_control_role()
);

drop policy if exists employees_delete_policy on public.employees;
create policy employees_delete_policy
on public.employees
for delete
to authenticated
using (
  client_id = public.onyx_client_id()
  and public.onyx_is_control_role()
);

drop policy if exists employee_site_assignments_delete_policy on public.employee_site_assignments;
create policy employee_site_assignments_delete_policy
on public.employee_site_assignments
for delete
to authenticated
using (
  client_id = public.onyx_client_id()
  and public.onyx_is_control_role()
);

drop policy if exists vehicles_delete_policy on public.vehicles;
create policy vehicles_delete_policy
on public.vehicles
for delete
to authenticated
using (
  client_id = public.onyx_client_id()
  and public.onyx_is_control_role()
);

drop policy if exists incidents_delete_policy on public.incidents;
create policy incidents_delete_policy
on public.incidents
for delete
to authenticated
using (
  client_id = public.onyx_client_id()
  and public.onyx_is_control_role()
);

drop policy if exists controllers_delete_policy on public.controllers;
create policy controllers_delete_policy
on public.controllers
for delete
to authenticated
using (
  client_id = public.onyx_client_id()
  and public.onyx_is_control_role()
);

drop policy if exists staff_delete_policy on public.staff;
create policy staff_delete_policy
on public.staff
for delete
to authenticated
using (
  client_id = public.onyx_client_id()
  and public.onyx_is_control_role()
);

drop policy if exists guards_delete_policy on public.guards;
create policy guards_delete_policy
on public.guards
for delete
to authenticated
using (
  client_id = public.onyx_client_id()
  and public.onyx_is_control_role()
);

commit;
