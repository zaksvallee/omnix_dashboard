# Audit: sovereign_ledger_page.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/ui/sovereign_ledger_page.dart`
- Read-only: yes

---

## Executive Summary

The file is a single-file occurrence-book UI (~3,978 lines) that combines presentation, view-model shaping, chain integrity, manual entry composition, and payload routing in one `StatefulWidget`. The domain mapping helpers (`_buildObEntries`, `_payloadForEvent`, `_titleForEvent`, `_descriptionForEvent`, etc.) are pure free functions but are embedded in the UI file with no test surface. Three concrete bugs stand out: a side-effect in `build()` that silently mutates `_selectedEntryId` without `setState`, `runtimeType.toString()` used as a stable audit type key (breaks under Flutter obfuscation), and a partial-chain integrity check wired to the global `_ChainIntegrity` indicator. The duplicate two-column/single-column composer layout blocks are the biggest maintenance risk. Test coverage for the pure mapping and chain functions is entirely absent.

---

## What Looks Good

- All five `TextEditingController` instances are properly declared `late final` and disposed in `dispose()` (lines 145–186). No leaks.
- `_buildObEntries` produces a deterministic chain by processing events in ascending `sequence` order and threading `previousHash` forward — the contract is clear and locally correct.
- `ScaffoldMessenger.maybeOf(context)` is used (line 2885) rather than the throwing variant, so snackbars degrade gracefully when the widget is removed from tree.
- `_resolveSelectedEntryId` guards against empty entry lists before indexing (lines 3786–3819).
- `_verifyChain` correctly implements hash linkage verification for the descending sort order used internally.
- `_matchesSearch` concatenates all searchable fields before a single `.contains` — efficient and consistent.
- `EvidenceCertificateExportService.chainedPayloadHash` is delegated to the application layer; hashing is not re-implemented here.

---

## Findings

### P1 — Side-effect mutation of `_selectedEntryId` inside `build()`

- **Action:** REVIEW
- `_selectedEntryId = _resolveSelectedEntryId(...)` is called directly inside `build()` at line 222, assigning to the instance field without going through `setState`.
- **Why it matters:** Mutating state in `build()` is a Flutter contract violation. The framework calls `build()` in contexts where it does not expect side-effects (hot reload, layout pass, widget inspector). If the mutation causes a semantic change mid-frame, it will not trigger a follow-up rebuild, leaving the visual tree inconsistent with `_selectedEntryId`. Testing this widget is harder because `build()` is impure.
- **Evidence:** `sovereign_ledger_page.dart:222` — `_selectedEntryId = _resolveSelectedEntryId(...)`.
- **Suggested follow-up:** Codex should validate whether moving this assignment into a `didUpdateWidget` / `didChangeDependencies` override (or an `initState` guard keyed on `widget.initialFocusReference`) preserves correct behaviour.

---

### P1 — `_desktopWorkspaceActive` mutated inside `build()`

- **Action:** REVIEW
- `_desktopWorkspaceActive = dualColumnLayout;` at line 249 modifies instance state inside `build()`.
- **Why it matters:** `_desktopWorkspaceActive` controls which feedback surface is shown in `_showActionMessage` (line 2874). If a user triggers an action callback between two `build()` invocations with different layout widths, the last-written value may be stale, routing the feedback to the wrong surface (snackbar vs. command receipt).
- **Evidence:** `sovereign_ledger_page.dart:249` and `sovereign_ledger_page.dart:2874`.
- **Suggested follow-up:** Codex should validate whether deriving `dualColumnLayout` from a `LayoutBuilder` callback and passing it down to `_showActionMessage` directly (or using a `ValueNotifier`) eliminates the race window.

---

### P1 — `runtimeType.toString()` used as stable audit type key

- **Action:** REVIEW
- `_payloadForEvent` sets `payload['type'] = event.runtimeType.toString()` at line 3329.
- **Why it matters:** Flutter compiles production builds with tree shaking and can obfuscate class names (`--obfuscate` flag). When obfuscation is active, `event.runtimeType.toString()` returns a mangled name (`A`, `B1`, etc.), not `IntelligenceReceived`. The state selectors that drive action buttons — `_dispatchAuditIncidentReferenceForSelected`, `_liveOpsAuditIncidentReferenceForSelected`, `_riskIntelAuditActionForSelected`, etc. — all match against literal string values like `'dispatch_auto_audit'`. These come from a different path (the auto-audit payload `type` field injected by other services, not `runtimeType.toString()`). However, the `_payloadForEvent` type key ends up in exported JSON and in `_entryToJson`. If any downstream consumer or test relies on this key, it will silently break in an obfuscated release build. The inconsistency between the auto-audit `type` convention and the `runtimeType.toString()` convention also means the same `payload['type']` key carries semantically different data depending on entry origin.
- **Evidence:** `sovereign_ledger_page.dart:3329`.
- **Suggested follow-up:** Codex should validate whether a private enum or sealed class constant should replace `runtimeType.toString()` as the exported type key.

---

### P2 — Hero-panel integrity check operates on a partial chain

- **Action:** REVIEW
- The `Check Chain` button in the hero panel (line 445–451) invokes `_runIntegrityCheck` with either `[..._manualEntries, selected]` or `[selected]` — never the full ledger.
- **Why it matters:** `_runIntegrityCheck` sets the global `_ChainIntegrity` state indicator that appears in both the hero banner and the detail panel status banner. A partial check reporting `INTACT` on two manually-added entries while the rest of the chain is corrupt will display a false `INTACT` badge across the entire page. The detail-panel `Check Chain` button (line 1202) passes the full `allEntries` list correctly; the hero-panel button does not.
- **Evidence:** `sovereign_ledger_page.dart:445–451` vs `sovereign_ledger_page.dart:1202`.
- **Suggested follow-up:** Codex should validate whether the hero-panel button should also pass `allEntries` (requires threading it down to `_buildHeroPanel`) or should be removed in favour of the detail-panel button.

---

### P2 — `_categoryForEvent` uses keyword heuristic on intelligence narrative

- **Action:** REVIEW
- For `IntelligenceReceived` events, category assignment scans `event.headline + event.summary` for words like `vehicle`, `alarm`, `breach`, `movement` (lines 3508–3519).
- **Why it matters:** Any AI-generated narrative containing those words as context (e.g. "no alarm activity observed") will be mis-categorised. The heuristic is not tested. Miscategorisation affects filter chips, entry card colours, and `incident`/`flagged` flags.
- **Evidence:** `sovereign_ledger_page.dart:3508–3519`.
- **Suggested follow-up:** Codex should check whether `IntelligenceReceived` carries a structured `category` or `eventType` field that could replace the heuristic.

---

### P2 — `_nextSequence` hardcoded seed tied to fallback data

- **Action:** AUTO
- `_nextSequence` and `_nextRecordNumber` both seed their `maxSequence` / `maxRecordNumber` floor at `2441` (lines 3843, 3853) — the sequence of the first fallback entry.
- **Why it matters:** If the live ledger contains only events with sequence numbers below `2441`, the next manual entry will silently skip to `2442` regardless, creating an artificial gap. If fallback entry sequences change in future, the seed silently shifts. The dependency is undocumented.
- **Evidence:** `sovereign_ledger_page.dart:3843,3853`.
- **Suggested follow-up:** Codex should validate whether the seed should be `0` (returning the actual max + 1) or whether it should derive from `widget.events.isNotEmpty ? widget.events.map((e) => e.sequence).reduce(max) + 1 : 1`.

---

### P3 — `_composerOpen` timestamp frozen at open-time

- **Action:** AUTO
- `_draftOccurredAt` is set to `DateTime.now().toUtc()` when the composer opens (`_openComposer`, line 2689) but is never refreshed until `_resetDraft` is called on submission or cancel. If a controller leaves the composer open for an extended period (common on a busy shift), the submitted entry will carry a stale timestamp.
- **Evidence:** `sovereign_ledger_page.dart:2689` and `sovereign_ledger_page.dart:2701`.
- **Suggested follow-up:** Codex should validate whether `_draftOccurredAt` should update on submit (capture real submission time rather than compose-open time).

---

## Duplication

### Composer two-column / single-column layout tripled

- The same four form sections (guard quick-select + site, guard name + callsign, category + occurred-at, and the label+field pattern itself) each have two near-identical branches for `twoColumn` and narrow layouts inside `_buildComposerPanel` (lines 567–762).
- Affected region: `sovereign_ledger_page.dart:567–762` (≈195 lines of duplicated widget trees).
- All six blocks share the same `_buildDropdownField` / `_buildTextField` calls with only the wrapping `Row` vs sequential `Column` differing.
- **Centralisation candidate:** A helper that accepts a `List<Widget>` children and a `bool twoColumn` flag and emits either a `Row` of `Expanded` children or a `Column` with `SizedBox(height:14)` separators would collapse this to a single declaration per field group.

### Button theme for contextual action buttons repeated inline

- Each contextual action button in `_buildRecordView` (lines 1370–1699) specifies `_primaryButtonStyle(backgroundColor: …, foregroundColor: …)` with hardcoded colour pairs. There are 15+ such buttons.
- The same colour pairs appear for equivalent action types in both `dispatch_auto_audit` and `live_ops_auto_audit` branches (e.g. CCTV Review uses `0xFF14301F / 0xFF6EE7B7` at lines 1497 and 1622).
- **Centralisation candidate:** Named action-type style constants or a single `_actionButtonStyle(String actionType)` lookup would eliminate the per-button colour literals.

### `_eventClientId` and `_eventSiteId` pattern-match the same exhaustive event type list

- Both functions repeat the same 11-branch `if (event is X) return event.fieldY` pattern (lines 3638–3666).
- **Centralisation candidate:** If `DispatchEvent` exposes `clientId` and `siteId` as abstract fields on the base class, both functions collapse to a single property access.

---

## Coverage Gaps

- **No test file found for this page.** The following pure functions have zero test coverage:
  - `_buildObEntries` — chain building, clientId/siteId filtering, sceneReview attachment
  - `_verifyChain` — hash linkage verification
  - `_categoryForEvent` — keyword heuristic classification
  - `_resolveSelectedEntryId` — focus-reference matching and fallback logic
  - `_nextSequence` / `_nextRecordNumber` — manual entry ID generation
  - `_manualEntryTitle` — title truncation
  - `_matchesSearch` — search predicate
  - `_payloadForEvent` — audit payload shape per event type

- **Untested failure case — `_verifyChain` with mixed manual + generated entries:** Manual entries set `previousHash = currentEntries.first.hash` (line 2733), making them chain off the top of the sorted descending list. If mixed with generated entries whose chain was built ascending, the full-list `_verifyChain` will almost certainly report `compromised` for any ledger that has both manual and generated entries. This is likely a false positive — needs explicit test coverage to confirm.

- **Untested: `_buildComposerPanel` submit path with empty `guardPresets`:** `_resolvePresetByKey` falls back to `_defaultGuardPresets.first` when `presets` is empty (line 3761), but `_resetDraft` also falls back via `_defaultGuardPresets` (line 3695). The interaction when a live ledger has no guard data has no test.

- **No widget test for entry card selection:** Tapping an entry card sets `_selectedEntryId` and `_workspaceView` — this is the primary interaction path and is untested.

- **No widget test for `_buildDetailPanel` action button visibility:** The 15+ conditional buttons derive from payload-key inspection; none of these conditions is tested at the widget level.

---

## Performance / Stability Notes

### `_buildObEntries`, `_buildGuardPresets`, `_buildSiteOptions` called every `build()`

- All three run on the full `widget.events` list every time the widget rebuilds (lines 193–211). For a controller with 500+ events during a shift, every `setState` (including each keypress in the search field) triggers a full O(n) rebuild of the entry list plus two O(n) scans for presets and sites.
- `_buildObEntries` also recomputes the entire hash chain from scratch each call (one `chainedPayloadHash` call per event).
- **Risk:** Jank on large event lists when typing in the search field.
- **Suggested follow-up:** Codex should validate whether `_buildObEntries` output can be memoised behind a `widget.events` identity/length check, deferring recomputation only when the event list changes.

### `_matchesSearch` builds a concatenated haystack string on every filter pass

- For a 500-entry ledger with a live search query, `_matchesSearch` joins 8 fields per entry into one string per `where` pass (line 3773). This runs after every character typed.
- **Risk:** Mild but measurable on low-end devices with large ledgers.

### `_relatedEntriesForSelected` scans all entries on every `build()`

- `_relatedEntriesForSelected` iterates the full entry list each time the detail panel renders (line 3705). It does a string equality check on `siteLabel` and `guardLabel`. At 500+ entries this is O(n) per frame with the detail panel open.
- **Risk:** Low at typical shift sizes; worth noting for completeness.

---

## Recommended Fix Order

1. **Side-effect in `build()` — `_selectedEntryId` and `_desktopWorkspaceActive`** (P1): Highest correctness risk. Move both assignments out of `build()`. Should be a clean lift into `didUpdateWidget` / `LayoutBuilder` callback.
2. **`runtimeType.toString()` as type key** (P1): Real obfuscation risk. Replace with a stable string constant per event type.
3. **Hero-panel partial chain check** (P1): One-line fix — pass the full entry list to the hero-panel integrity check or remove the button.
4. **Memoize `_buildObEntries`** (Performance): Eliminates per-keystroke chain recomputation. Straightforward cache keyed on `widget.events` length + last sequence.
5. **`_nextSequence` hardcoded seed** (P2/AUTO): Replace `2441` floor with `0` and let the actual max dominate.
6. **`_draftOccurredAt` frozen timestamp** (P3/AUTO): Set on submit rather than on composer open.
7. **Add unit tests for pure mapping functions**: `_buildObEntries`, `_verifyChain`, `_categoryForEvent`, `_resolveSelectedEntryId`, `_nextSequence`. These are already free functions — no widget harness needed.
8. **Composer duplication** (Structural): Extract a `_twoColumnOrStack` layout helper to collapse the 195-line duplicated composer layout.
