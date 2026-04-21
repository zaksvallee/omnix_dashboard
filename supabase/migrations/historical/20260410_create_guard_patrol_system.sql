CREATE TABLE IF NOT EXISTS public.patrol_routes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id text NOT NULL,
  route_name text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.patrol_checkpoints (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  route_id uuid REFERENCES public.patrol_routes(id),
  site_id text NOT NULL,
  checkpoint_name text NOT NULL,
  checkpoint_code text NOT NULL UNIQUE,
  sequence_order int NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.guard_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id text NOT NULL,
  guard_id text NOT NULL,
  guard_name text NOT NULL,
  route_id uuid REFERENCES public.patrol_routes(id),
  shift_start time NOT NULL,
  shift_end time NOT NULL,
  patrol_interval_minutes int NOT NULL DEFAULT 60,
  is_active boolean NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS public.patrol_scans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id text NOT NULL,
  guard_id text NOT NULL,
  checkpoint_id uuid REFERENCES public.patrol_checkpoints(id),
  checkpoint_name text NOT NULL,
  scanned_at timestamptz NOT NULL DEFAULT now(),
  lat numeric,
  lon numeric,
  note text
);

CREATE TABLE IF NOT EXISTS public.patrol_compliance (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id text NOT NULL,
  guard_id text NOT NULL,
  compliance_date date NOT NULL DEFAULT current_date,
  expected_patrols int NOT NULL DEFAULT 0,
  completed_patrols int NOT NULL DEFAULT 0,
  missed_checkpoints text[] DEFAULT '{}',
  compliance_percent numeric NOT NULL DEFAULT 0,
  UNIQUE(site_id, guard_id, compliance_date)
);

CREATE INDEX IF NOT EXISTS patrol_routes_site_idx
  ON public.patrol_routes(site_id);

CREATE INDEX IF NOT EXISTS patrol_checkpoints_site_route_idx
  ON public.patrol_checkpoints(site_id, route_id, sequence_order);

CREATE INDEX IF NOT EXISTS guard_assignments_site_idx
  ON public.guard_assignments(site_id, is_active);

CREATE INDEX IF NOT EXISTS patrol_scans_site_guard_scanned_idx
  ON public.patrol_scans(site_id, guard_id, scanned_at DESC);

CREATE INDEX IF NOT EXISTS patrol_compliance_site_guard_date_idx
  ON public.patrol_compliance(site_id, guard_id, compliance_date DESC);

ALTER TABLE public.patrol_routes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.patrol_checkpoints ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guard_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.patrol_scans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.patrol_compliance ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS patrol_routes_service_all ON public.patrol_routes;
CREATE POLICY patrol_routes_service_all
  ON public.patrol_routes
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS patrol_routes_authenticated_read ON public.patrol_routes;
CREATE POLICY patrol_routes_authenticated_read
  ON public.patrol_routes
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

DROP POLICY IF EXISTS patrol_checkpoints_service_all ON public.patrol_checkpoints;
CREATE POLICY patrol_checkpoints_service_all
  ON public.patrol_checkpoints
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS patrol_checkpoints_authenticated_read ON public.patrol_checkpoints;
CREATE POLICY patrol_checkpoints_authenticated_read
  ON public.patrol_checkpoints
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

DROP POLICY IF EXISTS guard_assignments_service_all ON public.guard_assignments;
CREATE POLICY guard_assignments_service_all
  ON public.guard_assignments
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS guard_assignments_authenticated_read ON public.guard_assignments;
CREATE POLICY guard_assignments_authenticated_read
  ON public.guard_assignments
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

DROP POLICY IF EXISTS patrol_scans_service_all ON public.patrol_scans;
CREATE POLICY patrol_scans_service_all
  ON public.patrol_scans
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS patrol_scans_authenticated_read ON public.patrol_scans;
CREATE POLICY patrol_scans_authenticated_read
  ON public.patrol_scans
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

DROP POLICY IF EXISTS patrol_compliance_service_all ON public.patrol_compliance;
CREATE POLICY patrol_compliance_service_all
  ON public.patrol_compliance
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS patrol_compliance_authenticated_read ON public.patrol_compliance;
CREATE POLICY patrol_compliance_authenticated_read
  ON public.patrol_compliance
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
