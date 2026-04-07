# Audit: risk_intelligence_page.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/ui/risk_intelligence_page.dart`
- Read-only: yes

---

## Executive Summary

The file is a self-contained, purely presentational UI page with no async calls, no state, and no service dependencies. Structure is clean and widget decomposition is reasonable. There are no critical bugs. The main risks are: static hardcoded demo data living in `defaultAreas` / `defaultRecentItems`, a dead branch in `actionLabel`, a key collision bug in dialog keys when two feed items share the same `sourceLabel`, and a growing volume of inline `BoxDecoration` / `GoogleFonts.inter` calls that are not yet causing perf problems but will resist theming. Coverage is zero — no test file exists for this page.

---

## What Looks Good

- Clean `StatelessWidget` hierarchy: page → panel → card → dialog. No domain logic leaking into widget state.
- `_highestPriorityArea` sorting logic is correct and deterministic (level rank first, signal count second). Corner case of empty `withSignals` is handled.
- `_IntelDialogFrame` is a well-extracted reusable shell; all three dialog call sites use it consistently.
- `ValueKey` identifiers are present on interactive widgets, which aids widget tests.
- `_riskIntelLevelRank` and `_intelKeySegment` are file-private helpers with no side effects — easy to test independently.

---

## Findings

### P1 — Dialog key collision when two feed items share `sourceLabel`

- **Action:** AUTO
- **Finding:** `_showRecentIntelDialog` generates the `dialogKey` from `_intelKeySegment(item.sourceLabel)` (line 267). If two `RiskIntelFeedItem` entries share the same `sourceLabel` (e.g., two `TWITTER` items), their dialogs receive the same `ValueKey`, causing Flutter to reuse widget state incorrectly.
- **Why it matters:** In production, the feed will contain real data where duplicate sources are common. Flutter will silently reuse the wrong widget tree.
- **Evidence:** `lib/ui/risk_intelligence_page.dart` lines 266–268
- **Suggested follow-up:** Switch the key to `item.id`, which is already unique per item: `ValueKey('intel-detail-${item.id}-dialog')`.

---

### P1 — `actionLabel` dead branch — both arms are identical

- **Action:** AUTO
- **Finding:** Lines 713–715 compute `actionLabel` as a conditional but both the `showArea` and the `else` arm return the same string `'OPEN EVENTS SCOPE'`. The conditional is dead code.
- **Why it matters:** It implies the original intent was to have a distinct label for the fallback case (e.g., `'VIEW INTEL ITEM'`). If that was intentional the branch should be removed; if it was accidental the else label is wrong and the wrong CTA is shown when `priorityArea` is null.
- **Evidence:** `lib/ui/risk_intelligence_page.dart` lines 713–715
- **Suggested follow-up:** Decide intended label for the non-area case (e.g., `'VIEW INTEL ITEM'`) and correct or collapse.

---

### P2 — `_IntelItemCard` button label hardcoded to `'OPEN EVENTS SCOPE'` regardless of item context

- **Action:** REVIEW
- **Finding:** The button in `_IntelItemCard` (line 1262) always reads `'OPEN EVENTS SCOPE'` regardless of whether the item has an associated `eventId`. For items without an event, the label is misleading — the tap resolves to a detail dialog, not an events scope view.
- **Why it matters:** Operator confusion. The button text promises a navigation action that may not happen.
- **Evidence:** `lib/ui/risk_intelligence_page.dart` lines 1240–1263; `RiskIntelFeedItem.eventId` field at line 57 is nullable and unused in the card.
- **Suggested follow-up:** Use `item.eventId != null ? 'OPEN EVENTS SCOPE' : 'VIEW DETAILS'` as the label.

---

### P2 — `defaultAreas` and `defaultRecentItems` are hardcoded demo data baked into the widget class

- **Action:** DECISION
- **Finding:** `RiskIntelligencePage.defaultAreas` (lines 116–141) and `defaultRecentItems` (lines 143–175) are `static const` fields on the widget. All four area entries have `signalCount = 0`, making `_highestPriorityArea` always return `null` in the default state. The priority panel will always render the fallback path in any demo context that doesn't override the defaults.
- **Why it matters:** If the page is ever mounted without explicit data (e.g., during a demo, a loading state, or a test), it silently shows the fallback/empty state rather than raising an error. There is also no mechanism to distinguish "data not yet loaded" from "no signals present."
- **Evidence:** Lines 116–175; `_highestPriorityArea` call at line 298 returns `null` with defaults.
- **Suggested follow-up:** Decide: (a) replace defaults with a nullable/loading state model, or (b) ensure the calling layer always provides real data and remove the defaults.

---

### P3 — `_showAreaIntelDialog` operating guidance only checks `LOW` / not-`LOW`

- **Action:** AUTO
- **Finding:** Line 244 branches on `area.level == 'LOW'` to select operating guidance. MEDIUM, HIGH, and CRITICAL all receive the same elevated-monitoring message. There is no differentiation between a MEDIUM and a CRITICAL area posture.
- **Why it matters:** Operators receive identical guidance for a MEDIUM and a CRITICAL area, which defeats the purpose of the risk level system.
- **Evidence:** `lib/ui/risk_intelligence_page.dart` lines 243–248
- **Suggested follow-up:** Expand to a switch on `area.level` matching the same cases used in `_riskIntelLevelRank`.

---

### P3 — `_IntelStatusStrip` uses positional record fields ($1–$5), not named

- **Action:** REVIEW
- **Finding:** The `status` record at lines 619–641 uses anonymous positional fields accessed as `status.$1` through `status.$5`. This is fragile — reordering the tuple members will silently produce wrong colours or text with no compiler error.
- **Why it matters:** Low risk today; becomes a bug magnet when the strip is extended.
- **Evidence:** Lines 619–682
- **Suggested follow-up:** Convert to a named record type or a small private data class.

---

## Duplication

### 1. Panel header block repeated in `_IntelAreaPanel` and `_IntelRecentPanel`

Both panels build an identical `Container` header: full-width, `fromLTRB(18, 16, 18, 16)` padding, bottom border, icon + label Row. The only differences are the icon and label string.
- **Files:** Lines 859–884 (`_IntelAreaPanel`) and lines 1087–1112 (`_IntelRecentPanel`)
- **Centralization candidate:** Extract a `_IntelPanelHeader({required IconData icon, required Color iconColor, required String label})` private widget.

### 2. Callback dispatch pattern repeated three times in `build`

The onAddManualIntel, onViewAreaIntel, and onViewRecentIntel callbacks all follow the same `if (callback != null) { callback!(); return; } _showFallbackDialog(context)` pattern. This pattern is copy-pasted into both the single-column and two-column layout arms (lines 401–415, 436–450, 457–465, 419–426).
- **Centralization candidate:** Extract helper methods `_handleAddManualIntel(BuildContext)`, `_handleViewAreaIntel(BuildContext, area)`, `_handleViewRecentIntel(BuildContext, item)` and call them from both layout arms.

### 3. Pill/badge `Container` decoration repeated across cards and dialogs

The small rounded pill badge (`borderRadius: BorderRadius.circular(999)`, translucent background from `accent.withValues(alpha: 0.14)`) appears at lines 540–556, 949–964, 1171–1189. These are visually identical constructs.
- **Centralization candidate:** A private `_IntelBadge({required String label, required Color accent})` widget.

---

## Coverage Gaps

1. **No test file exists** for `RiskIntelligencePage`. Grep for `risk_intelligence_page` in `/test/` returns nothing.
2. **`_riskIntelLevelRank` is untested.** The ranking function is the core logic for priority ordering. The default-unknown case (`return 0`) is a silent fallback that is easy to trigger with a typo in level strings from real data.
3. **`_highestPriorityArea` is untested.** Tie-breaking by `signalCount`, the empty-list path, and the single-area path are all unexercised.
4. **Dialog key collision** (P1 above) has no regression test locking the uniqueness of dialog keys.
5. **No golden or smoke test** for the single-column vs two-column layout switch at the 1280px breakpoint.
6. **`_IntelStatusStrip` rank-to-status mapping** (RED / AMBER / GREEN) is untested. The `>= 3` pattern-match arm could silently stop matching if the record or switch is refactored.

---

## Performance / Stability Notes

1. **`GoogleFonts.inter(...)` called on every build of every text widget.** `google_fonts` caches font data but creates a new `TextStyle` object each call. With 20+ `Text` widgets per page, this is a measurable allocation on every rebuild. Declaring `static const` `TextStyle` constants at file scope (or using a shared theme) eliminates this. Low urgency today since the page is mostly static, but will compound once live data triggers rebuilds.

2. **`Color.lerp` called in `_IntelAreaCard.build` and `_IntelPriorityPanel.build` per card.** `Color.lerp` is fast but is called during `build`, which runs on every layout pass. With many area cards this is redundant work. The computed background colour could be cached in the data model or computed once at list-construction time.

3. **`_highestPriorityArea` sorts the full list on every `build`.** The parent `build` is called on every layout pass. The sort is `O(n log n)` and creates two intermediate lists (the `where` result and the `.toList()` copy). With a small `areas` list this is negligible, but the method should be documented or moved to a `StatefulWidget` / provider if the list grows.

---

## Recommended Fix Order

1. **(P1) Fix dialog key collision** — swap `sourceLabel` slug for `item.id` in `_showRecentIntelDialog`. Zero ambiguity, no product decision needed.
2. **(P1) Resolve dead `actionLabel` branch** — decide correct fallback label and remove the duplicate arm.
3. **(Coverage) Add a widget test file** for `RiskIntelligencePage` covering: default render, single-column/two-column breakpoint, priority panel fallback when all `signalCount == 0`, and dialog open paths.
4. **(Coverage) Unit-test `_riskIntelLevelRank` and `_highestPriorityArea`** directly — both are pure functions, trivial to extract and test.
5. **(P2) Fix `_IntelItemCard` button label** to reflect whether an `eventId` is present.
6. **(P2) Decide on default data strategy** — loading state vs. always-provided data.
7. **(P3) Expand area dialog guidance** to all four risk levels.
8. **(Duplication) Extract panel header and badge widgets** once tests exist to guard against regressions.
