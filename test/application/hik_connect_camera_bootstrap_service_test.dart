import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:omnix_dashboard/application/hik_connect_camera_bootstrap_service.dart';
import 'package:omnix_dashboard/application/hik_connect_camera_catalog.dart';
import 'package:omnix_dashboard/application/hik_connect_openapi_client.dart';
import 'package:omnix_dashboard/application/hik_connect_openapi_config.dart';

void main() {
  final config = HikConnectOpenApiConfig(
    clientId: 'CLIENT-MS-VALLEE',
    regionId: 'REGION-GAUTENG',
    siteId: 'SITE-MS-VALLEE-RESIDENCE',
    baseUri: Uri.parse('https://api.hik-connect.example.com'),
    appKey: 'app-key',
    appSecret: 'app-secret',
    areaId: '-1',
    includeSubArea: true,
    deviceSerialNo: '',
    alarmEventTypes: const <int>[0, 1],
    cameraLabels: const <String, String>{},
  );

  test('fetches paged camera inventory and builds label seeds', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/hccgw/platform/v1/token/get') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'errorCode': '0',
            'data': <String, Object?>{
              'appToken': 'token-bootstrap',
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
                    'areaName': 'MS Vallee Residence',
                  },
                  <String, Object?>{
                    'resourceId': 'camera-back',
                    'cameraName': 'Rear Garden Camera',
                    'deviceSerialNo': 'SERIAL-001',
                    'areaName': 'MS Vallee Residence',
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
                  'areaName': 'MS Vallee Residence',
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
    const service = HikConnectCameraBootstrapService();

    final snapshot = await service.fetchSnapshot(api, pageSize: 2);

    expect(snapshot.cameraCount, 3);
    expect(snapshot.cameraLabelSeeds['camera-front'], 'Front Entrance Camera');
    expect(snapshot.cameraLabelSeeds['camera-drive'], 'Driveway Camera');
    expect(snapshot.deviceSerials, containsAll(<String>['SERIAL-001', 'SERIAL-002']));
    expect(snapshot.areaNames, <String>['MS Vallee Residence']);
    expect(snapshot.summaryLabel, contains('3 cameras'));
    expect(snapshot.summaryLabel, contains('2 device serials'));
    expect(
      requests.where(
        (request) => request.url.path == '/api/hccgw/resource/v1/areas/cameras/get',
      ),
      hasLength(2),
    );
  });

  test('builds a snapshot from preloaded pages', () {
    const service = HikConnectCameraBootstrapService();

    final snapshot = service.buildSnapshotFromPages(
      <HikConnectCameraCatalogPage>[
        const HikConnectCameraCatalogPage(
          totalCount: 2,
          pageIndex: 1,
          pageSize: 1,
          cameras: <HikConnectCameraResource>[
            HikConnectCameraResource(
              resourceId: 'camera-front',
              cameraName: 'Front Entrance Camera',
              displayName: 'Front Entrance Camera',
              deviceSerialNo: 'SERIAL-001',
              areaId: '',
              areaName: 'MS Vallee Residence',
            ),
          ],
        ),
        const HikConnectCameraCatalogPage(
          totalCount: 2,
          pageIndex: 2,
          pageSize: 1,
          cameras: <HikConnectCameraResource>[
            HikConnectCameraResource(
              resourceId: 'camera-back',
              cameraName: 'Rear Garden Camera',
              displayName: 'Rear Garden Camera',
              deviceSerialNo: 'SERIAL-001',
              areaId: '',
              areaName: 'MS Vallee Residence',
            ),
          ],
        ),
      ],
    );

    expect(snapshot.cameraCount, 2);
    expect(snapshot.cameraLabelSeeds['camera-front'], 'Front Entrance Camera');
    expect(snapshot.deviceSerials, <String>['SERIAL-001']);
    expect(snapshot.areaNames, <String>['MS Vallee Residence']);
  });
}
