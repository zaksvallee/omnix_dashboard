import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  void syncCommandBrainWorkItemIds(Map<String, dynamic> scenarioJson) {
    final scenarioId = scenarioJson['scenarioId']?.toString();
    final expectedOutcome = scenarioJson['expectedOutcome'];
    if (scenarioId == null ||
        scenarioId.isEmpty ||
        expectedOutcome is! Map<String, dynamic>) {
      return;
    }
    final commandBrainSnapshot = expectedOutcome['commandBrainSnapshot'];
    if (commandBrainSnapshot is Map<String, dynamic>) {
      commandBrainSnapshot['workItemId'] = scenarioId;
    }
    final commandBrainTimeline = expectedOutcome['commandBrainTimeline'];
    if (commandBrainTimeline is! List) {
      return;
    }
    for (final entry in commandBrainTimeline) {
      if (entry is! Map<String, dynamic>) {
        continue;
      }
      final snapshot = entry['snapshot'];
      if (snapshot is! Map<String, dynamic>) {
        continue;
      }
      snapshot['workItemId'] = scenarioId;
    }
  }

  Future<Map<String, dynamic>> loadScenarioFixture(
    String relativePath, {
    required String scenarioId,
    String? title,
  }) async {
    final sourceScenario = File('${Directory.current.path}/$relativePath');
    final scenario =
        jsonDecode(await sourceScenario.readAsString()) as Map<String, dynamic>;
    scenario['scenarioId'] = scenarioId;
    if (title != null) {
      scenario['title'] = title;
    }
    syncCommandBrainWorkItemIds(scenario);
    return scenario;
  }

  test(
    'run_onyx_scenario tool replays one scenario and writes history on demand',
    () async {
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-tool-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-tool-history-',
      );

      try {
        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final result = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          'simulations/scenarios/admin/scenario_admin_breaches_all_sites_v1.json',
        ], workingDirectory: Directory.current.path);

        expect(result.exitCode, 0, reason: '${result.stderr}');

        final stdoutText = result.stdout as String;
        final jsonStartIndex = stdoutText.indexOf('{');
        expect(jsonStartIndex, isNonNegative, reason: stdoutText);
        final decoded =
            jsonDecode(stdoutText.substring(jsonStartIndex))
                as Map<String, dynamic>;
        expect(decoded['scenarioCount'], 1);
        expect(decoded['passedCount'], 1);
        expect(decoded['failedCount'], 0);
        expect(
          decoded['scenarioCategorySummary'],
          containsPair('admin_portfolio_read', containsPair('passedCount', 1)),
        );
        expect(
          decoded['scenarioSetSummary'],
          containsPair('replay', containsPair('passedCount', 1)),
        );
        expect(
          decoded['scenarioStatusSummary'],
          containsPair('draft', containsPair('passedCount', 1)),
        );
        expect(decoded['mismatchFieldSummary'], isEmpty);
        expect(decoded['categoryMismatchFieldSummary'], isEmpty);
        expect(
          decoded['historyFocusSummary'],
          allOf(
            containsPair(
              'topScenario',
              allOf(
                containsPair(
                  'scenarioId',
                  'parser_admin_breaches_all_sites_v1',
                ),
                containsPair('failedCount', 0),
                containsPair('trend', 'clean'),
                containsPair('lastRunAt', isNotNull),
              ),
            ),
            containsPair(
              'topCategory',
              allOf(
                containsPair('category', 'admin_portfolio_read'),
                containsPair('failedCount', 0),
                containsPair('trend', 'clean'),
                containsPair('lastRunAt', isNotNull),
              ),
            ),
            containsPair(
              'topTag',
              allOf(
                containsPair('tag', 'admin_scope'),
                containsPair('failedCount', 0),
                containsPair('trend', 'clean'),
                containsPair('lastRunAt', isNotNull),
              ),
            ),
          ),
        );
        final cleanHistoryFocusSummary =
            decoded['historyFocusSummary'] as Map<String, dynamic>;
        expect(
          (cleanHistoryFocusSummary['topScenario'] as Map<String, dynamic>)
              .containsKey('topField'),
          isFalse,
        );
        expect(
          (cleanHistoryFocusSummary['topCategory'] as Map<String, dynamic>)
              .containsKey('topField'),
          isFalse,
        );
        expect(
          (cleanHistoryFocusSummary['topTag'] as Map<String, dynamic>)
              .containsKey('topField'),
          isFalse,
        );
        expect(
          decoded['historyCategorySummary'],
          containsPair(
            'admin_portfolio_read',
            allOf(
              containsPair('runCount', 1),
              containsPair('passedCount', 1),
              containsPair('failedCount', 0),
              containsPair('trend', 'clean'),
              containsPair('lastRunAt', isNotNull),
            ),
          ),
        );
        expect(
          decoded['historyTagSummary'],
          allOf(
            containsPair(
              'admin_scope',
              allOf(
                containsPair('runCount', 1),
                containsPair('passedCount', 1),
                containsPair('failedCount', 0),
                containsPair('trend', 'clean'),
              ),
            ),
            containsPair(
              'deterministic_read',
              allOf(
                containsPair('runCount', 1),
                containsPair('passedCount', 1),
                containsPair('failedCount', 0),
                containsPair('trend', 'clean'),
              ),
            ),
            containsPair(
              'multi_site',
              allOf(
                containsPair('runCount', 1),
                containsPair('passedCount', 1),
                containsPair('failedCount', 0),
                containsPair('trend', 'clean'),
              ),
            ),
          ),
        );
        expect(decoded['historyCategoryMismatchFieldSummary'], isEmpty);
        expect(decoded['historyCategoryMismatchFieldTrendSummary'], isEmpty);
        expect(decoded['historyTagMismatchFieldSummary'], isEmpty);
        expect(decoded['historyTagMismatchFieldTrendSummary'], isEmpty);
        expect(
          decoded['historyScenarioSummary'],
          containsPair(
            'parser_admin_breaches_all_sites_v1',
            allOf(
              containsPair('runCount', 1),
              containsPair('passedCount', 1),
              containsPair('failedCount', 0),
              containsPair('trend', 'clean'),
              containsPair('lastRunAt', isNotNull),
            ),
          ),
        );
        expect(decoded['historyScenarioMismatchFieldSummary'], isEmpty);
        expect(decoded['historyScenarioMismatchFieldTrendSummary'], isEmpty);
        expect(decoded['historyAlertSummary'], isEmpty);
        expect(decoded['historyAlertCategorySummary'], isEmpty);
        expect(decoded['historyAlertCategoryFieldSummary'], isEmpty);
        expect(decoded['historyAlertScenarioSummary'], isEmpty);
        expect(decoded['historyAlertScenarioFieldSummary'], isEmpty);
        expect(decoded['historyAlertFieldSummary'], isEmpty);
        expect(decoded['historyAlertTrendSummary'], isEmpty);
        expect(decoded['historyAlertScenarioSetSummary'], isEmpty);
        expect(decoded['historyAlertStatusSummary'], isEmpty);
        expect(decoded['historyAlertTagSummary'], isEmpty);
        expect(decoded['historyAlertTagFieldSummary'], isEmpty);
        expect(decoded['historyAlertPolicySummary'], isNull);
        expect(decoded['historyAlertPolicyTypeSummary'], isNull);
        expect(decoded['historyAlertPolicySuppressionSummary'], isNull);
        expect(decoded['historyAlertPolicySourceSummary'], isNull);
        expect(decoded['historyAlerts'], isEmpty);
        expect(decoded['historyAlertFocus'], isNull);

        final results = decoded['results'] as List<dynamic>;
        expect(results, hasLength(1));

        final runRecord = results.single as Map<String, dynamic>;
        expect(runRecord['scenarioId'], 'parser_admin_breaches_all_sites_v1');
        expect(runRecord['scenarioSet'], 'replay');
        expect(runRecord['passed'], isTrue);
        expect(runRecord['mismatchCount'], 0);
        expect(runRecord['mismatchFields'], isEmpty);

        final latestFiles = latestDirectory
            .listSync()
            .whereType<File>()
            .map((file) => file.path.split('/').last)
            .toList(growable: false);
        expect(
          latestFiles,
          contains('result_parser_admin_breaches_all_sites_v1.json'),
        );

        final historyFilePath = runRecord['historyFilePath'] as String?;
        expect(historyFilePath, isNotNull);
        expect(File(historyFilePath!).existsSync(), isTrue);
      } finally {
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool emits command brain timeline summaries for monitoring validation replay',
    () async {
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-brain-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-brain-history-',
      );

      try {
        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final result = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          'simulations/scenarios/monitoring/scenario_monitoring_priority_sequence_review_track_validation_v1.json',
        ], workingDirectory: Directory.current.path);

        expect(result.exitCode, 0, reason: '${result.stderr}');

        final stdoutText = result.stdout as String;
        final jsonStartIndex = stdoutText.indexOf('{');
        expect(jsonStartIndex, isNonNegative, reason: stdoutText);
        final decoded =
            jsonDecode(stdoutText.substring(jsonStartIndex))
                as Map<String, dynamic>;
        final results = decoded['results'] as List<dynamic>;
        expect(results, hasLength(1));

        final runRecord = results.single as Map<String, dynamic>;
        expect(runRecord['commandBrainFinalTarget'], 'tacticalTrack');
        expect(runRecord['commandBrainFinalMode'], 'deterministic');
        expect(runRecord['commandBrainFinalBiasSource'], 'replayPolicy');
        expect(runRecord['commandBrainFinalBiasScope'], 'sequenceFallback');
        expect(
          runRecord['commandBrainFinalBiasSignature'],
          'replayPolicy:sequenceFallback',
        );
        expect(runRecord['commandBrainFinalReplayBiasStackLength'], 1);
        expect(
          runRecord['commandBrainFinalReplayBiasStackSignature'],
          'replayPolicy:sequenceFallback:tacticalTrack',
        );
        expect(runRecord['sequenceFallbackLifecycle'], 'active_in_run');
        expect(
          runRecord['sequenceFallbackLifecycleSignature'],
          'active_in_run:replayPolicy:sequenceFallback:tacticalTrack',
        );
        expect(runRecord['commandBrainTimelineLength'], 2);
        expect(
          runRecord['commandBrainTimelineSignature'],
          'open_review_action:cctvReview -> open_track_handoff:tacticalTrack:replayPolicy:sequenceFallback',
        );

        expect(
          decoded['commandBrainTimelineSummary'],
          containsPair(
            'open_review_action:cctvReview -> open_track_handoff:tacticalTrack:replayPolicy:sequenceFallback',
            containsPair('passedCount', 1),
          ),
        );
        expect(
          decoded['historyCommandBrainFinalTargetSummary'],
          containsPair('tacticalTrack', containsPair('passedCount', 1)),
        );
        expect(
          decoded['commandBrainFinalBiasSourceSummary'],
          containsPair('replayPolicy', containsPair('passedCount', 1)),
        );
        expect(
          decoded['commandBrainFinalBiasScopeSummary'],
          containsPair('sequenceFallback', containsPair('passedCount', 1)),
        );
        expect(
          decoded['commandBrainFinalBiasSignatureSummary'],
          containsPair(
            'replayPolicy:sequenceFallback',
            containsPair('passedCount', 1),
          ),
        );
        expect(
          decoded['commandBrainFinalReplayBiasStackLengthSummary'],
          containsPair('1', containsPair('passedCount', 1)),
        );
        expect(
          decoded['commandBrainFinalReplayBiasStackSignatureSummary'],
          containsPair(
            'replayPolicy:sequenceFallback:tacticalTrack',
            containsPair('passedCount', 1),
          ),
        );
        expect(
          decoded['sequenceFallbackLifecycleSummary'],
          containsPair('active_in_run', containsPair('passedCount', 1)),
        );
        expect(
          decoded['sequenceFallbackLifecycleSignatureSummary'],
          containsPair(
            'active_in_run:replayPolicy:sequenceFallback:tacticalTrack',
            containsPair('passedCount', 1),
          ),
        );
        expect(
          decoded['historyCommandBrainFinalBiasSourceSummary'],
          containsPair('replayPolicy', containsPair('passedCount', 1)),
        );
        expect(
          decoded['historyCommandBrainFinalBiasScopeSummary'],
          containsPair('sequenceFallback', containsPair('passedCount', 1)),
        );
        expect(
          decoded['historyCommandBrainFinalBiasSignatureSummary'],
          containsPair(
            'replayPolicy:sequenceFallback',
            containsPair('passedCount', 1),
          ),
        );
        expect(
          decoded['historyCommandBrainFinalReplayBiasStackLengthSummary'],
          containsPair('1', containsPair('passedCount', 1)),
        );
        expect(
          decoded['historyCommandBrainFinalReplayBiasStackSignatureSummary'],
          containsPair(
            'replayPolicy:sequenceFallback:tacticalTrack',
            containsPair('passedCount', 1),
          ),
        );
        expect(
          decoded['historySequenceFallbackLifecycleSummary'],
          containsPair(
            'active_in_run',
            allOf(
              containsPair('scenarioCount', 1),
              containsPair('passedCount', 0),
              containsPair('failedCount', 1),
            ),
          ),
        );
        expect(
          decoded['historySequenceFallbackLifecycleSignatureSummary'],
          containsPair(
            'active_in_run:replayPolicy:sequenceFallback:tacticalTrack',
            containsPair('failedCount', 1),
          ),
        );
        expect(
          decoded['historyCommandBrainTimelineSummary'],
          containsPair(
            'open_review_action:cctvReview -> open_track_handoff:tacticalTrack:replayPolicy:sequenceFallback',
            containsPair('passedCount', 1),
          ),
        );
        expect(
          decoded['historyScenarioSequenceFallbackSummary'],
          containsPair(
            'monitoring_priority_sequence_review_track_validation_v1',
            isA<Map<String, dynamic>>(),
          ),
        );
        final historySequenceFallbackSummary =
            (decoded['historyScenarioSequenceFallbackSummary']
                    as Map<
                      String,
                      dynamic
                    >)['monitoring_priority_sequence_review_track_validation_v1']
                as Map<String, dynamic>;
        expect(historySequenceFallbackSummary['runCount'], 1);
        expect(historySequenceFallbackSummary['fallbackRunCount'], 1);
        expect(historySequenceFallbackSummary['clearedAfterRunCount'], 0);
        expect(historySequenceFallbackSummary['activeInRunCount'], 1);
        expect(historySequenceFallbackSummary['latestBranch'], 'active');
        expect(
          historySequenceFallbackSummary['latestLifecycle'],
          'active_in_run',
        );
        expect(
          historySequenceFallbackSummary['latestLifecycleSignature'],
          'active_in_run:replayPolicy:sequenceFallback:tacticalTrack',
        );
        expect(historySequenceFallbackSummary['latestTarget'], 'tacticalTrack');
        expect(historySequenceFallbackSummary['trend'], 'watch');
        expect(historySequenceFallbackSummary['recoveryTrend'], 'watch');
        expect(decoded['historyAlertSequenceFallbackSummary'], isEmpty);
      } finally {
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool raises direct command brain timeline alerts for monitoring validation drift',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-brain-alert-input-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-brain-alert-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-brain-alert-history-',
      );

      try {
        final sourceScenario = File(
          '${Directory.current.path}/simulations/scenarios/monitoring/scenario_monitoring_priority_sequence_review_track_validation_v1.json',
        );
        final baseScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        baseScenario['scenarioId'] =
            'parser_monitoring_priority_sequence_review_track_brain_alert_probe_v1';
        baseScenario['title'] =
            'Review to Track command brain timeline alert probe';
        void syncCommandBrainWorkItemIds(Map<String, dynamic> scenarioJson) {
          final scenarioId = scenarioJson['scenarioId']?.toString();
          final expectedOutcome = scenarioJson['expectedOutcome'];
          if (scenarioId == null ||
              scenarioId.isEmpty ||
              expectedOutcome is! Map<String, dynamic>) {
            return;
          }
          final commandBrainSnapshot = expectedOutcome['commandBrainSnapshot'];
          if (commandBrainSnapshot is Map<String, dynamic>) {
            commandBrainSnapshot['workItemId'] = scenarioId;
          }
          final commandBrainTimeline = expectedOutcome['commandBrainTimeline'];
          if (commandBrainTimeline is! List) {
            return;
          }
          for (final entry in commandBrainTimeline) {
            if (entry is! Map<String, dynamic>) {
              continue;
            }
            final snapshot = entry['snapshot'];
            if (snapshot is! Map<String, dynamic>) {
              continue;
            }
            snapshot['workItemId'] = scenarioId;
          }
        }

        syncCommandBrainWorkItemIds(baseScenario);

        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_monitoring_priority_sequence_review_track_brain_alert_probe_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(baseScenario),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final historyCommandArgs = <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ];
        final failOnAlertCommandArgs = <String>[
          ...historyCommandArgs,
          '--fail-on-alert=critical',
        ];

        final firstRun = await Process.run(
          dartExecutable,
          historyCommandArgs,
          workingDirectory: Directory.current.path,
        );
        expect(firstRun.exitCode, 0, reason: '${firstRun.stderr}');

        final failingScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        failingScenario['scenarioId'] =
            'parser_monitoring_priority_sequence_review_track_brain_alert_probe_v1';
        failingScenario['title'] =
            'Review to Track command brain timeline alert probe';
        syncCommandBrainWorkItemIds(failingScenario);
        final expectedOutcome =
            failingScenario['expectedOutcome'] as Map<String, dynamic>;
        final commandBrainTimeline =
            (expectedOutcome['commandBrainTimeline'] as List<dynamic>)
                .map((entry) => Map<String, dynamic>.from(entry as Map))
                .toList(growable: false);
        final finalEntry = Map<String, dynamic>.from(commandBrainTimeline.last);
        final finalSnapshot = Map<String, dynamic>.from(
          finalEntry['snapshot'] as Map,
        );
        finalEntry['stage'] = 'open_dispatch_handoff';
        finalEntry['note'] =
            'Dispatch handoff was expected before Track opened.';
        finalSnapshot['target'] = 'dispatchBoard';
        finalSnapshot['nextMoveLabel'] = 'OPEN DISPATCH BOARD';
        finalSnapshot['headline'] = 'Dispatch Board is the next move';
        finalSnapshot['summary'] = 'One next move is staged in Dispatch Board.';
        finalSnapshot['advisory'] =
            'Review evidence is staged and Dispatch Board is ready for controller ownership.';
        finalSnapshot['rationale'] =
            'Scenario replay preserved the live-ops sequence contract and handed the incident into Dispatch Board once availability stayed open.';
        finalSnapshot['supportingSpecialists'] = <String>['cctv', 'dispatch'];
        finalSnapshot.remove('decisionBias');
        finalEntry['snapshot'] = finalSnapshot;
        commandBrainTimeline[commandBrainTimeline.length - 1] = finalEntry;
        expectedOutcome['commandBrainTimeline'] = commandBrainTimeline;
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(failingScenario),
        );

        final secondRun = await Process.run(
          dartExecutable,
          failOnAlertCommandArgs,
          workingDirectory: Directory.current.path,
        );
        expect(secondRun.exitCode, 1, reason: '${secondRun.stderr}');

        final stdoutText = secondRun.stdout as String;
        final jsonStartIndex = stdoutText.indexOf('{');
        expect(jsonStartIndex, isNonNegative, reason: stdoutText);
        final decoded =
            jsonDecode(stdoutText.substring(jsonStartIndex))
                as Map<String, dynamic>;

        expect(decoded['historyAlertSummary'], containsPair('critical', 2));
        expect(
          decoded['historyAlertFieldSummary'],
          containsPair('commandBrainTimeline', 1),
        );
        expect(
          decoded['historyAlertScenarioFieldSummary'],
          containsPair(
            'parser_monitoring_priority_sequence_review_track_brain_alert_probe_v1',
            containsPair('commandBrainTimeline', 1),
          ),
        );
        expect(
          decoded['historyAlertCommandBrainTimelineSummary'],
          containsPair(
            'parser_monitoring_priority_sequence_review_track_brain_alert_probe_v1',
            allOf(
              containsPair('trend', 'worsening'),
              containsPair('severity', 'critical'),
              containsPair('count', 1),
              containsPair(
                'expectedTimelineSignature',
                'open_review_action:cctvReview -> open_dispatch_handoff:dispatchBoard:replayPolicy:sequenceFallback',
              ),
              containsPair(
                'actualTimelineSignature',
                'open_review_action:cctvReview -> open_track_handoff:tacticalTrack:replayPolicy:sequenceFallback',
              ),
              containsPair('expectedFinalTarget', 'tacticalTrack'),
              containsPair('actualFinalTarget', 'tacticalTrack'),
            ),
          ),
        );

        final historyAlertFocus =
            decoded['historyAlertFocus'] as Map<String, dynamic>;
        expect(historyAlertFocus['scope'], 'command_brain_timeline');
        expect(historyAlertFocus['field'], 'commandBrainTimeline');
        expect(
          historyAlertFocus['expectedCommandBrainTimelineSignature'],
          'open_review_action:cctvReview -> open_dispatch_handoff:dispatchBoard:replayPolicy:sequenceFallback',
        );
        expect(
          historyAlertFocus['actualCommandBrainTimelineSignature'],
          'open_review_action:cctvReview -> open_track_handoff:tacticalTrack:replayPolicy:sequenceFallback',
        );

        expect(decoded['alertFailureTriggered'], isTrue);
        expect(decoded['alertFailureCount'], 2);
        expect(decoded['alertFailureSummary'], containsPair('critical', 2));
        expect(
          decoded['alertFailureCommandBrainTimelineSummary'],
          containsPair(
            'parser_monitoring_priority_sequence_review_track_brain_alert_probe_v1',
            containsPair('expectedFinalTarget', 'tacticalTrack'),
          ),
        );
        final alertFailureFocus =
            decoded['alertFailureFocus'] as Map<String, dynamic>;
        expect(alertFailureFocus['scope'], 'command_brain_timeline');
        expect(alertFailureFocus['field'], 'commandBrainTimeline');

        final alerts = decoded['historyAlerts'] as List<dynamic>;
        expect(
          alerts,
          contains(
            allOf(
              containsPair('severity', 'critical'),
              containsPair('scope', 'command_brain_timeline'),
              containsPair(
                'scenarioId',
                'parser_monitoring_priority_sequence_review_track_brain_alert_probe_v1',
              ),
              containsPair('field', 'commandBrainTimeline'),
              containsPair('trend', 'worsening'),
            ),
          ),
        );
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool raises direct command brain replay bias stack alerts for stacked pressure drift',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-stack-alert-input-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-stack-alert-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-stack-alert-history-',
      );

      try {
        final baseScenario = await loadScenarioFixture(
          'simulations/scenarios/monitoring/scenario_monitoring_priority_sequence_review_track_conflict_validation_v1.json',
          scenarioId:
              'parser_monitoring_priority_sequence_review_track_stack_alert_probe_v1',
          title: 'Review to Track replay bias stack alert probe',
        );
        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_monitoring_priority_sequence_review_track_stack_alert_probe_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(baseScenario),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final historyCommandArgs = <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ];
        final failOnAlertCommandArgs = <String>[
          ...historyCommandArgs,
          '--fail-on-alert=critical',
        ];

        final firstRun = await Process.run(
          dartExecutable,
          historyCommandArgs,
          workingDirectory: Directory.current.path,
        );
        expect(firstRun.exitCode, 0, reason: '${firstRun.stderr}');

        final failingScenario = await loadScenarioFixture(
          'simulations/scenarios/monitoring/scenario_monitoring_priority_sequence_review_track_conflict_validation_v1.json',
          scenarioId:
              'parser_monitoring_priority_sequence_review_track_stack_alert_probe_v1',
          title: 'Review to Track replay bias stack alert probe',
        );
        final expectedOutcome =
            failingScenario['expectedOutcome'] as Map<String, dynamic>;
        final commandBrainSnapshot =
            expectedOutcome['commandBrainSnapshot'] as Map<String, dynamic>;
        commandBrainSnapshot['replayBiasStack'] = <dynamic>[
          Map<String, dynamic>.from(
            commandBrainSnapshot['decisionBias'] as Map<String, dynamic>,
          ),
        ];
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(failingScenario),
        );

        final secondRun = await Process.run(
          dartExecutable,
          failOnAlertCommandArgs,
          workingDirectory: Directory.current.path,
        );
        expect(secondRun.exitCode, 1, reason: '${secondRun.stderr}');

        final stdoutText = secondRun.stdout as String;
        final jsonStartIndex = stdoutText.indexOf('{');
        expect(jsonStartIndex, isNonNegative, reason: stdoutText);
        final decoded =
            jsonDecode(stdoutText.substring(jsonStartIndex))
                as Map<String, dynamic>;

        expect(decoded['historyAlertSummary'], containsPair('critical', 3));
        expect(
          decoded['historyAlertFieldSummary'],
          allOf(
            containsPair('commandBrainReplayBiasStack', 1),
            containsPair('commandBrainSnapshot', 1),
            isNot(containsPair('commandBrainTimeline', anything)),
          ),
        );
        expect(
          decoded['historyAlertScenarioFieldSummary'],
          containsPair(
            'parser_monitoring_priority_sequence_review_track_stack_alert_probe_v1',
            containsPair('commandBrainReplayBiasStack', 1),
          ),
        );
        expect(
          decoded['historyAlertCommandBrainReplayBiasStackSummary'],
          containsPair(
            'parser_monitoring_priority_sequence_review_track_stack_alert_probe_v1',
            allOf(
              containsPair('trend', 'worsening'),
              containsPair('severity', 'critical'),
              containsPair('count', 1),
              containsPair(
                'expectedReplayBiasStackSignature',
                'replayPolicy:sequenceFallback:tacticalTrack',
              ),
              containsPair(
                'actualReplayBiasStackSignature',
                'replayPolicy:sequenceFallback:tacticalTrack -> replayPolicy:specialistConflict:cctvReview',
              ),
              containsPair('expectedFinalTarget', 'tacticalTrack'),
              containsPair('actualFinalTarget', 'tacticalTrack'),
            ),
          ),
        );

        final historyAlertFocus =
            decoded['historyAlertFocus'] as Map<String, dynamic>;
        expect(historyAlertFocus['scope'], 'command_brain_replay_bias_stack');
        expect(historyAlertFocus['field'], 'commandBrainReplayBiasStack');
        expect(
          historyAlertFocus['expectedCommandBrainReplayBiasStackSignature'],
          'replayPolicy:sequenceFallback:tacticalTrack',
        );
        expect(
          historyAlertFocus['actualCommandBrainReplayBiasStackSignature'],
          'replayPolicy:sequenceFallback:tacticalTrack -> replayPolicy:specialistConflict:cctvReview',
        );
        expect(
          historyAlertFocus['expectedCommandBrainFinalTarget'],
          'tacticalTrack',
        );
        expect(
          historyAlertFocus['actualCommandBrainFinalTarget'],
          'tacticalTrack',
        );

        expect(decoded['alertFailureTriggered'], isTrue);
        expect(decoded['alertFailureCount'], 3);
        expect(decoded['alertFailureSummary'], containsPair('critical', 3));
        expect(
          decoded['alertFailureCommandBrainReplayBiasStackSummary'],
          containsPair(
            'parser_monitoring_priority_sequence_review_track_stack_alert_probe_v1',
            containsPair('expectedFinalTarget', 'tacticalTrack'),
          ),
        );
        final alertFailureFocus =
            decoded['alertFailureFocus'] as Map<String, dynamic>;
        expect(
          alertFailureFocus['scope'],
          'command_brain_replay_bias_stack',
        );
        expect(alertFailureFocus['field'], 'commandBrainReplayBiasStack');
        expect(
          alertFailureFocus['expectedCommandBrainFinalTarget'],
          'tacticalTrack',
        );
        expect(
          alertFailureFocus['actualCommandBrainFinalTarget'],
          'tacticalTrack',
        );

        final alerts = decoded['historyAlerts'] as List<dynamic>;
        expect(
          alerts,
          contains(
            allOf(
              containsPair('severity', 'critical'),
              containsPair('scope', 'command_brain_replay_bias_stack'),
              containsPair(
                'scenarioId',
                'parser_monitoring_priority_sequence_review_track_stack_alert_probe_v1',
              ),
              containsPair('field', 'commandBrainReplayBiasStack'),
              containsPair('trend', 'worsening'),
            ),
          ),
        );
        expect(
          alerts,
          isNot(
            contains(
              allOf(
                containsPair('scope', 'command_brain_timeline'),
                containsPair('scenarioId',
                    'parser_monitoring_priority_sequence_review_track_stack_alert_probe_v1'),
              ),
            ),
          ),
        );
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool aggregates history rollups by category across repeated runs',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-history-input-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-history-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-history-history-',
      );

      try {
        final sourceScenario = File(
          '${Directory.current.path}/simulations/scenarios/admin/scenario_admin_breaches_all_sites_v1.json',
        );
        final scenarioJson =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        scenarioJson['scenarioId'] =
            'parser_admin_breaches_all_sites_history_probe_v1';
        scenarioJson['title'] = 'Breaches across all sites history probe';
        final expectedOutcome =
            scenarioJson['expectedOutcome'] as Map<String, dynamic>;
        expectedOutcome['expectedRoute'] = 'admin_wrong_route';
        expectedOutcome['expectedUiState'] = <String, dynamic>{
          'surface': 'admin_wrong_surface',
          'legacyWorkspaceVisible': false,
        };

        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_admin_breaches_all_sites_history_probe_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(scenarioJson),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final commandArgs = <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ];

        final firstRun = await Process.run(
          dartExecutable,
          commandArgs,
          workingDirectory: Directory.current.path,
        );
        expect(firstRun.exitCode, 1, reason: '${firstRun.stderr}');

        final secondRun = await Process.run(
          dartExecutable,
          commandArgs,
          workingDirectory: Directory.current.path,
        );
        expect(secondRun.exitCode, 1, reason: '${secondRun.stderr}');

        final stdoutText = secondRun.stdout as String;
        final jsonStartIndex = stdoutText.indexOf('{');
        expect(jsonStartIndex, isNonNegative, reason: stdoutText);
        final decoded =
            jsonDecode(stdoutText.substring(jsonStartIndex))
                as Map<String, dynamic>;

        expect(
          decoded['historyFocusSummary'],
          allOf(
            containsPair(
              'topScenario',
              allOf(
                containsPair(
                  'scenarioId',
                  'parser_admin_breaches_all_sites_history_probe_v1',
                ),
                containsPair('failedCount', 2),
                containsPair('trend', 'stabilizing'),
                containsPair('lastRunAt', isNotNull),
              ),
            ),
            containsPair(
              'topCategory',
              allOf(
                containsPair('category', 'admin_portfolio_read'),
                containsPair('failedCount', 2),
                containsPair('trend', 'stabilizing'),
                containsPair('lastRunAt', isNotNull),
              ),
            ),
            containsPair(
              'topTag',
              allOf(
                containsPair('tag', 'admin_scope'),
                containsPair('failedCount', 2),
                containsPair('trend', 'stabilizing'),
                containsPair('lastRunAt', isNotNull),
              ),
            ),
          ),
        );
        final repeatedHistoryFocusSummary =
            decoded['historyFocusSummary'] as Map<String, dynamic>;
        final expectedTopFieldMatcher = allOf(
          containsPair('field', 'expectedUiState'),
          containsPair('count', 2),
          containsPair('trend', 'stabilizing'),
        );
        expect(
          (repeatedHistoryFocusSummary['topScenario']
              as Map<String, dynamic>)['topField'],
          expectedTopFieldMatcher,
        );
        expect(
          (repeatedHistoryFocusSummary['topCategory']
              as Map<String, dynamic>)['topField'],
          expectedTopFieldMatcher,
        );
        expect(
          (repeatedHistoryFocusSummary['topTag']
              as Map<String, dynamic>)['topField'],
          expectedTopFieldMatcher,
        );
        expect(
          decoded['historyCategorySummary'],
          containsPair(
            'admin_portfolio_read',
            allOf(
              containsPair('runCount', 2),
              containsPair('passedCount', 0),
              containsPair('failedCount', 2),
              containsPair('trend', 'stabilizing'),
              containsPair('lastRunAt', isNotNull),
            ),
          ),
        );
        expect(
          decoded['historyCategoryMismatchFieldSummary'],
          containsPair(
            'admin_portfolio_read',
            allOf(
              containsPair('expectedRoute', 2),
              containsPair('expectedUiState', 2),
            ),
          ),
        );
        expect(
          decoded['historyCategoryMismatchFieldTrendSummary'],
          containsPair(
            'admin_portfolio_read',
            allOf(
              containsPair(
                'expectedRoute',
                allOf(
                  containsPair('count', 2),
                  containsPair('trend', 'stabilizing'),
                ),
              ),
              containsPair(
                'expectedUiState',
                allOf(
                  containsPair('count', 2),
                  containsPair('trend', 'stabilizing'),
                ),
              ),
            ),
          ),
        );
        expect(
          decoded['historyTagSummary'],
          allOf(
            containsPair(
              'admin_scope',
              allOf(
                containsPair('runCount', 2),
                containsPair('passedCount', 0),
                containsPair('failedCount', 2),
                containsPair('trend', 'stabilizing'),
              ),
            ),
            containsPair(
              'deterministic_read',
              allOf(
                containsPair('runCount', 2),
                containsPair('passedCount', 0),
                containsPair('failedCount', 2),
                containsPair('trend', 'stabilizing'),
              ),
            ),
            containsPair(
              'multi_site',
              allOf(
                containsPair('runCount', 2),
                containsPair('passedCount', 0),
                containsPair('failedCount', 2),
                containsPair('trend', 'stabilizing'),
              ),
            ),
          ),
        );
        expect(
          decoded['historyTagMismatchFieldSummary'],
          allOf(
            containsPair(
              'admin_scope',
              allOf(
                containsPair('expectedRoute', 2),
                containsPair('expectedUiState', 2),
              ),
            ),
            containsPair(
              'deterministic_read',
              allOf(
                containsPair('expectedRoute', 2),
                containsPair('expectedUiState', 2),
              ),
            ),
            containsPair(
              'multi_site',
              allOf(
                containsPair('expectedRoute', 2),
                containsPair('expectedUiState', 2),
              ),
            ),
          ),
        );
        expect(
          decoded['historyTagMismatchFieldTrendSummary'],
          allOf(
            containsPair(
              'admin_scope',
              allOf(
                containsPair(
                  'expectedRoute',
                  allOf(
                    containsPair('count', 2),
                    containsPair('trend', 'stabilizing'),
                  ),
                ),
                containsPair(
                  'expectedUiState',
                  allOf(
                    containsPair('count', 2),
                    containsPair('trend', 'stabilizing'),
                  ),
                ),
              ),
            ),
            containsPair(
              'deterministic_read',
              allOf(
                containsPair(
                  'expectedRoute',
                  allOf(
                    containsPair('count', 2),
                    containsPair('trend', 'stabilizing'),
                  ),
                ),
                containsPair(
                  'expectedUiState',
                  allOf(
                    containsPair('count', 2),
                    containsPair('trend', 'stabilizing'),
                  ),
                ),
              ),
            ),
            containsPair(
              'multi_site',
              allOf(
                containsPair(
                  'expectedRoute',
                  allOf(
                    containsPair('count', 2),
                    containsPair('trend', 'stabilizing'),
                  ),
                ),
                containsPair(
                  'expectedUiState',
                  allOf(
                    containsPair('count', 2),
                    containsPair('trend', 'stabilizing'),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(
          decoded['historyScenarioSummary'],
          containsPair(
            'parser_admin_breaches_all_sites_history_probe_v1',
            allOf(
              containsPair('runCount', 2),
              containsPair('passedCount', 0),
              containsPair('failedCount', 2),
              containsPair('trend', 'stabilizing'),
              containsPair('lastRunAt', isNotNull),
            ),
          ),
        );
        expect(
          decoded['historyScenarioMismatchFieldSummary'],
          containsPair(
            'parser_admin_breaches_all_sites_history_probe_v1',
            allOf(
              containsPair('expectedRoute', 2),
              containsPair('expectedUiState', 2),
            ),
          ),
        );
        expect(
          decoded['historyScenarioMismatchFieldTrendSummary'],
          containsPair(
            'parser_admin_breaches_all_sites_history_probe_v1',
            allOf(
              containsPair(
                'expectedRoute',
                allOf(
                  containsPair('count', 2),
                  containsPair('trend', 'stabilizing'),
                ),
              ),
              containsPair(
                'expectedUiState',
                allOf(
                  containsPair('count', 2),
                  containsPair('trend', 'stabilizing'),
                ),
              ),
            ),
          ),
        );
        expect(
          decoded['historyAlertTrendSummary'],
          containsPair('stabilizing', 3),
        );

        final historyFiles = historyDirectory
            .listSync()
            .whereType<File>()
            .map((file) => file.path.split('/').last)
            .toList(growable: false);
        expect(historyFiles.length, 2);
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool prefers higher-severity mismatch fields in history focus when counts tie',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-severity-input-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-severity-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-severity-history-',
      );

      try {
        final sourceScenario = File(
          '${Directory.current.path}/simulations/scenarios/admin/scenario_admin_breaches_all_sites_v1.json',
        );
        final scenarioJson =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        scenarioJson['scenarioId'] =
            'parser_admin_breaches_all_sites_escalation_focus_probe_v1';
        scenarioJson['title'] =
            'Breaches across all sites escalation focus probe';
        final expectedOutcome =
            scenarioJson['expectedOutcome'] as Map<String, dynamic>;
        expectedOutcome['expectedRoute'] = 'admin_wrong_route';
        expectedOutcome['expectedEscalationState'] = 'major';

        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_admin_breaches_all_sites_escalation_focus_probe_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(scenarioJson),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final commandArgs = <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ];

        final firstRun = await Process.run(
          dartExecutable,
          commandArgs,
          workingDirectory: Directory.current.path,
        );
        expect(firstRun.exitCode, 1, reason: '${firstRun.stderr}');

        final secondRun = await Process.run(
          dartExecutable,
          commandArgs,
          workingDirectory: Directory.current.path,
        );
        expect(secondRun.exitCode, 1, reason: '${secondRun.stderr}');

        final stdoutText = secondRun.stdout as String;
        final jsonStartIndex = stdoutText.indexOf('{');
        expect(jsonStartIndex, isNonNegative, reason: stdoutText);
        final decoded =
            jsonDecode(stdoutText.substring(jsonStartIndex))
                as Map<String, dynamic>;
        final repeatedHistoryFocusSummary =
            decoded['historyFocusSummary'] as Map<String, dynamic>;
        final expectedTopFieldMatcher = allOf(
          containsPair('field', 'expectedEscalationState'),
          containsPair('count', 2),
          containsPair('trend', 'stabilizing'),
        );
        expect(
          (repeatedHistoryFocusSummary['topScenario']
              as Map<String, dynamic>)['topField'],
          expectedTopFieldMatcher,
        );
        expect(
          (repeatedHistoryFocusSummary['topCategory']
              as Map<String, dynamic>)['topField'],
          expectedTopFieldMatcher,
        );
        expect(
          (repeatedHistoryFocusSummary['topTag']
              as Map<String, dynamic>)['topField'],
          expectedTopFieldMatcher,
        );
        final scenarioAlerts = (decoded['historyAlerts'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .where(
              (alert) =>
                  alert['scenarioId'] ==
                  'parser_admin_breaches_all_sites_escalation_focus_probe_v1',
            )
            .toList(growable: false);
        expect(scenarioAlerts, hasLength(3));
        expect(
          decoded['historyAlertFocus'],
          allOf(
            containsPair('scope', 'scenario_field'),
            containsPair(
              'scenarioId',
              'parser_admin_breaches_all_sites_escalation_focus_probe_v1',
            ),
            containsPair('field', 'expectedEscalationState'),
            containsPair('trend', 'stabilizing'),
            containsPair('severity', 'low'),
            containsPair('count', 2),
          ),
        );
        expect(
          scenarioAlerts[0],
          allOf(
            containsPair('scope', 'scenario'),
            containsPair('trend', 'stabilizing'),
          ),
        );
        expect(
          scenarioAlerts[1],
          allOf(
            containsPair('scope', 'scenario_field'),
            containsPair('field', 'expectedEscalationState'),
            containsPair('trend', 'stabilizing'),
          ),
        );
        expect(
          scenarioAlerts[2],
          allOf(
            containsPair('scope', 'scenario_field'),
            containsPair('field', 'expectedRoute'),
            containsPair('trend', 'stabilizing'),
          ),
        );
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool surfaces the highest-priority blocking field in alert failure focus',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-alert-focus-input-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-alert-focus-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-alert-focus-history-',
      );

      try {
        final sourceScenario = File(
          '${Directory.current.path}/simulations/scenarios/admin/scenario_admin_breaches_all_sites_v1.json',
        );
        final scenarioJson =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        scenarioJson['scenarioId'] =
            'parser_admin_breaches_all_sites_alert_focus_probe_v1';
        scenarioJson['title'] = 'Breaches across all sites alert focus probe';
        final expectedOutcome =
            scenarioJson['expectedOutcome'] as Map<String, dynamic>;
        expectedOutcome['expectedRoute'] = 'admin_wrong_route';
        expectedOutcome['expectedEscalationState'] = 'major';

        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_admin_breaches_all_sites_alert_focus_probe_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(scenarioJson),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final commandArgs = <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--fail-on-alert=low',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ];

        final firstRun = await Process.run(
          dartExecutable,
          commandArgs,
          workingDirectory: Directory.current.path,
        );
        expect(firstRun.exitCode, 1, reason: '${firstRun.stderr}');

        final secondRun = await Process.run(
          dartExecutable,
          commandArgs,
          workingDirectory: Directory.current.path,
        );
        expect(secondRun.exitCode, 1, reason: '${secondRun.stderr}');

        final stdoutText = secondRun.stdout as String;
        final jsonStartIndex = stdoutText.indexOf('{');
        expect(jsonStartIndex, isNonNegative, reason: stdoutText);
        final decoded =
            jsonDecode(stdoutText.substring(jsonStartIndex))
                as Map<String, dynamic>;

        expect(decoded['alertFailureTriggered'], isTrue);
        expect(decoded['alertFailureCount'], 3);
        expect(decoded['alertFailureSummary'], containsPair('low', 3));
        expect(
          decoded['alertFailureFocus'],
          allOf(
            containsPair('scope', 'scenario_field'),
            containsPair(
              'scenarioId',
              'parser_admin_breaches_all_sites_alert_focus_probe_v1',
            ),
            containsPair('field', 'expectedEscalationState'),
            containsPair('severity', 'low'),
            containsPair('trend', 'stabilizing'),
            containsPair('count', 2),
          ),
        );
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool marks history as worsening when a scenario regresses after a clean pass',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-worsening-input-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-worsening-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-worsening-history-',
      );

      try {
        final sourceScenario = File(
          '${Directory.current.path}/simulations/scenarios/admin/scenario_admin_breaches_all_sites_v1.json',
        );
        final baseScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        baseScenario['scenarioId'] =
            'parser_admin_breaches_all_sites_worsening_probe_v1';
        baseScenario['title'] = 'Breaches across all sites worsening probe';

        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_admin_breaches_all_sites_worsening_probe_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(baseScenario),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final commandArgs = <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ];

        final firstRun = await Process.run(
          dartExecutable,
          commandArgs,
          workingDirectory: Directory.current.path,
        );
        expect(firstRun.exitCode, 0, reason: '${firstRun.stderr}');

        final failingScenario =
            jsonDecode(const JsonEncoder.withIndent('  ').convert(baseScenario))
                as Map<String, dynamic>;
        final expectedOutcome =
            failingScenario['expectedOutcome'] as Map<String, dynamic>;
        expectedOutcome['expectedRoute'] = 'admin_wrong_route';
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(failingScenario),
        );

        final secondRun = await Process.run(
          dartExecutable,
          commandArgs,
          workingDirectory: Directory.current.path,
        );
        expect(secondRun.exitCode, 1, reason: '${secondRun.stderr}');

        final stdoutText = secondRun.stdout as String;
        final jsonStartIndex = stdoutText.indexOf('{');
        expect(jsonStartIndex, isNonNegative, reason: stdoutText);
        final decoded =
            jsonDecode(stdoutText.substring(jsonStartIndex))
                as Map<String, dynamic>;

        expect(
          decoded['historyCategorySummary'],
          containsPair(
            'admin_portfolio_read',
            allOf(
              containsPair('runCount', 2),
              containsPair('passedCount', 1),
              containsPair('failedCount', 1),
              containsPair('trend', 'worsening'),
            ),
          ),
        );
        expect(
          decoded['historyCategoryMismatchFieldTrendSummary'],
          containsPair(
            'admin_portfolio_read',
            containsPair(
              'expectedRoute',
              allOf(
                containsPair('count', 1),
                containsPair('trend', 'worsening'),
              ),
            ),
          ),
        );
        expect(
          decoded['historyScenarioSummary'],
          containsPair(
            'parser_admin_breaches_all_sites_worsening_probe_v1',
            allOf(
              containsPair('runCount', 2),
              containsPair('passedCount', 1),
              containsPair('failedCount', 1),
              containsPair('trend', 'worsening'),
            ),
          ),
        );
        expect(
          decoded['historyScenarioMismatchFieldTrendSummary'],
          containsPair(
            'parser_admin_breaches_all_sites_worsening_probe_v1',
            containsPair(
              'expectedRoute',
              allOf(
                containsPair('count', 1),
                containsPair('trend', 'worsening'),
              ),
            ),
          ),
        );
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool raises critical history alerts for locked validation regressions',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-locked-alert-input-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-locked-alert-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-locked-alert-history-',
      );

      try {
        final sourceScenario = File(
          '${Directory.current.path}/simulations/scenarios/admin/scenario_admin_breaches_all_sites_validation_v1.json',
        );
        final baseScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        baseScenario['scenarioId'] =
            'parser_admin_breaches_all_sites_validation_alert_probe_v1';
        baseScenario['title'] =
            'Breaches across all sites locked validation alert probe';

        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_admin_breaches_all_sites_validation_alert_probe_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(baseScenario),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final commandArgs = <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ];

        final firstRun = await Process.run(
          dartExecutable,
          commandArgs,
          workingDirectory: Directory.current.path,
        );
        expect(firstRun.exitCode, 0, reason: '${firstRun.stderr}');

        final failingScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        failingScenario['scenarioId'] =
            'parser_admin_breaches_all_sites_validation_alert_probe_v1';
        failingScenario['title'] =
            'Breaches across all sites locked validation alert probe';
        final expectedOutcome =
            failingScenario['expectedOutcome'] as Map<String, dynamic>;
        expectedOutcome['expectedRoute'] = 'admin_wrong_route';
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(failingScenario),
        );

        final secondRun = await Process.run(
          dartExecutable,
          commandArgs,
          workingDirectory: Directory.current.path,
        );
        expect(secondRun.exitCode, 1, reason: '${secondRun.stderr}');

        final stdoutText = secondRun.stdout as String;
        final jsonStartIndex = stdoutText.indexOf('{');
        expect(jsonStartIndex, isNonNegative, reason: stdoutText);
        final decoded =
            jsonDecode(stdoutText.substring(jsonStartIndex))
                as Map<String, dynamic>;

        expect(decoded['historyAlertSummary'], containsPair('critical', 2));
        expect(
          decoded['historyAlertCategorySummary'],
          containsPair('admin_portfolio_read', 2),
        );
        expect(
          decoded['historyAlertCategoryFieldSummary'],
          containsPair(
            'admin_portfolio_read',
            containsPair('expectedRoute', 1),
          ),
        );
        expect(
          decoded['historyAlertScenarioSummary'],
          containsPair(
            'parser_admin_breaches_all_sites_validation_alert_probe_v1',
            2,
          ),
        );
        expect(
          decoded['historyAlertScenarioFieldSummary'],
          containsPair(
            'parser_admin_breaches_all_sites_validation_alert_probe_v1',
            containsPair('expectedRoute', 1),
          ),
        );
        expect(
          decoded['historyAlertFieldSummary'],
          containsPair('expectedRoute', 1),
        );
        expect(
          decoded['historyAlertScenarioSetSummary'],
          containsPair('validation', 2),
        );
        expect(
          decoded['historyAlertStatusSummary'],
          containsPair('locked_validation', 2),
        );
        expect(
          decoded['historyAlertTagSummary'],
          allOf(
            containsPair('admin_scope', 2),
            containsPair('deterministic_read', 2),
            containsPair('multi_site', 2),
          ),
        );
        expect(
          decoded['historyAlertTagFieldSummary'],
          allOf(
            containsPair('admin_scope', containsPair('expectedRoute', 1)),
            containsPair(
              'deterministic_read',
              containsPair('expectedRoute', 1),
            ),
            containsPair('multi_site', containsPair('expectedRoute', 1)),
          ),
        );

        final alerts = decoded['historyAlerts'] as List<dynamic>;
        expect(
          alerts,
          contains(
            allOf(
              containsPair('severity', 'critical'),
              containsPair('scope', 'scenario'),
              containsPair(
                'scenarioId',
                'parser_admin_breaches_all_sites_validation_alert_probe_v1',
              ),
              containsPair('scenarioSet', 'validation'),
              containsPair('status', 'locked_validation'),
              containsPair('trend', 'worsening'),
            ),
          ),
        );
        expect(
          alerts,
          contains(
            allOf(
              containsPair('severity', 'critical'),
              containsPair('scope', 'scenario_field'),
              containsPair(
                'scenarioId',
                'parser_admin_breaches_all_sites_validation_alert_probe_v1',
              ),
              containsPair('field', 'expectedRoute'),
              containsPair('trend', 'worsening'),
            ),
          ),
        );
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool can fail on critical history alerts even when the current run passes',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-alert-threshold-input-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-alert-threshold-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-alert-threshold-history-',
      );

      try {
        final sourceScenario = File(
          '${Directory.current.path}/simulations/scenarios/admin/scenario_admin_breaches_all_sites_validation_v1.json',
        );
        final failingScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        failingScenario['scenarioId'] =
            'parser_admin_breaches_all_sites_alert_threshold_probe_v1';
        failingScenario['title'] =
            'Breaches across all sites alert threshold probe';
        final failingExpectedOutcome =
            failingScenario['expectedOutcome'] as Map<String, dynamic>;
        failingExpectedOutcome['expectedRoute'] = 'admin_wrong_route';

        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_admin_breaches_all_sites_alert_threshold_probe_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(failingScenario),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final seedHistoryResult = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(
          seedHistoryResult.exitCode,
          1,
          reason: '${seedHistoryResult.stderr}',
        );

        final repairedScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        repairedScenario['scenarioId'] =
            'parser_admin_breaches_all_sites_alert_threshold_probe_v1';
        repairedScenario['title'] =
            'Breaches across all sites alert threshold probe';
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(repairedScenario),
        );

        final gatedRun = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--fail-on-alert=critical',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(gatedRun.exitCode, 1, reason: '${gatedRun.stderr}');

        final stdoutText = gatedRun.stdout as String;
        final jsonStartIndex = stdoutText.indexOf('{');
        expect(jsonStartIndex, isNonNegative, reason: stdoutText);
        final decoded =
            jsonDecode(stdoutText.substring(jsonStartIndex))
                as Map<String, dynamic>;

        expect(decoded['passedCount'], 1);
        expect(decoded['failedCount'], 0);
        expect(decoded['alertFailureThreshold'], 'critical');
        expect(decoded['alertFailureTriggered'], isTrue);
        expect(decoded['alertFailureCount'], 2);
        expect(decoded['alertFailureSummary'], containsPair('critical', 2));
        expect(decoded['historyAlertSummary'], containsPair('critical', 2));
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool scopes alert failure gating to a matching category',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-alert-category-input-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-alert-category-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-alert-category-history-',
      );

      try {
        final sourceScenario = File(
          '${Directory.current.path}/simulations/scenarios/admin/scenario_admin_breaches_all_sites_validation_v1.json',
        );
        final failingScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        failingScenario['scenarioId'] =
            'parser_admin_breaches_all_sites_alert_category_probe_v1';
        failingScenario['title'] =
            'Breaches across all sites alert category probe';
        final failingExpectedOutcome =
            failingScenario['expectedOutcome'] as Map<String, dynamic>;
        failingExpectedOutcome['expectedRoute'] = 'admin_wrong_route';

        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_admin_breaches_all_sites_alert_category_probe_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(failingScenario),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final seedHistoryResult = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(
          seedHistoryResult.exitCode,
          1,
          reason: '${seedHistoryResult.stderr}',
        );

        final repairedScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        repairedScenario['scenarioId'] =
            'parser_admin_breaches_all_sites_alert_category_probe_v1';
        repairedScenario['title'] =
            'Breaches across all sites alert category probe';
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(repairedScenario),
        );

        final nonMatchingRun = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--fail-on-alert=critical',
          '--fail-on-category=monitoring_watch',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(nonMatchingRun.exitCode, 0, reason: '${nonMatchingRun.stderr}');

        final nonMatchingDecoded =
            jsonDecode(
                  (nonMatchingRun.stdout as String).substring(
                    (nonMatchingRun.stdout as String).indexOf('{'),
                  ),
                )
                as Map<String, dynamic>;
        expect(
          nonMatchingDecoded['alertFailureCategoryFilter'],
          'monitoring_watch',
        );
        expect(nonMatchingDecoded['alertFailureTriggered'], isFalse);
        expect(nonMatchingDecoded['alertFailureCount'], 0);
        expect(nonMatchingDecoded['alertFailureSummary'], isEmpty);
        expect(nonMatchingDecoded['alertFailureCategoryFocus'], isNull);
        expect(nonMatchingDecoded['historyAlertCategoryFocus'], isNull);

        final matchingRun = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--fail-on-alert=critical',
          '--fail-on-category=admin_portfolio_read',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(matchingRun.exitCode, 1, reason: '${matchingRun.stderr}');

        final matchingDecoded =
            jsonDecode(
                  (matchingRun.stdout as String).substring(
                    (matchingRun.stdout as String).indexOf('{'),
                  ),
                )
                as Map<String, dynamic>;
        expect(
          matchingDecoded['alertFailureCategoryFilter'],
          'admin_portfolio_read',
        );
        expect(matchingDecoded['alertFailureTriggered'], isTrue);
        expect(matchingDecoded['alertFailureCount'], 2);
        expect(
          matchingDecoded['alertFailureSummary'],
          containsPair('critical', 2),
        );
        expect(
          matchingDecoded['alertFailureCategoryFocus'],
          allOf(
            containsPair('category', 'admin_portfolio_read'),
            containsPair('scope', 'scenario_field'),
            containsPair(
              'scenarioId',
              'parser_admin_breaches_all_sites_alert_category_probe_v1',
            ),
            containsPair('field', 'expectedRoute'),
            containsPair('severity', 'critical'),
            containsPair('trend', 'watch'),
            containsPair('count', 1),
          ),
        );
        expect(
          matchingDecoded['historyAlertCategoryFocus'],
          allOf(
            containsPair('category', 'admin_portfolio_read'),
            containsPair('scope', 'scenario_field'),
            containsPair(
              'scenarioId',
              'parser_admin_breaches_all_sites_alert_category_probe_v1',
            ),
            containsPair('field', 'expectedRoute'),
            containsPair('severity', 'critical'),
            containsPair('trend', 'watch'),
            containsPair('count', 1),
          ),
        );
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool scopes alert failure gating to a matching status',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-alert-status-input-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-alert-status-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-alert-status-history-',
      );

      try {
        final sourceScenario = File(
          '${Directory.current.path}/simulations/scenarios/admin/scenario_admin_breaches_all_sites_validation_v1.json',
        );
        final failingScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        failingScenario['scenarioId'] =
            'parser_admin_breaches_all_sites_alert_status_probe_v1';
        failingScenario['title'] =
            'Breaches across all sites alert status probe';
        final failingExpectedOutcome =
            failingScenario['expectedOutcome'] as Map<String, dynamic>;
        failingExpectedOutcome['expectedRoute'] = 'admin_wrong_route';

        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_admin_breaches_all_sites_alert_status_probe_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(failingScenario),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final seedHistoryResult = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(
          seedHistoryResult.exitCode,
          1,
          reason: '${seedHistoryResult.stderr}',
        );

        final repairedScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        repairedScenario['scenarioId'] =
            'parser_admin_breaches_all_sites_alert_status_probe_v1';
        repairedScenario['title'] =
            'Breaches across all sites alert status probe';
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(repairedScenario),
        );

        final nonMatchingRun = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--fail-on-alert=critical',
          '--fail-on-status=validation_candidate',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(nonMatchingRun.exitCode, 0, reason: '${nonMatchingRun.stderr}');

        final nonMatchingDecoded =
            jsonDecode(
                  (nonMatchingRun.stdout as String).substring(
                    (nonMatchingRun.stdout as String).indexOf('{'),
                  ),
                )
                as Map<String, dynamic>;
        expect(
          nonMatchingDecoded['alertFailureStatusFilter'],
          'validation_candidate',
        );
        expect(nonMatchingDecoded['alertFailureTriggered'], isFalse);
        expect(nonMatchingDecoded['alertFailureCount'], 0);
        expect(nonMatchingDecoded['alertFailureSummary'], isEmpty);
        expect(nonMatchingDecoded['alertFailureStatusFocus'], isNull);
        expect(nonMatchingDecoded['historyAlertStatusFocus'], isNull);

        final matchingRun = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--fail-on-alert=critical',
          '--fail-on-status=locked_validation',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(matchingRun.exitCode, 1, reason: '${matchingRun.stderr}');

        final matchingDecoded =
            jsonDecode(
                  (matchingRun.stdout as String).substring(
                    (matchingRun.stdout as String).indexOf('{'),
                  ),
                )
                as Map<String, dynamic>;
        expect(
          matchingDecoded['alertFailureStatusFilter'],
          'locked_validation',
        );
        expect(matchingDecoded['alertFailureTriggered'], isTrue);
        expect(matchingDecoded['alertFailureCount'], 2);
        expect(
          matchingDecoded['alertFailureSummary'],
          containsPair('critical', 2),
        );
        expect(
          matchingDecoded['alertFailureStatusFocus'],
          allOf(
            containsPair('status', 'locked_validation'),
            containsPair('scope', 'scenario_field'),
            containsPair(
              'scenarioId',
              'parser_admin_breaches_all_sites_alert_status_probe_v1',
            ),
            containsPair('field', 'expectedRoute'),
            containsPair('severity', 'critical'),
            containsPair('trend', 'watch'),
            containsPair('count', 1),
          ),
        );
        expect(
          matchingDecoded['historyAlertStatusFocus'],
          allOf(
            containsPair('status', 'locked_validation'),
            containsPair('scope', 'scenario_field'),
            containsPair(
              'scenarioId',
              'parser_admin_breaches_all_sites_alert_status_probe_v1',
            ),
            containsPair('field', 'expectedRoute'),
            containsPair('severity', 'critical'),
            containsPair('trend', 'watch'),
            containsPair('count', 1),
          ),
        );
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool applies checked-in alert policy from a file',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-input-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-history-',
      );

      try {
        final sourceScenario = File(
          '${Directory.current.path}/simulations/scenarios/admin/scenario_admin_breaches_all_sites_validation_v1.json',
        );
        final failingScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        failingScenario['scenarioId'] =
            'parser_admin_breaches_all_sites_policy_probe_v1';
        failingScenario['title'] = 'Breaches across all sites policy probe';
        final failingExpectedOutcome =
            failingScenario['expectedOutcome'] as Map<String, dynamic>;
        failingExpectedOutcome['expectedRoute'] = 'admin_wrong_route';

        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_admin_breaches_all_sites_policy_probe_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(failingScenario),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final seedHistoryResult = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(
          seedHistoryResult.exitCode,
          1,
          reason: '${seedHistoryResult.stderr}',
        );

        final repairedScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        repairedScenario['scenarioId'] =
            'parser_admin_breaches_all_sites_policy_probe_v1';
        repairedScenario['title'] = 'Breaches across all sites policy probe';
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(repairedScenario),
        );

        final result = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--policy=simulations/scenario_policy.json',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(result.exitCode, 1, reason: '${result.stderr}');

        final stdoutText = result.stdout as String;
        final jsonStartIndex = stdoutText.indexOf('{');
        expect(jsonStartIndex, isNonNegative, reason: stdoutText);
        final decoded =
            jsonDecode(stdoutText.substring(jsonStartIndex))
                as Map<String, dynamic>;

        expect(
          decoded['alertFailurePolicyPath'],
          '${Directory.current.path}/simulations/scenario_policy.json',
        );
        expect(decoded['alertFailureThreshold'], 'critical');
        expect(
          decoded['alertFailurePolicyByScenarioSet'],
          containsPair('validation', containsPair('threshold', 'critical')),
        );
        expect(
          decoded['alertFailurePolicyByScenarioSet'],
          containsPair(
            'validation',
            containsPair(
              'byScenarioId',
              allOf(
                containsPair(
                  'monitoring_priority_sequence_review_track_validation_v1',
                  containsPair(
                    'severityByScope',
                    containsPair('sequence_fallback', 'critical'),
                  ),
                ),
                containsPair(
                  'track_parent_rebuild_preserves_session_validation_v1',
                  containsPair('threshold', 'high'),
                ),
              ),
            ),
          ),
        );
        expect(
          decoded['alertFailurePolicyByScenarioSet'],
          containsPair('replay', containsPair('threshold', 'high')),
        );
        expect(
          decoded['alertFailurePolicyGroups'],
          containsPair(
            'watch_gates',
            containsPair('categories', contains('monitoring_watch')),
          ),
        );
        expect(
          decoded['alertFailurePolicyGroups'],
          containsPair(
            'night_shift_ops',
            containsPair('tags', contains('night_shift')),
          ),
        );
        expect(
          decoded['alertFailurePolicyGroups'],
          containsPair(
            'track_core',
            containsPair(
              'scenarioIds',
              contains('track_parent_rebuild_preserves_session_validation_v1'),
            ),
          ),
        );
        expect(
          decoded['alertFailurePolicyGroups'],
          containsPair(
            'live_ops_core',
            containsPair(
              'scenarioIds',
              containsAll(<String>[
                'guard_status_echo_3_validation_v1',
                'patrol_report_guard001_validation_v1',
                'client_comms_draft_update_validation_v1',
                'client_comms_attention_queue_pending_draft_validation_v1',
                'client_comms_queue_state_cycle_validation_v1',
                'monitoring_review_action_cctv_handoff_validation_v1',
                'monitoring_priority_sequence_review_dispatch_validation_v1',
                'monitoring_priority_sequence_dispatch_track_validation_v1',
                'monitoring_priority_sequence_review_track_validation_v1',
                'monitoring_priority_sequence_review_dispatch_track_validation_v1',
                'dispatch_attention_queue_handoff_validation_v1',
                'track_live_ops_handoff_validation_v1',
              ]),
            ),
          ),
        );
        expect(
          ((decoded['alertFailurePolicyGroups']
                  as Map<String, dynamic>)['live_ops_core']
              as Map<String, dynamic>)['scenarioIds'],
          isNot(
            containsAll(<String>[
              'monitoring_review_action_cctv_delay_v1',
              'monitoring_review_action_specialist_conflict_v1',
              'monitoring_review_action_hard_constraint_conflict_v1',
            ]),
          ),
        );
        expect(
          decoded['alertFailurePolicyGroups'],
          containsPair(
            'live_ops_core',
            containsPair('severityByScope', isEmpty),
          ),
        );
        expect(
          decoded['alertFailurePolicyByScenarioSet'],
          containsPair(
            'replay',
            containsPair(
              'byCategory',
              containsPair(
                'monitoring_watch',
                allOf(
                  containsPair('threshold', 'medium'),
                  containsPair(
                    'severityByScope',
                    allOf(
                      containsPair('specialist_degradation', 'medium'),
                      containsPair('specialist_conflict', 'medium'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(
          decoded['alertFailurePolicyByScenarioSet'],
          containsPair(
            'replay',
            containsPair(
              'byScenarioId',
              containsPair(
                'monitoring_review_action_hard_constraint_conflict_v1',
                containsPair(
                  'severityByScope',
                  containsPair('specialist_constraint', 'medium'),
                ),
              ),
            ),
          ),
        );
        expect(
          decoded['alertFailureStatusAllowlist'],
          contains('locked_validation'),
        );
        expect(decoded['alertFailureTriggered'], isTrue);
        expect(decoded['alertFailureCount'], 2);
        expect(decoded['alertFailureSummary'], containsPair('critical', 2));
        expect(
          decoded['alertFailureCategorySummary'],
          containsPair('admin_portfolio_read', 2),
        );
        expect(
          decoded['alertFailureCategoryFieldSummary'],
          containsPair(
            'admin_portfolio_read',
            containsPair('expectedRoute', 1),
          ),
        );
        expect(
          decoded['alertFailureScenarioSummary'],
          containsPair('parser_admin_breaches_all_sites_policy_probe_v1', 2),
        );
        expect(
          decoded['alertFailureScenarioFieldSummary'],
          containsPair(
            'parser_admin_breaches_all_sites_policy_probe_v1',
            containsPair('expectedRoute', 1),
          ),
        );
        expect(
          decoded['alertFailureFieldSummary'],
          containsPair('expectedRoute', 1),
        );
        expect(decoded['alertFailureTrendSummary'], containsPair('watch', 2));
        expect(
          decoded['alertFailureScenarioSetSummary'],
          containsPair('validation', 2),
        );
        expect(
          decoded['alertFailureStatusSummary'],
          containsPair('locked_validation', 2),
        );
        expect(
          decoded['alertFailureTagSummary'],
          allOf(
            containsPair('admin_scope', 2),
            containsPair('deterministic_read', 2),
            containsPair('multi_site', 2),
          ),
        );
        expect(
          decoded['alertFailureTagFieldSummary'],
          allOf(
            containsPair('admin_scope', containsPair('expectedRoute', 1)),
            containsPair(
              'deterministic_read',
              containsPair('expectedRoute', 1),
            ),
            containsPair('multi_site', containsPair('expectedRoute', 1)),
          ),
        );
        expect(
          decoded['alertFailurePolicySummary'],
          containsPair('status_allowlist:locked_validation', 2),
        );
        expect(
          decoded['alertFailurePolicyTypeSummary'],
          containsPair('status_allowlist', 2),
        );
        expect(
          decoded['alertFailurePolicySuppressionSummary'],
          containsPair('included', 2),
        );
        expect(
          decoded['alertFailurePolicySourceSummary'],
          containsPair('scenario_set', 2),
        );
        final policyFocus =
            decoded['alertFailurePolicyFocus'] as Map<String, dynamic>;
        expect(policyFocus['policyMatchType'], 'status_allowlist');
        expect(policyFocus['policyMatchValue'], 'locked_validation');
        expect(policyFocus['policyMatchSource'], 'scenario_set');
        expect(policyFocus['suppressed'], isFalse);
        expect(policyFocus['scope'], 'scenario_field');
        expect(
          policyFocus['scenarioId'],
          'parser_admin_breaches_all_sites_policy_probe_v1',
        );
        expect(policyFocus['field'], 'expectedRoute');
        expect(policyFocus['severity'], 'critical');
        expect(policyFocus['trend'], 'watch');
        expect(policyFocus['count'], 1);
        final historyPolicyFocus =
            decoded['historyAlertPolicyFocus'] as Map<String, dynamic>;
        expect(historyPolicyFocus['policyMatchType'], 'status_allowlist');
        expect(historyPolicyFocus['policyMatchValue'], 'locked_validation');
        expect(historyPolicyFocus['policyMatchSource'], 'scenario_set');
        expect(historyPolicyFocus['suppressed'], isFalse);
        expect(historyPolicyFocus['scope'], 'scenario_field');
        expect(
          historyPolicyFocus['scenarioId'],
          'parser_admin_breaches_all_sites_policy_probe_v1',
        );
        expect(historyPolicyFocus['field'], 'expectedRoute');
        expect(historyPolicyFocus['severity'], 'critical');
        expect(historyPolicyFocus['trend'], 'watch');
        expect(historyPolicyFocus['count'], 1);
        expect(
          decoded['historyAlertPolicySummary'],
          containsPair('status_allowlist:locked_validation', 2),
        );
        expect(
          decoded['historyAlertPolicyTypeSummary'],
          containsPair('status_allowlist', 2),
        );
        expect(
          decoded['historyAlertPolicySuppressionSummary'],
          containsPair('included', 2),
        );
        expect(
          decoded['historyAlertPolicySourceSummary'],
          containsPair('scenario_set', 2),
        );
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool scopes alert failure gating to a matching policy group',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-group-input-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-group-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-group-history-',
      );

      try {
        final sourceScenario = File(
          '${Directory.current.path}/simulations/scenarios/monitoring/scenario_monitoring_watchlist_match_review_v1.json',
        );
        final failingScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        failingScenario['scenarioId'] = 'monitoring_watchlist_group_probe_v1';
        failingScenario['title'] = 'Watchlist match policy group probe';
        final failingExpectedOutcome =
            failingScenario['expectedOutcome'] as Map<String, dynamic>;
        failingExpectedOutcome['expectedRoute'] = 'monitoring_wrong_route';

        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_monitoring_watchlist_group_probe_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(failingScenario),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final seedHistoryResult = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(
          seedHistoryResult.exitCode,
          1,
          reason: '${seedHistoryResult.stderr}',
        );

        final repairedScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        repairedScenario['scenarioId'] = 'monitoring_watchlist_group_probe_v1';
        repairedScenario['title'] = 'Watchlist match policy group probe';
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(repairedScenario),
        );

        final matchingResult = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--policy=simulations/scenario_policy.json',
          '--fail-on-alert=medium',
          '--fail-on-group=watch_gates',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(matchingResult.exitCode, 1, reason: '${matchingResult.stderr}');

        final matchingStdout = matchingResult.stdout as String;
        final matchingJsonStartIndex = matchingStdout.indexOf('{');
        expect(matchingJsonStartIndex, isNonNegative, reason: matchingStdout);
        final matchingDecoded =
            jsonDecode(matchingStdout.substring(matchingJsonStartIndex))
                as Map<String, dynamic>;
        expect(matchingDecoded['alertFailureGroupFilter'], 'watch_gates');
        expect(matchingDecoded['alertFailureTriggered'], isTrue);
        expect(matchingDecoded['alertFailureCount'], 2);
        expect(
          matchingDecoded['alertFailureSummary'],
          containsPair('medium', 2),
        );
        expect(
          matchingDecoded['alertFailureGroupFocus'],
          allOf(
            containsPair('group', 'watch_gates'),
            containsPair('scope', 'scenario_field'),
            containsPair('scenarioId', 'monitoring_watchlist_group_probe_v1'),
            containsPair('field', 'expectedRoute'),
            containsPair('severity', 'medium'),
            containsPair('trend', 'watch'),
            containsPair('count', 1),
          ),
        );
        expect(
          matchingDecoded['historyAlertGroupFocus'],
          allOf(
            containsPair('group', 'watch_gates'),
            containsPair('scope', 'scenario_field'),
            containsPair('scenarioId', 'monitoring_watchlist_group_probe_v1'),
            containsPair('field', 'expectedRoute'),
            containsPair('severity', 'medium'),
            containsPair('trend', 'watch'),
            containsPair('count', 1),
          ),
        );

        final nonMatchingResult = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--policy=simulations/scenario_policy.json',
          '--fail-on-alert=medium',
          '--fail-on-group=track_core',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(
          nonMatchingResult.exitCode,
          0,
          reason: '${nonMatchingResult.stderr}',
        );

        final nonMatchingStdout = nonMatchingResult.stdout as String;
        final nonMatchingJsonStartIndex = nonMatchingStdout.indexOf('{');
        expect(
          nonMatchingJsonStartIndex,
          isNonNegative,
          reason: nonMatchingStdout,
        );
        final nonMatchingDecoded =
            jsonDecode(nonMatchingStdout.substring(nonMatchingJsonStartIndex))
                as Map<String, dynamic>;
        expect(nonMatchingDecoded['alertFailureGroupFilter'], 'track_core');
        expect(nonMatchingDecoded['alertFailureTriggered'], isFalse);
        expect(nonMatchingDecoded['alertFailureCount'], 0);
        expect(nonMatchingDecoded['alertFailureSummary'], isEmpty);
        expect(nonMatchingDecoded['alertFailureGroupFocus'], isNull);
        expect(nonMatchingDecoded['historyAlertGroupFocus'], isNull);
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool scopes alert failure gating to the live ops core policy group',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-live-ops-group-filter-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-live-ops-group-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-live-ops-group-history-',
      );

      try {
        final sourceScenario = File(
          '${Directory.current.path}/simulations/scenarios/operations/scenario_guard_status_echo_3_validation_v1.json',
        );
        final failingScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        failingScenario['title'] = 'Guard status live ops group probe';
        final failingExpectedOutcome =
            failingScenario['expectedOutcome'] as Map<String, dynamic>;
        failingExpectedOutcome['expectedRoute'] = 'live_ops_wrong_route';

        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_guard_status_echo_3_validation_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(failingScenario),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final seedHistoryResult = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(
          seedHistoryResult.exitCode,
          1,
          reason: '${seedHistoryResult.stderr}',
        );

        final repairedScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        repairedScenario['title'] = 'Guard status live ops group probe';
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(repairedScenario),
        );

        final matchingResult = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--policy=simulations/scenario_policy.json',
          '--fail-on-alert=critical',
          '--fail-on-group=live_ops_core',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(matchingResult.exitCode, 1, reason: '${matchingResult.stderr}');

        final matchingStdout = matchingResult.stdout as String;
        final matchingJsonStartIndex = matchingStdout.indexOf('{');
        expect(matchingJsonStartIndex, isNonNegative, reason: matchingStdout);
        final matchingDecoded =
            jsonDecode(matchingStdout.substring(matchingJsonStartIndex))
                as Map<String, dynamic>;
        expect(matchingDecoded['alertFailureGroupFilter'], 'live_ops_core');
        expect(matchingDecoded['alertFailureTriggered'], isTrue);
        expect(matchingDecoded['alertFailureCount'], 2);
        expect(
          matchingDecoded['alertFailureSummary'],
          containsPair('critical', 2),
        );
        expect(
          matchingDecoded['alertFailureGroupFocus'],
          allOf(
            containsPair('group', 'live_ops_core'),
            containsPair('scope', 'scenario_field'),
            containsPair('scenarioId', 'guard_status_echo_3_validation_v1'),
            containsPair('field', 'expectedRoute'),
            containsPair('severity', 'critical'),
            containsPair('trend', 'watch'),
            containsPair('count', 1),
          ),
        );
        expect(
          matchingDecoded['historyAlertGroupFocus'],
          allOf(
            containsPair('group', 'live_ops_core'),
            containsPair('scope', 'scenario_field'),
            containsPair('scenarioId', 'guard_status_echo_3_validation_v1'),
            containsPair('field', 'expectedRoute'),
            containsPair('severity', 'critical'),
            containsPair('trend', 'watch'),
            containsPair('count', 1),
          ),
        );

        final nonMatchingResult = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--policy=simulations/scenario_policy.json',
          '--fail-on-alert=critical',
          '--fail-on-group=track_core',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(
          nonMatchingResult.exitCode,
          0,
          reason: '${nonMatchingResult.stderr}',
        );

        final nonMatchingStdout = nonMatchingResult.stdout as String;
        final nonMatchingJsonStartIndex = nonMatchingStdout.indexOf('{');
        expect(
          nonMatchingJsonStartIndex,
          isNonNegative,
          reason: nonMatchingStdout,
        );
        final nonMatchingDecoded =
            jsonDecode(nonMatchingStdout.substring(nonMatchingJsonStartIndex))
                as Map<String, dynamic>;
        expect(nonMatchingDecoded['alertFailureGroupFilter'], 'track_core');
        expect(nonMatchingDecoded['alertFailureTriggered'], isFalse);
        expect(nonMatchingDecoded['alertFailureCount'], 0);
        expect(nonMatchingDecoded['alertFailureSummary'], isEmpty);
        expect(nonMatchingDecoded['alertFailureGroupFocus'], isNull);
        expect(nonMatchingDecoded['historyAlertGroupFocus'], isNull);
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool scopes alert failure gating to the live ops core policy group for client comms',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-live-ops-client-group-filter-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-live-ops-client-group-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-live-ops-client-group-history-',
      );

      try {
        final sourceScenario = File(
          '${Directory.current.path}/simulations/scenarios/client/scenario_client_comms_draft_update_validation_v1.json',
        );
        final failingScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        failingScenario['title'] = 'Client comms live ops group probe';
        final failingExpectedOutcome =
            failingScenario['expectedOutcome'] as Map<String, dynamic>;
        failingExpectedOutcome['expectedRoute'] = 'client_comms_wrong_route';

        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_client_comms_draft_update_validation_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(failingScenario),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final seedHistoryResult = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(
          seedHistoryResult.exitCode,
          1,
          reason: '${seedHistoryResult.stderr}',
        );

        final repairedScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        repairedScenario['title'] = 'Client comms live ops group probe';
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(repairedScenario),
        );

        final matchingResult = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--policy=simulations/scenario_policy.json',
          '--fail-on-alert=critical',
          '--fail-on-group=live_ops_core',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(matchingResult.exitCode, 1, reason: '${matchingResult.stderr}');

        final matchingStdout = matchingResult.stdout as String;
        final matchingJsonStartIndex = matchingStdout.indexOf('{');
        expect(matchingJsonStartIndex, isNonNegative, reason: matchingStdout);
        final matchingDecoded =
            jsonDecode(matchingStdout.substring(matchingJsonStartIndex))
                as Map<String, dynamic>;
        expect(matchingDecoded['alertFailureGroupFilter'], 'live_ops_core');
        expect(matchingDecoded['alertFailureTriggered'], isTrue);
        expect(matchingDecoded['alertFailureCount'], 2);
        expect(
          matchingDecoded['alertFailureSummary'],
          containsPair('critical', 2),
        );
        expect(
          matchingDecoded['alertFailureGroupFocus'],
          allOf(
            containsPair('group', 'live_ops_core'),
            containsPair('scope', 'scenario_field'),
            containsPair(
              'scenarioId',
              'client_comms_draft_update_validation_v1',
            ),
            containsPair('field', 'expectedRoute'),
            containsPair('severity', 'critical'),
            containsPair('trend', 'watch'),
            containsPair('count', 1),
          ),
        );
        expect(
          matchingDecoded['historyAlertGroupFocus'],
          allOf(
            containsPair('group', 'live_ops_core'),
            containsPair('scope', 'scenario_field'),
            containsPair(
              'scenarioId',
              'client_comms_draft_update_validation_v1',
            ),
            containsPair('field', 'expectedRoute'),
            containsPair('severity', 'critical'),
            containsPair('trend', 'watch'),
            containsPair('count', 1),
          ),
        );
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool scopes alert failure gating to the live ops core policy group for CCTV review handoff',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-live-ops-review-group-filter-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-live-ops-review-group-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-live-ops-review-group-history-',
      );

      try {
        final sourceScenario = File(
          '${Directory.current.path}/simulations/scenarios/monitoring/scenario_monitoring_review_action_cctv_handoff_validation_v1.json',
        );
        final failingScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        failingScenario['title'] = 'Monitoring review live ops group probe';
        final failingExpectedOutcome =
            failingScenario['expectedOutcome'] as Map<String, dynamic>;
        failingExpectedOutcome['expectedRoute'] = 'monitoring_wrong_route';

        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_monitoring_review_action_cctv_handoff_validation_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(failingScenario),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final seedHistoryResult = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(
          seedHistoryResult.exitCode,
          1,
          reason: '${seedHistoryResult.stderr}',
        );

        final repairedScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        repairedScenario['title'] = 'Monitoring review live ops group probe';
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(repairedScenario),
        );

        final matchingResult = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--policy=simulations/scenario_policy.json',
          '--fail-on-alert=critical',
          '--fail-on-group=live_ops_core',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(matchingResult.exitCode, 1, reason: '${matchingResult.stderr}');

        final matchingStdout = matchingResult.stdout as String;
        final matchingJsonStartIndex = matchingStdout.indexOf('{');
        expect(matchingJsonStartIndex, isNonNegative, reason: matchingStdout);
        final matchingDecoded =
            jsonDecode(matchingStdout.substring(matchingJsonStartIndex))
                as Map<String, dynamic>;
        expect(matchingDecoded['alertFailureGroupFilter'], 'live_ops_core');
        expect(matchingDecoded['alertFailureTriggered'], isTrue);
        expect(matchingDecoded['alertFailureCount'], 2);
        expect(
          matchingDecoded['alertFailureSummary'],
          containsPair('critical', 2),
        );
        expect(
          matchingDecoded['alertFailureGroupFocus'],
          allOf(
            containsPair('group', 'live_ops_core'),
            containsPair('scope', 'scenario_field'),
            containsPair(
              'scenarioId',
              'monitoring_review_action_cctv_handoff_validation_v1',
            ),
            containsPair('field', 'expectedRoute'),
            containsPair('severity', 'critical'),
            containsPair('trend', 'watch'),
            containsPair('count', 1),
          ),
        );
        expect(
          matchingDecoded['historyAlertGroupFocus'],
          allOf(
            containsPair('group', 'live_ops_core'),
            containsPair('scope', 'scenario_field'),
            containsPair(
              'scenarioId',
              'monitoring_review_action_cctv_handoff_validation_v1',
            ),
            containsPair('field', 'expectedRoute'),
            containsPair('severity', 'critical'),
            containsPair('trend', 'watch'),
            containsPair('count', 1),
          ),
        );
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool scopes alert failure gating to the live ops core policy group for dispatch handoff',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-live-ops-dispatch-group-filter-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-live-ops-dispatch-group-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-live-ops-dispatch-group-history-',
      );

      try {
        final sourceScenario = File(
          '${Directory.current.path}/simulations/scenarios/dispatch/scenario_dispatch_attention_queue_handoff_validation_v1.json',
        );
        final failingScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        failingScenario['title'] = 'Dispatch handoff live ops group probe';
        final failingExpectedOutcome =
            failingScenario['expectedOutcome'] as Map<String, dynamic>;
        failingExpectedOutcome['expectedRoute'] = 'dispatch_wrong_route';

        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_dispatch_attention_queue_handoff_validation_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(failingScenario),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final seedHistoryResult = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(
          seedHistoryResult.exitCode,
          1,
          reason: '${seedHistoryResult.stderr}',
        );

        final repairedScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        repairedScenario['title'] = 'Dispatch handoff live ops group probe';
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(repairedScenario),
        );

        final matchingResult = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--policy=simulations/scenario_policy.json',
          '--fail-on-alert=critical',
          '--fail-on-group=live_ops_core',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(matchingResult.exitCode, 1, reason: '${matchingResult.stderr}');

        final matchingStdout = matchingResult.stdout as String;
        final matchingJsonStartIndex = matchingStdout.indexOf('{');
        expect(matchingJsonStartIndex, isNonNegative, reason: matchingStdout);
        final matchingDecoded =
            jsonDecode(matchingStdout.substring(matchingJsonStartIndex))
                as Map<String, dynamic>;
        expect(matchingDecoded['alertFailureGroupFilter'], 'live_ops_core');
        expect(matchingDecoded['alertFailureTriggered'], isTrue);
        expect(matchingDecoded['alertFailureCount'], 2);
        expect(
          matchingDecoded['alertFailureSummary'],
          containsPair('critical', 2),
        );
        expect(
          matchingDecoded['alertFailureGroupFocus'],
          allOf(
            containsPair('group', 'live_ops_core'),
            containsPair('scope', 'scenario_field'),
            containsPair(
              'scenarioId',
              'dispatch_attention_queue_handoff_validation_v1',
            ),
            containsPair('field', 'expectedRoute'),
            containsPair('severity', 'critical'),
            containsPair('trend', 'watch'),
            containsPair('count', 1),
          ),
        );
        expect(
          matchingDecoded['historyAlertGroupFocus'],
          allOf(
            containsPair('group', 'live_ops_core'),
            containsPair('scope', 'scenario_field'),
            containsPair(
              'scenarioId',
              'dispatch_attention_queue_handoff_validation_v1',
            ),
            containsPair('field', 'expectedRoute'),
            containsPair('severity', 'critical'),
            containsPair('trend', 'watch'),
            containsPair('count', 1),
          ),
        );
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool scopes alert failure gating to the live ops core policy group for Track handoff',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-live-ops-track-group-filter-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-live-ops-track-group-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-live-ops-track-group-history-',
      );

      try {
        final sourceScenario = File(
          '${Directory.current.path}/simulations/scenarios/track/scenario_track_live_ops_handoff_validation_v1.json',
        );
        final failingScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        failingScenario['title'] = 'Track handoff live ops group probe';
        final failingExpectedOutcome =
            failingScenario['expectedOutcome'] as Map<String, dynamic>;
        failingExpectedOutcome['expectedRoute'] = 'track_wrong_route';

        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_track_live_ops_handoff_validation_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(failingScenario),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final seedHistoryResult = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(
          seedHistoryResult.exitCode,
          1,
          reason: '${seedHistoryResult.stderr}',
        );

        final repairedScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        repairedScenario['title'] = 'Track handoff live ops group probe';
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(repairedScenario),
        );

        final matchingResult = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--policy=simulations/scenario_policy.json',
          '--fail-on-alert=critical',
          '--fail-on-group=live_ops_core',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(matchingResult.exitCode, 1, reason: '${matchingResult.stderr}');

        final matchingStdout = matchingResult.stdout as String;
        final matchingJsonStartIndex = matchingStdout.indexOf('{');
        expect(matchingJsonStartIndex, isNonNegative, reason: matchingStdout);
        final matchingDecoded =
            jsonDecode(matchingStdout.substring(matchingJsonStartIndex))
                as Map<String, dynamic>;
        expect(matchingDecoded['alertFailureGroupFilter'], 'live_ops_core');
        expect(matchingDecoded['alertFailureTriggered'], isTrue);
        expect(matchingDecoded['alertFailureCount'], 2);
        expect(
          matchingDecoded['alertFailureSummary'],
          containsPair('critical', 2),
        );
        expect(
          matchingDecoded['alertFailureGroupFocus'],
          allOf(
            containsPair('group', 'live_ops_core'),
            containsPair('scope', 'scenario_field'),
            containsPair('scenarioId', 'track_live_ops_handoff_validation_v1'),
            containsPair('field', 'expectedRoute'),
            containsPair('severity', 'critical'),
            containsPair('trend', 'watch'),
            containsPair('count', 1),
          ),
        );
        expect(
          matchingDecoded['historyAlertGroupFocus'],
          allOf(
            containsPair('group', 'live_ops_core'),
            containsPair('scope', 'scenario_field'),
            containsPair('scenarioId', 'track_live_ops_handoff_validation_v1'),
            containsPair('field', 'expectedRoute'),
            containsPair('severity', 'critical'),
            containsPair('trend', 'watch'),
            containsPair('count', 1),
          ),
        );
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool scopes alert failure gating to the live ops core policy group for the dispatch-to-Track sequence',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-live-ops-dispatch-track-group-filter-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-live-ops-dispatch-track-group-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-live-ops-dispatch-track-group-history-',
      );

      try {
        final sourceScenario = File(
          '${Directory.current.path}/simulations/scenarios/monitoring/scenario_monitoring_priority_sequence_dispatch_track_validation_v1.json',
        );
        final failingScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        failingScenario['title'] = 'Live ops dispatch to Track sequence probe';
        final failingExpectedOutcome =
            failingScenario['expectedOutcome'] as Map<String, dynamic>;
        failingExpectedOutcome['expectedRoute'] = 'sequence_wrong_route';

        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_monitoring_priority_sequence_dispatch_track_validation_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(failingScenario),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final seedHistoryResult = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(
          seedHistoryResult.exitCode,
          1,
          reason: '${seedHistoryResult.stderr}',
        );

        final repairedScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        repairedScenario['title'] = 'Live ops dispatch to Track sequence probe';
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(repairedScenario),
        );

        final matchingResult = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--policy=simulations/scenario_policy.json',
          '--fail-on-alert=critical',
          '--fail-on-group=live_ops_core',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(matchingResult.exitCode, 1, reason: '${matchingResult.stderr}');

        final matchingStdout = matchingResult.stdout as String;
        final matchingJsonStartIndex = matchingStdout.indexOf('{');
        expect(matchingJsonStartIndex, isNonNegative, reason: matchingStdout);
        final matchingDecoded =
            jsonDecode(matchingStdout.substring(matchingJsonStartIndex))
                as Map<String, dynamic>;
        expect(matchingDecoded['alertFailureGroupFilter'], 'live_ops_core');
        expect(matchingDecoded['alertFailureTriggered'], isTrue);
        expect(matchingDecoded['alertFailureCount'], 2);
        expect(
          matchingDecoded['alertFailureSummary'],
          containsPair('critical', 2),
        );
        expect(
          matchingDecoded['alertFailureGroupFocus'],
          allOf(
            containsPair('group', 'live_ops_core'),
            containsPair('scope', 'scenario_field'),
            containsPair(
              'scenarioId',
              'monitoring_priority_sequence_dispatch_track_validation_v1',
            ),
            containsPair('field', 'expectedRoute'),
            containsPair('severity', 'critical'),
            containsPair('trend', 'watch'),
            containsPair('count', 1),
          ),
        );
        expect(
          matchingDecoded['historyAlertGroupFocus'],
          allOf(
            containsPair('group', 'live_ops_core'),
            containsPair('scope', 'scenario_field'),
            containsPair(
              'scenarioId',
              'monitoring_priority_sequence_dispatch_track_validation_v1',
            ),
            containsPair('field', 'expectedRoute'),
            containsPair('severity', 'critical'),
            containsPair('trend', 'watch'),
            containsPair('count', 1),
          ),
        );
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool scopes alert failure gating to the live ops core policy group for the review-to-Track sequence',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-live-ops-review-track-group-filter-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-live-ops-review-track-group-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-live-ops-review-track-group-history-',
      );

      try {
        final sourceScenario = File(
          '${Directory.current.path}/simulations/scenarios/monitoring/scenario_monitoring_priority_sequence_review_track_validation_v1.json',
        );
        final failingScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        failingScenario['title'] = 'Live ops review to Track sequence probe';
        final failingExpectedOutcome =
            failingScenario['expectedOutcome'] as Map<String, dynamic>;
        failingExpectedOutcome['expectedRoute'] = 'sequence_wrong_route';

        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_monitoring_priority_sequence_review_track_validation_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(failingScenario),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final seedHistoryResult = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(
          seedHistoryResult.exitCode,
          1,
          reason: '${seedHistoryResult.stderr}',
        );

        final repairedScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        repairedScenario['title'] = 'Live ops review to Track sequence probe';
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(repairedScenario),
        );

        final matchingResult = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--policy=simulations/scenario_policy.json',
          '--fail-on-alert=critical',
          '--fail-on-group=live_ops_core',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(matchingResult.exitCode, 1, reason: '${matchingResult.stderr}');

        final matchingStdout = matchingResult.stdout as String;
        final matchingJsonStartIndex = matchingStdout.indexOf('{');
        expect(matchingJsonStartIndex, isNonNegative, reason: matchingStdout);
        final matchingDecoded =
            jsonDecode(matchingStdout.substring(matchingJsonStartIndex))
                as Map<String, dynamic>;
        expect(matchingDecoded['alertFailureGroupFilter'], 'live_ops_core');
        expect(matchingDecoded['alertFailureTriggered'], isTrue);
        expect(matchingDecoded['alertFailureCount'], 2);
        expect(
          matchingDecoded['alertFailureSummary'],
          containsPair('critical', 2),
        );
        expect(
          matchingDecoded['alertFailureGroupFocus'],
          allOf(
            containsPair('group', 'live_ops_core'),
            containsPair('scope', 'scenario_field'),
            containsPair(
              'scenarioId',
              'monitoring_priority_sequence_review_track_validation_v1',
            ),
            containsPair('field', 'expectedRoute'),
            containsPair('severity', 'critical'),
            containsPair('trend', 'watch'),
            containsPair('count', 1),
          ),
        );
        expect(
          matchingDecoded['historyAlertGroupFocus'],
          allOf(
            containsPair('group', 'live_ops_core'),
            containsPair('scope', 'scenario_field'),
            containsPair(
              'scenarioId',
              'monitoring_priority_sequence_review_track_validation_v1',
            ),
            containsPair('field', 'expectedRoute'),
            containsPair('severity', 'critical'),
            containsPair('trend', 'watch'),
            containsPair('count', 1),
          ),
        );
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool scopes alert failure gating to the live ops core policy group for the chained priority sequence',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-live-ops-sequence-group-filter-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-live-ops-sequence-group-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-live-ops-sequence-group-history-',
      );

      try {
        final sourceScenario = File(
          '${Directory.current.path}/simulations/scenarios/monitoring/scenario_monitoring_priority_sequence_review_dispatch_track_validation_v1.json',
        );
        final failingScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        failingScenario['title'] = 'Live ops chained priority sequence probe';
        final failingExpectedOutcome =
            failingScenario['expectedOutcome'] as Map<String, dynamic>;
        failingExpectedOutcome['expectedRoute'] = 'sequence_wrong_route';

        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_monitoring_priority_sequence_review_dispatch_track_validation_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(failingScenario),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final seedHistoryResult = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(
          seedHistoryResult.exitCode,
          1,
          reason: '${seedHistoryResult.stderr}',
        );

        final repairedScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        repairedScenario['title'] = 'Live ops chained priority sequence probe';
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(repairedScenario),
        );

        final matchingResult = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--policy=simulations/scenario_policy.json',
          '--fail-on-alert=critical',
          '--fail-on-group=live_ops_core',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(matchingResult.exitCode, 1, reason: '${matchingResult.stderr}');

        final matchingStdout = matchingResult.stdout as String;
        final matchingJsonStartIndex = matchingStdout.indexOf('{');
        expect(matchingJsonStartIndex, isNonNegative, reason: matchingStdout);
        final matchingDecoded =
            jsonDecode(matchingStdout.substring(matchingJsonStartIndex))
                as Map<String, dynamic>;
        expect(matchingDecoded['alertFailureGroupFilter'], 'live_ops_core');
        expect(matchingDecoded['alertFailureTriggered'], isTrue);
        expect(matchingDecoded['alertFailureCount'], 2);
        expect(
          matchingDecoded['alertFailureSummary'],
          containsPair('critical', 2),
        );
        expect(
          matchingDecoded['alertFailureGroupFocus'],
          allOf(
            containsPair('group', 'live_ops_core'),
            containsPair('scope', 'scenario_field'),
            containsPair(
              'scenarioId',
              'monitoring_priority_sequence_review_dispatch_track_validation_v1',
            ),
            containsPair('field', 'expectedRoute'),
            containsPair('severity', 'critical'),
            containsPair('trend', 'watch'),
            containsPair('count', 1),
          ),
        );
        expect(
          matchingDecoded['historyAlertGroupFocus'],
          allOf(
            containsPair('group', 'live_ops_core'),
            containsPair('scope', 'scenario_field'),
            containsPair(
              'scenarioId',
              'monitoring_priority_sequence_review_dispatch_track_validation_v1',
            ),
            containsPair('field', 'expectedRoute'),
            containsPair('severity', 'critical'),
            containsPair('trend', 'watch'),
            containsPair('count', 1),
          ),
        );
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool keeps live ops core group focused on operator bundles instead of specialist conflict replay alerts',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-live-ops-conflict-group-filter-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-live-ops-conflict-group-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-live-ops-conflict-group-history-',
      );

      try {
        final sourceScenario = File(
          '${Directory.current.path}/simulations/scenarios/monitoring/scenario_monitoring_review_action_specialist_conflict_v1.json',
        );
        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_monitoring_review_action_specialist_conflict_v1.json',
        );
        await scenarioFile.writeAsString(await sourceScenario.readAsString());

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';

        final seedHistoryResult = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(
          seedHistoryResult.exitCode,
          0,
          reason: '${seedHistoryResult.stderr}',
        );

        final groupedResult = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--policy=simulations/scenario_policy.json',
          '--fail-on-alert=medium',
          '--fail-on-group=live_ops_core',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(groupedResult.exitCode, 0, reason: '${groupedResult.stderr}');

        final stdoutText = groupedResult.stdout as String;
        final jsonStartIndex = stdoutText.indexOf('{');
        expect(jsonStartIndex, isNonNegative, reason: stdoutText);
        final decoded =
            jsonDecode(stdoutText.substring(jsonStartIndex))
                as Map<String, dynamic>;

        expect(decoded['alertFailureGroupFilter'], 'live_ops_core');
        expect(decoded['historyAlertSummary'], containsPair('low', 1));
        expect(
          decoded['historyAlertSpecialistConflictSummary'],
          containsPair(
            'monitoring_review_action_specialist_conflict_v1',
            containsPair('severity', 'low'),
          ),
        );
        expect(decoded['alertFailureTriggered'], isFalse);
        expect(decoded['alertFailureCount'], 0);
        expect(decoded['alertFailureSummary'], isEmpty);
        expect(decoded['alertFailureSpecialistConflictSummary'], isNull);
        expect(decoded['alertFailureGroupFocus'], isNull);
        expect(decoded['historyAlertGroupFocus'], isNull);
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool keeps live ops core group focused on operator bundles instead of specialist degradation replay alerts',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-live-ops-degradation-group-filter-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-live-ops-degradation-group-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-live-ops-degradation-group-history-',
      );

      try {
        final sourceScenario = File(
          '${Directory.current.path}/simulations/scenarios/monitoring/scenario_monitoring_review_action_cctv_delay_v1.json',
        );
        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_monitoring_review_action_cctv_delay_v1.json',
        );
        await scenarioFile.writeAsString(await sourceScenario.readAsString());

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';

        final seedHistoryResult = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(
          seedHistoryResult.exitCode,
          0,
          reason: '${seedHistoryResult.stderr}',
        );

        final groupedResult = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--policy=simulations/scenario_policy.json',
          '--fail-on-alert=medium',
          '--fail-on-group=live_ops_core',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(groupedResult.exitCode, 0, reason: '${groupedResult.stderr}');

        final stdoutText = groupedResult.stdout as String;
        final jsonStartIndex = stdoutText.indexOf('{');
        expect(jsonStartIndex, isNonNegative, reason: stdoutText);
        final decoded =
            jsonDecode(stdoutText.substring(jsonStartIndex))
                as Map<String, dynamic>;

        expect(decoded['alertFailureGroupFilter'], 'live_ops_core');
        expect(decoded['historyAlertSummary'], containsPair('low', 1));
        expect(
          decoded['historyAlertSpecialistDegradationSummary'],
          containsPair(
            'monitoring_review_action_cctv_delay_v1',
            containsPair('severity', 'low'),
          ),
        );
        expect(decoded['alertFailureTriggered'], isFalse);
        expect(decoded['alertFailureCount'], 0);
        expect(decoded['alertFailureSummary'], isEmpty);
        expect(decoded['alertFailureSpecialistDegradationSummary'], isNull);
        expect(decoded['alertFailureGroupFocus'], isNull);
        expect(decoded['historyAlertGroupFocus'], isNull);
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool keeps live ops core group focused on operator bundles instead of specialist constraint replay alerts',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-live-ops-constraint-group-filter-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-live-ops-constraint-group-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-live-ops-constraint-group-history-',
      );

      try {
        final sourceScenario = File(
          '${Directory.current.path}/simulations/scenarios/monitoring/scenario_monitoring_review_action_hard_constraint_conflict_v1.json',
        );
        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_monitoring_review_action_hard_constraint_conflict_v1.json',
        );
        await scenarioFile.writeAsString(await sourceScenario.readAsString());

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';

        final seedHistoryResult = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(
          seedHistoryResult.exitCode,
          0,
          reason: '${seedHistoryResult.stderr}',
        );

        final groupedResult = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--policy=simulations/scenario_policy.json',
          '--fail-on-alert=medium',
          '--fail-on-group=live_ops_core',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(groupedResult.exitCode, 0, reason: '${groupedResult.stderr}');

        final stdoutText = groupedResult.stdout as String;
        final jsonStartIndex = stdoutText.indexOf('{');
        expect(jsonStartIndex, isNonNegative, reason: stdoutText);
        final decoded =
            jsonDecode(stdoutText.substring(jsonStartIndex))
                as Map<String, dynamic>;

        expect(decoded['alertFailureGroupFilter'], 'live_ops_core');
        expect(decoded['historyAlertSummary'], containsPair('low', 2));
        expect(
          decoded['historyAlertSpecialistConstraintSummary'],
          containsPair(
            'monitoring_review_action_hard_constraint_conflict_v1',
            containsPair('severity', 'low'),
          ),
        );
        expect(
          decoded['historyAlertSpecialistConflictSummary'],
          containsPair(
            'monitoring_review_action_hard_constraint_conflict_v1',
            containsPair('severity', 'low'),
          ),
        );
        expect(decoded['alertFailureTriggered'], isFalse);
        expect(decoded['alertFailureCount'], 0);
        expect(decoded['alertFailureSummary'], isEmpty);
        expect(decoded['alertFailureSpecialistConflictSummary'], isNull);
        expect(decoded['alertFailureSpecialistConstraintSummary'], isNull);
        expect(decoded['alertFailureGroupFocus'], isNull);
        expect(decoded['historyAlertGroupFocus'], isNull);
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool scopes alert failure gating to a matching tag',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-tag-input-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-tag-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-tag-history-',
      );

      try {
        final sourceScenario = File(
          '${Directory.current.path}/simulations/scenarios/monitoring/scenario_monitoring_watchlist_match_review_v1.json',
        );
        final failingScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        failingScenario['scenarioId'] = 'monitoring_watchlist_tag_probe_v1';
        failingScenario['title'] = 'Watchlist match policy tag probe';
        final failingExpectedOutcome =
            failingScenario['expectedOutcome'] as Map<String, dynamic>;
        failingExpectedOutcome['expectedRoute'] = 'monitoring_wrong_route';

        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_monitoring_watchlist_tag_probe_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(failingScenario),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final seedHistoryResult = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(
          seedHistoryResult.exitCode,
          1,
          reason: '${seedHistoryResult.stderr}',
        );

        final repairedScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        repairedScenario['scenarioId'] = 'monitoring_watchlist_tag_probe_v1';
        repairedScenario['title'] = 'Watchlist match policy tag probe';
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(repairedScenario),
        );

        final matchingResult = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--fail-on-alert=medium',
          '--fail-on-tag=night_shift',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(matchingResult.exitCode, 1, reason: '${matchingResult.stderr}');

        final matchingStdout = matchingResult.stdout as String;
        final matchingJsonStartIndex = matchingStdout.indexOf('{');
        expect(matchingJsonStartIndex, isNonNegative, reason: matchingStdout);
        final matchingDecoded =
            jsonDecode(matchingStdout.substring(matchingJsonStartIndex))
                as Map<String, dynamic>;
        expect(matchingDecoded['alertFailureTagFilter'], 'night_shift');
        expect(matchingDecoded['alertFailureTriggered'], isTrue);
        expect(matchingDecoded['alertFailureCount'], 2);
        expect(
          matchingDecoded['alertFailureSummary'],
          containsPair('medium', 2),
        );
        expect(
          matchingDecoded['alertFailureTagFocus'],
          allOf(
            containsPair('tag', 'night_shift'),
            containsPair('scope', 'scenario_field'),
            containsPair('scenarioId', 'monitoring_watchlist_tag_probe_v1'),
            containsPair('field', 'expectedRoute'),
            containsPair('severity', 'medium'),
            containsPair('trend', 'watch'),
            containsPair('count', 1),
          ),
        );
        expect(
          matchingDecoded['historyAlertTagFocus'],
          allOf(
            containsPair('tag', 'night_shift'),
            containsPair('scope', 'scenario_field'),
            containsPair('scenarioId', 'monitoring_watchlist_tag_probe_v1'),
            containsPair('field', 'expectedRoute'),
            containsPair('severity', 'medium'),
            containsPair('trend', 'watch'),
            containsPair('count', 1),
          ),
        );

        final nonMatchingResult = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--fail-on-alert=medium',
          '--fail-on-tag=route_persistence',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(
          nonMatchingResult.exitCode,
          0,
          reason: '${nonMatchingResult.stderr}',
        );

        final nonMatchingStdout = nonMatchingResult.stdout as String;
        final nonMatchingJsonStartIndex = nonMatchingStdout.indexOf('{');
        expect(
          nonMatchingJsonStartIndex,
          isNonNegative,
          reason: nonMatchingStdout,
        );
        final nonMatchingDecoded =
            jsonDecode(nonMatchingStdout.substring(nonMatchingJsonStartIndex))
                as Map<String, dynamic>;
        expect(
          nonMatchingDecoded['alertFailureTagFilter'],
          'route_persistence',
        );
        expect(nonMatchingDecoded['alertFailureTriggered'], isFalse);
        expect(nonMatchingDecoded['alertFailureCount'], 0);
        expect(nonMatchingDecoded['alertFailureSummary'], isEmpty);
        expect(nonMatchingDecoded['alertFailureTagFocus'], isNull);
        expect(nonMatchingDecoded['historyAlertTagFocus'], isNull);
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool applies per-scenario-set policy overrides for replay rules',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-set-input-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-set-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-set-history-',
      );
      final policyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-set-policy-',
      );

      try {
        final sourceScenario = File(
          '${Directory.current.path}/simulations/scenarios/admin/scenario_admin_breaches_all_sites_v1.json',
        );
        final failingScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        failingScenario['scenarioId'] =
            'parser_admin_breaches_all_sites_replay_policy_probe_v1';
        failingScenario['title'] =
            'Breaches across all sites replay policy probe';
        final failingExpectedOutcome =
            failingScenario['expectedOutcome'] as Map<String, dynamic>;
        failingExpectedOutcome['expectedRoute'] = 'admin_wrong_route';

        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_admin_breaches_all_sites_replay_policy_probe_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(failingScenario),
        );

        final policyFile = File('${policyDirectory.path}/scenario_policy.json');
        await policyFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
            'alertFailure': <String, dynamic>{
              'threshold': 'critical',
              'includeStatuses': <String>['locked_validation'],
              'byScenarioSet': <String, dynamic>{
                'replay': <String, dynamic>{
                  'threshold': 'medium',
                  'includeStatuses': <String>[],
                },
              },
            },
          }),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final seedHistoryResult = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(
          seedHistoryResult.exitCode,
          1,
          reason: '${seedHistoryResult.stderr}',
        );

        final repairedScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        repairedScenario['scenarioId'] =
            'parser_admin_breaches_all_sites_replay_policy_probe_v1';
        repairedScenario['title'] =
            'Breaches across all sites replay policy probe';
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(repairedScenario),
        );

        final result = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--policy=${policyFile.path}',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(result.exitCode, 1, reason: '${result.stderr}');

        final stdoutText = result.stdout as String;
        final jsonStartIndex = stdoutText.indexOf('{');
        expect(jsonStartIndex, isNonNegative, reason: stdoutText);
        final decoded =
            jsonDecode(stdoutText.substring(jsonStartIndex))
                as Map<String, dynamic>;

        expect(
          decoded['alertFailurePolicyByScenarioSet'],
          containsPair('replay', containsPair('threshold', 'medium')),
        );
        expect(decoded['alertFailureThreshold'], 'critical');
        expect(decoded['alertFailureTriggered'], isTrue);
        expect(decoded['alertFailureCount'], 2);
        expect(decoded['alertFailureSummary'], containsPair('medium', 2));
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
        if (policyDirectory.existsSync()) {
          policyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool applies per-category policy overrides within a scenario set',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-category-input-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-category-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-category-history-',
      );

      try {
        final sourceScenario = File(
          '${Directory.current.path}/simulations/scenarios/monitoring/scenario_monitoring_watchlist_match_review_v1.json',
        );
        final failingScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        failingScenario['scenarioId'] =
            'monitoring_watchlist_policy_category_probe_v1';
        failingScenario['title'] =
            'Watchlist match replay category policy probe';
        final failingExpectedOutcome =
            failingScenario['expectedOutcome'] as Map<String, dynamic>;
        failingExpectedOutcome['expectedRoute'] = 'monitoring_wrong_route';

        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_monitoring_watchlist_policy_category_probe_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(failingScenario),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final seedHistoryResult = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(
          seedHistoryResult.exitCode,
          1,
          reason: '${seedHistoryResult.stderr}',
        );

        final repairedScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        repairedScenario['scenarioId'] =
            'monitoring_watchlist_policy_category_probe_v1';
        repairedScenario['title'] =
            'Watchlist match replay category policy probe';
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(repairedScenario),
        );

        final result = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--policy=simulations/scenario_policy.json',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(result.exitCode, 1, reason: '${result.stderr}');

        final stdoutText = result.stdout as String;
        final jsonStartIndex = stdoutText.indexOf('{');
        expect(jsonStartIndex, isNonNegative, reason: stdoutText);
        final decoded =
            jsonDecode(stdoutText.substring(jsonStartIndex))
                as Map<String, dynamic>;

        expect(
          decoded['alertFailurePolicyByScenarioSet'],
          containsPair(
            'replay',
            containsPair(
              'byCategory',
              containsPair(
                'monitoring_watch',
                containsPair('threshold', 'medium'),
              ),
            ),
          ),
        );
        expect(decoded['alertFailureThreshold'], 'critical');
        expect(decoded['alertFailureTriggered'], isTrue);
        expect(decoded['alertFailureCount'], 2);
        expect(decoded['alertFailureSummary'], containsPair('medium', 2));
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool applies per-scenario-id policy overrides within a scenario set',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-scenario-input-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-scenario-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-scenario-history-',
      );

      try {
        final sourceScenario = File(
          '${Directory.current.path}/simulations/scenarios/track/scenario_track_parent_rebuild_preserves_session_validation_v1.json',
        );
        final failingScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        failingScenario['scenarioId'] =
            'track_parent_rebuild_policy_scenario_probe_v1';
        failingScenario['title'] =
            'Track parent rebuild validation scenario policy probe';
        final failingExpectedOutcome =
            failingScenario['expectedOutcome'] as Map<String, dynamic>;
        failingExpectedOutcome['expectedRoute'] = 'track_wrong_route';

        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_track_parent_rebuild_policy_scenario_probe_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(failingScenario),
        );

        final policyFile = File(
          '${scenarioDirectory.path}/scenario_policy.json',
        );
        await policyFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
            'alertFailure': <String, dynamic>{
              'threshold': 'critical',
              'includeStatuses': <String>['locked_validation'],
              'byScenarioSet': <String, dynamic>{
                'validation': <String, dynamic>{
                  'threshold': 'critical',
                  'includeStatuses': <String>['locked_validation'],
                  'byScenarioId': <String, dynamic>{
                    'track_parent_rebuild_policy_scenario_probe_v1':
                        <String, dynamic>{'threshold': 'high'},
                  },
                },
              },
            },
          }),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final commandArgs = <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ];

        final firstFail = await Process.run(
          dartExecutable,
          commandArgs,
          workingDirectory: Directory.current.path,
        );
        expect(firstFail.exitCode, 1, reason: '${firstFail.stderr}');

        final secondFail = await Process.run(
          dartExecutable,
          commandArgs,
          workingDirectory: Directory.current.path,
        );
        expect(secondFail.exitCode, 1, reason: '${secondFail.stderr}');

        final repairedScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        repairedScenario['scenarioId'] =
            'track_parent_rebuild_policy_scenario_probe_v1';
        repairedScenario['title'] =
            'Track parent rebuild validation scenario policy probe';
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(repairedScenario),
        );

        final result = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--policy=${policyFile.path}',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(result.exitCode, 1, reason: '${result.stderr}');

        final stdoutText = result.stdout as String;
        final jsonStartIndex = stdoutText.indexOf('{');
        expect(jsonStartIndex, isNonNegative, reason: stdoutText);
        final decoded =
            jsonDecode(stdoutText.substring(jsonStartIndex))
                as Map<String, dynamic>;

        expect(
          decoded['alertFailurePolicyByScenarioSet'],
          containsPair(
            'validation',
            containsPair(
              'byScenarioId',
              containsPair(
                'track_parent_rebuild_policy_scenario_probe_v1',
                containsPair('threshold', 'high'),
              ),
            ),
          ),
        );
        expect(decoded['alertFailureThreshold'], 'critical');
        expect(decoded['alertFailureTriggered'], isTrue);
        expect(decoded['alertFailureCount'], 2);
        expect(decoded['alertFailureSummary'], containsPair('high', 2));
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool applies checked-in scope severity overrides for persistent sequence fallback alerts',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-sequence-fallback-input-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-sequence-fallback-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-sequence-fallback-history-',
      );

      try {
        final sourceScenario = File(
          '${Directory.current.path}/simulations/scenarios/monitoring/scenario_monitoring_priority_sequence_review_track_validation_v1.json',
        );
        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_monitoring_priority_sequence_review_track_validation_v1.json',
        );
        await scenarioFile.writeAsString(await sourceScenario.readAsString());

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final commandArgs = <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--policy=simulations/scenario_policy.json',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ];

        final firstRun = await Process.run(
          dartExecutable,
          commandArgs,
          workingDirectory: Directory.current.path,
        );
        expect(firstRun.exitCode, 0, reason: '${firstRun.stderr}');

        final secondRun = await Process.run(
          dartExecutable,
          commandArgs,
          workingDirectory: Directory.current.path,
        );
        expect(secondRun.exitCode, 1, reason: '${secondRun.stderr}');

        final stdoutText = secondRun.stdout as String;
        final jsonStartIndex = stdoutText.indexOf('{');
        expect(jsonStartIndex, isNonNegative, reason: stdoutText);
        final decoded =
            jsonDecode(stdoutText.substring(jsonStartIndex))
                as Map<String, dynamic>;

        expect(decoded['alertFailureTriggered'], isTrue);
        expect(decoded['alertFailureCount'], 1);
        expect(decoded['historyAlertSummary'], containsPair('high', 1));
        expect(decoded['alertFailureSummary'], containsPair('critical', 1));
        expect(
          decoded['historyAlertSequenceFallbackSummary'],
          containsPair(
            'monitoring_priority_sequence_review_track_validation_v1',
            allOf(
              containsPair('severity', 'high'),
              containsPair('trend', 'stabilizing'),
              containsPair('latestBranch', 'active'),
              containsPair('latestTarget', 'tacticalTrack'),
            ),
          ),
        );
        expect(
          decoded['alertFailureSequenceFallbackSummary'],
          containsPair(
            'monitoring_priority_sequence_review_track_validation_v1',
            containsPair('severity', 'critical'),
          ),
        );
        expect(
          decoded['alertFailurePolicySummary'],
          containsPair('scope_severity_override:sequence_fallback:critical', 1),
        );
        expect(
          decoded['alertFailurePolicyTypeSummary'],
          containsPair('scope_severity_override', 1),
        );
        expect(
          decoded['alertFailurePolicySourceSummary'],
          containsPair('scenario_set_scenario_id', 1),
        );
        expect(
          decoded['historyAlertPolicyPromotedReplayRiskSummary'],
          containsPair('sequence_fallback:high->critical', 1),
        );
        expect(
          decoded['historyAlertPolicyPromotedReplayRiskSourceSummary'],
          containsPair('scenario_set_scenario_id', 1),
        );
        final historyPromotedReplayRiskFocus =
            decoded['historyAlertPolicyPromotedReplayRiskFocus']
                as Map<String, dynamic>;
        expect(historyPromotedReplayRiskFocus['scope'], 'sequence_fallback');
        expect(historyPromotedReplayRiskFocus['originalSeverity'], 'high');
        expect(historyPromotedReplayRiskFocus['severity'], 'critical');
        expect(
          historyPromotedReplayRiskFocus['policyMatchType'],
          'scope_severity_override',
        );
        expect(
          historyPromotedReplayRiskFocus['policyMatchValue'],
          'sequence_fallback:critical',
        );
        expect(
          historyPromotedReplayRiskFocus['policyMatchSource'],
          'scenario_set_scenario_id',
        );
        expect(
          decoded['historyFocusSummary'],
          containsPair(
            'topPolicyPromotedReplayRiskScenario',
            allOf(
              containsPair(
                'scenarioId',
                'monitoring_priority_sequence_review_track_validation_v1',
              ),
              containsPair('scope', 'sequence_fallback'),
              containsPair('originalSeverity', 'high'),
              containsPair('promotedSeverity', 'critical'),
              containsPair('policyMatchSource', 'scenario_set_scenario_id'),
            ),
          ),
        );
        expect(
          decoded.containsKey('historyAlertPolicyPromotedSpecialistSummary'),
          isFalse,
        );
        expect(
          decoded['alertFailurePolicyPromotedReplayRiskSummary'],
          containsPair('sequence_fallback:high->critical', 1),
        );
        expect(
          decoded['alertFailurePolicyPromotedReplayRiskSourceSummary'],
          containsPair('scenario_set_scenario_id', 1),
        );
        final alertFailurePromotedReplayRiskFocus =
            decoded['alertFailurePolicyPromotedReplayRiskFocus']
                as Map<String, dynamic>;
        expect(
          alertFailurePromotedReplayRiskFocus['scope'],
          'sequence_fallback',
        );
        expect(alertFailurePromotedReplayRiskFocus['originalSeverity'], 'high');
        expect(alertFailurePromotedReplayRiskFocus['severity'], 'critical');
        expect(
          decoded.containsKey('alertFailurePolicyPromotedSpecialistSummary'),
          isFalse,
        );
        final policyFocus =
            decoded['alertFailurePolicyFocus'] as Map<String, dynamic>;
        expect(policyFocus['policyMatchType'], 'scope_severity_override');
        expect(policyFocus['policyMatchValue'], 'sequence_fallback:critical');
        expect(policyFocus['policyMatchSource'], 'scenario_set_scenario_id');
        expect(policyFocus['suppressed'], isFalse);
        expect(policyFocus['scope'], 'sequence_fallback');

        final historyAlerts = (decoded['historyAlerts'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);
        final promotedHistoryAlert = historyAlerts.singleWhere(
          (alert) => alert['scope']?.toString() == 'sequence_fallback',
        );
        expect(promotedHistoryAlert['severity'], 'high');
        expect(promotedHistoryAlert['baseSeverity'], 'high');
        expect(promotedHistoryAlert['effectiveSeverity'], 'critical');
        expect(promotedHistoryAlert['effectiveSeverityChanged'], isTrue);
        expect(promotedHistoryAlert['effectiveSeverityPromoted'], isTrue);
        expect(promotedHistoryAlert['effectiveSeverityDemoted'], isFalse);
        expect(promotedHistoryAlert['severityTransition'], 'high->critical');
        expect(
          promotedHistoryAlert['effectiveSeverityPolicyMatchType'],
          'scope_severity_override',
        );
        expect(
          promotedHistoryAlert['effectiveSeverityPolicyValue'],
          'sequence_fallback:critical',
        );
        expect(
          promotedHistoryAlert['effectiveSeverityPolicySource'],
          'scenario_set_scenario_id',
        );
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool applies per-scenario-set scope severity overrides for specialist conflict replay alerts',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-set-scope-input-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-set-scope-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-set-scope-history-',
      );
      final policyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-set-scope-policy-',
      );

      try {
        final sourceScenario = File(
          '${Directory.current.path}/simulations/scenarios/monitoring/scenario_monitoring_review_action_specialist_conflict_v1.json',
        );
        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_monitoring_review_action_specialist_conflict_v1.json',
        );
        await scenarioFile.writeAsString(await sourceScenario.readAsString());

        final policyFile = File('${policyDirectory.path}/scenario_policy.json');
        await policyFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
            'alertFailure': <String, dynamic>{
              'threshold': 'critical',
              'byScenarioSet': <String, dynamic>{
                'replay': <String, dynamic>{
                  'threshold': 'medium',
                  'severityByScope': <String, dynamic>{
                    'specialist_conflict': 'medium',
                  },
                },
              },
            },
          }),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final seedHistoryResult = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(
          seedHistoryResult.exitCode,
          0,
          reason: '${seedHistoryResult.stderr}',
        );

        final result = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--policy=${policyFile.path}',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(result.exitCode, 1, reason: '${result.stderr}');

        final stdoutText = result.stdout as String;
        final jsonStartIndex = stdoutText.indexOf('{');
        expect(jsonStartIndex, isNonNegative, reason: stdoutText);
        final decoded =
            jsonDecode(stdoutText.substring(jsonStartIndex))
                as Map<String, dynamic>;

        expect(
          decoded['alertFailurePolicyByScenarioSet'],
          containsPair(
            'replay',
            containsPair(
              'severityByScope',
              containsPair('specialist_conflict', 'medium'),
            ),
          ),
        );
        expect(decoded['historyAlertSummary'], containsPair('low', 1));
        expect(decoded['alertFailureTriggered'], isTrue);
        expect(decoded['alertFailureCount'], 1);
        expect(decoded['alertFailureSummary'], containsPair('medium', 1));
        expect(
          decoded['alertFailurePolicySummary'],
          containsPair('scope_severity_override:specialist_conflict:medium', 1),
        );
        expect(
          decoded['alertFailurePolicyTypeSummary'],
          containsPair('scope_severity_override', 1),
        );
        expect(
          decoded['alertFailurePolicySourceSummary'],
          containsPair('scenario_set', 1),
        );
        final policyFocus =
            decoded['alertFailurePolicyFocus'] as Map<String, dynamic>;
        expect(policyFocus['policyMatchType'], 'scope_severity_override');
        expect(policyFocus['policyMatchValue'], 'specialist_conflict:medium');
        expect(policyFocus['policyMatchSource'], 'scenario_set');
        expect(policyFocus['suppressed'], isFalse);
        expect(policyFocus['scope'], 'specialist_conflict');
        expect(
          decoded['historyAlertPolicySummary'],
          containsPair('scope_severity_override:specialist_conflict:medium', 1),
        );
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
        if (policyDirectory.existsSync()) {
          policyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool applies per-category scope severity overrides for specialist degradation replay alerts',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-category-scope-input-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-category-scope-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-category-scope-history-',
      );
      final policyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-category-scope-policy-',
      );

      try {
        final sourceScenario = File(
          '${Directory.current.path}/simulations/scenarios/monitoring/scenario_monitoring_review_action_cctv_delay_v1.json',
        );
        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_monitoring_review_action_cctv_delay_v1.json',
        );
        await scenarioFile.writeAsString(await sourceScenario.readAsString());

        final policyFile = File('${policyDirectory.path}/scenario_policy.json');
        await policyFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
            'alertFailure': <String, dynamic>{
              'threshold': 'critical',
              'byScenarioSet': <String, dynamic>{
                'replay': <String, dynamic>{
                  'threshold': 'critical',
                  'byCategory': <String, dynamic>{
                    'monitoring_watch': <String, dynamic>{
                      'threshold': 'medium',
                      'severityByScope': <String, dynamic>{
                        'specialist_degradation': 'medium',
                      },
                    },
                  },
                },
              },
            },
          }),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final seedHistoryResult = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(
          seedHistoryResult.exitCode,
          0,
          reason: '${seedHistoryResult.stderr}',
        );

        final result = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--policy=${policyFile.path}',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(result.exitCode, 1, reason: '${result.stderr}');

        final stdoutText = result.stdout as String;
        final jsonStartIndex = stdoutText.indexOf('{');
        expect(jsonStartIndex, isNonNegative, reason: stdoutText);
        final decoded =
            jsonDecode(stdoutText.substring(jsonStartIndex))
                as Map<String, dynamic>;

        expect(
          decoded['alertFailurePolicyByScenarioSet'],
          containsPair(
            'replay',
            containsPair(
              'byCategory',
              containsPair(
                'monitoring_watch',
                containsPair(
                  'severityByScope',
                  containsPair('specialist_degradation', 'medium'),
                ),
              ),
            ),
          ),
        );
        expect(decoded['historyAlertSummary'], containsPair('low', 1));
        expect(decoded['alertFailureTriggered'], isTrue);
        expect(decoded['alertFailureCount'], 1);
        expect(decoded['alertFailureSummary'], containsPair('medium', 1));
        expect(
          decoded['alertFailurePolicySummary'],
          containsPair(
            'scope_severity_override:specialist_degradation:medium',
            1,
          ),
        );
        expect(
          decoded['alertFailurePolicyTypeSummary'],
          containsPair('scope_severity_override', 1),
        );
        expect(
          decoded['alertFailurePolicySourceSummary'],
          containsPair('scenario_set_category', 1),
        );
        expect(
          decoded['historyAlertPolicyPromotedSpecialistSummary'],
          containsPair('specialist_degradation:low->medium', 1),
        );
        expect(
          decoded['historyAlertPolicyPromotedSpecialistSourceSummary'],
          containsPair('scenario_set_category', 1),
        );
        final historyPromotedFocus =
            decoded['historyAlertPolicyPromotedSpecialistFocus']
                as Map<String, dynamic>;
        expect(historyPromotedFocus['scope'], 'specialist_degradation');
        expect(historyPromotedFocus['originalSeverity'], 'low');
        expect(historyPromotedFocus['severity'], 'medium');
        expect(
          historyPromotedFocus['policyMatchType'],
          'scope_severity_override',
        );
        expect(
          historyPromotedFocus['policyMatchValue'],
          'specialist_degradation:medium',
        );
        expect(
          historyPromotedFocus['policyMatchSource'],
          'scenario_set_category',
        );
        expect(
          decoded['historyFocusSummary'],
          containsPair(
            'topPolicyPromotedSpecialistScenario',
            allOf(
              containsPair(
                'scenarioId',
                'monitoring_review_action_cctv_delay_v1',
              ),
              containsPair('scope', 'specialist_degradation'),
              containsPair('originalSeverity', 'low'),
              containsPair('promotedSeverity', 'medium'),
              containsPair('policyMatchSource', 'scenario_set_category'),
            ),
          ),
        );
        expect(
          decoded['alertFailurePolicyPromotedSpecialistSummary'],
          containsPair('specialist_degradation:low->medium', 1),
        );
        expect(
          decoded['alertFailurePolicyPromotedSpecialistSourceSummary'],
          containsPair('scenario_set_category', 1),
        );
        final alertFailurePromotedFocus =
            decoded['alertFailurePolicyPromotedSpecialistFocus']
                as Map<String, dynamic>;
        expect(alertFailurePromotedFocus['scope'], 'specialist_degradation');
        expect(alertFailurePromotedFocus['originalSeverity'], 'low');
        expect(alertFailurePromotedFocus['severity'], 'medium');
        final historyAlerts = (decoded['historyAlerts'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);
        final promotedHistoryAlert = historyAlerts
            .where(
              (alert) => alert['scope']?.toString() == 'specialist_degradation',
            )
            .single;
        expect(promotedHistoryAlert['severity'], 'low');
        expect(promotedHistoryAlert['baseSeverity'], 'low');
        expect(promotedHistoryAlert['effectiveSeverity'], 'medium');
        expect(promotedHistoryAlert['effectiveSeverityChanged'], isTrue);
        expect(promotedHistoryAlert['effectiveSeverityPromoted'], isTrue);
        expect(promotedHistoryAlert['effectiveSeverityDemoted'], isFalse);
        expect(promotedHistoryAlert['severityTransition'], 'low->medium');
        expect(
          promotedHistoryAlert['effectiveSeverityPolicyMatchType'],
          'scope_severity_override',
        );
        expect(
          promotedHistoryAlert['effectiveSeverityPolicyValue'],
          'specialist_degradation:medium',
        );
        expect(
          promotedHistoryAlert['effectiveSeverityPolicySource'],
          'scenario_set_category',
        );
        final policyFocus =
            decoded['alertFailurePolicyFocus'] as Map<String, dynamic>;
        expect(policyFocus['policyMatchType'], 'scope_severity_override');
        expect(
          policyFocus['policyMatchValue'],
          'specialist_degradation:medium',
        );
        expect(policyFocus['policyMatchSource'], 'scenario_set_category');
        expect(policyFocus['suppressed'], isFalse);
        expect(policyFocus['scope'], 'specialist_degradation');
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
        if (policyDirectory.existsSync()) {
          policyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool applies per-scenario-id scope severity overrides for specialist constraint replay alerts',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-scenario-scope-input-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-scenario-scope-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-scenario-scope-history-',
      );
      final policyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-scenario-scope-policy-',
      );

      try {
        final sourceScenario = File(
          '${Directory.current.path}/simulations/scenarios/monitoring/scenario_monitoring_review_action_hard_constraint_conflict_v1.json',
        );
        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_monitoring_review_action_hard_constraint_conflict_v1.json',
        );
        await scenarioFile.writeAsString(await sourceScenario.readAsString());

        final policyFile = File('${policyDirectory.path}/scenario_policy.json');
        await policyFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
            'alertFailure': <String, dynamic>{
              'threshold': 'critical',
              'byScenarioSet': <String, dynamic>{
                'replay': <String, dynamic>{
                  'threshold': 'critical',
                  'byScenarioId': <String, dynamic>{
                    'monitoring_review_action_hard_constraint_conflict_v1':
                        <String, dynamic>{
                          'threshold': 'medium',
                          'severityByScope': <String, dynamic>{
                            'specialist_constraint': 'medium',
                          },
                        },
                  },
                },
              },
            },
          }),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final seedHistoryResult = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(
          seedHistoryResult.exitCode,
          0,
          reason: '${seedHistoryResult.stderr}',
        );

        final result = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--policy=${policyFile.path}',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(result.exitCode, 1, reason: '${result.stderr}');

        final stdoutText = result.stdout as String;
        final jsonStartIndex = stdoutText.indexOf('{');
        expect(jsonStartIndex, isNonNegative, reason: stdoutText);
        final decoded =
            jsonDecode(stdoutText.substring(jsonStartIndex))
                as Map<String, dynamic>;

        expect(
          decoded['alertFailurePolicyByScenarioSet'],
          containsPair(
            'replay',
            containsPair(
              'byScenarioId',
              containsPair(
                'monitoring_review_action_hard_constraint_conflict_v1',
                containsPair(
                  'severityByScope',
                  containsPair('specialist_constraint', 'medium'),
                ),
              ),
            ),
          ),
        );
        expect(decoded['historyAlertSummary'], containsPair('low', 2));
        expect(decoded['alertFailureTriggered'], isTrue);
        expect(decoded['alertFailureCount'], 1);
        expect(decoded['alertFailureSummary'], containsPair('medium', 1));
        expect(
          decoded['alertFailurePolicySummary'],
          containsPair(
            'scope_severity_override:specialist_constraint:medium',
            1,
          ),
        );
        expect(
          decoded['alertFailurePolicyTypeSummary'],
          containsPair('scope_severity_override', 1),
        );
        expect(
          decoded['alertFailurePolicySourceSummary'],
          containsPair('scenario_set_scenario_id', 1),
        );
        final policyFocus =
            decoded['alertFailurePolicyFocus'] as Map<String, dynamic>;
        expect(policyFocus['policyMatchType'], 'scope_severity_override');
        expect(policyFocus['policyMatchValue'], 'specialist_constraint:medium');
        expect(policyFocus['policyMatchSource'], 'scenario_set_scenario_id');
        expect(policyFocus['suppressed'], isFalse);
        expect(policyFocus['scope'], 'specialist_constraint');
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
        if (policyDirectory.existsSync()) {
          policyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool surfaces policy-promoted replay risk in plain-text history focus',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-promoted-replay-risk-console-input-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-promoted-replay-risk-console-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-promoted-replay-risk-console-history-',
      );

      try {
        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_monitoring_priority_sequence_review_track_validation_v1.json',
        );
        await scenarioFile.writeAsString(
          await File(
            '${Directory.current.path}/simulations/scenarios/monitoring/scenario_monitoring_priority_sequence_review_track_validation_v1.json',
          ).readAsString(),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final commandArgs = <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--history',
          '--policy=simulations/scenario_policy.json',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ];

        final firstRun = await Process.run(
          dartExecutable,
          commandArgs,
          workingDirectory: Directory.current.path,
        );
        expect(firstRun.exitCode, 0, reason: '${firstRun.stderr}');

        final secondRun = await Process.run(
          dartExecutable,
          commandArgs,
          workingDirectory: Directory.current.path,
        );
        expect(secondRun.exitCode, 1, reason: '${secondRun.stderr}');

        final stdoutText = secondRun.stdout as String;
        expect(stdoutText, contains('History focus:'));
        expect(
          stdoutText,
          contains(
            'policy-promoted replay risk: monitoring_priority_sequence_review_track_validation_v1',
          ),
        );
        expect(stdoutText, contains('promoted high -> critical'));
        expect(stdoutText, contains('source scenario_set_scenario_id'));
        expect(
          stdoutText,
          contains('History policy-promoted replay risk focus:'),
        );
        expect(
          stdoutText,
          contains(
            'scope_severity_override sequence_fallback:critical from scenario_set_scenario_id, promoted high -> critical',
          ),
        );
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool surfaces policy-promoted specialist risk in plain-text history focus',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-promoted-console-input-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-promoted-console-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-promoted-console-history-',
      );
      final policyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-promoted-console-policy-',
      );

      try {
        const scenarioId =
            'parser_monitoring_review_action_policy_promoted_console_probe_v1';
        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_monitoring_review_action_policy_promoted_console_probe_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(
            await loadScenarioFixture(
              'simulations/scenarios/monitoring/scenario_monitoring_review_action_cctv_delay_v1.json',
              scenarioId: scenarioId,
              title: 'Policy promoted specialist console probe',
            ),
          ),
        );

        final policyFile = File('${policyDirectory.path}/scenario_policy.json');
        await policyFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
            'alertFailure': <String, dynamic>{
              'threshold': 'critical',
              'byScenarioSet': <String, dynamic>{
                'replay': <String, dynamic>{
                  'threshold': 'critical',
                  'byCategory': <String, dynamic>{
                    'monitoring_watch': <String, dynamic>{
                      'threshold': 'medium',
                      'severityByScope': <String, dynamic>{
                        'specialist_degradation': 'medium',
                      },
                    },
                  },
                },
              },
            },
          }),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final seedHistoryResult = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--history',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(
          seedHistoryResult.exitCode,
          0,
          reason: '${seedHistoryResult.stderr}',
        );

        final result = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--history',
          '--policy=${policyFile.path}',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(result.exitCode, 1, reason: '${result.stderr}');

        final stdoutText = result.stdout as String;
        expect(stdoutText, contains('History focus:'));
        expect(
          stdoutText,
          contains('policy-promoted specialist risk: $scenarioId'),
        );
        expect(stdoutText, contains('promoted low -> medium'));
        expect(stdoutText, contains('source scenario_set_category'));
        expect(
          stdoutText,
          contains('History policy-promoted specialist focus:'),
        );
        expect(
          stdoutText,
          contains(
            'scope_severity_override specialist_degradation:medium from scenario_set_category, promoted low -> medium',
          ),
        );
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
        if (policyDirectory.existsSync()) {
          policyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool respects policy denylist when evaluating alert failures',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-deny-input-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-deny-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-deny-history-',
      );
      final policyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-policy-deny-policy-',
      );

      try {
        final sourceScenario = File(
          '${Directory.current.path}/simulations/scenarios/admin/scenario_admin_breaches_all_sites_validation_v1.json',
        );
        final failingScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        failingScenario['scenarioId'] =
            'parser_admin_breaches_all_sites_policy_deny_probe_v1';
        failingScenario['title'] =
            'Breaches across all sites policy deny probe';
        final failingExpectedOutcome =
            failingScenario['expectedOutcome'] as Map<String, dynamic>;
        failingExpectedOutcome['expectedRoute'] = 'admin_wrong_route';

        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_admin_breaches_all_sites_policy_deny_probe_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(failingScenario),
        );

        final policyFile = File('${policyDirectory.path}/scenario_policy.json');
        await policyFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
            'alertFailure': <String, dynamic>{
              'threshold': 'critical',
              'includeStatuses': <String>['locked_validation'],
              'excludeCategories': <String>['admin_portfolio_read'],
            },
          }),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final seedHistoryResult = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(
          seedHistoryResult.exitCode,
          1,
          reason: '${seedHistoryResult.stderr}',
        );

        final repairedScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        repairedScenario['scenarioId'] =
            'parser_admin_breaches_all_sites_policy_deny_probe_v1';
        repairedScenario['title'] =
            'Breaches across all sites policy deny probe';
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(repairedScenario),
        );

        final result = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--policy=${policyFile.path}',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(result.exitCode, 0, reason: '${result.stderr}');

        final stdoutText = result.stdout as String;
        final jsonStartIndex = stdoutText.indexOf('{');
        expect(jsonStartIndex, isNonNegative, reason: stdoutText);
        final decoded =
            jsonDecode(stdoutText.substring(jsonStartIndex))
                as Map<String, dynamic>;

        expect(
          decoded['alertFailureCategoryDenylist'],
          contains('admin_portfolio_read'),
        );
        expect(decoded['alertFailureTriggered'], isFalse);
        expect(decoded['alertFailureCount'], 0);
        expect(decoded['alertFailureSummary'], isEmpty);
        expect(decoded['alertFailureCategorySummary'], isNull);
        expect(decoded['alertFailureCategoryFieldSummary'], isNull);
        expect(decoded['alertFailureScenarioSummary'], isNull);
        expect(decoded['alertFailureScenarioFieldSummary'], isNull);
        expect(decoded['alertFailureFieldSummary'], isNull);
        expect(decoded['alertFailureTrendSummary'], isNull);
        expect(decoded['alertFailureScenarioSetSummary'], isNull);
        expect(decoded['alertFailureStatusSummary'], isNull);
        expect(decoded['alertFailureTagSummary'], isNull);
        expect(decoded['alertFailureTagFieldSummary'], isNull);
        expect(decoded['alertFailurePolicySummary'], isNull);
        expect(decoded['alertFailurePolicyTypeSummary'], isNull);
        expect(
          decoded['alertFailurePolicySuppressionSummary'],
          containsPair('suppressed', 2),
        );
        expect(decoded['alertFailurePolicySourceSummary'], isNull);
        final policyFocus =
            decoded['alertFailurePolicyFocus'] as Map<String, dynamic>;
        expect(policyFocus['policyMatchType'], 'category_denylist');
        expect(policyFocus['policyMatchValue'], 'admin_portfolio_read');
        expect(policyFocus['policyMatchSource'], 'default');
        expect(policyFocus['suppressed'], isTrue);
        expect(policyFocus['scope'], 'scenario_field');
        expect(
          policyFocus['scenarioId'],
          'parser_admin_breaches_all_sites_policy_deny_probe_v1',
        );
        expect(policyFocus['field'], 'expectedRoute');
        expect(policyFocus['severity'], 'critical');
        expect(policyFocus['trend'], 'watch');
        expect(policyFocus['count'], 1);
        final historyPolicyFocus =
            decoded['historyAlertPolicyFocus'] as Map<String, dynamic>;
        expect(historyPolicyFocus['policyMatchType'], 'category_denylist');
        expect(historyPolicyFocus['policyMatchValue'], 'admin_portfolio_read');
        expect(historyPolicyFocus['policyMatchSource'], 'default');
        expect(historyPolicyFocus['suppressed'], isTrue);
        expect(historyPolicyFocus['scope'], 'scenario_field');
        expect(
          historyPolicyFocus['scenarioId'],
          'parser_admin_breaches_all_sites_policy_deny_probe_v1',
        );
        expect(historyPolicyFocus['field'], 'expectedRoute');
        expect(historyPolicyFocus['severity'], 'critical');
        expect(historyPolicyFocus['trend'], 'watch');
        expect(historyPolicyFocus['count'], 1);
        expect(
          decoded['historyAlertPolicySummary'],
          containsPair('category_denylist:admin_portfolio_read', 2),
        );
        expect(
          decoded['historyAlertPolicyTypeSummary'],
          containsPair('category_denylist', 2),
        );
        expect(
          decoded['historyAlertPolicySuppressionSummary'],
          containsPair('suppressed', 2),
        );
        expect(
          decoded['historyAlertPolicySourceSummary'],
          containsPair('default', 2),
        );
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
        if (policyDirectory.existsSync()) {
          policyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool raises persistent sequence fallback alerts after repeated fallback runs',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-sequence-fallback-alert-input-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-sequence-fallback-alert-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-sequence-fallback-alert-history-',
      );

      try {
        const scenarioId =
            'parser_monitoring_priority_sequence_fallback_alert_probe_v1';
        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_monitoring_priority_sequence_fallback_alert_probe_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(
            await loadScenarioFixture(
              'simulations/scenarios/monitoring/scenario_monitoring_priority_sequence_review_track_validation_v1.json',
              scenarioId: scenarioId,
              title: 'Sequence fallback alert probe',
            ),
          ),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final commandArgs = <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--fail-on-alert=high',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ];

        final firstRun = await Process.run(
          dartExecutable,
          commandArgs,
          workingDirectory: Directory.current.path,
        );
        expect(firstRun.exitCode, 0, reason: '${firstRun.stderr}');

        final secondRun = await Process.run(
          dartExecutable,
          commandArgs,
          workingDirectory: Directory.current.path,
        );
        expect(secondRun.exitCode, 1, reason: '${secondRun.stderr}');

        final stdoutText = secondRun.stdout as String;
        final jsonStartIndex = stdoutText.indexOf('{');
        expect(jsonStartIndex, isNonNegative, reason: stdoutText);
        final decoded =
            jsonDecode(stdoutText.substring(jsonStartIndex))
                as Map<String, dynamic>;

        expect(decoded['alertFailureTriggered'], isTrue);
        expect(decoded['alertFailureCount'], 1);
        expect(decoded['historyAlertSummary'], containsPair('high', 1));
        expect(decoded['alertFailureSummary'], containsPair('high', 1));
        expect(
          decoded['historyAlertSequenceFallbackSummary'],
          containsPair(
            scenarioId,
            allOf(
              containsPair('count', 2),
              containsPair('trend', 'stabilizing'),
              containsPair('severity', 'high'),
              containsPair('latestBranch', 'active'),
              containsPair(
                'latestSignature',
                'active_in_run:replayPolicy:sequenceFallback:tacticalTrack',
              ),
              containsPair('latestTarget', 'tacticalTrack'),
            ),
          ),
        );
        expect(
          decoded['alertFailureSequenceFallbackSummary'],
          containsPair(scenarioId, containsPair('severity', 'high')),
        );
        expect(
          decoded['historyAlertFocus'],
          allOf(
            containsPair('scope', 'sequence_fallback'),
            containsPair('scenarioId', scenarioId),
            containsPair('field', 'sequenceFallbackBranch'),
            containsPair('severity', 'high'),
            containsPair('trend', 'stabilizing'),
            containsPair('count', 2),
          ),
        );
        expect(
          decoded['alertFailureFocus'],
          allOf(
            containsPair('scope', 'sequence_fallback'),
            containsPair('scenarioId', scenarioId),
            containsPair('field', 'sequenceFallbackBranch'),
            containsPair('severity', 'high'),
            containsPair('trend', 'stabilizing'),
            containsPair('count', 2),
          ),
        );
        final historyAlerts = (decoded['historyAlerts'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);
        final sequenceFallbackAlert = historyAlerts.singleWhere(
          (alert) => alert['scope']?.toString() == 'sequence_fallback',
        );
        expect(sequenceFallbackAlert['severity'], 'high');
        expect(sequenceFallbackAlert['count'], 2);
        expect(sequenceFallbackAlert['trend'], 'stabilizing');
        expect(sequenceFallbackAlert['latestTarget'], 'tacticalTrack');
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool marks sequence fallback as cleared_after_run when dispatch path is restored',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-sequence-fallback-recovery-input-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-sequence-fallback-recovery-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-sequence-fallback-recovery-history-',
      );

      try {
        const scenarioId =
            'parser_monitoring_priority_sequence_fallback_recovery_probe_v1';
        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_monitoring_priority_sequence_fallback_recovery_probe_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(
            await loadScenarioFixture(
              'simulations/scenarios/monitoring/scenario_monitoring_priority_sequence_review_track_validation_v1.json',
              scenarioId: scenarioId,
              title: 'Sequence fallback recovery probe',
            ),
          ),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final commandArgs = <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ];

        final firstRun = await Process.run(
          dartExecutable,
          commandArgs,
          workingDirectory: Directory.current.path,
        );
        expect(firstRun.exitCode, 0, reason: '${firstRun.stderr}');

        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(
            await loadScenarioFixture(
              'simulations/scenarios/monitoring/scenario_monitoring_priority_sequence_review_dispatch_validation_v1.json',
              scenarioId: scenarioId,
              title: 'Sequence fallback recovery probe',
            ),
          ),
        );

        final secondRun = await Process.run(
          dartExecutable,
          commandArgs,
          workingDirectory: Directory.current.path,
        );
        expect(secondRun.exitCode, 0, reason: '${secondRun.stderr}');

        final stdoutText = secondRun.stdout as String;
        final jsonStartIndex = stdoutText.indexOf('{');
        expect(jsonStartIndex, isNonNegative, reason: stdoutText);
        final decoded =
            jsonDecode(stdoutText.substring(jsonStartIndex))
                as Map<String, dynamic>;

        expect(decoded['sequenceFallbackLifecycleSummary'], isEmpty);
        expect(decoded['sequenceFallbackLifecycleSignatureSummary'], isEmpty);
        expect(
          decoded['historySequenceFallbackLifecycleSummary'],
          containsPair(
            'cleared_after_run',
            allOf(
              containsPair('scenarioCount', 1),
              containsPair('passedCount', 1),
              containsPair('failedCount', 0),
            ),
          ),
        );
        expect(
          decoded['historySequenceFallbackLifecycleSignatureSummary'],
          containsPair(
            'cleared_after_run:dispatchBoard:tacticalTrack',
            containsPair('passedCount', 1),
          ),
        );
        expect(
          decoded['historyScenarioSequenceFallbackSummary'],
          containsPair(scenarioId, isA<Map<String, dynamic>>()),
        );
        final historyFallbackSummary =
            (decoded['historyScenarioSequenceFallbackSummary']
                    as Map<String, dynamic>)[scenarioId]
                as Map<String, dynamic>;
        expect(historyFallbackSummary['runCount'], 2);
        expect(historyFallbackSummary['fallbackRunCount'], 1);
        expect(historyFallbackSummary['clearedAfterRunCount'], 1);
        expect(historyFallbackSummary['activeInRunCount'], 1);
        expect(historyFallbackSummary['latestBranch'], 'clean');
        expect(historyFallbackSummary['latestLifecycle'], 'cleared_after_run');
        expect(
          historyFallbackSummary['latestLifecycleSignature'],
          'cleared_after_run:dispatchBoard:tacticalTrack',
        );
        expect(historyFallbackSummary['latestTarget'], 'dispatchBoard');
        expect(historyFallbackSummary['latestRestoredTarget'], 'dispatchBoard');
        expect(
          historyFallbackSummary['latestSummary'],
          'Dispatch Board is back in front after replay fallback cleared from Tactical Track.',
        );
        expect(historyFallbackSummary['trend'], 'clean_again');
        expect(historyFallbackSummary['recoveryTrend'], 'clean_again');
        expect(
          decoded['historyFocusSummary'],
          containsPair(
            'topSequenceFallbackRecoveryScenario',
            allOf(
              containsPair('scenarioId', scenarioId),
              containsPair('clearedAfterRunCount', 1),
              containsPair('recoveryTrend', 'clean_again'),
              containsPair('latestTarget', 'dispatchBoard'),
              containsPair('latestRestoredTarget', 'dispatchBoard'),
            ),
          ),
        );
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool surfaces sequence fallback recovery in plain-text history focus',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-sequence-fallback-console-input-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-sequence-fallback-console-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-sequence-fallback-console-history-',
      );

      try {
        const scenarioId =
            'parser_monitoring_priority_sequence_fallback_console_probe_v1';
        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_monitoring_priority_sequence_fallback_console_probe_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(
            await loadScenarioFixture(
              'simulations/scenarios/monitoring/scenario_monitoring_priority_sequence_review_track_validation_v1.json',
              scenarioId: scenarioId,
              title: 'Sequence fallback console probe',
            ),
          ),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final commandArgs = <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--history',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ];

        final firstRun = await Process.run(
          dartExecutable,
          commandArgs,
          workingDirectory: Directory.current.path,
        );
        expect(firstRun.exitCode, 0, reason: '${firstRun.stderr}');

        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(
            await loadScenarioFixture(
              'simulations/scenarios/monitoring/scenario_monitoring_priority_sequence_review_dispatch_validation_v1.json',
              scenarioId: scenarioId,
              title: 'Sequence fallback console probe',
            ),
          ),
        );

        final secondRun = await Process.run(
          dartExecutable,
          commandArgs,
          workingDirectory: Directory.current.path,
        );
        expect(secondRun.exitCode, 0, reason: '${secondRun.stderr}');

        final stdoutText = secondRun.stdout as String;
        expect(stdoutText, contains('History focus:'));
        expect(stdoutText, contains('sequence fallback recovery: $scenarioId'));
        expect(stdoutText, contains('History sequence fallback lifecycle:'));
        expect(stdoutText, contains('- cleared_after_run: 1/1 passed'));
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool marks history as clean_again when a failing scenario recovers',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-clean-again-input-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-clean-again-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-clean-again-history-',
      );

      try {
        final sourceScenario = File(
          '${Directory.current.path}/simulations/scenarios/admin/scenario_admin_breaches_all_sites_v1.json',
        );
        final baseScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        baseScenario['scenarioId'] =
            'parser_admin_breaches_all_sites_clean_again_probe_v1';
        baseScenario['title'] = 'Breaches across all sites clean again probe';
        final failingExpectedOutcome =
            baseScenario['expectedOutcome'] as Map<String, dynamic>;
        failingExpectedOutcome['expectedRoute'] = 'admin_wrong_route';

        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_admin_breaches_all_sites_clean_again_probe_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(baseScenario),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final commandArgs = <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ];

        final firstRun = await Process.run(
          dartExecutable,
          commandArgs,
          workingDirectory: Directory.current.path,
        );
        expect(firstRun.exitCode, 1, reason: '${firstRun.stderr}');

        final repairedScenario =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        repairedScenario['scenarioId'] =
            'parser_admin_breaches_all_sites_clean_again_probe_v1';
        repairedScenario['title'] =
            'Breaches across all sites clean again probe';
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(repairedScenario),
        );

        final secondRun = await Process.run(
          dartExecutable,
          commandArgs,
          workingDirectory: Directory.current.path,
        );
        expect(secondRun.exitCode, 0, reason: '${secondRun.stderr}');

        final stdoutText = secondRun.stdout as String;
        final jsonStartIndex = stdoutText.indexOf('{');
        expect(jsonStartIndex, isNonNegative, reason: stdoutText);
        final decoded =
            jsonDecode(stdoutText.substring(jsonStartIndex))
                as Map<String, dynamic>;

        expect(
          decoded['historyCategorySummary'],
          containsPair(
            'admin_portfolio_read',
            allOf(
              containsPair('runCount', 2),
              containsPair('passedCount', 1),
              containsPair('failedCount', 1),
              containsPair('trend', 'clean_again'),
            ),
          ),
        );
        expect(
          decoded['historyCategoryMismatchFieldTrendSummary'],
          containsPair(
            'admin_portfolio_read',
            containsPair(
              'expectedRoute',
              allOf(
                containsPair('count', 1),
                containsPair('trend', 'clean_again'),
              ),
            ),
          ),
        );
        expect(
          decoded['historyScenarioSummary'],
          containsPair(
            'parser_admin_breaches_all_sites_clean_again_probe_v1',
            allOf(
              containsPair('runCount', 2),
              containsPair('passedCount', 1),
              containsPair('failedCount', 1),
              containsPair('trend', 'clean_again'),
            ),
          ),
        );
        expect(
          decoded['historyScenarioMismatchFieldTrendSummary'],
          containsPair(
            'parser_admin_breaches_all_sites_clean_again_probe_v1',
            containsPair(
              'expectedRoute',
              allOf(
                containsPair('count', 1),
                containsPair('trend', 'clean_again'),
              ),
            ),
          ),
        );
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool reports mismatch fields clearly when a scenario fails',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-failure-input-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-failure-latest-',
      );

      try {
        final sourceScenario = File(
          '${Directory.current.path}/simulations/scenarios/admin/scenario_admin_breaches_all_sites_v1.json',
        );
        final scenarioJson =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        scenarioJson['scenarioId'] =
            'parser_admin_breaches_all_sites_failure_probe_v1';
        scenarioJson['title'] = 'Breaches across all sites failure probe';
        final expectedOutcome =
            scenarioJson['expectedOutcome'] as Map<String, dynamic>;
        expectedOutcome['expectedRoute'] = 'admin_wrong_route';
        expectedOutcome['expectedUiState'] = <String, dynamic>{
          'surface': 'admin_wrong_surface',
          'legacyWorkspaceVisible': false,
        };

        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_admin_breaches_all_sites_failure_probe_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(scenarioJson),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final result = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--results-dir=${latestDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);

        expect(result.exitCode, 1, reason: '${result.stderr}');

        final stdoutText = result.stdout as String;
        final jsonStartIndex = stdoutText.indexOf('{');
        expect(jsonStartIndex, isNonNegative, reason: stdoutText);
        final decoded =
            jsonDecode(stdoutText.substring(jsonStartIndex))
                as Map<String, dynamic>;

        expect(decoded['scenarioCount'], 1);
        expect(decoded['passedCount'], 0);
        expect(decoded['failedCount'], 1);
        expect(
          decoded['scenarioCategorySummary'],
          containsPair(
            'admin_portfolio_read',
            allOf(
              containsPair('scenarioCount', 1),
              containsPair('failedCount', 1),
            ),
          ),
        );
        expect(
          decoded['mismatchFieldSummary'],
          allOf(
            containsPair('expectedRoute', 1),
            containsPair('expectedUiState', 1),
          ),
        );
        expect(
          decoded['categoryMismatchFieldSummary'],
          containsPair(
            'admin_portfolio_read',
            allOf(
              containsPair('expectedRoute', 1),
              containsPair('expectedUiState', 1),
            ),
          ),
        );
        expect(
          decoded['scenarioSetSummary'],
          containsPair(
            'replay',
            allOf(
              containsPair('scenarioCount', 1),
              containsPair('failedCount', 1),
            ),
          ),
        );
        expect(
          decoded['scenarioStatusSummary'],
          containsPair(
            'draft',
            allOf(
              containsPair('scenarioCount', 1),
              containsPair('failedCount', 1),
            ),
          ),
        );

        final results = decoded['results'] as List<dynamic>;
        expect(results, hasLength(1));
        final runRecord = results.single as Map<String, dynamic>;
        expect(
          runRecord['scenarioId'],
          'parser_admin_breaches_all_sites_failure_probe_v1',
        );
        expect(runRecord['passed'], isFalse);
        expect(runRecord['mismatchCount'], 2);
        expect(
          runRecord['mismatchFields'],
          containsAll(<String>['expectedRoute', 'expectedUiState']),
        );

        final latestFiles = latestDirectory
            .listSync()
            .whereType<File>()
            .map((file) => file.path.split('/').last)
            .toList(growable: false);
        expect(
          latestFiles,
          contains(
            'result_parser_admin_breaches_all_sites_failure_probe_v1.json',
          ),
        );
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool executes only validation scenarios when filtered by set',
    () async {
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-validation-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-validation-history-',
      );

      try {
        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final result = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--set=validation',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          'simulations/scenarios',
        ], workingDirectory: Directory.current.path);

        expect(result.exitCode, 0, reason: '${result.stderr}');

        final stdoutText = result.stdout as String;
        final jsonStartIndex = stdoutText.indexOf('{');
        expect(jsonStartIndex, isNonNegative, reason: stdoutText);
        final decoded =
            jsonDecode(stdoutText.substring(jsonStartIndex))
                as Map<String, dynamic>;

        expect(decoded['scenarioSetFilter'], 'validation');
        expect(decoded['scenarioCount'], 19);
        expect(decoded['passedCount'], 19);
        expect(decoded['failedCount'], 0);
        expect(decoded['categoryMismatchFieldSummary'], isEmpty);
        expect(
          decoded['scenarioCategorySummary'],
          allOf(
            containsPair(
              'admin_portfolio_read',
              allOf(
                containsPair('scenarioCount', 1),
                containsPair('passedCount', 1),
              ),
            ),
            containsPair(
              'track_ui_state',
              allOf(
                containsPair('scenarioCount', 3),
                containsPair('passedCount', 3),
              ),
            ),
            containsPair(
              'guard_ops_read',
              allOf(
                containsPair('scenarioCount', 2),
                containsPair('passedCount', 2),
              ),
            ),
            containsPair(
              'client_comms',
              allOf(
                containsPair('scenarioCount', 3),
                containsPair('passedCount', 3),
              ),
            ),
            containsPair(
              'monitoring_watch',
              allOf(
                containsPair('scenarioCount', 7),
                containsPair('passedCount', 7),
              ),
            ),
            containsPair(
              'dispatch_flow',
              allOf(
                containsPair('scenarioCount', 2),
                containsPair('passedCount', 2),
              ),
            ),
            containsPair(
              'incident_timeline',
              allOf(
                containsPair('scenarioCount', 1),
                containsPair('passedCount', 1),
              ),
            ),
          ),
        );
        expect(
          decoded['scenarioSetSummary'],
          containsPair(
            'validation',
            allOf(
              containsPair('scenarioCount', 19),
              containsPair('passedCount', 19),
              containsPair('failedCount', 0),
            ),
          ),
        );
        expect(
          decoded['scenarioStatusSummary'],
          containsPair(
            'locked_validation',
            allOf(
              containsPair('scenarioCount', 16),
              containsPair('passedCount', 16),
              containsPair('failedCount', 0),
            ),
          ),
        );
        expect(
          decoded['scenarioStatusSummary'],
          containsPair(
            'validation_candidate',
            allOf(
              containsPair('scenarioCount', 3),
              containsPair('passedCount', 3),
              containsPair('failedCount', 0),
            ),
          ),
        );

        final results = decoded['results'] as List<dynamic>;
        expect(results, hasLength(19));

        final scenarioIds = results
            .map((entry) => (entry as Map<String, dynamic>)['scenarioId'])
            .toList(growable: false);
        expect(
          scenarioIds,
          containsAll(<String>[
            'parser_admin_breaches_all_sites_validation_v1',
            'track_fresh_entry_modern_overview_validation_v1',
            'track_parent_rebuild_preserves_session_validation_v1',
            'track_live_ops_handoff_validation_v1',
            'guard_status_echo_3_validation_v1',
            'patrol_report_guard001_validation_v1',
            'client_comms_draft_update_validation_v1',
            'client_comms_attention_queue_pending_draft_validation_v1',
            'client_comms_queue_state_cycle_validation_v1',
            'monitoring_watchlist_match_review_validation_v1',
            'monitoring_review_action_cctv_handoff_validation_v1',
            'monitoring_priority_sequence_review_dispatch_validation_v1',
            'monitoring_priority_sequence_dispatch_track_validation_v1',
            'monitoring_priority_sequence_review_track_conflict_validation_v1',
            'monitoring_priority_sequence_review_track_validation_v1',
            'monitoring_priority_sequence_review_dispatch_track_validation_v1',
            'dispatch_today_summary_validation_v1',
            'dispatch_attention_queue_handoff_validation_v1',
            'incident_timeline_summary_validation_v1',
          ]),
        );
        expect(
          scenarioIds,
          isNot(contains('parser_admin_breaches_all_sites_v1')),
        );

        for (final entry in results.cast<Map<String, dynamic>>()) {
          expect(entry['scenarioSet'], 'validation');
          expect(
            entry['status'],
            anyOf('locked_validation', 'validation_candidate'),
          );
          expect(entry['passed'], isTrue);
          expect(entry['historyFilePath'], isNotNull);
        }

        final latestFiles = latestDirectory
            .listSync()
            .whereType<File>()
            .map((file) => file.path.split('/').last)
            .toList(growable: false);
        expect(
          latestFiles,
          contains('result_parser_admin_breaches_all_sites_validation_v1.json'),
        );
        expect(
          latestFiles,
          contains(
            'result_track_fresh_entry_modern_overview_validation_v1.json',
          ),
        );
        expect(
          latestFiles,
          contains(
            'result_track_parent_rebuild_preserves_session_validation_v1.json',
          ),
        );
        expect(
          latestFiles,
          contains('result_track_live_ops_handoff_validation_v1.json'),
        );
        expect(
          latestFiles,
          contains('result_guard_status_echo_3_validation_v1.json'),
        );
        expect(
          latestFiles,
          contains('result_patrol_report_guard001_validation_v1.json'),
        );
        expect(
          latestFiles,
          contains('result_client_comms_draft_update_validation_v1.json'),
        );
        expect(
          latestFiles,
          contains(
            'result_client_comms_attention_queue_pending_draft_validation_v1.json',
          ),
        );
        expect(
          latestFiles,
          contains('result_client_comms_queue_state_cycle_validation_v1.json'),
        );
        expect(
          latestFiles,
          contains(
            'result_monitoring_watchlist_match_review_validation_v1.json',
          ),
        );
        expect(
          latestFiles,
          contains(
            'result_monitoring_review_action_cctv_handoff_validation_v1.json',
          ),
        );
        expect(
          latestFiles,
          contains(
            'result_monitoring_priority_sequence_review_dispatch_validation_v1.json',
          ),
        );
        expect(
          latestFiles,
          contains(
            'result_monitoring_priority_sequence_dispatch_track_validation_v1.json',
          ),
        );
        expect(
          latestFiles,
          contains(
            'result_monitoring_priority_sequence_review_track_validation_v1.json',
          ),
        );
        expect(
          latestFiles,
          contains(
            'result_monitoring_priority_sequence_review_dispatch_track_validation_v1.json',
          ),
        );
        expect(
          latestFiles,
          contains('result_dispatch_today_summary_validation_v1.json'),
        );
        expect(
          latestFiles,
          contains(
            'result_dispatch_attention_queue_handoff_validation_v1.json',
          ),
        );
        expect(
          latestFiles,
          contains('result_incident_timeline_summary_validation_v1.json'),
        );
      } finally {
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool executes only locked validation scenarios when filtered by status',
    () async {
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-locked-validation-latest-',
      );

      try {
        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final result = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--set=validation',
          '--status=locked_validation',
          '--results-dir=${latestDirectory.path}',
          'simulations/scenarios',
        ], workingDirectory: Directory.current.path);

        expect(result.exitCode, 0, reason: '${result.stderr}');

        final stdoutText = result.stdout as String;
        final jsonStartIndex = stdoutText.indexOf('{');
        expect(jsonStartIndex, isNonNegative, reason: stdoutText);
        final decoded =
            jsonDecode(stdoutText.substring(jsonStartIndex))
                as Map<String, dynamic>;

        expect(decoded['scenarioSetFilter'], 'validation');
        expect(decoded['scenarioStatusFilter'], 'locked_validation');
        expect(decoded['scenarioCount'], 16);
        expect(decoded['passedCount'], 16);
        expect(decoded['failedCount'], 0);
        expect(decoded['categoryMismatchFieldSummary'], isEmpty);
        expect(
          decoded['scenarioCategorySummary'],
          allOf(
            containsPair(
              'admin_portfolio_read',
              allOf(
                containsPair('scenarioCount', 1),
                containsPair('passedCount', 1),
              ),
            ),
            containsPair(
              'track_ui_state',
              allOf(
                containsPair('scenarioCount', 3),
                containsPair('passedCount', 3),
              ),
            ),
            containsPair(
              'guard_ops_read',
              allOf(
                containsPair('scenarioCount', 2),
                containsPair('passedCount', 2),
              ),
            ),
            containsPair(
              'client_comms',
              allOf(
                containsPair('scenarioCount', 3),
                containsPair('passedCount', 3),
              ),
            ),
            containsPair(
              'monitoring_watch',
              allOf(
                containsPair('scenarioCount', 6),
                containsPair('passedCount', 6),
              ),
            ),
            containsPair(
              'dispatch_flow',
              allOf(
                containsPair('scenarioCount', 1),
                containsPair('passedCount', 1),
              ),
            ),
          ),
        );
        expect(
          decoded['scenarioSetSummary'],
          containsPair(
            'validation',
            allOf(
              containsPair('scenarioCount', 16),
              containsPair('passedCount', 16),
            ),
          ),
        );
        expect(
          decoded['scenarioStatusSummary'],
          containsPair(
            'locked_validation',
            allOf(
              containsPair('scenarioCount', 16),
              containsPair('passedCount', 16),
            ),
          ),
        );

        final results = decoded['results'] as List<dynamic>;
        final scenarioIds = results
            .map((entry) => (entry as Map<String, dynamic>)['scenarioId'])
            .toList(growable: false);
        expect(
          scenarioIds,
          containsAll(<String>[
            'parser_admin_breaches_all_sites_validation_v1',
            'track_fresh_entry_modern_overview_validation_v1',
            'track_parent_rebuild_preserves_session_validation_v1',
            'track_live_ops_handoff_validation_v1',
            'guard_status_echo_3_validation_v1',
            'patrol_report_guard001_validation_v1',
            'client_comms_draft_update_validation_v1',
            'client_comms_attention_queue_pending_draft_validation_v1',
            'client_comms_queue_state_cycle_validation_v1',
            'monitoring_review_action_cctv_handoff_validation_v1',
            'monitoring_priority_sequence_review_dispatch_validation_v1',
            'monitoring_priority_sequence_dispatch_track_validation_v1',
            'monitoring_priority_sequence_review_track_conflict_validation_v1',
            'monitoring_priority_sequence_review_track_validation_v1',
            'monitoring_priority_sequence_review_dispatch_track_validation_v1',
            'dispatch_attention_queue_handoff_validation_v1',
          ]),
        );

        for (final entry in results.cast<Map<String, dynamic>>()) {
          expect(entry['scenarioSet'], 'validation');
          expect(entry['status'], 'locked_validation');
          expect(entry['passed'], isTrue);
        }
      } finally {
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool lists replay scenarios without executing them',
    () async {
      final result = await Process.run(
        (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart',
        <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--list',
          '--set=replay',
          'simulations/scenarios',
        ],
        workingDirectory: Directory.current.path,
      );

      expect(result.exitCode, 0, reason: '${result.stderr}');

      final stdoutText = result.stdout as String;
      final jsonStartIndex = stdoutText.indexOf('{');
      expect(jsonStartIndex, isNonNegative, reason: stdoutText);
      final decoded =
          jsonDecode(stdoutText.substring(jsonStartIndex))
              as Map<String, dynamic>;

      expect(decoded['scenarioSetFilter'], 'replay');
      expect(decoded['scenarioCount'], greaterThanOrEqualTo(9));
      expect(
        decoded['categoryCounts'],
        containsPair('admin_portfolio_read', greaterThanOrEqualTo(3)),
      );
      expect(
        decoded['categoryCounts'],
        containsPair('track_ui_state', greaterThanOrEqualTo(2)),
      );

      final scenarios = decoded['scenarios'] as List<dynamic>;
      final scenarioIds = scenarios
          .map((entry) => (entry as Map<String, dynamic>)['scenarioId'])
          .toList(growable: false);
      expect(scenarioIds, contains('parser_admin_breaches_all_sites_v1'));
      expect(scenarioIds, contains('track_fresh_entry_modern_overview_v1'));
      expect(scenarioIds, contains('dispatch_today_summary_v1'));
      expect(scenarioIds, contains('incident_timeline_summary_v1'));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool distinguishes recovered specialist branches from persistent ones in history',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-specialist-history-input-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-specialist-history-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-specialist-history-history-',
      );

      try {
        const scenarioId =
            'parser_monitoring_review_action_cctv_degradation_history_probe_v1';
        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_monitoring_review_action_cctv_degradation_history_probe_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(
            await loadScenarioFixture(
              'simulations/scenarios/monitoring/scenario_monitoring_review_action_cctv_delay_v1.json',
              scenarioId: scenarioId,
              title: 'CCTV degradation history probe',
            ),
          ),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final commandArgs = <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ];

        final firstRun = await Process.run(
          dartExecutable,
          commandArgs,
          workingDirectory: Directory.current.path,
        );
        expect(firstRun.exitCode, 0, reason: '${firstRun.stderr}');

        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(
            await loadScenarioFixture(
              'simulations/scenarios/monitoring/scenario_monitoring_review_action_cctv_signal_loss_track_v1.json',
              scenarioId: scenarioId,
              title: 'CCTV degradation history probe',
            ),
          ),
        );

        final secondRun = await Process.run(
          dartExecutable,
          commandArgs,
          workingDirectory: Directory.current.path,
        );
        expect(secondRun.exitCode, 0, reason: '${secondRun.stderr}');

        final stdoutText = secondRun.stdout as String;
        final jsonStartIndex = stdoutText.indexOf('{');
        expect(jsonStartIndex, isNonNegative, reason: stdoutText);
        final decoded =
            jsonDecode(stdoutText.substring(jsonStartIndex))
                as Map<String, dynamic>;

        expect(
          decoded['specialistDegradationBranchSummary'],
          containsPair('recovered', containsPair('passedCount', 1)),
        );
        expect(
          decoded['historySpecialistDegradationBranchSummary'],
          allOf(
            containsPair(
              'persistent',
              allOf(
                containsPair('scenarioCount', 1),
                containsPair('passedCount', 1),
                containsPair('failedCount', 0),
              ),
            ),
            containsPair(
              'recovered',
              allOf(
                containsPair('scenarioCount', 1),
                containsPair('passedCount', 1),
                containsPair('failedCount', 0),
              ),
            ),
          ),
        );
        expect(
          decoded['historySpecialistDegradationSignatureSummary'],
          allOf(
            containsPair(
              'persistent:cctv:delayed',
              containsPair('passedCount', 1),
            ),
            containsPair(
              'recovered:cctv:signal_lost',
              containsPair('passedCount', 1),
            ),
          ),
        );
        expect(
          decoded['historyScenarioSpecialistDegradationSummary'],
          containsPair(
            scenarioId,
            allOf(
              containsPair('runCount', 2),
              containsPair('degradedRunCount', 2),
              containsPair('persistentCount', 1),
              containsPair('recoveredCount', 1),
              containsPair('latestBranch', 'recovered'),
              containsPair('latestSignature', 'recovered:cctv:signal_lost'),
              containsPair('trend', 'clean_again'),
            ),
          ),
        );
        expect(decoded['historyAlertSpecialistDegradationSummary'], isEmpty);
        final specialistAlerts = (decoded['historyAlerts'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .where(
              (alert) => alert['scope']?.toString() == 'specialist_degradation',
            )
            .toList(growable: false);
        expect(specialistAlerts, isEmpty);
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool raises persistent specialist degradation alerts after a recovered branch regresses',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-specialist-alert-input-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-specialist-alert-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-specialist-alert-history-',
      );

      try {
        const scenarioId =
            'parser_monitoring_review_action_cctv_degradation_alert_probe_v1';
        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_monitoring_review_action_cctv_degradation_alert_probe_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(
            await loadScenarioFixture(
              'simulations/scenarios/monitoring/scenario_monitoring_review_action_cctv_signal_loss_track_v1.json',
              scenarioId: scenarioId,
              title: 'CCTV degradation alert probe',
            ),
          ),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final commandArgs = <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--fail-on-alert=medium',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ];

        final firstRun = await Process.run(
          dartExecutable,
          commandArgs,
          workingDirectory: Directory.current.path,
        );
        expect(firstRun.exitCode, 0, reason: '${firstRun.stderr}');

        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(
            await loadScenarioFixture(
              'simulations/scenarios/monitoring/scenario_monitoring_review_action_cctv_delay_v1.json',
              scenarioId: scenarioId,
              title: 'CCTV degradation alert probe',
            ),
          ),
        );

        final secondRun = await Process.run(
          dartExecutable,
          commandArgs,
          workingDirectory: Directory.current.path,
        );
        expect(secondRun.exitCode, 1, reason: '${secondRun.stderr}');

        final stdoutText = secondRun.stdout as String;
        final jsonStartIndex = stdoutText.indexOf('{');
        expect(jsonStartIndex, isNonNegative, reason: stdoutText);
        final decoded =
            jsonDecode(stdoutText.substring(jsonStartIndex))
                as Map<String, dynamic>;

        expect(
          decoded['historyScenarioSpecialistDegradationSummary'],
          containsPair(
            scenarioId,
            allOf(
              containsPair('runCount', 2),
              containsPair('degradedRunCount', 2),
              containsPair('persistentCount', 1),
              containsPair('recoveredCount', 1),
              containsPair('latestBranch', 'persistent'),
              containsPair('latestSignature', 'persistent:cctv:delayed'),
              containsPair('trend', 'worsening'),
            ),
          ),
        );
        expect(decoded['historyAlertSummary'], containsPair('medium', 1));
        expect(
          decoded['historyAlertFieldSummary'],
          containsPair('specialistDegradationBranch', 1),
        );
        expect(
          decoded['historyAlertSpecialistDegradationSummary'],
          containsPair(
            scenarioId,
            allOf(
              containsPair('count', 1),
              containsPair('trend', 'worsening'),
              containsPair('severity', 'medium'),
              containsPair('latestBranch', 'persistent'),
              containsPair('latestSignature', 'persistent:cctv:delayed'),
            ),
          ),
        );
        expect(
          decoded['historyAlertFocus'],
          allOf(
            containsPair('scope', 'specialist_degradation'),
            containsPair('field', 'specialistDegradationBranch'),
            containsPair('scenarioId', scenarioId),
            containsPair('trend', 'worsening'),
            containsPair('severity', 'medium'),
          ),
        );
        expect(decoded['alertFailureTriggered'], isTrue);
        expect(decoded['alertFailureCount'], 1);
        expect(decoded['alertFailureSummary'], containsPair('medium', 1));
        expect(
          decoded['alertFailureSpecialistDegradationSummary'],
          containsPair(
            scenarioId,
            containsPair('latestSignature', 'persistent:cctv:delayed'),
          ),
        );
        expect(
          decoded['alertFailureFocus'],
          allOf(
            containsPair('scope', 'specialist_degradation'),
            containsPair('field', 'specialistDegradationBranch'),
            containsPair('scenarioId', scenarioId),
            containsPair('trend', 'worsening'),
            containsPair('severity', 'medium'),
          ),
        );

        final specialistAlerts = (decoded['historyAlerts'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .where(
              (alert) => alert['scope']?.toString() == 'specialist_degradation',
            )
            .toList(growable: false);
        expect(specialistAlerts, hasLength(1));
        expect(
          specialistAlerts.single,
          allOf(
            containsPair('field', 'specialistDegradationBranch'),
            containsPair('trend', 'worsening'),
            containsPair('latestBranch', 'persistent'),
            containsPair(
              'latestSpecialistDegradationSignature',
              'persistent:cctv:delayed',
            ),
          ),
        );
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool raises persistent specialist conflict alerts after a clean review handoff regresses',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-specialist-conflict-alert-input-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-specialist-conflict-alert-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-specialist-conflict-alert-history-',
      );

      try {
        const scenarioId =
            'parser_monitoring_review_action_specialist_conflict_alert_probe_v1';
        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_monitoring_review_action_specialist_conflict_alert_probe_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(
            await loadScenarioFixture(
              'simulations/scenarios/monitoring/scenario_monitoring_review_action_cctv_handoff_v1.json',
              scenarioId: scenarioId,
              title: 'Specialist conflict alert probe',
            ),
          ),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final commandArgs = <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--fail-on-alert=medium',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ];

        final firstRun = await Process.run(
          dartExecutable,
          commandArgs,
          workingDirectory: Directory.current.path,
        );
        expect(firstRun.exitCode, 0, reason: '${firstRun.stderr}');

        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(
            await loadScenarioFixture(
              'simulations/scenarios/monitoring/scenario_monitoring_review_action_specialist_conflict_v1.json',
              scenarioId: scenarioId,
              title: 'Specialist conflict alert probe',
            ),
          ),
        );

        final secondRun = await Process.run(
          dartExecutable,
          commandArgs,
          workingDirectory: Directory.current.path,
        );
        expect(secondRun.exitCode, 1, reason: '${secondRun.stderr}');

        final stdoutText = secondRun.stdout as String;
        final jsonStartIndex = stdoutText.indexOf('{');
        expect(jsonStartIndex, isNonNegative, reason: stdoutText);
        final decoded =
            jsonDecode(stdoutText.substring(jsonStartIndex))
                as Map<String, dynamic>;

        const latestSignature =
            'persistent:cctv->cctvReview | track->tacticalTrack';
        const latestLifecycleSignature =
            'active_in_run:cctv|track:cctvReview|tacticalTrack';
        expect(
          decoded['specialistConflictBranchSummary'],
          containsPair('persistent', containsPair('passedCount', 1)),
        );
        expect(
          decoded['specialistConflictSignatureSummary'],
          containsPair(latestSignature, containsPair('passedCount', 1)),
        );
        expect(
          decoded['historySpecialistConflictBranchSummary'],
          containsPair(
            'persistent',
            allOf(
              containsPair('scenarioCount', 1),
              containsPair('passedCount', 1),
              containsPair('failedCount', 0),
            ),
          ),
        );
        expect(
          decoded['historySpecialistConflictSignatureSummary'],
          containsPair(latestSignature, containsPair('passedCount', 1)),
        );
        expect(
          decoded['historyScenarioSpecialistConflictSummary'],
          containsPair(scenarioId, isA<Map<String, dynamic>>()),
        );
        final historyConflictSummary =
            (decoded['historyScenarioSpecialistConflictSummary']
                    as Map<String, dynamic>)[scenarioId]
                as Map<String, dynamic>;
        expect(historyConflictSummary['runCount'], 2);
        expect(historyConflictSummary['conflictRunCount'], 1);
        expect(historyConflictSummary['clearedCount'], 1);
        expect(historyConflictSummary['persistentCount'], 1);
        expect(historyConflictSummary['recoveredInRunCount'], 0);
        expect(historyConflictSummary['activeInRunCount'], 1);
        expect(historyConflictSummary['latestBranch'], 'persistent');
        expect(
          historyConflictSummary['latestSummary'],
          'cctv->cctvReview | track->tacticalTrack',
        );
        expect(historyConflictSummary['latestSpecialists'], <String>[
          'cctv',
          'track',
        ]);
        expect(historyConflictSummary['latestTargets'], <String>[
          'cctvReview',
          'tacticalTrack',
        ]);
        expect(historyConflictSummary['latestLifecycle'], 'active_in_run');
        expect(
          historyConflictSummary['latestLifecycleSignature'],
          latestLifecycleSignature,
        );
        expect(historyConflictSummary['trend'], 'worsening');
        expect(decoded['historyAlertSummary'], containsPair('medium', 1));
        expect(
          decoded['historyAlertFieldSummary'],
          containsPair('specialistConflictBranch', 1),
        );
        expect(
          decoded['historyAlertSpecialistConflictSummary'],
          containsPair(scenarioId, isA<Map<String, dynamic>>()),
        );
        final historyConflictAlertSummary =
            (decoded['historyAlertSpecialistConflictSummary']
                    as Map<String, dynamic>)[scenarioId]
                as Map<String, dynamic>;
        expect(historyConflictAlertSummary['count'], 1);
        expect(historyConflictAlertSummary['trend'], 'worsening');
        expect(historyConflictAlertSummary['severity'], 'medium');
        expect(historyConflictAlertSummary['latestBranch'], 'persistent');
        expect(historyConflictAlertSummary['latestSignature'], latestSignature);
        expect(
          historyConflictAlertSummary['latestSummary'],
          'cctv->cctvReview | track->tacticalTrack',
        );
        expect(historyConflictAlertSummary['latestSpecialists'], <String>[
          'cctv',
          'track',
        ]);
        expect(historyConflictAlertSummary['latestTargets'], <String>[
          'cctvReview',
          'tacticalTrack',
        ]);
        expect(
          decoded['historyAlertFocus'],
          allOf(
            containsPair('scope', 'specialist_conflict'),
            containsPair('field', 'specialistConflictBranch'),
            containsPair('scenarioId', scenarioId),
            containsPair('trend', 'worsening'),
            containsPair('severity', 'medium'),
          ),
        );
        expect(decoded['alertFailureTriggered'], isTrue);
        expect(decoded['alertFailureCount'], 1);
        expect(decoded['alertFailureSummary'], containsPair('medium', 1));
        expect(
          decoded['alertFailureSpecialistConflictSummary'],
          containsPair(
            scenarioId,
            containsPair('latestSignature', latestSignature),
          ),
        );
        expect(
          decoded['alertFailureFocus'],
          allOf(
            containsPair('scope', 'specialist_conflict'),
            containsPair('field', 'specialistConflictBranch'),
            containsPair('scenarioId', scenarioId),
            containsPair('trend', 'worsening'),
            containsPair('severity', 'medium'),
          ),
        );

        final conflictAlerts = (decoded['historyAlerts'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .where(
              (alert) => alert['scope']?.toString() == 'specialist_conflict',
            )
            .toList(growable: false);
        expect(conflictAlerts, hasLength(1));
        expect(
          conflictAlerts.single,
          allOf(
            containsPair('field', 'specialistConflictBranch'),
            containsPair('trend', 'worsening'),
            containsPair('latestBranch', 'persistent'),
            containsPair('latestSpecialistConflictSignature', latestSignature),
            containsPair(
              'latestSummary',
              'cctv->cctvReview | track->tacticalTrack',
            ),
          ),
        );
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool raises hard specialist constraint alerts after a conflict regresses into a blocking branch',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-specialist-constraint-input-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-specialist-constraint-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-specialist-constraint-history-',
      );

      try {
        const scenarioId =
            'parser_monitoring_review_action_specialist_constraint_alert_probe_v1';
        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_monitoring_review_action_specialist_constraint_alert_probe_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(
            await loadScenarioFixture(
              'simulations/scenarios/monitoring/scenario_monitoring_review_action_specialist_conflict_v1.json',
              scenarioId: scenarioId,
              title: 'Specialist constraint alert probe',
            ),
          ),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final commandArgs = <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--fail-on-alert=medium',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ];

        final firstRun = await Process.run(
          dartExecutable,
          commandArgs,
          workingDirectory: Directory.current.path,
        );
        expect(firstRun.exitCode, 1, reason: '${firstRun.stderr}');

        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(
            await loadScenarioFixture(
              'simulations/scenarios/monitoring/scenario_monitoring_review_action_hard_constraint_conflict_v1.json',
              scenarioId: scenarioId,
              title: 'Specialist constraint alert probe',
            ),
          ),
        );

        final secondRun = await Process.run(
          dartExecutable,
          commandArgs,
          workingDirectory: Directory.current.path,
        );
        expect(secondRun.exitCode, 1, reason: '${secondRun.stderr}');

        final stdoutText = secondRun.stdout as String;
        final jsonStartIndex = stdoutText.indexOf('{');
        expect(jsonStartIndex, isNonNegative, reason: stdoutText);
        final decoded =
            jsonDecode(stdoutText.substring(jsonStartIndex))
                as Map<String, dynamic>;

        expect(
          decoded['specialistConstraintBranchSummary'],
          containsPair('blocking', containsPair('passedCount', 1)),
        );
        expect(
          decoded['specialistConstraintSignatureSummary'],
          containsPair(
            'blocking:guardOps:dispatchBoard',
            containsPair('passedCount', 1),
          ),
        );
        expect(
          decoded['historySpecialistConstraintBranchSummary'],
          containsPair(
            'blocking',
            allOf(
              containsPair('scenarioCount', 1),
              containsPair('passedCount', 1),
              containsPair('failedCount', 0),
            ),
          ),
        );
        expect(
          decoded['historySpecialistConstraintSignatureSummary'],
          containsPair(
            'blocking:guardOps:dispatchBoard',
            containsPair('passedCount', 1),
          ),
        );
        expect(
          decoded['historyScenarioSpecialistConstraintSummary'],
          containsPair(scenarioId, isA<Map<String, dynamic>>()),
        );
        final historyConstraintSummary =
            (decoded['historyScenarioSpecialistConstraintSummary']
                    as Map<String, dynamic>)[scenarioId]
                as Map<String, dynamic>;
        expect(historyConstraintSummary['runCount'], 2);
        expect(historyConstraintSummary['constraintRunCount'], 1);
        expect(historyConstraintSummary['blockingCount'], 1);
        expect(historyConstraintSummary['constrainedCount'], 0);
        expect(historyConstraintSummary['latestBranch'], 'blocking');
        expect(
          historyConstraintSummary['latestSignature'],
          'blocking:guardOps:dispatchBoard',
        );
        expect(historyConstraintSummary['latestSpecialist'], 'guardOps');
        expect(historyConstraintSummary['latestTarget'], 'dispatchBoard');
        expect(historyConstraintSummary['latestAllowRouteExecution'], isFalse);
        expect(historyConstraintSummary['trend'], 'worsening');
        expect(
          decoded['historyAlertSummary'],
          allOf(containsPair('medium', 1), containsPair('low', 1)),
        );
        expect(
          decoded['historyAlertFieldSummary'],
          allOf(
            containsPair('specialistConstraintBranch', 1),
            containsPair('specialistConflictBranch', 1),
          ),
        );
        expect(
          decoded['historyAlertSpecialistConstraintSummary'],
          containsPair(scenarioId, isA<Map<String, dynamic>>()),
        );
        expect(
          decoded['historyAlertSpecialistConflictSummary'],
          containsPair(scenarioId, isA<Map<String, dynamic>>()),
        );
        final historyConstraintAlertSummary =
            (decoded['historyAlertSpecialistConstraintSummary']
                    as Map<String, dynamic>)[scenarioId]
                as Map<String, dynamic>;
        expect(historyConstraintAlertSummary['count'], 1);
        expect(historyConstraintAlertSummary['trend'], 'worsening');
        expect(historyConstraintAlertSummary['severity'], 'medium');
        expect(historyConstraintAlertSummary['latestBranch'], 'blocking');
        expect(
          historyConstraintAlertSummary['latestSignature'],
          'blocking:guardOps:dispatchBoard',
        );
        expect(historyConstraintAlertSummary['latestSpecialist'], 'guardOps');
        expect(historyConstraintAlertSummary['latestTarget'], 'dispatchBoard');
        expect(
          historyConstraintAlertSummary['latestAllowRouteExecution'],
          isFalse,
        );
        expect(
          decoded['historyAlertFocus'],
          allOf(
            containsPair('scope', 'specialist_constraint'),
            containsPair('field', 'specialistConstraintBranch'),
            containsPair('scenarioId', scenarioId),
            containsPair('trend', 'worsening'),
            containsPair('severity', 'medium'),
          ),
        );
        expect(decoded['alertFailureTriggered'], isTrue);
        expect(decoded['alertFailureCount'], 1);
        expect(decoded['alertFailureSummary'], containsPair('medium', 1));
        expect(
          decoded['alertFailureSpecialistConstraintSummary'],
          containsPair(
            scenarioId,
            containsPair('latestSignature', 'blocking:guardOps:dispatchBoard'),
          ),
        );
        expect(decoded['alertFailureSpecialistConflictSummary'], isNull);
        expect(
          decoded['alertFailureFocus'],
          allOf(
            containsPair('scope', 'specialist_constraint'),
            containsPair('field', 'specialistConstraintBranch'),
            containsPair('scenarioId', scenarioId),
            containsPair('trend', 'worsening'),
            containsPair('severity', 'medium'),
          ),
        );

        final historyAlerts = (decoded['historyAlerts'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);
        final constraintAlerts = historyAlerts
            .whereType<Map<String, dynamic>>()
            .where(
              (alert) => alert['scope']?.toString() == 'specialist_constraint',
            )
            .toList(growable: false);
        expect(constraintAlerts, hasLength(1));
        expect(
          constraintAlerts.single,
          allOf(
            containsPair('field', 'specialistConstraintBranch'),
            containsPair('trend', 'worsening'),
            containsPair('latestBranch', 'blocking'),
            containsPair(
              'latestSpecialistConstraintSignature',
              'blocking:guardOps:dispatchBoard',
            ),
            containsPair('latestSpecialist', 'guardOps'),
            containsPair('latestTarget', 'dispatchBoard'),
            containsPair('latestAllowRouteExecution', isFalse),
          ),
        );
        final conflictAlerts = historyAlerts
            .where(
              (alert) => alert['scope']?.toString() == 'specialist_conflict',
            )
            .toList(growable: false);
        expect(conflictAlerts, hasLength(1));
        expect(
          conflictAlerts.single,
          allOf(
            containsPair('field', 'specialistConflictBranch'),
            containsPair('trend', 'stabilizing'),
            containsPair('latestBranch', 'persistent'),
            containsPair(
              'latestSpecialistConflictSignature',
              'persistent:cctv->cctvReview | guardOps->dispatchBoard',
            ),
          ),
        );
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool marks hard specialist constraints as clean_again after a blocking branch clears',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-specialist-constraint-recovery-input-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-specialist-constraint-recovery-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-specialist-constraint-recovery-history-',
      );

      try {
        const scenarioId =
            'parser_monitoring_review_action_specialist_constraint_recovery_probe_v1';
        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_monitoring_review_action_specialist_constraint_recovery_probe_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(
            await loadScenarioFixture(
              'simulations/scenarios/monitoring/scenario_monitoring_review_action_hard_constraint_conflict_v1.json',
              scenarioId: scenarioId,
              title: 'Specialist constraint recovery probe',
            ),
          ),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final commandArgs = <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--fail-on-alert=medium',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ];

        final firstRun = await Process.run(
          dartExecutable,
          commandArgs,
          workingDirectory: Directory.current.path,
        );
        expect(firstRun.exitCode, 1, reason: '${firstRun.stderr}');

        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(
            await loadScenarioFixture(
              'simulations/scenarios/monitoring/scenario_monitoring_review_action_specialist_conflict_v1.json',
              scenarioId: scenarioId,
              title: 'Specialist constraint recovery probe',
            ),
          ),
        );

        final secondRun = await Process.run(
          dartExecutable,
          commandArgs,
          workingDirectory: Directory.current.path,
        );
        expect(secondRun.exitCode, 0, reason: '${secondRun.stderr}');

        final stdoutText = secondRun.stdout as String;
        final jsonStartIndex = stdoutText.indexOf('{');
        expect(jsonStartIndex, isNonNegative, reason: stdoutText);
        final decoded =
            jsonDecode(stdoutText.substring(jsonStartIndex))
                as Map<String, dynamic>;

        expect(decoded['specialistConstraintBranchSummary'], isEmpty);
        expect(decoded['specialistConstraintSignatureSummary'], isEmpty);
        expect(
          decoded['historySpecialistConstraintBranchSummary'],
          containsPair(
            'blocking',
            allOf(
              containsPair('scenarioCount', 1),
              containsPair('passedCount', 1),
              containsPair('failedCount', 0),
            ),
          ),
        );
        expect(
          decoded['historyScenarioSpecialistConstraintSummary'],
          containsPair(scenarioId, isA<Map<String, dynamic>>()),
        );
        final historyConstraintSummary =
            (decoded['historyScenarioSpecialistConstraintSummary']
                    as Map<String, dynamic>)[scenarioId]
                as Map<String, dynamic>;
        expect(historyConstraintSummary['runCount'], 2);
        expect(historyConstraintSummary['constraintRunCount'], 1);
        expect(historyConstraintSummary['clearedCount'], 1);
        expect(historyConstraintSummary['blockingCount'], 1);
        expect(historyConstraintSummary['constrainedCount'], 0);
        expect(historyConstraintSummary['latestBranch'], 'clean');
        expect(historyConstraintSummary['latestAllowRouteExecution'], isTrue);
        expect(historyConstraintSummary['trend'], 'clean_again');

        expect(decoded['historyAlertSummary'], containsPair('low', 1));
        expect(
          decoded['historyAlertFieldSummary'],
          containsPair('specialistConflictBranch', 1),
        );
        expect(decoded['historyAlertSpecialistConstraintSummary'], isEmpty);
        expect(
          decoded['historyAlertSpecialistConflictSummary'],
          containsPair(scenarioId, isA<Map<String, dynamic>>()),
        );
        expect(
          decoded['historyAlertFocus'],
          allOf(
            containsPair('scope', 'specialist_conflict'),
            containsPair('field', 'specialistConflictBranch'),
            containsPair('scenarioId', scenarioId),
            containsPair('trend', 'stabilizing'),
            containsPair('severity', 'low'),
          ),
        );
        expect(decoded['alertFailureTriggered'], isFalse);
        expect(decoded['alertFailureCount'], 0);
        expect(decoded['alertFailureSummary'], isEmpty);
        expect(decoded['alertFailureSpecialistConflictSummary'], isNull);
        expect(decoded['alertFailureSpecialistConstraintSummary'], isNull);
        expect(decoded['alertFailureFocus'], isNull);

        final historyAlerts = (decoded['historyAlerts'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);
        final constraintAlerts = historyAlerts
            .whereType<Map<String, dynamic>>()
            .where(
              (alert) => alert['scope']?.toString() == 'specialist_constraint',
            )
            .toList(growable: false);
        expect(constraintAlerts, isEmpty);
        final conflictAlerts = historyAlerts
            .where(
              (alert) => alert['scope']?.toString() == 'specialist_conflict',
            )
            .toList(growable: false);
        expect(conflictAlerts, hasLength(1));
        expect(
          conflictAlerts.single,
          allOf(
            containsPair('field', 'specialistConflictBranch'),
            containsPair('trend', 'stabilizing'),
            containsPair('latestBranch', 'persistent'),
            containsPair(
              'latestSpecialistConflictSignature',
              'persistent:cctv->cctvReview | track->tacticalTrack',
            ),
          ),
        );
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool summarizes specialist conflict recovery inside a single replay run',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-specialist-conflict-lifecycle-input-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-specialist-conflict-lifecycle-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-specialist-conflict-lifecycle-history-',
      );

      try {
        const scenarioId =
            'parser_monitoring_priority_sequence_conflict_lifecycle_probe_v1';
        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_monitoring_priority_sequence_conflict_lifecycle_probe_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(
            await loadScenarioFixture(
              'simulations/scenarios/monitoring/scenario_monitoring_priority_sequence_review_conflict_track_v1.json',
              scenarioId: scenarioId,
              title: 'Specialist conflict lifecycle probe',
            ),
          ),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final result = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(result.exitCode, 0, reason: '${result.stderr}');

        final stdoutText = result.stdout as String;
        final jsonStartIndex = stdoutText.indexOf('{');
        expect(jsonStartIndex, isNonNegative, reason: stdoutText);
        final decoded =
            jsonDecode(stdoutText.substring(jsonStartIndex))
                as Map<String, dynamic>;

        const lifecycleSignature =
            'recovered_in_run:cctv|track:cctvReview|tacticalTrack:open_track_handoff';
        expect(decoded['specialistConflictBranchSummary'], isEmpty);
        expect(
          decoded['specialistConflictLifecycleSummary'],
          containsPair('recovered_in_run', containsPair('passedCount', 1)),
        );
        expect(
          decoded['specialistConflictLifecycleSignatureSummary'],
          containsPair(lifecycleSignature, containsPair('passedCount', 1)),
        );
        expect(decoded['historySpecialistConflictBranchSummary'], isEmpty);
        expect(
          decoded['historySpecialistConflictLifecycleSummary'],
          containsPair(
            'recovered_in_run',
            allOf(
              containsPair('scenarioCount', 1),
              containsPair('passedCount', 1),
              containsPair('failedCount', 0),
            ),
          ),
        );
        expect(
          decoded['historySpecialistConflictLifecycleSignatureSummary'],
          containsPair(lifecycleSignature, containsPair('passedCount', 1)),
        );
        expect(
          decoded['historyScenarioSpecialistConflictSummary'],
          containsPair(scenarioId, isA<Map<String, dynamic>>()),
        );
        final historyConflictSummary =
            (decoded['historyScenarioSpecialistConflictSummary']
                    as Map<String, dynamic>)[scenarioId]
                as Map<String, dynamic>;
        expect(historyConflictSummary['runCount'], 1);
        expect(historyConflictSummary['conflictRunCount'], 1);
        expect(historyConflictSummary['clearedCount'], 0);
        expect(historyConflictSummary['persistentCount'], 0);
        expect(historyConflictSummary['recoveredInRunCount'], 1);
        expect(historyConflictSummary['activeInRunCount'], 0);
        expect(historyConflictSummary['latestBranch'], 'clean');
        expect(historyConflictSummary['latestLifecycle'], 'recovered_in_run');
        expect(
          historyConflictSummary['latestLifecycleSignature'],
          lifecycleSignature,
        );
        expect(
          historyConflictSummary['latestRecoveryStage'],
          'open_track_handoff',
        );
        expect(
          historyConflictSummary['latestSummary'],
          'cctv->cctvReview | track->tacticalTrack',
        );
        expect(historyConflictSummary['latestTargets'], <String>[
          'cctvReview',
          'tacticalTrack',
        ]);
        expect(historyConflictSummary['trend'], 'clean');
        expect(historyConflictSummary['recoveryTrend'], 'clean');
        expect(
          decoded['historyFocusSummary'],
          containsPair(
            'topConflictRecoveryScenario',
            allOf(
              containsPair('scenarioId', scenarioId),
              containsPair('recoveredInRunCount', 1),
              containsPair('recoveryTrend', 'clean'),
              containsPair('latestRecoveryStage', 'open_track_handoff'),
              containsPair(
                'latestSummary',
                'cctv->cctvReview | track->tacticalTrack',
              ),
            ),
          ),
        );
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool surfaces specialist conflict recovery in plain-text history focus',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-specialist-conflict-console-input-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-specialist-conflict-console-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-specialist-conflict-console-history-',
      );

      try {
        const scenarioId =
            'parser_monitoring_priority_sequence_conflict_console_probe_v1';
        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_monitoring_priority_sequence_conflict_console_probe_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(
            await loadScenarioFixture(
              'simulations/scenarios/monitoring/scenario_monitoring_priority_sequence_review_conflict_track_v1.json',
              scenarioId: scenarioId,
              title: 'Specialist conflict console probe',
            ),
          ),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final result = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--history',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(result.exitCode, 0, reason: '${result.stderr}');

        final stdoutText = result.stdout as String;
        expect(stdoutText, contains('History focus:'));
        expect(stdoutText, contains('conflict recovery: $scenarioId'));
        expect(stdoutText, contains('Run specialist conflict lifecycle:'));
        expect(stdoutText, contains('- recovered_in_run: 1/1 passed'));
        expect(stdoutText, contains('History specialist conflict lifecycle:'));
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool summarizes hard specialist recovery inside a single replay run',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-specialist-constraint-lifecycle-input-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-specialist-constraint-lifecycle-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-specialist-constraint-lifecycle-history-',
      );

      try {
        const scenarioId =
            'parser_monitoring_priority_sequence_constraint_lifecycle_probe_v1';
        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_monitoring_priority_sequence_constraint_lifecycle_probe_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(
            await loadScenarioFixture(
              'simulations/scenarios/monitoring/scenario_monitoring_priority_sequence_review_constraint_dispatch_v1.json',
              scenarioId: scenarioId,
              title: 'Specialist constraint lifecycle probe',
            ),
          ),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final result = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--history',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(result.exitCode, 0, reason: '${result.stderr}');

        final stdoutText = result.stdout as String;
        final jsonStartIndex = stdoutText.indexOf('{');
        expect(jsonStartIndex, isNonNegative, reason: stdoutText);
        final decoded =
            jsonDecode(stdoutText.substring(jsonStartIndex))
                as Map<String, dynamic>;

        expect(decoded['specialistConstraintBranchSummary'], isEmpty);
        expect(
          decoded['specialistConstraintLifecycleSummary'],
          containsPair('recovered_in_run', containsPair('passedCount', 1)),
        );
        expect(
          decoded['specialistConstraintLifecycleSignatureSummary'],
          containsPair(
            'recovered_in_run:guardOps:dispatchBoard:open_dispatch_handoff',
            containsPair('passedCount', 1),
          ),
        );
        expect(decoded['historySpecialistConstraintBranchSummary'], isEmpty);
        expect(
          decoded['historySpecialistConstraintLifecycleSummary'],
          containsPair(
            'recovered_in_run',
            allOf(
              containsPair('scenarioCount', 1),
              containsPair('passedCount', 1),
              containsPair('failedCount', 0),
            ),
          ),
        );
        expect(
          decoded['historySpecialistConstraintLifecycleSignatureSummary'],
          containsPair(
            'recovered_in_run:guardOps:dispatchBoard:open_dispatch_handoff',
            containsPair('passedCount', 1),
          ),
        );
        expect(
          decoded['historyScenarioSpecialistConstraintSummary'],
          containsPair(scenarioId, isA<Map<String, dynamic>>()),
        );
        final historyConstraintSummary =
            (decoded['historyScenarioSpecialistConstraintSummary']
                    as Map<String, dynamic>)[scenarioId]
                as Map<String, dynamic>;
        expect(historyConstraintSummary['runCount'], 1);
        expect(historyConstraintSummary['constraintRunCount'], 1);
        expect(historyConstraintSummary['clearedCount'], 0);
        expect(historyConstraintSummary['blockingCount'], 0);
        expect(historyConstraintSummary['recoveredInRunCount'], 1);
        expect(historyConstraintSummary['activeInRunCount'], 0);
        expect(historyConstraintSummary['latestBranch'], 'clean');
        expect(historyConstraintSummary['latestLifecycle'], 'recovered_in_run');
        expect(
          historyConstraintSummary['latestLifecycleSignature'],
          'recovered_in_run:guardOps:dispatchBoard:open_dispatch_handoff',
        );
        expect(
          historyConstraintSummary['latestRecoveryStage'],
          'open_dispatch_handoff',
        );
        expect(historyConstraintSummary['latestAllowRouteExecution'], isTrue);
        expect(historyConstraintSummary['trend'], 'clean');
        expect(historyConstraintSummary['recoveryTrend'], 'clean');
        expect(
          decoded['historyFocusSummary'],
          containsPair(
            'topConstraintRecoveryScenario',
            allOf(
              containsPair('scenarioId', scenarioId),
              containsPair('recoveredInRunCount', 1),
              containsPair('recoveryTrend', 'clean'),
              containsPair('latestRecoveryStage', 'open_dispatch_handoff'),
              containsPair('latestTarget', 'dispatchBoard'),
            ),
          ),
        );
        expect(decoded['historyAlertSpecialistConstraintSummary'], isEmpty);
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool surfaces hard specialist recovery in plain-text history focus',
    () async {
      final scenarioDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-specialist-constraint-console-input-',
      );
      final latestDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-specialist-constraint-console-latest-',
      );
      final historyDirectory = Directory.systemTemp.createTempSync(
        'onyx-scenario-specialist-constraint-console-history-',
      );

      try {
        const scenarioId =
            'parser_monitoring_priority_sequence_constraint_console_probe_v1';
        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_monitoring_priority_sequence_constraint_console_probe_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(
            await loadScenarioFixture(
              'simulations/scenarios/monitoring/scenario_monitoring_priority_sequence_review_constraint_dispatch_v1.json',
              scenarioId: scenarioId,
              title: 'Specialist constraint console probe',
            ),
          ),
        );

        final dartExecutable =
            (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart';
        final result = await Process.run(dartExecutable, <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--history',
          '--results-dir=${latestDirectory.path}',
          '--history-dir=${historyDirectory.path}',
          scenarioFile.path,
        ], workingDirectory: Directory.current.path);
        expect(result.exitCode, 0, reason: '${result.stderr}');

        final stdoutText = result.stdout as String;
        expect(stdoutText, contains('History focus:'));
        expect(stdoutText, contains('constraint recovery: $scenarioId'));
        expect(stdoutText, contains('Run specialist constraint lifecycle:'));
        expect(stdoutText, contains('- recovered_in_run: 1/1 passed'));
        expect(
          stdoutText,
          contains('History specialist constraint lifecycle:'),
        );
      } finally {
        if (scenarioDirectory.existsSync()) {
          scenarioDirectory.deleteSync(recursive: true);
        }
        if (latestDirectory.existsSync()) {
          latestDirectory.deleteSync(recursive: true);
        }
        if (historyDirectory.existsSync()) {
          historyDirectory.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool lists validation scenarios without executing them',
    () async {
      final result = await Process.run(
        (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart',
        <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--list',
          '--set=validation',
          'simulations/scenarios',
        ],
        workingDirectory: Directory.current.path,
      );

      expect(result.exitCode, 0, reason: '${result.stderr}');

      final stdoutText = result.stdout as String;
      final jsonStartIndex = stdoutText.indexOf('{');
      expect(jsonStartIndex, isNonNegative, reason: stdoutText);
      final decoded =
          jsonDecode(stdoutText.substring(jsonStartIndex))
              as Map<String, dynamic>;

      expect(decoded['scenarioSetFilter'], 'validation');
      expect(decoded['scenarioCount'], 19);
      expect(
        decoded['scenarioStatusCounts'],
        containsPair('locked_validation', greaterThanOrEqualTo(15)),
      );
      expect(
        decoded['scenarioStatusCounts'],
        containsPair('validation_candidate', greaterThanOrEqualTo(3)),
      );
      expect(
        decoded['categoryCounts'],
        containsPair('admin_portfolio_read', greaterThanOrEqualTo(1)),
      );
      expect(
        decoded['categoryCounts'],
        containsPair('track_ui_state', greaterThanOrEqualTo(3)),
      );
      expect(
        decoded['categoryCounts'],
        containsPair('guard_ops_read', greaterThanOrEqualTo(2)),
      );
      expect(
        decoded['categoryCounts'],
        containsPair('client_comms', greaterThanOrEqualTo(3)),
      );
      expect(
        decoded['categoryCounts'],
        containsPair('monitoring_watch', greaterThanOrEqualTo(3)),
      );
      expect(
        decoded['categoryCounts'],
        containsPair('dispatch_flow', greaterThanOrEqualTo(2)),
      );
      expect(
        decoded['categoryCounts'],
        containsPair('incident_timeline', greaterThanOrEqualTo(1)),
      );

      final scenarios = decoded['scenarios'] as List<dynamic>;
      final scenarioIds = scenarios
          .map((entry) => (entry as Map<String, dynamic>)['scenarioId'])
          .toList(growable: false);
      expect(
        scenarioIds,
        containsAll(<String>[
          'parser_admin_breaches_all_sites_validation_v1',
          'track_fresh_entry_modern_overview_validation_v1',
          'track_parent_rebuild_preserves_session_validation_v1',
          'track_live_ops_handoff_validation_v1',
          'guard_status_echo_3_validation_v1',
          'patrol_report_guard001_validation_v1',
          'client_comms_draft_update_validation_v1',
          'client_comms_attention_queue_pending_draft_validation_v1',
          'client_comms_queue_state_cycle_validation_v1',
          'monitoring_watchlist_match_review_validation_v1',
          'monitoring_review_action_cctv_handoff_validation_v1',
          'monitoring_priority_sequence_review_dispatch_validation_v1',
          'monitoring_priority_sequence_dispatch_track_validation_v1',
          'monitoring_priority_sequence_review_track_conflict_validation_v1',
          'monitoring_priority_sequence_review_track_validation_v1',
          'monitoring_priority_sequence_review_dispatch_track_validation_v1',
          'dispatch_today_summary_validation_v1',
          'dispatch_attention_queue_handoff_validation_v1',
          'incident_timeline_summary_validation_v1',
        ]),
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'run_onyx_scenario tool lists validation candidates without executing locked validations',
    () async {
      final result = await Process.run(
        (Platform.environment['DART'] ?? 'dart').trim().isNotEmpty
            ? (Platform.environment['DART'] ?? 'dart').trim()
            : 'dart',
        <String>[
          'run',
          'tool/run_onyx_scenario.dart',
          '--json',
          '--list',
          '--set=validation',
          '--status=validation_candidate',
          'simulations/scenarios',
        ],
        workingDirectory: Directory.current.path,
      );

      expect(result.exitCode, 0, reason: '${result.stderr}');

      final stdoutText = result.stdout as String;
      final jsonStartIndex = stdoutText.indexOf('{');
      expect(jsonStartIndex, isNonNegative, reason: stdoutText);
      final decoded =
          jsonDecode(stdoutText.substring(jsonStartIndex))
              as Map<String, dynamic>;

      expect(decoded['scenarioSetFilter'], 'validation');
      expect(decoded['scenarioStatusFilter'], 'validation_candidate');
      expect(decoded['scenarioCount'], 3);
      expect(
        decoded['scenarioStatusCounts'],
        containsPair('validation_candidate', 3),
      );

      final scenarios = decoded['scenarios'] as List<dynamic>;
      final scenarioIds = scenarios
          .map((entry) => (entry as Map<String, dynamic>)['scenarioId'])
          .toList(growable: false);
      expect(
        scenarioIds,
        containsAll(<String>[
          'monitoring_watchlist_match_review_validation_v1',
          'dispatch_today_summary_validation_v1',
          'incident_timeline_summary_validation_v1',
        ]),
      );
      expect(
        scenarioIds,
        isNot(contains('track_fresh_entry_modern_overview_validation_v1')),
      );
      expect(
        scenarioIds,
        isNot(contains('client_comms_draft_update_validation_v1')),
      );
      expect(
        scenarioIds,
        isNot(
          contains('client_comms_attention_queue_pending_draft_validation_v1'),
        ),
      );
      expect(
        scenarioIds,
        isNot(contains('client_comms_queue_state_cycle_validation_v1')),
      );
      expect(
        scenarioIds,
        isNot(contains('monitoring_review_action_cctv_handoff_validation_v1')),
      );
      expect(
        scenarioIds,
        isNot(
          contains(
            'monitoring_priority_sequence_review_dispatch_track_validation_v1',
          ),
        ),
      );
      expect(scenarioIds, isNot(contains('guard_status_echo_3_validation_v1')));
      expect(
        scenarioIds,
        isNot(contains('patrol_report_guard001_validation_v1')),
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
