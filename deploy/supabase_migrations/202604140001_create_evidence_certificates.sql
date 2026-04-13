CREATE TABLE IF NOT EXISTS public.onyx_evidence_certificates (
  certificate_id uuid PRIMARY KEY,
  event_id text NOT NULL,
  incident_id text,
  site_id text NOT NULL,
  client_id text NOT NULL,
  camera_id text NOT NULL,
  detected_at timestamptz NOT NULL,
  issued_at timestamptz NOT NULL DEFAULT now(),
  snapshot_hash text,
  event_hash text NOT NULL,
  chain_position bigint NOT NULL,
  previous_certificate_hash text NOT NULL DEFAULT 'GENESIS',
  certificate_hash text NOT NULL,
  confidence double precision,
  face_match_id text,
  zone_id text,
  issuer text NOT NULL,
  version text NOT NULL,
  valid boolean NOT NULL DEFAULT true,
  event_data jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE UNIQUE INDEX IF NOT EXISTS onyx_evidence_certificates_site_chain_idx
  ON public.onyx_evidence_certificates(site_id, chain_position);

CREATE INDEX IF NOT EXISTS onyx_evidence_certificates_event_idx
  ON public.onyx_evidence_certificates(event_id);

CREATE INDEX IF NOT EXISTS onyx_evidence_certificates_detected_idx
  ON public.onyx_evidence_certificates(site_id, detected_at DESC);

ALTER TABLE public.onyx_evidence_certificates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS onyx_evidence_certificates_service_all
  ON public.onyx_evidence_certificates;
CREATE POLICY onyx_evidence_certificates_service_all
  ON public.onyx_evidence_certificates
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS onyx_evidence_certificates_authenticated_read
  ON public.onyx_evidence_certificates;
CREATE POLICY onyx_evidence_certificates_authenticated_read
  ON public.onyx_evidence_certificates
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
