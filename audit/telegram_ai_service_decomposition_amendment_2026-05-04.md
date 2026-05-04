# Telegram AI Service Decomposition — Amendment 2026-05-04

**Amends:** `audit/telegram_ai_service_decomposition_2026-05-04.md` (commit `e9d7970`)
**Status:** Retrospective — incorporates findings from Modules 0 and 5
**Modules shipped at time of writing:**
- Module 0 (`c5caae9`) — `telegram_ai_text_utils.dart`
- Module 5 (`f44ccf5`) — `telegram_ai_intent_resolver.dart`

---

## Why this amendment exists

The original audit (commit `e9d7970`) was authored from a head-only inventory of `lib/application/telegram_ai_assistant_service.dart`. During execution of Module 0 (Phase 4a), CC's pre-flight grep discovered that the file is the head of a 4-file Dart `part`/`part of` library — three additional files share its library-private scope. This finding changed the migration mechanics and the call-site counts materially. Module 0 was completed with the corrected scope; Module 5 followed the same pattern.

This amendment captures:

1. The corrected library structure
2. Reusable technique notes from both extractions (sed mechanics, function-end detection, dependency-import patterns, same-name-twin handling)
3. The updated module order and time estimates based on what we learned
4. Standing pre-flight checks that should run before every future extraction

The original audit is preserved unchanged. This amendment extends it.

---

## Modules shipped

### Module 0 — `telegram_ai_text_utils.dart` (commit `c5caae9`)

| Property | Value |
|---|---|
| Symbols extracted | 2 (both functions) |
| References migrated | 278 (266 `_containsAny` + 12 `_normalizeReplyHeuristicText`) |
| Files touched | 5 (head + 3 parts + new module) |
| Stat | +320 / -297 |
| New module size | 37 lines |
| Verification | `dart analyze lib/` clean, `dart compile kernel` clean |

Renames:
- `_containsAny` → `telegramAiContainsAny`
- `_normalizeReplyHeuristicText` → `telegramAiNormalizeReplyHeuristicText`

### Module 5 — `telegram_ai_intent_resolver.dart` (commit `f44ccf5`)

| Property | Value |
|---|---|
| Symbols extracted | 50 (3 enums + 47 functions) |
| References migrated | 290 across the 4-file library |
| Files touched | 5 (head + 3 parts + new module) |
| Stat | +1,250 / -1,182 (net +68) |
| New module size | 1,044 lines |
| Verification | `dart analyze lib/` clean, `dart compile kernel` clean |

Notable: every reference count matched the audit's pre-flight expected values exactly (zero drift).

---

## Corrected library structure

The `telegram_ai_assistant_service` library is a 4-file Dart `part`/`part of` library:

| File | Role | Lines (post Modules 0+5) |
|---|---|---|
| `telegram_ai_assistant_service.dart` | Library head | ~4,750 (was 5,730 before extractions) |
| `telegram_ai_assistant_camera_health.dart` | part of | 618 |
| `telegram_ai_assistant_clarifiers.dart` | part of | 432 |
| `telegram_ai_assistant_site_view.dart` | part of | 553 |

The head declares the parts at lines 12–14 with `part 'telegram_ai_assistant_*.dart';`. Each part file's first non-blank line is `part of 'telegram_ai_assistant_service.dart';`.

### Migration mechanics for `part` libraries

Three rules govern every extraction from this library:

1. **Imports live on the head only.** Part files cannot have their own `import` directives — they inherit from the head. New module imports go on `telegram_ai_assistant_service.dart`; the parts see the new symbols via inherited scope.

2. **Call sites must be rewritten in all four files.** When a private symbol is renamed to a public symbol, every call site across the library — head + parts — must be updated. A sed-replace targeting only the head will produce a compile error in the part files.

3. **Library-private symbols cross part boundaries; public symbols leave the library.** A `_helper()` defined in the head is callable from any part file unchanged. A `helper()` (no underscore) extracted to a new library file is callable from anywhere via import. The migration is moving symbols from the first category to the second.

---

## Technique notes (reusable across future extractions)

### 1. BSD sed lacks `\b` word boundaries

**Symptom:** `sed -i.bak 's/_oldName\b/newName/g' file` on macOS leaves residual `_oldName` strings in suffixed identifiers (`_oldNameSuffix` is incorrectly skipped or the boundary doesn't anchor properly).

**Workaround used in Modules 0 and 5:** Negative-class capture for the trailing non-identifier character.

```bash
# Capture the non-identifier character into \1, restore it after replacement
sed -E -i.bak 's/_oldName([^a-zA-Z0-9_])/newName\1/g' file
```

For prefix boundary as well (when needed for symbols that could be substrings of other identifiers):

```bash
sed -E -i.bak 's/([^a-zA-Z0-9_])_oldName([^a-zA-Z0-9_])/\1newName\2/g' file
```

For Modules 0 and 5 the trailing-only form was sufficient because the leading underscore on private names already provided enough left-side disambiguation.

**Alternative:** install GNU sed via Homebrew (`brew install gnu-sed`), invoke as `gsed` — supports `\b` natively. Not used in Modules 0–5 for portability; the negative-class form works on default macOS.

### 2. Function-end detection: avoid brace-counting

**Symptom:** Naive brace-counting to find a function's closing `}` over-shrinks any function whose signature has named-parameter blocks. Example:

```dart
bool myFunction({
  required String x,
  required int y,
}) {
  return x.isNotEmpty && y > 0;
}
```

A brace counter starting at the signature line increments on `{` of the parameter block, decrements on `})` of the parameter block, and falsely concludes the function ends there — actual body lines are missed.

**Pattern used in Module 5:** "Next top-level definition" anchor. After the function signature line, scan forward for the next line that begins (column 1) with a top-level definition keyword (`bool `, `String `, `int `, `void `, `Future`, `Stream`, `enum `, `class `, `abstract class `, `mixin `, `_<TypeName> `, `<TypeName> `, etc.). The function's closing `}` is the line immediately before that next definition.

For ranges to delete with sed:

```bash
# Find the line of the next top-level definition after line N
awk -v start=$((N+1)) 'NR >= start && /^([A-Z_][A-Za-z0-9_<>?, ]* |bool |String\??|int |double |void |Future|Stream|enum |class |abstract )/ {print NR; exit}' file
```

This was robust across all 50 Module 5 symbols. For symbols whose body ends right before a top-level comment or blank-line block, the next-definition anchor still works correctly because sed's range delete is inclusive only of the lines requested.

### 3. Dependency-import pattern

Each new module file ends up importing a small set of external libraries. The pattern observed in Modules 0 and 5:

| Import | Origin | Why |
|---|---|---|
| `telegram_ai_text_utils.dart` | Module 0 | Pure-text helpers used by all other modules |
| `telegram_client_prompt_signals.dart` | Pre-existing | Public `asksForTelegramClient*` predicates, `normalizeTelegramClientPromptSignalText` |
| `client_camera_health_fact_packet_service.dart` | Pre-existing | `ClientCameraHealthFactPacket` type used widely |

For Module 5, these three were the complete external-import set. Future modules will likely need the same three at minimum, plus possibly:

- `telegram_ai_intent_resolver.dart` (Module 5) — for `TelegramAi*` enums and predicates referenced from prompt builder, fallback reply, tone pack
- `telegram_ai_types.dart` (Module 1, future) — for `TelegramAiAudience`, `TelegramAiDeliveryMode`, `TelegramAiDraftReply`, `TelegramAiSiteAwarenessSummary`

**Cross-module-delegation tracking:** when a module's pre-flight reveals that some functions delegate to public predicates living in another module (e.g., Module 5's delegation to `asksForTelegramClient*` in `telegram_client_prompt_signals.dart`), record this in the commit message and consider whether the dependency suggests a future consolidation.

### 4. Same-name twin functions in unrelated libraries

Both Module 0 and Module 5 found independent same-name copies of private symbols in unrelated libraries:

- Module 0: `_containsAny` defined in 5 unrelated libraries (`events_review_page`, `client_camera_health_fact_packet_service`, `vehicle_visit_ledger_projector`, `monitoring_yolo_detection_service`, `simulation/scenario_runner`)
- Module 5: `_recentThreadShowsUnusableCurrentImage` and `_recentThreadDownCameraLabel` defined as class methods in `onyx_telegram_operational_command_service.dart` with different signatures (taking `OnyxTelegramCommandRequest` vs `List<String>`)

These are unrelated copies and stay untouched. The leading underscore makes them library-private; renaming the version in the telegram_ai_assistant_service library does not affect them. Confirm by inspecting each match — if it's a function definition (`bool _name(`) or class method, it's an independent copy.

If a match is a *call* in another library with no local definition, that's a different situation — it indicates a hidden cross-library coupling that must be resolved before extraction. (Modules 0 and 5 found none of these.)

### 5. Pre-flight reference counting

For modules with many symbols, run a pre-flight reference count across all 4 library files before drafting the CC prompt. The expected counts are pre-baked into the prompt as verification anchors:

```bash
for sym in <list of private symbols>; do
  total=$(grep -h "$sym" \
    lib/application/telegram_ai_assistant_service.dart \
    lib/application/telegram_ai_assistant_camera_health.dart \
    lib/application/telegram_ai_assistant_clarifiers.dart \
    lib/application/telegram_ai_assistant_site_view.dart \
    2>/dev/null | wc -l | tr -d ' ')
  printf "%-50s %s\n" "$sym" "$total"
done
```

Each count = 1 definition + N references. Pre-baking these into CC's verification step lets it detect drift and STOP if the file has changed materially since the audit.

---

## Standing pre-flight checks (run before every future module extraction)

```bash
# 1. Confirm library structure is unchanged
grep -n "^part \|^library " lib/application/telegram_ai_assistant_service.dart
grep -rn "^part of 'telegram_ai_assistant" lib/ bin/

# 2. Reference-count every symbol slated for extraction (across all 4 files)
# (use the loop above with the module's symbol list)

# 3. Confirm no external library defines or calls the private symbols
for sym in <private symbol list>; do
  grep -rn "\b${sym}\b" lib/ bin/ 2>/dev/null | grep -v 'lib/application/telegram_ai_assistant_'
done

# 4. Confirm new public names don't collide with existing public symbols
for sym in <new public name list>; do
  grep -rn "\b${sym}\b" lib/ bin/ 2>/dev/null
done

# 5. Read each symbol body and identify private dependencies NOT in the
#    extraction scope. These are blockers — STOP and re-scope rather than
#    silently dragging them in.
```

If any of these surface unexpected results, STOP and amend the extraction plan before proceeding.

---

## Updated module order and estimates

Based on what Modules 0 and 5 taught us, the remaining decomposition plan is updated as follows:

| # | Module | Path | Estimate | Notes |
|---|---|---|---|---|
| 1 | types | `telegram_ai_types.dart` | 15 min | `TelegramAiAudience` and `TelegramAiDeliveryMode` already public — pure file-move plus `TelegramAiDraftReply`, `TelegramAiSiteAwarenessSummary` data class moves. Smallest remaining module. |
| 4 | tone_pack | `telegram_ai_tone_pack.dart` | 60 min | ~30 symbols, mid-size enums (`_ClientTonePack`, `_ClientProfile`), 16+ tone-lead functions. Similar shape to Module 5 but smaller. |
| 6 | reply_style | `telegram_ai_reply_style.dart` | 30 min | ~6 symbols. Smallest non-types module. |
| 2 | prompt_builder | `telegram_ai_prompt_builder.dart` | 90 min | Cross-references to Modules 1, 4, 5, 6. Medium risk. |
| 3 | fallback_reply | `telegram_ai_fallback_reply.dart` | 2–3 hr | The hard one. `_polishReply` (1,640 lines) and `_fallbackReply` (440 lines) are the unknowns. May need its own decomposition. |
| 7 | Zara-backed service + main.dart rewire | (replaces head) | 2 hr | After all extractions complete, head collapses to ~480 lines of service classes, which then get replaced by a Zara-backed implementation. |
| — | Service deletion + smoke | — | 30 min | Final cleanup |

**Total remaining: 7–8 hr across 3–4 sessions.**

---

## Updated session plan

| Session | Scope | Deliverable |
|---|---|---|
| (done) 1 | Audit + Module 0 + Module 5 | 4 commits on `main` |
| 2 | Module 1 (types) + Module 4 (tone_pack) | Two extraction commits, ~75 min |
| 3 | Module 6 (reply_style) + Module 2 (prompt_builder) | Two extraction commits, ~120 min |
| 4 | Module 3 (fallback_reply) | Dedicated session, 2–3 hr |
| 5 | Module 7 (Zara-backed service) + main.dart rewire + delete legacy classes + four-path Telegram smoke | Final commits + verification |

---

## Tracking

| Item | Status |
|---|---|
| Baseline commit | `69c0588` |
| Original audit | `e9d7970` |
| Module 0 (text_utils) | `c5caae9` |
| Module 5 (intent_resolver) | `f44ccf5` |
| This amendment | _to be appended_ |
| Modules 1, 4, 6, 2, 3 | Pending future sessions |
| Module 7 (Zara-backed service) | Pending — final |

---

*End of amendment.*
