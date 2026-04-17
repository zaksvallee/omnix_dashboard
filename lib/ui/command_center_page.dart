import 'package:flutter/material.dart';

import '../application/morning_sovereign_report_service.dart';
import '../application/monitoring_scene_review_store.dart';
import '../application/onyx_agent_client_draft_service.dart';
import '../application/simulation/scenario_replay_history_signal_service.dart';
import '../application/feature_flags.dart';
import '../application/zara_theatre/zara_theatre_orchestrator.dart';
import '../domain/events/dispatch_event.dart';
import 'events_route_source.dart';
import 'live_operations_page.dart';
import 'zara_theatre_panel.dart';

class CommandCenterPage extends StatelessWidget {
  final List<DispatchEvent> events;
  final List<SovereignReport> morningSovereignReportHistory;
  final List<String> historicalSyntheticLearningLabels;
  final List<String> historicalShadowMoLabels;
  final List<String> historicalShadowStrengthLabels;
  final String previousTomorrowUrgencySummary;
  final String focusIncidentReference;
  final String? agentReturnIncidentReference;
  final ValueChanged<String>? onConsumeAgentReturnIncidentReference;
  final String? initialScopeClientId;
  final String? initialScopeSiteId;
  final String videoOpsLabel;
  final Map<String, MonitoringSceneReviewRecord> sceneReviewByIntelligenceId;
  final LiveClientCommsSnapshot? clientCommsSnapshot;
  final LiveControlInboxSnapshot? controlInboxSnapshot;
  final OnyxAgentClientDraftService? clientDraftService;
  final LiveOpsCameraHealthLoader? onLoadCameraHealthFactPacketForScope;
  final LiveOpsExternalUriOpener? onOpenExternalUri;
  final VoidCallback? onOpenClientView;
  final void Function(String clientId, String siteId)? onOpenClientViewForScope;
  final LiveOpsStageClientDraftCallback? onStageClientDraftForScope;
  final Future<void> Function(String clientId, String siteId)?
  onClearLearnedLaneStyleForScope;
  final Future<void> Function(
    String clientId,
    String siteId,
    String? profileSignal,
  )?
  onSetLaneVoiceProfileForScope;
  final Future<void> Function(int updateId, String draftText)?
  onUpdateClientReplyDraftText;
  final Future<String> Function(int updateId, {String? approvedText})?
  onApproveClientReplyDraft;
  final Future<String> Function(int updateId)? onRejectClientReplyDraft;
  final EventsScopeCallback? onOpenEventsForScope;
  final VoidCallback? onOpenAlarms;
  final void Function(String incidentReference)? onOpenAlarmsForIncident;
  final void Function(String incidentReference)? onOpenAgentForIncident;
  final VoidCallback? onOpenGuards;
  final VoidCallback? onOpenRosterPlanner;
  final VoidCallback? onOpenRosterAudit;
  final VoidCallback? onOpenLatestAudit;
  final void Function(String action, String detail)? onAutoAuditAction;
  final LiveOpsAutoAuditReceipt? latestAutoAuditReceipt;
  final VoidCallback? onOpenCctv;
  final void Function(String incidentReference)? onOpenCctvForIncident;
  final void Function(String incidentReference)? onOpenTrackForIncident;
  final VoidCallback? onOpenVipProtection;
  final VoidCallback? onOpenRiskIntel;
  final bool queueStateHintSeen;
  final VoidCallback? onQueueStateHintSeen;
  final VoidCallback? onQueueStateHintReset;
  final String? guardRosterSignalLabel;
  final String? guardRosterSignalHeadline;
  final String? guardRosterSignalDetail;
  final Color? guardRosterSignalAccent;
  final bool guardRosterSignalNeedsAttention;
  final ScenarioReplayHistorySignalService scenarioReplayHistorySignalService;
  final ZaraTheatreOrchestrator theatreOrchestrator;

  const CommandCenterPage({
    super.key,
    required this.events,
    required this.theatreOrchestrator,
    this.morningSovereignReportHistory = const <SovereignReport>[],
    this.historicalSyntheticLearningLabels = const <String>[],
    this.historicalShadowMoLabels = const <String>[],
    this.historicalShadowStrengthLabels = const <String>[],
    this.previousTomorrowUrgencySummary = '',
    this.focusIncidentReference = '',
    this.agentReturnIncidentReference,
    this.onConsumeAgentReturnIncidentReference,
    this.initialScopeClientId,
    this.initialScopeSiteId,
    this.videoOpsLabel = 'CCTV',
    this.sceneReviewByIntelligenceId = const {},
    this.clientCommsSnapshot,
    this.controlInboxSnapshot,
    this.clientDraftService,
    this.onLoadCameraHealthFactPacketForScope,
    this.onOpenExternalUri,
    this.onOpenClientView,
    this.onOpenClientViewForScope,
    this.onStageClientDraftForScope,
    this.onClearLearnedLaneStyleForScope,
    this.onSetLaneVoiceProfileForScope,
    this.onUpdateClientReplyDraftText,
    this.onApproveClientReplyDraft,
    this.onRejectClientReplyDraft,
    this.onOpenEventsForScope,
    this.onOpenAlarms,
    this.onOpenAlarmsForIncident,
    this.onOpenAgentForIncident,
    this.onOpenGuards,
    this.onOpenRosterPlanner,
    this.onOpenRosterAudit,
    this.onOpenLatestAudit,
    this.onAutoAuditAction,
    this.latestAutoAuditReceipt,
    this.onOpenCctv,
    this.onOpenCctvForIncident,
    this.onOpenTrackForIncident,
    this.onOpenVipProtection,
    this.onOpenRiskIntel,
    this.queueStateHintSeen = false,
    this.onQueueStateHintSeen,
    this.onQueueStateHintReset,
    this.guardRosterSignalLabel,
    this.guardRosterSignalHeadline,
    this.guardRosterSignalDetail,
    this.guardRosterSignalAccent,
    this.guardRosterSignalNeedsAttention = false,
    this.scenarioReplayHistorySignalService =
        const LocalScenarioReplayHistorySignalService(),
  });

  @override
  Widget build(BuildContext context) {
    return LiveOperationsPage(
      events: events,
      morningSovereignReportHistory: morningSovereignReportHistory,
      historicalSyntheticLearningLabels: historicalSyntheticLearningLabels,
      historicalShadowMoLabels: historicalShadowMoLabels,
      historicalShadowStrengthLabels: historicalShadowStrengthLabels,
      previousTomorrowUrgencySummary: previousTomorrowUrgencySummary,
      focusIncidentReference: focusIncidentReference,
      agentReturnIncidentReference: agentReturnIncidentReference,
      onConsumeAgentReturnIncidentReference:
          onConsumeAgentReturnIncidentReference,
      initialScopeClientId: initialScopeClientId,
      initialScopeSiteId: initialScopeSiteId,
      videoOpsLabel: videoOpsLabel,
      sceneReviewByIntelligenceId: sceneReviewByIntelligenceId,
      clientCommsSnapshot: clientCommsSnapshot,
      controlInboxSnapshot: controlInboxSnapshot,
      clientDraftService: clientDraftService,
      onLoadCameraHealthFactPacketForScope:
          onLoadCameraHealthFactPacketForScope,
      onOpenExternalUri: onOpenExternalUri,
      onOpenClientView: onOpenClientView,
      onOpenClientViewForScope: onOpenClientViewForScope,
      onStageClientDraftForScope: onStageClientDraftForScope,
      onClearLearnedLaneStyleForScope: onClearLearnedLaneStyleForScope,
      onSetLaneVoiceProfileForScope: onSetLaneVoiceProfileForScope,
      onUpdateClientReplyDraftText: onUpdateClientReplyDraftText,
      onApproveClientReplyDraft: onApproveClientReplyDraft,
      onRejectClientReplyDraft: onRejectClientReplyDraft,
      onOpenEventsForScope: onOpenEventsForScope,
      onOpenAlarms: onOpenAlarms,
      onOpenAlarmsForIncident: onOpenAlarmsForIncident,
      onOpenAgentForIncident: onOpenAgentForIncident,
      onOpenGuards: onOpenGuards,
      onOpenRosterPlanner: onOpenRosterPlanner,
      onOpenRosterAudit: onOpenRosterAudit,
      onOpenLatestAudit: onOpenLatestAudit,
      onAutoAuditAction: onAutoAuditAction,
      latestAutoAuditReceipt: latestAutoAuditReceipt,
      onOpenCctv: onOpenCctv,
      onOpenCctvForIncident: onOpenCctvForIncident,
      onOpenTrackForIncident: onOpenTrackForIncident,
      onOpenVipProtection: onOpenVipProtection,
      onOpenRiskIntel: onOpenRiskIntel,
      queueStateHintSeen: queueStateHintSeen,
      onQueueStateHintSeen: onQueueStateHintSeen,
      onQueueStateHintReset: onQueueStateHintReset,
      guardRosterSignalLabel: guardRosterSignalLabel,
      guardRosterSignalHeadline: guardRosterSignalHeadline,
      guardRosterSignalDetail: guardRosterSignalDetail,
      guardRosterSignalAccent: guardRosterSignalAccent,
      guardRosterSignalNeedsAttention: guardRosterSignalNeedsAttention,
      scenarioReplayHistorySignalService: scenarioReplayHistorySignalService,
      theatrePanel: kZaraTheatreEnabled
          ? Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: ZaraTheatrePanel(orchestrator: theatreOrchestrator),
            )
          : null,
    );
  }
}
