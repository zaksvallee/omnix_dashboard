import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/hik_connect_camera_catalog.dart';

void main() {
  test('parses Hik-Connect camera catalog pages and applies configured labels', () {
    final page = HikConnectCameraCatalogPage.fromApiResponse(
      <String, Object?>{
        'errorCode': '0',
        'data': <String, Object?>{
          'totalCount': 2,
          'pageIndex': 1,
          'pageSize': 200,
          'cameraInfo': <Object?>[
            <String, Object?>{
              'resourceId': 'camera-front',
              'cameraName': 'Front Entrance Camera',
              'deviceSerialNo': 'SERIAL-001',
              'areaID': '-1',
              'areaName': 'Main Residence',
            },
            <String, Object?>{
              'resourceId': 'camera-back',
              'cameraName': 'Rear Garden Camera',
              'deviceSerialNo': 'SERIAL-001',
              'areaID': '-1',
              'areaName': 'Main Residence',
            },
          ],
        },
      },
      cameraLabels: const <String, String>{
        'camera-front': 'Front Yard',
      },
    );

    expect(page.totalCount, 2);
    expect(page.pageIndex, 1);
    expect(page.pageSize, 200);
    expect(page.cameras, hasLength(2));
    expect(page.cameras.first.resourceId, 'camera-front');
    expect(page.cameras.first.cameraName, 'Front Entrance Camera');
    expect(page.cameras.first.displayName, 'Front Yard');
    expect(page.cameras.first.deviceSerialNo, 'SERIAL-001');
    expect(page.cameras.first.areaName, 'Main Residence');
    expect(page.cameras.last.displayName, 'Rear Garden Camera');
  });

  test('falls back to resource identifiers when names are absent', () {
    final page = HikConnectCameraCatalogPage.fromApiResponse(
      <String, Object?>{
        'errorCode': '0',
        'data': <String, Object?>{
          'totalCount': 1,
          'pageIndex': 1,
          'pageSize': 50,
          'cameraInfo': <Object?>[
            <String, Object?>{
              'resourceIndexCode': 'index-camera-7',
              'deviceSerial': 'SERIAL-777',
            },
          ],
        },
      },
    );

    expect(page.cameras, hasLength(1));
    expect(page.cameras.single.resourceId, 'index-camera-7');
    expect(page.cameras.single.displayName, 'index-camera-7');
    expect(page.cameras.single.deviceSerialNo, 'SERIAL-777');
  });
}
