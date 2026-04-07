import 'hik_connect_camera_catalog.dart';
import 'hik_connect_openapi_client.dart';

class HikConnectCameraBootstrapSnapshot {
  final List<HikConnectCameraResource> cameras;
  final Map<String, String> cameraLabelSeeds;
  final List<String> deviceSerials;
  final List<String> areaNames;

  const HikConnectCameraBootstrapSnapshot({
    required this.cameras,
    required this.cameraLabelSeeds,
    required this.deviceSerials,
    required this.areaNames,
  });

  int get cameraCount => cameras.length;

  String get preferredDeviceSerialNo =>
      deviceSerials.length == 1 ? deviceSerials.single : '';

  String get summaryLabel {
    final parts = <String>['$cameraCount camera${cameraCount == 1 ? '' : 's'}'];
    if (deviceSerials.isNotEmpty) {
      parts.add(
        '${deviceSerials.length} device serial${deviceSerials.length == 1 ? '' : 's'}',
      );
    }
    if (areaNames.isNotEmpty) {
      parts.add(areaNames.join(', '));
    }
    return parts.join(' • ');
  }
}

class HikConnectCameraBootstrapService {
  const HikConnectCameraBootstrapService();

  Future<HikConnectCameraBootstrapSnapshot> fetchSnapshot(
    HikConnectOpenApiClient api, {
    int pageSize = 200,
    int maxPages = 20,
    String? areaId,
    bool? includeSubArea,
    String deviceSerialNo = '',
  }) async {
    final pages = await api.getAllCameraCatalogPages(
      pageSize: pageSize,
      maxPages: maxPages,
      areaId: areaId,
      includeSubArea: includeSubArea,
      deviceSerialNo: deviceSerialNo,
    );
    return buildSnapshotFromPages(pages);
  }

  HikConnectCameraBootstrapSnapshot buildSnapshotFromPages(
    Iterable<HikConnectCameraCatalogPage> pages,
  ) {
    final camerasByKey = <String, HikConnectCameraResource>{};
    for (final page in pages) {
      for (final camera in page.cameras) {
        final key = camera.resourceId.trim().isNotEmpty
            ? camera.resourceId.trim().toLowerCase()
            : '${camera.deviceSerialNo}|${camera.displayName}'.toLowerCase();
        camerasByKey[key] = camera;
      }
    }
    final cameras = camerasByKey.values.toList(growable: false)
      ..sort((left, right) => left.displayName.compareTo(right.displayName));

    final cameraLabelSeeds = <String, String>{};
    final deviceSerials = <String>{};
    final areaNames = <String>{};
    for (final camera in cameras) {
      final resourceId = camera.resourceId.trim().toLowerCase();
      final displayName = camera.displayName.trim();
      if (resourceId.isNotEmpty && displayName.isNotEmpty) {
        cameraLabelSeeds[resourceId] = displayName;
      }
      final serial = camera.deviceSerialNo.trim();
      if (serial.isNotEmpty) {
        deviceSerials.add(serial);
      }
      final areaName = camera.areaName.trim();
      if (areaName.isNotEmpty) {
        areaNames.add(areaName);
      }
    }

    return HikConnectCameraBootstrapSnapshot(
      cameras: List<HikConnectCameraResource>.unmodifiable(cameras),
      cameraLabelSeeds: Map<String, String>.unmodifiable(cameraLabelSeeds),
      deviceSerials: List<String>.unmodifiable(deviceSerials.toList()..sort()),
      areaNames: List<String>.unmodifiable(areaNames.toList()..sort()),
    );
  }
}
