# Blackview Support Ticket Draft (BV5300 Pro)

Date: 2026-03-11  
Product: Blackview BV5300 Pro  
Android app: ONYX Guard (`com.example.omnix_dashboard`)

## Subject

Lockscreen consumes side key (`KEY_F1`) before app-level callbacks; request OEM lockscreen key-routing support for PTT workflows.

## Description

We are integrating a mission-critical push-to-talk workflow on Blackview BV5300 Pro devices.

Observed behavior:

- Side key generates Linux input events as `KEY_F1` (`/dev/input/event0`).
- ONYX captures the side key correctly while screen is unlocked.
- When lockscreen is active, raw `KEY_F1` events still occur at input layer, but app-level callbacks/broadcast delivery stop.

Impact:

- PTT ingest is not reliable while locked, which blocks guard-operations usage in real field conditions.

## Reproduction Summary

1. Enable ONYX accessibility key bridge (`ONYX PTT Key Bridge`).
2. Unlocked: press side key repeatedly.
   - ONYX logs `ptt_key_bridge_accepted` + `ptt_ingest_accepted`.
3. Locked: press side key repeatedly.
   - `getevent` still shows `KEY_F1` events.
   - ONYX ingest logs do not continue after lockscreen path takes over.

## Evidence

Attached bundle:

- `tmp/guard_field_validation/oem-escalation-20260311T155619Z.tar.gz`

Bundle highlights:

- Unlocked phase logcat PTT lines: `292`
- Locked phase logcat PTT lines: `12` (only at phase start)
- Unlocked key-event lines: `216`
- Locked key-event lines: `220`

Timing evidence:

- Locked phase ONYX logs stop at `17:56:35.651`.
- Locked phase raw key events continue until at least `73567.564082` in `getevent`.

## Request

Please provide one of the following for BV5300 Pro firmware:

1. A setting that allows side-key delivery to whitelisted app handlers while locked.
2. A documented lockscreen-safe broadcast intent for side-key down/up.
3. A documented system API/callback path for partner integrations to receive side-key events while locked.

If settings keys/values already exist, please share exact names and accepted values.

## Contact

Engineering team can provide additional logs, test APK, and live debug session if needed.
