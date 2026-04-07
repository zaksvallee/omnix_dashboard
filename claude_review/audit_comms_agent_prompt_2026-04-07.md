# Audit: ONYX Comms Agent — System Prompt, Context Injection, and Response Quality

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/application/telegram_ai_assistant_service.dart` · `lib/application/telegram_ai_assistant_camera_health.dart` · `lib/application/telegram_ai_assistant_clarifiers.dart` · `lib/application/telegram_ai_assistant_site_view.dart` · `lib/application/telegram_client_prompt_signals.dart` · `lib/application/telegram_ai_starter_examples.dart` · `lib/main.dart` (call sites)
- Read-only: yes

---

## Executive Summary

The client-facing comms agent has a well-structured system prompt with clear tone guidelines, camera-specific heuristic overrides, and a layered fallback system. The core identity and communication rules are solid. However, there are six material quality gaps that directly affect reply accuracy or debuggability: duplicated context fields, absent role attribution in conversation history, a very tight output token budget, hardcoded client names in tone examples, a silent multi-path fallback that offers no failure discrimination, and an admin call site that passes zero context. These are individually low-effort to fix and cumulatively meaningful.

---

## What Looks Good

- **Camera health override layer is strong.** The heuristic pre-emption chain in `_fallbackReply` and `_cameraHealthFactPacketReply` ensures camera status facts are never fabricated by the LLM. The `cameraHealthFactPacket` is treated as source-of-truth and the prompt explicitly instructs the model not to contradict it.
- **Mechanical reply detection is reliable.** `_looksMechanicalClientReply` catches internal-scope leaks ("ticket", "case id", "as an ai", "language model", internal ID patterns) and rejects them silently before delivery.
- **Prompt normalization signal library is comprehensive.** `telegram_client_prompt_signals.dart` covers a wide range of phrasings per intent with typo correction. The `_containsAny` pattern is fast and consistent.
- **Approval-draft pipeline is well-wired.** The `approvalDraft` delivery mode correctly gates all AI replies behind admin notification before client delivery. Pending drafts are persisted to ledger.
- **Temperature and determinism.** `temperature: 0.2` is appropriate for a comms agent that must not speculate.

---

## Findings

### P1 — watchStatus and cameraStatus are always identical
- Action: AUTO
- Both fields in `_TelegramAiClientPromptContext` are derived from the same `ClientCameraHealthFactPacket.status` enum via the same switch logic (lines 658–691). The LLM always sees two fields with the same value.
- Why it matters: Redundant fields consume prompt tokens and can confuse the model into thinking these represent distinct dimensions of system state. In practice, the only differentiator (watch vs. camera) comes from the `hasCurrentVisualConfirmation` / `hasContinuousVisualCoverage` flags, which are correctly used in `_telegramAiWatchStatusPromptValue` but produce the same output categories as `_telegramAiCameraStatusPromptValue`.
- Evidence: `telegram_ai_assistant_service.dart:658–691`
- Suggested follow-up: Either collapse to a single `monitoringStatus` field, or differentiate them meaningfully — e.g., `watchStatus` = operational posture (active/paused/offline), `cameraStatus` = live visual availability (available/limited/offline).

### P1 — Admin draftReply call site passes zero context
- Action: AUTO
- In `main.dart:14334–14340`, the admin path calls `draftReply(audience: admin, messageText:..., clientId:..., siteId:...)` with no `recentConversationTurns`, no `cameraHealthFactPacket`, and no `clientProfileSignals`.
- Why it matters: The admin system prompt branch does include a `recentContext` block, but it renders as `"none"` on every call. The admin agent is effectively blind to all conversation history and camera health state, despite both being available at that call site.
- Evidence: `lib/main.dart:14334–14340` vs. client path `lib/main.dart:14699–14714`
- Suggested follow-up: Wire the admin call site through the same `_telegramAiClientDraftingContextForScope` fetch as the client path, or at minimum pass `recentConversationTurns` and `cameraHealthFactPacket`.

### P1 — Hardcoded client site name in TONE EXAMPLES
- Action: REVIEW
- The system prompt's TONE EXAMPLES block (line 587) hardcodes `"MS Vallee Residence"` as a specific site label inside Bad/Good examples sent to the LLM for every client conversation.
- Why it matters: The LLM may pattern-match on this label and echo it to a different client — particularly in boundary cases where the model interpolates names into its output. Even if it does not leak literally, the presence of a real site name in a shared template is a privacy and correctness risk.
- Evidence: `telegram_ai_assistant_service.dart:587–592`
- Suggested follow-up: Replace with a neutral placeholder such as `"[your site]"` or `"the site"` in all three Bad/Good pairs.

### P2 — No role attribution in conversation history
- Action: REVIEW
- `_recentConversationContextSnippet` (line 4378) joins the last 6 conversation turns as a flat newline-separated string with no "Client:" / "ONYX:" speaker prefix. The LLM cannot distinguish who said what in the history.
- Why it matters: In multi-turn exchanges where the client pushes back on a prior ONYX reply, the model has no signal about which side of the conversation each turn came from. This degrades quality on follow-up questions, challenges, and escalation replies.
- Evidence: `telegram_ai_assistant_service.dart:4378–4388`; turn source data comes from `_telegramAiTruthWeightedConversationTurns` (`main.dart:23605`)
- Suggested follow-up: Prefix each turn with a speaker label derived from the message `author` field before joining — e.g., `"Client: ..."` / `"ONYX: ..."`.

### P2 — max_output_tokens: 220 is too tight for incident replies
- Action: DECISION
- The OpenAI call is capped at 220 output tokens (line 203). The system prompt itself instructs the model to use 3-sentence replies for most scenarios, and examples like the confirmed-threat response ("There's activity at your North Gate. Guard has been alerted. I'm watching it now.") fit within this. However, incident summaries that include guard status, camera state, and a next step can exceed 220 tokens before a closing sentence.
- Why it matters: Truncated incident replies look unprofessional and may omit the "clear next step" that Communication Rule 5 requires.
- Evidence: `telegram_ai_assistant_service.dart:203`; Communication Rules at line 573–585
- Suggested follow-up: Evaluate raising to 280–320 tokens for the `telegramLive` delivery mode. The `approvalDraft` path is less time-sensitive and could stay at 220.

### P2 — Camera health data injected twice with different framing
- Action: AUTO
- The prompt contains camera status in two places: the `CURRENT CONTEXT` block (cameraStatus, watchStatus as short enum strings) and the `INTERNAL STATUS FACTS` block (`cameraHealthFactPacket.toPromptBlock()` — structured multi-field output). Both describe the same camera state.
- Why it matters: Redundant framings of the same fact in a single prompt increase token use and create a risk of the model weighting one representation inconsistently against the other — especially when the enum strings say "offline" but the toPromptBlock output uses more nuanced language.
- Evidence: `telegram_ai_assistant_service.dart:554–556` (INTERNAL STATUS FACTS) vs. `telegram_ai_assistant_service.dart:566–572` (CURRENT CONTEXT cameraStatus / watchStatus)
- Suggested follow-up: Remove `watchStatus` and `cameraStatus` from `CURRENT CONTEXT` and rely solely on the structured `INTERNAL STATUS FACTS` block, which is already labeled as source-of-truth.

### P2 — Multiple silent fallback paths produce identical `usedFallback: true`
- Action: REVIEW
- The following conditions all return `TelegramAiDraftReply(usedFallback: true)` with no differentiation: HTTP error (non-2xx), timeout, empty/null parse, `_looksMechanicalClientReply`, `_shouldForceTruthGroundedClientFallback`, `_shouldPreferFallbackForClientReply`.
- Why it matters: The operator panel and the AI ledger cannot distinguish a network failure from a content-safety rejection from a deliberate heuristic override. This makes debugging degraded sessions very difficult.
- Evidence: `telegram_ai_assistant_service.dart:237–271` (HTTP failure), `telegram_ai_assistant_service.dart:1437–1489` (_polishReply fallback gates)
- Suggested follow-up: Add a `fallbackReason` field to `TelegramAiDraftReply` and tag each path distinctly (e.g., `httpError`, `parseFailure`, `mechanicalReply`, `truthGrounded`, `preferFallback`).

### P3 — guardOnSite derived entirely from conversation turn string matching
- Action: REVIEW (suspicion — low confidence)
- `_telegramAiGuardOnSitePromptValue` infers guard presence only by scanning `recentConversationTurns` for specific phrases (line 762–780). No live guard-sync or dispatch state is queried at drafting time.
- Why it matters: If the guard is on site but no recent conversation turn mentions it explicitly, the field returns "unknown" — limiting the model's ability to answer guard-related questions accurately.
- Evidence: `telegram_ai_assistant_service.dart:762–780`
- Suggested follow-up: Verify whether `_cameraHealthFactPacketForScope` or a guard-sync call could supply confirmed on-site presence at drafting time, and pass it through as a structured fact rather than inferred from text.

### P3 — clientName / siteName derived from ID strings, not database records
- Action: REVIEW (suspicion)
- `_scopeProfileFor` at line 3268 builds human-readable labels by stripping the "CLIENT-" / "SITE-" prefix and title-casing what remains. It does not query the actual client or site name from Supabase.
- Why it matters: If `clientId` is an opaque UUID or an ID that does not humanize cleanly (e.g., "CLIENT-UK-002"), the model will address the client as "Uk 002" or similar.
- Evidence: `telegram_ai_assistant_service.dart:3268–3323`; `_humanizeScopeLabel` strips well-structured prefixes but has no database lookup path
- Suggested follow-up: Confirm whether `clientId` / `siteId` values passed at call sites are always human-readable slugs, or whether a lookup against `_monitoringSiteProfileFor` (already available at `main.dart:23616`) should be passed into `_scopeProfileFor` as a name hint.

---

## Duplication

- `_telegramAiWatchStatusPromptValue` and `_telegramAiCameraStatusPromptValue` are parallel functions with identical structure, identical switch/if chains, and identical output values. They only differ in one additional `hasCurrentVisualConfirmation` check in the watch path. These could be collapsed into a single function with an enum parameter.
  - Files: `telegram_ai_assistant_service.dart:658–691`
- `_containsAny` is defined in both `telegram_ai_assistant_service.dart` (line 3325) and `telegram_client_prompt_signals.dart` (line 212) as identical private implementations.
  - Centralisation candidate: a shared `_TelegramAiStringUtils` helper or promote the one in `telegram_client_prompt_signals.dart` to a package-visible utility.

---

## Coverage Gaps

- No test verifies that `_looksMechanicalClientReply` actually blocks internal scope IDs. The `CLIENT-/SITE-/REGION-` regex (line 1688) is the only runtime guard against ID leakage in LLM replies — a single test with a fabricated LLM response containing an internal ID would lock this.
- No test verifies that the admin call site at `main.dart:14334` cannot leak client-specific data from a prior session (i.e., that `recentConversationTurns` defaulting to empty does not cause the model to hallucinate context from its own training).
- No test covers the `_polishReply → _shouldForceTruthGroundedClientFallback → simpleThanks` path. A reply containing "thank you" currently triggers silent fallback — this should be a named test case.
- `_extractTimestampFromPromptContext` only matches ISO 8601 format. No test verifies behavior when timestamps appear as human-readable strings ("at 2 PM", "this morning"). The `lastActivity` and `lastGuardCheckin` prompt fields silently return "unknown" in those cases.

---

## Performance / Stability Notes

- `_recentConversationContextSnippet` takes the first 6 turns (`take(6)`). For high-volume client threads, the most recent turn is always included, but the selection is not recency-weighted beyond that. In a 20-message thread, turn 1 could be from hours ago. No stability risk, but prompt freshness could degrade.
- `_preferredReplyExamplesSnippet` and `_learnedReplyExamplesSnippet` both `take(3)`. The caller (`_telegramAiClientDraftingContextForScope`) uses `telegramAiPreferredReplyExamplesForScope` to pre-filter. If that function returns more than 3, the service layer silently drops the rest. No risk, but the selection strategy is opaque at the AI service layer.

---

## Recommended Fix Order

1. **Remove hardcoded "MS Vallee Residence" from TONE EXAMPLES** — privacy risk, one-line fix, zero logic change.
2. **Add `fallbackReason` to `TelegramAiDraftReply`** — makes every fallback path debuggable; no behavior change.
3. **Wire admin call site to pass recentConversationTurns and cameraHealthFactPacket** — the data is available, the parameter is already in the signature.
4. **Add role attribution to recentConversationTurns snippet** — requires threading the `author` field through `_telegramAiTruthWeightedConversationTurns`; improves multi-turn reply quality.
5. **Collapse watchStatus / cameraStatus or differentiate them meaningfully** — removes prompt redundancy and the duplicate camera health injection in CURRENT CONTEXT vs. INTERNAL STATUS FACTS.
6. **Evaluate raising max_output_tokens to 280–320** — requires a product decision on latency/cost vs. reply completeness.
7. **De-duplicate `_containsAny`** — low-risk cleanup.
