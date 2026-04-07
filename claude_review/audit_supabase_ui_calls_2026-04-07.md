# Audit: Direct Supabase.instance.client calls in lib/ui/

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: lib/ui/admin_page.dart, lib/ui/ledger_page.dart
- Read-only: yes

## Executive Summary

12 direct `Supabase.instance.client` call sites exist across two UI files. The calls split into two categories:

1. **Repository construction inside widget state** — the repository class exists and is correct, but is being instantiated ad-hoc inside the widget rather than injected. These are structural violations but the query logic is sound.
2. **Raw table access with no repository** — `clients`, `sites`, `employees`, `employee_site_assignments`, `vehicles`, `incidents` tables are queried directly inside widget methods with no abstraction layer. These are the highest-risk findings: schema changes or policy changes are invisible to the UI layer.

One call (`ledger_page.dart:77`) has a fully-formed repository (`SupabaseClientLedgerRepository`) that exposes the exact same table but is never used for the listing query.

---

## What Looks Good

- `SupabaseSiteIdentityRegistryRepository` and `SupabaseClientMessagingBridgeRepository` exist as real abstractions. The UI is at least calling repository methods via them — the violation is construction, not bypassed logic.
- `adminDirectoryService.loadDirectory(supabase: ...)` passes the client through to a service layer, which owns the actual queries; this is the least severe pattern here.
- `SupabaseClientLedgerRepository` already exists and covers `client_evidence_ledger` — the fix for `ledger_page.dart` is straightforward.

---

## Findings

### F1 — `ledger_page.dart:77–82` — Raw `client_evidence_ledger` query bypasses existing repository
- **Action: AUTO**
- **Finding:** `_loadLedger()` queries `client_evidence_ledger` directly. `SupabaseClientLedgerRepository` already implements `fetchLedgerRow` and `fetchPreviousHash` on the same table, but `LedgerPage` has no read-all method there.
- **Why it matters:** `SupabaseClientLedgerRepository` is the correct abstraction for this table. Bypassing it means two different query shapes hitting the same table — one via the repo, one ad-hoc — with no shared projection or error handling policy.
- **Query:** `.from('client_evidence_ledger').select().eq('client_id', ...).order('created_at', ascending: true)`
- **Should belong to:** `SupabaseClientLedgerRepository` — a `fetchAllRows(clientId)` method.
- **Evidence:** `lib/ui/ledger_page.dart:77–82`, `lib/infrastructure/events/supabase_client_ledger_repository.dart`

---

### F2 — `admin_page.dart:3443, 3546, 3639, 3774` — `SupabaseSiteIdentityRegistryRepository` constructed inline 4×
- **Action: AUTO**
- **Finding:** Four widget methods each `new SupabaseSiteIdentityRegistryRepository(Supabase.instance.client)` independently. The repository is never injected or held as a field.
  - Line 3443: `_loadTelegramIdentityIntakesFromSupabase()` → `listPendingTelegramIntakes()`
  - Line 3546: `_approveTelegramIdentityIntakeOnce()` → approve + `insertApprovalDecision()`
  - Line 3639: `_approveTelegramIdentityIntakeAlways()` → approve
  - Line 3774: `_rejectTelegramIdentityIntake()` → `insertApprovalDecision()`
- **Why it matters:** Each action creates a new repository instance that is not shareable, not mockable in tests, and recreates a Supabase client reference every call. This makes widget testing impossible without live Supabase.
- **Should belong to:** Injected via `widget` or a state-held field, passed from the widget's parent scope.
- **Evidence:** `lib/ui/admin_page.dart:3442–3444, 3545–3547, 3638–3640, 3773–3775`

---

### F3 — `admin_page.dart:22763` — `SupabaseClientMessagingBridgeRepository` constructed inline in `_createClientMessagingBridgeRecord`
- **Action: AUTO**
- **Finding:** `_createClientMessagingBridgeRecord` instantiates `SupabaseClientMessagingBridgeRepository(Supabase.instance.client)` inline. Same pattern as F2.
- **Why it matters:** Identical testability and construction discipline issue. The repo already handles the correct abstraction.
- **Evidence:** `lib/ui/admin_page.dart:22763–22764`

---

### F4 — `admin_page.dart:23374` — `_seedDemoOperationsData` makes 4 raw table writes: `employees`, `vehicles`, `incidents`, plus a lookup
- **Action: REVIEW**
- **Finding:** `_seedDemoOperationsData` at line 23359 directly writes to `employees` (lookup at 23380), `vehicles` (upsert at 23398), and `incidents` (upsert at 23429) with no repository.
- **Why it matters:** This is the highest-volume raw query block. Three distinct domain tables touched directly, including `incidents` which likely has domain invariants (priority enum, status transitions). Demo seeding logic that bypasses the application layer can silently write structurally invalid records and will not be caught by any validation in the repo or domain layer.
- **Queries:**
  - `employees` select (line 23380): resolve employee UUID for linking
  - `vehicles` upsert (line 23398): seed demo vehicle
  - `incidents` upsert (line 23429): seed demo incident
- **Should belong to:** A `DemoSeedRepository` or `AdminDemoSeedService` in `lib/application/admin/`. Alternatively, each write should use the relevant domain repository once those exist.
- **Evidence:** `lib/ui/admin_page.dart:23374–23465`

---

### F5 — `admin_page.dart:23592` — `_clearDemoData` queries and deletes across 5+ tables raw
- **Action: REVIEW**
- **Finding:** `_clearDemoData` (line 23472) builds raw queries directly against `clients`, `employees`, `sites`, and then deletes across these plus additional expanded tables via a local `tryDeleteByFilter` closure (line 23630). No repository is involved.
- **Why it matters:** Multi-table deletion with no transaction guarantee. If any intermediate delete fails, the cleanup is partial and silent (the inner catch swallows all errors). More critically, this is destructive bulk-delete logic embedded directly in widget state — one refactor or copy-paste error could target the wrong `ilike` pattern on production data.
- **Queries:**
  - `clients` select `client_id` ilike `DEMO-%` (line 23593)
  - `employees` select `id, employee_code` ilike `DEMO-%` (line 23604)
  - `sites` select `site_id` ilike `DEMO-%` (line 23616)
  - Multi-table `.delete().inFilter(...)` (line 23637)
- **Should belong to:** `AdminDemoSeedService` or a dedicated `AdminDirectoryService` mutation method. The UI should pass intent; the service layer should own the deletion logic.
- **Evidence:** `lib/ui/admin_page.dart:23587–23641`

---

### F6 — `admin_page.dart:23800` — `_createClientRecord` writes directly to `clients` table
- **Action: REVIEW**
- **Finding:** `_createClientRecord` upserts a full client record directly to `clients` with no domain validation layer between the draft form state and the database.
- **Why it matters:** The `clients` table is a root domain entity. Field selection (billing_address, vat_number, contract_start, metadata, etc.) is decided inline in the widget. Any schema change (column rename, new constraint) requires a widget edit. There is no centralized validation for client record invariants.
- **Query:** `.from('clients').upsert({...}, onConflict: 'client_id')` (line 23801)
- **Should belong to:** An `AdminClientRepository` or `AdminDirectoryService.upsertClient(...)`.
- **Evidence:** `lib/ui/admin_page.dart:23800–23823`

---

### F7 — `admin_page.dart:24013` — `_createSiteRecord` writes directly to `sites` table
- **Action: REVIEW**
- **Finding:** Same pattern as F6. `_createSiteRecord` upserts to `sites` inline with no repository. The site record includes 14+ fields including geofence config, risk profile, and escalation policy settings — all composed ad-hoc in the widget method.
- **Query:** `.from('sites').upsert({...}, onConflict: 'site_id')` (line 24014)
- **Should belong to:** `AdminDirectoryService.upsertSite(...)` or a dedicated `AdminSiteRepository`.
- **Evidence:** `lib/ui/admin_page.dart:24013–24039`

---

### F8 — `admin_page.dart:24224, 24267` — `_createEmployeeRecord` writes directly to `employees` and `employee_site_assignments`
- **Action: REVIEW**
- **Finding:** `_createEmployeeRecord` upserts to `employees` (line 24224) and conditionally to `employee_site_assignments` (line 24267) in the same widget method, with no repository. The employee upsert includes biometric, firearm, PDP, PSIRA, and license fields all composed inline.
- **Why it matters:** Two-step write with no transaction. The assignment insert at line 24267 uses a separate `Supabase.instance.client` call — if this fails after the employee write succeeds, the employee exists in the DB with no site assignment, and the error is caught and partially reported (but the widget reload is triggered regardless). This is a partial-write bug candidate.
- **Queries:**
  - `employees` upsert (line 24224): 20+ field employee record
  - `employee_site_assignments` upsert (line 24267): site assignment link
- **Should belong to:** `AdminDirectoryService.upsertEmployee(...)` or a dedicated `AdminEmployeeRepository` that wraps both writes atomically.
- **Evidence:** `lib/ui/admin_page.dart:24224–24276`

---

### F9 — `admin_page.dart:24391` — `adminDirectoryService.loadDirectory(supabase: ...)` passes raw client to service
- **Action: REVIEW**
- **Finding:** `_loadDirectoryFromSupabase` passes `Supabase.instance.client` as a named parameter into `widget.adminDirectoryService.loadDirectory(...)`. The service (`AdminDirectoryService`) accepts the raw client and performs its own queries internally.
- **Why it matters:** This is the least severe pattern here — the logic is in the service, not the widget. But passing the raw `SupabaseClient` through the widget boundary prevents the service from being instantiated with a fixed client at construction time, making it harder to inject a test double. It also means the widget is aware of Supabase's existence rather than treating the service as opaque.
- **Should belong to:** The service should be constructed with its client dependency at app composition time, not receive it per-call from the widget layer.
- **Evidence:** `lib/ui/admin_page.dart:24391`

---

## Duplication

- The pattern `final repository = SupabaseSiteIdentityRegistryRepository(Supabase.instance.client)` appears **4 times** in `admin_page.dart` (lines 3442, 3545, 3638, 3773). These should be a single injected field.
- The pattern `final supabase = Supabase.instance.client` / `Supabase.instance.client` appears across `_createClientRecord`, `_createSiteRecord`, `_createEmployeeRecord`, `_seedDemoOperationsData`, and `_clearDemoData` — all inside `_AdminPageState`. These would all be eliminated by a single `SupabaseClient get _supabase => Supabase.instance.client` field, but the real fix is injection.

---

## Coverage Gaps

- `LedgerPage._loadLedger()` has no test that exercises the live-Supabase path. Because the query is inline, there is no repository double to stub.
- The Telegram identity intake approve/reject flows (F2) are not independently testable because the repository is constructed inside the widget.
- `_createEmployeeRecord` partial-write scenario (employee saved, assignment fails) has no test coverage — the failure path is swallowed in the finally block.
- `_clearDemoData` has no tests at all. The inner `tryDeleteByFilter` swallows all errors by design, meaning a test cannot distinguish correct deletion from silent failure.

---

## Performance / Stability Notes

- `_clearDemoData` issues at least 3 read queries followed by N delete queries in sequence with no batching. On a busy Supabase instance this could trigger rate limits; there is no retry or backoff.
- `_seedDemoOperationsData` issues 3 upserts sequentially (employees, vehicles, incidents) inside a single widget action. If the widget is unmounted mid-sequence, no cleanup of partial writes is performed.

---

## Recommended Fix Order

1. **F1** (`ledger_page.dart:77`) — Add `fetchAllRows(clientId)` to `SupabaseClientLedgerRepository` and wire it into `LedgerPage`. Smallest blast radius, repository already exists. `AUTO`.
2. **F2 + F3** (`admin_page.dart:3443–3774, 22763`) — Inject `SupabaseSiteIdentityRegistryRepository` and `SupabaseClientMessagingBridgeRepository` as widget properties or construct them once in `_AdminPageState.initState`. `AUTO`.
3. **F9** (`admin_page.dart:24391`) — Move `SupabaseClient` into `AdminDirectoryService` constructor so the widget no longer passes it per-call. `REVIEW`.
4. **F6 + F7 + F8** (`admin_page.dart:23800, 24013, 24224`) — Extract client/site/employee writes into `AdminDirectoryService` mutation methods. Address the two-step employee+assignment write atomicity issue at the same time. `REVIEW`.
5. **F4 + F5** (`admin_page.dart:23374, 23592`) — Extract demo seed and demo cleanup into a dedicated `AdminDemoSeedService`. These are the most complex refactors and require a product decision about error handling policy for partial-write cleanup. `REVIEW`.
