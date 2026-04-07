# Audit: ExecutionEngine

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/engine/execution/execution_engine.dart` + call sites in `lib/application/dispatch_application_service.dart`, `lib/engine/vertical_slice_runner.dart`, `lib/application/app_state.dart`, `test/`
- Read-only: yes

---

## Executive Summary

`ExecutionEngine` is a stub — 31 lines, returning a hardcoded `true`. By itself the class is too thin to carry real risk, but the **call sites** around it reveal three meaningful bugs and one design gap that will matter the moment real execution logic lands. The most urgent concern is that `DispatchApplicationService.execute()` treats `engine.execute()` as infallible: no return-value check, no exception guard, and `ExecutionCompleted` is appended with `success: true` unconditionally regardless of what the engine actually did. That pairing is a latent persistence-correctness bug.

---

## What Looks Good

- `dispatchId` emptiness guard (line 13) and `authority.authorizedBy` guard (line 17) are the right defensive checks for a security-critical gate.
- The idempotency set `_executedDispatchIds` correctly blocks duplicate execution at the engine boundary.
- `StateError` (not a silent fallback) is thrown on duplicate — loud failure is appropriate here.
- Authority is threaded as a value object (`AuthorityToken`), not a raw string, which keeps the contract explicit.

---

## Findings

### P1 — Bug: `engine.execute()` return value is discarded in the primary call site

- **Action:** REVIEW
- **Finding:** `DispatchApplicationService.execute()` calls `engine.execute(dispatchId, authority: authority)` and ignores the `bool` result. `ExecutionCompleted` is always appended with `success: true` on the next line, unconditionally.
- **Why it matters:** When the stub is replaced with real logic, a failed execution will produce a `success: true` event in the event store. The projection will mark the dispatch `EXECUTED` when it was not. This is a persistence-correctness bug that replay will not catch because the event itself lies.
- **Evidence:** `lib/application/dispatch_application_service.dart` lines 736–749
  ```
  engine.execute(dispatchId, authority: authority);   // return value dropped
  ...
  success: true,                                      // hardcoded
  ```
- **Suggested follow-up:** Codex should confirm whether any test asserts on `success: false` paths; search for `ExecutionCompleted` construction sites to see if `success` is ever set from the engine result.

---

### P1 — Bug: `engine.execute()` can throw `StateError` on duplicate; caller has no guard

- **Action:** REVIEW
- **Finding:** `ExecutionEngine.execute()` throws `StateError('Duplicate execution attempt...')` if the same `dispatchId` is presented twice (line 21–24). `DispatchApplicationService.execute()` does not catch this. The `StateError` will propagate out of the `async execute()` method as an unhandled exception, crashing the caller.
- **Why it matters:** A double-tap of the execute button, a network retry, or a race between two operator sessions on the same dispatch could produce this crash. The event store would have no `ExecutionDenied` or `ExecutionCompleted` record — the dispatch would be stuck in `DECIDED` with no audit trail.
- **Evidence:** `lib/engine/execution/execution_engine.dart` lines 20–24; `lib/application/dispatch_application_service.dart` line 736 (no try/catch around the call).
- **Suggested follow-up:** Codex should check whether the pre-call state check (`if (status != 'DECIDED') return;`) is sufficient to fully prevent duplicates, or whether a concurrent path can bypass it.

---

### P2 — Bug: `AuthorityToken` constructed with `DateTime.now()` (no `.toUtc()`) in `DispatchApplicationService`

- **Action:** AUTO
- **Finding:** `AuthorityToken` is constructed at line 731–733 of `dispatch_application_service.dart` with `timestamp: DateTime.now()` (local time). All other `DateTime` stamps in the same file use `.toUtc()`. `VerticalSliceRunner` correctly uses `DateTime.now().toUtc()` (line 75).
- **Why it matters:** If `AuthorityToken.timestamp` is ever serialised, persisted, or compared across timezones the authority record will be inconsistent with the event timestamps it accompanies.
- **Evidence:** `lib/application/dispatch_application_service.dart` line 733 vs line 739 (`occurredAt: DateTime.now().toUtc()`).
- **Suggested follow-up:** Codex can safely apply `.toUtc()` — direct swap, no logic change.

---

### P2 — Structural: `ExecutionEngine` is a singleton-state object with no reset path

- **Action:** DECISION
- **Finding:** `_executedDispatchIds` is a mutable `Set<String>` held inside `ExecutionEngine`. The engine is constructed once in `AppState.initial()` and lives for the application lifetime. There is no `reset()`, `clear()`, or factory method for test isolation. The set grows indefinitely.
- **Why it matters:**
  1. In production: if the app restarts (hot restart in Flutter) a new `ExecutionEngine` is created, losing all knowledge of previously executed dispatches. Cross-session duplicate detection relies entirely on the event store / projection, not the engine — so the engine's idempotency set is only effective within a single app session.
  2. In tests: `dispatch_application_service_triage_test.dart` and `intake_stress_service_test.dart` each create a fresh `ExecutionEngine()`, which is correct today. But if tests share state (e.g. a future `setUp` refactor), duplicate-detection bugs will be masked.
- **Evidence:** `lib/engine/execution/execution_engine.dart` lines 4, 27; `lib/application/app_state.dart` line 22.
- **Suggested follow-up:** Decide whether cross-session duplicate detection should be owned by the event store projection (checking for existing `ExecutionCompleted` events) rather than in-memory engine state. The engine set and the projection-based check are currently doing different things; one of them should be canonical.

---

### P3 — Design: Return value of `execute()` is structurally misleading

- **Action:** REVIEW
- **Finding:** The stub always returns `true`. The method signature `bool execute(...)` implies a meaningful true/false, but:
  - On failure the method throws (not returns `false`).
  - In the one real call site, the return value is dropped entirely.
  This creates a contract where the return type carries no information in practice.
- **Why it matters:** When real logic is added, a developer may return `false` on failure expecting the caller to check it — but the caller never will, based on current code.
- **Evidence:** `lib/engine/execution/execution_engine.dart` lines 8, 29; `lib/application/dispatch_application_service.dart` line 736.
- **Suggested follow-up:** Either change the return type to `void` and rely entirely on exceptions for failure, or enforce that the return value is used at every call site.

---

## Duplication

- `AuthorityToken` is constructed in two places: `DispatchApplicationService.execute()` (line 731) and `VerticalSliceRunner.run()` (line 73). Both pass `operator.operatorId` / `'FOUNDER'` as `authorizedBy`. When the real engine validates authority more strictly, these two construction sites will need to stay in sync.
- No further duplication within the engine file itself (it is too small).

---

## Coverage Gaps

1. **No test file under `test/engine/`** — the directory does not exist. `ExecutionEngine` has zero direct unit tests. All coverage is incidental via `DispatchApplicationService` tests.
2. **Duplicate-execution error path is untested.** No test calls `engine.execute()` with the same `dispatchId` twice to confirm the `StateError` is thrown and handled (or not handled) correctly.
3. **`authority.authorizedBy` empty-string guard is untested.** No test passes an `AuthorityToken` with `authorizedBy: ''` to confirm the `StateError` fires.
4. **The `false` return path does not exist and is therefore untested** — but this is structural (see P3 above).
5. **`DispatchApplicationService.execute()` failure path is untested.** No test confirms what happens if `engine.execute()` throws — the outer `async` method will reject its future silently in the current test suite.

---

## Performance / Stability Notes

- `_executedDispatchIds` is an unbounded `Set<String>`. For a long-running session with thousands of dispatches this grows forever. Not a concern at current scale, but worth noting for a stateful desktop or web app that runs without restart.
- No performance concerns within the engine file itself given it is a stub.

---

## Recommended Fix Order

1. **(P1) Guard the `engine.execute()` return value** — capture the `bool` and pass it to `ExecutionCompleted.success`. This is the highest-risk correctness gap and will be trivially wrong the moment the stub becomes real.
2. **(P1) Add try/catch around `engine.execute()` in `DispatchApplicationService`** — emit `ExecutionDenied` on duplicate or unexpected throw so the event store always has an audit trail.
3. **(P2) Fix `DateTime.now()` → `DateTime.now().toUtc()`** in `AuthorityToken` construction — AUTO, safe mechanical change.
4. **(DECISION) Resolve idempotency ownership** — decide whether the engine set or the projection is the canonical duplicate guard and remove the other.
5. **(P3) Clarify return type contract** — make `void` + throw, or enforce usage at all call sites before real logic lands.
6. **Add `test/engine/execution_engine_test.dart`** — cover: empty `dispatchId`, empty `authorizedBy`, successful execute, duplicate execute (StateError), and the interaction between engine and `DispatchApplicationService.execute()` on the unhappy path.
