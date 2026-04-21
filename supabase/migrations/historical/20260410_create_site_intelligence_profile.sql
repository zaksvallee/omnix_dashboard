CREATE TABLE IF NOT EXISTS public.site_intelligence_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id text NOT NULL UNIQUE,
  industry_type text NOT NULL DEFAULT 'residential',
  operating_hours_start time DEFAULT '08:00',
  operating_hours_end time DEFAULT '18:00',
  operating_days text[] DEFAULT '{"monday","tuesday","wednesday","thursday","friday"}',
  timezone text DEFAULT 'Africa/Johannesburg',
  is_24h_operation boolean DEFAULT false,
  expected_staff_count int DEFAULT 0,
  expected_resident_count int DEFAULT 0,
  expected_vehicle_count int DEFAULT 0,
  has_guard boolean DEFAULT false,
  has_armed_response boolean DEFAULT false,
  after_hours_sensitivity text DEFAULT 'high',
  during_hours_sensitivity text DEFAULT 'medium',
  monitor_staff_activity boolean DEFAULT false,
  inactive_staff_alert_minutes int DEFAULT 30,
  monitor_till_attendance boolean DEFAULT false,
  till_unattended_minutes int DEFAULT 5,
  monitor_restricted_zones boolean DEFAULT false,
  monitor_vehicle_movement boolean DEFAULT true,
  after_hours_vehicle_alert boolean DEFAULT true,
  send_shift_start_briefing boolean DEFAULT true,
  send_shift_end_report boolean DEFAULT true,
  send_daily_summary boolean DEFAULT true,
  daily_summary_time time DEFAULT '07:00',
  custom_rules jsonb DEFAULT '[]'
);

CREATE TABLE IF NOT EXISTS public.site_zone_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id text NOT NULL,
  zone_name text NOT NULL,
  zone_type text NOT NULL,
  allowed_roles text[] DEFAULT '{}',
  access_hours_start time,
  access_hours_end time,
  access_days text[] DEFAULT '{}',
  violation_action text DEFAULT 'alert',
  max_dwell_minutes int,
  requires_escort boolean DEFAULT false,
  is_restricted boolean DEFAULT false
);

CREATE INDEX IF NOT EXISTS site_intelligence_profiles_site_idx
  ON public.site_intelligence_profiles(site_id);

CREATE INDEX IF NOT EXISTS site_zone_rules_site_zone_idx
  ON public.site_zone_rules(site_id, zone_name, zone_type);

ALTER TABLE public.site_intelligence_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.site_zone_rules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS site_intelligence_profiles_service_all
  ON public.site_intelligence_profiles;
CREATE POLICY site_intelligence_profiles_service_all
  ON public.site_intelligence_profiles
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS site_intelligence_profiles_anon_read
  ON public.site_intelligence_profiles;
CREATE POLICY site_intelligence_profiles_anon_read
  ON public.site_intelligence_profiles
  FOR SELECT
  TO anon
  USING (true);

DROP POLICY IF EXISTS site_intelligence_profiles_authenticated_read
  ON public.site_intelligence_profiles;
CREATE POLICY site_intelligence_profiles_authenticated_read
  ON public.site_intelligence_profiles
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

DROP POLICY IF EXISTS site_zone_rules_service_all ON public.site_zone_rules;
CREATE POLICY site_zone_rules_service_all
  ON public.site_zone_rules
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS site_zone_rules_anon_read ON public.site_zone_rules;
CREATE POLICY site_zone_rules_anon_read
  ON public.site_zone_rules
  FOR SELECT
  TO anon
  USING (true);

DROP POLICY IF EXISTS site_zone_rules_authenticated_read
  ON public.site_zone_rules;
CREATE POLICY site_zone_rules_authenticated_read
  ON public.site_zone_rules
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

INSERT INTO public.site_intelligence_profiles (
  site_id,
  industry_type,
  operating_hours_start,
  operating_hours_end,
  has_guard,
  monitor_staff_activity,
  send_shift_start_briefing,
  send_daily_summary
) VALUES (
  'SITE-MS-VALLEE-RESIDENCE',
  'residential',
  '06:00',
  '22:00',
  false,
  false,
  true,
  true
)
ON CONFLICT (site_id) DO UPDATE
SET industry_type = 'residential';
