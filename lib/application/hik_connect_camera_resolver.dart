import 'hik_connect_camera_catalog.dart';
import 'hik_connect_openapi_client.dart';
import 'hik_connect_video_session.dart';

class HikConnectCameraResolver {
  const HikConnectCameraResolver();

  HikConnectCameraResource? resolveCamera(
    Iterable<HikConnectCameraResource> cameras, {
    required String cameraId,
    String sourceName = '',
    String deviceSerialNo = '',
  }) {
    final candidates = <String>[
      cameraId,
      sourceName,
      deviceSerialNo,
    ].map(_normalize).where((entry) => entry.isNotEmpty).toList(growable: false);
    if (candidates.isEmpty) {
      return null;
    }

    for (final camera in cameras) {
      final keys = <String>{
        _normalize(camera.resourceId),
        _normalize(camera.cameraName),
        _normalize(camera.displayName),
        _normalize(camera.deviceSerialNo),
      }..removeWhere((entry) => entry.isEmpty);
      if (keys.any(candidates.contains)) {
        return camera;
      }
    }
    return null;
  }

  String displayLabelForCamera(
    Iterable<HikConnectCameraResource> cameras, {
    required String cameraId,
    String sourceName = '',
    String deviceSerialNo = '',
  }) {
    final resolved = resolveCamera(
      cameras,
      cameraId: cameraId,
      sourceName: sourceName,
      deviceSerialNo: deviceSerialNo,
    );
    if (resolved != null && resolved.displayName.trim().isNotEmpty) {
      return resolved.displayName.trim();
    }
    if (sourceName.trim().isNotEmpty) {
      return sourceName.trim();
    }
    if (cameraId.trim().isNotEmpty) {
      return cameraId.trim();
    }
    if (deviceSerialNo.trim().isNotEmpty) {
      return deviceSerialNo.trim();
    }
    return 'Unlabeled camera';
  }

  Future<HikConnectLiveAddressResponse?> resolveLiveAddress(
    HikConnectOpenApiClient api,
    Iterable<HikConnectCameraResource> cameras, {
    required String cameraId,
    String sourceName = '',
    String deviceSerialNo = '',
    int type = 1,
    int protocol = 1,
    String quality = '1',
    String code = '',
  }) async {
    final resolved = resolveCamera(
      cameras,
      cameraId: cameraId,
      sourceName: sourceName,
      deviceSerialNo: deviceSerialNo,
    );
    if (resolved == null ||
        resolved.resourceId.trim().isEmpty ||
        resolved.deviceSerialNo.trim().isEmpty) {
      return null;
    }
    return api.getLiveAddressResult(
      resourceId: resolved.resourceId,
      deviceSerial: resolved.deviceSerialNo,
      type: type,
      protocol: protocol,
      quality: quality,
      code: code,
    );
  }

  static String _normalize(String raw) {
    return raw.trim().toLowerCase();
  }
}
