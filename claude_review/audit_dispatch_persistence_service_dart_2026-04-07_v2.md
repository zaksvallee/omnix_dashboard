# Audit: dispatch_persistence_service.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/application/dispatch_persistence_service.dart` + `test/application/dispatch_persistence_service_test.dart`
- Read-only: yes

---

## Executive Summary

`DispatchPersistenceService` is a 1,855-line god object managing 50+ distinct `SharedPreferences` keys across at least eight domain areas: radio, guard, monitoring, client conversation, offline spool, agent, morning sovereign, and ops health. The file works and its test coverage is wide (55 tests), but it carries four material risks: a hard layer violation (application importing from `ui/`), a god-object boundary problem, a silent data-destruction pattern on corrupt reads, and a registry write race in the scoped conversation family. Several whole families of methods have zero test coverage.

---

## What Looks Good

- Every `read*` method guards against null, empty, wrong JSON type, and exception with a consistent `try/catch` → clear → return safe-default pattern. Defensive and correct.
- Scoped conversation key structure (`baseKey::clientId|siteId`) is clean and deterministic.
- `saveMonitoringIdentityRuleAuditHistory` and `saveMonitoringWatchAuditHistory` both normalize before persisting (filter blanks, skip empty writes), which prevents silent whitespace accumulation.
- Key constants use versioned names (`_v1`) — migration-friendly if formats change.
- 55 unit tests exercise the most critical radio, guard, and monitoring paths. Corrupt-data / auto-clear tests are thorough for the paths they cover.

---

## Findings

### P1 — Layer Violation: Application service imports from `ui/`

- **Action: REVIEW**
- Lines 10–13 import four UI-layer files directly into an application-layer service:
  ```
  import '../ui/client_app_page.dart';
  import '../ui/admin_page.dart';
  import '../ui/dispatch_models.dart';
  import '../ui/video_fleet_scope_health_sections.dart';
  ```
- **Why it matters:** An application service must not depend on the UI layer. This inverts the dependency direction, couples persistence to widget-layer models, and prevents extracting or testing the service without Flutter widget infrastructure. `ClientAppDraft`, `ClientAppMessage`, `ClientAppAcknowledgement`, `ClientAppPushDeliveryItem`, `ClientPushSyncState`, `AdministrationPageTab`, and `VideoFleetWatchActionDrilldown` are persisted as first-class types — they belong in the domain or application layer, not in `ui/`.
- **Evidence:** `dispatch_persistence_service.dart` lines 10–13; same imports are mirrored in the test file (`test/application/dispatch_persistence_service_test.dart` lines 12–15), confirming they are real dependencies.
- **Suggested follow-up:** Codex to confirm whether these types are defined exclusively in `ui/` files, or whether parallel domain definitions exist. If they are UI-only, the models need to be relocated to `domain/` or `application/` before the import can be corrected.

---

### P1 — Silent data destruction on corrupt reads

- **Action: REVIEW**
- Every `read*` method catches all exceptions and immediately calls `clear*()` on the affected key, then returns a safe default. This is correct for transient corruption, but for mutable queues that represent live operational state (radio retry state, offline spool entries, guard assignments), it means a single JSON decode failure permanently destroys the queue with no error surfaced anywhere.
- **Why it matters:** A partial write, an OS-level storage truncation, or a `toJson()` regression could silently delete pending radio responses, unsynced offline incidents, or guard assignments — all of which require operator awareness and possible reconciliation.
- **Evidence:**
  - `readOfflineIncidentSpoolEntries()` lines 1274–1299
  - `readPendingRadioAutomatedResponses()` lines 463–489
  - `readGuardAssignments()` lines 1411–1434
  - Pattern is identical across ~25 methods.
- **Suggested follow-up:** Codex to confirm whether any caller logs or surfaces the data loss. If not, consider whether the `catch (_)` should rethrow or emit a structured error event for the highest-stakes queues (radio, spool, guard), while keeping silent-clear for UI-state-only keys (drilldown selections, filter strings, UI tab state).

---

### P1 — `_registerClientConversationScope` race and repeated round-trips

- **Action: REVIEW**
- Every `saveScopedClient*` call first invokes `_registerClientConversationScope` (lines 1132–1148), which performs a full read of the scope registry, checks for duplicates, then writes the updated list. When a caller saves messages + acks + push queue + sync state in a single flow, this is 4 sequential read-modify-write cycles on the same registry key. There is no in-memory cache or batch guard.
- **Why it matters:** Each round-trip re-decodes and re-encodes the registry JSON. As the number of distinct `clientId|siteId` scopes grows, each write becomes slower, and concurrent saves (e.g., two message batches arriving close together) could produce a duplicate registry entry — the `contains` check at line 1144 is not atomic across the `read → check → write` sequence.
- **Evidence:** `_registerClientConversationScope` lines 1132–1148; called at `saveScopedClientAppMessages` line 864, `saveScopedClientAppAcknowledgements` line 926, `saveScopedClientAppPushQueue` line 985, `saveScopedClientAppPushSyncState` line 1041.
- **Suggested follow-up:** Codex to verify whether any of the four scoped-save methods are called concurrently in practice. If yes, the registry write is not safe without a lock. An in-memory Set cache or a single registry write per session would eliminate the redundant round-trips.

---

### P2 — `readMonitoringWatchAuditSummary` mutates on read

- **Action: AUTO**
- Lines 1175–1186: if the stored value is blank (non-null but whitespace-only), the read method calls `clearMonitoringWatchAuditSummary()` as a side effect before returning `null`. No other `read*` method does this. The inconsistency means a stored blank value triggers a write during read, which is surprising and could interact with concurrent callers.
- **Why it matters:** Reads should be side-effect-free. If a caller checks for null and later saves a new value, the interleaved clear is invisible and could silently drop a concurrent save.
- **Evidence:** `readMonitoringWatchAuditSummary()` lines 1175–1186, compared to other string readers (e.g., `readRadioIntentPhrasesJson` lines 248–252) which simply return `null` on empty without clearing.
- **Suggested follow-up:** Codex to remove the `clearMonitoringWatchAuditSummary()` call from the read path. The clear-on-empty-save pattern in `saveMonitoringWatchAuditSummary` (lines 1188–1195) already handles this correctly on the write side.

---

### P2 — `_clientConversationScopeKey` accepts half-empty scope

- **Action: AUTO**
- Lines 1125–1130 build a scope key as `'${clientId.trim()}|${siteId.trim()}'`. The guard at line 1140 only rejects the key when both sides are empty (`scopeKey == '|'`). A call with `clientId = ''` and `siteId = 'SITE-1'` produces `'|SITE-1'` — which passes the guard and is registered as a valid scope.
- **Why it matters:** A half-empty scope key could cause multiple tenants' data to collide under a shared partial key, or cause a failed lookup at clear time.
- **Evidence:** `_clientConversationScopeKey` lines 1125–1130; guard at `_registerClientConversationScope` line 1140.
- **Suggested follow-up:** Codex to change the guard to reject any scope where either side is blank: `if (clientId.trim().isEmpty || siteId.trim().isEmpty) return;`

---

### P3 — God object: 50+ namespaces in one class

- **Action: DECISION**
- The class manages all of: radio queue state, guard assignments, monitoring watch runtime, client conversations, offline spool, agent session, morning sovereign report, and ops health — in a single flat class with no internal grouping.
- **Why it matters:** Any change to a guard persistence path requires touching the same file as client conversation persistence. Discovery, onboarding, and targeted testing are harder as the class grows. The `_v1` key versioning suggests awareness of future migrations — a namespaced split would isolate migration risk.
- **Evidence:** Lines 15–1855; key constant list lines 16–107.
- **Suggested follow-up:** This is a product/architecture decision. Options include: (a) keep as-is with grouped `// --- GUARD ---` sections; (b) extract into focused sub-services (`GuardPersistenceService`, `ClientConversationPersistenceService`, `MonitoringPersistenceService`) each injected via a shared `SharedPreferences` instance. Zaks to decide scope.

---

## Duplication

### 1. `Map<String, Object?>` read/decode boilerplate — 12+ methods

Identical pattern repeated for: `readLivePollSummary`, `readMonitoringSceneReviewState`, `readOpsIntegrationHealthSnapshot`, `readTelegramAdminRuntimeState`, `readOnyxAgentThreadSessionState`, `readMonitoringWatchRuntimeState`, `readMonitoringWatchRecoveryState`, `readOfflineIncidentSpoolReplayAudit`, `readGuardOutcomeGovernanceTelemetry`, `readGuardCoachingPromptSnoozes`, `readGuardCoachingTelemetry`, `readGuardCloseoutPacketAudit`, `readGuardShiftReplayAudit`, `readGuardSyncReportAudit`, `readGuardExportAuditClearMeta`, `readMorningSovereignReport`.

Each is 8–10 lines of `getString → decode → cast → mapEntries → catch → clear → return {}`. A private helper `_readJsonMap(String key)` would reduce the class by ~130 lines.

**Files involved:** `dispatch_persistence_service.dart` lines 164–185, 187–210, 615–641, 1065–1087, 1088–1111, 1150–1173, 1241–1258, 1347–1373, 1574–1600, 1602–1625, 1627–1650, 1652–1673, 1675–1696, 1698–1719, 1721–1742, 1744–1765.

**Centralization candidate:** `_readJsonMap(String key)` + `_readJsonList(String key)` private helpers.

---

### 2. `VideoFleetWatchActionDrilldown` enum lookup — 3 identical methods

`readTacticalWatchActionDrilldown` (lines 354–366), `readDispatchWatchActionDrilldown` (lines 382–394), `readAdminWatchActionDrilldown` (lines 410–422) each iterate `.values` by name with identical logic.

**Centralization candidate:** A single private `_readDrilldown(String key)` would replace all three.

---

### 3. String-list normalize/trim/filter pattern — 5 methods

`readLivePollHistory` (L139), `readClientConversationScopeKeys` (L796), `readMonitoringWatchAuditHistory` (L1201) all apply `.map(toString).where(trim().isNotEmpty).map(trim())` with identical pipeline steps.

---

## Coverage Gaps

The following method families have **zero test coverage**:

| Family | Methods missing tests |
|---|---|
| Scoped client conversations | `readScopedClientAppMessages`, `saveScopedClientAppMessages`, `clearScopedClientAppMessages`, all three Acknowledgements variants, all three PushQueue variants, all three PushSyncState variants |
| `_registerClientConversationScope` | Indirect only — no direct test for duplicate-scope guard or half-empty key guard |
| Onyx agent camera audit | `readOnyxAgentCameraAuditHistory`, `saveOnyxAgentCameraAuditHistory`, `clearOnyxAgentCameraAuditHistory` |
| Onyx agent thread session | `readOnyxAgentThreadSessionState`, `saveOnyxAgentThreadSessionState`, `clearOnyxAgentThreadSessionState` |
| Morning sovereign report (non-history) | `readMorningSovereignReport`, `saveMorningSovereignReport`, `clearMorningSovereignReport` |
| Morning sovereign auto-run key | `readMorningSovereignReportAutoRunKey`, `saveMorningSovereignReportAutoRunKey`, `clearMorningSovereignReportAutoRunKey` |
| Telegram admin runtime | `readTelegramAdminRuntimeState`, `saveTelegramAdminRuntimeState`, `clearTelegramAdminRuntimeState` |
| Monitoring watch runtime | `readMonitoringWatchRuntimeState`, `saveMonitoringWatchRuntimeState`, `clearMonitoringWatchRuntimeState` |
| Monitoring watch recovery | `readMonitoringWatchRecoveryState`, `saveMonitoringWatchRecoveryState`, `clearMonitoringWatchRecoveryState` |
| Monitoring scene review | `readMonitoringSceneReviewState`, `saveMonitoringSceneReviewState`, `clearMonitoringSceneReviewState` |

**Specific missing cases across covered paths:**

- `savePendingRadioAutomatedResponses` with an empty list — should it persist `[]` or skip? Not tested.
- `saveMonitoringIdentityRuleAuditHistory` with all-blank messages — tests that it calls `clear*`, not tested.
- `readMonitoringWatchAuditSummary` with a stored blank string — would trigger the side-effect clear, not tested.
- `_clientConversationScopeKey` with a half-empty `clientId` — not tested; the current guard does not catch this (P2 finding above).
- Corrupt-data / auto-clear tests for: `readScopedClientAppMessages`, `readOnyxAgentCameraAuditHistory`, `readMorningSovereignReportHistory` (currently only happy-path tested).

---

## Performance / Stability Notes

### 1. Registry read-modify-write on every scoped save

Described in P1 above. Four round-trips per full scoped-conversation flush. No in-memory dedup. Grows with conversation count. Not currently bounded.

### 2. Unbounded blob growth for audit and telemetry maps

`readGuardCoachingTelemetry`, `readGuardOutcomeGovernanceTelemetry`, `readGuardCloseoutPacketAudit`, `readGuardShiftReplayAudit`, `readGuardSyncReportAudit`, `readGuardExportAuditClearMeta`, `readMorningSovereignReport` are all typed as `Map<String, Object?>` with no schema enforcement or size cap. Their callers control size, but `DispatchPersistenceService` provides no defence against oversized writes. `SharedPreferences` on mobile has a practical limit; large blobs increase serialization time on the main thread.

**Evidence:** All raw-map save methods (e.g., `saveGuardCoachingTelemetry` line 1642, `saveMorningSovereignReport` line 1759) call `jsonEncode` directly without size validation.

### 3. `readMorningSovereignReportHistory` is an unbounded list of full report blobs

Each morning sovereign report blob (as seen in the test, lines 108–182) is a complex multi-section map. The history list has no cap. Over 6–12 months of daily runs, this list could grow to hundreds of large blobs persisted in a single `SharedPreferences` entry.

**Evidence:** `saveMorningSovereignReportHistory` line 1791; no trim or cap before write.

### 4. All `read*` methods are declared `async` but are synchronous

`SharedPreferences.getString` is synchronous. Every method is `async` and `await`s a sync call. This is not incorrect but creates unnecessary microtask overhead. For hot-path reads (e.g., `readMonitoringWatchRuntimeState` called on every watch tick), this is a minor but real cost. Low priority, but worth noting for any future extraction into a sync-capable layer.

---

## Recommended Fix Order

1. **P1 — Layer violation (UI imports)** — blocks architectural correctness; should be resolved before adding more domain types to `ui/`.
2. **P1 — Silent data destruction on corrupt queues** — add structured error emission for radio, spool, and guard paths; silent-clear is acceptable for UI-only keys.
3. **P1 — Registry write race in scoped conversation** — add half-empty scope guard (`clientId.isEmpty || siteId.isEmpty`) immediately; the in-memory cache is a follow-up.
4. **P2 — `readMonitoringWatchAuditSummary` side-effect clear** — small, safe, AUTO fix.
5. **P2 — Half-empty scope key guard** — small, safe, AUTO fix.
6. **Coverage — Scoped client conversation family** — highest risk untested path; test happy-path + corrupt-data for all four scoped types.
7. **Coverage — Agent camera, agent thread, morning sovereign, telegram admin** — fill remaining gaps.
8. **Duplication — `_readJsonMap` / `_readJsonList` helpers** — reduces ~130 lines; low risk, high clarity gain.
9. **P3 — God object split** — DECISION item; defer to Zaks.
10. **Performance — Sovereign report history cap** — add trim-to-N before save; low urgency until history grows.
