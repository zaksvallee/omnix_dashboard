alter table public.guard_ops_media
  add column if not exists visual_norm_mode text,
  add column if not exists visual_norm_metadata jsonb not null default '{}'::jsonb;

update public.guard_ops_media
set visual_norm_mode = 'day'
where visual_norm_mode is null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'guard_ops_media_visual_norm_mode_valid'
  ) then
    alter table public.guard_ops_media
      add constraint guard_ops_media_visual_norm_mode_valid
      check (visual_norm_mode is null or visual_norm_mode in ('day', 'night', 'ir'));
  end if;
end;
$$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'guard_ops_media_visual_norm_min_match_score_valid'
  ) then
    alter table public.guard_ops_media
      add constraint guard_ops_media_visual_norm_min_match_score_valid
      check (
        not (visual_norm_metadata ? 'min_match_score')
        or (
          jsonb_typeof(visual_norm_metadata -> 'min_match_score') = 'number'
          and (visual_norm_metadata ->> 'min_match_score')::int between 0 and 100
        )
      );
  end if;
end;
$$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'guard_ops_media_visual_norm_ir_required'
  ) then
    alter table public.guard_ops_media
      add constraint guard_ops_media_visual_norm_ir_required
      check (
        visual_norm_mode is distinct from 'ir'
        or coalesce(lower(visual_norm_metadata ->> 'ir_required'), 'false') = 'true'
      );
  end if;
end;
$$;

create index if not exists guard_ops_media_visual_norm_mode_idx
  on public.guard_ops_media (visual_norm_mode, captured_at desc);

comment on column public.guard_ops_media.visual_norm_mode is
  'Visual normalization environment mode: day, night, or ir.';

comment on column public.guard_ops_media.visual_norm_metadata is
  'Visual normalization metadata payload (baseline, profile, thresholds, IR requirement).';
