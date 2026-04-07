# Audit: lib/domain/authority/onyx_route.dart

- Date: 2026-04-08
- Auditor: Claude Code
- Scope: `lib/domain/authority/onyx_route.dart`, `test/domain/onyx_route_test.dart`, `test/ui/onyx_route_registry_sections_test.dart`
- Read-only: yes

---

## Executive Summary

`onyx_route.dart` is well-engineered for a route authority file. The enum is the single source of truth, all metadata is validated at startup via `StateError`, `fromLocation` is guarded with a map-first then linear scan, and unmodifiable collections are used throughout. Test coverage is strong and deliberately structured.

One confirmed data mismatch exists between the live enum and the test fixture (governance badge color). Everything else is either a minor structural note or a suspicion.

---

## What Looks Good

- Single-file authority: the `/// Authoritative ONYX route enum. This is the ONLY route definition allowed.` comment is enforced in practice — no duplicate route lists found.
- Startup validation in `_buildOnyxRoutes` / `_buildOnyxRouteSections` / `_buildOnyxRouteByPath` catches every invariant (badge pairing, label uniqueness, uppercase constraints, path format) before the app runs. Failing fast on bad enum data is the right approach.
- `fromLocation` uses a pre-built `Map<String, OnyxRoute>` for O(1) exact hits before falling back to a linear scan. Hot-path efficient.
- `_normalizeOnyxRouteLocation` strips query and fragment before matching — correct and explicit.
- `_matchesNormalizedLocation` guards against double-slash nesting (`!nestedPath.contains('//')`) — the test coverage at line 206 confirms this is intentional.
- `_buildOnyxRouteSectionRoutes` validates every section has at least one route.
- All returned collections are `List.unmodifiable` / `Map.unmodifiable` — no mutation leakage possible.
- Test coverage in `onyx_route_test.dart` mirrors every invariant in the production build validators. The `_expectedShellBadges`, `_expectedAgentFocusSources`, `_expectedCustomAgentScopes` maps make regressions explicit.

---

## Findings

### P1

- **Action: AUTO**
- **Finding:** Confirmed badge color mismatch between enum and test fixture for `governance`.
- **Why it matters:** The test fixture `_expectedShellBadges` at line 249 in `onyx_route_test.dart` records `governance` badge color as `Color(0xFFF59E0B)` (amber). The enum at line 109 in `onyx_route.dart` declares `Color(0xFF60A5FA)` (blue). The test passes because it only checks routes listed in `_expectedShellBadges` — and the fixture value is wrong relative to source. If the badge is rendered using the enum value, the test fixture silently diverges from the live color and no assertion fails. One of these two values is intended; the other is stale.
- **Evidence:**
  - `lib/domain/authority/onyx_route.dart:109` — `shellBadgeColor: Color(0xFF60A5FA)`
  - `test/domain/onyx_route_test.dart:249` — `color: Color(0xFFF59E0B)`
- **Suggested follow-up:** Codex should confirm which color is the Figma-approved value for the governance badge and align the enum and test fixture.

---

### P2

- **Action: REVIEW**
- **Finding:** `_buildOnyxRoutes()` builds five separate maps (`routesByLabel`, `routesByNormalizedLabel`, `routesByShellHeaderLabel`, `routesByAutopilotLabel`, `routesByNormalizedAutopilotLabel`, `routesByAutopilotKey`) that are used only for duplicate-detection during startup, then discarded. These are never stored on a module-level variable or reused.
- **Why it matters:** Not a bug. Not a performance concern at startup. But the function builds six temporary maps with full iteration, all of which are thrown away. If a seventh uniqueness constraint is ever added, this pattern silently accumulates cost. The existing `_onyxRouteByPath` map (stored at module level) is the only one that survives. The startup-only maps could be replaced by a simpler set-based check or a single pass with assertions. Low priority — raise only if the file gets more constraints.
- **Evidence:** `lib/domain/authority/onyx_route.dart:249–350`
- **Suggested follow-up:** No action required now. Revisit if `_buildOnyxRoutes` grows more constraints.

- **Action: REVIEW**
- **Finding:** `_onyxRouteSections` (line 244) and `_onyxRoutes` (line 246) are module-level `final` lists initialized via builder functions. `_onyxRouteSectionRoutes` (line 387) depends on `_onyxRouteSections` and `_onyxRoutes`. `_onyxRouteByPath` (line 385) depends on `_onyxRoutes`. Dart top-level `final` variables are lazily initialized in declaration order within a library — the current declaration order (`_onyxRouteSections` → `_onyxRoutes` → `_onyxRouteByPath` → `_onyxRouteSectionRoutes`) is correct. However, `OnyxRouteSection.routes` (line 17) calls `_onyxRouteSectionRoutes[this]!` — any call to `.routes` before `_onyxRouteSectionRoutes` is initialized would throw a null deref or LateInitializationError depending on Dart's lazy init chain. This is safe as long as no test or app code touches `OnyxRouteSection.routes` before the library is initialized. This is the expected Dart behavior and currently works correctly, but initialization order is fragile if module-level state is ever reordered.
- **Evidence:** `lib/domain/authority/onyx_route.dart:17, 244–388`
- **Suggested follow-up:** Suspicion only, not confirmed. Codex should verify no test directly accesses `OnyxRouteSection.routes` in an isolated context before `_onyxRouteSectionRoutes` is warm.

---

### P3

- **Action: AUTO**
- **Finding:** `_matchesNormalizedLocation` (line 216) validates nested paths by checking `!nestedPath.startsWith('/')` and `!nestedPath.contains('//')`. However, it does not check that the nested path segment is otherwise valid per the route path pattern (`_onyxRoutePathPattern`). A location like `/dashboard/a b c` (space-encoded or raw) would match `dashboard` if the caller doesn't pre-normalize. In practice GoRouter encodes URLs before passing them to location matchers, so this is a low-risk edge case — but it is an implicit dependency on caller behaviour.
- **Evidence:** `lib/domain/authority/onyx_route.dart:216–228`
- **Suggested follow-up:** Codex should confirm whether GoRouter always delivers percent-encoded paths to location matchers, or if raw paths are ever passed. No change needed if confirmed.

---

## Duplication

- **Test regex duplication:** `_onyxRoutePathPattern` and `_onyxRouteAutopilotKeyPattern` are declared both in `onyx_route.dart` (lines 379–383) and copied verbatim into `test/domain/onyx_route_test.dart` (lines 268–272). If either pattern changes in the source, the test copy must be manually updated — a silent drift risk.
  - Files: `lib/domain/authority/onyx_route.dart:379–383`, `test/domain/onyx_route_test.dart:268–272`
  - Centralization candidate: expose these as `@visibleForTesting` constants from the source, or from a dedicated `onyx_route_patterns.dart` that both source and test import. **Action: REVIEW**

---

## Coverage Gaps

- **Badge color is not asserted against the live enum value.** The `_expectedShellBadges` map in the test is a manually maintained fixture, not derived from the enum. If an enum badge color changes, the test will not catch the drift unless the fixture is also updated. This is the root cause of the P1 finding above.
  - Suggested gap close: derive the expected fixture from the enum itself, or at minimum assert that `route.shellBadgeColor == _expectedShellBadges[route]!.color` using the enum as the reference, not the fixture.

- **No test covers `_normalizeOnyxRouteLocation` with a fragment placed before a query string** (e.g. `/dashboard#focus?tab=x`). This is a malformed URL but some navigation frameworks can produce it. The current implementation strips `#` and `?` independently by scanning left-to-right — if `#` appears before `?`, the `?` is ignored (since `end` is already set). The result would be `/dashboard` which is correct, but this case is not explicitly tested.

- **No test covers `fromLocation` with an empty string or a string that does not start with `/`**. `fromLocation('')` would normalize to `''`, fail the map lookup, and fall back to `OnyxRoute.dashboard` via the `firstWhere` `orElse`. This is acceptable behavior but is implicit rather than specified.

---

## Performance / Stability Notes

- No hot-path concerns. `fromLocation` does a map lookup first, with a linear scan only as fallback — this is correct and efficient for the enum size (~14 routes).
- All initialization work happens once at app-startup via module-level lazy finals. No repeated computation in route resolution paths.
- `_buildOnyxRoutes` allocates six maps for ~14 routes at startup and discards them. Negligible cost in practice.

---

## Recommended Fix Order

1. **(P1 AUTO)** Resolve the governance badge color mismatch between `onyx_route.dart:109` and `onyx_route_test.dart:249`. Confirm the intended color and align both. One value is wrong.
2. **(Duplication AUTO)** Remove the regex copies from `onyx_route_test.dart` and import them from the source (or a shared constants file) to prevent silent drift.
3. **(Coverage REVIEW)** Add an empty-string and non-slash-prefixed path case to `fromLocation` tests to make the fallback behavior explicit.
4. **(P2 REVIEW)** Verify Dart lazy initialization order is safe for `OnyxRouteSection.routes` in isolated test contexts. Low risk but worth confirming.
5. **(P3 REVIEW)** Confirm GoRouter always delivers encoded paths to location matchers, closing the `_matchesNormalizedLocation` edge case.
