import 'dart:convert';
import 'dart:io';

import 'package:omnix_dashboard/domain/authority/onyx_command_brain_contract.dart';
import 'package:omnix_dashboard/domain/authority/onyx_task_protocol.dart';

import 'scenario_definition.dart';
import 'scenario_result.dart';

enum ScenarioReplayHistorySignalScope {
  specialistDegradation,
  specialistConflict,
  specialistConstraint,
  sequenceFallback,
  replayBiasStackDrift,
}

class ScenarioReplayHistorySignal {
  const ScenarioReplayHistorySignal({
    required this.scenarioId,
    required this.scope,
    required this.trend,
    required this.message,
    required this.count,
    required this.baseSeverity,
    required this.effectiveSeverity,
    this.policyMatchType,
    this.policyMatchValue,
    this.policyMatchSource,
    this.latestSummary,
    this.latestSpecialist,
    this.latestTarget,
    this.latestSpecialists = const <String>[],
    this.latestTargets = const <String>[],
    this.latestStatuses = const <String>[],
    this.latestBiasSource,
    this.latestBiasScope,
    this.latestBiasSignature,
    this.latestBiasPolicySourceLabel,
    this.latestBranch,
    this.latestRestoredTarget,
    this.latestReplayBiasStackSignature,
    this.latestReplayBiasStackPosition,
    this.previousReplayBiasStackSignature,
  });

  final String scenarioId;
  final ScenarioReplayHistorySignalScope scope;
  final String trend;
  final String message;
  final int count;
  final String baseSeverity;
  final String effectiveSeverity;
  final String? policyMatchType;
  final String? policyMatchValue;
  final String? policyMatchSource;
  final String? latestSummary;
  final String? latestSpecialist;
  final String? latestTarget;
  final List<String> latestSpecialists;
  final List<String> latestTargets;
  final List<String> latestStatuses;
  final String? latestBiasSource;
  final String? latestBiasScope;
  final String? latestBiasSignature;
  final String? latestBiasPolicySourceLabel;
  final String? latestBranch;
  final String? latestRestoredTarget;
  final String? latestReplayBiasStackSignature;
  final int? latestReplayBiasStackPosition;
  final String? previousReplayBiasStackSignature;

  bool get policyPromoted =>
      baseSeverity.trim().toLowerCase() !=
      effectiveSeverity.trim().toLowerCase();

  bool get policyEscalatedSequenceFallback =>
      scope == ScenarioReplayHistorySignalScope.sequenceFallback &&
      policyPromoted;

  String get commandSurfaceBiasLabel => policyEscalatedSequenceFallback
      ? 'replay policy escalation'
      : 'replay policy bias';

  int get commandSurfacePriorityRank {
    switch (scope) {
      case ScenarioReplayHistorySignalScope.specialistConstraint:
        return policyPromoted ? 50 : 30;
      case ScenarioReplayHistorySignalScope.specialistConflict:
        return policyPromoted ? 40 : 20;
      case ScenarioReplayHistorySignalScope.sequenceFallback:
        return policyPromoted ? 35 : 10;
      case ScenarioReplayHistorySignalScope.specialistDegradation:
        return policyPromoted ? 5 : 0;
      case ScenarioReplayHistorySignalScope.replayBiasStackDrift:
        return policyPromoted ? 2 : 1;
    }
  }

  bool get shouldBiasCommandSurface {
    switch (scope) {
      case ScenarioReplayHistorySignalScope.specialistConflict:
      case ScenarioReplayHistorySignalScope.specialistConstraint:
        return _signalSeverityRank(effectiveSeverity) >=
            _signalSeverityRank('medium');
      case ScenarioReplayHistorySignalScope.sequenceFallback:
        return latestBranch?.trim().toLowerCase() == 'active';
      case ScenarioReplayHistorySignalScope.specialistDegradation:
      case ScenarioReplayHistorySignalScope.replayBiasStackDrift:
        return false;
    }
  }

  OnyxToolTarget? get prioritizedTarget {
    if (!shouldBiasCommandSurface) {
      return null;
    }
    final explicitTarget = _toolTargetFromSignalValue(latestTarget);
    if (explicitTarget != null) {
      return explicitTarget;
    }
    final preferredTargets = latestTargets
        .map(_toolTargetFromSignalValue)
        .whereType<OnyxToolTarget>()
        .toList(growable: false);
    if (preferredTargets.contains(OnyxToolTarget.cctvReview)) {
      return OnyxToolTarget.cctvReview;
    }
    if (preferredTargets.contains(OnyxToolTarget.dispatchBoard)) {
      return OnyxToolTarget.dispatchBoard;
    }
    if (preferredTargets.isNotEmpty) {
      return preferredTargets.first;
    }
    return switch (scope) {
      ScenarioReplayHistorySignalScope.specialistConflict =>
        OnyxToolTarget.cctvReview,
      ScenarioReplayHistorySignalScope.specialistConstraint =>
        OnyxToolTarget.dispatchBoard,
      ScenarioReplayHistorySignalScope.sequenceFallback =>
        OnyxToolTarget.tacticalTrack,
      ScenarioReplayHistorySignalScope.specialistDegradation => null,
      ScenarioReplayHistorySignalScope.replayBiasStackDrift => null,
    };
  }

  String get severityPhrase {
    final normalizedBaseSeverity = baseSeverity.trim().toLowerCase();
    final normalizedEffectiveSeverity = effectiveSeverity.trim().toLowerCase();
    if (!policyPromoted) {
      return normalizedEffectiveSeverity;
    }
    return 'promoted $normalizedBaseSeverity -> $normalizedEffectiveSeverity';
  }

  String? get policySourceLabel {
    switch ((policyMatchSource ?? '').trim().toLowerCase()) {
      case 'default':
        return 'default policy';
      case 'category':
        return 'category policy';
      case 'scenario_id':
        return 'scenario policy';
      case 'scenario_set':
        return 'scenario set policy';
      case 'scenario_set_category':
        return 'scenario set/category policy';
      case 'scenario_set_scenario_id':
        return 'scenario set/scenario policy';
    }
    return null;
  }

  String get scopeLabel {
    switch (scope) {
      case ScenarioReplayHistorySignalScope.specialistDegradation:
        return 'specialist degradation';
      case ScenarioReplayHistorySignalScope.specialistConflict:
        return 'specialist conflict';
      case ScenarioReplayHistorySignalScope.specialistConstraint:
        return 'specialist constraint';
      case ScenarioReplayHistorySignalScope.sequenceFallback:
        return 'sequence fallback';
      case ScenarioReplayHistorySignalScope.replayBiasStackDrift:
        return 'replay bias stack drift';
    }
  }

  String get operatorDetail {
    switch (scope) {
      case ScenarioReplayHistorySignalScope.specialistDegradation:
        if (latestStatuses.isNotEmpty) {
          return 'Latest degraded status ${latestStatuses.join(' | ')}.';
        }
        if (latestSpecialists.isNotEmpty) {
          return 'Latest degraded specialist ${latestSpecialists.join(' | ')}.';
        }
        return message;
      case ScenarioReplayHistorySignalScope.specialistConflict:
        if (latestSummary != null && latestSummary!.trim().isNotEmpty) {
          return latestSummary!.trim();
        }
        if (latestSpecialists.isNotEmpty || latestTargets.isNotEmpty) {
          final specialistSegment = latestSpecialists.isEmpty
              ? 'unknown'
              : latestSpecialists.join(' | ');
          final targetSegment = latestTargets.isEmpty
              ? 'unknown'
              : latestTargets.join(' | ');
          return 'Latest conflict picture $specialistSegment -> $targetSegment.';
        }
        return message;
      case ScenarioReplayHistorySignalScope.specialistConstraint:
        if (latestTarget != null && latestTarget!.trim().isNotEmpty) {
          final specialistSegment = latestSpecialist?.trim().isNotEmpty == true
              ? ' via ${latestSpecialist!.trim()}'
              : '';
          return 'Latest blocked target ${latestTarget!.trim()}$specialistSegment.';
        }
        return message;
      case ScenarioReplayHistorySignalScope.sequenceFallback:
        if (latestSummary != null && latestSummary!.trim().isNotEmpty) {
          return latestSummary!.trim();
        }
        if (latestRestoredTarget != null &&
            latestRestoredTarget!.trim().isNotEmpty) {
          final restoredDesk = _toolTargetLabelFromSignalValue(
            latestRestoredTarget,
          );
          if (restoredDesk != null) {
            return '$restoredDesk is back in front after the replay fallback cleared.';
          }
        }
        if (latestTarget != null && latestTarget!.trim().isNotEmpty) {
          final fallbackDesk = _toolTargetLabelFromSignalValue(latestTarget);
          if (fallbackDesk != null &&
              latestBranch?.trim().toLowerCase() == 'active') {
            return 'Latest fallback target $fallbackDesk.';
          }
          return 'Latest fallback target ${latestTarget!.trim()}.';
        }
        return message;
      case ScenarioReplayHistorySignalScope.replayBiasStackDrift:
        if (latestSummary != null && latestSummary!.trim().isNotEmpty) {
          return latestSummary!.trim();
        }
        return message;
    }
  }

  String get operatorSummary {
    if (scope == ScenarioReplayHistorySignalScope.sequenceFallback &&
        latestBranch?.trim().toLowerCase() == 'clean') {
      final detail = operatorDetail.trim();
      if (detail.isEmpty) {
        return 'Replay history: sequence fallback cleared.';
      }
      return 'Replay history: sequence fallback cleared. $detail';
    }
    final policySourceSuffix = policyPromoted && policySourceLabel != null
        ? ' via ${policySourceLabel!}'
        : '';
    final detail = operatorDetail.trim();
    final lead =
        'Replay history: $scopeLabel $severityPhrase$policySourceSuffix.';
    if (detail.isEmpty) {
      return lead;
    }
    return '$lead $detail';
  }

  BrainDecisionBias? toBrainDecisionBias() {
    final target = prioritizedTarget;
    if (!shouldBiasCommandSurface ||
        target == null ||
        scope == ScenarioReplayHistorySignalScope.replayBiasStackDrift) {
      return null;
    }
    return BrainDecisionBias(
      source: BrainDecisionBiasSource.replayPolicy,
      scope: switch (scope) {
        ScenarioReplayHistorySignalScope.specialistDegradation =>
          BrainDecisionBiasScope.specialistDegradation,
        ScenarioReplayHistorySignalScope.specialistConflict =>
          BrainDecisionBiasScope.specialistConflict,
        ScenarioReplayHistorySignalScope.specialistConstraint =>
          BrainDecisionBiasScope.specialistConstraint,
        ScenarioReplayHistorySignalScope.sequenceFallback =>
          BrainDecisionBiasScope.sequenceFallback,
        ScenarioReplayHistorySignalScope.replayBiasStackDrift =>
          BrainDecisionBiasScope.sequenceFallback,
      },
      preferredTarget: target,
      summary: operatorSummary,
      baseSeverity: baseSeverity,
      effectiveSeverity: effectiveSeverity,
      policySourceLabel: policySourceLabel ?? '',
    );
  }
}

abstract class ScenarioReplayHistorySignalService {
  const ScenarioReplayHistorySignalService();

  Future<List<ScenarioReplayHistorySignal>> loadSignalStack({int limit = 3});

  Future<ScenarioReplayHistorySignal?> loadTopSignal() async {
    final stack = await loadSignalStack(limit: 1);
    if (stack.isEmpty) {
      return null;
    }
    return stack.first;
  }
}

class LocalScenarioReplayHistorySignalService
    extends ScenarioReplayHistorySignalService {
  const LocalScenarioReplayHistorySignalService({
    this.workspaceRootPath,
    this.scenarioRootPath = 'simulations/scenarios',
    this.historyResultsRootPath = 'simulations/results/history',
    this.policyPath = 'simulations/scenario_policy.json',
  });

  final String? workspaceRootPath;
  final String scenarioRootPath;
  final String historyResultsRootPath;
  final String policyPath;

  @override
  Future<List<ScenarioReplayHistorySignal>> loadSignalStack({
    int limit = 3,
  }) async {
    final workspaceRoot = workspaceRootPath ?? Directory.current.path;
    final scenarioPaths = _resolveScenarioPaths(
      workspaceRoot: workspaceRoot,
      targetPath: scenarioRootPath,
    );
    if (scenarioPaths.isEmpty) {
      return const <ScenarioReplayHistorySignal>[];
    }
    final scenarioMetadataByScenarioId = await _loadScenarioMetadataById(
      scenarioPaths,
    );
    if (scenarioMetadataByScenarioId.isEmpty) {
      return const <ScenarioReplayHistorySignal>[];
    }
    final historyRecords = await _loadHistoryRecords(
      workspaceRoot: workspaceRoot,
      historyResultsRootPath: historyResultsRootPath,
      scenarioMetadataByScenarioId: scenarioMetadataByScenarioId,
    );
    if (historyRecords.isEmpty) {
      return const <ScenarioReplayHistorySignal>[];
    }

    final degradationSummary =
        _buildHistoryScenarioSpecialistDegradationSummary(historyRecords);
    final conflictSummary = _buildHistoryScenarioSpecialistConflictSummary(
      historyRecords,
    );
    final constraintSummary = _buildHistoryScenarioSpecialistConstraintSummary(
      historyRecords,
    );
    final sequenceFallbackSummary =
        _buildHistoryScenarioSequenceFallbackSummary(historyRecords);
    final replayBiasStackDriftSummary =
        _buildHistoryScenarioReplayBiasStackDriftSummary(historyRecords);

    final alerts = <Map<String, dynamic>>[
      ..._buildSpecialistDegradationAlerts(
        degradationSummary,
        scenarioMetadataByScenarioId: scenarioMetadataByScenarioId,
      ),
      ..._buildSpecialistConflictAlerts(
        conflictSummary,
        scenarioMetadataByScenarioId: scenarioMetadataByScenarioId,
      ),
      ..._buildSpecialistConstraintAlerts(
        constraintSummary,
        scenarioMetadataByScenarioId: scenarioMetadataByScenarioId,
      ),
      ..._buildSequenceFallbackAlerts(
        sequenceFallbackSummary,
        scenarioMetadataByScenarioId: scenarioMetadataByScenarioId,
      ),
      ..._buildReplayBiasStackDriftAlerts(
        replayBiasStackDriftSummary,
        scenarioMetadataByScenarioId: scenarioMetadataByScenarioId,
      ),
    ];
    final orderedSignals = <Map<String, dynamic>>[];
    if (alerts.isNotEmpty) {
      final policy = await _loadAlertFailurePolicyMap(
        workspaceRoot: workspaceRoot,
        policyPath: policyPath,
      );
      final enrichedAlerts =
          alerts
              .map((alert) => _enrichAlertWithPolicySeverity(alert, policy))
              .toList(growable: false)
            ..sort(_compareReplayHistorySignals);
      orderedSignals.addAll(enrichedAlerts);
    } else {
      final recoverySignals = _buildSequenceFallbackRecoverySignals(
        sequenceFallbackSummary,
        scenarioMetadataByScenarioId: scenarioMetadataByScenarioId,
      )..sort(_compareReplayHistorySignals);
      orderedSignals.addAll(recoverySignals);
    }
    final expandedSignals = _expandLatestReplayBiasStackSignals(
      orderedSignals: orderedSignals,
      historyRecords: historyRecords,
      scenarioMetadataByScenarioId: scenarioMetadataByScenarioId,
    );
    if (expandedSignals.isEmpty) {
      return const <ScenarioReplayHistorySignal>[];
    }
    return expandedSignals
        .take(limit < 0 ? 0 : limit)
        .map(_signalFromMap)
        .toList(growable: false);
  }
}

ScenarioReplayHistorySignal _signalFromMap(Map<String, dynamic> rawSignal) {
  return ScenarioReplayHistorySignal(
    scenarioId: rawSignal['scenarioId']?.toString() ?? '',
    scope: _scopeFromName(rawSignal['scope']?.toString()),
    trend: rawSignal['trend']?.toString() ?? 'unknown',
    message: rawSignal['message']?.toString() ?? '',
    count: rawSignal['count'] is int ? rawSignal['count'] as int : 0,
    baseSeverity:
        rawSignal['baseSeverity']?.toString() ??
        rawSignal['severity']?.toString() ??
        'low',
    effectiveSeverity:
        rawSignal['effectiveSeverity']?.toString() ??
        rawSignal['severity']?.toString() ??
        'low',
    policyMatchType: rawSignal['effectiveSeverityPolicyMatchType']?.toString(),
    policyMatchValue: rawSignal['effectiveSeverityPolicyValue']?.toString(),
    policyMatchSource: rawSignal['effectiveSeverityPolicySource']?.toString(),
    latestSummary: rawSignal['latestSummary']?.toString(),
    latestSpecialist: rawSignal['latestSpecialist']?.toString(),
    latestTarget: rawSignal['latestTarget']?.toString(),
    latestSpecialists: _readNormalizedDynamicStringList(
      rawSignal['latestSpecialists'],
    ),
    latestTargets: _readNormalizedDynamicStringList(rawSignal['latestTargets']),
    latestStatuses: _readNormalizedDynamicStringList(
      rawSignal['latestStatuses'],
    ),
    latestBiasSource: rawSignal['latestBiasSource']?.toString(),
    latestBiasScope: rawSignal['latestBiasScope']?.toString(),
    latestBiasSignature: rawSignal['latestBiasSignature']?.toString(),
    latestBiasPolicySourceLabel: rawSignal['latestBiasPolicySourceLabel']
        ?.toString(),
    latestBranch: rawSignal['latestBranch']?.toString(),
    latestRestoredTarget: rawSignal['latestRestoredTarget']?.toString(),
    latestReplayBiasStackSignature: rawSignal['latestReplayBiasStackSignature']
        ?.toString(),
    latestReplayBiasStackPosition:
        rawSignal['latestReplayBiasStackPosition'] is int
        ? rawSignal['latestReplayBiasStackPosition'] as int
        : int.tryParse(
            rawSignal['latestReplayBiasStackPosition']?.toString() ?? '',
          ),
    previousReplayBiasStackSignature:
        rawSignal['previousReplayBiasStackSignature']?.toString(),
  );
}

String? summarizeReplayHistorySignalStack(
  List<ScenarioReplayHistorySignal> signals,
) {
  final hasStoredPositions = signals.any(
    (signal) => signal.latestReplayBiasStackPosition != null,
  );
  final orderedSignals = List<ScenarioReplayHistorySignal>.from(signals);
  if (hasStoredPositions) {
    orderedSignals.sort(_compareReplayHistorySignalSummaryOrder);
  }
  final normalizedSignals = orderedSignals
      .asMap()
      .entries
      .map((entry) {
        final signal = entry.value;
        final summary = signal.operatorSummary.trim();
        if (summary.isEmpty) {
          return '';
        }
        final position =
            signal.latestReplayBiasStackPosition ??
            (!hasStoredPositions && orderedSignals.length > 1
                ? entry.key
                : null);
        final label = _replayPressureSlotLabel(position);
        if (label == null) {
          return summary;
        }
        return '$label: $summary';
      })
      .where((summary) => summary.isNotEmpty)
      .toList(growable: false);
  if (normalizedSignals.isEmpty) {
    return null;
  }
  if (normalizedSignals.length == 1) {
    return normalizedSignals.first;
  }
  return normalizedSignals.join(' ');
}

int _compareReplayHistorySignalSummaryOrder(
  ScenarioReplayHistorySignal left,
  ScenarioReplayHistorySignal right,
) {
  final leftPosition = left.latestReplayBiasStackPosition;
  final rightPosition = right.latestReplayBiasStackPosition;
  if (leftPosition != null &&
      rightPosition != null &&
      leftPosition != rightPosition) {
    return leftPosition.compareTo(rightPosition);
  }
  if (leftPosition != null && rightPosition == null) {
    return -1;
  }
  if (leftPosition == null && rightPosition != null) {
    return 1;
  }
  return right.commandSurfacePriorityRank.compareTo(
    left.commandSurfacePriorityRank,
  );
}

String? _replayPressureSlotLabel(int? position) {
  switch (position) {
    case 0:
      return 'Primary replay pressure';
    case 1:
      return 'Secondary replay pressure';
    case 2:
      return 'Tertiary replay pressure';
  }
  if (position == null || position < 0) {
    return null;
  }
  return 'Replay pressure ${position + 1}';
}

ScenarioReplayHistorySignalScope _scopeFromName(String? rawScope) {
  switch ((rawScope ?? '').trim().toLowerCase()) {
    case 'replay_bias_stack_drift':
      return ScenarioReplayHistorySignalScope.replayBiasStackDrift;
    case 'sequence_fallback':
      return ScenarioReplayHistorySignalScope.sequenceFallback;
    case 'specialist_constraint':
      return ScenarioReplayHistorySignalScope.specialistConstraint;
    case 'specialist_conflict':
      return ScenarioReplayHistorySignalScope.specialistConflict;
    case 'specialist_degradation':
    default:
      return ScenarioReplayHistorySignalScope.specialistDegradation;
  }
}

List<String> _resolveScenarioPaths({
  required String workspaceRoot,
  required String targetPath,
}) {
  final resolvedTarget = _resolvePath(workspaceRoot, targetPath);
  final file = File(resolvedTarget);
  if (file.existsSync()) {
    if (!resolvedTarget.endsWith('.json')) {
      return const <String>[];
    }
    return <String>[resolvedTarget];
  }

  final directory = Directory(resolvedTarget);
  if (!directory.existsSync()) {
    return const <String>[];
  }

  final scenarioPaths =
      directory
          .listSync(recursive: true)
          .whereType<File>()
          .map((file) => file.path)
          .where((path) {
            final normalizedPath = path.replaceAll('\\', '/');
            return normalizedPath.endsWith('.json') &&
                normalizedPath.split('/').last.startsWith('scenario_');
          })
          .toList(growable: false)
        ..sort();
  return scenarioPaths;
}

String _resolvePath(String workspaceRoot, String targetPath) {
  if (targetPath.startsWith('/')) {
    return targetPath;
  }
  return '$workspaceRoot/$targetPath'.replaceAll('//', '/');
}

Future<Map<String, Map<String, dynamic>>> _loadScenarioMetadataById(
  List<String> scenarioPaths,
) async {
  final metadataByScenarioId = <String, Map<String, dynamic>>{};
  for (final scenarioPath in scenarioPaths) {
    final definition = ScenarioDefinition.fromJsonString(
      await File(scenarioPath).readAsString(),
    );
    metadataByScenarioId[definition.scenarioId] = <String, dynamic>{
      'category': definition.category,
      'scenarioSet': definition.scenarioSet,
      'status': definition.status,
      'tags': definition.tags,
    };
  }
  return metadataByScenarioId;
}

Future<List<Map<String, dynamic>>> _loadHistoryRecords({
  required String workspaceRoot,
  required String historyResultsRootPath,
  required Map<String, Map<String, dynamic>> scenarioMetadataByScenarioId,
}) async {
  final historyDirectory = Directory(
    _resolvePath(workspaceRoot, historyResultsRootPath),
  );
  if (!historyDirectory.existsSync()) {
    return const <Map<String, dynamic>>[];
  }
  final historyFiles =
      historyDirectory
          .listSync()
          .whereType<File>()
          .where((file) {
            final fileName = file.path.split('/').last;
            return fileName.startsWith('result_') && fileName.endsWith('.json');
          })
          .toList(growable: false)
        ..sort((left, right) => left.path.compareTo(right.path));

  final historyRecords = <Map<String, dynamic>>[];
  for (final historyFile in historyFiles) {
    final result = ScenarioResult.fromJsonString(
      await historyFile.readAsString(),
    );
    final metadata = scenarioMetadataByScenarioId[result.scenarioId];
    if (metadata == null) {
      continue;
    }
    final specialistDegradationRecord = _buildSpecialistDegradationRecord(
      result.actualOutcome,
    );
    final specialistConflictRecord = _buildSpecialistConflictRecord(
      result.actualOutcome,
    );
    final specialistConflictLifecycleRecord =
        _buildSpecialistConflictLifecycleRecord(result.actualOutcome);
    final specialistConstraintRecord = _buildSpecialistConstraintRecord(
      result.actualOutcome,
    );
    final specialistConstraintLifecycleRecord =
        _buildSpecialistConstraintLifecycleRecord(result.actualOutcome);
    final sequenceFallbackRecord = _buildSequenceFallbackRecord(
      result.actualOutcome,
    );
    final replayBiasStackRecord = _buildReplayBiasStackRecord(
      result.actualOutcome,
    );
    historyRecords.add(<String, dynamic>{
      'scenarioId': result.scenarioId,
      'category': metadata['category'],
      'scenarioSet': metadata['scenarioSet'],
      'status': metadata['status'],
      'tags': metadata['tags'],
      'runId': result.runId.toUtc().toIso8601String(),
      'actualRoute': result.actualOutcome.actualRoute,
      if (specialistDegradationRecord != null) ...specialistDegradationRecord,
      if (specialistConflictRecord != null) ...specialistConflictRecord,
      if (specialistConflictLifecycleRecord != null)
        ...specialistConflictLifecycleRecord,
      if (specialistConstraintRecord != null) ...specialistConstraintRecord,
      if (specialistConstraintLifecycleRecord != null)
        ...specialistConstraintLifecycleRecord,
      if (sequenceFallbackRecord != null) ...sequenceFallbackRecord,
      if (replayBiasStackRecord != null) ...replayBiasStackRecord,
    });
  }
  return historyRecords;
}

Map<String, dynamic>? _buildReplayBiasStackRecord(
  ScenarioActualOutcome actualOutcome,
) {
  final commandBrainSnapshot = actualOutcome.commandBrainSnapshot;
  final orderedReplayBiasStack =
      commandBrainSnapshot?.orderedReplayBiasStack ??
      const <BrainDecisionBias>[];
  if (orderedReplayBiasStack.isEmpty) {
    return null;
  }
  return <String, dynamic>{
    'commandBrainFinalReplayBiasStackLength': orderedReplayBiasStack.length,
    if (commandBrainSnapshot?.replayBiasStackSignature != null)
      'commandBrainFinalReplayBiasStackSignature':
          commandBrainSnapshot!.replayBiasStackSignature,
    'commandBrainFinalReplayBiasStackEntries': <Map<String, dynamic>>[
      for (var index = 0; index < orderedReplayBiasStack.length; index++)
        <String, dynamic>{
          'order': index,
          'source': orderedReplayBiasStack[index].source.name,
          'scope': orderedReplayBiasStack[index].scope.name,
          'preferredTarget': orderedReplayBiasStack[index].preferredTarget.name,
          'summary': orderedReplayBiasStack[index].summary,
          'signature':
              '${orderedReplayBiasStack[index].source.name}:${orderedReplayBiasStack[index].scope.name}',
          'stackSignatureSegment':
              orderedReplayBiasStack[index].stackSignatureSegment,
          if (orderedReplayBiasStack[index].baseSeverity.trim().isNotEmpty)
            'baseSeverity': orderedReplayBiasStack[index].baseSeverity.trim(),
          if (orderedReplayBiasStack[index].effectiveSeverity.trim().isNotEmpty)
            'effectiveSeverity': orderedReplayBiasStack[index].effectiveSeverity
                .trim(),
          if (orderedReplayBiasStack[index].policySourceLabel.trim().isNotEmpty)
            'policySourceLabel': orderedReplayBiasStack[index].policySourceLabel
                .trim(),
        },
    ],
  };
}

Map<String, dynamic>? _buildSequenceFallbackRecord(
  ScenarioActualOutcome actualOutcome,
) {
  final decisionBias = _resolveReplayBiasForScope(
    actualOutcome.commandBrainSnapshot,
    BrainDecisionBiasScope.sequenceFallback,
  );
  if (decisionBias == null) {
    return null;
  }
  return <String, dynamic>{
    'commandBrainFinalBiasSource': decisionBias.source.name,
    'commandBrainFinalBiasScope': decisionBias.scope.name,
    'commandBrainFinalBiasTarget': decisionBias.preferredTarget.name,
    'commandBrainFinalBiasSummary': _readNormalizedString(decisionBias.summary),
    'commandBrainFinalBiasSignature':
        '${decisionBias.source.name}:${decisionBias.scope.name}',
    if (decisionBias.policySourceLabel.trim().isNotEmpty)
      'commandBrainFinalBiasPolicySourceLabel': decisionBias.policySourceLabel
          .trim(),
  };
}

BrainDecisionBias? _resolveReplayBiasForScope(
  OnyxCommandBrainSnapshot? snapshot,
  BrainDecisionBiasScope scope,
) {
  if (snapshot == null) {
    return null;
  }
  for (final bias in snapshot.orderedReplayBiasStack) {
    if (bias.source == BrainDecisionBiasSource.replayPolicy &&
        bias.scope == scope) {
      return bias;
    }
  }
  return null;
}

Map<String, dynamic>? _buildSpecialistDegradationRecord(
  ScenarioActualOutcome actualOutcome,
) {
  final specialistStatuses = actualOutcome.actualUiState['specialistStatuses'];
  if (specialistStatuses is! Map) {
    return null;
  }

  final specialistNames = <String>[];
  final specialistStatusEntries = <String>[];
  for (final entry in specialistStatuses.entries) {
    final specialistName = entry.key?.toString().trim().toLowerCase();
    final statusValue = entry.value;
    if (specialistName == null ||
        specialistName.isEmpty ||
        statusValue is! Map) {
      continue;
    }
    final status = statusValue['status']?.toString().trim().toLowerCase();
    if (status == null || status.isEmpty) {
      continue;
    }
    specialistNames.add(specialistName);
    specialistStatusEntries.add('$specialistName:$status');
  }

  if (specialistStatusEntries.isEmpty) {
    return null;
  }

  specialistNames.sort();
  specialistStatusEntries.sort();
  final branch = _classifySpecialistDegradationBranch(actualOutcome.notes);
  return <String, dynamic>{
    'specialistDegradationBranch': branch,
    'specialistDegradationSpecialists': specialistNames,
    'specialistDegradationStatuses': specialistStatusEntries,
    'specialistDegradationSignature':
        '$branch:${specialistStatusEntries.join('|')}',
  };
}

String _classifySpecialistDegradationBranch(String notes) {
  final normalizedNotes = notes.trim().toLowerCase();
  if (normalizedNotes.contains('rerouted ')) {
    return 'recovered';
  }
  return 'persistent';
}

Map<String, dynamic>? _buildSpecialistConflictRecord(
  ScenarioActualOutcome actualOutcome,
) {
  final actualUiState = actualOutcome.actualUiState;
  if (actualUiState['specialistConflictVisible'] != true) {
    return null;
  }

  final specialists = _readNormalizedDynamicStringList(
    actualUiState['specialistConflictSpecialists'],
  );
  final targets = _readNormalizedDynamicStringList(
    actualUiState['specialistConflictTargets'],
  );
  final summary = _readNormalizedString(
    actualUiState['specialistConflictSummary'],
  );
  final signature = summary != null
      ? 'persistent:$summary'
      : 'persistent:${specialists.join('|')}=>${targets.join('|')}';
  return <String, dynamic>{
    'specialistConflictBranch': 'persistent',
    if (actualUiState['specialistConflictCount'] is int)
      'specialistConflictCount': actualUiState['specialistConflictCount'],
    if (specialists.isNotEmpty) 'specialistConflictSpecialists': specialists,
    if (targets.isNotEmpty) 'specialistConflictTargets': targets,
    'specialistConflictSummary': ?summary,
    'specialistConflictSignature': signature,
  };
}

Map<String, dynamic>? _buildSpecialistConstraintRecord(
  ScenarioActualOutcome actualOutcome,
) {
  final commandBrainSnapshot = actualOutcome.commandBrainSnapshot;
  final actualUiState = actualOutcome.actualUiState;
  final constraintVisible =
      actualUiState['specialistConstraintVisible'] == true ||
      commandBrainSnapshot?.mode == BrainDecisionMode.specialistConstraint;
  if (!constraintVisible) {
    return null;
  }

  final hardConstraintAssessment = _resolveHardConstraintAssessment(
    commandBrainSnapshot?.specialistAssessments ??
        const <SpecialistAssessment>[],
  );
  final allowRouteExecution = actualUiState['allowRouteExecution'] is bool
      ? actualUiState['allowRouteExecution'] as bool
      : hardConstraintAssessment?.allowRouteExecution ??
            commandBrainSnapshot?.allowRouteExecution ??
            true;
  final branch = allowRouteExecution ? 'constrained' : 'blocking';
  final specialist = hardConstraintAssessment?.specialist.name ?? 'unknown';
  final target =
      _readNormalizedString(actualUiState['constrainedTarget']) ??
      hardConstraintAssessment?.recommendedTarget?.name ??
      commandBrainSnapshot?.target.name ??
      'unknown';

  return <String, dynamic>{
    'specialistConstraintBranch': branch,
    'specialistConstraintAllowRouteExecution': allowRouteExecution,
    'specialistConstraintSpecialist': specialist,
    'specialistConstraintTarget': target,
    'specialistConstraintSignature': '$branch:$specialist:$target',
  };
}

Map<String, dynamic>? _buildSpecialistConflictLifecycleRecord(
  ScenarioActualOutcome actualOutcome,
) {
  String? summary;
  List<String> specialists = const <String>[];
  List<String> targets = const <String>[];
  String? clearedByStepId;

  for (final change in actualOutcome.actualProjectionChanges) {
    final keyedChange = _stringKeyedMapOrNull(change);
    if (keyedChange == null || keyedChange.isEmpty) {
      continue;
    }
    final step = _readNormalizedString(keyedChange['step']);
    if (step == 'specialist_conflict') {
      summary ??= _readNormalizedString(keyedChange['summary']);
      if (specialists.isEmpty) {
        specialists = _readNormalizedDynamicStringList(
          keyedChange['specialists'],
        );
      }
      if (targets.isEmpty) {
        targets = _readNormalizedDynamicStringList(
          keyedChange['recommendedTargets'],
        );
      }
    } else if (step == 'specialist_conflict_cleared') {
      clearedByStepId ??= _readNormalizedString(
        keyedChange['resolvedByStepId'],
      );
      summary ??= _readNormalizedString(keyedChange['summary']);
      if (specialists.isEmpty) {
        specialists = _readNormalizedDynamicStringList(
          keyedChange['specialists'],
        );
      }
      if (targets.isEmpty) {
        targets = _readNormalizedDynamicStringList(
          keyedChange['previousTargets'],
        );
      }
    }
  }

  if (summary == null && specialists.isEmpty && targets.isEmpty) {
    return null;
  }

  final lifecycle = clearedByStepId == null || clearedByStepId.isEmpty
      ? 'active_in_run'
      : 'recovered_in_run';
  return <String, dynamic>{
    'specialistConflictLifecycle': lifecycle,
    'specialistConflictLifecycleSummary': ?summary,
    if (specialists.isNotEmpty)
      'specialistConflictLifecycleSpecialists': specialists,
    if (targets.isNotEmpty) 'specialistConflictLifecycleTargets': targets,
    if (clearedByStepId != null && clearedByStepId.isNotEmpty)
      'specialistConflictRecoveryStage': clearedByStepId,
  };
}

Map<String, dynamic>? _buildSpecialistConstraintLifecycleRecord(
  ScenarioActualOutcome actualOutcome,
) {
  String? specialist;
  String? constrainedTarget;
  String? clearedByStepId;

  for (final change in actualOutcome.actualProjectionChanges) {
    final keyedChange = _stringKeyedMapOrNull(change);
    if (keyedChange == null || keyedChange.isEmpty) {
      continue;
    }
    final step = _readNormalizedString(keyedChange['step']);
    if (step == 'specialist_constraint') {
      specialist ??= _readNormalizedString(keyedChange['specialist']);
      constrainedTarget ??= _readNormalizedString(
        keyedChange['constrainedTarget'],
      );
    } else if (step == 'specialist_constraint_cleared') {
      clearedByStepId ??= _readNormalizedString(
        keyedChange['resolvedByStepId'],
      );
    }
  }

  if (specialist == null ||
      specialist.isEmpty ||
      constrainedTarget == null ||
      constrainedTarget.isEmpty) {
    return null;
  }

  final lifecycle = clearedByStepId == null || clearedByStepId.isEmpty
      ? 'active_in_run'
      : 'recovered_in_run';
  return <String, dynamic>{
    'specialistConstraintLifecycle': lifecycle,
    'specialistConstraintLifecycleSpecialist': specialist,
    'specialistConstraintLifecycleTarget': constrainedTarget,
    if (clearedByStepId != null && clearedByStepId.isNotEmpty)
      'specialistConstraintRecoveryStage': clearedByStepId,
  };
}

SpecialistAssessment? _resolveHardConstraintAssessment(
  List<SpecialistAssessment> assessments,
) {
  SpecialistAssessment? strongestConstraint;
  for (final assessment in assessments) {
    if (!assessment.isHardConstraint) {
      continue;
    }
    if (strongestConstraint == null ||
        assessment.confidence > strongestConstraint.confidence) {
      strongestConstraint = assessment;
    }
  }
  return strongestConstraint;
}

String? _readNormalizedString(Object? value) {
  final normalized = value?.toString().trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}

List<String> _readNormalizedDynamicStringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  final normalized = value
      .map(_readNormalizedString)
      .whereType<String>()
      .toList(growable: false);
  return normalized.isEmpty ? const <String>[] : normalized;
}

Map<String, dynamic>? _stringKeyedMapOrNull(Object? value) {
  if (value is! Map) {
    return null;
  }
  final keyedMap = <String, dynamic>{};
  for (final entry in value.entries) {
    final key = entry.key?.toString().trim();
    if (key == null || key.isEmpty) {
      continue;
    }
    keyedMap[key] = entry.value;
  }
  return keyedMap;
}

Map<String, Map<String, dynamic>>
_buildHistoryScenarioSpecialistDegradationSummary(
  List<Map<String, dynamic>> records,
) {
  final recordsByScenarioId = <String, List<Map<String, dynamic>>>{};
  for (final record in records) {
    final scenarioId = record['scenarioId']?.toString().trim();
    if (scenarioId == null || scenarioId.isEmpty) {
      continue;
    }
    recordsByScenarioId
        .putIfAbsent(scenarioId, () => <Map<String, dynamic>>[])
        .add(record);
  }

  final summary = <String, Map<String, dynamic>>{};
  for (final entry in recordsByScenarioId.entries) {
    final sortedRecords = List<Map<String, dynamic>>.from(entry.value)
      ..sort((left, right) {
        final leftRunId = left['runId']?.toString() ?? '';
        final rightRunId = right['runId']?.toString() ?? '';
        return leftRunId.compareTo(rightRunId);
      });
    final degradedRunCount = sortedRecords
        .where(
          (record) =>
              record['specialistDegradationBranch']
                  ?.toString()
                  .trim()
                  .isNotEmpty ==
              true,
        )
        .length;
    if (degradedRunCount == 0) {
      continue;
    }

    final persistentOutcomes = sortedRecords
        .map(
          (record) =>
              record['specialistDegradationBranch']?.toString().trim() ==
              'persistent',
        )
        .toList(growable: false);
    final persistentCount = persistentOutcomes.where((value) => value).length;
    final recoveredCount = sortedRecords
        .where(
          (record) =>
              record['specialistDegradationBranch']?.toString().trim() ==
              'recovered',
        )
        .length;
    final latestRecord = sortedRecords.last;
    final latestSpecialists =
        latestRecord['specialistDegradationSpecialists'] is List
        ? List<String>.from(
            latestRecord['specialistDegradationSpecialists'] as List,
          )
        : const <String>[];
    final latestStatuses = latestRecord['specialistDegradationStatuses'] is List
        ? List<String>.from(
            latestRecord['specialistDegradationStatuses'] as List,
          )
        : const <String>[];
    summary[entry.key] = <String, dynamic>{
      'persistentCount': persistentCount,
      'recoveredCount': recoveredCount,
      'latestBranch':
          latestRecord['specialistDegradationBranch']?.toString().trim() ??
          'clean',
      'trend': _buildHistoryFieldTrend(persistentOutcomes),
      if (latestRecord['specialistDegradationSignature'] != null)
        'latestSignature': latestRecord['specialistDegradationSignature'],
      if (latestSpecialists.isNotEmpty) 'latestSpecialists': latestSpecialists,
      if (latestStatuses.isNotEmpty) 'latestStatuses': latestStatuses,
    };
  }
  return summary;
}

Map<String, Map<String, dynamic>>
_buildHistoryScenarioSpecialistConflictSummary(
  List<Map<String, dynamic>> records,
) {
  final recordsByScenarioId = <String, List<Map<String, dynamic>>>{};
  for (final record in records) {
    final scenarioId = record['scenarioId']?.toString().trim();
    if (scenarioId == null || scenarioId.isEmpty) {
      continue;
    }
    recordsByScenarioId
        .putIfAbsent(scenarioId, () => <Map<String, dynamic>>[])
        .add(record);
  }

  final summary = <String, Map<String, dynamic>>{};
  for (final entry in recordsByScenarioId.entries) {
    final sortedRecords = List<Map<String, dynamic>>.from(entry.value)
      ..sort((left, right) {
        final leftRunId = left['runId']?.toString() ?? '';
        final rightRunId = right['runId']?.toString() ?? '';
        return leftRunId.compareTo(rightRunId);
      });
    final conflictRunCount = sortedRecords
        .where(
          (record) =>
              record['specialistConflictBranch']
                      ?.toString()
                      .trim()
                      .isNotEmpty ==
                  true ||
              record['specialistConflictLifecycle']
                      ?.toString()
                      .trim()
                      .isNotEmpty ==
                  true,
        )
        .length;
    if (conflictRunCount == 0) {
      continue;
    }

    final persistentOutcomes = sortedRecords
        .map(
          (record) =>
              record['specialistConflictBranch']?.toString().trim() ==
              'persistent',
        )
        .toList(growable: false);
    final persistentCount = persistentOutcomes.where((value) => value).length;
    final latestRecord = sortedRecords.last;
    final latestSummary =
        latestRecord['specialistConflictSummary'] ??
        latestRecord['specialistConflictLifecycleSummary'];
    final latestSpecialists =
        latestRecord['specialistConflictSpecialists'] is List
        ? List<String>.from(
            latestRecord['specialistConflictSpecialists'] as List,
          )
        : latestRecord['specialistConflictLifecycleSpecialists'] is List
        ? List<String>.from(
            latestRecord['specialistConflictLifecycleSpecialists'] as List,
          )
        : const <String>[];
    final latestTargets = latestRecord['specialistConflictTargets'] is List
        ? List<String>.from(latestRecord['specialistConflictTargets'] as List)
        : latestRecord['specialistConflictLifecycleTargets'] is List
        ? List<String>.from(
            latestRecord['specialistConflictLifecycleTargets'] as List,
          )
        : const <String>[];
    summary[entry.key] = <String, dynamic>{
      'persistentCount': persistentCount,
      'latestBranch':
          latestRecord['specialistConflictBranch']?.toString().trim() ??
          'clean',
      'trend': _buildHistoryFieldTrend(persistentOutcomes),
      'latestSummary': ?latestSummary,
      if (latestSpecialists.isNotEmpty) 'latestSpecialists': latestSpecialists,
      if (latestTargets.isNotEmpty) 'latestTargets': latestTargets,
      'latestSignature': ?latestRecord['specialistConflictSignature'],
    };
  }
  return summary;
}

Map<String, Map<String, dynamic>>
_buildHistoryScenarioSpecialistConstraintSummary(
  List<Map<String, dynamic>> records,
) {
  final recordsByScenarioId = <String, List<Map<String, dynamic>>>{};
  for (final record in records) {
    final scenarioId = record['scenarioId']?.toString().trim();
    if (scenarioId == null || scenarioId.isEmpty) {
      continue;
    }
    recordsByScenarioId
        .putIfAbsent(scenarioId, () => <Map<String, dynamic>>[])
        .add(record);
  }

  final summary = <String, Map<String, dynamic>>{};
  for (final entry in recordsByScenarioId.entries) {
    final sortedRecords = List<Map<String, dynamic>>.from(entry.value)
      ..sort((left, right) {
        final leftRunId = left['runId']?.toString() ?? '';
        final rightRunId = right['runId']?.toString() ?? '';
        return leftRunId.compareTo(rightRunId);
      });
    final constraintRunCount = sortedRecords
        .where(
          (record) =>
              record['specialistConstraintBranch']
                      ?.toString()
                      .trim()
                      .isNotEmpty ==
                  true ||
              record['specialistConstraintLifecycle']
                      ?.toString()
                      .trim()
                      .isNotEmpty ==
                  true,
        )
        .length;
    if (constraintRunCount == 0) {
      continue;
    }

    final blockingOutcomes = sortedRecords
        .map(
          (record) =>
              record['specialistConstraintBranch']?.toString().trim() ==
              'blocking',
        )
        .toList(growable: false);
    final blockingCount = blockingOutcomes.where((value) => value).length;
    final latestRecord = sortedRecords.last;
    final latestBranch =
        latestRecord['specialistConstraintBranch']?.toString().trim() ??
        'clean';
    final latestAllowRouteExecution =
        latestRecord['specialistConstraintAllowRouteExecution'] is bool
        ? latestRecord['specialistConstraintAllowRouteExecution'] as bool
        : latestBranch != 'blocking';
    final latestSpecialist =
        latestRecord['specialistConstraintSpecialist'] ??
        latestRecord['specialistConstraintLifecycleSpecialist'];
    final latestTarget =
        latestRecord['specialistConstraintTarget'] ??
        latestRecord['specialistConstraintLifecycleTarget'];
    summary[entry.key] = <String, dynamic>{
      'blockingCount': blockingCount,
      'latestBranch': latestBranch,
      'trend': _buildHistoryFieldTrend(blockingOutcomes),
      'latestAllowRouteExecution': latestAllowRouteExecution,
      if (latestRecord['specialistConstraintSignature'] != null)
        'latestSignature': latestRecord['specialistConstraintSignature'],
      'latestSpecialist': ?latestSpecialist,
      'latestTarget': ?latestTarget,
    };
  }
  return summary;
}

Map<String, Map<String, dynamic>> _buildHistoryScenarioSequenceFallbackSummary(
  List<Map<String, dynamic>> records,
) {
  final recordsByScenarioId = <String, List<Map<String, dynamic>>>{};
  for (final record in records) {
    final scenarioId = record['scenarioId']?.toString().trim();
    if (scenarioId == null || scenarioId.isEmpty) {
      continue;
    }
    recordsByScenarioId
        .putIfAbsent(scenarioId, () => <Map<String, dynamic>>[])
        .add(record);
  }

  final summary = <String, Map<String, dynamic>>{};
  for (final entry in recordsByScenarioId.entries) {
    final sortedRecords = List<Map<String, dynamic>>.from(entry.value)
      ..sort((left, right) {
        final leftRunId = left['runId']?.toString() ?? '';
        final rightRunId = right['runId']?.toString() ?? '';
        return leftRunId.compareTo(rightRunId);
      });
    final fallbackOutcomes = sortedRecords
        .map(
          (record) =>
              record['commandBrainFinalBiasScope']?.toString().trim() ==
              BrainDecisionBiasScope.sequenceFallback.name,
        )
        .toList(growable: false);
    final fallbackCount = fallbackOutcomes.where((value) => value).length;
    if (fallbackCount == 0) {
      continue;
    }
    final latestRecord = sortedRecords.last;
    final latestFallbackRecord = _latestRecordMatching(
      sortedRecords,
      (record) =>
          record['commandBrainFinalBiasScope']?.toString().trim() ==
          BrainDecisionBiasScope.sequenceFallback.name,
    );
    final latestFallbackBiasEntry = latestFallbackRecord == null
        ? null
        : _replayBiasEntryForScope(
            latestFallbackRecord,
            BrainDecisionBiasScope.sequenceFallback.name,
          );
    final latestBranch =
        latestRecord['commandBrainFinalBiasScope']?.toString().trim() ==
            BrainDecisionBiasScope.sequenceFallback.name
        ? 'active'
        : 'clean';
    final latestTarget = latestBranch == 'active'
        ? latestRecord['commandBrainFinalBiasTarget']?.toString()
        : latestRecord['actualRoute']?.toString();
    final latestRestoredTarget = latestBranch == 'clean'
        ? latestRecord['actualRoute']?.toString()
        : null;
    final latestSummary = latestBranch == 'active'
        ? latestRecord['commandBrainFinalBiasSummary']?.toString()
        : _buildSequenceFallbackRecoverySummary(
            restoredTarget: latestRestoredTarget,
            fallbackTarget: latestFallbackRecord?['commandBrainFinalBiasTarget']
                ?.toString(),
          );
    var clearedCount = 0;
    for (var index = 1; index < fallbackOutcomes.length; index++) {
      if (!fallbackOutcomes[index] && fallbackOutcomes[index - 1]) {
        clearedCount++;
      }
    }
    summary[entry.key] = <String, dynamic>{
      'count': fallbackCount,
      'clearedCount': clearedCount,
      'latestBranch': latestBranch,
      'trend': _buildHistoryFieldTrend(fallbackOutcomes),
      'latestTarget': ?latestTarget,
      'latestSummary': ?latestSummary,
      'latestRestoredTarget': ?latestRestoredTarget,
      if (latestFallbackRecord?['commandBrainFinalBiasSource'] != null)
        'latestBiasSource':
            latestFallbackRecord!['commandBrainFinalBiasSource'],
      if (latestFallbackRecord?['commandBrainFinalBiasScope'] != null)
        'latestBiasScope': latestFallbackRecord!['commandBrainFinalBiasScope'],
      if (latestFallbackRecord?['commandBrainFinalBiasSignature'] != null)
        'latestBiasSignature':
            latestFallbackRecord!['commandBrainFinalBiasSignature'],
      if (latestFallbackRecord?['commandBrainFinalBiasPolicySourceLabel'] !=
          null)
        'latestBiasPolicySourceLabel':
            latestFallbackRecord!['commandBrainFinalBiasPolicySourceLabel'],
      if (latestFallbackRecord?['commandBrainFinalReplayBiasStackSignature'] !=
          null)
        'latestReplayBiasStackSignature':
            latestFallbackRecord!['commandBrainFinalReplayBiasStackSignature'],
      if (latestFallbackBiasEntry?['order'] is int)
        'latestReplayBiasStackPosition': latestFallbackBiasEntry!['order'],
    };
  }
  return summary;
}

Map<String, Map<String, dynamic>>
_buildHistoryScenarioReplayBiasStackDriftSummary(
  List<Map<String, dynamic>> records,
) {
  final recordsByScenarioId = <String, List<Map<String, dynamic>>>{};
  for (final record in records) {
    final scenarioId = record['scenarioId']?.toString().trim();
    if (scenarioId == null || scenarioId.isEmpty) {
      continue;
    }
    recordsByScenarioId
        .putIfAbsent(scenarioId, () => <Map<String, dynamic>>[])
        .add(record);
  }

  final summary = <String, Map<String, dynamic>>{};
  for (final entry in recordsByScenarioId.entries) {
    final comparableRecords =
        List<Map<String, dynamic>>.from(entry.value)
          ..sort((left, right) {
            final leftRunId = left['runId']?.toString() ?? '';
            final rightRunId = right['runId']?.toString() ?? '';
            return leftRunId.compareTo(rightRunId);
          });
    comparableRecords.removeWhere(
      (record) =>
          _readNormalizedString(
            record['commandBrainFinalReplayBiasStackSignature'],
          ) ==
          null,
    );
    if (comparableRecords.length < 2) {
      continue;
    }

    final driftOutcomes = <bool>[false];
    var driftCount = 0;
    for (var index = 1; index < comparableRecords.length; index++) {
      final previousSignature = _readNormalizedString(
        comparableRecords[index - 1]['commandBrainFinalReplayBiasStackSignature'],
      );
      final latestSignature = _readNormalizedString(
        comparableRecords[index]['commandBrainFinalReplayBiasStackSignature'],
      );
      final drifted =
          previousSignature != null &&
          latestSignature != null &&
          previousSignature != latestSignature;
      driftOutcomes.add(drifted);
      if (drifted) {
        driftCount++;
      }
    }
    if (driftCount == 0) {
      continue;
    }

    final latestRecord = comparableRecords.last;
    final previousRecord = comparableRecords[comparableRecords.length - 2];
    final latestSignature = _readNormalizedString(
      latestRecord['commandBrainFinalReplayBiasStackSignature'],
    );
    final previousSignature = _readNormalizedString(
      previousRecord['commandBrainFinalReplayBiasStackSignature'],
    );
    final latestBranch =
        driftOutcomes.last && latestSignature != previousSignature
        ? 'drifted'
        : 'stable';
    summary[entry.key] = <String, dynamic>{
      'count': driftCount,
      'trend': _buildHistoryFieldTrend(driftOutcomes),
      'latestBranch': latestBranch,
      'latestReplayBiasStackSignature': ?latestSignature,
      'previousReplayBiasStackSignature': ?previousSignature,
      'latestSummary': _buildReplayBiasStackDriftSummary(
        previousEntries: _readReplayBiasEntryList(
          previousRecord['commandBrainFinalReplayBiasStackEntries'],
        ),
        latestEntries: _readReplayBiasEntryList(
          latestRecord['commandBrainFinalReplayBiasStackEntries'],
        ),
      ),
    };
  }
  return summary;
}

Map<String, dynamic>? _replayBiasEntryForScope(
  Map<String, dynamic> record,
  String biasScope,
) {
  for (final entry in _readReplayBiasEntryList(
    record['commandBrainFinalReplayBiasStackEntries'],
  )) {
    if (entry['scope']?.toString().trim() == biasScope) {
      return entry;
    }
  }
  return null;
}

List<Map<String, dynamic>> _expandLatestReplayBiasStackSignals({
  required List<Map<String, dynamic>> orderedSignals,
  required List<Map<String, dynamic>> historyRecords,
  required Map<String, Map<String, dynamic>> scenarioMetadataByScenarioId,
}) {
  if (orderedSignals.isEmpty) {
    return const <Map<String, dynamic>>[];
  }
  final primaryScenarioId = orderedSignals.first['scenarioId']
      ?.toString()
      .trim();
  if (primaryScenarioId == null || primaryScenarioId.isEmpty) {
    return orderedSignals;
  }
  final latestRecord = _latestRecordMatching(
    historyRecords,
    (record) => record['scenarioId']?.toString().trim() == primaryScenarioId,
  );
  if (latestRecord == null) {
    return orderedSignals;
  }
  final replayBiasEntries = _readReplayBiasEntryList(
    latestRecord['commandBrainFinalReplayBiasStackEntries'],
  );
  if (replayBiasEntries.length <= 1) {
    return orderedSignals;
  }
  final metadata = scenarioMetadataByScenarioId[primaryScenarioId];
  if (metadata == null) {
    return orderedSignals;
  }

  final stackSignals = <Map<String, dynamic>>[];
  for (final replayBiasEntry in replayBiasEntries) {
    final scopeName = _signalScopeNameFromBiasScope(
      replayBiasEntry['scope']?.toString(),
    );
    if (scopeName == null) {
      continue;
    }
    final matchingSignal = _firstSignalMatching(
      orderedSignals,
      scenarioId: primaryScenarioId,
      scope: scopeName,
    );
    final historySummary = _buildReplayBiasScopeHistorySummary(
      historyRecords: historyRecords,
      scenarioId: primaryScenarioId,
      biasScope: replayBiasEntry['scope']?.toString() ?? '',
    );
    stackSignals.add(
      _buildReplayBiasStackSignal(
        replayBiasEntry: replayBiasEntry,
        scenarioId: primaryScenarioId,
        metadata: metadata,
        latestRecord: latestRecord,
        matchingSignal: matchingSignal,
        historySummary: historySummary,
      ),
    );
  }
  if (stackSignals.isEmpty) {
    return orderedSignals;
  }

  return <Map<String, dynamic>>[
    ...stackSignals,
    ...orderedSignals.where((signal) {
      final scenarioId = signal['scenarioId']?.toString().trim();
      final scope = signal['scope']?.toString().trim();
      return !stackSignals.any(
        (stackSignal) =>
            stackSignal['scenarioId']?.toString().trim() == scenarioId &&
            stackSignal['scope']?.toString().trim() == scope,
      );
    }),
  ];
}

Map<String, dynamic>? _firstSignalMatching(
  List<Map<String, dynamic>> signals, {
  required String scenarioId,
  required String scope,
}) {
  for (final signal in signals) {
    if (signal['scenarioId']?.toString().trim() == scenarioId &&
        signal['scope']?.toString().trim() == scope) {
      return signal;
    }
  }
  return null;
}

Map<String, dynamic> _buildReplayBiasScopeHistorySummary({
  required List<Map<String, dynamic>> historyRecords,
  required String scenarioId,
  required String biasScope,
}) {
  final scopedRecords =
      historyRecords
          .where(
            (record) => record['scenarioId']?.toString().trim() == scenarioId,
          )
          .toList(growable: false)
        ..sort((left, right) {
          final leftRunId = left['runId']?.toString() ?? '';
          final rightRunId = right['runId']?.toString() ?? '';
          return leftRunId.compareTo(rightRunId);
        });
  final outcomes = scopedRecords
      .map((record) => _recordHasReplayBiasScope(record, biasScope))
      .toList(growable: false);
  final count = outcomes.where((value) => value).length;
  final latestBranch = outcomes.isNotEmpty && outcomes.last
      ? 'active'
      : 'clean';
  return <String, dynamic>{
    'count': count,
    'trend': _buildHistoryFieldTrend(outcomes),
    'latestBranch': latestBranch,
  };
}

bool _recordHasReplayBiasScope(Map<String, dynamic> record, String biasScope) {
  final normalizedScope = biasScope.trim();
  if (normalizedScope.isEmpty) {
    return false;
  }
  final replayBiasEntries = _readReplayBiasEntryList(
    record['commandBrainFinalReplayBiasStackEntries'],
  );
  return replayBiasEntries.any(
    (entry) => entry['scope']?.toString().trim() == normalizedScope,
  );
}

Map<String, dynamic> _buildReplayBiasStackSignal({
  required Map<String, dynamic> replayBiasEntry,
  required String scenarioId,
  required Map<String, dynamic> metadata,
  required Map<String, dynamic> latestRecord,
  required Map<String, dynamic>? matchingSignal,
  required Map<String, dynamic> historySummary,
}) {
  final scopeName = _signalScopeNameFromBiasScope(
    replayBiasEntry['scope']?.toString(),
  )!;
  final preferredTarget = replayBiasEntry['preferredTarget']?.toString().trim();
  final summary = _readNormalizedString(replayBiasEntry['summary']);
  final baseSeverity =
      _readNormalizedString(replayBiasEntry['baseSeverity']) ??
      matchingSignal?['baseSeverity']?.toString().trim() ??
      matchingSignal?['severity']?.toString().trim() ??
      'low';
  final effectiveSeverity =
      _readNormalizedString(replayBiasEntry['effectiveSeverity']) ??
      matchingSignal?['effectiveSeverity']?.toString().trim() ??
      baseSeverity;
  final signal = <String, dynamic>{
    'severity': matchingSignal?['severity'] ?? effectiveSeverity,
    'baseSeverity': baseSeverity,
    'effectiveSeverity': effectiveSeverity,
    'scope': scopeName,
    'scenarioId': scenarioId,
    'category': metadata['category'],
    'scenarioSet': metadata['scenarioSet'],
    'status': metadata['status'],
    'tags': metadata['tags'],
    'field':
        matchingSignal?['field'] ?? 'commandBrainFinalReplayBiasStackSignature',
    'trend': historySummary['trend'] ?? 'watch',
    'count': historySummary['count'] ?? 1,
    'latestBranch': historySummary['latestBranch'] ?? 'active',
    if (preferredTarget != null && preferredTarget.isNotEmpty)
      'latestTarget': preferredTarget,
    'latestSummary': ?summary,
    'latestBiasSource': replayBiasEntry['source'],
    'latestBiasScope': replayBiasEntry['scope'],
    'latestBiasSignature':
        replayBiasEntry['signature'] ??
        '${replayBiasEntry['source']}:${replayBiasEntry['scope']}',
    if (_readNormalizedString(replayBiasEntry['policySourceLabel']) != null)
      'latestBiasPolicySourceLabel': _readNormalizedString(
        replayBiasEntry['policySourceLabel'],
      ),
    if (latestRecord['commandBrainFinalReplayBiasStackSignature'] != null)
      'latestReplayBiasStackSignature':
          latestRecord['commandBrainFinalReplayBiasStackSignature'],
    if (replayBiasEntry['order'] is int)
      'latestReplayBiasStackPosition': replayBiasEntry['order'],
    'message': matchingSignal?['message']?.toString().trim().isNotEmpty == true
        ? matchingSignal!['message'].toString()
        : _buildReplayBiasStackSignalMessage(
            scope: scopeName,
            summary: summary,
            preferredTarget: preferredTarget,
          ),
  };
  if (matchingSignal?['effectiveSeverityChanged'] == true) {
    signal['effectiveSeverityChanged'] = true;
  }
  if (matchingSignal?['effectiveSeverityPromoted'] == true) {
    signal['effectiveSeverityPromoted'] = true;
  }
  if (matchingSignal?['effectiveSeverityDemoted'] == true) {
    signal['effectiveSeverityDemoted'] = true;
  }
  if (matchingSignal?['severityTransition'] != null) {
    signal['severityTransition'] = matchingSignal!['severityTransition'];
  }
  if (matchingSignal?['effectiveSeverityPolicyMatchType'] != null) {
    signal['effectiveSeverityPolicyMatchType'] =
        matchingSignal!['effectiveSeverityPolicyMatchType'];
  }
  if (matchingSignal?['effectiveSeverityPolicyValue'] != null) {
    signal['effectiveSeverityPolicyValue'] =
        matchingSignal!['effectiveSeverityPolicyValue'];
  }
  if (matchingSignal?['effectiveSeverityPolicySource'] != null) {
    signal['effectiveSeverityPolicySource'] =
        matchingSignal!['effectiveSeverityPolicySource'];
  }
  return signal;
}

String _buildReplayBiasStackSignalMessage({
  required String scope,
  required String? summary,
  required String? preferredTarget,
}) {
  if (summary != null && summary.isNotEmpty) {
    return summary;
  }
  final targetLabel = _toolTargetLabelFromSignalValue(preferredTarget);
  switch (scope) {
    case 'sequence_fallback':
      if (targetLabel != null) {
        return 'Replay sequence fallback keeps $targetLabel in front.';
      }
      return 'Replay sequence fallback remains active.';
    case 'specialist_conflict':
      if (targetLabel != null) {
        return 'Replay specialist conflict keeps $targetLabel in front.';
      }
      return 'Replay specialist conflict remains active.';
    case 'specialist_constraint':
      if (targetLabel != null) {
        return 'Replay specialist constraint keeps $targetLabel in front.';
      }
      return 'Replay specialist constraint remains active.';
    case 'specialist_degradation':
      if (targetLabel != null) {
        return 'Replay specialist degradation keeps $targetLabel in front.';
      }
      return 'Replay specialist degradation remains active.';
  }
  return 'Replay bias stack pressure remains active.';
}

String? _signalScopeNameFromBiasScope(String? rawBiasScope) {
  switch ((rawBiasScope ?? '').trim()) {
    case 'specialistDegradation':
      return 'specialist_degradation';
    case 'specialistConflict':
      return 'specialist_conflict';
    case 'specialistConstraint':
      return 'specialist_constraint';
    case 'sequenceFallback':
      return 'sequence_fallback';
  }
  return null;
}

List<Map<String, dynamic>> _readReplayBiasEntryList(Object? value) {
  if (value is! List) {
    return const <Map<String, dynamic>>[];
  }
  final entries = <Map<String, dynamic>>[];
  for (final entry in value) {
    final keyedMap = _stringKeyedMapOrNull(entry);
    if (keyedMap == null || keyedMap.isEmpty) {
      continue;
    }
    entries.add(keyedMap);
  }
  return entries;
}

Map<String, dynamic>? _latestRecordMatching(
  List<Map<String, dynamic>> records,
  bool Function(Map<String, dynamic> record) predicate,
) {
  for (final record in records.reversed) {
    if (predicate(record)) {
      return record;
    }
  }
  return null;
}

String _buildHistoryFieldTrend(List<bool> outcomes) {
  if (outcomes.isEmpty) {
    return 'unknown';
  }
  if (outcomes.length == 1) {
    return outcomes.single ? 'watch' : 'clean';
  }
  final latest = outcomes.last;
  final previous = outcomes[outcomes.length - 2];
  if (latest && !previous) {
    return 'worsening';
  }
  if (!latest && previous) {
    return 'clean_again';
  }
  if (latest && previous) {
    return 'stabilizing';
  }
  return 'clean';
}

bool _shouldAlertOnTrend(String trend) {
  switch (trend.trim().toLowerCase()) {
    case 'watch':
    case 'worsening':
    case 'stabilizing':
      return true;
  }
  return false;
}

String _buildAlertSeverity({
  required String scenarioSet,
  required String status,
  required String trend,
}) {
  final normalizedSet = scenarioSet.trim().toLowerCase();
  final normalizedStatus = status.trim().toLowerCase();
  final normalizedTrend = trend.trim().toLowerCase();
  final lockedValidation =
      normalizedSet == 'validation' && normalizedStatus == 'locked_validation';
  final validationCandidate = normalizedSet == 'validation';

  switch (normalizedTrend) {
    case 'worsening':
    case 'watch':
      if (lockedValidation) {
        return 'critical';
      }
      if (validationCandidate) {
        return 'high';
      }
      return 'medium';
    case 'stabilizing':
      if (lockedValidation) {
        return 'high';
      }
      if (validationCandidate) {
        return 'medium';
      }
      return 'low';
  }
  return 'info';
}

List<Map<String, dynamic>> _buildSpecialistDegradationAlerts(
  Map<String, Map<String, dynamic>> summary, {
  required Map<String, Map<String, dynamic>> scenarioMetadataByScenarioId,
}) {
  final alerts = <Map<String, dynamic>>[];
  for (final entry in summary.entries) {
    final metadata = scenarioMetadataByScenarioId[entry.key];
    if (metadata == null) {
      continue;
    }
    final latestBranch = entry.value['latestBranch']?.toString() ?? 'clean';
    final trend = entry.value['trend']?.toString() ?? 'unknown';
    if (latestBranch != 'persistent' || !_shouldAlertOnTrend(trend)) {
      continue;
    }
    alerts.add(<String, dynamic>{
      'severity': _buildAlertSeverity(
        scenarioSet: metadata['scenarioSet']?.toString() ?? '',
        status: metadata['status']?.toString() ?? '',
        trend: trend,
      ),
      'scope': 'specialist_degradation',
      'scenarioId': entry.key,
      'category': metadata['category'],
      'scenarioSet': metadata['scenarioSet'],
      'status': metadata['status'],
      'tags': metadata['tags'],
      'field': 'specialistDegradationBranch',
      'trend': trend,
      'count': entry.value['persistentCount'],
      'latestBranch': latestBranch,
      if (entry.value['latestSignature'] != null)
        'latestSpecialistDegradationSignature': entry.value['latestSignature'],
      if (entry.value['latestSpecialists'] != null)
        'latestSpecialists': entry.value['latestSpecialists'],
      if (entry.value['latestStatuses'] != null)
        'latestStatuses': entry.value['latestStatuses'],
      'message': _buildSpecialistDegradationAlertMessage(
        trend: trend,
        signature: entry.value['latestSignature']?.toString(),
      ),
    });
  }
  return alerts;
}

List<Map<String, dynamic>> _buildSpecialistConflictAlerts(
  Map<String, Map<String, dynamic>> summary, {
  required Map<String, Map<String, dynamic>> scenarioMetadataByScenarioId,
}) {
  final alerts = <Map<String, dynamic>>[];
  for (final entry in summary.entries) {
    final metadata = scenarioMetadataByScenarioId[entry.key];
    if (metadata == null) {
      continue;
    }
    final latestBranch = entry.value['latestBranch']?.toString() ?? 'clean';
    final trend = entry.value['trend']?.toString() ?? 'unknown';
    if (latestBranch != 'persistent' || !_shouldAlertOnTrend(trend)) {
      continue;
    }
    alerts.add(<String, dynamic>{
      'severity': _buildAlertSeverity(
        scenarioSet: metadata['scenarioSet']?.toString() ?? '',
        status: metadata['status']?.toString() ?? '',
        trend: trend,
      ),
      'scope': 'specialist_conflict',
      'scenarioId': entry.key,
      'category': metadata['category'],
      'scenarioSet': metadata['scenarioSet'],
      'status': metadata['status'],
      'tags': metadata['tags'],
      'field': 'specialistConflictBranch',
      'trend': trend,
      'count': entry.value['persistentCount'],
      'latestBranch': latestBranch,
      if (entry.value['latestSignature'] != null)
        'latestSpecialistConflictSignature': entry.value['latestSignature'],
      if (entry.value['latestSummary'] != null)
        'latestSummary': entry.value['latestSummary'],
      if (entry.value['latestSpecialists'] != null)
        'latestSpecialists': entry.value['latestSpecialists'],
      if (entry.value['latestTargets'] != null)
        'latestTargets': entry.value['latestTargets'],
      'message': _buildSpecialistConflictAlertMessage(
        trend: trend,
        signature: entry.value['latestSignature']?.toString(),
      ),
    });
  }
  return alerts;
}

List<Map<String, dynamic>> _buildSpecialistConstraintAlerts(
  Map<String, Map<String, dynamic>> summary, {
  required Map<String, Map<String, dynamic>> scenarioMetadataByScenarioId,
}) {
  final alerts = <Map<String, dynamic>>[];
  for (final entry in summary.entries) {
    final metadata = scenarioMetadataByScenarioId[entry.key];
    if (metadata == null) {
      continue;
    }
    final latestBranch = entry.value['latestBranch']?.toString() ?? 'clean';
    final trend = entry.value['trend']?.toString() ?? 'unknown';
    if (latestBranch != 'blocking' || !_shouldAlertOnTrend(trend)) {
      continue;
    }
    alerts.add(<String, dynamic>{
      'severity': _buildAlertSeverity(
        scenarioSet: metadata['scenarioSet']?.toString() ?? '',
        status: metadata['status']?.toString() ?? '',
        trend: trend,
      ),
      'scope': 'specialist_constraint',
      'scenarioId': entry.key,
      'category': metadata['category'],
      'scenarioSet': metadata['scenarioSet'],
      'status': metadata['status'],
      'tags': metadata['tags'],
      'field': 'specialistConstraintBranch',
      'trend': trend,
      'count': entry.value['blockingCount'],
      'latestBranch': latestBranch,
      if (entry.value['latestSignature'] != null)
        'latestSpecialistConstraintSignature': entry.value['latestSignature'],
      if (entry.value['latestSpecialist'] != null)
        'latestSpecialist': entry.value['latestSpecialist'],
      if (entry.value['latestTarget'] != null)
        'latestTarget': entry.value['latestTarget'],
      if (entry.value['latestAllowRouteExecution'] != null)
        'latestAllowRouteExecution': entry.value['latestAllowRouteExecution'],
      'message': _buildSpecialistConstraintAlertMessage(
        trend: trend,
        signature: entry.value['latestSignature']?.toString(),
      ),
    });
  }
  return alerts;
}

List<Map<String, dynamic>> _buildSequenceFallbackAlerts(
  Map<String, Map<String, dynamic>> summary, {
  required Map<String, Map<String, dynamic>> scenarioMetadataByScenarioId,
}) {
  final alerts = <Map<String, dynamic>>[];
  for (final entry in summary.entries) {
    final metadata = scenarioMetadataByScenarioId[entry.key];
    if (metadata == null) {
      continue;
    }
    final latestBranch = entry.value['latestBranch']?.toString() ?? 'clean';
    final trend = entry.value['trend']?.toString() ?? 'unknown';
    if (latestBranch != 'active' || !_shouldAlertOnTrend(trend)) {
      continue;
    }
    alerts.add(<String, dynamic>{
      'severity': _buildSequenceFallbackSeverity(trend: trend),
      'scope': 'sequence_fallback',
      'scenarioId': entry.key,
      'category': metadata['category'],
      'scenarioSet': metadata['scenarioSet'],
      'status': metadata['status'],
      'tags': metadata['tags'],
      'field': 'commandBrainFinalBiasScope',
      'trend': trend,
      'count': entry.value['count'],
      'latestBranch': latestBranch,
      if (entry.value['latestTarget'] != null)
        'latestTarget': entry.value['latestTarget'],
      if (entry.value['latestSummary'] != null)
        'latestSummary': entry.value['latestSummary'],
      if (entry.value['latestBiasSource'] != null)
        'latestBiasSource': entry.value['latestBiasSource'],
      if (entry.value['latestBiasScope'] != null)
        'latestBiasScope': entry.value['latestBiasScope'],
      if (entry.value['latestBiasSignature'] != null)
        'latestBiasSignature': entry.value['latestBiasSignature'],
      if (entry.value['latestBiasPolicySourceLabel'] != null)
        'latestBiasPolicySourceLabel':
            entry.value['latestBiasPolicySourceLabel'],
      if (entry.value['latestReplayBiasStackSignature'] != null)
        'latestReplayBiasStackSignature':
            entry.value['latestReplayBiasStackSignature'],
      if (entry.value['latestReplayBiasStackPosition'] != null)
        'latestReplayBiasStackPosition':
            entry.value['latestReplayBiasStackPosition'],
      'message': _buildSequenceFallbackAlertMessage(
        trend: trend,
        signature: entry.value['latestBiasSignature']?.toString(),
      ),
    });
  }
  return alerts;
}

List<Map<String, dynamic>> _buildSequenceFallbackRecoverySignals(
  Map<String, Map<String, dynamic>> summary, {
  required Map<String, Map<String, dynamic>> scenarioMetadataByScenarioId,
}) {
  final signals = <Map<String, dynamic>>[];
  for (final entry in summary.entries) {
    final metadata = scenarioMetadataByScenarioId[entry.key];
    if (metadata == null) {
      continue;
    }
    final latestBranch = entry.value['latestBranch']?.toString() ?? 'clean';
    final trend = entry.value['trend']?.toString() ?? 'unknown';
    if (latestBranch != 'clean' || trend != 'clean_again') {
      continue;
    }
    signals.add(<String, dynamic>{
      'severity': 'info',
      'effectiveSeverity': 'info',
      'baseSeverity': 'info',
      'scope': 'sequence_fallback',
      'scenarioId': entry.key,
      'category': metadata['category'],
      'scenarioSet': metadata['scenarioSet'],
      'status': metadata['status'],
      'tags': metadata['tags'],
      'field': 'commandBrainFinalBiasScope',
      'trend': trend,
      'count': entry.value['count'],
      if (entry.value['clearedCount'] != null)
        'clearedCount': entry.value['clearedCount'],
      'latestBranch': latestBranch,
      if (entry.value['latestTarget'] != null)
        'latestTarget': entry.value['latestTarget'],
      if (entry.value['latestRestoredTarget'] != null)
        'latestRestoredTarget': entry.value['latestRestoredTarget'],
      if (entry.value['latestSummary'] != null)
        'latestSummary': entry.value['latestSummary'],
      if (entry.value['latestBiasSource'] != null)
        'latestBiasSource': entry.value['latestBiasSource'],
      if (entry.value['latestBiasScope'] != null)
        'latestBiasScope': entry.value['latestBiasScope'],
      if (entry.value['latestBiasSignature'] != null)
        'latestBiasSignature': entry.value['latestBiasSignature'],
      if (entry.value['latestBiasPolicySourceLabel'] != null)
        'latestBiasPolicySourceLabel':
            entry.value['latestBiasPolicySourceLabel'],
      if (entry.value['latestReplayBiasStackSignature'] != null)
        'latestReplayBiasStackSignature':
            entry.value['latestReplayBiasStackSignature'],
      if (entry.value['latestReplayBiasStackPosition'] != null)
        'latestReplayBiasStackPosition':
            entry.value['latestReplayBiasStackPosition'],
      'message': _buildSequenceFallbackRecoveryMessage(
        target: entry.value['latestRestoredTarget']?.toString(),
      ),
    });
  }
  return signals;
}

List<Map<String, dynamic>> _buildReplayBiasStackDriftAlerts(
  Map<String, Map<String, dynamic>> summary, {
  required Map<String, Map<String, dynamic>> scenarioMetadataByScenarioId,
}) {
  final alerts = <Map<String, dynamic>>[];
  for (final entry in summary.entries) {
    final metadata = scenarioMetadataByScenarioId[entry.key];
    if (metadata == null) {
      continue;
    }
    final latestBranch = entry.value['latestBranch']?.toString() ?? 'stable';
    final trend = entry.value['trend']?.toString() ?? 'unknown';
    if (latestBranch != 'drifted' || !_shouldAlertOnTrend(trend)) {
      continue;
    }
    alerts.add(<String, dynamic>{
      'severity': _buildAlertSeverity(
        scenarioSet: metadata['scenarioSet']?.toString() ?? '',
        status: metadata['status']?.toString() ?? '',
        trend: trend,
      ),
      'scope': 'replay_bias_stack_drift',
      'scenarioId': entry.key,
      'category': metadata['category'],
      'scenarioSet': metadata['scenarioSet'],
      'status': metadata['status'],
      'tags': metadata['tags'],
      'field': 'commandBrainFinalReplayBiasStackSignature',
      'trend': trend,
      'count': entry.value['count'],
      'latestBranch': latestBranch,
      if (entry.value['latestReplayBiasStackSignature'] != null)
        'latestReplayBiasStackSignature':
            entry.value['latestReplayBiasStackSignature'],
      if (entry.value['previousReplayBiasStackSignature'] != null)
        'previousReplayBiasStackSignature':
            entry.value['previousReplayBiasStackSignature'],
      if (entry.value['latestSummary'] != null)
        'latestSummary': entry.value['latestSummary'],
      'message': _buildReplayBiasStackDriftAlertMessage(
        trend: trend,
        previousSignature:
            entry.value['previousReplayBiasStackSignature']?.toString(),
        latestSignature:
            entry.value['latestReplayBiasStackSignature']?.toString(),
      ),
    });
  }
  return alerts;
}

String? _buildReplayBiasStackDriftSummary({
  required List<Map<String, dynamic>> previousEntries,
  required List<Map<String, dynamic>> latestEntries,
}) {
  final previousSummary = _buildReplayBiasStackEntrySummary(previousEntries);
  final latestSummary = _buildReplayBiasStackEntrySummary(latestEntries);
  if (previousSummary == null && latestSummary == null) {
    return null;
  }
  if (previousSummary != null && latestSummary != null) {
    return 'Replay bias stack changed. Previous pressure: $previousSummary Latest pressure: $latestSummary';
  }
  if (latestSummary != null) {
    return 'Replay bias stack changed. Latest pressure: $latestSummary';
  }
  return 'Replay bias stack changed from $previousSummary';
}

String? _buildReplayBiasStackEntrySummary(List<Map<String, dynamic>> entries) {
  if (entries.isEmpty) {
    return null;
  }
  final parts = <String>[];
  for (final entry in entries) {
    final order = entry['order'] is int ? entry['order'] as int : null;
    final slotLabel = _replayPressureSlotLabel(order);
    final scopeLabel = _replayBiasScopeLabel(entry['scope']?.toString());
    final targetValue = _readNormalizedString(entry['preferredTarget']);
    final targetLabel =
        _toolTargetLabelFromSignalValue(targetValue) ?? targetValue;
    final descriptor = targetLabel == null || targetLabel.isEmpty
        ? scopeLabel
        : '$scopeLabel -> $targetLabel';
    if (slotLabel != null) {
      parts.add('$slotLabel: $descriptor.');
    } else {
      parts.add('$descriptor.');
    }
  }
  return parts.join(' ');
}

String _replayBiasScopeLabel(String? rawScope) {
  switch ((rawScope ?? '').trim()) {
    case 'specialistDegradation':
      return 'specialist degradation';
    case 'specialistConflict':
      return 'specialist conflict';
    case 'specialistConstraint':
      return 'specialist constraint';
    case 'sequenceFallback':
      return 'sequence fallback';
  }
  return 'replay pressure';
}

String _buildSpecialistDegradationAlertMessage({
  required String trend,
  String? signature,
}) {
  switch (trend) {
    case 'worsening':
      return 'Specialist signal regressed back into a degraded branch${signature == null ? '.' : ' ($signature).'}';
    case 'stabilizing':
      return 'Specialist signal stayed degraded across repeated runs${signature == null ? '.' : ' ($signature).'}';
    case 'watch':
      return 'Specialist signal opened a degraded branch${signature == null ? '.' : ' ($signature).'}';
  }
  return 'Specialist degradation needs review.';
}

String _buildSpecialistConflictAlertMessage({
  required String trend,
  String? signature,
}) {
  switch (trend) {
    case 'worsening':
      return 'Specialist conflict reopened after a clean run${signature == null ? '.' : ' ($signature).'}';
    case 'stabilizing':
      return 'Specialist conflict remains unresolved${signature == null ? '.' : ' ($signature).'}';
    case 'watch':
      return 'Specialist conflict opened for review${signature == null ? '.' : ' ($signature).'}';
  }
  return 'Specialist conflict needs review.';
}

String _buildSpecialistConstraintAlertMessage({
  required String trend,
  String? signature,
}) {
  switch (trend) {
    case 'worsening':
      return 'Hard specialist constraint blocked execution after a cleaner run${signature == null ? '.' : ' ($signature).'}';
    case 'stabilizing':
      return 'Hard specialist constraint is still blocking execution${signature == null ? '.' : ' ($signature).'}';
    case 'watch':
      return 'Hard specialist constraint opened and is blocking execution${signature == null ? '.' : ' ($signature).'}';
  }
  return 'Specialist constraint needs review.';
}

String _buildSequenceFallbackAlertMessage({
  required String trend,
  String? signature,
}) {
  switch (trend) {
    case 'worsening':
      return 'Replay sequence fallback reopened after a cleaner run${signature == null ? '.' : ' ($signature).'}';
    case 'stabilizing':
      return 'Replay sequence fallback remains active${signature == null ? '.' : ' ($signature).'}';
    case 'watch':
      return 'Replay sequence fallback opened for review${signature == null ? '.' : ' ($signature).'}';
  }
  return 'Replay sequence fallback needs review.';
}

String _buildSequenceFallbackRecoveryMessage({String? target}) {
  final restoredDesk = _toolTargetLabelFromSignalValue(target);
  if (restoredDesk != null) {
    return '$restoredDesk is back in front after the replay fallback cleared.';
  }
  return 'Replay sequence fallback cleared and the primary route was restored.';
}

String _buildReplayBiasStackDriftAlertMessage({
  required String trend,
  String? previousSignature,
  String? latestSignature,
}) {
  final signatureDetail =
      previousSignature != null && latestSignature != null
      ? ' ($previousSignature -> $latestSignature).'
      : latestSignature != null
      ? ' ($latestSignature).'
      : '.';
  switch (trend) {
    case 'worsening':
      return 'Replay bias stack reordered after a cleaner run$signatureDetail';
    case 'stabilizing':
      return 'Replay bias stack remains reordered across repeated runs$signatureDetail';
    case 'watch':
      return 'Replay bias stack changed for review$signatureDetail';
  }
  return 'Replay bias stack drift needs review.';
}

String _buildSequenceFallbackSeverity({required String trend}) {
  switch (trend.trim().toLowerCase()) {
    case 'worsening':
      return 'medium';
    case 'stabilizing':
    case 'watch':
      return 'low';
  }
  return 'info';
}

String? _buildSequenceFallbackRecoverySummary({
  required String? restoredTarget,
  required String? fallbackTarget,
}) {
  final restoredDesk = _toolTargetLabelFromSignalValue(restoredTarget);
  final fallbackDesk = _toolTargetLabelFromSignalValue(fallbackTarget);
  if (restoredDesk == null && fallbackDesk == null) {
    return null;
  }
  if (restoredDesk != null && fallbackDesk != null) {
    return '$restoredDesk is back in front after replay fallback cleared from $fallbackDesk.';
  }
  if (restoredDesk != null) {
    return '$restoredDesk is back in front after the replay fallback cleared.';
  }
  return '$fallbackDesk fallback cleared and the primary route is back in front.';
}

Future<Map<String, dynamic>?> _loadAlertFailurePolicyMap({
  required String workspaceRoot,
  required String policyPath,
}) async {
  final file = File(_resolvePath(workspaceRoot, policyPath));
  if (!file.existsSync()) {
    return null;
  }
  final decoded = jsonDecode(await file.readAsString());
  if (decoded is! Map<String, dynamic>) {
    return null;
  }
  return _stringKeyedMapOrNull(decoded['alertFailure']);
}

Map<String, dynamic> _enrichAlertWithPolicySeverity(
  Map<String, dynamic> alert,
  Map<String, dynamic>? policy,
) {
  final copy = Map<String, dynamic>.from(alert);
  final baseSeverity =
      alert['severity']?.toString().trim().toLowerCase() ?? 'low';
  copy['baseSeverity'] = baseSeverity;
  copy['effectiveSeverity'] = baseSeverity;

  final scope = alert['scope']?.toString().trim().toLowerCase();
  final scenarioSet = alert['scenarioSet']?.toString().trim().toLowerCase();
  final category = alert['category']?.toString().trim().toLowerCase();
  final scenarioId = alert['scenarioId']?.toString().trim();
  if (policy == null ||
      scope == null ||
      scope.isEmpty ||
      scenarioSet == null ||
      scenarioSet.isEmpty) {
    return copy;
  }

  final severityOverride = _resolvePolicySeverityOverride(
    policy: policy,
    scope: scope,
    scenarioSet: scenarioSet,
    category: category,
    scenarioId: scenarioId,
  );
  if (severityOverride == null) {
    return copy;
  }
  final effectiveSeverity = severityOverride['severity']!;
  copy['effectiveSeverity'] = effectiveSeverity;
  if (effectiveSeverity != baseSeverity) {
    copy['effectiveSeverityChanged'] = true;
    copy['effectiveSeverityPromoted'] =
        _alertSeverityRank(effectiveSeverity) >
        _alertSeverityRank(baseSeverity);
    copy['effectiveSeverityDemoted'] =
        _alertSeverityRank(effectiveSeverity) <
        _alertSeverityRank(baseSeverity);
    copy['severityTransition'] = '$baseSeverity->$effectiveSeverity';
    copy['effectiveSeverityPolicyMatchType'] = 'scope_severity_override';
    copy['effectiveSeverityPolicyValue'] = '$scope:$effectiveSeverity';
    copy['effectiveSeverityPolicySource'] = severityOverride['source'];
  }
  return copy;
}

Map<String, String>? _resolvePolicySeverityOverride({
  required Map<String, dynamic> policy,
  required String scope,
  required String scenarioSet,
  required String? category,
  required String? scenarioId,
}) {
  String? severity;
  String? source;

  void applyFromRule(Map<String, dynamic>? rule, String nextSource) {
    if (rule == null) {
      return;
    }
    final severityByScope = _readSeverityByScope(rule['severityByScope']);
    final scopedSeverity = severityByScope[scope];
    if (scopedSeverity == null || scopedSeverity.isEmpty) {
      return;
    }
    severity = scopedSeverity;
    source = nextSource;
  }

  applyFromRule(policy, 'default');
  final topLevelCategoryRules = _stringKeyedMapOrNull(policy['byCategory']);
  if (category != null && category.isNotEmpty) {
    applyFromRule(
      _stringKeyedMapOrNull(topLevelCategoryRules?[category]),
      'category',
    );
  }
  if (scenarioId != null && scenarioId.isNotEmpty) {
    final topLevelScenarioIdRules = _stringKeyedMapOrNull(
      policy['byScenarioId'],
    );
    applyFromRule(
      _stringKeyedMapOrNull(topLevelScenarioIdRules?[scenarioId]),
      'scenario_id',
    );
  }

  final scenarioSetRules = _stringKeyedMapOrNull(policy['byScenarioSet']);
  final scenarioSetRule = _stringKeyedMapOrNull(scenarioSetRules?[scenarioSet]);
  applyFromRule(scenarioSetRule, 'scenario_set');
  if (category != null && category.isNotEmpty) {
    final categoryRules = _stringKeyedMapOrNull(scenarioSetRule?['byCategory']);
    applyFromRule(
      _stringKeyedMapOrNull(categoryRules?[category]),
      'scenario_set_category',
    );
  }
  if (scenarioId != null && scenarioId.isNotEmpty) {
    final scenarioIdRules = _stringKeyedMapOrNull(
      scenarioSetRule?['byScenarioId'],
    );
    applyFromRule(
      _stringKeyedMapOrNull(scenarioIdRules?[scenarioId]),
      'scenario_set_scenario_id',
    );
  }

  if (severity == null || source == null) {
    return null;
  }
  return <String, String>{'severity': severity!, 'source': source!};
}

Map<String, String> _readSeverityByScope(Object? value) {
  final map = _stringKeyedMapOrNull(value);
  if (map == null || map.isEmpty) {
    return const <String, String>{};
  }
  final severityByScope = <String, String>{};
  for (final entry in map.entries) {
    final key = entry.key.trim().toLowerCase();
    final severity = entry.value?.toString().trim().toLowerCase();
    if (key.isEmpty || severity == null || severity.isEmpty) {
      continue;
    }
    severityByScope[key] = severity;
  }
  return severityByScope;
}

int _compareReplayHistorySignals(
  Map<String, dynamic> left,
  Map<String, dynamic> right,
) {
  final commandSurfaceOrder = _commandSurfacePriorityRank(
    right,
  ).compareTo(_commandSurfacePriorityRank(left));
  if (commandSurfaceOrder != 0) {
    return commandSurfaceOrder;
  }
  final severityOrder =
      _alertSeverityRank(
        right['effectiveSeverity']?.toString() ??
            right['severity']?.toString() ??
            '',
      ).compareTo(
        _alertSeverityRank(
          left['effectiveSeverity']?.toString() ??
              left['severity']?.toString() ??
              '',
        ),
      );
  if (severityOrder != 0) {
    return severityOrder;
  }
  final promotedOrder = (right['effectiveSeverityPromoted'] == true ? 1 : 0)
      .compareTo(left['effectiveSeverityPromoted'] == true ? 1 : 0);
  if (promotedOrder != 0) {
    return promotedOrder;
  }
  final scopeOrder = _scopeRank(
    right['scope']?.toString() ?? '',
  ).compareTo(_scopeRank(left['scope']?.toString() ?? ''));
  if (scopeOrder != 0) {
    return scopeOrder;
  }
  final leftCount = left['count'] is int ? left['count'] as int : 0;
  final rightCount = right['count'] is int ? right['count'] as int : 0;
  if (leftCount != rightCount) {
    return rightCount.compareTo(leftCount);
  }
  return (left['scenarioId']?.toString() ?? '').compareTo(
    right['scenarioId']?.toString() ?? '',
  );
}

int _commandSurfacePriorityRank(Map<String, dynamic> signal) {
  final promoted = signal['effectiveSeverityPromoted'] == true;
  switch ((signal['scope']?.toString() ?? '').trim().toLowerCase()) {
    case 'specialist_constraint':
      return promoted ? 50 : 30;
    case 'specialist_conflict':
      return promoted ? 40 : 20;
    case 'sequence_fallback':
      return promoted ? 35 : 10;
    case 'replay_bias_stack_drift':
      return promoted ? 2 : 1;
    case 'specialist_degradation':
      return promoted ? 5 : 0;
  }
  return 0;
}

int _scopeRank(String scope) {
  switch (scope.trim().toLowerCase()) {
    case 'specialist_constraint':
      return 5;
    case 'specialist_conflict':
      return 4;
    case 'sequence_fallback':
      return 3;
    case 'replay_bias_stack_drift':
      return 2;
    case 'specialist_degradation':
      return 1;
  }
  return 0;
}

int _alertSeverityRank(String severity) {
  switch (severity.trim().toLowerCase()) {
    case 'critical':
      return 4;
    case 'high':
      return 3;
    case 'medium':
      return 2;
    case 'low':
      return 1;
  }
  return 0;
}

int _signalSeverityRank(String severity) => _alertSeverityRank(severity);

OnyxToolTarget? _toolTargetFromSignalValue(String? value) {
  final normalized = (value ?? '').trim();
  if (normalized.isEmpty) {
    return null;
  }
  for (final target in OnyxToolTarget.values) {
    if (target.name == normalized) {
      return target;
    }
  }
  return null;
}

String? _toolTargetLabelFromSignalValue(String? value) {
  final target = _toolTargetFromSignalValue(value);
  return switch (target) {
    OnyxToolTarget.cctvReview => 'CCTV Review',
    OnyxToolTarget.tacticalTrack => 'Tactical Track',
    OnyxToolTarget.dispatchBoard => 'Dispatch Board',
    OnyxToolTarget.clientComms => 'Client Comms',
    OnyxToolTarget.reportsWorkspace => 'Reports Workspace',
    null => null,
  };
}
