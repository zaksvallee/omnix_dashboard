import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../application/monitoring_global_posture_service.dart';
import '../application/monitoring_scene_review_store.dart';
import '../application/monitoring_watch_action_plan.dart';
import '../application/monitoring_watch_autonomy_service.dart';
import '../application/shadow_mo_dossier_contract.dart';
import '../application/synthetic_promotion_summary_formatter.dart';
import '../domain/events/decision_created.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/events/execution_completed.dart';
import '../domain/events/execution_denied.dart';
import '../domain/events/intelligence_received.dart';
import '../domain/events/incident_closed.dart';
import 'layout_breakpoints.dart';
import 'onyx_surface.dart';
import 'theme/onyx_design_tokens.dart';

enum _AiIncidentPriority { p1Critical, p2High, p3Medium }

enum _AiActionStatus { pending, executing, paused }

enum _AiQueueLaneFilter { live, queued, drafts, shadow }

enum _AiQueueWorkspaceView { runbook, policy, context }

class _AiQueueAction {
  final String id;
  final String incidentId;
  final _AiIncidentPriority incidentPriority;
  final String site;
  final String actionType;
  final String description;
  final int timeUntilExecutionSeconds;
  final int initialExecutionSeconds;
  final _AiActionStatus status;
  final Map<String, String> metadata;

  const _AiQueueAction({
    required this.id,
    required this.incidentId,
    required this.incidentPriority,
    required this.site,
    required this.actionType,
    required this.description,
    required this.timeUntilExecutionSeconds,
    required this.initialExecutionSeconds,
    required this.status,
    required this.metadata,
  });

  _AiQueueAction copyWith({
    String? id,
    String? incidentId,
    _AiIncidentPriority? incidentPriority,
    String? site,
    String? actionType,
    String? description,
    int? timeUntilExecutionSeconds,
    int? initialExecutionSeconds,
    _AiActionStatus? status,
    Map<String, String>? metadata,
  }) {
    return _AiQueueAction(
      id: id ?? this.id,
      incidentId: incidentId ?? this.incidentId,
      incidentPriority: incidentPriority ?? this.incidentPriority,
      site: site ?? this.site,
      actionType: actionType ?? this.actionType,
      description: description ?? this.description,
      timeUntilExecutionSeconds:
          timeUntilExecutionSeconds ?? this.timeUntilExecutionSeconds,
      initialExecutionSeconds:
          initialExecutionSeconds ?? this.initialExecutionSeconds,
      status: status ?? this.status,
      metadata: metadata ?? this.metadata,
    );
  }
}

class _AiQueueDailyStats {
  final int totalActions;
  final int executed;
  final int overridden;
  final int approvalRate;

  const _AiQueueDailyStats({
    required this.totalActions,
    required this.executed,
    required this.overridden,
    required this.approvalRate,
  });
}

class _AiQueueCommandReceipt {
  final String label;
  final String message;
  final String detail;
  final Color accent;

  const _AiQueueCommandReceipt({
    required this.label,
    required this.message,
    required this.detail,
    required this.accent,
  });
}

class AiQueueEvidenceReturnReceipt {
  final String auditId;
  final String label;
  final String message;
  final String detail;
  final Color accent;

  const AiQueueEvidenceReturnReceipt({
    required this.auditId,
    required this.label,
    required this.message,
    required this.detail,
    required this.accent,
  });
}

class _CctvBoardAlert {
  final String id;
  final String headline;
  final String summary;
  final String siteLabel;
  final String cameraLabel;
  final String feedId;
  final String occurredLabel;
  final _AiIncidentPriority priority;

  const _CctvBoardAlert({
    required this.id,
    required this.headline,
    required this.summary,
    required this.siteLabel,
    required this.cameraLabel,
    required this.feedId,
    required this.occurredLabel,
    required this.priority,
  });
}

class _CctvBoardFeed {
  final String id;
  final String label;
  final bool highlighted;
  final bool hasAlert;

  const _CctvBoardFeed({
    required this.id,
    required this.label,
    this.highlighted = false,
    this.hasAlert = false,
  });
}

class AIQueuePage extends StatefulWidget {
  final List<DispatchEvent> events;
  final String focusIncidentReference;
  final String? agentReturnIncidentReference;
  final ValueChanged<String>? onConsumeAgentReturnIncidentReference;
  final AiQueueEvidenceReturnReceipt? evidenceReturnReceipt;
  final ValueChanged<String>? onConsumeEvidenceReturnReceipt;
  final String initialSelectedFeedId;
  final List<String> historicalSyntheticLearningLabels;
  final List<String> historicalShadowMoLabels;
  final List<String> historicalShadowStrengthLabels;
  final String previousTomorrowUrgencySummary;
  final String videoOpsLabel;
  final Map<String, MonitoringSceneReviewRecord> sceneReviewByIntelligenceId;
  final ValueChanged<String>? onOpenAlarmsForIncident;
  final ValueChanged<String>? onOpenAgentForIncident;
  final void Function(List<String> eventIds, String? selectedEventId)?
  onOpenEventsForScope;

  const AIQueuePage({
    super.key,
    required this.events,
    this.focusIncidentReference = '',
    this.agentReturnIncidentReference,
    this.onConsumeAgentReturnIncidentReference,
    this.evidenceReturnReceipt,
    this.onConsumeEvidenceReturnReceipt,
    this.initialSelectedFeedId = '',
    this.historicalSyntheticLearningLabels = const <String>[],
    this.historicalShadowMoLabels = const <String>[],
    this.historicalShadowStrengthLabels = const <String>[],
    this.previousTomorrowUrgencySummary = '',
    this.videoOpsLabel = 'CCTV',
    this.sceneReviewByIntelligenceId = const {},
    this.onOpenAlarmsForIncident,
    this.onOpenAgentForIncident,
    this.onOpenEventsForScope,
  });

  @override
  State<AIQueuePage> createState() => _AIQueuePageState();
}

class _AIQueuePageState extends State<AIQueuePage> {
  static const _autonomyService = MonitoringWatchAutonomyService();
  static const _globalPostureService = MonitoringGlobalPostureService();
  static const _defaultCommandReceipt = _AiQueueCommandReceipt(
    label: 'AI CALL READY',
    message: 'The last AI decision stays pinned in this rail on desktop.',
    detail:
        'Promotions, pause changes, and shadow dossier exports stay visible while you work the next queue call.',
    accent: OnyxColorTokens.accentSky,
  );
  late List<_AiQueueAction> _actions;
  late _AiQueueDailyStats _stats;
  late List<MonitoringGlobalSitePosture> _cachedMoShadowSites;
  Timer? _ticker;
  bool _queuePaused = false;
  _AiQueueLaneFilter _laneFilter = _AiQueueLaneFilter.live;
  _AiQueueWorkspaceView _workspaceView = _AiQueueWorkspaceView.runbook;
  String? _selectedFocusId;
  _AiQueueCommandReceipt _commandReceipt = _defaultCommandReceipt;
  bool _showDetailedWorkspace = false;
  final Set<String> _dismissedCctvAlertIds = <String>{};
  final Set<String> _dispatchedCctvAlertIds = <String>{};
  String? _selectedCctvAlertId;
  String? _selectedCctvFeedId;

  @override
  void initState() {
    super.initState();
    _actions = List<_AiQueueAction>.from(
      _seedActions(widget.events, widget.sceneReviewByIntelligenceId),
    );
    _stats = _buildDailyStats(widget.events);
    _cachedMoShadowSites = _computeMoShadowSites();
    _syncCctvRouteSelection();
    _ingestEvidenceReturnReceipt(widget.evidenceReturnReceipt, fromInit: true);
    _ingestAgentReturnIncidentReference(fromInit: true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  @override
  void didUpdateWidget(covariant AIQueuePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.events != widget.events ||
        oldWidget.historicalSyntheticLearningLabels !=
            widget.historicalSyntheticLearningLabels ||
        oldWidget.historicalShadowMoLabels != widget.historicalShadowMoLabels ||
        oldWidget.historicalShadowStrengthLabels !=
            widget.historicalShadowStrengthLabels ||
        oldWidget.videoOpsLabel != widget.videoOpsLabel ||
        oldWidget.sceneReviewByIntelligenceId !=
            widget.sceneReviewByIntelligenceId) {
      _actions = List<_AiQueueAction>.from(
        _seedActions(widget.events, widget.sceneReviewByIntelligenceId),
      );
      _stats = _buildDailyStats(widget.events);
      _cachedMoShadowSites = _computeMoShadowSites();
      _selectedFocusId = null;
      _dismissedCctvAlertIds.clear();
      _dispatchedCctvAlertIds.clear();
      _selectedCctvAlertId = null;
      _selectedCctvFeedId = null;
    }
    final routeSelectionActive =
        widget.focusIncidentReference.trim().isNotEmpty ||
        widget.initialSelectedFeedId.trim().isNotEmpty;
    final routeSelectionChanged =
        oldWidget.focusIncidentReference != widget.focusIncidentReference ||
        oldWidget.initialSelectedFeedId != widget.initialSelectedFeedId;
    if (routeSelectionChanged || routeSelectionActive) {
      _syncCctvRouteSelection();
    }
    if (oldWidget.agentReturnIncidentReference?.trim() !=
        widget.agentReturnIncidentReference?.trim()) {
      _ingestAgentReturnIncidentReference();
    }
    if (oldWidget.evidenceReturnReceipt?.auditId !=
        widget.evidenceReturnReceipt?.auditId) {
      _ingestEvidenceReturnReceipt(widget.evidenceReturnReceipt);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeAction = _activeAction;
    final queuedActions = _displayQueuedActions;
    final nextShiftDrafts = _nextShiftDrafts;
    final moShadowSites = _moShadowSites;
    final focusItems = _buildFocusItems(
      activeAction: activeAction,
      queuedActions: queuedActions,
      nextShiftDrafts: nextShiftDrafts,
      moShadowSites: moShadowSites,
    );
    final effectiveLane = _effectiveLaneForItems(focusItems);
    final laneItems = focusItems
        .where((item) => item.lane == effectiveLane)
        .toList(growable: false);
    final selectedFocus = _resolveSelectedFocus(
      laneItems: laneItems,
      allItems: focusItems,
    );
    final agentIncidentReference =
        (selectedFocus?.action?.incidentId ?? activeAction?.incidentId ?? '')
            .trim();
    final viewport = MediaQuery.sizeOf(context).width;
    final compact = viewport < 900 || isHandsetLayout(context);
    final showPinnedCommandReceipt = _hasPinnedCommandReceipt;
    if (!compact && viewport >= 1180 && !_showDetailedWorkspace) {
      return _buildCctvOverviewPage(
        context,
        showPinnedCommandReceipt: showPinnedCommandReceipt,
      );
    }
    final useEmbeddedWorkspace = !compact && allowEmbeddedPanelScroll(context);
    final mergeWorkspaceBannerIntoHero = !compact && viewport >= 1180;
    final contentPadding = compact
        ? const EdgeInsets.all(8)
        : const EdgeInsets.fromLTRB(2.25, 2.25, 2.25, 3.0);

    Widget buildWorkspaceSection({required bool expandToFill}) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final useEmbeddedPanels =
              constraints.maxWidth >= 1240 && allowEmbeddedPanelScroll(context);
          final useWideLayout = constraints.maxWidth >= 1180;
          final workspace = _automationWorkspace(
            activeAction: activeAction,
            queuedActions: queuedActions,
            nextShiftDrafts: nextShiftDrafts,
            moShadowSites: moShadowSites,
            focusItems: focusItems,
            laneItems: laneItems,
            selectedFocus: selectedFocus,
            effectiveLane: effectiveLane,
            useWideLayout: useWideLayout,
            useEmbeddedPanels: useEmbeddedPanels,
            compact: compact,
          );
          if (expandToFill) {
            if (!useWideLayout) {
              return workspace;
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!mergeWorkspaceBannerIntoHero) ...[
                  _workspaceStatusBanner(
                    activeAction: activeAction,
                    selectedFocus: selectedFocus,
                    effectiveLane: effectiveLane,
                  ),
                  const SizedBox(height: 1.35),
                ],
                Expanded(child: workspace),
              ],
            );
          }
          final workspaceShell = useWideLayout
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!mergeWorkspaceBannerIntoHero) ...[
                      _workspaceStatusBanner(
                        activeAction: activeAction,
                        selectedFocus: selectedFocus,
                        effectiveLane: effectiveLane,
                      ),
                      const SizedBox(height: 1.35),
                    ],
                    if (useEmbeddedPanels)
                      Expanded(child: workspace)
                    else
                      workspace,
                  ],
                )
              : workspace;
          final sectionBody = useEmbeddedPanels
              ? SizedBox(
                  height: useWideLayout ? 564 : 526,
                  child: workspaceShell,
                )
              : workspaceShell;
          if (!compact) {
            return sectionBody;
          }
          return OnyxSectionCard(
            title: 'Automation Workspace',
            subtitle:
                'Lane-based queue supervision with a selected automation board and live context.',
            flexibleChild: expandToFill,
            child: sectionBody,
          );
        },
      );
    }

    Widget buildSurfaceBody() {
      return LayoutBuilder(
        builder: (context, bodyConstraints) {
          final showSnapshotStrip = compact && bodyConstraints.maxWidth < 1180;
          final content = showSnapshotStrip
              ? [
                  _queueSnapshotStrip(
                    queuedActions: queuedActions,
                    nextShiftDrafts: nextShiftDrafts,
                    moShadowSites: moShadowSites,
                    selectedFocus: selectedFocus,
                    effectiveLane: effectiveLane,
                    compactPresentation: useEmbeddedWorkspace,
                  ),
                  SizedBox(height: useEmbeddedWorkspace ? 1.35 : 1.55),
                ]
              : const <Widget>[];
          if (useEmbeddedWorkspace) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...content,
                Expanded(child: buildWorkspaceSection(expandToFill: true)),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [...content, buildWorkspaceSection(expandToFill: false)],
          );
        },
      );
    }

    return OnyxPageScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final boundedDesktopSurface =
              useEmbeddedWorkspace &&
              constraints.hasBoundedHeight &&
              constraints.maxHeight.isFinite;
          final ultrawideSurface = isUltrawideLayout(
            context,
            viewportWidth: constraints.maxWidth,
          );
          final surfaceMaxWidth = commandSurfaceMaxWidth(
            context,
            compactDesktopWidth: 1600,
            viewportWidth: constraints.maxWidth,
            widescreenFillFactor: ultrawideSurface ? 1 : 0.95,
          );
          return OnyxViewportWorkspaceLayout(
            padding: contentPadding,
            maxWidth: surfaceMaxWidth,
            lockToViewport: boundedDesktopSurface,
            spacing: 1.55,
            header: _heroHeader(
              context,
              compact: compact,
              totalQueueCount: _actions.length,
              showOverviewToggle: !compact && viewport >= 1180,
              agentIncidentReference: agentIncidentReference,
              onOpenAgent:
                  widget.onOpenAgentForIncident == null ||
                      agentIncidentReference.isEmpty
                  ? null
                  : () =>
                        widget.onOpenAgentForIncident!(agentIncidentReference),
              workspaceBanner: mergeWorkspaceBannerIntoHero
                  ? _workspaceStatusBanner(
                      activeAction: activeAction,
                      selectedFocus: selectedFocus,
                      effectiveLane: effectiveLane,
                      summaryOnly: true,
                      shellless: true,
                    )
                  : null,
            ),
            body: buildSurfaceBody(),
          );
        },
      ),
    );
  }

  List<String> _eventIdsForAction(_AiQueueAction action) {
    final matching = <String>[];
    for (final event in widget.events) {
      final eventId = event.eventId.trim();
      if (eventId.isEmpty || matching.contains(eventId)) {
        continue;
      }
      final matches = switch (event) {
        DecisionCreated(:final dispatchId, :final siteId) =>
          dispatchId == action.incidentId || siteId == action.site,
        ExecutionCompleted(:final dispatchId, :final siteId) =>
          dispatchId == action.incidentId || siteId == action.site,
        ExecutionDenied(:final dispatchId, :final siteId) =>
          dispatchId == action.incidentId || siteId == action.site,
        IncidentClosed(:final dispatchId, :final siteId) =>
          dispatchId == action.incidentId || siteId == action.site,
        IntelligenceReceived(:final siteId) => siteId == action.site,
        _ => false,
      };
      if (matches) {
        matching.add(eventId);
      }
    }
    return matching;
  }

  void _openEventsForAction(_AiQueueAction action) {
    final callback = widget.onOpenEventsForScope;
    if (callback == null) {
      return;
    }
    final eventIds = _eventIdsForAction(action);
    if (eventIds.isEmpty) {
      return;
    }
    callback(eventIds, eventIds.first);
  }

  _AiQueueAction? _actionForAlert(_CctvBoardAlert alert) {
    for (final action in _actions) {
      if (action.id == alert.id) {
        return action;
      }
    }
    return null;
  }

  String _normalizeIncidentReference(String value) {
    final normalized = value.trim().toUpperCase();
    if (normalized.startsWith('INC-')) {
      return normalized.substring(4);
    }
    return normalized;
  }

  bool _matchesCctvRouteFocus(_CctvBoardAlert alert) {
    final preferredFeedId = widget.initialSelectedFeedId.trim();
    if (preferredFeedId.isNotEmpty && alert.feedId == preferredFeedId) {
      return true;
    }
    final focusReference = widget.focusIncidentReference.trim();
    if (focusReference.isEmpty) {
      return false;
    }
    final action = _actionForAlert(alert);
    if (action == null) {
      return false;
    }
    final normalizedFocusReference = _normalizeIncidentReference(
      focusReference,
    );
    return _normalizeIncidentReference(action.incidentId) ==
            normalizedFocusReference ||
        _normalizeIncidentReference(alert.id) == normalizedFocusReference;
  }

  void _syncCctvRouteSelection() {
    final routeFeedId = widget.initialSelectedFeedId.trim();
    final alerts = _seedCctvAlerts()
        .where((alert) => !_dismissedCctvAlertIds.contains(alert.id))
        .toList(growable: false);
    final focusedAlert = alerts.cast<_CctvBoardAlert?>().firstWhere(
      (alert) => alert != null && _matchesCctvRouteFocus(alert),
      orElse: () => null,
    );
    _selectedCctvAlertId = focusedAlert?.id;
    _selectedCctvFeedId = routeFeedId.isNotEmpty
        ? routeFeedId
        : focusedAlert?.feedId;
  }

  Widget _buildCctvOverviewPage(
    BuildContext context, {
    required bool showPinnedCommandReceipt,
  }) {
    final alerts = _visibleCctvAlerts;
    final selectedAlert = _resolveSelectedCctvAlert(alerts);
    final feeds = _buildCctvFeeds(selectedAlert: selectedAlert);

    return OnyxPageScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final ultrawideSurface = isUltrawideLayout(
            context,
            viewportWidth: constraints.maxWidth,
          );
          final surfaceMaxWidth = commandSurfaceMaxWidth(
            context,
            compactDesktopWidth: 1600,
            viewportWidth: constraints.maxWidth,
            widescreenFillFactor: ultrawideSurface ? 1 : 0.95,
          );
          final singleColumn = constraints.maxWidth < 1420;

          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CCTV monitoring',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: OnyxColorTokens.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'AI-powered video surveillance and alerts',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: OnyxColorTokens.textSecondary,
                    ),
                  ),
                ],
              ),
              if (showPinnedCommandReceipt) ...[
                const SizedBox(height: 16),
                _workspaceCommandReceiptCard(),
              ],
              const SizedBox(height: 16),
              if (singleColumn) ...[
                _buildCctvAlertPanel(selectedAlert: selectedAlert),
                const SizedBox(height: 16),
                _buildCctvFeedsPanel(feeds: feeds),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 360,
                      child: _buildCctvAlertPanel(selectedAlert: selectedAlert),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: _buildCctvFeedsPanel(feeds: feeds)),
                  ],
                ),
              const SizedBox(height: 16),
              _buildCctvWorkspaceToggle(),
            ],
          );

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: surfaceMaxWidth),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                child: content,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCctvAlertPanel({required _CctvBoardAlert? selectedAlert}) {
    if (selectedAlert == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: OnyxColorTokens.backgroundSecondary,
          border: Border.all(color: OnyxColorTokens.divider),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: OnyxColorTokens.greenSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: OnyxColorTokens.greenBorder),
              ),
              child: const Icon(
                Icons.videocam_rounded,
                color: OnyxColorTokens.accentGreen,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No active AI alerts',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: OnyxColorTokens.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'All cameras nominal',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: OnyxColorTokens.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final dispatched = _dispatchedCctvAlertIds.contains(selectedAlert.id);
    final agentIncidentReference = _incidentReferenceForAlert(selectedAlert);

    return Container(
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: OnyxColorTokens.accentAmber, width: 3),
          top: BorderSide(color: OnyxColorTokens.divider),
          right: BorderSide(color: OnyxColorTokens.divider),
          bottom: BorderSide(color: OnyxColorTokens.divider),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: OnyxColorTokens.amberSurface,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: OnyxColorTokens.accentAmber,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'AI ALERT',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: OnyxColorTokens.accentAmber,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    selectedAlert.headline,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: OnyxColorTokens.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _alertField('SITE', selectedAlert.siteLabel),
                const SizedBox(height: 10),
                _alertField('CAMERA', selectedAlert.cameraLabel),
                const SizedBox(height: 10),
                _alertField('TIME', selectedAlert.occurredLabel),
                if (dispatched) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: OnyxColorTokens.cyanSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: OnyxColorTokens.cyanBorder),
                    ),
                    child: Text(
                      'Guard dispatch staged. Keep this camera pinned until the scene is verified.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: OnyxColorTokens.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    key: const ValueKey('ai-queue-action-view-camera'),
                    icon: const Icon(Icons.fullscreen_rounded, size: 16),
                    label: const Text('View camera'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: OnyxColorTokens.accentPurple,
                      foregroundColor: OnyxColorTokens.textPrimary,
                      minimumSize: const Size(double.infinity, 40),
                      elevation: 0,
                      textStyle: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _viewCctvAlert(selectedAlert),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    key: const ValueKey('ai-queue-action-dispatch-guard'),
                    icon: const Icon(Icons.warning_amber_rounded, size: 16),
                    label: Text(
                      dispatched ? 'Guard dispatched' : 'Dispatch guard',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: OnyxColorTokens.accentRed,
                      foregroundColor: OnyxColorTokens.textPrimary,
                      disabledBackgroundColor: OnyxColorTokens.accentRed
                          .withValues(alpha: 0.35),
                      disabledForegroundColor: OnyxColorTokens.textPrimary
                          .withValues(alpha: 0.7),
                      minimumSize: const Size(double.infinity, 40),
                      elevation: 0,
                      textStyle: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: dispatched
                        ? null
                        : () => _dispatchCctvAlert(selectedAlert),
                  ),
                ),
                if (widget.onOpenAgentForIncident != null &&
                    agentIncidentReference.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const ValueKey('ai-queue-action-open-agent'),
                      icon: const Icon(Icons.psychology_alt_rounded, size: 16),
                      label: const Text('Ask agent'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: OnyxColorTokens.accentPurple,
                        side: const BorderSide(
                          color: OnyxColorTokens.purpleBorder,
                        ),
                        minimumSize: const Size(double.infinity, 40),
                        textStyle: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => widget.onOpenAgentForIncident!(
                        agentIncidentReference,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OnyxColorTokens.textSecondary,
                      side: const BorderSide(color: OnyxColorTokens.divider),
                      minimumSize: const Size(double.infinity, 40),
                      textStyle: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _dismissCctvAlert(selectedAlert),
                    child: const Text('Dismiss'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _alertField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: OnyxColorTokens.textMuted,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 3),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: OnyxColorTokens.backgroundPrimary,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: OnyxColorTokens.divider),
          ),
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: OnyxColorTokens.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCctvFeedsPanel({required List<_CctvBoardFeed> feeds}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LIVE FEEDS',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: OnyxColorTokens.textMuted,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 16 / 10,
          ),
          itemCount: feeds.length,
          itemBuilder: (context, index) =>
              _buildCctvFeedTile(feed: feeds[index]),
        ),
      ],
    );
  }

  Widget _buildCctvFeedTile({required _CctvBoardFeed feed}) {
    final selected = feed.highlighted;
    final hasAlert = feed.hasAlert;
    final borderColor = hasAlert
        ? OnyxColorTokens.accentAmber
        : (selected ? OnyxColorTokens.accentPurple : OnyxColorTokens.divider);
    final borderWidth = hasAlert ? 1.5 : (selected ? 1.5 : 1.0);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        setState(() {
          _selectedCctvFeedId = feed.id;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: OnyxColorTokens.backgroundSecondary,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.play_circle_outline_rounded,
                    size: 28,
                    color: OnyxColorTokens.textMuted,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    feed.label,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: OnyxColorTokens.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      OnyxColorTokens.backgroundPrimary.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(7),
                    bottomRight: Radius.circular(7),
                  ),
                ),
                child: Text(
                  feed.label,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: OnyxColorTokens.textPrimary,
                  ),
                ),
              ),
            ),
            if (hasAlert)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: OnyxColorTokens.accentAmber,
                    boxShadow: [
                      BoxShadow(
                        color: OnyxColorTokens.accentAmber.withValues(
                          alpha: 0.5,
                        ),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCctvWorkspaceToggle() {
    return Align(
      alignment: Alignment.centerRight,
      child: OutlinedButton.icon(
        key: const ValueKey('ai-queue-toggle-detailed-workspace'),
        onPressed: () {
          setState(() {
            _showDetailedWorkspace = true;
          });
        },
        icon: const Icon(Icons.open_in_new_rounded, size: 14),
        label: const Text('Open detailed workspace'),
        style: OutlinedButton.styleFrom(
          foregroundColor: OnyxColorTokens.textSecondary,
          side: const BorderSide(color: OnyxColorTokens.divider),
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  List<_CctvBoardAlert> get _visibleCctvAlerts {
    final alerts = _availableCctvAlerts().toList(growable: true);
    final focusedIndex = alerts.indexWhere(_matchesCctvRouteFocus);
    if (focusedIndex > 0) {
      final focusedAlert = alerts.removeAt(focusedIndex);
      alerts.insert(0, focusedAlert);
    }
    return alerts.take(1).toList(growable: false);
  }

  List<_CctvBoardAlert> _availableCctvAlerts({String? excludingAlertId}) {
    final normalizedExcludedId = (excludingAlertId ?? '').trim();
    return _seedCctvAlerts()
        .where((alert) => !_dismissedCctvAlertIds.contains(alert.id))
        .where(
          (alert) =>
              normalizedExcludedId.isEmpty || alert.id != normalizedExcludedId,
        )
        .toList(growable: false);
  }

  _CctvBoardAlert? _resolveSelectedCctvAlert(List<_CctvBoardAlert> alerts) {
    if (alerts.isEmpty) {
      return null;
    }
    for (final alert in alerts) {
      if (alert.id == _selectedCctvAlertId) {
        return alert;
      }
    }
    return alerts.first;
  }

  List<_CctvBoardFeed> _buildCctvFeeds({
    required _CctvBoardAlert? selectedAlert,
  }) {
    final routeFeedId = widget.initialSelectedFeedId.trim();
    final selectedFeedId =
        (_selectedCctvFeedId ??
                (routeFeedId.isEmpty ? null : routeFeedId) ??
                selectedAlert?.feedId ??
                '')
            .trim();
    final alertFeedId = selectedAlert?.feedId.trim() ?? '';
    return List<_CctvBoardFeed>.generate(9, (index) {
      final id = 'CAM-${(index + 1).toString().padLeft(2, '0')}';
      return _CctvBoardFeed(
        id: id,
        label: id,
        highlighted: id == selectedFeedId,
        hasAlert: alertFeedId.isNotEmpty && id == alertFeedId,
      );
    }, growable: false);
  }

  void _viewCctvAlert(_CctvBoardAlert alert) {
    setState(() {
      _selectedCctvAlertId = alert.id;
      _selectedCctvFeedId = alert.feedId;
    });
  }

  void _dispatchCctvAlert(_CctvBoardAlert alert) {
    setState(() {
      _selectedCctvAlertId = alert.id;
      _selectedCctvFeedId = alert.feedId;
      _dispatchedCctvAlertIds.add(alert.id);
    });
    final callback = widget.onOpenAlarmsForIncident;
    final action = _actionForAlert(alert);
    final incidentReference =
        action != null && action.incidentId.trim().isNotEmpty
        ? action.incidentId.trim()
        : alert.id;
    if (callback != null && incidentReference.isNotEmpty) {
      callback(incidentReference);
    }
  }

  String _incidentReferenceForAlert(_CctvBoardAlert alert) {
    final action = _actionForAlert(alert);
    return action != null && action.incidentId.trim().isNotEmpty
        ? action.incidentId.trim()
        : alert.id.trim();
  }

  void _dismissCctvAlert(_CctvBoardAlert alert) {
    final replacementAlert = _availableCctvAlerts(excludingAlertId: alert.id)
        .cast<_CctvBoardAlert?>()
        .firstWhere(
          (candidate) => candidate != null && candidate.feedId == alert.feedId,
          orElse: () => null,
        );
    setState(() {
      _dismissedCctvAlertIds.add(alert.id);
      if (_selectedCctvAlertId == alert.id) {
        _selectedCctvAlertId = replacementAlert?.id;
        if (_selectedCctvFeedId == alert.feedId && replacementAlert == null) {
          _selectedCctvFeedId = null;
        }
      }
    });
  }

  List<_CctvBoardAlert> _seedCctvAlerts() {
    final cameraLabels = <String>[
      'CAM-03 - North Gate',
      'CAM-07 - South Lot',
      'CAM-02 - East Fence',
      'CAM-05 - Main Entrance',
    ];
    return _actions
        .take(3)
        .toList(growable: false)
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final action = entry.value;
          final cameraLabel = cameraLabels[index % cameraLabels.length];
          return _CctvBoardAlert(
            id: action.id,
            headline: _cctvHeadlineForAction(action, index),
            summary: _cctvSummaryForAction(action),
            siteLabel: _humanizeCctvLabel(action.site),
            cameraLabel: cameraLabel,
            feedId: _cctvFeedIdFromCameraLabel(cameraLabel),
            occurredLabel: _formatCctvTime(
              DateTime.now().subtract(Duration(minutes: 2 + (index * 3))),
            ),
            priority: action.incidentPriority,
          );
        })
        .toList(growable: false);
  }

  String _cctvHeadlineForAction(_AiQueueAction action, int index) {
    final normalizedType = action.actionType.trim().toUpperCase();
    if (normalizedType.contains('VISION')) {
      return 'Suspicious Movement';
    }
    if (normalizedType.contains('AUTO-DISPATCH')) {
      return 'Restricted Zone Breach';
    }
    if (normalizedType.contains('VOIP')) {
      return 'Loitering Detected';
    }
    if (normalizedType.contains(widget.videoOpsLabel.toUpperCase())) {
      return 'AI Alert';
    }
    return switch (index) {
      0 => 'Loitering Detected',
      1 => 'Suspicious Movement',
      _ => 'Perimeter Watch',
    };
  }

  String _cctvSummaryForAction(_AiQueueAction action) {
    final description = action.description.trim();
    if (description.isNotEmpty) {
      return description;
    }
    return 'ONYX flagged unusual activity for controller review.';
  }

  String _cctvFeedIdFromCameraLabel(String cameraLabel) {
    final dashIndex = cameraLabel.indexOf(' - ');
    if (dashIndex <= 0) {
      return cameraLabel.trim();
    }
    return cameraLabel.substring(0, dashIndex).trim();
  }

  String _formatCctvTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _humanizeCctvLabel(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return 'Sandton Estate North';
    }
    return trimmed
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')
        .split(RegExp(r'\s+'))
        .where((segment) => segment.isNotEmpty)
        .map(
          (segment) =>
              segment.substring(0, 1).toUpperCase() +
              segment.substring(1).toLowerCase(),
        )
        .join(' ');
  }

  Widget _heroHeader(
    BuildContext context, {
    required bool compact,
    required int totalQueueCount,
    required bool showOverviewToggle,
    required String agentIncidentReference,
    required VoidCallback? onOpenAgent,
    Widget? workspaceBanner,
  }) {
    final activeAction = _activeAction;
    final canOpenEvents =
        activeAction != null &&
        widget.onOpenEventsForScope != null &&
        _eventIdsForAction(activeAction).isNotEmpty;
    final openEventsAction = canOpenEvents ? activeAction : null;
    final titleBlock = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 19.5,
          height: 19.5,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5.4),
            gradient: const LinearGradient(
              colors: [
                OnyxColorTokens.accentPurple,
                OnyxColorTokens.accentPurple,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Icon(
            Icons.psychology_alt_rounded,
            color: OnyxColorTokens.textPrimary,
            size: 10.4,
          ),
        ),
        const SizedBox(width: 3.0),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI Automation Queue',
                style: GoogleFonts.inter(
                  color: OnyxColorTokens.surfaceElevated,
                  fontSize: compact ? 12.2 : 13.0,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 1.0),
              Text(
                'AI flags what matters, ranks the risk, and waits 30s for your override.',
                style: GoogleFonts.inter(
                  color: OnyxColorTokens.textMuted,
                  fontSize: 6.8,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    final actions = Wrap(
      spacing: 1.25,
      runSpacing: 1.25,
      alignment: WrapAlignment.end,
      children: [
        if (showOverviewToggle)
          _heroActionButton(
            key: const ValueKey('ai-queue-toggle-detailed-workspace'),
            icon: Icons.visibility_off_rounded,
            label: 'Hide Detailed Workspace',
            accent: OnyxColorTokens.accentSky,
            onPressed: () {
              setState(() {
                _showDetailedWorkspace = false;
              });
            },
          ),
        _heroActionButton(
          key: const ValueKey('ai-queue-view-events-button'),
          icon: Icons.open_in_new,
          label: 'View Events',
          accent: OnyxColorTokens.accentSky.withValues(alpha: 0.75),
          onPressed: openEventsAction == null
              ? null
              : () => _openEventsForAction(openEventsAction),
        ),
        _heroActionButton(
          key: const ValueKey('ai-queue-open-agent-button'),
          icon: Icons.psychology_alt_rounded,
          label: 'Ask Agent',
          accent: OnyxColorTokens.accentPurple,
          onPressed: agentIncidentReference.isEmpty ? null : onOpenAgent,
        ),
        _heroStatusChip(
          label: _queuePaused ? 'AI Engine Paused' : 'AI Engine Active',
          accent: _queuePaused
              ? OnyxColorTokens.accentAmber
              : OnyxColorTokens.accentGreen,
        ),
        _heroCountCard(
          label: 'Total Queue',
          value: '$totalQueueCount',
          accent: OnyxColorTokens.surfaceInset,
        ),
      ],
    );
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleBlock,
          const SizedBox(height: 1.25),
          actions,
          if (workspaceBanner != null) ...[
            const SizedBox(height: 1.25),
            workspaceBanner,
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 1.0),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 148),
              child: actions,
            ),
          ],
        ),
        if (workspaceBanner != null) ...[
          const SizedBox(height: 1.25),
          workspaceBanner,
        ],
      ],
    );
  }

  Widget _heroStatusChip({required String label, required Color accent}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3.1, vertical: 1.35),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4.0,
            height: 4.0,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 3.0),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              color: accent,
              fontSize: 6.0,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroCountCard({
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(2.7, 1.7, 2.7, 1.7),
      decoration: BoxDecoration(
        color: OnyxColorTokens.surfaceInset,
        borderRadius: BorderRadius.circular(5.5),
        border: Border.all(color: OnyxColorTokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textMuted,
              fontSize: 6.0,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 0.45),
          Text(
            value,
            style: GoogleFonts.inter(
              color: accent,
              fontSize: 7.9,
              fontWeight: FontWeight.w800,
              height: 0.95,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroActionButton({
    required Key key,
    required IconData icon,
    required String label,
    required Color accent,
    required VoidCallback? onPressed,
  }) {
    return FilledButton.tonalIcon(
      key: key,
      onPressed: onPressed,
      icon: Icon(icon, size: 9.4),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: accent.withValues(alpha: 0.12),
        foregroundColor: accent,
        disabledBackgroundColor: OnyxColorTokens.surfaceInset,
        disabledForegroundColor: OnyxColorTokens.textMuted.withValues(
          alpha: 0.40,
        ),
        side: BorderSide(color: accent.withValues(alpha: 0.28)),
        padding: const EdgeInsets.symmetric(horizontal: 2.9, vertical: 1.7),
        textStyle: GoogleFonts.inter(
          fontSize: 6.5,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.0)),
      ),
    );
  }

  Widget _queueSnapshotStrip({
    required List<_AiQueueAction> queuedActions,
    required List<_AiQueueAction> nextShiftDrafts,
    required List<MonitoringGlobalSitePosture> moShadowSites,
    required _AiQueueFocusItem? selectedFocus,
    required _AiQueueLaneFilter effectiveLane,
    required bool compactPresentation,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final selectedCard = _selectedFocusSnapshotCard(
          selectedFocus: selectedFocus,
          effectiveLane: effectiveLane,
          compactPresentation: compactPresentation,
        );
        final countsCard = _queueCountsSnapshotCard(
          queuedCount: queuedActions.length,
          draftCount: nextShiftDrafts.length,
          shadowCount: moShadowSites.length,
          compactPresentation: compactPresentation,
        );
        if (constraints.maxWidth < 900) {
          return Column(
            children: [selectedCard, const SizedBox(height: 1.35), countsCard],
          );
        }
        return Row(
          children: [
            Expanded(flex: 18, child: selectedCard),
            const SizedBox(width: 0.85),
            Expanded(flex: 4, child: countsCard),
          ],
        );
      },
    );
  }

  Widget _queueCountsSnapshotCard({
    required int queuedCount,
    required int draftCount,
    required int shadowCount,
    required bool compactPresentation,
  }) {
    final items = [
      (
        label: 'Queued',
        value: '$queuedCount',
        accent: OnyxColorTokens.accentCyan,
      ),
      (
        label: 'Drafts',
        value: '$draftCount',
        accent: OnyxColorTokens.accentSky,
      ),
      (
        label: 'Shadow Sites',
        value: '$shadowCount',
        accent: OnyxColorTokens.accentSky,
      ),
    ];
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compactPresentation ? 1.35 : 1.7),
      decoration: BoxDecoration(
        color: OnyxColorTokens.surfaceInset,
        borderRadius: BorderRadius.circular(5.0),
        border: Border.all(color: OnyxColorTokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QUEUE SNAPSHOT',
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textMuted,
              fontSize: 5.8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 0.85),
          Row(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                Expanded(
                  child: _snapshotCountMetric(
                    label: items[i].label,
                    value: items[i].value,
                    accent: items[i].accent,
                    compactPresentation: compactPresentation,
                  ),
                ),
                if (i != items.length - 1) const SizedBox(width: 0.85),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _snapshotCountMetric({
    required String label,
    required String value,
    required Color accent,
    required bool compactPresentation,
  }) {
    return Container(
      padding: EdgeInsets.all(compactPresentation ? 1.15 : 1.35),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              color: accent,
              fontSize: 5.6,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 0.45),
          Text(
            value,
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textPrimary,
              fontSize: compactPresentation ? 10.4 : 10.8,
              fontWeight: FontWeight.w700,
              height: 0.92,
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectedFocusSnapshotCard({
    required _AiQueueFocusItem? selectedFocus,
    required _AiQueueLaneFilter effectiveLane,
    required bool compactPresentation,
  }) {
    final accent = selectedFocus?.accent ?? _laneAccent(effectiveLane);
    final headline = selectedFocus?.primaryLabel ?? 'Board clear';
    final summary =
        selectedFocus?.summary ??
        'The board is quiet for now, but runbook, policy, and context stay armed for the next signal.';
    final laneRecovery =
        selectedFocus != null && selectedFocus.lane != effectiveLane
        ? selectedFocus.lane
        : null;
    final canPromoteSelected =
        selectedFocus?.action != null &&
        selectedFocus!.action!.status == _AiActionStatus.pending;
    final canOpenScope = _canOpenEventsForFocus(selectedFocus);

    return Container(
      key: const ValueKey('ai-queue-overview-selected-card'),
      padding: EdgeInsets.all(compactPresentation ? 1.35 : 1.55),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.12),
            OnyxColorTokens.backgroundSecondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(4.9),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: compactPresentation ? 11 : 13,
                height: compactPresentation ? 11 : 13,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(3.4),
                ),
                child: Icon(
                  selectedFocus?.shadowSite != null
                      ? Icons.visibility_outlined
                      : Icons.auto_awesome_rounded,
                  color: accent,
                  size: compactPresentation ? 6.8 : 7.4,
                ),
              ),
              const SizedBox(width: 2.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI OPINION',
                      style: GoogleFonts.inter(
                        color: accent,
                        fontSize: 5.6,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.85,
                      ),
                    ),
                  ],
                ),
              ),
              if (selectedFocus != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2.2,
                    vertical: 1.05,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: accent.withValues(alpha: 0.34)),
                  ),
                  child: Text(
                    'FOCUS',
                    style: GoogleFonts.inter(
                      color: accent,
                      fontSize: 5.6,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: compactPresentation ? 0.5 : 0.75),
          Text(
            headline,
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textPrimary,
              fontSize: compactPresentation ? 9.0 : 9.5,
              fontWeight: FontWeight.w700,
              height: 0.95,
            ),
          ),
          const SizedBox(height: 0.5),
          Text(
            summary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textMuted,
              fontSize: compactPresentation ? 5.8 : 6.0,
              fontWeight: FontWeight.w600,
              height: 1.26,
            ),
          ),
          const SizedBox(height: 0.5),
          Wrap(
            spacing: 1.05,
            runSpacing: 1.05,
            children: [
              if (laneRecovery != null)
                _workspaceStatusAction(
                  key: const ValueKey('ai-queue-overview-selected-open-lane'),
                  label: 'Open ${_laneLabel(laneRecovery)}',
                  selected: false,
                  accent: _laneAccent(laneRecovery),
                  onTap: () => _focusLane(
                    laneRecovery,
                    preferredFocusId: selectedFocus!.id,
                  ),
                ),
              _workspaceStatusAction(
                key: const ValueKey('ai-queue-overview-selected-open-policy'),
                label: 'Policy',
                selected: _workspaceView == _AiQueueWorkspaceView.policy,
                accent: _workspaceAccent(_AiQueueWorkspaceView.policy),
                onTap: () => _setWorkspaceView(_AiQueueWorkspaceView.policy),
              ),
              _workspaceStatusAction(
                key: const ValueKey('ai-queue-overview-selected-open-context'),
                label: 'Context',
                selected: _workspaceView == _AiQueueWorkspaceView.context,
                accent: _workspaceAccent(_AiQueueWorkspaceView.context),
                onTap: () => _setWorkspaceView(_AiQueueWorkspaceView.context),
              ),
              if (canPromoteSelected)
                _workspaceStatusAction(
                  key: const ValueKey('ai-queue-overview-selected-promote'),
                  label: 'Promote',
                  selected: false,
                  accent: OnyxColorTokens.accentSky,
                  onTap: () => _promoteAction(selectedFocus.action!.id),
                )
              else if (canOpenScope)
                _workspaceStatusAction(
                  key: const ValueKey('ai-queue-overview-selected-open-scope'),
                  label: selectedFocus?.shadowSite != null
                      ? 'Open Evidence'
                      : 'Open Event Scope',
                  selected: false,
                  accent: OnyxColorTokens.accentSky,
                  onTap: () => _openEventsForFocus(selectedFocus!),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _workspaceStatusBanner({
    required _AiQueueAction? activeAction,
    required _AiQueueFocusItem? selectedFocus,
    required _AiQueueLaneFilter effectiveLane,
    bool summaryOnly = false,
    bool shellless = false,
  }) {
    final focusToken = selectedFocus == null
        ? 'Standby'
        : selectedFocus.action != null
        ? selectedFocus.action!.incidentId
        : selectedFocus.shadowSite!.siteId;
    final focusCard = _selectedFocusSnapshotCard(
      selectedFocus: selectedFocus,
      effectiveLane: effectiveLane,
      compactPresentation: true,
    );

    final bannerContent = LayoutBuilder(
      builder: (context, constraints) {
        final showInlineFocusCard = constraints.maxWidth >= 1180;
        final controls = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 1.2,
              runSpacing: 1.2,
              children: [
                _workspaceStatusPill(
                  label: _queuePaused ? 'Engine paused' : 'Engine active',
                  accent: _queuePaused
                      ? OnyxColorTokens.accentAmber
                      : OnyxColorTokens.accentGreen,
                ),
                _workspaceStatusPill(
                  label: 'Lane ${_laneLabel(effectiveLane)}',
                  accent: _laneAccent(effectiveLane),
                ),
                _workspaceStatusPill(
                  label: focusToken,
                  accent: selectedFocus?.accent ?? OnyxColorTokens.accentSky,
                ),
                if (activeAction != null)
                  _workspaceStatusPill(
                    label:
                        'Live ${_formatTime(activeAction.timeUntilExecutionSeconds)}',
                    accent: OnyxColorTokens.accentCyan,
                  ),
              ],
            ),
            const SizedBox(height: 0.1),
            Text(
              'Lane pivots stay pinned in the queue rail, while runbook, policy, context, promote, pause, and scope actions stay anchored to the selected automation board below.',
              style: GoogleFonts.inter(
                color: OnyxColorTokens.textMuted,
                fontSize: 6.2,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
        );

        if (summaryOnly) {
          return controls;
        }

        if (showInlineFocusCard) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: controls),
              const SizedBox(width: 1.0),
              SizedBox(width: 118, child: focusCard),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [controls, const SizedBox(height: 0.9), focusCard],
        );
      },
    );
    if (shellless) {
      return KeyedSubtree(
        key: const ValueKey('ai-queue-workspace-status-banner'),
        child: bannerContent,
      );
    }
    return Container(
      key: const ValueKey('ai-queue-workspace-status-banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(1.1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4.9),
        gradient: const LinearGradient(
          colors: [
            OnyxColorTokens.backgroundSecondary,
            OnyxColorTokens.surfaceElevated,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: OnyxColorTokens.divider),
        boxShadow: [
          BoxShadow(
            color: OnyxColorTokens.backgroundPrimary.withValues(alpha: 0.07),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: bannerContent,
    );
  }

  Widget _workspaceStatusPill({required String label, required Color accent}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 1.8, vertical: 1.05),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.38)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: accent,
          fontSize: 6.0,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _workspaceStatusAction({
    required Key key,
    required String label,
    required bool selected,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 1.8, vertical: 1.05),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.18)
              : OnyxColorTokens.backgroundSecondary,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.5)
                : OnyxColorTokens.divider,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: selected ? accent : OnyxColorTokens.textPrimary,
            fontSize: 6.0,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _automationWorkspace({
    required _AiQueueAction? activeAction,
    required List<_AiQueueAction> queuedActions,
    required List<_AiQueueAction> nextShiftDrafts,
    required List<MonitoringGlobalSitePosture> moShadowSites,
    required List<_AiQueueFocusItem> focusItems,
    required List<_AiQueueFocusItem> laneItems,
    required _AiQueueFocusItem? selectedFocus,
    required _AiQueueLaneFilter effectiveLane,
    required bool useWideLayout,
    required bool useEmbeddedPanels,
    required bool compact,
  }) {
    final laneWidth = useEmbeddedPanels ? 144.0 : 152.0;
    final contextRailWidth = useEmbeddedPanels ? 154.0 : 162.0;
    final workspaceGap = 0.3;
    final laneRail = _laneRail(
      focusItems: focusItems,
      laneItems: laneItems,
      effectiveLane: effectiveLane,
      useExpandedBody: useEmbeddedPanels,
      shadowCount: moShadowSites.length,
    );
    final selectedBoard = _selectedAutomationBoard(
      selectedFocus: selectedFocus,
      activeAction: activeAction,
      queuedActions: queuedActions,
      nextShiftDrafts: nextShiftDrafts,
      moShadowSites: moShadowSites,
      compact: compact,
      useExpandedBody: useEmbeddedPanels,
    );
    final contextRail = _workspaceContextRail(
      activeAction: activeAction,
      queuedActions: queuedActions,
      nextShiftDrafts: nextShiftDrafts,
      moShadowSites: moShadowSites,
      selectedFocus: selectedFocus,
      compact: compact,
      useExpandedBody: useEmbeddedPanels,
      useWideLayout: useWideLayout,
    );

    if (useWideLayout) {
      return Row(
        crossAxisAlignment: useEmbeddedPanels
            ? CrossAxisAlignment.stretch
            : CrossAxisAlignment.start,
        children: [
          SizedBox(width: laneWidth, child: laneRail),
          SizedBox(width: workspaceGap),
          Expanded(child: selectedBoard),
          SizedBox(width: workspaceGap),
          SizedBox(width: contextRailWidth, child: contextRail),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        laneRail,
        const SizedBox(height: 2.0),
        selectedBoard,
        const SizedBox(height: 2.0),
        contextRail,
      ],
    );
  }

  Widget _laneRail({
    required List<_AiQueueFocusItem> focusItems,
    required List<_AiQueueFocusItem> laneItems,
    required _AiQueueLaneFilter effectiveLane,
    required bool useExpandedBody,
    required int shadowCount,
  }) {
    final list = laneItems.isEmpty
        ? _emptyLaneState(
            totalQueueCount: _actions.length,
            queuedCount: _displayQueuedActions.length,
            draftCount: _nextShiftDrafts.length,
            shadowCount: shadowCount,
          )
        : ListView.separated(
            shrinkWrap: !useExpandedBody,
            primary: false,
            padding: EdgeInsets.zero,
            physics: useExpandedBody
                ? null
                : const NeverScrollableScrollPhysics(),
            itemCount: laneItems.length,
            separatorBuilder: (context, index) => const SizedBox(height: 5),
            itemBuilder: (context, index) {
              final item = laneItems[index];
              return _focusCard(item, isSelected: item.id == _selectedFocusId);
            },
          );

    return Container(
      padding: const EdgeInsets.all(2.6),
      decoration: onyxWorkspaceSurfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Queue Lanes',
            style: GoogleFonts.inter(
              color: OnyxColorTokens.surfaceInset,
              fontSize: 10.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2.0),
          Text(
            'Pick the live lane, queued stack, next-shift drafts, or shadow posture signals.',
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textMuted,
              fontSize: 6.3,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 1.0),
          Wrap(
            spacing: 2.0,
            runSpacing: 2.0,
            children: _AiQueueLaneFilter.values
                .map((lane) => _laneChip(lane, focusItems, effectiveLane))
                .toList(),
          ),
          const SizedBox(height: 1.0),
          if (useExpandedBody) Expanded(child: list) else list,
        ],
      ),
    );
  }

  Widget _laneChip(
    _AiQueueLaneFilter lane,
    List<_AiQueueFocusItem> focusItems,
    _AiQueueLaneFilter effectiveLane,
  ) {
    final selected = lane == effectiveLane;
    final accent = _laneAccent(lane);
    final count = focusItems.where((item) => item.lane == lane).length;
    return InkWell(
      key: ValueKey('ai-queue-lane-${lane.name}'),
      onTap: () => _focusLane(lane, focusItems: focusItems),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 3.6, vertical: 1.6),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.16)
              : OnyxColorTokens.backgroundSecondary,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.42)
                : OnyxColorTokens.divider,
          ),
        ),
        child: Text(
          '${_laneLabel(lane)} $count',
          style: GoogleFonts.inter(
            color: selected ? accent : OnyxColorTokens.textMuted,
            fontSize: 6.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _emptyLaneState({
    required int totalQueueCount,
    required int queuedCount,
    required int draftCount,
    required int shadowCount,
  }) {
    return _workspaceRecoveryDeck(
      key: const ValueKey('ai-queue-empty-lane-recovery'),
      eyebrow: 'LANE CLEAR',
      title: 'No automation is staged in this rail.',
      summary:
          'The lane shell stays armed so you can keep the workspace oriented while policy, runbook, and context views remain one tap away.',
      accent: OnyxColorTokens.accentSky,
      metrics: _standbyWorkspaceMetrics(
        totalQueueCount: totalQueueCount,
        queuedCount: queuedCount,
        draftCount: draftCount,
        shadowCount: shadowCount,
      ),
      actions: _standbyWorkspaceActions(prefix: 'ai-queue-empty-lane'),
    );
  }

  Widget _focusCard(_AiQueueFocusItem item, {required bool isSelected}) {
    return InkWell(
      key: ValueKey('ai-queue-focus-card-${item.id}'),
      onTap: () => _focusItem(item),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(3.25),
        decoration: onyxSelectableRowSurfaceDecoration(isSelected: isSelected),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 2.5),
                  decoration: BoxDecoration(
                    color: item.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.primaryLabel,
                        style: GoogleFonts.inter(
                          color: OnyxColorTokens.surfaceInset,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.secondaryLabel,
                        style: GoogleFonts.inter(
                          color: OnyxColorTokens.textMuted,
                          fontSize: 7.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: OnyxColorTokens.accentSky.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: OnyxColorTokens.accentSky.withValues(
                          alpha: 0.25,
                        ),
                      ),
                    ),
                    child: Text(
                      'FOCUS',
                      style: GoogleFonts.inter(
                        color: OnyxColorTokens.accentSky,
                        fontSize: 7,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2.5),
            Wrap(
              spacing: 3,
              runSpacing: 3,
              children: item.chips
                  .map((chip) => _detailChip(chip.$1, chip.$2, accent: chip.$3))
                  .toList(),
            ),
            const SizedBox(height: 2.5),
            Text(
              item.summary,
              style: GoogleFonts.inter(
                color: OnyxColorTokens.textMuted,
                fontSize: 7.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailChip(String label, String value, {required Color accent}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.34)),
      ),
      child: Text(
        '$label $value',
        style: GoogleFonts.inter(
          color: accent,
          fontSize: 7,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _selectedAutomationBoard({
    required _AiQueueFocusItem? selectedFocus,
    required _AiQueueAction? activeAction,
    required List<_AiQueueAction> queuedActions,
    required List<_AiQueueAction> nextShiftDrafts,
    required List<MonitoringGlobalSitePosture> moShadowSites,
    required bool compact,
    required bool useExpandedBody,
  }) {
    final panel = switch (_workspaceView) {
      _AiQueueWorkspaceView.runbook => _runbookPanel(
        selectedFocus,
        compact: compact,
        totalQueueCount: _actions.length,
        queuedCount: _displayQueuedActions.length,
        draftCount: _nextShiftDrafts.length,
        shadowCount: moShadowSites.length,
        useExpandedBody: useExpandedBody,
      ),
      _AiQueueWorkspaceView.policy => _policyPanel(
        selectedFocus,
        queuedActions: queuedActions,
        nextShiftDrafts: nextShiftDrafts,
        moShadowSites: moShadowSites,
        totalQueueCount: _actions.length,
        shadowCount: moShadowSites.length,
        useExpandedBody: useExpandedBody,
      ),
      _AiQueueWorkspaceView.context => _contextPanel(
        selectedFocus,
        activeAction: activeAction,
        queuedActions: queuedActions,
        nextShiftDrafts: nextShiftDrafts,
        moShadowSites: moShadowSites,
        useExpandedBody: useExpandedBody,
      ),
    };
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: onyxWorkspaceSurfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selected Automation',
            style: GoogleFonts.inter(
              color: OnyxColorTokens.surfaceInset,
              fontSize: 11.0,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 1.7),
          Text(
            'A focused execution board for the selected queue item, policy signal, or shadow dossier.',
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textMuted,
              fontSize: 6.6,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 0.9),
          _focusBanner(
            selectedFocus,
            totalQueueCount: _actions.length,
            queuedCount: _displayQueuedActions.length,
            draftCount: _nextShiftDrafts.length,
            shadowCount: moShadowSites.length,
          ),
          const SizedBox(height: 0.9),
          Wrap(
            spacing: 1.7,
            runSpacing: 1.7,
            children: _AiQueueWorkspaceView.values
                .map((view) => _workspaceChip(view))
                .toList(),
          ),
          const SizedBox(height: 1.7),
          if (useExpandedBody) Expanded(child: panel) else panel,
        ],
      ),
    );
  }

  Widget _focusBanner(
    _AiQueueFocusItem? selectedFocus, {
    required int totalQueueCount,
    required int queuedCount,
    required int draftCount,
    required int shadowCount,
  }) {
    if (selectedFocus == null) {
      return _workspaceRecoveryDeck(
        key: const ValueKey('ai-queue-focus-standby-recovery'),
        eyebrow: 'WORKSPACE STANDBY',
        title: 'Board clear. Nothing hot is pinned.',
        summary:
            'Standby supervision is still armed. Reset the live lane or pivot to policy and context without leaving the board.',
        accent: OnyxColorTokens.accentSky,
        metrics: _standbyWorkspaceMetrics(
          totalQueueCount: totalQueueCount,
          queuedCount: queuedCount,
          draftCount: draftCount,
          shadowCount: shadowCount,
        ),
        actions: _standbyWorkspaceActions(prefix: 'ai-queue-focus-standby'),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(1.7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            selectedFocus.accent.withValues(alpha: 0.18),
            OnyxColorTokens.surfaceInset,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(5.2),
        border: Border.all(color: selectedFocus.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACTIVE WORKSPACE FOCUS',
            style: GoogleFonts.inter(
              color: selectedFocus.accent,
              fontSize: 6.2,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 0.6),
          Text(
            selectedFocus.headline,
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textPrimary,
              fontSize: 11.0,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 0.6),
          Text(
            selectedFocus.bannerSummary,
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textMuted,
              fontSize: 6.9,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1.15),
          Wrap(
            spacing: 1.7,
            runSpacing: 1.7,
            children: [
              _detailChip(
                'Lane',
                _laneLabel(selectedFocus.lane),
                accent: _laneAccent(selectedFocus.lane),
              ),
              if (selectedFocus.action != null)
                _detailChip(
                  'Priority',
                  _priorityStyle(selectedFocus.action!.incidentPriority).label,
                  accent: _priorityStyle(
                    selectedFocus.action!.incidentPriority,
                  ).foreground,
                ),
              if (selectedFocus.action != null)
                _detailChip(
                  'ETA',
                  _formatTime(selectedFocus.action!.timeUntilExecutionSeconds),
                  accent: OnyxColorTokens.accentCyan,
                ),
              if (selectedFocus.shadowSite != null)
                _detailChip(
                  'Matches',
                  '${selectedFocus.shadowSite!.moShadowMatchCount}',
                  accent: OnyxColorTokens.accentSky,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _workspaceChip(_AiQueueWorkspaceView view) {
    final selected = _workspaceView == view;
    final accent = _workspaceAccent(view);
    return InkWell(
      key: ValueKey('ai-queue-workspace-view-${view.name}'),
      onTap: () => _setWorkspaceView(view),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.16)
              : OnyxColorTokens.backgroundSecondary,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.45)
                : OnyxColorTokens.divider,
          ),
        ),
        child: Text(
          _workspaceLabel(view),
          style: GoogleFonts.inter(
            color: selected ? accent : OnyxColorTokens.textMuted,
            fontSize: 7.3,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _runbookPanel(
    _AiQueueFocusItem? selectedFocus, {
    required bool compact,
    required int totalQueueCount,
    required int queuedCount,
    required int draftCount,
    required int shadowCount,
    required bool useExpandedBody,
  }) {
    Widget child;
    if (selectedFocus == null) {
      child = _automationStandbyCard(
        totalQueueCount: totalQueueCount,
        queuedCount: queuedCount,
        draftCount: draftCount,
        shadowCount: shadowCount,
      );
    } else if (selectedFocus.action != null) {
      final action = selectedFocus.action!;
      if (action.status == _AiActionStatus.executing ||
          action.status == _AiActionStatus.paused) {
        child = _activeAutomationCard(action, compact: compact);
      } else {
        child = _queuedAutomationWorkspaceCard(
          action,
          isDraft: _isNextShiftDraft(action),
        );
      }
    } else {
      child = _shadowWorkspaceCard(selectedFocus.shadowSite!);
    }
    if (useExpandedBody) {
      return ListView(
        key: const ValueKey('ai-queue-workspace-panel-runbook'),
        primary: false,
        padding: EdgeInsets.zero,
        children: [child],
      );
    }
    return SingleChildScrollView(
      key: const ValueKey('ai-queue-workspace-panel-runbook'),
      child: child,
    );
  }

  Widget _queuedAutomationWorkspaceCard(
    _AiQueueAction action, {
    required bool isDraft,
  }) {
    final promotionPressureSummary = _promotionPressureSummary(action.metadata);
    final promotionExecutionSummary = _promotionExecutionSummary(
      action.metadata,
    );
    final eventIds = _eventIdsForAction(action);
    final canOpenEvents =
        widget.onOpenEventsForScope != null && eventIds.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(border: OnyxColorTokens.surfaceElevated),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: OnyxColorTokens.accentCyan.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isDraft ? Icons.upcoming_rounded : Icons.schedule_rounded,
                  color: OnyxColorTokens.accentCyan,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDraft ? 'NEXT-SHIFT DRAFT' : 'QUEUED ACTION',
                      style: GoogleFonts.inter(
                        color: OnyxColorTokens.surfaceInset,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isDraft
                          ? 'Draft carry-forward is staged for the next operator window.'
                          : 'Awaiting promotion into the active autonomy slot.',
                      style: GoogleFonts.inter(
                        color: OnyxColorTokens.textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _actionTypePill(action.actionType),
            ],
          ),
          const SizedBox(height: 12),
          _activeAutomationMetrics(
            incidentId: action.incidentId,
            site: action.site,
            officer: action.metadata['officer'] ?? 'Queue hold',
            eta:
                action.metadata['eta'] ??
                _formatTime(action.timeUntilExecutionSeconds),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: OnyxColorTokens.backgroundPrimary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: OnyxColorTokens.surfaceElevated),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PROPOSED ACTION',
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.accentCyan,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  action.description,
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.surfaceInset,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  children: [
                    _detailCell(
                      'Queue status',
                      isDraft ? 'Drafted' : 'Pending',
                    ),
                    if ((action.metadata['scope'] ?? '').trim().isNotEmpty)
                      _detailCell(
                        'Scope mode',
                        action.metadata['scope']!.trim(),
                      ),
                    if (promotionPressureSummary.isNotEmpty)
                      _detailCell('Pressure cue', promotionPressureSummary),
                    if (promotionExecutionSummary.isNotEmpty)
                      _detailCell('Execution cue', promotionExecutionSummary),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Promote this action to active execution, approve it immediately, or remove it from the queue.',
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _actionButton(
                label: 'CANCEL ACTION',
                icon: Icons.cancel_rounded,
                background: OnyxColorTokens.accentRed,
                onPressed: () => _cancelAction(action.id),
              ),
              FilledButton.icon(
                key: const ValueKey('ai-queue-workspace-promote-action'),
                onPressed: () => _promoteAction(action.id),
                icon: const Icon(Icons.bolt_rounded, size: 18),
                style: FilledButton.styleFrom(
                  backgroundColor: OnyxColorTokens.accentSky,
                  foregroundColor: OnyxColorTokens.surfaceInset,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                  textStyle: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
                label: const Text('PROMOTE NOW'),
              ),
              _actionButton(
                label: 'APPROVE NOW',
                icon: Icons.check_circle_rounded,
                background: OnyxColorTokens.accentGreen,
                onPressed: () => _approveAction(action.id),
              ),
              if (canOpenEvents)
                OutlinedButton.icon(
                  key: const ValueKey('ai-queue-workspace-open-event-scope'),
                  onPressed: () => _openEventsForAction(action),
                  icon: const Icon(Icons.alt_route_rounded, size: 18),
                  label: const Text('OPEN EVENT SCOPE'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _shadowWorkspaceCard(MonitoringGlobalSitePosture site) {
    final eventIds = site.moShadowEventIds;
    final canOpenEvidence =
        widget.onOpenEventsForScope != null && eventIds.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(
        border: OnyxColorTokens.accentSky.withValues(alpha: 0.40),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SHADOW DOSSIER FOCUS',
            style: GoogleFonts.inter(
              color: OnyxColorTokens.surfaceInset,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${site.siteId} • ${site.moShadowSummary}',
            style: GoogleFonts.inter(
              color: OnyxColorTokens.surfaceInset,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: [
              _detailCell('Lead site', site.siteId),
              _detailCell('Signal family', 'mo_shadow'),
              _detailCell('Matched cues', '${site.moShadowMatchCount}'),
              _detailCell(
                'Strength summary',
                shadowMoPostureStrengthSummary(site),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (site.moShadowMatches.isEmpty)
            Text(
              'No matched dossier entries are available for this site yet.',
              style: GoogleFonts.inter(
                color: OnyxColorTokens.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: site.moShadowMatches.take(3).expand((match) {
                return <Widget>[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: OnyxColorTokens.backgroundSecondary,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: OnyxColorTokens.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          match.title,
                          style: GoogleFonts.inter(
                            color: OnyxColorTokens.accentSky,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Indicators ${match.matchedIndicators.join(', ')}',
                          style: GoogleFonts.inter(
                            color: OnyxColorTokens.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                ];
              }).toList(),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('ai-queue-workspace-open-shadow-dossier'),
                onPressed: () => _showMoShadowDossier([site]),
                icon: const Icon(Icons.visibility_rounded, size: 18),
                label: const Text('OPEN DOSSIER'),
              ),
              if (canOpenEvidence)
                OutlinedButton.icon(
                  key: const ValueKey(
                    'ai-queue-workspace-open-shadow-evidence',
                  ),
                  onPressed: () => widget.onOpenEventsForScope!(
                    eventIds,
                    site.moShadowSelectedEventId,
                  ),
                  icon: const Icon(Icons.alt_route_rounded, size: 18),
                  label: const Text('OPEN EVIDENCE'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _policyPanel(
    _AiQueueFocusItem? selectedFocus, {
    required List<_AiQueueAction> queuedActions,
    required List<_AiQueueAction> nextShiftDrafts,
    required List<MonitoringGlobalSitePosture> moShadowSites,
    required int totalQueueCount,
    required int shadowCount,
    required bool useExpandedBody,
  }) {
    final content = selectedFocus == null
        ? _policyEmptyState(
            totalQueueCount: totalQueueCount,
            queuedCount: queuedActions.length,
            draftCount: nextShiftDrafts.length,
            shadowCount: shadowCount,
          )
        : selectedFocus.action != null
        ? _actionPolicyContent(
            selectedFocus.action!,
            queuedActions: queuedActions,
            nextShiftDrafts: nextShiftDrafts,
            moShadowSites: moShadowSites,
          )
        : _shadowPolicyContent(selectedFocus.shadowSite!);
    return Container(
      key: const ValueKey('ai-queue-workspace-panel-policy'),
      child: _workspacePanelBody(
        content: content,
        useExpandedBody: useExpandedBody,
        shellless: useExpandedBody,
      ),
    );
  }

  Widget _policyEmptyState({
    required int totalQueueCount,
    required int queuedCount,
    required int draftCount,
    required int shadowCount,
  }) {
    return _workspaceRecoveryDeck(
      key: const ValueKey('ai-queue-policy-empty-recovery'),
      eyebrow: 'POLICY STANDBY',
      title: 'Policy panel is waiting for the next focus.',
      summary:
          'Autonomy pressure, execution bias, and lane posture will land here as soon as an automation re-enters the board.',
      accent: OnyxColorTokens.accentGreen,
      metrics: _standbyWorkspaceMetrics(
        totalQueueCount: totalQueueCount,
        queuedCount: queuedCount,
        draftCount: draftCount,
        shadowCount: shadowCount,
      ),
      actions: _standbyWorkspaceActions(prefix: 'ai-queue-policy-empty'),
    );
  }

  Widget _actionPolicyContent(
    _AiQueueAction action, {
    required List<_AiQueueAction> queuedActions,
    required List<_AiQueueAction> nextShiftDrafts,
    required List<MonitoringGlobalSitePosture> moShadowSites,
  }) {
    final promotionPressureSummary = _promotionPressureSummary(action.metadata);
    final promotionExecutionSummary = _promotionExecutionSummary(
      action.metadata,
    );
    final shadowBiasSummary = _shadowPostureBiasSummary(action.metadata);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Policy Signals',
          style: GoogleFonts.inter(
            color: OnyxColorTokens.textPrimary,
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Autonomy pressure, biasing cues, and carry-forward posture for the current focus.',
          style: GoogleFonts.inter(
            color: OnyxColorTokens.textMuted,
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 6),
        if (promotionPressureSummary.isNotEmpty)
          Text(
            'Promotion pressure: $promotionPressureSummary',
            style: GoogleFonts.inter(
              color: OnyxColorTokens.accentGreen,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        if (promotionExecutionSummary.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Promotion execution: $promotionExecutionSummary',
            style: GoogleFonts.inter(
              color: OnyxColorTokens.accentGreen,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (shadowBiasSummary.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Shadow bias in effect: $shadowBiasSummary',
            style: GoogleFonts.inter(
              color: OnyxColorTokens.accentSky,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: [
            _miniPolicyTile(
              'Queue Depth',
              '${queuedActions.length}',
              OnyxColorTokens.accentCyan,
            ),
            _miniPolicyTile(
              'Draft Carry',
              '${nextShiftDrafts.length}',
              OnyxColorTokens.accentSky,
            ),
            _miniPolicyTile(
              'Shadow Sites',
              '${moShadowSites.length}',
              OnyxColorTokens.accentSky,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: OnyxColorTokens.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: OnyxColorTokens.divider),
          ),
          child: Text(
            (action.metadata['scope'] ?? '').trim().toUpperCase() ==
                    'NEXT_SHIFT'
                ? 'This recommendation is currently staged for the next-shift carry-forward lane.'
                : 'This recommendation is held inside the live queue and can be promoted directly into execution.',
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textMuted,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }

  Widget _shadowPolicyContent(MonitoringGlobalSitePosture site) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Shadow Pattern Weighting',
          style: GoogleFonts.inter(
            color: OnyxColorTokens.textPrimary,
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Pattern strength, recommended actions, and evidence density for the selected shadow site.',
          style: GoogleFonts.inter(
            color: OnyxColorTokens.textMuted,
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: [
            _miniPolicyTile(
              'Lead Site',
              site.siteId,
              OnyxColorTokens.accentSky,
            ),
            _miniPolicyTile(
              'Matches',
              '${site.moShadowMatchCount}',
              OnyxColorTokens.accentCyan,
            ),
            _miniPolicyTile(
              'Posture Weight',
              shadowMoPostureStrengthSummary(site),
              OnyxColorTokens.accentSky,
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final match in site.moShadowMatches.take(3)) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: OnyxColorTokens.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: OnyxColorTokens.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  match.title,
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.accentSky,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Actions ${match.recommendedActionPlans.join(' • ')}',
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.textMuted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
        ],
      ],
    );
  }

  Widget _miniPolicyTile(String label, String value, Color accent) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: OnyxColorTokens.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textMuted,
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _contextPanel(
    _AiQueueFocusItem? selectedFocus, {
    required _AiQueueAction? activeAction,
    required List<_AiQueueAction> queuedActions,
    required List<_AiQueueAction> nextShiftDrafts,
    required List<MonitoringGlobalSitePosture> moShadowSites,
    required bool useExpandedBody,
  }) {
    final totalQueueCount =
        (activeAction == null ? 0 : 1) +
        queuedActions.length +
        nextShiftDrafts.length;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Execution Context',
          style: GoogleFonts.inter(
            color: OnyxColorTokens.textPrimary,
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Queue counts, related lanes, and handoffs for the current automation focus.',
          style: GoogleFonts.inter(
            color: OnyxColorTokens.textMuted,
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 5),
        _contextMetric('Live Action', activeAction?.incidentId ?? 'Standby'),
        const SizedBox(height: 5),
        _contextMetric('Queued Stack', '${queuedActions.length}'),
        const SizedBox(height: 5),
        _contextMetric('Draft Carry', '${nextShiftDrafts.length}'),
        const SizedBox(height: 5),
        _contextMetric('Shadow Sites', '${moShadowSites.length}'),
        if (selectedFocus?.action != null) ...[
          const SizedBox(height: 5),
          _contextMetric(
            'Scoped Events',
            '${_eventIdsForAction(selectedFocus!.action!).length}',
          ),
        ],
        const SizedBox(height: 6),
        if (selectedFocus == null)
          _workspaceRecoveryDeck(
            key: const ValueKey('ai-queue-context-standby-recovery'),
            eyebrow: 'CONTEXT READY',
            title: 'Standby supervision is still armed.',
            summary:
                'Use the context rail to reset the live lane or move back into the runbook and policy shells while the queue stays clear.',
            accent: OnyxColorTokens.accentSky,
            metrics: _standbyWorkspaceMetrics(
              totalQueueCount: totalQueueCount,
              queuedCount: queuedActions.length,
              draftCount: nextShiftDrafts.length,
              shadowCount: moShadowSites.length,
            ),
            actions: _standbyWorkspaceActions(
              prefix: 'ai-queue-context-standby',
            ),
          )
        else
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              FilledButton.tonalIcon(
                key: const ValueKey('ai-queue-context-focus-drafts'),
                onPressed: nextShiftDrafts.isEmpty
                    ? null
                    : () => _focusLane(_AiQueueLaneFilter.drafts),
                icon: const Icon(Icons.upcoming_rounded, size: 18),
                label: const Text('Focus Draft Lane'),
              ),
              FilledButton.tonalIcon(
                key: const ValueKey('ai-queue-context-focus-shadow'),
                onPressed: moShadowSites.isEmpty
                    ? null
                    : () => _focusLane(_AiQueueLaneFilter.shadow),
                icon: const Icon(Icons.visibility_rounded, size: 18),
                label: const Text('Focus Shadow Lane'),
              ),
            ],
          ),
      ],
    );
    return Container(
      key: const ValueKey('ai-queue-workspace-panel-context'),
      child: _workspacePanelBody(
        content: content,
        useExpandedBody: useExpandedBody,
        shellless: useExpandedBody,
      ),
    );
  }

  Widget _workspacePanelBody({
    required Widget content,
    required bool useExpandedBody,
    bool shellless = false,
  }) {
    final body = useExpandedBody
        ? ListView(
            primary: false,
            padding: EdgeInsets.zero,
            children: [content],
          )
        : SingleChildScrollView(child: content);
    if (shellless) {
      return body;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: OnyxColorTokens.divider),
      ),
      child: body,
    );
  }

  Widget _contextMetric(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: OnyxColorTokens.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: OnyxColorTokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textMuted,
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textPrimary,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _workspaceCommandReceiptCard() {
    final receipt = _commandReceipt;
    return Container(
      key: const ValueKey('ai-queue-workspace-command-receipt'),
      width: double.infinity,
      padding: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: receipt.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7.4),
        border: Border.all(color: receipt.accent.withValues(alpha: 0.34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LATEST COMMAND',
            style: GoogleFonts.inter(
              color: receipt.accent,
              fontSize: 7.6,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2.2),
          Text(
            receipt.label,
            style: GoogleFonts.inter(
              color: OnyxColorTokens.surfaceInset,
              fontSize: 8.6,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 0.85),
          Text(
            receipt.message,
            style: GoogleFonts.inter(
              color: OnyxColorTokens.surfaceInset,
              fontSize: 8.6,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 2.2),
          Text(
            receipt.detail,
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textMuted,
              fontSize: 7.6,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  bool get _hasPinnedCommandReceipt =>
      _commandReceipt.label == 'AGENT RETURN' ||
      _commandReceipt.label == 'EVIDENCE RETURN';

  void _ingestEvidenceReturnReceipt(
    AiQueueEvidenceReturnReceipt? receipt, {
    bool fromInit = false,
  }) {
    if (receipt == null) {
      return;
    }
    final commandReceipt = _AiQueueCommandReceipt(
      label: receipt.label,
      message: receipt.message,
      detail: receipt.detail,
      accent: receipt.accent,
    );
    if (fromInit) {
      _commandReceipt = commandReceipt;
    } else if (mounted) {
      setState(() {
        _commandReceipt = commandReceipt;
      });
    } else {
      _commandReceipt = commandReceipt;
    }
    widget.onConsumeEvidenceReturnReceipt?.call(receipt.auditId);
  }

  void _ingestAgentReturnIncidentReference({bool fromInit = false}) {
    final ref = (widget.agentReturnIncidentReference ?? '').trim();
    if (ref.isEmpty) {
      return;
    }
    final receipt = _AiQueueCommandReceipt(
      label: 'AGENT RETURN',
      message: 'Returned from Agent for $ref.',
      detail:
          'The CCTV focus stayed pinned so controllers can keep validating the same incident inside the simple queue flow.',
      accent: OnyxColorTokens.accentPurple,
    );
    if (fromInit) {
      _commandReceipt = receipt;
    } else if (mounted) {
      setState(() {
        _commandReceipt = receipt;
      });
    } else {
      _commandReceipt = receipt;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.onConsumeAgentReturnIncidentReference?.call(ref);
    });
  }

  Widget _workspaceContextRail({
    required _AiQueueAction? activeAction,
    required List<_AiQueueAction> queuedActions,
    required List<_AiQueueAction> nextShiftDrafts,
    required List<MonitoringGlobalSitePosture> moShadowSites,
    required _AiQueueFocusItem? selectedFocus,
    required bool compact,
    required bool useExpandedBody,
    required bool useWideLayout,
  }) {
    final children = <Widget>[
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(2.7),
        decoration: onyxWorkspaceSurfaceDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WHY IT FIRED',
              style: GoogleFonts.inter(
                color: OnyxColorTokens.surfaceInset,
                fontSize: 11.0,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 1.0),
            Text(
              'Keep the active lane, the last receipt, and the next queues visible while the workspace changes.',
              style: GoogleFonts.inter(
                color: OnyxColorTokens.textMuted,
                fontSize: 6.8,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 1.7),
            _contextMetric(
              'Current Lane',
              selectedFocus == null
                  ? _laneLabel(_laneFilter)
                  : _laneLabel(selectedFocus.lane),
            ),
          ],
        ),
      ),
      if (useWideLayout || _hasPinnedCommandReceipt) ...[
        const SizedBox(height: 2.2),
        _workspaceCommandReceiptCard(),
      ],
      const SizedBox(height: 2.6),
      if (queuedActions.isNotEmpty) ...[
        _queuedActionsCard(queuedActions),
        const SizedBox(height: 2.2),
      ],
      if (nextShiftDrafts.isNotEmpty) ...[
        _nextShiftDraftsCard(nextShiftDrafts),
        const SizedBox(height: 2.2),
      ],
      if (moShadowSites.isNotEmpty) ...[
        _moShadowCard(moShadowSites),
        const SizedBox(height: 2.2),
      ],
      _todayPerformance(compact: true),
    ];
    if (useExpandedBody) {
      return ListView(
        primary: false,
        padding: EdgeInsets.zero,
        children: children,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _activeAutomationCard(_AiQueueAction action, {required bool compact}) {
    final countdownColor = action.timeUntilExecutionSeconds <= 10
        ? OnyxColorTokens.accentRed
        : action.timeUntilExecutionSeconds <= 20
        ? OnyxColorTokens.accentAmber
        : OnyxColorTokens.accentCyan;
    final progress =
        (action.timeUntilExecutionSeconds /
                action.initialExecutionSeconds.clamp(1, 1 << 20))
            .clamp(0.0, 1.0);
    final paused = action.status == _AiActionStatus.paused;
    final promotionPressureSummary = _promotionPressureSummary(action.metadata);
    final promotionExecutionSummary = _promotionExecutionSummary(
      action.metadata,
    );
    final officer = action.metadata['officer'] ?? 'Echo-3';
    final distance = action.metadata['distance'] ?? '2.4km';
    final eta =
        action.metadata['eta'] ??
        '${(action.timeUntilExecutionSeconds / 60).ceil().clamp(1, 9)}m ${(action.timeUntilExecutionSeconds % 60).toString().padLeft(2, '0')}s';
    final confidence = _confidenceLabel(action);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: _panelDecoration(
        border: OnyxColorTokens.accentCyan.withValues(alpha: 0.40),
        glow: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stackHeader = constraints.maxWidth < 720;
              final headerCopy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    paused ? 'ACTIVE AUTOMATION (PAUSED)' : 'ACTIVE AUTOMATION',
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.surfaceInset,
                      fontSize: compact ? 12.5 : 13.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    paused
                        ? 'Execution hold is active'
                        : 'AI thinks this should happen next • override window live',
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.textMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
              final leadingIcon = Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: OnyxColorTokens.accentCyan.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: OnyxColorTokens.accentCyan,
                  size: 20,
                ),
              );
              if (stackHeader) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        leadingIcon,
                        const SizedBox(width: 7),
                        Expanded(child: headerCopy),
                      ],
                    ),
                    const SizedBox(height: 7),
                    _actionTypePill(action.actionType),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  leadingIcon,
                  const SizedBox(width: 7),
                  Expanded(child: headerCopy),
                  const SizedBox(width: 7),
                  _actionTypePill(action.actionType),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          _activeAutomationMetrics(
            incidentId: action.incidentId,
            site: action.site,
            officer: officer,
            eta: eta,
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: OnyxColorTokens.backgroundPrimary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: OnyxColorTokens.surfaceElevated),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PROPOSED ACTION',
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.accentCyan,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  action.description,
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.surfaceInset,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 760 ? 3 : 1;
                    final cards = [
                      _activeSignalCard(
                        label: 'Officer Status',
                        value: paused ? 'On Hold' : 'Available',
                        accent: OnyxColorTokens.accentSky,
                        icon: Icons.shield_outlined,
                      ),
                      _activeSignalCard(
                        label: 'Distance',
                        value: distance,
                        accent: OnyxColorTokens.accentCyan,
                        icon: Icons.map_outlined,
                      ),
                      _activeSignalCard(
                        label: 'Confidence',
                        value: confidence,
                        accent: OnyxColorTokens.accentGreen,
                        icon: Icons.bolt_rounded,
                      ),
                    ];
                    if (columns == 1) {
                      return Column(
                        children: [
                          for (int i = 0; i < cards.length; i++) ...[
                            cards[i],
                            if (i != cards.length - 1)
                              const SizedBox(height: 7),
                          ],
                        ],
                      );
                    }
                    return Row(
                      children: [
                        for (int i = 0; i < cards.length; i++) ...[
                          Expanded(child: cards[i]),
                          if (i != cards.length - 1) const SizedBox(width: 7),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          if (promotionPressureSummary.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              'Promotion pressure: $promotionPressureSummary',
              style: GoogleFonts.inter(
                color: OnyxColorTokens.accentGreen,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (promotionExecutionSummary.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              'Promotion execution: $promotionExecutionSummary',
              style: GoogleFonts.inter(
                color: OnyxColorTokens.accentGreen,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final timerStack = constraints.maxWidth < 520;
              if (timerStack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'INTERVENTION WINDOW',
                      style: GoogleFonts.inter(
                        color: OnyxColorTokens.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      paused
                          ? 'Execution hold remains active until resumed'
                          : 'Auto-executes when timer reaches zero',
                      style: GoogleFonts.inter(
                        color: OnyxColorTokens.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _formatTime(action.timeUntilExecutionSeconds),
                      style: GoogleFonts.inter(
                        color: countdownColor,
                        fontSize: 32,
                        height: 0.88,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'INTERVENTION WINDOW',
                          style: GoogleFonts.inter(
                            color: OnyxColorTokens.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          paused
                              ? 'Execution hold remains active until resumed'
                              : 'Auto-executes when timer reaches zero',
                          style: GoogleFonts.inter(
                            color: OnyxColorTokens.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatTime(action.timeUntilExecutionSeconds),
                    style: GoogleFonts.inter(
                      color: countdownColor,
                      fontSize: 36,
                      height: 0.88,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: paused ? 0.0 : progress,
              backgroundColor: OnyxColorTokens.backgroundPrimary.withValues(
                alpha: 0.40,
              ),
              valueColor: AlwaysStoppedAnimation<Color>(countdownColor),
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final stackButtons = constraints.maxWidth < 760;
              if (stackButtons) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _actionButton(
                      label: 'CANCEL ACTION',
                      icon: Icons.cancel_rounded,
                      background: OnyxColorTokens.accentRed,
                      onPressed: () => _cancelAction(action.id),
                    ),
                    const SizedBox(height: 5),
                    _actionButton(
                      label: paused ? 'RESUME' : 'PAUSE',
                      icon: paused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      background: OnyxColorTokens.surfaceElevated,
                      onPressed: () => _togglePause(action.id),
                    ),
                    const SizedBox(height: 5),
                    _actionButton(
                      label: 'APPROVE NOW',
                      icon: Icons.check_circle_rounded,
                      background: OnyxColorTokens.accentGreen,
                      onPressed: () => _approveAction(action.id),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      label: 'CANCEL ACTION',
                      icon: Icons.cancel_rounded,
                      background: OnyxColorTokens.accentRed,
                      onPressed: () => _cancelAction(action.id),
                    ),
                  ),
                  const SizedBox(width: 5),
                  _actionButton(
                    label: paused ? 'RESUME' : 'PAUSE',
                    icon: paused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    background: OnyxColorTokens.surfaceElevated,
                    onPressed: () => _togglePause(action.id),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: _actionButton(
                      label: 'APPROVE NOW',
                      icon: Icons.check_circle_rounded,
                      background: OnyxColorTokens.accentGreen,
                      onPressed: () => _approveAction(action.id),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _automationStandbyCard({
    required int totalQueueCount,
    required int queuedCount,
    required int draftCount,
    required int shadowCount,
  }) {
    return _workspaceRecoveryDeck(
      key: const ValueKey('ai-queue-runbook-standby-recovery'),
      eyebrow: 'RUNBOOK STANDBY',
      title: 'Nothing is firing right now.',
      summary:
          'The board is quiet, but the shell stays hot so you can reset the live lane or move straight into policy and context review.',
      accent: OnyxColorTokens.accentCyan,
      metrics: _standbyWorkspaceMetrics(
        totalQueueCount: totalQueueCount,
        queuedCount: queuedCount,
        draftCount: draftCount,
        shadowCount: shadowCount,
      ),
      actions: _standbyWorkspaceActions(prefix: 'ai-queue-runbook-standby'),
    );
  }

  Widget _workspaceRecoveryDeck({
    required Key key,
    required String eyebrow,
    required String title,
    required String summary,
    required Color accent,
    required List<Widget> metrics,
    required List<Widget> actions,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.05),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: GoogleFonts.inter(
              color: accent,
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2.5),
          Text(
            summary,
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          if (metrics.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(spacing: 4, runSpacing: 4, children: metrics),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(spacing: 4, runSpacing: 4, children: actions),
          ],
        ],
      ),
    );
  }

  List<Widget> _standbyWorkspaceMetrics({
    required int totalQueueCount,
    required int queuedCount,
    required int draftCount,
    required int shadowCount,
  }) {
    return [
      _workspaceStatusPill(
        label: 'Total $totalQueueCount',
        accent: OnyxColorTokens.accentPurple,
      ),
      _workspaceStatusPill(
        label: 'Queued $queuedCount',
        accent: OnyxColorTokens.accentSky,
      ),
      _workspaceStatusPill(
        label: 'Drafts $draftCount',
        accent: OnyxColorTokens.accentSky,
      ),
      _workspaceStatusPill(
        label: 'Shadow $shadowCount',
        accent: OnyxColorTokens.accentSky,
      ),
    ];
  }

  List<Widget> _standbyWorkspaceActions({required String prefix}) {
    return [
      _workspaceStatusAction(
        key: ValueKey('$prefix-prime-live'),
        label: 'Prime Live Lane',
        selected:
            _laneFilter == _AiQueueLaneFilter.live &&
            _workspaceView == _AiQueueWorkspaceView.runbook,
        accent: _laneAccent(_AiQueueLaneFilter.live),
        onTap: () => _openStandbyWorkspace(_AiQueueWorkspaceView.runbook),
      ),
      _workspaceStatusAction(
        key: ValueKey('$prefix-open-policy'),
        label: 'Policy Console',
        selected: _workspaceView == _AiQueueWorkspaceView.policy,
        accent: _workspaceAccent(_AiQueueWorkspaceView.policy),
        onTap: () => _openStandbyWorkspace(_AiQueueWorkspaceView.policy),
      ),
      _workspaceStatusAction(
        key: ValueKey('$prefix-open-context'),
        label: 'Context Rail',
        selected: _workspaceView == _AiQueueWorkspaceView.context,
        accent: _workspaceAccent(_AiQueueWorkspaceView.context),
        onTap: () => _openStandbyWorkspace(_AiQueueWorkspaceView.context),
      ),
    ];
  }

  Widget _queuedActionsCard(List<_AiQueueAction> queuedActions) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(9),
      decoration: _panelDecoration(border: OnyxColorTokens.surfaceElevated),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(
                Icons.schedule_rounded,
                color: OnyxColorTokens.textMuted,
                size: 18,
              ),
              Text(
                'Queued Actions',
                style: GoogleFonts.inter(
                  color: OnyxColorTokens.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5.5,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: OnyxColorTokens.accentCyan.withValues(alpha: 0.20),
                  border: Border.all(
                    color: OnyxColorTokens.accentCyan.withValues(alpha: 0.40),
                  ),
                ),
                child: Text(
                  '${queuedActions.length}',
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.accentCyan,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          if (queuedActions.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: OnyxColorTokens.surfaceElevated,
                border: Border.all(color: OnyxColorTokens.divider),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    color: OnyxColorTokens.textMuted,
                    size: 24,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'No actions queued',
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.textMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                for (int i = 0; i < queuedActions.length; i++) ...[
                  _queuedRow(index: i + 1, action: queuedActions[i]),
                  if (i != queuedActions.length - 1) const SizedBox(height: 5),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _queuedRow({required int index, required _AiQueueAction action}) {
    final priority = _priorityStyle(action.incidentPriority);
    final promotionPressureSummary = _promotionPressureSummary(action.metadata);
    final promotionExecutionSummary = _promotionExecutionSummary(
      action.metadata,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(5.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: OnyxColorTokens.surfaceElevated,
        border: Border.all(color: OnyxColorTokens.divider),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: OnyxColorTokens.accentCyan.withValues(alpha: 0.20),
                      border: Border.all(
                        color: OnyxColorTokens.accentCyan.withValues(
                          alpha: 0.40,
                        ),
                      ),
                    ),
                    child: Text(
                      '$index',
                      style: GoogleFonts.inter(
                        color: OnyxColorTokens.accentCyan,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              action.actionType,
                              style: GoogleFonts.inter(
                                color: OnyxColorTokens.textPrimary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '• ${action.incidentId}',
                              style: GoogleFonts.robotoMono(
                                color: OnyxColorTokens.accentCyan,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: priority.background,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: priority.border),
                              ),
                              child: Text(
                                priority.label,
                                style: GoogleFonts.inter(
                                  color: priority.foreground,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          action.description,
                          style: GoogleFonts.inter(
                            color: OnyxColorTokens.textMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (promotionPressureSummary.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            'Promotion pressure: $promotionPressureSummary',
                            style: GoogleFonts.inter(
                              color: OnyxColorTokens.accentGreen,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        if (promotionExecutionSummary.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            'Promotion execution: $promotionExecutionSummary',
                            style: GoogleFonts.inter(
                              color: OnyxColorTokens.accentGreen,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: compact
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Column(
                  crossAxisAlignment: compact
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Executes in',
                      style: GoogleFonts.inter(
                        color: OnyxColorTokens.textMuted,
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _formatTime(action.timeUntilExecutionSeconds),
                      style: GoogleFonts.robotoMono(
                        color: OnyxColorTokens.accentCyan,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _todayPerformance({required bool compact}) {
    final stats = [
      (
        label: 'Total Actions',
        value: _stats.totalActions.toString(),
        color: OnyxColorTokens.surfaceInset,
        border: OnyxColorTokens.surfaceElevated,
      ),
      (
        label: 'Executed',
        value: _stats.executed.toString(),
        color: OnyxColorTokens.accentGreen,
        border: OnyxColorTokens.accentGreen.withValues(alpha: 0.33),
      ),
      (
        label: 'Overridden',
        value: _stats.overridden.toString(),
        color: OnyxColorTokens.accentAmber,
        border: OnyxColorTokens.accentAmber.withValues(alpha: 0.33),
      ),
      (
        label: 'Approval Rate',
        value: '${_stats.approvalRate}%',
        color: OnyxColorTokens.accentCyan,
        border: OnyxColorTokens.accentCyan.withValues(alpha: 0.33),
      ),
    ];
    if (compact) {
      return Column(
        children: [
          for (int i = 0; i < stats.length; i++) ...[
            _statCard(
              label: stats[i].label,
              value: stats[i].value,
              color: stats[i].color,
              border: stats[i].border,
            ),
            if (i != stats.length - 1) const SizedBox(height: 8),
          ],
        ],
      );
    }
    return Row(
      children: [
        for (int i = 0; i < stats.length; i++) ...[
          Expanded(
            child: _statCard(
              label: stats[i].label,
              value: stats[i].value,
              color: stats[i].color,
              border: stats[i].border,
            ),
          ),
          if (i != stats.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _nextShiftDraftsCard(List<_AiQueueAction> drafts) {
    final leadDraft = drafts.first;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(7),
      decoration: _panelDecoration(
        border: OnyxColorTokens.accentPurple.withValues(alpha: 0.40),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(
                Icons.upcoming_rounded,
                color: OnyxColorTokens.accentSky,
                size: 18,
              ),
              Text(
                'Next-Shift Drafts',
                style: GoogleFonts.inter(
                  color: OnyxColorTokens.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5.5,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: OnyxColorTokens.accentPurple.withValues(alpha: 0.13),
                  border: Border.all(
                    color: OnyxColorTokens.accentPurple.withValues(alpha: 0.40),
                  ),
                ),
                child: Text(
                  '${drafts.length}',
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.accentSky,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            leadDraft.actionType,
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textPrimary,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            leadDraft.description,
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (leadDraft.metadata.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if ((leadDraft.metadata['shadow_mo_label'] ?? '').isNotEmpty)
                  _detailCell(
                    'Shadow',
                    [
                      leadDraft.metadata['shadow_mo_label']!,
                      if ((leadDraft.metadata['shadow_mo_repeat_count'] ?? '')
                          .isNotEmpty)
                        'x${leadDraft.metadata['shadow_mo_repeat_count']}',
                    ].join(' • '),
                  ),
                if ((leadDraft.metadata['learning_label'] ?? '').isNotEmpty)
                  _detailCell(
                    'Learning',
                    leadDraft.metadata['learning_label']!,
                  ),
                if ((leadDraft.metadata['learning_repeat_count'] ?? '')
                    .isNotEmpty)
                  _detailCell(
                    'Memory',
                    'x${leadDraft.metadata['learning_repeat_count']}',
                  ),
                if ((leadDraft.metadata['draft_countdown'] ?? '').isNotEmpty)
                  _detailCell(
                    'Countdown',
                    '${leadDraft.metadata['draft_countdown']}s',
                  ),
                if ((leadDraft.metadata['shadow_strength_bias'] ?? '')
                    .isNotEmpty)
                  _detailCell(
                    'Urgency',
                    [
                      leadDraft.metadata['shadow_strength_bias']!,
                      if ((leadDraft.metadata['shadow_strength_priority'] ?? '')
                          .isNotEmpty)
                        leadDraft.metadata['shadow_strength_priority']!,
                    ].join(' • '),
                  ),
                if (widget.previousTomorrowUrgencySummary.trim().isNotEmpty)
                  _detailCell(
                    'Previous urgency',
                    widget.previousTomorrowUrgencySummary.trim(),
                  ),
                if ((leadDraft.metadata['promotion_pressure_summary'] ?? '')
                    .isNotEmpty)
                  _detailCell(
                    'Promotion pressure',
                    leadDraft.metadata['promotion_pressure_summary']!,
                  ),
                if ((leadDraft.metadata['promotion_execution_summary'] ?? '')
                    .isNotEmpty)
                  _detailCell(
                    'Promotion execution',
                    leadDraft.metadata['promotion_execution_summary']!,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 5),
          Column(
            children: [
              for (var i = 0; i < drafts.length; i++) ...[
                _queuedRow(index: i + 1, action: drafts[i]),
                if (i < drafts.length - 1) const SizedBox(height: 5),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _moShadowCard(List<MonitoringGlobalSitePosture> sites) {
    final lead = sites.first;
    final supporting = sites.skip(1).map((site) => site.siteId).join(' • ');
    return Container(
      key: const ValueKey('ai-queue-mo-shadow-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(7),
      decoration: _panelDecoration(
        border: OnyxColorTokens.accentSky.withValues(alpha: 0.40),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(
                Icons.visibility_rounded,
                color: OnyxColorTokens.accentSky,
                size: 18,
              ),
              Text(
                'Shadow MO Intelligence',
                style: GoogleFonts.inter(
                  color: OnyxColorTokens.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5.5,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: OnyxColorTokens.accentSky.withValues(alpha: 0.13),
                  border: Border.all(
                    color: OnyxColorTokens.accentSky.withValues(alpha: 0.40),
                  ),
                ),
                child: Text(
                  '${sites.length}',
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.accentSky,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${lead.siteId} • ${lead.moShadowSummary}',
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textPrimary,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _detailCell('Signal', 'mo_shadow'),
              _detailCell('Lead Site', lead.siteId),
              _detailCell('Matches', '${lead.moShadowMatchCount}'),
              _detailCell(
                'Posture Weight',
                shadowMoPostureStrengthSummary(lead),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              key: const ValueKey('ai-queue-mo-shadow-open-dossier'),
              onPressed: () => _showMoShadowDossier(sites),
              child: const Text('VIEW DOSSIER'),
            ),
          ),
          if (supporting.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Supporting sites: $supporting',
              style: GoogleFonts.inter(
                color: OnyxColorTokens.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showMoShadowDossier(List<MonitoringGlobalSitePosture> sites) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: OnyxColorTokens.backgroundSecondary,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                key: const ValueKey('ai-queue-mo-shadow-dialog'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'SHADOW MO DOSSIER',
                          style: GoogleFonts.inter(
                            color: OnyxColorTokens.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          final payload = _moShadowDossierPayload(sites);
                          Clipboard.setData(
                            ClipboardData(
                              text: const JsonEncoder.withIndent(
                                '  ',
                              ).convert(payload),
                            ),
                          );
                          Navigator.of(dialogContext).pop();
                          if (!mounted) {
                            return;
                          }
                          _showAiQueueFeedback(
                            'Shadow MO dossier copied',
                            label: 'SHADOW DOSSIER',
                            detail:
                                'The exported MO dossier stays pinned in the context rail while the shadow lane remains available.',
                            accent: OnyxColorTokens.accentSky,
                          );
                        },
                        child: const Text('COPY JSON'),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(
                          Icons.close,
                          color: OnyxColorTokens.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: sites.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final site = sites[index];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: OnyxColorTokens.surfaceElevated,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: OnyxColorTokens.divider),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${site.siteId} • ${site.moShadowSummary}',
                                style: GoogleFonts.inter(
                                  color: OnyxColorTokens.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              for (final match in site.moShadowMatches) ...[
                                Text(
                                  match.title,
                                  style: GoogleFonts.inter(
                                    color: OnyxColorTokens.accentSky,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Indicators ${match.matchedIndicators.join(', ')}',
                                  style: GoogleFonts.inter(
                                    color: OnyxColorTokens.textMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (match.validationStatus.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Strength ${shadowMoStrengthSummary(match)}',
                                    style: GoogleFonts.robotoMono(
                                      color: OnyxColorTokens.accentSky,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                                if (match
                                    .recommendedActionPlans
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Actions ${match.recommendedActionPlans.join(' • ')}',
                                    style: GoogleFonts.inter(
                                      color: OnyxColorTokens.accentSky,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                                if (widget.onOpenEventsForScope != null &&
                                    site.moShadowEventIds.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: OutlinedButton(
                                      onPressed: () {
                                        Navigator.of(dialogContext).pop();
                                        widget.onOpenEventsForScope!(
                                          site.moShadowEventIds,
                                          site.moShadowSelectedEventId,
                                        );
                                      },
                                      child: const Text('OPEN EVIDENCE'),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
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

  Map<String, Object?> _moShadowDossierPayload(
    List<MonitoringGlobalSitePosture> sites,
  ) {
    return buildShadowMoDossierPayload(sites: sites);
  }

  Widget _statCard({
    required String label,
    required String value,
    required Color color,
    required Color border,
    bool compactPresentation = false,
  }) {
    return Container(
      padding: EdgeInsets.all(compactPresentation ? 6 : 7),
      decoration: _panelDecoration(border: border),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textMuted,
              fontSize: compactPresentation ? 8.5 : 9,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(
              color: color,
              fontSize: compactPresentation ? 18 : 22,
              height: 0.9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTypePill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: OnyxColorTokens.accentPurple.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: OnyxColorTokens.accentPurple.withValues(alpha: 0.40),
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          color: OnyxColorTokens.accentPurple,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _activeAutomationMetrics({
    required String incidentId,
    required String site,
    required String officer,
    required String eta,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 920
            ? 4
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        final cards = [
          _activeMetricCard(
            label: 'Incident ID',
            value: incidentId,
            mono: true,
          ),
          _activeMetricCard(label: 'Target Site', value: site),
          _activeMetricCard(label: 'Assigned Officer', value: officer),
          _activeMetricCard(label: 'Estimated ETA', value: eta, accent: true),
        ];
        if (columns == 1) {
          return Column(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                cards[i],
                if (i != cards.length - 1) const SizedBox(height: 8),
              ],
            ],
          );
        }
        return GridView.count(
          crossAxisCount: columns,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: columns == 4 ? 2.55 : 3.15,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: cards,
        );
      },
    );
  }

  Widget _activeMetricCard({
    required String label,
    required String value,
    bool mono = false,
    bool accent = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: OnyxColorTokens.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OnyxColorTokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textMuted,
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: mono
                ? GoogleFonts.robotoMono(
                    color: accent
                        ? OnyxColorTokens.accentCyan
                        : OnyxColorTokens.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  )
                : GoogleFonts.inter(
                    color: accent
                        ? OnyxColorTokens.accentCyan
                        : OnyxColorTokens.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _activeSignalCard({
    required String label,
    required String value,
    required Color accent,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: OnyxColorTokens.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OnyxColorTokens.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accent, size: 15),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.textMuted,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    color: accent,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailCell(String label, String value, {bool mono = false}) {
    final normalizedLabel = label.replaceAll('_', ' ').toUpperCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          normalizedLabel,
          style: GoogleFonts.inter(
            color: OnyxColorTokens.textMuted,
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
          ),
        ),
        Text(
          value,
          style: mono
              ? GoogleFonts.robotoMono(
                  color: OnyxColorTokens.accentCyan,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                )
              : GoogleFonts.inter(
                  color: OnyxColorTokens.textPrimary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color background,
    required VoidCallback onPressed,
  }) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: OnyxColorTokens.surfaceInset,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.inter(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
      label: Text(label),
    );
  }

  BoxDecoration _panelDecoration({required Color border, bool glow = false}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      color: OnyxColorTokens.backgroundSecondary,
      border: Border.all(color: border),
      boxShadow: glow
          ? [
              BoxShadow(
                color: OnyxColorTokens.backgroundPrimary.withValues(
                  alpha: 0.09,
                ),
                blurRadius: 18,
                spreadRadius: 1,
                offset: const Offset(0, 0),
              ),
            ]
          : [
              BoxShadow(
                color: OnyxColorTokens.backgroundPrimary.withValues(
                  alpha: 0.06,
                ),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
    );
  }

  String _confidenceLabel(_AiQueueAction action) {
    final directConfidence = action.metadata['confidence'];
    if (directConfidence != null && directConfidence.trim().isNotEmpty) {
      return directConfidence;
    }
    return switch (action.incidentPriority) {
      _AiIncidentPriority.p1Critical => '98%',
      _AiIncidentPriority.p2High => '94%',
      _AiIncidentPriority.p3Medium => '89%',
    };
  }

  _AiQueueAction? get _activeAction {
    for (final action in _actions) {
      if (action.status == _AiActionStatus.executing) {
        return action;
      }
    }
    for (final action in _actions) {
      if (action.status == _AiActionStatus.paused) {
        return action;
      }
    }
    return null;
  }

  List<_AiQueueAction> get _queuedActions => _actions
      .where((action) => action.status == _AiActionStatus.pending)
      .toList(growable: false);

  List<_AiQueueAction> get _displayQueuedActions => _queuedActions
      .where((action) => !_isNextShiftDraft(action))
      .toList(growable: false);

  List<_AiQueueAction> get _nextShiftDrafts =>
      _actions.where(_isNextShiftDraft).toList(growable: false);

  List<MonitoringGlobalSitePosture> get _moShadowSites => _cachedMoShadowSites;

  List<MonitoringGlobalSitePosture> _computeMoShadowSites() {
    final snapshot = _globalPostureService.buildSnapshot(
      events: widget.events,
      sceneReviewByIntelligenceId: widget.sceneReviewByIntelligenceId,
    );
    return snapshot.sites
        .where((site) => site.moShadowMatchCount > 0)
        .toList(growable: false);
  }

  void _onTick() {
    if (!mounted || _queuePaused) {
      return;
    }
    if (_activeAction == null) {
      return;
    }
    setState(() {
      _actions = _actions.map((action) {
        if (action.status != _AiActionStatus.executing) {
          return action;
        }
        if (action.timeUntilExecutionSeconds <= 0) {
          return action;
        }
        return action.copyWith(
          timeUntilExecutionSeconds: action.timeUntilExecutionSeconds - 1,
        );
      }).toList();

      final expiredActionIds = _actions
          .where(
            (action) =>
                action.status == _AiActionStatus.executing &&
                action.timeUntilExecutionSeconds <= 0,
          )
          .map((action) => action.id)
          .toSet();
      if (expiredActionIds.isNotEmpty) {
        _actions.removeWhere((action) => expiredActionIds.contains(action.id));
        if (_selectedFocusId != null &&
            expiredActionIds.contains(_selectedFocusId)) {
          _selectedFocusId = null;
        }
      }
      _ensureSingleExecuting();
    });
  }

  void _cancelAction(String actionId) {
    setState(() {
      _actions.removeWhere((action) => action.id == actionId);
      if (_selectedFocusId == actionId) {
        _selectedFocusId = null;
      }
      _queuePaused = false;
      _ensureSingleExecuting();
    });
  }

  void _approveAction(String actionId) {
    setState(() {
      _actions.removeWhere((action) => action.id == actionId);
      if (_selectedFocusId == actionId) {
        _selectedFocusId = null;
      }
      _queuePaused = false;
      _ensureSingleExecuting();
    });
  }

  void _showAiQueueFeedback(
    String message, {
    String label = 'QUEUE ACTION',
    String? detail,
    Color accent = OnyxColorTokens.accentSky,
  }) {
    if (_usesDesktopWorkspace(context)) {
      setState(() {
        _commandReceipt = _AiQueueCommandReceipt(
          label: label,
          message: message,
          detail:
              detail ??
              'The latest automation command remains pinned in the context rail.',
          accent: accent,
        );
      });
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        backgroundColor: OnyxColorTokens.backgroundSecondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: OnyxColorTokens.divider),
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(
            color: OnyxColorTokens.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  bool _usesDesktopWorkspace(BuildContext context) {
    if (isHandsetLayout(context)) {
      return false;
    }
    return MediaQuery.sizeOf(context).width >= 1180;
  }

  void _togglePause(String actionId) {
    _AiQueueAction? toggledAction;
    setState(() {
      _actions = _actions.map((action) {
        if (action.id != actionId) {
          return action;
        }
        if (action.status == _AiActionStatus.paused) {
          toggledAction = action.copyWith(status: _AiActionStatus.executing);
          return toggledAction!;
        }
        if (action.status == _AiActionStatus.executing) {
          toggledAction = action.copyWith(status: _AiActionStatus.paused);
          return toggledAction!;
        }
        return action;
      }).toList();
      _queuePaused = _actions.any(
        (action) => action.status == _AiActionStatus.paused,
      );
      if (!_queuePaused) {
        _ensureSingleExecuting();
      }
    });
    if (toggledAction == null) {
      return;
    }
    final isPaused = toggledAction!.status == _AiActionStatus.paused;
    _showAiQueueFeedback(
      isPaused
          ? 'Paused ${toggledAction!.incidentId}.'
          : 'Resumed ${toggledAction!.incidentId}.',
      label: isPaused ? 'PAUSE ENGINE' : 'RESUME ENGINE',
      detail:
          '${toggledAction!.site} stays pinned in the workspace while the queue lane remains available for review.',
      accent: isPaused
          ? OnyxColorTokens.accentAmber
          : OnyxColorTokens.accentCyan,
    );
  }

  void _promoteAction(String actionId) {
    _AiQueueAction? promotedAction;
    setState(() {
      _actions = _actions.map((action) {
        if (action.id == actionId) {
          promotedAction = action.copyWith(status: _AiActionStatus.executing);
          return promotedAction!;
        }
        if (action.status == _AiActionStatus.executing ||
            action.status == _AiActionStatus.paused) {
          return action.copyWith(status: _AiActionStatus.pending);
        }
        return action;
      }).toList();
      _queuePaused = false;
      _laneFilter = _AiQueueLaneFilter.live;
      _workspaceView = _AiQueueWorkspaceView.runbook;
      _selectedFocusId = actionId;
      _ensureSingleExecuting();
    });
    if (promotedAction == null) {
      return;
    }
    _showAiQueueFeedback(
      'Promoted ${promotedAction!.incidentId} into the live window.',
      label: 'PROMOTE CURRENT',
      detail:
          '${promotedAction!.site} now leads the automation board while queued alternatives stay visible in the lane rail.',
      accent: OnyxColorTokens.accentSky,
    );
  }

  void _openStandbyWorkspace(_AiQueueWorkspaceView view) {
    setState(() {
      _laneFilter = _AiQueueLaneFilter.live;
      _workspaceView = view;
    });
  }

  void _setWorkspaceView(_AiQueueWorkspaceView view) {
    setState(() => _workspaceView = view);
  }

  void _focusItem(_AiQueueFocusItem item) {
    setState(() {
      _selectedFocusId = item.id;
      _laneFilter = item.lane;
    });
  }

  void _focusLane(
    _AiQueueLaneFilter lane, {
    List<_AiQueueFocusItem>? focusItems,
    String? preferredFocusId,
  }) {
    final items =
        focusItems ??
        _buildFocusItems(
          activeAction: _activeAction,
          queuedActions: _displayQueuedActions,
          nextShiftDrafts: _nextShiftDrafts,
          moShadowSites: _moShadowSites,
        );
    final laneItems = items
        .where((item) => item.lane == lane)
        .toList(growable: false);
    setState(() {
      _laneFilter = lane;
      _selectedFocusId = null; // clear stale selection before reassigning
      if (laneItems.isEmpty) {
        return;
      }
      if (preferredFocusId != null &&
          laneItems.any((item) => item.id == preferredFocusId)) {
        _selectedFocusId = preferredFocusId;
        return;
      }
      _selectedFocusId = laneItems.first.id;
    });
  }

  bool _canOpenEventsForFocus(_AiQueueFocusItem? focus) {
    final callback = widget.onOpenEventsForScope;
    if (callback == null || focus == null) {
      return false;
    }
    if (focus.action != null) {
      return _eventIdsForAction(focus.action!).isNotEmpty;
    }
    if (focus.shadowSite != null) {
      return focus.shadowSite!.moShadowEventIds.isNotEmpty;
    }
    return false;
  }

  void _openEventsForFocus(_AiQueueFocusItem focus) {
    if (focus.action != null) {
      _openEventsForAction(focus.action!);
      return;
    }
    final callback = widget.onOpenEventsForScope;
    final shadowSite = focus.shadowSite;
    if (callback == null ||
        shadowSite == null ||
        shadowSite.moShadowEventIds.isEmpty) {
      return;
    }
    callback(shadowSite.moShadowEventIds, shadowSite.moShadowSelectedEventId);
  }

  void _ensureSingleExecuting() {
    if (_queuePaused) {
      return;
    }
    final hasExecuting = _actions.any(
      (action) => action.status == _AiActionStatus.executing,
    );
    if (hasExecuting) {
      return;
    }
    final nextPendingIndex = _actions.indexWhere(
      (action) => action.status == _AiActionStatus.pending,
    );
    if (nextPendingIndex == -1) {
      return;
    }
    _actions[nextPendingIndex] = _actions[nextPendingIndex].copyWith(
      status: _AiActionStatus.executing,
    );
  }

  List<_AiQueueFocusItem> _buildFocusItems({
    required _AiQueueAction? activeAction,
    required List<_AiQueueAction> queuedActions,
    required List<_AiQueueAction> nextShiftDrafts,
    required List<MonitoringGlobalSitePosture> moShadowSites,
  }) {
    return [
      if (activeAction != null)
        _AiQueueFocusItem.fromAction(
          activeAction,
          lane: _AiQueueLaneFilter.live,
        ),
      ...queuedActions.map(
        (action) => _AiQueueFocusItem.fromAction(
          action,
          lane: _AiQueueLaneFilter.queued,
        ),
      ),
      ...nextShiftDrafts.map(
        (action) => _AiQueueFocusItem.fromAction(
          action,
          lane: _AiQueueLaneFilter.drafts,
        ),
      ),
      ...moShadowSites.map(_AiQueueFocusItem.fromShadowSite),
    ];
  }

  _AiQueueLaneFilter _effectiveLaneForItems(List<_AiQueueFocusItem> items) {
    if (items.any((item) => item.lane == _laneFilter)) {
      return _laneFilter;
    }
    for (final lane in _AiQueueLaneFilter.values) {
      if (items.any((item) => item.lane == lane)) {
        return lane;
      }
    }
    return _AiQueueLaneFilter.live;
  }

  _AiQueueFocusItem? _resolveSelectedFocus({
    required List<_AiQueueFocusItem> laneItems,
    required List<_AiQueueFocusItem> allItems,
  }) {
    final selectedFocusId = _selectedFocusId;
    if (selectedFocusId != null &&
        selectedFocusId.isNotEmpty &&
        !allItems.any((item) => item.id == selectedFocusId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _selectedFocusId != selectedFocusId) {
          return;
        }
        setState(() {
          _selectedFocusId = null;
        });
      });
    }
    for (final item in laneItems) {
      if (item.id == _selectedFocusId) {
        return item;
      }
    }
    if (laneItems.isNotEmpty) {
      return laneItems.first;
    }
    for (final item in allItems) {
      if (item.id == _selectedFocusId) {
        return item;
      }
    }
    return allItems.isEmpty ? null : allItems.first;
  }

  bool _isNextShiftDraft(_AiQueueAction action) {
    return (action.metadata['scope'] ?? '').trim().toUpperCase() ==
        'NEXT_SHIFT';
  }

  String _laneLabel(_AiQueueLaneFilter lane) {
    return switch (lane) {
      _AiQueueLaneFilter.live => 'Live',
      _AiQueueLaneFilter.queued => 'Queued',
      _AiQueueLaneFilter.drafts => 'Drafts',
      _AiQueueLaneFilter.shadow => 'Shadow',
    };
  }

  Color _laneAccent(_AiQueueLaneFilter lane) {
    return switch (lane) {
      _AiQueueLaneFilter.live => OnyxColorTokens.accentCyan,
      _AiQueueLaneFilter.queued => OnyxColorTokens.accentSky,
      _AiQueueLaneFilter.drafts => OnyxColorTokens.accentSky,
      _AiQueueLaneFilter.shadow => OnyxColorTokens.accentSky,
    };
  }

  String _workspaceLabel(_AiQueueWorkspaceView view) {
    return switch (view) {
      _AiQueueWorkspaceView.runbook => 'Runbook',
      _AiQueueWorkspaceView.policy => 'Policy',
      _AiQueueWorkspaceView.context => 'Context',
    };
  }

  Color _workspaceAccent(_AiQueueWorkspaceView view) {
    return switch (view) {
      _AiQueueWorkspaceView.runbook => OnyxColorTokens.accentCyan,
      _AiQueueWorkspaceView.policy => OnyxColorTokens.accentGreen,
      _AiQueueWorkspaceView.context => OnyxColorTokens.accentSky,
    };
  }

  String _formatTime(int totalSeconds) {
    final bounded = totalSeconds < 0 ? 0 : totalSeconds;
    final mins = bounded ~/ 60;
    final secs = bounded % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  _AiQueuePriorityStyle _priorityStyle(_AiIncidentPriority priority) {
    return switch (priority) {
      _AiIncidentPriority.p1Critical => _AiQueuePriorityStyle(
        label: 'P1-CRITICAL',
        foreground: OnyxColorTokens.accentRed,
        background: OnyxColorTokens.accentRed.withValues(alpha: 0.20),
        border: OnyxColorTokens.accentRed.withValues(alpha: 0.40),
      ),
      _AiIncidentPriority.p2High => _AiQueuePriorityStyle(
        label: 'P2-HIGH',
        foreground: OnyxColorTokens.accentAmber,
        background: OnyxColorTokens.accentAmber.withValues(alpha: 0.20),
        border: OnyxColorTokens.accentAmber.withValues(alpha: 0.40),
      ),
      _AiIncidentPriority.p3Medium => _AiQueuePriorityStyle(
        label: 'P3-MEDIUM',
        foreground: OnyxColorTokens.accentAmber,
        background: OnyxColorTokens.accentAmber.withValues(alpha: 0.20),
        border: OnyxColorTokens.accentAmber.withValues(alpha: 0.40),
      ),
    };
  }

  List<_AiQueueAction> _seedActions(
    List<DispatchEvent> events,
    Map<String, MonitoringSceneReviewRecord> sceneReviewByIntelligenceId,
  ) {
    final autonomyPlans =
        _autonomyService
            .buildPlans(
              events: events,
              sceneReviewByIntelligenceId: sceneReviewByIntelligenceId,
              videoOpsLabel: widget.videoOpsLabel,
              historicalSyntheticLearningLabels:
                  widget.historicalSyntheticLearningLabels,
              historicalShadowMoLabels: widget.historicalShadowMoLabels,
              historicalShadowStrengthLabels:
                  widget.historicalShadowStrengthLabels,
            )
            .toList(growable: true)
          ..sort((left, right) {
            final byPriority = _autonomyPlanRank(
              left,
            ).compareTo(_autonomyPlanRank(right));
            if (byPriority != 0) {
              return byPriority;
            }
            return left.countdownSeconds.compareTo(right.countdownSeconds);
          });
    if (autonomyPlans.isNotEmpty) {
      return autonomyPlans
          .asMap()
          .entries
          .map((entry) {
            final plan = entry.value;
            return _AiQueueAction(
              id: plan.id,
              incidentId: plan.incidentId,
              incidentPriority: switch (plan.priority) {
                MonitoringWatchAutonomyPriority.critical =>
                  _AiIncidentPriority.p1Critical,
                MonitoringWatchAutonomyPriority.high =>
                  _AiIncidentPriority.p2High,
                MonitoringWatchAutonomyPriority.medium =>
                  _AiIncidentPriority.p3Medium,
              },
              site: plan.siteId,
              actionType: plan.actionType,
              description: plan.description,
              timeUntilExecutionSeconds: plan.countdownSeconds,
              initialExecutionSeconds: plan.countdownSeconds,
              status: entry.key == 0
                  ? _AiActionStatus.executing
                  : _AiActionStatus.pending,
              metadata: plan.metadata,
            );
          })
          .toList(growable: false);
    }

    final decisions = events.whereType<DecisionCreated>().toList(
      growable: false,
    )..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final closedDispatches = <String>{
      ...events.whereType<ExecutionCompleted>().map((e) => e.dispatchId),
      ...events.whereType<ExecutionDenied>().map((e) => e.dispatchId),
      ...events.whereType<IncidentClosed>().map((e) => e.dispatchId),
    };
    final queuedDecisions = decisions
        .where((decision) => !closedDispatches.contains(decision.dispatchId))
        .take(4)
        .toList(growable: false);

    if (queuedDecisions.isEmpty) {
      return [
        _AiQueueAction(
          id: 'A001',
          incidentId: 'INC-8829-QX',
          incidentPriority: _AiIncidentPriority.p1Critical,
          site: 'Sandton Estate North',
          actionType: 'AUTO-DISPATCH',
          description: 'Dispatch reaction officer Echo-3 to site.',
          timeUntilExecutionSeconds: 27,
          initialExecutionSeconds: 27,
          status: _AiActionStatus.executing,
          metadata: {'officer': 'Echo-3', 'distance': '2.4km', 'eta': '4m 12s'},
        ),
        _AiQueueAction(
          id: 'A002',
          incidentId: 'INC-8830-RZ',
          incidentPriority: _AiIncidentPriority.p1Critical,
          site: 'Waterfall Estate',
          actionType: 'VOIP CLIENT CALL',
          description: 'Initiate safe-word verification call.',
          timeUntilExecutionSeconds: 45,
          initialExecutionSeconds: 45,
          status: _AiActionStatus.pending,
          metadata: {'phone': '+27 82 555 6789'},
        ),
        _AiQueueAction(
          id: 'A003',
          incidentId: 'INC-8827-PX',
          incidentPriority: _AiIncidentPriority.p2High,
          site: 'Blue Ridge Security',
          actionType: '${widget.videoOpsLabel} ACTIVATION',
          description:
              'Request ${widget.videoOpsLabel} stream from perimeter cameras.',
          timeUntilExecutionSeconds: 72,
          initialExecutionSeconds: 72,
          status: _AiActionStatus.pending,
          metadata: {},
        ),
      ];
    }

    final actionTypes = [
      'AUTO-DISPATCH',
      'VOIP CLIENT CALL',
      '${widget.videoOpsLabel} ACTIVATION',
      'VISION VERIFY',
    ];
    final videoActivationType = '${widget.videoOpsLabel} ACTIVATION';
    final seeded = <_AiQueueAction>[];
    for (var index = 0; index < queuedDecisions.length; index++) {
      final decision = queuedDecisions[index];
      final priority = switch (index) {
        0 => _AiIncidentPriority.p1Critical,
        1 => _AiIncidentPriority.p1Critical,
        2 => _AiIncidentPriority.p2High,
        _ => _AiIncidentPriority.p3Medium,
      };
      final type = actionTypes[index % actionTypes.length];
      seeded.add(
        _AiQueueAction(
          id: 'A-${decision.dispatchId}',
          incidentId: decision.dispatchId,
          incidentPriority: priority,
          site: decision.siteId,
          actionType: type,
          description: type == 'AUTO-DISPATCH'
              ? 'Dispatch nearest reaction unit to ${decision.siteId}.'
              : type == 'VOIP CLIENT CALL'
              ? 'Initiate safe-word verification call.'
              : type == videoActivationType
              ? 'Request perimeter and gate camera activation.'
              : 'Queue visual verification capture for AI review.',
          timeUntilExecutionSeconds: 27 + (index * 18),
          initialExecutionSeconds: 27 + (index * 18),
          status: index == 0
              ? _AiActionStatus.executing
              : _AiActionStatus.pending,
          metadata: index == 0
              ? {
                  'officer': 'Echo-3',
                  'distance': '${2 + index}.4km',
                  'eta': '${4 + index}m ${12 + index}s',
                }
              : const {},
        ),
      );
    }
    return seeded;
  }

  int _autonomyPlanRank(MonitoringWatchAutonomyActionPlan plan) {
    final priorityScore = switch (plan.priority) {
      MonitoringWatchAutonomyPriority.critical => 0,
      MonitoringWatchAutonomyPriority.high => 1,
      MonitoringWatchAutonomyPriority.medium => 2,
    };
    if (plan.actionType.trim().toUpperCase() == 'SHADOW READINESS BIAS') {
      return priorityScore - 3;
    }
    if (_hasPromotionExecutionBias(plan)) {
      return priorityScore - 2;
    }
    if ((plan.metadata['scope'] ?? '').trim().toUpperCase() == 'NEXT_SHIFT') {
      return priorityScore - 1;
    }
    return priorityScore + 3;
  }

  bool _hasPromotionExecutionBias(MonitoringWatchAutonomyActionPlan plan) {
    if (plan.actionType.trim().toUpperCase() != 'POLICY RECOMMENDATION') {
      return false;
    }
    return _promotionExecutionSummary(plan.metadata).isNotEmpty;
  }

  String _promotionPressureSummary(Map<String, String> metadata) {
    final prebuiltSummary = (metadata['mo_promotion_pressure_summary'] ?? '')
        .trim();
    if (prebuiltSummary.isNotEmpty) {
      return prebuiltSummary;
    }
    final baseSummary = (metadata['mo_promotion_summary'] ?? '').trim();
    if (baseSummary.isEmpty) {
      return '';
    }
    return buildSyntheticPromotionSummary(
      baseSummary: baseSummary,
      shadowPostureBiasSummary: _shadowPostureBiasSummary(metadata),
    );
  }

  String _promotionExecutionSummary(Map<String, String> metadata) {
    return buildSyntheticPromotionExecutionBiasSummary(
      promotionPriorityBias: (metadata['mo_promotion_priority_bias'] ?? '')
          .trim(),
      promotionCountdownBias: (metadata['mo_promotion_countdown_bias'] ?? '')
          .trim(),
    );
  }

  String _shadowPostureBiasSummary(Map<String, String> metadata) {
    final prebuiltSummary = (metadata['shadow_posture_bias_summary'] ?? '')
        .trim();
    if (prebuiltSummary.isNotEmpty) {
      return prebuiltSummary;
    }
    final postureBias = (metadata['shadow_posture_bias'] ?? '').trim();
    final posturePriority = (metadata['shadow_posture_priority'] ?? '').trim();
    final postureCountdown = (metadata['shadow_posture_countdown'] ?? '')
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

  _AiQueueDailyStats _buildDailyStats(List<DispatchEvent> events) {
    final nowUtc = DateTime.now().toUtc();
    final windowStart = nowUtc.subtract(const Duration(hours: 24));
    final decisions24h = events
        .whereType<DispatchEvent>()
        .where(
          (event) => event is DecisionCreated || event is IntelligenceReceived,
        )
        .where((event) => event.occurredAt.isAfter(windowStart))
        .length;
    final executed24h = events
        .whereType<ExecutionCompleted>()
        .where((event) => event.occurredAt.isAfter(windowStart))
        .length;
    final overridden24h = events
        .whereType<ExecutionDenied>()
        .where((event) => event.occurredAt.isAfter(windowStart))
        .length;
    final approvalRate = decisions24h <= 0
        ? 0
        : ((executed24h / decisions24h) * 100).round().clamp(0, 100);
    return _AiQueueDailyStats(
      totalActions: decisions24h,
      executed: executed24h,
      overridden: overridden24h,
      approvalRate: approvalRate,
    );
  }
}

class _AiQueuePriorityStyle {
  final String label;
  final Color foreground;
  final Color background;
  final Color border;

  const _AiQueuePriorityStyle({
    required this.label,
    required this.foreground,
    required this.background,
    required this.border,
  });
}

class _AiQueueFocusItem {
  final String id;
  final _AiQueueLaneFilter lane;
  final _AiQueueAction? action;
  final MonitoringGlobalSitePosture? shadowSite;

  const _AiQueueFocusItem._({
    required this.id,
    required this.lane,
    this.action,
    this.shadowSite,
  });

  factory _AiQueueFocusItem.fromAction(
    _AiQueueAction action, {
    required _AiQueueLaneFilter lane,
  }) {
    return _AiQueueFocusItem._(id: action.id, lane: lane, action: action);
  }

  factory _AiQueueFocusItem.fromShadowSite(MonitoringGlobalSitePosture site) {
    return _AiQueueFocusItem._(
      id: 'shadow:${site.siteId}',
      lane: _AiQueueLaneFilter.shadow,
      shadowSite: site,
    );
  }

  Color get accent {
    if (action != null) {
      return switch (action!.incidentPriority) {
        _AiIncidentPriority.p1Critical => OnyxColorTokens.accentRed,
        _AiIncidentPriority.p2High => OnyxColorTokens.accentAmber,
        _AiIncidentPriority.p3Medium => OnyxColorTokens.accentCyan,
      };
    }
    return OnyxColorTokens.accentSky;
  }

  String get primaryLabel {
    if (action != null) {
      return '${action!.incidentId} • ${action!.site}';
    }
    return shadowSite!.siteId;
  }

  String get secondaryLabel {
    if (action != null) {
      return switch (lane) {
        _AiQueueLaneFilter.live => 'Live execution',
        _AiQueueLaneFilter.queued => 'Queued for review',
        _AiQueueLaneFilter.drafts => 'Next-shift draft',
        _AiQueueLaneFilter.shadow => 'Shadow',
      };
    }
    return 'Shadow posture signal';
  }

  String get summary {
    if (action != null) {
      return action!.description;
    }
    return shadowSite!.moShadowSummary;
  }

  String get headline {
    if (action != null) {
      return action!.site;
    }
    return shadowSite!.siteId;
  }

  String get bannerSummary {
    if (action != null) {
      return lane == _AiQueueLaneFilter.drafts
          ? 'This queued automation is staged as a next-shift carry-forward recommendation.'
          : lane == _AiQueueLaneFilter.live
          ? 'This automation is currently in the live intervention window.'
          : 'This automation remains in the pending review stack.';
    }
    return 'Shadow pattern intelligence is ready for dossier review and evidence handoff.';
  }

  List<(String, String, Color)> get chips {
    if (action != null) {
      return [
        ('Lane', lane.name.toUpperCase(), accent),
        (
          'ETA',
          _formatChipTime(action!.timeUntilExecutionSeconds),
          OnyxColorTokens.accentCyan,
        ),
      ];
    }
    return [
      ('Signal', 'mo_shadow', OnyxColorTokens.accentSky),
      (
        'Matches',
        '${shadowSite!.moShadowMatchCount}',
        OnyxColorTokens.accentCyan,
      ),
    ];
  }

  static String _formatChipTime(int totalSeconds) {
    final bounded = totalSeconds < 0 ? 0 : totalSeconds;
    final mins = bounded ~/ 60;
    final secs = bounded % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
