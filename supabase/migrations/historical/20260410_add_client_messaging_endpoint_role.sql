alter table public.client_messaging_endpoints
add column if not exists endpoint_role text not null default 'client';

update public.client_messaging_endpoints
set endpoint_role = 'client'
where endpoint_role is null
   or length(btrim(endpoint_role)) = 0;

update public.client_messaging_endpoints
set endpoint_role = 'client'
where site_id = 'SITE-MS-VALLEE-RESIDENCE';
