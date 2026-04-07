import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/telegram_bridge_service.dart';

const telegramHighRiskEscalationCopy =
    'Understood. This has been escalated to the control room now.';
const telegramRouteFallbackCopy = 'I could not route that request yet.';

String telegramTranscriptFromMessages(
  Iterable<TelegramBridgeMessage> messages,
) => messages.map((message) => message.text).join('\n---\n');

String telegramFollowUpReplyFromTranscript(String transcript) {
  final replies = transcript.split('\n---\n');
  expect(replies.length, greaterThanOrEqualTo(2));
  return replies.last;
}

void expectDeterministicTelegramReadTranscript(
  String transcript, {
  required String expectedHeading,
  required String expectedToken,
  String? unexpectedToken,
  String? reason,
  Iterable<String> forbiddenTranscriptSnippets = const <String>[],
}) {
  expect(transcript, contains(expectedHeading), reason: reason);
  expect(transcript, contains(expectedToken), reason: reason);
  if (unexpectedToken != null) {
    expect(transcript, isNot(contains(unexpectedToken)), reason: reason);
  }
  expect(
    transcript,
    isNot(contains(telegramHighRiskEscalationCopy)),
    reason: reason,
  );
  expect(
    transcript,
    isNot(contains(telegramRouteFallbackCopy)),
    reason: reason,
  );
  for (final snippet in forbiddenTranscriptSnippets) {
    expect(transcript, isNot(contains(snippet)), reason: reason);
  }
}

void expectDeterministicTelegramFollowUpReply(
  String transcript, {
  required String expectedHeading,
  required String expectedToken,
  String? unexpectedToken,
  String? reason,
  Iterable<String> forbiddenTranscriptSnippets = const <String>[],
  Iterable<String> forbiddenReplySnippets = const <String>[],
}) {
  final followUpReply = telegramFollowUpReplyFromTranscript(transcript);
  expect(followUpReply, contains(expectedHeading), reason: reason);
  expect(followUpReply, contains(expectedToken), reason: reason);
  if (unexpectedToken != null) {
    expect(followUpReply, isNot(contains(unexpectedToken)), reason: reason);
  }
  expect(
    followUpReply,
    isNot(contains(telegramHighRiskEscalationCopy)),
    reason: reason,
  );
  expect(
    transcript,
    isNot(contains(telegramRouteFallbackCopy)),
    reason: reason,
  );
  for (final snippet in forbiddenTranscriptSnippets) {
    expect(transcript, isNot(contains(snippet)), reason: reason);
  }
  for (final snippet in forbiddenReplySnippets) {
    expect(followUpReply, isNot(contains(snippet)), reason: reason);
  }
}
