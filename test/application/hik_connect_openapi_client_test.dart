import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:omnix_dashboard/application/hik_connect_openapi_client.dart';
import 'package:omnix_dashboard/application/hik_connect_openapi_config.dart';

void main() {
  final config = HikConnectOpenApiConfig(
    clientId: 'CLIENT-MS-VALLEE',
    regionId: 'REGION-GAUTENG',
    siteId: 'SITE-MS-VALLEE-RESIDENCE',
    baseUri: Uri(scheme: 'https', host: 'api.hik-connect.example.com'),
    appKey: 'app-key',
    appSecret: 'app-secret',
    areaId: '-1',
    includeSubArea: true,
    deviceSerialNo: 'SERIAL-001',
    alarmEventTypes: <int>[0, 1],
    cameraLabels: <String, String>{},
  );

  test('caches Hik-Connect token across camera lookups', () async {
    var tokenCalls = 0;
    var cameraCalls = 0;
    final client = MockClient((request) async {
      if (request.url.path == '/api/hccgw/platform/v1/token/get') {
        tokenCalls += 1;
        expect(request.method, 'POST');
        expect(request.headers['Content-Type'], 'application/json');
        expect(
          jsonDecode(request.body),
          <String, Object?>{
            'appKey': 'app-key',
            'secretKey': 'app-secret',
          },
        );
        return http.Response(
          jsonEncode(<String, Object?>{
            'errorCode': '0',
            'data': <String, Object?>{
              'appToken': 'token-123',
              'expireTime':
                  '${DateTime.now().toUtc().add(const Duration(days: 6)).millisecondsSinceEpoch}',
              'streamAreaDomain': 'https://stream.example.com',
            },
          }),
          200,
        );
      }
      if (request.url.path == '/api/hccgw/resource/v1/areas/cameras/get') {
        cameraCalls += 1;
        expect(request.headers['Token'], 'token-123');
        expect(
          jsonDecode(request.body),
          <String, Object?>{
            'pageIndex': 1,
            'pageSize': 200,
            'filter': <String, Object?>{
              'areaID': '-1',
              'includeSubArea': '1',
              'deviceID': '',
              'deviceSerialNo': 'SERIAL-001',
            },
          },
        );
        return http.Response(
          jsonEncode(<String, Object?>{
            'errorCode': '0',
            'data': <String, Object?>{
              'totalCount': 0,
              'pageIndex': 1,
              'pageSize': 200,
              'cameraInfo': <Object?>[],
            },
          }),
          200,
        );
      }
      fail('Unexpected request: ${request.method} ${request.url}');
    });
    final api = HikConnectOpenApiClient(config: config, client: client);

    await api.getCameras();
    await api.getCameras();

    expect(tokenCalls, 1);
    expect(cameraCalls, 2);
  });

  test('builds a typed camera catalog from the camera listing response', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/hccgw/platform/v1/token/get') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'errorCode': '0',
            'data': <String, Object?>{
              'appToken': 'token-catalog',
              'expireTime':
                  '${DateTime.now().toUtc().add(const Duration(days: 6)).millisecondsSinceEpoch}',
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
                  'cameraName': 'Front Entrance Camera',
                  'deviceSerialNo': 'SERIAL-001',
                  'areaName': 'Vallee Residence',
                },
              ],
            },
          }),
          200,
        );
      }
      fail('Unexpected request: ${request.method} ${request.url}');
    });
    final api = HikConnectOpenApiClient(
      config: HikConnectOpenApiConfig(
        clientId: config.clientId,
        regionId: config.regionId,
        siteId: config.siteId,
        baseUri: config.baseUri,
        appKey: config.appKey,
        appSecret: config.appSecret,
        areaId: config.areaId,
        includeSubArea: config.includeSubArea,
        deviceSerialNo: config.deviceSerialNo,
        alarmEventTypes: config.alarmEventTypes,
        cameraLabels: const <String, String>{'camera-front': 'Front Yard'},
      ),
      client: client,
    );

    final page = await api.getCameraCatalog();

    expect(page.totalCount, 1);
    expect(page.cameras.single.resourceId, 'camera-front');
    expect(page.cameras.single.displayName, 'Front Yard');
    expect(page.cameras.single.areaName, 'Vallee Residence');
  });

  test('loads paged camera catalog until the tenant inventory is exhausted', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/hccgw/platform/v1/token/get') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'errorCode': '0',
            'data': <String, Object?>{
              'appToken': 'token-paged-catalog',
              'expireTime':
                  '${DateTime.now().toUtc().add(const Duration(days: 6)).millisecondsSinceEpoch}',
              'streamAreaDomain': 'https://stream.example.com',
            },
          }),
          200,
        );
      }
      if (request.url.path == '/api/hccgw/resource/v1/areas/cameras/get') {
        final body = jsonDecode(request.body) as Map<String, Object?>;
        final pageIndex = body['pageIndex'];
        if (pageIndex == 1) {
          return http.Response(
            jsonEncode(<String, Object?>{
              'errorCode': '0',
              'data': <String, Object?>{
                'totalCount': 3,
                'pageIndex': 1,
                'pageSize': 2,
                'cameraInfo': <Object?>[
                  <String, Object?>{
                    'resourceId': 'camera-front',
                    'cameraName': 'Front Entrance Camera',
                    'deviceSerialNo': 'SERIAL-001',
                  },
                  <String, Object?>{
                    'resourceId': 'camera-back',
                    'cameraName': 'Rear Garden Camera',
                    'deviceSerialNo': 'SERIAL-001',
                  },
                ],
              },
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode(<String, Object?>{
            'errorCode': '0',
            'data': <String, Object?>{
              'totalCount': 3,
              'pageIndex': 2,
              'pageSize': 2,
              'cameraInfo': <Object?>[
                <String, Object?>{
                  'resourceId': 'camera-drive',
                  'cameraName': 'Driveway Camera',
                  'deviceSerialNo': 'SERIAL-002',
                },
              ],
            },
          }),
          200,
        );
      }
      fail('Unexpected request: ${request.method} ${request.url}');
    });
    final api = HikConnectOpenApiClient(config: config, client: client);

    final pages = await api.getAllCameraCatalogPages(pageSize: 2);

    expect(pages, hasLength(2));
    expect(
      pages.expand((entry) => entry.cameras).map((entry) => entry.resourceId),
      containsAll(<String>['camera-front', 'camera-back', 'camera-drive']),
    );
    expect(
      requests.where(
        (request) => request.url.path == '/api/hccgw/resource/v1/areas/cameras/get',
      ),
      hasLength(2),
    );
  });

  test('subscribes to alarm queue with configured event types', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/hccgw/platform/v1/token/get') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'errorCode': '0',
            'data': <String, Object?>{
              'appToken': 'token-abc',
              'expireTime':
                  '${DateTime.now().toUtc().add(const Duration(days: 6)).millisecondsSinceEpoch}',
              'streamAreaDomain': 'https://stream.example.com',
            },
          }),
          200,
        );
      }
      if (request.url.path == '/api/hccgw/alarm/v1/mq/subscribe') {
        return http.Response(
          jsonEncode(<String, Object?>{'errorCode': '0'}),
          200,
        );
      }
      fail('Unexpected request: ${request.method} ${request.url}');
    });
    final api = HikConnectOpenApiClient(config: config, client: client);

    await api.subscribeAlarmQueue();

    final subscribeRequest = requests.singleWhere(
      (request) => request.url.path == '/api/hccgw/alarm/v1/mq/subscribe',
    );
    expect(subscribeRequest.headers['Token'], 'token-abc');
    expect(
      jsonDecode(subscribeRequest.body),
      <String, Object?>{
        'subscribeType': 1,
        'subscribeMode': 1,
        'eventType': <int>[0, 1],
      },
    );
  });

  test('requests live address with the expected video payload', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/hccgw/platform/v1/token/get') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'errorCode': '0',
            'data': <String, Object?>{
              'appToken': 'token-live',
              'expireTime':
                  '${DateTime.now().toUtc().add(const Duration(days: 6)).millisecondsSinceEpoch}',
              'streamAreaDomain': 'https://stream.example.com',
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
      fail('Unexpected request: ${request.method} ${request.url}');
    });
    final api = HikConnectOpenApiClient(config: config, client: client);

    await api.getLiveAddress(
      resourceId: 'camera-front',
      deviceSerial: 'SERIAL-001',
      type: 1,
      protocol: 2,
      quality: '2',
      code: 'stream-code',
    );

    final liveAddressRequest = requests.singleWhere(
      (request) => request.url.path == '/api/hccgw/video/v1/live/address/get',
    );
    expect(liveAddressRequest.headers['Token'], 'token-live');
    expect(
      jsonDecode(liveAddressRequest.body),
      <String, Object?>{
        'resourceId': 'camera-front',
        'deviceSerial': 'SERIAL-001',
        'type': '1',
        'protocol': 2,
        'quality': '2',
        'code': 'stream-code',
      },
    );
  });

  test('builds a typed live address result from the response payload', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/hccgw/platform/v1/token/get') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'errorCode': '0',
            'data': <String, Object?>{
              'appToken': 'token-live-typed',
              'expireTime':
                  '${DateTime.now().toUtc().add(const Duration(days: 6)).millisecondsSinceEpoch}',
              'streamAreaDomain': 'https://stream.example.com',
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
              'hlsUrl': 'https://stream.example.com/live/index.m3u8',
            },
          }),
          200,
        );
      }
      fail('Unexpected request: ${request.method} ${request.url}');
    });
    final api = HikConnectOpenApiClient(config: config, client: client);

    final result = await api.getLiveAddressResult(
      resourceId: 'camera-front',
      deviceSerial: 'SERIAL-001',
    );

    expect(result.primaryUrl, 'wss://stream.example.com/live/token');
    expect(
      result.urlsByKey['hlsUrl'],
      'https://stream.example.com/live/index.m3u8',
    );
  });

  test('posts playback search and download requests through the shared token path', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/hccgw/platform/v1/token/get') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'errorCode': '0',
            'data': <String, Object?>{
              'appToken': 'token-playback',
              'expireTime':
                  '${DateTime.now().toUtc().add(const Duration(days: 6)).millisecondsSinceEpoch}',
              'streamAreaDomain': 'https://stream.example.com',
            },
          }),
          200,
        );
      }
      if (request.url.path == '/api/hccgw/video/v1/record/element/search') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'errorCode': '0',
            'data': <String, Object?>{'recordList': <Object?>[]},
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
    final api = HikConnectOpenApiClient(config: config, client: client);
    const searchBody = <String, Object?>{
      'resourceId': 'camera-front',
      'beginTime': '2026-03-30T00:00:00Z',
      'endTime': '2026-03-30T00:05:00Z',
    };
    const downloadBody = <String, Object?>{
      'recordId': 'record-001',
      'resourceId': 'camera-front',
    };

    await api.searchRecordElements(searchBody);
    await api.getVideoDownloadUrl(downloadBody);

    final searchRequest = requests.singleWhere(
      (request) =>
          request.url.path == '/api/hccgw/video/v1/record/element/search',
    );
    final downloadRequest = requests.singleWhere(
      (request) =>
          request.url.path == '/api/hccgw/video/v1/video/download/url',
    );
    expect(searchRequest.headers['Token'], 'token-playback');
    expect(downloadRequest.headers['Token'], 'token-playback');
    expect(jsonDecode(searchRequest.body), searchBody);
    expect(jsonDecode(downloadRequest.body), downloadBody);
  });

  test('builds typed playback search and download results', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/hccgw/platform/v1/token/get') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'errorCode': '0',
            'data': <String, Object?>{
              'appToken': 'token-video-typed',
              'expireTime':
                  '${DateTime.now().toUtc().add(const Duration(days: 6)).millisecondsSinceEpoch}',
              'streamAreaDomain': 'https://stream.example.com',
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
              'pageSize': 200,
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
    final api = HikConnectOpenApiClient(config: config, client: client);

    final searchResult = await api.searchRecordCatalog(<String, Object?>{
      'resourceId': 'camera-front',
      'beginTime': '2026-03-30T00:00:00Z',
      'endTime': '2026-03-30T00:05:00Z',
    });
    final downloadResult = await api.getVideoDownloadResult(<String, Object?>{
      'recordId': 'record-001',
      'resourceId': 'camera-front',
    });

    expect(searchResult.totalCount, 1);
    expect(searchResult.records.single.recordId, 'record-001');
    expect(
      downloadResult.downloadUrl,
      'https://stream.example.com/download/video.mp4',
    );
  });
}
