# Audit: client_conversation_repository.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/application/client_conversation_repository.dart` + `test/application/client_conversation_repository_test.dart`
- Read-only: yes

---

## Executive Summary

The file is well-structured and shows clear intent: an abstract repository interface, two local-storage implementations (unscoped and scoped), a Supabase backend implementation, and a fallback wrapper that composes primary + local. The merge helpers and sync-key functions are correct in isolation. However, there are four meaningful risk areas:

1. A silent double-query retry pattern inside `SupabaseClientConversationRepository` that swallows all errors and re-issues a narrowed SELECT or INSERT — this masks real failures and risks inserting duplicate rows.
2. `saveAcknowledgements` and `savePushQueue` in `SupabaseClientConversationRepository` each call `readMessages`/`readPushQueue` internally, creating a hidden N+1 and making `saveAcknowledgements(empty)` trigger a full-scope DELETE with no guard for partial Supabase failure.
3. The merge key for `_mergeConversationMessages` includes `messageSource` and `messageProvider`, but the remote sync key (`_conversationMessageRemoteSyncKey`) does not — these two key functions diverge on purpose (the contract doc confirms it), but that asymmetry is not documented in code and is a future maintenance trap.
4. `SharedPrefsClientConversationRepository` (the unscoped class) still exists and is not used by `buildScopedClientConversationRepository`, creating dead public surface.

Overall quality is **above average** for this codebase. The fallback pattern is sound and well-tested. Risks are concentrated in the Supabase write paths.

---

## What Looks Good

- Abstract interface is minimal and consistent — all four resource types follow the same read/save contract.
- `buildScopedClientConversationRepository` returns `null` on bad input rather than throwing, preventing crash on startup with missing config.
- Fallback repository mirrors writes locally even when the primary fails — the local cache stays authoritative.
- Merge logic for acknowledgements and push queue uses `putIfAbsent` correctly: primary wins over fallback on key collision.
- `readPushSyncState` in `FallbackClientConversationRepository` applies a meaningful heuristic (`_hasMeaningfulPushSyncState`) rather than a naive non-null check.
- Test coverage is solid for the fallback layer and remote-sync helpers. The `_FakeClientConversationRepository` is well-designed with independent read/write throw flags.

---

## Findings

### P1 — Swallowed errors in `readMessages` / `readPushQueue` silent retry
- **Action:** REVIEW
- **Finding:** `SupabaseClientConversationRepository.readMessages()` (lines 481–503) and `readPushQueue()` (lines 664–686) each catch all errors from the full-column SELECT and silently retry with a reduced column set. If the first call fails for any reason other than a missing column (network drop, RLS rejection, malformed response), the second call runs anyway and returns a potentially empty or wrong result. The caller has no visibility into which path executed.
- **Why it matters:** A transient network error triggers the narrowed SELECT. That SELECT may succeed and return rows where `messageSource`/`deliveryProvider` default to `in_app` — permanently. On the next `saveMessages`, those defaulted values become the inserted truth and overwrite real provider data in the fallback cache.
- **Evidence:** `lib/application/client_conversation_repository.dart` lines 481–503, 664–686
- **Suggested follow-up:** Codex should validate whether the outer `FallbackClientConversationRepository` already catches the full exception and falls back to local before the Supabase retry path is reached. If so, the inner retry in `SupabaseClientConversationRepository` is unnecessary and should be removed. If not, the retry should only catch a schema-column error (e.g. Postgres error code 42703), not all exceptions.

---

### P1 — `saveAcknowledgements(empty)` triggers unconditional full-scope DELETE
- **Action:** REVIEW
- **Finding:** `SupabaseClientConversationRepository.saveAcknowledgements()` (lines 620–626) deletes all acknowledgement rows for `client_id + site_id` when the input list is empty, with no prior check or guard. There is no `try/catch` on this DELETE. If a caller passes an empty list due to a local state bug (e.g., list not yet loaded), all remote acknowledgements are permanently deleted.
- **Why it matters:** The same pattern exists in `savePushQueue` (lines 697–703). Both are destructive ops with no rollback and no error guard. `FallbackClientConversationRepository.saveAcknowledgements` does not guard against this — it passes the empty list straight through to both primary and fallback.
- **Evidence:** `lib/application/client_conversation_repository.dart` lines 609–661 (`saveAcknowledgements`), 689–732 (`savePushQueue`)
- **Suggested follow-up:** Codex should check callers of `saveAcknowledgements` and `savePushQueue` — if any call site can pass an empty list that was produced by a failed read (not a deliberate clear), the delete is a data-loss risk. At minimum, the delete should be wrapped in a try/catch consistent with the rest of the write path.

---

### P2 — N+1 read inside `saveMessages` and `savePushQueue`
- **Action:** AUTO
- **Finding:** `SupabaseClientConversationRepository.saveMessages()` (line 510) calls `readMessages()` internally to compute missing rows before inserting. `saveAcknowledgements()` calls `readAcknowledgements()` (line 616), and `savePushQueue()` calls `readPushQueue()` (line 693). When called via `FallbackClientConversationRepository.saveMessages()`, the outer layer first calls `primary.saveMessages()` which itself reads from Supabase — making every write a read+write round-trip to Supabase.
- **Why it matters:** Under normal sync cadence this is tolerable, but if sync is called on every message addition, this doubles Supabase round-trips and doubles RLS evaluation cost. The internal read errors are silently swallowed (lines 615–619, 690–696), making read failures invisible.
- **Evidence:** Lines 510–527, 613–619, 691–696
- **Suggested follow-up:** Codex should check the call sites that invoke `saveMessages` to determine frequency. If called on every local state change (not just on batch sync), this is a hot-path issue. Consider accepting `existingMessages` as a parameter so the caller can supply the already-loaded list.

---

### P2 — Divergent merge keys: `_mergeConversationMessages` vs `_conversationMessageRemoteSyncKey`
- **Action:** REVIEW
- **Finding:** The in-memory merge key (lines 62–71) includes `messageSource` and `messageProvider`. The remote sync key (lines 127–134) excludes them. This is intentional per the contract doc (rollout safety), but the code has no comment explaining why they differ. A future contributor maintaining these two functions in tandem is likely to "align" them and break the rollout behavior.
- **Why it matters:** The divergence is load-bearing. Removing `messageSource`/`messageProvider` from the merge key would cause duplicate messages to appear in the UI when source/provider differ between local and remote. Adding them to the remote sync key would cause messages to be re-inserted to Supabase unnecessarily during schema rollout.
- **Evidence:** Lines 52–78 (`_mergeConversationMessages`), lines 126–135 (`_conversationMessageRemoteSyncKey`)
- **Suggested follow-up:** Codex should add a short comment above `_conversationMessageRemoteSyncKey` referencing the rollout intent. No logic change required.

---

### P3 — `SharedPrefsClientConversationRepository` is dead public surface
- **Action:** AUTO
- **Finding:** `SharedPrefsClientConversationRepository` (lines 193–240) is a public class with no `clientId`/`siteId` scope. `buildScopedClientConversationRepository` never constructs it — it always uses `ScopedSharedPrefsClientConversationRepository`. No other file in the repo appears to reference it.
- **Why it matters:** It exposes a different persistence key namespace (unscoped) through the same interface as the scoped version. If accidentally used, data written by the scoped repo would be invisible to it and vice versa. Its continued existence invites misuse.
- **Evidence:** Lines 193–240
- **Suggested follow-up:** Codex should grep for `SharedPrefsClientConversationRepository` across the codebase (excluding `Scoped` prefix). If the only references are in this file and the test file, the class is unused and can be removed. The test at line 15 covers it — that test would need removal too.

---

### P3 — `_FakeClientConversationRepository.throwOnRead` applies to all resource types uniformly
- **Action:** REVIEW
- **Finding:** The test fake (test file lines 519–603) uses a single `throwOnRead` flag that applies to messages, acknowledgements, push queue, and push sync state simultaneously. This means there is no test for a scenario where, e.g., `readMessages` succeeds but `readAcknowledgements` fails — which is a realistic partial-failure mode when Supabase RLS policies differ per table.
- **Why it matters:** The fallback behavior is per-method. A per-resource throw flag would allow isolation of which resource type triggered the fallback.
- **Evidence:** Test file lines 519–603
- **Suggested follow-up:** This is a test quality gap. Codex can extend `_FakeClientConversationRepository` to accept per-resource throw flags without changing production code.

---

## Duplication

### Schema-retry pattern repeated three times
- **Files:** `lib/application/client_conversation_repository.dart` lines 481–503, 506–527, 664–686, 689–732
- **Pattern:** `try { full-column query } catch (_) { reduced-column query }` — the same structural block appears for `readMessages`, `saveMessages`, `readPushQueue`, and `savePushQueue`.
- **Centralization candidate:** A small helper `_withColumnFallback<T>(Future<T> Function() full, Future<T> Function() reduced)` would eliminate repetition and make the swallow-all policy explicit in one place. This is a minor cleanup, not a correctness risk.

### Stale-row deletion loop repeated
- **Files:** Lines 651–660 (acknowledgements), lines 724–731 (push queue)
- **Pattern:** `for (final item in staleItems) { await client.from(...).delete()... }` — sequential per-row deletes. Both loops are identical in structure.
- **Risk:** For large stale sets this is O(n) round-trips. A batch delete using `.in_('message_key', staleKeys)` would be equivalent and more efficient. Not a current bug, but a future performance risk as queue size grows.

---

## Coverage Gaps

1. **`SupabaseClientConversationRepository` is entirely untested.** All Supabase-layer behavior (read, save, merge logic triggered by `FallbackClientConversationRepository`) is validated only via the fake. No test covers the actual query construction, row mapping, or schema-retry behavior.
   - Priority: medium. The fake is sufficient for fallback logic but gives no confidence in the Supabase layer.
   - Codex note: Integration tests would require a live Supabase instance or a mock HTTP layer. At minimum, unit tests for `_mapMessageRows`, `_mapPushQueueRows`, and `_messageRows` can be added without a live connection.

2. **Empty-list save behavior for `saveAcknowledgements` and `savePushQueue` is not tested.** The destructive delete path (lines 620–626, 697–703) has no test coverage.
   - Priority: high, given the P1 finding above.

3. **`buildScopedClientConversationRepository` with empty `clientId` or `siteId` returns `null` — not tested.** The test group for the builder (line 457) only tests the positive paths.
   - Priority: low. The null guard is simple, but a regression test would lock it.

4. **`readPushSyncState` fallback when both primary and fallback return idle.** The `_hasMeaningfulPushSyncState` logic is tested implicitly but the specific case where `fallbackState` is also idle is not explicitly covered.
   - Priority: low.

5. **Schema-retry paths in `readMessages` and `readPushQueue` are not tested.** The catch block that re-issues a reduced SELECT is never exercised by the current test suite.
   - Priority: medium given the P1 finding.

---

## Performance / Stability Notes

- **Sequential stale-row deletes** in `saveAcknowledgements` (lines 651–660) and `savePushQueue` (lines 724–731) issue one DELETE per stale row. Under normal conditions this is fine. If the push queue grows to dozens of stale rows (e.g., after a sync pause), this becomes a chatty path. A single `.in_()` batch delete is the standard Supabase pattern for this case.
- **`savePushSyncState` serializes `history` and `backendProbeHistory` as JSON arrays** (lines 826–834). If history is unbounded and callers append on every sync attempt, the JSON blob written to Supabase grows over time. No truncation or cap is visible in this file. This is a long-term stability concern if history arrays are not pruned at the call site.
- **`FallbackClientConversationRepository.readMessages`** awaits the fallback first, then awaits the primary (lines 337–351). These are sequential, not parallel. A concurrent read (using `Future.wait`) would reduce read latency on the happy path. This is a minor optimization, not a current issue.

---

## Recommended Fix Order

1. **[P1] Audit callers of `saveAcknowledgements` and `savePushQueue` for empty-list risk.** This is the highest-consequence bug candidate — a destructive remote DELETE triggered by an accidental empty list has no recovery path.
2. **[P1] Narrow the schema-retry catch clauses** in `readMessages`/`readPushQueue`/`saveMessages`/`savePushQueue` to only handle column-not-found errors, or remove them entirely if the outer `FallbackClientConversationRepository` already provides the necessary guard.
3. **[AUTO] Add a comment above `_conversationMessageRemoteSyncKey`** explaining the intentional omission of `messageSource`/`messageProvider` relative to the merge key.
4. **[AUTO] Confirm and remove `SharedPrefsClientConversationRepository`** if it is genuinely unused — reduces surface area and removes the namespace collision risk.
5. **[Coverage] Add tests for the empty-list delete paths** (`saveAcknowledgements([])`, `savePushQueue([])`).
6. **[Coverage] Add per-resource throw flags to `_FakeClientConversationRepository`** to enable partial-failure tests.
7. **[Performance] Replace sequential per-row stale deletes** with a single batch delete using `.in_()`.
