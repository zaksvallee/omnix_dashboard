# Codex Summary: Evidence Critical Fixes

- Date: 2026-04-07
- Scope: evidence ledger serialization, duplicate sealing, durability on persistence failure, and export hash verification

## Implemented

### Critical Fix 1 — Dispatch seals now persist actual event JSON
- Updated `/Users/zaks/omnix_dashboard/lib/domain/events/decision_created.dart`
- Updated `/Users/zaks/omnix_dashboard/lib/domain/events/execution_completed.dart`
- Updated `/Users/zaks/omnix_dashboard/lib/domain/evidence/client_ledger_service.dart`
- `DecisionCreated` and `ExecutionCompleted` now expose `toJson()` and JSON `toString()` output.
- `ClientLedgerService.sealDispatch(...)` now seals structured event maps instead of `"Instance of ..."` strings.

### Critical Fix 2 — Duplicate intelligence seals no longer append duplicate rows
- Updated `/Users/zaks/omnix_dashboard/lib/domain/evidence/client_ledger_service.dart`
- Added a pre-insert existence check using the existing persisted ledger row keyed by `clientId + recordId`.
- Re-sealing the same intelligence batch now returns the existing row instead of writing a second chained record.
- This was landed schema-safe without assuming a new Supabase column or migration.

### Critical Fix 3 — Ledger persistence failures no longer silently discard evidence
- Updated `/Users/zaks/omnix_dashboard/lib/domain/evidence/client_ledger_service.dart`
- Updated `/Users/zaks/omnix_dashboard/lib/infrastructure/events/supabase_client_ledger_repository.dart`
- Updated `/Users/zaks/omnix_dashboard/lib/main.dart`
- Added an in-memory pending evidence queue in `ClientLedgerService`.
- If `fetchPreviousHash`, `fetchLedgerRow`, or `insertLedgerRow` fails, the canonical evidence payload is queued for retry instead of being discarded.
- Pending evidence flushes in order on the next seal attempt.
- Supabase ledger repository now logs and rethrows persistence/query failures instead of swallowing them.
- The direct Telegram AI ledger path now routes through `ClientLedgerService`, so it benefits from the same queue/retry behavior.

### Critical Fix 4 — Export now re-verifies stored ledger hash before issuing certificate
- Updated `/Users/zaks/omnix_dashboard/lib/application/evidence_certificate_export_service.dart`
- Export now re-derives the expected ledger hash from `canonicalJson + previousHash`.
- On mismatch, export throws and refuses to issue a certificate.
- Export payload now includes `ledger.hashVerified`.

## Tests Added / Updated

- `/Users/zaks/omnix_dashboard/test/domain/evidence/client_ledger_service_test.dart`
  - dispatch seal stores human-readable JSON
  - intelligence seal is idempotent
  - queue + flush on `fetchPreviousHash` failure
  - queue + flush on insert failure
- `/Users/zaks/omnix_dashboard/test/application/evidence_certificate_export_service_test.dart`
  - export includes verified ledger state
  - tampered ledger hash refuses export
- `/Users/zaks/omnix_dashboard/test/infrastructure/events/supabase_client_ledger_repository_test.dart`
  - `fetchPreviousHash` rethrows instead of swallowing
  - `insertLedgerRow` rethrows instead of swallowing

## Validation

- `dart analyze` on all touched ledger files/tests: passed
- `flutter test /Users/zaks/omnix_dashboard/test/domain/evidence/client_ledger_service_test.dart /Users/zaks/omnix_dashboard/test/application/evidence_certificate_export_service_test.dart /Users/zaks/omnix_dashboard/test/infrastructure/events/supabase_client_ledger_repository_test.dart`: passed
- `flutter test /Users/zaks/omnix_dashboard/test/application/offline_incident_spool_service_test.dart /Users/zaks/omnix_dashboard/test/application/dispatch_application_service_triage_test.dart`: passed

## Residual Risk

- This batch does not add a DB-level atomic constraint or transaction around the hash-chain append. It prevents duplicate re-seals and prevents silent evidence loss, but a true multi-writer DB-level fork guard still needs a schema/transaction decision if multiple independent writers can seal the same client concurrently.
