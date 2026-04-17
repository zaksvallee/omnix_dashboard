import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../application/ai/ollama_service.dart';
import '../application/feature_flags.dart';
import '../application/morning_sovereign_report_service.dart';
import '../application/monitoring_scene_review_store.dart';
import '../application/onyx_agent_client_draft_service.dart';
import '../application/onyx_agent_cloud_boost_service.dart';
import '../application/simulation/scenario_replay_history_signal_service.dart';
import '../application/supabase/supabase_service.dart';
import '../application/zara_theatre/zara_action_executor.dart';
import '../application/zara_theatre/zara_intent_parser.dart';
import '../application/zara_theatre/zara_theatre_orchestrator.dart';
import '../domain/events/dispatch_event.dart';
import 'events_route_source.dart';
import 'live_operations_page.dart';
import 'zara_theatre_panel.dart';

class CommandCenterPage extends StatefulWidget {
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
  final Stream<List<DispatchEvent>>? theatreEventStream;
  final ZaraActionExecutor Function() createTheatreActionExecutor;
  final OnyxAgentCloudBoostService Function()? createTheatreCloudBoostService;
  final SupabaseClient? theatreSupabaseClient;
  final String theatreOllamaModel;
  final Uri? theatreOllamaEndpoint;
  final String Function()? theatreControllerUserIdProvider;
  final String Function()? theatreOrgIdProvider;

  const CommandCenterPage({
    super.key,
    required this.events,
    required this.createTheatreActionExecutor,
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
    this.theatreEventStream,
    this.createTheatreCloudBoostService,
    this.theatreSupabaseClient,
    this.theatreOllamaModel = 'mistral:7b-instruct-q5_K_M',
    this.theatreOllamaEndpoint,
    this.theatreControllerUserIdProvider,
    this.theatreOrgIdProvider,
  });

  @override
  State<CommandCenterPage> createState() => _CommandCenterPageState();
}

class _CommandCenterPageState extends State<CommandCenterPage> {
  late final http.Client _ollamaClient;
  late final ZaraTheatreOrchestrator _theatreOrchestrator;

  @override
  void initState() {
    super.initState();
    _ollamaClient = http.Client();
    _theatreOrchestrator = ZaraTheatreOrchestrator(
      intentParser: ZaraIntentParser(
        ollamaService: _buildOllamaService(),
        cloudBoostService:
            widget.createTheatreCloudBoostService?.call() ??
            const UnconfiguredOnyxAgentCloudBoostService(),
        localModel: widget.theatreOllamaModel.trim().isEmpty
            ? 'mistral:7b-instruct-q5_K_M'
            : widget.theatreOllamaModel.trim(),
      ),
      actionExecutor: widget.createTheatreActionExecutor(),
      eventStream: widget.theatreEventStream,
      supabaseService: widget.theatreSupabaseClient == null
          ? null
          : SupabaseService(client: widget.theatreSupabaseClient!),
      controllerUserIdProvider: widget.theatreControllerUserIdProvider,
      orgIdProvider: widget.theatreOrgIdProvider,
    );
    if (widget.events.isNotEmpty) {
      _theatreOrchestrator.seedEvents(widget.events);
    }
  }

  @override
  void dispose() {
    _theatreOrchestrator.dispose();
    _ollamaClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LiveOperationsPage(
      events: widget.events,
      morningSovereignReportHistory: widget.morningSovereignReportHistory,
      historicalSyntheticLearningLabels:
          widget.historicalSyntheticLearningLabels,
      historicalShadowMoLabels: widget.historicalShadowMoLabels,
      historicalShadowStrengthLabels: widget.historicalShadowStrengthLabels,
      previousTomorrowUrgencySummary: widget.previousTomorrowUrgencySummary,
      focusIncidentReference: widget.focusIncidentReference,
      agentReturnIncidentReference: widget.agentReturnIncidentReference,
      onConsumeAgentReturnIncidentReference:
          widget.onConsumeAgentReturnIncidentReference,
      initialScopeClientId: widget.initialScopeClientId,
      initialScopeSiteId: widget.initialScopeSiteId,
      videoOpsLabel: widget.videoOpsLabel,
      sceneReviewByIntelligenceId: widget.sceneReviewByIntelligenceId,
      clientCommsSnapshot: widget.clientCommsSnapshot,
      controlInboxSnapshot: widget.controlInboxSnapshot,
      clientDraftService: widget.clientDraftService,
      onLoadCameraHealthFactPacketForScope:
          widget.onLoadCameraHealthFactPacketForScope,
      onOpenExternalUri: widget.onOpenExternalUri,
      onOpenClientView: widget.onOpenClientView,
      onOpenClientViewForScope: widget.onOpenClientViewForScope,
      onStageClientDraftForScope: widget.onStageClientDraftForScope,
      onClearLearnedLaneStyleForScope: widget.onClearLearnedLaneStyleForScope,
      onSetLaneVoiceProfileForScope: widget.onSetLaneVoiceProfileForScope,
      onUpdateClientReplyDraftText: widget.onUpdateClientReplyDraftText,
      onApproveClientReplyDraft: widget.onApproveClientReplyDraft,
      onRejectClientReplyDraft: widget.onRejectClientReplyDraft,
      onOpenEventsForScope: widget.onOpenEventsForScope,
      onOpenAlarms: widget.onOpenAlarms,
      onOpenAlarmsForIncident: widget.onOpenAlarmsForIncident,
      onOpenAgentForIncident: widget.onOpenAgentForIncident,
      onOpenGuards: widget.onOpenGuards,
      onOpenRosterPlanner: widget.onOpenRosterPlanner,
      onOpenRosterAudit: widget.onOpenRosterAudit,
      onOpenLatestAudit: widget.onOpenLatestAudit,
      onAutoAuditAction: widget.onAutoAuditAction,
      latestAutoAuditReceipt: widget.latestAutoAuditReceipt,
      onOpenCctv: widget.onOpenCctv,
      onOpenCctvForIncident: widget.onOpenCctvForIncident,
      onOpenTrackForIncident: widget.onOpenTrackForIncident,
      onOpenVipProtection: widget.onOpenVipProtection,
      onOpenRiskIntel: widget.onOpenRiskIntel,
      queueStateHintSeen: widget.queueStateHintSeen,
      onQueueStateHintSeen: widget.onQueueStateHintSeen,
      onQueueStateHintReset: widget.onQueueStateHintReset,
      guardRosterSignalLabel: widget.guardRosterSignalLabel,
      guardRosterSignalHeadline: widget.guardRosterSignalHeadline,
      guardRosterSignalDetail: widget.guardRosterSignalDetail,
      guardRosterSignalAccent: widget.guardRosterSignalAccent,
      guardRosterSignalNeedsAttention: widget.guardRosterSignalNeedsAttention,
      scenarioReplayHistorySignalService:
          widget.scenarioReplayHistorySignalService,
      theatrePanel: kZaraTheatreEnabled
          ? Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: ZaraTheatrePanel(orchestrator: _theatreOrchestrator),
            )
          : null,
    );
  }

  OllamaService _buildOllamaService() {
    final endpoint = widget.theatreOllamaEndpoint;
    if (endpoint == null) {
      return const UnconfiguredOllamaService();
    }
    return HttpOllamaService(client: _ollamaClient, endpoint: endpoint);
  }
}
