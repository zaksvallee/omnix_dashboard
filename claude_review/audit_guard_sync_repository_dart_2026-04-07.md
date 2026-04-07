# Audit: guard_sync_repository.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/application/guard_sync_repository.dart`
- Read-only: yes

---

## Executive Summary

The file is well-conceived: three concrete implementations behind one abstract interface, a clean fallback/primary pattern, and reasonable in-memory filtering logic. The existing test suite covers the `SharedPrefs` path with good breadth. Two critical structural bugs exist in the Supabase implementation (non-atomic delete-then-insert), and the `retryFailedOperations` Supabase path makes N sequential round-trips. The `FallbackGuardSyncRepository` has a subtle but consequential asymmetry in what it mirrors when reading operations. `SupabaseGuardSyncRepository` has zero test coverage.

---

## What Looks Good

- Abstract interface extends `GuardSyncOperationStore` cleanly; the split between queue store (3 methods) and full repository (+ assignments, readOperations, retryFailedOperations) is sound.
- `SharedPrefsGuardSyncRepository.readOperations` applies status/facade/limit filtering deterministically in-memory before returning.
- `FallbackGuardSyncRepository` correctly mirrors writes into fallback even when primary succeeds, keeping the local store warm.
- `retryFailedOperations` in `SharedPrefsGuardSyncRepository` clears `failureReason` and increments `retryCount` atomically in a single in-memory pass before persisting.
- File-level private helpers (`_operationRuntimeContext`, `_operationFacadeId`, `_operationFacadeMode`, `_normalizedFacadeMode`) keep the body of each method clean.

---

## Findings

### P1 — Non-atomic delete-then-insert in `SupabaseGuardSyncRepository.saveAssignments`

- Action: **REVIEW**
- The method deletes all rows for the guard (line 284–288) then inserts fresh rows (line 292–309). If the delete succeeds and the insert throws (network, constraint, RLS rejection), every assignment for that guard is permanently wiped with no recovery path.
- Why it matters: `saveAssignments` is called by `FallbackGuardSyncRepository.saveAssignments` on every successful primary read (line 140–145), meaning the window is opened on every cache-warm call. An intermittent insert failure at that point leaves the guard with no server-side assignments until a full re-sync.
- Evidence: `lib/application/guard_sync_repository.dart` lines 282–309
- Suggested follow-up for Codex: Verify whether Supabase client exposes upsert (`.upsert()`) on this table. If assignment IDs are stable, replace delete+insert with upsert. If delete+insert is required for legacy reasons, wrap in a Postgres function/RPC to run both in a single transaction.

---

### P1 — Non-atomic delete-then-insert in `SupabaseGuardSyncRepository.saveQueuedOperations`

- Action: **REVIEW**
- Identical structural bug: deletes all `queued` rows for the guard (lines 389–394), then inserts. If insert fails, the entire queued operation log for that guard is wiped. Panic signals and checkpoint scans in the queue could be lost.
- Why it matters: This is a queue — losing queued operations silently is a safety risk (panic signals, location data). The fallback layer calling this to mirror data (line 184) opens the same window.
- Evidence: `lib/application/guard_sync_repository.dart` lines 387–418
- Suggested follow-up for Codex: Replace with `.upsert()` using `operation_id` as the conflict target, or use a stored procedure. Confirm the table has a unique constraint on `operation_id`.

---

### P1 — `retryFailedOperations` in `SupabaseGuardSyncRepository` issues N sequential round-trips

- Action: **AUTO**
- Lines 445–462 loop over each failed row and issue an individual `.update()` call per operation ID. For N failed operations this means N+1 Supabase calls (1 select + N updates), each with a full HTTP round-trip.
- Why it matters: `retryFailedOperations` is likely called during a sync flush when connectivity is restored, exactly when performance matters most. Under 10+ failed operations this will be noticeably slow and burn connection quota.
- Evidence: `lib/application/guard_sync_repository.dart` lines 444–463
- Suggested follow-up for Codex: Replace the per-row update loop with a single `.update({...}).inFilter('operation_id', operationIds).eq('operation_status', 'failed')` call. Note: the per-row `retry_count` increment cannot be done server-side without a stored procedure — consider accepting a flat increment or storing retry count only locally, or wrapping in an RPC.

---

### P2 — `FallbackGuardSyncRepository.readOperations` only mirrors `queued` status to fallback

- Action: **REVIEW**
- When `primary.readOperations` returns results, only operations with `status == queued` are written to fallback (lines 177–184). Operations with `failed` status returned from primary are discarded — the fallback never learns about them.
- Why it matters: If a caller queries `readOperations(statuses: {failed})` and primary is temporarily unavailable, the fallback returns empty, hiding the fact that there are failed operations on the server. Depending on retry UI logic, this could silently suppress a retry prompt.
- Contrast: `readAssignments` (line 129–133) mirrors everything returned by primary. The asymmetry is not documented.
- Evidence: `lib/application/guard_sync_repository.dart` lines 160–195
- Suggested follow-up for Codex: Decide whether fallback should mirror all returned operations or only queued ones. If only queued is intentional, add a comment explaining why. If it should mirror all, update the filter.

---

### P2 — `FallbackGuardSyncRepository.retryFailedOperations` return value is ambiguous

- Action: **REVIEW**
- Lines 216–223: `primaryRetried` stays `null` if primary throws. The method then returns `fallbackRetried`. But if primary succeeds with 0 (no failed rows on server) and fallback has failed rows locally, the method returns 0 even though fallback retried some — and vice versa.
- Why it matters: Callers relying on the return value to show "N operations retried" could display incorrect counts. The semantics of "how many were retried" is ambiguous across two stores.
- Evidence: `lib/application/guard_sync_repository.dart` lines 215–223
- Suggested follow-up for Codex: Clarify the intended contract. If primary is authoritative for count, document that. If callers should see the union, return `(primaryRetried ?? 0) + fallbackRetried` with a note that duplicates are possible.

---

### P3 — `readQueuedOperations` in `SharedPrefsGuardSyncRepository` returns unsorted results

- Action: **REVIEW** (suspicion, not confirmed bug)
- `readQueuedOperations` (lines 36–38) returns whatever order `persistence.readGuardSyncOperations()` delivers — no sort applied. `readOperations` (lines 41–76) sorts newest-first. `RepositoryBackedGuardMobileSyncQueue.peekBatch` calls `readQueuedOperations` and takes the first N items; if persistence order is insertion order this is FIFO, but that is an undocumented assumption.
- Why it matters: If the guard sync consumer processes in insertion order but persistence ever returns out-of-insertion order (e.g., after a SharedPrefs migration or JSON decode), the queue could drain in wrong order. Panic signals would not necessarily be processed before older heartbeats.
- Evidence: `lib/application/guard_sync_repository.dart` lines 36–38; `lib/domain/guard/guard_mobile_ops.dart` lines 292–296
- Suggested follow-up for Codex: Verify whether `DispatchPersistenceService.readGuardSyncOperations` preserves insertion order. If not, add explicit ascending-createdAt sort to `readQueuedOperations`.

---

## Duplication

### 1. Facade-mode extraction helpers are file-private and cannot be reused

- `_normalizedFacadeMode`, `_operationFacadeMode`, `_operationFacadeId`, `_operationRuntimeContext` (lines 466–503) encode the `onyx_runtime_context` payload contract.
- If any other service (e.g., `guard_telemetry_ingestion_adapter.dart`) needs to read facade mode from an operation payload, it would re-implement this extraction.
- Centralization candidate: move to a domain helper on `GuardSyncOperation` itself (e.g., `operation.facadeMode`, `operation.facadeId`) or to a shared utility in the domain layer.

### 2. Delete-then-insert pattern duplicated across two Supabase save methods

- `saveAssignments` (line 282) and `saveQueuedOperations` (line 387) follow the same delete + conditional insert structure.
- If this pattern is kept for a reason, a private helper or shared RPC would reduce duplication and make the atomicity risk a single fix target.

### 3. Status-filter + facade-filter + limit logic duplicated across `SharedPrefs` and `FallbackGuardSyncRepository`

- `SharedPrefsGuardSyncRepository.readOperations` does in-memory filter+sort+limit.
- `_FakeGuardSyncRepository.readOperations` (in the test file, lines 283–292) re-implements a simplified version of this logic without facade filtering.
- The fake's missing facade filter means facade-filter behavior in the fallback path is not tested.

---

## Coverage Gaps

1. **`SupabaseGuardSyncRepository` has zero test coverage** — all three classes in production but only `SharedPrefs` and `Fallback` are exercised. The Supabase implementation contains the most complex and risky logic (delete-then-insert, N round-trips).
   - Missing: any test for `readAssignments`, `saveAssignments`, `readOperations`, `saveQueuedOperations`, `markOperationsSynced`, `retryFailedOperations` on the Supabase path.

2. **`FallbackGuardSyncRepository.readOperations` is not tested at all**.
   - Missing: primary success → fallback mirroring of queued-only; primary returns empty → fallback query; primary throws → fallback query.

3. **`FallbackGuardSyncRepository.markOperationsSynced` is not tested**.
   - Missing: primary throws, fallback still marks synced.

4. **`FallbackGuardSyncRepository.retryFailedOperations` is not tested**.
   - Missing: primary throws, fallback retried count returned; primary succeeds with 0, fallback also retried.

5. **`readOperations` with empty `statuses` set** — the Supabase path returns early (line 329–331), the SharedPrefs path implicitly returns empty via the `where` clause. Neither path is tested for this edge case.

6. **`_operationFacadeMode` string-branch** (lines 493–499) — the `raw is String` path with values like `'true'`, `'false'`, and an unknown string are not exercised by any test. Only the `bool` path is tested via fixtures.

7. **`retryFailedOperations` with a mix of failed and non-failed operations** in the same call — the test (line 86–117) only uses a pure-failed list. A mix (some queued, some failed) with the same IDs is not tested; the shared-prefs path's `operation.status != GuardSyncOperationStatus.failed` guard on line 101 is the correct skip, but this path is untested.

8. **`markOperationsSynced` in `SupabaseGuardSyncRepository`** filters by `operation_status = queued` (line 430). If a caller passes an ID that is in `failed` status, the server-side update silently does nothing. This silent no-op is not tested and not documented.

---

## Performance / Stability Notes

1. **Full-queue read-modify-write on every `markOperationsSynced` and `retryFailedOperations` call** in `SharedPrefsGuardSyncRepository` (lines 86–91, 96–113). Each call reads the entire stored list from SharedPrefs, mutates it, and writes it back. Under frequent sync cycles with large queues this is O(N) read + O(N) write per call.

2. **Full-queue fetch in `SharedPrefsGuardSyncRepository.readOperations`** (line 49) — all operations loaded from SharedPrefs before any filtering. No server-side pagination. This is acceptable for small queues but should be bounded by an upper limit in `DispatchPersistenceService`.

3. **N sequential Supabase round-trips in `retryFailedOperations`** (covered in P1 finding above) — this is the most concrete performance risk.

4. **`FallbackGuardSyncRepository.readAssignments` triggers a fallback `saveAssignments` on every successful primary read** (lines 130–132). If the fallback is `SharedPrefsGuardSyncRepository`, this is a SharedPrefs write on every assignment read. This warm-up write is correct by design but may be surprising in high-frequency polling contexts.

---

## Recommended Fix Order

1. **Fix non-atomic delete-then-insert in `saveQueuedOperations`** — highest safety risk; panic signals can be silently lost. (P1, REVIEW)
2. **Fix non-atomic delete-then-insert in `saveAssignments`** — same structural bug, lower operational risk than queue loss. (P1, REVIEW)
3. **Replace per-row update loop in `retryFailedOperations` with a batch call** — clear performance win, low risk. (P1, AUTO)
4. **Add tests for `FallbackGuardSyncRepository.readOperations`, `markOperationsSynced`, `retryFailedOperations`** — closes the largest coverage gap without touching production code. (Coverage, AUTO)
5. **Clarify and document the `failed`-status mirror asymmetry in `FallbackGuardSyncRepository.readOperations`** — low-effort clarification with product implications. (P2, DECISION)
6. **Move facade-mode extraction to domain model** — consolidates payload contract, enables reuse, makes it testable in isolation. (Duplication, REVIEW)
7. **Add `_operationFacadeMode` string-branch tests and empty-statuses edge-case tests** — closes residual coverage gaps. (Coverage, AUTO)
