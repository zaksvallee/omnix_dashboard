Layer 3 Capability Repair Plan
Date: 2026-04-23
Status: Draft after successful Layer 2 cutover
Scope owner: Phase 5 §§1-2 follow-through

Inputs

- audit/phase_2a_backend_capability_verification.md
- audit/phase_2b_dashboard_feature_verification.md
- audit/fd_leak_diagnosis.md
- audit/layer_2_cutover_ms_vallee_2026-04-23.md
- audit/phase_5_section_3_cutover_policy.md
- audit/phase_5_section_3_amendment_3.md
- audit/phase_5_section_3_amendment_4.md
- audit/phase_5_section_3_amendment_5.md

Purpose

Layer 2 reset the MS Vallee test site to a clean, policy-compliant schema and
data state. Layer 3 should not do design cleanup or product rationalisation
first. It should restore the runtime capabilities that are supposed to produce
fresh operational truth on top of that clean state.

Primary rule

Repair write paths and operator-trust surfaces before doing cleanup work that
changes preserved configuration. If a capability is not worth repairing, Layer 3
must say so explicitly and hand it to Layer 4/Layer 6 as a retirement or design
decision, rather than leaving it in a half-alive state.

Not in scope for Layer 3

- Dummy site/client cleanup and `clients_name_unique`
- `client_evidence_ledger.dispatch_id` schema redesign
- v1 Flutter decommission strategy
- broad Layer 6 RLS / tenancy / schema-shape decisions
- new product surface area

Those stay with the already-documented Layer 4 / Layer 6 deferrals.

Workstream 1 — Restore incident and dispatch truth

Why first:
- Phase 2a found `incidents` had zero new inserts in the 7-day window.
- `dispatch_transitions` was 53 days stale.
- Phase 2b showed this blocks the most visible command-center surfaces.

Repair targets:
- incident creation path from live alarm / detection input
- dispatch state-transition writes
- alert outcome writes
- any callback/action path that should move an alarm into a tracked incident or
  dispatch state

Exit criteria:
- one controlled test alert creates a fresh `incidents` row
- one operator dispatch action creates a fresh `dispatch_transitions` row
- one outcome/closure action creates the expected follow-on write
- command-center and dispatch surfaces show fresh, same-day state

Workstream 2 — Restore evidence and ledger continuity

Why second:
- Phase 2b showed `client_evidence_ledger` writes stopped on 2026-04-17.
- Ledger continuity is a high-impact trust surface and feeds multiple UIs.

Repair targets:
- `client_evidence_ledger` write path
- any coupling between alert/incident generation and ledger append
- evidence certificate generation for fresh events
- chain-integrity behavior on newly-created rows

Exit criteria:
- a fresh operational event appends new ledger rows
- hash/previous-hash continuity is preserved on the new segment
- evidence certificate generation resumes for fresh events
- `/ledger` and related evidence surfaces are no longer frozen at pre-cutover
  history

Workstream 3 — Fix the enhancement path and camera-worker runtime stability

Why third:
- Phase 2a found the Pi -> Mac enhancement handoff was misconfigured in runtime
  (`127.0.0.1` behavior instead of the intended remote enhancement path).
- The Pi camera-worker had the long disconnect/reconnect storm and FD-leak
  suspicion that later needed the nofile override.

Repair targets:
- Pi -> Mac `/detect` handoff configuration and actual POST delivery
- decision: keep the Mac enhancement tier or retire it for the test-site path
- camera-worker reconnect behavior and file-descriptor stability
- any watchdog/telemetry needed so the next failure is diagnosable quickly

Exit criteria:
- either:
  - Pi -> Mac detect POSTs are visible and intentional, or
  - the enhancement tier is explicitly removed from the path and documented
- camera-worker survives a 24h window without the prior failure pattern
- alert generation continues during that window

Workstream 4 — Guard / patrol / workforce data-path triage

Why fourth:
- Phase 2a/2b showed the guard and patrol-related tables were largely zero-row
  or dormant, which makes several workforce screens decorative rather than real.

Repair targets:
- `guard_location_heartbeats`
- `guard_assignments`
- `guard_panic_signals`
- `guard_incident_captures`
- patrol-related writes that are supposed to power the workforce surfaces

Decision rule:
- if the capability is meant to be active for MS Vallee, prove it end-to-end
- if it is not meant to be active in the current deployment, mark the surfaces
  as dormant-by-design and hand UI cleanup to Layer 4

Exit criteria:
- at least one real or controlled workforce flow produces live rows in the
  intended tables, or
- a documented de-scope decision is recorded for the test site

Workstream 5 — Zara / advanced-assist capability triage

Why fifth:
- `zara_action_log`, `zara_scenarios`, `onyx_awareness_latency`, and
  `onyx_alert_outcomes` were zero-row or dormant, which blocks advanced
  surfaces across v1 and v2.

Repair targets:
- determine whether Zara-side tables are supposed to be operational now or are
  aspirational / dormant product scaffolding
- if operational, restore one minimally-real end-to-end write path
- if not operational, record a clear defer/retire decision so Layer 4 can clean
  the UI honestly

Exit criteria:
- either fresh rows appear from a controlled flow, or a documented defer/retire
  decision exists for the affected surfaces

Suggested sequence

1. Run the post-cutover smoke checklist over 24h to confirm the preserved
   deployment is stable enough to repair on top of.
2. Workstream 1: incident + dispatch truth
3. Workstream 2: evidence + ledger continuity
4. Workstream 3: enhancement path + camera-worker stability
5. Workstream 4: guard / patrol triage
6. Workstream 5: Zara / advanced-assist triage
7. Re-run the targeted parts of phase 2a and phase 2b against the repaired
   surfaces, not the whole world

Definition of done

Layer 3 is done when:

- fresh same-day rows are flowing again through the core operational truth path:
  alarms -> incidents -> dispatch -> outcome -> ledger
- the deployment is stable enough that the operator can trust the test site for
  normal validation work
- every remaining dormant surface is either:
  - proven working, or
  - explicitly deferred to Layer 4 / Layer 6 with a named reason

Immediate backlog seeded by Layer 2

- capture one controlled end-to-end incident after cutover and trace all writes
- verify whether `site_alarm_events` is flowing into `incidents` again
- verify whether dispatch actions now emit `dispatch_transitions`
- verify whether new evidence-chain rows appear after a fresh alert
- verify whether the Pi -> Mac enhancement handoff is still desired
- verify whether the camera-worker disconnect loop still appears after the
  cutover-era runtime hardening
