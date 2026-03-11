# Blackview Vendor Chat Brief (2026-03-11)

Copy/paste message:

BV5300 Pro lockscreen PTT issue persists.

On ONYX Guard (`com.example.omnix_dashboard`), side key `KEY_F1` is visible at input layer while locked, but app callbacks are blocked by keyguard.

Latest evidence bundle: `tmp/guard_field_validation/oem-escalation-20260311T214424Z`
Gate report: `.../lockscreen_gate_report.md`
Decision: `UNLOCKED_ONLY` (no confirmed lockscreen ingest evidence).

Metrics (20s phase): unlocked ingest 125, locked ingest 6, locked `locked=true` = 0, locked `interactive=false` = 0.

Request: please provide a firmware setting or documented API/broadcast path to deliver side-key down/up to whitelisted apps while screen is locked.

---

1-line fallback summary:

BV5300 Pro still blocks lockscreen side-key delivery to whitelisted apps; hardware key events exist, app callbacks do not.
