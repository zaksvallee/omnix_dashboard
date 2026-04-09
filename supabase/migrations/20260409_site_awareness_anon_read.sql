-- Allow the anon key (Flutter Web) to read site awareness snapshots.
-- The data contains operational status (detection counts, perimeter state)
-- which is safe for authenticated dashboard sessions. Writes remain
-- service-role only (camera worker runs natively, never in the browser).

drop policy if exists "anon_can_read_site_awareness"
  on public.site_awareness_snapshots;

create policy "anon_can_read_site_awareness"
  on public.site_awareness_snapshots
  for select
  to anon
  using (true);
