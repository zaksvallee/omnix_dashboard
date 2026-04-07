import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:omnix_dashboard/application/hik_connect_openapi_client.dart';
import 'package:omnix_dashboard/application/hik_connect_openapi_config.dart';
import 'package:omnix_dashboard/application/hik_connect_payload_bundle_collector_service.dart';
import 'package:omnix_dashboard/application/hik_connect_payload_bundle_locator.dart';

void main() {
  final config = HikConnectOpenApiConfig(
    clientId: 'CLIENT-MS-VALLEE',
    regionId: 'REGION-GAUTENG',
    siteId: 'SITE-MS-VALLEE-RESIDENCE',
    baseUri: Uri(
      scheme: 'https',
      host: 'api.hik-connect.example.com',
    ),
    appKey: 'test-key',
    appSecret: 'test-secret',
    areaId: '-1',
    includeSubArea: true,
    deviceSerialNo: '',
    alarmEventTypes: <int>[0, 1, 100657],
    cameraLabels: <String, String>{},
  );

  test('collects a real payload bundle from Hik-Connect responses', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/hccgw/platform/v1/token/get') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'errorCode': '0',
            'data': <String, Object?>{
              'appToken': 'token-collector',
              'expireTime':
                  '${DateTime.now().toUtc().add(const Duration(days: 3)).millisecondsSinceEpoch}',
              'streamAreaDomain': 'https://stream.example.com',
            },
          }),
          200,
        );
      }
      if (request.url.path == '/api/hccgw/resource/v1/areas/cameras/get') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'errorCode': '0',
            'data': <String, Object?>{
              'totalCount': 1,
              'pageIndex': 1,
              'pageSize': 200,
              'cameraInfo': <Object?>[
                <String, Object?>{
                  'resourceId': 'camera-front',
                  'cameraName': 'Front Yard',
                  'deviceSerialNo': 'SERIAL-001',
                  'areaName': 'MS Vallee Residence',
                },
              ],
            },
          }),
          200,
        );
      }
      if (request.url.path == '/api/hccgw/alarm/v1/mq/messages') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'errorCode': '0',
            'data': <String, Object?>{
              'batchId': 'batch-001',
              'alarmMsg': <Object?>[
                <String, Object?>{'guid': 'hik-guid-1'},
              ],
            },
          }),
          200,
        );
      }
      if (request.url.path == '/api/hccgw/video/v1/live/address/get') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'errorCode': '0',
            'data': <String, Object?>{
              'url': 'wss://stream.example.com/live/token',
            },
          }),
          200,
        );
      }
      if (request.url.path == '/api/hccgw/video/v1/record/element/search') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'errorCode': '0',
            'data': <String, Object?>{
              'totalCount': 1,
              'pageIndex': 1,
              'pageSize': 50,
              'recordList': <Object?>[
                <String, Object?>{
                  'recordId': 'record-001',
                  'beginTime': '2026-03-30T00:00:00Z',
                  'endTime': '2026-03-30T00:05:00Z',
                },
              ],
            },
          }),
          200,
        );
      }
      if (request.url.path == '/api/hccgw/video/v1/video/download/url') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'errorCode': '0',
            'data': <String, Object?>{
              'downloadUrl': 'https://stream.example.com/download/video.mp4',
            },
          }),
          200,
        );
      }
      fail('Unexpected request: ${request.method} ${request.url}');
    });

    final directory = Directory.systemTemp.createTempSync(
      'hik-connect-bundle-collector-test-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));

    final api = HikConnectOpenApiClient(config: config, client: client);
    const service = HikConnectPayloadBundleCollectorService();
    final result = await service.collect(
      api: api,
      directoryPath: directory.path,
      clientId: config.clientId,
      regionId: config.regionId,
      siteId: config.siteId,
      pageSize: 125,
      maxPages: 7,
      playbackLookback: const Duration(minutes: 90),
      playbackWindow: const Duration(minutes: 12),
      nowUtc: DateTime.utc(2026, 3, 30, 0, 30),
    );

    expect(result.cameraCount, 1);
    expect(result.alarmMessageCount, 1);
    expect(result.representativeCameraId, 'camera-front');
    expect(result.representativeDeviceSerial, 'SERIAL-001');
    expect(result.warnings, isEmpty);

    final cameraJson = jsonDecode(
      File(
        '${directory.path}/${HikConnectPayloadBundleLocator.defaultCameraFileName}',
      ).readAsStringSync(),
    ) as Map<String, Object?>;
    final pages = cameraJson['pages'] as List<Object?>;
    expect(pages, hasLength(1));

    final alarmJson = jsonDecode(
      File(
        '${directory.path}/${HikConnectPayloadBundleLocator.defaultAlarmFileName}',
      ).readAsStringSync(),
    ) as Map<String, Object?>;
    expect(
      ((alarmJson['data'] as Map<String, Object?>)['alarmMsg'] as List<Object?>)
          .length,
      1,
    );

    final liveJson = jsonDecode(
      File(
        '${directory.path}/${HikConnectPayloadBundleLocator.defaultLiveFileName}',
      ).readAsStringSync(),
    ) as Map<String, Object?>;
    expect(
      (liveJson['data'] as Map<String, Object?>)['url'],
      'wss://stream.example.com/live/token',
    );

    final downloadJson = jsonDecode(
      File(
        '${directory.path}/${HikConnectPayloadBundleLocator.defaultVideoDownloadFileName}',
      ).readAsStringSync(),
    ) as Map<String, Object?>;
    expect(
      (downloadJson['data'] as Map<String, Object?>)['downloadUrl'],
      'https://stream.example.com/download/video.mp4',
    );

    expect(
      requests
          .where(
            (request) =>
                request.url.path == '/api/hccgw/resource/v1/areas/cameras/get',
          )
          .length,
      1,
    );
    expect(
      requests.any(
        (request) => request.url.path == '/api/hccgw/alarm/v1/mq/messages',
      ),
      isTrue,
    );
    final manifestJson = jsonDecode(
      File(
        '${directory.path}/${HikConnectPayloadBundleLocator.defaultManifestFileName}',
      ).readAsStringSync(),
    ) as Map<String, Object?>;
    expect(manifestJson['area_id'], '-1');
    expect(manifestJson['include_sub_area'], true);
    expect(manifestJson['device_serial_no'], '');
    expect(manifestJson['alarm_event_types'], <Object?>[0, 1, 100657]);
    expect(
      manifestJson['camera_labels'],
      <String, Object?>{
        'camera-front': 'Front Yard',
      },
    );
    expect(manifestJson['representative_camera_id'], 'camera-front');
    expect(manifestJson['representative_device_serial_no'], 'SERIAL-001');
    expect(manifestJson['last_collection_at_utc'], '2026-03-30T00:30:00.000Z');
    expect(manifestJson['last_collection_camera_count'], 1);
    expect(manifestJson['last_collection_alarm_message_count'], 1);
    expect(
      manifestJson['last_collection_representative_camera_id'],
      'camera-front',
    );
    expect(
      manifestJson['last_collection_representative_device_serial_no'],
      'SERIAL-001',
    );
    expect(manifestJson['last_collection_warnings'], <Object?>[]);
    expect(manifestJson['page_size'], 125);
    expect(manifestJson['max_pages'], 7);
    expect(manifestJson['playback_lookback_minutes'], 90);
    expect(manifestJson['playback_window_minutes'], 12);
  });

  test('uses the requested representative camera override for video collection', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/hccgw/platform/v1/token/get') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'errorCode': '0',
            'data': <String, Object?>{
              'appToken': 'token-collector',
              'expireTime':
                  '${DateTime.now().toUtc().add(const Duration(days: 3)).millisecondsSinceEpoch}',
              'streamAreaDomain': 'https://stream.example.com',
            },
          }),
          200,
        );
      }
      if (request.url.path == '/api/hccgw/resource/v1/areas/cameras/get') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'errorCode': '0',
            'data': <String, Object?>{
              'totalCount': 2,
              'pageIndex': 1,
              'pageSize': 200,
              'cameraInfo': <Object?>[
                <String, Object?>{
                  'resourceId': 'camera-front',
                  'cameraName': 'Front Yard',
                  'deviceSerialNo': 'SERIAL-001',
                  'areaName': 'MS Vallee Residence',
                },
                <String, Object?>{
                  'resourceId': 'camera-back',
                  'cameraName': 'Back Yard',
                  'deviceSerialNo': 'SERIAL-002',
                  'areaName': 'MS Vallee Residence',
                },
              ],
            },
          }),
          200,
        );
      }
      if (request.url.path == '/api/hccgw/alarm/v1/mq/messages') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'errorCode': '0',
            'data': <String, Object?>{
              'batchId': 'batch-001',
              'alarmMsg': <Object?>[],
            },
          }),
          200,
        );
      }
      if (request.url.path == '/api/hccgw/video/v1/live/address/get') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'errorCode': '0',
            'data': <String, Object?>{
              'url': 'wss://stream.example.com/live/token',
            },
          }),
          200,
        );
      }
      if (request.url.path == '/api/hccgw/video/v1/record/element/search') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'errorCode': '0',
            'data': <String, Object?>{
              'totalCount': 1,
              'pageIndex': 1,
              'pageSize': 50,
              'recordList': <Object?>[
                <String, Object?>{
                  'recordId': 'record-002',
                  'beginTime': '2026-03-30T00:10:00Z',
                  'endTime': '2026-03-30T00:15:00Z',
                },
              ],
            },
          }),
          200,
        );
      }
      if (request.url.path == '/api/hccgw/video/v1/video/download/url') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'errorCode': '0',
            'data': <String, Object?>{
              'downloadUrl': 'https://stream.example.com/download/video-002.mp4',
            },
          }),
          200,
        );
      }
      fail('Unexpected request: ${request.method} ${request.url}');
    });

    final directory = Directory.systemTemp.createTempSync(
      'hik-connect-bundle-collector-override-test-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));

    final api = HikConnectOpenApiClient(config: config, client: client);
    const service = HikConnectPayloadBundleCollectorService();
    final result = await service.collect(
      api: api,
      directoryPath: directory.path,
      clientId: config.clientId,
      regionId: config.regionId,
      siteId: config.siteId,
      representativeCameraId: 'camera-back',
      representativeDeviceSerial: 'SERIAL-002',
      pageSize: 64,
      maxPages: 3,
      playbackLookback: const Duration(minutes: 45),
      playbackWindow: const Duration(minutes: 9),
      nowUtc: DateTime.utc(2026, 3, 30, 0, 30),
    );

    expect(result.representativeCameraId, 'camera-back');
    expect(result.representativeDeviceSerial, 'SERIAL-002');
    expect(result.warnings, isEmpty);

    final liveRequest = requests.singleWhere(
      (request) => request.url.path == '/api/hccgw/video/v1/live/address/get',
    );
    expect(
      jsonDecode(liveRequest.body),
      containsPair('resourceId', 'camera-back'),
    );
    expect(
      jsonDecode(liveRequest.body),
      containsPair('deviceSerial', 'SERIAL-002'),
    );

    final playbackRequest = requests.singleWhere(
      (request) =>
          request.url.path == '/api/hccgw/video/v1/record/element/search',
    );
    expect(
      jsonDecode(playbackRequest.body),
      containsPair('resourceId', 'camera-back'),
    );

    final downloadRequest = requests.singleWhere(
      (request) =>
          request.url.path == '/api/hccgw/video/v1/video/download/url',
    );
    expect(
      jsonDecode(downloadRequest.body),
      containsPair('resourceId', 'camera-back'),
    );
    final manifestJson = jsonDecode(
      File(
        '${directory.path}/${HikConnectPayloadBundleLocator.defaultManifestFileName}',
      ).readAsStringSync(),
    ) as Map<String, Object?>;
    expect(manifestJson['area_id'], '-1');
    expect(manifestJson['include_sub_area'], true);
    expect(manifestJson['device_serial_no'], '');
    expect(manifestJson['alarm_event_types'], <Object?>[0, 1, 100657]);
    expect(
      manifestJson['camera_labels'],
      <String, Object?>{
        'camera-front': 'Front Yard',
        'camera-back': 'Back Yard',
      },
    );
    expect(manifestJson['representative_camera_id'], 'camera-back');
    expect(manifestJson['representative_device_serial_no'], 'SERIAL-002');
    expect(manifestJson['last_collection_at_utc'], '2026-03-30T00:30:00.000Z');
    expect(manifestJson['last_collection_camera_count'], 2);
    expect(manifestJson['last_collection_alarm_message_count'], 0);
    expect(
      manifestJson['last_collection_representative_camera_id'],
      'camera-back',
    );
    expect(
      manifestJson['last_collection_representative_device_serial_no'],
      'SERIAL-002',
    );
    expect(manifestJson['last_collection_warnings'], <Object?>[]);
    expect(manifestJson['page_size'], 64);
    expect(manifestJson['max_pages'], 3);
    expect(manifestJson['playback_lookback_minutes'], 45);
    expect(manifestJson['playback_window_minutes'], 9);
  });
}
