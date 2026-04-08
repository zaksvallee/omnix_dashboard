# Audit: onyx_agent_cloud_boost_service.dart

- Date: 2026-04-08
- Auditor: Claude Code
- Scope: `lib/application/onyx_agent_cloud_boost_service.dart` + `lib/application/onyx_agent_local_brain_service.dart` (consumer/sibling, read for comparison)
- Read-only: yes

---

## Executive Summary

The cloud boost service is well-structured at the contract level and the advisory parsing pipeline is thorough. The happy-path tests are good. However, the file has grown into a shared library for types and utility functions that are also consumed by the local brain service — a directional dependency that will become a maintenance liability as the agent layer expands. Three concrete bug candidates exist: a `copyWith` null-reset trap on `OnyxAgentBrainAdvisory`, an ambiguous JSON extraction path, and a narrow narrative-suppression condition. Several coverage gaps are material given the safety-critical context.

---

## What Looks Good

- The `OnyxAgentCloudBoostService` abstract interface + `UnconfiguredOnyxAgentCloudBoostService` null-object pattern is clean. Callers never need to null-check the service reference.
- `_confidenceFromValue` correctly normalizes both 0–1 and 0–100 range inputs and clamps out-of-range values — this is careful defensive parsing.
- The `onyxAgentPrioritizedContextHighlights` category priority algorithm is explicit and deterministic. The ordering is intentional and the deduplication via normalized comparison is correct.
- `_tryParseBrainAdvisory` is wrapped in a full try/catch and logs with stack trace on failure. Silent fallback to `null` is appropriate here.
- The `OnyxAgentRoutingTier` enum and `onyxAgentRoutingTierFor` function provide a clean, centralized routing policy with no hidden conditionals.
- The `commandBodySupportLines` / `commandBodyClosingLines` / `commandBodyFooterLines` split on the extension is clean and composable.

---

## Findings

### P1 — Bug Candidate: `copyWith` cannot clear nullable fields

- **Action:** AUTO
- **Finding:** `OnyxAgentBrainAdvisory.copyWith` uses `??` for `recommendedTarget` and `confidence`, both of which are nullable (`OnyxToolTarget?` and `double?`). Passing `recommendedTarget: null` to `copyWith` silently preserves the existing value instead of clearing it — a standard Flutter `copyWith` null-reset trap.
- **Why it matters:** If any caller ever needs to produce a cleared advisory (e.g., after an operator cancels a recommendation), the advisory will silently retain stale data. In a security operations context, a ghost desk recommendation is a real operational risk.
- **Evidence:** `lib/application/onyx_agent_cloud_boost_service.dart` lines 118–147. The pattern is `recommendedTarget: recommendedTarget ?? this.recommendedTarget`.
- **Suggested follow-up:** Codex should verify whether any caller currently relies on the null-passthrough behaviour before fixing. The standard fix uses a sentinel wrapper or separate `clearRecommendedTarget` / `clearConfidence` flags.

---

### P1 — Bug Candidate: `_extractJsonCandidate` accepts ambiguous multi-object text

- **Action:** REVIEW
- **Finding:** The fallback extraction path at lines 972–976 uses `indexOf('{')` and `lastIndexOf('}')` to extract a JSON candidate from free text. If the AI returns a plain-text response containing two separate JSON-like objects (e.g., an error wrapper around a payload), the extractor will produce a span from the first `{` to the last `}` which is not valid JSON. The outer `try/catch` in `_tryParseBrainAdvisory` absorbs the `FormatException`, so there is no crash, but the advisory is silently dropped and the response falls back to raw text. In a production ops context, losing structured advisory data without any log or metric is a silent regression.
- **Why it matters:** Cloud providers occasionally return structured error bodies alongside partial completions (e.g., OpenAI content-policy envelopes). The current code logs the parse failure but does not distinguish between "LLM returned plain text" and "extraction produced malformed JSON from a multi-object response."
- **Evidence:** `lib/application/onyx_agent_cloud_boost_service.dart` lines 955–978, `_tryParseBrainAdvisory` lines 851–953.
- **Suggested follow-up:** Codex should verify whether the existing log at line 945 (`developer.log`) is sufficient for incident diagnosis. Consider whether a dedicated log entry at the extraction stage (before parse attempt) would improve observability.

---

### P2 — Bug Candidate: Narrative suppressed when it matches `why` field

- **Action:** REVIEW
- **Finding:** `commandBodyFooterLines` at line 190–193 suppresses the narrative if `trimmedResponseText == why.trim()`. The intent is deduplication, but `why` is an internal reasoning field while `narrative` is the operator-facing summary. If an AI returns a terse response where the narrative and the `why` text happen to be identical (which is plausible for single-sentence answers), the narrative line is omitted from the command body. The operator sees no human-readable conclusion.
- **Why it matters:** In a command-and-control UI, a missing narrative line could look like a broken response rather than intentional deduplication.
- **Evidence:** `lib/application/onyx_agent_cloud_boost_service.dart` lines 188–196.
- **Suggested follow-up:** Codex should check whether the `why` suppression check was intentional or a copy-paste from the `summary` check above it. Removing the `why` comparison may be safe.

---

### P2 — Architecture: Shared types and utilities live in the wrong file

- **Action:** DECISION
- **Finding:** `onyx_agent_local_brain_service.dart` imports `onyx_agent_cloud_boost_service.dart` to access shared types (`OnyxAgentCloudBoostResponse`, `OnyxAgentCloudScope`, `OnyxAgentCloudIntent`, `OnyxAgentBrainAdvisory`) and shared functions (`onyxAgentCloudBoostResponseFromRawText`, `onyxAgentMergePlannerMaintenancePriorityHighlight`, `onyxAgentPendingFollowUpContextForScope`, `onyxAgentOperatorFocusContextForScope`). The local brain service depends on the cloud service file for its own data types. This is a directional inversion — the local tier should not import from the cloud tier.
- **Why it matters:** As the agent layer grows (additional providers, streaming responses, or a Claude/Anthropic cloud tier), this coupling will force changes to the cloud service file to affect the local service. It also makes module boundaries misleading: the types are named "Cloud" but are shared infrastructure.
- **Evidence:** `lib/application/onyx_agent_local_brain_service.dart` line 6: `import 'onyx_agent_cloud_boost_service.dart';`
- **Suggested follow-up:** This is a naming and module extraction decision. A neutral file (e.g., `onyx_agent_brain_protocol.dart`) should own the shared types and utility functions. Both service implementations would then import from the protocol file. Zaks should confirm the extraction scope before Codex acts.

---

### P3 — Performance: `RegExp` instances are not cached in hot-path normalisation

- **Action:** AUTO
- **Finding:** `_normalizeHighlight` (lines 721–728) compiles two `RegExp` objects (`RegExp(r'[^a-z0-9]+')` and `RegExp(r'\s+')`) on every call. This function is called for every highlight in `_containsNormalizedHighlight` and `_sameNormalizedHighlights`, which are both called inside `onyxAgentPrioritizedContextHighlights` — once per advisory merge. In an ops context with frequent advisory refreshes this is a low-but-real GC cost.
- **Evidence:** `lib/application/onyx_agent_cloud_boost_service.dart` lines 721–728.
- **Suggested follow-up:** Codex can promote the two `RegExp` instances to top-level constants. No behavioural change.

---

### P3 — Performance: System prompt rebuilt on every `boost()` call

- **Action:** REVIEW
- **Finding:** `OpenAiOnyxAgentCloudBoostService._systemPrompt` and `OllamaOnyxAgentLocalBrainService._systemPrompt` both construct a multi-hundred-character string on every inference call. Since `scope` and `intent` vary per call this is not trivially cacheable, but the fixed preamble (the ONYX persona block and the rules numbered 1–15) is repeated on every invocation.
- **Evidence:** `lib/application/onyx_agent_cloud_boost_service.dart` lines 405–443; `lib/application/onyx_agent_local_brain_service.dart` lines 152–181.
- **Suggested follow-up:** Low operational impact at current call frequency. Flag for revisit if advisory throughput increases significantly (e.g., streaming or background polling).

---

## Duplication

### 1. System prompt preamble — cloud vs local brain

- **Files:** `onyx_agent_cloud_boost_service.dart` lines 421–423, `onyx_agent_local_brain_service.dart` lines 161–163.
- **Repeated block:** The ONYX persona preamble ("You are ONYX Intelligence...") is copy-pasted verbatim in both `_systemPrompt` methods.
- **Centralisation candidate:** A top-level constant `kOnyxAgentPersonaPreamble` in the shared protocol file. Each implementation appends its own formatting rules after the shared persona.

### 2. HTTP error response pattern

- **Files:** `onyx_agent_cloud_boost_service.dart` lines 354–402, `onyx_agent_local_brain_service.dart` lines 101–148.
- **Repeated block:** Non-2xx HTTP check → `onyxAgentCloudBoostErrorResponse`, `FormatException` → `onyxAgentCloudBoostErrorResponse`, catch-all → `onyxAgentCloudBoostErrorResponse`. The structure is identical in both services with only the `errorSummary` string differing.
- **Centralisation candidate:** A shared `_handleHttpError` / `_handleParseError` utility or a mixin. The per-provider label and summary string would be injected as parameters.

### 3. Scope header construction (`clientId` / `siteId` / `incident` / `route`)

- **Files:** `onyx_agent_cloud_boost_service.dart` lines 409–420, `onyx_agent_local_brain_service.dart` lines 153–160.
- **Repeated block:** Both `_systemPrompt` methods perform the same four `trim().isEmpty ? default : value` substitutions on `scope` fields before embedding them in the system prompt.
- **Centralisation candidate:** A `OnyxAgentCloudScope` method (e.g., `scopeHeader()`) or a top-level function that returns the scope string. Both prompts call it once.

---

## Coverage Gaps

1. **`_extractJsonCandidate` — code fence path** (lines 960–967): No test exercises the ` ```json\n{...}\n``` ` extraction branch. A test with a markdown-fenced JSON response would lock this behaviour.

2. **`_extractJsonCandidate` — multi-object ambiguous input**: No test for a response containing two JSON-like blocks. Should confirm the parse failure is logged and the advisory gracefully degrades to `null`.

3. **`_confidenceFromValue` — edge cases**: No test for negative input (expected: clamp to `0`), input `> 100` (expected: clamp to `1`), or string input like `"84%"` (expected: `null` since `double.tryParse` fails on percent signs).

4. **`_toolTargetFromValue` — unknown target**: No test for an unrecognised string (expected: `null`). Important since the LLM may hallucinate target names outside the permitted set.

5. **`onyxAgentPrioritizedContextHighlights` — direct unit test**: The priority ordering algorithm has no dedicated test. It is only exercised end-to-end through the full boost mock. A unit test with a pre-populated `currentHighlights` list and a scope with multiple pressures active simultaneously would lock the priority ordering contract directly.

6. **HTTP timeout path**: The `client.post(...).timeout(requestTimeout)` firing a `TimeoutException` is not tested. The catch-all at line 390 handles it, but the `errorSummary` and `errorDetail` values for a timeout are not verified.

7. **`OnyxAgentBrainAdvisory.copyWith` — null-reset behaviour**: No test asserts what happens when `recommendedTarget: null` is passed. This would expose the P1 bug above immediately.

8. **`commandBodyFooterLines` — narrative suppressed by `why` match**: No test for the case where `responseText == advisory.why`. The suppression condition is untested.

9. **`onyxAgentMergePlannerMaintenancePriorityHighlight` — no-op shortcut branch**: Lines 465–468 return early when highlights and primary pressure are unchanged. This early-return is tested indirectly but not directly with a case designed to hit it.

---

## Performance / Stability Notes

- **Regex allocation in hot path** (P3 above): `_normalizeHighlight` allocates two `RegExp` on every call. Promote to top-level constants.
- **No back-pressure on concurrent `boost()` calls**: `OpenAiOnyxAgentCloudBoostService` holds an injected `http.Client` but does not track in-flight requests. If the UI triggers multiple rapid advisory requests (e.g., operator types quickly), all fire in parallel with no debounce or cancellation. This is a calling-site responsibility, but worth confirming the coordinator above this service has a guard.
- **`_extractText` parses three different OpenAI response shapes** (lines 801–848 — `output_text` flat field, `output[].content[].text` nested, `choices[].message.content` legacy). This multi-shape extraction is a maintenance risk: if a fourth shape is introduced silently by an OpenAI API version update, text extraction returns `null` and the service returns `null` rather than an error, making it look like a successful empty response to the caller.

---

## Recommended Fix Order

1. **P1 — `copyWith` null-reset trap**: High impact, low risk to fix. Codex should check callers first, then fix. (`AUTO` once call-site check passes)
2. **Coverage — `_confidenceFromValue` and `_toolTargetFromValue` edge cases**: These are pure functions with no dependencies. Fast to cover. (`AUTO`)
3. **Coverage — HTTP timeout test**: Closes a silent failure path. (`AUTO`)
4. **P2 — Narrative suppressed by `why` match**: Small behavioural question. Zaks should confirm whether the `why` deduplication check was intentional. (`REVIEW`)
5. **Duplication — HTTP error pattern and scope header**: Extract shared helpers once the protocol file split (P2 architecture) is decided. (`DECISION` blocks `AUTO`)
6. **Architecture — shared types in wrong file**: Extract `onyx_agent_brain_protocol.dart`. Coordinate with Codex on import graph impact. (`DECISION`)
7. **P3 — Regex caching**: Trivial clean-up, do last. (`AUTO`)
