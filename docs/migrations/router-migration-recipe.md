# Router Migration — Phase 2 Recipe (for Codex)

**Audience**: Codex, executing the Phase 2 bulk conversion of in-state navigation call sites to `go_router`.

**Assumes**: Phase 1 has landed (`feat(routing): add go_router scaffold …`). `GoRouter` is live, `MaterialApp.router` is the authenticated controller-mode root, `_routerRefreshNotifier` bridges `setState` to router rebuilds, Alarms is migrated as the reference page, Zara Home (`/`) and Command Center (`/dashboard`) are split.

**Goal of Phase 2**: convert the remaining legacy navigation call sites — `setState(() { _route = OnyxRoute.X; })` and `_applyRouteBuilderState(() { _route = OnyxRoute.X; })` — to the router-driven pattern `setState(pre-seed); _router.go(OnyxRoute.X.path);`. Do this mechanically, one page at a time, verifying per page.

**Non-goals**: do NOT remove `_route` or `_applyRouteBuilderState`. Do NOT flip `_buildPage` to URL-driven dispatch. Do NOT touch the special cases flagged below. Do NOT touch any file listed under "Files off-limits."

---

## 0. Sanity checks before starting

```bash
git status                              # tree clean
git log -1 --oneline                    # HEAD should be 8e14f1b or later
flutter pub get                         # go_router + flutter_web_plugins must resolve
dart analyze lib/                       # 0 issues
flutter test test/ui/ --reporter compact | tail -3
# Baseline: 505 pass / 518 fail (pre-existing failures — do not try to fix).
```

If any of the above is off, stop and report before converting anything.

---

## 1. The pattern to find

There are two shapes. Both live inside `_OnyxAppState` in `lib/main.dart` and its `part of` extension files (`lib/ui/onyx_route_*_builders.dart`).

### Shape A — direct setState

```dart
setState(() {
  _route = OnyxRoute.<destination>;
});
```

Or coupled with other state:

```dart
setState(() {
  _someField = value;
  _anotherField = anotherValue;
  _route = OnyxRoute.<destination>;
});
```

### Shape B — via `_applyRouteBuilderState`

```dart
_applyRouteBuilderState(() {
  _route = OnyxRoute.<destination>;
});
```

Or coupled:

```dart
_applyRouteBuilderState(() {
  _operationsFocusIncidentReference = ref;
  _route = OnyxRoute.<destination>;
});
```

`_applyRouteBuilderState` is a thin wrapper over `setState`; treat it the same for this migration.

### How to find them

```bash
# All _route = OnyxRoute.X call sites
grep -rnE "_route\s*=\s*OnyxRoute\." lib/ --include="*.dart"

# All _applyRouteBuilderState call sites
grep -rn "_applyRouteBuilderState" lib/ --include="*.dart"
```

As of Phase 1 commit, **75** `_route = X` call sites and **17** `_applyRouteBuilderState` call sites exist. One of the `_route = X` sites (Alarms in `onyx_route_command_center_builders.dart:100`) was migrated in Phase 1 as reference — do not re-migrate it. Three more were removed entirely (the Zara Home Command Center / Dispatches / CCTV buttons, now using `_router.go`).

---

## 2. The pattern to replace with

### Transformation rule

```
BEFORE                                          AFTER
─────────────────────────────────────────────   ─────────────────────────────────────────────
setState(() {                                   setState(() {
  _fieldA = valueA;                               _fieldA = valueA;
  _fieldB = valueB;                               _fieldB = valueB;
  _route = OnyxRoute.destination;               });
});                                             _router.go(OnyxRoute.destination.path);
```

If the setState block contains nothing but the route assignment:

```
BEFORE                                          AFTER
─────────────────────────────────────────────   ─────────────────────────────────────────────
setState(() {                                   _router.go(OnyxRoute.destination.path);
  _route = OnyxRoute.destination;
});
```

For `_applyRouteBuilderState` — same, collapsed:

```
BEFORE                                          AFTER
─────────────────────────────────────────────   ─────────────────────────────────────────────
_applyRouteBuilderState(() {                    _router.go(OnyxRoute.destination.path);
  _route = OnyxRoute.destination;
});
```

If `_applyRouteBuilderState` contains coupled mutations:

```
BEFORE                                          AFTER
─────────────────────────────────────────────   ─────────────────────────────────────────────
_applyRouteBuilderState(() {                    setState(() {
  _fieldA = valueA;                               _fieldA = valueA;
  _route = OnyxRoute.destination;               });
});                                             _router.go(OnyxRoute.destination.path);
```

### Critical rule: never remove the setState if other state is being mutated

`_router.go(path)` is a navigation call. It does **not** trigger a setState. If you remove the setState block entirely when there are non-`_route` field mutations inside it, those mutations become orphans that never cause a rebuild.

If the original block mutates 2+ fields (of which `_route` is one), keep the setState for the other fields; append `_router.go(path)` after it.

A quick per-site check:

- Count the lines inside the block that match `^\s*_[a-zA-Z]\w*\s*=`.
- If only one line and it's `_route = X`: drop the setState, use `_router.go(...)` alone.
- Otherwise: keep setState for the other fields, remove the `_route =` line, append `_router.go(...)`.

---

## 3. Reference migration — Alarms (worked example)

Phase 1 already landed this. Shown here as the canonical before/after so Codex can pattern-match.

**File**: `lib/ui/onyx_route_command_center_builders.dart` (inside the Zara Home builder block).

**Before** (Phase 0 / origin):

```dart
onOpenAlarms: () {
  _cancelDemoAutopilot();
  _applyRouteBuilderState(() {
    _route = OnyxRoute.alarms;
  });
},
```

**After** (Phase 1):

```dart
onOpenAlarms: () {
  _cancelDemoAutopilot();
  _router.go(OnyxRoute.alarms.path);
},
```

`_cancelDemoAutopilot()` is an imperative side-effect, not a setState argument, so it stays. The `_applyRouteBuilderState` wrapping a sole `_route` assignment collapses entirely to `_router.go(...)`.

---

## 4. Parametered routes

None in Phase 2. The 16 `OnyxRoute` destinations all have static paths. Deep-linking with scope/origin metadata (the `ZaraEventsRouteSource` / `_eventsScopedEventIds` flow) is **Phase 3** work and must not be touched in Phase 2. See "Special cases" below.

If you ever need `context.go('/events/:id')`-style parametered routing in a future phase, the path would become `/events/:eventId` with `GoRouterState.of(context).pathParameters['eventId']`. **Not now.**

---

## 5. Navigation-with-state

Call sites with coupled field mutations must be split as documented in §2. Concretely:

```dart
// BEFORE
setState(() {
  _operationsFocusIncidentReference = ref;
  _dispatchRouteClientId = clientId;
  _dispatchRouteSiteId = siteId;
  _route = OnyxRoute.dispatches;
});

// AFTER
setState(() {
  _operationsFocusIncidentReference = ref;
  _dispatchRouteClientId = clientId;
  _dispatchRouteSiteId = siteId;
});
_router.go(OnyxRoute.dispatches.path);
```

The setState block mutates the coupled state (focus incident + scope). `_router.go` then changes the URL. The router's ListenableBuilder wrappers see the setState ping, rebuild, pick up the new `_route` (which the router listener updates from the URL match), and render the new page with the pre-seeded scope state.

This is the whole point of the `_routerRefreshNotifier` bridge landed in Phase 1.

---

## 6. Special cases — do NOT bulk-convert

These destinations have behaviour that Stage 1 analysis flagged as Phase 3 work. **Leave their call sites untouched.** Human review will migrate them in Phase 3.

### 6.1 Scope-rail origin tracking (Events page)

- Files involved: `lib/ui/events_route_source.dart`, `lib/ui/events_review_page.dart`, and any `_openEventsForScope` / `_openEventsForScopedEventIds` call sites in `lib/main.dart` and `lib/ui/onyx_route_*_builders.dart`.
- Why Phase 3: the scope-rail carries `ZaraEventsRouteSource` + `originLabel` + `_eventsScopedEventIds` state that round-trips from the caller through Events back to a "← back to origin" chip. Phase 3 encodes origin/originLabel as URL query parameters; scoped event IDs stay in-memory as today.
- **Do not migrate**: `_openEventsForScope`, `_openEventsForScopedEventIds`, `_openEventsFromAdminIncident`, `_openEventsForEventId`, `_returnFromScopedEvents`, any caller that sets `_eventsRouteSource` alongside `_route = OnyxRoute.events`.

### 6.2 Command Center ↔ Zara Home flip

Phase 1 already split these into `/` and `/dashboard`. The legacy `_zaraAmbientActive` flag is gone. There should be nothing left to migrate here — if you find a `_zaraAmbientActive` reference, it was missed in Phase 1; stop and report.

### 6.3 Demo autopilot

- File: `lib/main.dart` — `_demoAutopilotRouteTimer`, `_demoAutopilotSequence`, `_advanceDemoAutopilot`, and related.
- Why Phase 3: the autopilot drives `_route` on a timer to walk through a canned demo sequence. Migrating it requires considering timing of `_router.go` under the autopilot's paused / skipped / stopped state controls. Phase 3 will rewrite the autopilot's `_route = X` writes to `_router.go(X.path)` as a coherent block.
- **Do not migrate**: anything inside `_advanceDemoAutopilot`, `_stopDemoAutopilotFromShell`, `_skipDemoAutopilotFromShell`, `_toggleDemoAutopilotPauseFromShell`, the sequence-building helpers.

### 6.4 Telegram deep-link entry points

- File: `lib/main.dart` — `_handleTelegramAdminInboundUpdate`, `_handleTelegramPartnerInboundUpdate`, `_handleTelegramAiInboundUpdate`, and all `_handleTelegram*` handlers that pre-seed operational state before setting `_route`.
- Why Phase 3: these handlers set `_route` after mutating a dozen other fields, and the sequence of "pre-seed → navigate" must be preserved carefully. They also interact with `_telegramAdminRuntimeStateHydrationFuture`.
- **Do not migrate**: any `_handleTelegram*` method's navigation block.

### 6.5 `_handleControllerAuthenticated` and `_resetControllerPreviewSession`

- File: `lib/main.dart`.
- Already partially Phase-1 aware: `_handleControllerAuthenticated` calls `_router.go(targetPath)` after the setState. Leave it alone.
- `_resetControllerPreviewSession` still uses legacy `_route = OnyxRoute.dashboard;`. Phase 3 will migrate with its full state-reset context.

### 6.6 `initialRouteOverride` path in `initState`

- File: `lib/main.dart` around line 3319: `_route = widget.initialRouteOverride!;`.
- This runs before the router is built. Leave untouched — it's the seed value for the router's `initialLocation`.

### 6.7 Sync-from-router path (`_syncRouteFromRouter`)

- File: `lib/main.dart`.
- This is the state→URL mirror. It calls `setState(() { _route = … });` specifically to mirror URL changes. Leave it. Not a navigation call site.

### 6.8 Zara Theatre smoke harness

- File: `lib/smoke/zara_theatre_smoke.dart`.
- Has its own local `_route` state independent of `_OnyxAppState`. Do not touch.

### 6.9 `_applyRouteBuilderState` definition itself

- File: `lib/main.dart` around line 2217.
- The definition is:
  ```dart
  void _applyRouteBuilderState(VoidCallback mutation) {
    setState(mutation);
  }
  ```
  Leave it. Callers migrate individually. Phase 3 retires the helper when its call sites reach zero.

---

## 7. Per-page migration procedure (strict)

Run this loop for each destination page you convert:

1. Pick ONE destination, e.g. `OnyxRoute.vip`.
2. Find every call site:
   ```bash
   grep -rnE "_route\s*=\s*OnyxRoute\.vip" lib/ --include="*.dart"
   grep -rn "_applyRouteBuilderState" lib/ --include="*.dart" | grep -B0 "OnyxRoute.vip" || true
   ```
3. For each call site, check whether it falls under a "special case" in §6. If yes, SKIP it (leave as-is) and log in your report.
4. For each non-special call site, apply the transformation per §2.
5. After migrating the page's call sites:
   ```bash
   dart analyze lib/
   # must be 0 issues
   flutter test test/ui/ --reporter compact | tail -3
   # must match baseline (505 pass / 518 fail) — no regressions
   ```
   If analyze has new issues or the pass count drops below 505, REVERT your edits for this page and STOP. Report.
6. Commit per page:
   ```
   feat(routing): migrate <page> call sites from _route setState to _router.go
   ```
   Body: list the files touched and the number of call sites migrated. Call out any call sites you intentionally skipped (special cases).
7. Move to the next page.

Do not batch multiple pages into one commit. Bisectability is load-bearing if a later regression surfaces.

---

## 8. Verification steps per page

After each page migration:

- `dart analyze lib/` → 0 issues
- `flutter test test/ui/ --reporter compact` → 505 pass / 518 fail (or better)
- `flutter build web --release` (only once at end of Phase 2, not per page — it's slow)
- Navigate manually to the page's URL (e.g. `http://localhost:xxxx/vip`) and verify the page renders correctly, nav rail highlights the right chip, back button works.
- Navigate FROM the page via an in-page action (scope rail, detail drill-in, etc.) and verify the navigation still works if those use legacy `setState(() { _route = X; })` — they should, thanks to the `_routerRefreshNotifier` bridge.

---

## 9. Explicit non-goals for Phase 2

- Do NOT remove `_route`.
- Do NOT remove `_applyRouteBuilderState`.
- Do NOT remove `_buildPage` (lib/ui/onyx_route_dispatcher.dart). It's the compatibility dispatcher that makes the 74 legacy call sites work during Phase 2.
- Do NOT modify `main.dart` beyond the per-call-site transformation.
- Do NOT modify `lib/routing/onyx_router.dart`.
- Do NOT modify `lib/ui/app_shell.dart` or any `AppShell*` internals.
- Do NOT touch any `ensure_*.sh`, `Makefile`, `pubspec.yaml`, or `pubspec.lock` changes.
- Do NOT refactor the page internals (state shape, widget structure, styling).
- Do NOT fix unrelated pre-existing test failures — even if you notice one while working. Log them in the Phase 2 report for a separate session.
- Do NOT push commits. Local-only.

---

## 10. Files off-limits

- `lib/routing/onyx_router.dart`
- `lib/main.dart` **except** for per-call-site transformations matching §2's shape. Any new method, field, import, or structural change to `main.dart` is out of scope — report and wait.
- `lib/ui/onyx_route_dispatcher.dart`
- `lib/ui/app_shell.dart`
- `lib/smoke/zara_theatre_smoke.dart`
- `lib/ui/events_review_page.dart` and `lib/ui/events_route_source.dart` (Phase 3 territory)
- All Telegram handler methods (Phase 3 territory)

---

## 11. Phase 2 completion checklist

When every non-special-case call site has been migrated:

- Every `_route = OnyxRoute.X` write that ISN'T in a §6 special case should be gone. The remaining ones are:
  - the `initState` seed at `lib/main.dart` ~3319
  - the `_syncRouteFromRouter` mirror
  - the Phase 3 special cases enumerated in §6
  - the smoke harness's local `_route`
- `_applyRouteBuilderState` may still have a handful of call sites (those in §6) and its definition.
- All per-page commits have landed.
- `dart analyze lib/` clean.
- `flutter test test/ui/` at baseline or better.
- `flutter build web --release` succeeds.
- Report Phase 2 complete with per-page commit hashes and a count of migrated call sites.

---

## Appendix — quick cheat sheet

| You see                                                | Transform to                                     |
|---                                                    |---                                               |
| `setState(() { _route = OnyxRoute.X; });`              | `_router.go(OnyxRoute.X.path);`                  |
| `_applyRouteBuilderState(() { _route = OnyxRoute.X; });` | `_router.go(OnyxRoute.X.path);`                |
| Multi-field setState block ending in `_route = X`     | Keep setState for the other fields; remove `_route` line; append `_router.go(X.path);` after |
| Block that sets `_eventsRouteSource` + `_route = events` | SKIP — Phase 3                                 |
| Block that sets `_eventsScopedEventIds` + `_route = events` | SKIP — Phase 3                              |
| Block inside `_handleTelegram*`                       | SKIP — Phase 3                                   |
| Block inside `_advanceDemoAutopilot` etc              | SKIP — Phase 3                                   |
| Block inside `_syncRouteFromRouter`                   | SKIP — infrastructure, not a nav call            |
| Block inside `_handleControllerAuthenticated` or `_resetControllerPreviewSession` | SKIP — Phase 3  |

---

End of recipe. Questions? Stop and ask before bending any rule above — the compatibility bridge that keeps 74 legacy call sites working during this transition is fragile by design, and the only safe assumption is that if a call site isn't explicitly shaped like §2, it belongs in §6.
