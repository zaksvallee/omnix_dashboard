import 'dart:io';

import 'package:omnix_dashboard/application/telegram_ai_assistant_service.dart';

const _fixturePath = 'test/fixtures/telegram_ai_voice_review_transcripts.txt';
const _learnedExample =
    'We are checking MS Vallee Residence now. I will share the next confirmed step here when it is confirmed.';

int _wordCount(String text) {
  return text
      .trim()
      .split(RegExp(r'\s+'))
      .where((token) => token.trim().isNotEmpty)
      .length;
}

String _pairObservedDifference({
  required String baselineText,
  required String taggedText,
}) {
  final baseline = baselineText.trim().toLowerCase();
  final tagged = taggedText.trim().toLowerCase();
  final addsReassurance =
      !baseline.contains('you are not alone') &&
      tagged.contains('you are not alone');
  final addsLiveUrgency =
      !baseline.contains('treating this as live') &&
      tagged.contains('treating this as live');
  final dropsFormalSeriousness =
      baseline.contains('taking this seriously') &&
      !tagged.contains('taking this seriously');
  final addsFormalEnterpriseTone =
      !baseline.contains('actively checking') &&
      tagged.contains('actively checking');
  final addsCameraValidation =
      (!baseline.contains('daylight') && tagged.contains('daylight')) ||
      (!baseline.contains('camera check') && tagged.contains('camera check'));
  final usesEtaShorthand =
      baseline.contains('when the eta is confirmed') &&
      tagged.contains('when it is confirmed');
  final tightensEta =
      tagged.contains('eta') &&
      (!baseline.contains('eta') ||
          _wordCount(taggedText) < _wordCount(baselineText));
  final notes = <String>[];
  if (dropsFormalSeriousness && addsReassurance && addsLiveUrgency) {
    notes.add(
      'tagged reply shifts from formal enterprise wording to more protective plain language',
    );
  } else if (addsReassurance && addsLiveUrgency) {
    notes.add('tagged reply adds explicit reassurance and stronger urgency');
  } else {
    if (addsReassurance) {
      notes.add('tagged reply adds explicit reassurance');
    }
    if (addsLiveUrgency) {
      notes.add('tagged reply sounds more protective and urgent');
    }
  }
  if (addsCameraValidation) {
    notes.add('tagged reply leans harder into camera validation');
  }
  if (addsFormalEnterpriseTone) {
    notes.add('tagged reply shifts toward more formal enterprise wording');
  }
  if (usesEtaShorthand && tightensEta) {
    notes.add('tagged reply uses tighter ETA shorthand');
  } else {
    if (usesEtaShorthand) {
      notes.add('tagged reply uses tighter ETA shorthand');
    }
    if (tightensEta) {
      notes.add('tagged reply stays tighter around the ETA');
    }
  }
  if (notes.isNotEmpty) {
    return notes.join(' • ');
  }
  if (baselineText.trim() == taggedText.trim()) {
    return 'tagged reply stays effectively identical to baseline';
  }
  if (_wordCount(taggedText) < _wordCount(baselineText)) {
    return 'tagged reply is slightly tighter than baseline';
  }
  return 'tagged reply shifts tone subtly while staying close to baseline';
}

String? _journeyGroupPurposeNote(String groupTitle) {
  switch (groupTitle) {
    case 'VALLEE RESIDENTIAL JOURNEYS':
      return 'focus=pressure, validation, on-site, closure';
    case 'TOWER ENTERPRISE JOURNEYS':
      return 'focus=access, status, closure';
    default:
      return null;
  }
}

String? _pairGroupPurposeNote(String groupTitle) {
  switch (groupTitle) {
    case 'VALLEE RESIDENTIAL PAIRS':
      return 'focus=reassurance warmth, camera validation, ETA tightening';
    case 'TOWER ENTERPRISE PAIRS':
      return 'focus=ETA tightening, plain-to-formal status shift, formal-to-protective worry shift';
    default:
      return null;
  }
}

Future<String> _buildVoiceReviewTranscript() async {
  const service = UnconfiguredTelegramAiAssistantService();
  final pairedCases = <({
    String groupTitle,
    String title,
    String expectedShift,
    ({
      String label,
      List<String> preferredTags,
      List<String> learnedTags,
      Future<TelegramAiDraftReply> draft,
    }) baseline,
    ({
      String label,
      List<String> preferredTags,
      List<String> learnedTags,
      Future<TelegramAiDraftReply> draft,
    }) tagged,
  })>[
    (
      groupTitle: 'VALLEE RESIDENTIAL PAIRS',
      title: 'VALLEE_REASSURANCE_PAIR',
      expectedShift: 'baseline vs warmer reassurance under worry',
      baseline: (
        label: 'VALLEE_WORRIED',
        preferredTags: const <String>[],
        learnedTags: const <String>[],
        draft: service.draftReply(
          audience: TelegramAiAudience.client,
          messageText: 'I am scared, what is happening?',
          clientId: 'CLIENT-MS-VALLEE',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
        ),
      ),
      tagged: (
        label: 'VALLEE_WORRIED_TAGGED_REASSURANCE',
        preferredTags: const <String>[],
        learnedTags: const ['Warm reassurance'],
        draft: service.draftReply(
          audience: TelegramAiAudience.client,
          messageText: 'I am scared, what is happening?',
          clientId: 'CLIENT-MS-VALLEE',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          learnedReplyStyleTags: const ['Warm reassurance'],
        ),
      ),
    ),
    (
      groupTitle: 'VALLEE RESIDENTIAL PAIRS',
      title: 'VALLEE_VISUAL_PAIR',
      expectedShift: 'baseline vs stronger camera-validation wording',
      baseline: (
        label: 'VALLEE_VISUAL_BASELINE',
        preferredTags: const <String>[],
        learnedTags: const <String>[],
        draft: service.draftReply(
          audience: TelegramAiAudience.client,
          messageText: 'What do you see on camera in daylight?',
          clientId: 'CLIENT-MS-VALLEE',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
        ),
      ),
      tagged: (
        label: 'VALLEE_VISUAL_TAGGED_CAMERA',
        preferredTags: const ['Camera validation'],
        learnedTags: const <String>[],
        draft: service.draftReply(
          audience: TelegramAiAudience.client,
          messageText: 'What do you see on camera in daylight?',
          clientId: 'CLIENT-MS-VALLEE',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          preferredReplyStyleTags: const ['Camera validation'],
        ),
      ),
    ),
    (
      groupTitle: 'VALLEE RESIDENTIAL PAIRS',
      title: 'VALLEE_ETA_PAIR',
      expectedShift: 'baseline vs tighter ETA-focused wording',
      baseline: (
        label: 'VALLEE_ETA_BASELINE',
        preferredTags: const <String>[],
        learnedTags: const <String>[],
        draft: service.draftReply(
          audience: TelegramAiAudience.client,
          messageText: 'How long?',
          clientId: 'CLIENT-MS-VALLEE',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
        ),
      ),
      tagged: (
        label: 'VALLEE_ETA_TAGGED_CRISP',
        preferredTags: const ['ETA crisp'],
        learnedTags: const <String>[],
        draft: service.draftReply(
          audience: TelegramAiAudience.client,
          messageText: 'How long?',
          clientId: 'CLIENT-MS-VALLEE',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          preferredReplyStyleTags: const ['ETA crisp'],
        ),
      ),
    ),
    (
      groupTitle: 'TOWER ENTERPRISE PAIRS',
      title: 'TOWER_STATUS_PAIR',
      expectedShift: 'baseline vs more formal enterprise status wording',
      baseline: (
        label: 'TOWER_STATUS_BASELINE',
        preferredTags: const <String>[],
        learnedTags: const <String>[],
        draft: service.draftReply(
          audience: TelegramAiAudience.client,
          messageText: 'Any update?',
          clientId: 'CLIENT-SANDTON',
          siteId: 'SITE-SANDTON-TOWER',
        ),
      ),
      tagged: (
        label: 'TOWER_STATUS_TAGGED_FORMAL',
        preferredTags: const ['Operations formal'],
        learnedTags: const <String>[],
        draft: service.draftReply(
          audience: TelegramAiAudience.client,
          messageText: 'Any update?',
          clientId: 'CLIENT-SANDTON',
          siteId: 'SITE-SANDTON-TOWER',
          preferredReplyStyleTags: const ['Operations formal'],
        ),
      ),
    ),
    (
      groupTitle: 'TOWER ENTERPRISE PAIRS',
      title: 'TOWER_ETA_PAIR',
      expectedShift: 'baseline vs tighter ETA-focused enterprise wording',
      baseline: (
        label: 'TOWER_ETA_BASELINE',
        preferredTags: const <String>[],
        learnedTags: const <String>[],
        draft: service.draftReply(
          audience: TelegramAiAudience.client,
          messageText: 'How long?',
          clientId: 'CLIENT-SANDTON',
          siteId: 'SITE-SANDTON-TOWER',
          recentConversationTurns: const [
            'Reply Sent • openai:gpt-4.1-mini • ONYX AI: We are checking access at Sandton Tower now. I will update you here with the next confirmed step.',
          ],
        ),
      ),
      tagged: (
        label: 'TOWER_ETA_TAGGED_CRISP',
        preferredTags: const ['ETA crisp'],
        learnedTags: const <String>[],
        draft: service.draftReply(
          audience: TelegramAiAudience.client,
          messageText: 'How long?',
          clientId: 'CLIENT-SANDTON',
          siteId: 'SITE-SANDTON-TOWER',
          preferredReplyStyleTags: const ['ETA crisp'],
          recentConversationTurns: const [
            'Reply Sent • openai:gpt-4.1-mini • ONYX AI: We are checking access at Sandton Tower now. I will update you here with the next confirmed step.',
          ],
        ),
      ),
    ),
    (
      groupTitle: 'TOWER ENTERPRISE PAIRS',
      title: 'TOWER_WORRIED_PAIR',
      expectedShift: 'baseline vs more protective enterprise reassurance wording',
      baseline: (
        label: 'TOWER_WORRIED_BASELINE',
        preferredTags: const <String>[],
        learnedTags: const <String>[],
        draft: service.draftReply(
          audience: TelegramAiAudience.client,
          messageText: 'I am worried, what is happening?',
          clientId: 'CLIENT-SANDTON',
          siteId: 'SITE-SANDTON-TOWER',
        ),
      ),
      tagged: (
        label: 'TOWER_WORRIED_TAGGED_REASSURANCE',
        preferredTags: const <String>[],
        learnedTags: const ['Warm reassurance'],
        draft: service.draftReply(
          audience: TelegramAiAudience.client,
          messageText: 'I am worried, what is happening?',
          clientId: 'CLIENT-SANDTON',
          siteId: 'SITE-SANDTON-TOWER',
          learnedReplyStyleTags: const ['Warm reassurance'],
        ),
      ),
    ),
  ];
  final standaloneCases = <({
    String groupTitle,
    String label,
    List<String> preferredTags,
    List<String> learnedTags,
    Future<TelegramAiDraftReply> draft,
  })>[
    (
      groupTitle: 'VALLEE RESIDENTIAL JOURNEYS',
      label: 'VALLEE_PRESSURED_LEARNED',
      preferredTags: const <String>[],
      learnedTags: const <String>[],
      draft: service.draftReply(
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
      groupTitle: 'VALLEE RESIDENTIAL JOURNEYS',
      label: 'VALLEE_VISUAL_MEMORY',
      preferredTags: const <String>[],
      learnedTags: const <String>[],
      draft: service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'What do you see on camera in daylight?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        clientProfileSignals: const ['validation-heavy'],
      ),
    ),
    (
      groupTitle: 'VALLEE RESIDENTIAL JOURNEYS',
      label: 'VALLEE_ONSITE',
      preferredTags: const <String>[],
      learnedTags: const <String>[],
      draft: service.draftReply(
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
      groupTitle: 'VALLEE RESIDENTIAL JOURNEYS',
      label: 'VALLEE_CLOSURE',
      preferredTags: const <String>[],
      learnedTags: const <String>[],
      draft: service.draftReply(
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
      groupTitle: 'TOWER ENTERPRISE JOURNEYS',
      label: 'TOWER_ACCESS',
      preferredTags: const <String>[],
      learnedTags: const <String>[],
      draft: service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'The gate is not opening',
        clientId: 'CLIENT-SANDTON',
        siteId: 'SITE-SANDTON-TOWER',
      ),
    ),
    (
      groupTitle: 'TOWER ENTERPRISE JOURNEYS',
      label: 'TOWER_STATUS',
      preferredTags: const <String>[],
      learnedTags: const <String>[],
      draft: service.draftReply(
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
      groupTitle: 'TOWER ENTERPRISE JOURNEYS',
      label: 'TOWER_CLOSURE',
      preferredTags: const <String>[],
      learnedTags: const <String>[],
      draft: service.draftReply(
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
  buffer.writeln('# LEGEND');
  buffer.writeln(
    'focus=what the grouped section is meant to cover during review',
  );
  buffer.writeln(
    'expectedShift=the wording change we hope the tag or memory will cause',
  );
  buffer.writeln(
    'observedDifference=the wording difference the transcript actually shows',
  );
  String? currentPairGroupTitle;
  void writeCase({
    required String label,
    required List<String> preferredTags,
    required List<String> learnedTags,
    required TelegramAiDraftReply draft,
  }) {
    if (buffer.isNotEmpty) {
      buffer.writeln();
    }
    buffer.writeln('=== $label ===');
    if (preferredTags.isNotEmpty) {
      buffer.writeln('preferredStyleTags=${preferredTags.join(' | ')}');
    }
    if (learnedTags.isNotEmpty) {
      buffer.writeln('learnedStyleTags=${learnedTags.join(' | ')}');
    }
    buffer.writeln(draft.text);
    buffer.write('usedLearnedApprovalStyle=${draft.usedLearnedApprovalStyle}');
  }
  for (final pair in pairedCases) {
    if (buffer.isNotEmpty) {
      buffer.writeln();
    }
    if (currentPairGroupTitle != pair.groupTitle) {
      buffer.writeln('# ${pair.groupTitle}');
      final purposeNote = _pairGroupPurposeNote(pair.groupTitle);
      if (purposeNote != null) {
        buffer.writeln(purposeNote);
      }
      currentPairGroupTitle = pair.groupTitle;
    }
    buffer.writeln('## ${pair.title}');
    buffer.writeln('expectedShift=${pair.expectedShift}');
    final baselineDraft = await pair.baseline.draft;
    final taggedDraft = await pair.tagged.draft;
    buffer.writeln(
      'observedDifference=${_pairObservedDifference(baselineText: baselineDraft.text, taggedText: taggedDraft.text)}',
    );
    writeCase(
      label: pair.baseline.label,
      preferredTags: pair.baseline.preferredTags,
      learnedTags: pair.baseline.learnedTags,
      draft: baselineDraft,
    );
    writeCase(
      label: pair.tagged.label,
      preferredTags: pair.tagged.preferredTags,
      learnedTags: pair.tagged.learnedTags,
      draft: taggedDraft,
    );
  }
  if (standaloneCases.isNotEmpty) {
    if (buffer.isNotEmpty) {
      buffer.writeln();
    }
    buffer.writeln('# JOURNEY CASES');
  }
  String? currentJourneyGroupTitle;
  for (final voiceCase in standaloneCases) {
    if (currentJourneyGroupTitle != voiceCase.groupTitle) {
      if (buffer.isNotEmpty) {
        buffer.writeln();
      }
      buffer.writeln('## ${voiceCase.groupTitle}');
      final purposeNote = _journeyGroupPurposeNote(voiceCase.groupTitle);
      if (purposeNote != null) {
        buffer.writeln(purposeNote);
      }
      currentJourneyGroupTitle = voiceCase.groupTitle;
    }
    final draft = await voiceCase.draft;
    writeCase(
      label: voiceCase.label,
      preferredTags: voiceCase.preferredTags,
      learnedTags: voiceCase.learnedTags,
      draft: draft,
    );
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
