import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:omnix_dashboard/application/dvr_bridge_service.dart';
import 'package:omnix_dashboard/application/dvr_http_auth.dart';
import 'package:omnix_dashboard/application/dvr_ingest_contract.dart';
import 'package:omnix_dashboard/application/video_bridge_runtime.dart';
import 'package:omnix_dashboard/domain/intelligence/intel_ingestion.dart';

void main() {
  test(
    'hikvision DVR bridge fetches alert stream rows over digest auth',
    () async {
      var unauthorizedRequests = 0;
      var authorizedRequests = 0;
      final client = MockClient((request) async {
        expect(
          request.url.toString(),
          'http://192.168.8.105/ISAPI/Event/notification/alertStream',
        );
        if ((request.headers['Authorization'] ?? '').startsWith('Digest ')) {
          authorizedRequests += 1;
          return http.Response(
            '''
--boundary
Content-Type: application/xml

<EventNotificationAlert version="2.0" xmlns="http://www.hikvision.com/ver20/XMLSchema">
  <ipAddress>192.168.8.105</ipAddress>
  <channelID>1</channelID>
  <dateTime>2026-03-13T10:15:22Z</dateTime>
  <eventType>VMD</eventType>
  <eventState>active</eventState>
  <eventDescription>Vehicle motion</eventDescription>
  <targetType>vehicle</targetType>
</EventNotificationAlert>
''',
            200,
            headers: {
              'content-type': 'multipart/x-mixed-replace; boundary=boundary',
            },
          );
        }
        unauthorizedRequests += 1;
        return http.Response(
          '',
          401,
          headers: {
            'www-authenticate':
                'Digest realm="Hikvision", nonce="abc123", qop="auth", opaque="xyz"',
          },
        );
      });
      final service = HttpDvrBridgeService(
        profile: DvrProviderProfile.hikvisionMonitorOnly,
        eventsUri: Uri.parse(
          'http://192.168.8.105/ISAPI/Event/notification/alertStream',
        ),
        authMode: DvrHttpAuthMode.digest,
        username: 'operator',
        password: 'secret',
        client: client,
      );

      final records = await service.fetchLatest(
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      );

      expect(records, hasLength(1));
      expect(unauthorizedRequests, greaterThanOrEqualTo(1));
      expect(authorizedRequests, greaterThanOrEqualTo(1));
      expect(records.single.provider, 'hikvision_dvr_monitor_only');
      expect(records.single.externalId, isNotEmpty);
      expect(records.single.sourceType, 'dvr');
      expect(records.single.cameraId, 'channel-1');
      expect(records.single.headline, 'HIKVISION_DVR_MONITOR_ONLY MOTION');
      expect(records.single.summary, contains('snapshot:private-fetch'));
      expect(records.single.summary, contains('clip:not_expected'));
      expect(
        records.single.snapshotUrl,
        'http://192.168.8.105/ISAPI/Streaming/channels/101/picture',
      );
      expect(records.single.clipUrl, isNull);
    },
  );

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
      expect(
        request.url.toString(),
        'https://generic-dvr.example.com/api/events',
      );
      return http.Response(payload, 200);
    });
    final service = HttpDvrBridgeService(
      profile: DvrProviderProfile.genericEventList,
      eventsUri: Uri.parse('https://generic-dvr.example.com/api/events'),
      authMode: DvrHttpAuthMode.none,
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

  test(
    'createDvrBridgeService returns unconfigured when provider unsupported',
    () async {
      final service = createDvrBridgeService(
        provider: 'unknown_dvr',
        eventsUri: Uri.parse('https://dvr.example.com/events'),
        authMode: '',
        bearerToken: '',
        username: '',
        password: '',
        client: MockClient((_) async => http.Response('[]', 200)),
      );

      final records = await service.fetchLatest(
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      );

      expect(records, isEmpty);
    },
  );

  test(
    'dvr-backed video bridge service delegates to dvr bridge service',
    () async {
      const delegate = _FakeDvrBridgeService();
      const service = DvrBackedVideoBridgeService(delegate: delegate);

      final records = await service.fetchLatest(
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      );

      expect(records, hasLength(1));
      expect(records.single.provider, 'hikvision_dvr_monitor_only');
      expect(records.single.externalId, 'DVR-EVT-1');
    },
  );
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
            profile: DvrProviderProfile.hikvisionMonitorOnly,
            baseUri: Uri.parse('https://dvr.example.com'),
          )
          .normalize(
            payload: {
              'EventNotificationAlert': {
                'UUID': 'DVR-EVT-1',
                'eventType': 'intrusion',
                'dateTime': '2026-03-13T10:20:00Z',
                'channelID': '2',
              },
            },
            clientId: clientId,
            regionId: regionId,
            siteId: siteId,
          )!
          .toNormalizedIntelRecord(),
    ];
  }
}
