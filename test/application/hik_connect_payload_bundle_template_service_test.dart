import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/hik_connect_payload_bundle_locator.dart';
import 'package:omnix_dashboard/application/hik_connect_payload_bundle_template_service.dart';

void main() {
  test('creates a self-describing payload bundle scaffold', () async {
    final directory = await Directory.systemTemp.createTemp(
      'hik-connect-template-',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final targetPath = '${directory.path}/bundle';
    const service = HikConnectPayloadBundleTemplateService();

    final result = await service.createBundle(
      directoryPath: targetPath,
      clientId: 'CLIENT-MS-VALLEE',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
    );

    expect(result.directoryPath, targetPath);
    expect(result.createdDirectory, isTrue);
    expect(
      File(result.manifestPath).existsSync(),
      isTrue,
    );
    expect(
      File(
        '$targetPath/${HikConnectPayloadBundleLocator.defaultCameraFileName}',
      ).existsSync(),
      isTrue,
    );
    expect(
      File('$targetPath/README.md').readAsStringSync(),
      contains('ONYX_DVR_PREFLIGHT_DIR'),
    );
    expect(
      File(result.manifestPath).readAsStringSync(),
      contains('CLIENT-MS-VALLEE'),
    );
    expect(
      File(result.manifestPath).readAsStringSync(),
      contains(HikConnectPayloadBundleLocator.defaultReportFileName),
    );
    expect(
      File(result.manifestPath).readAsStringSync(),
      contains(HikConnectPayloadBundleLocator.defaultReportJsonFileName),
    );
    expect(
      File(result.manifestPath).readAsStringSync(),
      contains(HikConnectPayloadBundleLocator.defaultScopeSeedFileName),
    );
    expect(
      File(result.manifestPath).readAsStringSync(),
      contains(HikConnectPayloadBundleLocator.defaultPilotEnvFileName),
    );
    expect(
      File(result.manifestPath).readAsStringSync(),
      contains(HikConnectPayloadBundleLocator.defaultBootstrapPacketFileName),
    );
    expect(
      File(result.manifestPath).readAsStringSync(),
      contains('representative_camera_id'),
    );
    expect(
      File(result.manifestPath).readAsStringSync(),
      contains('representative_device_serial_no'),
    );
    expect(
      File(result.manifestPath).readAsStringSync(),
      contains('"area_id": "-1"'),
    );
    expect(
      File(result.manifestPath).readAsStringSync(),
      contains('"include_sub_area": true'),
    );
    expect(
      File(result.manifestPath).readAsStringSync(),
      contains('"device_serial_no": ""'),
    );
    expect(
      File(result.manifestPath).readAsStringSync(),
      contains('"alarm_event_types": ['),
    );
    expect(
      File(result.manifestPath).readAsStringSync(),
      contains('"camera_labels": {}'),
    );
    expect(
      File(result.manifestPath).readAsStringSync(),
      contains('"page_size": 200'),
    );
    expect(
      File(result.manifestPath).readAsStringSync(),
      contains('"max_pages": 20'),
    );
    expect(
      File(result.manifestPath).readAsStringSync(),
      contains('"status_max_age_hours": 0'),
    );
    expect(
      File(result.manifestPath).readAsStringSync(),
      contains('"playback_lookback_minutes": 60'),
    );
    expect(
      File(result.manifestPath).readAsStringSync(),
      contains('"playback_window_minutes": 5'),
    );
    expect(
      File('$targetPath/README.md').readAsStringSync(),
      contains(HikConnectPayloadBundleLocator.defaultScopeSeedFileName),
    );
    expect(
      File('$targetPath/README.md').readAsStringSync(),
      contains(HikConnectPayloadBundleLocator.defaultPilotEnvFileName),
    );
    expect(
      File('$targetPath/README.md').readAsStringSync(),
      contains(HikConnectPayloadBundleLocator.defaultBootstrapPacketFileName),
    );
  });
}
