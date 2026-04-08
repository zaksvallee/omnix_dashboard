import 'dart:convert';
import 'dart:io';

import 'hik_connect_camera_bootstrap_service.dart';
import 'hik_connect_camera_catalog.dart';
import 'hik_connect_openapi_client.dart';
import 'hik_connect_payload_bundle_locator.dart';
import 'hik_connect_payload_bundle_template_service.dart';
import 'hik_connect_video_session.dart';

class HikConnectPayloadBundleCollectionResult {
  final String directoryPath;
  final Map<String, String> outputPaths;
  final int cameraCount;
  final int alarmMessageCount;
  final String representativeCameraId;
  final String representativeDeviceSerial;
  final List<String> warnings;

  const HikConnectPayloadBundleCollectionResult({
    required this.directoryPath,
    required this.outputPaths,
    required this.cameraCount,
    required this.alarmMessageCount,
    required this.representativeCameraId,
    required this.representativeDeviceSerial,
    required this.warnings,
  });
}

class HikConnectPayloadBundleCollectorService {
  const HikConnectPayloadBundleCollectorService();

  Future<HikConnectPayloadBundleCollectionResult> collect({
    required HikConnectOpenApiClient api,
    required String directoryPath,
    required String clientId,
    required String regionId,
    required String siteId,
    String representativeCameraId = '',
    String representativeDeviceSerial = '',
    int pageSize = 200,
    int maxPages = 20,
    Duration playbackLookback = const Duration(hours: 1),
    Duration playbackWindow = const Duration(minutes: 5),
    DateTime? nowUtc,
  }) async {
    const templateService = HikConnectPayloadBundleTemplateService();
    final bundle = await templateService.createBundle(
      directoryPath: directoryPath,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      apiBaseUrl: api.config.baseUri?.toString() ?? '',
    );

    final cameraPath =
        '${bundle.directoryPath}/${HikConnectPayloadBundleLocator.defaultCameraFileName}';
    final alarmPath =
        '${bundle.directoryPath}/${HikConnectPayloadBundleLocator.defaultAlarmFileName}';
    final livePath =
        '${bundle.directoryPath}/${HikConnectPayloadBundleLocator.defaultLiveFileName}';
    final playbackPath =
        '${bundle.directoryPath}/${HikConnectPayloadBundleLocator.defaultPlaybackFileName}';
    final downloadPath =
        '${bundle.directoryPath}/${HikConnectPayloadBundleLocator.defaultVideoDownloadFileName}';

    final rawCameraPages = <Map<String, Object?>>[];
    final typedCameraPages = <HikConnectCameraCatalogPage>[];
    for (var pageIndex = 1; pageIndex <= maxPages; pageIndex += 1) {
      final rawPage = await api.getCameras(
        pageIndex: pageIndex,
        pageSize: pageSize,
      );
      rawCameraPages.add(rawPage);
      final typedPage = HikConnectCameraCatalogPage.fromApiResponse(
        rawPage,
        cameraLabels: api.config.cameraLabels,
      );
      typedCameraPages.add(typedPage);
      final loadedCount = typedCameraPages.fold<int>(
        0,
        (sum, page) => sum + page.cameras.length,
      );
      if (typedPage.cameras.isEmpty ||
          typedPage.totalCount <= 0 ||
          loadedCount >= typedPage.totalCount ||
          typedPage.cameras.length < pageSize) {
        break;
      }
    }

    await _writeJsonFile(
      cameraPath,
      <String, Object?>{'pages': rawCameraPages},
    );

    final rawAlarmBatch = await api.pullAlarmMessages();
    await _writeJsonFile(alarmPath, rawAlarmBatch);

    final cameras = typedCameraPages
        .expand((page) => page.cameras)
        .where((camera) => camera.resourceId.trim().isNotEmpty)
        .toList(growable: false);
    final warnings = <String>[];
    final representative = _selectRepresentativeCamera(
      cameras,
      preferredCameraId: representativeCameraId,
      preferredDeviceSerial: representativeDeviceSerial,
      warnings: warnings,
    );
    final resolvedRepresentativeSerial =
        representative?.deviceSerialNo.trim() ?? '';
    final resolvedRepresentativeId = representative?.resourceId.trim() ?? '';

    Map<String, Object?> liveResponse = _emptyLivePayload();
    Map<String, Object?> playbackResponse = _emptyPlaybackPayload();
    Map<String, Object?> downloadResponse = _emptyDownloadPayload();

    if (representative == null || resolvedRepresentativeSerial.isEmpty) {
      warnings.add(
        'No representative camera with both resource id and device serial was available for live/playback collection.',
      );
    } else {
      liveResponse = await api.getLiveAddress(
        resourceId: resolvedRepresentativeId,
        deviceSerial: resolvedRepresentativeSerial,
      );

      final endTime = (nowUtc ?? DateTime.now().toUtc());
      final beginTime = endTime.subtract(playbackLookback);
      playbackResponse = await api.searchRecordElements(<String, Object?>{
        'resourceId': resolvedRepresentativeId,
        'beginTime': beginTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'pageIndex': 1,
        'pageSize': 50,
      });

      final playbackCatalog = HikConnectRecordElementSearchResult.fromApiResponse(
        playbackResponse,
      );
      final downloadableRecord = playbackCatalog.records.isNotEmpty
          ? playbackCatalog.records.first
          : null;
      if (downloadableRecord == null) {
        warnings.add(
          'Playback search returned no record windows for the representative camera.',
        );
      } else {
        final downloadBegin = downloadableRecord.beginTime.trim().isEmpty
            ? beginTime.toIso8601String()
            : downloadableRecord.beginTime;
        final downloadEnd = downloadableRecord.endTime.trim().isEmpty
            ? beginTime.add(playbackWindow).toIso8601String()
            : downloadableRecord.endTime;
        downloadResponse = await api.getVideoDownloadUrl(<String, Object?>{
          'recordId': downloadableRecord.recordId,
          'resourceId': resolvedRepresentativeId,
          'beginTime': downloadBegin,
          'endTime': downloadEnd,
        });
      }
    }

    await _writeJsonFile(livePath, liveResponse);
    await _writeJsonFile(playbackPath, playbackResponse);
    await _writeJsonFile(downloadPath, downloadResponse);
    final bootstrapSnapshot = const HikConnectCameraBootstrapService()
        .buildSnapshotFromPages(typedCameraPages);
    await _updateManifestRepresentativeSelection(
      bundle.directoryPath,
      collectionRecordedAtUtc: (nowUtc ?? DateTime.now().toUtc()).toUtc(),
      areaId: api.config.areaId,
      includeSubArea: api.config.includeSubArea,
      deviceSerialNo: api.config.deviceSerialNo,
      alarmEventTypes: api.config.alarmEventTypes,
      cameraLabelSeeds: bootstrapSnapshot.cameraLabelSeeds,
      cameraCount: cameras.length,
      alarmMessageCount: _readAlarmMessages(rawAlarmBatch).length,
      collectionWarnings: warnings,
      representativeCameraId: resolvedRepresentativeId,
      representativeDeviceSerialNo: resolvedRepresentativeSerial,
      pageSize: pageSize,
      maxPages: maxPages,
      playbackLookbackMinutes: playbackLookback.inMinutes,
      playbackWindowMinutes: playbackWindow.inMinutes,
    );

    final alarmMessages = _readAlarmMessages(rawAlarmBatch);
    return HikConnectPayloadBundleCollectionResult(
      directoryPath: bundle.directoryPath,
      outputPaths: <String, String>{
        'camera': cameraPath,
        'alarm': alarmPath,
        'live_address': livePath,
        'playback': playbackPath,
        'video_download': downloadPath,
      },
      cameraCount: cameras.length,
      alarmMessageCount: alarmMessages.length,
      representativeCameraId: resolvedRepresentativeId,
      representativeDeviceSerial: resolvedRepresentativeSerial,
      warnings: List<String>.unmodifiable(warnings),
    );
  }

  HikConnectCameraResource? _selectRepresentativeCamera(
    List<HikConnectCameraResource> cameras, {
    required String preferredCameraId,
    required String preferredDeviceSerial,
    required List<String> warnings,
  }) {
    final normalizedCameraId = preferredCameraId.trim().toLowerCase();
    final normalizedDeviceSerial = preferredDeviceSerial.trim().toLowerCase();

    if (normalizedCameraId.isNotEmpty) {
      for (final camera in cameras) {
        if (camera.resourceId.trim().toLowerCase() == normalizedCameraId &&
            (normalizedDeviceSerial.isEmpty ||
                camera.deviceSerialNo.trim().toLowerCase() ==
                    normalizedDeviceSerial)) {
          return camera;
        }
      }
      warnings.add(
        'Preferred representative camera $preferredCameraId was not found in the collected Hik-Connect inventory.',
      );
    }

    if (normalizedDeviceSerial.isNotEmpty) {
      for (final camera in cameras) {
        if (camera.deviceSerialNo.trim().toLowerCase() ==
            normalizedDeviceSerial) {
          return camera;
        }
      }
      warnings.add(
        'Preferred representative device serial $preferredDeviceSerial was not found in the collected Hik-Connect inventory.',
      );
    }

    for (final camera in cameras) {
      if (camera.deviceSerialNo.trim().isNotEmpty) {
        return camera;
      }
    }
    return cameras.isNotEmpty ? cameras.first : null;
  }

  List<Object?> _readAlarmMessages(Map<String, Object?> rawAlarmBatch) {
    final data = rawAlarmBatch['data'];
    if (data is Map<String, Object?>) {
      final messages = data['alarmMsg'];
      if (messages is List<Object?>) {
        return messages;
      }
      if (messages is List) {
        return List<Object?>.from(messages);
      }
    }
    if (data is Map) {
      final normalized = data.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final messages = normalized['alarmMsg'];
      if (messages is List<Object?>) {
        return messages;
      }
      if (messages is List) {
        return List<Object?>.from(messages);
      }
    }
    return const <Object?>[];
  }

  Future<void> _writeJsonFile(String path, Map<String, Object?> data) async {
    final encoded = const JsonEncoder.withIndent('  ').convert(data);
    await File(path).writeAsString('$encoded\n');
  }

  Future<void> _updateManifestRepresentativeSelection(
    String directoryPath, {
    required DateTime collectionRecordedAtUtc,
    required String areaId,
    required bool includeSubArea,
    required String deviceSerialNo,
    required List<int> alarmEventTypes,
    required Map<String, String> cameraLabelSeeds,
    required int cameraCount,
    required int alarmMessageCount,
    required List<String> collectionWarnings,
    required String representativeCameraId,
    required String representativeDeviceSerialNo,
    required int pageSize,
    required int maxPages,
    required int playbackLookbackMinutes,
    required int playbackWindowMinutes,
  }) async {
    final manifestFile = File(
      '$directoryPath/${HikConnectPayloadBundleLocator.defaultManifestFileName}',
    );
    if (!manifestFile.existsSync()) {
      return;
    }
    final raw = await manifestFile.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return;
    }
    final manifest = decoded.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final existingCameraLabels = <String, String>{};
    final rawCameraLabels = manifest['camera_labels'];
    if (rawCameraLabels is Map) {
      for (final entry in rawCameraLabels.entries) {
        final key = entry.key.toString().trim().toLowerCase();
        final value = entry.value.toString().trim();
        if (key.isEmpty || value.isEmpty) {
          continue;
        }
        existingCameraLabels[key] = value;
      }
    }
    final mergedCameraLabels = <String, String>{
      ...cameraLabelSeeds.map(
        (key, value) => MapEntry(key.trim().toLowerCase(), value.trim()),
      ),
      ...existingCameraLabels,
    };
    manifest['area_id'] = areaId;
    manifest['include_sub_area'] = includeSubArea;
    manifest['device_serial_no'] = deviceSerialNo;
    manifest['alarm_event_types'] = alarmEventTypes;
    manifest['camera_labels'] = mergedCameraLabels;
    manifest['representative_camera_id'] = representativeCameraId;
    manifest['representative_device_serial_no'] = representativeDeviceSerialNo;
    manifest['last_collection_at_utc'] =
        collectionRecordedAtUtc.toUtc().toIso8601String();
    manifest['last_collection_camera_count'] = cameraCount;
    manifest['last_collection_alarm_message_count'] = alarmMessageCount;
    manifest['last_collection_representative_camera_id'] =
        representativeCameraId;
    manifest['last_collection_representative_device_serial_no'] =
        representativeDeviceSerialNo;
    manifest['last_collection_warnings'] = collectionWarnings;
    manifest['page_size'] = pageSize;
    manifest['max_pages'] = maxPages;
    manifest['playback_lookback_minutes'] = playbackLookbackMinutes;
    manifest['playback_window_minutes'] = playbackWindowMinutes;
    final encoded = const JsonEncoder.withIndent('  ').convert(manifest);
    await manifestFile.writeAsString('$encoded\n');
  }

  Map<String, Object?> _emptyLivePayload() {
    return const <String, Object?>{
      'data': <String, Object?>{},
    };
  }

  Map<String, Object?> _emptyPlaybackPayload() {
    return const <String, Object?>{
      'data': <String, Object?>{
        'totalCount': 0,
        'pageIndex': 1,
        'pageSize': 50,
        'recordList': <Object?>[],
      },
    };
  }

  Map<String, Object?> _emptyDownloadPayload() {
    return const <String, Object?>{
      'data': <String, Object?>{
        'downloadUrl': '',
      },
    };
  }
}
