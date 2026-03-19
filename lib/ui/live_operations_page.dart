import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';

import '../application/client_delivery_message_formatter.dart';
import '../application/hazard_response_directive_service.dart';
import '../application/morning_sovereign_report_service.dart';
import '../application/monitoring_global_posture_service.dart';
import '../application/monitoring_orchestrator_service.dart';
import '../application/monitoring_synthetic_war_room_service.dart';
import '../domain/events/decision_created.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/events/execution_completed.dart';
import '../domain/events/execution_denied.dart';
import '../domain/events/guard_checked_in.dart';
import '../domain/events/incident_closed.dart';
import '../domain/events/intelligence_received.dart';
import '../domain/events/partner_dispatch_status_declared.dart';
import '../domain/events/patrol_completed.dart';
import '../domain/events/response_arrived.dart';
import '../application/monitoring_scene_review_store.dart';
import '../application/site_activity_intelligence_service.dart';
import '../application/synthetic_promotion_summary_formatter.dart';
import '../application/monitoring_watch_action_plan.dart';
import '../application/shadow_mo_dossier_contract.dart';
import 'layout_breakpoints.dart';
import 'onyx_surface.dart';
import 'ui_action_logger.dart';

enum _IncidentPriority { p1Critical, p2High, p3Medium, p4Low }

enum _IncidentStatus { triaging, dispatched, investigating, resolved }

enum _LadderStepStatus { completed, active, thinking, pending, blocked }

enum _ContextTab { details, voip, visual }

enum _FocusLinkState { none, exact, scopeBacked, seeded }

enum _LedgerType { aiAction, humanOverride, systemEvent, escalation }

enum _ControlInboxDraftCueKind {
  timing,
  sensitive,
  detail,
  validation,
  reassurance,
  formal,
  concise,
  defaultReassurance,
}

class _IncidentRecord {
  final String id;
  final String clientId;
  final String regionId;
  final String siteId;
  final _IncidentPriority priority;
  final String type;
  final String site;
  final String timestamp;
  final _IncidentStatus status;
  final String? latestIntelHeadline;
  final String? latestIntelSummary;
  final String? latestSceneReviewLabel;
  final String? latestSceneReviewSummary;
  final String? latestSceneDecisionLabel;
  final String? latestSceneDecisionSummary;
  final String? snapshotUrl;
  final String? clipUrl;

  const _IncidentRecord({
    required this.id,
    this.clientId = '',
    this.regionId = '',
    this.siteId = '',
    required this.priority,
    required this.type,
    required this.site,
    required this.timestamp,
    required this.status,
    this.latestIntelHeadline,
    this.latestIntelSummary,
    this.latestSceneReviewLabel,
    this.latestSceneReviewSummary,
    this.latestSceneDecisionLabel,
    this.latestSceneDecisionSummary,
    this.snapshotUrl,
    this.clipUrl,
  });

  _IncidentRecord copyWith({
    String? id,
    String? clientId,
    String? regionId,
    String? siteId,
    _IncidentPriority? priority,
    String? type,
    String? site,
    String? timestamp,
    _IncidentStatus? status,
    String? latestIntelHeadline,
    String? latestIntelSummary,
    String? latestSceneReviewLabel,
    String? latestSceneReviewSummary,
    String? latestSceneDecisionLabel,
    String? latestSceneDecisionSummary,
    String? snapshotUrl,
    String? clipUrl,
  }) {
    return _IncidentRecord(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      regionId: regionId ?? this.regionId,
      siteId: siteId ?? this.siteId,
      priority: priority ?? this.priority,
      type: type ?? this.type,
      site: site ?? this.site,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      latestIntelHeadline: latestIntelHeadline ?? this.latestIntelHeadline,
      latestIntelSummary: latestIntelSummary ?? this.latestIntelSummary,
      latestSceneReviewLabel:
          latestSceneReviewLabel ?? this.latestSceneReviewLabel,
      latestSceneReviewSummary:
          latestSceneReviewSummary ?? this.latestSceneReviewSummary,
      latestSceneDecisionLabel:
          latestSceneDecisionLabel ?? this.latestSceneDecisionLabel,
      latestSceneDecisionSummary:
          latestSceneDecisionSummary ?? this.latestSceneDecisionSummary,
      snapshotUrl: snapshotUrl ?? this.snapshotUrl,
      clipUrl: clipUrl ?? this.clipUrl,
    );
  }
}

const _hazardDirectiveService = HazardResponseDirectiveService();
const _globalPostureService = MonitoringGlobalPostureService();
const _syntheticWarRoomService = MonitoringSyntheticWarRoomService();

class _LadderStep {
  final String id;
  final String name;
  final _LadderStepStatus status;
  final String? timestamp;
  final String? details;
  final String? metadata;
  final String? thinkingMessage;

  const _LadderStep({
    required this.id,
    required this.name,
    required this.status,
    this.timestamp,
    this.details,
    this.metadata,
    this.thinkingMessage,
  });
}

class _LedgerEntry {
  final String id;
  final DateTime timestamp;
  final _LedgerType type;
  final String description;
  final String? actor;
  final String hash;
  final bool verified;
  final String? reasonCode;

  const _LedgerEntry({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.description,
    this.actor,
    required this.hash,
    required this.verified,
    this.reasonCode,
  });
}

class _GuardVigilance {
  final String callsign;
  final int decayLevel;
  final String lastCheckIn;
  final List<int> sparkline;

  const _GuardVigilance({
    required this.callsign,
    required this.decayLevel,
    required this.lastCheckIn,
    required this.sparkline,
  });
}

class _SuppressedSceneReviewContext {
  final IntelligenceReceived intelligence;
  final MonitoringSceneReviewRecord review;

  const _SuppressedSceneReviewContext({
    required this.intelligence,
    required this.review,
  });
}

class _PartnerLiveProgressSummary {
  final String dispatchId;
  final String clientId;
  final String siteId;
  final String partnerLabel;
  final PartnerDispatchStatus latestStatus;
  final DateTime latestOccurredAt;
  final int declarationCount;
  final Map<PartnerDispatchStatus, DateTime> firstOccurrenceByStatus;

  const _PartnerLiveProgressSummary({
    required this.dispatchId,
    required this.clientId,
    required this.siteId,
    required this.partnerLabel,
    required this.latestStatus,
    required this.latestOccurredAt,
    required this.declarationCount,
    required this.firstOccurrenceByStatus,
  });
}

class _PartnerLiveTrendSummary {
  final int reportDays;
  final String currentScoreLabel;
  final String trendLabel;
  final String trendReason;

  const _PartnerLiveTrendSummary({
    required this.reportDays,
    required this.currentScoreLabel,
    required this.trendLabel,
    required this.trendReason,
  });
}

class LiveClientCommsSnapshot {
  final String clientId;
  final String siteId;
  final String clientVoiceProfileLabel;
  final int learnedApprovalStyleCount;
  final String learnedApprovalStyleExample;
  final int pendingLearnedStyleDraftCount;
  final int totalMessages;
  final int clientInboundCount;
  final int pendingApprovalCount;
  final int queuedPushCount;
  final String telegramHealthLabel;
  final String? telegramHealthDetail;
  final bool telegramFallbackActive;
  final String pushSyncStatusLabel;
  final String? pushSyncFailureReason;
  final String smsFallbackLabel;
  final bool smsFallbackReady;
  final bool smsFallbackEligibleNow;
  final String voiceReadinessLabel;
  final String? deliveryReadinessDetail;
  final String? latestSmsFallbackStatus;
  final DateTime? latestSmsFallbackAtUtc;
  final String? latestVoipStageStatus;
  final DateTime? latestVoipStageAtUtc;
  final List<String> recentDeliveryHistoryLines;
  final String? latestClientMessage;
  final DateTime? latestClientMessageAtUtc;
  final String? latestOnyxReply;
  final DateTime? latestOnyxReplyAtUtc;
  final String? latestPendingDraft;
  final DateTime? latestPendingDraftAtUtc;

  const LiveClientCommsSnapshot({
    required this.clientId,
    required this.siteId,
    this.clientVoiceProfileLabel = 'Auto',
    this.learnedApprovalStyleCount = 0,
    this.learnedApprovalStyleExample = '',
    this.pendingLearnedStyleDraftCount = 0,
    this.totalMessages = 0,
    this.clientInboundCount = 0,
    this.pendingApprovalCount = 0,
    this.queuedPushCount = 0,
    this.telegramHealthLabel = 'disabled',
    this.telegramHealthDetail,
    this.telegramFallbackActive = false,
    this.pushSyncStatusLabel = 'idle',
    this.pushSyncFailureReason,
    this.smsFallbackLabel = 'SMS not ready',
    this.smsFallbackReady = false,
    this.smsFallbackEligibleNow = false,
    this.voiceReadinessLabel = 'VoIP staging',
    this.deliveryReadinessDetail,
    this.latestSmsFallbackStatus,
    this.latestSmsFallbackAtUtc,
    this.latestVoipStageStatus,
    this.latestVoipStageAtUtc,
    this.recentDeliveryHistoryLines = const <String>[],
    this.latestClientMessage,
    this.latestClientMessageAtUtc,
    this.latestOnyxReply,
    this.latestOnyxReplyAtUtc,
    this.latestPendingDraft,
    this.latestPendingDraftAtUtc,
  });
}

class LiveControlInboxDraft {
  final int updateId;
  final String clientId;
  final String siteId;
  final String clientVoiceProfileLabel;
  final String sourceText;
  final String draftText;
  final String providerLabel;
  final bool usesLearnedApprovalStyle;
  final DateTime createdAtUtc;
  final bool matchesSelectedScope;

  const LiveControlInboxDraft({
    required this.updateId,
    required this.clientId,
    required this.siteId,
    this.clientVoiceProfileLabel = 'Auto',
    required this.sourceText,
    required this.draftText,
    required this.providerLabel,
    this.usesLearnedApprovalStyle = false,
    required this.createdAtUtc,
    this.matchesSelectedScope = false,
  });
}

class LiveControlInboxClientAsk {
  final String clientId;
  final String siteId;
  final String author;
  final String body;
  final String messageProvider;
  final DateTime occurredAtUtc;
  final bool matchesSelectedScope;

  const LiveControlInboxClientAsk({
    required this.clientId,
    required this.siteId,
    required this.author,
    required this.body,
    required this.messageProvider,
    required this.occurredAtUtc,
    this.matchesSelectedScope = false,
  });
}

class LiveControlInboxSnapshot {
  final String selectedClientId;
  final String selectedSiteId;
  final String selectedScopeClientVoiceProfileLabel;
  final int pendingApprovalCount;
  final int selectedScopePendingCount;
  final int awaitingResponseCount;
  final String telegramHealthLabel;
  final String? telegramHealthDetail;
  final bool telegramFallbackActive;
  final List<LiveControlInboxDraft> pendingDrafts;
  final List<LiveControlInboxClientAsk> liveClientAsks;

  const LiveControlInboxSnapshot({
    required this.selectedClientId,
    required this.selectedSiteId,
    this.selectedScopeClientVoiceProfileLabel = 'Auto',
    this.pendingApprovalCount = 0,
    this.selectedScopePendingCount = 0,
    this.awaitingResponseCount = 0,
    this.telegramHealthLabel = 'disabled',
    this.telegramHealthDetail,
    this.telegramFallbackActive = false,
    this.pendingDrafts = const <LiveControlInboxDraft>[],
    this.liveClientAsks = const <LiveControlInboxClientAsk>[],
  });
}

class LiveOperationsPage extends StatefulWidget {
  final List<DispatchEvent> events;
  final List<SovereignReport> morningSovereignReportHistory;
  final List<String> historicalSyntheticLearningLabels;
  final List<String> historicalShadowMoLabels;
  final List<String> historicalShadowStrengthLabels;
  final String previousTomorrowUrgencySummary;
  final String focusIncidentReference;
  final String? initialScopeClientId;
  final String? initialScopeSiteId;
  final String videoOpsLabel;
  final Map<String, MonitoringSceneReviewRecord> sceneReviewByIntelligenceId;
  final LiveClientCommsSnapshot? clientCommsSnapshot;
  final LiveControlInboxSnapshot? controlInboxSnapshot;
  final VoidCallback? onOpenClientView;
  final void Function(String clientId, String siteId)? onOpenClientViewForScope;
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
  final void Function(List<String> eventIds, String? selectedEventId)?
  onOpenEventsForScope;
  final bool queueStateHintSeen;
  final VoidCallback? onQueueStateHintSeen;
  final VoidCallback? onQueueStateHintReset;

  const LiveOperationsPage({
    super.key,
    required this.events,
    this.morningSovereignReportHistory = const <SovereignReport>[],
    this.historicalSyntheticLearningLabels = const <String>[],
    this.historicalShadowMoLabels = const <String>[],
    this.historicalShadowStrengthLabels = const <String>[],
    this.previousTomorrowUrgencySummary = '',
    this.focusIncidentReference = '',
    this.initialScopeClientId,
    this.initialScopeSiteId,
    this.videoOpsLabel = 'CCTV',
    this.sceneReviewByIntelligenceId = const {},
    this.clientCommsSnapshot,
    this.controlInboxSnapshot,
    this.onOpenClientView,
    this.onOpenClientViewForScope,
    this.onClearLearnedLaneStyleForScope,
    this.onSetLaneVoiceProfileForScope,
    this.onUpdateClientReplyDraftText,
    this.onApproveClientReplyDraft,
    this.onRejectClientReplyDraft,
    this.onOpenEventsForScope,
    this.queueStateHintSeen = false,
    this.onQueueStateHintSeen,
    this.onQueueStateHintReset,
  });

  @override
  State<LiveOperationsPage> createState() => _LiveOperationsPageState();

  static void debugResetQueueStateHintSession() {
    _LiveOperationsPageState.debugResetQueueStateHintSession();
  }
}

class _LiveOperationsPageState extends State<LiveOperationsPage> {
  static const _siteActivityService = SiteActivityIntelligenceService();
  static const _orchestratorService = MonitoringOrchestratorService();
  static const _overrideReasonCodes = [
    'DUPLICATE_SIGNAL',
    'FALSE_ALARM',
    'TEST_EVENT',
    'CLIENT_VERIFIED_SAFE',
    'HARDWARE_FAULT',
  ];
  static bool _queueStateHintSeenThisSession = false;

  List<_IncidentRecord> _incidents = const [];
  List<_LedgerEntry> _projectedLedger = const [];
  List<_GuardVigilance> _vigilance = const [];
  final List<_LedgerEntry> _manualLedger = [];
  final Map<String, _IncidentStatus> _statusOverrides = {};
  Set<int> _controlInboxBusyDraftIds = <int>{};
  Set<int> _controlInboxDraftEditBusyIds = <int>{};
  Set<String> _learnedStyleBusyScopeKeys = <String>{};
  Set<String> _laneVoiceBusyScopeKeys = <String>{};
  final GlobalKey _controlInboxPanelGlobalKey = GlobalKey();
  bool _controlInboxPriorityOnly = false;
  _ControlInboxDraftCueKind? _controlInboxCueOnlyKind;
  late bool _showQueueStateHint;
  String? _activeIncidentId;
  String _resolvedFocusReference = '';
  _FocusLinkState _focusLinkState = _FocusLinkState.none;
  _ContextTab _activeTab = _ContextTab.details;

  VoidCallback? _openClientLaneAction({
    required String clientId,
    required String siteId,
  }) {
    final scopedCallback = widget.onOpenClientViewForScope;
    if (scopedCallback != null) {
      return () => scopedCallback(clientId, siteId);
    }
    return widget.onOpenClientView;
  }

  String _scopeBusyKey(String clientId, String siteId) =>
      '${clientId.trim()}|${siteId.trim()}';

  static void debugResetQueueStateHintSession() {
    _queueStateHintSeenThisSession = false;
  }

  void _markQueueStateHintSeen() {
    _queueStateHintSeenThisSession = true;
    _showQueueStateHint = false;
    widget.onQueueStateHintSeen?.call();
  }

  void _restoreQueueStateHint() {
    _queueStateHintSeenThisSession = false;
    _showQueueStateHint = true;
    widget.onQueueStateHintReset?.call();
  }

  Future<void> _clearLearnedLaneStyle(LiveClientCommsSnapshot snapshot) async {
    final callback = widget.onClearLearnedLaneStyleForScope;
    if (callback == null) {
      return;
    }
    final clientId = snapshot.clientId.trim();
    final siteId = snapshot.siteId.trim();
    if (clientId.isEmpty || siteId.isEmpty) {
      return;
    }
    final key = _scopeBusyKey(clientId, siteId);
    if (_learnedStyleBusyScopeKeys.contains(key)) {
      return;
    }
    setState(() {
      _learnedStyleBusyScopeKeys = <String>{..._learnedStyleBusyScopeKeys, key};
    });
    try {
      await callback(clientId, siteId);
    } finally {
      if (mounted) {
        setState(() {
          _learnedStyleBusyScopeKeys = Set<String>.from(
            _learnedStyleBusyScopeKeys,
          )..remove(key);
        });
      }
    }
  }

  Future<void> _setLaneVoiceProfile(
    LiveClientCommsSnapshot snapshot,
    String? profileSignal,
  ) async {
    final callback = widget.onSetLaneVoiceProfileForScope;
    if (callback == null) {
      return;
    }
    final clientId = snapshot.clientId.trim();
    final siteId = snapshot.siteId.trim();
    if (clientId.isEmpty || siteId.isEmpty) {
      return;
    }
    final key = _scopeBusyKey(clientId, siteId);
    if (_laneVoiceBusyScopeKeys.contains(key)) {
      return;
    }
    setState(() {
      _laneVoiceBusyScopeKeys = <String>{..._laneVoiceBusyScopeKeys, key};
    });
    try {
      await callback(clientId, siteId, profileSignal);
    } finally {
      if (mounted) {
        setState(() {
          _laneVoiceBusyScopeKeys = Set<String>.from(_laneVoiceBusyScopeKeys)
            ..remove(key);
        });
      }
    }
  }

  Future<void> _jumpToControlInboxPanel() async {
    final controlInboxSnapshot = widget.controlInboxSnapshot;
    final priorityDraftCount = controlInboxSnapshot == null
        ? 0
        : _controlInboxPriorityDraftCount(
            _sortedControlInboxDrafts(controlInboxSnapshot.pendingDrafts),
          );
    if (priorityDraftCount > 0 &&
        (!_controlInboxPriorityOnly || _controlInboxCueOnlyKind != null) &&
        mounted) {
      setState(() {
        _controlInboxPriorityOnly = true;
        _controlInboxCueOnlyKind = null;
      });
      await Future<void>.delayed(Duration.zero);
    }
    await _ensureControlInboxPanelVisible();
  }

  Future<void> _cycleControlInboxTopBarCueFilter() async {
    final filteredCueKind = _controlInboxCueOnlyKind;
    if (filteredCueKind != null &&
        _isControlInboxPriorityCueKind(filteredCueKind) &&
        mounted) {
      setState(() {
        _controlInboxPriorityOnly = true;
        _controlInboxCueOnlyKind = null;
      });
      await Future<void>.delayed(Duration.zero);
    }
    await _ensureControlInboxPanelVisible();
  }

  Future<void> _toggleTopBarPriorityFilter() async {
    if (_controlInboxPriorityOnly && _controlInboxCueOnlyKind == null && mounted) {
      setState(() {
        _controlInboxPriorityOnly = false;
      });
      await Future<void>.delayed(Duration.zero);
      await _ensureControlInboxPanelVisible();
      return;
    }
    await _jumpToControlInboxPanel();
  }

  Future<void> _cycleControlInboxQueueStateChip() async {
    if (_controlInboxCueOnlyKind != null) {
      if (mounted) {
        setState(() {
          _markQueueStateHintSeen();
        });
      }
      await _cycleControlInboxTopBarCueFilter();
      return;
    }
    if (_controlInboxPriorityOnly && mounted) {
      setState(() {
        _controlInboxPriorityOnly = false;
        _markQueueStateHintSeen();
      });
      await Future<void>.delayed(Duration.zero);
      await _ensureControlInboxPanelVisible();
      return;
    }
    if (mounted) {
      setState(() {
        _markQueueStateHintSeen();
      });
    }
    await _jumpToControlInboxPanel();
  }

  void _dismissQueueStateHint() {
    if (!_showQueueStateHint) {
      return;
    }
    setState(() {
      _markQueueStateHintSeen();
    });
  }

  Future<void> _ensureControlInboxPanelVisible() async {
    final panelContext = _controlInboxPanelGlobalKey.currentContext;
    if (panelContext == null) {
      return;
    }
    await Scrollable.ensureVisible(
      panelContext,
      alignment: 0.04,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _toggleControlInboxPriorityOnly() {
    setState(() {
      _controlInboxPriorityOnly = !_controlInboxPriorityOnly;
      _controlInboxCueOnlyKind = null;
    });
  }

  void _clearControlInboxPriorityOnly() {
    if (!_controlInboxPriorityOnly && _controlInboxCueOnlyKind == null) {
      return;
    }
    setState(() {
      _controlInboxPriorityOnly = false;
      _controlInboxCueOnlyKind = null;
    });
  }

  void _toggleControlInboxCueOnlyKind(_ControlInboxDraftCueKind kind) {
    setState(() {
      if (_controlInboxCueOnlyKind == kind) {
        _controlInboxCueOnlyKind = null;
      } else {
        _controlInboxCueOnlyKind = kind;
        _controlInboxPriorityOnly = false;
      }
    });
  }

  bool _laneVoiceOptionSelected(
    LiveClientCommsSnapshot snapshot,
    String? signal,
  ) {
    return _laneVoiceOptionSelectedForLabel(
      snapshot.clientVoiceProfileLabel,
      signal,
    );
  }

  bool _laneVoiceOptionSelectedForLabel(String profileLabel, String? signal) {
    final normalizedLabel = profileLabel.trim().toLowerCase();
    return switch (signal) {
      null => normalizedLabel == 'auto',
      'concise-updates' => normalizedLabel == 'concise',
      'reassurance-forward' => normalizedLabel == 'reassuring',
      'validation-heavy' => normalizedLabel == 'validation-heavy',
      _ => false,
    };
  }

  bool _liveClientLaneCueContainsAny(String text, List<String> needles) {
    for (final needle in needles) {
      if (text.contains(needle)) {
        return true;
      }
    }
    return false;
  }

  _ControlInboxDraftCueKind _liveClientLaneCueKind(
    LiveClientCommsSnapshot snapshot,
  ) {
    final source = (snapshot.latestClientMessage ?? '').trim().toLowerCase();
    final reply = ((snapshot.latestPendingDraft ?? '').trim().isNotEmpty
            ? snapshot.latestPendingDraft
            : snapshot.latestOnyxReply)
        .toString()
        .trim()
        .toLowerCase();
    final learnedSignals =
        '${snapshot.clientVoiceProfileLabel.trim().toLowerCase()}\n${snapshot.learnedApprovalStyleExample.trim().toLowerCase()}';
    if (source.contains('eta') || source.contains('arrival')) {
      return _ControlInboxDraftCueKind.timing;
    }
    if (source.contains('panic') ||
        source.contains('armed') ||
        source.contains('medical') ||
        source.contains('fire')) {
      return _ControlInboxDraftCueKind.sensitive;
    }
    if (reply.contains('?')) {
      return _ControlInboxDraftCueKind.detail;
    }
    if (_liveClientLaneCueContainsAny(learnedSignals, const [
      'camera',
      'daylight',
      'visual',
      'camera check',
      'validation',
    ])) {
      return _ControlInboxDraftCueKind.validation;
    }
    if (_liveClientLaneCueContainsAny(learnedSignals, const [
      'reassuring',
      'reassurance',
      'comfort',
      'you are not alone',
      'treating this as live',
      'stay close',
      'protective',
    ])) {
      return _ControlInboxDraftCueKind.reassurance;
    }
    if (_liveClientLaneCueContainsAny(learnedSignals, const [
      'operations formal',
      'actively checking',
      'operations',
      'formal',
      'close review',
      'monitoring',
    ])) {
      return _ControlInboxDraftCueKind.formal;
    }
    return _ControlInboxDraftCueKind.defaultReassurance;
  }

  String _liveClientLaneCueMessage(_ControlInboxDraftCueKind kind) {
    return switch (kind) {
      _ControlInboxDraftCueKind.timing =>
        'Check that timing is not over-promised before sending.',
      _ControlInboxDraftCueKind.sensitive =>
        'High-sensitivity message. Keep the tone calm and do not imply resolution unless control confirmed it.',
      _ControlInboxDraftCueKind.detail =>
        'The reply asks for one missing detail, which is good when the scope is unclear.',
      _ControlInboxDraftCueKind.validation =>
        'Keep the camera wording concrete and make sure the exact check is clear before sending.',
      _ControlInboxDraftCueKind.reassurance =>
        'Lead with calm reassurance first, then the next confirmed step.',
      _ControlInboxDraftCueKind.formal =>
        'Keep the wording composed and operations-grade without slipping into robotic language.',
      _ControlInboxDraftCueKind.concise =>
        'Keep the reply short and make the next confirmed step clear.',
      _ControlInboxDraftCueKind.defaultReassurance =>
        'This draft is shaped for reassurance first, then the next confirmed step.',
    };
  }

  String _liveClientLaneCue(LiveClientCommsSnapshot snapshot) {
    return _liveClientLaneCueMessage(_liveClientLaneCueKind(snapshot));
  }

  _ControlInboxDraftCueKind _controlInboxDraftCueKindForSignals({
    required String sourceText,
    required String replyText,
    required String clientVoiceProfileLabel,
    required bool usesLearnedApprovalStyle,
  }) {
    final source = sourceText.trim().toLowerCase();
    final reply = replyText.trim().toLowerCase();
    final signals =
        '${clientVoiceProfileLabel.trim().toLowerCase()}\n$reply${usesLearnedApprovalStyle ? '\nlearned approval style' : ''}';
    if (source.contains('eta') ||
        source.contains('arrival') ||
        source.contains('arrived') ||
        source.contains('how long') ||
        reply.contains('eta') ||
        reply.contains('arrival') ||
        reply.contains('arrived')) {
      return _ControlInboxDraftCueKind.timing;
    }
    if (source.contains('panic') ||
        source.contains('armed') ||
        source.contains('medical') ||
        source.contains('fire')) {
      return _ControlInboxDraftCueKind.sensitive;
    }
    if (reply.contains('?')) {
      return _ControlInboxDraftCueKind.detail;
    }
    if (_liveClientLaneCueContainsAny(signals, const [
      'validation-heavy',
      'camera',
      'daylight',
      'visual',
      'validation',
      'verified position',
      'confirmed position',
    ])) {
      return _ControlInboxDraftCueKind.validation;
    }
    if (_liveClientLaneCueContainsAny(signals, const [
      'reassuring',
      'reassurance',
      'comfort',
      'you are not alone',
      'treating this as live',
      'stay close',
      'protective',
    ])) {
      return _ControlInboxDraftCueKind.reassurance;
    }
    if (_liveClientLaneCueContainsAny(signals, const [
      'operations formal',
      'actively checking',
      'operations',
      'formal',
      'close review',
      'monitoring',
    ])) {
      return _ControlInboxDraftCueKind.formal;
    }
    if (_liveClientLaneCueContainsAny(signals, const [
      'concise',
      'concise-updates',
      'short',
      'brief',
    ])) {
      return _ControlInboxDraftCueKind.concise;
    }
    return _ControlInboxDraftCueKind.defaultReassurance;
  }

  String _controlInboxDraftCueMessage(_ControlInboxDraftCueKind kind) {
    return switch (kind) {
      _ControlInboxDraftCueKind.timing =>
        'Check that timing is not over-promised before sending.',
      _ControlInboxDraftCueKind.sensitive =>
        'High-sensitivity message. Keep the tone calm and do not imply resolution unless control confirmed it.',
      _ControlInboxDraftCueKind.detail =>
        'The reply asks for one missing detail, which is good when the scope is unclear.',
      _ControlInboxDraftCueKind.validation =>
        'Keep the exact check concrete and make sure the next confirmed step is clear before sending.',
      _ControlInboxDraftCueKind.reassurance =>
        'Lead with calm reassurance first, then the next confirmed step.',
      _ControlInboxDraftCueKind.formal =>
        'Keep the wording composed and operations-grade without slipping into robotic language.',
      _ControlInboxDraftCueKind.concise =>
        'Keep the reply short and make the next confirmed step clear.',
      _ControlInboxDraftCueKind.defaultReassurance =>
        'This draft is shaped for reassurance first, then the next confirmed step.',
    };
  }

  String _controlInboxDraftCueForSignals({
    required String sourceText,
    required String replyText,
    required String clientVoiceProfileLabel,
    required bool usesLearnedApprovalStyle,
  }) {
    return _controlInboxDraftCueMessage(
      _controlInboxDraftCueKindForSignals(
        sourceText: sourceText,
        replyText: replyText,
        clientVoiceProfileLabel: clientVoiceProfileLabel,
        usesLearnedApprovalStyle: usesLearnedApprovalStyle,
      ),
    );
  }

  String _controlInboxDraftCueChipLabel(_ControlInboxDraftCueKind kind) {
    return switch (kind) {
      _ControlInboxDraftCueKind.timing => 'Cue Timing',
      _ControlInboxDraftCueKind.sensitive => 'Cue Sensitive',
      _ControlInboxDraftCueKind.detail => 'Cue Detail',
      _ControlInboxDraftCueKind.validation => 'Cue Validation',
      _ControlInboxDraftCueKind.reassurance => 'Cue Reassurance',
      _ControlInboxDraftCueKind.formal => 'Cue Formal',
      _ControlInboxDraftCueKind.concise => 'Cue Concise',
      _ControlInboxDraftCueKind.defaultReassurance => 'Cue Next Step',
    };
  }

  IconData _controlInboxDraftCueChipIcon(_ControlInboxDraftCueKind kind) {
    return switch (kind) {
      _ControlInboxDraftCueKind.timing => Icons.schedule_rounded,
      _ControlInboxDraftCueKind.sensitive => Icons.warning_amber_rounded,
      _ControlInboxDraftCueKind.detail => Icons.help_outline_rounded,
      _ControlInboxDraftCueKind.validation => Icons.visibility_rounded,
      _ControlInboxDraftCueKind.reassurance => Icons.favorite_border_rounded,
      _ControlInboxDraftCueKind.formal => Icons.business_center_rounded,
      _ControlInboxDraftCueKind.concise => Icons.short_text_rounded,
      _ControlInboxDraftCueKind.defaultReassurance => Icons.flag_outlined,
    };
  }

  Color _controlInboxDraftCueChipAccent(_ControlInboxDraftCueKind kind) {
    return switch (kind) {
      _ControlInboxDraftCueKind.timing => const Color(0xFFF59E0B),
      _ControlInboxDraftCueKind.sensitive => const Color(0xFFEF4444),
      _ControlInboxDraftCueKind.detail => const Color(0xFF60A5FA),
      _ControlInboxDraftCueKind.validation => const Color(0xFF22D3EE),
      _ControlInboxDraftCueKind.reassurance => const Color(0xFF34D399),
      _ControlInboxDraftCueKind.formal => const Color(0xFF4B6B8F),
      _ControlInboxDraftCueKind.concise => const Color(0xFF8B5CF6),
      _ControlInboxDraftCueKind.defaultReassurance => const Color(0xFF9AB1CF),
    };
  }

  int _controlInboxDraftCuePriority(_ControlInboxDraftCueKind kind) {
    return switch (kind) {
      _ControlInboxDraftCueKind.sensitive => 0,
      _ControlInboxDraftCueKind.timing => 1,
      _ControlInboxDraftCueKind.detail => 2,
      _ControlInboxDraftCueKind.validation => 3,
      _ControlInboxDraftCueKind.formal => 4,
      _ControlInboxDraftCueKind.reassurance => 5,
      _ControlInboxDraftCueKind.concise => 6,
      _ControlInboxDraftCueKind.defaultReassurance => 7,
    };
  }

  List<LiveControlInboxDraft> _sortedControlInboxDrafts(
    List<LiveControlInboxDraft> drafts,
  ) {
    final sorted = List<LiveControlInboxDraft>.from(drafts);
    sorted.sort((a, b) {
      final cueCompare = _controlInboxDraftCuePriority(
        _controlInboxDraftCueKindForSignals(
          sourceText: a.sourceText,
          replyText: a.draftText,
          clientVoiceProfileLabel: a.clientVoiceProfileLabel,
          usesLearnedApprovalStyle: a.usesLearnedApprovalStyle,
        ),
      ).compareTo(
        _controlInboxDraftCuePriority(
          _controlInboxDraftCueKindForSignals(
            sourceText: b.sourceText,
            replyText: b.draftText,
            clientVoiceProfileLabel: b.clientVoiceProfileLabel,
            usesLearnedApprovalStyle: b.usesLearnedApprovalStyle,
          ),
        ),
      );
      if (cueCompare != 0) {
        return cueCompare;
      }
      if (a.matchesSelectedScope != b.matchesSelectedScope) {
        return a.matchesSelectedScope ? -1 : 1;
      }
      return b.createdAtUtc.compareTo(a.createdAtUtc);
    });
    return sorted;
  }

  String _controlInboxCueSummaryLabel(_ControlInboxDraftCueKind kind) {
    return switch (kind) {
      _ControlInboxDraftCueKind.sensitive => 'sensitive',
      _ControlInboxDraftCueKind.timing => 'timing',
      _ControlInboxDraftCueKind.detail => 'detail',
      _ControlInboxDraftCueKind.validation => 'validation',
      _ControlInboxDraftCueKind.reassurance => 'reassurance',
      _ControlInboxDraftCueKind.formal => 'formal',
      _ControlInboxDraftCueKind.concise => 'concise',
      _ControlInboxDraftCueKind.defaultReassurance => 'next step',
    };
  }

  String _controlInboxTopBarFilterLabel(_ControlInboxDraftCueKind kind) {
    return switch (kind) {
      _ControlInboxDraftCueKind.sensitive => 'Sensitive only',
      _ControlInboxDraftCueKind.timing => 'Timing only',
      _ControlInboxDraftCueKind.detail => 'Detail only',
      _ControlInboxDraftCueKind.validation => 'Validation only',
      _ControlInboxDraftCueKind.reassurance => 'Reassurance only',
      _ControlInboxDraftCueKind.formal => 'Formal only',
      _ControlInboxDraftCueKind.concise => 'Concise only',
      _ControlInboxDraftCueKind.defaultReassurance => 'Next step only',
    };
  }

  String _controlInboxTopBarQueueStateLabel() {
    final filteredCueKind = _controlInboxCueOnlyKind;
    if (filteredCueKind != null) {
      return 'Queue ${_controlInboxTopBarFilterLabel(filteredCueKind)}';
    }
    if (_controlInboxPriorityOnly) {
      return 'Queue High priority';
    }
    return 'Queue Full';
  }

  Color _controlInboxTopBarQueueStateForeground(
    bool hasSensitivePriorityDraft,
  ) {
    final filteredCueKind = _controlInboxCueOnlyKind;
    if (filteredCueKind != null) {
      return _controlInboxDraftCueChipAccent(filteredCueKind);
    }
    if (_controlInboxPriorityOnly) {
      return hasSensitivePriorityDraft
          ? const Color(0xFFEF4444)
          : const Color(0xFFF59E0B);
    }
    return const Color(0xFF9AB1CF);
  }

  Color _controlInboxTopBarQueueStateBackground(
    bool hasSensitivePriorityDraft,
  ) {
    final filteredCueKind = _controlInboxCueOnlyKind;
    if (filteredCueKind != null) {
      return _controlInboxDraftCueChipAccent(
        filteredCueKind,
      ).withValues(alpha: 0.2);
    }
    if (_controlInboxPriorityOnly) {
      return hasSensitivePriorityDraft
          ? const Color(0x33EF4444)
          : const Color(0x33F59E0B);
    }
    return const Color(0x334B6B8F);
  }

  Color _controlInboxTopBarQueueStateBorder(bool hasSensitivePriorityDraft) {
    final filteredCueKind = _controlInboxCueOnlyKind;
    if (filteredCueKind != null) {
      return _controlInboxDraftCueChipAccent(
        filteredCueKind,
      ).withValues(alpha: 0.45);
    }
    if (_controlInboxPriorityOnly) {
      return hasSensitivePriorityDraft
          ? const Color(0x66EF4444)
          : const Color(0x66F59E0B);
    }
    return const Color(0x664B6B8F);
  }

  IconData _controlInboxTopBarQueueStateIcon(bool hasSensitivePriorityDraft) {
    final filteredCueKind = _controlInboxCueOnlyKind;
    if (filteredCueKind != null) {
      return _controlInboxDraftCueChipIcon(filteredCueKind);
    }
    if (_controlInboxPriorityOnly) {
      return hasSensitivePriorityDraft
          ? Icons.warning_amber_rounded
          : Icons.priority_high_rounded;
    }
    return Icons.inbox_rounded;
  }

  String _controlInboxQueueStateTooltip() {
    final filteredCueKind = _controlInboxCueOnlyKind;
    if (filteredCueKind != null) {
      return '${_controlInboxTopBarQueueStateLabel()} is showing only ${_controlInboxCueSummaryLabel(filteredCueKind)} replies. Tap to widen back to the high-priority queue.';
    }
    if (_controlInboxPriorityOnly) {
      return 'Queue High priority is showing only sensitive and timing replies. Tap to return to the full queue.';
    }
    return 'Queue Full is showing every pending reply. Tap to narrow the inbox to the high-priority queue.';
  }

  List<(_ControlInboxDraftCueKind, int)> _controlInboxCueSummaryItems(
    List<LiveControlInboxDraft> drafts,
  ) {
    final counts = <_ControlInboxDraftCueKind, int>{};
    for (final draft in drafts) {
      final kind = _controlInboxDraftCueKindForSignals(
        sourceText: draft.sourceText,
        replyText: draft.draftText,
        clientVoiceProfileLabel: draft.clientVoiceProfileLabel,
        usesLearnedApprovalStyle: draft.usesLearnedApprovalStyle,
      );
      counts[kind] = (counts[kind] ?? 0) + 1;
    }
    if (counts.isEmpty) {
      return const <(_ControlInboxDraftCueKind, int)>[];
    }
    final orderedKinds = counts.keys.toList()
      ..sort(
        (a, b) =>
            _controlInboxDraftCuePriority(a).compareTo(
              _controlInboxDraftCuePriority(b),
            ),
      );
    return orderedKinds
        .map((kind) => (kind, counts[kind] ?? 0))
        .toList(growable: false);
  }

  String _controlInboxCueSummaryText(List<LiveControlInboxDraft> drafts) {
    final items = _controlInboxCueSummaryItems(drafts);
    if (items.isEmpty) {
      return '';
    }
    final parts = items
        .map((item) => '${item.$2} ${_controlInboxCueSummaryLabel(item.$1)}')
        .toList(growable: false);
    return 'Queue shape: ${parts.join(' • ')}';
  }

  bool _isControlInboxPriorityCueKind(_ControlInboxDraftCueKind kind) {
    return kind == _ControlInboxDraftCueKind.sensitive ||
        kind == _ControlInboxDraftCueKind.timing;
  }

  int _controlInboxPriorityDraftCount(List<LiveControlInboxDraft> drafts) {
    var count = 0;
    for (final draft in drafts) {
      final kind = _controlInboxDraftCueKindForSignals(
        sourceText: draft.sourceText,
        replyText: draft.draftText,
        clientVoiceProfileLabel: draft.clientVoiceProfileLabel,
        usesLearnedApprovalStyle: draft.usesLearnedApprovalStyle,
      );
      if (_isControlInboxPriorityCueKind(kind)) {
        count += 1;
      }
    }
    return count;
  }

  int _controlInboxCueKindCount(
    List<LiveControlInboxDraft> drafts,
    _ControlInboxDraftCueKind kind,
  ) {
    var count = 0;
    for (final draft in drafts) {
      final draftKind = _controlInboxDraftCueKindForSignals(
        sourceText: draft.sourceText,
        replyText: draft.draftText,
        clientVoiceProfileLabel: draft.clientVoiceProfileLabel,
        usesLearnedApprovalStyle: draft.usesLearnedApprovalStyle,
      );
      if (draftKind == kind) {
        count += 1;
      }
    }
    return count;
  }

  bool _controlInboxHasSensitivePriorityDraft(
    List<LiveControlInboxDraft> drafts,
  ) {
    for (final draft in drafts) {
      final kind = _controlInboxDraftCueKindForSignals(
        sourceText: draft.sourceText,
        replyText: draft.draftText,
        clientVoiceProfileLabel: draft.clientVoiceProfileLabel,
        usesLearnedApprovalStyle: draft.usesLearnedApprovalStyle,
      );
      if (kind == _ControlInboxDraftCueKind.sensitive) {
        return true;
      }
    }
    return false;
  }

  String _controlInboxDraftCue(LiveControlInboxDraft draft) {
    return _controlInboxDraftCueMessage(
      _controlInboxDraftCueKindForSignals(
        sourceText: draft.sourceText,
        replyText: draft.draftText,
        clientVoiceProfileLabel: draft.clientVoiceProfileLabel,
        usesLearnedApprovalStyle: draft.usesLearnedApprovalStyle,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.queueStateHintSeen) {
      _queueStateHintSeenThisSession = true;
    }
    _showQueueStateHint = !_queueStateHintSeenThisSession;
    _projectFromEvents();
  }

  @override
  void didUpdateWidget(covariant LiveOperationsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.queueStateHintSeen && widget.queueStateHintSeen) {
      _queueStateHintSeenThisSession = true;
      _showQueueStateHint = false;
    } else if (oldWidget.queueStateHintSeen && !widget.queueStateHintSeen) {
      _queueStateHintSeenThisSession = false;
      _showQueueStateHint = true;
    }
    if (oldWidget.events.length != widget.events.length ||
        oldWidget.sceneReviewByIntelligenceId !=
            widget.sceneReviewByIntelligenceId ||
        oldWidget.initialScopeClientId?.trim() !=
            widget.initialScopeClientId?.trim() ||
        oldWidget.initialScopeSiteId?.trim() !=
            widget.initialScopeSiteId?.trim() ||
        oldWidget.focusIncidentReference.trim() !=
            widget.focusIncidentReference.trim()) {
      _projectFromEvents();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scopeClientId = (widget.initialScopeClientId ?? '').trim();
    final scopeSiteId = (widget.initialScopeSiteId ?? '').trim();
    final hasScopeFocus = scopeClientId.isNotEmpty;
    final activeIncident = _activeIncident;
    final clientCommsSnapshot = widget.clientCommsSnapshot;
    final controlInboxSnapshot = widget.controlInboxSnapshot;
    final ledger = [..._manualLedger, ..._projectedLedger]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final handsetLayout = isHandsetLayout(context);
    final viewportSize = MediaQuery.sizeOf(context);
    final viewportWidth = viewportSize.width;
    final wide = allowEmbeddedPanelScroll(context);
    final showPageTopBar = viewportWidth < 980 || handsetLayout;

    return OnyxPageScaffold(
      child: Column(
        children: [
          if (showPageTopBar) _topBar(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: LayoutBuilder(
                builder: (context, bodyConstraints) {
                  final canUseEmbeddedDesktopLayout =
                      wide && bodyConstraints.maxHeight >= 1040;
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1580),
                      child: canUseEmbeddedDesktopLayout
                          ? Column(
                              children: [
                                if (_criticalAlertIncident != null) ...[
                                  _criticalAlertBanner(_criticalAlertIncident!),
                                  const SizedBox(height: 10),
                                ],
                                _commandOverviewGrid(
                                  clientCommsSnapshot: clientCommsSnapshot,
                                  controlInboxSnapshot: controlInboxSnapshot,
                                ),
                                const SizedBox(height: 10),
                                if (hasScopeFocus) ...[
                                  _scopeFocusBanner(
                                    clientId: scopeClientId,
                                    siteId: scopeSiteId,
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                if (controlInboxSnapshot != null ||
                                    ledger.isNotEmpty) ...[
                                  _operationsDecisionDeck(
                                    controlInboxSnapshot: controlInboxSnapshot,
                                    activeIncident: activeIncident,
                                    ledger: ledger,
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                if (clientCommsSnapshot != null) ...[
                                  _clientLaneWatchPanel(
                                    clientCommsSnapshot,
                                    activeIncident,
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                Expanded(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: _incidentQueuePanel(
                                          embeddedScroll: true,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        flex: 5,
                                        child: _actionLadderPanel(
                                          activeIncident,
                                          embeddedScroll: true,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        flex: 4,
                                        child: _contextAndVigilancePanel(
                                          activeIncident,
                                          embeddedScroll: true,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : SingleChildScrollView(
                              child: Column(
                                children: [
                                  if (_criticalAlertIncident != null) ...[
                                    _criticalAlertBanner(
                                      _criticalAlertIncident!,
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                  _commandOverviewGrid(
                                    clientCommsSnapshot: clientCommsSnapshot,
                                    controlInboxSnapshot: controlInboxSnapshot,
                                  ),
                                  const SizedBox(height: 10),
                                  if (hasScopeFocus) ...[
                                    _scopeFocusBanner(
                                      clientId: scopeClientId,
                                      siteId: scopeSiteId,
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                  if (controlInboxSnapshot != null ||
                                      ledger.isNotEmpty) ...[
                                    _operationsDecisionDeck(
                                      controlInboxSnapshot:
                                          controlInboxSnapshot,
                                      activeIncident: activeIncident,
                                      ledger: ledger,
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                  if (clientCommsSnapshot != null) ...[
                                    _clientLaneWatchPanel(
                                      clientCommsSnapshot,
                                      activeIncident,
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                  _incidentQueuePanel(
                                    embeddedScroll: false,
                                  ),
                                  const SizedBox(height: 10),
                                  _actionLadderPanel(
                                    activeIncident,
                                    embeddedScroll: false,
                                  ),
                                  const SizedBox(height: 10),
                                  _contextAndVigilancePanel(
                                    activeIncident,
                                    embeddedScroll: false,
                                  ),
                                ],
                              ),
                            ),
                    ),
                  );
                },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _operationsDecisionDeck({
    required LiveControlInboxSnapshot? controlInboxSnapshot,
    required _IncidentRecord? activeIncident,
    required List<_LedgerEntry> ledger,
  }) {
    final hasInbox = controlInboxSnapshot != null;
    final hasLedger = ledger.isNotEmpty;
    if (!hasInbox && !hasLedger) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 1180;
        final inboxPanel = hasInbox
            ? _controlInboxPanel(
                controlInboxSnapshot,
                compactPreview: !stack,
              )
            : const SizedBox.shrink();
        final ledgerPanel = hasLedger
            ? _ledgerPanel(ledger, embeddedScroll: false)
            : const SizedBox.shrink();
        if (!hasInbox) {
          return ledgerPanel;
        }
        if (!hasLedger) {
          return inboxPanel;
        }
        if (stack) {
          return Column(
            children: [
              inboxPanel,
              const SizedBox(height: 10),
              ledgerPanel,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 8, child: inboxPanel),
            const SizedBox(width: 10),
            Expanded(flex: 4, child: ledgerPanel),
          ],
        );
      },
    );
  }

  _IncidentRecord? get _criticalAlertIncident {
    for (final incident in _incidents) {
      if (incident.status != _IncidentStatus.resolved &&
          incident.priority == _IncidentPriority.p1Critical) {
        return incident;
      }
    }
    return null;
  }

  int _visibleControlInboxDraftCount(LiveControlInboxSnapshot? snapshot) {
    if (snapshot == null) {
      return 0;
    }
    final sortedPendingDrafts = _sortedControlInboxDrafts(snapshot.pendingDrafts);
    if (_controlInboxCueOnlyKind != null) {
      return sortedPendingDrafts.where((draft) {
        final kind = _controlInboxDraftCueKindForSignals(
          sourceText: draft.sourceText,
          replyText: draft.draftText,
          clientVoiceProfileLabel: draft.clientVoiceProfileLabel,
          usesLearnedApprovalStyle: draft.usesLearnedApprovalStyle,
        );
        return kind == _controlInboxCueOnlyKind;
      }).length;
    }
    if (_controlInboxPriorityOnly) {
      return sortedPendingDrafts.where((draft) {
        final kind = _controlInboxDraftCueKindForSignals(
          sourceText: draft.sourceText,
          replyText: draft.draftText,
          clientVoiceProfileLabel: draft.clientVoiceProfileLabel,
          usesLearnedApprovalStyle: draft.usesLearnedApprovalStyle,
        );
        return _isControlInboxPriorityCueKind(kind);
      }).length;
    }
    return sortedPendingDrafts.length;
  }

  int _sitesUnderWatchCount(LiveClientCommsSnapshot? clientCommsSnapshot) {
    final liveSites = <String>{};
    for (final incident in _incidents) {
      if (incident.status == _IncidentStatus.resolved) {
        continue;
      }
      final normalizedSiteId = incident.siteId.trim();
      final fallbackSite = incident.site.trim();
      if (normalizedSiteId.isNotEmpty) {
        liveSites.add(normalizedSiteId);
      } else if (fallbackSite.isNotEmpty) {
        liveSites.add(fallbackSite);
      }
    }
    final snapshotSiteId = clientCommsSnapshot?.siteId.trim() ?? '';
    if (snapshotSiteId.isNotEmpty) {
      liveSites.add(snapshotSiteId);
    }
    return liveSites.length;
  }

  void _focusIncidentFromBanner(_IncidentRecord incident) {
    if (_activeIncidentId != incident.id) {
      setState(() {
        _activeIncidentId = incident.id;
      });
    }
  }

  Widget _criticalAlertBanner(_IncidentRecord incident) {
    final statusLabel = _statusLabel(incident.status).toUpperCase();
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final detailsButton = FilledButton(
          key: const ValueKey('live-operations-critical-alert-view-details'),
          onPressed: () => _focusIncidentFromBanner(incident),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0x33EF4444),
            foregroundColor: const Color(0xFFFFE4E4),
            side: const BorderSide(color: Color(0x66FFB4B4)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            'VIEW DETAILS',
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        );
        return Container(
          key: const ValueKey('live-operations-critical-alert-banner'),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF621313), Color(0xFF7A1616)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xAAEF4444)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x30EF4444),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFFFB4B4),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'CRITICAL ALERT',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFFFD6D6),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${incident.id} • ${incident.type} • ${incident.site}',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFFFF1F1),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '$statusLabel ${incident.timestamp}',
                          style: GoogleFonts.robotoMono(
                            color: const Color(0xFFFFC7C7),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        detailsButton,
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFFFB4B4),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'CRITICAL ALERT',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFFFD6D6),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 18,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      color: const Color(0x55FFD6D6),
                    ),
                    Expanded(
                      child: Text(
                        '${incident.id} • ${incident.type} • ${incident.site}',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFFFF1F1),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$statusLabel ${incident.timestamp}',
                      style: GoogleFonts.robotoMono(
                        color: const Color(0xFFFFC7C7),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    detailsButton,
                  ],
                ),
        );
      },
    );
  }

  Widget _commandOverviewGrid({
    required LiveClientCommsSnapshot? clientCommsSnapshot,
    required LiveControlInboxSnapshot? controlInboxSnapshot,
  }) {
    final activeIncidentCount = _incidents
        .where((incident) => incident.status != _IncidentStatus.resolved)
        .length;
    final resolvedCount = _incidents
        .where((incident) => incident.status == _IncidentStatus.resolved)
        .length;
    final pendingActionCount = _visibleControlInboxDraftCount(
      controlInboxSnapshot,
    );
    final activeLaneCount = clientCommsSnapshot == null ? 0 : 1;
    final watchCount = _sitesUnderWatchCount(clientCommsSnapshot);
    final highPriorityCount = controlInboxSnapshot == null
        ? 0
        : _controlInboxPriorityDraftCount(
            _sortedControlInboxDrafts(controlInboxSnapshot.pendingDrafts),
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = constraints.maxWidth < 940 ? 2 : 4;
        final childAspectRatio = constraints.maxWidth < 520
            ? 0.82
            : constraints.maxWidth < 940
            ? 1.12
            : 1.5;
        return GridView.count(
          key: const ValueKey('live-operations-command-overview'),
          crossAxisCount: columnCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _commandOverviewCard(
              icon: Icons.graphic_eq_rounded,
              iconAccent: const Color(0xFFEF4444),
              statusLabel: 'Live',
              statusAccent: const Color(0xFFEF4444),
              value: '$activeIncidentCount',
              title: 'Active Incidents',
              footnote: resolvedCount > 0
                  ? '$resolvedCount cleared today'
                  : 'No cleared incidents yet',
              footnoteIcon: Icons.trending_up_rounded,
              footnoteAccent: const Color(0xFF34D399),
            ),
            _commandOverviewCard(
              icon: Icons.schedule_rounded,
              iconAccent: const Color(0xFFF59E0B),
              statusLabel: 'Queue',
              statusAccent: const Color(0xFFF59E0B),
              value: '$pendingActionCount',
              title: 'Pending Actions',
              footnote: highPriorityCount > 0
                  ? '$highPriorityCount high priority'
                  : 'All queues clear',
              footnoteIcon: highPriorityCount > 0
                  ? Icons.priority_high_rounded
                  : Icons.check_circle_rounded,
              footnoteAccent: highPriorityCount > 0
                  ? const Color(0xFFF87171)
                  : const Color(0xFF34D399),
            ),
            _commandOverviewCard(
              icon: Icons.chat_bubble_outline_rounded,
              iconAccent: const Color(0xFF22D3EE),
              statusLabel: activeLaneCount > 0 ? 'Ready' : 'Idle',
              statusAccent: activeLaneCount > 0
                  ? const Color(0xFF22D3EE)
                  : const Color(0xFF4B6B8F),
              value: '$activeLaneCount',
              title: 'Active Lanes',
              footnote: clientCommsSnapshot == null
                  ? 'Lane watch unavailable'
                  : 'Telegram ${clientCommsSnapshot.telegramHealthLabel}',
              footnoteIcon: clientCommsSnapshot == null
                  ? Icons.remove_circle_outline_rounded
                  : Icons.check_circle_rounded,
              footnoteAccent: clientCommsSnapshot == null
                  ? const Color(0xFF9AB1CF)
                  : _telegramHealthAccent(
                      clientCommsSnapshot.telegramHealthLabel,
                    ),
            ),
            _commandOverviewCard(
              icon: Icons.visibility_rounded,
              iconAccent: const Color(0xFF10B981),
              statusLabel: watchCount > 0 ? 'Active' : 'Idle',
              statusAccent: watchCount > 0
                  ? const Color(0xFF10B981)
                  : const Color(0xFF4B6B8F),
              value: '$watchCount',
              title: 'Sites Under Watch',
              footnote: watchCount > 0 ? 'Full coverage' : 'Coverage idle',
              footnoteIcon: Icons.shield_outlined,
              footnoteAccent: watchCount > 0
                  ? const Color(0xFF34D399)
                  : const Color(0xFF9AB1CF),
            ),
          ],
        );
      },
    );
  }

  Widget _commandOverviewCard({
    required IconData icon,
    required Color iconAccent,
    required String statusLabel,
    required Color statusAccent,
    required String value,
    required String title,
    required String footnote,
    required IconData footnoteIcon,
    required Color footnoteAccent,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF21262D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: iconAccent.withValues(alpha: 0.14),
                  border: Border.all(color: iconAccent.withValues(alpha: 0.32)),
                ),
                child: Icon(icon, size: 20, color: iconAccent),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel.toUpperCase(),
                  style: GoogleFonts.inter(
                    color: statusAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.9,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.inter(
              color: const Color(0xFFF8FBFF),
              fontSize: 30,
              fontWeight: FontWeight.w900,
              height: 0.95,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              color: const Color(0xFFB4BDC9),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 1,
            color: const Color(0x14FFFFFF),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(footnoteIcon, size: 14, color: footnoteAccent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  footnote,
                  style: GoogleFonts.inter(
                    color: footnoteAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final clientCommsSnapshot = widget.clientCommsSnapshot;
    final controlInboxSnapshot = widget.controlInboxSnapshot;
    final sortedInboxDrafts = controlInboxSnapshot == null
        ? const <LiveControlInboxDraft>[]
        : _sortedControlInboxDrafts(controlInboxSnapshot.pendingDrafts);
    final priorityDraftCount = _controlInboxPriorityDraftCount(sortedInboxDrafts);
    final filteredReplyCount = _controlInboxCueOnlyKind == null
        ? (_controlInboxPriorityOnly ? priorityDraftCount : 0)
        : _controlInboxCueKindCount(
            sortedInboxDrafts,
            _controlInboxCueOnlyKind!,
          );
    final filteredCueKind = _controlInboxCueOnlyKind;
    final hasSensitivePriorityDraft = _controlInboxHasSensitivePriorityDraft(
      sortedInboxDrafts,
    );
    final priorityChipForeground = hasSensitivePriorityDraft
        ? const Color(0xFFEF4444)
        : const Color(0xFFF59E0B);
    final priorityChipBackground = hasSensitivePriorityDraft
        ? const Color(0x33EF4444)
        : const Color(0x33F59E0B);
    final priorityChipBorder = hasSensitivePriorityDraft
        ? const Color(0x66EF4444)
        : const Color(0x66F59E0B);
    final focusReference = _resolvedFocusReference;
    final hasFocusReference = focusReference.isNotEmpty;
    final focusState = _focusLinkState;
    final activeCount = _incidents
        .where((incident) => incident.status != _IncidentStatus.resolved)
        .length;
    final compact = isHandsetLayout(context);
    if (compact) {
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: const BoxDecoration(
          color: Color(0xFF0A0D14),
          border: Border(bottom: BorderSide(color: Color(0xFF1A2D49))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$hh:$mm',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFE4EEFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 10),
                Container(width: 1, height: 16, color: const Color(0xFF22334C)),
                const SizedBox(width: 10),
                Text(
                  'Combat Window Active',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFF59E0B),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(
                  label: '$activeCount Incidents',
                  foreground: const Color(0xFFEF4444),
                  background: const Color(0x33EF4444),
                  border: const Color(0x66EF4444),
                ),
                _chip(
                  label: _clientLaneTopBarLabel(clientCommsSnapshot),
                  foreground: _clientLaneTopBarForeground(clientCommsSnapshot),
                  background: _clientLaneTopBarBackground(clientCommsSnapshot),
                  border: _clientLaneTopBarBorder(clientCommsSnapshot),
                ),
                _chip(
                  key: const ValueKey('top-bar-queue-state-chip'),
                  label: _controlInboxTopBarQueueStateLabel(),
                  leadingIcon: _controlInboxTopBarQueueStateIcon(
                    hasSensitivePriorityDraft,
                  ),
                  tooltipMessage: _controlInboxQueueStateTooltip(),
                  foreground: _controlInboxTopBarQueueStateForeground(
                    hasSensitivePriorityDraft,
                  ),
                  background: _controlInboxTopBarQueueStateBackground(
                    hasSensitivePriorityDraft,
                  ),
                  border: _controlInboxTopBarQueueStateBorder(
                    hasSensitivePriorityDraft,
                  ),
                ),
                if (priorityDraftCount > 0)
                  _chip(
                    key: const ValueKey('top-bar-priority-chip'),
                    label: hasSensitivePriorityDraft
                        ? (priorityDraftCount == 1
                              ? '1 Sensitive Reply'
                              : '$priorityDraftCount Sensitive Replies')
                        : (priorityDraftCount == 1
                              ? '1 High-priority Reply'
                              : '$priorityDraftCount High-priority Replies'),
                    foreground: priorityChipForeground,
                    background: priorityChipBackground,
                    border: priorityChipBorder,
                    onTap: _toggleTopBarPriorityFilter,
                  ),
                if (filteredCueKind != null)
                  _chip(
                    key: const ValueKey('top-bar-cue-filter-chip'),
                    label: _controlInboxTopBarFilterLabel(filteredCueKind),
                    foreground: _controlInboxDraftCueChipAccent(filteredCueKind),
                    background: _controlInboxDraftCueChipAccent(
                      filteredCueKind,
                    ).withValues(alpha: 0.2),
                    border: _controlInboxDraftCueChipAccent(
                      filteredCueKind,
                    ).withValues(alpha: 0.45),
                    onTap: _cycleControlInboxTopBarCueFilter,
                  ),
                if (_controlInboxPriorityOnly || filteredCueKind != null)
                  _chip(
                    key: const ValueKey('top-bar-show-all-chip'),
                    label: filteredReplyCount == 1
                        ? 'Show all replies (1)'
                        : 'Show all replies ($filteredReplyCount)',
                    foreground: const Color(0xFFEAF4FF),
                    background: const Color(0x334B6B8F),
                    border: const Color(0x664B6B8F),
                    onTap: _clearControlInboxPriorityOnly,
                  ),
                _chip(
                  label: '${_vigilance.length} Guards Online',
                  foreground: const Color(0xFF10B981),
                  background: const Color(0x3310B981),
                  border: const Color(0x6610B981),
                ),
                if (hasFocusReference)
                  _chip(
                    label:
                        'Focus ${_focusStateLabel(focusState)}: $focusReference',
                    foreground: _focusStateForeground(focusState),
                    background: _focusStateBackground(focusState),
                    border: _focusStateBorder(focusState),
                  ),
              ],
            ),
          ],
        ),
      );
    }
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0D14),
        border: Border(bottom: BorderSide(color: Color(0xFF1A2D49))),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$hh:$mm',
            style: GoogleFonts.inter(
              color: const Color(0xFFE4EEFF),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 10),
          Container(width: 1, height: 16, color: const Color(0xFF22334C)),
          const SizedBox(width: 10),
          Text(
            'Combat Window Active',
            style: GoogleFonts.inter(
              color: const Color(0xFFF59E0B),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          _chip(
            label: '$activeCount Active Incidents',
            foreground: const Color(0xFFEF4444),
            background: const Color(0x33EF4444),
            border: const Color(0x66EF4444),
          ),
          const SizedBox(width: 8),
          _chip(
            label: _clientLaneTopBarLabel(clientCommsSnapshot),
            foreground: _clientLaneTopBarForeground(clientCommsSnapshot),
            background: _clientLaneTopBarBackground(clientCommsSnapshot),
            border: _clientLaneTopBarBorder(clientCommsSnapshot),
          ),
          const SizedBox(width: 8),
          _chip(
            key: const ValueKey('top-bar-queue-state-chip'),
            label: _controlInboxTopBarQueueStateLabel(),
            leadingIcon: _controlInboxTopBarQueueStateIcon(
              hasSensitivePriorityDraft,
            ),
            tooltipMessage: _controlInboxQueueStateTooltip(),
            foreground: _controlInboxTopBarQueueStateForeground(
              hasSensitivePriorityDraft,
            ),
            background: _controlInboxTopBarQueueStateBackground(
              hasSensitivePriorityDraft,
            ),
            border: _controlInboxTopBarQueueStateBorder(
              hasSensitivePriorityDraft,
            ),
          ),
          if (priorityDraftCount > 0) ...[
            const SizedBox(width: 8),
            _chip(
              key: const ValueKey('top-bar-priority-chip'),
              label: hasSensitivePriorityDraft
                  ? (priorityDraftCount == 1
                        ? '1 Sensitive Reply'
                        : '$priorityDraftCount Sensitive Replies')
                  : (priorityDraftCount == 1
                        ? '1 High-priority Reply'
                        : '$priorityDraftCount High-priority Replies'),
              foreground: priorityChipForeground,
              background: priorityChipBackground,
              border: priorityChipBorder,
              onTap: _toggleTopBarPriorityFilter,
            ),
          ],
          if (filteredCueKind != null) ...[
            const SizedBox(width: 8),
            _chip(
              key: const ValueKey('top-bar-cue-filter-chip'),
              label: _controlInboxTopBarFilterLabel(filteredCueKind),
              foreground: _controlInboxDraftCueChipAccent(filteredCueKind),
              background: _controlInboxDraftCueChipAccent(
                filteredCueKind,
              ).withValues(alpha: 0.2),
              border: _controlInboxDraftCueChipAccent(
                filteredCueKind,
              ).withValues(alpha: 0.45),
              onTap: _cycleControlInboxTopBarCueFilter,
            ),
          ],
          if (_controlInboxPriorityOnly || filteredCueKind != null) ...[
            const SizedBox(width: 8),
            _chip(
              key: const ValueKey('top-bar-show-all-chip'),
              label: filteredReplyCount == 1
                  ? 'Show all replies (1)'
                  : 'Show all replies ($filteredReplyCount)',
              foreground: const Color(0xFFEAF4FF),
              background: const Color(0x334B6B8F),
              border: const Color(0x664B6B8F),
              onTap: _clearControlInboxPriorityOnly,
            ),
          ],
          const SizedBox(width: 8),
          _chip(
            label: '${_vigilance.length} Guards Online',
            foreground: const Color(0xFF10B981),
            background: const Color(0x3310B981),
            border: const Color(0x6610B981),
          ),
          if (hasFocusReference) ...[
            const SizedBox(width: 8),
            _chip(
              label:
                  'Focus ${_focusStateLabel(focusState)}: $focusReference',
              foreground: _focusStateForeground(focusState),
              background: _focusStateBackground(focusState),
              border: _focusStateBorder(focusState),
            ),
          ],
        ],
      ),
    );
  }

  Widget _clientLaneWatchPanel(
    LiveClientCommsSnapshot snapshot,
    _IncidentRecord? activeIncident,
  ) {
    final cueKind = _liveClientLaneCueKind(snapshot);
    final learnedStyleBusy = _learnedStyleBusyScopeKeys.contains(
      _scopeBusyKey(snapshot.clientId, snapshot.siteId),
    );
    final laneVoiceBusy = _laneVoiceBusyScopeKeys.contains(
      _scopeBusyKey(snapshot.clientId, snapshot.siteId),
    );
    final accent = _clientCommsAccent(snapshot);
    final linkedToActiveIncident =
        activeIncident != null &&
        activeIncident.clientId.trim() == snapshot.clientId.trim() &&
        activeIncident.siteId.trim() == snapshot.siteId.trim();
    final scopeFallback = activeIncident?.site ?? snapshot.siteId;
    final scopeLabel = _humanizeOpsScopeLabel(
      snapshot.siteId,
      fallback: scopeFallback,
    );
    final latestClientMessage = (snapshot.latestClientMessage ?? '').trim();
    final responseLabel = snapshot.pendingApprovalCount > 0
        ? 'Next ONYX reply waiting sign-off'
        : 'Latest lane reply';
    final responseText = snapshot.pendingApprovalCount > 0
        ? (snapshot.latestPendingDraft ?? '').trim()
        : (snapshot.latestOnyxReply ?? '').trim();
    final responseMoment = _commsMomentLabel(
      snapshot.pendingApprovalCount > 0
          ? snapshot.latestPendingDraftAtUtc
          : snapshot.latestOnyxReplyAtUtc,
    );

    return Container(
      key: const ValueKey('client-lane-watch-panel'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: 0.16), const Color(0xFF0D1725)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.52)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accent.withValues(alpha: 0.34)),
                ),
                child: Icon(
                  Icons.mark_chat_read_rounded,
                  size: 18,
                  color: accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CLIENT LANE WATCH',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8FAFD4),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$scopeLabel • ${_clientCommsNarrative(snapshot)}',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFEAF4FF),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      linkedToActiveIncident
                          ? 'Linked to active incident ${activeIncident.id}, so control can feel client pressure without leaving the board.'
                          : 'Watching the selected client lane so operator approval and delivery health stay visible before the next escalation.',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFB8CCE5),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (_openClientLaneAction(
                    clientId: snapshot.clientId,
                    siteId: snapshot.siteId,
                  ) !=
                  null) ...[
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _openClientLaneAction(
                    clientId: snapshot.clientId,
                    siteId: snapshot.siteId,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEAF4FF),
                    side: BorderSide(color: accent.withValues(alpha: 0.52)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 34),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 15),
                  label: Text(
                    'Open Client Lane',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              if (snapshot.learnedApprovalStyleCount > 0 &&
                  widget.onClearLearnedLaneStyleForScope != null) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  key: ValueKey(
                    'client-lane-watch-clear-learned-style-${snapshot.clientId}-${snapshot.siteId}',
                  ),
                  onPressed: learnedStyleBusy
                      ? null
                      : () => _clearLearnedLaneStyle(snapshot),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF9EDCF0),
                    side: const BorderSide(color: Color(0xFF245B72)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 34),
                  ),
                  icon: learnedStyleBusy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF9EDCF0),
                          ),
                        )
                      : const Icon(Icons.refresh_rounded, size: 15),
                  label: Text(
                    'Clear Learned Style',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (linkedToActiveIncident)
                _commsChip(
                  icon: Icons.link_rounded,
                  label: activeIncident.id,
                  accent: accent,
                ),
              _commsChip(
                icon: Icons.mark_chat_unread_rounded,
                label: '${snapshot.clientInboundCount} client msg',
                accent: const Color(0xFF22D3EE),
              ),
              _commsChip(
                icon: Icons.verified_user_rounded,
                label: '${snapshot.pendingApprovalCount} approval',
                accent: snapshot.pendingApprovalCount > 0
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF34D399),
              ),
              _commsChip(
                icon: Icons.tune_rounded,
                label: 'Lane voice ${snapshot.clientVoiceProfileLabel}',
                accent: const Color(0xFF4B6B8F),
              ),
              _commsChip(
                icon: _controlInboxDraftCueChipIcon(cueKind),
                label: _controlInboxDraftCueChipLabel(cueKind),
                accent: _controlInboxDraftCueChipAccent(cueKind),
              ),
              if (snapshot.learnedApprovalStyleCount > 0)
                _commsChip(
                  icon: Icons.school_rounded,
                  label: 'Learned style ${snapshot.learnedApprovalStyleCount}',
                  accent: const Color(0xFF22D3EE),
                ),
              if (snapshot.pendingLearnedStyleDraftCount > 0)
                _commsChip(
                  icon: Icons.psychology_alt_rounded,
                  label: snapshot.pendingLearnedStyleDraftCount == 1
                      ? 'ONYX using learned style'
                      : 'ONYX using learned style on ${snapshot.pendingLearnedStyleDraftCount} drafts',
                  accent: const Color(0xFF67E8F9),
                ),
              _commsChip(
                icon: Icons.telegram_rounded,
                label: 'Telegram ${snapshot.telegramHealthLabel.toUpperCase()}',
                accent: _telegramHealthAccent(snapshot.telegramHealthLabel),
              ),
              _commsChip(
                icon: Icons.sms_rounded,
                label: snapshot.smsFallbackLabel,
                accent: _smsFallbackAccent(
                  snapshot.smsFallbackLabel,
                  ready: snapshot.smsFallbackReady,
                  eligibleNow: snapshot.smsFallbackEligibleNow,
                ),
              ),
              _commsChip(
                icon: Icons.phone_forwarded_rounded,
                label: snapshot.voiceReadinessLabel,
                accent: _voiceReadinessAccent(snapshot.voiceReadinessLabel),
              ),
              _commsChip(
                icon: Icons.outbox_rounded,
                label: 'Push ${snapshot.pushSyncStatusLabel.toUpperCase()}',
                accent: _pushSyncAccent(snapshot.pushSyncStatusLabel),
              ),
            ],
          ),
          if (widget.onSetLaneVoiceProfileForScope != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (laneVoiceBusy)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF8FD1FF),
                    ),
                  ),
                for (final option in const <(String, String?)>[
                  ('Auto', null),
                  ('Concise', 'concise-updates'),
                  ('Reassuring', 'reassurance-forward'),
                  ('Validation-heavy', 'validation-heavy'),
                ])
                  OutlinedButton(
                    onPressed: laneVoiceBusy
                        ? null
                        : () => _setLaneVoiceProfile(snapshot, option.$2),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          _laneVoiceOptionSelected(snapshot, option.$2)
                          ? const Color(0xFFEAF4FF)
                          : const Color(0xFF9AB1CF),
                      backgroundColor:
                          _laneVoiceOptionSelected(snapshot, option.$2)
                          ? const Color(0xFF1B3148)
                          : Colors.transparent,
                      side: BorderSide(
                        color: _laneVoiceOptionSelected(snapshot, option.$2)
                            ? const Color(0xFF4B6B8F)
                            : const Color(0xFF35506F),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    child: Text(
                      option.$1,
                      style: GoogleFonts.inter(
                        fontSize: 10.6,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            _liveClientLaneCue(snapshot),
            style: GoogleFonts.inter(
              color: const Color(0xFF9FB7D5),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.28,
            ),
          ),
          if (latestClientMessage.isNotEmpty) ...[
            const SizedBox(height: 10),
            _clientCommsTextBlock(
              label: 'Latest client ask',
              text:
                  '$latestClientMessage${_commsMomentLabel(snapshot.latestClientMessageAtUtc).isEmpty ? '' : ' • ${_commsMomentLabel(snapshot.latestClientMessageAtUtc)}'}',
              borderColor: const Color(0xFF31506F),
              textColor: const Color(0xFFD8E8FA),
            ),
          ],
          if (responseText.isNotEmpty) ...[
            const SizedBox(height: 8),
            _clientCommsTextBlock(
              label: responseLabel,
              text:
                  '$responseText${responseMoment.isEmpty ? '' : ' • $responseMoment'}',
              borderColor: accent,
              textColor: const Color(0xFFEAF4FF),
            ),
          ],
          if ((snapshot.latestSmsFallbackStatus ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _clientCommsTextBlock(
              label: 'Latest SMS fallback',
              text:
                  '${ClientDeliveryMessageFormatter.humanizeScopedCommsSummary(snapshot.latestSmsFallbackStatus!.trim())}${_commsMomentLabel(snapshot.latestSmsFallbackAtUtc).isEmpty ? '' : ' • ${_commsMomentLabel(snapshot.latestSmsFallbackAtUtc)}'}',
              borderColor: const Color(0xFF2E7D68),
              textColor: const Color(0xFFDDFBF3),
            ),
          ],
          if ((snapshot.latestVoipStageStatus ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _clientCommsTextBlock(
              label: 'Latest VoIP stage',
              text:
                  '${ClientDeliveryMessageFormatter.humanizeScopedCommsSummary(snapshot.latestVoipStageStatus!.trim())}${_commsMomentLabel(snapshot.latestVoipStageAtUtc).isEmpty ? '' : ' • ${_commsMomentLabel(snapshot.latestVoipStageAtUtc)}'}',
              borderColor: const Color(0xFF3E6AA6),
              textColor: const Color(0xFFDCEBFF),
            ),
          ],
          if (snapshot.recentDeliveryHistoryLines.isNotEmpty) ...[
            const SizedBox(height: 8),
            _clientCommsTextBlock(
              label: 'Recent delivery history',
              text: snapshot.recentDeliveryHistoryLines.join('\n'),
              borderColor: const Color(0xFF35506F),
              textColor: const Color(0xFFDCE8FF),
            ),
          ],
          if (snapshot.learnedApprovalStyleExample.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _clientCommsTextBlock(
              label: 'Learned approval style',
              text: snapshot.learnedApprovalStyleExample.trim(),
              borderColor: const Color(0xFF245B72),
              textColor: const Color(0xFFD9F7FF),
            ),
          ],
          if (_clientCommsOpsFootnote(snapshot).isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _clientCommsOpsFootnote(snapshot),
              style: GoogleFonts.inter(
                color: const Color(0xFF9FB7D5),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1.28,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _controlInboxPanel(
    LiveControlInboxSnapshot snapshot, {
    bool compactPreview = false,
  }) {
    final laneVoiceBusy = _laneVoiceBusyScopeKeys.contains(
      _scopeBusyKey(snapshot.selectedClientId, snapshot.selectedSiteId),
    );
    final sortedPendingDrafts = _sortedControlInboxDrafts(snapshot.pendingDrafts);
    final priorityDraftCount = _controlInboxPriorityDraftCount(
      sortedPendingDrafts,
    );
    final hasSensitivePriorityDraft = _controlInboxHasSensitivePriorityDraft(
      sortedPendingDrafts,
    );
    final displayedPendingDrafts = _controlInboxCueOnlyKind != null
        ? sortedPendingDrafts.where((draft) {
            final kind = _controlInboxDraftCueKindForSignals(
              sourceText: draft.sourceText,
              replyText: draft.draftText,
              clientVoiceProfileLabel: draft.clientVoiceProfileLabel,
              usesLearnedApprovalStyle: draft.usesLearnedApprovalStyle,
            );
            return kind == _controlInboxCueOnlyKind;
          }).toList(growable: false)
        : _controlInboxPriorityOnly
        ? sortedPendingDrafts.where((draft) {
            final kind = _controlInboxDraftCueKindForSignals(
              sourceText: draft.sourceText,
              replyText: draft.draftText,
              clientVoiceProfileLabel: draft.clientVoiceProfileLabel,
              usesLearnedApprovalStyle: draft.usesLearnedApprovalStyle,
            );
            return _isControlInboxPriorityCueKind(kind);
          }).toList(growable: false)
        : sortedPendingDrafts;
    final cueSummaryItems = _controlInboxCueSummaryItems(displayedPendingDrafts);
    final cueSummaryText = _controlInboxCueSummaryText(displayedPendingDrafts);
    final accent = _controlInboxAccent(snapshot);
    final visiblePendingDrafts = compactPreview
        ? displayedPendingDrafts.take(1).toList(growable: false)
        : displayedPendingDrafts.take(3).toList(growable: false);
    final visibleClientAsks = compactPreview
        ? snapshot.liveClientAsks.take(1).toList(growable: false)
        : snapshot.liveClientAsks.take(2).toList(growable: false);
    final selectedScopeLabel = _humanizeOpsScopeLabel(
      snapshot.selectedSiteId,
      fallback: snapshot.selectedSiteId,
    );
    final selectedScopeNarrative = snapshot.selectedScopePendingCount > 0
        ? '${snapshot.selectedScopePendingCount} pending in the selected lane'
        : snapshot.awaitingResponseCount > 0
        ? '${snapshot.awaitingResponseCount} fresh client ask${snapshot.awaitingResponseCount == 1 ? '' : 's'} waiting for ONYX shaping'
        : 'selected lane is clear right now';

    return KeyedSubtree(
      key: _controlInboxPanelGlobalKey,
      child: Container(
        key: const ValueKey('control-inbox-panel'),
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accent.withValues(alpha: 0.15), const Color(0xFF0C1622)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accent.withValues(alpha: 0.34)),
                ),
                child: Icon(Icons.inbox_rounded, size: 18, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'CONTROL INBOX',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF8FAFD4),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                        if (priorityDraftCount > 0) ...[
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              key: const ValueKey(
                                'control-inbox-priority-badge',
                              ),
                              borderRadius: BorderRadius.circular(999),
                              onTap: _toggleControlInboxPriorityOnly,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _controlInboxPriorityOnly
                                      ? const Color(0x44F59E0B)
                                      : const Color(0x33F59E0B),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: _controlInboxPriorityOnly
                                        ? const Color(0x99F59E0B)
                                        : const Color(0x66F59E0B),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.priority_high_rounded,
                                      size: 12,
                                      color: Color(0xFFF59E0B),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      hasSensitivePriorityDraft
                                          ? (priorityDraftCount == 1
                                                ? 'Sensitive 1'
                                                : 'Sensitive $priorityDraftCount')
                                          : (priorityDraftCount == 1
                                                ? 'High priority 1'
                                                : 'High priority $priorityDraftCount'),
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFFFE1A8),
                                        fontSize: 9.6,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (_controlInboxPriorityOnly ||
                            _controlInboxCueOnlyKind != null) ...[
                          Container(
                            key: const ValueKey('control-inbox-filtered-chip'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x334B6B8F),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0x664B6B8F),
                              ),
                            ),
                            child: Text(
                              'Filtered ${displayedPendingDrafts.length}',
                              style: GoogleFonts.inter(
                                color: const Color(0xFFEAF4FF),
                                fontSize: 9.6,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                        Tooltip(
                          message: _controlInboxQueueStateTooltip(),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              key: const ValueKey('control-inbox-queue-state-chip'),
                              borderRadius: BorderRadius.circular(999),
                              onTap: _cycleControlInboxQueueStateChip,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _controlInboxTopBarQueueStateBackground(
                                    hasSensitivePriorityDraft,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: _controlInboxTopBarQueueStateBorder(
                                      hasSensitivePriorityDraft,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _controlInboxTopBarQueueStateIcon(
                                        hasSensitivePriorityDraft,
                                      ),
                                      size: 12,
                                      color: _controlInboxTopBarQueueStateForeground(
                                        hasSensitivePriorityDraft,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _controlInboxTopBarQueueStateLabel(),
                                      style: GoogleFonts.inter(
                                        color: _controlInboxTopBarQueueStateForeground(
                                          hasSensitivePriorityDraft,
                                        ),
                                        fontSize: 9.6,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (!_showQueueStateHint)
                          TextButton(
                            key: const ValueKey('control-inbox-show-queue-hint'),
                            onPressed: () {
                              setState(() {
                                _restoreQueueStateHint();
                              });
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFBAE6FD),
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Show tip again',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (_showQueueStateHint) ...[
                      const SizedBox(height: 8),
                      Container(
                        key: const ValueKey('control-inbox-queue-hint'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x1438BDF8),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0x5538BDF8)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 1),
                              child: Icon(
                                Icons.lightbulb_outline_rounded,
                                size: 14,
                                color: Color(0xFF7DD3FC),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Tip: tap the queue chip to move between full and high-priority views. Long press it for a quick explanation of the current mode.',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFD9F4FF),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  height: 1.32,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: _dismissQueueStateHint,
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFBAE6FD),
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Hide tip',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 3),
                    Text(
                      snapshot.pendingApprovalCount > 0
                          ? '${snapshot.pendingApprovalCount} client repl${snapshot.pendingApprovalCount == 1 ? 'y' : 'ies'} waiting for operator judgement'
                          : snapshot.awaitingResponseCount > 0
                          ? '${snapshot.awaitingResponseCount} live client ask${snapshot.awaitingResponseCount == 1 ? '' : 's'} waiting for response shaping'
                          : 'No client replies are waiting for approval',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFEAF4FF),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$selectedScopeLabel • $selectedScopeNarrative',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFB8CCE5),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (_openClientLaneAction(
                    clientId: snapshot.selectedClientId,
                    siteId: snapshot.selectedSiteId,
                  ) !=
                  null) ...[
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _openClientLaneAction(
                    clientId: snapshot.selectedClientId,
                    siteId: snapshot.selectedSiteId,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEAF4FF),
                    side: BorderSide(color: accent.withValues(alpha: 0.52)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 34),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 15),
                  label: Text(
                    'Open Client Lane',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _commsChip(
                icon: Icons.verified_user_rounded,
                label: '${snapshot.pendingApprovalCount} waiting',
                accent: snapshot.pendingApprovalCount > 0
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF34D399),
              ),
              _commsChip(
                icon: Icons.mark_chat_unread_rounded,
                label: '${snapshot.awaitingResponseCount} live ask',
                accent: snapshot.awaitingResponseCount > 0
                    ? const Color(0xFF22D3EE)
                    : const Color(0xFF4B6B8F),
              ),
              _commsChip(
                icon: Icons.pin_drop_rounded,
                label:
                    '$selectedScopeLabel • ${snapshot.selectedScopePendingCount}',
                accent: snapshot.selectedScopePendingCount > 0
                    ? accent
                    : const Color(0xFF4B6B8F),
              ),
              _commsChip(
                icon: Icons.tune_rounded,
                label:
                    'Lane voice ${snapshot.selectedScopeClientVoiceProfileLabel}',
                accent: const Color(0xFF4B6B8F),
              ),
              _commsChip(
                icon: Icons.telegram_rounded,
                label: 'Telegram ${snapshot.telegramHealthLabel.toUpperCase()}',
                accent: _telegramHealthAccent(snapshot.telegramHealthLabel),
              ),
              if (snapshot.telegramFallbackActive)
                _commsChip(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Fallback active',
                  accent: const Color(0xFFF97316),
                ),
            ],
          ),
          if (cueSummaryItems.isNotEmpty) ...[
            const SizedBox(height: 8),
            Semantics(
              label: cueSummaryText,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Queue shape',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFA9BFD9),
                      fontSize: 10.2,
                      fontWeight: FontWeight.w700,
                      height: 1.28,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final item in cueSummaryItems)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            key: ValueKey(
                              'control-inbox-summary-pill-${_controlInboxCueSummaryLabel(item.$1)}',
                            ),
                            borderRadius: BorderRadius.circular(999),
                            onTap: () => _toggleControlInboxCueOnlyKind(item.$1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: (_controlInboxCueOnlyKind == item.$1
                                        ? _controlInboxDraftCueChipAccent(item.$1)
                                        : _controlInboxDraftCueChipAccent(item.$1)
                                    )
                                    .withValues(
                                      alpha: _controlInboxCueOnlyKind == item.$1
                                          ? 0.26
                                          : 0.16,
                                    ),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: _controlInboxDraftCueChipAccent(
                                    item.$1,
                                  ).withValues(
                                    alpha: _controlInboxCueOnlyKind == item.$1
                                        ? 0.74
                                        : 0.48,
                                  ),
                                ),
                              ),
                              child: Text(
                                '${item.$2} ${_controlInboxCueSummaryLabel(item.$1)}',
                                style: GoogleFonts.inter(
                                  color: _controlInboxDraftCueChipAccent(
                                    item.$1,
                                  ),
                                  fontSize: 9.8,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (_controlInboxCueOnlyKind != null) ...[
              const SizedBox(height: 4),
              Text(
                'Showing ${_controlInboxCueSummaryLabel(_controlInboxCueOnlyKind!)} only. Tap the same pill again or use Show all replies to return to the full queue.',
                style: GoogleFonts.inter(
                  color: _controlInboxDraftCueChipAccent(
                    _controlInboxCueOnlyKind!,
                  ),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1.28,
                ),
              ),
            ] else if (_controlInboxPriorityOnly) ...[
              const SizedBox(height: 4),
              Text(
                'Showing high-priority only. Tap the badge again to return to the full queue.',
                style: GoogleFonts.inter(
                  color: const Color(0xFFFFE1A8),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1.28,
                ),
              ),
            ],
          ],
          if (widget.onSetLaneVoiceProfileForScope != null &&
              !compactPreview) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (laneVoiceBusy)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF8FD1FF),
                    ),
                  ),
                for (final option in const <(String, String?)>[
                  ('Auto', null),
                  ('Concise', 'concise-updates'),
                  ('Reassuring', 'reassurance-forward'),
                  ('Validation-heavy', 'validation-heavy'),
                ])
                  OutlinedButton(
                    onPressed: laneVoiceBusy
                        ? null
                        : () => _setLaneVoiceProfile(
                            LiveClientCommsSnapshot(
                              clientId: snapshot.selectedClientId,
                              siteId: snapshot.selectedSiteId,
                              clientVoiceProfileLabel:
                                  snapshot.selectedScopeClientVoiceProfileLabel,
                            ),
                            option.$2,
                          ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          _laneVoiceOptionSelectedForLabel(
                            snapshot.selectedScopeClientVoiceProfileLabel,
                            option.$2,
                          )
                          ? const Color(0xFFEAF4FF)
                          : const Color(0xFF9AB1CF),
                      backgroundColor:
                          _laneVoiceOptionSelectedForLabel(
                            snapshot.selectedScopeClientVoiceProfileLabel,
                            option.$2,
                          )
                          ? const Color(0xFF1B3148)
                          : Colors.transparent,
                      side: BorderSide(
                        color:
                            _laneVoiceOptionSelectedForLabel(
                              snapshot.selectedScopeClientVoiceProfileLabel,
                              option.$2,
                            )
                            ? const Color(0xFF4B6B8F)
                            : const Color(0xFF35506F),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    child: Text(
                      option.$1,
                      style: GoogleFonts.inter(
                        fontSize: 10.6,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          if (snapshot.pendingDrafts.isEmpty)
            Text(
              visibleClientAsks.isEmpty
                  ? 'The inbox is clear. New client questions and approval drafts will stage here for command.'
                  : 'Client questions are active even though no reply drafts are waiting yet.',
              style: GoogleFonts.inter(
                color: const Color(0xFF9FB7D5),
                fontSize: 10.8,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            )
          else
            Column(
              children: visiblePendingDrafts
                  .map(_controlInboxDraftCard)
                  .toList(growable: false),
            ),
          if (visibleClientAsks.isNotEmpty) ...[
            if (visiblePendingDrafts.isNotEmpty) const SizedBox(height: 4),
            Text(
              'LIVE CLIENT ASKS',
              style: GoogleFonts.inter(
                color: const Color(0xFF8FAFD4),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Column(
              children: visibleClientAsks
                  .map(_controlInboxClientAskCard)
                  .toList(growable: false),
            ),
          ],
          if ((snapshot.telegramHealthDetail ?? '').trim().isNotEmpty &&
              !compactPreview) ...[
            const SizedBox(height: 8),
            Text(
              ClientDeliveryMessageFormatter.humanizeScopedCommsSummary(
                snapshot.telegramHealthDetail!.trim(),
              ),
              style: GoogleFonts.inter(
                color: const Color(0xFF8FA7C8),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1.28,
              ),
            ),
          ],
          ],
        ),
      ),
    );
  }

  Widget _controlInboxClientAskCard(LiveControlInboxClientAsk ask) {
    final accent = ask.matchesSelectedScope
        ? const Color(0xFF22D3EE)
        : const Color(0xFF4B6B8F);
    final scopeLabel = _humanizeOpsScopeLabel(ask.siteId, fallback: ask.siteId);
    final providerLabel = ask.messageProvider.trim().isEmpty
        ? 'client lane'
        : ask.messageProvider.trim();

    return Container(
      key: ValueKey(
        'control-inbox-ask-${ask.clientId}-${ask.siteId}-${ask.occurredAtUtc.toIso8601String()}',
      ),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1825),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$scopeLabel • ${ask.author.trim().isEmpty ? 'Client' : ask.author.trim()}',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFEAF4FF),
                        fontSize: 11.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$providerLabel • ${_commsMomentLabel(ask.occurredAtUtc)}',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8EA4C2),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (_openClientLaneAction(
                    clientId: ask.clientId,
                    siteId: ask.siteId,
                  ) !=
                  null)
                OutlinedButton.icon(
                  onPressed: _openClientLaneAction(
                    clientId: ask.clientId,
                    siteId: ask.siteId,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEAF4FF),
                    side: BorderSide(color: accent.withValues(alpha: 0.42)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: Text(
                    'Shape Reply',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _commsChip(
                icon: ask.matchesSelectedScope
                    ? Icons.my_location_rounded
                    : Icons.travel_explore_rounded,
                label: ask.matchesSelectedScope
                    ? 'Selected lane'
                    : 'Other scope',
                accent: accent,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _clientCommsTextBlock(
            label: 'Client asked',
            text: ask.body.trim(),
            borderColor: accent,
            textColor: const Color(0xFFD8E8FA),
          ),
        ],
      ),
    );
  }

  Widget _controlInboxDraftCard(LiveControlInboxDraft draft) {
    final accent = draft.matchesSelectedScope
        ? const Color(0xFF22D3EE)
        : const Color(0xFFF59E0B);
    final cueKind = _controlInboxDraftCueKindForSignals(
      sourceText: draft.sourceText,
      replyText: draft.draftText,
      clientVoiceProfileLabel: draft.clientVoiceProfileLabel,
      usesLearnedApprovalStyle: draft.usesLearnedApprovalStyle,
    );
    final scopeLabel = _humanizeOpsScopeLabel(
      draft.siteId,
      fallback: draft.siteId,
    );
    final busy = _controlInboxBusyDraftIds.contains(draft.updateId);

    return Container(
      key: ValueKey('control-inbox-draft-${draft.updateId}'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF101A27),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.36)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$scopeLabel • Draft #${draft.updateId}',
                style: GoogleFonts.inter(
                  color: const Color(0xFFEAF4FF),
                  fontSize: 11.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${draft.providerLabel.trim().isEmpty ? 'AI provider' : draft.providerLabel.trim()} • ${_commsMomentLabel(draft.createdAtUtc)}',
                style: GoogleFonts.inter(
                  color: const Color(0xFF8EA4C2),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _commsChip(
                    icon: draft.matchesSelectedScope
                        ? Icons.my_location_rounded
                        : Icons.travel_explore_rounded,
                    label: draft.matchesSelectedScope
                        ? 'Selected lane'
                        : 'Other scope',
                    accent: accent,
                  ),
                  _commsChip(
                    icon: Icons.tune_rounded,
                    label: 'Voice ${draft.clientVoiceProfileLabel}',
                    accent: const Color(0xFF4B6B8F),
                  ),
                  _commsChip(
                    icon: _controlInboxDraftCueChipIcon(cueKind),
                    label: _controlInboxDraftCueChipLabel(cueKind),
                    accent: _controlInboxDraftCueChipAccent(cueKind),
                  ),
                  if (draft.clientVoiceProfileLabel.trim().toLowerCase() !=
                      'auto')
                    _commsChip(
                      icon: Icons.auto_fix_high_rounded,
                      label: 'Voice-adjusted',
                      accent: const Color(0xFF34D399),
                    ),
                  if (draft.usesLearnedApprovalStyle)
                    _commsChip(
                      icon: Icons.psychology_alt_rounded,
                      label: 'Uses learned approval style',
                      accent: const Color(0xFF67E8F9),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          _clientCommsTextBlock(
            label: 'Client asked',
            text: draft.sourceText.trim(),
            borderColor: const Color(0xFF31465F),
            textColor: const Color(0xFFD4E4F7),
          ),
          const SizedBox(height: 7),
          _clientCommsTextBlock(
            label: 'ONYX draft',
            text: draft.draftText.trim(),
            borderColor: accent,
            textColor: const Color(0xFFEAF4FF),
          ),
          const SizedBox(height: 7),
          Text(
            _controlInboxDraftCue(draft),
            style: GoogleFonts.inter(
              color: const Color(0xFFB7CAE3),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.32,
            ),
          ),
          if (draft.usesLearnedApprovalStyle) ...[
            const SizedBox(height: 7),
            Text(
              'This draft is already leaning on learned approval wording from this lane.',
              style: GoogleFonts.inter(
                color: const Color(0xFFB7CAE3),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1.32,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: widget.onApproveClientReplyDraft == null || busy
                    ? null
                    : () => _approveControlInboxDraft(draft),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D5B),
                  foregroundColor: const Color(0xFFEAF4FF),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
                icon: const Icon(Icons.check_rounded, size: 14),
                label: Text(
                  'Approve + Send',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed:
                    widget.onUpdateClientReplyDraftText == null ||
                        busy ||
                        _controlInboxDraftEditBusyIds.contains(draft.updateId)
                    ? null
                    : () => _editControlInboxDraft(draft),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB9D9FF),
                  side: const BorderSide(color: Color(0xFF35506F)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
                icon: const Icon(Icons.edit_rounded, size: 14),
                label: Text(
                  'Edit Draft',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: widget.onRejectClientReplyDraft == null || busy
                    ? null
                    : () => _rejectControlInboxDraft(draft),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF87171),
                  side: const BorderSide(color: Color(0xFF5B242C)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
                icon: const Icon(Icons.close_rounded, size: 14),
                label: Text(
                  'Reject',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_openClientLaneAction(
                    clientId: draft.clientId,
                    siteId: draft.siteId,
                  ) !=
                  null)
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : _openClientLaneAction(
                          clientId: draft.clientId,
                          siteId: draft.siteId,
                        ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8FD1FF),
                    side: BorderSide(color: accent.withValues(alpha: 0.42)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: Text(
                    'Open Client Lane',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _incidentQueuePanel({required bool embeddedScroll}) {
    final wide = embeddedScroll;
    Widget incidentTile(int index) {
      final incident = _incidents[index];
      final priority = _priorityStyle(incident.priority);
      final isActive = incident.id == _activeIncidentId;
      final isP1 = incident.priority == _IncidentPriority.p1Critical;
      return TweenAnimationBuilder<double>(
        duration: Duration(milliseconds: 180 + (index * 50)),
        tween: Tween(begin: 0, end: 1),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset((1 - value) * 12, 0),
              child: child,
            ),
          );
        },
        child: AnimatedContainer(
          key: Key('incident-card-${incident.id}'),
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isActive
                ? const Color(0x3322D3EE)
                : isP1
                ? const Color(0x14EF4444)
                : const Color(0x14000000),
            border: Border.all(
              color: isActive
                  ? const Color(0x9922D3EE)
                  : priority.border.withValues(alpha: 0.55),
            ),
            boxShadow: [
              if (isActive)
                const BoxShadow(
                  color: Color(0x4022D3EE),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              if (isP1)
                const BoxShadow(
                  color: Color(0x24EF4444),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              setState(() {
                _activeIncidentId = incident.id;
              });
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(priority.icon, color: priority.foreground, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              incident.id,
                              style: GoogleFonts.robotoMono(
                                color: const Color(0xFF22D3EE),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            incident.timestamp,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF8BA3C4),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        incident.type,
                        style: GoogleFonts.inter(
                          color: const Color(0xFFE6F0FF),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        incident.site,
                        style: GoogleFonts.inter(
                          color: const Color(0xFFA4BAD7),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: _statusChipColor(
                                incident.status,
                              ).withValues(alpha: 0.16),
                              border: Border.all(
                                color: _statusChipColor(
                                  incident.status,
                                ).withValues(alpha: 0.44),
                              ),
                            ),
                            child: Text(
                              _statusLabel(incident.status),
                              style: GoogleFonts.inter(
                                color: _statusChipColor(incident.status),
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (isActive) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: Color(0xFF22D3EE),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Active',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF22D3EE),
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: priority.background,
                    border: Border.all(color: priority.border),
                  ),
                  child: Text(
                    priority.label,
                    style: GoogleFonts.inter(
                      color: priority.foreground,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _panel(
      title: 'Incident Queue',
      subtitle: 'All active incidents, priority sorted',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Live',
                style: GoogleFonts.inter(
                  color: const Color(0xFFA3BAD8),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${_incidents.where((incident) => incident.priority == _IncidentPriority.p1Critical).length} Critical',
                style: GoogleFonts.inter(
                  color: const Color(0xFFEF4444),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_incidents.where((incident) => incident.priority == _IncidentPriority.p2High).length} High',
                style: GoogleFonts.inter(
                  color: const Color(0xFFF59E0B),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (wide)
            Expanded(
              child: ListView.separated(
                itemCount: _incidents.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) => incidentTile(index),
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < _incidents.length; i++) ...[
                  incidentTile(i),
                  if (i < _incidents.length - 1) const SizedBox(height: 8),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _actionLadderPanel(
    _IncidentRecord? activeIncident, {
    required bool embeddedScroll,
  }) {
    final steps = _ladderStepsFor(activeIncident);
    final wide = embeddedScroll;
    Widget stepTile(int index) {
      final step = steps[index];
      final isActive = step.status == _LadderStepStatus.active;
      final statusColor = _stepColor(step.status);
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: const Color(0x14000000),
          border: Border.all(color: const Color(0xFF2A3F5F)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 56,
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF22D3EE)
                    : const Color(0x0022D3EE),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 8),
            Icon(_stepIcon(step.status), color: statusColor, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          step.name,
                          style: GoogleFonts.inter(
                            color: const Color(0xFFE7F1FF),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        _stepLabel(step.status),
                        style: GoogleFonts.inter(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  if ((step.timestamp ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      step.timestamp!,
                      style: GoogleFonts.robotoMono(
                        color: const Color(0xFF86A0C5),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if ((step.details ?? '').isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      step.details!,
                      style: GoogleFonts.inter(
                        color: const Color(0xFFA6BDD9),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if ((step.metadata ?? '').isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      step.metadata!,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8ED3FF),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if ((step.thinkingMessage ?? '').isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      step.thinkingMessage!,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF22D3EE),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (step.status == _LadderStepStatus.active ||
                      step.status == _LadderStepStatus.thinking) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        OutlinedButton(
                          onPressed: activeIncident == null
                              ? null
                              : () => _openOverrideDialog(activeIncident),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0x66EF4444)),
                            foregroundColor: const Color(0xFFEF4444),
                            backgroundColor: const Color(0x220F1419),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            textStyle: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          child: const Text('Override'),
                        ),
                        OutlinedButton(
                          onPressed: activeIncident == null
                              ? null
                              : () => _pauseAutomation(activeIncident),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0x333B82F6)),
                            foregroundColor: const Color(0xFFBFD1EC),
                            backgroundColor: const Color(0x11000000),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            textStyle: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: const Text('Pause'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    final stepsList = wide
        ? ListView.separated(
            itemCount: steps.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) => stepTile(index),
          )
        : Column(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                stepTile(i),
                if (i < steps.length - 1) const SizedBox(height: 8),
              ],
            ],
          );
    return _panel(
      title: 'Action Ladder',
      subtitle: 'AI execution path with human override control',
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stackHeader = constraints.maxWidth < 560;
              final headline = Text(
                activeIncident == null
                    ? 'No incident selected'
                    : 'Active Incident: ${activeIncident.id}',
                style: GoogleFonts.inter(
                  color: const Color(0xFF94B0D2),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              );
              final overrideButton = OutlinedButton.icon(
                onPressed: activeIncident == null
                    ? null
                    : () => _openOverrideDialog(activeIncident),
                icon: const Icon(Icons.gavel_rounded, size: 16),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0x66EF4444)),
                  foregroundColor: const Color(0xFFEF4444),
                  backgroundColor: const Color(0x220F1419),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  textStyle: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                label: const Text('MANUAL OVERRIDE'),
              );
              if (stackHeader) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    headline,
                    const SizedBox(height: 8),
                    SizedBox(width: double.infinity, child: overrideButton),
                  ],
                );
              }
              return Row(children: [headline, const Spacer(), overrideButton]);
            },
          ),
          const SizedBox(height: 10),
          if (wide) Expanded(child: stepsList) else stepsList,
        ],
      ),
    );
  }

  Widget _contextAndVigilancePanel(
    _IncidentRecord? activeIncident, {
    required bool embeddedScroll,
  }) {
    final wide = embeddedScroll;
    if (!wide) {
      return Column(
        children: [
          _panel(
            title: 'Incident Context',
            subtitle: 'Details, VoIP handshake, and visual verification',
            child: Column(
              children: [
                _contextTabs(),
                const SizedBox(height: 8),
                _activeTab == _ContextTab.details
                    ? _detailsTab(
                        activeIncident,
                        embeddedScroll: false,
                      )
                    : _activeTab == _ContextTab.voip
                    ? _voipTab(
                        activeIncident,
                        embeddedScroll: false,
                      )
                    : _visualTab(
                        activeIncident,
                        embeddedScroll: false,
                      ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _panel(
            title: 'Guard Vigilance',
            subtitle: 'Decay sparkline tracking and escalation posture',
            child: _vigilancePanel(embeddedScroll: false),
          ),
        ],
      );
    }
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: _panel(
            title: 'Incident Context',
            subtitle: 'Details, VoIP handshake, and visual verification',
            child: Column(
              children: [
                _contextTabs(),
                const SizedBox(height: 8),
                Expanded(
                  child: _activeTab == _ContextTab.details
                      ? _detailsTab(
                          activeIncident,
                          embeddedScroll: true,
                        )
                      : _activeTab == _ContextTab.voip
                      ? _voipTab(
                          activeIncident,
                          embeddedScroll: true,
                        )
                      : _visualTab(
                          activeIncident,
                          embeddedScroll: true,
                        ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          flex: 2,
          child: _panel(
            title: 'Guard Vigilance',
            subtitle: 'Decay sparkline tracking and escalation posture',
            child: _vigilancePanel(embeddedScroll: true),
          ),
        ),
      ],
    );
  }

  Widget _detailsTab(
    _IncidentRecord? incident, {
    required bool embeddedScroll,
  }) {
    final wide = embeddedScroll;
    if (incident == null) {
      return _muted('Select an incident from the queue.');
    }
    final duress = _duressDetected(incident);
    final evidenceReady = _evidenceReadyLabel(incident);
    final partnerProgress = _partnerProgressForIncident(incident);
    final siteActivity = _siteActivitySnapshotForIncident(incident);
    final moShadowPosture = _moShadowPostureForIncident(incident);
    final nextShiftDrafts = _nextShiftDraftsForIncident(incident);
    final suppressedReviews = _suppressedSceneReviewsForIncident(incident);
    final clientComms = _clientCommsSnapshotForIncident(incident);
    final rows = <Widget>[
      _metaRow('Incident', incident.id),
      _metaRow('Type', incident.type),
      _metaRow('Site', '${incident.site} Gate'),
      _metaRow('Address', '123 Main Road, Sandton, Johannesburg'),
      _metaRow('GPS', '-26.1076, 28.0567'),
      _metaRow('Status', _statusLabel(incident.status)),
      _metaRow('Risk Rating', '4/5'),
      _metaRow('SLA Tier', 'Gold'),
      _metaRow('Client', 'Sandton HOA'),
      _metaRow('Contact', 'John Sovereign'),
      _metaRow('Client Safe Word', 'PHOENIX'),
      if (clientComms != null) ...[
        const SizedBox(height: 8),
        _clientCommsPulseCard(incident, clientComms),
      ],
      if (siteActivity != null && siteActivity.totalSignals > 0) ...[
        const SizedBox(height: 8),
        _siteActivityTruthCard(incident, siteActivity),
      ],
      if (moShadowPosture != null &&
          moShadowPosture.moShadowMatchCount > 0) ...[
        const SizedBox(height: 8),
        _moShadowCard(incident, moShadowPosture),
      ],
      if (nextShiftDrafts.isNotEmpty) ...[
        const SizedBox(height: 8),
        _nextShiftDraftCard(incident, nextShiftDrafts),
      ],
      if (partnerProgress != null) ...[
        const SizedBox(height: 8),
        _partnerProgressCard(partnerProgress, incident.id),
      ],
      if ((incident.latestIntelHeadline ?? '').trim().isNotEmpty)
        _metaRow(
          'Latest ${widget.videoOpsLabel} Intel',
          incident.latestIntelHeadline!.trim(),
        ),
      if ((incident.latestIntelSummary ?? '').trim().isNotEmpty)
        _metaRow(
          'Intel Detail',
          _compactContextLabel(incident.latestIntelSummary!),
        ),
      if ((incident.latestSceneReviewLabel ?? '').trim().isNotEmpty)
        _metaRow('Scene Review', incident.latestSceneReviewLabel!.trim()),
      if ((incident.latestSceneReviewSummary ?? '').trim().isNotEmpty)
        _metaRow(
          'Review Detail',
          _compactContextLabel(incident.latestSceneReviewSummary!),
        ),
      if ((incident.latestSceneDecisionLabel ?? '').trim().isNotEmpty)
        _metaRow('Scene Action', incident.latestSceneDecisionLabel!.trim()),
      if ((incident.latestSceneDecisionSummary ?? '').trim().isNotEmpty)
        _metaRow(
          'Action Detail',
          _compactContextLabel(incident.latestSceneDecisionSummary!),
        ),
      _metaRow('Evidence Ready', evidenceReady),
      if ((incident.snapshotUrl ?? '').trim().isNotEmpty)
        _metaRow('Snapshot Ref', _compactContextLabel(incident.snapshotUrl!)),
      if ((incident.clipUrl ?? '').trim().isNotEmpty)
        _metaRow('Clip Ref', _compactContextLabel(incident.clipUrl!)),
      if (suppressedReviews.isNotEmpty) ...[
        const SizedBox(height: 8),
        _suppressedSceneReviewQueue(suppressedReviews),
      ],
      if (duress) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0x66EF4444), width: 2),
            color: const Color(0x22EF4444),
            boxShadow: const [
              BoxShadow(
                color: Color(0x30EF4444),
                blurRadius: 14,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFEF4444),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'SILENT DURESS DETECTED',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFFFAAB2),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => _forceDispatch(incident),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: const Color(0xFFF8FCFF),
                  textStyle: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: const Text('FORCED DISPATCH'),
              ),
            ],
          ),
        ),
      ],
    ];
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      );
    }
    return ListView(children: rows);
  }

  LiveClientCommsSnapshot? _clientCommsSnapshotForIncident(
    _IncidentRecord incident,
  ) {
    final snapshot = widget.clientCommsSnapshot;
    if (snapshot == null) {
      return null;
    }
    final incidentClientId = incident.clientId.trim();
    final incidentSiteId = incident.siteId.trim();
    if (incidentClientId.isEmpty || incidentSiteId.isEmpty) {
      return null;
    }
    if (incidentClientId != snapshot.clientId.trim() ||
        incidentSiteId != snapshot.siteId.trim()) {
      return null;
    }
    return snapshot;
  }

  SiteActivityIntelligenceSnapshot? _siteActivitySnapshotForIncident(
    _IncidentRecord incident,
  ) {
    if (incident.clientId.trim().isEmpty || incident.siteId.trim().isEmpty) {
      return null;
    }
    return _siteActivityService.buildSnapshot(
      events: widget.events,
      clientId: incident.clientId,
      siteId: incident.siteId,
    );
  }

  Widget _clientCommsPulseCard(
    _IncidentRecord incident,
    LiveClientCommsSnapshot snapshot,
  ) {
    final cueKind = _liveClientLaneCueKind(snapshot);
    final learnedStyleBusy = _learnedStyleBusyScopeKeys.contains(
      _scopeBusyKey(snapshot.clientId, snapshot.siteId),
    );
    final laneVoiceBusy = _laneVoiceBusyScopeKeys.contains(
      _scopeBusyKey(snapshot.clientId, snapshot.siteId),
    );
    final accent = _clientCommsAccent(snapshot);
    final latestClientMessage =
        (snapshot.latestClientMessage ?? '').trim().isEmpty
        ? 'Client lane is quiet right now. New messages will appear here.'
        : snapshot.latestClientMessage!.trim();
    final pendingDraft = (snapshot.latestPendingDraft ?? '').trim();
    final latestOnyxReply = (snapshot.latestOnyxReply ?? '').trim();
    final responseLabel = pendingDraft.isNotEmpty
        ? 'Pending ONYX Draft'
        : 'Latest lane reply';
    final responseText = pendingDraft.isNotEmpty
        ? pendingDraft
        : latestOnyxReply.isEmpty
        ? 'No lane reply has been logged yet.'
        : latestOnyxReply;
    final responseMoment = _commsMomentLabel(
      pendingDraft.isNotEmpty
          ? snapshot.latestPendingDraftAtUtc
          : snapshot.latestOnyxReplyAtUtc,
    );
    return Container(
      key: Key('client-comms-pulse-${incident.id}'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: 0.18), const Color(0xFF0C1622)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.48)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.forum_rounded, size: 16, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Client Comms Pulse',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEAF4FF),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (_openClientLaneAction(
                    clientId: snapshot.clientId,
                    siteId: snapshot.siteId,
                  ) !=
                  null)
                OutlinedButton.icon(
                  onPressed: _openClientLaneAction(
                    clientId: snapshot.clientId,
                    siteId: snapshot.siteId,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEAF4FF),
                    side: BorderSide(color: accent.withValues(alpha: 0.58)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    minimumSize: const Size(0, 28),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: Text(
                    'Open Lane',
                    style: GoogleFonts.inter(
                      fontSize: 10.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (snapshot.learnedApprovalStyleCount > 0 &&
                  widget.onClearLearnedLaneStyleForScope != null) ...[
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  key: ValueKey(
                    'client-comms-pulse-clear-learned-style-${snapshot.clientId}-${snapshot.siteId}',
                  ),
                  onPressed: learnedStyleBusy
                      ? null
                      : () => _clearLearnedLaneStyle(snapshot),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF9EDCF0),
                    side: const BorderSide(color: Color(0xFF245B72)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    minimumSize: const Size(0, 28),
                  ),
                  icon: learnedStyleBusy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF9EDCF0),
                          ),
                        )
                      : const Icon(Icons.refresh_rounded, size: 14),
                  label: Text(
                    'Clear Learned Style',
                    style: GoogleFonts.inter(
                      fontSize: 10.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${_humanizeOpsScopeLabel(snapshot.siteId, fallback: incident.site)} • ${_clientCommsNarrative(snapshot)}',
            style: GoogleFonts.inter(
              color: const Color(0xFFCEE4FA),
              fontSize: 10.4,
              fontWeight: FontWeight.w600,
              height: 1.28,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _commsChip(
                icon: Icons.mark_chat_unread_rounded,
                label: '${snapshot.clientInboundCount} client msg',
                accent: const Color(0xFF22D3EE),
              ),
              _commsChip(
                icon: Icons.verified_user_rounded,
                label: '${snapshot.pendingApprovalCount} approval',
                accent: snapshot.pendingApprovalCount > 0
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF34D399),
              ),
              _commsChip(
                icon: Icons.telegram_rounded,
                label: 'Telegram ${snapshot.telegramHealthLabel.toUpperCase()}',
                accent: _telegramHealthAccent(snapshot.telegramHealthLabel),
              ),
              _commsChip(
                icon: Icons.sms_rounded,
                label: snapshot.smsFallbackLabel,
                accent: _smsFallbackAccent(
                  snapshot.smsFallbackLabel,
                  ready: snapshot.smsFallbackReady,
                  eligibleNow: snapshot.smsFallbackEligibleNow,
                ),
              ),
              _commsChip(
                icon: Icons.phone_forwarded_rounded,
                label: snapshot.voiceReadinessLabel,
                accent: _voiceReadinessAccent(snapshot.voiceReadinessLabel),
              ),
              _commsChip(
                icon: Icons.outbox_rounded,
                label: 'Push ${snapshot.pushSyncStatusLabel.toUpperCase()}',
                accent: _pushSyncAccent(snapshot.pushSyncStatusLabel),
              ),
              _commsChip(
                icon: _controlInboxDraftCueChipIcon(cueKind),
                label: _controlInboxDraftCueChipLabel(cueKind),
                accent: _controlInboxDraftCueChipAccent(cueKind),
              ),
              if (snapshot.learnedApprovalStyleCount > 0)
                _commsChip(
                  icon: Icons.school_rounded,
                  label: 'Learned style ${snapshot.learnedApprovalStyleCount}',
                  accent: const Color(0xFF22D3EE),
                ),
              if (snapshot.pendingLearnedStyleDraftCount > 0)
                _commsChip(
                  icon: Icons.psychology_alt_rounded,
                  label: snapshot.pendingLearnedStyleDraftCount == 1
                      ? 'ONYX using learned style'
                      : 'ONYX using learned style on ${snapshot.pendingLearnedStyleDraftCount} drafts',
                  accent: const Color(0xFF67E8F9),
                ),
            ],
          ),
          if (widget.onSetLaneVoiceProfileForScope != null) ...[
            const SizedBox(height: 7),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (laneVoiceBusy)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF8FD1FF),
                    ),
                  ),
                for (final option in const <(String, String?)>[
                  ('Auto', null),
                  ('Concise', 'concise-updates'),
                  ('Reassuring', 'reassurance-forward'),
                  ('Validation-heavy', 'validation-heavy'),
                ])
                  OutlinedButton(
                    onPressed: laneVoiceBusy
                        ? null
                        : () => _setLaneVoiceProfile(snapshot, option.$2),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          _laneVoiceOptionSelected(snapshot, option.$2)
                          ? const Color(0xFFEAF4FF)
                          : const Color(0xFF9AB1CF),
                      backgroundColor:
                          _laneVoiceOptionSelected(snapshot, option.$2)
                          ? const Color(0xFF1B3148)
                          : Colors.transparent,
                      side: BorderSide(
                        color: _laneVoiceOptionSelected(snapshot, option.$2)
                            ? const Color(0xFF4B6B8F)
                            : const Color(0xFF35506F),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                    ),
                    child: Text(
                      option.$1,
                      style: GoogleFonts.inter(
                        fontSize: 10.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 7),
          Text(
            _liveClientLaneCue(snapshot),
            style: GoogleFonts.inter(
              color: const Color(0xFFA9BFD9),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.28,
            ),
          ),
          const SizedBox(height: 8),
          _clientCommsTextBlock(
            label: 'Latest Client Message',
            text:
                '$latestClientMessage${_commsMomentLabel(snapshot.latestClientMessageAtUtc).isEmpty ? '' : ' • ${_commsMomentLabel(snapshot.latestClientMessageAtUtc)}'}',
            borderColor: const Color(0xFF31506F),
            textColor: const Color(0xFFD8E8FA),
          ),
          const SizedBox(height: 7),
          _clientCommsTextBlock(
            label: responseLabel,
            text:
                '$responseText${responseMoment.isEmpty ? '' : ' • $responseMoment'}',
            borderColor: accent,
            textColor: const Color(0xFFEAF4FF),
          ),
          if ((snapshot.latestSmsFallbackStatus ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 7),
            _clientCommsTextBlock(
              label: 'Latest SMS fallback',
              text:
                  '${ClientDeliveryMessageFormatter.humanizeScopedCommsSummary(snapshot.latestSmsFallbackStatus!.trim())}${_commsMomentLabel(snapshot.latestSmsFallbackAtUtc).isEmpty ? '' : ' • ${_commsMomentLabel(snapshot.latestSmsFallbackAtUtc)}'}',
              borderColor: const Color(0xFF2E7D68),
              textColor: const Color(0xFFDDFBF3),
            ),
          ],
          if ((snapshot.latestVoipStageStatus ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 7),
            _clientCommsTextBlock(
              label: 'Latest VoIP stage',
              text:
                  '${ClientDeliveryMessageFormatter.humanizeScopedCommsSummary(snapshot.latestVoipStageStatus!.trim())}${_commsMomentLabel(snapshot.latestVoipStageAtUtc).isEmpty ? '' : ' • ${_commsMomentLabel(snapshot.latestVoipStageAtUtc)}'}',
              borderColor: const Color(0xFF3E6AA6),
              textColor: const Color(0xFFDCEBFF),
            ),
          ],
          if (snapshot.recentDeliveryHistoryLines.isNotEmpty) ...[
            const SizedBox(height: 7),
            _clientCommsTextBlock(
              label: 'Recent delivery history',
              text: snapshot.recentDeliveryHistoryLines.join('\n'),
              borderColor: const Color(0xFF35506F),
              textColor: const Color(0xFFDCE8FF),
            ),
          ],
          if (snapshot.learnedApprovalStyleExample.trim().isNotEmpty) ...[
            const SizedBox(height: 7),
            _clientCommsTextBlock(
              label: 'Learned approval style',
              text: snapshot.learnedApprovalStyleExample.trim(),
              borderColor: const Color(0xFF245B72),
              textColor: const Color(0xFFD9F7FF),
            ),
          ],
          if ((snapshot.telegramHealthDetail ?? '').trim().isNotEmpty ||
              (snapshot.pushSyncFailureReason ?? '').trim().isNotEmpty ||
              snapshot.telegramFallbackActive ||
              snapshot.queuedPushCount > 0) ...[
            const SizedBox(height: 7),
            Text(
              _clientCommsOpsFootnote(snapshot),
              style: GoogleFonts.inter(
                color: const Color(0xFFA9BFD9),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1.28,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _commsChip({
    required IconData icon,
    required String label,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.42)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.2, color: const Color(0xFFEAF4FF)),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFFEAF4FF),
              fontSize: 10.1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _clientCommsTextBlock({
    required String label,
    required String text,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1824),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor.withValues(alpha: 0.52)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 9.8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.35,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            text,
            style: GoogleFonts.inter(
              color: textColor,
              fontSize: 10.8,
              fontWeight: FontWeight.w600,
              height: 1.32,
            ),
          ),
        ],
      ),
    );
  }

  MonitoringGlobalSitePosture? _moShadowPostureForIncident(
    _IncidentRecord incident,
  ) {
    final snapshot = _globalPostureService.buildSnapshot(
      events: widget.events,
      sceneReviewByIntelligenceId: widget.sceneReviewByIntelligenceId,
    );
    for (final site in snapshot.sites) {
      if (site.siteId.trim() == incident.siteId.trim() &&
          site.regionId.trim() == incident.regionId.trim()) {
        return site;
      }
    }
    return null;
  }

  List<MonitoringWatchAutonomyActionPlan> _nextShiftDraftsForIncident(
    _IncidentRecord incident,
  ) {
    if (widget.historicalSyntheticLearningLabels.isEmpty &&
        widget.historicalShadowMoLabels.isEmpty &&
        widget.historicalShadowStrengthLabels.isEmpty) {
      return const <MonitoringWatchAutonomyActionPlan>[];
    }
    return _orchestratorService
        .buildActionIntents(
          events: widget.events,
          sceneReviewByIntelligenceId: widget.sceneReviewByIntelligenceId,
          videoOpsLabel: widget.videoOpsLabel,
          historicalSyntheticLearningLabels:
              widget.historicalSyntheticLearningLabels,
          historicalShadowMoLabels: widget.historicalShadowMoLabels,
          historicalShadowStrengthLabels: widget.historicalShadowStrengthLabels,
        )
        .where((plan) => plan.metadata['scope'] == 'NEXT_SHIFT')
        .where(
          (plan) =>
              plan.siteId.trim() == incident.siteId.trim() ||
              (plan.metadata['lead_site'] ?? '').trim() ==
                  incident.siteId.trim() ||
              (plan.metadata['region'] ?? '').trim() ==
                  incident.regionId.trim(),
        )
        .toList(growable: false);
  }

  List<MonitoringWatchAutonomyActionPlan> _readinessBiasesForIncident(
    _IncidentRecord incident,
  ) {
    if (widget.historicalShadowMoLabels.isEmpty &&
        widget.historicalShadowStrengthLabels.isEmpty) {
      return const <MonitoringWatchAutonomyActionPlan>[];
    }
    return _orchestratorService
        .buildActionIntents(
          events: widget.events,
          sceneReviewByIntelligenceId: widget.sceneReviewByIntelligenceId,
          videoOpsLabel: widget.videoOpsLabel,
          historicalSyntheticLearningLabels:
              widget.historicalSyntheticLearningLabels,
          historicalShadowMoLabels: widget.historicalShadowMoLabels,
          historicalShadowStrengthLabels: widget.historicalShadowStrengthLabels,
        )
        .where((plan) => plan.metadata['scope'] == 'READINESS')
        .where(
          (plan) =>
              plan.siteId.trim() == incident.siteId.trim() ||
              (plan.metadata['lead_site'] ?? '').trim() ==
                  incident.siteId.trim() ||
              (plan.metadata['region'] ?? '').trim() ==
                  incident.regionId.trim(),
        )
        .toList(growable: false);
  }

  MonitoringWatchAutonomyActionPlan? _syntheticPolicyForIncident(
    _IncidentRecord incident,
  ) {
    final plans = _syntheticWarRoomService.buildSimulationPlans(
      events: widget.events,
      sceneReviewByIntelligenceId: widget.sceneReviewByIntelligenceId,
      videoOpsLabel: widget.videoOpsLabel,
      historicalLearningLabels: widget.historicalSyntheticLearningLabels,
      historicalShadowMoLabels: widget.historicalShadowMoLabels,
    );
    for (final plan in plans) {
      if (plan.actionType != 'POLICY RECOMMENDATION') {
        continue;
      }
      if (plan.siteId.trim() == incident.siteId.trim() ||
          (plan.metadata['lead_site'] ?? '').trim() == incident.siteId.trim() ||
          (plan.metadata['region'] ?? '').trim() == incident.regionId.trim()) {
        return plan;
      }
    }
    return null;
  }

  String _promotionPressureSummaryForPlan(
    MonitoringWatchAutonomyActionPlan plan,
  ) {
    final prebuiltSummary =
        (plan.metadata['mo_promotion_pressure_summary'] ?? '').trim();
    if (prebuiltSummary.isNotEmpty) {
      return prebuiltSummary;
    }
    final baseSummary = (plan.metadata['mo_promotion_summary'] ?? '').trim();
    if (baseSummary.isEmpty) {
      return '';
    }
    return buildSyntheticPromotionSummary(
      baseSummary: baseSummary,
      shadowPostureBiasSummary: _shadowPostureBiasSummaryForPlan(plan),
    );
  }

  String _promotionExecutionSummaryForPlan(
    MonitoringWatchAutonomyActionPlan plan,
  ) {
    return buildSyntheticPromotionExecutionBiasSummary(
      promotionPriorityBias: (plan.metadata['mo_promotion_priority_bias'] ?? '')
          .trim(),
      promotionCountdownBias:
          (plan.metadata['mo_promotion_countdown_bias'] ?? '').trim(),
    );
  }

  String _shadowPostureBiasSummaryForPlan(
    MonitoringWatchAutonomyActionPlan plan,
  ) {
    final prebuiltSummary = (plan.metadata['shadow_posture_bias_summary'] ?? '')
        .trim();
    if (prebuiltSummary.isNotEmpty) {
      return prebuiltSummary;
    }
    final postureBias = (plan.metadata['shadow_posture_bias'] ?? '').trim();
    final posturePriority = (plan.metadata['shadow_posture_priority'] ?? '')
        .trim();
    final postureCountdown = (plan.metadata['shadow_posture_countdown'] ?? '')
        .trim();
    if (postureBias.isEmpty &&
        posturePriority.isEmpty &&
        postureCountdown.isEmpty) {
      return '';
    }
    final parts = <String>[
      if (postureBias.isNotEmpty) postureBias,
      if (posturePriority.isNotEmpty) posturePriority,
      if (postureCountdown.isNotEmpty) '${postureCountdown}s',
    ];
    return parts.join(' • ');
  }

  Widget _nextShiftDraftCard(
    _IncidentRecord incident,
    List<MonitoringWatchAutonomyActionPlan> drafts,
  ) {
    final leadDraft = drafts.first;
    final readinessBiases = _readinessBiasesForIncident(incident);
    final leadBias = readinessBiases.isEmpty ? null : readinessBiases.first;
    final linkedSyntheticPolicy = _syntheticPolicyForIncident(incident);
    final learningLabel = (leadDraft.metadata['learning_label'] ?? '').trim();
    final repeatCount = (leadDraft.metadata['learning_repeat_count'] ?? '')
        .trim();
    final shadowLabel = (leadDraft.metadata['shadow_mo_label'] ?? '').trim();
    final shadowRepeatCount =
        (leadDraft.metadata['shadow_mo_repeat_count'] ?? '').trim();
    final promotionPressureSummary = linkedSyntheticPolicy == null
        ? ''
        : _promotionPressureSummaryForPlan(linkedSyntheticPolicy);
    final promotionExecutionSummary = linkedSyntheticPolicy == null
        ? ''
        : _promotionExecutionSummaryForPlan(linkedSyntheticPolicy);
    return Container(
      key: ValueKey('live-next-shift-draft-card-${incident.id}'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x665C7CFA)),
        color: const Color(0x221B1F45),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Next-Shift Drafts',
                style: GoogleFonts.inter(
                  color: const Color(0xFFC8D2FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${drafts.length} draft${drafts.length == 1 ? '' : 's'}',
                style: GoogleFonts.inter(
                  color: const Color(0xFFA6BDD9),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (learningLabel.isNotEmpty) _metaRow('Learning', learningLabel),
          if (repeatCount.isNotEmpty)
            _metaRow(
              'Memory',
              'Repeated across $repeatCount recent shift${repeatCount == '1' ? '' : 's'}',
            ),
          if (shadowLabel.isNotEmpty)
            _metaRow(
              'Shadow',
              '$shadowLabel${shadowRepeatCount.isEmpty ? '' : ' • x$shadowRepeatCount'}',
            ),
          if ((leadDraft.metadata['shadow_strength_bias'] ?? '')
              .trim()
              .isNotEmpty)
            _metaRow(
              'Urgency',
              [
                (leadDraft.metadata['shadow_strength_bias'] ?? '').trim(),
                if ((leadDraft.metadata['shadow_strength_priority'] ?? '')
                    .trim()
                    .isNotEmpty)
                  (leadDraft.metadata['shadow_strength_priority'] ?? '').trim(),
              ].join(' • '),
            ),
          if (widget.previousTomorrowUrgencySummary.trim().isNotEmpty)
            _metaRow(
              'Previous urgency',
              widget.previousTomorrowUrgencySummary.trim(),
            ),
          if (leadBias != null)
            _metaRow(
              'Readiness bias',
              _compactContextLabel(leadBias.description),
            ),
          if (promotionPressureSummary.isNotEmpty)
            _metaRow('Promotion pressure', promotionPressureSummary),
          if (promotionExecutionSummary.isNotEmpty)
            _metaRow('Promotion execution', promotionExecutionSummary),
          _metaRow('Lead Draft', leadDraft.actionType),
          _metaRow('Bias', _compactContextLabel(leadDraft.description)),
          if (drafts.length > 1)
            _metaRow(
              'Supporting',
              drafts.skip(1).map((plan) => plan.actionType).join(' • '),
            ),
        ],
      ),
    );
  }

  Widget _moShadowCard(
    _IncidentRecord incident,
    MonitoringGlobalSitePosture sitePosture,
  ) {
    return Container(
      key: ValueKey('live-mo-shadow-card-${incident.id}'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x665B9BD5)),
        color: const Color(0x2214334A),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Shadow MO Intelligence',
                style: GoogleFonts.inter(
                  color: const Color(0xFFB8D7FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${sitePosture.moShadowMatchCount} match${sitePosture.moShadowMatchCount == 1 ? '' : 'es'}',
                style: GoogleFonts.inter(
                  color: const Color(0xFFA6BDD9),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _metaRow('Pattern', sitePosture.moShadowSummary),
          _metaRow('Signal', 'mo_shadow'),
          _metaRow(
            'Posture Weight',
            shadowMoPostureStrengthSummary(sitePosture),
          ),
          _metaRow('Site Heat', sitePosture.heatLevel.name),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              key: ValueKey('live-mo-shadow-open-dossier-${incident.id}'),
              onPressed: () => _showMoShadowDossier(incident, sitePosture),
              child: const Text('VIEW DOSSIER'),
            ),
          ),
        ],
      ),
    );
  }

  void _showMoShadowDossier(
    _IncidentRecord incident,
    MonitoringGlobalSitePosture sitePosture,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF08111B),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                key: ValueKey('live-mo-shadow-dialog-${incident.id}'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'SHADOW MO DOSSIER',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFEAF4FF),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          final pretty = const JsonEncoder.withIndent(
                            '  ',
                          ).convert(_moShadowPayload(incident, sitePosture));
                          Clipboard.setData(ClipboardData(text: pretty));
                          Navigator.of(dialogContext).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Shadow MO dossier copied'),
                            ),
                          );
                        },
                        child: const Text('COPY JSON'),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close, color: Color(0xFFEAF4FF)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${incident.site} • ${sitePosture.moShadowSummary}',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFEAF4FF),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.separated(
                      itemCount: sitePosture.moShadowMatches.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final match = sitePosture.moShadowMatches[index];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0x14000000),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0x335B9BD5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                match.title,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFB8D7FF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Indicators ${match.matchedIndicators.join(', ')}',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF9AB5D7),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (match.validationStatus.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Strength ${shadowMoStrengthSummary(match)}',
                                  style: GoogleFonts.robotoMono(
                                    color: const Color(0xFF8FD1FF),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                              if (match.recommendedActionPlans.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Actions ${match.recommendedActionPlans.join(' • ')}',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF8FD1FF),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              if (widget.onOpenEventsForScope != null &&
                                  sitePosture.moShadowEventIds.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: OutlinedButton(
                                    onPressed: () {
                                      Navigator.of(dialogContext).pop();
                                      widget.onOpenEventsForScope!(
                                        sitePosture.moShadowEventIds,
                                        sitePosture.moShadowSelectedEventId,
                                      );
                                    },
                                    child: const Text('OPEN EVIDENCE'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Map<String, Object?> _moShadowPayload(
    _IncidentRecord incident,
    MonitoringGlobalSitePosture sitePosture,
  ) {
    return buildShadowMoSitePayload(
      sitePosture,
      metadata: <String, Object?>{
        'incidentId': incident.id,
        'clientId': incident.clientId,
        'regionId': incident.regionId,
        'siteId': incident.siteId,
        'siteHeat': sitePosture.heatLevel.name,
      },
    );
  }

  Widget _siteActivityTruthCard(
    _IncidentRecord incident,
    SiteActivityIntelligenceSnapshot snapshot,
  ) {
    final canOpenEvents =
        widget.onOpenEventsForScope != null && snapshot.eventIds.isNotEmpty;
    return Container(
      key: ValueKey('live-activity-truth-card-${incident.id}'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A3D58)),
        color: const Color(0x14000000),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Activity Truth',
                style: GoogleFonts.inter(
                  color: const Color(0xFF8FD1FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${snapshot.totalSignals} signals',
                style: GoogleFonts.inter(
                  color: const Color(0xFFA6BDD9),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _metaRow('Summary', snapshot.summaryLine),
          _metaRow(
            'Known / Unknown',
            '${snapshot.knownIdentitySignals} known • ${snapshot.unknownPersonSignals + snapshot.unknownVehicleSignals} unknown',
          ),
          if (snapshot.topFlaggedIdentitySummary.trim().isNotEmpty)
            _metaRow('Flagged', snapshot.topFlaggedIdentitySummary),
          if (snapshot.topLongPresenceSummary.trim().isNotEmpty)
            _metaRow('Long Presence', snapshot.topLongPresenceSummary),
          if (snapshot.topGuardInteractionSummary.trim().isNotEmpty)
            _metaRow('Guard Note', snapshot.topGuardInteractionSummary),
          if (snapshot.evidenceEventIds.isNotEmpty)
            _metaRow('Review Refs', snapshot.evidenceEventIds.join(', ')),
          if (canOpenEvents) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                key: ValueKey('live-activity-truth-open-events-${incident.id}'),
                onPressed: () {
                  widget.onOpenEventsForScope!(
                    snapshot.eventIds,
                    snapshot.selectedEventId,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Opening Events Review for activity truth.',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFE7F0FF),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      backgroundColor: const Color(0xFF0E203A),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF23547C)),
                  foregroundColor: const Color(0xFF8FD1FF),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  textStyle: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Open Events Review'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<_SuppressedSceneReviewContext> _suppressedSceneReviewsForIncident(
    _IncidentRecord incident,
  ) {
    final siteId = incident.site.trim();
    final output = <_SuppressedSceneReviewContext>[];
    for (final intel in widget.events.whereType<IntelligenceReceived>()) {
      if (intel.siteId.trim() != siteId) {
        continue;
      }
      if (intel.sourceType != 'hardware' && intel.sourceType != 'dvr') {
        continue;
      }
      final review =
          widget.sceneReviewByIntelligenceId[intel.intelligenceId.trim()];
      if (review == null) {
        continue;
      }
      final decisionLabel = review.decisionLabel.trim().toLowerCase();
      final decisionSummary = review.decisionSummary.trim().toLowerCase();
      if (!decisionLabel.contains('suppress') &&
          !decisionSummary.contains('suppress')) {
        continue;
      }
      output.add(
        _SuppressedSceneReviewContext(intelligence: intel, review: review),
      );
    }
    output.sort(
      (a, b) => b.review.reviewedAtUtc.compareTo(a.review.reviewedAtUtc),
    );
    return output.take(3).toList(growable: false);
  }

  Widget _suppressedSceneReviewQueue(
    List<_SuppressedSceneReviewContext> entries,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A3D58)),
        color: const Color(0x14000000),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Suppressed ${widget.videoOpsLabel} Reviews',
                style: GoogleFonts.inter(
                  color: const Color(0xFFE4EEFF),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              _contextChip(
                label: '${entries.length} internal',
                foreground: const Color(0xFFBFD7F2),
                background: const Color(0x149AB1CF),
                border: const Color(0x339AB1CF),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Recent ${widget.videoOpsLabel} reviews ONYX held below the client notification threshold for this site.',
            style: GoogleFonts.inter(
              color: const Color(0xFF7F95B6),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...entries.asMap().entries.map((entry) {
            final item = entry.value;
            final intel = item.intelligence;
            final review = item.review;
            final cameraLabel = (intel.cameraId ?? '').trim();
            final zoneLabel = (intel.zone ?? '').trim();
            final sourceLabel = review.sourceLabel.trim();
            final postureLabel = review.postureLabel.trim();
            return Container(
              width: double.infinity,
              margin: EdgeInsets.only(
                bottom: entry.key == entries.length - 1 ? 0 : 8,
              ),
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFF0F1419),
                border: Border.all(color: const Color(0xFF24364F)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          intel.headline.trim(),
                          style: GoogleFonts.inter(
                            color: const Color(0xFFE4EEFF),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _hhmm(review.reviewedAtUtc.toLocal()),
                        style: GoogleFonts.robotoMono(
                          color: const Color(0xFF8FA7C8),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    review.decisionSummary.trim().isEmpty
                        ? 'Suppressed because the activity remained below threshold.'
                        : review.decisionSummary.trim(),
                    style: GoogleFonts.inter(
                      color: const Color(0xFFE4EEFF),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Scene review: ${review.summary.trim()}',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF7F95B6),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _contextChip(
                        label: sourceLabel.isEmpty ? 'metadata' : sourceLabel,
                        foreground: const Color(0xFFFDE68A),
                        background: const Color(0x145B3A16),
                        border: const Color(0x665B3A16),
                      ),
                      _contextChip(
                        label: postureLabel.isEmpty ? 'reviewed' : postureLabel,
                        foreground: const Color(0xFF86EFAC),
                        background: const Color(0x1420643B),
                        border: const Color(0x6634D399),
                      ),
                      if (cameraLabel.isNotEmpty)
                        _contextChip(
                          label: cameraLabel,
                          foreground: const Color(0xFF67E8F9),
                          background: const Color(0x1122D3EE),
                          border: const Color(0x5522D3EE),
                        ),
                      if (zoneLabel.isNotEmpty)
                        _contextChip(
                          label: zoneLabel,
                          foreground: const Color(0xFFBFD7F2),
                          background: const Color(0x14000000),
                          border: const Color(0xFF2A3D58),
                        ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  _PartnerLiveProgressSummary? _partnerProgressForIncident(
    _IncidentRecord incident,
  ) {
    final incidentId = incident.id.trim();
    if (incidentId.isEmpty) {
      return null;
    }
    final candidateDispatchIds = <String>{
      incidentId,
      if (incidentId.startsWith('INC-')) incidentId.substring(4).trim(),
    }..removeWhere((value) => value.isEmpty);
    final declarations = widget.events
        .whereType<PartnerDispatchStatusDeclared>()
        .where(
          (event) => candidateDispatchIds.contains(event.dispatchId.trim()),
        )
        .toList(growable: false);
    if (declarations.isEmpty) {
      return null;
    }
    final ordered = [...declarations]
      ..sort((a, b) {
        final occurredAtCompare = a.occurredAt.compareTo(b.occurredAt);
        if (occurredAtCompare != 0) {
          return occurredAtCompare;
        }
        return a.sequence.compareTo(b.sequence);
      });
    final first = ordered.first;
    final latest = ordered.last;
    final firstOccurrenceByStatus = <PartnerDispatchStatus, DateTime>{};
    for (final event in ordered) {
      firstOccurrenceByStatus.putIfAbsent(event.status, () => event.occurredAt);
    }
    return _PartnerLiveProgressSummary(
      dispatchId: first.dispatchId,
      clientId: first.clientId,
      siteId: first.siteId,
      partnerLabel: first.partnerLabel,
      latestStatus: latest.status,
      latestOccurredAt: latest.occurredAt,
      declarationCount: ordered.length,
      firstOccurrenceByStatus: firstOccurrenceByStatus,
    );
  }

  _PartnerLiveTrendSummary? _partnerTrendSummary(
    _PartnerLiveProgressSummary progress,
  ) {
    final clientId = progress.clientId.trim();
    final siteId = progress.siteId.trim();
    final partnerLabel = progress.partnerLabel.trim().toUpperCase();
    if (clientId.isEmpty ||
        siteId.isEmpty ||
        partnerLabel.isEmpty ||
        widget.morningSovereignReportHistory.isEmpty) {
      return null;
    }
    final reports = [...widget.morningSovereignReportHistory]
      ..sort(
        (a, b) => b.generatedAtUtc.toUtc().compareTo(a.generatedAtUtc.toUtc()),
      );
    if (reports.isEmpty) {
      return null;
    }
    final latestDate = reports.first.date.trim();
    final matchingRows = <SovereignReportPartnerScoreboardRow>[];
    SovereignReportPartnerScoreboardRow? currentRow;
    for (final report in reports) {
      final reportDate = report.date.trim();
      for (final row in report.partnerProgression.scoreboardRows) {
        if (!_partnerScoreboardRowMatches(
          row,
          clientId: clientId,
          siteId: siteId,
          partnerLabel: partnerLabel,
        )) {
          continue;
        }
        matchingRows.add(row);
        if (reportDate == latestDate) {
          currentRow = row;
        }
      }
    }
    if (matchingRows.isEmpty) {
      for (final report in reports) {
        final reportDate = report.date.trim();
        for (final row in report.partnerProgression.scoreboardRows) {
          if (row.partnerLabel.trim().toUpperCase() != partnerLabel) {
            continue;
          }
          matchingRows.add(row);
          if (reportDate == latestDate) {
            currentRow = row;
          }
        }
      }
    }
    if (matchingRows.isEmpty) {
      for (final report in reports) {
        final reportDate = report.date.trim();
        for (final row in report.partnerProgression.scoreboardRows) {
          matchingRows.add(row);
          if (currentRow == null && reportDate == latestDate) {
            currentRow = row;
          }
        }
      }
    }
    currentRow ??= matchingRows.isEmpty ? null : matchingRows.first;
    if (currentRow == null) {
      return null;
    }
    final priorSeverityScores = <double>[];
    final priorAcceptedDelayMinutes = <double>[];
    final priorOnSiteDelayMinutes = <double>[];
    for (final report in reports) {
      if (report.date.trim() == latestDate) {
        continue;
      }
      for (final row in report.partnerProgression.scoreboardRows) {
        if (!_partnerScoreboardRowMatches(
          row,
          clientId: clientId,
          siteId: siteId,
          partnerLabel: partnerLabel,
        )) {
          continue;
        }
        priorSeverityScores.add(_partnerSeverityScore(row));
        if (row.averageAcceptedDelayMinutes > 0) {
          priorAcceptedDelayMinutes.add(row.averageAcceptedDelayMinutes);
        }
        if (row.averageOnSiteDelayMinutes > 0) {
          priorOnSiteDelayMinutes.add(row.averageOnSiteDelayMinutes);
        }
      }
    }
    return _PartnerLiveTrendSummary(
      reportDays: matchingRows.length,
      currentScoreLabel: _partnerDominantScoreLabel(currentRow),
      trendLabel: _partnerTrendLabel(currentRow, priorSeverityScores),
      trendReason: _partnerTrendReason(
        currentRow: currentRow,
        priorSeverityScores: priorSeverityScores,
        priorAcceptedDelayMinutes: priorAcceptedDelayMinutes,
        priorOnSiteDelayMinutes: priorOnSiteDelayMinutes,
      ),
    );
  }

  _PartnerLiveTrendSummary? _fallbackPartnerTrendSummary() {
    if (widget.morningSovereignReportHistory.isEmpty) {
      return null;
    }
    final reports = [...widget.morningSovereignReportHistory]
      ..sort(
        (a, b) => b.generatedAtUtc.toUtc().compareTo(a.generatedAtUtc.toUtc()),
      );
    if (reports.isEmpty) {
      return null;
    }
    final currentRows = reports.first.partnerProgression.scoreboardRows;
    if (currentRows.isEmpty) {
      return null;
    }
    final currentRow = currentRows.first;
    final priorSeverityScores = <double>[];
    final priorAcceptedDelayMinutes = <double>[];
    final priorOnSiteDelayMinutes = <double>[];
    for (final report in reports.skip(1)) {
      if (report.partnerProgression.scoreboardRows.isEmpty) {
        continue;
      }
      final row = report.partnerProgression.scoreboardRows.first;
      priorSeverityScores.add(_partnerSeverityScore(row));
      if (row.averageAcceptedDelayMinutes > 0) {
        priorAcceptedDelayMinutes.add(row.averageAcceptedDelayMinutes);
      }
      if (row.averageOnSiteDelayMinutes > 0) {
        priorOnSiteDelayMinutes.add(row.averageOnSiteDelayMinutes);
      }
    }
    return _PartnerLiveTrendSummary(
      reportDays: reports.length,
      currentScoreLabel: _partnerDominantScoreLabel(currentRow),
      trendLabel: _partnerTrendLabel(currentRow, priorSeverityScores),
      trendReason: _partnerTrendReason(
        currentRow: currentRow,
        priorSeverityScores: priorSeverityScores,
        priorAcceptedDelayMinutes: priorAcceptedDelayMinutes,
        priorOnSiteDelayMinutes: priorOnSiteDelayMinutes,
      ),
    );
  }

  double _partnerSeverityScore(SovereignReportPartnerScoreboardRow row) {
    final dispatchCount = row.dispatchCount <= 0 ? 1 : row.dispatchCount;
    final rawScore = (row.criticalCount * 3) + row.watchCount - row.strongCount;
    return rawScore / dispatchCount;
  }

  String _partnerDominantScoreLabel(SovereignReportPartnerScoreboardRow row) {
    if (row.criticalCount > 0) {
      return 'CRITICAL';
    }
    if (row.watchCount > 0) {
      return 'WATCH';
    }
    if (row.onTrackCount > 0) {
      return 'ON TRACK';
    }
    if (row.strongCount > 0) {
      return 'STRONG';
    }
    return '';
  }

  bool _partnerScoreboardRowMatches(
    SovereignReportPartnerScoreboardRow row, {
    required String clientId,
    required String siteId,
    required String partnerLabel,
  }) {
    final rowLabel = row.partnerLabel.trim().toUpperCase();
    final rowClientId = row.clientId.trim();
    final rowSiteId = row.siteId.trim();
    if (rowLabel != partnerLabel) {
      return false;
    }
    if (rowClientId == clientId && rowSiteId == siteId) {
      return true;
    }
    if (rowSiteId == siteId) {
      return true;
    }
    return rowClientId == clientId;
  }

  String _partnerTrendLabel(
    SovereignReportPartnerScoreboardRow currentRow,
    List<double> priorSeverityScores,
  ) {
    if (priorSeverityScores.isEmpty) {
      return 'NEW';
    }
    final priorAverage =
        priorSeverityScores.reduce((left, right) => left + right) /
        priorSeverityScores.length;
    final currentScore = _partnerSeverityScore(currentRow);
    if (currentScore <= priorAverage - 0.35) {
      return 'IMPROVING';
    }
    if (currentScore >= priorAverage + 0.35) {
      return 'SLIPPING';
    }
    return 'STABLE';
  }

  String _partnerTrendReason({
    required SovereignReportPartnerScoreboardRow currentRow,
    required List<double> priorSeverityScores,
    required List<double> priorAcceptedDelayMinutes,
    required List<double> priorOnSiteDelayMinutes,
  }) {
    if (priorSeverityScores.isEmpty) {
      return 'First recorded shift in the 7-day partner window.';
    }
    final trendLabel = _partnerTrendLabel(currentRow, priorSeverityScores);
    final priorAcceptedAverage = priorAcceptedDelayMinutes.isEmpty
        ? null
        : priorAcceptedDelayMinutes.reduce((left, right) => left + right) /
              priorAcceptedDelayMinutes.length;
    final priorOnSiteAverage = priorOnSiteDelayMinutes.isEmpty
        ? null
        : priorOnSiteDelayMinutes.reduce((left, right) => left + right) /
              priorOnSiteDelayMinutes.length;
    switch (trendLabel) {
      case 'IMPROVING':
        if (priorAcceptedAverage != null &&
            currentRow.averageAcceptedDelayMinutes > 0 &&
            currentRow.averageAcceptedDelayMinutes <=
                priorAcceptedAverage - 2.0) {
          return 'Acceptance timing improved against the prior 7-day average.';
        }
        if (priorOnSiteAverage != null &&
            currentRow.averageOnSiteDelayMinutes > 0 &&
            currentRow.averageOnSiteDelayMinutes <= priorOnSiteAverage - 2.0) {
          return 'On-site timing improved against the prior 7-day average.';
        }
        return 'Current shift severity improved against the prior 7-day average.';
      case 'SLIPPING':
        if (priorAcceptedAverage != null &&
            currentRow.averageAcceptedDelayMinutes >=
                priorAcceptedAverage + 2.0) {
          return 'Acceptance timing slipped beyond the prior 7-day average.';
        }
        if (priorOnSiteAverage != null &&
            currentRow.averageOnSiteDelayMinutes >= priorOnSiteAverage + 2.0) {
          return 'On-site timing slipped beyond the prior 7-day average.';
        }
        return 'Current shift severity slipped against the prior 7-day average.';
      case 'STABLE':
      case 'NEW':
        return 'Current shift is holding close to the prior 7-day performance.';
    }
    return '';
  }

  Widget _partnerProgressCard(
    _PartnerLiveProgressSummary progress,
    String incidentId,
  ) {
    final trend =
        _partnerTrendSummary(progress) ?? _fallbackPartnerTrendSummary();
    return Container(
      key: ValueKey<String>('live-partner-progress-card-$incidentId'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A3D58)),
        color: const Color(0x14000000),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Partner Progression',
                style: GoogleFonts.inter(
                  color: const Color(0xFFE4EEFF),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              _contextChip(
                label: '${progress.declarationCount} declarations',
                foreground: const Color(0xFF8FD1FF),
                background: const Color(0x1122D3EE),
                border: const Color(0x5522D3EE),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${progress.partnerLabel} • Latest ${_partnerDispatchStatusLabel(progress.latestStatus)} • ${_hhmm(progress.latestOccurredAt.toLocal())}',
            style: GoogleFonts.inter(
              color: const Color(0xFFE4EEFF),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _contextChip(
                label: 'Dispatch ${progress.dispatchId}',
                foreground: const Color(0xFFBFD7F2),
                background: const Color(0x14000000),
                border: const Color(0xFF2A3D58),
              ),
              if (trend != null)
                _contextChip(
                  label: '7D ${trend.trendLabel} • ${trend.reportDays}d',
                  foreground: _partnerTrendColor(trend.trendLabel),
                  background: _partnerTrendColor(
                    trend.trendLabel,
                  ).withValues(alpha: 0.12),
                  border: _partnerTrendColor(
                    trend.trendLabel,
                  ).withValues(alpha: 0.45),
                ),
              for (final status in PartnerDispatchStatus.values)
                _partnerProgressChip(
                  incidentId: incidentId,
                  status: status,
                  timestamp: progress.firstOccurrenceByStatus[status],
                ),
            ],
          ),
          if (trend != null) ...[
            const SizedBox(height: 6),
            Text(
              trend.trendReason,
              key: ValueKey<String>('live-partner-trend-reason-$incidentId'),
              style: GoogleFonts.inter(
                color: _partnerTrendColor(trend.trendLabel),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ] else if (widget.morningSovereignReportHistory.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '7-day partner history is available for review in Admin and Governance.',
              key: ValueKey<String>('live-partner-trend-reason-$incidentId'),
              style: GoogleFonts.inter(
                color: const Color(0xFF8FA7C8),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _partnerProgressChip({
    required String incidentId,
    required PartnerDispatchStatus status,
    required DateTime? timestamp,
  }) {
    final reached = timestamp != null;
    final tone = _partnerProgressTone(status);
    return Container(
      key: ValueKey<String>('live-partner-progress-$incidentId-${status.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: reached ? tone.$2 : const Color(0x14000000),
        border: Border.all(color: reached ? tone.$3 : const Color(0xFF2A3D58)),
      ),
      child: Text(
        reached
            ? '${_partnerDispatchStatusLabel(status)} ${_hhmm(timestamp.toLocal())}'
            : '${_partnerDispatchStatusLabel(status)} Pending',
        style: GoogleFonts.inter(
          color: reached ? tone.$1 : const Color(0xFF8FA7C8),
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _voipTab(
    _IncidentRecord? incident, {
    required bool embeddedScroll,
  }) {
    final wide = embeddedScroll;
    if (incident == null) {
      return _muted('No live call transcript for this lane yet.');
    }
    final duress = _duressDetected(incident);
    final transcript = <Map<String, String>>[
      <String, String>{
        'speaker': 'AI',
        'timestamp': '22:14:12',
        'message':
            'Good evening. ONYX Security Operations. We detected an alarm at your north gate. Please confirm your safe word.',
      },
      <String, String>{
        'speaker': 'CLIENT',
        'timestamp': '22:14:18',
        'message': duress ? '... please hold.' : 'Phoenix.',
      },
      <String, String>{
        'speaker': 'AI',
        'timestamp': '22:14:21',
        'message': duress
            ? 'Voice stress confidence dropped. Escalation recommended.'
            : 'Safe-word verification complete. Response team remains en route.',
      },
    ];
    final items = List<Widget>.generate(transcript.length, (index) {
      final entry = transcript[index];
      final speaker = entry['speaker'] ?? '';
      final timestamp = entry['timestamp'] ?? '';
      final message = entry['message'] ?? '';
      final aiSpeaker = speaker == 'AI';
      return Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: aiSpeaker ? const Color(0x1122D3EE) : const Color(0x14000000),
          border: Border.all(
            color: aiSpeaker
                ? const Color(0x5522D3EE)
                : const Color(0xFF2A3D58),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  speaker,
                  style: GoogleFonts.inter(
                    color: aiSpeaker
                        ? const Color(0xFF22D3EE)
                        : const Color(0xFFDCE9FF),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  timestamp,
                  style: GoogleFonts.robotoMono(
                    color: const Color(0xFF8EA8CB),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: GoogleFonts.inter(
                color: index == transcript.length - 1 && duress
                    ? const Color(0xFFFFAAB2)
                    : const Color(0xFFE1ECFF),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    });
    final statusBanner = Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: const Color(0x1122D3EE),
        border: Border.all(color: const Color(0x4422D3EE)),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFF22D3EE),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'VoIP Call Active - Recording in progress',
              style: GoogleFonts.inter(
                color: const Color(0xFF8ED3FF),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (!wide) {
      return Column(
        children: [
          statusBanner,
          const SizedBox(height: 6),
          for (var i = 0; i < items.length; i++) ...[
            items[i],
            if (i < items.length - 1) const SizedBox(height: 6),
          ],
        ],
      );
    }
    return ListView.separated(
      itemCount: items.length + 1,
      separatorBuilder: (context, index) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        if (index == 0) return statusBanner;
        return items[index - 1];
      },
    );
  }

  Widget _visualTab(
    _IncidentRecord? incident, {
    required bool embeddedScroll,
  }) {
    if (incident == null) {
      return _muted('No camera comparison is ready for this lane yet.');
    }
    final snapshotAvailable = (incident.snapshotUrl ?? '').trim().isNotEmpty;
    final clipAvailable = (incident.clipUrl ?? '').trim().isNotEmpty;
    final score = incident.priority == _IncidentPriority.p1Critical
        ? 58
        : incident.priority == _IncidentPriority.p2High
        ? 74
        : 96;
    final scoreColor = score >= 95
        ? const Color(0xFF10B981)
        : score >= 60
        ? const Color(0xFFFACC15)
        : const Color(0xFFEF4444);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _metaRow('NORM', 'NIGHT BASELINE'),
        _metaRow('LIVE', incident.timestamp),
        Row(
          children: [
            Text(
              'Match Score',
              style: GoogleFonts.inter(
                color: const Color(0xFF9CB3D2),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              '$score%',
              style: GoogleFonts.rajdhani(
                color: scoreColor,
                fontSize: 38,
                height: 0.9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _metaRow(
                'Snapshot',
                snapshotAvailable ? 'READY' : 'PENDING',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _metaRow('Clip', clipAvailable ? 'READY' : 'PENDING'),
            ),
          ],
        ),
        if (snapshotAvailable || clipAvailable) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: const Color(0x120F766E),
              border: Border.all(color: const Color(0x5534D399)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (snapshotAvailable)
                  _anomalyRow('Snapshot reference captured', 100),
                if (snapshotAvailable && clipAvailable)
                  const SizedBox(height: 4),
                if (clipAvailable) _anomalyRow('Clip reference captured', 100),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (score < 60) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: const Color(0x18EF4444),
              border: Border.all(color: const Color(0x55EF4444)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _anomalyRow('Gate status changed', 94),
                const SizedBox(height: 4),
                _anomalyRow('Perimeter breach line', 91),
                const SizedBox(height: 4),
                _anomalyRow('Unauthorized vehicle', 86),
              ],
            ),
          ),
        ] else
          _metaRow('Anomalies', '0'),
      ],
    );
  }

  Widget _anomalyRow(String label, int confidence) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFFFFC3C9),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          '$confidence%',
          style: GoogleFonts.inter(
            color: const Color(0xFFEF4444),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _vigilancePanel({required bool embeddedScroll}) {
    final wide = embeddedScroll;
    Widget vigilanceTile(int index) {
      final guard = _vigilance[index];
      final statusColor = guard.decayLevel <= 75
          ? const Color(0xFF10B981)
          : guard.decayLevel <= 90
          ? const Color(0xFFF59E0B)
          : const Color(0xFFEF4444);
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: const Color(0x14000000),
          border: Border.all(color: const Color(0xFF2A3C57)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guard.callsign,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFE7F2FF),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Last check-in: ${guard.lastCheckIn}',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF8FA7C8),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 64,
              height: 20,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: guard.sparkline
                    .map((value) {
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          height: (value.clamp(10, 100) / 100) * 18,
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${guard.decayLevel}%',
              style: GoogleFonts.inter(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    return wide
        ? ListView.separated(
            itemCount: _vigilance.length,
            separatorBuilder: (context, index) => const SizedBox(height: 6),
            itemBuilder: (context, index) => vigilanceTile(index),
          )
        : Column(
            children: [
              for (var i = 0; i < _vigilance.length; i++) ...[
                vigilanceTile(i),
                if (i < _vigilance.length - 1) const SizedBox(height: 6),
              ],
            ],
          );
  }

  Widget _ledgerPanel(List<_LedgerEntry> ledger, {bool embeddedScroll = true}) {
    final visibleEntries = ledger.take(embeddedScroll ? 4 : 3).toList();
    final rows = List<Widget>.generate(visibleEntries.length, (index) {
      final entry = visibleEntries[index];
      final style = _ledgerStyle(entry.type);
      final hh = entry.timestamp.toLocal().hour.toString().padLeft(2, '0');
      final mm = entry.timestamp.toLocal().minute.toString().padLeft(2, '0');
      final ss = entry.timestamp.toLocal().second.toString().padLeft(2, '0');
      return Tooltip(
        message: entry.hash,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: const Color(0x14000000),
            border: Border.all(color: const Color(0xFF2A3D58)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  color: style.color.withValues(alpha: 0.16),
                ),
                child: Icon(style.icon, size: 14, color: style.color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _ledgerTypeLabel(entry.type),
                          style: GoogleFonts.inter(
                            color: style.color,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$hh:$mm:$ss',
                          style: GoogleFonts.robotoMono(
                            color: const Color(0xFF8EA8CB),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      entry.description,
                      style: GoogleFonts.inter(
                        color: const Color(0xFFE0EBFF),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if ((entry.actor ?? '').isNotEmpty)
                          Text(
                            'Actor: ${entry.actor}',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF9AB2D2),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if ((entry.reasonCode ?? '').isNotEmpty) ...[
                          if ((entry.actor ?? '').isNotEmpty)
                            const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: style.color.withValues(alpha: 0.14),
                              border: Border.all(
                                color: style.color.withValues(alpha: 0.45),
                              ),
                            ),
                            child: Text(
                              entry.reasonCode!,
                              style: GoogleFonts.robotoMono(
                                color: style.color,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
    return Container(
      key: const ValueKey('live-operations-ledger-preview'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF21262D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF6D28D9).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.36),
                  ),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  size: 18,
                  color: Color(0xFFA78BFA),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SOVEREIGN LEDGER',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFF8FBFF),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Immutable event chain',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8FAFD4),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFF10151C),
                border: Border.all(color: const Color(0xFF223244)),
              ),
              child: Text(
                'No ledger events recorded yet for the current command window.',
                style: GoogleFonts.inter(
                  color: const Color(0xFF9AB2D2),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Column(
              children: [
                for (int i = 0; i < rows.length; i++) ...[
                  rows[i],
                  if (i < rows.length - 1) const SizedBox(height: 8),
                ],
              ],
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${ledger.length} events recorded',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9AB2D2),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ledger chain verification passed'),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFA78BFA),
                  side: const BorderSide(color: Color(0x665B3FD1)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                ),
                child: Text(
                  'Verify Chain',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _contextTabs() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 480;
        if (compact) {
          return Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _ContextTab.values
                .map((tab) {
                  final selected = tab == _activeTab;
                  return _contextTabButton(tab, selected, compact: true);
                })
                .toList(growable: false),
          );
        }
        return Row(
          children: _ContextTab.values
              .map((tab) {
                final selected = tab == _activeTab;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _contextTabButton(tab, selected, compact: false),
                  ),
                );
              })
              .toList(growable: false),
        );
      },
    );
  }

  Widget _contextTabButton(
    _ContextTab tab,
    bool selected, {
    required bool compact,
  }) {
    return OutlinedButton(
      onPressed: () {
        setState(() {
          _activeTab = tab;
        });
      },
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: selected ? const Color(0x6622D3EE) : const Color(0x33FFFFFF),
        ),
        backgroundColor: selected
            ? const Color(0x3322D3EE)
            : const Color(0x14FFFFFF),
        foregroundColor: selected
            ? const Color(0xFF22D3EE)
            : const Color(0xFFB8CAE4),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 0,
          vertical: 10,
        ),
        textStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800),
      ),
      child: Text(_tabLabel(tab)),
    );
  }

  Widget _panel({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boundedHeight =
            constraints.hasBoundedHeight && constraints.maxHeight.isFinite;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFF0E1A2B),
            border: Border.all(color: const Color(0xFF223244)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: GoogleFonts.inter(
                  color: const Color(0xFF6C87AD),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  color: const Color(0xFF8EA5C5),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (boundedHeight) Expanded(child: child) else child,
            ],
          ),
        );
      },
    );
  }

  Widget _chip({
    required String label,
    required Color foreground,
    required Color background,
    required Color border,
    IconData? leadingIcon,
    String? tooltipMessage,
    VoidCallback? onTap,
    Key? key,
  }) {
    Widget child = Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: background,
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingIcon != null) ...[
            Icon(leadingIcon, size: 13, color: foreground),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
    if ((tooltipMessage ?? '').trim().isNotEmpty) {
      child = Tooltip(message: tooltipMessage!.trim(), child: child);
    }
    if (onTap == null) {
      return child;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: child,
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(0xFF8FA7C8),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                color: const Color(0xFFE4EEFF),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contextChip({
    required String label,
    required Color foreground,
    required Color background,
    required Color border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: background,
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _muted(String message) {
    return Center(
      child: Text(
        message,
        style: GoogleFonts.inter(
          color: const Color(0xFF7F95B6),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _approveControlInboxDraft(LiveControlInboxDraft draft) async {
    if (widget.onApproveClientReplyDraft == null ||
        _controlInboxBusyDraftIds.contains(draft.updateId)) {
      return;
    }
    setState(() {
      _controlInboxBusyDraftIds = {
        ..._controlInboxBusyDraftIds,
        draft.updateId,
      };
    });
    try {
      final message = await widget.onApproveClientReplyDraft!.call(
        draft.updateId,
        approvedText: draft.draftText,
      );
      _showLiveOpsSnack(message.trim().isEmpty ? 'Draft approved.' : message);
    } catch (_) {
      _showLiveOpsSnack('Failed to approve AI draft ${draft.updateId}.');
    } finally {
      if (mounted) {
        setState(() {
          _controlInboxBusyDraftIds = _controlInboxBusyDraftIds
              .where((entry) => entry != draft.updateId)
              .toSet();
        });
      }
    }
  }

  Future<void> _editControlInboxDraft(LiveControlInboxDraft draft) async {
    if (widget.onUpdateClientReplyDraftText == null ||
        _controlInboxDraftEditBusyIds.contains(draft.updateId)) {
      return;
    }
    final controller = TextEditingController(text: draft.draftText);
    final nextText = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0E1620),
          title: Text(
            'Refine ONYX Draft',
            style: GoogleFonts.inter(
              color: const Color(0xFFEAF4FF),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, child) {
                    return Text(
                      _controlInboxDraftCueForSignals(
                        sourceText: draft.sourceText,
                        replyText: value.text,
                        clientVoiceProfileLabel: draft.clientVoiceProfileLabel,
                        usesLearnedApprovalStyle:
                            draft.usesLearnedApprovalStyle,
                      ),
                      style: GoogleFonts.inter(
                        color: const Color(0xFFB7CAE3),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.32,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: controller,
                  minLines: 5,
                  maxLines: 9,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEAF4FF),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Shape the final client-facing wording here.',
                    hintStyle: GoogleFonts.inter(
                      color: const Color(0xFF8EA4C2),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF111D2A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF35506F)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF35506F)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF4B6B8F)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: const Color(0xFF9AB1CF),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D5B),
                foregroundColor: const Color(0xFFEAF4FF),
              ),
              child: Text(
                'Save Draft',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
    final normalizedText = (nextText ?? '').trim();
    if (normalizedText.isEmpty || normalizedText == draft.draftText.trim()) {
      return;
    }
    setState(() {
      _controlInboxDraftEditBusyIds = {
        ..._controlInboxDraftEditBusyIds,
        draft.updateId,
      };
    });
    try {
      await widget.onUpdateClientReplyDraftText!.call(
        draft.updateId,
        normalizedText,
      );
      _showLiveOpsSnack('Draft wording updated for approval.');
    } catch (_) {
      _showLiveOpsSnack('Failed to update AI draft ${draft.updateId}.');
    } finally {
      if (mounted) {
        setState(() {
          _controlInboxDraftEditBusyIds = _controlInboxDraftEditBusyIds
              .where((entry) => entry != draft.updateId)
              .toSet();
        });
      }
    }
  }

  Future<void> _rejectControlInboxDraft(LiveControlInboxDraft draft) async {
    if (widget.onRejectClientReplyDraft == null ||
        _controlInboxBusyDraftIds.contains(draft.updateId)) {
      return;
    }
    setState(() {
      _controlInboxBusyDraftIds = {
        ..._controlInboxBusyDraftIds,
        draft.updateId,
      };
    });
    try {
      final message = await widget.onRejectClientReplyDraft!.call(
        draft.updateId,
      );
      _showLiveOpsSnack(message.trim().isEmpty ? 'Draft rejected.' : message);
    } catch (_) {
      _showLiveOpsSnack('Failed to reject AI draft ${draft.updateId}.');
    } finally {
      if (mounted) {
        setState(() {
          _controlInboxBusyDraftIds = _controlInboxBusyDraftIds
              .where((entry) => entry != draft.updateId)
              .toSet();
        });
      }
    }
  }

  void _showLiveOpsSnack(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _openOverrideDialog(_IncidentRecord incident) {
    String? selectedReason;
    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0E1A2B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0x66EF4444)),
              ),
              title: Text(
                'Override ${incident.id}',
                style: GoogleFonts.inter(
                  color: const Color(0xFFFFC0C6),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select a reason code (required):',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF9AB2D2),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._overrideReasonCodes.map((code) {
                      final selected = selectedReason == code;
                      return InkWell(
                        key: Key('reason-$code'),
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          setDialogState(() {
                            selectedReason = code;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 4,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                size: 16,
                                color: selected
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF9AB2D2),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  code,
                                  style: GoogleFonts.robotoMono(
                                    color: const Color(0xFFE8F2FF),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  key: const Key('override-submit-button'),
                  onPressed: selectedReason == null
                      ? null
                      : () {
                          _applyOverride(incident, selectedReason!);
                          Navigator.of(context).pop();
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                  ),
                  child: const Text('Submit Override'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _applyOverride(_IncidentRecord incident, String reasonCode) {
    setState(() {
      _statusOverrides[incident.id] = _IncidentStatus.resolved;
      _manualLedger.add(
        _LedgerEntry(
          id: 'OVR-${DateTime.now().microsecondsSinceEpoch}',
          timestamp: DateTime.now(),
          type: _LedgerType.humanOverride,
          description: 'Override submitted for ${incident.id}',
          hash: _hashFor('override-$reasonCode-${incident.id}'),
          verified: true,
          reasonCode: reasonCode,
        ),
      );
      _projectFromEvents();
    });
    logUiAction(
      'live_operations.manual_override',
      context: {'incident_id': incident.id, 'reason_code': reasonCode},
    );
  }

  void _forceDispatch(_IncidentRecord incident) {
    setState(() {
      _statusOverrides[incident.id] = _IncidentStatus.dispatched;
      _manualLedger.add(
        _LedgerEntry(
          id: 'ESC-${DateTime.now().microsecondsSinceEpoch}',
          timestamp: DateTime.now(),
          type: _LedgerType.escalation,
          description: 'Forced dispatch activated for ${incident.id}',
          hash: _hashFor('forced-dispatch-${incident.id}'),
          verified: true,
        ),
      );
      _projectFromEvents();
    });
    logUiAction(
      'live_operations.force_dispatch',
      context: {'incident_id': incident.id},
    );
  }

  void _pauseAutomation(_IncidentRecord incident) {
    setState(() {
      _manualLedger.add(
        _LedgerEntry(
          id: 'PAUSE-${DateTime.now().microsecondsSinceEpoch}',
          timestamp: DateTime.now(),
          type: _LedgerType.systemEvent,
          description: 'Automation paused for ${incident.id}',
          hash: _hashFor('pause-${incident.id}'),
          verified: true,
        ),
      );
    });
    logUiAction(
      'live_operations.pause_automation',
      context: {'incident_id': incident.id},
    );
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text('Automation paused for ${incident.id}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  _IncidentRecord? get _activeIncident {
    if (_incidents.isEmpty) return null;
    return _incidents.firstWhere(
      (incident) => incident.id == _activeIncidentId,
      orElse: () => _incidents.first,
    );
  }

  void _projectFromEvents() {
    final scopeClientId = (widget.initialScopeClientId ?? '').trim();
    final scopeSiteId = (widget.initialScopeSiteId ?? '').trim();
    final hasScopeFocus = scopeClientId.isNotEmpty;
    final scopedEvents = hasScopeFocus
        ? widget.events
              .where((event) {
                final clientId = switch (event) {
                  DecisionCreated value => value.clientId.trim(),
                  ResponseArrived value => value.clientId.trim(),
                  PartnerDispatchStatusDeclared value => value.clientId.trim(),
                  GuardCheckedIn value => value.clientId.trim(),
                  ExecutionCompleted value => value.clientId.trim(),
                  IntelligenceReceived value => value.clientId.trim(),
                  PatrolCompleted value => value.clientId.trim(),
                  IncidentClosed value => value.clientId.trim(),
                  _ => '',
                };
                final siteId = switch (event) {
                  DecisionCreated value => value.siteId.trim(),
                  ResponseArrived value => value.siteId.trim(),
                  PartnerDispatchStatusDeclared value => value.siteId.trim(),
                  GuardCheckedIn value => value.siteId.trim(),
                  ExecutionCompleted value => value.siteId.trim(),
                  IntelligenceReceived value => value.siteId.trim(),
                  PatrolCompleted value => value.siteId.trim(),
                  IncidentClosed value => value.siteId.trim(),
                  _ => '',
                };
                if (clientId != scopeClientId) {
                  return false;
                }
                if (scopeSiteId.isEmpty) {
                  return true;
                }
                return siteId == scopeSiteId;
              })
              .toList(growable: false)
        : widget.events;
    final focusReference = _canonicalFocusReference(
      widget.focusIncidentReference,
      scopedEvents,
    );
    final normalizedInputFocus = widget.focusIncidentReference.trim();
    final liveProjectedIncidents = _deriveIncidents(
      scopedEvents,
      allowDemoFallback: !hasScopeFocus,
    );
    final focusMatchedInLiveStream =
        focusReference.isNotEmpty &&
        liveProjectedIncidents.any((incident) => incident.id == focusReference);
    final projectedIncidents = _injectFocusedIncidentFallback(
      incidents: liveProjectedIncidents,
      focusReference: focusReference,
      hasLiveMatch: focusMatchedInLiveStream,
    );
    final projectedLedger = _deriveLedger(scopedEvents);
    final projectedVigilance = _deriveVigilance(scopedEvents);
    setState(() {
      _incidents = projectedIncidents;
      _projectedLedger = projectedLedger;
      _vigilance = projectedVigilance;
      _resolvedFocusReference = focusReference;
      _focusLinkState = switch ((focusReference.isNotEmpty, focusMatchedInLiveStream)) {
        (false, _) => _FocusLinkState.none,
        (true, false) => _FocusLinkState.seeded,
        (true, true) when normalizedInputFocus == focusReference =>
          _FocusLinkState.exact,
        (true, true) => _FocusLinkState.scopeBacked,
      };
      if (_incidents.isEmpty) {
        _activeIncidentId = null;
      } else if (focusReference.isNotEmpty &&
          _incidents.any((incident) => incident.id == focusReference)) {
        _activeIncidentId = focusReference;
      } else if (!_incidents.any(
        (incident) => incident.id == _activeIncidentId,
      )) {
        _activeIncidentId = _incidents.first.id;
      }
    });
  }

  String _canonicalFocusReference(
    String rawFocusReference,
    List<DispatchEvent> events,
  ) {
    final normalizedReference = rawFocusReference.trim();
    if (normalizedReference.isEmpty) {
      return '';
    }

    DecisionCreated? decisionMatch;
    IntelligenceReceived? intelligenceMatch;
    for (final event in events) {
      final dispatchId = switch (event) {
        DecisionCreated value => value.dispatchId.trim(),
        ResponseArrived value => value.dispatchId.trim(),
        PartnerDispatchStatusDeclared value => value.dispatchId.trim(),
        ExecutionCompleted value => value.dispatchId.trim(),
        ExecutionDenied value => value.dispatchId.trim(),
        IncidentClosed value => value.dispatchId.trim(),
        _ => '',
      };
      final eventMatches = event.eventId.trim() == normalizedReference;
      final dispatchMatches =
          dispatchId.isNotEmpty &&
          (dispatchId == normalizedReference ||
              _incidentIdForDispatch(dispatchId) == normalizedReference);
      if (eventMatches || dispatchMatches) {
        final decision = events
            .whereType<DecisionCreated>()
            .where((candidate) => candidate.dispatchId.trim() == dispatchId)
            .fold<DecisionCreated?>(
              null,
              (latest, candidate) =>
                  latest == null ||
                      candidate.occurredAt.isAfter(latest.occurredAt)
                  ? candidate
                  : latest,
            );
        if (decision != null &&
            (decisionMatch == null ||
                decision.occurredAt.isAfter(decisionMatch.occurredAt))) {
          decisionMatch = decision;
        }
      }
      if (event is IntelligenceReceived &&
          (event.eventId.trim() == normalizedReference ||
              event.intelligenceId.trim() == normalizedReference) &&
          (intelligenceMatch == null ||
              event.occurredAt.isAfter(intelligenceMatch.occurredAt))) {
        intelligenceMatch = event;
      }
    }

    if (decisionMatch != null) {
      return _incidentIdForDispatch(decisionMatch.dispatchId.trim());
    }

    if (intelligenceMatch != null) {
      final decision = events
          .whereType<DecisionCreated>()
          .where(
            (candidate) =>
                candidate.clientId.trim() ==
                    intelligenceMatch!.clientId.trim() &&
                candidate.siteId.trim() == intelligenceMatch.siteId.trim(),
          )
          .fold<DecisionCreated?>(
            null,
            (latest, candidate) =>
                latest == null ||
                    candidate.occurredAt.isAfter(latest.occurredAt)
                ? candidate
                : latest,
          );
      if (decision != null) {
        return _incidentIdForDispatch(decision.dispatchId.trim());
      }
    }

    return normalizedReference;
  }

  String _focusStateLabel(_FocusLinkState state) {
    return switch (state) {
      _FocusLinkState.none => 'Idle',
      _FocusLinkState.exact => 'Linked',
      _FocusLinkState.scopeBacked => 'Scope-backed',
      _FocusLinkState.seeded => 'Seeded',
    };
  }

  Color _focusStateForeground(_FocusLinkState state) {
    return switch (state) {
      _FocusLinkState.none => const Color(0xFF9AB1CF),
      _FocusLinkState.exact => const Color(0xFF34D399),
      _FocusLinkState.scopeBacked => const Color(0xFF8FD1FF),
      _FocusLinkState.seeded => const Color(0xFFF59E0B),
    };
  }

  Color _focusStateBackground(_FocusLinkState state) {
    return switch (state) {
      _FocusLinkState.none => const Color(0x1A9AB1CF),
      _FocusLinkState.exact => const Color(0x3334D399),
      _FocusLinkState.scopeBacked => const Color(0x338FD1FF),
      _FocusLinkState.seeded => const Color(0x33F59E0B),
    };
  }

  Color _focusStateBorder(_FocusLinkState state) {
    return switch (state) {
      _FocusLinkState.none => const Color(0x669AB1CF),
      _FocusLinkState.exact => const Color(0x6634D399),
      _FocusLinkState.scopeBacked => const Color(0x668FD1FF),
      _FocusLinkState.seeded => const Color(0x66F59E0B),
    };
  }

  String _incidentIdForDispatch(String dispatchId) {
    final normalizedDispatchId = dispatchId.trim();
    if (normalizedDispatchId.isEmpty) {
      return '';
    }
    return normalizedDispatchId.startsWith('INC-')
        ? normalizedDispatchId
        : 'INC-$normalizedDispatchId';
  }

  List<_IncidentRecord> _injectFocusedIncidentFallback({
    required List<_IncidentRecord> incidents,
    required String focusReference,
    required bool hasLiveMatch,
  }) {
    if (focusReference.isEmpty || hasLiveMatch) {
      return incidents;
    }
    return [
      _IncidentRecord(
        id: focusReference,
        clientId: '',
        regionId: '',
        siteId: '',
        priority: _IncidentPriority.p2High,
        type: 'Focused lane playback',
        site: 'Focused Operations Lane',
        timestamp: _hhmm(DateTime.now().toLocal()),
        status: _statusOverrides[focusReference] ?? _IncidentStatus.dispatched,
      ),
      ...incidents,
    ];
  }

  List<_IncidentRecord> _deriveIncidents(
    List<DispatchEvent> events, {
    required bool allowDemoFallback,
  }) {
    final decisions = events.whereType<DecisionCreated>().toList(
      growable: false,
    )..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    if (decisions.isEmpty) {
      if (!allowDemoFallback) {
        return const <_IncidentRecord>[];
      }
      final fallbackIncidents = _fallbackIncidents();
      return fallbackIncidents
          .map(
            (incident) => incident.copyWith(
              status: _statusOverrides[incident.id] ?? incident.status,
            ),
          )
          .toList(growable: false);
    }
    final closedIds = {
      ...events.whereType<IncidentClosed>().map((event) => event.dispatchId),
      ...events
          .whereType<PartnerDispatchStatusDeclared>()
          .where(
            (event) =>
                event.status == PartnerDispatchStatus.allClear ||
                event.status == PartnerDispatchStatus.cancelled,
          )
          .map((event) => event.dispatchId),
    };
    final arrivedIds = {
      ...events.whereType<ResponseArrived>().map((event) => event.dispatchId),
      ...events
          .whereType<PartnerDispatchStatusDeclared>()
          .where((event) => event.status == PartnerDispatchStatus.onSite)
          .map((event) => event.dispatchId),
    };
    final executedIds = {
      ...events.whereType<ExecutionCompleted>().map(
        (event) => event.dispatchId,
      ),
      ...events
          .whereType<PartnerDispatchStatusDeclared>()
          .where((event) => event.status == PartnerDispatchStatus.accepted)
          .map((event) => event.dispatchId),
    };
    final riskBySite = <String, int>{};
    final latestHardwareIntelBySite = <String, IntelligenceReceived>{};
    for (final intel in events.whereType<IntelligenceReceived>()) {
      final existing = riskBySite[intel.siteId] ?? 0;
      if (intel.riskScore > existing) {
        riskBySite[intel.siteId] = intel.riskScore;
      }
      if (intel.sourceType != 'hardware' && intel.sourceType != 'dvr') {
        continue;
      }
      final current = latestHardwareIntelBySite[intel.siteId];
      if (current == null || intel.occurredAt.isAfter(current.occurredAt)) {
        latestHardwareIntelBySite[intel.siteId] = intel;
      }
    }
    final incidents =
        decisions
            .take(12)
            .map((decision) {
              final baseStatus = closedIds.contains(decision.dispatchId)
                  ? _IncidentStatus.resolved
                  : arrivedIds.contains(decision.dispatchId)
                  ? _IncidentStatus.investigating
                  : executedIds.contains(decision.dispatchId)
                  ? _IncidentStatus.dispatched
                  : _IncidentStatus.triaging;
              final normalizedId = decision.dispatchId.startsWith('INC-')
                  ? decision.dispatchId
                  : 'INC-${decision.dispatchId}';
              final risk = riskBySite[decision.siteId] ?? 55;
              final latestIntel = latestHardwareIntelBySite[decision.siteId];
              final latestSceneReview = latestIntel == null
                  ? null
                  : widget.sceneReviewByIntelligenceId[latestIntel
                        .intelligenceId
                        .trim()];
              final priority = _incidentPriorityFor(
                risk,
                latestSceneReview: latestSceneReview,
              );
              final status = _statusOverrides[normalizedId] ?? baseStatus;
              return _IncidentRecord(
                id: normalizedId,
                clientId: decision.clientId,
                regionId: decision.regionId,
                siteId: decision.siteId,
                priority: priority,
                type: _incidentTypeFor(
                  risk,
                  latestSceneReview: latestSceneReview,
                ),
                site: decision.siteId,
                timestamp: _hhmm(decision.occurredAt.toLocal()),
                status: status,
                latestIntelHeadline: latestIntel?.headline,
                latestIntelSummary: latestIntel?.summary,
                latestSceneReviewLabel: latestSceneReview == null
                    ? null
                    : '${latestSceneReview.sourceLabel} • ${latestSceneReview.postureLabel}',
                latestSceneReviewSummary: latestSceneReview?.summary,
                latestSceneDecisionLabel: latestSceneReview?.decisionLabel,
                latestSceneDecisionSummary: latestSceneReview?.decisionSummary,
                snapshotUrl: latestIntel?.snapshotUrl,
                clipUrl: latestIntel?.clipUrl,
              );
            })
            .toList(growable: false)
          ..sort((a, b) {
            final byPriority = _priorityRank(
              a.priority,
            ).compareTo(_priorityRank(b.priority));
            if (byPriority != 0) return byPriority;
            return b.timestamp.compareTo(a.timestamp);
          });
    return incidents;
  }

  List<_IncidentRecord> _fallbackIncidents() {
    return const [
      _IncidentRecord(
        id: 'INC-8829-QX',
        clientId: '',
        regionId: '',
        siteId: '',
        priority: _IncidentPriority.p1Critical,
        type: 'Perimeter breach',
        site: 'North Residential Cluster',
        timestamp: '22:14',
        status: _IncidentStatus.investigating,
      ),
      _IncidentRecord(
        id: 'INC-8830-RZ',
        clientId: '',
        regionId: '',
        siteId: '',
        priority: _IncidentPriority.p1Critical,
        type: 'Priority response',
        site: 'Central Access Gate',
        timestamp: '22:08',
        status: _IncidentStatus.dispatched,
      ),
      _IncidentRecord(
        id: 'INC-8827-PX',
        clientId: '',
        regionId: '',
        siteId: '',
        priority: _IncidentPriority.p2High,
        type: 'Perimeter alarm',
        site: 'East Patrol Sector',
        timestamp: '21:56',
        status: _IncidentStatus.triaging,
      ),
      _IncidentRecord(
        id: 'INC-8828-MN',
        clientId: '',
        regionId: '',
        siteId: '',
        priority: _IncidentPriority.p2High,
        type: 'Access control failure',
        site: 'Midrand Operations Park',
        timestamp: '21:45',
        status: _IncidentStatus.investigating,
      ),
      _IncidentRecord(
        id: 'INC-8826-KL',
        clientId: '',
        regionId: '',
        siteId: '',
        priority: _IncidentPriority.p3Medium,
        type: 'Power instability',
        site: 'Centurion Retail Annex',
        timestamp: '21:42',
        status: _IncidentStatus.resolved,
      ),
    ];
  }

  Widget _scopeFocusBanner({required String clientId, required String siteId}) {
    final scopeLabel = siteId.trim().isEmpty
        ? '$clientId/all sites'
        : '$clientId/$siteId';
    return Container(
      key: const ValueKey('live-operations-scope-banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0x141C3C57),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x4435506F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Scope focus active',
            style: GoogleFonts.inter(
              color: const Color(0xFF8FD1FF),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            scopeLabel,
            style: GoogleFonts.inter(
              color: const Color(0xFFEAF1FB),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  List<_LadderStep> _ladderStepsFor(_IncidentRecord? incident) {
    if (incident == null) return const [];
    final duress = _duressDetected(incident);
    final videoActivationStep = '${widget.videoOpsLabel} ACTIVATION';
    final dispatchStep = _dispatchStepLabel(incident);
    final clientCallStep = _clientCallStepLabel(incident);
    final verifyStep = _verifyStepLabel(incident);
    final dispatchActiveDetails = _dispatchActiveDetails(incident);
    final dispatchActiveMetadata = _dispatchActiveMetadata(incident);
    final clientCallActiveDetails = _clientCallActiveDetails(incident);
    final videoActiveDetails = _videoActiveDetails(incident);
    final videoActiveMetadata = _videoActiveMetadata(incident);
    final verifyThinkingMessage = _verifyThinkingMessage(incident);
    if (incident.status == _IncidentStatus.resolved) {
      return [
        _LadderStep(
          id: 's1',
          name: 'SIGNAL TRIAGE',
          status: _LadderStepStatus.completed,
        ),
        _LadderStep(
          id: 's2',
          name: dispatchStep,
          status: _LadderStepStatus.completed,
        ),
        _LadderStep(
          id: 's3',
          name: clientCallStep,
          status: _LadderStepStatus.completed,
        ),
        _LadderStep(
          id: 's4',
          name: videoActivationStep,
          status: _LadderStepStatus.completed,
        ),
        _LadderStep(
          id: 's5',
          name: verifyStep,
          status: _LadderStepStatus.completed,
        ),
      ];
    }
    if (incident.status == _IncidentStatus.investigating) {
      return [
        _LadderStep(
          id: 's1',
          name: 'SIGNAL TRIAGE',
          status: _LadderStepStatus.completed,
        ),
        _LadderStep(
          id: 's2',
          name: dispatchStep,
          status: _LadderStepStatus.completed,
        ),
        _LadderStep(
          id: 's3',
          name: clientCallStep,
          status: _LadderStepStatus.completed,
          details: clientCallActiveDetails,
        ),
        _LadderStep(
          id: 's4',
          name: videoActivationStep,
          status: _LadderStepStatus.active,
          details: videoActiveDetails,
          timestamp: '22:14:18',
          metadata: videoActiveMetadata,
        ),
        _LadderStep(
          id: 's5',
          name: verifyStep,
          status: _LadderStepStatus.thinking,
          thinkingMessage: verifyThinkingMessage,
        ),
      ];
    }
    if (incident.status == _IncidentStatus.dispatched) {
      return [
        _LadderStep(
          id: 's1',
          name: 'SIGNAL TRIAGE',
          status: _LadderStepStatus.completed,
        ),
        _LadderStep(
          id: 's2',
          name: dispatchStep,
          status: _LadderStepStatus.completed,
          details: dispatchActiveDetails,
          timestamp: '22:14:06',
          metadata: dispatchActiveMetadata,
        ),
        _LadderStep(
          id: 's3',
          name: clientCallStep,
          status: _LadderStepStatus.active,
          details: clientCallActiveDetails,
        ),
        _LadderStep(
          id: 's4',
          name: videoActivationStep,
          status: _LadderStepStatus.pending,
        ),
        _LadderStep(
          id: 's5',
          name: verifyStep,
          status: _LadderStepStatus.pending,
        ),
      ];
    }
    return [
      const _LadderStep(
        id: 's1',
        name: 'SIGNAL TRIAGE',
        status: _LadderStepStatus.completed,
      ),
      _LadderStep(
        id: 's2',
        name: dispatchStep,
        status: _LadderStepStatus.active,
        details: dispatchActiveDetails,
        timestamp: '22:14:06',
        metadata: dispatchActiveMetadata,
      ),
      _LadderStep(
        id: 's3',
        name: clientCallStep,
        status: duress ? _LadderStepStatus.blocked : _LadderStepStatus.thinking,
        thinkingMessage: duress
            ? 'Silent duress suspected • waiting for forced dispatch.'
            : _clientCallThinkingMessage(incident),
      ),
      _LadderStep(
        id: 's4',
        name: videoActivationStep,
        status: _LadderStepStatus.pending,
      ),
      _LadderStep(
        id: 's5',
        name: verifyStep,
        status: _LadderStepStatus.pending,
      ),
    ];
  }

  String _dispatchStepLabel(_IncidentRecord incident) {
    if (_isFireIncident(incident)) {
      return 'FIRE RESPONSE';
    }
    if (_isLeakIncident(incident)) {
      return 'LEAK CONTAINMENT';
    }
    if (_isHazardIncident(incident)) {
      return 'HAZARD RESPONSE';
    }
    return 'AUTO-DISPATCH';
  }

  String _clientCallStepLabel(_IncidentRecord incident) {
    if (_isHazardIncident(incident)) {
      return 'CLIENT SAFETY CALL';
    }
    return 'VOIP CLIENT CALL';
  }

  String _verifyStepLabel(_IncidentRecord incident) {
    if (_isFireIncident(incident)) {
      return 'FIRE VERIFY';
    }
    if (_isLeakIncident(incident)) {
      return 'LEAK VERIFY';
    }
    if (_isHazardIncident(incident)) {
      return 'HAZARD VERIFY';
    }
    return 'VISION VERIFY';
  }

  String _dispatchActiveDetails(_IncidentRecord incident) {
    final directives = _hazardDirectivesForIncident(incident);
    if (directives.hasHazard) {
      return directives.operatorDispatchActiveDetails;
    }
    return 'Officer Echo-3 • 2.4km • ETA 4m 12s';
  }

  String _dispatchActiveMetadata(_IncidentRecord incident) {
    final directives = _hazardDirectivesForIncident(incident);
    if (directives.hasHazard) {
      return directives.operatorDispatchActiveMetadata;
    }
    return 'Nearest armed response selected';
  }

  String _clientCallActiveDetails(_IncidentRecord incident) {
    final directives = _hazardDirectivesForIncident(incident);
    if (directives.hasHazard) {
      return directives.operatorClientCallActiveDetails;
    }
    return 'Safe-word verification call in progress.';
  }

  String _clientCallThinkingMessage(_IncidentRecord incident) {
    final directives = _hazardDirectivesForIncident(incident);
    if (directives.hasHazard) {
      return directives.operatorClientCallThinkingMessage;
    }
    return 'Waiting for VoIP completion...';
  }

  HazardResponseDirectives _hazardDirectivesForIncident(
    _IncidentRecord incident,
  ) {
    return _hazardDirectiveService.build(
      postureLabel: incident.latestSceneReviewLabel ?? incident.type,
      siteName: incident.site,
    );
  }

  String _videoActiveDetails(_IncidentRecord incident) {
    if (_isFireIncident(incident)) {
      return 'Live thermal and smoke evidence stream active.';
    }
    if (_isLeakIncident(incident)) {
      return 'Live pooling and spread evidence stream active.';
    }
    if (_isHazardIncident(incident)) {
      return 'Live hazard verification stream active.';
    }
    return 'Live perimeter stream active.';
  }

  String _videoActiveMetadata(_IncidentRecord incident) {
    if (_isFireIncident(incident)) {
      return 'Generator room cluster · confidence 98%';
    }
    if (_isLeakIncident(incident)) {
      return 'Stock room cluster · confidence 96%';
    }
    if (_isHazardIncident(incident)) {
      return 'Safety zone cluster · confidence 94%';
    }
    return 'Camera cluster N4 · confidence 98%';
  }

  String _verifyThinkingMessage(_IncidentRecord incident) {
    if (_isFireIncident(incident)) {
      return 'Checking for flame growth, smoke density, and spread pattern...';
    }
    if (_isLeakIncident(incident)) {
      return 'Checking for pooling spread, pipe-burst pattern, and ongoing water loss...';
    }
    if (_isHazardIncident(incident)) {
      return 'Checking for worsening hazard indicators against baseline...';
    }
    return 'Comparing live capture against norm baseline...';
  }

  bool _isFireIncident(_IncidentRecord incident) {
    final text = _incidentHazardText(incident);
    return text.contains('fire') || text.contains('smoke');
  }

  bool _isLeakIncident(_IncidentRecord incident) {
    final text = _incidentHazardText(incident);
    return text.contains('flood') || text.contains('leak');
  }

  bool _isHazardIncident(_IncidentRecord incident) {
    if (_isFireIncident(incident) || _isLeakIncident(incident)) {
      return true;
    }
    return _incidentHazardText(incident).contains('hazard');
  }

  String _incidentHazardText(_IncidentRecord incident) {
    return [
      incident.type,
      incident.latestSceneReviewLabel,
      incident.latestSceneReviewSummary,
      incident.latestSceneDecisionLabel,
      incident.latestSceneDecisionSummary,
      incident.latestIntelHeadline,
      incident.latestIntelSummary,
    ].join(' ').toLowerCase();
  }

  List<_LedgerEntry> _deriveLedger(List<DispatchEvent> events) {
    final entries = <_LedgerEntry>[];
    for (final event in events.take(40)) {
      final entry = switch (event) {
        DecisionCreated() => _LedgerEntry(
          id: event.eventId,
          timestamp: event.occurredAt,
          type: _LedgerType.aiAction,
          description: 'Dispatch decision created for ${event.dispatchId}',
          actor: 'ONYX AI',
          hash: _hashFor(event.eventId),
          verified: true,
        ),
        ExecutionCompleted() => _LedgerEntry(
          id: event.eventId,
          timestamp: event.occurredAt,
          type: _LedgerType.systemEvent,
          description: 'Execution completed for ${event.dispatchId}',
          hash: _hashFor(event.eventId),
          verified: true,
        ),
        ExecutionDenied() => _LedgerEntry(
          id: event.eventId,
          timestamp: event.occurredAt,
          type: _LedgerType.humanOverride,
          description: 'Execution denied for ${event.dispatchId}',
          actor: 'Admin-1',
          hash: _hashFor(event.eventId),
          verified: true,
        ),
        ResponseArrived() => _LedgerEntry(
          id: event.eventId,
          timestamp: event.occurredAt,
          type: _LedgerType.systemEvent,
          description: 'Response arrived for ${event.dispatchId}',
          hash: _hashFor(event.eventId),
          verified: true,
        ),
        PartnerDispatchStatusDeclared() => _LedgerEntry(
          id: event.eventId,
          timestamp: event.occurredAt,
          type: _LedgerType.systemEvent,
          description:
              '${event.partnerLabel} declared ${event.status.name} for ${event.dispatchId}',
          actor: event.actorLabel,
          hash: _hashFor(event.eventId),
          verified: false,
        ),
        IncidentClosed() => _LedgerEntry(
          id: event.eventId,
          timestamp: event.occurredAt,
          type: _LedgerType.systemEvent,
          description: 'Incident closed for ${event.dispatchId}',
          hash: _hashFor(event.eventId),
          verified: true,
        ),
        IntelligenceReceived() => _LedgerEntry(
          id: event.eventId,
          timestamp: event.occurredAt,
          type: _LedgerType.escalation,
          description: 'Intelligence received at ${event.siteId}',
          hash: _hashFor(event.eventId),
          verified: true,
        ),
        _ => _LedgerEntry(
          id: event.eventId,
          timestamp: event.occurredAt,
          type: _LedgerType.systemEvent,
          description: 'System event ${event.eventId}',
          hash: _hashFor(event.eventId),
          verified: true,
        ),
      };
      entries.add(entry);
    }
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (entries.isEmpty) {
      return [
        _LedgerEntry(
          id: 'L001',
          timestamp: DateTime(2026, 3, 10, 22, 14, 27),
          type: _LedgerType.aiAction,
          description: 'VoIP call transcript analyzed - safe word verified',
          actor: 'ONYX AI',
          hash: 'a7f3e9c2',
          verified: true,
        ),
        _LedgerEntry(
          id: 'L002',
          timestamp: DateTime(2026, 3, 10, 22, 14, 12),
          type: _LedgerType.aiAction,
          description: 'VoIP call initiated to sovereign contact',
          actor: 'ONYX AI',
          hash: 'b8e41d3f',
          verified: true,
        ),
        _LedgerEntry(
          id: 'L003',
          timestamp: DateTime(2026, 3, 10, 22, 14, 6),
          type: _LedgerType.aiAction,
          description: 'Auto-dispatch created for Echo-3',
          actor: 'ONYX AI',
          hash: 'c9f52e4g',
          verified: true,
        ),
        _LedgerEntry(
          id: 'L004',
          timestamp: DateTime(2026, 3, 10, 22, 14, 3),
          type: _LedgerType.systemEvent,
          description: 'Perimeter breach signal received from Site-Sandton-04',
          hash: 'd1a63f5h',
          verified: true,
        ),
        _LedgerEntry(
          id: 'L005',
          timestamp: DateTime(2026, 3, 10, 22, 8, 45),
          type: _LedgerType.humanOverride,
          description: 'INC-8830 dispatch cancelled by Controller-1',
          actor: 'Admin-1',
          reasonCode: 'FALSE_ALARM',
          hash: 'e2b74g6i',
          verified: true,
        ),
      ];
    }
    return entries;
  }

  List<_GuardVigilance> _deriveVigilance(List<DispatchEvent> events) {
    final checkIns = events.whereType<GuardCheckedIn>().toList(growable: false)
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    if (checkIns.isEmpty) {
      return const [
        _GuardVigilance(
          callsign: 'Echo-3',
          decayLevel: 67,
          lastCheckIn: '22:12',
          sparkline: [58, 61, 63, 64, 66, 67, 67, 67],
        ),
        _GuardVigilance(
          callsign: 'Bravo-2',
          decayLevel: 42,
          lastCheckIn: '22:10',
          sparkline: [35, 38, 40, 41, 42, 42, 42, 42],
        ),
        _GuardVigilance(
          callsign: 'Delta-1',
          decayLevel: 89,
          lastCheckIn: '22:02',
          sparkline: [74, 78, 82, 85, 87, 88, 89, 89],
        ),
        _GuardVigilance(
          callsign: 'Alpha-5',
          decayLevel: 98,
          lastCheckIn: '21:45',
          sparkline: [84, 87, 90, 93, 95, 97, 98, 98],
        ),
      ];
    }
    final now = DateTime.now().toUtc();
    final grouped = <String, List<GuardCheckedIn>>{};
    for (final checkIn in checkIns) {
      grouped
          .putIfAbsent(checkIn.guardId, () => <GuardCheckedIn>[])
          .add(checkIn);
    }
    return grouped.entries
        .take(6)
        .map((entry) {
          final latest = entry.value.first.occurredAt;
          final elapsedMinutes = now.difference(latest).inMinutes;
          final decay = ((elapsedMinutes / 20) * 100).round().clamp(0, 100);
          final sparkline = List<int>.generate(8, (index) {
            final value = decay - ((7 - index) * 3);
            return value.clamp(12, 100);
          });
          return _GuardVigilance(
            callsign: entry.key,
            decayLevel: decay,
            lastCheckIn: '${elapsedMinutes}m ago',
            sparkline: sparkline,
          );
        })
        .toList(growable: false);
  }

  bool _duressDetected(_IncidentRecord incident) {
    return incident.priority == _IncidentPriority.p1Critical &&
        incident.status == _IncidentStatus.triaging;
  }

  Color _statusChipColor(_IncidentStatus status) {
    return switch (status) {
      _IncidentStatus.triaging => const Color(0xFF22D3EE),
      _IncidentStatus.dispatched => const Color(0xFFF59E0B),
      _IncidentStatus.investigating => const Color(0xFF3B82F6),
      _IncidentStatus.resolved => const Color(0xFF10B981),
    };
  }

  _PriorityStyle _priorityStyle(_IncidentPriority priority) {
    return switch (priority) {
      _IncidentPriority.p1Critical => const _PriorityStyle(
        label: 'P1',
        foreground: Color(0xFFEF4444),
        background: Color(0x33EF4444),
        border: Color(0x66EF4444),
        icon: Icons.local_fire_department_rounded,
      ),
      _IncidentPriority.p2High => const _PriorityStyle(
        label: 'P2',
        foreground: Color(0xFFF59E0B),
        background: Color(0x33F59E0B),
        border: Color(0x66F59E0B),
        icon: Icons.warning_amber_rounded,
      ),
      _IncidentPriority.p3Medium => const _PriorityStyle(
        label: 'P3',
        foreground: Color(0xFFFACC15),
        background: Color(0x33FACC15),
        border: Color(0x66FACC15),
        icon: Icons.schedule_rounded,
      ),
      _IncidentPriority.p4Low => const _PriorityStyle(
        label: 'P4',
        foreground: Color(0xFF3B82F6),
        background: Color(0x333B82F6),
        border: Color(0x663B82F6),
        icon: Icons.shield_outlined,
      ),
    };
  }

  _LedgerStyle _ledgerStyle(_LedgerType type) {
    return switch (type) {
      _LedgerType.aiAction => const _LedgerStyle(
        icon: Icons.psychology_alt_rounded,
        color: Color(0xFF22D3EE),
      ),
      _LedgerType.humanOverride => const _LedgerStyle(
        icon: Icons.person_rounded,
        color: Color(0xFF10B981),
      ),
      _LedgerType.systemEvent => const _LedgerStyle(
        icon: Icons.settings_rounded,
        color: Color(0xFF3B82F6),
      ),
      _LedgerType.escalation => const _LedgerStyle(
        icon: Icons.priority_high_rounded,
        color: Color(0xFFEF4444),
      ),
    };
  }

  String _ledgerTypeLabel(_LedgerType type) {
    return switch (type) {
      _LedgerType.aiAction => 'AI ACTION',
      _LedgerType.humanOverride => 'HUMAN OVERRIDE',
      _LedgerType.systemEvent => 'SYSTEM EVENT',
      _LedgerType.escalation => 'ESCALATION',
    };
  }

  Color _stepColor(_LadderStepStatus status) {
    return switch (status) {
      _LadderStepStatus.completed => const Color(0xFF10B981),
      _LadderStepStatus.active => const Color(0xFF22D3EE),
      _LadderStepStatus.thinking => const Color(0xFF22D3EE),
      _LadderStepStatus.pending => const Color(0xFF6F84A3),
      _LadderStepStatus.blocked => const Color(0xFFEF4444),
    };
  }

  IconData _stepIcon(_LadderStepStatus status) {
    return switch (status) {
      _LadderStepStatus.completed => Icons.check_circle_rounded,
      _LadderStepStatus.active => Icons.autorenew_rounded,
      _LadderStepStatus.thinking => Icons.hourglass_top_rounded,
      _LadderStepStatus.pending => Icons.radio_button_unchecked_rounded,
      _LadderStepStatus.blocked => Icons.cancel_rounded,
    };
  }

  String _stepLabel(_LadderStepStatus status) {
    return switch (status) {
      _LadderStepStatus.completed => 'COMPLETED',
      _LadderStepStatus.active => 'ACTIVE',
      _LadderStepStatus.thinking => 'THINKING',
      _LadderStepStatus.pending => 'PENDING',
      _LadderStepStatus.blocked => 'BLOCKED',
    };
  }

  String _tabLabel(_ContextTab tab) {
    return switch (tab) {
      _ContextTab.details => 'DETAILS',
      _ContextTab.voip => 'VOIP',
      _ContextTab.visual => 'VISUAL',
    };
  }

  String _statusLabel(_IncidentStatus status) {
    return switch (status) {
      _IncidentStatus.triaging => 'TRIAGING',
      _IncidentStatus.dispatched => 'DISPATCHED',
      _IncidentStatus.investigating => 'INVESTIGATING',
      _IncidentStatus.resolved => 'RESOLVED',
    };
  }

  String _partnerDispatchStatusLabel(PartnerDispatchStatus status) {
    return switch (status) {
      PartnerDispatchStatus.accepted => 'ACCEPT',
      PartnerDispatchStatus.onSite => 'ON SITE',
      PartnerDispatchStatus.allClear => 'ALL CLEAR',
      PartnerDispatchStatus.cancelled => 'CANCEL',
    };
  }

  (Color, Color, Color) _partnerProgressTone(PartnerDispatchStatus status) {
    return switch (status) {
      PartnerDispatchStatus.accepted => (
        const Color(0xFF38BDF8),
        const Color(0x1A38BDF8),
        const Color(0x6638BDF8),
      ),
      PartnerDispatchStatus.onSite => (
        const Color(0xFFF59E0B),
        const Color(0x1AF59E0B),
        const Color(0x66F59E0B),
      ),
      PartnerDispatchStatus.allClear => (
        const Color(0xFF34D399),
        const Color(0x1A34D399),
        const Color(0x6634D399),
      ),
      PartnerDispatchStatus.cancelled => (
        const Color(0xFFF87171),
        const Color(0x1AF87171),
        const Color(0x66F87171),
      ),
    };
  }

  Color _partnerTrendColor(String trendLabel) {
    return switch (trendLabel.trim().toUpperCase()) {
      'IMPROVING' => const Color(0xFF34D399),
      'STABLE' => const Color(0xFF38BDF8),
      'SLIPPING' => const Color(0xFFF97316),
      'NEW' => const Color(0xFFFDE68A),
      _ => const Color(0xFF9CB4D0),
    };
  }

  Color _clientCommsAccent(LiveClientCommsSnapshot snapshot) {
    if (snapshot.pendingApprovalCount > 0) {
      return const Color(0xFFF59E0B);
    }
    final bridge = snapshot.telegramHealthLabel.trim().toLowerCase();
    final push = snapshot.pushSyncStatusLabel.trim().toLowerCase();
    if (bridge == 'blocked' ||
        bridge == 'degraded' ||
        push == 'failed' ||
        snapshot.telegramFallbackActive) {
      return const Color(0xFFF97316);
    }
    return const Color(0xFF22D3EE);
  }

  Color _controlInboxAccent(LiveControlInboxSnapshot snapshot) {
    if (snapshot.pendingApprovalCount > 0) {
      return const Color(0xFFF59E0B);
    }
    if (snapshot.awaitingResponseCount > 0) {
      return const Color(0xFF22D3EE);
    }
    final bridge = snapshot.telegramHealthLabel.trim().toLowerCase();
    if (snapshot.telegramFallbackActive ||
        bridge == 'blocked' ||
        bridge == 'degraded') {
      return const Color(0xFFF97316);
    }
    return const Color(0xFF22D3EE);
  }

  String _clientLaneTopBarLabel(LiveClientCommsSnapshot? snapshot) {
    if (snapshot == null) {
      return 'Client lane idle';
    }
    if (snapshot.pendingApprovalCount > 0) {
      return '${snapshot.pendingApprovalCount} Client Reply${snapshot.pendingApprovalCount == 1 ? '' : 's'} Awaiting';
    }
    if (snapshot.smsFallbackEligibleNow) {
      return 'Client lane SMS fallback ready';
    }
    if (snapshot.telegramFallbackActive) {
      return 'Client lane on fallback';
    }
    if (snapshot.clientInboundCount > 0) {
      return '${snapshot.clientInboundCount} Client Msg${snapshot.clientInboundCount == 1 ? '' : 's'} Live';
    }
    return 'Client lane stable';
  }

  Color _clientLaneTopBarForeground(LiveClientCommsSnapshot? snapshot) {
    if (snapshot == null) {
      return const Color(0xFF8FA7C8);
    }
    return _clientCommsAccent(snapshot);
  }

  Color _clientLaneTopBarBackground(LiveClientCommsSnapshot? snapshot) {
    final foreground = _clientLaneTopBarForeground(snapshot);
    return foreground.withValues(alpha: 0.18);
  }

  Color _clientLaneTopBarBorder(LiveClientCommsSnapshot? snapshot) {
    final foreground = _clientLaneTopBarForeground(snapshot);
    return foreground.withValues(alpha: 0.42);
  }

  Color _telegramHealthAccent(String label) {
    return switch (label.trim().toLowerCase()) {
      'ok' => const Color(0xFF34D399),
      'blocked' => const Color(0xFFEF4444),
      'degraded' => const Color(0xFFF59E0B),
      'disabled' => const Color(0xFF8EA4C2),
      _ => const Color(0xFF38BDF8),
    };
  }

  Color _pushSyncAccent(String label) {
    return switch (label.trim().toLowerCase()) {
      'ok' => const Color(0xFF34D399),
      'failed' => const Color(0xFFEF4444),
      'syncing' => const Color(0xFF38BDF8),
      _ => const Color(0xFF8EA4C2),
    };
  }

  Color _smsFallbackAccent(
    String label, {
    required bool ready,
    required bool eligibleNow,
  }) {
    if (eligibleNow) {
      return const Color(0xFFF59E0B);
    }
    if (ready) {
      return const Color(0xFF34D399);
    }
    final normalized = label.trim().toLowerCase();
    if (normalized.contains('pending')) {
      return const Color(0xFFF97316);
    }
    return const Color(0xFF8EA4C2);
  }

  Color _voiceReadinessAccent(String label) {
    return switch (label.trim().toLowerCase()) {
      'voip ready' => const Color(0xFF34D399),
      'voip contact pending' => const Color(0xFFF59E0B),
      'voip staged' => const Color(0xFF38BDF8),
      _ => const Color(0xFF8EA4C2),
    };
  }

  String _clientCommsNarrative(LiveClientCommsSnapshot snapshot) {
    if (snapshot.pendingApprovalCount > 0) {
      return 'client reply waiting on human approval';
    }
    final bridge = snapshot.telegramHealthLabel.trim().toLowerCase();
    final push = snapshot.pushSyncStatusLabel.trim().toLowerCase();
    if (bridge == 'blocked' || bridge == 'degraded') {
      return 'delivery lane needs operator attention';
    }
    if (push == 'failed') {
      return 'push sync is failing and needs recovery';
    }
    if (snapshot.smsFallbackEligibleNow) {
      return 'telegram needs help and sms fallback is standing by';
    }
    if ((snapshot.latestClientMessage ?? '').trim().isNotEmpty) {
      return 'client lane is active and being tracked';
    }
    return 'client lane is quiet for now';
  }

  String _clientCommsOpsFootnote(LiveClientCommsSnapshot snapshot) {
    final notes = <String>[
      if (snapshot.telegramFallbackActive) 'Telegram fallback is active',
      if (snapshot.queuedPushCount > 0)
        '${snapshot.queuedPushCount} push item${snapshot.queuedPushCount == 1 ? '' : 's'} queued',
      if ((snapshot.telegramHealthDetail ?? '').trim().isNotEmpty)
        ClientDeliveryMessageFormatter.humanizeScopedCommsSummary(
          snapshot.telegramHealthDetail!.trim(),
        ),
      if ((snapshot.deliveryReadinessDetail ?? '').trim().isNotEmpty)
        snapshot.deliveryReadinessDetail!.trim(),
      if ((snapshot.pushSyncFailureReason ?? '').trim().isNotEmpty)
        'Push detail: ${ClientDeliveryMessageFormatter.humanizeScopedCommsSummary(snapshot.pushSyncFailureReason!.trim())}',
    ];
    return notes.join(' • ');
  }

  String _commsMomentLabel(DateTime? atUtc) {
    if (atUtc == null) {
      return '';
    }
    final local = atUtc.toLocal();
    final now = DateTime.now();
    final age = now.difference(local);
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    if (age.inMinutes < 1) {
      return 'just now • $hh:$mm';
    }
    if (age.inMinutes < 60) {
      return '${age.inMinutes}m ago • $hh:$mm';
    }
    if (age.inHours < 24) {
      return '${age.inHours}h ago • $hh:$mm';
    }
    return '${age.inDays}d ago • $hh:$mm';
  }

  String _humanizeOpsScopeLabel(String raw, {required String fallback}) {
    final cleaned = raw
        .trim()
        .replaceFirst(RegExp(r'^(CLIENT|SITE|REGION)-'), '')
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .replaceAll(RegExp(r'[^A-Za-z0-9 ]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) {
      return fallback;
    }
    final stopWords = <String>{'and', 'of', 'the'};
    return cleaned
        .split(' ')
        .where((token) => token.trim().isNotEmpty)
        .toList(growable: false)
        .asMap()
        .entries
        .map((entry) {
          final lower = entry.value.toLowerCase();
          if (entry.key > 0 && stopWords.contains(lower)) {
            return lower;
          }
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');
  }

  int _priorityRank(_IncidentPriority priority) {
    return switch (priority) {
      _IncidentPriority.p1Critical => 0,
      _IncidentPriority.p2High => 1,
      _IncidentPriority.p3Medium => 2,
      _IncidentPriority.p4Low => 3,
    };
  }

  _IncidentPriority _incidentPriorityFor(
    int risk, {
    required MonitoringSceneReviewRecord? latestSceneReview,
  }) {
    final basePriority = switch (risk) {
      >= 85 => _IncidentPriority.p1Critical,
      >= 70 => _IncidentPriority.p2High,
      >= 50 => _IncidentPriority.p3Medium,
      _ => _IncidentPriority.p4Low,
    };
    final posture = (latestSceneReview?.postureLabel ?? '')
        .trim()
        .toLowerCase();
    if (posture.contains('fire') || posture.contains('smoke')) {
      return _IncidentPriority.p1Critical;
    }
    if (posture.contains('flood') || posture.contains('leak')) {
      return _IncidentPriority.p1Critical;
    }
    if (posture.contains('hazard')) {
      if (_priorityRank(basePriority) >
          _priorityRank(_IncidentPriority.p2High)) {
        return _IncidentPriority.p2High;
      }
    }
    return basePriority;
  }

  String _incidentTypeFor(
    int risk, {
    required MonitoringSceneReviewRecord? latestSceneReview,
  }) {
    final posture = (latestSceneReview?.postureLabel ?? '')
        .trim()
        .toLowerCase();
    if (posture.contains('fire') || posture.contains('smoke')) {
      return 'Fire / Smoke Emergency';
    }
    if (posture.contains('flood') || posture.contains('leak')) {
      return 'Flood / Leak Emergency';
    }
    if (posture.contains('hazard')) {
      return 'Environmental Hazard';
    }
    return risk >= 85 ? 'Breach Detection' : 'Perimeter Alarm';
  }

  String _hhmm(DateTime timestamp) {
    final hh = timestamp.hour.toString().padLeft(2, '0');
    final mm = timestamp.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _evidenceReadyLabel(_IncidentRecord incident) {
    final snapshot = (incident.snapshotUrl ?? '').trim().isNotEmpty;
    final clip = (incident.clipUrl ?? '').trim().isNotEmpty;
    if (snapshot && clip) {
      return 'snapshot + clip';
    }
    if (snapshot) {
      return 'snapshot only';
    }
    if (clip) {
      return 'clip only';
    }
    return 'pending';
  }

  String _compactContextLabel(String value, {int maxLength = 68}) {
    final trimmed = value.trim();
    if (trimmed.length <= maxLength) {
      return trimmed;
    }
    return '${trimmed.substring(0, maxLength).trimRight()}...';
  }

  String _hashFor(String seed) {
    final value = seed.hashCode.toUnsigned(32);
    return value.toRadixString(16).padLeft(8, '0');
  }
}

class _PriorityStyle {
  final String label;
  final Color foreground;
  final Color background;
  final Color border;
  final IconData icon;

  const _PriorityStyle({
    required this.label,
    required this.foreground,
    required this.background,
    required this.border,
    required this.icon,
  });
}

class _LedgerStyle {
  final IconData icon;
  final Color color;

  const _LedgerStyle({required this.icon, required this.color});
}
