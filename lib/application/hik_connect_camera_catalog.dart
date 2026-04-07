class HikConnectCameraResource {
  final String resourceId;
  final String cameraName;
  final String displayName;
  final String deviceSerialNo;
  final String areaId;
  final String areaName;

  const HikConnectCameraResource({
    required this.resourceId,
    required this.cameraName,
    required this.displayName,
    required this.deviceSerialNo,
    required this.areaId,
    required this.areaName,
  });

  factory HikConnectCameraResource.fromJson(
    Map<String, Object?> raw, {
    Map<String, String> cameraLabels = const <String, String>{},
  }) {
    String readString(List<String> keys) {
      for (final key in keys) {
        final value = (raw[key] ?? '').toString().trim();
        if (value.isNotEmpty) {
          return value;
        }
      }
      return '';
    }

    final resourceId = readString(const [
      'resourceId',
      'resourceIndexCode',
      'cameraIndexCode',
      'indexCode',
      'id',
    ]);
    final cameraName = readString(const [
      'cameraName',
      'name',
      'resourceName',
      'channelName',
    ]);
    final deviceSerialNo = readString(const [
      'deviceSerialNo',
      'deviceSerial',
      'devSerialNo',
    ]);
    final areaId = readString(const ['areaID', 'areaId']);
    final areaName = readString(const ['areaName']);
    final displayName = _resolveDisplayName(
      cameraLabels: cameraLabels,
      resourceId: resourceId,
      cameraName: cameraName,
      deviceSerialNo: deviceSerialNo,
    );

    return HikConnectCameraResource(
      resourceId: resourceId,
      cameraName: cameraName,
      displayName: displayName,
      deviceSerialNo: deviceSerialNo,
      areaId: areaId,
      areaName: areaName,
    );
  }

  static String _resolveDisplayName({
    required Map<String, String> cameraLabels,
    required String resourceId,
    required String cameraName,
    required String deviceSerialNo,
  }) {
    for (final candidate in <String>[resourceId, cameraName, deviceSerialNo]) {
      final normalized = candidate.trim().toLowerCase();
      if (normalized.isEmpty) {
        continue;
      }
      final override = cameraLabels[normalized];
      if (override != null && override.trim().isNotEmpty) {
        return override.trim();
      }
    }
    if (cameraName.trim().isNotEmpty) {
      return cameraName.trim();
    }
    if (resourceId.trim().isNotEmpty) {
      return resourceId.trim();
    }
    if (deviceSerialNo.trim().isNotEmpty) {
      return deviceSerialNo.trim();
    }
    return 'Unlabeled camera';
  }
}

class HikConnectCameraCatalogPage {
  final int totalCount;
  final int pageIndex;
  final int pageSize;
  final List<HikConnectCameraResource> cameras;

  const HikConnectCameraCatalogPage({
    required this.totalCount,
    required this.pageIndex,
    required this.pageSize,
    required this.cameras,
  });

  factory HikConnectCameraCatalogPage.fromApiResponse(
    Map<String, Object?> response, {
    Map<String, String> cameraLabels = const <String, String>{},
  }) {
    final data = _asObjectMap(response['data']);
    final cameraInfo = data['cameraInfo'];
    final rawCameras = cameraInfo is List ? cameraInfo : const <Object?>[];

    return HikConnectCameraCatalogPage(
      totalCount: _asInt(data['totalCount']),
      pageIndex: _asInt(data['pageIndex']),
      pageSize: _asInt(data['pageSize']),
      cameras: rawCameras
          .whereType<Map>()
          .map(
            (entry) => HikConnectCameraResource.fromJson(
              entry.map(
                (key, value) => MapEntry(key.toString(), value as Object?),
              ),
              cameraLabels: cameraLabels,
            ),
          )
          .toList(growable: false),
    );
  }

  static Map<String, Object?> _asObjectMap(Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (key, dynamicValue) => MapEntry(key.toString(), dynamicValue),
      );
    }
    return const <String, Object?>{};
  }

  static int _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse((value ?? '').toString().trim()) ?? 0;
  }
}
