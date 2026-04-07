# Audit: dispatch_state_machine.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/engine/dispatch/dispatch_state_machine.dart`, `lib/engine/dispatch/dispatch_action.dart`, `lib/engine/dispatch/action_status.dart`, `lib/engine/vertical_slice_runner.dart`
- Read-only: yes

---

## Executive Summary

The state machine is small, structurally clean, and uses an exhaustive `switch` with no default fallthrough. The `DispatchAction.transition()` wrapper throws on illegal transitions, so the machine is not silent. However, there are three confirmed logical gaps in the transition graph, one semantic ambiguity that deserves a product decision, no concurrency protection at the call-site level, and zero meaningful tests of the machine's core behaviour. This is a medium-risk subsystem — the machine is correct for the happy path but unvalidated for failure paths.

---

## What Looks Good

- Exhaustive `switch` over `ActionStatus` — Dart will emit a compile warning if a new enum value is added without updating the switch. No implicit `default` escape hatch.
- `DispatchAction.transition()` throws `StateError` for illegal transitions (line 27). Callers cannot silently ignore a bad transition via the domain object.
- Terminal states (`aborted`, `overridden`, `failed`) all correctly return `false` for all targets. No resurrection paths exist.
- `DispatchAction` is immutable — `transition()` returns a new copy. No shared-mutable-state bugs inside the object itself.
- `domain/models/action_status.dart` and `domain/models/dispatch_action.dart` are shims that re-export the engine path. No divergent enum definitions.

---

## Full Transition Graph (derived from source)

```
decided     → committing   ✓
decided     → executed     ✓  (skip-committing fast path)
decided     → overridden   ✓
committing  → executed     ✓
committing  → aborted      ✓
committing  → overridden   ✓
executed    → failed       ✓  (see P1 — semantically ambiguous)
aborted     → (terminal)
overridden  → (terminal)
failed      → (terminal)
```

Absent transitions:
```
decided     → aborted      ✗  (no pre-commit operator abort path)
committing  → failed       ✗  (no commit-phase crash path)
decided     → failed       ✗  (no pre-commit system failure path)
```

---

## Findings

### P1 — `executed → failed` is semantically ambiguous

- **Action: DECISION**
- **Finding:** `executed` is the only non-terminal state that can reach `failed`. This implies `executed` means "execution was attempted" rather than "execution succeeded." But the name strongly implies success. If `executed` means success, then `failed` after it is contradictory. If `executed` means "the dispatch was sent," the terminal success state is missing entirely.
- **Why it matters:** Consumers reading `status == ActionStatus.executed` cannot tell whether the dispatch succeeded. Business logic built on that assumption (e.g., the vertical slice runner throwing `StateError` if status != `EXECUTED` at line 112) treats `executed` as success — but the machine allows `executed → failed`. A dispatch can be in `executed` and then transition to `failed`, making the replay check at line 112 of `vertical_slice_runner.dart` a false positive.
- **Evidence:**
  - `lib/engine/dispatch/dispatch_state_machine.dart:19–20` — `executed → failed` is legal
  - `lib/engine/vertical_slice_runner.dart:112` — replay check asserts `EXECUTED` as final success
- **Suggested follow-up:** Decide whether `executed` is a terminal-success state (remove `executed → failed`, add a separate `dispatched` or `sent` intermediate) or document explicitly that `executed` means "attempted" and add `succeeded` as a distinct terminal state.

---

### P2 — `committing → failed` transition is missing

- **Action: REVIEW**
- **Finding:** If the commit phase encounters an unrecoverable error (e.g., persistence failure, external system crash), there is no legal transition to `failed`. The only options from `committing` are `executed`, `aborted`, or `overridden`. A system crash mid-commit cannot be recorded as `failed` without bypassing the state machine entirely.
- **Why it matters:** Real-world commit phases can fail for reasons unrelated to an intentional abort or override. Forcing callers to use `aborted` for a system fault conflates operator intent with system failure. If callers record nothing (because they can't transition), the dispatch stays permanently stuck in `committing`.
- **Evidence:** `lib/engine/dispatch/dispatch_state_machine.dart:14–17` — `committing` has no `failed` target.
- **Suggested follow-up:** Codex should confirm whether any call site currently leaves a dispatch in `committing` on exception. If yes, this is a stale-state bug today, not a hypothetical.

---

### P3 — `decided → aborted` transition is missing

- **Action: REVIEW**
- **Finding:** There is no path from `decided` to `aborted`. If an operator wants to abort a dispatch before the commit phase begins, the only available transition is `decided → overridden`. This conflates "operator abort before commit" with "override during or after commit." Both outcomes end up in `overridden`, making audit trails ambiguous.
- **Why it matters:** Reporting and audit tooling that distinguishes `aborted` (system-initiated cancel) from `overridden` (operator-initiated cancel) will produce misleading counts if pre-commit operator cancels land in `overridden`.
- **Evidence:** `lib/engine/dispatch/dispatch_state_machine.dart:9–12` — `decided` has no `aborted` target.
- **Suggested follow-up:** Confirm the intended semantic split between `aborted` and `overridden` before adding the transition. This may be intentional product design.

---

### P4 — `vertical_slice_runner.dart` calls `canTransition()` directly instead of using `DispatchAction.transition()`

- **Action: AUTO**
- **Finding:** `vertical_slice_runner.dart` lines 64–71 call `DispatchStateMachine.canTransition()` directly and manually check the boolean. This bypasses the domain object's `transition()` method, which also produces the new `DispatchAction` instance. The check is used as a gate only, but the actual state change is then performed separately by `engine.execute()`. If the engine performs the status change internally, this check is redundant. If it doesn't, the status is never officially transitioned through the machine.
- **Why it matters:** Dual-path state mutation — one path through the domain object (`DispatchAction.transition()`), one through raw boolean check + external engine — creates drift risk. Future callers may copy the raw-check pattern, bypassing `transition()`'s throw guard.
- **Evidence:** `lib/engine/vertical_slice_runner.dart:64–71`
- **Suggested follow-up:** Codex should verify whether `engine.execute()` calls `DispatchAction.transition()` internally or mutates status through a different path. If the latter, this is a state machine bypass.

---

### P5 — No concurrency protection at call-site level

- **Action: REVIEW**
- **Finding:** `DispatchStateMachine.canTransition()` is a pure static function with no state. `DispatchAction` is immutable. Neither provides any atomicity guarantee. If two concurrent operations both read a `DispatchAction` with `status == decided`, both call `canTransition(decided, executed)`, receive `true`, and both call `transition()`, they each produce a valid new `DispatchAction(status: executed)`. The machine does not detect the double-fire.
- **Why it matters:** In an async Flutter app with multiple service layers touching the same dispatch ID, a race between two concurrent escalation paths (e.g., a user override and an automated execution) can produce two "legal" terminal states from a single decision, with no guard. Whether this is currently reachable depends on whether the persistence layer serialises writes by dispatch ID.
- **Evidence:** `lib/engine/dispatch/dispatch_state_machine.dart` — no locking or event-store check; `lib/application/dispatch_persistence_service.dart` — not inspected in this audit scope.
- **Suggested follow-up:** Audit `dispatch_persistence_service.dart` for optimistic concurrency control (e.g., version fields, compare-and-swap). If absent, this is a live race condition.

---

## Duplication

- `lib/domain/models/action_status.dart` and `lib/domain/models/dispatch_action.dart` are shim re-exports. The shim comment says "compatibility with older import paths." The canonical test (`dispatch_action_canonical_test.dart`) confirms both paths resolve to the same symbols. No actual duplication — but the shim adds indirection for no current benefit if all callers have migrated. This is low priority.

---

## Coverage Gaps

The only existing test file (`test/domain/dispatch_action_canonical_test.dart`) tests:
- Constructor aliasing (`dispatchId` vs `id`)
- Enum symbol name parity between domain and engine import paths

**Zero tests** cover the state machine's actual behaviour. The following tests are missing:

| Test case | Priority |
|---|---|
| Every legal transition returns `true` | High |
| Every illegal transition returns `false` | High |
| `DispatchAction.transition()` throws `StateError` on illegal input | High |
| Terminal states (`aborted`, `overridden`, `failed`) block all outbound transitions | High |
| `decided → executed` skip path (no committing) is legal | Medium |
| `executed → failed` is legal (documents the ambiguity from P1) | Medium |
| Attempting `committing → failed` throws (documents the gap from P2) | Medium |
| Two concurrent `transition()` calls from the same `decided` instance both succeed, proving no atomic guard | Low (concurrency awareness) |

---

## Performance / Stability Notes

- None specific to this file. The machine is a pure static boolean function with no I/O, no allocation, and no branching complexity. Performance is not a concern here.

---

## Recommended Fix Order

1. **DECISION (P1):** Resolve the `executed` semantic before any other changes — adding `committing → failed` (P2) or restructuring tests depends on knowing what `executed` means.
2. **REVIEW (P5):** Audit `dispatch_persistence_service.dart` for concurrency protection around dispatch status writes. If absent, this is the highest-risk live bug in the system.
3. **AUTO (P4):** Verify `engine.execute()` and determine if the raw `canTransition()` call in `vertical_slice_runner.dart` is a bypass or redundant guard. Remove the bypass if confirmed.
4. **REVIEW (P2):** Add `committing → failed` after P1 is resolved and the semantics of `failed` are confirmed.
5. **REVIEW (P3):** Decide `decided → aborted` vs `decided → overridden` semantics with Zaks before touching the graph.
6. **AUTO (coverage):** Add full transition matrix tests once P1 and P2 are resolved. Until then, tests will be written against a graph that may change.
