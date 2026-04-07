# Audit: app_shell.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/ui/app_shell.dart`, `test/ui/app_shell_widget_test.dart`
- Read-only: yes

---

## Executive Summary

`app_shell.dart` is well-structured for a shell component — layout logic is cleanly separated into private classes, styling is consistently token-driven, and the test file has solid coverage of desktop/mobile layout switching, badge rendering, intel ticker filtering, quick-jump, and the status snack. Two confirmed bugs stand out: a sidebar-to-drawer width mismatch on narrow phones that causes overflow clipping, and a `setState`-missing mutation in `_reconcileSourceFilter` that leaves the ticker's filter chip UI stale after upstream items change. Both are undetected by current tests. There is also a structural concern: `OnyxIntelTickerItem` is a domain-adjacent data model living inside a UI file, forcing callers to import a UI module to build that type.

---

## What Looks Good

- Private classes (`_Sidebar`, `_ShellTopBar`, `_ShellIntelTicker`, `_MobileAutopilotOverlay`) are tightly scoped — no domain logic bleeds into them.
- Token-only styling throughout; no hardcoded raw color literals except the fallback badge color at lines 928 and 933 (minor).
- `_ShellIntelTickerState` handles timer lifecycle, hover guard, and user-interaction reset correctly in `dispose()` and `didUpdateWidget`.
- `_showAppShellQuickJumpDialog` properly disposes `queryNotifier` in a `finally` block and checks `context.mounted` before calling `onRouteChanged`.
- `_Sidebar._badgeForRoute` suppresses zero-count badges cleanly via the switch pattern.
- Test file covers: mobile drawer nav, landscape phone layout, desktop chrome, badge rendering at two viewport widths, operator chip, ticker rendering, DVR/news/hardware filter taps, tap callback, quick-jump at two viewport widths, and status snack.

---

## Findings

### P1 — Sidebar content overflows drawer on narrow phones

- **Action: AUTO**
- The `Drawer` width is set to `constraints.maxWidth * 0.84` when `constraints.maxWidth < 420` (line 301), but `_Sidebar` inside it always receives `width: 320` (line 305). On a 360 dp screen the drawer is ~302 dp but the sidebar insists on being 320 dp — the `Container(width: width)` in `_Sidebar.build` will overflow and clip.
- **Why it matters:** Silent visual corruption on every phone narrower than 380 dp. The `Container` does not use `ConstrainedBox` so it will assert or render outside the drawer boundary.
- **Evidence:** `app_shell.dart:301-305`
  ```dart
  width: constraints.maxWidth < 420
      ? constraints.maxWidth * 0.84
      : 320,                          // drawer width
  child: _Sidebar(
    width: 320,                       // sidebar always 320 — mismatch
  ```
- **Suggested follow-up:** Codex should validate by running the mobile drawer test at a 360×800 viewport and confirming no overflow assertion fires.

### P1 — `_reconcileSourceFilter` mutates `_sourceFilter` without `setState`

- **Action: AUTO**
- `_reconcileSourceFilter()` (line 1339) is called from `didUpdateWidget` (line 1325). When the active filter becomes invalid (e.g. all `'news'` items disappear), it reassigns `_sourceFilter` directly (line 1344) without calling `setState()`. The `_sourceFilter` used by the filter-chip `selected` check in `build()` will be stale until the next unrelated rebuild.
- **Why it matters:** After items update causes a filter to vanish, the previously selected chip can remain highlighted while a different filter is actually active. The auto-scroll timer will restart for the new filter but the filter chips will not re-render.
- **Evidence:** `app_shell.dart:1325-1348`
  ```dart
  bool _reconcileSourceFilter() {
    final activeFilter = _resolvedActiveFilter();
    if (activeFilter == _sourceFilter) return false;
    _sourceFilter = activeFilter;     // ← no setState
    ...
    return true;
  }
  ```
- **Suggested follow-up:** Codex should add a `setState(() { _sourceFilter = activeFilter; })` guard and add a widget test that removes all items of the currently selected source type and confirms the filter chip reverts to ALL.

### P2 — `OnyxIntelTickerItem` model defined inside a UI file

- **Action: DECISION**
- `OnyxIntelTickerItem` (lines 198-213) is a pure data carrier with `id`, `eventId`, `sourceType`, `provider`, `headline`, and `occurredAtUtc`. It belongs in the domain or application layer. Any service, repository, or coordinator that produces ticker items must currently import `lib/ui/app_shell.dart` — a UI file — to reference this type.
- **Why it matters:** Layer inversion. Domain/application code depending on a UI file is architecture drift that compounds as more callers are added.
- **Evidence:** `app_shell.dart:198-213`
- **Suggested follow-up:** Zaks should decide whether this type moves to `lib/domain/intel/` or `lib/application/`. Codex should then update all import sites. This is a DECISION because it may also affect how the ticker is populated from services.

### P2 — `_sourceCounts()` called twice per build in `_ShellIntelTickerState`

- **Action: AUTO**
- `build()` (line 1415) calls `_sourceCounts()` on line 1416 to build `sourceCounts`, then calls `_resolvedActiveFilter()` on line 1418, which internally calls `_availableFilters(_sourceCounts())` (line 1352) — a second full iteration over `widget.items`. Both calls happen before any rendering.
- **Why it matters:** Redundant O(n) work per build. Harmless at 10 items; visible overhead at 200+ items in a high-refresh context.
- **Evidence:** `app_shell.dart:1416-1419` and `app_shell.dart:1351-1352`
- **Suggested follow-up:** Codex should pass `sourceCounts` into `_resolvedActiveFilter` so the list is iterated once.

### P2 — Hardcoded `'READY'` system status label

- **Action: REVIEW**
- The system status chip in `_ShellTopBar` always renders `'READY'` (line 657) regardless of actual platform health (Supabase connectivity, agent reachability, auth state). If the backend is degraded the chip will still show green `READY`.
- **Why it matters:** Operators rely on this indicator. A static label provides false confidence.
- **Evidence:** `app_shell.dart:656-661`
  ```dart
  _TopChip(
    label: 'READY',
    foreground: OnyxDesignTokens.greenNominal,
    ...
  )
  ```
- **Suggested follow-up:** Zaks should decide whether to wire a system health state into `AppShell`. If yes, Codex adds a `systemStatusLabel`/`systemStatusColor` prop; if this is intentionally a demo placeholder, document it.

### P3 — `_navItem` uses `GestureDetector` instead of `InkWell`

- **Action: AUTO**
- The sidebar nav items use `GestureDetector` (line 886), which gives no ink splash on tap. The quick-jump dialog list rows use `InkWell` (line 131). Users on desktop have no visual tap feedback when clicking a nav item.
- **Why it matters:** Inconsistent interaction affordance; on desktop this is a noticeable UX gap against the dialog which does ripple.
- **Evidence:** `app_shell.dart:886-950`
- **Suggested follow-up:** Replace `GestureDetector` with `InkWell` in `_navItem` and add `borderRadius` to match the existing decoration.

### P3 — Duplicate Cmd+K and Ctrl+K shortcut lambdas

- **Action: AUTO**
- Two separate lambda callbacks are registered for `meta+K` and `control+K` (lines 272-282) with identical bodies. While cross-platform support requires both activators, the lambda is duplicated rather than referenced.
- **Why it matters:** Minor duplication risk — a future change to the callback body must be applied twice.
- **Evidence:** `app_shell.dart:271-282`
- **Suggested follow-up:** Extract the common callback to a named method on `_AppShellState` and reference it from both bindings.

---

## Duplication

### Autopilot stop/pause/skip control pattern — 3× implementations

- `_ShellTopBar` extended desktop (lines 563-645): `OutlinedButton` rows for Stop, Pause/Resume, Next.
- `_ShellTopBar` compact desktop (same block, icon variants via `_TopBarActionIcon`): conditional branch within the same builder.
- `_MobileAutopilotOverlay` (lines 1235-1253): inline icon row with `_mobileActionIcon`.

All three encode the same semantic (stop/pause/skip) with different widget trees. The ordering logic (`if (showCompactAutopilotControls && onStop != null)`) is spread across ~80 lines of the same builder and can drift.

**Centralization candidate:** An `_AutopilotControls` widget that accepts `compact: bool` and `mobile: bool` flags, encapsulating stop/pause/skip actions. Reduce the top-bar builder by ~40 lines.

### Route iteration pattern — 2× locations

- `_showAppShellQuickJumpDialog` (line 43): `OnyxRouteSection.values.expand((section) => section.routes)` to build the flat route list.
- `_Sidebar.build` (line 784): `OnyxRouteSection.values.map((section) => _NavSection(...))` to build the section model list.

Both traverse the same `OnyxRouteSection.values` enumeration. Acceptable as-is given different output shapes, but worth noting if a third caller emerges.

---

## Coverage Gaps

| Gap | Risk |
|---|---|
| No test for sidebar overflow on a <380 dp screen | The P1 drawer/sidebar width mismatch is untested — confirmed bug. |
| No test for `_reconcileSourceFilter` when source vanishes mid-update | The P1 setState omission is untested — confirmed bug. |
| No test for intel ticker hidden on mobile layout | Whether mobile intentionally hides the ticker is unconfirmed in tests. |
| No test for autopilot overlay on mobile (label, stop, pause, skip) | `_MobileAutopilotOverlay` is rendered only in the mobile branch but has zero test coverage. |
| No test for Ctrl+K quick-jump shortcut | Only the icon button path is tested; the keyboard shortcut paths (`meta+K`, `ctrl+K`) are not. |
| No test for badge suppression when count drops to 0 after being non-zero | Badge rendering at non-zero counts is tested but badge removal is not. |
| No test for `_navItem` tap on desktop layout | Desktop sidebar nav tap is exercised only via the drawer route in mobile tests. |

---

## Performance / Stability Notes

- **`_sourceCounts()` called 2× per build** (confirmed, see P2 above).
- **`LayoutBuilder` inside a fixed-height `Container(height: 56)` in `_ShellTopBar`** (line 489-496): The inner `LayoutBuilder` is valid — the constraints do differ horizontally — but it fires on every resize. This is fine at current scale; note it if the top bar becomes more complex.
- **Intel ticker auto-scroll timer not paused during route transitions:** The `Timer.periodic` (line 1365) continues ticking even when the ticker is scrolled off-screen (e.g. on routes where `showsShellIntelTicker` is false). The ticker widget is removed from the tree in that case so the timer will be cancelled via `dispose()` — this is safe, but worth confirming that `OnyxRoute.dashboard`'s `showsShellIntelTicker: false` does fully unmount `_ShellIntelTicker`.

---

## Recommended Fix Order

1. **(P1) Sidebar width mismatch on narrow mobile** — pass dynamic width to `_Sidebar` in the mobile drawer branch, matching the actual drawer width. Add a 360×800 viewport test. `AUTO`
2. **(P1) `_reconcileSourceFilter` missing `setState`** — wrap the assignment in `setState` and add a widget test that removes all items of the active filter source. `AUTO`
3. **(P2) `OnyxIntelTickerItem` layer position** — requires a product/architecture decision before Codex can move it. `DECISION`
4. **(P2) Hardcoded `READY` label** — needs a product decision on whether to wire health state. `REVIEW`
5. **(P2) `_sourceCounts()` double call** — pass computed counts into `_resolvedActiveFilter`. Low-risk structural cleanup. `AUTO`
6. **(P3) `GestureDetector` → `InkWell` in `_navItem`** — one-line swap with border radius. `AUTO`
7. **(P3) Shared shortcut lambda** — extract named method. `AUTO`
8. **Coverage gaps** — mobile autopilot overlay, Ctrl+K shortcut, badge removal, desktop sidebar tap. `AUTO`
