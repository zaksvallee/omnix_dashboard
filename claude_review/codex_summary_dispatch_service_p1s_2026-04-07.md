# Codex Summary — Dispatch Service P1s (2026-04-07)

## Scope

Implemented the approved `dispatch_application_service.dart` P1 fixes:

1. Await intelligence ledger sealing instead of fire-and-forget.
2. Reverse `execute()` ordering so `sealDispatch()` happens before `ExecutionCompleted` is appended.
3. Replace `sequence: 0` placeholders in the service with explicit sequence allocation.
4. Replace truncated dispatch IDs with full-provider deterministic IDs plus UUID-form suffixes.

Also updated the small set of async call sites that rely on `ingestNormalizedIntelligence()`.

## Code Changes

### 1. Awaited ledger sealing

- `DispatchApplicationService.ingestNormalizedIntelligence(...)` is now `async`.
- The method now `await`s `ledgerService.sealIntelligenceBatch(...)` before returning.
- This required call-site updates in:
  - `lib/main.dart`
  - `lib/application/intake_stress_service.dart`

### 2. Execute ordering

- `execute()` now:
  - verifies authority
  - runs the execution engine
  - builds the `ExecutionCompleted` event
  - awaits `ledgerService.sealDispatch(...)` against the pre-execution event stream
  - appends `ExecutionCompleted`
  - verifies replay
- This prevents the completion event from being written before dispatch sealing.

### 3. Sequence allocation

- Added explicit helpers in `DispatchApplicationService`:
  - `_nextGlobalSequence(...)`
  - `_nextSequenceForDispatch(...)`
- Replaced service-created `sequence: 0` placeholders with real sequence values.
- Radio ingest and radio automated-response ingest now track provisional in-batch events so multiple generated events in one pass do not reuse the same sequence.
- Dispatch-bound events now allocate sequence monotonically per dispatch from the existing store plus provisional pending events.

### 4. Dispatch ID stability / collision hardening

- `_dispatchIdForExternal(...)` no longer truncates provider names to four characters.
- Dispatch IDs now use:
  - full sanitized provider string
  - deterministic UUID-shaped suffix derived from `sha256(provider|externalId)`
- Result:
  - same provider/external input remains stable for dedupe
  - different providers that previously collided on the same first four characters no longer collide

## Validation

Focused tests:

- `flutter test test/application/dispatch_application_service_triage_test.dart`

New / updated regressions in that file cover:

- awaited ledger sealing before `ingestNormalizedIntelligence()` returns
- `execute()` sealing before `ExecutionCompleted` append
- monotonic per-dispatch sequence allocation
- full-provider deterministic dispatch IDs with collision protection

Analyze:

- `dart analyze lib/application/dispatch_application_service.dart lib/application/intake_stress_service.dart lib/main.dart test/application/dispatch_application_service_triage_test.dart`

Result: clean.

## Notes

- `ingestNormalizedIntelligence(...)` is now asynchronous, so callers must await it to preserve the ledger guarantee.
- This batch intentionally left `DeterministicIntelligenceIngestionService` unchanged; the approved P1 scope was the application-service layer and its direct call paths.
