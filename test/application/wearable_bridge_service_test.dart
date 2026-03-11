import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:omnix_dashboard/application/wearable_bridge_service.dart';

void main() {
  test('wearable panic alert normalizes with high risk', () async {
    final client = MockClient((request) async {
      expect(request.url.toString(), 'https://wearable.example.com/events');
      return http.Response('''
[
  {
    "event_id": "WR-7001",
    "event_type": "panic",
    "officer_id": "Echo-3",
    "heart_rate": 144,
    "battery_percent": 18,
    "summary": "Panic trigger from wearable",
    "occurred_at_utc": "2026-03-11T09:05:00Z"
  }
]
''', 200);
    });
    final service = HttpWearableBridgeService(
      provider: 'garmin',
      eventsUri: Uri.parse('https://wearable.example.com/events'),
      client: client,
    );

    final records = await service.fetchLatest(
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
    );

    expect(records, hasLength(1));
    expect(records.first.provider, 'garmin');
    expect(records.first.externalId, 'WR-7001');
    expect(records.first.sourceType, 'wearable');
    expect(records.first.summary, contains('officer:Echo-3'));
    expect(records.first.summary, contains('HR:144bpm'));
    expect(records.first.riskScore, greaterThanOrEqualTo(95));
  });

  test('wearable bridge parses wrapped items payload', () async {
    final client = MockClient((request) async {
      return http.Response('''
{
  "items": [
    {
      "id": "WR-7002",
      "alert_type": "check_in",
      "callsign": "Bravo-2",
      "battery": 62,
      "timestamp": "2026-03-11T09:10:00Z"
    }
  ]
}
''', 200);
    });
    final service = HttpWearableBridgeService(
      provider: 'garmin',
      eventsUri: Uri.parse('https://wearable.example.com/events'),
      client: client,
    );

    final records = await service.fetchLatest(
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
    );

    expect(records, hasLength(1));
    expect(records.first.externalId, 'WR-7002');
    expect(records.first.headline, contains('CHECK_IN'));
    expect(records.first.riskScore, inInclusiveRange(1, 99));
  });

  test('wearable bridge fetchLatest times out when endpoint stalls', () async {
    final client = MockClient((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return http.Response('[]', 200);
    });
    final service = HttpWearableBridgeService(
      provider: 'garmin',
      eventsUri: Uri.parse('https://wearable.example.com/events'),
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
}
