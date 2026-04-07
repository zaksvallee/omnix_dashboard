# Audit: Test Suite Health

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `/test/` — all 287 `*_test.dart` files, all layers
- Read-only: yes

---

## Executive Summary

The test suite is large and growing rapidly. Total test cases sit at **2,505** across 287 test files. The working tree holds **96 untracked new test files** (541 new test cases) and **178 modified committed test files** — neither set is yet committed. The application layer is well-covered; the domain layer is the sharpest gap at ~21% file coverage. No test files have zero assertions. One cross-file duplicate test name exists. A structural flakiness risk is present across at least 6 UI widget test files that use `DateTime.now()` inside test bodies to drive relative-time assertions — these are the most likely source of intermittent CI failures if the test run crosses a minute boundary.

---

## What Looks Good

- **Zero true zero-assertion files.** Every `*_test.dart` file, including the `supabase_client_ledger_repository_test.dart` that uses `expectLater`, has at least one real assertion.
- **SLA domain tests use hardcoded timestamps.** `sla_clock_test.dart` and `sla_breach_evaluator_test.dart` use `DateTime.parse(...)` with fixed UTC strings rather than `DateTime.now()` — correct design, immune to wall-clock flakiness.
- **New test files have high assertion density.** The 96 newly added files average ~5–6 assertions per test case (e.g., `onyx_app_clients_route_widget_test.dart` has 335 assertion calls across 52 `testWidgets`; `onyx_app_admin_route_widget_test.dart` has 309 across 14).
- **Application layer test coverage is strong.** 178 test files for 216 source files ≈ 82% file-level coverage.
- **UI layer coverage is strong.** 59 test files for 70 source files ≈ 84% file-level coverage.

---

## Findings

### P1

**Action: REVIEW**

**Finding:** `DateTime.now()` used inside test bodies to drive relative-time assertions — flaky by design.

**Why it matters:** Tests that compute `now.subtract(Duration(minutes: 6))` and then assert on a UI label like "6 minutes ago" will fail if the test executes near a minute boundary. The rendered label will show "7 minutes ago" while the assertion expects "6 minutes ago." These are not isolated edge cases — the pattern is used in 14+ locations across the highest-traffic widget test files.

**Evidence:**
- `test/ui/onyx_app_clients_route_widget_test.dart:3015,3036,3053,6176,6266,7155,7156,7443,7444,8001,8002,8462,8463,8642,10131,10201,10269` — 15+ uses of `DateTime.now().subtract(Duration(minutes: N))` fed into data models whose output is then asserted via `find.text(...)`
- `test/ui/onyx_app_agent_route_widget_test.dart:222,952,953,1140,1141,1276,1277,1278,1479,1480,1603` — 7 test-body instances
- `test/ui/dashboard_page_widget_test.dart:177,1330` — `Duration(minutes: 20)` and `Duration(minutes: 9)` relative computations
- `test/application/cctv_phase1_flow_test.dart:16,99` — `DateTime.now().toUtc().subtract(Duration(minutes: N))` in event payloads
- `test/application/dvr_evidence_probe_service_test.dart:128` — same pattern

**Suggested follow-up for Codex:** Replace `DateTime.now()` in test bodies with a fixed anchor: `DateTime.parse('2026-04-07T09:00:00.000Z')` or inject a `ClockProvider` stub. Codex should validate each occurrence to determine whether the displayed label is sensitive to sub-minute drift.

---

### P1

**Action: REVIEW**

**Finding:** 96 new test files (541 test cases) are uncommitted and untracked. 178 existing test files have uncommitted modifications. The working tree diverges significantly from HEAD.

**Why it matters:** These tests cannot be run in CI, cannot be reviewed in PRs, and cannot be treated as authoritative coverage evidence until committed. If HEAD is the baseline referenced by CI, then the effective test count visible to CI is approximately 191 files / ~1,964 cases — not 2,505. Any coverage reporting or badge based on HEAD is stale by ~28%.

**Evidence:**
- `git status --short -- test/` returns 178 `M` entries and 96 `??` entries
- HEAD commit is `5a9e4ce` dated 2026-03-26 — 12 days behind
- Untracked new files include: `admin_directory_service_test.dart`, `cctv_false_positive_policy_test.dart`, full `hik_connect_*` suite (18 files), `client_backend_probe_coordinator_test.dart`, `client_camera_health_fact_packet_service_test.dart`, and others

**Suggested follow-up for Codex:** Validate that the 96 untracked files compile and all 541 test cases pass before committing. Prioritize committing the `hik_connect_*` cluster first as it represents the largest new surface (18 files).

---

### P2

**Action: AUTO**

**Finding:** Module-level `DateTime.now()` captures in 4 test files evaluated at class load time.

**Why it matters:** These capture wall-clock at the moment the test file is loaded, not at test execution time. If Flutter's test runner loads all files once and then runs tests in sequence, a long test run could make the captured timestamp stale relative to what the UI renders as "recent." Not an immediate problem but structurally fragile.

**Evidence:**
- `test/ui/onyx_camera_bridge_tone_resolver_test.dart:7` — `final DateTime _bridgeFixtureNowUtc = DateTime.now().toUtc();`
- `test/ui/onyx_camera_bridge_clipboard_test.dart:9` — same pattern
- `test/ui/onyx_camera_bridge_actions_test.dart:9` — same pattern
- `test/ui/clients_page_widget_test.dart:23` — `final DateTime _clientsAgentDraftBaseUtc = DateTime.now().toUtc().subtract(...)`

**Suggested follow-up for Codex:** Move `DateTime.now()` captures inside `setUp()` or into a top-level function called at test time, not at file evaluation time.

---

### P2

**Action: REVIEW**

**Finding:** 161 of 178 application-layer test files have no `setUp` or `tearDown` blocks.

**Why it matters:** Tests construct all dependencies inline. This is not inherently wrong, but it means there is no structural guarantee that mutable state (e.g., in-memory maps, service instances with list accumulators) is reset between test cases within a `group`. If a service accumulates state via a list or map and is shared across test cases (rare but present), failures will be order-dependent and non-deterministic.

**Evidence:**
- Count: `grep -L "setUp|tearDown" test/application/*_test.dart | wc -l` → 161
- Risk is highest in tests that construct a service once and run multiple `test()` calls against it without reinitializing

**Suggested follow-up for Codex:** Scan for test files where a service or repository is instantiated outside a `test()` or `setUp()` block and reused across multiple `test()` calls. Flag those for `setUp()` migration.

---

### P3

**Action: AUTO**

**Finding:** One cross-file duplicate test name: `'reads from fallback when primary fails'`

**Why it matters:** Not a runtime failure (Flutter's test runner namespaces by file), but it makes grepping test output ambiguous. If CI prints test names without file context, this name appears twice and is impossible to attribute without the file prefix.

**Evidence:**
- `test/application/guard_sync_repository_test.dart:192`
- `test/application/client_conversation_repository_test.dart:119`

**Suggested follow-up for Codex:** Rename one of the two tests to include the service name, e.g., `'guard sync reads from fallback when primary fails'`.

---

## Coverage Gaps

### Domain Layer — 21% file-level coverage

- 116 domain source files, 24 test files
- Most at-risk uncovered subsystems (by test file count):
  - `lib/domain/` — only tested at: guard (6 files), evidence (2 files), incidents/risk (2 files), crm/reporting (3 files), intelligence (3 files), integration (1 file), onyx_command_brain (1 file), onyx_route (1 file), dispatch_action_canonical (1 file), event_log_canonical (1 file), risk_policy_canonical (1 file)
  - Missing domain test files for: any `crm/` entity models, `sites/` domain, notification domain objects, `dispatch/` value objects beyond the canonical test

### Infrastructure Layer — 38% file-level coverage

- 8 infrastructure source files, 3 test files
- `test/infrastructure/configured_live_feed_service_test.dart`
- `test/infrastructure/events/supabase_client_ledger_repository_test.dart`
- `test/infrastructure/news_intelligence_service_test.dart`
- Missing: any tests for other infrastructure adapters (Supabase read-path repositories, HTTP clients beyond HikConnect)

### Engine Layer — Exists but narrow

- 3 test files for `dispatch_state_machine`, `execution_engine`, `vertical_slice_runner`
- No coverage gap detected here given the layer's scope, but the vertical slice runner test should be verified against the current engine contract after the controller redesign (`5a9e4ce`)

### Missing Failure-Path Tests

- No test file for the `email_bridge_service_web.dart` path
- No test file for `telegram_ai_assistant_service` failure paths (service exists with a test file but the test for failure-path AI fallback behavior needs validation after the `5a9e4ce` UI redesign)
- No test for `dispatch_snapshot_file_service_web.dart` error path (file exists but test only covers happy path per the file naming)

---

## Performance / Stability Notes

- **`onyx_app_clients_route_widget_test.dart` and `onyx_app_admin_route_widget_test.dart` are very large files.** 52 and 14 `testWidgets` with 335 and 309 assertion calls respectively. These will be the slowest tests in the suite. No action required but worth monitoring if CI time becomes a concern.
- **SharedPreferences mock reset pattern.** `onyx_app_agent_route_widget_test.dart` calls `SharedPreferences.setMockInitialValues(...)` inside each individual test. If any test crashes before its prefs setup runs, leftover values from the previous test may bleed through. This is low-risk with the mock implementation but worth noting.

---

## Summary Statistics

| Metric | Value |
|---|---|
| Total test files (`*_test.dart`) | 287 |
| Fixture / support / script files | 9 |
| Total `test()` cases | 1,480 |
| Total `testWidgets()` cases | 1,025 |
| **Total test cases** | **2,505** |
| New untracked test files (working tree) | 96 |
| New test cases in those files | ~541 |
| Modified existing test files (working tree) | 178 |
| HEAD baseline test files | ~191 |
| Files with zero assertions | 0 |
| Cross-file duplicate test names | 1 |
| Files using `DateTime.now()` in tests | 27 |
| Files with time-relative test-body assertions (flaky candidates) | ≥6 |
| Estimated file-level coverage (application) | ~82% |
| Estimated file-level coverage (domain) | ~21% |
| Estimated file-level coverage (ui) | ~84% |
| Estimated file-level coverage (infrastructure) | ~38% |
| Estimated file-level coverage (presentation) | ~61% |
| **Overall estimated file-level coverage** | **~64%** |

---

## Recommended Fix Order

1. **Commit and validate the 96 untracked test files.** (REVIEW) — These represent the largest pending test surface. CI blind to them until committed.
2. **Replace `DateTime.now()` with fixed anchors in test bodies.** (REVIEW) — Highest probability of intermittent CI failures. At least 6 widget test files affected.
3. **Rename the duplicate test name.** (AUTO) — Low effort, high grep clarity.
4. **Move module-level `DateTime.now()` into `setUp()`.** (AUTO) — Low risk, structurally cleaner.
5. **Add setUp/tearDown to application tests that instantiate services outside test bodies.** (REVIEW) — Codex to identify which of the 161 files actually have shared service state.
6. **Expand domain layer coverage.** (DECISION) — Domain is at 21%. Zaks should decide whether domain model tests are expected to grow via this working branch or represent an accepted gap given the DDD service boundary strategy.
