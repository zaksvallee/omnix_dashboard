# ONYX UI Compact QC Signoff (2026-03-06)

## Validation Baseline

- `flutter test`: PASS
- `flutter analyze`: PASS
- `flutter run -d chrome --dart-define-from-file=config/onyx.local.json`: PASS (startup/runtime stable, Supabase init OK)
- `./scripts/guard_pilot_gate_report.sh -- --enforce-live-telemetry --require-supabase-config`: PASS

## Route Signoff

- [x] `Dashboard` compact layout + reduced right-rail clutter
- [x] `Dispatches` compact workspace spacing and grouped scan flow
- [x] `Events` forensic layout density tightened
- [x] `Sites` roster/detail workspace compacted
- [x] `Guards` roster/detail workspace compacted
- [x] `Ledger` timeline density + panel sizing compacted
- [x] `Reports` command hub spacing compacted
- [x] `Clients` surface constrained + compact rhythm applied
- [x] `Guard Mobile Shell` constrained + compact rhythm applied

## Shared Design Primitive Signoff

- [x] `lib/ui/onyx_surface.dart` compact defaults for header/stats/padding
- [x] `lib/ui/app_shell.dart` compact sidebar card spacing

## Known Non-Blocking Notes

- Dependency update notices (pub outdated) remain informational only.
- Local working tree includes unrelated Android/config/docs artifacts not part of this signoff.

## Next Execution Block (Pre-Device)

- [ ] Verify all route interactions manually in Chrome once more after any next functional feature merge.
- [ ] Keep strict gate as pre-merge check for guard sync changes.
- [ ] Prepare phone-day run order:
  1. Android connect + telemetry bridge doctor
  2. guard pilot gate script
  3. live shift workflow rehearsal (shift start/checkpoint/panic/sync)
  4. artifact capture and checklist closeout
