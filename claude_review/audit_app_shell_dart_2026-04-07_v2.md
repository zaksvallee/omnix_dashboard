# Audit: app_shell.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/ui/app_shell.dart` — AppShell, _ShellTopBar, _Sidebar, _ShellIntelTicker, helper widgets
- Read-only: yes

---

## Executive Summary

`app_shell.dart` is structurally sound for a navigation shell: responsibilities are layered
cleanly across `AppShell` (layout router), `_Sidebar` (nav), `_ShellTopBar` (chrome), and
`_ShellIntelTicker` (live feed). The existing widget-test suite is above-average for a shell
component, covering breakpoints, badge rendering, ticker filtering, quick-jump, and keyboard
shortcuts.

Two concrete bugs exist: a `ValueNotifier` use-after-dispose risk in the quick-jump dialog,
and a list identity comparison in `didUpdateWidget` that fires on every parent rebuild,
resetting the ticker scroll position and restarting the auto-scroll timer. Several design-token
bypasses and test gaps round out the findings.

---

## What Looks Good

- `_Sidebar._badgeForRoute` cleanly delegates to an `OnyxRoute`-owned `shellBadgeKind` enum —
  zero per-route if-chains in the shell.
- `_ShellIntelTicker` lifecycle is well disciplined: `initState` / `didUpdateWidget` / `dispose`
  all cancel timers correctly, `mounted` is checked before scroll commands.
- `_autoScrollTick` guards against hover, user-interaction, and no-clients before scrolling —
  avoids the common pattern of scrolling into a disposed controller.
- `_reconcileSourceFilter` returns a boolean change-flag and only resets scroll on actual
  filter invalidation. Good defensive design.
- Quick-jump dialog uses `context.mounted` before calling `onRouteChanged` post-`await` — a
  pattern many widgets miss.
- Test suite covers: mobile drawer, landscape phone, desktop badges, operator chip, ticker
  entries, ticker filter tap, DVR vs hardware discrimination, ticker tap callback, quick-jump
  dialog, keyboard shortcuts (Meta+K, Control+K), and timer-stability on parent rebuild.

---

## Findings

### P1 — Bug: `queryNotifier` use-after-dispose risk

- **Action:** AUTO
- **Finding:** In `_showAppShellQuickJumpDialog` (line 175–178), `queryNotifier.dispose()` is
  deferred via `addPostFrameCallback` inside the `finally` block. The dialog's
  `ValueListenableBuilder` holds a listener on this notifier. If Flutter flushes the post-frame
  callback while a rebuild of the dialog is still pending (e.g., if the caller's widget tree
  is still active at close), the notifier is disposed while a listener exists. The `ValueNotifier`
  debug mode will throw "A ValueNotifier<String> was used after being disposed."
- **Why it matters:** The deferred disposal pattern is unnecessary. The notifier is local to the
  function, the dialog is removed from the tree on `pop`, and `ValueNotifier` does not need a
  post-frame callback — it can be disposed synchronously in `finally`.
- **Evidence:** `lib/ui/app_shell.dart` lines 175–178.
- **Suggested follow-up for Codex:** Replace the `addPostFrameCallback` wrapper with a direct
  `queryNotifier.dispose()` call inside the `finally` block.

---

### P1 — Bug: `didUpdateWidget` list reference comparison always triggers scroll reset

- **Action:** AUTO
- **Finding:** `_ShellIntelTickerState.didUpdateWidget` (lines 1301–1303) checks:
  ```
  oldWidget.items.length != widget.items.length ||
  oldWidget.items != widget.items
  ```
  `List` equality in Dart uses identity (`identical`) by default, not element equality.
  Callers that pass `const []` will compare equal, but any caller that builds a new list
  on every parent rebuild (e.g., `intelTickerItems: someState.items`) will always produce
  `oldWidget.items != widget.items == true`, so `filterChanged` and `itemsChanged` are both
  `true` on every rebuild even when the items are logically identical. This calls
  `_syncAutoScrollState()` which cancels and restarts the `Timer.periodic`, resetting
  scroll timing on every state update anywhere in the tree.
- **Why it matters:** The `AppShell.build` passes `widget.intelTickerItems` directly. Any
  parent `setState` call (e.g., badge count changes, operator label changes) will rebuild
  `AppShell` and trigger this comparison. In production, where badge counts update
  frequently, the ticker auto-scroll is perpetually reset and never fires.
- **Evidence:** `lib/ui/app_shell.dart` lines 1301–1303.
  The regression test at `test/ui/app_shell_widget_test.dart` lines 545–601 passes
  because it only triggers one parent rebuild between scroll checks, not a stream of them.
- **Suggested follow-up for Codex:** Guard the timer-restart path behind a list element
  comparison (e.g., using `listEquals` from `flutter/foundation.dart`) rather than a
  reference check. The length check alone is sufficient as a fast-path guard; true item
  change detection requires element equality.

---

### P2 — Design token bypass: hard-coded `Color(0xFFF5F7FB)` background

- **Action:** AUTO
- **Finding:** The Scaffold background color `const Color(0xFFF5F7FB)` is hard-coded in
  three separate locations: mobile Scaffold `backgroundColor` (line 285), mobile body
  `Container.color` (line 308), and desktop Scaffold `backgroundColor` / inner `Container`
  (lines 363, 387). `OnyxDesignTokens` is imported and used for most other surface colors,
  but this token is missing.
- **Why it matters:** A theme or brand palette update would require finding all four literal
  sites rather than updating one token.
- **Evidence:** `lib/ui/app_shell.dart` lines 285, 308, 363, 387.
- **Suggested follow-up for Codex:** Add a `backgroundPrimary` or `pageBackground` token to
  `OnyxDesignTokens` and replace all four literals.

---

### P2 — `Color.lerp` implicit null suppression in `_sourceFilterChip`

- **Action:** REVIEW
- **Finding:** `_sourceFilterChip` (line 1656) uses `Color.lerp(...)` as a `Color` value for
  `TextStyle.color`. The Flutter SDK declares `Color.lerp` as returning `Color?`. With two
  non-null inputs the return is never actually null, but the implicit cast suppresses the type
  system. If strict null-safety analysis is tightened or the SDK signature changes, this
  silently becomes a runtime null.
- **Why it matters:** Low risk in practice but introduces an imprecise null suppression. A
  linter set to `implicit-casts: false` would flag this.
- **Evidence:** `lib/ui/app_shell.dart` line 1656.
- **Suggested follow-up for Codex:** Replace with `Color.lerp(...) ?? _appShellBodyColor` to
  make the fallback explicit.

---

### P2 — Mobile layout silently drops the intel ticker

- **Action:** DECISION
- **Finding:** The desktop layout conditionally renders `_ShellIntelTicker` when
  `intelTickerItems.isNotEmpty && currentRoute.showsShellIntelTicker` (lines 413–418). The
  mobile Scaffold body contains no equivalent branch — the ticker is silently absent on
  handset/narrow layouts regardless of content.
- **Why it matters:** If the intel ticker carries time-sensitive operational data (hardware
  alerts, radio feeds), operators on mobile never see it. This could be intentional for
  screen-real-estate reasons or an oversight.
- **Evidence:** `lib/ui/app_shell.dart` lines 281–356 (mobile path) vs 413–418 (desktop only).
- **Suggested follow-up for Codex:** Confirm with Zaks whether mobile should receive a
  compact ticker strip or if omission is deliberate. If deliberate, add a comment; if not,
  add a conditional ticker row to the mobile `Stack` body.

---

### P3 — `_sourceFilterOrder` 'all' entry is dead code

- **Action:** AUTO
- **Finding:** `_sourceFilterOrder` starts with `'all'` (line 1274), but `_availableFilters`
  immediately skips it with `if (source == 'all') continue;` (line 1588) and prepends 'all'
  manually (line 1586). The 'all' entry in the constant list is never reached.
- **Why it matters:** Minor confusion for future maintainers — it looks like 'all' is part of
  the ordered set but is actually bypassed.
- **Evidence:** `lib/ui/app_shell.dart` lines 1273–1282 vs 1585–1594.
- **Suggested follow-up for Codex:** Remove 'all' from `_sourceFilterOrder`.

---

### P3 — `CallbackShortcuts` bindings map rebuilt on every `build`

- **Action:** REVIEW
- **Finding:** `_wrapShellShortcuts` (lines 252–273) is called inside `_AppShellState.build`,
  creating a new `Map<ShortcutActivator, VoidCallback>` with new closures on every rebuild.
  `CallbackShortcuts` compares bindings by identity. This means every parent rebuild
  causes `CallbackShortcuts` to re-register all shortcut handlers, creating GC pressure
  proportional to rebuild frequency.
- **Why it matters:** Moderate. In an ops dashboard where badges update frequently, rebuilds
  are continuous. Not a visible performance issue today, but grows worse with rebuild frequency.
- **Evidence:** `lib/ui/app_shell.dart` lines 252–273, called from lines 282 and 360.
- **Suggested follow-up for Codex:** Consider making `_wrapShellShortcuts` return a fixed
  widget subtree (e.g., extracted as a private `StatelessWidget` that takes `onQuickJump` as
  a callback) so the `CallbackShortcuts` widget instance is stable across builds.

---

## Duplication

### Autopilot control icons: `_ShellTopBar` (desktop) vs `_MobileAutopilotOverlay` (mobile)

- **Files:** `lib/ui/app_shell.dart` lines 539–626 (desktop) and 1165–1254 (mobile).
- Both implement Stop / Pause / Resume / Skip autopilot actions with the same icon mapping
  and the same three color constants (`0xFFFCA5A5`, `0xFFBFDBFE`, `0xFF93C5FD`).
- The only difference is icon size (16px mobile, 16px desktop via `_TopBarActionIcon`) and
  the wrapper widget (`InkWell` in mobile vs `OutlinedButton` / `_TopBarActionIcon` in
  desktop).
- **Centralization candidate:** Extract an `_AutopilotActionSet` widget accepting
  `onStop/onSkip/onTogglePause/paused` and a `compact: bool` flag, shared by both layouts.

### `_navItem` hard-coded active/inactive color pairs bypassing `OnyxDesignTokens`

- **Files:** `lib/ui/app_shell.dart` lines 874–929.
- Active background `0xFFE8F1FF`, active border `0xFF9EC1E8`, active icon `0xFF365E94`,
  active text `0xFF142235` — all hard-coded. The same blue-grey palette appears in other
  places in the file (`0xFF365E94` in the menu button icon, line 345).
- **Centralization candidate:** These belong in `OnyxDesignTokens` as nav-state tokens.

---

## Coverage Gaps

| Gap | Risk |
|-----|------|
| Sidebar toggle (`_sidebarOpen`) — no test verifies the sidebar collapses and re-expands when the top-bar toggle button is tapped | Medium — state machine is trivial but unverified |
| `intelTickerItems` on a route where `showsShellIntelTicker == false` — no test confirms the ticker is hidden | Medium — route config is easy to misconfigure |
| Mobile autopilot overlay — `_MobileAutopilotOverlay` is never exercised in tests | Medium — autopilot controls have independent behavior on mobile |
| Desktop autopilot Stop/Pause/Skip controls (narrow and wide variants) — zero coverage in test suite | Medium — three distinct responsive breakpoints, none tested |
| `_OperatorSessionChip` with `operatorLabel` only (no role, no shift) — fallback 'OPERATOR' label path not covered | Low |
| Quick-jump dialog "Current" badge rendered for active route — not tested | Low |
| Empty ticker empty-state text ("No … intelligence in ticker window") — not covered | Low |
| `onIntelTickerTap == null` with items present — `InkWell.onTap` should be null, item should render non-interactive | Low |
| `_sourceFilterChip` tap that does nothing when already selected (`_sourceFilter == source` guard, line 1629) | Low |

---

## Performance / Stability Notes

### `_sourceCounts()` called twice per ticker build

- `_ShellIntelTickerState.build` (lines 1395–1396) calls `_sourceCounts()` twice:
  once to get the map and once to pass into `_availableFilters`. Both calls iterate
  the full `widget.items` list. With large item lists (e.g., 500+ ticker entries),
  this doubles iteration work on every rebuild.
- **Suggested follow-up:** Compute `sourceCounts` once, pass the result to both
  `_availableFilters` and `_filteredItems`.

### Auto-scroll timer not guarded against concurrent animation in-flight

- `Timer.periodic` fires every 4 seconds. Each tick launches `_autoScrollController.animateTo`
  which takes up to 420ms. The next tick won't overlap (4s > 420ms), but if the device is
  slow and a frame budget overrun delays the animation, a second tick could start a new
  `animateTo` while the previous one is still running, causing a controller assertion.
- **Risk:** Low in practice but not defensively guarded.
- **Suggested follow-up:** Add an `_animating` flag set to `true` before `animateTo` and
  cleared in a `finally` block after it completes; skip the tick if `_animating == true`.

---

## Recommended Fix Order

1. **(P1 AUTO)** Fix `queryNotifier.dispose()` — replace deferred `addPostFrameCallback`
   with direct synchronous disposal in the `finally` block. Zero-risk change, clear bug.

2. **(P1 AUTO)** Fix `didUpdateWidget` list comparison — use `listEquals` from
   `flutter/foundation.dart` instead of reference equality to prevent continuous timer
   resets. High operational impact; the existing regression test will continue to pass.

3. **(AUTO)** Remove `'all'` from `_sourceFilterOrder` static constant. Zero-risk cleanup.

4. **(AUTO)** Add `OnyxDesignTokens.pageBackground` and replace 4 literal `Color(0xFFF5F7FB)`
   sites. Pure token alignment; no behavioral change.

5. **(AUTO)** Explicit null fallback for `Color.lerp` in `_sourceFilterChip`.

6. **(REVIEW)** Extract `_AutopilotActionSet` to eliminate desktop/mobile autopilot
   control duplication — low risk but touches both layout branches.

7. **(REVIEW)** Address `CallbackShortcuts` rebuild churn — minor optimization, acceptable
   to defer.

8. **(DECISION)** Confirm mobile intel ticker omission is intentional, document or implement
   accordingly.

9. **(Coverage)** Add tests for: sidebar toggle, ticker hidden on `showsShellIntelTicker == false`
   routes, mobile autopilot overlay rendering, desktop autopilot controls, empty ticker
   empty-state message.
