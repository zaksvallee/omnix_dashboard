# Audit: onyx_telegram_operational_command_service.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/application/onyx_telegram_operational_command_service.dart`
- Read-only: yes

---

## Executive Summary

This is a large, structurally coherent service (~3,370 lines) that handles Telegram conversational triage for security operations clients. The domain logic is well-contained — no UI coupling, no persistence side effects, no async code — which makes it easy to reason about and test. The test file (6,182 lines) provides broad coverage of the happy-path conversational matrix.

The main risks are:
1. A confirmed regex bug that silently breaks whitespace normalization in a label-formatting path.
2. Three independent but structurally identical calm-check branches that repeat the same `latestOpenDecision` guard pattern with near-identical text, creating a maintenance trap.
3. A midnight-crossover gap in clock-time fuzzy matching that can silently miss valid events.
4. Several double-lookup patterns that compute the same value twice in the same method.
5. A thin wrapper method with no real purpose.

---

## What Looks Good

- **Pure synchronous service.** No async, no futures, no I/O. Every response path is a pure function of input. This is the right design for a conversational safety-response layer.
- **Explicit authority check at entry.** The `gateway.route` call at line 38–46 short-circuits the entire method on denial. Authority cannot be bypassed by any internal path.
- **Trim discipline.** `.trim()` is consistently applied at every access to user-supplied strings (`guardId`, `dispatchId`, `clientId`, `siteId`). No invisible-whitespace bugs.
- **`_truthSnapshotForRequest` as a coherent state unit.** Sorting and unresolved-decision computation are centralized here rather than scattered. Most response methods use it correctly.
- **Prompt normalization strategy is grounded.** The typo replacement table at lines 1833–1869 is domain-relevant and clearly sourced from real usage patterns.
- **`_eventsForRequest` security filter is tight.** The three-layer check (allowed clients, allowed sites, requested scope) prevents scope leakage across groups.

---

## Findings

### P1 — Confirmed Bug

**`_humanizeScopeLabel` whitespace deduplication regex never fires**

- Action: `AUTO`
- Finding: Line 1755 uses `RegExp(r'\\s+')` in a raw Dart string. In a raw string, `\\s` is the literal two-character sequence backslash-s, not the `\s` whitespace class. The `replaceAll` call matches nothing in normal text. Whitespace deduplication after token splitting is silently skipped.
- Why it matters: Site/client IDs that contain multiple consecutive spaces or tabs (e.g. from slugified external IDs) will produce malformed display labels like `"Front  Gate"` sent to live clients via Telegram.
- Evidence: `lib/application/onyx_telegram_operational_command_service.dart:1755`
  ```dart
  .replaceAll(RegExp(r'\\s+'), ' ')
  ```
  The fix is `RegExp(r'\s+')` (single backslash in a non-raw string or escaped correctly).
- Suggested follow-up for Codex: Search for any other `RegExp(r'\\` patterns in the codebase for the same class of bug.

---

### P2 — Bug Candidate

**Clock-time fuzzy match ignores midnight rollover**

- Action: `REVIEW`
- Finding: `_findIntelligenceNearRequestedClockTime` (lines 3297–3314) computes `delta` as `(eventMinutes - requestedMinutes).abs()`. This treats the clock as linear 0–1439 minutes. If a client asks "around 11:50pm" (1430 min) and the matching event is at "00:10" (10 min), the computed delta is 1420 minutes (rejected), when the actual wall-clock distance is 20 minutes.
- Why it matters: For security clients who ask follow-up questions about overnight incidents near midnight, the system will silently fail to match the correct event and return a "no confirmed alert" response instead.
- Evidence: `lib/application/onyx_telegram_operational_command_service.dart:3303–3310`
- Suggested follow-up for Codex: Add wrap-around delta: `min(delta, 24*60 - delta)` and add a test case with a 23:55pm request against a 00:05am event.

---

### P2 — Bug Candidate

**`_bestIntelForDecision` returns `intelligence.first` as fallback after skipping all candidates**

- Action: `REVIEW`
- Finding: Lines 2797–2807: the loop skips events that are after the decision or more than 6 hours before it. If all events are skipped, the fallback `intelligence.first` (line 2807) is returned — which could be an event from a completely different time window.
- Why it matters: A response constructed from an unrelated intelligence event may show the wrong zone, camera, or signal type to a live client. Since `intelligence` is sorted newest-first, `intelligence.first` is typically the most recent event, not the most contextually relevant one.
- Evidence: `lib/application/onyx_telegram_operational_command_service.dart:2806–2807`
- Suggested follow-up for Codex: Replace the fallback with `null` and add a test case where all intelligence predates the decision by more than 6 hours.

---

### P2 — Duplication / Structural

**Four calm-check branches share an identical `latestOpenDecision` guard with near-identical response construction**

- Action: `REVIEW`
- Finding: `incidentPatrolAnchoredCalmFollowUp` (lines 1104–1151), `incidentDispatchAnchoredCalmFollowUp` (lines 1153–1199), `incidentResponseArrivalAnchoredCalmFollowUp` (lines 1201–1247), and `incidentCameraReviewAnchoredCalmFollowUp` (lines 1249–1294) follow the exact same structure:
  1. Check for the anchor marker, return early if null.
  2. Build an anchor-specific line string.
  3. Check `latestOpenDecision != null` → build `calmLead` with an identical 3-way branch on `contextAreaLabel` / `contextualIntel`.
  4. Build `statusLine` from `latestClosed`.
  5. Return `'$calmLead $anchorLine $statusLine ${visualLine(...)}'`.
  The only variation is the anchor type and its time label.
- Why it matters: Any change to the shared calmness-assessment logic (e.g. wording, status precedence) requires four synchronized edits. A missed edit produces inconsistent client-facing responses across anchor types.
- Evidence: Lines 1104–1294 in `_incidentClarificationResponse`
- Suggested follow-up for Codex: Extract a `_anchoredCalmResponse` helper that accepts the anchor line and area label, centralizing the shared guard logic.

---

### P2 — Duplication

**`_guardStatusResponse` and `_patrolReportResponse` share identical setup**

- Action: `AUTO`
- Finding: Both methods (lines 148–197 and 199–228) begin with the identical block: fetch patrols via `_eventsForRequest<PatrolCompleted>`, sort descending, and return an empty-scope message if empty. The divergence is only in what they do with the patrol result.
- Why it matters: A bug in patrol filtering (e.g., wrong sort direction) would need to be fixed in two places.
- Evidence:
  - `lib/application/onyx_telegram_operational_command_service.dart:152–164`
  - `lib/application/onyx_telegram_operational_command_service.dart:203–215`
- Suggested follow-up for Codex: Extract `_sortedPatrolsForRequest` returning `List<PatrolCompleted>` and an optional empty-response helper.

---

### P3 — Duplication / Wasted Compute

**`_findAreaMatchedIntelligence` called twice with identical arguments in two response methods**

- Action: `AUTO`
- Finding:
  - `_verificationResponse`: `_findAreaMatchedIntelligence` called at lines 575–579 (assigned to `matchingIntel` as part of null-coalescing fallback) and again at lines 618–621 (assigned to `areaSpecificMatch`). The second call is identical to the first and is immediately used to override the first result.
  - `_actionRequestResponse`: Same pattern at lines 674–679 and 680–683.
- Why it matters: Each call iterates the intelligence list. On a high-volume site, this doubles list traversal for every verification/action-request prompt. Also signals intent confusion — the variable `matchingIntel` includes a `latestIntelligence` fallback while `areaSpecificMatch` does not, but the distinction is then inconsistently applied.
- Evidence:
  - `lib/application/onyx_telegram_operational_command_service.dart:575–621`
  - `lib/application/onyx_telegram_operational_command_service.dart:674–683`
- Suggested follow-up for Codex: Store the area-specific match in one variable, compute the fallback-enriched form separately.

---

### P3 — Dead Abstraction

**`_statusVisualQualificationForCurrentReply` is a zero-value wrapper**

- Action: `AUTO`
- Finding: Lines 2906–2916 define `_statusVisualQualificationForCurrentReply` which does nothing except forward three named parameters to `_visualQualificationForCurrentReply` under different parameter names (`siteReference` → `siteReference`, `request` → `request`, `cameraHealthFactPacket` → `cameraHealthFactPacket`). The signatures differ only in that `_statusVisual...` requires `siteReference` rather than accepting it as optional. There is exactly one call site (line 275).
- Why it matters: Adds indirection with no semantic value and a misleading name suggesting different behavior.
- Evidence: `lib/application/onyx_telegram_operational_command_service.dart:2906–2916`
- Suggested follow-up for Codex: Inline the call at line 275, remove the wrapper.

---

### P3 — Copy/Paste Text Bug

**Self-referential sentence in `_incidentClarificationResponse`**

- Action: `AUTO`
- Finding: Line 1353 produces:
  `'The current operational picture does not clearly point back to $contextAreaLabel from the current operational picture.'`
  The phrase "from the current operational picture" is a duplicate tail that reads as malformed.
- Evidence: `lib/application/onyx_telegram_operational_command_service.dart:1353`
- Suggested follow-up for Codex: Remove the trailing "from the current operational picture." clause.

---

### P3 — Minor / Redundant Work

**`_hhmm` called with already-local DateTimes at every callsite**

- Action: `AUTO`
- Finding: `_hhmm` calls `.toLocal()` internally (line 1653) but every callsite also calls `.toLocal()` before passing (e.g. `_hhmm(patrol.occurredAt.toLocal())`). The double conversion is idempotent but creates unnecessary objects on every message format path.
- Evidence: `lib/application/onyx_telegram_operational_command_service.dart:1652–1657` and callsites at e.g. lines 175, 195, 224, 317, etc.
- Suggested follow-up for Codex: Remove the `.toLocal()` call inside `_hhmm` and let callers provide UTC or local as appropriate, or remove `.toLocal()` from all callsites and keep it only inside `_hhmm`.

---

## Duplication

| Repeated pattern | Methods involved | Centralization candidate |
|---|---|---|
| Patrol fetch + sort + empty guard | `_guardStatusResponse`, `_patrolReportResponse` | `_sortedPatrolsForRequest` |
| 4-variant anchored calm branch (check marker → `calmLead` → `statusLine` → visual) | 4 blocks in `_incidentClarificationResponse` (lines 1104–1294) | `_anchoredCalmResponse(anchorLine, contextAreaLabel, ...)` |
| `_findAreaMatchedIntelligence` double-call | `_verificationResponse`, `_actionRequestResponse` | Assign once, reuse |
| `_normalizedNaturalPrompt` called inside both `_resolvedAreaForRequest` and then again in calling methods | `_verificationResponse`, `_actionRequestResponse`, `_incidentClarificationResponse` | Already consistent — low priority |

---

## Coverage Gaps

1. **Regex bug (P1) has no test.** No test in the 6,182-line test file covers a site ID or route ID that contains multiple consecutive spaces or a raw underscore-separated ID that would expose the `r'\\s+'` bug. The scope label output is exercised indirectly through many tests, but the broken regex path is never triggered.

2. **Midnight crossover for clock-time matching is untested.** `_findIntelligenceNearRequestedClockTime` tests (if any) do not include events near midnight against a prompt requesting a time just before midnight. Confirm with Codex.

3. **`_bestIntelForDecision` fallback path is untested.** The case where all intelligence events are outside the 6-hour window before the decision (returning `intelligence.first` as a false best-match) has no coverage.

4. **`_lastNightWindowLocal` hardcodes 18:00–06:00 without locale context.** No test confirms that a prompt sent at 05:50 returns the correct night window (i.e., that `end` is today 06:00 and `start` is yesterday 18:00). Edge: if system runs UTC and `toLocal()` shifts the hour, this window could silently shift.

5. **`_to24HourClock` edge: 12am / 12pm.** `hour % 12` for `12am` = 0, `+0 = 0` (midnight) — correct. For `12pm` = 0, `+12 = 12` (noon) — correct. For `12pm` with `normalizedHour = 0 + 12 = 12`: no test exists for these edge inputs.

6. **`_siteAlertLeaderResponse` missing test for tie-breaking.** The alphabetical tie-break in `rankedSites` sort (line 1556–1559) has no explicit test. Tie-breaking directly affects which site name appears to the client.

7. **`_unresolvedIncidentsResponse` does not use `_truthSnapshotForRequest`.** It runs two independent `_eventsForRequest` calls (lines 234, 238). If the filter logic in `_eventsForRequest` changes, this method could produce results inconsistent with all other methods that use the snapshot. No test currently verifies that `_unresolvedIncidentsResponse` is consistent with the snapshot's `unresolvedDecisions` list.

---

## Performance / Stability Notes

1. **`_normalizedNaturalPrompt` is called multiple times per request path in `_incidentClarificationResponse`.** The method tokenizes and rebuilds the prompt string. For a single incoming message, it can be called 10–15 times across `_resolveConversationalIntent`, `_resolvedAreaForRequest`, and the individual `_looksLike*` checks. The normalization result is identical for all calls. Consider memoizing or passing it as a parameter.

2. **`_eventsForRequest` with switch-expression on event type uses a catch-all `_ => ''` branch** (lines 1596, 1603). Any new `DispatchEvent` subtype added to the domain that is not explicitly listed will silently return an empty `clientId`/`siteId`, causing it to pass all scope filters. This is a latent scope-leakage risk for future event types.

3. **`_truthSnapshotForRequest` performs 4 independent `_eventsForRequest` traversals of the same event list.** For clients with large event histories, these 4 full passes happen on every message. The list is already in memory, so this is not a remote-read problem, but it does mean O(4n) work per conversational turn. Low priority until event lists grow large.

---

## Recommended Fix Order

1. **Fix `RegExp(r'\\s+')` → `RegExp(r'\s+')` in `_humanizeScopeLabel`.** (P1 confirmed bug, AUTO, low risk)
2. **Add midnight-wrap to `_findIntelligenceNearRequestedClockTime` delta calculation.** (P2 bug candidate, REVIEW, requires a test to confirm the failure case first)
3. **Fix `_bestIntelForDecision` fallback — return `null` instead of `intelligence.first` when all candidates are out of window.** (P2 bug candidate, REVIEW, verify test exists)
4. **Remove `_statusVisualQualificationForCurrentReply` wrapper and the self-referential sentence at line 1353.** (P3, AUTO, cosmetic/textual)
5. **Fix double `_hhmm/.toLocal()` redundancy.** (P3, AUTO)
6. **Extract `_sortedPatrolsForRequest` to de-duplicate patrol setup.** (P3, AUTO)
7. **Extract anchored-calm branch into a shared helper.** (P2 structural, REVIEW — requires care not to change response text)
8. **Add missing test cases for P1 regex bug, midnight clock match, and `_bestIntelForDecision` fallback.** (Coverage, AUTO)
