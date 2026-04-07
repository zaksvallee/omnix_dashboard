import 'dart:convert';
import 'dart:io';

import 'hik_connect_payload_bundle_locator.dart';

class HikConnectBundleFileStatus {
  final String label;
  final String path;
  final bool exists;
  final int sizeBytes;
  final String modifiedAtUtc;
  final int ageHours;

  const HikConnectBundleFileStatus({
    required this.label,
    required this.path,
    required this.exists,
    required this.sizeBytes,
    required this.modifiedAtUtc,
    required this.ageHours,
  });

  String get summaryLine {
    final status = exists ? 'found' : 'missing';
    final details = <String>[status];
    if (exists && sizeBytes > 0) {
      details.add('$sizeBytes bytes');
    }
    if (exists && modifiedAtUtc.trim().isNotEmpty) {
      details.add('updated $modifiedAtUtc');
      details.add(ageHours > 0 ? '${ageHours}h old' : 'fresh');
    }
    if (path.trim().isNotEmpty) {
      details.add(path);
    }
    return '$label: ${details.join(' • ')}';
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'label': label,
      'path': path,
      'exists': exists,
      'size_bytes': sizeBytes,
      'modified_at_utc': modifiedAtUtc,
      'age_hours': ageHours,
    };
  }
}

class HikConnectBundleStatusResult {
  final String bundleDirectoryPath;
  final String manifestPath;
  final String clientId;
  final String regionId;
  final String siteId;
  final String areaId;
  final bool includeSubArea;
  final String deviceSerialNo;
  final String representativeCameraId;
  final String representativeDeviceSerialNo;
  final List<int> alarmEventTypes;
  final int cameraLabelsCount;
  final int pageSize;
  final int maxPages;
  final int playbackLookbackMinutes;
  final int playbackWindowMinutes;
  final String lastCollectionAtUtc;
  final int lastCollectionCameraCount;
  final int lastCollectionAlarmMessageCount;
  final String lastCollectionRepresentativeCameraId;
  final String lastCollectionRepresentativeDeviceSerialNo;
  final List<String> lastCollectionWarnings;
  final int lastCollectionAgeHours;
  final bool collectionStale;
  final String lastPreflightAtUtc;
  final String lastRolloutReadiness;
  final String reportPath;
  final String reportJsonPath;
  final String scopeSeedPath;
  final String pilotEnvPath;
  final String bootstrapPacketPath;
  final int cameraCount;
  final int alarmTotalMessages;
  final int alarmNormalizedMessages;
  final bool videoLiveAvailable;
  final int videoPlaybackRecords;
  final bool videoDownloadAvailable;
  final int maxAllowedAgeHours;
  final int preflightAgeHours;
  final bool stale;
  final List<HikConnectBundleFileStatus> payloadFiles;
  final List<HikConnectBundleFileStatus> artifactFiles;

  const HikConnectBundleStatusResult({
    required this.bundleDirectoryPath,
    required this.manifestPath,
    required this.clientId,
    required this.regionId,
    required this.siteId,
    required this.areaId,
    required this.includeSubArea,
    required this.deviceSerialNo,
    required this.representativeCameraId,
    required this.representativeDeviceSerialNo,
    required this.alarmEventTypes,
    required this.cameraLabelsCount,
    required this.pageSize,
    required this.maxPages,
    required this.playbackLookbackMinutes,
    required this.playbackWindowMinutes,
    required this.lastCollectionAtUtc,
    required this.lastCollectionCameraCount,
    required this.lastCollectionAlarmMessageCount,
    required this.lastCollectionRepresentativeCameraId,
    required this.lastCollectionRepresentativeDeviceSerialNo,
    required this.lastCollectionWarnings,
    required this.lastCollectionAgeHours,
    required this.collectionStale,
    required this.lastPreflightAtUtc,
    required this.lastRolloutReadiness,
    required this.reportPath,
    required this.reportJsonPath,
    required this.scopeSeedPath,
    required this.pilotEnvPath,
    required this.bootstrapPacketPath,
    required this.cameraCount,
    required this.alarmTotalMessages,
    required this.alarmNormalizedMessages,
    required this.videoLiveAvailable,
    required this.videoPlaybackRecords,
    required this.videoDownloadAvailable,
    required this.maxAllowedAgeHours,
    required this.preflightAgeHours,
    required this.stale,
    required this.payloadFiles,
    required this.artifactFiles,
  });

  bool get hasLastPreflightSummary =>
      lastPreflightAtUtc.trim().isNotEmpty ||
      lastRolloutReadiness.trim().isNotEmpty;

  int get missingPayloadFileCount =>
      payloadFiles.where((entry) => !entry.exists).length;

  int get missingArtifactFileCount =>
      artifactFiles.where((entry) => !entry.exists).length;

  String get bundleHealthLabel {
    if (!hasLastPreflightSummary) {
      return 'PENDING';
    }
    if (stale || collectionStale) {
      return 'STALE';
    }
    if (_summaryLooksReady &&
        missingPayloadFileCount == 0 &&
        missingArtifactFileCount == 0) {
      return 'READY';
    }
    return 'INCOMPLETE';
  }

  bool get strictReady => bundleHealthLabel == 'READY';

  List<String> get warnings {
    final output = <String>[];
    if (!hasLastPreflightSummary) {
      output.add('No preflight summary is recorded in this bundle yet.');
    } else if (!_summaryLooksReady) {
      output.add(
        'Last rollout readiness is not fully ready yet: $lastRolloutReadiness',
      );
    }
    if (stale) {
      output.add(
        'Last preflight summary is stale at ${preflightAgeHours}h old (limit ${maxAllowedAgeHours}h).',
      );
    }
    if (collectionStale) {
      output.add(
        'Last collection snapshot is stale at ${lastCollectionAgeHours}h old (limit ${maxAllowedAgeHours}h).',
      );
    }
    if (missingPayloadFileCount > 0) {
      output.add(
        '$missingPayloadFileCount payload file${missingPayloadFileCount == 1 ? '' : 's'} ${missingPayloadFileCount == 1 ? 'is' : 'are'} missing.',
      );
    }
    if (missingArtifactFileCount > 0) {
      output.add(
        '$missingArtifactFileCount artifact file${missingArtifactFileCount == 1 ? '' : 's'} ${missingArtifactFileCount == 1 ? 'is' : 'are'} missing.',
      );
    }
    return List<String>.unmodifiable(output);
  }

  List<String> get nextSteps {
    final output = <String>[];
    if (!hasLastPreflightSummary) {
      output.add(
        'Run ONYX_DVR_PREFLIGHT_DIR="$bundleDirectoryPath" dart run tool/hik_connect_preflight.dart to record the first bundle summary.',
      );
      return List<String>.unmodifiable(output);
    }
    if (stale) {
      output.add(
        'Rerun bundle preflight because the saved readiness snapshot is older than the allowed max age.',
      );
    }
    if (collectionStale) {
      output.add(
        'Recollect the bundle payloads because the saved collection snapshot is older than the allowed max age.',
      );
    }
    if (missingPayloadFileCount > 0) {
      output.add(
        'Restore or recollect the missing payload files before trusting the saved bundle summary.',
      );
    }
    if (missingArtifactFileCount > 0) {
      output.add(
        'Rerun bundle preflight so the missing report or rollout artifact files are regenerated.',
      );
    }
    if (!_summaryLooksReady) {
      output.add(
        'Review the last rollout readiness and preflight outputs before promoting this bundle.',
      );
    }
    if (output.isEmpty) {
      output.add(
        'Bundle looks ready. Review the saved scope seed, pilot env, and bootstrap packet for rollout.',
      );
    }
    return List<String>.unmodifiable(output);
  }

  bool get _summaryLooksReady {
    final normalized = lastRolloutReadiness.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    return !normalized.contains('incomplete') &&
        !normalized.contains('not yet') &&
        !normalized.contains('missing') &&
        !normalized.contains('pending');
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'bundle_directory_path': bundleDirectoryPath,
      'manifest_path': manifestPath,
      'client_id': clientId,
      'region_id': regionId,
      'site_id': siteId,
      'scope_settings': <String, Object?>{
        'area_id': areaId,
        'include_sub_area': includeSubArea,
        'device_serial_no': deviceSerialNo,
        'representative_camera_id': representativeCameraId,
        'representative_device_serial_no': representativeDeviceSerialNo,
        'alarm_event_types': alarmEventTypes,
        'camera_labels_count': cameraLabelsCount,
        'page_size': pageSize,
        'max_pages': maxPages,
        'playback_lookback_minutes': playbackLookbackMinutes,
        'playback_window_minutes': playbackWindowMinutes,
      },
      'last_collection': <String, Object?>{
        'recorded_at_utc': lastCollectionAtUtc,
        'age_hours': lastCollectionAgeHours,
        'stale': collectionStale,
        'camera_count': lastCollectionCameraCount,
        'alarm_message_count': lastCollectionAlarmMessageCount,
        'representative_camera_id': lastCollectionRepresentativeCameraId,
        'representative_device_serial_no':
            lastCollectionRepresentativeDeviceSerialNo,
        'warnings': lastCollectionWarnings,
      },
      'has_last_preflight_summary': hasLastPreflightSummary,
      'bundle_health_label': bundleHealthLabel,
      'strict_ready': strictReady,
      'collection_stale': collectionStale,
      'last_preflight_at_utc': lastPreflightAtUtc,
      'last_rollout_readiness': lastRolloutReadiness,
      'report_path': reportPath,
      'report_json_path': reportJsonPath,
      'scope_seed_path': scopeSeedPath,
      'pilot_env_path': pilotEnvPath,
      'bootstrap_packet_path': bootstrapPacketPath,
      'camera_count': cameraCount,
      'alarm_total_messages': alarmTotalMessages,
      'alarm_normalized_messages': alarmNormalizedMessages,
      'video_live_available': videoLiveAvailable,
      'video_playback_records': videoPlaybackRecords,
      'video_download_available': videoDownloadAvailable,
      'max_allowed_age_hours': maxAllowedAgeHours,
      'preflight_age_hours': preflightAgeHours,
      'stale': stale,
      'missing_payload_file_count': missingPayloadFileCount,
      'missing_artifact_file_count': missingArtifactFileCount,
      'warnings': warnings,
      'next_steps': nextSteps,
      'payload_files': payloadFiles
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'artifact_files': artifactFiles
          .map((entry) => entry.toJson())
          .toList(growable: false),
    };
  }

  String buildSummary() {
    final headerClient = clientId.trim().isEmpty ? 'CLIENT-UNSET' : clientId;
    final headerSite = siteId.trim().isEmpty ? 'SITE-UNSET' : siteId;
    final headerRegion = regionId.trim().isEmpty ? 'REGION-UNSET' : regionId;
    final buffer = StringBuffer()
      ..writeln('HIK-CONNECT BUNDLE STATUS')
      ..writeln('$headerClient / $headerSite / $headerRegion')
      ..writeln('- bundle: $bundleDirectoryPath')
      ..writeln('- manifest: $manifestPath')
      ..writeln();

    buffer
      ..writeln('Bundle Health')
      ..writeln('- status: $bundleHealthLabel');
    for (final warning in warnings) {
      buffer.writeln('- warning: $warning');
    }
    buffer.writeln();

    if (payloadFiles.isNotEmpty) {
      buffer.writeln('Payload Files');
      for (final entry in payloadFiles) {
        buffer.writeln('- ${entry.summaryLine}');
      }
      buffer.writeln();
    }

    if (artifactFiles.isNotEmpty) {
      buffer.writeln('Artifact Files');
      for (final entry in artifactFiles) {
        buffer.writeln('- ${entry.summaryLine}');
      }
      buffer.writeln();
    }

    buffer
      ..writeln('Scope Settings')
      ..writeln(
        '- area: ${areaId.trim().isEmpty ? 'unset' : areaId} • include sub-area ${includeSubArea ? 'yes' : 'no'}',
      )
      ..writeln(
        '- device serial filter: ${deviceSerialNo.trim().isEmpty ? 'unset' : deviceSerialNo}',
      )
      ..writeln(
        '- representative camera: ${representativeCameraId.trim().isEmpty ? 'unset' : representativeCameraId}',
      )
      ..writeln(
        '- representative serial: ${representativeDeviceSerialNo.trim().isEmpty ? 'unset' : representativeDeviceSerialNo}',
      )
      ..writeln(
        '- alarm event types: ${alarmEventTypes.isEmpty ? 'unset' : alarmEventTypes.join(', ')}',
      )
      ..writeln('- camera labels: $cameraLabelsCount')
      ..writeln(
        '- collection: page size $pageSize • max pages $maxPages • playback lookback ${playbackLookbackMinutes}m • playback window ${playbackWindowMinutes}m',
      )
      ..writeln();

    if (lastCollectionAtUtc.trim().isNotEmpty) {
      buffer
        ..writeln('Last Collection')
        ..writeln('- recorded at: $lastCollectionAtUtc')
        ..writeln(
          '- age: ${lastCollectionAgeHours > 0 ? '${lastCollectionAgeHours}h' : 'fresh'}${maxAllowedAgeHours > 0 ? ' (limit ${maxAllowedAgeHours}h)' : ''}',
        )
        ..writeln(
          '- cameras: $lastCollectionCameraCount • alarm messages: $lastCollectionAlarmMessageCount',
        )
        ..writeln(
          '- representative camera: ${lastCollectionRepresentativeCameraId.trim().isEmpty ? 'unset' : lastCollectionRepresentativeCameraId}',
        )
        ..writeln(
          '- representative serial: ${lastCollectionRepresentativeDeviceSerialNo.trim().isEmpty ? 'unset' : lastCollectionRepresentativeDeviceSerialNo}',
        );
      for (final warning in lastCollectionWarnings) {
        buffer.writeln('- collection warning: $warning');
      }
      buffer.writeln();
    }

    if (!hasLastPreflightSummary) {
      buffer
        ..writeln('No preflight summary is recorded in this bundle yet.')
        ..writeln();
      if (nextSteps.isNotEmpty) {
        buffer.writeln('Next');
        for (final step in nextSteps) {
          buffer.writeln('- $step');
        }
      }
      return buffer.toString().trimRight();
    }

    buffer
      ..writeln('Last Preflight')
      ..writeln(
        '- recorded at: ${lastPreflightAtUtc.trim().isEmpty ? 'unset' : lastPreflightAtUtc}',
      )
      ..writeln(
        '- age: ${preflightAgeHours > 0 ? '${preflightAgeHours}h' : 'fresh'}${maxAllowedAgeHours > 0 ? ' (limit ${maxAllowedAgeHours}h)' : ''}',
      )
      ..writeln(
        '- rollout readiness: ${lastRolloutReadiness.trim().isEmpty ? 'unset' : lastRolloutReadiness}',
      )
      ..writeln(
        '- camera bootstrap: $cameraCount camera${cameraCount == 1 ? '' : 's'}',
      )
      ..writeln(
        '- alarms: $alarmNormalizedMessages/$alarmTotalMessages normalized',
      )
      ..writeln(
        '- video: live ${videoLiveAvailable ? 'yes' : 'no'} • playback $videoPlaybackRecords • download ${videoDownloadAvailable ? 'yes' : 'no'}',
      )
      ..writeln();

    if (artifactFiles.isNotEmpty) {
      buffer.writeln('Saved Artifacts');
      for (final entry in artifactFiles) {
        if (entry.path.trim().isEmpty) {
          continue;
        }
        buffer.writeln('- ${entry.label}: ${entry.path}');
      }
      buffer.writeln();
    }

    if (nextSteps.isNotEmpty) {
      buffer.writeln('Next');
      for (final step in nextSteps) {
        buffer.writeln('- $step');
      }
    }

    return buffer.toString().trimRight();
  }
}

class HikConnectBundleStatusService {
  const HikConnectBundleStatusService();

  Future<HikConnectBundleStatusResult> load({
    required String bundleDirectoryPath,
    int maxAllowedAgeHours = 0,
    DateTime? nowUtc,
  }) async {
    final directory = bundleDirectoryPath.trim();
    const locator = HikConnectPayloadBundleLocator();
    final bundle = locator.resolveFromEnvironment(<String, String>{
      'ONYX_DVR_PREFLIGHT_DIR': directory,
    });
    final manifestPath =
        '$directory/${HikConnectPayloadBundleLocator.defaultManifestFileName}';
    final manifestFile = File(manifestPath);
    if (!manifestFile.existsSync()) {
      throw ArgumentError(
        'Bundle manifest does not exist: $manifestPath',
      );
    }

    final raw = await manifestFile.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw ArgumentError('Bundle manifest is not a JSON object: $manifestPath');
    }
    final manifest = decoded.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final payloadFiles = <HikConnectBundleFileStatus>[
      _buildFileStatus('camera', bundle.cameraPayloadPath, nowUtc: nowUtc),
      _buildFileStatus('alarm', bundle.alarmPayloadPath, nowUtc: nowUtc),
      _buildFileStatus(
        'live address',
        bundle.liveAddressPayloadPath,
        nowUtc: nowUtc,
      ),
      _buildFileStatus('playback', bundle.playbackPayloadPath, nowUtc: nowUtc),
      _buildFileStatus(
        'video download',
        bundle.videoDownloadPayloadPath,
        nowUtc: nowUtc,
      ),
    ].where((entry) => entry.path.trim().isNotEmpty).toList(growable: false);
    final artifactFiles = <HikConnectBundleFileStatus>[
      _buildFileStatus(
        'report',
        _readString(manifest, 'last_report_path').isNotEmpty
            ? _readString(manifest, 'last_report_path')
            : bundle.reportOutputPath,
        nowUtc: nowUtc,
      ),
      _buildFileStatus(
        'report json',
        _readString(manifest, 'last_report_json_path').isNotEmpty
            ? _readString(manifest, 'last_report_json_path')
            : bundle.reportJsonOutputPath,
        nowUtc: nowUtc,
      ),
      _buildFileStatus(
        'scope seed',
        _readString(manifest, 'last_scope_seed_path').isNotEmpty
            ? _readString(manifest, 'last_scope_seed_path')
            : bundle.scopeSeedOutputPath,
        nowUtc: nowUtc,
      ),
      _buildFileStatus(
        'pilot env',
        _readString(manifest, 'last_pilot_env_path').isNotEmpty
            ? _readString(manifest, 'last_pilot_env_path')
            : bundle.pilotEnvOutputPath,
        nowUtc: nowUtc,
      ),
      _buildFileStatus(
        'bootstrap packet',
        _readString(manifest, 'last_bootstrap_packet_path').isNotEmpty
            ? _readString(manifest, 'last_bootstrap_packet_path')
            : bundle.bootstrapPacketOutputPath,
        nowUtc: nowUtc,
      ),
    ].where((entry) => entry.path.trim().isNotEmpty).toList(growable: false);
    final lastPreflightAtUtc = _readString(manifest, 'last_preflight_at_utc');
    final preflightAgeHours = _computeAgeHours(
      lastPreflightAtUtc,
      nowUtc: nowUtc,
    );
    final lastCollectionAtUtc = _readString(manifest, 'last_collection_at_utc');
    final lastCollectionAgeHours = _computeAgeHours(
      lastCollectionAtUtc,
      nowUtc: nowUtc,
    );
    final stale =
        maxAllowedAgeHours > 0 &&
        preflightAgeHours > maxAllowedAgeHours &&
        lastPreflightAtUtc.trim().isNotEmpty;
    final collectionStale =
        maxAllowedAgeHours > 0 &&
        lastCollectionAgeHours > maxAllowedAgeHours &&
        lastCollectionAtUtc.trim().isNotEmpty;

    return HikConnectBundleStatusResult(
      bundleDirectoryPath: directory,
      manifestPath: manifestPath,
      clientId: _readString(manifest, 'client_id'),
      regionId: _readString(manifest, 'region_id'),
      siteId: _readString(manifest, 'site_id'),
      areaId: bundle.areaId,
      includeSubArea: bundle.includeSubArea,
      deviceSerialNo: bundle.deviceSerialNo,
      representativeCameraId: bundle.representativeCameraId,
      representativeDeviceSerialNo: bundle.representativeDeviceSerialNo,
      alarmEventTypes: List<int>.unmodifiable(bundle.alarmEventTypes),
      cameraLabelsCount: bundle.cameraLabels.length,
      pageSize: bundle.pageSize,
      maxPages: bundle.maxPages,
      playbackLookbackMinutes: bundle.playbackLookbackMinutes,
      playbackWindowMinutes: bundle.playbackWindowMinutes,
      lastCollectionAtUtc: lastCollectionAtUtc,
      lastCollectionCameraCount: _readInt(
        manifest,
        'last_collection_camera_count',
      ),
      lastCollectionAlarmMessageCount: _readInt(
        manifest,
        'last_collection_alarm_message_count',
      ),
      lastCollectionRepresentativeCameraId: _readString(
        manifest,
        'last_collection_representative_camera_id',
      ),
      lastCollectionRepresentativeDeviceSerialNo: _readString(
        manifest,
        'last_collection_representative_device_serial_no',
      ),
      lastCollectionWarnings: _readStringList(
        manifest,
        'last_collection_warnings',
      ),
      lastCollectionAgeHours: lastCollectionAgeHours,
      collectionStale: collectionStale,
      lastPreflightAtUtc: lastPreflightAtUtc,
      lastRolloutReadiness: _readString(manifest, 'last_rollout_readiness'),
      reportPath: _readString(manifest, 'last_report_path'),
      reportJsonPath: _readString(manifest, 'last_report_json_path'),
      scopeSeedPath: _readString(manifest, 'last_scope_seed_path'),
      pilotEnvPath: _readString(manifest, 'last_pilot_env_path'),
      bootstrapPacketPath: _readString(manifest, 'last_bootstrap_packet_path'),
      cameraCount: _readInt(manifest, 'last_camera_count'),
      alarmTotalMessages: _readInt(manifest, 'last_alarm_total_messages'),
      alarmNormalizedMessages: _readInt(
        manifest,
        'last_alarm_normalized_messages',
      ),
      videoLiveAvailable: _readBool(manifest, 'last_video_live_available'),
      videoPlaybackRecords: _readInt(manifest, 'last_video_playback_records'),
      videoDownloadAvailable: _readBool(
        manifest,
        'last_video_download_available',
      ),
      maxAllowedAgeHours: maxAllowedAgeHours,
      preflightAgeHours: preflightAgeHours,
      stale: stale,
      payloadFiles: List<HikConnectBundleFileStatus>.unmodifiable(payloadFiles),
      artifactFiles: List<HikConnectBundleFileStatus>.unmodifiable(
        artifactFiles,
      ),
    );
  }

  String _readString(Map<String, Object?> manifest, String key) {
    return (manifest[key] ?? '').toString().trim();
  }

  int _readInt(Map<String, Object?> manifest, String key) {
    final raw = manifest[key];
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    return int.tryParse((raw ?? '').toString().trim()) ?? 0;
  }

  bool _readBool(Map<String, Object?> manifest, String key) {
    final raw = (manifest[key] ?? '').toString().trim().toLowerCase();
    return raw == 'true' || raw == '1' || raw == 'yes';
  }

  List<String> _readStringList(Map<String, Object?> manifest, String key) {
    final raw = manifest[key];
    if (raw is List) {
      return raw
          .map((entry) => entry.toString().trim())
          .where((entry) => entry.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  int _computeAgeHours(String recordedAtUtc, {DateTime? nowUtc}) {
    final recorded = DateTime.tryParse(recordedAtUtc.trim());
    if (recorded == null) {
      return 0;
    }
    final now = (nowUtc ?? DateTime.now().toUtc()).toUtc();
    final age = now.difference(recorded.toUtc());
    if (age.isNegative) {
      return 0;
    }
    return age.inHours;
  }

  HikConnectBundleFileStatus _buildFileStatus(
    String label,
    String path, {
    DateTime? nowUtc,
  }) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      return HikConnectBundleFileStatus(
        label: label,
        path: '',
        exists: false,
        sizeBytes: 0,
        modifiedAtUtc: '',
        ageHours: 0,
      );
    }
    final file = File(trimmed);
    final exists = file.existsSync();
    final sizeBytes = exists ? file.lengthSync() : 0;
    final modifiedAtUtc = exists
        ? file.lastModifiedSync().toUtc().toIso8601String()
        : '';
    final ageHours = exists
        ? _computeFileAgeHours(
            file.lastModifiedSync().toUtc(),
            nowUtc: nowUtc,
          )
        : 0;
    return HikConnectBundleFileStatus(
      label: label,
      path: file.path,
      exists: exists,
      sizeBytes: sizeBytes,
      modifiedAtUtc: modifiedAtUtc,
      ageHours: ageHours,
    );
  }

  int _computeFileAgeHours(DateTime modifiedAtUtc, {DateTime? nowUtc}) {
    final now = (nowUtc ?? DateTime.now().toUtc()).toUtc();
    final age = now.difference(modifiedAtUtc.toUtc());
    if (age.isNegative) {
      return 0;
    }
    return age.inHours;
  }
}
