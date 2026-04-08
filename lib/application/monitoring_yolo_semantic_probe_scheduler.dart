import '../domain/intelligence/intel_ingestion.dart';
import 'dvr_scope_config.dart';
import 'monitoring_watch_continuous_visual_service.dart';

class MonitoringYoloSemanticProbeScheduler {
  final Duration cameraCooldown;
  final int maxCamerasPerSweep;

  final Map<String, DateTime> _lastProbeAtByScopeCamera = <String, DateTime>{};

  MonitoringYoloSemanticProbeScheduler({
    this.cameraCooldown = const Duration(seconds: 24),
    this.maxCamerasPerSweep = 3,
  });

  List<NormalizedIntelRecord> buildProbeRecords({
    required DvrScopeConfig scope,
    required MonitoringWatchContinuousVisualScopeSnapshot snapshot,
    required DateTime nowUtc,
  }) {
    if (maxCamerasPerSweep <= 0) {
      return const <NormalizedIntelRecord>[];
    }
    final eligibleCameras =
        snapshot.cameras
            .where((camera) {
              final snapshotUrl = camera.snapshotUri.toString().trim();
              return camera.reachable && snapshotUrl.isNotEmpty;
            })
            .toList(growable: false)
          ..sort((left, right) {
            final stagePriority = _stagePriority(
              right.changeStage,
            ).compareTo(_stagePriority(left.changeStage));
            if (stagePriority != 0) {
              return stagePriority;
            }
            final leftProbeAt = _lastProbeAt(scope.scopeKey, left.cameraId);
            final rightProbeAt = _lastProbeAt(scope.scopeKey, right.cameraId);
            if (leftProbeAt == null && rightProbeAt != null) {
              return -1;
            }
            if (leftProbeAt != null && rightProbeAt == null) {
              return 1;
            }
            if (leftProbeAt != null && rightProbeAt != null) {
              final byProbeAt = leftProbeAt.compareTo(rightProbeAt);
              if (byProbeAt != 0) {
                return byProbeAt;
              }
            }
            final streak = right.changeStreakCount.compareTo(
              left.changeStreakCount,
            );
            if (streak != 0) {
              return streak;
            }
            return left.cameraId.compareTo(right.cameraId);
          });

    final selected = <MonitoringWatchContinuousVisualCameraSnapshot>[];
    for (final camera in eligibleCameras) {
      final lastProbeAt = _lastProbeAt(scope.scopeKey, camera.cameraId);
      final cooldownSatisfied =
          lastProbeAt == null ||
          nowUtc.difference(lastProbeAt).abs() >= cameraCooldown;
      if (!cooldownSatisfied) {
        continue;
      }
      selected.add(camera);
      if (selected.length >= maxCamerasPerSweep) {
        break;
      }
    }
    if (selected.isEmpty) {
      return const <NormalizedIntelRecord>[];
    }

    final probeWindowKey = _probeWindowKey(nowUtc);
    final records = <NormalizedIntelRecord>[];
    for (final camera in selected) {
      _lastProbeAtByScopeCamera[_scopeCameraKey(
            scope.scopeKey,
            camera.cameraId,
          )] =
          nowUtc;
      final hotspot = _hotspotLabel(camera);
      records.add(
        NormalizedIntelRecord(
          provider: scope.provider,
          sourceType: 'dvr',
          externalId:
              'semantic-probe:${scope.scopeKey}:${camera.cameraId}:$probeWindowKey',
          clientId: scope.clientId,
          regionId: scope.regionId,
          siteId: scope.siteId,
          cameraId: camera.cameraId,
          zone: hotspot,
          objectLabel: 'movement',
          objectConfidence: null,
          headline: 'Semantic watch probe on ${camera.cameraLabel}',
          summary:
              'Semantic watch probe sampled ${camera.cameraLabel}${hotspot == null ? '' : ' near $hotspot'} for person, vehicle, or animal activity.',
          riskScore: _riskScoreFor(camera),
          occurredAtUtc: nowUtc,
          snapshotUrl: camera.snapshotUri.toString(),
        ),
      );
    }
    return List<NormalizedIntelRecord>.unmodifiable(records);
  }

  DateTime? _lastProbeAt(String scopeKey, String cameraId) {
    return _lastProbeAtByScopeCamera[_scopeCameraKey(scopeKey, cameraId)];
  }

  String _scopeCameraKey(String scopeKey, String cameraId) {
    return '$scopeKey|$cameraId';
  }

  int _probeWindowKey(DateTime nowUtc) {
    final milliseconds = cameraCooldown.inMilliseconds;
    if (milliseconds <= 0) {
      return nowUtc.millisecondsSinceEpoch;
    }
    return nowUtc.millisecondsSinceEpoch ~/ milliseconds;
  }

  int _stagePriority(MonitoringWatchContinuousVisualChangeStage stage) {
    return switch (stage) {
      MonitoringWatchContinuousVisualChangeStage.persistent => 4,
      MonitoringWatchContinuousVisualChangeStage.sustained => 3,
      MonitoringWatchContinuousVisualChangeStage.watching => 2,
      MonitoringWatchContinuousVisualChangeStage.idle => 1,
    };
  }

  String? _hotspotLabel(MonitoringWatchContinuousVisualCameraSnapshot camera) {
    final candidates = <String?>[
      camera.areaLabel,
      camera.zoneLabel,
      camera.cameraLabel,
    ];
    for (final candidate in candidates) {
      final normalized = candidate?.trim() ?? '';
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return null;
  }

  int _riskScoreFor(MonitoringWatchContinuousVisualCameraSnapshot camera) {
    final stageBoost = switch (camera.changeStage) {
      MonitoringWatchContinuousVisualChangeStage.persistent => 20,
      MonitoringWatchContinuousVisualChangeStage.sustained => 14,
      MonitoringWatchContinuousVisualChangeStage.watching => 8,
      MonitoringWatchContinuousVisualChangeStage.idle => 4,
    };
    final priorityBoost = switch ((camera.watchPriorityLabel ?? '')
        .trim()
        .toLowerCase()) {
      'critical' => 14,
      'high' => 10,
      'medium' => 6,
      _ => 0,
    };
    return 38 + stageBoost + priorityBoost;
  }
}
