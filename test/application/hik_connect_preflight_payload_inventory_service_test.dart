import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/hik_connect_preflight_payload_inventory_service.dart';

void main() {
  test('builds payload inventory entries with found, missing, and unset states', () {
    const service = HikConnectPreflightPayloadInventoryService();
    final directory = Directory.systemTemp.createTempSync(
      'hik-connect-payload-inventory-test-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final cameraFile = File('${directory.path}/camera-pages.json')
      ..writeAsStringSync('{"pages":[]}');

    final inventory = service.buildInventory(
      cameraPayloadPath: cameraFile.path,
      alarmPayloadPath: '',
      liveAddressPayloadPath: '${directory.path}/live-address.json',
      playbackPayloadPath: '',
      videoDownloadPayloadPath: '${directory.path}/video-download.json',
    );

    expect(inventory, hasLength(5));
    expect(
      inventory.first,
      containsPair('key', 'camera'),
    );
    expect(
      inventory.first,
      containsPair('configured', true),
    );
    expect(
      inventory.first,
      containsPair('exists', true),
    );
    expect(
      inventory.first,
      containsPair('status', 'found'),
    );
    expect(
      inventory.first,
      containsPair('path', cameraFile.path),
    );
    expect(
      inventory.first,
      containsPair('size_bytes', greaterThan(0)),
    );
    expect(
      inventory[1],
      containsPair('status', 'unset'),
    );
    expect(
      inventory[2],
      containsPair('status', 'configured_missing'),
    );
  });
}
