create table if not exists public.onyx_settings (
  key text primary key,
  value_text text not null default '',
  updated_at timestamptz not null default timezone('utc', now())
);

insert into public.onyx_settings (key, value_text)
values ('sia_dc09_port', '5072')
on conflict (key) do nothing;

create table if not exists public.alarm_accounts (
  account_number text primary key,
  client_id text not null,
  site_id text not null,
  aes_key_override text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists alarm_accounts_client_site_idx
  on public.alarm_accounts (client_id, site_id);
