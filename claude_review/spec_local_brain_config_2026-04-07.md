# Spec: ONYX Local Brain — Ollama Model Configuration

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/application/onyx_agent_local_brain_service.dart`, `lib/application/onyx_agent_cloud_boost_service.dart`, `lib/ui/onyx_agent_page.dart` (routing surface)
- Read-only: yes

---

## Current State

| Parameter | Value |
|---|---|
| Model | `ONYX_AGENT_LOCAL_MODEL` env var — **no default set** |
| Provider | `ONYX_AGENT_LOCAL_PROVIDER` — defaults to `ollama` |
| Endpoint | `ONYX_AGENT_LOCAL_ENDPOINT` — defaults to `http://127.0.0.1:11434` |
| Temperature | Hardcoded `0.2` |
| Timeout | Hardcoded `25s` |
| Token limit | **Not set** — no `num_predict` in Ollama options |
| Context injection | 4 system messages (base, follow-up, operator focus, contextSummary) |

If `ONYX_AGENT_LOCAL_MODEL` is empty or `ONYX_AGENT_LOCAL_ENABLED` is false, the service resolves to `UnconfiguredOnyxAgentLocalBrainService` and all `synthesize()` calls return `null`. The local brain is **off by default**.

Routing is user-controlled via `_preferCloudBoost` toggle in `onyx_agent_page.dart:1510`. There is no automatic complexity-based routing between local and cloud.

---

## 1. Best Model for Security Ops Context

### Primary Recommendation: `mistral:7b-instruct-q5_K_M`

**Why:**
- Mistral 7B Instruct has the best JSON instruction compliance in the sub-10B class. The ONYX system prompt demands a 12-key JSON schema (`summary`, `recommended_target`, `confidence`, `why`, `missing_info`, `primary_pressure`, `context_highlights`, `operator_focus_note`, `follow_up_label`, `follow_up_prompt`, `follow_up_status`, `text`). Models that drift to prose fail silently — `_extractLocalText` will return a blob and the advisory parser will produce a null advisory, dropping all structured routing guidance.
- At q5_K_M quantisation: fits in 6GB VRAM, ~35 token/s on Apple M-series, ~28 token/s on RTX 3060. Stays inside the 25s timeout under normal load.
- Temperature 0.2 is the right choice for this model — keeps confidence scores and recommended_target values stable.

**Pull command:**
```
ollama pull mistral:7b-instruct-q5_K_M
```

**Env vars:**
```
ONYX_AGENT_LOCAL_ENABLED=true
ONYX_AGENT_LOCAL_PROVIDER=ollama
ONYX_AGENT_LOCAL_MODEL=mistral:7b-instruct-q5_K_M
ONYX_AGENT_LOCAL_ENDPOINT=http://127.0.0.1:11434
```

---

### Tier 2: `llama3.1:8b-instruct-q5_K_M` (if better reasoning needed)

Use this if you observe the Mistral model:
- failing to populate `missing_info` correctly on ambiguous patrol/dispatch prompts
- hallucinating `recommended_target` values outside the allowed enum (dispatchBoard, tacticalTrack, cctvReview, clientComms, reportsWorkspace)

Llama 3.1 has stronger multi-step reasoning and tighter enum adherence. ~15% slower than Mistral 7B at equivalent quantisation.

**Pull command:**
```
ollama pull llama3.1:8b-instruct-q5_K_M
```

---

### Tier 3: `llama3.1:70b-instruct-q4_K_M` (workstation only)

Reserve for incident correlation (`OnyxAgentCloudIntent.correlation`) where multi-hop reasoning over site, camera, and patrol thread context matters. Requires ~42GB VRAM or unified memory. Will regularly breach the 25s timeout on CPU-offloaded runs — bump `requestTimeout` to 60s if using this model.

---

### Do Not Use

| Model | Reason |
|---|---|
| `llama2:*` | Ignores all but the first `system` message. ONYX sends 3–4 system messages — follow-up and operator focus context will be silently dropped. |
| `phi3:mini` | Context window (4k) is too short for the full scope + follow-up + contextSummary injection at peak load. |
| `codellama:*` | Code-tuned models resist plain prose rules. Will produce markdown code blocks instead of JSON objects. |
| `gemma2:2b` | Fails to maintain JSON structure across the 12-key schema reliably at temperature 0.2. |

---

## 2. Optimal System Prompt

### Current Issues

1. **No token cap in Ollama options.** `options: {'temperature': 0.2}` has no `num_predict`. A slow model under load can produce a 2000-token response and block the thread for 90+ seconds. The OpenAI path caps at `max_output_tokens: 280`. The local path should match.

2. **Multiple system role messages — model-dependent behaviour.** Ollama models handle consecutive `system` messages differently. Mistral and Llama 3.1 support it correctly. Older or unchecked community models may merge or drop subsequent system messages. The current injection of follow-up and operator focus as separate system messages is a silent failure risk.

3. **Rule 7 fallback is underspecified.** `"If JSON is not possible, return plain text."` — some models interpret "not possible" as "inconvenient" and return prose for complex prompts. The system prompt should rank JSON above prose more firmly, with a concrete failure mode stated.

4. **Intent is passed as a name string only.** `intent.name` produces `"camera"`, `"patrol"`, etc. The model has no semantic map of what those intent lanes mean operationally. A one-line gloss per intent would improve targeting accuracy.

### Recommended System Prompt (for Codex to implement)

Replace the body of `_systemPrompt()` in `onyx_agent_local_brain_service.dart:161` with the following (keeping the same dynamic variable insertions):

```
You are the ONYX local controller brain — offline-first, running on-device.
Route: $route | Scope: client=$clientId site=$siteId incident=$incident | Intent: ${intent.name} (${_intentGloss(intent)}).

OUTPUT RULES (strict):
- Return ONLY a single JSON object with these exact keys: summary, recommended_target, confidence, why, missing_info, primary_pressure, context_highlights, operator_focus_note, follow_up_label, follow_up_prompt, follow_up_status, text.
- recommended_target must be exactly one of: dispatchBoard, tacticalTrack, cctvReview, clientComms, reportsWorkspace.
- follow_up_status must be exactly one of: pending, unresolved, overdue, cleared.
- confidence is a float 0.0–1.0.
- context_highlights is a string array, ordered by operational urgency.
- If JSON output is not achievable, return a single plain text sentence only — no markdown.

OPERATIONAL RULES:
1. Be concise and operationally useful. No narrative padding.
2. Do not invent dispatches, ETAs, arrivals, or completed actions.
3. All device state changes are approval-gated — never present them as done.
4. Never echo, request, or repeat secrets, passwords, or credentials.
5. If an outstanding follow-up is unresolved or overdue, keep it warm unless a human-safety signal outranks it.
6. If operator focus is preserved, respect it — explain urgent items elsewhere without reassigning the desk recommendation unless safety clearly requires it.
7. Echo primary_pressure from context when present. Valid values: planner maintenance, overdue follow-up, unresolved follow-up, operator focus hold, active signal watch.
8. If a planner maintenance priority is in context, surface it as the first context_highlights item when it materially affects the next step.
```

Add a private helper `_intentGloss(OnyxAgentCloudIntent intent)` that maps each intent to a one-line description:

| Intent | Gloss |
|---|---|
| camera | CCTV / DVR device review |
| telemetry | sensor and alarm signal review |
| patrol | guard route and check-in tracking |
| client | client-facing communications |
| report | incident reporting and documentation |
| correlation | cross-site signal correlation |
| dispatch | guard or response unit deployment |
| admin | system and account administration |
| general | general operator query |

### Recommended Ollama Options Block (for Codex to implement)

In `onyx_agent_local_brain_service.dart:97`, replace:
```dart
'options': {'temperature': 0.2},
```
with:
```dart
'options': {
  'temperature': 0.2,
  'num_predict': 320,
  'stop': ['\n\n\n'],
},
```

`num_predict: 320` matches the OpenAI `max_output_tokens: 280` budget with a small margin for JSON closing syntax. The stop sequence cuts runaway newline-padded responses.

---

## 3. Context Injection Strategy

### Current Architecture

```
messages: [
  { role: system,  content: _systemPrompt(scope, intent) },      // always
  { role: system,  content: pendingFollowUpContext },             // conditional
  { role: system,  content: operatorFocusContext },               // conditional
  { role: system,  content: 'Operational context: $summary' },   // conditional
  { role: user,    content: cleanedPrompt },
]
```

### Risk: Silent Drop on Non-Conforming Models

If a model only honours the first `system` message (Llama 2, Phi-2, some GGUF community repacks), the follow-up and operator focus context is silently lost. The response will appear valid but will be missing the `follow_up_status` and `operator_focus_note` population that the UI surface depends on.

### Recommendation: Consolidate Secondary Context Into Base System Message

For Codex to validate: consider injecting follow-up and operator focus context as labelled sections appended to the base system message rather than as separate system messages. This collapses the risk across all models:

```
// In _systemPrompt(), append conditional sections at the end:
if (scope.hasPendingFollowUp) {
  buffer.write('\n\nPENDING FOLLOW-UP:\n${onyxAgentPendingFollowUpContextForScope(scope)}');
}
if (scope.hasOperatorFocusContext) {
  buffer.write('\n\nOPERATOR FOCUS:\n${onyxAgentOperatorFocusContextForScope(scope)}');
}
```

Then remove the conditional secondary system messages from the `messages` list in `synthesize()`.

**Trade-off:** This increases system prompt token length by up to ~300 tokens when both contexts are active. At `mistral:7b-instruct-q5_K_M`, this is within comfortable context window limits and does not materially affect latency.

### Operational Context Summary (`contextSummary`)

Keep `'Operational context: ${contextSummary.trim()}'` as a separate system message — it is a live-generated runtime summary and its separation from the static system prompt is intentional and correct. No change recommended here.

---

## 4. When to Route Local vs OpenAI

### Current Routing Logic (`onyx_agent_page.dart:1510`)

User-toggled `_preferCloudBoost`. When false → local (if configured). When true → OpenAI (if available). No automatic routing based on prompt complexity or intent.

### Recommended Routing Decision Matrix

| Condition | Recommended Route | Rationale |
|---|---|---|
| Network unavailable | **Local** | Only viable path. |
| `OnyxAgentCloudIntent.correlation` | **OpenAI** | Multi-hop incident correlation exceeds reliable local reasoning for sub-70B models. |
| `OnyxAgentCloudIntent.dispatch` | **OpenAI** | Dispatch decisions carry safety consequences — higher-quality reasoning is justified. |
| `OnyxAgentCloudIntent.report` | **Local** | Report drafting is deterministic and low-stakes. Prefer local to avoid cloud latency. |
| `OnyxAgentCloudIntent.camera` | **Local** | Camera state queries are tightly scoped — local handles them well. |
| `OnyxAgentCloudIntent.telemetry` | **Local** | Same as camera — structured, bounded scope. |
| `OnyxAgentCloudIntent.patrol` | **Local** | Patrol state is short-context, local is sufficient. |
| `OnyxAgentCloudIntent.client` | **OpenAI** | Client-facing language quality matters — cloud produces better prose. |
| `OnyxAgentCloudIntent.admin` | **OpenAI** | Admin queries may touch sensitive policy; cloud is auditable. |
| `OnyxAgentCloudIntent.general` | **Local first, cloud fallback** | Use local for speed; escalate to cloud if local returns null advisory. |
| Prompt length > 400 chars | **OpenAI** (prefer) | Long prompts may exceed context budget for smaller quantised models. |
| `pendingFollowUpAgeMinutes > 60` | **OpenAI** (prefer) | Overdue follow-up is high-stakes; better reasoning warranted. |

### Implementation Approach (for Codex)

This decision matrix is currently not implemented. The routing is entirely user-driven. If automatic routing is desired, Codex should implement a `_resolvePreferredBrainProvider()` method in `_OnyxAgentPageState` that returns `BrainProvider.local` or `BrainProvider.cloud` based on these conditions, and override `_preferCloudBoost` at call time rather than relying solely on the user toggle.

**Action:** `DECISION` — this changes user-visible routing behaviour. Zaks should approve before Codex implements.

---

## Summary Checklist

| Item | Action | Priority |
|---|---|---|
| Set `ONYX_AGENT_LOCAL_MODEL=mistral:7b-instruct-q5_K_M` | `AUTO` | P1 — local brain is non-functional without it |
| Add `num_predict: 320` and stop sequence to Ollama options | `AUTO` | P1 — prevents timeout risk |
| Add `_intentGloss()` helper and strengthen JSON output rules in system prompt | `AUTO` | P2 — reduces hallucinated target values |
| Consolidate secondary system messages into base system prompt | `REVIEW` | P2 — model compatibility fix, behavioural change |
| Implement automatic routing matrix by intent | `DECISION` | P3 — product choice |
