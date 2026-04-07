import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:omnix_dashboard/application/hik_connect_camera_catalog.dart';
import 'package:omnix_dashboard/application/hik_connect_camera_resolver.dart';
import 'package:omnix_dashboard/application/hik_connect_openapi_client.dart';
import 'package:omnix_dashboard/application/hik_connect_openapi_config.dart';

void main() {
  const cameras = <HikConnectCameraResource>[
    HikConnectCameraResource(
      resourceId: 'camera-front',
      cameraName: 'Front Entrance Camera',
      displayName: 'Front Yard',
      deviceSerialNo: 'SERIAL-001',
      areaId: '-1',
      areaName: 'MS Vallee Residence',
    ),
    HikConnectCameraResource(
      resourceId: 'camera-back',
      cameraName: 'Rear Garden Camera',
      displayName: 'Back Yard',
      deviceSerialNo: 'SERIAL-002',
      areaId: '-1',
      areaName: 'MS Vallee Residence',
    ),
  ];

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

  test('resolves cameras by resource id, source name, or device serial', () {
    const resolver = HikConnectCameraResolver();

    expect(
      resolver.resolveCamera(cameras, cameraId: 'camera-front')?.displayName,
      'Front Yard',
    );
    expect(
      resolver.resolveCamera(
        cameras,
        cameraId: 'unknown',
        sourceName: 'Rear Garden Camera',
      )?.displayName,
      'Back Yard',
    );
    expect(
      resolver.resolveCamera(
        cameras,
        cameraId: 'unknown',
        deviceSerialNo: 'SERIAL-001',
      )?.displayName,
      'Front Yard',
    );
  });

  test('falls back to source name or camera id when no catalog match exists', () {
    const resolver = HikConnectCameraResolver();

    expect(
      resolver.displayLabelForCamera(
        cameras,
        cameraId: 'camera-missing',
        sourceName: 'Driveway Camera',
      ),
      'Driveway Camera',
    );
    expect(
      resolver.displayLabelForCamera(
        cameras,
        cameraId: 'camera-missing',
      ),
      'camera-missing',
    );
  });

  test('resolves live address through the matched camera resource', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/hccgw/platform/v1/token/get') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'errorCode': '0',
            'data': <String, Object?>{
              'appToken': 'token-resolver',
              'expireTime':
                  '${DateTime.now().toUtc().add(const Duration(days: 6)).millisecondsSinceEpoch}',
              'streamAreaDomain': 'https://stream.example.com',
            },
          }),
          200,
        );
      }
      if (request.url.path == '/api/hccgw/video/v1/live/address/get') {
        expect(
          jsonDecode(request.body),
          <String, Object?>{
            'resourceId': 'camera-front',
            'deviceSerial': 'SERIAL-001',
            'type': '1',
            'protocol': 1,
            'quality': '1',
          },
        );
        return http.Response(
          jsonEncode(<String, Object?>{
            'errorCode': '0',
            'data': <String, Object?>{
              'url': 'wss://stream.example.com/live/front',
            },
          }),
          200,
        );
      }
      fail('Unexpected request: ${request.method} ${request.url}');
    });
    final api = HikConnectOpenApiClient(config: config, client: client);
    const resolver = HikConnectCameraResolver();

    final result = await resolver.resolveLiveAddress(
      api,
      cameras,
      cameraId: 'camera-front',
    );

    expect(result, isNotNull);
    expect(result!.primaryUrl, 'wss://stream.example.com/live/front');
  });
}
