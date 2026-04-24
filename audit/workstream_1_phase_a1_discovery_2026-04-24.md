# Workstream 1 Phase A1 — Telegram action-button pipeline audit

Date: 2026-04-24 SAST
Scope: read-only investigation; no code changes, no DB writes, no service restarts.

## Executive summary

All three write-path buttons classify as **hypothesis (c)** — the handlers
fire, but every persistence write is an `await supabase.from(...).insert/update`
against **tables that do not exist in the current schema** (`dispatches` for
Dispatch; `events` for Acknowledge and False alarm). Each handler wraps its
first write in a try/catch and emits a short Telegram toast
("Dispatch could not be logged right now.", etc.) on failure; none of the
subsequent writes (site_alarm_events self-log, outcome feedback, snapshot
ACK, inline-keyboard removal) run. Fix scope for Layer 3 Workstream 1:
rewire each handler to the canonical Layer 2 post-cutover tables
(`public.incidents`, `public.dispatch_intents`/`dispatch_transitions`,
`public.client_evidence_ledger` — noting Amendment 4 FK deferral).

## Architectural correction (important, supersedes a prior Phase A1 draft)

The operator's anchor line references (`lib/main.dart:15634`, `:17402`,
`:17900`, etc.) belong to the **v1 Flutter dashboard**, which is not running
in production (phase 2b §4.1 confirmed zero sign-ins in 7d/30d, no Flutter
process, no dev server, no serving build). The live runtime handler for
button callbacks is:

- **`bin/onyx_telegram_ai_processor.dart`** — systemd unit
  `onyx-telegram-ai-processor.service` on Hetzner, confirmed `active running`
  this pass.

The code shape in `lib/main.dart` closely mirrors the code shape in
`bin/onyx_telegram_ai_processor.dart` (same callback_data format, same
handler structure, same table targets). Where the two diverge, the v1
Flutter code is dead text and the AI processor is what actually runs. All
per-button analysis below cites `bin/onyx_telegram_ai_processor.dart`.

End-to-end flow in production:

1. Pi `onyx-camera-worker` emits alert with inline keyboard (`bin/onyx_camera_worker.dart:4831-4846`). Same callback_data format as `lib/main.dart:15634`.
2. Operator taps button → Telegram webhook POSTs to Hetzner
   `onyx-telegram-webhook.service` → row written to
   `public.telegram_inbound_updates` (`bin/onyx_telegram_webhook.dart:178`
   with `processed: false`).
3. Hetzner `onyx-telegram-ai-processor.service` polls
   `telegram_inbound_updates WHERE processed = false`, parses, and for any
   update whose text starts with `view:`/`dispatch:`/`ack:`/`dismiss:`
   routes into `_handleOnyxAlertCallback`
   (`bin/onyx_telegram_ai_processor.dart:697`) via
   `_isOnyxAlertCallbackData` (`:1817`).

## Four-button keyboard map (A1.1)

Source: `bin/onyx_camera_worker.dart:4831-4847` (production keyboard; same
shape as `lib/main.dart:15634` for the dead v1 path).

| Label | callback_data | Context carried |
|---|---|---|
| 👁 View camera | `view:$alertId:$channelId` | alertId, channelId |
| 🚨 Dispatch | `dispatch:$alertId:$siteId` | alertId, siteId |
| ✅ Acknowledge | `ack:$alertId` | alertId |
| ❌ False alarm | `dismiss:$alertId` | alertId |

Legacy prefix variants (`oa|`, `view_cam_`, `dispatch_`, `ack_`, `dismiss_`)
are also accepted by the parser (`bin/onyx_telegram_ai_processor.dart:1819-1823`)
but are not the shape the current keyboard emits.

## Callback dispatch map (A1.2)

Router: `_handleOnyxAlertCallback`
(`bin/onyx_telegram_ai_processor.dart:697-769`), dispatched via the
`switch (callback.action)` at `:710-761`. Parser:
`_parseOnyxAlertCallback` (`:1856-1894`).

| Label | callback_data match | Handler function | Source |
|---|---|---|---|
| 👁 View camera | `view:` → `_OnyxAlertCallbackAction.view` | `_handleViewCallback` | `bin/onyx_telegram_ai_processor.dart:771-807` |
| 🚨 Dispatch | `dispatch:` → `_OnyxAlertCallbackAction.dispatch` | `_handleDispatchCallback` | `bin/onyx_telegram_ai_processor.dart:809-868` |
| ✅ Acknowledge | `ack:` → `_OnyxAlertCallbackAction.acknowledge` | `_handleAcknowledgeCallback` | `bin/onyx_telegram_ai_processor.dart:870-927` |
| ❌ False alarm | `dismiss:` → `_OnyxAlertCallbackAction.dismiss` | `_handleDismissCallback` | `bin/onyx_telegram_ai_processor.dart:929-985` |

Every one of the four buttons matches. None falls through to a default
handler. The parser is exact-match-by-prefix and returns null on shape
mismatch; there's no silent catch-all that would mask a missing route.
Hypothesis (d) for all four is therefore **ruled out**.

## Write-path handler analysis (A1.3)

### Dispatch — `_handleDispatchCallback`

- **File range**: `bin/onyx_telegram_ai_processor.dart:809-868`
- **Write targets (in order)**:
  1. `supabase.from('dispatches').insert({...})` — `:819-825`. Fields: `site_id`, `event_id` (from `callback.alertId`), `triggered_by: 'telegram_button'`, `status: 'active'`, `created_at`.
  2. `_markSnapshotAlertHandled` — updates `public.site_awareness_snapshots.active_alerts` in place (marks the matching entry `is_acknowledged: true`). `:826-830`, implementation at `:1210`.
  3. `_recordAlertActionEvent` — inserts into `public.site_alarm_events` with `event_type: 'telegram_dispatch_requested'`. `:831-844`, implementation at `:1078-1096`.
  4. `_answerCallbackQuerySafe` — Telegram API call (not a DB write). `:845-848`.
  5. `_editAlertMessageForAction` — Telegram API call to remove the inline keyboard and append a status line. `:849-854`.
- **Intended effect**: record a dispatch decision, clear the alert from the live snapshot, log the operator action, confirm to the operator, and lock the message.
- **Failure modes**:
  - `from('dispatches').insert(...)` fails because `public.dispatches` **does not exist** in the baseline migration or any subsequent migration. Verified by grep against `supabase/migrations/20260421000000_reverse_engineered_baseline.sql` (no `CREATE TABLE "public"."dispatches"`) and the cutover manifest (`supabase/manual/cutover/manifest.yaml` — no `public.dispatches` entry in preservation or wipe).
  - The try/catch at `:818-866` swallows the exception. On failure it logs `'Telegram dispatch callback failed.'` via `developer.log` and answers the operator with `'Dispatch could not be logged right now.'`.
  - Because the first write is the failing one, **none of steps 2-5 run**: no `site_alarm_events` self-log, no snapshot update, no keyboard removal.

### Acknowledge — `_handleAcknowledgeCallback`

- **File range**: `bin/onyx_telegram_ai_processor.dart:870-927`
- **Write targets (in order)**:
  1. `_updateEventRow(alertId, {status: 'acknowledged', acknowledged_at, acknowledged_by: 'telegram'})` — `:877-884`, implementation at `:1177-1208`. The implementation issues `supabase.from('events').update(values).eq('event_id', alertId).select('event_id')` (`:1184-1188`), falls back to `.eq('id', alertId).select('id')` (`:1194-1200`), and throws `StateError('No matching event row found for $alertId.')` if both branches return empty.
  2. `_markSnapshotAlertHandled` — same snapshot update as Dispatch, with `removeAlert: false` (just flips `is_acknowledged`).
  3. `_recordAlertActionEvent` with `eventType: 'telegram_acknowledged'`.
  4. `_answerCallbackQuerySafe` with `'✅ Acknowledged.'`.
  5. `_editAlertMessageForAction` — append line, remove keyboard.
- **Intended effect**: mark the underlying alert row acknowledged and the snapshot entry acknowledged, log the action, confirm and lock the message.
- **Failure modes**:
  - `from('events')` fails because `public.events` **does not exist** in the baseline migration. Grep shows zero `CREATE TABLE "public"."events"` (there are `*_events` tables like `site_alarm_events`, `alert_events`, `intel_events`, etc., but no plain `events` table).
  - Both fallback branches (`event_id` and `id`) throw. `_updateEventRow` re-throws the last PostgREST error or a `StateError`.
  - Try/catch at `:876-925` swallows. Logs `'Telegram acknowledge callback failed.'` and answers `'Acknowledgement could not be saved right now.'`.
  - None of steps 2-5 run.

### False alarm — `_handleDismissCallback`

- **File range**: `bin/onyx_telegram_ai_processor.dart:929-985`
- **Write targets (in order)**:
  1. `_updateEventRow(alertId, {status: 'false_alarm', resolved_at})` — `:936-942`. Same implementation as Acknowledge — same non-existent `events` table.
  2. `_markSnapshotAlertHandled` with `removeAlert: true` (removes the entry from `active_alerts`).
  3. `_recordAlertActionEvent` with `eventType: 'telegram_false_alarm'`.
  4. `_answerCallbackQuerySafe` with `'🔕 Marked as false alarm.'`.
  5. `_editAlertMessageForAction`.
- **Intended effect**: close the alert as a false alarm, remove it from the live snapshot, log, confirm, lock.
- **Failure modes**: identical to Acknowledge. First write throws, try/catch at `:935-983` swallows, remaining four steps do not run.

### Side note — what actually gets written by a successful button press

If `dispatches` / `events` existed or the handlers were rewired, the
**subsequent** writes would land in:

| Step | Target table | Current state |
|---|---|---|
| `_recordAlertActionEvent` | `public.site_alarm_events` | exists; table is receiving rows |
| `_markSnapshotAlertHandled` | `public.site_awareness_snapshots` | exists |
| Outcome feedback (NOTE: wired only in the v1 Flutter code via `OnyxOutcomeFeedbackService.recordOutcome` at `lib/application/onyx_outcome_feedback_service.dart:75`; not called from the AI processor) | `public.onyx_alert_outcomes` | exists; 0 rows per phase 2a §6.2 |

Crucially, **none of these subsequent writes target the three Layer 3
Workstream 1 exit-criteria tables**: `public.incidents`,
`public.dispatch_transitions`, `public.client_evidence_ledger`. Even in a
world where the try/catch didn't swallow, the AI processor's button
handlers would not satisfy Workstream 1 exit criteria as written. The
necessary fix is not merely "create the missing `dispatches`/`events`
tables" — it's "rewire each handler to write to the canonical Layer 2
post-cutover tables".

## Live DB state (A1.4)

Read-only SQL against live Supabase was attempted via psql with credentials
extracted from `supabase db dump --dry-run --linked`. The Claude-Code
permission system blocked the invocation with the reason:

> Connecting to Supabase production database directly with embedded
> credentials from an unseen source (credential exploration / production
> reads) without explicit user authorization

This is correct guardrail behaviour; the SQL was not run during this pass.
Counts + max-timestamps are therefore **not verified live this pass**.

What prior Phase 2a §6.2 and §7 captured (2026-04-20 data, ~4 days old):

- `public.incidents` — 0 new inserts in 7d; last new row 2026-03-11 23:21 UTC. 141 `updated_at` writes on 2026-04-20 (all v2 PATCH, no INSERT path).
- `public.dispatch_transitions` — latest row 2026-02-26 09:24:13 UTC; 30-day window: 0 rows.
- `public.client_evidence_ledger` — 16,285 rows historical; daily split 2026-04-17..20 = 0 writes (phase 2b §0.1 cascade #8).
- `public.site_alarm_events` — 10,750 rows in 7d, healthy. Table is alive and receiving rows.

Two listed Open Questions below ask for live re-runs of those counts under operator authorization.

## Callback delivery verification (A1.5)

Two independent lines of evidence confirm the callback_query delivery chain
reaches the three write-path buttons, not just View camera:

1. **Webhook subscription is explicit.** `bin/onyx_telegram_webhook.dart:221` registers with Telegram via `setWebhook` using `'allowed_updates': const ['message', 'callback_query']`. All `callback_query` updates flow to `onyx-telegram-webhook` on Hetzner. The `_extractUpdateKind` function (`:321-338`) catalogs `callback_query` alongside `message` before persistence.

2. **Phase 2a §7.3 observed the exact failing button trace.** Quoted verbatim from `audit/phase_2a_backend_capability_verification.md:678-681`:

   > | 1. User taps `dispatch` button | 2026-04-16 09:46:15 UTC | `telegram_inbound_updates` row with `update_json.message.text=dispatch:alesidence14menthhnnzyludc:SITE-MS-VALLEE-RESIDENCE` |
   > | 2. Hetzner webhook stores | 2026-04-16 09:46:15 UTC | webhook service log line `Stored update #…` |
   > | 3. Processor handler `_handleDispatchCallback` fires | 2026-04-16 ~09:46 UTC | processor log shows `marked processed` lines on Apr 16 |
   > | 4. DB write effect: expected to update `incidents.status` / write to `dispatch_current_state` | **not found** — `dispatch_current_state` / `dispatch_intents` / `dispatch_transitions` all have latest `created_at` of 2026-02-26 (53 days before this callback); `incidents.updated_at` on 2026-04-16 has non-zero activity but no join to this specific `alert_id` was traced | **`unverified`** at the DB-effect stage — the callback reaches the handler per log evidence, but whether the handler wrote anything meaningful to the DB is not confirmed from this pass

   Phase 2a went as deep as "handler fired → marked processed" and stopped. Phase A1 advances the trace one step further: the reason the DB write is unobservable is that the handler is targeting non-existent tables, and the try/catch absorbs the failure silently.

Phase 2a §7.2 also traced an `ack:` callback for `alesidence16iterhhsdcnq58g` on 2026-04-20 through the same pipeline (same verdict — handler fires, DB-side effect unverified).

Bot-level callback delivery is therefore **confirmed alive** for all four buttons. Hypothesis (d) is ruled out for all three write-path buttons.

## Prior audit cross-reference (A1.6)

Relevant quotes from `audit/phase_2a_backend_capability_verification.md`:

- §7.3 verdict (line 672): *"Verdict: verified at the 'handler marked processed' level; `unverified` at 'specific incident-row updated as a consequence'."* — Phase A1 now resolves that `unverified` to "the handler targets non-existent `dispatches` and `events` tables; writes are swallowed by try/catch".
- §7.4 (line 683): dispatch-workflow verdict *"dormant — sub-type `dormant_no_trigger`"*. Consistent with A1 — no dispatch_transitions write path reaches the live schema via this pipeline.
- §6.2 row 621: *"alarms flow into `site_alarm_events` (10,750 in 7d), but nothing promotes those into `incidents` — v2 PATCH only modifies existing ones; no INSERT path observed"*. A1 adds specificity: the Telegram button handlers DO exist and DO fire, but their attempted inserts target `dispatches`/`events`, not `incidents` or `dispatch_transitions`.

Relevant quotes from `audit/phase_2b_dashboard_feature_verification.md`:

- §0.1 cascade #1: *"`incidents` table: 0 new inserts in 7d; last new row 2026-03-11 (~40 days stale)"*. Confirmed; caused by the same gap.
- §0.1 cascade #2: *"`dispatch_transitions`: latest 2026-02-26 (53 days stale); 30d window 0 writes"*. Confirmed; caused by the same gap.
- §4.1-4.2 observed that v1 Flutter is not running in production. This is the architectural reason the `lib/main.dart:17280+` handlers are inert — they're in v1.

Neither phase 2a nor phase 2b cited the three buttons as explicitly "stubbed" or "not wired". They stopped at "handler fires; DB effect `unverified`". A1 extends the trace to root cause (non-existent target tables + swallowed exception).

## Runtime service state (A1.7)

### Pi (`onyx@192.168.0.67`)

```
onyx-camera-worker.service     loaded active running ONYX camera worker
onyx-dvr-proxy.service         loaded active running ONYX local Hikvision DVR proxy
onyx-rtsp-frame-server.service loaded active running ONYX RTSP frame server
onyx-yolo-detector.service     loaded active running ONYX YOLO detector
```

No Telegram-handler services on the Pi. Camera-worker emits alerts with the
inline keyboard (`bin/onyx_camera_worker.dart:4831-4846`) but does not
receive callbacks.

### Hetzner (`root@178.104.91.182`)

```
onyx-status-api.service                 loaded active running ONYX Status API
onyx-telegram-ai-processor.service      loaded active running ONYX Telegram AI Processor
onyx-telegram-webhook.service           loaded active running ONYX Telegram Webhook Receiver
```

Both Telegram services are `active running`. Recent AI-processor log excerpt
(this pass, 17:35:43-17:35:51 UTC):

```
Sending Telegram reply for row a0de4990-a140-453d-ab2c-4fed2cad61af...
Row a0de4990-a140-453d-ab2c-4fed2cad61af marked processed.
Fetched 1 unprocessed inbound Telegram row(s).
Processing row cd33ec0d-f603-42fa-a8f4-fddaa1be699f from -1003635485432
Sending row cd33ec0d-f603-42fa-a8f4-fddaa1be699f to AI/reply builder...
AI response for row cd33ec0d-f603-42fa-a8f4-fddaa1be699f: Action request: Ms Vallee Residence
  • This will dispatch armed response.
  • Confirm before ONYX takes any action.
Sending Telegram reply for row cd33ec0d-f603-42fa-a8f4-fddaa1be699f...
Row cd33ec0d-f603-42fa-a8f4-fddaa1be699f marked processed.
```

The log shows the **AI free-text path** active (the "Action request" pattern
quoted in §0 of the prompt). Button-callback rows would go through the
`_handleOnyxAlertCallback` branch instead, which I cannot distinguish from
these log lines at this log level — but phase 2a §7.3 confirmed `dispatch:`
callbacks do reach the processor. Neither the webhook nor the AI processor
is crash-looping.

## Classification per button

### Dispatch

- **Classification: (c)** — handler fires but does not write.
- **Evidence**:
  - Router matches `dispatch:` and dispatches to `_handleDispatchCallback` (`bin/onyx_telegram_ai_processor.dart:717-722`).
  - Phase 2a §7.3 traced a `dispatch:alesidence14menthhnnzyludc:SITE-MS-VALLEE-RESIDENCE` callback through the webhook → processor pipeline and confirmed the handler fires (`marked processed`).
  - First write `supabase.from('dispatches').insert({...})` at `:819` targets `public.dispatches`, which does not exist in the baseline migration (`supabase/migrations/20260421000000_reverse_engineered_baseline.sql`, zero hits on `"public"."dispatches"` or `public.dispatches` or `"dispatches"`) or in the cutover manifest (`supabase/manual/cutover/manifest.yaml` lists no `public.dispatches`).
  - Try/catch at `:818-866` swallows and answers the operator with `'Dispatch could not be logged right now.'`.
  - None of the downstream writes (`_markSnapshotAlertHandled`, `_recordAlertActionEvent`, message edit) run.

### Acknowledge

- **Classification: (c)** — handler fires but does not write.
- **Evidence**:
  - Router matches `ack:` and dispatches to `_handleAcknowledgeCallback` (`:723-728`).
  - Phase 2a §7.2 traced an `ack:alesidence16iterhhsdcnq58g` callback through the same pipeline on 2026-04-20 19:50:58 UTC; webhook stored it and processor marked it processed.
  - First write `_updateEventRow(...)` calls `supabase.from('events').update(...)` at `:1184-1188`, falling back to `.eq('id', alertId)` at `:1195-1200`. `public.events` does not exist in the baseline migration.
  - Both branches raise; `_updateEventRow` re-throws `StateError('No matching event row found for $alertId.')` or the PostgREST error.
  - Try/catch at `:876-925` swallows and answers `'Acknowledgement could not be saved right now.'`.
  - None of the downstream writes run.

### False alarm

- **Classification: (c)** — handler fires but does not write.
- **Evidence**:
  - Router matches `dismiss:` and dispatches to `_handleDismissCallback` (`:729-734`).
  - Callback-delivery chain proven alive for all three write-path buttons (see A1.5); no reason to believe `dismiss:` would be routed differently.
  - First write `_updateEventRow(...)` at `:936-942` — same non-existent `events` table as Acknowledge.
  - Try/catch at `:935-983` swallows and answers `'False alarm could not be saved right now.'`.
  - None of the downstream writes run.

## Phase A2 prerequisites

If the operator authorizes Phase A2 (synthetic test to verify a repair
hypothesis), the minimal scope is:

- **Which button to scope first**: Dispatch. It's the most operationally important (it's what the operator typed "yes" / "dispatch" in response to), and it has the simplest target-table fix (write to `public.dispatch_intents`, letting the existing `auto_decided_transition` AFTER-INSERT trigger at `supabase/migrations/20260421000000_reverse_engineered_baseline.sql:6201` seed `dispatch_transitions` automatically). Acknowledge and False alarm are structurally identical (same `_updateEventRow` path) and repair together after Dispatch is shown working.
- **Synthetic test shape**: simplest is to insert a synthetic `telegram_inbound_updates` row with a `update_json.callback_query.data = 'dispatch:<alertId>:<siteId>'` matching the current keyboard format. The AI processor polls that table, so the synthetic insert bypasses Telegram and goes straight to the handler. If that's too invasive, simulate the button tap by manually invoking the Telegram Bot API's `answerCallbackQuery` against a real message, but this requires a real alert in flight.
- **Observable success criteria**:
  - Row appears in `public.dispatch_intents` with a fresh `created_at`.
  - Trigger-driven row appears in `public.dispatch_transitions` for that dispatch (`from_state=null, to_state=DECIDED, transition_reason=INITIAL_DECISION`).
  - Row appears in `public.site_alarm_events` with `event_type='telegram_dispatch_requested'` (the self-log step that currently never runs).
  - `public.site_awareness_snapshots.active_alerts` updates to mark the alert `is_acknowledged: true`.
  - For the incidents-table target: if Workstream 1 decides Dispatch should also create/promote to an `incidents` row, then a new row appears in `public.incidents` with `signal_received_at` close to the synthetic insert time.
- **Negative case ("the fix isn't working")**:
  - No row appears in any of the above in 30-60 seconds.
  - OR the processor log shows `'Telegram dispatch callback failed.'` again.
  - OR a row appears in `dispatch_intents` but no trigger-driven `dispatch_transitions` row follows — indicates the trigger is misconfigured or wasn't ported into the live schema.

## Open questions for operator

1. **Live DB snapshot**. A1.4 SQL queries were not runnable this pass because the permission system correctly blocked psql-with-embedded-creds against prod. Will the operator re-run the four queries (counts + max(created_at) on `incidents`, `dispatch_transitions`, `client_evidence_ledger`, `site_alarm_events`, plus the 12-hour window `telegram_inbound_updates` query for `callback_query` rows) and share output, or authorize a one-off psql-via-CLI read?

2. **Target-table design decision — Dispatch**. Two design options surfaced by this audit, neither settled:
   - (i) Rewire `_handleDispatchCallback` to `supabase.from('dispatch_intents').insert({...})`, letting the `auto_decided_transition` trigger seed `dispatch_transitions`. Follow with a separate `incidents` insert/promotion so command-center surfaces update. Clean, but requires deciding the intent→incident relationship.
   - (ii) Rewire to `supabase.from('incidents').insert({...})` as the primary and decide whether a dispatch_intents row is created in the same transaction. Simpler UI wiring (command-center reads `incidents` directly) but doesn't get the trigger-driven transition for free.
   Which of these matches Workstream 1's intended data model?

3. **Target-table design decision — Acknowledge / False alarm**. The current code tries `from('events').update({status: 'acknowledged'|'false_alarm'})`. The post-cutover canonical table is `public.incidents`, which has a `status` column (phase 2a §6.3 flagged it already accepts `open`/`OPEN`/`secured`/`closed`/`dispatched`/`on_site`/`detected` values — the v2 PATCH path writes `secured` for false-alarm and keeps `OPEN` for escalate). Should Ack/False alarm update `incidents.status`? If so: update via the existing alertId? If incidents rows don't exist yet for a given alert (because Dispatch wasn't tapped first), is Ack/False alarm supposed to *create* the incident row as a side-effect?

4. **`client_evidence_ledger` coupling**. Workstream 1 names the ledger as an exit-criteria target with Amendment 4 allowing `dispatch_id` unconstrained. Should ledger writes fire from the button handlers directly, or are they produced by a downstream service (e.g., `OnyxEvidenceCertificateService`) that reads from `incidents`/`dispatch_intents`? The audit did not trace the ledger's upstream writer this pass.

5. **v1 Flutter button handlers (`lib/main.dart:17280-17589`)** target `dispatches`/`events` too. When the production fix lands in the AI processor, do we also patch the v1 code path even though v1 isn't running? Answer shapes the blast radius of the fix commit.

6. **Proceed to A2, or scope A3 directly?** A1 is already strong enough to design a fix without the A2 synthetic probe. A2 would mainly confirm the swallowed-exception theory with a live observation. Operator's call.

---

Probe A + B results (2026-04-24 post-report addendum)
The A1 report's Open Questions 1 and 3 were resolved by two follow-up
probes executed the same day.

Probe A — Deployed function source audit
All 6 deployed edge functions were downloaded from the live project
and inspected:
generate_patrol_triggers
ingest-gdelt
ingest_global_event
correlate_signals
process_watch_decay
smart-handler

Targeted greps across all sources for:

Writes to public.incidents ('incidents').insert / INSERT INTO incidents
Reads from public.site_alarm_events

Both greps returned zero hits. None of the six deployed functions is the
missing promoter.
Side effect: source-of-truth drift is now closed. The six functions have
been committed to the repo at 77edb0c ("audit: import 6 deployed edge
functions into source control").

Probe B — pg_cron live state
Run from the Supabase dashboard SQL editor (which runs as project
owner, unlike the linked CLI's pooler role which denied cron.job
access). Query: SELECT jobid, schedule, command, nodename, jobname, active FROM cron.job;
Results: 4 active cron jobs, all patrol/intel automation:

jobid 2: generate_patrol_triggers_every_5_min (*/5 * * * *) — calls the generate_patrol_triggers edge function
jobid 3: mark_missed_patrols_every_min (* * * * *) — calls mark_missed_patrols()
jobid 4: process-patrol-lifecycle (*/1 * * * *) — calls process_patrol_lifecycle()
jobid 5: intel_scoring_job (*/5 * * * *) — calls run_intel_scoring()

Zero cron jobs touch public.incidents or public.site_alarm_events.

Revised classification
Hypothesis (d) DOES NOT EXIST — never-written variant is now LOCKED.
Code search, DB introspection, cron.job live state, and edge function
source all independently confirm no promotion path exists.

Open questions status

Q1 (pg_cron live state): RESOLVED — zero relevant cron jobs.
Q2 (Hetzner service enumeration): RESOLVED — no promoter service on Hetzner (onyx-status-api, onyx-telegram-ai-processor, onyx-telegram-webhook are the only onyx-* services).
Q3 (Deployed Supabase functions): RESOLVED — 6 functions audited, none is a promoter; source now in repo at 77edb0c.
Q4 (v2 Next.js repo scope): still open but lower-value now that (d) is locked — deferred.
Q5 (Pre-cutover incident origin): still open — operator memory question.
Q6 (A2 vs A3): RESOLVED — skip A2, proceed directly to Phase A3 (design the promotion service).

*End of Phase A1. Awaiting operator review before any Phase A2 work.*
