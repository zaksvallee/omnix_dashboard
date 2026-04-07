import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/simulation/scenario_result.dart';
import 'package:omnix_dashboard/application/simulation/scenario_runner.dart';
import 'package:omnix_dashboard/domain/authority/onyx_command_brain_contract.dart';
import 'package:omnix_dashboard/domain/authority/onyx_task_protocol.dart';

void main() {
  late Directory temporaryResultsDirectory;
  late ScenarioRunner runner;

  setUp(() {
    temporaryResultsDirectory = Directory.systemTemp.createTempSync(
      'onyx-scenario-runner-test-',
    );
    runner = ScenarioRunner(
      workspaceRoot: Directory.current.path,
      resultsRootPath: temporaryResultsDirectory.path,
      runClock: () => DateTime.utc(2026, 4, 1, 8, 15, 0),
    );
  });

  tearDown(() {
    if (temporaryResultsDirectory.existsSync()) {
      temporaryResultsDirectory.deleteSync(recursive: true);
    }
  });

  group('ScenarioRunner Phase 1', () {
    test('runs admin parser scenario and writes a passing result', () async {
      final result = await runner.runScenarioFile(
        'simulations/scenarios/admin/scenario_admin_breaches_all_sites_v1.json',
      );

      expect(result.scenarioId, 'parser_admin_breaches_all_sites_v1');
      expect(result.runId, DateTime.utc(2026, 4, 1, 8, 15, 0));
      expect(result.passed, isTrue);
      expect(result.actualOutcome.actualRoute, 'admin_all_sites_read');
      expect(result.actualOutcome.actualIntent, 'portfolio_breach_lookup');
      expect(result.actualOutcome.actualEscalationState, 'none');
      expect(result.actualOutcome.actualBlockedActions, ['live_escalation']);
      expect(
        result.actualOutcome.actualUiState,
        containsPair('surface', 'admin_read_result'),
      );
      expect(result.mismatches, isEmpty);

      final resultFile = File(
        '${temporaryResultsDirectory.path}/result_parser_admin_breaches_all_sites_v1.json',
      );
      expect(resultFile.existsSync(), isTrue);

      final persistedResult = ScenarioResult.fromJsonString(
        await resultFile.readAsString(),
      );
      expect(persistedResult.passed, isTrue);
      expect(
        persistedResult.actualOutcome.actualUiState,
        containsPair('legacyWorkspaceVisible', false),
      );
    });

    test(
      'runs track fresh-entry scenario and keeps modern overview default',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/track/scenario_track_fresh_entry_modern_overview_v1.json',
        );

        expect(result.scenarioId, 'track_fresh_entry_modern_overview_v1');
        expect(result.passed, isTrue);
        expect(result.actualOutcome.actualRoute, 'track_overview');
        expect(result.actualOutcome.actualIntent, 'open_track_workspace');
        expect(result.actualOutcome.actualBlockedActions, [
          'reopen_legacy_tactical_workspace',
        ]);
        expect(
          result.actualOutcome.actualUiState,
          containsPair('surface', 'track_modern_overview'),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('modernOverviewVisible', true),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('legacyWorkspaceVisible', false),
        );
        expect(result.mismatches, isEmpty);
      },
    );

    test('runs scoped police activity scenario and keeps it read-only', () async {
      final result = await runner.runScenarioFile(
        'simulations/scenarios/admin/scenario_admin_police_activity_ms_vallee_tonight_v1.json',
      );

      expect(
        result.scenarioId,
        'parser_admin_police_activity_ms_vallee_tonight_v1',
      );
      expect(result.passed, isTrue);
      expect(result.actualOutcome.actualRoute, 'admin_scoped_read');
      expect(result.actualOutcome.actualIntent, 'site_police_activity_lookup');
      expect(result.actualOutcome.actualBlockedActions, ['live_escalation']);
      expect(
        result.actualOutcome.actualUiState,
        containsPair('surface', 'admin_read_result'),
      );
    });

    test(
      'runs weekly top-alert site scenario and keeps it deterministic',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/admin/scenario_admin_weekly_top_alert_site_v1.json',
        );

        expect(result.scenarioId, 'parser_admin_weekly_top_alert_site_v1');
        expect(result.passed, isTrue);
        expect(result.actualOutcome.actualRoute, 'admin_all_sites_read');
        expect(
          result.actualOutcome.actualIntent,
          'weekly_top_alert_site_lookup',
        );
        expect(result.actualOutcome.actualBlockedActions, ['live_escalation']);
        expect(
          result.actualOutcome.actualUiState,
          containsPair('surface', 'admin_read_result'),
        );
      },
    );

    test('runs unresolved all-sites scenario and keeps it read-only', () async {
      final result = await runner.runScenarioFile(
        'simulations/scenarios/admin/scenario_admin_unresolved_all_sites_v1.json',
      );

      expect(result.scenarioId, 'parser_admin_unresolved_all_sites_v1');
      expect(result.passed, isTrue);
      expect(result.actualOutcome.actualRoute, 'admin_all_sites_read');
      expect(result.actualOutcome.actualIntent, 'portfolio_unresolved_lookup');
      expect(result.actualOutcome.actualBlockedActions, ['live_escalation']);
      expect(
        result.actualOutcome.actualUiState,
        containsPair('surface', 'admin_read_result'),
      );
    });

    test(
      'runs dispatches today all-sites scenario and keeps it read-only',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/admin/scenario_admin_dispatches_today_all_sites_v1.json',
        );

        expect(result.scenarioId, 'parser_admin_dispatches_today_all_sites_v1');
        expect(result.passed, isTrue);
        expect(result.actualOutcome.actualRoute, 'admin_all_sites_read');
        expect(result.actualOutcome.actualIntent, 'portfolio_dispatch_lookup');
        expect(result.actualOutcome.actualBlockedActions, ['live_escalation']);
        expect(
          result.actualOutcome.actualUiState,
          containsPair('surface', 'admin_read_result'),
        );
      },
    );

    test(
      'runs Track parent rebuild scenario and preserves detailed workspace',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/track/scenario_track_parent_rebuild_preserves_session_v1.json',
        );

        expect(result.scenarioId, 'track_parent_rebuild_preserves_session_v1');
        expect(result.passed, isTrue);
        expect(result.actualOutcome.actualRoute, 'track_detailed_workspace');
        expect(result.actualOutcome.actualIntent, 'preserve_track_workspace');
        expect(result.actualOutcome.actualBlockedActions, [
          'reset_to_track_overview',
        ]);
        expect(
          result.actualOutcome.actualUiState,
          containsPair('surface', 'track_detailed_workspace'),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('detailedWorkspaceVisible', true),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('legacyWorkspaceVisible', false),
        );
      },
    );

    test(
      'runs Track parent rebuild legacy scenario and reopens the legacy workspace',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/track/scenario_track_parent_rebuild_legacy_workspace_v1.json',
        );

        expect(result.scenarioId, 'track_parent_rebuild_legacy_workspace_v1');
        expect(result.passed, isTrue);
        expect(
          result.actualOutcome.actualRoute,
          'track_legacy_tactical_workspace',
        );
        expect(result.actualOutcome.actualIntent, 'open_track_workspace');
        expect(result.actualOutcome.actualBlockedActions, isEmpty);
        expect(
          result.actualOutcome.actualUiState,
          containsPair('surface', 'track_legacy_workspace'),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('legacyWorkspaceVisible', true),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('detailedWorkspaceVisible', false),
        );
      },
    );

    test(
      'runs guard status scenario and answers in the live operations center',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/operations/scenario_guard_status_echo_3_v1.json',
        );

        expect(result.scenarioId, 'guard_status_echo_3_v1');
        expect(result.passed, isTrue);
        expect(result.actualOutcome.actualRoute, 'live_operations_center');
        expect(result.actualOutcome.actualIntent, 'guard_status_lookup');
        expect(result.actualOutcome.actualBlockedActions, isEmpty);
        expect(
          result.actualOutcome.actualUiState,
          containsPair('surface', 'guard_status_answer'),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('focusedGuardCallsign', 'Echo-3'),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('lastCheckIn', '22:12'),
        );
      },
    );

    test(
      'runs patrol report scenario and answers in the live operations center',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/operations/scenario_patrol_report_guard001_v1.json',
        );

        expect(result.scenarioId, 'patrol_report_guard001_v1');
        expect(result.passed, isTrue);
        expect(result.actualOutcome.actualRoute, 'live_operations_center');
        expect(result.actualOutcome.actualIntent, 'patrol_report_lookup');
        expect(result.actualOutcome.actualBlockedActions, isEmpty);
        expect(
          result.actualOutcome.actualUiState,
          containsPair('surface', 'patrol_report_answer'),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('guardId', 'Guard001'),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('routeLabel', 'North Perimeter'),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('durationMinutes', 17),
        );
      },
    );

    test(
      'runs guard status validation scenario with explicit vigilance detail markers',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/operations/scenario_guard_status_echo_3_validation_v1.json',
        );

        expect(result.scenarioId, 'guard_status_echo_3_validation_v1');
        expect(result.passed, isTrue);
        expect(result.actualOutcome.actualRoute, 'live_operations_center');
        expect(result.actualOutcome.actualIntent, 'guard_status_lookup');
        expect(result.actualOutcome.actualBlockedActions, isEmpty);
        expect(
          result.actualOutcome.actualUiState,
          containsPair('focusedGuardCallsign', 'Echo-3'),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('vigilanceDecay', 67),
        );
      },
    );

    test(
      'runs patrol report validation scenario with explicit route and site detail markers',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/operations/scenario_patrol_report_guard001_validation_v1.json',
        );

        expect(result.scenarioId, 'patrol_report_guard001_validation_v1');
        expect(result.passed, isTrue);
        expect(result.actualOutcome.actualRoute, 'live_operations_center');
        expect(result.actualOutcome.actualIntent, 'patrol_report_lookup');
        expect(result.actualOutcome.actualBlockedActions, isEmpty);
        expect(
          result.actualOutcome.actualUiState,
          containsPair('routeLabel', 'North Perimeter'),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('siteLabel', 'Site Ms Vallee Residence'),
        );
      },
    );

    test('runs client comms draft scenario and stages a scoped reply', () async {
      final result = await runner.runScenarioFile(
        'simulations/scenarios/client/scenario_client_comms_draft_update_v1.json',
      );

      expect(result.scenarioId, 'client_comms_draft_update_v1');
      expect(result.passed, isTrue);
      expect(result.actualOutcome.actualRoute, 'client_comms');
      expect(result.actualOutcome.actualIntent, 'draft_client_update');
      expect(result.actualOutcome.actualBlockedActions, [
        'send_without_review',
      ]);
      expect(result.actualOutcome.actualDrafts, [
        <String, dynamic>{
          'status': 'staged',
          'channel': 'telegram',
          'scopeSiteId': 'site_ms_vallee',
          'deliveryState': 'review_required',
        },
      ]);
      expect(
        result.actualOutcome.actualUiState,
        containsPair('surface', 'client_comms_draft_ready'),
      );
    });

    test(
      'runs client comms validation scenario with explicit review-state markers',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/client/scenario_client_comms_draft_update_validation_v1.json',
        );

        expect(result.scenarioId, 'client_comms_draft_update_validation_v1');
        expect(result.passed, isTrue);
        expect(result.actualOutcome.actualRoute, 'client_comms');
        expect(result.actualOutcome.actualIntent, 'draft_client_update');
        expect(result.actualOutcome.actualBlockedActions, [
          'send_without_review',
        ]);
        expect(
          result.actualOutcome.actualUiState,
          containsPair('reviewRequiredVisible', true),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('sendBlockedReason', 'review_required'),
        );
      },
    );

    test(
      'runs client comms attention-queue scenario and opens scoped handoff route',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/client/scenario_client_comms_attention_queue_pending_draft_v1.json',
        );

        expect(
          result.scenarioId,
          'client_comms_attention_queue_pending_draft_v1',
        );
        expect(result.passed, isTrue);
        expect(result.actualOutcome.actualRoute, 'client_comms');
        expect(result.actualOutcome.actualIntent, 'open_client_comms_handoff');
        expect(result.actualOutcome.actualBlockedActions, [
          'reopen_legacy_workspace',
          'send_without_review',
        ]);
        expect(result.actualOutcome.actualDrafts, [
          <String, dynamic>{
            'status': 'pending_review',
            'clientId': 'CLIENT-MS-VALLEE',
            'scopeSiteId': 'SITE-MS-VALLEE-RESIDENCE',
            'source': 'pending_draft_approval',
          },
        ]);
        expect(
          result.actualOutcome.actualUiState,
          containsPair('surface', 'live_ops_attention_queue_client_comms'),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('queueHandoffVisible', true),
        );
      },
    );

    test(
      'runs client comms attention-queue validation scenario with pending-draft markers',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/client/scenario_client_comms_attention_queue_pending_draft_validation_v1.json',
        );

        expect(
          result.scenarioId,
          'client_comms_attention_queue_pending_draft_validation_v1',
        );
        expect(result.passed, isTrue);
        expect(result.actualOutcome.actualRoute, 'client_comms');
        expect(result.actualOutcome.actualIntent, 'open_client_comms_handoff');
        expect(result.actualOutcome.actualBlockedActions, [
          'reopen_legacy_workspace',
          'send_without_review',
        ]);
        expect(
          result.actualOutcome.actualUiState,
          containsPair('pendingDraftApprovalVisible', true),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('pendingDraftCount', 1),
        );
      },
    );

    test(
      'runs client comms queue-state replay scenario and narrows the inbox in place',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/client/scenario_client_comms_queue_state_cycle_v1.json',
        );

        expect(result.scenarioId, 'client_comms_queue_state_cycle_v1');
        expect(result.passed, isTrue);
        expect(result.actualOutcome.actualRoute, 'live_operations_center');
        expect(
          result.actualOutcome.actualIntent,
          'cycle_client_comms_queue_state',
        );
        expect(result.actualOutcome.actualProjectionChanges, [
          <String, dynamic>{'queueMode': 'high_priority'},
        ]);
        expect(
          result.actualOutcome.actualUiState,
          containsPair('queueMode', 'high_priority'),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('highPriorityOnlyVisible', true),
        );
      },
    );

    test(
      'runs client comms queue-state validation scenario with queue markers',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/client/scenario_client_comms_queue_state_cycle_validation_v1.json',
        );

        expect(
          result.scenarioId,
          'client_comms_queue_state_cycle_validation_v1',
        );
        expect(result.passed, isTrue);
        expect(result.actualOutcome.actualRoute, 'live_operations_center');
        expect(
          result.actualOutcome.actualIntent,
          'cycle_client_comms_queue_state',
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('pendingDraftCount', 2),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('highPriorityCount', 1),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('timingCount', 1),
        );
      },
    );

    test(
      'runs monitoring review handoff scenario and opens CCTV route',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/monitoring/scenario_monitoring_review_action_cctv_handoff_v1.json',
        );

        expect(result.scenarioId, 'monitoring_review_action_cctv_handoff_v1');
        expect(result.passed, isTrue);
        expect(result.actualOutcome.actualRoute, 'monitoring_watch');
        expect(result.actualOutcome.actualIntent, 'open_cctv_review_handoff');
        expect(result.actualOutcome.actualEscalationState, 'review_opened');
        expect(result.actualOutcome.actualBlockedActions, [
          'dismiss_without_review',
        ]);
        expect(result.actualOutcome.actualProjectionChanges, [
          <String, dynamic>{'reviewSurface': 'cctv_review'},
        ]);
        expect(
          result.actualOutcome.actualUiState,
          containsPair('cctvRouteVisible', true),
        );
      },
    );

    test(
      'runs monitoring review handoff validation scenario with incident markers',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/monitoring/scenario_monitoring_review_action_cctv_handoff_validation_v1.json',
        );

        expect(
          result.scenarioId,
          'monitoring_review_action_cctv_handoff_validation_v1',
        );
        expect(result.passed, isTrue);
        expect(result.actualOutcome.actualRoute, 'monitoring_watch');
        expect(result.actualOutcome.actualIntent, 'open_cctv_review_handoff');
        expect(result.actualOutcome.actualEscalationState, 'review_opened');
        expect(
          result.actualOutcome.actualUiState,
          containsPair('incidentReference', 'INC-DSP-VISUAL'),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('intelligenceId', 'INTEL-DSP-VISUAL'),
        );
      },
    );

    test(
      'runs monitoring review action scenario with delayed CCTV specialist without stalling',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/monitoring/scenario_monitoring_review_action_cctv_delay_v1.json',
        );

        expect(result.scenarioId, 'monitoring_review_action_cctv_delay_v1');
        expect(result.passed, isTrue);
        expect(result.actualOutcome.actualRoute, 'monitoring_watch');
        expect(result.actualOutcome.actualIntent, 'open_cctv_review_handoff');
        expect(result.actualOutcome.actualEscalationState, 'review_opened');
        expect(result.actualOutcome.actualProjectionChanges, [
          <String, dynamic>{
            'step': 'specialist_status',
            'sourceStepId': 'open_review_action',
            'specialist': 'cctv',
            'status': 'delayed',
            'delayMs': 45000,
            'detail': 'Live verification queue exceeded the CCTV review SLA.',
          },
          <String, dynamic>{
            'step': 'review_opened',
            'reviewSurface': 'cctv_review',
          },
        ]);
        expect(result.actualOutcome.actualBlockedActions, [
          'dismiss_without_review',
        ]);
        expect(
          result.actualOutcome.actualUiState,
          containsPair('surface', 'monitoring_watch_review'),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('specialistDegradationVisible', true),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair(
            'specialistStatuses',
            containsPair('cctv', containsPair('status', 'delayed')),
          ),
        );
        expect(
          result.actualOutcome.notes,
          contains('cctv was delayed by 45000 ms at open_review_action'),
        );
        expect(
          result.actualOutcome.commandBrainSnapshot?.target,
          OnyxToolTarget.cctvReview,
        );
        expect(result.actualOutcome.commandBrainSnapshot?.confidence, 0.68);
        expect(
          result.actualOutcome.commandBrainSnapshot?.missingInfo,
          contains('Fresh CCTV specialist verification is still pending.'),
        );
        expect(
          result
              .actualOutcome
              .commandBrainSnapshot
              ?.specialistAssessments
              .single
              .specialist,
          OnyxSpecialist.cctv,
        );
        expect(result.actualOutcome.commandBrainTimeline, hasLength(1));
        expect(
          result.actualOutcome.commandBrainTimeline.single.note,
          contains('was delayed by 45000 ms'),
        );
      },
    );

    test(
      'runs monitoring review action scenario with CCTV signal loss and reroutes to Track',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/monitoring/scenario_monitoring_review_action_cctv_signal_loss_track_v1.json',
        );

        expect(
          result.scenarioId,
          'monitoring_review_action_cctv_signal_loss_track_v1',
        );
        expect(result.passed, isTrue);
        expect(result.actualOutcome.actualRoute, 'track_detailed_workspace');
        expect(result.actualOutcome.actualIntent, 'open_track_handoff');
        expect(result.actualOutcome.actualEscalationState, 'track_opened');
        expect(result.actualOutcome.actualProjectionChanges, [
          <String, dynamic>{
            'step': 'specialist_status',
            'sourceStepId': 'open_review_action',
            'specialist': 'cctv',
            'status': 'signal_lost',
            'detail': 'Primary CCTV uplink dropped during live review handoff.',
          },
          <String, dynamic>{
            'step': 'track_opened',
            'focusSiteId': 'site_ms_vallee',
          },
        ]);
        expect(result.actualOutcome.actualBlockedActions, [
          'dismiss_without_track',
        ]);
        expect(
          result.actualOutcome.actualUiState,
          containsPair('surface', 'live_ops_track_handoff'),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('trackHandoffVisible', true),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('specialistDegradationVisible', true),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair(
            'specialistStatuses',
            containsPair('cctv', containsPair('status', 'signal_lost')),
          ),
        );
        expect(
          result.actualOutcome.notes,
          contains('cctv lost signal at open_review_action'),
        );
        expect(
          result.actualOutcome.notes,
          contains('rerouted open_review_action to open_track_handoff'),
        );
        expect(
          result.actualOutcome.commandBrainSnapshot?.target,
          OnyxToolTarget.tacticalTrack,
        );
        expect(result.actualOutcome.commandBrainSnapshot?.confidence, 0.63);
        expect(
          result.actualOutcome.commandBrainSnapshot?.followUpLabel,
          'RESTORE CCTV SIGNAL',
        );
        expect(
          result.actualOutcome.commandBrainSnapshot?.missingInfo,
          contains('CCTV specialist signal recovery is still pending.'),
        );
        expect(
          result
              .actualOutcome
              .commandBrainSnapshot
              ?.specialistAssessments
              .single
              .priority,
          SpecialistAssessmentPriority.critical,
        );
        expect(result.actualOutcome.commandBrainTimeline, hasLength(1));
        expect(
          result.actualOutcome.commandBrainTimeline.single.stage,
          'open_track_handoff',
        );
        expect(
          result.actualOutcome.commandBrainTimeline.single.note,
          contains('lost signal'),
        );
      },
    );

    test(
      'runs monitoring review action scenario with conflicting specialist assessments and keeps review stable',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/monitoring/scenario_monitoring_review_action_specialist_conflict_v1.json',
        );

        expect(
          result.scenarioId,
          'monitoring_review_action_specialist_conflict_v1',
        );
        expect(result.passed, isTrue);
        expect(result.actualOutcome.actualRoute, 'monitoring_watch');
        expect(result.actualOutcome.actualIntent, 'open_cctv_review_handoff');
        expect(result.actualOutcome.actualEscalationState, 'review_opened');
        expect(result.actualOutcome.actualProjectionChanges, [
          <String, dynamic>{
            'step': 'specialist_conflict',
            'sourceStepId': 'open_review_action',
            'target': 'cctvReview',
            'specialists': <String>['cctv', 'track'],
            'recommendedTargets': <String>['cctvReview', 'tacticalTrack'],
            'summary': 'cctv->cctvReview | track->tacticalTrack',
          },
          <String, dynamic>{
            'step': 'review_opened',
            'reviewSurface': 'cctv_review',
          },
        ]);
        expect(result.actualOutcome.actualBlockedActions, [
          'dismiss_without_review',
        ]);
        expect(
          result.actualOutcome.actualUiState,
          containsPair('surface', 'monitoring_watch_review'),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('specialistConflictVisible', true),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('specialistConflictCount', 2),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair(
            'specialistConflictSummary',
            'cctv->cctvReview | track->tacticalTrack',
          ),
        );
        expect(
          result.actualOutcome.notes,
          contains(
            'specialist conflict at open_review_action: cctv->cctvReview | track->tacticalTrack',
          ),
        );
        expect(
          result.actualOutcome.commandBrainSnapshot?.mode,
          BrainDecisionMode.corroboratedSynthesis,
        );
        expect(
          result.actualOutcome.commandBrainSnapshot?.target,
          OnyxToolTarget.cctvReview,
        );
        expect(result.actualOutcome.commandBrainSnapshot?.confidence, 0.74);
        expect(
          result.actualOutcome.commandBrainSnapshot?.followUpLabel,
          'RESOLVE SPECIALIST CONFLICT',
        );
        expect(
          result.actualOutcome.commandBrainSnapshot?.missingInfo,
          contains(
            'Conflicting specialist recommendations still need reconciliation before the next move is locked.',
          ),
        );
        expect(
          result.actualOutcome.commandBrainSnapshot?.specialistAssessments,
          hasLength(2),
        );
        expect(
          result.actualOutcome.commandBrainSnapshot?.specialistAssessments
              .map((assessment) => assessment.specialist)
              .toList(growable: false),
          containsAll(<OnyxSpecialist>[
            OnyxSpecialist.cctv,
            OnyxSpecialist.track,
          ]),
        );
        expect(result.actualOutcome.commandBrainTimeline, hasLength(1));
        expect(
          result.actualOutcome.commandBrainTimeline.single.note,
          contains('specialist conflict stayed contained'),
        );
      },
    );

    test(
      'runs monitoring review action scenario with a hard specialist constraint and blocks route execution',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/monitoring/scenario_monitoring_review_action_hard_constraint_conflict_v1.json',
        );

        expect(
          result.scenarioId,
          'monitoring_review_action_hard_constraint_conflict_v1',
        );
        expect(result.passed, isTrue);
        expect(result.actualOutcome.actualRoute, 'monitoring_watch');
        expect(result.actualOutcome.actualIntent, 'open_cctv_review_handoff');
        expect(result.actualOutcome.actualEscalationState, 'review_opened');
        expect(result.actualOutcome.actualProjectionChanges, [
          <String, dynamic>{
            'step': 'specialist_conflict',
            'sourceStepId': 'open_review_action',
            'target': 'cctvReview',
            'specialists': <String>['cctv', 'guardOps'],
            'recommendedTargets': <String>['cctvReview', 'dispatchBoard'],
            'summary': 'cctv->cctvReview | guardOps->dispatchBoard',
          },
          <String, dynamic>{
            'step': 'specialist_constraint',
            'sourceStepId': 'open_review_action',
            'specialist': 'guardOps',
            'constrainedTarget': 'dispatchBoard',
            'allowRouteExecution': false,
            'summary':
                'cctv->cctvReview | guardOps->dispatchBoard => constraint:dispatchBoard',
          },
          <String, dynamic>{
            'step': 'review_opened',
            'reviewSurface': 'cctv_review',
          },
        ]);
        expect(result.actualOutcome.actualBlockedActions, [
          'dismiss_without_review',
          'advance_without_constraint_resolution',
        ]);
        expect(
          result.actualOutcome.actualUiState,
          containsPair('surface', 'monitoring_watch_review'),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('specialistConstraintVisible', true),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('routeExecutionBlockedVisible', true),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('allowRouteExecution', false),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('constrainedTarget', 'dispatchBoard'),
        );
        expect(
          result.actualOutcome.notes,
          contains(
            'hard specialist constraint at open_review_action: cctv->cctvReview | guardOps->dispatchBoard => constraint:dispatchBoard',
          ),
        );
        expect(
          result.actualOutcome.commandBrainSnapshot?.mode,
          BrainDecisionMode.specialistConstraint,
        );
        expect(
          result.actualOutcome.commandBrainSnapshot?.target,
          OnyxToolTarget.dispatchBoard,
        );
        expect(
          result.actualOutcome.commandBrainSnapshot?.allowRouteExecution,
          isFalse,
        );
        expect(result.actualOutcome.commandBrainSnapshot?.confidence, 0.93);
        expect(
          result.actualOutcome.commandBrainSnapshot?.followUpLabel,
          'CLEAR HARD CONSTRAINT',
        );
        expect(
          result.actualOutcome.commandBrainSnapshot?.missingInfo,
          contains(
            'Hard specialist constraint still blocks route execution until the contradiction is resolved.',
          ),
        );
        expect(
          result.actualOutcome.commandBrainSnapshot?.specialistAssessments,
          hasLength(2),
        );
        expect(result.actualOutcome.commandBrainTimeline, hasLength(1));
        expect(
          result.actualOutcome.commandBrainTimeline.single.snapshot.mode,
          BrainDecisionMode.specialistConstraint,
        );
        expect(
          result.actualOutcome.commandBrainTimeline.single.note,
          contains('hard specialist constraint blocked execution'),
        );
      },
    );

    test(
      'runs monitoring priority sequence scenario with a hard constraint that clears before dispatch',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/monitoring/scenario_monitoring_priority_sequence_review_constraint_dispatch_v1.json',
        );

        expect(
          result.scenarioId,
          'monitoring_priority_sequence_review_constraint_dispatch_v1',
        );
        expect(result.passed, isTrue);
        expect(result.actualOutcome.actualRoute, 'dispatch_board');
        expect(
          result.actualOutcome.actualIntent,
          'open_live_ops_priority_sequence',
        );
        expect(result.actualOutcome.actualEscalationState, 'dispatch_ready');
        expect(result.actualOutcome.actualProjectionChanges, [
          <String, dynamic>{
            'step': 'specialist_conflict',
            'sourceStepId': 'open_review_action',
            'target': 'cctvReview',
            'specialists': <String>['cctv', 'guardOps'],
            'recommendedTargets': <String>['cctvReview', 'dispatchBoard'],
            'summary': 'cctv->cctvReview | guardOps->dispatchBoard',
          },
          <String, dynamic>{
            'step': 'specialist_constraint',
            'sourceStepId': 'open_review_action',
            'specialist': 'guardOps',
            'constrainedTarget': 'dispatchBoard',
            'allowRouteExecution': false,
            'summary':
                'cctv->cctvReview | guardOps->dispatchBoard => constraint:dispatchBoard',
          },
          <String, dynamic>{
            'step': 'review_opened',
            'reviewSurface': 'cctv_review',
          },
          <String, dynamic>{
            'step': 'specialist_constraint_cleared',
            'resolvedByStepId': 'open_dispatch_handoff',
            'previousTarget': 'dispatchBoard',
            'summary':
                'cctv->cctvReview | guardOps->dispatchBoard => constraint:dispatchBoard',
          },
          <String, dynamic>{
            'step': 'specialist_conflict_cleared',
            'resolvedByStepId': 'open_dispatch_handoff',
            'specialists': <String>['cctv', 'guardOps'],
            'previousTargets': <String>['cctvReview', 'dispatchBoard'],
            'summary': 'cctv->cctvReview | guardOps->dispatchBoard',
          },
          <String, dynamic>{
            'step': 'dispatch_opened',
            'dispatchSelection': 'DSP-CHAIN-1',
          },
        ]);
        expect(result.actualOutcome.actualBlockedActions, [
          'dismiss_without_review',
          'dismiss_without_dispatch',
        ]);
        expect(
          result.actualOutcome.actualUiState,
          containsPair('surface', 'live_ops_priority_sequence'),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('specialistConflictVisible', false),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('specialistConstraintVisible', false),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('routeExecutionBlockedVisible', false),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('allowRouteExecution', true),
        );
        expect(
          result.actualOutcome.actualUiState.containsKey('constrainedTarget'),
          isFalse,
        );
        expect(
          result.actualOutcome.notes,
          contains(
            'hard specialist constraint cleared before open_dispatch_handoff toward dispatchBoard',
          ),
        );
        expect(
          result.actualOutcome.commandBrainSnapshot?.mode,
          BrainDecisionMode.deterministic,
        );
        expect(
          result.actualOutcome.commandBrainSnapshot?.target,
          OnyxToolTarget.dispatchBoard,
        );
        expect(
          result.actualOutcome.commandBrainSnapshot?.allowRouteExecution,
          isTrue,
        );
        expect(result.actualOutcome.commandBrainTimeline, hasLength(2));
        expect(
          result.actualOutcome.commandBrainTimeline.first.snapshot.mode,
          BrainDecisionMode.specialistConstraint,
        );
        expect(
          result.actualOutcome.commandBrainTimeline.last.snapshot.mode,
          BrainDecisionMode.deterministic,
        );
        expect(
          result.actualOutcome.commandBrainTimeline.last.note,
          contains('after hard specialist constraint cleared'),
        );
      },
    );

    test(
      'runs monitoring priority sequence scenario with a hard constraint that clears before Track',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/monitoring/scenario_monitoring_priority_sequence_review_constraint_track_v1.json',
        );

        expect(
          result.scenarioId,
          'monitoring_priority_sequence_review_constraint_track_v1',
        );
        expect(result.passed, isTrue);
        expect(result.actualOutcome.actualRoute, 'track_detailed_workspace');
        expect(
          result.actualOutcome.actualIntent,
          'open_live_ops_priority_sequence',
        );
        expect(result.actualOutcome.actualEscalationState, 'track_opened');
        expect(result.actualOutcome.actualProjectionChanges, [
          <String, dynamic>{
            'step': 'specialist_conflict',
            'sourceStepId': 'open_review_action',
            'target': 'cctvReview',
            'specialists': <String>['cctv', 'guardOps'],
            'recommendedTargets': <String>['cctvReview', 'dispatchBoard'],
            'summary': 'cctv->cctvReview | guardOps->dispatchBoard',
          },
          <String, dynamic>{
            'step': 'specialist_constraint',
            'sourceStepId': 'open_review_action',
            'specialist': 'guardOps',
            'constrainedTarget': 'dispatchBoard',
            'allowRouteExecution': false,
            'summary':
                'cctv->cctvReview | guardOps->dispatchBoard => constraint:dispatchBoard',
          },
          <String, dynamic>{
            'step': 'review_opened',
            'reviewSurface': 'cctv_review',
          },
          <String, dynamic>{
            'step': 'specialist_constraint_cleared',
            'resolvedByStepId': 'open_track_handoff',
            'previousTarget': 'dispatchBoard',
            'summary':
                'cctv->cctvReview | guardOps->dispatchBoard => constraint:dispatchBoard',
          },
          <String, dynamic>{
            'step': 'specialist_conflict_cleared',
            'resolvedByStepId': 'open_track_handoff',
            'specialists': <String>['cctv', 'guardOps'],
            'previousTargets': <String>['cctvReview', 'dispatchBoard'],
            'summary': 'cctv->cctvReview | guardOps->dispatchBoard',
          },
          <String, dynamic>{
            'step': 'track_opened',
            'focusSiteId': 'site_ms_vallee',
          },
        ]);
        expect(result.actualOutcome.actualBlockedActions, [
          'dismiss_without_review',
          'dismiss_without_track',
        ]);
        expect(
          result.actualOutcome.actualUiState,
          containsPair('surface', 'live_ops_priority_sequence'),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('specialistConflictVisible', false),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('specialistConstraintVisible', false),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('routeExecutionBlockedVisible', false),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('allowRouteExecution', true),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('trackHandoffVisible', true),
        );
        expect(
          result.actualOutcome.actualUiState.containsKey('constrainedTarget'),
          isFalse,
        );
        expect(
          result.actualOutcome.notes,
          contains(
            'hard specialist constraint cleared before open_track_handoff toward dispatchBoard',
          ),
        );
        expect(
          result.actualOutcome.commandBrainSnapshot?.mode,
          BrainDecisionMode.deterministic,
        );
        expect(
          result.actualOutcome.commandBrainSnapshot?.target,
          OnyxToolTarget.tacticalTrack,
        );
        expect(
          result.actualOutcome.commandBrainSnapshot?.allowRouteExecution,
          isTrue,
        );
        expect(result.actualOutcome.commandBrainTimeline, hasLength(2));
        expect(
          result.actualOutcome.commandBrainTimeline.first.snapshot.mode,
          BrainDecisionMode.specialistConstraint,
        );
        expect(
          result.actualOutcome.commandBrainTimeline.last.snapshot.mode,
          BrainDecisionMode.deterministic,
        );
        expect(
          result.actualOutcome.commandBrainTimeline.last.snapshot.target,
          OnyxToolTarget.tacticalTrack,
        );
        expect(
          result.actualOutcome.commandBrainTimeline.last.note,
          contains('after hard specialist constraint cleared'),
        );
      },
    );

    test(
      'runs monitoring priority sequence scenario with a specialist conflict that clears before Track',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/monitoring/scenario_monitoring_priority_sequence_review_conflict_track_v1.json',
        );

        expect(
          result.scenarioId,
          'monitoring_priority_sequence_review_conflict_track_v1',
        );
        expect(result.passed, isTrue);
        expect(result.actualOutcome.actualRoute, 'track_detailed_workspace');
        expect(
          result.actualOutcome.actualIntent,
          'open_live_ops_priority_sequence',
        );
        expect(result.actualOutcome.actualEscalationState, 'track_opened');
        expect(result.actualOutcome.actualProjectionChanges, [
          <String, dynamic>{
            'step': 'specialist_conflict',
            'sourceStepId': 'open_review_action',
            'target': 'cctvReview',
            'specialists': <String>['cctv', 'track'],
            'recommendedTargets': <String>['cctvReview', 'tacticalTrack'],
            'summary': 'cctv->cctvReview | track->tacticalTrack',
          },
          <String, dynamic>{
            'step': 'review_opened',
            'reviewSurface': 'cctv_review',
          },
          <String, dynamic>{
            'step': 'specialist_conflict_cleared',
            'resolvedByStepId': 'open_track_handoff',
            'specialists': <String>['cctv', 'track'],
            'previousTargets': <String>['cctvReview', 'tacticalTrack'],
            'summary': 'cctv->cctvReview | track->tacticalTrack',
          },
          <String, dynamic>{
            'step': 'track_opened',
            'focusSiteId': 'site_ms_vallee',
          },
        ]);
        expect(result.actualOutcome.actualBlockedActions, [
          'dismiss_without_review',
          'dismiss_without_track',
        ]);
        expect(
          result.actualOutcome.actualUiState,
          containsPair('surface', 'live_ops_priority_sequence'),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('specialistConflictVisible', false),
        );
        expect(
          result.actualOutcome.actualUiState.containsKey(
            'specialistConflictSummary',
          ),
          isFalse,
        );
        expect(
          result.actualOutcome.notes,
          contains(
            'specialist conflict cleared before open_track_handoff: cctv->cctvReview | track->tacticalTrack',
          ),
        );
        expect(
          result.actualOutcome.commandBrainSnapshot?.mode,
          BrainDecisionMode.deterministic,
        );
        expect(
          result.actualOutcome.commandBrainSnapshot?.target,
          OnyxToolTarget.tacticalTrack,
        );
        expect(
          result.actualOutcome.commandBrainSnapshot?.allowRouteExecution,
          isTrue,
        );
        expect(result.actualOutcome.commandBrainTimeline, hasLength(2));
        expect(
          result.actualOutcome.commandBrainTimeline.first.snapshot.mode,
          BrainDecisionMode.corroboratedSynthesis,
        );
        expect(
          result.actualOutcome.commandBrainTimeline.last.snapshot.mode,
          BrainDecisionMode.deterministic,
        );
        expect(
          result.actualOutcome.commandBrainTimeline.last.note,
          contains('after specialist conflict cleared'),
        );
      },
    );

    test(
      'runs monitoring priority sequence scenario through review and dispatch',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/monitoring/scenario_monitoring_priority_sequence_review_dispatch_v1.json',
        );

        expect(
          result.scenarioId,
          'monitoring_priority_sequence_review_dispatch_v1',
        );
        expect(result.passed, isTrue);
        expect(result.actualOutcome.actualRoute, 'dispatch_board');
        expect(
          result.actualOutcome.actualIntent,
          'open_live_ops_priority_sequence',
        );
        expect(result.actualOutcome.actualEscalationState, 'dispatch_ready');
        expect(result.actualOutcome.actualProjectionChanges, [
          <String, dynamic>{
            'step': 'review_opened',
            'reviewSurface': 'cctv_review',
          },
          <String, dynamic>{
            'step': 'dispatch_opened',
            'dispatchSelection': 'DSP-CHAIN-1',
          },
        ]);
        expect(result.actualOutcome.actualBlockedActions, [
          'dismiss_without_review',
          'dismiss_without_dispatch',
        ]);
        expect(result.actualOutcome.appendedEvents, [
          <String, dynamic>{
            'type': 'review',
            'incidentReference': 'INC-LIVEOPS-CHAIN',
          },
          <String, dynamic>{'type': 'dispatch', 'dispatchId': 'DSP-CHAIN-1'},
        ]);
        expect(
          result.actualOutcome.actualUiState,
          containsPair('surface', 'live_ops_priority_sequence'),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('finalRoute', 'dispatch_board'),
        );
        expect(
          result.actualOutcome.actualUiState.containsKey('trackHandoffVisible'),
          isFalse,
        );
        expect(
          result.actualOutcome.commandBrainSnapshot?.target,
          OnyxToolTarget.dispatchBoard,
        );
        expect(
          result.actualOutcome.commandBrainSnapshot?.mode,
          BrainDecisionMode.deterministic,
        );
        expect(result.actualOutcome.commandBrainTimeline, hasLength(2));
        expect(
          result.actualOutcome.commandBrainTimeline.first.stage,
          'open_review_action',
        );
        expect(
          result.actualOutcome.commandBrainTimeline.last.snapshot.target,
          OnyxToolTarget.dispatchBoard,
        );
      },
    );

    test(
      'runs monitoring priority sequence validation scenario through review and dispatch only',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/monitoring/scenario_monitoring_priority_sequence_review_dispatch_validation_v1.json',
        );

        expect(
          result.scenarioId,
          'monitoring_priority_sequence_review_dispatch_validation_v1',
        );
        expect(result.passed, isTrue);
        expect(result.actualOutcome.actualRoute, 'dispatch_board');
        expect(
          result.actualOutcome.actualIntent,
          'open_live_ops_priority_sequence',
        );
        expect(result.actualOutcome.actualEscalationState, 'dispatch_ready');
        expect(
          result.actualOutcome.actualUiState,
          containsPair('readyToDispatchVisible', true),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('priorityLane', 'priority_response'),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('cctvRouteVisible', true),
        );
        expect(
          result.actualOutcome.actualUiState.containsKey('trackHandoffVisible'),
          isFalse,
        );
      },
    );

    test(
      'runs monitoring priority sequence scenario through review and Track',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/monitoring/scenario_monitoring_priority_sequence_review_track_v1.json',
        );

        expect(
          result.scenarioId,
          'monitoring_priority_sequence_review_track_v1',
        );
        expect(result.passed, isTrue);
        expect(result.actualOutcome.actualRoute, 'track_detailed_workspace');
        expect(
          result.actualOutcome.actualIntent,
          'open_live_ops_priority_sequence',
        );
        expect(result.actualOutcome.actualEscalationState, 'track_opened');
        expect(result.actualOutcome.actualProjectionChanges, [
          <String, dynamic>{
            'step': 'review_opened',
            'reviewSurface': 'cctv_review',
          },
          <String, dynamic>{
            'step': 'track_opened',
            'focusSiteId': 'site_ms_vallee',
          },
        ]);
        expect(result.actualOutcome.actualBlockedActions, [
          'dismiss_without_review',
          'dismiss_without_track',
        ]);
        expect(result.actualOutcome.appendedEvents, [
          <String, dynamic>{
            'type': 'review',
            'incidentReference': 'INC-LIVEOPS-CHAIN',
          },
          <String, dynamic>{'type': 'track', 'siteId': 'site_ms_vallee'},
        ]);
        expect(
          result.actualOutcome.notes,
          contains('rerouted open_dispatch_handoff to open_track_handoff'),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('surface', 'live_ops_priority_sequence'),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('finalRoute', 'track_detailed_workspace'),
        );
        expect(
          result.actualOutcome.actualUiState.containsKey(
            'dispatchHandoffVisible',
          ),
          isFalse,
        );
        expect(
          result.actualOutcome.commandBrainSnapshot?.target,
          OnyxToolTarget.tacticalTrack,
        );
        expect(
          result.actualOutcome.commandBrainSnapshot?.supportingSpecialists,
          contains(OnyxSpecialist.cctv),
        );
        expect(
          result.actualOutcome.commandBrainSnapshot?.decisionBias?.scope,
          BrainDecisionBiasScope.sequenceFallback,
        );
        expect(result.actualOutcome.commandBrainTimeline, hasLength(2));
        expect(
          result.actualOutcome.commandBrainTimeline.first.snapshot.target,
          OnyxToolTarget.cctvReview,
        );
        expect(
          result.actualOutcome.commandBrainTimeline.last.stage,
          'open_track_handoff',
        );
        expect(
          result.actualOutcome.commandBrainTimeline.last.signatureSegment,
          'open_track_handoff:tacticalTrack:replayPolicy:sequenceFallback',
        );
        expect(
          result.actualOutcome.commandBrainTimeline.last.note,
          contains(
            'Replay policy bias: Dispatch was unavailable, so ONYX kept the live-ops sequence moving in Tactical Track.',
          ),
        );
      },
    );

    test(
      'runs monitoring priority sequence validation scenario through review and Track only',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/monitoring/scenario_monitoring_priority_sequence_review_track_validation_v1.json',
        );

        expect(
          result.scenarioId,
          'monitoring_priority_sequence_review_track_validation_v1',
        );
        expect(result.passed, isTrue);
        expect(result.actualOutcome.actualRoute, 'track_detailed_workspace');
        expect(
          result.actualOutcome.actualIntent,
          'open_live_ops_priority_sequence',
        );
        expect(result.actualOutcome.actualEscalationState, 'track_opened');
        expect(
          result.actualOutcome.actualUiState,
          containsPair('readyToTrackVisible', true),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('trackLabel', 'Ms Vallee chain track'),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('cctvRouteVisible', true),
        );
        expect(
          result.actualOutcome.actualUiState.containsKey(
            'dispatchHandoffVisible',
          ),
          isFalse,
        );
        expect(
          result.actualOutcome.commandBrainSnapshot?.decisionBias?.scope,
          BrainDecisionBiasScope.sequenceFallback,
        );
        expect(
          result.actualOutcome.commandBrainTimeline.last.signatureSegment,
          'open_track_handoff:tacticalTrack:replayPolicy:sequenceFallback',
        );
        expect(
          result.actualOutcome.commandBrainTimeline.last.note,
          contains(
            'Replay policy bias: Dispatch was unavailable, so ONYX kept the live-ops sequence moving in Tactical Track.',
          ),
        );
      },
    );

    test(
      'runs monitoring priority sequence validation scenario through review and Track with stacked replay pressure',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/monitoring/scenario_monitoring_priority_sequence_review_track_conflict_validation_v1.json',
        );

        expect(
          result.scenarioId,
          'monitoring_priority_sequence_review_track_conflict_validation_v1',
        );
        expect(result.passed, isTrue);
        expect(result.actualOutcome.actualRoute, 'track_detailed_workspace');
        expect(
          result.actualOutcome.actualIntent,
          'open_live_ops_priority_sequence',
        );
        expect(result.actualOutcome.actualEscalationState, 'track_opened');
        expect(
          result.actualOutcome.actualUiState,
          containsPair('specialistConflictVisible', true),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair(
            'specialistConflictSummary',
            'cctv->cctvReview | track->tacticalTrack',
          ),
        );
        expect(
          result.actualOutcome.commandBrainSnapshot?.mode,
          BrainDecisionMode.corroboratedSynthesis,
        );
        expect(
          result.actualOutcome.commandBrainSnapshot?.decisionBias?.scope,
          BrainDecisionBiasScope.sequenceFallback,
        );
        expect(
          result.actualOutcome.commandBrainSnapshot?.replayBiasStackSignature,
          'replayPolicy:sequenceFallback:tacticalTrack -> replayPolicy:specialistConflict:cctvReview',
        );
        expect(
          result.actualOutcome.commandBrainTimeline.last.signatureSegment,
          'open_track_handoff:tacticalTrack:stack:replayPolicy:sequenceFallback:tacticalTrack -> replayPolicy:specialistConflict:cctvReview',
        );
        expect(
          result.actualOutcome.commandBrainTimeline.last.note,
          contains('Primary replay pressure: Replay policy bias: Dispatch was unavailable'),
        );
        expect(
          result.actualOutcome.commandBrainTimeline.last.note,
          contains(
            'Secondary replay pressure: Replay policy bias: Specialist conflict (cctv->cctvReview | track->tacticalTrack) still leaned back to CCTV Review while Tactical Track stayed in front.',
          ),
        );
      },
    );

    test(
      'runs monitoring priority sequence scenario through dispatch and Track',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/monitoring/scenario_monitoring_priority_sequence_dispatch_track_v1.json',
        );

        expect(
          result.scenarioId,
          'monitoring_priority_sequence_dispatch_track_v1',
        );
        expect(result.passed, isTrue);
        expect(result.actualOutcome.actualRoute, 'track_detailed_workspace');
        expect(
          result.actualOutcome.actualIntent,
          'open_live_ops_priority_sequence',
        );
        expect(result.actualOutcome.actualEscalationState, 'track_opened');
        expect(result.actualOutcome.actualProjectionChanges, [
          <String, dynamic>{
            'step': 'dispatch_opened',
            'dispatchSelection': 'DSP-CHAIN-1',
          },
          <String, dynamic>{
            'step': 'track_opened',
            'focusSiteId': 'site_ms_vallee',
          },
        ]);
        expect(result.actualOutcome.actualBlockedActions, [
          'dismiss_without_dispatch',
          'dismiss_without_track',
        ]);
        expect(
          result.actualOutcome.actualUiState,
          containsPair('surface', 'live_ops_priority_sequence'),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('finalRoute', 'track_detailed_workspace'),
        );
        expect(
          result.actualOutcome.actualUiState.containsKey('reviewActionVisible'),
          isFalse,
        );
      },
    );

    test(
      'runs monitoring priority sequence validation scenario through dispatch and Track only',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/monitoring/scenario_monitoring_priority_sequence_dispatch_track_validation_v1.json',
        );

        expect(
          result.scenarioId,
          'monitoring_priority_sequence_dispatch_track_validation_v1',
        );
        expect(result.passed, isTrue);
        expect(result.actualOutcome.actualRoute, 'track_detailed_workspace');
        expect(
          result.actualOutcome.actualIntent,
          'open_live_ops_priority_sequence',
        );
        expect(result.actualOutcome.actualEscalationState, 'track_opened');
        expect(
          result.actualOutcome.actualUiState,
          containsPair('readyToDispatchVisible', true),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('readyToTrackVisible', true),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('priorityLane', 'priority_response'),
        );
        expect(
          result.actualOutcome.actualUiState.containsKey('reviewActionVisible'),
          isFalse,
        );
      },
    );

    test(
      'runs monitoring priority sequence scenario through review dispatch and Track',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/monitoring/scenario_monitoring_priority_sequence_review_dispatch_track_v1.json',
        );

        expect(
          result.scenarioId,
          'monitoring_priority_sequence_review_dispatch_track_v1',
        );
        expect(result.passed, isTrue);
        expect(result.actualOutcome.actualRoute, 'track_detailed_workspace');
        expect(
          result.actualOutcome.actualIntent,
          'open_live_ops_priority_sequence',
        );
        expect(result.actualOutcome.actualEscalationState, 'track_opened');
        expect(result.actualOutcome.actualProjectionChanges, [
          <String, dynamic>{
            'step': 'review_opened',
            'reviewSurface': 'cctv_review',
          },
          <String, dynamic>{
            'step': 'dispatch_opened',
            'dispatchSelection': 'DSP-CHAIN-1',
          },
          <String, dynamic>{
            'step': 'track_opened',
            'focusSiteId': 'site_ms_vallee',
          },
        ]);
        expect(result.actualOutcome.actualBlockedActions, [
          'dismiss_without_review',
          'dismiss_without_dispatch',
          'dismiss_without_track',
        ]);
        expect(
          result.actualOutcome.actualUiState,
          containsPair('surface', 'live_ops_priority_sequence'),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('finalRoute', 'track_detailed_workspace'),
        );
      },
    );

    test(
      'runs monitoring priority sequence validation scenario with final takeover markers',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/monitoring/scenario_monitoring_priority_sequence_review_dispatch_track_validation_v1.json',
        );

        expect(
          result.scenarioId,
          'monitoring_priority_sequence_review_dispatch_track_validation_v1',
        );
        expect(result.passed, isTrue);
        expect(result.actualOutcome.actualRoute, 'track_detailed_workspace');
        expect(
          result.actualOutcome.actualIntent,
          'open_live_ops_priority_sequence',
        );
        expect(result.actualOutcome.actualEscalationState, 'track_opened');
        expect(
          result.actualOutcome.actualUiState,
          containsPair('readyToDispatchVisible', true),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('readyToTrackVisible', true),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('trackLabel', 'Ms Vallee chain track'),
        );
      },
    );

    test(
      'runs monitoring watch scenario and queues review before dispatch',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/monitoring/scenario_monitoring_watchlist_match_review_v1.json',
        );

        expect(result.scenarioId, 'monitoring_watchlist_match_review_v1');
        expect(result.passed, isTrue);
        expect(result.actualOutcome.actualRoute, 'monitoring_watch');
        expect(result.actualOutcome.actualIntent, 'review_watch_signal');
        expect(result.actualOutcome.actualEscalationState, 'review_pending');
        expect(result.actualOutcome.actualBlockedActions, [
          'dispatch_without_review',
        ]);
        expect(
          result.actualOutcome.actualUiState,
          containsPair('surface', 'monitoring_watch_review'),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('watchlistQueueVisible', true),
        );
      },
    );

    test(
      'runs monitoring watch validation scenario with explicit review gate markers',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/monitoring/scenario_monitoring_watchlist_match_review_validation_v1.json',
        );

        expect(
          result.scenarioId,
          'monitoring_watchlist_match_review_validation_v1',
        );
        expect(result.passed, isTrue);
        expect(result.actualOutcome.actualRoute, 'monitoring_watch');
        expect(result.actualOutcome.actualIntent, 'review_watch_signal');
        expect(result.actualOutcome.actualEscalationState, 'review_pending');
        expect(result.actualOutcome.actualBlockedActions, [
          'dispatch_without_review',
        ]);
        expect(
          result.actualOutcome.actualUiState,
          containsPair('reviewGateActive', true),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('directDispatchAllowed', false),
        );
      },
    );

    test(
      'runs dispatch flow scenario and summarizes only today dispatches',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/dispatch/scenario_dispatch_today_summary_v1.json',
        );

        expect(result.scenarioId, 'dispatch_today_summary_v1');
        expect(result.passed, isTrue);
        expect(result.actualOutcome.actualRoute, 'dispatch_board');
        expect(result.actualOutcome.actualIntent, 'dispatch_today_lookup');
        expect(result.actualOutcome.actualEscalationState, 'none');
        expect(result.actualOutcome.actualBlockedActions, isEmpty);
        expect(result.actualOutcome.actualDrafts, [
          <String, dynamic>{
            'type': 'dispatch_summary',
            'dispatchCount': 2,
            'dispatchIds': ['DSP-TODAY-1', 'DSP-TODAY-2'],
          },
        ]);
        expect(
          result.actualOutcome.actualUiState,
          containsPair('surface', 'dispatch_today_summary'),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('dispatchCount', 2),
        );
      },
    );

    test(
      'runs dispatch handoff scenario and opens the priority dispatch board',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/dispatch/scenario_dispatch_attention_queue_handoff_v1.json',
        );

        expect(result.scenarioId, 'dispatch_attention_queue_handoff_v1');
        expect(result.passed, isTrue);
        expect(result.actualOutcome.actualRoute, 'dispatch_board');
        expect(result.actualOutcome.actualIntent, 'open_dispatch_handoff');
        expect(result.actualOutcome.actualEscalationState, 'dispatch_ready');
        expect(result.actualOutcome.actualProjectionChanges, [
          <String, dynamic>{'dispatchSelection': 'DSP-PRIORITY-7'},
        ]);
        expect(result.actualOutcome.actualBlockedActions, [
          'dismiss_without_dispatch',
        ]);
        expect(
          result.actualOutcome.actualUiState,
          containsPair('surface', 'live_ops_dispatch_handoff'),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('dispatchId', 'DSP-PRIORITY-7'),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('incidentReference', 'INC-9912-ALPHA'),
        );
      },
    );

    test(
      'runs incident timeline scenario and produces a scoped summary draft',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/timeline/scenario_incident_timeline_summary_v1.json',
        );

        expect(result.scenarioId, 'incident_timeline_summary_v1');
        expect(result.passed, isTrue);
        expect(result.actualOutcome.actualRoute, 'reports_workspace');
        expect(result.actualOutcome.actualIntent, 'summarize_incident');
        expect(result.actualOutcome.actualEscalationState, 'none');
        expect(result.actualOutcome.actualBlockedActions, isEmpty);
        expect(result.actualOutcome.actualDrafts, [
          <String, dynamic>{
            'type': 'incident_summary',
            'incidentReference': 'INC-8829-QX',
            'headline': 'INC-8829-QX is investigating at Ms Vallee Residence.',
            'summary':
                'Perimeter breach with elevated priority. Unauthorized person matched watchlist context.',
          },
        ]);
        expect(
          result.actualOutcome.actualUiState,
          containsPair('surface', 'incident_summary'),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('timelineVisible', true),
        );
      },
    );

    test(
      'runs Track parent rebuild validation scenario and preserves detailed workspace',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/track/scenario_track_parent_rebuild_preserves_session_validation_v1.json',
        );

        expect(
          result.scenarioId,
          'track_parent_rebuild_preserves_session_validation_v1',
        );
        expect(result.passed, isTrue);
        expect(result.actualOutcome.actualRoute, 'track_detailed_workspace');
        expect(result.actualOutcome.actualIntent, 'preserve_track_workspace');
        expect(result.actualOutcome.actualBlockedActions, [
          'reset_to_track_overview',
        ]);
        expect(
          result.actualOutcome.actualUiState,
          containsPair('surface', 'track_detailed_workspace'),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('detailedWorkspaceVisible', true),
        );
      },
    );

    test(
      'runs Track live ops handoff scenario and opens the detailed workspace',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/track/scenario_track_live_ops_handoff_v1.json',
        );

        expect(result.scenarioId, 'track_live_ops_handoff_v1');
        expect(result.passed, isTrue);
        expect(result.actualOutcome.actualRoute, 'track_detailed_workspace');
        expect(result.actualOutcome.actualIntent, 'open_track_handoff');
        expect(result.actualOutcome.actualEscalationState, 'track_opened');
        expect(result.actualOutcome.actualProjectionChanges, [
          <String, dynamic>{'focusSiteId': 'site_ms_vallee'},
        ]);
        expect(result.actualOutcome.actualBlockedActions, [
          'dismiss_without_track',
        ]);
        expect(
          result.actualOutcome.actualUiState,
          containsPair('surface', 'live_ops_track_handoff'),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('incidentReference', 'INC-7721-TRACK'),
        );
      },
    );

    test(
      'runs Track live ops handoff validation scenario and keeps takeover ready',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/track/scenario_track_live_ops_handoff_validation_v1.json',
        );

        expect(result.scenarioId, 'track_live_ops_handoff_validation_v1');
        expect(result.passed, isTrue);
        expect(result.actualOutcome.actualRoute, 'track_detailed_workspace');
        expect(result.actualOutcome.actualIntent, 'open_track_handoff');
        expect(result.actualOutcome.actualEscalationState, 'track_opened');
        expect(result.actualOutcome.actualProjectionChanges, [
          <String, dynamic>{'focusSiteId': 'site_ms_vallee'},
        ]);
        expect(result.actualOutcome.actualBlockedActions, [
          'dismiss_without_track',
        ]);
        expect(
          result.actualOutcome.actualUiState,
          containsPair('surface', 'live_ops_track_handoff'),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('readyToTrackVisible', true),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('detailedWorkspaceVisible', true),
        );
      },
    );

    test(
      'runs incident timeline validation scenario and produces a scoped summary draft',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/timeline/scenario_incident_timeline_summary_validation_v1.json',
        );

        expect(result.scenarioId, 'incident_timeline_summary_validation_v1');
        expect(result.passed, isTrue);
        expect(result.actualOutcome.actualRoute, 'reports_workspace');
        expect(result.actualOutcome.actualIntent, 'summarize_incident');
        expect(result.actualOutcome.actualEscalationState, 'none');
        expect(result.actualOutcome.actualBlockedActions, isEmpty);
        expect(result.actualOutcome.actualDrafts, [
          <String, dynamic>{
            'type': 'incident_summary',
            'incidentReference': 'INC-8829-QX',
            'headline': 'INC-8829-QX is investigating at Ms Vallee Residence.',
            'summary':
                'Perimeter breach with elevated priority. Unauthorized person matched watchlist context.',
          },
        ]);
        expect(
          result.actualOutcome.actualUiState,
          containsPair('surface', 'incident_summary'),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('timelineVisible', true),
        );
      },
    );

    test(
      'runs dispatch handoff validation scenario and keeps the priority handoff visible',
      () async {
        final result = await runner.runScenarioFile(
          'simulations/scenarios/dispatch/scenario_dispatch_attention_queue_handoff_validation_v1.json',
        );

        expect(
          result.scenarioId,
          'dispatch_attention_queue_handoff_validation_v1',
        );
        expect(result.passed, isTrue);
        expect(result.actualOutcome.actualRoute, 'dispatch_board');
        expect(result.actualOutcome.actualIntent, 'open_dispatch_handoff');
        expect(result.actualOutcome.actualEscalationState, 'dispatch_ready');
        expect(result.actualOutcome.actualProjectionChanges, [
          <String, dynamic>{'dispatchSelection': 'DSP-PRIORITY-7'},
        ]);
        expect(result.actualOutcome.actualBlockedActions, [
          'dismiss_without_dispatch',
        ]);
        expect(
          result.actualOutcome.actualUiState,
          containsPair('surface', 'live_ops_dispatch_handoff'),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('readyToDispatchVisible', true),
        );
        expect(
          result.actualOutcome.actualUiState,
          containsPair('priorityLaneVisible', true),
        );
      },
    );

    test(
      'records mismatches when expected route does not match actual route',
      () async {
        final definition = await runner.loadScenarioFile(
          'simulations/scenarios/admin/scenario_admin_breaches_all_sites_v1.json',
        );
        final mismatchedDefinition = definition.copyWith(
          expectedOutcome: definition.expectedOutcome.copyWith(
            expectedRoute: 'admin_scoped_read',
          ),
        );

        final result = await runner.runScenario(mismatchedDefinition);

        expect(result.passed, isFalse);
        expect(result.mismatches, hasLength(1));
        expect(result.mismatches.single.field, 'expectedRoute');
        expect(result.mismatches.single.expected, 'admin_scoped_read');
        expect(result.mismatches.single.actual, 'admin_all_sites_read');
      },
    );

    test(
      'records a dedicated mismatch when the expected replay bias stack drifts',
      () async {
        final definition = await runner.loadScenarioFile(
          'simulations/scenarios/monitoring/scenario_monitoring_priority_sequence_review_track_conflict_validation_v1.json',
        );
        final expectedSnapshotJson = Map<String, Object?>.from(
          definition.expectedOutcome.commandBrainSnapshot!.toJson(),
        );
        expectedSnapshotJson['replayBiasStack'] = <Object?>[
          (expectedSnapshotJson['decisionBias'] as Map).cast<String, Object?>(),
        ];
        final mismatchedDefinition = definition.copyWith(
          expectedOutcome: definition.expectedOutcome.copyWith(
            commandBrainSnapshot: OnyxCommandBrainSnapshot.fromJson(
              expectedSnapshotJson,
            ),
          ),
        );

        final result = await runner.runScenario(mismatchedDefinition);

        expect(result.passed, isFalse);
        expect(
          result.mismatches.map((mismatch) => mismatch.field),
          contains('commandBrainReplayBiasStack'),
        );
        final replayBiasStackMismatch = result.mismatches.firstWhere(
          (mismatch) => mismatch.field == 'commandBrainReplayBiasStack',
        );
        expect(
          replayBiasStackMismatch.expected,
          containsPair(
            'signature',
            'replayPolicy:sequenceFallback:tacticalTrack',
          ),
        );
        expect(
          replayBiasStackMismatch.actual,
          containsPair(
            'signature',
            'replayPolicy:sequenceFallback:tacticalTrack -> replayPolicy:specialistConflict:cctvReview',
          ),
        );
      },
    );
  });
}
