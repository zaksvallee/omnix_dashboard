# Audit: dispatch_persistence_service.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/application/dispatch_persistence_service.dart` + `test/application/dispatch_persistence_service_test.dart`
- Read-only: yes

---

## Executive Summary

`DispatchPersistenceService` is a 1,854-line god object that owns all application state persistence in a single class — 45+ key constants, 40+ read/save/clear triads, and cross-domain responsibilities spanning guard ops, client comms, monitoring, telegram, morning reports, and UI filter state. The individual methods are written defensively and consistently, which is the dominant strength. However, the class has a confirmed architectural violation (application layer importing UI types), a real key-collision risk in scoped storage, an inconsistent write-path guard on one filter method, and a large untested surface in scoped conversation methods and audit bag reads. Several unbounded list blobs can grow indefinitely in SharedPreferences.

---

## What Looks Good

- Every read method handles corrupt JSON by clearing the key and returning a safe default — no silent exception swallowing.
- Enum persistence uses `.name`-based round-trip with stale-key clear, not raw ordinals — resilient to enum reordering.
- Scoped conversation registry (`_registerClientConversationScope`) correctly deduplicates before appending.
- `saveMonitoringIdentityRuleAuditHistory` normalizes to empty → clears rather than writing a zero-length blob.
- `saveMonitoringWatchRecoveryState` guards against writing empty maps.
- Test suite is substantial (45 test cases, 1,301 lines) and covers the most complex paths.

---

## Findings

### P1 — Architectural: Application layer imports UI layer types

- **Action:** REVIEW
- **Finding:** The service directly imports four UI-layer files at lines 10–13.
- **Why it matters:** This is a direct application → UI dependency, which is an inversion of the expected DDD layer contract. It makes the persistence layer untestable without Flutter widget infrastructure and prevents any future extraction of application logic into a standalone package.
- **Evidence:**
  ```
  lib/application/dispatch_persistence_service.dart:10  import '../ui/client_app_page.dart';
  lib/application/dispatch_persistence_service.dart:11  import '../ui/admin_page.dart';
  lib/application/dispatch_persistence_service.dart:12  import '../ui/dispatch_models.dart';
  lib/application/dispatch_persistence_service.dart:13  import '../ui/video_fleet_scope_health_sections.dart';
  ```
  Affected types: `ClientAppDraft`, `ClientAppMessage`, `ClientAppAcknowledgement`, `ClientAppPushDeliveryItem`, `ClientPushSyncState`, `AdministrationPageTab`, `VideoFleetWatchActionDrilldown`, `DispatchProfileDraft`.
- **Suggested follow-up:** Codex should verify whether any of these model types (e.g. `ClientAppMessage`, `DispatchProfileDraft`) are already duplicated or movable to `domain/` or a shared `models/` location without breaking UI imports.

---

### P1 — Bug candidate: Scoped key collision via unguarded delimiter in IDs

- **Action:** REVIEW
- **Finding:** `_clientConversationScopeKey` joins `clientId` and `siteId` with `|` (line 1129). The guard at line 1140 only rejects the trivially empty `'|'` case. If either ID contains a literal `|`, keys for different `(clientId, siteId)` pairs can collide.
- **Why it matters:** A collision causes one client's conversation messages, acks, push queue, and sync state to be read/overwritten by another client's writes. This is a silent data corruption path in production.
- **Evidence:**
  ```
  lib/application/dispatch_persistence_service.dart:1125-1130  _clientConversationScopeKey()
  lib/application/dispatch_persistence_service.dart:1140        if (scopeKey == '|') return;
  ```
- **Suggested follow-up:** Codex should check how `clientId` and `siteId` are sourced (Supabase UUIDs, user-defined strings?) and whether `|` can appear. If IDs are raw UUIDs, risk is low. If user-defined, it is real.

---

### P2 — Bug: `saveGuardSyncHistoryFilter` does not guard empty strings

- **Action:** AUTO
- **Finding:** `saveGuardSyncHistoryFilter` (line 1489–1491) calls `prefs.setString` unconditionally after `.trim()`, even if the trimmed result is empty. All comparable filter save methods (`saveGuardSyncOperationModeFilter` at line 1505–1511, `savePendingRadioQueueManualActionDetail` at line 545–552) guard against empty → clear. The read method returns `null` for empty strings, so the discrepancy is not visible to callers — but it leaves a stale empty-string key rather than removing it.
- **Evidence:**
  ```
  lib/application/dispatch_persistence_service.dart:1489-1491
    Future<void> saveGuardSyncHistoryFilter(String filter) async {
      await prefs.setString(guardSyncHistoryFilterKey, filter.trim());
    }
  ```
  Compare to lines 1505–1511 which gate on `normalized.isEmpty`.
- **Suggested follow-up:** Codex can align `saveGuardSyncHistoryFilter` to call `clearGuardSyncHistoryFilter()` when the trimmed value is empty, matching the established pattern.

---

### P2 — Bug candidate: `readMonitoringIdentityRuleAuditHistory` skips `whereType<Map>()` guard

- **Action:** REVIEW
- **Finding:** Line 288 passes list items directly to `MonitoringIdentityPolicyAuditRecord.fromJson` via `.map()` without the `.whereType<Map>()` filter used in every other list-of-map reader in this file. If `decoded` contains a non-Map item (e.g. a `null` or a string from a future schema change), `fromJson` receives the raw `dynamic` and will likely throw, triggering the corrupt-clear path and wiping the audit history.
- **Evidence:**
  ```
  lib/application/dispatch_persistence_service.dart:287-289
    return decoded
        .map(MonitoringIdentityPolicyAuditRecord.fromJson)
        .whereType<MonitoringIdentityPolicyAuditRecord>()
  ```
  Contrast with `readGuardAssignments` at lines 1417–1423 and `readClientAppMessages` at lines 672–678 which both use `.whereType<Map>()` first.
- **Suggested follow-up:** Codex should verify whether `MonitoringIdentityPolicyAuditRecord.fromJson` accepts `dynamic` safely or requires a typed `Map<String, Object?>`. If the latter, add `.whereType<Map>()` before `.map(fromJson)`.

---

### P2 — Structural: God object with no domain partitioning

- **Action:** DECISION
- **Finding:** The class owns persistence for at least seven distinct subsystems: guard ops, client comms, monitoring watch, telegram admin, morning reports, radio queue, and UI filter state. This is ~1,854 lines in a single class with no internal sub-grouping.
- **Why it matters:** Every new subsystem adds to this class. New developers have no signal about which methods are related. Test isolation is hampered because a single `SharedPreferences.setMockInitialValues({})` resets all domains simultaneously.
- **Evidence:** `lib/application/dispatch_persistence_service.dart:15–1854`
- **Suggested follow-up:** Splitting into domain-scoped persistence services (e.g. `GuardPersistenceService`, `ClientConversationPersistenceService`) is an architectural decision for Zaks. Codex should not split without approval. Codex may add an internal `// --- Guard Domain ---` comment grouping as a low-risk orientation step if approved.

---

### P3 — Performance/Stability: Unbounded list blobs in SharedPreferences

- **Action:** REVIEW
- **Finding:** `readMorningSovereignReportHistory` (line 1767) and `readOnyxAgentCameraAuditHistory` (line 1375) return `List<Map<String, Object?>>` with no size cap. Save paths write the full list unconditionally. If callers append indefinitely, these SharedPreferences values will grow without bound.
- **Why it matters:** SharedPreferences is not designed for large payloads. Large blobs increase startup I/O and can cause write failures on some platforms.
- **Evidence:**
  ```
  lib/application/dispatch_persistence_service.dart:1401-1405  saveOnyxAgentCameraAuditHistory
  lib/application/dispatch_persistence_service.dart:1791-1797  saveMorningSovereignReportHistory
  ```
- **Suggested follow-up:** Codex should check call sites to determine if callers already enforce a cap. If not, a max-length trim (e.g. keep last N entries) in the save methods is appropriate.

---

### P3 — Structural: Repeated Map<String, Object?> open-bag pattern

- **Action:** DECISION
- **Finding:** 16 methods return `Map<String, Object?>` with no typed wrapper — `readMonitoringSceneReviewState`, `readLivePollSummary`, `readTelegramAdminRuntimeState`, `readOnyxAgentThreadSessionState`, `readMonitoringWatchRuntimeState`, `readMonitoringWatchRecoveryState`, `readOfflineIncidentSpoolReplayAudit`, `readGuardOutcomeGovernanceTelemetry`, `readGuardCoachingPromptSnoozes`, `readGuardCoachingTelemetry`, `readGuardCloseoutPacketAudit`, `readGuardShiftReplayAudit`, `readGuardSyncReportAudit`, `readGuardExportAuditClearMeta`, `readMorningSovereignReport`, `readOpsIntegrationHealthSnapshot`. The save paths are also all identical.
- **Why it matters:** No type-checking at the persistence boundary. Schema drift is invisible until a read fails at a cast site. Each of these probably has an implicit schema known to its consumer — replacing with typed models would lock the contract.
- **Evidence:** `lib/application/dispatch_persistence_service.dart:615–641` (one example), mirrored 15+ times.
- **Suggested follow-up:** This is an architectural trade-off — Zaks to decide. Codex should not convert without approval.

---

## Duplication

### 1. Trimmed-string list decode (3 instances, identical logic)
- `readLivePollHistory` lines 139–154
- `readClientConversationScopeKeys` lines 796–811
- `readMonitoringWatchAuditHistory` lines 1201–1220

All three decode a JSON list of strings, trim entries, filter blanks, and return `List<String>`. The only difference is the key and the corrupt-clear call target. A private helper `_readStringList(String key, Future<void> Function() onCorrupt)` would eliminate this.

### 2. Map<String, Object?> decode (16 instances, identical body)
See P3 finding above. The read body is identical across all 16 methods. A private helper `_readMap(String key)` or `_readMapOrClear(String key, Future<void> Function() clear)` would collapse this.

### 3. WatchActionDrilldown enum persistence (3 identical triplets)
- `readTacticalWatchActionDrilldown` / `saveT...` / `clearT...` lines 354–380
- `readDispatchWatchActionDrilldown` / `saveD...` / `clearD...` lines 382–408
- `readAdminWatchActionDrilldown` / `saveA...` / `clearA...` lines 410–436

All three operate on `VideoFleetWatchActionDrilldown` with identical logic, differing only in key. A single `_readEnum<T>`, `_saveEnum<T>`, `_clearEnum` helper or a parameterized method would remove the repetition.

### 4. Scoped conversation triplets (4 × 3 = 12 nearly-identical methods)
`readScoped*` / `saveScoped*` / `clearScoped*` for messages, acks, push queue, and push sync state (lines 829–1063). Each is identical except for the base key and model type. A generic helper would reduce this surface significantly — but requires type parameterization, which is a refactor decision.

---

## Coverage Gaps

### Untested: scoped client conversation methods
- `readScopedClientAppMessages`, `saveScopedClientAppMessages`, `clearScopedClientAppMessages`
- `readScopedClientAppAcknowledgements`, `saveScopedClientAppAcknowledgements`, `clearScopedClientAppAcknowledgements`
- `readScopedClientAppPushQueue`, `saveScopedClientAppPushQueue`, `clearScopedClientAppPushQueue`
- `readScopedClientAppPushSyncState`, `saveScopedClientAppPushSyncState`, `clearScopedClientAppPushSyncState`

Test at line 536 covers `readClientConversationScopeKeys` but not the scoped data reads. The scoped collision risk (P1) is also untested.

### Untested: `_registerClientConversationScope` deduplication
No test verifies that calling `saveScopedClientAppMessages` twice for the same `(clientId, siteId)` does not append a duplicate scope key.

### Untested: `readMonitoringSceneReviewState` / `saveMonitoringSceneReviewState`
No test case for this pair. No corrupt-path test either.

### Untested: `readMonitoringWatchRecoveryState` / `saveMonitoringWatchRecoveryState`
Not covered. The `state.isEmpty → clear` guard in save (line 1263) is also untested.

### Untested: audit bag reads (guard domain)
`readGuardCloseoutPacketAudit`, `readGuardShiftReplayAudit`, `readGuardSyncReportAudit`, `readGuardExportAuditClearMeta` — round-trip and corrupt-path tests missing for all four.

### Untested: `readMorningSovereignReport` round-trip
Only history is tested (line 106). The current-report read/save/clear triplet is not covered.

### Untested: `readMorningSovereignReportAutoRunKey`
No test.

### Untested: `readOnyxAgentCameraAuditHistory` / `saveOnyxAgentCameraAuditHistory`
No test.

### Untested: `readOnyxAgentThreadSessionState`
No test.

### Untested: `saveGuardSyncHistoryFilter` empty-string edge case
The P2 bug (save with empty string does not clear) is not caught by any test. Test at line 732 only confirms a non-empty round-trip.

### Untested: `readOperatorId` / `saveOperatorId`
Tested at line 1252 (basic round-trip) but no corrupt-path and no empty-string edge case.

---

## Performance / Stability Notes

- **Unbounded list blobs** (morning sovereign report history, agent camera audit history): SharedPreferences is a flat key/value store loaded entirely at startup. Unbounded append without a size cap will degrade startup I/O over time. Confirm callers enforce a cap; if not, add one in the save methods. See P3 finding.
- **`_registerClientConversationScope` read-modify-write**: Lines 1143–1148 perform a non-atomic read-then-write. On web (single-threaded Dart, but async interleaving), two concurrent `saveScopedClient*` calls for different scopes could both read the same stale scope list and one write would win, dropping the other's registration. Low probability in practice given the UI event loop, but worth noting for high-traffic scenarios.
- **No write batching**: Methods that save related state (e.g. `saveScopedClientAppMessages` + `saveScopedClientAppAcknowledgements`) each do independent `prefs.setString` calls. SharedPreferences commits are synchronous on Android (via apply) so this is low-risk, but callers doing multi-part saves should be aware there is no transaction boundary.

---

## Recommended Fix Order

1. **[P1] Resolve UI import violations** — confirm which types can be moved to `domain/` or a shared models file, then update the import chain. This unblocks pure-Dart testing of the persistence layer.
2. **[P2] Fix `saveGuardSyncHistoryFilter` empty-string guard** — trivial one-line alignment to the established pattern (`AUTO` once P1 is clear enough to proceed safely).
3. **[P2] Add `whereType<Map>()` guard to `readMonitoringIdentityRuleAuditHistory`** — low-risk defensive fix, confirm `fromJson` signature first.
4. **[P1] Validate scoped key collision scope** — check whether `clientId` / `siteId` can contain `|`; if yes, encode with `Uri.encodeComponent` or a delimiter-free separator.
5. **[Coverage] Add tests for scoped conversation methods** — especially the deduplication path in `_registerClientConversationScope` and the collision scenario.
6. **[Coverage] Add tests for untested audit-bag triplets** — `guardCloseoutPacketAudit`, `guardShiftReplayAudit`, `guardSyncReportAudit`, `guardExportAuditClearMeta`, `morningSovereignReport`, `onyxAgentCameraAuditHistory`, `onyxAgentThreadSessionState`.
7. **[Performance] Confirm or add size caps on unbounded list blobs** — morning sovereign history, agent camera audit history.
8. **[DECISION] Domain partitioning** — splitting the god object is a product and architecture call for Zaks; do not implement without approval.
