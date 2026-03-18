import 'dart:io';

import 'package:omnix_dashboard/application/telegram_ai_assistant_service.dart';

const _fixturePath = 'test/fixtures/telegram_ai_voice_review_transcripts.txt';
const _learnedExample =
    'We are on it at MS Vallee Residence now. I will share the next confirmed step the moment control has it.';

Future<String> _buildVoiceReviewTranscript() async {
  const service = UnconfiguredTelegramAiAssistantService();
  final cases = <(String, Future<TelegramAiDraftReply>)>[
    (
      'VALLEE_WORRIED',
      service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'I am scared, what is happening?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
      ),
    ),
    (
      'VALLEE_PRESSURED_LEARNED',
      service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'still waiting?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        preferredReplyExamples: const [_learnedExample],
        learnedReplyExamples: const [_learnedExample],
        recentConversationTurns: const [
          'Telegram Inbound • telegram • Resident: still waiting',
          'Reply Sent • openai:gpt-4.1-mini • ONYX AI: We are on it at MS Vallee Residence and control is checking the latest position now. I will send the next confirmed update as soon as control has it.',
        ],
      ),
    ),
    (
      'VALLEE_ONSITE',
      service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'Any update?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'Responder On Site • partner_dispatch • ONYX AI: Responder on site at MS Vallee Residence.',
        ],
      ),
    ),
    (
      'VALLEE_CLOSURE',
      service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'Thank you',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'Incident Resolved • onyx_monitoring • ONYX AI: Incident resolved at MS Vallee Residence.',
        ],
      ),
    ),
    (
      'TOWER_ACCESS',
      service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'The gate is not opening',
        clientId: 'CLIENT-SANDTON',
        siteId: 'SITE-SANDTON-TOWER',
      ),
    ),
    (
      'TOWER_STATUS',
      service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'Any update?',
        clientId: 'CLIENT-SANDTON',
        siteId: 'SITE-SANDTON-TOWER',
        recentConversationTurns: const [
          'Reply Sent • openai:gpt-4.1-mini • ONYX AI: We are actively checking access-control status for Sandton Tower now. I will share the next confirmed step the moment control has it.',
        ],
      ),
    ),
    (
      'TOWER_CLOSURE',
      service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'Thanks',
        clientId: 'CLIENT-SANDTON',
        siteId: 'SITE-SANDTON-TOWER',
        recentConversationTurns: const [
          'Incident Resolved • onyx_monitoring • ONYX AI: Incident resolved at Sandton Tower.',
        ],
      ),
    ),
  ];

  final buffer = StringBuffer();
  for (final (label, futureDraft) in cases) {
    final draft = await futureDraft;
    if (buffer.isNotEmpty) {
      buffer.writeln();
    }
    buffer.writeln('=== $label ===');
    buffer.writeln(draft.text);
    buffer.write('usedLearnedApprovalStyle=${draft.usedLearnedApprovalStyle}');
  }
  return buffer.toString();
}

Future<void> main(List<String> args) async {
  final transcript = await _buildVoiceReviewTranscript();
  if (args.contains('--write')) {
    await File(_fixturePath).writeAsString('$transcript\n');
    stdout.writeln('Updated $_fixturePath');
    return;
  }
  stdout.writeln(transcript);
}
