import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/onyx_agent_camera_change_service.dart';
import 'package:omnix_dashboard/application/onyx_agent_camera_bridge_health_service.dart';
import 'package:omnix_dashboard/application/onyx_agent_camera_probe_service.dart';
import 'package:omnix_dashboard/application/onyx_agent_camera_bridge_server_contract.dart';
import 'package:omnix_dashboard/application/onyx_agent_cloud_boost_service.dart';
import 'package:omnix_dashboard/application/onyx_agent_client_draft_service.dart';
import 'package:omnix_dashboard/application/onyx_agent_local_brain_service.dart';
import 'package:omnix_dashboard/application/simulation/scenario_replay_history_signal_service.dart';
import 'package:omnix_dashboard/domain/authority/onyx_task_protocol.dart';
import 'package:omnix_dashboard/domain/events/decision_created.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/domain/events/patrol_completed.dart';
import 'package:omnix_dashboard/domain/events/response_arrived.dart';
import 'package:omnix_dashboard/ui/onyx_agent_page.dart';

OnyxAgentCameraExecutionPacket _buildTestCameraPacket({
  required String packetId,
  required String target,
  String vendorLabel = 'Generic ONVIF',
  String profileLabel = 'Balanced Monitoring',
  String profileKey = 'balanced_monitoring',
  String rollbackExportLabel = 'rollback-CAM-PKT-TEST-1-192-168-1-64.json',
}) {
  return OnyxAgentCameraExecutionPacket(
    packetId: packetId,
    target: target,
    vendorKey: vendorLabel.toLowerCase().replaceAll(' ', '_'),
    vendorLabel: vendorLabel,
    profileKey: profileKey,
    profileLabel: profileLabel,
    onvifProfileToken: 'onyx-test-token',
    mainStreamLabel: 'H.265 1920x1080 @ 15 fps / 2048 kbps',
    subStreamLabel: 'H.264 640x360 @ 8 fps / 384 kbps',
    recorderTarget: 'primary_nvr',
    rollbackExportLabel: rollbackExportLabel,
    credentialHandling: 'Keep credentials local and redacted.',
    changePlan: const <String>[
      'Read media capabilities.',
      'Export current settings.',
      'Apply the approved profile.',
    ],
    verificationPlan: const <String>[
      'Confirm live view.',
      'Confirm recorder ingest.',
    ],
    rollbackPlan: const <String>[
      'Restore the previous profile.',
      'Confirm ingest recovery.',
    ],
  );
}

class _FakeCameraChangeService implements OnyxAgentCameraChangeService {
  _FakeCameraChangeService({
    List<OnyxAgentCameraAuditEntry>? initialHistory,
    this.failStage = false,
  }) : _history = List<OnyxAgentCameraAuditEntry>.from(
         initialHistory ?? const <OnyxAgentCameraAuditEntry>[],
       );

  final List<OnyxAgentCameraAuditEntry> _history;
  final bool failStage;

  @override
  bool get isConfigured => true;

  @override
  String get executionModeLabel => 'LAN test bridge';

  @override
  Future<OnyxAgentCameraChangePlanResult> stage({
    required String target,
    required String clientId,
    required String siteId,
    required String incidentReference,
    required String sourceRouteLabel,
  }) async {
    if (failStage) {
      throw StateError('camera stage failed');
    }
    final resolvedTarget = target.trim().isEmpty
        ? 'current scoped camera target'
        : target;
    final packet = _buildTestCameraPacket(
      packetId: 'CAM-PKT-TEST-1',
      target: resolvedTarget,
    );
    final result = OnyxAgentCameraChangePlanResult(
      packetId: 'CAM-PKT-TEST-1',
      target: resolvedTarget,
      scopeLabel: '$clientId • $siteId',
      incidentReference: incidentReference,
      sourceRouteLabel: sourceRouteLabel,
      providerLabel: 'local:test-camera-change',
      createdAtUtc: _onyxAgentFixtureAtUtc(0),
      executionPacket: packet,
    );
    _history.insert(
      0,
      OnyxAgentCameraAuditEntry(
        auditId: result.packetId,
        kind: OnyxAgentCameraAuditKind.staged,
        packetId: result.packetId,
        target: result.target,
        clientId: clientId,
        siteId: siteId,
        scopeLabel: result.scopeLabel,
        incidentReference: incidentReference,
        sourceRouteLabel: sourceRouteLabel,
        providerLabel: result.providerLabel,
        statusLabel: 'approval staged',
        detail: 'Approval gate active. No device write has been executed yet.',
        success: true,
        recordedAtUtc: result.createdAtUtc,
        executionPacket: packet,
      ),
    );
    return result;
  }

  @override
  Future<OnyxAgentCameraExecutionResult> approveAndExecute({
    required String packetId,
    required String target,
    required String clientId,
    required String siteId,
    required String incidentReference,
  }) async {
    final packet = _buildTestCameraPacket(
      packetId: packetId,
      target: target,
      vendorLabel: 'Hikvision',
      profileLabel: 'Alarm Verification',
      profileKey: 'alarm_verification',
      rollbackExportLabel: 'rollback-CAM-PKT-TEST-1-192-168-1-64-before.json',
    );
    final result = OnyxAgentCameraExecutionResult(
      packetId: packetId,
      executionId: 'CAM-EXEC-TEST-1',
      remoteExecutionId: 'REMOTE-TEST-1',
      target: target,
      scopeLabel: '$clientId • $siteId',
      incidentReference: incidentReference,
      providerLabel: 'local:test-camera-executor',
      approvedAtUtc: _onyxAgentFixtureAtUtc(5),
      outcomeDetail:
          'LAN bridge applied the approved packet and returned confirmation.',
      recommendedNextStep: 'Validate the live stream in CCTV.',
      executionPacket: packet,
    );
    _history.insert(
      0,
      OnyxAgentCameraAuditEntry(
        auditId: result.executionId,
        kind: OnyxAgentCameraAuditKind.executed,
        packetId: result.packetId,
        executionId: result.executionId,
        target: result.target,
        clientId: clientId,
        siteId: siteId,
        scopeLabel: result.scopeLabel,
        incidentReference: incidentReference,
        sourceRouteLabel: 'AI Queue',
        providerLabel: result.providerLabel,
        statusLabel: 'executed',
        detail: result.outcomeDetail,
        success: true,
        recordedAtUtc: result.approvedAtUtc,
        executionPacket: packet,
      ),
    );
    return result;
  }

  @override
  Future<OnyxAgentCameraRollbackResult> logRollback({
    required String packetId,
    required String executionId,
    required String target,
  }) async {
    final packet = _buildTestCameraPacket(
      packetId: packetId,
      target: target,
      vendorLabel: 'Hikvision',
      profileLabel: 'Alarm Verification',
      profileKey: 'alarm_verification',
      rollbackExportLabel: 'rollback-CAM-PKT-TEST-1-192-168-1-64-before.json',
    );
    final result = OnyxAgentCameraRollbackResult(
      packetId: packetId,
      executionId: executionId,
      rollbackId: 'CAM-RBK-TEST-1',
      target: target,
      scopeLabel: 'CLIENT-001 • SITE-SANDTON',
      incidentReference: 'INC-CTRL-88',
      providerLabel: 'local:test-camera-rollback',
      recordedAtUtc: _onyxAgentFixtureAtUtc(8),
      executionPacket: packet,
    );
    _history.insert(
      0,
      OnyxAgentCameraAuditEntry(
        auditId: result.rollbackId,
        kind: OnyxAgentCameraAuditKind.rolledBack,
        packetId: result.packetId,
        executionId: result.executionId,
        rollbackId: result.rollbackId,
        target: result.target,
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        scopeLabel: result.scopeLabel,
        incidentReference: result.incidentReference,
        sourceRouteLabel: 'AI Queue',
        providerLabel: result.providerLabel,
        statusLabel: 'rollback logged',
        detail:
            'Rollback recorded locally. Recheck live view and recorder ingest immediately.',
        success: true,
        recordedAtUtc: result.recordedAtUtc,
        executionPacket: packet,
      ),
    );
    return result;
  }

  @override
  Future<List<OnyxAgentCameraAuditEntry>> readAuditHistory({
    required String clientId,
    required String siteId,
    required String incidentReference,
    int limit = 6,
  }) async {
    return _history.take(limit).toList(growable: false);
  }
}

class _FakeSimulatedCameraChangeService extends _FakeCameraChangeService {
  _FakeSimulatedCameraChangeService();

  @override
  String get executionModeLabel => 'Embedded camera bridge (staging)';
}

class _FakeCameraProbeService implements OnyxAgentCameraProbeService {
  const _FakeCameraProbeService();

  @override
  bool get isConfigured => true;

  @override
  Future<OnyxAgentCameraProbeResult> probe(String target) async {
    return OnyxAgentCameraProbeResult(
      target: target.trim(),
      openPorts: const <int, bool>{80: true, 443: false, 554: true, 8899: true},
      rootHttpStatus: 200,
      onvifHttpStatus: 401,
    );
  }
}

class _FakeClientDraftService implements OnyxAgentClientDraftService {
  const _FakeClientDraftService();

  @override
  bool get isConfigured => true;

  @override
  Future<OnyxAgentClientDraftResult> draft({
    required String prompt,
    required String clientId,
    required String siteId,
    required String incidentReference,
  }) async {
    return OnyxAgentClientDraftResult(
      telegramDraft:
          'Telegram draft for $clientId / $siteId about $incidentReference',
      smsDraft: 'SMS draft based on: $prompt',
      providerLabel: 'local:test-client-draft',
    );
  }
}

class _FakeCloudBoostService implements OnyxAgentCloudBoostService {
  const _FakeCloudBoostService();

  @override
  bool get isConfigured => true;

  @override
  Future<OnyxAgentCloudBoostResponse?> boost({
    required String prompt,
    required OnyxAgentCloudScope scope,
    required OnyxAgentCloudIntent intent,
    String contextSummary = '',
  }) async {
    final maintenanceHighlight =
        onyxAgentPlannerMaintenancePriorityHighlightFromContextSummary(
          contextSummary,
        );
    return OnyxAgentCloudBoostResponse(
      text:
          'The signal picture points to a real controller follow-up: verify CCTV Review first, keep Tactical Track open for posture, and send the client update only after confirmation.',
      providerLabel: 'openai:test-agent',
      advisory: OnyxAgentBrainAdvisory(
        summary:
            'Visual confirmation is still the cleanest next read before wider escalation.',
        recommendedTarget: OnyxToolTarget.cctvReview,
        confidence: 0.82,
        why:
            'The fused signal still depends on visual confirmation before the operator should widen the response.',
        missingInfo: <String>[
          'fresh CCTV clip confirmation',
          'current guard ETA',
        ],
        contextHighlights: <String>[
          ?maintenanceHighlight,
          'Outstanding visual confirmation before escalation',
        ],
        operatorFocusNote: scope.operatorFocusPreserved
            ? 'manual context preserved on ${scope.operatorFocusThreadTitle} while urgent review remains visible on ${scope.operatorFocusUrgentThreadTitle}.'
            : '',
        followUpLabel: 'RECHECK CCTV CONFIRMATION',
        followUpPrompt:
            'Recheck CCTV confirmation for the active incident before widening the response.',
        followUpStatus: 'unresolved',
        narrative:
            'Verify CCTV context first, then keep Tactical Track open while the controller confirms the next client-safe update.',
      ),
    );
  }
}

class _RecordingCloudBoostService extends _FakeCloudBoostService {
  int calls = 0;
  String? lastPrompt;
  OnyxAgentCloudIntent? lastIntent;
  String? lastContextSummary;
  OnyxAgentCloudScope? lastScope;

  @override
  Future<OnyxAgentCloudBoostResponse?> boost({
    required String prompt,
    required OnyxAgentCloudScope scope,
    required OnyxAgentCloudIntent intent,
    String contextSummary = '',
  }) async {
    calls += 1;
    lastPrompt = prompt;
    lastIntent = intent;
    lastContextSummary = contextSummary;
    lastScope = scope;
    return super.boost(
      prompt: prompt,
      scope: scope,
      intent: intent,
      contextSummary: contextSummary,
    );
  }
}

class _ThrowingCloudBoostService implements OnyxAgentCloudBoostService {
  int calls = 0;

  @override
  bool get isConfigured => true;

  @override
  Future<OnyxAgentCloudBoostResponse?> boost({
    required String prompt,
    required OnyxAgentCloudScope scope,
    required OnyxAgentCloudIntent intent,
    String contextSummary = '',
  }) async {
    calls += 1;
    throw StateError('cloud boost offline');
  }
}

class _ErrorCloudBoostService implements OnyxAgentCloudBoostService {
  int calls = 0;

  @override
  bool get isConfigured => true;

  @override
  Future<OnyxAgentCloudBoostResponse?> boost({
    required String prompt,
    required OnyxAgentCloudScope scope,
    required OnyxAgentCloudIntent intent,
    String contextSummary = '',
  }) async {
    calls += 1;
    return const OnyxAgentCloudBoostResponse(
      text: '',
      providerLabel: 'openai:test-agent',
      isError: true,
      errorSummary: 'OpenAI brain request failed',
      errorDetail: 'Provider returned HTTP 503.',
    );
  }
}

class _FakeLocalBrainService implements OnyxAgentLocalBrainService {
  const _FakeLocalBrainService();

  @override
  bool get isConfigured => true;

  @override
  Future<OnyxAgentCloudBoostResponse?> synthesize({
    required String prompt,
    required OnyxAgentCloudScope scope,
    required OnyxAgentCloudIntent intent,
    String contextSummary = '',
  }) async {
    final maintenanceHighlight =
        onyxAgentPlannerMaintenancePriorityHighlightFromContextSummary(
          contextSummary,
        );
    return OnyxAgentCloudBoostResponse(
      text:
          'Offline model view: the safest next step is to verify CCTV context, keep Track pinned, and delay the client update until the signal is confirmed.',
      providerLabel: 'local:ollama:test-brain',
      advisory: OnyxAgentBrainAdvisory(
        summary:
            'Field posture is still active, but the next desk should stay on CCTV until the visual read is confirmed.',
        recommendedTarget: OnyxToolTarget.cctvReview,
        confidence: 0.76,
        why:
            'The local model sees CCTV as the highest-confidence validation lane before the response picture widens.',
        missingInfo: <String>['fresh clip confirmation'],
        contextHighlights: <String>[
          ?maintenanceHighlight,
          'Outstanding visual confirmation before escalation',
        ],
        operatorFocusNote: scope.operatorFocusPreserved
            ? 'manual context preserved on ${scope.operatorFocusThreadTitle} while urgent review remains visible on ${scope.operatorFocusUrgentThreadTitle}.'
            : '',
        followUpLabel: 'RECHECK CCTV CONFIRMATION',
        followUpPrompt:
            'Recheck CCTV confirmation for the active incident before widening the response.',
        followUpStatus: 'unresolved',
        narrative:
            'Verify CCTV context first, then keep Track pinned while the signal is confirmed.',
      ),
    );
  }
}

class _RecordingLocalBrainService extends _FakeLocalBrainService {
  int calls = 0;
  String? lastPrompt;
  OnyxAgentCloudIntent? lastIntent;
  String? lastContextSummary;
  OnyxAgentCloudScope? lastScope;

  @override
  Future<OnyxAgentCloudBoostResponse?> synthesize({
    required String prompt,
    required OnyxAgentCloudScope scope,
    required OnyxAgentCloudIntent intent,
    String contextSummary = '',
  }) async {
    calls += 1;
    lastPrompt = prompt;
    lastIntent = intent;
    lastContextSummary = contextSummary;
    lastScope = scope;
    return super.synthesize(
      prompt: prompt,
      scope: scope,
      intent: intent,
      contextSummary: contextSummary,
    );
  }
}

class _ThrowingLocalBrainService implements OnyxAgentLocalBrainService {
  int calls = 0;

  @override
  bool get isConfigured => true;

  @override
  Future<OnyxAgentCloudBoostResponse?> synthesize({
    required String prompt,
    required OnyxAgentCloudScope scope,
    required OnyxAgentCloudIntent intent,
    String contextSummary = '',
  }) async {
    calls += 1;
    throw StateError('local brain offline');
  }
}

class _ErrorLocalBrainService implements OnyxAgentLocalBrainService {
  int calls = 0;

  @override
  bool get isConfigured => true;

  @override
  Future<OnyxAgentCloudBoostResponse?> synthesize({
    required String prompt,
    required OnyxAgentCloudScope scope,
    required OnyxAgentCloudIntent intent,
    String contextSummary = '',
  }) async {
    calls += 1;
    return const OnyxAgentCloudBoostResponse(
      text: '',
      providerLabel: 'local:ollama:test-brain',
      isError: true,
      errorSummary: 'Local brain request failed',
      errorDetail: 'Provider returned HTTP 503.',
    );
  }
}

const _promotedReplayConflictSignal = ScenarioReplayHistorySignal(
  scenarioId: 'parser_monitoring_review_action_specialist_conflict_v1',
  scope: ScenarioReplayHistorySignalScope.specialistConflict,
  trend: 'stabilizing',
  message: 'Specialist conflict remains unresolved.',
  count: 2,
  baseSeverity: 'low',
  effectiveSeverity: 'medium',
  policyMatchType: 'scope_severity_override',
  policyMatchValue: 'specialist_conflict:medium',
  policyMatchSource: 'scenario_set_category',
  latestSummary: 'CCTV holds review while Track pushes tactical track.',
  latestSpecialists: <String>['cctv', 'track'],
  latestTargets: <String>['cctvReview', 'tacticalTrack'],
);

const _sequenceFallbackReplaySignal = ScenarioReplayHistorySignal(
  scenarioId: 'parser_monitoring_priority_sequence_review_track_v1',
  scope: ScenarioReplayHistorySignalScope.sequenceFallback,
  trend: 'stabilizing',
  message: 'Replay sequence fallback remains active.',
  count: 2,
  baseSeverity: 'low',
  effectiveSeverity: 'low',
  latestSummary:
      'Dispatch was unavailable, so ONYX kept the live-ops sequence moving in Tactical Track.',
  latestTarget: 'tacticalTrack',
  latestBiasSource: 'replayPolicy',
  latestBiasScope: 'sequenceFallback',
  latestBiasSignature: 'replayPolicy:sequenceFallback',
  latestBiasPolicySourceLabel: 'scenario sequence policy',
  latestBranch: 'active',
);

const _promotedSequenceFallbackReplaySignal = ScenarioReplayHistorySignal(
  scenarioId: 'monitoring_priority_sequence_review_track_validation_v1',
  scope: ScenarioReplayHistorySignalScope.sequenceFallback,
  trend: 'worsening',
  message: 'Replay sequence fallback remains active under policy escalation.',
  count: 3,
  baseSeverity: 'high',
  effectiveSeverity: 'critical',
  policyMatchType: 'scope_severity_override',
  policyMatchValue: 'sequence_fallback:critical',
  policyMatchSource: 'scenario_set_scenario_id',
  latestSummary:
      'Dispatch was unavailable, so ONYX kept the live-ops sequence moving in Tactical Track.',
  latestTarget: 'tacticalTrack',
  latestBiasSource: 'replayPolicy',
  latestBiasScope: 'sequenceFallback',
  latestBiasSignature: 'replayPolicy:sequenceFallback',
  latestBiasPolicySourceLabel: 'scenario set/scenario policy',
  latestBranch: 'active',
);

const _stackedSequenceFallbackReplaySignal = ScenarioReplayHistorySignal(
  scenarioId: 'monitoring_priority_sequence_review_track_validation_v1',
  scope: ScenarioReplayHistorySignalScope.sequenceFallback,
  trend: 'stabilizing',
  message: 'Replay sequence fallback remains active.',
  count: 2,
  baseSeverity: 'low',
  effectiveSeverity: 'low',
  latestSummary:
      'Dispatch was unavailable, so ONYX kept the live-ops sequence moving in Tactical Track.',
  latestTarget: 'tacticalTrack',
  latestBiasSource: 'replayPolicy',
  latestBiasScope: 'sequenceFallback',
  latestBiasSignature: 'replayPolicy:sequenceFallback',
  latestBiasPolicySourceLabel: 'scenario sequence policy',
  latestBranch: 'active',
  latestReplayBiasStackSignature:
      'replayPolicy:sequenceFallback:tacticalTrack -> replayPolicy:specialistConflict:cctvReview',
  latestReplayBiasStackPosition: 0,
);

const _stackedReplayConflictSignal = ScenarioReplayHistorySignal(
  scenarioId: 'monitoring_priority_sequence_review_track_validation_v1',
  scope: ScenarioReplayHistorySignalScope.specialistConflict,
  trend: 'worsening',
  message: 'Specialist conflict opened for review.',
  count: 1,
  baseSeverity: 'low',
  effectiveSeverity: 'medium',
  latestSummary:
      'Replay history: specialist conflict still leans back to CCTV Review.',
  latestTarget: 'cctvReview',
  latestBiasSource: 'replayPolicy',
  latestBiasScope: 'specialistConflict',
  latestBiasSignature: 'replayPolicy:specialistConflict',
  latestReplayBiasStackSignature:
      'replayPolicy:sequenceFallback:tacticalTrack -> replayPolicy:specialistConflict:cctvReview',
  latestReplayBiasStackPosition: 1,
);

const _replayBiasStackDriftSignal = ScenarioReplayHistorySignal(
  scenarioId: 'monitoring_priority_sequence_review_track_validation_v1',
  scope: ScenarioReplayHistorySignalScope.replayBiasStackDrift,
  trend: 'worsening',
  message: 'Replay bias stack reordered after a cleaner run.',
  count: 1,
  baseSeverity: 'critical',
  effectiveSeverity: 'critical',
  latestSummary:
      'Replay bias stack changed. Previous pressure: Primary replay pressure: sequence fallback -> Tactical Track. Latest pressure: Primary replay pressure: sequence fallback -> Tactical Track. Secondary replay pressure: specialist conflict -> CCTV Review.',
  latestReplayBiasStackSignature:
      'replayPolicy:sequenceFallback:tacticalTrack -> replayPolicy:specialistConflict:cctvReview',
  previousReplayBiasStackSignature:
      'replayPolicy:sequenceFallback:tacticalTrack',
);

class _FakeReplayHistorySignalService
    extends ScenarioReplayHistorySignalService {
  const _FakeReplayHistorySignalService(
    this.signal, {
    this.signalStack = const <ScenarioReplayHistorySignal>[],
  });

  final ScenarioReplayHistorySignal? signal;
  final List<ScenarioReplayHistorySignal> signalStack;

  @override
  Future<List<ScenarioReplayHistorySignal>> loadSignalStack({
    int limit = 3,
  }) async {
    final stack = signalStack.isNotEmpty
        ? signalStack
        : <ScenarioReplayHistorySignal>[?signal];
    return stack.take(limit).toList(growable: false);
  }
}

class _PriorityOrderingLocalBrainService extends _FakeLocalBrainService {
  const _PriorityOrderingLocalBrainService();

  @override
  Future<OnyxAgentCloudBoostResponse?> synthesize({
    required String prompt,
    required OnyxAgentCloudScope scope,
    required OnyxAgentCloudIntent intent,
    String contextSummary = '',
  }) async {
    return OnyxAgentCloudBoostResponse(
      text: 'Keep the maintenance signal visible while you confirm the hold.',
      providerLabel: 'local:ollama:test-priority-ordering',
      advisory: const OnyxAgentBrainAdvisory(
        summary: 'Multiple controller pressures are active at once.',
        recommendedTarget: OnyxToolTarget.dispatchBoard,
        confidence: 0.71,
        why:
            'Maintenance drift is still hottest, but the overdue follow-up and preserved manual context matter too.',
        missingInfo: <String>[],
        contextHighlights: <String>[
          'Operator focus: preserving your current thread while urgent review stays visible in the rail.',
          'Outstanding visual confirmation before escalation',
          'Outstanding follow-up: RECHECK RESPONDER ETA (overdue).',
          'Top maintenance pressure: Completed maintenance review for chronic drift from archived watch on Increase Tactical Track weighting.',
        ],
        narrative:
            'Keep the planner signal, overdue follow-up, and preserved manual context visible in that order.',
      ),
    );
  }
}

class _FakeCameraBridgeHealthService
    implements OnyxAgentCameraBridgeHealthService {
  const _FakeCameraBridgeHealthService();

  @override
  bool get isConfigured => true;

  @override
  Future<OnyxAgentCameraBridgeHealthSnapshot> probe(Uri endpoint) async {
    return OnyxAgentCameraBridgeHealthSnapshot(
      requestedEndpoint: endpoint,
      healthEndpoint: endpoint.replace(path: '/health'),
      reportedEndpoint: endpoint,
      reachable: true,
      running: true,
      statusCode: 200,
      statusLabel: 'Healthy',
      detail:
          'GET /health succeeded and the bridge reported packet ingress ready.',
      executePath: '/execute',
      checkedAtUtc: _freshBridgeCheckedAtUtc(),
    );
  }
}

DateTime _agentPageNowUtc() => DateTime.now().toUtc();

DateTime _onyxAgentFixtureBaseUtc() =>
    _agentPageNowUtc().subtract(const Duration(minutes: 8));

DateTime _onyxAgentFixtureAtUtc(int minute) =>
    _onyxAgentFixtureBaseUtc().add(Duration(minutes: minute));

DateTime _freshBridgeCheckedAtUtc() =>
    _agentPageNowUtc().subtract(const Duration(minutes: 5));

DateTime _staleBridgeCheckedAtUtc() =>
    _agentPageNowUtc().subtract(const Duration(hours: 2));

Map<String, dynamic> _expectPlannerDrivenThreadHandoff(
  Map<String, Object?>? sessionState, {
  required String selectedThreadId,
  int? expectedMessageCount,
  String? expectedMessageHeadline,
}) {
  expect(sessionState, isNotNull);
  final state = jsonDecode(jsonEncode(sessionState)) as Map<String, dynamic>;
  expect(state['selected_thread_id'], selectedThreadId);
  expect(state.containsKey('selected_thread_operator_id'), isFalse);
  expect(state.containsKey('selected_thread_operator_at_utc'), isFalse);

  final threads = (state['threads'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  final selectedThread = threads.firstWhere(
    (thread) => thread['id'] == selectedThreadId,
  );
  final memory = selectedThread['memory'] as Map<String, dynamic>;
  expect(memory.containsKey('stale_follow_up_surface_count'), isFalse);
  expect(memory.containsKey('last_auto_follow_up_surfaced_at_utc'), isFalse);

  if (expectedMessageCount != null || expectedMessageHeadline != null) {
    final messages = (selectedThread['messages'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    if (expectedMessageCount != null) {
      expect(messages, hasLength(expectedMessageCount));
    }
    if (expectedMessageHeadline != null) {
      expect(
        messages.where(
          (message) => message['headline'] == expectedMessageHeadline,
        ),
        hasLength(1),
      );
    }
  }

  return state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('onyx agent page renders controller brain and specialist mesh', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: OnyxAgentPage(
          scopeClientId: 'CLIENT-001',
          scopeSiteId: 'SITE-SANDTON',
          focusIncidentReference: 'INC-CTRL-42',
          sourceRouteLabel: 'Command',
          cloudAssistAvailable: true,
          cameraChangeService: _FakeCameraChangeService(),
          cameraProbeService: _FakeCameraProbeService(),
          clientDraftService: _FakeClientDraftService(),
          localBrainService: _FakeLocalBrainService(),
          cloudBoostService: _FakeCloudBoostService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('onyx-agent-page')), findsOneWidget);
    expect(find.text('Junior Analyst'), findsOneWidget);
    expect(find.text('Tactical Track Agent'), findsOneWidget);
    expect(find.text('Signal Picture Agent'), findsWidgets);
    expect(find.text('Policy / Logic Agent'), findsOneWidget);
    expect(find.text('Summon OpenAI when needed'), findsOneWidget);
    expect(
      find.text(
        'Smart routing is active. Fast tasks stay local; complex or overdue work can escalate to OpenAI. Approval stays with you.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('onyx agent page ingests evidence returns into the header rail', (
    tester,
  ) async {
    String? consumedAuditId;

    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: OnyxAgentPage(
          scopeClientId: 'CLIENT-001',
          scopeSiteId: 'SITE-SANDTON',
          focusIncidentReference: 'INC-DSP-2442',
          sourceRouteLabel: 'Dispatches',
          cloudAssistAvailable: true,
          cameraChangeService: _FakeCameraChangeService(),
          cameraProbeService: const _FakeCameraProbeService(),
          clientDraftService: const _FakeClientDraftService(),
          evidenceReturnReceipt: const OnyxAgentEvidenceReturnReceipt(
            auditId: 'audit-agent-2442',
            label: 'EVIDENCE RETURN',
            headline: 'Returned to AI Copilot for DSP-2442.',
            detail:
                'The signed analyst handoff was verified in the ledger. Keep the same dispatch context pinned and finish the next move from here.',
            accent: Color(0xFFC084FC),
          ),
          onConsumeEvidenceReturnReceipt: (auditId) {
            consumedAuditId = auditId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('onyx-agent-evidence-return-banner')),
      findsOneWidget,
    );
    expect(find.text('EVIDENCE RETURN'), findsOneWidget);
    expect(find.text('Returned to AI Copilot for DSP-2442.'), findsOneWidget);
    expect(consumedAuditId, 'audit-agent-2442');
  });

  testWidgets('onyx agent page routes telemetry prompts into scoped Track', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var openedTrackCount = 0;
    String? openedTrackIncident;

    await tester.pumpWidget(
      MaterialApp(
        home: OnyxAgentPage(
          scopeClientId: 'CLIENT-001',
          scopeSiteId: 'SITE-SANDTON',
          focusIncidentReference: 'INC-CTRL-42',
          cloudAssistAvailable: true,
          cameraChangeService: _FakeCameraChangeService(),
          cameraProbeService: const _FakeCameraProbeService(),
          clientDraftService: const _FakeClientDraftService(),
          onOpenCctv: () {},
          onOpenCctvForIncident: (_) {},
          onOpenAlarms: () {},
          onOpenAlarmsForIncident: (_) {},
          onOpenTrack: () {
            openedTrackCount += 1;
          },
          onOpenTrackForIncident: (incidentReference) {
            openedTrackIncident = incidentReference;
          },
          onOpenComms: () {},
          onOpenCommsForScope: (_, scopeId) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('onyx-agent-composer-field')),
      'Review telemetry posture for the active incident',
    );
    await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
    await tester.pumpAndSettle();

    final openTrackAction = find.byKey(
      const ValueKey('onyx-agent-action-telemetry-open-track'),
    );
    final messageList = find.byKey(const ValueKey('onyx-agent-message-list'));
    for (
      var attempt = 0;
      attempt < 5 && openTrackAction.evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(messageList, const Offset(0, -280));
      await tester.pumpAndSettle();
    }
    expect(openTrackAction, findsOneWidget);
    await tester.ensureVisible(openTrackAction);
    await tester.pumpAndSettle();
    await tester.tap(openTrackAction);
    await tester.pump();

    expect(openedTrackCount, 0);
    expect(openedTrackIncident, 'INC-CTRL-42');
  });

  testWidgets(
    'onyx agent page shows direct resume actions for dispatch, track, and comms sources',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String? resumedDispatchIncident;
      String? resumedTrackIncident;
      String? resumedCommsClientId;
      String? resumedCommsSiteId;

      Future<void> pumpAgent(Widget page) async {
        await tester.pumpWidget(MaterialApp(home: page));
        await tester.pumpAndSettle();
      }

      await pumpAgent(
        OnyxAgentPage(
          scopeClientId: 'CLIENT-001',
          scopeSiteId: 'SITE-SANDTON',
          focusIncidentReference: 'INC-DSP-101',
          sourceRouteLabel: 'Dispatches',
          cameraChangeService: _FakeCameraChangeService(),
          cameraProbeService: _FakeCameraProbeService(),
          clientDraftService: _FakeClientDraftService(),
          onOpenAlarmsForIncident: (incidentReference) {
            resumedDispatchIncident = incidentReference;
          },
        ),
      );

      final resumeAlarms = find.byKey(
        const ValueKey('onyx-agent-resume-alarms-button'),
      );
      expect(resumeAlarms, findsOneWidget);
      await tester.tap(resumeAlarms);
      await tester.pump();
      expect(resumedDispatchIncident, 'INC-DSP-101');

      await pumpAgent(
        OnyxAgentPage(
          scopeClientId: 'CLIENT-001',
          scopeSiteId: 'SITE-SANDTON',
          focusIncidentReference: 'INC-TRACK-101',
          sourceRouteLabel: 'Track',
          cameraChangeService: _FakeCameraChangeService(),
          cameraProbeService: _FakeCameraProbeService(),
          clientDraftService: _FakeClientDraftService(),
          onOpenTrackForIncident: (incidentReference) {
            resumedTrackIncident = incidentReference;
          },
        ),
      );

      final resumeTrack = find.byKey(
        const ValueKey('onyx-agent-resume-track-button'),
      );
      expect(resumeTrack, findsOneWidget);
      await tester.tap(resumeTrack);
      await tester.pump();
      expect(resumedTrackIncident, 'INC-TRACK-101');

      await pumpAgent(
        OnyxAgentPage(
          scopeClientId: 'CLIENT-VALLEE',
          scopeSiteId: 'SITE-RESIDENCE',
          focusIncidentReference: 'INC-COMMS-101',
          sourceRouteLabel: 'Clients',
          cameraChangeService: _FakeCameraChangeService(),
          cameraProbeService: _FakeCameraProbeService(),
          clientDraftService: _FakeClientDraftService(),
          onOpenCommsForScope: (clientId, siteId) {
            resumedCommsClientId = clientId;
            resumedCommsSiteId = siteId;
          },
        ),
      );

      final resumeComms = find.byKey(
        const ValueKey('onyx-agent-resume-comms-button'),
      );
      expect(resumeComms, findsOneWidget);
      await tester.tap(resumeComms);
      await tester.pump();
      expect(resumedCommsClientId, 'CLIENT-VALLEE');
      expect(resumedCommsSiteId, 'SITE-RESIDENCE');
    },
  );

  testWidgets(
    'onyx agent page uses typed triage for one next move and records an evidence receipt',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final localBrainService = _RecordingLocalBrainService();
      String? openedDispatchIncident;
      Map<String, Object?>? sessionState;

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-CTRL-777',
            sourceRouteLabel: 'Command',
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            localBrainService: localBrainService,
            onOpenAlarmsForIncident: (incidentReference) {
              openedDispatchIncident = incidentReference;
            },
            onThreadSessionStateChanged: (state) {
              sessionState = state;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('onyx-agent-composer-field')),
        'Triage the active incident and stage one obvious next move',
      );
      await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
      await tester.pumpAndSettle();

      final messageList = find.byKey(const ValueKey('onyx-agent-message-list'));
      final triageSummary = find.textContaining(
        'One next move is staged in Dispatch Board.',
      );
      for (
        var attempt = 0;
        attempt < 5 && triageSummary.evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(messageList, const Offset(0, -280));
        await tester.pumpAndSettle();
      }

      expect(localBrainService.calls, 0);
      expect(triageSummary, findsWidgets);

      final executeNextMove = find.widgetWithText(OutlinedButton, 'Do this');
      for (
        var attempt = 0;
        attempt < 5 && executeNextMove.evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(messageList, const Offset(0, -280));
        await tester.pumpAndSettle();
      }
      expect(executeNextMove, findsOneWidget);
      final executeNextMoveButton = tester.widget<OutlinedButton>(
        executeNextMove,
      );
      executeNextMoveButton.onPressed!.call();
      await tester.pumpAndSettle();

      final evidenceReceipt = find.textContaining('EVIDENCE RECEIPT');
      for (
        var attempt = 0;
        attempt < 5 && evidenceReceipt.evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(messageList, const Offset(0, -280));
        await tester.pumpAndSettle();
      }

      expect(openedDispatchIncident, 'INC-CTRL-777');
      expect(evidenceReceipt, findsWidgets);
      expect(
        find.textContaining('Dispatch Board handoff sealed.'),
        findsWidgets,
      );

      final persistedState =
          jsonDecode(jsonEncode(sessionState)) as Map<String, dynamic>;
      final persistedThreads = (persistedState['threads'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final persistedMemory =
          persistedThreads.first['memory'] as Map<String, dynamic>;
      final persistedCommandSurfaceMemory =
          persistedMemory['command_surface_memory'] as Map<String, dynamic>;
      final persistedCommandPreview =
          persistedCommandSurfaceMemory['commandPreview']
              as Map<String, dynamic>;
      final persistedCommandReceipt =
          persistedCommandSurfaceMemory['commandReceipt']
              as Map<String, dynamic>;
      final persistedCommandOutcome =
          persistedCommandSurfaceMemory['commandOutcome']
              as Map<String, dynamic>;
      expect(
        persistedCommandPreview['headline'],
        'Dispatch Board is the next move',
      );
      expect(persistedCommandPreview['label'], 'OPEN DISPATCH BOARD');
      expect(
        persistedCommandPreview['summary'],
        'One next move is staged in Dispatch Board.',
      );
      expect(persistedCommandReceipt['label'], 'EVIDENCE RECEIPT');
      expect(
        persistedCommandReceipt['headline'],
        'Dispatch Board handoff sealed.',
      );
      expect(persistedCommandReceipt['target'], 'dispatchBoard');
      expect(
        persistedCommandOutcome['headline'],
        'Dispatch Board opened from typed triage.',
      );
      expect(
        persistedCommandOutcome['summary'],
        'One next move is staged in Dispatch Board.',
      );
    },
  );

  testWidgets(
    'onyx agent page holds for clarification when a threat query has no signals',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: '',
            sourceRouteLabel: 'Command',
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('onyx-agent-composer-field')),
        'Is there a fire?',
      );
      await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
      await tester.pumpAndSettle();

      final messageList = find.byKey(const ValueKey('onyx-agent-message-list'));
      final clarificationAdvisory = find.textContaining(
        'Advisory: No signals detected for that threat',
      );
      for (
        var attempt = 0;
        attempt < 5 && clarificationAdvisory.evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(messageList, const Offset(0, -280));
        await tester.pumpAndSettle();
      }

      expect(clarificationAdvisory, findsOneWidget);
      expect(
        find.textContaining('Missing info: site or incident reference'),
        findsOneWidget,
      );
      expect(find.widgetWithText(OutlinedButton, 'Do this'), findsNothing);
      expect(
        find.textContaining('Still confirm site or incident reference'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'onyx agent page compresses repeated threat queries instead of re-analyzing from scratch',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            sourceRouteLabel: 'Command',
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> askAnyBreaches() async {
        await tester.enterText(
          find.byKey(const ValueKey('onyx-agent-composer-field')),
          'Any breaches?',
        );
        await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
        await tester.pumpAndSettle();
      }

      await askAnyBreaches();
      await askAnyBreaches();
      await askAnyBreaches();

      final messageList = find.byKey(const ValueKey('onyx-agent-message-list'));
      final compressedReply = find.textContaining(
        'No change from the last check.',
      );
      for (
        var attempt = 0;
        attempt < 6 && compressedReply.evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(messageList, const Offset(0, -280));
        await tester.pumpAndSettle();
      }

      expect(compressedReply, findsOneWidget);
      expect(
        find.textContaining('Still confirm site or incident reference'),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'onyx agent page restores explicit primary pressure from thread memory state',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final seededState = <String, Object?>{
        'version': 7,
        'thread_counter': 1,
        'selected_thread_id': 'thread-1',
        'threads': <Object?>[
          <String, Object?>{
            'id': 'thread-1',
            'title': 'Signal watch',
            'summary': 'Keep the controller signal watch warm.',
            'memory': <String, Object?>{
              'last_primary_pressure': 'active signal watch',
              'last_recommendation_summary':
                  'Keep the controller signal watch warm.',
              'updated_at_utc': DateTime.utc(
                2026,
                3,
                31,
                8,
                22,
              ).toIso8601String(),
            },
            'messages': <Object?>[
              <String, Object?>{
                'id': 'msg-0',
                'kind': 'agent',
                'persona_id': 'main',
                'headline': 'Signal watch remains open',
                'body': 'Keep the controller signal watch warm.',
                'created_at_utc': DateTime.utc(
                  2026,
                  3,
                  31,
                  8,
                  20,
                ).toIso8601String(),
              },
            ],
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            sourceRouteLabel: 'Command',
            initialThreadSessionState: seededState,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('onyx-agent-thread-memory-banner')),
          matching: find.textContaining(
            'Primary pressure: active signal watch.',
          ),
        ),
        findsOneWidget,
      );
      final threadMemoryLabel = tester.widget<Text>(
        find.byKey(const ValueKey('onyx-agent-thread-memory-thread-1')),
      );
      expect(threadMemoryLabel.data, contains('primary signal watch'));
      expect(
        find.textContaining('Primary: active signal watch.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'onyx agent page surfaces replay specialist risk in thread memory and local brain context',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final seededState = <String, Object?>{
        'version': 7,
        'thread_counter': 1,
        'selected_thread_id': 'thread-1',
        'threads': <Object?>[
          <String, Object?>{
            'id': 'thread-1',
            'title': 'Signal watch',
            'summary': 'Keep the controller signal watch warm.',
            'memory': <String, Object?>{
              'last_primary_pressure': 'active signal watch',
              'last_recommendation_summary':
                  'Keep the controller signal watch warm.',
              'updated_at_utc': DateTime.utc(
                2026,
                3,
                31,
                8,
                22,
              ).toIso8601String(),
            },
            'messages': <Object?>[
              <String, Object?>{
                'id': 'msg-0',
                'kind': 'agent',
                'persona_id': 'main',
                'headline': 'Signal watch remains open',
                'body': 'Keep the controller signal watch warm.',
                'created_at_utc': DateTime.utc(
                  2026,
                  3,
                  31,
                  8,
                  20,
                ).toIso8601String(),
              },
            ],
          },
        ],
      };
      final localBrainService = _RecordingLocalBrainService();

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            sourceRouteLabel: 'Command',
            initialThreadSessionState: seededState,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            localBrainService: localBrainService,
            scenarioReplayHistorySignalService:
                const _FakeReplayHistorySignalService(
                  _promotedReplayConflictSignal,
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('onyx-agent-thread-memory-replay-history')),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Replay history: specialist conflict promoted low -> medium via scenario set/category policy.',
        ),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('onyx-agent-composer-field')),
        'Hold the thread on the highest-risk signal.',
      );
      await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
      await tester.pumpAndSettle();

      expect(
        localBrainService.lastContextSummary,
        contains(
          'Replay history: specialist conflict promoted low -> medium via scenario set/category policy.',
        ),
      );
      expect(
        localBrainService.lastContextSummary,
        contains('CCTV holds review while Track pushes tactical track.'),
      );
    },
  );

  testWidgets(
    'onyx agent page orders thread rail by stored primary pressure when urgent review is idle',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Map<String, Object?>? sessionState;
      final seededState = <String, Object?>{
        'version': 7,
        'thread_counter': 3,
        'selected_thread_id': 'thread-1',
        'threads': <Object?>[
          <String, Object?>{
            'id': 'thread-1',
            'title': 'Signal watch',
            'summary': 'Keep the controller signal watch warm.',
            'memory': <String, Object?>{
              'last_primary_pressure': 'active signal watch',
              'updated_at_utc': DateTime.utc(
                2026,
                3,
                31,
                8,
                20,
              ).toIso8601String(),
            },
            'messages': <Object?>[
              <String, Object?>{
                'id': 'msg-1',
                'kind': 'agent',
                'persona_id': 'main',
                'headline': 'Signal watch remains open',
                'body': 'Keep the controller signal watch warm.',
                'created_at_utc': DateTime.utc(
                  2026,
                  3,
                  31,
                  8,
                  20,
                ).toIso8601String(),
              },
            ],
          },
          <String, Object?>{
            'id': 'thread-2',
            'title': 'ETA still overdue',
            'summary': 'Controller follow-up is overdue.',
            'memory': <String, Object?>{
              'last_primary_pressure': 'overdue follow-up',
              'updated_at_utc': DateTime.utc(
                2026,
                3,
                31,
                8,
                21,
              ).toIso8601String(),
            },
            'messages': <Object?>[
              <String, Object?>{
                'id': 'msg-2',
                'kind': 'agent',
                'persona_id': 'dispatch',
                'headline': 'ETA recheck is overdue',
                'body': 'Follow up on the responder ETA now.',
                'created_at_utc': DateTime.utc(
                  2026,
                  3,
                  31,
                  8,
                  21,
                ).toIso8601String(),
              },
            ],
          },
          <String, Object?>{
            'id': 'thread-3',
            'title': 'Planner maintenance hot',
            'summary': 'Planner maintenance is the top pressure.',
            'memory': <String, Object?>{
              'last_primary_pressure': 'planner maintenance',
              'updated_at_utc': DateTime.utc(
                2026,
                3,
                31,
                8,
                22,
              ).toIso8601String(),
            },
            'messages': <Object?>[
              <String, Object?>{
                'id': 'msg-3',
                'kind': 'agent',
                'persona_id': 'policy',
                'headline': 'Planner maintenance remains active',
                'body': 'Keep the planner maintenance rule in view.',
                'created_at_utc': DateTime.utc(
                  2026,
                  3,
                  31,
                  8,
                  22,
                ).toIso8601String(),
              },
            ],
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            sourceRouteLabel: 'Command',
            initialThreadSessionState: seededState,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            onThreadSessionStateChanged: (state) {
              sessionState = state;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .getTopLeft(
              find.byKey(const ValueKey('onyx-agent-thread-thread-3')),
            )
            .dy,
        lessThan(
          tester
              .getTopLeft(
                find.byKey(const ValueKey('onyx-agent-thread-thread-2')),
              )
              .dy,
        ),
      );
      expect(
        tester
            .getTopLeft(
              find.byKey(const ValueKey('onyx-agent-thread-thread-2')),
            )
            .dy,
        lessThan(
          tester
              .getTopLeft(
                find.byKey(const ValueKey('onyx-agent-thread-thread-1')),
              )
              .dy,
        ),
      );
      expect(find.text('Planner maintenance remains active'), findsOneWidget);
      expect(find.text('Signal watch remains open'), findsNothing);
      expect(
        find.byKey(const ValueKey('onyx-agent-restored-pressure-banner')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('onyx-agent-thread-pressure-focus-thread-3')),
        findsOneWidget,
      );
      expect(
        find.text(
          'Restored over Signal watch because planner maintenance was stronger.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Restored the highest-pressure thread because planner maintenance outranked the previously saved Signal watch thread.',
        ),
        findsOneWidget,
      );
      expect(sessionState, isNotNull);
      final restoredState =
          jsonDecode(jsonEncode(sessionState)) as Map<String, dynamic>;
      expect(restoredState['selected_thread_id'], 'thread-3');
    },
  );

  testWidgets(
    'onyx agent page restores preview-only command continuity from shared surface memory',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final seededState = <String, Object?>{
        'version': 7,
        'thread_counter': 1,
        'selected_thread_id': 'thread-1',
        'threads': <Object?>[
          <String, Object?>{
            'id': 'thread-1',
            'title': 'Dispatch memory',
            'summary': 'Keep the dispatch lane warm.',
            'memory': <String, Object?>{
              'command_surface_memory': <String, Object?>{
                'commandPreview': <String, Object?>{
                  'eyebrow': 'ONYX ROUTED',
                  'headline': 'Dispatch Board is the next move',
                  'label': 'OPEN DISPATCH BOARD',
                  'summary': 'One next move is staged in Dispatch Board.',
                },
              },
              'updated_at_utc': DateTime.utc(
                2026,
                3,
                31,
                8,
                22,
              ).toIso8601String(),
            },
            'messages': <Object?>[
              <String, Object?>{
                'id': 'msg-1',
                'kind': 'agent',
                'persona_id': 'main',
                'headline': 'Dispatch memory',
                'body':
                    'Restored preview-only continuity for the dispatch lane.',
                'created_at_utc': DateTime.utc(
                  2026,
                  3,
                  31,
                  8,
                  22,
                ).toIso8601String(),
              },
            ],
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-CTRL-777',
            sourceRouteLabel: 'Command',
            initialThreadSessionState: seededState,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bannerLabel = tester.widget<Text>(
        find.byKey(const ValueKey('onyx-agent-thread-memory-banner-label')),
      );
      expect(
        bannerLabel.data,
        contains('One next move is staged in Dispatch Board.'),
      );
    },
  );

  testWidgets(
    'onyx agent page clears restored pressure focus cues after the first operator prompt',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final seededState = <String, Object?>{
        'version': 7,
        'thread_counter': 2,
        'selected_thread_id': 'thread-1',
        'threads': <Object?>[
          <String, Object?>{
            'id': 'thread-1',
            'title': 'Signal watch',
            'summary': 'Keep the controller signal watch warm.',
            'memory': <String, Object?>{
              'last_primary_pressure': 'active signal watch',
              'updated_at_utc': DateTime.utc(
                2026,
                3,
                31,
                8,
                20,
              ).toIso8601String(),
            },
            'messages': <Object?>[
              <String, Object?>{
                'id': 'msg-1',
                'kind': 'agent',
                'persona_id': 'main',
                'headline': 'Signal watch remains open',
                'body': 'Keep the controller signal watch warm.',
                'created_at_utc': DateTime.utc(
                  2026,
                  3,
                  31,
                  8,
                  20,
                ).toIso8601String(),
              },
            ],
          },
          <String, Object?>{
            'id': 'thread-2',
            'title': 'Planner maintenance hot',
            'summary': 'Planner maintenance is the top pressure.',
            'memory': <String, Object?>{
              'last_primary_pressure': 'planner maintenance',
              'updated_at_utc': DateTime.utc(
                2026,
                3,
                31,
                8,
                22,
              ).toIso8601String(),
            },
            'messages': <Object?>[
              <String, Object?>{
                'id': 'msg-2',
                'kind': 'agent',
                'persona_id': 'policy',
                'headline': 'Planner maintenance remains active',
                'body': 'Keep the planner maintenance rule in view.',
                'created_at_utc': DateTime.utc(
                  2026,
                  3,
                  31,
                  8,
                  22,
                ).toIso8601String(),
              },
            ],
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            sourceRouteLabel: 'Command',
            initialThreadSessionState: seededState,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('onyx-agent-restored-pressure-banner')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('onyx-agent-thread-pressure-focus-thread-2')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('onyx-agent-composer-field')),
        'What changed?',
      );
      await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('onyx-agent-restored-pressure-banner')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('onyx-agent-thread-pressure-focus-thread-2')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('onyx-agent-thread-pressure-note-thread-2')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'onyx agent page clears restored pressure focus cues after a direct resume route open',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      String? resumedTrackIncident;
      final seededState = <String, Object?>{
        'version': 7,
        'thread_counter': 2,
        'selected_thread_id': 'thread-1',
        'threads': <Object?>[
          <String, Object?>{
            'id': 'thread-1',
            'title': 'Signal watch',
            'summary': 'Keep the controller signal watch warm.',
            'memory': <String, Object?>{
              'last_primary_pressure': 'active signal watch',
              'updated_at_utc': DateTime.utc(
                2026,
                3,
                31,
                8,
                20,
              ).toIso8601String(),
            },
            'messages': <Object?>[
              <String, Object?>{
                'id': 'msg-1',
                'kind': 'agent',
                'persona_id': 'main',
                'headline': 'Signal watch remains open',
                'body': 'Keep the controller signal watch warm.',
                'created_at_utc': DateTime.utc(
                  2026,
                  3,
                  31,
                  8,
                  20,
                ).toIso8601String(),
              },
            ],
          },
          <String, Object?>{
            'id': 'thread-2',
            'title': 'Planner maintenance hot',
            'summary': 'Planner maintenance is the top pressure.',
            'memory': <String, Object?>{
              'last_primary_pressure': 'planner maintenance',
              'updated_at_utc': DateTime.utc(
                2026,
                3,
                31,
                8,
                22,
              ).toIso8601String(),
            },
            'messages': <Object?>[
              <String, Object?>{
                'id': 'msg-2',
                'kind': 'agent',
                'persona_id': 'policy',
                'headline': 'Planner maintenance remains active',
                'body': 'Keep the planner maintenance rule in view.',
                'created_at_utc': DateTime.utc(
                  2026,
                  3,
                  31,
                  8,
                  22,
                ).toIso8601String(),
              },
            ],
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-TRACK-101',
            sourceRouteLabel: 'Track',
            initialThreadSessionState: seededState,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            onOpenTrackForIncident: (incidentReference) {
              resumedTrackIncident = incidentReference;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('onyx-agent-restored-pressure-banner')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('onyx-agent-thread-pressure-focus-thread-2')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('onyx-agent-resume-track-button')),
      );
      await tester.pumpAndSettle();

      expect(resumedTrackIncident, 'INC-TRACK-101');
      expect(
        find.byKey(const ValueKey('onyx-agent-restored-pressure-banner')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('onyx-agent-thread-pressure-focus-thread-2')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('onyx-agent-thread-pressure-note-thread-2')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'onyx agent page clears restored pressure focus cues when the operator re-selects the restored thread',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final seededState = <String, Object?>{
        'version': 7,
        'thread_counter': 2,
        'selected_thread_id': 'thread-1',
        'threads': <Object?>[
          <String, Object?>{
            'id': 'thread-1',
            'title': 'Signal watch',
            'summary': 'Keep the controller signal watch warm.',
            'memory': <String, Object?>{
              'last_primary_pressure': 'active signal watch',
              'updated_at_utc': DateTime.utc(
                2026,
                3,
                31,
                8,
                20,
              ).toIso8601String(),
            },
            'messages': <Object?>[
              <String, Object?>{
                'id': 'msg-1',
                'kind': 'agent',
                'persona_id': 'main',
                'headline': 'Signal watch remains open',
                'body': 'Keep the controller signal watch warm.',
                'created_at_utc': DateTime.utc(
                  2026,
                  3,
                  31,
                  8,
                  20,
                ).toIso8601String(),
              },
            ],
          },
          <String, Object?>{
            'id': 'thread-2',
            'title': 'Planner maintenance hot',
            'summary': 'Planner maintenance is the top pressure.',
            'memory': <String, Object?>{
              'last_primary_pressure': 'planner maintenance',
              'updated_at_utc': DateTime.utc(
                2026,
                3,
                31,
                8,
                22,
              ).toIso8601String(),
            },
            'messages': <Object?>[
              <String, Object?>{
                'id': 'msg-2',
                'kind': 'agent',
                'persona_id': 'policy',
                'headline': 'Planner maintenance remains active',
                'body': 'Keep the planner maintenance rule in view.',
                'created_at_utc': DateTime.utc(
                  2026,
                  3,
                  31,
                  8,
                  22,
                ).toIso8601String(),
              },
            ],
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            sourceRouteLabel: 'Command',
            initialThreadSessionState: seededState,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('onyx-agent-restored-pressure-banner')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('onyx-agent-thread-pressure-focus-thread-2')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('onyx-agent-thread-thread-2')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('onyx-agent-restored-pressure-banner')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('onyx-agent-thread-pressure-focus-thread-2')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('onyx-agent-thread-pressure-note-thread-2')),
        findsNothing,
      );
    },
  );

  testWidgets('onyx agent page surfaces camera staging mode clearly', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: OnyxAgentPage(
          scopeClientId: 'CLIENT-001',
          scopeSiteId: 'SITE-SANDTON',
          focusIncidentReference: 'INC-STAGE-44',
          cameraBridgeStatus: OnyxAgentCameraBridgeStatus(
            enabled: true,
            running: true,
            authRequired: false,
            endpoint: Uri.parse('http://127.0.0.1:11634'),
            statusLabel: 'Live',
            detail:
                'Listening locally for approved camera execution packets and health probes through the embedded ONYX bridge.',
          ),
          cameraChangeService: _FakeSimulatedCameraChangeService(),
          cameraProbeService: _FakeCameraProbeService(),
          clientDraftService: _FakeClientDraftService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Camera control in staging mode'), findsWidgets);
    expect(
      find.byKey(const ValueKey('onyx-agent-camera-staging-indicator')),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'This scope is still in staging for live camera control.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'onyx agent page keeps operator focus note visible in compressed repeat replies',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final localBrainService = _RecordingLocalBrainService();
      final seededState = <String, Object?>{
        'version': 7,
        'thread_counter': 1,
        'selected_thread_id': 'thread-1',
        'threads': <Object?>[
          <String, Object?>{
            'id': 'thread-1',
            'title': 'What should I do next?',
            'summary': 'One next move is staged in Dispatch Board.',
            'memory': <String, Object?>{
              'last_recommendation_summary':
                  'One next move is staged in Dispatch Board.',
              'last_advisory':
                  'Scoped context is driving the next operator move.',
              'last_operator_focus_note':
                  'manual context preserved on What should I do next? while urgent review remains visible on Track drift warning.',
              'updated_at_utc': DateTime.utc(
                2026,
                3,
                31,
                8,
                22,
              ).toIso8601String(),
            },
            'messages': <Object?>[
              <String, Object?>{
                'id': 'msg-0',
                'kind': 'agent',
                'persona_id': 'main',
                'headline': 'Thread memory is warm',
                'body': 'Operator focus is already preserved on this thread.',
                'created_at_utc': DateTime.utc(
                  2026,
                  3,
                  31,
                  8,
                  20,
                ).toIso8601String(),
              },
              <String, Object?>{
                'id': 'msg-1',
                'kind': 'user',
                'persona_id': 'user',
                'headline': '',
                'body': 'Summarize the thread memory state again.',
                'created_at_utc': DateTime.utc(
                  2026,
                  3,
                  31,
                  8,
                  21,
                ).toIso8601String(),
              },
              <String, Object?>{
                'id': 'msg-2',
                'kind': 'agent',
                'persona_id': 'main',
                'headline': 'Local Model Brain',
                'body':
                    'Operator focus: manual context preserved on What should I do next? while urgent review remains visible on Track drift warning.',
                'created_at_utc': DateTime.utc(
                  2026,
                  3,
                  31,
                  8,
                  21,
                  30,
                ).toIso8601String(),
              },
              <String, Object?>{
                'id': 'msg-3',
                'kind': 'user',
                'persona_id': 'user',
                'headline': '',
                'body': 'Summarize the thread memory state again.',
                'created_at_utc': DateTime.utc(
                  2026,
                  3,
                  31,
                  8,
                  22,
                ).toIso8601String(),
              },
            ],
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-CTRL-891',
            sourceRouteLabel: 'Track',
            cloudAssistAvailable: false,
            initialThreadSessionState: seededState,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            localBrainService: localBrainService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('onyx-agent-composer-field')),
        'Summarize the thread memory state again.',
      );
      await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
      await tester.pumpAndSettle();

      expect(localBrainService.calls, 0);
      final compressedReply = find.textContaining(
        'No change from the last check.\nPrimary pressure: operator focus hold.\nOperator focus: manual context preserved on What should I do next? while urgent review remains visible on Track drift warning.',
      );
      final messageList = find.byKey(const ValueKey('onyx-agent-message-list'));
      for (
        var attempt = 0;
        attempt < 6 && compressedReply.evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(messageList, const Offset(0, -280));
        await tester.pumpAndSettle();
      }
      expect(compressedReply, findsOneWidget);
      expect(
        find.textContaining(
          'Scoped context is driving the next operator move.',
        ),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'onyx agent page auto-surfaces stale follow-ups when a thread is restored',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Map<String, Object?>? sessionState;
      Map<String, Object?>? restoredSessionState;
      final events = <DispatchEvent>[
        DecisionCreated(
          eventId: 'evt-1',
          sequence: 1,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 0),
          dispatchId: 'INC-42',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-SANDTON',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-42',
            sourceRouteLabel: 'Command',
            events: events,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            onThreadSessionStateChanged: (state) {
              sessionState = state;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('onyx-agent-composer-field')),
        'Status?',
      );
      await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
      await tester.pumpAndSettle();

      final messageList = find.byKey(const ValueKey('onyx-agent-message-list'));
      final followUpLabel = find.textContaining(
        'Next follow-up: RECHECK RESPONDER ETA',
      );
      for (
        var attempt = 0;
        attempt < 6 && followUpLabel.evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(messageList, const Offset(0, -220));
        await tester.pumpAndSettle();
      }

      expect(followUpLabel, findsWidgets);
      expect(sessionState, isNotNull);
      final staleSessionState =
          jsonDecode(jsonEncode(sessionState)) as Map<String, dynamic>;
      final restoredThreads = (staleSessionState['threads'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final memory = restoredThreads.first['memory'] as Map<String, dynamic>;
      memory['updated_at_utc'] = DateTime.now()
          .subtract(const Duration(minutes: 12))
          .toIso8601String();
      memory['last_operator_focus_note'] =
          'manual context preserved on What should I do next? while urgent review remains visible on Track drift warning.';
      memory.remove('last_auto_follow_up_surfaced_at_utc');

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-42',
            sourceRouteLabel: 'Command',
            events: events,
            initialThreadSessionState: staleSessionState
                .cast<String, Object?>(),
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            onThreadSessionStateChanged: (state) {
              restoredSessionState = state;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('onyx-agent-thread-memory-follow-up')),
        findsOneWidget,
      );
      expect(find.text('Proactive follow-up is still pending'), findsOneWidget);
      expect(find.text('RECHECK RESPONDER ETA'), findsWidgets);
      expect(
        find.textContaining('Primary pressure: overdue follow-up.'),
        findsNWidgets(2),
      );
      expect(
        find.textContaining(
          'Operator focus: manual context preserved on What should I do next? while urgent review remains visible on Track drift warning.',
        ),
        findsOneWidget,
      );

      expect(restoredSessionState, isNotNull);
      expect(
        jsonEncode(restoredSessionState),
        contains('last_auto_follow_up_surfaced_at_utc'),
      );
      expect(
        jsonEncode(restoredSessionState),
        contains('stale_follow_up_surface_count'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-42',
            sourceRouteLabel: 'Command',
            events: events,
            initialThreadSessionState: restoredSessionState!,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Proactive follow-up is still pending'), findsOneWidget);
    },
  );

  testWidgets(
    'onyx agent page does not duplicate stale follow-up surfacing on same-thread reselection',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Map<String, Object?>? sessionState;
      final seededState = <String, Object?>{
        'version': 7,
        'thread_counter': 1,
        'selected_thread_id': 'thread-1',
        'threads': <Object?>[
          <String, Object?>{
            'id': 'thread-1',
            'title': 'Delayed dispatch follow-up',
            'summary': 'Keep responder ETA in view.',
            'memory': <String, Object?>{
              'last_primary_pressure': 'overdue follow-up',
              'next_follow_up_label': 'RECHECK RESPONDER ETA',
              'next_follow_up_prompt':
                  'Check the responder ETA and confirm whether dispatch has arrived.',
              'pending_confirmations': <Object?>['responder ETA'],
              'last_advisory': 'Response delay detected.',
              'updated_at_utc': DateTime.now()
                  .subtract(const Duration(minutes: 12))
                  .toIso8601String(),
            },
            'messages': <Object?>[
              <String, Object?>{
                'id': 'msg-1',
                'kind': 'agent',
                'persona_id': 'dispatch',
                'headline': 'Response delay detected',
                'body':
                    'Response ETA has stretched beyond the expected window.',
                'created_at_utc': DateTime.now()
                    .subtract(const Duration(minutes: 12))
                    .toIso8601String(),
              },
            ],
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-42',
            sourceRouteLabel: 'Command',
            initialThreadSessionState: seededState,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            onThreadSessionStateChanged: (state) {
              sessionState = state;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Proactive follow-up is still pending'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('onyx-agent-thread-thread-1')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Proactive follow-up is still pending'), findsOneWidget);
      expect(sessionState, isNotNull);
      final restoredState =
          jsonDecode(jsonEncode(sessionState)) as Map<String, dynamic>;
      final threads = (restoredState['threads'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final memory = threads.first['memory'] as Map<String, dynamic>;
      expect(memory['stale_follow_up_surface_count'], 1);
    },
  );

  testWidgets(
    'onyx agent page auto-surfaces stale follow-ups after the timer elapses without a restore',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Map<String, Object?>? sessionState;
      final seededState = <String, Object?>{
        'version': 7,
        'thread_counter': 1,
        'selected_thread_id': 'thread-1',
        'threads': <Object?>[
          <String, Object?>{
            'id': 'thread-1',
            'title': 'Delayed dispatch follow-up',
            'summary': 'Keep responder ETA in view.',
            'memory': <String, Object?>{
              'last_primary_pressure': 'overdue follow-up',
              'next_follow_up_label': 'RECHECK RESPONDER ETA',
              'next_follow_up_prompt':
                  'Check the responder ETA and confirm whether dispatch has arrived.',
              'pending_confirmations': <Object?>['responder ETA'],
              'last_advisory': 'Response delay detected.',
              'updated_at_utc': DateTime.now()
                  .subtract(const Duration(minutes: 4, seconds: 58))
                  .toIso8601String(),
            },
            'messages': <Object?>[
              <String, Object?>{
                'id': 'msg-1',
                'kind': 'agent',
                'persona_id': 'dispatch',
                'headline': 'Response delay detected',
                'body':
                    'Response ETA has stretched beyond the expected window.',
                'created_at_utc': DateTime.now()
                    .subtract(const Duration(minutes: 4, seconds: 58))
                    .toIso8601String(),
              },
            ],
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-42',
            sourceRouteLabel: 'Command',
            initialThreadSessionState: seededState,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            onThreadSessionStateChanged: (state) {
              sessionState = state;
            },
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Proactive follow-up is still pending'), findsNothing);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump();

      expect(find.text('Proactive follow-up is still pending'), findsOneWidget);
      expect(find.text('RECHECK RESPONDER ETA'), findsWidgets);
      expect(sessionState, isNotNull);
      final timedState =
          jsonDecode(jsonEncode(sessionState)) as Map<String, dynamic>;
      final timedThreads = (timedState['threads'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final timedMemory = timedThreads.first['memory'] as Map<String, dynamic>;
      expect(timedMemory['stale_follow_up_surface_count'], 1);
      expect(timedMemory, contains('last_auto_follow_up_surfaced_at_utc'));
    },
  );

  testWidgets(
    'onyx agent page escalates ignored stale follow-ups across repeated restores',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Map<String, Object?>? sessionState;
      Map<String, Object?>? firstRestoredSessionState;
      Map<String, Object?>? secondRestoredSessionState;
      Map<String, Object?>? thirdRestoredSessionState;
      final events = <DispatchEvent>[
        DecisionCreated(
          eventId: 'evt-1',
          sequence: 1,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 0),
          dispatchId: 'INC-42',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-SANDTON',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-42',
            sourceRouteLabel: 'Command',
            events: events,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            onThreadSessionStateChanged: (state) {
              sessionState = state;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('onyx-agent-composer-field')),
        'Status?',
      );
      await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
      await tester.pumpAndSettle();

      final staleSessionState =
          jsonDecode(jsonEncode(sessionState)) as Map<String, dynamic>;
      final staleThreads = (staleSessionState['threads'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final staleMemory = staleThreads.first['memory'] as Map<String, dynamic>;
      staleMemory['updated_at_utc'] = DateTime.now()
          .subtract(const Duration(minutes: 24))
          .toIso8601String();
      staleMemory.remove('last_auto_follow_up_surfaced_at_utc');
      staleMemory.remove('stale_follow_up_surface_count');

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-42',
            sourceRouteLabel: 'Command',
            events: events,
            initialThreadSessionState: staleSessionState
                .cast<String, Object?>(),
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            onThreadSessionStateChanged: (state) {
              firstRestoredSessionState = state;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Proactive follow-up is still pending'), findsOneWidget);
      expect(firstRestoredSessionState, isNotNull);
      final firstThreads =
          (firstRestoredSessionState!['threads'] as List<dynamic>)
              .cast<Map<String, dynamic>>();
      final firstMemory = firstThreads.first['memory'] as Map<String, dynamic>;
      expect(firstMemory['stale_follow_up_surface_count'], 1);

      final secondStaleSessionState =
          jsonDecode(jsonEncode(firstRestoredSessionState))
              as Map<String, dynamic>;
      final secondThreads =
          (secondStaleSessionState['threads'] as List<dynamic>)
              .cast<Map<String, dynamic>>();
      final secondMemory =
          secondThreads.first['memory'] as Map<String, dynamic>;
      secondMemory['last_auto_follow_up_surfaced_at_utc'] = DateTime.now()
          .subtract(const Duration(minutes: 16))
          .toIso8601String();

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-42',
            sourceRouteLabel: 'Command',
            events: events,
            initialThreadSessionState: secondStaleSessionState
                .cast<String, Object?>(),
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            onThreadSessionStateChanged: (state) {
              secondRestoredSessionState = state;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Follow-up is still unresolved'), findsOneWidget);
      expect(secondRestoredSessionState, isNotNull);
      final secondRestoredThreads =
          (secondRestoredSessionState!['threads'] as List<dynamic>)
              .cast<Map<String, dynamic>>();
      final secondRestoredMemory =
          secondRestoredThreads.first['memory'] as Map<String, dynamic>;
      expect(secondRestoredMemory['stale_follow_up_surface_count'], 2);

      final thirdStaleSessionState =
          jsonDecode(jsonEncode(secondRestoredSessionState))
              as Map<String, dynamic>;
      final thirdThreads = (thirdStaleSessionState['threads'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final thirdMemory = thirdThreads.first['memory'] as Map<String, dynamic>;
      thirdMemory['last_auto_follow_up_surfaced_at_utc'] = DateTime.now()
          .subtract(const Duration(minutes: 16))
          .toIso8601String();

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-42',
            sourceRouteLabel: 'Command',
            events: events,
            initialThreadSessionState: thirdStaleSessionState
                .cast<String, Object?>(),
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            onThreadSessionStateChanged: (state) {
              thirdRestoredSessionState = state;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Escalation follow-up is now overdue'), findsOneWidget);
      expect(thirdRestoredSessionState, isNotNull);
      final thirdRestoredThreads =
          (thirdRestoredSessionState!['threads'] as List<dynamic>)
              .cast<Map<String, dynamic>>();
      final thirdRestoredMemory =
          thirdRestoredThreads.first['memory'] as Map<String, dynamic>;
      expect(thirdRestoredMemory['stale_follow_up_surface_count'], 3);
    },
  );

  testWidgets(
    'onyx agent page uses overdue thread follow-up memory in the next typed recommendation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Map<String, Object?>? sessionState;
      final seededEvents = <DispatchEvent>[
        DecisionCreated(
          eventId: 'evt-1',
          sequence: 1,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 0),
          dispatchId: 'INC-42',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-SANDTON',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-42',
            sourceRouteLabel: 'Command',
            events: seededEvents,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            onThreadSessionStateChanged: (state) {
              sessionState = state;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('onyx-agent-composer-field')),
        'Status?',
      );
      await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
      await tester.pumpAndSettle();

      final staleSessionState =
          jsonDecode(jsonEncode(sessionState)) as Map<String, dynamic>;
      final staleThreads = (staleSessionState['threads'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final staleMemory = staleThreads.first['memory'] as Map<String, dynamic>;
      staleMemory['updated_at_utc'] = DateTime.now()
          .subtract(const Duration(minutes: 26))
          .toIso8601String();
      staleMemory['last_auto_follow_up_surfaced_at_utc'] = DateTime.now()
          .subtract(const Duration(minutes: 16))
          .toIso8601String();
      staleMemory['stale_follow_up_surface_count'] = 2;

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-42',
            sourceRouteLabel: 'Command',
            events: const <DispatchEvent>[],
            initialThreadSessionState: staleSessionState
                .cast<String, Object?>(),
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('onyx-agent-composer-field')),
        'What should I do next?',
      );
      await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
      await tester.pumpAndSettle();

      final messageList = find.byKey(const ValueKey('onyx-agent-message-list'));
      final overdueAdvisory = find.textContaining(
        'Advisory: Outstanding follow-up is overdue.',
      );
      for (
        var attempt = 0;
        attempt < 6 && overdueAdvisory.evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(messageList, const Offset(0, -240));
        await tester.pumpAndSettle();
      }

      expect(find.text('Dispatch Board is the next move'), findsOneWidget);
      expect(overdueAdvisory, findsOneWidget);
      expect(
        find.descendant(
          of: messageList,
          matching: find.textContaining('Primary pressure: overdue follow-up.'),
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Context: Outstanding follow-up: RECHECK RESPONDER ETA',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Next follow-up: RECHECK RESPONDER ETA'),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'onyx agent page prioritizes the highest-risk site during cross-site triage',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final events = <DispatchEvent>[
        IntelligenceReceived(
          eventId: 'evt-1',
          sequence: 1,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 0),
          intelligenceId: 'intel-1',
          provider: 'vision',
          sourceType: 'cctv',
          externalId: 'vision-1',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-A',
          cameraId: 'CAM-1',
          headline: 'Tree motion near the outer fence',
          summary: 'Low-risk movement matched previous wind noise.',
          riskScore: 19,
          canonicalHash: 'hash-1',
        ),
        DecisionCreated(
          eventId: 'evt-2',
          sequence: 2,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 1),
          dispatchId: 'INC-900',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-B',
        ),
        IntelligenceReceived(
          eventId: 'evt-3',
          sequence: 3,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 2),
          intelligenceId: 'intel-2',
          provider: 'vision',
          sourceType: 'cctv',
          externalId: 'vision-2',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-B',
          cameraId: 'CAM-9',
          headline: 'Confirmed breach at the north gate',
          summary:
              'Two intruders crossed the perimeter and dispatch is staging.',
          riskScore: 96,
          canonicalHash: 'hash-2',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            sourceRouteLabel: 'Operations',
            events: events,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('onyx-agent-composer-field')),
        "What's happening across sites?",
      );
      await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
      await tester.pumpAndSettle();

      final messageList = find.byKey(const ValueKey('onyx-agent-message-list'));
      final summary = find.textContaining(
        'One next move is staged in Tactical Track.',
      );
      for (
        var attempt = 0;
        attempt < 6 && summary.evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(messageList, const Offset(0, -280));
        await tester.pumpAndSettle();
      }

      expect(summary, findsWidgets);
      final advisory = find.textContaining(
        'Advisory: Prioritize SITE-B first.',
      );
      for (
        var attempt = 0;
        attempt < 4 && advisory.evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(messageList, const Offset(0, -220));
        await tester.pumpAndSettle();
      }
      expect(advisory, findsOneWidget);
      expect(find.textContaining('SITE-B'), findsWidgets);
      expect(
        find.textContaining(
          'Context: 1. SITE-B — Confirmed breach at the north gate (risk 96)',
        ),
        findsOneWidget,
      );
      expect(find.text('RECHECK LOWER-PRIORITY SITES'), findsWidgets);
    },
  );

  testWidgets(
    'onyx agent page escalates guard welfare distress through typed triage',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      String? openedDispatchIncident;
      final events = <DispatchEvent>[
        DecisionCreated(
          eventId: 'evt-1',
          sequence: 1,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 0),
          dispatchId: 'INC-42',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-SANDTON',
        ),
        IntelligenceReceived(
          eventId: 'evt-2',
          sequence: 2,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 2),
          intelligenceId: 'intel-2',
          provider: 'wearable',
          sourceType: 'wearable telemetry',
          externalId: 'wearable-1',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-SANDTON',
          headline: 'Guard distress pattern from wearable telemetry',
          summary: 'No movement plus heart rate spike for Guard 9.',
          riskScore: 91,
          canonicalHash: 'hash-2',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-42',
            sourceRouteLabel: 'Track',
            events: events,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            onOpenAlarmsForIncident: (incidentReference) {
              openedDispatchIncident = incidentReference;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('onyx-agent-composer-field')),
        'Status guard?',
      );
      await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
      await tester.pumpAndSettle();

      final messageList = find.byKey(const ValueKey('onyx-agent-message-list'));
      final summary = find.textContaining(
        'One next move is staged in Dispatch Board.',
      );
      for (
        var attempt = 0;
        attempt < 6 && summary.evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(messageList, const Offset(0, -280));
        await tester.pumpAndSettle();
      }

      expect(summary, findsWidgets);
      final advisory = find.textContaining(
        'Advisory: Possible guard distress detected.',
      );
      for (
        var attempt = 0;
        attempt < 4 && advisory.evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(messageList, const Offset(0, -220));
        await tester.pumpAndSettle();
      }
      expect(advisory, findsOneWidget);
      final missingInfo = find.textContaining(
        'Missing info: guard voice confirmation',
      );
      for (
        var attempt = 0;
        attempt < 4 && missingInfo.evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(messageList, const Offset(0, -220));
        await tester.pumpAndSettle();
      }
      expect(missingInfo, findsOneWidget);

      final executeNextMove = find.widgetWithText(OutlinedButton, 'Do this');
      await tester.ensureVisible(executeNextMove);
      await tester.tap(executeNextMove);
      await tester.pumpAndSettle();

      expect(openedDispatchIncident, 'INC-42');
    },
  );

  testWidgets(
    'onyx agent page uses scoped field context to prefer Tactical Track during typed triage',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final localBrainService = _RecordingLocalBrainService();
      String? openedTrackIncident;
      final events = <DispatchEvent>[
        DecisionCreated(
          eventId: 'evt-1',
          sequence: 1,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 0),
          dispatchId: 'INC-CTRL-888',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-SANDTON',
        ),
        ResponseArrived(
          eventId: 'evt-2',
          sequence: 2,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 4),
          dispatchId: 'INC-CTRL-888',
          guardId: 'GUARD-9',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-SANDTON',
        ),
        PatrolCompleted(
          eventId: 'evt-3',
          sequence: 3,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 6),
          guardId: 'GUARD-9',
          routeId: 'ROUTE-ALPHA',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-SANDTON',
          durationSeconds: 960,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-CTRL-888',
            sourceRouteLabel: 'Track',
            events: events,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            localBrainService: localBrainService,
            onOpenTrackForIncident: (incidentReference) {
              openedTrackIncident = incidentReference;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('onyx-agent-composer-field')),
        'Triage the active incident and stage one obvious next move',
      );
      await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
      await tester.pumpAndSettle();

      final messageList = find.byKey(const ValueKey('onyx-agent-message-list'));
      final triageSummary = find.textContaining(
        'One next move is staged in Tactical Track.',
      );
      for (
        var attempt = 0;
        attempt < 5 && triageSummary.evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(messageList, const Offset(0, -280));
        await tester.pumpAndSettle();
      }

      expect(localBrainService.calls, 0);
      expect(triageSummary, findsWidgets);

      final executeNextMove = find.widgetWithText(OutlinedButton, 'Do this');
      for (
        var attempt = 0;
        attempt < 5 && executeNextMove.evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(messageList, const Offset(0, -280));
        await tester.pumpAndSettle();
      }
      expect(executeNextMove, findsOneWidget);
      final executeNextMoveButton = tester.widget<OutlinedButton>(
        executeNextMove,
      );
      executeNextMoveButton.onPressed!.call();
      await tester.pumpAndSettle();

      expect(openedTrackIncident, 'INC-CTRL-888');
      expect(
        find.textContaining('Tactical Track handoff sealed.'),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'onyx agent page lets replay conflict bias typed triage into CCTV review',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final localBrainService = _RecordingLocalBrainService();
      String? openedTrackIncident;
      String? openedCctvIncident;
      final events = <DispatchEvent>[
        DecisionCreated(
          eventId: 'evt-1',
          sequence: 1,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 0),
          dispatchId: 'INC-CTRL-889',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-SANDTON',
        ),
        ResponseArrived(
          eventId: 'evt-2',
          sequence: 2,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 4),
          dispatchId: 'INC-CTRL-889',
          guardId: 'GUARD-9',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-SANDTON',
        ),
        PatrolCompleted(
          eventId: 'evt-3',
          sequence: 3,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 6),
          guardId: 'GUARD-9',
          routeId: 'ROUTE-ALPHA',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-SANDTON',
          durationSeconds: 960,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-CTRL-889',
            sourceRouteLabel: 'Track',
            events: events,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            localBrainService: localBrainService,
            scenarioReplayHistorySignalService:
                const _FakeReplayHistorySignalService(
                  _promotedReplayConflictSignal,
                ),
            onOpenTrackForIncident: (incidentReference) {
              openedTrackIncident = incidentReference;
            },
            onOpenCctvForIncident: (incidentReference) {
              openedCctvIncident = incidentReference;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('onyx-agent-composer-field')),
        'Triage the active incident and stage one obvious next move',
      );
      await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
      await tester.pumpAndSettle();

      final messageList = find.byKey(const ValueKey('onyx-agent-message-list'));
      final replaySummary = find.textContaining(
        'Replay priority keeps CCTV Review in front',
      );
      for (
        var attempt = 0;
        attempt < 5 && replaySummary.evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(messageList, const Offset(0, -280));
        await tester.pumpAndSettle();
      }

      expect(localBrainService.calls, 0);
      expect(replaySummary, findsWidgets);
      expect(openedCctvIncident, isNull);
      expect(openedTrackIncident, isNull);
    },
  );

  testWidgets(
    'onyx agent page lets sequence fallback bias typed triage into tactical track without phantom conflict copy',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final localBrainService = _RecordingLocalBrainService();
      String? openedTrackIncident;
      String? openedCctvIncident;
      final events = <DispatchEvent>[
        DecisionCreated(
          eventId: 'evt-seq-1',
          sequence: 1,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 0),
          dispatchId: 'INC-CTRL-990',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-SANDTON',
        ),
        ResponseArrived(
          eventId: 'evt-seq-2',
          sequence: 2,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 4),
          dispatchId: 'INC-CTRL-990',
          guardId: 'GUARD-9',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-SANDTON',
        ),
        PatrolCompleted(
          eventId: 'evt-seq-3',
          sequence: 3,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 6),
          guardId: 'GUARD-9',
          routeId: 'ROUTE-ALPHA',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-SANDTON',
          durationSeconds: 960,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-CTRL-990',
            sourceRouteLabel: 'Track',
            events: events,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            localBrainService: localBrainService,
            scenarioReplayHistorySignalService:
                const _FakeReplayHistorySignalService(
                  _sequenceFallbackReplaySignal,
                ),
            onOpenTrackForIncident: (incidentReference) {
              openedTrackIncident = incidentReference;
            },
            onOpenCctvForIncident: (incidentReference) {
              openedCctvIncident = incidentReference;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('onyx-agent-composer-field')),
        'Triage the active incident and stage one obvious next move',
      );
      await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
      await tester.pumpAndSettle();

      final messageList = find.byKey(const ValueKey('onyx-agent-message-list'));
      final replaySummary = find.textContaining(
        'Replay priority keeps Tactical Track in front while sequence fallback stays active.',
      );
      for (
        var attempt = 0;
        attempt < 5 && replaySummary.evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(messageList, const Offset(0, -280));
        await tester.pumpAndSettle();
      }

      expect(localBrainService.calls, 0);
      expect(replaySummary, findsWidgets);
      expect(
        find.textContaining(
          'Replay history: sequence fallback low. Dispatch was unavailable, so ONYX kept the live-ops sequence moving in Tactical Track.',
        ),
        findsWidgets,
      );
      expect(
        find.textContaining('unresolved specialist conflict'),
        findsNothing,
      );
      expect(openedCctvIncident, isNull);
      expect(openedTrackIncident, isNull);
    },
  );

  testWidgets(
    'onyx agent page frames promoted sequence fallback as replay policy escalation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final localBrainService = _RecordingLocalBrainService();
      final events = <DispatchEvent>[
        DecisionCreated(
          eventId: 'evt-seq-critical-1',
          sequence: 1,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 0),
          dispatchId: 'INC-CTRL-991',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-SANDTON',
        ),
        ResponseArrived(
          eventId: 'evt-seq-critical-2',
          sequence: 2,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 4),
          dispatchId: 'INC-CTRL-991',
          guardId: 'GUARD-9',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-SANDTON',
        ),
        PatrolCompleted(
          eventId: 'evt-seq-critical-3',
          sequence: 3,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 6),
          guardId: 'GUARD-9',
          routeId: 'ROUTE-ALPHA',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-SANDTON',
          durationSeconds: 960,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-CTRL-991',
            sourceRouteLabel: 'Track',
            events: events,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            localBrainService: localBrainService,
            scenarioReplayHistorySignalService:
                const _FakeReplayHistorySignalService(
                  _promotedSequenceFallbackReplaySignal,
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('onyx-agent-composer-field')),
        'Triage the active incident and stage one obvious next move',
      );
      await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
      await tester.pumpAndSettle();

      final messageList = find.byKey(const ValueKey('onyx-agent-message-list'));
      final replaySummary = find.textContaining(
        'Replay policy escalation keeps Tactical Track in front while sequence fallback stays active.',
      );
      for (
        var attempt = 0;
        attempt < 5 && replaySummary.evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(messageList, const Offset(0, -280));
        await tester.pumpAndSettle();
      }

      expect(localBrainService.calls, 0);
      expect(replaySummary, findsWidgets);
      expect(
        find.textContaining(
          'Replay history: sequence fallback promoted high -> critical via scenario set/scenario policy. Dispatch was unavailable, so ONYX kept the live-ops sequence moving in Tactical Track.',
        ),
        findsWidgets,
      );
      expect(
        find.textContaining(
          'Replay policy is still holding the safer sequence fallback.',
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'onyx agent page carries ordered replay pressure stack into command explanation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final localBrainService = _RecordingLocalBrainService();
      final events = <DispatchEvent>[
        DecisionCreated(
          eventId: 'evt-seq-stack-1',
          sequence: 1,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 0),
          dispatchId: 'INC-CTRL-992',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-SANDTON',
        ),
        ResponseArrived(
          eventId: 'evt-seq-stack-2',
          sequence: 2,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 4),
          dispatchId: 'INC-CTRL-992',
          guardId: 'GUARD-9',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-SANDTON',
        ),
        PatrolCompleted(
          eventId: 'evt-seq-stack-3',
          sequence: 3,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 6),
          guardId: 'GUARD-9',
          routeId: 'ROUTE-ALPHA',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-SANDTON',
          durationSeconds: 960,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-CTRL-992',
            sourceRouteLabel: 'Track',
            events: events,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            localBrainService: localBrainService,
            scenarioReplayHistorySignalService:
                const _FakeReplayHistorySignalService(
                  _promotedSequenceFallbackReplaySignal,
                  signalStack: <ScenarioReplayHistorySignal>[
                    _promotedSequenceFallbackReplaySignal,
                    _promotedReplayConflictSignal,
                  ],
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('onyx-agent-composer-field')),
        'Triage the active incident and stage one obvious next move',
      );
      await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
      await tester.pumpAndSettle();

      final messageList = find.byKey(const ValueKey('onyx-agent-message-list'));
      final replaySummary = find.textContaining(
        'Secondary replay pressure: Replay history: specialist conflict promoted low -> medium via scenario set/category policy.',
      );
      for (
        var attempt = 0;
        attempt < 5 && replaySummary.evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(messageList, const Offset(0, -280));
        await tester.pumpAndSettle();
      }

      expect(localBrainService.calls, 0);
      expect(replaySummary, findsWidgets);
      expect(
        find.textContaining(
          'Primary replay pressure: Replay history: sequence fallback promoted high -> critical via scenario set/scenario policy.',
        ),
        findsWidgets,
      );
      expect(
        find.textContaining(
          'Primary replay pressure: Replay policy escalation: Replay history: sequence fallback promoted high -> critical via scenario set/scenario policy.',
        ),
        findsWidgets,
      );
      expect(
        find.textContaining(
          'Replay policy escalation keeps Tactical Track in front while sequence fallback stays active.',
        ),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'onyx agent page explains when typed triage overrules OpenAI second look',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final cloudBoostService = _RecordingCloudBoostService();
      Map<String, Object?>? sessionState;
      final events = <DispatchEvent>[
        DecisionCreated(
          eventId: 'evt-1',
          sequence: 1,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 0),
          dispatchId: 'INC-CTRL-889',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-SANDTON',
        ),
        ResponseArrived(
          eventId: 'evt-2',
          sequence: 2,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 4),
          dispatchId: 'INC-CTRL-889',
          guardId: 'GUARD-9',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-SANDTON',
        ),
        PatrolCompleted(
          eventId: 'evt-3',
          sequence: 3,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 6),
          guardId: 'GUARD-9',
          routeId: 'ROUTE-ALPHA',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-SANDTON',
          durationSeconds: 960,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-CTRL-889',
            sourceRouteLabel: 'Track',
            cloudAssistAvailable: true,
            events: events,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            localBrainService: _FakeLocalBrainService(),
            cloudBoostService: cloudBoostService,
            onThreadSessionStateChanged: (state) {
              sessionState = state;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cloudAssistToggle = find.byKey(
        const ValueKey('onyx-agent-cloud-boost-toggle'),
      );
      await tester.ensureVisible(cloudAssistToggle);
      await tester.pumpAndSettle();
      await tester.tap(cloudAssistToggle);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('onyx-agent-composer-field')),
        'Triage the active incident and stage one obvious next move',
      );
      await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
      await tester.pumpAndSettle();

      expect(cloudBoostService.calls, 1);
      expect(
        cloudBoostService.lastContextSummary,
        contains('Typed triage recommendation: desk=tacticalTrack'),
      );

      final messageList = find.byKey(const ValueKey('onyx-agent-message-list'));
      final triageSummary = find.textContaining(
        'One next move is staged in Tactical Track.',
      );
      for (
        var attempt = 0;
        attempt < 6 && triageSummary.evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(messageList, const Offset(0, -280));
        await tester.pumpAndSettle();
      }
      expect(triageSummary, findsWidgets);

      final conflictHeadline = find.text(
        'Typed triage overruled the model suggestion',
      );
      for (
        var attempt = 0;
        attempt < 6 && conflictHeadline.evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(messageList, const Offset(0, -280));
        await tester.pumpAndSettle();
      }

      expect(conflictHeadline, findsOneWidget);
      expect(
        find.textContaining(
          'Typed triage kept Tactical Track as the active desk.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'OpenAI second look suggested CCTV Review instead.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Winner: typed triage. Live field posture rules kept Tactical Track authoritative for this handoff.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('onyx-agent-second-look-telemetry')),
        findsOneWidget,
      );
      expect(
        find.textContaining('1 second-look disagreement recorded.'),
        findsWidgets,
      );
      expect(
        find.textContaining(
          'OpenAI second look: kept Tactical Track over CCTV Review.',
        ),
        findsWidgets,
      );
      expect(
        find.textContaining('Last recommendation: Tactical Track.'),
        findsOneWidget,
      );
      final persistedState =
          jsonDecode(jsonEncode(sessionState)) as Map<String, dynamic>;
      final persistedThreads = (persistedState['threads'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final persistedMemory =
          persistedThreads.first['memory'] as Map<String, dynamic>;
      expect(persistedMemory['second_look_conflict_count'], 1);
      expect(
        persistedMemory['last_second_look_conflict_summary'],
        contains('kept Tactical Track over CCTV Review.'),
      );
    },
  );

  testWidgets(
    'onyx agent page surfaces replay bias stack drift without inventing a tertiary stack slot',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final localBrainService = _RecordingLocalBrainService();
      final events = <DispatchEvent>[
        DecisionCreated(
          eventId: 'evt-stack-drift-1',
          sequence: 1,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 0),
          dispatchId: 'INC-CTRL-993',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-SANDTON',
        ),
        ResponseArrived(
          eventId: 'evt-stack-drift-2',
          sequence: 2,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 4),
          dispatchId: 'INC-CTRL-993',
          guardId: 'GUARD-9',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-SANDTON',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-CTRL-993',
            sourceRouteLabel: 'Track',
            events: events,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            localBrainService: localBrainService,
            scenarioReplayHistorySignalService:
                const _FakeReplayHistorySignalService(
                  _stackedSequenceFallbackReplaySignal,
                  signalStack: <ScenarioReplayHistorySignal>[
                    _stackedSequenceFallbackReplaySignal,
                    _stackedReplayConflictSignal,
                    _replayBiasStackDriftSignal,
                  ],
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('onyx-agent-composer-field')),
        'Triage the active incident and stage one obvious next move',
      );
      await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
      await tester.pumpAndSettle();

      final messageList = find.byKey(const ValueKey('onyx-agent-message-list'));
      final driftSummary = find.textContaining(
        'Replay history: replay bias stack drift critical.',
      );
      for (
        var attempt = 0;
        attempt < 5 && driftSummary.evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(messageList, const Offset(0, -280));
        await tester.pumpAndSettle();
      }

      expect(
        find.textContaining(
          'Primary replay pressure: Replay history: sequence fallback low.',
        ),
        findsWidgets,
      );
      expect(
        find.textContaining(
          'Secondary replay pressure: Replay history: specialist conflict promoted low -> medium.',
        ),
        findsWidgets,
      );
      expect(driftSummary, findsWidgets);
      expect(
        find.textContaining(
          'Previous pressure: Primary replay pressure: sequence fallback -> Tactical Track.',
        ),
        findsWidgets,
      );
      expect(
        find.textContaining(
          'Latest pressure: Primary replay pressure: sequence fallback -> Tactical Track. Secondary replay pressure: specialist conflict -> CCTV Review.',
        ),
        findsWidgets,
      );
      expect(find.textContaining('Tertiary replay pressure'), findsNothing);
    },
  );

  testWidgets(
    'onyx agent page restores replay bias stack drift from thread memory when live replay history is unavailable',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Map<String, Object?>? sessionState;
      final seedLocalBrainService = _RecordingLocalBrainService();
      final restoreLocalBrainService = _RecordingLocalBrainService();
      final events = <DispatchEvent>[
        DecisionCreated(
          eventId: 'evt-stack-drift-restore-1',
          sequence: 1,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 0),
          dispatchId: 'INC-CTRL-994',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-SANDTON',
        ),
        ResponseArrived(
          eventId: 'evt-stack-drift-restore-2',
          sequence: 2,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 4),
          dispatchId: 'INC-CTRL-994',
          guardId: 'GUARD-9',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-SANDTON',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-CTRL-994',
            sourceRouteLabel: 'Track',
            events: events,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            localBrainService: seedLocalBrainService,
            onThreadSessionStateChanged: (state) {
              sessionState = state;
            },
            scenarioReplayHistorySignalService:
                const _FakeReplayHistorySignalService(
                  _stackedSequenceFallbackReplaySignal,
                  signalStack: <ScenarioReplayHistorySignal>[
                    _stackedSequenceFallbackReplaySignal,
                    _stackedReplayConflictSignal,
                    _replayBiasStackDriftSignal,
                  ],
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('onyx-agent-composer-field')),
        'Triage the active incident and stage one obvious next move',
      );
      await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
      await tester.pumpAndSettle();

      expect(sessionState, isNotNull);
      final persistedState =
          jsonDecode(jsonEncode(sessionState)) as Map<String, dynamic>;
      final persistedThreads = (persistedState['threads'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final persistedMemory =
          persistedThreads.first['memory'] as Map<String, dynamic>;
      final persistedCommandSurfaceMemory =
          persistedMemory['command_surface_memory'] as Map<String, dynamic>;
      expect(persistedMemory['last_replay_history_summary'], isNull);
      expect(
        persistedCommandSurfaceMemory['replayHistorySummary'],
        contains('Replay history: replay bias stack drift critical.'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-CTRL-994',
            sourceRouteLabel: 'Track',
            events: events,
            initialThreadSessionState: persistedState.cast<String, Object?>(),
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            localBrainService: restoreLocalBrainService,
            scenarioReplayHistorySignalService:
                const _FakeReplayHistorySignalService(null),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('onyx-agent-thread-memory-replay-history')),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Replay history: replay bias stack drift critical.',
        ),
        findsWidgets,
      );
      final threadMemoryBannerLabel = tester.widget<Text>(
        find.byKey(const ValueKey('onyx-agent-thread-memory-banner-label')),
      );
      expect(
        threadMemoryBannerLabel.data,
        contains(
          'Remembered replay continuity: Primary replay pressure: Replay history: sequence fallback low.',
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey('onyx-agent-composer-field')),
        'Summarize the thread memory state again.',
      );
      await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
      await tester.pumpAndSettle();

      expect(restoreLocalBrainService.calls, 1);
      expect(
        restoreLocalBrainService.lastContextSummary,
        contains('Replay history: replay bias stack drift critical.'),
      );
      expect(
        restoreLocalBrainService.lastContextSummary,
        contains(
          'Latest pressure: Primary replay pressure: sequence fallback -> Tactical Track. Secondary replay pressure: specialist conflict -> CCTV Review.',
        ),
      );
    },
  );

  testWidgets(
    'onyx agent page lets the command brain corroborate a sharper CCTV move',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final cloudBoostService = _RecordingCloudBoostService();
      Map<String, Object?>? sessionState;

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-CTRL-890',
            sourceRouteLabel: 'Track',
            cloudAssistAvailable: true,
            events: [
              DecisionCreated(
                eventId: 'evt-1',
                sequence: 1,
                version: 1,
                occurredAt: DateTime.utc(2026, 3, 31, 8, 0),
                dispatchId: 'INC-CTRL-890',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GP',
                siteId: 'SITE-SANDTON',
              ),
              ResponseArrived(
                eventId: 'evt-2',
                sequence: 2,
                version: 1,
                occurredAt: DateTime.utc(2026, 3, 31, 8, 4),
                dispatchId: 'INC-CTRL-890',
                guardId: 'GUARD-9',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GP',
                siteId: 'SITE-SANDTON',
              ),
              PatrolCompleted(
                eventId: 'evt-3',
                sequence: 3,
                version: 1,
                occurredAt: DateTime.utc(2026, 3, 31, 8, 6),
                guardId: 'GUARD-9',
                routeId: 'ROUTE-ALPHA',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GP',
                siteId: 'SITE-SANDTON',
                durationSeconds: 960,
              ),
              IntelligenceReceived(
                eventId: 'evt-4',
                sequence: 4,
                version: 1,
                occurredAt: DateTime.utc(2026, 3, 31, 8, 7),
                intelligenceId: 'intel-4',
                provider: 'vision',
                sourceType: 'cctv',
                externalId: 'vision-4',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GP',
                siteId: 'SITE-SANDTON',
                cameraId: 'CAM-9',
                headline: 'Confirmed breach at the north gate',
                summary:
                    'Fresh clip still needs confirmation before the response picture widens.',
                riskScore: 92,
                canonicalHash: 'hash-4',
              ),
            ],
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            localBrainService: _FakeLocalBrainService(),
            cloudBoostService: cloudBoostService,
            onThreadSessionStateChanged: (state) {
              sessionState = state;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('onyx-agent-composer-field')),
        'Triage the active incident and stage one obvious next move',
      );
      await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
      await tester.pumpAndSettle();

      expect(cloudBoostService.calls, 1);

      final messageList = find.byKey(const ValueKey('onyx-agent-message-list'));
      final brainHeadline = find.text(
        'Command brain corroborated a sharper next move',
      );
      for (
        var attempt = 0;
        attempt < 6 && brainHeadline.evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(messageList, const Offset(0, -280));
        await tester.pumpAndSettle();
      }

      expect(brainHeadline, findsOneWidget);
      expect(
        find.textContaining('Command brain mode: corroborated synthesis.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Specialist support: CCTV specialist'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Last recommendation: CCTV Review.'),
        findsOneWidget,
      );
      expect(
        find.text('Typed triage overruled the model suggestion'),
        findsNothing,
      );

      final persistedState =
          jsonDecode(jsonEncode(sessionState)) as Map<String, dynamic>;
      final persistedThreads = (persistedState['threads'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final persistedMemory =
          persistedThreads.first['memory'] as Map<String, dynamic>;
      final persistedCommandSurfaceMemory =
          persistedMemory['command_surface_memory'] as Map<String, dynamic>;
      expect(
        persistedMemory['last_recommendation_summary'],
        'ONYX command brain staged a corroborated move in CCTV Review.',
      );
      expect(persistedMemory['last_command_brain_snapshot'], isNull);
      final persistedSurfaceSnapshot =
          persistedCommandSurfaceMemory['commandBrainSnapshot']
              as Map<String, dynamic>;
      expect(persistedSurfaceSnapshot['mode'], 'corroboratedSynthesis');
      expect(
        persistedSurfaceSnapshot['supportingSpecialists'],
        contains('cctv'),
      );
    },
  );

  testWidgets('onyx agent page aggregates second-look disagreements across threads', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final cloudBoostService = _RecordingCloudBoostService();
    final events = <DispatchEvent>[
      DecisionCreated(
        eventId: 'evt-1',
        sequence: 1,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 31, 8, 0),
        dispatchId: 'INC-CTRL-891',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GP',
        siteId: 'SITE-SANDTON',
      ),
      ResponseArrived(
        eventId: 'evt-2',
        sequence: 2,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 31, 8, 4),
        dispatchId: 'INC-CTRL-891',
        guardId: 'GUARD-9',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GP',
        siteId: 'SITE-SANDTON',
      ),
      PatrolCompleted(
        eventId: 'evt-3',
        sequence: 3,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 31, 8, 6),
        guardId: 'GUARD-9',
        routeId: 'ROUTE-ALPHA',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GP',
        siteId: 'SITE-SANDTON',
        durationSeconds: 960,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: OnyxAgentPage(
          scopeClientId: 'CLIENT-001',
          scopeSiteId: 'SITE-SANDTON',
          focusIncidentReference: 'INC-CTRL-891',
          sourceRouteLabel: 'Track',
          cloudAssistAvailable: true,
          events: events,
          cameraChangeService: _FakeCameraChangeService(),
          cameraProbeService: _FakeCameraProbeService(),
          clientDraftService: _FakeClientDraftService(),
          localBrainService: _FakeLocalBrainService(),
          cloudBoostService: cloudBoostService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    Future<void> triggerConflict() async {
      await tester.enterText(
        find.byKey(const ValueKey('onyx-agent-composer-field')),
        'Triage the active incident and stage one obvious next move',
      );
      await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
      await tester.pumpAndSettle();
    }

    await triggerConflict();

    await tester.tap(
      find.byKey(const ValueKey('onyx-agent-new-thread-button')),
    );
    await tester.pumpAndSettle();

    await triggerConflict();

    expect(cloudBoostService.calls, 2);
    expect(
      find.byKey(const ValueKey('onyx-agent-planner-conflict-report')),
      findsOneWidget,
    );
    expect(
      find.text('2 second-look disagreements across 2 threads.'),
      findsOneWidget,
    );
    expect(
      find.text('Model drifted most toward CCTV Review (2).'),
      findsOneWidget,
    );
    expect(
      find.text('Typed planner held Tactical Track most often (2).'),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('onyx-agent-planner-top-model-drift')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey('onyx-agent-planner-section-focus-model-drift'),
      ),
      findsOneWidget,
    );
    expect(find.text('Focused model drift detail.'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('onyx-agent-planner-top-typed-hold')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey('onyx-agent-planner-section-focus-typed-holds'),
      ),
      findsOneWidget,
    );
    expect(find.text('Focused typed hold detail.'), findsOneWidget);
    expect(find.text('CCTV Review 2'), findsOneWidget);
    expect(find.text('Tactical Track 2'), findsOneWidget);
    expect(
      find.text(
        'Revisit Tactical Track vs CCTV Review threshold. The model keeps asking for visual confirmation while typed triage holds field posture.',
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('onyx-agent-composer-field')),
      'Correlate CCTV Review, Tactical Track, and Dispatch Board signals for the active incident',
    );
    await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
    await tester.pumpAndSettle();

    expect(cloudBoostService.calls, 3);
    expect(
      cloudBoostService.lastContextSummary,
      contains(
        'Planner review signal: Revisit Tactical Track vs CCTV Review threshold. The model keeps asking for visual confirmation while typed triage holds field posture.',
      ),
    );
    final plannerNote = find.textContaining(
      'Planner note: Revisit Tactical Track vs CCTV Review threshold. The model keeps asking for visual confirmation while typed triage holds field posture.',
    );
    final messageList = find.byKey(const ValueKey('onyx-agent-message-list'));
    for (
      var attempt = 0;
      attempt < 6 && plannerNote.evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(messageList, const Offset(0, -280));
      await tester.pumpAndSettle();
    }
    expect(plannerNote, findsOneWidget);
  });

  testWidgets(
    'onyx agent page tracks planner drift as worsening, stabilizing, and resolved',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final cloudBoostService = _RecordingCloudBoostService();
      Map<String, Object?>? sessionState;

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-CTRL-891',
            sourceRouteLabel: 'Track',
            cloudAssistAvailable: true,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            localBrainService: _FakeLocalBrainService(),
            cloudBoostService: cloudBoostService,
            onThreadSessionStateChanged: (state) {
              sessionState = state;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      Future<void> triggerConflict(String prompt) async {
        await tester.enterText(
          find.byKey(const ValueKey('onyx-agent-composer-field')),
          prompt,
        );
        await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
        await tester.pumpAndSettle();
      }

      await triggerConflict(
        'Triage the active incident and stage one obvious next move',
      );
      await tester.tap(
        find.byKey(const ValueKey('onyx-agent-new-thread-button')),
      );
      await tester.pumpAndSettle();
      await triggerConflict(
        'Triage the active incident and stage one obvious next move',
      );
      await tester.tap(
        find.byKey(const ValueKey('onyx-agent-new-thread-button')),
      );
      await tester.pumpAndSettle();
      await triggerConflict(
        'Triage the active incident and stage one obvious next move for controllers',
      );

      expect(sessionState, isNotNull);
      final worseningState =
          jsonDecode(jsonEncode(sessionState)) as Map<String, dynamic>;
      final worseningCurrentSnapshot =
          worseningState['planner_signal_snapshot'] as Map<String, dynamic>;
      final worseningPreviousSnapshot =
          worseningState['previous_planner_signal_snapshot']
              as Map<String, dynamic>;
      final worseningSignalCounts =
          worseningCurrentSnapshot['signal_counts'] as Map<String, dynamic>;
      final worseningSignalId = worseningSignalCounts.keys.single;
      final worseningSignalKey = worseningSignalId.replaceAll(
        RegExp(r'[^a-zA-Z0-9]+'),
        '-',
      );
      expect(worseningSignalCounts[worseningSignalId], 3);
      expect(
        (worseningPreviousSnapshot['signal_counts']
            as Map<String, dynamic>)[worseningSignalId],
        2,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-CTRL-891',
            sourceRouteLabel: 'Track',
            cloudAssistAvailable: true,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            localBrainService: _FakeLocalBrainService(),
            cloudBoostService: cloudBoostService,
            initialThreadSessionState: worseningState.cast<String, Object?>(),
            onThreadSessionStateChanged: (state) {
              sessionState = state;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Worsening:'), findsWidgets);
      expect(find.textContaining('Tune now:'), findsWidgets);
      expect(find.text('CHANGE NEXT'), findsOneWidget);
      expect(find.textContaining('hot now · '), findsWidgets);
      final driftWatchShortcut = find.byKey(
        ValueKey('onyx-agent-planner-drift-watch-$worseningSignalKey'),
      );
      await tester.ensureVisible(driftWatchShortcut);
      await tester.pumpAndSettle();
      await tester.tap(driftWatchShortcut);
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          ValueKey('onyx-agent-planner-backlog-focus-$worseningSignalKey'),
        ),
        findsOneWidget,
      );
      expect(find.text('Focused from drift watch.'), findsOneWidget);
      final tuningCueShortcut = find.byKey(
        ValueKey('onyx-agent-planner-tuning-cue-$worseningSignalKey'),
      );
      await tester.ensureVisible(tuningCueShortcut);
      await tester.pumpAndSettle();
      await tester.tap(tuningCueShortcut);
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          ValueKey('onyx-agent-planner-backlog-focus-$worseningSignalKey'),
        ),
        findsOneWidget,
      );
      expect(find.text('Focused from planner tuning cue.'), findsOneWidget);

      final stabilizedState =
          jsonDecode(jsonEncode(worseningState)) as Map<String, dynamic>;
      stabilizedState['previous_planner_signal_snapshot'] =
          worseningState['planner_signal_snapshot'];
      final stabilizedCurrentSnapshot =
          stabilizedState['planner_signal_snapshot'] as Map<String, dynamic>;
      final stabilizedPreviousSnapshot =
          stabilizedState['previous_planner_signal_snapshot']
              as Map<String, dynamic>;
      expect(
        (stabilizedCurrentSnapshot['signal_counts']
            as Map<String, dynamic>)[worseningSignalId],
        3,
      );
      expect(
        (stabilizedPreviousSnapshot['signal_counts']
            as Map<String, dynamic>)[worseningSignalId],
        3,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-CTRL-891',
            sourceRouteLabel: 'Track',
            cloudAssistAvailable: true,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            localBrainService: _FakeLocalBrainService(),
            cloudBoostService: cloudBoostService,
            initialThreadSessionState: stabilizedState.cast<String, Object?>(),
            onThreadSessionStateChanged: (state) {
              sessionState = state;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Stabilizing:'), findsWidgets);
      expect(find.textContaining('Adjustment cue:'), findsWidgets);
      expect(find.text('CHANGE NEXT'), findsOneWidget);
      expect(find.textContaining('hot now · '), findsWidgets);

      final resolvedState =
          jsonDecode(jsonEncode(stabilizedState)) as Map<String, dynamic>;
      resolvedState.remove('planner_signal_snapshot');
      resolvedState['previous_planner_signal_snapshot'] =
          stabilizedState['planner_signal_snapshot'];
      final resolvedThreads = (resolvedState['threads'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      for (final thread in resolvedThreads) {
        final memory = thread['memory'] as Map<String, dynamic>;
        memory.remove('second_look_conflict_count');
        memory.remove('second_look_model_target_counts');
        memory.remove('second_look_typed_target_counts');
        memory.remove('second_look_route_closed_conflict_count');
      }

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-CTRL-891',
            sourceRouteLabel: 'Track',
            cloudAssistAvailable: true,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            localBrainService: _FakeLocalBrainService(),
            cloudBoostService: cloudBoostService,
            initialThreadSessionState: resolvedState.cast<String, Object?>(),
            onThreadSessionStateChanged: (state) {
              sessionState = state;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Resolved:'), findsWidgets);
      expect(find.textContaining('Tune now:'), findsNothing);
      expect(find.textContaining('Adjustment cue:'), findsNothing);
      expect(find.text('CHANGE NEXT'), findsOneWidget);
      expect(find.textContaining('watch · '), findsWidgets);
    },
  );

  testWidgets(
    'onyx agent page lets planner backlog items be acknowledged, muted, and fixed',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Map<String, Object?>? sessionState;
      const signalId = 'drift:cctvReview:tacticalTrack';
      final seededState = <String, Object?>{
        'version': 4,
        'thread_counter': 1,
        'selected_thread_id': 'thread-1',
        'planner_backlog_scores': <String, Object?>{signalId: 2},
        'planner_signal_snapshot': <String, Object?>{
          'signal_counts': <String, Object?>{signalId: 3},
          'captured_at_utc': DateTime.utc(2026, 3, 31, 8, 12).toIso8601String(),
        },
        'previous_planner_signal_snapshot': <String, Object?>{
          'signal_counts': <String, Object?>{signalId: 2},
          'captured_at_utc': DateTime.utc(2026, 3, 31, 8, 11).toIso8601String(),
        },
        'threads': <Object?>[
          <String, Object?>{
            'id': 'thread-1',
            'title': 'Track drift warning',
            'summary': 'Typed triage kept Tactical Track.',
            'memory': <String, Object?>{
              'last_recommended_target': 'tacticalTrack',
              'second_look_conflict_count': 3,
              'last_second_look_conflict_summary':
                  'OpenAI second look: kept Tactical Track over CCTV Review.',
              'second_look_model_target_counts': <String, Object?>{
                'cctvReview': 3,
              },
              'second_look_typed_target_counts': <String, Object?>{
                'tacticalTrack': 3,
              },
              'updated_at_utc': DateTime.utc(
                2026,
                3,
                31,
                8,
                12,
              ).toIso8601String(),
            },
            'messages': <Object?>[
              <String, Object?>{
                'id': 'msg-1',
                'kind': 'agent',
                'persona_id': 'policy',
                'headline': 'Typed triage overruled the model suggestion',
                'body': 'Typed triage kept Tactical Track as the active desk.',
                'created_at_utc': DateTime.utc(
                  2026,
                  3,
                  31,
                  8,
                  12,
                ).toIso8601String(),
              },
            ],
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-CTRL-891',
            sourceRouteLabel: 'Track',
            cloudAssistAvailable: true,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            localBrainService: _FakeLocalBrainService(),
            cloudBoostService: _RecordingCloudBoostService(),
            initialThreadSessionState: seededState,
            onThreadSessionStateChanged: (state) {
              sessionState = state;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SELF-TUNING CUES'), findsOneWidget);
      expect(find.text('CHANGE NEXT'), findsOneWidget);

      final acknowledgedButton = find.byKey(
        const ValueKey(
          'onyx-agent-planner-backlog-acknowledged-drift-cctvReview-tacticalTrack',
        ),
      );
      await tester.ensureVisible(acknowledgedButton);
      await tester.pumpAndSettle();
      await tester.tap(acknowledgedButton);
      await tester.pumpAndSettle();

      expect(find.text('ACKNOWLEDGED'), findsOneWidget);
      expect(find.text('SELF-TUNING CUES'), findsNothing);
      expect(sessionState, isNotNull);
      final acknowledgedState =
          jsonDecode(jsonEncode(sessionState)) as Map<String, dynamic>;
      expect(
        (acknowledgedState['planner_backlog_review_statuses']
            as Map<String, dynamic>)[signalId],
        'acknowledged',
      );

      final mutedButton = find.byKey(
        const ValueKey(
          'onyx-agent-planner-backlog-muted-drift-cctvReview-tacticalTrack',
        ),
      );
      await tester.ensureVisible(mutedButton);
      await tester.pumpAndSettle();
      await tester.tap(mutedButton);
      await tester.pumpAndSettle();

      expect(find.text('MUTED'), findsOneWidget);
      final mutedState =
          jsonDecode(jsonEncode(sessionState)) as Map<String, dynamic>;
      expect(
        (mutedState['planner_backlog_review_statuses']
            as Map<String, dynamic>)[signalId],
        'muted',
      );

      final fixedButton = find.byKey(
        const ValueKey(
          'onyx-agent-planner-backlog-fixed-drift-cctvReview-tacticalTrack',
        ),
      );
      await tester.ensureVisible(fixedButton);
      await tester.pumpAndSettle();
      await tester.tap(fixedButton);
      await tester.pumpAndSettle();

      expect(find.text('FIXED'), findsOneWidget);
      final fixedState =
          jsonDecode(jsonEncode(sessionState)) as Map<String, dynamic>;
      expect(
        (fixedState['planner_backlog_review_statuses']
            as Map<String, dynamic>)[signalId],
        'fixed',
      );
      expect(find.text('CHANGE NEXT'), findsOneWidget);
      expect(find.textContaining('watch'), findsNothing);
      expect(find.textContaining('hot now'), findsWidgets);
    },
  );

  testWidgets('onyx agent page clears reviewed planner backlog items in bulk', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Map<String, Object?>? sessionState;
    const signalId = 'drift:cctvReview:tacticalTrack';
    final seededState = <String, Object?>{
      'version': 5,
      'thread_counter': 1,
      'selected_thread_id': 'thread-1',
      'planner_backlog_scores': <String, Object?>{signalId: 2},
      'planner_backlog_review_statuses': <String, Object?>{signalId: 'muted'},
      'planner_signal_snapshot': <String, Object?>{
        'signal_counts': <String, Object?>{signalId: 3},
        'captured_at_utc': DateTime.utc(2026, 3, 31, 8, 12).toIso8601String(),
      },
      'previous_planner_signal_snapshot': <String, Object?>{
        'signal_counts': <String, Object?>{signalId: 2},
        'captured_at_utc': DateTime.utc(2026, 3, 31, 8, 11).toIso8601String(),
      },
      'threads': <Object?>[
        <String, Object?>{
          'id': 'thread-1',
          'title': 'Track drift warning',
          'summary': 'Typed triage kept Tactical Track.',
          'memory': <String, Object?>{
            'last_recommended_target': 'tacticalTrack',
            'second_look_conflict_count': 3,
            'last_second_look_conflict_summary':
                'OpenAI second look: kept Tactical Track over CCTV Review.',
            'second_look_model_target_counts': <String, Object?>{
              'cctvReview': 3,
            },
            'second_look_typed_target_counts': <String, Object?>{
              'tacticalTrack': 3,
            },
            'updated_at_utc': DateTime.utc(
              2026,
              3,
              31,
              8,
              12,
            ).toIso8601String(),
          },
          'messages': <Object?>[
            <String, Object?>{
              'id': 'msg-1',
              'kind': 'agent',
              'persona_id': 'policy',
              'headline': 'Typed triage overruled the model suggestion',
              'body': 'Typed triage kept Tactical Track as the active desk.',
              'created_at_utc': DateTime.utc(
                2026,
                3,
                31,
                8,
                12,
              ).toIso8601String(),
            },
          ],
        },
      ],
    };

    await tester.pumpWidget(
      MaterialApp(
        home: OnyxAgentPage(
          scopeClientId: 'CLIENT-001',
          scopeSiteId: 'SITE-SANDTON',
          focusIncidentReference: 'INC-CTRL-891',
          sourceRouteLabel: 'Track',
          cloudAssistAvailable: true,
          cameraChangeService: _FakeCameraChangeService(),
          cameraProbeService: _FakeCameraProbeService(),
          clientDraftService: _FakeClientDraftService(),
          localBrainService: _FakeLocalBrainService(),
          cloudBoostService: _RecordingCloudBoostService(),
          initialThreadSessionState: seededState,
          onThreadSessionStateChanged: (state) {
            sessionState = state;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SELF-TUNING CUES'), findsNothing);
    expect(find.text('MUTED'), findsOneWidget);

    final clearReviewedButton = find.byKey(
      const ValueKey('onyx-agent-planner-backlog-clear-reviewed'),
    );
    await tester.ensureVisible(clearReviewedButton);
    await tester.pumpAndSettle();
    await tester.tap(clearReviewedButton);
    await tester.pumpAndSettle();

    expect(find.text('SELF-TUNING CUES'), findsOneWidget);
    expect(find.text('MUTED'), findsNothing);
    expect(sessionState, isNotNull);
    final clearedState =
        jsonDecode(jsonEncode(sessionState)) as Map<String, dynamic>;
    expect(
      clearedState.containsKey('planner_backlog_review_statuses'),
      isFalse,
    );
  });

  testWidgets(
    'onyx agent page archives reviewed planner backlog items in bulk',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Map<String, Object?>? sessionState;
      const signalId = 'drift:cctvReview:tacticalTrack';
      final seededState = <String, Object?>{
        'version': 5,
        'thread_counter': 1,
        'selected_thread_id': 'thread-1',
        'planner_backlog_scores': <String, Object?>{signalId: 2},
        'planner_backlog_review_statuses': <String, Object?>{signalId: 'fixed'},
        'planner_signal_snapshot': <String, Object?>{
          'signal_counts': <String, Object?>{signalId: 3},
          'captured_at_utc': DateTime.utc(2026, 3, 31, 8, 12).toIso8601String(),
        },
        'previous_planner_signal_snapshot': <String, Object?>{
          'signal_counts': <String, Object?>{signalId: 2},
          'captured_at_utc': DateTime.utc(2026, 3, 31, 8, 11).toIso8601String(),
        },
        'threads': <Object?>[
          <String, Object?>{
            'id': 'thread-1',
            'title': 'Track drift warning',
            'summary': 'Typed triage kept Tactical Track.',
            'memory': <String, Object?>{
              'last_recommended_target': 'tacticalTrack',
              'second_look_conflict_count': 3,
              'last_second_look_conflict_summary':
                  'OpenAI second look: kept Tactical Track over CCTV Review.',
              'second_look_model_target_counts': <String, Object?>{
                'cctvReview': 3,
              },
              'second_look_typed_target_counts': <String, Object?>{
                'tacticalTrack': 3,
              },
              'updated_at_utc': DateTime.utc(
                2026,
                3,
                31,
                8,
                12,
              ).toIso8601String(),
            },
            'messages': <Object?>[
              <String, Object?>{
                'id': 'msg-1',
                'kind': 'agent',
                'persona_id': 'policy',
                'headline': 'Typed triage overruled the model suggestion',
                'body': 'Typed triage kept Tactical Track as the active desk.',
                'created_at_utc': DateTime.utc(
                  2026,
                  3,
                  31,
                  8,
                  12,
                ).toIso8601String(),
              },
            ],
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-CTRL-891',
            sourceRouteLabel: 'Track',
            cloudAssistAvailable: true,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            localBrainService: _FakeLocalBrainService(),
            cloudBoostService: _RecordingCloudBoostService(),
            initialThreadSessionState: seededState,
            onThreadSessionStateChanged: (state) {
              sessionState = state;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('FIXED'), findsOneWidget);
      expect(find.text('CHANGE NEXT'), findsOneWidget);

      final archiveReviewedButton = find.byKey(
        const ValueKey('onyx-agent-planner-backlog-archive-reviewed'),
      );
      await tester.ensureVisible(archiveReviewedButton);
      await tester.pumpAndSettle();
      await tester.tap(archiveReviewedButton);
      await tester.pumpAndSettle();

      expect(find.text('CHANGE NEXT'), findsNothing);
      expect(
        find.text('1 reviewed item is archived until the drift worsens again.'),
        findsOneWidget,
      );
      final archivedSummaryShortcut = find.byKey(
        const ValueKey('onyx-agent-planner-archived-summary'),
      );
      await tester.ensureVisible(archivedSummaryShortcut);
      await tester.pumpAndSettle();
      await tester.tap(archivedSummaryShortcut);
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey(
            'onyx-agent-planner-archived-focus-drift-cctvReview-tacticalTrack',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('Focused archived rule bucket.'), findsOneWidget);
      expect(find.text('ARCHIVED WATCH'), findsOneWidget);
      expect(find.text('SELF-TUNING CUES'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('onyx-agent-thread-thread-1')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey(
            'onyx-agent-planner-archived-focus-drift-cctvReview-tacticalTrack',
          ),
        ),
        findsNothing,
      );
      expect(find.text('Focused archived rule bucket.'), findsNothing);

      expect(sessionState, isNotNull);
      final archivedState =
          jsonDecode(jsonEncode(sessionState)) as Map<String, dynamic>;
      expect(
        (archivedState['planner_backlog_archived_signal_counts']
            as Map<String, dynamic>)[signalId],
        3,
      );
      expect(
        archivedState.containsKey('planner_backlog_review_statuses'),
        isFalse,
      );
    },
  );

  testWidgets(
    'onyx agent page explains when archived planner backlog items reactivate',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const signalId = 'drift:cctvReview:tacticalTrack';
      final reactivatedAt = DateTime.now().toUtc();
      final seededState = <String, Object?>{
        'version': 7,
        'thread_counter': 1,
        'selected_thread_id': 'thread-1',
        'planner_backlog_scores': <String, Object?>{signalId: 2},
        'planner_backlog_reactivated_signal_counts': <String, Object?>{
          signalId: 2,
        },
        'planner_backlog_reactivation_counts': <String, Object?>{signalId: 2},
        'planner_backlog_last_reactivated_at_utc': <String, Object?>{
          signalId: reactivatedAt.toIso8601String(),
        },
        'planner_signal_snapshot': <String, Object?>{
          'signal_counts': <String, Object?>{signalId: 3},
          'captured_at_utc': DateTime.utc(2026, 3, 31, 8, 12).toIso8601String(),
        },
        'previous_planner_signal_snapshot': <String, Object?>{
          'signal_counts': <String, Object?>{signalId: 2},
          'captured_at_utc': DateTime.utc(2026, 3, 31, 8, 11).toIso8601String(),
        },
        'threads': <Object?>[
          <String, Object?>{
            'id': 'thread-1',
            'title': 'Track drift warning',
            'summary': 'Typed triage kept Tactical Track.',
            'memory': <String, Object?>{
              'last_recommended_target': 'tacticalTrack',
              'second_look_conflict_count': 3,
              'last_second_look_conflict_summary':
                  'OpenAI second look: kept Tactical Track over CCTV Review.',
              'second_look_model_target_counts': <String, Object?>{
                'cctvReview': 3,
              },
              'second_look_typed_target_counts': <String, Object?>{
                'tacticalTrack': 3,
              },
              'updated_at_utc': DateTime.utc(
                2026,
                3,
                31,
                8,
                12,
              ).toIso8601String(),
            },
            'messages': <Object?>[
              <String, Object?>{
                'id': 'msg-1',
                'kind': 'agent',
                'persona_id': 'policy',
                'headline': 'Typed triage overruled the model suggestion',
                'body': 'Typed triage kept Tactical Track as the active desk.',
                'created_at_utc': DateTime.utc(
                  2026,
                  3,
                  31,
                  8,
                  12,
                ).toIso8601String(),
              },
            ],
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-CTRL-891',
            sourceRouteLabel: 'Track',
            cloudAssistAvailable: true,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            localBrainService: _FakeLocalBrainService(),
            cloudBoostService: _RecordingCloudBoostService(),
            initialThreadSessionState: seededState,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          '1 archived planner item reactivated after the drift worsened. Highest severity: flapping.',
        ),
        findsOneWidget,
      );
      expect(find.text('MAINTENANCE ALERTS'), findsNothing);
      expect(find.text('REACTIVATED'), findsOneWidget);
      expect(
        find.textContaining(
          'Reactivated from archive: Increase Tactical Track weighting when field posture is already live and CCTV is still only a confirmation step. returned after drift worsened from 2 to 3.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Severity: flapping.'), findsOneWidget);
      expect(find.textContaining('Reactivation count: 2.'), findsOneWidget);
      expect(find.textContaining('Last reactivated:'), findsOneWidget);
      expect(find.text('CHANGE NEXT'), findsOneWidget);
      final reactivatedShortcut = find.byKey(
        const ValueKey(
          'onyx-agent-planner-reactivated-drift-cctvReview-tacticalTrack',
        ),
      );
      await tester.ensureVisible(reactivatedShortcut);
      await tester.pumpAndSettle();
      await tester.tap(reactivatedShortcut);
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey(
            'onyx-agent-planner-backlog-focus-drift-cctvReview-tacticalTrack',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('Focused from reactivated rule.'), findsOneWidget);
    },
  );

  testWidgets(
    'onyx agent page queues planner maintenance review for chronic drift alerts',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Map<String, Object?>? sessionState;
      const signalId = 'drift:cctvReview:tacticalTrack';
      final reactivatedAt = DateTime.now().toUtc().subtract(
        const Duration(minutes: 30),
      );
      final seededState = <String, Object?>{
        'version': 7,
        'thread_counter': 1,
        'selected_thread_id': 'thread-1',
        'planner_backlog_scores': <String, Object?>{signalId: 2},
        'planner_backlog_reactivated_signal_counts': <String, Object?>{
          signalId: 2,
        },
        'planner_backlog_reactivation_counts': <String, Object?>{signalId: 4},
        'planner_backlog_last_reactivated_at_utc': <String, Object?>{
          signalId: reactivatedAt.toIso8601String(),
        },
        'planner_signal_snapshot': <String, Object?>{
          'signal_counts': <String, Object?>{signalId: 3},
          'captured_at_utc': DateTime.utc(2026, 3, 31, 8, 12).toIso8601String(),
        },
        'previous_planner_signal_snapshot': <String, Object?>{
          'signal_counts': <String, Object?>{signalId: 2},
          'captured_at_utc': DateTime.utc(2026, 3, 31, 8, 11).toIso8601String(),
        },
        'threads': <Object?>[
          <String, Object?>{
            'id': 'thread-1',
            'title': 'Track drift warning',
            'summary': 'Typed triage kept Tactical Track.',
            'memory': <String, Object?>{
              'last_recommended_target': 'tacticalTrack',
              'second_look_conflict_count': 3,
              'last_second_look_conflict_summary':
                  'OpenAI second look: kept Tactical Track over CCTV Review.',
              'second_look_model_target_counts': <String, Object?>{
                'cctvReview': 3,
              },
              'second_look_typed_target_counts': <String, Object?>{
                'tacticalTrack': 3,
              },
              'updated_at_utc': DateTime.utc(
                2026,
                3,
                31,
                8,
                12,
              ).toIso8601String(),
            },
            'messages': <Object?>[
              <String, Object?>{
                'id': 'msg-1',
                'kind': 'agent',
                'persona_id': 'policy',
                'headline': 'Typed triage overruled the model suggestion',
                'body': 'Typed triage kept Tactical Track as the active desk.',
                'created_at_utc': DateTime.utc(
                  2026,
                  3,
                  31,
                  8,
                  12,
                ).toIso8601String(),
              },
            ],
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-CTRL-891',
            sourceRouteLabel: 'Track',
            cloudAssistAvailable: true,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            localBrainService: _FakeLocalBrainService(),
            cloudBoostService: _RecordingCloudBoostService(),
            initialThreadSessionState: seededState,
            onThreadSessionStateChanged: (state) {
              sessionState = state;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MAINTENANCE ALERTS'), findsOneWidget);
      expect(find.text('REVIEW NOW'), findsOneWidget);
      expect(find.text('Mark for rule review'), findsOneWidget);
      expect(find.text('FROM ARCHIVE'), findsOneWidget);
      expect(
        find.text(
          'Archive lineage: escalated from archived watch after drift rose from 2 to 3.',
        ),
        findsOneWidget,
      );

      final lineageButton = find.byKey(
        const ValueKey(
          'onyx-agent-planner-maintenance-lineage-drift-cctvReview-tacticalTrack',
        ),
      );
      await tester.ensureVisible(lineageButton);
      await tester.pumpAndSettle();
      await tester.tap(lineageButton);
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey(
            'onyx-agent-planner-reactivation-focus-drift-cctvReview-tacticalTrack',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.text('Focused archive lineage from maintenance alert.'),
        findsOneWidget,
      );

      final queueReviewButton = find.byKey(
        const ValueKey(
          'onyx-agent-planner-maintenance-review-drift-cctvReview-tacticalTrack',
        ),
      );
      await tester.ensureVisible(queueReviewButton);
      await tester.pumpAndSettle();
      await tester.tap(queueReviewButton);
      await tester.pumpAndSettle();

      expect(find.text('RULE REVIEW QUEUED'), findsOneWidget);
      expect(find.textContaining('Queued for rule review:'), findsOneWidget);
      expect(find.text('Clear review mark'), findsOneWidget);
      expect(find.text('Planner maintenance review'), findsOneWidget);
      expect(sessionState, isNotNull);
      final queuedState =
          jsonDecode(jsonEncode(sessionState)) as Map<String, dynamic>;
      expect(
        (queuedState['planner_maintenance_review_queued_at_utc']
            as Map<String, dynamic>)[signalId],
        isNotEmpty,
      );
    },
  );

  testWidgets(
    'onyx agent page completes planner maintenance review for chronic drift alerts',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Map<String, Object?>? sessionState;
      const signalId = 'drift:cctvReview:tacticalTrack';
      final reactivatedAt = DateTime.now().toUtc().subtract(
        const Duration(minutes: 30),
      );
      final seededState = <String, Object?>{
        'version': 7,
        'thread_counter': 1,
        'selected_thread_id': 'thread-1',
        'planner_backlog_scores': <String, Object?>{signalId: 2},
        'planner_backlog_reactivated_signal_counts': <String, Object?>{
          signalId: 2,
        },
        'planner_backlog_reactivation_counts': <String, Object?>{signalId: 4},
        'planner_backlog_last_reactivated_at_utc': <String, Object?>{
          signalId: reactivatedAt.toIso8601String(),
        },
        'planner_signal_snapshot': <String, Object?>{
          'signal_counts': <String, Object?>{signalId: 3},
          'captured_at_utc': DateTime.utc(2026, 3, 31, 8, 12).toIso8601String(),
        },
        'previous_planner_signal_snapshot': <String, Object?>{
          'signal_counts': <String, Object?>{signalId: 2},
          'captured_at_utc': DateTime.utc(2026, 3, 31, 8, 11).toIso8601String(),
        },
        'planner_maintenance_review_queued_at_utc': <String, Object?>{
          signalId: reactivatedAt
              .add(const Duration(minutes: 2))
              .toIso8601String(),
        },
        'threads': <Object?>[
          <String, Object?>{
            'id': 'thread-1',
            'title': 'Track drift warning',
            'summary': 'Typed triage kept Tactical Track.',
            'memory': <String, Object?>{
              'last_recommended_target': 'tacticalTrack',
              'second_look_conflict_count': 3,
              'last_second_look_conflict_summary':
                  'OpenAI second look: kept Tactical Track over CCTV Review.',
              'second_look_model_target_counts': <String, Object?>{
                'cctvReview': 3,
              },
              'second_look_typed_target_counts': <String, Object?>{
                'tacticalTrack': 3,
              },
              'updated_at_utc': DateTime.utc(
                2026,
                3,
                31,
                8,
                12,
              ).toIso8601String(),
            },
            'messages': <Object?>[
              <String, Object?>{
                'id': 'msg-1',
                'kind': 'agent',
                'persona_id': 'policy',
                'headline': 'Typed triage overruled the model suggestion',
                'body': 'Typed triage kept Tactical Track as the active desk.',
                'created_at_utc': DateTime.utc(
                  2026,
                  3,
                  31,
                  8,
                  12,
                ).toIso8601String(),
              },
            ],
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-CTRL-891',
            sourceRouteLabel: 'Track',
            cloudAssistAvailable: true,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            localBrainService: _FakeLocalBrainService(),
            cloudBoostService: _RecordingCloudBoostService(),
            initialThreadSessionState: seededState,
            onThreadSessionStateChanged: (state) {
              sessionState = state;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final completeReviewButton = find.byKey(
        const ValueKey(
          'onyx-agent-planner-maintenance-complete-drift-cctvReview-tacticalTrack',
        ),
      );
      await tester.ensureVisible(completeReviewButton);
      await tester.pumpAndSettle();
      await tester.tap(completeReviewButton);
      await tester.pumpAndSettle();

      expect(find.text('REVIEW COMPLETED'), findsOneWidget);
      expect(find.textContaining('Review completed:'), findsOneWidget);
      expect(find.text('Reopen review'), findsOneWidget);
      expect(find.text('Planner maintenance review'), findsOneWidget);
      expect(sessionState, isNotNull);
      final completedState =
          jsonDecode(jsonEncode(sessionState)) as Map<String, dynamic>;
      expect(
        (completedState['planner_maintenance_review_completed_at_utc']
            as Map<String, dynamic>)[signalId],
        isNotEmpty,
      );
    },
  );

  testWidgets(
    'onyx agent page auto-reopens completed maintenance review when chronic drift worsens again',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final cloudBoostService = _RecordingCloudBoostService();
      Map<String, Object?>? sessionState;
      const signalId = 'drift:cctvReview:tacticalTrack';
      final reactivatedAt = DateTime.now().toUtc().subtract(
        const Duration(minutes: 30),
      );
      final reviewQueuedAt = reactivatedAt.add(const Duration(minutes: 2));
      final reviewCompletedAt = reviewQueuedAt.add(const Duration(minutes: 4));
      final seededState = <String, Object?>{
        'version': 7,
        'thread_counter': 1,
        'selected_thread_id': 'thread-1',
        'planner_backlog_scores': <String, Object?>{signalId: 2},
        'planner_backlog_reactivated_signal_counts': <String, Object?>{
          signalId: 2,
        },
        'planner_backlog_reactivation_counts': <String, Object?>{signalId: 4},
        'planner_backlog_last_reactivated_at_utc': <String, Object?>{
          signalId: reactivatedAt.toIso8601String(),
        },
        'planner_maintenance_review_queued_at_utc': <String, Object?>{
          signalId: reviewQueuedAt.toIso8601String(),
        },
        'planner_maintenance_review_completed_at_utc': <String, Object?>{
          signalId: reviewCompletedAt.toIso8601String(),
        },
        'planner_maintenance_review_completed_signal_counts': <String, Object?>{
          signalId: 3,
        },
        'planner_maintenance_review_completed_reactivation_counts':
            <String, Object?>{signalId: 4},
        'planner_signal_snapshot': <String, Object?>{
          'signal_counts': <String, Object?>{signalId: 3},
          'captured_at_utc': DateTime.utc(2026, 3, 31, 8, 12).toIso8601String(),
        },
        'previous_planner_signal_snapshot': <String, Object?>{
          'signal_counts': <String, Object?>{signalId: 2},
          'captured_at_utc': DateTime.utc(2026, 3, 31, 8, 11).toIso8601String(),
        },
        'threads': <Object?>[
          <String, Object?>{
            'id': 'thread-1',
            'title': 'Track drift warning',
            'summary': 'Typed triage kept Tactical Track.',
            'memory': <String, Object?>{
              'last_recommended_target': 'tacticalTrack',
              'second_look_conflict_count': 3,
              'last_second_look_conflict_summary':
                  'OpenAI second look: kept Tactical Track over CCTV Review.',
              'second_look_model_target_counts': <String, Object?>{
                'cctvReview': 3,
              },
              'second_look_typed_target_counts': <String, Object?>{
                'tacticalTrack': 3,
              },
              'updated_at_utc': DateTime.utc(
                2026,
                3,
                31,
                8,
                12,
              ).toIso8601String(),
            },
            'messages': <Object?>[
              <String, Object?>{
                'id': 'msg-1',
                'kind': 'agent',
                'persona_id': 'policy',
                'headline': 'Typed triage overruled the model suggestion',
                'body': 'Typed triage kept Tactical Track as the active desk.',
                'created_at_utc': DateTime.utc(
                  2026,
                  3,
                  31,
                  8,
                  12,
                ).toIso8601String(),
              },
            ],
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-CTRL-891',
            sourceRouteLabel: 'Track',
            cloudAssistAvailable: true,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            localBrainService: _FakeLocalBrainService(),
            cloudBoostService: cloudBoostService,
            initialThreadSessionState: seededState,
            onThreadSessionStateChanged: (state) {
              sessionState = state;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('onyx-agent-composer-field')),
        'Triage the active incident and stage one obvious next move',
      );
      await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
      await tester.pumpAndSettle();

      expect(cloudBoostService.calls, 1);
      expect(find.text('REVIEW REOPENED'), findsOneWidget);
      expect(find.text('REPEAT REGRESSION'), findsOneWidget);
      expect(find.text('Prioritize review now'), findsNothing);
      expect(
        find.text(
          '1 planner maintenance alert active. Highest severity: chronic drift from archived watch. Top burn rate: review reopened 1 time.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('has gone stale after the drift worsened again.'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Planner maintenance: Maintenance review completed for chronic drift from archived watch on Increase Tactical Track weighting when field posture is already live and CCTV is still only a confirmation step.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Review reopened after worsening:'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Most regressed rule: Increase Tactical Track weighting when field posture is already live and CCTV is still only a confirmation step from archived watch reopened after review 1 time.',
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('onyx-agent-planner-most-regressed-rule')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey(
            'onyx-agent-planner-maintenance-focus-drift-cctvReview-tacticalTrack',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('Focused from planner summary.'), findsOneWidget);
      expect(
        find.text('Review reopened after completion 1 time.'),
        findsOneWidget,
      );
      expect(find.text('Mark review completed'), findsOneWidget);
      expect(sessionState, isNotNull);
      final reopenedState =
          jsonDecode(jsonEncode(sessionState)) as Map<String, dynamic>;
      final queuedAt = DateTime.parse(
        (reopenedState['planner_maintenance_review_queued_at_utc']
                as Map<String, dynamic>)[signalId]
            as String,
      );
      final completedAt = DateTime.parse(
        (reopenedState['planner_maintenance_review_completed_at_utc']
                as Map<String, dynamic>)[signalId]
            as String,
      );
      expect(queuedAt.isAfter(completedAt), isTrue);
      expect(
        (reopenedState['planner_maintenance_review_reopened_counts']
            as Map<String, dynamic>)[signalId],
        1,
      );
    },
  );

  testWidgets(
    'onyx agent page does not auto-surface stale follow-up when urgent thread navigation switches threads',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Map<String, Object?>? sessionState;
      const signalId = 'drift:cctvReview:tacticalTrack';
      final reactivatedAt = DateTime.now().toUtc().subtract(
        const Duration(minutes: 30),
      );
      final reviewQueuedAt = reactivatedAt.add(const Duration(minutes: 2));
      final reviewCompletedAt = reviewQueuedAt.add(const Duration(minutes: 4));
      final reviewReopenedAt = reviewCompletedAt.add(
        const Duration(minutes: 6),
      );
      final prioritizedAt = reviewReopenedAt.add(const Duration(minutes: 1));
      final seededState = <String, Object?>{
        'version': 7,
        'thread_counter': 2,
        'selected_thread_id': 'thread-1',
        'selected_thread_operator_id': 'thread-1',
        'selected_thread_operator_at_utc': DateTime.utc(
          2026,
          3,
          31,
          8,
          19,
        ).toIso8601String(),
        'planner_backlog_scores': <String, Object?>{signalId: 2},
        'planner_backlog_reactivated_signal_counts': <String, Object?>{
          signalId: 2,
        },
        'planner_backlog_reactivation_counts': <String, Object?>{signalId: 4},
        'planner_backlog_last_reactivated_at_utc': <String, Object?>{
          signalId: reactivatedAt.toIso8601String(),
        },
        'planner_maintenance_review_queued_at_utc': <String, Object?>{
          signalId: reviewReopenedAt.toIso8601String(),
        },
        'planner_maintenance_review_completed_at_utc': <String, Object?>{
          signalId: reviewCompletedAt.toIso8601String(),
        },
        'planner_maintenance_review_prioritized_at_utc': <String, Object?>{
          signalId: prioritizedAt.toIso8601String(),
        },
        'planner_maintenance_review_completed_signal_counts': <String, Object?>{
          signalId: 3,
        },
        'planner_maintenance_review_completed_reactivation_counts':
            <String, Object?>{signalId: 4},
        'planner_maintenance_review_reopened_counts': <String, Object?>{
          signalId: 2,
        },
        'planner_signal_snapshot': <String, Object?>{
          'signal_counts': <String, Object?>{signalId: 4},
          'captured_at_utc': DateTime.utc(2026, 3, 31, 8, 18).toIso8601String(),
        },
        'previous_planner_signal_snapshot': <String, Object?>{
          'signal_counts': <String, Object?>{signalId: 3},
          'captured_at_utc': DateTime.utc(2026, 3, 31, 8, 12).toIso8601String(),
        },
        'threads': <Object?>[
          <String, Object?>{
            'id': 'thread-1',
            'title': 'Client reassurance',
            'summary': 'No urgent planner drift on this thread.',
            'memory': <String, Object?>{},
            'messages': <Object?>[
              <String, Object?>{
                'id': 'msg-0',
                'kind': 'agent',
                'persona_id': 'main',
                'headline': 'Client reassurance ready',
                'body': 'No operational drift is attached to this thread.',
                'created_at_utc': DateTime.utc(
                  2026,
                  3,
                  31,
                  8,
                  10,
                ).toIso8601String(),
              },
            ],
          },
          <String, Object?>{
            'id': 'thread-2',
            'title': 'Track drift warning',
            'summary': 'Typed triage kept Tactical Track.',
            'memory': <String, Object?>{
              'last_primary_pressure': 'overdue follow-up',
              'last_recommended_target': 'tacticalTrack',
              'second_look_conflict_count': 4,
              'last_second_look_conflict_summary':
                  'OpenAI second look: kept Tactical Track over CCTV Review.',
              'second_look_model_target_counts': <String, Object?>{
                'cctvReview': 4,
              },
              'second_look_typed_target_counts': <String, Object?>{
                'tacticalTrack': 4,
              },
              'next_follow_up_label': 'RECHECK RESPONDER ETA',
              'next_follow_up_prompt':
                  'Check the responder ETA and confirm whether dispatch has arrived.',
              'pending_confirmations': <Object?>['responder ETA'],
              'last_advisory': 'Response delay detected.',
              'updated_at_utc': DateTime.now()
                  .subtract(const Duration(minutes: 12))
                  .toIso8601String(),
            },
            'messages': <Object?>[
              <String, Object?>{
                'id': 'msg-1',
                'kind': 'agent',
                'persona_id': 'policy',
                'headline': 'Typed triage overruled the model suggestion',
                'body': 'Typed triage kept Tactical Track as the active desk.',
                'created_at_utc': DateTime.utc(
                  2026,
                  3,
                  31,
                  8,
                  18,
                ).toIso8601String(),
              },
            ],
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-CTRL-891',
            sourceRouteLabel: 'Track',
            cloudAssistAvailable: true,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            localBrainService: _FakeLocalBrainService(),
            cloudBoostService: _RecordingCloudBoostService(),
            initialThreadSessionState: seededState,
            onThreadSessionStateChanged: (state) {
              sessionState = state;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('URGENT REVIEW'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('onyx-agent-thread-urgent-reason-thread-2')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('onyx-agent-thread-urgent-reason-thread-2')),
      );
      await tester.pump();

      expect(
        find.byKey(
          const ValueKey(
            'onyx-agent-planner-maintenance-focus-drift-cctvReview-tacticalTrack',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('Focused from the thread rail.'), findsOneWidget);
      _expectPlannerDrivenThreadHandoff(
        sessionState,
        selectedThreadId: 'thread-2',
        expectedMessageCount: 1,
      );
    },
  );

  testWidgets(
    'onyx agent page keeps highest-burn maintenance review prioritized after escalation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final cloudBoostService = _RecordingCloudBoostService();
      Map<String, Object?>? sessionState;
      const signalId = 'drift:cctvReview:tacticalTrack';
      final reactivatedAt = DateTime.now().toUtc().subtract(
        const Duration(minutes: 30),
      );
      final reviewCompletedAt = reactivatedAt.add(const Duration(minutes: 4));
      final reviewReopenedAt = reviewCompletedAt.add(
        const Duration(minutes: 6),
      );
      final seededState = <String, Object?>{
        'version': 7,
        'thread_counter': 1,
        'selected_thread_id': 'thread-1',
        'selected_thread_operator_id': 'thread-1',
        'selected_thread_operator_at_utc': DateTime.utc(
          2026,
          3,
          31,
          8,
          19,
        ).toIso8601String(),
        'planner_backlog_scores': <String, Object?>{signalId: 2},
        'planner_backlog_reactivated_signal_counts': <String, Object?>{
          signalId: 2,
        },
        'planner_backlog_reactivation_counts': <String, Object?>{signalId: 4},
        'planner_backlog_last_reactivated_at_utc': <String, Object?>{
          signalId: reactivatedAt.toIso8601String(),
        },
        'planner_maintenance_review_queued_at_utc': <String, Object?>{
          signalId: reviewReopenedAt.toIso8601String(),
        },
        'planner_maintenance_review_completed_at_utc': <String, Object?>{
          signalId: reviewCompletedAt.toIso8601String(),
        },
        'planner_maintenance_review_completed_signal_counts': <String, Object?>{
          signalId: 3,
        },
        'planner_maintenance_review_completed_reactivation_counts':
            <String, Object?>{signalId: 4},
        'planner_maintenance_review_reopened_counts': <String, Object?>{
          signalId: 2,
        },
        'planner_signal_snapshot': <String, Object?>{
          'signal_counts': <String, Object?>{signalId: 4},
          'captured_at_utc': DateTime.utc(2026, 3, 31, 8, 18).toIso8601String(),
        },
        'previous_planner_signal_snapshot': <String, Object?>{
          'signal_counts': <String, Object?>{signalId: 3},
          'captured_at_utc': DateTime.utc(2026, 3, 31, 8, 12).toIso8601String(),
        },
        'threads': <Object?>[
          <String, Object?>{
            'id': 'thread-1',
            'title': 'Client reassurance',
            'summary': 'No urgent planner drift on this thread.',
            'memory': <String, Object?>{
              'last_recommended_target': 'clientComms',
              'last_operator_focus_note':
                  'manual context preserved on Client reassurance while urgent review remains visible on Track drift warning.',
              'updated_at_utc': DateTime.utc(
                2026,
                3,
                31,
                8,
                10,
              ).toIso8601String(),
            },
            'messages': <Object?>[
              <String, Object?>{
                'id': 'msg-0',
                'kind': 'agent',
                'persona_id': 'main',
                'headline': 'Client reassurance ready',
                'body': 'No operational drift is attached to this thread.',
                'created_at_utc': DateTime.utc(
                  2026,
                  3,
                  31,
                  8,
                  10,
                ).toIso8601String(),
              },
            ],
          },
          <String, Object?>{
            'id': 'thread-2',
            'title': 'Track drift warning',
            'summary': 'Typed triage kept Tactical Track.',
            'memory': <String, Object?>{
              'last_primary_pressure': 'overdue follow-up',
              'last_recommended_target': 'tacticalTrack',
              'second_look_conflict_count': 4,
              'last_second_look_conflict_summary':
                  'OpenAI second look: kept Tactical Track over CCTV Review.',
              'second_look_model_target_counts': <String, Object?>{
                'cctvReview': 4,
              },
              'second_look_typed_target_counts': <String, Object?>{
                'tacticalTrack': 4,
              },
              'next_follow_up_label': 'RECHECK RESPONDER ETA',
              'next_follow_up_prompt':
                  'Check the responder ETA and confirm whether dispatch has arrived.',
              'pending_confirmations': <Object?>['responder ETA'],
              'last_advisory': 'Response delay detected.',
              'updated_at_utc': DateTime.now()
                  .subtract(const Duration(minutes: 12))
                  .toIso8601String(),
            },
            'messages': <Object?>[
              <String, Object?>{
                'id': 'msg-1',
                'kind': 'agent',
                'persona_id': 'policy',
                'headline': 'Typed triage overruled the model suggestion',
                'body': 'Typed triage kept Tactical Track as the active desk.',
                'created_at_utc': DateTime.utc(
                  2026,
                  3,
                  31,
                  8,
                  18,
                ).toIso8601String(),
              },
            ],
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-CTRL-891',
            sourceRouteLabel: 'Track',
            cloudAssistAvailable: true,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            localBrainService: _FakeLocalBrainService(),
            cloudBoostService: cloudBoostService,
            initialThreadSessionState: seededState,
            onThreadSessionStateChanged: (state) {
              sessionState = state;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('onyx-agent-cloud-boost-toggle')),
      );
      await tester.pumpAndSettle();

      final prioritizeButton = find.byKey(
        const ValueKey(
          'onyx-agent-planner-maintenance-prioritize-drift-cctvReview-tacticalTrack',
        ),
      );
      await tester.ensureVisible(prioritizeButton);
      await tester.pumpAndSettle();
      await tester.tap(prioritizeButton);
      await tester.pumpAndSettle();

      expect(
        tester
            .getTopLeft(
              find.byKey(const ValueKey('onyx-agent-thread-thread-2')),
            )
            .dy,
        lessThan(
          tester
              .getTopLeft(
                find.byKey(const ValueKey('onyx-agent-thread-thread-1')),
              )
              .dy,
        ),
      );
      expect(find.text('URGENT REVIEW'), findsOneWidget);
      expect(
        find.text('Typed triage overruled the model suggestion'),
        findsOneWidget,
      );
      expect(find.text('Client reassurance ready'), findsNothing);
      expect(
        find.byKey(const ValueKey('onyx-agent-thread-urgent-reason-thread-2')),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Urgent rule: Increase Tactical Track weighting when field posture is already live and CCTV is still only a confirmation step • chronic drift • review reopened 2 times',
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('onyx-agent-thread-urgent-reason-thread-2')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey(
            'onyx-agent-planner-maintenance-focus-drift-cctvReview-tacticalTrack',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('Focused from the thread rail.'), findsOneWidget);
      expect(
        find.text(
          '1 planner maintenance alert active. Highest severity: chronic drift from archived watch. Top burn rate: review reopened 2 times. Urgent review active.',
        ),
        findsOneWidget,
      );
      expect(find.text('URGENT MAINTENANCE'), findsOneWidget);
      expect(
        find.textContaining('Urgent maintenance prioritized:'),
        findsOneWidget,
      );
      expect(find.text('OPERATOR FOCUS'), findsNothing);
      expect(
        find.byKey(const ValueKey('onyx-agent-operator-focus-banner')),
        findsNothing,
      );
      expect(find.text('Refresh priority'), findsOneWidget);
      expect(find.text('Planner maintenance review'), findsOneWidget);
      final prioritizedState = _expectPlannerDrivenThreadHandoff(
        sessionState,
        selectedThreadId: 'thread-2',
        expectedMessageCount: 2,
        expectedMessageHeadline: 'Planner maintenance review',
      );
      expect(
        (prioritizedState['planner_maintenance_review_prioritized_at_utc']
            as Map<String, dynamic>)[signalId],
        isNotEmpty,
      );

      await tester.enterText(
        find.byKey(const ValueKey('onyx-agent-composer-field')),
        'Summarize the urgent planner drift before we switch desks.',
      );
      await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey(
            'onyx-agent-planner-maintenance-focus-drift-cctvReview-tacticalTrack',
          ),
        ),
        findsNothing,
      );
      expect(find.text('Focused from the thread rail.'), findsNothing);
      expect(cloudBoostService.calls, 1);
      expect(
        cloudBoostService.lastContextSummary,
        contains(
          'Planner maintenance priority: Completed maintenance review for chronic drift from archived watch on Increase Tactical Track weighting when field posture is already live and CCTV is still only a confirmation step has gone stale after the drift worsened again.',
        ),
      );
      expect(
        cloudBoostService.lastContextSummary,
        contains('Primary pressure: planner maintenance.'),
      );
      expect(
        find.textContaining(
          'Top maintenance pressure: Completed maintenance review for chronic drift from archived watch on Increase Tactical Track weighting when field posture is already live and CCTV is still only a confirmation step has gone stale after the drift worsened again.',
        ),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'onyx agent page clears planner shortcut focus after a direct resume route open',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      String? resumedTrackIncident;
      Map<String, Object?>? sessionState;
      const signalId = 'drift:cctvReview:tacticalTrack';
      final reactivatedAt = DateTime.now().toUtc().subtract(
        const Duration(minutes: 30),
      );
      final reviewQueuedAt = reactivatedAt.add(const Duration(minutes: 2));
      final reviewCompletedAt = reviewQueuedAt.add(const Duration(minutes: 4));
      final reviewReopenedAt = reviewCompletedAt.add(
        const Duration(minutes: 6),
      );
      final prioritizedAt = reviewReopenedAt.add(const Duration(minutes: 1));
      final seededState = <String, Object?>{
        'version': 7,
        'thread_counter': 2,
        'selected_thread_id': 'thread-1',
        'planner_backlog_scores': <String, Object?>{signalId: 2},
        'planner_backlog_reactivated_signal_counts': <String, Object?>{
          signalId: 2,
        },
        'planner_backlog_reactivation_counts': <String, Object?>{signalId: 4},
        'planner_backlog_last_reactivated_at_utc': <String, Object?>{
          signalId: reactivatedAt.toIso8601String(),
        },
        'planner_maintenance_review_queued_at_utc': <String, Object?>{
          signalId: reviewReopenedAt.toIso8601String(),
        },
        'planner_maintenance_review_completed_at_utc': <String, Object?>{
          signalId: reviewCompletedAt.toIso8601String(),
        },
        'planner_maintenance_review_prioritized_at_utc': <String, Object?>{
          signalId: prioritizedAt.toIso8601String(),
        },
        'planner_maintenance_review_completed_signal_counts': <String, Object?>{
          signalId: 3,
        },
        'planner_maintenance_review_completed_reactivation_counts':
            <String, Object?>{signalId: 4},
        'planner_maintenance_review_reopened_counts': <String, Object?>{
          signalId: 1,
        },
        'planner_signal_snapshot': <String, Object?>{
          'signal_counts': <String, Object?>{signalId: 4},
          'captured_at_utc': DateTime.utc(2026, 3, 31, 8, 18).toIso8601String(),
        },
        'previous_planner_signal_snapshot': <String, Object?>{
          'signal_counts': <String, Object?>{signalId: 3},
          'captured_at_utc': DateTime.utc(2026, 3, 31, 8, 12).toIso8601String(),
        },
        'threads': <Object?>[
          <String, Object?>{
            'id': 'thread-1',
            'title': 'Client reassurance',
            'summary': 'No urgent planner drift on this thread.',
            'memory': <String, Object?>{},
            'messages': <Object?>[
              <String, Object?>{
                'id': 'msg-0',
                'kind': 'agent',
                'persona_id': 'main',
                'headline': 'Client reassurance ready',
                'body': 'No operational drift is attached to this thread.',
                'created_at_utc': DateTime.utc(
                  2026,
                  3,
                  31,
                  8,
                  10,
                ).toIso8601String(),
              },
            ],
          },
          <String, Object?>{
            'id': 'thread-2',
            'title': 'Track drift warning',
            'summary': 'Typed triage kept Tactical Track.',
            'memory': <String, Object?>{
              'last_recommended_target': 'tacticalTrack',
              'second_look_conflict_count': 4,
              'last_second_look_conflict_summary':
                  'OpenAI second look: kept Tactical Track over CCTV Review.',
              'second_look_model_target_counts': <String, Object?>{
                'cctvReview': 4,
              },
              'second_look_typed_target_counts': <String, Object?>{
                'tacticalTrack': 4,
              },
              'updated_at_utc': DateTime.utc(
                2026,
                3,
                31,
                8,
                18,
              ).toIso8601String(),
            },
            'messages': <Object?>[
              <String, Object?>{
                'id': 'msg-1',
                'kind': 'agent',
                'persona_id': 'policy',
                'headline': 'Typed triage overruled the model suggestion',
                'body': 'Typed triage kept Tactical Track as the active desk.',
                'created_at_utc': DateTime.utc(
                  2026,
                  3,
                  31,
                  8,
                  18,
                ).toIso8601String(),
              },
            ],
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-CTRL-891',
            sourceRouteLabel: 'Track',
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            initialThreadSessionState: seededState,
            onOpenTrackForIncident: (incidentReference) {
              resumedTrackIncident = incidentReference;
            },
            onThreadSessionStateChanged: (state) {
              sessionState = state;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('onyx-agent-thread-urgent-reason-thread-2')),
      );
      await tester.pump();

      expect(
        find.byKey(
          const ValueKey(
            'onyx-agent-planner-maintenance-focus-drift-cctvReview-tacticalTrack',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('Focused from the thread rail.'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('onyx-agent-resume-track-button')),
      );
      await tester.pumpAndSettle();

      expect(resumedTrackIncident, 'INC-CTRL-891');
      expect(
        find.byKey(
          const ValueKey(
            'onyx-agent-planner-maintenance-focus-drift-cctvReview-tacticalTrack',
          ),
        ),
        findsNothing,
      );
      expect(find.text('Focused from the thread rail.'), findsNothing);
      expect(sessionState, isNotNull);
      final persistedState =
          jsonDecode(jsonEncode(sessionState)) as Map<String, dynamic>;
      expect(persistedState['selected_thread_id'], 'thread-2');
      expect(persistedState['selected_thread_operator_id'], 'thread-2');
      expect(persistedState['selected_thread_operator_at_utc'], isNotEmpty);
    },
  );

  testWidgets(
    'onyx agent page keeps explicit operator thread selection on restore even with urgent maintenance',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const signalId = 'drift:cctvReview:tacticalTrack';
      final localBrainService = _RecordingLocalBrainService();
      Map<String, Object?>? sessionState;
      final reactivatedAt = DateTime.now().toUtc().subtract(
        const Duration(minutes: 30),
      );
      final reviewCompletedAt = reactivatedAt.add(const Duration(minutes: 4));
      final reviewReopenedAt = reviewCompletedAt.add(
        const Duration(minutes: 6),
      );
      final prioritizedAt = reviewReopenedAt.add(const Duration(minutes: 1));
      final operatorSelectedAt = prioritizedAt.add(const Duration(minutes: 1));
      final seededState = <String, Object?>{
        'version': 7,
        'thread_counter': 1,
        'selected_thread_id': 'thread-2',
        'selected_thread_operator_id': 'thread-1',
        'selected_thread_operator_at_utc': operatorSelectedAt.toIso8601String(),
        'planner_backlog_scores': <String, Object?>{signalId: 2},
        'planner_backlog_reactivated_signal_counts': <String, Object?>{
          signalId: 2,
        },
        'planner_backlog_reactivation_counts': <String, Object?>{signalId: 4},
        'planner_backlog_last_reactivated_at_utc': <String, Object?>{
          signalId: reactivatedAt.toIso8601String(),
        },
        'planner_maintenance_review_queued_at_utc': <String, Object?>{
          signalId: reviewReopenedAt.toIso8601String(),
        },
        'planner_maintenance_review_completed_at_utc': <String, Object?>{
          signalId: reviewCompletedAt.toIso8601String(),
        },
        'planner_maintenance_review_prioritized_at_utc': <String, Object?>{
          signalId: prioritizedAt.toIso8601String(),
        },
        'planner_maintenance_review_completed_signal_counts': <String, Object?>{
          signalId: 3,
        },
        'planner_maintenance_review_completed_reactivation_counts':
            <String, Object?>{signalId: 4},
        'planner_maintenance_review_reopened_counts': <String, Object?>{
          signalId: 2,
        },
        'planner_signal_snapshot': <String, Object?>{
          'signal_counts': <String, Object?>{signalId: 4},
          'captured_at_utc': DateTime.utc(2026, 3, 31, 8, 18).toIso8601String(),
        },
        'previous_planner_signal_snapshot': <String, Object?>{
          'signal_counts': <String, Object?>{signalId: 3},
          'captured_at_utc': DateTime.utc(2026, 3, 31, 8, 12).toIso8601String(),
        },
        'threads': <Object?>[
          <String, Object?>{
            'id': 'thread-1',
            'title': 'Client reassurance',
            'summary': 'No urgent planner drift on this thread.',
            'memory': <String, Object?>{
              'last_recommended_target': 'clientComms',
              'last_operator_focus_note':
                  'manual context preserved on Client reassurance while urgent review remains visible on Track drift warning.',
              'updated_at_utc': DateTime.utc(
                2026,
                3,
                31,
                8,
                10,
              ).toIso8601String(),
            },
            'messages': <Object?>[
              <String, Object?>{
                'id': 'msg-0',
                'kind': 'agent',
                'persona_id': 'main',
                'headline': 'Client reassurance ready',
                'body': 'No operational drift is attached to this thread.',
                'created_at_utc': DateTime.utc(
                  2026,
                  3,
                  31,
                  8,
                  10,
                ).toIso8601String(),
              },
            ],
          },
          <String, Object?>{
            'id': 'thread-2',
            'title': 'Track drift warning',
            'summary': 'Typed triage kept Tactical Track.',
            'memory': <String, Object?>{
              'last_recommended_target': 'tacticalTrack',
              'second_look_conflict_count': 4,
              'last_second_look_conflict_summary':
                  'OpenAI second look: kept Tactical Track over CCTV Review.',
              'second_look_model_target_counts': <String, Object?>{
                'cctvReview': 4,
              },
              'second_look_typed_target_counts': <String, Object?>{
                'tacticalTrack': 4,
              },
              'updated_at_utc': DateTime.utc(
                2026,
                3,
                31,
                8,
                18,
              ).toIso8601String(),
            },
            'messages': <Object?>[
              <String, Object?>{
                'id': 'msg-1',
                'kind': 'agent',
                'persona_id': 'policy',
                'headline': 'Typed triage overruled the model suggestion',
                'body': 'Typed triage kept Tactical Track as the active desk.',
                'created_at_utc': DateTime.utc(
                  2026,
                  3,
                  31,
                  8,
                  18,
                ).toIso8601String(),
              },
            ],
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-CTRL-891',
            sourceRouteLabel: 'Track',
            cloudAssistAvailable: true,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            localBrainService: localBrainService,
            cloudBoostService: _RecordingCloudBoostService(),
            initialThreadSessionState: seededState,
            onThreadSessionStateChanged: (state) {
              sessionState = state;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Client reassurance ready'), findsOneWidget);
      expect(
        find.text('Typed triage overruled the model suggestion'),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('onyx-agent-restored-pressure-banner')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('onyx-agent-thread-pressure-focus-thread-1')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('onyx-agent-thread-operator-focus-thread-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('onyx-agent-operator-focus-banner')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('onyx-agent-operator-focus-banner-tag')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('onyx-agent-operator-focus-banner-urgent-tag'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('onyx-agent-thread-operator-note-thread-1')),
        findsOneWidget,
      );
      final threadMemoryLabel = tester.widget<Text>(
        find.byKey(const ValueKey('onyx-agent-thread-memory-thread-1')),
      );
      expect(threadMemoryLabel.data, contains('manual focus held'));
      expect(threadMemoryLabel.data, contains('primary operator focus'));
      expect(
        find.textContaining('Primary: operator focus hold.'),
        findsOneWidget,
      );
      expect(
        find.text('Manual context preserved over urgent review.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Manual operator context is active here. ONYX kept focus on this thread while urgent review stays visible on Track drift warning.',
        ),
        findsOneWidget,
      );
      expect(find.text('URGENT REVIEW'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('onyx-agent-thread-urgent-reason-thread-2')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('onyx-agent-composer-field')),
        'What should I do next?',
      );
      await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
      await tester.pumpAndSettle();

      expect(sessionState, isNotNull);
      final typedPersistedState =
          jsonDecode(jsonEncode(sessionState)) as Map<String, dynamic>;
      final typedPersistedThreads =
          (typedPersistedState['threads'] as List<dynamic>)
              .cast<Map<String, dynamic>>();
      final typedPersistedThread = typedPersistedThreads.firstWhere(
        (thread) => thread['id'] == 'thread-1',
      );
      final typedPersistedMemory =
          typedPersistedThread['memory'] as Map<String, dynamic>;
      expect(
        typedPersistedMemory['last_operator_focus_note'],
        'manual context preserved on What should I do next? while urgent review remains visible on Track drift warning.',
      );
      expect(
        typedPersistedMemory['last_primary_pressure'],
        'planner maintenance',
      );

      await tester.enterText(
        find.byKey(const ValueKey('onyx-agent-composer-field')),
        'Summarize the manual thread context before we switch desks.',
      );
      await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
      await tester.pumpAndSettle();

      expect(localBrainService.calls, 1);
      expect(localBrainService.lastContextSummary, isNotNull);
      expect(
        localBrainService.lastContextSummary,
        contains(
          'Operator focus preserved on What should I do next? while urgent review remains visible on Track drift warning.',
        ),
      );
      expect(
        localBrainService.lastContextSummary,
        contains(
          'Planner maintenance priority: Completed maintenance review for chronic drift from archived watch on Increase Tactical Track weighting when field posture is already live and CCTV is still only a confirmation step has gone stale after the drift worsened again.',
        ),
      );
      expect(
        localBrainService.lastContextSummary,
        contains('Primary pressure: planner maintenance.'),
      );
      expect(
        find.textContaining(
          'Top maintenance pressure: Completed maintenance review for chronic drift from archived watch on Increase Tactical Track weighting when field posture is already live and CCTV is still only a confirmation step has gone stale after the drift worsened again.',
        ),
        findsNWidgets(2),
      );
      expect(
        find.textContaining(
          'Operator focus: manual context preserved on What should I do next? while urgent review remains visible on Track drift warning.',
        ),
        findsOneWidget,
      );
      expect(localBrainService.lastScope, isNotNull);
      expect(localBrainService.lastScope!.operatorFocusPreserved, isTrue);
      expect(
        localBrainService.lastScope!.operatorFocusThreadTitle,
        'What should I do next?',
      );
      expect(
        localBrainService.lastScope!.operatorFocusUrgentThreadTitle,
        'Track drift warning',
      );
      expect(sessionState, isNotNull);
      final persistedState =
          jsonDecode(jsonEncode(sessionState)) as Map<String, dynamic>;
      final persistedThreads = (persistedState['threads'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final persistedThread = persistedThreads.firstWhere(
        (thread) => thread['id'] == 'thread-1',
      );
      final persistedMemory = persistedThread['memory'] as Map<String, dynamic>;
      expect(
        persistedMemory['last_operator_focus_note'],
        'manual context preserved on What should I do next? while urgent review remains visible on Track drift warning.',
      );
      expect(persistedMemory['last_primary_pressure'], 'planner maintenance');

      await tester.enterText(
        find.byKey(const ValueKey('onyx-agent-composer-field')),
        'Summarize the thread memory state again.',
      );
      await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
      await tester.pumpAndSettle();

      expect(localBrainService.calls, 2);
      expect(
        localBrainService.lastContextSummary,
        contains(
          'Thread memory operator focus: manual context preserved on What should I do next? while urgent review remains visible on Track drift warning.',
        ),
      );
    },
  );

  testWidgets('onyx agent page appends OpenAI brain boost when enabled', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final cloudBoostService = _RecordingCloudBoostService();
    var openedCctv = false;

    await tester.pumpWidget(
      MaterialApp(
        home: OnyxAgentPage(
          scopeClientId: 'CLIENT-001',
          scopeSiteId: 'SITE-SANDTON',
          focusIncidentReference: 'INC-CTRL-99',
          sourceRouteLabel: 'Command',
          cloudAssistAvailable: true,
          cameraChangeService: _FakeCameraChangeService(),
          cameraProbeService: _FakeCameraProbeService(),
          clientDraftService: _FakeClientDraftService(),
          localBrainService: _FakeLocalBrainService(),
          cloudBoostService: cloudBoostService,
          onOpenCctv: () {
            openedCctv = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('onyx-agent-composer-field')),
      'Correlate CCTV Review, Tactical Track, and Dispatch Board signals for the active incident',
    );
    await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
    await tester.pumpAndSettle();

    expect(cloudBoostService.calls, 1);
    expect(
      cloudBoostService.lastPrompt,
      'Correlate CCTV Review, Tactical Track, and Dispatch Board signals for the active incident',
    );
    expect(cloudBoostService.lastIntent, OnyxAgentCloudIntent.correlation);
    final messageList = find.byKey(const ValueKey('onyx-agent-message-list'));
    final recommendedDesk = find.textContaining(
      'Recommended desk: CCTV Review',
    );
    for (
      var attempt = 0;
      attempt < 5 && recommendedDesk.evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(messageList, const Offset(0, -280));
      await tester.pumpAndSettle();
    }
    final confidenceLabel = find.textContaining(
      'Confidence: 82% high confidence',
    );
    for (
      var attempt = 0;
      attempt < 5 && confidenceLabel.evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(messageList, const Offset(0, -280));
      await tester.pumpAndSettle();
    }
    expect(recommendedDesk, findsOneWidget);
    expect(confidenceLabel, findsOneWidget);
    expect(
      find.byKey(const ValueKey('onyx-agent-action-brain-open-cctvReview')),
      findsOneWidget,
    );
    expect(
      find.textContaining('Last recommendation: CCTV Review.'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('onyx-agent-action-brain-open-cctvReview')),
    );
    await tester.pumpAndSettle();

    expect(openedCctv, isTrue);
    expect(
      find.textContaining('Last opened desk: CCTV Review.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'onyx agent page clears the local brain latch when synthesis fails',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final localBrainService = _ThrowingLocalBrainService();

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-CTRL-LOCAL-FAIL',
            sourceRouteLabel: 'Track',
            cloudAssistAvailable: false,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            localBrainService: localBrainService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('onyx-agent-composer-field')),
        'Correlate CCTV Review, Tactical Track, and Dispatch Board signals for the active incident',
      );
      await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
      await tester.pumpAndSettle();

      expect(localBrainService.calls, 1);
      expect(find.text('Send'), findsOneWidget);
      expect(find.text('Thinking...'), findsNothing);
    },
  );

  testWidgets('onyx agent page surfaces local brain error responses', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final localBrainService = _ErrorLocalBrainService();

    await tester.pumpWidget(
      MaterialApp(
        home: OnyxAgentPage(
          scopeClientId: 'CLIENT-001',
          scopeSiteId: 'SITE-SANDTON',
          focusIncidentReference: 'INC-CTRL-LOCAL-ERROR',
          sourceRouteLabel: 'Track',
          cloudAssistAvailable: false,
          cameraChangeService: _FakeCameraChangeService(),
          cameraProbeService: _FakeCameraProbeService(),
          clientDraftService: _FakeClientDraftService(),
          localBrainService: localBrainService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('onyx-agent-composer-field')),
      'Correlate CCTV Review, Tactical Track, and Dispatch Board signals for the active incident',
    );
    await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
    await tester.pumpAndSettle();

    expect(localBrainService.calls, 1);
    final messageList = find.byKey(const ValueKey('onyx-agent-message-list'));
    final errorHeadline = find.text('Local brain unavailable');
    for (
      var attempt = 0;
      attempt < 5 && errorHeadline.evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(messageList, const Offset(0, -280));
      await tester.pumpAndSettle();
    }
    final providerDetail = find.textContaining(
      'Provider detail: Provider returned HTTP 503.',
    );
    for (
      var attempt = 0;
      attempt < 5 && providerDetail.evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(messageList, const Offset(0, -280));
      await tester.pumpAndSettle();
    }
    expect(errorHeadline, findsOneWidget);
    expect(
      find.textContaining('The local model pass could not complete'),
      findsOneWidget,
    );
    expect(providerDetail, findsOneWidget);
    expect(find.text('Thinking...'), findsNothing);
  });

  testWidgets('onyx agent page clears the cloud boost latch when boost fails', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final cloudBoostService = _ThrowingCloudBoostService();

    await tester.pumpWidget(
      MaterialApp(
        home: OnyxAgentPage(
          scopeClientId: 'CLIENT-001',
          scopeSiteId: 'SITE-SANDTON',
          focusIncidentReference: 'INC-CTRL-CLOUD-FAIL',
          sourceRouteLabel: 'Command',
          cloudAssistAvailable: true,
          cameraChangeService: _FakeCameraChangeService(),
          cameraProbeService: _FakeCameraProbeService(),
          clientDraftService: _FakeClientDraftService(),
          localBrainService: _FakeLocalBrainService(),
          cloudBoostService: cloudBoostService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('onyx-agent-composer-field')),
      'Correlate CCTV Review, Tactical Track, and Dispatch Board signals for the active incident',
    );
    await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
    await tester.pumpAndSettle();

    expect(cloudBoostService.calls, 1);
    expect(find.text('Send'), findsOneWidget);
    expect(find.text('Thinking...'), findsNothing);
  });

  testWidgets('onyx agent page surfaces cloud boost error responses', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final cloudBoostService = _ErrorCloudBoostService();

    await tester.pumpWidget(
      MaterialApp(
        home: OnyxAgentPage(
          scopeClientId: 'CLIENT-001',
          scopeSiteId: 'SITE-SANDTON',
          focusIncidentReference: 'INC-CTRL-CLOUD-ERROR',
          sourceRouteLabel: 'Command',
          cloudAssistAvailable: true,
          cameraChangeService: _FakeCameraChangeService(),
          cameraProbeService: _FakeCameraProbeService(),
          clientDraftService: _FakeClientDraftService(),
          localBrainService: _FakeLocalBrainService(),
          cloudBoostService: cloudBoostService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('onyx-agent-composer-field')),
      'Correlate CCTV Review, Tactical Track, and Dispatch Board signals for the active incident',
    );
    await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
    await tester.pumpAndSettle();

    expect(cloudBoostService.calls, 1);
    final messageList = find.byKey(const ValueKey('onyx-agent-message-list'));
    final errorHeadline = find.text('OpenAI boost unavailable');
    for (
      var attempt = 0;
      attempt < 5 && errorHeadline.evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(messageList, const Offset(0, -280));
      await tester.pumpAndSettle();
    }
    final providerDetail = find.textContaining(
      'Provider detail: Provider returned HTTP 503.',
    );
    for (
      var attempt = 0;
      attempt < 5 && providerDetail.evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(messageList, const Offset(0, -280));
      await tester.pumpAndSettle();
    }
    expect(errorHeadline, findsOneWidget);
    expect(
      find.textContaining('The OpenAI brain boost could not complete'),
      findsOneWidget,
    );
    expect(providerDetail, findsOneWidget);
    expect(find.text('Thinking...'), findsNothing);
  });

  testWidgets(
    'onyx agent page sends typed triage prompts to cloud second look as correlation intent',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final cloudBoostService = _RecordingCloudBoostService();

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-CTRL-101',
            sourceRouteLabel: 'Command',
            cloudAssistAvailable: true,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            localBrainService: _FakeLocalBrainService(),
            cloudBoostService: cloudBoostService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('onyx-agent-composer-field')),
        "What's happening now?",
      );
      await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
      await tester.pumpAndSettle();

      expect(cloudBoostService.calls, 1);
      expect(cloudBoostService.lastPrompt, "What's happening now?");
      expect(cloudBoostService.lastIntent, OnyxAgentCloudIntent.correlation);
    },
  );

  testWidgets(
    'onyx agent page keeps typed triage active when the second look fails',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final cloudBoostService = _ThrowingCloudBoostService();
      final events = <DispatchEvent>[
        DecisionCreated(
          eventId: 'evt-1',
          sequence: 1,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 0),
          dispatchId: 'INC-CTRL-STRUCTURED-FAIL',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-SANDTON',
        ),
        ResponseArrived(
          eventId: 'evt-2',
          sequence: 2,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 4),
          dispatchId: 'INC-CTRL-STRUCTURED-FAIL',
          guardId: 'GUARD-9',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-SANDTON',
        ),
        PatrolCompleted(
          eventId: 'evt-3',
          sequence: 3,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 6),
          guardId: 'GUARD-9',
          routeId: 'ROUTE-ALPHA',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-SANDTON',
          durationSeconds: 960,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-CTRL-STRUCTURED-FAIL',
            sourceRouteLabel: 'Track',
            cloudAssistAvailable: true,
            events: events,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            localBrainService: _FakeLocalBrainService(),
            cloudBoostService: cloudBoostService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('onyx-agent-composer-field')),
        'Triage the active incident and stage one obvious next move',
      );
      await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
      await tester.pumpAndSettle();

      expect(cloudBoostService.calls, 1);
      expect(find.text('Send'), findsOneWidget);
      expect(find.text('Thinking...'), findsNothing);
      final messageList = find.byKey(const ValueKey('onyx-agent-message-list'));
      final triageSummary = find.textContaining(
        'One next move is staged in Tactical Track.',
      );
      for (
        var attempt = 0;
        attempt < 6 && triageSummary.evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(messageList, const Offset(0, -280));
        await tester.pumpAndSettle();
      }
      expect(triageSummary, findsWidgets);
    },
  );

  testWidgets('onyx agent page shows local camera bridge bind status', (
    tester,
  ) async {
    String? copiedPayload;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>;
          copiedPayload = args['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: OnyxAgentPage(
          scopeClientId: 'CLIENT-001',
          scopeSiteId: 'SITE-SANDTON',
          focusIncidentReference: 'INC-CTRL-44',
          cameraBridgeStatus: OnyxAgentCameraBridgeStatus(
            enabled: true,
            running: true,
            authRequired: true,
            endpoint: Uri.parse('http://127.0.0.1:11634'),
            statusLabel: 'Live',
            detail:
                'Listening locally for approved camera execution packets and health probes through the embedded ONYX bridge.',
          ),
          cameraBridgeHealthSnapshot: OnyxAgentCameraBridgeHealthSnapshot(
            requestedEndpoint: Uri.parse('http://127.0.0.1:11634'),
            healthEndpoint: Uri.parse('http://127.0.0.1:11634/health'),
            reportedEndpoint: Uri.parse('http://127.0.0.1:11634'),
            reachable: true,
            running: true,
            statusCode: 200,
            statusLabel: 'Healthy',
            detail:
                'GET /health succeeded and the bridge reported packet ingress ready.',
            executePath: '/execute',
            checkedAtUtc: _freshBridgeCheckedAtUtc(),
            operatorId: 'CONTROL-09',
          ),
          cameraChangeService: _FakeCameraChangeService(),
          cameraProbeService: _FakeCameraProbeService(),
          clientDraftService: _FakeClientDraftService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('onyx-agent-camera-bridge-status')),
      findsOneWidget,
    );
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text('AUTH REQUIRED'), findsOneWidget);
    expect(find.textContaining('http://127.0.0.1:11634'), findsWidgets);
    expect(find.textContaining('POST /execute'), findsOneWidget);
    expect(find.textContaining('Bearer token required'), findsOneWidget);

    final copyBridgeButton = find.byKey(
      const ValueKey('onyx-agent-camera-bridge-copy'),
    );
    await tester.ensureVisible(copyBridgeButton);
    await tester.tap(copyBridgeButton);
    await tester.pumpAndSettle();

    expect(copiedPayload, isNotNull);
    expect(copiedPayload, contains('ONYX CAMERA BRIDGE'));
    expect(copiedPayload, contains('Status: LIVE'));
    expect(copiedPayload, contains('Bind: http://127.0.0.1:11634'));
    expect(copiedPayload, contains('POST http://127.0.0.1:11634/execute'));
    expect(copiedPayload, contains('Auth: Bearer token required'));
    expect(copiedPayload, contains('Validation: HEALTHY'));
    expect(
      copiedPayload,
      contains('Health: GET http://127.0.0.1:11634/health'),
    );
    expect(copiedPayload, contains('Shell state: READY'));
    expect(
      copiedPayload,
      contains(
        'Shell summary: LAN workers can target http://127.0.0.1:11634/execute and poll http://127.0.0.1:11634/health right now.',
      ),
    );
    expect(copiedPayload, contains('Receipt state: CURRENT'));
    expect(copiedPayload, contains('Validated at:'));
    expect(copiedPayload, contains('Validated by: CONTROL-09'));
    expect(find.text('Camera bridge setup copied.'), findsOneWidget);
  });

  testWidgets(
    'onyx agent page refreshes local camera bridge status when parent snapshot changes',
    (tester) async {
      String? copiedPayload;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<dynamic, dynamic>;
            copiedPayload = args['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Widget buildPage(OnyxAgentCameraBridgeHealthSnapshot snapshot) {
        return MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-CTRL-44',
            cameraBridgeStatus: OnyxAgentCameraBridgeStatus(
              enabled: true,
              running: true,
              authRequired: true,
              endpoint: Uri.parse('http://127.0.0.1:11634'),
              statusLabel: 'Live',
              detail:
                  'Listening locally for approved camera execution packets and health probes through the embedded ONYX bridge.',
            ),
            cameraBridgeHealthSnapshot: snapshot,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
          ),
        );
      }

      await tester.pumpWidget(
        buildPage(
          OnyxAgentCameraBridgeHealthSnapshot(
            requestedEndpoint: Uri.parse('http://127.0.0.1:11634'),
            healthEndpoint: Uri.parse('http://127.0.0.1:11634/health'),
            reportedEndpoint: Uri.parse('http://127.0.0.1:11634'),
            reachable: true,
            running: true,
            statusCode: 200,
            statusLabel: 'Healthy',
            detail:
                'GET /health succeeded and the bridge reported packet ingress ready.',
            executePath: '/execute',
            checkedAtUtc: _freshBridgeCheckedAtUtc(),
            operatorId: 'CONTROL-09',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        buildPage(
          OnyxAgentCameraBridgeHealthSnapshot(
            requestedEndpoint: Uri.parse('http://127.0.0.1:11634'),
            healthEndpoint: Uri.parse('http://127.0.0.1:11634/health'),
            reportedEndpoint: Uri.parse('http://127.0.0.1:11634'),
            reachable: true,
            running: true,
            statusCode: 503,
            statusLabel: 'Degraded',
            detail: 'GET /health failed during the latest validation attempt.',
            executePath: '/execute',
            checkedAtUtc: _freshBridgeCheckedAtUtc(),
            operatorId: 'CONTROL-10',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final copyBridgeButton = find.byKey(
        const ValueKey('onyx-agent-camera-bridge-copy'),
      );
      await tester.ensureVisible(copyBridgeButton);
      await tester.tap(copyBridgeButton);
      await tester.pumpAndSettle();

      expect(copiedPayload, contains('Validation: DEGRADED'));
      expect(copiedPayload, contains('Validated by: CONTROL-10'));
    },
  );

  testWidgets(
    'onyx agent page does not surface receipt state when camera bridge is not live',
    (tester) async {
      String? copiedPayload;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<dynamic, dynamic>;
            copiedPayload = args['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-CTRL-DISABLED-1',
            cameraBridgeStatus: OnyxAgentCameraBridgeStatus(
              enabled: false,
              running: false,
              authRequired: true,
              endpoint: Uri.parse('http://127.0.0.1:11634'),
              statusLabel: 'Disabled',
              detail:
                  'Local listener is off. Enable the bridge server to accept POST /execute and GET /health for LAN camera workers.',
            ),
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('RECEIPT UNAVAILABLE'), findsNothing);
      expect(find.text('UNVALIDATED'), findsNothing);
      expect(find.text('RECENT RECEIPT'), findsNothing);
      expect(find.text('STALE RECEIPT'), findsNothing);
      expect(
        find.textContaining(
          'Local camera bridge visibility stays here so camera tools never have to fall back into a hidden legacy workspace.',
        ),
        findsOneWidget,
      );

      final copyBridgeButton = find.byKey(
        const ValueKey('onyx-agent-camera-bridge-copy'),
      );
      await tester.ensureVisible(copyBridgeButton);
      await tester.tap(copyBridgeButton);
      await tester.pumpAndSettle();

      expect(copiedPayload, contains('Status: DISABLED'));
      expect(copiedPayload, contains('Shell state: DISABLED'));
      expect(
        copiedPayload,
        contains(
          'Shell summary: Enable the local camera bridge if you want LAN workers to post packets into ONYX.',
        ),
      );
      expect(copiedPayload, isNot(contains('Receipt state:')));
      expect(copiedPayload, isNot(contains('Validation:')));
    },
  );

  testWidgets('onyx agent page validates local camera bridge health', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: OnyxAgentPage(
          scopeClientId: 'CLIENT-001',
          scopeSiteId: 'SITE-SANDTON',
          focusIncidentReference: 'INC-CTRL-44',
          cameraBridgeStatus: OnyxAgentCameraBridgeStatus(
            enabled: true,
            running: true,
            authRequired: true,
            endpoint: Uri.parse('http://127.0.0.1:11634'),
            statusLabel: 'Live',
            detail:
                'Listening locally for approved camera execution packets and health probes through the embedded ONYX bridge.',
          ),
          cameraBridgeHealthService: const _FakeCameraBridgeHealthService(),
          cameraChangeService: _FakeCameraChangeService(),
          cameraProbeService: _FakeCameraProbeService(),
          clientDraftService: _FakeClientDraftService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final validateButton = find.byKey(
      const ValueKey('onyx-agent-camera-bridge-validate'),
    );
    await tester.ensureVisible(validateButton);
    await tester.tap(validateButton);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('onyx-agent-camera-bridge-health-result')),
      findsOneWidget,
    );
    expect(find.text('HEALTHY'), findsOneWidget);
    expect(find.textContaining('HTTP: 200'), findsOneWidget);
    expect(find.textContaining('Receipt state: CURRENT'), findsOneWidget);
    expect(
      find.textContaining('GET http://127.0.0.1:11634/health'),
      findsOneWidget,
    );
    expect(find.textContaining('Validated at:'), findsOneWidget);
    expect(
      find.textContaining('POST http://127.0.0.1:11634/execute'),
      findsOneWidget,
    );
    expect(find.textContaining('Validated by: OPERATOR-01'), findsOneWidget);
    expect(find.text('Camera bridge health check complete.'), findsOneWidget);
  });

  testWidgets('onyx agent page can clear stored camera bridge health receipt', (
    tester,
  ) async {
    var clearedCount = 0;
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: OnyxAgentPage(
          scopeClientId: 'CLIENT-001',
          scopeSiteId: 'SITE-SANDTON',
          focusIncidentReference: 'INC-CTRL-44',
          cameraBridgeStatus: OnyxAgentCameraBridgeStatus(
            enabled: true,
            running: true,
            authRequired: true,
            endpoint: Uri.parse('http://127.0.0.1:11634'),
            statusLabel: 'Live',
            detail:
                'Listening locally for approved camera execution packets and health probes through the embedded ONYX bridge.',
          ),
          cameraBridgeHealthSnapshot: OnyxAgentCameraBridgeHealthSnapshot(
            requestedEndpoint: Uri.parse('http://127.0.0.1:11634'),
            healthEndpoint: Uri.parse('http://127.0.0.1:11634/health'),
            reportedEndpoint: Uri.parse('http://127.0.0.1:11634'),
            reachable: true,
            running: true,
            statusCode: 200,
            statusLabel: 'Healthy',
            detail:
                'GET /health succeeded and the bridge reported packet ingress ready.',
            executePath: '/execute',
            checkedAtUtc: _freshBridgeCheckedAtUtc(),
            operatorId: 'CONTROL-07',
          ),
          cameraChangeService: _FakeCameraChangeService(),
          cameraProbeService: _FakeCameraProbeService(),
          clientDraftService: _FakeClientDraftService(),
          onClearCameraBridgeHealthSnapshot: () async {
            clearedCount += 1;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('onyx-agent-camera-bridge-health-result')),
      findsOneWidget,
    );
    expect(
      find.textContaining('GET http://127.0.0.1:11634/health'),
      findsOneWidget,
    );
    expect(find.textContaining('Validated at:'), findsOneWidget);
    expect(find.textContaining('Validated by: CONTROL-07'), findsOneWidget);

    final clearBridgeReceiptButton = find.byKey(
      const ValueKey('onyx-agent-camera-bridge-clear-health'),
    );
    await tester.ensureVisible(clearBridgeReceiptButton);
    await tester.tap(clearBridgeReceiptButton);
    await tester.pumpAndSettle();

    expect(clearedCount, 1);
    expect(
      find.byKey(const ValueKey('onyx-agent-camera-bridge-health-result')),
      findsNothing,
    );
    expect(find.text('Camera bridge health receipt cleared.'), findsOneWidget);
  });

  testWidgets('onyx agent page surfaces reported bind mismatch on bridge receipt', (
    tester,
  ) async {
    String? copiedPayload;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>;
          copiedPayload = args['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: OnyxAgentPage(
          scopeClientId: 'CLIENT-001',
          scopeSiteId: 'SITE-SANDTON',
          focusIncidentReference: 'INC-CTRL-44',
          cameraBridgeStatus: OnyxAgentCameraBridgeStatus(
            enabled: true,
            running: true,
            authRequired: true,
            endpoint: Uri.parse('http://127.0.0.1:11634'),
            statusLabel: 'Live',
            detail:
                'Listening locally for approved camera execution packets and health probes through the embedded ONYX bridge.',
          ),
          cameraBridgeHealthSnapshot: OnyxAgentCameraBridgeHealthSnapshot(
            requestedEndpoint: Uri.parse('http://127.0.0.1:11634'),
            healthEndpoint: Uri.parse('http://127.0.0.1:11634/health'),
            reportedEndpoint: Uri.parse('http://10.0.0.44:11634'),
            reachable: true,
            running: true,
            statusCode: 200,
            statusLabel: 'Healthy',
            detail:
                'GET /health succeeded and the bridge reported packet ingress ready. Bridge reported bind http://10.0.0.44:11634 while ONYX probed http://127.0.0.1:11634.',
            executePath: '/execute',
            checkedAtUtc: _freshBridgeCheckedAtUtc(),
            operatorId: 'CONTROL-88',
          ),
          cameraChangeService: _FakeCameraChangeService(),
          cameraProbeService: _FakeCameraProbeService(),
          clientDraftService: _FakeClientDraftService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Reported bind: http://10.0.0.44:11634'),
      findsOneWidget,
    );
    expect(find.textContaining('Receipt state: CURRENT'), findsOneWidget);
    expect(find.textContaining('Endpoint mismatch: Detected'), findsOneWidget);
    expect(find.text('BIND MISMATCH'), findsOneWidget);
    expect(
      find.textContaining(
        'Compare the probed and reported endpoints before handing this bridge to LAN workers.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Probed bind: http://127.0.0.1:11634'),
      findsOneWidget,
    );
    expect(
      find.textContaining('POST http://10.0.0.44:11634/execute'),
      findsOneWidget,
    );
    expect(
      find.textContaining('GET http://127.0.0.1:11634/health'),
      findsOneWidget,
    );

    final copyBridgeButton = find.byKey(
      const ValueKey('onyx-agent-camera-bridge-copy'),
    );
    await tester.ensureVisible(copyBridgeButton);
    await tester.tap(copyBridgeButton);
    await tester.pumpAndSettle();

    expect(copiedPayload, isNotNull);
    expect(copiedPayload, contains('Endpoint mismatch: DETECTED'));
    expect(copiedPayload, contains('Probed bind: http://127.0.0.1:11634'));
    expect(copiedPayload, contains('Reported bind: http://10.0.0.44:11634'));
    expect(
      copiedPayload,
      contains('Route: POST http://10.0.0.44:11634/execute'),
    );
  });

  testWidgets(
    'onyx agent page marks stale bridge validation in the summary shell',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-CTRL-STALE-1',
            sourceRouteLabel: 'AI Queue',
            cloudAssistAvailable: false,
            cameraBridgeStatus: OnyxAgentCameraBridgeStatus(
              enabled: true,
              running: true,
              authRequired: true,
              endpoint: Uri.parse('http://127.0.0.1:11634'),
              statusLabel: 'Live',
              detail:
                  'Listening locally for approved camera execution packets and health probes through the embedded ONYX bridge.',
            ),
            cameraBridgeHealthSnapshot: OnyxAgentCameraBridgeHealthSnapshot(
              requestedEndpoint: Uri.parse('http://127.0.0.1:11634'),
              healthEndpoint: Uri.parse('http://127.0.0.1:11634/health'),
              reportedEndpoint: Uri.parse('http://127.0.0.1:11634'),
              reachable: true,
              running: true,
              statusCode: 200,
              statusLabel: 'Healthy',
              detail:
                  'GET /health succeeded and the bridge reported packet ingress ready.',
              executePath: '/execute',
              checkedAtUtc: _staleBridgeCheckedAtUtc(),
              operatorId: 'CONTROL-STALE',
            ),
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('STALE RECEIPT'), findsOneWidget);
      expect(find.text('Re-Validate Bridge'), findsOneWidget);
      expect(find.textContaining('Last validation'), findsOneWidget);
      expect(
        find.textContaining('Re-run GET /health before trusting this receipt.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'onyx agent page marks live bridge as unvalidated when no receipt exists',
    (tester) async {
      String? copiedPayload;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<dynamic, dynamic>;
            copiedPayload = args['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-CTRL-UNVALIDATED-1',
            sourceRouteLabel: 'AI Queue',
            cloudAssistAvailable: false,
            cameraBridgeStatus: OnyxAgentCameraBridgeStatus(
              enabled: true,
              running: true,
              authRequired: true,
              endpoint: Uri.parse('http://127.0.0.1:11634'),
              statusLabel: 'Live',
              detail:
                  'Listening locally for approved camera execution packets and health probes through the embedded ONYX bridge.',
            ),
            cameraBridgeHealthService: const _FakeCameraBridgeHealthService(),
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('UNVALIDATED'), findsOneWidget);
      expect(find.text('Run First Validation'), findsOneWidget);
      expect(
        find.textContaining('no validation receipt has been captured yet'),
        findsWidgets,
      );
      expect(
        find.textContaining('Run GET /health before trusting this bridge.'),
        findsOneWidget,
      );

      final copyBridgeButton = find.byKey(
        const ValueKey('onyx-agent-camera-bridge-copy'),
      );
      await tester.ensureVisible(copyBridgeButton);
      await tester.tap(copyBridgeButton);
      await tester.pumpAndSettle();

      expect(copiedPayload, contains('Validation: NOT RUN'));
      expect(copiedPayload, contains('Receipt state: MISSING'));
    },
  );

  testWidgets(
    'onyx agent page marks live bridge receipt as unavailable when health probe is offline',
    (tester) async {
      String? copiedPayload;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<dynamic, dynamic>;
            copiedPayload = args['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-CTRL-UNAVAILABLE-1',
            sourceRouteLabel: 'AI Queue',
            cloudAssistAvailable: false,
            cameraBridgeStatus: OnyxAgentCameraBridgeStatus(
              enabled: true,
              running: true,
              authRequired: true,
              endpoint: Uri.parse('http://127.0.0.1:11634'),
              statusLabel: 'Live',
              detail:
                  'Listening locally for approved camera execution packets and health probes through the embedded ONYX bridge.',
            ),
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('RECEIPT UNAVAILABLE'), findsOneWidget);
      expect(
        find.textContaining('health probe is unavailable on this ONYX runtime'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Bridge validation receipt is unavailable on this ONYX runtime.',
        ),
        findsOneWidget,
      );

      final copyBridgeButton = find.byKey(
        const ValueKey('onyx-agent-camera-bridge-copy'),
      );
      await tester.ensureVisible(copyBridgeButton);
      await tester.tap(copyBridgeButton);
      await tester.pumpAndSettle();

      expect(copiedPayload, contains('Validation: UNAVAILABLE'));
      expect(copiedPayload, contains('Receipt state: UNAVAILABLE'));
    },
  );

  testWidgets('onyx agent page appends offline local model reasoning by default', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final localBrainService = _RecordingLocalBrainService();

    await tester.pumpWidget(
      MaterialApp(
        home: OnyxAgentPage(
          scopeClientId: 'CLIENT-001',
          scopeSiteId: 'SITE-SANDTON',
          focusIncidentReference: 'INC-CTRL-77',
          sourceRouteLabel: 'Track',
          cloudAssistAvailable: false,
          cameraChangeService: _FakeCameraChangeService(),
          cameraProbeService: _FakeCameraProbeService(),
          clientDraftService: _FakeClientDraftService(),
          localBrainService: localBrainService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('onyx-agent-composer-field')),
      'Correlate CCTV Review, Tactical Track, and Dispatch Board signals for the active incident',
    );
    await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
    await tester.pumpAndSettle();

    expect(localBrainService.calls, 1);
    expect(
      localBrainService.lastPrompt,
      'Correlate CCTV Review, Tactical Track, and Dispatch Board signals for the active incident',
    );
    expect(localBrainService.lastIntent, OnyxAgentCloudIntent.correlation);
    final messageList = find.byKey(const ValueKey('onyx-agent-message-list'));
    final recommendedDesk = find.textContaining(
      'Recommended desk: CCTV Review',
    );
    for (
      var attempt = 0;
      attempt < 5 && recommendedDesk.evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(messageList, const Offset(0, -280));
      await tester.pumpAndSettle();
    }
    final confidenceLabel = find.textContaining(
      'Confidence: 76% medium confidence',
    );
    for (
      var attempt = 0;
      attempt < 5 && confidenceLabel.evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(messageList, const Offset(0, -280));
      await tester.pumpAndSettle();
    }
    expect(recommendedDesk, findsOneWidget);
    expect(confidenceLabel, findsOneWidget);
    expect(
      find.byKey(const ValueKey('onyx-agent-action-brain-open-cctvReview')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('onyx-agent-composer-field')),
      'What still needs confirmation before we escalate?',
    );
    await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
    await tester.pumpAndSettle();

    expect(localBrainService.calls, 2);
    expect(
      localBrainService.lastContextSummary,
      contains('Thread memory last recommended CCTV Review.'),
    );
    expect(
      localBrainService.lastContextSummary,
      contains('Thread memory still needs fresh clip confirmation.'),
    );
    expect(
      localBrainService.lastContextSummary,
      contains('Primary pressure: unresolved follow-up.'),
    );
    expect(localBrainService.lastScope, isNotNull);
    expect(
      localBrainService.lastScope!.pendingFollowUpLabel,
      'RECHECK CCTV CONFIRMATION',
    );
    expect(localBrainService.lastScope!.pendingFollowUpStatus, 'unresolved');
    expect(
      localBrainService.lastScope!.pendingConfirmations,
      contains('fresh clip confirmation'),
    );
  });

  testWidgets(
    'onyx agent page orders visible context highlights by maintenance and follow-up priority',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-CTRL-77',
            sourceRouteLabel: 'Track',
            cloudAssistAvailable: false,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            localBrainService: const _PriorityOrderingLocalBrainService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('onyx-agent-composer-field')),
        'Correlate controller pressures for the active incident',
      );
      await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
      await tester.pumpAndSettle();

      final messageList = find.byKey(const ValueKey('onyx-agent-message-list'));
      final orderedContext = find.textContaining(
        'Context: Top maintenance pressure: Completed maintenance review for chronic drift from archived watch on Increase Tactical Track weighting. | Outstanding follow-up: RECHECK RESPONDER ETA (overdue). | Operator focus: preserving your current thread while urgent review stays visible in the rail. | Outstanding visual confirmation before escalation',
      );
      for (
        var attempt = 0;
        attempt < 5 && orderedContext.evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(messageList, const Offset(0, -280));
        await tester.pumpAndSettle();
      }

      expect(orderedContext, findsOneWidget);
      expect(
        find.descendant(
          of: messageList,
          matching: find.textContaining(
            'Primary pressure: planner maintenance.',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('onyx-agent-thread-memory-banner')),
          matching: find.textContaining(
            'Primary pressure: planner maintenance.',
          ),
        ),
        findsOneWidget,
      );
      final threadMemoryLabel = tester.widget<Text>(
        find.byKey(const ValueKey('onyx-agent-thread-memory-thread-1')),
      );
      expect(threadMemoryLabel.data, contains('primary maintenance'));
      expect(
        find.textContaining('Primary: planner maintenance.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'onyx agent page passes overdue follow-up memory into the local brain scope',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Map<String, Object?>? sessionState;
      final localBrainService = _RecordingLocalBrainService();
      final seededEvents = <DispatchEvent>[
        DecisionCreated(
          eventId: 'evt-1',
          sequence: 1,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 31, 8, 0),
          dispatchId: 'INC-42',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GP',
          siteId: 'SITE-SANDTON',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-42',
            sourceRouteLabel: 'Command',
            events: seededEvents,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            onThreadSessionStateChanged: (state) {
              sessionState = state;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('onyx-agent-composer-field')),
        'Status?',
      );
      await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
      await tester.pumpAndSettle();

      final staleSessionState =
          jsonDecode(jsonEncode(sessionState)) as Map<String, dynamic>;
      final staleThreads = (staleSessionState['threads'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final staleMemory = staleThreads.first['memory'] as Map<String, dynamic>;
      staleMemory['updated_at_utc'] = DateTime.now()
          .subtract(const Duration(minutes: 26))
          .toIso8601String();
      staleMemory['last_auto_follow_up_surfaced_at_utc'] = DateTime.now()
          .subtract(const Duration(minutes: 16))
          .toIso8601String();
      staleMemory['stale_follow_up_surface_count'] = 2;

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-42',
            sourceRouteLabel: 'Command',
            events: const <DispatchEvent>[],
            cloudAssistAvailable: false,
            initialThreadSessionState: staleSessionState
                .cast<String, Object?>(),
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            localBrainService: localBrainService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('onyx-agent-composer-field')),
        'What still needs confirmation before we escalate?',
      );
      await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
      await tester.pumpAndSettle();

      expect(localBrainService.calls, 1);
      expect(localBrainService.lastScope, isNotNull);
      expect(
        localBrainService.lastScope!.pendingFollowUpLabel,
        'RECHECK RESPONDER ETA',
      );
      expect(
        localBrainService.lastScope!.pendingFollowUpTarget,
        OnyxToolTarget.dispatchBoard,
      );
      expect(localBrainService.lastScope!.pendingFollowUpStatus, 'overdue');
      expect(
        localBrainService.lastScope!.pendingFollowUpAgeMinutes,
        greaterThanOrEqualTo(25),
      );
      expect(
        localBrainService.lastScope!.pendingFollowUpReopenCycles,
        greaterThanOrEqualTo(2),
      );
      expect(
        localBrainService.lastScope!.pendingConfirmations,
        contains('current responder ETA'),
      );
    },
  );

  testWidgets(
    'onyx agent page auto-routes report prompts to cloud when available',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final localBrainService = _RecordingLocalBrainService();
      final cloudBoostService = _RecordingCloudBoostService();

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-42',
            sourceRouteLabel: 'Reports',
            cloudAssistAvailable: true,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            localBrainService: localBrainService,
            cloudBoostService: cloudBoostService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('onyx-agent-composer-field')),
        'Draft the incident report summary and highlight the export proof we should retain for audit review.',
      );
      await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
      await tester.pumpAndSettle();

      expect(localBrainService.calls, 0);
      expect(cloudBoostService.calls, 1);
      expect(cloudBoostService.lastIntent, OnyxAgentCloudIntent.report);
    },
  );

  testWidgets(
    'onyx agent page keeps patrol prompts on the local brain when available',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final localBrainService = _RecordingLocalBrainService();
      final cloudBoostService = _RecordingCloudBoostService();

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-42',
            sourceRouteLabel: 'Track',
            cloudAssistAvailable: true,
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
            localBrainService: localBrainService,
            cloudBoostService: cloudBoostService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('onyx-agent-composer-field')),
        'Check patrol progress for Guard 7 on the north perimeter and confirm whether Track should stay warm.',
      );
      await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
      await tester.pumpAndSettle();

      expect(localBrainService.calls, 1);
      expect(localBrainService.lastIntent, OnyxAgentCloudIntent.patrol);
      expect(cloudBoostService.calls, 0);
    },
  );

  testWidgets('onyx agent page uses live camera probe tool action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: OnyxAgentPage(
          scopeClientId: 'CLIENT-001',
          scopeSiteId: 'SITE-SANDTON',
          focusIncidentReference: 'INC-CTRL-11',
          cameraChangeService: _FakeCameraChangeService(),
          cameraProbeService: _FakeCameraProbeService(),
          clientDraftService: _FakeClientDraftService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final messageList = find.byKey(const ValueKey('onyx-agent-message-list'));
    final seedProbeAction = find.byKey(
      const ValueKey('onyx-agent-action-thread-1-probe-camera'),
    );
    for (
      var attempt = 0;
      attempt < 5 && seedProbeAction.evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(messageList, const Offset(0, -280));
      await tester.pumpAndSettle();
    }
    await tester.tap(seedProbeAction);
    await tester.pumpAndSettle();

    final probeTargetAction = find.byKey(
      const ValueKey('onyx-agent-action-probe-192.168.1.64'),
    );
    for (
      var attempt = 0;
      attempt < 5 && probeTargetAction.evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(messageList, const Offset(0, -280));
      await tester.pumpAndSettle();
    }
    expect(probeTargetAction, findsOneWidget);
    await tester.tap(probeTargetAction);
    await tester.pumpAndSettle();

    expect(find.text('Local tool result'), findsOneWidget);
    expect(find.textContaining('HTTP 80: open'), findsOneWidget);
    expect(find.textContaining('ONVIF endpoint status: 401'), findsOneWidget);
  });

  testWidgets('onyx agent page uses live client draft tool action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? stagedDraftText;
    String? stagedOriginalDraftText;

    await tester.pumpWidget(
      MaterialApp(
        home: OnyxAgentPage(
          scopeClientId: 'CLIENT-001',
          scopeSiteId: 'SITE-SANDTON',
          focusIncidentReference: 'INC-CTRL-55',
          cameraChangeService: _FakeCameraChangeService(),
          cameraProbeService: _FakeCameraProbeService(),
          clientDraftService: _FakeClientDraftService(),
          onStageCommsDraft: (draftText, originalDraftText) {
            stagedDraftText = draftText;
            stagedOriginalDraftText = originalDraftText;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('onyx-agent-composer-field')),
      'Draft a client update for the current incident',
    );
    await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final refineDraftAction = find.byKey(
      const ValueKey('onyx-agent-action-draft-client-reply'),
    );
    final messageList = find.byKey(const ValueKey('onyx-agent-message-list'));
    for (
      var attempt = 0;
      attempt < 5 && refineDraftAction.evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(messageList, const Offset(0, -280));
      await tester.pumpAndSettle();
    }
    expect(refineDraftAction, findsOneWidget);

    await tester.ensureVisible(refineDraftAction);
    final draftReplyButton = tester.widget<OutlinedButton>(refineDraftAction);
    draftReplyButton.onPressed!.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final reopenCommsAction = find.byKey(
      const ValueKey('onyx-agent-action-refined-draft-open-comms'),
    );
    for (
      var attempt = 0;
      attempt < 5 && reopenCommsAction.evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(messageList, const Offset(0, -280));
      await tester.pumpAndSettle();
    }

    expect(
      find.textContaining('Telegram draft for CLIENT-001 / SITE-SANDTON'),
      findsOneWidget,
    );
    expect(find.textContaining('local:test-client-draft'), findsOneWidget);
    expect(
      find.textContaining(
        'Scoped handoff: this draft is staged in Client Comms',
      ),
      findsOneWidget,
    );
    expect(reopenCommsAction, findsOneWidget);
    expect(stagedDraftText, contains('Telegram draft for CLIENT-001'));
    expect(stagedOriginalDraftText, stagedDraftText);
  });

  testWidgets('onyx agent page uses live camera change staging tool action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: OnyxAgentPage(
          scopeClientId: 'CLIENT-001',
          scopeSiteId: 'SITE-SANDTON',
          focusIncidentReference: 'INC-CTRL-88',
          sourceRouteLabel: 'AI Queue',
          cameraChangeService: _FakeCameraChangeService(),
          cameraProbeService: _FakeCameraProbeService(),
          clientDraftService: _FakeClientDraftService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final messageList = find.byKey(const ValueKey('onyx-agent-message-list'));
    final seedProbeAction = find.byKey(
      const ValueKey('onyx-agent-action-thread-1-probe-camera'),
    );
    for (
      var attempt = 0;
      attempt < 5 && seedProbeAction.evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(messageList, const Offset(0, -280));
      await tester.pumpAndSettle();
    }
    await tester.tap(seedProbeAction);
    await tester.pumpAndSettle();

    final stageCameraChangeAction = find.byKey(
      const ValueKey('onyx-agent-action-stage-camera-change'),
    );
    for (
      var attempt = 0;
      attempt < 5 && stageCameraChangeAction.evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(messageList, const Offset(0, -280));
      await tester.pumpAndSettle();
    }
    expect(stageCameraChangeAction, findsOneWidget);
    await tester.tap(stageCameraChangeAction);
    await tester.pumpAndSettle();

    expect(find.text('Camera change packet'), findsOneWidget);
    expect(
      find.textContaining('Approval gate: staged only. No device write'),
      findsOneWidget,
    );
    expect(find.textContaining('local:test-camera-change'), findsWidgets);
    expect(find.text('Camera Audit Trail'), findsOneWidget);
    expect(find.textContaining('approval staged'), findsWidgets);
    expect(find.textContaining('Generic ONVIF'), findsWidgets);
    expect(find.textContaining('Balanced Monitoring'), findsWidgets);
    expect(find.textContaining('rollback-CAM-PKT-TEST-1'), findsWidgets);

    await tester.tap(
      find.byKey(
        const ValueKey(
          'onyx-agent-action-approve-camera-change-CAM-PKT-TEST-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Execution audit'), findsOneWidget);
    expect(find.textContaining('CAM-EXEC-TEST-1'), findsWidgets);
    expect(find.textContaining('local:test-camera-executor'), findsWidgets);
    expect(find.textContaining('executed'), findsWidgets);
    expect(find.textContaining('Hikvision'), findsWidgets);
    expect(find.textContaining('Alarm Verification'), findsWidgets);

    await tester.tap(
      find.byKey(
        const ValueKey(
          'onyx-agent-action-rollback-camera-change-CAM-EXEC-TEST-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rollback audit'), findsOneWidget);
    expect(find.textContaining('CAM-RBK-TEST-1'), findsWidgets);
    expect(find.textContaining('local:test-camera-rollback'), findsWidgets);
    expect(find.textContaining('rollback logged'), findsWidgets);
    expect(
      find.textContaining('rollback-CAM-PKT-TEST-1-192-168-1-64-before.json'),
      findsWidgets,
    );
  });

  testWidgets(
    'onyx agent page does not show approval gate ready when camera staging fails',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-001',
            scopeSiteId: 'SITE-SANDTON',
            focusIncidentReference: 'INC-CTRL-88',
            sourceRouteLabel: 'AI Queue',
            cameraChangeService: _FakeCameraChangeService(failStage: true),
            cameraProbeService: _FakeCameraProbeService(),
            clientDraftService: _FakeClientDraftService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final messageList = find.byKey(const ValueKey('onyx-agent-message-list'));
      final seedProbeAction = find.byKey(
        const ValueKey('onyx-agent-action-thread-1-probe-camera'),
      );
      for (
        var attempt = 0;
        attempt < 5 && seedProbeAction.evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(messageList, const Offset(0, -280));
        await tester.pumpAndSettle();
      }
      await tester.tap(seedProbeAction);
      await tester.pumpAndSettle();

      final stageCameraChangeAction = find.byKey(
        const ValueKey('onyx-agent-action-stage-camera-change'),
      );
      for (
        var attempt = 0;
        attempt < 5 && stageCameraChangeAction.evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(messageList, const Offset(0, -280));
        await tester.pumpAndSettle();
      }

      expect(stageCameraChangeAction, findsOneWidget);
      await tester.tap(stageCameraChangeAction);
      await tester.pumpAndSettle();

      expect(find.text('Camera staging failed'), findsOneWidget);
      expect(find.text('Approval gate is ready'), findsNothing);
      expect(
        find.textContaining('No device write was attempted.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'onyx agent page stages scoped camera recovery for reconnect prompts',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: OnyxAgentPage(
            scopeClientId: 'CLIENT-MS-VALLEE',
            scopeSiteId: 'SITE-MS-VALLEE-RESIDENCE',
            focusIncidentReference: 'INC-VALLEE-CAM-1',
            sourceRouteLabel: 'Command',
            cameraBridgeStatus: const OnyxAgentCameraBridgeStatus(
              enabled: true,
              running: true,
              statusLabel: 'Live',
              detail: 'Listening locally for approved camera packets.',
            ),
            cameraChangeService: _FakeCameraChangeService(),
            cameraProbeService: const _FakeCameraProbeService(),
            clientDraftService: const _FakeClientDraftService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('onyx-agent-composer-field')),
        'Reconnect the Vallee residence cameras. The Wi-Fi was down.',
      );
      await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
      await tester.pumpAndSettle();

      final messageList = find.byKey(const ValueKey('onyx-agent-message-list'));
      final scopedRecovery = find.text(
        'Scoped camera recovery plan for MS Vallee Residence',
      );
      for (
        var attempt = 0;
        attempt < 5 && scopedRecovery.evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(messageList, const Offset(0, -280));
        await tester.pumpAndSettle();
      }

      expect(scopedRecovery, findsOneWidget);
      expect(
        find.textContaining('The local camera bridge is live'),
        findsOneWidget,
      );
      expect(find.text('Stage Reconnect Packet'), findsOneWidget);
      expect(find.text('OPEN CCTV REVIEW'), findsWidgets);

      final stageReconnectAction = find.byKey(
        const ValueKey('onyx-agent-action-stage-camera-change'),
      );
      await tester.ensureVisible(stageReconnectAction);
      await tester.tap(stageReconnectAction);
      await tester.pumpAndSettle();

      expect(find.text('Camera change packet'), findsOneWidget);
      expect(
        find.textContaining('Approval gate: staged only. No device write'),
        findsOneWidget,
      );
      expect(find.textContaining('local:test-camera-change'), findsWidgets);
    },
  );
}
