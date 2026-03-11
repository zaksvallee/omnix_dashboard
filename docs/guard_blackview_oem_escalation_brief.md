# ONYX OEM Escalation Brief (Blackview BV5300 Pro)

Last updated: 2026-03-11 (Africa/Johannesburg)

## Issue Summary

- Device: Blackview BV5300 Pro
- ONYX package: `com.example.omnix_dashboard`
- Side key emits `KEY_F1` (`/dev/input/event0`) at Linux input layer.
- ONYX captures side key successfully while unlocked (PTT down/up ingest logs present).
- While lockscreen is active (`mWakefulness=Dozing`), no app-visible key/broadcast callback is delivered to ONYX.

## Reproduction

1. Enable ONYX accessibility bridge (`ONYX PTT Key Bridge`).
2. With device unlocked, press side key:
   - ONYX logs `ptt_key_bridge_accepted` and `ptt_ingest_accepted`.
3. Lock device and press side key:
   - side-key action occurs physically,
   - no ONYX PTT ingest logs appear.

## Expected Behavior

- Side key should be routable while locked to an app-visible callback path (broadcast or key callback) for mission-critical PTT workflows.

## Requested OEM Support

Provide one of the following for lockscreen operation:

1. Firmware setting to allow side key events while locked for whitelisted apps.
2. System broadcast intent emitted on key down/up while locked.
3. Documented system API/callback for privileged or partner integration.
4. Existing vendor setting key names and accepted values to enable lockscreen key routing.

## Attached Evidence

Generate and attach bundle:

```bash
./scripts/guard_android_oem_escalation_bundle.sh --serial <device-serial> --duration 15
```

Include:

- `summary.md`
- `unlocked/logcat_ptt_matches.txt`
- `locked/logcat_ptt_matches.txt`
- `unlocked/getevent_key_matches.txt`
- `locked/getevent_key_matches.txt`
- `dumpsys_accessibility.txt`
- `dumpsys_power.txt`
- `settings_*_focus.txt`

## Current Workaround

- Keep device unlocked/kiosk mode during operation, or
- Use OEM-provided key mapping route that emits lockscreen-safe PTT broadcasts.

## Latest Field Evidence (2026-03-11 19:24 SAST)

Bundle:

- `tmp/guard_field_validation/oem-escalation-20260311T172358Z`

Accessibility preflight:

- `enabled_accessibility_services` includes `com.example.omnix_dashboard/com.example.omnix_dashboard.telemetry.OnyxPttAccessibilityService`
- `accessibility_enabled=1`

Measured counts (20s per phase):

- Unlocked logcat PTT lines: `324`
- Locked logcat PTT lines: `12`
- Unlocked key-event lines: `324`
- Locked key-event lines: `316`
- Unlocked ingest accepted: `162`
- Locked ingest accepted: `6`
- Unlocked ingest lock-state: `locked=true:0` / `locked=false:162`
- Locked ingest lock-state: `locked=true:0` / `locked=false:6`

Interpretation:

- Side-key input (`KEY_F1`) continues at kernel/input layer while locked.
- App-layer ingest drops from `162` to `6` when locked.
- The few locked-phase ingest lines still report `locked=false interactive=true`, indicating they were captured near lock transition rather than true keyguard-delivered locked events.

Conclusion:

- Hardware key path is functional.
- App-visible delivery while keyguard is active is restricted by OEM/lockscreen policy.

## Fast Talkie Fallback Check (2026-03-11 20:05 SAST)

Observed on same device/build:

- ONYX ingest accepts Fast Talkie style broadcasts (`android.intent.action.PTT.down/up`)
  when broadcast is sent directly (including locked runtime context).
- With physical side-button presses while unlocked, ONYX logs continue via accessibility
  bridge (`ptt_key_bridge_accepted`, `ptt_ingest_accepted`).
- With physical side-button presses while locked, no ONYX logs and no Fast Talkie-style
  PTT broadcast traces are emitted.

Interpretation:

- Broadcast ingest path is valid.
- Hardware-to-app routing under keyguard is blocked before third-party bridge apps
  (including Fast Talkie style routing) can emit app-visible PTT intents.

## Latest Gate Run (2026-03-11 23:45 SAST)

Bundle:

- `tmp/guard_field_validation/oem-escalation-20260311T214424Z`

Gate report:

- `tmp/guard_field_validation/oem-escalation-20260311T214424Z/lockscreen_gate_report.md`
- Decision: `UNLOCKED_ONLY`
- Reason: `No confirmed lockscreen ingest evidence.`

Measured counts (20s per phase):

- Unlocked ingest accepted: `125`
- Locked ingest accepted: `6`
- Locked ingest with `locked=true`: `0`
- Locked ingest with `interactive=false`: `0`

Interpretation:

- Accessibility bridge remains healthy while unlocked.
- Locked-phase ingest still lacks true lockscreen-delivered evidence.
- Operational mode remains `unlocked/kiosk` until OEM keyguard routing support lands.
