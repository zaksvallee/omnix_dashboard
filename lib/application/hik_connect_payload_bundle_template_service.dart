import 'dart:convert';
import 'dart:io';

import 'hik_connect_payload_bundle_locator.dart';

class HikConnectPayloadBundleTemplateResult {
  final String directoryPath;
  final String manifestPath;
  final List<String> payloadPaths;
  final bool createdDirectory;

  const HikConnectPayloadBundleTemplateResult({
    required this.directoryPath,
    required this.manifestPath,
    required this.payloadPaths,
    required this.createdDirectory,
  });
}

class HikConnectPayloadBundleTemplateService {
  const HikConnectPayloadBundleTemplateService();

  Future<HikConnectPayloadBundleTemplateResult> createBundle({
    required String directoryPath,
    String clientId = 'CLIENT-REPLACE-ME',
    String regionId = 'REGION-REPLACE-ME',
    String siteId = 'SITE-REPLACE-ME',
    String apiBaseUrl = '',
  }) async {
    final directory = Directory(directoryPath.trim());
    final createdDirectory = !directory.existsSync();
    if (createdDirectory) {
      await directory.create(recursive: true);
    }

    final manifestPath =
        '${directory.path}/${HikConnectPayloadBundleLocator.defaultManifestFileName}';
    final cameraPath =
        '${directory.path}/${HikConnectPayloadBundleLocator.defaultCameraFileName}';
    final alarmPath =
        '${directory.path}/${HikConnectPayloadBundleLocator.defaultAlarmFileName}';
    final livePath =
        '${directory.path}/${HikConnectPayloadBundleLocator.defaultLiveFileName}';
    final playbackPath =
        '${directory.path}/${HikConnectPayloadBundleLocator.defaultPlaybackFileName}';
    final downloadPath =
        '${directory.path}/${HikConnectPayloadBundleLocator.defaultVideoDownloadFileName}';
    final readmePath = '${directory.path}/README.md';

    final manifestJson = const JsonEncoder.withIndent('  ').convert(
      <String, Object?>{
        'client_id': clientId,
        'region_id': regionId,
        'site_id': siteId,
        'api_base_url': apiBaseUrl,
        'area_id': '-1',
        'include_sub_area': true,
        'device_serial_no': '',
        'alarm_event_types': <int>[0, 1, 100657],
        'camera_labels': <String, String>{},
        'representative_camera_id': '',
        'representative_device_serial_no': '',
        'page_size': HikConnectPayloadBundleManifest.defaultPageSize,
        'max_pages': HikConnectPayloadBundleManifest.defaultMaxPages,
        'status_max_age_hours': 0,
        'playback_lookback_minutes':
            HikConnectPayloadBundleManifest.defaultPlaybackLookbackMinutes,
        'playback_window_minutes':
            HikConnectPayloadBundleManifest.defaultPlaybackWindowMinutes,
        'report_path': HikConnectPayloadBundleLocator.defaultReportFileName,
        'report_json_path':
            HikConnectPayloadBundleLocator.defaultReportJsonFileName,
        'scope_seed_path':
            HikConnectPayloadBundleLocator.defaultScopeSeedFileName,
        'pilot_env_path':
            HikConnectPayloadBundleLocator.defaultPilotEnvFileName,
        'bootstrap_packet_path':
            HikConnectPayloadBundleLocator.defaultBootstrapPacketFileName,
        'camera_payload_path':
            HikConnectPayloadBundleLocator.defaultCameraFileName,
        'alarm_payload_path':
            HikConnectPayloadBundleLocator.defaultAlarmFileName,
        'live_address_payload_path':
            HikConnectPayloadBundleLocator.defaultLiveFileName,
        'playback_payload_path':
            HikConnectPayloadBundleLocator.defaultPlaybackFileName,
        'video_download_payload_path':
            HikConnectPayloadBundleLocator.defaultVideoDownloadFileName,
      },
    );
    await File(manifestPath).writeAsString(
      '$manifestJson\n',
    );

    final cameraJson = const JsonEncoder.withIndent('  ').convert(
      <String, Object?>{
        'pages': <Object?>[],
      },
    );
    await File(cameraPath).writeAsString(
      '$cameraJson\n',
    );
    final alarmJson = const JsonEncoder.withIndent('  ').convert(
      <String, Object?>{
        'data': <String, Object?>{
          'batchId': '',
          'alarmMsg': <Object?>[],
        },
      },
    );
    await File(alarmPath).writeAsString(
      '$alarmJson\n',
    );
    final liveJson = const JsonEncoder.withIndent('  ').convert(
      <String, Object?>{
        'data': <String, Object?>{},
      },
    );
    await File(livePath).writeAsString(
      '$liveJson\n',
    );
    final playbackJson = const JsonEncoder.withIndent('  ').convert(
      <String, Object?>{
        'data': <String, Object?>{
          'totalCount': 0,
          'pageIndex': 1,
          'pageSize': 50,
          'recordList': <Object?>[],
        },
      },
    );
    await File(playbackPath).writeAsString(
      '$playbackJson\n',
    );
    final downloadJson = const JsonEncoder.withIndent('  ').convert(
      <String, Object?>{
        'data': <String, Object?>{
          'downloadUrl': '',
        },
      },
    );
    await File(downloadPath).writeAsString(
      '$downloadJson\n',
    );
    await File(readmePath).writeAsString(_buildReadme(directory.path));

    return HikConnectPayloadBundleTemplateResult(
      directoryPath: directory.path,
      manifestPath: manifestPath,
      payloadPaths: List<String>.unmodifiable(<String>[
        cameraPath,
        alarmPath,
        livePath,
        playbackPath,
        downloadPath,
      ]),
      createdDirectory: createdDirectory,
    );
  }

  String _buildReadme(String directoryPath) {
    return '''
# Hik-Connect Payload Bundle

This folder is a ready preflight bundle for ONYX.

Files:

- `${HikConnectPayloadBundleLocator.defaultManifestFileName}`
- `${HikConnectPayloadBundleLocator.defaultCameraFileName}`
- `${HikConnectPayloadBundleLocator.defaultAlarmFileName}`
- `${HikConnectPayloadBundleLocator.defaultLiveFileName}`
- `${HikConnectPayloadBundleLocator.defaultPlaybackFileName}`
- `${HikConnectPayloadBundleLocator.defaultVideoDownloadFileName}`
- `${HikConnectPayloadBundleLocator.defaultReportFileName}` after the first preflight run
- `${HikConnectPayloadBundleLocator.defaultReportJsonFileName}` after the first preflight run
- `${HikConnectPayloadBundleLocator.defaultScopeSeedFileName}` after the first preflight run
- `${HikConnectPayloadBundleLocator.defaultPilotEnvFileName}` after the first preflight run
- `${HikConnectPayloadBundleLocator.defaultBootstrapPacketFileName}` after the first preflight run

Replace the placeholder JSON files with real Hik-Connect payloads, then run:

```sh
ONYX_DVR_PREFLIGHT_DIR="$directoryPath" dart run tool/hik_connect_preflight.dart
```
''';
  }
}
