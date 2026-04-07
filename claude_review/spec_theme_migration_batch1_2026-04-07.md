# Theme Migration Spec: Batch 1 — Five Screens After Command Center

- Date: 2026-04-07
- Author: Claude Code
- Scope: `admin_page.dart`, `governance_page.dart`, `dispatch_page.dart`, `client_intelligence_reports_page.dart`, `tactical_page.dart`
- Basis: `audit_theme_migration_2026-04-07.md`
- Reference: Command Center (`live_operations_page.dart`) is the migrated reference implementation
- Read-only: yes — this is a spec for Codex to implement

---

## Priority Order

| # | Screen | File | Violations | Rationale |
|---|---|---|---|---|
| 1 | Admin | `lib/ui/admin_page.dart` | ~2,652 | P1; largest file; shadow palette sets tone for all admin dialog surfaces |
| 2 | Governance | `lib/ui/governance_page.dart` | ~674 | P2; same palette pattern; contains duplicated `_partnerStatusColor` to centralise |
| 3 | Dispatch | `lib/ui/dispatch_page.dart` | ~582 | P2; `Colors.white` directly on card backgrounds causes immediate visual breakage |
| 4 | Reports | `lib/ui/client_intelligence_reports_page.dart` | ~563 | P2; D2 decision must be resolved for lines 9562–9574 before full migration |
| 5 | Tactical | `lib/ui/tactical_page.dart` | ~559 | P2; `Colors.white` at lines 1366 and 1597 are hard dark-theme blockers |

---

## Section 0 — Cross-File Shared Patterns (All 5 Screens)

All five files independently define a file-private "shadow palette" with identical light-mode colour values. These constants drive almost every rendered colour in the file. Replacing them is the single highest-leverage action for dark theme.

### 0A — File-private palette → token mapping

Each file uses its own prefix (`_admin…`, `_governance…`, `_dispatch…`, `_reports…`, `_tactical…`) for the same semantic roles. The following table is prefix-independent.

| Suffix pattern | Raw hex examples | Semantic role | → OnyxColorTokens |
|---|---|---|---|
| `…SurfaceColor` / `…PanelColor` | `0xFFFFFFFF` | Card / panel background | `OnyxColorTokens.card` |
| `…AltColor` / `…PanelAltColor` | `0xFFF4F8FC`, `0xFFF5F8FC` | Secondary / off-white surface | `OnyxColorTokens.backgroundSecondary` |
| `…TintColor` / `…PanelTintColor` | `0xFFEEF4FA` | Inset / tinted inner surface | `OnyxColorTokens.surfaceInset` |
| `…RaisedColor` *(admin only)* | `0xFFFBFDFF` | Elevated card surface | `OnyxColorTokens.surface` |
| `…BorderColor` | `0xFFD4DFEA`, `0xFFD4E0EB`, `0xFFD7E0EA` | Subtle dividing border | `OnyxColorTokens.borderSubtle` |
| `…StrongBorderColor` | `0xFFBDD0E2`, `0xFFBDD1E4`, `0xFFBFCCD9` | Prominent container border | `OnyxColorTokens.borderStrong` |
| `…TitleColor` | `0xFF172638`, `0xFF182638`, `0xFF172432` | Title / primary label text | `OnyxColorTokens.textPrimary` |
| `…BodyColor` | `0xFF556B80`, `0xFF51677D`, `0xFF5D6F82` | Body / secondary text | `OnyxColorTokens.textSecondary` |
| `…MutedColor` | `0xFF7A8FA4`, `0xFF74879B`, `0xFF7C8DA0` | Placeholder / muted text | `OnyxColorTokens.textMuted` |
| `…ShadowColor` | `0x0C0F2235` (4% black) | Drop shadow | No token — use `Colors.black.withValues(alpha: 0.05)` or remove entirely (dark surfaces have no visible drop shadow) |

**Migration rule:** In each file, substitute every *usage site* of `_xxxPanelColor`, `_xxxTitleColor`, etc. with the mapped token. The constants themselves can be removed once all usages are replaced.

---

### 0B — `Colors.*` replacement rules

| Pattern | Context | → Replacement |
|---|---|---|
| `backgroundColor: Colors.white` | Card / dialog / panel background | `OnyxColorTokens.card` |
| `color: Colors.white` | Text or icon foreground | `OnyxColorTokens.textPrimary` |
| `foregroundColor: Colors.white` | Button label | `OnyxColorTokens.textPrimary` |
| `dropdownColor: Colors.white` | Dropdown surface | `OnyxColorTokens.card` |
| `background = Colors.white` *(variable)* | Background assignment | `OnyxColorTokens.card` |
| `Colors.white.withValues(alpha: 0.10–0.18)` | Subtle glass overlay | `OnyxColorTokens.glassSurface` (`0x1AFFFFFF`) |
| `Colors.white.withValues(alpha: 0.19–0.27)` | Glass border / divider overlay | `OnyxColorTokens.glassBorder` (`0x26FFFFFF`) |
| `Colors.white.withValues(alpha: 0.28–0.45)` | Glass highlight | `OnyxColorTokens.glassHighlight` (`0x33FFFFFF`) |
| `Colors.white.withValues(alpha: 0.50–0.65)` | Text overlay on tinted card (lower) | `OnyxColorTokens.textSecondary` |
| `Colors.white.withValues(alpha: 0.66+)` | Text overlay on tinted card (higher) | `OnyxColorTokens.textPrimary` |
| `Colors.transparent` on `surfaceTintColor` | Material 3 tint suppression | **Keep as-is** — intentional, not a dark theme issue |
| `Colors.transparent` on `backgroundColor` / `color` | Overlay suppression | Audit per site — most are intentional, verify before changing |

---

### 0C — Shared inline hex → token mapping

These values appear across most or all 5 files. Codex should apply them as a batch substitution across the entire set.

#### Status foreground (solid colours)

| Hex | Tailwind equiv | Semantic role | → OnyxColorTokens |
|---|---|---|---|
| `0xFF10B981` | emerald-500 | Nominal / healthy / live | `OnyxColorTokens.accentGreen` |
| `0xFF34D399` | green-400 | Nominal / healthy | `OnyxColorTokens.accentGreen` |
| `0xFF22C55E` | green-500 | Nominal / healthy | `OnyxColorTokens.accentGreen` |
| `0xFF59D79B` | custom green | Nominal (soft) | `OnyxColorTokens.accentGreen` |
| `0xFF63E6A1` | green-300 | Nominal (soft) | `OnyxColorTokens.accentGreen` |
| `0xFF86EFAC` | green-300 | Nominal (muted label) | `OnyxColorTokens.accentGreen` |
| `0xFFF59E0B` | amber-400 | Warning / at-risk | `OnyxColorTokens.accentAmber` |
| `0xFFFBBF24` | amber-300 | Warning (lighter) | `OnyxColorTokens.accentAmber` |
| `0xFFFACC15` | yellow-400 | Warning / seeded | `OnyxColorTokens.accentAmber` |
| `0xFFFDE68A` | amber-200 | Warning (muted label) | `OnyxColorTokens.accentAmber` |
| `0xFFF1B872` | custom amber | Warning / roster accent | `OnyxColorTokens.accentAmber` |
| `0xFFF97316` | orange-500 | Slipping / declining | `OnyxColorTokens.accentAmber` |
| `0xFFEF4444` | red-500 | Critical / alarm | `OnyxColorTokens.accentRed` |
| `0xFFF87171` | red-400 | Critical (softer) | `OnyxColorTokens.accentRed` |
| `0xFFFF8A94` | custom pink-red | Critical / urgent snack | `OnyxColorTokens.accentRed` |
| `0xFF22D3EE` | cyan-400 | Interactive / info | `OnyxColorTokens.accentCyan` |
| `0xFF38BDF8` | sky-400 | Interactive / accepted | `OnyxColorTokens.accentCyan` |
| `0xFF67E8F9` | cyan-300 | Interactive (soft) | `OnyxColorTokens.accentCyan` |
| `0xFF8FD1FF` | custom sky-blue | Interactive accent / selection | `OnyxColorTokens.accentCyan` — **see D4 in §6** |
| `0xFFA78BFA` | purple-400 | Admin / governance | `OnyxColorTokens.accentPurple` |
| `0xFF8B5CF6` | purple-500 | Admin / governance | `OnyxColorTokens.accentPurple` |
| `0xFF7C3AED` | purple-600 | Admin / governance (strong) | `OnyxColorTokens.accentPurple` |

#### Status surface (10% alpha tint)

| Hex | → OnyxColorTokens |
|---|---|
| `0x1A34D399`, `0x1410B981`, `0x1A86EFAC` | `OnyxColorTokens.greenSurface` |
| `0x1AF59E0B` | `OnyxColorTokens.amberSurface` |
| `0x1422D3EE`, `0x1A22D3EE`, `0x1A8FD1FF`, `0x1438BDF8`, `0x1422D3EE` | `OnyxColorTokens.cyanSurface` |
| `0x1AF87171`, `0x1AEF4444` | `OnyxColorTokens.redSurface` |
| `0x1A8B5CF6`, `0x147C3AED` | `OnyxColorTokens.purpleSurface` |

#### Status border (~40% alpha)

| Hex | → OnyxColorTokens |
|---|---|
| `0x6634D399`, `0x6610B981`, `0x6686EFAC` | `OnyxColorTokens.greenBorder` |
| `0x66F59E0B` | `OnyxColorTokens.amberBorder` |
| `0x6622D3EE`, `0x668FD1FF`, `0x6638BDF8`, `0x553DB8D7` | `OnyxColorTokens.cyanBorder` |
| `0x66F87171`, `0x66EF4444` | `OnyxColorTokens.redBorder` |
| `0x668B5CF6`, `0x664338CA` | `OnyxColorTokens.purpleBorder` |

#### Navy / blue accent (non-status)

| Hex | Context | → OnyxColorTokens |
|---|---|---|
| `0xFF2A5D95` | Filled button BG, text on highlight | `OnyxColorTokens.accentBlue` |
| `0xFF2B5E93` | Filled button background | `OnyxColorTokens.accentBlue` |
| `0xFF315C86`, `0xFF315A86`, `0xFF315F95` | Button foreground / label | `OnyxColorTokens.accentBlue` |
| `0xFF345A87`, `0xFF365E94` | Accent text | `OnyxColorTokens.accentBlue` |
| `0xFF35506F` | Dark navy border accent | `OnyxColorTokens.borderStrong` |
| `0xFF4E92B7` | Muted cyan-blue badge | `OnyxColorTokens.accentCyan` |

#### Light-mode status surface backgrounds (→ dark equivalents)

| Hex | Intent | → OnyxColorTokens |
|---|---|---|
| `0xFFEAF4FF`, `0xFFEAF3FF`, `0xFFEAF8FB`, `0xFFDFF3F8` | Info / cyan tint | `OnyxColorTokens.cyanSurface` |
| `0xFFEAF8F3`, `0xFFF0FBF3`, `0xFFF0FDF4` | Success / green tint | `OnyxColorTokens.greenSurface` |
| `0xFFF7F1FF`, `0xFFF8F2FF`, `0xFFF6F1FF`, `0xFFF2F7FF` | Admin / purple tint | `OnyxColorTokens.purpleSurface` |
| `0xFFFFF1F1`, `0xFFFEF2F2`, `0xFFFFF4F2` | Critical / red tint | `OnyxColorTokens.redSurface` |
| `0xFFFFF7E7`, `0xFFFFFBF0` | Warning / amber tint | `OnyxColorTokens.amberSurface` |
| `0xFFF2F6FC`, `0xFFF3F7FC`, `0xFFECF2F8` | Neutral light surface | `OnyxColorTokens.backgroundSecondary` |

#### Light-mode text (→ dark text on migration)

| Hex | Context | → OnyxColorTokens |
|---|---|---|
| `0xFF10243A`, `0xFF18304A`, `0xFF33506E` | Strong heading | `OnyxColorTokens.textPrimary` |
| `0xFF5B7086`, `0xFF5A718A`, `0xFF556B80` | Secondary body | `OnyxColorTokens.textSecondary` |
| `0xFF9AB1CF`, `0xFF9CB2D1`, `0xFF9CB4D0` | Muted / inactive label | `OnyxColorTokens.textMuted` |
| `0xFF8EA4C2`, `0xFF95A3B7`, `0xFF94A3B8` | Placeholder / disabled | `OnyxColorTokens.textDisabled` |
| `0xFF60748E`, `0xFF7F93A8`, `0xFF7E9EC0` | Inactive step / decoration | `OnyxColorTokens.textMuted` |

---

### 0D — GoogleFonts migration rule (all 5 files)

All five files import `google_fonts` and call `GoogleFonts.inter(…)`. The replacement rule is uniform across the batch:

```dart
// BEFORE
GoogleFonts.inter(
  fontSize: X,
  fontWeight: Y,
  color: Z,
  letterSpacing: W,
)

// AFTER
TextStyle(
  fontFamily: OnyxDesignTokens.fontFamily,   // = 'Inter'
  fontSize: X,
  fontWeight: Y,
  color: Z,
  letterSpacing: W,
)
```

After all calls are replaced, remove the `import 'package:google_fonts/google_fonts.dart';` import from the file. Verify that `Inter` is already bundled via the asset font declaration in `pubspec.yaml` (it should be, given the `OnyxTheme` already uses `OnyxDesignTokens.fontFamily`).

---

## Section 1 — Admin (`lib/ui/admin_page.dart`)

### Private palette (lines 77–84)

| Constant | Hex | → OnyxColorTokens |
|---|---|---|
| `_adminDialogSurfaceColor` | `0xFFFFFFFF` | `OnyxColorTokens.card` |
| `_adminDialogAltColor` | `0xFFF5F8FC` | `OnyxColorTokens.backgroundSecondary` |
| `_adminDialogRaisedColor` | `0xFFFBFDFF` | `OnyxColorTokens.surface` |
| `_adminDialogBorderColor` | `0xFFD4DFEA` | `OnyxColorTokens.borderSubtle` |
| `_adminDialogStrongBorderColor` | `0xFFBDD0E2` | `OnyxColorTokens.borderStrong` |
| `_adminDialogTitleColor` | `0xFF172638` | `OnyxColorTokens.textPrimary` |
| `_adminDialogBodyColor` | `0xFF556B80` | `OnyxColorTokens.textSecondary` |
| `_adminDialogMutedColor` | `0xFF7A8FA4` | `OnyxColorTokens.textMuted` |

### `_adminAccentTextColor` function (line 86)

No structural change needed beyond the constant substitution above. Once `_adminDialogTitleColor` → `OnyxColorTokens.textPrimary`, the lerp automatically operates in dark-token space.

### `Colors.white` critical replacements

| Lines | Pattern | → Replacement |
|---|---|---|
| 1956, 2080, 2212 | `color: Colors.white` (card decoration) | `OnyxColorTokens.card` |
| 2505 | `backgroundColor: Colors.white` (outlined button) | `OnyxColorTokens.card` |
| 2652, 2749, 8671, 8700 | `foregroundColor: Colors.white` (button label) | `OnyxColorTokens.textPrimary` |
| 2722 | `backgroundColor: Colors.white` (outlined button) | `OnyxColorTokens.card` |
| 5614, 5646, 7748, 14158, 15098 | `color: Colors.white` (text / icon) | `OnyxColorTokens.textPrimary` |
| 9837 | `color: selected ? … : Colors.white` | unselected branch → `OnyxColorTokens.card` |
| 13689 | `color: selected ? … : Colors.white` | unselected branch → `OnyxColorTokens.card` |
| 12984, 15183, 15217, 15420, 15662, 15687, 15723 | `backgroundColor: Colors.white` (panels / dialogs) | `OnyxColorTokens.card` |
| 16341, 16387, 16637, 16711, 17077, 17098 | `backgroundColor: Colors.white` | `OnyxColorTokens.card` |
| 17726, 18311, 19302, 19437, 19679, 19720, 19826 | `Colors.white` (text or BG) | `OnyxColorTokens.textPrimary` or `OnyxColorTokens.card` by context |
| 20303, 20587, 21353, 21387, 21827 | `backgroundColor: Colors.white` | `OnyxColorTokens.card` |
| 22175, 24892, 25937, 36940 | `Colors.white` / `dropdownColor` | `OnyxColorTokens.textPrimary` / `OnyxColorTokens.card` |
| 44183, 44538 | `Colors.white` (foreground / BG assign) | `OnyxColorTokens.textPrimary` / `OnyxColorTokens.card` |
| 43464 | `color: light ? Colors.white : _adminDialogAltColor` | `Colors.white` → `OnyxColorTokens.card`; `_adminDialogAltColor` → `OnyxColorTokens.backgroundSecondary` |

### `Color.alphaBlend` white-base patterns (lines 2839–2870)

These blend toward `Colors.white` assuming a light background. Replace the white blend target with a dark card colour.

| Lines | Current | → Replacement |
|---|---|---|
| 2839–2843 | `Color.alphaBlend(Colors.white.withValues(alpha: 0.62), accent.withValues(alpha: 0.1))` | `Color.alphaBlend(OnyxColorTokens.card.withValues(alpha: 0.8), accent.withValues(alpha: 0.1))` |
| 2867–2871 | `Color.alphaBlend(Colors.white.withValues(alpha: 0.54), accent.withValues(alpha: 0.08))` | `Color.alphaBlend(OnyxColorTokens.card.withValues(alpha: 0.7), accent.withValues(alpha: 0.08))` |

### Glass / alpha-white overlays (admin)

| Lines | Alpha | → OnyxColorTokens |
|---|---|---|
| 2841 | 0.62 | `OnyxColorTokens.glassHighlight` |
| 2869 | 0.54 | `OnyxColorTokens.glassHighlight` |
| 3004 | 0.46 | `OnyxColorTokens.glassBorder` |
| 18678 | 0.56 | `OnyxColorTokens.glassHighlight` |
| 21972 | isActive ? 0.56 : 0.68 | `OnyxColorTokens.textSecondary` (lower) / `textPrimary` (higher) |
| 22005, 40895, 43420 | 0.72, 0.56 | `OnyxColorTokens.textPrimary` |
| 40933 | 0.62 | `OnyxColorTokens.glassHighlight` |
| 40937 | 0.36 | `OnyxColorTokens.glassBorder` |

### Admin-specific inline values

| Hex | Lines (sample) | Context | → OnyxColorTokens |
|---|---|---|---|
| `0xFF8FD1FF` | 1288, 1394, 1815, 2146, 2150, 2721 | Primary interactive accent throughout admin | `OnyxColorTokens.accentCyan` (**D4**) |
| `0xFF2B5E93` | 1835 | Filled button background | `OnyxColorTokens.accentBlue` |
| `0xFFEAF2FB`, `0xFFD9E6F5` | 1862 | Light blue gradient stops | `OnyxColorTokens.cyanSurface` |
| `0x14334155` | 1869 | Shadow tint on button | `OnyxColorTokens.borderSubtle` |
| `0xFF365E94` | 1879 | Accent text on hover | `OnyxColorTokens.accentBlue` |
| `0xFF34D399` / `0xFFF59E0B` | 1921–1941 | Status ternary (healthy/warning) | `accentGreen` / `accentAmber` |

---

## Section 2 — Governance (`lib/ui/governance_page.dart`)

### Private palette (lines 45–53)

| Constant | Hex | → OnyxColorTokens |
|---|---|---|
| `_governancePanelColor` | `0xFFFFFFFF` | `OnyxColorTokens.card` |
| `_governancePanelAltColor` | `0xFFF4F8FC` | `OnyxColorTokens.backgroundSecondary` |
| `_governancePanelTintColor` | `0xFFEEF4FA` | `OnyxColorTokens.surfaceInset` |
| `_governanceBorderColor` | `0xFFD4E0EB` | `OnyxColorTokens.borderSubtle` |
| `_governanceBorderStrongColor` | `0xFFBDD1E4` | `OnyxColorTokens.borderStrong` |
| `_governanceTitleColor` | `0xFF182638` | `OnyxColorTokens.textPrimary` |
| `_governanceBodyColor` | `0xFF51677D` | `OnyxColorTokens.textSecondary` |
| `_governanceMutedColor` | `0xFF74879B` | `OnyxColorTokens.textMuted` |
| `_governanceShadowColor` | `0x0C0F2235` | `Colors.black.withValues(alpha: 0.05)` or remove |

### `Colors.white` critical replacements

| Line | Pattern | → Replacement |
|---|---|---|
| 2010 | `color: Colors.white` | `OnyxColorTokens.textPrimary` |

### `_partnerStatusColor` function (line 14753) — duplication target

This duplicates `events_review_page.dart:7498`. Token mapping:

| PartnerDispatchStatus | Raw hex | → OnyxColorTokens |
|---|---|---|
| `.accepted` | `0xFF38BDF8` (sky-400) | `OnyxColorTokens.accentCyan` |
| `.onSite` | `0xFFF59E0B` (amber-400) | `OnyxColorTokens.accentAmber` |
| `.allClear` | `0xFF10B981` (emerald-500) | `OnyxColorTokens.accentGreen` |
| `.cancelled` | `0xFFEF4444` (red-500) | `OnyxColorTokens.accentRed` |

After migrating both `governance_page.dart` and `events_review_page.dart`, centralise this logic into a shared resolver (e.g. `OnyxStatusResolver.partnerDispatchStatusColor(PartnerDispatchStatus)` → `OnyxStatusTokens`).

### Governance-specific inline values

| Hex | Lines (sample) | Context | → OnyxColorTokens |
|---|---|---|---|
| `0xFF8FD1FF` | 872, 1870, 1916 | Interactive accent | `OnyxColorTokens.accentCyan` (**D4**) |
| `0xFF34D399` / `0xFFF59E0B` / `0xFFEF4444` | 1427–1439 | Status ternary | `accentGreen` / `accentAmber` / `accentRed` |
| `0xFF22C55E` | 1623 | Healthy secondary | `OnyxColorTokens.accentGreen` |
| `0xFF67E8F9` | 1444, 1528, 1676, 1691, 1698 | Interactive / info | `OnyxColorTokens.accentCyan` |
| `0xFFFDE68A` | 1537 | Warning label | `OnyxColorTokens.accentAmber` |
| `0xFF9CB2D1` | 1546 | Muted label | `OnyxColorTokens.textMuted` |
| `0xFFF1B872` | 1648, 1655, 1719 | Roster / amber accent | `OnyxColorTokens.accentAmber` |
| `0xFFA78BFA` | 1665, 1708 | Admin / governance accent | `OnyxColorTokens.accentPurple` |
| `0xFF5A718A` | 1755 | Secondary label | `OnyxColorTokens.textSecondary` |
| `0xFF18304A` | 1765 | Dark heading text | `OnyxColorTokens.textPrimary` |
| `0xFF4E92B7` | 1465 | Muted cyan badge | `OnyxColorTokens.accentCyan` |
| `0xFFFF8A94` | 1900 | Critical snack accent | `OnyxColorTokens.accentRed` |
| `0xFF0E203A` | 1934 | Info snack background (dark navy) | **Keep as-is** — already dark; or `OnyxColorTokens.cyanSurface` |
| `0xFF3A0E14` | 1936 | Critical snack background | `OnyxColorTokens.redSurface` (`0xFF341516` ≈ match) |

---

## Section 3 — Dispatch (`lib/ui/dispatch_page.dart`)

### Private palette (lines 33–41)

| Constant | Hex | → OnyxColorTokens |
|---|---|---|
| `_dispatchPanelColor` | `0xFFFFFFFF` | `OnyxColorTokens.card` |
| `_dispatchPanelAltColor` | `0xFFF4F8FC` | `OnyxColorTokens.backgroundSecondary` |
| `_dispatchPanelTintColor` | `0xFFEEF4FA` | `OnyxColorTokens.surfaceInset` |
| `_dispatchBorderColor` | `0xFFD4E0EB` | `OnyxColorTokens.borderSubtle` |
| `_dispatchBorderStrongColor` | `0xFFBDD1E4` | `OnyxColorTokens.borderStrong` |
| `_dispatchTitleColor` | `0xFF182638` | `OnyxColorTokens.textPrimary` |
| `_dispatchBodyColor` | `0xFF51677D` | `OnyxColorTokens.textSecondary` |
| `_dispatchMutedColor` | `0xFF74879B` | `OnyxColorTokens.textMuted` |
| `_dispatchShadowColor` | `0x0C0F2235` | Remove or `Colors.black.withValues(alpha: 0.05)` |

### `Colors.white` critical replacements

| Line | Pattern | → Replacement |
|---|---|---|
| 1238 | `color: Colors.white` (text) | `OnyxColorTokens.textPrimary` |
| 2218 | `backgroundColor: Colors.white` (panel) | `OnyxColorTokens.card` |
| 3184 | `color: Colors.white` (text) | `OnyxColorTokens.textPrimary` |
| 3515 | `Colors.white.withValues(alpha: 0.7)` (glass) | `OnyxColorTokens.glassHighlight` |
| 6803 | `color: Colors.transparent` | **Keep** (overlay suppression) |
| 6860 | `Colors.white.withValues(alpha: isActive ? 0.6 : 0.72)` | `OnyxColorTokens.textSecondary` (0.6) / `OnyxColorTokens.textPrimary` (0.72) |
| 6894 | `Colors.white.withValues(alpha: 0.72)` | `OnyxColorTokens.textPrimary` |
| 7103 | `Colors.white.withValues(alpha: 0.72)` | `OnyxColorTokens.textPrimary` |

### `_partnerProgressTone` resolver (lines 5097–5120)

Replace 3-tuple raw hex with token triples:

| PartnerDispatchStatus | Current foreground | Current surface | Current border | → Tokens |
|---|---|---|---|---|
| `.accepted` | `0xFF38BDF8` | `0x1A38BDF8` | `0x6638BDF8` | `accentCyan` / `cyanSurface` / `cyanBorder` |
| `.onSite` | `0xFFF59E0B` | `0x1AF59E0B` | `0x66F59E0B` | `accentAmber` / `amberSurface` / `amberBorder` |
| `.allClear` | `0xFF34D399` | `0x1A34D399` | `0x6634D399` | `accentGreen` / `greenSurface` / `greenBorder` |
| `.cancelled` | `0xFFF87171` | `0x1AF87171` | `0x66F87171` | `accentRed` / `redSurface` / `redBorder` |

Similarly for `_DispatchFocusState` colour switch (lines 3504–3507):

| State | Current hex | → OnyxColorTokens |
|---|---|---|
| `.exact` | `0xFF22D3EE` | `OnyxColorTokens.accentCyan` |
| `.scopeBacked` | `0xFF8FD1FF` | `OnyxColorTokens.accentCyan` (**D4**) |
| `.seeded` | `0xFFFACC15` | `OnyxColorTokens.accentAmber` |
| `.none` | `0xFF9AB1CF` | `OnyxColorTokens.textMuted` |

### Dispatch-specific inline values

| Hex | Lines (sample) | Context | → OnyxColorTokens |
|---|---|---|---|
| `0xFF8FD1FF` | 664, 1162 area, 2418, 2686–2688, 3245–3247 | Default interactive accent | `OnyxColorTokens.accentCyan` (**D4**) |
| `0xFF8A5A16` / `0xFF9F2A25` | 1114–1118 | Warning / critical text on light badge | `accentAmber` / `accentRed` |
| `0xFFF7C66A` / `0xFF6DDB9F` / `0xFFFF8A7A` | 1128–1132 | Status badge foreground | `accentAmber` / `accentGreen` / `accentRed` |
| `0xFF9FD8FF` | 1291 | Info highlight text | `OnyxColorTokens.accentCyan` |
| `0xFF0F6D84` / `0xFF1E7B59` | 1447, 1469, 1493, 1515 | Dark teal / green accent on tinted bg | `accentCyan` / `accentGreen` |
| `0xFF345A87` / `0xFF6E3EB5` / `0xFF6C42BC` | 1524, 1533, 1542 | Status variant accents | `accentBlue` / `accentPurple` / `accentPurple` |
| `0xFFB83A35` | 1852 | Danger button background | `OnyxColorTokens.accentRed` |
| `0xFF7A4BC1` / `0xFF3567AE` | 1924 | Resolved / unresolved accent | `accentPurple` / `accentBlue` |
| `0xFFA24C75` | 1978, 2013 | Escalated / rose accent | `OnyxColorTokens.accentRed` (no closer token) |
| `0xFF6F4AA7` | 2023 | Admin escalation | `OnyxColorTokens.accentPurple` |
| `0xFF081018` | 3755 | Very dark text on accent button | `OnyxColorTokens.shell` |
| `0xFF9AB1CF` | 3507, 4285, 5535, 6027, 6044 | Inactive / none state | `OnyxColorTokens.textMuted` |
| `0xFF3B82F6` alpha variants | 2722–3002 | Blue broadcast / radio status | `OnyxColorTokens.accentCyan` (intent: interactive info) |
| `0xFF10B981` | 5194, 5217, 5796 | Live / operational | `OnyxColorTokens.accentGreen` |
| `0xFFBFD7F2` | 5601 | Muted blue chip | `OnyxColorTokens.textMuted` |

---

## Section 4 — Reports (`lib/ui/client_intelligence_reports_page.dart`)

### ⚠️ D2 DECISION required for lines 9562–9574 before full migration — see §6

The rest of the file can be migrated independently of D2.

### Private palette (lines 52–59)

| Constant | Hex | → OnyxColorTokens |
|---|---|---|
| `_reportsPanelColor` | `0xFFFFFFFF` | `OnyxColorTokens.card` |
| `_reportsPanelAltColor` | `0xFFF4F8FC` | `OnyxColorTokens.backgroundSecondary` |
| `_reportsPanelTintColor` | `0xFFEEF4FA` | `OnyxColorTokens.surfaceInset` |
| `_reportsBorderColor` | `0xFFD4E0EB` | `OnyxColorTokens.borderSubtle` |
| `_reportsTitleColor` | `0xFF182638` | `OnyxColorTokens.textPrimary` |
| `_reportsBodyColor` | `0xFF51677D` | `OnyxColorTokens.textSecondary` |
| `_reportsMutedColor` | `0xFF74879B` | `OnyxColorTokens.textMuted` |
| `_reportsShadowColor` | `0x0C0F2235` | Remove or `Colors.black.withValues(alpha: 0.05)` |

### `Colors.*` replacements

| Line | Pattern | → Replacement |
|---|---|---|
| 3607, 3801, 4369, 4651, 8823 | `surfaceTintColor: Colors.transparent` | **Keep as-is** (Material 3 tint suppression) |
| 9513 | `checkColor: Colors.white` | `OnyxColorTokens.textPrimary` |
| 9565 | `foregroundColor: filled ? Colors.white : const Color(0xFF2A5D95)` | **D2 pending** — provisional: `filled ? OnyxColorTokens.textPrimary : OnyxColorTokens.accentBlue` |

### D2 button pattern — full context (lines 9555–9574)

```dart
// CURRENT
backgroundColor: filled ? const Color(0xFF2A5D95) : const Color(0xFFEAF4FF),
foregroundColor: filled ? Colors.white : const Color(0xFF2A5D95),
disabledBackgroundColor: const Color(0xFFF0F5FB),
disabledForegroundColor: _reportsMutedColor,
side: BorderSide(color: filled ? const Color(0xFF2A5D95) : _reportsBorderColor),
```

Provisional token mapping (depends on D2 resolution in §6):

```dart
// AFTER (Option A — preserve navy)
backgroundColor: filled ? OnyxColorTokens.accentBlue : OnyxColorTokens.cyanSurface,
foregroundColor: filled ? OnyxColorTokens.textPrimary : OnyxColorTokens.accentBlue,
disabledBackgroundColor: OnyxColorTokens.surfaceInset,
disabledForegroundColor: OnyxColorTokens.textMuted,
side: BorderSide(color: filled ? OnyxColorTokens.accentBlue : OnyxColorTokens.borderSubtle),
```

### Reports-specific inline values

| Hex | Lines (sample) | Context | → OnyxColorTokens |
|---|---|---|---|
| `0xFF8FD1FF` | 146, 829, 838, 880, 1116, 1207 | Primary receipt lane accent | `OnyxColorTokens.accentCyan` (**D4**) |
| `0xFF59D79B` | 824, 833, 843, 852, 898, 940 | Green receipt accent | `OnyxColorTokens.accentGreen` |
| `0xFF60A5FA` | 888 | Blue-400 accent | `OnyxColorTokens.accentCyan` |
| `0xFF9CB2D1` | 863 | Muted chip label | `OnyxColorTokens.textMuted` |
| `0xFFF2F6FB` | 968 | Neutral card surface | `OnyxColorTokens.backgroundSecondary` |
| `0xFFD1DCE8` | 970 | Subtle border on neutral card | `OnyxColorTokens.borderSubtle` |
| `0xFF33506E` / `0xFF10243A` | 978, 979 | Header text | `OnyxColorTokens.textPrimary` |
| `0xFF5B7086` | 983 | Body text | `OnyxColorTokens.textSecondary` |
| `0xFFF3F7FC` | 1044 | Very light surface | `OnyxColorTokens.backgroundSecondary` |
| `0xFFE3EAF2` / `0xFFE9F1F8` | 1068, 1071 | Slight tint surfaces | `OnyxColorTokens.surfaceInset` |
| `0xFFC7D5E3` | 1075, 1078 | Subtle tint border | `OnyxColorTokens.borderSubtle` |
| `0xFF7A8CA1` | 1085 | Label text | `OnyxColorTokens.textMuted` |
| `0xFF18304A` | 1088 | Dark label text | `OnyxColorTokens.textPrimary` |
| `0xFFF6C067` | 1138, 1253 | Amber highlight | `OnyxColorTokens.accentAmber` |
| `0xFFB9C6D8` | 1261 | Muted border | `OnyxColorTokens.borderSubtle` |

---

## Section 5 — Tactical (`lib/ui/tactical_page.dart`)

### Private palette (lines 35–41)

| Constant | Hex | → OnyxColorTokens |
|---|---|---|
| `_tacticalSurfaceColor` | `0xFFFFFFFF` | `OnyxColorTokens.card` |
| `_tacticalAltSurfaceColor` | `0xFFF5F8FC` | `OnyxColorTokens.backgroundSecondary` |
| `_tacticalBorderColor` | `0xFFD7E0EA` | `OnyxColorTokens.borderSubtle` |
| `_tacticalStrongBorderColor` | `0xFFBFCCD9` | `OnyxColorTokens.borderStrong` |
| `_tacticalTitleColor` | `0xFF172432` | `OnyxColorTokens.textPrimary` |
| `_tacticalBodyColor` | `0xFF5D6F82` | `OnyxColorTokens.textSecondary` |
| `_tacticalMutedColor` | `0xFF7C8DA0` | `OnyxColorTokens.textMuted` |

### `Colors.white` critical replacements

| Line | Pattern | → Replacement |
|---|---|---|
| 1366 | `backgroundColor: Colors.white` | `OnyxColorTokens.card` |
| 1442 | `color: Colors.white` | `OnyxColorTokens.textPrimary` |
| 1597 | `backgroundColor: Colors.white` | `OnyxColorTokens.card` |
| 1937 | `Colors.white.withValues(alpha: 0.62)` | `OnyxColorTokens.glassHighlight` |
| 2063 | `foregroundColor: Colors.white` | `OnyxColorTokens.textPrimary` |
| 3218 | `color: Colors.white` | `OnyxColorTokens.textPrimary` |
| 3599 | `color: Colors.white` | `OnyxColorTokens.textPrimary` |
| 4140 | `color: Colors.transparent` | **Keep** (overlay suppression) |
| 6608 | `Colors.white.withValues(alpha: 0.58)` | `OnyxColorTokens.textSecondary` |
| 6725 | `Colors.white.withValues(alpha: 0.72)` | `OnyxColorTokens.textPrimary` |
| 6939 | `Colors.white.withValues(alpha: 0.74)` | `OnyxColorTokens.textPrimary` |

### Tactical-specific inline values

| Hex | Lines (sample) | Context | → OnyxColorTokens |
|---|---|---|---|
| `0xFF8FD1FF` | 475, 1476, 1870, 1916, 1939 | Default interactive accent | `OnyxColorTokens.accentCyan` (**D4**) |
| `0xFF365E94` | 1365 | Blue accent foreground | `OnyxColorTokens.accentBlue` |
| `0xFF9DB9D9` | 1370 | Muted blue label | `OnyxColorTokens.textMuted` |
| `0xFF6C4BD2` | 1390 | Purple identity accent | `OnyxColorTokens.accentPurple` |
| `0xFFB7A5EE` | 1394 | Light purple (hover label) | `OnyxColorTokens.accentPurple` |
| `0xFFF6F1FF` | 1396 | Purple tint surface | `OnyxColorTokens.purpleSurface` |
| `0xFF8B5CF6` | 1661 | Admin accent | `OnyxColorTokens.accentPurple` |
| `0x1A7C3AED` | 1696 | Admin surface | `OnyxColorTokens.purpleSurface` |
| `0x664338CA` | 1698 | Admin border | `OnyxColorTokens.purpleBorder` |
| `0xFFDCD4FF` | 1772 | Admin foreground (soft) | `OnyxColorTokens.accentPurple` |
| `0x147C3AED` | 1773 | Admin surface alpha | `OnyxColorTokens.purpleSurface` |
| `0x667C3AED` | 1774 | Admin border alpha | `OnyxColorTokens.purpleBorder` |
| `0xFFEF4444` | 720, 1030 | Critical accent | `OnyxColorTokens.accentRed` |
| `0xFFF59E0B` | 732, 1042 | Warning accent | `OnyxColorTokens.accentAmber` |
| `0xFF2DD4BF` | 2066 | Teal / secondary interaction | `OnyxColorTokens.accentCyan` |
| `0xFFF5C27A` | 1940, 2055 | Amber-orange notification | `OnyxColorTokens.accentAmber` |
| `0xFFFF8A94` | 1937 | Critical snack accent | `OnyxColorTokens.accentRed` |
| `0xFF0E203A` | 1934 | Info snack background (dark navy) | **Keep as-is** or `OnyxColorTokens.cyanSurface` |

---

## Section 6 — Decisions

### D2 (from audit) — `Color(0xFF2A5D95)` button pattern in Reports

- **File:** `client_intelligence_reports_page.dart:9562–9574`
- **Question:** The filled/unfilled button uses `0xFF2A5D95` (navy blue = `accentBlue`) as both filled background and unfilled text colour. Unfilled state has `0xFFEAF4FF` light tint as background. On dark theme, what is the correct unfilled state?
  - **Option A — preserve navy:** Unfilled = `cyanSurface` bg + `accentBlue` text + `borderSubtle` stroke. Consistent with the `accentBlue` token intent.
  - **Option B — shift to interactive:** Unfilled = `cyanSurface` bg + `accentCyan` text + `cyanBorder` stroke. Unifies with the broader interactive token set.
- **Provisional recommendation:** Option A. `accentBlue` (`0xFF2A5D95`) is already in the token system with this exact purpose; preserving it avoids a semantic shift in the reports UI.

### D3 (from audit) — Glass surface tokens

- **Files:** All 5 screens in this batch
- **Question:** Should `Colors.white.withValues(alpha: X)` glass overlays map to the three `OnyxColorTokens.glass*` constants, or should each be expressed as a precise alpha?
- **Recommendation:** Round to the nearest glass token per the mapping in §0B rather than preserving exact alphas. The three tokens (`0x1A`, `0x26`, `0x33`) cover the range well.

### D4 (new) — `Color(0xFF8FD1FF)` sky-blue accent

- **Files:** All 5 screens in this batch — 100+ usages total
- **Question:** `0xFF8FD1FF` (periwinkle / sky blue) is the dominant interactive accent in this batch. It differs in hue from `OnyxColorTokens.accentCyan = 0xFF00B4D8` (teal). Mapping it to `accentCyan` introduces a visible hue shift on all interactive elements.
  - **Option A — accept the shift:** Map all `0xFF8FD1FF` → `accentCyan`. Visual consistency with the token system; no new token needed.
  - **Option B — add `accentSky`:** Add `static const Color accentSky = Color(0xFF8FD1FF)` to `OnyxColorTokens` before migrating. Preserves the existing selection/chip/tab character distinct from the active-watch `accentCyan`.
- **Recommendation:** **Add `accentSky = Color(0xFF8FD1FF)` to `OnyxColorTokens`** before beginning the batch migration. The sky-blue accent and the teal `accentCyan` serve different interactive roles across the app. References to `0xFF8FD1FF` throughout this batch should then map to `OnyxColorTokens.accentSky`.

---

## Section 7 — Migration Execution Sequence for Codex

Apply changes in this order within each file to minimise intermediate breakage:

1. Replace all file-private `_xxx*Color` constant usages (global substitution per §1A–5A)
2. Replace `Colors.white` / `Colors.black` / `dropdownColor: Colors.white` (per §1B–5B)
3. Resolve `Color.alphaBlend` white-base patterns (admin only, §1, alphaBlend block)
4. Replace inline status hex values using §0C tables (batch scan across all 5 files)
5. Replace inline surface / text hex values using §0C tables
6. Replace all `GoogleFonts.inter(…)` calls with `TextStyle(fontFamily: OnyxDesignTokens.fontFamily, …)`
7. Remove `import 'package:google_fonts/google_fonts.dart';` from each file
8. Run `flutter analyze` and fix residual type or null-safety issues
9. Run existing widget tests if present

Do not change `Colors.transparent` usages without per-site confirmation of intent.

---

## Appendix — Token Quick Reference

| OnyxColorTokens | Hex | Role |
|---|---|---|
| `shell` / `backgroundPrimary` | `0xFF0A0A0F` | Page scaffold |
| `backgroundSecondary` | `0xFF111118` | Sidebar / off-page |
| `card` / `surface` | `0xFF16161F` | Card and dialog surface |
| `surfaceInset` | `0xFF0E1519` | Inset panel |
| `surfaceEmphasis` | `0xFF29233D` | Selected state surface |
| `borderSubtle` | `0xFF1E1E2E` | Dividers / inactive borders |
| `borderStrong` | `0xFF313844` | Container borders |
| `divider` | `0xFF1B2129` | Horizontal rule |
| `textPrimary` | `0xFFF2F5F7` | Heading / primary |
| `textSecondary` | `0xFF9DA6B4` | Body / secondary |
| `textMuted` | `0xFF737D8B` | Placeholder / inactive nav |
| `textDisabled` | `0xFF565F6B` | Disabled |
| `accentRed` | `0xFFFF3B5C` | Critical / alarm |
| `accentGreen` | `0xFF00D4AA` | Nominal / healthy |
| `accentAmber` | `0xFFF5A623` | Warning |
| `accentCyan` | `0xFF00B4D8` | Interactive / info / active watch |
| `accentPurple` | `0xFF7B5EA7` | Admin / governance |
| `accentBlue` | `0xFF2A5D95` | Navy accent / filled buttons |
| *(proposed)* `accentSky` | `0xFF8FD1FF` | Selection / chip / tab accent — **pending D4** |
| `glassSurface` | `0x1AFFFFFF` | 10% white glass |
| `glassBorder` | `0x26FFFFFF` | 15% white glass border |
| `glassHighlight` | `0x33FFFFFF` | 20% white glass highlight |
| `greenSurface` | `0xFF11211E` | Nominal tint |
| `amberSurface` | `0xFF342216` | Warning tint |
| `redSurface` | `0xFF341516` | Critical tint |
| `cyanSurface` | `0xFF163440` | Interactive tint |
| `purpleSurface` | `0xFF281C3E` | Admin tint |
| `greenBorder` | `0xFF285546` | Nominal border |
| `amberBorder` | `0xFF72501E` | Warning border |
| `redBorder` | `0xFF7F302E` | Critical border |
| `cyanBorder` | `0xFF295C6F` | Interactive border |
| `purpleBorder` | `0xFF5B2F96` | Admin border |
