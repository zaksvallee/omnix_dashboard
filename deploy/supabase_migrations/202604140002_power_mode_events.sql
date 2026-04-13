CREATE TABLE IF NOT EXISTS public.onyx_power_mode_events (
  site_id text NOT NULL,
  mode text NOT NULL,
  reason text NOT NULL,
  occurred_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS onyx_power_mode_events_site_occurred_idx
  ON public.onyx_power_mode_events(site_id, occurred_at DESC);

ALTER TABLE public.onyx_power_mode_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS onyx_power_mode_events_service_all
  ON public.onyx_power_mode_events;
CREATE POLICY onyx_power_mode_events_service_all
  ON public.onyx_power_mode_events
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS onyx_power_mode_events_authenticated_read
  ON public.onyx_power_mode_events;
CREATE POLICY onyx_power_mode_events_authenticated_read
  ON public.onyx_power_mode_events
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
