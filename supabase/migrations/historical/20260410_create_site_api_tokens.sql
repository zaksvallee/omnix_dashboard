create table if not exists public.site_api_tokens (
  id uuid primary key default gen_random_uuid(),
  site_id text not null,
  token text not null unique,
  label text,
  created_at timestamptz not null default now(),
  last_used_at timestamptz
);

create index if not exists site_api_tokens_site_id_idx
  on public.site_api_tokens (site_id, created_at desc);

alter table public.site_api_tokens enable row level security;
