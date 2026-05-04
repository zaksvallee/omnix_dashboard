# Telegram AI Service Decomposition — Amendment 2 (2026-05-04)

**Amends:** `audit/telegram_ai_service_decomposition_2026-05-04.md` (commit `e9d7970`) and `audit/telegram_ai_service_decomposition_amendment_2026-05-04.md` (commit `5f5b37c`)
**Status:** Discovery — captured during Module 4 pre-flight, before extraction
**Branch state at time of writing:** 1 commit ahead of `origin/main` (`ba45275` Module 1 extract)
**Modules shipped to date:** 0 (text_utils, `c5caae9`), 5 (intent_resolver, `f44ccf5`), 1 (types, `ba45275`)

---

## Why this amendment exists

During Module 4 (tone_pack) pre-flight, CC's symbol-body read at Step 7 surfaced two private types in the head file that Module 4 functions reference. Both block Module 4 from being a clean standalone library:

| Type | Defined at (head) | Refs in Module 4 zone | Module fit |
|---|---|---|---|
| `_TelegramAiScopeProfile` | line 23 (class) | 18 (parameter type in 17+ tone generators + `_clientTonePackFor`) | Foundational — belongs in Module 1 |
| `_PreferredReplyStyle` | line 3548 (enum) | 9 (parameter type + `.shareStyle` / `.defaultStyle` value comparisons in `_clientFollowUpClosing`) | IS Module 6 (reply_style) per original audit |

Cycle check (Module 5 referencing Module 4): clean. Zero matches. The blocker is foundational-type ordering, not a circular dependency.

This amendment records:

1. The discovery itself (two blockers, where they're used, why they're not yet placed)
2. The decision to promote `_TelegramAiScopeProfile` into Module 1 via a follow-up amendment commit (rather than dragging it into Module 4)
3. The decision to swap Module 4 ↔ Module 6 ordering (Module 6 ships before Module 4)
4. The updated module order with revised time estimates

---

## Discovery details

### `_TelegramAiScopeProfile` — Module 1 expansion candidate

Class definition lives at line 23 of `lib/application/telegram_ai_assistant_service.dart`. Used as a parameter type across the library. Module 4 zone (lines ~3550–4130) shows 18 references — every tone-lead generator and the resolver entry point (`_clientTonePackFor`) accept a `_TelegramAiScopeProfile` parameter.

CC's report also flagged use beyond the Module 4 zone:
- `_smsFallbackReply` (line ~3687, in Module 3 zone) references it
- Likely additional consumers in Module 2 (prompt_builder) territory

**This is a public-by-shape, library-private-by-name foundational type.** It carries scope context (client_id, site_id, derived labels) through the reply pipeline. Every downstream module needs it.

**Decision: promote to Module 1.** Make it public (`TelegramAiScopeProfile`), move into `telegram_ai_types.dart`. This means:
- Module 4 imports `telegram_ai_types.dart` for the type
- Module 3 imports `telegram_ai_types.dart` for the type
- Module 2 imports `telegram_ai_types.dart` for the type
- One canonical home, no duplication, no module having to import another module just to get a parameter type

**Cost:** small Module 1 amendment commit. Pre-flight reference count needed (likely 50+ references across the 4 library files), sed-rename `_TelegramAiScopeProfile` → `TelegramAiScopeProfile` across all four files, move the class definition to `telegram_ai_types.dart`, verify.

### `_PreferredReplyStyle` — already Module 6

Single-line enum declaration at line 3548. Per the original audit's Module 6 scope, this enum is already named as Module 6's anchor:

> Module 6 (reply_style): `_PreferredReplyStyle`, `_preferredReplyStyleFromExamples`, `_preferredReplyStyleFromExamplesAndTags`, `_preferredReplyExamplesSnippet`, `_learnedReplyExamplesSnippet`, `_replyStyleTagsSnippet`. ~200 lines.

Pulling it into Module 4 would conflate two modules and leave Module 6 as a stub. Correct placement: extract as part of Module 6 in its scheduled extraction.

**Decision: ship Module 6 first.** This means swapping the Module 4/6 order — Module 6 ships before Module 4, not after.

---

## Updated module order (corrected by empirical dependency graph)

The original audit ordered modules bottom-up by symbol count. Empirical pre-flight shows the dependency graph differs slightly: Module 6 is a true leaf, and Module 4 depends on it indirectly via `_PreferredReplyStyle` (used in `_clientFollowUpClosing`).

Corrected order:

| # | Module | Status | Estimate | Notes |
|---|---|---|---|---|
| 0 | text_utils | ✅ done (`c5caae9`) | — | 2 symbols, 278 refs migrated |
| 5 | intent_resolver | ✅ done (`f44ccf5`) | — | 50 symbols, 290 refs migrated |
| 1 | types (initial) | ✅ done (`ba45275`) | — | 4 public types, 160 refs preserved via re-export |
| 6 | reply_style | **next** | ~30 min | `_PreferredReplyStyle` + 5 helpers (`_preferredReplyStyleFromExamples`, `_preferredReplyStyleFromExamplesAndTags`, `_preferredReplyExamplesSnippet`, `_learnedReplyExamplesSnippet`, `_replyStyleTagsSnippet`) |
| 1+ | types amendment: `_TelegramAiScopeProfile` | after M6 | ~30 min | Promote private class → public type. Sed-rename across 4 library files. Move class definition into `telegram_ai_types.dart`. Possibly second small additions of related scope helpers if they're also private-by-name. |
| 4 | tone_pack | after Module 1+ amendment | ~60 min | 30 symbols. Imports: text_utils (M0), intent_resolver (M5), types (M1 with `TelegramAiScopeProfile`), reply_style (M6 for `TelegramAiPreferredReplyStyle`). |
| 2 | prompt_builder | later | ~90 min | Cross-references all of M0/M1/M4/M5/M6 |
| 3 | fallback_reply | later | 2-3 hr | The hard one (`_polishReply` 1,640 lines, `_fallbackReply` 440 lines) |
| 7 | Zara service + main.dart rewire | final | ~2 hr | Replaces head's `OnyxFirstTelegramAiAssistantService` composite with Zara-backed implementation |
| — | service deletion + smoke | final | ~30 min | |

**Total remaining: ~7 hours across 3-4 sessions** (slightly higher than original estimate because of the Module 1 amendment step, but the amendment unblocks every later module so it's net-time-saving overall).

---

## Updated session plan

| Session | Scope | Deliverable |
|---|---|---|
| (done) 1 | Audit + Module 0 + Module 5 | 4 commits on `main` |
| (done) 2 | Module 1 (initial) + LPR disable | 5 commits on `main` |
| (this session, partial) | This amendment commit | 1 commit |
| Next session — focused 3-step block (~135 min) | Module 6 + Module 1 amendment + Module 4 | 3 commits |
| Session after | Module 2 (prompt_builder) | 1 commit |
| Session after that | Module 3 (fallback_reply) | 1 commit (dedicated session for the hard one) |
| Final session | Module 7 (Zara service) + main.dart rewire + delete legacy classes + four-path Telegram smoke | Final commits + verification |

---

## Why "promote to Module 1" rather than "drag into Module 4"

Three architectural arguments for Path A (the chosen path):

1. **`_TelegramAiScopeProfile` is used outside Module 4.** Confirmed in `_smsFallbackReply` (Module 3 territory) and likely in Module 2 (prompt_builder). If it lived in Module 4, Modules 2 and 3 would have to `import 'telegram_ai_tone_pack.dart';` purely to get a parameter type — semantically wrong and architecturally backwards.

2. **Module 1's contract is "public types for the subsystem."** `_TelegramAiScopeProfile` matches that contract — it's a value-type carrying scope context, not behavior. The original audit's Module 1 scope listed `TelegramAiAudience`, `TelegramAiDeliveryMode`, `TelegramAiDraftReply`, `TelegramAiSiteAwarenessSummary`. `TelegramAiScopeProfile` is the same shape of thing.

3. **Promotion is reversible if needed; conflation is not.** Once `_TelegramAiScopeProfile` is in Module 4, dragging it back out is itself a refactor. Putting it in Module 1 from the start preserves clean module boundaries.

---

## Pre-flight checks for the next session's three-step block

When the next session opens, the standard pre-flight checks from amendment 1 still apply, plus:

```bash
# 1. Confirm library structure unchanged
grep -n "^part \|^library " lib/application/telegram_ai_assistant_service.dart
grep -rn "^part of 'telegram_ai_assistant" lib/ bin/

# 2. Confirm Module 1 (types) is still as shipped
grep -n "^class TelegramAi\|^enum TelegramAi" lib/application/telegram_ai_types.dart

# 3. Verify _TelegramAiScopeProfile total reference count across all 4 library files
grep -h "_TelegramAiScopeProfile" \
  lib/application/telegram_ai_assistant_service.dart \
  lib/application/telegram_ai_assistant_camera_health.dart \
  lib/application/telegram_ai_assistant_clarifiers.dart \
  lib/application/telegram_ai_assistant_site_view.dart \
  | wc -l

# 4. Confirm no external library defines or calls _TelegramAiScopeProfile
grep -rn "\b_TelegramAiScopeProfile\b" lib/ bin/ | grep -v 'lib/application/telegram_ai_assistant_'

# 5. Verify Module 6 symbol references (as inputs to Module 6 prompt)
for sym in _PreferredReplyStyle _preferredReplyStyleFromExamples \
           _preferredReplyStyleFromExamplesAndTags \
           _preferredReplyExamplesSnippet _learnedReplyExamplesSnippet \
           _replyStyleTagsSnippet; do
  total=$(grep -h "$sym" \
    lib/application/telegram_ai_assistant_service.dart \
    lib/application/telegram_ai_assistant_camera_health.dart \
    lib/application/telegram_ai_assistant_clarifiers.dart \
    lib/application/telegram_ai_assistant_site_view.dart \
    2>/dev/null | wc -l | tr -d ' ')
  printf "%-50s %s\n" "$sym" "$total"
done
```

---

## Tracking

| Item | Status |
|---|---|
| Baseline commit | `69c0588` |
| Original audit | `e9d7970` |
| Amendment 1 (part-of structure) | `5f5b37c` |
| Module 0 (text_utils) | `c5caae9` |
| Module 5 (intent_resolver) | `f44ccf5` |
| Module 1 (types initial) | `ba45275` |
| LPR profile + disable trio | `90243f3` + `9ac4dc1` + `4623288` |
| **This amendment (Amendment 2)** | _to be appended after commit_ |
| Module 6 (reply_style) | pending |
| Module 1 amendment (`TelegramAiScopeProfile` promotion) | pending |
| Module 4 (tone_pack) | pending — blocked on Module 6 + Module 1 amendment |
| Modules 2, 3, 7 | later sessions |

---

*End of amendment 2.*
