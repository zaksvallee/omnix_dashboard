import 'dart:convert';
import 'dart:io';

class HikConnectPayloadBundleManifest {
  static const int defaultPageSize = 200;
  static const int defaultMaxPages = 20;
  static const int defaultPlaybackLookbackMinutes = 60;
  static const int defaultPlaybackWindowMinutes = 5;

  final String clientId;
  final String regionId;
  final String siteId;
  final String apiBaseUrl;
  final String areaId;
  final bool includeSubArea;
  final String deviceSerialNo;
  final List<int> alarmEventTypes;
  final Map<String, String> cameraLabels;
  final String representativeCameraId;
  final String representativeDeviceSerialNo;
  final int pageSize;
  final int maxPages;
  final int statusMaxAgeHours;
  final int playbackLookbackMinutes;
  final int playbackWindowMinutes;
  final String reportPath;
  final String reportJsonPath;
  final String scopeSeedPath;
  final String pilotEnvPath;
  final String bootstrapPacketPath;
  final String cameraPayloadPath;
  final String alarmPayloadPath;
  final String liveAddressPayloadPath;
  final String playbackPayloadPath;
  final String videoDownloadPayloadPath;

  const HikConnectPayloadBundleManifest({
    required this.clientId,
    required this.regionId,
    required this.siteId,
    required this.apiBaseUrl,
    required this.areaId,
    required this.includeSubArea,
    required this.deviceSerialNo,
    required this.alarmEventTypes,
    required this.cameraLabels,
    required this.representativeCameraId,
    required this.representativeDeviceSerialNo,
    required this.pageSize,
    required this.maxPages,
    required this.statusMaxAgeHours,
    required this.playbackLookbackMinutes,
    required this.playbackWindowMinutes,
    required this.reportPath,
    required this.reportJsonPath,
    required this.scopeSeedPath,
    required this.pilotEnvPath,
    required this.bootstrapPacketPath,
    required this.cameraPayloadPath,
    required this.alarmPayloadPath,
    required this.liveAddressPayloadPath,
    required this.playbackPayloadPath,
    required this.videoDownloadPayloadPath,
  });

  factory HikConnectPayloadBundleManifest.fromJson(Map<String, Object?> json) {
    String readString(List<String> keys) {
      for (final key in keys) {
        final value = (json[key] ?? '').toString().trim();
        if (value.isNotEmpty) {
          return value;
        }
      }
      return '';
    }

    int readInt(List<String> keys, int fallback) {
      for (final key in keys) {
        final raw = (json[key] ?? '').toString().trim();
        final parsed = int.tryParse(raw);
        if (parsed != null && parsed > 0) {
          return parsed;
        }
      }
      return fallback;
    }

    bool readBool(List<String> keys, bool fallback) {
      for (final key in keys) {
        final raw = (json[key] ?? '').toString().trim().toLowerCase();
        if (raw.isEmpty) {
          continue;
        }
        if (raw == '1' || raw == 'true' || raw == 'yes') {
          return true;
        }
        if (raw == '0' || raw == 'false' || raw == 'no') {
          return false;
        }
      }
      return fallback;
    }

    List<int> readIntList(List<String> keys, List<int> fallback) {
      for (final key in keys) {
        final raw = json[key];
        if (raw is List) {
          final output = <int>[];
          for (final entry in raw) {
            final parsed = int.tryParse(entry.toString().trim());
            if (parsed != null) {
              output.add(parsed);
            }
          }
          if (output.isNotEmpty) {
            return List<int>.unmodifiable(output);
          }
        }
        final text = (raw ?? '').toString().trim();
        if (text.isEmpty) {
          continue;
        }
        final output = <int>[];
        for (final token in text.split(RegExp(r'[\s,]+'))) {
          final parsed = int.tryParse(token.trim());
          if (parsed != null) {
            output.add(parsed);
          }
        }
        if (output.isNotEmpty) {
          return List<int>.unmodifiable(output);
        }
      }
      return List<int>.unmodifiable(fallback);
    }

    Map<String, String> readStringMap(List<String> keys) {
      for (final key in keys) {
        final raw = json[key];
        if (raw is! Map) {
          continue;
        }
        final output = <String, String>{};
        for (final entry in raw.entries) {
          final mapKey = entry.key.toString().trim().toLowerCase();
          final mapValue = entry.value.toString().trim();
          if (mapKey.isEmpty || mapValue.isEmpty) {
            continue;
          }
          output[mapKey] = mapValue;
        }
        if (output.isNotEmpty) {
          return Map<String, String>.unmodifiable(output);
        }
      }
      return const <String, String>{};
    }

    return HikConnectPayloadBundleManifest(
      clientId: readString(const ['client_id', 'clientId']),
      regionId: readString(const ['region_id', 'regionId']),
      siteId: readString(const ['site_id', 'siteId']),
      apiBaseUrl: readString(const ['api_base_url', 'apiBaseUrl']),
      areaId: readString(const ['area_id', 'areaId']),
      includeSubArea: readBool(
        const ['include_sub_area', 'includeSubArea'],
        true,
      ),
      deviceSerialNo: readString(
        const ['device_serial_no', 'deviceSerialNo'],
      ),
      alarmEventTypes: readIntList(
        const ['alarm_event_types', 'alarmEventTypes'],
        const <int>[0, 1, 100657],
      ),
      cameraLabels: readStringMap(
        const ['camera_labels', 'cameraLabels'],
      ),
      representativeCameraId: readString(
        const ['representative_camera_id', 'representativeCameraId'],
      ),
      representativeDeviceSerialNo: readString(
        const [
          'representative_device_serial_no',
          'representativeDeviceSerialNo',
        ],
      ),
      pageSize: readInt(
        const ['page_size', 'pageSize'],
        defaultPageSize,
      ),
      maxPages: readInt(
        const ['max_pages', 'maxPages'],
        defaultMaxPages,
      ),
      statusMaxAgeHours: readInt(
        const ['status_max_age_hours', 'statusMaxAgeHours'],
        0,
      ),
      playbackLookbackMinutes: readInt(
        const ['playback_lookback_minutes', 'playbackLookbackMinutes'],
        defaultPlaybackLookbackMinutes,
      ),
      playbackWindowMinutes: readInt(
        const ['playback_window_minutes', 'playbackWindowMinutes'],
        defaultPlaybackWindowMinutes,
      ),
      reportPath: readString(const ['report_path', 'reportPath']),
      reportJsonPath: readString(
        const ['report_json_path', 'reportJsonPath'],
      ),
      scopeSeedPath: readString(
        const ['scope_seed_path', 'scopeSeedPath'],
      ),
      pilotEnvPath: readString(
        const ['pilot_env_path', 'pilotEnvPath'],
      ),
      bootstrapPacketPath: readString(
        const ['bootstrap_packet_path', 'bootstrapPacketPath'],
      ),
      cameraPayloadPath: readString(
        const ['camera_payload_path', 'cameraPayloadPath'],
      ),
      alarmPayloadPath: readString(
        const ['alarm_payload_path', 'alarmPayloadPath'],
      ),
      liveAddressPayloadPath: readString(
        const ['live_address_payload_path', 'liveAddressPayloadPath'],
      ),
      playbackPayloadPath: readString(
        const ['playback_payload_path', 'playbackPayloadPath'],
      ),
      videoDownloadPayloadPath: readString(
        const [
          'video_download_payload_path',
          'videoDownloadPayloadPath',
        ],
      ),
    );
  }
}

class HikConnectPayloadBundlePaths {
  final String cameraPayloadPath;
  final String alarmPayloadPath;
  final String liveAddressPayloadPath;
  final String playbackPayloadPath;
  final String videoDownloadPayloadPath;
  final String clientId;
  final String regionId;
  final String siteId;
  final String apiBaseUrl;
  final String areaId;
  final bool includeSubArea;
  final String deviceSerialNo;
  final List<int> alarmEventTypes;
  final Map<String, String> cameraLabels;
  final String representativeCameraId;
  final String representativeDeviceSerialNo;
  final int pageSize;
  final int maxPages;
  final int statusMaxAgeHours;
  final int playbackLookbackMinutes;
  final int playbackWindowMinutes;
  final String reportOutputPath;
  final String reportJsonOutputPath;
  final String scopeSeedOutputPath;
  final String pilotEnvOutputPath;
  final String bootstrapPacketOutputPath;

  const HikConnectPayloadBundlePaths({
    required this.cameraPayloadPath,
    required this.alarmPayloadPath,
    required this.liveAddressPayloadPath,
    required this.playbackPayloadPath,
    required this.videoDownloadPayloadPath,
    required this.clientId,
    required this.regionId,
    required this.siteId,
    required this.apiBaseUrl,
    required this.areaId,
    required this.includeSubArea,
    required this.deviceSerialNo,
    required this.alarmEventTypes,
    required this.cameraLabels,
    required this.representativeCameraId,
    required this.representativeDeviceSerialNo,
    required this.pageSize,
    required this.maxPages,
    required this.statusMaxAgeHours,
    required this.playbackLookbackMinutes,
    required this.playbackWindowMinutes,
    required this.reportOutputPath,
    required this.reportJsonOutputPath,
    required this.scopeSeedOutputPath,
    required this.pilotEnvOutputPath,
    required this.bootstrapPacketOutputPath,
  });

  bool get hasAny =>
      cameraPayloadPath.isNotEmpty ||
      alarmPayloadPath.isNotEmpty ||
      liveAddressPayloadPath.isNotEmpty ||
      playbackPayloadPath.isNotEmpty ||
      videoDownloadPayloadPath.isNotEmpty;
}

class HikConnectPayloadBundleLocator {
  static const String defaultManifestFileName = 'bundle-manifest.json';
  static const String defaultReportFileName = 'preflight-report.md';
  static const String defaultReportJsonFileName = 'preflight-report.json';
  static const String defaultScopeSeedFileName = 'scope-seed.json';
  static const String defaultPilotEnvFileName = 'pilot-env.sh';
  static const String defaultBootstrapPacketFileName = 'bootstrap-packet.md';
  static const String defaultCameraFileName = 'camera-pages.json';
  static const String defaultAlarmFileName = 'alarm-messages.json';
  static const String defaultLiveFileName = 'live-address.json';
  static const String defaultPlaybackFileName = 'playback-search.json';
  static const String defaultVideoDownloadFileName = 'video-download.json';

  const HikConnectPayloadBundleLocator();

  HikConnectPayloadBundlePaths resolveFromEnvironment(Map<String, String> env) {
    final bundleDir = (env['ONYX_DVR_PREFLIGHT_DIR'] ?? '').trim();
    final directory = bundleDir.isEmpty ? null : Directory(bundleDir);
    final manifest = _loadManifest(directory);

    String resolveMetadata(
      String envKey,
      String manifestValue,
    ) {
      final explicit = (env[envKey] ?? '').trim();
      if (explicit.isNotEmpty) {
        return explicit;
      }
      return manifestValue.trim();
    }

    int resolveIntMetadata(
      String envKey,
      int manifestValue,
      int fallback,
    ) {
      final explicit = int.tryParse((env[envKey] ?? '').trim());
      if (explicit != null && explicit > 0) {
        return explicit;
      }
      if (manifestValue > 0) {
        return manifestValue;
      }
      return fallback;
    }

    bool resolveBoolMetadata(
      String envKey,
      bool manifestValue,
      bool fallback,
    ) {
      final raw = (env[envKey] ?? '').trim().toLowerCase();
      if (raw == '1' || raw == 'true' || raw == 'yes') {
        return true;
      }
      if (raw == '0' || raw == 'false' || raw == 'no') {
        return false;
      }
      return manifestValue == fallback ? fallback : manifestValue;
    }

    List<int> resolveIntListMetadata(
      String envKey,
      List<int> manifestValue,
      List<int> fallback,
    ) {
      final raw = (env[envKey] ?? '').trim();
      if (raw.isNotEmpty) {
        final output = <int>[];
        for (final token in raw.split(RegExp(r'[\s,]+'))) {
          final parsed = int.tryParse(token.trim());
          if (parsed != null) {
            output.add(parsed);
          }
        }
        if (output.isNotEmpty) {
          return List<int>.unmodifiable(output);
        }
      }
      if (manifestValue.isNotEmpty) {
        return List<int>.unmodifiable(manifestValue);
      }
      return List<int>.unmodifiable(fallback);
    }

    Map<String, String> resolveStringMapMetadata(
      String envKey,
      Map<String, String> manifestValue,
    ) {
      final raw = (env[envKey] ?? '').trim();
      if (raw.isNotEmpty) {
        final output = <String, String>{};
        for (final pair in raw.split(',')) {
          final separator = pair.indexOf('=');
          if (separator <= 0) {
            continue;
          }
          final key = pair.substring(0, separator).trim().toLowerCase();
          final value = pair.substring(separator + 1).trim();
          if (key.isEmpty || value.isEmpty) {
            continue;
          }
          output[key] = value;
        }
        if (output.isNotEmpty) {
          return Map<String, String>.unmodifiable(output);
        }
      }
      return Map<String, String>.unmodifiable(manifestValue);
    }

    String resolvePath(
      String envKey,
      String manifestPath,
      String defaultFileName,
    ) {
      final explicit = (env[envKey] ?? '').trim();
      if (explicit.isNotEmpty) {
        return explicit;
      }
      if (manifestPath.trim().isNotEmpty) {
        return _resolveBundleRelativePath(directory, manifestPath);
      }
      if (directory == null) {
        return '';
      }
      final candidate = File('${directory.path}/$defaultFileName');
      return candidate.existsSync() ? candidate.path : '';
    }

    String resolveOutputPath(
      String envKey,
      String manifestPath,
      String defaultFileName,
    ) {
      final explicit = (env[envKey] ?? '').trim();
      if (explicit.isNotEmpty) {
        return explicit;
      }
      if (manifestPath.trim().isNotEmpty) {
        return _resolveBundleRelativePath(directory, manifestPath);
      }
      if (directory == null) {
        return '';
      }
      return File('${directory.path}/$defaultFileName').path;
    }

    return HikConnectPayloadBundlePaths(
      cameraPayloadPath: resolvePath(
        'ONYX_DVR_CAMERA_PAYLOAD_PATH',
        manifest?.cameraPayloadPath ?? '',
        defaultCameraFileName,
      ),
      alarmPayloadPath: resolvePath(
        'ONYX_DVR_ALARM_PAYLOAD_PATH',
        manifest?.alarmPayloadPath ?? '',
        defaultAlarmFileName,
      ),
      liveAddressPayloadPath: resolvePath(
        'ONYX_DVR_LIVE_ADDRESS_PAYLOAD_PATH',
        manifest?.liveAddressPayloadPath ?? '',
        defaultLiveFileName,
      ),
      playbackPayloadPath: resolvePath(
        'ONYX_DVR_PLAYBACK_PAYLOAD_PATH',
        manifest?.playbackPayloadPath ?? '',
        defaultPlaybackFileName,
      ),
      videoDownloadPayloadPath: resolvePath(
        'ONYX_DVR_VIDEO_DOWNLOAD_PAYLOAD_PATH',
        manifest?.videoDownloadPayloadPath ?? '',
        defaultVideoDownloadFileName,
      ),
      clientId: resolveMetadata('ONYX_DVR_CLIENT_ID', manifest?.clientId ?? ''),
      regionId: resolveMetadata(
        'ONYX_DVR_REGION_ID',
        manifest?.regionId ?? '',
      ),
      siteId: resolveMetadata('ONYX_DVR_SITE_ID', manifest?.siteId ?? ''),
      apiBaseUrl: resolveMetadata(
        'ONYX_DVR_API_BASE_URL',
        manifest?.apiBaseUrl ?? '',
      ),
      areaId: resolveMetadata('ONYX_DVR_AREA_ID', manifest?.areaId ?? '-1'),
      includeSubArea: resolveBoolMetadata(
        'ONYX_DVR_INCLUDE_SUB_AREA',
        manifest?.includeSubArea ?? true,
        true,
      ),
      deviceSerialNo: resolveMetadata(
        'ONYX_DVR_DEVICE_SERIAL_NO',
        manifest?.deviceSerialNo ?? '',
      ),
      alarmEventTypes: resolveIntListMetadata(
        'ONYX_DVR_ALARM_EVENT_TYPES',
        manifest?.alarmEventTypes ?? const <int>[0, 1, 100657],
        const <int>[0, 1, 100657],
      ),
      cameraLabels: resolveStringMapMetadata(
        'ONYX_DVR_CAMERA_LABELS',
        manifest?.cameraLabels ?? const <String, String>{},
      ),
      representativeCameraId: resolveMetadata(
        'ONYX_DVR_REPRESENTATIVE_CAMERA_ID',
        manifest?.representativeCameraId ?? '',
      ),
      representativeDeviceSerialNo: resolveMetadata(
        'ONYX_DVR_REPRESENTATIVE_DEVICE_SERIAL_NO',
        manifest?.representativeDeviceSerialNo ?? '',
      ),
      pageSize: resolveIntMetadata(
        'ONYX_DVR_PAGE_SIZE',
        manifest?.pageSize ?? HikConnectPayloadBundleManifest.defaultPageSize,
        HikConnectPayloadBundleManifest.defaultPageSize,
      ),
      maxPages: resolveIntMetadata(
        'ONYX_DVR_MAX_PAGES',
        manifest?.maxPages ?? HikConnectPayloadBundleManifest.defaultMaxPages,
        HikConnectPayloadBundleManifest.defaultMaxPages,
      ),
      statusMaxAgeHours: resolveIntMetadata(
        'ONYX_DVR_BUNDLE_MAX_AGE_HOURS',
        manifest?.statusMaxAgeHours ?? 0,
        0,
      ),
      playbackLookbackMinutes: resolveIntMetadata(
        'ONYX_DVR_PLAYBACK_LOOKBACK_MINUTES',
        manifest?.playbackLookbackMinutes ??
            HikConnectPayloadBundleManifest.defaultPlaybackLookbackMinutes,
        HikConnectPayloadBundleManifest.defaultPlaybackLookbackMinutes,
      ),
      playbackWindowMinutes: resolveIntMetadata(
        'ONYX_DVR_PLAYBACK_WINDOW_MINUTES',
        manifest?.playbackWindowMinutes ??
            HikConnectPayloadBundleManifest.defaultPlaybackWindowMinutes,
        HikConnectPayloadBundleManifest.defaultPlaybackWindowMinutes,
      ),
      reportOutputPath: resolveOutputPath(
        'ONYX_DVR_PREFLIGHT_REPORT_PATH',
        manifest?.reportPath ?? '',
        defaultReportFileName,
      ),
      reportJsonOutputPath: resolveOutputPath(
        'ONYX_DVR_PREFLIGHT_REPORT_JSON_PATH',
        manifest?.reportJsonPath ?? '',
        defaultReportJsonFileName,
      ),
      scopeSeedOutputPath: resolveOutputPath(
        'ONYX_DVR_PREFLIGHT_SCOPE_SEED_PATH',
        manifest?.scopeSeedPath ?? '',
        defaultScopeSeedFileName,
      ),
      pilotEnvOutputPath: resolveOutputPath(
        'ONYX_DVR_PREFLIGHT_PILOT_ENV_PATH',
        manifest?.pilotEnvPath ?? '',
        defaultPilotEnvFileName,
      ),
      bootstrapPacketOutputPath: resolveOutputPath(
        'ONYX_DVR_PREFLIGHT_BOOTSTRAP_PACKET_PATH',
        manifest?.bootstrapPacketPath ?? '',
        defaultBootstrapPacketFileName,
      ),
    );
  }

  HikConnectPayloadBundleManifest? _loadManifest(Directory? directory) {
    if (directory == null) {
      return null;
    }
    final file = File('${directory.path}/$defaultManifestFileName');
    if (!file.existsSync()) {
      return null;
    }
    final raw = file.readAsStringSync().trim();
    if (raw.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, Object?>) {
      return HikConnectPayloadBundleManifest.fromJson(decoded);
    }
    if (decoded is Map) {
      return HikConnectPayloadBundleManifest.fromJson(
        decoded.map(
          (key, value) => MapEntry(key.toString(), value as Object?),
        ),
      );
    }
    return null;
  }

  String _resolveBundleRelativePath(Directory? directory, String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    if (directory == null) {
      return trimmed;
    }
    final file = File(trimmed);
    if (file.isAbsolute) {
      return file.path;
    }
    return File('${directory.path}/$trimmed').path;
  }
}
