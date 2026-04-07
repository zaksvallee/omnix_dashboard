# Audit: dispatch_application_service.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/application/dispatch_application_service.dart` (784 lines)
- Read-only: yes

---

## Executive Summary

`DispatchApplicationService` is the central coordinator for all intelligence ingestion, radio transcription processing, dispatch creation, and execution. The core event-sourcing patterns are solid and the test file (`dispatch_application_service_triage_test.dart`) covers most happy paths. However, there are **four concrete bugs** — including a swallowed `unawaited` ledger seal, a non-atomic multi-step append in `execute`, a collision-prone `dispatchId` truncation scheme, and a stale-state race in `_createDecisionsFromIntel`. The radio ingest method has grown to 145 lines with several interleaved concerns that belong in smaller extracted pieces. Coverage gaps exist for `execute` failure paths and `processIntelligenceDemo` entirely.

---

## What Looks Good

- Clean event-sourcing pattern: every mutation appends an event before returning.
- Deduplication via pre-scanned ID sets is correct and avoids O(n²) store scans per record.
- `_sanitize` + `_dispatchIdForExternal` produce a deterministic, stable dispatch ID from external references.
- Radio ingestion properly handles all-clear → open-dispatch resolution via `_latestOpenDispatchId`.
- `_DecisionCreationResult.empty` is a well-scoped internal value object.
- Authority check precedes engine execution and records `ExecutionDenied` to the store — good audit trail.
- `verifyReplay` flag on every mutation-bearing method allows callers to skip expensive verification in batch scenarios.

---

## Findings

### P1 — Bug: `unawaited` ledger seal in `ingestNormalizedIntelligence` swallows failures silently

- **Action:** REVIEW
- **Finding:** `unawaited(ledgerService.sealIntelligenceBatch(...))` (line 146–150) discards the returned Future without error handling. If `sealIntelligenceBatch` throws or the underlying Supabase call fails, the caller receives a successful `IntelligenceIngestionOutcome` with no indication that ledger persistence failed.
- **Why it matters:** Intel events are appended to the store but the ledger may diverge silently. Evidence chain breaks without any observable signal.
- **Evidence:** `dispatch_application_service.dart:146–150`
- **Suggested follow-up:** Codex should verify whether `ClientLedgerService.sealIntelligenceBatch` can throw and whether callers are expected to surface ledger failures. If so, the method signature must become `async` and the Future awaited, or a callback/stream error path added.

---

### P1 — Bug: Non-atomic multi-step append in `execute` — store state can be partially written

- **Action:** REVIEW
- **Finding:** `execute` (lines 690–759) appends `ExecutionDenied` or `ExecutionCompleted` to the store and *then* calls `ledgerService.sealDispatch`. If `sealDispatch` throws, the store already contains `ExecutionCompleted` but the ledger seal never happened. On subsequent invocations, `projection.statusOf` will return a status other than `'DECIDED'` (execution already recorded), so the dispatch silently stalls with no retry path.
- **Why it matters:** This is an unrecoverable partial-write. The event store and the ledger diverge permanently without any error surfaced to the caller.
- **Evidence:** `dispatch_application_service.dart:738–758`
- **Suggested follow-up:** Codex should verify whether a compensating retry mechanism exists elsewhere, or whether `execute` should be wrapped in try/catch with a compensating `ExecutionFailed` event appended on ledger failure.

---

### P1 — Bug: `sequence: 0` hardcoded on every appended event

- **Action:** REVIEW
- **Finding:** Every `DecisionCreated`, `IntelligenceReceived`, `IncidentClosed`, `ExecutionCompleted`, and `ExecutionDenied` event is created with `sequence: 0` (e.g. lines 186–194, 239–258, 274–284, 329–343, 503–523, 650–659, 713–728, 738–749). If `sequence` is used by the event store for ordering, replay, or conflict detection, all events will share the same sequence number, making ordering undefined.
- **Why it matters:** `ReplayConsistencyVerifier.verify` may pass today because it doesn't check sequence values, but any downstream consumer that relies on sequence for ordering or cursor-based replay will be silently broken.
- **Evidence:** Lines 186, 241, 275, 330, 504, 651, 714, 739 — all `sequence: 0`.
- **Suggested follow-up:** Codex should inspect `EventStore.append` and `ReplayConsistencyVerifier.verify` to confirm whether sequence is assigned by the store or must be provided by the caller. If store-assigned, the field should be removed from call sites.

---

### P2 — Bug: `_dispatchIdFor` truncates provider/externalId — collision risk under common patterns

- **Action:** REVIEW
- **Finding:** `_dispatchIdForExternal` (lines 678–682) truncates the sanitized provider to 4 chars and the sanitized externalId to 8 chars: `DSP-$providerCode-$extCode`. Providers `"watchtower"` and `"watchman"` both sanitize to `WATC`. External IDs `"WT-001"` and `"WT-002"` both sanitize to `WT001` (5 chars, within 8) but `"WT-0012"` and `"WT-0013"` both produce `WT0012XX` and `WT0013XX` after `padRight(8,'0')` — no collision there. However, `"WT-0012345"` and `"WT-00123456"` both truncate to `WT001234`. Providers with common short prefixes and sequential IDs can produce duplicate dispatch IDs pointing to different real dispatches.
- **Why it matters:** A false deduplication match would suppress a genuine dispatch creation silently.
- **Evidence:** `dispatch_application_service.dart:678–682`
- **Suggested follow-up:** Codex should validate whether the hash-based `canonicalHash` field is already used as the unique key elsewhere, or whether `_dispatchIdForExternal` should use an SHA prefix of the full `provider+externalId` string instead of truncation.

---

### P2 — Stale state: `_createDecisionsFromIntel` reads store twice, mid-loop writes diverge from the snapshot

- **Action:** REVIEW
- **Finding:** `_createDecisionsFromIntel` (lines 593–672) reads `historicalIntel` and `knownDecisions` from the store at the start (lines 608–614), then appends new `DecisionCreated` events inside the loop (line 660). `knownDecisions` is a local mutable list that receives the new decisions (line 661), but `historicalIntel` is a frozen snapshot. If `triagePolicy.evaluateNormalizedRecord` uses `historicalIntel` to check whether corroborating intel already exists, it will miss intel appended by `DeterministicIntelligenceIngestionService.ingestBatch` in the same call to `ingestNormalizedIntelligence` (lines 132–135 run before `_createDecisionsFromIntel` at line 137).
- **Why it matters:** Triage policy may under-escalate because the corroborating intel was appended in the same batch but isn't in the `historicalIntel` snapshot passed to `evaluateNormalizedRecord`.
- **Evidence:** `dispatch_application_service.dart:608–614, 660–661`; `ingestNormalizedIntelligence:132–137`
- **Suggested follow-up:** Codex should verify whether `ingestBatch` appends to the same `store` before `_createDecisionsFromIntel` reads it, and whether `historicalIntel` should be rebuilt after the ingest step or constructed from `ingestResult.appendedEvents + store.allEvents().whereType<IntelligenceReceived>()`.

---

### P2 — Logic: `_DecisionCreationResult.empty` misclassifies all skipped records as `advisoryCount`

- **Action:** REVIEW
- **Finding:** When `autoGenerateDispatches = false`, `_createDecisionsFromIntel` is skipped and `_DecisionCreationResult.empty(records.length)` is returned (line 138). This sets `advisoryCount = records.length`, implying all records are advisory-grade intelligence. In reality, some may be watch or dispatch-candidate grade — they were just never evaluated. The `IntelligenceIngestionOutcome` returned to callers will thus overstate `advisoryCount`.
- **Why it matters:** Callers that threshold on `advisoryCount` vs `dispatchCandidateCount` for telemetry or alerting will see misleading data when `autoGenerateDispatches = false`.
- **Evidence:** `dispatch_application_service.dart:138`, `_DecisionCreationResult.empty:775–782`
- **Suggested follow-up:** Consider renaming the field to `unevaluatedCount` or returning zeroes for all recommendation fields when skipping triage, making the "not evaluated" case unambiguous.

---

### P3 — Structural: `ingestRadioTransmissions` is 145 lines with interleaved append, intent classification, all-clear resolution, and automated response generation

- **Action:** AUTO
- **Finding:** Lines 201–374 handle four distinct concerns inline: (1) dedup check, (2) intent classification + intel record construction, (3) escalation dispatch creation, (4) all-clear close and automated response routing. The all-clear dispatch resolution block (lines 298–317) is especially hard to follow — `allClearDispatchId` is used both for the all-clear path and as a fallback for panic/duress, which is confusing.
- **Why it matters:** Any change to escalation or all-clear logic risks inadvertently touching the other path. Bug at line 306 (see P2 stale state above) is easy to miss precisely because of this interleaving.
- **Evidence:** `dispatch_application_service.dart:201–374`
- **Suggested follow-up:** Codex could extract `_buildRadioIntelEvent`, `_buildEscalationDecision`, and `_buildCloseEvent` as private helpers without changing any logic.

---

### P3 — `processIntelligenceDemo` uses wall-clock `DateTime.now()` as a stable ID seed

- **Action:** AUTO
- **Finding:** `processIntelligenceDemo` (lines 93–122) sets `id: DateTime.now().millisecondsSinceEpoch.toString()` (line 99). If called multiple times within the same millisecond (e.g. in tests or rapid UI triggers) it will produce duplicate IDs.
- **Why it matters:** This is a demo method, but it writes to the real `store`. Duplicate IDs could confuse replay verification.
- **Evidence:** `dispatch_application_service.dart:99`
- **Suggested follow-up:** Use a UUID or a counter-based ID. Since this is demo-only, risk is low but the fix is trivial.

---

## Duplication

### 1. Store full-scan for dedup sets — appears in three methods

`ingestRadioTransmissions` (lines 206–215), `recordRadioAutomatedResponses` (lines 477–481), and `escalateIntelligence` (lines 174–181) each do a full `store.allEvents()` scan to build dedup sets. The same pattern exists in `_createDecisionsFromIntel` (lines 597–614). None of these are cached between calls.

- **Files involved:** `dispatch_application_service.dart:174–181`, `206–215`, `477–481`, `597–614`
- **Centralization candidate:** A `_buildKnownIdSets()` private method that returns `(intelIds, dispatchIds, closedIds)` in one pass over `store.allEvents()` could eliminate four separate full scans per composite operation.

### 2. `DecisionCreated` event construction appears in three call sites

Nearly identical `DecisionCreated(...)` construction at lines 186–194 (`escalateIntelligence`), 274–284 (`ingestRadioTransmissions`), and 650–659 (`_createDecisionsFromIntel`). Differences are only in `eventId` prefix (`DEC-MANUAL-`, `DEC-RAD-`, `DEC-`).

- **Centralization candidate:** A `_buildDecision(String prefix, ...)` factory method.

### 3. `_radioRiskScore` / `_radioIntentLabel` switch blocks mirror each other

Lines 376–394. Both switch exhaustively on `OnyxRadioIntent`. These could be co-located in a single `_radioIntentMetadata` record/map or pushed to `OnyxRadioIntent` itself as extension methods.

---

## Coverage Gaps

| Gap | Severity | Notes |
|-----|----------|-------|
| `processIntelligenceDemo` — no test | Medium | Writes to store; not just display logic |
| `execute` — denied path not tested | High | `ExecutionDenied` event is business-critical; authority check at line 712 has no test |
| `execute` — `ledgerService.sealDispatch` failure | High | Partial-write scenario (P1 above) has no regression test |
| `escalateIntelligence` — dedup / already-escalated path | Medium | `return false` at line 180 not covered |
| `recordRadioAutomatedResponses` — empty list early return | Low | Trivial but uncovered |
| `ingestNormalizedIntelligence` with `autoGenerateDispatches = false` | Medium | The `_DecisionCreationResult.empty` path is not exercised |
| `_latestOpenDispatchId` when no open dispatches exist | Medium | Returns `null`; the `null` flows into `IncidentClosed` path — verify null guard at line 325 covers all code paths |
| Radio transmission with `unknown` intent | Low | `_radioAutomatedResponseFor` returns `null` — no test confirms it produces no automated response |

---

## Performance / Stability Notes

1. **O(n) store scan per record in radio ingest:** The `existingIntelIds` and `knownDispatchIds` sets are built once before the loop, which is correct. However, `_latestOpenDispatchId` (called inside the loop at line 301) calls `store.allEvents()` *twice* (lines 569 and 575) for every all-clear record. On a store with thousands of events this is O(2n) per all-clear transmission. If multiple all-clear transmissions appear in one batch, this multiplies. Consider building the open-dispatch index once before the loop.

2. **`execute` calls `store.allEvents()` for full projection replay on every execution:** Lines 698–707 rebuild the entire `DispatchProjection` from scratch on every `execute` call. If the store grows large and `execute` is called frequently, this becomes expensive. A projection cache or pre-filtered view would help but this is an architectural trade-off to flag for `DECISION`.
   - **Action:** DECISION

3. **`_verifyReplay` calls `store.allEvents()` on every mutation path:** `ReplayConsistencyVerifier.verify` (line 90) also iterates the full store. Combined with the store scans above, a single `ingestNormalizedIntelligence` call with 50 records may scan the event store 4–5 times. The `verifyReplay` flag helps callers opt out, but the default is `true`.

---

## Recommended Fix Order

1. **P1 — Await ledger seal in `ingestNormalizedIntelligence`** — silent divergence between store and ledger is a data integrity risk. Make the method `async` or add error recovery.
2. **P1 — Protect `execute` against partial write** — add try/catch around `sealDispatch` and append a compensating event on failure.
3. **P1 — Audit `sequence: 0` across all event construction sites** — confirm whether the store assigns sequence or expects it from the caller. If caller-assigned, this is a latent ordering bug.
4. **P2 — Add tests for `execute` denied path and ledger-failure path** — these are business-critical and currently untested.
5. **P2 — Fix stale `historicalIntel` snapshot in `_createDecisionsFromIntel`** — rebuild after `ingestBatch` completes.
6. **P2 — Fix `_DecisionCreationResult.empty` advisory misclassification** — rename or zero-out recommendation counts when triage is skipped.
7. **P3 — Extract radio ingest helpers** — reduce `ingestRadioTransmissions` from 145 to ~60 lines.
8. **P3 — Fix `_latestOpenDispatchId` double store scan inside loop** — build open-dispatch index once before the transmission loop.
9. **P3 — Validate `_dispatchIdForExternal` collision surface** — switch to SHA-based prefix if provider + externalId combinations overlap in production data.
