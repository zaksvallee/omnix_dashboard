import '../domain/intelligence/intel_ingestion.dart';
import 'hik_connect_alarm_smoke_service.dart';
import 'hik_connect_bootstrap_orchestrator_service.dart';
import 'hik_connect_video_smoke_service.dart';

class HikConnectPreflightReportService {
  const HikConnectPreflightReportService();

  String buildReport({
    required String clientId,
    required String regionId,
    required String siteId,
    HikConnectBootstrapRunResult? bootstrap,
    HikConnectAlarmSmokeResult? alarm,
    HikConnectVideoSmokeResult? video,
    List<String> bundleHealthNotes = const <String>[],
    List<Map<String, Object?>> payloadInventory = const <Map<String, Object?>>[],
    List<Map<String, Object?>> rolloutArtifacts = const <Map<String, Object?>>[],
    List<String> nextSteps = const <String>[],
  }) {
    final buffer = StringBuffer()
      ..writeln('HIK-CONNECT PREFLIGHT REPORT')
      ..writeln('$clientId / $siteId / $regionId')
      ..writeln();

    if (payloadInventory.isNotEmpty) {
      buffer.writeln('Payload Inventory');
      for (final entry in payloadInventory) {
        final key = (entry['key'] ?? '').toString().trim();
        final status = _formatInventoryStatus(
          (entry['status'] ?? '').toString().trim(),
        );
        final path = (entry['path'] ?? '').toString().trim();
        final sizeBytes = entry['size_bytes'] is num
            ? (entry['size_bytes'] as num).toInt()
            : 0;
        final label = key.isEmpty ? 'unknown' : key;
        final details = <String>[status];
        if (sizeBytes > 0) {
          details.add('$sizeBytes bytes');
        }
        if (path.isNotEmpty) {
          details.add(path);
        }
        buffer.writeln('- $label: ${details.join(' • ')}');
      }
      buffer.writeln();
    }

    if (bootstrap != null) {
      final sampleCameras = bootstrap.snapshot.cameras
          .take(3)
          .map((camera) => camera.displayName.trim())
          .where((label) => label.isNotEmpty)
          .toList(growable: false);
      buffer
        ..writeln('Camera Bootstrap')
        ..writeln('- status: ${bootstrap.readinessLabel}')
        ..writeln('- summary: ${bootstrap.snapshot.summaryLabel}');
      if (sampleCameras.isNotEmpty) {
        buffer.writeln('- sample cameras: ${sampleCameras.join(', ')}');
      }
      if (bootstrap.warnings.isNotEmpty) {
        for (final warning in bootstrap.warnings) {
          buffer.writeln('- warning: $warning');
        }
      }
      buffer.writeln();
    }

    if (alarm != null) {
      buffer
        ..writeln('Alarm Smoke')
        ..writeln(
          '- normalized: ${alarm.normalizedRecords.length}/${alarm.totalMessages}',
        );
      if (alarm.droppedMessages > 0) {
        buffer.writeln('- dropped: ${alarm.droppedMessages}');
      }
      for (final record in alarm.normalizedRecords) {
        final area = (record.zone ?? '').trim();
        final plate = (record.plateNumber ?? '').trim();
        buffer.writeln('- ${record.headline}');
        buffer.writeln('  externalId: ${record.externalId}');
        if (area.isNotEmpty) {
          buffer.writeln('  area: $area');
        }
        if (plate.isNotEmpty) {
          buffer.writeln('  plate: $plate');
        }
      }
      buffer.writeln();
    }

    if (video != null) {
      buffer.writeln('Video Smoke');
      if (video.liveAddress != null) {
        buffer.writeln('- live: ${video.liveAddress!.primaryUrl}');
      }
      if (video.playbackCatalog != null) {
        buffer.writeln(
          '- playback records: ${video.playbackCatalog!.totalCount}',
        );
      }
      if (video.downloadResult != null &&
          video.downloadResult!.downloadUrl.trim().isNotEmpty) {
        buffer.writeln('- download: ${video.downloadResult!.downloadUrl}');
      }
      buffer.writeln();
    }

    if (bundleHealthNotes.isNotEmpty) {
      buffer.writeln('Bundle Health');
      for (final note in bundleHealthNotes) {
        buffer.writeln('- $note');
      }
      buffer.writeln();
    }

    if (rolloutArtifacts.isNotEmpty) {
      buffer.writeln('Rollout Artifacts');
      for (final entry in rolloutArtifacts) {
        final label = (entry['label'] ?? entry['key'] ?? 'artifact')
            .toString()
            .trim();
        final path = (entry['path'] ?? '').toString().trim();
        if (path.isEmpty) {
          continue;
        }
        buffer.writeln('- $label: $path');
      }
      buffer.writeln();
    }

    if (nextSteps.isNotEmpty) {
      buffer.writeln('Next Steps');
      for (final step in nextSteps) {
        buffer.writeln('- $step');
      }
      buffer.writeln();
    }

    final ready = _buildReadinessLine(
      bootstrap: bootstrap,
      alarm: alarm,
      video: video,
    );
    buffer
      ..writeln('Rollout Readiness')
      ..writeln('- $ready');

    return buffer.toString().trimRight();
  }

  Map<String, Object?> buildJsonReport({
    required String clientId,
    required String regionId,
    required String siteId,
    HikConnectBootstrapRunResult? bootstrap,
    HikConnectAlarmSmokeResult? alarm,
    HikConnectVideoSmokeResult? video,
    List<String> bundleHealthNotes = const <String>[],
    List<Map<String, Object?>> payloadInventory = const <Map<String, Object?>>[],
    List<Map<String, Object?>> rolloutArtifacts = const <Map<String, Object?>>[],
    List<String> nextSteps = const <String>[],
  }) {
    return <String, Object?>{
      'client_id': clientId,
      'region_id': regionId,
      'site_id': siteId,
      'payload_inventory': payloadInventory,
      'camera_bootstrap': bootstrap == null
          ? null
          : <String, Object?>{
              'status': bootstrap.readinessLabel,
              'ready_for_pilot': bootstrap.readyForPilot,
              'summary': bootstrap.snapshot.summaryLabel,
              'camera_count': bootstrap.snapshot.cameraCount,
              'device_serials': bootstrap.snapshot.deviceSerials,
              'area_names': bootstrap.snapshot.areaNames,
              'sample_cameras': bootstrap.snapshot.cameras
                  .take(3)
                  .map((camera) => camera.displayName.trim())
                  .where((label) => label.isNotEmpty)
                  .toList(growable: false),
              'warnings': bootstrap.warnings,
            },
      'alarm_smoke': alarm == null
          ? null
          : <String, Object?>{
              'total_messages': alarm.totalMessages,
              'normalized_messages': alarm.normalizedRecords.length,
              'dropped_messages': alarm.droppedMessages,
              'records': alarm.normalizedRecords
                  .map(_normalizedRecordToJson)
                  .toList(growable: false),
            },
      'video_smoke': video == null
          ? null
          : <String, Object?>{
              'live_primary_url': video.liveAddress?.primaryUrl ?? '',
              'live_urls_by_key': video.liveAddress?.urlsByKey ?? const <String, String>{},
              'playback_total_count': video.playbackCatalog?.totalCount ?? 0,
              'playback_records': video.playbackCatalog?.records
                      .map(
                        (record) => <String, Object?>{
                          'record_id': record.recordId,
                          'begin_time': record.beginTime,
                          'end_time': record.endTime,
                          'playback_url': record.playbackUrl,
                        },
                      )
                      .toList(growable: false) ??
                  const <Map<String, Object?>>[],
              'download_url': video.downloadResult?.downloadUrl ?? '',
            },
      'bundle_health_notes': bundleHealthNotes,
      'rollout_artifacts': rolloutArtifacts,
      'next_steps': nextSteps,
      'rollout_readiness': _buildReadinessLine(
        bootstrap: bootstrap,
        alarm: alarm,
        video: video,
      ),
    };
  }

  Map<String, Object?> _normalizedRecordToJson(NormalizedIntelRecord record) {
    return <String, Object?>{
      'provider': record.provider,
      'source_type': record.sourceType,
      'external_id': record.externalId,
      'camera_id': record.cameraId,
      'zone': record.zone,
      'plate_number': record.plateNumber,
      'headline': record.headline,
      'summary': record.summary,
      'risk_score': record.riskScore,
      'occurred_at_utc': record.occurredAtUtc.toUtc().toIso8601String(),
      'snapshot_url': record.snapshotUrl,
      'clip_url': record.clipUrl,
    };
  }

  String _formatInventoryStatus(String status) {
    switch (status) {
      case 'found':
        return 'found';
      case 'configured_missing':
        return 'configured but missing';
      case 'unset':
      default:
        return 'unset';
    }
  }

  String _buildReadinessLine({
    HikConnectBootstrapRunResult? bootstrap,
    HikConnectAlarmSmokeResult? alarm,
    HikConnectVideoSmokeResult? video,
  }) {
    final parts = <String>[];
    if (bootstrap != null) {
      parts.add(
        bootstrap.readyForPilot ? 'camera bootstrap ready' : 'camera bootstrap incomplete',
      );
    }
    if (alarm != null) {
      parts.add(
        alarm.normalizedRecords.isNotEmpty
            ? 'alarm normalization verified'
            : 'alarm normalization not yet verified',
      );
    }
    if (video != null) {
      final hasLive = video.liveAddress != null &&
          video.liveAddress!.primaryUrl.trim().isNotEmpty;
      final hasPlayback = video.playbackCatalog != null &&
          video.playbackCatalog!.records.isNotEmpty;
      if (hasLive || hasPlayback) {
        parts.add('video payloads verified');
      } else {
        parts.add('video payloads incomplete');
      }
    }
    if (parts.isEmpty) {
      return 'no payloads reviewed';
    }
    return parts.join(' | ');
  }
}
