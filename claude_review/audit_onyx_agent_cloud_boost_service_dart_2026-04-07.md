# Audit: onyx_agent_cloud_boost_service.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/application/onyx_agent_cloud_boost_service.dart` + `test/application/onyx_agent_cloud_boost_service_test.dart`
- Read-only: yes

---

## Executive Summary

This is a well-reasoned service layer that handles cloud AI boost calls with structured advisory parsing, context injection, and highlight prioritization. The core logic is defensively written and the test suite covers the main happy paths and error paths thoroughly.

The primary risks are: a silent catch-all in `_tryParseBrainAdvisory` that can absorb real bugs invisibly; a very low `max_output_tokens` (280) that will cause silent advisory loss when JSON is truncated; and a 1060-line god module that mixes models, service interfaces, response factories, context serializers, and sorting logic in one file. The architecture needs splitting before it grows further.

---

## What Looks Good

- `OnyxAgentCloudScope` and `OnyxAgentBrainAdvisory` are clean, const-constructable, and well-defaulted.
- `_extractText` handles three distinct OpenAI API response shapes (`output_text`, `output[].content[].text`, `choices[].message.content`) — good forward compatibility.
- `_toolTargetFromValue` uses a `switch` expression with aliased cases — readable and exhaustive.
- `_confidenceFromValue` normalises 0–1 and 0–100 scales and clamps at boundaries — defensive and correct.
- `onyxAgentPrioritizedContextHighlights` has a clear ordering contract and deduplicates by normalised form — solid.
- Test coverage for core paths (happy path JSON, plain text, HTTP error, socket throw, operator focus scope, follow-up scope, planner maintenance merge) is good.

---

## Findings

### P1 — Silent `catch (_)` in `_tryParseBrainAdvisory` swallows real bugs
- **Action:** REVIEW
- `_tryParseBrainAdvisory` at line 915 uses bare `catch (_)` with no logging. Any `TypeError`, `CastError`, or unexpected `Map.cast` failure inside JSON parsing is silently discarded — the function returns `null` and the advisory is silently lost.
- **Why it matters:** If the JSON contract changes (e.g., `confidence` is returned as a `bool` instead of `double`), production responses will silently degrade to plain-text mode. No log, no metric, no alert. This is the exact kind of silent fallback the CLAUDE_CODE_ROLE.md warns against.
- **Evidence:** `lib/application/onyx_agent_cloud_boost_service.dart:915`
- **Suggested follow-up:** Replace bare `catch (_)` with `catch (error, stackTrace)` and emit a `developer.log` at minimum. Label the failure as a JSON advisory parse failure so it can be traced in logs.

---

### P1 — `max_output_tokens: 280` is too low for the required structured JSON
- **Action:** REVIEW
- The system prompt at lines 394–413 requests a JSON object with 12 named keys (`summary`, `recommended_target`, `confidence`, `why`, `missing_info`, `primary_pressure`, `context_highlights`, `operator_focus_note`, `follow_up_label`, `follow_up_prompt`, `follow_up_status`, `text`). A full advisory easily exceeds 280 tokens.
- **Why it matters:** When the model's response is truncated mid-JSON, `jsonDecode` throws a `FormatException`. The silent `catch (_)` at line 915 absorbs it, drops the advisory, and the caller receives a plain-text fallback with no indication of truncation. The operator sees degraded output with no visible error.
- **Evidence:** `lib/application/onyx_agent_cloud_boost_service.dart:292` (token limit), line 915 (silent catch)
- **Suggested follow-up:** Increase `max_output_tokens` to at least 512–768. Cross-check against `gpt-4.1-mini` context pricing if cost is a concern. Note this is a `REVIEW` not `AUTO` because the token value encodes a product trade-off.

---

### P2 — `_extractJsonCandidate` markdown fence stripping is brittle
- **Action:** AUTO
- Lines 925–933: the fence-strip path only activates when the response starts with ` ``` `. It then calls `lines.sublist(1, lines.length - 1)` and checks `body.startsWith('{') && body.endsWith('}')`. If the closing fence line has trailing whitespace or the response ends with `}` followed by an extra newline inside the fence, `endsWith('}')` fails, and the function falls through to the `indexOf`/`lastIndexOf` greedy extraction at lines 937–941 — which may grab a partial or outer JSON fragment.
- **Why it matters:** Produces a corrupted JSON candidate that fails `jsonDecode`, swallowed silently by `catch (_)` above.
- **Evidence:** `lib/application/onyx_agent_cloud_boost_service.dart:925–941`
- **Suggested follow-up:** After `join('\n')`, apply `.trim()` before the `startsWith`/`endsWith` checks (the existing code does trim, but `endsWith('}')` still fails if a trailing newline survives). Alternatively, skip the fence check entirely and always use the greedy `indexOf`/`lastIndexOf` path — it already handles the common case safely.

---

### P2 — `onyxAgentPrimaryPressureFromContextSummary` calls `onyxAgentPlannerMaintenancePriorityHighlightFromContextSummary` only to discard the result
- **Action:** AUTO
- Lines 577–583: `onyxAgentPrimaryPressureFromContextSummary` calls the full `onyxAgentPlannerMaintenancePriorityHighlightFromContextSummary` (which does multi-boundary substring extraction) purely to check `!= null`. It then ignores the value and returns the hardcoded string `'planner maintenance'`.
- **Why it matters:** Wastes work. More importantly, the check could be done with the cheaper marker presence check already inside `_pressureLabelFromContextSummary`. This is a logic redundancy that could diverge.
- **Evidence:** `lib/application/onyx_agent_cloud_boost_service.dart:577–583`
- **Suggested follow-up:** Extract a cheaper `_hasMaintenancePriorityMarker(contextSummary)` boolean helper rather than calling the full highlight builder for a side-effect-free existence check.

---

### P3 — God module: 1060-line file mixing models, interfaces, implementations, formatters, and sorters
- **Action:** DECISION
- The file contains: `OnyxAgentCloudScope` (model), `OnyxAgentBrainAdvisory` (model + extension), `OnyxAgentCloudBoostResponse` (response DTO), `OnyxAgentCloudBoostService` (abstract interface), `UnconfiguredOnyxAgentCloudBoostService` (null object), `OpenAiOnyxAgentCloudBoostService` (HTTP implementation), plus 15 free functions covering context serialization, highlight prioritization, JSON extraction, and narrative building.
- **Why it matters:** Any future provider (e.g., Claude, Gemini) requires adding another impl class here, deepening the file further. The sorting/highlight logic (`onyxAgentPrioritizedContextHighlights`, `_priorityHighlightCategory`) is domain logic that should be testable in isolation without pulling in HTTP.
- **Evidence:** `lib/application/onyx_agent_cloud_boost_service.dart:1–1060`
- **Suggested follow-up:** This is a DECISION because splitting requires agreeing on a new file layout. Candidate split: `onyx_agent_cloud_scope.dart` (models), `onyx_agent_brain_advisory.dart` (advisory + formatters), `onyx_agent_context_formatters.dart` (scope context strings), `onyx_agent_highlight_prioritizer.dart` (sorting + canonical logic), `onyx_agent_cloud_boost_service.dart` (interface + impls only). Keep the split in sync with the existing test file or split tests in parallel.

---

## Duplication

### `_pressureLabelFromContextSummary` vs `onyxAgentPlannerMaintenancePriorityHighlightFromContextSummary`
- Both parse structured string markers from `contextSummary` using identical index/substring logic (lines 668–690 vs lines 523–560).
- The maintenance highlight version adds multi-boundary stripping and a terminal-period formatter.
- **Files:** both in `lib/application/onyx_agent_cloud_boost_service.dart`
- **Centralization candidate:** A shared `_extractContextSummarySegment(summary, marker, boundaries)` helper would unify the substring extraction skeleton, leaving only boundary lists and formatting as call-site parameters.

### `onyxAgentPendingFollowUpContextForScope` and `onyxAgentOperatorFocusContextForScope`
- Both build `key=value` strings from scope fields using the same `parts.join(' ')` pattern (lines 641–658 and lines 753–770).
- Not a strong centralization candidate yet (the content differs meaningfully), but worth noting if a third context formatter is added.
- **Files:** same file, lines 641–770.

---

## Coverage Gaps

### `_extractJsonCandidate` — fence-strip path not tested
- The markdown fence path (response starting with ` ``` `) has no dedicated test. All existing tests return bare JSON or string text.
- **Risk:** Fence-strip regression could silently degrade advisory parsing in production if a model starts wrapping responses in code fences.

### `boost()` with empty prompt — null return path not tested
- `cleanedPrompt.isEmpty` at line 275 returns `null`. No test covers this branch.
- **Risk:** Callers that don't guard for null may crash at the UI layer.

### `_confidenceFromValue` boundary normalization not unit-tested
- Boundary values (e.g., `84` → `0.84`, `101` → `1.0`, `-5` → `0.0`, `'0.95'` string) are not tested in isolation. Only covered indirectly via full integration at `0.84`.
- **Risk:** Confidence clamping behaviour is invisible to test output.

### `_buildNarrative` all-empty fallback not tested
- When `narrative`, `summary`, `why`, and `missingInfo` are all empty, `_buildNarrative` returns `rawText.trim()` (line 1056). This path is untested.

### Request timeout expiry not tested
- `requestTimeout` (default 18 s) is injected but the timeout path (`TimeoutException`) is not verified. The catch at line 363 handles it generically, but there's no test that verifies the returned `errorDetail` reflects a timeout.

### `onyxAgentMergePlannerMaintenancePriorityHighlight` with null advisory not tested explicitly
- The short-circuit `if (advisory == null) return response` at line 423 is exercised by plain-text responses, but no test explicitly verifies that the response passes through unchanged when advisory is absent.

---

## Performance / Stability Notes

### `RegExp` compiled on every `_normalizeHighlight` call
- `_normalizeHighlight` (lines 692–699) compiles two `RegExp` objects on every invocation: `RegExp(r'[^a-z0-9]+')` and `RegExp(r'\s+')`. `onyxAgentPrioritizedContextHighlights` calls this for every highlight in both `remaining` and `ordered` lists on every advisory merge.
- **Concern level:** Low for current list sizes (< 10 items), but these should be module-level constants to avoid repeated compilation.
- **Evidence:** `lib/application/onyx_agent_cloud_boost_service.dart:693–698`

### System prompt rebuilt on every `boost()` call
- `_systemPrompt` (lines 378–414) concatenates a 15-rule string with minor per-call interpolation (client, site, incident, route, intent). The bulk of the string is static and rebuilt every call.
- **Concern level:** Low — the runtime cost is negligible. But the static portion should be a module constant to make the per-call diff visible.

---

## Recommended Fix Order

1. **(P1)** Replace bare `catch (_)` in `_tryParseBrainAdvisory` with a logged catch — highest-value fix, zero risk, unlocks debuggability for all silent advisory failures.
2. **(P1)** Raise `max_output_tokens` after agreeing on a target — requires product REVIEW before Codex can implement.
3. **(P2)** Fix `_extractJsonCandidate` fence-strip path to apply `.trim()` before `endsWith('}')` — AUTO, safe, no behaviour change on non-fence responses.
4. **(P2)** Replace the `onyxAgentPlannerMaintenancePriorityHighlightFromContextSummary != null` check with a lightweight marker-presence helper.
5. **(Coverage)** Add unit tests for `_confidenceFromValue` boundary values, empty prompt null return, and `_extractJsonCandidate` fence-strip path.
6. **(P3 / DECISION)** Agree on file split strategy before the next provider implementation is added.
