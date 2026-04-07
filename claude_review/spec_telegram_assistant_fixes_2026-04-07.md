# Fix Spec: telegram_ai_assistant_service.dart — P1 Bugs

- Date: 2026-04-07
- Spec author: Claude Code
- Source audit: `claude_review/audit_telegram_ai_assistant_service_dart_2026-04-07.md`
- Target file: `lib/application/telegram_ai_assistant_service.dart`
- Read-only: yes (spec only — implementation by Codex)

---

## Overview

Two confirmed P1 bugs in `telegram_ai_assistant_service.dart`. Both are isolated, surgical fixes. Neither requires architectural changes.

- **Bug 1 (AUTO):** `catch (_)` at line 311 silently swallows all remote errors in `OpenAiTelegramAiAssistantService.draftReply`.
- **Bug 2 (REVIEW):** `_fallbackReply` at line 970 is missing the `learnedReplyExamples` parameter, causing every polished fallback path to discard learned reply memory while falsely claiming it was applied.

---

## Fix 1 — Silent `catch (_)` at line 311

### Location

`lib/application/telegram_ai_assistant_service.dart`, line 311.
Class: `OpenAiTelegramAiAssistantService`.
Method: `draftReply` (line 151).
Try block: lines 191–328.

### Problem

The `try` block at line 191 wraps the full HTTP call chain — request construction, `jsonEncode`, `client.post`, `jsonDecode` inside `_extractText`, and `_polishReply`. Every failure type collapses into one `catch (_)` with no logging and no error type distinction:

```dart
// CURRENT — line 311
} catch (_) {
  return TelegramAiDraftReply(
    text: _fallbackReply(...),
    usedFallback: true,
    usedLearnedApprovalStyle: learnedReplyExamples.isNotEmpty,
  );
}
```

`TimeoutException`, `SocketException`, `http.ClientException`, `FormatException` (from `jsonDecode`), and programming errors all produce identical silent fallback replies with `providerLabel: 'fallback'`. There is no observable signal at any layer that the provider failed.

### Required change

Replace `catch (_)` with typed branches. The catch block must:

1. Log or surface the error type so callers can distinguish transient network failures from programming errors.
2. Preserve the existing fallback reply behaviour for all non-programming errors (do not rethrow to the caller — this is a live Telegram lane).
3. Rethrow `AssertionError`, `TypeError`, and similar programming errors — these should not be silently swallowed.

**Exact replacement for lines 311–328:**

```dart
} on TimeoutException catch (e, st) {
  // ignore: avoid_print
  debugPrint('[TelegramAiAssistant] OpenAI timeout: $e\n$st');
  return TelegramAiDraftReply(
    text: _fallbackReply(
      audience: audience,
      messageText: cleaned,
      scope: scope,
      deliveryMode: deliveryMode,
      clientProfileSignals: clientProfileSignals,
      preferredReplyExamples: preferredReplyExamples,
      preferredReplyStyleTags: preferredReplyStyleTags,
      learnedReplyStyleTags: learnedReplyStyleTags,
      recentConversationTurns: recentConversationTurns,
      cameraHealthFactPacket: cameraHealthFactPacket,
    ),
    usedFallback: true,
    usedLearnedApprovalStyle: learnedReplyExamples.isNotEmpty,
  );
} on http.ClientException catch (e, st) {
  // ignore: avoid_print
  debugPrint('[TelegramAiAssistant] OpenAI HTTP client error: $e\n$st');
  return TelegramAiDraftReply(
    text: _fallbackReply(
      audience: audience,
      messageText: cleaned,
      scope: scope,
      deliveryMode: deliveryMode,
      clientProfileSignals: clientProfileSignals,
      preferredReplyExamples: preferredReplyExamples,
      preferredReplyStyleTags: preferredReplyStyleTags,
      learnedReplyStyleTags: learnedReplyStyleTags,
      recentConversationTurns: recentConversationTurns,
      cameraHealthFactPacket: cameraHealthFactPacket,
    ),
    usedFallback: true,
    usedLearnedApprovalStyle: learnedReplyExamples.isNotEmpty,
  );
} on FormatException catch (e, st) {
  // ignore: avoid_print
  debugPrint('[TelegramAiAssistant] OpenAI response parse error: $e\n$st');
  return TelegramAiDraftReply(
    text: _fallbackReply(
      audience: audience,
      messageText: cleaned,
      scope: scope,
      deliveryMode: deliveryMode,
      clientProfileSignals: clientProfileSignals,
      preferredReplyExamples: preferredReplyExamples,
      preferredReplyStyleTags: preferredReplyStyleTags,
      learnedReplyStyleTags: learnedReplyStyleTags,
      recentConversationTurns: recentConversationTurns,
      cameraHealthFactPacket: cameraHealthFactPacket,
    ),
    usedFallback: true,
    usedLearnedApprovalStyle: learnedReplyExamples.isNotEmpty,
  );
} catch (e, st) {
  // Unexpected error — rethrow if it is a programming error.
  if (e is AssertionError || e is TypeError) {
    rethrow;
  }
  // ignore: avoid_print
  debugPrint('[TelegramAiAssistant] OpenAI unexpected error: $e\n$st');
  return TelegramAiDraftReply(
    text: _fallbackReply(
      audience: audience,
      messageText: cleaned,
      scope: scope,
      deliveryMode: deliveryMode,
      clientProfileSignals: clientProfileSignals,
      preferredReplyExamples: preferredReplyExamples,
      preferredReplyStyleTags: preferredReplyStyleTags,
      learnedReplyStyleTags: learnedReplyStyleTags,
      recentConversationTurns: recentConversationTurns,
      cameraHealthFactPacket: cameraHealthFactPacket,
    ),
    usedFallback: true,
    usedLearnedApprovalStyle: learnedReplyExamples.isNotEmpty,
  );
}
```

### Notes for Codex

- `debugPrint` is already available in Flutter. If the project uses a structured logger, substitute accordingly — the key requirement is that the error type and stack trace are observable.
- Codex should check whether `http` is imported as `package:http/http.dart as http` — use whichever alias is already in the file.
- The `learnedReplyExamples` omission in the `_fallbackReply` calls inside this catch block is fixed separately in Fix 2 below. Apply both fixes together.
- If Codex extracts a `_buildFallback` helper (P2 AUTO in the audit), the typed catch branches collapse further. That is a follow-on refactor, not a prerequisite.

### Tests required

- `'openai assistant catch TimeoutException returns fallback without throwing'`
- `'openai assistant catch ClientException returns fallback without throwing'`
- `'openai assistant catch FormatException returns fallback without throwing'`
- Verify `usedFallback: true` and `providerLabel` in each case.
- Verify that `AssertionError` from inside the try block is not swallowed (rethrown).

---

## Fix 2 — `_fallbackReply` drops `learnedReplyExamples`

### Location

`lib/application/telegram_ai_assistant_service.dart`.

Three locations are affected:

| Location | Line | Description |
|---|---|---|
| `_fallbackReply` signature | 970–981 | Missing parameter |
| `_polishReply` call to `_fallbackReply` (force-truth path) | 1450–1461 | Missing argument |
| `_polishReply` call to `_fallbackReply` (mechanical-reply path) | 1464–1475 | Missing argument |
| `_polishReply` call to `_fallbackReply` (prefer-fallback path) | 1485–1496 | Missing argument |
| `catch (_)` call to `_fallbackReply` (error path — see Fix 1) | 313–324 | Missing argument |

### Problem

`_fallbackReply` (line 970) accepts `preferredReplyExamples` but has no `learnedReplyExamples` parameter:

```dart
// CURRENT — lines 970–981
String _fallbackReply({
  required TelegramAiAudience audience,
  required String messageText,
  required _TelegramAiScopeProfile scope,
  required TelegramAiDeliveryMode deliveryMode,
  List<String> clientProfileSignals = const <String>[],
  List<String> preferredReplyExamples = const <String>[],
  List<String> preferredReplyStyleTags = const <String>[],
  List<String> learnedReplyStyleTags = const <String>[],    // ← style tags present
  List<String> recentConversationTurns = const <String>[],
  ClientCameraHealthFactPacket? cameraHealthFactPacket,
  // learnedReplyExamples is ABSENT
})
```

As a result, `_preferredReplyStyleFromExamplesAndTags` at line 1002 is called with only `preferredReplyExamples`, missing the learned examples entirely:

```dart
// CURRENT — lines 1002–1006
final preferredReplyStyle = _preferredReplyStyleFromExamplesAndTags(
  preferredReplyExamples: preferredReplyExamples,  // ← preferred only, no learned
  preferredReplyStyleTags: preferredReplyStyleTags,
  learnedReplyStyleTags: learnedReplyStyleTags,
);
```

The correct pattern — used at lines 1505–1512 inside the non-fallback path of `_polishReply` — is to pass combined examples via `_combinedReplyExamples`:

```dart
// REFERENCE — lines 1505–1512 (correct pattern already in use)
preferredReplyStyle: _preferredReplyStyleFromExamplesAndTags(
  preferredReplyExamples: _combinedReplyExamples(
    preferredReplyExamples: preferredReplyExamples,
    learnedReplyExamples: learnedReplyExamples,
  ),
  preferredReplyStyleTags: preferredReplyStyleTags,
  learnedReplyStyleTags: learnedReplyStyleTags,
),
```

The outer `draftReply` (line 326) sets `usedLearnedApprovalStyle: learnedReplyExamples.isNotEmpty` on the returned `TelegramAiDraftReply`, meaning the reply claims learned style was applied when `_fallbackReply` was called — but `_fallbackReply` never received the examples and could not have applied them.

### Required change — Part A: `_fallbackReply` signature

Add `learnedReplyExamples` to the `_fallbackReply` signature at line 977 (after `preferredReplyExamples`):

```dart
// REPLACE lines 970–981
String _fallbackReply({
  required TelegramAiAudience audience,
  required String messageText,
  required _TelegramAiScopeProfile scope,
  required TelegramAiDeliveryMode deliveryMode,
  List<String> clientProfileSignals = const <String>[],
  List<String> preferredReplyExamples = const <String>[],
  List<String> learnedReplyExamples = const <String>[],   // ← ADD THIS LINE
  List<String> preferredReplyStyleTags = const <String>[],
  List<String> learnedReplyStyleTags = const <String>[],
  List<String> recentConversationTurns = const <String>[],
  ClientCameraHealthFactPacket? cameraHealthFactPacket,
})
```

### Required change — Part B: `_preferredReplyStyleFromExamplesAndTags` call inside `_fallbackReply`

Update the call at lines 1002–1006 to pass combined examples using the existing `_combinedReplyExamples` helper:

```dart
// REPLACE lines 1002–1006
final preferredReplyStyle = _preferredReplyStyleFromExamplesAndTags(
  preferredReplyExamples: _combinedReplyExamples(
    preferredReplyExamples: preferredReplyExamples,
    learnedReplyExamples: learnedReplyExamples,
  ),
  preferredReplyStyleTags: preferredReplyStyleTags,
  learnedReplyStyleTags: learnedReplyStyleTags,
);
```

### Required change — Part C: all `_fallbackReply` call sites in `_polishReply`

Add `learnedReplyExamples: learnedReplyExamples,` to each of the three `_fallbackReply` calls inside `_polishReply`. `_polishReply` already has `learnedReplyExamples` in its signature (line 1421) — it just does not forward it.

**Call site 1 — force-truth path (lines 1450–1461):**

```dart
// REPLACE lines 1450–1461
return _fallbackReply(
  audience: audience,
  messageText: messageText,
  scope: scope,
  deliveryMode: deliveryMode,
  clientProfileSignals: clientProfileSignals,
  preferredReplyExamples: preferredReplyExamples,
  learnedReplyExamples: learnedReplyExamples,           // ← ADD
  preferredReplyStyleTags: preferredReplyStyleTags,
  learnedReplyStyleTags: learnedReplyStyleTags,
  recentConversationTurns: recentConversationTurns,
  cameraHealthFactPacket: cameraHealthFactPacket,
);
```

**Call site 2 — mechanical-reply path (lines 1464–1475):**

```dart
// REPLACE lines 1464–1475
return _fallbackReply(
  audience: audience,
  messageText: messageText,
  scope: scope,
  deliveryMode: deliveryMode,
  clientProfileSignals: clientProfileSignals,
  preferredReplyExamples: preferredReplyExamples,
  learnedReplyExamples: learnedReplyExamples,           // ← ADD
  preferredReplyStyleTags: preferredReplyStyleTags,
  learnedReplyStyleTags: learnedReplyStyleTags,
  recentConversationTurns: recentConversationTurns,
  cameraHealthFactPacket: cameraHealthFactPacket,
);
```

**Call site 3 — prefer-fallback path (lines 1485–1496):**

```dart
// REPLACE lines 1485–1496
return _fallbackReply(
  audience: audience,
  messageText: messageText,
  scope: scope,
  deliveryMode: deliveryMode,
  clientProfileSignals: clientProfileSignals,
  preferredReplyExamples: preferredReplyExamples,
  learnedReplyExamples: learnedReplyExamples,           // ← ADD
  preferredReplyStyleTags: preferredReplyStyleTags,
  learnedReplyStyleTags: learnedReplyStyleTags,
  recentConversationTurns: recentConversationTurns,
  cameraHealthFactPacket: cameraHealthFactPacket,
);
```

**Call site 4 — catch block (lines 313–324, same as Fix 1):**

This call site also omits `learnedReplyExamples`. The Fix 1 replacement code above already omits it — Codex must add it there as well when applying Fix 2 in parallel:

```dart
// ADD to each _fallbackReply call in the catch branches (Fix 1 code)
learnedReplyExamples: learnedReplyExamples,
```

### Required change — Part D: other `_fallbackReply` call sites to audit

Codex must search the full file for all remaining `_fallbackReply(` calls and confirm whether each one has access to a `learnedReplyExamples` variable in its scope. Specific known sites outside `_polishReply`:

- `UnconfiguredTelegramAiAssistantService.draftReply` — line 113. `learnedReplyExamples` is in scope (parameter at line 106). Add `learnedReplyExamples: learnedReplyExamples,` to the call.
- `OpenAiTelegramAiAssistantService.draftReply` — lines 176, 237, 258, 290, 313. `learnedReplyExamples` is in scope (parameter at line 160). Add `learnedReplyExamples: learnedReplyExamples,` to each call.

Run: `grep -n '_fallbackReply(' lib/application/telegram_ai_assistant_service.dart` to get the full list before patching.

### Notes for Codex

- `_combinedReplyExamples` already exists at line 4220 and does exactly `[...preferredReplyExamples, ...learnedReplyExamples]`. No new helper needed.
- `_preferredReplyStyleFromExamplesAndTags` does not take `learnedReplyExamples` directly — it takes a combined list via the `preferredReplyExamples` parameter. The pattern at lines 1505–1512 is the reference implementation to follow.
- The parameter ordering in the new signature (Part A) should place `learnedReplyExamples` immediately after `preferredReplyExamples` to mirror the `draftReply` abstract signature (lines 80–83) and the `_polishReply` signature (lines 1421–1422).
- This is a `REVIEW` action. Zaks must confirm before Codex implements — specifically whether `_preferredReplyStyleFromExamplesAndTags` should receive combined examples or preferred-only inside `_fallbackReply`. The audit recommendation is combined (matching the non-fallback path), but the product intent should be confirmed.

### Tests required

- `'fallback reply uses learned reply examples when polished reply is mechanical'` — pass non-empty `learnedReplyExamples` with a `shareStyle` indicator; assert reply style reflects learned style, not default.
- `'fallback reply uses learned reply examples when truth-grounded override fires'` — same assertion via the force-truth path.
- `'TelegramAiDraftReply usedLearnedApprovalStyle matches actual learned style application'` — pass non-empty `learnedReplyExamples`; assert both the flag and the reply content reflect the examples.
- `'unconfigured assistant forwards learnedReplyExamples to fallbackReply'` — verify `usedLearnedApprovalStyle: true` when examples are non-empty.

---

## Dependency Between Fixes

Apply Fix 1 and Fix 2 together in the same commit. Every `_fallbackReply(...)` call inside the Fix 1 typed catch branches must also receive `learnedReplyExamples: learnedReplyExamples,` (Part D of Fix 2). If applied separately, Fix 1 introduces four more call sites that silently drop learned examples.

---

## Acceptance Criteria

| # | Criterion |
|---|---|
| 1 | `catch (_)` at line 311 no longer exists in the file |
| 2 | `TimeoutException`, `http.ClientException`, `FormatException` each have their own named catch branch with a `debugPrint` (or project logger) call |
| 3 | `AssertionError` and `TypeError` are rethrown, not silently swallowed |
| 4 | `_fallbackReply` signature includes `learnedReplyExamples` |
| 5 | All `_fallbackReply` call sites in `_polishReply` (3 sites) forward `learnedReplyExamples` |
| 6 | All `_fallbackReply` call sites in `draftReply` catch branches forward `learnedReplyExamples` |
| 7 | `_preferredReplyStyleFromExamplesAndTags` inside `_fallbackReply` receives combined examples via `_combinedReplyExamples` |
| 8 | All new tests pass; existing tests are green |
