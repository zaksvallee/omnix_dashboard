# Workstream 1 Phase B — Phase A (Investigation) — Proposal

Date: 2026-04-24 SAST
Scope: investigation only; no code changes, no migrations written, no DB writes.
Reference: A3 decisions locked in `audit/workstream_1_phase_a3_design_2026-04-24.md`.

## Executive summary

The A3 design maps cleanly onto the runtime handler code (three small
handlers in `bin/onyx_telegram_ai_processor.dart`) and is achievable as a
surgical rewrite. However, the actual post-cutover schema diverges from A3's
working assumptions on **six concrete points** (column names, column types,
absence of an `incident_id` column on `dispatch_intents`, and a CHECK
constraint on `site_alarm_events.event_type` that rejects every
`telegram_*` event value the existing helper tries to write). Five are
resolvable in code alone. **One — the `site_alarm_events.event_type` CHECK —
requires either a small targeted migration or dropping the
site_alarm_events-side audit log in Phase B; the choice is an operator
decision before Phase B proper begins.** Idempotency keys exist cleanly:
`incidents.event_uid` (already UNIQUE) carries the alert identity for
upsert; `dispatch_current_state` view gives the duplicate-safety check
surface for dispatch_intents. Once the operator answers Q1 (migrate vs drop
audit log), Phase B implementation is unblocked.

## Current handler structure

### Dispatch handler (`bin/onyx_telegram_ai_processor.dart:809-868`)

- **What it reads**: `update` (Telegram message), `target` (resolved `_ProcessorTarget` with `siteId`), `callback` (`_OnyxAlertCallback` carrying `alertId`, `siteId`, `channelId`), `nowUtc`.
- **What it attempts to write** (all inside one big try-catch):
  1. `supabase.from('dispatches').insert({site_id, event_id: alertId, triggered_by: 'telegram_button', status: 'active', created_at})` (`:819-825`). **Target table `public.dispatches` does not exist.**
  2. `_markSnapshotAlertHandled(siteId, alertId, removeAlert: false)` — updates `site_awareness_snapshots.active_alerts` to flip the entry's `is_acknowledged: true` (`:826-830`, implementation `:1210-1252`).
  3. `_recordAlertActionEvent(..., eventType: 'telegram_dispatch_requested', ...)` — inserts into `site_alarm_events` with raw_payload carrying the operator context (`:831-844`, implementation `:1078-1096`).
  4. `_answerCallbackQuerySafe` with success text (`:845-848`).
  5. `_editAlertMessageForAction` with "Dispatch logged" line + `removeInlineKeyboard: true` (`:849-854`).
- **What gets swallowed on failure**: the try/catch at `:818-866` catches any exception, calls `developer.log('Telegram dispatch callback failed.')`, and answers the operator with the short toast `'Dispatch could not be logged right now.'`. None of steps 2-5 run when step 1 throws. The operator's only visible signal is the tiny toast (easy to miss if they've already closed the message).
- **What downstream helpers fire (post-fix semantics to preserve)**: `_markSnapshotAlertHandled`, `_recordAlertActionEvent` (subject to the event_type CHECK issue below), `_answerCallbackQuerySafe`, `_editAlertMessageForAction`. These are fine to keep; the first write needs rewiring.

### Acknowledge handler (`bin/onyx_telegram_ai_processor.dart:870-927`)

- **What it reads**: same inputs. `callback.alertId` only — no `siteId` / `channelId` in the ack callback_data format (`ack:$alertId`); `target.siteId` is the fallback.
- **What it attempts to write**:
  1. `_updateEventRow(alertId, {status: 'acknowledged', acknowledged_at, acknowledged_by: 'telegram'})` — first tries `supabase.from('events').update(values).eq('event_id', alertId)` (`:1184-1188`), falls back to `.eq('id', alertId)` (`:1194-1200`), throws on both-empty. **Target table `public.events` does not exist.**
  2. `_markSnapshotAlertHandled(removeAlert: false)`.
  3. `_recordAlertActionEvent(eventType: 'telegram_acknowledged')`.
  4. `_answerCallbackQuerySafe` with `'✅ Acknowledged.'`.
  5. `_editAlertMessageForAction`.
- **What gets swallowed**: try/catch at `:876-925` absorbs the `events` table exception; toast `'Acknowledgement could not be saved right now.'`; steps 2-5 do not run.

### Dismiss (False alarm) handler (`bin/onyx_telegram_ai_processor.dart:929-985`)

- **What it reads**: same as Acknowledge.
- **What it attempts to write**:
  1. `_updateEventRow(alertId, {status: 'false_alarm', resolved_at})`. Same non-existent `events` table.
  2. `_markSnapshotAlertHandled(removeAlert: true)` — drops the entry from `active_alerts`.
  3. `_recordAlertActionEvent(eventType: 'telegram_false_alarm')`.
  4. `_answerCallbackQuerySafe` with `'🔕 Marked as false alarm.'`.
  5. `_editAlertMessageForAction`.
- **What gets swallowed**: try/catch at `:935-983`; toast `'False alarm could not be saved right now.'`; steps 2-5 do not run.

### Shared helper — `_updateEventRow` (`bin/onyx_telegram_ai_processor.dart:1177-1208`)

Replaced in Phase B by a new helper `_upsertIncidentRow` (keyed on
`event_uid = alertId`; details in pseudocode §below). The existing
`_updateEventRow` is removed.

## Schema reads

### `public.incidents` table

(From `supabase/migrations/20260421000000_reverse_engineered_baseline.sql:3443-3493`
plus post-cutover additions in `20260423000107_capture_layer2_post_cutover_constraints.sql`
and constraint migrations `20260421000103`, `20260421000104`.)

Column highlights:

| Column | Type | Constraint |
|---|---|---|
| `id` | TEXT | `DEFAULT gen_random_uuid()` NOT NULL. PK. Default emits UUID-shaped text; handler can rely on the default and return `.select('id')` to get it. |
| `event_uid` | TEXT | Nullable in column definition, **UNIQUE** via `incidents_event_uid_unique` (`20260421000104:28`). This is the idempotency key. |
| `site_id` | TEXT | **NOT NULL** post-cutover (`20260423000107:83`). FK → `sites.site_id` RESTRICT. |
| `client_id` | TEXT | Nullable. FK → `clients.client_id` RESTRICT. |
| `status` | TEXT | `DEFAULT 'OPEN'` NOT NULL; **CHECK in ('detected','open','acknowledged','dispatched','on_site','secured','closed','false_alarm')** (`20260423000107:91-93`). Matches A3's locked vocabulary. |
| `priority` | TEXT | Nullable; **CHECK in ('critical','high','medium','low')** (`20260423000107:95-97`). |
| `risk_level` | TEXT | Nullable; CHECK in ('LOW','MEDIUM','HIGH','CRITICAL') (`20260423000107:99-101`). |
| `incident_type` | enum `public.incident_type` | **CHECK in ('technical_failure','breach','panic')** — no NULL (`20260421000103:40`). Must be populated on insert. |
| `acknowledged_at` | timestamptz | Nullable. **A3 column name matches.** |
| `acknowledged_by` | **UUID** | Nullable. **Type mismatch vs A3:** A3 assumed TEXT `'telegram:<operator>'`. UUID can hold NULL; operator identifier must go elsewhere (see §Idempotency strategy). |
| `dispatch_time` | timestamptz | Nullable. **A3 called this `dispatched_at`.** Real column is `dispatch_time`. |
| `resolution_time` | timestamptz | Nullable. **A3 called this `resolved_at`.** Real column is `resolution_time`. |
| `controller_notes` | TEXT | Nullable. Used by v2 PATCH for the false-alarm free-text. A3 matches. |
| `signal_received_at` | timestamptz | Nullable. A3 matches. |
| `description` | TEXT | Nullable. |
| `metadata` | JSONB | NOT NULL DEFAULT `'{}'`. Safe place to record operator-side audit info (telegram_user_id, chat_id, message_id, action timestamp). |
| `source` | TEXT | Nullable; CHECK in ('manual','news','social','ops') or NULL (`20260421000103:35`). Suggested value: `'ops'`. |
| `scope` | TEXT | DEFAULT `'AREA'` NOT NULL. |
| `action_code`, `category` | TEXT | Both nullable with CHECK constraints; set-null is fine. |
| `created_at`, `updated_at` | timestamptz | DEFAULTs exist; handler can omit. |

Trigger:
- `incidents_lock_closed_rows_before_update` (BEFORE UPDATE; `:6217`). Rejects mutation of rows with status='closed'. Handler is updating `dispatched`/`acknowledged`/`false_alarm` states, not `closed`, so the trigger doesn't fire on our path.

### `public.dispatch_intents` table

(From baseline `:2545-2563`.)

| Column | Type | Constraint |
|---|---|---|
| `dispatch_id` | UUID | `DEFAULT gen_random_uuid()` NOT NULL. PK. |
| `action_type` | TEXT | **NOT NULL.** |
| `risk_level` | TEXT | **NOT NULL, CHECK in ('LOW','MEDIUM','HIGH')**. |
| `risk_score` | double precision | **NOT NULL.** |
| `confidence` | double precision | **NOT NULL.** |
| `decision_trace` | JSONB | **NOT NULL.** |
| `geo_scope` | JSONB | **NOT NULL.** |
| `dcw_seconds` | integer | **NOT NULL.** |
| `decided_at` | timestamptz | **NOT NULL.** |
| `execute_after` | timestamptz | **NOT NULL.** |
| `ati_snapshot` | JSONB | **NOT NULL.** |
| `units`, `route_id`, `geo_lat`, `geo_lng` | nullable | — |
| `created_at` | timestamptz | DEFAULT `now()`. |

**Critical finding: there is no `incident_id` column on `dispatch_intents`.**
A3 said the handler should "insert a dispatch_intents row referencing the
incident", but no FK column exists today. Resolution: write the
`incident_id` into `decision_trace` JSONB (`decision_trace->'incident_id'`)
so the relationship is preserved without a schema change. See Idempotency
strategy for how this also powers duplicate-safety.

### `auto_decided_transition` trigger

(Baseline `:6201` wiring; body `:713-739`.)

```
AFTER INSERT ON dispatch_intents
FOR EACH ROW
EXECUTE FUNCTION create_initial_transition();

-- create_initial_transition():
insert into dispatch_transitions (
  dispatch_id, from_state, to_state,
  transition_reason, actor_type, actor_id
) values (
  NEW.dispatch_id, null, 'DECIDED',
  'INITIAL_DECISION', 'AI', 'SYSTEM'
);
```

Observations:
- Fires on every dispatch_intents insert — no conditional logic.
- Seeds `dispatch_transitions` with `to_state='DECIDED'`, `actor_type='AI'`, `actor_id='SYSTEM'`. **Telegram-driven dispatches will therefore appear as AI/SYSTEM actions, not HUMAN**. Fixing this is out-of-scope for Phase B (A3 doesn't ask for it); if the operator wants HUMAN actor recording, Phase B can additionally insert a second `dispatch_transitions` row with `from_state='DECIDED'`, `to_state='DECIDED'` and `actor_type='HUMAN'`. Flagged as Open Q3.

### `public.dispatch_transitions` table

(Baseline `:2569-2582`.)

Notable: `to_state` CHECK in `('DECIDED','COMMITTING','EXECUTED','ABORTED','OVERRIDDEN','FAILED')`; `actor_type` CHECK in `('AI','HUMAN','SYSTEM')`. Terminal states per A3 convention: `EXECUTED`, `ABORTED`, `OVERRIDDEN`, `FAILED`. Non-terminal: `DECIDED`, `COMMITTING`.

View `dispatch_current_state` (baseline `:2588-2609`) computes the latest state per dispatch via LATERAL join. Useful for duplicate-safety queries.

### `public.site_alarm_events` table

(Baseline `:4090-4102`; CHECK in `20260421000103:42-45`.)

| Column | Type | Constraint |
|---|---|---|
| `id` | UUID | DEFAULT gen_random_uuid() NOT NULL. |
| `site_id` | TEXT | NOT NULL. FK → sites.site_id. |
| `device_id` | TEXT | NOT NULL. |
| `event_type` | TEXT | **NOT NULL. CHECK in ('camera_worker_offline','false_alarm_cleared','armed_response_requested').** ← BLOCKER for Phase B audit logging. |
| `occurred_at` | timestamptz | NOT NULL. |
| `raw_payload` | JSONB | NOT NULL DEFAULT `'{}'`. |
| `zone_id`, `area_id`, `zone_name`, `area_name`, `armed_state` | nullable | — |

**The existing `_recordAlertActionEvent` helper writes event_type values like
`'telegram_view_camera'`, `'telegram_dispatch_requested'`,
`'telegram_acknowledged'`, `'telegram_false_alarm'`. All four violate the
CHECK constraint.** The View-camera path appears to work for the operator
only because the toast + `_sendCameraViewReply` run *before* the CHECK-failing
`_recordAlertActionEvent` call; the operator sees the snapshot URL toast,
but the site_alarm_events audit row never lands. This is a latent bug
unrelated to the Dispatch/Ack/False-alarm fix — but it's in the same helper
the A3 design reuses.

**This is the one decision Phase B needs from the operator before proceeding.**
See Open Q1 below.

### `public.site_awareness_snapshots` table

(Baseline `:4140-4151`.)

- `site_id` TEXT NOT NULL; `client_id` TEXT NOT NULL; `snapshot_at` timestamptz NOT NULL; `active_alerts` JSONB NOT NULL DEFAULT `'[]'`.
- `active_alerts` is the source of truth for the current unresolved alerts at a site. Each array entry is a JSON object that at minimum carries `alert_id` and `is_acknowledged` (visible in `_markSnapshotAlertHandled` at `:1235, :1244`); likely also `zone_name`, `channel_id`, `detected_at`, `alert_kind` based on the camera-worker snapshot shape. This is where the handler can source the richer context needed for a proper `incidents` upsert.

## `callback.alertId` provenance

(From `bin/onyx_camera_worker.dart:2211-2235`.)

```dart
String _compactAlertId({
  required String siteId,
  required String channelId,
  required DateTime detectedAt,
  required String variant,
}) {
  // Build compact tokens: siteToken (≤8), channelToken (≤3),
  // variantToken (≤4), timeToken = microsecondsSinceEpoch in base36.
  return 'al$siteToken$channelToken$variantToken$timeToken';
}
```

Observations:

- `alertId` is a **derived string**, not a row PK. Format example: `al{site-last-8}{ch-last-3}{variant}{micros-base36}`. Collisions essentially impossible (microseconds timestamp component).
- The string is stable per (site, channel, detection event, variant). Tapping the same button twice reproduces the same `alertId`.
- The alert is **not persisted to `site_alarm_events` by this compact id**. The camera worker stores alert context in `site_awareness_snapshots.active_alerts` (JSONB array, keyed internally by `alert_id`).
- Conclusion for the handler: **do NOT try to look up a source row in `site_alarm_events` using `alertId` — it won't be there**. Use `site_awareness_snapshots.active_alerts` as the context source instead. See Pseudocode §lookup step.

## Idempotency strategy

### Incidents upsert key

- **Recommended**: use existing column `incidents.event_uid` (TEXT, UNIQUE via `incidents_event_uid_unique`) to hold the `callback.alertId` value. Upsert via:
  ```
  .from('incidents')
    .upsert(values, onConflict: 'event_uid')
    .select('id')
    .single()
  ```
  The PostgREST Dart client supports `upsert(values, onConflict: <column>)`, returning the row. On first tap, a fresh `id` is generated by `gen_random_uuid()`; on repeat taps, the existing row is updated with the action's new fields.
- **Reasoning**: the UNIQUE constraint exists already (confirmed in both `20260421000104_add_unique_constraints.sql:28` and the live unique index `incidents_event_uid_unique_idx` at baseline `:5957`). No migration needed. `event_uid` is nullable at the column level so historical NULL rows stay valid; post-cutover only our new rows carry `event_uid = alertId`.
- **Migration needed**: **none** for the upsert key itself.

### Dispatch_intents duplicate-safety

- **Recommended**: before inserting a dispatch_intents row, query the `dispatch_current_state` view filtered by our incident reference, and skip if a non-terminal row exists:
  ```
  // Pseudocode: fetch any active dispatch for this incident
  final existing = await supabase.rpc('dispatch_active_for_incident', ...);
  // OR direct query:
  final existing = await supabase
    .from('dispatch_current_state')
    .select('dispatch_id, current_state')
    .contains('decision_trace', { 'incident_id': incidentId })
    .not('current_state', 'in', ['EXECUTED','ABORTED','OVERRIDDEN','FAILED'])
    .limit(1);
  if (existing.isNotEmpty) {
    // Already active; do not insert a second row.
    // Still run message-edit + snapshot ACK + callback-query answer.
    return skip;
  }
  ```
- **Reasoning**: dispatch_intents has no state column of its own; the state lives on the latest dispatch_transitions row. The `dispatch_current_state` view computes that for us. Filtering on `decision_trace->>'incident_id'` keeps the relationship local to the JSONB field (no schema change).
- **Migration needed**: **none**.

## Handler pseudocode

### Dispatch

```
Handler _handleDispatchCallback(update, target, callback, nowUtc):
  siteId = callback.siteId or target.siteId
  alertId = callback.alertId
  callbackId = update.callbackQueryId

  try:
    # Step 1: look up alert context from snapshot (best-effort)
    alertContext = lookupActiveAlert(siteId, alertId)
      # returns null if snapshot row missing or alert already cleared;
      # returns {zone_name, channel_id, detected_at, alert_kind, priority?}
      # otherwise.

    # Step 2: upsert the incidents row keyed on event_uid = alertId
    incidentRow = upsertIncidentRow(
      eventUid: alertId,
      siteId: siteId,
      status: 'dispatched',
      priority: alertContext.priority or 'medium',
      incidentType: 'breach',
      source: 'ops',
      scope: 'AREA',
      signalReceivedAt: alertContext.detectedAt or nowUtc,
      dispatchTime: nowUtc,              # NB: column is dispatch_time, not dispatched_at
      occurredAt: alertContext.detectedAt or nowUtc,
      description: 'Telegram dispatch: ' + (alertContext.zoneName or 'alert ' + alertId),
      zoneName: alertContext.zoneName,
      channel: alertContext.channelId,
      metadata: {                        # operator audit info lives here (acknowledged_by is UUID, can't hold 'telegram')
        telegram: {
          operator: telegramOperatorLabel(update),
          chat_id: update.chatId,
          message_id: update.messageId,
          action: 'dispatch',
          action_at: nowUtc,
        },
      },
    )
    incidentId = incidentRow.id

    # Step 3: duplicate-safety — skip dispatch_intents if one is already non-terminal
    existing = dispatchActiveForIncident(incidentId)
    if existing is None:
      # Step 4: insert dispatch_intents; auto_decided_transition trigger seeds dispatch_transitions
      insert dispatch_intents:
        action_type: 'armed_response',    # operator-chosen dispatch
        risk_level: mapRiskLevel(alertContext.priority, fallback: 'MEDIUM'),
        risk_score: alertContext.riskScore or 0.5,
        confidence: alertContext.confidence or 1.0,
        decision_trace: { incident_id: incidentId, source: 'telegram_button', alert_id: alertId, operator: <label> },
        geo_scope: {},                    # empty JSONB for site-level scope
        dcw_seconds: 0,
        decided_at: nowUtc,
        execute_after: nowUtc,
        ati_snapshot: { site_id: siteId, incident_id: incidentId },   # minimal
      # Trigger fires: dispatch_transitions row with to_state='DECIDED', actor_type='AI', actor_id='SYSTEM'.

    # Step 5: snapshot ACK (existing helper, unchanged semantics)
    markSnapshotAlertHandled(siteId, alertId, removeAlert: false)

    # Step 6: site_alarm_events audit log — SEE OPEN Q1 (CHECK constraint blocks current values)
    if auditLoggingEnabled:
      recordAlertActionEvent(siteId, channelId, eventType: 'telegram_dispatch_requested', rawPayload: {...})

    # Step 7: Telegram replies (existing helpers, unchanged)
    answerCallbackQuerySafe(callbackId, '🚨 Dispatch logged for $siteId. Guard notified.')
    editAlertMessageForAction(
      update,
      actionLine: '🚨 Dispatch logged by operator — ' + formatLocalTime(nowUtc),
      removeInlineKeyboard: true,
    )

  catch error:
    developer.log('Telegram dispatch callback failed.', error: error)
    answerCallbackQuerySafe(callbackId, 'Dispatch could not be logged right now.')
  return ''
```

Notes:
- `lookupActiveAlert` is a new helper factored out of the current `_markSnapshotAlertHandled` body — it reads `site_awareness_snapshots.active_alerts` and returns the matching map (or null). `_markSnapshotAlertHandled` is refactored to use the lookup internally.
- `upsertIncidentRow` is a new helper replacing the removed `_updateEventRow`.
- `dispatchActiveForIncident` is a new small helper querying `dispatch_current_state` via `decision_trace` JSONB filter.
- Order is: incidents first (UI truth surface), then dispatch_intents (action state machine). Matches A3 step order.

### Acknowledge

```
Handler _handleAcknowledgeCallback(update, target, callback, nowUtc):
  siteId = target.siteId
  alertId = callback.alertId
  callbackId = update.callbackQueryId

  try:
    alertContext = lookupActiveAlert(siteId, alertId)
    upsertIncidentRow(
      eventUid: alertId,
      siteId: siteId,
      status: 'acknowledged',
      priority: alertContext.priority or 'medium',
      incidentType: 'breach',
      source: 'ops',
      scope: 'AREA',
      signalReceivedAt: alertContext.detectedAt or nowUtc,
      acknowledgedAt: nowUtc,
      # acknowledged_by is UUID-typed — leave NULL and put operator label in metadata
      occurredAt: alertContext.detectedAt or nowUtc,
      description: 'Telegram ack: ' + (alertContext.zoneName or 'alert ' + alertId),
      zoneName: alertContext.zoneName,
      channel: alertContext.channelId,
      metadata: {
        telegram: { operator, chat_id, message_id, action: 'acknowledge', action_at: nowUtc },
      },
    )

    # No dispatch_intents row for ack per A3 Q2.

    markSnapshotAlertHandled(siteId, alertId, removeAlert: false)

    if auditLoggingEnabled:
      recordAlertActionEvent(siteId, channelId, eventType: 'telegram_acknowledged', rawPayload: {...})

    answerCallbackQuerySafe(callbackId, '✅ Acknowledged.')
    editAlertMessageForAction(
      update,
      actionLine: '✅ Acknowledged by operator — ' + formatLocalTime(nowUtc),
      removeInlineKeyboard: true,
    )

  catch error:
    developer.log('Telegram acknowledge callback failed.', error: error)
    answerCallbackQuerySafe(callbackId, 'Acknowledgement could not be saved right now.')
  return ''
```

### False alarm (dismiss)

```
Handler _handleDismissCallback(update, target, callback, nowUtc):
  siteId = target.siteId
  alertId = callback.alertId
  callbackId = update.callbackQueryId

  try:
    alertContext = lookupActiveAlert(siteId, alertId)
    upsertIncidentRow(
      eventUid: alertId,
      siteId: siteId,
      status: 'false_alarm',
      priority: alertContext.priority or 'medium',
      incidentType: 'breach',
      source: 'ops',
      scope: 'AREA',
      signalReceivedAt: alertContext.detectedAt or nowUtc,
      resolutionTime: nowUtc,           # NB: column is resolution_time, not resolved_at
      occurredAt: alertContext.detectedAt or nowUtc,
      controllerNotes: 'Marked as false alarm via Telegram operator action',
      description: 'Telegram false-alarm: ' + (alertContext.zoneName or 'alert ' + alertId),
      zoneName: alertContext.zoneName,
      channel: alertContext.channelId,
      metadata: {
        telegram: { operator, chat_id, message_id, action: 'false_alarm', action_at: nowUtc },
      },
    )

    # No dispatch_intents row for false alarm per A3 Q2.

    markSnapshotAlertHandled(siteId, alertId, removeAlert: true)   # clears the alert from the snapshot

    if auditLoggingEnabled:
      recordAlertActionEvent(siteId, channelId, eventType: 'telegram_false_alarm', rawPayload: {...})

    answerCallbackQuerySafe(callbackId, '🔕 Marked as false alarm.')
    editAlertMessageForAction(
      update,
      actionLine: '🔕 Marked as false alarm — ' + formatLocalTime(nowUtc),
      removeInlineKeyboard: true,
    )

  catch error:
    developer.log('Telegram false-alarm callback failed.', error: error)
    answerCallbackQuerySafe(callbackId, 'False alarm could not be saved right now.')
  return ''
```

## Estimated LOC for Phase B implementation

Target file: `bin/onyx_telegram_ai_processor.dart` only (per A3 Q5).

| Change | Estimated net LOC |
|---|---|
| Remove `_updateEventRow` | −32 |
| Add `_upsertIncidentRow` | +45 |
| Add `_lookupActiveAlert` (factored from `_markSnapshotAlertHandled`'s read logic) | +25 |
| Add `_dispatchActiveForIncident` | +20 |
| Rewrite `_handleDispatchCallback` | +15 (from ~60 to ~75, net +15) |
| Rewrite `_handleAcknowledgeCallback` | +5 |
| Rewrite `_handleDismissCallback` | +5 |
| Minor signature shift on `_markSnapshotAlertHandled` to use the extracted lookup | +3 |
| Import / helper glue | +5 |
| **Total estimated net LOC** | **+91** |

Migration LOC (if Q1 answered "migrate"): ~6 lines of SQL in a new file
`supabase/migrations/20260424XXXXXX_expand_site_alarm_events_event_type.sql`
plus ~2 lines into the drift-checker expectation table, if applicable.

If Q1 answered "skip site_alarm_events logging": no migration, and handler
pseudocode's `if auditLoggingEnabled` branches collapse (~−10 LOC from the
estimate above).

## Open questions

1. **`site_alarm_events.event_type` CHECK constraint violation (BLOCKER).**
   The existing `_recordAlertActionEvent` helper the A3 design reuses writes
   `event_type` values (`telegram_view_camera`, `telegram_dispatch_requested`,
   `telegram_acknowledged`, `telegram_false_alarm`) that all violate the
   post-cutover CHECK constraint `event_type IN ('camera_worker_offline',
   'false_alarm_cleared', 'armed_response_requested')`. Options:
   - **(a)** Write a targeted migration expanding the CHECK to allow the 4 telegram_* values (plus potentially `'telegram_view_camera'`). ~6 lines SQL, drift-checker compliant, preserves the Phase B audit log. **Recommended.**
   - **(b)** Drop site_alarm_events logging from the three button handlers entirely. No migration; audit info goes only into `incidents.metadata.telegram.*`. Trade: reduces the flat audit trail but isn't load-bearing for Workstream 1 exit criteria (which target `incidents`, `dispatch_intents`, `dispatch_transitions`).
   - **(c)** Repurpose existing allowed values — map `telegram_dispatch_requested → 'armed_response_requested'` (already permitted). No equivalent for ack/view/false_alarm. Asymmetric; not recommended.
   Which does the operator want?

2. **`incidents.client_id` population.** Column is nullable and FK-constrained to `clients.client_id` on RESTRICT. Handler options: (a) leave NULL; (b) look up `sites.client_id` for the site on each upsert. A3 didn't explicitly ask for client_id. **Recommended**: (a) leave NULL — simplest — and let a follow-up pass backfill if needed. Confirm?

3. **`dispatch_transitions` actor recording.** `auto_decided_transition` trigger hard-codes `actor_type='AI', actor_id='SYSTEM'`. If the operator wants Telegram-driven dispatches to appear as HUMAN actors, Phase B can additionally insert a second `dispatch_transitions` row (`from_state='DECIDED'`, `to_state='DECIDED'`, `actor_type='HUMAN'`, `actor_id='telegram:<operator>'`, `transition_reason='TELEGRAM_OPERATOR'`). Trade-off: two rows per dispatch rather than one; requires judgment on whether the trigger's AI/SYSTEM label is authoritative or augmentable. A3 did not specify. **Recommended**: leave the trigger-seeded row as-is for Phase B; defer actor-type refinement. Confirm?

4. **`incidents.acknowledged_by` type.** Column is UUID; A3 called for `'telegram:<operator>'` TEXT. Recommendation: leave `acknowledged_by = NULL`, put operator identifier in `incidents.metadata.telegram.operator`. Phase B code will follow this unless operator instructs otherwise. Confirm?

5. **Column name aliases in A3.** A3 used logical column names `dispatched_at` / `resolved_at` / `acknowledged_by = 'telegram:...'`. Actual schema: `dispatch_time` / `resolution_time` / `acknowledged_by` UUID. Phase B will use actual schema names. No operator action needed — flagging so the A3 doc reader can reconcile.

## Recommended next action

**Phase B requires operator answer on Q1 first.** Q2, Q3, Q4 have safe
defaults the Phase B implementation will adopt unless the operator objects
(the proposal is specific about those). Q5 is informational only.

Once Q1 is answered:
- If (a): Phase B ships +91 net LOC in `bin/onyx_telegram_ai_processor.dart` plus one ~6-line migration. Phase B scope widens slightly to include the migration under the Layer 1-Step 4-style append-only discipline.
- If (b): Phase B ships ~+80 net LOC in the handler file alone, no migration. site_alarm_events audit rows are dropped from the button handlers.

Either way, the A3 design maps cleanly onto the actual schema once Q1 is
settled — there is no structural impediment to implementing the three
write-path handlers against the canonical Layer 2 post-cutover tables.

---

*End of Phase B — Phase A investigation. Awaiting operator decision on Q1 before Phase B implementation.*

## Operator decisions (appended 2026-04-24)

All four open questions resolved. Phase B implementation is unblocked.

**Q1 — `site_alarm_events.event_type` CHECK constraint**: LOCKED to Option (a). Phase B includes one small migration expanding the CHECK to allow the four `telegram_*` event_types (`telegram_dispatch_requested`, `telegram_acknowledged`, `telegram_false_alarm`, `telegram_view_camera`).

Rationale:
- Preserves the `_recordAlertActionEvent` helper as a real audit trail rather than downgrading it into `incidents.metadata`.
- The discovered latent bug — View camera's audit-log side effect has ALSO been silently failing the same CHECK constraint — is fixed by the same migration. View camera remains a valid control for callback delivery and snapshot fan-out, but its `site_alarm_events` audit side effect was broken and should be named as part of the migration rationale.
- Migration adds ~6 SQL lines; drift-checker compliant; single file.

**Q2 — `dispatch_intents.client_id` on new inserts**: LOCKED to safe default. May stay NULL. Matches current pattern. FK deferred per Amendment 4.

**Q3 — Human-actor augmentation on `dispatch_transitions`**: LOCKED to safe default. No augmentation. Trigger-seeded rows are system rows; human actor is recorded on the originating `dispatch_intents` row and the `incidents` row, not on the trigger-generated transition.

**Q4 — `incidents.acknowledged_by` field**: LOCKED to safe default. Column is UUID-typed and incompatible with the string `"telegram:<operator>"`. Leave `acknowledged_by` NULL; place the operator identifier in `incidents.metadata.telegram.operator` (JSONB).

## Latent bug discovered during Phase B Phase A

Worth preserving in the audit trail: CC's investigation found that `_recordAlertActionEvent` has been writing `telegram_*` event_types to `site_alarm_events` since before today's work, and all such writes have silently failed the CHECK constraint (20260421000103:42-45 allows only `camera_worker_offline`, `false_alarm_cleared`, `armed_response_requested`). This includes the View camera audit log entries which we believed were landing.

Implication: our session's assumption that "View camera proves the callback pipeline is fully healthy" was partially wrong. Callback delivery works, snapshot fan-out works, but the audit-log side effect has been failing. Phase B's CHECK constraint migration closes this gap alongside the three write-path button fixes.

## Phase B implementation is unblocked

Phase B proper (CC investigation → implementation → deployment → verification) is the next session's work. Not tonight.

Next session plan:
1. CC investigates current handler code one more time and drafts the code-level implementation plan.
2. CC writes the migration SQL + rewritten handlers + tests.
3. Codex deploys (migration first, then Hetzner restart of `onyx-telegram-ai-processor.service`).
4. Operator verifies by tapping buttons and observing DB writes.

## Phase B/C resolution note (appended 2026-04-25)

Phase B/C completed at commit `548c254` (`feat(telegram): rewire action buttons to canonical post-cutover schema`).

Live deployment summary:
- Migration `20260424180000_expand_site_alarm_events_event_type_for_telegram.sql` applied to Supabase on 2026-04-25 at approximately 05:25 UTC and verified live via `pg_get_constraintdef`.
- Hetzner deployment completed after pre-flight backup, source SHA verification, binary swap, and clean service restart validation.

Three live-verification hotfixes landed during Phase C:
1. `_failActionToast` now calls `_logError(...)` before `developer.log(...)` so callback failures surface to journald in the compiled binary.
2. `_upsertIncidentRow` now populates `incidents.client_id` from `target.clientId`; this cleared the live `NOT NULL` violation on `public.incidents.client_id`.
3. `_dispatchActiveForIncident` now queries `dispatch_intents` for `decision_trace.incident_id` and then `dispatch_current_state` for current state by `dispatch_id`; this replaced the broken direct filter on a nonexistent `dispatch_current_state.decision_trace` column.

Live verification outcomes:
- `Dispatch` verified end to end: `incidents`, `dispatch_intents`, `dispatch_transitions`, and `site_alarm_events` all returned the expected rows for the tapped alert.
- `Acknowledge` verified end to end: `incidents.status='acknowledged'`, `acknowledged_at`, `client_id`, and the matching `telegram_acknowledged` `site_alarm_events` row all landed as expected.
- `False alarm` verified end to end: `incidents.status='false_alarm'`, `resolution_time`, canonical `controller_notes`, `client_id`, and the matching `telegram_false_alarm` `site_alarm_events` row all landed as expected.
- `View camera` remained operational throughout and the latent audit-log failure on its `site_alarm_events` side effect was fixed as a direct side effect of the CHECK-constraint migration.

## Small follow-up noted during verification

`telegram_acknowledged` rows in `site_alarm_events.raw_payload` currently carry `incident_id = NULL` even though the corresponding `incidents` row exists. `telegram_dispatch_requested` rows do propagate `incident_id`. This is a minor consistency gap, not a blocker for Workstream 1 button functionality, and should be tracked as a small follow-up.

## Scope closure

Workstream 1 button-fix scope is closed. Telegram action buttons are now functional in production against the canonical post-cutover schema.

Deferred follow-ups remain open:
- Automated promotion from alert telemetry into incidents remains a separate deferred Workstream 1 follow-up.
- Test infrastructure for Telegram handler database interactions remains backlog; this session relied on live verification rather than a substantial Supabase fake fixture build-out.
- The misleading `_pollOnce` log line (`Sending row ... to AI/reply builder...`) still names the callback path imprecisely; cosmetic cleanup only.
