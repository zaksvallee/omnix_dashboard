# Audit: Demo Hygiene — Hardcoded Data, Placeholders, TODOs

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: repo-wide — all `lib/` files
- Read-only: yes
- Search terms: `TODO`, `PLACEHOLDER`, `hardcoded`, `fake`, `mock`, `demo only`, `temp`, `test data`, `replace-me`, `DEMO-`, `onyx123`

---

## Executive Summary

The codebase is generally well-structured but carries several pieces of developer-identity test data, hardcoded fallback IDs, and demo-seeding strings that would be immediately visible during a live client demo. The highest-severity issue is that the developer's personal details (name, home address, phone number) are the compile-time default scope — meaning any build launched without explicit `ONYX_CLIENT_ID`/`ONYX_SITE_ID` env vars will default to `CLIENT-MS-VALLEE` / `SITE-MS-VALLEE-RESIDENCE`. A second cluster of embarrassing items sits in the admin seeding functions: fake VAT numbers, fake South African ID numbers, and `DEMO-CLT-*` / `DEMO-SITE-*` ID formats that can leak into seeded records. One string can reach client-visible screens at runtime without any debug gate (`DEMO-CLT` in events_review_page).

---

## What Looks Good

- `runtime_config.dart` correctly detects and rejects `replace-me`, `example.com`, and other sentinel placeholder values before they reach live integrations.
- `kDebugMode` guard on `_controllerDemoAccounts` (main.dart:1688) prevents `onyx123` passwords from appearing in release builds.
- HikConnect sanitizer (`hik_connect_bundle_sanitizer.dart`) properly redacts secret/password keys.
- AI prompts explicitly instruct the model never to repeat credentials or secrets.

---

## Findings

### P1 — Developer personal data is the compile-time default scope

- Action: **REVIEW**
- `ONYX_CLIENT_ID` defaults to `'CLIENT-MS-VALLEE'` and `ONYX_SITE_ID` defaults to `'SITE-MS-VALLEE-RESIDENCE'` at compile time.
- A hardcoded profile for this scope in `main.dart` returns the developer's full name and a named address in the site profile resolver, and the admin directory includes the developer's personal phone number (`0824787276`) and home address (`11 Eastwood Street, Reuven, Johannesburg, 2091`).
- Any demo or test build launched without explicit env-var overrides will default to this scope and display the developer's identity in scope selectors, AI narration, and site profile headers.
- Evidence:
  - `lib/main.dart:980-990` — `defaultValue: 'CLIENT-MS-VALLEE'` / `'SITE-MS-VALLEE-RESIDENCE'`
  - `lib/main.dart:18772-18776` — hardcoded profile returning `'Muhammed Vallee'` / `'MS Vallee Residence'`
  - `lib/main.dart:19833-19834` — second special-case branch for same scope
  - `lib/ui/admin_page.dart:1500-1513` — static admin directory seed with real name, address, phone
  - `lib/ui/admin_page.dart:1558-1561` — matching client seed row
  - `lib/application/telegram_ai_assistant_service.dart:587-589` — AI training example references "MS Vallee Residence" by name
  - `lib/ui/admin_page.dart:3947` — hardcoded JSON fixture with `CLIENT-MS-VALLEE`
  - `lib/ui/admin_page.dart:13109` — inline comment referencing "Vallee" by name visible in admin panel
- Suggested follow-up: Codex should verify whether any of these surface in scope dropdowns or AI output during a release-mode demo and confirm the default values are replaced by a neutral sentinel (e.g., `''` or `'ONYX-DEFAULT'`).

---

### P1 — `DEMO-CLT` / `DEMO-SITE` / `REGION-GAUTENG` injected at runtime without debug gate

- Action: **REVIEW**
- When `_timelineWithFocusedFallback` is called with a `focusedEventId` that isn't present in `baseEvents` and `fallbackScope` is null, it injects a synthetic `_SeededDispatchEvent` with `clientId: 'DEMO-CLT'`, `siteId: 'DEMO-SITE'`, and a hardcoded `regionId: 'REGION-GAUTENG'`. This synthetic event is then visible in the events review timeline.
- This path is not gated by `kDebugMode`. It can trigger in a release/demo build whenever a deep-link or route parameter points to an event ID that isn't locally loaded.
- Evidence:
  - `lib/ui/events_review_page.dart:2566-2593` — `_timelineWithFocusedFallback` method
  - `lib/ui/events_review_page.dart:2588` — `clientId: fallbackScope?.clientId ?? 'DEMO-CLT'`
  - `lib/ui/events_review_page.dart:2589` — `regionId: 'REGION-GAUTENG'` (always hardcoded)
  - `lib/ui/events_review_page.dart:2590` — `siteId: fallbackScope?.siteId ?? 'DEMO-SITE'`
- Suggested follow-up: Codex should verify the call sites for `_timelineWithFocusedFallback` and confirm whether `fallbackScope` can ever be null during a production demo, and whether `'REGION-GAUTENG'` needs to be derived from runtime config instead.

---

### P2 — Autopilot narration strings expose internal demo framing to the client

- Action: **REVIEW**
- The admin route's `autopilotNarration` is `'Demo seeding and runtime controls.'` (shown in the autopilot overlay during demo walkthroughs). The reports route uses `'Demonstrate export and report proof.'`
- During a live autopilot demo the app announces these strings, making it explicit to the client that they are watching a staged demo with seeded controls — which undermines the demo's credibility.
- Evidence:
  - `lib/domain/authority/onyx_route.dart:166` — reports route narration: `'Demonstrate export and report proof.'`
  - `lib/domain/authority/onyx_route.dart:174` — admin route narration: `'Demo seeding and runtime controls.'`
- Suggested follow-up: Narration copy should be rewritten in operational language (e.g., `'Reviewing incident evidence and generated reports.'`, `'Accessing system configuration.'`).

---

### P2 — `onyx123` demo passwords visible in debug login UI

- Action: **REVIEW**
- Three controller login accounts with password `'onyx123'` are defined in `_controllerDemoAccounts`. The accounts are gated behind `kDebugMode` (main.dart:1688) so they're absent from release builds. However, debug builds render a prominent `'DEMO ACCOUNTS'` section in the login page with tap-to-fill tiles showing username, role, and access level — including all three accounts. A client who notices this section will immediately understand the app is running in demo mode with a weak shared password.
- Evidence:
  - `lib/main.dart:1687-1717` — `_controllerDemoAccounts` getter with `onyx123`
  - `lib/ui/controller_login_page.dart:254` — `'DEMO ACCOUNTS'` header rendered in UI
  - `lib/ui/controller_login_page.dart:65-67` — error message: `'Demo accounts are unavailable in this build.'`
- Suggested follow-up: Confirm whether demos always run debug builds. If yes, consider suppressing the "DEMO ACCOUNTS" label from the visible UI (use a neutral label or omit the section header).

---

### P2 — Fake VAT number `4499912345` as seeding default

- Action: **AUTO**
- The VAT number `'4499912345'` is used as a hardcoded default in three distinct seeding paths. If an operator seeds a client record using the autofill function without editing this field, a fake VAT number is committed to the database as the client's billing record.
- Evidence:
  - `lib/ui/admin_page.dart:23005` — `vatNumber = '4499912345'` in `_buildDemoSeedPayload`
  - `lib/ui/admin_page.dart:28616` — `String defaultVat = '4499912345'` in `_autoFillMissingForDemo`
  - `lib/ui/admin_page.dart:28917` — `_vatNumberController.text = '4499912345'` in quickfill
- Suggested follow-up: Codex should replace all three with `''` (empty) so the field is left blank pending real input.

---

### P2 — Fake South African ID number `9003031234080` as seeding default

- Action: **AUTO**
- The ID number `'9003031234080'` appears as a hardcoded default in four employee seeding paths. If seeded without correction, this fake ID appears in employee records.
- Evidence:
  - `lib/ui/admin_page.dart:23068` — `employeeIdNumber = '9003031234080'`
  - `lib/ui/admin_page.dart:36154` — `defaultId = '9003031234080'` (controller role)
  - `lib/ui/admin_page.dart:37094` — returned as default from a helper function
  - `lib/ui/admin_page.dart:39278` — `_idNumberController.text = '9003031234080'`
- Suggested follow-up: Codex should replace with `''` across all four sites.

---

### P2 — Fake Telegram chat IDs in demo seeding

- Action: **REVIEW**
- Placeholder Telegram chat IDs (`-1000000000000`, `-1000000001001`, `-1000000002002`) are used as defaults in the client autofill flow. If a seeded client record retains these IDs, Telegram notifications will silently fail for that client (messages sent to non-existent groups are silently dropped by the bot API).
- Evidence:
  - `lib/ui/admin_page.dart:28621` — `defaultTelegramChatId = '-1000000000000'`
  - `lib/ui/admin_page.dart:28633` — `'-1000000001001'` (industrial scenario)
  - `lib/ui/admin_page.dart:28644` — `'-1000000002002'` (retail scenario)
  - `lib/ui/admin_page.dart:28883` — `_telegramChatIdController.text = '-1000000001001'`
  - `lib/ui/admin_page.dart:28893` — `'-1000000002002'`
  - `lib/ui/admin_page.dart:28902` — `'-1000000000000'`
- Suggested follow-up: Consider whether these IDs should be left blank rather than pre-populated with obviously fake values. If the intent is to seed a working demo Telegram group, these should point to a real test group, documented in the ops runbook.

---

### P2 — Demo email addresses hardcoded in seeding functions

- Action: **REVIEW**
- Three demo employee emails are hardcoded in seeding functions. If seeded into real client records without editing, these fake addresses appear in client employee data and will receive no real messages.
- Evidence:
  - `lib/ui/admin_page.dart:22998` — `employeeEmail = 'kagiso.demo@onyx-security.co.za'`
  - `lib/ui/admin_page.dart:36146` — `defaultEmail = 'lerato.guard@onyx-security.co.za'`
  - `lib/ui/admin_page.dart:36163` — `defaultEmail = 'anele.controller@onyx-security.co.za'`
- Suggested follow-up: Verify whether these `@onyx-security.co.za` addresses are real inboxes. If not, the domain or address should be changed to something clearly inert (e.g., `example.com`) or left blank.

---

### P3 — `replace-me` defaults in HikConnect bootstrap services

- Action: **AUTO**
- Multiple HikConnect service constructors use `'replace-me'` as the default value for `appKey` and `appSecret`. The `runtime_config.dart` sentinel detection (`_isPlaceholderSecret`) will correctly reject these before they reach the API, so there is no functional risk. However, if any log line or error message emits the raw value, a client would see `replace-me` in a diagnostics panel.
- Evidence:
  - `lib/application/hik_connect_bootstrap_orchestrator_service.dart:49-50, 88-89, 117-118`
  - `lib/application/hik_connect_bootstrap_packet_service.dart:20-21`
  - `lib/application/hik_connect_scope_seed_formatter.dart:14-15, 48-49`
  - `lib/application/hik_connect_env_seed_formatter.dart:9-10`
  - `lib/application/hik_connect_preflight_runner_service.dart:44-45`
- Suggested follow-up: Replace the default with `''` (empty string) since the sentinel check catches both empty and `replace-me`; this removes the visible string from any logs or stack traces.

---

### P3 — `https://api.hik-connect.example.com` fallback URL in two files

- Action: **AUTO**
- Two files use `'https://api.hik-connect.example.com'` as a fallback when `api.config.baseUri` is null. This URL is also caught by `runtime_config.dart`'s `isExampleComHost` check (line 86), so it won't be contacted. However, the string appears in the generated payload bundle JSON that the template service writes out, and it would be visible in any exported diagnostics file.
- Evidence:
  - `lib/application/hik_connect_payload_bundle_collector_service.dart:55`
  - `lib/application/hik_connect_preflight_runner_service.dart:94`
- Suggested follow-up: Replace the fallback with `''` or remove the fallback entirely and let the null propagate to an explicit error, so the output file never contains an `example.com` URL.

---

### P3 — TODO: hardcoded patrol expectation in performance projection

- Action: **REVIEW**
- `_expectedPatrolsPerCheckIn = 8` is a business-logic constant that the author explicitly flagged as needing to move to per-contract configuration. This constant directly affects the guard performance report shown to clients (patrol completion rate). Different clients may have different contractual patrol frequencies.
- Evidence:
  - `lib/domain/crm/reporting/dispatch_performance_projection.dart:8` — `// TODO(zaks): Per-contract value — move to client configuration when contract data model is ready.`
- Suggested follow-up: This is a deferred product decision. Zaks should decide whether `8` is an acceptable universal fallback until the contract model is ready, or whether the report should omit the metric when no per-contract value is configured.

---

## Duplication

- `DEMO-CLT` / `DEMO-SITE` prefixes are scattered across admin_page.dart (~10 call sites) and events_review_page.dart with no single constant defining them. If the prefix is ever renamed, it will be missed.
- The fake VAT `'4499912345'` appears in 3 separate switch branches rather than a single constant.
- The fake ID `'9003031234080'` appears in 4 separate locations rather than a single constant.

---

## Coverage Gaps

- No test covers the `_timelineWithFocusedFallback` null-scope path (the P1 `DEMO-CLT` fallback branch).
- No test asserts that `_controllerDemoAccounts` returns empty in non-debug mode.
- No test verifies that seeding autofill functions leave VAT/ID fields blank when no real value is provided.

---

## Performance / Stability Notes

None identified that are specific to demo hygiene.

---

## Recommended Fix Order

1. **P1 — Developer personal data as default scope** (`main.dart:980-990`, `admin_page.dart:1500-1513`): replace compile-time defaults with empty strings or a neutral demo sentinel; remove static admin-directory rows with personal details before any client demo. Codex must validate whether running without env vars causes visible breakage before touching defaults.

2. **P1 — `DEMO-CLT` / `DEMO-SITE` runtime fallback** (`events_review_page.dart:2588-2590`): gate the fallback behind `kDebugMode` or derive `clientId`/`siteId`/`regionId` from the configured runtime scope instead of hardcoded strings.

3. **P2 — Autopilot narration copy** (`onyx_route.dart:166, 174`): rewrite to operational language before using autopilot in a client demo.

4. **P2/AUTO — Fake VAT and ID number defaults** (`admin_page.dart`: 23005, 28616, 28917, 23068, 36154, 37094, 39278): replace with `''`.

5. **P3/AUTO — `replace-me` defaults and `example.com` URLs**: replace with `''` across all HikConnect bootstrap services and bundle collector.

6. **P3 — TODO patrol constant** (`dispatch_performance_projection.dart:8`): product decision required before implementation.
