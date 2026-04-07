# Audit: Backlog Gaps

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: All 2026-04-07 audit reports vs `ONYX_BACKLOG.md`
- Read-only: yes

---

## Executive Summary

`ONYX_BACKLOG.md` currently describes one initiative: the SIA DC-09 virtual alarm receiver in four vendor phases. Every other planned or needed work in the repository exists only in `claude_review/` audit reports or not at all.

The 43 audit reports from today surface ten substantial work items that carry production-blocking or compliance-blocking risk, that require architectural or product decisions before Codex can act, and that are not reflected anywhere in the backlog. All ten are confirmed by evidence in the source files audited today.

---

## Gap 1 — Admin Page Decomposition (god object breakup)

**Why it belongs in the backlog:**
`admin_page.dart` is 45,595 lines. Five classes inside it each qualify as god objects. Domain logic (Supabase upsert, directory loading, identity policy mutation) lives directly inside `_AdministrationPageState`. This is the single largest structural debt in the codebase. Every new admin feature added today increases the untestable surface. It is not a clean-up item — it is a prerequisite for any safe expansion of the admin surface.

**Scope:**
- Extract client/site/employee CRUD into `AdminDirectoryService` mutation methods
- Extract demo seed and demo clear into a dedicated `AdminDemoSeedService`
- Inject `SupabaseSiteIdentityRegistryRepository` and `SupabaseClientMessagingBridgeRepository` as fields instead of constructing inline at 4–5 call sites
- Move `SupabaseClient` dependency into service constructors so the widget never handles Supabase directly
- Reduce `_AdministrationPageState` to a thin coordinator passing commands to services and receiving results

**Evidence:** `audit_admin_page_dart_2026-04-07.md` P1-5; `audit_supabase_ui_calls_2026-04-07.md` F4–F9

**Action label:** REVIEW (extraction boundaries and atomicity for employee+assignment write require Zaks alignment)

---

## Gap 2 — DispatchPersistenceService → Drift Migration

**Why it belongs in the backlog:**
`DispatchPersistenceService` holds 56+ distinct SharedPreferences keys across eight domain areas. Today's audit produced a complete seven-phase migration plan with Drift table schemas, per-key risk ratings, and migration ordering. This work is large, risky (offline incident spool and client conversations are marked CRITICAL and HIGH respectively), and requires a pre-migration decision on the global vs. scoped client conversation key ambiguity before any code can move. It will not happen safely without explicit tracking.

**Scope:**
- Phase 0: Resolve global vs. scoped client conversation key ambiguity; enumerate orphaned scope keys via `prefs.getKeys()`
- Phase 1–2: Migrate UI preferences, scalars, offline spool, guard ops, radio queue
- Phase 3: Migrate scoped client conversation lane (5+ dynamic keys per scope)
- Phase 4–6: Typed singletons, history lists, config blobs
- Phase 7: Per-blob schema excavation and normalisation for 18 untyped `Map<String, Object?>` keys

**Evidence:** `audit_drift_migration_plan_2026-04-07.md`

**Action label:** DECISION (Phase 0 ambiguity must be resolved by Zaks before any migration code starts)

---

## Gap 3 — PSIRA Evidence Compliance

**Why it belongs in the backlog:**
The evidence and ledger layer currently fails seven PSIRA-relevant compliance requirements. The most critical: `sealDispatch` serialises events with `.toString()` (producing `"Instance of 'DecisionCreated'"` for every sealed dispatch, making every existing dispatch ledger record forensically void), `insertLedgerRow` silently discards evidence on any Supabase error (the primary failure mode during load shedding), and `sealIntelligenceBatch` has no idempotency guard so reconnect retries create duplicate chain entries. Evidence certificates carry no export timestamp and no cryptographic signature.

For a PSIRA-aligned security operations product, these are not future improvements — they are correctness requirements that must be in the backlog before client-facing evidence workflows are live.

**Scope:**
- Replace `.toString()` with `.toJson()` in `sealDispatch` (AUTO)
- Add pre-insert existence check or DB unique constraint on `(client_id, dispatch_id)` for idempotency
- Add hash re-derivation step in `EvidenceCertificateExportService` before export (tamper detection)
- Add export timestamp to every certificate
- Decide durability contract for load-shedding: spool + retry, explicit loss log, or caller-owned queue
- Decide atomic sealing strategy (DB advisory lock or `ON CONFLICT DO NOTHING`)
- Decide certificate signing mechanism (Supabase Edge Function, operator keypair, HMAC)

**Evidence:** `audit_evidence_ledger_2026-04-07.md` P1-A through P2-E; PSIRA Compliance Gaps table

**Action label:** REVIEW/DECISION (P1-A and P1-D are AUTO; P1-B, P1-C, and P2-E are blocked on Zaks)

---

## Gap 4 — SLA Clock Injection and Load-Shedding Drift Policy

**Why it belongs in the backlog:**
`IncidentService` uses live `DateTime.now()` with no clock injection. In South Africa, load shedding is not a theoretical edge case — it is the default operating environment. When power is restored and NTP resyncs, a clock jump forward will cause `IncidentService` to evaluate all open incidents against the jumped clock and emit false breaches. When the app is offline during an SLA window, incidents that crossed their `dueAt` are silently never marked as breached (the restart-miss bug). Neither failure mode is detectable, testable, or recoverable without a product decision and a code change.

**Scope:**
- Inject `DateTime Function() clock` into `IncidentService` and `SLABreachEvaluator._generateId` (matching the pattern already in `IncidentToCRMMapper`) — AUTO
- Product decision: acceptable clock drift threshold (what forward jump suppresses breach detection until human review?)
- Product decision: retroactive breach treatment on restart (should missed-at-restart breaches generate CRM events?)
- Product decision: should `escalated` status stop the SLA clock?
- After decisions: add drift guard and restart evaluation to `initialize()`

**Evidence:** `audit_sla_chain_2026-04-07.md` P2 (load-shedding), P3 (escalated terminal status); `audit_sla_incident_domain_2026-04-07.md` P1 (restart miss), P2 (DateTime.now)

**Action label:** DECISION (clock injection is AUTO; policy questions are blocked on Zaks)

---

## Gap 5 — Camera Vendor Workers: Real ONVIF Integration

**Why it belongs in the backlog:**
All five camera vendor workers (Hikvision, Dahua, Axis, Uniview, Generic ONVIF) return hardcoded `success: true` with no network call. When an operator approves a camera profile change, the UI shows green receipt status but the camera is unchanged. The credential path does not exist: `OnyxAgentCameraExecutionPacket.credentialHandling` is a plain-text operator note, not a `DvrHttpAuthConfig`. The `DvrHttpAuthConfig` abstraction already exists and Hikvision digest auth is already implemented in `LocalHikvisionDvrProxyService` — the integration infrastructure is available but not wired.

This is a decision-blocked backlog item, not a future nice-to-have. Operators are already interacting with the camera change UI.

**Scope:**
- Decide credential carrier design: credential key in packet (Option A), credentials injected into worker at construction (Option B), or credentials in HTTP request (Option C, not recommended)
- Wire `DvrHttpAuthConfig` into `HikvisionOnyxAgentCameraWorker`
- Replace stub worker bodies with real ISAPI calls: `GET /deviceInfo`, `GET /channels`, `PUT /channels/{id}`, `GET /channels/{id}` (verify)
- Set `success: false` on non-2xx or verify-read mismatch
- Add visible UI notice that workers are in intent-only mode until integration is live
- Decide CCTV auth mechanism (all CCTV probes currently fail 401 silently)

**Evidence:** `audit_camera_bridge_2026-04-07.md` P1 (both findings); `audit_agent_connections_2026-04-07.md` P1 (vendor workers)

**Action label:** DECISION (credential carrier design must be chosen by Zaks before any implementation starts)

---

## Gap 6 — Governance Page: Replace Stub Data with Live Data

**Why it belongs in the backlog:**
`governance_page.dart` renders three major operational surfaces using hardcoded fabricated data:

1. **Fleet status** (line 907–914): 12 ready, 2 maintenance, 1 critical — static regardless of actual dispatch state
2. **Guard vigilance** (line 13084): Four hardcoded callsigns (Echo-3, Bravo-2, Delta-1, Alpha-5) with fake last-check-in times and fabricated sparklines
3. **Compliance issues** (line 13113): Four hardcoded employees (John Nkosi, Sizwe Moyo, Mandla Khumalo, Thato Dlamini) with fake PSIRA expiry states

All three feed the hero chip readiness percentage, the READINESS BLOCKERS surface, and the posture score. Operators and reviewers are seeing fabricated data on the primary governance surface. `_resolveComplianceIssue` "resolves" hardcoded employee IDs — those resolved keys are meaningless.

**Scope:**
- Decide input shape: fleet data as widget parameter (FleetStatus value object) or derived from dispatch events via a fleet service
- Wire guard vigilance from `GuardCheckedIn` events already present in `widget.events`
- Wire compliance issues from `widget.morningSovereignReport.complianceBlockage` (field already exists)
- Remove hardcoded stubs after live wiring is confirmed

**Evidence:** `audit_governance_page_dart_2026-04-07_v2.md` P1 (three findings)

**Action label:** REVIEW (architecture decision on input shape needed before Codex can wire)

---

## Gap 7 — Demo Credential Security and Production Hardening

**Why it belongs in the backlog:**
Two production-blocking security issues exist in the login screen:

1. Demo passwords are rendered as plaintext text on screen (`'/ ${account.password}'`) — visible to any shoulder-surfer, screenshot, or screen recorder
2. `_controllerDemoAccounts` in `main.dart` stores `password: 'onyx123'` as compile-time string constants with no `kDebugMode` or `--dart-define` gate, baking credentials into every build including production web deploys

The `admin` account carries full admin authority. The login gate is the **default** app mode. These are not acceptable in any client-facing or production build.

**Scope:**
- Gate `_controllerDemoAccounts` behind `kDebugMode` or inject via `--dart-define`
- Remove or gate the plaintext `'/ ${account.password}'` display
- Replace demo-specific error string with a generic `'Invalid username or password.'`
- Decide: light vs. dark theme for login screen, then extract 14 inline color literals to `OnyxDesignTokens`

**Evidence:** `audit_login_screen_2026-04-07.md` P1 (both findings)

**Action label:** REVIEW (product decisions on credential gate strategy and theme choice needed)

---

## Gap 8 — CRM Reporting: Data Correctness and Test Coverage

**Why it belongs in the backlog:**
The CRM reporting subsystem (18 files, 8 projection classes) generates client-facing reports with zero test coverage. Today's audit identified three confirmed data bugs that are live in production outputs:

1. `breachedIncidents` count in `SLADashboardSummary` includes overridden incidents while the compliance formula excludes them — a report can show "3 breaches, 100% compliance" simultaneously
2. `DispatchPerformanceProjection` synthesises `guardName: 'Guard $guardId'` and `psiraNumber: 'PSIRA-$guardId'` as fabricated strings — these appear in serialised reports as if they are real data
3. `ReportBundleAssembler.build` force-unwraps `slaProfile!` — a runtime crash for any client whose CRM event stream is incomplete or reordered

Additionally, three different `slaComplianceRate` formulas are in use across the subsystem, producing divergent results for the same client in the same period.

**Scope:**
- Fix `breachedIncidents` count to exclude overridden incidents (AUTO)
- Fix force-unwrap on `slaProfile!` in `ReportBundleAssembler`
- Resolve fabricated guard PII — use real guard domain model or mark as `unknown`/`unresolved`
- Unify `slaComplianceRate` formula across all three projection paths
- Decide: hardcoded narrative strings and `_expectedPatrolsPerCheckIn = 8` constant — per-client config or documented universal
- Build the 20-test suite listed in `audit_crm_reporting_2026-04-07.md` coverage section

**Evidence:** `audit_crm_reporting_2026-04-07.md` P1 (three findings), P2 (formula divergence); `audit_test_coverage_2026-04-07.md` P2 (CRM projection subsystem)

**Action label:** REVIEW (guard PII sourcing, narrative content, and patrol constant require product decisions)

---

## Gap 9 — Authority Domain: Complete the Permission Ladder

**Why it belongs in the backlog:**
The Telegram authority model has two structural gaps that leave it incomplete as a production authorization system:

1. **Dead rungs**: `propose` and `execute` are in the action enum and role policies but are never required by any command intent in `OnyxTelegramCommandGateway`. No current command requires admin-only authority — a supervisor can do everything an admin can. If new high-privilege intents are added without updating `_requiredActionForIntent`, they silently default to `read` authority.

2. **AuthorityToken is a stub**: Defined in the authority domain (2 fields: `authorizedBy`, `timestamp`), imported nowhere in the authorization path, no expiry, no revocation. Developers reading the code cannot tell whether this is active enforcement or dead scaffolding.

3. **OperatorContext is disconnected**: Defined in the authority domain, used in `app_state.dart`, but its `canExecute(regionId, siteId)` is not wired into any gate in `OnyxScopeGuard` or `OnyxTelegramCommandGateway`.

**Scope:**
- Decide: fill the `propose`/`execute` ladder with real intents, or trim the enum to what is actually checked
- Wire `AuthorityToken` into the authorization path with an expiry check, or add a `// TODO(authority): not yet wired` comment and document its intended lifecycle
- Audit `OperatorContext` usage in `app_state.dart` — determine if it is an active gate or passive metadata
- Add `OnyxTelegramCommandGateway.route` end-to-end tests (currently the composed gateway has no test)

**Evidence:** `audit_authority_domain_2026-04-07.md` P1 (both findings), P2 (`OperatorContext`)

**Action label:** DECISION (permission ladder shape and AuthorityToken lifecycle are product/architecture choices)

---

## Gap 10 — Dispatch State Machine: Semantic Gaps and Concurrency

**Why it belongs in the backlog:**
The dispatch state machine has three confirmed semantic gaps and an unresolved concurrency question:

1. `executed → failed` is a legal transition, but `executed` is also treated as terminal success by `vertical_slice_runner.dart:112`. These are contradictory — `executed` cannot simultaneously mean "attempted" and "succeeded."
2. `committing → failed` is missing. A system crash mid-commit cannot be recorded. Dispatches can be permanently stuck in `committing` with no recovery path.
3. `decided → aborted` is missing. Pre-commit operator cancels must use `overridden`, conflating operator intent with system failure in audit trails.
4. The `canTransition()` call in `vertical_slice_runner.dart` bypasses `DispatchAction.transition()` — if the engine doesn't call `transition()` internally, this is a state machine bypass.

These semantic questions must be resolved before the `ExecutionEngine` stub is replaced with real logic.

**Scope:**
- Decide: does `executed` mean "attempted" or "succeeded"? If succeeded, remove `executed → failed` and add a `dispatched`/`sent` intermediate. If attempted, add `succeeded` as a distinct terminal state.
- After P1 is resolved: add `committing → failed` transition
- Decide: `aborted` vs `overridden` semantic split for pre-commit operator cancels
- Verify `engine.execute()` and whether the raw `canTransition()` call in `vertical_slice_runner.dart` is a bypass
- Add full transition matrix tests (currently zero tests for the state machine's actual behaviour)

**Evidence:** `audit_dispatch_state_machine_2026-04-07.md` P1–P4

**Action label:** DECISION (semantic questions are product/architecture choices; tests and P4 fix are AUTO once decisions land)

---

## Summary Table

| # | Gap | Risk Level | Action Label | Blocked On |
|---|-----|-----------|--------------|------------|
| 1 | Admin page god object decomposition | Structural | REVIEW | Extraction boundary alignment |
| 2 | DispatchPersistenceService → Drift migration | High (operational data) | DECISION | Global vs. scoped key ambiguity |
| 3 | PSIRA evidence compliance | Compliance-blocking | REVIEW/DECISION | Durability contract, signing mechanism |
| 4 | SLA clock injection + load-shedding policy | Ops correctness | DECISION | Drift threshold, retroactive breach policy |
| 5 | Camera vendor workers: real ONVIF integration | Ops correctness | DECISION | Credential carrier design |
| 6 | Governance page stub data replacement | Production readiness | REVIEW | Input shape decision |
| 7 | Demo credential security | Production-blocking | REVIEW | Credential gate strategy + theme choice |
| 8 | CRM reporting data correctness + tests | Client-facing correctness | REVIEW | Guard PII source, narrative content |
| 9 | Authority domain: complete the permission ladder | Authorization integrity | DECISION | Permission ladder shape, AuthorityToken lifecycle |
| 10 | Dispatch state machine: semantic gaps + concurrency | Engine correctness | DECISION | `executed` semantics |

---

## What Is Already in the Backlog

`ONYX_BACKLOG.md` covers the SIA DC-09 / Texecom / Olarm / Contact ID alarm receiver chain. None of the ten gaps above overlap with or depend on the alarm receiver work. They can proceed independently.

---

## Recommended Backlog Entry Order

1. **Gap 7** (demo credentials) — simplest to resolve, production-blocking, no external dependency
2. **Gap 3** (PSIRA evidence) — compliance risk for existing client workflows; P1-A and P1-D are AUTO and can start immediately
3. **Gap 4** (SLA clock injection) — clock injection is AUTO today; policy decisions can follow
4. **Gap 10** (dispatch state machine semantics) — must be resolved before `ExecutionEngine` stub becomes real
5. **Gap 8** (CRM reporting correctness) — AUTO fixes can start now; fabricated PSIRA numbers are live in reports
6. **Gap 5** (camera workers) — decision-blocked but operationally confusing to operators right now
7. **Gap 6** (governance stubs) — most visible to daily operators; decision needed on input shape
8. **Gap 9** (authority domain) — important before Telegram-based privilege escalation is possible
9. **Gap 1** (admin page decomposition) — large but can be done incrementally; no decision needed, only scope alignment
10. **Gap 2** (Drift migration) — longest-horizon item; Phase 0 prerequisite decision should be scheduled now even if migration is months away
