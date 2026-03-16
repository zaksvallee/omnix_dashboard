import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:omnix_dashboard/application/listener_alarm_feed_service.dart';

void main() {
  test(
    'parseJson accepts raw lines and envelope objects from mixed feed lists',
    () {
      final service = ListenerAlarmFeedService(
        feedUri: null,
        headers: const <String, String>{},
        client: MockClient((_) async => http.Response('[]', 200)),
      );

      final batch = service.parseJson(
        '''
      {
        "events": [
          "1130 01 004 1234 0001 2026-03-16T00:00:00Z",
          {
            "provider": "falcon_serial",
            "transport": "serial",
            "external_id": "evt-2",
            "account_number": "1234",
            "partition": "01",
            "event_code": "130",
            "event_qualifier": "1",
            "zone": "005",
            "user_code": "0001",
            "client_id": "CLIENT-OVERRIDE",
            "region_id": "REGION-OVERRIDE",
            "site_id": "SITE-OVERRIDE",
            "occurred_at_utc": "2026-03-16T00:01:00Z"
          }
        ]
      }
      ''',
        clientId: 'CLIENT-RAW',
        regionId: 'REGION-RAW',
        siteId: 'SITE-RAW',
      );

      expect(batch.acceptedCount, 2);
      expect(batch.rejectedCount, 0);
      expect(batch.envelopes.first.accountNumber, '1234');
      expect(batch.envelopes.first.clientId, 'CLIENT-RAW');
      expect(batch.envelopes.last.clientId, 'CLIENT-OVERRIDE');
      expect(batch.envelopes.last.siteId, 'SITE-OVERRIDE');
    },
  );

  test('parseJson supports line wrapper entries and classifies rejects', () {
    final service = ListenerAlarmFeedService(
      feedUri: null,
      headers: const <String, String>{},
      client: MockClient((_) async => http.Response('[]', 200)),
    );

    final batch = service.parseJson(
      '''
      {
        "payloads": [
          {
            "line": "1130 01 004 1234 0001 2026-03-16T00:00:00Z",
            "client_id": "CLIENT-WRAPPED",
            "site_id": "SITE-WRAPPED",
            "region_id": "REGION-WRAPPED"
          },
          "bad"
        ]
      }
      ''',
      clientId: 'CLIENT-RAW',
      regionId: 'REGION-RAW',
      siteId: 'SITE-RAW',
    );

    expect(batch.acceptedCount, 1);
    expect(batch.envelopes.single.clientId, 'CLIENT-WRAPPED');
    expect(batch.envelopes.single.siteId, 'SITE-WRAPPED');
    expect(batch.rejectedCount, 1);
    expect(batch.rejectReasonCounts['insufficient_tokens'], 1);
  });

  test(
    'fetchLatest applies auth headers and returns parsed envelopes',
    () async {
      late http.Request capturedRequest;
      final service = ListenerAlarmFeedService(
        feedUri: Uri.parse('https://listener.example.com/feed'),
        headers: const {'Authorization': 'Bearer abc', 'X-Test': '1'},
        client: MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            '["1130 01 004 1234 0001 2026-03-16T00:00:00Z"]',
            200,
          );
        }),
      );

      final batch = await service.fetchLatest(
        clientId: 'CLIENT-RAW',
        regionId: 'REGION-RAW',
        siteId: 'SITE-RAW',
      );

      expect(capturedRequest.method, 'GET');
      expect(capturedRequest.headers['Authorization'], 'Bearer abc');
      expect(capturedRequest.headers['X-Test'], '1');
      expect(capturedRequest.headers['Accept'], 'application/json');
      expect(batch.acceptedCount, 1);
      expect(batch.sourceLabel, 'listener.example.com');
    },
  );

  test(
    'fetchLatest throws helpful format error on non-success responses',
    () async {
      final service = ListenerAlarmFeedService(
        feedUri: Uri.parse('https://listener.example.com/feed'),
        headers: const <String, String>{},
        client: MockClient((_) async => http.Response('boom', 503)),
      );

      await expectLater(
        () => service.fetchLatest(
          clientId: 'CLIENT-RAW',
          regionId: 'REGION-RAW',
          siteId: 'SITE-RAW',
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('HTTP 503'),
          ),
        ),
      );
    },
  );
}
