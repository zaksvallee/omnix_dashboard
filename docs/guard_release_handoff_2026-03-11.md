# ONYX Guard Release Handoff (2026-03-11)

## Release Scope
- Live telemetry pilot validation completed for both native provider families.
- Supabase remote migration parity restored and readiness smoke checks executed.
- Actor-context contract validated against recent canonical guard events.

## Included Commits
- `9bcecba` Pass pilot-gate config through to readiness check.
- `7f41e27` Document March 11 pilot and remote readiness validations.
- `3c840a8` Add March 11 guard validation signoff record.

## Verification Summary
- Android pilot gate (`fsk_sdk`) with real-device artifacts and full tests: PASS.
- Android pilot gate (`hikvision_sdk`) with real-device artifacts and full tests: PASS.
- Supabase migration parity: local and remote aligned through `202603090001`.
- Remote readiness checks:
  - `guard_storage_readiness_checks`: all PASS.
  - `guard_rls_readiness_checks`: all PASS.
  - Retention dry-run RPC checks completed; replay safety returned true.
- Actor contract checks on latest rows: PASS (`recent_rows=3`, all missing-key counts = 0).

## Release Gate Status
- Zero critical runtime errors on Android pilot devices: READY (validated in pilot gates).
- Offline queue replay without duplicates: READY (guard reliability + full suite passed).
- RLS/auth scopes for guard-only access: READY (remote readiness checks PASS).
- Replay/export artifacts sufficient for audit: READY (validation + signoff docs present).

## Evidence
- [guard_validation_signoff_2026-03-11.md](/Users/zaks/omnix_dashboard/docs/guard_validation_signoff_2026-03-11.md)
- [guard_app_deployment_status_checklist.md](/Users/zaks/omnix_dashboard/docs/guard_app_deployment_status_checklist.md)

## Suggested Release Message
```
ONYX Guard pilot release validation is complete (2026-03-11).

Validated:
- fsk_sdk and hikvision_sdk real-device pilot gates (full tests) PASS
- Supabase migrations synced through 202603090001
- guard_storage_readiness_checks + guard_rls_readiness_checks all PASS
- Actor-context contract check PASS on recent guard_ops_events rows

Key commits:
- 9bcecba
- 7f41e27
- 3c840a8

System is ready for controlled pilot rollout and site-by-site runbook execution.
```

## Operational Next Steps
1. Push `master` and open/update release PR with the three commits above.
2. Roll out approved provider config by site (`fsk_sdk` or `hikvision_sdk`).
3. Execute site pilot runbook per site:
   `shift start -> checkpoint/image -> panic -> sync/replay closeout`.
4. Monitor first 24 hours:
   payload health, failed-op KPIs, replay/export audit sufficiency, actor-contract drift.
