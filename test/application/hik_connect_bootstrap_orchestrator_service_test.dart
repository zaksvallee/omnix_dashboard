import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:omnix_dashboard/application/hik_connect_bootstrap_orchestrator_service.dart';
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

  test('runs a full bootstrap and returns scope json, packet, and warnings', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/hccgw/platform/v1/token/get') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'errorCode': '0',
            'data': <String, Object?>{
              'appToken': 'token-orchestrator',
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
                'totalCount': 2,
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
        return http.Response(
          jsonEncode(<String, Object?>{
            'errorCode': '0',
            'data': <String, Object?>{
              'totalCount': 2,
              'pageIndex': 2,
              'pageSize': 2,
              'cameraInfo': <Object?>[],
            },
          }),
          200,
        );
      }
      fail('Unexpected request: ${request.method} ${request.url}');
    });
    final api = HikConnectOpenApiClient(config: config, client: client);
    const service = HikConnectBootstrapOrchestratorService();

    final result = await service.run(
      api,
      clientId: 'CLIENT-MS-VALLEE',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      apiBaseUrl: 'https://api.hik-connect.example.com',
    );

    expect(result.readyForPilot, isTrue);
    expect(result.readinessLabel, 'READY FOR PILOT');
    expect(result.snapshot.cameraCount, 2);
    expect(result.scopeConfigJson, contains('"provider": "hik_connect_openapi"'));
    expect(result.scopeConfigJson, contains('"camera-front": "Front Entrance Camera"'));
    expect(
      result.pilotEnvBlock,
      contains("export ONYX_DVR_PROVIDER='hik_connect_openapi'"),
    );
    expect(result.operatorPacket, contains('HIK-CONNECT BOOTSTRAP PACKET'));
    expect(result.operatorPacket, contains('Pilot Env Block'));
    expect(result.operatorPacket, contains('Device Serials'));
    expect(result.warnings, hasLength(1));
    expect(result.warnings.single, contains('Multiple device serials were discovered.'));
  });

  test('flags an empty bootstrap as incomplete', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/hccgw/platform/v1/token/get') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'errorCode': '0',
            'data': <String, Object?>{
              'appToken': 'token-empty',
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
    const service = HikConnectBootstrapOrchestratorService();

    final result = await service.run(
      api,
      clientId: 'CLIENT-MS-VALLEE',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      apiBaseUrl: 'https://api.hik-connect.example.com',
    );

    expect(result.readyForPilot, isFalse);
    expect(result.readinessLabel, 'INCOMPLETE');
    expect(
      result.warnings,
      contains(
        'No cameras were returned by Hik-Connect. Verify area scope, tenant access, and device enrollment before rollout.',
      ),
    );
  });

  test('can build a bootstrap result from preloaded pages', () {
    const service = HikConnectBootstrapOrchestratorService();

    final result = service.runFromPages(
      <HikConnectCameraCatalogPage>[
        const HikConnectCameraCatalogPage(
          totalCount: 1,
          pageIndex: 1,
          pageSize: 200,
          cameras: <HikConnectCameraResource>[
            HikConnectCameraResource(
              resourceId: 'camera-front',
              cameraName: 'Front Yard',
              displayName: 'Front Yard',
              deviceSerialNo: 'SERIAL-001',
              areaId: '',
              areaName: 'MS Vallee Residence',
            ),
          ],
        ),
      ],
      clientId: 'CLIENT-MS-VALLEE',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      apiBaseUrl: 'https://api.hik-connect.example.com',
    );

    expect(result.readyForPilot, isTrue);
    expect(result.scopeConfigJson, contains('"provider": "hik_connect_openapi"'));
    expect(result.operatorPacket, contains('Front Yard'));
  });
}
