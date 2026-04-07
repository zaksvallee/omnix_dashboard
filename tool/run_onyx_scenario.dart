import 'dart:convert';
import 'dart:io';

import 'package:omnix_dashboard/application/simulation/scenario_definition.dart';
import 'package:omnix_dashboard/application/simulation/scenario_result.dart';
import 'package:omnix_dashboard/application/simulation/scenario_runner.dart';
import 'package:omnix_dashboard/domain/authority/onyx_command_brain_contract.dart';

Future<void> main(List<String> args) async {
  final jsonMode = args.any((arg) => arg.trim() == '--json');
  final listMode = args.any((arg) => arg.trim() == '--list');
  final writeHistory = args.any((arg) => arg.trim() == '--history');
  final helpMode = args.any(
    (arg) => arg.trim() == '--help' || arg.trim() == '-h',
  );
  final resultsDir = _readOptionValue(args, '--results-dir');
  final historyDir = _readOptionValue(args, '--history-dir');
  final scenarioSetFilter = _readOptionValue(args, '--set');
  final scenarioStatusFilter = _readOptionValue(args, '--status');
  final policyPath = _readOptionValue(args, '--policy');
  final failOnAlertThreshold = _normalizeAlertSeverityOption(
    _readOptionValue(args, '--fail-on-alert'),
  );
  final failOnAlertGroupFilter = _normalizeOptionalFilterValue(
    _readOptionValue(args, '--fail-on-group'),
  );
  final failOnAlertTagFilter = _normalizeOptionalFilterValue(
    _readOptionValue(args, '--fail-on-tag'),
  );
  final failOnAlertCategoryFilter = _normalizeOptionalFilterValue(
    _readOptionValue(args, '--fail-on-category'),
  );
  final failOnAlertStatusFilter = _normalizeOptionalFilterValue(
    _readOptionValue(args, '--fail-on-status'),
  );
  final positionalArgs = args
      .map((arg) => arg.trim())
      .where(
        (arg) =>
            arg.isNotEmpty &&
            arg != '--json' &&
            arg != '--list' &&
            arg != '--history' &&
            arg != '--help' &&
            arg != '-h' &&
            !arg.startsWith('--results-dir=') &&
            !arg.startsWith('--history-dir=') &&
            !arg.startsWith('--set=') &&
            !arg.startsWith('--status=') &&
            !arg.startsWith('--policy=') &&
            !arg.startsWith('--fail-on-alert=') &&
            !arg.startsWith('--fail-on-group=') &&
            !arg.startsWith('--fail-on-tag=') &&
            !arg.startsWith('--fail-on-category=') &&
            !arg.startsWith('--fail-on-status='),
      )
      .toList(growable: false);

  if (helpMode) {
    _printUsage();
    return;
  }

  final workspaceRoot = Directory.current.path;
  final targetPath = positionalArgs.isNotEmpty
      ? positionalArgs.first
      : 'simulations/scenarios';
  final includeHistoryRollups =
      writeHistory || (historyDir != null && historyDir.trim().isNotEmpty);

  try {
    final alertFailurePolicy = await _loadAlertFailurePolicy(
      workspaceRoot: workspaceRoot,
      policyPath: policyPath,
    );
    final defaultAlertFailureRule = alertFailurePolicy?.resolveForScenarioSet(
      null,
    );
    final appliedAlertThreshold =
        failOnAlertThreshold ?? defaultAlertFailureRule?.threshold;
    final appliedAlertCategoryAllowlist = failOnAlertCategoryFilter != null
        ? <String>[failOnAlertCategoryFilter]
        : defaultAlertFailureRule?.includeCategories ?? const <String>[];
    final appliedAlertStatusAllowlist = failOnAlertStatusFilter != null
        ? <String>[failOnAlertStatusFilter]
        : defaultAlertFailureRule?.includeStatuses ?? const <String>[];
    final appliedAlertCategoryDenylist =
        defaultAlertFailureRule?.excludeCategories ?? const <String>[];
    final appliedAlertStatusDenylist =
        defaultAlertFailureRule?.excludeStatuses ?? const <String>[];

    final runner = ScenarioRunner(
      workspaceRoot: workspaceRoot,
      resultsRootPath: resultsDir,
      historyResultsRootPath: historyDir,
    );
    final scenarioPaths = _resolveScenarioPaths(
      workspaceRoot: workspaceRoot,
      targetPath: targetPath,
    );
    if (scenarioPaths.isEmpty) {
      stderr.writeln('No scenario JSON files found for target: $targetPath');
      exitCode = 64;
      return;
    }
    final resolvedScenarios = await _loadResolvedScenarios(
      scenarioPaths: scenarioPaths,
      scenarioSetFilter: scenarioSetFilter,
      scenarioStatusFilter: scenarioStatusFilter,
    );
    if (resolvedScenarios.isEmpty) {
      final normalizedSetFilter = scenarioSetFilter?.trim();
      final normalizedStatusFilter = scenarioStatusFilter?.trim();
      final filterParts = <String>[];
      if (normalizedSetFilter != null && normalizedSetFilter.isNotEmpty) {
        filterParts.add('scenario set "$normalizedSetFilter"');
      }
      if (normalizedStatusFilter != null && normalizedStatusFilter.isNotEmpty) {
        filterParts.add('status "$normalizedStatusFilter"');
      }
      final filterSuffix = filterParts.isEmpty
          ? ''
          : ' with ${filterParts.join(' and ')}';
      stderr.writeln(
        'No scenario JSON files found for target: $targetPath$filterSuffix',
      );
      exitCode = 64;
      return;
    }

    if (listMode) {
      final index = _buildScenarioIndex(
        resolvedScenarios: resolvedScenarios,
        scenarioSetFilter: scenarioSetFilter,
        scenarioStatusFilter: scenarioStatusFilter,
      );
      if (jsonMode) {
        stdout.writeln(const JsonEncoder.withIndent('  ').convert(index));
      } else {
        stdout.writeln(_buildIndexConsoleSummary(index));
      }
      return;
    }

    final records = <Map<String, dynamic>>[];
    for (final resolvedScenario in resolvedScenarios) {
      final result = await runner.runScenario(resolvedScenario.definition);
      File? historyFile;
      if (writeHistory) {
        historyFile = await runner.writeHistoryResult(result);
      }
      records.add(
        _buildRecord(
          scenarioPath: resolvedScenario.path,
          scenarioCategory: resolvedScenario.definition.category,
          scenarioSet: resolvedScenario.definition.scenarioSet,
          scenarioStatus: resolvedScenario.definition.status,
          result: result,
          historyFilePath: historyFile?.path,
        ),
      );
    }

    final failedCount = records
        .where((record) => record['passed'] == false)
        .length;
    final historyRollups = includeHistoryRollups
        ? await _buildHistoryRollups(
            historyResultsRootPath: runner.historyResultsRootPath,
            resolvedScenarios: resolvedScenarios,
          )
        : const <String, dynamic>{};
    final enrichedHistoryAlerts = _enrichHistoryAlertsWithSeverityContext(
      historyRollups['historyAlerts'],
      policy: alertFailurePolicy,
    );
    final summary = <String, dynamic>{
      'targetPath': targetPath,
      if (scenarioSetFilter != null && scenarioSetFilter.trim().isNotEmpty)
        'scenarioSetFilter': scenarioSetFilter.trim().toLowerCase(),
      if (scenarioStatusFilter != null &&
          scenarioStatusFilter.trim().isNotEmpty)
        'scenarioStatusFilter': scenarioStatusFilter.trim().toLowerCase(),
      if (alertFailurePolicy != null)
        'alertFailurePolicyPath': alertFailurePolicy.path,
      if (alertFailurePolicy != null &&
          alertFailurePolicy.byScenarioSet.isNotEmpty)
        'alertFailurePolicyByScenarioSet': alertFailurePolicy
            .resolvedScenarioSetRulesToJson(),
      if (alertFailurePolicy != null &&
          alertFailurePolicy.resolvedCategoryRulesToJson().isNotEmpty)
        'alertFailurePolicyByCategory': alertFailurePolicy
            .resolvedCategoryRulesToJson(),
      if (alertFailurePolicy != null &&
          alertFailurePolicy.resolvedScenarioIdRulesToJson().isNotEmpty)
        'alertFailurePolicyByScenarioId': alertFailurePolicy
            .resolvedScenarioIdRulesToJson(),
      if (alertFailurePolicy != null && alertFailurePolicy.groups.isNotEmpty)
        'alertFailurePolicyGroups': alertFailurePolicy.groupsToJson(),
      'alertFailureThreshold': ?appliedAlertThreshold,
      'alertFailureGroupFilter': ?failOnAlertGroupFilter,
      'alertFailureTagFilter': ?failOnAlertTagFilter,
      'alertFailureCategoryFilter': ?failOnAlertCategoryFilter,
      'alertFailureStatusFilter': ?failOnAlertStatusFilter,
      if (appliedAlertCategoryAllowlist.isNotEmpty)
        'alertFailureCategoryAllowlist': appliedAlertCategoryAllowlist,
      if (appliedAlertStatusAllowlist.isNotEmpty)
        'alertFailureStatusAllowlist': appliedAlertStatusAllowlist,
      if (appliedAlertCategoryDenylist.isNotEmpty)
        'alertFailureCategoryDenylist': appliedAlertCategoryDenylist,
      if (appliedAlertStatusDenylist.isNotEmpty)
        'alertFailureStatusDenylist': appliedAlertStatusDenylist,
      'scenarioCount': records.length,
      'passedCount': records.length - failedCount,
      'failedCount': failedCount,
      'scenarioCategorySummary': _buildRunSummary(
        records,
        groupKey: 'category',
      ),
      'scenarioSetSummary': _buildRunSummary(records, groupKey: 'scenarioSet'),
      'scenarioStatusSummary': _buildRunSummary(records, groupKey: 'status'),
      'commandBrainFinalTargetSummary': _buildRunSummary(
        records,
        groupKey: 'commandBrainFinalTarget',
      ),
      'commandBrainFinalModeSummary': _buildRunSummary(
        records,
        groupKey: 'commandBrainFinalMode',
      ),
      'commandBrainFinalBiasSourceSummary': _buildRunSummary(
        records,
        groupKey: 'commandBrainFinalBiasSource',
      ),
      'commandBrainFinalBiasScopeSummary': _buildRunSummary(
        records,
        groupKey: 'commandBrainFinalBiasScope',
      ),
      'commandBrainFinalBiasSignatureSummary': _buildRunSummary(
        records,
        groupKey: 'commandBrainFinalBiasSignature',
      ),
      'commandBrainFinalReplayBiasStackLengthSummary': _buildRunSummary(
        records,
        groupKey: 'commandBrainFinalReplayBiasStackLength',
      ),
      'commandBrainFinalReplayBiasStackSignatureSummary': _buildRunSummary(
        records,
        groupKey: 'commandBrainFinalReplayBiasStackSignature',
      ),
      'commandBrainTimelineSummary': _buildRunSummary(
        records,
        groupKey: 'commandBrainTimelineSignature',
      ),
      'specialistDegradationBranchSummary': _buildRunSummary(
        records,
        groupKey: 'specialistDegradationBranch',
      ),
      'specialistDegradationSignatureSummary': _buildRunSummary(
        records,
        groupKey: 'specialistDegradationSignature',
      ),
      'specialistConflictBranchSummary': _buildRunSummary(
        records,
        groupKey: 'specialistConflictBranch',
      ),
      'specialistConflictSignatureSummary': _buildRunSummary(
        records,
        groupKey: 'specialistConflictSignature',
      ),
      'specialistConflictLifecycleSummary': _buildRunSummary(
        records,
        groupKey: 'specialistConflictLifecycle',
      ),
      'specialistConflictLifecycleSignatureSummary': _buildRunSummary(
        records,
        groupKey: 'specialistConflictLifecycleSignature',
      ),
      'specialistConstraintBranchSummary': _buildRunSummary(
        records,
        groupKey: 'specialistConstraintBranch',
      ),
      'specialistConstraintSignatureSummary': _buildRunSummary(
        records,
        groupKey: 'specialistConstraintSignature',
      ),
      'specialistConstraintLifecycleSummary': _buildRunSummary(
        records,
        groupKey: 'specialistConstraintLifecycle',
      ),
      'specialistConstraintLifecycleSignatureSummary': _buildRunSummary(
        records,
        groupKey: 'specialistConstraintLifecycleSignature',
      ),
      'sequenceFallbackLifecycleSummary': _buildRunSummary(
        records,
        groupKey: 'sequenceFallbackLifecycle',
      ),
      'sequenceFallbackLifecycleSignatureSummary': _buildRunSummary(
        records,
        groupKey: 'sequenceFallbackLifecycleSignature',
      ),
      'mismatchFieldSummary': _buildMismatchFieldSummary(records),
      'categoryMismatchFieldSummary': _buildCategoryMismatchFieldSummary(
        records,
      ),
      ...historyRollups,
      'historyAlerts': enrichedHistoryAlerts,
      'results': records,
    };
    final historyAlertFocus = _buildAlertFailureFocus(enrichedHistoryAlerts);
    if (historyAlertFocus != null) {
      summary['historyAlertFocus'] = historyAlertFocus;
    }
    final policyPromotedReplayRiskEvaluations =
        _buildPolicyPromotedReplayRiskEvaluations(
          historyAlerts: historyRollups['historyAlerts'],
          policy: alertFailurePolicy,
          thresholdOverride: failOnAlertThreshold,
          groupFilterOverride: failOnAlertGroupFilter,
          tagFilterOverride: failOnAlertTagFilter,
          categoryFilterOverride: failOnAlertCategoryFilter,
          statusFilterOverride: failOnAlertStatusFilter,
        );
    final historyAlertPolicyPromotedReplayRiskSummary =
        _buildPolicyPromotedReplayRiskSummary(
          policyPromotedReplayRiskEvaluations,
        );
    if (historyAlertPolicyPromotedReplayRiskSummary.isNotEmpty) {
      summary['historyAlertPolicyPromotedReplayRiskSummary'] =
          historyAlertPolicyPromotedReplayRiskSummary;
    }
    final historyAlertPolicyPromotedReplayRiskSourceSummary =
        _buildPolicyPromotedReplayRiskSourceSummary(
          policyPromotedReplayRiskEvaluations,
        );
    if (historyAlertPolicyPromotedReplayRiskSourceSummary.isNotEmpty) {
      summary['historyAlertPolicyPromotedReplayRiskSourceSummary'] =
          historyAlertPolicyPromotedReplayRiskSourceSummary;
    }
    final historyAlertPolicyPromotedReplayRiskFocus =
        _buildPolicyPromotedReplayRiskFocus(
          policyPromotedReplayRiskEvaluations,
        );
    if (historyAlertPolicyPromotedReplayRiskFocus != null) {
      summary['historyAlertPolicyPromotedReplayRiskFocus'] =
          historyAlertPolicyPromotedReplayRiskFocus;
      final historyFocusSummary = _stringKeyedMapOrNull(
        summary['historyFocusSummary'],
      );
      final topPolicyPromotedReplayRiskScenario =
          _buildHistoryPolicyPromotedReplayRiskFocusEntry(
            focus: historyAlertPolicyPromotedReplayRiskFocus,
            historyScenarioSummary: summary['historyScenarioSummary'],
          );
      if (historyFocusSummary != null &&
          topPolicyPromotedReplayRiskScenario != null) {
        summary['historyFocusSummary'] = <String, dynamic>{
          ...historyFocusSummary,
          'topPolicyPromotedReplayRiskScenario':
              topPolicyPromotedReplayRiskScenario,
        };
      }
    }
    final policyPromotedSpecialistEvaluations =
        _buildPolicyPromotedSpecialistEvaluations(
          historyAlerts: historyRollups['historyAlerts'],
          policy: alertFailurePolicy,
          thresholdOverride: failOnAlertThreshold,
          groupFilterOverride: failOnAlertGroupFilter,
          tagFilterOverride: failOnAlertTagFilter,
          categoryFilterOverride: failOnAlertCategoryFilter,
          statusFilterOverride: failOnAlertStatusFilter,
        );
    final historyAlertPolicyPromotedSpecialistSummary =
        _buildPolicyPromotedSpecialistSummary(
          policyPromotedSpecialistEvaluations,
        );
    if (historyAlertPolicyPromotedSpecialistSummary.isNotEmpty) {
      summary['historyAlertPolicyPromotedSpecialistSummary'] =
          historyAlertPolicyPromotedSpecialistSummary;
    }
    final historyAlertPolicyPromotedSpecialistSourceSummary =
        _buildPolicyPromotedSpecialistSourceSummary(
          policyPromotedSpecialistEvaluations,
        );
    if (historyAlertPolicyPromotedSpecialistSourceSummary.isNotEmpty) {
      summary['historyAlertPolicyPromotedSpecialistSourceSummary'] =
          historyAlertPolicyPromotedSpecialistSourceSummary;
    }
    final historyAlertPolicyPromotedSpecialistFocus =
        _buildPolicyPromotedSpecialistFocus(
          policyPromotedSpecialistEvaluations,
        );
    if (historyAlertPolicyPromotedSpecialistFocus != null) {
      summary['historyAlertPolicyPromotedSpecialistFocus'] =
          historyAlertPolicyPromotedSpecialistFocus;
      final historyFocusSummary = _stringKeyedMapOrNull(
        summary['historyFocusSummary'],
      );
      final topPolicyPromotedSpecialistScenario =
          _buildHistoryPolicyPromotedSpecialistFocusEntry(
            focus: historyAlertPolicyPromotedSpecialistFocus,
            historyScenarioSummary: summary['historyScenarioSummary'],
          );
      if (historyFocusSummary != null &&
          topPolicyPromotedSpecialistScenario != null) {
        summary['historyFocusSummary'] = <String, dynamic>{
          ...historyFocusSummary,
          'topPolicyPromotedSpecialistScenario':
              topPolicyPromotedSpecialistScenario,
        };
      }
    }
    final alertFailures = _buildTriggeredAlertSummary(
      enrichedHistoryAlerts,
      policy: alertFailurePolicy,
      thresholdOverride: failOnAlertThreshold,
      groupFilterOverride: failOnAlertGroupFilter,
      tagFilterOverride: failOnAlertTagFilter,
      categoryFilterOverride: failOnAlertCategoryFilter,
      statusFilterOverride: failOnAlertStatusFilter,
    );
    if (appliedAlertThreshold != null) {
      summary['alertFailureTriggered'] = alertFailures.isNotEmpty;
      summary['alertFailureCount'] = alertFailures.length;
      summary['alertFailureSummary'] = _buildHistoryAlertSummary(alertFailures);
      final alertFailureCategorySummary = _buildHistoryAlertGroupSummary(
        alertFailures,
        groupKey: 'category',
      );
      if (alertFailureCategorySummary.isNotEmpty) {
        summary['alertFailureCategorySummary'] = alertFailureCategorySummary;
      }
      final alertFailureCategoryFieldSummary = _buildGroupedAlertFieldSummary(
        alertFailures,
        groupKey: 'category',
      );
      if (alertFailureCategoryFieldSummary.isNotEmpty) {
        summary['alertFailureCategoryFieldSummary'] =
            alertFailureCategoryFieldSummary;
      }
      final alertFailureScenarioSummary = _buildHistoryAlertGroupSummary(
        alertFailures,
        groupKey: 'scenarioId',
      );
      if (alertFailureScenarioSummary.isNotEmpty) {
        summary['alertFailureScenarioSummary'] = alertFailureScenarioSummary;
      }
      final alertFailureScenarioFieldSummary = _buildGroupedAlertFieldSummary(
        alertFailures,
        groupKey: 'scenarioId',
      );
      if (alertFailureScenarioFieldSummary.isNotEmpty) {
        summary['alertFailureScenarioFieldSummary'] =
            alertFailureScenarioFieldSummary;
      }
      final alertFailureFieldSummary = _buildHistoryAlertFieldSummary(
        alertFailures,
      );
      if (alertFailureFieldSummary.isNotEmpty) {
        summary['alertFailureFieldSummary'] = alertFailureFieldSummary;
      }
      final alertFailureCommandBrainTimelineSummary =
          _buildCommandBrainTimelineAlertSummary(alertFailures);
      if (alertFailureCommandBrainTimelineSummary.isNotEmpty) {
        summary['alertFailureCommandBrainTimelineSummary'] =
            alertFailureCommandBrainTimelineSummary;
      }
      final alertFailureCommandBrainReplayBiasStackSummary =
          _buildCommandBrainReplayBiasStackAlertSummary(alertFailures);
      if (alertFailureCommandBrainReplayBiasStackSummary.isNotEmpty) {
        summary['alertFailureCommandBrainReplayBiasStackSummary'] =
            alertFailureCommandBrainReplayBiasStackSummary;
      }
      final alertFailureSpecialistDegradationSummary =
          _buildSpecialistDegradationAlertSummary(alertFailures);
      if (alertFailureSpecialistDegradationSummary.isNotEmpty) {
        summary['alertFailureSpecialistDegradationSummary'] =
            alertFailureSpecialistDegradationSummary;
      }
      final alertFailureSpecialistConflictSummary =
          _buildSpecialistConflictAlertSummary(alertFailures);
      if (alertFailureSpecialistConflictSummary.isNotEmpty) {
        summary['alertFailureSpecialistConflictSummary'] =
            alertFailureSpecialistConflictSummary;
      }
      final alertFailureSpecialistConstraintSummary =
          _buildSpecialistConstraintAlertSummary(alertFailures);
      if (alertFailureSpecialistConstraintSummary.isNotEmpty) {
        summary['alertFailureSpecialistConstraintSummary'] =
            alertFailureSpecialistConstraintSummary;
      }
      final alertFailureSequenceFallbackSummary =
          _buildSequenceFallbackAlertSummary(alertFailures);
      if (alertFailureSequenceFallbackSummary.isNotEmpty) {
        summary['alertFailureSequenceFallbackSummary'] =
            alertFailureSequenceFallbackSummary;
      }
      final alertFailureTrendSummary = _buildHistoryAlertGroupSummary(
        alertFailures,
        groupKey: 'trend',
      );
      if (alertFailureTrendSummary.isNotEmpty) {
        summary['alertFailureTrendSummary'] = alertFailureTrendSummary;
      }
      final alertFailureScenarioSetSummary = _buildHistoryAlertGroupSummary(
        alertFailures,
        groupKey: 'scenarioSet',
      );
      if (alertFailureScenarioSetSummary.isNotEmpty) {
        summary['alertFailureScenarioSetSummary'] =
            alertFailureScenarioSetSummary;
      }
      final alertFailureStatusSummary = _buildHistoryAlertGroupSummary(
        alertFailures,
        groupKey: 'status',
      );
      if (alertFailureStatusSummary.isNotEmpty) {
        summary['alertFailureStatusSummary'] = alertFailureStatusSummary;
      }
      final alertFailureTagSummary = _buildHistoryAlertTagSummary(
        alertFailures,
      );
      if (alertFailureTagSummary.isNotEmpty) {
        summary['alertFailureTagSummary'] = alertFailureTagSummary;
      }
      final alertFailureTagFieldSummary = _buildAlertTagFieldSummary(
        alertFailures,
      );
      if (alertFailureTagFieldSummary.isNotEmpty) {
        summary['alertFailureTagFieldSummary'] = alertFailureTagFieldSummary;
      }
      final alertFailurePolicySummary = _buildAlertFailurePolicySummary(
        historyAlerts: historyRollups['historyAlerts'],
        policy: alertFailurePolicy,
        thresholdOverride: failOnAlertThreshold,
        groupFilterOverride: failOnAlertGroupFilter,
        tagFilterOverride: failOnAlertTagFilter,
        categoryFilterOverride: failOnAlertCategoryFilter,
        statusFilterOverride: failOnAlertStatusFilter,
      );
      if (alertFailurePolicySummary.isNotEmpty) {
        summary['alertFailurePolicySummary'] = alertFailurePolicySummary;
      }
      final alertFailurePolicyTypeSummary = _buildAlertFailurePolicyTypeSummary(
        historyAlerts: historyRollups['historyAlerts'],
        policy: alertFailurePolicy,
        thresholdOverride: failOnAlertThreshold,
        groupFilterOverride: failOnAlertGroupFilter,
        tagFilterOverride: failOnAlertTagFilter,
        categoryFilterOverride: failOnAlertCategoryFilter,
        statusFilterOverride: failOnAlertStatusFilter,
      );
      if (alertFailurePolicyTypeSummary.isNotEmpty) {
        summary['alertFailurePolicyTypeSummary'] =
            alertFailurePolicyTypeSummary;
      }
      final alertFailurePolicySuppressionSummary =
          _buildHistoryAlertPolicySuppressionSummary(
            historyAlerts: historyRollups['historyAlerts'],
            policy: alertFailurePolicy,
            thresholdOverride: failOnAlertThreshold,
            groupFilterOverride: failOnAlertGroupFilter,
            tagFilterOverride: failOnAlertTagFilter,
            categoryFilterOverride: failOnAlertCategoryFilter,
            statusFilterOverride: failOnAlertStatusFilter,
          );
      if (alertFailurePolicySuppressionSummary.isNotEmpty) {
        summary['alertFailurePolicySuppressionSummary'] =
            alertFailurePolicySuppressionSummary;
      }
      final alertFailurePolicySourceSummary =
          _buildAlertFailurePolicySourceSummary(
            historyAlerts: historyRollups['historyAlerts'],
            policy: alertFailurePolicy,
            thresholdOverride: failOnAlertThreshold,
            groupFilterOverride: failOnAlertGroupFilter,
            tagFilterOverride: failOnAlertTagFilter,
            categoryFilterOverride: failOnAlertCategoryFilter,
            statusFilterOverride: failOnAlertStatusFilter,
          );
      if (alertFailurePolicySourceSummary.isNotEmpty) {
        summary['alertFailurePolicySourceSummary'] =
            alertFailurePolicySourceSummary;
      }
      if (historyAlertPolicyPromotedSpecialistSummary.isNotEmpty) {
        summary['alertFailurePolicyPromotedSpecialistSummary'] =
            historyAlertPolicyPromotedSpecialistSummary;
      }
      if (historyAlertPolicyPromotedReplayRiskSummary.isNotEmpty) {
        summary['alertFailurePolicyPromotedReplayRiskSummary'] =
            historyAlertPolicyPromotedReplayRiskSummary;
      }
      if (historyAlertPolicyPromotedSpecialistSourceSummary.isNotEmpty) {
        summary['alertFailurePolicyPromotedSpecialistSourceSummary'] =
            historyAlertPolicyPromotedSpecialistSourceSummary;
      }
      if (historyAlertPolicyPromotedReplayRiskSourceSummary.isNotEmpty) {
        summary['alertFailurePolicyPromotedReplayRiskSourceSummary'] =
            historyAlertPolicyPromotedReplayRiskSourceSummary;
      }
      if (historyAlertPolicyPromotedSpecialistFocus != null) {
        summary['alertFailurePolicyPromotedSpecialistFocus'] =
            historyAlertPolicyPromotedSpecialistFocus;
      }
      if (historyAlertPolicyPromotedReplayRiskFocus != null) {
        summary['alertFailurePolicyPromotedReplayRiskFocus'] =
            historyAlertPolicyPromotedReplayRiskFocus;
      }
      final alertFailureFocus = _buildAlertFailureFocus(alertFailures);
      if (alertFailureFocus != null) {
        summary['alertFailureFocus'] = alertFailureFocus;
      }
      final alertFailureGroupFocus = _buildAlertFailureGroupFocus(
        group: failOnAlertGroupFilter,
        alerts: alertFailures,
      );
      if (alertFailureGroupFocus != null) {
        summary['alertFailureGroupFocus'] = alertFailureGroupFocus;
      }
      final alertFailureTagFocus = _buildAlertFailureTagFocus(
        tag: failOnAlertTagFilter,
        alerts: alertFailures,
      );
      if (alertFailureTagFocus != null) {
        summary['alertFailureTagFocus'] = alertFailureTagFocus;
      }
      final alertFailureCategoryFocus = _buildAlertFailureCategoryFocus(
        category: failOnAlertCategoryFilter,
        alerts: alertFailures,
      );
      if (alertFailureCategoryFocus != null) {
        summary['alertFailureCategoryFocus'] = alertFailureCategoryFocus;
      }
      final alertFailureStatusFocus = _buildAlertFailureStatusFocus(
        status: failOnAlertStatusFilter,
        alerts: alertFailures,
      );
      if (alertFailureStatusFocus != null) {
        summary['alertFailureStatusFocus'] = alertFailureStatusFocus;
      }
      final alertFailurePolicyFocus = _buildAlertFailurePolicyFocus(
        historyAlerts: historyRollups['historyAlerts'],
        alerts: alertFailures,
        policy: alertFailurePolicy,
        thresholdOverride: failOnAlertThreshold,
        groupFilterOverride: failOnAlertGroupFilter,
        tagFilterOverride: failOnAlertTagFilter,
        categoryFilterOverride: failOnAlertCategoryFilter,
        statusFilterOverride: failOnAlertStatusFilter,
      );
      if (alertFailurePolicyFocus != null) {
        summary['alertFailurePolicyFocus'] = alertFailurePolicyFocus;
      }
    }
    final historyAlertScopedAlerts = _buildTriggeredAlertSummary(
      enrichedHistoryAlerts,
      policy: alertFailurePolicy,
      thresholdOverride: failOnAlertThreshold,
      groupFilterOverride: failOnAlertGroupFilter,
      tagFilterOverride: failOnAlertTagFilter,
      categoryFilterOverride: failOnAlertCategoryFilter,
      statusFilterOverride: failOnAlertStatusFilter,
    );
    final historyAlertGroupFocus = _buildAlertFailureGroupFocus(
      group: failOnAlertGroupFilter,
      alerts: historyAlertScopedAlerts,
    );
    if (historyAlertGroupFocus != null) {
      summary['historyAlertGroupFocus'] = historyAlertGroupFocus;
    }
    final historyAlertTagFocus = _buildAlertFailureTagFocus(
      tag: failOnAlertTagFilter,
      alerts: historyAlertScopedAlerts,
    );
    if (historyAlertTagFocus != null) {
      summary['historyAlertTagFocus'] = historyAlertTagFocus;
    }
    final historyAlertCategoryFocus = _buildAlertFailureCategoryFocus(
      category: failOnAlertCategoryFilter,
      alerts: historyAlertScopedAlerts,
    );
    if (historyAlertCategoryFocus != null) {
      summary['historyAlertCategoryFocus'] = historyAlertCategoryFocus;
    }
    final historyAlertStatusFocus = _buildAlertFailureStatusFocus(
      status: failOnAlertStatusFilter,
      alerts: historyAlertScopedAlerts,
    );
    if (historyAlertStatusFocus != null) {
      summary['historyAlertStatusFocus'] = historyAlertStatusFocus;
    }
    final historyAlertPolicyFocus = _buildAlertFailurePolicyFocus(
      historyAlerts: historyRollups['historyAlerts'],
      alerts: historyAlertScopedAlerts,
      policy: alertFailurePolicy,
      thresholdOverride: failOnAlertThreshold,
      groupFilterOverride: failOnAlertGroupFilter,
      tagFilterOverride: failOnAlertTagFilter,
      categoryFilterOverride: failOnAlertCategoryFilter,
      statusFilterOverride: failOnAlertStatusFilter,
    );
    if (historyAlertPolicyFocus != null) {
      summary['historyAlertPolicyFocus'] = historyAlertPolicyFocus;
    }
    final historyAlertPolicySummary = _buildHistoryAlertPolicySummary(
      historyAlerts: historyRollups['historyAlerts'],
      policy: alertFailurePolicy,
      thresholdOverride: failOnAlertThreshold,
      groupFilterOverride: failOnAlertGroupFilter,
      tagFilterOverride: failOnAlertTagFilter,
      categoryFilterOverride: failOnAlertCategoryFilter,
      statusFilterOverride: failOnAlertStatusFilter,
    );
    if (historyAlertPolicySummary.isNotEmpty) {
      summary['historyAlertPolicySummary'] = historyAlertPolicySummary;
    }
    final historyAlertPolicyTypeSummary = _buildHistoryAlertPolicyTypeSummary(
      historyAlerts: historyRollups['historyAlerts'],
      policy: alertFailurePolicy,
      thresholdOverride: failOnAlertThreshold,
      groupFilterOverride: failOnAlertGroupFilter,
      tagFilterOverride: failOnAlertTagFilter,
      categoryFilterOverride: failOnAlertCategoryFilter,
      statusFilterOverride: failOnAlertStatusFilter,
    );
    if (historyAlertPolicyTypeSummary.isNotEmpty) {
      summary['historyAlertPolicyTypeSummary'] = historyAlertPolicyTypeSummary;
    }
    final historyAlertPolicySuppressionSummary =
        _buildHistoryAlertPolicySuppressionSummary(
          historyAlerts: historyRollups['historyAlerts'],
          policy: alertFailurePolicy,
          thresholdOverride: failOnAlertThreshold,
          groupFilterOverride: failOnAlertGroupFilter,
          tagFilterOverride: failOnAlertTagFilter,
          categoryFilterOverride: failOnAlertCategoryFilter,
          statusFilterOverride: failOnAlertStatusFilter,
        );
    if (historyAlertPolicySuppressionSummary.isNotEmpty) {
      summary['historyAlertPolicySuppressionSummary'] =
          historyAlertPolicySuppressionSummary;
    }
    final historyAlertPolicySourceSummary =
        _buildHistoryAlertPolicySourceSummary(
          historyAlerts: historyRollups['historyAlerts'],
          policy: alertFailurePolicy,
          thresholdOverride: failOnAlertThreshold,
          groupFilterOverride: failOnAlertGroupFilter,
          tagFilterOverride: failOnAlertTagFilter,
          categoryFilterOverride: failOnAlertCategoryFilter,
          statusFilterOverride: failOnAlertStatusFilter,
        );
    if (historyAlertPolicySourceSummary.isNotEmpty) {
      summary['historyAlertPolicySourceSummary'] =
          historyAlertPolicySourceSummary;
    }

    if (jsonMode) {
      stdout.writeln(const JsonEncoder.withIndent('  ').convert(summary));
    } else {
      stdout.writeln(_buildConsoleSummary(summary));
    }
    if (failedCount > 0 || alertFailures.isNotEmpty) {
      exitCode = 1;
    }
  } on FileSystemException catch (error) {
    stderr.writeln(error.message);
    if (error.path != null) {
      stderr.writeln(error.path);
    }
    exitCode = 66;
  } on FormatException catch (error) {
    stderr.writeln('Scenario run failed: $error');
    exitCode = 65;
  } on UnsupportedError catch (error) {
    stderr.writeln('Scenario run failed: $error');
    exitCode = 65;
  } on StateError catch (error) {
    stderr.writeln('Scenario run failed: $error');
    exitCode = 65;
  } on Object catch (error, stackTrace) {
    stderr.writeln('Scenario run failed: $error');
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}

void _printUsage() {
  stdout.writeln('ONYX Scenario Runner');
  stdout.writeln();
  stdout.writeln(
    'Usage: dart run tool/run_onyx_scenario.dart [options] [scenario-file-or-directory]',
  );
  stdout.writeln();
  stdout.writeln('Options:');
  stdout.writeln(
    '  --json                  Print machine-readable summary JSON.',
  );
  stdout.writeln(
    '  --list                  List scenarios without executing them.',
  );
  stdout.writeln(
    '  --history               Also write each run to history results.',
  );
  stdout.writeln(
    '  --set=<name>            Filter listed or executed scenarios by scenarioSet (for example replay, validation, training).',
  );
  stdout.writeln(
    '  --status=<name>         Filter listed or executed scenarios by status (for example draft, validation_candidate, locked_validation).',
  );
  stdout.writeln(
    '  --policy=<path>         Load alert failure policy JSON from a checked-in file.',
  );
  stdout.writeln(
    '  --fail-on-alert=<level> Fail the run when history alerts meet or exceed the given severity (info, low, medium, high, critical).',
  );
  stdout.writeln(
    '  --fail-on-group=<name>  Restrict alert-triggered failure gating to a named policy group.',
  );
  stdout.writeln(
    '  --fail-on-tag=<name>   Restrict alert-triggered failure gating to a specific scenario tag.',
  );
  stdout.writeln(
    '  --fail-on-category=<name> Restrict alert-triggered failure gating to a specific scenario category.',
  );
  stdout.writeln(
    '  --fail-on-status=<name> Restrict alert-triggered failure gating to a specific scenario status.',
  );
  stdout.writeln(
    '  --results-dir=<path>    Override latest results output directory.',
  );
  stdout.writeln(
    '  --history-dir=<path>    Override history results output directory.',
  );
  stdout.writeln('  --help, -h              Show this help.');
}

String? _readOptionValue(List<String> args, String optionName) {
  for (final arg in args) {
    final trimmed = arg.trim();
    if (!trimmed.startsWith('$optionName=')) {
      continue;
    }
    return trimmed.substring(optionName.length + 1).trim();
  }
  return null;
}

String? _normalizeAlertSeverityOption(String? value) {
  final normalized = value?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  if (!_isRecognizedAlertSeverity(normalized)) {
    throw FormatException(
      'Unsupported alert severity "$normalized". Expected one of: info, low, medium, high, critical.',
    );
  }
  return normalized;
}

bool _isRecognizedAlertSeverity(String value) {
  switch (value.trim().toLowerCase()) {
    case 'info':
    case 'low':
    case 'medium':
    case 'high':
    case 'critical':
      return true;
  }
  return false;
}

Future<_AlertFailurePolicy?> _loadAlertFailurePolicy({
  required String workspaceRoot,
  required String? policyPath,
}) async {
  final normalizedPath = policyPath?.trim();
  if (normalizedPath == null || normalizedPath.isEmpty) {
    return null;
  }
  final resolvedPath = _resolvePath(workspaceRoot, normalizedPath);
  final file = File(resolvedPath);
  if (!file.existsSync()) {
    throw FileSystemException('Scenario policy does not exist.', resolvedPath);
  }
  final decoded = jsonDecode(await file.readAsString());
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException(
      'Scenario policy must decode to a JSON object.',
    );
  }
  return _AlertFailurePolicy.fromJson(decoded, path: resolvedPath);
}

String? _normalizeOptionalFilterValue(String? value) {
  final normalized = value?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}

List<String> _readNormalizedStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return const <String>[];
  }
  if (value is! List) {
    throw FormatException('Expected "$key" to be a list.');
  }
  return value
      .map((dynamic item) {
        if (item is! String) {
          throw FormatException('Expected all items in "$key" to be strings.');
        }
        final normalized = item.trim().toLowerCase();
        if (normalized.isEmpty) {
          throw FormatException(
            'Expected all items in "$key" to be non-empty.',
          );
        }
        return normalized;
      })
      .toList(growable: false);
}

List<String> _readTrimmedStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return const <String>[];
  }
  if (value is! List) {
    throw FormatException('Expected "$key" to be a list.');
  }
  return value
      .map((dynamic item) {
        if (item is! String) {
          throw FormatException('Expected all items in "$key" to be strings.');
        }
        final trimmed = item.trim();
        if (trimmed.isEmpty) {
          throw FormatException(
            'Expected all items in "$key" to be non-empty.',
          );
        }
        return trimmed;
      })
      .toList(growable: false);
}

String? _readNormalizedAlertScope(Map<String, dynamic> alert) {
  final normalizedScope = alert['scope']?.toString().trim().toLowerCase();
  if (normalizedScope == null || normalizedScope.isEmpty) {
    return null;
  }
  return normalizedScope;
}

Map<String, String> _readAlertSeverityByScope(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];
  if (value == null) {
    return const <String, String>{};
  }
  if (value is! Map<String, dynamic>) {
    throw FormatException('Expected "$key" to be a JSON object.');
  }
  final summary = <String, String>{};
  for (final entry in value.entries) {
    final normalizedScope = entry.key.trim().toLowerCase();
    if (normalizedScope.isEmpty) {
      throw FormatException(
        'Expected all keys in "$key" to be non-empty scope names.',
      );
    }
    final severity = _normalizeAlertSeverityOption(entry.value?.toString());
    if (severity == null) {
      throw FormatException(
        'Expected all values in "$key" to be non-empty alert severities.',
      );
    }
    summary[normalizedScope] = severity;
  }
  return Map<String, String>.unmodifiable(summary);
}

List<String> _resolveScenarioPaths({
  required String workspaceRoot,
  required String targetPath,
}) {
  final resolvedTarget = _resolvePath(workspaceRoot, targetPath);
  final file = File(resolvedTarget);
  if (file.existsSync()) {
    if (!resolvedTarget.endsWith('.json')) {
      throw FileSystemException(
        'Scenario target must be a JSON file or directory.',
        resolvedTarget,
      );
    }
    return <String>[resolvedTarget];
  }

  final directory = Directory(resolvedTarget);
  if (!directory.existsSync()) {
    throw FileSystemException(
      'Scenario target does not exist.',
      resolvedTarget,
    );
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

Map<String, dynamic> _buildRecord({
  required String scenarioPath,
  required String scenarioCategory,
  required String scenarioSet,
  required String scenarioStatus,
  required ScenarioResult result,
  String? historyFilePath,
}) {
  final mismatchFields = result.mismatches
      .map((mismatch) => mismatch.field)
      .toList(growable: false);
  final commandBrainSnapshot = result.actualOutcome.commandBrainSnapshot;
  final commandBrainTimeline = result.actualOutcome.commandBrainTimeline;
  final orderedReplayBiasStack =
      commandBrainSnapshot?.orderedReplayBiasStack ??
      const <BrainDecisionBias>[];
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
  final sequenceFallbackLifecycleRecord = _buildSequenceFallbackLifecycleRecord(
    result.actualOutcome,
  );
  final commandBrainTimelineSignature = commandBrainTimeline.isEmpty
      ? null
      : commandBrainTimeline
            .map((entry) => entry.signatureSegment)
            .join(' -> ');
  return <String, dynamic>{
    'scenarioPath': scenarioPath,
    'scenarioId': result.scenarioId,
    'category': scenarioCategory,
    'scenarioSet': scenarioSet,
    'status': scenarioStatus,
    'passed': result.passed,
    'runId': result.runId.toUtc().toIso8601String(),
    'actualRoute': result.actualOutcome.actualRoute,
    'mismatchCount': result.mismatches.length,
    'mismatchFields': mismatchFields,
    'mismatches': result.mismatches
        .map((mismatch) => mismatch.toJson())
        .toList(),
    if (commandBrainSnapshot != null)
      'commandBrainFinalTarget': commandBrainSnapshot.target.name,
    if (commandBrainSnapshot != null)
      'commandBrainFinalMode': commandBrainSnapshot.mode.name,
    if (commandBrainSnapshot?.decisionBias != null)
      'commandBrainFinalBiasSource':
          commandBrainSnapshot!.decisionBias!.source.name,
    if (commandBrainSnapshot?.decisionBias != null)
      'commandBrainFinalBiasScope':
          commandBrainSnapshot!.decisionBias!.scope.name,
    if (commandBrainSnapshot?.decisionBias != null)
      'commandBrainFinalBiasSignature':
          '${commandBrainSnapshot!.decisionBias!.source.name}:${commandBrainSnapshot.decisionBias!.scope.name}',
    if (orderedReplayBiasStack.isNotEmpty)
      'commandBrainFinalReplayBiasStackLength': orderedReplayBiasStack.length,
    if (commandBrainSnapshot?.replayBiasStackSignature != null)
      'commandBrainFinalReplayBiasStackSignature':
          commandBrainSnapshot!.replayBiasStackSignature,
    if (commandBrainTimeline.isNotEmpty)
      'commandBrainTimelineLength': commandBrainTimeline.length,
    if (commandBrainTimeline.isNotEmpty)
      'commandBrainTimelineStages': commandBrainTimeline
          .map((entry) => entry.stage)
          .toList(growable: false),
    if (commandBrainTimeline.isNotEmpty)
      'commandBrainTimelineTargets': commandBrainTimeline
          .map((entry) => entry.snapshot.target.name)
          .toList(growable: false),
    'commandBrainTimelineSignature': ?commandBrainTimelineSignature,
    if (specialistDegradationRecord != null) ...specialistDegradationRecord,
    if (specialistConflictRecord != null) ...specialistConflictRecord,
    if (specialistConflictLifecycleRecord != null)
      ...specialistConflictLifecycleRecord,
    if (specialistConstraintRecord != null) ...specialistConstraintRecord,
    if (specialistConstraintLifecycleRecord != null)
      ...specialistConstraintLifecycleRecord,
    if (sequenceFallbackLifecycleRecord != null)
      ...sequenceFallbackLifecycleRecord,
    'historyFilePath': ?historyFilePath,
  };
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
    'specialistDegradationCount': specialistStatusEntries.length,
    'specialistDegradationSpecialists': specialistNames,
    'specialistDegradationStatuses': specialistStatusEntries,
    'specialistDegradationSignature':
        '$branch:${specialistStatusEntries.join('|')}',
  };
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
  final branch = 'persistent';
  final signature = summary != null
      ? '$branch:$summary'
      : '$branch:${specialists.join('|')}=>${targets.join('|')}';
  return <String, dynamic>{
    'specialistConflictBranch': branch,
    if (actualUiState['specialistConflictCount'] is int)
      'specialistConflictCount': actualUiState['specialistConflictCount'],
    if (specialists.isNotEmpty) 'specialistConflictSpecialists': specialists,
    if (targets.isNotEmpty) 'specialistConflictTargets': targets,
    'specialistConflictSummary': ?summary,
    'specialistConflictSignature': signature,
  };
}

String _classifySpecialistDegradationBranch(String notes) {
  final normalizedNotes = notes.trim().toLowerCase();
  if (normalizedNotes.contains('rerouted ')) {
    return 'recovered';
  }
  return 'persistent';
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
  final specialistSegment = specialists.isEmpty
      ? 'unknown'
      : specialists.join('|');
  final targetSegment = targets.isEmpty ? 'unknown' : targets.join('|');
  final signature = lifecycle == 'recovered_in_run'
      ? '$lifecycle:$specialistSegment:$targetSegment:$clearedByStepId'
      : '$lifecycle:$specialistSegment:$targetSegment';

  return <String, dynamic>{
    'specialistConflictLifecycle': lifecycle,
    'specialistConflictLifecycleSummary': ?summary,
    if (specialists.isNotEmpty)
      'specialistConflictLifecycleSpecialists': specialists,
    if (targets.isNotEmpty) 'specialistConflictLifecycleTargets': targets,
    'specialistConflictLifecycleRecovered': lifecycle == 'recovered_in_run',
    'specialistConflictLifecycleSignature': signature,
    if (clearedByStepId != null && clearedByStepId.isNotEmpty)
      'specialistConflictRecoveryStage': clearedByStepId,
  };
}

Map<String, dynamic>? _buildSpecialistConstraintLifecycleRecord(
  ScenarioActualOutcome actualOutcome,
) {
  String? specialist;
  String? constrainedTarget;
  String? clearedTarget;
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
      clearedTarget ??= _readNormalizedString(keyedChange['previousTarget']);
    }
  }

  final target = clearedTarget ?? constrainedTarget;
  if (specialist == null ||
      specialist.isEmpty ||
      target == null ||
      target.isEmpty) {
    return null;
  }

  final lifecycle = clearedByStepId == null || clearedByStepId.isEmpty
      ? 'active_in_run'
      : 'recovered_in_run';
  final signature = lifecycle == 'recovered_in_run'
      ? '$lifecycle:$specialist:$target:$clearedByStepId'
      : '$lifecycle:$specialist:$target';

  return <String, dynamic>{
    'specialistConstraintLifecycle': lifecycle,
    'specialistConstraintLifecycleSpecialist': specialist,
    'specialistConstraintLifecycleTarget': target,
    'specialistConstraintLifecycleRecovered': lifecycle == 'recovered_in_run',
    'specialistConstraintLifecycleSignature': signature,
    if (clearedByStepId != null && clearedByStepId.isNotEmpty)
      'specialistConstraintRecoveryStage': clearedByStepId,
  };
}

Map<String, dynamic>? _buildSequenceFallbackLifecycleRecord(
  ScenarioActualOutcome actualOutcome,
) {
  final decisionBias = actualOutcome.commandBrainSnapshot?.decisionBias;
  if (decisionBias == null ||
      decisionBias.source != BrainDecisionBiasSource.replayPolicy ||
      decisionBias.scope != BrainDecisionBiasScope.sequenceFallback) {
    return null;
  }

  final target = decisionBias.preferredTarget.name;
  return <String, dynamic>{
    'sequenceFallbackLifecycle': 'active_in_run',
    'sequenceFallbackLifecycleTarget': target,
    'sequenceFallbackLifecycleRecovered': false,
    'sequenceFallbackLifecycleSignature':
        'active_in_run:${decisionBias.source.name}:${decisionBias.scope.name}:$target',
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

Future<List<_ResolvedScenario>> _loadResolvedScenarios({
  required List<String> scenarioPaths,
  String? scenarioSetFilter,
  String? scenarioStatusFilter,
}) async {
  final scenarios = <_ResolvedScenario>[];
  final normalizedSetFilter = scenarioSetFilter?.trim().toLowerCase();
  final normalizedStatusFilter = scenarioStatusFilter?.trim().toLowerCase();

  for (final scenarioPath in scenarioPaths) {
    final definition = ScenarioDefinition.fromJsonString(
      await File(scenarioPath).readAsString(),
    );
    final scenarioSet = definition.scenarioSet.trim().toLowerCase();
    final scenarioStatus = definition.status.trim().toLowerCase();
    if (normalizedSetFilter != null &&
        normalizedSetFilter.isNotEmpty &&
        scenarioSet != normalizedSetFilter) {
      continue;
    }
    if (normalizedStatusFilter != null &&
        normalizedStatusFilter.isNotEmpty &&
        scenarioStatus != normalizedStatusFilter) {
      continue;
    }
    scenarios.add(
      _ResolvedScenario(path: scenarioPath, definition: definition),
    );
  }

  scenarios.sort((left, right) {
    final categoryOrder = left.definition.category.compareTo(
      right.definition.category,
    );
    if (categoryOrder != 0) {
      return categoryOrder;
    }
    return left.definition.scenarioId.compareTo(right.definition.scenarioId);
  });

  return scenarios;
}

Map<String, dynamic> _buildScenarioIndex({
  required List<_ResolvedScenario> resolvedScenarios,
  String? scenarioSetFilter,
  String? scenarioStatusFilter,
}) {
  final scenarios = <Map<String, dynamic>>[];
  final categoryCounts = <String, int>{};
  final setCounts = <String, int>{};
  final statusCounts = <String, int>{};
  final normalizedSetFilter = scenarioSetFilter?.trim().toLowerCase();
  final normalizedStatusFilter = scenarioStatusFilter?.trim().toLowerCase();

  for (final resolvedScenario in resolvedScenarios) {
    final definition = resolvedScenario.definition;
    categoryCounts.update(
      definition.category,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    setCounts.update(
      definition.scenarioSet,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    statusCounts.update(
      definition.status,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    scenarios.add(<String, dynamic>{
      'scenarioId': definition.scenarioId,
      'title': definition.title,
      'category': definition.category,
      'scenarioSet': definition.scenarioSet,
      'status': definition.status,
      'tags': definition.tags,
      'path': resolvedScenario.path,
    });
  }

  return <String, dynamic>{
    'scenarioCount': scenarios.length,
    if (normalizedSetFilter != null && normalizedSetFilter.isNotEmpty)
      'scenarioSetFilter': normalizedSetFilter,
    if (normalizedStatusFilter != null && normalizedStatusFilter.isNotEmpty)
      'scenarioStatusFilter': normalizedStatusFilter,
    'categoryCounts': categoryCounts,
    'scenarioSetCounts': setCounts,
    'scenarioStatusCounts': statusCounts,
    'scenarios': scenarios,
  };
}

String _buildConsoleSummary(Map<String, dynamic> summary) {
  final buffer = StringBuffer()
    ..writeln('ONYX SCENARIO RUNNER')
    ..writeln('Target: ${summary['targetPath']}')
    ..write(
      summary['scenarioSetFilter'] != null
          ? 'Scenario set filter: ${summary['scenarioSetFilter']}\n'
          : '',
    )
    ..write(
      summary['scenarioStatusFilter'] != null
          ? 'Scenario status filter: ${summary['scenarioStatusFilter']}\n'
          : '',
    )
    ..write(
      summary['alertFailurePolicyPath'] != null
          ? 'Alert failure policy: ${summary['alertFailurePolicyPath']}\n'
          : '',
    )
    ..write(
      summary['alertFailureThreshold'] != null
          ? 'Alert failure threshold: ${summary['alertFailureThreshold']}\n'
          : '',
    )
    ..write(
      summary['alertFailureGroupFilter'] != null
          ? 'Alert failure group filter: ${summary['alertFailureGroupFilter']}\n'
          : '',
    )
    ..write(
      summary['alertFailureTagFilter'] != null
          ? 'Alert failure tag filter: ${summary['alertFailureTagFilter']}\n'
          : '',
    )
    ..write(
      summary['alertFailureCategoryFilter'] != null
          ? 'Alert failure category filter: ${summary['alertFailureCategoryFilter']}\n'
          : '',
    )
    ..write(
      summary['alertFailureStatusFilter'] != null
          ? 'Alert failure status filter: ${summary['alertFailureStatusFilter']}\n'
          : '',
    )
    ..write(
      summary['alertFailureCategoryAllowlist'] != null
          ? 'Alert failure category allowlist: ${(summary['alertFailureCategoryAllowlist'] as List).join(', ')}\n'
          : '',
    )
    ..write(
      summary['alertFailureStatusAllowlist'] != null
          ? 'Alert failure status allowlist: ${(summary['alertFailureStatusAllowlist'] as List).join(', ')}\n'
          : '',
    )
    ..write(
      summary['alertFailureCategoryDenylist'] != null
          ? 'Alert failure category denylist: ${(summary['alertFailureCategoryDenylist'] as List).join(', ')}\n'
          : '',
    )
    ..write(
      summary['alertFailureStatusDenylist'] != null
          ? 'Alert failure status denylist: ${(summary['alertFailureStatusDenylist'] as List).join(', ')}\n'
          : '',
    )
    ..writeln('Scenarios: ${summary['scenarioCount']}')
    ..writeln('Passed: ${summary['passedCount']}')
    ..writeln('Failed: ${summary['failedCount']}');

  if (summary['alertFailureTriggered'] == true) {
    buffer
      ..writeln('Alert threshold triggered: true')
      ..writeln('Alert-triggered failures: ${summary['alertFailureCount']}');
  }

  final scenarioSetSummary = summary['scenarioSetSummary'];
  if (scenarioSetSummary is Map && scenarioSetSummary.isNotEmpty) {
    buffer.writeln('Run sets:');
    final entries = scenarioSetSummary.entries.toList()
      ..sort(
        (left, right) => left.key.toString().compareTo(right.key.toString()),
      );
    for (final entry in entries) {
      final value = entry.value;
      if (value is! Map) {
        continue;
      }
      buffer.writeln(
        '- ${entry.key}: ${value['passedCount']}/${value['scenarioCount']} passed',
      );
    }
  }

  final scenarioCategorySummary = summary['scenarioCategorySummary'];
  if (scenarioCategorySummary is Map && scenarioCategorySummary.isNotEmpty) {
    buffer.writeln('Run categories:');
    final entries = scenarioCategorySummary.entries.toList()
      ..sort(
        (left, right) => left.key.toString().compareTo(right.key.toString()),
      );
    for (final entry in entries) {
      final value = entry.value;
      if (value is! Map) {
        continue;
      }
      buffer.writeln(
        '- ${entry.key}: ${value['passedCount']}/${value['scenarioCount']} passed',
      );
    }
  }

  final scenarioStatusSummary = summary['scenarioStatusSummary'];
  if (scenarioStatusSummary is Map && scenarioStatusSummary.isNotEmpty) {
    buffer.writeln('Run statuses:');
    final entries = scenarioStatusSummary.entries.toList()
      ..sort(
        (left, right) => left.key.toString().compareTo(right.key.toString()),
      );
    for (final entry in entries) {
      final value = entry.value;
      if (value is! Map) {
        continue;
      }
      buffer.writeln(
        '- ${entry.key}: ${value['passedCount']}/${value['scenarioCount']} passed',
      );
    }
  }

  final commandBrainFinalBiasSourceSummary =
      summary['commandBrainFinalBiasSourceSummary'];
  if (commandBrainFinalBiasSourceSummary is Map &&
      commandBrainFinalBiasSourceSummary.isNotEmpty) {
    buffer.writeln('Run command brain bias sources:');
    final entries = commandBrainFinalBiasSourceSummary.entries.toList()
      ..sort(
        (left, right) => left.key.toString().compareTo(right.key.toString()),
      );
    for (final entry in entries) {
      final value = entry.value;
      if (value is! Map) {
        continue;
      }
      buffer.writeln(
        '- ${entry.key}: ${value['passedCount']}/${value['scenarioCount']} passed',
      );
    }
  }

  final commandBrainFinalBiasScopeSummary =
      summary['commandBrainFinalBiasScopeSummary'];
  if (commandBrainFinalBiasScopeSummary is Map &&
      commandBrainFinalBiasScopeSummary.isNotEmpty) {
    buffer.writeln('Run command brain bias scopes:');
    final entries = commandBrainFinalBiasScopeSummary.entries.toList()
      ..sort(
        (left, right) => left.key.toString().compareTo(right.key.toString()),
      );
    for (final entry in entries) {
      final value = entry.value;
      if (value is! Map) {
        continue;
      }
      buffer.writeln(
        '- ${entry.key}: ${value['passedCount']}/${value['scenarioCount']} passed',
      );
    }
  }

  final mismatchFieldSummary = summary['mismatchFieldSummary'];
  if (mismatchFieldSummary is Map && mismatchFieldSummary.isNotEmpty) {
    buffer.writeln('Mismatch fields:');
    final entries = mismatchFieldSummary.entries.toList()
      ..sort(_compareMismatchFieldCountEntries);
    for (final entry in entries) {
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
  }

  final categoryMismatchFieldSummary = summary['categoryMismatchFieldSummary'];
  if (categoryMismatchFieldSummary is Map &&
      categoryMismatchFieldSummary.isNotEmpty) {
    buffer.writeln('Category mismatch fields:');
    final categoryEntries = categoryMismatchFieldSummary.entries.toList()
      ..sort(
        (left, right) => left.key.toString().compareTo(right.key.toString()),
      );
    for (final categoryEntry in categoryEntries) {
      final value = categoryEntry.value;
      if (value is! Map || value.isEmpty) {
        continue;
      }
      final fieldEntries = value.entries.toList()
        ..sort(_compareMismatchFieldCountEntries);
      final fieldSummary = fieldEntries
          .map((entry) => '${entry.key}=${entry.value}')
          .join(', ');
      buffer.writeln('- ${categoryEntry.key}: $fieldSummary');
    }
  }

  final historyFocusSummary = summary['historyFocusSummary'];
  if (historyFocusSummary is Map && historyFocusSummary.isNotEmpty) {
    buffer.writeln('History focus:');
    final topScenario = historyFocusSummary['topScenario'];
    if (topScenario is Map) {
      final fieldSuffix = _buildHistoryFocusFieldConsoleSuffix(topScenario);
      buffer.writeln(
        '- scenario: ${topScenario['scenarioId']} (${topScenario['trend']}, failed ${topScenario['failedCount']}, last run ${topScenario['lastRunAt']})$fieldSuffix',
      );
    }
    final topCategory = historyFocusSummary['topCategory'];
    if (topCategory is Map) {
      final fieldSuffix = _buildHistoryFocusFieldConsoleSuffix(topCategory);
      buffer.writeln(
        '- category: ${topCategory['category']} (${topCategory['trend']}, failed ${topCategory['failedCount']}, last run ${topCategory['lastRunAt']})$fieldSuffix',
      );
    }
    final topTag = historyFocusSummary['topTag'];
    if (topTag is Map) {
      final fieldSuffix = _buildHistoryFocusFieldConsoleSuffix(topTag);
      buffer.writeln(
        '- tag: ${topTag['tag']} (${topTag['trend']}, failed ${topTag['failedCount']}, last run ${topTag['lastRunAt']})$fieldSuffix',
      );
    }
    final topConflictRecoveryScenario =
        historyFocusSummary['topConflictRecoveryScenario'];
    if (topConflictRecoveryScenario is Map) {
      final recoveryStageSuffix =
          topConflictRecoveryScenario['latestRecoveryStage'] != null
          ? ', stage ${topConflictRecoveryScenario['latestRecoveryStage']}'
          : '';
      final summarySuffix = topConflictRecoveryScenario['latestSummary'] != null
          ? ', summary ${topConflictRecoveryScenario['latestSummary']}'
          : '';
      buffer.writeln(
        '- conflict recovery: ${topConflictRecoveryScenario['scenarioId']} (${topConflictRecoveryScenario['recoveryTrend']}, recovered ${topConflictRecoveryScenario['recoveredInRunCount']}, last run ${topConflictRecoveryScenario['lastRunAt']}$recoveryStageSuffix$summarySuffix)',
      );
    }
    final topConstraintRecoveryScenario =
        historyFocusSummary['topConstraintRecoveryScenario'];
    if (topConstraintRecoveryScenario is Map) {
      final recoveryStageSuffix =
          topConstraintRecoveryScenario['latestRecoveryStage'] != null
          ? ', stage ${topConstraintRecoveryScenario['latestRecoveryStage']}'
          : '';
      final targetSuffix = topConstraintRecoveryScenario['latestTarget'] != null
          ? ', target ${topConstraintRecoveryScenario['latestTarget']}'
          : '';
      buffer.writeln(
        '- constraint recovery: ${topConstraintRecoveryScenario['scenarioId']} (${topConstraintRecoveryScenario['recoveryTrend']}, recovered ${topConstraintRecoveryScenario['recoveredInRunCount']}, last run ${topConstraintRecoveryScenario['lastRunAt']}$recoveryStageSuffix$targetSuffix)',
      );
    }
    final topSequenceFallbackRecoveryScenario =
        historyFocusSummary['topSequenceFallbackRecoveryScenario'];
    if (topSequenceFallbackRecoveryScenario is Map) {
      final targetSuffix =
          topSequenceFallbackRecoveryScenario['latestTarget'] != null
          ? ', target ${topSequenceFallbackRecoveryScenario['latestTarget']}'
          : '';
      final restoredTargetSuffix =
          topSequenceFallbackRecoveryScenario['latestRestoredTarget'] != null
          ? ', restored ${topSequenceFallbackRecoveryScenario['latestRestoredTarget']}'
          : '';
      buffer.writeln(
        '- sequence fallback recovery: ${topSequenceFallbackRecoveryScenario['scenarioId']} (${topSequenceFallbackRecoveryScenario['recoveryTrend']}, cleared ${topSequenceFallbackRecoveryScenario['clearedAfterRunCount']}, last run ${topSequenceFallbackRecoveryScenario['lastRunAt']}$targetSuffix$restoredTargetSuffix)',
      );
    }
    final topPolicyPromotedReplayRiskScenario =
        historyFocusSummary['topPolicyPromotedReplayRiskScenario'];
    if (topPolicyPromotedReplayRiskScenario is Map) {
      final scopeSuffix = topPolicyPromotedReplayRiskScenario['scope'] != null
          ? ', scope ${topPolicyPromotedReplayRiskScenario['scope']}'
          : '';
      final severitySuffix = _buildPolicySeverityTransitionConsoleLabel(
        topPolicyPromotedReplayRiskScenario,
        severityKey: 'promotedSeverity',
      );
      final sourceSuffix =
          topPolicyPromotedReplayRiskScenario['policyMatchSource'] != null
          ? ', source ${topPolicyPromotedReplayRiskScenario['policyMatchSource']}'
          : '';
      final countSuffix = topPolicyPromotedReplayRiskScenario['count'] != null
          ? ', count ${topPolicyPromotedReplayRiskScenario['count']}'
          : '';
      buffer.writeln(
        '- policy-promoted replay risk: ${topPolicyPromotedReplayRiskScenario['scenarioId']} (${topPolicyPromotedReplayRiskScenario['trend']}, last run ${topPolicyPromotedReplayRiskScenario['lastRunAt']}$scopeSuffix$severitySuffix$sourceSuffix$countSuffix)',
      );
    }
    final topPolicyPromotedSpecialistScenario =
        historyFocusSummary['topPolicyPromotedSpecialistScenario'];
    if (topPolicyPromotedSpecialistScenario is Map) {
      final scopeSuffix = topPolicyPromotedSpecialistScenario['scope'] != null
          ? ', scope ${topPolicyPromotedSpecialistScenario['scope']}'
          : '';
      final severitySuffix = _buildPolicySeverityTransitionConsoleLabel(
        topPolicyPromotedSpecialistScenario,
        severityKey: 'promotedSeverity',
      );
      final sourceSuffix =
          topPolicyPromotedSpecialistScenario['policyMatchSource'] != null
          ? ', source ${topPolicyPromotedSpecialistScenario['policyMatchSource']}'
          : '';
      final countSuffix = topPolicyPromotedSpecialistScenario['count'] != null
          ? ', count ${topPolicyPromotedSpecialistScenario['count']}'
          : '';
      buffer.writeln(
        '- policy-promoted specialist risk: ${topPolicyPromotedSpecialistScenario['scenarioId']} (${topPolicyPromotedSpecialistScenario['trend']}, last run ${topPolicyPromotedSpecialistScenario['lastRunAt']}$scopeSuffix$severitySuffix$sourceSuffix$countSuffix)',
      );
    }
  }

  final historyCategorySummary = summary['historyCategorySummary'];
  if (historyCategorySummary is Map && historyCategorySummary.isNotEmpty) {
    buffer.writeln('History categories:');
    final entries = historyCategorySummary.entries.toList()
      ..sort(
        (left, right) => left.key.toString().compareTo(right.key.toString()),
      );
    for (final entry in entries) {
      final value = entry.value;
      if (value is! Map) {
        continue;
      }
      buffer.writeln(
        '- ${entry.key}: ${value['passedCount']}/${value['runCount']} passed, trend ${value['trend']}, last run ${value['lastRunAt']}',
      );
    }
  }

  final historyCommandBrainFinalBiasSourceSummary =
      summary['historyCommandBrainFinalBiasSourceSummary'];
  if (historyCommandBrainFinalBiasSourceSummary is Map &&
      historyCommandBrainFinalBiasSourceSummary.isNotEmpty) {
    buffer.writeln('History command brain bias sources:');
    final entries = historyCommandBrainFinalBiasSourceSummary.entries.toList()
      ..sort(
        (left, right) => left.key.toString().compareTo(right.key.toString()),
      );
    for (final entry in entries) {
      final value = entry.value;
      if (value is! Map) {
        continue;
      }
      buffer.writeln(
        '- ${entry.key}: ${value['passedCount']}/${value['runCount']} passed, trend ${value['trend']}, last run ${value['lastRunAt']}',
      );
    }
  }

  final historyCommandBrainFinalBiasScopeSummary =
      summary['historyCommandBrainFinalBiasScopeSummary'];
  if (historyCommandBrainFinalBiasScopeSummary is Map &&
      historyCommandBrainFinalBiasScopeSummary.isNotEmpty) {
    buffer.writeln('History command brain bias scopes:');
    final entries = historyCommandBrainFinalBiasScopeSummary.entries.toList()
      ..sort(
        (left, right) => left.key.toString().compareTo(right.key.toString()),
      );
    for (final entry in entries) {
      final value = entry.value;
      if (value is! Map) {
        continue;
      }
      buffer.writeln(
        '- ${entry.key}: ${value['passedCount']}/${value['runCount']} passed, trend ${value['trend']}, last run ${value['lastRunAt']}',
      );
    }
  }

  final historyTagSummary = summary['historyTagSummary'];
  if (historyTagSummary is Map && historyTagSummary.isNotEmpty) {
    buffer.writeln('History tags:');
    final entries = historyTagSummary.entries.toList()
      ..sort((left, right) {
        final leftValue = left.value;
        final rightValue = right.value;
        final leftFailedCount =
            leftValue is Map && leftValue['failedCount'] is int
            ? leftValue['failedCount'] as int
            : 0;
        final rightFailedCount =
            rightValue is Map && rightValue['failedCount'] is int
            ? rightValue['failedCount'] as int
            : 0;
        if (leftFailedCount != rightFailedCount) {
          return rightFailedCount.compareTo(leftFailedCount);
        }
        return left.key.toString().compareTo(right.key.toString());
      });
    for (final entry in entries) {
      final value = entry.value;
      if (value is! Map) {
        continue;
      }
      buffer.writeln(
        '- ${entry.key}: ${value['passedCount']}/${value['runCount']} passed, failed ${value['failedCount']}, trend ${value['trend']}, last run ${value['lastRunAt']}',
      );
    }
  }

  final historyScenarioSummary = summary['historyScenarioSummary'];
  if (historyScenarioSummary is Map && historyScenarioSummary.isNotEmpty) {
    buffer.writeln('History scenarios:');
    final entries = historyScenarioSummary.entries.toList()
      ..sort((left, right) {
        final leftValue = left.value;
        final rightValue = right.value;
        final leftFailedCount =
            leftValue is Map && leftValue['failedCount'] is int
            ? leftValue['failedCount'] as int
            : 0;
        final rightFailedCount =
            rightValue is Map && rightValue['failedCount'] is int
            ? rightValue['failedCount'] as int
            : 0;
        if (leftFailedCount != rightFailedCount) {
          return rightFailedCount.compareTo(leftFailedCount);
        }
        return left.key.toString().compareTo(right.key.toString());
      });
    for (final entry in entries) {
      final value = entry.value;
      if (value is! Map) {
        continue;
      }
      buffer.writeln(
        '- ${entry.key}: ${value['passedCount']}/${value['runCount']} passed, failed ${value['failedCount']}, trend ${value['trend']}, last run ${value['lastRunAt']}',
      );
    }
  }

  final specialistConflictLifecycleSummary =
      summary['specialistConflictLifecycleSummary'];
  if (specialistConflictLifecycleSummary is Map &&
      specialistConflictLifecycleSummary.isNotEmpty) {
    buffer.writeln('Run specialist conflict lifecycle:');
    final lifecycleEntries = specialistConflictLifecycleSummary.entries.toList()
      ..sort(_compareMismatchFieldCountEntries);
    for (final entry in lifecycleEntries) {
      final value = entry.value;
      if (value is! Map) {
        continue;
      }
      buffer.writeln(
        '- ${entry.key}: ${value['passedCount']}/${value['scenarioCount']} passed',
      );
    }
  }

  final historySpecialistConflictLifecycleSummary =
      summary['historySpecialistConflictLifecycleSummary'];
  if (historySpecialistConflictLifecycleSummary is Map &&
      historySpecialistConflictLifecycleSummary.isNotEmpty) {
    buffer.writeln('History specialist conflict lifecycle:');
    final lifecycleEntries =
        historySpecialistConflictLifecycleSummary.entries.toList()
          ..sort(_compareMismatchFieldCountEntries);
    for (final entry in lifecycleEntries) {
      final value = entry.value;
      if (value is! Map) {
        continue;
      }
      buffer.writeln(
        '- ${entry.key}: ${value['passedCount']}/${value['scenarioCount']} passed',
      );
    }
  }

  final specialistConstraintLifecycleSummary =
      summary['specialistConstraintLifecycleSummary'];
  if (specialistConstraintLifecycleSummary is Map &&
      specialistConstraintLifecycleSummary.isNotEmpty) {
    buffer.writeln('Run specialist constraint lifecycle:');
    final lifecycleEntries =
        specialistConstraintLifecycleSummary.entries.toList()
          ..sort(_compareMismatchFieldCountEntries);
    for (final entry in lifecycleEntries) {
      final value = entry.value;
      if (value is! Map) {
        continue;
      }
      buffer.writeln(
        '- ${entry.key}: ${value['passedCount']}/${value['scenarioCount']} passed',
      );
    }
  }

  final sequenceFallbackLifecycleSummary =
      summary['sequenceFallbackLifecycleSummary'];
  if (sequenceFallbackLifecycleSummary is Map &&
      sequenceFallbackLifecycleSummary.isNotEmpty) {
    buffer.writeln('Run sequence fallback lifecycle:');
    final lifecycleEntries = sequenceFallbackLifecycleSummary.entries.toList()
      ..sort(_compareMismatchFieldCountEntries);
    for (final entry in lifecycleEntries) {
      final value = entry.value;
      if (value is! Map) {
        continue;
      }
      buffer.writeln(
        '- ${entry.key}: ${value['passedCount']}/${value['scenarioCount']} passed',
      );
    }
  }

  final historySpecialistConstraintLifecycleSummary =
      summary['historySpecialistConstraintLifecycleSummary'];
  if (historySpecialistConstraintLifecycleSummary is Map &&
      historySpecialistConstraintLifecycleSummary.isNotEmpty) {
    buffer.writeln('History specialist constraint lifecycle:');
    final lifecycleEntries =
        historySpecialistConstraintLifecycleSummary.entries.toList()
          ..sort(_compareMismatchFieldCountEntries);
    for (final entry in lifecycleEntries) {
      final value = entry.value;
      if (value is! Map) {
        continue;
      }
      buffer.writeln(
        '- ${entry.key}: ${value['passedCount']}/${value['scenarioCount']} passed',
      );
    }
  }

  final historySequenceFallbackLifecycleSummary =
      summary['historySequenceFallbackLifecycleSummary'];
  if (historySequenceFallbackLifecycleSummary is Map &&
      historySequenceFallbackLifecycleSummary.isNotEmpty) {
    buffer.writeln('History sequence fallback lifecycle:');
    final lifecycleEntries =
        historySequenceFallbackLifecycleSummary.entries.toList()
          ..sort(_compareMismatchFieldCountEntries);
    for (final entry in lifecycleEntries) {
      final value = entry.value;
      if (value is! Map) {
        continue;
      }
      buffer.writeln(
        '- ${entry.key}: ${value['passedCount']}/${value['scenarioCount']} passed',
      );
    }
  }

  final historyCategoryMismatchFieldSummary =
      summary['historyCategoryMismatchFieldSummary'];
  if (historyCategoryMismatchFieldSummary is Map &&
      historyCategoryMismatchFieldSummary.isNotEmpty) {
    buffer.writeln('History category mismatch fields:');
    final categoryEntries = historyCategoryMismatchFieldSummary.entries.toList()
      ..sort(
        (left, right) => left.key.toString().compareTo(right.key.toString()),
      );
    for (final categoryEntry in categoryEntries) {
      final value = categoryEntry.value;
      if (value is! Map || value.isEmpty) {
        continue;
      }
      final fieldEntries = value.entries.toList()
        ..sort(_compareMismatchFieldCountEntries);
      final fieldSummary = fieldEntries
          .map((entry) => '${entry.key}=${entry.value}')
          .join(', ');
      buffer.writeln('- ${categoryEntry.key}: $fieldSummary');
    }
  }

  final historyCategoryMismatchFieldTrendSummary =
      summary['historyCategoryMismatchFieldTrendSummary'];
  if (historyCategoryMismatchFieldTrendSummary is Map &&
      historyCategoryMismatchFieldTrendSummary.isNotEmpty) {
    buffer.writeln('History category mismatch trends:');
    final categoryEntries =
        historyCategoryMismatchFieldTrendSummary.entries.toList()..sort(
          (left, right) => left.key.toString().compareTo(right.key.toString()),
        );
    for (final categoryEntry in categoryEntries) {
      final value = categoryEntry.value;
      if (value is! Map || value.isEmpty) {
        continue;
      }
      final fieldEntries = value.entries.toList()
        ..sort(_compareMismatchFieldTrendEntries);
      final fieldSummary = fieldEntries
          .map((entry) {
            final trendValue = entry.value;
            if (trendValue is! Map) {
              return '${entry.key}=unknown';
            }
            return '${entry.key}=${trendValue['trend']} (${trendValue['count']})';
          })
          .join(', ');
      buffer.writeln('- ${categoryEntry.key}: $fieldSummary');
    }
  }

  final historyTagMismatchFieldSummary =
      summary['historyTagMismatchFieldSummary'];
  if (historyTagMismatchFieldSummary is Map &&
      historyTagMismatchFieldSummary.isNotEmpty) {
    buffer.writeln('History tag mismatch fields:');
    final tagEntries = historyTagMismatchFieldSummary.entries.toList()
      ..sort(
        (left, right) => left.key.toString().compareTo(right.key.toString()),
      );
    for (final tagEntry in tagEntries) {
      final value = tagEntry.value;
      if (value is! Map || value.isEmpty) {
        continue;
      }
      final fieldEntries = value.entries.toList()
        ..sort(_compareMismatchFieldCountEntries);
      final fieldSummary = fieldEntries
          .map((entry) => '${entry.key}=${entry.value}')
          .join(', ');
      buffer.writeln('- ${tagEntry.key}: $fieldSummary');
    }
  }

  final historyTagMismatchFieldTrendSummary =
      summary['historyTagMismatchFieldTrendSummary'];
  if (historyTagMismatchFieldTrendSummary is Map &&
      historyTagMismatchFieldTrendSummary.isNotEmpty) {
    buffer.writeln('History tag mismatch trends:');
    final tagEntries = historyTagMismatchFieldTrendSummary.entries.toList()
      ..sort(
        (left, right) => left.key.toString().compareTo(right.key.toString()),
      );
    for (final tagEntry in tagEntries) {
      final value = tagEntry.value;
      if (value is! Map || value.isEmpty) {
        continue;
      }
      final fieldEntries = value.entries.toList()
        ..sort(_compareMismatchFieldTrendEntries);
      final fieldSummary = fieldEntries
          .map((entry) {
            final trendValue = entry.value;
            if (trendValue is! Map) {
              return '${entry.key}=unknown';
            }
            return '${entry.key}=${trendValue['trend']} (${trendValue['count']})';
          })
          .join(', ');
      buffer.writeln('- ${tagEntry.key}: $fieldSummary');
    }
  }

  final historyScenarioMismatchFieldSummary =
      summary['historyScenarioMismatchFieldSummary'];
  if (historyScenarioMismatchFieldSummary is Map &&
      historyScenarioMismatchFieldSummary.isNotEmpty) {
    buffer.writeln('History scenario mismatch fields:');
    final scenarioEntries = historyScenarioMismatchFieldSummary.entries.toList()
      ..sort(
        (left, right) => left.key.toString().compareTo(right.key.toString()),
      );
    for (final scenarioEntry in scenarioEntries) {
      final value = scenarioEntry.value;
      if (value is! Map || value.isEmpty) {
        continue;
      }
      final fieldEntries = value.entries.toList()
        ..sort(_compareMismatchFieldCountEntries);
      final fieldSummary = fieldEntries
          .map((entry) => '${entry.key}=${entry.value}')
          .join(', ');
      buffer.writeln('- ${scenarioEntry.key}: $fieldSummary');
    }
  }

  final historyScenarioMismatchFieldTrendSummary =
      summary['historyScenarioMismatchFieldTrendSummary'];
  if (historyScenarioMismatchFieldTrendSummary is Map &&
      historyScenarioMismatchFieldTrendSummary.isNotEmpty) {
    buffer.writeln('History scenario mismatch trends:');
    final scenarioEntries =
        historyScenarioMismatchFieldTrendSummary.entries.toList()..sort(
          (left, right) => left.key.toString().compareTo(right.key.toString()),
        );
    for (final scenarioEntry in scenarioEntries) {
      final value = scenarioEntry.value;
      if (value is! Map || value.isEmpty) {
        continue;
      }
      final fieldEntries = value.entries.toList()
        ..sort(_compareMismatchFieldTrendEntries);
      final fieldSummary = fieldEntries
          .map((entry) {
            final trendValue = entry.value;
            if (trendValue is! Map) {
              return '${entry.key}=unknown';
            }
            return '${entry.key}=${trendValue['trend']} (${trendValue['count']})';
          })
          .join(', ');
      buffer.writeln('- ${scenarioEntry.key}: $fieldSummary');
    }
  }

  final historyAlertSummary = summary['historyAlertSummary'];
  if (historyAlertSummary is Map && historyAlertSummary.isNotEmpty) {
    buffer.writeln('History alerts:');
    final severityEntries = historyAlertSummary.entries.toList()
      ..sort((left, right) {
        final severityOrder = _alertSeverityRank(
          right.key.toString(),
        ).compareTo(_alertSeverityRank(left.key.toString()));
        if (severityOrder != 0) {
          return severityOrder;
        }
        return left.key.toString().compareTo(right.key.toString());
      });
    for (final entry in severityEntries) {
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
  }

  final historyAlertCategorySummary = summary['historyAlertCategorySummary'];
  if (historyAlertCategorySummary is Map &&
      historyAlertCategorySummary.isNotEmpty) {
    buffer.writeln('History alert categories:');
    final categoryEntries = historyAlertCategorySummary.entries.toList()
      ..sort(_compareMismatchFieldCountEntries);
    for (final entry in categoryEntries) {
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
  }

  final historyAlertCategoryFieldSummary =
      summary['historyAlertCategoryFieldSummary'];
  if (historyAlertCategoryFieldSummary is Map &&
      historyAlertCategoryFieldSummary.isNotEmpty) {
    buffer.writeln('History alert category fields:');
    final categoryEntries = historyAlertCategoryFieldSummary.entries.toList()
      ..sort(
        (left, right) => left.key.toString().compareTo(right.key.toString()),
      );
    for (final categoryEntry in categoryEntries) {
      final value = categoryEntry.value;
      if (value is! Map || value.isEmpty) {
        continue;
      }
      final fieldEntries = value.entries.toList()
        ..sort(_compareMismatchFieldCountEntries);
      final fieldSummary = fieldEntries
          .map((entry) => '${entry.key}=${entry.value}')
          .join(', ');
      buffer.writeln('- ${categoryEntry.key}: $fieldSummary');
    }
  }

  final historyAlertScenarioSummary = summary['historyAlertScenarioSummary'];
  if (historyAlertScenarioSummary is Map &&
      historyAlertScenarioSummary.isNotEmpty) {
    buffer.writeln('History alert scenarios:');
    final scenarioEntries = historyAlertScenarioSummary.entries.toList()
      ..sort(_compareMismatchFieldCountEntries);
    for (final entry in scenarioEntries) {
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
  }

  final historyAlertScenarioFieldSummary =
      summary['historyAlertScenarioFieldSummary'];
  if (historyAlertScenarioFieldSummary is Map &&
      historyAlertScenarioFieldSummary.isNotEmpty) {
    buffer.writeln('History alert scenario fields:');
    final scenarioEntries = historyAlertScenarioFieldSummary.entries.toList()
      ..sort(
        (left, right) => left.key.toString().compareTo(right.key.toString()),
      );
    for (final scenarioEntry in scenarioEntries) {
      final value = scenarioEntry.value;
      if (value is! Map || value.isEmpty) {
        continue;
      }
      final fieldEntries = value.entries.toList()
        ..sort(_compareMismatchFieldCountEntries);
      final fieldSummary = fieldEntries
          .map((entry) => '${entry.key}=${entry.value}')
          .join(', ');
      buffer.writeln('- ${scenarioEntry.key}: $fieldSummary');
    }
  }

  final historyAlertFieldSummary = summary['historyAlertFieldSummary'];
  if (historyAlertFieldSummary is Map && historyAlertFieldSummary.isNotEmpty) {
    buffer.writeln('History alert fields:');
    final fieldEntries = historyAlertFieldSummary.entries.toList()
      ..sort(_compareMismatchFieldCountEntries);
    for (final entry in fieldEntries) {
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
  }

  final historyAlertCommandBrainTimelineSummary =
      summary['historyAlertCommandBrainTimelineSummary'];
  if (historyAlertCommandBrainTimelineSummary is Map &&
      historyAlertCommandBrainTimelineSummary.isNotEmpty) {
    buffer.writeln('History alert command brain timeline drift:');
    final scenarioEntries =
        historyAlertCommandBrainTimelineSummary.entries.toList()..sort(
          (left, right) => left.key.toString().compareTo(right.key.toString()),
        );
    for (final scenarioEntry in scenarioEntries) {
      final value = scenarioEntry.value;
      if (value is! Map || value.isEmpty) {
        continue;
      }
      final expectedSignature = value['expectedTimelineSignature'];
      final actualSignature = value['actualTimelineSignature'];
      final signatureSuffix =
          expectedSignature != null || actualSignature != null
          ? ', expected ${expectedSignature ?? 'unknown'}, actual ${actualSignature ?? 'unknown'}'
          : '';
      buffer.writeln(
        '- ${scenarioEntry.key}: ${value['trend']} (${value['severity']}, count ${value['count']})$signatureSuffix',
      );
    }
  }

  final historyAlertCommandBrainReplayBiasStackSummary =
      summary['historyAlertCommandBrainReplayBiasStackSummary'];
  if (historyAlertCommandBrainReplayBiasStackSummary is Map &&
      historyAlertCommandBrainReplayBiasStackSummary.isNotEmpty) {
    buffer.writeln('History alert command brain replay bias stack drift:');
    final scenarioEntries =
        historyAlertCommandBrainReplayBiasStackSummary.entries.toList()..sort(
          (left, right) => left.key.toString().compareTo(right.key.toString()),
        );
    for (final scenarioEntry in scenarioEntries) {
      final value = scenarioEntry.value;
      if (value is! Map || value.isEmpty) {
        continue;
      }
      final expectedSignature = value['expectedReplayBiasStackSignature'];
      final actualSignature = value['actualReplayBiasStackSignature'];
      final signatureSuffix =
          expectedSignature != null || actualSignature != null
          ? ', expected ${expectedSignature ?? 'unknown'}, actual ${actualSignature ?? 'unknown'}'
          : '';
      buffer.writeln(
        '- ${scenarioEntry.key}: ${value['trend']} (${value['severity']}, count ${value['count']})$signatureSuffix',
      );
    }
  }

  final historyAlertTrendSummary = summary['historyAlertTrendSummary'];
  if (historyAlertTrendSummary is Map && historyAlertTrendSummary.isNotEmpty) {
    buffer.writeln('History alert trends:');
    final trendEntries = historyAlertTrendSummary.entries.toList()
      ..sort(_compareHistoryTrendCountEntries);
    for (final entry in trendEntries) {
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
  }

  final historyAlertScenarioSetSummary =
      summary['historyAlertScenarioSetSummary'];
  if (historyAlertScenarioSetSummary is Map &&
      historyAlertScenarioSetSummary.isNotEmpty) {
    buffer.writeln('History alert scenario sets:');
    final setEntries = historyAlertScenarioSetSummary.entries.toList()
      ..sort(_compareMismatchFieldCountEntries);
    for (final entry in setEntries) {
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
  }

  final historyAlertStatusSummary = summary['historyAlertStatusSummary'];
  if (historyAlertStatusSummary is Map &&
      historyAlertStatusSummary.isNotEmpty) {
    buffer.writeln('History alert statuses:');
    final statusEntries = historyAlertStatusSummary.entries.toList()
      ..sort(_compareMismatchFieldCountEntries);
    for (final entry in statusEntries) {
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
  }

  final historyAlertTagSummary = summary['historyAlertTagSummary'];
  if (historyAlertTagSummary is Map && historyAlertTagSummary.isNotEmpty) {
    buffer.writeln('History alert tags:');
    final tagEntries = historyAlertTagSummary.entries.toList()
      ..sort(_compareMismatchFieldCountEntries);
    for (final entry in tagEntries) {
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
  }

  final historyAlertTagFieldSummary = summary['historyAlertTagFieldSummary'];
  if (historyAlertTagFieldSummary is Map &&
      historyAlertTagFieldSummary.isNotEmpty) {
    buffer.writeln('History alert tag fields:');
    final tagEntries = historyAlertTagFieldSummary.entries.toList()
      ..sort(
        (left, right) => left.key.toString().compareTo(right.key.toString()),
      );
    for (final tagEntry in tagEntries) {
      final value = tagEntry.value;
      if (value is! Map || value.isEmpty) {
        continue;
      }
      final fieldEntries = value.entries.toList()
        ..sort(_compareMismatchFieldCountEntries);
      final fieldSummary = fieldEntries
          .map((entry) => '${entry.key}=${entry.value}')
          .join(', ');
      buffer.writeln('- ${tagEntry.key}: $fieldSummary');
    }
  }

  final historyAlertPolicySummary = summary['historyAlertPolicySummary'];
  if (historyAlertPolicySummary is Map &&
      historyAlertPolicySummary.isNotEmpty) {
    buffer.writeln('History alert policy matches:');
    final policyEntries = historyAlertPolicySummary.entries.toList()
      ..sort(_compareMismatchFieldCountEntries);
    for (final entry in policyEntries) {
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
  }

  final historyAlertPolicyTypeSummary =
      summary['historyAlertPolicyTypeSummary'];
  if (historyAlertPolicyTypeSummary is Map &&
      historyAlertPolicyTypeSummary.isNotEmpty) {
    buffer.writeln('History alert policy types:');
    final policyTypeEntries = historyAlertPolicyTypeSummary.entries.toList()
      ..sort(_compareMismatchFieldCountEntries);
    for (final entry in policyTypeEntries) {
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
  }

  final historyAlertPolicySuppressionSummary =
      summary['historyAlertPolicySuppressionSummary'];
  if (historyAlertPolicySuppressionSummary is Map &&
      historyAlertPolicySuppressionSummary.isNotEmpty) {
    buffer.writeln('History alert policy suppression:');
    final policySuppressionEntries =
        historyAlertPolicySuppressionSummary.entries.toList()
          ..sort(_compareMismatchFieldCountEntries);
    for (final entry in policySuppressionEntries) {
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
  }

  final historyAlertPolicySourceSummary =
      summary['historyAlertPolicySourceSummary'];
  if (historyAlertPolicySourceSummary is Map &&
      historyAlertPolicySourceSummary.isNotEmpty) {
    buffer.writeln('History alert policy sources:');
    final policySourceEntries = historyAlertPolicySourceSummary.entries.toList()
      ..sort(_compareMismatchFieldCountEntries);
    for (final entry in policySourceEntries) {
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
  }

  final historyAlertPolicyPromotedReplayRiskSummary =
      summary['historyAlertPolicyPromotedReplayRiskSummary'];
  if (historyAlertPolicyPromotedReplayRiskSummary is Map &&
      historyAlertPolicyPromotedReplayRiskSummary.isNotEmpty) {
    buffer.writeln('History policy-promoted replay risks:');
    final policyPromotedEntries =
        historyAlertPolicyPromotedReplayRiskSummary.entries.toList()
          ..sort(_compareMismatchFieldCountEntries);
    for (final entry in policyPromotedEntries) {
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
  }

  final historyAlertPolicyPromotedReplayRiskSourceSummary =
      summary['historyAlertPolicyPromotedReplayRiskSourceSummary'];
  if (historyAlertPolicyPromotedReplayRiskSourceSummary is Map &&
      historyAlertPolicyPromotedReplayRiskSourceSummary.isNotEmpty) {
    buffer.writeln('History policy-promoted replay risk sources:');
    final policyPromotedSourceEntries =
        historyAlertPolicyPromotedReplayRiskSourceSummary.entries.toList()
          ..sort(_compareMismatchFieldCountEntries);
    for (final entry in policyPromotedSourceEntries) {
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
  }

  final historyAlertPolicyPromotedReplayRiskFocus =
      summary['historyAlertPolicyPromotedReplayRiskFocus'];
  if (historyAlertPolicyPromotedReplayRiskFocus is Map &&
      historyAlertPolicyPromotedReplayRiskFocus.isNotEmpty) {
    buffer.writeln('History policy-promoted replay risk focus:');
    final fieldSuffix =
        historyAlertPolicyPromotedReplayRiskFocus['field'] != null
        ? '.${historyAlertPolicyPromotedReplayRiskFocus['field']}'
        : '';
    final sourceSuffix =
        historyAlertPolicyPromotedReplayRiskFocus['policyMatchSource'] != null
        ? ' from ${historyAlertPolicyPromotedReplayRiskFocus['policyMatchSource']}'
        : '';
    final promotionSuffix = _buildPolicySeverityTransitionConsoleLabel(
      historyAlertPolicyPromotedReplayRiskFocus,
    );
    buffer.writeln(
      '- ${historyAlertPolicyPromotedReplayRiskFocus['policyMatchType']} ${historyAlertPolicyPromotedReplayRiskFocus['policyMatchValue']}$sourceSuffix$promotionSuffix: [${historyAlertPolicyPromotedReplayRiskFocus['severity']}] ${historyAlertPolicyPromotedReplayRiskFocus['scenarioId']}$fieldSuffix (${historyAlertPolicyPromotedReplayRiskFocus['trend']}, count ${historyAlertPolicyPromotedReplayRiskFocus['count']}): ${historyAlertPolicyPromotedReplayRiskFocus['message']}',
    );
  }

  final historyAlertPolicyPromotedSpecialistSummary =
      summary['historyAlertPolicyPromotedSpecialistSummary'];
  if (historyAlertPolicyPromotedSpecialistSummary is Map &&
      historyAlertPolicyPromotedSpecialistSummary.isNotEmpty) {
    buffer.writeln('History policy-promoted specialist alerts:');
    final policyPromotedEntries =
        historyAlertPolicyPromotedSpecialistSummary.entries.toList()
          ..sort(_compareMismatchFieldCountEntries);
    for (final entry in policyPromotedEntries) {
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
  }

  final historyAlertPolicyPromotedSpecialistSourceSummary =
      summary['historyAlertPolicyPromotedSpecialistSourceSummary'];
  if (historyAlertPolicyPromotedSpecialistSourceSummary is Map &&
      historyAlertPolicyPromotedSpecialistSourceSummary.isNotEmpty) {
    buffer.writeln('History policy-promoted specialist sources:');
    final policyPromotedSourceEntries =
        historyAlertPolicyPromotedSpecialistSourceSummary.entries.toList()
          ..sort(_compareMismatchFieldCountEntries);
    for (final entry in policyPromotedSourceEntries) {
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
  }

  final historyAlertPolicyPromotedSpecialistFocus =
      summary['historyAlertPolicyPromotedSpecialistFocus'];
  if (historyAlertPolicyPromotedSpecialistFocus is Map &&
      historyAlertPolicyPromotedSpecialistFocus.isNotEmpty) {
    buffer.writeln('History policy-promoted specialist focus:');
    final fieldSuffix =
        historyAlertPolicyPromotedSpecialistFocus['field'] != null
        ? '.${historyAlertPolicyPromotedSpecialistFocus['field']}'
        : '';
    final sourceSuffix =
        historyAlertPolicyPromotedSpecialistFocus['policyMatchSource'] != null
        ? ' from ${historyAlertPolicyPromotedSpecialistFocus['policyMatchSource']}'
        : '';
    final promotionSuffix = _buildPolicySeverityTransitionConsoleLabel(
      historyAlertPolicyPromotedSpecialistFocus,
    );
    buffer.writeln(
      '- ${historyAlertPolicyPromotedSpecialistFocus['policyMatchType']} ${historyAlertPolicyPromotedSpecialistFocus['policyMatchValue']}$sourceSuffix$promotionSuffix: [${historyAlertPolicyPromotedSpecialistFocus['severity']}] ${historyAlertPolicyPromotedSpecialistFocus['scenarioId']}$fieldSuffix (${historyAlertPolicyPromotedSpecialistFocus['trend']}, count ${historyAlertPolicyPromotedSpecialistFocus['count']}): ${historyAlertPolicyPromotedSpecialistFocus['message']}',
    );
  }

  final historyAlertFocus = summary['historyAlertFocus'];
  if (historyAlertFocus is Map && historyAlertFocus.isNotEmpty) {
    buffer.writeln('History alert focus:');
    final fieldSuffix = historyAlertFocus['field'] != null
        ? '.${historyAlertFocus['field']}'
        : '';
    buffer.writeln(
      '- [${historyAlertFocus['severity']}] ${historyAlertFocus['scenarioId']}$fieldSuffix (${historyAlertFocus['trend']}, count ${historyAlertFocus['count']}): ${historyAlertFocus['message']}',
    );
  }

  final historyAlertGroupFocus = summary['historyAlertGroupFocus'];
  if (historyAlertGroupFocus is Map && historyAlertGroupFocus.isNotEmpty) {
    buffer.writeln('History alert group focus:');
    final fieldSuffix = historyAlertGroupFocus['field'] != null
        ? '.${historyAlertGroupFocus['field']}'
        : '';
    buffer.writeln(
      '- ${historyAlertGroupFocus['group']}: [${historyAlertGroupFocus['severity']}] ${historyAlertGroupFocus['scenarioId']}$fieldSuffix (${historyAlertGroupFocus['trend']}, count ${historyAlertGroupFocus['count']}): ${historyAlertGroupFocus['message']}',
    );
  }

  final historyAlertTagFocus = summary['historyAlertTagFocus'];
  if (historyAlertTagFocus is Map && historyAlertTagFocus.isNotEmpty) {
    buffer.writeln('History alert tag focus:');
    final fieldSuffix = historyAlertTagFocus['field'] != null
        ? '.${historyAlertTagFocus['field']}'
        : '';
    buffer.writeln(
      '- ${historyAlertTagFocus['tag']}: [${historyAlertTagFocus['severity']}] ${historyAlertTagFocus['scenarioId']}$fieldSuffix (${historyAlertTagFocus['trend']}, count ${historyAlertTagFocus['count']}): ${historyAlertTagFocus['message']}',
    );
  }

  final historyAlertCategoryFocus = summary['historyAlertCategoryFocus'];
  if (historyAlertCategoryFocus is Map &&
      historyAlertCategoryFocus.isNotEmpty) {
    buffer.writeln('History alert category focus:');
    final fieldSuffix = historyAlertCategoryFocus['field'] != null
        ? '.${historyAlertCategoryFocus['field']}'
        : '';
    buffer.writeln(
      '- ${historyAlertCategoryFocus['category']}: [${historyAlertCategoryFocus['severity']}] ${historyAlertCategoryFocus['scenarioId']}$fieldSuffix (${historyAlertCategoryFocus['trend']}, count ${historyAlertCategoryFocus['count']}): ${historyAlertCategoryFocus['message']}',
    );
  }

  final historyAlertStatusFocus = summary['historyAlertStatusFocus'];
  if (historyAlertStatusFocus is Map && historyAlertStatusFocus.isNotEmpty) {
    buffer.writeln('History alert status focus:');
    final fieldSuffix = historyAlertStatusFocus['field'] != null
        ? '.${historyAlertStatusFocus['field']}'
        : '';
    buffer.writeln(
      '- ${historyAlertStatusFocus['status']}: [${historyAlertStatusFocus['severity']}] ${historyAlertStatusFocus['scenarioId']}$fieldSuffix (${historyAlertStatusFocus['trend']}, count ${historyAlertStatusFocus['count']}): ${historyAlertStatusFocus['message']}',
    );
  }

  final historyAlertPolicyFocus = summary['historyAlertPolicyFocus'];
  if (historyAlertPolicyFocus is Map && historyAlertPolicyFocus.isNotEmpty) {
    buffer.writeln('History alert policy focus:');
    final fieldSuffix = historyAlertPolicyFocus['field'] != null
        ? '.${historyAlertPolicyFocus['field']}'
        : '';
    final suppressedPrefix = historyAlertPolicyFocus['suppressed'] == true
        ? 'suppressed '
        : '';
    final sourceSuffix = historyAlertPolicyFocus['policyMatchSource'] != null
        ? ' from ${historyAlertPolicyFocus['policyMatchSource']}'
        : '';
    final promotionSuffix = _buildPolicySeverityTransitionConsoleLabel(
      historyAlertPolicyFocus,
    );
    buffer.writeln(
      '- ${historyAlertPolicyFocus['policyMatchType']} ${historyAlertPolicyFocus['policyMatchValue']}$sourceSuffix$promotionSuffix: $suppressedPrefix[${historyAlertPolicyFocus['severity']}] ${historyAlertPolicyFocus['scenarioId']}$fieldSuffix (${historyAlertPolicyFocus['trend']}, count ${historyAlertPolicyFocus['count']}): ${historyAlertPolicyFocus['message']}',
    );
  }

  final alertFailureSummary = summary['alertFailureSummary'];
  if (alertFailureSummary is Map && alertFailureSummary.isNotEmpty) {
    buffer.writeln('Alert-threshold matches:');
    final severityEntries = alertFailureSummary.entries.toList()
      ..sort((left, right) {
        final severityOrder = _alertSeverityRank(
          right.key.toString(),
        ).compareTo(_alertSeverityRank(left.key.toString()));
        if (severityOrder != 0) {
          return severityOrder;
        }
        return left.key.toString().compareTo(right.key.toString());
      });
    for (final entry in severityEntries) {
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
  }

  final alertFailureCategorySummary = summary['alertFailureCategorySummary'];
  if (alertFailureCategorySummary is Map &&
      alertFailureCategorySummary.isNotEmpty) {
    buffer.writeln('Alert-threshold categories:');
    final categoryEntries = alertFailureCategorySummary.entries.toList()
      ..sort(_compareMismatchFieldCountEntries);
    for (final entry in categoryEntries) {
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
  }

  final alertFailureCategoryFieldSummary =
      summary['alertFailureCategoryFieldSummary'];
  if (alertFailureCategoryFieldSummary is Map &&
      alertFailureCategoryFieldSummary.isNotEmpty) {
    buffer.writeln('Alert-threshold category fields:');
    final categoryEntries = alertFailureCategoryFieldSummary.entries.toList()
      ..sort(
        (left, right) => left.key.toString().compareTo(right.key.toString()),
      );
    for (final categoryEntry in categoryEntries) {
      final value = categoryEntry.value;
      if (value is! Map || value.isEmpty) {
        continue;
      }
      final fieldEntries = value.entries.toList()
        ..sort(_compareMismatchFieldCountEntries);
      final fieldSummary = fieldEntries
          .map((entry) => '${entry.key}=${entry.value}')
          .join(', ');
      buffer.writeln('- ${categoryEntry.key}: $fieldSummary');
    }
  }

  final alertFailureScenarioSummary = summary['alertFailureScenarioSummary'];
  if (alertFailureScenarioSummary is Map &&
      alertFailureScenarioSummary.isNotEmpty) {
    buffer.writeln('Alert-threshold scenarios:');
    final scenarioEntries = alertFailureScenarioSummary.entries.toList()
      ..sort(_compareMismatchFieldCountEntries);
    for (final entry in scenarioEntries) {
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
  }

  final alertFailureScenarioFieldSummary =
      summary['alertFailureScenarioFieldSummary'];
  if (alertFailureScenarioFieldSummary is Map &&
      alertFailureScenarioFieldSummary.isNotEmpty) {
    buffer.writeln('Alert-threshold scenario fields:');
    final scenarioEntries = alertFailureScenarioFieldSummary.entries.toList()
      ..sort(
        (left, right) => left.key.toString().compareTo(right.key.toString()),
      );
    for (final scenarioEntry in scenarioEntries) {
      final value = scenarioEntry.value;
      if (value is! Map || value.isEmpty) {
        continue;
      }
      final fieldEntries = value.entries.toList()
        ..sort(_compareMismatchFieldCountEntries);
      final fieldSummary = fieldEntries
          .map((entry) => '${entry.key}=${entry.value}')
          .join(', ');
      buffer.writeln('- ${scenarioEntry.key}: $fieldSummary');
    }
  }

  final alertFailureFieldSummary = summary['alertFailureFieldSummary'];
  if (alertFailureFieldSummary is Map && alertFailureFieldSummary.isNotEmpty) {
    buffer.writeln('Alert-threshold fields:');
    final fieldEntries = alertFailureFieldSummary.entries.toList()
      ..sort(_compareMismatchFieldCountEntries);
    for (final entry in fieldEntries) {
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
  }

  final alertFailureCommandBrainTimelineSummary =
      summary['alertFailureCommandBrainTimelineSummary'];
  if (alertFailureCommandBrainTimelineSummary is Map &&
      alertFailureCommandBrainTimelineSummary.isNotEmpty) {
    buffer.writeln('Alert-threshold command brain timeline drift:');
    final scenarioEntries =
        alertFailureCommandBrainTimelineSummary.entries.toList()..sort(
          (left, right) => left.key.toString().compareTo(right.key.toString()),
        );
    for (final scenarioEntry in scenarioEntries) {
      final value = scenarioEntry.value;
      if (value is! Map || value.isEmpty) {
        continue;
      }
      final expectedSignature = value['expectedTimelineSignature'];
      final actualSignature = value['actualTimelineSignature'];
      final signatureSuffix =
          expectedSignature != null || actualSignature != null
          ? ', expected ${expectedSignature ?? 'unknown'}, actual ${actualSignature ?? 'unknown'}'
          : '';
      buffer.writeln(
        '- ${scenarioEntry.key}: ${value['trend']} (${value['severity']}, count ${value['count']})$signatureSuffix',
      );
    }
  }

  final alertFailureCommandBrainReplayBiasStackSummary =
      summary['alertFailureCommandBrainReplayBiasStackSummary'];
  if (alertFailureCommandBrainReplayBiasStackSummary is Map &&
      alertFailureCommandBrainReplayBiasStackSummary.isNotEmpty) {
    buffer.writeln('Alert-threshold command brain replay bias stack drift:');
    final scenarioEntries =
        alertFailureCommandBrainReplayBiasStackSummary.entries.toList()..sort(
          (left, right) => left.key.toString().compareTo(right.key.toString()),
        );
    for (final scenarioEntry in scenarioEntries) {
      final value = scenarioEntry.value;
      if (value is! Map || value.isEmpty) {
        continue;
      }
      final expectedSignature = value['expectedReplayBiasStackSignature'];
      final actualSignature = value['actualReplayBiasStackSignature'];
      final signatureSuffix =
          expectedSignature != null || actualSignature != null
          ? ', expected ${expectedSignature ?? 'unknown'}, actual ${actualSignature ?? 'unknown'}'
          : '';
      buffer.writeln(
        '- ${scenarioEntry.key}: ${value['trend']} (${value['severity']}, count ${value['count']})$signatureSuffix',
      );
    }
  }

  final alertFailureTrendSummary = summary['alertFailureTrendSummary'];
  if (alertFailureTrendSummary is Map && alertFailureTrendSummary.isNotEmpty) {
    buffer.writeln('Alert-threshold trends:');
    final trendEntries = alertFailureTrendSummary.entries.toList()
      ..sort(_compareMismatchFieldCountEntries);
    for (final entry in trendEntries) {
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
  }

  final alertFailureScenarioSetSummary =
      summary['alertFailureScenarioSetSummary'];
  if (alertFailureScenarioSetSummary is Map &&
      alertFailureScenarioSetSummary.isNotEmpty) {
    buffer.writeln('Alert-threshold scenario sets:');
    final setEntries = alertFailureScenarioSetSummary.entries.toList()
      ..sort(_compareMismatchFieldCountEntries);
    for (final entry in setEntries) {
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
  }

  final alertFailureStatusSummary = summary['alertFailureStatusSummary'];
  if (alertFailureStatusSummary is Map &&
      alertFailureStatusSummary.isNotEmpty) {
    buffer.writeln('Alert-threshold statuses:');
    final statusEntries = alertFailureStatusSummary.entries.toList()
      ..sort(_compareMismatchFieldCountEntries);
    for (final entry in statusEntries) {
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
  }

  final alertFailureTagSummary = summary['alertFailureTagSummary'];
  if (alertFailureTagSummary is Map && alertFailureTagSummary.isNotEmpty) {
    buffer.writeln('Alert-threshold tags:');
    final tagEntries = alertFailureTagSummary.entries.toList()
      ..sort(_compareMismatchFieldCountEntries);
    for (final entry in tagEntries) {
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
  }

  final alertFailureTagFieldSummary = summary['alertFailureTagFieldSummary'];
  if (alertFailureTagFieldSummary is Map &&
      alertFailureTagFieldSummary.isNotEmpty) {
    buffer.writeln('Alert-threshold tag fields:');
    final tagEntries = alertFailureTagFieldSummary.entries.toList()
      ..sort(
        (left, right) => left.key.toString().compareTo(right.key.toString()),
      );
    for (final tagEntry in tagEntries) {
      final value = tagEntry.value;
      if (value is! Map || value.isEmpty) {
        continue;
      }
      final fieldEntries = value.entries.toList()
        ..sort(_compareMismatchFieldCountEntries);
      final fieldSummary = fieldEntries
          .map((entry) => '${entry.key}=${entry.value}')
          .join(', ');
      buffer.writeln('- ${tagEntry.key}: $fieldSummary');
    }
  }

  final alertFailurePolicySummary = summary['alertFailurePolicySummary'];
  if (alertFailurePolicySummary is Map &&
      alertFailurePolicySummary.isNotEmpty) {
    buffer.writeln('Alert-threshold policy matches:');
    final policyEntries = alertFailurePolicySummary.entries.toList()
      ..sort(_compareMismatchFieldCountEntries);
    for (final entry in policyEntries) {
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
  }

  final alertFailurePolicyTypeSummary =
      summary['alertFailurePolicyTypeSummary'];
  if (alertFailurePolicyTypeSummary is Map &&
      alertFailurePolicyTypeSummary.isNotEmpty) {
    buffer.writeln('Alert-threshold policy types:');
    final policyTypeEntries = alertFailurePolicyTypeSummary.entries.toList()
      ..sort(_compareMismatchFieldCountEntries);
    for (final entry in policyTypeEntries) {
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
  }

  final alertFailurePolicySuppressionSummary =
      summary['alertFailurePolicySuppressionSummary'];
  if (alertFailurePolicySuppressionSummary is Map &&
      alertFailurePolicySuppressionSummary.isNotEmpty) {
    buffer.writeln('Alert-threshold policy suppression:');
    final policySuppressionEntries =
        alertFailurePolicySuppressionSummary.entries.toList()
          ..sort(_compareMismatchFieldCountEntries);
    for (final entry in policySuppressionEntries) {
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
  }

  final alertFailurePolicySourceSummary =
      summary['alertFailurePolicySourceSummary'];
  if (alertFailurePolicySourceSummary is Map &&
      alertFailurePolicySourceSummary.isNotEmpty) {
    buffer.writeln('Alert-threshold policy sources:');
    final policySourceEntries = alertFailurePolicySourceSummary.entries.toList()
      ..sort(_compareMismatchFieldCountEntries);
    for (final entry in policySourceEntries) {
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
  }

  final alertFailurePolicyPromotedReplayRiskSummary =
      summary['alertFailurePolicyPromotedReplayRiskSummary'];
  if (alertFailurePolicyPromotedReplayRiskSummary is Map &&
      alertFailurePolicyPromotedReplayRiskSummary.isNotEmpty) {
    buffer.writeln('Alert-threshold policy-promoted replay risks:');
    final policyPromotedEntries =
        alertFailurePolicyPromotedReplayRiskSummary.entries.toList()
          ..sort(_compareMismatchFieldCountEntries);
    for (final entry in policyPromotedEntries) {
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
  }

  final alertFailurePolicyPromotedReplayRiskSourceSummary =
      summary['alertFailurePolicyPromotedReplayRiskSourceSummary'];
  if (alertFailurePolicyPromotedReplayRiskSourceSummary is Map &&
      alertFailurePolicyPromotedReplayRiskSourceSummary.isNotEmpty) {
    buffer.writeln('Alert-threshold policy-promoted replay risk sources:');
    final policyPromotedSourceEntries =
        alertFailurePolicyPromotedReplayRiskSourceSummary.entries.toList()
          ..sort(_compareMismatchFieldCountEntries);
    for (final entry in policyPromotedSourceEntries) {
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
  }

  final alertFailurePolicyPromotedReplayRiskFocus =
      summary['alertFailurePolicyPromotedReplayRiskFocus'];
  if (alertFailurePolicyPromotedReplayRiskFocus is Map &&
      alertFailurePolicyPromotedReplayRiskFocus.isNotEmpty) {
    buffer.writeln('Alert-threshold policy-promoted replay risk focus:');
    final fieldSuffix =
        alertFailurePolicyPromotedReplayRiskFocus['field'] != null
        ? '.${alertFailurePolicyPromotedReplayRiskFocus['field']}'
        : '';
    final sourceSuffix =
        alertFailurePolicyPromotedReplayRiskFocus['policyMatchSource'] != null
        ? ' from ${alertFailurePolicyPromotedReplayRiskFocus['policyMatchSource']}'
        : '';
    final promotionSuffix = _buildPolicySeverityTransitionConsoleLabel(
      alertFailurePolicyPromotedReplayRiskFocus,
    );
    buffer.writeln(
      '- ${alertFailurePolicyPromotedReplayRiskFocus['policyMatchType']} ${alertFailurePolicyPromotedReplayRiskFocus['policyMatchValue']}$sourceSuffix$promotionSuffix: [${alertFailurePolicyPromotedReplayRiskFocus['severity']}] ${alertFailurePolicyPromotedReplayRiskFocus['scenarioId']}$fieldSuffix (${alertFailurePolicyPromotedReplayRiskFocus['trend']}, count ${alertFailurePolicyPromotedReplayRiskFocus['count']}): ${alertFailurePolicyPromotedReplayRiskFocus['message']}',
    );
  }

  final alertFailurePolicyPromotedSpecialistSummary =
      summary['alertFailurePolicyPromotedSpecialistSummary'];
  if (alertFailurePolicyPromotedSpecialistSummary is Map &&
      alertFailurePolicyPromotedSpecialistSummary.isNotEmpty) {
    buffer.writeln('Alert-threshold policy-promoted specialist alerts:');
    final policyPromotedEntries =
        alertFailurePolicyPromotedSpecialistSummary.entries.toList()
          ..sort(_compareMismatchFieldCountEntries);
    for (final entry in policyPromotedEntries) {
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
  }

  final alertFailurePolicyPromotedSpecialistSourceSummary =
      summary['alertFailurePolicyPromotedSpecialistSourceSummary'];
  if (alertFailurePolicyPromotedSpecialistSourceSummary is Map &&
      alertFailurePolicyPromotedSpecialistSourceSummary.isNotEmpty) {
    buffer.writeln('Alert-threshold policy-promoted specialist sources:');
    final policyPromotedSourceEntries =
        alertFailurePolicyPromotedSpecialistSourceSummary.entries.toList()
          ..sort(_compareMismatchFieldCountEntries);
    for (final entry in policyPromotedSourceEntries) {
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
  }

  final alertFailurePolicyPromotedSpecialistFocus =
      summary['alertFailurePolicyPromotedSpecialistFocus'];
  if (alertFailurePolicyPromotedSpecialistFocus is Map &&
      alertFailurePolicyPromotedSpecialistFocus.isNotEmpty) {
    buffer.writeln('Alert-threshold policy-promoted specialist focus:');
    final fieldSuffix =
        alertFailurePolicyPromotedSpecialistFocus['field'] != null
        ? '.${alertFailurePolicyPromotedSpecialistFocus['field']}'
        : '';
    final sourceSuffix =
        alertFailurePolicyPromotedSpecialistFocus['policyMatchSource'] != null
        ? ' from ${alertFailurePolicyPromotedSpecialistFocus['policyMatchSource']}'
        : '';
    final promotionSuffix = _buildPolicySeverityTransitionConsoleLabel(
      alertFailurePolicyPromotedSpecialistFocus,
    );
    buffer.writeln(
      '- ${alertFailurePolicyPromotedSpecialistFocus['policyMatchType']} ${alertFailurePolicyPromotedSpecialistFocus['policyMatchValue']}$sourceSuffix$promotionSuffix: [${alertFailurePolicyPromotedSpecialistFocus['severity']}] ${alertFailurePolicyPromotedSpecialistFocus['scenarioId']}$fieldSuffix (${alertFailurePolicyPromotedSpecialistFocus['trend']}, count ${alertFailurePolicyPromotedSpecialistFocus['count']}): ${alertFailurePolicyPromotedSpecialistFocus['message']}',
    );
  }

  final alertFailureGroupFocus = summary['alertFailureGroupFocus'];
  if (alertFailureGroupFocus is Map && alertFailureGroupFocus.isNotEmpty) {
    buffer.writeln('Alert-threshold group focus:');
    final fieldSuffix = alertFailureGroupFocus['field'] != null
        ? '.${alertFailureGroupFocus['field']}'
        : '';
    buffer.writeln(
      '- ${alertFailureGroupFocus['group']}: [${alertFailureGroupFocus['severity']}] ${alertFailureGroupFocus['scenarioId']}$fieldSuffix (${alertFailureGroupFocus['trend']}, count ${alertFailureGroupFocus['count']}): ${alertFailureGroupFocus['message']}',
    );
  }

  final alertFailureTagFocus = summary['alertFailureTagFocus'];
  if (alertFailureTagFocus is Map && alertFailureTagFocus.isNotEmpty) {
    buffer.writeln('Alert-threshold tag focus:');
    final fieldSuffix = alertFailureTagFocus['field'] != null
        ? '.${alertFailureTagFocus['field']}'
        : '';
    buffer.writeln(
      '- ${alertFailureTagFocus['tag']}: [${alertFailureTagFocus['severity']}] ${alertFailureTagFocus['scenarioId']}$fieldSuffix (${alertFailureTagFocus['trend']}, count ${alertFailureTagFocus['count']}): ${alertFailureTagFocus['message']}',
    );
  }

  final alertFailureCategoryFocus = summary['alertFailureCategoryFocus'];
  if (alertFailureCategoryFocus is Map &&
      alertFailureCategoryFocus.isNotEmpty) {
    buffer.writeln('Alert-threshold category focus:');
    final fieldSuffix = alertFailureCategoryFocus['field'] != null
        ? '.${alertFailureCategoryFocus['field']}'
        : '';
    buffer.writeln(
      '- ${alertFailureCategoryFocus['category']}: [${alertFailureCategoryFocus['severity']}] ${alertFailureCategoryFocus['scenarioId']}$fieldSuffix (${alertFailureCategoryFocus['trend']}, count ${alertFailureCategoryFocus['count']}): ${alertFailureCategoryFocus['message']}',
    );
  }

  final alertFailureStatusFocus = summary['alertFailureStatusFocus'];
  if (alertFailureStatusFocus is Map && alertFailureStatusFocus.isNotEmpty) {
    buffer.writeln('Alert-threshold status focus:');
    final fieldSuffix = alertFailureStatusFocus['field'] != null
        ? '.${alertFailureStatusFocus['field']}'
        : '';
    buffer.writeln(
      '- ${alertFailureStatusFocus['status']}: [${alertFailureStatusFocus['severity']}] ${alertFailureStatusFocus['scenarioId']}$fieldSuffix (${alertFailureStatusFocus['trend']}, count ${alertFailureStatusFocus['count']}): ${alertFailureStatusFocus['message']}',
    );
  }

  final alertFailurePolicyFocus = summary['alertFailurePolicyFocus'];
  if (alertFailurePolicyFocus is Map && alertFailurePolicyFocus.isNotEmpty) {
    buffer.writeln('Alert-threshold policy focus:');
    final fieldSuffix = alertFailurePolicyFocus['field'] != null
        ? '.${alertFailurePolicyFocus['field']}'
        : '';
    final suppressedPrefix = alertFailurePolicyFocus['suppressed'] == true
        ? 'suppressed '
        : '';
    final sourceSuffix = alertFailurePolicyFocus['policyMatchSource'] != null
        ? ' from ${alertFailurePolicyFocus['policyMatchSource']}'
        : '';
    final promotionSuffix = _buildPolicySeverityTransitionConsoleLabel(
      alertFailurePolicyFocus,
    );
    buffer.writeln(
      '- ${alertFailurePolicyFocus['policyMatchType']} ${alertFailurePolicyFocus['policyMatchValue']}$sourceSuffix$promotionSuffix: $suppressedPrefix[${alertFailurePolicyFocus['severity']}] ${alertFailurePolicyFocus['scenarioId']}$fieldSuffix (${alertFailurePolicyFocus['trend']}, count ${alertFailurePolicyFocus['count']}): ${alertFailurePolicyFocus['message']}',
    );
  }

  if ((alertFailureGroupFocus is! Map || alertFailureGroupFocus.isEmpty) &&
      (alertFailureTagFocus is! Map || alertFailureTagFocus.isEmpty) &&
      (alertFailureCategoryFocus is! Map ||
          alertFailureCategoryFocus.isEmpty) &&
      (alertFailureStatusFocus is! Map || alertFailureStatusFocus.isEmpty) &&
      (alertFailurePolicyFocus is! Map || alertFailurePolicyFocus.isEmpty)) {
    final alertFailureFocus = summary['alertFailureFocus'];
    if (alertFailureFocus is Map && alertFailureFocus.isNotEmpty) {
      buffer.writeln('Alert-threshold focus:');
      final fieldSuffix = alertFailureFocus['field'] != null
          ? '.${alertFailureFocus['field']}'
          : '';
      buffer.writeln(
        '- [${alertFailureFocus['severity']}] ${alertFailureFocus['scenarioId']}$fieldSuffix (${alertFailureFocus['trend']}, count ${alertFailureFocus['count']}): ${alertFailureFocus['message']}',
      );
    }
  }

  final historyAlerts = summary['historyAlerts'];
  if (historyAlerts is List && historyAlerts.isNotEmpty) {
    buffer.writeln('Alert details:');
    for (final alert in historyAlerts) {
      if (alert is! Map) {
        continue;
      }
      final fieldSuffix = alert['field'] != null ? '.${alert['field']}' : '';
      final severitySuffix = _buildPolicySeverityTransitionConsoleLabel(
        alert,
        severityKey: 'effectiveSeverity',
      );
      buffer.writeln(
        '- [${alert['severity']}] ${alert['scenarioId']}$fieldSuffix (${alert['trend']}, count ${alert['count']}$severitySuffix): ${alert['message']}',
      );
    }
  }

  final results = summary['results'];
  if (results is List) {
    for (final entry in results) {
      if (entry is! Map) {
        continue;
      }
      final scenarioId = entry['scenarioId'];
      final passed = entry['passed'] == true;
      final mismatchFields = entry['mismatchFields'];
      final mismatchFieldSuffix =
          !passed && mismatchFields is List && mismatchFields.isNotEmpty
          ? ': ${mismatchFields.join(', ')}'
          : '';
      buffer.writeln(
        '- ${passed ? 'PASS' : 'FAIL'} $scenarioId (${entry['mismatchCount']} mismatch${entry['mismatchCount'] == 1 ? '' : 'es'}$mismatchFieldSuffix)',
      );
    }
  }
  return buffer.toString().trimRight();
}

Map<String, Map<String, int>> _buildRunSummary(
  List<Map<String, dynamic>> records, {
  required String groupKey,
}) {
  final summary = <String, Map<String, int>>{};
  for (final record in records) {
    final rawGroup = record[groupKey];
    final group = rawGroup?.toString().trim();
    if (group == null || group.isEmpty) {
      continue;
    }
    final passed = record['passed'] == true;
    final groupSummary = summary.putIfAbsent(
      group,
      () => <String, int>{
        'scenarioCount': 0,
        'passedCount': 0,
        'failedCount': 0,
      },
    );
    groupSummary['scenarioCount'] = (groupSummary['scenarioCount'] ?? 0) + 1;
    if (passed) {
      groupSummary['passedCount'] = (groupSummary['passedCount'] ?? 0) + 1;
    } else {
      groupSummary['failedCount'] = (groupSummary['failedCount'] ?? 0) + 1;
    }
  }
  return summary;
}

Map<String, Map<String, int>> _buildHistoryScenarioLifecycleSummary(
  Map<String, Map<String, dynamic>> summary, {
  required String lifecycleKey,
}) {
  final lifecycleSummary = <String, Map<String, int>>{};
  for (final value in summary.values) {
    final lifecycle = value[lifecycleKey]?.toString().trim();
    if (lifecycle == null || lifecycle.isEmpty) {
      continue;
    }
    final passed = value['latestBranch']?.toString().trim() != 'active';
    final groupSummary = lifecycleSummary.putIfAbsent(
      lifecycle,
      () => <String, int>{
        'scenarioCount': 0,
        'passedCount': 0,
        'failedCount': 0,
      },
    );
    groupSummary['scenarioCount'] = (groupSummary['scenarioCount'] ?? 0) + 1;
    if (passed) {
      groupSummary['passedCount'] = (groupSummary['passedCount'] ?? 0) + 1;
    } else {
      groupSummary['failedCount'] = (groupSummary['failedCount'] ?? 0) + 1;
    }
  }
  return lifecycleSummary;
}

Map<String, int> _buildMismatchFieldSummary(
  List<Map<String, dynamic>> records,
) {
  final summary = <String, int>{};
  for (final record in records) {
    final mismatchFields = record['mismatchFields'];
    if (mismatchFields is! List) {
      continue;
    }
    for (final field in mismatchFields) {
      final normalizedField = field?.toString().trim();
      if (normalizedField == null || normalizedField.isEmpty) {
        continue;
      }
      summary.update(normalizedField, (count) => count + 1, ifAbsent: () => 1);
    }
  }
  return summary;
}

Map<String, Map<String, int>> _buildCategoryMismatchFieldSummary(
  List<Map<String, dynamic>> records,
) {
  return _buildGroupedMismatchFieldSummary(records, groupKey: 'category');
}

Map<String, Map<String, int>> _buildGroupedMismatchFieldSummary(
  List<Map<String, dynamic>> records, {
  required String groupKey,
}) {
  final summary = <String, Map<String, int>>{};
  for (final record in records) {
    final group = record[groupKey]?.toString().trim();
    if (group == null || group.isEmpty) {
      continue;
    }
    final mismatchFields = record['mismatchFields'];
    if (mismatchFields is! List || mismatchFields.isEmpty) {
      continue;
    }
    final groupSummary = summary.putIfAbsent(group, () => <String, int>{});
    for (final field in mismatchFields) {
      final normalizedField = field?.toString().trim();
      if (normalizedField == null || normalizedField.isEmpty) {
        continue;
      }
      groupSummary.update(
        normalizedField,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
  }
  return summary;
}

Future<Map<String, dynamic>> _buildHistoryRollups({
  required String historyResultsRootPath,
  required List<_ResolvedScenario> resolvedScenarios,
}) async {
  final directory = Directory(historyResultsRootPath);
  if (!directory.existsSync()) {
    return const <String, dynamic>{};
  }

  final scenarioMetadataByScenarioId = <String, Map<String, dynamic>>{
    for (final resolvedScenario in resolvedScenarios)
      resolvedScenario.definition.scenarioId: _buildScenarioHistoryMetadata(
        resolvedScenario,
      ),
  };
  final historyRecords = <Map<String, dynamic>>[];
  final historyFiles =
      directory
          .listSync()
          .whereType<File>()
          .where((file) {
            final fileName = file.path.split('/').last;
            return fileName.startsWith('result_') && fileName.endsWith('.json');
          })
          .toList(growable: false)
        ..sort((left, right) => left.path.compareTo(right.path));

  for (final historyFile in historyFiles) {
    final result = ScenarioResult.fromJsonString(
      await historyFile.readAsString(),
    );
    final metadata = scenarioMetadataByScenarioId[result.scenarioId];
    final category = metadata?['category']?.toString();
    final scenarioSet = metadata?['scenarioSet']?.toString();
    final status = metadata?['status']?.toString();
    final tags = metadata?['tags'] is List
        ? List<String>.from(metadata!['tags'] as List)
        : const <String>[];
    if (category == null ||
        category.isEmpty ||
        scenarioSet == null ||
        scenarioSet.isEmpty ||
        status == null ||
        status.isEmpty) {
      continue;
    }
    final commandBrainSnapshot = result.actualOutcome.commandBrainSnapshot;
    final commandBrainTimeline = result.actualOutcome.commandBrainTimeline;
    final orderedReplayBiasStack =
        commandBrainSnapshot?.orderedReplayBiasStack ??
        const <BrainDecisionBias>[];
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
    final sequenceFallbackLifecycleRecord =
        _buildSequenceFallbackLifecycleRecord(result.actualOutcome);
    final commandBrainTimelineSignature = commandBrainTimeline.isEmpty
        ? null
        : commandBrainTimeline
              .map((entry) => entry.signatureSegment)
              .join(' -> ');
    historyRecords.add(<String, dynamic>{
      'scenarioId': result.scenarioId,
      'category': category,
      'scenarioSet': scenarioSet,
      'status': status,
      'tags': tags,
      'passed': result.passed,
      'runId': result.runId.toUtc().toIso8601String(),
      'actualRoute': result.actualOutcome.actualRoute,
      'mismatchFields': result.mismatches
          .map((mismatch) => mismatch.field)
          .toList(growable: false),
      if (commandBrainSnapshot != null)
        'commandBrainFinalTarget': commandBrainSnapshot.target.name,
      if (commandBrainSnapshot != null)
        'commandBrainFinalMode': commandBrainSnapshot.mode.name,
      if (commandBrainSnapshot?.decisionBias != null)
        'commandBrainFinalBiasSource':
            commandBrainSnapshot!.decisionBias!.source.name,
      if (commandBrainSnapshot?.decisionBias != null)
        'commandBrainFinalBiasScope':
            commandBrainSnapshot!.decisionBias!.scope.name,
      if (commandBrainSnapshot?.decisionBias != null)
        'commandBrainFinalBiasSignature':
            '${commandBrainSnapshot!.decisionBias!.source.name}:${commandBrainSnapshot.decisionBias!.scope.name}',
      if (orderedReplayBiasStack.isNotEmpty)
        'commandBrainFinalReplayBiasStackLength': orderedReplayBiasStack.length,
      if (commandBrainSnapshot?.replayBiasStackSignature != null)
        'commandBrainFinalReplayBiasStackSignature':
            commandBrainSnapshot!.replayBiasStackSignature,
      'commandBrainTimelineSignature': ?commandBrainTimelineSignature,
      if (specialistDegradationRecord != null) ...specialistDegradationRecord,
      if (specialistConflictRecord != null) ...specialistConflictRecord,
      if (specialistConflictLifecycleRecord != null)
        ...specialistConflictLifecycleRecord,
      if (specialistConstraintRecord != null) ...specialistConstraintRecord,
      if (specialistConstraintLifecycleRecord != null)
        ...specialistConstraintLifecycleRecord,
      if (sequenceFallbackLifecycleRecord != null)
        ...sequenceFallbackLifecycleRecord,
    });
  }

  if (historyRecords.isEmpty) {
    return const <String, dynamic>{};
  }

  final latestHistoryRecordByScenarioId = _buildLatestHistoryRecordByScenarioId(
    historyRecords,
  );
  final historyTagRecords = _expandHistoryRecordsByTag(historyRecords);
  final historyCategorySummary = _buildHistoryCategorySummary(historyRecords);
  final historyCategoryMismatchFieldSummary =
      _buildCategoryMismatchFieldSummary(historyRecords);
  final historyCategoryMismatchFieldTrendSummary =
      _buildHistoryGroupedMismatchFieldTrendSummary(
        historyRecords,
        groupKey: 'category',
      );
  final historyTagSummary = _buildHistoryTagSummary(historyTagRecords);
  final historyTagMismatchFieldSummary = _buildTagMismatchFieldSummary(
    historyTagRecords,
  );
  final historyTagMismatchFieldTrendSummary =
      _buildHistoryGroupedMismatchFieldTrendSummary(
        historyTagRecords,
        groupKey: 'tag',
      );
  final historyScenarioSummary = _buildHistoryScenarioSummary(historyRecords);
  final historyScenarioMismatchFieldSummary =
      _buildHistoryScenarioMismatchFieldSummary(historyRecords);
  final historyScenarioMismatchFieldTrendSummary =
      _buildHistoryGroupedMismatchFieldTrendSummary(
        historyRecords,
        groupKey: 'scenarioId',
      );
  final historyScenarioSpecialistDegradationSummary =
      _buildHistoryScenarioSpecialistDegradationSummary(historyRecords);
  final historyScenarioSpecialistConflictSummary =
      _buildHistoryScenarioSpecialistConflictSummary(historyRecords);
  final historyScenarioSpecialistConstraintSummary =
      _buildHistoryScenarioSpecialistConstraintSummary(historyRecords);
  final historyScenarioSequenceFallbackSummary =
      _buildHistoryScenarioSequenceFallbackSummary(historyRecords);
  final historyAlerts = _buildHistoryAlerts(
    historyScenarioSummary: historyScenarioSummary,
    historyScenarioSpecialistConflictSummary:
        historyScenarioSpecialistConflictSummary,
    historyScenarioSpecialistConstraintSummary:
        historyScenarioSpecialistConstraintSummary,
    historyScenarioSpecialistDegradationSummary:
        historyScenarioSpecialistDegradationSummary,
    historyScenarioSequenceFallbackSummary:
        historyScenarioSequenceFallbackSummary,
    historyScenarioMismatchFieldTrendSummary:
        historyScenarioMismatchFieldTrendSummary,
    scenarioMetadataByScenarioId: scenarioMetadataByScenarioId,
    latestHistoryRecordByScenarioId: latestHistoryRecordByScenarioId,
  );
  final historyFocusSummary = _buildHistoryFocusSummary(
    historyCategorySummary: historyCategorySummary,
    historyCategoryMismatchFieldTrendSummary:
        historyCategoryMismatchFieldTrendSummary,
    historyTagSummary: historyTagSummary,
    historyTagMismatchFieldTrendSummary: historyTagMismatchFieldTrendSummary,
    historyScenarioSummary: historyScenarioSummary,
    historyScenarioSpecialistConflictSummary:
        historyScenarioSpecialistConflictSummary,
    historyScenarioSpecialistConstraintSummary:
        historyScenarioSpecialistConstraintSummary,
    historyScenarioSequenceFallbackSummary:
        historyScenarioSequenceFallbackSummary,
    historyScenarioMismatchFieldTrendSummary:
        historyScenarioMismatchFieldTrendSummary,
  );

  return <String, dynamic>{
    'historyFocusSummary': historyFocusSummary,
    'historyCategorySummary': historyCategorySummary,
    'historyCommandBrainFinalTargetSummary': _buildRunSummary(
      historyRecords,
      groupKey: 'commandBrainFinalTarget',
    ),
    'historyCommandBrainFinalModeSummary': _buildRunSummary(
      historyRecords,
      groupKey: 'commandBrainFinalMode',
    ),
    'historyCommandBrainFinalBiasSourceSummary': _buildRunSummary(
      historyRecords,
      groupKey: 'commandBrainFinalBiasSource',
    ),
    'historyCommandBrainFinalBiasScopeSummary': _buildRunSummary(
      historyRecords,
      groupKey: 'commandBrainFinalBiasScope',
    ),
    'historyCommandBrainFinalBiasSignatureSummary': _buildRunSummary(
      historyRecords,
      groupKey: 'commandBrainFinalBiasSignature',
    ),
    'historyCommandBrainFinalReplayBiasStackLengthSummary': _buildRunSummary(
      historyRecords,
      groupKey: 'commandBrainFinalReplayBiasStackLength',
    ),
    'historyCommandBrainFinalReplayBiasStackSignatureSummary': _buildRunSummary(
      historyRecords,
      groupKey: 'commandBrainFinalReplayBiasStackSignature',
    ),
    'historyCommandBrainTimelineSummary': _buildRunSummary(
      historyRecords,
      groupKey: 'commandBrainTimelineSignature',
    ),
    'historySpecialistDegradationBranchSummary': _buildRunSummary(
      historyRecords,
      groupKey: 'specialistDegradationBranch',
    ),
    'historySpecialistDegradationSignatureSummary': _buildRunSummary(
      historyRecords,
      groupKey: 'specialistDegradationSignature',
    ),
    'historySpecialistConflictBranchSummary': _buildRunSummary(
      historyRecords,
      groupKey: 'specialistConflictBranch',
    ),
    'historySpecialistConflictSignatureSummary': _buildRunSummary(
      historyRecords,
      groupKey: 'specialistConflictSignature',
    ),
    'historySpecialistConflictLifecycleSummary': _buildRunSummary(
      historyRecords,
      groupKey: 'specialistConflictLifecycle',
    ),
    'historySpecialistConflictLifecycleSignatureSummary': _buildRunSummary(
      historyRecords,
      groupKey: 'specialistConflictLifecycleSignature',
    ),
    'historySpecialistConstraintBranchSummary': _buildRunSummary(
      historyRecords,
      groupKey: 'specialistConstraintBranch',
    ),
    'historySpecialistConstraintSignatureSummary': _buildRunSummary(
      historyRecords,
      groupKey: 'specialistConstraintSignature',
    ),
    'historySpecialistConstraintLifecycleSummary': _buildRunSummary(
      historyRecords,
      groupKey: 'specialistConstraintLifecycle',
    ),
    'historySpecialistConstraintLifecycleSignatureSummary': _buildRunSummary(
      historyRecords,
      groupKey: 'specialistConstraintLifecycleSignature',
    ),
    'historySequenceFallbackLifecycleSummary':
        _buildHistoryScenarioLifecycleSummary(
          historyScenarioSequenceFallbackSummary,
          lifecycleKey: 'latestLifecycle',
        ),
    'historySequenceFallbackLifecycleSignatureSummary':
        _buildHistoryScenarioLifecycleSummary(
          historyScenarioSequenceFallbackSummary,
          lifecycleKey: 'latestLifecycleSignature',
        ),
    'historyScenarioSpecialistDegradationSummary':
        historyScenarioSpecialistDegradationSummary,
    'historyScenarioSpecialistConflictSummary':
        historyScenarioSpecialistConflictSummary,
    'historyScenarioSpecialistConstraintSummary':
        historyScenarioSpecialistConstraintSummary,
    'historyScenarioSequenceFallbackSummary':
        historyScenarioSequenceFallbackSummary,
    'historyCategoryMismatchFieldSummary': historyCategoryMismatchFieldSummary,
    'historyCategoryMismatchFieldTrendSummary':
        historyCategoryMismatchFieldTrendSummary,
    'historyTagSummary': historyTagSummary,
    'historyTagMismatchFieldSummary': historyTagMismatchFieldSummary,
    'historyTagMismatchFieldTrendSummary': historyTagMismatchFieldTrendSummary,
    'historyScenarioSummary': historyScenarioSummary,
    'historyScenarioMismatchFieldSummary': historyScenarioMismatchFieldSummary,
    'historyScenarioMismatchFieldTrendSummary':
        historyScenarioMismatchFieldTrendSummary,
    'historyAlertSummary': _buildHistoryAlertSummary(historyAlerts),
    'historyAlertCategorySummary': _buildHistoryAlertGroupSummary(
      historyAlerts,
      groupKey: 'category',
    ),
    'historyAlertCategoryFieldSummary': _buildGroupedAlertFieldSummary(
      historyAlerts,
      groupKey: 'category',
    ),
    'historyAlertScenarioSummary': _buildHistoryAlertGroupSummary(
      historyAlerts,
      groupKey: 'scenarioId',
    ),
    'historyAlertScenarioFieldSummary': _buildGroupedAlertFieldSummary(
      historyAlerts,
      groupKey: 'scenarioId',
    ),
    'historyAlertFieldSummary': _buildHistoryAlertFieldSummary(historyAlerts),
    'historyAlertSpecialistDegradationSummary':
        _buildSpecialistDegradationAlertSummary(historyAlerts),
    'historyAlertSpecialistConflictSummary':
        _buildSpecialistConflictAlertSummary(historyAlerts),
    'historyAlertSpecialistConstraintSummary':
        _buildSpecialistConstraintAlertSummary(historyAlerts),
    'historyAlertSequenceFallbackSummary': _buildSequenceFallbackAlertSummary(
      historyAlerts,
    ),
    'historyAlertCommandBrainReplayBiasStackSummary':
        _buildCommandBrainReplayBiasStackAlertSummary(historyAlerts),
    'historyAlertCommandBrainTimelineSummary':
        _buildCommandBrainTimelineAlertSummary(historyAlerts),
    'historyAlertTrendSummary': _buildHistoryAlertGroupSummary(
      historyAlerts,
      groupKey: 'trend',
    ),
    'historyAlertScenarioSetSummary': _buildHistoryAlertGroupSummary(
      historyAlerts,
      groupKey: 'scenarioSet',
    ),
    'historyAlertStatusSummary': _buildHistoryAlertGroupSummary(
      historyAlerts,
      groupKey: 'status',
    ),
    'historyAlertTagSummary': _buildHistoryAlertTagSummary(historyAlerts),
    'historyAlertTagFieldSummary': _buildAlertTagFieldSummary(historyAlerts),
    'historyAlerts': historyAlerts,
  };
}

Map<String, dynamic> _buildScenarioHistoryMetadata(
  _ResolvedScenario resolvedScenario,
) {
  final expectedTimeline =
      resolvedScenario.definition.expectedOutcome.commandBrainTimeline;
  final expectedSnapshot =
      resolvedScenario.definition.expectedOutcome.commandBrainSnapshot ??
      (expectedTimeline.isEmpty ? null : expectedTimeline.last.snapshot);
  final expectedTimelineSignature = expectedTimeline.isEmpty
      ? null
      : expectedTimeline.map((entry) => entry.signatureSegment).join(' -> ');
  return <String, dynamic>{
    'category': resolvedScenario.definition.category,
    'scenarioSet': resolvedScenario.definition.scenarioSet,
    'status': resolvedScenario.definition.status,
    'tags': resolvedScenario.definition.tags,
    if (expectedSnapshot != null)
      'expectedCommandBrainFinalTarget': expectedSnapshot.target.name,
    if (expectedSnapshot != null)
      'expectedCommandBrainFinalMode': expectedSnapshot.mode.name,
    if (expectedSnapshot?.replayBiasStackSignature != null)
      'expectedCommandBrainFinalReplayBiasStackSignature':
          expectedSnapshot!.replayBiasStackSignature,
    'expectedCommandBrainTimelineSignature': ?expectedTimelineSignature,
  };
}

Map<String, Map<String, dynamic>> _buildHistoryCategorySummary(
  List<Map<String, dynamic>> records,
) {
  return _buildHistorySummary(records, groupKey: 'category');
}

Map<String, Map<String, dynamic>> _buildHistoryTagSummary(
  List<Map<String, dynamic>> records,
) {
  return _buildHistorySummary(records, groupKey: 'tag');
}

Map<String, Map<String, dynamic>> _buildHistoryScenarioSummary(
  List<Map<String, dynamic>> records,
) {
  return _buildHistorySummary(records, groupKey: 'scenarioId');
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
      'runCount': sortedRecords.length,
      'degradedRunCount': degradedRunCount,
      'persistentCount': persistentCount,
      'recoveredCount': recoveredCount,
      'latestBranch':
          latestRecord['specialistDegradationBranch']?.toString().trim() ??
          'clean',
      'lastRunAt': latestRecord['runId'],
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
    final recoveryOutcomes = sortedRecords
        .map(
          (record) =>
              record['specialistConflictLifecycle']?.toString().trim() ==
              'recovered_in_run',
        )
        .toList(growable: false);
    final recoveredInRunCount = recoveryOutcomes.where((value) => value).length;
    final activeInRunCount = sortedRecords
        .where(
          (record) =>
              record['specialistConflictLifecycle']?.toString().trim() ==
              'active_in_run',
        )
        .length;
    final latestRecord = sortedRecords.last;
    final latestBranch =
        latestRecord['specialistConflictBranch']?.toString().trim() ?? 'clean';
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
      'runCount': sortedRecords.length,
      'conflictRunCount': conflictRunCount,
      'clearedCount': sortedRecords.length - conflictRunCount,
      'persistentCount': persistentCount,
      'recoveredInRunCount': recoveredInRunCount,
      'activeInRunCount': activeInRunCount,
      'latestBranch': latestBranch,
      'lastRunAt': latestRecord['runId'],
      'trend': _buildHistoryFieldTrend(persistentOutcomes),
      'latestSummary': ?latestSummary,
      if (latestSpecialists.isNotEmpty) 'latestSpecialists': latestSpecialists,
      if (latestTargets.isNotEmpty) 'latestTargets': latestTargets,
      if (latestRecord['specialistConflictLifecycle'] != null)
        'latestLifecycle': latestRecord['specialistConflictLifecycle'],
      if (latestRecord['specialistConflictSignature'] != null)
        'latestSignature': latestRecord['specialistConflictSignature'],
      if (latestRecord['specialistConflictLifecycleSignature'] != null)
        'latestLifecycleSignature':
            latestRecord['specialistConflictLifecycleSignature'],
      if (latestRecord['specialistConflictRecoveryStage'] != null)
        'latestRecoveryStage': latestRecord['specialistConflictRecoveryStage'],
      'recoveryTrend': _buildHistoryTrend(recoveryOutcomes),
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
    final constrainedCount = sortedRecords
        .where(
          (record) =>
              record['specialistConstraintBranch']?.toString().trim() ==
              'constrained',
        )
        .length;
    final recoveryOutcomes = sortedRecords
        .map(
          (record) =>
              record['specialistConstraintLifecycle']?.toString().trim() ==
              'recovered_in_run',
        )
        .toList(growable: false);
    final recoveredInRunCount = recoveryOutcomes.where((value) => value).length;
    final activeInRunCount = sortedRecords
        .where(
          (record) =>
              record['specialistConstraintLifecycle']?.toString().trim() ==
              'active_in_run',
        )
        .length;
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
      'runCount': sortedRecords.length,
      'constraintRunCount': constraintRunCount,
      'clearedCount': sortedRecords.length - constraintRunCount,
      'blockingCount': blockingCount,
      'constrainedCount': constrainedCount,
      'recoveredInRunCount': recoveredInRunCount,
      'activeInRunCount': activeInRunCount,
      'latestBranch': latestBranch,
      'lastRunAt': latestRecord['runId'],
      'trend': _buildHistoryFieldTrend(blockingOutcomes),
      'latestAllowRouteExecution': latestAllowRouteExecution,
      if (latestRecord['specialistConstraintLifecycle'] != null)
        'latestLifecycle': latestRecord['specialistConstraintLifecycle'],
      if (latestRecord['specialistConstraintSignature'] != null)
        'latestSignature': latestRecord['specialistConstraintSignature'],
      'latestSpecialist': ?latestSpecialist,
      'latestTarget': ?latestTarget,
      if (latestRecord['specialistConstraintLifecycleSignature'] != null)
        'latestLifecycleSignature':
            latestRecord['specialistConstraintLifecycleSignature'],
      if (latestRecord['specialistConstraintRecoveryStage'] != null)
        'latestRecoveryStage':
            latestRecord['specialistConstraintRecoveryStage'],
      'recoveryTrend': _buildHistoryTrend(recoveryOutcomes),
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
    final activeOutcomes = sortedRecords
        .map(
          (record) =>
              record['commandBrainFinalBiasScope']?.toString().trim() ==
              BrainDecisionBiasScope.sequenceFallback.name,
        )
        .toList(growable: false);
    final fallbackRunCount = activeOutcomes.where((value) => value).length;
    if (fallbackRunCount == 0) {
      continue;
    }

    final latestRecord = sortedRecords.last;
    final latestFallbackRecord = _latestRecordMatching(
      sortedRecords,
      (record) =>
          record['commandBrainFinalBiasScope']?.toString().trim() ==
          BrainDecisionBiasScope.sequenceFallback.name,
    );
    final latestBranch = activeOutcomes.last ? 'active' : 'clean';
    final latestTarget = latestBranch == 'active'
        ? latestRecord['commandBrainFinalTarget']?.toString() ??
              latestRecord['actualRoute']?.toString()
        : latestRecord['commandBrainFinalTarget']?.toString() ??
              latestRecord['actualRoute']?.toString();
    final latestRestoredTarget = latestBranch == 'clean'
        ? latestRecord['commandBrainFinalTarget']?.toString() ??
              latestRecord['actualRoute']?.toString()
        : null;
    final latestLifecycle = latestBranch == 'active'
        ? 'active_in_run'
        : 'cleared_after_run';
    final latestLifecycleSignature = latestBranch == 'active'
        ? latestRecord['sequenceFallbackLifecycleSignature']?.toString() ??
              'active_in_run:replayPolicy:sequenceFallback:${latestTarget ?? 'unknown'}'
        : 'cleared_after_run:${latestRestoredTarget ?? 'unknown'}:${latestFallbackRecord?['commandBrainFinalTarget']?.toString() ?? latestFallbackRecord?['actualRoute']?.toString() ?? 'unknown'}';
    final latestSummary = latestBranch == 'active'
        ? latestRecord['commandBrainFinalBiasSignature']?.toString()
        : _buildSequenceFallbackRecoverySummary(
            restoredTarget: latestRestoredTarget,
            fallbackTarget:
                latestFallbackRecord?['commandBrainFinalTarget']?.toString() ??
                latestFallbackRecord?['actualRoute']?.toString(),
          );
    final clearedAfterRunOutcomes = activeOutcomes
        .map((isActive) => !isActive)
        .toList(growable: false);
    final activeInRunCount = sortedRecords
        .where(
          (record) =>
              record['sequenceFallbackLifecycle']?.toString().trim() ==
              'active_in_run',
        )
        .length;
    final clearedAfterRunCount = sortedRecords.length - fallbackRunCount;

    summary[entry.key] = <String, dynamic>{
      'runCount': sortedRecords.length,
      'fallbackRunCount': fallbackRunCount,
      'clearedAfterRunCount': clearedAfterRunCount,
      'activeInRunCount': activeInRunCount,
      'latestBranch': latestBranch,
      'lastRunAt': latestRecord['runId'],
      'trend': _buildHistoryFieldTrend(activeOutcomes),
      'latestLifecycle': latestLifecycle,
      'latestLifecycleSignature': latestLifecycleSignature,
      'latestTarget': ?latestTarget,
      'latestRestoredTarget': ?latestRestoredTarget,
      'latestSummary': ?latestSummary,
      'recoveryTrend': _buildHistoryTrend(clearedAfterRunOutcomes),
    };
  }
  return summary;
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

Map<String, dynamic> _buildHistoryFocusSummary({
  required Map<String, Map<String, dynamic>> historyCategorySummary,
  required Map<String, Map<String, Map<String, dynamic>>>
  historyCategoryMismatchFieldTrendSummary,
  required Map<String, Map<String, dynamic>> historyTagSummary,
  required Map<String, Map<String, Map<String, dynamic>>>
  historyTagMismatchFieldTrendSummary,
  required Map<String, Map<String, dynamic>> historyScenarioSummary,
  required Map<String, Map<String, dynamic>>
  historyScenarioSpecialistConflictSummary,
  required Map<String, Map<String, dynamic>>
  historyScenarioSpecialistConstraintSummary,
  required Map<String, Map<String, dynamic>>
  historyScenarioSequenceFallbackSummary,
  required Map<String, Map<String, Map<String, dynamic>>>
  historyScenarioMismatchFieldTrendSummary,
}) {
  final topScenario = _buildHistoryFocusEntry(
    historyScenarioSummary,
    keyName: 'scenarioId',
    mismatchFieldTrendSummary: historyScenarioMismatchFieldTrendSummary,
  );
  final topCategory = _buildHistoryFocusEntry(
    historyCategorySummary,
    keyName: 'category',
    mismatchFieldTrendSummary: historyCategoryMismatchFieldTrendSummary,
  );
  final topTag = _buildHistoryFocusEntry(
    historyTagSummary,
    keyName: 'tag',
    mismatchFieldTrendSummary: historyTagMismatchFieldTrendSummary,
  );
  final topConflictRecoveryScenario = _buildHistoryConflictRecoveryFocusEntry(
    historyScenarioSpecialistConflictSummary,
  );
  final topConstraintRecoveryScenario =
      _buildHistoryConstraintRecoveryFocusEntry(
        historyScenarioSpecialistConstraintSummary,
      );
  final topSequenceFallbackRecoveryScenario =
      _buildHistorySequenceFallbackRecoveryFocusEntry(
        historyScenarioSequenceFallbackSummary,
      );
  return <String, dynamic>{
    'topScenario': ?topScenario,
    'topCategory': ?topCategory,
    'topTag': ?topTag,
    'topConflictRecoveryScenario': ?topConflictRecoveryScenario,
    'topConstraintRecoveryScenario': ?topConstraintRecoveryScenario,
    'topSequenceFallbackRecoveryScenario':
        ?topSequenceFallbackRecoveryScenario,
  };
}

Map<String, dynamic>? _buildHistoryConflictRecoveryFocusEntry(
  Map<String, Map<String, dynamic>> summary,
) {
  final recoveryEntries = summary.entries
      .where(
        (entry) =>
            (entry.value['recoveredInRunCount'] is int
                ? entry.value['recoveredInRunCount'] as int
                : 0) >
            0,
      )
      .toList(growable: false);
  if (recoveryEntries.isEmpty) {
    return null;
  }
  final sortedEntries =
      List<MapEntry<String, Map<String, dynamic>>>.from(recoveryEntries)..sort((
        left,
        right,
      ) {
        final recoveryTrendOrder =
            _historyTrendRank(
              right.value['recoveryTrend']?.toString() ?? '',
            ).compareTo(
              _historyTrendRank(left.value['recoveryTrend']?.toString() ?? ''),
            );
        if (recoveryTrendOrder != 0) {
          return recoveryTrendOrder;
        }
        final leftRecoveredCount = left.value['recoveredInRunCount'] is int
            ? left.value['recoveredInRunCount'] as int
            : 0;
        final rightRecoveredCount = right.value['recoveredInRunCount'] is int
            ? right.value['recoveredInRunCount'] as int
            : 0;
        if (leftRecoveredCount != rightRecoveredCount) {
          return rightRecoveredCount.compareTo(leftRecoveredCount);
        }
        final leftLastRunAt = left.value['lastRunAt']?.toString() ?? '';
        final rightLastRunAt = right.value['lastRunAt']?.toString() ?? '';
        final lastRunOrder = rightLastRunAt.compareTo(leftLastRunAt);
        if (lastRunOrder != 0) {
          return lastRunOrder;
        }
        return left.key.compareTo(right.key);
      });
  final topEntry = sortedEntries.first;
  final topValue = topEntry.value;
  return <String, dynamic>{
    'scenarioId': topEntry.key,
    'recoveredInRunCount': topValue['recoveredInRunCount'],
    'recoveryTrend': topValue['recoveryTrend'],
    'lastRunAt': topValue['lastRunAt'],
    if (topValue['latestLifecycle'] != null)
      'latestLifecycle': topValue['latestLifecycle'],
    if (topValue['latestRecoveryStage'] != null)
      'latestRecoveryStage': topValue['latestRecoveryStage'],
    if (topValue['latestSummary'] != null)
      'latestSummary': topValue['latestSummary'],
    if (topValue['latestTargets'] != null)
      'latestTargets': topValue['latestTargets'],
  };
}

Map<String, dynamic>? _buildHistoryConstraintRecoveryFocusEntry(
  Map<String, Map<String, dynamic>> summary,
) {
  final recoveryEntries = summary.entries
      .where(
        (entry) =>
            (entry.value['recoveredInRunCount'] is int
                ? entry.value['recoveredInRunCount'] as int
                : 0) >
            0,
      )
      .toList(growable: false);
  if (recoveryEntries.isEmpty) {
    return null;
  }
  final sortedEntries =
      List<MapEntry<String, Map<String, dynamic>>>.from(recoveryEntries)..sort((
        left,
        right,
      ) {
        final recoveryTrendOrder =
            _historyTrendRank(
              right.value['recoveryTrend']?.toString() ?? '',
            ).compareTo(
              _historyTrendRank(left.value['recoveryTrend']?.toString() ?? ''),
            );
        if (recoveryTrendOrder != 0) {
          return recoveryTrendOrder;
        }
        final leftRecoveredCount = left.value['recoveredInRunCount'] is int
            ? left.value['recoveredInRunCount'] as int
            : 0;
        final rightRecoveredCount = right.value['recoveredInRunCount'] is int
            ? right.value['recoveredInRunCount'] as int
            : 0;
        if (leftRecoveredCount != rightRecoveredCount) {
          return rightRecoveredCount.compareTo(leftRecoveredCount);
        }
        final leftLastRunAt = left.value['lastRunAt']?.toString() ?? '';
        final rightLastRunAt = right.value['lastRunAt']?.toString() ?? '';
        final lastRunOrder = rightLastRunAt.compareTo(leftLastRunAt);
        if (lastRunOrder != 0) {
          return lastRunOrder;
        }
        return left.key.compareTo(right.key);
      });
  final topEntry = sortedEntries.first;
  final topValue = topEntry.value;
  return <String, dynamic>{
    'scenarioId': topEntry.key,
    'recoveredInRunCount': topValue['recoveredInRunCount'],
    'recoveryTrend': topValue['recoveryTrend'],
    'lastRunAt': topValue['lastRunAt'],
    if (topValue['latestLifecycle'] != null)
      'latestLifecycle': topValue['latestLifecycle'],
    if (topValue['latestRecoveryStage'] != null)
      'latestRecoveryStage': topValue['latestRecoveryStage'],
    if (topValue['latestTarget'] != null)
      'latestTarget': topValue['latestTarget'],
  };
}

Map<String, dynamic>? _buildHistorySequenceFallbackRecoveryFocusEntry(
  Map<String, Map<String, dynamic>> summary,
) {
  final recoveryEntries = summary.entries
      .where(
        (entry) =>
            (entry.value['clearedAfterRunCount'] is int
                ? entry.value['clearedAfterRunCount'] as int
                : 0) >
            0,
      )
      .toList(growable: false);
  if (recoveryEntries.isEmpty) {
    return null;
  }
  final sortedEntries =
      List<MapEntry<String, Map<String, dynamic>>>.from(recoveryEntries)..sort((
        left,
        right,
      ) {
        final recoveryTrendOrder =
            _historyTrendRank(
              right.value['recoveryTrend']?.toString() ?? '',
            ).compareTo(
              _historyTrendRank(left.value['recoveryTrend']?.toString() ?? ''),
            );
        if (recoveryTrendOrder != 0) {
          return recoveryTrendOrder;
        }
        final leftClearedCount = left.value['clearedAfterRunCount'] is int
            ? left.value['clearedAfterRunCount'] as int
            : 0;
        final rightClearedCount = right.value['clearedAfterRunCount'] is int
            ? right.value['clearedAfterRunCount'] as int
            : 0;
        if (leftClearedCount != rightClearedCount) {
          return rightClearedCount.compareTo(leftClearedCount);
        }
        final leftLastRunAt = left.value['lastRunAt']?.toString() ?? '';
        final rightLastRunAt = right.value['lastRunAt']?.toString() ?? '';
        final lastRunOrder = rightLastRunAt.compareTo(leftLastRunAt);
        if (lastRunOrder != 0) {
          return lastRunOrder;
        }
        return left.key.compareTo(right.key);
      });
  final topEntry = sortedEntries.first;
  final topValue = topEntry.value;
  return <String, dynamic>{
    'scenarioId': topEntry.key,
    'clearedAfterRunCount': topValue['clearedAfterRunCount'],
    'recoveryTrend': topValue['recoveryTrend'],
    'lastRunAt': topValue['lastRunAt'],
    if (topValue['latestLifecycle'] != null)
      'latestLifecycle': topValue['latestLifecycle'],
    if (topValue['latestTarget'] != null)
      'latestTarget': topValue['latestTarget'],
    if (topValue['latestRestoredTarget'] != null)
      'latestRestoredTarget': topValue['latestRestoredTarget'],
  };
}

Map<String, dynamic>? _buildHistoryFocusEntry(
  Map<String, Map<String, dynamic>> summary, {
  required String keyName,
  required Map<String, Map<String, Map<String, dynamic>>>
  mismatchFieldTrendSummary,
}) {
  if (summary.isEmpty) {
    return null;
  }
  final entries = summary.entries.toList()..sort(_compareHistoryFocusEntries);
  final topEntry = entries.first;
  final topValue = topEntry.value;
  return <String, dynamic>{
    keyName: topEntry.key,
    'runCount': topValue['runCount'],
    'passedCount': topValue['passedCount'],
    'failedCount': topValue['failedCount'],
    'lastRunAt': topValue['lastRunAt'],
    'trend': topValue['trend'],
    'topField': ?_buildHistoryFocusFieldEntry(
      mismatchFieldTrendSummary[topEntry.key],
    ),
  };
}

Map<String, dynamic>? _buildHistoryFocusFieldEntry(
  Map<String, Map<String, dynamic>>? fieldTrendSummary,
) {
  if (fieldTrendSummary == null || fieldTrendSummary.isEmpty) {
    return null;
  }
  final fieldEntries = fieldTrendSummary.entries.toList()
    ..sort(_compareHistoryFocusFieldEntries);
  final topFieldEntry = fieldEntries.first;
  final topFieldValue = topFieldEntry.value;
  return <String, dynamic>{
    'field': topFieldEntry.key,
    'count': topFieldValue['count'],
    'trend': topFieldValue['trend'],
  };
}

int _compareHistoryFocusEntries(
  MapEntry<String, Map<String, dynamic>> left,
  MapEntry<String, Map<String, dynamic>> right,
) {
  final trendOrder = _historyTrendRank(
    right.value['trend']?.toString() ?? '',
  ).compareTo(_historyTrendRank(left.value['trend']?.toString() ?? ''));
  if (trendOrder != 0) {
    return trendOrder;
  }
  final leftFailedCount = left.value['failedCount'] is int
      ? left.value['failedCount'] as int
      : 0;
  final rightFailedCount = right.value['failedCount'] is int
      ? right.value['failedCount'] as int
      : 0;
  if (leftFailedCount != rightFailedCount) {
    return rightFailedCount.compareTo(leftFailedCount);
  }
  final leftRunCount = left.value['runCount'] is int
      ? left.value['runCount'] as int
      : 0;
  final rightRunCount = right.value['runCount'] is int
      ? right.value['runCount'] as int
      : 0;
  if (leftRunCount != rightRunCount) {
    return rightRunCount.compareTo(leftRunCount);
  }
  final leftLastRunAt = left.value['lastRunAt']?.toString() ?? '';
  final rightLastRunAt = right.value['lastRunAt']?.toString() ?? '';
  final lastRunOrder = rightLastRunAt.compareTo(leftLastRunAt);
  if (lastRunOrder != 0) {
    return lastRunOrder;
  }
  return left.key.compareTo(right.key);
}

int _compareHistoryFocusFieldEntries(
  MapEntry<String, Map<String, dynamic>> left,
  MapEntry<String, Map<String, dynamic>> right,
) {
  return _compareMismatchFieldTrendEntries(left, right);
}

String _buildHistoryFocusFieldConsoleSuffix(dynamic focusEntry) {
  if (focusEntry is! Map) {
    return '';
  }
  final topField = focusEntry['topField'];
  if (topField is! Map) {
    return '';
  }
  final field = topField['field']?.toString();
  final trend = topField['trend']?.toString();
  final count = topField['count'];
  if (field == null || field.isEmpty || trend == null || trend.isEmpty) {
    return '';
  }
  return ', focus field $field ($trend, count $count)';
}

String _buildPolicySeverityTransitionConsoleLabel(
  dynamic focusEntry, {
  String severityKey = 'severity',
}) {
  if (focusEntry is! Map) {
    return '';
  }
  final originalSeverity = focusEntry['originalSeverity']
      ?.toString()
      .trim()
      .toLowerCase();
  final promotedSeverity = focusEntry[severityKey]
      ?.toString()
      .trim()
      .toLowerCase();
  if (originalSeverity == null ||
      originalSeverity.isEmpty ||
      promotedSeverity == null ||
      promotedSeverity.isEmpty ||
      originalSeverity == promotedSeverity) {
    return '';
  }
  return ', promoted $originalSeverity -> $promotedSeverity';
}

Map<String, Map<String, dynamic>> _buildHistorySummary(
  List<Map<String, dynamic>> records, {
  required String groupKey,
}) {
  final groupedRecords = <String, List<Map<String, dynamic>>>{};
  for (final record in records) {
    final group = record[groupKey]?.toString().trim();
    if (group == null || group.isEmpty) {
      continue;
    }
    groupedRecords
        .putIfAbsent(group, () => <Map<String, dynamic>>[])
        .add(record);
  }
  final summary = <String, Map<String, dynamic>>{};
  for (final entry in groupedRecords.entries) {
    final sortedRecords = List<Map<String, dynamic>>.from(entry.value)
      ..sort((left, right) {
        final leftRunId = left['runId']?.toString() ?? '';
        final rightRunId = right['runId']?.toString() ?? '';
        return leftRunId.compareTo(rightRunId);
      });
    final outcomes = sortedRecords
        .map((record) => record['passed'] == true)
        .toList(growable: false);
    final passedCount = outcomes.where((passed) => passed).length;
    final runCount = outcomes.length;
    final lastRunAt = sortedRecords.isNotEmpty
        ? sortedRecords.last['runId']?.toString()
        : null;
    summary[entry.key] = <String, dynamic>{
      'runCount': runCount,
      'passedCount': passedCount,
      'failedCount': runCount - passedCount,
      'lastRunAt': lastRunAt,
      'trend': _buildHistoryTrend(outcomes),
    };
  }
  return summary;
}

Map<String, Map<String, int>> _buildHistoryScenarioMismatchFieldSummary(
  List<Map<String, dynamic>> records,
) {
  return _buildGroupedMismatchFieldSummary(records, groupKey: 'scenarioId');
}

Map<String, Map<String, int>> _buildTagMismatchFieldSummary(
  List<Map<String, dynamic>> records,
) {
  return _buildGroupedMismatchFieldSummary(records, groupKey: 'tag');
}

List<Map<String, dynamic>> _expandHistoryRecordsByTag(
  List<Map<String, dynamic>> records,
) {
  final expanded = <Map<String, dynamic>>[];
  for (final record in records) {
    final tags = record['tags'];
    if (tags is! List || tags.isEmpty) {
      continue;
    }
    for (final tag in tags) {
      final normalizedTag = tag?.toString().trim().toLowerCase();
      if (normalizedTag == null || normalizedTag.isEmpty) {
        continue;
      }
      expanded.add(<String, dynamic>{...record, 'tag': normalizedTag});
    }
  }
  return expanded;
}

Map<String, Map<String, Map<String, dynamic>>>
_buildHistoryGroupedMismatchFieldTrendSummary(
  List<Map<String, dynamic>> records, {
  required String groupKey,
}) {
  final recordsByGroup = <String, List<Map<String, dynamic>>>{};
  for (final record in records) {
    final group = record[groupKey]?.toString().trim();
    if (group == null || group.isEmpty) {
      continue;
    }
    recordsByGroup
        .putIfAbsent(group, () => <Map<String, dynamic>>[])
        .add(record);
  }

  final summary = <String, Map<String, Map<String, dynamic>>>{};
  for (final entry in recordsByGroup.entries) {
    final sortedRecords = List<Map<String, dynamic>>.from(entry.value)
      ..sort((left, right) {
        final leftRunId = left['runId']?.toString() ?? '';
        final rightRunId = right['runId']?.toString() ?? '';
        return leftRunId.compareTo(rightRunId);
      });
    final allFields = <String>{};
    for (final record in sortedRecords) {
      final mismatchFields = record['mismatchFields'];
      if (mismatchFields is! List) {
        continue;
      }
      for (final field in mismatchFields) {
        final normalizedField = field?.toString().trim();
        if (normalizedField == null || normalizedField.isEmpty) {
          continue;
        }
        allFields.add(normalizedField);
      }
    }
    if (allFields.isEmpty) {
      continue;
    }

    final fieldSummary = <String, Map<String, dynamic>>{};
    for (final field in allFields) {
      final outcomes = sortedRecords
          .map((record) {
            final mismatchFields = record['mismatchFields'];
            if (mismatchFields is! List) {
              return false;
            }
            return mismatchFields.any(
              (value) => value?.toString().trim() == field,
            );
          })
          .toList(growable: false);
      final count = outcomes.where((present) => present).length;
      fieldSummary[field] = <String, dynamic>{
        'count': count,
        'trend': _buildHistoryFieldTrend(outcomes),
      };
    }
    summary[entry.key] = fieldSummary;
  }
  return summary;
}

String _buildHistoryTrend(List<bool> outcomes) {
  if (outcomes.isEmpty) {
    return 'unknown';
  }
  if (outcomes.length == 1) {
    return outcomes.single ? 'clean' : 'watch';
  }
  final latest = outcomes.last;
  final previous = outcomes[outcomes.length - 2];
  if (latest && !previous) {
    return 'clean_again';
  }
  if (!latest && previous) {
    return 'worsening';
  }
  if (!latest && !previous) {
    return 'stabilizing';
  }
  return 'clean';
}

String? _buildSequenceFallbackRecoverySummary({
  required String? restoredTarget,
  required String? fallbackTarget,
}) {
  final restoredDesk = _toolTargetLabelFromName(restoredTarget);
  final fallbackDesk = _toolTargetLabelFromName(fallbackTarget);
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

String? _toolTargetLabelFromName(String? name) {
  final normalized = name?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  switch (normalized) {
    case 'cctvReview':
      return 'CCTV Review';
    case 'tacticalTrack':
      return 'Tactical Track';
    case 'dispatchBoard':
      return 'Dispatch Board';
    case 'clientComms':
      return 'Client Comms';
    case 'reportsWorkspace':
      return 'Reports Workspace';
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

Map<String, int> _buildHistoryAlertSummary(List<Map<String, dynamic>> alerts) {
  final summary = <String, int>{};
  for (final alert in alerts) {
    final severity = alert['severity']?.toString().trim();
    if (severity == null || severity.isEmpty) {
      continue;
    }
    summary.update(severity, (count) => count + 1, ifAbsent: () => 1);
  }
  return summary;
}

Map<String, int> _buildHistoryAlertGroupSummary(
  List<Map<String, dynamic>> alerts, {
  required String groupKey,
}) {
  final summary = <String, int>{};
  for (final alert in alerts) {
    final group = alert[groupKey]?.toString().trim();
    if (group == null || group.isEmpty) {
      continue;
    }
    summary.update(group, (count) => count + 1, ifAbsent: () => 1);
  }
  return summary;
}

Map<String, int> _buildHistoryAlertTagSummary(
  List<Map<String, dynamic>> alerts,
) {
  final summary = <String, int>{};
  for (final alert in alerts) {
    for (final tag in _readAlertTags(alert['tags'])) {
      summary.update(tag, (count) => count + 1, ifAbsent: () => 1);
    }
  }
  return summary;
}

Map<String, int> _buildHistoryAlertFieldSummary(
  List<Map<String, dynamic>> alerts,
) {
  final summary = <String, int>{};
  for (final alert in alerts) {
    final field = alert['field']?.toString().trim();
    if (field == null || field.isEmpty) {
      continue;
    }
    summary.update(field, (count) => count + 1, ifAbsent: () => 1);
  }
  return summary;
}

Map<String, Map<String, dynamic>> _buildCommandBrainTimelineAlertSummary(
  List<Map<String, dynamic>> alerts,
) {
  final summary = <String, Map<String, dynamic>>{};
  for (final alert in alerts) {
    if (alert['scope']?.toString() != 'command_brain_timeline') {
      continue;
    }
    final scenarioId = alert['scenarioId']?.toString().trim();
    if (scenarioId == null || scenarioId.isEmpty) {
      continue;
    }
    final count = alert['count'] is int ? alert['count'] as int : 0;
    final entry = summary.putIfAbsent(
      scenarioId,
      () => <String, dynamic>{
        'count': 0,
        'trend': alert['trend'],
        'severity': alert['severity'],
        if (alert['expectedCommandBrainTimelineSignature'] != null)
          'expectedTimelineSignature':
              alert['expectedCommandBrainTimelineSignature'],
        if (alert['actualCommandBrainTimelineSignature'] != null)
          'actualTimelineSignature':
              alert['actualCommandBrainTimelineSignature'],
        if (alert['expectedCommandBrainFinalTarget'] != null)
          'expectedFinalTarget': alert['expectedCommandBrainFinalTarget'],
        if (alert['actualCommandBrainFinalTarget'] != null)
          'actualFinalTarget': alert['actualCommandBrainFinalTarget'],
        if (alert['expectedCommandBrainFinalMode'] != null)
          'expectedFinalMode': alert['expectedCommandBrainFinalMode'],
        if (alert['actualCommandBrainFinalMode'] != null)
          'actualFinalMode': alert['actualCommandBrainFinalMode'],
      },
    );
    entry['count'] = (entry['count'] as int? ?? 0) + count;
    final existingTrend = entry['trend']?.toString() ?? '';
    final currentTrend = alert['trend']?.toString() ?? '';
    if (_historyTrendRank(currentTrend) > _historyTrendRank(existingTrend)) {
      entry['trend'] = currentTrend;
    }
    final existingSeverity = entry['severity']?.toString() ?? '';
    final currentSeverity = alert['severity']?.toString() ?? '';
    if (_alertSeverityRank(currentSeverity) >
        _alertSeverityRank(existingSeverity)) {
      entry['severity'] = currentSeverity;
    }
    entry.putIfAbsent(
      'expectedTimelineSignature',
      () => alert['expectedCommandBrainTimelineSignature'],
    );
    entry.putIfAbsent(
      'actualTimelineSignature',
      () => alert['actualCommandBrainTimelineSignature'],
    );
    entry.putIfAbsent(
      'expectedFinalTarget',
      () => alert['expectedCommandBrainFinalTarget'],
    );
    entry.putIfAbsent(
      'actualFinalTarget',
      () => alert['actualCommandBrainFinalTarget'],
    );
    entry.putIfAbsent(
      'expectedFinalMode',
      () => alert['expectedCommandBrainFinalMode'],
    );
    entry.putIfAbsent(
      'actualFinalMode',
      () => alert['actualCommandBrainFinalMode'],
    );
  }
  return summary;
}

Map<String, Map<String, dynamic>> _buildCommandBrainReplayBiasStackAlertSummary(
  List<Map<String, dynamic>> alerts,
) {
  final summary = <String, Map<String, dynamic>>{};
  for (final alert in alerts) {
    if (alert['scope']?.toString() != 'command_brain_replay_bias_stack') {
      continue;
    }
    final scenarioId = alert['scenarioId']?.toString().trim();
    if (scenarioId == null || scenarioId.isEmpty) {
      continue;
    }
    final count = alert['count'] is int ? alert['count'] as int : 0;
    final entry = summary.putIfAbsent(
      scenarioId,
      () => <String, dynamic>{
        'count': 0,
        'trend': alert['trend'],
        'severity': alert['severity'],
        if (alert['expectedCommandBrainReplayBiasStackSignature'] != null)
          'expectedReplayBiasStackSignature':
              alert['expectedCommandBrainReplayBiasStackSignature'],
        if (alert['actualCommandBrainReplayBiasStackSignature'] != null)
          'actualReplayBiasStackSignature':
              alert['actualCommandBrainReplayBiasStackSignature'],
        if (alert['expectedCommandBrainFinalTarget'] != null)
          'expectedFinalTarget': alert['expectedCommandBrainFinalTarget'],
        if (alert['actualCommandBrainFinalTarget'] != null)
          'actualFinalTarget': alert['actualCommandBrainFinalTarget'],
        if (alert['expectedCommandBrainFinalMode'] != null)
          'expectedFinalMode': alert['expectedCommandBrainFinalMode'],
        if (alert['actualCommandBrainFinalMode'] != null)
          'actualFinalMode': alert['actualCommandBrainFinalMode'],
      },
    );
    entry['count'] = (entry['count'] as int? ?? 0) + count;
    final existingTrend = entry['trend']?.toString() ?? '';
    final currentTrend = alert['trend']?.toString() ?? '';
    if (_historyTrendRank(currentTrend) > _historyTrendRank(existingTrend)) {
      entry['trend'] = currentTrend;
    }
    final existingSeverity = entry['severity']?.toString() ?? '';
    final currentSeverity = alert['severity']?.toString() ?? '';
    if (_alertSeverityRank(currentSeverity) > _alertSeverityRank(existingSeverity)) {
      entry['severity'] = currentSeverity;
    }
  }
  return summary;
}

Map<String, Map<String, dynamic>> _buildSpecialistDegradationAlertSummary(
  List<Map<String, dynamic>> alerts,
) {
  final summary = <String, Map<String, dynamic>>{};
  for (final alert in alerts) {
    if (alert['scope']?.toString() != 'specialist_degradation') {
      continue;
    }
    final scenarioId = alert['scenarioId']?.toString().trim();
    if (scenarioId == null || scenarioId.isEmpty) {
      continue;
    }
    final count = alert['count'] is int ? alert['count'] as int : 0;
    final entry = summary.putIfAbsent(
      scenarioId,
      () => <String, dynamic>{
        'count': 0,
        'trend': alert['trend'],
        'severity': alert['severity'],
        if (alert['latestBranch'] != null)
          'latestBranch': alert['latestBranch'],
        if (alert['latestSpecialistDegradationSignature'] != null)
          'latestSignature': alert['latestSpecialistDegradationSignature'],
        if (alert['latestSpecialists'] != null)
          'latestSpecialists': alert['latestSpecialists'],
        if (alert['latestStatuses'] != null)
          'latestStatuses': alert['latestStatuses'],
      },
    );
    entry['count'] = (entry['count'] as int? ?? 0) + count;
    final existingTrend = entry['trend']?.toString() ?? '';
    final currentTrend = alert['trend']?.toString() ?? '';
    if (_historyTrendRank(currentTrend) > _historyTrendRank(existingTrend)) {
      entry['trend'] = currentTrend;
    }
    final existingSeverity = entry['severity']?.toString() ?? '';
    final currentSeverity = alert['severity']?.toString() ?? '';
    if (_alertSeverityRank(currentSeverity) >
        _alertSeverityRank(existingSeverity)) {
      entry['severity'] = currentSeverity;
    }
    entry.putIfAbsent('latestBranch', () => alert['latestBranch']);
    entry.putIfAbsent(
      'latestSignature',
      () => alert['latestSpecialistDegradationSignature'],
    );
    entry.putIfAbsent('latestSpecialists', () => alert['latestSpecialists']);
    entry.putIfAbsent('latestStatuses', () => alert['latestStatuses']);
  }
  return summary;
}

Map<String, Map<String, dynamic>> _buildSpecialistConflictAlertSummary(
  List<Map<String, dynamic>> alerts,
) {
  final summary = <String, Map<String, dynamic>>{};
  for (final alert in alerts) {
    if (alert['scope']?.toString() != 'specialist_conflict') {
      continue;
    }
    final scenarioId = alert['scenarioId']?.toString().trim();
    if (scenarioId == null || scenarioId.isEmpty) {
      continue;
    }
    final count = alert['count'] is int ? alert['count'] as int : 0;
    final entry = summary.putIfAbsent(
      scenarioId,
      () => <String, dynamic>{
        'count': 0,
        'trend': alert['trend'],
        'severity': alert['severity'],
        if (alert['latestBranch'] != null)
          'latestBranch': alert['latestBranch'],
        if (alert['latestSpecialistConflictSignature'] != null)
          'latestSignature': alert['latestSpecialistConflictSignature'],
        if (alert['latestSummary'] != null)
          'latestSummary': alert['latestSummary'],
        if (alert['latestSpecialists'] != null)
          'latestSpecialists': alert['latestSpecialists'],
        if (alert['latestTargets'] != null)
          'latestTargets': alert['latestTargets'],
      },
    );
    entry['count'] = (entry['count'] as int? ?? 0) + count;
    final existingTrend = entry['trend']?.toString() ?? '';
    final currentTrend = alert['trend']?.toString() ?? '';
    if (_historyTrendRank(currentTrend) > _historyTrendRank(existingTrend)) {
      entry['trend'] = currentTrend;
    }
    final existingSeverity = entry['severity']?.toString() ?? '';
    final currentSeverity = alert['severity']?.toString() ?? '';
    if (_alertSeverityRank(currentSeverity) >
        _alertSeverityRank(existingSeverity)) {
      entry['severity'] = currentSeverity;
    }
    entry.putIfAbsent('latestBranch', () => alert['latestBranch']);
    entry.putIfAbsent(
      'latestSignature',
      () => alert['latestSpecialistConflictSignature'],
    );
    entry.putIfAbsent('latestSummary', () => alert['latestSummary']);
    entry.putIfAbsent('latestSpecialists', () => alert['latestSpecialists']);
    entry.putIfAbsent('latestTargets', () => alert['latestTargets']);
  }
  return summary;
}

Map<String, Map<String, dynamic>> _buildSpecialistConstraintAlertSummary(
  List<Map<String, dynamic>> alerts,
) {
  final summary = <String, Map<String, dynamic>>{};
  for (final alert in alerts) {
    if (alert['scope']?.toString() != 'specialist_constraint') {
      continue;
    }
    final scenarioId = alert['scenarioId']?.toString().trim();
    if (scenarioId == null || scenarioId.isEmpty) {
      continue;
    }
    final count = alert['count'] is int ? alert['count'] as int : 0;
    final entry = summary.putIfAbsent(
      scenarioId,
      () => <String, dynamic>{
        'count': 0,
        'trend': alert['trend'],
        'severity': alert['severity'],
        if (alert['latestBranch'] != null)
          'latestBranch': alert['latestBranch'],
        if (alert['latestSpecialistConstraintSignature'] != null)
          'latestSignature': alert['latestSpecialistConstraintSignature'],
        if (alert['latestSpecialist'] != null)
          'latestSpecialist': alert['latestSpecialist'],
        if (alert['latestTarget'] != null)
          'latestTarget': alert['latestTarget'],
        if (alert['latestAllowRouteExecution'] != null)
          'latestAllowRouteExecution': alert['latestAllowRouteExecution'],
      },
    );
    entry['count'] = (entry['count'] as int? ?? 0) + count;
    final existingTrend = entry['trend']?.toString() ?? '';
    final currentTrend = alert['trend']?.toString() ?? '';
    if (_historyTrendRank(currentTrend) > _historyTrendRank(existingTrend)) {
      entry['trend'] = currentTrend;
    }
    final existingSeverity = entry['severity']?.toString() ?? '';
    final currentSeverity = alert['severity']?.toString() ?? '';
    if (_alertSeverityRank(currentSeverity) >
        _alertSeverityRank(existingSeverity)) {
      entry['severity'] = currentSeverity;
    }
    entry.putIfAbsent('latestBranch', () => alert['latestBranch']);
    entry.putIfAbsent(
      'latestSignature',
      () => alert['latestSpecialistConstraintSignature'],
    );
    entry.putIfAbsent('latestSpecialist', () => alert['latestSpecialist']);
    entry.putIfAbsent('latestTarget', () => alert['latestTarget']);
    entry.putIfAbsent(
      'latestAllowRouteExecution',
      () => alert['latestAllowRouteExecution'],
    );
  }
  return summary;
}

Map<String, Map<String, dynamic>> _buildSequenceFallbackAlertSummary(
  List<Map<String, dynamic>> alerts,
) {
  final summary = <String, Map<String, dynamic>>{};
  for (final alert in alerts) {
    if (alert['scope']?.toString() != 'sequence_fallback') {
      continue;
    }
    final scenarioId = alert['scenarioId']?.toString().trim();
    if (scenarioId == null || scenarioId.isEmpty) {
      continue;
    }
    final count = alert['count'] is int ? alert['count'] as int : 0;
    final entry = summary.putIfAbsent(
      scenarioId,
      () => <String, dynamic>{
        'count': 0,
        'trend': alert['trend'],
        'severity': alert['severity'],
        if (alert['latestBranch'] != null)
          'latestBranch': alert['latestBranch'],
        if (alert['latestSequenceFallbackLifecycleSignature'] != null)
          'latestSignature': alert['latestSequenceFallbackLifecycleSignature'],
        if (alert['latestTarget'] != null)
          'latestTarget': alert['latestTarget'],
        if (alert['latestSummary'] != null)
          'latestSummary': alert['latestSummary'],
      },
    );
    entry['count'] = (entry['count'] as int? ?? 0) + count;
    final existingTrend = entry['trend']?.toString() ?? '';
    final currentTrend = alert['trend']?.toString() ?? '';
    if (_historyTrendRank(currentTrend) > _historyTrendRank(existingTrend)) {
      entry['trend'] = currentTrend;
    }
    final existingSeverity = entry['severity']?.toString() ?? '';
    final currentSeverity = alert['severity']?.toString() ?? '';
    if (_alertSeverityRank(currentSeverity) >
        _alertSeverityRank(existingSeverity)) {
      entry['severity'] = currentSeverity;
    }
    entry.putIfAbsent('latestBranch', () => alert['latestBranch']);
    entry.putIfAbsent(
      'latestSignature',
      () => alert['latestSequenceFallbackLifecycleSignature'],
    );
    entry.putIfAbsent('latestTarget', () => alert['latestTarget']);
    entry.putIfAbsent('latestSummary', () => alert['latestSummary']);
  }
  return summary;
}

Map<String, Map<String, int>> _buildGroupedAlertFieldSummary(
  List<Map<String, dynamic>> alerts, {
  required String groupKey,
}) {
  final summary = <String, Map<String, int>>{};
  for (final alert in alerts) {
    final group = alert[groupKey]?.toString().trim();
    final field = alert['field']?.toString().trim();
    if (group == null || group.isEmpty || field == null || field.isEmpty) {
      continue;
    }
    final fieldSummary = summary.putIfAbsent(group, () => <String, int>{});
    fieldSummary.update(field, (count) => count + 1, ifAbsent: () => 1);
  }
  return summary;
}

Map<String, Map<String, int>> _buildAlertTagFieldSummary(
  List<Map<String, dynamic>> alerts,
) {
  final summary = <String, Map<String, int>>{};
  for (final alert in alerts) {
    final field = alert['field']?.toString().trim();
    if (field == null || field.isEmpty) {
      continue;
    }
    for (final tag in _readAlertTags(alert['tags'])) {
      final fieldSummary = summary.putIfAbsent(tag, () => <String, int>{});
      fieldSummary.update(field, (count) => count + 1, ifAbsent: () => 1);
    }
  }
  return summary;
}

Map<String, int> _buildHistoryAlertPolicySummary({
  required dynamic historyAlerts,
  required _AlertFailurePolicy? policy,
  required String? thresholdOverride,
  required String? groupFilterOverride,
  required String? tagFilterOverride,
  required String? categoryFilterOverride,
  required String? statusFilterOverride,
}) {
  final evaluations = _buildHistoryAlertPolicyEvaluations(
    historyAlerts: historyAlerts,
    policy: policy,
    thresholdOverride: thresholdOverride,
    groupFilterOverride: groupFilterOverride,
    tagFilterOverride: tagFilterOverride,
    categoryFilterOverride: categoryFilterOverride,
    statusFilterOverride: statusFilterOverride,
  );
  final summary = <String, int>{};
  for (final evaluation in evaluations) {
    final policyMatchType = evaluation['policyMatchType']?.toString().trim();
    final policyMatchValue = evaluation['policyMatchValue']?.toString().trim();
    if (policyMatchType == null ||
        policyMatchType.isEmpty ||
        policyMatchValue == null ||
        policyMatchValue.isEmpty) {
      continue;
    }
    final key = '$policyMatchType:$policyMatchValue';
    summary.update(key, (count) => count + 1, ifAbsent: () => 1);
  }
  return summary;
}

Map<String, int> _buildHistoryAlertPolicyTypeSummary({
  required dynamic historyAlerts,
  required _AlertFailurePolicy? policy,
  required String? thresholdOverride,
  required String? groupFilterOverride,
  required String? tagFilterOverride,
  required String? categoryFilterOverride,
  required String? statusFilterOverride,
}) {
  final evaluations = _buildHistoryAlertPolicyEvaluations(
    historyAlerts: historyAlerts,
    policy: policy,
    thresholdOverride: thresholdOverride,
    groupFilterOverride: groupFilterOverride,
    tagFilterOverride: tagFilterOverride,
    categoryFilterOverride: categoryFilterOverride,
    statusFilterOverride: statusFilterOverride,
  );
  final summary = <String, int>{};
  for (final evaluation in evaluations) {
    final policyMatchType = evaluation['policyMatchType']?.toString().trim();
    if (policyMatchType == null || policyMatchType.isEmpty) {
      continue;
    }
    summary.update(policyMatchType, (count) => count + 1, ifAbsent: () => 1);
  }
  return summary;
}

Map<String, int> _buildHistoryAlertPolicySuppressionSummary({
  required dynamic historyAlerts,
  required _AlertFailurePolicy? policy,
  required String? thresholdOverride,
  required String? groupFilterOverride,
  required String? tagFilterOverride,
  required String? categoryFilterOverride,
  required String? statusFilterOverride,
}) {
  final evaluations = _buildHistoryAlertPolicyEvaluations(
    historyAlerts: historyAlerts,
    policy: policy,
    thresholdOverride: thresholdOverride,
    groupFilterOverride: groupFilterOverride,
    tagFilterOverride: tagFilterOverride,
    categoryFilterOverride: categoryFilterOverride,
    statusFilterOverride: statusFilterOverride,
  );
  final summary = <String, int>{};
  for (final evaluation in evaluations) {
    final suppressed = evaluation['suppressed'] == true;
    final key = suppressed ? 'suppressed' : 'included';
    summary.update(key, (count) => count + 1, ifAbsent: () => 1);
  }
  return summary;
}

Map<String, int> _buildHistoryAlertPolicySourceSummary({
  required dynamic historyAlerts,
  required _AlertFailurePolicy? policy,
  required String? thresholdOverride,
  required String? groupFilterOverride,
  required String? tagFilterOverride,
  required String? categoryFilterOverride,
  required String? statusFilterOverride,
}) {
  final evaluations = _buildHistoryAlertPolicyEvaluations(
    historyAlerts: historyAlerts,
    policy: policy,
    thresholdOverride: thresholdOverride,
    groupFilterOverride: groupFilterOverride,
    tagFilterOverride: tagFilterOverride,
    categoryFilterOverride: categoryFilterOverride,
    statusFilterOverride: statusFilterOverride,
  );
  final summary = <String, int>{};
  for (final evaluation in evaluations) {
    final policyMatchSource = evaluation['policyMatchSource']
        ?.toString()
        .trim();
    if (policyMatchSource == null || policyMatchSource.isEmpty) {
      continue;
    }
    summary.update(policyMatchSource, (count) => count + 1, ifAbsent: () => 1);
  }
  return summary;
}

Map<String, int> _buildAlertFailurePolicyTypeSummary({
  required dynamic historyAlerts,
  required _AlertFailurePolicy? policy,
  required String? thresholdOverride,
  required String? groupFilterOverride,
  required String? tagFilterOverride,
  required String? categoryFilterOverride,
  required String? statusFilterOverride,
}) {
  final evaluations = _buildIncludedAlertFailurePolicyEvaluations(
    historyAlerts: historyAlerts,
    policy: policy,
    thresholdOverride: thresholdOverride,
    groupFilterOverride: groupFilterOverride,
    tagFilterOverride: tagFilterOverride,
    categoryFilterOverride: categoryFilterOverride,
    statusFilterOverride: statusFilterOverride,
  );
  final summary = <String, int>{};
  for (final evaluation in evaluations) {
    final policyMatchType = evaluation['policyMatchType']?.toString().trim();
    if (policyMatchType == null || policyMatchType.isEmpty) {
      continue;
    }
    summary.update(policyMatchType, (count) => count + 1, ifAbsent: () => 1);
  }
  return summary;
}

Map<String, int> _buildAlertFailurePolicySummary({
  required dynamic historyAlerts,
  required _AlertFailurePolicy? policy,
  required String? thresholdOverride,
  required String? groupFilterOverride,
  required String? tagFilterOverride,
  required String? categoryFilterOverride,
  required String? statusFilterOverride,
}) {
  final evaluations = _buildIncludedAlertFailurePolicyEvaluations(
    historyAlerts: historyAlerts,
    policy: policy,
    thresholdOverride: thresholdOverride,
    groupFilterOverride: groupFilterOverride,
    tagFilterOverride: tagFilterOverride,
    categoryFilterOverride: categoryFilterOverride,
    statusFilterOverride: statusFilterOverride,
  );
  final summary = <String, int>{};
  for (final evaluation in evaluations) {
    final policyMatchType = evaluation['policyMatchType']?.toString().trim();
    final policyMatchValue = evaluation['policyMatchValue']?.toString().trim();
    if (policyMatchType == null ||
        policyMatchType.isEmpty ||
        policyMatchValue == null ||
        policyMatchValue.isEmpty) {
      continue;
    }
    final key = '$policyMatchType:$policyMatchValue';
    summary.update(key, (count) => count + 1, ifAbsent: () => 1);
  }
  return summary;
}

Map<String, int> _buildAlertFailurePolicySourceSummary({
  required dynamic historyAlerts,
  required _AlertFailurePolicy? policy,
  required String? thresholdOverride,
  required String? groupFilterOverride,
  required String? tagFilterOverride,
  required String? categoryFilterOverride,
  required String? statusFilterOverride,
}) {
  final evaluations = _buildIncludedAlertFailurePolicyEvaluations(
    historyAlerts: historyAlerts,
    policy: policy,
    thresholdOverride: thresholdOverride,
    groupFilterOverride: groupFilterOverride,
    tagFilterOverride: tagFilterOverride,
    categoryFilterOverride: categoryFilterOverride,
    statusFilterOverride: statusFilterOverride,
  );
  final summary = <String, int>{};
  for (final evaluation in evaluations) {
    final policyMatchSource = evaluation['policyMatchSource']
        ?.toString()
        .trim();
    if (policyMatchSource == null || policyMatchSource.isEmpty) {
      continue;
    }
    summary.update(policyMatchSource, (count) => count + 1, ifAbsent: () => 1);
  }
  return summary;
}

List<Map<String, dynamic>> _buildPolicyPromotedSpecialistEvaluations({
  required dynamic historyAlerts,
  required _AlertFailurePolicy? policy,
  required String? thresholdOverride,
  required String? groupFilterOverride,
  required String? tagFilterOverride,
  required String? categoryFilterOverride,
  required String? statusFilterOverride,
}) {
  return _buildIncludedAlertFailurePolicyEvaluations(
    historyAlerts: historyAlerts,
    policy: policy,
    thresholdOverride: thresholdOverride,
    groupFilterOverride: groupFilterOverride,
    tagFilterOverride: tagFilterOverride,
    categoryFilterOverride: categoryFilterOverride,
    statusFilterOverride: statusFilterOverride,
  ).where(_isPolicyPromotedSpecialistEvaluation).toList(growable: false);
}

List<Map<String, dynamic>> _enrichHistoryAlertsWithSeverityContext(
  dynamic historyAlerts, {
  required _AlertFailurePolicy? policy,
}) {
  if (historyAlerts is! List) {
    return const <Map<String, dynamic>>[];
  }
  return historyAlerts
      .whereType<Map<String, dynamic>>()
      .map((alert) {
        final copy = Map<String, dynamic>.from(alert);
        final scenarioSet = alert['scenarioSet']?.toString();
        final category = alert['category']?.toString().trim().toLowerCase();
        final scenarioId = alert['scenarioId']?.toString();
        final resolvedRule = policy?.resolveForScenario(
          scenarioSet: scenarioSet,
          category: category,
          scenarioId: scenarioId,
        );
        final effectiveSeverity = _resolveEffectiveAlertSeverity(
          alert,
          resolvedRule: resolvedRule,
          group: null,
        );
        copy.addAll(
          _buildAlertSeverityContextFields(
            alert,
            effectiveSeverity: effectiveSeverity,
          ),
        );
        if (policy != null) {
          final scopeSeverityOverride = _buildRuleSeverityOverridePolicyMatch(
            alert: alert,
            policy: policy,
            resolvedRule: resolvedRule,
            scenarioSet: scenarioSet,
            category: category,
            scenarioId: scenarioId,
          );
          if (scopeSeverityOverride != null) {
            copy['effectiveSeverityPolicyMatchType'] =
                scopeSeverityOverride['policyMatchType'];
            copy['effectiveSeverityPolicyValue'] =
                scopeSeverityOverride['policyMatchValue'];
            copy['effectiveSeverityPolicySource'] =
                scopeSeverityOverride['policyMatchSource'];
          }
        }
        return copy;
      })
      .toList(growable: false);
}

bool _isPolicyPromotedSpecialistEvaluation(Map<String, dynamic> evaluation) {
  if (!_isPolicyPromotedScopeSeverityEvaluation(evaluation)) {
    return false;
  }
  final scope = _readNormalizedAlertScope(evaluation);
  switch (scope) {
    case 'specialist_constraint':
    case 'specialist_conflict':
    case 'specialist_degradation':
      return true;
  }
  return false;
}

bool _isPolicyPromotedReplayRiskEvaluation(Map<String, dynamic> evaluation) {
  if (!_isPolicyPromotedScopeSeverityEvaluation(evaluation)) {
    return false;
  }
  return !_isPolicyPromotedSpecialistEvaluation(evaluation);
}

bool _isPolicyPromotedScopeSeverityEvaluation(Map<String, dynamic> evaluation) {
  if (evaluation['suppressed'] == true) {
    return false;
  }
  if (evaluation['policyMatchType']?.toString().trim() !=
      'scope_severity_override') {
    return false;
  }
  final originalSeverity = evaluation['originalSeverity']
      ?.toString()
      .trim()
      .toLowerCase();
  final promotedSeverity = evaluation['severity']
      ?.toString()
      .trim()
      .toLowerCase();
  return originalSeverity != null &&
      originalSeverity.isNotEmpty &&
      promotedSeverity != null &&
      promotedSeverity.isNotEmpty &&
      originalSeverity != promotedSeverity;
}

List<Map<String, dynamic>> _buildPolicyPromotedReplayRiskEvaluations({
  required dynamic historyAlerts,
  required _AlertFailurePolicy? policy,
  required String? thresholdOverride,
  required String? groupFilterOverride,
  required String? tagFilterOverride,
  required String? categoryFilterOverride,
  required String? statusFilterOverride,
}) {
  return _buildIncludedAlertFailurePolicyEvaluations(
    historyAlerts: historyAlerts,
    policy: policy,
    thresholdOverride: thresholdOverride,
    groupFilterOverride: groupFilterOverride,
    tagFilterOverride: tagFilterOverride,
    categoryFilterOverride: categoryFilterOverride,
    statusFilterOverride: statusFilterOverride,
  ).where(_isPolicyPromotedReplayRiskEvaluation).toList(growable: false);
}

Map<String, int> _buildPolicyPromotedSpecialistSummary(
  List<Map<String, dynamic>> evaluations,
) {
  return _buildPolicyPromotedAlertSummary(evaluations);
}

Map<String, int> _buildPolicyPromotedReplayRiskSummary(
  List<Map<String, dynamic>> evaluations,
) {
  return _buildPolicyPromotedAlertSummary(evaluations);
}

Map<String, int> _buildPolicyPromotedAlertSummary(
  List<Map<String, dynamic>> evaluations,
) {
  final summary = <String, int>{};
  for (final evaluation in evaluations) {
    final scope = _readNormalizedAlertScope(evaluation);
    final originalSeverity = evaluation['originalSeverity']
        ?.toString()
        .trim()
        .toLowerCase();
    final promotedSeverity = evaluation['severity']
        ?.toString()
        .trim()
        .toLowerCase();
    if (scope == null ||
        originalSeverity == null ||
        originalSeverity.isEmpty ||
        promotedSeverity == null ||
        promotedSeverity.isEmpty ||
        originalSeverity == promotedSeverity) {
      continue;
    }
    final key = '$scope:$originalSeverity->$promotedSeverity';
    summary.update(key, (count) => count + 1, ifAbsent: () => 1);
  }
  return summary;
}

Map<String, int> _buildPolicyPromotedSpecialistSourceSummary(
  List<Map<String, dynamic>> evaluations,
) {
  return _buildPolicyPromotedAlertSourceSummary(evaluations);
}

Map<String, int> _buildPolicyPromotedReplayRiskSourceSummary(
  List<Map<String, dynamic>> evaluations,
) {
  return _buildPolicyPromotedAlertSourceSummary(evaluations);
}

Map<String, int> _buildPolicyPromotedAlertSourceSummary(
  List<Map<String, dynamic>> evaluations,
) {
  final summary = <String, int>{};
  for (final evaluation in evaluations) {
    final source = evaluation['policyMatchSource']?.toString().trim();
    if (source == null || source.isEmpty) {
      continue;
    }
    summary.update(source, (count) => count + 1, ifAbsent: () => 1);
  }
  return summary;
}

Map<String, dynamic>? _buildPolicyPromotedSpecialistFocus(
  List<Map<String, dynamic>> evaluations,
) {
  return _buildPolicyPromotedAlertFocus(evaluations);
}

Map<String, dynamic>? _buildPolicyPromotedReplayRiskFocus(
  List<Map<String, dynamic>> evaluations,
) {
  return _buildPolicyPromotedAlertFocus(evaluations);
}

Map<String, dynamic>? _buildPolicyPromotedAlertFocus(
  List<Map<String, dynamic>> evaluations,
) {
  if (evaluations.isEmpty) {
    return null;
  }
  final focus = _buildAlertFailureFocus(evaluations);
  if (focus == null) {
    return null;
  }
  return Map<String, dynamic>.from(focus);
}

Map<String, dynamic>? _buildHistoryPolicyPromotedSpecialistFocusEntry({
  required Map<String, dynamic> focus,
  required dynamic historyScenarioSummary,
}) {
  return _buildHistoryPolicyPromotedAlertFocusEntry(
    focus: focus,
    historyScenarioSummary: historyScenarioSummary,
  );
}

Map<String, dynamic>? _buildHistoryPolicyPromotedReplayRiskFocusEntry({
  required Map<String, dynamic> focus,
  required dynamic historyScenarioSummary,
}) {
  return _buildHistoryPolicyPromotedAlertFocusEntry(
    focus: focus,
    historyScenarioSummary: historyScenarioSummary,
  );
}

Map<String, dynamic>? _buildHistoryPolicyPromotedAlertFocusEntry({
  required Map<String, dynamic> focus,
  required dynamic historyScenarioSummary,
}) {
  final scenarioId = focus['scenarioId']?.toString().trim();
  if (scenarioId == null || scenarioId.isEmpty) {
    return null;
  }
  final summaryMap = _stringKeyedMapOrNull(historyScenarioSummary);
  final scenarioSummary = summaryMap?[scenarioId];
  return <String, dynamic>{
    'scenarioId': scenarioId,
    if (focus['scope'] != null) 'scope': focus['scope'],
    if (focus['trend'] != null) 'trend': focus['trend'],
    if (focus['count'] != null) 'count': focus['count'],
    if (scenarioSummary is Map && scenarioSummary['lastRunAt'] != null)
      'lastRunAt': scenarioSummary['lastRunAt'],
    if (focus['originalSeverity'] != null)
      'originalSeverity': focus['originalSeverity'],
    if (focus['severity'] != null) 'promotedSeverity': focus['severity'],
    if (focus['policyMatchSource'] != null)
      'policyMatchSource': focus['policyMatchSource'],
    if (focus['policyMatchValue'] != null)
      'policyMatchValue': focus['policyMatchValue'],
  };
}

List<Map<String, dynamic>> _buildIncludedAlertFailurePolicyEvaluations({
  required dynamic historyAlerts,
  required _AlertFailurePolicy? policy,
  required String? thresholdOverride,
  required String? groupFilterOverride,
  required String? tagFilterOverride,
  required String? categoryFilterOverride,
  required String? statusFilterOverride,
}) {
  return _buildHistoryAlertPolicyEvaluations(
        historyAlerts: historyAlerts,
        policy: policy,
        thresholdOverride: thresholdOverride,
        groupFilterOverride: groupFilterOverride,
        tagFilterOverride: tagFilterOverride,
        categoryFilterOverride: categoryFilterOverride,
        statusFilterOverride: statusFilterOverride,
      )
      .where((evaluation) => evaluation['suppressed'] != true)
      .toList(growable: false);
}

List<Map<String, dynamic>> _buildHistoryAlertPolicyEvaluations({
  required dynamic historyAlerts,
  required _AlertFailurePolicy? policy,
  required String? thresholdOverride,
  required String? groupFilterOverride,
  required String? tagFilterOverride,
  required String? categoryFilterOverride,
  required String? statusFilterOverride,
}) {
  if (policy == null || historyAlerts is! List) {
    return const <Map<String, dynamic>>[];
  }
  if ((groupFilterOverride?.trim().isNotEmpty ?? false) ||
      (tagFilterOverride?.trim().isNotEmpty ?? false) ||
      (categoryFilterOverride?.trim().isNotEmpty ?? false) ||
      (statusFilterOverride?.trim().isNotEmpty ?? false)) {
    return const <Map<String, dynamic>>[];
  }

  final evaluations = <Map<String, dynamic>>[];
  for (final alert in historyAlerts.whereType<Map<String, dynamic>>()) {
    final scenarioSet = alert['scenarioSet']?.toString();
    final alertCategory = alert['category']?.toString().trim().toLowerCase();
    final alertScenarioId = alert['scenarioId']?.toString();
    final alertStatus = alert['status']?.toString().trim().toLowerCase();
    final resolvedRule = policy.resolveForScenario(
      scenarioSet: scenarioSet,
      category: alertCategory,
      scenarioId: alertScenarioId,
    );
    final scopeSeverityOverride = _buildRuleSeverityOverridePolicyMatch(
      alert: alert,
      policy: policy,
      resolvedRule: resolvedRule,
      scenarioSet: scenarioSet,
      category: alertCategory,
      scenarioId: alertScenarioId,
    );
    final threshold = thresholdOverride ?? resolvedRule.threshold;
    if (threshold == null || threshold.isEmpty) {
      continue;
    }
    final severity = _resolveEffectiveAlertSeverity(
      alert,
      resolvedRule: resolvedRule,
      group: null,
    );
    if (_alertSeverityRank(severity) < _alertSeverityRank(threshold)) {
      continue;
    }

    late final String policyMatchType;
    late final String policyMatchValue;
    late final String policyMatchSource;
    late final bool suppressed;

    if (alertCategory != null &&
        alertCategory.isNotEmpty &&
        resolvedRule.excludeCategories.contains(alertCategory)) {
      policyMatchType = 'category_denylist';
      policyMatchValue = alertCategory;
      policyMatchSource =
          policy.resolveFieldSource(
            scenarioSet: scenarioSet,
            category: alertCategory,
            scenarioId: alertScenarioId,
            fieldKey: 'excludeCategories',
          ) ??
          'unresolved';
      suppressed = true;
    } else if (alertStatus != null &&
        alertStatus.isNotEmpty &&
        resolvedRule.excludeStatuses.contains(alertStatus)) {
      policyMatchType = 'status_denylist';
      policyMatchValue = alertStatus;
      policyMatchSource =
          policy.resolveFieldSource(
            scenarioSet: scenarioSet,
            category: alertCategory,
            scenarioId: alertScenarioId,
            fieldKey: 'excludeStatuses',
          ) ??
          'unresolved';
      suppressed = true;
    } else if (scopeSeverityOverride != null) {
      policyMatchType = scopeSeverityOverride['policyMatchType']!.toString();
      policyMatchValue = scopeSeverityOverride['policyMatchValue']!.toString();
      policyMatchSource = scopeSeverityOverride['policyMatchSource']!
          .toString();
      suppressed = false;
    } else if (resolvedRule.includeCategories.isNotEmpty) {
      policyMatchType = 'category_allowlist';
      policyMatchSource =
          policy.resolveFieldSource(
            scenarioSet: scenarioSet,
            category: alertCategory,
            scenarioId: alertScenarioId,
            fieldKey: 'includeCategories',
          ) ??
          'unresolved';
      if (alertCategory != null &&
          alertCategory.isNotEmpty &&
          resolvedRule.includeCategories.contains(alertCategory)) {
        policyMatchValue = alertCategory;
        suppressed = false;
      } else {
        policyMatchValue = resolvedRule.includeCategories.join(',');
        suppressed = true;
      }
    } else if (resolvedRule.includeStatuses.isNotEmpty) {
      policyMatchType = 'status_allowlist';
      policyMatchSource =
          policy.resolveFieldSource(
            scenarioSet: scenarioSet,
            category: alertCategory,
            scenarioId: alertScenarioId,
            fieldKey: 'includeStatuses',
          ) ??
          'unresolved';
      if (alertStatus != null &&
          alertStatus.isNotEmpty &&
          resolvedRule.includeStatuses.contains(alertStatus)) {
        policyMatchValue = alertStatus;
        suppressed = false;
      } else {
        policyMatchValue = resolvedRule.includeStatuses.join(',');
        suppressed = true;
      }
    } else {
      policyMatchType =
          thresholdOverride != null && thresholdOverride.trim().isNotEmpty
          ? 'threshold_override'
          : 'threshold';
      policyMatchValue = threshold;
      policyMatchSource =
          thresholdOverride != null && thresholdOverride.trim().isNotEmpty
          ? 'threshold_override'
          : (policy.resolveFieldSource(
                  scenarioSet: scenarioSet,
                  category: alertCategory,
                  scenarioId: alertScenarioId,
                  fieldKey: 'threshold',
                ) ??
                'unresolved');
      suppressed = false;
    }

    evaluations.add(<String, dynamic>{
      ..._copyAlertWithSeverityOverrides(
        alert,
        resolvedRule: resolvedRule,
        group: null,
      ),
      'policyMatchType': policyMatchType,
      'policyMatchValue': policyMatchValue,
      'policyMatchSource': policyMatchSource,
      'suppressed': suppressed,
    });
  }
  return evaluations;
}

Map<String, dynamic>? _buildAlertFailureFocus(
  List<Map<String, dynamic>> alerts,
) {
  for (final alert in alerts) {
    if (alert['scope']?.toString() == 'command_brain_replay_bias_stack') {
      return Map<String, dynamic>.from(alert);
    }
  }
  for (final alert in alerts) {
    if (alert['scope']?.toString() == 'command_brain_timeline') {
      return Map<String, dynamic>.from(alert);
    }
  }
  for (final alert in alerts) {
    if (alert['scope']?.toString() == 'specialist_constraint') {
      return Map<String, dynamic>.from(alert);
    }
  }
  for (final alert in alerts) {
    if (alert['scope']?.toString() == 'specialist_conflict') {
      return Map<String, dynamic>.from(alert);
    }
  }
  for (final alert in alerts) {
    if (alert['scope']?.toString() == 'sequence_fallback') {
      return Map<String, dynamic>.from(alert);
    }
  }
  for (final alert in alerts) {
    if (alert['scope']?.toString() == 'specialist_degradation') {
      return Map<String, dynamic>.from(alert);
    }
  }
  for (final alert in alerts) {
    if (alert['scope']?.toString() == 'scenario_field') {
      return Map<String, dynamic>.from(alert);
    }
  }
  if (alerts.isEmpty) {
    return null;
  }
  return Map<String, dynamic>.from(alerts.first);
}

Map<String, dynamic>? _buildAlertFailureGroupFocus({
  required String? group,
  required List<Map<String, dynamic>> alerts,
}) {
  final normalizedGroup = group?.trim().toLowerCase();
  if (normalizedGroup == null || normalizedGroup.isEmpty) {
    return null;
  }
  final focus = _buildAlertFailureFocus(alerts);
  if (focus == null) {
    return null;
  }
  return <String, dynamic>{'group': normalizedGroup, ...focus};
}

Map<String, dynamic>? _buildAlertFailureTagFocus({
  required String? tag,
  required List<Map<String, dynamic>> alerts,
}) {
  final normalizedTag = tag?.trim().toLowerCase();
  if (normalizedTag == null || normalizedTag.isEmpty) {
    return null;
  }
  final focus = _buildAlertFailureFocus(alerts);
  if (focus == null) {
    return null;
  }
  return <String, dynamic>{'tag': normalizedTag, ...focus};
}

Map<String, dynamic>? _buildAlertFailureCategoryFocus({
  required String? category,
  required List<Map<String, dynamic>> alerts,
}) {
  final normalizedCategory = category?.trim().toLowerCase();
  if (normalizedCategory == null || normalizedCategory.isEmpty) {
    return null;
  }
  final focus = _buildAlertFailureFocus(alerts);
  if (focus == null) {
    return null;
  }
  return <String, dynamic>{'category': normalizedCategory, ...focus};
}

Map<String, dynamic>? _buildAlertFailureStatusFocus({
  required String? status,
  required List<Map<String, dynamic>> alerts,
}) {
  final normalizedStatus = status?.trim().toLowerCase();
  if (normalizedStatus == null || normalizedStatus.isEmpty) {
    return null;
  }
  final focus = _buildAlertFailureFocus(alerts);
  if (focus == null) {
    return null;
  }
  return <String, dynamic>{'status': normalizedStatus, ...focus};
}

Map<String, dynamic>? _buildAlertFailurePolicyFocus({
  required dynamic historyAlerts,
  required List<Map<String, dynamic>> alerts,
  required _AlertFailurePolicy? policy,
  required String? thresholdOverride,
  required String? groupFilterOverride,
  required String? tagFilterOverride,
  required String? categoryFilterOverride,
  required String? statusFilterOverride,
}) {
  if (policy == null) {
    return null;
  }
  if ((groupFilterOverride?.trim().isNotEmpty ?? false) ||
      (tagFilterOverride?.trim().isNotEmpty ?? false) ||
      (categoryFilterOverride?.trim().isNotEmpty ?? false) ||
      (statusFilterOverride?.trim().isNotEmpty ?? false)) {
    return null;
  }
  final includedFocus = _buildIncludedAlertFailurePolicyFocus(
    alerts: alerts,
    policy: policy,
  );
  if (includedFocus != null) {
    return includedFocus;
  }
  return _buildSuppressedAlertFailurePolicyFocus(
    historyAlerts: historyAlerts,
    policy: policy,
    thresholdOverride: thresholdOverride,
  );
}

Map<String, dynamic>? _buildIncludedAlertFailurePolicyFocus({
  required List<Map<String, dynamic>> alerts,
  required _AlertFailurePolicy policy,
}) {
  final focus = _buildAlertFailureFocus(alerts);
  if (focus == null) {
    return null;
  }
  final resolvedRule = policy.resolveForScenario(
    scenarioSet: focus['scenarioSet']?.toString(),
    category: focus['category']?.toString(),
    scenarioId: focus['scenarioId']?.toString(),
  );
  final scopeSeverityOverride = _buildRuleSeverityOverridePolicyMatch(
    alert: focus,
    policy: policy,
    resolvedRule: resolvedRule,
    scenarioSet: focus['scenarioSet']?.toString(),
    category: focus['category']?.toString(),
    scenarioId: focus['scenarioId']?.toString(),
  );
  if (scopeSeverityOverride != null) {
    return <String, dynamic>{
      'policyMatchType': 'scope_severity_override',
      'policyMatchValue': scopeSeverityOverride['policyMatchValue']!.toString(),
      'policyMatchSource': scopeSeverityOverride['policyMatchSource']!
          .toString(),
      'suppressed': false,
      ...focus,
    };
  }
  final category = focus['category']?.toString().trim().toLowerCase();
  if (category != null &&
      category.isNotEmpty &&
      resolvedRule.includeCategories.contains(category)) {
    return <String, dynamic>{
      'policyMatchType': 'category_allowlist',
      'policyMatchValue': category,
      'policyMatchSource':
          policy.resolveFieldSource(
            scenarioSet: focus['scenarioSet']?.toString(),
            category: category,
            scenarioId: focus['scenarioId']?.toString(),
            fieldKey: 'includeCategories',
          ) ??
          'unresolved',
      'suppressed': false,
      ...focus,
    };
  }
  final status = focus['status']?.toString().trim().toLowerCase();
  if (status != null &&
      status.isNotEmpty &&
      resolvedRule.includeStatuses.contains(status)) {
    return <String, dynamic>{
      'policyMatchType': 'status_allowlist',
      'policyMatchValue': status,
      'policyMatchSource':
          policy.resolveFieldSource(
            scenarioSet: focus['scenarioSet']?.toString(),
            category: focus['category']?.toString(),
            scenarioId: focus['scenarioId']?.toString(),
            fieldKey: 'includeStatuses',
          ) ??
          'unresolved',
      'suppressed': false,
      ...focus,
    };
  }
  return null;
}

Map<String, dynamic>? _buildSuppressedAlertFailurePolicyFocus({
  required dynamic historyAlerts,
  required _AlertFailurePolicy policy,
  required String? thresholdOverride,
}) {
  if (historyAlerts is! List) {
    return null;
  }
  final suppressedAlerts = <Map<String, dynamic>>[];
  for (final alert in historyAlerts.whereType<Map<String, dynamic>>()) {
    final scenarioSet = alert['scenarioSet']?.toString();
    final category = alert['category']?.toString().trim().toLowerCase();
    final scenarioId = alert['scenarioId']?.toString();
    final status = alert['status']?.toString().trim().toLowerCase();
    final resolvedRule = policy.resolveForScenario(
      scenarioSet: scenarioSet,
      category: category,
      scenarioId: scenarioId,
    );
    final effectiveSeverity = _resolveEffectiveAlertSeverity(
      alert,
      resolvedRule: resolvedRule,
      group: null,
    );
    final threshold = thresholdOverride ?? resolvedRule.threshold;
    if (threshold == null || threshold.isEmpty) {
      continue;
    }
    if (_alertSeverityRank(effectiveSeverity) < _alertSeverityRank(threshold)) {
      continue;
    }

    String? policyMatchType;
    String? policyMatchValue;
    String? policyMatchSource;
    if (category != null &&
        category.isNotEmpty &&
        resolvedRule.excludeCategories.contains(category)) {
      policyMatchType = 'category_denylist';
      policyMatchValue = category;
      policyMatchSource = policy.resolveFieldSource(
        scenarioSet: scenarioSet,
        category: category,
        scenarioId: scenarioId,
        fieldKey: 'excludeCategories',
      );
    } else if (status != null &&
        status.isNotEmpty &&
        resolvedRule.excludeStatuses.contains(status)) {
      policyMatchType = 'status_denylist';
      policyMatchValue = status;
      policyMatchSource = policy.resolveFieldSource(
        scenarioSet: scenarioSet,
        category: category,
        scenarioId: scenarioId,
        fieldKey: 'excludeStatuses',
      );
    } else if (resolvedRule.includeCategories.isNotEmpty &&
        (category == null ||
            !resolvedRule.includeCategories.contains(category))) {
      policyMatchType = 'category_allowlist';
      policyMatchValue = resolvedRule.includeCategories.join(',');
      policyMatchSource = policy.resolveFieldSource(
        scenarioSet: scenarioSet,
        category: category,
        scenarioId: scenarioId,
        fieldKey: 'includeCategories',
      );
    } else if (resolvedRule.includeStatuses.isNotEmpty &&
        (status == null || !resolvedRule.includeStatuses.contains(status))) {
      policyMatchType = 'status_allowlist';
      policyMatchValue = resolvedRule.includeStatuses.join(',');
      policyMatchSource = policy.resolveFieldSource(
        scenarioSet: scenarioSet,
        category: category,
        scenarioId: scenarioId,
        fieldKey: 'includeStatuses',
      );
    } else {
      continue;
    }

    suppressedAlerts.add(<String, dynamic>{
      ...alert,
      'policyMatchType': policyMatchType,
      'policyMatchValue': policyMatchValue,
      'policyMatchSource': policyMatchSource ?? 'unresolved',
      'suppressed': true,
    });
  }
  if (suppressedAlerts.isEmpty) {
    return null;
  }
  final focus = _buildAlertFailureFocus(suppressedAlerts);
  if (focus == null) {
    return null;
  }
  return focus;
}

List<Map<String, dynamic>> _buildHistoryAlerts({
  required Map<String, Map<String, dynamic>> historyScenarioSummary,
  required Map<String, Map<String, dynamic>>
  historyScenarioSpecialistConflictSummary,
  required Map<String, Map<String, dynamic>>
  historyScenarioSpecialistConstraintSummary,
  required Map<String, Map<String, dynamic>>
  historyScenarioSpecialistDegradationSummary,
  required Map<String, Map<String, dynamic>>
  historyScenarioSequenceFallbackSummary,
  required Map<String, Map<String, Map<String, dynamic>>>
  historyScenarioMismatchFieldTrendSummary,
  required Map<String, Map<String, dynamic>> scenarioMetadataByScenarioId,
  required Map<String, Map<String, dynamic>> latestHistoryRecordByScenarioId,
}) {
  final alerts = <Map<String, dynamic>>[];

  for (final entry in historyScenarioSummary.entries) {
    final scenarioId = entry.key;
    final summary = entry.value;
    final metadata = scenarioMetadataByScenarioId[scenarioId];
    if (metadata == null) {
      continue;
    }
    final trend = summary['trend']?.toString() ?? 'unknown';
    if (!_shouldAlertOnTrend(trend)) {
      continue;
    }
    alerts.add(<String, dynamic>{
      'severity': _buildAlertSeverity(
        scenarioSet: metadata['scenarioSet'] ?? '',
        status: metadata['status'] ?? '',
        trend: trend,
      ),
      'scope': 'scenario',
      'scenarioId': scenarioId,
      'category': metadata['category'],
      'scenarioSet': metadata['scenarioSet'],
      'status': metadata['status'],
      'tags': metadata['tags'],
      'trend': trend,
      'count': summary['failedCount'],
      'message': _buildScenarioAlertMessage(trend),
    });
  }

  for (final entry in historyScenarioSpecialistConstraintSummary.entries) {
    final scenarioId = entry.key;
    final summary = entry.value;
    final metadata = scenarioMetadataByScenarioId[scenarioId];
    if (metadata == null) {
      continue;
    }
    final trend = summary['trend']?.toString() ?? 'unknown';
    final latestBranch = summary['latestBranch']?.toString() ?? 'clean';
    if (latestBranch != 'blocking' || !_shouldAlertOnTrend(trend)) {
      continue;
    }
    alerts.add(<String, dynamic>{
      'severity': _buildAlertSeverity(
        scenarioSet: metadata['scenarioSet'] ?? '',
        status: metadata['status'] ?? '',
        trend: trend,
      ),
      'scope': 'specialist_constraint',
      'scenarioId': scenarioId,
      'category': metadata['category'],
      'scenarioSet': metadata['scenarioSet'],
      'status': metadata['status'],
      'tags': metadata['tags'],
      'field': 'specialistConstraintBranch',
      'trend': trend,
      'count': summary['blockingCount'],
      'latestBranch': latestBranch,
      if (summary['latestSignature'] != null)
        'latestSpecialistConstraintSignature': summary['latestSignature'],
      if (summary['latestSpecialist'] != null)
        'latestSpecialist': summary['latestSpecialist'],
      if (summary['latestTarget'] != null)
        'latestTarget': summary['latestTarget'],
      if (summary['latestAllowRouteExecution'] != null)
        'latestAllowRouteExecution': summary['latestAllowRouteExecution'],
      'message': _buildSpecialistConstraintAlertMessage(
        trend: trend,
        signature: summary['latestSignature']?.toString(),
      ),
    });
  }

  for (final entry in historyScenarioSpecialistConflictSummary.entries) {
    final scenarioId = entry.key;
    final summary = entry.value;
    final metadata = scenarioMetadataByScenarioId[scenarioId];
    if (metadata == null) {
      continue;
    }
    final trend = summary['trend']?.toString() ?? 'unknown';
    final latestBranch = summary['latestBranch']?.toString() ?? 'clean';
    if (latestBranch != 'persistent' || !_shouldAlertOnTrend(trend)) {
      continue;
    }
    alerts.add(<String, dynamic>{
      'severity': _buildAlertSeverity(
        scenarioSet: metadata['scenarioSet'] ?? '',
        status: metadata['status'] ?? '',
        trend: trend,
      ),
      'scope': 'specialist_conflict',
      'scenarioId': scenarioId,
      'category': metadata['category'],
      'scenarioSet': metadata['scenarioSet'],
      'status': metadata['status'],
      'tags': metadata['tags'],
      'field': 'specialistConflictBranch',
      'trend': trend,
      'count': summary['persistentCount'],
      'latestBranch': latestBranch,
      if (summary['latestSignature'] != null)
        'latestSpecialistConflictSignature': summary['latestSignature'],
      if (summary['latestSummary'] != null)
        'latestSummary': summary['latestSummary'],
      if (summary['latestSpecialists'] != null)
        'latestSpecialists': summary['latestSpecialists'],
      if (summary['latestTargets'] != null)
        'latestTargets': summary['latestTargets'],
      'message': _buildSpecialistConflictAlertMessage(
        trend: trend,
        signature: summary['latestSignature']?.toString(),
      ),
    });
  }

  for (final entry in historyScenarioSpecialistDegradationSummary.entries) {
    final scenarioId = entry.key;
    final summary = entry.value;
    final metadata = scenarioMetadataByScenarioId[scenarioId];
    if (metadata == null) {
      continue;
    }
    final trend = summary['trend']?.toString() ?? 'unknown';
    final latestBranch = summary['latestBranch']?.toString() ?? 'clean';
    if (latestBranch != 'persistent' || !_shouldAlertOnTrend(trend)) {
      continue;
    }
    alerts.add(<String, dynamic>{
      'severity': _buildAlertSeverity(
        scenarioSet: metadata['scenarioSet'] ?? '',
        status: metadata['status'] ?? '',
        trend: trend,
      ),
      'scope': 'specialist_degradation',
      'scenarioId': scenarioId,
      'category': metadata['category'],
      'scenarioSet': metadata['scenarioSet'],
      'status': metadata['status'],
      'tags': metadata['tags'],
      'field': 'specialistDegradationBranch',
      'trend': trend,
      'count': summary['persistentCount'],
      'latestBranch': latestBranch,
      if (summary['latestSignature'] != null)
        'latestSpecialistDegradationSignature': summary['latestSignature'],
      if (summary['latestSpecialists'] != null)
        'latestSpecialists': summary['latestSpecialists'],
      if (summary['latestStatuses'] != null)
        'latestStatuses': summary['latestStatuses'],
      'message': _buildSpecialistDegradationAlertMessage(
        trend: trend,
        signature: summary['latestSignature']?.toString(),
      ),
    });
  }

  for (final entry in historyScenarioSequenceFallbackSummary.entries) {
    final scenarioId = entry.key;
    final summary = entry.value;
    final metadata = scenarioMetadataByScenarioId[scenarioId];
    if (metadata == null) {
      continue;
    }
    final trend = summary['trend']?.toString() ?? 'unknown';
    final latestBranch = summary['latestBranch']?.toString() ?? 'clean';
    if (latestBranch != 'active' ||
        !_shouldAlertOnSequenceFallbackTrend(trend)) {
      continue;
    }
    alerts.add(<String, dynamic>{
      'severity': _buildAlertSeverity(
        scenarioSet: metadata['scenarioSet'] ?? '',
        status: metadata['status'] ?? '',
        trend: trend,
      ),
      'scope': 'sequence_fallback',
      'scenarioId': scenarioId,
      'category': metadata['category'],
      'scenarioSet': metadata['scenarioSet'],
      'status': metadata['status'],
      'tags': metadata['tags'],
      'field': 'sequenceFallbackBranch',
      'trend': trend,
      'count': summary['fallbackRunCount'],
      'latestBranch': latestBranch,
      if (summary['latestLifecycleSignature'] != null)
        'latestSequenceFallbackLifecycleSignature':
            summary['latestLifecycleSignature'],
      if (summary['latestTarget'] != null)
        'latestTarget': summary['latestTarget'],
      if (summary['latestSummary'] != null)
        'latestSummary': summary['latestSummary'],
      'message': _buildSequenceFallbackAlertMessage(
        trend: trend,
        target: summary['latestTarget']?.toString(),
      ),
    });
  }

  for (final entry in historyScenarioMismatchFieldTrendSummary.entries) {
    final scenarioId = entry.key;
    final metadata = scenarioMetadataByScenarioId[scenarioId];
    if (metadata == null) {
      continue;
    }
    final fieldEntries = entry.value.entries.toList()
      ..sort(_compareMismatchFieldTrendEntries);
    for (final fieldEntry in fieldEntries) {
      final field = fieldEntry.key.toString().trim();
      final trend = fieldEntry.value['trend']?.toString() ?? 'unknown';
      if (!_shouldAlertOnTrend(trend)) {
        continue;
      }
      if (field == 'commandBrainTimeline') {
        final latestRecord = latestHistoryRecordByScenarioId[scenarioId];
        alerts.add(<String, dynamic>{
          'severity': _buildAlertSeverity(
            scenarioSet: metadata['scenarioSet'] ?? '',
            status: metadata['status'] ?? '',
            trend: trend,
          ),
          'scope': 'command_brain_timeline',
          'scenarioId': scenarioId,
          'category': metadata['category'],
          'scenarioSet': metadata['scenarioSet'],
          'status': metadata['status'],
          'tags': metadata['tags'],
          'field': field,
          'trend': trend,
          'count': fieldEntry.value['count'],
          if (metadata['expectedCommandBrainTimelineSignature'] != null)
            'expectedCommandBrainTimelineSignature':
                metadata['expectedCommandBrainTimelineSignature'],
          if (latestRecord?['commandBrainTimelineSignature'] != null)
            'actualCommandBrainTimelineSignature':
                latestRecord?['commandBrainTimelineSignature'],
          if (metadata['expectedCommandBrainFinalTarget'] != null)
            'expectedCommandBrainFinalTarget':
                metadata['expectedCommandBrainFinalTarget'],
          if (latestRecord?['commandBrainFinalTarget'] != null)
            'actualCommandBrainFinalTarget':
                latestRecord?['commandBrainFinalTarget'],
          if (metadata['expectedCommandBrainFinalMode'] != null)
            'expectedCommandBrainFinalMode':
                metadata['expectedCommandBrainFinalMode'],
          if (latestRecord?['commandBrainFinalMode'] != null)
            'actualCommandBrainFinalMode':
                latestRecord?['commandBrainFinalMode'],
          'message': _buildCommandBrainTimelineAlertMessage(
            trend: trend,
            expectedSignature: metadata['expectedCommandBrainTimelineSignature']
                ?.toString(),
            actualSignature: latestRecord?['commandBrainTimelineSignature']
                ?.toString(),
          ),
        });
        continue;
      }
      if (field == 'commandBrainReplayBiasStack') {
        final latestRecord = latestHistoryRecordByScenarioId[scenarioId];
        alerts.add(<String, dynamic>{
          'severity': _buildAlertSeverity(
            scenarioSet: metadata['scenarioSet'] ?? '',
            status: metadata['status'] ?? '',
            trend: trend,
          ),
          'scope': 'command_brain_replay_bias_stack',
          'scenarioId': scenarioId,
          'category': metadata['category'],
          'scenarioSet': metadata['scenarioSet'],
          'status': metadata['status'],
          'tags': metadata['tags'],
          'field': field,
          'trend': trend,
          'count': fieldEntry.value['count'],
          if (metadata['expectedCommandBrainFinalReplayBiasStackSignature'] !=
              null)
            'expectedCommandBrainReplayBiasStackSignature':
                metadata['expectedCommandBrainFinalReplayBiasStackSignature'],
          if (latestRecord?['commandBrainFinalReplayBiasStackSignature'] != null)
            'actualCommandBrainReplayBiasStackSignature':
                latestRecord?['commandBrainFinalReplayBiasStackSignature'],
          if (metadata['expectedCommandBrainFinalTarget'] != null)
            'expectedCommandBrainFinalTarget':
                metadata['expectedCommandBrainFinalTarget'],
          if (latestRecord?['commandBrainFinalTarget'] != null)
            'actualCommandBrainFinalTarget':
                latestRecord?['commandBrainFinalTarget'],
          if (metadata['expectedCommandBrainFinalMode'] != null)
            'expectedCommandBrainFinalMode':
                metadata['expectedCommandBrainFinalMode'],
          if (latestRecord?['commandBrainFinalMode'] != null)
            'actualCommandBrainFinalMode':
                latestRecord?['commandBrainFinalMode'],
          'message': _buildCommandBrainReplayBiasStackAlertMessage(
            trend: trend,
            expectedSignature:
                metadata['expectedCommandBrainFinalReplayBiasStackSignature']
                    ?.toString(),
            actualSignature:
                latestRecord?['commandBrainFinalReplayBiasStackSignature']
                    ?.toString(),
          ),
        });
        continue;
      }
      alerts.add(<String, dynamic>{
        'severity': _buildAlertSeverity(
          scenarioSet: metadata['scenarioSet'] ?? '',
          status: metadata['status'] ?? '',
          trend: trend,
        ),
        'scope': 'scenario_field',
        'scenarioId': scenarioId,
        'category': metadata['category'],
        'scenarioSet': metadata['scenarioSet'],
        'status': metadata['status'],
        'tags': metadata['tags'],
        'field': field,
        'trend': trend,
        'count': fieldEntry.value['count'],
        'message': _buildScenarioFieldAlertMessage(field: field, trend: trend),
      });
    }
  }

  alerts.sort((left, right) {
    final severityOrder = _alertSeverityRank(
      right['severity']?.toString() ?? '',
    ).compareTo(_alertSeverityRank(left['severity']?.toString() ?? ''));
    if (severityOrder != 0) {
      return severityOrder;
    }
    final leftCount = left['count'] is int ? left['count'] as int : 0;
    final rightCount = right['count'] is int ? right['count'] as int : 0;
    if (leftCount != rightCount) {
      return rightCount.compareTo(leftCount);
    }
    final leftScenarioId = left['scenarioId']?.toString() ?? '';
    final rightScenarioId = right['scenarioId']?.toString() ?? '';
    final scenarioOrder = leftScenarioId.compareTo(rightScenarioId);
    if (scenarioOrder != 0) {
      return scenarioOrder;
    }
    final scopeOrder = _historyAlertScopeRank(
      right['scope']?.toString() ?? '',
    ).compareTo(_historyAlertScopeRank(left['scope']?.toString() ?? ''));
    if (scopeOrder != 0) {
      return scopeOrder;
    }
    final leftField = left['field']?.toString() ?? '';
    final rightField = right['field']?.toString() ?? '';
    final fieldPriorityOrder = _mismatchFieldPriority(
      rightField,
    ).compareTo(_mismatchFieldPriority(leftField));
    if (fieldPriorityOrder != 0) {
      return fieldPriorityOrder;
    }
    return leftField.compareTo(rightField);
  });

  return alerts;
}

Map<String, Map<String, dynamic>> _buildLatestHistoryRecordByScenarioId(
  List<Map<String, dynamic>> historyRecords,
) {
  final latestRecords = <String, Map<String, dynamic>>{};
  for (final record in historyRecords) {
    final scenarioId = record['scenarioId']?.toString().trim();
    final runId = record['runId']?.toString().trim();
    if (scenarioId == null ||
        scenarioId.isEmpty ||
        runId == null ||
        runId.isEmpty) {
      continue;
    }
    final existing = latestRecords[scenarioId];
    final existingRunId = existing?['runId']?.toString() ?? '';
    if (existing == null || runId.compareTo(existingRunId) > 0) {
      latestRecords[scenarioId] = record;
    }
  }
  return latestRecords;
}

bool _shouldAlertOnTrend(String trend) {
  switch (trend) {
    case 'watch':
    case 'worsening':
    case 'stabilizing':
      return true;
  }
  return false;
}

bool _shouldAlertOnSequenceFallbackTrend(String trend) {
  switch (trend) {
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

int _historyAlertScopeRank(String scope) {
  switch (scope.trim().toLowerCase()) {
    case 'command_brain_replay_bias_stack':
      return 6;
    case 'command_brain_timeline':
      return 5;
    case 'specialist_constraint':
      return 4;
    case 'specialist_conflict':
      return 3;
    case 'sequence_fallback':
      return 2;
    case 'specialist_degradation':
      return 1;
    case 'scenario':
      return 0;
    case 'scenario_field':
      return -1;
  }
  return -2;
}

int _historyTrendRank(String trend) {
  switch (trend.trim().toLowerCase()) {
    case 'worsening':
      return 5;
    case 'stabilizing':
      return 4;
    case 'watch':
      return 3;
    case 'clean_again':
      return 2;
    case 'clean':
      return 1;
  }
  return 0;
}

int _compareMismatchFieldCountEntries(
  MapEntry<dynamic, dynamic> left,
  MapEntry<dynamic, dynamic> right,
) {
  final leftCount = left.value is int ? left.value as int : 0;
  final rightCount = right.value is int ? right.value as int : 0;
  if (leftCount != rightCount) {
    return rightCount.compareTo(leftCount);
  }
  final priorityOrder = _mismatchFieldPriority(
    _mismatchFieldName(right.key),
  ).compareTo(_mismatchFieldPriority(_mismatchFieldName(left.key)));
  if (priorityOrder != 0) {
    return priorityOrder;
  }
  return _mismatchFieldName(left.key).compareTo(_mismatchFieldName(right.key));
}

int _compareMismatchFieldTrendEntries(
  MapEntry<dynamic, dynamic> left,
  MapEntry<dynamic, dynamic> right,
) {
  final leftCount = left.value is Map && left.value['count'] is int
      ? left.value['count'] as int
      : 0;
  final rightCount = right.value is Map && right.value['count'] is int
      ? right.value['count'] as int
      : 0;
  if (leftCount != rightCount) {
    return rightCount.compareTo(leftCount);
  }
  final trendOrder =
      _historyTrendRank(
        right.value is Map ? right.value['trend']?.toString() ?? '' : '',
      ).compareTo(
        _historyTrendRank(
          left.value is Map ? left.value['trend']?.toString() ?? '' : '',
        ),
      );
  if (trendOrder != 0) {
    return trendOrder;
  }
  final priorityOrder = _mismatchFieldPriority(
    _mismatchFieldName(right.key),
  ).compareTo(_mismatchFieldPriority(_mismatchFieldName(left.key)));
  if (priorityOrder != 0) {
    return priorityOrder;
  }
  return _mismatchFieldName(left.key).compareTo(_mismatchFieldName(right.key));
}

int _compareHistoryTrendCountEntries(
  MapEntry<dynamic, dynamic> left,
  MapEntry<dynamic, dynamic> right,
) {
  final leftCount = left.value is int ? left.value as int : 0;
  final rightCount = right.value is int ? right.value as int : 0;
  if (leftCount != rightCount) {
    return rightCount.compareTo(leftCount);
  }
  final trendOrder = _historyTrendRank(
    right.key?.toString() ?? '',
  ).compareTo(_historyTrendRank(left.key?.toString() ?? ''));
  if (trendOrder != 0) {
    return trendOrder;
  }
  return (left.key?.toString() ?? '').compareTo(right.key?.toString() ?? '');
}

String _mismatchFieldName(dynamic value) {
  return value?.toString().trim() ?? '';
}

int _mismatchFieldPriority(String field) {
  switch (field.trim().toLowerCase()) {
    case 'commandbrainreplaybiasstack':
      return 9;
    case 'commandbraintimeline':
      return 8;
    case 'commandbrainsnapshot':
      return 7;
    case 'expectedescalationstate':
      return 6;
    case 'expectedblockedactions':
      return 5;
    case 'expecteduistate':
      return 4;
    case 'expectedroute':
      return 3;
    case 'expectedintent':
      return 2;
    case 'expectedprojectionchanges':
      return 1;
    case 'expecteddrafts':
      return 0;
  }
  return 0;
}

List<Map<String, dynamic>> _buildTriggeredAlertSummary(
  dynamic historyAlerts, {
  required _AlertFailurePolicy? policy,
  required String? thresholdOverride,
  required String? groupFilterOverride,
  required String? tagFilterOverride,
  required String? categoryFilterOverride,
  required String? statusFilterOverride,
}) {
  if (historyAlerts is! List) {
    return const <Map<String, dynamic>>[];
  }
  final resolvedGroup = _resolveAlertFailureGroup(
    policy: policy,
    groupFilterOverride: groupFilterOverride,
  );
  return historyAlerts
      .whereType<Map<String, dynamic>>()
      .where((alert) {
        final scenarioSet = alert['scenarioSet']?.toString();
        final alertCategory = alert['category']
            ?.toString()
            .trim()
            .toLowerCase();
        final alertScenarioId = alert['scenarioId']?.toString();
        final alertStatus = alert['status']?.toString().trim().toLowerCase();
        final alertTags = _readAlertTags(alert['tags']);
        if (resolvedGroup != null) {
          if (resolvedGroup.categories.isNotEmpty &&
              (alertCategory == null ||
                  !resolvedGroup.categories.contains(alertCategory))) {
            return false;
          }
          if (resolvedGroup.statuses.isNotEmpty &&
              (alertStatus == null ||
                  !resolvedGroup.statuses.contains(alertStatus))) {
            return false;
          }
          if (resolvedGroup.scenarioIds.isNotEmpty &&
              (alertScenarioId == null ||
                  !resolvedGroup.scenarioIds.contains(alertScenarioId))) {
            return false;
          }
          if (resolvedGroup.tags.isNotEmpty &&
              !alertTags.any(resolvedGroup.tags.contains)) {
            return false;
          }
        }
        if (tagFilterOverride != null &&
            !alertTags.contains(tagFilterOverride)) {
          return false;
        }
        final resolvedRule = policy?.resolveForScenario(
          scenarioSet: scenarioSet,
          category: alertCategory,
          scenarioId: alertScenarioId,
        );
        final threshold = thresholdOverride ?? resolvedRule?.threshold;
        if (threshold == null || threshold.isEmpty) {
          return false;
        }
        final thresholdRank = _alertSeverityRank(threshold);
        final includeCategories = categoryFilterOverride != null
            ? <String>[categoryFilterOverride]
            : resolvedRule?.includeCategories ?? const <String>[];
        final includeStatuses = statusFilterOverride != null
            ? <String>[statusFilterOverride]
            : resolvedRule?.includeStatuses ?? const <String>[];
        final excludeCategories =
            resolvedRule?.excludeCategories ?? const <String>[];
        final excludeStatuses =
            resolvedRule?.excludeStatuses ?? const <String>[];
        final severity = _resolveEffectiveAlertSeverity(
          alert,
          resolvedRule: resolvedRule,
          group: resolvedGroup,
        );
        if (_alertSeverityRank(severity) < thresholdRank) {
          return false;
        }
        if (includeCategories.isNotEmpty &&
            (alertCategory == null ||
                !includeCategories.contains(alertCategory))) {
          return false;
        }
        if (alertCategory != null &&
            excludeCategories.contains(alertCategory)) {
          return false;
        }
        if (includeStatuses.isNotEmpty &&
            (alertStatus == null || !includeStatuses.contains(alertStatus))) {
          return false;
        }
        if (alertStatus != null && excludeStatuses.contains(alertStatus)) {
          return false;
        }
        return true;
      })
      .map(
        (alert) => _copyAlertWithSeverityOverrides(
          alert,
          resolvedRule: policy?.resolveForScenario(
            scenarioSet: alert['scenarioSet']?.toString(),
            category: alert['category']?.toString().trim().toLowerCase(),
            scenarioId: alert['scenarioId']?.toString(),
          ),
          group: resolvedGroup,
        ),
      )
      .toList(growable: false);
}

String _resolveRuleAdjustedAlertSeverity(
  Map<String, dynamic> alert, {
  required _ResolvedAlertFailureRule? resolvedRule,
}) {
  final fallbackSeverity =
      alert['severity']?.toString().trim().toLowerCase() ?? '';
  final scope = _readNormalizedAlertScope(alert);
  if (resolvedRule == null || scope == null) {
    return fallbackSeverity;
  }
  return resolvedRule.severityByScope[scope] ?? fallbackSeverity;
}

String _resolveEffectiveAlertSeverity(
  Map<String, dynamic> alert, {
  required _ResolvedAlertFailureRule? resolvedRule,
  required _AlertFailureGroup? group,
}) {
  final fallbackSeverity = _resolveRuleAdjustedAlertSeverity(
    alert,
    resolvedRule: resolvedRule,
  );
  if (group == null) {
    return fallbackSeverity;
  }
  final scope = _readNormalizedAlertScope(alert);
  if (scope == null || scope.isEmpty) {
    return fallbackSeverity;
  }
  return group.severityByScope[scope] ?? fallbackSeverity;
}

Map<String, String>? _buildRuleSeverityOverridePolicyMatch({
  required Map<String, dynamic> alert,
  required _AlertFailurePolicy policy,
  required _ResolvedAlertFailureRule? resolvedRule,
  required String? scenarioSet,
  required String? category,
  required String? scenarioId,
}) {
  final scope = _readNormalizedAlertScope(alert);
  if (scope == null || resolvedRule == null) {
    return null;
  }
  final overriddenSeverity = resolvedRule.severityByScope[scope];
  final originalSeverity =
      alert['originalSeverity']?.toString().trim().toLowerCase() ??
      alert['severity']?.toString().trim().toLowerCase();
  if (overriddenSeverity == null ||
      overriddenSeverity.isEmpty ||
      originalSeverity == null ||
      originalSeverity.isEmpty ||
      overriddenSeverity == originalSeverity) {
    return null;
  }
  return <String, String>{
    'policyMatchType': 'scope_severity_override',
    'policyMatchValue': '$scope:$overriddenSeverity',
    'policyMatchSource':
        policy.resolveFieldSource(
          scenarioSet: scenarioSet,
          category: category,
          scenarioId: scenarioId,
          fieldKey: 'severityByScope.$scope',
        ) ??
        'unresolved',
    'originalSeverity': originalSeverity,
    'severityOverrideScope': scope,
  };
}

Map<String, dynamic> _copyAlertWithSeverityOverrides(
  Map<String, dynamic> alert, {
  required _ResolvedAlertFailureRule? resolvedRule,
  required _AlertFailureGroup? group,
}) {
  final copy = Map<String, dynamic>.from(alert);
  final originalSeverity = alert['severity']?.toString().trim().toLowerCase();
  final ruleAdjustedSeverity = _resolveRuleAdjustedAlertSeverity(
    alert,
    resolvedRule: resolvedRule,
  );
  final scope = _readNormalizedAlertScope(alert);
  if (originalSeverity != null &&
      originalSeverity.isNotEmpty &&
      ruleAdjustedSeverity.isNotEmpty &&
      ruleAdjustedSeverity != originalSeverity) {
    copy['originalSeverity'] = originalSeverity;
    copy['severity'] = ruleAdjustedSeverity;
    if (scope != null) {
      copy['severityOverrideScope'] = scope;
      copy['severityOverridePolicyValue'] = '$scope:$ruleAdjustedSeverity';
    }
  }
  final overriddenSeverity = _resolveEffectiveAlertSeverity(
    alert,
    resolvedRule: resolvedRule,
    group: group,
  );
  final effectiveSeverity = overriddenSeverity.isNotEmpty
      ? overriddenSeverity
      : (ruleAdjustedSeverity.isNotEmpty ? ruleAdjustedSeverity : null);
  copy.addAll(
    _buildAlertSeverityContextFields(
      alert,
      effectiveSeverity: effectiveSeverity,
    ),
  );
  if (overriddenSeverity.isEmpty) {
    return copy;
  }
  copy['severity'] = overriddenSeverity;
  return copy;
}

Map<String, dynamic> _buildAlertSeverityContextFields(
  Map<String, dynamic> alert, {
  required String? effectiveSeverity,
}) {
  final baseSeverity =
      alert['baseSeverity']?.toString().trim().toLowerCase() ??
      alert['originalSeverity']?.toString().trim().toLowerCase() ??
      alert['severity']?.toString().trim().toLowerCase();
  final normalizedEffectiveSeverity = effectiveSeverity?.trim().toLowerCase();
  final resolvedEffectiveSeverity =
      normalizedEffectiveSeverity != null &&
          normalizedEffectiveSeverity.isNotEmpty
      ? normalizedEffectiveSeverity
      : baseSeverity;
  final context = <String, dynamic>{};
  if (baseSeverity != null && baseSeverity.isNotEmpty) {
    context['baseSeverity'] = baseSeverity;
  }
  if (resolvedEffectiveSeverity != null &&
      resolvedEffectiveSeverity.isNotEmpty) {
    context['effectiveSeverity'] = resolvedEffectiveSeverity;
  }
  if (baseSeverity != null &&
      baseSeverity.isNotEmpty &&
      resolvedEffectiveSeverity != null &&
      resolvedEffectiveSeverity.isNotEmpty &&
      baseSeverity != resolvedEffectiveSeverity) {
    context['effectiveSeverityChanged'] = true;
    context['effectiveSeverityPromoted'] =
        _alertSeverityRank(resolvedEffectiveSeverity) >
        _alertSeverityRank(baseSeverity);
    context['effectiveSeverityDemoted'] =
        _alertSeverityRank(resolvedEffectiveSeverity) <
        _alertSeverityRank(baseSeverity);
    context['severityTransition'] = '$baseSeverity->$resolvedEffectiveSeverity';
  }
  return context;
}

List<String> _readAlertTags(dynamic value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .map((tag) => tag?.toString().trim().toLowerCase())
      .whereType<String>()
      .where((tag) => tag.isNotEmpty)
      .toList(growable: false);
}

_AlertFailureGroup? _resolveAlertFailureGroup({
  required _AlertFailurePolicy? policy,
  required String? groupFilterOverride,
}) {
  final normalizedGroup = groupFilterOverride?.trim().toLowerCase();
  if (normalizedGroup == null || normalizedGroup.isEmpty) {
    return null;
  }
  if (policy == null) {
    throw const FormatException(
      'Alert failure group filtering requires a policy file.',
    );
  }
  final group = policy.groups[normalizedGroup];
  if (group == null) {
    throw FormatException('Unknown alert failure group "$normalizedGroup".');
  }
  return group;
}

String _buildScenarioAlertMessage(String trend) {
  switch (trend) {
    case 'worsening':
      return 'Scenario regressed after a clean pass.';
    case 'stabilizing':
      return 'Scenario is still failing across repeated runs.';
    case 'watch':
      return 'Scenario has a fresh failure to watch.';
  }
  return 'Scenario history needs review.';
}

String _buildScenarioFieldAlertMessage({
  required String field,
  required String trend,
}) {
  switch (trend) {
    case 'worsening':
      return 'Mismatch field $field regressed after a clean pass.';
    case 'stabilizing':
      return 'Mismatch field $field is still drifting across repeated runs.';
    case 'watch':
      return 'Mismatch field $field has a fresh failure to watch.';
  }
  return 'Mismatch field $field needs review.';
}

String _buildCommandBrainTimelineAlertMessage({
  required String trend,
  String? expectedSignature,
  String? actualSignature,
}) {
  final signatureSuffix = expectedSignature != null || actualSignature != null
      ? ' Expected ${expectedSignature ?? 'unknown'} but saw ${actualSignature ?? 'unknown'}.'
      : '';
  switch (trend) {
    case 'worsening':
      return 'Command-brain timeline regressed after a clean pass.$signatureSuffix';
    case 'stabilizing':
      return 'Command-brain timeline is still drifting across repeated runs.$signatureSuffix';
    case 'watch':
      return 'Command-brain timeline has a fresh failure to watch.$signatureSuffix';
  }
  return 'Command-brain timeline needs review.$signatureSuffix';
}

String _buildCommandBrainReplayBiasStackAlertMessage({
  required String trend,
  String? expectedSignature,
  String? actualSignature,
}) {
  final signatureSuffix = expectedSignature != null || actualSignature != null
      ? ' Expected ${expectedSignature ?? 'unknown'} but saw ${actualSignature ?? 'unknown'}.'
      : '';
  switch (trend) {
    case 'worsening':
      return 'Command-brain replay bias stack regressed after a clean pass.$signatureSuffix';
    case 'stabilizing':
      return 'Command-brain replay bias stack is still drifting across repeated runs.$signatureSuffix';
    case 'watch':
      return 'Command-brain replay bias stack has a fresh failure to watch.$signatureSuffix';
  }
  return 'Command-brain replay bias stack needs review.$signatureSuffix';
}

String _buildSpecialistDegradationAlertMessage({
  required String trend,
  String? signature,
}) {
  final signatureSuffix = signature == null || signature.isEmpty
      ? ''
      : ' Latest branch $signature.';
  switch (trend) {
    case 'worsening':
      return 'Specialist degradation regressed into a persistent branch after a cleaner run.$signatureSuffix';
    case 'stabilizing':
      return 'Specialist degradation is still persisting across repeated runs.$signatureSuffix';
    case 'watch':
      return 'Specialist degradation has a fresh persistent branch to watch.$signatureSuffix';
  }
  return 'Specialist degradation needs review.$signatureSuffix';
}

String _buildSpecialistConflictAlertMessage({
  required String trend,
  String? signature,
}) {
  final signatureSuffix = signature == null || signature.isEmpty
      ? ''
      : ' Latest branch $signature.';
  switch (trend) {
    case 'worsening':
      return 'Specialist conflict regressed into a persistent branch after a cleaner run.$signatureSuffix';
    case 'stabilizing':
      return 'Specialist conflict is still persisting across repeated runs.$signatureSuffix';
    case 'watch':
      return 'Specialist conflict has a fresh persistent branch to watch.$signatureSuffix';
  }
  return 'Specialist conflict needs review.$signatureSuffix';
}

String _buildSpecialistConstraintAlertMessage({
  required String trend,
  String? signature,
}) {
  final signatureSuffix = signature == null || signature.isEmpty
      ? ''
      : ' Latest branch $signature.';
  switch (trend) {
    case 'worsening':
      return 'Hard specialist constraint regressed into a blocking branch after a cleaner run.$signatureSuffix';
    case 'stabilizing':
      return 'Hard specialist constraint is still blocking repeated runs.$signatureSuffix';
    case 'watch':
      return 'Hard specialist constraint has a fresh blocking branch to watch.$signatureSuffix';
  }
  return 'Hard specialist constraint needs review.$signatureSuffix';
}

String _buildSequenceFallbackAlertMessage({
  required String trend,
  String? target,
}) {
  final targetSuffix = target == null || target.isEmpty
      ? ''
      : ' Latest fallback target ${_toolTargetLabelFromName(target) ?? target}.';
  switch (trend) {
    case 'worsening':
      return 'Sequence fallback reactivated after a cleaner run and is still biasing the command surface.$targetSuffix';
    case 'stabilizing':
      return 'Sequence fallback is still active across repeated runs and continues to bias the command surface.$targetSuffix';
    case 'watch':
      return 'Sequence fallback has a fresh active branch to watch.$targetSuffix';
  }
  return 'Sequence fallback needs review.$targetSuffix';
}

class _AlertFailurePolicy {
  const _AlertFailurePolicy({
    required this.path,
    this.defaultRule = const _AlertFailureRule(),
    this.byScenarioSet = const <String, _AlertFailureRule>{},
    this.groups = const <String, _AlertFailureGroup>{},
  });

  factory _AlertFailurePolicy.fromJson(
    Map<String, dynamic> json, {
    required String path,
  }) {
    final rawAlertFailure = json['alertFailure'];
    if (rawAlertFailure == null) {
      return _AlertFailurePolicy(path: path);
    }
    if (rawAlertFailure is! Map<String, dynamic>) {
      throw const FormatException(
        'Scenario policy "alertFailure" must be a JSON object.',
      );
    }
    final byScenarioSet = <String, _AlertFailureRule>{};
    final rawByScenarioSet = rawAlertFailure['byScenarioSet'];
    if (rawByScenarioSet != null) {
      if (rawByScenarioSet is! Map<String, dynamic>) {
        throw const FormatException(
          'Scenario policy "alertFailure.byScenarioSet" must be a JSON object.',
        );
      }
      for (final entry in rawByScenarioSet.entries) {
        final normalizedScenarioSet = entry.key.trim().toLowerCase();
        if (normalizedScenarioSet.isEmpty) {
          throw const FormatException(
            'Scenario policy "alertFailure.byScenarioSet" keys must be non-empty.',
          );
        }
        if (entry.value is! Map<String, dynamic>) {
          throw FormatException(
            'Scenario policy rule for scenario set "$normalizedScenarioSet" must be a JSON object.',
          );
        }
        byScenarioSet[normalizedScenarioSet] = _AlertFailureRule.fromJson(
          entry.value as Map<String, dynamic>,
        );
      }
    }
    final groups = <String, _AlertFailureGroup>{};
    final rawGroups = rawAlertFailure['groups'];
    if (rawGroups != null) {
      if (rawGroups is! Map<String, dynamic>) {
        throw const FormatException(
          'Scenario policy "alertFailure.groups" must be a JSON object.',
        );
      }
      for (final entry in rawGroups.entries) {
        final normalizedGroup = entry.key.trim().toLowerCase();
        if (normalizedGroup.isEmpty) {
          throw const FormatException(
            'Scenario policy "alertFailure.groups" keys must be non-empty.',
          );
        }
        if (entry.value is! Map<String, dynamic>) {
          throw FormatException(
            'Scenario policy group "$normalizedGroup" must be a JSON object.',
          );
        }
        groups[normalizedGroup] = _AlertFailureGroup.fromJson(
          entry.value as Map<String, dynamic>,
        );
      }
    }
    return _AlertFailurePolicy(
      path: path,
      defaultRule: _AlertFailureRule.fromJson(rawAlertFailure),
      byScenarioSet: byScenarioSet,
      groups: groups,
    );
  }

  final String path;
  final _AlertFailureRule defaultRule;
  final Map<String, _AlertFailureRule> byScenarioSet;
  final Map<String, _AlertFailureGroup> groups;

  _ResolvedAlertFailureRule resolveForScenario({
    required String? scenarioSet,
    required String? category,
    required String? scenarioId,
  }) {
    final normalizedScenarioSet = scenarioSet?.trim().toLowerCase();
    final normalizedCategory = category?.trim().toLowerCase();
    final normalizedScenarioId = scenarioId?.trim();
    final scenarioSetRule =
        normalizedScenarioSet == null || normalizedScenarioSet.isEmpty
        ? null
        : byScenarioSet[normalizedScenarioSet];
    final defaultCategoryRule =
        normalizedCategory == null || normalizedCategory.isEmpty
        ? null
        : defaultRule.byCategory[normalizedCategory];
    final scenarioSetCategoryRule =
        normalizedCategory == null || normalizedCategory.isEmpty
        ? null
        : scenarioSetRule?.byCategory[normalizedCategory];
    final defaultScenarioIdRule =
        normalizedScenarioId == null || normalizedScenarioId.isEmpty
        ? null
        : defaultRule.byScenarioId[normalizedScenarioId];
    final scenarioSetScenarioIdRule =
        normalizedScenarioId == null || normalizedScenarioId.isEmpty
        ? null
        : scenarioSetRule?.byScenarioId[normalizedScenarioId];
    return _ResolvedAlertFailureRule(
      threshold:
          scenarioSetScenarioIdRule?.threshold ??
          defaultScenarioIdRule?.threshold ??
          scenarioSetCategoryRule?.threshold ??
          defaultCategoryRule?.threshold ??
          scenarioSetRule?.threshold ??
          defaultRule.threshold,
      includeCategories:
          scenarioSetScenarioIdRule?.includeCategories ??
          defaultScenarioIdRule?.includeCategories ??
          scenarioSetCategoryRule?.includeCategories ??
          defaultCategoryRule?.includeCategories ??
          scenarioSetRule?.includeCategories ??
          defaultRule.includeCategories ??
          const <String>[],
      includeStatuses:
          scenarioSetScenarioIdRule?.includeStatuses ??
          defaultScenarioIdRule?.includeStatuses ??
          scenarioSetCategoryRule?.includeStatuses ??
          defaultCategoryRule?.includeStatuses ??
          scenarioSetRule?.includeStatuses ??
          defaultRule.includeStatuses ??
          const <String>[],
      excludeCategories:
          scenarioSetScenarioIdRule?.excludeCategories ??
          defaultScenarioIdRule?.excludeCategories ??
          scenarioSetCategoryRule?.excludeCategories ??
          defaultCategoryRule?.excludeCategories ??
          scenarioSetRule?.excludeCategories ??
          defaultRule.excludeCategories ??
          const <String>[],
      excludeStatuses:
          scenarioSetScenarioIdRule?.excludeStatuses ??
          defaultScenarioIdRule?.excludeStatuses ??
          scenarioSetCategoryRule?.excludeStatuses ??
          defaultCategoryRule?.excludeStatuses ??
          scenarioSetRule?.excludeStatuses ??
          defaultRule.excludeStatuses ??
          const <String>[],
      severityByScope:
          scenarioSetScenarioIdRule?.severityByScope ??
          defaultScenarioIdRule?.severityByScope ??
          scenarioSetCategoryRule?.severityByScope ??
          defaultCategoryRule?.severityByScope ??
          scenarioSetRule?.severityByScope ??
          defaultRule.severityByScope ??
          const <String, String>{},
    );
  }

  _ResolvedAlertFailureRule resolveForScenarioSet(String? scenarioSet) {
    return resolveForScenario(
      scenarioSet: scenarioSet,
      category: null,
      scenarioId: null,
    );
  }

  String? resolveFieldSource({
    required String? scenarioSet,
    required String? category,
    required String? scenarioId,
    required String fieldKey,
  }) {
    final normalizedScenarioSet = scenarioSet?.trim().toLowerCase();
    final normalizedCategory = category?.trim().toLowerCase();
    final normalizedScenarioId = scenarioId?.trim();
    final scenarioSetRule =
        normalizedScenarioSet == null || normalizedScenarioSet.isEmpty
        ? null
        : byScenarioSet[normalizedScenarioSet];
    final defaultCategoryRule =
        normalizedCategory == null || normalizedCategory.isEmpty
        ? null
        : defaultRule.byCategory[normalizedCategory];
    final scenarioSetCategoryRule =
        normalizedCategory == null || normalizedCategory.isEmpty
        ? null
        : scenarioSetRule?.byCategory[normalizedCategory];
    final defaultScenarioIdRule =
        normalizedScenarioId == null || normalizedScenarioId.isEmpty
        ? null
        : defaultRule.byScenarioId[normalizedScenarioId];
    final scenarioSetScenarioIdRule =
        normalizedScenarioId == null || normalizedScenarioId.isEmpty
        ? null
        : scenarioSetRule?.byScenarioId[normalizedScenarioId];

    final candidates = <MapEntry<String, _AlertFailureRule?>>[
      MapEntry('scenario_set_scenario_id', scenarioSetScenarioIdRule),
      MapEntry('scenario_id', defaultScenarioIdRule),
      MapEntry('scenario_set_category', scenarioSetCategoryRule),
      MapEntry('category', defaultCategoryRule),
      MapEntry('scenario_set', scenarioSetRule),
      MapEntry('default', defaultRule),
    ];
    for (final candidate in candidates) {
      final rule = candidate.value;
      if (rule == null) {
        continue;
      }
      if (_alertFailureRuleHasFieldValue(rule, fieldKey)) {
        return candidate.key;
      }
    }
    return null;
  }

  Map<String, dynamic> resolvedScenarioSetRulesToJson() {
    final summary = <String, dynamic>{};
    final keys = byScenarioSet.keys.toList()..sort();
    for (final key in keys) {
      final resolvedRule = resolveForScenarioSet(key).toJson();
      final resolvedCategories = resolvedCategoryRulesToJson(scenarioSet: key);
      if (resolvedCategories.isNotEmpty) {
        resolvedRule['byCategory'] = resolvedCategories;
      }
      final resolvedScenarioIds = resolvedScenarioIdRulesToJson(
        scenarioSet: key,
      );
      if (resolvedScenarioIds.isNotEmpty) {
        resolvedRule['byScenarioId'] = resolvedScenarioIds;
      }
      summary[key] = resolvedRule;
    }
    return summary;
  }

  Map<String, dynamic> resolvedCategoryRulesToJson({String? scenarioSet}) {
    final normalizedScenarioSet = scenarioSet?.trim().toLowerCase();
    final scenarioSetRule =
        normalizedScenarioSet == null || normalizedScenarioSet.isEmpty
        ? null
        : byScenarioSet[normalizedScenarioSet];
    final categoryKeys = <String>{
      ...defaultRule.byCategory.keys,
      ...?scenarioSetRule?.byCategory.keys,
    }.toList()..sort();
    final summary = <String, dynamic>{};
    for (final key in categoryKeys) {
      summary[key] = resolveForScenario(
        scenarioSet: normalizedScenarioSet,
        category: key,
        scenarioId: null,
      ).toJson();
    }
    return summary;
  }

  Map<String, dynamic> resolvedScenarioIdRulesToJson({String? scenarioSet}) {
    final normalizedScenarioSet = scenarioSet?.trim().toLowerCase();
    final scenarioSetRule =
        normalizedScenarioSet == null || normalizedScenarioSet.isEmpty
        ? null
        : byScenarioSet[normalizedScenarioSet];
    final scenarioIds = <String>{
      ...defaultRule.byScenarioId.keys,
      ...?scenarioSetRule?.byScenarioId.keys,
    }.toList()..sort();
    final summary = <String, dynamic>{};
    for (final scenarioId in scenarioIds) {
      summary[scenarioId] = resolveForScenario(
        scenarioSet: normalizedScenarioSet,
        category: null,
        scenarioId: scenarioId,
      ).toJson();
    }
    return summary;
  }

  Map<String, dynamic> groupsToJson() {
    final summary = <String, dynamic>{};
    final keys = groups.keys.toList()..sort();
    for (final key in keys) {
      summary[key] = groups[key]!.toJson();
    }
    return summary;
  }
}

class _AlertFailureGroup {
  const _AlertFailureGroup({
    required this.categories,
    required this.statuses,
    required this.scenarioIds,
    required this.tags,
    required this.severityByScope,
  });

  factory _AlertFailureGroup.fromJson(Map<String, dynamic> json) {
    return _AlertFailureGroup(
      categories: json.containsKey('categories')
          ? _readNormalizedStringList(json, 'categories')
          : const <String>[],
      statuses: json.containsKey('statuses')
          ? _readNormalizedStringList(json, 'statuses')
          : const <String>[],
      scenarioIds: json.containsKey('scenarioIds')
          ? _readTrimmedStringList(json, 'scenarioIds')
          : const <String>[],
      tags: json.containsKey('tags')
          ? _readNormalizedStringList(json, 'tags')
          : const <String>[],
      severityByScope: json.containsKey('severityByScope')
          ? _readAlertSeverityByScope(json, 'severityByScope')
          : const <String, String>{},
    );
  }

  final List<String> categories;
  final List<String> statuses;
  final List<String> scenarioIds;
  final List<String> tags;
  final Map<String, String> severityByScope;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'categories': categories,
      'statuses': statuses,
      'scenarioIds': scenarioIds,
      'tags': tags,
      'severityByScope': severityByScope,
    };
  }
}

class _AlertFailureRule {
  const _AlertFailureRule({
    this.threshold,
    this.includeCategories,
    this.includeStatuses,
    this.excludeCategories,
    this.excludeStatuses,
    this.severityByScope,
    this.byCategory = const <String, _AlertFailureRule>{},
    this.byScenarioId = const <String, _AlertFailureRule>{},
  });

  factory _AlertFailureRule.fromJson(Map<String, dynamic> json) {
    final threshold = json.containsKey('threshold')
        ? _normalizeAlertSeverityOption(json['threshold']?.toString())
        : null;
    final byCategory = <String, _AlertFailureRule>{};
    final rawByCategory = json['byCategory'];
    if (rawByCategory != null) {
      if (rawByCategory is! Map<String, dynamic>) {
        throw const FormatException(
          'Scenario policy "byCategory" must be a JSON object.',
        );
      }
      for (final entry in rawByCategory.entries) {
        final normalizedCategory = entry.key.trim().toLowerCase();
        if (normalizedCategory.isEmpty) {
          throw const FormatException(
            'Scenario policy "byCategory" keys must be non-empty.',
          );
        }
        if (entry.value is! Map<String, dynamic>) {
          throw FormatException(
            'Scenario policy rule for category "$normalizedCategory" must be a JSON object.',
          );
        }
        byCategory[normalizedCategory] = _AlertFailureRule.fromJson(
          entry.value as Map<String, dynamic>,
        );
      }
    }
    final byScenarioId = <String, _AlertFailureRule>{};
    final rawByScenarioId = json['byScenarioId'];
    if (rawByScenarioId != null) {
      if (rawByScenarioId is! Map<String, dynamic>) {
        throw const FormatException(
          'Scenario policy "byScenarioId" must be a JSON object.',
        );
      }
      for (final entry in rawByScenarioId.entries) {
        final normalizedScenarioId = entry.key.trim();
        if (normalizedScenarioId.isEmpty) {
          throw const FormatException(
            'Scenario policy "byScenarioId" keys must be non-empty.',
          );
        }
        if (entry.value is! Map<String, dynamic>) {
          throw FormatException(
            'Scenario policy rule for scenarioId "$normalizedScenarioId" must be a JSON object.',
          );
        }
        byScenarioId[normalizedScenarioId] = _AlertFailureRule.fromJson(
          entry.value as Map<String, dynamic>,
        );
      }
    }
    return _AlertFailureRule(
      threshold: threshold,
      includeCategories: json.containsKey('includeCategories')
          ? _readNormalizedStringList(json, 'includeCategories')
          : null,
      includeStatuses: json.containsKey('includeStatuses')
          ? _readNormalizedStringList(json, 'includeStatuses')
          : null,
      excludeCategories: json.containsKey('excludeCategories')
          ? _readNormalizedStringList(json, 'excludeCategories')
          : null,
      excludeStatuses: json.containsKey('excludeStatuses')
          ? _readNormalizedStringList(json, 'excludeStatuses')
          : null,
      severityByScope: json.containsKey('severityByScope')
          ? _readAlertSeverityByScope(json, 'severityByScope')
          : null,
      byCategory: byCategory,
      byScenarioId: byScenarioId,
    );
  }

  final String? threshold;
  final List<String>? includeCategories;
  final List<String>? includeStatuses;
  final List<String>? excludeCategories;
  final List<String>? excludeStatuses;
  final Map<String, String>? severityByScope;
  final Map<String, _AlertFailureRule> byCategory;
  final Map<String, _AlertFailureRule> byScenarioId;
}

class _ResolvedAlertFailureRule {
  const _ResolvedAlertFailureRule({
    required this.threshold,
    required this.includeCategories,
    required this.includeStatuses,
    required this.excludeCategories,
    required this.excludeStatuses,
    required this.severityByScope,
  });

  final String? threshold;
  final List<String> includeCategories;
  final List<String> includeStatuses;
  final List<String> excludeCategories;
  final List<String> excludeStatuses;
  final Map<String, String> severityByScope;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (threshold != null) 'threshold': threshold,
      'includeCategories': includeCategories,
      'includeStatuses': includeStatuses,
      'excludeCategories': excludeCategories,
      'excludeStatuses': excludeStatuses,
      'severityByScope': severityByScope,
    };
  }
}

bool _alertFailureRuleHasFieldValue(_AlertFailureRule rule, String fieldKey) {
  final normalizedFieldKey = fieldKey.trim();
  if (normalizedFieldKey.startsWith('severityByScope.')) {
    final scope = normalizedFieldKey.substring('severityByScope.'.length);
    return rule.severityByScope?.containsKey(scope) == true;
  }
  switch (normalizedFieldKey) {
    case 'threshold':
      return rule.threshold != null;
    case 'includeCategories':
      return rule.includeCategories != null;
    case 'includeStatuses':
      return rule.includeStatuses != null;
    case 'excludeCategories':
      return rule.excludeCategories != null;
    case 'excludeStatuses':
      return rule.excludeStatuses != null;
    case 'severityByScope':
      return rule.severityByScope != null;
  }
  return false;
}

String _buildIndexConsoleSummary(Map<String, dynamic> summary) {
  final buffer = StringBuffer()
    ..writeln('ONYX SCENARIO INDEX')
    ..writeln('Scenarios: ${summary['scenarioCount']}');
  final scenarioSetFilter = summary['scenarioSetFilter'];
  if (scenarioSetFilter != null) {
    buffer.writeln('Scenario set filter: $scenarioSetFilter');
  }
  final scenarioStatusFilter = summary['scenarioStatusFilter'];
  if (scenarioStatusFilter != null) {
    buffer.writeln('Scenario status filter: $scenarioStatusFilter');
  }

  final scenarioSetCounts = summary['scenarioSetCounts'];
  if (scenarioSetCounts is Map && scenarioSetCounts.isNotEmpty) {
    buffer.writeln('Sets:');
    final entries = scenarioSetCounts.entries.toList()
      ..sort(
        (left, right) => left.key.toString().compareTo(right.key.toString()),
      );
    for (final entry in entries) {
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
  }

  final scenarioStatusCounts = summary['scenarioStatusCounts'];
  if (scenarioStatusCounts is Map && scenarioStatusCounts.isNotEmpty) {
    buffer.writeln('Statuses:');
    final entries = scenarioStatusCounts.entries.toList()
      ..sort(
        (left, right) => left.key.toString().compareTo(right.key.toString()),
      );
    for (final entry in entries) {
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
  }

  final categoryCounts = summary['categoryCounts'];
  if (categoryCounts is Map && categoryCounts.isNotEmpty) {
    buffer.writeln('Categories:');
    final entries = categoryCounts.entries.toList()
      ..sort(
        (left, right) => left.key.toString().compareTo(right.key.toString()),
      );
    for (final entry in entries) {
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
  }

  final scenarios = summary['scenarios'];
  if (scenarios is List && scenarios.isNotEmpty) {
    buffer.writeln('Scenario list:');
    for (final scenario in scenarios) {
      if (scenario is! Map) {
        continue;
      }
      buffer.writeln(
        '- [${scenario['scenarioSet']}] ${scenario['category']} :: ${scenario['scenarioId']} (${scenario['status']})',
      );
    }
  }

  return buffer.toString().trimRight();
}

class _ResolvedScenario {
  const _ResolvedScenario({required this.path, required this.definition});

  final String path;
  final ScenarioDefinition definition;
}
