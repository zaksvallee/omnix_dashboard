# Audit: lib/ui/vip_protection_page.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/ui/vip_protection_page.dart`, `test/ui/vip_protection_page_widget_test.dart`
- Read-only: yes

---

## Executive Summary

Solid pure-UI page. No live state, no async work, no service calls — all data flows in through constructor parameters, and routing is cleanly delegated to `onyx_route_operations_builders.dart`. The widget key discipline is good and the test suite covers the major happy paths.

Three issues warrant priority attention: a stale `context` capture in the create-detail dialog, a duplicate badge block inside `_VipScheduleCard`, and a status-strip logic that is easy to misread (AMBER when details exist, GREEN when empty). The file is also 1 192 lines — borderline for a single-file widget file, but not critical yet.

---

## What Looks Good

- Clean data-in / callback-out interface on `VipProtectionPage` — no hidden state dependencies.
- `TextEditingController` disposal is guarded by `try/finally` in `_showVipCreateDetailDialog` (line 434-438).
- `ValueKey` coverage on every interactive widget — makes widget tests stable.
- `_vipKeySegment` helper (line 1190) is correctly used for card keys and matches what tests assert.
- `ScaffoldMessenger.maybeOf(context)` (line 420) avoids a hard crash if no scaffold ancestor exists.
- `LayoutBuilder` adaptive layout in `_VipScheduleCard` (line 903) correctly collapses facts to a column on narrow widths.

---

## Findings

### P1 — Stale outer `context` captured in dialog submit handler

- **Action:** REVIEW
- **Finding:** `_showVipCreateDetailDialog` is a free function called from `VipProtectionPage.build`. The `showDialog` builder closure captures `context` from the outer `build` call (line 353, 420). After the dialog is shown, if the calling page is removed from the tree (e.g., rapid navigation), the captured `context` is stale at the moment the "Stage Detail" submit button calls `ScaffoldMessenger.maybeOf(context)?.showSnackBar(...)`.
- **Why it matters:** `maybeOf` masks the null case, so no crash — but the snackbar silently does nothing. Worse, accessing `.maybeOf` on an unmounted `BuildContext` can trigger framework assertions in debug mode.
- **Evidence:** `lib/ui/vip_protection_page.dart` lines 346-438; capture at line 353 (`builder: (dialogContext) { ... }`), use at line 420 (`ScaffoldMessenger.maybeOf(context)`).
- **Follow-up for Codex:** Verify by navigating away mid-dialog submit in debug mode and checking for framework errors. Fix is to use `dialogContext` (already in scope) or convert the function to a method on the widget and use a `mounted` guard.

---

### P1 — Status strip semantics are inverted relative to natural reading

- **Action:** REVIEW
- **Finding:** `_VipStatusStrip` shows **AMBER** when `hasScheduledDetails == true` and **GREEN** when `hasScheduledDetails == false` (lines 448-462). Operationally this is intentional: AMBER means "upcoming work, act now"; GREEN means "board clear." But the variable name `hasScheduledDetails` reads as a positive signal, making the branch appear inverted on first read.
- **Why it matters:** Any future maintainer branching on this logic is likely to read `hasScheduledDetails → GREEN` and reverse the colors, introducing a silent UX regression.
- **Evidence:** `lib/ui/vip_protection_page.dart` lines 448-462; the `true` branch yields `'AMBER'`.
- **Follow-up for Codex:** No test currently asserts the AMBER/GREEN text based on scheduled detail presence. Add a widget test that pins both states.

---

### P2 — `detail.badgeLabel` rendered twice inside `_VipScheduleCard`

- **Action:** AUTO
- **Finding:** Within the card's top `Row`, `detail.badgeLabel` appears in a pill badge at top-left (lines 795-813) and again in a rounded-rect badge at top-right (lines 842-860). Both are visible simultaneously and carry the same value (e.g. "TOMORROW").
- **Why it matters:** Duplicate labels clutter the card and will confuse operators in the field. If the label ever diverges (e.g., one block is updated but not the other), it causes an inconsistent display.
- **Evidence:** `lib/ui/vip_protection_page.dart` lines 795-860.
- **Follow-up for Codex:** Determine which badge position is the canonical one and remove the other. The pill badge (top-left, line 795) appears again inside the dialog via a matching block, so that form is more consistent with the dialog pattern.

---

### P2 — `_VipDetailFact.title` field is defined but silently dropped in card view

- **Action:** REVIEW
- **Finding:** `VipDetailFact` has a `title` field (e.g., "Time window", "Detail team"), but `_VipScheduleFactTile.build` (lines 965-988) only renders `fact.label` and `fact.icon`. `fact.title` is used only in `_VipDialogNote` inside the detail dialog. The model carries a field that half the renderers ignore.
- **Why it matters:** The `title` field is a public API surface of a data class. A caller adding a `VipDetailFact` with a carefully crafted title will see it silently swallowed in the card. No compiler warning.
- **Evidence:** `lib/ui/vip_protection_page.dart` lines 15-25 (model), lines 965-988 (`_VipScheduleFactTile`).
- **Follow-up for Codex:** Either render `fact.title` in `_VipScheduleFactTile` as a sublabel, or split the model into a card-only variant and a dialog-only variant to make the API contract explicit.

---

### P3 — Free-function dialogs cannot be unit tested in isolation

- **Action:** DECISION
- **Finding:** `_showVipCreateDetailDialog` and `_showVipScheduleDetailDialog` are private free functions (lines 346, 1032). They cannot be tested by name, mocked, or overridden. Tests must always go through the full page → button tap → dialog path.
- **Why it matters:** If the create-detail form gains validation or async submission, testing it will require standing up the entire `VipProtectionPage` scaffold each time.
- **Evidence:** `lib/ui/vip_protection_page.dart` lines 346 and 1032.
- **Follow-up for Codex:** Decision needed: keep as-is (acceptable for simple dialogs) or extract to named widget classes so they can be pumped and tested independently.

---

## Duplication

### 1. Badge container block — 3 instances

The same badge-rendering logic (`badgeBackground`, `badgeBorder`, `badgeForeground`, `badgeLabel`) is copy-pasted three times:

- `_VipScheduleCard` top-left pill (lines 795-813)
- `_VipScheduleCard` top-right box (lines 842-860)
- `_showVipScheduleDetailDialog` badge (lines 1075-1094)

A `_VipBadge` widget accepting `label`, `background`, `foreground`, `border`, and `shape` (pill vs rect) would eliminate all three. P2 duplicate-badge fix above would reduce this to two canonical sites.

### 2. "DO THIS NOW" action-strip block — 2 instances

A `Container` with two `Text` children ("DO THIS NOW" left, action label right) appears in:

- `_VipEmptyState` (lines 571-601)
- `_VipScheduleCard` (lines 865-901)

The structure is identical; only the action label string and foreground color differ. A `_VipActionStrip(actionLabel, foregroundColor)` widget would centralize this.

### 3. `BoxShadow` constant — 2 instances

`BoxShadow(color: Color(0x120F172A), blurRadius: 18, offset: Offset(0, 8))` appears in `_VipEmptyState` (line 525-529) and `_VipScheduledPanel` (line 685-689). Could be a file-level constant.

---

## Coverage Gaps

| Gap | Severity |
|-----|----------|
| No test asserts AMBER status text when `scheduledDetails` is non-empty | Medium — status strip logic is easy to accidentally invert |
| No test asserts GREEN status text when `scheduledDetails` is empty | Medium — same reason |
| No test covers "Stage Detail" submit path in create-detail dialog (snackbar shown, controllers cleared) | Medium — submit is the primary action of the dialog |
| No test covers `latestAutoAuditReceipt == null` → panel is absent | Low — easy to regress silently |
| No test covers the "OPEN PACKAGE DESK" (not button, the static action-strip row) renders in empty state | Low |
| No test locks that `_VipScheduleFactTile` renders `fact.label` but NOT `fact.title` in card view | Low — documents the intentional omission |
| No compact-layout test for `_VipScheduleCard` fact row (LayoutBuilder compact branch at line 909) | Low |

---

## Performance / Stability Notes

- **`Color.lerp(...)` in `_VipScheduleCard.build` (line 783):** Called every rebuild for every card. For a short list this is negligible, but it is unnecessary work on a pure layout rebuild. Extract to a helper or cache in a `late final`.

- **`LayoutBuilder` per card (line 903):** Each `_VipScheduleCard` has its own `LayoutBuilder`. For the current two-card default this is fine, but if the list grows (e.g., paginated VIP runs), each card independently queries layout. Consider passing a pre-computed `compact` bool from `_VipScheduledPanel` which already owns the outer `LayoutBuilder` context at the page level.

- **`GoogleFonts.inter(...)` per text widget (throughout):** `google_fonts` caches fonts internally, but the style object is reconstructed on every build call. No critical path concern at this scale, but if the page ever scrolls a large list, consider extracting styles to `static const` `TextStyle` fields using `TextStyle(fontFamily: 'Inter', ...)` after the font is registered.

---

## Recommended Fix Order

1. **Stale context in dialog submit** (P1) — verify with debug navigation then fix scope of `context` or add mounted guard.
2. **Add AMBER/GREEN status strip widget tests** — locks the inverted-logic intent before a maintainer reverses it.
3. **Remove duplicate `badgeLabel` block in `_VipScheduleCard`** (P2, AUTO) — clear visual regression, safe mechanical delete.
4. **Clarify `VipDetailFact.title` rendering contract** (P2) — either render in card or split model.
5. **Extract `_VipActionStrip` and `_VipBadge`** — centralize duplication before the dialog or card grows further.
6. **Add Stage Detail submit test** — covers the only untested interactive path in the file.
