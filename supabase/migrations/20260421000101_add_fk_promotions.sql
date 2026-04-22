-- Layer 1 Step 4a — FK promotions (clean relationships only).
--
-- What: promote 14 soft-FK columns to hard FK CONSTRAINTs where live-data orphan
--       count is zero. Every FK below was validated against live via SQL orphan
--       probe (see audit/layer_1_step_4_constraint_additions.md §1).
--
-- Phase 4 finding: §6 flagged 172 soft-FK columns; §1.4 enumerated orphans per
--       child table. This migration covers the 14 soft-FKs with 0 orphans.
--
-- 4a rationale: every row below passed `SELECT count(*) FILTER (WHERE <col> IS
--       NOT NULL AND <col> NOT IN (SELECT <pk> FROM <parent>)) = 0`. No
--       violators — FK will apply cleanly. ON DELETE semantics intentionally
--       conservative: RESTRICT on directory references (sites/clients) so that
--       accidental parent deletion surfaces as an error rather than a cascade.
--
-- Not here (moved to 4b): incidents.site_id (238 null rows — see Step 4b #01),
--       onyx_evidence_certificates.incident_id (282 null rows — see Step 4b #01),
--       client_evidence_ledger.*, client_conversation_*.client_id,
--       guard_ops_events.guard_id, incident_aar_scores.incident_id (all have
--       live-data violators per §1 classification table).

BEGIN;

-- incidents → clients (0 orphans, 0 nulls per Phase A probe #10)
ALTER TABLE public.incidents
  ADD CONSTRAINT incidents_client_id_fkey
  FOREIGN KEY (client_id) REFERENCES public.clients (client_id) ON DELETE RESTRICT;

-- site_alarm_events → sites (0 orphans per Phase A probe #11; 11,227 rows)
ALTER TABLE public.site_alarm_events
  ADD CONSTRAINT site_alarm_events_site_id_fkey
  FOREIGN KEY (site_id) REFERENCES public.sites (site_id) ON DELETE RESTRICT;

-- onyx_evidence_certificates → sites / clients (0 orphans per probes #12, #13)
ALTER TABLE public.onyx_evidence_certificates
  ADD CONSTRAINT onyx_evidence_certificates_site_id_fkey
  FOREIGN KEY (site_id) REFERENCES public.sites (site_id) ON DELETE RESTRICT;
ALTER TABLE public.onyx_evidence_certificates
  ADD CONSTRAINT onyx_evidence_certificates_client_id_fkey
  FOREIGN KEY (client_id) REFERENCES public.clients (client_id) ON DELETE RESTRICT;

-- fr_person_registry → sites (0 orphans per probe #15)
ALTER TABLE public.fr_person_registry
  ADD CONSTRAINT fr_person_registry_site_id_fkey
  FOREIGN KEY (site_id) REFERENCES public.sites (site_id) ON DELETE RESTRICT;

-- site_camera_zones → sites (0 orphans per probe #16)
ALTER TABLE public.site_camera_zones
  ADD CONSTRAINT site_camera_zones_site_id_fkey
  FOREIGN KEY (site_id) REFERENCES public.sites (site_id) ON DELETE RESTRICT;

-- site_occupancy_config → sites (0 orphans per probe #17)
ALTER TABLE public.site_occupancy_config
  ADD CONSTRAINT site_occupancy_config_site_id_fkey
  FOREIGN KEY (site_id) REFERENCES public.sites (site_id) ON DELETE RESTRICT;

-- site_occupancy_sessions → sites (0 orphans per probe #18)
ALTER TABLE public.site_occupancy_sessions
  ADD CONSTRAINT site_occupancy_sessions_site_id_fkey
  FOREIGN KEY (site_id) REFERENCES public.sites (site_id) ON DELETE RESTRICT;

-- site_alert_config → sites (0 orphans per probe #19)
ALTER TABLE public.site_alert_config
  ADD CONSTRAINT site_alert_config_site_id_fkey
  FOREIGN KEY (site_id) REFERENCES public.sites (site_id) ON DELETE RESTRICT;

-- site_api_tokens → sites (0 orphans per probe #20)
ALTER TABLE public.site_api_tokens
  ADD CONSTRAINT site_api_tokens_site_id_fkey
  FOREIGN KEY (site_id) REFERENCES public.sites (site_id) ON DELETE RESTRICT;

-- site_intelligence_profiles → sites (0 orphans per probe #21)
ALTER TABLE public.site_intelligence_profiles
  ADD CONSTRAINT site_intelligence_profiles_site_id_fkey
  FOREIGN KEY (site_id) REFERENCES public.sites (site_id) ON DELETE RESTRICT;

-- site_expected_visitors → sites (0 orphans per probe #22)
ALTER TABLE public.site_expected_visitors
  ADD CONSTRAINT site_expected_visitors_site_id_fkey
  FOREIGN KEY (site_id) REFERENCES public.sites (site_id) ON DELETE RESTRICT;

-- onyx_power_mode_events → sites (0 orphans per probe #23)
ALTER TABLE public.onyx_power_mode_events
  ADD CONSTRAINT onyx_power_mode_events_site_id_fkey
  FOREIGN KEY (site_id) REFERENCES public.sites (site_id) ON DELETE RESTRICT;

-- site_vehicle_registry → sites (0 orphans per probe #24)
ALTER TABLE public.site_vehicle_registry
  ADD CONSTRAINT site_vehicle_registry_site_id_fkey
  FOREIGN KEY (site_id) REFERENCES public.sites (site_id) ON DELETE RESTRICT;

COMMIT;
