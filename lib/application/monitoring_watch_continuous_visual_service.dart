import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../domain/events/intelligence_received.dart';
import '../domain/intelligence/intel_ingestion.dart';
import 'dvr_http_auth.dart';
import 'dvr_ingest_contract.dart';
import 'dvr_scope_config.dart';

enum MonitoringWatchContinuousVisualStatus {
  inactive,
  learning,
  active,
  alerting,
  degraded,
}

enum MonitoringWatchContinuousVisualChangeStage {
  idle,
  watching,
  sustained,
  persistent,
}

extension MonitoringWatchContinuousVisualStatusValue
    on MonitoringWatchContinuousVisualStatus {
  String get wireValue => switch (this) {
    MonitoringWatchContinuousVisualStatus.inactive => 'inactive',
    MonitoringWatchContinuousVisualStatus.learning => 'learning',
    MonitoringWatchContinuousVisualStatus.active => 'active',
    MonitoringWatchContinuousVisualStatus.alerting => 'alerting',
    MonitoringWatchContinuousVisualStatus.degraded => 'degraded',
  };
}

extension MonitoringWatchContinuousVisualChangeStageValue
    on MonitoringWatchContinuousVisualChangeStage {
  String get wireValue => switch (this) {
    MonitoringWatchContinuousVisualChangeStage.idle => 'idle',
    MonitoringWatchContinuousVisualChangeStage.watching => 'watching',
    MonitoringWatchContinuousVisualChangeStage.sustained => 'sustained',
    MonitoringWatchContinuousVisualChangeStage.persistent => 'persistent',
  };
}

class MonitoringWatchContinuousVisualCameraSnapshot {
  final String cameraId;
  final String cameraLabel;
  final String? zoneLabel;
  final String? areaLabel;
  final String? watchRuleKey;
  final String? watchPriorityLabel;
  final Uri snapshotUri;
  final bool reachable;
  final bool baselineReady;
  final DateTime? lastSampledAtUtc;
  final DateTime? lastCandidateAtUtc;
  final DateTime? changeActiveSinceUtc;
  final int changeStreakCount;
  final MonitoringWatchContinuousVisualChangeStage changeStage;
  final double? lastSceneDeltaScore;
  final String lastFingerprint;
  final String lastError;

  const MonitoringWatchContinuousVisualCameraSnapshot({
    required this.cameraId,
    required this.cameraLabel,
    this.zoneLabel,
    this.areaLabel,
    this.watchRuleKey,
    this.watchPriorityLabel,
    required this.snapshotUri,
    required this.reachable,
    required this.baselineReady,
    this.lastSampledAtUtc,
    this.lastCandidateAtUtc,
    this.changeActiveSinceUtc,
    this.changeStreakCount = 0,
    this.changeStage = MonitoringWatchContinuousVisualChangeStage.idle,
    this.lastSceneDeltaScore,
    this.lastFingerprint = '',
    this.lastError = '',
  });
}

class MonitoringWatchContinuousVisualScopeSnapshot {
  final String scopeKey;
  final MonitoringWatchContinuousVisualStatus status;
  final DateTime? lastSweepAtUtc;
  final DateTime? lastCandidateAtUtc;
  final int sampledCameraCount;
  final int reachableCameraCount;
  final int baselineReadyCameraCount;
  final int emittedCandidateCount;
  final String? hotCameraId;
  final String? hotCameraLabel;
  final String? hotZoneLabel;
  final String? hotAreaLabel;
  final String? hotWatchRuleKey;
  final String? hotWatchPriorityLabel;
  final int? hotCameraChangeStreakCount;
  final MonitoringWatchContinuousVisualChangeStage? hotCameraChangeStage;
  final DateTime? hotCameraChangeActiveSinceUtc;
  final double? hotCameraSceneDeltaScore;
  final String? correlatedContextLabel;
  final String? correlatedAreaLabel;
  final String? correlatedZoneLabel;
  final String? correlatedWatchRuleKey;
  final String? correlatedWatchPriorityLabel;
  final MonitoringWatchContinuousVisualChangeStage? correlatedChangeStage;
  final DateTime? correlatedActiveSinceUtc;
  final int? correlatedCameraCount;
  final List<String> correlatedCameraLabels;
  final String? watchPostureKey;
  final String? watchPostureLabel;
  final String? watchAttentionLabel;
  final String? watchSourceLabel;
  final String summary;
  final String lastError;
  final List<MonitoringWatchContinuousVisualCameraSnapshot> cameras;

  const MonitoringWatchContinuousVisualScopeSnapshot({
    required this.scopeKey,
    required this.status,
    this.lastSweepAtUtc,
    this.lastCandidateAtUtc,
    this.sampledCameraCount = 0,
    this.reachableCameraCount = 0,
    this.baselineReadyCameraCount = 0,
    this.emittedCandidateCount = 0,
    this.hotCameraId,
    this.hotCameraLabel,
    this.hotZoneLabel,
    this.hotAreaLabel,
    this.hotWatchRuleKey,
    this.hotWatchPriorityLabel,
    this.hotCameraChangeStreakCount,
    this.hotCameraChangeStage,
    this.hotCameraChangeActiveSinceUtc,
    this.hotCameraSceneDeltaScore,
    this.correlatedContextLabel,
    this.correlatedAreaLabel,
    this.correlatedZoneLabel,
    this.correlatedWatchRuleKey,
    this.correlatedWatchPriorityLabel,
    this.correlatedChangeStage,
    this.correlatedActiveSinceUtc,
    this.correlatedCameraCount,
    this.correlatedCameraLabels = const <String>[],
    this.watchPostureKey,
    this.watchPostureLabel,
    this.watchAttentionLabel,
    this.watchSourceLabel,
    this.summary = '',
    this.lastError = '',
    this.cameras = const <MonitoringWatchContinuousVisualCameraSnapshot>[],
  });
}

class MonitoringWatchContinuousVisualCandidate {
  final String cameraId;
  final Uri snapshotUri;
  final DateTime occurredAtUtc;
  final double sceneDeltaScore;
  final NormalizedIntelRecord record;

  const MonitoringWatchContinuousVisualCandidate({
    required this.cameraId,
    required this.snapshotUri,
    required this.occurredAtUtc,
    required this.sceneDeltaScore,
    required this.record,
  });
}

class MonitoringWatchContinuousVisualSweepResult {
  final MonitoringWatchContinuousVisualScopeSnapshot snapshot;
  final List<MonitoringWatchContinuousVisualCandidate> candidates;

  const MonitoringWatchContinuousVisualSweepResult({
    required this.snapshot,
    this.candidates = const <MonitoringWatchContinuousVisualCandidate>[],
  });
}

class MonitoringWatchContinuousVisualService {
  final http.Client client;
  final Duration requestTimeout;
  final Duration candidateCooldown;
  final Duration staleBaselineAfter;
  final int minBaselineFrames;
  final int minConsecutiveChangeSweeps;
  final int persistentChangeSweepThreshold;
  final Duration persistentChangeAfter;
  final Duration perimeterPersistentChangeAfter;
  final Duration outdoorPersistentChangeAfter;
  final int maxHistoryFrames;
  final int maxCamerasPerSweep;
  final int discoveryProbeLimit;
  final double sceneChangeThreshold;

  final Map<String, _ContinuousVisualScopeState> _stateByScope =
      <String, _ContinuousVisualScopeState>{};

  MonitoringWatchContinuousVisualService({
    required this.client,
    this.requestTimeout = const Duration(seconds: 4),
    this.candidateCooldown = const Duration(seconds: 90),
    this.staleBaselineAfter = const Duration(minutes: 8),
    this.minBaselineFrames = 3,
    this.minConsecutiveChangeSweeps = 2,
    this.persistentChangeSweepThreshold = 5,
    this.persistentChangeAfter = const Duration(seconds: 45),
    this.perimeterPersistentChangeAfter = const Duration(seconds: 30),
    this.outdoorPersistentChangeAfter = const Duration(seconds: 35),
    this.maxHistoryFrames = 6,
    this.maxCamerasPerSweep = 6,
    this.discoveryProbeLimit = 3,
    this.sceneChangeThreshold = 0.14,
  });

  MonitoringWatchContinuousVisualScopeSnapshot? snapshotForScope(
    String clientId,
    String siteId,
  ) {
    final scopeKey = '${clientId.trim()}|${siteId.trim()}';
    return _snapshotFor(scopeKey);
  }

  void clearScope(String clientId, String siteId) {
    final scopeKey = '${clientId.trim()}|${siteId.trim()}';
    _stateByScope.remove(scopeKey);
  }

  Future<MonitoringWatchContinuousVisualSweepResult?> sweepScope({
    required DvrScopeConfig scope,
    Iterable<IntelligenceReceived> recentIntelligence =
        const <IntelligenceReceived>[],
    DateTime? nowUtc,
  }) async {
    final baseUri = scope.eventsUri;
    final profile = DvrProviderProfile.fromProvider(scope.provider);
    if (baseUri == null || profile == null) {
      return null;
    }
    final scopeKey = scope.scopeKey;
    final state = _stateByScope.putIfAbsent(
      scopeKey,
      () => _ContinuousVisualScopeState(scopeKey: scopeKey),
    );
    final resolvedNowUtc = (nowUtc ?? DateTime.now()).toUtc();
    final auth = DvrHttpAuthConfig(
      mode: parseDvrHttpAuthMode(scope.authMode),
      bearerToken: scope.bearerToken.trim().isEmpty ? null : scope.bearerToken,
      username: scope.username.trim().isEmpty ? null : scope.username,
      password: scope.password.isEmpty ? null : scope.password,
    );

    final candidates = <MonitoringWatchContinuousVisualCandidate>[];
    var sampledCameraCount = 0;
    var reachableCameraCount = 0;
    var baselineReadyCameraCount = 0;
    var emittedCandidateCount = 0;
    var lastError = '';

    final knownCameraIds = state.cameras.keys.toSet();
    final orderedChannelIds = _candidateChannelIds(
      scope,
      recentIntelligence: recentIntelligence,
      knownCameraIds: knownCameraIds,
    );
    final preferredCameraIds = orderedChannelIds
        .take(maxCamerasPerSweep)
        .toSet();
    final discoveryChannelIds = orderedChannelIds
        .where((channelId) => !preferredCameraIds.contains(channelId))
        .take(discoveryProbeLimit)
        .toList(growable: false);
    final sweepChannelIds = <String>[
      ...preferredCameraIds,
      ...discoveryChannelIds,
    ];

    for (final channelId in sweepChannelIds) {
      final snapshotUrl = profile.buildSnapshotUrl(
        baseUri,
        'continuous-watch',
        channelId: channelId,
      );
      if (snapshotUrl == null || snapshotUrl.trim().isEmpty) {
        continue;
      }
      final snapshotUri = Uri.tryParse(snapshotUrl);
      if (snapshotUri == null) {
        continue;
      }
      final cameraId = _cameraIdForChannel(channelId);
      final cameraLabel = _cameraLabelFor(scope, cameraId, channelId);
      final zoneProfile = _zoneWatchProfileForCameraLabel(cameraLabel);
      final zoneLabel = zoneProfile.zoneLabel;
      sampledCameraCount += 1;
      try {
        final response = await auth
            .get(
              client,
              snapshotUri,
              headers: const <String, String>{
                'Accept': 'image/jpeg, image/*;q=0.9, */*;q=0.1',
              },
            )
            .timeout(requestTimeout);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          final existingCameraState = state.cameras[cameraId];
          if (existingCameraState != null) {
            _applyTransientCameraError(
              existingCameraState,
              'Snapshot HTTP ${response.statusCode}',
            );
            lastError = existingCameraState.lastError;
          } else {
            lastError = 'Snapshot HTTP ${response.statusCode}';
          }
          continue;
        }
        final frame = _decodeFrameFingerprint(response.bodyBytes);
        if (frame == null) {
          final existingCameraState = state.cameras[cameraId];
          if (existingCameraState != null) {
            _applyTransientCameraError(
              existingCameraState,
              'Snapshot decode failed.',
            );
            lastError = existingCameraState.lastError;
          } else {
            lastError = 'Snapshot decode failed.';
          }
          continue;
        }
        final cameraState = state.cameras.putIfAbsent(
          cameraId,
          () => _ContinuousVisualCameraState(cameraId: cameraId),
        );
        cameraState.snapshotUri = snapshotUri;
        cameraState.cameraLabel = cameraLabel;
        cameraState.zoneLabel = zoneLabel;
        cameraState.areaLabel = zoneProfile.areaLabel;
        cameraState.watchRuleKey = zoneProfile.ruleKey;
        cameraState.watchPriorityLabel = zoneProfile.priorityLabel;

        if (cameraState.lastSampledAtUtc != null &&
            resolvedNowUtc.difference(cameraState.lastSampledAtUtc!).abs() >
                staleBaselineAfter) {
          cameraState.history.clear();
          cameraState.lastSceneDeltaScore = null;
          cameraState.changeStreakCount = 0;
          cameraState.lastKnownGoodStreak = 0;
          cameraState.changeActiveSinceUtc = null;
          cameraState.changeStage =
              MonitoringWatchContinuousVisualChangeStage.idle;
          cameraState.lastEmittedChangeStage =
              MonitoringWatchContinuousVisualChangeStage.idle;
        }

        cameraState.reachable = true;
        cameraState.lastError = '';
        cameraState.lastFingerprint = frame.digest;
        cameraState.lastSampledAtUtc = resolvedNowUtc;
        reachableCameraCount += 1;
        final baseline = _baselineFingerprint(cameraState.history);
        final baselineReady = baseline != null;
        if (baselineReady) {
          baselineReadyCameraCount += 1;
        }
        final deltaScore = baseline == null
            ? null
            : _sceneDeltaScore(frame.luminance, baseline);
        cameraState.lastSceneDeltaScore = deltaScore;
        final aboveThreshold =
            deltaScore != null && deltaScore >= sceneChangeThreshold;
        if (aboveThreshold) {
          cameraState.changeActiveSinceUtc ??= resolvedNowUtc;
          cameraState.changeStreakCount += 1;
          cameraState.lastKnownGoodStreak = cameraState.changeStreakCount;
        } else {
          cameraState.changeActiveSinceUtc = null;
          cameraState.changeStreakCount = 0;
          cameraState.lastKnownGoodStreak = 0;
          cameraState.lastEmittedChangeStage =
              MonitoringWatchContinuousVisualChangeStage.idle;
        }
        final changeStage = _changeStageFor(
          streakCount: cameraState.changeStreakCount,
          changeActiveSinceUtc: cameraState.changeActiveSinceUtc,
          nowUtc: resolvedNowUtc,
          zoneLabel: zoneLabel,
        );
        cameraState.changeStage = changeStage;

        final shouldEmitCandidate =
            aboveThreshold &&
            _shouldEmitCandidateForStage(
              cameraState: cameraState,
              nowUtc: resolvedNowUtc,
            );
        if (shouldEmitCandidate) {
          final record = _candidateRecord(
            scope: scope,
            cameraId: cameraId,
            cameraLabel: cameraLabel,
            channelId: channelId,
            snapshotUri: snapshotUri,
            occurredAtUtc: resolvedNowUtc,
            sceneDeltaScore: deltaScore,
            changeStreakCount: cameraState.changeStreakCount,
            changeStage: changeStage,
            changeActiveSinceUtc: cameraState.changeActiveSinceUtc,
            zoneProfile: zoneProfile,
          );
          candidates.add(
            MonitoringWatchContinuousVisualCandidate(
              cameraId: cameraId,
              snapshotUri: snapshotUri,
              occurredAtUtc: resolvedNowUtc,
              sceneDeltaScore: deltaScore,
              record: record,
            ),
          );
          cameraState.lastCandidateAtUtc = resolvedNowUtc;
          cameraState.lastEmittedChangeStage = changeStage;
          state.lastCandidateAtUtc = resolvedNowUtc;
          emittedCandidateCount += 1;
        }

        cameraState.history.add(frame);
        while (cameraState.history.length > maxHistoryFrames) {
          cameraState.history.removeAt(0);
        }
      } catch (error) {
        final existingCameraState = state.cameras[cameraId];
        if (existingCameraState != null) {
          _applyTransientCameraError(existingCameraState, error.toString());
          lastError = existingCameraState.lastError;
        } else {
          lastError = error.toString();
        }
      }
    }

    final hotCamera = _hotCameraState(state.cameras.values);
    final correlatedGroup = _correlatedGroup(state.cameras.values);
    final watchPosture = _watchPostureFor(
      correlatedGroup: correlatedGroup,
      hotCamera: hotCamera,
    );
    state.lastSweepAtUtc = resolvedNowUtc;
    state.lastError = lastError;
    state.lastEmittedCandidateCount = emittedCandidateCount;
    state.lastStatus = _resolveStatus(
      reachableCameraCount: reachableCameraCount,
      baselineReadyCameraCount: baselineReadyCameraCount,
      emittedCandidateCount: emittedCandidateCount,
      lastError: lastError,
    );
    state.lastSummary = _summaryFor(
      status: state.lastStatus,
      sampledCameraCount: sampledCameraCount,
      reachableCameraCount: reachableCameraCount,
      baselineReadyCameraCount: baselineReadyCameraCount,
      emittedCandidateCount: emittedCandidateCount,
      hotCameraLabel: hotCamera?.cameraLabel ?? hotCamera?.cameraId,
      hotZoneLabel: hotCamera?.zoneLabel,
      hotAreaLabel: hotCamera?.areaLabel,
      hotWatchPriorityLabel: hotCamera?.watchPriorityLabel,
      hotCameraChangeStreakCount: hotCamera?.changeStreakCount ?? 0,
      hotCameraChangeStage: hotCamera?.changeStage,
      hotCameraChangeActiveSinceUtc: hotCamera?.changeActiveSinceUtc,
      hotCameraSceneDeltaScore: hotCamera?.lastSceneDeltaScore,
      correlatedGroup: correlatedGroup,
      watchPosture: watchPosture,
      nowUtc: resolvedNowUtc,
      lastError: lastError,
    );

    return MonitoringWatchContinuousVisualSweepResult(
      snapshot: _snapshotFor(scopeKey)!,
      candidates: candidates,
    );
  }

  MonitoringWatchContinuousVisualScopeSnapshot? _snapshotFor(String scopeKey) {
    final state = _stateByScope[scopeKey];
    if (state == null) {
      return null;
    }
    final cameras = state.cameras.values.toList(growable: false)
      ..sort((a, b) => a.cameraId.compareTo(b.cameraId));
    final reachableCameraCount = cameras
        .where((camera) => camera.reachable)
        .length;
    final baselineReadyCameraCount = cameras
        .where((camera) => camera.history.length >= minBaselineFrames)
        .length;
    final hotCamera = _hotCameraState(cameras);
    final correlatedGroup = _correlatedGroup(cameras);
    final watchPosture = _watchPostureFor(
      correlatedGroup: correlatedGroup,
      hotCamera: hotCamera,
    );
    return MonitoringWatchContinuousVisualScopeSnapshot(
      scopeKey: scopeKey,
      status: state.lastStatus,
      lastSweepAtUtc: state.lastSweepAtUtc,
      lastCandidateAtUtc: state.lastCandidateAtUtc,
      sampledCameraCount: cameras.length,
      reachableCameraCount: reachableCameraCount,
      baselineReadyCameraCount: baselineReadyCameraCount,
      emittedCandidateCount: state.lastEmittedCandidateCount,
      hotCameraId: hotCamera?.cameraId,
      hotCameraLabel: hotCamera?.cameraLabel,
      hotZoneLabel: hotCamera?.zoneLabel,
      hotAreaLabel: hotCamera?.areaLabel,
      hotWatchRuleKey: hotCamera?.watchRuleKey,
      hotWatchPriorityLabel: hotCamera?.watchPriorityLabel,
      hotCameraChangeStreakCount: hotCamera?.changeStreakCount,
      hotCameraChangeStage: hotCamera?.changeStage,
      hotCameraChangeActiveSinceUtc: hotCamera?.changeActiveSinceUtc,
      hotCameraSceneDeltaScore: hotCamera?.lastSceneDeltaScore,
      correlatedContextLabel: correlatedGroup?.contextLabel,
      correlatedAreaLabel: correlatedGroup?.areaLabel,
      correlatedZoneLabel: correlatedGroup?.zoneLabel,
      correlatedWatchRuleKey: correlatedGroup?.watchRuleKey,
      correlatedWatchPriorityLabel: correlatedGroup?.watchPriorityLabel,
      correlatedChangeStage: correlatedGroup?.changeStage,
      correlatedActiveSinceUtc: correlatedGroup?.activeSinceUtc,
      correlatedCameraCount: correlatedGroup?.cameraCount,
      correlatedCameraLabels: correlatedGroup?.cameraLabels ?? const <String>[],
      watchPostureKey: watchPosture?.key,
      watchPostureLabel: watchPosture?.label,
      watchAttentionLabel: watchPosture?.attentionLabel,
      watchSourceLabel: watchPosture?.sourceLabel,
      summary: state.lastSummary,
      lastError: state.lastError,
      cameras: cameras
          .map(
            (camera) => MonitoringWatchContinuousVisualCameraSnapshot(
              cameraId: camera.cameraId,
              cameraLabel: camera.cameraLabel,
              zoneLabel: camera.zoneLabel,
              areaLabel: camera.areaLabel,
              watchRuleKey: camera.watchRuleKey,
              watchPriorityLabel: camera.watchPriorityLabel,
              snapshotUri: camera.snapshotUri ?? Uri(),
              reachable: camera.reachable,
              baselineReady: camera.history.length >= minBaselineFrames,
              lastSampledAtUtc: camera.lastSampledAtUtc,
              lastCandidateAtUtc: camera.lastCandidateAtUtc,
              changeActiveSinceUtc: camera.changeActiveSinceUtc,
              changeStreakCount: camera.changeStreakCount,
              changeStage: camera.changeStage,
              lastSceneDeltaScore: camera.lastSceneDeltaScore,
              lastFingerprint: camera.lastFingerprint,
              lastError: camera.lastError,
            ),
          )
          .where((camera) => camera.snapshotUri.toString().trim().isNotEmpty)
          .toList(growable: false),
    );
  }

  MonitoringWatchContinuousVisualStatus _resolveStatus({
    required int reachableCameraCount,
    required int baselineReadyCameraCount,
    required int emittedCandidateCount,
    required String lastError,
  }) {
    if (emittedCandidateCount > 0) {
      return MonitoringWatchContinuousVisualStatus.alerting;
    }
    if (reachableCameraCount <= 0 && lastError.trim().isNotEmpty) {
      return MonitoringWatchContinuousVisualStatus.degraded;
    }
    if (baselineReadyCameraCount > 0) {
      return MonitoringWatchContinuousVisualStatus.active;
    }
    if (reachableCameraCount > 0) {
      return MonitoringWatchContinuousVisualStatus.learning;
    }
    return MonitoringWatchContinuousVisualStatus.inactive;
  }

  String _summaryFor({
    required MonitoringWatchContinuousVisualStatus status,
    required int sampledCameraCount,
    required int reachableCameraCount,
    required int baselineReadyCameraCount,
    required int emittedCandidateCount,
    required String? hotCameraLabel,
    required String? hotZoneLabel,
    required String? hotAreaLabel,
    required String? hotWatchPriorityLabel,
    required int hotCameraChangeStreakCount,
    required MonitoringWatchContinuousVisualChangeStage? hotCameraChangeStage,
    required DateTime? hotCameraChangeActiveSinceUtc,
    required double? hotCameraSceneDeltaScore,
    required _ZoneCorrelationGroup? correlatedGroup,
    required _WatchPosture? watchPosture,
    required DateTime nowUtc,
    required String lastError,
  }) {
    final trackedCameraLabel = (hotCameraLabel ?? '').trim();
    final trackedZoneLabel = (hotZoneLabel ?? '').trim();
    final trackedAreaLabel = (hotAreaLabel ?? '').trim();
    final trackedPriorityLabel = (hotWatchPriorityLabel ?? '').trim();
    final trackedContext = _zoneContextLabel(
      cameraLabel: trackedCameraLabel,
      zoneLabel: trackedZoneLabel,
      areaLabel: trackedAreaLabel,
    );
    final trackedPriorityPrefix = trackedPriorityLabel.isEmpty
        ? ''
        : '${trackedPriorityLabel.toLowerCase()}-priority ';
    final trackedScoreLabel = hotCameraSceneDeltaScore == null
        ? ''
        : ' (delta ${(hotCameraSceneDeltaScore * 100).round()}%)';
    final trackedDurationLabel = _changeDurationLabel(
      hotCameraChangeActiveSinceUtc,
      nowUtc: nowUtc,
    );
    final correlatedSummary = _correlatedSummaryLine(
      group: correlatedGroup,
      watchPosture: watchPosture,
      status: status,
      nowUtc: nowUtc,
    );
    if (correlatedSummary.isNotEmpty) {
      return correlatedSummary;
    }
    final postureLabel = (watchPosture?.label ?? '').trim().toLowerCase();
    if (postureLabel.isNotEmpty && trackedCameraLabel.isNotEmpty) {
      return switch (status) {
        MonitoringWatchContinuousVisualStatus.alerting =>
          hotCameraChangeStage ==
                  MonitoringWatchContinuousVisualChangeStage.persistent
              ? 'Continuous visual watch flagged a persistent $trackedPriorityPrefix$postureLabel $trackedContext${trackedDurationLabel.isEmpty ? '' : ' over $trackedDurationLabel'}$trackedScoreLabel.'
              : hotCameraChangeStage ==
                    MonitoringWatchContinuousVisualChangeStage.sustained
              ? 'Continuous visual watch flagged a sustained $trackedPriorityPrefix$postureLabel $trackedContext after $hotCameraChangeStreakCount consecutive sweeps$trackedScoreLabel.'
              : 'Continuous visual watch is tracking a fresh $trackedPriorityPrefix$postureLabel $trackedContext (${hotCameraChangeStreakCount.toString()}/$minConsecutiveChangeSweeps sweeps)$trackedScoreLabel before escalation.',
        MonitoringWatchContinuousVisualStatus.active =>
          hotCameraChangeStage ==
                  MonitoringWatchContinuousVisualChangeStage.persistent
              ? 'Continuous visual watch still sees a persistent $trackedPriorityPrefix$postureLabel $trackedContext${trackedDurationLabel.isEmpty ? '' : ' for $trackedDurationLabel'}$trackedScoreLabel.'
              : hotCameraChangeStage ==
                    MonitoringWatchContinuousVisualChangeStage.sustained
              ? 'Continuous visual watch still sees a sustained $trackedPriorityPrefix$postureLabel $trackedContext${trackedDurationLabel.isEmpty ? '' : ' for $trackedDurationLabel'}$trackedScoreLabel.'
              : 'Continuous visual watch is tracking a fresh $trackedPriorityPrefix$postureLabel $trackedContext (${hotCameraChangeStreakCount.toString()}/$minConsecutiveChangeSweeps sweeps)$trackedScoreLabel before escalation.',
        _ => '',
      };
    }
    return switch (status) {
      MonitoringWatchContinuousVisualStatus.alerting =>
        trackedCameraLabel.isNotEmpty &&
                hotCameraChangeStage ==
                    MonitoringWatchContinuousVisualChangeStage.persistent
            ? 'Continuous visual watch flagged a persistent ${trackedPriorityPrefix}scene deviation $trackedContext after $hotCameraChangeStreakCount consecutive sweeps${trackedDurationLabel.isEmpty ? '' : ' over $trackedDurationLabel'}$trackedScoreLabel.'
            : trackedCameraLabel.isNotEmpty
            ? 'Continuous visual watch flagged a sustained ${trackedPriorityPrefix}scene change $trackedContext after $hotCameraChangeStreakCount consecutive sweeps$trackedScoreLabel.'
            : 'Continuous visual watch flagged $emittedCandidateCount material ${emittedCandidateCount == 1 ? 'scene change' : 'scene changes'} on the latest sweep.',
      MonitoringWatchContinuousVisualStatus.active =>
        trackedCameraLabel.isNotEmpty &&
                hotCameraChangeStage ==
                    MonitoringWatchContinuousVisualChangeStage.persistent
            ? 'Continuous visual watch still sees a persistent ${trackedPriorityPrefix}scene deviation $trackedContext${trackedDurationLabel.isEmpty ? '' : ' for $trackedDurationLabel'}$trackedScoreLabel.'
            : trackedCameraLabel.isNotEmpty &&
                  hotCameraChangeStage ==
                      MonitoringWatchContinuousVisualChangeStage.sustained
            ? 'Continuous visual watch still sees a sustained ${trackedPriorityPrefix}scene change $trackedContext${trackedDurationLabel.isEmpty ? '' : ' for $trackedDurationLabel'}$trackedScoreLabel.'
            : trackedCameraLabel.isNotEmpty && hotCameraChangeStreakCount > 0
            ? 'Continuous visual watch is tracking a fresh ${trackedPriorityPrefix}scene change $trackedContext (${hotCameraChangeStreakCount.toString()}/$minConsecutiveChangeSweeps sweeps)$trackedScoreLabel before escalation.'
            : 'Continuous visual watch is sampling $reachableCameraCount ${reachableCameraCount == 1 ? 'camera view' : 'camera views'} against a rolling scene baseline.',
      MonitoringWatchContinuousVisualStatus.learning =>
        'Continuous visual watch is sampling $reachableCameraCount ${reachableCameraCount == 1 ? 'camera view' : 'camera views'} while the baseline is still forming.',
      MonitoringWatchContinuousVisualStatus.degraded =>
        lastError.trim().isEmpty
            ? 'Continuous visual watch could not verify fresh frames on the latest sweep.'
            : 'Continuous visual watch could not verify fresh frames on the latest sweep: ${lastError.trim()}',
      MonitoringWatchContinuousVisualStatus.inactive =>
        sampledCameraCount > 0
            ? 'Continuous visual watch has not confirmed a usable baseline yet.'
            : 'Continuous visual watch is idle for this scope.',
    };
  }

  bool _candidateCooldownSatisfied({
    required DateTime? lastCandidateAtUtc,
    required DateTime nowUtc,
  }) {
    if (lastCandidateAtUtc == null) {
      return true;
    }
    return nowUtc.difference(lastCandidateAtUtc).abs() >= candidateCooldown;
  }

  bool _shouldEmitCandidateForStage({
    required _ContinuousVisualCameraState cameraState,
    required DateTime nowUtc,
  }) {
    if (cameraState.changeStage.index <
        MonitoringWatchContinuousVisualChangeStage.sustained.index) {
      return false;
    }
    if (!_candidateCooldownSatisfied(
      lastCandidateAtUtc: cameraState.lastCandidateAtUtc,
      nowUtc: nowUtc,
    )) {
      return false;
    }
    return cameraState.lastEmittedChangeStage.index <
        cameraState.changeStage.index;
  }

  NormalizedIntelRecord _candidateRecord({
    required DvrScopeConfig scope,
    required String cameraId,
    required String cameraLabel,
    required String channelId,
    required Uri snapshotUri,
    required DateTime occurredAtUtc,
    required double sceneDeltaScore,
    required int changeStreakCount,
    required MonitoringWatchContinuousVisualChangeStage changeStage,
    required DateTime? changeActiveSinceUtc,
    required _ZoneWatchProfile zoneProfile,
  }) {
    final zoneRiskBoost = zoneProfile.priorityRiskBoost;
    final stageRiskBoost = switch (changeStage) {
      MonitoringWatchContinuousVisualChangeStage.persistent => 10,
      MonitoringWatchContinuousVisualChangeStage.sustained => 4,
      _ => 0,
    };
    final durationRiskBoost = _durationRiskBoost(
      changeActiveSinceUtc,
      occurredAtUtc,
      zoneProfile.zoneLabel,
    );
    final riskScore =
        (38 +
                (sceneDeltaScore * 120).round() +
                ((changeStreakCount - minConsecutiveChangeSweeps).clamp(0, 4) *
                    4) +
                zoneRiskBoost +
                stageRiskBoost +
                durationRiskBoost)
            .clamp(38, 86);
    final zonePrefix = zoneProfile.zoneLabel.trim().isEmpty
        ? ''
        : '${zoneProfile.zoneLabel.trim().toLowerCase()} ';
    final durationLabel = _changeDurationLabel(
      changeActiveSinceUtc,
      nowUtc: occurredAtUtc,
    );
    final objectLabel =
        changeStage == MonitoringWatchContinuousVisualChangeStage.persistent
        ? 'persistent_scene_change'
        : 'scene_change';
    final stageLabel =
        changeStage == MonitoringWatchContinuousVisualChangeStage.persistent
        ? 'persistent scene deviation'
        : 'sustained scene change';
    final contextSuffix = _zoneContextSuffix(
      cameraLabel: cameraLabel,
      zoneLabel: zoneProfile.zoneLabel,
      areaLabel: zoneProfile.areaLabel,
    );
    return NormalizedIntelRecord(
      provider: scope.provider.trim(),
      sourceType: 'dvr',
      externalId:
          'continuous-watch-$channelId-${occurredAtUtc.millisecondsSinceEpoch}',
      clientId: scope.clientId.trim(),
      regionId: scope.regionId.trim(),
      siteId: scope.siteId.trim(),
      cameraId: cameraId,
      zone: zoneProfile.areaLabel.trim().isNotEmpty
          ? zoneProfile.areaLabel.trim()
          : zoneProfile.zoneLabel.trim().isNotEmpty
          ? zoneProfile.zoneLabel.trim()
          : (cameraLabel == cameraId ? null : cameraLabel),
      objectLabel: objectLabel,
      objectConfidence: sceneDeltaScore.clamp(0, 1),
      headline:
          'Continuous visual watch flagged $zonePrefix$stageLabel$contextSuffix',
      summary:
          'A $zonePrefix$stageLabel$contextSuffix was detected across $changeStreakCount consecutive sweeps${durationLabel.isEmpty ? '' : ' over $durationLabel'} compared with the recent rolling baseline.',
      riskScore: riskScore,
      occurredAtUtc: occurredAtUtc,
      snapshotUrl: snapshotUri.toString(),
    );
  }

  String _cameraLabelFor(
    DvrScopeConfig scope,
    String cameraId,
    String channelId,
  ) {
    final direct = scope.cameraLabels[cameraId.trim().toLowerCase()];
    if ((direct ?? '').trim().isNotEmpty) {
      return direct!.trim();
    }
    final byChannel = scope.cameraLabels[channelId.trim().toLowerCase()];
    if ((byChannel ?? '').trim().isNotEmpty) {
      return byChannel!.trim();
    }
    return 'Camera $channelId';
  }

  _ZoneWatchProfile _zoneWatchProfileForCameraLabel(String label) {
    final normalized = label.trim().toLowerCase();
    String zoneLabel = '';
    String areaLabel = '';
    String ruleKey = '';
    String priorityLabel = '';
    int priorityRiskBoost = 0;

    String extractAreaLabel() {
      final patterns = <RegExp>[
        RegExp(
          r'(north gate|south gate|east gate|west gate|front gate|rear gate|back gate|main gate|pedestrian gate|driveway gate|garage gate)',
          caseSensitive: false,
        ),
        RegExp(
          r'(driveway|courtyard|garden|yard|patio|pool|parking|carport|boundary wall|front entrance|rear entrance|main entrance|service entrance)',
          caseSensitive: false,
        ),
      ];
      for (final pattern in patterns) {
        final match = pattern.firstMatch(label);
        if (match != null) {
          final raw = match.group(1)?.trim() ?? '';
          if (raw.isNotEmpty) {
            return _titleCase(raw);
          }
        }
      }
      if (label.trim().isEmpty ||
          label.trim().toLowerCase().startsWith('camera ')) {
        return '';
      }
      return label.trim();
    }

    if (normalized.contains('perimeter') ||
        normalized.contains('boundary') ||
        normalized.contains('fence')) {
      zoneLabel = 'Perimeter';
      priorityLabel = 'High';
      priorityRiskBoost = 8;
      ruleKey = 'perimeter_watch';
      areaLabel = extractAreaLabel();
    } else if (normalized.contains('gate') ||
        normalized.contains('entry') ||
        normalized.contains('entrance') ||
        normalized.contains('door')) {
      zoneLabel = 'Entry';
      priorityLabel = 'High';
      priorityRiskBoost = 7;
      ruleKey = 'entry_watch';
      areaLabel = extractAreaLabel();
    } else if (normalized.contains('outdoor') ||
        normalized.contains('yard') ||
        normalized.contains('garden') ||
        normalized.contains('driveway') ||
        normalized.contains('parking') ||
        normalized.contains('carport') ||
        normalized.contains('pool') ||
        normalized.contains('courtyard')) {
      zoneLabel = 'Outdoor';
      priorityLabel = 'Medium';
      priorityRiskBoost = 4;
      ruleKey = 'outdoor_watch';
      areaLabel = extractAreaLabel();
    } else {
      areaLabel = extractAreaLabel();
      if (areaLabel.isNotEmpty) {
        ruleKey = 'named_camera_watch';
        priorityLabel = 'Medium';
        priorityRiskBoost = 2;
      }
    }

    return _ZoneWatchProfile(
      zoneLabel: zoneLabel,
      areaLabel: areaLabel,
      ruleKey: ruleKey,
      priorityLabel: priorityLabel,
      priorityRiskBoost: priorityRiskBoost,
    );
  }

  int _durationRiskBoost(
    DateTime? changeActiveSinceUtc,
    DateTime nowUtc,
    String? zoneLabel,
  ) {
    if (changeActiveSinceUtc == null) {
      return 0;
    }
    final duration = nowUtc.difference(changeActiveSinceUtc).abs();
    final persistentAfter = _persistentChangeAfterFor(zoneLabel);
    if (duration >= persistentAfter * 2) {
      return 8;
    }
    if (duration >= persistentAfter) {
      return 4;
    }
    return 0;
  }

  String _zoneContextLabel({
    required String cameraLabel,
    required String zoneLabel,
    required String areaLabel,
  }) {
    if (areaLabel.isNotEmpty) {
      if (zoneLabel.isNotEmpty) {
        return 'near $areaLabel ($zoneLabel)';
      }
      return 'near $areaLabel';
    }
    if (zoneLabel.isNotEmpty) {
      return 'at the $zoneLabel';
    }
    return 'on $cameraLabel';
  }

  String _zoneContextSuffix({
    required String cameraLabel,
    required String zoneLabel,
    required String areaLabel,
  }) {
    final label = _zoneContextLabel(
      cameraLabel: cameraLabel,
      zoneLabel: zoneLabel,
      areaLabel: areaLabel,
    );
    if (label.startsWith('near ') || label.startsWith('at the ')) {
      return ' $label';
    }
    return ' on $cameraLabel';
  }

  String _correlatedSummaryLine({
    required _ZoneCorrelationGroup? group,
    required _WatchPosture? watchPosture,
    required MonitoringWatchContinuousVisualStatus status,
    required DateTime nowUtc,
  }) {
    if (group == null) {
      return '';
    }
    final postureLabel = (watchPosture?.label ?? 'Scene change')
        .trim()
        .toLowerCase();
    final priorityPrefix = group.watchPriorityLabel.trim().isEmpty
        ? ''
        : '${group.watchPriorityLabel.trim().toLowerCase()}-priority ';
    final durationLabel = _changeDurationLabel(
      group.activeSinceUtc,
      nowUtc: nowUtc,
    );
    final context = group.areaLabel.trim().isNotEmpty
        ? 'near ${group.areaLabel.trim()}'
        : group.zoneLabel.trim().isNotEmpty
        ? 'at the ${group.zoneLabel.trim()}'
        : 'across ${group.cameraCount} cameras';
    final acrossLabel =
        'across ${group.cameraCount} ${group.cameraCount == 1 ? 'camera' : 'cameras'}';
    return switch (status) {
      MonitoringWatchContinuousVisualStatus.alerting =>
        group.changeStage ==
                MonitoringWatchContinuousVisualChangeStage.persistent
            ? 'Continuous visual watch flagged a persistent $priorityPrefix$postureLabel $context $acrossLabel${durationLabel.isEmpty ? '' : ' over $durationLabel'}.'
            : 'Continuous visual watch flagged a sustained $priorityPrefix$postureLabel $context $acrossLabel.',
      MonitoringWatchContinuousVisualStatus.active =>
        group.changeStage ==
                MonitoringWatchContinuousVisualChangeStage.persistent
            ? 'Continuous visual watch still sees a persistent $priorityPrefix$postureLabel $context $acrossLabel${durationLabel.isEmpty ? '' : ' for $durationLabel'}.'
            : 'Continuous visual watch still sees a sustained $priorityPrefix$postureLabel $context $acrossLabel${durationLabel.isEmpty ? '' : ' for $durationLabel'}.',
      _ => '',
    };
  }

  String _titleCase(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower.isEmpty) {
      return '';
    }
    final stopWords = <String>{'and', 'of', 'the'};
    return lower
        .split(RegExp(r'\s+'))
        .asMap()
        .entries
        .map((entry) {
          final token = entry.value;
          if (entry.key > 0 && stopWords.contains(token)) {
            return token;
          }
          return token[0].toUpperCase() + token.substring(1);
        })
        .join(' ');
  }

  List<String> _candidateChannelIds(
    DvrScopeConfig scope, {
    required Iterable<IntelligenceReceived> recentIntelligence,
    required Set<String> knownCameraIds,
  }) {
    final output = <String>[];
    final seen = <String>{};

    void addChannel(String raw) {
      final digits = RegExp(r'(\d+)').firstMatch(raw.trim())?.group(1) ?? '';
      final parsed = int.tryParse(digits);
      if (parsed == null || parsed <= 0) {
        return;
      }
      final normalized = '$parsed';
      if (seen.add(normalized)) {
        output.add(normalized);
      }
    }

    for (final cameraId in knownCameraIds) {
      addChannel(cameraId);
    }
    for (final cameraId in scope.cameraLabels.keys) {
      addChannel(cameraId);
    }
    final sortedRecent = recentIntelligence.toList(growable: false)
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    for (final event in sortedRecent) {
      addChannel(event.cameraId ?? '');
    }
    for (var channel = 1; channel <= 16; channel += 1) {
      addChannel('$channel');
    }
    return output;
  }

  _FrameFingerprint? _decodeFrameFingerprint(List<int> bytes) {
    if (bytes.isEmpty) {
      return null;
    }
    final decoded = img.decodeImage(Uint8List.fromList(bytes));
    if (decoded == null) {
      return null;
    }
    final resized = img.copyResize(
      decoded,
      width: 24,
      height: 24,
      interpolation: img.Interpolation.average,
    );
    final luminance = <int>[];
    for (var y = 0; y < resized.height; y += 1) {
      for (var x = 0; x < resized.width; x += 1) {
        final pixel = resized.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        final value = ((0.299 * r) + (0.587 * g) + (0.114 * b)).round();
        luminance.add(value.clamp(0, 255));
      }
    }
    return _FrameFingerprint(
      luminance: luminance,
      digest: sha1.convert(luminance).toString(),
    );
  }

  List<int>? _baselineFingerprint(List<_FrameFingerprint> history) {
    if (history.length < minBaselineFrames) {
      return null;
    }
    final width = history.first.luminance.length;
    final medians = List<int>.filled(width, 0);
    for (var index = 0; index < width; index += 1) {
      final samples =
          history.map((frame) => frame.luminance[index]).toList(growable: false)
            ..sort();
      medians[index] = samples[samples.length ~/ 2].clamp(0, 255);
    }
    return medians;
  }

  double _sceneDeltaScore(List<int> current, List<int> baseline) {
    if (current.length != baseline.length || current.isEmpty) {
      return 0;
    }
    var total = 0.0;
    for (var index = 0; index < current.length; index += 1) {
      total += (current[index] - baseline[index]).abs() / 255.0;
    }
    return total / current.length;
  }

  String _cameraIdForChannel(String channelId) => 'channel-${channelId.trim()}';

  MonitoringWatchContinuousVisualChangeStage _changeStageFor({
    required int streakCount,
    required DateTime? changeActiveSinceUtc,
    required DateTime nowUtc,
    required String? zoneLabel,
  }) {
    if (streakCount <= 0 || changeActiveSinceUtc == null) {
      return MonitoringWatchContinuousVisualChangeStage.idle;
    }
    final duration = nowUtc.difference(changeActiveSinceUtc).abs();
    if (duration >= _persistentChangeAfterFor(zoneLabel) ||
        streakCount >= persistentChangeSweepThreshold) {
      return MonitoringWatchContinuousVisualChangeStage.persistent;
    }
    if (streakCount >= minConsecutiveChangeSweeps) {
      return MonitoringWatchContinuousVisualChangeStage.sustained;
    }
    return MonitoringWatchContinuousVisualChangeStage.watching;
  }

  void _applyTransientCameraError(
    _ContinuousVisualCameraState cameraState,
    String error,
  ) {
    cameraState.reachable = false;
    cameraState.lastSceneDeltaScore = null;
    cameraState.changeStreakCount = cameraState.lastKnownGoodStreak;
    cameraState.lastError = error;
  }

  Duration _persistentChangeAfterFor(String? zoneLabel) {
    return switch ((zoneLabel ?? '').trim().toLowerCase()) {
      'perimeter' => perimeterPersistentChangeAfter,
      'entry' => perimeterPersistentChangeAfter,
      'outdoor' => outdoorPersistentChangeAfter,
      _ => persistentChangeAfter,
    };
  }

  String _changeDurationLabel(
    DateTime? changeActiveSinceUtc, {
    required DateTime nowUtc,
  }) {
    if (changeActiveSinceUtc == null) {
      return '';
    }
    final duration = nowUtc.difference(changeActiveSinceUtc).abs();
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds}s';
    }
    if (duration.inMinutes < 60) {
      final seconds = duration.inSeconds % 60;
      return seconds == 0
          ? '${duration.inMinutes}m'
          : '${duration.inMinutes}m ${seconds}s';
    }
    final minutes = duration.inMinutes % 60;
    return minutes == 0
        ? '${duration.inHours}h'
        : '${duration.inHours}h ${minutes}m';
  }

  _ContinuousVisualCameraState? _hotCameraState(
    Iterable<_ContinuousVisualCameraState> cameras,
  ) {
    final ranked =
        cameras
            .where(
              (camera) =>
                  camera.lastSceneDeltaScore != null ||
                  camera.changeStreakCount > 0,
            )
            .toList(growable: false)
          ..sort((a, b) {
            final stageCompare = b.changeStage.index.compareTo(
              a.changeStage.index,
            );
            if (stageCompare != 0) {
              return stageCompare;
            }
            final streakCompare = b.changeStreakCount.compareTo(
              a.changeStreakCount,
            );
            if (streakCompare != 0) {
              return streakCompare;
            }
            final scoreCompare = (b.lastSceneDeltaScore ?? 0).compareTo(
              a.lastSceneDeltaScore ?? 0,
            );
            if (scoreCompare != 0) {
              return scoreCompare;
            }
            return (b.lastSampledAtUtc ??
                    DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(
                  a.lastSampledAtUtc ?? DateTime.fromMillisecondsSinceEpoch(0),
                );
          });
    return ranked.isEmpty ? null : ranked.first;
  }

  _ZoneCorrelationGroup? _correlatedGroup(
    Iterable<_ContinuousVisualCameraState> cameras,
  ) {
    final groups = <String, List<_ContinuousVisualCameraState>>{};
    for (final camera in cameras) {
      if (!camera.reachable) {
        continue;
      }
      if (camera.changeStage.index <
          MonitoringWatchContinuousVisualChangeStage.sustained.index) {
        continue;
      }
      final areaLabel = (camera.areaLabel ?? '').trim();
      final zoneLabel = (camera.zoneLabel ?? '').trim();
      final key = areaLabel.isNotEmpty
          ? 'area:${areaLabel.toLowerCase()}'
          : zoneLabel.isNotEmpty
          ? 'zone:${zoneLabel.toLowerCase()}'
          : '';
      if (key.isEmpty) {
        continue;
      }
      groups
          .putIfAbsent(key, () => <_ContinuousVisualCameraState>[])
          .add(camera);
    }

    final correlated =
        groups.entries
            .where((entry) => entry.value.length >= 2)
            .map((entry) => _buildCorrelationGroup(entry.value))
            .whereType<_ZoneCorrelationGroup>()
            .toList(growable: false)
          ..sort((left, right) {
            final stageCompare = right.changeStage.index.compareTo(
              left.changeStage.index,
            );
            if (stageCompare != 0) {
              return stageCompare;
            }
            final priorityCompare = right.priorityRiskBoost.compareTo(
              left.priorityRiskBoost,
            );
            if (priorityCompare != 0) {
              return priorityCompare;
            }
            final countCompare = right.cameraCount.compareTo(left.cameraCount);
            if (countCompare != 0) {
              return countCompare;
            }
            return (left.activeSinceUtc ??
                    DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(
                  right.activeSinceUtc ??
                      DateTime.fromMillisecondsSinceEpoch(0),
                );
          });
    return correlated.isEmpty ? null : correlated.first;
  }

  _WatchPosture? _watchPostureFor({
    required _ZoneCorrelationGroup? correlatedGroup,
    required _ContinuousVisualCameraState? hotCamera,
  }) {
    if (correlatedGroup != null) {
      return _buildWatchPosture(
        zoneLabel: correlatedGroup.zoneLabel,
        areaLabel: correlatedGroup.areaLabel,
        watchRuleKey: correlatedGroup.watchRuleKey,
        watchPriorityLabel: correlatedGroup.watchPriorityLabel,
        changeStage: correlatedGroup.changeStage,
        cameraCount: correlatedGroup.cameraCount,
        sourceLabel: 'cross_camera',
      );
    }
    if (hotCamera == null) {
      return null;
    }
    return _buildWatchPosture(
      zoneLabel: hotCamera.zoneLabel ?? '',
      areaLabel: hotCamera.areaLabel ?? '',
      watchRuleKey: hotCamera.watchRuleKey ?? '',
      watchPriorityLabel: hotCamera.watchPriorityLabel ?? '',
      changeStage: hotCamera.changeStage,
      cameraCount: 1,
      sourceLabel: 'single_camera',
    );
  }

  _WatchPosture? _buildWatchPosture({
    required String zoneLabel,
    required String areaLabel,
    required String watchRuleKey,
    required String watchPriorityLabel,
    required MonitoringWatchContinuousVisualChangeStage changeStage,
    required int cameraCount,
    required String sourceLabel,
  }) {
    final descriptor = _watchPostureDescriptorFor(
      zoneLabel: zoneLabel,
      areaLabel: areaLabel,
      watchRuleKey: watchRuleKey,
    );
    if (descriptor == null) {
      return null;
    }
    return _WatchPosture(
      key: descriptor.key,
      label: descriptor.label,
      attentionLabel: _watchAttentionLabelFor(
        stage: changeStage,
        priorityLabel: watchPriorityLabel,
        cameraCount: cameraCount,
      ),
      sourceLabel: sourceLabel,
    );
  }

  _WatchPostureDescriptor? _watchPostureDescriptorFor({
    required String zoneLabel,
    required String areaLabel,
    required String watchRuleKey,
  }) {
    final normalizedRule = watchRuleKey.trim().toLowerCase();
    final normalizedZone = zoneLabel.trim().toLowerCase();
    if (normalizedRule == 'perimeter_watch' || normalizedZone == 'perimeter') {
      return const _WatchPostureDescriptor(
        key: 'perimeter_pressure',
        label: 'Perimeter pressure',
      );
    }
    if (normalizedRule == 'entry_watch' || normalizedZone == 'entry') {
      return const _WatchPostureDescriptor(
        key: 'entry_pressure',
        label: 'Entry pressure',
      );
    }
    if (normalizedRule == 'outdoor_watch' || normalizedZone == 'outdoor') {
      return const _WatchPostureDescriptor(
        key: 'outdoor_pressure',
        label: 'Outdoor pressure',
      );
    }
    if (normalizedRule == 'named_camera_watch' || areaLabel.trim().isNotEmpty) {
      return const _WatchPostureDescriptor(
        key: 'area_pressure',
        label: 'Area pressure',
      );
    }
    return null;
  }

  String _watchAttentionLabelFor({
    required MonitoringWatchContinuousVisualChangeStage stage,
    required String priorityLabel,
    required int cameraCount,
  }) {
    final normalizedPriority = priorityLabel.trim().toLowerCase();
    final score =
        stage.index +
        (cameraCount >= 2 ? 1 : 0) +
        (normalizedPriority == 'high' ? 1 : 0);
    if (score >= 5) {
      return 'urgent';
    }
    if (score >= 4) {
      return 'high';
    }
    if (score >= 3) {
      return 'elevated';
    }
    return 'watch';
  }

  _ZoneCorrelationGroup? _buildCorrelationGroup(
    List<_ContinuousVisualCameraState> cameras,
  ) {
    if (cameras.length < 2) {
      return null;
    }
    final first = cameras.first;
    final areaLabel = (first.areaLabel ?? '').trim();
    final zoneLabel = (first.zoneLabel ?? '').trim();
    final watchRuleKey = (first.watchRuleKey ?? '').trim();
    final watchPriorityLabel = (first.watchPriorityLabel ?? '').trim();
    final changeStage = cameras
        .map((camera) => camera.changeStage)
        .reduce((left, right) => left.index <= right.index ? left : right);
    final activeSinceUtc = cameras
        .map((camera) => camera.changeActiveSinceUtc)
        .whereType<DateTime>()
        .fold<DateTime?>(
          null,
          (latest, value) =>
              latest == null || value.isAfter(latest) ? value : latest,
        );
    final cameraLabels =
        cameras
            .map((camera) => camera.cameraLabel.trim())
            .where((label) => label.isNotEmpty)
            .toList(growable: false)
          ..sort();
    return _ZoneCorrelationGroup(
      contextLabel: areaLabel.isNotEmpty ? areaLabel : zoneLabel,
      areaLabel: areaLabel,
      zoneLabel: zoneLabel,
      watchRuleKey: watchRuleKey,
      watchPriorityLabel: watchPriorityLabel,
      priorityRiskBoost: cameras
          .map((camera) => _priorityRiskBoostFor(camera.watchPriorityLabel))
          .fold<int>(0, (best, value) => value > best ? value : best),
      changeStage: changeStage,
      activeSinceUtc: activeSinceUtc,
      cameraCount: cameras.length,
      cameraLabels: cameraLabels,
    );
  }

  int _priorityRiskBoostFor(String? raw) {
    return switch ((raw ?? '').trim().toLowerCase()) {
      'high' => 8,
      'medium' => 4,
      'low' => 1,
      _ => 0,
    };
  }
}

class _ContinuousVisualScopeState {
  final String scopeKey;
  DateTime? lastSweepAtUtc;
  DateTime? lastCandidateAtUtc;
  String lastError = '';
  String lastSummary = '';
  int lastEmittedCandidateCount = 0;
  MonitoringWatchContinuousVisualStatus lastStatus =
      MonitoringWatchContinuousVisualStatus.inactive;
  final Map<String, _ContinuousVisualCameraState> cameras =
      <String, _ContinuousVisualCameraState>{};

  _ContinuousVisualScopeState({required this.scopeKey});
}

class _ContinuousVisualCameraState {
  final String cameraId;
  Uri? snapshotUri;
  String cameraLabel = '';
  String? zoneLabel;
  String? areaLabel;
  String? watchRuleKey;
  String? watchPriorityLabel;
  bool reachable = false;
  DateTime? lastSampledAtUtc;
  DateTime? lastCandidateAtUtc;
  DateTime? changeActiveSinceUtc;
  int changeStreakCount = 0;
  int lastKnownGoodStreak = 0;
  MonitoringWatchContinuousVisualChangeStage changeStage =
      MonitoringWatchContinuousVisualChangeStage.idle;
  MonitoringWatchContinuousVisualChangeStage lastEmittedChangeStage =
      MonitoringWatchContinuousVisualChangeStage.idle;
  double? lastSceneDeltaScore;
  String lastFingerprint = '';
  String lastError = '';
  final List<_FrameFingerprint> history = <_FrameFingerprint>[];

  _ContinuousVisualCameraState({required this.cameraId});
}

class _ZoneWatchProfile {
  final String zoneLabel;
  final String areaLabel;
  final String ruleKey;
  final String priorityLabel;
  final int priorityRiskBoost;

  const _ZoneWatchProfile({
    required this.zoneLabel,
    required this.areaLabel,
    required this.ruleKey,
    required this.priorityLabel,
    required this.priorityRiskBoost,
  });
}

class _ZoneCorrelationGroup {
  final String contextLabel;
  final String areaLabel;
  final String zoneLabel;
  final String watchRuleKey;
  final String watchPriorityLabel;
  final int priorityRiskBoost;
  final MonitoringWatchContinuousVisualChangeStage changeStage;
  final DateTime? activeSinceUtc;
  final int cameraCount;
  final List<String> cameraLabels;

  const _ZoneCorrelationGroup({
    required this.contextLabel,
    required this.areaLabel,
    required this.zoneLabel,
    required this.watchRuleKey,
    required this.watchPriorityLabel,
    required this.priorityRiskBoost,
    required this.changeStage,
    required this.activeSinceUtc,
    required this.cameraCount,
    required this.cameraLabels,
  });
}

class _WatchPostureDescriptor {
  final String key;
  final String label;

  const _WatchPostureDescriptor({required this.key, required this.label});
}

class _WatchPosture {
  final String key;
  final String label;
  final String attentionLabel;
  final String sourceLabel;

  const _WatchPosture({
    required this.key,
    required this.label,
    required this.attentionLabel,
    required this.sourceLabel,
  });
}

class _FrameFingerprint {
  final List<int> luminance;
  final String digest;

  const _FrameFingerprint({required this.luminance, required this.digest});
}
