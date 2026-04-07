# Audit: Theme Migration Progress — Batch 1

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `live_operations_page.dart` (reference) + 5 batch-1 screens: `admin_page.dart`, `governance_page.dart`, `dispatch_page.dart`, `client_intelligence_reports_page.dart`, `tactical_page.dart`
- Basis: `spec_theme_migration_batch1_2026-04-07.md`
- Read-only: yes

---

## Executive Summary

**Batch 1 migration is 0% complete.** None of the five target screens have received any token substitution. The reference implementation (`live_operations_page.dart`) has completed only Step 1 of 9 (private palette constants replaced with token aliases) and itself still carries 291 `GoogleFonts.inter` calls and 609 inline `Color(0xFF…)` values. The prerequisite D4 decision (`accentSky` token) has not been resolved and the token has not been added to `OnyxColorTokens`. All migration work remains ahead of Codex.

---

## Migration Status by File

### Reference — `lib/ui/live_operations_page.dart`

| Check | Status | Evidence |
|---|---|---|
| Private palette → token aliases | ✅ Done | Lines 69–77: constants now alias `OnyxDesignTokens.*` / `OnyxColorTokens.*` |
| `Colors.white` replacements | ⚠️ Partial | 2 calls remain |
| Inline `Color(0xFF…)` values | ❌ Pending | 609 calls remain |
| `GoogleFonts.inter` → `OnyxDesignTokens.fontFamily` | ❌ Pending | 291 calls remain |
| `google_fonts` import removed | ❌ Pending | Import still present (line 5) |

**Reference completion: ~15% (Step 1 done; Steps 2–7 pending)**

The reference established the palette-alias pattern Codex should replicate in batch-1 files, but it is not itself fully migrated. This is not a blocker for batch-1 work, but Codex should be aware that the reference cannot be used as a model for the later steps.

---

### Batch-1 Screens

| Screen | File | Private Palette | `Colors.white` | `GoogleFonts.inter` | Inline hex | Migration |
|---|---|---|---|---|---|---|
| Admin | `admin_page.dart` | ❌ 8 raw consts (lines 77–84) | ❌ 62 calls | ❌ 870 calls | ❌ 1,478 calls | **0%** |
| Governance | `governance_page.dart` | ❌ 9 raw consts (lines 46–54) | ❌ 1 call | ❌ 251 calls | ❌ 397 calls | **0%** |
| Dispatch | `dispatch_page.dart` | ❌ 9 raw consts (lines 33–41) | ❌ 7 calls | ❌ 171 calls | ❌ 302 calls | **0%** |
| Reports | `client_intelligence_reports_page.dart` | ❌ 8 raw consts (lines 52–59) | ❌ 2 calls | ❌ 147 calls | ❌ 389 calls | **0%** |
| Tactical | `tactical_page.dart` | ❌ 7 raw consts (lines 35–41) | ❌ 10 calls | ❌ 122 calls | ❌ 297 calls | **0%** |

**Batch-1 completion: 0% across all five files.**

---

## Token Infrastructure — What's Ready, What's Missing

### Ready in `OnyxColorTokens` / `OnyxDesignTokens`

All tokens listed in the spec Appendix are confirmed present in `lib/ui/theme/onyx_design_tokens.dart`:

- Shell / background: `shell`, `backgroundPrimary`, `backgroundSecondary`, `card`, `surface`, `surfaceInset`
- Borders: `borderSubtle`, `borderStrong`, `divider`
- Text: `textPrimary`, `textSecondary`, `textMuted`, `textDisabled`
- Accent: `accentRed`, `accentGreen`, `accentAmber`, `accentCyan`, `accentBlue`, `accentPurple`
- Status surfaces: `redSurface`, `greenSurface`, `amberSurface`, `cyanSurface`, `purpleSurface`
- Glass: `glassSurface`, `glassBorder`, `glassHighlight`

### Missing — D4 Blocker

| Token | Status | Impact |
|---|---|---|
| `OnyxColorTokens.accentSky` (`Color(0xFF8FD1FF)`) | ❌ **Not added** | 100+ usages across all 5 batch files; spec §6 D4 recommends adding before migration begins |

The spec recommends adding `accentSky` as a prerequisite. Without it, Codex must either defer all `0xFF8FD1FF` usages or map them to `accentCyan` with a hue shift. The spec recommends Option B (add `accentSky`) to avoid a visible hue change on interactive chips, tabs, and selection elements across all five screens.

---

## What's Complete Across All of `lib/ui/`

To give full repo context, `OnyxDesignTokens` (or `OnyxColorTokens`) usage was searched across the entire `lib/ui/` tree:

| Category | Files |
|---|---|
| Fully migrated to tokens (palette + inline) | `controller_login_page.dart` (no palette, 29 `OnyxDesignTokens` calls, 0 GoogleFonts) |
| Partially migrated (palette aliases done) | `live_operations_page.dart` |
| Not yet started (includes all batch-1 files) | All remaining 60+ UI files |

The `onyx_camera_bridge_*` component files already use `OnyxDesignTokens` heavily (confirmed in prior grep), suggesting the component layer is ahead of the page layer in token adoption.

---

## Pre-Migration Blockers

| # | Blocker | Action | Required before |
|---|---|---|---|
| B1 | `accentSky` token missing from `OnyxColorTokens` | `REVIEW` — Add `static const Color accentSky = Color(0xFF8FD1FF);` to `OnyxColorTokens` in `onyx_design_tokens.dart` | Any batch-1 file migration |
| B2 | D2 button pattern in Reports (lines 9555–9574) | `DECISION` — Zaks to confirm Option A (preserve navy) vs Option B (shift to interactive) per spec §6 D2 | `client_intelligence_reports_page.dart` migration |

D3 (glass token rounding) is a recommendation only — not a blocker.

---

## Recommended Fix Order

1. **[B1 — AUTO]** Add `accentSky = Color(0xFF8FD1FF)` to `OnyxColorTokens` in `lib/ui/theme/onyx_design_tokens.dart`. No behaviour change; pure token addition.

2. **[B2 — DECISION]** Zaks confirms D2 button pattern (Option A or B) for Reports before Codex begins that file.

3. **[Governance — AUTO]** Begin with Governance (`~674` violations, smallest after Admin, straightforward palette). Validates the migration process with low noise before the ~2,652-violation Admin file.

4. **[Dispatch — AUTO]** Dispatch next (~582 violations). The `_partnerProgressTone` resolver and `_DispatchFocusState` switches are well-specified in §3 of the spec.

5. **[Reports — AUTO after D2]** Reports after D2 is resolved (~563 violations). Spec §4 provides exact line-number guidance.

6. **[Tactical — AUTO]** Tactical (~559 violations). Two critical `Colors.white` blockers at lines 1366 and 1597; rest is straightforward spec §5.

7. **[Admin — AUTO/REVIEW]** Admin last (~2,652 violations). Largest file; `Color.alphaBlend` white-base patterns at lines 2839–2870 require care (spec §1 alphaBlend block). Recommend Zaks review the blended output once implemented.

8. **[Reference — AUTO]** After batch-1 is done, revisit `live_operations_page.dart` to complete Steps 2–7 (inline hex, `Colors.white`, GoogleFonts migration) for consistency.

---

## Overall Percentage Complete

| Scope | Done | Total | % |
|---|---|---|---|
| Token infrastructure (OnyxColorTokens/OnyxDesignTokens) | ✅ All tokens except `accentSky` | — | ~95% |
| Reference implementation (live_operations_page) | Step 1 of ~7 migration steps | — | ~15% |
| Batch-1 files (5 screens) | 0 of 5 files | — | **0%** |
| **Batch-1 overall** | **0** | **5 files** | **0%** |

The migration spec is well-formed and the token system is ready. The only infrastructure gap is the missing `accentSky` token. All batch-1 work is greenfield for Codex.
