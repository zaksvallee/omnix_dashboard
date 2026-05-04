# Telegram AI Service Decomposition — 2026-05-04

**Author:** Zaks
**Repo baseline:** commit `69c0588` (chore(bin): delete orphan OpenAiTelegramAiAssistantService)
**Branch:** `main`, 1 commit ahead of `origin/main` at time of writing
**Status:** Plan locked, Module 5 extraction to follow as Step 4 of this session

---

## Why this doc exists

While scoping a planned 30-minute deletion of `OpenAiTelegramAiAssistantService` from `lib/application/telegram_ai_assistant_service.dart`, the audit revealed that the file is not a simple service — it is a 5,127-line prompt-shaping engine carrying ~90% reusable logic and ~9% replaceable service-implementation code, with a wide blast radius across the codebase. The bin/ copy of the same class was already orphaned by the Zara migration and was deleted cleanly (commit `69c0588`, 140 lines removed). The lib/ copy cannot be deleted in isolation — it is the visible tip of an architectural migration that was never completed when Zara shipped.

This doc captures the decomposition path so the Zara migration can be finished without losing the prompt-shaping investment that lives in this file.

---

## Current state

| Property | Value |
|---|---|
| File | `lib/application/telegram_ai_assistant_service.dart` |
| Lines | 5,127 |
| Top-level symbols (approx) | ~120 (3 classes, 1 abstract class, 6 enums, 4 data classes, ~100 functions) |
| Public types exported to other files | `TelegramAiAudience`, `TelegramAiDeliveryMode`, `TelegramAiDraftReply`, `TelegramAiSiteAwarenessSummary`, `TelegramAiAssistantService`, `UnconfiguredTelegramAiAssistantService`, `OpenAiTelegramAiAssistantService`, `OnyxFirstTelegramAiAssistantService` |
| Composition | 90% shaping/heuristic helpers (Survives), 9% service implementations (Replaceable), 1% interface/types (Survives) |

---

## Bucket summary

| Bucket | Lines (approx) | Symbols | Fate |
|---|---|---|---|
| **R — Replaceable** | ~480 | 3 classes (`Unconfigured`, `OpenAi`, `OnyxFirst`) | Delete after Zara migration completes |
| **S — Survives** | ~4,500 | ~100 functions, 6 enums, 4 data types, 1 abstract class | Extract to standalone modules; logic preserved |
| **W — Wire-rewrite** | (in `lib/main.dart`, 5 call sites) | 5 `.draftReply()` invocations + supporting context-builders | Rewire to Zara via adapter or direct migration |

---

## Dependency map (verified via grep)

### Consumers within `lib/application/`
- `telegram_ai_assistant_camera_health.dart` — imports `cameraHealthFactPacket`-shaped helpers; partial extraction already exists here
- `telegram_ai_assistant_clarifiers.dart` — imports clarifier flows tied to camera health
- `telegram_ai_assistant_site_view.dart` — imports site-view rendering helpers
- `telegram_client_quick_action_service.dart` — consumes `cameraHealthFactPacket` for quick-action gating
- `onyx_telegram_operational_command_service.dart` — heaviest external consumer; `cameraHealthFactPacket` referenced 20+ times

### Call sites of `.draftReply(`
- `lib/main.dart:16617`
- `lib/main.dart:17027`
- `lib/main.dart:30131`
- `lib/main.dart:39145`
- `lib/main.dart:39373`
- `bin/onyx_telegram_ai_processor.dart:1273` (now routes through `ZaraTelegramAiAssistantService`, not the lib copy)

### Wire-up
- `lib/main.dart:2767–2785` — `_buildTelegramAiAssistant()` constructs `OnyxFirstTelegramAiAssistantService` with three tiers: `onyxCloudBoost`, `onyxLocalBrain`, `directProvider: OpenAiTelegramAiAssistantService(...)`. **This is the wire-up that holds the lib `OpenAiTelegramAiAssistantService` alive.** The composite must be replaced or its `directProvider` must be Zara-backed.

### Shaping inputs flowing through `draftReply`
- `clientProfileSignals: List<String>`
- `preferredReplyExamples: List<String>`
- `preferredReplyStyleTags: List<String>`
- `learnedReplyExamples: List<String>`
- `learnedReplyStyleTags: List<String>`
- `recentConversationTurns: List<String>`
- `cameraHealthFactPacket: ClientCameraHealthFactPacket?`
- `siteAwarenessContext: String?`
- `siteAwarenessSummary: TelegramAiSiteAwarenessSummary?`

These are built upstream in `main.dart` (notably around line 29234–29348 in `_aiContext`-style builders) and passed to `draftReply`. **The Zara migration must preserve this data flow** — the inputs survive, the consumer changes.

---

## Proposed modules (6)

| # | Module | Path (proposed) | Lines | Content | Dependencies | Risk | Order |
|---|---|---|---|---|---|---|---|
| 1 | types | `lib/application/telegram_ai_types.dart` | ~180 | Enums (`TelegramAiAudience`, `TelegramAiDeliveryMode`), data classes (`TelegramAiDraftReply`, `TelegramAiSiteAwarenessSummary`), `_TelegramAiScopeProfile`, `_TelegramAiClientPromptContext`, abstract interface `TelegramAiAssistantService` | None | Low | 2nd |
| 5 | intent_resolver | `lib/application/telegram_ai_intent_resolver.dart` | ~800 | `_ClientReplyIntent`, `_FollowUpMode`, `_ClientLaneStage`, `_resolveClientReplyIntent`, `_resolveClientLaneStage`, `_intentFromRecentConversation`, all `_asksFor*` / `_hasRecent*` / `_challenges*` semantic-intent predicates | None | Low | **1st (today)** |
| 4 | tone_pack | `lib/application/telegram_ai_tone_pack.dart` | ~600 | `_ClientTonePack`, `_ClientProfile`, `_clientTonePackFor`, `_clientProfileFromSignals`, `_clientProfileFromSignalsAndTags`, all `*LeadForTonePack` generators (16+), `_clientFollowUpClosing` | types | Low | 3rd |
| 6 | reply_style | `lib/application/telegram_ai_reply_style.dart` | ~200 | `_PreferredReplyStyle`, `_preferredReplyStyleFromExamples`, `_preferredReplyStyleFromExamplesAndTags`, `_preferredReplyExamplesSnippet`, `_learnedReplyExamplesSnippet`, `_replyStyleTagsSnippet` | types | Low | 4th |
| 2 | prompt_builder | `lib/application/telegram_ai_prompt_builder.dart` | ~700 | `_telegramAssistantSystemPrompt`, `_telegramAssistantOnyxPrompt`, `_telegramAssistantOnyxContextSummary`, `_telegramAiClientPromptContext`, `_cameraHealthPromptSnippet`, all `_telegramAi*PromptValue` helpers | types, intent_resolver, tone_pack, reply_style | Medium | 5th |
| 3 | fallback_reply | `lib/application/telegram_ai_fallback_reply.dart` | ~1,500 | `_fallbackReply` (~440 lines), `_polishReply` (~1,640 lines), `_smsFallbackReply`, `_emptyPromptReply`, `_approvalDraftFallbackReply`, `_fieldTelemetryCountClarifierReply`, all heuristic predicates (`_shouldForceTruthGroundedClientFallback`, `_looksMechanicalClientReply`, `_replyConflictsWithCameraHealthFactPacket`, etc.) | All above | High | 6th |

After all 6 modules extract cleanly, `lib/application/telegram_ai_assistant_service.dart` collapses to ~480 lines containing only the 3 service-implementation classes. Those then get replaced by a Zara-backed implementation in module 7 (below) and the file is deleted.

---

## Module 7 — Zara-backed replacement (post-extraction)

| Property | Plan |
|---|---|
| Approach | Build `ZaraBackedTelegramAiAssistantService` (lib version, sibling to the bin's existing `ZaraTelegramAiAssistantService`) implementing the same `TelegramAiAssistantService` interface. Internally delegate to `ProviderBackedZaraService` and reuse the extracted prompt-builder / fallback / tone modules for shaping. |
| Composite fate | `OnyxFirstTelegramAiAssistantService` — decide: collapse entirely (Zara's `LlmProvider` already handles Haiku→Sonnet escalation, making the cloud-boost / local-brain / direct three-tier composite redundant) **or** keep as a graceful-degradation wrapper around Zara. Decision deferred to Session 5; default position is **collapse**. |
| Wire-rewrite at `lib/main.dart:2767` | `_buildTelegramAiAssistant()` returns the Zara-backed implementation directly, with the composite removed. |
| 5 `draftReply` call sites | Unchanged in shape — same parameters passed in. The implementation behind the interface is what changes. |

---

## Migration order

Bottom-up: extract leaves first (no internal deps), then consumers, then services. Each extraction is its own commit on `main`.

1. **(today)** Module 5 — intent_resolver
2. Module 1 — types
3. Module 4 — tone_pack
4. Module 6 — reply_style
5. Module 2 — prompt_builder
6. Module 3 — fallback_reply
7. Module 7 — Zara-backed service + main.dart rewire + delete legacy classes

---

## Per-module time estimates

| Module | Estimate |
|---|---|
| 5 — intent_resolver | 60–90 min |
| 1 — types | 30 min |
| 4 — tone_pack | 60 min |
| 6 — reply_style | 30 min |
| 2 — prompt_builder | 90 min |
| 3 — fallback_reply | 2–3 hr |
| 7 — Zara-backed service + main.dart rewire | 2 hr |
| Service deletion + final smoke | 30 min |
| **Total realistic effort** | **8–12 hr across 4–5 sessions** |

---

## Acceptance criteria per module

A module extraction is **done** when all of the following hold:

1. New module file exists at the proposed path with the extracted symbols and any necessary imports.
2. Original file imports the new module and re-exports public symbols if needed for backward compatibility during in-flight migration.
3. `dart analyze lib/` returns zero issues.
4. All original call sites compile without modification (no API breakage during the in-flight phase).
5. `dart compile kernel bin/onyx_telegram_ai_processor.dart` succeeds (catches any indirect breakage from shared imports).
6. The four-path Zara smoke (monitoring brief, incident summary, peak occupancy, fallback) shows no behavioral regression on real Telegram. *Note: this only matters once Module 7 ships; for Modules 1–6 the smoke is proof-of-no-regression on the legacy path.*
7. Commit message references this audit doc and lists the symbols moved.

---

## Risks and unknowns

- **`_polishReply` (~1,640 lines)** — the largest unknown. Deep coupling to camera health, recent conversation context, tone packs, and intent. Needs careful untangling in Module 3. May require its own sub-decomposition.
- **5 `main.dart` call sites** — each passes the full shaping context. Need to verify all 5 sites pass the same shape and that `_aiContext` builders feed them consistently. A divergent call site would mean Module 7's adapter has to handle multiple input shapes.
- **Cross-file imports from `camera_health`, `site_view`, `clarifiers`, `quick_action`, `operational_command`** — these files import helpers from the legacy file. After extraction, their imports must repoint to the new module paths. **Risk:** a missed import means a compile failure surfaces only when those specific files are touched.
- **`OnyxAgentCloudBoostService` / `OnyxAgentLocalBrainService`** — the composite's other two tiers. If the composite is collapsed in Module 7, these services lose their consumer here but are also referenced in `lib/ui/onyx_agent_page.dart`, `lib/ui/command_center_page.dart`, `lib/ui/onyx_route_command_center_builders.dart`, `lib/application/zara/theatre/zara_intent_parser.dart`, and `lib/smoke/zara_theatre_smoke.dart`. **They survive the migration**; only the Telegram-AI consumer of them changes.
- **Test coverage** — the legacy file has no visible test suite of its own. The four-path Zara smoke + manual Telegram verification is the regression net. Consider adding deterministic unit tests for the intent resolver as part of Module 5 since it's pure-function and naturally testable.
- **Approval-draft path** — `_approvalDraftFallbackReply` and `_approvalDraftReplyDriftsFromOperatorDraft` exist for a non-Zara approval-draft flow. Confirm whether this flow is still active or has been retired. If active, Zara needs an equivalent.

---

## Session plan

| Session | Scope | Deliverable |
|---|---|---|
| **1 (today)** | Audit + Module 5 (intent_resolver) | This doc + new module file + zero-regression analyze + commit |
| 2 | Module 1 (types) + Module 4 (tone_pack) | Two extraction commits |
| 3 | Module 6 (reply_style) + Module 2 (prompt_builder) | Two extraction commits |
| 4 | Module 3 (fallback_reply) | One extraction commit (highest-risk; allow full session) |
| 5 | Module 7 (Zara-backed service) + main.dart rewire + delete legacy classes + four-path smoke | Final commits + Telegram smoke verification |

---

## Today's target — Module 5 (intent_resolver)

**Path:** `lib/application/telegram_ai_intent_resolver.dart`

**Symbols to extract (~30):**

Enums:
- `_FollowUpMode`
- `_ClientReplyIntent`
- `_ClientLaneStage`

Resolution functions:
- `_resolveClientReplyIntent`
- `_resolveClientLaneStage`
- `_intentFromRecentConversation`
- `_followUpModeFromReplyText`

Lane-context predicates:
- `_isEscalatedLaneContext`
- `_isPressuredLaneContext`

Conversation/context helpers:
- `_recentConversationContextSnippet`
- `_hasTelemetrySummaryContext`
- `_hasTelemetryResponseArrivalSignal`
- `_hasExplicitCurrentOnSitePresence`
- `_hasExplicitCurrentMovementConfirmation`
- `_hasRecentMotionTelemetryContext`
- `_hasRecentPresenceVerificationContext`
- `_hasRecentContinuousVisualActivityContext`
- `_hasRecentCameraStatusContext`
- `_hasCurrentFrameConversationContext`
- `_recentThreadShowsUnusableCurrentImage`
- `_recentThreadDownCameraLabel`
- `_recentThreadMentionsRecordedEventVisuals`

Semantic-ask predicates (`_asksFor*`):
- `_asksWhyNoLiveCameraAccess`
- `_asksIfConnectionOrBridgeIsFixed`
- `_assertsLiveVisualAccessState`
- `_asksHypotheticalEscalationCapability`
- `_asksForCurrentSiteIssueCheck`
- `_asksForCurrentFrameMovementCheck`
- `_asksForSemanticMovementIdentification`
- `_asksForCurrentFramePersonConfirmation`
- `_asksForCurrentSiteView`
- `_asksWhyImageCannotBeSent`
- `_asksOvernightAlertingSupport`
- `_asksForBaselineSweep`
- `_asksAboutBaselineSweepStatus`
- `_asksAboutBaselineSweepEta`
- `_asksForWholeSiteBreachReview`
- `_asksAboutWholeSiteBreachReviewStatus`
- `_asksAboutWholeSiteBreachReviewEta`
- `_asksComfortOrMonitoringSupport`

Misc helpers:
- `_recentMotionTelemetryLeadLabel`
- `_challengesTelemetryPresenceSummary`
- `_challengesMissedMovementDetection`
- `_currentFrameConfirmationAreaLabel`
- `_isGenericStatusFollowUp`
- `_isBroadReassuranceAsk`
- `_containsCameraCoverageCountClaim`
- `_looksLikeShortFollowUp`
- `_hasRecentBaselineSweepContext`
- `_hasRecentWholeSiteBreachReviewContext`
- `_containsAny` (utility)

**Note:** Many of these are private (leading `_`) in the original file. Extracting them to a new file means they must become **public** (drop the leading `_`) so the original file can import and use them. Recommend `intent_resolver.` prefix on the public names where ambiguity would otherwise arise — e.g. `IntentResolver.asksForCurrentSiteView(text)`. Final naming convention to be decided during extraction.

**Open question for Module 5:** wrap them in a class (`class TelegramAiIntentResolver { static bool asksFor...() }`) or expose as top-level functions? **Recommend top-level functions** with a shared filename prefix (`tIRasksForCurrentSiteView`) — Dart idiomatic, no instance overhead, easier to grep. Final call when extraction begins.

**Acceptance criteria for today:**

1. New file exists at `lib/application/telegram_ai_intent_resolver.dart`
2. Original file imports it and all internal usages compile
3. `dart analyze lib/` zero issues
4. `dart compile kernel bin/onyx_telegram_ai_processor.dart` clean
5. Commit references this doc

---

## Tracking

- **Audit doc commit:** _to be appended after this doc is committed_
- **Module 5 commit:** _to be appended after extraction_
- **Cross-reference:** baseline commit `69c0588`

---

*End of audit.*
