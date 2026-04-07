import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/hik_connect_bootstrap_packet_service.dart';
import 'package:omnix_dashboard/application/hik_connect_camera_bootstrap_service.dart';
import 'package:omnix_dashboard/application/hik_connect_camera_catalog.dart';

void main() {
  const snapshot = HikConnectCameraBootstrapSnapshot(
    cameras: <HikConnectCameraResource>[
      HikConnectCameraResource(
        resourceId: 'camera-back',
        cameraName: 'Rear Garden Camera',
        displayName: 'Back Yard',
        deviceSerialNo: 'SERIAL-001',
        areaId: '-1',
        areaName: 'MS Vallee Residence',
      ),
      HikConnectCameraResource(
        resourceId: 'camera-front',
        cameraName: 'Front Entrance Camera',
        displayName: 'Front Yard',
        deviceSerialNo: 'SERIAL-001',
        areaId: '-1',
        areaName: 'MS Vallee Residence',
      ),
    ],
    cameraLabelSeeds: <String, String>{
      'camera-back': 'Back Yard',
      'camera-front': 'Front Yard',
    },
    deviceSerials: <String>['SERIAL-001'],
    areaNames: <String>['MS Vallee Residence'],
  );

  test('builds an operator-friendly bootstrap packet with scope json', () {
    const service = HikConnectBootstrapPacketService();

    final packet = service.buildBootstrapPacket(
      snapshot: snapshot,
      clientId: 'CLIENT-MS-VALLEE',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      apiBaseUrl: 'https://api.hik-connect.example.com',
    );

    expect(packet, contains('HIK-CONNECT BOOTSTRAP PACKET'));
    expect(packet, contains('CLIENT-MS-VALLEE / SITE-MS-VALLEE-RESIDENCE'));
    expect(packet, contains('Areas'));
    expect(packet, contains('MS Vallee Residence'));
    expect(packet, contains('Device Serials'));
    expect(packet, contains('SERIAL-001'));
    expect(packet, contains('Discovered Cameras'));
    expect(packet, contains('- Back Yard [camera-back]'));
    expect(packet, contains('- Front Yard [camera-front]'));
    expect(packet, contains('Recommended Next Step'));
    expect(packet, contains('```json'));
    expect(packet, contains('"provider": "hik_connect_openapi"'));
    expect(packet, contains('"camera-back": "Back Yard"'));
    expect(packet, contains('"camera-front": "Front Yard"'));
    expect(packet, contains('Pilot Env Block'));
    expect(packet, contains('```sh'));
    expect(packet, contains("export ONYX_DVR_PROVIDER='hik_connect_openapi'"));
    expect(packet, contains("export ONYX_DVR_DEVICE_SERIAL_NO='SERIAL-001'"));
  });
}
