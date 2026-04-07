# Audit: dispatch_persistence_service.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/application/dispatch_persistence_service.dart`, `test/application/dispatch_persistence_service_test.dart`, plus referenced context files
- Read-only: yes

---

## Executive Summary

`DispatchPersistenceService` is structurally sound at the method level — the read/save/clear contract is consistent, corrupt-cache handling is thorough, and the test suite is broad. However the class has grown into a god-object (1 858 lines, 57 keys, ~170 methods) with three concrete problems that need attention:

1. **Layer violation** — the application service imports three UI-layer types directly.
2. **Race condition** — the scoped-conversation registry uses an unguarded read-modify-write that silently drops scope keys under concurrent saves.
3. **Coverage gaps** — 15+ round-trip and corrupt-cache scenarios are untested, including the entire scoped conversation surface and several guard audit keys.

---

## What Looks Good

- Every read method handles `null`, empty string, bad JSON, and wrong root type with a clear fallback.
- The `catch (_)` → `clearX()` → return-empty pattern is consistent across all ~30 typed readers.
- Scoped conversation key derivation is deterministic: `'$baseKey::$clientId|$siteId'`.
- Boolean persistence correctly uses `prefs.containsKey` sentinel before `getBool`, so `false` and `null` are distinguishable.
- Inline normalization in `saveMonitoringIdentityRuleAuditHistory` and `saveMonitoringWatchAuditHistory` prevents empty-entry pollution on write.
- `const DispatchPersistenceService(this.prefs)` constructor enables injection, which the test suite correctly uses via `setMockInitialValues`.

---

## Findings

### P1 — Race Condition in `_registerClientConversationScope`
- **Action: REVIEW**
- `_registerClientConversationScope` does a read-modify-write on the scope registry with no lock or atomic primitive:
  ```
  final existing = await readClientConversationScopeKeys();   // read
  if (existing.contains(scopeKey)) return;
  await saveClientConversationScopeKeys([...existing, scopeKey]); // write
  ```
  If `saveScopedClientAppMessages` and `saveScopedClientAppAcknowledgements` are called concurrently for the same new client/site pair, both read the same empty list, both write a single-element list, and one write clobbers the other's registration. The second scope key is silently dropped from the registry.
- **Why it matters**: If the registry misses a scope key, that scope's data is orphaned — it can never be bulk-cleared and will persist across sessions indefinitely.
- **Evidence**: `lib/application/dispatch_persistence_service.dart` lines 1132–1148; pattern repeated at call sites lines 864, 926, 985, 1041.
- **Suggested follow-up**: Codex should validate whether any caller triggers concurrent scoped saves, and whether the `DispatchPage` controller or similar coordinator issues parallel saves on first contact with a new client.

---

### P1 — Layer Violation: Application Service Imports UI Types
- **Action: REVIEW**
- `dispatch_persistence_service.dart` imports three UI-layer files directly:
  ```
  import '../ui/client_app_page.dart';         // line 11
  import '../ui/admin_page.dart';              // line 12
  import '../ui/video_fleet_scope_health_sections.dart'; // line 13
  ```
  Types used: `ClientAppDraft`, `ClientAppMessage`, `ClientAppAcknowledgement`, `ClientAppPushDeliveryItem`, `ClientPushSyncState`, `AdministrationPageTab`, `VideoFleetWatchActionDrilldown`.
- **Why it matters**: An application-layer service owning persistence should not depend on UI types. Any change to those UI files can break the persistence layer, and the persistence layer cannot be tested or used without pulling in widget machinery.
- **Evidence**: Lines 11–13; method signatures at lines 643, 666, 698, 736, 757, 770, 438, 354–436.
- **Suggested follow-up**: Codex should verify whether `AdministrationPageTab`, `VideoFleetWatchActionDrilldown`, `ClientAppDraft`, etc. are defined inside the UI files or whether they are re-exported models that could be moved to `application/` or `domain/` without breaking widget code.

---

### P2 — God Object: 1 858 Lines, 57 Keys, No Subdivision
- **Action: DECISION**
- The class covers at least 8 semantically distinct subsystems: intake telemetry, live poll, news diagnostics, radio bridge queue, monitoring identity, client app conversation, guard ops, and morning sovereign report. All 57 keys and ~170 methods live in one class.
- **Why it matters**: Any developer touching guard coaching telemetry must open the same file as one touching radio retry state. Diff noise and merge risk are high. There is no interface to scope injection.
- **Evidence**: Lines 1–1858; key declarations lines 16–107.
- **Suggested follow-up**: Product/architecture decision needed: split into domain-scoped persistence services (e.g. `GuardPersistenceService`, `ClientConversationPersistenceService`, `RadioQueuePersistenceService`) or keep unified. If split, the common read-map-pattern could be extracted to a shared helper.

---

### P2 — Massive Structural Duplication: ~14 Identical `Map<String, Object?>` Readers
- **Action: AUTO**
- The following methods are byte-for-byte identical except for the key constant used:
  `readTelegramAdminRuntimeState`, `readMonitoringWatchRuntimeState`, `readOpsIntegrationHealthSnapshot`, `readGuardOutcomeGovernanceTelemetry`, `readGuardCoachingPromptSnoozes`, `readGuardCoachingTelemetry`, `readGuardCloseoutPacketAudit`, `readGuardShiftReplayAudit`, `readGuardSyncReportAudit`, `readGuardExportAuditClearMeta`, `readMorningSovereignReport`, `readOfflineIncidentSpoolReplayAudit`, `readMonitoringSceneReviewState`, `readLivePollSummary`.
  All follow:
  ```dart
  final raw = prefs.getString(KEY);
  if (raw == null || raw.isEmpty) return const {};
  try { ... jsonDecode ... if not Map return {}; return decoded.map(...); }
  catch (_) { await clearX(); return {}; }
  ```
- **Why it matters**: 14 copies of the same error-handling logic means a bug fix must be applied 14 times. One copy already diverges: `readOnyxAgentCameraAuditHistory` (line 1374) and `readMorningSovereignReportHistory` (line 1771) use a `for` loop instead of the functional chain — visually different but semantically the same.
- **Evidence**: Lines 615–641, 1065–1086, 1150–1173, 1346–1372, 1578–1603, 1606–1628, 1631–1653, 1656–1677, 1679–1700, 1702–1723, 1725–1746, 1748–1769 (and list/history variants).
- **Suggested follow-up**: Codex can extract `_readJsonMap`, `_readJsonList<T>`, and `_readString` private helpers and thread `clearFn` as a callback. Safe to auto-implement since all copies are functionally identical.

---

### P2 — Enum Decode Pattern Duplicated 4 Times for `VideoFleetWatchActionDrilldown`
- **Action: AUTO**
- `readTacticalWatchActionDrilldown`, `readDispatchWatchActionDrilldown`, `readAdminWatchActionDrilldown`, and `readAdminPageTab` each contain a manual `for` loop over `<EnumType>.values` to match by name, followed by a clear-on-unknown fallback. The bodies differ only in key constant and enum type.
- **Evidence**: Lines 354–436.
- **Suggested follow-up**: Codex can extract `_readEnum<T extends Enum>(String key, List<T> values, Future<void> Function() clearFn)` helper.

---

### P2 — Inconsistent Empty-List Persistence Across Save Methods
- **Action: REVIEW**
- `saveMonitoringWatchAuditHistory` (line 1221) and `saveMonitoringIdentityRuleAuditHistory` (line 297) both call `clearX()` and return early when the normalized list is empty. `savePendingRadioAutomatedResponses` (line 491), `saveClientAppMessages` (line 687), `saveClientAppAcknowledgements` (line 719), `saveClientAppPushQueue` (line 757) do NOT — they serialize and write `[]` to prefs.
- **Why it matters**: Callers that depend on `prefs.containsKey` to distinguish "never written" from "written empty" will see different behavior depending on which method family they use.
- **Evidence**: Lines 297–311, 1221–1234 vs. lines 491–498, 687–695.
- **Suggested follow-up**: Codex should verify whether any caller checks `containsKey` on these keys, and standardize the write-if-non-empty behavior across all list writers.

---

### P3 — No Size Guard on Unbounded Append-Only Lists
- **Action: REVIEW**
- `morningSovereignReportHistory` (line 1771), `monitoringWatchAuditHistory` (line 1200), and `onyxAgentCameraAuditHistory` (line 1374) are append-only histories with no max-length enforcement. SharedPreferences serializes these to a single JSON string on every save. A long-running deployment accumulates an ever-growing blob.
- **Why it matters**: SharedPreferences on Android is backed by an XML file loaded at startup; on iOS by a plist. Very large values degrade read latency and can exceed system soft limits.
- **Evidence**: Lines 1200–1234, 1374–1408, 1771–1806.
- **Suggested follow-up**: Codex should check whether any save site trims history before calling `save*`. If not, a max-length cap (e.g. 50–100 entries) should be added in the save method.

---

### P3 — `_clientConversationScopeKey` Permits Pipe-Delimited Collision
- **Action: REVIEW** (suspicion, not confirmed)
- The scope key is built as `'${clientId.trim()}|${siteId.trim()}'`. If a `clientId` contains a `|` character, two different `(clientId, siteId)` pairs could produce the same scope key. This is only exploitable if client IDs are user-controlled.
- **Evidence**: Lines 1125–1130.
- **Suggested follow-up**: Codex should check how `clientId` and `siteId` are sourced — if they are system-generated opaque IDs, this risk is negligible; if they are user-facing names, a separator that cannot appear in IDs (e.g. URI-encoding) should be used.

---

## Duplication Summary

| Pattern | Occurrences | Centralization candidate |
|---|---|---|
| `_readJsonMap` (read Map, decode, fallback, clear-on-corrupt) | ~14 | Private generic helper |
| `_readJsonList<T>` (read List, decode, map, filter, clear-on-corrupt) | ~8 | Private generic helper |
| Enum decode via name-match loop | 4 | `_readEnum<T extends Enum>` helper |
| String-normalize-or-clear save pattern | ~6 (radio queue detail methods) | `_saveNonEmptyString` helper |

---

## Coverage Gaps

### Missing round-trip tests
- `readMonitoringIdentityRuleAuditHistory` / `saveMonitoringIdentityRuleAuditHistory` — no save→restore→clear test
- `readMonitoringIdentityRulesJson` / `saveMonitoringIdentityRulesJson` — no test at all
- `readMonitoringWatchRuntimeState` / `saveMonitoringWatchRuntimeState` — no test at all
- `readMorningSovereignReport` / `saveMorningSovereignReport` (single report, not history) — no test
- `readMorningSovereignReportAutoRunKey` / `saveMorningSovereignReportAutoRunKey` — no test
- `readOnyxAgentCameraAuditHistory` / `saveOnyxAgentCameraAuditHistory` — no test
- `readOnyxAgentThreadSessionState` / `saveOnyxAgentThreadSessionState` — no test
- `readMonitoringSceneReviewState` / `saveMonitoringSceneReviewState` — no test
- `readGuardCloseoutPacketAudit` / `readGuardShiftReplayAudit` / `readGuardSyncReportAudit` / `readGuardExportAuditClearMeta` — no individual tests
- Full scoped conversation round-trip: `readScopedClientAppMessages`, `readScopedClientAppAcknowledgements`, `readScopedClientAppPushQueue`, `readScopedClientAppPushSyncState` — no save→restore→clear test
- `readClientConversationScopeKeys` multi-scope accumulation — no multi-scope test

### Missing corrupt-cache tests
- `monitoringWatchRuntimeState`, `telegramAdminRuntimeState`, `onyxAgentCameraAuditHistory`, `morningSovereignReportHistory` — corrupt-cache auto-clear not tested
- Scoped conversation keys (scoped messages, acks, push queue, push sync state) — corrupt-cache path untested
- `pendingRadioAutomatedResponsesRetryState` — corrupt-cache path untested

### Missing behavioral edge cases
- Concurrent calls to `_registerClientConversationScope` for the same new scope — race not tested
- `saveMonitoringIdentityRuleAuditHistory` with a list that normalizes to empty (all blank messages) — auto-clear path not tested
- `saveScopedClientAppMessages` with a blank `clientId` — scoped key still written but not registered; no test validates that the data is still readable via the unregistered key

---

## Performance / Stability Notes

- **Unbounded history lists** (see P3 above): `morningSovereignReportHistory`, `monitoringWatchAuditHistory`, `onyxAgentCameraAuditHistory` write the full list on every append. Consider whether the history should be bounded or migrated to SQLite/Hive once it exceeds a few hundred entries.
- **`_registerClientConversationScope` reads the full scope registry on every scoped save**: Once there are many scopes, this is an extra JSON decode per save. Low concern now, but worth noting as the client base grows.

---

## Recommended Fix Order

1. **[P1] Layer violation** — Move `AdministrationPageTab`, `VideoFleetWatchActionDrilldown`, `ClientAppDraft`, `ClientAppMessage`, `ClientAppAcknowledgement`, `ClientAppPushDeliveryItem`, `ClientPushSyncState` out of the UI files (or add re-exports from a shared location) so the application service no longer imports `../ui/`. This unblocks testing the persistence layer without the widget tree.
2. **[P1] Race condition in `_registerClientConversationScope`** — Add a serialization gate (e.g. a boolean `_registeringScope` flag or a `Completer`-based mutex) around the read-modify-write. Validate that no caller issues concurrent scoped saves.
3. **[AUTO] Extract `_readJsonMap` / `_readJsonList<T>` / `_readEnum` helpers** — Mechanical de-duplication; safe to auto-implement.
4. **[P2] Inconsistent empty-list write behavior** — Standardize whether `saveX([])` writes `[]` or removes the key; update tests accordingly.
5. **[P3] Add history length caps** — Apply a `kMaxHistoryLength` guard in `saveMonitoringWatchAuditHistory`, `saveOnyxAgentCameraAuditHistory`, `saveMorningSovereignReportHistory`.
6. **Coverage** — Add round-trip tests for the 15+ untested methods; add corrupt-cache tests for the 5+ unguarded keys; add a concurrent-scope-registration test.
7. **[DECISION] God-object split** — Defer until after layer violation is resolved; splitting is easier once UI types are no longer entangled.
