-- Layer 1 Step 4a — CHECK constraints (clean enum-like columns).
--
-- What: add CHECK (<col> IN (<canonical values>)) on 11 enum-like columns
--       where live data already contains only canonical values (allowing
--       NULL where already present). Each was validated via GROUP BY probe
--       (see audit §1 probes P4.*).
--
-- Phase 4 finding: §4 flagged value inconsistencies. This migration covers
--       only columns with no inconsistency today.
--
-- 4a rationale: CHECK constraints that reject no existing rows. Where a
--       column has NULL rows today, the CHECK explicitly allows NULL via
--       `IS NULL OR col IN (...)` form so the constraint doesn't reject them.
--
-- Not here (moved to 4b): incidents.status (mixed case `open`/`OPEN`),
--       incidents.priority (4 vocabularies), incidents.risk_level,
--       guards.grade (format inconsistency), onyx_evidence_certificates
--       with duplicate event_ids. See Step 4b #03.

BEGIN;

-- incidents.action_code — 4 canonical values + 69 NULL rows (P4.7)
ALTER TABLE public.incidents
  ADD CONSTRAINT incidents_action_code_valid
  CHECK (action_code IS NULL OR action_code IN ('CRITICAL_ALERT', 'MONITOR', 'ESCALATE', 'LOG_ONLY'));

-- incidents.category — 5 canonical values + 27 NULL rows (P4.8)
ALTER TABLE public.incidents
  ADD CONSTRAINT incidents_category_valid
  CHECK (category IS NULL OR category IN ('Unknown', 'Robbery', 'Hijacking', 'General Incident', 'Public Unrest'));

-- incidents.source — 4 canonical values + 3 NULL rows (P4.5)
ALTER TABLE public.incidents
  ADD CONSTRAINT incidents_source_valid
  CHECK (source IS NULL OR source IN ('manual', 'news', 'social', 'ops'));

-- incidents.incident_type — 3 values, no NULL (P4.6)
ALTER TABLE public.incidents
  ADD CONSTRAINT incidents_incident_type_valid
  CHECK (incident_type IN ('technical_failure', 'breach', 'panic'));

-- site_alarm_events.event_type — 3 values, no NULL (P4.11)
ALTER TABLE public.site_alarm_events
  ADD CONSTRAINT site_alarm_events_event_type_valid
  CHECK (event_type IN ('camera_worker_offline', 'false_alarm_cleared', 'armed_response_requested'));

-- client_conversation_messages.author — 2 values (P4.14)
ALTER TABLE public.client_conversation_messages
  ADD CONSTRAINT client_conversation_messages_author_valid
  CHECK (author IN ('Client', 'Control'));

-- client_conversation_messages.viewer_role — 2 values (P4.15)
ALTER TABLE public.client_conversation_messages
  ADD CONSTRAINT client_conversation_messages_viewer_role_valid
  CHECK (viewer_role IN ('client', 'control'));

-- onyx_evidence_certificates.issuer — single value (P4.16); lock it
ALTER TABLE public.onyx_evidence_certificates
  ADD CONSTRAINT onyx_evidence_certificates_issuer_valid
  CHECK (issuer = 'ONYX Risk and Intelligence Group');

-- onyx_evidence_certificates.version — single value (P4.17); lock it
ALTER TABLE public.onyx_evidence_certificates
  ADD CONSTRAINT onyx_evidence_certificates_version_valid
  CHECK (version = '1.0');

-- onyx_power_mode_events.mode — 3 values (P4.19)
ALTER TABLE public.onyx_power_mode_events
  ADD CONSTRAINT onyx_power_mode_events_mode_valid
  CHECK (mode IN ('threat', 'normal', 'degraded'));

-- site_camera_zones.zone_type — 3 values (P4.20)
ALTER TABLE public.site_camera_zones
  ADD CONSTRAINT site_camera_zones_zone_type_valid
  CHECK (zone_type IN ('perimeter', 'semi_perimeter', 'indoor'));

COMMIT;
