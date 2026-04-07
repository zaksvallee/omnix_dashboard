# Audit: guard_sync_repository.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/application/guard_sync_repository.dart`, `lib/domain/guard/guard_position_summary.dart`, `test/application/guard_sync_repository_test.dart`
- Read-only: yes

---

## Executive Summary

The file is well-structured with a clean three-implementation pattern: SharedPrefs (local), Supabase (remote), and Fallback (composite). The domain logic is correctly isolated from UI, and the persistence contract is clear. The test suite covers the most critical paths.

Three issues carry real production risk: (1) silent exception swallowing in `FallbackGuardSyncRepository` with no observability; (2) `SupabaseGuardSyncRepository.retryFailedOperations` issues N serial UPDATE round-trips and returns an over-counted value; (3) `_operationFacadeMode` silently assigns `'unknown'` to operations that have an `onyx_runtime_context` but no `telemetry_facade_live_mode` key, which can silently exclude valid operations from filtered reads. Coverage gaps exist for the Supabase read/filter paths.

---

## What Looks Good

- Three-implementation layering is sound. `FallbackGuardSyncRepository` delegates correctly and the composite pattern is easy to reason about.
- `saveAssignments` / `saveQueuedOperations` both guard the delete step behind the upsert — delete only runs after upsert succeeds, preventing data loss on write failure. Tests lock this ordering.
- `_latestGuardPositionsFromOperations` correctly deduplicates by guard, compares `recordedAtUtc` rather than `createdAt`, and sorts descending before returning.
- `SharedPrefsGuardSyncRepository.readOperations` applies deterministic tie-breaking via `operationId` when `createdAt` matches.
- `GuardPositionSummary.fromHeartbeatPayload` uses `fallbackRecordedAtUtc` only when `recorded_at` is absent from the payload — correct precedence.
- All row-to-model mappings use `?.toString()` + `?? ''` defensively, avoiding null crashes on unexpected Supabase responses.
- Epoch-zero sentinel (`DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)`) is consistent across both implementations and is easy to detect downstream.

---

## Findings

### P1 — Silent exception swallowing in `FallbackGuardSyncRepository`

- **Action:** REVIEW
- **Finding:** Every `try { ... } catch (_) {}` block in `FallbackGuardSyncRepository` swallows exceptions with no log, metric, or rethrow. Primary failures are invisible in production.
- **Why it matters:** If Supabase connectivity degrades silently, the app falls back to stale SharedPrefs data without any signal to operators or the sync layer. Repeated silent failures will not surface until data staleness causes a visible UI problem.
- **Evidence:** Lines 137–143, 148–153, 158–163, 169–176, 186–207, 218–221, 226–230, 237–239 — all `catch (_) {}` blocks.
- **Suggested follow-up:** Replace bare `catch (_) {}` with a minimal error-reporting hook (e.g., `onPrimaryError` callback or a logger) injected at construction time. The fallback behavior stays the same; visibility changes.

---

### P1 — `SupabaseGuardSyncRepository.retryFailedOperations` issues N serial round-trips and over-counts

- **Action:** REVIEW
- **Finding:** After fetching `failed` rows in a single SELECT (lines 478–485), the method loops over each row and issues an individual `await client.update(...)` call per row (lines 487–503). For N failed operations this is N sequential Supabase round-trips. The method then returns `failedRows.length` — the count of rows fetched as `failed` — not the count of rows actually updated.
- **Why it matters:**
  1. **Performance:** N serial round-trips for what should be a single batch UPDATE. Under load (e.g., a guard returning online after a connectivity gap with 20+ failed ops) this creates unnecessary latency.
  2. **Semantic bug:** Between the SELECT (line 478) and the per-row UPDATEs (line 494), another process could have already re-queued or deleted a row. The returned count reflects the pre-update state, not post-update truth. Callers that use the return value to decide further action will make decisions on stale data.
- **Evidence:** `lib/application/guard_sync_repository.dart` lines 476–504.
- **Suggested follow-up for Codex:** Validate whether the Supabase Flutter client supports a batch update with `inFilter('operation_id', operationIds).eq('operation_status', 'failed')` — if so, replace the loop with a single update call. The return value should be derived from a post-update SELECT or accepted as approximate and documented as such.

---

### P1 — `_operationFacadeMode` assigns `'unknown'` to operations that have context but no mode key

- **Action:** REVIEW
- **Finding:** `_operationFacadeMode` returns `'unknown'` when `onyx_runtime_context` is present but `telemetry_facade_live_mode` is absent or unrecognized (line 643: `if (context != null) return 'unknown'`). Operations in this state will not match `facadeMode == 'live'` or `facadeMode == 'stub'` filters, silently excluding them from filtered reads.
- **Why it matters:** A guard operation recorded before the `telemetry_facade_live_mode` key was introduced — or one whose value is a non-boolean non-string type — gets classified as `'unknown'` and is invisible to any `facadeMode: 'live'` or `facadeMode: 'stub'` query. This is a silent data loss path for historical operations.
- **Evidence:** `lib/application/guard_sync_repository.dart` lines 631–645, specifically line 643. Also affects `SharedPrefsGuardSyncRepository.readOperations` filter at lines 58–70 via `_normalizedFacadeMode` + `_operationFacadeMode`.
- **Suggested follow-up for Codex:** Confirm whether `'unknown'` is a valid filter target or whether callers should be able to request `{live, stub, unknown}` explicitly. If `'unknown'` is a valid category, document it in the abstract. If not, returning `null` when context is present but mode is absent would be safer.

---

### P2 — `FallbackGuardSyncRepository.retryFailedOperations` return value is incorrect when primary succeeds with 0

- **Action:** REVIEW
- **Finding:** `return primaryRetried ?? fallbackRetried` (line 241). `??` is null-coalescing, not falsy. If the primary succeeds but finds 0 failed operations (returns `0`), the fallback's retried count is ignored and `0` is returned — even if the fallback retried operations.
- **Why it matters:** In a dual-write setup where both primary and fallback hold state, a caller that uses the return value to decide whether to trigger further sync will see `0` and skip re-sync even though fallback operations were actually re-queued.
- **Evidence:** `lib/application/guard_sync_repository.dart` lines 234–242.
- **Suggested follow-up for Codex:** Determine the intended contract. If the intent is "primary is authoritative, fallback count is noise," document it explicitly. If the intent is "total retried across both backends," use `(primaryRetried ?? 0) + fallbackRetried`.

---

### P2 — `_deleteScopedQueuedOperations` does not prune `failed` rows on Supabase

- **Action:** REVIEW
- **Finding:** `_deleteScopedQueuedOperations` adds a `.eq('operation_status', 'queued')` guard (line 531), which means only rows in `queued` state are pruned after a `saveQueuedOperations` call. Rows that transitioned to `failed` before the next save are permanently retained in Supabase unless explicitly cleared by another path.
- **Why it matters:** In a long-running guard session with repeated sync failures, the `guard_sync_operations` table accumulates `failed` rows indefinitely. There is no visible retention policy or TTL for these rows in this file.
- **Evidence:** `lib/application/guard_sync_repository.dart` lines 522–536.
- **Suggested follow-up for Codex:** Confirm whether there is a separate cleanup job for `failed` rows. If not, consider whether `retryFailedOperations` or a separate `pruneStaleOperations` path should handle cleanup after a configurable retention window.

---

### P3 — `readLatestGuardPositions` in `SupabaseGuardSyncRepository` is hard-limited to 500 rows with no guard

- **Action:** REVIEW
- **Finding:** The Supabase query at line 346 limits to 500 rows. If a site has more than 500 guards active (or many heartbeats from a smaller guard pool), the `_latestGuardPositionsFromOperations` function may not receive the most recent heartbeat for guards whose records fall outside the limit.
- **Why it matters:** Since the query is ordered by `occurred_at DESC`, the 500 rows will be the most recent globally — but for a guard whose last heartbeat is older than the 500th most recent row across all guards, they will disappear from the position map.
- **Evidence:** `lib/application/guard_sync_repository.dart` lines 336–348.
- **Suggested follow-up for Codex:** Verify the typical maximum guard count per site. If it reliably stays under ~100, the limit of 500 is safe with margin. If it could reach hundreds, consider a `DISTINCT ON (guard_id)` approach or a dedicated last-position materialized view.

---

## Duplication

### Row-to-model mapping duplicated between `_guardOperationFromRow` and inline mapping in `readOperations`

- `_guardOperationFromRow` (lines 582–606) and the inline `.map((row) => GuardSyncOperation(...))` inside `SupabaseGuardSyncRepository.readOperations` (lines 396–422) are near-identical.
- The inline version does not map `operation_id` from a `facade_id`/`facade_mode` column — those fields come from `payload.onyx_runtime_context` — so the structural difference is real but minor (select column list differs slightly).
- The two deserialization blocks could share a common private helper, reducing the risk of divergence if `GuardSyncOperation` grows fields.
- **Files involved:** Lines 396–422 and 582–606, both in `lib/application/guard_sync_repository.dart`.
- **Centralization candidate:** A single `_guardOperationFromRow(Map row)` function covering both use cases, with the `_guardOperationFromRow` call inside `readLatestGuardPositions` already using the extracted version — only `readOperations` needs to be redirected.

---

## Coverage Gaps

1. **`SupabaseGuardSyncRepository.readOperations` with facade filters** — no test exercises the `facadeMode` or `facadeId` filter paths against the Supabase mock. If the filter query params are wrong, no test will catch it.

2. **`SupabaseGuardSyncRepository.retryFailedOperations`** — no test. The serial-loop bug and the over-counted return value are untested. This is the highest-impact untested path.

3. **`SupabaseGuardSyncRepository.markOperationsSynced`** — no test validates that the Supabase query correctly scopes to `operation_status = 'queued'` before updating. A row already `failed` should not be marked synced.

4. **`FallbackGuardSyncRepository.retryFailedOperations` return value edge case** — no test for the case where `primaryRetried = 0` and `fallbackRetried > 0`. The `??` semantics are untested.

5. **`FallbackGuardSyncRepository` when primary returns empty list** — `readAssignments` and `readQueuedOperations` fall through to fallback only on exception, not on empty list. But `readOperations` falls through on empty result (line 195: `if (operations.isNotEmpty)`). This inconsistency is untested and may be intentional — needs explicit test confirming the design decision.

6. **`_operationFacadeMode` returning `'unknown'` and its filter effect** — no test for an operation with `onyx_runtime_context` but missing `telemetry_facade_live_mode`. The silent exclusion path is unverified.

7. **`GuardPositionSummary.fromHeartbeatPayload` `recorded_at` fallback** — the fallback to `fallbackRecordedAtUtc` when `recorded_at` is absent is covered implicitly by the SharedPrefs position test (which includes `recorded_at`), but the fallback path itself (no `recorded_at` in payload) is never exercised. If `_latestGuardPositionsFromOperations` uses `createdAt` as fallback for timestamp comparison, a payload without `recorded_at` could return a stale-timestamp position that sorts incorrectly.

---

## Performance / Stability Notes

1. **`SupabaseGuardSyncRepository.retryFailedOperations` — N serial round-trips** (covered in P1 above). Most impactful performance issue in this file.

2. **`SharedPrefsGuardSyncRepository.readOperations` loads all operations then filters in-memory.** For a large queue (thousands of operations after a connectivity outage), this reads the full blob from SharedPrefs before filtering. The SharedPrefs blob is bounded by `saveQueuedOperations` pruning, but if pruning is not called frequently, the blob grows. No explicit size guard is present.

3. **`FallbackGuardSyncRepository.readOperations` can trigger a fallback `saveQueuedOperations` write on every successful primary read** (lines 196–203). If this method is called frequently (polling loop), the fallback write on every call creates write amplification. A staleness check or dirty flag would reduce this.

---

## Recommended Fix Order

1. **Add error observability to `FallbackGuardSyncRepository`** (`catch (_) {}` blocks) — zero behavior change, high observability gain. AUTO candidate once logging approach is confirmed.
2. **Replace `retryFailedOperations` serial loop with batch update** in `SupabaseGuardSyncRepository` — eliminates N round-trips and fixes over-count return value. Requires Codex to confirm Supabase client batch update API.
3. **Add tests for `SupabaseGuardSyncRepository.retryFailedOperations` and `markOperationsSynced`** — lock the most untested high-risk paths before they reach production.
4. **Document or fix `_operationFacadeMode` `'unknown'` behavior** — either add `'unknown'` as an explicit queryable value in the abstract contract, or change the function to return `null` for ambiguous context.
5. **Add test for `FallbackGuardSyncRepository` primary-empty vs primary-exception asymmetry** — confirm the design decision is intentional.
6. **Investigate failed-row retention policy** for `_deleteScopedQueuedOperations` — either document the external cleanup job or add a retention sweep.
