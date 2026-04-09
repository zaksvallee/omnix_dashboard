import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:omnix_dashboard/application/telegram_bridge_service.dart';

void main() {
  test('unconfigured bridge marks all messages as failed', () async {
    const service = UnconfiguredTelegramBridgeService();
    const outbound = [
      TelegramBridgeMessage(messageKey: 'm-1', chatId: '-1001', text: 'hello'),
      TelegramBridgeMessage(messageKey: 'm-2', chatId: '-1002', text: 'world'),
    ];

    final result = await service.sendMessages(messages: outbound);

    expect(service.isConfigured, isFalse);
    expect(result.sentCount, 0);
    expect(result.failedCount, 2);
    expect(
      result.failureReasonsByMessageKey['m-1'],
      'Telegram bridge not configured.',
    );
    expect(await service.fetchUpdates(), isEmpty);
  });

  test('http bridge sendMessage posts payload and marks success', () async {
    late Uri requestUri;
    late Map<String, dynamic> payload;
    final client = MockClient((request) async {
      requestUri = request.url;
      payload = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response('{"ok":true,"result":{"message_id":11}}', 200);
    });
    final service = HttpTelegramBridgeService(
      client: client,
      botToken: 'token-123',
    );

    final result = await service.sendMessages(
      messages: const [
        TelegramBridgeMessage(
          messageKey: 'm-ok',
          chatId: '-5247743742',
          messageThreadId: 77,
          text: 'ONYX test',
        ),
      ],
    );

    expect(service.isConfigured, isTrue);
    expect(requestUri.path, '/bottoken-123/sendMessage');
    expect(payload['chat_id'], '-5247743742');
    expect(payload['message_thread_id'], 77);
    expect(payload['text'], 'ONYX test');
    expect(payload['disable_web_page_preview'], isTrue);
    expect(result.sentCount, 1);
    expect(result.failedCount, 0);
    expect(result.telegramMessageIdsByMessageKey['m-ok'], 11);
  });

  test('http bridge includes reply markup when provided', () async {
    late Map<String, dynamic> payload;
    final client = MockClient((request) async {
      payload = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response('{"ok":true,"result":{"message_id":12}}', 200);
    });
    final service = HttpTelegramBridgeService(
      client: client,
      botToken: 'token-123',
    );

    final result = await service.sendMessages(
      messages: const [
        TelegramBridgeMessage(
          messageKey: 'm-kb',
          chatId: '-5247743742',
          text: 'ONYX keyboard test',
          parseMode: 'HTML',
          replyMarkup: {
            'keyboard': [
              [
                {'text': 'Brief'},
              ],
            ],
            'resize_keyboard': true,
          },
        ),
      ],
    );

    expect(result.sentCount, 1);
    expect(result.failedCount, 0);
    expect(payload['reply_markup'], isA<Map<String, dynamic>>());
    expect(payload['parse_mode'], 'HTML');
    final markup = payload['reply_markup'] as Map<String, dynamic>;
    expect(markup['resize_keyboard'], isTrue);
  });

  test('http bridge uses configured api base uri when provided', () async {
    late Uri requestUri;
    final client = MockClient((request) async {
      requestUri = request.url;
      return http.Response('{"ok":true,"result":{"message_id":21}}', 200);
    });
    final service = HttpTelegramBridgeService(
      client: client,
      botToken: 'token-123',
      apiBaseUri: Uri.parse('http://127.0.0.1:11637/proxy'),
    );

    final result = await service.sendMessages(
      messages: const [
        TelegramBridgeMessage(
          messageKey: 'm-proxy',
          chatId: '-5247743742',
          text: 'proxy test',
        ),
      ],
    );

    expect(
      requestUri.toString(),
      'http://127.0.0.1:11637/proxy/bottoken-123/sendMessage',
    );
    expect(result.sentCount, 1);
    expect(result.failedCount, 0);
  });

  test('http bridge sendPhoto uploads bytes with caption', () async {
    late Uri requestUri;
    late http.MultipartRequest multipart;
    final client = MockClient.streaming((request, _) async {
      requestUri = request.url;
      expect(request, isA<http.MultipartRequest>());
      multipart = request as http.MultipartRequest;
      return http.StreamedResponse(
        Stream<List<int>>.fromIterable([
          utf8.encode('{"ok":true,"result":{"message_id":13}}'),
        ]),
        200,
        headers: const {'content-type': 'application/json'},
      );
    });
    final service = HttpTelegramBridgeService(
      client: client,
      botToken: 'token-123',
    );

    final result = await service.sendMessages(
      messages: const [
        TelegramBridgeMessage(
          messageKey: 'm-photo',
          chatId: '-5247743742',
          messageThreadId: 77,
          text: 'Current verified frame from Camera 11 at MS Vallee Residence.',
          photoBytes: <int>[1, 2, 3, 4],
          photoFilename: 'vallee-camera-11.jpg',
        ),
      ],
    );

    expect(requestUri.path, '/bottoken-123/sendPhoto');
    expect(multipart.fields['chat_id'], '-5247743742');
    expect(multipart.fields['message_thread_id'], '77');
    expect(
      multipart.fields['caption'],
      'Current verified frame from Camera 11 at MS Vallee Residence.',
    );
    expect(multipart.files, hasLength(1));
    expect(multipart.files.single.field, 'photo');
    expect(multipart.files.single.filename, 'vallee-camera-11.jpg');
    expect(result.sentCount, 1);
    expect(result.failedCount, 0);
    expect(result.telegramMessageIdsByMessageKey['m-photo'], 13);
  });

  test(
    'http bridge returns description for failed telegram response',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          '{"ok":false,"description":"Forbidden: bot was blocked by the user"}',
          403,
        );
      });
      final service = HttpTelegramBridgeService(
        client: client,
        botToken: 'token-123',
      );

      final result = await service.sendMessages(
        messages: const [
          TelegramBridgeMessage(
            messageKey: 'm-blocked',
            chatId: '-1',
            text: 'test',
          ),
        ],
      );

      expect(result.sentCount, 0);
      expect(result.failedCount, 1);
      expect(
        result.failureReasonsByMessageKey['m-blocked'],
        'Forbidden: bot was blocked by the user',
      );
    },
  );

  test('http bridge marks blank chat_id as failed without request', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls += 1;
      return http.Response('{"ok":true}', 200);
    });
    final service = HttpTelegramBridgeService(
      client: client,
      botToken: 'token-123',
    );

    final result = await service.sendMessages(
      messages: const [
        TelegramBridgeMessage(
          messageKey: 'm-blank',
          chatId: ' ',
          text: 'ignored',
        ),
      ],
    );

    expect(calls, 0);
    expect(result.sentCount, 0);
    expect(result.failedCount, 1);
    expect(
      result.failureReasonsByMessageKey['m-blank'],
      'Missing Telegram chat_id.',
    );
  });

  test('http bridge fetchUpdates parses and sorts message updates', () async {
    late Uri requestUri;
    final client = MockClient((request) async {
      requestUri = request.url;
      return http.Response('''
{
  "ok": true,
  "result": [
    {
      "update_id": 2002,
      "message": {
        "message_id": 901,
        "date": 1773230402,
        "message_thread_id": 5,
        "chat": {"id": -5247743742, "type": "supergroup", "title": "ONYX Admin"},
        "from": {"id": 6652600225, "username": "zaks_vallee", "is_bot": false},
        "reply_to_message": {
          "message_id": 811,
          "text": "ONYX PARTNER DISPATCH\\nincident=DSP-1001\\nReply with: ACCEPT, ON SITE, ALL CLEAR, or CANCEL."
        },
        "text": "/status"
      }
    },
    {
      "update_id": 2001,
      "message": {
        "message_id": 900,
        "date": 1773230401,
        "chat": {"id": -5247743742, "type": "supergroup", "title": "ONYX Admin"},
        "from": {"id": 11, "username": "other_user", "is_bot": true},
        "text": "/critical"
      }
    },
    {
      "update_id": 2003,
      "message": {
        "message_id": 902,
        "chat": {"id": -5247743742, "type": "supergroup"},
        "text": ""
      }
    }
  ]
}
''', 200);
    });
    final service = HttpTelegramBridgeService(
      client: client,
      botToken: 'token-abc',
    );

    final updates = await service.fetchUpdates(offset: 123, limit: 40);

    expect(requestUri.path, '/bottoken-abc/getUpdates');
    expect(requestUri.queryParameters['offset'], '123');
    expect(requestUri.queryParameters['limit'], '40');
    expect(requestUri.queryParameters['timeout'], '0');
    expect(
      requestUri.queryParameters['allowed_updates'],
      '["message","callback_query"]',
    );
    expect(updates, hasLength(2));
    expect(updates[0].updateId, 2001);
    expect(updates[0].fromIsBot, isTrue);
    expect(updates[1].updateId, 2002);
    expect(updates[1].messageId, 901);
    expect(updates[1].chatId, '-5247743742');
    expect(updates[1].messageThreadId, 5);
    expect(updates[1].replyToMessageId, 811);
    expect(updates[1].replyToText, contains('incident=DSP-1001'));
    expect(updates[1].fromUserId, 6652600225);
    expect(updates[1].fromUsername, 'zaks_vallee');
    expect(updates[1].text, '/status');
    expect(updates[1].sentAtUtc?.toIso8601String(), '2026-03-11T12:00:02.000Z');
  });

  test(
    'http bridge fetchUpdates returns empty when telegram rejects',
    () async {
      final client = MockClient((request) async {
        return http.Response('{"ok":false,"description":"unauthorized"}', 401);
      });
      final service = HttpTelegramBridgeService(
        client: client,
        botToken: 'token-abc',
      );

      final updates = await service.fetchUpdates(offset: 1, limit: 5);

      expect(updates, isEmpty);
    },
  );
}
