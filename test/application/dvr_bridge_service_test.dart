import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:omnix_dashboard/application/dvr_bridge_service.dart';
import 'package:omnix_dashboard/application/dvr_ingest_contract.dart';
import 'package:omnix_dashboard/application/video_bridge_runtime.dart';
import 'package:omnix_dashboard/domain/intelligence/intel_ingestion.dart';

void main() {
  test('hikvision DVR bridge fetch normalizes event notification alert', () async {
    final payload = File(
      'test/fixtures/dvr_hikvision_isapi_event_notification_alert_sample.json',
    ).readAsStringSync();
    final client = MockClient((request) async {
      expect(request.url.toString(), 'https://dvr.example.com/ISAPI/Event/notification/alertStream');
      expect(request.headers['Authorization'], 'Bearer dvr-token');
      return http.Response(payload, 200);
    });
    final service = HttpDvrBridgeService(
      profile: DvrProviderProfile.hikvisionIsapi,
      eventsUri: Uri.parse(
        'https://dvr.example.com/ISAPI/Event/notification/alertStream',
      ),
      bearerToken: 'dvr-token',
      client: client,
    );

    final records = await service.fetchLatest(
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
    );

    expect(records, hasLength(1));
    expect(records.single.provider, 'hikvision_dvr');
    expect(records.single.externalId, 'DVR-EVT-1001');
    expect(records.single.sourceType, 'dvr');
    expect(records.single.cameraId, 'DVR-001');
    expect(records.single.headline, 'HIKVISION_DVR LINE_CROSSING');
    expect(records.single.summary, contains('snapshot:private-fetch'));
    expect(records.single.summary, contains('clip:private-fetch'));
    expect(
      records.single.snapshotUrl,
      'https://dvr.example.com/ISAPI/ContentMgmt/events/DVR-EVT-1001/snapshot',
    );
    expect(
      records.single.clipUrl,
      'https://dvr.example.com/ISAPI/ContentMgmt/events/DVR-EVT-1001/clip',
    );
  });

  test('generic DVR bridge fetch normalizes event list rows', () async {
    final payload = '''
{
  "events": [
    {
      "id": "GEN-DVR-7",
      "timestamp": "2026-03-13T10:20:00Z",
      "camera_id": "GEN-CAM-7",
      "channel_id": "7",
      "zone": "parking_north",
      "label": "vehicle",
      "confidence": 81.6,
      "event_type": "motion"
    }
  ]
}
''';
    final client = MockClient((request) async {
      expect(request.url.toString(), 'https://generic-dvr.example.com/api/events');
      return http.Response(payload, 200);
    });
    final service = HttpDvrBridgeService(
      profile: DvrProviderProfile.genericEventList,
      eventsUri: Uri.parse('https://generic-dvr.example.com/api/events'),
      client: client,
    );

    final records = await service.fetchLatest(
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
    );

    expect(records, hasLength(1));
    expect(records.single.provider, 'generic_dvr');
    expect(records.single.externalId, 'GEN-DVR-7');
    expect(records.single.summary, contains('channel:7'));
    expect(records.single.summary, contains('label:vehicle 81.6%'));
    expect(
      records.single.snapshotUrl,
      'https://generic-dvr.example.com/api/dvr/events/GEN-DVR-7/snapshot.jpg',
    );
  });

  test('createDvrBridgeService returns unconfigured when provider unsupported', () async {
    final service = createDvrBridgeService(
      provider: 'unknown_dvr',
      eventsUri: Uri.parse('https://dvr.example.com/events'),
      bearerToken: '',
      client: MockClient((_) async => http.Response('[]', 200)),
    );

    final records = await service.fetchLatest(
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
    );

    expect(records, isEmpty);
  });

  test('dvr-backed video bridge service delegates to dvr bridge service', () async {
    const delegate = _FakeDvrBridgeService();
    const service = DvrBackedVideoBridgeService(delegate: delegate);

    final records = await service.fetchLatest(
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
    );

    expect(records, hasLength(1));
    expect(records.single.provider, 'hikvision_dvr');
    expect(records.single.externalId, 'DVR-EVT-1');
  });
}

class _FakeDvrBridgeService implements DvrBridgeService {
  const _FakeDvrBridgeService();

  @override
  Future<List<NormalizedIntelRecord>> fetchLatest({
    required String clientId,
    required String regionId,
    required String siteId,
  }) async {
    return [
      DvrFixtureContractNormalizer(
        profile: DvrProviderProfile.hikvisionIsapi,
        baseUri: Uri.parse('https://dvr.example.com'),
      ).normalize(
        payload: {
          'EventNotificationAlert': {
            'UUID': 'DVR-EVT-1',
            'eventType': 'intrusion',
            'dateTime': '2026-03-13T10:20:00Z',
            'deviceID': 'DVR-001',
          },
        },
        clientId: clientId,
        regionId: regionId,
        siteId: siteId,
      )!.toNormalizedIntelRecord(),
    ];
  }
}
