/// Pure text utilities used by the Telegram AI subsystem.
///
/// Extracted from `telegram_ai_assistant_service.dart` as Module 0 of the
/// decomposition plan in `audit/telegram_ai_service_decomposition_2026-05-04.md`.
/// These are leaf helpers with no internal state — they intentionally have
/// zero dependencies on the rest of the Telegram AI subsystem so all later
/// modules can import them without creating cycles.
library;

import 'telegram_client_prompt_signals.dart';

/// Returns true if [text] contains any of the [needles].
///
/// Linear scan; intended for short needle lists where allocating a Set
/// would be heavier than the scan itself.
bool telegramAiContainsAny(String text, List<String> needles) {
  for (final needle in needles) {
    if (text.contains(needle)) {
      return true;
    }
  }
  return false;
}

/// Normalizes a reply text for heuristic matching.
///
/// Builds on [normalizeTelegramClientPromptSignalText] (the canonical
/// prompt-signal normalizer) by additionally collapsing underscores and
/// whitespace runs into single spaces. Used by intent resolution and
/// fallback-reply heuristics where punctuation and formatting variation
/// would otherwise produce false negatives.
String telegramAiNormalizeReplyHeuristicText(String value) {
  return normalizeTelegramClientPromptSignalText(value)
      .replaceAll('_', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
