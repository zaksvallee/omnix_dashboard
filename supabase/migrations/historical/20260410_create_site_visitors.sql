CREATE TABLE IF NOT EXISTS public.site_expected_visitors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id text NOT NULL,
  visitor_name text NOT NULL,
  visitor_role text NOT NULL DEFAULT 'visitor',
  visit_days text[] DEFAULT '{}',
  visit_start time,
  visit_end time,
  visit_date date,
  expires_at timestamptz,
  is_active boolean DEFAULT true,
  notes text,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS site_expected_visitors_site_idx
  ON public.site_expected_visitors(site_id, is_active, created_at DESC);

ALTER TABLE public.site_expected_visitors ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS site_expected_visitors_service_all
  ON public.site_expected_visitors;
CREATE POLICY site_expected_visitors_service_all
  ON public.site_expected_visitors
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS site_expected_visitors_anon_read
  ON public.site_expected_visitors;
CREATE POLICY site_expected_visitors_anon_read
  ON public.site_expected_visitors
  FOR SELECT
  TO anon
  USING (true);

DROP POLICY IF EXISTS site_expected_visitors_authenticated_read
  ON public.site_expected_visitors;
CREATE POLICY site_expected_visitors_authenticated_read
  ON public.site_expected_visitors
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

INSERT INTO public.site_expected_visitors (
  site_id,
  visitor_name,
  visitor_role,
  visit_days,
  visit_start,
  visit_end
) VALUES (
  'SITE-MS-VALLEE-RESIDENCE',
  'Cleaner',
  'cleaner',
  '{"monday","tuesday","wednesday","thursday","friday"}',
  '08:00',
  '17:00'
)
ON CONFLICT DO NOTHING;
