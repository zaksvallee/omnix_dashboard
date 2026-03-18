import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:omnix_dashboard/application/telegram_ai_assistant_service.dart';

void main() {
  Future<String> buildVoiceReviewTranscript() async {
    const service = UnconfiguredTelegramAiAssistantService();
    const learnedExample =
        'We are on it at MS Vallee Residence now. I will share the next confirmed step the moment control has it.';
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
          preferredReplyExamples: const [learnedExample],
          learnedReplyExamples: const [learnedExample],
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

  test('unconfigured assistant returns fallback draft', () async {
    const service = UnconfiguredTelegramAiAssistantService();

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'Need update please',
      clientId: 'CLIENT-1',
      siteId: 'SITE-1',
    );

    expect(service.isConfigured, isFalse);
    expect(draft.usedFallback, isTrue);
    expect(draft.text, contains('confirmed update'));
    expect(draft.text, isNot(contains('CLIENT-1')));
    expect(draft.text, isNot(contains('SITE-1')));
  });

  test('openai assistant parses output_text payload', () async {
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['model'], 'gpt-4.1-mini');
      final input = body['input'] as List<dynamic>;
      final system =
          ((input.first as Map<String, dynamic>)['content'] as List<dynamic>)
              .first as Map<String, dynamic>;
      expect(system['text'], contains('calm, capable control-room operator'));
      return http.Response(
        '{"id":"resp_1","output_text":"We are checking SITE-1 now and will send the next confirmed update as soon as it is in."}',
        200,
      );
    });
    final service = OpenAiTelegramAiAssistantService(
      client: client,
      apiKey: 'sk-test',
      model: 'gpt-4.1-mini',
    );

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'What is the status?',
      clientId: 'CLIENT-1',
      siteId: 'SITE-1',
    );

    expect(service.isConfigured, isTrue);
    expect(draft.usedFallback, isFalse);
    expect(draft.text, 'We are checking now and will send the next confirmed update as soon as it is in.');
    expect(draft.providerLabel, 'openai:gpt-4.1-mini');
  });

  test('openai assistant adds urgency note for escalated client lane', () async {
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final input = body['input'] as List<dynamic>;
      final system =
          ((input.first as Map<String, dynamic>)['content'] as List<dynamic>)
              .first as Map<String, dynamic>;
      expect(system['text'], contains('already escalated/high-priority'));
      return http.Response(
        '{"id":"resp_2","output_text":"This is already escalated with control and we are checking the next confirmed step now."}',
        200,
      );
    });
    final service = OpenAiTelegramAiAssistantService(
      client: client,
      apiKey: 'sk-test',
      model: 'gpt-4.1-mini',
    );

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'Any update?',
      clientId: 'CLIENT-1',
      siteId: 'SITE-1',
      recentConversationTurns: const [
        'Escalated • ai_policy • ONYX AI: ONYX ALERT RECEIVED: your message is marked high-priority and has been escalated to the control room.',
      ],
    );

    expect(draft.usedFallback, isFalse);
    expect(draft.text, contains('already escalated with control'));
  });

  test('openai assistant adds steady-tone note for pressured client lane',
      () async {
    String? systemText;
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final input = body['input'] as List<dynamic>;
      final system =
          ((input.first as Map<String, dynamic>)['content'] as List<dynamic>)
              .first as Map<String, dynamic>;
      systemText = system['text'] as String?;
      return http.Response(
        '{"id":"resp_3","output_text":"We are on it at MS Vallee Residence now. I will update you here the moment control confirms the next step."}',
        200,
      );
    });
    final service = OpenAiTelegramAiAssistantService(
      client: client,
      apiKey: 'sk-test',
      model: 'gpt-4.1-mini',
    );

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'Any update?',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      recentConversationTurns: const [
        'Telegram Inbound • telegram • Resident: still waiting',
        'Reply Sent • openai:gpt-4.1-mini • ONYX AI: We are on it at MS Vallee Residence and control is checking the latest position now. I will send the next confirmed update as soon as control has it.',
      ],
    );

    expect(draft.usedFallback, isFalse);
    expect(systemText, contains('repeated anxious follow-ups'));
    expect(draft.text, contains('moment control confirms the next step'));
  });

  test('openai assistant adds on-site stage note for responder lane',
      () async {
    String? systemText;
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final input = body['input'] as List<dynamic>;
      final system =
          ((input.first as Map<String, dynamic>)['content'] as List<dynamic>)
              .first as Map<String, dynamic>;
      systemText = system['text'] as String?;
      return http.Response(
        '{"id":"resp_4","output_text":"Security is already on site at MS Vallee Residence. We are checking the latest on-site position now."}',
        200,
      );
    });
    final service = OpenAiTelegramAiAssistantService(
      client: client,
      apiKey: 'sk-test',
      model: 'gpt-4.1-mini',
    );

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'ETA?',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      recentConversationTurns: const [
        'Responder On Site • partner_dispatch • ONYX AI: Responder on site at MS Vallee Residence.',
      ],
    );

    expect(draft.usedFallback, isFalse);
    expect(systemText, contains('already on site'));
    expect(systemText, contains('not ETA'));
    expect(draft.text, contains('already on site'));
  });

  test('openai assistant adds approval-draft delivery note', () async {
    String? systemText;
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final input = body['input'] as List<dynamic>;
      final system =
          ((input.first as Map<String, dynamic>)['content'] as List<dynamic>)
              .first as Map<String, dynamic>;
      systemText = system['text'] as String?;
      return http.Response(
        '{"id":"resp_5","output_text":"We are checking access status for MS Vallee Residence now. I will share the next confirmed step the moment control has it."}',
        200,
      );
    });
    final service = OpenAiTelegramAiAssistantService(
      client: client,
      apiKey: 'sk-test',
      model: 'gpt-4.1-mini',
    );

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'We cannot get out the gate',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      deliveryMode: TelegramAiDeliveryMode.approvalDraft,
    );

    expect(draft.usedFallback, isFalse);
    expect(systemText, contains('drafted for operator approval'));
    expect(draft.text, contains('moment control has it'));
  });

  test('openai assistant adds concise client-profile note when provided',
      () async {
    String? systemText;
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final input = body['input'] as List<dynamic>;
      final system =
          ((input.first as Map<String, dynamic>)['content'] as List<dynamic>)
              .first as Map<String, dynamic>;
      systemText = system['text'] as String?;
      return http.Response(
        '{"id":"resp_5profile","output_text":"We are checking MS Vallee Residence now. I will share the next step when confirmed."}',
        200,
      );
    });
    final service = OpenAiTelegramAiAssistantService(
      client: client,
      apiKey: 'sk-test',
      model: 'gpt-4.1-mini',
    );

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'Need status please',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      clientProfileSignals: const ['concise-updates'],
    );

    expect(draft.usedFallback, isFalse);
    expect(systemText, contains('prefers short operational updates'));
    expect(draft.text, contains('share the next step when confirmed'));
  });

  test('openai assistant adds residential tone note for Vallee scope',
      () async {
    String? systemText;
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final input = body['input'] as List<dynamic>;
      final system =
          ((input.first as Map<String, dynamic>)['content'] as List<dynamic>)
              .first as Map<String, dynamic>;
      systemText = system['text'] as String?;
      return http.Response(
        '{"id":"resp_5a","output_text":"We are on it at MS Vallee Residence and control is checking the latest position now."}',
        200,
      );
    });
    final service = OpenAiTelegramAiAssistantService(
      client: client,
      apiKey: 'sk-test',
      model: 'gpt-4.1-mini',
    );

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'Need status please',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
    );

    expect(draft.usedFallback, isFalse);
    expect(systemText, contains('residential/private-community'));
  });

  test('openai assistant adds enterprise tone note for tower scope', () async {
    String? systemText;
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final input = body['input'] as List<dynamic>;
      final system =
          ((input.first as Map<String, dynamic>)['content'] as List<dynamic>)
              .first as Map<String, dynamic>;
      systemText = system['text'] as String?;
      return http.Response(
        '{"id":"resp_5b","output_text":"We are actively checking the latest position for Sandton Tower now."}',
        200,
      );
    });
    final service = OpenAiTelegramAiAssistantService(
      client: client,
      apiKey: 'sk-test',
      model: 'gpt-4.1-mini',
    );

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'Need status please',
      clientId: 'CLIENT-SANDTON',
      siteId: 'SITE-SANDTON-TOWER',
    );

    expect(draft.usedFallback, isFalse);
    expect(systemText, contains('corporate/enterprise site'));
  });

  test('openai assistant adds residential visual tone note for daylight check',
      () async {
    String? systemText;
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final input = body['input'] as List<dynamic>;
      final system =
          ((input.first as Map<String, dynamic>)['content'] as List<dynamic>)
              .first as Map<String, dynamic>;
      systemText = system['text'] as String?;
      return http.Response(
        '{"id":"resp_5c","output_text":"We are checking the latest camera view around MS Vallee Residence now."}',
        200,
      );
    });
    final service = OpenAiTelegramAiAssistantService(
      client: client,
      apiKey: 'sk-test',
      model: 'gpt-4.1-mini',
    );

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'What do you see on camera in daylight?',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
    );

    expect(draft.usedFallback, isFalse);
    expect(systemText, contains('camera/daylight validation'));
    expect(systemText, contains('protective and clear'));
  });

  test('openai assistant adds enterprise access tone note for tower scope',
      () async {
    String? systemText;
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final input = body['input'] as List<dynamic>;
      final system =
          ((input.first as Map<String, dynamic>)['content'] as List<dynamic>)
              .first as Map<String, dynamic>;
      systemText = system['text'] as String?;
      return http.Response(
        '{"id":"resp_5d","output_text":"We are checking access-control status for Sandton Tower now."}',
        200,
      );
    });
    final service = OpenAiTelegramAiAssistantService(
      client: client,
      apiKey: 'sk-test',
      model: 'gpt-4.1-mini',
    );

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'The gate is not opening',
      clientId: 'CLIENT-SANDTON',
      siteId: 'SITE-SANDTON-TOWER',
    );

    expect(draft.usedFallback, isFalse);
    expect(systemText, contains('access control'));
    expect(systemText, contains('operational next steps'));
  });

  test('openai assistant includes approved wording examples when provided',
      () async {
    String? systemText;
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final input = body['input'] as List<dynamic>;
      final system =
          ((input.first as Map<String, dynamic>)['content'] as List<dynamic>)
              .first as Map<String, dynamic>;
      systemText = system['text'] as String?;
      return http.Response(
        '{"id":"resp_6","output_text":"We are checking access status for MS Vallee Residence now. I will share the next confirmed step the moment control has it."}',
        200,
      );
    });
    final service = OpenAiTelegramAiAssistantService(
      client: client,
      apiKey: 'sk-test',
      model: 'gpt-4.1-mini',
    );

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'Need status please',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      preferredReplyExamples: const [
        'We are on it at MS Vallee Residence now. I will share the next confirmed step the moment control has it.',
      ],
    );

    expect(draft.usedFallback, isFalse);
    expect(systemText, contains('Preferred approved reply examples'));
    expect(systemText, contains('I will share the next confirmed step'));
    expect(draft.text, contains('I will share the next confirmed step'));
  });

  test('openai assistant normalizes drift back to learned closing style',
      () async {
    final client = MockClient((request) async {
      return http.Response(
        '{"id":"resp_7","output_text":"We are checking access status for MS Vallee Residence now. I will send the next confirmed step as soon as control has it."}',
        200,
      );
    });
    final service = OpenAiTelegramAiAssistantService(
      client: client,
      apiKey: 'sk-test',
      model: 'gpt-4.1-mini',
    );

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'We cannot get out the gate',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      preferredReplyExamples: const [
        'We are on it at MS Vallee Residence now. I will share the next confirmed step the moment control has it.',
      ],
    );

    expect(draft.usedFallback, isFalse);
    expect(
      draft.text,
      'We are checking access status for MS Vallee Residence now. I will share the next confirmed step the moment control has it.',
    );
  });

  test('openai assistant normalizes sms-style drift into concise fallback voice',
      () async {
    final client = MockClient((request) async {
      return http.Response(
        '{"id":"resp_8","output_text":"We are checking MS Vallee Residence now. I will update you here the moment control confirms the next step."}',
        200,
      );
    });
    final service = OpenAiTelegramAiAssistantService(
      client: client,
      apiKey: 'sk-test',
      model: 'gpt-4.1-mini',
    );

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'Any update?',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      deliveryMode: TelegramAiDeliveryMode.smsFallback,
    );

    expect(draft.usedFallback, isFalse);
    expect(
      draft.text,
      'We are checking MS Vallee Residence now. Control will send the next confirmed step.',
    );
  });

  test('openai assistant falls back when API fails', () async {
    final client = MockClient((request) async {
      return http.Response('{"error":"rate limited"}', 429);
    });
    final service = OpenAiTelegramAiAssistantService(
      client: client,
      apiKey: 'sk-test',
      model: 'gpt-4.1-mini',
    );

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'ETA?',
      clientId: 'CLIENT-1',
      siteId: 'SITE-1',
    );

    expect(draft.usedFallback, isTrue);
    expect(draft.text, contains('ETA'));
    expect(draft.text, isNot(contains('CLIENT-1')));
    expect(draft.text, isNot(contains('SITE-1')));
  });

  test('openai assistant replaces mechanical client reply with warm fallback',
      () async {
    final client = MockClient((request) async {
      return http.Response(
        '{"id":"resp_1","output_text":"ONYX received your message (CLIENT-1/SITE-1). Command is reviewing and will send a verified update shortly."}',
        200,
      );
    });
    final service = OpenAiTelegramAiAssistantService(
      client: client,
      apiKey: 'sk-test',
      model: 'gpt-4.1-mini',
    );

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'Need status please',
      clientId: 'CLIENT-1',
      siteId: 'SITE-1',
    );

    expect(draft.usedFallback, isFalse);
    expect(draft.text, contains('confirmed update'));
    expect(draft.text, isNot(contains('received your message')));
    expect(draft.text, isNot(contains('CLIENT-1')));
  });

  test('fallback reply reassures worried clients without sounding robotic',
      () async {
    const service = UnconfiguredTelegramAiAssistantService();

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'I am really worried and scared',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
    );

    expect(draft.text, contains('You are not alone.'));
    expect(draft.text, contains('MS Vallee Residence'));
    expect(draft.text, contains('next confirmed update'));
  });

  test('fallback reply uses enterprise status phrasing for tower scope',
      () async {
    const service = UnconfiguredTelegramAiAssistantService();

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'Need status please',
      clientId: 'CLIENT-SANDTON',
      siteId: 'SITE-SANDTON-TOWER',
    );

    expect(
      draft.text,
      contains('actively checking the latest position for Sandton Tower now'),
    );
    expect(draft.text, isNot(contains('We are on it at Sandton Tower')));
  });

  test('fallback reply uses residential visual phrasing for Vallee daylight',
      () async {
    const service = UnconfiguredTelegramAiAssistantService();

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'What do you see on camera in daylight?',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
    );

    expect(
      draft.text,
      contains('latest camera view around MS Vallee Residence now'),
    );
    expect(draft.text, contains('confirmed visual update'));
  });

  test('fallback reply uses enterprise access phrasing for tower scope',
      () async {
    const service = UnconfiguredTelegramAiAssistantService();

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'The gate is not opening',
      clientId: 'CLIENT-SANDTON',
      siteId: 'SITE-SANDTON-TOWER',
    );

    expect(
      draft.text,
      contains('checking access-control status for Sandton Tower now'),
    );
    expect(draft.text, contains('next confirmed step'));
  });

  test('fallback reply honors concise client profile memory', () async {
    const service = UnconfiguredTelegramAiAssistantService();

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'Need status please',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      clientProfileSignals: const ['concise-updates'],
    );

    expect(draft.text, contains('We are checking MS Vallee Residence now.'));
    expect(draft.text, contains('I will share the next step when confirmed.'));
    expect(draft.text, isNot(contains('control is checking the latest position now')));
  });

  test('fallback reply honors validation-heavy client profile memory',
      () async {
    const service = UnconfiguredTelegramAiAssistantService();

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'What do you see on camera?',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      clientProfileSignals: const ['validation-heavy'],
    );

    expect(
      draft.text,
      contains('latest camera and daylight view around MS Vallee Residence now'),
    );
    expect(draft.text, contains('confirmed visual check'));
  });

  test('fallback reply handles access issues with a concrete next step',
      () async {
    const service = UnconfiguredTelegramAiAssistantService();

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'We cannot get out the gate',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
    );

    expect(draft.text, contains('checking access status'));
    expect(draft.text, contains('next confirmed step'));
  });

  test('fallback reply handles camera validation requests cleanly', () async {
    const service = UnconfiguredTelegramAiAssistantService();

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'What do you see on camera in daylight?',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
    );

    expect(draft.text, contains('latest camera view'));
    expect(draft.text, contains('confirmed visual update'));
  });

  test('fallback reply varies repeated status follow-up language', () async {
    const service = UnconfiguredTelegramAiAssistantService();

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'Any update yet?',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      recentConversationTurns: const [
        'ONYX AI: We are on it at MS Vallee Residence and control is checking the latest position now. I will send the next confirmed update as soon as it is in.',
      ],
    );

    expect(
      draft.text,
      contains('I will keep this lane updated the moment control confirms the next step.'),
    );
    expect(draft.text, isNot(contains('next confirmed update as soon as it is in')));
  });

  test('fallback reply carries eta intent into short follow-up turns', () async {
    const service = UnconfiguredTelegramAiAssistantService();

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'still waiting?',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      recentConversationTurns: const [
        'ONYX AI: We are checking live movement for MS Vallee Residence now. I will send the ETA as soon as control confirms it.',
      ],
    );

    expect(draft.text, contains('checking live movement'));
    expect(
      draft.text,
      anyOf(
        contains('ETA'),
        contains('moment control confirms the ETA'),
      ),
    );
  });

  test('fallback reply tightens status follow-up once lane is escalated',
      () async {
    const service = UnconfiguredTelegramAiAssistantService();

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'Any update?',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      recentConversationTurns: const [
        'Escalated • ai_policy • ONYX AI: ONYX ALERT RECEIVED: your message is marked high-priority and has been escalated to the control room.',
      ],
    );

    expect(draft.text, contains('already escalated with control'));
    expect(draft.text, contains('actively checking the latest position'));
    expect(
      draft.text,
      contains('moment control confirms the next step'),
    );
    expect(draft.text, isNot(contains('keep this lane updated')));
  });

  test('fallback reply shortens repeated anxious follow-ups in one lane',
      () async {
    const service = UnconfiguredTelegramAiAssistantService();

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'Any update?',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      recentConversationTurns: const [
        'Telegram Inbound • telegram • Resident: still waiting',
        'Reply Sent • openai:gpt-4.1-mini • ONYX AI: We are on it at MS Vallee Residence and control is checking the latest position now. I will send the next confirmed update as soon as control has it.',
      ],
    );

    expect(draft.text, contains('We are on it at MS Vallee Residence now.'));
    expect(
      draft.text,
      contains('I will update you here the moment control confirms the next step.'),
    );
    expect(draft.text, isNot(contains('keep this lane updated')));
    expect(draft.text, isNot(contains('control is checking the latest position now')));
  });

  test('fallback reply shifts into on-site voice once responder is there',
      () async {
    const service = UnconfiguredTelegramAiAssistantService();

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'ETA?',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      recentConversationTurns: const [
        'Responder On Site • partner_dispatch • ONYX AI: Responder on site at MS Vallee Residence.',
      ],
    );

    expect(draft.text, contains('Security is already on site at MS Vallee Residence.'));
    expect(draft.text, contains('latest on-site position'));
    expect(draft.text, isNot(contains('ETA as soon as control confirms it')));
  });

  test('fallback reply shifts into closure voice once incident is resolved',
      () async {
    const service = UnconfiguredTelegramAiAssistantService();

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'Any update?',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      recentConversationTurns: const [
        'Incident Resolved • onyx_monitoring • ONYX AI: Incident resolved at MS Vallee Residence.',
      ],
    );

    expect(
      draft.text,
      contains('The latest confirmed position is that MS Vallee Residence is secure.'),
    );
    expect(draft.text, contains('message here immediately'));
    expect(draft.text, isNot(contains('checking the latest position now')));
  });

  test('fallback reply uses approval-draft phrasing when requested', () async {
    const service = UnconfiguredTelegramAiAssistantService();

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'We cannot get out the gate',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      deliveryMode: TelegramAiDeliveryMode.approvalDraft,
    );

    expect(draft.text, contains('checking access status'));
    expect(draft.text, contains('I will share the next confirmed step the moment control has it.'));
    expect(draft.text, isNot(contains('as soon as control has it')));
  });

  test('fallback reply uses concise sms fallback voice', () async {
    const service = UnconfiguredTelegramAiAssistantService();

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'Any update?',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      deliveryMode: TelegramAiDeliveryMode.smsFallback,
      recentConversationTurns: const [
        'Telegram Inbound • telegram • Resident: still waiting',
      ],
    );

    expect(draft.text, 'We are on it at MS Vallee Residence. Control will send the next confirmed step.');
    expect(draft.text, isNot(contains('I will update you here')));
  });

  test('fallback reply mirrors preferred approved closing style', () async {
    const service = UnconfiguredTelegramAiAssistantService();

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'We cannot get out the gate',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      preferredReplyExamples: const [
        'We are on it at MS Vallee Residence now. I will share the next confirmed step the moment control has it.',
      ],
    );

    expect(draft.text, contains('checking access status'));
    expect(draft.text, contains('I will share the next confirmed step the moment control has it.'));
    expect(draft.text, isNot(contains('I will send the next confirmed step as soon as control has it.')));
  });

  test('fallback sequence stays coherent across Vallee lane stages', () async {
    const service = UnconfiguredTelegramAiAssistantService();

    final worriedDraft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'I am scared, is someone coming?',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
    );
    final onSiteDraft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'Any update?',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      recentConversationTurns: const [
        'Responder On Site • partner_dispatch • ONYX AI: Responder on site at MS Vallee Residence.',
      ],
    );
    final closureDraft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'Thank you',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      recentConversationTurns: const [
        'Incident Resolved • onyx_monitoring • ONYX AI: Incident resolved at MS Vallee Residence.',
      ],
    );

    expect(worriedDraft.text, contains('You are not alone.'));
    expect(worriedDraft.text, contains('MS Vallee Residence'));
    expect(onSiteDraft.text, contains('already on site'));
    expect(onSiteDraft.text, contains('latest on-site position'));
    expect(onSiteDraft.text, isNot(contains('You are not alone.')));
    expect(closureDraft.text, contains('latest confirmed position'));
    expect(closureDraft.text, contains('secure'));
    expect(closureDraft.text, isNot(contains('latest on-site position')));
  });

  test('fallback sequence keeps learned Vallee closing style under pressure',
      () async {
    const service = UnconfiguredTelegramAiAssistantService();
    const learnedExample =
        'We are on it at MS Vallee Residence now. I will share the next confirmed step the moment control has it.';

    final firstFollowUp = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'still waiting?',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      preferredReplyExamples: const [learnedExample],
      learnedReplyExamples: const [learnedExample],
      recentConversationTurns: const [
        'Telegram Inbound • telegram • Resident: still waiting',
        'Reply Sent • openai:gpt-4.1-mini • ONYX AI: We are on it at MS Vallee Residence and control is checking the latest position now. I will send the next confirmed update as soon as control has it.',
      ],
    );
    final secondFollowUp = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'please keep checking',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      preferredReplyExamples: const [learnedExample],
      learnedReplyExamples: const [learnedExample],
      recentConversationTurns: const [
        'Telegram Inbound • telegram • Resident: still waiting',
        'Reply Sent • openai:gpt-4.1-mini • ONYX AI: We are on it at MS Vallee Residence and control is checking the latest position now. I will send the next confirmed update as soon as control has it.',
        'Telegram Inbound • telegram • Resident: please keep checking',
      ],
    );

    expect(firstFollowUp.usedLearnedApprovalStyle, isTrue);
    expect(secondFollowUp.usedLearnedApprovalStyle, isTrue);
    expect(
      firstFollowUp.text,
      anyOf(
        contains('I will share the next confirmed step the moment control has it.'),
        contains('I will update you here the moment control confirms the next step.'),
      ),
    );
    expect(
      secondFollowUp.text,
      anyOf(
        contains('I will share the next confirmed step the moment control has it.'),
        contains('I will update you here the moment control confirms the next step.'),
      ),
    );
    expect(
      secondFollowUp.text,
      isNot(contains('I will send the next confirmed update as soon as control has it.')),
    );
  });

  test('openai draft marks learned approval style usage when provided',
      () async {
    final client = MockClient((request) async {
      return http.Response(
        '{"id":"resp_learned","output_text":"We are checking access status for MS Vallee Residence now. I will share the next confirmed step the moment control has it."}',
        200,
      );
    });
    final service = OpenAiTelegramAiAssistantService(
      client: client,
      apiKey: 'sk-test',
      model: 'gpt-4.1-mini',
    );

    final withLearnedStyle = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'The gate is still not opening',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      preferredReplyExamples: const [
        'We are on it at MS Vallee Residence now. I will share the next confirmed step the moment control has it.',
      ],
      learnedReplyExamples: const [
        'We are on it at MS Vallee Residence now. I will share the next confirmed step the moment control has it.',
      ],
    );
    final withoutLearnedStyle = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'The gate is still not opening',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
    );

    expect(withLearnedStyle.usedLearnedApprovalStyle, isTrue);
    expect(withoutLearnedStyle.usedLearnedApprovalStyle, isFalse);
  });

  test('voice review transcript fixture stays current', () async {
    final transcript = await buildVoiceReviewTranscript();
    final fixture = File(
      'test/fixtures/telegram_ai_voice_review_transcripts.txt',
    ).readAsStringSync().trimRight();

    expect(transcript.trimRight(), fixture);
  });

  test('Vallee journey regression keeps reassurance, learned pressure, and closure distinct',
      () async {
    const service = UnconfiguredTelegramAiAssistantService();
    const learnedExample =
        'We are on it at MS Vallee Residence now. I will share the next confirmed step the moment control has it.';

    final intakeDraft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'I am scared, what is happening?',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
    );
    final pressuredDraft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'still waiting?',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      preferredReplyExamples: const [learnedExample],
      learnedReplyExamples: const [learnedExample],
      recentConversationTurns: const [
        'Telegram Inbound • telegram • Resident: still waiting',
        'Reply Sent • openai:gpt-4.1-mini • ONYX AI: We are on it at MS Vallee Residence and control is checking the latest position now. I will send the next confirmed update as soon as control has it.',
      ],
    );
    final closureDraft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'Thank you',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      recentConversationTurns: const [
        'Incident Resolved • onyx_monitoring • ONYX AI: Incident resolved at MS Vallee Residence.',
      ],
    );

    expect(intakeDraft.text, contains('You are not alone.'));
    expect(intakeDraft.text, contains('MS Vallee Residence'));
    expect(pressuredDraft.usedLearnedApprovalStyle, isTrue);
    expect(
      pressuredDraft.text,
      anyOf(
        contains('I will share the next confirmed step the moment control has it.'),
        contains('I will update you here the moment control confirms the next step.'),
      ),
    );
    expect(
      pressuredDraft.text,
      isNot(contains('I will send the next confirmed update as soon as control has it.')),
    );
    expect(closureDraft.text, contains('latest confirmed position'));
    expect(closureDraft.text, contains('secure'));
    expect(closureDraft.text, isNot(contains('You are not alone.')));
  });

  test('enterprise tower journey regression stays formal from access to closure',
      () async {
    const service = UnconfiguredTelegramAiAssistantService();

    final accessDraft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'The gate is not opening',
      clientId: 'CLIENT-SANDTON',
      siteId: 'SITE-SANDTON-TOWER',
    );
    final statusDraft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'Any update?',
      clientId: 'CLIENT-SANDTON',
      siteId: 'SITE-SANDTON-TOWER',
      recentConversationTurns: const [
        'Reply Sent • openai:gpt-4.1-mini • ONYX AI: We are actively checking access-control status for Sandton Tower now. I will share the next confirmed step the moment control has it.',
      ],
    );
    final closureDraft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'Thanks',
      clientId: 'CLIENT-SANDTON',
      siteId: 'SITE-SANDTON-TOWER',
      recentConversationTurns: const [
        'Incident Resolved • onyx_monitoring • ONYX AI: Incident resolved at Sandton Tower.',
      ],
    );

    expect(
      accessDraft.text,
      contains('checking access-control status for Sandton Tower now'),
    );
    expect(accessDraft.text, isNot(contains('You are not alone.')));
    expect(
      statusDraft.text,
      anyOf(
        contains('actively checking the latest position for Sandton Tower now'),
        contains('keep this lane updated the moment control confirms the next step'),
      ),
    );
    expect(statusDraft.text, isNot(contains('We are on it at Sandton Tower')));
    expect(closureDraft.text, contains('Sandton Tower is secure'));
    expect(closureDraft.text, isNot(contains('You are not alone.')));
  });
}
