# ONYX Dashboard

Flutter command-and-control surface for ONYX dispatch, guard sync, client comms, ledger, and reporting.

## Core Commands

### Local web run (with ONYX config)

```bash
flutter run -d chrome --dart-define-from-file=config/onyx.local.json
```

### Standard quality gate

```bash
flutter analyze
flutter test
```

### Unified ONYX ops preflight (recommended)

Runs analyze + tests + guard gate in one command.

```bash
./scripts/onyx_ops_preflight.sh
```

## Guard Validation Gates

### Auto gate (recommended)

Uses on-device gate if Android is connected, otherwise pre-device mock gate.

```bash
./scripts/guard_gate_auto.sh
```

### Pre-device gate only

```bash
./scripts/guard_predevice_gate.sh
```

### On-device pilot gate

```bash
./scripts/guard_android_pilot_gate.sh --action com.onyx.fsk.SDK_HEARTBEAT
```

## Notes

- Operator runbook: `docs/guard_android_live_validation_runbook.md`
- UI compact QC signoff: `docs/ui_compact_qc_signoff_2026-03-06.md`
