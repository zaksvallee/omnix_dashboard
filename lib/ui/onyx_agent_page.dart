import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../application/onyx_agent_camera_change_service.dart';
import '../application/onyx_agent_camera_bridge_health_service.dart';
import '../application/onyx_agent_camera_probe_service.dart';
import '../application/onyx_agent_camera_bridge_server_contract.dart';
import '../application/onyx_agent_cloud_boost_service.dart';
import '../application/onyx_agent_context_snapshot_service.dart';
import '../application/onyx_agent_client_draft_service.dart';
import '../application/onyx_agent_local_brain_service.dart';
import '../application/onyx_command_brain_orchestrator.dart';
import '../application/onyx_command_specialist_assessment_service.dart';
import '../application/simulation/scenario_replay_history_signal_service.dart';
import '../application/onyx_tool_bridge.dart';
import '../domain/authority/onyx_command_brain_contract.dart';
import '../domain/authority/onyx_task_protocol.dart';
import '../domain/events/dispatch_event.dart';
import 'onyx_camera_bridge_actions.dart';
import 'onyx_camera_bridge_shell_panel.dart';
import 'onyx_camera_bridge_tone_resolver.dart';
import 'onyx_surface.dart';
import 'theme/onyx_design_tokens.dart';

class OnyxAgentEvidenceReturnReceipt {
  final String auditId;
  final String label;
  final String headline;
  final String detail;
  final Color accent;

  const OnyxAgentEvidenceReturnReceipt({
    required this.auditId,
    required this.label,
    required this.headline,
    required this.detail,
    required this.accent,
  });
}

class OnyxAgentPage extends StatefulWidget {
  final String scopeClientId;
  final String scopeSiteId;
  final String focusIncidentReference;
  final String sourceRouteLabel;
  final List<DispatchEvent> events;
  final String operatorId;
  final bool cloudAssistAvailable;
  final OnyxAgentCameraBridgeStatus cameraBridgeStatus;
  final OnyxAgentCameraBridgeHealthService cameraBridgeHealthService;
  final OnyxAgentCameraBridgeHealthSnapshot? cameraBridgeHealthSnapshot;
  final OnyxAgentCameraChangeService? cameraChangeService;
  final OnyxAgentCameraProbeService? cameraProbeService;
  final OnyxAgentClientDraftService? clientDraftService;
  final OnyxAgentLocalBrainService? localBrainService;
  final OnyxAgentCloudBoostService? cloudBoostService;
  final OnyxAgentContextSnapshotService contextSnapshotService;
  final Map<String, Object?> initialThreadSessionState;
  final ValueChanged<Map<String, Object?>>? onThreadSessionStateChanged;
  final VoidCallback? onOpenCctv;
  final ValueChanged<String>? onOpenCctvForIncident;
  final VoidCallback? onOpenAlarms;
  final ValueChanged<String>? onOpenAlarmsForIncident;
  final VoidCallback? onOpenTrack;
  final ValueChanged<String>? onOpenTrackForIncident;
  final ValueChanged<String>? onOpenOperationsForIncident;
  final VoidCallback? onOpenComms;
  final void Function(String clientId, String siteId)? onOpenCommsForScope;
  final void Function(String draftText, String originalDraftText)?
  onStageCommsDraft;
  final OnyxAgentEvidenceReturnReceipt? evidenceReturnReceipt;
  final ValueChanged<String>? onConsumeEvidenceReturnReceipt;
  final ValueChanged<OnyxAgentCameraBridgeHealthSnapshot>?
  onCameraBridgeHealthSnapshotChanged;
  final Future<void> Function()? onClearCameraBridgeHealthSnapshot;
  final ScenarioReplayHistorySignalService scenarioReplayHistorySignalService;

  const OnyxAgentPage({
    super.key,
    this.scopeClientId = '',
    this.scopeSiteId = '',
    this.focusIncidentReference = '',
    this.sourceRouteLabel = 'Command',
    this.events = const <DispatchEvent>[],
    this.operatorId = onyxAgentCameraBridgeDefaultOperatorId,
    this.cloudAssistAvailable = false,
    this.cameraBridgeStatus = const OnyxAgentCameraBridgeStatus(),
    this.cameraBridgeHealthService =
        const UnconfiguredOnyxAgentCameraBridgeHealthService(),
    this.cameraBridgeHealthSnapshot,
    this.cameraChangeService,
    this.cameraProbeService,
    this.clientDraftService,
    this.localBrainService,
    this.cloudBoostService,
    this.contextSnapshotService = const LocalOnyxAgentContextSnapshotService(),
    this.initialThreadSessionState = const <String, Object?>{},
    this.onThreadSessionStateChanged,
    this.onOpenCctv,
    this.onOpenCctvForIncident,
    this.onOpenAlarms,
    this.onOpenAlarmsForIncident,
    this.onOpenTrack,
    this.onOpenTrackForIncident,
    this.onOpenOperationsForIncident,
    this.onOpenComms,
    this.onOpenCommsForScope,
    this.onStageCommsDraft,
    this.evidenceReturnReceipt,
    this.onConsumeEvidenceReturnReceipt,
    this.onCameraBridgeHealthSnapshotChanged,
    this.onClearCameraBridgeHealthSnapshot,
    this.scenarioReplayHistorySignalService =
        const LocalScenarioReplayHistorySignalService(),
  });

  @override
  State<OnyxAgentPage> createState() => _OnyxAgentPageState();
}

enum _AgentActionKind {
  seedPrompt,
  executeRecommendation,
  dryProbeCamera,
  stageCameraChange,
  approveCameraChange,
  logCameraRollback,
  draftClientReply,
  summarizeIncident,
  openCctv,
  openComms,
  openAlarms,
  openTrack,
}

enum _AgentContextHighlightCategory {
  maintenance,
  overdueFollowUp,
  unresolvedFollowUp,
  operatorFocus,
  other,
}

enum _PlannerBacklogReviewStatus { acknowledged, muted, fixed }

enum _AgentMessageKind { user, agent, tool }

enum _AgentBrainProvider { local, cloud, none }

class _AgentPersona {
  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final String section;
  final String localCapability;
  final bool adminOnly;

  const _AgentPersona({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.section,
    required this.localCapability,
    this.adminOnly = false,
  });
}

class _AgentActionCard {
  final String id;
  final _AgentActionKind kind;
  final String label;
  final String detail;
  final String payload;
  final Map<String, String> arguments;
  final bool requiresApproval;
  final bool opensRoute;
  final String personaId;

  const _AgentActionCard({
    required this.id,
    required this.kind,
    required this.label,
    required this.detail,
    this.payload = '',
    this.arguments = const <String, String>{},
    this.requiresApproval = false,
    this.opensRoute = false,
    required this.personaId,
  });
}

class _AgentMessage {
  final String id;
  final _AgentMessageKind kind;
  final String personaId;
  final String headline;
  final String body;
  final DateTime createdAt;
  final List<_AgentActionCard> actions;

  const _AgentMessage({
    required this.id,
    required this.kind,
    required this.personaId,
    required this.headline,
    required this.body,
    required this.createdAt,
    this.actions = const <_AgentActionCard>[],
  });
}

class _AgentThread {
  final String id;
  final String title;
  final String summary;
  final List<_AgentMessage> messages;
  final _AgentThreadMemory memory;

  _AgentThread({
    required this.id,
    required this.title,
    required this.summary,
    required this.messages,
    _AgentThreadMemory? memory,
  }) : memory = memory ?? _AgentThreadMemory();

  _AgentThread copyWith({
    String? title,
    String? summary,
    List<_AgentMessage>? messages,
    _AgentThreadMemory? memory,
  }) {
    return _AgentThread(
      id: id,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      messages: messages ?? this.messages,
      memory: memory ?? this.memory,
    );
  }
}

class _AgentThreadMemory {
  final OnyxToolTarget? lastRecommendedTarget;
  final OnyxToolTarget? lastOpenedTarget;
  final OnyxCommandSurfaceMemory commandSurfaceMemory;
  final String lastRecommendationSummary;
  final String lastAdvisory;
  final String lastPrimaryPressure;
  final String lastOperatorFocusNote;
  final double? lastConfidence;
  final List<String> lastContextHighlights;
  final int secondLookConflictCount;
  final String lastSecondLookConflictSummary;
  final DateTime? lastSecondLookConflictAt;
  final Map<OnyxToolTarget, int> secondLookModelTargetCounts;
  final Map<OnyxToolTarget, int> secondLookTypedTargetCounts;
  final int secondLookRouteClosedConflictCount;
  final String nextFollowUpLabel;
  final String nextFollowUpPrompt;
  final DateTime? lastAutoFollowUpSurfacedAt;
  final int staleFollowUpSurfaceCount;
  final List<String> pendingConfirmations;
  final DateTime? updatedAt;

  OnyxCommandBrainSnapshot? get lastCommandBrainSnapshot =>
      commandSurfaceMemory.commandBrainSnapshot;

  String get lastReplayHistorySummary =>
      commandSurfaceMemory.replayHistorySummary;

  OnyxCommandSurfaceReceiptMemory? get lastCommandReceipt =>
      commandSurfaceMemory.commandReceipt;

  OnyxCommandSurfaceOutcomeMemory? get lastCommandOutcome =>
      commandSurfaceMemory.commandOutcome;

  OnyxCommandSurfacePreview? get lastCommandPreview =>
      commandSurfaceMemory.commandPreview;

  OnyxCommandSurfaceContinuityView commandContinuityView({
    bool preferRememberedContinuity = false,
  }) {
    return commandSurfaceMemory.continuityView(
      preferRememberedContinuity: preferRememberedContinuity,
    );
  }

  _AgentThreadMemory({
    this.lastRecommendedTarget,
    this.lastOpenedTarget,
    OnyxCommandSurfaceMemory commandSurfaceMemory =
        const OnyxCommandSurfaceMemory(),
    OnyxCommandBrainSnapshot? lastCommandBrainSnapshot,
    String lastReplayHistorySummary = '',
    this.lastRecommendationSummary = '',
    this.lastAdvisory = '',
    this.lastPrimaryPressure = '',
    this.lastOperatorFocusNote = '',
    this.lastConfidence,
    this.lastContextHighlights = const <String>[],
    this.secondLookConflictCount = 0,
    this.lastSecondLookConflictSummary = '',
    this.lastSecondLookConflictAt,
    this.secondLookModelTargetCounts = const <OnyxToolTarget, int>{},
    this.secondLookTypedTargetCounts = const <OnyxToolTarget, int>{},
    this.secondLookRouteClosedConflictCount = 0,
    this.nextFollowUpLabel = '',
    this.nextFollowUpPrompt = '',
    this.lastAutoFollowUpSurfacedAt,
    this.staleFollowUpSurfaceCount = 0,
    this.pendingConfirmations = const <String>[],
    this.updatedAt,
  }) : commandSurfaceMemory =
           (lastCommandBrainSnapshot != null || lastReplayHistorySummary != '')
           ? OnyxCommandSurfaceMemory(
               commandBrainSnapshot: lastCommandBrainSnapshot,
               replayHistorySummary: lastReplayHistorySummary,
             )
           : commandSurfaceMemory;

  bool get hasData {
    return lastRecommendedTarget != null ||
        lastOpenedTarget != null ||
        commandSurfaceMemory.hasData ||
        lastRecommendationSummary.trim().isNotEmpty ||
        lastAdvisory.trim().isNotEmpty ||
        lastPrimaryPressure.trim().isNotEmpty ||
        lastOperatorFocusNote.trim().isNotEmpty ||
        lastConfidence != null ||
        lastContextHighlights.isNotEmpty ||
        secondLookConflictCount > 0 ||
        lastSecondLookConflictSummary.trim().isNotEmpty ||
        lastSecondLookConflictAt != null ||
        secondLookModelTargetCounts.isNotEmpty ||
        secondLookTypedTargetCounts.isNotEmpty ||
        secondLookRouteClosedConflictCount > 0 ||
        nextFollowUpLabel.trim().isNotEmpty ||
        nextFollowUpPrompt.trim().isNotEmpty ||
        lastAutoFollowUpSurfacedAt != null ||
        pendingConfirmations.isNotEmpty;
  }

  _AgentThreadMemory copyWith({
    Object? lastRecommendedTarget = _memorySentinel,
    Object? lastOpenedTarget = _memorySentinel,
    Object? commandSurfaceMemory = _memorySentinel,
    Object? lastCommandBrainSnapshot = _memorySentinel,
    Object? lastCommandPreview = _memorySentinel,
    Object? lastCommandReceipt = _memorySentinel,
    Object? lastCommandOutcome = _memorySentinel,
    String? lastReplayHistorySummary,
    String? lastRecommendationSummary,
    String? lastAdvisory,
    String? lastPrimaryPressure,
    String? lastOperatorFocusNote,
    Object? lastConfidence = _memorySentinel,
    List<String>? lastContextHighlights,
    Object? secondLookConflictCount = _memorySentinel,
    String? lastSecondLookConflictSummary,
    Object? lastSecondLookConflictAt = _memorySentinel,
    Map<OnyxToolTarget, int>? secondLookModelTargetCounts,
    Map<OnyxToolTarget, int>? secondLookTypedTargetCounts,
    Object? secondLookRouteClosedConflictCount = _memorySentinel,
    String? nextFollowUpLabel,
    String? nextFollowUpPrompt,
    Object? lastAutoFollowUpSurfacedAt = _memorySentinel,
    Object? staleFollowUpSurfaceCount = _memorySentinel,
    List<String>? pendingConfirmations,
    Object? updatedAt = _memorySentinel,
  }) {
    final replaceCommandBrainSnapshot = !identical(
      lastCommandBrainSnapshot,
      _memorySentinel,
    );
    final replaceCommandPreview = !identical(
      lastCommandPreview,
      _memorySentinel,
    );
    final replaceCommandReceipt = !identical(
      lastCommandReceipt,
      _memorySentinel,
    );
    final replaceCommandOutcome = !identical(
      lastCommandOutcome,
      _memorySentinel,
    );
    final nextCommandSurfaceMemory =
        identical(commandSurfaceMemory, _memorySentinel)
        ? OnyxCommandSurfaceMemoryAdapter.merge(
            base: this.commandSurfaceMemory,
            replaceCommandBrainSnapshot: replaceCommandBrainSnapshot,
            commandBrainSnapshot: replaceCommandBrainSnapshot
                ? lastCommandBrainSnapshot as OnyxCommandBrainSnapshot?
                : null,
            replayHistorySummary: lastReplayHistorySummary,
            replaceCommandPreview: replaceCommandPreview,
            commandPreview: replaceCommandPreview
                ? lastCommandPreview as OnyxCommandSurfacePreview?
                : null,
            replaceCommandReceipt: replaceCommandReceipt,
            commandReceipt: replaceCommandReceipt
                ? lastCommandReceipt as OnyxCommandSurfaceReceiptMemory?
                : null,
            replaceCommandOutcome: replaceCommandOutcome,
            commandOutcome: replaceCommandOutcome
                ? lastCommandOutcome as OnyxCommandSurfaceOutcomeMemory?
                : null,
          )
        : commandSurfaceMemory as OnyxCommandSurfaceMemory;
    return _AgentThreadMemory(
      lastRecommendedTarget: identical(lastRecommendedTarget, _memorySentinel)
          ? this.lastRecommendedTarget
          : lastRecommendedTarget as OnyxToolTarget?,
      lastOpenedTarget: identical(lastOpenedTarget, _memorySentinel)
          ? this.lastOpenedTarget
          : lastOpenedTarget as OnyxToolTarget?,
      commandSurfaceMemory: nextCommandSurfaceMemory,
      lastRecommendationSummary:
          lastRecommendationSummary ?? this.lastRecommendationSummary,
      lastAdvisory: lastAdvisory ?? this.lastAdvisory,
      lastPrimaryPressure: lastPrimaryPressure ?? this.lastPrimaryPressure,
      lastOperatorFocusNote:
          lastOperatorFocusNote ?? this.lastOperatorFocusNote,
      lastConfidence: identical(lastConfidence, _memorySentinel)
          ? this.lastConfidence
          : lastConfidence as double?,
      lastContextHighlights:
          lastContextHighlights ??
          List<String>.from(this.lastContextHighlights),
      secondLookConflictCount:
          identical(secondLookConflictCount, _memorySentinel)
          ? this.secondLookConflictCount
          : secondLookConflictCount as int,
      lastSecondLookConflictSummary:
          lastSecondLookConflictSummary ?? this.lastSecondLookConflictSummary,
      lastSecondLookConflictAt:
          identical(lastSecondLookConflictAt, _memorySentinel)
          ? this.lastSecondLookConflictAt
          : lastSecondLookConflictAt as DateTime?,
      secondLookModelTargetCounts:
          secondLookModelTargetCounts ??
          Map<OnyxToolTarget, int>.from(this.secondLookModelTargetCounts),
      secondLookTypedTargetCounts:
          secondLookTypedTargetCounts ??
          Map<OnyxToolTarget, int>.from(this.secondLookTypedTargetCounts),
      secondLookRouteClosedConflictCount:
          identical(secondLookRouteClosedConflictCount, _memorySentinel)
          ? this.secondLookRouteClosedConflictCount
          : secondLookRouteClosedConflictCount as int,
      nextFollowUpLabel: nextFollowUpLabel ?? this.nextFollowUpLabel,
      nextFollowUpPrompt: nextFollowUpPrompt ?? this.nextFollowUpPrompt,
      lastAutoFollowUpSurfacedAt:
          identical(lastAutoFollowUpSurfacedAt, _memorySentinel)
          ? this.lastAutoFollowUpSurfacedAt
          : lastAutoFollowUpSurfacedAt as DateTime?,
      staleFollowUpSurfaceCount:
          identical(staleFollowUpSurfaceCount, _memorySentinel)
          ? this.staleFollowUpSurfaceCount
          : staleFollowUpSurfaceCount as int,
      pendingConfirmations:
          pendingConfirmations ?? List<String>.from(this.pendingConfirmations),
      updatedAt: identical(updatedAt, _memorySentinel)
          ? this.updatedAt
          : updatedAt as DateTime?,
    );
  }
}

class _PlannerConflictTargetCount {
  final OnyxToolTarget target;
  final int count;

  const _PlannerConflictTargetCount({
    required this.target,
    required this.count,
  });
}

class _PlannerConflictReport {
  final int totalConflictCount;
  final int impactedThreadCount;
  final int routeClosedConflictCount;
  final Map<String, int> currentSignalCounts;
  final List<_PlannerConflictTargetCount> modelTargetCounts;
  final List<_PlannerConflictTargetCount> typedTargetCounts;
  final List<_PlannerMaintenanceAlertEntry> maintenanceAlerts;
  final List<String> tuningSignals;
  final List<String> tuningSuggestions;
  final List<_PlannerArchivedEntry> archivedEntries;
  final List<_PlannerReactivationEntry> reactivationEntries;
  final List<String> reactivationSignals;
  final String highestReactivationSeverity;
  final List<_PlannerBacklogEntry> backlogEntries;
  final int archivedReviewedCount;

  const _PlannerConflictReport({
    this.totalConflictCount = 0,
    this.impactedThreadCount = 0,
    this.routeClosedConflictCount = 0,
    this.currentSignalCounts = const <String, int>{},
    this.modelTargetCounts = const <_PlannerConflictTargetCount>[],
    this.typedTargetCounts = const <_PlannerConflictTargetCount>[],
    this.maintenanceAlerts = const <_PlannerMaintenanceAlertEntry>[],
    this.tuningSignals = const <String>[],
    this.tuningSuggestions = const <String>[],
    this.archivedEntries = const <_PlannerArchivedEntry>[],
    this.reactivationEntries = const <_PlannerReactivationEntry>[],
    this.reactivationSignals = const <String>[],
    this.highestReactivationSeverity = '',
    this.backlogEntries = const <_PlannerBacklogEntry>[],
    this.archivedReviewedCount = 0,
  });

  bool get hasData =>
      totalConflictCount > 0 ||
      archivedReviewedCount > 0 ||
      maintenanceAlerts.isNotEmpty ||
      archivedEntries.isNotEmpty ||
      reactivationEntries.isNotEmpty ||
      reactivationSignals.isNotEmpty ||
      tuningSignals.isNotEmpty ||
      tuningSuggestions.isNotEmpty ||
      backlogEntries.isNotEmpty;

  _PlannerConflictTargetCount? get topModelTarget =>
      modelTargetCounts.isEmpty ? null : modelTargetCounts.first;

  _PlannerConflictTargetCount? get topTypedTarget =>
      typedTargetCounts.isEmpty ? null : typedTargetCounts.first;

  _PlannerMaintenanceAlertEntry? get topMaintenanceAlert =>
      maintenanceAlerts.isEmpty ? null : maintenanceAlerts.first;
}

class _PlannerBacklogEntry {
  final String signalId;
  final String label;
  final int score;
  final bool active;
  final _PlannerBacklogReviewStatus? reviewStatus;

  const _PlannerBacklogEntry({
    required this.signalId,
    required this.label,
    required this.score,
    required this.active,
    this.reviewStatus,
  });
}

class _PlannerArchivedEntry {
  final String signalId;
  final String label;
  final int archivedAtCount;
  final int currentCount;

  const _PlannerArchivedEntry({
    required this.signalId,
    required this.label,
    required this.archivedAtCount,
    required this.currentCount,
  });
}

class _PlannerMaintenanceAlertEntry {
  final String signalId;
  final String label;
  final int reactivationCount;
  final int staleAgainCount;
  final DateTime? lastReactivatedAt;
  final DateTime? reviewQueuedAt;
  final DateTime? reviewCompletedAt;
  final DateTime? reviewPrioritizedAt;

  const _PlannerMaintenanceAlertEntry({
    required this.signalId,
    required this.label,
    required this.reactivationCount,
    this.staleAgainCount = 0,
    this.lastReactivatedAt,
    this.reviewQueuedAt,
    this.reviewCompletedAt,
    this.reviewPrioritizedAt,
  });

  bool get reviewQueued => reviewQueuedAt != null && reviewCompletedAt == null;

  bool get reviewReopened =>
      reviewQueuedAt != null &&
      reviewCompletedAt != null &&
      reviewQueuedAt!.isAfter(reviewCompletedAt!);

  bool get reviewCompleted => reviewCompletedAt != null && !reviewReopened;

  bool get reviewPrioritized => reviewPrioritizedAt != null;
}

class _PlannerReactivationEntry {
  final String signalId;
  final String label;
  final int archivedAtCount;
  final int currentCount;
  final int reactivationCount;
  final DateTime? lastReactivatedAt;

  const _PlannerReactivationEntry({
    required this.signalId,
    required this.label,
    required this.archivedAtCount,
    required this.currentCount,
    required this.reactivationCount,
    this.lastReactivatedAt,
  });
}

class _PlannerSignalSnapshot {
  final Map<String, int> signalCounts;
  final DateTime? capturedAt;

  const _PlannerSignalSnapshot({
    this.signalCounts = const <String, int>{},
    this.capturedAt,
  });

  bool get hasData => signalCounts.isNotEmpty;
}

enum _PromptHandlingProfile {
  triage,
  cameraRecovery,
  camera,
  telemetry,
  patrol,
  client,
  report,
  correlation,
  admin,
  dispatch,
  general,
}

const Object _memorySentinel = Object();

class _OnyxAgentPageState extends State<OnyxAgentPage> {
  static const OnyxCommandBrainOrchestrator _commandBrainOrchestrator =
      OnyxCommandBrainOrchestrator();
  static const OnyxCommandSpecialistAssessmentService
  _specialistAssessmentService = OnyxCommandSpecialistAssessmentService();
  static const Duration _staleFollowUpInitialDelay = Duration(minutes: 5);
  static const Duration _staleFollowUpRepeatDelay = Duration(minutes: 10);

  static const List<_AgentPersona> _personas = <_AgentPersona>[
    _AgentPersona(
      id: 'main',
      label: 'Main Brain',
      subtitle:
          'Answers controller questions, routes specialist work, and owns cloud escalation.',
      icon: Icons.hub_rounded,
      accent: Color(0xFF67E8F9),
      section: 'Command Brain',
      localCapability: 'Local orchestration',
    ),
    _AgentPersona(
      id: 'camera',
      label: 'CCTV Review Agent',
      subtitle:
          'Detects movement, classifies objects, and stages camera bring-up checks.',
      icon: Icons.videocam_rounded,
      accent: Color(0xFFFBBF24),
      section: 'Core Intelligence',
      localCapability: 'Edge video ready',
    ),
    _AgentPersona(
      id: 'telemetry',
      label: 'Tactical Track Agent',
      subtitle:
          'Watches heart rate, motion, inactivity, and patrol compliance signals.',
      icon: Icons.monitor_heart_rounded,
      accent: Color(0xFFFB7185),
      section: 'Core Intelligence',
      localCapability: 'Wearable signals ready',
    ),
    _AgentPersona(
      id: 'patrol',
      label: 'Tactical Patrol Agent',
      subtitle:
          'Checks patrol photos against baseline coverage and checkpoint truth.',
      icon: Icons.fact_check_rounded,
      accent: Color(0xFF34D399),
      section: 'Core Intelligence',
      localCapability: 'Photo proof checks ready',
    ),
    _AgentPersona(
      id: 'client',
      label: 'Client Comms Agent',
      subtitle:
          'Drafts replies, standardizes tone, and hands off into Client Comms.',
      icon: Icons.mark_chat_read_rounded,
      accent: Color(0xFF22D3EE),
      section: 'Operator Support',
      localCapability: 'Reply drafting ready',
    ),
    _AgentPersona(
      id: 'dispatch',
      label: 'War Room Handoff Agent',
      subtitle:
          'Coordinates Dispatch Board, Tactical Track, CCTV Review, Client Comms, and controller handoffs.',
      icon: Icons.send_rounded,
      accent: Color(0xFFF87171),
      section: 'Operator Support',
      localCapability: 'Route handoffs ready',
    ),
    _AgentPersona(
      id: 'intel',
      label: 'Signal Picture Agent',
      subtitle:
          'Combines CCTV Review, Tactical Track posture, Dispatch Board signals, and Sovereign Ledger context into one War Room picture.',
      icon: Icons.insights_rounded,
      accent: Color(0xFFA78BFA),
      section: 'Core Intelligence',
      localCapability: 'Cross-signal fusion ready',
    ),
    _AgentPersona(
      id: 'report',
      label: 'Reports Workspace Agent',
      subtitle:
          'Compiles Sovereign Ledger entries, Dispatch Board activity, incidents, and CCTV Review events into narrative.',
      icon: Icons.description_rounded,
      accent: Color(0xFF93C5FD),
      section: 'Operator Support',
      localCapability: 'Narrative drafting ready',
    ),
    _AgentPersona(
      id: 'classification',
      label: 'Incident Triage Agent',
      subtitle: 'Turns the active signal picture into one clear incident call.',
      icon: Icons.rule_folder_rounded,
      accent: Color(0xFFF59E0B),
      section: 'Core Intelligence',
      localCapability: 'Classification rules ready',
    ),
    _AgentPersona(
      id: 'escalation',
      label: 'Escalation Agent',
      subtitle:
          'Watches timers, inaction, and overdue responses before things stall.',
      icon: Icons.warning_amber_rounded,
      accent: Color(0xFFF97316),
      section: 'Core Intelligence',
      localCapability: 'Timer watch ready',
    ),
    _AgentPersona(
      id: 'proactive',
      label: 'Proactive Suggestion Agent',
      subtitle:
          'Flags missing next steps like client updates, rechecks, and follow-ups.',
      icon: Icons.tips_and_updates_rounded,
      accent: Color(0xFF2DD4BF),
      section: 'Core Intelligence',
      localCapability: 'Gap detection ready',
    ),
    _AgentPersona(
      id: 'pattern',
      label: 'Pattern Detection Agent',
      subtitle:
          'Surfaces recurring false alarms, weak sites, and unstable sensor trends.',
      icon: Icons.query_stats_rounded,
      accent: Color(0xFFC084FC),
      section: 'Supervisor',
      localCapability: 'Trend watch ready',
    ),
    _AgentPersona(
      id: 'performance',
      label: 'Guard Performance Agent',
      subtitle:
          'Tracks missed patrols, response delays, and ongoing field behavior.',
      icon: Icons.military_tech_rounded,
      accent: Color(0xFF38BDF8),
      section: 'Supervisor',
      localCapability: 'Performance scoring ready',
    ),
    _AgentPersona(
      id: 'system',
      label: 'System Health Agent',
      subtitle: 'Monitors cameras, feeds, devices, and integration uptime.',
      icon: Icons.router_rounded,
      accent: Color(0xFF60A5FA),
      section: 'Admin',
      localCapability: 'Health probes ready',
      adminOnly: true,
    ),
    _AgentPersona(
      id: 'debug',
      label: 'Signal Debug Agent',
      subtitle:
          'Shows confidence, detection weighting, and why a signal fired.',
      icon: Icons.bug_report_rounded,
      accent: Color(0xFFFB7185),
      section: 'Admin',
      localCapability: 'Confidence traces ready',
      adminOnly: true,
    ),
    _AgentPersona(
      id: 'policy',
      label: 'Policy / Logic Agent',
      subtitle: 'Enforces thresholds, escalation rules, and safety boundaries.',
      icon: Icons.gavel_rounded,
      accent: Color(0xFFFDE68A),
      section: 'Admin',
      localCapability: 'Rule engine ready',
      adminOnly: true,
    ),
  ];

  late final TextEditingController _composerController;
  final ScrollController _messageScrollController = ScrollController();
  final ScrollController _networkRailScrollController = ScrollController();
  Timer? _staleFollowUpSurfaceTimer;
  final Map<String, GlobalKey> _plannerMaintenanceAlertKeys =
      <String, GlobalKey>{};
  final Map<String, GlobalKey> _plannerReportSectionKeys =
      <String, GlobalKey>{};
  final Map<String, GlobalKey> _plannerBacklogEntryKeys = <String, GlobalKey>{};
  final Map<String, GlobalKey> _plannerArchivedEntryKeys =
      <String, GlobalKey>{};
  final Map<String, GlobalKey> _plannerReactivationEntryKeys =
      <String, GlobalKey>{};
  late List<_AgentThread> _threads;
  late String _selectedThreadId;
  String? _selectedThreadOperatorId;
  DateTime? _selectedThreadOperatorAt;
  String? _restoredPressureFocusThreadId;
  String? _restoredPressureFocusFallbackThreadTitle;
  String? _restoredPressureFocusLabel;
  String? _suppressedRestoreStaleFollowUpThreadId;
  String? _focusedPlannerSignalId;
  String? _focusedPlannerSectionId;
  String? _focusedPlannerBacklogSignalId;
  String? _focusedPlannerArchivedSignalId;
  String? _focusedPlannerReactivationSignalId;
  String? _focusedPlannerSignalContextLabel;
  String? _suppressedThreadCardTapId;
  bool _preferCloudBoost = false;
  bool _localBrainInFlight = false;
  bool _cloudBoostInFlight = false;
  bool _cameraAuditLoading = false;
  OnyxAgentCameraBridgeLocalState _cameraBridgeLocalState =
      const OnyxAgentCameraBridgeLocalState();
  int _threadCounter = 3;
  _PlannerSignalSnapshot _plannerSignalSnapshot =
      const _PlannerSignalSnapshot();
  _PlannerSignalSnapshot _previousPlannerSignalSnapshot =
      const _PlannerSignalSnapshot();
  _PlannerConflictReport? _cachedPlannerConflictReport;
  Map<String, int> _plannerBacklogScores = const <String, int>{};
  Map<String, int> _plannerBacklogArchivedSignalCounts = const <String, int>{};
  Map<String, int> _plannerBacklogReactivatedSignalCounts =
      const <String, int>{};
  Map<String, int> _plannerBacklogReactivationCounts = const <String, int>{};
  Map<String, DateTime> _plannerBacklogLastReactivatedAt =
      const <String, DateTime>{};
  Map<String, _PlannerBacklogReviewStatus> _plannerBacklogReviewStatuses =
      const <String, _PlannerBacklogReviewStatus>{};
  Map<String, DateTime> _plannerMaintenanceReviewQueuedAt =
      const <String, DateTime>{};
  Map<String, DateTime> _plannerMaintenanceReviewCompletedAt =
      const <String, DateTime>{};
  Map<String, DateTime> _plannerMaintenanceReviewPrioritizedAt =
      const <String, DateTime>{};
  Map<String, int> _plannerMaintenanceReviewReopenedCounts =
      const <String, int>{};
  Map<String, int> _plannerMaintenanceReviewCompletedSignalCounts =
      const <String, int>{};
  Map<String, int> _plannerMaintenanceReviewCompletedReactivationCounts =
      const <String, int>{};
  List<OnyxAgentCameraAuditEntry> _cameraAuditHistory =
      const <OnyxAgentCameraAuditEntry>[];
  OnyxAgentEvidenceReturnReceipt? _activeEvidenceReturnReceipt;
  ScenarioReplayHistorySignal? _replayHistorySignal;
  List<ScenarioReplayHistorySignal> _replayHistorySignalStack =
      const <ScenarioReplayHistorySignal>[];
  bool _zaraReasoningExpanded = false;

  bool get _localBrainConfigured =>
      widget.localBrainService?.isConfigured == true;

  bool get _cameraProbeAvailable =>
      widget.cameraProbeService?.isConfigured == true;

  bool get _cameraChangeAvailable =>
      widget.cameraChangeService?.isConfigured == true;

  bool get _cameraBridgeHealthAvailable =>
      widget.cameraBridgeHealthService.isConfigured;

  OnyxCameraBridgeSurfacePresentation get _cameraBridgePresentation =>
      resolveOnyxCameraBridgeSurfacePresentation(
        status: widget.cameraBridgeStatus,
        localSnapshot: _cameraBridgeLocalState.snapshot,
        healthProbeConfigured: _cameraBridgeHealthAvailable,
        validationInFlight: _cameraBridgeLocalState.validationInFlight,
        resetInFlight: _cameraBridgeLocalState.resetInFlight,
        variant: OnyxCameraBridgeSurfaceToneVariant.agent,
      );

  bool get _clientDraftAvailable =>
      widget.clientDraftService?.isConfigured == true;

  bool get _commsDraftHandoffAvailable => widget.onStageCommsDraft != null;

  bool get _cloudBoostConfigured =>
      widget.cloudBoostService?.isConfigured == true;

  bool get _cloudBoostAvailable =>
      widget.cloudAssistAvailable && _cloudBoostConfigured;

  bool get _reasoningInFlight => _localBrainInFlight || _cloudBoostInFlight;

  @override
  void initState() {
    super.initState();
    _composerController = TextEditingController();
    _ingestInitialThreadSessionState();
    _queueStaleFollowUpSurface();
    _cameraBridgeLocalState = _cameraBridgeLocalState.syncSnapshot(
      widget.cameraBridgeHealthSnapshot,
    );
    _ingestEvidenceReturnReceipt(widget.evidenceReturnReceipt);
    if (_cameraChangeAvailable) {
      unawaited(_refreshCameraAuditHistory(showLoading: true));
    }
    unawaited(_loadReplayHistorySignals());
  }

  @override
  void didUpdateWidget(covariant OnyxAgentPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameJsonState(
      oldWidget.initialThreadSessionState,
      widget.initialThreadSessionState,
    )) {
      _ingestInitialThreadSessionState(useSetState: true);
      _queueStaleFollowUpSurface();
    }
    if (oldWidget.cameraBridgeHealthSnapshot !=
        widget.cameraBridgeHealthSnapshot) {
      setState(() {
        _cameraBridgeLocalState = _cameraBridgeLocalState.syncSnapshot(
          widget.cameraBridgeHealthSnapshot,
        );
      });
    }
    if (oldWidget.evidenceReturnReceipt?.auditId !=
        widget.evidenceReturnReceipt?.auditId) {
      _ingestEvidenceReturnReceipt(
        widget.evidenceReturnReceipt,
        useSetState: true,
      );
    }
    if (oldWidget.scenarioReplayHistorySignalService !=
        widget.scenarioReplayHistorySignalService) {
      unawaited(_loadReplayHistorySignals());
    }
  }

  Future<void> _loadReplayHistorySignals() async {
    try {
      final stack = await widget.scenarioReplayHistorySignalService
          .loadSignalStack(limit: 3);
      if (!mounted) {
        return;
      }
      setState(() {
        _replayHistorySignalStack = stack;
        _replayHistorySignal = stack.isEmpty ? null : stack.first;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _replayHistorySignalStack = const <ScenarioReplayHistorySignal>[];
        _replayHistorySignal = null;
      });
    }
  }

  @override
  void dispose() {
    _staleFollowUpSurfaceTimer?.cancel();
    _composerController.dispose();
    _messageScrollController.dispose();
    _networkRailScrollController.dispose();
    super.dispose();
  }

  void _ingestInitialThreadSessionState({bool useSetState = false}) {
    final restored = _restoreThreadSessionState(
      widget.initialThreadSessionState,
    );
    var shouldEmitResolvedRestoreState = false;

    void apply() {
      _cachedPlannerConflictReport = null;
      _suppressedRestoreStaleFollowUpThreadId = null;
      if (restored != null) {
        _threads = restored.threads;
        _threadCounter = restored.threadCounter;
        _selectedThreadOperatorId = restored.selectedThreadOperatorId;
        _selectedThreadOperatorAt = restored.selectedThreadOperatorAt;
        if (restored.plannerSignalSnapshot.hasData ||
            restored.previousPlannerSignalSnapshot.hasData) {
          _plannerSignalSnapshot = restored.plannerSignalSnapshot;
          _previousPlannerSignalSnapshot =
              restored.previousPlannerSignalSnapshot;
          _plannerBacklogScores = restored.plannerBacklogScores.isNotEmpty
              ? restored.plannerBacklogScores
              : _seedPlannerBacklogScores(
                  currentSignalCounts:
                      restored.plannerSignalSnapshot.signalCounts,
                  previousSignalCounts:
                      restored.previousPlannerSignalSnapshot.signalCounts,
                );
          _plannerBacklogArchivedSignalCounts =
              restored.plannerBacklogArchivedSignalCounts;
          _plannerBacklogReactivatedSignalCounts =
              restored.plannerBacklogReactivatedSignalCounts;
          _plannerBacklogReactivationCounts =
              restored.plannerBacklogReactivationCounts;
          _plannerBacklogLastReactivatedAt =
              restored.plannerBacklogLastReactivatedAt;
          _plannerBacklogReviewStatuses = restored.plannerBacklogReviewStatuses;
          _plannerMaintenanceReviewQueuedAt =
              restored.plannerMaintenanceReviewQueuedAt;
          _plannerMaintenanceReviewCompletedAt =
              restored.plannerMaintenanceReviewCompletedAt;
          _plannerMaintenanceReviewPrioritizedAt =
              restored.plannerMaintenanceReviewPrioritizedAt;
          _plannerMaintenanceReviewReopenedCounts =
              restored.plannerMaintenanceReviewReopenedCounts;
          _plannerMaintenanceReviewCompletedSignalCounts =
              restored.plannerMaintenanceReviewCompletedSignalCounts;
          _plannerMaintenanceReviewCompletedReactivationCounts =
              restored.plannerMaintenanceReviewCompletedReactivationCounts;
        } else {
          _synchronizePlannerSignalSnapshots(
            threads: restored.threads,
            baseline: true,
          );
        }
        final resolvedSelectedThreadId = _resolveRestoredSelectedThreadId(
          fallbackSelectedThreadId: restored.selectedThreadId,
        );
        _selectedThreadId = resolvedSelectedThreadId;
        shouldEmitResolvedRestoreState =
            resolvedSelectedThreadId != restored.selectedThreadId;
        if (_shouldSuppressRestoredStaleFollowUp(
          fallbackSelectedThreadId: restored.selectedThreadId,
          resolvedSelectedThreadId: resolvedSelectedThreadId,
        )) {
          _suppressedRestoreStaleFollowUpThreadId = resolvedSelectedThreadId;
        }
        _applyRestoredPressureFocusNote(
          fallbackSelectedThreadId: restored.selectedThreadId,
          resolvedSelectedThreadId: resolvedSelectedThreadId,
        );
        return;
      }
      _threads = _seedThreads();
      _selectedThreadId = _threads.first.id;
      _selectedThreadOperatorId = null;
      _selectedThreadOperatorAt = null;
      _restoredPressureFocusThreadId = null;
      _restoredPressureFocusFallbackThreadTitle = null;
      _restoredPressureFocusLabel = null;
      _threadCounter = _inferThreadCounter(_threads);
      _plannerBacklogArchivedSignalCounts = const <String, int>{};
      _plannerBacklogReactivatedSignalCounts = const <String, int>{};
      _plannerBacklogReactivationCounts = const <String, int>{};
      _plannerBacklogLastReactivatedAt = const <String, DateTime>{};
      _plannerBacklogReviewStatuses =
          const <String, _PlannerBacklogReviewStatus>{};
      _plannerMaintenanceReviewQueuedAt = const <String, DateTime>{};
      _plannerMaintenanceReviewCompletedAt = const <String, DateTime>{};
      _plannerMaintenanceReviewPrioritizedAt = const <String, DateTime>{};
      _plannerMaintenanceReviewReopenedCounts = const <String, int>{};
      _plannerMaintenanceReviewCompletedSignalCounts = const <String, int>{};
      _plannerMaintenanceReviewCompletedReactivationCounts =
          const <String, int>{};
      _synchronizePlannerSignalSnapshots(threads: _threads, baseline: true);
    }

    if (useSetState) {
      setState(apply);
    } else {
      apply();
    }
    if (shouldEmitResolvedRestoreState) {
      _queueEmitThreadSessionState();
    }
  }

  void _queueEmitThreadSessionState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _emitThreadSessionState();
    });
  }

  void _queueStaleFollowUpSurface({
    String? threadId,
    bool allowImmediate = true,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final targetThreadId = threadId ?? _selectedThreadId;
      if (_suppressedRestoreStaleFollowUpThreadId == targetThreadId) {
        _suppressedRestoreStaleFollowUpThreadId = null;
        _scheduleStaleFollowUpSurface(
          threadId: targetThreadId,
          allowImmediate: false,
        );
        return;
      }
      final surfaced = allowImmediate
          ? _surfaceStaleFollowUpIfNeeded(targetThreadId)
          : false;
      if (!surfaced) {
        _scheduleStaleFollowUpSurface(
          threadId: targetThreadId,
          allowImmediate: false,
        );
      }
    });
  }

  void _suppressThreadCardTapOnce(String threadId) {
    _suppressedThreadCardTapId = threadId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_suppressedThreadCardTapId == threadId) {
        _suppressedThreadCardTapId = null;
      }
    });
  }

  bool _consumeSuppressedThreadCardTap(String threadId) {
    if (_suppressedThreadCardTapId != threadId) {
      return false;
    }
    _suppressedThreadCardTapId = null;
    return true;
  }

  bool _surfaceStaleFollowUpIfNeeded(
    String threadId, {
    bool trustScheduledDueAt = false,
  }) {
    final index = _threads.indexWhere((thread) => thread.id == threadId);
    if (index < 0) {
      return false;
    }
    final thread = _threads[index];
    final memory = thread.memory;
    final dueAt = _nextStaleFollowUpDueAt(memory);
    if (dueAt == null) {
      return false;
    }
    if (!trustScheduledDueAt && !_shouldSurfaceStaleFollowUp(memory)) {
      return false;
    }
    final cue = _staleFollowUpCue(memory);
    final leadLines = <String>[cue.lead];
    final contextLines = <String>[
      ?_threadMemoryPrimaryPressureResponseLine(memory),
      if (memory.lastOperatorFocusNote.trim().isNotEmpty)
        'Operator focus: ${memory.lastOperatorFocusNote.trim()}',
      if (memory.lastAdvisory.trim().isNotEmpty) memory.lastAdvisory.trim(),
    ];
    final followUpLines = <String>[
      if (memory.pendingConfirmations.isNotEmpty)
        'Still confirm ${memory.pendingConfirmations.join(', ')}.',
    ];
    final now = DateTime.now();
    final action = _action(
      id: 'thread-follow-up-${DateTime.now().microsecondsSinceEpoch}',
      kind: _AgentActionKind.seedPrompt,
      label: memory.nextFollowUpLabel,
      detail: cue.actionDetail,
      payload: memory.nextFollowUpPrompt,
      personaId: cue.personaId,
    );
    _updateThreadById(threadId, (currentThread) {
      return currentThread.copyWith(
        memory: currentThread.memory.copyWith(
          lastAutoFollowUpSurfacedAt: now,
          staleFollowUpSurfaceCount:
              currentThread.memory.staleFollowUpSurfaceCount + 1,
        ),
        messages: [
          ...currentThread.messages,
          _agentMessage(
            personaId: cue.personaId,
            headline: cue.headline,
            body: buildCommandBodyFromSections(<Iterable<String>>[
              leadLines,
              contextLines,
              followUpLines,
            ]),
            actions: [action],
          ),
        ],
      );
    });
    return true;
  }

  bool _shouldSurfaceStaleFollowUp(_AgentThreadMemory memory) {
    final dueAt = _nextStaleFollowUpDueAt(memory);
    if (dueAt == null) {
      return false;
    }
    return !dueAt.isAfter(DateTime.now());
  }

  OnyxThreadMemoryFollowUpCue _staleFollowUpCue(_AgentThreadMemory memory) {
    return OnyxThreadMemoryFollowUpCue.forSurfaceCount(
      memory.staleFollowUpSurfaceCount,
    );
  }

  DateTime? _nextStaleFollowUpDueAt(_AgentThreadMemory memory) {
    final prompt = memory.nextFollowUpPrompt.trim();
    final label = memory.nextFollowUpLabel.trim();
    final updatedAt = memory.updatedAt;
    if (prompt.isEmpty || label.isEmpty || updatedAt == null) {
      return null;
    }
    final surfacedAt = memory.lastAutoFollowUpSurfacedAt;
    if (surfacedAt != null) {
      return surfacedAt.add(_staleFollowUpRepeatDelay);
    }
    return updatedAt.add(_staleFollowUpInitialDelay);
  }

  void _scheduleStaleFollowUpSurface({
    String? threadId,
    bool allowImmediate = false,
  }) {
    _staleFollowUpSurfaceTimer?.cancel();
    _staleFollowUpSurfaceTimer = null;
    if (!mounted) {
      return;
    }
    final targetThreadId = threadId ?? _selectedThreadId;
    final threadIndex = _threads.indexWhere(
      (candidate) => candidate.id == targetThreadId,
    );
    if (threadIndex < 0) {
      return;
    }
    final dueAt = _nextStaleFollowUpDueAt(_threads[threadIndex].memory);
    if (dueAt == null) {
      return;
    }
    var delay = dueAt.difference(DateTime.now());
    if (delay <= Duration.zero) {
      if (allowImmediate) {
        _queueStaleFollowUpSurface(threadId: targetThreadId);
        return;
      }
      delay = _staleFollowUpRepeatDelay;
    }
    _staleFollowUpSurfaceTimer = Timer(delay, () {
      if (!mounted || _selectedThreadId != targetThreadId) {
        return;
      }
      final surfaced = _surfaceStaleFollowUpIfNeeded(
        targetThreadId,
        trustScheduledDueAt: true,
      );
      if (!surfaced) {
        _scheduleStaleFollowUpSurface(
          threadId: targetThreadId,
          allowImmediate: false,
        );
      }
    });
  }

  void _ingestEvidenceReturnReceipt(
    OnyxAgentEvidenceReturnReceipt? receipt, {
    bool useSetState = false,
  }) {
    if (receipt == null) {
      return;
    }

    void apply() {
      _activeEvidenceReturnReceipt = receipt;
    }

    if (useSetState) {
      setState(apply);
    } else {
      apply();
    }

    widget.onConsumeEvidenceReturnReceipt?.call(receipt.auditId);
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveThread = _hasActiveSelectedThread;
    final thread = hasActiveThread ? _selectedThread : _standbyThread();
    final memory = thread.memory;
    final snapshot = _contextSnapshot();
    final recommendedActions = _zaraRecommendedActions(thread);
    return OnyxPageScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 1240;
          return Column(
            children: [
              _zaraAgentTopBar(
                thread: thread,
                memory: memory,
                snapshot: snapshot,
                recommendedActions: recommendedActions,
              ),
              Expanded(
                child: _zaraAgentBody(
                  constraints: constraints,
                  stacked: stacked,
                  hasActiveThread: hasActiveThread,
                  thread: thread,
                  memory: memory,
                  snapshot: snapshot,
                  recommendedActions: recommendedActions,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ignore: unused_element
  Widget _legacyAgentWorkspaceLayout(BoxConstraints constraints) {
    final widescreen = constraints.maxWidth >= 1380;
    final desktop = constraints.maxWidth >= 1100;
    final inset = constraints.maxWidth >= 1400 ? 20.0 : 14.0;
    final plannerConflictReport = _plannerConflictReport();
    final threadRail = _buildThreadRail(
      compact: !desktop,
      plannerConflictReport: plannerConflictReport,
    );
    final networkRail = _buildNetworkRail(compact: !widescreen);
    final conversationSurface = _buildConversationSurface();

    if (widescreen) {
      return Padding(
        padding: EdgeInsets.all(inset),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 228, child: threadRail),
            const SizedBox(width: 16),
            Expanded(child: conversationSurface),
            const SizedBox(width: 16),
            SizedBox(width: 280, child: networkRail),
          ],
        ),
      );
    }

    if (desktop) {
      return Padding(
        padding: EdgeInsets.all(inset),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 248,
              child: Column(
                children: [
                  Expanded(child: threadRail),
                  const SizedBox(height: 14),
                  SizedBox(height: 308, child: networkRail),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: conversationSurface),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.all(inset),
      child: Column(
        children: [
          SizedBox(height: 196, child: threadRail),
          const SizedBox(height: 12),
          Expanded(child: conversationSurface),
          const SizedBox(height: 12),
          SizedBox(height: 260, child: networkRail),
        ],
      ),
    );
  }

  Widget _zaraAgentTopBar({
    required _AgentThread thread,
    required _AgentThreadMemory memory,
    required OnyxAgentContextSnapshot snapshot,
    required List<_AgentActionCard> recommendedActions,
  }) {
    final operatorLabel = widget.operatorId.trim().isEmpty
        ? 'Controller-1 · Operator'
        : '${widget.operatorId.trim()} · Operator';
    final alertAction = _zaraAlertCallback(recommendedActions);

    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        border: Border(bottom: BorderSide(color: OnyxColorTokens.divider)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: OnyxColorTokens.accentPurple,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 9),
                Text(
                  'ZARA',
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: OnyxColorTokens.accentPurple.withValues(
                        alpha: 0.2,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 15,
                        height: 15,
                        decoration: BoxDecoration(
                          color: OnyxColorTokens.accentPurple.withValues(
                            alpha: 0.2,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: OnyxColorTokens.accentPurple.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Z',
                          style: GoogleFonts.inter(
                            color: OnyxColorTokens.accentPurple,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'ZARA:',
                        style: GoogleFonts.inter(
                          color: OnyxColorTokens.accentPurple.withValues(
                            alpha: 0.7,
                          ),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          _zaraSpeechText(
                            thread: thread,
                            memory: memory,
                            snapshot: snapshot,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: OnyxColorTokens.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 220,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: OnyxColorTokens.accentGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    operatorLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.textDisabled,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: alertAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: OnyxColorTokens.accentPurple,
                    foregroundColor: OnyxColorTokens.textPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    minimumSize: const Size(0, 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    textStyle: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('ALERT'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _zaraAgentBody({
    required BoxConstraints constraints,
    required bool stacked,
    required bool hasActiveThread,
    required _AgentThread thread,
    required _AgentThreadMemory memory,
    required OnyxAgentContextSnapshot snapshot,
    required List<_AgentActionCard> recommendedActions,
  }) {
    if (stacked) {
      return Container(
        color: OnyxColorTokens.backgroundPrimary,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            SizedBox(height: 40, child: _zaraAgentNavRail(compact: true)),
            Container(height: 1, color: OnyxColorTokens.divider),
            _zaraAgentLeftRail(
              hasActiveThread: hasActiveThread,
              thread: thread,
              memory: memory,
              snapshot: snapshot,
              recommendedActions: recommendedActions,
              scrollable: false,
            ),
            Container(height: 1, color: OnyxColorTokens.divider),
            _zaraAgentCenterZone(
              hasActiveThread: hasActiveThread,
              thread: thread,
              memory: memory,
              snapshot: snapshot,
              recommendedActions: recommendedActions,
              scrollable: false,
            ),
            Container(height: 1, color: OnyxColorTokens.divider),
            _zaraAgentRightRail(
              hasActiveThread: hasActiveThread,
              thread: thread,
              memory: memory,
              snapshot: snapshot,
              recommendedActions: recommendedActions,
              scrollable: false,
            ),
          ],
        ),
      );
    }

    return Container(
      color: OnyxColorTokens.backgroundPrimary,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 40, child: _zaraAgentNavRail(compact: false)),
          Container(width: 1, color: OnyxColorTokens.divider),
          SizedBox(
            width: 170,
            child: _zaraAgentLeftRail(
              hasActiveThread: hasActiveThread,
              thread: thread,
              memory: memory,
              snapshot: snapshot,
              recommendedActions: recommendedActions,
            ),
          ),
          Container(width: 1, color: OnyxColorTokens.divider),
          Expanded(
            child: _zaraAgentCenterZone(
              hasActiveThread: hasActiveThread,
              thread: thread,
              memory: memory,
              snapshot: snapshot,
              recommendedActions: recommendedActions,
            ),
          ),
          Container(width: 1, color: OnyxColorTokens.divider),
          SizedBox(
            width: 190,
            child: _zaraAgentRightRail(
              hasActiveThread: hasActiveThread,
              thread: thread,
              memory: memory,
              snapshot: snapshot,
              recommendedActions: recommendedActions,
            ),
          ),
        ],
      ),
    );
  }

  Widget _zaraAgentNavRail({required bool compact}) {
    final sourceLabel = widget.sourceRouteLabel.trim().toLowerCase();
    final items =
        <({IconData icon, String label, bool active, VoidCallback? onTap})>[
          (
            icon: Icons.warning_amber_rounded,
            label: 'Dispatch',
            active: sourceLabel == 'dispatches' || sourceLabel == 'alarms',
            onTap:
                widget.focusIncidentReference.trim().isEmpty &&
                    widget.onOpenAlarms == null &&
                    widget.onOpenAlarmsForIncident == null
                ? null
                : () {
                    _openAlarmsRoute();
                  },
          ),
          (
            icon: Icons.videocam_rounded,
            label: 'CCTV',
            active:
                sourceLabel == 'cctv' ||
                sourceLabel == 'ai queue' ||
                sourceLabel == 'aiqueue' ||
                sourceLabel == 'ai-queue',
            onTap:
                widget.onOpenCctv == null &&
                    widget.onOpenCctvForIncident == null
                ? null
                : () {
                    _openCctvRoute();
                  },
          ),
          (
            icon: Icons.mark_chat_read_rounded,
            label: 'Comms',
            active: sourceLabel == 'clients' || sourceLabel == 'comms',
            onTap:
                widget.onOpenComms == null && widget.onOpenCommsForScope == null
                ? null
                : () {
                    _openCommsRoute();
                  },
          ),
          (
            icon: Icons.route_rounded,
            label: 'Track',
            active: sourceLabel == 'track' || sourceLabel == 'tactical',
            onTap:
                widget.onOpenTrack == null &&
                    widget.onOpenTrackForIncident == null
                ? null
                : () {
                    _openTrackRoute();
                  },
          ),
          (
            icon: Icons.reply_all_rounded,
            label: 'Board',
            active: sourceLabel == 'operations',
            onTap:
                widget.focusIncidentReference.trim().isEmpty ||
                    widget.onOpenOperationsForIncident == null
                ? null
                : _openOperationsRoute,
          ),
        ];

    final buttons = [
      for (final item in items)
        _zaraNavButton(
          icon: item.icon,
          label: item.label,
          active: item.active,
          onTap: item.onTap,
        ),
    ];

    return Container(
      color: OnyxColorTokens.backgroundPrimary,
      child: compact
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: buttons,
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < buttons.length; index++) ...[
                  buttons[index],
                  if (index != buttons.length - 1) const SizedBox(height: 8),
                ],
              ],
            ),
    );
  }

  Widget _zaraNavButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback? onTap,
  }) {
    final foreground = active
        ? OnyxColorTokens.accentPurple
        : onTap == null
        ? OnyxColorTokens.textDisabled
        : OnyxColorTokens.textMuted;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: active
                ? OnyxColorTokens.accentPurple.withValues(alpha: 0.12)
                : OnyxColorTokens.backgroundPrimary,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: active
                  ? OnyxColorTokens.accentPurple.withValues(alpha: 0.22)
                  : OnyxColorTokens.divider,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 15, color: foreground),
        ),
      ),
    );
  }

  Widget _zaraAgentLeftRail({
    required bool hasActiveThread,
    required _AgentThread thread,
    required _AgentThreadMemory memory,
    required OnyxAgentContextSnapshot snapshot,
    required List<_AgentActionCard> recommendedActions,
    bool scrollable = true,
  }) {
    final signalRows = _zaraSignalRows(
      thread: thread,
      memory: memory,
      snapshot: snapshot,
      recommendedActions: recommendedActions,
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _zaraRailHeader(label: 'ACTIVE SIGNALS'),
        Padding(
          padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
          child: hasActiveThread
              ? Column(
                  children: [
                    for (var index = 0; index < signalRows.length; index++) ...[
                      _zaraSignalRow(
                        label: signalRows[index].label,
                        status: signalRows[index].status,
                        dotColor: signalRows[index].dotColor,
                        active: signalRows[index].active,
                      ),
                      if (index != signalRows.length - 1)
                        const SizedBox(height: 3),
                    ],
                  ],
                )
              : Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'No active signals',
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.textDisabled,
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
        ),
        _zaraRailHeader(label: 'ZARA FOCUS', includeDivider: false),
        Padding(
          padding: const EdgeInsets.fromLTRB(11, 2, 11, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _zaraFocusItem(
                label: 'Current task',
                value: hasActiveThread
                    ? _zaraCurrentTaskLabel(thread: thread, memory: memory)
                    : 'No active review',
              ),
              _zaraFocusItem(
                label: 'Cross-referencing',
                value: hasActiveThread
                    ? _zaraCrossReferenceLabel(
                        thread: thread,
                        memory: memory,
                        snapshot: snapshot,
                      )
                    : 'Waiting for the next scoped signal',
              ),
              _zaraFocusItem(
                label: 'Next action',
                value: hasActiveThread
                    ? _zaraNextActionLabel(
                        memory: memory,
                        recommendedActions: recommendedActions,
                      )
                    : 'Standing by',
                valueColor: OnyxColorTokens.accentPurple.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ],
    );

    return Container(
      color: OnyxColorTokens.surfaceInset,
      child: scrollable ? SingleChildScrollView(child: content) : content,
    );
  }

  Widget _zaraSignalRow({
    required String label,
    required String status,
    required Color dotColor,
    required bool active,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundPrimary,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: active
              ? OnyxColorTokens.accentPurple.withValues(alpha: 0.2)
              : OnyxColorTokens.borderSubtle,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: OnyxColorTokens.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status,
            style: GoogleFonts.inter(
              color: active
                  ? OnyxColorTokens.accentPurple.withValues(alpha: 0.6)
                  : OnyxColorTokens.textDisabled,
              fontSize: 8,
              fontWeight: active ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _zaraFocusItem({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textDisabled,
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: GoogleFonts.inter(
              color: valueColor ?? OnyxColorTokens.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _zaraAgentCenterZone({
    required bool hasActiveThread,
    required _AgentThread thread,
    required _AgentThreadMemory memory,
    required OnyxAgentContextSnapshot snapshot,
    required List<_AgentActionCard> recommendedActions,
    bool scrollable = true,
  }) {
    final usedActionIds = <String>{};
    final callAction = _zaraSelectAction(recommendedActions, (action) {
      return action.kind == _AgentActionKind.openComms ||
          action.kind == _AgentActionKind.draftClientReply ||
          action.personaId == 'client';
    });
    if (callAction != null) {
      usedActionIds.add(callAction.id);
    }
    final dispatchAction = _zaraSelectAction(recommendedActions, (action) {
      return action.kind == _AgentActionKind.executeRecommendation ||
          action.kind == _AgentActionKind.openAlarms ||
          action.kind == _AgentActionKind.openTrack ||
          action.kind == _AgentActionKind.openCctv ||
          action.personaId == 'dispatch' ||
          action.personaId == 'camera' ||
          action.personaId == 'intel';
    }, excludedIds: usedActionIds);
    if (dispatchAction != null) {
      usedActionIds.add(dispatchAction.id);
    }
    final escalateAction = _zaraSelectAction(recommendedActions, (action) {
      return action.requiresApproval ||
          action.kind == _AgentActionKind.approveCameraChange ||
          action.personaId == 'escalation' ||
          action.personaId == 'proactive' ||
          action.personaId == 'report';
    }, excludedIds: usedActionIds);

    final actionButtons = <({int flex, Widget child})>[
      if (callAction != null)
        (
          flex: 4,
          child: _zaraActionButton(
            title: 'CALL',
            accent: OnyxColorTokens.accentGreen,
            backgroundAlpha: 0.10,
            borderAlpha: 0.30,
            onTap: () => unawaited(_handleAction(callAction)),
          ),
        ),
      if (dispatchAction != null)
        (
          flex: 5,
          child: _zaraActionButton(
            title: 'DISPATCH',
            subtitle: 'Send response unit',
            accent: OnyxColorTokens.accentRed,
            backgroundAlpha: 0.08,
            borderAlpha: 0.40,
            borderWidth: 1.5,
            onTap: () => unawaited(_handleAction(dispatchAction)),
          ),
        ),
      if (escalateAction != null)
        (
          flex: 4,
          child: _zaraActionButton(
            title: 'ESCALATE',
            accent: OnyxColorTokens.accentAmber.withValues(alpha: 0.8),
            backgroundAlpha: 0.07,
            borderAlpha: 0.22,
            onTap: () => unawaited(_handleAction(escalateAction)),
          ),
        ),
    ];

    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _zaraNeuralHub(stateColor: _zaraHubStateColor(snapshot: snapshot)),
            const SizedBox(height: 10),
            Text(
              'ZARA',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: OnyxColorTokens.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 3),
              decoration: BoxDecoration(
                color: OnyxColorTokens.accentPurple.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: OnyxColorTokens.accentPurple.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: OnyxColorTokens.accentPurple,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _zaraStateLabel(
                      thread: thread,
                      memory: memory,
                      snapshot: snapshot,
                    ),
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.accentPurple.withValues(
                        alpha: 0.8,
                      ),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 1,
              height: 16,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    OnyxColorTokens.accentPurple.withValues(alpha: 0.30),
                    OnyxColorTokens.accentPurple.withValues(alpha: 0.08),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            _zaraIntelligenceCard(
              hasActiveThread: hasActiveThread,
              thread: thread,
              memory: memory,
              snapshot: snapshot,
            ),
            if (actionButtons.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            color: OnyxColorTokens.accentPurple.withValues(
                              alpha: 0.12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ZARA RECOMMENDS',
                          style: GoogleFonts.inter(
                            color: OnyxColorTokens.accentPurple.withValues(
                              alpha: 0.35,
                            ),
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: OnyxColorTokens.accentPurple.withValues(
                              alpha: 0.12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (
                          var index = 0;
                          index < actionButtons.length;
                          index++
                        ) ...[
                          Expanded(
                            flex: actionButtons[index].flex,
                            child: actionButtons[index].child,
                          ),
                          if (index != actionButtons.length - 1)
                            const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: OnyxColorTokens.surfaceElevated,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: OnyxColorTokens.accentPurple.withValues(alpha: 0.20),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 3,
                      height: 20,
                      decoration: BoxDecoration(
                        color: OnyxColorTokens.accentPurple.withValues(
                          alpha: 0.35,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _composerController,
                        enabled: !_reasoningInFlight,
                        minLines: 1,
                        maxLines: 3,
                        style: GoogleFonts.inter(
                          color: OnyxColorTokens.textPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration.collapsed(
                          hintText: 'Ask Zara…',
                          hintStyle: GoogleFonts.inter(
                            color: OnyxColorTokens.textDisabled,
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onSubmitted: (_) => _submitPrompt(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _reasoningInFlight ? null : _submitPrompt,
                      borderRadius: BorderRadius.circular(5),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: OnyxColorTokens.accentPurple.withValues(
                            alpha: 0.15,
                          ),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: OnyxColorTokens.accentPurple.withValues(
                              alpha: 0.30,
                            ),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '↑',
                          style: GoogleFonts.inter(
                            color: OnyxColorTokens.accentPurple,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );

    return Container(
      color: OnyxColorTokens.backgroundPrimary,
      child: scrollable
          ? SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: content,
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: content,
            ),
    );
  }

  Widget _zaraNeuralHub({required Color stateColor}) {
    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _zaraOrbitalRing(240, 0.04),
          _zaraOrbitalRing(205, 0.07),
          _zaraOrbitalRing(172, 0.12),
          _zaraOrbitalRing(140, 0.22),
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              color: OnyxColorTokens.backgroundPrimary,
              shape: BoxShape.circle,
              border: Border.all(
                color: OnyxColorTokens.accentPurple.withValues(alpha: 0.45),
                width: 2,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          OnyxColorTokens.accentPurple.withValues(alpha: 0.08),
                          OnyxColorTokens.accentPurple.withValues(alpha: 0),
                        ],
                        stops: const [0.15, 1],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: OnyxColorTokens.accentPurple.withValues(
                            alpha: 0.18,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: OnyxColorTokens.accentPurple.withValues(
                              alpha: 0.38,
                            ),
                            width: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 100,
                        height: 50,
                        decoration: BoxDecoration(
                          color: OnyxColorTokens.accentPurple.withValues(
                            alpha: 0.10,
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(50),
                          ),
                          border: Border.all(
                            color: OnyxColorTokens.accentPurple.withValues(
                              alpha: 0.22,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: OnyxColorTokens.backgroundPrimary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: OnyxColorTokens.accentPurple.withValues(
                          alpha: 0.25,
                        ),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: stateColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _zaraOrbitalRing(double size, double alpha) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: OnyxColorTokens.accentPurple.withValues(alpha: alpha),
        ),
      ),
    );
  }

  Widget _zaraIntelligenceCard({
    required bool hasActiveThread,
    required _AgentThread thread,
    required _AgentThreadMemory memory,
    required OnyxAgentContextSnapshot snapshot,
  }) {
    final reasoningText = _zaraReasoningText(
      thread: thread,
      memory: memory,
      snapshot: snapshot,
    );
    final title = hasActiveThread
        ? _zaraSituationTitle(thread: thread, memory: memory)
        : 'Standing By';
    final assessment = hasActiveThread
        ? _zaraAssessmentText(
            thread: thread,
            memory: memory,
            snapshot: snapshot,
          )
        : 'ZARA: Standing by. No active review.';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: OnyxColorTokens.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: OnyxColorTokens.accentPurple.withValues(alpha: 0.15),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: OnyxColorTokens.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                assessment,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: OnyxColorTokens.textSecondary.withValues(alpha: 0.42),
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: _zaraMetricBlock(
                      label: 'RECOMMENDATION',
                      value: hasActiveThread
                          ? _zaraRecommendationMetric(
                              memory: memory,
                              thread: thread,
                            )
                          : 'Awaiting task',
                      valueColor: OnyxColorTokens.textPrimary.withValues(
                        alpha: 0.75,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _zaraMetricBlock(
                      label: 'CONFIDENCE',
                      value: hasActiveThread
                          ? _zaraConfidenceMetric(memory)
                          : '--',
                      valueColor: OnyxColorTokens.accentAmber,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _zaraMetricBlock(
                      label: 'ELAPSED',
                      value: hasActiveThread
                          ? _zaraElapsedMetric(
                              thread: thread,
                              memory: memory,
                              snapshot: snapshot,
                            )
                          : '--',
                      valueColor: OnyxColorTokens.accentAmber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              InkWell(
                onTap: () {
                  setState(() {
                    _zaraReasoningExpanded = !_zaraReasoningExpanded;
                  });
                },
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  children: [
                    Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: OnyxColorTokens.accentPurple.withValues(
                          alpha: 0.10,
                        ),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: OnyxColorTokens.accentPurple.withValues(
                            alpha: 0.18,
                          ),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        _zaraReasoningExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 10,
                        color: OnyxColorTokens.accentPurple.withValues(
                          alpha: 0.50,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'View reasoning',
                      style: GoogleFonts.inter(
                        color: OnyxColorTokens.accentPurple.withValues(
                          alpha: 0.45,
                        ),
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasActiveThread &&
                  _zaraReasoningExpanded &&
                  reasoningText.trim().isNotEmpty) ...[
                const SizedBox(height: 9),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: OnyxColorTokens.backgroundPrimary,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: OnyxColorTokens.borderSubtle),
                  ),
                  child: Text(
                    reasoningText,
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: 80,
              height: 1,
              color: OnyxColorTokens.accentPurple.withValues(alpha: 0.40),
            ),
          ),
        ),
      ],
    );
  }

  Widget _zaraMetricBlock({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundPrimary,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: OnyxColorTokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textDisabled,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: valueColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _zaraActionButton({
    required String title,
    String? subtitle,
    required Color accent,
    required double backgroundAlpha,
    required double borderAlpha,
    double borderWidth = 1,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: backgroundAlpha),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: accent.withValues(alpha: borderAlpha),
            width: borderWidth,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: accent,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: accent.withValues(alpha: 0.40),
                  fontSize: 8,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _zaraAgentRightRail({
    required bool hasActiveThread,
    required _AgentThread thread,
    required _AgentThreadMemory memory,
    required OnyxAgentContextSnapshot snapshot,
    required List<_AgentActionCard> recommendedActions,
    bool scrollable = true,
  }) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _zaraRailHeader(label: 'ZARA RECOMMENDS'),
        Padding(
          padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
          child: !hasActiveThread
              ? Text(
                  'Awaiting task',
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.textDisabled,
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                )
              : recommendedActions.isEmpty
              ? Text(
                  'No active approvals queued. Zara is monitoring the current thread.',
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.textDisabled.withValues(alpha: 0.28),
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                )
              : Column(
                  children: [
                    for (
                      var index = 0;
                      index < recommendedActions.take(3).length;
                      index++
                    ) ...[
                      _zaraRecommendationCard(
                        action: recommendedActions[index],
                      ),
                      if (index != recommendedActions.take(3).length - 1)
                        const SizedBox(height: 4),
                    ],
                  ],
                ),
        ),
        _zaraRailHeader(label: 'GUARDRAILS'),
        Padding(
          padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
          child: Column(
            children: [
              _zaraGuardrailLineItem('Local tools stay inside the app first'),
              const SizedBox(height: 8),
              _zaraGuardrailLineItem('Device changes are approval-gated'),
              const SizedBox(height: 8),
              _zaraGuardrailLineItem('Cloud escalation redacts secrets'),
              const SizedBox(height: 8),
              _zaraGuardrailLineItem('Client replies scoped before sending'),
            ],
          ),
        ),
        _zaraRailHeader(label: 'LOCAL TOOLS', includeDivider: false),
        Padding(
          padding: const EdgeInsets.fromLTRB(11, 10, 11, 12),
          child: Column(
            children: [
              _zaraToolRow('Camera Probe', _cameraProbeAvailable),
              const SizedBox(height: 3),
              _zaraToolRow('Client Draft', _clientDraftAvailable),
              const SizedBox(height: 3),
              _zaraToolRow('Camera Bridge', widget.cameraBridgeStatus.isLive),
              const SizedBox(height: 3),
              _zaraToolRow('Client Comms', _commsDraftHandoffAvailable),
            ],
          ),
        ),
      ],
    );

    return Container(
      color: OnyxColorTokens.surfaceInset,
      child: scrollable ? SingleChildScrollView(child: content) : content,
    );
  }

  Widget _zaraRecommendationCard({required _AgentActionCard action}) {
    final accent = _zaraRecommendationAccent(action);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: OnyxColorTokens.divider),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 2,
                color: accent.withValues(alpha: 0.50),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _zaraRecommendationAgentLabel(action),
                        style: GoogleFonts.inter(
                          color: accent.withValues(alpha: 0.60),
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        action.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: OnyxColorTokens.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _zaraCompactText(action.detail, maxLength: 110),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: OnyxColorTokens.textDisabled.withValues(
                            alpha: 0.28,
                          ),
                          fontSize: 8,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: InkWell(
                          onTap: () => unawaited(_handleAction(action)),
                          borderRadius: BorderRadius.circular(3),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: OnyxColorTokens.accentPurple.withValues(
                                alpha: 0.10,
                              ),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                color: OnyxColorTokens.accentPurple.withValues(
                                  alpha: 0.22,
                                ),
                              ),
                            ),
                            child: Text(
                              'Approve',
                              style: GoogleFonts.inter(
                                color: OnyxColorTokens.accentPurple.withValues(
                                  alpha: 0.75,
                                ),
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _zaraToolRow(String label, bool live) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundPrimary,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: OnyxColorTokens.borderSubtle),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: OnyxColorTokens.textMuted,
                fontSize: 8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            live ? 'LIVE' : 'OFFLINE',
            style: GoogleFonts.inter(
              color: live
                  ? OnyxColorTokens.accentGreen
                  : OnyxColorTokens.textDisabled,
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _zaraGuardrailLineItem(String label) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 4,
          margin: const EdgeInsets.only(top: 3),
          decoration: BoxDecoration(
            color: OnyxColorTokens.backgroundPrimary,
            shape: BoxShape.circle,
            border: Border.all(
              color: OnyxColorTokens.accentGreen.withValues(alpha: 0.30),
            ),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textDisabled.withValues(alpha: 0.22),
              fontSize: 8,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _zaraRailHeader({required String label, bool includeDivider = true}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        border: includeDivider
            ? const Border(bottom: BorderSide(color: OnyxColorTokens.divider))
            : null,
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: OnyxColorTokens.textDisabled,
          fontSize: 8,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.3,
        ),
      ),
    );
  }

  List<({String label, String status, Color dotColor, bool active})>
  _zaraSignalRows({
    required _AgentThread thread,
    required _AgentThreadMemory memory,
    required OnyxAgentContextSnapshot snapshot,
    required List<_AgentActionCard> recommendedActions,
  }) {
    final activeSourceId = _zaraCurrentSourceId(
      thread: thread,
      memory: memory,
      snapshot: snapshot,
    );
    final reportActive = _zaraHasRecommendationFor(
      recommendedActions,
      'report',
    );
    final clientActive = _zaraHasRecommendationFor(
      recommendedActions,
      'client',
    );

    return [
      (
        label: 'War Room',
        status: activeSourceId == 'war-room'
            ? 'FOCUS'
            : snapshot.activeDispatchCount > 0
            ? 'ACTIVE'
            : 'IDLE',
        dotColor: activeSourceId == 'war-room'
            ? OnyxColorTokens.accentPurple
            : snapshot.activeDispatchCount > 0
            ? OnyxColorTokens.accentAmber
            : OnyxColorTokens.textDisabled,
        active: activeSourceId == 'war-room',
      ),
      (
        label: 'CCTV Review',
        status: activeSourceId == 'cctv-review'
            ? 'FOCUS'
            : widget.cameraBridgeStatus.isLive
            ? 'ACTIVE'
            : 'IDLE',
        dotColor: activeSourceId == 'cctv-review'
            ? OnyxColorTokens.accentPurple
            : widget.cameraBridgeStatus.isLive
            ? OnyxColorTokens.accentGreen
            : OnyxColorTokens.textDisabled,
        active: activeSourceId == 'cctv-review',
      ),
      (
        label: 'Client Comms',
        status: activeSourceId == 'client-comms'
            ? 'FOCUS'
            : clientActive || _commsDraftHandoffAvailable
            ? 'ACTIVE'
            : 'IDLE',
        dotColor: activeSourceId == 'client-comms'
            ? OnyxColorTokens.accentPurple
            : clientActive || _commsDraftHandoffAvailable
            ? OnyxColorTokens.accentPurple.withValues(alpha: 0.70)
            : OnyxColorTokens.textDisabled,
        active: activeSourceId == 'client-comms',
      ),
      (
        label: 'Signal Picture',
        status: activeSourceId == 'signal-picture'
            ? 'FOCUS'
            : snapshot.hasVisualSignal ||
                  snapshot.latestIntelligenceHeadline.trim().isNotEmpty
            ? 'ACTIVE'
            : 'IDLE',
        dotColor: activeSourceId == 'signal-picture'
            ? OnyxColorTokens.accentPurple
            : snapshot.hasVisualSignal ||
                  snapshot.latestIntelligenceHeadline.trim().isNotEmpty
            ? OnyxColorTokens.accentSky
            : OnyxColorTokens.textDisabled,
        active: activeSourceId == 'signal-picture',
      ),
      (
        label: 'Report Agent',
        status: activeSourceId == 'report-agent'
            ? 'FOCUS'
            : reportActive
            ? 'ACTIVE'
            : 'IDLE',
        dotColor: activeSourceId == 'report-agent'
            ? OnyxColorTokens.accentPurple
            : reportActive
            ? OnyxColorTokens.accentSky
            : OnyxColorTokens.textDisabled,
        active: activeSourceId == 'report-agent',
      ),
    ];
  }

  String _zaraCurrentSourceId({
    required _AgentThread thread,
    required _AgentThreadMemory memory,
    required OnyxAgentContextSnapshot snapshot,
  }) {
    final target = memory.lastRecommendedTarget ?? memory.lastOpenedTarget;
    if (target != null) {
      return switch (target) {
        OnyxToolTarget.dispatchBoard => 'war-room',
        OnyxToolTarget.cctvReview => 'cctv-review',
        OnyxToolTarget.clientComms => 'client-comms',
        OnyxToolTarget.tacticalTrack => 'signal-picture',
        OnyxToolTarget.reportsWorkspace => 'report-agent',
      };
    }
    final latestMessage = _zaraLatestNonUserMessage(thread);
    return switch (latestMessage?.personaId) {
      'camera' => 'cctv-review',
      'client' => 'client-comms',
      'intel' => 'signal-picture',
      'report' => 'report-agent',
      _ when snapshot.hasVisualSignal => 'signal-picture',
      _ => 'war-room',
    };
  }

  _AgentMessage? _zaraLatestNonUserMessage(_AgentThread thread) {
    for (final message in thread.messages.reversed) {
      if (message.kind != _AgentMessageKind.user) {
        return message;
      }
    }
    return thread.messages.isEmpty ? null : thread.messages.last;
  }

  List<_AgentActionCard> _zaraRecommendedActions(_AgentThread thread) {
    final actions = <_AgentActionCard>[];
    final seen = <String>{};
    for (final message in thread.messages.reversed) {
      for (final action in message.actions) {
        final key =
            '${action.kind.name}:${action.label}:${action.personaId}:${action.payload}';
        if (seen.add(key)) {
          actions.add(action);
        }
        if (actions.length >= 4) {
          return actions;
        }
      }
    }
    return actions;
  }

  _AgentActionCard? _zaraSelectAction(
    List<_AgentActionCard> actions,
    bool Function(_AgentActionCard action) matcher, {
    Set<String> excludedIds = const <String>{},
  }) {
    for (final action in actions) {
      if (excludedIds.contains(action.id)) {
        continue;
      }
      if (matcher(action)) {
        return action;
      }
    }
    return null;
  }

  bool _zaraHasRecommendationFor(
    List<_AgentActionCard> actions,
    String personaId,
  ) {
    return actions.any((action) => action.personaId == personaId);
  }

  String _zaraSpeechText({
    required _AgentThread thread,
    required _AgentThreadMemory memory,
    required OnyxAgentContextSnapshot snapshot,
  }) {
    if (_isStandbyThread(thread)) {
      return 'Standing by. No active review.';
    }
    if (memory.lastAdvisory.trim().isNotEmpty) {
      return _zaraCompactText(memory.lastAdvisory);
    }
    if (memory.lastRecommendationSummary.trim().isNotEmpty) {
      return _zaraCompactText(memory.lastRecommendationSummary);
    }
    if (snapshot.latestIntelligenceHeadline.trim().isNotEmpty) {
      return _zaraCompactText(snapshot.latestIntelligenceHeadline);
    }
    final latestMessage = _zaraLatestNonUserMessage(thread);
    if (latestMessage != null) {
      final candidate = latestMessage.headline.trim().isNotEmpty
          ? latestMessage.headline
          : latestMessage.body;
      if (candidate.trim().isNotEmpty) {
        return _zaraCompactText(candidate);
      }
    }
    return _zaraCompactText(_brainStatusSummaryText());
  }

  String _zaraStateLabel({
    required _AgentThread thread,
    required _AgentThreadMemory memory,
    required OnyxAgentContextSnapshot snapshot,
  }) {
    if (_isStandbyThread(thread)) {
      return 'MONITORING';
    }
    if (snapshot.hasHumanSafetySignal || snapshot.hasGuardWelfareRisk) {
      return 'CRITICAL';
    }
    if (_reasoningInFlight) {
      return 'CORRELATING';
    }
    if (memory.pendingConfirmations.isNotEmpty) {
      return 'AWAITING APPROVAL';
    }
    if (memory.lastRecommendedTarget != null) {
      return 'REVIEWING · ${_deskLabelForTarget(memory.lastRecommendedTarget!).toUpperCase()}';
    }
    if (memory.nextFollowUpLabel.trim().isNotEmpty) {
      return 'LISTENING';
    }
    final latestMessage = _zaraLatestNonUserMessage(thread);
    if (latestMessage?.personaId == 'intel') {
      return 'CORRELATING';
    }
    return snapshot.hasAnyOperationalSignal ? 'MONITORING' : 'LISTENING';
  }

  Color _zaraHubStateColor({required OnyxAgentContextSnapshot snapshot}) {
    if (snapshot.hasHumanSafetySignal || snapshot.hasGuardWelfareRisk) {
      return OnyxColorTokens.accentRed;
    }
    if (_reasoningInFlight) {
      return OnyxColorTokens.accentAmber;
    }
    return OnyxColorTokens.accentGreen;
  }

  String _zaraCurrentTaskLabel({
    required _AgentThread thread,
    required _AgentThreadMemory memory,
  }) {
    if (memory.lastRecommendationSummary.trim().isNotEmpty) {
      return _zaraCompactText(memory.lastRecommendationSummary, maxLength: 72);
    }
    final latestMessage = _zaraLatestNonUserMessage(thread);
    if (latestMessage != null && latestMessage.headline.trim().isNotEmpty) {
      return _zaraCompactText(latestMessage.headline, maxLength: 72);
    }
    return _zaraCompactText(thread.title, maxLength: 72);
  }

  String _zaraCrossReferenceLabel({
    required _AgentThread thread,
    required _AgentThreadMemory memory,
    required OnyxAgentContextSnapshot snapshot,
  }) {
    final anchorTime = _zaraAnchorTime(
      thread: thread,
      memory: memory,
      snapshot: snapshot,
    );
    final source = snapshot.latestIntelligenceSourceType.trim().isNotEmpty
        ? snapshot.latestIntelligenceSourceType.trim()
        : memory.lastOpenedTarget == OnyxToolTarget.cctvReview
        ? 'CCTV Review'
        : 'Signal mesh';
    final location = snapshot.prioritySiteLabel.trim().isNotEmpty
        ? snapshot.prioritySiteLabel.trim()
        : snapshot.scopeLabel;
    final timeLabel = anchorTime == null
        ? 'waiting'
        : _hhmm(anchorTime.toLocal());
    return _zaraCompactText('$source · $location · $timeLabel', maxLength: 76);
  }

  String _zaraNextActionLabel({
    required _AgentThreadMemory memory,
    required List<_AgentActionCard> recommendedActions,
  }) {
    if (memory.pendingConfirmations.isNotEmpty) {
      return 'Awaiting approval';
    }
    if (memory.nextFollowUpLabel.trim().isNotEmpty) {
      return _zaraCompactText(memory.nextFollowUpLabel, maxLength: 72);
    }
    if (recommendedActions.isNotEmpty) {
      return _zaraCompactText(recommendedActions.first.label, maxLength: 72);
    }
    return 'Monitoring current scope';
  }

  String _zaraSituationTitle({
    required _AgentThread thread,
    required _AgentThreadMemory memory,
  }) {
    final latestMessage = _zaraLatestNonUserMessage(thread);
    if (latestMessage != null && latestMessage.headline.trim().isNotEmpty) {
      return _zaraCompactText(latestMessage.headline, maxLength: 64);
    }
    if (memory.lastRecommendationSummary.trim().isNotEmpty) {
      return _zaraCompactText(memory.lastRecommendationSummary, maxLength: 64);
    }
    return _zaraCompactText(thread.title, maxLength: 64);
  }

  String _zaraAssessmentText({
    required _AgentThread thread,
    required _AgentThreadMemory memory,
    required OnyxAgentContextSnapshot snapshot,
  }) {
    if (memory.lastAdvisory.trim().isNotEmpty) {
      return _zaraCompactText(memory.lastAdvisory, maxLength: 150);
    }
    final latestMessage = _zaraLatestNonUserMessage(thread);
    if (latestMessage != null && latestMessage.body.trim().isNotEmpty) {
      return _zaraCompactText(latestMessage.body, maxLength: 150);
    }
    return _zaraCompactText(snapshot.toReasoningSummary(), maxLength: 150);
  }

  String _zaraRecommendationMetric({
    required _AgentThreadMemory memory,
    required _AgentThread thread,
  }) {
    if (memory.lastRecommendedTarget != null) {
      return _deskLabelForTarget(memory.lastRecommendedTarget!);
    }
    final latestMessage = _zaraLatestNonUserMessage(thread);
    if (latestMessage != null && latestMessage.headline.trim().isNotEmpty) {
      return _zaraCompactText(latestMessage.headline, maxLength: 18);
    }
    return 'Standby';
  }

  String _zaraConfidenceMetric(_AgentThreadMemory memory) {
    final value = memory.lastConfidence;
    if (value == null) {
      return '--';
    }
    final percentage = (value.clamp(0.0, 1.0) * 100).round();
    return '$percentage%';
  }

  DateTime? _zaraAnchorTime({
    required _AgentThread thread,
    required _AgentThreadMemory memory,
    required OnyxAgentContextSnapshot snapshot,
  }) {
    return snapshot.latestEventAt ??
        snapshot.latestDispatchCreatedAt ??
        memory.updatedAt ??
        _zaraLatestNonUserMessage(thread)?.createdAt;
  }

  String _zaraElapsedMetric({
    required _AgentThread thread,
    required _AgentThreadMemory memory,
    required OnyxAgentContextSnapshot snapshot,
  }) {
    final anchor = _zaraAnchorTime(
      thread: thread,
      memory: memory,
      snapshot: snapshot,
    );
    if (anchor == null) {
      return '--';
    }
    final diff = DateTime.now().difference(anchor);
    if (diff.inHours > 0) {
      return '${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
    }
    final minutes = diff.inMinutes.toString().padLeft(2, '0');
    final seconds = diff.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _zaraReasoningText({
    required _AgentThread thread,
    required _AgentThreadMemory memory,
    required OnyxAgentContextSnapshot snapshot,
  }) {
    final summary = _threadMemoryReasoningSummary(memory).trim();
    if (summary.isNotEmpty) {
      return summary;
    }
    final latestMessage = _zaraLatestNonUserMessage(thread);
    if (latestMessage != null) {
      final parts = [
        latestMessage.headline.trim(),
        latestMessage.body.trim(),
      ].where((part) => part.isNotEmpty).join(' ');
      if (parts.trim().isNotEmpty) {
        return parts.replaceAll(RegExp(r'\s+'), ' ').trim();
      }
    }
    return snapshot.toReasoningSummary();
  }

  String _zaraCompactText(String text, {int maxLength = 120}) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty || normalized.length <= maxLength) {
      return normalized;
    }
    return '${normalized.substring(0, maxLength - 1).trimRight()}…';
  }

  Color _zaraRecommendationAccent(_AgentActionCard action) {
    if (action.personaId == 'camera' ||
        action.kind == _AgentActionKind.openCctv) {
      return OnyxColorTokens.accentGreen;
    }
    if (action.personaId == 'client' ||
        action.kind == _AgentActionKind.openComms ||
        action.kind == _AgentActionKind.draftClientReply) {
      return OnyxColorTokens.accentPurple;
    }
    if (action.personaId == 'dispatch' ||
        action.kind == _AgentActionKind.executeRecommendation ||
        action.kind == _AgentActionKind.openAlarms ||
        action.kind == _AgentActionKind.openTrack) {
      return OnyxColorTokens.accentAmber;
    }
    if (action.requiresApproval) {
      return OnyxColorTokens.accentRed;
    }
    return OnyxColorTokens.accentSky;
  }

  String _zaraRecommendationAgentLabel(_AgentActionCard action) {
    if (action.personaId == 'camera' ||
        action.kind == _AgentActionKind.openCctv) {
      return 'CCTV REVIEW';
    }
    if (action.personaId == 'client' ||
        action.kind == _AgentActionKind.openComms ||
        action.kind == _AgentActionKind.draftClientReply) {
      return 'CLIENT COMMS';
    }
    if (action.personaId == 'dispatch' ||
        action.kind == _AgentActionKind.executeRecommendation ||
        action.kind == _AgentActionKind.openAlarms ||
        action.kind == _AgentActionKind.openTrack) {
      return 'WAR ROOM';
    }
    if (action.personaId == 'report') {
      return 'REPORT AGENT';
    }
    if (action.personaId == 'intel') {
      return 'SIGNAL PICTURE';
    }
    return 'ZARA';
  }

  VoidCallback? _zaraAlertCallback(List<_AgentActionCard> recommendedActions) {
    final dispatchAction = _zaraSelectAction(recommendedActions, (action) {
      return action.kind == _AgentActionKind.executeRecommendation ||
          action.kind == _AgentActionKind.openAlarms ||
          action.kind == _AgentActionKind.openTrack ||
          action.personaId == 'dispatch' ||
          action.personaId == 'camera' ||
          action.personaId == 'intel';
    });
    if (dispatchAction != null) {
      return () => unawaited(_handleAction(dispatchAction));
    }
    if (widget.focusIncidentReference.trim().isNotEmpty &&
        (widget.onOpenAlarmsForIncident != null ||
            widget.onOpenAlarms != null)) {
      return () {
        _openAlarmsRoute();
      };
    }
    if (widget.focusIncidentReference.trim().isNotEmpty &&
        widget.onOpenOperationsForIncident != null) {
      return _openOperationsRoute;
    }
    if (widget.onOpenTrackForIncident != null || widget.onOpenTrack != null) {
      return () {
        _openTrackRoute();
      };
    }
    return null;
  }

  Widget _buildConversationSurface() {
    final thread = _selectedThread;
    final plannerConflictReport = _plannerConflictReport();
    final scopeLabel = _scopeLabel();
    final incidentLabel = widget.focusIncidentReference.trim().isEmpty
        ? 'Board clear'
        : widget.focusIncidentReference.trim();
    final sourceLabel = widget.sourceRouteLabel.trim().isEmpty
        ? 'Command'
        : widget.sourceRouteLabel.trim();
    final resumeRouteAction = _buildResumeRouteAction();
    final operatorFocusBanner = _buildOperatorFocusBanner(
      threadId: thread.id,
      plannerConflictReport: plannerConflictReport,
    );
    final restoredPressureFocusBanner = _buildRestoredPressureFocusBanner(
      threadId: thread.id,
      plannerConflictReport: plannerConflictReport,
    );

    return Container(
      key: const ValueKey('onyx-agent-page'),
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: OnyxColorTokens.borderSubtle),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: LayoutBuilder(
              builder: (context, headerConstraints) {
                final stackHeader =
                    resumeRouteAction != null &&
                    headerConstraints.maxWidth < 880;
                final intro = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Junior Analyst',
                      style: GoogleFonts.inter(
                        color: OnyxColorTokens.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 0.95,
                      ),
                    ),
                  ],
                );
                final threadMemoryBanner = thread.memory.hasData
                    ? _buildThreadMemoryBanner(
                        thread.memory,
                        onFollowUp:
                            thread.memory.nextFollowUpPrompt.trim().isEmpty
                            ? null
                            : () {
                                unawaited(
                                  _submitPrompt(
                                    thread.memory.nextFollowUpPrompt,
                                  ),
                                );
                              },
                      )
                    : null;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (stackHeader) ...[
                      intro,
                      const SizedBox(height: 10),
                      resumeRouteAction,
                    ] else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: intro),
                          if (resumeRouteAction != null) ...[
                            const SizedBox(width: 12),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 280),
                              child: resumeRouteAction,
                            ),
                          ],
                        ],
                      ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _conversationContextChip(
                          icon: Icons.route_rounded,
                          label: sourceLabel,
                          accent: const Color(0xFF8FD1FF),
                        ),
                        _conversationContextChip(
                          icon: Icons.location_on_outlined,
                          label: scopeLabel,
                          accent: const Color(0xFF86EFAC),
                        ),
                        _conversationContextChip(
                          icon: Icons.flag_outlined,
                          label: incidentLabel,
                          accent: const Color(0xFFF1B872),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _brainStatusSummaryText(),
                      style: GoogleFonts.inter(
                        color: OnyxColorTokens.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                    if (operatorFocusBanner != null) ...[
                      const SizedBox(height: 12),
                      operatorFocusBanner,
                    ],
                    if (restoredPressureFocusBanner != null) ...[
                      const SizedBox(height: 12),
                      restoredPressureFocusBanner,
                    ],
                    if (threadMemoryBanner != null) ...[
                      const SizedBox(height: 12),
                      threadMemoryBanner,
                    ],
                    if (_activeEvidenceReturnReceipt != null) ...[
                      const SizedBox(height: 12),
                      _buildEvidenceReturnBanner(_activeEvidenceReturnReceipt!),
                    ],
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1, color: Color(0xFFDDE7F0)),
          Expanded(
            child: ListView.separated(
              key: const ValueKey('onyx-agent-message-list'),
              controller: _messageScrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              itemCount: thread.messages.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final message = thread.messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          const Divider(height: 1, color: Color(0xFFDDE7F0)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildComposerCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildThreadRail({
    required bool compact,
    required _PlannerConflictReport plannerConflictReport,
  }) {
    final orderedThreads = _orderedThreadsForRail(plannerConflictReport);
    return Container(
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OnyxColorTokens.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'CONVERSATIONS',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.9,
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  key: const ValueKey('onyx-agent-new-thread-button'),
                  onPressed: _createThread,
                  icon: const Icon(Icons.add_comment_rounded, size: 14),
                  label: Text(
                    compact ? 'New' : 'New Chat',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: const Size(0, 28),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: orderedThreads.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final thread = orderedThreads[index];
                  final selected = thread.id == _selectedThreadId;
                  final operatorFocus = _threadHasOperatorFocus(thread.id);
                  final operatorFocusNote = _threadOperatorFocusNote(
                    thread.id,
                    plannerConflictReport,
                  );
                  final pressureFocus = _threadHasRestoredPressureFocus(
                    thread.id,
                    plannerConflictReport,
                  );
                  final pressureFocusNote = _threadPressureFocusNote(thread.id);
                  final urgentMaintenanceReason =
                      _threadUrgentMaintenanceReason(
                        thread,
                        plannerConflictReport,
                      );
                  final urgentMaintenance =
                      urgentMaintenanceReason != null &&
                      urgentMaintenanceReason.trim().isNotEmpty;
                  return InkWell(
                    key: ValueKey('onyx-agent-thread-${thread.id}'),
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      if (_consumeSuppressedThreadCardTap(thread.id)) {
                        return;
                      }
                      _selectThread(thread.id);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: selected
                            ? OnyxColorTokens.surfaceInset
                            : OnyxColorTokens.backgroundSecondary,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? OnyxColorTokens.accentCyan.withValues(
                                  alpha: 0.4,
                                )
                              : OnyxColorTokens.divider,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            thread.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: OnyxColorTokens.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _visibleThreadSummary(thread),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: OnyxColorTokens.textSecondary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                          ),
                          if (thread.memory.hasData) ...[
                            const SizedBox(height: 6),
                            Text(
                              _threadMemoryRailLabel(thread.memory),
                              key: ValueKey(
                                'onyx-agent-thread-memory-${thread.id}',
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: selected
                                    ? const Color(0xFF9D4BFF)
                                    : const Color(0xFF6C8198),
                                fontSize: 10.8,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                              ),
                            ),
                          ],
                          if (operatorFocus ||
                              pressureFocus ||
                              urgentMaintenance) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (operatorFocus)
                                  _miniStatusTag(
                                    key: ValueKey(
                                      'onyx-agent-thread-operator-focus-${thread.id}',
                                    ),
                                    label: 'OPERATOR FOCUS',
                                    foreground: const Color(0xFF1D4ED8),
                                    border: const Color(0xFF93C5FD),
                                  ),
                                if (urgentMaintenance)
                                  _miniStatusTag(
                                    label: 'URGENT REVIEW',
                                    foreground: const Color(0xFF991B1B),
                                    border: const Color(0xFFFCA5A5),
                                  ),
                                if (pressureFocus)
                                  _miniStatusTag(
                                    key: ValueKey(
                                      'onyx-agent-thread-pressure-focus-${thread.id}',
                                    ),
                                    label: 'PRESSURE FOCUS',
                                    foreground: const Color(0xFF166534),
                                    border: const Color(0xFF86EFAC),
                                  ),
                              ],
                            ),
                            if (operatorFocusNote != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                operatorFocusNote,
                                key: ValueKey(
                                  'onyx-agent-thread-operator-note-${thread.id}',
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: selected
                                      ? const Color(0xFF9D4BFF)
                                      : const Color(0xFF4A6A8F),
                                  fontSize: 10.6,
                                  fontWeight: FontWeight.w700,
                                  height: 1.35,
                                ),
                              ),
                            ],
                            if (pressureFocusNote != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                pressureFocusNote,
                                key: ValueKey(
                                  'onyx-agent-thread-pressure-note-${thread.id}',
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: selected
                                      ? const Color(0xFF2F6A4F)
                                      : const Color(0xFF3F6F58),
                                  fontSize: 10.6,
                                  fontWeight: FontWeight.w700,
                                  height: 1.35,
                                ),
                              ),
                            ],
                            if (urgentMaintenance) ...[
                              const SizedBox(height: 6),
                              TextButton.icon(
                                key: ValueKey(
                                  'onyx-agent-thread-urgent-reason-${thread.id}',
                                ),
                                onPressed: () {
                                  _suppressThreadCardTapOnce(thread.id);
                                  _focusPlannerMaintenanceAlertForThread(
                                    thread.id,
                                    plannerConflictReport,
                                  );
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF8A3B12),
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  alignment: Alignment.centerLeft,
                                ),
                                icon: const Icon(
                                  Icons.arrow_outward_rounded,
                                  size: 14,
                                ),
                                label: Text(
                                  'Urgent rule: $urgentMaintenanceReason',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF8A3B12),
                                    fontSize: 10.6,
                                    fontWeight: FontWeight.w700,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ],
                          const SizedBox(height: 8),
                          Text(
                            '${thread.messages.length} messages',
                            style: GoogleFonts.inter(
                              color: selected
                                  ? const Color(0xFF9D4BFF)
                                  : const Color(0xFF6C8198),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvidenceReturnBanner(OnyxAgentEvidenceReturnReceipt receipt) {
    return Container(
      key: const ValueKey('onyx-agent-evidence-return-banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: receipt.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: receipt.accent.withValues(alpha: 0.34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            receipt.label,
            style: GoogleFonts.inter(
              color: receipt.accent,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            receipt.headline,
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            receipt.detail,
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildOperatorFocusBanner({
    required String threadId,
    required _PlannerConflictReport plannerConflictReport,
  }) {
    if (!_threadHasOperatorFocus(threadId)) {
      return null;
    }
    final urgentThreadId = _bestThreadIdForPrioritizedMaintenanceFromReport(
      plannerConflictReport,
    );
    final urgentReviewElsewhere =
        urgentThreadId != null && urgentThreadId != threadId;
    final bannerBody = _operatorFocusBannerBody(
      threadId: threadId,
      plannerConflictReport: plannerConflictReport,
    );
    return Container(
      key: const ValueKey('onyx-agent-operator-focus-banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _miniStatusTag(
                key: const ValueKey('onyx-agent-operator-focus-banner-tag'),
                label: 'OPERATOR FOCUS',
                foreground: const Color(0xFF1D4ED8),
                border: const Color(0xFF93C5FD),
              ),
              if (urgentReviewElsewhere)
                _miniStatusTag(
                  key: const ValueKey(
                    'onyx-agent-operator-focus-banner-urgent-tag',
                  ),
                  label: 'URGENT REVIEW ELSEWHERE',
                  foreground: const Color(0xFF8A3B12),
                  border: const Color(0xFFF1B872),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            bannerBody,
            style: GoogleFonts.inter(
              color: const Color(0xFF9D4BFF),
              fontSize: 11.6,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreadMemoryBanner(
    _AgentThreadMemory memory, {
    VoidCallback? onFollowUp,
  }) {
    final orderedContextHighlights = _orderedVisibleContextHighlights(
      memory.lastContextHighlights,
    );
    final replayHistoryLine = _threadMemoryReplayHistoryLine(memory);
    return Container(
      key: const ValueKey('onyx-agent-thread-memory-banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8FC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OnyxColorTokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'THREAD MEMORY',
            style: GoogleFonts.inter(
              color: const Color(0xFF9D4BFF),
              fontSize: 10.8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.45,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _threadMemoryBannerLabel(memory),
            key: const ValueKey('onyx-agent-thread-memory-banner-label'),
            style: GoogleFonts.inter(
              color: const Color(0xFF364A60),
              fontSize: 12.2,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          if (replayHistoryLine != null) ...[
            const SizedBox(height: 8),
            Text(
              replayHistoryLine,
              key: const ValueKey('onyx-agent-thread-memory-replay-history'),
              style: GoogleFonts.inter(
                color: const Color(0xFF9D4BFF),
                fontSize: 11.2,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ],
          if (orderedContextHighlights.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              orderedContextHighlights.join('\n'),
              style: GoogleFonts.inter(
                color: OnyxColorTokens.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ],
          if (_hasSecondLookTelemetry(memory)) ...[
            const SizedBox(height: 8),
            Text(
              _secondLookTelemetryBannerLabel(memory),
              style: GoogleFonts.inter(
                color: const Color(0xFF9D4BFF),
                fontSize: 11.2,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ],
          if (onFollowUp != null &&
              memory.nextFollowUpLabel.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const ValueKey('onyx-agent-thread-memory-follow-up'),
              onPressed: onFollowUp,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2D6CDF),
                side: const BorderSide(color: Color(0xFFB9CCE3)),
                backgroundColor: const Color(0xFFEAF2FC),
              ),
              icon: const Icon(Icons.tips_and_updates_rounded, size: 16),
              label: Text(
                memory.nextFollowUpLabel,
                style: GoogleFonts.inter(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget? _buildRestoredPressureFocusBanner({
    required String threadId,
    required _PlannerConflictReport plannerConflictReport,
  }) {
    if (_restoredPressureFocusThreadId != threadId) {
      return null;
    }
    if (_threadHasOperatorFocus(threadId)) {
      return null;
    }
    if (_bestThreadIdForPrioritizedMaintenanceFromReport(
          plannerConflictReport,
        ) !=
        null) {
      return null;
    }
    final pressureLabel = _restoredPressureFocusLabel?.trim();
    if (pressureLabel == null || pressureLabel.isEmpty) {
      return null;
    }
    final fallbackTitle = _restoredPressureFocusFallbackThreadTitle?.trim();
    final body = fallbackTitle == null || fallbackTitle.isEmpty
        ? 'Restored the highest-pressure thread because $pressureLabel was the strongest saved pressure.'
        : 'Restored the highest-pressure thread because $pressureLabel outranked the previously saved $fallbackTitle thread.';
    return Container(
      key: const ValueKey('onyx-agent-restored-pressure-banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _miniStatusTag(
                key: const ValueKey('onyx-agent-restored-pressure-banner-tag'),
                label: 'PRESSURE FOCUS',
                foreground: const Color(0xFF166534),
                border: const Color(0xFF86EFAC),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: GoogleFonts.inter(
              color: const Color(0xFF166534),
              fontSize: 11.6,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _conversationContextChip({
    required IconData icon,
    required String label,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF9D4BFF),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkRail({required bool compact}) {
    final selectedMemory = _selectedThread.memory;
    final plannerConflictReport = _plannerConflictReport();
    return Container(
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OnyxColorTokens.borderSubtle),
      ),
      child: SingleChildScrollView(
        controller: _networkRailScrollController,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ANALYST NOTES',
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: OnyxColorTokens.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.9,
              ),
            ),
            const SizedBox(height: 8),
            _sideCard(
              title: 'HOW I WORK',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.cloudAssistAvailable
                              ? (_cloudBoostConfigured
                                    ? 'Summon OpenAI when needed'
                                    : 'OpenAI key required')
                              : 'OpenAI reserved for your login',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFE6EEF8),
                            fontSize: 12.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Switch.adaptive(
                        key: const ValueKey('onyx-agent-cloud-boost-toggle'),
                        value: _preferCloudBoost,
                        onChanged: _cloudBoostAvailable
                            ? (value) {
                                setState(() {
                                  _preferCloudBoost = value;
                                });
                              }
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (_hasSecondLookTelemetry(selectedMemory)) ...[
              _buildSecondLookTelemetryCard(selectedMemory),
              const SizedBox(height: 10),
            ],
            if (plannerConflictReport.hasData) ...[
              _buildPlannerConflictReportCard(plannerConflictReport),
              const SizedBox(height: 10),
            ],
            _sideCard(
              title: 'TOOLS',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _coverageChip(
                        _cameraProbeAvailable
                            ? 'Camera Probe Live'
                            : 'Camera Probe Fallback',
                      ),
                      _coverageChip(
                        _cameraChangeAvailable
                            ? 'Camera Change Live'
                            : 'Camera Change Fallback',
                      ),
                      _coverageChip(
                        _clientDraftAvailable
                            ? 'Client Draft Live'
                            : 'Client Draft Fallback',
                      ),
                      _coverageChip(
                        _commsDraftHandoffAvailable
                            ? 'Client Comms Live'
                            : 'Client Comms Manual',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _cameraChangeAvailable
                        ? (_cameraChangeIsStagingMode
                              ? 'Camera control in staging mode • ${widget.cameraChangeService!.executionModeLabel}'
                              : 'Camera execution mode: ${widget.cameraChangeService!.executionModeLabel}')
                        : 'Camera execution mode: fallback guidance only',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF7F93AD),
                      fontSize: 11.3,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  OnyxCameraBridgeShellPanel(
                    cardKey: const ValueKey('onyx-agent-camera-bridge-status'),
                    status: widget.cameraBridgeStatus,
                    surfaceState: _cameraBridgePresentation.surfaceState,
                    snapshot: _cameraBridgePresentation.displaySnapshot,
                    accents: _cameraBridgePresentation.accents,
                    stagingIndicatorKey: const ValueKey(
                      'onyx-agent-camera-staging-indicator',
                    ),
                    stagingIndicatorLabel: _cameraChangeIsStagingMode
                        ? 'Camera control in staging mode'
                        : null,
                    stagingIndicatorDetail: _cameraChangeIsStagingMode
                        ? 'This scope is still in staging for live camera control. Validate CCTV outcomes before treating any approved packet as a confirmed device change.'
                        : null,
                    healthCardKey: const ValueKey(
                      'onyx-agent-camera-bridge-health-result',
                    ),
                    validateButtonKey: const ValueKey(
                      'onyx-agent-camera-bridge-validate',
                    ),
                    onValidate: _validateCameraBridge,
                    validateBusy: _cameraBridgeLocalState.validationInFlight,
                    clearButtonKey: const ValueKey(
                      'onyx-agent-camera-bridge-clear-health',
                    ),
                    onClear: _clearCameraBridgeHealthSnapshot,
                    clearBusy: _cameraBridgeLocalState.resetInFlight,
                    copyButtonKey: const ValueKey(
                      'onyx-agent-camera-bridge-copy',
                    ),
                    onCopy: _copyCameraBridgeSetup,
                  ),
                  const SizedBox(height: 10),
                  _sideCard(
                    title: 'Camera Audit Trail',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recent camera stage, execution, and rollback receipts stay pinned for this controller scope.',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF9CB0C8),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_cameraAuditLoading)
                          Row(
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Refreshing recent audit receipts...',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF8EA3BE),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          )
                        else if (_cameraAuditHistory.isEmpty)
                          Text(
                            _cameraChangeAvailable
                                ? 'No camera audit receipts have been recorded for this scope yet.'
                                : 'Camera audit history becomes available when the live camera change service is wired.',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF7F93AD),
                              fontSize: 11.6,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          )
                        else
                          Column(
                            children: [
                              for (
                                var index = 0;
                                index < _cameraAuditHistory.length;
                                index++
                              )
                                Padding(
                                  padding: EdgeInsets.only(
                                    bottom:
                                        index == _cameraAuditHistory.length - 1
                                        ? 0
                                        : 8,
                                  ),
                                  child: _cameraAuditTile(
                                    _cameraAuditHistory[index],
                                    index: index,
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  _sideCard(
                    title: 'GUARDRAILS',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _guardrailLine(
                          'Local tools stay inside the app and on the LAN first.',
                        ),
                        _guardrailLine(
                          'Any device config change stays approval-gated.',
                        ),
                        _guardrailLine(
                          'Cloud escalation should redact secrets and creds.',
                        ),
                        _guardrailLine(
                          'Client replies always hand off into scoped Client Comms.',
                        ),
                        _guardrailLine(
                          'CCTV analysis should surface important changes only, never spam the UI.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshCameraAuditHistory({bool showLoading = false}) async {
    if (!_cameraChangeAvailable) {
      if (!mounted) return;
      setState(() {
        _cameraAuditLoading = false;
        _cameraAuditHistory = const <OnyxAgentCameraAuditEntry>[];
      });
      return;
    }
    if (showLoading && mounted) {
      setState(() {
        _cameraAuditLoading = true;
      });
    }
    List<OnyxAgentCameraAuditEntry> history;
    try {
      history = await widget.cameraChangeService!.readAuditHistory(
        clientId: widget.scopeClientId,
        siteId: widget.scopeSiteId,
        incidentReference: widget.focusIncidentReference,
      );
    } catch (_) {
      history = const <OnyxAgentCameraAuditEntry>[];
    }
    if (!mounted) return;
    setState(() {
      _cameraAuditLoading = false;
      _cameraAuditHistory = history;
    });
  }

  bool get _cameraChangeIsStagingMode =>
      _cameraChangeAvailable &&
      widget.cameraChangeService!.executionModeLabel.toLowerCase().contains(
        'staging',
      );

  Widget _cameraAuditTile(
    OnyxAgentCameraAuditEntry entry, {
    required int index,
  }) {
    final accent = switch (entry.kind) {
      OnyxAgentCameraAuditKind.staged => const Color(0xFFFDE68A),
      OnyxAgentCameraAuditKind.executed =>
        entry.success ? const Color(0xFF86EFAC) : const Color(0xFFFDA4AF),
      OnyxAgentCameraAuditKind.rolledBack => const Color(0xFF93C5FD),
    };
    return Container(
      key: ValueKey('onyx-agent-camera-audit-$index'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OnyxColorTokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                ),
                child: Text(
                  entry.kindLabel.toUpperCase(),
                  style: GoogleFonts.inter(
                    color: accent,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.target,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.textPrimary,
                    fontSize: 12.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            entry.detail,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          if (entry.vendorLabel.isNotEmpty ||
              entry.profileLabel.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${entry.vendorLabel.isEmpty ? 'Vendor pending' : entry.vendorLabel}${entry.profileLabel.isEmpty ? '' : ' • ${entry.profileLabel}'}',
              style: GoogleFonts.inter(
                color: const Color(0xFFFDE68A),
                fontSize: 10.8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (entry.rollbackExportLabel.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Rollback export: ${entry.rollbackExportLabel}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: OnyxColorTokens.textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '${entry.statusLabel} • ${entry.packetId}${entry.executionId.isEmpty ? '' : ' • ${entry.executionId}'}${entry.rollbackId.isEmpty ? '' : ' • ${entry.rollbackId}'}',
            style: GoogleFonts.inter(
              color: const Color(0xFF73B4FF),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${entry.providerLabel} • ${entry.recordedAtUtc.toIso8601String()}',
            style: GoogleFonts.inter(
              color: const Color(0xFF6C8198),
              fontSize: 10.3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposerCard() {
    final quickPrompts = <({String label, String prompt})>[
      (
        label: 'Check a camera',
        prompt: 'Probe camera 192.168.1.64 and validate RTSP / ONVIF',
      ),
      (
        label: 'Look into guard distress',
        prompt:
            'Possible guard distress in Sector C: heart rate spike plus no movement',
      ),
      (
        label: 'Check patrol proof',
        prompt: 'Verify patrol photo at Gate B against the baseline checkpoint',
      ),
      (
        label: 'Draft a client update',
        prompt: 'Draft a client update for the current incident',
      ),
      (
        label: 'Connect the live signals',
        prompt:
            'Correlate CCTV Review, Tactical Track, and Dispatch Board signals for the active incident',
      ),
      (
        label: 'Draft the report narrative',
        prompt: 'Build a Reports Workspace narrative for the current scope',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var index = 0; index < quickPrompts.length; index++)
              ActionChip(
                key: ValueKey('onyx-agent-quick-prompt-$index'),
                backgroundColor: const Color(0xFF1A1A2E),
                side: const BorderSide(color: Color(0x269D4BFF)),
                onPressed: () => _submitPrompt(quickPrompts[index].prompt),
                label: Text(
                  quickPrompts[index].label,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9D4BFF),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: OnyxColorTokens.borderSubtle),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('onyx-agent-composer-field'),
                  controller: _composerController,
                  minLines: 1,
                  maxLines: 5,
                  enabled: !_reasoningInFlight,
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        'Ask a question, request a check, or ask for a draft...',
                    hintStyle: GoogleFonts.inter(
                      color: const Color(0xFF6C8198),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
                  ),
                  onSubmitted: (_) => _submitPrompt(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 8),
                child: FilledButton.icon(
                  key: const ValueKey('onyx-agent-send-button'),
                  onPressed: _reasoningInFlight ? null : _submitPrompt,
                  icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                  label: Text(
                    _reasoningInFlight ? 'Thinking...' : 'Send',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_reasoningInFlight) ...[
          const SizedBox(height: 8),
          Text(
            _cloudBoostInFlight
                ? 'OpenAI is helping with a deeper second pass.'
                : 'ONYX is thinking through the thread now.',
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMessageBubble(_AgentMessage message) {
    final persona = _personaFor(message.personaId);
    final isUser = message.kind == _AgentMessageKind.user;
    final isTool = message.kind == _AgentMessageKind.tool;
    final accent = isUser
        ? const Color(0xFF7DD3FC)
        : isTool
        ? const Color(0xFFFBBF24)
        : persona.accent;
    final background = isUser
        ? const Color(0x1A9D4BFF)
        : isTool
        ? const Color(0x1AEF9F27)
        : const Color(0xFF1A1A2E);
    final border = isUser
        ? const Color(0x4D9D4BFF)
        : isTool
        ? const Color(0x40EF9F27)
        : OnyxColorTokens.borderSubtle;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth >= 1080
            ? (isUser ? 780.0 : 940.0)
            : constraints.maxWidth * (isUser ? 0.82 : 0.92);
        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isUser
                                  ? Icons.person_rounded
                                  : isTool
                                  ? Icons.memory_rounded
                                  : persona.icon,
                              size: 14,
                              color: accent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isUser
                                  ? 'You'
                                  : isTool
                                  ? 'Tool Result'
                                  : persona.label,
                              style: GoogleFonts.inter(
                                color: accent,
                                fontSize: 11.2,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _hhmm(message.createdAt),
                        style: GoogleFonts.inter(
                          color: const Color(0xFF71859E),
                          fontSize: 10.8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  if (message.headline.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      message.headline,
                      style: GoogleFonts.inter(
                        color: OnyxColorTokens.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 0.95,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    message.body,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF364A60),
                      fontSize: 13.2,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                  if (message.actions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Column(
                      children: [
                        for (
                          var index = 0;
                          index < message.actions.length;
                          index++
                        )
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: index == message.actions.length - 1
                                  ? 0
                                  : 8,
                            ),
                            child: _buildActionCard(message.actions[index]),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionCard(_AgentActionCard action) {
    final persona = _personaFor(action.personaId);
    final buttonLabel = switch (action.kind) {
      _AgentActionKind.seedPrompt => 'Use this',
      _AgentActionKind.executeRecommendation => 'Do this',
      _AgentActionKind.dryProbeCamera => 'Check it',
      _AgentActionKind.stageCameraChange => 'Review it',
      _AgentActionKind.approveCameraChange => 'Approve it',
      _AgentActionKind.logCameraRollback => 'Log rollback',
      _AgentActionKind.draftClientReply => 'Draft it',
      _AgentActionKind.summarizeIncident => 'Summarize it',
      _AgentActionKind.openCctv ||
      _AgentActionKind.openComms ||
      _AgentActionKind.openAlarms ||
      _AgentActionKind.openTrack => 'Open desk',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OnyxColorTokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Suggested by ${persona.label}',
                style: GoogleFonts.inter(
                  color: persona.accent,
                  fontSize: 10.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (action.requiresApproval)
                _miniStatusTag(
                  label: 'Approval',
                  foreground: const Color(0xFFFDE68A),
                  border: const Color(0xFF6B4F18),
                ),
              if (action.opensRoute)
                _miniStatusTag(
                  label: 'Route',
                  foreground: const Color(0xFFBFDBFE),
                  border: const Color(0xFF28476B),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            action.label,
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textPrimary,
              fontSize: 13.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            action.detail,
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: ValueKey('onyx-agent-action-${action.id}'),
              onPressed: () {
                unawaited(_handleAction(action));
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: persona.accent,
                backgroundColor: persona.accent.withValues(alpha: 0.1),
                side: BorderSide(color: persona.accent.withValues(alpha: 0.3)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(
                action.opensRoute
                    ? Icons.open_in_new_rounded
                    : action.requiresApproval
                    ? Icons.rule_rounded
                    : Icons.play_arrow_rounded,
                size: 16,
              ),
              label: Text(
                buttonLabel,
                style: GoogleFonts.inter(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _coverageChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: OnyxColorTokens.borderSubtle),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: const Color(0xFF9D4BFF),
          fontSize: 10.6,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildSecondLookTelemetryCard(_AgentThreadMemory memory) {
    return _sideCard(
      cardKey: const ValueKey('onyx-agent-second-look-telemetry'),
      title: 'SECOND LOOK TELEMETRY',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _secondLookTelemetryBannerLabel(memory),
            style: GoogleFonts.inter(
              color: const Color(0xFF364A60),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          if (memory.lastSecondLookConflictAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Last logged: ${_conflictTelemetryTimestampLabel(memory.lastSecondLookConflictAt!)}',
              style: GoogleFonts.inter(
                color: OnyxColorTokens.textSecondary,
                fontSize: 11.2,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Typed desk rules still win routing, but this thread keeps a lightweight count of model disagreements so we can tune planner gaps later.',
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textSecondary,
              fontSize: 11.4,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlannerConflictReportCard(_PlannerConflictReport report) {
    final topModelTarget = report.topModelTarget;
    final topTypedTarget = report.topTypedTarget;
    final topMaintenanceAlert = report.topMaintenanceAlert;
    final reviewedEntries = report.backlogEntries
        .where((entry) => entry.reviewStatus != null)
        .toList(growable: false);
    return _sideCard(
      cardKey: const ValueKey('onyx-agent-planner-conflict-report'),
      title: 'PLANNER REPORT',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _plannerConflictReportSummary(report),
            style: GoogleFonts.inter(
              color: const Color(0xFF364A60),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          if (topMaintenanceAlert != null &&
              topMaintenanceAlert.staleAgainCount > 0) ...[
            const SizedBox(height: 8),
            TextButton(
              key: const ValueKey('onyx-agent-planner-most-regressed-rule'),
              onPressed: () {
                _focusPlannerMaintenanceAlertBySignal(
                  topMaintenanceAlert.signalId,
                  contextLabel: buildPlannerFocusContextLabel(
                    OnyxPlannerFocusContext.summary,
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: OnyxColorTokens.textSecondary,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                alignment: Alignment.centerLeft,
              ),
              child: Text(
                _plannerMostRegressedRuleLabel(report, topMaintenanceAlert),
                style: GoogleFonts.inter(
                  color: OnyxColorTokens.textSecondary,
                  fontSize: 11.4,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
            ),
          ],
          if (topModelTarget != null) ...[
            const SizedBox(height: 8),
            TextButton(
              key: const ValueKey('onyx-agent-planner-top-model-drift'),
              onPressed: () {
                _focusPlannerReportSection(
                  'model-drift',
                  contextLabel: buildPlannerFocusContextLabel(
                    OnyxPlannerFocusContext.modelDriftDetail,
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: OnyxColorTokens.textSecondary,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                alignment: Alignment.centerLeft,
              ),
              child: Text(
                buildSecondLookPlannerTopModelDriftLabel(
                  deskLabel: _deskLabelForTarget(topModelTarget.target),
                  count: topModelTarget.count,
                ),
                style: GoogleFonts.inter(
                  color: OnyxColorTokens.textSecondary,
                  fontSize: 11.4,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
            ),
          ],
          if (topTypedTarget != null) ...[
            const SizedBox(height: 6),
            TextButton(
              key: const ValueKey('onyx-agent-planner-top-typed-hold'),
              onPressed: () {
                _focusPlannerReportSection(
                  'typed-holds',
                  contextLabel: buildPlannerFocusContextLabel(
                    OnyxPlannerFocusContext.typedHoldDetail,
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: OnyxColorTokens.textSecondary,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                alignment: Alignment.centerLeft,
              ),
              child: Text(
                buildSecondLookPlannerTopTypedHoldLabel(
                  deskLabel: _deskLabelForTarget(topTypedTarget.target),
                  count: topTypedTarget.count,
                ),
                style: GoogleFonts.inter(
                  color: OnyxColorTokens.textSecondary,
                  fontSize: 11.4,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
            ),
          ],
          if (report.routeClosedConflictCount > 0) ...[
            const SizedBox(height: 6),
            TextButton(
              key: const ValueKey('onyx-agent-planner-route-closed-summary'),
              onPressed: () {
                _focusPlannerReportSection(
                  'safety-holds',
                  contextLabel: buildPlannerFocusContextLabel(
                    OnyxPlannerFocusContext.safetyHoldDetail,
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: OnyxColorTokens.textSecondary,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                alignment: Alignment.centerLeft,
              ),
              child: Text(
                buildPlannerRouteClosedSummaryLabel(
                  count: report.routeClosedConflictCount,
                ),
                style: GoogleFonts.inter(
                  color: OnyxColorTokens.textSecondary,
                  fontSize: 11.4,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
            ),
          ],
          if (report.modelTargetCounts.isNotEmpty) ...[
            const SizedBox(height: 10),
            _plannerReportFocusSection(
              sectionId: 'model-drift',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MODEL DRIFT',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF9D4BFF),
                      fontSize: 10.6,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: report.modelTargetCounts
                        .map(
                          (entry) => _coverageChip(
                            '${_deskLabelForTarget(entry.target)} ${entry.count}',
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
              ),
            ),
          ],
          if (report.typedTargetCounts.isNotEmpty) ...[
            const SizedBox(height: 10),
            _plannerReportFocusSection(
              sectionId: 'typed-holds',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TYPED HOLDS',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF9D4BFF),
                      fontSize: 10.6,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: report.typedTargetCounts
                        .map(
                          (entry) => _coverageChip(
                            '${_deskLabelForTarget(entry.target)} ${entry.count}',
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
              ),
            ),
          ],
          if (report.routeClosedConflictCount > 0) ...[
            const SizedBox(height: 10),
            _plannerReportFocusSection(
              sectionId: 'safety-holds',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SAFETY HOLDS',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF9D4BFF),
                      fontSize: 10.6,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    report.routeClosedConflictCount == 1
                        ? 'Route safety guardrails held 1 route closed while second-look pressure disagreed.'
                        : 'Route safety guardrails held ${report.routeClosedConflictCount} routes closed while second-look pressure disagreed.',
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.textSecondary,
                      fontSize: 11.4,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (report.maintenanceAlerts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'MAINTENANCE ALERTS',
              style: GoogleFonts.inter(
                color: const Color(0xFF8A3B12),
                fontSize: 10.6,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 8),
            for (final alert in report.maintenanceAlerts)
              Builder(
                builder: (context) {
                  final signalKey = _plannerSignalKey(alert.signalId);
                  final focused = _focusedPlannerSignalId == alert.signalId;
                  return AnimatedContainer(
                    key: _plannerMaintenanceAlertAnchorKey(alert.signalId),
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: focused
                          ? const Color(0xFFFFF7ED)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: focused
                            ? const Color(0xFFF59E0B)
                            : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _miniStatusTag(
                              label: alert.reviewReopened
                                  ? 'REVIEW REOPENED'
                                  : alert.reviewCompleted
                                  ? 'REVIEW COMPLETED'
                                  : alert.reviewQueued
                                  ? 'RULE REVIEW QUEUED'
                                  : 'REVIEW NOW',
                              foreground: alert.reviewReopened
                                  ? const Color(0xFF8A3B12)
                                  : alert.reviewCompleted
                                  ? const Color(0xFF166534)
                                  : alert.reviewQueued
                                  ? const Color(0xFF2D6CDF)
                                  : const Color(0xFF8A3B12),
                              border: alert.reviewReopened
                                  ? const Color(0xFFF59E0B)
                                  : alert.reviewCompleted
                                  ? const Color(0xFF86EFAC)
                                  : alert.reviewQueued
                                  ? const Color(0xFF9CB9DA)
                                  : const Color(0xFFF59E0B),
                            ),
                            if (focused)
                              _miniStatusTag(
                                key: ValueKey(
                                  'onyx-agent-planner-maintenance-focus-$signalKey',
                                ),
                                label: 'THREAD SHORTCUT',
                                foreground: const Color(0xFF8A3B12),
                                border: const Color(0xFFF59E0B),
                              ),
                            if (_plannerMaintenanceBurnTagLabel(report, alert)
                                case final burnTagLabel?)
                              _miniStatusTag(
                                label: burnTagLabel,
                                foreground: burnTagLabel == 'HIGHEST BURN'
                                    ? const Color(0xFF8A3B12)
                                    : const Color(0xFF9A3412),
                                border: burnTagLabel == 'HIGHEST BURN'
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFFFBBF24),
                              ),
                            if (alert.reviewPrioritized)
                              _miniStatusTag(
                                label: 'URGENT MAINTENANCE',
                                foreground: const Color(0xFF991B1B),
                                border: const Color(0xFFFCA5A5),
                              ),
                            Text(
                              _plannerMaintenanceAlertMessage(report, alert),
                              style: GoogleFonts.inter(
                                color: OnyxColorTokens.textSecondary,
                                fontSize: 11.4,
                                fontWeight: FontWeight.w600,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                        if (focused) ...[
                          const SizedBox(height: 6),
                          Text(
                            _focusedPlannerSignalContextLabel ??
                                'Focused in planner report.',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF8A3B12),
                              fontSize: 11.2,
                              fontWeight: FontWeight.w700,
                              height: 1.45,
                            ),
                          ),
                        ],
                        if (alert.reviewQueuedAt != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            '${alert.reviewReopened ? 'Review reopened after worsening' : 'Queued for rule review'}: ${_conflictTelemetryTimestampLabel(alert.reviewQueuedAt!)}',
                            style: GoogleFonts.inter(
                              color: OnyxColorTokens.textSecondary,
                              fontSize: 11.2,
                              fontWeight: FontWeight.w600,
                              height: 1.45,
                            ),
                          ),
                        ],
                        if (alert.reviewCompletedAt != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Review completed: ${_conflictTelemetryTimestampLabel(alert.reviewCompletedAt!)}',
                            style: GoogleFonts.inter(
                              color: OnyxColorTokens.textSecondary,
                              fontSize: 11.2,
                              fontWeight: FontWeight.w600,
                              height: 1.45,
                            ),
                          ),
                        ],
                        if (alert.reviewPrioritizedAt != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Urgent maintenance prioritized: ${_conflictTelemetryTimestampLabel(alert.reviewPrioritizedAt!)}',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF8A3B12),
                              fontSize: 11.2,
                              fontWeight: FontWeight.w700,
                              height: 1.45,
                            ),
                          ),
                        ],
                        if (alert.staleAgainCount > 0) ...[
                          const SizedBox(height: 6),
                          Text(
                            alert.staleAgainCount == 1
                                ? 'Review reopened after completion 1 time.'
                                : 'Review reopened after completion ${alert.staleAgainCount} times. Rule keeps regressing after repeated review cycles.',
                            style: GoogleFonts.inter(
                              color: OnyxColorTokens.textSecondary,
                              fontSize: 11.2,
                              fontWeight: FontWeight.w600,
                              height: 1.45,
                            ),
                          ),
                        ],
                        if (_plannerReactivationEntryForSignal(
                              report,
                              alert.signalId,
                            )
                            case final lineageEntry?) ...[
                          const SizedBox(height: 6),
                          _miniStatusTag(
                            label: 'FROM ARCHIVE',
                            foreground: const Color(0xFF9D4BFF),
                            border: const Color(0xFF93C5FD),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _plannerMaintenanceLineageMessage(lineageEntry),
                            style: GoogleFonts.inter(
                              color: OnyxColorTokens.textSecondary,
                              fontSize: 11.2,
                              fontWeight: FontWeight.w600,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _plannerShortcutTextButton(
                            key: ValueKey(
                              'onyx-agent-planner-maintenance-lineage-$signalKey',
                            ),
                            label: 'View archive lineage',
                            onPressed: () {
                              _focusPlannerReactivationEntryBySignal(
                                alert.signalId,
                                contextLabel: buildPlannerFocusContextLabel(
                                  OnyxPlannerFocusContext
                                      .archiveLineageFromMaintenanceAlert,
                                ),
                              );
                            },
                          ),
                        ],
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _plannerMaintenanceAlertButtons(
                            report,
                            alert,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
          if (report.tuningSignals.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'DRIFT WATCH',
              style: GoogleFonts.inter(
                color: const Color(0xFF9D4BFF),
                fontSize: 10.6,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 8),
            for (final signal in report.tuningSignals)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Builder(
                  builder: (context) {
                    final signalId = _plannerSignalIdForTrendMessage(
                      report,
                      signal,
                    );
                    final navigable =
                        signalId != null &&
                        _plannerHasNavigableRuleForSignal(report, signalId);
                    if (!navigable) {
                      return Text(
                        signal,
                        style: GoogleFonts.inter(
                          color: OnyxColorTokens.textSecondary,
                          fontSize: 11.4,
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                        ),
                      );
                    }
                    return _plannerShortcutTextButton(
                      key: ValueKey(
                        'onyx-agent-planner-drift-watch-${_plannerSignalKey(signalId)}',
                      ),
                      label: signal,
                      onPressed: () {
                        _focusPlannerRuleForSignal(
                          report,
                          signalId,
                          contextLabel: buildPlannerFocusContextLabel(
                            OnyxPlannerFocusContext.driftWatch,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
          if (report.tuningSuggestions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'SELF-TUNING CUES',
              style: GoogleFonts.inter(
                color: const Color(0xFF9D4BFF),
                fontSize: 10.6,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 8),
            for (final suggestion in report.tuningSuggestions)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Builder(
                  builder: (context) {
                    final signalId = _plannerSignalIdForTuningSuggestionMessage(
                      report,
                      suggestion,
                    );
                    final navigable =
                        signalId != null &&
                        _plannerHasNavigableRuleForSignal(report, signalId);
                    if (!navigable) {
                      return Text(
                        suggestion,
                        style: GoogleFonts.inter(
                          color: OnyxColorTokens.textSecondary,
                          fontSize: 11.4,
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                        ),
                      );
                    }
                    return _plannerShortcutTextButton(
                      key: ValueKey(
                        'onyx-agent-planner-tuning-cue-${_plannerSignalKey(signalId)}',
                      ),
                      label: suggestion,
                      onPressed: () {
                        _focusPlannerRuleForSignal(
                          report,
                          signalId,
                          contextLabel: buildPlannerFocusContextLabel(
                            OnyxPlannerFocusContext.tuningCue,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
          if (report.reactivationEntries.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'REACTIVATED',
              style: GoogleFonts.inter(
                color: const Color(0xFF9D4BFF),
                fontSize: 10.6,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 8),
            for (final entry in report.reactivationEntries)
              Builder(
                builder: (context) {
                  final signalKey = _plannerSignalKey(entry.signalId);
                  final focused =
                      _focusedPlannerReactivationSignalId == entry.signalId;
                  final message = _plannerReactivationMessage(entry);
                  final navigable = _plannerHasNavigableRuleForSignal(
                    report,
                    entry.signalId,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: AnimatedContainer(
                      key: _plannerReactivationEntryAnchorKey(entry.signalId),
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: focused
                            ? const Color(0xFFEFF6FF)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: focused
                              ? const Color(0xFF93C5FD)
                              : Colors.transparent,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (focused) ...[
                            _miniStatusTag(
                              key: ValueKey(
                                'onyx-agent-planner-reactivation-focus-$signalKey',
                              ),
                              label: 'LINEAGE SHORTCUT',
                              foreground: const Color(0xFF1D4ED8),
                              border: const Color(0xFF93C5FD),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _focusedPlannerSignalContextLabel ??
                                  'Focused reactivation lineage.',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF9D4BFF),
                                fontSize: 11.2,
                                fontWeight: FontWeight.w700,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (!navigable)
                            Text(
                              message,
                              style: GoogleFonts.inter(
                                color: OnyxColorTokens.textSecondary,
                                fontSize: 11.4,
                                fontWeight: FontWeight.w600,
                                height: 1.45,
                              ),
                            )
                          else
                            _plannerShortcutTextButton(
                              key: ValueKey(
                                'onyx-agent-planner-reactivated-$signalKey',
                              ),
                              label: message,
                              onPressed: () {
                                _focusPlannerRuleForSignal(
                                  report,
                                  entry.signalId,
                                  contextLabel:
                                      'Focused from reactivated rule.',
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
          if (report.archivedReviewedCount > 0) ...[
            const SizedBox(height: 10),
            if (report.archivedEntries.isEmpty)
              Text(
                buildPlannerArchivedBucketSummaryLabel(
                  archivedReviewedCount: report.archivedReviewedCount,
                ),
                style: GoogleFonts.inter(
                  color: OnyxColorTokens.textSecondary,
                  fontSize: 11.4,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              )
            else
              _plannerShortcutTextButton(
                key: const ValueKey('onyx-agent-planner-archived-summary'),
                label: buildPlannerArchivedBucketSummaryLabel(
                  archivedReviewedCount: report.archivedReviewedCount,
                ),
                onPressed: () {
                  _focusPlannerArchivedBucket(
                    report,
                    contextLabel: buildPlannerFocusContextLabel(
                      OnyxPlannerFocusContext.archivedRuleBucket,
                    ),
                  );
                },
              ),
          ],
          if (report.archivedEntries.isNotEmpty) ...[
            const SizedBox(height: 10),
            _plannerReportFocusSection(
              sectionId: 'archived-rules',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ARCHIVED WATCH',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF9D4BFF),
                      fontSize: 10.6,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final entry in report.archivedEntries)
                    Builder(
                      builder: (context) {
                        final signalKey = _plannerSignalKey(entry.signalId);
                        final focused =
                            _focusedPlannerArchivedSignalId == entry.signalId;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: AnimatedContainer(
                            key: _plannerArchivedEntryAnchorKey(entry.signalId),
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: focused
                                  ? const Color(0xFFEFF6FF)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: focused
                                    ? const Color(0xFF93C5FD)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (focused) ...[
                                  _miniStatusTag(
                                    key: ValueKey(
                                      'onyx-agent-planner-archived-focus-$signalKey',
                                    ),
                                    label: 'SUMMARY SHORTCUT',
                                    foreground: const Color(0xFF1D4ED8),
                                    border: const Color(0xFF93C5FD),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _focusedPlannerSignalContextLabel ??
                                        buildPlannerFocusContextLabel(
                                          OnyxPlannerFocusContext
                                              .archivedRuleBucket,
                                        ),
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF9D4BFF),
                                      fontSize: 11.2,
                                      fontWeight: FontWeight.w700,
                                      height: 1.45,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                Text(
                                  _plannerArchivedMessage(entry),
                                  style: GoogleFonts.inter(
                                    color: OnyxColorTokens.textSecondary,
                                    fontSize: 11.4,
                                    fontWeight: FontWeight.w600,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
          if (report.backlogEntries.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'CHANGE NEXT',
              style: GoogleFonts.inter(
                color: const Color(0xFF9D4BFF),
                fontSize: 10.6,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 8),
            if (reviewedEntries.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _plannerBacklogMaintenanceButtons(report),
              ),
              const SizedBox(height: 8),
            ],
            for (final entry in report.backlogEntries.take(3))
              Builder(
                builder: (context) {
                  final signalKey = _plannerSignalKey(entry.signalId);
                  final focused =
                      _focusedPlannerBacklogSignalId == entry.signalId;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: AnimatedContainer(
                      key: _plannerBacklogEntryAnchorKey(entry.signalId),
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: focused
                            ? const Color(0xFFEFF6FF)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: focused
                              ? const Color(0xFF93C5FD)
                              : Colors.transparent,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (focused) ...[
                            _miniStatusTag(
                              key: ValueKey(
                                'onyx-agent-planner-backlog-focus-$signalKey',
                              ),
                              label: 'SUMMARY SHORTCUT',
                              foreground: const Color(0xFF1D4ED8),
                              border: const Color(0xFF93C5FD),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _focusedPlannerSignalContextLabel ??
                                  'Focused in planner backlog.',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF9D4BFF),
                                fontSize: 11.2,
                                fontWeight: FontWeight.w700,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Priority ${entry.score} · ${entry.active ? 'hot now' : 'watch'} · ${entry.label}',
                                style: GoogleFonts.inter(
                                  color: OnyxColorTokens.textSecondary,
                                  fontSize: 11.4,
                                  fontWeight: FontWeight.w600,
                                  height: 1.45,
                                ),
                              ),
                              if (entry.reviewStatus != null)
                                _miniStatusTag(
                                  label: _plannerBacklogReviewStatusLabel(
                                    entry.reviewStatus!,
                                  ),
                                  foreground: const Color(0xFF2D6CDF),
                                  border: const Color(0xFF9CB9DA),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _plannerBacklogReviewButtons(entry),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ],
      ),
    );
  }

  String _plannerMaintenanceAlertMessage(
    _PlannerConflictReport report,
    _PlannerMaintenanceAlertEntry alert,
  ) {
    final inlineLabel = _plannerInlineRuleLabel(alert.label);
    final severityLabel =
        _plannerReactivationEntryForSignal(report, alert.signalId) == null
        ? 'chronic drift'
        : 'chronic drift from archived watch';
    if (alert.reviewReopened) {
      return 'Completed maintenance review for $severityLabel on $inlineLabel has gone stale after the drift worsened again. Reactivated ${alert.reactivationCount} times. Planner review is back in queue.';
    }
    if (alert.reviewCompleted) {
      return 'Maintenance review completed for $severityLabel on $inlineLabel. Reactivated ${alert.reactivationCount} times. ONYX will keep tracking the signal without reopening the alert unless the drift shifts again.';
    }
    if (alert.reviewQueued) {
      return 'Maintenance alert: ${_sentenceCase(severityLabel)} on $inlineLabel. Reactivated ${alert.reactivationCount} times. Rule review is queued.';
    }
    return 'Maintenance alert: ${_sentenceCase(severityLabel)} on $inlineLabel. Reactivated ${alert.reactivationCount} times. Planner review should happen now.';
  }

  String _plannerMostRegressedRuleLabel(
    _PlannerConflictReport report,
    _PlannerMaintenanceAlertEntry alert,
  ) {
    final count = alert.staleAgainCount;
    final reopenLabel = count == 1 ? '1 time' : '$count times';
    final inlineLabel = _plannerInlineRuleLabel(alert.label);
    final originLabel =
        _plannerReactivationEntryForSignal(report, alert.signalId) == null
        ? ''
        : ' from archived watch';
    return 'Most regressed rule: $inlineLabel$originLabel reopened after review $reopenLabel.';
  }

  String _plannerInlineRuleLabel(String label) {
    return label.trim().replaceFirst(RegExp(r'[.!?]+$'), '');
  }

  String _sentenceCase(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    return '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
  }

  List<Widget> _plannerMaintenanceAlertButtons(
    _PlannerConflictReport report,
    _PlannerMaintenanceAlertEntry alert,
  ) {
    final signalKey = _plannerSignalKey(alert.signalId);
    if (alert.reviewReopened) {
      return <Widget>[
        if (_plannerMaintenanceCanPrioritize(report, alert))
          _plannerBacklogMaintenanceButton(
            key: ValueKey(
              'onyx-agent-planner-maintenance-prioritize-$signalKey',
            ),
            label: alert.reviewPrioritized
                ? 'Refresh priority'
                : 'Prioritize review now',
            onPressed: () {
              _prioritizePlannerMaintenanceReview(
                signalId: alert.signalId,
                label: alert.label,
              );
            },
          ),
        _plannerBacklogMaintenanceButton(
          key: ValueKey('onyx-agent-planner-maintenance-complete-$signalKey'),
          label: 'Mark review completed',
          onPressed: () {
            _completePlannerMaintenanceReview(
              signalId: alert.signalId,
              label: alert.label,
            );
          },
        ),
        _plannerBacklogMaintenanceButton(
          key: ValueKey('onyx-agent-planner-maintenance-review-$signalKey'),
          label: 'Clear review mark',
          onPressed: () {
            _clearPlannerMaintenanceReview(
              signalId: alert.signalId,
              label: alert.label,
            );
          },
        ),
      ];
    }
    if (alert.reviewCompleted) {
      return <Widget>[
        _plannerBacklogMaintenanceButton(
          key: ValueKey('onyx-agent-planner-maintenance-reopen-$signalKey'),
          label: 'Reopen review',
          onPressed: () {
            _reopenPlannerMaintenanceReview(
              signalId: alert.signalId,
              label: alert.label,
            );
          },
        ),
      ];
    }
    if (alert.reviewQueued) {
      return <Widget>[
        _plannerBacklogMaintenanceButton(
          key: ValueKey('onyx-agent-planner-maintenance-complete-$signalKey'),
          label: 'Mark review completed',
          onPressed: () {
            _completePlannerMaintenanceReview(
              signalId: alert.signalId,
              label: alert.label,
            );
          },
        ),
        _plannerBacklogMaintenanceButton(
          key: ValueKey('onyx-agent-planner-maintenance-review-$signalKey'),
          label: 'Clear review mark',
          onPressed: () {
            _clearPlannerMaintenanceReview(
              signalId: alert.signalId,
              label: alert.label,
            );
          },
        ),
      ];
    }
    return <Widget>[
      _plannerBacklogMaintenanceButton(
        key: ValueKey('onyx-agent-planner-maintenance-review-$signalKey'),
        label: 'Mark for rule review',
        onPressed: () {
          _queuePlannerMaintenanceReview(
            signalId: alert.signalId,
            label: alert.label,
          );
        },
      ),
    ];
  }

  void _queuePlannerMaintenanceReview({
    required String signalId,
    required String label,
  }) {
    final nextQueuedAt = Map<String, DateTime>.from(
      _plannerMaintenanceReviewQueuedAt,
    )..[signalId] = DateTime.now();
    final nextCompletedAt = Map<String, DateTime>.from(
      _plannerMaintenanceReviewCompletedAt,
    )..remove(signalId);
    final nextPrioritizedAt = Map<String, DateTime>.from(
      _plannerMaintenanceReviewPrioritizedAt,
    )..remove(signalId);
    final nextReopenedCounts = Map<String, int>.from(
      _plannerMaintenanceReviewReopenedCounts,
    )..remove(signalId);
    final nextCompletedSignalCounts = Map<String, int>.from(
      _plannerMaintenanceReviewCompletedSignalCounts,
    )..remove(signalId);
    final nextCompletedReactivationCounts = Map<String, int>.from(
      _plannerMaintenanceReviewCompletedReactivationCounts,
    )..remove(signalId);
    _setPlannerMaintenanceReviewState(
      queuedAt: nextQueuedAt,
      completedAt: nextCompletedAt,
      prioritizedAt: nextPrioritizedAt,
      reopenedCounts: nextReopenedCounts,
      completedSignalCounts: nextCompletedSignalCounts,
      completedReactivationCounts: nextCompletedReactivationCounts,
      summary: 'Planner maintenance review queued',
      body:
          'Marked $label for planner rule review. ONYX will keep the chronic drift visible, but the alert will show that maintenance review is already queued.',
    );
  }

  void _prioritizePlannerMaintenanceReview({
    required String signalId,
    required String label,
  }) {
    final focusThreadId = _bestThreadIdForPlannerSignal(signalId);
    final nextQueuedAt = Map<String, DateTime>.from(
      _plannerMaintenanceReviewQueuedAt,
    )..[signalId] = DateTime.now();
    final nextCompletedAt = Map<String, DateTime>.from(
      _plannerMaintenanceReviewCompletedAt,
    );
    final nextPrioritizedAt = Map<String, DateTime>.from(
      _plannerMaintenanceReviewPrioritizedAt,
    )..[signalId] = DateTime.now();
    final nextReopenedCounts = Map<String, int>.from(
      _plannerMaintenanceReviewReopenedCounts,
    );
    final nextCompletedSignalCounts = Map<String, int>.from(
      _plannerMaintenanceReviewCompletedSignalCounts,
    );
    final nextCompletedReactivationCounts = Map<String, int>.from(
      _plannerMaintenanceReviewCompletedReactivationCounts,
    );
    _setPlannerMaintenanceReviewState(
      queuedAt: nextQueuedAt,
      completedAt: nextCompletedAt,
      prioritizedAt: nextPrioritizedAt,
      reopenedCounts: nextReopenedCounts,
      completedSignalCounts: nextCompletedSignalCounts,
      completedReactivationCounts: nextCompletedReactivationCounts,
      focusThreadId: focusThreadId,
      summary: 'Planner maintenance review prioritized',
      body: focusThreadId == null
          ? 'Prioritized planner rule review for $label so the highest-burn chronic drift stays at the front of maintenance follow-up.'
          : 'Prioritized planner rule review for $label so the highest-burn chronic drift stays at the front of maintenance follow-up and shifted focus to the affected thread.',
    );
  }

  void _clearPlannerMaintenanceReview({
    required String signalId,
    required String label,
  }) {
    final nextQueuedAt = Map<String, DateTime>.from(
      _plannerMaintenanceReviewQueuedAt,
    )..remove(signalId);
    final nextCompletedAt = Map<String, DateTime>.from(
      _plannerMaintenanceReviewCompletedAt,
    )..remove(signalId);
    final nextPrioritizedAt = Map<String, DateTime>.from(
      _plannerMaintenanceReviewPrioritizedAt,
    )..remove(signalId);
    final nextReopenedCounts = Map<String, int>.from(
      _plannerMaintenanceReviewReopenedCounts,
    )..remove(signalId);
    final nextCompletedSignalCounts = Map<String, int>.from(
      _plannerMaintenanceReviewCompletedSignalCounts,
    )..remove(signalId);
    final nextCompletedReactivationCounts = Map<String, int>.from(
      _plannerMaintenanceReviewCompletedReactivationCounts,
    )..remove(signalId);
    _setPlannerMaintenanceReviewState(
      queuedAt: nextQueuedAt,
      completedAt: nextCompletedAt,
      prioritizedAt: nextPrioritizedAt,
      reopenedCounts: nextReopenedCounts,
      completedSignalCounts: nextCompletedSignalCounts,
      completedReactivationCounts: nextCompletedReactivationCounts,
      summary: 'Planner maintenance review cleared',
      body:
          'Cleared the rule review mark for $label. ONYX will switch the chronic drift alert back to review now while the rule is still flapping.',
    );
  }

  void _completePlannerMaintenanceReview({
    required String signalId,
    required String label,
  }) {
    final now = DateTime.now();
    final nextQueuedAt = Map<String, DateTime>.from(
      _plannerMaintenanceReviewQueuedAt,
    );
    nextQueuedAt.putIfAbsent(signalId, () => now);
    final nextCompletedAt = Map<String, DateTime>.from(
      _plannerMaintenanceReviewCompletedAt,
    )..[signalId] = now;
    final nextPrioritizedAt = Map<String, DateTime>.from(
      _plannerMaintenanceReviewPrioritizedAt,
    )..remove(signalId);
    final nextReopenedCounts = Map<String, int>.from(
      _plannerMaintenanceReviewReopenedCounts,
    );
    final nextCompletedSignalCounts = Map<String, int>.from(
      _plannerMaintenanceReviewCompletedSignalCounts,
    )..[signalId] = _plannerSignalSnapshot.signalCounts[signalId] ?? 0;
    final nextCompletedReactivationCounts = Map<String, int>.from(
      _plannerMaintenanceReviewCompletedReactivationCounts,
    )..[signalId] = _plannerBacklogReactivationCounts[signalId] ?? 0;
    _setPlannerMaintenanceReviewState(
      queuedAt: nextQueuedAt,
      completedAt: nextCompletedAt,
      prioritizedAt: nextPrioritizedAt,
      reopenedCounts: nextReopenedCounts,
      completedSignalCounts: nextCompletedSignalCounts,
      completedReactivationCounts: nextCompletedReactivationCounts,
      summary: 'Planner maintenance review completed',
      body:
          'Marked the planner maintenance review for $label as completed. ONYX will keep tracking the chronic drift, but it will stop presenting this rule as an active maintenance alert until the signal changes again.',
    );
  }

  void _reopenPlannerMaintenanceReview({
    required String signalId,
    required String label,
  }) {
    final nextQueuedAt = Map<String, DateTime>.from(
      _plannerMaintenanceReviewQueuedAt,
    )..[signalId] = DateTime.now();
    final nextCompletedAt = Map<String, DateTime>.from(
      _plannerMaintenanceReviewCompletedAt,
    )..remove(signalId);
    final nextPrioritizedAt = Map<String, DateTime>.from(
      _plannerMaintenanceReviewPrioritizedAt,
    )..remove(signalId);
    final nextReopenedCounts = Map<String, int>.from(
      _plannerMaintenanceReviewReopenedCounts,
    );
    final nextCompletedSignalCounts = Map<String, int>.from(
      _plannerMaintenanceReviewCompletedSignalCounts,
    )..remove(signalId);
    final nextCompletedReactivationCounts = Map<String, int>.from(
      _plannerMaintenanceReviewCompletedReactivationCounts,
    )..remove(signalId);
    _setPlannerMaintenanceReviewState(
      queuedAt: nextQueuedAt,
      completedAt: nextCompletedAt,
      prioritizedAt: nextPrioritizedAt,
      reopenedCounts: nextReopenedCounts,
      completedSignalCounts: nextCompletedSignalCounts,
      completedReactivationCounts: nextCompletedReactivationCounts,
      summary: 'Planner maintenance review reopened',
      body:
          'Reopened planner rule review for $label. ONYX will treat the chronic drift as an active maintenance item again until review is completed.',
    );
  }

  void _setPlannerMaintenanceReviewState({
    required Map<String, DateTime> queuedAt,
    required Map<String, DateTime> completedAt,
    required Map<String, DateTime> prioritizedAt,
    required Map<String, int> reopenedCounts,
    required Map<String, int> completedSignalCounts,
    required Map<String, int> completedReactivationCounts,
    String? focusThreadId,
    required String summary,
    required String body,
  }) {
    final resolvedFocusThreadId =
        focusThreadId != null &&
            _threads.any((thread) => thread.id == focusThreadId)
        ? focusThreadId
        : null;
    if (resolvedFocusThreadId != null) {
      _selectThreadForPlannerHandoff(
        resolvedFocusThreadId,
        clearPlannerFocus: false,
      );
    }
    setState(() {
      _plannerMaintenanceReviewQueuedAt = queuedAt;
      _plannerMaintenanceReviewCompletedAt = completedAt;
      _plannerMaintenanceReviewPrioritizedAt = prioritizedAt;
      _plannerMaintenanceReviewReopenedCounts = reopenedCounts;
      _plannerMaintenanceReviewCompletedSignalCounts = completedSignalCounts;
      _plannerMaintenanceReviewCompletedReactivationCounts =
          completedReactivationCounts;
    });
    _emitThreadSessionState();
    _appendToolMessage(
      headline: 'Planner maintenance review',
      summary: summary,
      body: body,
    );
  }

  void _selectThreadForPlannerHandoff(
    String threadId, {
    bool clearPlannerFocus = false,
  }) {
    _selectThread(
      threadId,
      surfaceStaleFollowUp: false,
      clearPlannerFocus: clearPlannerFocus,
      explicitOperatorSelection: false,
    );
  }

  List<Widget> _plannerBacklogMaintenanceButtons(
    _PlannerConflictReport report,
  ) {
    final reviewedEntries = report.backlogEntries
        .where((entry) => entry.reviewStatus != null)
        .toList(growable: false);
    if (reviewedEntries.isEmpty) {
      return const <Widget>[];
    }
    return <Widget>[
      _plannerBacklogMaintenanceButton(
        key: const ValueKey('onyx-agent-planner-backlog-clear-reviewed'),
        label: 'Clear reviewed',
        onPressed: () {
          _clearReviewedPlannerBacklogItems(report);
        },
      ),
      _plannerBacklogMaintenanceButton(
        key: const ValueKey('onyx-agent-planner-backlog-archive-reviewed'),
        label: 'Archive reviewed',
        onPressed: () {
          _archiveReviewedPlannerBacklogItems(report);
        },
      ),
    ];
  }

  Widget _plannerBacklogMaintenanceButton({
    required Key key,
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      key: key,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF9D4BFF),
        backgroundColor: const Color(0xFF1A1A2E),
        side: const BorderSide(color: Color(0x269D4BFF)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _plannerReportFocusSection({
    required String sectionId,
    required Widget child,
  }) {
    final focused = _focusedPlannerSectionId == sectionId;
    final sectionKey = _plannerReportSectionAnchorKey(sectionId);
    return AnimatedContainer(
      key: sectionKey,
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: focused ? const Color(0xFFEFF6FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: focused ? const Color(0xFF93C5FD) : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (focused) ...[
            _miniStatusTag(
              key: ValueKey('onyx-agent-planner-section-focus-$sectionId'),
              label: 'SUMMARY SHORTCUT',
              foreground: const Color(0xFF1D4ED8),
              border: const Color(0xFF93C5FD),
            ),
            const SizedBox(height: 6),
            Text(
              _focusedPlannerSignalContextLabel ?? 'Focused in planner report.',
              style: GoogleFonts.inter(
                color: const Color(0xFF9D4BFF),
                fontSize: 11.2,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 8),
          ],
          child,
        ],
      ),
    );
  }

  Widget _plannerShortcutTextButton({
    required Key key,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        key: key,
        onPressed: onPressed,
        style: TextButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: OnyxColorTokens.textSecondary,
        ),
        child: Text(
          label,
          textAlign: TextAlign.left,
          style: GoogleFonts.inter(
            color: OnyxColorTokens.textSecondary,
            fontSize: 11.4,
            fontWeight: FontWeight.w600,
            height: 1.45,
          ),
        ),
      ),
    );
  }

  List<Widget> _plannerBacklogReviewButtons(_PlannerBacklogEntry entry) {
    return _PlannerBacklogReviewStatus.values
        .map((status) {
          final isActive = entry.reviewStatus == status;
          return OutlinedButton(
            key: ValueKey(
              'onyx-agent-planner-backlog-${status.name}-${_plannerSignalKey(entry.signalId)}',
            ),
            onPressed: () {
              _togglePlannerBacklogReviewStatus(entry.signalId, status);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: isActive
                  ? const Color(0xFF2D6CDF)
                  : OnyxColorTokens.textSecondary,
              backgroundColor: isActive
                  ? const Color(0xFFEAF2FC)
                  : const Color(0xFF1A1A2E),
              side: BorderSide(
                color: isActive
                    ? const Color(0xFF9CB9DA)
                    : const Color(0xFFD4DFEA),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              switch (status) {
                _PlannerBacklogReviewStatus.acknowledged => 'Acknowledge',
                _PlannerBacklogReviewStatus.muted => 'Mute',
                _PlannerBacklogReviewStatus.fixed => 'Fixed',
              },
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          );
        })
        .toList(growable: false);
  }

  String _plannerSignalKey(String signalId) {
    return signalId.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '-');
  }

  GlobalKey _plannerMaintenanceAlertAnchorKey(String signalId) {
    return _plannerMaintenanceAlertKeys.putIfAbsent(signalId, GlobalKey.new);
  }

  GlobalKey _plannerReportSectionAnchorKey(String sectionId) {
    return _plannerReportSectionKeys.putIfAbsent(sectionId, GlobalKey.new);
  }

  GlobalKey _plannerBacklogEntryAnchorKey(String signalId) {
    return _plannerBacklogEntryKeys.putIfAbsent(signalId, GlobalKey.new);
  }

  GlobalKey _plannerArchivedEntryAnchorKey(String signalId) {
    return _plannerArchivedEntryKeys.putIfAbsent(signalId, GlobalKey.new);
  }

  GlobalKey _plannerReactivationEntryAnchorKey(String signalId) {
    return _plannerReactivationEntryKeys.putIfAbsent(signalId, GlobalKey.new);
  }

  void _togglePlannerBacklogReviewStatus(
    String signalId,
    _PlannerBacklogReviewStatus status,
  ) {
    final currentStatus = _plannerBacklogReviewStatuses[signalId];
    final nextStatuses = Map<String, _PlannerBacklogReviewStatus>.from(
      _plannerBacklogReviewStatuses,
    );
    String summary;
    String body;
    if (currentStatus == status) {
      nextStatuses.remove(signalId);
      summary = 'Planner review status cleared';
      body =
          'Cleared ${status.name} on the planner backlog item so ONYX can surface live tuning cues for this rule again.';
    } else {
      nextStatuses[signalId] = status;
      summary = 'Planner review status updated';
      body =
          'Marked this planner backlog item as ${status.name}. ONYX will keep the backlog visible, but it will stop pushing repeated self-tuning nudges for this rule until you clear the review status.';
    }
    setState(() {
      _plannerBacklogReviewStatuses = nextStatuses;
    });
    _emitThreadSessionState();
    _appendToolMessage(
      headline: 'Planner backlog review',
      summary: summary,
      body: body,
    );
  }

  void _clearReviewedPlannerBacklogItems(_PlannerConflictReport report) {
    final reviewedEntries = report.backlogEntries
        .where((entry) => entry.reviewStatus != null)
        .toList(growable: false);
    if (reviewedEntries.isEmpty) {
      return;
    }
    final nextStatuses = Map<String, _PlannerBacklogReviewStatus>.from(
      _plannerBacklogReviewStatuses,
    );
    for (final entry in reviewedEntries) {
      nextStatuses.remove(entry.signalId);
    }
    setState(() {
      _plannerBacklogReviewStatuses = nextStatuses;
    });
    _emitThreadSessionState();
    final count = reviewedEntries.length;
    _appendToolMessage(
      headline: 'Planner backlog maintenance',
      summary: count == 1
          ? 'Cleared 1 reviewed planner item'
          : 'Cleared $count reviewed planner items',
      body: count == 1
          ? 'Cleared the review tag on this planner backlog item so ONYX can surface live tuning cues for it again.'
          : 'Cleared the review tags on $count planner backlog items so ONYX can surface live tuning cues for those rules again.',
    );
  }

  void _archiveReviewedPlannerBacklogItems(_PlannerConflictReport report) {
    final reviewedEntries = report.backlogEntries
        .where((entry) => entry.reviewStatus != null)
        .toList(growable: false);
    if (reviewedEntries.isEmpty) {
      return;
    }
    final nextStatuses = Map<String, _PlannerBacklogReviewStatus>.from(
      _plannerBacklogReviewStatuses,
    );
    final nextScores = Map<String, int>.from(_plannerBacklogScores);
    final nextArchivedSignalCounts = Map<String, int>.from(
      _plannerBacklogArchivedSignalCounts,
    );
    final nextReactivatedSignalCounts = Map<String, int>.from(
      _plannerBacklogReactivatedSignalCounts,
    );
    final nextLastReactivatedAt = Map<String, DateTime>.from(
      _plannerBacklogLastReactivatedAt,
    );
    for (final entry in reviewedEntries) {
      nextStatuses.remove(entry.signalId);
      nextScores.remove(entry.signalId);
      nextArchivedSignalCounts[entry.signalId] =
          report.currentSignalCounts[entry.signalId] ?? 0;
      nextReactivatedSignalCounts.remove(entry.signalId);
      nextLastReactivatedAt.remove(entry.signalId);
    }
    setState(() {
      _plannerBacklogReviewStatuses = nextStatuses;
      _plannerBacklogScores = nextScores;
      _plannerBacklogArchivedSignalCounts = nextArchivedSignalCounts;
      _plannerBacklogReactivatedSignalCounts = nextReactivatedSignalCounts;
      _plannerBacklogLastReactivatedAt = nextLastReactivatedAt;
    });
    _emitThreadSessionState();
    final count = reviewedEntries.length;
    _appendToolMessage(
      headline: 'Planner backlog maintenance',
      summary: count == 1
          ? 'Archived 1 reviewed planner item'
          : 'Archived $count reviewed planner items',
      body: count == 1
          ? 'Archived this reviewed planner backlog item. ONYX will keep it out of the active backlog until the same drift gets worse again.'
          : 'Archived $count reviewed planner backlog items. ONYX will keep them out of the active backlog until those same drifts get worse again.',
    );
  }

  Widget _sideCard({
    Key? cardKey,
    required String title,
    required Widget child,
  }) {
    return Container(
      key: cardKey,
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OnyxColorTokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textPrimary,
              fontSize: 12.2,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _scopeActionPill({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color foreground,
    required Color background,
    required Color border,
  }) {
    return InkWell(
      key: key,
      onTap: onPressed,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: foreground),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: foreground,
                fontSize: 11.2,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildResumeRouteAction() {
    final sourceLabel = widget.sourceRouteLabel.trim().toLowerCase();
    if (widget.focusIncidentReference.trim().isEmpty) {
      return null;
    }
    if ((sourceLabel == 'dispatches' || sourceLabel == 'alarms') &&
        (widget.onOpenAlarmsForIncident != null ||
            widget.onOpenAlarms != null)) {
      return _scopeActionPill(
        key: const ValueKey('onyx-agent-resume-alarms-button'),
        icon: Icons.warning_amber_rounded,
        label: 'RESUME DISPATCH BOARD',
        onPressed: () {
          _openAlarmsRoute();
        },
        foreground: const Color(0xFFFECACA),
        background: const Color(0xFFFEF2F2),
        border: const Color(0xFF7F1D1D),
      );
    }
    if ((sourceLabel == 'track' || sourceLabel == 'tactical') &&
        (widget.onOpenTrackForIncident != null || widget.onOpenTrack != null)) {
      return _scopeActionPill(
        key: const ValueKey('onyx-agent-resume-track-button'),
        icon: Icons.route_rounded,
        label: 'RESUME TACTICAL TRACK',
        onPressed: () {
          _openTrackRoute();
        },
        foreground: const Color(0xFFBBF7D0),
        background: const Color(0xFFF0FDF4),
        border: const Color(0xFF1B5E20),
      );
    }
    if ((sourceLabel == 'clients' || sourceLabel == 'comms') &&
        ((widget.scopeClientId.trim().isNotEmpty &&
                widget.onOpenCommsForScope != null) ||
            widget.onOpenComms != null)) {
      return _scopeActionPill(
        key: const ValueKey('onyx-agent-resume-comms-button'),
        icon: Icons.forum_rounded,
        label: 'RESUME CLIENT COMMS',
        onPressed: () {
          _openCommsRoute();
        },
        foreground: const Color(0xFFBFDBFE),
        background: const Color(0xFFEFF6FF),
        border: const Color(0xFF28476B),
      );
    }
    if (sourceLabel == 'operations' &&
        widget.onOpenOperationsForIncident != null) {
      return _scopeActionPill(
        key: const ValueKey('onyx-agent-resume-operations-button'),
        icon: Icons.reply_all_rounded,
        label: 'Resume Board',
        onPressed: _openOperationsRoute,
        foreground: const Color(0xFFFDE68A),
        background: const Color(0xFFFFF8E7),
        border: const Color(0xFF6B4F18),
      );
    }
    if ((sourceLabel == 'cctv' ||
            sourceLabel == 'ai queue' ||
            sourceLabel == 'aiqueue' ||
            sourceLabel == 'ai-queue') &&
        widget.onOpenCctvForIncident != null) {
      return _scopeActionPill(
        key: const ValueKey('onyx-agent-resume-ai-queue-button'),
        icon: Icons.videocam_rounded,
        label: 'RESUME AI QUEUE',
        onPressed: () {
          _openCctvRoute();
        },
        foreground: const Color(0xFFBFDBFE),
        background: const Color(0xFFEFF6FF),
        border: const Color(0xFF28476B),
      );
    }
    return null;
  }

  Widget _miniStatusTag({
    Key? key,
    required String label,
    required Color foreground,
    required Color border,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: foreground,
          fontSize: 9.8,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Future<void> _validateCameraBridge() async {
    await runOnyxCameraBridgeValidationAction(
      currentState: _cameraBridgeLocalState,
      status: widget.cameraBridgeStatus,
      service: widget.cameraBridgeHealthService,
      operatorId: widget.operatorId,
      onLocalStateChanged: (state) {
        setState(() {
          _cameraBridgeLocalState = state;
        });
      },
      isMounted: () => mounted,
      onSnapshotChanged: (snapshot) {
        widget.onCameraBridgeHealthSnapshotChanged?.call(snapshot);
      },
      onMessage: _showBridgeSnackBar,
    );
  }

  Future<void> _copyCameraBridgeSetup() async {
    await runOnyxCameraBridgeCopyAction(
      status: widget.cameraBridgeStatus,
      presentation: _cameraBridgePresentation,
      isMounted: () => mounted,
      onMessage: _showBridgeSnackBar,
    );
  }

  Future<void> _clearCameraBridgeHealthSnapshot() async {
    await runOnyxCameraBridgeClearAction(
      currentState: _cameraBridgeLocalState,
      snapshot: _cameraBridgeLocalState.snapshot,
      onClearReceipt: widget.onClearCameraBridgeHealthSnapshot,
      onLocalStateChanged: (state) {
        setState(() {
          _cameraBridgeLocalState = state;
        });
      },
      isMounted: () => mounted,
      onMessage: _showBridgeSnackBar,
    );
  }

  void _showBridgeSnackBar(String message) {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: OnyxColorTokens.backgroundSecondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFD6E1EC)),
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(
            color: OnyxColorTokens.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _guardrailLine(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(
              Icons.shield_outlined,
              size: 14,
              color: Color(0xFF67E8F9),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(0xFFD7E2F0),
                fontSize: 11.7,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _hasActiveSelectedThread => _threadById(_selectedThreadId) != null;

  _AgentThread get _selectedThread =>
      _threadById(_selectedThreadId) ??
      (_threads.isNotEmpty ? _threads.first : _standbyThread());

  bool _isStandbyThread(_AgentThread thread) => thread.id == '__standby__';

  _AgentThread _standbyThread() {
    return _AgentThread(
      id: '__standby__',
      title: 'Standby',
      summary: 'Zara is standing by for the next task.',
      messages: const <_AgentMessage>[],
    );
  }

  _AgentPersona _personaFor(String personaId) {
    return _personas.firstWhere(
      (persona) => persona.id == personaId,
      orElse: () => _personas.first,
    );
  }

  List<_AgentThread> _seedThreads() {
    final scope = _scopeLabel();
    final incident = widget.focusIncidentReference.trim();

    return <_AgentThread>[
      _AgentThread(
        id: 'thread-1',
        title: 'Agent Workspace',
        summary: 'Main brain online for $scope.',
        messages: [
          _agentMessage(
            personaId: 'main',
            headline: 'Local-first agent mesh is ready',
            body:
                'Ask any controller question about CCTV Review, Tactical Track, patrol proof, Client Comms, incident triage, escalation, or Reports Workspace. The main brain will keep everything local by default and only summon OpenAI when you explicitly allow it.',
            actions: [
              _action(
                id: 'thread-1-probe-camera',
                kind: _AgentActionKind.seedPrompt,
                label: 'Probe Camera',
                detail:
                    'Start a dry LAN probe for a camera IP and stage the next install steps.',
                payload: 'Probe camera 192.168.1.64 and validate RTSP / ONVIF',
                personaId: 'camera',
              ),
              _action(
                id: 'thread-1-reconnect-cameras',
                kind: _AgentActionKind.seedPrompt,
                label: 'Reconnect Cameras',
                detail:
                    'Stage a scoped camera recovery plan when feeds have gone down.',
                payload:
                    'Reconnect the scoped cameras. Wi-Fi dropped and I need the bring-up plan.',
                personaId: 'camera',
              ),
              _action(
                id: 'thread-1-draft-client',
                kind: _AgentActionKind.seedPrompt,
                label: 'Draft Client Reply',
                detail: 'Write a scoped update and hand it into Client Comms.',
                payload: 'Draft a client update for the current incident',
                personaId: 'client',
              ),
              _action(
                id: 'thread-1-one-next-move',
                kind: _AgentActionKind.seedPrompt,
                label: 'One Next Move',
                detail:
                    'Triage the active incident and stage one obvious desk handoff.',
                payload:
                    'Triage the active incident and stage one obvious next move',
                personaId: 'dispatch',
              ),
              _action(
                id: 'thread-1-correlate-signals',
                kind: _AgentActionKind.seedPrompt,
                label: 'Correlate Signals',
                detail:
                    'Fuse CCTV Review, Dispatch Board, Tactical Track, and Sovereign Ledger context before the next War Room handoff.',
                payload:
                    'Correlate CCTV Review, Tactical Track, and Dispatch Board signals for the active incident',
                personaId: 'intel',
              ),
              if (incident.isNotEmpty)
                _action(
                  id: 'thread-1-summarize-incident',
                  kind: _AgentActionKind.summarizeIncident,
                  label: 'Summarize Incident',
                  detail:
                      'Build a quick situation summary before you hand off.',
                  payload: incident,
                  personaId: 'dispatch',
                ),
            ],
          ),
        ],
      ),
      _AgentThread(
        id: 'thread-2',
        title: 'Signal Picture',
        summary:
            'Fuse CCTV Review, Tactical Track posture, Dispatch Board state, and Sovereign Ledger context into one operator view.',
        messages: [
          _agentMessage(
            personaId: 'intel',
            headline: 'War Room signal picture is ready',
            body:
                'Feed me the active Dispatch Board alert, CCTV Review note, Tactical Track clue, or patrol concern and I will merge the War Room picture before you hand off.',
          ),
        ],
      ),
      _AgentThread(
        id: 'thread-3',
        title: 'Client Comms',
        summary: 'Reply drafts, reports, and Client Comms handoffs for $scope.',
        messages: [
          _agentMessage(
            personaId: 'client',
            headline: 'Client Comms Agent is scoped and ready',
            body:
                'I can draft clean client language, explain the current incident in plain terms, and route you into live Client Comms when you want to send it.',
          ),
        ],
      ),
    ];
  }

  void _createThread() {
    _threadCounter += 1;
    final id = 'thread-$_threadCounter';
    final thread = _AgentThread(
      id: id,
      title: 'Analyst Chat $_threadCounter',
      summary: 'Fresh analyst thread waiting for the next question.',
      messages: [
        _agentMessage(
          personaId: 'main',
          headline: 'War room ready',
          body:
              'Start with a device target, a client request, or an incident question and I will route it through the right specialist.',
        ),
      ],
    );
    final selectedAt = DateTime.now();
    setState(() {
      _threads = [thread, ..._threads];
      _selectedThreadId = id;
      _selectedThreadOperatorId = id;
      _selectedThreadOperatorAt = selectedAt;
      _restoredPressureFocusThreadId = null;
      _restoredPressureFocusFallbackThreadTitle = null;
      _restoredPressureFocusLabel = null;
      _focusedPlannerSignalId = null;
      _focusedPlannerSectionId = null;
      _focusedPlannerBacklogSignalId = null;
      _focusedPlannerArchivedSignalId = null;
      _focusedPlannerReactivationSignalId = null;
      _focusedPlannerSignalContextLabel = null;
      _synchronizePlannerSignalSnapshots(threads: _threads);
    });
    _emitThreadSessionState();
    _scheduleStaleFollowUpSurface(threadId: id, allowImmediate: false);
    _scheduleScrollToBottom();
  }

  void _selectThread(
    String threadId, {
    bool surfaceStaleFollowUp = true,
    bool explicitOperatorSelection = true,
    bool clearPlannerFocus = true,
  }) {
    if (!_threads.any((thread) => thread.id == threadId)) {
      return;
    }
    final selectedThreadChanged = _selectedThreadId != threadId;
    final shouldClearRestoredPressureFocus =
        explicitOperatorSelection &&
        (_restoredPressureFocusThreadId != null ||
            _restoredPressureFocusFallbackThreadTitle != null ||
            _restoredPressureFocusLabel != null);
    final shouldClearOperatorSelection =
        !explicitOperatorSelection &&
        selectedThreadChanged &&
        (_selectedThreadOperatorId?.trim().isNotEmpty == true ||
            _selectedThreadOperatorAt != null);
    if (explicitOperatorSelection) {
      _markOperatorSelectedThread(threadId);
    }
    if (selectedThreadChanged ||
        shouldClearOperatorSelection ||
        shouldClearRestoredPressureFocus ||
        (clearPlannerFocus &&
            (_focusedPlannerSignalId != null ||
                _focusedPlannerSectionId != null ||
                _focusedPlannerBacklogSignalId != null ||
                _focusedPlannerArchivedSignalId != null ||
                _focusedPlannerReactivationSignalId != null))) {
      setState(() {
        _selectedThreadId = threadId;
        if (shouldClearOperatorSelection) {
          _selectedThreadOperatorId = null;
          _selectedThreadOperatorAt = null;
        }
        if (shouldClearRestoredPressureFocus || selectedThreadChanged) {
          _restoredPressureFocusThreadId = null;
          _restoredPressureFocusFallbackThreadTitle = null;
          _restoredPressureFocusLabel = null;
        }
        if (clearPlannerFocus) {
          _focusedPlannerSignalId = null;
          _focusedPlannerSectionId = null;
          _focusedPlannerBacklogSignalId = null;
          _focusedPlannerArchivedSignalId = null;
          _focusedPlannerReactivationSignalId = null;
          _focusedPlannerSignalContextLabel = null;
        }
      });
    }
    _emitThreadSessionState();
    if (surfaceStaleFollowUp && selectedThreadChanged) {
      _queueStaleFollowUpSurface(threadId: threadId);
    } else if (selectedThreadChanged) {
      _scheduleStaleFollowUpSurface(threadId: threadId, allowImmediate: false);
    }
  }

  void _clearRestoredPressureFocusCue({bool rebuild = true}) {
    if (_restoredPressureFocusThreadId == null &&
        _restoredPressureFocusFallbackThreadTitle == null &&
        _restoredPressureFocusLabel == null) {
      return;
    }
    void apply() {
      _restoredPressureFocusThreadId = null;
      _restoredPressureFocusFallbackThreadTitle = null;
      _restoredPressureFocusLabel = null;
    }

    if (rebuild) {
      setState(apply);
    } else {
      apply();
    }
  }

  void _clearPlannerFocusCue({bool rebuild = true}) {
    if (_focusedPlannerSignalId == null &&
        _focusedPlannerSectionId == null &&
        _focusedPlannerBacklogSignalId == null &&
        _focusedPlannerArchivedSignalId == null &&
        _focusedPlannerReactivationSignalId == null &&
        _focusedPlannerSignalContextLabel == null) {
      return;
    }

    void apply() {
      _focusedPlannerSignalId = null;
      _focusedPlannerSectionId = null;
      _focusedPlannerBacklogSignalId = null;
      _focusedPlannerArchivedSignalId = null;
      _focusedPlannerReactivationSignalId = null;
      _focusedPlannerSignalContextLabel = null;
    }

    if (rebuild) {
      setState(apply);
    } else {
      apply();
    }
  }

  Future<void> _submitPrompt([String? seededPrompt]) async {
    final prompt = (seededPrompt ?? _composerController.text).trim();
    if (prompt.isEmpty) {
      return;
    }
    _clearRestoredPressureFocusCue();
    _clearPlannerFocusCue();
    if (_reasoningInFlight) {
      return;
    }
    if (seededPrompt == null) {
      _composerController.clear();
    }
    final threadId = _selectedThreadId;
    _markOperatorSelectedThread(threadId);
    final threadMemory = _selectedThread.memory;
    final contextSnapshot = _contextSnapshot();
    final plannerConflictReport = _plannerConflictReport();
    final reasoningContext = [
      contextSnapshot.toReasoningSummary(),
      _activePrimaryPressureReasoningSummary(
        threadMemory,
        plannerConflictReport,
      ),
      _threadMemoryReasoningSummary(threadMemory),
      _plannerMaintenancePriorityReasoningSummary(plannerConflictReport),
      _plannerConflictReasoningSummary(plannerConflictReport),
      _selectedOperatorFocusReasoningSummary(plannerConflictReport),
    ].where((part) => part.trim().isNotEmpty).join(' ');
    if (_repeatPromptCount(_selectedThread, prompt) >= 2 &&
        threadMemory.hasData) {
      _updateThreadById(threadId, (thread) {
        final compressedResponse = _compressedRepeatResponse(thread.memory);
        return thread.copyWith(
          summary: compressedResponse.summary,
          memory: thread.memory.copyWith(updatedAt: DateTime.now()),
          messages: [
            ...thread.messages,
            _userMessage(body: prompt),
            _agentMessage(
              personaId: 'main',
              headline: compressedResponse.headline,
              body: compressedResponse.body,
            ),
          ],
        );
      });
      return;
    }
    final structuredWorkItem = _structuredWorkItemForPrompt(
      prompt,
      contextSnapshot,
      reasoningContext,
      threadMemory,
    );
    final structuredDecision = structuredWorkItem == null
        ? null
        : _brainDecisionForWorkItem(
            structuredWorkItem,
            plannerDisagreementTelemetry:
                _plannerDisagreementTelemetryForThreadMemory(
                  threadMemory,
                  plannerConflictReport,
                ),
          );
    final structuredRecommendation = structuredDecision?.toRecommendation();
    final brainScope = _brainScopeForThreadMemory(
      threadMemory,
      plannerConflictReport: plannerConflictReport,
    );
    final brainIntent = _cloudIntentForPrompt(prompt);
    final preferredBrainProvider = _resolvePreferredBrainProvider(
      prompt: prompt,
      scope: brainScope,
      intent: brainIntent,
    );
    final nextStructuredThreadTitle = _selectedThread.messages.length <= 1
        ? _threadTitleFromPrompt(prompt)
        : _selectedThread.title;
    final structuredMemory = structuredRecommendation == null
        ? null
        : _rememberRecommendation(
            threadMemory,
            structuredRecommendation,
            decision: structuredDecision,
            operatorFocusNote: _selectedOperatorFocusMemoryNote(
              plannerConflictReport,
              selectedThreadTitle: nextStructuredThreadTitle,
            ),
            plannerConflictReport: plannerConflictReport,
          );
    final responses = structuredRecommendation == null
        ? _responsesForPrompt(
            prompt,
            preferredBrainProvider: preferredBrainProvider,
          )
        : _responsesForStructuredRecommendation(
            structuredRecommendation,
            decision: structuredDecision,
            threadMemory: threadMemory,
            plannerConflictReport: plannerConflictReport,
          );
    _updateThreadById(threadId, (thread) {
      return thread.copyWith(
        title: nextStructuredThreadTitle,
        summary:
            structuredRecommendation?.summary ??
            _threadSummaryFromPrompt(prompt),
        memory: structuredMemory ?? thread.memory,
        messages: [
          ...thread.messages,
          _userMessage(body: prompt),
          ...responses,
        ],
      );
    });
    if (structuredRecommendation != null) {
      if (preferredBrainProvider == _AgentBrainProvider.cloud &&
          structuredMemory != null &&
          structuredWorkItem != null &&
          structuredDecision != null) {
        await _runStructuredCloudSecondLook(
          prompt: prompt,
          threadId: threadId,
          workItem: structuredWorkItem,
          typedDecision: structuredDecision,
          typedMemory: structuredMemory,
          reasoningContext: reasoningContext,
        );
      }
      return;
    }
    if (preferredBrainProvider == _AgentBrainProvider.local) {
      OnyxAgentCloudBoostResponse? localResponse;
      try {
        localResponse = await _runLocalBrainSynthesis(
          prompt: prompt,
          scope: brainScope,
          intent: brainIntent,
          contextSummary: reasoningContext,
        );
      } catch (_) {
        if (!mounted) {
          return;
        }
        _appendToolMessage(
          headline: 'Local brain unavailable',
          body:
              'The local model pass could not complete, so the thread stayed on the deterministic operator path without adding a model advisory.',
          summary: 'Local model pass failed',
        );
        return;
      }
      if (!mounted) {
        return;
      }
      if (localResponse == null) {
        if (_shouldFallbackLocalBrainToCloud(brainIntent)) {
          await _runCloudBoostForThread(
            threadId: threadId,
            prompt: prompt,
            scope: brainScope,
            intent: brainIntent,
            contextSummary: reasoningContext,
            plannerConflictReport: plannerConflictReport,
          );
        }
        return;
      }
      if (localResponse.isError) {
        if (_shouldFallbackLocalBrainToCloud(brainIntent)) {
          await _runCloudBoostForThread(
            threadId: threadId,
            prompt: prompt,
            scope: brainScope,
            intent: brainIntent,
            contextSummary: reasoningContext,
            plannerConflictReport: plannerConflictReport,
          );
          return;
        }
        _appendToolMessage(
          headline: 'Local brain unavailable',
          body: _brainErrorMessageBody(
            fallbackBody:
                'The local model pass could not complete, so the thread stayed on the deterministic operator path without adding a model advisory.',
            response: localResponse,
          ),
          summary: _brainErrorMessageSummary(
            fallbackSummary: 'Local model pass failed',
            response: localResponse,
          ),
        );
        return;
      }
      final resolvedLocalResponse = localResponse;
      _updateThreadById(threadId, (thread) {
        return thread.copyWith(
          messages: [
            ...thread.messages,
            ..._messagesForBrainResponse(
              response: resolvedLocalResponse,
              headline: 'Local Model Brain',
              plannerConflictReport: plannerConflictReport,
            ),
          ],
          memory: _rememberBrainAdvisory(thread.memory, resolvedLocalResponse),
        );
      });
      return;
    }
    if (preferredBrainProvider != _AgentBrainProvider.cloud) {
      return;
    }
    await _runCloudBoostForThread(
      threadId: threadId,
      prompt: prompt,
      scope: brainScope,
      intent: brainIntent,
      contextSummary: reasoningContext,
      plannerConflictReport: plannerConflictReport,
    );
  }

  Future<void> _runCloudBoostForThread({
    required String threadId,
    required String prompt,
    required OnyxAgentCloudScope scope,
    required OnyxAgentCloudIntent intent,
    required String contextSummary,
    required _PlannerConflictReport plannerConflictReport,
  }) async {
    OnyxAgentCloudBoostResponse? cloudResponse;
    try {
      cloudResponse = await _runCloudBoost(
        prompt: prompt,
        scope: scope,
        intent: intent,
        contextSummary: contextSummary,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _appendToolMessage(
        headline: 'OpenAI boost unavailable',
        body:
            'The OpenAI brain boost could not complete, so the thread stayed on the local operator response without adding a cloud advisory.',
        summary: 'OpenAI boost failed',
      );
      return;
    }
    if (!mounted) {
      return;
    }
    if (cloudResponse == null) {
      return;
    }
    if (cloudResponse.isError) {
      _appendToolMessage(
        headline: 'OpenAI boost unavailable',
        body: _brainErrorMessageBody(
          fallbackBody:
              'The OpenAI brain boost could not complete, so the thread stayed on the local operator response without adding a cloud advisory.',
          response: cloudResponse,
        ),
        summary: _brainErrorMessageSummary(
          fallbackSummary: 'OpenAI boost failed',
          response: cloudResponse,
        ),
      );
      return;
    }
    final resolvedCloudResponse = cloudResponse;
    _updateThreadById(threadId, (thread) {
      return thread.copyWith(
        messages: [
          ...thread.messages,
          ..._messagesForBrainResponse(
            response: resolvedCloudResponse,
            headline: 'OpenAI Brain Boost',
            plannerConflictReport: plannerConflictReport,
          ),
        ],
        memory: _rememberBrainAdvisory(thread.memory, resolvedCloudResponse),
      );
    });
  }

  Future<OnyxAgentCloudBoostResponse?> _runLocalBrainSynthesis({
    required String prompt,
    required OnyxAgentCloudScope scope,
    required OnyxAgentCloudIntent intent,
    required String contextSummary,
  }) async {
    setState(() {
      _localBrainInFlight = true;
    });
    try {
      return await widget.localBrainService!.synthesize(
        prompt: prompt,
        scope: scope,
        intent: intent,
        contextSummary: contextSummary,
      );
    } finally {
      if (mounted) {
        setState(() {
          _localBrainInFlight = false;
        });
      }
    }
  }

  Future<OnyxAgentCloudBoostResponse?> _runCloudBoost({
    required String prompt,
    required OnyxAgentCloudScope scope,
    required OnyxAgentCloudIntent intent,
    required String contextSummary,
  }) async {
    setState(() {
      _cloudBoostInFlight = true;
    });
    try {
      return await widget.cloudBoostService!.boost(
        prompt: prompt,
        scope: scope,
        intent: intent,
        contextSummary: contextSummary,
      );
    } finally {
      if (mounted) {
        setState(() {
          _cloudBoostInFlight = false;
        });
      }
    }
  }

  List<_AgentMessage> _responsesForPrompt(
    String prompt, {
    required _AgentBrainProvider preferredBrainProvider,
  }) {
    final normalized = prompt.toLowerCase();
    final ips = _extractIpv4Targets(prompt);
    final scope = _scopeLabel();
    final recoveryScope = _cameraRecoveryScopeLabel();
    final incident = widget.focusIncidentReference.trim();
    final cameraRecovery = _looksLikeCameraRecoveryPrompt(normalized);
    final cloudLine = _brainRoutingNarrativeForPrompt(
      preferredBrainProvider: preferredBrainProvider,
    );

    if (_looksLikeCameraPrompt(normalized, ips)) {
      final bridgeStatusLine = widget.cameraBridgeStatus.isLive
          ? 'The local camera bridge is live, so I can stage and approve a reconnect packet inside ONYX once the target is confirmed.'
          : 'The local camera bridge is not live yet, so I can stage the reconnect packet and clean recovery checklist now, then execute only after the bridge is healthy again.';
      return <_AgentMessage>[
        _agentMessage(
          personaId: 'main',
          headline: cameraRecovery
              ? 'Main Brain staged a scoped camera recovery'
              : 'Main Brain routed this to CCTV Review Agent',
          body: cameraRecovery
              ? '$cloudLine I will keep this reconnect local, approval-gated, and tied to the camera bridge before anything touches the scoped feeds.'
              : '$cloudLine I will stage a LAN probe before anything touches device configuration.',
        ),
        _agentMessage(
          personaId: 'camera',
          headline: cameraRecovery
              ? 'Scoped camera recovery plan for $recoveryScope'
              : ips.isEmpty
              ? 'Camera bring-up needs a target'
              : 'Camera bring-up plan',
          body: cameraRecovery
              ? ips.isEmpty
                    ? 'I did not find explicit camera IPs in your message, so I will treat this as a scoped recovery for $recoveryScope. $bridgeStatusLine ${normalized.contains('wifi') || normalized.contains('wi-fi') ? 'Because you mentioned Wi-Fi, I will bias the first pass toward reachability, recorder path, and stream re-registration before changing profile settings.' : 'I will start with reachability, recorder path, and stream validation before changing any profile settings.'}'
                    : 'I found ${ips.length == 1 ? 'camera target' : 'camera targets'} ${ips.join(', ')} for $recoveryScope. $bridgeStatusLine ${normalized.contains('wifi') || normalized.contains('wi-fi') ? 'Because you mentioned Wi-Fi, I will stage reachability, recorder path, and stream re-registration before any profile change.' : 'I will stage reachability, recorder path, and stream validation before any profile change.'}'
              : ips.isEmpty
              ? 'I did not find a camera IP yet. Add the device IP, NVR IP, or target subnet and I will stage reachability, RTSP, ONVIF, and a clean wiring checklist for $scope.'
              : 'I found ${ips.length == 1 ? 'camera target' : 'camera targets'} ${ips.join(', ')}. I can dry-probe reachability, stage RTSP / ONVIF checks, and prepare the next install steps for $scope.',
          actions: [
            for (final ip in ips.take(3))
              _action(
                id: 'probe-$ip',
                kind: _AgentActionKind.dryProbeCamera,
                label: 'Dry Probe $ip',
                detail:
                    'Ping plus ports 80 / 554 / 8899, then stage RTSP and ONVIF validation.',
                payload: ip,
                personaId: 'camera',
              ),
            _action(
              id: 'stage-camera-change',
              kind: _AgentActionKind.stageCameraChange,
              label: cameraRecovery
                  ? 'Stage Reconnect Packet'
                  : 'Stage Config Change',
              detail: cameraRecovery
                  ? 'Prepare the scoped reconnect packet, recorder target, and rollback export before any write action.'
                  : 'Collect make, model, approved profile, and creds before any write action.',
              payload: ips.isNotEmpty ? ips.first : '',
              personaId: 'camera',
              requiresApproval: true,
            ),
            _action(
              id: 'open-cctv-route',
              kind: _AgentActionKind.openCctv,
              label: 'OPEN CCTV REVIEW',
              detail: cameraRecovery
                  ? 'Validate the scoped feeds in CCTV Review before and after the reconnect packet runs.'
                  : 'Validate the stream in CCTV Review instead of leaving the controller flow.',
              personaId: 'camera',
              opensRoute: true,
            ),
          ],
        ),
      ];
    }

    if (_looksLikeTelemetryPrompt(normalized)) {
      return <_AgentMessage>[
        _agentMessage(
          personaId: 'main',
          headline: 'Main Brain routed this to Tactical Track',
          body:
              '$cloudLine I am checking Tactical Track posture first, then I will use the escalation and War Room handoff agents if the signal looks real.',
        ),
        _agentMessage(
          personaId: 'telemetry',
          headline: 'Guard distress posture check',
          body: _telemetrySummary(scope: scope, incident: incident),
          actions: [
            _action(
              id: 'telemetry-open-track',
              kind: _AgentActionKind.openTrack,
              label: 'OPEN TACTICAL TRACK',
              detail: 'Verify movement, route continuity, and unit posture.',
              personaId: 'telemetry',
              opensRoute: true,
            ),
            _action(
              id: 'telemetry-open-alarms',
              kind: _AgentActionKind.openAlarms,
              label: 'OPEN DISPATCH BOARD',
              detail:
                  'Cross-check distress timing against alarm and dispatch state.',
              personaId: 'dispatch',
              opensRoute: true,
            ),
            _action(
              id: 'telemetry-summary',
              kind: _AgentActionKind.summarizeIncident,
              label: 'Build Handoff',
              detail: 'Package the signal into a War Room-ready handoff.',
              payload: incident,
              personaId: 'intel',
            ),
          ],
        ),
        _agentMessage(
          personaId: 'escalation',
          headline: 'Escalation watch armed',
          body:
              'I will treat inactivity plus a biometric spike as a timed escalation risk, not a final conclusion. If controller action stalls, the escalation agent should nudge the next step instead of spamming the whole UI.',
        ),
      ];
    }

    if (_looksLikePatrolPrompt(normalized)) {
      return <_AgentMessage>[
        _agentMessage(
          personaId: 'main',
          headline: 'Main Brain routed this to Patrol Verification Agent',
          body:
              '$cloudLine I am comparing patrol proof against the expected checkpoint and site context before you act on it.',
        ),
        _agentMessage(
          personaId: 'patrol',
          headline: 'Patrol verification staged',
          body: _patrolVerificationSummary(scope: scope),
          actions: [
            _action(
              id: 'patrol-open-track',
              kind: _AgentActionKind.openTrack,
              label: 'OPEN TACTICAL TRACK',
              detail:
                  'Validate the guard route and current checkpoint continuity.',
              personaId: 'patrol',
              opensRoute: true,
            ),
            _action(
              id: 'patrol-open-cctv',
              kind: _AgentActionKind.openCctv,
              label: 'OPEN CCTV REVIEW',
              detail:
                  'Cross-check the checkpoint visually before accepting patrol proof.',
              personaId: 'camera',
              opensRoute: true,
            ),
          ],
        ),
      ];
    }

    if (_looksLikeClientPrompt(normalized)) {
      return <_AgentMessage>[
        _agentMessage(
          personaId: 'main',
          headline: 'Main Brain routed this to Client Comms Agent',
          body:
              '$cloudLine The reply itself will stay scoped to $scope and hand back into live Client Comms.',
        ),
        _agentMessage(
          personaId: 'client',
          headline: 'Draft reply is ready',
          body: _draftClientReply(scope: scope, incident: incident),
          actions: [
            _action(
              id: 'draft-client-reply',
              kind: _AgentActionKind.draftClientReply,
              label: 'Refine Draft',
              detail:
                  'Expand this into a client-ready update while keeping the same scope.',
              payload: prompt,
              personaId: 'client',
            ),
            _action(
              id: 'open-comms-route',
              kind: _AgentActionKind.openComms,
              label: 'OPEN CLIENT COMMS',
              detail:
                  'Move into Client Comms and keep this draft tied to the active scope.',
              personaId: 'client',
              opensRoute: true,
            ),
            if (incident.isNotEmpty)
              _action(
                id: 'open-alarms-route',
                kind: _AgentActionKind.openAlarms,
                label: 'OPEN DISPATCH BOARD',
                detail:
                    'Cross-check the client wording against the active dispatch flow.',
                personaId: 'dispatch',
                opensRoute: true,
              ),
          ],
        ),
      ];
    }

    if (_looksLikeReportPrompt(normalized)) {
      return <_AgentMessage>[
        _agentMessage(
          personaId: 'main',
          headline: 'Main Brain routed this to Reports Workspace Agent',
          body:
              '$cloudLine I will compile the current scope into a Reports Workspace narrative first, then you can refine it or pass it onward.',
        ),
        _agentMessage(
          personaId: 'report',
          headline: 'Reports Workspace narrative draft',
          body: _reportNarrative(scope: scope, incident: incident),
          actions: [
            _action(
              id: 'report-open-comms',
              kind: _AgentActionKind.openComms,
              label: 'OPEN CLIENT COMMS',
              detail: 'Share or adapt the narrative from scoped Client Comms.',
              personaId: 'client',
              opensRoute: true,
            ),
            _action(
              id: 'report-summary',
              kind: _AgentActionKind.summarizeIncident,
              label: 'CONDENSE FOR REPORTS WORKSPACE',
              detail: 'Reduce the draft to a short Reports Workspace handoff.',
              payload: incident,
              personaId: 'report',
            ),
          ],
        ),
      ];
    }

    if (_looksLikeCorrelationPrompt(normalized) ||
        _looksLikeClassificationPrompt(normalized)) {
      return <_AgentMessage>[
        _agentMessage(
          personaId: 'main',
          headline: 'Main Brain routed this to Signal Picture Agent',
          body:
              '$cloudLine I am combining the active signals first, then I will classify the incident so your next handoff stays clean.',
        ),
        _agentMessage(
          personaId: 'intel',
          headline: 'War Room signal picture',
          body: _correlationSummary(scope: scope, incident: incident),
          actions: [
            _action(
              id: 'correlation-open-cctv',
              kind: _AgentActionKind.openCctv,
              label: 'OPEN CCTV REVIEW',
              detail: 'Check the visual context that shaped the fused signal.',
              personaId: 'camera',
              opensRoute: true,
            ),
            _action(
              id: 'correlation-open-track',
              kind: _AgentActionKind.openTrack,
              label: 'OPEN TACTICAL TRACK',
              detail:
                  'Confirm Tactical Track posture against the fused War Room picture.',
              personaId: 'dispatch',
              opensRoute: true,
            ),
            _action(
              id: 'correlation-open-alarms',
              kind: _AgentActionKind.openAlarms,
              label: 'OPEN DISPATCH BOARD',
              detail: 'Check Dispatch Board timing and the live board state.',
              personaId: 'dispatch',
              opensRoute: true,
            ),
          ],
        ),
        _agentMessage(
          personaId: 'classification',
          headline: 'Incident triage ready',
          body: _classificationSummary(),
        ),
      ];
    }

    if (_looksLikeSystemPrompt(normalized) ||
        _looksLikePolicyPrompt(normalized)) {
      final personaId = _looksLikePolicyPrompt(normalized)
          ? 'policy'
          : normalized.contains('debug') ||
                normalized.contains('confidence') ||
                normalized.contains('breakdown')
          ? 'debug'
          : 'system';
      return <_AgentMessage>[
        _agentMessage(
          personaId: 'main',
          headline: 'Main Brain routed this to Governance Desk',
          body:
              '$cloudLine I am keeping execution local and treating this as a read-first Governance Desk workflow.',
        ),
        _agentMessage(
          personaId: personaId,
          headline: personaId == 'policy'
              ? 'Governance Desk policy check'
              : personaId == 'debug'
              ? 'War Room signal breakdown'
              : 'Governance Desk health check',
          body: personaId == 'policy'
              ? _policySummary()
              : personaId == 'debug'
              ? _debugSummary()
              : _systemHealthSummary(),
          actions: [
            _action(
              id: 'system-open-cctv',
              kind: _AgentActionKind.openCctv,
              label: 'OPEN CCTV REVIEW',
              detail:
                  'Validate the affected feed or camera state in CCTV Review.',
              personaId: 'system',
              opensRoute: true,
            ),
            _action(
              id: 'system-open-alarms',
              kind: _AgentActionKind.openAlarms,
              label: 'OPEN DISPATCH BOARD',
              detail: 'Cross-check health changes against live alarm activity.',
              personaId: 'dispatch',
              opensRoute: true,
            ),
          ],
        ),
      ];
    }

    if (_looksLikeDispatchPrompt(normalized)) {
      return <_AgentMessage>[
        _agentMessage(
          personaId: 'main',
          headline: 'Main Brain routed this to Dispatch Board Agent',
          body:
              '$cloudLine I am keeping the next steps inside the simple ONYX pages so you do not fall back into the old workspace.',
        ),
        _agentMessage(
          personaId: 'dispatch',
          headline: 'Scoped handoff ladder is ready',
          body: incident.isEmpty
              ? 'I can hand you directly into Dispatch Board, Tactical Track, CCTV Review, or Client Comms using the current War Room scope.'
              : 'I can hand $incident directly into Dispatch Board, Tactical Track, CCTV Review, or Client Comms without breaking the simplified controller flow.',
          actions: [
            _action(
              id: 'dispatch-open-alarms',
              kind: _AgentActionKind.openAlarms,
              label: 'OPEN DISPATCH BOARD',
              detail: 'Move into Dispatch Board and keep the incident scoped.',
              personaId: 'dispatch',
              opensRoute: true,
            ),
            _action(
              id: 'dispatch-open-track',
              kind: _AgentActionKind.openTrack,
              label: 'OPEN TACTICAL TRACK',
              detail:
                  'Jump into Tactical Track for live unit posture and route continuity.',
              personaId: 'dispatch',
              opensRoute: true,
            ),
            _action(
              id: 'dispatch-open-cctv',
              kind: _AgentActionKind.openCctv,
              label: 'OPEN CCTV REVIEW',
              detail:
                  'Verify video context inside CCTV Review without leaving the simple controller stack.',
              personaId: 'camera',
              opensRoute: true,
            ),
            _action(
              id: 'dispatch-open-comms',
              kind: _AgentActionKind.openComms,
              label: 'OPEN CLIENT COMMS',
              detail: 'Draft or send the client update from Client Comms.',
              personaId: 'client',
              opensRoute: true,
            ),
          ],
        ),
      ];
    }

    return <_AgentMessage>[
      _agentMessage(
        personaId: 'main',
        headline: 'Main Brain staged the next step',
        body:
            '$cloudLine I can treat this as a camera task, a client-reply task, or an incident-routing task. If you want a deeper reasoning pass, enable cloud boost first and then resend the request.',
        actions: [
          _action(
            id: 'generic-probe-camera',
            kind: _AgentActionKind.seedPrompt,
            label: 'Probe Camera',
            detail: 'Start a LAN-first device probe.',
            payload: 'Probe camera 192.168.1.64 and validate RTSP / ONVIF',
            personaId: 'camera',
          ),
          _action(
            id: 'generic-draft-client',
            kind: _AgentActionKind.seedPrompt,
            label: 'Draft Client Reply',
            detail: 'Shape a scoped client update.',
            payload: 'Draft a client update for the current incident',
            personaId: 'client',
          ),
          _action(
            id: 'generic-one-next-move',
            kind: _AgentActionKind.seedPrompt,
            label: 'One Next Move',
            detail: 'Triage the active incident into one obvious desk handoff.',
            payload:
                'Triage the active incident and stage one obvious next move',
            personaId: 'dispatch',
          ),
          _action(
            id: 'generic-summarize-incident',
            kind: _AgentActionKind.summarizeIncident,
            label: 'Summarize Incident',
            detail: 'Turn the active signal into a handoff-ready summary.',
            payload: incident,
            personaId: 'intel',
          ),
        ],
      ),
    ];
  }

  String _brainStatusSummaryText() {
    if (_preferCloudBoost && _cloudBoostAvailable) {
      return 'OpenAI is pinned for this thread. Approval stays with you.';
    }
    if (_localBrainConfigured && _cloudBoostAvailable) {
      return 'Smart routing is active. Fast tasks stay local; complex or overdue work can escalate to OpenAI. Approval stays with you.';
    }
    if (_localBrainConfigured) {
      return 'Local first. Approval stays with you. OpenAI is optional, not required.';
    }
    if (_cloudBoostAvailable) {
      return 'Cloud reasoning is available for deeper passes. Approval stays with you.';
    }
    return 'Local heuristics stay first. Approval stays with you. OpenAI remains optional.';
  }

  String _brainRoutingNarrativeForPrompt({
    required _AgentBrainProvider preferredBrainProvider,
  }) {
    if (_preferCloudBoost && _cloudBoostAvailable) {
      return 'OpenAI is pinned for this thread, but execution stays local and approval-gated.';
    }
    return switch (preferredBrainProvider) {
      _AgentBrainProvider.cloud when _cloudBoostAvailable =>
        'Smart routing escalated this request to OpenAI for a deeper advisory while execution stays local and approval-gated.',
      _AgentBrainProvider.local when _localBrainConfigured =>
        _cloudBoostAvailable
            ? 'Smart routing kept this request on the offline model first, with OpenAI still available if the thread needs a deeper second pass.'
            : 'This login is locked to local mode, so the offline model and local ONYX tools stay inside the app.',
      _AgentBrainProvider.cloud =>
        'Cloud routing is preferred for this request, but the advisory will stay local until a cloud provider is available.',
      _AgentBrainProvider.none =>
        'This login is locked to local-first mode, so reasoning and tools stay inside ONYX.',
      _AgentBrainProvider.local =>
        'This login is locked to local-first mode, so reasoning and tools stay inside ONYX.',
    };
  }

  _AgentBrainProvider _resolvePreferredBrainProvider({
    required String prompt,
    required OnyxAgentCloudScope scope,
    required OnyxAgentCloudIntent intent,
  }) {
    if (_preferCloudBoost && _cloudBoostAvailable) {
      return _AgentBrainProvider.cloud;
    }
    final preferredTier = onyxAgentSmartRoutingTierFor(
      intent: intent,
      prompt: prompt,
      pendingFollowUpAgeMinutes: scope.pendingFollowUpAgeMinutes,
    );
    return switch (preferredTier) {
      OnyxAgentRoutingTier.cloud when _cloudBoostAvailable =>
        _AgentBrainProvider.cloud,
      OnyxAgentRoutingTier.cloud when _localBrainConfigured =>
        _AgentBrainProvider.local,
      OnyxAgentRoutingTier.local when _localBrainConfigured =>
        _AgentBrainProvider.local,
      OnyxAgentRoutingTier.local when _cloudBoostAvailable =>
        _AgentBrainProvider.cloud,
      _ => _AgentBrainProvider.none,
    };
  }

  bool _shouldFallbackLocalBrainToCloud(OnyxAgentCloudIntent intent) {
    return !_preferCloudBoost &&
        _cloudBoostAvailable &&
        intent == OnyxAgentCloudIntent.general;
  }

  OnyxWorkItem? _structuredWorkItemForPrompt(
    String prompt,
    OnyxAgentContextSnapshot contextSnapshot,
    String reasoningContext,
    _AgentThreadMemory threadMemory,
  ) {
    final normalized = prompt.trim().toLowerCase();
    if (!_looksLikeTriagePrompt(normalized)) {
      return null;
    }
    final createdAt = DateTime.now();
    final pendingFollowUpTarget =
        threadMemory.nextFollowUpLabel.trim().isEmpty ||
            threadMemory.nextFollowUpPrompt.trim().isEmpty
        ? null
        : (threadMemory.lastRecommendedTarget ?? threadMemory.lastOpenedTarget);
    final pendingFollowUpAgeMinutes = threadMemory.updatedAt == null
        ? 0
        : createdAt.difference(threadMemory.updatedAt!).inMinutes;
    return OnyxWorkItem(
      id: 'work-item-${createdAt.microsecondsSinceEpoch}',
      intent: OnyxWorkIntent.triageIncident,
      prompt: prompt,
      clientId: widget.scopeClientId,
      siteId: widget.scopeSiteId,
      incidentReference: widget.focusIncidentReference,
      sourceRouteLabel: widget.sourceRouteLabel,
      createdAt: createdAt,
      contextSummary: reasoningContext,
      totalScopedEvents: contextSnapshot.totalScopedEvents,
      activeDispatchCount: contextSnapshot.activeDispatchCount,
      dispatchesAwaitingResponseCount:
          contextSnapshot.dispatchesAwaitingResponseCount,
      responseCount: contextSnapshot.responseCount,
      closedDispatchCount: contextSnapshot.closedDispatchCount,
      patrolCount: contextSnapshot.patrolCount,
      guardCheckInCount: contextSnapshot.guardCheckInCount,
      scopedSiteCount: contextSnapshot.scopedSiteCount,
      hasVisualSignal: contextSnapshot.hasVisualSignal,
      latestIntelligenceHeadline: contextSnapshot.latestIntelligenceHeadline,
      latestIntelligenceSourceType:
          contextSnapshot.latestIntelligenceSourceType,
      latestIntelligenceRiskScore: contextSnapshot.latestIntelligenceRiskScore,
      latestPartnerStatusLabel: contextSnapshot.latestPartnerStatusLabel,
      latestResponderLabel: contextSnapshot.latestResponderLabel,
      latestEventLabel: contextSnapshot.latestEventLabel,
      latestEventAt: contextSnapshot.latestEventAt,
      latestDispatchCreatedAt: contextSnapshot.latestDispatchCreatedAt,
      latestClosureAt: contextSnapshot.latestClosureAt,
      prioritySiteLabel: contextSnapshot.prioritySiteLabel,
      prioritySiteReason: contextSnapshot.prioritySiteReason,
      prioritySiteRiskScore: contextSnapshot.prioritySiteRiskScore,
      rankedSiteSummaries: contextSnapshot.rankedSiteSummaries,
      repeatedFalseAlarmCount: contextSnapshot.repeatedFalseAlarmCount,
      hasHumanSafetySignal: contextSnapshot.hasHumanSafetySignal,
      hasGuardWelfareRisk: contextSnapshot.hasGuardWelfareRisk,
      guardWelfareSignalLabel: contextSnapshot.guardWelfareSignalLabel,
      pendingFollowUpLabel: threadMemory.nextFollowUpLabel,
      pendingFollowUpPrompt: threadMemory.nextFollowUpPrompt,
      pendingFollowUpTarget: pendingFollowUpTarget,
      pendingFollowUpAgeMinutes: pendingFollowUpAgeMinutes,
      staleFollowUpSurfaceCount: threadMemory.staleFollowUpSurfaceCount,
      pendingConfirmations: threadMemory.pendingConfirmations,
    );
  }

  BrainDecision _brainDecisionForWorkItem(
    OnyxWorkItem workItem, {
    OnyxAgentBrainAdvisory? advisory,
    PlannerDisagreementTelemetry? plannerDisagreementTelemetry,
  }) {
    final deterministicRecommendation = _commandBrainOrchestrator
        .operatorOrchestrator
        .recommend(workItem);
    return _commandBrainOrchestrator.decide(
      item: workItem,
      advisory: advisory,
      decisionBias: _replayHistorySignal?.toBrainDecisionBias(),
      replayBiasStack: _replayHistoryBiasStack,
      plannerDisagreementTelemetry: plannerDisagreementTelemetry,
      specialistAssessments: advisory == null
          ? const <SpecialistAssessment>[]
          : _specialistAssessmentService.assess(
              item: workItem,
              deterministicRecommendation: deterministicRecommendation,
            ),
    );
  }

  List<BrainDecisionBias> get _replayHistoryBiasStack =>
      _replayHistorySignalStack
          .map((signal) => signal.toBrainDecisionBias())
          .whereType<BrainDecisionBias>()
          .toList(growable: false);

  OnyxAgentCloudScope _brainScopeForThreadMemory(
    _AgentThreadMemory memory, {
    required _PlannerConflictReport plannerConflictReport,
  }) {
    final pendingTarget =
        memory.nextFollowUpLabel.trim().isEmpty ||
            memory.nextFollowUpPrompt.trim().isEmpty
        ? null
        : (memory.lastRecommendedTarget ?? memory.lastOpenedTarget);
    final operatorFocusPreserved = _threadHasOperatorFocus(_selectedThreadId);
    final operatorFocusThreadTitle = operatorFocusPreserved
        ? (_threadTitleForId(_selectedThreadId) ?? _selectedThread.title)
        : '';
    final urgentThreadId = operatorFocusPreserved
        ? _bestThreadIdForPrioritizedMaintenanceFromReport(
            plannerConflictReport,
          )
        : null;
    final operatorFocusUrgentThreadTitle =
        operatorFocusPreserved &&
            urgentThreadId != null &&
            urgentThreadId != _selectedThreadId
        ? (_threadTitleForId(urgentThreadId) ?? '')
        : '';
    return OnyxAgentCloudScope(
      clientId: widget.scopeClientId,
      siteId: widget.scopeSiteId,
      incidentReference: widget.focusIncidentReference,
      sourceRouteLabel: widget.sourceRouteLabel,
      operatorFocusPreserved: operatorFocusPreserved,
      operatorFocusThreadTitle: operatorFocusThreadTitle,
      operatorFocusUrgentThreadTitle: operatorFocusUrgentThreadTitle,
      pendingFollowUpLabel: memory.nextFollowUpLabel,
      pendingFollowUpPrompt: memory.nextFollowUpPrompt,
      pendingFollowUpTarget: pendingTarget,
      pendingFollowUpStatus: _pendingFollowUpStatusForMemory(memory),
      pendingFollowUpAgeMinutes: _pendingFollowUpAgeMinutesForMemory(memory),
      pendingFollowUpReopenCycles: memory.staleFollowUpSurfaceCount,
      pendingConfirmations: List<String>.from(memory.pendingConfirmations),
    );
  }

  Future<void> _runStructuredCloudSecondLook({
    required String prompt,
    required String threadId,
    required OnyxWorkItem workItem,
    required BrainDecision typedDecision,
    required _AgentThreadMemory typedMemory,
    required String reasoningContext,
  }) async {
    final typedRecommendation = typedDecision.toRecommendation();
    final plannerConflictReport = _plannerConflictReport();
    OnyxAgentCloudBoostResponse? cloudResponse;
    try {
      cloudResponse = await _runCloudBoost(
        prompt: prompt,
        scope: _brainScopeForThreadMemory(
          typedMemory,
          plannerConflictReport: plannerConflictReport,
        ),
        intent: _cloudIntentForPrompt(prompt),
        contextSummary: _typedSecondLookContext(
          reasoningContext: reasoningContext,
          typedRecommendation: typedRecommendation,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _appendToolMessage(
        headline: 'OpenAI second look unavailable',
        body:
            'The OpenAI second look could not complete, so the typed recommendation stayed active without a cloud override.',
        summary: 'OpenAI second look failed',
      );
      return;
    }
    if (!mounted) {
      return;
    }
    if (cloudResponse?.isError == true) {
      final errorResponse = cloudResponse!;
      _appendToolMessage(
        headline: 'OpenAI second look unavailable',
        body: _brainErrorMessageBody(
          fallbackBody:
              'The OpenAI second look could not complete, so the typed recommendation stayed active without a cloud override.',
          response: errorResponse,
        ),
        summary: _brainErrorMessageSummary(
          fallbackSummary: 'OpenAI second look failed',
          response: errorResponse,
        ),
      );
      return;
    }
    final advisory = cloudResponse?.advisory;
    if (advisory == null) {
      return;
    }
    final resolvedDecision = _brainDecisionForWorkItem(
      workItem,
      advisory: advisory,
      plannerDisagreementTelemetry:
          _plannerDisagreementTelemetryForThreadMemory(
            typedMemory,
            plannerConflictReport,
          ),
    );
    if (_brainDecisionChangedTypedRecommendation(
      typedRecommendation,
      resolvedDecision,
    )) {
      final resolvedRecommendation = resolvedDecision.toRecommendation();
      _updateThreadById(threadId, (thread) {
        return thread.copyWith(
          summary: resolvedRecommendation.summary,
          memory: _rememberRecommendation(
            thread.memory,
            resolvedRecommendation,
            decision: resolvedDecision,
            operatorFocusNote: _selectedOperatorFocusMemoryNote(
              plannerConflictReport,
              selectedThreadTitle: thread.title,
            ),
            plannerConflictReport: plannerConflictReport,
          ),
          messages: [
            ...thread.messages,
            _commandBrainDecisionMessage(
              decision: resolvedDecision,
              plannerConflictReport: plannerConflictReport,
            ),
          ],
        );
      });
      return;
    }
    if (!_brainAdvisoryConflictsWithTypedRecommendation(
      typedRecommendation,
      advisory,
    )) {
      return;
    }
    _updateThreadById(threadId, (thread) {
      return thread.copyWith(
        memory: _rememberTypedPlannerConflict(
          thread.memory,
          typedRecommendation: typedRecommendation,
          advisory: advisory,
          brainLabel: 'OpenAI second look',
        ),
        messages: [
          ...thread.messages,
          _typedPlannerConflictMessage(
            typedRecommendation: typedRecommendation,
            response: cloudResponse!,
            brainLabel: 'OpenAI second look',
            plannerConflictReport: plannerConflictReport,
          ),
        ],
      );
    });
  }

  bool _brainDecisionChangedTypedRecommendation(
    OnyxRecommendation typedRecommendation,
    BrainDecision decision,
  ) {
    final resolvedRecommendation = decision.toRecommendation();
    return resolvedRecommendation.target != typedRecommendation.target ||
        resolvedRecommendation.allowRouteExecution !=
            typedRecommendation.allowRouteExecution;
  }

  String _typedSecondLookContext({
    required String reasoningContext,
    required OnyxRecommendation typedRecommendation,
  }) {
    final parts = <String>[
      reasoningContext,
      'Typed triage recommendation: desk=${typedRecommendation.target.name} advisory=${typedRecommendation.advisory.trim()} allow_route_execution=${typedRecommendation.allowRouteExecution ? 'true' : 'false'} confidence=${typedRecommendation.confidence.toStringAsFixed(2)}',
    ];
    if (typedRecommendation.followUpLabel.trim().isNotEmpty) {
      parts.add(
        'Typed triage follow-up: ${typedRecommendation.followUpLabel.trim()}',
      );
    }
    return parts.where((part) => part.trim().isNotEmpty).join(' ');
  }

  bool _brainAdvisoryConflictsWithTypedRecommendation(
    OnyxRecommendation typedRecommendation,
    OnyxAgentBrainAdvisory advisory,
  ) {
    final targetConflict =
        advisory.recommendedTarget != null &&
        advisory.recommendedTarget != typedRecommendation.target;
    final routeConflict =
        !typedRecommendation.allowRouteExecution &&
        advisory.recommendedTarget != null;
    final followUpConflict =
        advisory.followUpLabel.trim().isNotEmpty &&
        typedRecommendation.followUpLabel.trim().isNotEmpty &&
        advisory.followUpLabel.trim() !=
            typedRecommendation.followUpLabel.trim();
    return targetConflict || routeConflict || followUpConflict;
  }

  _AgentMessage _typedPlannerConflictMessage({
    required OnyxRecommendation typedRecommendation,
    required OnyxAgentCloudBoostResponse response,
    required String brainLabel,
    required _PlannerConflictReport plannerConflictReport,
  }) {
    final advisory = response.advisory!;
    final typedDesk = _deskLabelForTarget(typedRecommendation.target);
    final operatorFocusLine = _selectedOperatorFocusAdvisoryLine(
      plannerConflictReport,
    );
    final primaryPressureLine = _primaryPressureAdvisoryLine(
      contextHighlights: typedRecommendation.contextHighlights,
      hasOperatorFocus: operatorFocusLine != null,
      followUpStatus: _typedRecommendationFollowUpStatus(typedRecommendation),
    );
    return _agentMessage(
      personaId: 'policy',
      headline: 'Typed triage overruled the model suggestion',
      body: buildCommandBodyFromSections(<Iterable<String>>[
        <String>[
          'Typed triage kept $typedDesk as the active desk.',
          if (advisory.recommendedTarget != null)
            '$brainLabel suggested ${_deskLabelForTarget(advisory.recommendedTarget!)} instead.',
          if (typedRecommendation.followUpLabel.trim().isNotEmpty ||
              advisory.followUpLabel.trim().isNotEmpty)
            'Typed follow-up: ${typedRecommendation.followUpLabel.trim().isEmpty ? 'none' : typedRecommendation.followUpLabel.trim()}. Model follow-up: ${advisory.followUpLabel.trim().isEmpty ? 'none' : advisory.followUpLabel.trim()}.',
          ?primaryPressureLine,
          _typedPlannerConflictReason(typedRecommendation),
          if (advisory.why.trim().isNotEmpty)
            'Model rationale: ${advisory.why.trim()}',
        ],
        buildPlannerCommandSupportLines(
          maintenance: _plannerOperatorMaintenanceLines(plannerConflictReport),
        ),
      ]),
    );
  }

  String _typedPlannerConflictReason(OnyxRecommendation typedRecommendation) {
    if (!typedRecommendation.allowRouteExecution) {
      return 'Winner: typed triage. Safety guardrails kept the route closed until the missing context is confirmed.';
    }
    final advisory = typedRecommendation.advisory.trim().toLowerCase();
    if (advisory.contains('human safety') ||
        advisory.contains('guard distress')) {
      return 'Winner: typed triage. Deterministic safety rules outrank the model suggestion when human welfare is in play.';
    }
    if (advisory.contains('overdue') || advisory.contains('response delay')) {
      return 'Winner: typed triage. The outstanding dispatch follow-up still outranks the model suggestion.';
    }
    if (typedRecommendation.target == OnyxToolTarget.tacticalTrack) {
      return 'Winner: typed triage. Live field posture rules kept Tactical Track authoritative for this handoff.';
    }
    return 'Winner: typed triage. Deterministic route rules stay authoritative for desk routing; the model remains advisory only.';
  }

  _AgentThreadMemory _rememberTypedPlannerConflict(
    _AgentThreadMemory memory, {
    required OnyxRecommendation typedRecommendation,
    required OnyxAgentBrainAdvisory advisory,
    required String brainLabel,
  }) {
    return memory.copyWith(
      secondLookConflictCount: memory.secondLookConflictCount + 1,
      lastSecondLookConflictSummary: _typedPlannerConflictTelemetrySummary(
        typedRecommendation: typedRecommendation,
        advisory: advisory,
        brainLabel: brainLabel,
      ),
      lastSecondLookConflictAt: DateTime.now(),
      secondLookModelTargetCounts: _incrementTargetCount(
        memory.secondLookModelTargetCounts,
        advisory.recommendedTarget,
      ),
      secondLookTypedTargetCounts: _incrementTargetCount(
        memory.secondLookTypedTargetCounts,
        typedRecommendation.target,
      ),
      secondLookRouteClosedConflictCount:
          memory.secondLookRouteClosedConflictCount +
          (typedRecommendation.allowRouteExecution ? 0 : 1),
    );
  }

  String _typedPlannerConflictTelemetrySummary({
    required OnyxRecommendation typedRecommendation,
    required OnyxAgentBrainAdvisory advisory,
    required String brainLabel,
  }) {
    final typedDesk = _deskLabelForTarget(typedRecommendation.target);
    final modelDesk = advisory.recommendedTarget == null
        ? ''
        : _deskLabelForTarget(advisory.recommendedTarget!);
    final typedFollowUp = typedRecommendation.followUpLabel.trim();
    final modelFollowUp = advisory.followUpLabel.trim();
    if (!typedRecommendation.allowRouteExecution &&
        advisory.recommendedTarget != null) {
      return '$brainLabel: kept the route closed while the model pushed $modelDesk.';
    }
    if (modelDesk.isNotEmpty &&
        advisory.recommendedTarget != typedRecommendation.target) {
      final base = '$brainLabel: kept $typedDesk over $modelDesk.';
      if (typedFollowUp.isNotEmpty &&
          modelFollowUp.isNotEmpty &&
          typedFollowUp != modelFollowUp) {
        return '$base Follow-up stayed $typedFollowUp over $modelFollowUp.';
      }
      return base;
    }
    if (typedFollowUp.isNotEmpty || modelFollowUp.isNotEmpty) {
      return '$brainLabel: kept follow-up ${typedFollowUp.isEmpty ? 'none' : typedFollowUp} over ${modelFollowUp.isEmpty ? 'none' : modelFollowUp}.';
    }
    return '$brainLabel: disagreement logged while typed triage stayed in control.';
  }

  int _pendingFollowUpAgeMinutesForMemory(_AgentThreadMemory memory) {
    final updatedAt = memory.updatedAt;
    if (updatedAt == null) {
      return 0;
    }
    return DateTime.now().difference(updatedAt).inMinutes;
  }

  String _pendingFollowUpStatusForMemory(_AgentThreadMemory memory) {
    final pendingTarget =
        memory.nextFollowUpLabel.trim().isEmpty ||
            memory.nextFollowUpPrompt.trim().isEmpty
        ? null
        : (memory.lastRecommendedTarget ?? memory.lastOpenedTarget);
    if (pendingTarget == null) {
      return '';
    }
    final ageMinutes = _pendingFollowUpAgeMinutesForMemory(memory);
    if (memory.staleFollowUpSurfaceCount >= 2 || ageMinutes >= 20) {
      return 'overdue';
    }
    if (memory.staleFollowUpSurfaceCount >= 1 || ageMinutes >= 8) {
      return 'unresolved';
    }
    return 'pending';
  }

  List<_AgentMessage> _responsesForStructuredRecommendation(
    OnyxRecommendation recommendation, {
    BrainDecision? decision,
    required _AgentThreadMemory threadMemory,
    required _PlannerConflictReport plannerConflictReport,
  }) {
    final prioritizedRecommendation = _prioritizeRecommendationForReplayRisk(
      recommendation,
    );
    return <_AgentMessage>[
      _agentMessage(
        personaId: 'main',
        headline: 'Main Brain staged one obvious next move',
        body:
            'ONYX kept this triage local and typed. One desk is hot, one action is obvious, and the evidence loop stays attached.',
      ),
      _agentMessage(
        personaId: _personaIdForRecommendationTarget(
          prioritizedRecommendation.target,
        ),
        headline: prioritizedRecommendation.headline,
        body: _structuredRecommendationBody(
          prioritizedRecommendation,
          decision: decision,
          threadMemory: threadMemory,
          plannerConflictReport: plannerConflictReport,
        ),
        actions: [
          if (prioritizedRecommendation.allowRouteExecution)
            _action(
              id: 'typed-triage-${prioritizedRecommendation.target.name}-${DateTime.now().microsecondsSinceEpoch}',
              kind: _AgentActionKind.executeRecommendation,
              label: prioritizedRecommendation.nextMoveLabel,
              detail:
                  'Execute the typed next move and keep the signed evidence loop warm.',
              arguments: prioritizedRecommendation.toToolActionArguments(),
              personaId: _personaIdForRecommendationTarget(
                prioritizedRecommendation.target,
              ),
              opensRoute: true,
            ),
          if (prioritizedRecommendation.followUpPrompt.trim().isNotEmpty &&
              prioritizedRecommendation.followUpLabel.trim().isNotEmpty)
            _action(
              id: 'typed-follow-up-${prioritizedRecommendation.target.name}-${DateTime.now().microsecondsSinceEpoch}',
              kind: _AgentActionKind.seedPrompt,
              label: prioritizedRecommendation.followUpLabel,
              detail:
                  'Queue the next proactive check without losing the current thread state.',
              payload: prioritizedRecommendation.followUpPrompt,
              personaId: 'proactive',
            ),
        ],
      ),
    ];
  }

  String _structuredRecommendationBody(
    OnyxRecommendation recommendation, {
    BrainDecision? decision,
    required _AgentThreadMemory threadMemory,
    required _PlannerConflictReport plannerConflictReport,
  }) {
    final orderedContextHighlights = _orderedVisibleContextHighlights(
      recommendation.contextHighlights,
    );
    final operatorFocusLine = _selectedOperatorFocusAdvisoryLine(
      plannerConflictReport,
    );
    final primaryPressureLine = _primaryPressureAdvisoryLine(
      contextHighlights: orderedContextHighlights,
      hasOperatorFocus: operatorFocusLine != null,
      followUpStatus: _typedRecommendationFollowUpStatus(recommendation),
    );
    final threadContinuityView = _threadMemoryContinuityView(threadMemory);
    final recommendationSnapshot =
        decision?.toSnapshot() ??
        OnyxCommandBrainSnapshot.fromRecommendation(recommendation);
    final replayContextLine = decision?.decisionBias == null
        ? OnyxCommandSurfaceMemoryAdapter.continuityViewForSnapshot(
            recommendationSnapshot,
            rememberedReplayHistorySummary: _replayHistorySignalStack.isEmpty
                ? threadContinuityView.replayHistorySummary
                : '',
            preferRememberedContinuity: true,
          ).replayContextLine
        : null;
    return buildCommandBodyFromSections(<Iterable<String>>[
      <String>[recommendation.detail],
      buildPlannerCommandSupportLines(
        backlog: _plannerOperatorBacklog(plannerConflictReport),
        adjustments: _plannerOperatorAdjustments(plannerConflictReport),
        maintenance: _plannerOperatorMaintenanceLines(plannerConflictReport),
      ),
      recommendation.commandBodyContextLines(
        primaryPressureLine: primaryPressureLine,
        operatorFocusLine: operatorFocusLine,
        replayContextLine: replayContextLine,
        orderedContextHighlights: orderedContextHighlights,
      ),
      buildPlannerCommandSupportLines(
        notes: _plannerOperatorNotes(plannerConflictReport),
      ),
      recommendation.commandBodyClosingLines(
        confidenceLabel: _confidenceLabel(recommendation.confidence),
      ),
    ]);
  }

  OnyxRecommendation _prioritizeRecommendationForReplayRisk(
    OnyxRecommendation recommendation,
  ) {
    final replayHistorySignal = _replayHistorySignal;
    final prioritizedTarget = replayHistorySignal?.prioritizedTarget;
    if (replayHistorySignal == null ||
        !replayHistorySignal.shouldBiasCommandSurface ||
        prioritizedTarget == null) {
      return recommendation;
    }
    final prioritizedDesk = _deskLabelForTarget(prioritizedTarget);
    final baselineDesk = _deskLabelForTarget(recommendation.target);
    final incidentLabel = widget.focusIncidentReference.trim().isEmpty
        ? 'the active incident'
        : widget.focusIncidentReference.trim();
    final policyEscalatedSequenceFallback =
        replayHistorySignal.policyEscalatedSequenceFallback;
    final followUpLabel = switch (replayHistorySignal.scope) {
      ScenarioReplayHistorySignalScope.specialistConstraint =>
        'CLEAR HARD CONSTRAINT',
      ScenarioReplayHistorySignalScope.specialistConflict =>
        'RESOLVE SPECIALIST CONFLICT',
      ScenarioReplayHistorySignalScope.sequenceFallback => '',
      ScenarioReplayHistorySignalScope.specialistDegradation =>
        'RESTORE SPECIALIST SIGNAL',
      ScenarioReplayHistorySignalScope.replayBiasStackDrift => '',
    };
    final followUpPrompt = switch (replayHistorySignal.scope) {
      ScenarioReplayHistorySignalScope.specialistConstraint =>
        'Clear the replay hard specialist constraint for $incidentLabel before resuming $baselineDesk.',
      ScenarioReplayHistorySignalScope.specialistConflict =>
        'Resolve the replay specialist conflict for $incidentLabel before widening beyond $prioritizedDesk.',
      ScenarioReplayHistorySignalScope.sequenceFallback => '',
      ScenarioReplayHistorySignalScope.specialistDegradation =>
        'Restore the replay specialist signal for $incidentLabel before widening beyond $baselineDesk.',
      ScenarioReplayHistorySignalScope.replayBiasStackDrift => '',
    };
    final detailLead = switch (replayHistorySignal.scope) {
      ScenarioReplayHistorySignalScope.specialistConstraint =>
        'Replay history is still showing a blocking specialist constraint.',
      ScenarioReplayHistorySignalScope.specialistConflict =>
        'Replay history is still showing unresolved specialist conflict.',
      ScenarioReplayHistorySignalScope.sequenceFallback =>
        policyEscalatedSequenceFallback
            ? 'Replay policy escalation is still holding the safer sequence fallback.'
            : 'Replay policy is still holding the safer sequence fallback.',
      ScenarioReplayHistorySignalScope.specialistDegradation =>
        'Replay history is still showing unresolved specialist degradation.',
      ScenarioReplayHistorySignalScope.replayBiasStackDrift =>
        'Replay history is still showing replay bias stack drift.',
    };
    final evidenceDetail = switch (replayHistorySignal.scope) {
      ScenarioReplayHistorySignalScope.sequenceFallback =>
        policyEscalatedSequenceFallback
            ? 'ONYX routed you into $prioritizedDesk to honor the replay policy escalation before widening $incidentLabel back toward $baselineDesk.'
            : 'ONYX routed you into $prioritizedDesk to keep the replay fallback path intact for $incidentLabel.',
      _ =>
        'ONYX routed you into $prioritizedDesk to clear ${replayHistorySignal.scopeLabel} pressure for $incidentLabel.',
    };
    final headline =
        replayHistorySignal.scope ==
                ScenarioReplayHistorySignalScope.sequenceFallback &&
            policyEscalatedSequenceFallback
        ? '$prioritizedDesk is the replay escalation desk'
        : '$prioritizedDesk is the replay recovery desk';
    final detail =
        replayHistorySignal.scope ==
                ScenarioReplayHistorySignalScope.sequenceFallback &&
            policyEscalatedSequenceFallback
        ? '$detailLead Open $prioritizedDesk first and satisfy the replay policy escalation before widening back to $baselineDesk.'
        : '$detailLead Open $prioritizedDesk first and clear the replay risk before widening back to $baselineDesk.';
    final summary =
        replayHistorySignal.scope ==
                ScenarioReplayHistorySignalScope.sequenceFallback &&
            policyEscalatedSequenceFallback
        ? 'Replay policy escalation keeps $prioritizedDesk in front while ${replayHistorySignal.scopeLabel} stays active.'
        : 'Replay priority keeps $prioritizedDesk in front while ${replayHistorySignal.scopeLabel} stays active.';
    return OnyxRecommendation(
      workItemId:
          '${recommendation.workItemId}-replay-${replayHistorySignal.scope.name}',
      target: prioritizedTarget,
      nextMoveLabel: _openLabelForTarget(prioritizedTarget),
      headline: headline,
      detail: detail,
      summary: summary,
      evidenceHeadline: '$prioritizedDesk handoff sealed.',
      evidenceDetail: evidenceDetail,
      advisory: replayHistorySignal.operatorSummary,
      confidence: recommendation.confidence < 0.74
          ? 0.74
          : recommendation.confidence,
      missingInfo: recommendation.missingInfo,
      contextHighlights: <String>[
        ...recommendation.contextHighlights,
        replayHistorySignal.operatorSummary,
      ],
      followUpLabel: followUpLabel,
      followUpPrompt: followUpPrompt,
      allowRouteExecution: true,
    );
  }

  _AgentMessage _commandBrainDecisionMessage({
    required BrainDecision decision,
    required _PlannerConflictReport plannerConflictReport,
  }) {
    final recommendation = decision.toRecommendation();
    return _agentMessage(
      personaId: _personaIdForRecommendationTarget(recommendation.target),
      headline: _commandBrainDecisionHeadline(decision),
      body: _commandBrainDecisionBody(
        decision,
        recommendation: recommendation,
        plannerConflictReport: plannerConflictReport,
      ),
      actions: [
        if (recommendation.allowRouteExecution)
          _action(
            id: 'command-brain-${recommendation.target.name}-${DateTime.now().microsecondsSinceEpoch}',
            kind: _AgentActionKind.executeRecommendation,
            label: recommendation.nextMoveLabel,
            detail:
                'Execute the command-brain move and keep the signed evidence loop warm.',
            arguments: recommendation.toToolActionArguments(),
            personaId: _personaIdForRecommendationTarget(recommendation.target),
            opensRoute: true,
          ),
        if (recommendation.followUpPrompt.trim().isNotEmpty &&
            recommendation.followUpLabel.trim().isNotEmpty)
          _action(
            id: 'command-brain-follow-up-${recommendation.target.name}-${DateTime.now().microsecondsSinceEpoch}',
            kind: _AgentActionKind.seedPrompt,
            label: recommendation.followUpLabel,
            detail:
                'Queue the next proactive check without losing the current thread state.',
            payload: recommendation.followUpPrompt,
            personaId: 'proactive',
          ),
      ],
    );
  }

  String _commandBrainDecisionHeadline(BrainDecision decision) {
    return switch (decision.mode) {
      BrainDecisionMode.corroboratedSynthesis =>
        'Command brain corroborated a sharper next move',
      BrainDecisionMode.specialistConstraint =>
        'Command brain held a specialist constraint',
      BrainDecisionMode.deterministic => decision.headline,
    };
  }

  String _commandBrainDecisionBody(
    BrainDecision decision, {
    required OnyxRecommendation recommendation,
    required _PlannerConflictReport plannerConflictReport,
  }) {
    final commandBrainSnapshot = decision.toSnapshot();
    final continuityView =
        OnyxCommandSurfaceMemoryAdapter.continuityViewForSnapshot(
          commandBrainSnapshot,
          rememberedReplayHistorySummary: _replayHistorySignalStack.isEmpty
              ? _threadMemoryContinuityView(
                  _selectedThread.memory,
                ).replayHistorySummary
              : '',
          preferRememberedContinuity: decision.decisionBias == null,
        );
    final recommendationBody = _structuredRecommendationBody(
      recommendation,
      decision: decision,
      threadMemory: _selectedThread.memory,
      plannerConflictReport: plannerConflictReport,
    );
    return buildCommandBodyFromSections(<Iterable<String>>[
      continuityView.commandBrainDecisionLines(
        rationale: decision.rationale,
        supportingSpecialists: decision.supportingSpecialists,
      ),
      <String>[recommendationBody],
    ]);
  }

  String _brainErrorMessageBody({
    required String fallbackBody,
    required OnyxAgentCloudBoostResponse response,
  }) {
    final detail = response.errorDetail.trim();
    if (detail.isEmpty) {
      return fallbackBody;
    }
    return '$fallbackBody\n\nProvider detail: $detail';
  }

  String _brainErrorMessageSummary({
    required String fallbackSummary,
    required OnyxAgentCloudBoostResponse response,
  }) {
    final summary = response.errorSummary.trim();
    return summary.isEmpty ? fallbackSummary : summary;
  }

  List<_AgentMessage> _messagesForBrainResponse({
    required OnyxAgentCloudBoostResponse response,
    required String headline,
    required _PlannerConflictReport plannerConflictReport,
  }) {
    final advisory = response.advisory;
    if (advisory == null) {
      return <_AgentMessage>[
        _agentMessage(
          personaId: 'main',
          headline: headline,
          body: buildCommandBodyFromSections(<Iterable<String>>[
            <String>[response.text],
            <String>['Source: ${response.providerLabel}'],
          ], sectionSeparator: '\n\n'),
        ),
      ];
    }
    return <_AgentMessage>[
      _agentMessage(
        personaId: 'main',
        headline: headline,
        body: _brainAdvisoryBody(
          response,
          plannerConflictReport: plannerConflictReport,
        ),
        actions: _brainAdvisoryActions(advisory),
      ),
    ];
  }

  String _brainAdvisoryBody(
    OnyxAgentCloudBoostResponse response, {
    required _PlannerConflictReport plannerConflictReport,
  }) {
    final advisory = response.advisory;
    if (advisory == null) {
      return buildCommandBodyFromSections(<Iterable<String>>[
        <String>[response.text],
        <String>['Source: ${response.providerLabel}'],
      ], sectionSeparator: '\n\n');
    }
    final operatorFocusLine = _brainOperatorFocusAdvisoryLine(
      advisory,
      plannerConflictReport: plannerConflictReport,
    );
    final orderedContextHighlights = _orderedVisibleContextHighlights(
      advisory.contextHighlights,
    );
    final primaryPressureLine = _brainPrimaryPressureAdvisoryLine(
      advisory,
      contextHighlights: orderedContextHighlights,
      hasOperatorFocus: operatorFocusLine != null,
    );
    return buildCommandBodyFromSections(<Iterable<String>>[
      buildPlannerCommandSupportLines(
        backlog: _plannerOperatorBacklog(plannerConflictReport),
        adjustments: _plannerOperatorAdjustments(plannerConflictReport),
        maintenance: _plannerOperatorMaintenanceLines(plannerConflictReport),
      ),
      advisory.commandBodySupportLines(
        primaryPressureLine: primaryPressureLine,
        operatorFocusLine: operatorFocusLine,
        recommendedDeskLabel: advisory.recommendedTarget == null
            ? null
            : _deskLabelForTarget(advisory.recommendedTarget!),
        orderedContextHighlights: orderedContextHighlights,
      ),
      buildPlannerCommandSupportLines(
        notes: _plannerOperatorNotes(plannerConflictReport),
      ),
      advisory.commandBodyClosingLines(
        confidenceLabel: advisory.confidence == null
            ? null
            : _confidenceLabel(advisory.confidence!),
      ),
      advisory.commandBodyFooterLines(
        responseText: response.text,
        providerLabel: response.providerLabel,
      ),
    ]);
  }

  String? _brainPrimaryPressureAdvisoryLine(
    OnyxAgentBrainAdvisory advisory, {
    required Iterable<String> contextHighlights,
    required bool hasOperatorFocus,
  }) {
    final structuredPrimaryPressure = advisory.primaryPressure.trim();
    if (structuredPrimaryPressure.isNotEmpty) {
      final trimmed = structuredPrimaryPressure.replaceFirst(
        RegExp(r'[.]+$'),
        '',
      );
      if (trimmed.isNotEmpty) {
        return 'Primary pressure: ${trimmed.toLowerCase()}.';
      }
    }
    return _primaryPressureAdvisoryLine(
      contextHighlights: contextHighlights,
      hasOperatorFocus: hasOperatorFocus,
      followUpStatus: advisory.followUpStatus,
    );
  }

  String? _brainOperatorFocusAdvisoryLine(
    OnyxAgentBrainAdvisory advisory, {
    required _PlannerConflictReport plannerConflictReport,
  }) {
    final modelNote = advisory.operatorFocusNote.trim();
    if (modelNote.isNotEmpty) {
      return 'Operator focus: $modelNote';
    }
    return _selectedOperatorFocusAdvisoryLine(plannerConflictReport);
  }

  String? _selectedOperatorFocusAdvisoryLine(
    _PlannerConflictReport plannerConflictReport,
  ) {
    if (!_threadHasOperatorFocus(_selectedThreadId)) {
      return null;
    }
    final urgentThreadId = _bestThreadIdForPrioritizedMaintenanceFromReport(
      plannerConflictReport,
    );
    if (urgentThreadId != null && urgentThreadId != _selectedThreadId) {
      final urgentThreadTitle = _threadTitleForId(urgentThreadId);
      if (urgentThreadTitle != null && urgentThreadTitle.isNotEmpty) {
        return 'Operator focus: preserving your current thread while urgent review stays visible on $urgentThreadTitle.';
      }
      return 'Operator focus: preserving your current thread while urgent review stays visible in the rail.';
    }
    return 'Operator focus: preserving your current thread until you move to another conversation.';
  }

  String _typedRecommendationFollowUpStatus(OnyxRecommendation recommendation) {
    if (recommendation.followUpLabel.trim().isEmpty) {
      return '';
    }
    final advisory = recommendation.advisory.trim().toLowerCase();
    if (advisory.contains('overdue') || advisory.contains('response delay')) {
      return 'overdue';
    }
    return 'unresolved';
  }

  String _typedRecommendationPrimaryPressure(
    OnyxRecommendation recommendation, {
    required _PlannerConflictReport plannerConflictReport,
    required String operatorFocusNote,
  }) {
    if (_plannerTopActiveMaintenanceAlert(plannerConflictReport) != null) {
      return 'planner maintenance';
    }
    final category = _primaryPressureCategoryForVisibleContext(
      contextHighlights: recommendation.contextHighlights,
      hasOperatorFocus: operatorFocusNote.trim().isNotEmpty,
      followUpStatus: _typedRecommendationFollowUpStatus(recommendation),
    );
    return category == null
        ? ''
        : (_primaryPressureLabelForCategory(category) ?? '');
  }

  String _brainAdvisoryPrimaryPressure(
    OnyxAgentBrainAdvisory advisory, {
    required bool hasOperatorFocus,
  }) {
    final structuredPrimaryPressure = advisory.primaryPressure.trim();
    if (structuredPrimaryPressure.isNotEmpty) {
      return structuredPrimaryPressure
          .replaceFirst(RegExp(r'[.]+$'), '')
          .trim()
          .toLowerCase();
    }
    final category = _primaryPressureCategoryForVisibleContext(
      contextHighlights: advisory.contextHighlights,
      hasOperatorFocus: hasOperatorFocus,
      followUpStatus: advisory.followUpStatus,
    );
    return category == null
        ? ''
        : (_primaryPressureLabelForCategory(category) ?? '');
  }

  String? _primaryPressureAdvisoryLine({
    required Iterable<String> contextHighlights,
    required bool hasOperatorFocus,
    String followUpStatus = '',
  }) {
    final category = _primaryPressureCategoryForVisibleContext(
      contextHighlights: contextHighlights,
      hasOperatorFocus: hasOperatorFocus,
      followUpStatus: followUpStatus,
    );
    final label = switch (category) {
      _AgentContextHighlightCategory.maintenance => 'planner maintenance',
      _AgentContextHighlightCategory.overdueFollowUp => 'overdue follow-up',
      _AgentContextHighlightCategory.unresolvedFollowUp =>
        'unresolved follow-up',
      _AgentContextHighlightCategory.operatorFocus => 'operator focus hold',
      _AgentContextHighlightCategory.other => 'active signal watch',
      null => null,
    };
    if (label == null) {
      return null;
    }
    return 'Primary pressure: $label.';
  }

  _AgentContextHighlightCategory? _primaryPressureCategoryForVisibleContext({
    required Iterable<String> contextHighlights,
    required bool hasOperatorFocus,
    String followUpStatus = '',
  }) {
    final orderedHighlights = _orderedVisibleContextHighlights(
      contextHighlights,
    );
    final firstHighlightCategory = orderedHighlights.isNotEmpty
        ? _agentContextHighlightCategory(orderedHighlights.first)
        : null;
    if (firstHighlightCategory != null &&
        firstHighlightCategory != _AgentContextHighlightCategory.other) {
      return firstHighlightCategory;
    }
    final normalizedFollowUpStatus = followUpStatus.trim().toLowerCase();
    if (normalizedFollowUpStatus == 'overdue') {
      return _AgentContextHighlightCategory.overdueFollowUp;
    }
    if (normalizedFollowUpStatus == 'unresolved') {
      return _AgentContextHighlightCategory.unresolvedFollowUp;
    }
    if (hasOperatorFocus) {
      return _AgentContextHighlightCategory.operatorFocus;
    }
    if (orderedHighlights.isNotEmpty) {
      return _AgentContextHighlightCategory.other;
    }
    return null;
  }

  List<String> _orderedVisibleContextHighlights(Iterable<String> highlights) {
    final buckets = <_AgentContextHighlightCategory, List<String>>{
      _AgentContextHighlightCategory.maintenance: <String>[],
      _AgentContextHighlightCategory.overdueFollowUp: <String>[],
      _AgentContextHighlightCategory.unresolvedFollowUp: <String>[],
      _AgentContextHighlightCategory.operatorFocus: <String>[],
      _AgentContextHighlightCategory.other: <String>[],
    };
    for (final highlight in highlights) {
      final trimmed = highlight.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      buckets[_agentContextHighlightCategory(trimmed)]!.add(trimmed);
    }
    return <String>[
      ...buckets[_AgentContextHighlightCategory.maintenance]!,
      ...buckets[_AgentContextHighlightCategory.overdueFollowUp]!,
      ...buckets[_AgentContextHighlightCategory.unresolvedFollowUp]!,
      ...buckets[_AgentContextHighlightCategory.operatorFocus]!,
      ...buckets[_AgentContextHighlightCategory.other]!,
    ];
  }

  _AgentContextHighlightCategory _agentContextHighlightCategory(
    String highlight,
  ) {
    final normalized = highlight.trim().toLowerCase();
    if (normalized.startsWith('top maintenance pressure:')) {
      return _AgentContextHighlightCategory.maintenance;
    }
    if (normalized.startsWith('outstanding follow-up:')) {
      if (normalized.contains('(overdue')) {
        return _AgentContextHighlightCategory.overdueFollowUp;
      }
      if (normalized.contains('(unresolved')) {
        return _AgentContextHighlightCategory.unresolvedFollowUp;
      }
    }
    if (normalized.startsWith('operator focus:')) {
      return _AgentContextHighlightCategory.operatorFocus;
    }
    return _AgentContextHighlightCategory.other;
  }

  List<_AgentActionCard> _brainAdvisoryActions(
    OnyxAgentBrainAdvisory advisory,
  ) {
    final actions = <_AgentActionCard>[];
    final target = advisory.recommendedTarget;
    if (target != null && target != OnyxToolTarget.reportsWorkspace) {
      actions.add(
        _action(
          id: 'brain-open-${target.name}',
          kind: _actionKindForTarget(target),
          label: _openLabelForTarget(target),
          detail:
              'Follow the brain recommendation${advisory.confidence == null ? '' : ' at ${_confidenceLabel(advisory.confidence!)}'}. ${advisory.why.trim().isEmpty ? 'Keep the scoped controller flow warm while you validate the next desk.' : advisory.why.trim()}',
          personaId: _personaIdForRecommendationTarget(target),
          opensRoute: true,
        ),
      );
    }
    if (advisory.followUpLabel.trim().isNotEmpty &&
        advisory.followUpPrompt.trim().isNotEmpty) {
      actions.add(
        _action(
          id: 'brain-follow-up-${DateTime.now().microsecondsSinceEpoch}-${advisory.followUpLabel.trim().toLowerCase().replaceAll(' ', '-')}',
          kind: _AgentActionKind.seedPrompt,
          label: advisory.followUpLabel.trim(),
          detail: advisory.followUpStatus.trim().isEmpty
              ? 'Queue the brain follow-up without losing the current thread state.'
              : 'Queue the ${advisory.followUpStatus.trim()} brain follow-up without losing the current thread state.',
          payload: advisory.followUpPrompt,
          personaId: 'proactive',
        ),
      );
    }
    return actions;
  }

  _AgentActionKind _actionKindForTarget(OnyxToolTarget target) {
    return switch (target) {
      OnyxToolTarget.dispatchBoard => _AgentActionKind.openAlarms,
      OnyxToolTarget.tacticalTrack => _AgentActionKind.openTrack,
      OnyxToolTarget.cctvReview => _AgentActionKind.openCctv,
      OnyxToolTarget.clientComms => _AgentActionKind.openComms,
      OnyxToolTarget.reportsWorkspace => _AgentActionKind.summarizeIncident,
    };
  }

  String _openLabelForTarget(OnyxToolTarget target) {
    return switch (target) {
      OnyxToolTarget.dispatchBoard => 'OPEN DISPATCH BOARD',
      OnyxToolTarget.tacticalTrack => 'OPEN TACTICAL TRACK',
      OnyxToolTarget.cctvReview => 'OPEN CCTV REVIEW',
      OnyxToolTarget.clientComms => 'OPEN CLIENT COMMS',
      OnyxToolTarget.reportsWorkspace => 'OPEN REPORTS WORKSPACE',
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

  String _confidenceLabel(double confidence) {
    final clamped = confidence.clamp(0.0, 1.0);
    final percentage = (clamped * 100).round();
    if (clamped >= 0.8) {
      return '$percentage% high confidence';
    }
    if (clamped >= 0.6) {
      return '$percentage% medium confidence';
    }
    return '$percentage% cautious confidence';
  }

  Future<void> _handleAction(_AgentActionCard action) async {
    _clearRestoredPressureFocusCue();
    _clearPlannerFocusCue();
    _markOperatorSelectedThread(_selectedThreadId);
    switch (action.kind) {
      case _AgentActionKind.seedPrompt:
        await _submitPrompt(action.payload);
        return;
      case _AgentActionKind.executeRecommendation:
        _runStructuredRecommendationAction(action);
        return;
      case _AgentActionKind.dryProbeCamera:
        await _runCameraProbeAction(action);
        return;
      case _AgentActionKind.stageCameraChange:
        await _runCameraChangeStageAction(action);
        return;
      case _AgentActionKind.approveCameraChange:
        await _runCameraChangeApproveAction(action);
        return;
      case _AgentActionKind.logCameraRollback:
        await _runCameraRollbackAction(action);
        return;
      case _AgentActionKind.draftClientReply:
        await _runClientDraftAction(action);
        return;
      case _AgentActionKind.summarizeIncident:
        final snapshot = _contextSnapshot();
        _appendAgentMessage(
          personaId: 'intel',
          headline: 'Scoped incident summary',
          body: _incidentSummary(snapshot),
        );
        return;
      case _AgentActionKind.openCctv:
        if (_openCctvRoute()) {
          return;
        }
        break;
      case _AgentActionKind.openComms:
        if (_openCommsRoute()) {
          return;
        }
        break;
      case _AgentActionKind.openAlarms:
        if (_openAlarmsRoute()) {
          return;
        }
        break;
      case _AgentActionKind.openTrack:
        if (_openTrackRoute()) {
          return;
        }
        break;
    }

    _appendToolMessage(
      body:
          'This action is not wired in the current session yet. The page shell is ready, but the route callback is missing.',
      summary: 'Route callback missing',
    );
  }

  Future<void> _runCameraProbeAction(_AgentActionCard action) async {
    final target = action.payload.trim();
    var fallbackReason = '';
    if (_cameraProbeAvailable) {
      try {
        final result = await widget.cameraProbeService!.probe(target);
        if (!mounted) {
          return;
        }
        _appendToolMessage(
          body: result.toOperatorSummary(),
          summary: 'LAN probe completed for ${result.target}',
        );
        return;
      } catch (_) {
        fallbackReason =
            'The live camera probe was unavailable for ${target.isEmpty ? 'the requested target' : target}, so I kept the checklist local.\n\n';
      }
    }
    _appendToolMessage(
      body: '$fallbackReason${_cameraProbeResult(target)}',
      summary:
          'LAN dry probe staged for ${target.isEmpty ? 'the requested target' : target}',
    );
  }

  Future<void> _runCameraChangeStageAction(_AgentActionCard action) async {
    if (_cameraChangeAvailable) {
      try {
        final result = await widget.cameraChangeService!.stage(
          target: action.payload,
          clientId: widget.scopeClientId,
          siteId: widget.scopeSiteId,
          incidentReference: widget.focusIncidentReference,
          sourceRouteLabel: widget.sourceRouteLabel,
        );
        if (!mounted) {
          return;
        }
        _appendToolMessage(
          headline: 'Camera change packet',
          body: result.toOperatorSummary(),
          summary: 'Approval-gated camera change staged for ${result.target}',
          actions: [
            _action(
              id: 'approve-camera-change-${result.packetId}',
              kind: _AgentActionKind.approveCameraChange,
              label: 'Approve + Execute',
              detail:
                  'Capture explicit operator approval, run the local execution path, and log the execution audit.',
              payload: result.target,
              arguments: <String, String>{'packetId': result.packetId},
              requiresApproval: true,
              personaId: 'main',
            ),
            _action(
              id: 'open-cctv-review-${result.packetId}',
              kind: _AgentActionKind.openCctv,
              label: 'OPEN CCTV REVIEW',
              detail:
                  'Keep the scoped camera view ready for validation before and after approval.',
              opensRoute: true,
              personaId: 'camera',
            ),
          ],
        );
        await _refreshCameraAuditHistory();
        return;
      } catch (error, stackTrace) {
        debugPrint(
          'OnyxAgentPage camera change staging failed for '
          '${action.payload.trim().isEmpty ? 'current scoped camera target' : action.payload}: '
          '$error\n$stackTrace',
        );
        if (!mounted) {
          return;
        }
        _appendToolMessage(
          body:
              'The approval-gated camera staging step failed before the packet could be prepared. '
              'No device write was attempted. Re-run the staging action or keep the target under CCTV review while the bridge is checked.',
          summary: 'Camera staging failed',
        );
        return;
      }
    }
    _appendAgentMessage(
      personaId: 'main',
      headline: 'Approval gate is ready',
      body:
          'Before any device write, capture the exact make / model, approved stream profile, credentials, and rollback target. Cloud reasoning can help compare vendor quirks, but credentials should stay local and redacted.',
    );
  }

  Future<void> _runCameraChangeApproveAction(_AgentActionCard action) async {
    if (!_cameraChangeAvailable) {
      _appendToolMessage(
        body: kDebugMode
            ? 'Camera change approval is not wired in this session. Keep the packet local and use CCTV to verify the target manually.'
            : 'Camera changes are not enabled for this deployment. Use CCTV to verify the target manually.',
        summary: 'Camera execution unavailable',
      );
      return;
    }
    try {
      final result = await widget.cameraChangeService!.approveAndExecute(
        packetId: action.arguments['packetId'] ?? '',
        target: action.payload,
        clientId: widget.scopeClientId,
        siteId: widget.scopeSiteId,
        incidentReference: widget.focusIncidentReference,
      );
      if (!mounted) {
        return;
      }
      _appendToolMessage(
        headline: 'Execution audit',
        body: result.toOperatorSummary(),
        summary: 'Camera change executed for ${result.target}',
        actions: [
          _action(
            id: 'rollback-camera-change-${result.executionId}',
            kind: _AgentActionKind.logCameraRollback,
            label: 'Log Rollback',
            detail:
                'Record rollback execution if the stream, quality, or recorder ingest regresses after approval.',
            payload: result.target,
            arguments: <String, String>{
              'packetId': result.packetId,
              'executionId': result.executionId,
            },
            requiresApproval: true,
            personaId: 'main',
          ),
          _action(
            id: 'open-cctv-post-approve-${result.executionId}',
            kind: _AgentActionKind.openCctv,
            label: 'OPEN CCTV REVIEW',
            detail:
                'Validate live view and recorder posture immediately after execution.',
            opensRoute: true,
            personaId: 'camera',
          ),
        ],
      );
      await _refreshCameraAuditHistory();
    } catch (_) {
      if (!mounted) {
        return;
      }
      _appendToolMessage(
        body:
            'Operator approval was captured, but the execution audit could not be completed. Recheck the target in CCTV before any further action.',
        summary: 'Camera execution audit failed',
      );
    }
  }

  Future<void> _runCameraRollbackAction(_AgentActionCard action) async {
    if (!_cameraChangeAvailable) {
      _appendToolMessage(
        body: kDebugMode
            ? 'Rollback logging is not wired in this session. Record the rollback manually in the incident notes and recheck CCTV.'
            : 'Rollback logging is not enabled for this deployment. Record the rollback manually in the incident notes and recheck CCTV.',
        summary: 'Rollback logging unavailable',
      );
      return;
    }
    try {
      final result = await widget.cameraChangeService!.logRollback(
        packetId: action.arguments['packetId'] ?? '',
        executionId: action.arguments['executionId'] ?? '',
        target: action.payload,
      );
      if (!mounted) {
        return;
      }
      _appendToolMessage(
        headline: 'Rollback audit',
        body: result.toOperatorSummary(),
        summary: 'Rollback logged for ${result.target}',
        actions: [
          _action(
            id: 'open-cctv-post-rollback-${result.rollbackId}',
            kind: _AgentActionKind.openCctv,
            label: 'OPEN CCTV REVIEW',
            detail:
                'Validate the restored stream/profile after the rollback audit is logged.',
            opensRoute: true,
            personaId: 'camera',
          ),
        ],
      );
      await _refreshCameraAuditHistory();
    } catch (_) {
      if (!mounted) {
        return;
      }
      _appendToolMessage(
        body:
            'The rollback audit could not be recorded. Keep the rollback local, recheck CCTV, and attach the manual note to the incident.',
        summary: 'Rollback audit failed',
      );
    }
  }

  Future<void> _runClientDraftAction(_AgentActionCard action) async {
    var fallbackPrefix = '';
    if (_clientDraftAvailable) {
      try {
        final result = await widget.clientDraftService!.draft(
          prompt: action.payload,
          clientId: widget.scopeClientId,
          siteId: widget.scopeSiteId,
          incidentReference: widget.focusIncidentReference,
        );
        if (!mounted) {
          return;
        }
        _stageCommsDraftHandoff(
          draftText: result.telegramDraft,
          originalDraftText: result.telegramDraft,
        );
        _appendAgentMessage(
          personaId: 'client',
          headline: 'Refined client draft',
          body:
              '${result.toOperatorSummary()}\n\n${_commsHandoffNextStepLabel()}',
          actions: _refinedDraftHandoffActions(),
        );
        return;
      } catch (_) {
        fallbackPrefix =
            'The live client drafting tool could not finish this request, so I kept the reply local and scoped inside ONYX.\n\n';
      }
    }
    final fallbackDraft = _draftClientReply(
      scope: _scopeLabel(),
      incident: widget.focusIncidentReference.trim(),
    );
    _stageCommsDraftHandoff(
      draftText: fallbackDraft,
      originalDraftText: fallbackDraft,
    );
    _appendAgentMessage(
      personaId: 'client',
      headline: 'Refined client draft',
      body: '$fallbackPrefix$fallbackDraft\n\n${_commsHandoffNextStepLabel()}',
      actions: _refinedDraftHandoffActions(),
    );
  }

  void _runStructuredRecommendationAction(_AgentActionCard action) {
    final recommendation = OnyxRecommendation.fromToolActionArguments(
      action.arguments,
    );
    final result = _toolBridge().executeRecommendation(recommendation);
    if (!mounted) {
      return;
    }
    final commandReceipt = OnyxCommandSurfaceReceiptMemory(
      label: result.receipt.label,
      headline: result.receipt.headline,
      detail: result.receipt.detail,
      target: result.target,
    );
    final commandOutcome = OnyxCommandSurfaceOutcomeMemory(
      headline: result.headline,
      label: recommendation.nextMoveLabel,
      summary: result.summary,
    );
    _updateSelectedThread((thread) {
      return thread.copyWith(
        summary: result.summary,
        memory: thread.memory.copyWith(
          lastCommandReceipt: commandReceipt,
          lastCommandOutcome: commandOutcome,
          updatedAt: DateTime.now(),
        ),
        messages: [
          ...thread.messages,
          _toolMessage(
            body:
                '${result.detail}\n\n${result.receipt.label}\n${result.receipt.headline}\n${result.receipt.detail}',
            headline: result.headline,
          ),
        ],
      );
    });
  }

  OnyxToolBridge _toolBridge() {
    return OnyxToolBridge(
      scopeLabel: _scopeLabel(),
      incidentReference: widget.focusIncidentReference,
      openDispatchBoard: _openAlarmsRoute,
      openTacticalTrack: _openTrackRoute,
      openCctvReview: _openCctvRoute,
      openClientComms: _openCommsRoute,
    );
  }

  void _stageCommsDraftHandoff({
    required String draftText,
    required String originalDraftText,
  }) {
    final callback = widget.onStageCommsDraft;
    if (callback == null) {
      return;
    }
    callback(draftText, originalDraftText);
  }

  String _commsHandoffNextStepLabel() {
    return _commsDraftHandoffAvailable
        ? 'Scoped handoff: this draft is staged in Client Comms for controller review.'
        : 'Next step: open Client Comms and paste or adapt this wording in the scoped thread.';
  }

  List<_AgentActionCard> _refinedDraftHandoffActions() {
    return <_AgentActionCard>[
      _action(
        id: 'refined-draft-open-comms',
        kind: _AgentActionKind.openComms,
        label: 'OPEN CLIENT COMMS',
        detail:
            'Return to Client Comms with this staged draft ready for review.',
        personaId: 'client',
        opensRoute: true,
      ),
    ];
  }

  bool _openCctvRoute() {
    final focus = widget.focusIncidentReference.trim();
    if (focus.isNotEmpty && widget.onOpenCctvForIncident != null) {
      widget.onOpenCctvForIncident!(focus);
      _recordOpenedDesk(OnyxToolTarget.cctvReview);
      return true;
    }
    final callback = widget.onOpenCctv;
    if (callback == null) {
      return false;
    }
    callback();
    _recordOpenedDesk(OnyxToolTarget.cctvReview);
    return true;
  }

  bool _openAlarmsRoute() {
    final focus = widget.focusIncidentReference.trim();
    if (focus.isNotEmpty && widget.onOpenAlarmsForIncident != null) {
      widget.onOpenAlarmsForIncident!(focus);
      _recordOpenedDesk(OnyxToolTarget.dispatchBoard);
      return true;
    }
    final callback = widget.onOpenAlarms;
    if (callback == null) {
      return false;
    }
    callback();
    _recordOpenedDesk(OnyxToolTarget.dispatchBoard);
    return true;
  }

  bool _openTrackRoute() {
    final focus = widget.focusIncidentReference.trim();
    if (focus.isNotEmpty && widget.onOpenTrackForIncident != null) {
      widget.onOpenTrackForIncident!(focus);
      _recordOpenedDesk(OnyxToolTarget.tacticalTrack);
      return true;
    }
    final callback = widget.onOpenTrack;
    if (callback == null) {
      return false;
    }
    callback();
    _recordOpenedDesk(OnyxToolTarget.tacticalTrack);
    return true;
  }

  void _openOperationsRoute() {
    final focus = widget.focusIncidentReference.trim();
    if (focus.isEmpty || widget.onOpenOperationsForIncident == null) {
      return;
    }
    widget.onOpenOperationsForIncident!(focus);
  }

  bool _openCommsRoute() {
    final clientId = widget.scopeClientId.trim();
    final siteId = widget.scopeSiteId.trim();
    if (clientId.isNotEmpty && widget.onOpenCommsForScope != null) {
      widget.onOpenCommsForScope!(clientId, siteId);
      _recordOpenedDesk(OnyxToolTarget.clientComms);
      return true;
    }
    final callback = widget.onOpenComms;
    if (callback == null) {
      return false;
    }
    callback();
    _recordOpenedDesk(OnyxToolTarget.clientComms);
    return true;
  }

  void _appendToolMessage({
    required String body,
    required String summary,
    String headline = 'Local tool result',
    List<_AgentActionCard> actions = const <_AgentActionCard>[],
  }) {
    _updateSelectedThread((thread) {
      return thread.copyWith(
        summary: summary,
        messages: [
          ...thread.messages,
          _toolMessage(body: body, headline: headline, actions: actions),
        ],
      );
    });
  }

  void _appendAgentMessage({
    required String personaId,
    required String headline,
    required String body,
    List<_AgentActionCard> actions = const <_AgentActionCard>[],
  }) {
    _updateSelectedThread((thread) {
      return thread.copyWith(
        messages: [
          ...thread.messages,
          _agentMessage(
            personaId: personaId,
            headline: headline,
            body: body,
            actions: actions,
          ),
        ],
      );
    });
  }

  void _updateSelectedThread(
    _AgentThread Function(_AgentThread thread) update,
  ) {
    _updateThreadById(_selectedThreadId, update);
  }

  void _updateThreadById(
    String threadId,
    _AgentThread Function(_AgentThread thread) update,
  ) {
    final index = _threads.indexWhere((thread) => thread.id == threadId);
    if (index < 0) {
      return;
    }
    if (!mounted) {
      return;
    }
    final nextThread = update(_threads[index]);
    setState(() {
      _threads = [
        for (final thread in _threads)
          if (thread.id == nextThread.id) nextThread else thread,
      ];
      _synchronizePlannerSignalSnapshots(threads: _threads);
    });
    _emitThreadSessionState();
    if (nextThread.id == _selectedThreadId) {
      _scheduleStaleFollowUpSurface(
        threadId: nextThread.id,
        allowImmediate: false,
      );
    }
    _scheduleScrollToBottom();
  }

  void _scheduleScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (!_messageScrollController.hasClients) {
        return;
      }
      _messageScrollController.animateTo(
        _messageScrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  String _scopeLabel() {
    final clientId = widget.scopeClientId.trim();
    final siteId = widget.scopeSiteId.trim();
    if (clientId.isEmpty && siteId.isEmpty) {
      return 'Global controller scope';
    }
    if (clientId.isEmpty) {
      return siteId;
    }
    if (siteId.isEmpty) {
      return '$clientId • all sites';
    }
    return '$clientId • $siteId';
  }

  OnyxAgentContextSnapshot _contextSnapshot() {
    return widget.contextSnapshotService.capture(
      events: widget.events,
      clientId: widget.scopeClientId,
      siteId: widget.scopeSiteId,
      incidentReference: widget.focusIncidentReference,
      sourceRouteLabel: widget.sourceRouteLabel,
    );
  }

  String _threadMemoryBannerLabel(_AgentThreadMemory memory) {
    final primaryPressure = _threadMemoryPrimaryPressureBannerLabel(memory);
    final continuityView = _threadMemoryContinuityView(memory);
    final lines = continuityView.threadMemoryBannerLines(
      primaryPressureLabel: primaryPressure,
      lastRecommendedDeskLabel: memory.lastRecommendedTarget == null
          ? null
          : _deskLabelForTarget(memory.lastRecommendedTarget!),
      lastOpenedDeskLabel: memory.lastOpenedTarget == null
          ? null
          : _deskLabelForTarget(memory.lastOpenedTarget!),
      pendingConfirmations: memory.pendingConfirmations,
      nextFollowUpLabel: memory.nextFollowUpLabel,
      operatorFocusNote: memory.lastOperatorFocusNote,
      secondLookTelemetryLabel: _hasSecondLookTelemetry(memory)
          ? _secondLookTelemetryBannerLabel(memory)
          : null,
      advisory: memory.lastAdvisory,
      previewSummary: _threadMemoryPreviewSummary(memory),
      recommendationSummary: memory.lastRecommendationSummary,
    );
    return lines.isEmpty
        ? 'This thread is still fresh. ONYX has not committed any desk memory yet.'
        : lines.join(' ');
  }

  String _threadMemoryRailLabel(_AgentThreadMemory memory) {
    final primaryPressure = _threadMemoryPrimaryPressureRailLabel(memory);
    final continuityView = _threadMemoryContinuityView(memory);
    return continuityView
        .threadMemoryRailTokens(
          primaryPressureLabel: primaryPressure,
          lastRecommendedDeskLabel: memory.lastRecommendedTarget == null
              ? null
              : _deskLabelForTarget(memory.lastRecommendedTarget!),
          lastOpenedDeskLabel: memory.lastOpenedTarget == null
              ? null
              : _deskLabelForTarget(memory.lastOpenedTarget!),
          operatorFocusLabel: _threadMemoryRailOperatorFocusLabel(memory),
          pendingConfirmationCount: memory.pendingConfirmations.length,
          hasReadyFollowUp: memory.nextFollowUpLabel.trim().isNotEmpty,
          secondLookTelemetryLabel: _hasSecondLookTelemetry(memory)
              ? _secondLookTelemetryRailLabel(memory)
              : null,
        )
        .join(' • ');
  }

  String? _threadMemoryPrimaryPressureBannerLabel(_AgentThreadMemory memory) {
    final category = _threadMemoryPrimaryPressureCategory(memory);
    return category == null ? null : _primaryPressureLabelForCategory(category);
  }

  String? _threadMemoryPrimaryPressureRailLabel(_AgentThreadMemory memory) {
    return switch (_threadMemoryPrimaryPressureCategory(memory)) {
      _AgentContextHighlightCategory.maintenance => 'primary maintenance',
      _AgentContextHighlightCategory.overdueFollowUp =>
        'primary overdue follow-up',
      _AgentContextHighlightCategory.unresolvedFollowUp =>
        'primary unresolved follow-up',
      _AgentContextHighlightCategory.operatorFocus => 'primary operator focus',
      _AgentContextHighlightCategory.other => 'primary signal watch',
      null => null,
    };
  }

  String? _threadMemoryPrimaryPressureResponseLine(_AgentThreadMemory memory) {
    final primaryPressure = _threadMemoryPrimaryPressureBannerLabel(memory);
    if (primaryPressure == null) {
      return null;
    }
    return 'Primary pressure: $primaryPressure.';
  }

  String? _threadMemoryPreviewSummary(_AgentThreadMemory memory) {
    final preview = _threadMemoryContinuityView(memory).commandPreview;
    final summary = preview?.summary.trim() ?? '';
    if (summary.isNotEmpty) {
      return summary;
    }
    final headline = preview?.headline.trim() ?? '';
    return headline.isEmpty ? null : headline;
  }

  String _visibleThreadSummary(_AgentThread thread) {
    final summary = thread.summary.trim();
    final primaryPressure = _threadMemoryPrimaryPressureBannerLabel(
      thread.memory,
    );
    if (primaryPressure == null) {
      return summary;
    }
    final prefix = 'Primary: $primaryPressure.';
    if (summary.isEmpty) {
      return prefix;
    }
    if (summary.startsWith(prefix)) {
      return summary;
    }
    return '$prefix $summary';
  }

  _AgentContextHighlightCategory? _threadMemoryPrimaryPressureCategory(
    _AgentThreadMemory memory,
  ) {
    final storedPrimaryPressure = _primaryPressureCategoryFromValue(
      memory.lastPrimaryPressure,
    );
    if (storedPrimaryPressure != null) {
      return storedPrimaryPressure;
    }
    final orderedHighlights = _orderedVisibleContextHighlights(
      memory.lastContextHighlights,
    );
    final firstHighlightCategory = orderedHighlights.isNotEmpty
        ? _agentContextHighlightCategory(orderedHighlights.first)
        : null;
    if (firstHighlightCategory != null &&
        firstHighlightCategory != _AgentContextHighlightCategory.other) {
      return firstHighlightCategory;
    }
    if (memory.nextFollowUpLabel.trim().isNotEmpty) {
      return switch (_pendingFollowUpStatusForMemory(memory)) {
        'overdue' => _AgentContextHighlightCategory.overdueFollowUp,
        'unresolved' => _AgentContextHighlightCategory.unresolvedFollowUp,
        _ => _AgentContextHighlightCategory.other,
      };
    }
    if (memory.lastOperatorFocusNote.trim().isNotEmpty) {
      return _AgentContextHighlightCategory.operatorFocus;
    }
    if (orderedHighlights.isNotEmpty) {
      return _AgentContextHighlightCategory.other;
    }
    return null;
  }

  String? _primaryPressureLabelForCategory(
    _AgentContextHighlightCategory category,
  ) {
    return switch (category) {
      _AgentContextHighlightCategory.maintenance => 'planner maintenance',
      _AgentContextHighlightCategory.overdueFollowUp => 'overdue follow-up',
      _AgentContextHighlightCategory.unresolvedFollowUp =>
        'unresolved follow-up',
      _AgentContextHighlightCategory.operatorFocus => 'operator focus hold',
      _AgentContextHighlightCategory.other => 'active signal watch',
    };
  }

  _AgentContextHighlightCategory? _primaryPressureCategoryFromValue(
    String value,
  ) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized == 'planner maintenance') {
      return _AgentContextHighlightCategory.maintenance;
    }
    if (normalized == 'overdue follow-up') {
      return _AgentContextHighlightCategory.overdueFollowUp;
    }
    if (normalized == 'unresolved follow-up') {
      return _AgentContextHighlightCategory.unresolvedFollowUp;
    }
    if (normalized == 'operator focus hold') {
      return _AgentContextHighlightCategory.operatorFocus;
    }
    if (normalized == 'active signal watch') {
      return _AgentContextHighlightCategory.other;
    }
    return null;
  }

  String? _threadMemoryRailOperatorFocusLabel(_AgentThreadMemory memory) {
    final note = memory.lastOperatorFocusNote.trim().toLowerCase();
    if (note.isEmpty) {
      return null;
    }
    if (note.contains('urgent review remains visible')) {
      return 'manual focus held';
    }
    return 'manual context held';
  }

  String _threadMemoryReasoningSummary(_AgentThreadMemory memory) {
    if (!memory.hasData) {
      return '';
    }
    final continuityView = _threadMemoryContinuityView(memory);
    final replayHistorySummary = _threadMemoryReplayHistoryLine(memory);
    return continuityView
        .threadMemoryReasoningLines(
          primaryPressureLabel: _threadMemoryPrimaryPressureBannerLabel(memory),
          replayHistorySummary: replayHistorySummary,
          lastRecommendedDeskLabel: memory.lastRecommendedTarget == null
              ? null
              : _deskLabelForTarget(memory.lastRecommendedTarget!),
          lastOpenedDeskLabel: memory.lastOpenedTarget == null
              ? null
              : _deskLabelForTarget(memory.lastOpenedTarget!),
          pendingConfirmations: memory.pendingConfirmations,
          nextFollowUpLabel: memory.nextFollowUpLabel,
          operatorFocusNote: memory.lastOperatorFocusNote,
          secondLookTelemetryLine: _hasSecondLookTelemetry(memory)
              ? buildThreadMemorySecondLookReasoningLine(
                  conflictCount: memory.secondLookConflictCount,
                  lastConflictSummary: memory.lastSecondLookConflictSummary,
                )
              : null,
          advisory: memory.lastAdvisory,
          orderedContextHighlights: _orderedVisibleContextHighlights(
            memory.lastContextHighlights,
          ),
          recommendationSummary: memory.lastRecommendationSummary,
          previewSummary: _threadMemoryPreviewSummary(memory),
        )
        .join(' ');
  }

  String? _threadMemoryReplayHistoryLine(_AgentThreadMemory memory) {
    final liveReplayHistorySummary = summarizeReplayHistorySignalStack(
      _replayHistorySignalStack,
    );
    if (liveReplayHistorySummary != null &&
        liveReplayHistorySummary.trim().isNotEmpty) {
      return liveReplayHistorySummary;
    }
    final storedReplayHistorySummary = _threadMemoryContinuityView(
      memory,
    ).replayHistorySummary.trim();
    if (storedReplayHistorySummary.isEmpty) {
      return null;
    }
    return storedReplayHistorySummary;
  }

  OnyxCommandSurfaceContinuityView _threadMemoryContinuityView(
    _AgentThreadMemory memory,
  ) {
    return memory.commandContinuityView(
      preferRememberedContinuity: _replayHistorySignalStack.isEmpty,
    );
  }

  String _selectedOperatorFocusReasoningSummary(
    _PlannerConflictReport plannerConflictReport,
  ) {
    if (!_threadHasOperatorFocus(_selectedThreadId)) {
      return '';
    }
    final selectedThreadTitle =
        _threadTitleForId(_selectedThreadId) ?? _selectedThread.title;
    final urgentThreadId = _bestThreadIdForPrioritizedMaintenanceFromReport(
      plannerConflictReport,
    );
    if (urgentThreadId != null && urgentThreadId != _selectedThreadId) {
      final urgentThreadTitle = _threadTitleForId(urgentThreadId);
      if (urgentThreadTitle != null && urgentThreadTitle.isNotEmpty) {
        return 'Operator focus preserved on $selectedThreadTitle while urgent review remains visible on $urgentThreadTitle.';
      }
      return 'Operator focus preserved on $selectedThreadTitle while urgent review remains visible elsewhere in the rail.';
    }
    return 'Operator focus preserved on $selectedThreadTitle until the operator changes conversations.';
  }

  String _plannerMaintenancePriorityReasoningSummary(
    _PlannerConflictReport report,
  ) {
    final topActiveAlert = _plannerTopActiveMaintenanceAlert(report);
    if (topActiveAlert == null) {
      return '';
    }
    return 'Planner maintenance priority: ${_plannerMaintenanceAlertMessage(report, topActiveAlert)}';
  }

  String _activePrimaryPressureReasoningSummary(
    _AgentThreadMemory memory,
    _PlannerConflictReport report,
  ) {
    final category = _activePrimaryPressureReasoningCategory(memory, report);
    final label = switch (category) {
      _AgentContextHighlightCategory.maintenance => 'planner maintenance',
      _AgentContextHighlightCategory.overdueFollowUp => 'overdue follow-up',
      _AgentContextHighlightCategory.unresolvedFollowUp =>
        'unresolved follow-up',
      _AgentContextHighlightCategory.operatorFocus => 'operator focus hold',
      _AgentContextHighlightCategory.other => 'active signal watch',
      null => null,
    };
    if (label == null) {
      return '';
    }
    return 'Primary pressure: $label.';
  }

  _AgentContextHighlightCategory? _activePrimaryPressureReasoningCategory(
    _AgentThreadMemory memory,
    _PlannerConflictReport report,
  ) {
    if (_plannerTopActiveMaintenanceAlert(report) != null) {
      return _AgentContextHighlightCategory.maintenance;
    }
    return _threadMemoryPrimaryPressureCategory(memory);
  }

  _PlannerMaintenanceAlertEntry? _plannerTopActiveMaintenanceAlert(
    _PlannerConflictReport report,
  ) {
    for (final alert in report.maintenanceAlerts) {
      if (!alert.reviewCompleted) {
        return alert;
      }
    }
    return null;
  }

  int _repeatPromptCount(_AgentThread thread, String prompt) {
    final normalized = prompt.trim().toLowerCase();
    if (normalized.isEmpty) {
      return 0;
    }
    return thread.messages.where((message) {
      return message.kind == _AgentMessageKind.user &&
          message.body.trim().toLowerCase() == normalized;
    }).length;
  }

  ({String headline, String body, String summary}) _compressedRepeatResponse(
    _AgentThreadMemory memory,
  ) {
    final leadLines = <String>['No change from the last check.'];
    final contextLines = <String>[];
    final continuityLines = <String>[];
    final highlightLines = <String>[];
    final followUpLines = <String>[];
    final orderedContextHighlights = _orderedVisibleContextHighlights(
      memory.lastContextHighlights,
    );
    final continuityView = memory.commandContinuityView();
    if (_threadMemoryPrimaryPressureResponseLine(memory) case final primary?) {
      contextLines.add(primary);
    }
    if (memory.lastOperatorFocusNote.trim().isNotEmpty) {
      contextLines.add(
        'Operator focus: ${memory.lastOperatorFocusNote.trim()}',
      );
    }
    if (memory.lastAdvisory.trim().isNotEmpty) {
      contextLines.add(memory.lastAdvisory.trim());
    } else if (memory.lastRecommendationSummary.trim().isNotEmpty) {
      contextLines.add(memory.lastRecommendationSummary.trim());
    } else if (_threadMemoryPreviewSummary(memory) case final previewSummary?) {
      contextLines.add(previewSummary);
    }
    if (memory.lastConfidence != null) {
      continuityLines.add(
        'Confidence: ${_confidenceLabel(memory.lastConfidence!)}',
      );
    }
    if (continuityView.outcomeSummaryLine(trailingPeriod: false)
        case final line?) {
      continuityLines.add(line);
    }
    if (continuityView.receiptLine(trailingPeriod: false) case final line?) {
      continuityLines.add(line);
    }
    if (orderedContextHighlights.isNotEmpty) {
      highlightLines.addAll(orderedContextHighlights.take(2));
    }
    if (memory.pendingConfirmations.isNotEmpty) {
      followUpLines.add(
        'Still confirm ${memory.pendingConfirmations.join(', ')}.',
      );
    }
    if (memory.nextFollowUpLabel.trim().isNotEmpty) {
      followUpLines.add('Next follow-up: ${memory.nextFollowUpLabel.trim()}.');
    }
    final summary = memory.lastRecommendationSummary.trim().isNotEmpty
        ? memory.lastRecommendationSummary.trim()
        : _threadMemoryPreviewSummary(memory) ??
              'No change from the last check.';
    return (
      headline: 'No change from the last check',
      body: buildCommandBodyFromSections(<Iterable<String>>[
        leadLines,
        contextLines,
        continuityLines,
        highlightLines,
        followUpLines,
      ]),
      summary: summary,
    );
  }

  bool _hasSecondLookTelemetry(_AgentThreadMemory memory) {
    return memory.secondLookConflictCount > 0 ||
        memory.lastSecondLookConflictSummary.trim().isNotEmpty;
  }

  String _secondLookTelemetryBannerLabel(_AgentThreadMemory memory) {
    return buildSecondLookTelemetryBannerLabel(
      conflictCount: memory.secondLookConflictCount,
      lastConflictSummary: memory.lastSecondLookConflictSummary,
    );
  }

  String _secondLookTelemetryRailLabel(_AgentThreadMemory memory) {
    return buildSecondLookTelemetryRailLabel(
      conflictCount: memory.secondLookConflictCount,
    );
  }

  PlannerDisagreementTelemetry? _plannerDisagreementTelemetryForThreadMemory(
    _AgentThreadMemory memory,
    _PlannerConflictReport report,
  ) {
    if (report.totalConflictCount <= 0 &&
        report.routeClosedConflictCount <= 0) {
      return null;
    }
    return PlannerDisagreementTelemetry(
      conflictCount: report.totalConflictCount,
      routeClosedConflictCount: report.routeClosedConflictCount,
      modelTargetCounts: {
        for (final entry in report.modelTargetCounts) entry.target: entry.count,
      },
      typedTargetCounts: {
        for (final entry in report.typedTargetCounts) entry.target: entry.count,
      },
      lastConflictSummary: memory.lastSecondLookConflictSummary,
    );
  }

  String _conflictTelemetryTimestampLabel(DateTime timestamp) {
    final age = DateTime.now().difference(timestamp);
    if (age.inMinutes < 1) {
      return 'just now';
    }
    if (age.inHours < 1) {
      final minutes = age.inMinutes;
      return minutes == 1 ? '1 minute ago' : '$minutes minutes ago';
    }
    if (age.inDays < 1) {
      final hours = age.inHours;
      return hours == 1 ? '1 hour ago' : '$hours hours ago';
    }
    final days = age.inDays;
    return days == 1 ? '1 day ago' : '$days days ago';
  }

  _PlannerConflictReport _plannerConflictReport() =>
      _cachedPlannerConflictReport ??= _computePlannerConflictReport();

  _PlannerConflictReport _computePlannerConflictReport() {
    final metrics = _plannerConflictMetricsForThreads(_threads);
    final currentSignalCounts = _plannerSignalCountMap(
      modelTargetCounts: metrics.modelTargetCounts,
      typedTargetCounts: metrics.typedTargetCounts,
      routeClosedConflictCount: metrics.routeClosedConflictCount,
    );
    final suppressedArchivedSignalIds = _suppressedArchivedPlannerSignalIds(
      currentSignalCounts,
    );
    final archivedEntries = _plannerArchivedEntries(
      suppressedArchivedSignalIds: suppressedArchivedSignalIds,
      currentSignalCounts: currentSignalCounts,
    );
    final reactivationEntries = _plannerReactivationEntries(
      currentSignalCounts: currentSignalCounts,
    );
    final previousSignalCounts =
        _sameStringIntMap(
          currentSignalCounts,
          _plannerSignalSnapshot.signalCounts,
        )
        ? _previousPlannerSignalSnapshot.signalCounts
        : _plannerSignalSnapshot.signalCounts;
    final maintenanceAlerts = reactivationEntries
        .where(
          (entry) =>
              _plannerReactivationSeverityLabel(entry.reactivationCount) ==
              'chronic drift',
        )
        .map(
          (entry) => _PlannerMaintenanceAlertEntry(
            signalId: entry.signalId,
            label: entry.label,
            reactivationCount: entry.reactivationCount,
            staleAgainCount:
                _plannerMaintenanceReviewReopenedCounts[entry.signalId] ?? 0,
            lastReactivatedAt: entry.lastReactivatedAt,
            reviewQueuedAt: _plannerMaintenanceReviewQueuedAt[entry.signalId],
            reviewPrioritizedAt:
                _plannerMaintenanceReviewPrioritizedAt[entry.signalId],
            reviewCompletedAt:
                _plannerMaintenanceReviewCompletedAt[entry.signalId],
          ),
        )
        .toList(growable: false);
    maintenanceAlerts.sort((left, right) {
      final byReopened = right.staleAgainCount.compareTo(left.staleAgainCount);
      if (byReopened != 0) {
        return byReopened;
      }
      final leftState = left.reviewReopened
          ? 0
          : left.reviewQueued
          ? 1
          : left.reviewCompleted
          ? 2
          : 3;
      final rightState = right.reviewReopened
          ? 0
          : right.reviewQueued
          ? 1
          : right.reviewCompleted
          ? 2
          : 3;
      final byState = leftState.compareTo(rightState);
      if (byState != 0) {
        return byState;
      }
      final byReactivation = right.reactivationCount.compareTo(
        left.reactivationCount,
      );
      if (byReactivation != 0) {
        return byReactivation;
      }
      return left.label.compareTo(right.label);
    });
    return _PlannerConflictReport(
      totalConflictCount: metrics.totalConflictCount,
      impactedThreadCount: metrics.impactedThreadCount,
      routeClosedConflictCount: metrics.routeClosedConflictCount,
      currentSignalCounts: currentSignalCounts,
      modelTargetCounts: metrics.modelTargetCounts,
      typedTargetCounts: metrics.typedTargetCounts,
      maintenanceAlerts: maintenanceAlerts,
      tuningSignals: _plannerTuningSignals(
        currentSignalCounts: currentSignalCounts,
        previousSignalCounts: previousSignalCounts,
      ),
      tuningSuggestions: _plannerTuningSuggestions(
        currentSignalCounts: currentSignalCounts,
        previousSignalCounts: previousSignalCounts,
        reviewStatuses: _plannerBacklogReviewStatuses,
        suppressedArchivedSignalIds: suppressedArchivedSignalIds,
      ),
      archivedEntries: archivedEntries,
      reactivationEntries: reactivationEntries,
      reactivationSignals: reactivationEntries
          .map(_plannerReactivationMessage)
          .toList(growable: false),
      highestReactivationSeverity: reactivationEntries.isEmpty
          ? ''
          : _plannerReactivationSeverityLabel(
              reactivationEntries.first.reactivationCount,
            ),
      backlogEntries: _plannerBacklogEntries(
        backlogScores: _plannerBacklogScores,
        activeSignalIds: currentSignalCounts.keys.toSet(),
        reviewStatuses: _plannerBacklogReviewStatuses,
        suppressedArchivedSignalIds: suppressedArchivedSignalIds,
      ),
      archivedReviewedCount: suppressedArchivedSignalIds.length,
    );
  }

  String _plannerConflictReportSummary(_PlannerConflictReport report) {
    if (report.maintenanceAlerts.isNotEmpty) {
      final completedCount = report.maintenanceAlerts
          .where((alert) => alert.reviewCompleted)
          .length;
      final activeCount = report.maintenanceAlerts.length - completedCount;
      final severitySummary = _plannerMaintenanceSeveritySummary(report);
      final topMaintenanceAlert = report.topMaintenanceAlert;
      return buildPlannerMaintenanceConflictSummaryLabel(
        activeCount: activeCount,
        completedCount: completedCount,
        severitySummary: severitySummary,
        trackedFromArchivedWatch:
            severitySummary == 'chronic drift from archived watch',
        topBurnRateReopenedCount: topMaintenanceAlert?.staleAgainCount ?? 0,
        hasUrgentReview: report.maintenanceAlerts.any(
          (alert) => alert.reviewPrioritized,
        ),
      );
    }
    if (report.reactivationSignals.isNotEmpty) {
      return buildPlannerReactivationSummaryLabel(
        reactivationSignalCount: report.reactivationSignals.length,
        highestSeverity: report.highestReactivationSeverity,
      );
    }
    if (report.totalConflictCount <= 0 && report.archivedReviewedCount > 0) {
      return buildPlannerArchivedReviewedSummaryLabel(
        archivedReviewedCount: report.archivedReviewedCount,
      );
    }
    if (report.totalConflictCount <= 0 && report.tuningSignals.isNotEmpty) {
      return buildSecondLookPlannerSummaryLabel(
        totalConflictCount: report.totalConflictCount,
        impactedThreadCount: report.impactedThreadCount,
        hasTuningSignals: true,
      );
    }
    return buildSecondLookPlannerSummaryLabel(
      totalConflictCount: report.totalConflictCount,
      impactedThreadCount: report.impactedThreadCount,
      hasTuningSignals: report.tuningSignals.isNotEmpty,
    );
  }

  String _plannerMaintenanceSeveritySummary(_PlannerConflictReport report) {
    final topMaintenanceAlert = report.topMaintenanceAlert;
    if (topMaintenanceAlert == null) {
      return 'chronic drift';
    }
    return _plannerReactivationEntryForSignal(
              report,
              topMaintenanceAlert.signalId,
            ) ==
            null
        ? 'chronic drift'
        : 'chronic drift from archived watch';
  }

  String? _plannerMaintenanceBurnTagLabel(
    _PlannerConflictReport report,
    _PlannerMaintenanceAlertEntry alert,
  ) {
    if (alert.staleAgainCount <= 0) {
      return null;
    }
    if (_plannerMaintenanceIsHighestBurn(report, alert)) {
      return 'HIGHEST BURN';
    }
    return 'REPEAT REGRESSION';
  }

  bool _plannerMaintenanceCanPrioritize(
    _PlannerConflictReport report,
    _PlannerMaintenanceAlertEntry alert,
  ) {
    return _plannerMaintenanceIsHighestBurn(report, alert) ||
        alert.reviewPrioritized;
  }

  bool _plannerMaintenanceIsHighestBurn(
    _PlannerConflictReport report,
    _PlannerMaintenanceAlertEntry alert,
  ) {
    final topMaintenanceAlert = report.topMaintenanceAlert;
    return topMaintenanceAlert != null &&
        topMaintenanceAlert.signalId == alert.signalId &&
        alert.staleAgainCount >= 2;
  }

  String _plannerReactivationMessage(_PlannerReactivationEntry entry) {
    final parts = <String>[
      'Reactivated from archive: ${entry.label} returned after drift worsened from ${entry.archivedAtCount} to ${entry.currentCount}.',
      'Severity: ${_plannerReactivationSeverityLabel(entry.reactivationCount)}.',
      'Reactivation count: ${entry.reactivationCount}.',
    ];
    if (entry.lastReactivatedAt != null) {
      parts.add(
        'Last reactivated: ${_conflictTelemetryTimestampLabel(entry.lastReactivatedAt!)}.',
      );
    }
    return parts.join(' ');
  }

  String _plannerArchivedMessage(_PlannerArchivedEntry entry) {
    final driftState = entry.currentCount <= 0
        ? 'Drift is quiet right now'
        : 'Drift is holding at ${entry.currentCount}';
    return 'Archived rule: ${entry.label}. Hidden from active tuning while $driftState after archiving at ${entry.archivedAtCount}.';
  }

  _PlannerReactivationEntry? _plannerReactivationEntryForSignal(
    _PlannerConflictReport report,
    String signalId,
  ) {
    for (final entry in report.reactivationEntries) {
      if (entry.signalId == signalId) {
        return entry;
      }
    }
    return null;
  }

  String _plannerMaintenanceLineageMessage(_PlannerReactivationEntry entry) {
    return 'Archive lineage: escalated from archived watch after drift rose from ${entry.archivedAtCount} to ${entry.currentCount}.';
  }

  String _plannerConflictReasoningSummary(_PlannerConflictReport report) {
    final parts = <String>[
      ...report.maintenanceAlerts.map(
        (alert) =>
            'Planner maintenance alert: ${_plannerMaintenanceAlertMessage(report, alert)}${alert.reviewQueuedAt == null ? '' : ' Rule review queued ${_conflictTelemetryTimestampLabel(alert.reviewQueuedAt!)}.'}${alert.reviewCompletedAt == null ? '' : ' Review completed ${_conflictTelemetryTimestampLabel(alert.reviewCompletedAt!)}.'}',
      ),
      ...report.reactivationSignals.map(
        (note) => 'Planner reactivation: $note',
      ),
      ..._plannerOperatorBacklog(
        report,
      ).map((note) => 'Planner backlog item: $note'),
      ..._plannerOperatorAdjustments(
        report,
      ).map((note) => 'Planner tuning cue: $note'),
      ..._plannerOperatorNotes(
        report,
      ).map((note) => 'Planner review signal: $note'),
    ];
    if (parts.isEmpty) {
      return '';
    }
    return parts.join(' ');
  }

  ({
    int totalConflictCount,
    int impactedThreadCount,
    int routeClosedConflictCount,
    List<_PlannerConflictTargetCount> modelTargetCounts,
    List<_PlannerConflictTargetCount> typedTargetCounts,
  })
  _plannerConflictMetricsForThreads(List<_AgentThread> threads) {
    final modelTargetCounts = <OnyxToolTarget, int>{};
    final typedTargetCounts = <OnyxToolTarget, int>{};
    var totalConflictCount = 0;
    var impactedThreadCount = 0;
    var routeClosedConflictCount = 0;
    for (final thread in threads) {
      final memory = thread.memory;
      if (memory.secondLookConflictCount <= 0) {
        continue;
      }
      impactedThreadCount += 1;
      totalConflictCount += memory.secondLookConflictCount;
      routeClosedConflictCount += memory.secondLookRouteClosedConflictCount;
      _mergeTargetCountMapInto(
        destination: modelTargetCounts,
        source: memory.secondLookModelTargetCounts,
      );
      _mergeTargetCountMapInto(
        destination: typedTargetCounts,
        source: memory.secondLookTypedTargetCounts,
      );
    }
    return (
      totalConflictCount: totalConflictCount,
      impactedThreadCount: impactedThreadCount,
      routeClosedConflictCount: routeClosedConflictCount,
      modelTargetCounts: _sortedTargetCountList(modelTargetCounts),
      typedTargetCounts: _sortedTargetCountList(typedTargetCounts),
    );
  }

  List<_AgentThread> _orderedThreadsForRail(
    _PlannerConflictReport plannerConflictReport,
  ) {
    final indexedThreads = _threads.indexed
        .map((entry) => (index: entry.$1, thread: entry.$2))
        .toList(growable: false);
    indexedThreads.sort((left, right) {
      final leftUrgent = _threadUrgentMaintenanceScore(
        left.thread,
        plannerConflictReport,
      );
      final rightUrgent = _threadUrgentMaintenanceScore(
        right.thread,
        plannerConflictReport,
      );
      final byUrgent = rightUrgent.compareTo(leftUrgent);
      if (byUrgent != 0) {
        return byUrgent;
      }
      final byPrimaryPressure = _threadPrimaryPressureSortScore(
        right.thread,
      ).compareTo(_threadPrimaryPressureSortScore(left.thread));
      if (byPrimaryPressure != 0) {
        return byPrimaryPressure;
      }
      return left.index.compareTo(right.index);
    });
    return indexedThreads.map((entry) => entry.thread).toList(growable: false);
  }

  int _threadPrimaryPressureSortScore(_AgentThread thread) {
    return switch (_threadMemoryPrimaryPressureCategory(thread.memory)) {
      _AgentContextHighlightCategory.maintenance => 5,
      _AgentContextHighlightCategory.overdueFollowUp => 4,
      _AgentContextHighlightCategory.unresolvedFollowUp => 3,
      _AgentContextHighlightCategory.operatorFocus => 2,
      _AgentContextHighlightCategory.other => 1,
      null => 0,
    };
  }

  String _resolveRestoredSelectedThreadId({
    required String fallbackSelectedThreadId,
  }) {
    final operatorSelectedThreadId = _selectedThreadOperatorId?.trim();
    if (operatorSelectedThreadId != null &&
        operatorSelectedThreadId.isNotEmpty &&
        _selectedThreadOperatorAt != null &&
        _threads.any((thread) => thread.id == operatorSelectedThreadId)) {
      return operatorSelectedThreadId;
    }
    final urgentThreadId = _bestThreadIdForPrioritizedMaintenance();
    if (urgentThreadId != null) {
      return urgentThreadId;
    }
    final resolvedFallbackThreadId =
        _threadById(fallbackSelectedThreadId)?.id ??
        (_threads.isEmpty ? fallbackSelectedThreadId : _threads.first.id);
    final fallbackThread = _threadById(resolvedFallbackThreadId);
    final fallbackScore = fallbackThread == null
        ? 0
        : _threadPrimaryPressureSortScore(fallbackThread);
    final highestPressureThreadId = _bestThreadIdForPrimaryPressure(
      preferredThreadId: resolvedFallbackThreadId,
    );
    if (highestPressureThreadId != null) {
      final highestPressureThread = _threadById(highestPressureThreadId);
      final highestPressureScore = highestPressureThread == null
          ? 0
          : _threadPrimaryPressureSortScore(highestPressureThread);
      if (highestPressureScore > fallbackScore) {
        return highestPressureThreadId;
      }
    }
    return resolvedFallbackThreadId;
  }

  bool _shouldSuppressRestoredStaleFollowUp({
    required String fallbackSelectedThreadId,
    required String resolvedSelectedThreadId,
  }) {
    if (resolvedSelectedThreadId == fallbackSelectedThreadId) {
      return false;
    }
    final operatorSelectedThreadId = _selectedThreadOperatorId?.trim();
    final restoredOperatorSelection =
        operatorSelectedThreadId != null &&
        operatorSelectedThreadId.isNotEmpty &&
        _selectedThreadOperatorAt != null &&
        resolvedSelectedThreadId == operatorSelectedThreadId;
    return !restoredOperatorSelection;
  }

  void _applyRestoredPressureFocusNote({
    required String fallbackSelectedThreadId,
    required String resolvedSelectedThreadId,
  }) {
    _restoredPressureFocusThreadId = null;
    _restoredPressureFocusFallbackThreadTitle = null;
    _restoredPressureFocusLabel = null;
    if (resolvedSelectedThreadId == fallbackSelectedThreadId) {
      return;
    }
    if (_selectedThreadOperatorId?.trim().isNotEmpty == true &&
        _selectedThreadOperatorAt != null) {
      return;
    }
    if (_bestThreadIdForPrioritizedMaintenance() != null) {
      return;
    }
    final resolvedThread = _threadById(resolvedSelectedThreadId);
    final fallbackThread = _threadById(fallbackSelectedThreadId);
    if (resolvedThread == null || fallbackThread == null) {
      return;
    }
    final resolvedCategory = _threadMemoryPrimaryPressureCategory(
      resolvedThread.memory,
    );
    final fallbackScore = _threadPrimaryPressureSortScore(fallbackThread);
    final resolvedScore = _threadPrimaryPressureSortScore(resolvedThread);
    final resolvedLabel = resolvedCategory == null
        ? null
        : _primaryPressureLabelForCategory(resolvedCategory);
    if (resolvedLabel == null ||
        resolvedLabel.isEmpty ||
        resolvedScore <= fallbackScore) {
      return;
    }
    _restoredPressureFocusThreadId = resolvedSelectedThreadId;
    _restoredPressureFocusFallbackThreadTitle = fallbackThread.title;
    _restoredPressureFocusLabel = resolvedLabel;
  }

  _AgentThread? _threadById(String threadId) {
    for (final thread in _threads) {
      if (thread.id == threadId) {
        return thread;
      }
    }
    return null;
  }

  String? _bestThreadIdForPrimaryPressure({String preferredThreadId = ''}) {
    _AgentThread? bestThread;
    var bestScore = 0;
    for (final thread in _threads) {
      final score = _threadPrimaryPressureSortScore(thread);
      if (score > bestScore) {
        bestScore = score;
        bestThread = thread;
        continue;
      }
      if (score == bestScore && score > 0 && thread.id == preferredThreadId) {
        bestThread = thread;
      }
    }
    if (bestThread == null || bestScore <= 0) {
      return null;
    }
    return bestThread.id;
  }

  bool _threadHasOperatorFocus(String threadId) {
    return _selectedThreadOperatorAt != null &&
        _selectedThreadOperatorId == threadId;
  }

  String? _threadOperatorFocusNote(
    String threadId,
    _PlannerConflictReport plannerConflictReport,
  ) {
    if (!_threadHasOperatorFocus(threadId)) {
      return null;
    }
    final urgentThreadId = _bestThreadIdForPrioritizedMaintenanceFromReport(
      plannerConflictReport,
    );
    if (urgentThreadId != null && urgentThreadId != threadId) {
      return 'Manual context preserved over urgent review.';
    }
    return 'Manual operator context is active on this thread.';
  }

  bool _threadHasRestoredPressureFocus(
    String threadId,
    _PlannerConflictReport plannerConflictReport,
  ) {
    if (_restoredPressureFocusThreadId != threadId) {
      return false;
    }
    if (_threadHasOperatorFocus(threadId)) {
      return false;
    }
    if (_bestThreadIdForPrioritizedMaintenanceFromReport(
          plannerConflictReport,
        ) !=
        null) {
      return false;
    }
    return (_restoredPressureFocusLabel ?? '').trim().isNotEmpty;
  }

  String? _threadPressureFocusNote(String threadId) {
    if (_restoredPressureFocusThreadId != threadId) {
      return null;
    }
    final pressureLabel = _restoredPressureFocusLabel?.trim();
    if (pressureLabel == null || pressureLabel.isEmpty) {
      return null;
    }
    final fallbackTitle = _restoredPressureFocusFallbackThreadTitle?.trim();
    if (fallbackTitle == null || fallbackTitle.isEmpty) {
      return 'Restored from saved pressure because $pressureLabel was strongest.';
    }
    return 'Restored over $fallbackTitle because $pressureLabel was stronger.';
  }

  String _operatorFocusBannerBody({
    required String threadId,
    required _PlannerConflictReport plannerConflictReport,
  }) {
    final urgentThreadId = _bestThreadIdForPrioritizedMaintenanceFromReport(
      plannerConflictReport,
    );
    if (urgentThreadId != null && urgentThreadId != threadId) {
      final urgentThreadTitle = _threadTitleForId(urgentThreadId);
      if (urgentThreadTitle != null && urgentThreadTitle.isNotEmpty) {
        return 'Manual operator context is active here. ONYX kept focus on this thread while urgent review stays visible on $urgentThreadTitle.';
      }
      return 'Manual operator context is active here. ONYX kept focus on this thread while urgent review stays visible in the rail.';
    }
    return 'Manual operator context is active here. ONYX will keep this thread selected until you move to a different conversation.';
  }

  String? _bestThreadIdForPrioritizedMaintenance() {
    return _bestThreadIdForPrioritizedMaintenanceFromReport(
      _plannerConflictReport(),
    );
  }

  String? _bestThreadIdForPrioritizedMaintenanceFromReport(
    _PlannerConflictReport plannerConflictReport,
  ) {
    final prioritizedAlerts = plannerConflictReport.maintenanceAlerts
        .where((alert) => alert.reviewPrioritized)
        .toList(growable: false);
    for (final alert in prioritizedAlerts) {
      final threadId = _bestThreadIdForPlannerSignal(alert.signalId);
      if (threadId != null) {
        return threadId;
      }
    }
    return null;
  }

  String? _threadTitleForId(String threadId) {
    for (final thread in _threads) {
      if (thread.id == threadId) {
        return thread.title;
      }
    }
    return null;
  }

  int _threadUrgentMaintenanceScore(
    _AgentThread thread,
    _PlannerConflictReport plannerConflictReport,
  ) {
    final urgentAlerts = plannerConflictReport.maintenanceAlerts
        .where((alert) => alert.reviewPrioritized)
        .toList(growable: false);
    if (urgentAlerts.isEmpty) {
      return 0;
    }
    var bestScore = 0;
    for (final alert in urgentAlerts) {
      final score = _threadPlannerSignalScore(thread, alert.signalId);
      if (score > bestScore) {
        bestScore = score;
      }
    }
    return bestScore;
  }

  String? _threadUrgentMaintenanceReason(
    _AgentThread thread,
    _PlannerConflictReport plannerConflictReport,
  ) {
    final matchedAlert = _threadUrgentMaintenanceAlert(
      thread,
      plannerConflictReport,
    );
    if (matchedAlert == null) {
      return null;
    }
    final parts = <String>[
      _plannerInlineRuleLabel(matchedAlert.label),
      _plannerReactivationSeverityLabel(matchedAlert.reactivationCount),
    ];
    if (matchedAlert.staleAgainCount > 0) {
      parts.add(
        matchedAlert.staleAgainCount == 1
            ? 'review reopened 1 time'
            : 'review reopened ${matchedAlert.staleAgainCount} times',
      );
    } else if (matchedAlert.reviewPrioritized) {
      parts.add('urgent review active');
    } else if (matchedAlert.reviewQueued) {
      parts.add('rule review queued');
    }
    return parts.join(' • ');
  }

  _PlannerMaintenanceAlertEntry? _threadUrgentMaintenanceAlert(
    _AgentThread thread,
    _PlannerConflictReport plannerConflictReport,
  ) {
    final prioritizedAlerts = plannerConflictReport.maintenanceAlerts
        .where((alert) => alert.reviewPrioritized)
        .toList(growable: false);
    _PlannerMaintenanceAlertEntry? matchedAlert;
    var bestScore = 0;
    for (final alert in prioritizedAlerts) {
      final score = _threadPlannerSignalScore(thread, alert.signalId);
      if (score > bestScore) {
        bestScore = score;
        matchedAlert = alert;
      }
    }
    if (matchedAlert == null || bestScore <= 0) {
      return null;
    }
    return matchedAlert;
  }

  void _focusPlannerMaintenanceAlertForThread(
    String threadId,
    _PlannerConflictReport plannerConflictReport,
  ) {
    final thread = _threads.firstWhere(
      (candidate) => candidate.id == threadId,
      orElse: () => _selectedThread,
    );
    final matchedAlert = _threadUrgentMaintenanceAlert(
      thread,
      plannerConflictReport,
    );
    if (matchedAlert == null) {
      return;
    }
    _focusPlannerMaintenanceAlertBySignal(
      matchedAlert.signalId,
      threadId: threadId,
      selectThread: true,
      explicitOperatorSelection: false,
      contextLabel: buildPlannerFocusContextLabel(
        OnyxPlannerFocusContext.threadRail,
      ),
    );
  }

  void _focusPlannerMaintenanceAlertBySignal(
    String signalId, {
    String? threadId,
    bool selectThread = false,
    bool explicitOperatorSelection = false,
    required String contextLabel,
  }) {
    final targetThreadId = threadId ?? _bestThreadIdForPlannerSignal(signalId);
    if (selectThread && targetThreadId != null) {
      if (explicitOperatorSelection) {
        _selectThread(
          targetThreadId,
          surfaceStaleFollowUp: false,
          clearPlannerFocus: false,
          explicitOperatorSelection: true,
        );
      } else {
        _selectThreadForPlannerHandoff(
          targetThreadId,
          clearPlannerFocus: false,
        );
      }
    }
    setState(() {
      _focusedPlannerSignalId = signalId;
      _focusedPlannerSectionId = null;
      _focusedPlannerBacklogSignalId = null;
      _focusedPlannerArchivedSignalId = null;
      _focusedPlannerReactivationSignalId = null;
      _focusedPlannerSignalContextLabel = contextLabel;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final context = _plannerMaintenanceAlertAnchorKey(
        signalId,
      ).currentContext;
      if (context == null) {
        return;
      }
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: 0.06,
      );
    });
  }

  void _focusPlannerReportSection(
    String sectionId, {
    required String contextLabel,
  }) {
    setState(() {
      _focusedPlannerSignalId = null;
      _focusedPlannerSectionId = sectionId;
      _focusedPlannerBacklogSignalId = null;
      _focusedPlannerArchivedSignalId = null;
      _focusedPlannerReactivationSignalId = null;
      _focusedPlannerSignalContextLabel = contextLabel;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final context = _plannerReportSectionAnchorKey(sectionId).currentContext;
      if (context == null) {
        return;
      }
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: 0.06,
      );
    });
  }

  void _focusPlannerBacklogEntryBySignal(
    String signalId, {
    required String contextLabel,
  }) {
    setState(() {
      _focusedPlannerSignalId = null;
      _focusedPlannerSectionId = null;
      _focusedPlannerBacklogSignalId = signalId;
      _focusedPlannerArchivedSignalId = null;
      _focusedPlannerReactivationSignalId = null;
      _focusedPlannerSignalContextLabel = contextLabel;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final context = _plannerBacklogEntryAnchorKey(signalId).currentContext;
      if (context == null) {
        return;
      }
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: 0.06,
      );
    });
  }

  void _focusPlannerArchivedEntryBySignal(
    String signalId, {
    required String contextLabel,
  }) {
    setState(() {
      _focusedPlannerSignalId = null;
      _focusedPlannerSectionId = null;
      _focusedPlannerBacklogSignalId = null;
      _focusedPlannerArchivedSignalId = signalId;
      _focusedPlannerReactivationSignalId = null;
      _focusedPlannerSignalContextLabel = contextLabel;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final context = _plannerArchivedEntryAnchorKey(signalId).currentContext;
      if (context == null) {
        return;
      }
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: 0.06,
      );
    });
  }

  void _focusPlannerReactivationEntryBySignal(
    String signalId, {
    required String contextLabel,
  }) {
    setState(() {
      _focusedPlannerSignalId = null;
      _focusedPlannerSectionId = null;
      _focusedPlannerBacklogSignalId = null;
      _focusedPlannerArchivedSignalId = null;
      _focusedPlannerReactivationSignalId = signalId;
      _focusedPlannerSignalContextLabel = contextLabel;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final context = _plannerReactivationEntryAnchorKey(
        signalId,
      ).currentContext;
      if (context == null) {
        return;
      }
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: 0.06,
      );
    });
  }

  bool _plannerHasNavigableRuleForSignal(
    _PlannerConflictReport report,
    String signalId,
  ) {
    return report.maintenanceAlerts.any(
          (alert) => alert.signalId == signalId,
        ) ||
        report.backlogEntries.any((entry) => entry.signalId == signalId) ||
        report.archivedEntries.any((entry) => entry.signalId == signalId);
  }

  void _focusPlannerRuleForSignal(
    _PlannerConflictReport report,
    String signalId, {
    required String contextLabel,
  }) {
    if (report.maintenanceAlerts.any((alert) => alert.signalId == signalId)) {
      _focusPlannerMaintenanceAlertBySignal(
        signalId,
        contextLabel: contextLabel,
      );
      return;
    }
    if (report.backlogEntries.any((entry) => entry.signalId == signalId)) {
      _focusPlannerBacklogEntryBySignal(signalId, contextLabel: contextLabel);
      return;
    }
    if (report.archivedEntries.any((entry) => entry.signalId == signalId)) {
      _focusPlannerArchivedEntryBySignal(signalId, contextLabel: contextLabel);
    }
  }

  void _focusPlannerArchivedBucket(
    _PlannerConflictReport report, {
    required String contextLabel,
  }) {
    if (report.archivedEntries.isEmpty) {
      return;
    }
    if (report.archivedEntries.length == 1) {
      _focusPlannerArchivedEntryBySignal(
        report.archivedEntries.first.signalId,
        contextLabel: contextLabel,
      );
      return;
    }
    _focusPlannerReportSection('archived-rules', contextLabel: contextLabel);
  }

  String? _bestThreadIdForPlannerSignal(String signalId) {
    String? bestThreadId;
    var bestScore = 0;
    for (final thread in _threads) {
      final score = _threadPlannerSignalScore(thread, signalId);
      if (score > bestScore) {
        bestScore = score;
        bestThreadId = thread.id;
      }
    }
    if (bestScore <= 0) {
      return null;
    }
    return bestThreadId;
  }

  Map<String, int> _plannerPreviousSignalCountsForReport(
    _PlannerConflictReport report,
  ) {
    return _sameStringIntMap(
          report.currentSignalCounts,
          _plannerSignalSnapshot.signalCounts,
        )
        ? _previousPlannerSignalSnapshot.signalCounts
        : _plannerSignalSnapshot.signalCounts;
  }

  String? _plannerSignalIdForTrendMessage(
    _PlannerConflictReport report,
    String message,
  ) {
    final previousSignalCounts = _plannerPreviousSignalCountsForReport(report);
    final signalIds =
        <String>{
          ...previousSignalCounts.keys,
          ...report.currentSignalCounts.keys,
        }.toList(growable: false)..sort((left, right) {
          final leftScore =
              report.currentSignalCounts[left] ??
              previousSignalCounts[left] ??
              0;
          final rightScore =
              report.currentSignalCounts[right] ??
              previousSignalCounts[right] ??
              0;
          final byCount = rightScore.compareTo(leftScore);
          if (byCount != 0) {
            return byCount;
          }
          return left.compareTo(right);
        });
    for (final signalId in signalIds) {
      final candidate = _plannerTrendMessageForSignal(
        signalId: signalId,
        currentCount: report.currentSignalCounts[signalId] ?? 0,
        previousCount: previousSignalCounts[signalId] ?? 0,
      );
      if (candidate == message) {
        return signalId;
      }
    }
    return null;
  }

  String? _plannerSignalIdForTuningSuggestionMessage(
    _PlannerConflictReport report,
    String message,
  ) {
    final previousSignalCounts = _plannerPreviousSignalCountsForReport(report);
    final signalIds = report.currentSignalCounts.keys.toList(growable: false)
      ..sort((left, right) {
        final leftScore = report.currentSignalCounts[left] ?? 0;
        final rightScore = report.currentSignalCounts[right] ?? 0;
        final byCount = rightScore.compareTo(leftScore);
        if (byCount != 0) {
          return byCount;
        }
        return left.compareTo(right);
      });
    for (final signalId in signalIds) {
      final candidate = _plannerTuningSuggestionForSignal(
        signalId: signalId,
        currentCount: report.currentSignalCounts[signalId] ?? 0,
        previousCount: previousSignalCounts[signalId] ?? 0,
      );
      if (candidate == message) {
        return signalId;
      }
    }
    return null;
  }

  void _markOperatorSelectedThread(String threadId) {
    if (!_threads.any((thread) => thread.id == threadId)) {
      return;
    }
    _selectedThreadOperatorId = threadId;
    _selectedThreadOperatorAt = DateTime.now();
  }

  int _threadPlannerSignalScore(_AgentThread thread, String signalId) {
    final memory = thread.memory;
    if (signalId == 'route-closed-safety') {
      return memory.secondLookRouteClosedConflictCount;
    }
    final parts = signalId.split(':');
    if (parts.length != 3 || parts.first != 'drift') {
      return 0;
    }
    final modelTarget = _toolTargetFromName(parts[1]);
    final typedTarget = parts[2] == 'none'
        ? null
        : _toolTargetFromName(parts[2]);
    if (modelTarget == null) {
      return 0;
    }
    final modelCount = memory.secondLookModelTargetCounts[modelTarget] ?? 0;
    if (modelCount <= 0) {
      return 0;
    }
    if (typedTarget == null) {
      return modelCount;
    }
    final typedCount = memory.secondLookTypedTargetCounts[typedTarget] ?? 0;
    if (typedCount <= 0) {
      return 0;
    }
    return modelCount + typedCount;
  }

  List<_PlannerConflictTargetCount> _sortedTargetCountList(
    Map<OnyxToolTarget, int> counts,
  ) {
    final entries = counts.entries
        .where((entry) => entry.value > 0)
        .map(
          (entry) => _PlannerConflictTargetCount(
            target: entry.key,
            count: entry.value,
          ),
        )
        .toList(growable: false);
    entries.sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      if (byCount != 0) {
        return byCount;
      }
      return a.target.index.compareTo(b.target.index);
    });
    return entries;
  }

  void _mergeTargetCountMapInto({
    required Map<OnyxToolTarget, int> destination,
    required Map<OnyxToolTarget, int> source,
  }) {
    for (final entry in source.entries) {
      destination[entry.key] = (destination[entry.key] ?? 0) + entry.value;
    }
  }

  Map<OnyxToolTarget, int> _incrementTargetCount(
    Map<OnyxToolTarget, int> current,
    OnyxToolTarget? target,
  ) {
    if (target == null) {
      return Map<OnyxToolTarget, int>.from(current);
    }
    return Map<OnyxToolTarget, int>.from(current)
      ..update(target, (value) => value + 1, ifAbsent: () => 1);
  }

  Map<String, int> _plannerSignalCountMap({
    required List<_PlannerConflictTargetCount> modelTargetCounts,
    required List<_PlannerConflictTargetCount> typedTargetCounts,
    required int routeClosedConflictCount,
  }) {
    final signals = <String, int>{};
    final topModelTarget = modelTargetCounts.isEmpty
        ? null
        : modelTargetCounts.first;
    final topTypedTarget = typedTargetCounts.isEmpty
        ? null
        : typedTargetCounts.first;
    if (topModelTarget != null && topModelTarget.count >= 2) {
      signals[_plannerSignalIdForTargetPair(
            modelTarget: topModelTarget.target,
            typedTarget: topTypedTarget?.target,
          )] =
          topModelTarget.count;
    }
    if (routeClosedConflictCount >= 2) {
      signals['route-closed-safety'] = routeClosedConflictCount;
    }
    return signals;
  }

  Map<String, int> _seedPlannerBacklogScores({
    required Map<String, int> currentSignalCounts,
    required Map<String, int> previousSignalCounts,
  }) {
    final seeded = <String, int>{};
    for (final signalId in currentSignalCounts.keys) {
      final suggestion = _plannerTuningSuggestionForSignal(
        signalId: signalId,
        currentCount: currentSignalCounts[signalId] ?? 0,
        previousCount: previousSignalCounts[signalId] ?? 0,
      );
      if (suggestion.trim().isEmpty) {
        continue;
      }
      seeded[signalId] = 1;
    }
    return seeded;
  }

  void _synchronizePlannerSignalSnapshots({
    required List<_AgentThread> threads,
    bool baseline = false,
  }) {
    _cachedPlannerConflictReport = null;
    final metrics = _plannerConflictMetricsForThreads(threads);
    final nextSnapshot = _PlannerSignalSnapshot(
      signalCounts: _plannerSignalCountMap(
        modelTargetCounts: metrics.modelTargetCounts,
        typedTargetCounts: metrics.typedTargetCounts,
        routeClosedConflictCount: metrics.routeClosedConflictCount,
      ),
      capturedAt: DateTime.now(),
    );
    final previousSignalCounts = baseline
        ? nextSnapshot.signalCounts
        : _plannerSignalSnapshot.signalCounts;
    final nextArchivedSignalCounts = Map<String, int>.from(
      _plannerBacklogArchivedSignalCounts,
    );
    final nextReactivatedSignalCounts = Map<String, int>.from(
      _plannerBacklogReactivatedSignalCounts,
    );
    final nextReactivationCounts = Map<String, int>.from(
      _plannerBacklogReactivationCounts,
    );
    final nextLastReactivatedAt = Map<String, DateTime>.from(
      _plannerBacklogLastReactivatedAt,
    );
    final nextMaintenanceReviewQueuedAt = Map<String, DateTime>.from(
      _plannerMaintenanceReviewQueuedAt,
    );
    final nextMaintenanceReviewCompletedAt = Map<String, DateTime>.from(
      _plannerMaintenanceReviewCompletedAt,
    );
    final nextMaintenanceReviewPrioritizedAt = Map<String, DateTime>.from(
      _plannerMaintenanceReviewPrioritizedAt,
    );
    final nextMaintenanceReviewReopenedCounts = Map<String, int>.from(
      _plannerMaintenanceReviewReopenedCounts,
    );
    final nextMaintenanceReviewCompletedSignalCounts = Map<String, int>.from(
      _plannerMaintenanceReviewCompletedSignalCounts,
    );
    final nextMaintenanceReviewCompletedReactivationCounts =
        Map<String, int>.from(
          _plannerMaintenanceReviewCompletedReactivationCounts,
        );
    for (final signalId in nextReactivatedSignalCounts.keys.toList()) {
      if (!nextSnapshot.signalCounts.containsKey(signalId) &&
          !nextArchivedSignalCounts.containsKey(signalId)) {
        nextReactivatedSignalCounts.remove(signalId);
      }
    }
    for (final entry in _plannerBacklogArchivedSignalCounts.entries) {
      final currentCount = nextSnapshot.signalCounts[entry.key] ?? 0;
      if (currentCount > entry.value) {
        nextArchivedSignalCounts.remove(entry.key);
        if (!nextReactivatedSignalCounts.containsKey(entry.key)) {
          nextReactivationCounts[entry.key] =
              (nextReactivationCounts[entry.key] ?? 0) + 1;
          nextLastReactivatedAt[entry.key] = DateTime.now();
        }
        nextReactivatedSignalCounts[entry.key] = entry.value;
      }
    }
    final suppressedArchivedSignalIds = nextArchivedSignalCounts.entries
        .where(
          (entry) => (nextSnapshot.signalCounts[entry.key] ?? 0) <= entry.value,
        )
        .map((entry) => entry.key)
        .toSet();
    nextMaintenanceReviewQueuedAt.removeWhere(
      (signalId, _) =>
          !nextSnapshot.signalCounts.containsKey(signalId) &&
          !nextArchivedSignalCounts.containsKey(signalId),
    );
    nextMaintenanceReviewCompletedAt.removeWhere(
      (signalId, _) =>
          !nextSnapshot.signalCounts.containsKey(signalId) &&
          !nextArchivedSignalCounts.containsKey(signalId),
    );
    nextMaintenanceReviewPrioritizedAt.removeWhere(
      (signalId, _) =>
          !nextSnapshot.signalCounts.containsKey(signalId) &&
          !nextArchivedSignalCounts.containsKey(signalId),
    );
    nextMaintenanceReviewReopenedCounts.removeWhere(
      (signalId, _) =>
          !nextSnapshot.signalCounts.containsKey(signalId) &&
          !nextArchivedSignalCounts.containsKey(signalId),
    );
    nextMaintenanceReviewCompletedSignalCounts.removeWhere(
      (signalId, _) =>
          !nextSnapshot.signalCounts.containsKey(signalId) &&
          !nextArchivedSignalCounts.containsKey(signalId),
    );
    nextMaintenanceReviewCompletedReactivationCounts.removeWhere(
      (signalId, _) =>
          !nextSnapshot.signalCounts.containsKey(signalId) &&
          !nextArchivedSignalCounts.containsKey(signalId),
    );
    for (final signalId in nextSnapshot.signalCounts.keys) {
      if (_plannerMaintenanceReviewShouldAutoReopen(
        signalId: signalId,
        currentSignalCount: nextSnapshot.signalCounts[signalId] ?? 0,
        currentReactivationCount: nextReactivationCounts[signalId] ?? 0,
        queuedAt: nextMaintenanceReviewQueuedAt[signalId],
        completedAt: nextMaintenanceReviewCompletedAt[signalId],
        completedSignalCount:
            nextMaintenanceReviewCompletedSignalCounts[signalId],
        completedReactivationCount:
            nextMaintenanceReviewCompletedReactivationCounts[signalId],
      )) {
        nextMaintenanceReviewQueuedAt[signalId] = DateTime.now();
        nextMaintenanceReviewReopenedCounts[signalId] =
            (nextMaintenanceReviewReopenedCounts[signalId] ?? 0) + 1;
      }
    }
    final nextBacklogScores = Map<String, int>.from(_plannerBacklogScores);
    for (final signalId in nextSnapshot.signalCounts.keys) {
      if (suppressedArchivedSignalIds.contains(signalId)) {
        continue;
      }
      if (_plannerBacklogReviewStatuses.containsKey(signalId)) {
        nextBacklogScores.putIfAbsent(signalId, () => 1);
        continue;
      }
      final suggestion = _plannerTuningSuggestionForSignal(
        signalId: signalId,
        currentCount: nextSnapshot.signalCounts[signalId] ?? 0,
        previousCount: previousSignalCounts[signalId] ?? 0,
      );
      if (suggestion.trim().isEmpty) {
        continue;
      }
      if (baseline) {
        nextBacklogScores.putIfAbsent(signalId, () => 1);
        continue;
      }
      if (_sameStringIntMap(
        nextSnapshot.signalCounts,
        _plannerSignalSnapshot.signalCounts,
      )) {
        nextBacklogScores.putIfAbsent(signalId, () => 1);
        continue;
      }
      nextBacklogScores[signalId] = (nextBacklogScores[signalId] ?? 0) + 1;
    }
    if (baseline) {
      _plannerSignalSnapshot = nextSnapshot;
      _previousPlannerSignalSnapshot = nextSnapshot;
      _plannerBacklogScores = nextBacklogScores;
      _plannerBacklogArchivedSignalCounts = nextArchivedSignalCounts;
      _plannerBacklogReactivatedSignalCounts = nextReactivatedSignalCounts;
      _plannerBacklogReactivationCounts = nextReactivationCounts;
      _plannerBacklogLastReactivatedAt = nextLastReactivatedAt;
      _plannerMaintenanceReviewQueuedAt = nextMaintenanceReviewQueuedAt;
      _plannerMaintenanceReviewCompletedAt = nextMaintenanceReviewCompletedAt;
      _plannerMaintenanceReviewPrioritizedAt =
          nextMaintenanceReviewPrioritizedAt;
      _plannerMaintenanceReviewReopenedCounts =
          nextMaintenanceReviewReopenedCounts;
      _plannerMaintenanceReviewCompletedSignalCounts =
          nextMaintenanceReviewCompletedSignalCounts;
      _plannerMaintenanceReviewCompletedReactivationCounts =
          nextMaintenanceReviewCompletedReactivationCounts;
      return;
    }
    if (_sameStringIntMap(
      nextSnapshot.signalCounts,
      _plannerSignalSnapshot.signalCounts,
    )) {
      if (!_sameStringIntMap(
        _previousPlannerSignalSnapshot.signalCounts,
        nextSnapshot.signalCounts,
      )) {
        _previousPlannerSignalSnapshot = _plannerSignalSnapshot;
      }
      _plannerBacklogScores = nextBacklogScores;
      _plannerBacklogArchivedSignalCounts = nextArchivedSignalCounts;
      _plannerBacklogReactivatedSignalCounts = nextReactivatedSignalCounts;
      _plannerBacklogReactivationCounts = nextReactivationCounts;
      _plannerBacklogLastReactivatedAt = nextLastReactivatedAt;
      _plannerMaintenanceReviewQueuedAt = nextMaintenanceReviewQueuedAt;
      _plannerMaintenanceReviewCompletedAt = nextMaintenanceReviewCompletedAt;
      _plannerMaintenanceReviewPrioritizedAt =
          nextMaintenanceReviewPrioritizedAt;
      _plannerMaintenanceReviewReopenedCounts =
          nextMaintenanceReviewReopenedCounts;
      _plannerMaintenanceReviewCompletedSignalCounts =
          nextMaintenanceReviewCompletedSignalCounts;
      _plannerMaintenanceReviewCompletedReactivationCounts =
          nextMaintenanceReviewCompletedReactivationCounts;
      return;
    }
    _previousPlannerSignalSnapshot = _plannerSignalSnapshot;
    _plannerSignalSnapshot = nextSnapshot;
    _plannerBacklogScores = nextBacklogScores;
    _plannerBacklogArchivedSignalCounts = nextArchivedSignalCounts;
    _plannerBacklogReactivatedSignalCounts = nextReactivatedSignalCounts;
    _plannerBacklogReactivationCounts = nextReactivationCounts;
    _plannerBacklogLastReactivatedAt = nextLastReactivatedAt;
    _plannerMaintenanceReviewQueuedAt = nextMaintenanceReviewQueuedAt;
    _plannerMaintenanceReviewCompletedAt = nextMaintenanceReviewCompletedAt;
    _plannerMaintenanceReviewPrioritizedAt = nextMaintenanceReviewPrioritizedAt;
    _plannerMaintenanceReviewReopenedCounts =
        nextMaintenanceReviewReopenedCounts;
    _plannerMaintenanceReviewCompletedSignalCounts =
        nextMaintenanceReviewCompletedSignalCounts;
    _plannerMaintenanceReviewCompletedReactivationCounts =
        nextMaintenanceReviewCompletedReactivationCounts;
  }

  bool _plannerMaintenanceReviewShouldAutoReopen({
    required String signalId,
    required int currentSignalCount,
    required int currentReactivationCount,
    required DateTime? queuedAt,
    required DateTime? completedAt,
    required int? completedSignalCount,
    required int? completedReactivationCount,
  }) {
    if (completedAt == null) {
      return false;
    }
    if (queuedAt != null && queuedAt.isAfter(completedAt)) {
      return false;
    }
    if (_plannerReactivationSeverityLabel(currentReactivationCount) !=
        'chronic drift') {
      return false;
    }
    if (completedSignalCount == null || completedReactivationCount == null) {
      return false;
    }
    return currentSignalCount > completedSignalCount ||
        currentReactivationCount > completedReactivationCount;
  }

  List<String> _plannerTuningSignals({
    required Map<String, int> currentSignalCounts,
    required Map<String, int> previousSignalCounts,
  }) {
    final signalIds =
        <String>{
          ...previousSignalCounts.keys,
          ...currentSignalCounts.keys,
        }.toList(growable: false)..sort((left, right) {
          final leftScore =
              currentSignalCounts[left] ?? previousSignalCounts[left] ?? 0;
          final rightScore =
              currentSignalCounts[right] ?? previousSignalCounts[right] ?? 0;
          final byCount = rightScore.compareTo(leftScore);
          if (byCount != 0) {
            return byCount;
          }
          return left.compareTo(right);
        });
    return signalIds
        .map(
          (signalId) => _plannerTrendMessageForSignal(
            signalId: signalId,
            currentCount: currentSignalCounts[signalId] ?? 0,
            previousCount: previousSignalCounts[signalId] ?? 0,
          ),
        )
        .where((signal) => signal.trim().isNotEmpty)
        .toList(growable: false);
  }

  List<String> _plannerTuningSuggestions({
    required Map<String, int> currentSignalCounts,
    required Map<String, int> previousSignalCounts,
    required Map<String, _PlannerBacklogReviewStatus> reviewStatuses,
    required Set<String> suppressedArchivedSignalIds,
  }) {
    final signalIds = currentSignalCounts.keys.toList(growable: false)
      ..sort((left, right) {
        final leftScore = currentSignalCounts[left] ?? 0;
        final rightScore = currentSignalCounts[right] ?? 0;
        final byCount = rightScore.compareTo(leftScore);
        if (byCount != 0) {
          return byCount;
        }
        return left.compareTo(right);
      });
    return signalIds
        .map(
          (signalId) =>
              reviewStatuses.containsKey(signalId) ||
                  suppressedArchivedSignalIds.contains(signalId)
              ? ''
              : _plannerTuningSuggestionForSignal(
                  signalId: signalId,
                  currentCount: currentSignalCounts[signalId] ?? 0,
                  previousCount: previousSignalCounts[signalId] ?? 0,
                ),
        )
        .where((signal) => signal.trim().isNotEmpty)
        .toList(growable: false);
  }

  List<_PlannerBacklogEntry> _plannerBacklogEntries({
    required Map<String, int> backlogScores,
    required Set<String> activeSignalIds,
    required Map<String, _PlannerBacklogReviewStatus> reviewStatuses,
    required Set<String> suppressedArchivedSignalIds,
  }) {
    final entries = backlogScores.entries
        .where(
          (entry) =>
              entry.value > 0 &&
              !suppressedArchivedSignalIds.contains(entry.key),
        )
        .map(
          (entry) => _PlannerBacklogEntry(
            signalId: entry.key,
            label: _plannerTuningSuggestionForSignalId(entry.key),
            score: entry.value,
            active: activeSignalIds.contains(entry.key),
            reviewStatus: reviewStatuses[entry.key],
          ),
        )
        .where((entry) => entry.label.trim().isNotEmpty)
        .toList(growable: false);
    entries.sort((left, right) {
      final byActive = right.active == left.active
          ? 0
          : (right.active ? 1 : -1);
      if (byActive != 0) {
        return byActive;
      }
      final byStatus = _plannerBacklogReviewStatusSortValue(
        left.reviewStatus,
      ).compareTo(_plannerBacklogReviewStatusSortValue(right.reviewStatus));
      if (byStatus != 0) {
        return byStatus;
      }
      final byScore = right.score.compareTo(left.score);
      if (byScore != 0) {
        return byScore;
      }
      return left.label.compareTo(right.label);
    });
    return entries;
  }

  Set<String> _suppressedArchivedPlannerSignalIds(
    Map<String, int> currentSignalCounts,
  ) {
    final suppressed = <String>{};
    for (final entry in _plannerBacklogArchivedSignalCounts.entries) {
      final currentCount = currentSignalCounts[entry.key] ?? 0;
      if (currentCount <= entry.value) {
        suppressed.add(entry.key);
      }
    }
    return suppressed;
  }

  List<_PlannerArchivedEntry> _plannerArchivedEntries({
    required Set<String> suppressedArchivedSignalIds,
    required Map<String, int> currentSignalCounts,
  }) {
    final entries = suppressedArchivedSignalIds
        .map((signalId) {
          final label = _plannerTuningSuggestionForSignalId(signalId);
          if (label.trim().isEmpty) {
            return null;
          }
          return _PlannerArchivedEntry(
            signalId: signalId,
            label: label,
            archivedAtCount: _plannerBacklogArchivedSignalCounts[signalId] ?? 0,
            currentCount: currentSignalCounts[signalId] ?? 0,
          );
        })
        .whereType<_PlannerArchivedEntry>()
        .toList(growable: false);
    entries.sort((left, right) {
      final byArchived = right.archivedAtCount.compareTo(left.archivedAtCount);
      if (byArchived != 0) {
        return byArchived;
      }
      final byCurrent = right.currentCount.compareTo(left.currentCount);
      if (byCurrent != 0) {
        return byCurrent;
      }
      return left.label.compareTo(right.label);
    });
    return entries;
  }

  List<_PlannerReactivationEntry> _plannerReactivationEntries({
    required Map<String, int> currentSignalCounts,
  }) {
    final entries = _plannerBacklogReactivatedSignalCounts.entries
        .map((entry) {
          final currentCount = currentSignalCounts[entry.key] ?? 0;
          if (currentCount <= entry.value) {
            return null;
          }
          final label = _plannerTuningSuggestionForSignalId(entry.key);
          if (label.trim().isEmpty) {
            return null;
          }
          return _PlannerReactivationEntry(
            signalId: entry.key,
            label: label,
            archivedAtCount: entry.value,
            currentCount: currentCount,
            reactivationCount:
                _plannerBacklogReactivationCounts[entry.key] ?? 1,
            lastReactivatedAt: _plannerBacklogLastReactivatedAt[entry.key],
          );
        })
        .whereType<_PlannerReactivationEntry>()
        .toList(growable: false);
    entries.sort((left, right) {
      final bySeverity =
          _plannerReactivationSeveritySortValue(
            right.reactivationCount,
          ).compareTo(
            _plannerReactivationSeveritySortValue(left.reactivationCount),
          );
      if (bySeverity != 0) {
        return bySeverity;
      }
      final byReactivationCount = right.reactivationCount.compareTo(
        left.reactivationCount,
      );
      if (byReactivationCount != 0) {
        return byReactivationCount;
      }
      final byCurrent = right.currentCount.compareTo(left.currentCount);
      if (byCurrent != 0) {
        return byCurrent;
      }
      final byArchived = right.archivedAtCount.compareTo(left.archivedAtCount);
      if (byArchived != 0) {
        return byArchived;
      }
      return left.label.compareTo(right.label);
    });
    return entries;
  }

  int _plannerReactivationSeveritySortValue(int reactivationCount) {
    if (reactivationCount >= 4) {
      return 3;
    }
    if (reactivationCount >= 2) {
      return 2;
    }
    return 1;
  }

  String _plannerReactivationSeverityLabel(int reactivationCount) {
    if (reactivationCount >= 4) {
      return 'chronic drift';
    }
    if (reactivationCount >= 2) {
      return 'flapping';
    }
    return 'returned once';
  }

  List<String> _plannerOperatorNotes(_PlannerConflictReport report) {
    return report.tuningSignals.take(2).toList(growable: false);
  }

  List<String> _plannerOperatorAdjustments(_PlannerConflictReport report) {
    return report.tuningSuggestions.take(2).toList(growable: false);
  }

  List<String> _plannerOperatorMaintenanceLines(_PlannerConflictReport report) {
    return report.maintenanceAlerts
        .take(1)
        .map((alert) => _plannerMaintenanceAlertMessage(report, alert))
        .toList(growable: false);
  }

  List<String> _plannerOperatorBacklog(_PlannerConflictReport report) {
    return report.backlogEntries
        .where((entry) => entry.reviewStatus == null)
        .take(2)
        .map(
          (entry) =>
              'Priority ${entry.score}: ${entry.label}${entry.active ? ' (hot now)' : ''}',
        )
        .toList(growable: false);
  }

  int _plannerBacklogReviewStatusSortValue(
    _PlannerBacklogReviewStatus? status,
  ) {
    return switch (status) {
      null => 0,
      _PlannerBacklogReviewStatus.acknowledged => 1,
      _PlannerBacklogReviewStatus.muted => 2,
      _PlannerBacklogReviewStatus.fixed => 3,
    };
  }

  String _plannerBacklogReviewStatusLabel(_PlannerBacklogReviewStatus status) {
    return switch (status) {
      _PlannerBacklogReviewStatus.acknowledged => 'ACKNOWLEDGED',
      _PlannerBacklogReviewStatus.muted => 'MUTED',
      _PlannerBacklogReviewStatus.fixed => 'FIXED',
    };
  }

  String _plannerBacklogReviewStatusName(_PlannerBacklogReviewStatus status) {
    return status.name;
  }

  _PlannerBacklogReviewStatus? _plannerBacklogReviewStatusFromName(
    Object? rawValue,
  ) {
    final name = (rawValue ?? '').toString().trim();
    for (final value in _PlannerBacklogReviewStatus.values) {
      if (value.name == name) {
        return value;
      }
    }
    return null;
  }

  String _plannerTuningSignalForTargetPair({
    required OnyxToolTarget modelTarget,
    required OnyxToolTarget? typedTarget,
  }) {
    if (modelTarget == OnyxToolTarget.cctvReview &&
        typedTarget == OnyxToolTarget.tacticalTrack) {
      return 'Revisit Tactical Track vs CCTV Review threshold. The model keeps asking for visual confirmation while typed triage holds field posture.';
    }
    if (modelTarget == OnyxToolTarget.clientComms) {
      return 'Revisit Client Comms drift guardrail. The model keeps pushing comms before typed triage is ready to open that lane.';
    }
    if (modelTarget == OnyxToolTarget.dispatchBoard) {
      return 'Revisit Dispatch Board escalation threshold. The model keeps pushing dispatch before typed triage agrees the escalation bar is met.';
    }
    if (modelTarget == OnyxToolTarget.reportsWorkspace) {
      return 'Revisit reporting handoff threshold. The model keeps trying to close into summaries before typed triage is done working the incident.';
    }
    if (modelTarget == OnyxToolTarget.tacticalTrack &&
        typedTarget == OnyxToolTarget.cctvReview) {
      return 'Revisit CCTV Review vs Tactical Track threshold. The model keeps pushing field posture before typed triage is satisfied with the visual read.';
    }
    final modelDesk = _deskLabelForTarget(modelTarget);
    if (typedTarget == null) {
      return 'Revisit $modelDesk drift. The model keeps preferring that desk often enough to warrant a planner review.';
    }
    final typedDesk = _deskLabelForTarget(typedTarget);
    return 'Revisit $typedDesk vs $modelDesk threshold. This disagreement pattern is repeating often enough to review planner rules.';
  }

  String _plannerSignalIdForTargetPair({
    required OnyxToolTarget modelTarget,
    required OnyxToolTarget? typedTarget,
  }) {
    return 'drift:${modelTarget.name}:${typedTarget?.name ?? 'none'}';
  }

  String _plannerTrendMessageForSignal({
    required String signalId,
    required int currentCount,
    required int previousCount,
  }) {
    if (currentCount <= 0 && previousCount <= 0) {
      return '';
    }
    if (currentCount <= 0) {
      return 'Resolved: ${_plannerResolvedSignalMessageForId(signalId)}';
    }
    final baseSignal = _plannerSignalMessageForId(signalId);
    if (baseSignal.isEmpty) {
      return '';
    }
    if (previousCount <= 0) {
      return baseSignal;
    }
    if (currentCount > previousCount) {
      return 'Worsening: $baseSignal';
    }
    if (currentCount < previousCount) {
      return 'Easing: $baseSignal';
    }
    return 'Stabilizing: $baseSignal';
  }

  String _plannerTuningSuggestionForSignal({
    required String signalId,
    required int currentCount,
    required int previousCount,
  }) {
    if (currentCount < 3 || currentCount < previousCount) {
      return '';
    }
    final cue = _plannerTuningSuggestionForSignalId(signalId);
    if (cue.isEmpty) {
      return '';
    }
    if (previousCount > 0 && currentCount > previousCount) {
      return 'Tune now: $cue';
    }
    return 'Adjustment cue: $cue';
  }

  String _plannerSignalMessageForId(String signalId) {
    if (signalId == 'route-closed-safety') {
      return 'Revisit route-closed safety messaging. The model keeps pushing execution while typed triage is still holding for confirmation.';
    }
    final parts = signalId.split(':');
    if (parts.length != 3 || parts.first != 'drift') {
      return '';
    }
    final modelTarget = _toolTargetFromName(parts[1]);
    final typedTarget = parts[2] == 'none'
        ? null
        : _toolTargetFromName(parts[2]);
    if (modelTarget == null) {
      return '';
    }
    return _plannerTuningSignalForTargetPair(
      modelTarget: modelTarget,
      typedTarget: typedTarget,
    );
  }

  String _plannerResolvedSignalMessageForId(String signalId) {
    if (signalId == 'route-closed-safety') {
      return 'Route-closed safety disagreement has quieted for now. Keep the confirmation guardrail in place, but it is no longer a recurring drift pattern.';
    }
    final parts = signalId.split(':');
    if (parts.length != 3 || parts.first != 'drift') {
      return 'The last flagged planner drift has quieted for now.';
    }
    final modelTarget = _toolTargetFromName(parts[1]);
    final typedTarget = parts[2] == 'none'
        ? null
        : _toolTargetFromName(parts[2]);
    if (modelTarget == null) {
      return 'The last flagged planner drift has quieted for now.';
    }
    final modelDesk = _deskLabelForTarget(modelTarget);
    if (typedTarget == null) {
      return '$modelDesk drift has quieted for now. Keep watching in case it reappears.';
    }
    final typedDesk = _deskLabelForTarget(typedTarget);
    return '$typedDesk vs $modelDesk drift has quieted for now. Keep watching in case it reappears.';
  }

  String _plannerTuningSuggestionForSignalId(String signalId) {
    if (signalId == 'route-closed-safety') {
      return 'Tighten approval language so route execution stays closed until typed triage has explicit confirmation or a stronger safety trigger.';
    }
    final parts = signalId.split(':');
    if (parts.length != 3 || parts.first != 'drift') {
      return '';
    }
    final modelTarget = _toolTargetFromName(parts[1]);
    final typedTarget = parts[2] == 'none'
        ? null
        : _toolTargetFromName(parts[2]);
    if (modelTarget == OnyxToolTarget.cctvReview &&
        typedTarget == OnyxToolTarget.tacticalTrack) {
      return 'Increase Tactical Track weighting when field posture is already live and CCTV is still only a confirmation step.';
    }
    if (modelTarget == OnyxToolTarget.clientComms) {
      return 'Require verified threat or an explicit update obligation before Client Comms can outrank live operational desks.';
    }
    if (modelTarget == OnyxToolTarget.dispatchBoard) {
      return 'Raise Dispatch Board weighting only when panic, ETA breach, or a confirmed threat is present.';
    }
    if (modelTarget == OnyxToolTarget.reportsWorkspace) {
      return 'Block Reports Workspace handoff while the incident is active or follow-up work is still unresolved.';
    }
    if (modelTarget == OnyxToolTarget.tacticalTrack &&
        typedTarget == OnyxToolTarget.cctvReview) {
      return 'Require a stronger field-posture signal before Tactical Track outranks CCTV Review.';
    }
    final modelDesk = modelTarget == null
        ? ''
        : _deskLabelForTarget(modelTarget);
    if (typedTarget == null) {
      return modelDesk.isEmpty
          ? ''
          : 'Bias routing slightly away from $modelDesk until this repeated drift cools off.';
    }
    final typedDesk = _deskLabelForTarget(typedTarget);
    return 'Bias routing slightly toward $typedDesk and away from $modelDesk until this repeated drift cools off.';
  }

  _AgentThreadMemory _rememberRecommendation(
    _AgentThreadMemory memory,
    OnyxRecommendation recommendation, {
    BrainDecision? decision,
    required String operatorFocusNote,
    required _PlannerConflictReport plannerConflictReport,
  }) {
    final replayHistorySummary = _rememberedReplayHistorySummary();
    final rememberedCommandBrainSnapshot = _rememberedCommandBrainSnapshot(
      decision?.toSnapshot(),
      replayHistorySummary: replayHistorySummary,
    );
    final commandPreview = rememberedCommandBrainSnapshot != null
        ? OnyxCommandSurfacePreview.routed(rememberedCommandBrainSnapshot)
        : OnyxCommandSurfacePreview.answered(
            headline: recommendation.headline,
            label: recommendation.nextMoveLabel,
            summary: recommendation.summary,
          );
    return memory.copyWith(
      lastRecommendedTarget: recommendation.allowRouteExecution
          ? recommendation.target
          : null,
      lastRecommendationSummary: recommendation.summary,
      lastCommandBrainSnapshot: rememberedCommandBrainSnapshot,
      lastCommandPreview: commandPreview,
      lastReplayHistorySummary: replayHistorySummary,
      lastAdvisory: recommendation.advisory,
      lastPrimaryPressure: _typedRecommendationPrimaryPressure(
        recommendation,
        plannerConflictReport: plannerConflictReport,
        operatorFocusNote: operatorFocusNote,
      ),
      lastOperatorFocusNote: operatorFocusNote,
      lastConfidence: recommendation.confidence,
      lastContextHighlights: _orderedVisibleContextHighlights(
        recommendation.contextHighlights,
      ),
      nextFollowUpLabel: recommendation.followUpLabel,
      nextFollowUpPrompt: recommendation.followUpPrompt,
      lastAutoFollowUpSurfacedAt: null,
      staleFollowUpSurfaceCount: 0,
      pendingConfirmations: List<String>.from(recommendation.missingInfo),
      updatedAt: DateTime.now(),
    );
  }

  String _rememberedReplayHistorySummary() {
    return summarizeReplayHistorySignalStack(_replayHistorySignalStack) ?? '';
  }

  OnyxCommandBrainSnapshot? _rememberedCommandBrainSnapshot(
    OnyxCommandBrainSnapshot? snapshot, {
    required String replayHistorySummary,
  }) {
    if (snapshot == null) {
      return null;
    }
    final normalizedReplayHistorySummary = replayHistorySummary.trim();
    if (normalizedReplayHistorySummary.isEmpty ||
        snapshot.contextHighlights.contains(normalizedReplayHistorySummary)) {
      return snapshot;
    }
    return OnyxCommandBrainSnapshot(
      workItemId: snapshot.workItemId,
      mode: snapshot.mode,
      target: snapshot.target,
      nextMoveLabel: snapshot.nextMoveLabel,
      headline: snapshot.headline,
      summary: snapshot.summary,
      advisory: snapshot.advisory,
      confidence: snapshot.confidence,
      primaryPressure: snapshot.primaryPressure,
      rationale: snapshot.rationale,
      supportingSpecialists: snapshot.supportingSpecialists,
      contextHighlights: <String>[
        ...snapshot.contextHighlights,
        normalizedReplayHistorySummary,
      ],
      missingInfo: snapshot.missingInfo,
      followUpLabel: snapshot.followUpLabel,
      followUpPrompt: snapshot.followUpPrompt,
      allowRouteExecution: snapshot.allowRouteExecution,
      specialistAssessments: snapshot.specialistAssessments,
      decisionBias: snapshot.decisionBias,
      replayBiasStack: snapshot.replayBiasStack,
    );
  }

  String _selectedOperatorFocusMemoryNote(
    _PlannerConflictReport plannerConflictReport, {
    String? selectedThreadTitle,
  }) {
    if (!_threadHasOperatorFocus(_selectedThreadId)) {
      return '';
    }
    final resolvedSelectedThreadTitle =
        selectedThreadTitle ??
        _threadTitleForId(_selectedThreadId) ??
        _selectedThread.title;
    final urgentThreadId = _bestThreadIdForPrioritizedMaintenanceFromReport(
      plannerConflictReport,
    );
    if (urgentThreadId != null && urgentThreadId != _selectedThreadId) {
      final urgentThreadTitle = _threadTitleForId(urgentThreadId);
      if (urgentThreadTitle != null && urgentThreadTitle.isNotEmpty) {
        return 'manual context preserved on $resolvedSelectedThreadTitle while urgent review remains visible on $urgentThreadTitle.';
      }
      return 'manual context preserved on $resolvedSelectedThreadTitle while urgent review remains visible elsewhere in the rail.';
    }
    return 'manual context preserved on $resolvedSelectedThreadTitle until the operator changes conversations.';
  }

  _AgentThreadMemory _rememberBrainAdvisory(
    _AgentThreadMemory memory,
    OnyxAgentCloudBoostResponse response,
  ) {
    final advisory = response.advisory;
    if (advisory == null) {
      return memory;
    }
    final clearsFollowUp = _brainFollowUpClearsMemory(advisory.followUpStatus);
    final nextFollowUpLabel = clearsFollowUp
        ? ''
        : advisory.followUpLabel.trim().isNotEmpty
        ? advisory.followUpLabel.trim()
        : memory.nextFollowUpLabel;
    final nextFollowUpPrompt = clearsFollowUp
        ? ''
        : advisory.followUpPrompt.trim().isNotEmpty
        ? advisory.followUpPrompt
        : memory.nextFollowUpPrompt;
    final followUpChanged =
        nextFollowUpLabel.trim() != memory.nextFollowUpLabel.trim() ||
        nextFollowUpPrompt.trim() != memory.nextFollowUpPrompt.trim();
    final staleFollowUpSurfaceCount =
        nextFollowUpLabel.trim().isEmpty || nextFollowUpPrompt.trim().isEmpty
        ? 0
        : _staleFollowUpSurfaceCountForBrainStatus(
            advisory.followUpStatus,
            fallbackCount: followUpChanged
                ? 0
                : memory.staleFollowUpSurfaceCount,
          );
    return memory.copyWith(
      lastRecommendedTarget:
          advisory.recommendedTarget ?? memory.lastRecommendedTarget,
      lastRecommendationSummary: advisory.summary.trim().isEmpty
          ? (response.text.trim().isEmpty
                ? memory.lastRecommendationSummary
                : response.text.trim())
          : advisory.summary.trim(),
      lastAdvisory: advisory.why.trim().isEmpty
          ? (advisory.summary.trim().isEmpty
                ? response.text.trim()
                : advisory.summary.trim())
          : advisory.why.trim(),
      lastPrimaryPressure: _brainAdvisoryPrimaryPressure(
        advisory,
        hasOperatorFocus:
            advisory.operatorFocusNote.trim().isNotEmpty ||
            memory.lastOperatorFocusNote.trim().isNotEmpty,
      ),
      lastOperatorFocusNote: advisory.operatorFocusNote.trim().isNotEmpty
          ? advisory.operatorFocusNote.trim()
          : memory.lastOperatorFocusNote,
      lastConfidence: advisory.confidence ?? memory.lastConfidence,
      lastContextHighlights: advisory.contextHighlights.isNotEmpty
          ? _orderedVisibleContextHighlights(advisory.contextHighlights)
          : List<String>.from(memory.lastContextHighlights),
      nextFollowUpLabel: nextFollowUpLabel,
      nextFollowUpPrompt: nextFollowUpPrompt,
      lastAutoFollowUpSurfacedAt: null,
      staleFollowUpSurfaceCount: staleFollowUpSurfaceCount,
      pendingConfirmations: advisory.missingInfo.isNotEmpty
          ? List<String>.from(advisory.missingInfo)
          : List<String>.from(memory.pendingConfirmations),
      updatedAt: DateTime.now(),
    );
  }

  int _staleFollowUpSurfaceCountForBrainStatus(
    String status, {
    required int fallbackCount,
  }) {
    return switch (status.trim().toLowerCase()) {
      'overdue' => 2,
      'unresolved' => 1,
      'pending' => 0,
      'cleared' || 'resolved' || 'complete' || 'completed' => 0,
      _ => fallbackCount,
    };
  }

  bool _brainFollowUpClearsMemory(String status) {
    return switch (status.trim().toLowerCase()) {
      'cleared' || 'resolved' || 'complete' || 'completed' => true,
      _ => false,
    };
  }

  void _recordOpenedDesk(OnyxToolTarget target) {
    _clearRestoredPressureFocusCue(rebuild: false);
    _clearPlannerFocusCue(rebuild: false);
    _markOperatorSelectedThread(_selectedThreadId);
    _updateSelectedThread((thread) {
      return thread.copyWith(
        memory: thread.memory.copyWith(
          lastOpenedTarget: target,
          lastAutoFollowUpSurfacedAt: null,
          staleFollowUpSurfaceCount: 0,
          updatedAt: DateTime.now(),
        ),
      );
    });
  }

  void _emitThreadSessionState() {
    widget.onThreadSessionStateChanged?.call(_serializeThreadSessionState());
  }

  Map<String, Object?> _serializeThreadSessionState() {
    return <String, Object?>{
      'version': 7,
      'thread_counter': _threadCounter,
      'selected_thread_id': _selectedThreadId,
      if ((_selectedThreadOperatorId ?? '').trim().isNotEmpty)
        'selected_thread_operator_id': _selectedThreadOperatorId,
      if (_selectedThreadOperatorAt != null)
        'selected_thread_operator_at_utc': _selectedThreadOperatorAt!
            .toIso8601String(),
      if (_plannerSignalSnapshot.hasData)
        'planner_signal_snapshot': _serializePlannerSignalSnapshot(
          _plannerSignalSnapshot,
        ),
      if (_previousPlannerSignalSnapshot.hasData)
        'previous_planner_signal_snapshot': _serializePlannerSignalSnapshot(
          _previousPlannerSignalSnapshot,
        ),
      if (_plannerBacklogScores.isNotEmpty)
        'planner_backlog_scores': _plannerBacklogScores,
      if (_plannerBacklogArchivedSignalCounts.isNotEmpty)
        'planner_backlog_archived_signal_counts':
            _plannerBacklogArchivedSignalCounts,
      if (_plannerBacklogReactivatedSignalCounts.isNotEmpty)
        'planner_backlog_reactivated_signal_counts':
            _plannerBacklogReactivatedSignalCounts,
      if (_plannerBacklogReactivationCounts.isNotEmpty)
        'planner_backlog_reactivation_counts':
            _plannerBacklogReactivationCounts,
      if (_plannerBacklogLastReactivatedAt.isNotEmpty)
        'planner_backlog_last_reactivated_at_utc':
            _plannerBacklogLastReactivatedAt.map(
              (key, value) => MapEntry(key, value.toIso8601String()),
            ),
      if (_plannerMaintenanceReviewQueuedAt.isNotEmpty)
        'planner_maintenance_review_queued_at_utc':
            _plannerMaintenanceReviewQueuedAt.map(
              (key, value) => MapEntry(key, value.toIso8601String()),
            ),
      if (_plannerMaintenanceReviewCompletedAt.isNotEmpty)
        'planner_maintenance_review_completed_at_utc':
            _plannerMaintenanceReviewCompletedAt.map(
              (key, value) => MapEntry(key, value.toIso8601String()),
            ),
      if (_plannerMaintenanceReviewPrioritizedAt.isNotEmpty)
        'planner_maintenance_review_prioritized_at_utc':
            _plannerMaintenanceReviewPrioritizedAt.map(
              (key, value) => MapEntry(key, value.toIso8601String()),
            ),
      if (_plannerMaintenanceReviewReopenedCounts.isNotEmpty)
        'planner_maintenance_review_reopened_counts':
            _plannerMaintenanceReviewReopenedCounts,
      if (_plannerMaintenanceReviewCompletedSignalCounts.isNotEmpty)
        'planner_maintenance_review_completed_signal_counts':
            _plannerMaintenanceReviewCompletedSignalCounts,
      if (_plannerMaintenanceReviewCompletedReactivationCounts.isNotEmpty)
        'planner_maintenance_review_completed_reactivation_counts':
            _plannerMaintenanceReviewCompletedReactivationCounts,
      if (_plannerBacklogReviewStatuses.isNotEmpty)
        'planner_backlog_review_statuses': _plannerBacklogReviewStatuses.map(
          (key, value) => MapEntry(key, _plannerBacklogReviewStatusName(value)),
        ),
      'threads': _threads.map(_serializeThread).toList(growable: false),
    };
  }

  Map<String, Object?> _serializePlannerSignalSnapshot(
    _PlannerSignalSnapshot snapshot,
  ) {
    return <String, Object?>{
      if (snapshot.signalCounts.isNotEmpty)
        'signal_counts': snapshot.signalCounts,
      if (snapshot.capturedAt != null)
        'captured_at_utc': snapshot.capturedAt!.toIso8601String(),
    };
  }

  Map<String, Object?> _serializeThread(_AgentThread thread) {
    return <String, Object?>{
      'id': thread.id,
      'title': thread.title,
      'summary': thread.summary,
      'memory': _serializeThreadMemory(thread.memory),
      'messages': thread.messages
          .map(_serializeMessage)
          .toList(growable: false),
    };
  }

  Map<String, Object?> _serializeThreadMemory(_AgentThreadMemory memory) {
    final serializedCommandSurfaceMemory = memory.commandSurfaceMemory.hasData
        ? memory.commandSurfaceMemory.toJson()
        : null;
    final serializedLegacyBrainSnapshot = memory.lastCommandBrainSnapshot
        ?.toJson();
    final serializedSurfaceBrainSnapshot =
        serializedCommandSurfaceMemory?['commandBrainSnapshot'];
    final shouldSerializeLegacyBrainSnapshot =
        serializedLegacyBrainSnapshot != null &&
        (serializedSurfaceBrainSnapshot == null ||
            jsonEncode(serializedSurfaceBrainSnapshot) !=
                jsonEncode(serializedLegacyBrainSnapshot));
    final normalizedLegacyReplayHistorySummary = memory.lastReplayHistorySummary
        .trim();
    final normalizedSurfaceReplayHistorySummary =
        (serializedCommandSurfaceMemory?['replayHistorySummary'] ?? '')
            .toString()
            .trim();
    final shouldSerializeLegacyReplayHistorySummary =
        normalizedLegacyReplayHistorySummary.isNotEmpty &&
        normalizedSurfaceReplayHistorySummary !=
            normalizedLegacyReplayHistorySummary;
    return <String, Object?>{
      'command_surface_memory': ?serializedCommandSurfaceMemory,
      'last_recommended_target': ?memory.lastRecommendedTarget?.name,
      'last_opened_target': ?memory.lastOpenedTarget?.name,
      if (shouldSerializeLegacyBrainSnapshot)
        'last_command_brain_snapshot': serializedLegacyBrainSnapshot,
      if (shouldSerializeLegacyReplayHistorySummary)
        'last_replay_history_summary': normalizedLegacyReplayHistorySummary,
      if (memory.lastRecommendationSummary.trim().isNotEmpty)
        'last_recommendation_summary': memory.lastRecommendationSummary.trim(),
      if (memory.lastAdvisory.trim().isNotEmpty)
        'last_advisory': memory.lastAdvisory.trim(),
      if (memory.lastPrimaryPressure.trim().isNotEmpty)
        'last_primary_pressure': memory.lastPrimaryPressure.trim(),
      if (memory.lastOperatorFocusNote.trim().isNotEmpty)
        'last_operator_focus_note': memory.lastOperatorFocusNote.trim(),
      if (memory.lastConfidence != null)
        'last_confidence': memory.lastConfidence,
      if (memory.lastContextHighlights.isNotEmpty)
        'last_context_highlights': memory.lastContextHighlights,
      if (memory.secondLookConflictCount > 0)
        'second_look_conflict_count': memory.secondLookConflictCount,
      if (memory.lastSecondLookConflictSummary.trim().isNotEmpty)
        'last_second_look_conflict_summary': memory
            .lastSecondLookConflictSummary
            .trim(),
      if (memory.lastSecondLookConflictAt != null)
        'last_second_look_conflict_at_utc': memory.lastSecondLookConflictAt!
            .toIso8601String(),
      if (memory.secondLookModelTargetCounts.isNotEmpty)
        'second_look_model_target_counts': _serializeTargetCountMap(
          memory.secondLookModelTargetCounts,
        ),
      if (memory.secondLookTypedTargetCounts.isNotEmpty)
        'second_look_typed_target_counts': _serializeTargetCountMap(
          memory.secondLookTypedTargetCounts,
        ),
      if (memory.secondLookRouteClosedConflictCount > 0)
        'second_look_route_closed_conflict_count':
            memory.secondLookRouteClosedConflictCount,
      if (memory.nextFollowUpLabel.trim().isNotEmpty)
        'next_follow_up_label': memory.nextFollowUpLabel.trim(),
      if (memory.nextFollowUpPrompt.trim().isNotEmpty)
        'next_follow_up_prompt': memory.nextFollowUpPrompt,
      if (memory.lastAutoFollowUpSurfacedAt != null)
        'last_auto_follow_up_surfaced_at_utc': memory
            .lastAutoFollowUpSurfacedAt!
            .toIso8601String(),
      if (memory.staleFollowUpSurfaceCount > 0)
        'stale_follow_up_surface_count': memory.staleFollowUpSurfaceCount,
      if (memory.pendingConfirmations.isNotEmpty)
        'pending_confirmations': memory.pendingConfirmations,
      if (memory.updatedAt != null)
        'updated_at_utc': memory.updatedAt!.toIso8601String(),
    };
  }

  Map<String, Object?> _serializeMessage(_AgentMessage message) {
    return <String, Object?>{
      'id': message.id,
      'kind': message.kind.name,
      'persona_id': message.personaId,
      'headline': message.headline,
      'body': message.body,
      'created_at_utc': message.createdAt.toIso8601String(),
      if (message.actions.isNotEmpty)
        'actions': message.actions
            .map(_serializeAction)
            .toList(growable: false),
    };
  }

  Map<String, Object?> _serializeAction(_AgentActionCard action) {
    return <String, Object?>{
      'id': action.id,
      'kind': action.kind.name,
      'label': action.label,
      'detail': action.detail,
      if (action.payload.trim().isNotEmpty) 'payload': action.payload,
      if (action.arguments.isNotEmpty) 'arguments': action.arguments,
      if (action.requiresApproval) 'requires_approval': true,
      if (action.opensRoute) 'opens_route': true,
      'persona_id': action.personaId,
    };
  }

  ({
    List<_AgentThread> threads,
    String selectedThreadId,
    String? selectedThreadOperatorId,
    DateTime? selectedThreadOperatorAt,
    int threadCounter,
    _PlannerSignalSnapshot plannerSignalSnapshot,
    _PlannerSignalSnapshot previousPlannerSignalSnapshot,
    Map<String, int> plannerBacklogScores,
    Map<String, int> plannerBacklogArchivedSignalCounts,
    Map<String, int> plannerBacklogReactivatedSignalCounts,
    Map<String, int> plannerBacklogReactivationCounts,
    Map<String, DateTime> plannerBacklogLastReactivatedAt,
    Map<String, DateTime> plannerMaintenanceReviewQueuedAt,
    Map<String, DateTime> plannerMaintenanceReviewCompletedAt,
    Map<String, DateTime> plannerMaintenanceReviewPrioritizedAt,
    Map<String, int> plannerMaintenanceReviewReopenedCounts,
    Map<String, int> plannerMaintenanceReviewCompletedSignalCounts,
    Map<String, int> plannerMaintenanceReviewCompletedReactivationCounts,
    Map<String, _PlannerBacklogReviewStatus> plannerBacklogReviewStatuses,
  })?
  _restoreThreadSessionState(Map<String, Object?> rawState) {
    if (rawState.isEmpty) {
      return null;
    }
    final rawThreads = rawState['threads'];
    if (rawThreads is! List) {
      return null;
    }
    final threads = rawThreads
        .whereType<Map>()
        .map(
          (entry) => _deserializeThread(
            entry.cast<Object?, Object?>().map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          ),
        )
        .whereType<_AgentThread>()
        .toList(growable: false);
    if (threads.isEmpty) {
      return null;
    }
    final rawSelectedThreadId = (rawState['selected_thread_id'] ?? '')
        .toString()
        .trim();
    final selectedThreadId =
        threads.any((thread) => thread.id == rawSelectedThreadId)
        ? rawSelectedThreadId
        : threads.first.id;
    final rawSelectedThreadOperatorId =
        (rawState['selected_thread_operator_id'] ?? '').toString().trim();
    final selectedThreadOperatorId =
        threads.any((thread) => thread.id == rawSelectedThreadOperatorId)
        ? rawSelectedThreadOperatorId
        : null;
    final selectedThreadOperatorAt = _dateFromValue(
      rawState['selected_thread_operator_at_utc'],
    );
    final parsedCounter = _intFromValue(rawState['thread_counter']);
    final plannerSignalSnapshot = _plannerSignalSnapshotFromValue(
      rawState['planner_signal_snapshot'],
    );
    final previousPlannerSignalSnapshot = _plannerSignalSnapshotFromValue(
      rawState['previous_planner_signal_snapshot'],
    );
    final plannerBacklogScores = _stringIntMapFromValue(
      rawState['planner_backlog_scores'],
    );
    final plannerBacklogArchivedSignalCounts = _stringIntMapFromValue(
      rawState['planner_backlog_archived_signal_counts'],
    );
    final plannerBacklogReactivatedSignalCounts = _stringIntMapFromValue(
      rawState['planner_backlog_reactivated_signal_counts'],
    );
    final plannerBacklogReactivationCounts = _stringIntMapFromValue(
      rawState['planner_backlog_reactivation_counts'],
    );
    final plannerBacklogLastReactivatedAt = _stringDateMapFromValue(
      rawState['planner_backlog_last_reactivated_at_utc'],
    );
    final plannerMaintenanceReviewQueuedAt = _stringDateMapFromValue(
      rawState['planner_maintenance_review_queued_at_utc'],
    );
    final plannerMaintenanceReviewCompletedAt = _stringDateMapFromValue(
      rawState['planner_maintenance_review_completed_at_utc'],
    );
    final plannerMaintenanceReviewPrioritizedAt = _stringDateMapFromValue(
      rawState['planner_maintenance_review_prioritized_at_utc'],
    );
    final plannerMaintenanceReviewReopenedCounts = _stringIntMapFromValue(
      rawState['planner_maintenance_review_reopened_counts'],
    );
    final plannerMaintenanceReviewCompletedSignalCounts =
        _stringIntMapFromValue(
          rawState['planner_maintenance_review_completed_signal_counts'],
        );
    final plannerMaintenanceReviewCompletedReactivationCounts =
        _stringIntMapFromValue(
          rawState['planner_maintenance_review_completed_reactivation_counts'],
        );
    final plannerBacklogReviewStatuses = _plannerBacklogReviewStatusesFromValue(
      rawState['planner_backlog_review_statuses'],
    );
    return (
      threads: threads,
      selectedThreadId: selectedThreadId,
      selectedThreadOperatorId: selectedThreadOperatorId,
      selectedThreadOperatorAt: selectedThreadOperatorAt,
      threadCounter: parsedCounter ?? _inferThreadCounter(threads),
      plannerSignalSnapshot: plannerSignalSnapshot,
      previousPlannerSignalSnapshot: previousPlannerSignalSnapshot,
      plannerBacklogScores: plannerBacklogScores,
      plannerBacklogArchivedSignalCounts: plannerBacklogArchivedSignalCounts,
      plannerBacklogReactivatedSignalCounts:
          plannerBacklogReactivatedSignalCounts,
      plannerBacklogReactivationCounts: plannerBacklogReactivationCounts,
      plannerBacklogLastReactivatedAt: plannerBacklogLastReactivatedAt,
      plannerMaintenanceReviewQueuedAt: plannerMaintenanceReviewQueuedAt,
      plannerMaintenanceReviewCompletedAt: plannerMaintenanceReviewCompletedAt,
      plannerMaintenanceReviewPrioritizedAt:
          plannerMaintenanceReviewPrioritizedAt,
      plannerMaintenanceReviewReopenedCounts:
          plannerMaintenanceReviewReopenedCounts,
      plannerMaintenanceReviewCompletedSignalCounts:
          plannerMaintenanceReviewCompletedSignalCounts,
      plannerMaintenanceReviewCompletedReactivationCounts:
          plannerMaintenanceReviewCompletedReactivationCounts,
      plannerBacklogReviewStatuses: plannerBacklogReviewStatuses,
    );
  }

  _PlannerSignalSnapshot _plannerSignalSnapshotFromValue(Object? rawValue) {
    if (rawValue is! Map) {
      return const _PlannerSignalSnapshot();
    }
    final snapshot = rawValue.cast<Object?, Object?>().map(
      (key, value) => MapEntry(key.toString(), value),
    );
    return _PlannerSignalSnapshot(
      signalCounts: _stringIntMapFromValue(snapshot['signal_counts']),
      capturedAt: _dateFromValue(snapshot['captured_at_utc']),
    );
  }

  Map<String, DateTime> _stringDateMapFromValue(Object? rawValue) {
    if (rawValue is! Map) {
      return const <String, DateTime>{};
    }
    final parsed = <String, DateTime>{};
    for (final entry in rawValue.entries) {
      final key = entry.key?.toString().trim() ?? '';
      final value = _dateFromValue(entry.value);
      if (key.isEmpty || value == null) {
        continue;
      }
      parsed[key] = value;
    }
    return parsed;
  }

  Map<String, _PlannerBacklogReviewStatus>
  _plannerBacklogReviewStatusesFromValue(Object? rawValue) {
    if (rawValue is! Map) {
      return const <String, _PlannerBacklogReviewStatus>{};
    }
    final parsed = <String, _PlannerBacklogReviewStatus>{};
    for (final entry in rawValue.entries) {
      final key = entry.key?.toString().trim() ?? '';
      final status = _plannerBacklogReviewStatusFromName(entry.value);
      if (key.isEmpty || status == null) {
        continue;
      }
      parsed[key] = status;
    }
    return parsed;
  }

  _AgentThread? _deserializeThread(Map<String, Object?> rawThread) {
    final id = (rawThread['id'] ?? '').toString().trim();
    final title = (rawThread['title'] ?? '').toString().trim();
    if (id.isEmpty || title.isEmpty) {
      return null;
    }
    final rawMessages = rawThread['messages'];
    final messages = rawMessages is List
        ? rawMessages
              .whereType<Map>()
              .map(
                (entry) => _deserializeMessage(
                  entry.cast<Object?, Object?>().map(
                    (key, value) => MapEntry(key.toString(), value),
                  ),
                ),
              )
              .whereType<_AgentMessage>()
              .toList(growable: false)
        : const <_AgentMessage>[];
    if (messages.isEmpty) {
      return null;
    }
    final rawMemory = rawThread['memory'];
    final memory = rawMemory is Map
        ? _deserializeThreadMemory(
            rawMemory.cast<Object?, Object?>().map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          )
        : _AgentThreadMemory();
    return _AgentThread(
      id: id,
      title: title,
      summary: (rawThread['summary'] ?? '').toString().trim(),
      memory: memory,
      messages: messages,
    );
  }

  _AgentThreadMemory _deserializeThreadMemory(Map<String, Object?> rawMemory) {
    final lastRecommendedTarget = _toolTargetFromName(
      rawMemory['last_recommended_target'],
    );
    final lastOpenedTarget = _toolTargetFromName(
      rawMemory['last_opened_target'],
    );
    final commandSurfaceMemory = OnyxCommandSurfaceMemoryAdapter.restore(
      persistedMemory: _commandSurfaceMemoryFromValue(
        rawMemory['command_surface_memory'],
      ),
      legacyCommandBrainSnapshot:
          _commandBrainSnapshotFromValue(
            rawMemory['last_command_brain_snapshot'],
          ) ??
          _legacyCommandBrainSnapshotFromMemory(
            rawMemory,
            lastRecommendedTarget: lastRecommendedTarget,
            lastOpenedTarget: lastOpenedTarget,
          ),
      legacyReplayHistorySummary:
          (rawMemory['last_replay_history_summary'] ?? '').toString().trim(),
    );
    return _AgentThreadMemory(
      lastRecommendedTarget: lastRecommendedTarget,
      lastOpenedTarget: lastOpenedTarget,
      commandSurfaceMemory: commandSurfaceMemory,
      lastRecommendationSummary:
          (rawMemory['last_recommendation_summary'] ?? '').toString().trim(),
      lastAdvisory: (rawMemory['last_advisory'] ?? '').toString().trim(),
      lastPrimaryPressure: (rawMemory['last_primary_pressure'] ?? '')
          .toString()
          .trim(),
      lastOperatorFocusNote: (rawMemory['last_operator_focus_note'] ?? '')
          .toString()
          .trim(),
      lastConfidence: _doubleFromValue(rawMemory['last_confidence']),
      lastContextHighlights: _stringListFromValue(
        rawMemory['last_context_highlights'],
      ),
      secondLookConflictCount:
          _intFromValue(rawMemory['second_look_conflict_count']) ?? 0,
      lastSecondLookConflictSummary:
          (rawMemory['last_second_look_conflict_summary'] ?? '')
              .toString()
              .trim(),
      lastSecondLookConflictAt: _dateFromValue(
        rawMemory['last_second_look_conflict_at_utc'],
      ),
      secondLookModelTargetCounts: _toolTargetCountMapFromValue(
        rawMemory['second_look_model_target_counts'],
      ),
      secondLookTypedTargetCounts: _toolTargetCountMapFromValue(
        rawMemory['second_look_typed_target_counts'],
      ),
      secondLookRouteClosedConflictCount:
          _intFromValue(rawMemory['second_look_route_closed_conflict_count']) ??
          0,
      nextFollowUpLabel: (rawMemory['next_follow_up_label'] ?? '')
          .toString()
          .trim(),
      nextFollowUpPrompt: (rawMemory['next_follow_up_prompt'] ?? '').toString(),
      lastAutoFollowUpSurfacedAt: _dateFromValue(
        rawMemory['last_auto_follow_up_surfaced_at_utc'],
      ),
      staleFollowUpSurfaceCount:
          _intFromValue(rawMemory['stale_follow_up_surface_count']) ?? 0,
      pendingConfirmations: _stringListFromValue(
        rawMemory['pending_confirmations'],
      ),
      updatedAt: _dateFromValue(rawMemory['updated_at_utc']),
    );
  }

  _AgentMessage? _deserializeMessage(Map<String, Object?> rawMessage) {
    final id = (rawMessage['id'] ?? '').toString().trim();
    final kind = _messageKindFromName(rawMessage['kind']);
    final personaId = (rawMessage['persona_id'] ?? '').toString().trim();
    final body = (rawMessage['body'] ?? '').toString();
    if (id.isEmpty ||
        kind == null ||
        personaId.isEmpty ||
        body.trim().isEmpty) {
      return null;
    }
    final rawActions = rawMessage['actions'];
    final actions = rawActions is List
        ? rawActions
              .whereType<Map>()
              .map(
                (entry) => _deserializeAction(
                  entry.cast<Object?, Object?>().map(
                    (key, value) => MapEntry(key.toString(), value),
                  ),
                ),
              )
              .whereType<_AgentActionCard>()
              .toList(growable: false)
        : const <_AgentActionCard>[];
    return _AgentMessage(
      id: id,
      kind: kind,
      personaId: personaId,
      headline: (rawMessage['headline'] ?? '').toString(),
      body: body,
      createdAt: _dateFromValue(rawMessage['created_at_utc']) ?? DateTime.now(),
      actions: actions,
    );
  }

  _AgentActionCard? _deserializeAction(Map<String, Object?> rawAction) {
    final id = (rawAction['id'] ?? '').toString().trim();
    final kind = _actionKindFromName(rawAction['kind']);
    final label = (rawAction['label'] ?? '').toString().trim();
    final detail = (rawAction['detail'] ?? '').toString().trim();
    final personaId = (rawAction['persona_id'] ?? '').toString().trim();
    if (id.isEmpty ||
        kind == null ||
        label.isEmpty ||
        detail.isEmpty ||
        personaId.isEmpty) {
      return null;
    }
    final rawArguments = rawAction['arguments'];
    final arguments = rawArguments is Map
        ? rawArguments.map(
            (key, value) => MapEntry(key.toString(), (value ?? '').toString()),
          )
        : const <String, String>{};
    return _AgentActionCard(
      id: id,
      kind: kind,
      label: label,
      detail: detail,
      payload: (rawAction['payload'] ?? '').toString(),
      arguments: arguments,
      requiresApproval: rawAction['requires_approval'] == true,
      opensRoute: rawAction['opens_route'] == true,
      personaId: personaId,
    );
  }

  int _inferThreadCounter(List<_AgentThread> threads) {
    var maxCounter = 0;
    for (final thread in threads) {
      final match = RegExp(r'thread-(\d+)$').firstMatch(thread.id);
      final value = int.tryParse(match?.group(1) ?? '');
      if (value != null && value > maxCounter) {
        maxCounter = value;
      }
    }
    return maxCounter < 3 ? 3 : maxCounter;
  }

  OnyxToolTarget? _toolTargetFromName(Object? rawValue) {
    final name = (rawValue ?? '').toString().trim();
    for (final value in OnyxToolTarget.values) {
      if (value.name == name) {
        return value;
      }
    }
    return null;
  }

  BrainDecisionMode? _brainDecisionModeFromName(Object? rawValue) {
    final name = (rawValue ?? '').toString().trim();
    for (final value in BrainDecisionMode.values) {
      if (value.name == name) {
        return value;
      }
    }
    return null;
  }

  List<OnyxSpecialist> _specialistsFromValue(Object? rawValue) {
    if (rawValue is! List) {
      return const <OnyxSpecialist>[];
    }
    final specialists = <OnyxSpecialist>[];
    for (final entry in rawValue) {
      final name = entry.toString().trim();
      for (final specialist in OnyxSpecialist.values) {
        if (specialist.name == name && !specialists.contains(specialist)) {
          specialists.add(specialist);
          break;
        }
      }
    }
    return List<OnyxSpecialist>.unmodifiable(specialists);
  }

  OnyxCommandBrainSnapshot? _commandBrainSnapshotFromValue(Object? rawValue) {
    if (rawValue is! Map) {
      return null;
    }
    return OnyxCommandBrainSnapshot.fromJson(
      rawValue.cast<Object?, Object?>().map(
        (key, value) => MapEntry(key.toString(), value),
      ),
    );
  }

  OnyxCommandSurfaceMemory? _commandSurfaceMemoryFromValue(Object? rawValue) {
    if (rawValue is! Map) {
      return null;
    }
    final parsed = OnyxCommandSurfaceMemory.fromJson(
      rawValue.cast<Object?, Object?>().map(
        (key, value) => MapEntry(key.toString(), value),
      ),
    );
    return parsed.hasData ? parsed : null;
  }

  OnyxCommandBrainSnapshot? _legacyCommandBrainSnapshotFromMemory(
    Map<String, Object?> rawMemory, {
    required OnyxToolTarget? lastRecommendedTarget,
    required OnyxToolTarget? lastOpenedTarget,
  }) {
    final mode = _brainDecisionModeFromName(
      rawMemory['last_brain_decision_mode'],
    );
    final specialists = _specialistsFromValue(
      rawMemory['last_brain_specialists'],
    );
    if (mode == null && specialists.isEmpty) {
      return null;
    }
    final target =
        lastRecommendedTarget ??
        lastOpenedTarget ??
        OnyxToolTarget.dispatchBoard;
    return OnyxCommandBrainSnapshot(
      workItemId: 'thread-memory',
      mode: mode ?? BrainDecisionMode.deterministic,
      target: target,
      nextMoveLabel: _nextMoveLabelForTarget(target),
      headline: '${_deskLabelForTarget(target)} is the next move',
      summary: (rawMemory['last_recommendation_summary'] ?? '')
          .toString()
          .trim(),
      advisory: (rawMemory['last_advisory'] ?? '').toString().trim(),
      confidence: _doubleFromValue(rawMemory['last_confidence']) ?? 0.0,
      primaryPressure: (rawMemory['last_primary_pressure'] ?? '')
          .toString()
          .trim(),
      supportingSpecialists: specialists,
      contextHighlights: _stringListFromValue(
        rawMemory['last_context_highlights'],
      ),
      missingInfo: _stringListFromValue(rawMemory['pending_confirmations']),
      followUpLabel: (rawMemory['next_follow_up_label'] ?? '')
          .toString()
          .trim(),
      followUpPrompt: (rawMemory['next_follow_up_prompt'] ?? '').toString(),
      allowRouteExecution: lastRecommendedTarget != null,
    );
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

  _AgentMessageKind? _messageKindFromName(Object? rawValue) {
    final name = (rawValue ?? '').toString().trim();
    for (final value in _AgentMessageKind.values) {
      if (value.name == name) {
        return value;
      }
    }
    return null;
  }

  _AgentActionKind? _actionKindFromName(Object? rawValue) {
    final name = (rawValue ?? '').toString().trim();
    for (final value in _AgentActionKind.values) {
      if (value.name == name) {
        return value;
      }
    }
    return null;
  }

  Map<String, Object?> _serializeTargetCountMap(
    Map<OnyxToolTarget, int> counts,
  ) {
    return Map<String, Object?>.fromEntries(
      counts.entries
          .where((entry) => entry.value > 0)
          .map((entry) => MapEntry(entry.key.name, entry.value)),
    );
  }

  Map<OnyxToolTarget, int> _toolTargetCountMapFromValue(Object? rawValue) {
    if (rawValue is! Map) {
      return const <OnyxToolTarget, int>{};
    }
    final parsed = <OnyxToolTarget, int>{};
    for (final entry in rawValue.entries) {
      final target = _toolTargetFromName(entry.key);
      final count = _intFromValue(entry.value);
      if (target == null || count == null || count <= 0) {
        continue;
      }
      parsed[target] = count;
    }
    return parsed;
  }

  List<String> _stringListFromValue(Object? rawValue) {
    if (rawValue is! List) {
      return const <String>[];
    }
    return rawValue
        .map((entry) => entry.toString().trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }

  DateTime? _dateFromValue(Object? rawValue) {
    final text = (rawValue ?? '').toString().trim();
    if (text.isEmpty) {
      return null;
    }
    return DateTime.tryParse(text);
  }

  int? _intFromValue(Object? rawValue) {
    if (rawValue is int) {
      return rawValue;
    }
    return int.tryParse((rawValue ?? '').toString().trim());
  }

  double? _doubleFromValue(Object? rawValue) {
    if (rawValue is double) {
      return rawValue;
    }
    if (rawValue is int) {
      return rawValue.toDouble();
    }
    return double.tryParse((rawValue ?? '').toString().trim());
  }

  bool _sameJsonState(Map<String, Object?> left, Map<String, Object?> right) {
    if (identical(left, right)) {
      return true;
    }
    if (left.length != right.length) {
      return false;
    }
    for (final entry in left.entries) {
      if (right[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  bool _sameStringIntMap(Map<String, int> left, Map<String, int> right) {
    if (identical(left, right)) {
      return true;
    }
    if (left.length != right.length) {
      return false;
    }
    for (final entry in left.entries) {
      if (right[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  Map<String, int> _stringIntMapFromValue(Object? rawValue) {
    if (rawValue is! Map) {
      return const <String, int>{};
    }
    final parsed = <String, int>{};
    for (final entry in rawValue.entries) {
      final key = entry.key?.toString().trim() ?? '';
      final count = _intFromValue(entry.value);
      if (key.isEmpty || count == null || count <= 0) {
        continue;
      }
      parsed[key] = count;
    }
    return parsed;
  }

  String _threadTitleFromPrompt(String prompt) {
    final normalized = prompt.trim();
    if (normalized.isEmpty) {
      return 'Agent Session';
    }
    if (normalized.length <= 28) {
      return normalized;
    }
    return '${normalized.substring(0, 28).trim()}...';
  }

  String _threadSummaryFromPrompt(String prompt) {
    return switch (_promptHandlingProfile(prompt)) {
      _PromptHandlingProfile.triage =>
        'One next move is staged from typed triage.',
      _PromptHandlingProfile.cameraRecovery =>
        'Camera recovery flow is active.',
      _PromptHandlingProfile.camera =>
        'Camera bring-up and validation flow is active.',
      _PromptHandlingProfile.telemetry =>
        'Tactical Track watch and escalation timing are active.',
      _PromptHandlingProfile.patrol => 'Patrol proof verification is active.',
      _PromptHandlingProfile.client =>
        'Client drafting and Client Comms handoff are active.',
      _PromptHandlingProfile.report => 'Reports Workspace narrative is active.',
      _PromptHandlingProfile.correlation =>
        'War Room signal picture and incident triage are active.',
      _PromptHandlingProfile.admin =>
        'Governance Desk health and policy review are active.',
      _PromptHandlingProfile.dispatch =>
        'Dispatch Board, Tactical Track, CCTV Review, and Client Comms handoffs are staged.',
      _PromptHandlingProfile.general =>
        'General operator reasoning thread is active.',
    };
  }

  OnyxAgentCloudIntent _cloudIntentForPrompt(String prompt) {
    return switch (_promptHandlingProfile(prompt)) {
      _PromptHandlingProfile.triage => OnyxAgentCloudIntent.correlation,
      _PromptHandlingProfile.cameraRecovery ||
      _PromptHandlingProfile.camera => OnyxAgentCloudIntent.camera,
      _PromptHandlingProfile.telemetry => OnyxAgentCloudIntent.telemetry,
      _PromptHandlingProfile.patrol => OnyxAgentCloudIntent.patrol,
      _PromptHandlingProfile.client => OnyxAgentCloudIntent.client,
      _PromptHandlingProfile.report => OnyxAgentCloudIntent.report,
      _PromptHandlingProfile.correlation => OnyxAgentCloudIntent.correlation,
      _PromptHandlingProfile.admin => OnyxAgentCloudIntent.admin,
      _PromptHandlingProfile.dispatch => OnyxAgentCloudIntent.dispatch,
      _PromptHandlingProfile.general => OnyxAgentCloudIntent.general,
    };
  }

  _PromptHandlingProfile _promptHandlingProfile(String prompt) {
    final normalized = prompt.toLowerCase();
    final ips = _extractIpv4Targets(prompt);
    if (_looksLikeTriagePrompt(normalized)) {
      return _PromptHandlingProfile.triage;
    }
    if (_looksLikeCameraRecoveryPrompt(normalized)) {
      return _PromptHandlingProfile.cameraRecovery;
    }
    if (_looksLikeCameraPrompt(normalized, ips)) {
      return _PromptHandlingProfile.camera;
    }
    if (_looksLikeTelemetryPrompt(normalized)) {
      return _PromptHandlingProfile.telemetry;
    }
    if (_looksLikePatrolPrompt(normalized)) {
      return _PromptHandlingProfile.patrol;
    }
    if (_looksLikeClientPrompt(normalized)) {
      return _PromptHandlingProfile.client;
    }
    if (_looksLikeReportPrompt(normalized)) {
      return _PromptHandlingProfile.report;
    }
    if (_looksLikeCorrelationPrompt(normalized) ||
        _looksLikeClassificationPrompt(normalized)) {
      return _PromptHandlingProfile.correlation;
    }
    if (_looksLikeSystemPrompt(normalized) ||
        _looksLikePolicyPrompt(normalized)) {
      return _PromptHandlingProfile.admin;
    }
    if (_looksLikeDispatchPrompt(normalized)) {
      return _PromptHandlingProfile.dispatch;
    }
    return _PromptHandlingProfile.general;
  }

  List<String> _extractIpv4Targets(String prompt) {
    final matches = RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}\b')
        .allMatches(prompt)
        .map((match) => match.group(0) ?? '')
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    final deduped = <String>{};
    final output = <String>[];
    for (final candidate in matches) {
      final octets = candidate.split('.');
      if (octets.length != 4) {
        continue;
      }
      final valid = octets.every((octet) {
        final parsed = int.tryParse(octet);
        return parsed != null && parsed >= 0 && parsed <= 255;
      });
      if (!valid || deduped.contains(candidate)) {
        continue;
      }
      deduped.add(candidate);
      output.add(candidate);
    }
    return output;
  }

  bool _looksLikeCameraPrompt(String normalized, List<String> ips) {
    return ips.isNotEmpty ||
        normalized.contains('camera') ||
        normalized.contains('rtsp') ||
        normalized.contains('onvif') ||
        normalized.contains('nvr') ||
        normalized.contains('dvr') ||
        normalized.contains('wire') ||
        normalized.contains('wiring');
  }

  bool _looksLikeCameraRecoveryPrompt(String normalized) {
    if (!_looksLikeCameraPrompt(normalized, const <String>[])) {
      return false;
    }
    return normalized.contains('reconnect') ||
        normalized.contains('connect') ||
        normalized.contains('restore') ||
        normalized.contains('recover') ||
        normalized.contains('bring back') ||
        normalized.contains('back online') ||
        normalized.contains('bring online') ||
        normalized.contains('offline') ||
        normalized.contains('wifi') ||
        normalized.contains('wi-fi') ||
        normalized.contains('feed down') ||
        normalized.contains('stream down');
  }

  String _cameraRecoveryScopeLabel() {
    final siteId = widget.scopeSiteId.trim();
    if (siteId.isEmpty) {
      return _scopeLabel();
    }
    final tokens = siteId
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .split(RegExp(r'\s+'))
        .where((token) => token.trim().isNotEmpty)
        .toList(growable: false);
    final filtered = tokens
        .where((token) {
          final lower = token.toLowerCase();
          return lower != 'site';
        })
        .toList(growable: false);
    if (filtered.isEmpty) {
      return _scopeLabel();
    }
    return filtered
        .map((token) {
          final lower = token.toLowerCase();
          if (lower == 'ms') {
            return 'MS';
          }
          if (lower == 'vip') {
            return 'VIP';
          }
          return '${lower.substring(0, 1).toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');
  }

  bool _looksLikeClientPrompt(String normalized) {
    return normalized.contains('client') ||
        normalized.contains('reply') ||
        normalized.contains('message') ||
        normalized.contains('update') ||
        normalized.contains('comms');
  }

  bool _looksLikeTelemetryPrompt(String normalized) {
    return normalized.contains('telemetry') ||
        normalized.contains('heart rate') ||
        normalized.contains('hr ') ||
        normalized.contains('distress') ||
        normalized.contains('inactivity') ||
        normalized.contains('wearable') ||
        normalized.contains('no movement');
  }

  bool _looksLikePatrolPrompt(String normalized) {
    return normalized.contains('patrol') ||
        normalized.contains('checkpoint') ||
        normalized.contains('photo') ||
        normalized.contains('baseline') ||
        normalized.contains('fake patrol');
  }

  bool _looksLikeReportPrompt(String normalized) {
    return normalized.contains('report') ||
        normalized.contains('daily report') ||
        normalized.contains('narrative') ||
        normalized.contains('ob entry') ||
        normalized.contains('occurrence book');
  }

  bool _looksLikeCorrelationPrompt(String normalized) {
    return normalized.contains('correlate') ||
        normalized.contains('correlation') ||
        normalized.contains('multiple signals') ||
        normalized.contains('combine') ||
        normalized.contains('fusion');
  }

  bool _looksLikeClassificationPrompt(String normalized) {
    return normalized.contains('classify') ||
        normalized.contains('classification') ||
        normalized.contains('false alarm') ||
        normalized.contains('intrusion') ||
        normalized.contains('sensor fault') ||
        normalized.contains('suspicious activity');
  }

  bool _looksLikeDispatchPrompt(String normalized) {
    return normalized.contains('alarm') ||
        normalized.contains('dispatch') ||
        normalized.contains('track') ||
        normalized.contains('incident') ||
        normalized.contains('guard');
  }

  bool _looksLikeSystemPrompt(String normalized) {
    return normalized.contains('system') ||
        normalized.contains('camera offline') ||
        normalized.contains('health') ||
        normalized.contains('device') ||
        normalized.contains('integration') ||
        normalized.contains('feed') ||
        normalized.contains('debug') ||
        normalized.contains('confidence');
  }

  bool _looksLikePolicyPrompt(String normalized) {
    return normalized.contains('policy') ||
        normalized.contains('logic') ||
        normalized.contains('threshold') ||
        normalized.contains('safety') ||
        normalized.contains('rule');
  }

  bool _looksLikeTriagePrompt(String normalized) {
    return normalized.contains('triage') ||
        normalized.contains('next move') ||
        normalized.contains('what now') ||
        normalized.contains("what's happening") ||
        normalized.contains('what is happening') ||
        normalized.contains('status') ||
        normalized.contains('everything okay') ||
        normalized.contains('across sites') ||
        normalized.contains('what should i do') ||
        normalized.contains('where do i go next') ||
        normalized.contains('one obvious next move') ||
        normalized.contains('breach') ||
        normalized.contains('fire') ||
        normalized.contains('welfare') ||
        normalized.contains('distress') ||
        normalized.contains('immediate dispatch') ||
        normalized.contains('client wants');
  }

  String _personaIdForRecommendationTarget(OnyxToolTarget target) {
    return switch (target) {
      OnyxToolTarget.dispatchBoard => 'dispatch',
      OnyxToolTarget.tacticalTrack => 'telemetry',
      OnyxToolTarget.cctvReview => 'camera',
      OnyxToolTarget.clientComms => 'client',
      OnyxToolTarget.reportsWorkspace => 'report',
    };
  }

  String _draftClientReply({required String scope, required String incident}) {
    final incidentLabel = incident.isEmpty
        ? 'the active War Room signal'
        : incident;
    return 'Client update for $scope:\n\n'
        'ONYX is actively verifying $incidentLabel and the response flow remains under control. '
        'We are checking Dispatch Board context, CCTV Review visibility, and Tactical Track posture now. '
        'I will send the next update as soon as the verification step is complete or the site status changes.';
  }

  String _telemetrySummary({required String scope, required String incident}) {
    final incidentLabel = incident.isEmpty
        ? 'current War Room signal picture'
        : incident;
    return 'Tactical Track scope: $scope\n'
        'Focus: $incidentLabel\n'
        'Detected posture: heart-rate spike paired with low movement confidence.\n'
        'Recommended controller sequence: confirm Tactical Track posture, check any matching Dispatch Board timestamps, then decide whether to escalate guard welfare.';
  }

  String _patrolVerificationSummary({required String scope}) {
    return 'Scope: $scope\n'
        'Checkpoint review staged against the expected baseline, photo evidence, and route continuity.\n'
        'What I am looking for: mismatched landmark cues, stale timestamps, wrong camera angle, or weak checkpoint coverage.';
  }

  String _reportNarrative({required String scope, required String incident}) {
    final incidentLabel = incident.isEmpty
        ? 'the current War Room signal'
        : incident;
    return 'Reports Workspace narrative for $scope:\n\n'
        'War room monitored $incidentLabel with CCTV Review, active responder posture checks, and scoped Client Comms readiness. '
        'The controller workflow remained inside the simplified ONYX stack, with Dispatch Board verification, Tactical Track continuity, and Client Comms handoff staged before closure or escalation. '
        'Any unresolved signal should stay flagged for the next shift with a concise continuity note.';
  }

  String _correlationSummary({
    required String scope,
    required String incident,
  }) {
    final incidentLabel = incident.isEmpty
        ? 'current War Room scope'
        : incident;
    return 'Signal Picture scope: $scope\n'
        'Focus: $incidentLabel\n'
        'Merged inputs: CCTV Review context, Dispatch Board state, Tactical Track posture, and Sovereign Ledger continuity.\n'
        'Suggested read: treat the combined evidence as one War Room picture, then classify it before dispatching the next external update.';
  }

  String _classificationSummary() {
    final incident = widget.focusIncidentReference.trim();
    final incidentLabel = incident.isEmpty
        ? 'current War Room signal'
        : incident;
    return 'Incident triage for $incidentLabel:\n'
        'False Alarm if the trigger resolves to sensor fault or clean visual context.\n'
        'Suspicious Activity if CCTV Review or patrol proof stays uncertain.\n'
        'Intrusion if alarm timing, movement, and visual context align strongly enough to justify escalation.';
  }

  String _systemHealthSummary() {
    return 'Governance Desk health check:\n'
        'Camera fleet: monitor reachability, stream uptime, and stale feeds.\n'
        'Device layer: flag cameras, NVRs, wearables, or integrations that stop reporting.\n'
        'Next step: validate the affected feed inside CCTV Review, then cross-check whether any active Dispatch Board triggers depend on that signal.';
  }

  String _debugSummary() {
    return 'War Room signal breakdown:\n'
        'Human: 84%\n'
        'Vehicle: 12%\n'
        'Unknown motion: 4%\n'
        'Interpretation: confidence is good enough for controller review, but not for unsupervised automation.';
  }

  String _policySummary() {
    return 'Governance Desk policy check:\n'
        'Thresholds should stay strict for auto-actions, softer for controller suggestions, and approval-gated for device writes.\n'
        'Escalation rules should prefer timed nudges and scoped handoffs over noisy global alerts.';
  }

  String _cameraProbeResult(String ip) {
    final target = ip.trim().isEmpty ? 'unknown target' : ip.trim();
    return 'Target: $target\n'
        'Ping: reachable on local network\n'
        'HTTP 80 / 443: device responds\n'
        'RTSP 554: open for stream validation\n'
        'ONVIF 8899: endpoint present, credentials still required\n'
        'Next step: confirm make / model, approved profile, and rollback target before any write action.';
  }

  String _incidentSummary(OnyxAgentContextSnapshot snapshot) {
    final scope = snapshot.scopeLabel;
    final incident = widget.focusIncidentReference.trim();
    final incidentLabel = incident.isEmpty
        ? 'current War Room scope'
        : incident;
    return 'Scope: $scope\n'
        'Focus: $incidentLabel\n'
        'Recommended sequence: verify Dispatch Board timing, confirm CCTV Review context, check Tactical Track posture, then shape the client update from Client Comms.\n'
        '${snapshot.toReasoningSummary()}\n'
        'The main brain will keep the handoff inside the simplified ONYX routes instead of reopening the legacy workspace.';
  }

  String _hhmm(DateTime timestamp) {
    final hh = timestamp.hour.toString().padLeft(2, '0');
    final mm = timestamp.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  _AgentMessage _userMessage({required String body}) {
    return _AgentMessage(
      id: 'message-${DateTime.now().microsecondsSinceEpoch}',
      kind: _AgentMessageKind.user,
      personaId: 'main',
      headline: '',
      body: body,
      createdAt: DateTime.now(),
    );
  }

  _AgentMessage _agentMessage({
    required String personaId,
    required String headline,
    required String body,
    List<_AgentActionCard> actions = const <_AgentActionCard>[],
  }) {
    return _AgentMessage(
      id: 'message-${DateTime.now().microsecondsSinceEpoch}-$personaId',
      kind: _AgentMessageKind.agent,
      personaId: personaId,
      headline: headline,
      body: body,
      createdAt: DateTime.now(),
      actions: actions,
    );
  }

  _AgentMessage _toolMessage({
    required String headline,
    required String body,
    List<_AgentActionCard> actions = const <_AgentActionCard>[],
  }) {
    return _AgentMessage(
      id: 'message-${DateTime.now().microsecondsSinceEpoch}-tool',
      kind: _AgentMessageKind.tool,
      personaId: 'camera',
      headline: headline,
      body: body,
      createdAt: DateTime.now(),
      actions: actions,
    );
  }

  _AgentActionCard _action({
    required String id,
    required _AgentActionKind kind,
    required String label,
    required String detail,
    String payload = '',
    Map<String, String> arguments = const <String, String>{},
    bool requiresApproval = false,
    bool opensRoute = false,
    required String personaId,
  }) {
    return _AgentActionCard(
      id: id,
      kind: kind,
      label: label,
      detail: detail,
      payload: payload,
      arguments: arguments,
      requiresApproval: requiresApproval,
      opensRoute: opensRoute,
      personaId: personaId,
    );
  }
}
