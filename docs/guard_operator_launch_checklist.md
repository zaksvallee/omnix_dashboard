# ONYX Guard Operator Launch Checklist

Use this checklist for pilot and production launch readiness.

Source alignment:
- [guard_app_android_deployment_blueprint_v2.md](/Users/zaks/omnix_dashboard/docs/guard_app_android_deployment_blueprint_v2.md)
- [onyx_operational_memory_engine.md](/Users/zaks/omnix_dashboard/docs/onyx_operational_memory_engine.md)

## 1. Platform Preflight (T-3 to T-1 days)

- [ ] Supabase project linked locally (`supabase link --project-ref <ref>`).
- [ ] Migrations pushed (`supabase db push`) with no errors.
- [ ] `guard_ops_events` and `guard_ops_media` tables visible in `public`.
- [ ] Storage buckets exist:
  - [ ] `guard-shift-verification`
  - [ ] `guard-patrol-images`
  - [ ] `guard-incident-media`
- [ ] RLS and storage policies enabled and validated for guard scope.
  - Owner apply script:
    [guard_storage_policies_owner.sql](/Users/zaks/omnix_dashboard/supabase/manual/guard_storage_policies_owner.sql)
  - Validation script:
    [guard_storage_policy_validation.sql](/Users/zaks/omnix_dashboard/supabase/verification/guard_storage_policy_validation.sql)
- [ ] Environment config confirmed:
  - [ ] `SUPABASE_URL`
  - [ ] `SUPABASE_ANON_KEY`
  - [ ] app config file present for run/deploy.

## 2. App Build Preflight

- [ ] `flutter analyze` passes.
- [ ] `flutter test` passes.
- [ ] Chrome smoke run passes:
  - [ ] app launches
  - [ ] no runtime crash on Guards route
  - [ ] sync controls render.

## 3. Device & Field Setup

- [ ] Guard Android devices enrolled and signed in.
- [ ] Camera permissions granted.
- [ ] Storage permissions granted (image picker flow).
- [ ] NFC availability confirmed on each device.
- [ ] Wearable pairing completed for pilot guards.
- [ ] Checkpoint mapping loaded and validated per site.

## 4. Shift Start Functional Checks

- [ ] `Shift Start` screen blocks until verification image captured.
- [ ] `SHIFT_VERIFICATION_IMAGE` event queued.
- [ ] `SHIFT_START` event queued after verification.
- [ ] Event sequence for shift begins at `1` and increments deterministically.

## 5. Patrol Functional Checks

- [ ] Checkpoint scan queues `CHECKPOINT_SCANNED`.
- [ ] Patrol image is enforced at checkpoint flow.
- [ ] `PATROL_IMAGE_CAPTURED` event queued.
- [ ] Media metadata queued with correct bucket/path/local reference.

## 6. Panic & Dispatch Checks

- [ ] Dispatch ack/status actions queue expected events.
- [ ] Panic trigger queues `PANIC_TRIGGERED`.
- [ ] Sync screen shows pending counts changing in real-time.

## 7. Offline/Recovery Drill (Mandatory)

- [ ] Put device offline (airplane mode).
- [ ] Perform:
  - [ ] shift start
  - [ ] checkpoint scan
  - [ ] patrol image
  - [ ] status update
  - [ ] panic trigger/clear
- [ ] Confirm pending counters increase while offline.
- [ ] Restore network.
- [ ] Run manual sync (`Sync Now`).
- [ ] Confirm pending counts drain to expected values.
- [ ] Confirm no duplicate event records in backend.

## 8. Sync Diagnostics & Retry

- [ ] Last successful sync timestamp appears.
- [ ] Last failure reason appears when sync fails.
- [ ] Failed event/media counts appear when applicable.
- [ ] `Retry Failed Events` works.
- [ ] `Retry Failed Media` works.
- [ ] Recent event/media sync rows update after retries.

## 9. Operational Readiness Gates

- [ ] Controller SOP issued for:
  - shift verification exceptions
  - patrol image failures
  - sync failure escalation
  - panic escalation flow
- [ ] Guard SOP issued for:
  - shift start verification
  - patrol image quality standards
  - checkpoint discipline
  - offline behavior expectations
- [ ] Incident labeling process defined (`true_threat`, `false_alarm`, etc.).

## 10. Launch-Day Acceptance Criteria

- [ ] Replayable timeline is complete for all pilot shifts.
- [ ] Event ordering is deterministic for each shift.
- [ ] Offline-to-online sync completes with no data loss.
- [ ] Duplicate rate is within tolerance (<0.1% target).
- [ ] Patrol verification compliance meets target (>95% for pilot).
- [ ] Welfare and panic escalations are visible to control room.

## 11. Post-Launch 72-Hour Watch

- [ ] Monitor sync failure frequency by site/device.
- [ ] Monitor image capture failure reasons (permissions, quality, upload).
- [ ] Monitor queue backlogs and drain times.
- [ ] Record operator feedback and top friction points.
- [ ] File and prioritize hotfixes within 24 hours where needed.

## 12. Sign-Off

- [ ] Operations Lead sign-off
- [ ] Control Room Lead sign-off
- [ ] Technical Lead sign-off
- [ ] Client Pilot Sponsor sign-off
