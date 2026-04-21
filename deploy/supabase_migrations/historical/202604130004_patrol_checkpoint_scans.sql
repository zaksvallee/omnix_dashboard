CREATE TABLE IF NOT EXISTS public.patrol_checkpoint_scans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  guard_id text NOT NULL,
  site_id text NOT NULL,
  client_id text NOT NULL,
  checkpoint_id text NOT NULL,
  checkpoint_name text NOT NULL,
  scanned_at timestamptz NOT NULL DEFAULT now(),
  lat double precision,
  lon double precision,
  method text NOT NULL DEFAULT 'qr',
  valid boolean NOT NULL DEFAULT true,
  notes text
);

CREATE INDEX IF NOT EXISTS patrol_checkpoint_scans_site_guard_scanned_idx
  ON public.patrol_checkpoint_scans(site_id, guard_id, scanned_at DESC);

CREATE INDEX IF NOT EXISTS patrol_checkpoint_scans_site_checkpoint_idx
  ON public.patrol_checkpoint_scans(site_id, checkpoint_id, scanned_at DESC);

ALTER TABLE public.patrol_checkpoint_scans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS patrol_checkpoint_scans_service_all
  ON public.patrol_checkpoint_scans;
CREATE POLICY patrol_checkpoint_scans_service_all
  ON public.patrol_checkpoint_scans
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS patrol_checkpoint_scans_authenticated_read
  ON public.patrol_checkpoint_scans;
CREATE POLICY patrol_checkpoint_scans_authenticated_read
  ON public.patrol_checkpoint_scans
  FOR SELECT
  TO authenticated
  USING (
    site_id = COALESCE(auth.jwt() ->> 'site_id', '')
    OR site_id = ANY(
      COALESCE(
        string_to_array(NULLIF(auth.jwt() ->> 'site_ids', ''), ','),
        ARRAY[]::text[]
      )
    )
  );
