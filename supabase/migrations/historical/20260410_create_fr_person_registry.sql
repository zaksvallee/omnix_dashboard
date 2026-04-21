CREATE TABLE IF NOT EXISTS public.fr_person_registry (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id text NOT NULL,
  person_id text NOT NULL UNIQUE,
  display_name text NOT NULL,
  role text NOT NULL DEFAULT 'resident',
  is_private boolean NOT NULL DEFAULT true,
  expected_days text[] DEFAULT '{}',
  expected_start time,
  expected_end time,
  photo_count int NOT NULL DEFAULT 0,
  gallery_path text,
  is_enrolled boolean NOT NULL DEFAULT false,
  enrolled_at timestamptz,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.fr_person_registry ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "service_full_access_fr_registry"
ON public.fr_person_registry;

CREATE POLICY "service_full_access_fr_registry"
ON public.fr_person_registry
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);
