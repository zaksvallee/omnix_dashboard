# Audit: onyx_surface.dart

- Date: 2026-04-08
- Auditor: Claude Code
- Scope: `lib/ui/onyx_surface.dart` (898 lines, 10 exported symbols)
- Read-only: yes

---

## Executive Summary

`onyx_surface.dart` is a well-structured shared UI surface library — the design token and layout primitive layer for the whole app. Its 10 exports are used across 27 files (251 occurrences). The file is mostly safe and contains no logic bugs. The main risks are: (1) two nearly-identical `BoxDecoration` patterns that will drift independently, (2) heavy duplication of the "accent bar + title + subtitle" header block repeated verbatim in both branches of `OnyxSectionCard`, (3) `OnyxSectionCard`'s dual-path layout logic is complex enough to cause subtle rendering surprises, and (4) zero widget-level test coverage for any of these primitives.

---

## What Looks Good

- All color constants are file-private (`_onyxXxx`). No design tokens leak into callers.
- `_softenHeroColor` is a pure function — safe, deterministic, no side effects.
- `OnyxPageScaffold` correctly detects an existing `Scaffold` with `maybeOf` before inserting one, avoiding double-scaffold nesting.
- `OnyxTruncationHint` guards `hiddenCount <= 0` and returns `SizedBox.shrink()` — clean early exit.
- `OnyxCommandSurface` + `OnyxViewportWorkspaceLayout` correctly propagate `viewportWidth` rather than always re-reading `MediaQuery`, which avoids unnecessary rebuilds at the surface level.
- `onyxBoundedPanelBody` function is a clean extraction of shared body-constraint logic — though it partially duplicates internal `OnyxSectionCard` logic (see P2).

---

## Findings

### P1 — Duplicated "accent bar + title + subtitle" block inside `OnyxSectionCard`

- **Action: AUTO**
- **Finding:** The header rendering block (accent bar `Container`, title `Text`, subtitle `Text`) is copy-pasted verbatim in two branches of `OnyxSectionCard.build`: lines 456–490 (compact bounded branch) and lines 534–564 (standard branch). They differ only in wrapping (`SingleChildScrollView` vs. `Column`) — not in the header content.
- **Why it matters:** Any future header change (font, spacing, subtitle style) must be applied twice. One branch will drift. This has already happened: the accent bar width in the compact branch is `34` (line 460) and also `34` in the standard branch (line 537) — they match *now*, but this is the exact class of bug this pattern produces.
- **Evidence:** `lib/ui/onyx_surface.dart` lines 456–490 vs. 534–564.
- **Suggested follow-up:** Extract the header block into a private `_OnyxSectionCardHeader` widget or a `_buildHeader()` method. Both branches call it, then independently wrap the body.

---

### P2 — `onyxBoundedPanelBody` partially duplicates `OnyxSectionCard` body-constraint logic

- **Action: REVIEW**
- **Finding:** `onyxBoundedPanelBody` (lines 681–694) applies the same `flexibleChild` / `hasBoundedHeight` / `isHandsetLayout` body-wrapping pattern that lives inside `OnyxSectionCard` (lines 512–516). They are not identical (the free function lacks the `compactBoundedLayout` path), but the logic families overlap. Callers using `onyxBoundedPanelBody` directly bypass `OnyxSectionCard`'s compact path entirely.
- **Why it matters:** Two maintenance surfaces for the same concept. If the handset / bounded heuristic changes, both must be updated in sync.
- **Evidence:** `lib/ui/onyx_surface.dart` lines 512–516 vs. 681–694.
- **Suggested follow-up:** Codex should check which pages call `onyxBoundedPanelBody` vs. `OnyxSectionCard` and assess whether the free function is still needed or can be removed.

---

### P2 — `onyxSelectableRowSurfaceDecoration` and `onyxForensicRowDecoration` are near-identical

- **Action: AUTO**
- **Finding:** `onyxSelectableRowSurfaceDecoration` (lines 808–825) and `onyxForensicRowDecoration` (lines 849–866) produce structurally identical `BoxDecoration`s — same colors, same conditional shadow, same border logic. The only difference is border radius: `12` vs. `16`.
- **Why it matters:** Both are used across at least 6 files. A future color or shadow tweak must be applied to both, and the second is easy to forget.
- **Evidence:** `lib/ui/onyx_surface.dart` lines 808–825 and 849–866.
- **Suggested follow-up:** Collapse into one function with a `radius` parameter (defaulting to `12`), matching the pattern already established by `onyxPanelSurfaceDecoration({double radius = 12})` at line 827.

---

### P2 — `OnyxStoryHero` `_metricChip` uses `computeLuminance()` for label color but ignores `metric.foreground`

- **Action: REVIEW**
- **Finding:** `_metricChip` (line 395) computes `labelColor` from `metric.background.computeLuminance()` and uses it for the label `TextSpan`. However, the caller already provides `metric.foreground` — which is used only for the *value* span (line 413). The label color is derived independently from the background, meaning callers cannot control the label color directly.
- **Why it matters:** If a caller provides a dark `foreground` on a light `background`, the label colour is silently overridden by the luminance logic. This is a silent contract violation: `OnyxStoryMetric.foreground` does not mean "foreground for all text in the chip", which callers may not realise.
- **Evidence:** `lib/ui/onyx_surface.dart` lines 394–428.
- **Suggested follow-up:** Either document explicitly in `OnyxStoryMetric` that `foreground` applies only to the value span, or expose a second `labelColor` field and remove the luminance fallback.

---

### P3 — `OnyxPageHeader._iconLayout` ignores the compact / actions responsive logic of the main `build` path

- **Action: REVIEW**
- **Finding:** When `icon != null && iconColor != null`, `_iconLayout()` is returned immediately (line 93), bypassing the `LayoutBuilder` responsive logic entirely. In `_iconLayout`, `actions` are appended inline with `...actions` (line 220–222) without any compact stacking or wrapping. If many actions are present on a narrow screen, they will overflow.
- **Why it matters:** Every page that passes both `icon`+`iconColor` *and* multiple `actions` to `OnyxPageHeader` is susceptible to overflow on narrow viewports.
- **Evidence:** `lib/ui/onyx_surface.dart` lines 93–95 (early return) and lines 219–222 (`_iconLayout` action rendering).
- **Suggested follow-up:** Codex should audit all `OnyxPageHeader` callsites that pass both `icon` and `actions` to assess real-world exposure. If any page uses 2+ actions with icon layout, `_iconLayout` needs its own `LayoutBuilder` with compact stacking.

---

### P3 — `OnyxViewportWorkspaceLayout` resolves padding at `build` time, not inside `LayoutBuilder`

- **Action: REVIEW** (suspicion, not confirmed bug)
- **Finding:** `resolvedPadding` is computed at line 594 before the `LayoutBuilder` callback. `Directionality.of(context)` is stable for most apps, but if the widget ever appears in a directionality-switching subtree (e.g., RTL inside LTR), the resolved padding would be stale relative to the `LayoutBuilder`'s context.
- **Why it matters:** Low probability for this app (security dashboard, single locale), but the pattern is non-idiomatic. Padding resolution should ideally happen inside the `LayoutBuilder` callback where the `constraints` are used.
- **Evidence:** `lib/ui/onyx_surface.dart` lines 594, 626, 629.
- **Suggested follow-up:** Move `resolvedPadding` inside the `LayoutBuilder` builder closure. No functional change for LTR-only deployments.

---

## Duplication

| Pattern | Locations | Centralization Candidate |
|---|---|---|
| Accent bar + title + subtitle header | `OnyxSectionCard` lines 456–490 and 534–564 | Extract `_OnyxSectionCardHeader` widget |
| Selectable row decoration | `onyxSelectableRowSurfaceDecoration` (L808) and `onyxForensicRowDecoration` (L849) | Single function with `radius` param |
| Body-constraint logic | `OnyxSectionCard` lines 512–516 and `onyxBoundedPanelBody` lines 681–694 | Assess whether free function is still needed |

---

## Coverage Gaps

- **Zero widget tests** for any symbol in `onyx_surface.dart`. The file is imported by 27 pages and is the visual foundation of the entire app. No test covers:
  - `OnyxPageScaffold` double-scaffold guard (`maybeOf` branch)
  - `OnyxSectionCard` compact-bounded layout path (height < 140)
  - `OnyxSectionCard` `flexibleChild` vs. scrollable body switching
  - `OnyxTruncationHint` hidden count = 0 guard
  - `OnyxStoryHero` responsive compact vs. wide layout
  - `OnyxPageHeader` icon layout overflow on narrow viewport
- **Missing golden/snapshot tests** — with 10 primitive widgets used in 27 files, even lightweight golden tests would catch layout regressions earlier than page-level widget tests.

---

## Performance / Stability Notes

- `OnyxSectionCard` wraps a `LayoutBuilder` inside every build call. When used inside `ListView` or `Column` with many items, each card triggers an independent layout measurement. This is standard Flutter but worth noting if card counts grow significantly.
- `OnyxStoryHero` runs `gradientColors.map(_softenHeroColor).toList(growable: false)` on every `build`. This is cheap (2–3 colors) and pure — acceptable. `toList(growable: false)` is already optimal.
- `OnyxCommandSurface` wraps a `LayoutBuilder` around every page body to compute `commandSurfaceMaxWidth`. For pages with `OnyxViewportWorkspaceLayout` (which already has its own `LayoutBuilder`), this is two nested layout passes per rebuild. Functionally correct, but the outer layout pass is redundant if `viewportWidth` is already provided via `OnyxViewportWorkspaceLayout`. Currently it is: `viewportWidth: constraints.maxWidth` at line 600 — so `OnyxCommandSurface`'s inner `LayoutBuilder` is entered but the `viewportWidth` is immediately used from the outer pass. This is safe and the double-pass overhead is negligible.

---

## Recommended Fix Order

1. **Extract `_OnyxSectionCardHeader`** — eliminates the highest-risk duplication, easiest to validate (P1, AUTO).
2. **Collapse `onyxSelectableRowSurfaceDecoration` + `onyxForensicRowDecoration`** into one parameterized function (P2, AUTO).
3. **Add widget tests** for `OnyxSectionCard` layout paths and `OnyxTruncationHint` guard (Coverage Gap, AUTO).
4. **Audit `OnyxPageHeader` icon + actions callsites** for overflow risk (P3, REVIEW).
5. **Clarify `OnyxStoryMetric.foreground` contract** or expose `labelColor` (P2, REVIEW / DECISION depending on whether callers rely on current behaviour).
6. **Assess `onyxBoundedPanelBody` continued necessity** and remove if superseded by `OnyxSectionCard` (P2, REVIEW).
