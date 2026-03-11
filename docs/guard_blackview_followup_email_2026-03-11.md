# Blackview Follow-up Email Draft (2026-03-11 23:45 SAST)

Subject: Follow-up: BV5300 Pro lockscreen side-key routing still blocked (new evidence attached)

Hello Blackview Support Team,

Following up on our BV5300 Pro side-key routing issue for mission-critical PTT workflows.

We reran controlled captures on 2026-03-11 with ONYX Guard (`com.example.omnix_dashboard`) and attached fresh evidence:

- `tmp/guard_field_validation/oem-escalation-20260311T214424Z`
- `tmp/guard_field_validation/oem-escalation-20260311T214424Z/lockscreen_gate_report.md`

Latest result:

- Decision: `UNLOCKED_ONLY`
- Reason: `No confirmed lockscreen ingest evidence`

Key metrics (20s per phase):

- Unlocked key events: 347
- Locked key events: 300
- Unlocked ingest accepted: 125
- Locked ingest accepted: 6
- Locked ingest with `locked=true`: 0
- Locked ingest with `interactive=false`: 0

Interpretation:

- Hardware side key still fires at Linux input layer while locked.
- App-visible callbacks are not delivered under keyguard/lockscreen.
- Remaining locked-phase ingest lines are transition-window events, not true lockscreen delivery.

Request:

Please provide one of the following for BV5300 Pro firmware:

1. A lockscreen-safe setting to allow side-key delivery to whitelisted apps.
2. A documented broadcast intent for side-key down/up while locked.
3. A documented system API/callback path for partner integrations to receive side-key events while locked.

If this is available through hidden/system settings, please share exact key names and accepted values.

Thanks,
ONYX Engineering
