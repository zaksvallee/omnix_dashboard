import 'dart:convert';
import 'dart:io';

import '../../domain/authority/onyx_command_brain_contract.dart';
import '../../domain/authority/onyx_command_intent.dart';
import '../../domain/authority/onyx_task_protocol.dart';
import '../onyx_command_parser.dart';
import 'scenario_definition.dart';
import 'scenario_fixture_loader.dart';
import 'scenario_result.dart';

enum ScenarioExecutionMode {
  parserAdminRead,
  trackSessionState,
  guardOpsRead,
  clientCommsDraft,
  monitoringWatch,
  dispatchFlow,
  incidentTimeline,
}

class ScenarioRunner {
  ScenarioRunner({
    required this.workspaceRoot,
    String? resultsRootPath,
    String? historyResultsRootPath,
    OnyxCommandParser? commandParser,
    ScenarioFixtureLoader? fixtureLoader,
    DateTime Function()? runClock,
  }) : resultsRootPath =
           resultsRootPath ??
           _normalizePath('$workspaceRoot/simulations/results/latest'),
       historyResultsRootPath =
           historyResultsRootPath ??
           _normalizePath('$workspaceRoot/simulations/results/history'),
       commandParser = commandParser ?? const OnyxCommandParser(),
       fixtureLoader =
           fixtureLoader ?? ScenarioFixtureLoader(workspaceRoot: workspaceRoot),
       runClock = runClock ?? DateTime.now;

  final String workspaceRoot;
  final String resultsRootPath;
  final String historyResultsRootPath;
  final OnyxCommandParser commandParser;
  final ScenarioFixtureLoader fixtureLoader;
  final DateTime Function() runClock;

  Future<ScenarioDefinition> loadScenarioFile(String scenarioFilePath) async {
    final resolvedPath = _resolvePath(scenarioFilePath);
    final file = File(resolvedPath);
    if (!file.existsSync()) {
      throw FileSystemException('Scenario file does not exist.', resolvedPath);
    }
    return ScenarioDefinition.fromJsonString(await file.readAsString());
  }

  Future<ScenarioResult> runScenarioFile(String scenarioFilePath) async {
    final definition = await loadScenarioFile(scenarioFilePath);
    return runScenario(definition);
  }

  Future<ScenarioResult> runScenario(ScenarioDefinition definition) async {
    final fixtures = await fixtureLoader.loadFixtures(definition);
    final actualOutcome = switch (_executionModeFor(definition)) {
      ScenarioExecutionMode.parserAdminRead => _runParserAdminScenario(
        definition,
        fixtures,
      ),
      ScenarioExecutionMode.trackSessionState => _runTrackScenario(
        definition,
        fixtures,
      ),
      ScenarioExecutionMode.guardOpsRead => _runGuardOpsScenario(
        definition,
        fixtures,
      ),
      ScenarioExecutionMode.clientCommsDraft => _runClientCommsScenario(
        definition,
        fixtures,
      ),
      ScenarioExecutionMode.monitoringWatch => _runMonitoringWatchScenario(
        definition,
        fixtures,
      ),
      ScenarioExecutionMode.dispatchFlow => _runDispatchFlowScenario(
        definition,
        fixtures,
      ),
      ScenarioExecutionMode.incidentTimeline => _runIncidentTimelineScenario(
        definition,
        fixtures,
      ),
    };
    final result = ScenarioResult(
      scenarioId: definition.scenarioId,
      runId: runClock().toUtc(),
      actualOutcome: actualOutcome,
      mismatches: _compareOutcome(definition.expectedOutcome, actualOutcome),
    );
    await writeLatestResult(result);
    return result;
  }

  Future<File> writeLatestResult(ScenarioResult result) async {
    final directory = Directory(resultsRootPath);
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    final file = File(
      _normalizePath(
        '${directory.path}/result_${_normalizeId(result.scenarioId)}.json',
      ),
    );
    await file.writeAsString(result.toJsonString(pretty: true));
    return file;
  }

  Future<File> writeHistoryResult(ScenarioResult result) async {
    final directory = Directory(historyResultsRootPath);
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    final file = File(
      _normalizePath(
        '${directory.path}/result_${_normalizeId(result.scenarioId)}_${_normalizeTimestamp(result.runId)}.json',
      ),
    );
    await file.writeAsString(result.toJsonString(pretty: true));
    return file;
  }

  ScenarioExecutionMode _executionModeFor(ScenarioDefinition definition) {
    switch (definition.category) {
      case 'parser_read':
      case 'admin_portfolio_read':
        return ScenarioExecutionMode.parserAdminRead;
      case 'track_ui_state':
        return ScenarioExecutionMode.trackSessionState;
      case 'guard_ops_read':
        return ScenarioExecutionMode.guardOpsRead;
      case 'client_comms':
        return ScenarioExecutionMode.clientCommsDraft;
      case 'monitoring_watch':
        return ScenarioExecutionMode.monitoringWatch;
      case 'dispatch_flow':
        return ScenarioExecutionMode.dispatchFlow;
      case 'incident_timeline':
        return ScenarioExecutionMode.incidentTimeline;
    }
    throw UnsupportedError(
      'Scenario category "${definition.category}" is not supported in Phase 1.',
    );
  }

  ScenarioActualOutcome _runParserAdminScenario(
    ScenarioDefinition definition,
    ScenarioLoadedFixtures fixtures,
  ) {
    if (definition.inputs.prompts.isEmpty) {
      throw StateError(
        'Parser/admin scenarios require at least one prompt in Phase 1.',
      );
    }
    final prompt = definition.inputs.prompts.first;
    final parsed = commandParser.parse(prompt.text);
    final normalizedPrompt = parsed.prompt.toLowerCase();
    final authorityScope = definition.runtimeContext.authorityScope;
    final route = _adminRouteForParsedIntent(parsed.intent, authorityScope);
    final intent = _adminIntentForPrompt(
      parsed.intent,
      normalizedPrompt,
      authorityScope,
    );
    final activeSiteCount = definition.runtimeContext.activeSiteIds.length;
    final notes =
        'Resolved ${parsed.intent.name} from ${prompt.channel} under '
        '$authorityScope scope across $activeSiteCount site(s). '
        'Loaded ${fixtures.existingEvents.length} seeded event(s).';
    final isReadOnlyRoute =
        route == 'admin_all_sites_read' || route == 'admin_scoped_read';
    return ScenarioActualOutcome(
      actualRoute: route,
      actualIntent: intent,
      actualEscalationState: 'none',
      actualProjectionChanges: const <dynamic>[],
      actualDrafts: const <dynamic>[],
      actualBlockedActions: isReadOnlyRoute
          ? const <String>['live_escalation']
          : const <String>[],
      actualUiState: <String, dynamic>{
        'surface': isReadOnlyRoute
            ? 'admin_read_result'
            : 'admin_triage_result',
        'legacyWorkspaceVisible': false,
      },
      appendedEvents: const <dynamic>[],
      notes: notes,
    );
  }

  ScenarioActualOutcome _runTrackScenario(
    ScenarioDefinition definition,
    ScenarioLoadedFixtures fixtures,
  ) {
    final sessionState = fixtures.sessionState;
    final navigation = definition.inputs.navigation;
    final entryRoute = navigation?.entryRoute ?? '';
    if (entryRoute == 'live_operations_track_handoff') {
      return _runTrackHandoffScenario(fixtures);
    }
    final sessionMode = definition.runtimeContext.sessionMode;
    final persistedWorkspace = sessionState['persistedWorkspace'];
    final persistedDrilldown = sessionState['persistedDrilldown'];
    final persistedRouteState = sessionState['persistedRouteState'];
    final isFreshEntry =
        sessionMode == 'fresh_entry' &&
        entryRoute == 'track' &&
        persistedWorkspace == null &&
        persistedDrilldown == null &&
        persistedRouteState == null;
    final isParentRebuildWithDetailedWorkspace =
        sessionMode == 'parent_rebuild' &&
        entryRoute == 'track' &&
        persistedWorkspace == 'modern_detailed_workspace';
    final route = isFreshEntry
        ? 'track_overview'
        : isParentRebuildWithDetailedWorkspace
        ? 'track_detailed_workspace'
        : 'track_legacy_tactical_workspace';
    final uiState = <String, dynamic>{
      'surface': isFreshEntry
          ? 'track_modern_overview'
          : isParentRebuildWithDetailedWorkspace
          ? 'track_detailed_workspace'
          : 'track_legacy_workspace',
      'legacyWorkspaceVisible':
          !isFreshEntry && !isParentRebuildWithDetailedWorkspace,
      'modernOverviewVisible': isFreshEntry,
      'detailedWorkspaceVisible': isParentRebuildWithDetailedWorkspace,
    };
    final trackOverview = fixtures.projectionState['trackOverview'];
    final notesBuffer = StringBuffer()
      ..write('Evaluated Track entry via ')
      ..write(definition.runtimeContext.viewportProfile)
      ..write(' viewport in ')
      ..write(sessionMode)
      ..write(' mode.');
    if (trackOverview is Map) {
      final keyedTrackOverview = _stringKeyedMap(trackOverview);
      notesBuffer
        ..write(' Projection seeded ')
        ..write(keyedTrackOverview['sitesVisible'] ?? 0)
        ..write(' visible site(s) and liveTrackingEnabled=')
        ..write(keyedTrackOverview['liveTrackingEnabled'] ?? false)
        ..write('.');
    }
    return ScenarioActualOutcome(
      actualRoute: route,
      actualIntent: isParentRebuildWithDetailedWorkspace
          ? 'preserve_track_workspace'
          : 'open_track_workspace',
      actualEscalationState: 'none',
      actualProjectionChanges: const <dynamic>[],
      actualDrafts: const <dynamic>[],
      actualBlockedActions: isFreshEntry
          ? const <String>['reopen_legacy_tactical_workspace']
          : isParentRebuildWithDetailedWorkspace
          ? const <String>['reset_to_track_overview']
          : const <String>[],
      actualUiState: uiState,
      appendedEvents: const <dynamic>[],
      notes: notesBuffer.toString(),
    );
  }

  ScenarioActualOutcome _runTrackHandoffScenario(
    ScenarioLoadedFixtures fixtures,
  ) {
    final trackOverview = fixtures.projectionState['trackOverview'];
    if (trackOverview is! Map) {
      throw StateError(
        'Track handoff scenarios require a trackOverview projection fixture.',
      );
    }
    final keyedTrackOverview = _stringKeyedMap(trackOverview);
    final trackHandoff = keyedTrackOverview['trackHandoff'];
    if (trackHandoff is! Map) {
      throw StateError(
        'Track handoff scenarios require a trackOverview.trackHandoff fixture.',
      );
    }
    final keyedTrackHandoff = _stringKeyedMap(trackHandoff);
    final siteId = keyedTrackHandoff['siteId']?.toString() ?? 'site_unknown';
    final incidentReference =
        keyedTrackHandoff['incidentReference']?.toString() ?? 'INC-UNKNOWN';
    final trackLabel =
        keyedTrackHandoff['trackLabel']?.toString() ?? 'Priority Track';
    final notes =
        'Opened live operations Track handoff for $incidentReference on '
        '$trackLabel.';
    return ScenarioActualOutcome(
      actualRoute: 'track_detailed_workspace',
      actualIntent: 'open_track_handoff',
      actualEscalationState: 'track_opened',
      actualProjectionChanges: <dynamic>[
        <String, dynamic>{'focusSiteId': siteId},
      ],
      actualDrafts: const <dynamic>[],
      actualBlockedActions: const <String>['dismiss_without_track'],
      actualUiState: <String, dynamic>{
        'surface': 'live_ops_track_handoff',
        'trackWorkspaceVisible': true,
        'tacticalTrackVisible': true,
        'handoffVisible': true,
        'readyToTrackVisible': true,
        'detailedWorkspaceVisible': true,
        'incidentReference': incidentReference,
        'siteId': siteId,
        'trackLabel': trackLabel,
        'legacyWorkspaceVisible': false,
      },
      appendedEvents: const <dynamic>[],
      notes: notes,
    );
  }

  ScenarioActualOutcome _runClientCommsScenario(
    ScenarioDefinition definition,
    ScenarioLoadedFixtures fixtures,
  ) {
    final navigation = definition.inputs.navigation;
    if (navigation?.entryRoute == 'live_operations_attention_queue') {
      return _runClientCommsAttentionQueueScenario(definition, fixtures);
    }
    if (navigation?.entryRoute == 'live_operations_queue_state_chip') {
      return _runClientCommsQueueStateScenario(definition, fixtures);
    }
    if (definition.inputs.prompts.isEmpty) {
      throw StateError(
        'Client comms scenarios require at least one prompt in Phase 1.',
      );
    }
    final prompt = definition.inputs.prompts.first;
    final parsed = commandParser.parse(prompt.text);
    if (parsed.intent != OnyxCommandIntent.draftClientUpdate) {
      throw StateError(
        'Client comms Phase 1 only supports draftClientUpdate prompts.',
      );
    }
    final scopeSiteId = definition.runtimeContext.activeSiteIds.isNotEmpty
        ? definition.runtimeContext.activeSiteIds.first
        : 'site_unknown';
    final clientComms = fixtures.projectionState['clientComms'];
    final keyedClientComms = clientComms is Map
        ? _stringKeyedMap(clientComms)
        : <String, dynamic>{};
    final draft = <String, dynamic>{
      'status': 'staged',
      'channel': prompt.channel,
      'scopeSiteId': scopeSiteId,
      'deliveryState': keyedClientComms['deliveryState'] ?? 'review_required',
    };
    final notes =
        'Staged a scoped client reply from ${prompt.channel}. '
        'Delivery posture is ${draft['deliveryState']}.';
    return ScenarioActualOutcome(
      actualRoute: 'client_comms',
      actualIntent: 'draft_client_update',
      actualEscalationState: 'none',
      actualProjectionChanges: const <dynamic>[],
      actualDrafts: <dynamic>[draft],
      actualBlockedActions: const <String>['send_without_review'],
      actualUiState: <String, dynamic>{
        'surface': 'client_comms_draft_ready',
        'draftReadyVisible': true,
        'reviewRequiredVisible': true,
        'sendBlockedReason': 'review_required',
        'legacyWorkspaceVisible': false,
      },
      appendedEvents: const <dynamic>[],
      notes: notes,
    );
  }

  ScenarioActualOutcome _runClientCommsQueueStateScenario(
    ScenarioDefinition definition,
    ScenarioLoadedFixtures fixtures,
  ) {
    final clientComms = fixtures.projectionState['clientComms'];
    if (clientComms is! Map) {
      throw StateError(
        'Client comms queue-state scenarios require a clientComms projection fixture.',
      );
    }
    final keyedClientComms = _stringKeyedMap(clientComms);
    final currentQueueMode =
        keyedClientComms['queueMode']?.toString() ?? 'full';
    final nextQueueMode = switch (currentQueueMode) {
      'full' => 'high_priority',
      'high_priority' => 'full',
      'timing_only' => 'high_priority',
      _ => 'high_priority',
    };
    final pendingDraftCount = keyedClientComms['pendingDraftCount'] ?? 0;
    final highPriorityCount = keyedClientComms['highPriorityCount'] ?? 0;
    final timingCount = keyedClientComms['timingCount'] ?? 0;
    final notes =
        'Cycled the live operations queue-state chip from $currentQueueMode '
        'to $nextQueueMode with $pendingDraftCount pending draft(s).';
    return ScenarioActualOutcome(
      actualRoute: 'live_operations_center',
      actualIntent: 'cycle_client_comms_queue_state',
      actualEscalationState: 'none',
      actualProjectionChanges: <dynamic>[
        <String, dynamic>{'queueMode': nextQueueMode},
      ],
      actualDrafts: const <dynamic>[],
      actualBlockedActions: const <String>[],
      actualUiState: <String, dynamic>{
        'surface': 'live_ops_queue_state',
        'queueMode': nextQueueMode,
        'queueShapeVisible': true,
        'highPriorityOnlyVisible': nextQueueMode == 'high_priority',
        'timingOnlyVisible': nextQueueMode == 'timing_only',
        'showAllRepliesVisible': nextQueueMode != 'full',
        'pendingDraftCount': pendingDraftCount,
        'highPriorityCount': highPriorityCount,
        'timingCount': timingCount,
        'legacyWorkspaceVisible': false,
      },
      appendedEvents: const <dynamic>[],
      notes: notes,
    );
  }

  ScenarioActualOutcome _runClientCommsAttentionQueueScenario(
    ScenarioDefinition definition,
    ScenarioLoadedFixtures fixtures,
  ) {
    final clientComms = fixtures.projectionState['clientComms'];
    if (clientComms is! Map) {
      throw StateError(
        'Client comms attention-queue scenarios require a clientComms projection fixture.',
      );
    }
    final keyedClientComms = _stringKeyedMap(clientComms);
    final attentionQueueEntry = keyedClientComms['attentionQueueEntry'];
    if (attentionQueueEntry is! Map) {
      throw StateError(
        'Client comms attention-queue scenarios require a clientComms.attentionQueueEntry fixture.',
      );
    }
    final keyedQueueEntry = _stringKeyedMap(attentionQueueEntry);
    final clientId =
        keyedQueueEntry['clientId']?.toString() ?? 'CLIENT-UNKNOWN';
    final siteId = keyedQueueEntry['siteId']?.toString() ?? 'site_unknown';
    final reason =
        keyedQueueEntry['reason']?.toString() ?? 'pending_draft_approval';
    final pendingDraftCount = keyedClientComms['pendingDraftCount'] ?? 0;
    final notes =
        'Opened scoped Client Comms from live operations attention queue. '
        'Queue source is $reason with $pendingDraftCount pending draft(s).';
    return ScenarioActualOutcome(
      actualRoute: 'client_comms',
      actualIntent: 'open_client_comms_handoff',
      actualEscalationState: 'none',
      actualProjectionChanges: const <dynamic>[],
      actualDrafts: <dynamic>[
        <String, dynamic>{
          'status': 'pending_review',
          'clientId': clientId,
          'scopeSiteId': siteId,
          'source': reason,
        },
      ],
      actualBlockedActions: const <String>[
        'reopen_legacy_workspace',
        'send_without_review',
      ],
      actualUiState: <String, dynamic>{
        'surface': 'live_ops_attention_queue_client_comms',
        'scopedClientCommsVisible': true,
        'pendingDraftApprovalVisible': reason == 'pending_draft_approval',
        'queueHandoffVisible': true,
        'clientId': clientId,
        'siteId': siteId,
        'pendingDraftCount': pendingDraftCount,
        'legacyWorkspaceVisible': false,
      },
      appendedEvents: const <dynamic>[],
      notes: notes,
    );
  }

  ScenarioActualOutcome _runGuardOpsScenario(
    ScenarioDefinition definition,
    ScenarioLoadedFixtures fixtures,
  ) {
    if (definition.inputs.prompts.isEmpty) {
      throw StateError(
        'Guard ops scenarios require at least one prompt in Phase 1.',
      );
    }
    final prompt = definition.inputs.prompts.first;
    final parsed = commandParser.parse(prompt.text);
    switch (parsed.intent) {
      case OnyxCommandIntent.guardStatusLookup:
        return _runGuardStatusScenario(prompt.text, fixtures);
      case OnyxCommandIntent.patrolReportLookup:
        return _runPatrolReportScenario(prompt.text, fixtures);
      default:
        throw StateError(
          'Guard ops Phase 1 only supports guard status and patrol report prompts.',
        );
    }
  }

  ScenarioActualOutcome _runGuardStatusScenario(
    String prompt,
    ScenarioLoadedFixtures fixtures,
  ) {
    final normalizedPrompt = prompt.toLowerCase();
    final guardOps = fixtures.projectionState['guardOps'];
    final keyedGuardOps = guardOps is Map
        ? _stringKeyedMap(guardOps)
        : <String, dynamic>{};
    final guards = keyedGuardOps['guards'];
    final keyedGuards = guards is List
        ? guards.whereType<Map>().map(_stringKeyedMap).toList(growable: false)
        : const <Map<String, dynamic>>[];
    final matchedGuard = keyedGuards.firstWhere(
      (guard) => normalizedPrompt.contains(
        guard['callsign']?.toString().toLowerCase() ?? '',
      ),
      orElse: () =>
          keyedGuards.isNotEmpty ? keyedGuards.first : <String, dynamic>{},
    );
    if (matchedGuard.isEmpty) {
      throw StateError(
        'Guard ops Phase 1 requires a guardOps projection fixture with at least one guard.',
      );
    }
    final callsign = matchedGuard['callsign']?.toString() ?? 'Unknown Guard';
    final lastCheckIn = matchedGuard['lastCheckIn']?.toString() ?? '--:--';
    final decayLevel = matchedGuard['decayLevel'] ?? 0;
    final notes =
        'Answered guard status for $callsign from live operations. '
        'Last check-in is $lastCheckIn with vigilance decay $decayLevel%.';
    return ScenarioActualOutcome(
      actualRoute: 'live_operations_center',
      actualIntent: 'guard_status_lookup',
      actualEscalationState: 'none',
      actualProjectionChanges: const <dynamic>[],
      actualDrafts: const <dynamic>[],
      actualBlockedActions: const <String>[],
      actualUiState: <String, dynamic>{
        'surface': 'guard_status_answer',
        'liveOpsCommandPreviewVisible': true,
        'guardStatusVisible': true,
        'focusedGuardCallsign': callsign,
        'lastCheckIn': lastCheckIn,
        'vigilanceDecay': decayLevel,
        'legacyWorkspaceVisible': false,
      },
      appendedEvents: const <dynamic>[],
      notes: notes,
    );
  }

  ScenarioActualOutcome _runPatrolReportScenario(
    String prompt,
    ScenarioLoadedFixtures fixtures,
  ) {
    final normalizedPrompt = prompt.toLowerCase();
    final patrolEvents =
        fixtures.existingEvents
            .whereType<Map>()
            .map(_stringKeyedMap)
            .where((event) => event['kind'] == 'patrol_completed')
            .toList(growable: false)
          ..sort((left, right) {
            final leftAt = DateTime.parse(left['occurredAt'].toString());
            final rightAt = DateTime.parse(right['occurredAt'].toString());
            return rightAt.compareTo(leftAt);
          });
    if (patrolEvents.isEmpty) {
      throw StateError(
        'Guard ops Phase 1 requires at least one patrol_completed event fixture.',
      );
    }
    final patrol = patrolEvents.firstWhere(
      (event) => normalizedPrompt.contains(
        event['guardId']?.toString().toLowerCase() ?? '',
      ),
      orElse: () => patrolEvents.first,
    );
    final guardId = patrol['guardId']?.toString() ?? 'Unknown Guard';
    final routeLabel = _humanizeIdentifier(
      patrol['routeId']?.toString() ?? 'unknown_route',
    );
    final siteLabel = _humanizeIdentifier(
      patrol['siteId']?.toString() ?? 'unknown_site',
    );
    final durationSeconds = patrol['durationSeconds'];
    final durationMinutes = durationSeconds is num ? durationSeconds ~/ 60 : 0;
    final notes =
        'Answered patrol report for $guardId from live operations. '
        'Latest scoped patrol ran $routeLabel for $durationMinutes minute(s).';
    return ScenarioActualOutcome(
      actualRoute: 'live_operations_center',
      actualIntent: 'patrol_report_lookup',
      actualEscalationState: 'none',
      actualProjectionChanges: const <dynamic>[],
      actualDrafts: const <dynamic>[],
      actualBlockedActions: const <String>[],
      actualUiState: <String, dynamic>{
        'surface': 'patrol_report_answer',
        'liveOpsCommandPreviewVisible': true,
        'patrolReportVisible': true,
        'guardId': guardId,
        'routeLabel': routeLabel,
        'siteLabel': siteLabel,
        'durationMinutes': durationMinutes,
        'legacyWorkspaceVisible': false,
      },
      appendedEvents: const <dynamic>[],
      notes: notes,
    );
  }

  ScenarioActualOutcome _runMonitoringWatchScenario(
    ScenarioDefinition definition,
    ScenarioLoadedFixtures fixtures,
  ) {
    final navigation = definition.inputs.navigation;
    if (navigation != null && navigation.steps.isNotEmpty) {
      return _runMonitoringSequenceScenario(
        definition.scenarioId,
        navigation.steps,
        fixtures,
      );
    }
    if (navigation?.entryRoute == 'live_operations_review_action') {
      return _runMonitoringReviewHandoffScenario(fixtures);
    }
    final cameraInputs = definition.inputs.cameraInputs;
    if (cameraInputs.isEmpty) {
      throw StateError(
        'Monitoring watch scenarios require at least one camera input in Phase 1.',
      );
    }
    final firstInput = cameraInputs.first;
    if (firstInput is! Map) {
      throw StateError(
        'Monitoring watch Phase 1 camera input must be a JSON object.',
      );
    }
    final keyedInput = _stringKeyedMap(firstInput);
    final signalKind = keyedInput['kind']?.toString() ?? 'unknown_signal';
    final reviewQueue = fixtures.projectionState['monitoringWatch'];
    final keyedReviewQueue = reviewQueue is Map
        ? _stringKeyedMap(reviewQueue)
        : <String, dynamic>{};
    final queueCount = keyedReviewQueue['pendingReviewCount'] ?? 0;
    final notes =
        'Queued $signalKind for monitoring watch review. '
        'Pending review count is $queueCount.';
    return ScenarioActualOutcome(
      actualRoute: 'monitoring_watch',
      actualIntent: 'review_watch_signal',
      actualEscalationState: 'review_pending',
      actualProjectionChanges: const <dynamic>[],
      actualDrafts: const <dynamic>[],
      actualBlockedActions: const <String>['dispatch_without_review'],
      actualUiState: <String, dynamic>{
        'surface': 'monitoring_watch_review',
        'verificationRailVisible': true,
        'watchlistQueueVisible': true,
        'reviewGateActive': true,
        'directDispatchAllowed': false,
        'legacyWorkspaceVisible': false,
      },
      appendedEvents: const <dynamic>[],
      notes: notes,
    );
  }

  ScenarioActualOutcome _runMonitoringSequenceScenario(
    String scenarioId,
    List<ScenarioNavigationStep> steps,
    ScenarioLoadedFixtures fixtures,
  ) {
    if (steps.isEmpty) {
      throw StateError(
        'Monitoring sequence scenarios require at least one navigation step.',
      );
    }
    final projectionChanges = <dynamic>[];
    final blockedActions = <String>[];
    final appendedEvents = <dynamic>[];
    final uiState = <String, dynamic>{'legacyWorkspaceVisible': false};
    final executedNotes = <String>[];
    final branchNotes = <String>[];
    final executedStepIds = <String>[];
    final commandBrainTimeline = <OnyxCommandBrainTimelineEntry>[];
    var finalRoute = 'monitoring_watch';
    var finalIntent = 'review_watch_signal';
    var finalEscalationState = 'review_pending';

    for (final step in steps) {
      var stepIdToExecute = step.stepId;
      BrainDecisionBias? decisionBias;
      final condition = step.condition;
      if (condition != null &&
          !_matchesMonitoringStepCondition(condition, fixtures)) {
        final otherwiseStepId = condition.otherwiseStepId;
        if (otherwiseStepId == null || otherwiseStepId.isEmpty) {
          branchNotes.add(
            'skipped ${step.stepId} '
            '(${_describeMonitoringStepCondition(condition)})',
          );
          continue;
        }
        branchNotes.add(
          'rerouted ${step.stepId} to $otherwiseStepId '
          '(${_describeMonitoringStepCondition(condition)})',
        );
        stepIdToExecute = otherwiseStepId;
        decisionBias = _monitoringConditionDecisionBias(
          condition: condition,
          originalStepId: step.stepId,
          reroutedStepId: otherwiseStepId,
        );
      }
      ScenarioStepSpecialistSignal? activeSpecialistSignal;
      if (stepIdToExecute == step.stepId &&
          step.specialist != null &&
          step.specialist!.status != ScenarioStepSpecialistStatus.ready) {
        activeSpecialistSignal = step.specialist;
        _recordMonitoringSpecialistSignal(
          signal: activeSpecialistSignal!,
          stepId: step.stepId,
          projectionChanges: projectionChanges,
          uiState: uiState,
          executedNotes: executedNotes,
        );
        final specialistFallbackStepId = activeSpecialistSignal.fallbackStepId;
        if (specialistFallbackStepId != null &&
            specialistFallbackStepId.isNotEmpty) {
          branchNotes.add(
            'rerouted ${step.stepId} to $specialistFallbackStepId '
            '(${_describeMonitoringSpecialistSignal(activeSpecialistSignal)})',
          );
          stepIdToExecute = specialistFallbackStepId;
        }
      }
      final activeSpecialistAssessments = step.specialistAssessments;
      final specialistConflictActive =
          activeSpecialistSignal == null &&
          _hasMonitoringSpecialistConflict(activeSpecialistAssessments);
      final specialistConstraint = activeSpecialistSignal == null
          ? _monitoringHardConstraintAssessment(activeSpecialistAssessments)
          : null;
      final clearedConstraintTarget = _clearMonitoringSpecialistConstraint(
        stepId: stepIdToExecute,
        activeConstraint: specialistConstraint,
        projectionChanges: projectionChanges,
        blockedActions: blockedActions,
        uiState: uiState,
        executedNotes: executedNotes,
      );
      final clearedConflict = _clearMonitoringSpecialistConflict(
        stepId: stepIdToExecute,
        conflictActive: specialistConflictActive,
        projectionChanges: projectionChanges,
        uiState: uiState,
        executedNotes: executedNotes,
      );
      final clearedConflictSummary = _normalizedString(
        clearedConflict?['summary'],
      );
      executedStepIds.add(stepIdToExecute);
      switch (stepIdToExecute) {
        case 'open_review_action':
          if (specialistConflictActive) {
            _recordMonitoringSpecialistConflict(
              assessments: activeSpecialistAssessments,
              target: OnyxToolTarget.cctvReview,
              stepId: step.stepId,
              projectionChanges: projectionChanges,
              uiState: uiState,
              executedNotes: executedNotes,
            );
          }
          if (specialistConstraint != null) {
            _recordMonitoringSpecialistConstraint(
              constraint: specialistConstraint,
              assessments: activeSpecialistAssessments,
              stepId: step.stepId,
              projectionChanges: projectionChanges,
              uiState: uiState,
              executedNotes: executedNotes,
            );
          }
          final reviewQueue = fixtures.projectionState['monitoringWatch'];
          if (reviewQueue is! Map) {
            throw StateError(
              'Monitoring sequence step open_review_action requires a monitoringWatch projection fixture.',
            );
          }
          final keyedReviewQueue = _stringKeyedMap(reviewQueue);
          final reviewAction = keyedReviewQueue['reviewAction'];
          if (reviewAction is! Map) {
            throw StateError(
              'Monitoring sequence step open_review_action requires monitoringWatch.reviewAction fixture data.',
            );
          }
          final keyedReviewAction = _stringKeyedMap(reviewAction);
          final incidentReference =
              keyedReviewAction['incidentReference']?.toString() ??
              'INC-UNKNOWN';
          final intelligenceId =
              keyedReviewAction['intelligenceId']?.toString() ??
              'INTEL-UNKNOWN';
          final reviewSurface =
              keyedReviewAction['reviewSurface']?.toString() ?? 'cctv_review';
          projectionChanges.add(<String, dynamic>{
            'step': 'review_opened',
            'reviewSurface': reviewSurface,
          });
          blockedActions.add('dismiss_without_review');
          uiState.addAll(<String, dynamic>{
            'reviewActionVisible': true,
            'cctvRouteVisible': reviewSurface == 'cctv_review',
            'incidentReference': incidentReference,
            'intelligenceId': intelligenceId,
          });
          appendedEvents.add(<String, dynamic>{
            'type': 'review',
            'incidentReference': incidentReference,
          });
          executedNotes.add('opened $reviewSurface for $incidentReference');
          final specialistConstraintActive = specialistConstraint != null;
          final specialistDelayActive =
              activeSpecialistSignal?.status ==
              ScenarioStepSpecialistStatus.delayed;
          if (specialistConstraintActive &&
              !specialistConstraint.allowRouteExecution) {
            blockedActions.add('advance_without_constraint_resolution');
          }
          finalRoute = 'monitoring_watch';
          finalIntent = 'open_cctv_review_handoff';
          finalEscalationState = 'review_opened';
          commandBrainTimeline.add(
            _monitoringTimelineEntryForStep(
              sequence: commandBrainTimeline.length + 1,
              scenarioId: scenarioId,
              stage: stepIdToExecute,
              route: finalRoute,
              mode: specialistConstraintActive
                  ? BrainDecisionMode.specialistConstraint
                  : specialistConflictActive
                  ? BrainDecisionMode.corroboratedSynthesis
                  : BrainDecisionMode.deterministic,
              snapshotTarget: specialistConstraint?.recommendedTarget,
              note: specialistDelayActive
                  ? 'Review evidence staged for $incidentReference while ${_monitoringSpecialistStatusLead(activeSpecialistSignal!)}.'
                  : specialistConstraintActive
                  ? 'Review evidence staged for $incidentReference while hard specialist constraint blocked execution toward ${_deskLabelForTarget(specialistConstraint.recommendedTarget!)}.'
                  : specialistConflictActive
                  ? 'Review evidence staged for $incidentReference while specialist conflict stayed contained in CCTV Review.'
                  : 'Review evidence staged for $incidentReference.',
              advisory: specialistDelayActive
                  ? _monitoringSpecialistDelayAdvisory(
                      activeSpecialistSignal!,
                      deskLabel: 'CCTV Review',
                    )
                  : specialistConstraintActive
                  ? _monitoringSpecialistConstraintAdvisory(
                      specialistConstraint,
                    )
                  : specialistConflictActive
                  ? _monitoringSpecialistConflictAdvisory(
                      activeSpecialistAssessments,
                      deskLabel: 'CCTV Review',
                    )
                  : 'Review evidence is staged before the next desk opens.',
              rationale: specialistDelayActive
                  ? _monitoringSpecialistDelayRationale(
                      activeSpecialistSignal!,
                      deskLabel: 'CCTV Review',
                    )
                  : specialistConstraintActive
                  ? _monitoringSpecialistConstraintRationale(
                      specialistConstraint,
                      deskLabel: 'CCTV Review',
                    )
                  : specialistConflictActive
                  ? _monitoringSpecialistConflictRationale(
                      activeSpecialistAssessments,
                      deskLabel: 'CCTV Review',
                    )
                  : 'Scenario replay opened CCTV Review first to keep the next move attached to verified watch evidence.',
              contextHighlights: specialistDelayActive
                  ? const <String>[
                      'CCTV specialist delay stayed active at the review gate.',
                      'Sequence replay still opened CCTV Review instead of stalling.',
                    ]
                  : specialistConstraintActive
                  ? _monitoringSpecialistConstraintContextHighlights(
                      specialistConstraint,
                      activeSpecialistAssessments,
                    )
                  : specialistConflictActive
                  ? _monitoringSpecialistConflictContextHighlights(
                      activeSpecialistAssessments,
                    )
                  : const <String>[
                      'Sequence replay executed CCTV review before the next desk.',
                    ],
              supportingSpecialists:
                  specialistConstraintActive || specialistConflictActive
                  ? _monitoringConflictSupportingSpecialists(
                      activeSpecialistAssessments,
                    )
                  : const <OnyxSpecialist>[OnyxSpecialist.cctv],
              confidence: specialistDelayActive
                  ? 0.68
                  : specialistConstraintActive
                  ? specialistConstraint.confidence.clamp(0.0, 1.0)
                  : specialistConflictActive
                  ? 0.74
                  : 0.81,
              missingInfo: specialistDelayActive
                  ? const <String>[
                      'Fresh CCTV specialist verification is still pending.',
                    ]
                  : specialistConstraintActive
                  ? _monitoringSpecialistConstraintMissingInfo(
                      specialistConstraint,
                      activeSpecialistAssessments,
                    )
                  : specialistConflictActive
                  ? _monitoringSpecialistConflictMissingInfo(
                      activeSpecialistAssessments,
                    )
                  : const <String>[],
              followUpLabel: specialistDelayActive
                  ? 'RECHECK CCTV SPECIALIST'
                  : specialistConstraintActive
                  ? 'CLEAR HARD CONSTRAINT'
                  : specialistConflictActive
                  ? 'RESOLVE SPECIALIST CONFLICT'
                  : '',
              followUpPrompt: specialistDelayActive
                  ? 'Confirm whether the CCTV specialist has returned and refresh the live verification feed.'
                  : specialistConstraintActive
                  ? 'Resolve the hard specialist constraint and confirm whether Dispatch Board can be reopened safely.'
                  : specialistConflictActive
                  ? 'Reconcile the conflicting specialist recommendations and confirm whether Tactical Track pressure still overrides the review gate.'
                  : '',
              allowRouteExecution: specialistConstraintActive
                  ? specialistConstraint.allowRouteExecution
                  : true,
              decisionBias: decisionBias,
              specialistAssessments: specialistDelayActive
                  ? <SpecialistAssessment>[
                      _buildMonitoringSpecialistAssessment(
                        activeSpecialistSignal!,
                        target: OnyxToolTarget.cctvReview,
                      ),
                    ]
                  : specialistConflictActive
                  ? activeSpecialistAssessments
                  : const <SpecialistAssessment>[],
            ),
          );
        case 'open_dispatch_handoff':
          if (specialistConflictActive) {
            _recordMonitoringSpecialistConflict(
              assessments: activeSpecialistAssessments,
              target: OnyxToolTarget.dispatchBoard,
              stepId: step.stepId,
              projectionChanges: projectionChanges,
              uiState: uiState,
              executedNotes: executedNotes,
            );
          }
          final dispatchBoard = fixtures.projectionState['dispatchBoard'];
          if (dispatchBoard is! Map) {
            throw StateError(
              'Monitoring sequence step open_dispatch_handoff requires a dispatchBoard projection fixture.',
            );
          }
          final keyedDispatchBoard = _stringKeyedMap(dispatchBoard);
          final dispatchHandoff = keyedDispatchBoard['dispatchHandoff'];
          if (dispatchHandoff is! Map) {
            throw StateError(
              'Monitoring sequence step open_dispatch_handoff requires dispatchBoard.dispatchHandoff fixture data.',
            );
          }
          final keyedDispatchHandoff = _stringKeyedMap(dispatchHandoff);
          final dispatchId =
              keyedDispatchHandoff['dispatchId']?.toString() ?? 'DSP-UNKNOWN';
          final priorityLane =
              keyedDispatchHandoff['priorityLane']?.toString() ??
              'priority_response';
          final incidentReference =
              keyedDispatchHandoff['incidentReference']?.toString() ??
              uiState['incidentReference']?.toString() ??
              'INC-UNKNOWN';
          uiState.addAll(<String, dynamic>{
            'dispatchHandoffVisible': true,
            'readyToDispatchVisible': true,
            'dispatchId': dispatchId,
            'priorityLane': priorityLane,
            'incidentReference': incidentReference,
          });
          projectionChanges.add(<String, dynamic>{
            'step': 'dispatch_opened',
            'dispatchSelection': dispatchId,
          });
          blockedActions.add('dismiss_without_dispatch');
          appendedEvents.add(<String, dynamic>{
            'type': 'dispatch',
            'dispatchId': dispatchId,
          });
          executedNotes.add('opened $priorityLane for $dispatchId');
          finalRoute = 'dispatch_board';
          finalIntent = 'open_dispatch_handoff';
          finalEscalationState = 'dispatch_ready';
          final specialistDelayActive =
              activeSpecialistSignal?.status ==
              ScenarioStepSpecialistStatus.delayed;
          commandBrainTimeline.add(
            _monitoringTimelineEntryForStep(
              sequence: commandBrainTimeline.length + 1,
              scenarioId: scenarioId,
              stage: stepIdToExecute,
              route: finalRoute,
              mode: specialistConflictActive
                  ? BrainDecisionMode.corroboratedSynthesis
                  : BrainDecisionMode.deterministic,
              note: specialistDelayActive
                  ? 'Dispatch handoff staged for $dispatchId while ${_monitoringSpecialistStatusLead(activeSpecialistSignal!)}.'
                  : clearedConstraintTarget != null
                  ? 'Dispatch handoff staged for $dispatchId after hard specialist constraint cleared toward ${_deskLabelForTarget(_monitoringTargetFromName(clearedConstraintTarget))}.'
                  : clearedConflictSummary != null
                  ? 'Dispatch handoff staged for $dispatchId after specialist conflict cleared ($clearedConflictSummary).'
                  : specialistConflictActive
                  ? 'Dispatch handoff staged for $dispatchId while specialist conflict stayed contained in Dispatch Board.'
                  : 'Dispatch handoff staged for $dispatchId.',
              advisory: specialistDelayActive
                  ? _monitoringSpecialistDelayAdvisory(
                      activeSpecialistSignal!,
                      deskLabel: 'Dispatch Board',
                    )
                  : clearedConstraintTarget != null
                  ? 'Hard specialist constraint toward ${_deskLabelForTarget(_monitoringTargetFromName(clearedConstraintTarget))} cleared, so ONYX resumed the next move in Dispatch Board.'
                  : clearedConflictSummary != null
                  ? 'Specialist conflict ($clearedConflictSummary) cleared, so ONYX resumed the next move in Dispatch Board.'
                  : specialistConflictActive
                  ? _monitoringSpecialistConflictAdvisory(
                      activeSpecialistAssessments,
                      deskLabel: 'Dispatch Board',
                    )
                  : 'Review evidence is staged and Dispatch Board is ready for controller ownership.',
              rationale: specialistDelayActive
                  ? _monitoringSpecialistDelayRationale(
                      activeSpecialistSignal!,
                      deskLabel: 'Dispatch Board',
                    )
                  : clearedConstraintTarget != null
                  ? 'Scenario replay reopened Dispatch Board once the hard specialist constraint cleared and route execution resumed.'
                  : clearedConflictSummary != null
                  ? 'Scenario replay reopened Dispatch Board once the specialist conflict cleared and the deterministic route resumed.'
                  : specialistConflictActive
                  ? _monitoringSpecialistConflictRationale(
                      activeSpecialistAssessments,
                      deskLabel: 'Dispatch Board',
                    )
                  : 'Scenario replay preserved the live-ops sequence contract and handed the incident into Dispatch Board once availability stayed open.',
              contextHighlights: specialistDelayActive
                  ? const <String>[
                      'Specialist delay stayed active while Dispatch Board remained the next move.',
                    ]
                  : clearedConstraintTarget != null
                  ? <String>[
                      'Hard specialist constraint toward ${_deskLabelForTarget(_monitoringTargetFromName(clearedConstraintTarget))} cleared before Dispatch Board resumed.',
                      'Dispatch handoff stayed available inside the live-ops chain.',
                    ]
                  : clearedConflictSummary != null
                  ? <String>[
                      'Specialist conflict $clearedConflictSummary cleared before Dispatch Board resumed.',
                      'Dispatch handoff stayed available inside the live-ops chain.',
                    ]
                  : specialistConflictActive
                  ? _monitoringSpecialistConflictContextHighlights(
                      activeSpecialistAssessments,
                    )
                  : const <String>[
                      'Dispatch handoff stayed available inside the live-ops chain.',
                    ],
              supportingSpecialists: specialistConflictActive
                  ? _monitoringConflictSupportingSpecialists(
                      activeSpecialistAssessments,
                    )
                  : const <OnyxSpecialist>[
                      OnyxSpecialist.cctv,
                      OnyxSpecialist.dispatch,
                    ],
              confidence: specialistDelayActive
                  ? 0.68
                  : clearedConstraintTarget != null
                  ? 0.81
                  : specialistConflictActive
                  ? 0.74
                  : clearedConflictSummary != null
                  ? 0.79
                  : 0.81,
              missingInfo: specialistDelayActive
                  ? <String>[
                      _monitoringSpecialistMissingInfo(activeSpecialistSignal!),
                    ]
                  : specialistConflictActive
                  ? _monitoringSpecialistConflictMissingInfo(
                      activeSpecialistAssessments,
                    )
                  : const <String>[],
              followUpLabel: specialistDelayActive
                  ? _monitoringSpecialistFollowUpLabel(activeSpecialistSignal!)
                  : specialistConflictActive
                  ? 'RESOLVE SPECIALIST CONFLICT'
                  : '',
              followUpPrompt: specialistDelayActive
                  ? _monitoringSpecialistFollowUpPrompt(activeSpecialistSignal!)
                  : specialistConflictActive
                  ? 'Reconcile the conflicting specialist recommendations and confirm whether the Dispatch Board remains the correct next desk.'
                  : '',
              decisionBias: decisionBias,
              specialistAssessments: specialistDelayActive
                  ? <SpecialistAssessment>[
                      _buildMonitoringSpecialistAssessment(
                        activeSpecialistSignal!,
                        target: OnyxToolTarget.dispatchBoard,
                      ),
                    ]
                  : specialistConflictActive
                  ? activeSpecialistAssessments
                  : const <SpecialistAssessment>[],
            ),
          );
        case 'open_track_handoff':
          if (specialistConflictActive) {
            _recordMonitoringSpecialistConflict(
              assessments: activeSpecialistAssessments,
              target: OnyxToolTarget.tacticalTrack,
              stepId: step.stepId,
              projectionChanges: projectionChanges,
              uiState: uiState,
              executedNotes: executedNotes,
            );
          }
          final trackOverview = fixtures.projectionState['trackOverview'];
          if (trackOverview is! Map) {
            throw StateError(
              'Monitoring sequence step open_track_handoff requires a trackOverview projection fixture.',
            );
          }
          final keyedTrackOverview = _stringKeyedMap(trackOverview);
          final trackHandoff = keyedTrackOverview['trackHandoff'];
          if (trackHandoff is! Map) {
            throw StateError(
              'Monitoring sequence step open_track_handoff requires trackOverview.trackHandoff fixture data.',
            );
          }
          final keyedTrackHandoff = _stringKeyedMap(trackHandoff);
          final siteId =
              keyedTrackHandoff['siteId']?.toString() ?? 'site_unknown';
          final trackLabel =
              keyedTrackHandoff['trackLabel']?.toString() ?? 'Priority Track';
          final incidentReference =
              keyedTrackHandoff['incidentReference']?.toString() ??
              uiState['incidentReference']?.toString() ??
              'INC-UNKNOWN';
          uiState.addAll(<String, dynamic>{
            'trackHandoffVisible': true,
            'readyToTrackVisible': true,
            'detailedWorkspaceVisible': true,
            'siteId': siteId,
            'trackLabel': trackLabel,
            'incidentReference': incidentReference,
          });
          projectionChanges.add(<String, dynamic>{
            'step': 'track_opened',
            'focusSiteId': siteId,
          });
          blockedActions.add('dismiss_without_track');
          appendedEvents.add(<String, dynamic>{
            'type': 'track',
            'siteId': siteId,
          });
          executedNotes.add('opened $trackLabel for $siteId');
          finalRoute = 'track_detailed_workspace';
          finalIntent = 'open_track_handoff';
          finalEscalationState = 'track_opened';
          final reroutedFromDispatch = branchNotes.isNotEmpty;
          final specialistSignalLost =
              activeSpecialistSignal?.status ==
              ScenarioStepSpecialistStatus.signalLost;
          final specialistDelayActive =
              activeSpecialistSignal?.status ==
              ScenarioStepSpecialistStatus.delayed;
          commandBrainTimeline.add(
            _monitoringTimelineEntryForStep(
              sequence: commandBrainTimeline.length + 1,
              scenarioId: scenarioId,
              stage: stepIdToExecute,
              route: finalRoute,
              mode: specialistConflictActive
                  ? BrainDecisionMode.corroboratedSynthesis
                  : BrainDecisionMode.deterministic,
              note: specialistSignalLost
                  ? 'Track fallback staged after ${_monitoringSpecialistStatusLead(activeSpecialistSignal!)}.'
                  : reroutedFromDispatch
                  ? 'Track fallback staged after dispatch availability failed.'
                  : clearedConstraintTarget != null
                  ? 'Track handoff staged for $siteId after hard specialist constraint cleared toward ${_deskLabelForTarget(_monitoringTargetFromName(clearedConstraintTarget))}.'
                  : clearedConflictSummary != null
                  ? 'Track handoff staged for $siteId after specialist conflict cleared ($clearedConflictSummary).'
                  : specialistConflictActive
                  ? 'Track handoff staged for $siteId while specialist conflict stayed contained in Tactical Track.'
                  : 'Track handoff staged for $siteId.',
              advisory: specialistSignalLost
                  ? _monitoringSpecialistLossFallbackAdvisory(
                      activeSpecialistSignal!,
                    )
                  : reroutedFromDispatch && specialistConflictActive
                  ? 'Dispatch was unavailable, and specialists still disagreed on the fallback desk (${_monitoringConflictSummary(activeSpecialistAssessments)}), so ONYX kept the live-ops sequence moving in Tactical Track while the conflict stayed visible.'
                  : reroutedFromDispatch
                  ? 'Dispatch was unavailable, so ONYX kept the live-ops sequence moving in Tactical Track.'
                  : clearedConstraintTarget != null
                  ? 'Hard specialist constraint toward ${_deskLabelForTarget(_monitoringTargetFromName(clearedConstraintTarget))} cleared, so ONYX resumed the next move in Tactical Track.'
                  : clearedConflictSummary != null
                  ? 'Specialist conflict ($clearedConflictSummary) cleared, so ONYX resumed the next move in Tactical Track.'
                  : specialistConflictActive
                  ? _monitoringSpecialistConflictAdvisory(
                      activeSpecialistAssessments,
                      deskLabel: 'Tactical Track',
                    )
                  : specialistDelayActive
                  ? _monitoringSpecialistDelayAdvisory(
                      activeSpecialistSignal!,
                      deskLabel: 'Tactical Track',
                    )
                  : 'Review evidence is staged and Tactical Track is ready for field continuity.',
              rationale: specialistSignalLost
                  ? _monitoringSpecialistLossFallbackRationale(
                      activeSpecialistSignal!,
                    )
                  : reroutedFromDispatch && specialistConflictActive
                  ? 'Scenario replay preserved the live-ops sequence contract, applied the Track fallback when dispatch availability failed, and kept the specialist conflict attached to the fallback desk.'
                  : reroutedFromDispatch
                  ? 'Scenario replay preserved the live-ops sequence contract and applied the Track fallback when dispatch availability failed.'
                  : clearedConstraintTarget != null
                  ? 'Scenario replay reopened route execution and staged Tactical Track once the hard specialist constraint cleared.'
                  : clearedConflictSummary != null
                  ? 'Scenario replay reopened the deterministic handoff in Tactical Track once the specialist conflict cleared.'
                  : specialistConflictActive
                  ? _monitoringSpecialistConflictRationale(
                      activeSpecialistAssessments,
                      deskLabel: 'Tactical Track',
                    )
                  : specialistDelayActive
                  ? _monitoringSpecialistDelayRationale(
                      activeSpecialistSignal!,
                      deskLabel: 'Tactical Track',
                    )
                  : 'Scenario replay preserved the live-ops sequence contract and staged Tactical Track from the validated path.',
              contextHighlights: specialistSignalLost
                  ? const <String>[
                      'Track continuity absorbed the next move after CCTV signal loss.',
                      'Sequence replay still produced a live-ops target instead of hanging.',
                    ]
                  : reroutedFromDispatch && specialistConflictActive
                  ? <String>[
                      ..._monitoringSpecialistConflictContextHighlights(
                        activeSpecialistAssessments,
                      ),
                      'Track fallback still held the next move after dispatch availability failed.',
                    ]
                  : clearedConstraintTarget != null
                  ? <String>[
                      'Hard specialist constraint toward ${_deskLabelForTarget(_monitoringTargetFromName(clearedConstraintTarget))} cleared before Tactical Track resumed.',
                      'Track continuity reopened once route execution returned.',
                    ]
                  : clearedConflictSummary != null
                  ? <String>[
                      'Specialist conflict $clearedConflictSummary cleared before Tactical Track resumed.',
                      'Track continuity reopened once the route stabilized.',
                    ]
                  : specialistConflictActive
                  ? _monitoringSpecialistConflictContextHighlights(
                      activeSpecialistAssessments,
                    )
                  : specialistDelayActive
                  ? const <String>[
                      'Track continuity stayed ready while specialist delay remained active.',
                    ]
                  : const <String>[
                      'Track continuity held the next move after review.',
                    ],
              supportingSpecialists:
                  reroutedFromDispatch || specialistSignalLost
                      ? specialistConflictActive
                            ? _monitoringConflictSupportingSpecialists(
                                activeSpecialistAssessments,
                              )
                            : const <OnyxSpecialist>[
                                OnyxSpecialist.cctv,
                                OnyxSpecialist.track,
                              ]
                  : specialistConflictActive
                  ? _monitoringConflictSupportingSpecialists(
                      activeSpecialistAssessments,
                    )
                  : const <OnyxSpecialist>[OnyxSpecialist.track],
              confidence: specialistSignalLost
                  ? 0.63
                  : clearedConstraintTarget != null
                  ? 0.81
                  : reroutedFromDispatch && specialistConflictActive
                  ? 0.74
                  : specialistConflictActive
                  ? 0.74
                  : clearedConflictSummary != null
                  ? 0.79
                  : specialistDelayActive
                  ? 0.68
                  : 0.81,
              missingInfo: specialistSignalLost || specialistDelayActive
                  ? <String>[
                      _monitoringSpecialistMissingInfo(activeSpecialistSignal!),
                    ]
                  : reroutedFromDispatch && specialistConflictActive
                  ? _monitoringSpecialistConflictMissingInfo(
                      activeSpecialistAssessments,
                    )
                  : specialistConflictActive
                  ? _monitoringSpecialistConflictMissingInfo(
                      activeSpecialistAssessments,
                    )
                  : const <String>[],
              followUpLabel: specialistSignalLost || specialistDelayActive
                  ? _monitoringSpecialistFollowUpLabel(activeSpecialistSignal!)
                  : reroutedFromDispatch && specialistConflictActive
                  ? 'RESOLVE SPECIALIST CONFLICT'
                  : specialistConflictActive
                  ? 'RESOLVE SPECIALIST CONFLICT'
                  : '',
              followUpPrompt: specialistSignalLost || specialistDelayActive
                  ? _monitoringSpecialistFollowUpPrompt(activeSpecialistSignal!)
                  : reroutedFromDispatch && specialistConflictActive
                  ? 'Reconcile the conflicting specialist recommendations and confirm whether Tactical Track remains the correct next desk.'
                  : specialistConflictActive
                  ? 'Reconcile the conflicting specialist recommendations and confirm whether Tactical Track remains the correct next desk.'
                  : '',
              decisionBias: decisionBias,
              specialistAssessments:
                  specialistSignalLost || specialistDelayActive
                  ? <SpecialistAssessment>[
                      _buildMonitoringSpecialistAssessment(
                        activeSpecialistSignal!,
                        target: OnyxToolTarget.tacticalTrack,
                      ),
                    ]
                  : specialistConflictActive
                  ? activeSpecialistAssessments
                  : const <SpecialistAssessment>[],
            ),
          );
        default:
          throw UnsupportedError(
            'Monitoring sequence step "${step.stepId}" is not supported in Phase 1.',
          );
      }
    }

    if (executedStepIds.isEmpty) {
      throw StateError(
        'Monitoring sequence scenarios require at least one navigation step '
        'to execute after condition evaluation.',
      );
    }

    final isMultiStep = executedStepIds.length > 1;
    if (isMultiStep) {
      uiState['surface'] = 'live_ops_priority_sequence';
      uiState['finalRoute'] = finalRoute;
      finalIntent = 'open_live_ops_priority_sequence';
    } else if (executedStepIds.single == 'open_review_action') {
      uiState['surface'] = 'monitoring_watch_review';
    } else if (executedStepIds.single == 'open_track_handoff') {
      uiState['surface'] = 'live_ops_track_handoff';
      uiState['trackWorkspaceVisible'] = true;
      uiState['tacticalTrackVisible'] = true;
      uiState['handoffVisible'] = true;
    }

    final notesBuffer = StringBuffer()
      ..write('Executed monitoring sequence: ')
      ..write(executedNotes.join(' -> '))
      ..write('.');
    if (branchNotes.isNotEmpty) {
      notesBuffer
        ..write(' Branches: ')
        ..write(branchNotes.join(' -> '))
        ..write('.');
    }
    final commandBrainSnapshot = commandBrainTimeline.isEmpty
        ? null
        : commandBrainTimeline.last.snapshot;

    return ScenarioActualOutcome(
      actualRoute: finalRoute,
      actualIntent: finalIntent,
      actualEscalationState: finalEscalationState,
      actualProjectionChanges: projectionChanges,
      actualDrafts: const <dynamic>[],
      actualBlockedActions: List<String>.unmodifiable(blockedActions),
      actualUiState: uiState,
      appendedEvents: appendedEvents,
      notes: notesBuffer.toString(),
      commandBrainSnapshot: commandBrainSnapshot,
      commandBrainTimeline: commandBrainTimeline,
    );
  }

  OnyxCommandBrainTimelineEntry _monitoringTimelineEntryForStep({
    required int sequence,
    required String scenarioId,
    required String stage,
    required String route,
    required String note,
    required String advisory,
    required String rationale,
    required List<String> contextHighlights,
    BrainDecisionMode mode = BrainDecisionMode.deterministic,
    OnyxToolTarget? snapshotTarget,
    List<OnyxSpecialist> supportingSpecialists = const <OnyxSpecialist>[],
    double confidence = 0.81,
    List<String> missingInfo = const <String>[],
    String followUpLabel = '',
    String followUpPrompt = '',
    bool allowRouteExecution = true,
    BrainDecisionBias? decisionBias,
    List<BrainDecisionBias> replayBiasStack = const <BrainDecisionBias>[],
    List<SpecialistAssessment> specialistAssessments =
        const <SpecialistAssessment>[],
  }) {
    final target = snapshotTarget ?? _targetForMonitoringSequenceRoute(route);
    final supplementalReplayBiasStack = replayBiasStack.isNotEmpty
        ? replayBiasStack
        : _monitoringSupplementalReplayBiasStack(
            decisionBias: decisionBias,
            currentTarget: target,
            specialistAssessments: specialistAssessments,
          );
    final recommendation = OnyxRecommendation(
      workItemId: scenarioId,
      target: target,
      nextMoveLabel: _nextMoveLabelForTarget(target),
      headline: '${_deskLabelForTarget(target)} is the next move',
      detail: '',
      summary: 'One next move is staged in ${_deskLabelForTarget(target)}.',
      evidenceHeadline: '',
      evidenceDetail: '',
      advisory: advisory,
      confidence: confidence,
      missingInfo: missingInfo,
      contextHighlights: contextHighlights,
      followUpLabel: followUpLabel,
      followUpPrompt: followUpPrompt,
      allowRouteExecution: allowRouteExecution,
    );
    final snapshot = OnyxCommandBrainSnapshot.fromRecommendation(
      recommendation,
      mode: mode,
      primaryPressure: 'active signal watch',
      rationale: rationale,
      supportingSpecialists: supportingSpecialists,
      decisionBias: decisionBias,
      replayBiasStack: supplementalReplayBiasStack,
      specialistAssessments: specialistAssessments,
    );
    return OnyxCommandBrainTimelineEntry(
      sequence: sequence,
      stage: stage,
      note: _monitoringTimelineNote(note: note, snapshot: snapshot),
      snapshot: snapshot,
    );
  }

  String _monitoringTimelineNote({
    required String note,
    required OnyxCommandBrainSnapshot snapshot,
  }) {
    final normalizedNote = note.trim();
    final replayPressureSummary = snapshot.replayPressureSummary?.trim() ?? '';
    if (replayPressureSummary.isEmpty) {
      return normalizedNote;
    }
    if (normalizedNote.isEmpty) {
      return replayPressureSummary;
    }
    if (normalizedNote.contains(replayPressureSummary)) {
      return normalizedNote;
    }
    return '$normalizedNote $replayPressureSummary';
  }

  List<BrainDecisionBias> _monitoringSupplementalReplayBiasStack({
    required BrainDecisionBias? decisionBias,
    required OnyxToolTarget currentTarget,
    required List<SpecialistAssessment> specialistAssessments,
  }) {
    if (decisionBias == null ||
        !_hasMonitoringSpecialistConflict(specialistAssessments)) {
      return const <BrainDecisionBias>[];
    }
    final conflictTarget = _monitoringAlternateConflictTarget(
      specialistAssessments,
      currentTarget: currentTarget,
    );
    if (conflictTarget == null) {
      return const <BrainDecisionBias>[];
    }
    return <BrainDecisionBias>[
      BrainDecisionBias(
        source: BrainDecisionBiasSource.replayPolicy,
        scope: BrainDecisionBiasScope.specialistConflict,
        preferredTarget: conflictTarget,
        summary:
            'Specialist conflict (${_monitoringConflictSummary(specialistAssessments)}) still leaned back to ${_deskLabelForTarget(conflictTarget)} while ${_deskLabelForTarget(currentTarget)} stayed in front.',
        policySourceLabel: 'scenario replay specialist pressure',
      ),
    ];
  }

  OnyxToolTarget? _monitoringAlternateConflictTarget(
    List<SpecialistAssessment> assessments, {
    required OnyxToolTarget currentTarget,
  }) {
    for (final assessment in assessments) {
      final recommendedTarget = assessment.recommendedTarget;
      if (recommendedTarget == null || recommendedTarget == currentTarget) {
        continue;
      }
      return recommendedTarget;
    }
    return null;
  }

  BrainDecisionBias? _monitoringConditionDecisionBias({
    required ScenarioStepCondition condition,
    required String originalStepId,
    required String reroutedStepId,
  }) {
    final preferredTarget = _monitoringTargetForStepId(reroutedStepId);
    if (preferredTarget == null) {
      return null;
    }
    final summary = switch ((condition.field.trim(), reroutedStepId)) {
      ('dispatchBoard.dispatchAvailable', 'open_track_handoff') =>
        'Dispatch was unavailable, so ONYX kept the live-ops sequence moving in Tactical Track.',
      _ =>
        'Replay policy rerouted $originalStepId to $reroutedStepId because ${_describeMonitoringStepCondition(condition)}.',
    };
    return BrainDecisionBias(
      source: BrainDecisionBiasSource.replayPolicy,
      scope: BrainDecisionBiasScope.sequenceFallback,
      preferredTarget: preferredTarget,
      summary: summary,
      policySourceLabel: 'scenario sequence policy',
    );
  }

  OnyxToolTarget? _monitoringTargetForStepId(String stepId) {
    return switch (stepId) {
      'open_review_action' => OnyxToolTarget.cctvReview,
      'open_dispatch_handoff' => OnyxToolTarget.dispatchBoard,
      'open_track_handoff' => OnyxToolTarget.tacticalTrack,
      _ => null,
    };
  }

  void _recordMonitoringSpecialistSignal({
    required ScenarioStepSpecialistSignal signal,
    required String stepId,
    required List<dynamic> projectionChanges,
    required Map<String, dynamic> uiState,
    required List<String> executedNotes,
  }) {
    projectionChanges.add(<String, dynamic>{
      'step': 'specialist_status',
      'sourceStepId': stepId,
      'specialist': signal.specialist.name,
      'status': _monitoringSpecialistStatusName(signal.status),
      if (signal.delayMs > 0) 'delayMs': signal.delayMs,
      if (signal.detail.trim().isNotEmpty) 'detail': signal.detail,
    });
    final specialistStatuses =
        uiState.putIfAbsent('specialistStatuses', () => <String, dynamic>{})
            as Map<String, dynamic>;
    specialistStatuses[signal.specialist.name] = <String, dynamic>{
      'status': _monitoringSpecialistStatusName(signal.status),
      if (signal.delayMs > 0) 'delayMs': signal.delayMs,
      if (signal.detail.trim().isNotEmpty) 'detail': signal.detail,
    };
    uiState['specialistDegradationVisible'] = true;
    executedNotes.add(
      '${signal.specialist.name} ${_monitoringSpecialistStatusDetail(signal)} '
      'at $stepId',
    );
  }

  bool _hasMonitoringSpecialistConflict(
    List<SpecialistAssessment> assessments,
  ) {
    if (assessments.length < 2) {
      return false;
    }
    final distinctTargets = assessments
        .map((assessment) => assessment.recommendedTarget?.name)
        .whereType<String>()
        .toSet();
    if (distinctTargets.length > 1) {
      return true;
    }
    return false;
  }

  SpecialistAssessment? _monitoringHardConstraintAssessment(
    List<SpecialistAssessment> assessments,
  ) {
    for (final assessment in assessments) {
      if (assessment.isHardConstraint && assessment.recommendedTarget != null) {
        return assessment;
      }
    }
    return null;
  }

  void _recordMonitoringSpecialistConflict({
    required List<SpecialistAssessment> assessments,
    required OnyxToolTarget target,
    required String stepId,
    required List<dynamic> projectionChanges,
    required Map<String, dynamic> uiState,
    required List<String> executedNotes,
  }) {
    final specialists = _monitoringConflictSpecialistNames(assessments);
    final recommendedTargets = _monitoringConflictTargetNames(assessments);
    final conflictSummary = _monitoringConflictSummary(assessments);
    projectionChanges.add(<String, dynamic>{
      'step': 'specialist_conflict',
      'sourceStepId': stepId,
      'target': target.name,
      'specialists': specialists,
      'recommendedTargets': recommendedTargets,
      'summary': conflictSummary,
    });
    uiState['specialistConflictVisible'] = true;
    uiState['specialistConflictCount'] = assessments.length;
    uiState['specialistConflictSpecialists'] = specialists;
    uiState['specialistConflictTargets'] = recommendedTargets;
    uiState['specialistConflictSummary'] = conflictSummary;
    executedNotes.add('specialist conflict at $stepId: $conflictSummary');
  }

  void _recordMonitoringSpecialistConstraint({
    required SpecialistAssessment constraint,
    required List<SpecialistAssessment> assessments,
    required String stepId,
    required List<dynamic> projectionChanges,
    required Map<String, dynamic> uiState,
    required List<String> executedNotes,
  }) {
    final constrainedTarget = constraint.recommendedTarget!;
    final summary = _monitoringConstraintSummary(
      assessments,
      constrainedTarget: constrainedTarget,
    );
    projectionChanges.add(<String, dynamic>{
      'step': 'specialist_constraint',
      'sourceStepId': stepId,
      'specialist': constraint.specialist.name,
      'constrainedTarget': constrainedTarget.name,
      'allowRouteExecution': constraint.allowRouteExecution,
      'summary': summary,
    });
    uiState['specialistConstraintVisible'] = true;
    uiState['routeExecutionBlockedVisible'] = !constraint.allowRouteExecution;
    uiState['allowRouteExecution'] = constraint.allowRouteExecution;
    uiState['constrainedTarget'] = constrainedTarget.name;
    uiState['constrainingSpecialist'] = constraint.specialist.name;
    uiState['specialistConstraintSummary'] = summary;
    executedNotes.add('hard specialist constraint at $stepId: $summary');
  }

  Map<String, dynamic>? _clearMonitoringSpecialistConflict({
    required String stepId,
    required bool conflictActive,
    required List<dynamic> projectionChanges,
    required Map<String, dynamic> uiState,
    required List<String> executedNotes,
  }) {
    if (conflictActive || uiState['specialistConflictVisible'] != true) {
      return null;
    }
    final previousSummary = uiState['specialistConflictSummary']
        ?.toString()
        .trim();
    final previousSpecialists =
        (uiState['specialistConflictSpecialists'] is List
                ? (uiState['specialistConflictSpecialists'] as List)
                : const <dynamic>[])
            .map((entry) => entry?.toString().trim())
            .whereType<String>()
            .where((entry) => entry.isNotEmpty)
            .toList(growable: false);
    final previousTargets =
        (uiState['specialistConflictTargets'] is List
                ? (uiState['specialistConflictTargets'] as List)
                : const <dynamic>[])
            .map((entry) => entry?.toString().trim())
            .whereType<String>()
            .where((entry) => entry.isNotEmpty)
            .toList(growable: false);
    projectionChanges.add(<String, dynamic>{
      'step': 'specialist_conflict_cleared',
      'resolvedByStepId': stepId,
      if (previousSpecialists.isNotEmpty) 'specialists': previousSpecialists,
      if (previousTargets.isNotEmpty) 'previousTargets': previousTargets,
      if (previousSummary != null && previousSummary.isNotEmpty)
        'summary': previousSummary,
    });
    uiState['specialistConflictVisible'] = false;
    uiState.remove('specialistConflictCount');
    uiState.remove('specialistConflictSpecialists');
    uiState.remove('specialistConflictTargets');
    uiState.remove('specialistConflictSummary');
    executedNotes.add(
      previousSummary == null || previousSummary.isEmpty
          ? 'specialist conflict cleared before $stepId'
          : 'specialist conflict cleared before $stepId: $previousSummary',
    );
    return <String, dynamic>{
      if (previousSummary != null && previousSummary.isNotEmpty)
        'summary': previousSummary,
      if (previousSpecialists.isNotEmpty) 'specialists': previousSpecialists,
      if (previousTargets.isNotEmpty) 'previousTargets': previousTargets,
    };
  }

  String? _clearMonitoringSpecialistConstraint({
    required String stepId,
    required SpecialistAssessment? activeConstraint,
    required List<dynamic> projectionChanges,
    required List<String> blockedActions,
    required Map<String, dynamic> uiState,
    required List<String> executedNotes,
  }) {
    if (activeConstraint != null ||
        uiState['specialistConstraintVisible'] != true) {
      return null;
    }
    final previousTarget = uiState['constrainedTarget']?.toString().trim();
    final previousSummary = uiState['specialistConstraintSummary']
        ?.toString()
        .trim();
    projectionChanges.add(<String, dynamic>{
      'step': 'specialist_constraint_cleared',
      'resolvedByStepId': stepId,
      if (previousTarget != null && previousTarget.isNotEmpty)
        'previousTarget': previousTarget,
      if (previousSummary != null && previousSummary.isNotEmpty)
        'summary': previousSummary,
    });
    uiState['specialistConstraintVisible'] = false;
    uiState['routeExecutionBlockedVisible'] = false;
    uiState['allowRouteExecution'] = true;
    uiState.remove('constrainedTarget');
    uiState.remove('constrainingSpecialist');
    uiState.remove('specialistConstraintSummary');
    blockedActions.remove('advance_without_constraint_resolution');
    executedNotes.add(
      previousTarget == null || previousTarget.isEmpty
          ? 'hard specialist constraint cleared before $stepId'
          : 'hard specialist constraint cleared before $stepId toward $previousTarget',
    );
    return previousTarget == null || previousTarget.isEmpty
        ? null
        : previousTarget;
  }

  List<OnyxSpecialist> _monitoringConflictSupportingSpecialists(
    List<SpecialistAssessment> assessments,
  ) {
    final seen = <OnyxSpecialist>{};
    return assessments
        .map((assessment) => assessment.specialist)
        .where((specialist) => seen.add(specialist))
        .toList(growable: false);
  }

  List<String> _monitoringSpecialistConflictContextHighlights(
    List<SpecialistAssessment> assessments,
  ) {
    return assessments
        .map((assessment) {
          final targetLabel = assessment.recommendedTarget == null
              ? 'the current desk'
              : _deskLabelForTarget(assessment.recommendedTarget!);
          return '${assessment.specialist.label} argued for $targetLabel.';
        })
        .toList(growable: false);
  }

  List<String> _monitoringSpecialistConflictMissingInfo(
    List<SpecialistAssessment> assessments,
  ) {
    final missingInfo = <String>[
      'Conflicting specialist recommendations still need reconciliation before the next move is locked.',
    ];
    for (final assessment in assessments) {
      for (final entry in assessment.missingInfo) {
        if (entry.trim().isEmpty || missingInfo.contains(entry)) {
          continue;
        }
        missingInfo.add(entry);
      }
    }
    return List<String>.unmodifiable(missingInfo);
  }

  List<String> _monitoringSpecialistConstraintMissingInfo(
    SpecialistAssessment constraint,
    List<SpecialistAssessment> assessments,
  ) {
    final missingInfo = <String>[
      'Hard specialist constraint still blocks route execution until the contradiction is resolved.',
    ];
    for (final assessment in assessments) {
      for (final entry in assessment.missingInfo) {
        if (entry.trim().isEmpty || missingInfo.contains(entry)) {
          continue;
        }
        missingInfo.add(entry);
      }
    }
    final operatorLine =
        '${constraint.specialist.label} constraint still needs operator clearance.';
    if (!missingInfo.contains(operatorLine)) {
      missingInfo.add(operatorLine);
    }
    return List<String>.unmodifiable(missingInfo);
  }

  String _monitoringSpecialistConflictAdvisory(
    List<SpecialistAssessment> assessments, {
    required String deskLabel,
  }) {
    final conflictSummary = _monitoringConflictSummary(assessments);
    return 'Specialists disagreed on the next desk ($conflictSummary), so '
        'ONYX kept the move in $deskLabel until the conflict resolves.';
  }

  String _monitoringSpecialistConflictRationale(
    List<SpecialistAssessment> assessments, {
    required String deskLabel,
  }) {
    return 'Scenario replay held the deterministic gate in $deskLabel and '
        'synthesized the conflicting specialist pressure instead of pivoting '
        'early into another desk.';
  }

  String _monitoringSpecialistConstraintAdvisory(
    SpecialistAssessment constraint,
  ) {
    final constrainedTarget = constraint.recommendedTarget!;
    return '${constraint.specialist.label} raised a hard constraint toward '
        '${_deskLabelForTarget(constrainedTarget)}, so ONYX blocked route '
        'execution until the contradiction is cleared.';
  }

  String _monitoringSpecialistConstraintRationale(
    SpecialistAssessment constraint, {
    required String deskLabel,
  }) {
    return 'Scenario replay held the deterministic gate in $deskLabel but '
        'staged a constrained move in '
        '${_deskLabelForTarget(constraint.recommendedTarget!)} because '
        '${constraint.specialist.label.toLowerCase()} blocked route execution.';
  }

  List<String> _monitoringSpecialistConstraintContextHighlights(
    SpecialistAssessment constraint,
    List<SpecialistAssessment> assessments,
  ) {
    final highlights = <String>[
      '${constraint.specialist.label} blocked route execution toward '
          '${_deskLabelForTarget(constraint.recommendedTarget!)}.',
    ];
    for (final assessment in assessments) {
      if (assessment == constraint) {
        continue;
      }
      final targetLabel = assessment.recommendedTarget == null
          ? 'the current desk'
          : _deskLabelForTarget(assessment.recommendedTarget!);
      highlights.add(
        '${assessment.specialist.label} still argued for $targetLabel.',
      );
    }
    return List<String>.unmodifiable(highlights);
  }

  List<String> _monitoringConflictSpecialistNames(
    List<SpecialistAssessment> assessments,
  ) {
    final seen = <String>{};
    return assessments
        .map((assessment) => assessment.specialist.name)
        .where((name) => seen.add(name))
        .toList(growable: false);
  }

  List<String> _monitoringConflictTargetNames(
    List<SpecialistAssessment> assessments,
  ) {
    final seen = <String>{};
    return assessments
        .map((assessment) => assessment.recommendedTarget?.name)
        .whereType<String>()
        .where((target) => seen.add(target))
        .toList(growable: false);
  }

  String _monitoringConflictSummary(List<SpecialistAssessment> assessments) {
    return assessments
        .map((assessment) {
          final targetName =
              assessment.recommendedTarget?.name ?? 'currentDesk';
          return '${assessment.specialist.name}->$targetName';
        })
        .join(' | ');
  }

  String _monitoringConstraintSummary(
    List<SpecialistAssessment> assessments, {
    required OnyxToolTarget constrainedTarget,
  }) {
    return '${_monitoringConflictSummary(assessments)} => '
        'constraint:${constrainedTarget.name}';
  }

  String _monitoringSpecialistStatusName(ScenarioStepSpecialistStatus status) {
    return switch (status) {
      ScenarioStepSpecialistStatus.ready => 'ready',
      ScenarioStepSpecialistStatus.delayed => 'delayed',
      ScenarioStepSpecialistStatus.signalLost => 'signal_lost',
    };
  }

  String _monitoringSpecialistStatusLead(ScenarioStepSpecialistSignal signal) {
    return '${signal.specialist.label.toLowerCase()} '
        '${_monitoringSpecialistStatusDetail(signal)}';
  }

  String _monitoringSpecialistStatusDetail(
    ScenarioStepSpecialistSignal signal,
  ) {
    return switch (signal.status) {
      ScenarioStepSpecialistStatus.ready => 'was ready',
      ScenarioStepSpecialistStatus.delayed =>
        signal.delayMs > 0
            ? 'was delayed by ${signal.delayMs} ms'
            : 'was delayed',
      ScenarioStepSpecialistStatus.signalLost => 'lost signal',
    };
  }

  String? _normalizedString(Object? value) {
    final normalized = value?.toString().trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  String _describeMonitoringSpecialistSignal(
    ScenarioStepSpecialistSignal? signal,
  ) {
    if (signal == null) {
      return 'specialist status unavailable';
    }
    final detailSuffix = signal.detail.trim().isNotEmpty
        ? ', detail=${signal.detail}'
        : '';
    return 'specialist=${signal.specialist.name}, '
        'status=${_monitoringSpecialistStatusName(signal.status)}'
        '${signal.delayMs > 0 ? ', delayMs=${signal.delayMs}' : ''}'
        '$detailSuffix';
  }

  String _monitoringSpecialistDelayAdvisory(
    ScenarioStepSpecialistSignal signal, {
    required String deskLabel,
  }) {
    final delayText = signal.delayMs > 0 ? ' by ${signal.delayMs} ms' : '';
    return '${signal.specialist.label} is delayed$delayText, so ONYX kept the '
        'next move in $deskLabel while fresh verification is pending.';
  }

  String _monitoringSpecialistDelayRationale(
    ScenarioStepSpecialistSignal signal, {
    required String deskLabel,
  }) {
    return 'Scenario replay preserved the current gate and staged $deskLabel '
        'instead of hanging while ${signal.specialist.label.toLowerCase()} '
        'delay remained active.';
  }

  String _monitoringSpecialistLossFallbackAdvisory(
    ScenarioStepSpecialistSignal signal,
  ) {
    return '${signal.specialist.label} lost signal, so ONYX shifted the next '
        'move into Tactical Track while verification recovered.';
  }

  String _monitoringSpecialistLossFallbackRationale(
    ScenarioStepSpecialistSignal signal,
  ) {
    return 'Scenario replay preserved a live command target and rerouted into '
        'Tactical Track once ${signal.specialist.label.toLowerCase()} signal '
        'loss removed the original desk from immediate use.';
  }

  String _monitoringSpecialistMissingInfo(ScenarioStepSpecialistSignal signal) {
    return switch (signal.status) {
      ScenarioStepSpecialistStatus.ready => '',
      ScenarioStepSpecialistStatus.delayed =>
        'Fresh ${signal.specialist.label} verification is still pending.',
      ScenarioStepSpecialistStatus.signalLost =>
        '${signal.specialist.label} signal recovery is still pending.',
    };
  }

  String _monitoringSpecialistFollowUpLabel(
    ScenarioStepSpecialistSignal signal,
  ) {
    return switch (signal.specialist) {
      OnyxSpecialist.cctv =>
        signal.status == ScenarioStepSpecialistStatus.signalLost
            ? 'RESTORE CCTV SIGNAL'
            : 'RECHECK CCTV SPECIALIST',
      _ =>
        signal.status == ScenarioStepSpecialistStatus.signalLost
            ? 'RESTORE SPECIALIST SIGNAL'
            : 'RECHECK SPECIALIST',
    };
  }

  String _monitoringSpecialistFollowUpPrompt(
    ScenarioStepSpecialistSignal signal,
  ) {
    return switch (signal.status) {
      ScenarioStepSpecialistStatus.ready => '',
      ScenarioStepSpecialistStatus.delayed =>
        'Confirm whether the ${signal.specialist.label.toLowerCase()} has returned and refresh the live verification feed.',
      ScenarioStepSpecialistStatus.signalLost =>
        'Restore the ${signal.specialist.label.toLowerCase()} signal and confirm the next verified update before reopening the blocked desk.',
    };
  }

  SpecialistAssessment _buildMonitoringSpecialistAssessment(
    ScenarioStepSpecialistSignal signal, {
    required OnyxToolTarget target,
  }) {
    final evidence = <String>[
      'Deterministic specialist degradation injected at replay step.',
      if (signal.delayMs > 0) 'Delay budget: ${signal.delayMs} ms.',
      if (signal.detail.trim().isNotEmpty) signal.detail,
    ];
    final missingInfo = _monitoringSpecialistMissingInfo(signal);
    return SpecialistAssessment(
      specialist: signal.specialist,
      sourceLabel: 'scenario_replay',
      summary: switch (signal.status) {
        ScenarioStepSpecialistStatus.ready =>
          '${signal.specialist.label} stayed ready during replay.',
        ScenarioStepSpecialistStatus.delayed =>
          '${signal.specialist.label} is delayed${signal.delayMs > 0 ? ' by ${signal.delayMs} ms' : ''}, so ONYX is holding the move in ${_deskLabelForTarget(target)} until fresh verification lands.',
        ScenarioStepSpecialistStatus.signalLost =>
          '${signal.specialist.label} lost signal, so ONYX redirected the move into ${_deskLabelForTarget(target)} while verification recovered.',
      },
      recommendedTarget: target,
      confidence: signal.status == ScenarioStepSpecialistStatus.signalLost
          ? 0.63
          : signal.status == ScenarioStepSpecialistStatus.delayed
          ? 0.68
          : 0.81,
      priority: signal.status == ScenarioStepSpecialistStatus.signalLost
          ? SpecialistAssessmentPriority.critical
          : SpecialistAssessmentPriority.high,
      evidence: evidence,
      missingInfo: missingInfo.isEmpty
          ? const <String>[]
          : <String>[missingInfo],
      allowRouteExecution: true,
      isHardConstraint: false,
    );
  }

  OnyxToolTarget _targetForMonitoringSequenceRoute(String finalRoute) {
    return switch (finalRoute) {
      'dispatch_board' => OnyxToolTarget.dispatchBoard,
      'track_detailed_workspace' => OnyxToolTarget.tacticalTrack,
      'monitoring_watch' => OnyxToolTarget.cctvReview,
      'client_comms' => OnyxToolTarget.clientComms,
      'reports_workspace' => OnyxToolTarget.reportsWorkspace,
      _ => OnyxToolTarget.dispatchBoard,
    };
  }

  String _deskLabelForTarget(OnyxToolTarget target) {
    return switch (target) {
      OnyxToolTarget.dispatchBoard => 'Dispatch Board',
      OnyxToolTarget.tacticalTrack => 'Tactical Track',
      OnyxToolTarget.cctvReview => 'CCTV Review',
      OnyxToolTarget.clientComms => 'Client Comms',
      OnyxToolTarget.reportsWorkspace => 'Reports Workspace',
    };
  }

  String _nextMoveLabelForTarget(OnyxToolTarget target) {
    return switch (target) {
      OnyxToolTarget.dispatchBoard => 'OPEN DISPATCH BOARD',
      OnyxToolTarget.tacticalTrack => 'OPEN TACTICAL TRACK',
      OnyxToolTarget.cctvReview => 'OPEN CCTV REVIEW',
      OnyxToolTarget.clientComms => 'OPEN CLIENT COMMS',
      OnyxToolTarget.reportsWorkspace => 'OPEN REPORTS WORKSPACE',
    };
  }

  OnyxToolTarget _monitoringTargetFromName(String targetName) {
    return OnyxToolTarget.values.firstWhere(
      (target) => target.name == targetName,
      orElse: () => OnyxToolTarget.dispatchBoard,
    );
  }

  ScenarioActualOutcome _runMonitoringReviewHandoffScenario(
    ScenarioLoadedFixtures fixtures,
  ) {
    final reviewQueue = fixtures.projectionState['monitoringWatch'];
    if (reviewQueue is! Map) {
      throw StateError(
        'Monitoring review handoff scenarios require a monitoringWatch projection fixture.',
      );
    }
    final keyedReviewQueue = _stringKeyedMap(reviewQueue);
    final reviewAction = keyedReviewQueue['reviewAction'];
    if (reviewAction is! Map) {
      throw StateError(
        'Monitoring review handoff scenarios require a monitoringWatch.reviewAction fixture.',
      );
    }
    final keyedReviewAction = _stringKeyedMap(reviewAction);
    final incidentReference =
        keyedReviewAction['incidentReference']?.toString() ?? 'INC-UNKNOWN';
    final intelligenceId =
        keyedReviewAction['intelligenceId']?.toString() ?? 'INTEL-UNKNOWN';
    final reviewSurface =
        keyedReviewAction['reviewSurface']?.toString() ?? 'cctv_review';
    final notes =
        'Opened $reviewSurface from the live operations review action for '
        '$incidentReference using $intelligenceId.';
    return ScenarioActualOutcome(
      actualRoute: 'monitoring_watch',
      actualIntent: 'open_cctv_review_handoff',
      actualEscalationState: 'review_opened',
      actualProjectionChanges: <dynamic>[
        <String, dynamic>{'reviewSurface': reviewSurface},
      ],
      actualDrafts: const <dynamic>[],
      actualBlockedActions: const <String>['dismiss_without_review'],
      actualUiState: <String, dynamic>{
        'surface': 'live_ops_review_handoff',
        'reviewActionVisible': true,
        'cctvRouteVisible': reviewSurface == 'cctv_review',
        'incidentReference': incidentReference,
        'intelligenceId': intelligenceId,
        'legacyWorkspaceVisible': false,
      },
      appendedEvents: const <dynamic>[],
      notes: notes,
    );
  }

  ScenarioActualOutcome _runDispatchFlowScenario(
    ScenarioDefinition definition,
    ScenarioLoadedFixtures fixtures,
  ) {
    final navigation = definition.inputs.navigation;
    if (navigation?.entryRoute == 'live_operations_dispatch_handoff') {
      return _runDispatchHandoffScenario(fixtures);
    }
    if (definition.inputs.prompts.isEmpty) {
      throw StateError(
        'Dispatch flow scenarios require at least one prompt in Phase 1.',
      );
    }
    final prompt = definition.inputs.prompts.first;
    final parsed = commandParser.parse(prompt.text);
    if (parsed.intent != OnyxCommandIntent.showDispatchesToday) {
      throw StateError(
        'Dispatch flow Phase 1 only supports showDispatchesToday prompts.',
      );
    }
    final scenarioNow = definition.runtimeContext.currentTime.toLocal();
    final todayDispatches =
        fixtures.existingEvents
            .whereType<Map>()
            .map(_stringKeyedMap)
            .where((event) => event['kind'] == 'decision_created')
            .where((event) {
              final occurredAtRaw = event['occurredAt']?.toString();
              if (occurredAtRaw == null || occurredAtRaw.isEmpty) {
                return false;
              }
              final occurredAt = DateTime.parse(occurredAtRaw).toLocal();
              return occurredAt.year == scenarioNow.year &&
                  occurredAt.month == scenarioNow.month &&
                  occurredAt.day == scenarioNow.day;
            })
            .toList(growable: false)
          ..sort((left, right) {
            final leftAt = DateTime.parse(left['occurredAt'].toString());
            final rightAt = DateTime.parse(right['occurredAt'].toString());
            return rightAt.compareTo(leftAt);
          });
    final dispatchIds = todayDispatches
        .map((event) => event['dispatchId'].toString())
        .toList(growable: false);
    final notes =
        'Summarized ${todayDispatches.length} dispatch creation event(s) for '
        '${scenarioNow.toIso8601String().split('T').first}.';
    return ScenarioActualOutcome(
      actualRoute: 'dispatch_board',
      actualIntent: 'dispatch_today_lookup',
      actualEscalationState: 'none',
      actualProjectionChanges: const <dynamic>[],
      actualDrafts: <dynamic>[
        <String, dynamic>{
          'type': 'dispatch_summary',
          'dispatchCount': todayDispatches.length,
          'dispatchIds': dispatchIds,
        },
      ],
      actualBlockedActions: const <String>[],
      actualUiState: <String, dynamic>{
        'surface': 'dispatch_today_summary',
        'dispatchListVisible': true,
        'dispatchCount': todayDispatches.length,
      },
      appendedEvents: const <dynamic>[],
      notes: notes,
    );
  }

  ScenarioActualOutcome _runDispatchHandoffScenario(
    ScenarioLoadedFixtures fixtures,
  ) {
    final dispatchBoard = fixtures.projectionState['dispatchBoard'];
    if (dispatchBoard is! Map) {
      throw StateError(
        'Dispatch handoff scenarios require a dispatchBoard projection fixture.',
      );
    }
    final keyedDispatchBoard = _stringKeyedMap(dispatchBoard);
    final dispatchHandoff = keyedDispatchBoard['dispatchHandoff'];
    if (dispatchHandoff is! Map) {
      throw StateError(
        'Dispatch handoff scenarios require a dispatchBoard.dispatchHandoff fixture.',
      );
    }
    final keyedDispatchHandoff = _stringKeyedMap(dispatchHandoff);
    final dispatchId =
        keyedDispatchHandoff['dispatchId']?.toString() ?? 'DSP-UNKNOWN';
    final incidentReference =
        keyedDispatchHandoff['incidentReference']?.toString() ?? 'INC-UNKNOWN';
    final priorityLane =
        keyedDispatchHandoff['priorityLane']?.toString() ?? 'priority_response';
    final siteLabel =
        keyedDispatchHandoff['siteLabel']?.toString() ?? 'Unknown Site';
    final notes =
        'Opened dispatch handoff from live operations for '
        '$incidentReference into $priorityLane on $siteLabel.';
    return ScenarioActualOutcome(
      actualRoute: 'dispatch_board',
      actualIntent: 'open_dispatch_handoff',
      actualEscalationState: 'dispatch_ready',
      actualProjectionChanges: <dynamic>[
        <String, dynamic>{'dispatchSelection': dispatchId},
      ],
      actualDrafts: const <dynamic>[],
      actualBlockedActions: const <String>['dismiss_without_dispatch'],
      actualUiState: <String, dynamic>{
        'surface': 'live_ops_dispatch_handoff',
        'dispatchBoardVisible': true,
        'dispatchHandoffVisible': true,
        'readyToDispatchVisible': true,
        'priorityLaneVisible': true,
        'dispatchId': dispatchId,
        'incidentReference': incidentReference,
        'priorityLane': priorityLane,
        'siteLabel': siteLabel,
        'legacyWorkspaceVisible': false,
      },
      appendedEvents: const <dynamic>[],
      notes: notes,
    );
  }

  ScenarioActualOutcome _runIncidentTimelineScenario(
    ScenarioDefinition definition,
    ScenarioLoadedFixtures fixtures,
  ) {
    if (definition.inputs.prompts.isEmpty) {
      throw StateError(
        'Incident timeline scenarios require at least one prompt in Phase 1.',
      );
    }
    final prompt = definition.inputs.prompts.first;
    final parsed = commandParser.parse(prompt.text);
    if (parsed.intent != OnyxCommandIntent.summarizeIncident) {
      throw StateError(
        'Incident timeline Phase 1 only supports summarizeIncident prompts.',
      );
    }
    final incidentTimeline = fixtures.projectionState['incidentTimeline'];
    if (incidentTimeline is! Map) {
      throw StateError(
        'Incident timeline Phase 1 requires an incidentTimeline projection fixture.',
      );
    }
    final keyedTimeline = _stringKeyedMap(incidentTimeline);
    final incidentReference =
        keyedTimeline['incidentReference']?.toString() ?? 'INC-UNKNOWN';
    final headline =
        keyedTimeline['headline']?.toString() ??
        '$incidentReference summary is ready.';
    final summary =
        keyedTimeline['summary']?.toString() ??
        'No supporting incident summary is attached yet.';
    final eventCount = keyedTimeline['eventCount'] ?? 0;
    final notes =
        'Built a scoped incident summary for $incidentReference from '
        '$eventCount seeded timeline event(s).';
    return ScenarioActualOutcome(
      actualRoute: 'reports_workspace',
      actualIntent: 'summarize_incident',
      actualEscalationState: 'none',
      actualProjectionChanges: const <dynamic>[],
      actualDrafts: <dynamic>[
        <String, dynamic>{
          'type': 'incident_summary',
          'incidentReference': incidentReference,
          'headline': headline,
          'summary': summary,
        },
      ],
      actualBlockedActions: const <String>[],
      actualUiState: <String, dynamic>{
        'surface': 'incident_summary',
        'timelineVisible': true,
        'activeIncidentVisible': true,
      },
      appendedEvents: const <dynamic>[],
      notes: notes,
    );
  }

  bool _matchesMonitoringStepCondition(
    ScenarioStepCondition condition,
    ScenarioLoadedFixtures fixtures,
  ) {
    final projectionValue = _resolvePathValue(
      fixtures.projectionState,
      condition.field,
    );
    if (projectionValue == _missingScenarioPathValue) {
      return false;
    }
    return _deepEquals(projectionValue, condition.equals);
  }

  String _describeMonitoringStepCondition(ScenarioStepCondition condition) {
    final description = StringBuffer()
      ..write('field=')
      ..write(condition.field)
      ..write(', equals=')
      ..write(condition.equals);
    if (condition.otherwiseStepId != null) {
      description
        ..write(', otherwiseStepId=')
        ..write(condition.otherwiseStepId);
    }
    return description.toString();
  }

  dynamic _resolvePathValue(Map<String, dynamic> root, String path) {
    dynamic current = root;
    for (final segment in path.split('.')) {
      if (segment.isEmpty || current is! Map) {
        return _missingScenarioPathValue;
      }
      final keyedCurrent = _stringKeyedMap(current);
      if (!keyedCurrent.containsKey(segment)) {
        return _missingScenarioPathValue;
      }
      current = keyedCurrent[segment];
      if (current == null) {
        return _missingScenarioPathValue;
      }
    }
    return current;
  }

  List<ScenarioMismatch> _compareOutcome(
    ScenarioExpectedOutcome expected,
    ScenarioActualOutcome actual,
  ) {
    final mismatches = <ScenarioMismatch>[];
    final expectedCommandBrainSnapshot = expected.commandBrainSnapshot ??
        (expected.commandBrainTimeline.isEmpty
            ? null
            : expected.commandBrainTimeline.last.snapshot);
    final actualCommandBrainSnapshot = actual.commandBrainSnapshot ??
        (actual.commandBrainTimeline.isEmpty
            ? null
            : actual.commandBrainTimeline.last.snapshot);
    _maybeAddMismatch(
      mismatches,
      field: 'expectedRoute',
      expected: expected.expectedRoute,
      actual: actual.actualRoute,
    );
    _maybeAddMismatch(
      mismatches,
      field: 'expectedIntent',
      expected: expected.expectedIntent,
      actual: actual.actualIntent,
    );
    _maybeAddMismatch(
      mismatches,
      field: 'expectedEscalationState',
      expected: expected.expectedEscalationState,
      actual: actual.actualEscalationState,
    );
    _maybeAddMismatch(
      mismatches,
      field: 'expectedProjectionChanges',
      expected: expected.expectedProjectionChanges,
      actual: actual.actualProjectionChanges,
    );
    _maybeAddMismatch(
      mismatches,
      field: 'expectedDrafts',
      expected: expected.expectedDrafts,
      actual: actual.actualDrafts,
    );
    _maybeAddMismatch(
      mismatches,
      field: 'expectedBlockedActions',
      expected: List<String>.from(expected.expectedBlockedActions)..sort(),
      actual: List<String>.from(actual.actualBlockedActions)..sort(),
    );
    if (!_isExpectedSubset(expected.expectedUiState, actual.actualUiState)) {
      mismatches.add(
        ScenarioMismatch(
          field: 'expectedUiState',
          expected: expected.expectedUiState,
          actual: actual.actualUiState,
        ),
      );
    }
    if (expected.commandBrainSnapshot != null &&
        !_deepEquals(
          expected.commandBrainSnapshot!.toJson(),
          actual.commandBrainSnapshot?.toJson(),
        )) {
      mismatches.add(
        ScenarioMismatch(
          field: 'commandBrainSnapshot',
          expected: expected.commandBrainSnapshot!.toJson(),
          actual: actual.commandBrainSnapshot?.toJson(),
        ),
      );
    }
    final expectedReplayBiasStack = _commandBrainReplayBiasStackPayload(
      expectedCommandBrainSnapshot,
    );
    final actualReplayBiasStack = _commandBrainReplayBiasStackPayload(
      actualCommandBrainSnapshot,
    );
    if (expectedReplayBiasStack != null &&
        !_deepEquals(expectedReplayBiasStack, actualReplayBiasStack)) {
      mismatches.add(
        ScenarioMismatch(
          field: 'commandBrainReplayBiasStack',
          expected: expectedReplayBiasStack,
          actual: actualReplayBiasStack,
        ),
      );
    }
    if (expected.commandBrainTimeline.isNotEmpty &&
        !_deepEquals(
          expected.commandBrainTimeline
              .map((entry) => entry.toJson())
              .toList(growable: false),
          actual.commandBrainTimeline
              .map((entry) => entry.toJson())
              .toList(growable: false),
        )) {
      mismatches.add(
        ScenarioMismatch(
          field: 'commandBrainTimeline',
          expected: expected.commandBrainTimeline
              .map((entry) => entry.toJson())
              .toList(growable: false),
          actual: actual.commandBrainTimeline
              .map((entry) => entry.toJson())
              .toList(growable: false),
        ),
      );
    }
    return mismatches;
  }

  Map<String, Object?>? _commandBrainReplayBiasStackPayload(
    OnyxCommandBrainSnapshot? snapshot,
  ) {
    if (snapshot == null || snapshot.orderedReplayBiasStack.isEmpty) {
      return null;
    }
    return <String, Object?>{
      'signature': snapshot.replayBiasStackSignature,
      'entries': snapshot.orderedReplayBiasStack
          .map((bias) => bias.toJson())
          .toList(growable: false),
    };
  }

  void _maybeAddMismatch(
    List<ScenarioMismatch> mismatches, {
    required String field,
    required Object? expected,
    required Object? actual,
  }) {
    if (_deepEquals(expected, actual)) {
      return;
    }
    mismatches.add(
      ScenarioMismatch(field: field, expected: expected, actual: actual),
    );
  }

  String _adminRouteForParsedIntent(
    OnyxCommandIntent intent,
    String authorityScope,
  ) {
    switch (intent) {
      case OnyxCommandIntent.showUnresolvedIncidents:
      case OnyxCommandIntent.showIncidentsLastNight:
      case OnyxCommandIntent.showSiteMostAlertsThisWeek:
      case OnyxCommandIntent.showDispatchesToday:
        return authorityScope == 'all_sites'
            ? 'admin_all_sites_read'
            : 'admin_scoped_read';
      default:
        return 'admin_operator_triage';
    }
  }

  String _adminIntentForPrompt(
    OnyxCommandIntent intent,
    String normalizedPrompt,
    String authorityScope,
  ) {
    switch (intent) {
      case OnyxCommandIntent.showUnresolvedIncidents:
        if (_containsAny(normalizedPrompt, const <String>[
          'breach',
          'breaches',
        ])) {
          return authorityScope == 'all_sites'
              ? 'portfolio_breach_lookup'
              : 'site_breach_lookup';
        }
        return authorityScope == 'all_sites'
            ? 'portfolio_unresolved_lookup'
            : 'scoped_unresolved_lookup';
      case OnyxCommandIntent.showIncidentsLastNight:
        if (normalizedPrompt.contains('police')) {
          return authorityScope == 'all_sites'
              ? 'portfolio_police_activity_lookup'
              : 'site_police_activity_lookup';
        }
        return 'overnight_incident_lookup';
      case OnyxCommandIntent.showSiteMostAlertsThisWeek:
        return 'weekly_top_alert_site_lookup';
      case OnyxCommandIntent.showDispatchesToday:
        return authorityScope == 'all_sites'
            ? 'portfolio_dispatch_lookup'
            : 'scoped_dispatch_lookup';
      default:
        return intent.name;
    }
  }

  bool _containsAny(String value, List<String> needles) {
    for (final needle in needles) {
      if (value.contains(needle)) {
        return true;
      }
    }
    return false;
  }

  String _resolvePath(String path) {
    if (path.startsWith('/')) {
      return path;
    }
    return _normalizePath('$workspaceRoot/$path');
  }
}

bool _deepEquals(Object? left, Object? right) {
  return jsonEncode(left) == jsonEncode(right);
}

bool _isExpectedSubset(
  Map<String, dynamic> expected,
  Map<String, dynamic> actual,
) {
  for (final entry in expected.entries) {
    if (!actual.containsKey(entry.key)) {
      return false;
    }
    final actualValue = actual[entry.key];
    final expectedValue = entry.value;
    if (expectedValue is Map && actualValue is Map) {
      if (!_isExpectedSubset(
        _stringKeyedMap(expectedValue),
        _stringKeyedMap(actualValue),
      )) {
        return false;
      }
      continue;
    }
    if (!_deepEquals(expectedValue, actualValue)) {
      return false;
    }
  }
  return true;
}

String _normalizeId(String value) {
  return value.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]+'), '_');
}

String _normalizeTimestamp(DateTime value) {
  return value
      .toUtc()
      .toIso8601String()
      .replaceAll(':', '')
      .replaceAll('-', '')
      .replaceAll('.', '')
      .replaceAll('T', 'T')
      .replaceAll('Z', 'Z');
}

String _normalizePath(String value) => value.replaceAll('//', '/');

final Object _missingScenarioPathValue = Object();

Map<String, dynamic> _stringKeyedMap(Map value) {
  return value.map<String, dynamic>(
    (key, entryValue) => MapEntry(key.toString(), entryValue),
  );
}

String _humanizeIdentifier(String value) {
  final normalized = value
      .replaceAll(RegExp(r'[_\-]+'), ' ')
      .trim()
      .toLowerCase();
  if (normalized.isEmpty) {
    return value;
  }
  return normalized
      .split(RegExp(r'\s+'))
      .map((segment) {
        if (segment.isEmpty) {
          return segment;
        }
        return '${segment[0].toUpperCase()}${segment.substring(1)}';
      })
      .join(' ');
}
