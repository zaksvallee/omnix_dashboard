# Audit: onyx_agent_local_brain_service.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/application/onyx_agent_local_brain_service.dart` + cross-reference `lib/application/onyx_agent_cloud_boost_service.dart` + `test/application/onyx_agent_local_brain_service_test.dart`
- Read-only: yes

---

## Executive Summary

The file is small and focused. The null-object pattern (`UnconfiguredOnyxAgentLocalBrainService`) is clean. The Ollama implementation is structurally sound and covered by a reasonable test suite. However, two concerns dominate:

1. **Structural duplication** with `OpenAiOnyxAgentCloudBoostService` — the entire request/decode/merge pipeline is copy-pasted between the two providers with no shared coordinator. This will drift.
2. **Silent empty-text return** — when the model responds with parseable JSON but an empty `text`/`content`, `synthesize` returns `null` with no log or error signal, which is indistinguishable from "service not configured" at the call site.

Three coverage gaps are concrete and fixable. One endpoint resolution edge case is a latent misconfiguration risk.

---

## What Looks Good

- Null-object `UnconfiguredOnyxAgentLocalBrainService` is correctly placed and tests for it are minimal and correct.
- `_resolveChatEndpoint` handles the most common path forms cleanly (bare host, trailing slash, already-terminated path).
- `_extractLocalText` correctly tries both Ollama response shapes (`message.content` and top-level `response`) in priority order.
- The `FormatException` is caught in an inner try/catch and returns a structured error response rather than propagating.
- The outer `catch (error, stackTrace)` logs with `developer.log` and returns a structured error — callers are never left with an unhandled exception.
- `requestTimeout` is configurable and wired correctly through `.timeout(requestTimeout)`.
- Temperature is pinned at 0.2 — appropriate for a deterministic ops context.

---

## Findings

### P1 — Silent null on empty model text (confirmed bug candidate)

- **Action: AUTO**
- **Finding:** When `_extractLocalText` returns an empty string after the model responds with HTTP 200, `synthesize` returns `null` at lines 125–127 with no log entry and no structured error response. The caller cannot distinguish this from "service not configured".
- **Why it matters:** A misconfigured Ollama model (e.g. wrong model name, memory exhaustion causing truncated output) will silently look like "local brain not running." Operators get no feedback.
- **Evidence:** `onyx_agent_local_brain_service.dart:125–127`
  ```dart
  if (text == null || text.trim().isEmpty) {
    return null;
  }
  ```
  Compare the HTTP error path at line 102 and the throw path at line 144 — both return a structured error response. The empty-text path does not.
- **Suggested follow-up:** Codex should verify whether any call site distinguishes `null` (unconfigured) from `null` (configured but empty). If not, replace the `return null` with `onyxAgentCloudBoostErrorResponse(providerLabel: providerLabel, errorSummary: 'Local brain returned no content', errorDetail: 'Provider responded with HTTP 200 but the message content was empty.')`.

---

### P2 — Full synthesize pipeline duplicated from OpenAiOnyxAgentCloudBoostService

- **Action: REVIEW**
- **Finding:** `OllamaOnyxAgentLocalBrainService.synthesize` (lines 56–150) is a structural copy of `OpenAiOnyxAgentCloudBoostService.boost` (cloud_boost_service.dart lines 267–376). The pattern is identical: guard on `isConfigured` + empty prompt → `client.post().timeout()` → HTTP status check → inner JSON decode try/catch → extract text → `onyxAgentCloudBoostResponseFromRawText` → `onyxAgentMergePlannerMaintenancePriorityHighlight`. Only the HTTP payload shape and extraction function differ.
- **Why it matters:** Any change to the shared post-decode pipeline (e.g. new pressure handling, new error surface) must be applied in two places. This has already produced a subtle divergence: the empty-text `null` return (P1 above) exists in both files, but the cloud service also has a `choices` fallback in `_extractText` that has no analogue in `_extractLocalText`.
- **Evidence:**
  - `onyx_agent_local_brain_service.dart:56–150`
  - `onyx_agent_cloud_boost_service.dart:267–376`
- **Suggested follow-up:** Consider whether a shared `_OnyxAgentSynthesizeCoordinator` function (or mixin) can own the `post → decode → extract → merge` steps, with each provider only supplying an HTTP body builder and a text extractor. This is an architecture decision — Zaks should approve the abstraction boundary before Codex implements it.

---

### P3 — `_systemPrompt` logic duplicated across both providers

- **Action: REVIEW**
- **Finding:** `OllamaOnyxAgentLocalBrainService._systemPrompt` (lines 152–179) and `OpenAiOnyxAgentCloudBoostService._systemPrompt` (cloud_boost_service.dart lines 378–414) share 11 of 13 rules verbatim. The scope-variable resolution (`clientId`, `siteId`, `incident`, `route`) is also duplicated. The two prompts have diverged in minor wording (e.g. rule 2, rule 3) with no indication this was intentional.
- **Why it matters:** Prompt rules are operational policy. Untracked divergence means the local and cloud brains may give subtly different guidance to operators on identical inputs, which is a safety concern for a security ops platform.
- **Evidence:**
  - `onyx_agent_local_brain_service.dart:152–179` — 13-rule local prompt
  - `onyx_agent_cloud_boost_service.dart:378–413` — 15-rule cloud prompt
  - Rule 3 (local): "Keep all device changes approval-gated." vs Rule 3 (cloud): "Keep execution local-first and approval-gated." — the local version drops "local-first".
  - Rule 5 (local) is absent from the cloud prompt; cloud has a unique rule 5 and rule 10.
- **Suggested follow-up:** Extract shared rule lines into a `_onyxAgentBasePromptRules()` top-level function in `onyx_agent_cloud_boost_service.dart`, then have each provider compose its prompt from the shared base plus provider-specific rules. This is a REVIEW item because it requires deciding which rule variant is canonical.

---

### P4 — `_resolveChatEndpoint` partial path edge case

- **Action: AUTO**
- **Finding:** If a caller passes an endpoint with a custom prefix path (e.g. `http://host:11434/ollama`), the resolver returns `http://host:11434/ollama/api/chat`. If the path is `/api` (partial), it returns `/api/api/chat`. This is a latent misconfiguration surface for deployments behind a reverse proxy.
- **Why it matters:** Ollama behind nginx at `/ollama/` is a common production setup. The current logic has no guard against double-appending segments.
- **Evidence:** `onyx_agent_local_brain_service.dart:182–194`
  ```dart
  // path = '/api' → '/api/api/chat'
  return endpoint.replace(path: '$normalizedPath/api/chat');
  ```
- **Suggested follow-up:** Codex should validate: does `_resolveChatEndpoint` need to handle the reverse-proxy case? If yes, add a check: if `normalizedPath.endsWith('/api/chat')` is already handled; add a check for `normalizedPath.contains('/api/chat')` to avoid double-append. Mark as AUTO if the fix is purely defensive.

---

### P5 — `model.trim()` called three times per request

- **Action: AUTO**
- **Finding:** `model.trim()` is called at line 53 (`isConfigured`), line 63 (for `providerLabel`), and line 76 (in the JSON body). In `isConfigured` this is fine, but within `synthesize` a single `final trimmedModel = model.trim()` at the top would remove the redundancy.
- **Why it matters:** Cosmetic/minor, but `model` is an immutable final field — the trim result is stable. Removing redundant calls signals intent and avoids future divergence if the field ever becomes mutable.
- **Evidence:** `onyx_agent_local_brain_service.dart:63, 76`
- **Suggested follow-up:** Trivial AUTO fix — `final trimmedModel = model.trim()` at the top of `synthesize`, replace downstream uses.

---

## Duplication

| Pattern | Files | Lines |
|---|---|---|
| Full synthesize/boost pipeline | `onyx_agent_local_brain_service.dart:56–150` vs `onyx_agent_cloud_boost_service.dart:267–376` | ~90 lines duplicated |
| `_systemPrompt` scope-variable resolution | `onyx_agent_local_brain_service.dart:153–163` vs `onyx_agent_cloud_boost_service.dart:382–393` | Identical pattern |
| System prompt rules 1–4, 6–9, 11–13 | Both files | 11 of 13 rules identical |
| Empty prompt / unconfigured guard | Both files | Identical 2-line guard |

Centralization candidate: a shared `_onyxAgentPostSynthesizeAndMerge` coordinator or a base class with a template method pattern. The HTTP body builder and text extractor can remain provider-specific.

---

## Coverage Gaps

### Untested paths in `OllamaOnyxAgentLocalBrainService`

1. **Empty prompt returns null** — No test verifies that `synthesize(prompt: '', ...)` returns `null` before making any HTTP call. The guard is at line 64 but is not exercised.

2. **Empty / blank model name returns null** — `isConfigured` returns `false` for `model = '   '`. No test covers this.

3. **TimeoutException path** — No test verifies that a hanging HTTP call returns a structured error. The `catch` block at line 137 would handle it, but the test suite has no mock that simulates a timeout. The error detail format is untested for this case.

4. **FormatException / invalid JSON path** — No test verifies the inner `on FormatException` branch (lines 111–123). A mock returning `'not json'` with HTTP 200 would cover this.

5. **`_extractLocalText` `response` fallback** — All tests mock the `message.content` shape. No test exercises the `map['response']` fallback path (line 209).

6. **`_resolveChatEndpoint` non-trivial path forms** — No unit test for:
   - Custom prefix path: `http://host/ollama` → should produce `http://host/ollama/api/chat`
   - Already-correct path: `http://host/api/chat` → should return unchanged
   - Partial path `/api` → currently produces `/api/api/chat` (the edge case in P4)

7. **Concurrent synthesize calls** — Not a unit test concern, but there is no `_isBusy` guard. If the same service instance is called concurrently, both requests proceed independently. This is probably acceptable, but it is undocumented.

### Test fragility

- `test/application/onyx_agent_local_brain_service_test.dart:33` — `expect(messages, hasLength(3))` is hardcoded. If `contextSummary` is ever made optional-empty in that test variant, or a scope field is added, this count check will break without indicating why.

---

## Performance / Stability Notes

- **No backoff on timeout** — The service makes a single attempt with a fixed 25-second timeout. For a local Ollama service that may be loading a model, a first-call cold start can easily exceed 25 seconds. Callers get an error response on cold-start rather than a retry. This is acceptable if the UI surfaces the error for manual retry, but worth confirming.

- **`http.Client` is injected but never closed** — The `client` parameter is injected (good for testing), but the service has no `dispose` or `close` method. If the `OllamaOnyxAgentLocalBrainService` is constructed with its own `http.Client()`, that client is never closed. Confirm at the injection site that the owning layer manages client lifecycle.

- **Large system prompt per request** — The 13-rule system prompt at lines 161–178 is reconstructed on every `synthesize` call. It is a `String` allocation of ~900 characters. This is not a performance concern at current call rates, but caching it as a computed field (or as a static once scope is stable) would be a minor improvement.

---

## Recommended Fix Order

1. **P1 (silent null on empty text)** — Highest operator-safety risk. The current behavior silently hides misconfigured model errors. AUTO fix.
2. **P4 (endpoint partial path)** — Latent deployment risk, trivial to harden. AUTO fix.
3. **P5 (redundant `model.trim()`)** — Trivial cleanup, same pass as P1. AUTO fix.
4. **Coverage gap: FormatException test** — Adds a missing error-path test for the inner JSON decode branch. AUTO fix.
5. **Coverage gap: empty prompt + empty model tests** — Two one-liner tests. AUTO fix.
6. **Coverage gap: `_extractLocalText` response fallback test** — Locks the secondary extraction path. AUTO fix.
7. **P3 (shared system prompt rules)** — Needs product decision on which rule variant is canonical. REVIEW before implementation.
8. **P2 (full pipeline duplication)** — Larger architectural cut. REVIEW before implementation.
