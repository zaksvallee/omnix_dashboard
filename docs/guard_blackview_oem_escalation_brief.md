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
