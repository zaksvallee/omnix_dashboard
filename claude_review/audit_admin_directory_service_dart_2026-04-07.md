# Audit: admin_directory_service.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/application/admin/admin_directory_service.dart` + `test/application/admin_directory_service_test.dart`
- Read-only: yes

---

## Executive Summary

Solid, well-structured service. The data-source abstraction (`AdminDirectoryDataSource`) is correct,
the `const`-constructible stateless service is good DDD practice, and `Future.wait` parallelism is
applied correctly. `AdminDirectorySnapshot` is fully immutable at construction time.

Four issues deserve attention: a silent exception swallow on optional loaders that hides code bugs, a
hardcoded no-op for site contact fields, a misleading count field name, and an ordering sensitivity in
the assignment resolver that depends on unordered Supabase results. The test file covers the happy path
and the optional-table-failure path well, but has multiple meaningful gaps on edge cases.

---

## What Looks Good

- `AdminDirectoryDataSource` abstract class enables full injection; `SupabaseAdminDirectoryDataSource`
  is only instantiated inside the public `loadDirectory` shim — testable by design.
- All output collections are wrapped in `List.unmodifiable` / `Map.unmodifiable` — no accidental
  mutation from callers.
- `Future.wait` over all six queries in parallel is correct; endpoint and contact tables are guarded
  separately via `_loadOptionalRows` without blocking the core fetch.
- `_preferredChatcheckStatus` severity ranking (FAIL > SKIP > PASS > empty) is clean and tested
  implicitly by the primary test case.
- `_employeeCertifications` correctly produces a `['General']` fallback for employees with no
  documented credentials.

---

## Findings

### P1 — Silent broad catch in `_loadOptionalRows` masks code bugs

- **Action:** REVIEW
- `_loadOptionalRows` at line 453–461 catches `_` (every `Object`) and returns an empty list.
  This is intentional for tables that may not exist in older schema versions, but it also silences
  `TypeError`, `StateError`, null dereferences, and any future programming errors thrown by the loader.
  A schema-missing error and a null cast error are indistinguishable at the call site.
- **Why it matters:** If `fetchMessagingEndpoints` or `fetchClientContacts` throw due to a refactor
  bug (e.g., changed return type), the service silently returns an empty snapshot instead of failing
  loudly during development/CI. The snapshot will look valid but all endpoint and contact telemetry
  will be zeroed.
- **Evidence:** `admin_directory_service.dart:453–461`
- **Suggested follow-up:** Narrow the catch to the specific Supabase `PostgrestException` (or a typed
  wrapper) that indicates a missing/inaccessible table. Let all other exception types propagate.

---

### P1 — Assignment resolver has unordered-query ordering sensitivity

- **Action:** REVIEW
- `fetchAssignments` (line 190–195) fetches all active assignments with no `ORDER BY`. The resolver
  loop at lines 389–396 uses "last-seen non-primary wins" semantics: a non-primary assignment will be
  overwritten only if a later row is marked `is_primary = true`. If an employee has two non-primary
  assignments, the resolved `assignedSite` depends entirely on the order Supabase returns rows — which
  is not guaranteed.
- **Why it matters:** Guard–site assignments displayed in the admin directory could flip on every load
  for employees with multiple active non-primary assignments.
- **Evidence:** `admin_directory_service.dart:388–396`
- **Suggested follow-up:** Add `.order('is_primary', ascending: false)` to `fetchAssignments` in
  `SupabaseAdminDirectoryDataSource`, or change the resolver to prefer the most-recently-updated
  assignment using a `created_at` / `updated_at` field.

---

### P2 — `AdminDirectorySiteRow.contactPerson` and `contactPhone` are permanently hardcoded to `'-'`

- **Action:** DECISION
- `_mapSiteRow` at lines 517–518 assigns `contactPerson: '-'` and `contactPhone: '-'` unconditionally.
  The `AdminDirectorySiteRow` model carries both fields, implying they are meaningful. The `sites`
  table may have a `contact_name` or `contact_person` column that is being ignored.
- **Why it matters:** These fields appear in the admin directory UI. If the table has data for them,
  it is silently discarded every time the directory loads.
- **Evidence:** `admin_directory_service.dart:517–518`
- **Suggested follow-up for Codex:** Check the Supabase `sites` schema for contact fields. If present,
  wire them through; if absent by design, remove the fields from `AdminDirectorySiteRow` to avoid
  dead-weight model properties.

---

### P2 — `clientMessagingEndpointCounts` counts all providers, not just messaging

- **Action:** REVIEW
- `endpointCounts` is incremented at line 279 for every active endpoint regardless of provider (SMS,
  Telegram, email, etc.). The map is then exposed as `clientMessagingEndpointCounts`. In the test at
  line 222, a 3-count includes 2 Telegram + 1 SMS endpoint, confirming the inclusive behavior.
- **Why it matters:** Callers reading `clientMessagingEndpointCounts` may reason about it as
  "Telegram/messaging-only" given the name, causing incorrect UI labels or threshold checks.
- **Evidence:** `admin_directory_service.dart:279`, `admin_directory_service_test.dart:222`
- **Suggested follow-up:** Either rename the field to `clientAllEndpointCounts`, or filter to only
  messaging-relevant providers (telegram, email, sms) and document the intent clearly.

---

### P3 — Duplicate `detailLine` string interpolation for partner endpoints

- **Action:** AUTO
- The `detailLine` string `'$label • chat=...'` is constructed twice with identical expressions: once
  at lines 305–307 (for the `siteDetails` list) and again at lines 317–318 (for the `clientDetails`
  list) inside the same `if (isPartner)` branch.
- **Why it matters:** If the format ever changes, one instance is likely to be missed.
- **Evidence:** `admin_directory_service.dart:305–307` and `317–318`
- **Suggested follow-up:** Extract to a local variable `final detailLine = ...` before the `if
  (siteId.isNotEmpty)` block and reuse it in both places.

---

### P3 — `contract_start` and `contract_end` have asymmetric field sources

- **Action:** REVIEW (suspicion, not confirmed bug)
- `contractStart` maps from `row['contract_start']` (a first-class DB column, lines 480–481), while
  `contractEnd` maps from `metadata['contract_end']` (a JSON field inside a JSONB blob, line 482).
  The asymmetry is not documented and could indicate a schema migration that was half-applied.
- **Why it matters:** If `contract_end` is later promoted to a real column, the service will keep
  reading the stale JSONB value unless updated.
- **Evidence:** `admin_directory_service.dart:480–482`
- **Suggested follow-up:** Confirm whether `contract_end` exists as a first-class column in the
  `clients` table. If so, map it directly like `contract_start`.

---

## Duplication

| Pattern | Locations | Centralization candidate |
|---|---|---|
| `(row['x'] ?? '').toString().trim()` appears ~30 times across the three mapper methods | `_mapClientRow`, `_mapSiteRow`, `_mapEmployeeRow` | A local inline helper `_str(dynamic v, [String fallback = ''])` would reduce noise but is not strictly necessary |
| `partnerChatcheckByClient` / `chatcheckByClient` update pattern is repeated verbatim at lines 338–348 and 344–366 | same loop | Could be a helper `_updateChatcheckMap(map, key, status)` but the map is local so impact is cosmetic |
| `detailLine` construction (see P3 above) | lines 305–307, 317–318 | Single local variable |

---

## Coverage Gaps

1. **Inactive endpoint excluded from counts** — no test for `is_active: false` on an endpoint that
   would otherwise increment `endpointCounts`. Currently implicit but not explicit.

2. **Guard with `terminated` employment status** — `switch` branch `'terminated' =>
   AdminDirectoryStatus.inactive` at line 562 has no test case. Only `suspended` is tested.

3. **Employee with multiple active assignments, none primary** — ordering sensitivity described in P1
   has no test to document expected behavior.

4. **Partner endpoint with empty `site_id`** — when `site_id` is empty the partner endpoint is still
   counted at the client level and added to `clientPartnerLaneDetails`, but `sitePartnerEndpointCounts`
   is skipped. This path is untested.

5. **`chatcheck_unlinked` and `chatcheck_skip` delivery statuses** — `_chatcheckStatusFromEndpointRow`
   handles five `last_delivery_status` values; only `chatcheck_pass` and `chatcheck_blocked` are
   exercised in the test. `chatcheck_fail`, `chatcheck_unlinked`, and `chatcheck_skip` are untested.

6. **`_preferredChatcheckStatus` severity ordering explicit test** — the severity ranking (FAIL wins
   over SKIP wins over PASS) is only validated implicitly through the main scenario. A dedicated unit
   test would lock this contract independently of the snapshot assembly.

7. **`_dateFromDynamic` with null and malformed input** — returns `'-'` for null, `'-'` for bad
   strings — no tests confirm this. If callers depend on `'-'` as the fallback sentinel, a regression
   would be silent.

8. **`_doubleFromDynamic` and `_intFromDynamic` with null / invalid string** — similar to above; both
   return `0` silently. No direct tests.

9. **`_isPartnerEndpointLabel` with custom prefix** — the `partnerEndpointLabelPrefix` parameter is
   never varied in tests; only the default `'PARTNER'` is exercised.

10. **`loadDirectory` shim (the Supabase-wired entry point)** — has no test coverage at all (expected,
    but worth noting for completeness).

---

## Performance / Stability Notes

- **No caching** — `loadDirectoryFromDataSource` hits all six tables on every call. This is
  intentional for an admin snapshot loader, but callers in widget `initState` or `FutureBuilder` must
  not trigger rebuilds that re-call this method. No guard is present inside the service; callers own
  this responsibility.
- **`partnerLaneDetailsBySite` duplicate-check uses `List.contains`** (line 312 and 323) — O(n) per
  insertion. For a typical directory (< 100 partner endpoints per client) this is irrelevant.
- **`hardwareIds.cast<String?>().firstWhere`** at line 500 — safe but iterates the full list. Again,
  hardware ID lists are short in practice.

---

## Recommended Fix Order

1. **(P1) Narrow `catch` in `_loadOptionalRows`** — replace `catch (_)` with a catch scoped to
   Supabase / network exceptions. Prevents silent masking of code bugs. LOW blast radius.
2. **(P1) Add ORDER BY to `fetchAssignments`** — add `.order('is_primary', ascending: false)` to make
   the assignment resolver deterministic. LOW blast radius, schema-safe.
3. **(P2 — DECISION) Resolve `contactPerson`/`contactPhone` dead fields on site rows** — either
   populate from the DB or remove from the model. Needs schema check first.
4. **(P3 — AUTO) Extract duplicate `detailLine` to local variable** in the partner endpoint loop.
5. **(Coverage) Add tests** for `terminated` guard status, inactive endpoint exclusion, and the three
   untested `chatcheck_*` delivery statuses.
6. **(P2) Rename or narrow `clientMessagingEndpointCounts`** — post-DECISION once intent is clarified.
