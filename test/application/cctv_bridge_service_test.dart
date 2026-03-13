import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:omnix_dashboard/application/cctv_bridge_service.dart';
import 'package:omnix_dashboard/application/cctv_false_positive_policy.dart';

void main() {
  test('hikvision payload normalizes FR/LPR enriched record', () async {
    final client = MockClient((request) async {
      expect(request.url.toString(), 'https://cctv.example.com/events');
      return http.Response('''
[
  {
    "event_id": "HIK-101",
    "eventType": "intrusion",
    "camera_id": "CAM-NORTH-1",
    "face_match_id": "PERSON-77",
    "fr_confidence": 92.5,
    "license_plate": "CA123456",
    "lpr_confidence": 89.0,
    "summary": "Perimeter breach at north gate",
    "occurred_at_utc": "2026-03-11T08:14:00Z"
  }
]
''', 200);
    });
    final service = HttpCctvBridgeService(
      provider: 'hikvision',
      eventsUri: Uri.parse('https://cctv.example.com/events'),
      client: client,
      liveMonitoringEnabled: true,
      facialRecognitionEnabled: true,
      licensePlateRecognitionEnabled: true,
    );

    final records = await service.fetchLatest(
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
    );

    expect(records, hasLength(1));
    expect(records.first.provider, 'hikvision');
    expect(records.first.externalId, 'HIK-101');
    expect(records.first.headline, contains('INTRUSION'));
    expect(records.first.summary, contains('FR:PERSON-77'));
    expect(records.first.summary, contains('LPR:CA123456'));
    expect(records.first.riskScore, greaterThanOrEqualTo(90));
  });

  test('axis payload with no capabilities still normalizes', () async {
    final client = MockClient((request) async {
      return http.Response('''
{
  "items": [
    {
      "id": "AX-11",
      "topic": "motion",
      "camera": "AX-CAM-2",
      "description": "Motion detected in parking",
      "timestamp": "2026-03-11T08:20:00Z"
    }
  ]
}
''', 200);
    });
    final service = HttpCctvBridgeService(
      provider: 'axis',
      eventsUri: Uri.parse('https://axis.example.com/events'),
      client: client,
      liveMonitoringEnabled: false,
      facialRecognitionEnabled: false,
      licensePlateRecognitionEnabled: false,
    );

    final records = await service.fetchLatest(
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
    );

    expect(records, hasLength(1));
    expect(records.first.externalId, 'AX-11');
    expect(records.first.summary, contains('camera:AX-CAM-2'));
    expect(records.first.riskScore, inInclusiveRange(1, 99));
  });

  test('dahua payload normalizes tripwire into line crossing', () async {
    final client = MockClient((request) async {
      return http.Response('''
{
  "events": [
    {
      "Code": "CrossLine",
      "UTC": "2026-03-11T08:25:00Z",
      "Info": {
        "EventID": "DH-9001",
        "DeviceSerialNo": "DH-CAM-9",
        "PlateNumber": "GP77777",
        "confidence": 93.0,
        "description": "Tripwire crossed near east fence"
      }
    }
  ]
}
''', 200);
    });
    final service = HttpCctvBridgeService(
      provider: 'dahua',
      eventsUri: Uri.parse('https://dahua.example.com/events'),
      client: client,
      liveMonitoringEnabled: true,
      facialRecognitionEnabled: false,
      licensePlateRecognitionEnabled: true,
    );

    final records = await service.fetchLatest(
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
    );

    expect(records, hasLength(1));
    expect(records.first.provider, 'dahua');
    expect(records.first.externalId, 'DH-9001');
    expect(records.first.headline, contains('LINE_CROSSING'));
    expect(records.first.summary, contains('provider:dahua'));
    expect(records.first.summary, contains('LPR:GP77777'));
  });

  test('frigate event list normalizes pilot edge fields', () async {
    final client = MockClient((request) async {
      return http.Response('''
[
  {
    "id": "1709918700.123-front-gate-person",
    "camera": "front-gate",
    "label": "person",
    "entered_zones": ["north_gate"],
    "top_score": 0.9731,
    "start_time": 1709918700.123,
    "has_snapshot": true,
    "has_clip": true
  }
]
''', 200);
    });
    final service = HttpCctvBridgeService(
      provider: 'frigate',
      eventsUri: Uri.parse('https://edge.example.com/api/events'),
      client: client,
      liveMonitoringEnabled: true,
      facialRecognitionEnabled: false,
      licensePlateRecognitionEnabled: false,
    );

    final records = await service.fetchLatest(
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
    );

    expect(records, hasLength(1));
    expect(records.first.provider, 'frigate');
    expect(records.first.externalId, '1709918700.123-front-gate-person');
    expect(records.first.headline, 'FRIGATE INTRUSION');
    expect(records.first.summary, contains('camera:front-gate'));
    expect(records.first.summary, contains('zone:north_gate'));
    expect(records.first.summary, contains('label:person 97.3%'));
    expect(records.first.summary, contains('provider:frigate'));
    expect(records.first.summary, contains('snapshot:available'));
    expect(records.first.summary, contains('clip:available'));
    expect(
      records.first.snapshotUrl,
      'https://edge.example.com/api/events/1709918700.123-front-gate-person/snapshot.jpg',
    );
    expect(
      records.first.clipUrl,
      'https://edge.example.com/api/events/1709918700.123-front-gate-person/clip.mp4',
    );
    expect(records.first.siteId, 'SITE-SANDTON');
    expect(records.first.riskScore, greaterThanOrEqualTo(95));
    expect(
      records.first.occurredAtUtc,
      DateTime.fromMillisecondsSinceEpoch(1709918700123, isUtc: true),
    );
  });

  test(
    'frigate MQTT envelope flattens after payload and skips false positives',
    () async {
      final client = MockClient((request) async {
        return http.Response('''
[
  {
    "type": "new",
    "before": {
      "id": "evt-old",
      "camera": "yard",
      "label": "person",
      "start_time": 1709918600.0
    },
    "after": {
      "id": "evt-1",
      "camera": "yard",
      "label": "car",
      "current_zones": ["driveway"],
      "top_score": 0.88,
      "start_time": 1709918601.0,
      "false_positive": false
    }
  },
  {
    "type": "new",
    "after": {
      "id": "evt-2",
      "camera": "yard",
      "label": "person",
      "start_time": 1709918602.0,
      "false_positive": true
    }
  }
]
''', 200);
      });
      final service = HttpCctvBridgeService(
        provider: 'frigate',
        eventsUri: Uri.parse('https://edge.example.com/api/events'),
        client: client,
        liveMonitoringEnabled: true,
        facialRecognitionEnabled: false,
        licensePlateRecognitionEnabled: false,
      );

      final records = await service.fetchLatest(
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      );

      expect(records, hasLength(1));
      expect(records.first.externalId, 'evt-1');
      expect(records.first.summary, contains('camera:yard'));
      expect(records.first.summary, contains('zone:driveway'));
      expect(records.first.summary, contains('label:car 88.0%'));
      expect(
        records.first.snapshotUrl,
        'https://edge.example.com/api/events/evt-1/snapshot.jpg',
      );
      expect(
        records.first.clipUrl,
        'https://edge.example.com/api/events/evt-1/clip.mp4',
      );
    },
  );

  test(
    'hikvision EventNotificationAlert fixture normalizes nested schema',
    () async {
      final fixture = File(
        'test/fixtures/cctv_hikvision_event_notification_alert_sample.json',
      ).readAsStringSync();
      final client = MockClient((request) async => http.Response(fixture, 200));
      final service = HttpCctvBridgeService(
        provider: 'hikvision',
        eventsUri: Uri.parse('https://hikvision.example.com/events'),
        client: client,
        liveMonitoringEnabled: true,
        facialRecognitionEnabled: true,
        licensePlateRecognitionEnabled: true,
      );

      final records = await service.fetchLatest(
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      );

      expect(records, hasLength(1));
      expect(records.first.externalId, isNotEmpty);
      expect(records.first.headline, contains('LINE_CROSSING'));
      expect(records.first.summary, contains('Line crossing alert'));
      expect(records.first.summary, contains('FR:PERSON-77'));
      expect(records.first.summary, contains('LPR:CA123456'));
    },
  );

  test('cctv bridge fetchLatest times out when endpoint stalls', () async {
    final client = MockClient((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return http.Response('[]', 200);
    });
    final service = HttpCctvBridgeService(
      provider: 'hikvision',
      eventsUri: Uri.parse('https://cctv.example.com/events'),
      requestTimeout: const Duration(milliseconds: 1),
      client: client,
      liveMonitoringEnabled: true,
      facialRecognitionEnabled: true,
      licensePlateRecognitionEnabled: true,
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

  test(
    'false-positive rules suppress matching zone/time window events',
    () async {
      final client = MockClient((request) async {
        return http.Response('''
[
  {
    "id": "evt-quiet",
    "camera": "yard",
    "label": "cat",
    "entered_zones": ["garden"],
    "top_score": 0.91,
    "start_time": "2026-03-13T01:10:00Z"
  },
  {
    "id": "evt-keep",
    "camera": "yard",
    "label": "person",
    "entered_zones": ["garden"],
    "top_score": 0.91,
    "start_time": "2026-03-13T01:12:00Z"
  }
]
''', 200);
      });
      final service = HttpCctvBridgeService(
        provider: 'frigate',
        eventsUri: Uri.parse('https://edge.example.com/api/events'),
        client: client,
        liveMonitoringEnabled: true,
        facialRecognitionEnabled: false,
        licensePlateRecognitionEnabled: false,
        falsePositivePolicy: const CctvFalsePositivePolicy(
          rules: [
            CctvFalsePositiveRule(
              zone: 'garden',
              objectLabel: 'cat',
              startHourLocal: 0,
              endHourLocal: 6,
              minConfidencePercent: 80,
            ),
          ],
        ),
      );

      final records = await service.fetchLatest(
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      );

      expect(records, hasLength(1));
      expect(records.first.externalId, 'evt-keep');
    },
  );
}
