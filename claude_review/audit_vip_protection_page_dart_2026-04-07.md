# Audit: lib/ui/vip_protection_page.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: lib/ui/vip_protection_page.dart + test/ui/vip_protection_page_widget_test.dart
- Read-only: yes

---

## Executive Summary

The file is well-structured for a pure UI widget — no application logic, clean data models, good use of `ValueKey` anchors, and a solid base test suite. Two concrete bugs exist: the `_VipEmptyState` always renders (creating contradictory on-screen messaging when scheduled details are present), and `_showVipScheduleDetailDialog` hardcodes badge colours, ignoring the `VipScheduledDetail`'s own badge colour fields. Several duplication candidates are repo-wide and flagged for centralisation. Test coverage is missing for the submit path and for badge-colour fidelity.

---

## What Looks Good

- All interactive widgets have stable `ValueKey` anchors — test hooks are clean throughout.
- `VipScheduledDetail` and `VipAutoAuditReceipt` are pure value objects (no logic, `const`-constructable) — easy to test and extend.
- `_vipKeySegment` (line 1169) produces stable, reproducible widget keys from detail titles.
- `ScaffoldMessenger.maybeOf` (line 397) is used correctly — no crash risk if the scaffold is absent.
- `LayoutBuilder` in `_VipScheduleCard` (line 882) correctly provides a compact/wide fact row split — good responsive pattern.
- Dialog controllers are never leaked on the happy path; the `try/finally` structure is intentional.

---

## Findings

### P1 — `_VipEmptyState` renders unconditionally, contradicting AMBER status

- **Action:** REVIEW
- **Finding:** `_VipEmptyState` is placed in the `Column` at line 179 with no guard, so it always renders regardless of whether `scheduledDetails` is non-empty. When details exist, the status strip correctly shows AMBER ("Prep the next package before wheels move"), but directly below it the empty state reads "No Live VIP Run — Board clear right now." The two messages contradict each other.
- **Why it matters:** Operators see conflicting situational cues. The empty state prompt ("Stage the next package") is also redundant when scheduled details already appear in the panel below.
- **Evidence:** `lib/ui/vip_protection_page.dart` lines 179–187 — no `if (scheduledDetails.isEmpty)` guard around `_VipEmptyState`.
- **Suggested follow-up for Codex:** Confirm whether `_VipEmptyState` is intentionally always shown (as a persistent CTA) or should only render when `scheduledDetails.isEmpty`. If the former, the copy needs updating; if the latter, wrap in `if (!hasScheduledDetails)`.

---

### P1 — `_showVipScheduleDetailDialog` hardcodes badge colours, ignores `detail` badge fields

- **Action:** AUTO
- **Finding:** The badge container inside `_showVipScheduleDetailDialog` (lines 1054–1072) always uses hardcoded cyan colours (`Color(0x1A22D3EE)`, `Color(0x5522D3EE)`, `Color(0xFF7DDCFF)`). `VipScheduledDetail` carries `badgeBackground`, `badgeForeground`, and `badgeBorder` precisely for this purpose, but they are ignored inside the dialog.
- **Why it matters:** The "Board Meeting Security" detail uses purple badge colours on the schedule card but renders cyan in its review dialog — colour discontinuity between card and dialog for every non-cyan detail.
- **Evidence:** `lib/ui/vip_protection_page.dart` lines 1054–1072 vs. lines 781–795 and 823–842 where the same `detail` badge fields are correctly used on the card.
- **Suggested follow-up for Codex:** Replace hardcoded colour literals in `_showVipScheduleDetailDialog` badge Container with `detail.badgeBackground`, `detail.badgeForeground`, `detail.badgeBorder`.

---

### P2 — `_showVipScheduleDetailDialog` fact label is always "Assignment detail"

- **Action:** AUTO
- **Finding:** `_VipDialogNote` is called with `label: 'Assignment detail'` for every fact (lines 1085–1092). All three facts in the CEO detail (schedule, officers, route) get the same label. `VipDetailFact` does not carry a label field, so this cannot be fixed without either adding one or using different labelling logic.
- **Why it matters:** The dialog collapses distinct fact types into a single generic label — reduces operator clarity in a handoff context.
- **Evidence:** `lib/ui/vip_protection_page.dart` lines 1085–1092.
- **Suggested follow-up for Codex:** Either add an optional `category` field to `VipDetailFact` or derive the label from the icon (e.g., `Icons.schedule_rounded` → "Time Window"). Codex to choose and validate against existing test data.

---

### P2 — `_VipScheduleCard` "YOU NEXT" badge ignores `detail.badgeLabel`

- **Action:** AUTO
- **Finding:** The small pill badge in the top-left of each schedule card (lines 786–793) always renders the hardcoded string `'YOU NEXT'`. The bottom-right time badge at lines 832–840 correctly uses `detail.badgeLabel` ("TOMORROW", "FRIDAY"). Two badges on the same card for the same detail use different label sources.
- **Why it matters:** If `badgeLabel` is meant to signal timing/status, having a parallel hardcoded label introduces inconsistency. For future details with different timing, "YOU NEXT" becomes misleading.
- **Evidence:** `lib/ui/vip_protection_page.dart` line 788 hardcoded vs. line 834 `detail.badgeLabel`.
- **Suggested follow-up for Codex:** Confirm whether "YOU NEXT" is an intentional fixed operational label or should reflect `detail.badgeLabel`. If fixed, it should be a named constant; if variable, replace with `detail.badgeLabel`.

---

### P2 — `TextEditingController.dispose` deferred unnecessarily via `addPostFrameCallback`

- **Action:** AUTO
- **Finding:** Inside `_showVipCreateDetailDialog` (lines 411–416), the three controllers are disposed via `WidgetsBinding.instance.addPostFrameCallback((_) { ... })`. Since `showDialog` is already `await`ed, the dialog is guaranteed to be closed before the `finally` block runs. The extra frame deferral is unnecessary indirection and could cause "already disposed" errors if anything else triggers a rebuild/route within that single frame gap.
- **Why it matters:** Low probability failure mode, but the simpler and safer pattern is direct synchronous disposal in `finally`.
- **Evidence:** `lib/ui/vip_protection_page.dart` lines 411–416.
- **Suggested follow-up for Codex:** Replace `addPostFrameCallback` wrapper with direct `.dispose()` calls in the `finally` block.

---

### P2 — Status strip is binary (GREEN/AMBER only), no RED/live state

- **Action:** DECISION
- **Finding:** `_VipStatusStrip` derives its state from a single `bool hasScheduledDetails` (lines 427–441). Real VIP protection scenarios need at minimum three states: GREEN (board clear), AMBER (packages queued), RED (movement currently live). The current model has no way to express an active run.
- **Why it matters:** If/when live run tracking is added, the strip will require a data model change. Locking the bool now means the strip cannot differentiate "packages queued" from "principal currently moving."
- **Evidence:** `lib/ui/vip_protection_page.dart` lines 427–441, `VipProtectionPage` constructor lines 58–72.
- **Suggested follow-up for Codex/Zaks:** Decide whether a `VipBoardStatus` enum (green/amber/red) should be added to `VipProtectionPage`'s API now or deferred until live-run tracking is implemented.

---

## Duplication

### "DO THIS NOW" action row — duplicated in `_VipEmptyState` and `_VipScheduleCard`

- `lib/ui/vip_protection_page.dart` lines 550–581 (`_VipEmptyState`) and lines 846–879 (`_VipScheduleCard`): both render a Container+Row with a coloured "DO THIS NOW" label on the left and an action descriptor on the right, with identical padding/decoration structure.
- This pattern also appears in 12 other UI files (confirmed: `ledger_page.dart`, `live_operations_page.dart`, `governance_page.dart`, `dispatch_page.dart`, and 8 others).
- **Centralisation candidate:** A shared `OnyxActionPromptRow` widget (or similar) in `onyx_surface.dart` or a dedicated `onyx_action_row.dart` could replace all instances. **This is a repo-wide concern, not just this file.**

### Pill badge Container+BoxDecoration pattern — 5 instances in this file alone

- Lines 132–151 (WAR ROOM label), 250–268 (`_VipAuditReceipt`), 776–795 (`_VipScheduleCard` YOU NEXT), 823–842 (`_VipScheduleCard` time badge), 1054–1072 (dialog badge).
- All share: `Container`, `padding: EdgeInsets.symmetric(horizontal: N, vertical: M)`, `BoxDecoration(borderRadius: BorderRadius.circular(999 or 9), border: Border.all(...))`, `Text(...)`.
- **Centralisation candidate:** A `_VipBadge` private widget (or shared `OnyxBadge`) taking `label`, `background`, `foreground`, `border` params.

---

## Coverage Gaps

1. **Submit path in create dialog is untested.** `test/ui/vip_protection_page_widget_test.dart` tests dialog open and cancel, but never taps "Stage Detail". The snackbar message (line 399) and the fallback strings for empty fields (lines 387–395) are uncovered.

2. **Status strip colour/state is untested.** No test verifies that `hasScheduledDetails = true` produces an AMBER strip or that `scheduledDetails = []` produces a GREEN strip. The contradiction bug (P1 above) would not be caught by current tests.

3. **Badge colour fidelity in review dialog is untested.** No test checks that the dialog badge uses `detail.badgeBackground` or `detail.badgeForeground`. The hardcoded colour bug (P1 above) cannot be caught by current tests.

4. **Only the first default card ("CEO Airport Escort") is exercised.** "Board Meeting Security" is never tapped in tests — the second card's dialog flow and its purple badge colours are untested.

5. **`latestAutoAuditReceipt = null` render is untested.** The audit receipt section is tested for the present-receipt case but the null case (panel should not appear) has no dedicated assertion.

6. **`onOpenLatestAudit = null` path untested.** When `latestAutoAuditReceipt` is provided but `onOpenLatestAudit` is null, the "View Audit" button should not render (line 289). No test covers this branch.

---

## Performance / Stability Notes

- `Color.lerp(_vipSurfaceColor, detail.badgeForeground, 0.08)` is called on every build of `_VipScheduleCard` (line 762–765). Since `badgeForeground` is a const field on a const-constructable data object, this computation could be memoised or moved to a static helper, though in practice the cost is negligible for a small list.
- `LayoutBuilder` nested inside each `_VipScheduleCard` (line 882) adds a build-path fork per card. With `defaultScheduledDetails` at 2 items this is harmless; if the list grows to 20+ cards it could accumulate constraint propagation overhead. No action needed now.
- `GoogleFonts.inter(...)` and `GoogleFonts.rajdhani(...)` are called as static functions on every build. These are cached by the `google_fonts` package internally — no performance concern, just a style observation.

---

## Recommended Fix Order

1. **Wrap `_VipEmptyState` in `if (!hasScheduledDetails)`** (or clarify intent) — eliminates contradictory operator messaging. Requires a product decision (REVIEW).
2. **Replace hardcoded badge colours in `_showVipScheduleDetailDialog`** with `detail.badgeBackground / badgeForeground / badgeBorder` — clear AUTO fix, adds colour correctness for all non-cyan details.
3. **Add test for "Stage Detail" submit path** — covers snackbar message and empty-field fallbacks; closes the most significant coverage gap.
4. **Add test for status strip state** — GREEN when empty, AMBER when details present; would have caught the always-visible empty state contradiction.
5. **Replace `addPostFrameCallback` with direct disposal in `finally`** — small hygiene fix, AUTO.
6. **Resolve "YOU NEXT" vs `detail.badgeLabel`** — needs a product clarification (DECISION) on whether the pill label is fixed or per-detail.
7. **`VipBoardStatus` enum** — DECISION for Zaks; defer until live-run tracking requirements are clearer.
8. **Centralise "DO THIS NOW" row and pill badge** — repo-wide refactor candidate; low urgency, high long-term payoff.
