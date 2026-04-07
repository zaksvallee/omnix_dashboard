import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/hik_connect_payload_bundle_locator.dart';

void main() {
  group('HikConnectPayloadBundleLocator', () {
    test('uses explicit env paths when provided', () {
      const locator = HikConnectPayloadBundleLocator();

      final paths = locator.resolveFromEnvironment(<String, String>{
        'ONYX_DVR_CAMERA_PAYLOAD_PATH': '/tmp/camera-pages.json',
        'ONYX_DVR_ALARM_PAYLOAD_PATH': '/tmp/alarm-messages.json',
      });

      expect(paths.cameraPayloadPath, '/tmp/camera-pages.json');
      expect(paths.alarmPayloadPath, '/tmp/alarm-messages.json');
      expect(paths.hasAny, isTrue);
    });

    test('discovers default payload files inside a preflight bundle dir', () async {
      final directory = await Directory.systemTemp.createTemp(
        'hik-connect-preflight-',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });
      await File(
        '${directory.path}/${HikConnectPayloadBundleLocator.defaultCameraFileName}',
      ).writeAsString('{}');
      await File(
        '${directory.path}/${HikConnectPayloadBundleLocator.defaultLiveFileName}',
      ).writeAsString('{}');

      const locator = HikConnectPayloadBundleLocator();
      final paths = locator.resolveFromEnvironment(<String, String>{
        'ONYX_DVR_PREFLIGHT_DIR': directory.path,
      });

      expect(
        paths.cameraPayloadPath,
        '${directory.path}/${HikConnectPayloadBundleLocator.defaultCameraFileName}',
      );
      expect(
        paths.liveAddressPayloadPath,
        '${directory.path}/${HikConnectPayloadBundleLocator.defaultLiveFileName}',
      );
      expect(paths.alarmPayloadPath, isEmpty);
      expect(paths.hasAny, isTrue);
      expect(paths.areaId, '-1');
      expect(paths.includeSubArea, isTrue);
      expect(paths.deviceSerialNo, isEmpty);
      expect(paths.alarmEventTypes, <int>[0, 1, 100657]);
      expect(paths.cameraLabels, isEmpty);
      expect(
        paths.reportOutputPath,
        '${directory.path}/${HikConnectPayloadBundleLocator.defaultReportFileName}',
      );
      expect(
        paths.reportJsonOutputPath,
        '${directory.path}/${HikConnectPayloadBundleLocator.defaultReportJsonFileName}',
      );
      expect(
        paths.scopeSeedOutputPath,
        '${directory.path}/${HikConnectPayloadBundleLocator.defaultScopeSeedFileName}',
      );
      expect(
        paths.pilotEnvOutputPath,
        '${directory.path}/${HikConnectPayloadBundleLocator.defaultPilotEnvFileName}',
      );
      expect(
        paths.bootstrapPacketOutputPath,
        '${directory.path}/${HikConnectPayloadBundleLocator.defaultBootstrapPacketFileName}',
      );
    });

    test('reads metadata and relative file names from bundle manifest', () async {
      final directory = await Directory.systemTemp.createTemp(
        'hik-connect-preflight-manifest-',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });
      await File('${directory.path}/cams.json').writeAsString('{}');
      await File('${directory.path}/alarms.json').writeAsString('{}');
      await File(
        '${directory.path}/${HikConnectPayloadBundleLocator.defaultManifestFileName}',
      ).writeAsString(
        '''
        {
          "client_id": "CLIENT-MS-VALLEE",
          "region_id": "REGION-GAUTENG",
          "site_id": "SITE-MS-VALLEE-RESIDENCE",
          "api_base_url": "https://api.hik-connect.example.com",
          "area_id": "AREA-001",
          "include_sub_area": false,
          "device_serial_no": "SERIAL-FILTER",
          "alarm_event_types": [100657, 42],
          "camera_labels": {
            "camera-front": "Front Gate",
            "camera-back": "Back Gate"
          },
          "representative_camera_id": "camera-back",
          "representative_device_serial_no": "SERIAL-002",
          "page_size": 125,
          "max_pages": 7,
          "status_max_age_hours": 6,
          "playback_lookback_minutes": 90,
          "playback_window_minutes": 12,
          "report_path": "reports/preflight.md",
          "report_json_path": "reports/preflight.json",
          "scope_seed_path": "reports/scope-seed.json",
          "pilot_env_path": "reports/pilot-env.sh",
          "bootstrap_packet_path": "reports/bootstrap-packet.md",
          "camera_payload_path": "cams.json",
          "alarm_payload_path": "alarms.json"
        }
        ''',
      );

      const locator = HikConnectPayloadBundleLocator();
      final paths = locator.resolveFromEnvironment(<String, String>{
        'ONYX_DVR_PREFLIGHT_DIR': directory.path,
      });

      expect(paths.clientId, 'CLIENT-MS-VALLEE');
      expect(paths.regionId, 'REGION-GAUTENG');
      expect(paths.siteId, 'SITE-MS-VALLEE-RESIDENCE');
      expect(paths.apiBaseUrl, 'https://api.hik-connect.example.com');
      expect(paths.areaId, 'AREA-001');
      expect(paths.includeSubArea, isFalse);
      expect(paths.deviceSerialNo, 'SERIAL-FILTER');
      expect(paths.alarmEventTypes, <int>[100657, 42]);
      expect(
        paths.cameraLabels,
        <String, String>{
          'camera-front': 'Front Gate',
          'camera-back': 'Back Gate',
        },
      );
      expect(paths.representativeCameraId, 'camera-back');
      expect(paths.representativeDeviceSerialNo, 'SERIAL-002');
      expect(paths.pageSize, 125);
      expect(paths.maxPages, 7);
      expect(paths.statusMaxAgeHours, 6);
      expect(paths.playbackLookbackMinutes, 90);
      expect(paths.playbackWindowMinutes, 12);
      expect(paths.reportOutputPath, '${directory.path}/reports/preflight.md');
      expect(
        paths.reportJsonOutputPath,
        '${directory.path}/reports/preflight.json',
      );
      expect(
        paths.scopeSeedOutputPath,
        '${directory.path}/reports/scope-seed.json',
      );
      expect(
        paths.pilotEnvOutputPath,
        '${directory.path}/reports/pilot-env.sh',
      );
      expect(
        paths.bootstrapPacketOutputPath,
        '${directory.path}/reports/bootstrap-packet.md',
      );
      expect(paths.cameraPayloadPath, '${directory.path}/cams.json');
      expect(paths.alarmPayloadPath, '${directory.path}/alarms.json');
    });
  });
}
