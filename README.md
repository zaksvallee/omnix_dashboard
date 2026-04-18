# ONYX Dashboard

Flutter command-and-control surface for ONYX dispatch, guard sync, client comms, ledger, and reporting.

## Core Commands

### Local config setup (first run)

```bash
cp config/onyx.local.example.json config/onyx.local.json
```

### Local web run (with ONYX config)

```bash
flutter run -d chrome --dart-define-from-file=config/onyx.local.json
```

### Live Telegram quick-action smoke

```bash
./scripts/run_onyx_chrome_local.sh --log-file tmp/telegram_quick_action_live.log -- --web-port 63123
python3 scripts/watch_onyx_quick_actions.py --log-file tmp/telegram_quick_action_live.log
```

Or use the one-command wrapper:

```bash
./scripts/telegram_quick_action_live_smoke.sh
```

Optional raw Telegram queue watcher:

```bash
python3 scripts/watch_telegram_updates.py --config config/onyx.local.json
```

Note:
- run the raw Telegram watcher only when you specifically need queue visibility; it can conflict with ONYX's live poller and produce `HTTP 409: Conflict`

Runbook:
- [Telegram quick-action live smoke](/Users/zaks/omnix_dashboard/docs/telegram_quick_action_live_smoke.md)

### Standard quality gate

```bash
flutter analyze
flutter test
```

### Fast UI compact smoke

```bash
make smoke-ui
```

### Unified ONYX ops preflight (recommended)

Runs analyze + tests + guard gate in one command.

```bash
./scripts/onyx_ops_preflight.sh
```

Or:

```bash
make preflight
```

Fast preflight during active UI iteration:

```bash
make preflight-smoke
```

## Guard Validation Gates

### Auto gate (recommended)

Uses on-device gate if Android is connected, otherwise pre-device mock gate.

```bash
./scripts/guard_gate_auto.sh
```

Or:

```bash
make guard-auto
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
- UI action telemetry runbook: `docs/ui_action_telemetry_runbook.md`
- PTT lockscreen capability gate: `scripts/guard_android_ptt_lockscreen_gate.sh`
- Supabase remote smoke helper: `scripts/guard_supabase_remote_smoke.sh`
- UI compact QC signoff: `docs/ui_compact_qc_signoff_2026-03-06.md`
# omnix_dashboard
# omnix_dashboard
# omnix_dashboard
# onyx-dashboard
