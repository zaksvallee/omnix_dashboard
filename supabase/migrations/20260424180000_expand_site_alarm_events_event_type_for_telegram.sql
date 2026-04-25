-- Workstream 1 Phase B — expand site_alarm_events.event_type CHECK to allow
-- the four telegram_* audit values the `_recordAlertActionEvent` helper
-- (bin/onyx_telegram_ai_processor.dart:1078) emits from the Telegram action
-- button handlers.
--
-- Why: migration 20260421000103 locked event_type to the three values that
-- live data carried at baseline capture
-- ('camera_worker_offline', 'false_alarm_cleared', 'armed_response_requested').
-- Since before Layer 2 cutover, `_recordAlertActionEvent` has been writing
-- four additional event_type values:
--   * telegram_view_camera
--   * telegram_dispatch_requested
--   * telegram_acknowledged
--   * telegram_false_alarm
-- All four were silently rejected by the CHECK constraint. Phase B Phase A
-- investigation (audit/workstream_1_phase_b_phase_a_proposal_2026-04-24.md
-- §site_alarm_events) identified this as a latent bug and the last blocker
-- for Workstream 1 Phase B. Operator locked the migrate path as the
-- resolution.
--
-- Side effect: this migration also closes the latent audit-log bug on the
-- View camera button handler (`_handleViewCallback`). That handler's
-- callback delivery and snapshot reply have been working, but its
-- site_alarm_events audit row has been failing silently alongside the
-- three write-path buttons.
--
-- Discipline: additive-only. DROP + re-ADD on the same constraint is the
-- canonical PostgreSQL pattern for expanding a CHECK's allowed set.

BEGIN;

ALTER TABLE public.site_alarm_events
  DROP CONSTRAINT site_alarm_events_event_type_valid;

ALTER TABLE public.site_alarm_events
  ADD CONSTRAINT site_alarm_events_event_type_valid
  CHECK (event_type IN (
    'camera_worker_offline',
    'false_alarm_cleared',
    'armed_response_requested',
    'telegram_view_camera',
    'telegram_dispatch_requested',
    'telegram_acknowledged',
    'telegram_false_alarm'
  ));

COMMIT;
