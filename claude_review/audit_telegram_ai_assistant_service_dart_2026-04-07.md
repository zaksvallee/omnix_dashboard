# Audit: telegram_ai_assistant_service.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/application/telegram_ai_assistant_service.dart` (5375 lines) + part files: `telegram_ai_assistant_camera_health.dart` (575 lines), `telegram_ai_assistant_clarifiers.dart` (432 lines), `telegram_ai_assistant_site_view.dart` (468 lines) — 6850 lines total
- Read-only: yes

---

## Executive Summary

This is the most complex service in the codebase. The core AI drafting, fallback routing, and reply polishing logic are well-structured and show careful operational thought. The three-provider chain (OnyxCloud → directProvider → OnyxLocal) is coherent. The heuristic fallback engine is thorough.

However, the file has grown into a god-class: 5375 lines in the main file alone, a 1200-line `_fallbackReply` dispatcher, and two 150+ line boolean guard functions. There are two confirmed bugs: a fully silent catch block that masks all remote failures, and a missing `learnedReplyExamples` parameter in `_fallbackReply` that silently drops learned style memory in every polished fallback path. There is also a structural priority order inconsistency in `OnyxFirstTelegramAiAssistantService`. Coverage of the truth-grounded fallback paths is thin.

---

## What Looks Good

- **Three-provider chain** in `OnyxFirstTelegramAiAssistantService` is cleanly composed: tries cloud boost, falls to direct provider, falls to local brain, ends in unconfigured fallback. The intent is readable.
- **`_extractText`** (lines 5335–5374) handles both the Responses API format (`output_text`, `output[].content[]`) and the older Chat Completions format (`choices[0].message.content`) in one place — good defensive forward-compatibility.
- **`_telegramDraftReplyFromOnyxResponse`** (line 920) validates the Onyx response before calling `_polishReply`, and the null-return path forces fallback cleanly.
- **`_looksMechanicalClientReply`** is a concrete, testable guard against leaking internal identifiers or template artifacts to clients.
- **Part-file split** (`_camera_health`, `_clarifiers`, `_site_view`) is a reasonable structural separation of the clarifier subtrees.
- **`_scopeProfileFor`** (line 3275) and `_humanizeScopeLabel` provide a clean, single normalization path for all client/site ID handling.

---

## Findings

### P1 — Bug: Silent `catch (_)` swallows all remote errors
- **Action: AUTO**
- **Finding:** `OpenAiTelegramAiAssistantService.draftReply` wraps the entire HTTP call in `try { ... } catch (_) { return fallback; }` with no logging or error type inspection.
- **Why it matters:** `TimeoutException`, `SocketException`, `FormatException` from `jsonDecode`, and `http.ClientException` all become silent fallback replies with `providerLabel: 'fallback'`. There is no observable signal that the API is down, the key is wrong, or the network is broken. Operational failures silently degrade to heuristic mode with no alerting path.
- **Evidence:** `telegram_ai_assistant_service.dart:311` — `catch (_) { return TelegramAiDraftReply(text: _fallbackReply(...), usedFallback: true, ...); }`
- **Suggested follow-up for Codex:** Replace `catch (_)` with typed catch branches (`on TimeoutException`, `on http.ClientException`, `on FormatException`), or at minimum rethrow to a logging layer. The `TelegramAiDraftReply` model could carry an optional `errorHint` field to surface failure type to the caller without exposing it to the client.

---

### P1 — Bug: `_fallbackReply` drops `learnedReplyExamples` silently
- **Action: REVIEW**
- **Finding:** `_fallbackReply` (line 970) does not accept a `learnedReplyExamples` parameter. Every call site in `_polishReply` that triggers a fallback (lines 1450, 1464, 1485) cannot forward learned examples because the signature won't accept them.
- **Why it matters:** When the AI provider returns a mechanical or truth-conflicting reply and `_polishReply` routes to `_fallbackReply`, the learned approval style is silently discarded. The caller still sets `usedLearnedApprovalStyle: learnedReplyExamples.isNotEmpty` in the outer `draftReply` — meaning the returned `TelegramAiDraftReply` claims learned style was applied when it was not.
- **Evidence:**
  - `_fallbackReply` signature: line 970–980 — `learnedReplyExamples` is absent.
  - `_polishReply` at line 1450, 1464, 1485 — calls `_fallbackReply` with all other parameters, but cannot include `learnedReplyExamples` because the parameter doesn't exist.
  - `_preferredReplyStyleFromExamplesAndTags` and `_combinedReplyExamples` (line 4224) are designed to merge learned examples into the style, but they are never reached on this code path.
- **Suggested follow-up for Codex:** Add `learnedReplyExamples` to `_fallbackReply`'s signature. Confirm whether `_preferredReplyStyleFromExamplesAndTags` inside `_fallbackReply` should receive combined examples or preferred-only.

---

### P1 — Structural: `OnyxFirstTelegramAiAssistantService` priority order contradicts its name
- **Action: REVIEW**
- **Finding:** The routing order in `OnyxFirstTelegramAiAssistantService.draftReply` is: OnyxCloud → directProvider (OpenAI) → OnyxLocal → unconfigured fallback. `directProvider` (typically `OpenAiTelegramAiAssistantService`) is tried **before** `onyxLocalBrain`, despite the class being named "OnyxFirst".
- **Why it matters:** The implied contract is that Onyx providers are preferred over third-party providers. But if cloud boost fails (returns null), a configured OpenAI key is used before the local Onyx brain. Whether this is intentional (OpenAI is faster/better than local) or accidental is not clear from the code.
- **Evidence:** Lines 433–475. `directProvider.isConfigured` check at 433 runs before `onyxLocalBrain.isConfigured` at 450.
- **Suggested follow-up for Codex:** Confirm with Zaks whether the intended priority is `cloud → direct → local` or `cloud → local → direct`. If the latter, lines 433–474 should be swapped.

---

### P2 — Structural: `_fallbackReply` is a 400-line dispatcher with 25+ sequential null-checks
- **Action: DECISION**
- **Finding:** `_fallbackReply` (lines 970–1390) dispatches through ~22 named clarifier functions via sequential `if (result != null) return result;` chains. The order of these checks determines reply selection but there is no explicit priority table or configuration driving the order — it is purely implicit in the code sequence.
- **Why it matters:** Adding a new clarifier type or adjusting priority requires reading 400 lines to understand the routing order. A new clarifier inserted in the wrong position silently takes priority over existing ones. The "priority" is invisible to anyone reviewing the business logic without reading the full dispatch chain.
- **Evidence:** Lines 1024–1275 — 22 sequential clarifier dispatches.
- **Suggested follow-up for Codex:** This is a design choice. Consider whether the dispatch chain should be extracted into a prioritized list of `_TelegramReplyStrategy` objects, each with a name, priority, and `String? tryReply(...)` signature. Not blocking, but worth a design conversation.

---

### P2 — Bug candidate: `_shouldForceTruthGroundedClientFallback` and `_shouldPreferFallbackForClientReply` overlap in intent
- **Action: REVIEW**
- **Finding:** Both functions are called from `_polishReply` (lines 1446, 1478). Both evaluate `messageText` + `recentConversationTurns` for trust-override conditions. Both duplicate large keyword lists (camera down, security not on site, etc.) independently.
- **Why it matters:** A condition that triggers one may not trigger the other, creating inconsistent fallback behavior depending on the call path. The keyword list for "cameras down" appears in both functions with slight variation (e.g. `_shouldForceTruthGroundedClientFallback` line 1559–1576 vs `_shouldPreferFallbackForClientReply` line 1992–1999).
- **Evidence:**
  - `_shouldForceTruthGroundedClientFallback`: lines 1524–1673
  - `_shouldPreferFallbackForClientReply`: lines 1820–2240 (approx)
- **Suggested follow-up for Codex:** Audit whether both functions can return `true` for the same input (they can), meaning `_polishReply` checks force-truth first and never reaches prefer-fallback. Verify there are inputs where only `_shouldPreferFallbackForClientReply` triggers — if not, `_shouldForceTruthGroundedClientFallback` is a subset and could be merged.

---

### P2 — Stability: `recentConversationTurns` is unbounded at entry
- **Action: AUTO**
- **Finding:** All three `draftReply` implementations accept `recentConversationTurns` with no length guard. Internal consumers take slices (`.take(4)` at line 915, `.take(6)` at line 4318), but the full list is passed through every clarifier call, every `joinedContext` assembly, and every keyword scan.
- **Why it matters:** A caller passing 50–100 turns causes each clarifier to do full O(n) string joins and scans. In a lane with a long conversation history this could become expensive per-message.
- **Evidence:** `draftReply` signature at lines 79, 108, 362 — no `maxTurns` guard. `joinedContext` is assembled from the full list at lines 1533, 1750, etc.
- **Suggested follow-up for Codex:** Add a guard early in each `draftReply`: `final boundedTurns = recentConversationTurns.take(12).toList();` and use that throughout. 12 turns is enough for all present heuristics (the deepest scan is `take(6)` at 4318).

---

## Duplication

### 1. Keyword lists for "cameras down" duplicated across guard functions
- **Files:** `telegram_ai_assistant_service.dart` lines 1559–1576, 1992–1999, 1709–1714, 1733–1740
- **Pattern:** The phrase list `['my cameras are down', 'cameras are down', 'camera is down', 'camera down', 'cctv is down', 'cctv down']` appears verbatim in at least four different guard functions.
- **Centralization candidate:** Extract a `_kCamerasDownPhrases` top-level const list. The same applies to "security not on site" (lines 779–786, 2001–2013).

### 2. `draftReply` parameter signature repeated three times
- **Files:** `UnconfiguredTelegramAiAssistantService.draftReply` (line 97), `OpenAiTelegramAiAssistantService.draftReply` (line 151), `OnyxFirstTelegramAiAssistantService.draftReply` (line 351)
- **Pattern:** 10-parameter named signature is literally duplicated across all three implementations. An interface change requires updating all three.
- **Centralization candidate:** The abstract `TelegramAiAssistantService.draftReply` signature at line 73 is the single source of truth — this is already correct. Risk is that a parameter added to one impl without updating the abstract class compiles silently with a default value. No immediate fix needed, but worth noting.

### 3. Fallback `TelegramAiDraftReply` construction repeated 6+ times in `OpenAiTelegramAiAssistantService`
- **Files:** `telegram_ai_assistant_service.dart` lines 168, 175, 237, 258, 290, 312
- **Pattern:** `TelegramAiDraftReply(text: _fallbackReply(...), usedFallback: true, usedLearnedApprovalStyle: learnedReplyExamples.isNotEmpty)` is repeated 6 times with nearly identical argument sets.
- **Centralization candidate:** Extract a private `_buildFallback(...)` helper inside `OpenAiTelegramAiAssistantService` that constructs the fallback reply from the common parameter set.

---

## Coverage Gaps

### 1. `_shouldForceTruthGroundedClientFallback` — no direct unit test
- The only test touching the mechanical-reply path is `'openai assistant replaces mechanical client reply with warm fallback'` (line 1241 of test file), which exercises `_looksMechanicalClientReply`. The 15+ branching conditions in `_shouldForceTruthGroundedClientFallback` (e.g. `_challengesTelemetryPresenceSummary`, `_asksHypotheticalEscalationCapability`, `cameraConnectionAsk + joinedContext`, `operationalPictureClarifier`) have no isolated tests.
- **Gap:** A regression in any one branch silently changes reply selection for AI-generated text.

### 2. `_replyConflictsWithCameraHealthFactPacket` — no tests found
- This function (line 1698) has 6 distinct case branches driven by `ClientCameraHealthStatus` and message intent. No test in `telegram_ai_assistant_service_test.dart` was found targeting it by name or behavior.
- **Gap:** Camera health contradiction logic is completely untested in isolation.

### 3. `OnyxFirstTelegramAiAssistantService` priority chain — partial coverage
- Tests exist for the cloud-first path (`'onyx-first telegram assistant prefers onyx cloud before local and direct providers'`), but it is unclear whether `directProvider` beating `onyxLocalBrain` is covered. The case where cloud fails and direct is unconfigured (local brain path) should be tested explicitly.

### 4. `_fallbackReply` clarifier priority order — not locked
- The 22-step dispatch chain has no test that verifies two overlapping clarifiers return the correct one. If clarifier X fires before clarifier Y for a given message, and their order is swapped, no test would catch it.

### 5. `UnconfiguredTelegramAiAssistantService` with non-empty `learnedReplyExamples`
- The only test for the unconfigured service (`'unconfigured assistant returns fallback draft'`) likely passes empty style lists. There is no test verifying that `usedLearnedApprovalStyle: true` is set when examples are provided (even though the code path looks correct).

---

## Performance / Stability Notes

### 1. No retry or backoff on `OpenAiTelegramAiAssistantService` HTTP calls
- A single `requestTimeout: Duration(seconds: 15)` is the only resilience mechanism. No retry on 429, 503, or transient 5xx. The service degrades fully to fallback on first failure.
- This is not necessarily wrong — silent retry in a Telegram reply context could cause double-send ambiguity — but the caller has no signal that the failure was transient vs permanent.

### 2. Prompt is constructed even when `!isConfigured` in `OpenAiTelegramAiAssistantService`
- Lines 165–189 check `isConfigured` **after** computing `cleaned` and `scope`. The prompt itself is not constructed at this point, so no real waste. Confirmed: OK. (This is a non-issue.)

### 3. `_telegramAssistantOnyxPrompt` calls `_telegramAssistantSystemPrompt` which calls multiple snippet builders
- At line 862, the Onyx prompt wraps the full system prompt including all snippet assembly (lines 507–527). For messages with long `preferredReplyExamples` lists this could produce prompts of several thousand characters. No length guard on the final prompt string before sending to Onyx.

---

## Recommended Fix Order

1. **[P1 AUTO] Fix `catch (_)` in `OpenAiTelegramAiAssistantService`** — add typed catch branches or a logging hook. This is the highest-risk silent failure in the file.
2. **[P1 REVIEW] Add `learnedReplyExamples` to `_fallbackReply` signature** — verify all call sites and confirm `_preferredReplyStyleFromExamplesAndTags` receives combined examples.
3. **[P1 REVIEW] Confirm `OnyxFirstTelegramAiAssistantService` provider priority order** — get Zaks to confirm intended routing before touching this.
4. **[P2 AUTO] Bound `recentConversationTurns`** at entry to `draftReply` (guard at 12 or configurable max) to prevent unbounded scan cost in long-running lanes.
5. **[P2 AUTO] Extract duplicated keyword const lists** (`_kCamerasDownPhrases`, `_kSecurityNotOnSitePhrases`) to remove drift risk between guard functions.
6. **[P2 AUTO] Extract `_buildFallback` helper** inside `OpenAiTelegramAiAssistantService` to collapse 6 near-identical `TelegramAiDraftReply` construction blocks.
7. **[P2 REVIEW] Audit `_shouldForceTruthGroundedClientFallback` vs `_shouldPreferFallbackForClientReply` overlap** — determine if one is a strict superset and merge.
8. **[Coverage] Add tests for `_replyConflictsWithCameraHealthFactPacket`** across all 6 `ClientCameraHealthStatus` × intent branch combinations.
9. **[Coverage] Add tests for `_shouldForceTruthGroundedClientFallback`** — at minimum cover the `telemetryPresenceChallenge`, `cameraConnectionAsk`, and `operationalPictureClarifier` branches.
10. **[DECISION] Review `_fallbackReply` dispatcher architecture** — 22-step sequential chain warrants a named-strategy table if the count grows further.
