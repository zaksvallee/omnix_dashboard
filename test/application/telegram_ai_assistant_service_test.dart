import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:omnix_dashboard/application/telegram_ai_assistant_service.dart';

void main() {
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
    expect(draft.text, contains('ONYX'));
  });

  test('openai assistant parses output_text payload', () async {
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['model'], 'gpt-4.1-mini');
      return http.Response(
        '{"id":"resp_1","output_text":"Reply from model."}',
        200,
      );
    });
    final service = OpenAiTelegramAiAssistantService(
      client: client,
      apiKey: 'sk-test',
      model: 'gpt-4.1-mini',
    );

    final draft = await service.draftReply(
      audience: TelegramAiAudience.admin,
      messageText: 'What is the status?',
      clientId: 'CLIENT-1',
      siteId: 'SITE-1',
    );

    expect(service.isConfigured, isTrue);
    expect(draft.usedFallback, isFalse);
    expect(draft.text, 'Reply from model.');
    expect(draft.providerLabel, 'openai:gpt-4.1-mini');
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
  });
}
