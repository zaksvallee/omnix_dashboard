alter table public.site_intelligence_profiles
  add column if not exists alert_with_snapshot boolean not null default true;

alter table public.site_intelligence_profiles
  add column if not exists alert_with_buttons boolean not null default true;

alter table public.site_intelligence_profiles
  add column if not exists response_mode text not null default 'passive';
