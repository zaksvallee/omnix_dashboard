# Audit: Drift Migration Plan — DispatchPersistenceService

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/application/dispatch_persistence_service.dart` — all SharedPreferences keys and blob structures
- Read-only: yes

---

## Executive Summary

`DispatchPersistenceService` holds **56 distinct SharedPreferences keys** spanning UI
preferences, typed domain collections, singleton state objects, opaque JSON blobs, and a
dynamic scoped-key scheme for per-client conversations. The surface is large and varied
enough that migration to Drift requires three separate tracks: (A) trivial scalar/enum
preferences that may not warrant Drift at all, (B) typed collections that map cleanly to
Drift tables, and (C) untyped `Map<String, Object?>` blobs that require schema
investigation before normalization is possible.

Three structural risks compound the migration: silent data loss on any parse failure, a
manually tracked scoped-key registry that can drift out of sync, and blob contents that
carry no internal version field despite the `_v1` key suffix.

---

## What Looks Good

- Every read method guards against null, empty, wrong JSON type, and parse exceptions before
  returning a safe default. Consistent defensive posture.
- `_registerClientConversationScope` auto-registers scoped keys into the registry at write
  time, preventing the scope registry from falling behind writes.
- `_v1` suffix on every key provides a clean rename path for any future breaking schema
  change without requiring a migration — old key is simply abandoned.
- `toList(growable: false)` used consistently on read paths, preventing accidental in-place
  mutation of persisted collections.
- The `readOperatorId` / `saveOperatorId` pair is the simplest possible shape — a single
  string, no JSON encoding — easiest thing to migrate.

---

## Complete Key Inventory

### Category A — UI Preferences and Session Flags (11 keys)

These store enums-by-name, bools, or simple filter strings. They are ephemeral: losing them
on migration only resets a UI preference, not operational data.

| # | Key constant | SharedPreferences key | Type stored | Notes |
|---|---|---|---|---|
| 1 | `monitoringIdentityRuleAuditExpandedKey` | `onyx_monitoring_identity_rule_audit_expanded_v1` | `bool` | native `setBool` |
| 2 | `tacticalWatchActionDrilldownKey` | `onyx_tactical_watch_action_drilldown_v1` | `String` (enum `.name`) | `VideoFleetWatchActionDrilldown` |
| 3 | `dispatchWatchActionDrilldownKey` | `onyx_dispatch_watch_action_drilldown_v1` | `String` (enum `.name`) | same enum |
| 4 | `adminWatchActionDrilldownKey` | `onyx_admin_watch_action_drilldown_v1` | `String` (enum `.name`) | same enum |
| 5 | `adminPageTabKey` | `onyx_admin_page_tab_v1` | `String` (enum `.name`) | `AdministrationPageTab` |
| 6 | `monitoringIdentityRuleAuditSourceFilterKey` | `onyx_monitoring_identity_rule_audit_source_filter_v1` | `String` (enum persistence key) | `MonitoringIdentityPolicyAuditSource` |
| 7 | `guardSyncHistoryFilterKey` | `onyx_guard_sync_history_filter_v1` | `String` | raw filter label |
| 8 | `guardSyncOperationModeFilterKey` | `onyx_guard_sync_operation_mode_filter_v1` | `String` | raw mode name |
| 9 | `guardSyncSelectedFacadeIdKey` | `onyx_guard_sync_selected_facade_id_v1` | `String` | raw ID |
| 10 | `guardSyncSelectedOperationIdsKey` | `onyx_guard_sync_selected_operation_ids_v1` | `Map<String, String>` | filter→operationId |
| 11 | `morningSovereignReportAutoRunKey` | `onyx_morning_sovereign_report_auto_run_key_v1` | `String` | last auto-run key |

**Drift table schema (Category A):**

These do not justify individual Drift tables. The recommended pattern is a single key-value
table used by all Category A entries:

```
// Drift table (pseudocode, not implementation)
class AppPreferences extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}
```

All 11 keys map to rows in `app_preferences`. Reading is a single `SELECT value WHERE key =
?`. Because the data is ephemeral, no migration of existing SharedPreferences data is
required — the Drift read path can fall back to SharedPreferences on first boot, write the
value into Drift, then clear the SharedPreferences key.

**Migration risk:** Low. Worst case: UI resets to default on first Drift boot.

---

### Category B — Scalar Identity and Operator State (9 keys)

These store strings that identify the current operator or capture a transient string state
(pending action details, audit summary). Not JSON-encoded.

| # | Key constant | SharedPreferences key | Type stored |
|---|---|---|---|
| 12 | `operatorIdKey` | `onyx_operator_id_v1` | `String` |
| 13 | `radioIntentPhrasesJsonKey` | `onyx_radio_intent_phrases_json_v1` | `String` (opaque JSON) |
| 14 | `monitoringIdentityRulesJsonKey` | `onyx_monitoring_identity_rules_json_v1` | `String` (opaque JSON) |
| 15 | `pendingRadioQueueManualActionDetailKey` | `onyx_pending_radio_queue_manual_action_detail_v1` | `String` |
| 16 | `pendingRadioQueueFailureSnapshotKey` | `onyx_pending_radio_queue_failure_snapshot_v1` | `String` |
| 17 | `pendingRadioQueueFailureAuditDetailKey` | `onyx_pending_radio_queue_failure_audit_detail_v1` | `String` |
| 18 | `pendingRadioQueueStateChangeDetailKey` | `onyx_pending_radio_queue_state_change_detail_v1` | `String` |
| 19 | `monitoringWatchAuditSummaryKey` | `onyx_monitoring_watch_audit_summary_v1` | `String` |
| 20 | `monitoringIdentityRuleAuditSourceFilterKey` | *(listed above)* | *(moved to Cat A)* |

**Drift table schema (Category B):**

`operatorId` warrants its own row in `AppPreferences` (key = `operator_id`, value = the id).

`radioIntentPhrasesJsonKey` and `monitoringIdentityRulesJsonKey` are opaque JSON strings
loaded from an external config source. Store as `TEXT` in a dedicated singleton table:

```
class ConfigBlobs extends Table {
  TextColumn get configKey => text()();
  TextColumn get rawJson => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {configKey};
}
```

The 4 radio queue detail strings are transient state attached to a queue session.
Fold them into the `PendingRadioQueue` table (Category C) as nullable text columns
on a singleton row rather than separate keys.

**Migration risk:** Low. `operatorId` is the only one that is load-bearing for identity;
must be migrated before any auth-dependent reads attempt to run.

---

### Category C — Typed Domain Collections (10 keys + scoped variants)

These store structs or lists of structs with `fromJson` / `toJson`. They map cleanly to
Drift tables with proper columns.

#### C1 — `offlineIncidentSpoolEntriesKey` (line 1274)
- **Key:** `onyx_offline_incident_spool_entries_v1`
- **Stored:** `List<OfflineIncidentSpoolEntry>` — validated: `entryId`, `incidentReference`,
  `siteId` must all be non-empty
- **Drift schema:**
  ```
  class OfflineIncidentSpoolEntries extends Table {
    TextColumn get entryId => text()();
    TextColumn get incidentReference => text()();
    TextColumn get siteId => text()();
    TextColumn get payloadJson => text()();  // remaining fields until domain is fully modelled
    DateTimeColumn get createdAt => dateTime()();
    @override
    Set<Column> get primaryKey => {entryId};
  }
  ```
- **Migration risk:** **CRITICAL.** Offline incidents may represent data that has not yet
  synced to Supabase. Silent loss during migration means lost incident records. Must be
  migrated with a read-before-write verify loop: read from SharedPreferences → write to
  Drift → confirm row count matches → only then clear SharedPreferences key.

#### C2 — `offlineIncidentSpoolSyncStateKey` (line 1314)
- **Key:** `onyx_offline_incident_spool_sync_state_v1`
- **Stored:** `OfflineIncidentSpoolSyncState` — singleton typed object
- **Drift schema:** Singleton row pattern in `SyncStates` table (see below) or a dedicated
  one-row table.
- **Migration risk:** Medium. Loss resets sync cursor; spool may re-submit already-synced
  entries if cursor is gone. Requires idempotency in the sync path.

#### C3 — `guardAssignmentsKey` (line 1411)
- **Key:** `onyx_guard_assignments_v1`
- **Stored:** `List<GuardAssignment>` — validated: `assignmentId`, `dispatchId` non-empty
- **Drift schema:**
  ```
  class GuardAssignments extends Table {
    TextColumn get assignmentId => text()();
    TextColumn get dispatchId => text()();
    TextColumn get payloadJson => text()();
    @override
    Set<Column> get primaryKey => {assignmentId};
  }
  ```
- **Migration risk:** Medium-high. Guard assignments drive operational dispatch. Loss means
  operators lose context for in-progress assignments.

#### C4 — `guardSyncOperationsKey` (line 1447)
- **Key:** `onyx_guard_sync_operations_v1`
- **Stored:** `List<GuardSyncOperation>` — validated: `operationId` non-empty
- **Drift schema:**
  ```
  class GuardSyncOperations extends Table {
    TextColumn get operationId => text()();
    TextColumn get payloadJson => text()();
    @override
    Set<Column> get primaryKey => {operationId};
  }
  ```
- **Migration risk:** Medium. Sync operations are recoverable from server on next sync but
  local state represents un-committed work.

#### C5 — `pendingRadioAutomatedResponsesKey` (line 463)
- **Key:** `onyx_pending_radio_automated_responses_v1`
- **Stored:** `List<RadioAutomatedResponse>` — validated: `transmissionId`, `message`
  non-empty
- **Drift schema:**
  ```
  class PendingRadioResponses extends Table {
    TextColumn get transmissionId => text()();
    TextColumn get message => text()();
    TextColumn get payloadJson => text()();
    IntColumn get retryCount => integer().withDefault(const Constant(0))();
    DateTimeColumn get lastAttemptAt => dateTime().nullable()();
    @override
    Set<Column> get primaryKey => {transmissionId};
  }
  ```
- **Migration risk:** Medium. Undelivered automated responses will be silently dropped.
  The separate retry state key (C6 below) must be migrated atomically with this one.

#### C6 — `pendingRadioAutomatedResponsesRetryStateKey` (line 504)
- **Key:** `onyx_pending_radio_automated_responses_retry_state_v1`
- **Stored:** `Map<String, Map<String, Object?>>` — outer key is response key / transmission
  ID, inner map is untyped retry metadata
- **Drift schema:** Fold retry metadata columns directly into `PendingRadioResponses` (C5)
  as `retryCount`, `lastAttemptAt`, and a `retryMetaJson TEXT` overflow column. The current
  two-key structure represents artificial split between a record and its retry state.
- **Migration risk:** Medium. This split is a structural smell — see Findings below.

#### C7 — `clientConversationScopeRegistry` + scoped keys (line 796, 829–1063)
- **Global key:** `onyx_client_conversation_scope_registry_v1`  
  Stores `List<String>` of scope keys in format `{clientId}|{siteId}`.
- **Scoped keys:** Dynamic keys constructed as:
  ```
  {baseKey}::{clientId}|{siteId}
  ```
  for four base keys:
  - `onyx_client_app_messages_v1` → `List<ClientAppMessage>`
  - `onyx_client_app_acks_v1` → `List<ClientAppAcknowledgement>`
  - `onyx_client_app_push_queue_v1` → `List<ClientAppPushDeliveryItem>`
  - `onyx_client_app_push_sync_state_v1` → `ClientPushSyncState`
- **Global (unscoped) variants of the same 4 keys also exist** and are operated on
  independently at lines 666–793. This creates a dual-path read pattern where both the
  global key and the scoped key may hold messages for overlapping scopes. The interaction
  is unclear without tracing all callers.
- **Drift schema:**
  ```
  class ClientConversations extends Table {
    TextColumn get clientId => text()();
    TextColumn get siteId => text()();
    TextColumn get scopeKey => text().generatedAs(
      clientId + const Constant('|') + siteId)();
    @override
    Set<Column> get primaryKey => {clientId, siteId};
  }

  class ClientMessages extends Table {
    IntColumn get id => integer().autoIncrement()();
    TextColumn get clientId => text()();
    TextColumn get siteId => text()();
    TextColumn get body => text()();
    TextColumn get payloadJson => text()();
    // FK → ClientConversations(clientId, siteId)
  }

  class ClientAcknowledgements extends Table {
    TextColumn get messageKey => text()();
    TextColumn get clientId => text()();
    TextColumn get siteId => text()();
    TextColumn get payloadJson => text()();
    @override
    Set<Column> get primaryKey => {messageKey};
  }

  class ClientPushQueue extends Table {
    TextColumn get messageKey => text()();
    TextColumn get clientId => text()();
    TextColumn get siteId => text()();
    TextColumn get payloadJson => text()();
    @override
    Set<Column> get primaryKey => {messageKey};
  }

  class ClientPushSyncStates extends Table {
    TextColumn get clientId => text()();
    TextColumn get siteId => text()();
    TextColumn get stateJson => text()();
    @override
    Set<Column> get primaryKey => {clientId, siteId};
  }
  ```
- **Migration risk:** **HIGH.** Two compounding risks:
  1. The scope registry must be enumerated first to discover all dynamic keys. If any scope
     key was written before `_registerClientConversationScope` was in place (or if registration
     was skipped on a crash), orphaned keys exist in SharedPreferences with no registry entry.
     These will not be migrated.
  2. The existence of both global and scoped variants of the same 4 keys is unresolved. Before
     migration, a full audit of which callers use which read path is required (DECISION item).

#### C8 — `monitoringIdentityRuleAuditHistoryKey` (line 276)
- **Key:** `onyx_monitoring_identity_rule_audit_history_v1`
- **Stored:** `List<MonitoringIdentityPolicyAuditRecord>` — filtered: `message` non-empty
- **Drift schema:**
  ```
  class IdentityRuleAuditHistory extends Table {
    IntColumn get id => integer().autoIncrement()();
    TextColumn get message => text()();
    TextColumn get payloadJson => text()();
    DateTimeColumn get recordedAt => dateTime()();
  }
  ```
- **Migration risk:** Low-medium. Audit history loss is observable but not operationally
  blocking.

#### C9 — `newsSourceDiagnosticsKey` (line 212)
- **Key:** `onyx_dispatch_news_source_diagnostics_v1`
- **Stored:** `List<NewsSourceDiagnostic>` — filtered: `provider` non-empty
- **Drift schema:**
  ```
  class NewsSourceDiagnostics extends Table {
    TextColumn get provider => text()();
    TextColumn get payloadJson => text()();
    DateTimeColumn get updatedAt => dateTime()();
    @override
    Set<Column> get primaryKey => {provider};
  }
  ```
- **Migration risk:** Low. Diagnostics are regenerated on next news poll.

#### C10 — Singleton typed objects
Four keys store singleton domain objects (one instance ever):

| Key constant | SharedPreferences key | Type | Notes |
|---|---|---|---|
| `intakeTelemetryKey` | `onyx_dispatch_intake_telemetry_v1` | `IntakeTelemetry` | |
| `stressProfileKey` | `onyx_dispatch_stress_profile_v1` | `DispatchProfileDraft` | **naming mismatch** — key says "stress" but stores `DispatchProfileDraft` |
| `clientAppDraftKey` | `onyx_client_app_draft_v1` | `ClientAppDraft` | |
| `clientAppPushSyncStateKey` (global) | `onyx_client_app_push_sync_state_v1` | `ClientPushSyncState` | global fallback path |

**Drift schema:** Single-row tables or rows in a `SingletonStates` table:
```
class SingletonStates extends Table {
  TextColumn get stateKey => text()();
  TextColumn get stateJson => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {stateKey};
}
```

- **Migration risk:** Medium for `intakeTelemetryKey` (active dispatch telemetry), low for
  the others (drafts and push sync state are recoverable).

#### C11 — `monitoringWatchAuditHistoryKey` and `livePollHistoryKey`

| Key constant | SharedPreferences key | Type |
|---|---|---|
| `monitoringWatchAuditHistoryKey` | `onyx_monitoring_watch_audit_history_v1` | `List<String>` |
| `livePollHistoryKey` | `onyx_dispatch_live_poll_history_v1` | `List<String>` |

**Drift schema:** Store as `TEXT` (JSON array) in `SingletonStates` — not worth individual
tables for unkeyed string lists unless ordering or indexing is needed.

- **Migration risk:** Low. History strings are display-only.

---

### Category D — Opaque JSON Blobs (18 keys)

These all use `Map<String, Object?>` with no typed domain model. Internal structure is
unknown without reading the writers.

| # | Key constant | SharedPreferences key | Notes |
|---|---|---|---|
| D1 | `livePollSummaryKey` | `onyx_dispatch_live_poll_summary_v1` | poll run summary |
| D2 | `opsIntegrationHealthSnapshotKey` | `onyx_ops_integration_health_snapshot_v1` | ops health |
| D3 | `telegramAdminRuntimeStateKey` | `onyx_telegram_admin_runtime_state_v1` | telegram session |
| D4 | `monitoringWatchRuntimeStateKey` | `onyx_monitoring_watch_runtime_state_v1` | watch session |
| D5 | `monitoringWatchRecoveryStateKey` | `onyx_monitoring_watch_recovery_state_v1` | recovery cursor |
| D6 | `monitoringSceneReviewStateKey` | `onyx_monitoring_scene_review_state_v1` | scene review |
| D7 | `guardOutcomeGovernanceTelemetryKey` | `onyx_guard_outcome_governance_telemetry_v1` | governance |
| D8 | `guardCoachingPromptSnoozesKey` | `onyx_guard_coaching_prompt_snoozes_v1` | snooze map |
| D9 | `guardCoachingTelemetryKey` | `onyx_guard_coaching_telemetry_v1` | coaching stats |
| D10 | `guardCloseoutPacketAuditKey` | `onyx_guard_closeout_packet_audit_v1` | closeout audit |
| D11 | `guardShiftReplayAuditKey` | `onyx_guard_shift_replay_audit_v1` | shift replay |
| D12 | `guardSyncReportAuditKey` | `onyx_guard_sync_report_audit_v1` | sync report |
| D13 | `guardExportAuditClearMetaKey` | `onyx_guard_export_audit_clear_meta_v1` | export clear |
| D14 | `offlineIncidentSpoolReplayAuditKey` | `onyx_offline_incident_spool_replay_audit_v1` | spool replay |
| D15 | `onyxAgentCameraAuditHistoryKey` | `onyx_agent_camera_audit_history_v1` | `List<Map<...>>` |
| D16 | `onyxAgentThreadSessionStateKey` | `onyx_agent_thread_session_state_v1` | AI thread |
| D17 | `morningSovereignReportKey` | `onyx_morning_sovereign_report_v1` | current report |
| D18 | `morningSovereignReportHistoryKey` | `onyx_morning_sovereign_report_history_v1` | `List<Map<...>>` |

**Drift schema for all Category D:**

Store as raw `TEXT` (JSON) in `ConfigBlobs` or `SingletonStates` tables:
```
// row per key, value = raw jsonEncode output, same as today
// No structural gain from Drift until internal schemas are excavated
```

Attempting to normalize untyped blobs without reading the producer code is unsafe —
the schema may contain sub-maps, nullable fields, or version flags that only appear under
specific runtime paths.

- **Migration risk:** Varies. D3 (`telegramAdminRuntimeState`) and D4/D5
  (`monitoringWatchRuntimeState`, `monitoringWatchRecoveryState`) hold active session
  cursors — loss causes a watch restart but not data loss. D8 (`guardCoachingPromptSnoozes`)
  loss resets snooze timers (minor UX). D15 and D18 (camera/morning report history) are
  display artifacts with no operational consequence.

---

## Findings

### P1 — Global vs. Scoped Client Conversation Dual-Path Ambiguity
- **Action:** DECISION
- **Finding:** Four keys (`clientAppMessages`, `clientAppAcknowledgements`, `clientAppPushQueue`,
  `clientAppPushSyncState`) exist in both a global (unscoped) form (lines 666–793) and a
  scoped form keyed by `clientId|siteId` (lines 829–1063). It is unclear whether the global
  variants are deprecated, a fallback, or a separate concern.
- **Why it matters:** A migration that preserves scoped keys but not global keys (or vice
  versa) will silently drop data for whichever path is live. Neither path documents its
  intended lifecycle.
- **Evidence:** `clientAppMessagesKey` declared at line 53; global `readClientAppMessages`
  at line 666; scoped `readScopedClientAppMessages` at line 829. Both compile and have no
  deprecation annotation.
- **Follow-up:** Codex must trace all call sites of both global and scoped variants to
  determine whether they can be merged or which one is authoritative before any migration
  step touches these keys.

### P1 — Orphaned Scope Keys Cannot Be Enumerated Safely
- **Action:** REVIEW
- **Finding:** The scoped key discovery path depends entirely on `clientConversationScopeRegistryKey`
  (line 796). If any scoped write happened before `_registerClientConversationScope` existed
  or on a crash between the scope write and the registry update, keys exist in SharedPreferences
  with no registry entry. Drift migration will miss them.
- **Why it matters:** Silent data loss of client conversation history for affected scopes.
- **Evidence:** `_registerClientConversationScope` at line 1132. The registry read and write
  are not atomic — a crash between lines 1146 and 1147 leaves the scope unregistered.
- **Follow-up:** Before migration, run a SharedPreferences key enumeration pass (using
  `prefs.getKeys()`) and cross-reference against the registry to find orphaned scopes.

### P1 — Silent Data Destruction on Parse Failure
- **Action:** REVIEW
- **Finding:** Every `catch (_)` block in read methods calls `clear*()` on the key before
  returning an empty/null default (e.g., lines 125–127, 150–152, 230, 292, etc.). During
  migration, if Drift is introduced alongside SharedPreferences with a dual-read path, any
  transient decode error (e.g., a partial write caught mid-startup) permanently destroys
  the only copy of the data.
- **Why it matters:** The current behavior is safe only when SharedPreferences is the sole
  store. It becomes destructive if Drift is reading the same blob concurrently, or if a
  migration script causes a re-parse of a partially migrated key.
- **Evidence:** Pattern appears at ~25 locations throughout the file.
- **Follow-up:** Migration scripts must operate in read-then-clear order, never clear-then-read.
  The `catch → clear` pattern in read methods should be suppressed or replaced with a
  non-destructive error log during the migration window.

### P2 — Radio Response and Retry State Are Artificially Split
- **Action:** AUTO
- **Finding:** `pendingRadioAutomatedResponsesKey` and `pendingRadioAutomatedResponsesRetryStateKey`
  represent the same logical entity (a pending radio response and its retry metadata) stored
  across two separate keys. There is no atomicity guarantee between them — a crash between
  the two writes leaves them out of sync.
- **Why it matters:** A retry count may reference a transmissionId that no longer exists in
  the responses list (or vice versa). In Drift, this split should be collapsed into a single
  table with retry columns on the response row.
- **Evidence:** Lines 39–41 (key declarations), lines 463–536 (read/write methods).
- **Follow-up:** Codex should validate that no callers update only one of the two keys in
  isolation.

### P2 — `stressProfileKey` Name Mismatch
- **Action:** AUTO
- **Finding:** `stressProfileKey` (line 17) stores a `DispatchProfileDraft`, not a stress
  profile. The key string is `onyx_dispatch_stress_profile_v1`.
- **Why it matters:** Naming confusion at the persistence layer creates read errors if a
  developer creates a separate "stress profile" concept and reuses the existing key name.
- **Evidence:** Line 17 (key declaration), lines 1832–1853 (read/write methods with
  `DispatchProfileDraft`).
- **Follow-up:** Rename to `dispatchProfileDraftKey` in Drift migration.
  The `_v1` suffix allows abandoning the old key without a migration.

### P3 — 18 Untyped Blobs Block Normalization
- **Action:** DECISION
- **Finding:** 18 keys store `Map<String, Object?>` with no domain model. These cannot be
  safely normalized into typed Drift columns without first reading the producers and
  constructing typed domain objects.
- **Why it matters:** Migrating them as raw `TEXT` to Drift provides zero structural benefit.
  Migrating them without schema knowledge risks data loss through missed fields.
- **Evidence:** Category D inventory above.
- **Follow-up:** Each blob needs a dedicated schema excavation audit before migration.
  Priority order for excavation: D4 (monitoring watch runtime), D3 (telegram admin), D8
  (coaching snoozes), D5 (watch recovery) — these are most likely to have hidden temporal
  state that blocks recovery if lost.

---

## Duplication

- `readMonitoringWatchRuntimeState` / `readTelegramAdminRuntimeState` / `readMonitoringSceneReviewState`
  / `readLivePollSummary` / `readOpsIntegrationHealthSnapshot` and 13 others all have the
  same body shape:
  ```dart
  final raw = prefs.getString(someKey);
  if (raw == null || raw.isEmpty) return const {};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const {};
    return decoded.map((key, value) => MapEntry(key.toString(), value as Object?));
  } catch (_) {
    await clear*();
    return const {};
  }
  ```
  This pattern repeats ~13 times across the file. A generic
  `Future<Map<String, Object?>> _readJsonMap(String key, Future<void> Function() onError)`
  helper would eliminate the duplication — but this is an implementation concern for Codex,
  not a migration blocker.
- Files involved: `dispatch_persistence_service.dart` lines 164–210, 615–641, 1065–1086,
  1150–1173, 1241–1272, etc.

---

## Coverage Gaps

- No test verifies the scoped key registry recovery path (orphaned scope detection).
- No test exercises the `catch → clear` path to confirm the correct key is cleared (as
  opposed to all keys being cleared or no key being cleared on certain parse errors).
- No test covers the dual-read path (global vs. scoped) for client conversation keys.
- No migration smoke test exists to validate read-then-write fidelity for any key.

---

## Performance / Stability Notes

- **Scope registry write-amplification:** Every scoped conversation write calls
  `_registerClientConversationScope` (line 864, 926, 985, 1041), which reads the full
  registry list, deserializes it, checks for membership, and rewrites it if the scope is
  new. For long-lived sessions with many clients, this is O(n) on every write. In Drift,
  a proper FK relationship removes this entirely.
- **Whole-list JSON rewrites:** All list keys (`offlineIncidentSpoolEntries`,
  `guardAssignments`, `pendingRadioAutomatedResponses`, etc.) are fully re-serialized and
  re-written on every mutation. For lists that grow (audit histories, spool entries), this
  becomes progressively expensive. Drift row-level inserts eliminate this.
- **No size bound on any list key.** `monitoringWatchAuditHistory`, `livePollHistory`,
  `morningSovereignReportHistory`, `onyxAgentCameraAuditHistory`, and
  `monitoringIdentityRuleAuditHistory` can grow without bound until SharedPreferences
  hits platform write limits.

---

## Recommended Migration Order

### Phase 0 — Pre-migration prerequisites (DECISION blocks)
1. Resolve global vs. scoped client conversation key ambiguity (P1 finding above).
2. Audit all call sites for each of the 4 duplicated global/scoped key pairs.
3. Run `prefs.getKeys()` enumeration to find orphaned scope keys not in the registry.

### Phase 1 — Foundational (lowest risk, zero operational dependency)
1. `operatorIdKey` → `AppPreferences` row. Single string, foundational identity.
2. All 11 Category A UI preferences → `AppPreferences` rows. Ephemeral; loss is cosmetic.
3. Category B scalar strings (radio queue detail strings, audit summary) → `AppPreferences`
   or `SingletonStates` rows.

### Phase 2 — Operational collections (migrate with read-verify-clear discipline)
4. `offlineIncidentSpoolEntriesKey` + `offlineIncidentSpoolSyncStateKey` — together, atomic.
   **Must use read-verify-clear; never clear-before-verify.**
5. `guardAssignmentsKey` — operational dispatch context.
6. `guardSyncOperationsKey` — in-flight sync operations.
7. `pendingRadioAutomatedResponsesKey` + `pendingRadioAutomatedResponsesRetryStateKey` —
   migrate together, collapse into single `PendingRadioResponses` table.

### Phase 3 — Client conversation lane (after Phase 0 resolution)
8. Enumerate all scopes from registry + orphan scan.
9. Migrate scoped messages, acks, pushQueue, pushSyncState into `ClientMessages`,
   `ClientAcknowledgements`, `ClientPushQueue`, `ClientPushSyncStates` tables.
10. Resolve fate of global unscoped variants.

### Phase 4 — Typed singleton objects
11. `intakeTelemetryKey` → `SingletonStates`.
12. `stressProfileKey` (rename to `dispatchProfileDraftKey`) → `SingletonStates`.
13. `clientAppDraftKey` → `SingletonStates`.
14. `clientAppPushSyncStateKey` (global) → `ClientPushSyncStates` with `clientId = '__global__'`
    or deprecate after Phase 3.

### Phase 5 — Typed history and diagnostic lists
15. `monitoringIdentityRuleAuditHistoryKey` → `IdentityRuleAuditHistory` table.
16. `newsSourceDiagnosticsKey` → `NewsSourceDiagnostics` table.
17. `monitoringWatchAuditHistoryKey`, `livePollHistoryKey` → `SingletonStates` as JSON TEXT.

### Phase 6 — Config JSON blobs
18. `radioIntentPhrasesJsonKey`, `monitoringIdentityRulesJsonKey` → `ConfigBlobs` table.

### Phase 7 — Opaque blobs (after per-blob schema excavation)
19–36. Each Category D key individually, only after its internal schema has been audited
    and a typed Drift representation confirmed.
    Priority within Phase 7: D4 → D3 → D5 → D8 → D7 → remainder.

---

## Summary Table

| Category | Key count | Migration priority | Risk level |
|---|---|---|---|
| A — UI preferences | 11 | Phase 1 | Low |
| B — Scalar strings | 9 | Phase 1 | Low–Medium |
| C1 — Offline incident spool | 2 | Phase 2 (first) | **Critical** |
| C2 — Guard operations | 2 | Phase 2 | Medium-High |
| C3 — Radio pending queue | 2 | Phase 2 | Medium |
| C4 — Client conversations | 5+ scoped | Phase 3 | **High** |
| C5 — Typed singletons | 4 | Phase 4 | Medium |
| C6 — Typed history lists | 5 | Phase 5 | Low–Medium |
| D — Opaque JSON blobs | 18 | Phase 7 | Unknown until excavated |
| **Total** | **~58** | | |
