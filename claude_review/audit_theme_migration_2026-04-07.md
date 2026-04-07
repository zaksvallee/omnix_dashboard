# Audit: Dark Theme Migration — Hardcoded Colors and GoogleFonts across lib/ui/

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: All `lib/ui/**/*.dart` files scanned for `Color(0x...)`, `Colors.*`, and `GoogleFonts.*` not yet routed through `OnyxDesignTokens`
- Read-only: yes

---

## Executive Summary

The token system in `OnyxDesignTokens` / `OnyxColorTokens` / `OnyxTypographyTokens` is structurally complete and well-defined. However, adoption across the UI layer is shallow. Of 67 dart files in `lib/ui/`, **40 contain raw `Color(0x...)` literals**, **26 contain `Colors.*` references**, and **36 contain `GoogleFonts.*` calls** — totalling **7,052 raw hex occurrences, 232 `Colors.*` occurrences, and 3,302 `GoogleFonts.*` occurrences** (combined: ~10,586 unarouted references). Several files also maintain file-private shadow palettes (`_xxxColor` variables) that reproduce token-equivalent values at file scope, creating drift risk. Dark theme support is not achievable without migrating these.

---

## What Looks Good

- `OnyxDesignTokens`, `OnyxColorTokens`, `OnyxStatusTokens`, `OnyxTypographyTokens`, `OnyxSpacingTokens`, `OnyxInsetsTokens`, and `OnyxRadiusTokens` are complete and constitute a solid token contract.
- `OnyxStatusTokens` correctly groups `foreground`, `surface`, `banner`, and `border` per semantic state — this removes ambiguity for status-driven coloring once migration lands.
- Smaller camera bridge components (`onyx_camera_bridge_validation_summary.dart`, `onyx_camera_bridge_status_metadata_panel.dart`, `onyx_camera_bridge_detail_line.dart`) are nearly clean — 1–2 residual calls each.
- Route builder files (`onyx_route_*`) are mostly clean; `onyx_route_operations_builders.dart` is the only outlier.

---

## Findings

### P0 — Systemic infrastructure (affects entire app)

#### Finding 1 — `onyx_theme.dart` still calls `GoogleFonts` 14 times and `Colors` 6 times
- Action: AUTO
- `lib/ui/theme/onyx_theme.dart` constructs `TextTheme` entries using `GoogleFonts.inter(...)` and `GoogleFonts.rajdhani(...)` directly rather than resolving through `OnyxTypographyTokens.sansFamily`. This means font loading is coupled to the theme constructor and bypasses the token abstraction for every app-wide text style. The 6 `Colors.*` calls include `Colors.black` (shadow/scrim — acceptable baseline for Material), `Colors.transparent` (4 — acceptable for surfaceTintColor suppression), and `Colors.white` (highlight — marginal; could be `OnyxColorTokens.textPrimary` or left as Material baseline).
- Evidence: `lib/ui/theme/onyx_theme.dart` — 14 GoogleFonts calls, 6 Colors calls (all lines visible in grep output)
- Suggested follow-up: Replace `GoogleFonts.inter(...)` / `GoogleFonts.rajdhani(...)` in the theme with `fontFamily: OnyxDesignTokens.fontFamily` + style-only properties. `Colors.black` for shadow/scrim is acceptable. Confirm whether `Colors.white` for `highlightColor` should become `OnyxColorTokens.textPrimary`.

---

#### Finding 2 — `onyx_surface.dart` has 20 raw hex literals and 15 `GoogleFonts` calls — it is a widely-shared utility
- Action: REVIEW
- `lib/ui/onyx_surface.dart` is imported across many page files and acts as a shared surface primitive. Its 20 raw `Color(0x...)` literals and 15 `GoogleFonts.*` calls mean any page consuming it inherits unresolved values. The `_softenHeroColor` helper at line 17 blends toward `Colors.white` (line 18) and references `_onyxAccentBlue` (an internal constant at line 213) — both should route through `OnyxColorTokens`. The `Colors.white` fallback at line 337 is a silent fallback that will render incorrectly on dark backgrounds if the expected color is absent.
- Evidence: `lib/ui/onyx_surface.dart` — 20 `Color(0x...)`, 4 `Colors.*`, 15 `GoogleFonts.*`
- Suggested follow-up: Identify the private `_onyxAccentBlue` constant and map it to `OnyxColorTokens.accentCyan`. Replace `Colors.white` blend target in `_softenHeroColor` with `OnyxColorTokens.textPrimary`. Replace all `GoogleFonts.inter(...)` calls with `fontFamily: OnyxDesignTokens.fontFamily`.

---

### P1 — Critical volume or critical-path page files

#### Finding 3 — `admin_page.dart` is the worst single-file offender with ~2,652 total unrouted references
- Action: REVIEW
- `lib/ui/admin_page.dart` has **1,670 raw `Color(0x...)` literals**, **79 `Colors.*` references**, and **903 `GoogleFonts.*` calls**. It also has **878 references to file-private `_xxxColor` variables** — meaning it maintains a shadow palette entirely outside the token system. The top-level function `_adminAccentTextColor` at line 85 accepts a `Color` argument and blends it, which is structurally reasonable, but if callers pass raw literals, the token contract is bypassed upstream. Numerous `Colors.white` calls for `backgroundColor` suggest light-mode assumptions baked into card and dialog surfaces (e.g., lines 2479, 12960, 13665, 15159, 15193, 15638, 15663, 15699, 16317, 17053, 17074, 21803).
- Evidence: `lib/ui/admin_page.dart` — 1,670 `Color(0x...)`, 79 `Colors.*`, 903 `GoogleFonts.*`, 878 `_color` refs
- Suggested follow-up: Enumerate the file-private `_xxxColor` constants and map each to the closest `OnyxDesignTokens` or `OnyxStatusTokens` equivalent. The `Colors.white` background assignments are the most visible breakage point for dark theme — start there. GoogleFonts migration should be systematic: convert all `GoogleFonts.inter(...)` to `fontFamily: OnyxDesignTokens.fontFamily` style objects.

---

#### Finding 4 — `live_operations_page.dart` has ~1,032 total unrouted references on the core operator workflow
- Action: REVIEW
- `lib/ui/live_operations_page.dart` has **713 raw `Color(0x...)` literals**, **12 `Colors.*`**, and **307 `GoogleFonts.*`** — making it the second-highest volume file. It is the core ops monitoring surface, making visual regressions high-stakes. Line 4489 and 13611 use `Colors.white.withValues(alpha: 0.54/0.62)` for text overlays — these should become `OnyxColorTokens.textSecondary` or `textMuted`. Multiple `Colors.transparent` usages (lines 4030, 4984, 8281, 10020, 10102, 10371, 10507, 15427, 16162, 16271) are likely suppressing Material overlays — acceptable if intentional, but should be audited for whether `OnyxColorTokens.borderSubtle` or a surface token is the real intent.
- Evidence: `lib/ui/live_operations_page.dart` — 713 `Color(0x...)`, 12 `Colors.*`, 307 `GoogleFonts.*`, 340 `_color` private refs
- Suggested follow-up: Validate `Colors.transparent` usages are overlay suppression (keep) vs. missing background tokens (replace). Replace alpha-blended white text with `textMuted`/`textSecondary` tokens.

---

#### Finding 5 — `app_shell.dart` is the navigation shell and has 133 unrouted references
- Action: REVIEW
- `lib/ui/app_shell.dart` has **104 raw `Color(0x...)` literals**, **3 `Colors.*`**, and **26 `GoogleFonts.*`**. Its impact exceeds its count because it wraps every page. Line 991 sets `backgroundColor: Colors.white` — this is a direct dark theme blocker on the shell level. Line 1602 uses `Colors.white` as an unselected nav item color — should be `OnyxColorTokens.textMuted`. Line 286 uses `Colors.transparent` for a background — likely intentional overlay suppression but worth verifying.
- Evidence: `lib/ui/app_shell.dart` — 104 `Color(0x...)`, 3 `Colors.*`, 26 `GoogleFonts.*`
- Suggested follow-up: `backgroundColor: Colors.white` at line 991 is the highest-priority single fix — replace with `OnyxColorTokens.shell` or `backgroundPrimary`. Nav rail unselected color at line 1602 → `OnyxColorTokens.textMuted`.

---

### P2 — High volume, page-scoped files

| File | Raw `Color(0x...)` | `Colors.*` | `GoogleFonts.*` | Private `_color` refs | Combined total |
|---|---|---|---|---|---|
| `governance_page.dart` | 414 | 1 | 259 | 230 | ~674 |
| `dispatch_page.dart` | 402 | 8 | 172 | 218 | ~582 |
| `client_intelligence_reports_page.dart` | 409 | 7 | 147 | 164 | ~563 |
| `tactical_page.dart` | 424 | 11 | 124 | 122 | ~559 |
| `client_app_page.dart` | 375 | 2 | 147 | 186 | ~524 |
| `ai_queue_page.dart` | 307 | 2 | 134 | — | ~443 |
| `events_review_page.dart` | 259 | 1 | 141 | 16 | ~401 |

**Notable signals across P2:**

- `tactical_page.dart` lines 1366, 1597: `backgroundColor: Colors.white` — light surface assumption on a tactical command page.
- `dispatch_page.dart` lines 1222, 2202, 3173: `Colors.white` — dispatch UI will render incorrectly on dark shell.
- `client_intelligence_reports_page.dart` line 9496: `foregroundColor: filled ? Colors.white : const Color(0xFF2A5D95)` — hardcodes a light-blue that has no token equivalent, will need a DECISION on whether it maps to `accentCyan` or a new token.
- `governance_page.dart` line 14927: `_partnerStatusColor` top-level function — same pattern as `events_review_page.dart:7498`; these are duplicated status color resolver functions that should be centralized (see Duplication section below).
- `ai_queue_page.dart` line 1078: `backgroundColor: Colors.white` — light background assumption on a queue board.

---

### P3 — Moderate volume

| File | Raw `Color(0x...)` | `Colors.*` | `GoogleFonts.*` | Private `_color` refs | Combined total |
|---|---|---|---|---|---|
| `guard_mobile_shell_page.dart` | 258 | 1 | 126 | 101 | ~385 |
| `onyx_agent_page.dart` | 234 | 18 | 99 | — | ~351 |
| `clients_page.dart` | 227 | 0 | 83 | 2 | ~310 |
| `guards_page.dart` | 149 | 11 | 87 | 114 | ~247 |
| `dashboard_page.dart` | 179 | 4 | 87 | — | ~270 |
| `sites_command_page.dart` | 182 | 0 | 47 | 14 | ~229 |
| `track_overview_board.dart` | 47 | 42 | 44 | — | ~133 |
| `client_comms_queue_board.dart` | 47 | 0 | 22 | 29 | ~69 |

**Notable signals across P3:**

- `onyx_agent_page.dart` lines 4392–4395: `const Color(0xFFEFF6FF)` and `const Color(0xFF93C5FD)` — these are Tailwind blue-50/blue-300 equivalents that appear to be a light-mode focus ring pattern with no token equivalent.
- `track_overview_board.dart` has **42 `Colors.*` usages** — the highest `Colors.*` density of any file outside `admin_page.dart`. Most are `Colors.white.withValues(alpha: ...)` for glass-effect surfaces. These should be mapped to `OnyxColorTokens.borderSubtle`, `surface`, or bespoke overlay tokens.
- `guards_page.dart` lines 2578–2581: ternary between private `_guardsSelectedPanelColor` / `_guardsStrongBorderColor` and `Colors.transparent` — the private constants need token mapping.
- `guard_mobile_shell_page.dart` line 1127: `surfaceTintColor: Colors.transparent` — a Material 3 tint suppression call; this is likely intentional.

---

### P4 — Lower volume

| File | Raw `Color(0x...)` | `Colors.*` | `GoogleFonts.*` | Combined total |
|---|---|---|---|
| `sovereign_ledger_page.dart` | 106 | 10 | 58 | ~174 |
| `events_page.dart` | 97 | 2 | 75 | ~174 |
| `sites_page.dart` | 125 | 1 | 47 | ~173 |
| `ledger_page.dart` | 107 | 1 | 47 | ~155 |
| `risk_intelligence_page.dart` | 44 | 1 | 36 | ~81 |
| `vip_protection_page.dart` | 41 | 2 | 38 | ~81 |
| `onyx_camera_bridge_tone_resolver.dart` | 27 | 0 | 0 | ~27 |
| `video_fleet_scope_health_panel.dart` | 11 | 0 | 3 | ~14 |
| `video_fleet_scope_health_sections.dart` | 12 | 0 | 0 | ~12 |

**Notable signals across P4:**

- `vip_protection_page.dart` uses `GoogleFonts.rajdhani(...)` (lines 155, 272, 531) — Rajdhani is a second font family not declared in `OnyxTypographyTokens`, which only defines `sansFamily = 'Inter'`. This is a DECISION: either add `rajdhaniFamily` to `OnyxTypographyTokens` or eliminate the usage.
- `sovereign_ledger_page.dart` lines 2663, 2677: function signature defaults `Color foregroundColor = Colors.white` and `backgroundColor: Colors.white` — API-level white assumptions that will propagate to callers on dark theme.
- `onyx_camera_bridge_tone_resolver.dart` — 27 raw hex values are likely the tone-to-color mapping logic; these are semantically important and should map explicitly to `OnyxStatusTokens` variants.

---

### P5 — Near-clean camera bridge components

These files have 1–4 total violations and should be cleaned last or alongside their P2/P3 page owners:

| File | Violations |
|---|---|
| `onyx_camera_bridge_health_card_body.dart` | 4 (1 hex + 3 GoogleFonts) |
| `onyx_camera_bridge_shell_panel.dart` | 4 (2 hex + 2 GoogleFonts) |
| `onyx_camera_bridge_detail_line.dart` | 2 (GoogleFonts only) |
| `onyx_camera_bridge_health_panel.dart` | 7 (6 hex + 1 Colors) |
| `onyx_camera_bridge_summary_panel.dart` | 6 (3 hex + 1 Colors + 2 GoogleFonts) |
| `onyx_camera_bridge_action_button.dart` | 2 (1 hex + 1 GoogleFonts) |
| `onyx_camera_bridge_shell_actions.dart` | 2 (hex only) |
| `onyx_camera_bridge_shell_surface.dart` | 3 (hex only) |
| `onyx_camera_bridge_validation_summary.dart` | 1 (GoogleFonts only) |
| `onyx_camera_bridge_status_metadata_panel.dart` | 2 (1 hex + 1 GoogleFonts) |
| `onyx_camera_bridge_status_badge.dart` | 1 (GoogleFonts only) |
| `operator_stream_embed_view_stub.dart` | 3 (2 hex + 1 GoogleFonts) |
| `video_fleet_scope_health_card.dart` | 5 (2 hex + 1 Colors + fallback at lines 164/293) |

---

## Duplication

### Duplicated status color resolver functions
- `_partnerStatusColor(PartnerDispatchStatus status)` exists at:
  - `lib/ui/events_review_page.dart:7498`
  - `lib/ui/governance_page.dart:14927`
- These are top-level file functions implementing the same dispatch-status-to-color logic in two separate files. Both should be centralized into a single shared resolver — ideally as a method on `PartnerDispatchStatus` or in a dedicated `OnyxStatusResolver` utility — and replaced with `OnyxStatusTokens` lookups.
- Action: REVIEW

### Duplicated `_feedColor` / `_eventColor` patterns
- `_feedColor(_FeedStatus status)` at `lib/ui/clients_page.dart:4304`
- `_eventColor(DispatchEvent event)` at `lib/ui/events_review_page.dart:7639`
- `_statusColor(_SiteStatus status)` at `lib/ui/sites_command_page.dart:2749`
- Three separate file-private status-to-color switch functions. Once all route through `OnyxStatusTokens`, these collapse to a single pattern.
- Action: AUTO (after token mapping is confirmed)

### Rajdhani font usage in vip_protection_page.dart
- `GoogleFonts.rajdhani(...)` at lines 155, 272, 531 is the only place in the UI this second font family appears. If intentional, `OnyxTypographyTokens` needs a `displayFamily` constant. If not intentional, it is a rogue font that should become `Inter`.
- Action: DECISION

### `Colors.white.withValues(alpha: ...)` glass-surface pattern
- `track_overview_board.dart` uses this pattern 20+ times for glass-effect cards and borders. `dispatch_page.dart`, `live_operations_page.dart`, `admin_page.dart` use it similarly. This is a candidate for a set of `OnyxColorTokens.glass*` overlay tokens (e.g., `glassSubtle`, `glassMid`, `glassBorder`).
- Action: DECISION

---

## Coverage Gaps

- No widget tests exist that assert dark theme renders — once migration lands, there will be no regression guard. Tests should be added for at minimum `app_shell.dart`, `onyx_surface.dart`, and `onyx_theme.dart` that verify `OnyxColorTokens.backgroundPrimary` is the scaffold background under the ONYX theme.
- `onyx_camera_bridge_tone_resolver.dart` has 27 raw hex values mapping tones to colors, but no tests that lock this mapping. If tokens change, the resolver will silently drift.

---

## Performance / Stability Notes

- `GoogleFonts.inter(...)` and `GoogleFonts.rajdhani(...)` called at widget build time (not in the theme) means font resolution happens on every rebuild of the containing widget, rather than being resolved once at theme construction. `admin_page.dart` (903 calls) and `live_operations_page.dart` (307 calls) are the most affected. Migrating to `fontFamily: OnyxDesignTokens.fontFamily` with `TextStyle` style properties (not `GoogleFonts.*`) removes per-build font lookup overhead.
- `onyx_surface.dart` being a shared utility means its 20 raw hex values are instantiated everywhere it is used. Moving to `const OnyxColorTokens.*` references removes heap allocation for those color objects.

---

## Recommended Fix Order

1. **`onyx_theme.dart`** — theme root; GoogleFonts → `fontFamily: OnyxDesignTokens.fontFamily`. This unblocks the rest. AUTO.
2. **`onyx_surface.dart`** — shared utility; token-map all 20 hex literals and 15 GoogleFonts before P1 pages begin. REVIEW.
3. **`app_shell.dart`** — navigation shell; `Colors.white` at line 991 is the highest-visibility dark theme blocker. REVIEW.
4. **`admin_page.dart`** — 2,652 violations; enumerate and map private `_xxxColor` palette first, then sweep GoogleFonts. Largest migration chunk — scope carefully. REVIEW.
5. **`live_operations_page.dart`** — 1,032 violations on core operator workflow. REVIEW.
6. **`governance_page.dart`** — 674 violations; also contains duplicated `_partnerStatusColor`. REVIEW.
7. **`dispatch_page.dart`** — 582 violations; `Colors.white` background calls on dispatch surfaces are direct breakage. REVIEW.
8. **`client_intelligence_reports_page.dart`** — 563 violations; `Color(0xFF2A5D95)` at line 9496 needs a DECISION before this file can be fully migrated.
9. **`tactical_page.dart`** — 559 violations. REVIEW.
10. **`client_app_page.dart`** — 524 violations. REVIEW.
11. **`ai_queue_page.dart`** — 443 violations. REVIEW.
12. **`events_review_page.dart`** — 401 violations; also contains duplicated `_partnerStatusColor`. REVIEW.
13. **`guard_mobile_shell_page.dart`**, **`onyx_agent_page.dart`**, **`clients_page.dart`** — P3 sweep, 300–385 violations each.
14. **`guards_page.dart`**, **`dashboard_page.dart`**, **`sites_command_page.dart`**, **`track_overview_board.dart`** — P3 sweep, 130–270 violations each.
15. **`client_comms_queue_board.dart`** — 69 violations.
16. **P4 page files** (`sovereign_ledger_page.dart`, `events_page.dart`, `sites_page.dart`, `ledger_page.dart`, `risk_intelligence_page.dart`, `vip_protection_page.dart`) — 80–175 violations each; `vip_protection_page.dart` requires Rajdhani DECISION.
17. **`onyx_camera_bridge_tone_resolver.dart`** — 27 raw hex values need explicit `OnyxStatusTokens` mapping.
18. **P5 camera bridge components** — clean up residual 1–7 violations per file as part of the camera bridge audit pass.

---

## DECISION Items Requiring Zaks Input

| # | File | Question |
|---|---|---|
| D1 | `vip_protection_page.dart` (lines 155, 272, 531) | Is `GoogleFonts.rajdhani(...)` intentional branding? If yes, add `displayFamily` to `OnyxTypographyTokens`. If no, replace with `Inter`. |
| D2 | `client_intelligence_reports_page.dart` line 9496 | `Color(0xFF2A5D95)` — does this map to `accentCyan`, a new `accentBlue` token, or should the filled/unfilled button pattern change entirely? |
| D3 | `track_overview_board.dart` + `admin_page.dart` + others | Should `Colors.white.withValues(alpha: ...)` glass-effect overlays become a set of `OnyxColorTokens.glass*` tokens, or should each file resolve them individually to existing surface/border tokens? |
