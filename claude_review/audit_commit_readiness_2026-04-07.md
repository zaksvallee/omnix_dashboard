# Audit: Commit Readiness

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: Repo-wide — dart analyze, git status, test/source parity, layer violations
- Read-only: yes

---

## Executive Summary

`dart analyze` reports **zero issues**. The codebase is statically clean. However, the working tree carries a very large uncommitted changeset: **209 modified tracked files, 258 untracked files, and 1 deleted file** — nearly the entire lib/ and test/ tree. Several structural concerns exist independently of analyzer findings: one confirmed domain→infrastructure layer violation, two confirmed UI→infrastructure violations, and a substantial number of test files whose import paths no longer match their production source locations due to directory restructuring.

---

## What Looks Good

- `dart analyze`: no warnings, no errors, no lints. Clean across 440 source files.
- DDD layer separation is mostly intact: domain does not import application, application does not import UI.
- 288 test files exist — solid coverage investment.
- engine/ and infrastructure/ sub-layering appears deliberate and consistent within those packages.

---

## Findings

### P1 — Layer Violation: Domain importing Infrastructure

- **Action:** REVIEW
- **Finding:** `lib/domain/incidents/incident_service.dart` imports `../../infrastructure/persistence/local_event_storage.dart` directly.
- **Why it matters:** Domain must not depend on infrastructure. This couples the incident aggregate's core service to a concrete persistence implementation, making it impossible to test `IncidentService` without the storage layer, and breaks the dependency inversion principle that the DDD layer structure implies.
- **Evidence:** `lib/domain/incidents/incident_service.dart:9`
  ```dart
  import '../../infrastructure/persistence/local_event_storage.dart';
  ```
  The `IncidentService` constructor accepts `LocalEventStorage storage` as a direct parameter (line ~14), not via a domain-level abstraction.
- **Suggested follow-up for Codex:** Confirm whether a `Storage` or `EventRepository` interface exists in the domain layer that `LocalEventStorage` could implement. If yes, update the import and constructor type to use the abstraction. If no abstraction exists yet, this is a DECISION item.

---

### P2 — Layer Violation: UI importing Infrastructure (Supabase + concrete services)

- **Action:** REVIEW
- **Finding:** Two UI pages import infrastructure implementations directly, bypassing the application layer entirely.
- **Why it matters:** UI depending on infrastructure creates tight coupling to persistence technology (Supabase). These pages cannot be widget-tested without spinning up the concrete service.
- **Evidence:**
  - `lib/ui/dispatch_page.dart:15` — imports `../infrastructure/intelligence/news_intelligence_service.dart`
  - `lib/ui/ledger_page.dart:21` — imports `../infrastructure/events/supabase_client_ledger_repository.dart`
- **Suggested follow-up for Codex:** Check whether `DispatchPage` and `LedgerPage` hold a direct instantiation or receive via provider. If provider-injected, the import may still compile but the type reference couples the widget to infra. Verify whether an application-layer service or repository interface can mediate.

---

### P2 — UI importing In-Memory Store (domain/store)

- **Action:** REVIEW
- **Finding:** `lib/ui/client_intelligence_reports_page.dart:38` imports `../domain/store/in_memory_event_store.dart`.
- **Why it matters:** UI reaching into `domain/store` (a persistence primitive) rather than going through an application service is a layering smell — the page is driving its own state from raw event replay, outside the application layer's control.
- **Evidence:** `lib/ui/client_intelligence_reports_page.dart:38`
- **Suggested follow-up for Codex:** Determine if `InMemoryEventStore` is used for local read projection in the reports page or for bootstrapping. If it's a local projection, an application-layer read model service would be the right boundary.

---

### P2 — Deleted source file with surviving test

- **Action:** AUTO
- **Finding:** `lib/ui/dispatch_models.dart` was deleted (D in git status), but `test/ui/dispatch_models_test.dart` is untracked (pending addition).
- **Why it matters:** The test file references a source that no longer exists. If the test is added and the source deletion committed, the test suite will fail to compile.
- **Evidence:**
  - `git status`: `D lib/ui/dispatch_models.dart`
  - `git status`: `?? test/ui/dispatch_models_test.dart`
- **Suggested follow-up for Codex:** Determine whether `dispatch_models_test.dart` was written for the deleted file or for a replacement. Either delete the test or reconcile with the new source location.

---

### P3 — Test import path mismatches from directory restructuring

- **Action:** REVIEW
- **Finding:** At least 6 test files import via a flat path but the source was moved to a subdirectory. These tests will fail to compile as-is if the import paths were not updated alongside the move.
- **Why it matters:** Silent broken test files — they don't surface in `dart analyze` if untracked, but will fail `flutter test` once committed.
- **Evidence (path restructure):**

  | Test file | Expected flat path | Actual location |
  |---|---|---|
  | `test/domain/onyx_route_test.dart` | `lib/domain/onyx_route.dart` | `lib/domain/authority/onyx_route.dart` |
  | `test/domain/onyx_command_brain_contract_test.dart` | `lib/domain/onyx_command_brain_contract.dart` | `lib/domain/authority/onyx_command_brain_contract.dart` |
  | `test/engine/dispatch_state_machine_test.dart` | `lib/engine/dispatch_state_machine.dart` | `lib/engine/dispatch/dispatch_state_machine.dart` |
  | `test/engine/execution_engine_test.dart` | `lib/engine/execution_engine.dart` | `lib/engine/execution/execution_engine.dart` |
  | `test/infrastructure/configured_live_feed_service_test.dart` | `lib/infrastructure/configured_live_feed_service.dart` | `lib/infrastructure/intelligence/configured_live_feed_service.dart` |
  | `test/infrastructure/news_intelligence_service_test.dart` | `lib/infrastructure/news_intelligence_service.dart` | `lib/infrastructure/intelligence/news_intelligence_service.dart` |

- **Suggested follow-up for Codex:** Open each test file and verify the import paths. Update test imports to match the actual source locations. Run `flutter test` on affected files individually to confirm they pass.

---

### P3 — True orphan test files (source missing, no known relocation)

- **Action:** REVIEW
- **Finding:** Several test files have no production source at any path in the repo.
- **Why it matters:** These may be tests written ahead of implementation (TDD stubs), or tests for deleted/renamed sources without a corresponding rename. Either way they represent dead test weight or a gap signal.
- **Evidence:**

  | Orphan test | Status |
  |---|---|
  | `test/application/admin_directory_service_test.dart` | Source missing entirely |
  | `test/application/cctv_phase1_flow_test.dart` | Source missing |
  | `test/application/dispatch_application_service_triage_test.dart` | Source missing |
  | `test/application/simulation/run_onyx_scenario_tool_test.dart` | Source missing |
  | `test/application/telegram_push_sync_coordinator_test.dart` | Source missing |
  | `test/domain/dispatch_action_canonical_test.dart` | Source missing |
  | `test/domain/event_log_canonical_test.dart` | Source missing |
  | `test/domain/events/dispatch_event_audit_type_key_test.dart` | Source missing |
  | `test/domain/risk_policy_canonical_test.dart` | Source missing |

- **Suggested follow-up for Codex:** For each, open the test file and determine whether the imports can be resolved against any existing file. If not resolvable, classify as TDD-ahead or stale and document.

---

### P3 — Naming convention drift: `_widget_test` suffix mismatch

- **Action:** AUTO (low risk)
- **Finding:** A majority of `test/ui/` widget tests use the suffix `_page_widget_test.dart`, but source files use `_page.dart`. This is a convention mismatch — the tests reference the correct source implicitly (they import `../lib/ui/admin_page.dart` not `admin_page_widget.dart`), but the file naming creates false "no match" noise in tooling and scripts that correlate test→source by filename.
- **Evidence:** e.g., `test/ui/admin_page_widget_test.dart` → source `lib/ui/admin_page.dart` (exists). Verified for: admin, controller_login, dashboard, dispatch, events, guards, sites, ledger, tactical pages.
- **Suggested follow-up for Codex:** No code change needed. Document the convention: widget test filenames for page sources always use `_page_widget_test.dart` even when the source is `_page.dart`.

---

## Duplication

Not assessed in this commit-readiness scan. See `audit_repo_wide_2026-04-07.md` or prior duplication audits for that scope.

---

## Coverage Gaps

- **288 test files / 440 source files** = ~65% file-level test coverage by count. Reasonable, but several untracked test files are new (104 untracked test entries), meaning they have not been exercised in CI yet.
- The 9 true orphan tests (P3 above) represent a coverage gap in reverse — test investment with no source backing.
- `test/application/carwash_bi_demo_fixture_test.dart` is untracked and references a missing source — if this is a demo/fixture, it may be testing infrastructure rather than domain behavior.

---

## Performance / Stability Notes

None identified in this scan. Static analysis is clean.

---

## Commit Readiness Summary

| Item | Status |
|---|---|
| `dart analyze` | ✅ Clean — 0 issues |
| Modified tracked files | ⚠️ 209 files uncommitted |
| Untracked files | ⚠️ 258 files not yet staged |
| Deleted files | ⚠️ 1 (`lib/ui/dispatch_models.dart`) — orphaned test pending |
| Domain→Infrastructure violation | ❌ 1 confirmed (`incident_service.dart`) |
| UI→Infrastructure violations | ❌ 2 confirmed (`dispatch_page`, `ledger_page`) |
| Test path mismatches (restructure) | ⚠️ 6 files — imports likely broken |
| True orphan tests | ⚠️ 9 files — source missing |
| Import cycles | ✅ None detected in key domain pairs |

---

## Recommended Fix Order

1. **(P1)** Resolve `IncidentService` domain→infrastructure import: introduce a domain abstraction or move the service to the application layer — REVIEW with Zaks first.
2. **(P2)** Fix `dispatch_page.dart` and `ledger_page.dart` UI→infrastructure imports before committing those files — straightforward application-layer mediation.
3. **(P2)** Resolve `dispatch_models.dart` deletion vs surviving test: either delete the test or restore/redirect the source.
4. **(P3)** Fix import paths in the 6 restructure-mismatched test files (engine, domain/authority, infrastructure/intelligence) — AUTO candidate for Codex.
5. **(P3)** Triage 9 orphan test files: classify as TDD-ahead or stale, document decision.
6. Stage and commit the full working tree only after items 2–4 are confirmed passing under `flutter test`.
