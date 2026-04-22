-- Layer 1 Step 4a — Index additions.
--
-- What: add 10 indexes identified as missing by Step 2 §4.3 drift catalogue.
--       Indexes are always 4a (they don't care about data state; they either
--       build or fail for structural reasons, never for row validation).
--
-- Phase 4 / Step 2 finding: Step 2 §4.3 enumerated 18 indexes declared by
--       historical migration files but absent from live. This migration covers
--       the 10 still-relevant ones; 8 are skipped because their target tables
--       were renamed or never applied (see notes in Step 4 audit doc §2).
--
-- 4a rationale: indexes don't validate data — CREATE INDEX always succeeds
--       (modulo schema errors). `IF NOT EXISTS` guards re-apply safety.

BEGIN;

-- patrol_* subsystem indexes (Step 2 §4.3)
CREATE INDEX IF NOT EXISTS patrol_routes_site_idx
  ON public.patrol_routes (site_id);

CREATE INDEX IF NOT EXISTS patrol_checkpoints_site_route_idx
  ON public.patrol_checkpoints (site_id, route_id);

CREATE INDEX IF NOT EXISTS patrol_scans_site_guard_scanned_idx
  ON public.patrol_scans (site_id, guard_id, scanned_at DESC);

CREATE INDEX IF NOT EXISTS patrol_compliance_site_guard_date_idx
  ON public.patrol_compliance (site_id, guard_id, compliance_date);

-- site_intelligence subsystem (Step 2 §4.3)
CREATE INDEX IF NOT EXISTS site_intelligence_profiles_site_idx
  ON public.site_intelligence_profiles (site_id);

CREATE INDEX IF NOT EXISTS site_zone_rules_site_zone_idx
  ON public.site_zone_rules (site_id, zone_name);

-- site_expected_visitors (Step 2 §4.3)
CREATE INDEX IF NOT EXISTS site_expected_visitors_site_idx
  ON public.site_expected_visitors (site_id);

-- site_api_tokens (Step 2 §4.3)
CREATE INDEX IF NOT EXISTS site_api_tokens_site_id_idx
  ON public.site_api_tokens (site_id);

-- onyx_evidence_certificates (Step 2 §4.3 — detected_at-sorted scans)
CREATE INDEX IF NOT EXISTS onyx_evidence_certificates_detected_idx
  ON public.onyx_evidence_certificates (detected_at DESC);

-- onyx_awareness_latency (Step 2 §4.3)
CREATE INDEX IF NOT EXISTS onyx_awareness_latency_site_idx
  ON public.onyx_awareness_latency (site_id);

COMMIT;
