import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/hik_connect_camera_bootstrap_service.dart';
import 'package:omnix_dashboard/application/hik_connect_camera_catalog.dart';
import 'package:omnix_dashboard/application/hik_connect_env_seed_formatter.dart';

void main() {
  const singleSerialSnapshot = HikConnectCameraBootstrapSnapshot(
    cameras: <HikConnectCameraResource>[],
    cameraLabelSeeds: <String, String>{},
    deviceSerials: <String>['SERIAL-001'],
    areaNames: <String>['MS Vallee Residence'],
  );

  const multiSerialSnapshot = HikConnectCameraBootstrapSnapshot(
    cameras: <HikConnectCameraResource>[],
    cameraLabelSeeds: <String, String>{},
    deviceSerials: <String>['SERIAL-001', 'SERIAL-002'],
    areaNames: <String>['MS Vallee Residence'],
  );

  test('formats a ready-to-run pilot env block for a single serial site', () {
    const formatter = HikConnectEnvSeedFormatter();

    final block = formatter.formatEnvBlock(
      snapshot: singleSerialSnapshot,
      apiBaseUrl: 'https://api.hik-connect.example.com',
    );

    expect(block, contains("export ONYX_DVR_PROVIDER='hik_connect_openapi'"));
    expect(
      block,
      contains("export ONYX_DVR_API_BASE_URL='https://api.hik-connect.example.com'"),
    );
    expect(block, contains("export ONYX_DVR_DEVICE_SERIAL_NO='SERIAL-001'"));
  });

  test('leaves a chooser hint when multiple serials are discovered', () {
    const formatter = HikConnectEnvSeedFormatter();

    final block = formatter.formatEnvBlock(
      snapshot: multiSerialSnapshot,
      apiBaseUrl: 'https://api.hik-connect.example.com',
    );

    expect(
      block,
      contains('# ONYX_DVR_DEVICE_SERIAL_NO=choose-one-of:SERIAL-001|SERIAL-002'),
    );
  });
}
