import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/simulation/scenario_replay_history_signal_service.dart';
import 'package:omnix_dashboard/application/simulation/scenario_result.dart';
import 'package:omnix_dashboard/domain/authority/onyx_command_brain_contract.dart';
import 'package:omnix_dashboard/domain/authority/onyx_task_protocol.dart';

void main() {
  test(
    'local replay history signal service returns a policy-promoted specialist conflict signal',
    () async {
      final workspace = Directory.systemTemp.createTempSync(
        'onyx-replay-history-signal-',
      );

      try {
        final scenarioDirectory = Directory(
          '${workspace.path}/simulations/scenarios/monitoring',
        )..createSync(recursive: true);
        final historyDirectory = Directory(
          '${workspace.path}/simulations/results/history',
        )..createSync(recursive: true);
        final policyFile = File(
          '${workspace.path}/simulations/scenario_policy.json',
        );

        final sourceScenario = File(
          '${Directory.current.path}/simulations/scenarios/monitoring/scenario_monitoring_review_action_specialist_conflict_v1.json',
        );
        final scenarioJson =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        scenarioJson['scenarioId'] =
            'parser_monitoring_review_action_specialist_conflict_signal_service_v1';
        scenarioJson['title'] =
            'Specialist conflict replay history signal probe';

        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_monitoring_review_action_specialist_conflict_signal_service_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(scenarioJson),
        );

        final result = ScenarioResult(
          scenarioId: scenarioJson['scenarioId'] as String,
          runId: DateTime.utc(2026, 4, 2, 1, 15),
          actualOutcome: ScenarioActualOutcome(
            actualRoute: 'cctvReview',
            actualIntent: 'review_incident',
            actualEscalationState: 'monitoring',
            actualProjectionChanges: const <dynamic>['specialist_conflict'],
            actualDrafts: const <dynamic>[],
            actualBlockedActions: const <String>[],
            actualUiState: const <String, dynamic>{
              'specialistConflictVisible': true,
              'specialistConflictCount': 2,
              'specialistConflictSpecialists': <String>['cctv', 'track'],
              'specialistConflictTargets': <String>[
                'cctvReview',
                'tacticalTrack',
              ],
              'specialistConflictSummary':
                  'CCTV holds review while Track pushes tactical track.',
            },
            appendedEvents: const <dynamic>[],
            notes: 'Specialist conflict held on review.',
          ),
          mismatches: const [],
        );
        final resultFile = File(
          '${historyDirectory.path}/result_specialist_conflict_history_probe.json',
        );
        await resultFile.writeAsString(result.toJsonString(pretty: true));

        await policyFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
            'alertFailure': <String, dynamic>{
              'byScenarioSet': <String, dynamic>{
                'replay': <String, dynamic>{
                  'byCategory': <String, dynamic>{
                    'monitoring_watch': <String, dynamic>{
                      'severityByScope': <String, dynamic>{
                        'specialist_conflict': 'high',
                      },
                    },
                  },
                },
              },
            },
          }),
        );

        final service = LocalScenarioReplayHistorySignalService(
          workspaceRootPath: workspace.path,
        );
        final signal = await service.loadTopSignal();
        expect(signal, isNotNull);
        expect(signal!.scenarioId, scenarioJson['scenarioId']);
        expect(
          signal.scope,
          ScenarioReplayHistorySignalScope.specialistConflict,
        );
        expect(signal.baseSeverity, 'medium');
        expect(signal.effectiveSeverity, 'high');
        expect(signal.policyPromoted, isTrue);
        expect(signal.policyMatchSource, 'scenario_set_category');
        expect(
          signal.operatorSummary,
          contains(
            'Replay history: specialist conflict promoted medium -> high via scenario set/category policy.',
          ),
        );
        expect(
          signal.operatorSummary,
          contains('CCTV holds review while Track pushes tactical track.'),
        );
      } finally {
        if (workspace.existsSync()) {
          workspace.deleteSync(recursive: true);
        }
      }
    },
  );

  test(
    'local replay history signal service prioritizes promoted sequence fallback above non-promoted replay risks for command surfaces',
    () async {
      final workspace = Directory.systemTemp.createTempSync(
        'onyx-replay-history-signal-command-order-',
      );

      try {
        final scenarioDirectory = Directory(
          '${workspace.path}/simulations/scenarios/monitoring',
        )..createSync(recursive: true);
        final historyDirectory = Directory(
          '${workspace.path}/simulations/results/history',
        )..createSync(recursive: true);
        final policyFile = File(
          '${workspace.path}/simulations/scenario_policy.json',
        );

        final sourceConflictScenario = File(
          '${Directory.current.path}/simulations/scenarios/monitoring/scenario_monitoring_review_action_specialist_conflict_v1.json',
        );
        final conflictScenarioJson =
            jsonDecode(await sourceConflictScenario.readAsString())
                as Map<String, dynamic>;
        conflictScenarioJson['scenarioId'] =
            'parser_monitoring_review_action_specialist_conflict_command_order_v1';
        conflictScenarioJson['title'] =
            'Specialist conflict replay command-order probe';
        conflictScenarioJson['scenarioSet'] = 'validation';
        conflictScenarioJson['status'] = 'locked_validation';

        final conflictScenarioFile = File(
          '${scenarioDirectory.path}/scenario_monitoring_review_action_specialist_conflict_command_order_v1.json',
        );
        await conflictScenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(conflictScenarioJson),
        );

        final sourceFallbackScenario = File(
          '${Directory.current.path}/simulations/scenarios/monitoring/scenario_monitoring_priority_sequence_review_track_validation_v1.json',
        );
        final fallbackScenarioJson =
            jsonDecode(await sourceFallbackScenario.readAsString())
                as Map<String, dynamic>;
        fallbackScenarioJson['scenarioId'] =
            'parser_monitoring_priority_sequence_review_track_command_order_v1';
        fallbackScenarioJson['title'] =
            'Sequence fallback replay command-order probe';

        final fallbackScenarioFile = File(
          '${scenarioDirectory.path}/scenario_monitoring_priority_sequence_review_track_command_order_v1.json',
        );
        await fallbackScenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(fallbackScenarioJson),
        );

        final conflictResult = ScenarioResult(
          scenarioId: conflictScenarioJson['scenarioId'] as String,
          runId: DateTime.utc(2026, 4, 2, 1, 15),
          actualOutcome: ScenarioActualOutcome(
            actualRoute: 'cctvReview',
            actualIntent: 'review_incident',
            actualEscalationState: 'monitoring',
            actualProjectionChanges: const <dynamic>['specialist_conflict'],
            actualDrafts: const <dynamic>[],
            actualBlockedActions: const <String>[],
            actualUiState: const <String, dynamic>{
              'specialistConflictVisible': true,
              'specialistConflictCount': 2,
              'specialistConflictSpecialists': <String>['cctv', 'track'],
              'specialistConflictTargets': <String>[
                'cctvReview',
                'tacticalTrack',
              ],
              'specialistConflictSummary':
                  'CCTV holds review while Track pushes tactical track.',
            },
            appendedEvents: const <dynamic>[],
            notes: 'Specialist conflict held on review.',
          ),
          mismatches: const [],
        );
        final fallbackResult = ScenarioResult(
          scenarioId: fallbackScenarioJson['scenarioId'] as String,
          runId: DateTime.utc(2026, 4, 2, 2, 45),
          actualOutcome: ScenarioActualOutcome(
            actualRoute: 'tacticalTrack',
            actualIntent: 'track_dispatch_fallback',
            actualEscalationState: 'monitoring',
            actualProjectionChanges: const <dynamic>[],
            actualDrafts: const <dynamic>[],
            actualBlockedActions: const <String>[],
            actualUiState: const <String, dynamic>{},
            appendedEvents: const <dynamic>[],
            notes: 'Dispatch stayed unavailable and replay kept Track hot.',
            commandBrainSnapshot: const OnyxCommandBrainSnapshot(
              workItemId: 'review-track-fallback',
              mode: BrainDecisionMode.deterministic,
              target: OnyxToolTarget.tacticalTrack,
              nextMoveLabel: 'OPEN TACTICAL TRACK',
              headline: 'Tactical Track is the next move',
              summary:
                  'Replay priority keeps Tactical Track in front while sequence fallback stays active.',
              advisory:
                  'Dispatch was unavailable, so ONYX kept the live-ops sequence moving in Tactical Track.',
              decisionBias: BrainDecisionBias(
                source: BrainDecisionBiasSource.replayPolicy,
                scope: BrainDecisionBiasScope.sequenceFallback,
                preferredTarget: OnyxToolTarget.tacticalTrack,
                summary:
                    'Dispatch was unavailable, so ONYX kept the live-ops sequence moving in Tactical Track.',
                baseSeverity: 'low',
                effectiveSeverity: 'low',
                policySourceLabel: 'scenario sequence policy',
              ),
            ),
          ),
          mismatches: const [],
        );

        await File(
          '${historyDirectory.path}/result_specialist_conflict_command_order_probe.json',
        ).writeAsString(conflictResult.toJsonString(pretty: true));
        await File(
          '${historyDirectory.path}/result_sequence_fallback_command_order_probe.json',
        ).writeAsString(fallbackResult.toJsonString(pretty: true));

        await policyFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
            'alertFailure': <String, dynamic>{
              'byScenarioId': <String, dynamic>{
                'parser_monitoring_priority_sequence_review_track_command_order_v1':
                    <String, dynamic>{
                      'severityByScope': <String, dynamic>{
                        'sequence_fallback': 'medium',
                      },
                    },
              },
            },
          }),
        );

        final service = LocalScenarioReplayHistorySignalService(
          workspaceRootPath: workspace.path,
        );
        final signal = await service.loadTopSignal();
        expect(signal, isNotNull);
        expect(signal!.scenarioId, fallbackScenarioJson['scenarioId']);
        expect(signal.scope, ScenarioReplayHistorySignalScope.sequenceFallback);
        expect(signal.baseSeverity, 'low');
        expect(signal.effectiveSeverity, 'medium');
        expect(signal.policyPromoted, isTrue);
        expect(signal.commandSurfacePriorityRank, greaterThan(20));
        expect(signal.prioritizedTarget, OnyxToolTarget.tacticalTrack);
        expect(
          signal.operatorSummary,
          contains(
            'Replay history: sequence fallback promoted low -> medium via scenario policy.',
          ),
        );
      } finally {
        if (workspace.existsSync()) {
          workspace.deleteSync(recursive: true);
        }
      }
    },
  );

  test(
    'local replay history signal service reads final sequence fallback bias directly from command brain snapshots',
    () async {
      final workspace = Directory.systemTemp.createTempSync(
        'onyx-replay-history-signal-bias-',
      );

      try {
        final scenarioDirectory = Directory(
          '${workspace.path}/simulations/scenarios/monitoring',
        )..createSync(recursive: true);
        final historyDirectory = Directory(
          '${workspace.path}/simulations/results/history',
        )..createSync(recursive: true);

        final sourceScenario = File(
          '${Directory.current.path}/simulations/scenarios/monitoring/scenario_monitoring_priority_sequence_review_track_validation_v1.json',
        );
        final scenarioJson =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        scenarioJson['scenarioId'] =
            'parser_monitoring_priority_sequence_review_track_bias_signal_v1';
        scenarioJson['title'] = 'Sequence fallback replay history signal probe';

        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_monitoring_priority_sequence_review_track_bias_signal_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(scenarioJson),
        );

        final result = ScenarioResult(
          scenarioId: scenarioJson['scenarioId'] as String,
          runId: DateTime.utc(2026, 4, 2, 2, 45),
          actualOutcome: ScenarioActualOutcome(
            actualRoute: 'tacticalTrack',
            actualIntent: 'track_dispatch_fallback',
            actualEscalationState: 'monitoring',
            actualProjectionChanges: const <dynamic>[],
            actualDrafts: const <dynamic>[],
            actualBlockedActions: const <String>[],
            actualUiState: const <String, dynamic>{},
            appendedEvents: const <dynamic>[],
            notes: 'Dispatch stayed unavailable and replay kept Track hot.',
            commandBrainSnapshot: const OnyxCommandBrainSnapshot(
              workItemId: 'review-track-fallback',
              mode: BrainDecisionMode.deterministic,
              target: OnyxToolTarget.tacticalTrack,
              nextMoveLabel: 'OPEN TACTICAL TRACK',
              headline: 'Tactical Track is the next move',
              summary:
                  'Replay priority keeps Tactical Track in front while sequence fallback stays active.',
              advisory:
                  'Dispatch was unavailable, so ONYX kept the live-ops sequence moving in Tactical Track.',
              decisionBias: BrainDecisionBias(
                source: BrainDecisionBiasSource.replayPolicy,
                scope: BrainDecisionBiasScope.sequenceFallback,
                preferredTarget: OnyxToolTarget.tacticalTrack,
                summary:
                    'Dispatch was unavailable, so ONYX kept the live-ops sequence moving in Tactical Track.',
                baseSeverity: 'low',
                effectiveSeverity: 'low',
                policySourceLabel: 'scenario sequence policy',
              ),
            ),
          ),
          mismatches: const [],
        );
        final resultFile = File(
          '${historyDirectory.path}/result_sequence_fallback_history_probe.json',
        );
        await resultFile.writeAsString(result.toJsonString(pretty: true));

        final service = LocalScenarioReplayHistorySignalService(
          workspaceRootPath: workspace.path,
        );
        final signal = await service.loadTopSignal();
        expect(signal, isNotNull);
        expect(signal!.scenarioId, scenarioJson['scenarioId']);
        expect(signal.scope, ScenarioReplayHistorySignalScope.sequenceFallback);
        expect(signal.baseSeverity, 'low');
        expect(signal.effectiveSeverity, 'low');
        expect(signal.policyPromoted, isFalse);
        expect(signal.latestTarget, 'tacticalTrack');
        expect(signal.latestBiasSource, 'replayPolicy');
        expect(signal.latestBiasScope, 'sequenceFallback');
        expect(signal.latestBiasSignature, 'replayPolicy:sequenceFallback');
        expect(signal.latestBiasPolicySourceLabel, 'scenario sequence policy');
        expect(
          signal.latestReplayBiasStackSignature,
          'replayPolicy:sequenceFallback:tacticalTrack',
        );
        expect(signal.latestReplayBiasStackPosition, 0);
        expect(signal.shouldBiasCommandSurface, isTrue);
        expect(signal.prioritizedTarget, OnyxToolTarget.tacticalTrack);
        expect(
          signal.operatorSummary,
          contains('Replay history: sequence fallback low.'),
        );
        expect(
          signal.operatorSummary,
          contains(
            'Dispatch was unavailable, so ONYX kept the live-ops sequence moving in Tactical Track.',
          ),
        );
        final decisionBias = signal.toBrainDecisionBias();
        expect(decisionBias, isNotNull);
        expect(decisionBias!.scope, BrainDecisionBiasScope.sequenceFallback);
        expect(decisionBias.preferredTarget, OnyxToolTarget.tacticalTrack);
      } finally {
        if (workspace.existsSync()) {
          workspace.deleteSync(recursive: true);
        }
      }
    },
  );

  test(
    'local replay history signal service expands persisted replay bias stacks in stored order',
    () async {
      final workspace = Directory.systemTemp.createTempSync(
        'onyx-replay-history-signal-stack-',
      );

      try {
        final scenarioDirectory = Directory(
          '${workspace.path}/simulations/scenarios/monitoring',
        )..createSync(recursive: true);
        final historyDirectory = Directory(
          '${workspace.path}/simulations/results/history',
        )..createSync(recursive: true);

        final sourceScenario = File(
          '${Directory.current.path}/simulations/scenarios/monitoring/scenario_monitoring_priority_sequence_review_track_validation_v1.json',
        );
        final scenarioJson =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        scenarioJson['scenarioId'] =
            'parser_monitoring_priority_sequence_review_track_bias_stack_v1';
        scenarioJson['title'] = 'Sequence fallback replay history stack probe';

        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_monitoring_priority_sequence_review_track_bias_stack_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(scenarioJson),
        );

        final result = ScenarioResult(
          scenarioId: scenarioJson['scenarioId'] as String,
          runId: DateTime.utc(2026, 4, 2, 2, 45),
          actualOutcome: ScenarioActualOutcome(
            actualRoute: 'tacticalTrack',
            actualIntent: 'track_dispatch_fallback',
            actualEscalationState: 'monitoring',
            actualProjectionChanges: const <dynamic>[],
            actualDrafts: const <dynamic>[],
            actualBlockedActions: const <String>[],
            actualUiState: const <String, dynamic>{},
            appendedEvents: const <dynamic>[],
            notes: 'Dispatch stayed unavailable and replay kept Track hot.',
            commandBrainSnapshot: const OnyxCommandBrainSnapshot(
              workItemId: 'review-track-fallback',
              mode: BrainDecisionMode.deterministic,
              target: OnyxToolTarget.tacticalTrack,
              nextMoveLabel: 'OPEN TACTICAL TRACK',
              headline: 'Tactical Track is the next move',
              summary:
                  'Replay priority keeps Tactical Track in front while sequence fallback stays active.',
              advisory:
                  'Dispatch was unavailable, so ONYX kept the live-ops sequence moving in Tactical Track.',
              decisionBias: BrainDecisionBias(
                source: BrainDecisionBiasSource.replayPolicy,
                scope: BrainDecisionBiasScope.sequenceFallback,
                preferredTarget: OnyxToolTarget.tacticalTrack,
                summary:
                    'Dispatch was unavailable, so ONYX kept the live-ops sequence moving in Tactical Track.',
                baseSeverity: 'low',
                effectiveSeverity: 'low',
                policySourceLabel: 'scenario sequence policy',
              ),
              replayBiasStack: <BrainDecisionBias>[
                BrainDecisionBias(
                  source: BrainDecisionBiasSource.replayPolicy,
                  scope: BrainDecisionBiasScope.specialistConflict,
                  preferredTarget: OnyxToolTarget.cctvReview,
                  summary:
                      'Replay history: specialist conflict still leans back to CCTV Review.',
                  baseSeverity: 'low',
                  effectiveSeverity: 'medium',
                  policySourceLabel: 'scenario set/category policy',
                ),
              ],
            ),
          ),
          mismatches: const [],
        );
        final resultFile = File(
          '${historyDirectory.path}/result_sequence_fallback_history_stack_probe.json',
        );
        await resultFile.writeAsString(result.toJsonString(pretty: true));

        final service = LocalScenarioReplayHistorySignalService(
          workspaceRootPath: workspace.path,
        );
        final signals = await service.loadSignalStack(limit: 3);

        expect(signals, hasLength(2));
        expect(
          signals.first.scope,
          ScenarioReplayHistorySignalScope.sequenceFallback,
        );
        expect(signals.first.latestTarget, 'tacticalTrack');
        expect(signals.first.latestReplayBiasStackPosition, 0);
        expect(
          signals.first.latestReplayBiasStackSignature,
          'replayPolicy:sequenceFallback:tacticalTrack -> replayPolicy:specialistConflict:cctvReview',
        );
        expect(
          signals[1].scope,
          ScenarioReplayHistorySignalScope.specialistConflict,
        );
        expect(signals[1].latestTarget, 'cctvReview');
        expect(signals[1].latestReplayBiasStackPosition, 1);
        expect(
          signals[1].operatorSummary,
          contains(
            'Replay history: specialist conflict promoted low -> medium.',
          ),
        );
        expect(
          summarizeReplayHistorySignalStack(signals),
          'Primary replay pressure: Replay history: sequence fallback low. Dispatch was unavailable, so ONYX kept the live-ops sequence moving in Tactical Track. Secondary replay pressure: Replay history: specialist conflict promoted low -> medium. Replay history: specialist conflict still leans back to CCTV Review.',
        );
      } finally {
        if (workspace.existsSync()) {
          workspace.deleteSync(recursive: true);
        }
      }
    },
  );

  test(
    'local replay history signal service surfaces replay bias stack drift without turning it into a tertiary stack slot',
    () async {
      final workspace = Directory.systemTemp.createTempSync(
        'onyx-replay-history-signal-stack-drift-',
      );

      try {
        final scenarioDirectory = Directory(
          '${workspace.path}/simulations/scenarios/monitoring',
        )..createSync(recursive: true);
        final historyDirectory = Directory(
          '${workspace.path}/simulations/results/history',
        )..createSync(recursive: true);

        final sourceScenario = File(
          '${Directory.current.path}/simulations/scenarios/monitoring/scenario_monitoring_priority_sequence_review_track_validation_v1.json',
        );
        final scenarioJson =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        scenarioJson['scenarioId'] =
            'parser_monitoring_priority_sequence_review_track_bias_stack_drift_v1';
        scenarioJson['title'] =
            'Sequence fallback replay history stack drift probe';

        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_monitoring_priority_sequence_review_track_bias_stack_drift_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(scenarioJson),
        );

        const fallbackOnlySnapshot = OnyxCommandBrainSnapshot(
          workItemId: 'review-track-fallback',
          mode: BrainDecisionMode.deterministic,
          target: OnyxToolTarget.tacticalTrack,
          nextMoveLabel: 'OPEN TACTICAL TRACK',
          headline: 'Tactical Track is the next move',
          summary:
              'Replay priority keeps Tactical Track in front while sequence fallback stays active.',
          advisory:
              'Dispatch was unavailable, so ONYX kept the live-ops sequence moving in Tactical Track.',
          decisionBias: BrainDecisionBias(
            source: BrainDecisionBiasSource.replayPolicy,
            scope: BrainDecisionBiasScope.sequenceFallback,
            preferredTarget: OnyxToolTarget.tacticalTrack,
            summary:
                'Dispatch was unavailable, so ONYX kept the live-ops sequence moving in Tactical Track.',
            baseSeverity: 'low',
            effectiveSeverity: 'low',
            policySourceLabel: 'scenario sequence policy',
          ),
        );

        const driftedSnapshot = OnyxCommandBrainSnapshot(
          workItemId: 'review-track-fallback',
          mode: BrainDecisionMode.corroboratedSynthesis,
          target: OnyxToolTarget.tacticalTrack,
          nextMoveLabel: 'OPEN TACTICAL TRACK',
          headline: 'Tactical Track is the next move',
          summary:
              'Replay priority keeps Tactical Track in front while stacked replay pressure stays active.',
          advisory:
              'Dispatch stayed unavailable while replay conflict pressure leaned back toward CCTV Review.',
          decisionBias: BrainDecisionBias(
            source: BrainDecisionBiasSource.replayPolicy,
            scope: BrainDecisionBiasScope.sequenceFallback,
            preferredTarget: OnyxToolTarget.tacticalTrack,
            summary:
                'Dispatch was unavailable, so ONYX kept the live-ops sequence moving in Tactical Track.',
            baseSeverity: 'low',
            effectiveSeverity: 'low',
            policySourceLabel: 'scenario sequence policy',
          ),
          replayBiasStack: <BrainDecisionBias>[
            BrainDecisionBias(
              source: BrainDecisionBiasSource.replayPolicy,
              scope: BrainDecisionBiasScope.specialistConflict,
              preferredTarget: OnyxToolTarget.cctvReview,
              summary:
                  'Replay history: specialist conflict still leans back to CCTV Review.',
              baseSeverity: 'low',
              effectiveSeverity: 'medium',
              policySourceLabel: 'scenario set/category policy',
            ),
          ],
        );

        final fallbackResult = ScenarioResult(
          scenarioId: scenarioJson['scenarioId'] as String,
          runId: DateTime.utc(2026, 4, 2, 2, 45),
          actualOutcome: ScenarioActualOutcome(
            actualRoute: 'tacticalTrack',
            actualIntent: 'track_dispatch_fallback',
            actualEscalationState: 'monitoring',
            actualProjectionChanges: <dynamic>[],
            actualDrafts: <dynamic>[],
            actualBlockedActions: <String>[],
            actualUiState: <String, dynamic>{},
            appendedEvents: <dynamic>[],
            notes: 'Dispatch stayed unavailable and replay kept Track hot.',
            commandBrainSnapshot: fallbackOnlySnapshot,
          ),
          mismatches: const [],
        );
        final driftedResult = ScenarioResult(
          scenarioId: scenarioJson['scenarioId'] as String,
          runId: DateTime.utc(2026, 4, 2, 3, 15),
          actualOutcome: ScenarioActualOutcome(
            actualRoute: 'tacticalTrack',
            actualIntent: 'track_dispatch_fallback',
            actualEscalationState: 'monitoring',
            actualProjectionChanges: <dynamic>[],
            actualDrafts: <dynamic>[],
            actualBlockedActions: <String>[],
            actualUiState: <String, dynamic>{},
            appendedEvents: <dynamic>[],
            notes:
                'Dispatch stayed unavailable and replay kept Track hot while stacked replay pressure widened.',
            commandBrainSnapshot: driftedSnapshot,
          ),
          mismatches: const [],
        );

        await File(
          '${historyDirectory.path}/result_sequence_fallback_history_stack_drift_probe_a.json',
        ).writeAsString(fallbackResult.toJsonString(pretty: true));
        await File(
          '${historyDirectory.path}/result_sequence_fallback_history_stack_drift_probe_b.json',
        ).writeAsString(driftedResult.toJsonString(pretty: true));

        final service = LocalScenarioReplayHistorySignalService(
          workspaceRootPath: workspace.path,
        );
        final signals = await service.loadSignalStack(limit: 4);

        expect(signals, hasLength(3));
        expect(
          signals[0].scope,
          ScenarioReplayHistorySignalScope.sequenceFallback,
        );
        expect(
          signals[1].scope,
          ScenarioReplayHistorySignalScope.specialistConflict,
        );
        expect(
          signals[2].scope,
          ScenarioReplayHistorySignalScope.replayBiasStackDrift,
        );
        expect(signals[2].shouldBiasCommandSurface, isFalse);
        expect(signals[2].toBrainDecisionBias(), isNull);
        expect(
          signals[2].previousReplayBiasStackSignature,
          'replayPolicy:sequenceFallback:tacticalTrack',
        );
        expect(
          signals[2].latestReplayBiasStackSignature,
          'replayPolicy:sequenceFallback:tacticalTrack -> replayPolicy:specialistConflict:cctvReview',
        );
        expect(
          signals[2].operatorSummary,
          contains('Replay history: replay bias stack drift critical.'),
        );
        expect(
          signals[2].operatorSummary,
          contains('Previous pressure: Primary replay pressure: sequence fallback -> Tactical Track.'),
        );
        expect(
          signals[2].operatorSummary,
          contains('Latest pressure: Primary replay pressure: sequence fallback -> Tactical Track. Secondary replay pressure: specialist conflict -> CCTV Review.'),
        );
        final summary = summarizeReplayHistorySignalStack(signals);
        expect(summary, isNotNull);
        expect(
          summary,
          contains(
            'Primary replay pressure: Replay history: sequence fallback low.',
          ),
        );
        expect(
          summary,
          contains(
            'Secondary replay pressure: Replay history: specialist conflict promoted low -> medium.',
          ),
        );
        expect(
          summary,
          contains('Replay history: replay bias stack drift critical.'),
        );
        expect(summary, isNot(contains('Tertiary replay pressure')));
      } finally {
        if (workspace.existsSync()) {
          workspace.deleteSync(recursive: true);
        }
      }
    },
  );

  test(
    'local replay history signal service reports sequence fallback recovery when dispatch path is restored',
    () async {
      final workspace = Directory.systemTemp.createTempSync(
        'onyx-replay-history-signal-bias-recovery-',
      );

      try {
        final scenarioDirectory = Directory(
          '${workspace.path}/simulations/scenarios/monitoring',
        )..createSync(recursive: true);
        final historyDirectory = Directory(
          '${workspace.path}/simulations/results/history',
        )..createSync(recursive: true);

        final sourceScenario = File(
          '${Directory.current.path}/simulations/scenarios/monitoring/scenario_monitoring_priority_sequence_review_track_validation_v1.json',
        );
        final scenarioJson =
            jsonDecode(await sourceScenario.readAsString())
                as Map<String, dynamic>;
        scenarioJson['scenarioId'] =
            'parser_monitoring_priority_sequence_review_track_bias_recovery_v1';
        scenarioJson['title'] =
            'Sequence fallback replay history recovery signal probe';

        final scenarioFile = File(
          '${scenarioDirectory.path}/scenario_monitoring_priority_sequence_review_track_bias_recovery_v1.json',
        );
        await scenarioFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(scenarioJson),
        );

        final fallbackResult = ScenarioResult(
          scenarioId: scenarioJson['scenarioId'] as String,
          runId: DateTime.utc(2026, 4, 2, 2, 45),
          actualOutcome: ScenarioActualOutcome(
            actualRoute: 'tacticalTrack',
            actualIntent: 'track_dispatch_fallback',
            actualEscalationState: 'monitoring',
            actualProjectionChanges: const <dynamic>[],
            actualDrafts: const <dynamic>[],
            actualBlockedActions: const <String>[],
            actualUiState: const <String, dynamic>{},
            appendedEvents: const <dynamic>[],
            notes: 'Dispatch stayed unavailable and replay kept Track hot.',
            commandBrainSnapshot: const OnyxCommandBrainSnapshot(
              workItemId: 'review-track-fallback',
              mode: BrainDecisionMode.deterministic,
              target: OnyxToolTarget.tacticalTrack,
              nextMoveLabel: 'OPEN TACTICAL TRACK',
              headline: 'Tactical Track is the next move',
              summary:
                  'Replay priority keeps Tactical Track in front while sequence fallback stays active.',
              advisory:
                  'Dispatch was unavailable, so ONYX kept the live-ops sequence moving in Tactical Track.',
              decisionBias: BrainDecisionBias(
                source: BrainDecisionBiasSource.replayPolicy,
                scope: BrainDecisionBiasScope.sequenceFallback,
                preferredTarget: OnyxToolTarget.tacticalTrack,
                summary:
                    'Dispatch was unavailable, so ONYX kept the live-ops sequence moving in Tactical Track.',
                baseSeverity: 'low',
                effectiveSeverity: 'low',
                policySourceLabel: 'scenario sequence policy',
              ),
            ),
          ),
          mismatches: const [],
        );
        final restoredResult = ScenarioResult(
          scenarioId: scenarioJson['scenarioId'] as String,
          runId: DateTime.utc(2026, 4, 2, 3, 15),
          actualOutcome: ScenarioActualOutcome(
            actualRoute: 'dispatchBoard',
            actualIntent: 'dispatch_ready',
            actualEscalationState: 'monitoring',
            actualProjectionChanges: const <dynamic>[],
            actualDrafts: const <dynamic>[],
            actualBlockedActions: const <String>[],
            actualUiState: const <String, dynamic>{},
            appendedEvents: const <dynamic>[],
            notes: 'Dispatch reopened cleanly after replay fallback cleared.',
            commandBrainSnapshot: const OnyxCommandBrainSnapshot(
              workItemId: 'review-dispatch-restored',
              mode: BrainDecisionMode.deterministic,
              target: OnyxToolTarget.dispatchBoard,
              nextMoveLabel: 'OPEN DISPATCH BOARD',
              headline: 'Dispatch Board is the next move',
              summary: 'One next move is staged in Dispatch Board.',
              advisory:
                  'Review evidence is staged and Dispatch Board is ready for controller ownership.',
            ),
          ),
          mismatches: const [],
        );

        await File(
          '${historyDirectory.path}/result_sequence_fallback_history_probe.json',
        ).writeAsString(fallbackResult.toJsonString(pretty: true));
        await File(
          '${historyDirectory.path}/result_sequence_fallback_history_recovery_probe.json',
        ).writeAsString(restoredResult.toJsonString(pretty: true));

        final service = LocalScenarioReplayHistorySignalService(
          workspaceRootPath: workspace.path,
        );
        final signal = await service.loadTopSignal();
        expect(signal, isNotNull);
        expect(signal!.scenarioId, scenarioJson['scenarioId']);
        expect(signal.scope, ScenarioReplayHistorySignalScope.sequenceFallback);
        expect(signal.trend, 'clean_again');
        expect(signal.baseSeverity, 'info');
        expect(signal.effectiveSeverity, 'info');
        expect(signal.latestBranch, 'clean');
        expect(signal.latestTarget, 'dispatchBoard');
        expect(signal.latestRestoredTarget, 'dispatchBoard');
        expect(signal.latestBiasSource, 'replayPolicy');
        expect(signal.latestBiasScope, 'sequenceFallback');
        expect(signal.latestBiasSignature, 'replayPolicy:sequenceFallback');
        expect(signal.shouldBiasCommandSurface, isFalse);
        expect(signal.prioritizedTarget, isNull);
        expect(
          signal.operatorSummary,
          'Replay history: sequence fallback cleared. Dispatch Board is back in front after replay fallback cleared from Tactical Track.',
        );
        expect(signal.toBrainDecisionBias(), isNull);
      } finally {
        if (workspace.existsSync()) {
          workspace.deleteSync(recursive: true);
        }
      }
    },
  );
}
