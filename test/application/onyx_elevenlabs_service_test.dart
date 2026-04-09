import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:omnix_dashboard/application/onyx_elevenlabs_service.dart';

void main() {
  test('unconfigured elevenlabs service returns null', () async {
    const service = UnconfiguredOnyxElevenLabsService();

    final bytes = await service.synthesize('ONYX Security. All clear.');

    expect(service.isConfigured, isFalse);
    expect(bytes, isNull);
  });

  test('http elevenlabs service posts normalized capped payload', () async {
    late Uri requestUri;
    late Map<String, dynamic> payload;
    late String apiKey;
    final client = MockClient((request) async {
      requestUri = request.url;
      apiKey = request.headers['xi-api-key'] ?? '';
      payload = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response.bytes(const <int>[1, 2, 3, 4], 200);
    });
    final service = HttpOnyxElevenLabsService(
      client: client,
      apiKey: 'api-key-123',
      voiceId: 'voice-456',
    );
    final longText = List<String>.filled(120, 'status').join(' ');

    final bytes = await service.synthesize(longText);

    expect(service.isConfigured, isTrue);
    expect(
      requestUri.toString(),
      'https://api.elevenlabs.io/v1/text-to-speech/voice-456',
    );
    expect(apiKey, 'api-key-123');
    expect(payload['model_id'], kOnyxDefaultElevenLabsModelId);
    expect((payload['text'] as String).length, lessThanOrEqualTo(500));
    expect(bytes, isNotNull);
    expect(bytes, hasLength(4));
  });

  test('http elevenlabs service returns null on failed response', () async {
    final client = MockClient((request) async {
      return http.Response('bad request', 400);
    });
    final service = HttpOnyxElevenLabsService(
      client: client,
      apiKey: 'api-key-123',
      voiceId: 'voice-456',
    );

    final bytes = await service.synthesize('ONYX Security. All clear.');

    expect(bytes, isNull);
  });

  test(
    'http elevenlabs service uses local proxy when api base uri is set',
    () async {
      late Uri requestUri;
      late Map<String, dynamic> payload;
      late Map<String, String> headers;
      final client = MockClient((request) async {
        requestUri = request.url;
        headers = request.headers;
        payload = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response.bytes(const <int>[5, 4, 3, 2], 200);
      });
      final service = HttpOnyxElevenLabsService(
        client: client,
        apiKey: 'api-key-123',
        voiceId: 'voice-456',
        apiBaseUri: Uri.parse('http://127.0.0.1:11637'),
      );

      final bytes = await service.synthesize('ONYX Security. All clear.');

      expect(
        requestUri.toString(),
        'http://127.0.0.1:11637/elevenlabs/tts/voice-456',
      );
      expect(headers.containsKey('xi-api-key'), isFalse);
      expect(payload['model_id'], kOnyxDefaultElevenLabsModelId);
      expect(bytes, isNotNull);
      expect(bytes, hasLength(4));
    },
  );

  test('http elevenlabs service retries with fallback voice on 402', () async {
    final requestedPaths = <String>[];
    final client = MockClient((request) async {
      requestedPaths.add(request.url.path);
      if (request.url.path.endsWith('/voice-paid')) {
        return http.Response('{"detail":{"code":"paid_plan_required"}}', 402);
      }
      return http.Response.bytes(const <int>[9, 8, 7], 200);
    });
    final service = HttpOnyxElevenLabsService(
      client: client,
      apiKey: 'api-key-123',
      voiceId: 'voice-paid',
    );

    final bytes = await service.synthesize('ONYX Security. All clear.');

    expect(requestedPaths, <String>[
      '/v1/text-to-speech/voice-paid',
      '/v1/text-to-speech/$kOnyxDefaultElevenLabsVoiceId',
    ]);
    expect(bytes, isNotNull);
    expect(bytes, hasLength(3));
  });
}
