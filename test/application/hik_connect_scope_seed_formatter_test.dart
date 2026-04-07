import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/hik_connect_camera_bootstrap_service.dart';
import 'package:omnix_dashboard/application/hik_connect_camera_catalog.dart';
import 'package:omnix_dashboard/application/hik_connect_scope_seed_formatter.dart';

void main() {
  const snapshot = HikConnectCameraBootstrapSnapshot(
    cameras: <HikConnectCameraResource>[
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
        deviceSerialNo: 'SERIAL-001',
        areaId: '-1',
        areaName: 'MS Vallee Residence',
      ),
    ],
    cameraLabelSeeds: <String, String>{
      'camera-front': 'Front Yard',
      'camera-back': 'Back Yard',
    },
    deviceSerials: <String>['SERIAL-001'],
    areaNames: <String>['MS Vallee Residence'],
  );

  test('builds a ready-to-paste Hik-Connect scope config item', () {
    const formatter = HikConnectScopeSeedFormatter();

    final item = formatter.buildScopeConfigItem(
      snapshot: snapshot,
      clientId: 'CLIENT-MS-VALLEE',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      apiBaseUrl: 'https://api.hik-connect.example.com',
      appKey: 'replace-me',
      appSecret: 'replace-me',
    );

    expect(item['client_id'], 'CLIENT-MS-VALLEE');
    expect(item['region_id'], 'REGION-GAUTENG');
    expect(item['site_id'], 'SITE-MS-VALLEE-RESIDENCE');
    expect(item['provider'], 'hik_connect_openapi');
    expect(item['api_base_url'], 'https://api.hik-connect.example.com');
    expect(item['device_serial_no'], 'SERIAL-001');
    expect(item['alarm_event_types'], <int>[0, 1, 100657]);
    expect(
      item['camera_labels'],
      <String, String>{
        'camera-back': 'Back Yard',
        'camera-front': 'Front Yard',
      },
    );
  });

  test('formats the scope config as stable json', () {
    const formatter = HikConnectScopeSeedFormatter();

    final json = formatter.formatScopeConfigJson(
      snapshot: snapshot,
      clientId: 'CLIENT-MS-VALLEE',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      apiBaseUrl: 'https://api.hik-connect.example.com',
    );

    expect(json, contains('"provider": "hik_connect_openapi"'));
    expect(json, contains('"device_serial_no": "SERIAL-001"'));
    expect(json, contains('"camera-back": "Back Yard"'));
    expect(json, contains('"camera-front": "Front Yard"'));
  });
}
