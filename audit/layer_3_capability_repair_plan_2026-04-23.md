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
- v1 Flutter decommission strategy
- broad Layer 6 RLS / tenancy / schema-shape decisions
- new product surface area

Those stay with the already-documented Layer 4 / Layer 6 deferrals.

Workstream 1 — Restore incident and dispatch truth

Build the alarm-to-incident promotion and operator-action write
paths. Phase A1 (2026-04-24, commit e7dceb7) proved no promotion
path exists anywhere in production (hypothesis (d) locked), and
that the three Telegram button handlers in the live AI processor
attempt writes to pre-cutover schema (`dispatches`, `events`)
that do not exist — writes throw, try/catch swallows silently.
This workstream is therefore a BUILD, not a repair.

### Phase A1 findings (2026-04-24)

Report: `audit/workstream_1_phase_a1_discovery_2026-04-24.md` (commit e7dceb7)

- No automated promotion path exists. Code search, 6 deployed edge
  function audit, DB trigger introspection, pg_cron live query, and
  Hetzner/Pi service enumeration all independently confirmed this.
- Telegram button handlers (Dispatch / Acknowledge / False alarm)
  in `bin/onyx_telegram_ai_processor.dart` on Hetzner fire on
  operator tap, but write to stale schema:
    - Dispatch → `supabase.from('dispatches').insert(...)` —
      table does not exist
    - Acknowledge → `_updateEventRow` → `supabase.from('events').update(...)` —
      table does not exist
    - False alarm → same `_updateEventRow` path — same stale table
  Exceptions are swallowed by try/catch; operator sees a toast
  ("Dispatch could not be logged right now.", etc.); no DB state
  changes.
- View camera button works correctly (read-only side effect via
  snapshot fan-out) — used as the known-working control to confirm
  the callback_query delivery chain is alive for all four buttons.
- v1 Flutter code (`lib/main.dart:17280+`) has mirrored handlers
  with the same bug, but v1 is not running in production (phase 2b
  §4.1) — latent duplicate, blast radius decision at Phase A3.

### Phase A3 design inputs

Phase A2 (synthetic test) is SKIPPED per A1's conclusion strength.
Proceed directly to Phase A3 design work. Six open questions from
the A1 report must be resolved before Phase B implementation:

1. **Dispatch target model.** Write to `public.dispatch_intents`
   (gets `auto_decided_transition` trigger-seeded
   `dispatch_transitions` for free) vs. write to `public.incidents`
   directly (simpler UI wiring, command-center reads from there).
   Which matches the intended data model?
2. **Acknowledge / False alarm target model.** Update
   `incidents.status`. If no incidents row exists yet for the
   given alert (because Dispatch wasn't tapped first), does
   Ack/False alarm create the incident row as a side-effect, or
   require incident-first?
3. **Incident creation point.** Is incident creation triggered by
   operator button tap (manual), by automated promotion from
   `site_alarm_events` (background service / edge function /
   pg_cron), or both (manual path creates immediately; automated
   path catches un-acted alerts after N minutes)?
4. **Ledger coupling.** Does `client_evidence_ledger` receive
   writes directly from the button handlers, or from a downstream
   service (e.g., `OnyxEvidenceCertificateService`) that reads
   from `incidents`/`dispatch_intents`? Note Amendment 4's FK
   deferral allows `dispatch_id` unconstrained.
5. **v1 Flutter blast radius.** When the fix lands in the AI
   processor, do we also patch the dead v1 handler in
   `lib/main.dart` for hygiene, or leave it and consolidate as
   part of a broader v1→v2 cutover later?
6. **Pre-cutover incident origin** (historical context, not
   blocking). The last new incident row was 2026-03-11. If those
   238 pre-cutover rows came from a retired service, that source
   might merit tracing. Left open.

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

Prerequisite:
- `client_evidence_ledger.dispatch_id` (text) vs
  `dispatch_intents.dispatch_id` (uuid) FK type mismatch must be
  resolved OR Workstream 2 exit criterion must be relaxed to
  "ledger appends with dispatch_id unconstrained until FK
  reconciled." See Amendment 4 for deferral rationale.

Repair targets:
- `client_evidence_ledger` write path
- any coupling between alert/incident generation and ledger append
- evidence certificate generation for fresh events
- chain-integrity behavior on newly-created rows

Exit criteria:
- a fresh operational event appends new ledger rows (`dispatch_id` linkage may
  be null/unconstrained pending FK reconciliation; track FK work as separate
  item)
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
- FD runtime profile completed 2026-04-24 (see
  `audit/fd_leak_runtime_profile_2026-04-24.md`, commits `04d73b2`
  and `9bfc726`). Static hypothesis contradicted; real root cause
  was in the proxy (fixed in `1612f0d`). Worker-side FD release
  bug in `bin/onyx_camera_worker.dart:2889-3007` `_runConnectionLoop()`
  is latent post-proxy-fix but not resolved; tracked as this
  workstream's next code-change item.
- any watchdog/telemetry needed so the next failure is diagnosable quickly

Exit criteria:
- either:
  - Pi -> Mac detect POSTs are visible and intentional, or
  - the enhancement tier is explicitly removed from the path and documented
- camera-worker survives a 24h window without the prior failure pattern
- alert generation continues during that window

Workstream 4 — Guard / patrol / workforce data-path triage

MS Vallee has no guards on patrol. Guard/patrol capabilities are
dormant-by-design at this deployment. Workstream 4 output is a
documented dormancy decision record; no write-path repair work
performed. Surface cleanup (dashboard screens showing dormant tables)
deferred to Layer 4.

Tables confirmed dormant at MS Vallee:
- `guard_location_heartbeats`
- `guard_assignments`
- `guard_panic_signals`
- `guard_incident_captures`
- patrol-related writes that are supposed to power the workforce surfaces

Exit criteria:
- dormancy decision committed as audit artifact

Workstream 5 — Zara / advanced-assist capability triage

Zara / advanced-assist capabilities are not operational at MS Vallee.
Workstream 5 output is a documented deferral decision record. If/when
Zara becomes operational scope (Layer 5 commercial site or later), a
fresh capability-restoration workstream is scoped at that time.

Repair targets:
- `zara_action_log`
- `zara_scenarios`
- `onyx_awareness_latency`
- `onyx_alert_outcomes`

Exit criteria:
- deferral decision committed as audit artifact

Suggested sequence

1. Run the post-cutover smoke checklist over 24h to confirm the preserved
   deployment is stable enough to repair on top of.
2. Workstream 1: incident + dispatch truth
3. Workstream 2: evidence + ledger continuity
4. Workstream 3: enhancement path + camera-worker stability
   Note: Workstream 3's 24h stability verification runs in parallel
   with Workstreams 4+5 (both of which reduce to decision records, not
   active work), not serially. Total Layer 3 calendar time is bounded
   by the longer of Workstream 3's 24h window or Workstreams 1+2
   combined.
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
- resolve FK type mismatch on `client_evidence_ledger.dispatch_id`
  before Workstream 2 exit criteria can be met with constrained schema
  (see Amendment 4)
- Workstream 1 Phase A3 design decisions (6 open questions; see
  Workstream 1 Phase A3 design inputs) must resolve before Phase B
  implementation begins
- verify whether the Pi -> Mac enhancement handoff is still desired
- verify whether the camera-worker disconnect loop still appears after the
  cutover-era runtime hardening

## Open Items From Review (2026-04-23)

- Deferred FK `client_evidence_ledger.dispatch_id` (text) vs
  `dispatch_intents.dispatch_id` (uuid) — elevate from "not in scope"
  to named blocker. Workstream 2 exit criteria cannot be met with
  constrained schema until FK reconciled. See Amendment 4 for
  deferral rationale.

- FD leak diagnosis incomplete. Static hypothesis committed at
  `audit/fd_leak_diagnosis.md`; Pi-side runtime profiling was deferred
  during Layer 2 execution. Belongs under Workstream 3 as unfinished
  verification work, not closed.

- Workstream 4 and 5 decision rules are likely pre-determined for
  MS Vallee (no guards, no Zara in live use). Consider collapsing
  both to dormancy-decision records rather than triage workstreams
  in the next plan revision.
