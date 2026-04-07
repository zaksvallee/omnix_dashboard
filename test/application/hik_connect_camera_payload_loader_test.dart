import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/hik_connect_camera_payload_loader.dart';

void main() {
  group('HikConnectCameraPayloadLoader', () {
    test('loads a single camera page response', () {
      const loader = HikConnectCameraPayloadLoader();

      final pages = loader.loadPagesFromJson(
        '''
        {
          "errorCode": "0",
          "data": {
            "totalCount": 1,
            "pageIndex": 1,
            "pageSize": 200,
            "cameraInfo": [
              {
                "resourceId": "camera-front",
                "cameraName": "Front Yard",
                "deviceSerialNo": "SERIAL-001",
                "areaName": "MS Vallee Residence"
              }
            ]
          }
        }
        ''',
      );

      expect(pages, hasLength(1));
      expect(pages.single.cameras.single.resourceId, 'camera-front');
    });

    test('loads wrapped pages payloads', () {
      const loader = HikConnectCameraPayloadLoader();

      final pages = loader.loadPagesFromJson(
        '''
        {
          "pages": [
            {
              "errorCode": "0",
              "data": {
                "totalCount": 2,
                "pageIndex": 1,
                "pageSize": 1,
                "cameraInfo": [
                  {
                    "resourceId": "camera-front",
                    "cameraName": "Front Yard"
                  }
                ]
              }
            },
            {
              "errorCode": "0",
              "data": {
                "totalCount": 2,
                "pageIndex": 2,
                "pageSize": 1,
                "cameraInfo": [
                  {
                    "resourceId": "camera-back",
                    "cameraName": "Back Yard"
                  }
                ]
              }
            }
          ]
        }
        ''',
      );

      expect(pages, hasLength(2));
      expect(pages.first.cameras.single.resourceId, 'camera-front');
      expect(pages.last.cameras.single.resourceId, 'camera-back');
    });
  });
}
