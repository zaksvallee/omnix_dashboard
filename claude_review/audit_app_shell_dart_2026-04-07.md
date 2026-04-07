# Audit: lib/ui/app_shell.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/ui/app_shell.dart`, cross-referenced with `test/ui/app_shell_widget_test.dart`
- Read-only: yes

---

## Executive Summary

`app_shell.dart` is 1649 lines and carries the full shell chrome: sidebar, top bar, intel ticker, quick-jump dialog, and a mobile overlay. The core layout logic is sound and the test file is reasonably comprehensive for happy paths. However, there are three concrete bug risks — one of which is a `LateInitializationError` that can be triggered in production — and a build-phase side-effect pattern in `_ShellIntelTickerState` that violates Flutter's state-update rules. Structural issues are modest but real: `OnyxIntelTickerItem` is a domain data class stranded in a UI file, and the re-export of `onyx_route.dart` from the UI layer inverts the import dependency. Autopilot controls are duplicated across desktop and mobile paths.

---

## What Looks Good

- `_Sidebar` badge mapping via `_badgeForRoute` / `OnyxRouteShellBadgeKind` is clean and centralised — adding a new badge kind only requires touching `OnyxRoute`.
- `_ShellIntelTicker` source-filter chip logic is well-decomposed (`_sourceCounts`, `_availableFilters`, `_filteredItems`) and independently testable.
- `_wrapShellShortcuts` correctly registers both `meta+K` and `ctrl+K`, and tests for both are present.
- `_autoScrollTick` guards against `mounted`, `_hovering`, `_userInteracting`, and `!hasClients` before touching the scroll controller — no crash risk there.
- `dispose()` properly cancels the timer and disposes the scroll controller (lines 1301–1305).
- Quick-jump dialog leaks no route state on dismiss — the `context.mounted` check at line 176 is present and correct (for the normal path).
- Test file covers: mobile drawer, landscape phone, desktop chrome, sidebar badges, operator chip, ticker render, ticker filter, ticker tap callback, quick-jump search + navigate, keyboard shortcuts, status snack. Good breadth for a shell.

---

## Findings

### P1 — Bug: `LateInitializationError` when `showDialog` throws
- **Action:** AUTO
- **Finding:** `selection` is declared `late final OnyxRoute?` at line 23, then assigned only inside the `try` block that `await`s `showDialog`. If `showDialog` throws before returning (e.g., context becomes invalid mid-dialog or a framework assertion fires), `selection` is never assigned. The `finally` block runs, and then line 176 reads `selection` — throwing `LateInitializationError` at the call site, crashing the shell.
- **Why it matters:** `late final` without guaranteed assignment is a crash waiting for an error path. The `context.mounted` guard on line 176 only protects against a dismounted widget after a *successful* `showDialog` return — it does not protect against an exception path.
- **Evidence:** `lib/ui/app_shell.dart` lines 23–176
- **Suggested fix for Codex to validate:** Replace `late final OnyxRoute? selection` + `try/finally` with a `try/catch` pattern where `selection` is initialised to `null` before the `try` block. The `finally` logic (dispose queryNotifier) stays, but `selection` should be a plain nullable local.

---

### P1 — Bug: Side-effectful state mutation inside `build()`
- **Action:** REVIEW
- **Finding:** `_ShellIntelTickerState.build()` at lines 1355–1358 detects that `activeFilter != _sourceFilter`, then directly assigns `_sourceFilter = activeFilter` and calls `_syncAutoScrollState()`. `_syncAutoScrollState` cancels the current `Timer.periodic` and creates a new one. Flutter's contract forbids side-effectful mutations during `build` — if the framework calls `build` more than once before committing (which it is permitted to do), the timer will be cancelled and re-created multiple times per frame cycle, and the state assignment bypasses `setState`, so it is invisible to the framework.
- **Why it matters:** This is a latent ordering bug. Under the current widget tree depth it may not manifest visibly, but it will produce spurious timer churn on every rebuild triggered by parent widget updates (e.g., live incident count changes cause `AppShell.build` to rebuild `_ShellIntelTicker`).
- **Evidence:** `lib/ui/app_shell.dart` lines 1350–1358
- **Suggested fix for Codex to validate:** Move the filter-correction logic into `didUpdateWidget`. When `widget.items` changes, recompute the valid active filter and call `setState(() { _sourceFilter = correctedFilter; })`, then `_syncAutoScrollState()`.

---

### P2 — Structural: `OnyxIntelTickerItem` is a domain data class in a UI file
- **Action:** REVIEW
- **Finding:** `OnyxIntelTickerItem` (lines 181–197) has fields `id`, `eventId`, `sourceType`, `provider`, `headline`, `occurredAtUtc`. These are domain/application layer concepts (event identity, source classification, timestamps). Defining this class in `lib/ui/app_shell.dart` means application-layer callers must import a UI file to construct ticker items, violating the UI→domain import direction.
- **Why it matters:** When the intelligence pipeline evolves (new fields, normalization), the change touches both a domain concept and a UI shell file — two unrelated layers in one edit. It also makes the class invisible to non-UI tests without importing from the UI layer.
- **Evidence:** `lib/ui/app_shell.dart` lines 181–197
- **Suggested fix for Codex to validate:** Move `OnyxIntelTickerItem` to a domain or application layer file (e.g., `lib/domain/intelligence/onyx_intel_ticker_item.dart`). Import it in `app_shell.dart`.

---

### P2 — Structural: Re-export of domain route from UI file
- **Action:** REVIEW
- **Finding:** Line 9 — `export '../domain/authority/onyx_route.dart'` — means callers who import `app_shell.dart` get `OnyxRoute` and all its enums as a side-effect of importing a UI file. This creates an upward dependency: the domain is reachable through the UI layer.
- **Why it matters:** Any file that needs `OnyxRoute` but not the shell will import `app_shell.dart` for convenience, tightening coupling to the UI and making future extraction of either layer harder.
- **Evidence:** `lib/ui/app_shell.dart` line 9
- **Suggested fix for Codex to validate:** Remove the re-export. Callers should import `onyx_route.dart` directly from the domain. Codex should audit which callers currently rely on the re-export before removing.

---

### P2 — Bug suspicion: `_tickerColor` does not use `_normalizeSource`
- **Action:** AUTO
- **Finding:** `_tickerColor` (lines 1624–1648) calls `sourceType.trim().toLowerCase()` directly rather than delegating to `_normalizeSource`. The difference: `_normalizeSource` replaces an empty/whitespace-only source with `'system'`, while `_tickerColor` falls through to the default color for a blank source type.
- **Why it matters:** An item with `sourceType: ''` renders with color `0xFFA78BFA` (unknown/default) instead of `0xFF93C5FD` (system), while filter logic classifies it as `'system'`. Visual inconsistency between color and filter behavior.
- **Evidence:** `lib/ui/app_shell.dart` lines 1567–1569 vs 1624–1648
- **Suggested fix for Codex to validate:** Replace `sourceType.trim().toLowerCase()` on line 1625 with `_normalizeSource(sourceType)`.

---

### P3 — Duplication: Autopilot controls duplicated between desktop and mobile
- **Action:** REVIEW
- **Finding:** The stop/pause/skip autopilot control set appears in two completely separate widget implementations:
  - `_ShellTopBar` lines 535–623 (desktop path)
  - `_MobileAutopilotOverlay` lines 1161–1251 (mobile path)
  Both use the same icons (`stop_circle_outlined`, `pause_rounded`/`play_arrow_rounded`, `skip_next_rounded`) and the same colors (`0xFFFCA5A5`, `0xFFBFDBFE`, `0xFF93C5FD`). Logic for which controls render based on null callbacks is duplicated independently.
- **Why it matters:** Adding a fourth control, changing an icon, or recoloring requires touching both implementations. A bug introduced in one won't be caught if tests only exercise the other.
- **Evidence:** `lib/ui/app_shell.dart` lines 535–623 and 1161–1251
- **Suggested fix for Codex to validate:** Extract a shared `_AutopilotControlSet` widget that accepts stop/skip/pause callbacks and a `paused` flag. Both desktop and mobile compose it.

---

### P3 — Duplication: Identical lambda bodies for `meta+K` and `ctrl+K`
- **Action:** AUTO
- **Finding:** `_wrapShellShortcuts` (lines 252–268) registers two `SingleActivator` entries with identical lambda bodies, both calling `_showAppShellQuickJumpDialog(...)` with the same arguments.
- **Why it matters:** If the call signature changes, both lambdas need updating independently. Minor but avoidable.
- **Evidence:** `lib/ui/app_shell.dart` lines 253–265
- **Suggested fix for Codex to validate:** Extract a named `void _openQuickJump(BuildContext context)` helper and reference it from both activator bindings.

---

## Duplication

| Pattern | Lines | Centralization candidate |
|---|---|---|
| Autopilot stop/pause/skip controls | 535–623 and 1161–1251 | `_AutopilotControlSet` widget |
| `meta+K` / `ctrl+K` shortcut lambda bodies | 254–265 | Named local callback |
| `sourceType.trim().toLowerCase()` normalization | `_tickerColor` (1625) vs `_normalizeSource` (1567) | Always delegate to `_normalizeSource` |
| Hardcoded `Color(0xFF365E94)`, `Color(0xFFD7E1EC)`, `Color(0xFF142235)`, `Color(0xFFF7FAFE)` | File-wide (~30 occurrences) | Shell color palette constants |

---

## Coverage Gaps

1. **`LateInitializationError` path in `_showAppShellQuickJumpDialog`** — the exception-during-dialog path is untested. No test simulates `showDialog` throwing or the widget being disposed mid-dialog.
2. **Mobile autopilot overlay** — `_MobileAutopilotOverlay` is never instantiated in any test. Stop, pause, and skip callbacks are all untested on mobile layout.
3. **Sidebar toggle on desktop** — no test verifies that clicking the sidebar toggle actually collapses the sidebar (`_sidebarOpen` flips, `AnimatedContainer` width reaches 0, `_Sidebar` widget disappears). The landscape phone test (line 43) checks for the menu icon but does not exercise the desktop sidebar toggle.
4. **Operator chip hidden at narrow viewport** — no test verifies the chip is absent when `constraints.maxWidth < 1320` (or `< 1600` with autopilot active). The positive case (chip present at 2200px) is tested; the hidden case is not.
5. **Intel ticker auto-scroll timer lifecycle** — `_syncAutoScrollState`, `_autoScrollTick`, and the `_autoScrollTimer` cancel/restart cycle are entirely untested. Specifically: timer not started when `filteredItems.length <= 1`, timer reset after filter change, timer cancelled on dispose.
6. **Quick-jump — selecting current route does not fire `onRouteChanged`** — line 176 guards `selection != currentRoute` but no test covers this case.
7. **Intel ticker hidden when `showsShellIntelTicker == false`** — no test verifies the ticker strip is absent when the current route opts out, even if `intelTickerItems` is non-empty. `app_shell.dart` line 410 gates this.

---

## Performance / Stability Notes

1. **`_sourceCounts()` and `_availableFilters()` recomputed on every build** (lines 1350–1351): Both allocate new maps and lists on every paint. Since `AppShell.build` fires on every live badge count change, the ticker state will rebuild frequently. Both results depend only on `widget.items` and should be cached in `didUpdateWidget`.

2. **`_filteredItems()` called twice per some code paths** — called inside `_syncAutoScrollState` at line 1310 and again explicitly at line 1359 in `build`. The result should be reused.

3. **`_Sidebar.build` allocates a full `navSections` model on every rebuild** (lines 761–768): `OnyxRouteSection.values.map(...).toList()` runs on every rebuild. Since `AppShell` propagates badge counts through props, `_Sidebar` rebuilds whenever any count changes. The nav section structure is derived from constants and could be a `const` list or a `late final` on the sidebar widget.

4. **`_ShellTopBar` nests a `LayoutBuilder` inside the shell's outer `LayoutBuilder`** (line 473): Extra layout pass on every resize event. The threshold logic for `showOperatorChip` / autopilot widths could be derived from the outer constraints if the top bar width were passed in. Low priority unless resize jank is measured.

---

## Recommended Fix Order

1. **(P1 — Bug)** Replace `late final OnyxRoute? selection` with a nullable local init to eliminate the `LateInitializationError` crash path. — **AUTO**
2. **(P1 — Bug)** Move `_sourceFilter` correction and `_syncAutoScrollState()` out of `build()` into `didUpdateWidget`. — **REVIEW** (subtle behavioral change in ticker timing)
3. **(P2 — Bug suspicion)** Make `_tickerColor` delegate to `_normalizeSource`. — **AUTO**
4. **(Coverage)** Add tests for: mobile autopilot overlay callbacks, desktop sidebar toggle collapse, operator chip hidden state, ticker hidden per route, quick-jump selecting current route. — **AUTO**
5. **(Coverage)** Add timer lifecycle tests for `_ShellIntelTicker`. — **AUTO**
6. **(P2 — Structural)** Move `OnyxIntelTickerItem` to a domain/application layer file; audit and remove `onyx_route.dart` re-export. — **REVIEW** (import chain audit needed)
7. **(Performance)** Cache `_sourceCounts()` and `_availableFilters()` in `didUpdateWidget`. — **AUTO**
8. **(Duplication)** Extract `_AutopilotControlSet` shared widget from desktop and mobile implementations. — **REVIEW** (ensure visual parity)
9. **(Duplication)** Extract named `_openQuickJump` callback in `_wrapShellShortcuts`. — **AUTO**
- Read-only: yes

---

## Executive Summary

`app_shell.dart` is 1,649 lines and structurally coherent. The widget decomposition
is reasonable: a thin `AppShell` coordinator, a `_Sidebar`, a `_ShellTopBar`, and an
independent `_ShellIntelTicker`. Test coverage is above average for a shell file.

The primary risks are a real `LateInitializationError` bug in the quick-jump dialog
function, a side-effect inside a `build` method in `_ShellIntelTickerState`, and a fat
constructor on `AppShell` (18 params) that is growing toward coordinator territory.
Duplication of the autopilot control block across desktop and mobile surfaces is also
a maintenance risk.

---

## What Looks Good

- `_ShellIntelTicker` lifecycle is tidy: timer is cancelled in `dispose`, `didUpdateWidget`
  restarts the auto-scroll correctly when items change.
- `_userInteracting` guard on `_autoScrollTick` correctly prevents fighting user scrolls.
- `_Sidebar._badgeForRoute` uses an exhaustive `switch` on `OnyxRouteShellBadgeKind` —
  compile-time safety for new badge kinds.
- `_TopBarActionIcon` correctly uses `Stack(clipBehavior: Clip.none)` so the alert dot
  overflows without clipping artifacts.
- Test suite covers mobile drawer, desktop chrome, badge rendering, ticker filtering,
  quick-jump keyboard shortcuts (Meta+K and Ctrl+K), and the status snack bar.

---

## Findings

### P1 — `LateInitializationError` in `_showAppShellQuickJumpDialog`

- **Action:** AUTO
- **Finding:** `late final OnyxRoute? selection` (line 23) is declared inside a
  `try/finally` block but is only assigned by the `await showDialog(...)` return at
  line 25. If `showDialog` throws before it returns (e.g., context is deactivated
  mid-flight, or an internal assertion fires), the `finally` block schedules the
  `queryNotifier.dispose()` call as expected, but execution then falls through to
  line 176 where `selection` is read while still uninitialized — throwing
  `LateInitializationError` at runtime.
- **Why it matters:** The quick-jump dialog is on the keyboard shortcut hot path.
  Any Flutter assertion or context error inside the dialog would surface as an
  `LateInitializationError` instead of the real error, masking the root cause.
- **Evidence:** `lib/ui/app_shell.dart` lines 23–178
- **Suggested follow-up:** Codex should verify whether replacing `late final` with a
  nullable `OnyxRoute? selection;` (initialized to `null`) removes the risk without
  changing observable behaviour. The `if (selection != null)` guard at line 176 already
  handles the null case correctly.

---

### P1 — Side-effect inside `build` in `_ShellIntelTickerState`

- **Action:** REVIEW
- **Finding:** `_ShellIntelTickerState.build` (lines 1355–1358) checks whether
  `_sourceFilter` is stale and, if so, reassigns `_sourceFilter` and calls
  `_syncAutoScrollState()`. `_syncAutoScrollState` cancels and restarts a `Timer.periodic`.
  Mutating state and cancelling/starting timers inside `build` is a Flutter anti-pattern:
  `build` can be called repeatedly for reasons unrelated to item changes, causing timers
  to be silently restarted on every rebuild.
- **Why it matters:** On high-frequency rebuild paths (parent widget rebuilding on every
  incident update), the auto-scroll timer would be cancelled and restarted on every frame
  tick, resetting the 4-second interval each time and effectively never firing.
- **Evidence:** `lib/ui/app_shell.dart` lines 1349–1358
- **Suggested follow-up:** Codex should move the stale-filter correction into
  `didUpdateWidget` (alongside the existing item-length check) so timer restarts
  only happen on genuine state transitions, not on every build.

---

### P2 — `_userInteracting` can be permanently stuck `true`

- **Action:** AUTO
- **Finding:** `_userInteracting` is set to `false` only when a `UserScrollNotification`
  with `direction == ScrollDirection.idle` fires (line 1418). If the user drags a few
  pixels but the scroll does not settle naturally (e.g., a quick tap that never generates
  an idle notification), `_userInteracting` stays `true` indefinitely and permanently
  suppresses auto-scroll for the lifetime of the widget.
- **Why it matters:** In practice a quick swipe on the ticker strip that doesn't reach
  deceleration phase may never generate an `idle` direction event. The ticker goes
  silent from that point forward.
- **Evidence:** `lib/ui/app_shell.dart` lines 1415–1422
- **Suggested follow-up:** Codex should evaluate adding a `Timer` that resets
  `_userInteracting` to `false` after a short idle window (e.g., 2–3 seconds) as a
  fallback, or switch to listening for `ScrollEndNotification` which fires more reliably.

---

### P2 — Duplicate keyboard-shortcut closures in `_wrapShellShortcuts`

- **Action:** AUTO
- **Finding:** Lines 254–265 register Meta+K and Ctrl+K with identical inline lambdas.
  The two closures are byte-for-byte duplicates.
- **Why it matters:** If the quick-jump call signature changes, both bindings must be
  updated independently. One will be missed.
- **Evidence:** `lib/ui/app_shell.dart` lines 252–268
- **Suggested follow-up:** Extract a single `void _openQuickJump()` method and
  reference it from both bindings.

---

### P2 — Fat constructor on `AppShell` (18 parameters)

- **Action:** DECISION
- **Finding:** `AppShell` accepts 18 constructor parameters, including five demo-autopilot
  fields (`demoAutopilotStatusLabel`, `onStopDemoAutopilot`, `onSkipDemoAutopilot`,
  `onToggleDemoAutopilotPause`, `demoAutopilotPaused`) and three operator-session fields.
  These concerns are unrelated to shell layout.
- **Why it matters:** Every new cross-cutting feature (e.g., a maintenance-mode banner)
  will add more parameters here. The shell becomes a coordinator and its callers must
  be updated across the board.
- **Evidence:** `lib/ui/app_shell.dart` lines 199–243
- **Suggested follow-up:** Zaks to decide whether autopilot state should be lifted into
  an inherited widget / provider so `AppShell` can read it directly rather than
  threading callbacks down from the caller.

---

### P3 — `_navItem` uses `GestureDetector` instead of `InkWell`

- **Action:** AUTO
- **Finding:** `_Sidebar._navItem` (line 863) wraps the nav item in `GestureDetector`.
  Every other interactive element in this file (quick-jump dialog rows line 112, mobile
  action icons line 1241) uses `InkWell`. `GestureDetector` produces no ink ripple,
  making the sidebar the only area without touch feedback.
- **Why it matters:** Inconsistency in tactile feedback. Minor UX regression vs. the
  rest of the shell.
- **Evidence:** `lib/ui/app_shell.dart` lines 863–926
- **Suggested follow-up:** Codex can replace `GestureDetector` with `InkWell` and add
  `borderRadius: BorderRadius.circular(10)` to match the `Container` decoration.

---

### P3 — Magic number `50` for mobile autopilot overlay left-pad

- **Action:** REVIEW
- **Finding:** The mobile autopilot overlay is positioned with
  `EdgeInsets.fromLTRB(50, 4, 8, 0)` (line 312) to avoid the hamburger menu icon.
  The `50` is derived from the hamburger icon's touch target width but is not referenced
  from a shared constant.
- **Why it matters:** If the hamburger button size or left padding changes, the overlay
  will overlap it. On very narrow viewports (< 360 px) the 50 px offset eats into
  the available label width.
- **Evidence:** `lib/ui/app_shell.dart` lines 310–321
- **Suggested follow-up:** Codex to verify whether a `Row` with an explicit spacer or
  `Positioned` using the actual button width is feasible here, or at minimum extract
  `50.0` as a named constant.

---

## Duplication

### 1. Autopilot control block — desktop vs mobile

- **Files:** `_ShellTopBar` (lines 535–624), `_MobileAutopilotOverlay` (lines 1161–1251)
- **Pattern:** Stop / pause / skip controls appear in both branches with separate
  rendering logic (compact icon vs labelled button in desktop; icon-only in mobile).
  The show/hide conditions for each control are duplicated.
- **Centralization candidate:** A shared `_AutopilotControlSet` widget taking the three
  callbacks and a `compact: bool` flag could replace both branches.

### 2. Meta+K / Ctrl+K closures

- **Files:** `_AppShellState._wrapShellShortcuts` (lines 254–265)
- **Pattern:** Identical inline lambda registered twice. See P2 finding above.

### 3. Active/inactive pill decoration

- **Files:** `_Sidebar._navItem` (lines 868–873), `_ShellIntelTickerState._sourceFilterChip`
  (lines 1599–1608), quick-jump dialog item (lines 122–131)
- **Pattern:** Three separate `BoxDecoration` blocks for an active/inactive pill with
  color-and-border toggle. All differ slightly in radius and color but share the same
  structural logic.
- **Note:** These are distinct enough in context that a shared helper would require
  parameters for radius, active color, and inactive color — marginal gain. Flag as
  awareness only; not a strong centralization candidate unless a theme sweep is planned.

---

## Coverage Gaps

1. **Sidebar toggle**: No test for the desktop-layout toggle button opening/closing the
   sidebar. `_sidebarOpen` state is untested.

2. **Demo autopilot controls**: No test for any of the five autopilot params
   (`demoAutopilotStatusLabel`, `onStop*`, `onSkip*`, `onTogglePause*`,
   `demoAutopilotPaused`). The stop/pause/skip button rendering is completely uncovered.

3. **Mobile autopilot overlay** (`_MobileAutopilotOverlay`): No test at any viewport.

4. **Operator chip fallback**: `_OperatorSessionChip` shows `'OPERATOR'` when
   `roleLabel` and `shiftLabel` are both empty. This fallback branch is untested.

5. **`showsShellIntelTicker = false`**: No test that the ticker is hidden when the
   current route opts out. The `currentRoute.showsShellIntelTicker` guard (line 410) is
   untested.

6. **Source filter reset on item list change**: If `_sourceFilter` is set to `'radio'`
   and the items list is replaced with a list containing only `'news'` items, the filter
   should fall back to `'all'`. The build-time correction at lines 1352–1358 handles
   this, but no test exercises it.

7. **Empty headline / empty provider / empty sourceType normalization** in ticker items:
   `_normalizeSource` maps empty strings to `'system'`; `build` maps empty `sourceType`
   to `'intel'` and empty `provider` to `'feed'`. These fallback paths are untested.

8. **`_userInteracting` suppression**: No test that a mid-scroll interaction pauses
   auto-scroll and that it eventually resumes.

9. **Alert dot on status button**: No test that `showAlertDot` is set when
   `activeIncidentCount > 0 || aiActionCount > 0` (it is implied by the badge rendering
   test but not directly asserted on `_TopBarActionIcon`).

---

## Performance / Stability Notes

1. **`_sourceCounts()` and `_availableFilters()` recomputed on every build**
   (lines 1350–1351). These iterate the full items list each time. For tickers with
   large item counts (100+) this will become measurable. Both can be memoized in
   `didUpdateWidget` and stored in fields.

2. **Two nested `LayoutBuilder` calls**: `AppShell.build` uses `LayoutBuilder` (line 273)
   and `_ShellTopBar.build` also uses `LayoutBuilder` (line 473). Flutter resolves these
   in separate layout passes. This is acceptable but means the top bar triggers a full
   child layout pass on any resize event even when only the top bar breakpoint logic
   needs to change. Consider whether the inner `LayoutBuilder` can be replaced with
   `MediaQuery.sizeOf(context)` or a simple width read.

3. **`GoogleFonts.*()` calls in every build path**: All text styles are constructed
   with `GoogleFonts.inter(...)` and `GoogleFonts.rajdhani(...)` inline in `build`.
   Google Fonts caches the font itself but still allocates a new `TextStyle` object each
   call. This is minor but widespread (30+ call sites in this file). A set of
   file-level `const`-style or `static final` style constants would eliminate the
   allocation and make it easier to enforce theme consistency.

---

## Recommended Fix Order

1. **(P1) Fix `LateInitializationError` in quick-jump dialog** — `late final` → nullable
   `OnyxRoute? selection;`. Zero behaviour change, eliminates unhandled error path.

2. **(P1) Move stale-filter correction out of `build`** into `didUpdateWidget` in
   `_ShellIntelTickerState` — prevents silent timer thrash on every parent rebuild.

3. **(P2) Fix `_userInteracting` stuck-true** — add a reset timer or switch to
   `ScrollEndNotification`.

4. **(P2) Deduplicate Meta+K / Ctrl+K closures** — extract `_openQuickJump` method.

5. **(P3) Replace `GestureDetector` with `InkWell` in `_navItem`** — consistent touch
   feedback, one-line change.

6. **(Coverage) Add tests for**: sidebar toggle, autopilot controls, mobile autopilot
   overlay, operator chip fallback, `showsShellIntelTicker = false`, source filter
   reset on items change.

7. **(Performance) Memoize `_sourceCounts` / `_availableFilters`** in `didUpdateWidget`.

8. **(DECISION) AppShell constructor width** — Zaks to decide on inherited-widget
   refactor before the param list grows further.
