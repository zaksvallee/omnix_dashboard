import 'dart:async';
import 'dart:convert';

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

  test(
    'hikvision DVR bridge normalizes video-loss alert stream rows as video loss',
    () async {
      final client = MockClient((request) async {
        if ((request.headers['Authorization'] ?? '').startsWith('Digest ')) {
          return http.Response(
            '''
--boundary
Content-Type: application/xml

<EventNotificationAlert version="2.0" xmlns="http://www.hikvision.com/ver20/XMLSchema">
  <ipAddress>192.168.8.105</ipAddress>
  <channelID>11</channelID>
  <dateTime>2026-03-13T10:16:22Z</dateTime>
  <eventType>videoloss</eventType>
  <eventState>active</eventState>
  <eventDescription>Video loss</eventDescription>
</EventNotificationAlert>
''',
            200,
            headers: {
              'content-type': 'multipart/x-mixed-replace; boundary=boundary',
            },
          );
        }
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
      expect(records.single.provider, 'hikvision_dvr_monitor_only');
      expect(records.single.cameraId, 'channel-11');
      expect(records.single.headline, 'HIKVISION_DVR_MONITOR_ONLY VIDEO_LOSS');
      expect(records.single.objectLabel, isNull);
    expect(records.single.summary, contains('snapshot:private-fetch'));
  },
  );

  test(
    'hikvision DVR bridge keeps buffering live alert-stream events between fetches',
    () async {
      final allowSecondEvent = Completer<void>();
      final client = _ScriptedStreamHttpClient((request, requestCount) async {
        expect(
          request.url.toString(),
          'http://127.0.0.1/ISAPI/Event/notification/alertStream',
        );
        const headers = <String, String>{
          'content-type': 'multipart/x-mixed-replace; boundary=boundary',
        };
        if (requestCount == 1) {
          return http.StreamedResponse(
            Stream<List<int>>.value(
              utf8.encode('''
--boundary
Content-Type: application/xml

<EventNotificationAlert version="2.0" xmlns="http://www.hikvision.com/ver20/XMLSchema">
  <ipAddress>192.168.8.105</ipAddress>
  <channelID>16</channelID>
  <dateTime>2026-04-05T19:07:25Z</dateTime>
  <eventType>VMD</eventType>
  <eventState>active</eventState>
  <eventDescription>Motion alarm</eventDescription>
  <targetType>human</targetType>
</EventNotificationAlert>
'''),
            ),
            200,
            headers: headers,
          );
        }
        if (requestCount == 2) {
          final controller = StreamController<List<int>>();
          unawaited(() async {
            await allowSecondEvent.future;
            controller.add(
              utf8.encode('''
--boundary
Content-Type: application/xml

<EventNotificationAlert version="2.0" xmlns="http://www.hikvision.com/ver20/XMLSchema">
  <ipAddress>192.168.8.105</ipAddress>
  <channelID>17</channelID>
  <dateTime>2026-04-05T19:07:45Z</dateTime>
  <eventType>VMD</eventType>
  <eventState>active</eventState>
  <eventDescription>Motion alarm</eventDescription>
  <targetType>human</targetType>
</EventNotificationAlert>
'''),
            );
            await controller.close();
          }());
          return http.StreamedResponse(controller.stream, 200, headers: headers);
        }
        return http.StreamedResponse(
          const Stream<List<int>>.empty(),
          200,
          headers: headers,
        );
      });
      final service = HttpDvrBridgeService(
        profile: DvrProviderProfile.hikvisionMonitorOnly,
        eventsUri: Uri.parse('http://127.0.0.1/ISAPI/Event/notification/alertStream'),
        authMode: DvrHttpAuthMode.none,
        client: client,
        requestTimeout: const Duration(milliseconds: 1500),
        alertStreamIdleWindow: const Duration(milliseconds: 250),
        alertStreamReconnectDelay: const Duration(milliseconds: 40),
      );
      addTearDown(() {
        service.dispose();
        client.close();
      });

      final firstRecords = await service.fetchLatest(
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      );

      expect(firstRecords, hasLength(1));
      expect(firstRecords.single.cameraId, 'channel-16');
      expect(firstRecords.single.objectLabel, 'human');

      allowSecondEvent.complete();
      await Future<void>.delayed(const Duration(milliseconds: 220));

      final secondRecords = await service.fetchLatest(
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      );

      expect(secondRecords, hasLength(1));
      expect(secondRecords.single.cameraId, 'channel-17');
      expect(secondRecords.single.objectLabel, 'human');
    },
  );

  test(
    'hikvision DVR bridge records healthy alert-stream contact even when no rows arrive',
    () async {
      final client = _ScriptedStreamHttpClient((request, requestCount) async {
        expect(
          request.url.toString(),
          'http://127.0.0.1/ISAPI/Event/notification/alertStream',
        );
        return http.StreamedResponse(
          const Stream<List<int>>.empty(),
          200,
          headers: const <String, String>{
            'content-type': 'multipart/x-mixed-replace; boundary=boundary',
          },
        );
      });
      final service = HttpDvrBridgeService(
        profile: DvrProviderProfile.hikvisionMonitorOnly,
        eventsUri: Uri.parse(
          'http://127.0.0.1/ISAPI/Event/notification/alertStream',
        ),
        authMode: DvrHttpAuthMode.none,
        client: client,
        requestTimeout: const Duration(milliseconds: 400),
        alertStreamIdleWindow: const Duration(milliseconds: 80),
        alertStreamReconnectDelay: const Duration(milliseconds: 40),
      );
      addTearDown(() {
        service.dispose();
        client.close();
      });

      final records = await service.fetchLatest(
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      );

      expect(records, isEmpty);
      final health = service.healthSnapshot();
      expect(health, isNotNull);
      expect(health!.lastHealthyAtUtc, isNotNull);
      expect(health.lastError, isEmpty);
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
    'hik-connect cloud bridge fetches alarm queue rows and completes batch',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/hccgw/platform/v1/token/get') {
          return http.Response(
            '''
          {
            "errorCode":"0",
            "data":{
              "appToken":"token-123",
              "expireTime":"${DateTime.now().toUtc().add(const Duration(days: 6)).millisecondsSinceEpoch}",
              "streamAreaDomain":"https://stream.example.com"
            }
          }
          ''',
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/hccgw/alarm/v1/mq/subscribe') {
          return http.Response('{"errorCode":"0"}', 200);
        }
        if (request.url.path == '/api/hccgw/alarm/v1/mq/messages') {
          return http.Response(
            '''
          {
            "errorCode":"0",
            "data":{
              "batchId":"batch-001",
              "remainingNumber":0,
              "alarmMsg":[
                {
                  "guid":"hik-connect-guid-1",
                  "msgType":"1",
                  "alarmState":"1",
                  "alarmSubCategory":"alarmSubCategoryCamera",
                  "timeInfo":{"startTime":"2026-03-30T00:10:00Z"},
                  "eventSource":{
                    "eventType":"100657",
                    "sourceID":"camera-resource-1",
                    "sourceName":"IPCamera 01",
                    "sourceType":"camera",
                    "areaName":"MS Vallee Residence",
                    "deviceInfo":{"devName":"G95721825"}
                  },
                  "alarmRule":{"name":"People Queue Leave"},
                  "anprInfo":{"licensePlate":"CA123456"},
                  "fileInfo":{
                    "file":[
                      {"type":"1","URL":"https://files.example.com/snapshot.jpg"},
                      {"type":"2","URL":"https://files.example.com/clip.mp4"}
                    ]
                  }
                }
              ]
            }
          }
          ''',
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/hccgw/alarm/v1/mq/messages/complete') {
          expect(request.headers['Token'], 'token-123');
          expect(request.body, contains('"batchId":"batch-001"'));
          return http.Response('{"errorCode":"0"}', 200);
        }
        fail('Unexpected request: ${request.method} ${request.url}');
      });

      final service = createDvrBridgeService(
        provider: 'hik_connect_openapi',
        eventsUri: null,
        authMode: '',
        bearerToken: '',
        username: '',
        password: '',
        client: client,
        apiBaseUri: Uri.parse('https://api.hik-connect.example.com'),
        appKey: 'app-key',
        appSecret: 'app-secret',
        areaId: '-1',
        includeSubArea: true,
        deviceSerialNo: 'SERIAL-001',
        alarmEventTypes: const <int>[0, 1, 100657],
      );

      final records = await service.fetchLatest(
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      );

      expect(records, hasLength(1));
      expect(records.single.provider, 'hik_connect_openapi');
      expect(records.single.externalId, 'hik-connect-guid-1');
      expect(records.single.cameraId, 'camera-resource-1');
      expect(records.single.zone, 'MS Vallee Residence');
      expect(records.single.plateNumber, 'CA123456');
      expect(records.single.headline, 'HIK_CONNECT_OPENAPI LPR_ALERT');
      expect(
        records.single.snapshotUrl,
        'https://files.example.com/snapshot.jpg',
      );
      expect(records.single.clipUrl, 'https://files.example.com/clip.mp4');
      expect(records.single.summary, contains('rule:People Queue Leave'));
      expect(records.single.summary, contains('LPR:CA123456'));
      expect(
        requests.where(
          (request) => request.url.path == '/api/hccgw/alarm/v1/mq/subscribe',
        ),
        hasLength(1),
      );
      expect(
        requests.where(
          (request) =>
              request.url.path == '/api/hccgw/alarm/v1/mq/messages/complete',
        ),
        hasLength(1),
      );
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

  @override
  DvrBridgeHealthSnapshot? healthSnapshot() => null;

  @override
  void dispose() {}
}

class _ScriptedStreamHttpClient extends http.BaseClient {
  _ScriptedStreamHttpClient(this._handler);

  final Future<http.StreamedResponse> Function(
    http.BaseRequest request,
    int requestCount,
  )
  _handler;

  int _requestCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    _requestCount += 1;
    return _handler(request, _requestCount);
  }
}
