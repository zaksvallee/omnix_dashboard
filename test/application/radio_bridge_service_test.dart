import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:omnix_dashboard/application/radio_bridge_service.dart';

void main() {
  test('zello fixture normalizes nested messages envelope', () async {
    final fixture = File(
      'test/fixtures/radio_zello_messages_sample.json',
    ).readAsStringSync();
    final client = MockClient((request) async {
      expect(request.url.toString(), 'https://radio.example.com/listen');
      return http.Response(fixture, 200);
    });
    final service = HttpRadioBridgeService(
      provider: 'zello',
      listenUri: Uri.parse('https://radio.example.com/listen'),
      respondUri: Uri.parse('https://radio.example.com/respond'),
      client: client,
    );

    final transmissions = await service.fetchLatest(
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
    );

    expect(transmissions, hasLength(2));
    expect(transmissions.first.provider, 'zello');
    expect(transmissions.first.transmissionId, 'zel-msg-1001');
    expect(transmissions.first.channel, 'ops-primary');
    expect(transmissions.first.speakerRole, 'client');
    expect(transmissions.first.speakerId, 'Resident-42');
    expect(transmissions.first.transcript, contains('all clear'));
    expect(transmissions.first.dispatchId, 'DSP-ZELLO-1');
  });

  test('radio bridge synthesizes id when message id is missing', () async {
    final client = MockClient((request) async {
      return http.Response('''
{
  "messages": [
    {
      "text": "Status update from control room",
      "timestamp": "1773224040",
      "from": {"name": "Control-1", "role": "controller"},
      "channel": {"name": "ops-primary"}
    }
  ]
}
''', 200);
    });
    final service = HttpRadioBridgeService(
      provider: 'zello',
      listenUri: Uri.parse('https://radio.example.com/listen'),
      respondUri: Uri.parse('https://radio.example.com/respond'),
      client: client,
    );

    final transmissions = await service.fetchLatest(
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
    );

    expect(transmissions, hasLength(1));
    expect(transmissions.first.transmissionId, startsWith('RAD-'));
    expect(transmissions.first.speakerId, 'Control-1');
    expect(transmissions.first.speakerRole, 'controller');
  });

  test(
    'radio bridge posts automated response payloads to respond endpoint',
    () async {
      final sentPayloads = <Map<String, dynamic>>[];
      final client = MockClient((request) async {
        if (request.method == 'POST') {
          expect(request.url.toString(), 'https://radio.example.com/respond');
          expect(request.headers['authorization'], 'Bearer token-123');
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          sentPayloads.add(payload);
          return http.Response('{"ok":true}', 200);
        }
        return http.Response('{"messages":[]}', 200);
      });
      final service = HttpRadioBridgeService(
        provider: 'zello',
        listenUri: Uri.parse('https://radio.example.com/listen'),
        respondUri: Uri.parse('https://radio.example.com/respond'),
        bearerToken: 'token-123',
        client: client,
      );

      final result = await service.sendAutomatedResponses(
        responses: const [
          RadioAutomatedResponse(
            transmissionId: 'ZEL-2001',
            provider: 'zello',
            channel: 'ops-primary',
            clientId: 'CLIENT-001',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            dispatchId: 'DSP-2001',
            message: 'ONYX AI marked dispatch DSP-2001 all clear.',
            responseType: 'AI_ALL_CLEAR_ACK',
            intent: 'all_clear',
          ),
        ],
      );

      expect(result.sentCount, 1);
      expect(result.failed, isEmpty);
      expect(sentPayloads, hasLength(1));
      expect(sentPayloads.single['transmission_id'], 'ZEL-2001');
      expect(sentPayloads.single['dispatch_id'], 'DSP-2001');
      expect(sentPayloads.single['response_type'], 'AI_ALL_CLEAR_ACK');
    },
  );

  test('radio bridge keeps failed responses for retry queue', () async {
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        return http.Response('{"error":"server"}', 503);
      }
      return http.Response('{"messages":[]}', 200);
    });
    final service = HttpRadioBridgeService(
      provider: 'zello',
      listenUri: Uri.parse('https://radio.example.com/listen'),
      respondUri: Uri.parse('https://radio.example.com/respond'),
      client: client,
    );

    final result = await service.sendAutomatedResponses(
      responses: const [
        RadioAutomatedResponse(
          transmissionId: 'ZEL-2002',
          provider: 'zello',
          channel: 'ops-primary',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          dispatchId: 'DSP-2002',
          message: 'ONYX AI marked dispatch DSP-2002 all clear.',
          responseType: 'AI_ALL_CLEAR_ACK',
          intent: 'all_clear',
        ),
      ],
    );

    expect(result.sent, isEmpty);
    expect(result.failed, hasLength(1));
    expect(result.failed.single.transmissionId, 'ZEL-2002');
  });

  test('radio bridge fetchLatest times out when endpoint stalls', () async {
    final client = MockClient((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return http.Response('{"messages":[]}', 200);
    });
    final service = HttpRadioBridgeService(
      provider: 'zello',
      listenUri: Uri.parse('https://radio.example.com/listen'),
      respondUri: Uri.parse('https://radio.example.com/respond'),
      requestTimeout: const Duration(milliseconds: 1),
      client: client,
    );

    expect(
      service.fetchLatest(
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      ),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('radio automated response serializes and deserializes', () {
    const response = RadioAutomatedResponse(
      transmissionId: 'ZEL-9991',
      provider: 'zello',
      channel: 'ops-primary',
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
      dispatchId: 'DSP-9',
      message: 'ACK',
      responseType: 'AI_STATUS_ACK',
      intent: 'status',
    );

    final restored = RadioAutomatedResponse.fromJson(response.toJson());

    expect(restored.toJson(), response.toJson());
  });
}
