import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../application/morning_sovereign_report_service.dart';
import '../application/monitoring_scene_review_store.dart';
import '../domain/events/decision_created.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/events/execution_completed.dart';
import '../domain/events/execution_denied.dart';
import '../domain/events/incident_closed.dart';
import '../domain/events/intelligence_received.dart';
import '../domain/events/partner_dispatch_status_declared.dart';
import '../domain/events/response_arrived.dart';
import '../infrastructure/intelligence/news_intelligence_service.dart';
import 'dispatch_models.dart';
import 'layout_breakpoints.dart';
import 'onyx_surface.dart';
import 'video_fleet_scope_health_card.dart';
import 'video_fleet_scope_health_panel.dart';
import 'video_fleet_scope_health_sections.dart';
import 'video_fleet_scope_health_view.dart';

export 'dispatch_models.dart';

enum _DispatchPriority { p1Critical, p2High, p3Medium }

enum _DispatchStatus { pending, enRoute, onSite, cleared }

enum _DispatchLaneFilter { all, active, pending, cleared }

enum _DispatchFocusState { none, exact, scopeBacked, seeded }

class _DispatchItem {
  final String id;
  final String site;
  final String type;
  final _DispatchPriority priority;
  final _DispatchStatus status;
  final String officer;
  final String dispatchTime;
  final String? eta;
  final String? distance;
  final bool isSeededPlaceholder;

  const _DispatchItem({
    required this.id,
    required this.site,
    required this.type,
    required this.priority,
    required this.status,
    required this.officer,
    required this.dispatchTime,
    this.eta,
    this.distance,
    this.isSeededPlaceholder = false,
  });

  _DispatchItem copyWith({
    String? id,
    String? site,
    String? type,
    _DispatchPriority? priority,
    _DispatchStatus? status,
    String? officer,
    String? dispatchTime,
    String? eta,
    String? distance,
    bool? isSeededPlaceholder,
  }) {
    return _DispatchItem(
      id: id ?? this.id,
      site: site ?? this.site,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      officer: officer ?? this.officer,
      dispatchTime: dispatchTime ?? this.dispatchTime,
      eta: eta ?? this.eta,
      distance: distance ?? this.distance,
      isSeededPlaceholder: isSeededPlaceholder ?? this.isSeededPlaceholder,
    );
  }
}

class _SuppressedDispatchReviewEntry {
  final VideoFleetScopeHealthView scope;
  final MonitoringSceneReviewRecord review;

  const _SuppressedDispatchReviewEntry({
    required this.scope,
    required this.review,
  });
}

class _PartnerDispatchProgressSummary {
  final String dispatchId;
  final String clientId;
  final String siteId;
  final String partnerLabel;
  final PartnerDispatchStatus latestStatus;
  final DateTime latestOccurredAt;
  final int declarationCount;
  final Map<PartnerDispatchStatus, DateTime> firstOccurrenceByStatus;

  const _PartnerDispatchProgressSummary({
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

class _PartnerTrendSummary {
  final int reportDays;
  final String currentScoreLabel;
  final String trendLabel;
  final String trendReason;

  const _PartnerTrendSummary({
    required this.reportDays,
    required this.currentScoreLabel,
    required this.trendLabel,
    required this.trendReason,
  });
}

class _DispatchCommandReceipt {
  final String label;
  final String headline;
  final String detail;
  final Color accent;

  const _DispatchCommandReceipt({
    required this.label,
    required this.headline,
    required this.detail,
    required this.accent,
  });
}

class DispatchPage extends StatefulWidget {
  final String clientId;
  final String regionId;
  final String siteId;
  final VoidCallback onGenerate;
  final VoidCallback onIngestFeeds;
  final VoidCallback? onIngestRadioOps;
  final VoidCallback? onIngestCctvEvents;
  final VoidCallback? onIngestWearableOps;
  final VoidCallback? onIngestNews;
  final VoidCallback? onRetryRadioQueue;
  final VoidCallback? onClearRadioQueue;
  final VoidCallback? onLoadFeedFile;
  final ValueChanged<IntelligenceReceived>? onEscalateIntelligence;
  final List<String> configuredNewsSources;
  final String? newsSourceRequirementsHint;
  final List<NewsSourceDiagnostic> newsSourceDiagnostics;
  final ValueChanged<String>? onProbeNewsSource;
  final VoidCallback? onStartLivePolling;
  final VoidCallback? onStopLivePolling;
  final bool livePolling;
  final String? livePollingLabel;
  final String? runtimeConfigHint;
  final String? initialSelectedDispatchId;
  final ValueChanged<String?>? onSelectedDispatchChanged;
  final bool supabaseReady;
  final bool guardSyncBackendEnabled;
  final String telemetryProviderReadiness;
  final String? telemetryProviderActiveId;
  final String telemetryProviderExpectedId;
  final bool telemetryAdapterStubMode;
  final bool telemetryLiveReadyGateEnabled;
  final bool telemetryLiveReadyGateViolation;
  final String? telemetryLiveReadyGateReason;
  final String radioOpsReadiness;
  final String radioOpsDetail;
  final String radioOpsQueueHealth;
  final String radioQueueIntentMix;
  final String radioAckRecentSummary;
  final bool radioQueueHasPending;
  final String radioQueueFailureDetail;
  final String radioQueueManualActionDetail;
  final bool radioAiAutoAllClearEnabled;
  final String videoOpsLabel;
  final String cctvOpsReadiness;
  final String cctvOpsDetail;
  final String cctvCapabilitySummary;
  final String cctvRecentSignalSummary;
  final List<VideoFleetScopeHealthView> fleetScopeHealth;
  final Map<String, MonitoringSceneReviewRecord> sceneReviewByIntelligenceId;
  final VideoFleetWatchActionDrilldown? initialWatchActionDrilldown;
  final ValueChanged<VideoFleetWatchActionDrilldown?>?
  onWatchActionDrilldownChanged;
  final void Function(
    String clientId,
    String siteId,
    String? incidentReference,
  )?
  onOpenFleetTacticalScope;
  final void Function(
    String clientId,
    String siteId,
    String? incidentReference,
  )?
  onOpenFleetDispatchScope;
  final void Function(String clientId, String siteId)? onRecoverFleetWatchScope;
  final Future<String> Function(VideoFleetScopeHealthView scope)?
  onExtendTemporaryIdentityApproval;
  final Future<String> Function(VideoFleetScopeHealthView scope)?
  onExpireTemporaryIdentityApproval;
  final String wearableOpsReadiness;
  final String wearableOpsDetail;
  final List<String> livePollingHistory;
  final Future<void> Function(IntakeStressProfile profile) onRunStress;
  final Future<void> Function(IntakeStressProfile profile) onRunSoak;
  final Future<void> Function() onRunBenchmarkSuite;
  final IntakeStressProfile initialProfile;
  final String initialScenarioLabel;
  final List<String> initialScenarioTags;
  final String initialRunNote;
  final List<DispatchBenchmarkFilterPreset> initialFilterPresets;
  final String initialIntelligenceSourceFilter;
  final String initialIntelligenceActionFilter;
  final List<String> initialPinnedWatchIntelligenceIds;
  final List<String> initialDismissedIntelligenceIds;
  final bool initialShowPinnedWatchIntelligenceOnly;
  final bool initialShowDismissedIntelligenceOnly;
  final String initialSelectedIntelligenceId;
  final ValueChanged<IntakeStressProfile> onProfileChanged;
  final void Function(String scenarioLabel, List<String> tags)
  onScenarioChanged;
  final ValueChanged<String> onRunNoteChanged;
  final ValueChanged<List<DispatchBenchmarkFilterPreset>>?
  onFilterPresetsChanged;
  final void Function(String sourceFilter, String actionFilter)?
  onIntelligenceFiltersChanged;
  final void Function(
    List<String> pinnedWatchIntelligenceIds,
    List<String> dismissedIntelligenceIds,
  )?
  onIntelligenceTriageChanged;
  final void Function(
    bool showPinnedWatchIntelligenceOnly,
    bool showDismissedIntelligenceOnly,
  )?
  onIntelligenceViewModesChanged;
  final ValueChanged<String>? onSelectedIntelligenceChanged;
  final ValueChanged<IntakeTelemetry> onTelemetryImported;
  final Future<void> Function()? onRerunLastProfile;
  final VoidCallback onCancelStress;
  final VoidCallback onResetTelemetry;
  final VoidCallback onClearTelemetryPersistence;
  final VoidCallback? onClearLivePollHealth;
  final VoidCallback onClearProfilePersistence;
  final VoidCallback? onClearSavedViewsPersistence;
  final bool stressRunning;
  final String? intakeStatus;
  final String? stressStatus;
  final IntakeTelemetry? intakeTelemetry;
  final List<DispatchEvent> events;
  final List<SovereignReport> morningSovereignReportHistory;
  final void Function(String dispatchId) onExecute;
  final ValueChanged<String>? onOpenReportForDispatch;
  final String focusIncidentReference;

  const DispatchPage({
    super.key,
    required this.clientId,
    required this.regionId,
    required this.siteId,
    required this.onGenerate,
    required this.onIngestFeeds,
    this.onIngestRadioOps,
    this.onIngestCctvEvents,
    this.onIngestWearableOps,
    this.onIngestNews,
    this.onRetryRadioQueue,
    this.onClearRadioQueue,
    this.onLoadFeedFile,
    this.onEscalateIntelligence,
    this.configuredNewsSources = const [],
    this.newsSourceRequirementsHint,
    this.newsSourceDiagnostics = const [],
    this.onProbeNewsSource,
    this.onStartLivePolling,
    this.onStopLivePolling,
    this.livePolling = false,
    this.livePollingLabel,
    this.runtimeConfigHint,
    this.initialSelectedDispatchId,
    this.onSelectedDispatchChanged,
    this.supabaseReady = false,
    this.guardSyncBackendEnabled = false,
    this.telemetryProviderReadiness = 'unknown',
    this.telemetryProviderActiveId,
    this.telemetryProviderExpectedId = 'unknown',
    this.telemetryAdapterStubMode = true,
    this.telemetryLiveReadyGateEnabled = false,
    this.telemetryLiveReadyGateViolation = false,
    this.telemetryLiveReadyGateReason,
    this.radioOpsReadiness = 'UNCONFIGURED',
    this.radioOpsDetail =
        'Configure ONYX_RADIO_PROVIDER and ONYX_RADIO_LISTEN_URL.',
    this.radioOpsQueueHealth = 'pending 0 • due 0 • deferred 0 • max-attempt 0',
    this.radioQueueIntentMix =
        'pending intent mix • all_clear 0 • panic 0 • duress 0 • status 0 • unknown 0',
    this.radioAckRecentSummary =
        'recent ack 0 (6h) • all_clear 0 • panic 0 • duress 0 • status 0',
    this.radioQueueHasPending = false,
    this.radioQueueFailureDetail = 'No failed radio responses pending retry.',
    this.radioQueueManualActionDetail =
        'No manual radio queue action in current session.',
    this.radioAiAutoAllClearEnabled = false,
    this.videoOpsLabel = 'CCTV',
    this.cctvOpsReadiness = 'UNCONFIGURED',
    this.cctvOpsDetail =
        'Configure ONYX_CCTV_PROVIDER and ONYX_CCTV_EVENTS_URL, or ONYX_DVR_PROVIDER and ONYX_DVR_EVENTS_URL.',
    this.cctvCapabilitySummary = 'caps none',
    this.cctvRecentSignalSummary =
        'recent video intel 0 (6h) • intrusion 0 • line_crossing 0 • motion 0 • fr 0 • lpr 0',
    this.fleetScopeHealth = const [],
    this.sceneReviewByIntelligenceId =
        const <String, MonitoringSceneReviewRecord>{},
    this.initialWatchActionDrilldown,
    this.onWatchActionDrilldownChanged,
    this.onOpenFleetTacticalScope,
    this.onOpenFleetDispatchScope,
    this.onRecoverFleetWatchScope,
    this.onExtendTemporaryIdentityApproval,
    this.onExpireTemporaryIdentityApproval,
    this.wearableOpsReadiness = 'UNCONFIGURED',
    this.wearableOpsDetail =
        'Configure ONYX_WEARABLE_PROVIDER and ONYX_WEARABLE_EVENTS_URL.',
    this.livePollingHistory = const [],
    required this.onRunStress,
    required this.onRunSoak,
    required this.onRunBenchmarkSuite,
    required this.initialProfile,
    this.initialScenarioLabel = '',
    this.initialScenarioTags = const [],
    this.initialRunNote = '',
    this.initialFilterPresets = const [],
    this.initialIntelligenceSourceFilter = 'all',
    this.initialIntelligenceActionFilter = 'all',
    this.initialPinnedWatchIntelligenceIds = const [],
    this.initialDismissedIntelligenceIds = const [],
    this.initialShowPinnedWatchIntelligenceOnly = false,
    this.initialShowDismissedIntelligenceOnly = false,
    this.initialSelectedIntelligenceId = '',
    required this.onProfileChanged,
    required this.onScenarioChanged,
    required this.onRunNoteChanged,
    this.onFilterPresetsChanged,
    this.onIntelligenceFiltersChanged,
    this.onIntelligenceTriageChanged,
    this.onIntelligenceViewModesChanged,
    this.onSelectedIntelligenceChanged,
    required this.onTelemetryImported,
    this.onRerunLastProfile,
    required this.onCancelStress,
    required this.onResetTelemetry,
    required this.onClearTelemetryPersistence,
    this.onClearLivePollHealth,
    required this.onClearProfilePersistence,
    this.onClearSavedViewsPersistence,
    required this.stressRunning,
    this.intakeStatus,
    this.stressStatus,
    this.intakeTelemetry,
    required this.events,
    this.morningSovereignReportHistory = const <SovereignReport>[],
    required this.onExecute,
    this.onOpenReportForDispatch,
    this.focusIncidentReference = '',
  });

  @override
  State<DispatchPage> createState() => _DispatchPageState();
}

class _DispatchPageState extends State<DispatchPage> {
  static const _defaultCommandReceipt = _DispatchCommandReceipt(
    label: 'SYSTEM RAIL',
    headline: 'Dispatch workspace ready',
    detail:
        'Fleet-watch actions, temporary identity updates, and queue feedback stay visible in the system rail.',
    accent: Color(0xFF8FD1FF),
  );
  late List<_DispatchItem> _dispatches;
  String? _selectedDispatchId;
  String _resolvedFocusReference = '';
  _DispatchFocusState _focusState = _DispatchFocusState.none;
  VideoFleetWatchActionDrilldown? _activeWatchActionDrilldown;
  _DispatchLaneFilter _dispatchLaneFilter = _DispatchLaneFilter.all;
  _DispatchCommandReceipt _commandReceipt = _defaultCommandReceipt;
  bool _desktopWorkspaceActive = false;

  @override
  void initState() {
    super.initState();
    _activeWatchActionDrilldown = widget.initialWatchActionDrilldown;
    _selectedDispatchId = _normalizeSelectedDispatchId(
      widget.initialSelectedDispatchId,
    );
    _projectDispatches(fromInit: true);
  }

  @override
  void didUpdateWidget(covariant DispatchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.events != widget.events ||
        oldWidget.focusIncidentReference.trim() !=
            widget.focusIncidentReference.trim()) {
      _projectDispatches();
    }
    if (oldWidget.initialWatchActionDrilldown !=
            widget.initialWatchActionDrilldown &&
        _activeWatchActionDrilldown != widget.initialWatchActionDrilldown) {
      _activeWatchActionDrilldown = widget.initialWatchActionDrilldown;
    }
    final incomingSelectedDispatchId = _normalizeSelectedDispatchId(
      widget.initialSelectedDispatchId,
    );
    if (oldWidget.initialSelectedDispatchId !=
            widget.initialSelectedDispatchId &&
        incomingSelectedDispatchId != null &&
        _selectedDispatchId != incomingSelectedDispatchId &&
        widget.focusIncidentReference.trim().isEmpty &&
        _dispatches.any(
          (dispatch) => dispatch.id == incomingSelectedDispatchId,
        )) {
      _selectedDispatchId = incomingSelectedDispatchId;
    }
  }

  String? _normalizeSelectedDispatchId(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  void _setActiveWatchActionDrilldown(
    VideoFleetWatchActionDrilldown? value, {
    bool notify = true,
  }) {
    if (_activeWatchActionDrilldown == value) {
      return;
    }
    setState(() {
      _activeWatchActionDrilldown = value;
    });
    if (notify) {
      widget.onWatchActionDrilldownChanged?.call(value);
    }
  }

  void _setSelectedDispatchId(String? value, {bool notify = true}) {
    final normalized = _normalizeSelectedDispatchId(value);
    if (_selectedDispatchId == normalized) {
      return;
    }
    setState(() {
      _selectedDispatchId = normalized;
    });
    if (notify) {
      widget.onSelectedDispatchChanged?.call(normalized);
    }
  }

  void _setDispatchLaneFilter(_DispatchLaneFilter value) {
    if (_dispatchLaneFilter == value) {
      return;
    }
    final previousSelectedDispatchId = _selectedDispatchId;
    final visibleDispatches = _visibleDispatches(
      dispatches: _dispatches,
      filter: value,
    );
    final nextSelectedDispatchId = visibleDispatches.isEmpty
        ? null
        : visibleDispatches.any(
            (dispatch) => dispatch.id == _selectedDispatchId,
          )
        ? _selectedDispatchId
        : visibleDispatches.first.id;
    setState(() {
      _dispatchLaneFilter = value;
      _selectedDispatchId = nextSelectedDispatchId;
    });
    if (previousSelectedDispatchId != nextSelectedDispatchId) {
      widget.onSelectedDispatchChanged?.call(nextSelectedDispatchId);
    }
  }

  List<_DispatchItem> _visibleDispatches({
    List<_DispatchItem>? dispatches,
    _DispatchLaneFilter? filter,
  }) {
    final source = dispatches ?? _dispatches;
    final activeFilter = filter ?? _dispatchLaneFilter;
    return source
        .where((dispatch) {
          return switch (activeFilter) {
            _DispatchLaneFilter.all => true,
            _DispatchLaneFilter.active =>
              dispatch.status == _DispatchStatus.enRoute ||
                  dispatch.status == _DispatchStatus.onSite,
            _DispatchLaneFilter.pending =>
              dispatch.status == _DispatchStatus.pending,
            _DispatchLaneFilter.cleared =>
              dispatch.status == _DispatchStatus.cleared,
          };
        })
        .toList(growable: false);
  }

  int _dispatchCountForFilter(_DispatchLaneFilter filter) {
    return _visibleDispatches(filter: filter).length;
  }

  _DispatchItem? _selectedDispatch({List<_DispatchItem>? dispatches}) {
    final source = dispatches ?? _dispatches;
    if (source.isEmpty) {
      return null;
    }
    return source.cast<_DispatchItem?>().firstWhere(
      (dispatch) => dispatch?.id == _selectedDispatchId,
      orElse: () => source.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fleetPanelKey = GlobalKey();
    final suppressedPanelKey = GlobalKey();
    final commandActionsKey = GlobalKey();
    final selectedDispatchBoardKey = GlobalKey();
    final dispatchQueueKey = GlobalKey();
    final wide = allowEmbeddedPanelScroll(context);
    final contentPadding = const EdgeInsets.fromLTRB(2.95, 2.95, 2.95, 3.7);
    _desktopWorkspaceActive = wide;
    final activeDispatches = _dispatches
        .where(
          (dispatch) =>
              !dispatch.isSeededPlaceholder &&
              (dispatch.status == _DispatchStatus.enRoute ||
                  dispatch.status == _DispatchStatus.onSite),
        )
        .length;
    final pendingDispatches = _dispatches
        .where(
          (dispatch) =>
              !dispatch.isSeededPlaceholder &&
              dispatch.status == _DispatchStatus.pending,
        )
        .length;
    final visibleDispatches = _visibleDispatches();
    final selectedDispatch = visibleDispatches.isEmpty
        ? null
        : _selectedDispatch(dispatches: visibleDispatches);
    final suppressedEntries = _suppressedDispatchReviewEntries();
    void openSection(GlobalKey key) {
      final targetContext = key.currentContext;
      if (targetContext == null) {
        return;
      }
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }

    void openWatchActionDrilldown(VideoFleetWatchActionDrilldown drilldown) {
      if (_activeWatchActionDrilldown == drilldown) {
        _setActiveWatchActionDrilldown(null);
        return;
      }
      _setActiveWatchActionDrilldown(drilldown);
      final targetContext =
          drilldown == VideoFleetWatchActionDrilldown.filtered &&
              suppressedEntries.isNotEmpty
          ? suppressedPanelKey.currentContext
          : fleetPanelKey.currentContext;
      if (targetContext == null) {
        return;
      }
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }

    void openLatestWatchActionDetail(VideoFleetScopeHealthView scope) {
      if (_activeWatchActionDrilldown ==
              VideoFleetWatchActionDrilldown.filtered &&
          suppressedEntries.isNotEmpty) {
        final targetContext = suppressedPanelKey.currentContext;
        if (targetContext != null) {
          Scrollable.ensureVisible(
            targetContext,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          );
        }
        return;
      }
      final primaryOpenFleetScope = scope.hasIncidentContext
          ? (widget.onOpenFleetDispatchScope ?? widget.onOpenFleetTacticalScope)
          : null;
      if (primaryOpenFleetScope == null) {
        return;
      }
      primaryOpenFleetScope.call(
        scope.clientId,
        scope.siteId,
        scope.latestIncidentReference,
      );
    }

    Widget buildWideWorkspace({required bool embedScroll}) {
      Widget railChild() {
        if (!embedScroll) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kpiBand(
                activeDispatches: activeDispatches,
                pendingDispatches: pendingDispatches,
              ),
              const SizedBox(height: 4),
              KeyedSubtree(key: commandActionsKey, child: _commandActions()),
            ],
          );
        }
        return ListView(
          primary: false,
          padding: EdgeInsets.zero,
          children: [
            _kpiBand(
              activeDispatches: activeDispatches,
              pendingDispatches: pendingDispatches,
            ),
            const SizedBox(height: 3.5),
            KeyedSubtree(key: commandActionsKey, child: _commandActions()),
          ],
        );
      }

      Widget queueChild() {
        return KeyedSubtree(
          key: dispatchQueueKey,
          child: _dispatchQueue(
            selectedDispatchBoardKey: selectedDispatchBoardKey,
            embeddedSurface: embedScroll,
          ),
        );
      }

      Widget systemRailChild() {
        final content = _systemStatusPanel(
          fleetPanelKey: fleetPanelKey,
          suppressedPanelKey: suppressedPanelKey,
          onOpenDispatchBoard: () => openSection(selectedDispatchBoardKey),
          onOpenCommandActions: () => openSection(commandActionsKey),
          onOpenFleetWatch: () => openSection(fleetPanelKey),
          onOpenSuppressedReviews: () => openSection(suppressedPanelKey),
          summaryOnly: true,
          suppressedEntries: suppressedEntries,
          onOpenWatchActionDrilldown: openWatchActionDrilldown,
          onOpenLatestWatchActionDetail: openLatestWatchActionDetail,
        );
        if (!embedScroll) {
          return content;
        }
        return ListView(
          primary: false,
          padding: EdgeInsets.zero,
          children: [content],
        );
      }

      final railWidth = embedScroll ? 170.0 : 180.0;
      final systemRailWidth = embedScroll ? 188.0 : 198.0;
      final workspaceGap = 0.48;

      final workspaceRow = Row(
        crossAxisAlignment: embedScroll
            ? CrossAxisAlignment.stretch
            : CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: railWidth,
            child: _dispatchWorkspacePanel(
              key: const ValueKey('dispatch-workspace-panel-rail'),
              title: 'Dispatch Rail',
              subtitle:
                  'Command posture, KPIs, and launch actions stay pinned on the left.',
              shellless: true,
              child: railChild(),
              flexibleChild: embedScroll,
            ),
          ),
          SizedBox(width: workspaceGap),
          Expanded(
            flex: 10,
            child: _dispatchWorkspacePanel(
              key: const ValueKey('dispatch-workspace-panel-board'),
              title: 'Mission Board',
              subtitle:
                  'Lane-filtered dispatch queue and the selected mission board stay centered.',
              shellless: true,
              child: queueChild(),
              flexibleChild: embedScroll,
            ),
          ),
          SizedBox(width: workspaceGap),
          SizedBox(
            width: systemRailWidth,
            child: _dispatchWorkspacePanel(
              key: const ValueKey('dispatch-workspace-panel-context'),
              title: 'System Rail',
              subtitle:
                  'Fleet watch health, suppressed reviews, and command-system posture stay visible.',
              shellless: true,
              child: systemRailChild(),
              flexibleChild: embedScroll,
            ),
          ),
        ],
      );

      return workspaceRow;
    }

    Widget buildSurfaceBody({required bool embedScroll}) {
      if (wide) {
        return buildWideWorkspace(embedScroll: embedScroll);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kpiBand(
            activeDispatches: activeDispatches,
            pendingDispatches: pendingDispatches,
          ),
          const SizedBox(height: 3.0),
          KeyedSubtree(key: commandActionsKey, child: _commandActions()),
          const SizedBox(height: 3.0),
          _dispatchQueue(selectedDispatchBoardKey: selectedDispatchBoardKey),
          const SizedBox(height: 3.0),
          _systemStatusPanel(
            fleetPanelKey: fleetPanelKey,
            suppressedPanelKey: suppressedPanelKey,
            onOpenDispatchBoard: () => openSection(selectedDispatchBoardKey),
            onOpenCommandActions: () => openSection(commandActionsKey),
            onOpenFleetWatch: () => openSection(fleetPanelKey),
            onOpenSuppressedReviews: () => openSection(suppressedPanelKey),
            suppressedEntries: suppressedEntries,
            onOpenWatchActionDrilldown: openWatchActionDrilldown,
            onOpenLatestWatchActionDetail: openLatestWatchActionDetail,
          ),
        ],
      );
    }

    final workspaceStatusBanner = wide
        ? _dispatchWorkspaceStatusBanner(
            selectedDispatch: selectedDispatch,
            activeDispatches: activeDispatches,
            pendingDispatches: pendingDispatches,
            onOpenReport:
                selectedDispatch == null ||
                    widget.onOpenReportForDispatch == null ||
                    selectedDispatch.isSeededPlaceholder
                ? null
                : () =>
                      widget.onOpenReportForDispatch!.call(selectedDispatch.id),
            onOpenCommandActions: () => openSection(commandActionsKey),
            onOpenDispatchBoard: () => openSection(selectedDispatchBoardKey),
            onOpenSystemStatus: () => openSection(fleetPanelKey),
            onSetLaneFilter: (_DispatchLaneFilter filter) {
              _setDispatchLaneFilter(filter);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                openSection(dispatchQueueKey);
              });
            },
          )
        : null;

    return OnyxPageScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final boundedDesktopSurface =
              wide &&
              constraints.hasBoundedHeight &&
              constraints.maxHeight.isFinite;
          final surfaceMaxWidth = commandSurfaceMaxWidth(
            context,
            compactDesktopWidth: 1760,
            viewportWidth: constraints.maxWidth,
            widescreenFillFactor: 0.985,
          );
          return OnyxViewportWorkspaceLayout(
            padding: contentPadding,
            maxWidth: surfaceMaxWidth,
            lockToViewport: boundedDesktopSurface,
            header: _header(workspaceBanner: workspaceStatusBanner),
            body: buildSurfaceBody(embedScroll: boundedDesktopSurface),
          );
        },
      ),
    );
  }

  Widget _dispatchWorkspaceStatusBanner({
    required _DispatchItem? selectedDispatch,
    required int activeDispatches,
    required int pendingDispatches,
    required VoidCallback? onOpenReport,
    required VoidCallback onOpenCommandActions,
    required VoidCallback onOpenDispatchBoard,
    required VoidCallback onOpenSystemStatus,
    required ValueChanged<_DispatchLaneFilter> onSetLaneFilter,
  }) {
    final laneLabel = switch (_dispatchLaneFilter) {
      _DispatchLaneFilter.all => 'All lanes live',
      _DispatchLaneFilter.active => 'Active lanes in focus',
      _DispatchLaneFilter.pending => 'Pending lanes in focus',
      _DispatchLaneFilter.cleared => 'Cleared lanes in focus',
    };
    final selectedLabel = selectedDispatch == null
        ? 'No live dispatch selected'
        : '${selectedDispatch.id} • ${selectedDispatch.site}';
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1240;
        final summary = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 10.3,
              height: 10.3,
              decoration: BoxDecoration(
                color: const Color(0x1ADC2626),
                borderRadius: BorderRadius.circular(3.15),
                border: Border.all(color: const Color(0x55EA580C)),
              ),
              child: const Icon(
                Icons.route_rounded,
                color: Color(0xFFFFD6BF),
                size: 6.2,
              ),
            ),
            const SizedBox(width: 1.35),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DISPATCH WORKSPACE',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF8FAFD4),
                      fontSize: 5.6,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.95,
                    ),
                  ),
                  const SizedBox(height: 0.24),
                  Text(
                    '$selectedLabel while $laneLabel. Active $activeDispatches • Pending $pendingDispatches.',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFEAF4FF),
                      fontSize: 6.5,
                      fontWeight: FontWeight.w700,
                      height: 1.28,
                    ),
                    maxLines: compact ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        );
        final focusCard = _dispatchWorkspaceFocusCard(
          selectedDispatch: selectedDispatch,
          activeDispatches: activeDispatches,
          pendingDispatches: pendingDispatches,
          onOpenReport: onOpenReport,
          onOpenCommandActions: onOpenCommandActions,
          onOpenDispatchBoard: onOpenDispatchBoard,
          onOpenSystemStatus: onOpenSystemStatus,
          onSetLaneFilter: onSetLaneFilter,
          summaryOnly: !compact,
        );
        if (!compact) {
          return KeyedSubtree(
            key: const ValueKey('dispatch-workspace-status-banner'),
            child: focusCard,
          );
        }
        return Container(
          key: const ValueKey('dispatch-workspace-status-banner'),
          width: double.infinity,
          padding: const EdgeInsets.all(0.46),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF101D30), Color(0xFF162740)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(5.5),
            border: Border.all(color: const Color(0xFF26405C)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [summary, const SizedBox(height: 0.12), focusCard],
          ),
        );
      },
    );
  }

  Widget _dispatchWorkspaceFocusCard({
    required _DispatchItem? selectedDispatch,
    required int activeDispatches,
    required int pendingDispatches,
    required VoidCallback? onOpenReport,
    required VoidCallback onOpenCommandActions,
    required VoidCallback onOpenDispatchBoard,
    required VoidCallback onOpenSystemStatus,
    required ValueChanged<_DispatchLaneFilter> onSetLaneFilter,
    bool summaryOnly = false,
  }) {
    if (selectedDispatch == null) {
      final clearedDispatches = _dispatchCountForFilter(
        _DispatchLaneFilter.cleared,
      );
      return KeyedSubtree(
        key: const ValueKey('dispatch-workspace-focus-card'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0.2, vertical: 0.12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MISSION FOCUS RECOVERY',
                style: GoogleFonts.inter(
                  color: const Color(0xFFF6C067),
                  fontSize: 5.8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 0.34),
              Text(
                'No mission is pinned in the board.',
                style: GoogleFonts.rajdhani(
                  color: const Color(0xFFF4F8FF),
                  fontSize: 8.9,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 0.34),
              Text(
                'Recover the board by reopening a populated lane or jumping straight into the mission board.',
                style: GoogleFonts.inter(
                  color: const Color(0xFFD5E1F2),
                  fontSize: 5.9,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 0.56),
              Wrap(
                spacing: 0.58,
                runSpacing: 0.58,
                children: [
                  _heroChip(
                    label: 'Active',
                    foreground: const Color(0xFF22D3EE),
                    background: const Color(0x1422D3EE),
                    border: const Color(0x6622D3EE),
                  ),
                  _workspaceActionChip(
                    key: const ValueKey('dispatch-workspace-filter-pending'),
                    label: 'Pending $pendingDispatches',
                    foreground: const Color(0xFFF59E0B),
                    background: const Color(0x1AF59E0B),
                    border: const Color(0x66F59E0B),
                    onTap: () => onSetLaneFilter(_DispatchLaneFilter.pending),
                  ),
                  _heroChip(
                    label: 'Cleared $clearedDispatches',
                    foreground: const Color(0xFF86EFAC),
                    background: const Color(0x1486EFAC),
                    border: const Color(0x6686EFAC),
                  ),
                ],
              ),
              const SizedBox(height: 0.56),
              Wrap(
                spacing: 0.58,
                runSpacing: 0.58,
                children: [
                  _workspaceActionChip(
                    key: const ValueKey(
                      'dispatch-workspace-focus-open-all-lanes',
                    ),
                    label: 'All lanes',
                    foreground: const Color(0xFF8FD1FF),
                    background: const Color(0x148FD1FF),
                    border: const Color(0x668FD1FF),
                    onTap: () => onSetLaneFilter(_DispatchLaneFilter.all),
                  ),
                  if (activeDispatches > 0)
                    _workspaceActionChip(
                      key: const ValueKey(
                        'dispatch-workspace-focus-open-active-lanes',
                      ),
                      label: 'Active lanes',
                      foreground: const Color(0xFF22D3EE),
                      background: const Color(0x1422D3EE),
                      border: const Color(0x6622D3EE),
                      onTap: () => onSetLaneFilter(_DispatchLaneFilter.active),
                    ),
                  _workspaceActionChip(
                    key: const ValueKey('dispatch-workspace-filter-pending'),
                    label: 'Pending lanes',
                    foreground: const Color(0xFFF59E0B),
                    background: const Color(0x1AF59E0B),
                    border: const Color(0x66F59E0B),
                    onTap: () => onSetLaneFilter(_DispatchLaneFilter.pending),
                  ),
                  _workspaceActionChip(
                    key: const ValueKey('dispatch-workspace-filter-cleared'),
                    label: 'Cleared lanes',
                    foreground: const Color(0xFF86EFAC),
                    background: const Color(0x1486EFAC),
                    border: const Color(0x6686EFAC),
                    onTap: () => onSetLaneFilter(_DispatchLaneFilter.cleared),
                  ),
                  _workspaceActionChip(
                    key: const ValueKey('dispatch-workspace-focus-open-board'),
                    label: 'Mission board',
                    foreground: const Color(0xFFD8E8FA),
                    background: const Color(0x143B82F6),
                    border: const Color(0x663B82F6),
                    onTap: onOpenDispatchBoard,
                  ),
                  _workspaceActionChip(
                    key: const ValueKey('dispatch-workspace-open-system'),
                    label: 'System rail',
                    foreground: const Color(0xFFD8E8FA),
                    background: const Color(0x143B82F6),
                    border: const Color(0x663B82F6),
                    onTap: onOpenSystemStatus,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final statusStyle = _statusStyle(selectedDispatch.status);
    final priorityStyle = _priorityStyle(selectedDispatch.priority);
    final laneForDispatch = switch (selectedDispatch.status) {
      _DispatchStatus.pending => _DispatchLaneFilter.pending,
      _DispatchStatus.cleared => _DispatchLaneFilter.cleared,
      _DispatchStatus.enRoute ||
      _DispatchStatus.onSite => _DispatchLaneFilter.active,
    };
    final laneActionLabel = switch (laneForDispatch) {
      _DispatchLaneFilter.active => 'Active lane',
      _DispatchLaneFilter.pending => 'Pending lane',
      _DispatchLaneFilter.cleared => 'Cleared lane',
      _DispatchLaneFilter.all => 'All lanes',
    };

    return KeyedSubtree(
      key: const ValueKey('dispatch-workspace-focus-card'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0.2, vertical: 0.14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MISSION IN FOCUS',
              style: GoogleFonts.inter(
                color: priorityStyle.color,
                fontSize: 5.8,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 0.34),
            Text(
              '${selectedDispatch.id} • ${selectedDispatch.site}',
              style: GoogleFonts.rajdhani(
                color: const Color(0xFFF4F8FF),
                fontSize: 8.9,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 0.34),
            Text(
              '${selectedDispatch.type} is assigned to ${selectedDispatch.officer} while the mission board and reporting handoff stay one step away.',
              style: GoogleFonts.inter(
                color: const Color(0xFFD5E1F2),
                fontSize: 5.9,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 0.56),
            Wrap(
              spacing: 0.58,
              runSpacing: 0.58,
              children: [
                _heroChip(
                  label: statusStyle.label,
                  foreground: statusStyle.chipFg,
                  background: statusStyle.chipBg,
                  border: statusStyle.chipBorder,
                ),
                _heroChip(
                  label: priorityStyle.label,
                  foreground: priorityStyle.color,
                  background: priorityStyle.color.withValues(alpha: 0.12),
                  border: priorityStyle.color.withValues(alpha: 0.42),
                ),
                _heroChip(
                  label: selectedDispatch.officer,
                  foreground: const Color(0xFFD8E8FA),
                  background: const Color(0x143B82F6),
                  border: const Color(0x663B82F6),
                ),
                if (selectedDispatch.eta != null)
                  _heroChip(
                    label: 'ETA ${selectedDispatch.eta}',
                    foreground: const Color(0xFF22D3EE),
                    background: const Color(0x1422D3EE),
                    border: const Color(0x6622D3EE),
                  ),
              ],
            ),
            const SizedBox(height: 0.56),
            if (summaryOnly)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 0.58,
                    runSpacing: 0.58,
                    children: [
                      if (_dispatchLaneFilter != laneForDispatch)
                        _workspaceActionChip(
                          key: const ValueKey(
                            'dispatch-workspace-focus-open-lane',
                          ),
                          label: laneActionLabel,
                          foreground: statusStyle.chipFg,
                          background: statusStyle.chipBg,
                          border: statusStyle.chipBorder,
                          onTap: () => onSetLaneFilter(laneForDispatch),
                        ),
                      if (_dispatchLaneFilter != _DispatchLaneFilter.all)
                        _workspaceActionChip(
                          key: const ValueKey('dispatch-workspace-filter-all'),
                          label: 'All lanes',
                          foreground: const Color(0xFF8FD1FF),
                          background: const Color(0x148FD1FF),
                          border: const Color(0x668FD1FF),
                          onTap: () => onSetLaneFilter(_DispatchLaneFilter.all),
                        ),
                      _workspaceActionChip(
                        key: const ValueKey('dispatch-workspace-filter-active'),
                        label: 'Active lanes',
                        foreground: const Color(0xFF22D3EE),
                        background: const Color(0x1422D3EE),
                        border: const Color(0x6622D3EE),
                        onTap: () =>
                            onSetLaneFilter(_DispatchLaneFilter.active),
                      ),
                      _workspaceActionChip(
                        key: const ValueKey(
                          'dispatch-workspace-filter-pending',
                        ),
                        label: 'Pending lanes',
                        foreground: const Color(0xFFF59E0B),
                        background: const Color(0x1AF59E0B),
                        border: const Color(0x66F59E0B),
                        onTap: () =>
                            onSetLaneFilter(_DispatchLaneFilter.pending),
                      ),
                      _workspaceActionChip(
                        key: const ValueKey(
                          'dispatch-workspace-filter-cleared',
                        ),
                        label: 'Cleared lanes',
                        foreground: const Color(0xFF86EFAC),
                        background: const Color(0x1486EFAC),
                        border: const Color(0x6686EFAC),
                        onTap: () =>
                            onSetLaneFilter(_DispatchLaneFilter.cleared),
                      ),
                    ],
                  ),
                  const SizedBox(height: 0.56),
                  Text(
                    'Report handoff, mission detail, and system posture stay anchored to the header, selected board, and right rail.',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFD5E1F2),
                      fontSize: 5.9,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              )
            else
              Wrap(
                spacing: 0.58,
                runSpacing: 0.58,
                children: [
                  if (_dispatchLaneFilter != laneForDispatch)
                    _workspaceActionChip(
                      key: const ValueKey('dispatch-workspace-focus-open-lane'),
                      label: laneActionLabel,
                      foreground: statusStyle.chipFg,
                      background: statusStyle.chipBg,
                      border: statusStyle.chipBorder,
                      onTap: () => onSetLaneFilter(laneForDispatch),
                    ),
                  if (_dispatchLaneFilter != _DispatchLaneFilter.all)
                    _workspaceActionChip(
                      key: const ValueKey('dispatch-workspace-filter-all'),
                      label: 'All lanes',
                      foreground: const Color(0xFF8FD1FF),
                      background: const Color(0x148FD1FF),
                      border: const Color(0x668FD1FF),
                      onTap: () => onSetLaneFilter(_DispatchLaneFilter.all),
                    ),
                  _workspaceActionChip(
                    key: const ValueKey('dispatch-workspace-filter-active'),
                    label: 'Active lanes',
                    foreground: const Color(0xFF22D3EE),
                    background: const Color(0x1422D3EE),
                    border: const Color(0x6622D3EE),
                    onTap: () => onSetLaneFilter(_DispatchLaneFilter.active),
                  ),
                  _workspaceActionChip(
                    key: const ValueKey('dispatch-workspace-filter-pending'),
                    label: 'Pending lanes',
                    foreground: const Color(0xFFF59E0B),
                    background: const Color(0x1AF59E0B),
                    border: const Color(0x66F59E0B),
                    onTap: () => onSetLaneFilter(_DispatchLaneFilter.pending),
                  ),
                  _workspaceActionChip(
                    key: const ValueKey('dispatch-workspace-filter-cleared'),
                    label: 'Cleared lanes',
                    foreground: const Color(0xFF86EFAC),
                    background: const Color(0x1486EFAC),
                    border: const Color(0x6686EFAC),
                    onTap: () => onSetLaneFilter(_DispatchLaneFilter.cleared),
                  ),
                  _workspaceActionChip(
                    key: const ValueKey('dispatch-workspace-focus-open-board'),
                    label: 'Mission board',
                    foreground: const Color(0xFF8FD1FF),
                    background: const Color(0x148FD1FF),
                    border: const Color(0x668FD1FF),
                    onTap: onOpenDispatchBoard,
                  ),
                  if (onOpenReport != null)
                    _workspaceActionChip(
                      key: const ValueKey(
                        'dispatch-workspace-focus-open-report',
                      ),
                      label: 'Selected report',
                      foreground: const Color(0xFFFFD6BF),
                      background: const Color(0x14EA580C),
                      border: const Color(0x66EA580C),
                      onTap: onOpenReport,
                    ),
                  _workspaceActionChip(
                    key: const ValueKey('dispatch-workspace-open-system'),
                    label: 'System rail',
                    foreground: const Color(0xFFD8E8FA),
                    background: const Color(0x143B82F6),
                    border: const Color(0x663B82F6),
                    onTap: onOpenSystemStatus,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _dispatchWorkspacePanel({
    required Key key,
    required String title,
    required String subtitle,
    required Widget child,
    bool flexibleChild = false,
    bool shellless = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boundedHeight =
            constraints.hasBoundedHeight && constraints.maxHeight.isFinite;
        if (shellless) {
          return KeyedSubtree(key: key, child: child);
        }
        return Container(
          key: key,
          width: double.infinity,
          padding: const EdgeInsets.all(0.9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4.0),
            color: const Color(0xFF0B1523),
            border: Border.all(color: const Color(0xFF203448)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: GoogleFonts.inter(
                  color: const Color(0xFF6C87AD),
                  fontSize: 6.1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 0.38),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  color: const Color(0xFF96AECD),
                  fontSize: 6.0,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 0.68),
              if (boundedHeight && flexibleChild)
                Expanded(child: child)
              else
                child,
            ],
          ),
        );
      },
    );
  }

  Widget _workspaceActionChip({
    required Key key,
    required String label,
    required Color foreground,
    required Color background,
    required Color border,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2.2, vertical: 1.0),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: foreground,
            fontSize: 6.1,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _header({Widget? workspaceBanner}) {
    final selectedDispatch = _dispatches.cast<_DispatchItem?>().firstWhere(
      (dispatch) => dispatch?.id == _selectedDispatchId,
      orElse: () => _dispatches.isNotEmpty ? _dispatches.first : null,
    );
    final openReportAvailable =
        widget.onOpenReportForDispatch != null &&
        selectedDispatch != null &&
        !selectedDispatch.isSeededPlaceholder;
    final fleetScopeCount = widget.fleetScopeHealth.length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1120;
        final actionButton = OutlinedButton.icon(
          key: const ValueKey('dispatch-open-report-button'),
          onPressed: !openReportAvailable
              ? null
              : () => widget.onOpenReportForDispatch!.call(selectedDispatch.id),
          icon: const Icon(Icons.description_rounded, size: 14.5),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFEAF4FF),
            side: BorderSide(
              color: openReportAvailable
                  ? const Color(0xFF4B6B8F)
                  : const Color(0xFF35506F),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 2.75,
              vertical: 1.05,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4.5),
            ),
          ),
          label: Text(
            'Open Report',
            style: GoogleFonts.inter(
              fontSize: 7.6,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
        final titleBlock = Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 16.8,
                height: 16.8,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFDC2626), Color(0xFFEA580C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(4.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33DC2626),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.radio_rounded,
                  size: 7.8,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 1.8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DISPATCH COMMAND',
                      style: GoogleFonts.rajdhani(
                        color: const Color(0xFFE9F3FF),
                        fontSize: compact ? 11.8 : 13.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 0.34),
                    Text(
                      '${widget.clientId} / ${widget.regionId} / ${widget.siteId.trim().isEmpty ? 'all sites' : widget.siteId}',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8EA4C2),
                        fontSize: 6.6,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 0.4),
                    if (workspaceBanner == null) ...[
                      Wrap(
                        spacing: 0.72,
                        runSpacing: 0.56,
                        children: [
                          _heroChip(
                            label: widget.livePolling
                                ? 'Live Poll Active'
                                : 'Live Poll Paused',
                            foreground: widget.livePolling
                                ? const Color(0xFF22D3EE)
                                : const Color(0xFF94A3B8),
                            background: widget.livePolling
                                ? const Color(0x1A22D3EE)
                                : const Color(0x1A94A3B8),
                            border: widget.livePolling
                                ? const Color(0x6622D3EE)
                                : const Color(0x6694A3B8),
                          ),
                          _heroChip(
                            label: widget.radioQueueHasPending
                                ? 'Radio Queue Pending'
                                : 'Radio Queue Clear',
                            foreground: widget.radioQueueHasPending
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF34D399),
                            background: widget.radioQueueHasPending
                                ? const Color(0x1AF59E0B)
                                : const Color(0x1A34D399),
                            border: widget.radioQueueHasPending
                                ? const Color(0x66F59E0B)
                                : const Color(0x6634D399),
                          ),
                          _heroChip(
                            label: 'Fleet $fleetScopeCount',
                            foreground: const Color(0xFF8FD1FF),
                            background: const Color(0x1A8FD1FF),
                            border: const Color(0x668FD1FF),
                          ),
                          if (_resolvedFocusReference.trim().isNotEmpty)
                            _focusPill(_resolvedFocusReference.trim()),
                        ],
                      ),
                    ] else ...[
                      Wrap(
                        spacing: 0.88,
                        runSpacing: 0.24,
                        children: [
                          Text(
                            widget.livePolling
                                ? 'Live poll active'
                                : 'Live poll paused',
                            style: GoogleFonts.inter(
                              color: widget.livePolling
                                  ? const Color(0xFF22D3EE)
                                  : const Color(0xFF94A3B8),
                              fontSize: 5.9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            widget.radioQueueHasPending
                                ? 'Radio queue pending'
                                : 'Radio queue clear',
                            style: GoogleFonts.inter(
                              color: widget.radioQueueHasPending
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF34D399),
                              fontSize: 5.9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Fleet $fleetScopeCount',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF8FD1FF),
                              fontSize: 5.9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (_resolvedFocusReference.trim().isNotEmpty)
                            Text(
                              'Focus ${switch (_focusState) {
                                _DispatchFocusState.exact => 'Linked',
                                _DispatchFocusState.scopeBacked => 'Scope-backed',
                                _DispatchFocusState.seeded => 'Seeded',
                                _DispatchFocusState.none => 'Idle',
                              }}: ${_resolvedFocusReference.trim()}',
                              style: GoogleFonts.inter(
                                color: switch (_focusState) {
                                  _DispatchFocusState.exact => const Color(
                                    0xFF22D3EE,
                                  ),
                                  _DispatchFocusState.scopeBacked =>
                                    const Color(0xFF8FD1FF),
                                  _DispatchFocusState.seeded => const Color(
                                    0xFFFACC15,
                                  ),
                                  _DispatchFocusState.none => const Color(
                                    0xFF9AB1CF,
                                  ),
                                },
                                fontSize: 5.9,
                                fontWeight: FontWeight.w800,
                              ),
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
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(workspaceBanner == null ? 0.84 : 0.72),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1A2B),
            borderRadius: BorderRadius.circular(4.25),
            border: Border.all(color: const Color(0xFF223244)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [titleBlock]),
                        const SizedBox(height: 0.15),
                        actionButton,
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleBlock,
                        const SizedBox(width: 1.75),
                        actionButton,
                      ],
                    ),
              if (workspaceBanner != null) ...[
                const SizedBox(height: 0.42),
                workspaceBanner,
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _heroChip({
    required String label,
    required Color foreground,
    required Color background,
    required Color border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2.1, vertical: 0.88),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: foreground,
          fontSize: 6.2,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _focusPill(String focusReference) {
    final color = switch (_focusState) {
      _DispatchFocusState.exact => const Color(0xFF22D3EE),
      _DispatchFocusState.scopeBacked => const Color(0xFF8FD1FF),
      _DispatchFocusState.seeded => const Color(0xFFFACC15),
      _DispatchFocusState.none => const Color(0xFF9AB1CF),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2.1, vertical: 0.88),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        'Focus ${switch (_focusState) {
          _DispatchFocusState.exact => 'Linked',
          _DispatchFocusState.scopeBacked => 'Scope-backed',
          _DispatchFocusState.seeded => 'Seeded',
          _DispatchFocusState.none => 'Idle',
        }}: $focusReference',
        style: GoogleFonts.inter(
          color: color,
          fontSize: 6.2,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _kpiBand({
    required int activeDispatches,
    required int pendingDispatches,
  }) {
    final cards = [
      _KpiCardSpec(
        label: 'ACTIVE DISPATCHES',
        value: '$activeDispatches',
        icon: Icons.send_rounded,
        valueColor: const Color(0xFF10B981),
        borderColor: const Color(0x5538C98B),
      ),
      _KpiCardSpec(
        label: 'PENDING QUEUE',
        value: '$pendingDispatches',
        icon: Icons.schedule_rounded,
        valueColor: pendingDispatches > 0
            ? const Color(0xFFF59E0B)
            : const Color(0xFF8EA4C2),
        borderColor: pendingDispatches > 0
            ? const Color(0x55F59E0B)
            : const Color(0x332B425F),
      ),
      _KpiCardSpec(
        label: 'AVG RESPONSE TIME',
        value: _averageResponseTimeLabel(widget.events),
        icon: Icons.speed_rounded,
        valueColor: const Color(0xFF22D3EE),
        borderColor: const Color(0x553DB8D7),
      ),
      _KpiCardSpec(
        label: 'OFFICERS AVAILABLE',
        value: '${_officersAvailable()}',
        icon: Icons.radio_rounded,
        valueColor: const Color(0xFF10B981),
        borderColor: const Color(0x5538C98B),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1200;
        if (compact) {
          return Column(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                _kpiCard(cards[i]),
                if (i != cards.length - 1) const SizedBox(height: 3.0),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              Expanded(child: _kpiCard(cards[i])),
              if (i != cards.length - 1) const SizedBox(width: 3.0),
            ],
          ],
        );
      },
    );
  }

  Widget _kpiCard(_KpiCardSpec spec) {
    return Container(
      padding: const EdgeInsets.all(2.75),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(5.5),
        border: Border.all(color: spec.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(spec.icon, size: 13.5, color: const Color(0xFF9AB1CF)),
              const SizedBox(width: 2.75),
              Text(
                spec.label,
                style: GoogleFonts.inter(
                  color: const Color(0x7FFFFFFF),
                  fontSize: 7.8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
          const SizedBox(height: 1.75),
          Text(
            spec.value,
            style: GoogleFonts.rajdhani(
              color: spec.valueColor,
              fontSize: 16.4,
              height: 0.9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _commandActions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(1.2),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(5.5),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COMMAND ACTIONS',
            style: GoogleFonts.inter(
              color: const Color(0x7FFFFFFF),
              fontSize: 7.6,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 1.75),
          FilledButton.icon(
            onPressed: widget.onGenerate,
            icon: const Icon(Icons.auto_awesome_rounded, size: 16),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2B5E93),
              foregroundColor: const Color(0xFFEAF4FF),
              minimumSize: const Size.fromHeight(23),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5.5),
              ),
            ),
            label: Text(
              'Generate Dispatch',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 8.6,
              ),
            ),
          ),
          const SizedBox(height: 1.75),
          Wrap(
            spacing: 2.0,
            runSpacing: 2.0,
            children: [
              _secondaryActionButton(
                label: 'Ingest Live Feeds',
                icon: Icons.stream_rounded,
                onPressed: widget.onIngestFeeds,
              ),
              _secondaryActionButton(
                label: 'Ingest Radio Ops',
                icon: Icons.hearing_rounded,
                onPressed: widget.onIngestRadioOps,
              ),
              _secondaryActionButton(
                label: 'Ingest ${widget.videoOpsLabel} Events',
                icon: Icons.videocam_rounded,
                onPressed: widget.onIngestCctvEvents,
              ),
              _secondaryActionButton(
                label: 'Ingest Wearable Ops',
                icon: Icons.watch_rounded,
                onPressed: widget.onIngestWearableOps,
              ),
              _secondaryActionButton(
                label: 'Ingest News Intel',
                icon: Icons.newspaper_rounded,
                onPressed: widget.onIngestNews,
              ),
              _secondaryActionButton(
                label: 'Load Feed File',
                icon: Icons.upload_file_rounded,
                onPressed: widget.onLoadFeedFile,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _secondaryActionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14.5),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF8FD1FF),
        side: const BorderSide(color: Color(0xFF35506F)),
        padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 1.8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.5)),
      ),
      label: Text(
        label,
        style: GoogleFonts.inter(fontSize: 7.6, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _dispatchQueue({
    required GlobalKey selectedDispatchBoardKey,
    bool embeddedSurface = false,
  }) {
    final visibleDispatches = _visibleDispatches();
    final selectedDispatch = visibleDispatches.isEmpty
        ? null
        : _selectedDispatch(dispatches: visibleDispatches);
    final filters = Wrap(
      spacing: 3.0,
      runSpacing: 3.0,
      children: [
        _queueFilterChip(_DispatchLaneFilter.all, 'All'),
        _queueFilterChip(_DispatchLaneFilter.active, 'Active'),
        _queueFilterChip(_DispatchLaneFilter.pending, 'Pending'),
        _queueFilterChip(_DispatchLaneFilter.cleared, 'Cleared'),
      ],
    );
    final showQueueFilterStrip = !embeddedSurface;
    final header = !showQueueFilterStrip
        ? const SizedBox.shrink()
        : LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 860;
              final title = Text(
                'ACTIVE DISPATCH QUEUE',
                style: GoogleFonts.inter(
                  color: const Color(0x7FFFFFFF),
                  fontSize: 8.7,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              );
              final action = TextButton.icon(
                onPressed: widget.onGenerate,
                icon: const Icon(Icons.send_rounded, size: 15),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF8FD1FF),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4.2,
                    vertical: 2.8,
                  ),
                ),
                label: Text(
                  'NEW DISPATCH',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 8.3,
                  ),
                ),
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: title),
                        const SizedBox(width: 2.0),
                        action,
                      ],
                    ),
                    const SizedBox(height: 1.4),
                    filters,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  title,
                  const SizedBox(width: 3.4),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: filters,
                    ),
                  ),
                  const SizedBox(width: 3.0),
                  action,
                ],
              );
            },
          );

    Widget buildQueueBody() {
      if (visibleDispatches.isEmpty) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: const Color(0x33000000),
            borderRadius: BorderRadius.circular(8.5),
            border: Border.all(color: const Color(0xFF2A3D58)),
          ),
          child: Text(
            'No dispatches match the current lane filter right now.',
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontSize: 10.0,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 1160;
          final boundedHeight =
              constraints.hasBoundedHeight && constraints.maxHeight.isFinite;
          final useSplitScrollablePanels =
              embeddedSurface && boundedHeight && !compact;
          final detailBoardChild = selectedDispatch == null
              ? const SizedBox.shrink()
              : KeyedSubtree(
                  key: selectedDispatchBoardKey,
                  child: _selectedDispatchBoard(selectedDispatch),
                );

          if (embeddedSurface && compact && boundedHeight) {
            return ListView(
              primary: false,
              padding: EdgeInsets.zero,
              children: [
                if (selectedDispatch != null) ...[
                  detailBoardChild,
                  const SizedBox(height: 3.0),
                ],
                for (int i = 0; i < visibleDispatches.length; i++) ...[
                  _dispatchCard(visibleDispatches[i]),
                  if (i != visibleDispatches.length - 1)
                    const SizedBox(height: 3.0),
                ],
              ],
            );
          }

          final queueList = useSplitScrollablePanels
              ? ListView.separated(
                  primary: false,
                  padding: EdgeInsets.zero,
                  itemCount: visibleDispatches.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 3.0),
                  itemBuilder: (context, index) =>
                      _dispatchCard(visibleDispatches[index]),
                )
              : Column(
                  children: [
                    for (int i = 0; i < visibleDispatches.length; i++) ...[
                      _dispatchCard(visibleDispatches[i]),
                      if (i != visibleDispatches.length - 1)
                        const SizedBox(height: 2.5),
                    ],
                  ],
                );
          final detailBoard = selectedDispatch == null
              ? const SizedBox.shrink()
              : useSplitScrollablePanels
              ? ListView(
                  primary: false,
                  padding: EdgeInsets.zero,
                  children: [detailBoardChild],
                )
              : detailBoardChild;

          if (compact || !useSplitScrollablePanels) {
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [detailBoard, const SizedBox(height: 3.0), queueList],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: queueList),
                const SizedBox(width: 2.0),
                Expanded(flex: 6, child: detailBoard),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 6,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: queueList,
                ),
              ),
              const SizedBox(width: 2.0),
              Expanded(
                flex: 6,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: detailBoard,
                ),
              ),
            ],
          );
        },
      );
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showQueueFilterStrip) ...[header, const SizedBox(height: 0.85)],
        if (embeddedSurface)
          Expanded(child: buildQueueBody())
        else
          buildQueueBody(),
      ],
    );
    if (embeddedSurface) {
      return content;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(4.25),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: content,
    );
  }

  Widget _queueFilterChip(_DispatchLaneFilter filter, String label) {
    final active = _dispatchLaneFilter == filter;
    final count = _dispatchCountForFilter(filter);
    final accent = switch (filter) {
      _DispatchLaneFilter.all => const Color(0xFF8FD1FF),
      _DispatchLaneFilter.active => const Color(0xFF22D3EE),
      _DispatchLaneFilter.pending => const Color(0xFFF59E0B),
      _DispatchLaneFilter.cleared => const Color(0xFF86EFAC),
    };
    return InkWell(
      key: ValueKey<String>('dispatch-queue-filter-${filter.name}'),
      onTap: () => _setDispatchLaneFilter(filter),
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.8),
        decoration: BoxDecoration(
          color: active
              ? accent.withValues(alpha: 0.16)
              : const Color(0xFF111826),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active
                ? accent.withValues(alpha: 0.85)
                : accent.withValues(alpha: 0.38),
          ),
        ),
        child: Text(
          '$label • $count',
          style: GoogleFonts.inter(
            color: accent,
            fontSize: 7.2,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _selectedDispatchBoard(_DispatchItem dispatch) {
    final statusStyle = _statusStyle(dispatch.status);
    final priorityStyle = _priorityStyle(dispatch.priority);
    final partnerProgress = _partnerDispatchProgressSummary(dispatch.id);
    final partnerTrend = partnerProgress == null
        ? null
        : _partnerTrendSummary(partnerProgress);
    final linkedScope = _linkedFleetScopeForDispatch(dispatch);
    final linkedFocus = _resolvedFocusReference.trim() == dispatch.id;
    final openReportAvailable =
        widget.onOpenReportForDispatch != null && !dispatch.isSeededPlaceholder;
    final primaryScopeAction =
        linkedScope != null && linkedScope.hasIncidentContext
        ? (widget.onOpenFleetDispatchScope ?? widget.onOpenFleetTacticalScope)
        : null;
    final waitingAssignment = dispatch.status == _DispatchStatus.pending;
    final partnerAccepted = partnerProgress
        ?.firstOccurrenceByStatus[PartnerDispatchStatus.accepted];
    final partnerOnSite =
        partnerProgress?.firstOccurrenceByStatus[PartnerDispatchStatus.onSite];
    final handoffReady = dispatch.status == _DispatchStatus.cleared;

    return Container(
      key: const ValueKey('dispatch-selected-board'),
      width: double.infinity,
      padding: const EdgeInsets.all(3.0),
      decoration: BoxDecoration(
        color: const Color(0xFF101722),
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: const Color(0xFF223244)),
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
                      'SELECTED DISPATCH',
                      style: GoogleFonts.inter(
                        color: const Color(0x7FFFFFFF),
                        fontSize: 8.3,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      dispatch.id,
                      style: GoogleFonts.rajdhani(
                        color: const Color(0xFFEAF4FF),
                        fontSize: 17.4,
                        height: 0.92,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1.5),
                    Text(
                      dispatch.site,
                      style: GoogleFonts.inter(
                        color: const Color(0xFFEAF4FF),
                        fontSize: 8.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 3.5),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _statusChip(dispatch.status),
                  if (linkedFocus) ...[
                    const SizedBox(height: 2.0),
                    _heroChip(
                      label: 'Focus Linked',
                      foreground: const Color(0xFF8FD1FF),
                      background: const Color(0x1A8FD1FF),
                      border: const Color(0x668FD1FF),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 2.0),
          Wrap(
            spacing: 3.0,
            runSpacing: 3.0,
            children: [
              _dispatchBoardTag(
                'Priority',
                priorityStyle.label,
                priorityStyle.color,
              ),
              _dispatchBoardTag('Type', dispatch.type, const Color(0xFF8FD1FF)),
              _dispatchBoardTag(
                'Officer',
                dispatch.officer,
                waitingAssignment
                    ? const Color(0xFFFDE68A)
                    : const Color(0xFF86EFAC),
              ),
              _dispatchBoardTag(
                'Dispatched',
                dispatch.dispatchTime,
                const Color(0xFF9AB1CF),
              ),
              if (dispatch.eta != null)
                _dispatchBoardTag(
                  'ETA',
                  dispatch.eta!,
                  const Color(0xFF22D3EE),
                ),
              if (dispatch.distance != null)
                _dispatchBoardTag(
                  'Distance',
                  dispatch.distance!,
                  const Color(0xFF9AB1CF),
                ),
            ],
          ),
          const SizedBox(height: 3.0),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(3.0),
            decoration: BoxDecoration(
              color: const Color(0xFF0C1117),
              borderRadius: BorderRadius.circular(6.0),
              border: Border.all(color: const Color(0xFF23344C)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MISSION BOARD',
                  style: GoogleFonts.inter(
                    color: const Color(0x7FFFFFFF),
                    fontSize: 7.6,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 1.5),
                Text(
                  _dispatchNarrative(dispatch, partnerProgress, linkedScope),
                  style: GoogleFonts.inter(
                    color: const Color(0xFFDCE8F8),
                    fontSize: 8.4,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (partnerTrend != null) ...[
                  const SizedBox(height: 2.0),
                  Text(
                    '${partnerTrend.currentScoreLabel} partner posture • ${partnerTrend.trendLabel.toUpperCase()} over ${partnerTrend.reportDays}d',
                    style: GoogleFonts.inter(
                      color: _partnerTrendColor(partnerTrend.trendLabel),
                      fontSize: 8.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 2.0),
          Text(
            'RESPONSE RUNWAY',
            style: GoogleFonts.inter(
              color: const Color(0x7FFFFFFF),
              fontSize: 8.8,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 2.0),
          _dispatchBoardRunwayStep(
            label: 'Dispatch queued',
            detail: 'Controller created this lane at ${dispatch.dispatchTime}.',
            accent: const Color(0xFF8FD1FF),
            complete: true,
            active: false,
          ),
          const SizedBox(height: 2.0),
          _dispatchBoardRunwayStep(
            label: waitingAssignment ? 'Awaiting assignment' : 'Unit assigned',
            detail: waitingAssignment
                ? 'Dispatch is waiting for officer commitment on this lane.'
                : 'Primary responder ${dispatch.officer} owns the current lane.',
            accent: waitingAssignment
                ? const Color(0xFFF59E0B)
                : const Color(0xFF22D3EE),
            complete: !waitingAssignment,
            active: waitingAssignment,
          ),
          const SizedBox(height: 2.0),
          _dispatchBoardRunwayStep(
            label: partnerOnSite != null
                ? 'On-site confirmed'
                : partnerAccepted != null ||
                      dispatch.status == _DispatchStatus.enRoute
                ? 'Partner / route tracking'
                : 'Travel window idle',
            detail: partnerOnSite != null
                ? 'Responder reached site at ${_clockLabel(partnerOnSite.toLocal())}.'
                : partnerAccepted != null
                ? 'Partner accepted at ${_clockLabel(partnerAccepted.toLocal())}; maintain live tracking.'
                : dispatch.eta != null
                ? 'Travel window is still in motion. Current ETA ${dispatch.eta}.'
                : 'Waiting for travel telemetry or partner progression.',
            accent: partnerOnSite != null
                ? const Color(0xFF86EFAC)
                : const Color(0xFFF59E0B),
            complete: partnerOnSite != null,
            active: partnerOnSite == null,
          ),
          const SizedBox(height: 2.0),
          _dispatchBoardRunwayStep(
            label: handoffReady
                ? 'Report handoff ready'
                : 'Report handoff staged',
            detail: handoffReady
                ? 'Dispatch is cleared and report export is ready for review.'
                : openReportAvailable
                ? 'Report shell can open now for mid-incident review and receipt prep.'
                : 'Report handoff will unlock once a live dispatch is available.',
            accent: handoffReady
                ? const Color(0xFF86EFAC)
                : const Color(0xFF8EA4C2),
            complete: handoffReady,
            active: !handoffReady && openReportAvailable,
          ),
          if (partnerProgress != null) ...[
            const SizedBox(height: 2.0),
            Text(
              'PARTNER PROGRESSION',
              style: GoogleFonts.inter(
                color: const Color(0x7FFFFFFF),
                fontSize: 8.8,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 2.0),
            Wrap(
              spacing: 3.0,
              runSpacing: 3.0,
              children: [
                for (final status in PartnerDispatchStatus.values)
                  _partnerProgressBadge(
                    dispatchId: dispatch.id,
                    status: status,
                    timestamp: partnerProgress.firstOccurrenceByStatus[status],
                  ),
              ],
            ),
          ],
          if (linkedScope != null) ...[
            const SizedBox(height: 2.0),
            _dispatchScopeSummaryCard(linkedScope),
          ],
          const SizedBox(height: 2.0),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 460;
              final primaryButton = FilledButton.icon(
                onPressed: () => _handleDispatchAction(dispatch),
                style: FilledButton.styleFrom(
                  backgroundColor: statusStyle.actionColor.withValues(
                    alpha: 0.22,
                  ),
                  foregroundColor: statusStyle.actionColor,
                  padding: const EdgeInsets.symmetric(vertical: 7.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.5),
                  ),
                ),
                icon: Icon(statusStyle.icon, size: 16),
                label: Text(
                  statusStyle.actionLabel,
                  style: GoogleFonts.inter(
                    fontSize: 10.0,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
              final secondaryButtons = <Widget>[
                if (openReportAvailable)
                  _dispatchBoardActionButton(
                    label: 'Open Report',
                    icon: Icons.description_rounded,
                    foreground: const Color(0xFF8FD1FF),
                    onPressed: () =>
                        widget.onOpenReportForDispatch!.call(dispatch.id),
                  ),
                if (primaryScopeAction != null)
                  _dispatchBoardActionButton(
                    label: 'Open Scope',
                    icon: Icons.center_focus_strong_rounded,
                    foreground: const Color(0xFFFDE68A),
                    onPressed: () => primaryScopeAction.call(
                      linkedScope!.clientId,
                      linkedScope.siteId,
                      linkedScope.latestIncidentReference,
                    ),
                  ),
              ];
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    primaryButton,
                    for (final button in secondaryButtons) ...[
                      const SizedBox(height: 4.5),
                      button,
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: primaryButton),
                  for (final button in secondaryButtons) ...[
                    const SizedBox(width: 4.5),
                    Expanded(child: button),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _dispatchBoardTag(String label, String value, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5.75, vertical: 3.0),
      decoration: BoxDecoration(
        color: const Color(0xFF111826),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.48)),
      ),
      child: Text(
        '$label • $value',
        style: GoogleFonts.inter(
          color: accent,
          fontSize: 8.2,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _dispatchBoardRunwayStep({
    required String label,
    required String detail,
    required Color accent,
    required bool complete,
    required bool active,
  }) {
    final icon = complete
        ? Icons.check_circle_rounded
        : active
        ? Icons.radio_button_checked_rounded
        : Icons.circle_outlined;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: active
            ? accent.withValues(alpha: 0.12)
            : const Color(0xFF111826),
        borderRadius: BorderRadius.circular(7.0),
        border: Border.all(
          color: complete || active
              ? accent.withValues(alpha: 0.65)
              : const Color(0xFF23344C),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 13.0,
            color: complete || active ? accent : const Color(0xFF60748E),
          ),
          const SizedBox(width: 4.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: complete || active
                        ? const Color(0xFFEAF4FF)
                        : const Color(0xFF9AB1CF),
                    fontSize: 9.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 0.75),
                Text(
                  detail,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9AB1CF),
                    fontSize: 8.2,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _dispatchNarrative(
    _DispatchItem dispatch,
    _PartnerDispatchProgressSummary? partnerProgress,
    VideoFleetScopeHealthView? linkedScope,
  ) {
    final parts = <String>[
      '${dispatch.type} coverage is centered on ${dispatch.site}.',
    ];
    switch (dispatch.status) {
      case _DispatchStatus.pending:
        parts.add('Lane is staged and waiting for officer assignment.');
        break;
      case _DispatchStatus.enRoute:
        parts.add(
          dispatch.eta == null
              ? 'Responder is committed and moving toward the site.'
              : 'Responder is committed with ${dispatch.eta} remaining.',
        );
        break;
      case _DispatchStatus.onSite:
        parts.add(
          'Responder is on-site and the command body is in verification mode.',
        );
        break;
      case _DispatchStatus.cleared:
        parts.add('Lane is cleared and ready for report handoff.');
        break;
    }
    if (partnerProgress != null) {
      parts.add(
        '${partnerProgress.partnerLabel} is ${_partnerDispatchStatusLabel(partnerProgress.latestStatus).toLowerCase()} after ${partnerProgress.declarationCount} progression updates.',
      );
    }
    if (linkedScope != null) {
      parts.add(
        '${linkedScope.siteName} watch is ${linkedScope.watchLabel.toLowerCase()} with ${linkedScope.recentEvents} recent ${widget.videoOpsLabel.toLowerCase()} events.',
      );
      final latestSummary = linkedScope.latestSummaryText;
      if (latestSummary != null) {
        parts.add(latestSummary);
      }
    }
    return parts.join(' ');
  }

  VideoFleetScopeHealthView? _linkedFleetScopeForDispatch(
    _DispatchItem dispatch,
  ) {
    final dispatchSite = dispatch.site.trim().toLowerCase();
    if (dispatchSite.isEmpty) {
      return null;
    }
    for (final scope in widget.fleetScopeHealth) {
      final scopeSiteId = scope.siteId.trim().toLowerCase();
      final scopeSiteName = scope.siteName.trim().toLowerCase();
      if (scopeSiteId == dispatchSite || scopeSiteName == dispatchSite) {
        return scope;
      }
    }
    return null;
  }

  Widget _dispatchScopeSummaryCard(VideoFleetScopeHealthView scope) {
    final latestSummary =
        scope.latestSummaryText ??
        scope.noteText ??
        'Fleet scope is linked without additional scene detail yet.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1117),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF23344C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LINKED ${widget.videoOpsLabel.toUpperCase()} SCOPE',
            style: GoogleFonts.inter(
              color: const Color(0x7FFFFFFF),
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              _dispatchBoardTag(
                'Site',
                scope.siteName,
                const Color(0xFF8FD1FF),
              ),
              _dispatchBoardTag(
                'Status',
                scope.statusLabel,
                const Color(0xFF86EFAC),
              ),
              _dispatchBoardTag(
                'Watch',
                scope.watchLabel,
                const Color(0xFFFDE68A),
              ),
              if ((scope.latestCameraLabel ?? '').trim().isNotEmpty)
                _dispatchBoardTag(
                  'Camera',
                  scope.latestCameraLabel!,
                  const Color(0xFF9AB1CF),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            latestSummary,
            style: GoogleFonts.inter(
              color: const Color(0xFFCAD7E8),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dispatchBoardActionButton({
    required String label,
    required IconData icon,
    required Color foreground,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        side: BorderSide(color: foreground.withValues(alpha: 0.46)),
        padding: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _dispatchCard(_DispatchItem dispatch) {
    final selected = dispatch.id == _selectedDispatchId;
    final statusStyle = _statusStyle(dispatch.status);
    final priorityStyle = _priorityStyle(dispatch.priority);
    final partnerProgress = _partnerDispatchProgressSummary(dispatch.id);
    final partnerTrend = partnerProgress == null
        ? null
        : _partnerTrendSummary(partnerProgress);

    return InkWell(
      onTap: () => _setSelectedDispatchId(dispatch.id),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        key: ValueKey<String>('dispatch-card-${dispatch.id}'),
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected ? const Color(0x1A22D3EE) : const Color(0xFF0F1419),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0x8022D3EE) : const Color(0x332B425F),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: statusStyle.iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                statusStyle.icon,
                color: statusStyle.iconColor,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          dispatch.id,
                          style: GoogleFonts.rajdhani(
                            color: const Color(0xFFEAF4FF),
                            fontSize: 24,
                            height: 0.9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _statusChip(dispatch.status),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 8,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        dispatch.site,
                        style: GoogleFonts.inter(
                          color: const Color(0xFFE5EFFF),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        priorityStyle.label,
                        style: GoogleFonts.inter(
                          color: priorityStyle.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (dispatch.isSeededPlaceholder)
                        Text(
                          'SEEDED',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFFACC15),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _metaItem('Type', dispatch.type),
                      _metaItem('Officer', dispatch.officer),
                      _metaItem('Dispatched', dispatch.dispatchTime),
                      if (dispatch.eta != null)
                        _metaItem(
                          'ETA',
                          dispatch.eta!,
                          color: const Color(0xFF22D3EE),
                        ),
                      if (dispatch.distance != null)
                        _metaItem('Distance', dispatch.distance!),
                    ],
                  ),
                  if (selected && partnerProgress != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      key: ValueKey<String>(
                        'dispatch-partner-progress-card-${dispatch.id}',
                      ),
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C1117),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF223244)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PARTNER PROGRESSION',
                            style: GoogleFonts.inter(
                              color: const Color(0x7FFFFFFF),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${partnerProgress.partnerLabel} • Latest ${_partnerDispatchStatusLabel(partnerProgress.latestStatus)} • ${_clockLabel(partnerProgress.latestOccurredAt.toLocal())}',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFEAF4FF),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              _metaItem(
                                'Declarations',
                                '${partnerProgress.declarationCount}',
                              ),
                              _metaItem(
                                'Dispatch',
                                '$dispatch.id',
                                color: const Color(0xFF8FD1FF),
                              ),
                              if (partnerTrend != null)
                                _metaItem(
                                  '7D Trend',
                                  '${partnerTrend.trendLabel} • ${partnerTrend.reportDays}d',
                                  color: _partnerTrendColor(
                                    partnerTrend.trendLabel,
                                  ),
                                ),
                            ],
                          ),
                          if (partnerTrend != null) ...[
                            const SizedBox(height: 5),
                            Text(
                              partnerTrend.trendReason,
                              key: ValueKey<String>(
                                'dispatch-partner-trend-reason-${dispatch.id}',
                              ),
                              style: GoogleFonts.inter(
                                color: _partnerTrendColor(
                                  partnerTrend.trendLabel,
                                ),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final status in PartnerDispatchStatus.values)
                                _partnerProgressBadge(
                                  dispatchId: dispatch.id,
                                  status: status,
                                  timestamp: partnerProgress
                                      .firstOccurrenceByStatus[status],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _handleDispatchAction(dispatch),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: statusStyle.actionColor,
                        side: BorderSide(color: statusStyle.actionColor),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        statusStyle.actionLabel,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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

  Widget _metaItem(String label, String value, {Color? color}) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.inter(
          color: const Color(0xFF9AB1CF),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        children: [
          TextSpan(text: '$label: '),
          TextSpan(
            text: value,
            style: GoogleFonts.inter(
              color: color ?? const Color(0xFFD7E8FF),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(_DispatchStatus status) {
    final style = _statusStyle(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: style.chipBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: style.chipBorder),
      ),
      child: Text(
        style.label,
        style: GoogleFonts.inter(
          color: style.chipFg,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _partnerProgressBadge({
    required String dispatchId,
    required PartnerDispatchStatus status,
    required DateTime? timestamp,
  }) {
    final reached = timestamp != null;
    final tone = _partnerProgressTone(status);
    return Container(
      key: ValueKey<String>(
        'dispatch-partner-progress-$dispatchId-${status.name}',
      ),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: reached ? tone.$2 : const Color(0xFF111822),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: reached ? tone.$3 : const Color(0xFF2A374A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _partnerDispatchStatusLabel(status),
            style: GoogleFonts.inter(
              color: reached ? tone.$1 : const Color(0xFF94A3B8),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            reached ? _clockLabel(timestamp.toLocal()) : 'Pending',
            style: GoogleFonts.inter(
              color: reached
                  ? const Color(0xFFEAF4FF)
                  : const Color(0xFF8EA4C2),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
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

  Widget _systemStatusPanel({
    required GlobalKey fleetPanelKey,
    required GlobalKey suppressedPanelKey,
    required VoidCallback onOpenDispatchBoard,
    required VoidCallback onOpenCommandActions,
    required VoidCallback onOpenFleetWatch,
    required VoidCallback onOpenSuppressedReviews,
    required List<_SuppressedDispatchReviewEntry> suppressedEntries,
    bool summaryOnly = false,
    required void Function(VideoFleetWatchActionDrilldown drilldown)
    onOpenWatchActionDrilldown,
    required void Function(VideoFleetScopeHealthView scope)
    onOpenLatestWatchActionDetail,
  }) {
    final showSuppressedPrimary =
        _activeWatchActionDrilldown ==
            VideoFleetWatchActionDrilldown.filtered &&
        suppressedEntries.isNotEmpty;
    final showEscalatedPrimary =
        _activeWatchActionDrilldown == VideoFleetWatchActionDrilldown.escalated;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SYSTEM STATUS',
            style: GoogleFonts.inter(
              color: const Color(0x7FFFFFFF),
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          _dispatchWorkspaceCommandReceipt(),
          if (showEscalatedPrimary && widget.fleetScopeHealth.isNotEmpty) ...[
            const SizedBox(height: 3),
            KeyedSubtree(
              key: fleetPanelKey,
              child: _fleetScopePanel(
                onOpenWatchActionDrilldown: onOpenWatchActionDrilldown,
                onOpenLatestWatchActionDetail: onOpenLatestWatchActionDetail,
              ),
            ),
          ],
          const SizedBox(height: 2),
          _statusSection(
            title: 'Transport & Intake',
            pill: _statePill('OPERATIONAL', const Color(0xFF10B981)),
            child: Column(
              children: const [
                _MetricRow(label: 'Vehicles Ready', value: '12 / 14'),
                _MetricRow(label: 'Officers On Duty', value: '18 / 20'),
                _MetricRow(
                  label: 'Fuel Status',
                  value: 'Optimal',
                  valueColor: Color(0xFF10B981),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          _statusSection(
            title: 'Communication Systems',
            pill: _statePill(
              widget.radioOpsReadiness == 'UNCONFIGURED' &&
                      widget.cctvOpsReadiness == 'UNCONFIGURED'
                  ? 'PARTIAL'
                  : 'HEALTHY',
              widget.radioOpsReadiness == 'UNCONFIGURED' &&
                      widget.cctvOpsReadiness == 'UNCONFIGURED'
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFF10B981),
            ),
            child: Column(
              children: [
                _BulletLine(
                  title: 'Radio Ops • ${widget.radioOpsReadiness}',
                  detail: widget.radioOpsDetail,
                ),
                _BulletLine(
                  title: 'Radio Queue',
                  detail: widget.radioOpsQueueHealth,
                ),
                _BulletLine(
                  title: 'Radio Queue Intent Mix',
                  detail: widget.radioQueueIntentMix,
                ),
                _BulletLine(
                  title: 'Radio ACK Recent',
                  detail: widget.radioAckRecentSummary,
                ),
                _BulletLine(
                  title: 'Radio Queue Failure',
                  detail: widget.radioQueueFailureDetail,
                ),
                _BulletLine(
                  title: 'Radio Queue Manual',
                  detail: widget.radioQueueManualActionDetail,
                ),
                const SizedBox(height: 4),
                _radioQueueActions(),
                _BulletLine(
                  title:
                      '${widget.videoOpsLabel} Ops • ${widget.cctvOpsReadiness}',
                  detail: widget.cctvOpsDetail,
                ),
                _BulletLine(
                  title: '${widget.videoOpsLabel} Capabilities',
                  detail: widget.cctvCapabilitySummary,
                ),
                _BulletLine(
                  title: '${widget.videoOpsLabel} Signals Recent',
                  detail: widget.cctvRecentSignalSummary,
                ),
                if (showSuppressedPrimary) ...[
                  const SizedBox(height: 4),
                  KeyedSubtree(
                    key: suppressedPanelKey,
                    child: _suppressedReviewPanel(suppressedEntries),
                  ),
                ],
                if (!showEscalatedPrimary &&
                    widget.fleetScopeHealth.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  KeyedSubtree(
                    key: fleetPanelKey,
                    child: _fleetScopePanel(
                      onOpenWatchActionDrilldown: onOpenWatchActionDrilldown,
                      onOpenLatestWatchActionDetail:
                          onOpenLatestWatchActionDetail,
                    ),
                  ),
                ],
                if (!showSuppressedPrimary && suppressedEntries.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  KeyedSubtree(
                    key: suppressedPanelKey,
                    child: _suppressedReviewPanel(suppressedEntries),
                  ),
                ],
                _BulletLine(
                  title: 'Wearable Ops • ${widget.wearableOpsReadiness}',
                  detail: widget.wearableOpsDetail,
                ),
                _BulletLine(
                  title: 'AI Radio Clearance',
                  detail: widget.radioAiAutoAllClearEnabled
                      ? 'Enabled for all-clear phrases (controller override still available).'
                      : 'Disabled: controller confirmation required.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          _statusSection(
            title: 'Command Actions',
            child: summaryOnly
                ? Text(
                    suppressedEntries.isNotEmpty
                        ? 'Selected-dispatch focus, filtered watch review, and top-deck ingest controls stay pinned in the mission board, suppressed-review lane, and command deck above so this rail can stay status-first.'
                        : 'Selected-dispatch focus, fleet watch review, and top-deck ingest controls stay pinned in the mission board, fleet-watch rail, and command deck above so this rail can stay status-first.',
                    style: GoogleFonts.inter(
                      color: const Color(0x99FFFFFF),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  )
                : Column(
                    children: [
                      _panelButton(
                        label: 'PRIME SELECTED DISPATCH',
                        detail:
                            'Jump back to the focused dispatch board and action runway.',
                        icon: Icons.center_focus_strong_rounded,
                        onPressed: onOpenDispatchBoard,
                      ),
                      const SizedBox(height: 4),
                      _panelButton(
                        label: suppressedEntries.isNotEmpty
                            ? 'REVIEW FILTERED WATCH'
                            : 'OPEN FLEET WATCH',
                        detail: suppressedEntries.isNotEmpty
                            ? 'Open the suppressed review lane for held ${widget.videoOpsLabel.toLowerCase()} actions.'
                            : 'Jump to the fleet watch body and active scope cards.',
                        icon: suppressedEntries.isNotEmpty
                            ? Icons.visibility_off_rounded
                            : Icons.videocam_rounded,
                        onPressed: suppressedEntries.isNotEmpty
                            ? onOpenSuppressedReviews
                            : onOpenFleetWatch,
                      ),
                      const SizedBox(height: 4),
                      _panelButton(
                        label: 'OPEN COMMAND ACTIONS',
                        detail:
                            'Return to ingest, generate, and feed controls at the top of the page.',
                        icon: Icons.rocket_launch_rounded,
                        onPressed: onOpenCommandActions,
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 4),
          _statusSection(
            title: 'Response Time Breakdown',
            child: const Column(
              children: [
                _BreakdownRow(
                  label: 'P1 Critical',
                  value: '4.2 min avg',
                  width: 0.85,
                  color: Color(0xFF10B981),
                ),
                SizedBox(height: 5),
                _BreakdownRow(
                  label: 'P2 High',
                  value: '8.1 min avg',
                  width: 0.65,
                  color: Color(0xFFF59E0B),
                ),
                SizedBox(height: 5),
                _BreakdownRow(
                  label: 'P3 Medium',
                  value: '12.4 min avg',
                  width: 0.50,
                  color: Color(0xFF22D3EE),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dispatchWorkspaceCommandReceipt() {
    final receipt = _commandReceipt;
    return Container(
      key: const ValueKey('dispatch-workspace-command-receipt'),
      width: double.infinity,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1117),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: receipt.accent.withValues(alpha: 0.42)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LATEST COMMAND',
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: receipt.accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: receipt.accent.withValues(alpha: 0.45)),
            ),
            child: Text(
              receipt.label,
              style: GoogleFonts.inter(
                color: receipt.accent,
                fontSize: 8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            receipt.headline,
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFEAF4FF),
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            receipt.detail,
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  List<_SuppressedDispatchReviewEntry> _suppressedDispatchReviewEntries() {
    final output = <_SuppressedDispatchReviewEntry>[];
    for (final scope in widget.fleetScopeHealth) {
      if (!scope.hasSuppressedSceneAction) {
        continue;
      }
      final intelligenceId = (scope.latestIncidentReference ?? '').trim();
      if (intelligenceId.isEmpty) {
        continue;
      }
      final review = widget.sceneReviewByIntelligenceId[intelligenceId];
      if (review == null) {
        continue;
      }
      output.add(_SuppressedDispatchReviewEntry(scope: scope, review: review));
    }
    output.sort(
      (a, b) => b.review.reviewedAtUtc.compareTo(a.review.reviewedAtUtc),
    );
    return output.take(4).toList(growable: false);
  }

  Widget _suppressedReviewPanel(List<_SuppressedDispatchReviewEntry> entries) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1117),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x332B425F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Suppressed ${widget.videoOpsLabel} Reviews',
                style: GoogleFonts.inter(
                  color: const Color(0xFFEAF4FF),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              _statusBadge(
                'Internal',
                '${entries.length}',
                const Color(0xFF9AB1CF),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Recent ${widget.videoOpsLabel} reviews ONYX held below the client notification threshold while dispatch remained active.',
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          ...entries.asMap().entries.map((entry) {
            final item = entry.value;
            final scope = item.scope;
            final review = item.review;
            return Container(
              width: double.infinity,
              margin: EdgeInsets.only(
                bottom: entry.key == entries.length - 1 ? 0 : 5,
              ),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF101722),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: const Color(0x333A546E)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          scope.siteName,
                          style: GoogleFonts.inter(
                            color: const Color(0xFFEAF4FF),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _clockLabel(review.reviewedAtUtc.toLocal()),
                        style: GoogleFonts.robotoMono(
                          color: const Color(0xFF8EA4C2),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      _statusBadge(
                        'Action',
                        review.decisionLabel.trim().isEmpty
                            ? 'Suppressed'
                            : review.decisionLabel.trim(),
                        const Color(0xFFBFD7F2),
                      ),
                      if ((scope.latestCameraLabel ?? '').trim().isNotEmpty)
                        _statusBadge(
                          'Camera',
                          scope.latestCameraLabel!.trim(),
                          const Color(0xFF67E8F9),
                        ),
                      _statusBadge(
                        'Posture',
                        review.postureLabel.trim(),
                        const Color(0xFF86EFAC),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    review.decisionSummary.trim().isEmpty
                        ? 'Suppressed because the activity remained below threshold.'
                        : review.decisionSummary.trim(),
                    style: GoogleFonts.inter(
                      color: const Color(0xFFEAF4FF),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Scene review: ${review.summary.trim()}',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF9AB1CF),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _statusSection({
    required String title,
    required Widget child,
    Widget? pill,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1117),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x332B425F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 360;
              final titleWidget = Text(
                title.toUpperCase(),
                style: GoogleFonts.inter(
                  color: const Color(0xB3FFFFFF),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleWidget,
                    if (pill != null) ...[const SizedBox(height: 2), pill],
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: titleWidget),
                  ...?(pill != null ? [pill] : null),
                ],
              );
            },
          ),
          const SizedBox(height: 2),
          child,
        ],
      ),
    );
  }

  Widget _fleetScopePanel({
    required void Function(VideoFleetWatchActionDrilldown drilldown)
    onOpenWatchActionDrilldown,
    required void Function(VideoFleetScopeHealthView scope)
    onOpenLatestWatchActionDetail,
  }) {
    final sections = VideoFleetScopeHealthSections.fromScopes(
      widget.fleetScopeHealth,
    );
    final filteredSections = VideoFleetScopeHealthSections.fromScopes(
      orderFleetScopesForWatchAction(
        filterFleetScopesForWatchAction(
          widget.fleetScopeHealth,
          _activeWatchActionDrilldown,
        ),
        _activeWatchActionDrilldown,
      ),
    );
    final primaryFocusedScope = primaryFleetScopeForWatchAction(
      filteredSections,
      _activeWatchActionDrilldown,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_activeWatchActionDrilldown != null) ...[
          _watchActionFocusBanner(primaryFocusedScope),
          const SizedBox(height: 8),
        ],
        VideoFleetScopeHealthPanel(
          title: '${widget.videoOpsLabel} Fleet Health',
          titleStyle: GoogleFonts.inter(
            color: const Color(0xFFEAF4FF),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          sectionLabelStyle: GoogleFonts.inter(
            color: const Color(0xFF8EA4C2),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.9,
          ),
          sections: filteredSections,
          activeWatchActionDrilldown: _activeWatchActionDrilldown,
          summaryHeader: _fleetSummaryCommandDeck(
            sections: sections,
            activeWatchActionDrilldown: _activeWatchActionDrilldown,
            onFocusDrilldown: onOpenWatchActionDrilldown,
            onClearFocus: _activeWatchActionDrilldown == null
                ? null
                : () => _setActiveWatchActionDrilldown(null),
          ),
          summaryChildren: _fleetSummaryChips(
            sections: sections,
            onOpenWatchActionDrilldown: onOpenWatchActionDrilldown,
          ),
          actionableChildren: filteredSections.actionableScopes
              .map(
                (scope) => _fleetScopeCard(
                  scope,
                  onOpenLatestWatchActionDetail: onOpenLatestWatchActionDetail,
                ),
              )
              .toList(growable: false),
          watchOnlyChildren: filteredSections.watchOnlyScopes
              .map(
                (scope) => _fleetScopeCard(
                  scope,
                  onOpenLatestWatchActionDetail: onOpenLatestWatchActionDetail,
                ),
              )
              .toList(growable: false),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0E141D),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x334A5E78)),
          ),
          cardSpacing: 10,
          runSpacing: 10,
        ),
      ],
    );
  }

  Widget _fleetScopeCard(
    VideoFleetScopeHealthView scope, {
    required void Function(VideoFleetScopeHealthView scope)
    onOpenLatestWatchActionDetail,
  }) {
    final statusColor = switch (scope.statusLabel.toUpperCase()) {
      'LIVE' => const Color(0xFF10B981),
      'ACTIVE WATCH' => const Color(0xFF22D3EE),
      'LIMITED WATCH' => const Color(0xFFF59E0B),
      'WATCH READY' => const Color(0xFFF59E0B),
      _ => const Color(0xFF8EA4C2),
    };
    final watchColor = scope.watchLabel == 'LIMITED'
        ? const Color(0xFFF59E0B)
        : const Color(0xFF67E8F9);
    final phaseColor = (scope.watchWindowStateLabel ?? '').contains('LIMITED')
        ? const Color(0xFFF59E0B)
        : scope.watchWindowStateLabel == 'IN WINDOW'
        ? const Color(0xFF86EFAC)
        : const Color(0xFFFBBF24);
    final hasDispatchLane =
        scope.hasIncidentContext && widget.onOpenFleetDispatchScope != null;
    final hasTacticalLane =
        scope.hasIncidentContext && widget.onOpenFleetTacticalScope != null;
    final canRecoverCoverage =
        scope.hasWatchActivationGap && widget.onRecoverFleetWatchScope != null;
    final commandAccent = _fleetScopeCommandAccent(scope);
    final commandHeadline = _fleetScopeCommandHeadline(scope);
    final commandDetail = _fleetScopeCommandDetail(scope);
    final primaryActionLabel = canRecoverCoverage
        ? 'Resync coverage'
        : hasDispatchLane
        ? 'Open dispatch'
        : hasTacticalLane
        ? 'Open tactical'
        : 'Latest detail';
    final primaryActionColor = canRecoverCoverage
        ? const Color(0xFFFCA5A5)
        : hasDispatchLane
        ? const Color(0xFFFDE68A)
        : hasTacticalLane
        ? const Color(0xFF67E8F9)
        : const Color(0xFF8FD1FF);

    void openFleetDetail() {
      onOpenLatestWatchActionDetail(scope);
      _showDispatchFeedback(
        'Focused fleet scope detail for ${scope.siteName}.',
        label: 'FLEET DETAIL',
        detail:
            '${scope.siteName} stays pinned in the watch rail while the latest signal detail opens below it.',
        accent: const Color(0xFF8FD1FF),
      );
    }

    void openFleetDispatch() {
      if (!hasDispatchLane) {
        openFleetDetail();
        return;
      }
      widget.onOpenFleetDispatchScope!.call(
        scope.clientId,
        scope.siteId,
        scope.latestIncidentReference,
      );
      _showDispatchFeedback(
        'Opened ${scope.siteName} in dispatch lane.',
        label: 'DISPATCH HANDOFF',
        detail:
            '${scope.siteName} is now foregrounded in the incident-backed dispatch board.',
        accent: const Color(0xFFFDE68A),
      );
    }

    void openFleetTactical() {
      if (!hasTacticalLane) {
        openFleetDetail();
        return;
      }
      widget.onOpenFleetTacticalScope!.call(
        scope.clientId,
        scope.siteId,
        scope.latestIncidentReference,
      );
      _showDispatchFeedback(
        'Opened ${scope.siteName} in tactical lane.',
        label: 'TACTICAL HANDOFF',
        detail:
            '${scope.siteName} is now foregrounded in the scoped tactical workspace.',
        accent: const Color(0xFF67E8F9),
      );
    }

    void recoverFleetScope() {
      if (!canRecoverCoverage) {
        openFleetDetail();
        return;
      }
      widget.onRecoverFleetWatchScope!.call(scope.clientId, scope.siteId);
      _showDispatchFeedback(
        'Triggered coverage resync for ${scope.siteName}.',
        label: 'COVERAGE RESYNC',
        detail:
            '${scope.siteName} has been queued for watch-window recovery from the fleet command card.',
        accent: const Color(0xFFFCA5A5),
      );
    }

    return VideoFleetScopeHealthCard(
      key: ValueKey('dispatch-fleet-scope-card-${scope.siteId}'),
      headerChild: Container(
        key: ValueKey('dispatch-fleet-scope-command-${scope.siteId}'),
        width: double.infinity,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: const Color(0xFF111826),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: commandAccent.withValues(alpha: 0.36)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 124;
            final summary = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FLEET COMMAND',
                  style: GoogleFonts.inter(
                    color: commandAccent,
                    fontSize: 9.0,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  commandHeadline,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEAF4FF),
                    fontSize: 10.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1.5),
                Text(
                  commandDetail,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFCAD7E8),
                    fontSize: 9.8,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            );
            final nextMove = Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.5,
                vertical: 6.5,
              ),
              decoration: BoxDecoration(
                color: primaryActionColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: primaryActionColor.withValues(alpha: 0.42),
                ),
              ),
              child: Column(
                crossAxisAlignment: compact
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.end,
                children: [
                  Text(
                    'NEXT MOVE',
                    style: GoogleFonts.inter(
                      color: primaryActionColor,
                      fontSize: 8.4,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    primaryActionLabel,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFEAF4FF),
                      fontSize: 9.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [summary, const SizedBox(height: 6), nextMove],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: summary),
                const SizedBox(width: 8),
                Flexible(child: nextMove),
              ],
            );
          },
        ),
      ),
      identityChild: Container(
        key: ValueKey('dispatch-fleet-scope-identity-${scope.siteId}'),
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: commandAccent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: commandAccent.withValues(alpha: 0.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SCOPE IDENTITY',
              style: GoogleFonts.inter(
                color: commandAccent,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _statusBadge(
                  'Endpoint',
                  scope.endpointLabel,
                  const Color(0xFF9AB1CF),
                ),
                _statusBadge(
                  'Last seen',
                  scope.lastSeenLabel,
                  _fleetFreshnessColor(scope),
                ),
                if ((scope.latestIncidentReference ?? '').trim().isNotEmpty)
                  _statusBadge(
                    'Reference',
                    scope.latestIncidentReference!,
                    const Color(0xFFFDE68A),
                  ),
                if ((scope.latestCameraLabel ?? '').trim().isNotEmpty)
                  _statusBadge(
                    'Camera',
                    scope.latestCameraLabel!,
                    const Color(0xFF9AB1CF),
                  ),
                if (!scope.hasIncidentContext)
                  _statusBadge('Context', 'Pending', const Color(0xFFFBBF24)),
              ],
            ),
          ],
        ),
      ),
      hideDefaultEndpoint: true,
      hideDefaultLastSeen: true,
      title: scope.siteName,
      endpointLabel: scope.endpointLabel,
      lastSeenLabel: ': ${scope.lastSeenLabel}',
      titleStyle: GoogleFonts.inter(
        color: const Color(0xFFEAF4FF),
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      endpointStyle: GoogleFonts.inter(
        color: const Color(0xFF8EA4C2),
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
      lastSeenStyle: GoogleFonts.inter(
        color: const Color(0xFF9AB1CF),
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      statusDetailStyle: GoogleFonts.inter(
        color: const Color(0xFFFDE68A),
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
      noteStyle: GoogleFonts.inter(
        color: const Color(0xFF9AB1CF),
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
      latestStyle: GoogleFonts.inter(
        color: const Color(0xFFEAF4FF),
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      primaryGroupLabel: 'COMMAND POSTURE',
      primaryGroupAccent: commandAccent,
      primaryGroupKey: ValueKey('dispatch-fleet-scope-posture-${scope.siteId}'),
      contextGroupLabel: 'WATCH CONTEXT',
      contextGroupAccent: const Color(0xFFFDE68A),
      contextGroupKey: ValueKey('dispatch-fleet-scope-context-${scope.siteId}'),
      latestGroupLabel: 'LATEST SIGNAL',
      latestGroupAccent: const Color(0xFF67E8F9),
      latestGroupKey: ValueKey('dispatch-fleet-scope-latest-${scope.siteId}'),
      secondaryGroupLabel: 'LIVE FEED',
      secondaryGroupAccent: const Color(0xFF8FD1FF),
      secondaryGroupKey: ValueKey('dispatch-fleet-scope-feed-${scope.siteId}'),
      actionsGroupLabel: 'COMMAND ACTIONS',
      actionsGroupAccent: primaryActionColor,
      actionsGroupKey: ValueKey('dispatch-fleet-scope-actions-${scope.siteId}'),
      primaryChips: [
        if ((scope.operatorOutcomeLabel ?? '').trim().isNotEmpty)
          _statusBadge(
            'Cue',
            scope.operatorOutcomeLabel!,
            const Color(0xFF67E8F9),
          ),
        if ((scope.operatorOutcomeLabel ?? '').trim().isEmpty &&
            (scope.lastRecoveryLabel ?? '').trim().isNotEmpty)
          _statusBadge(
            'Recovery',
            scope.lastRecoveryLabel!,
            const Color(0xFF86EFAC),
          ),
        if (scope.hasWatchActivationGap)
          _statusBadge(
            'Gap',
            scope.watchActivationGapLabel!,
            const Color(0xFFF87171),
          ),
        if (!scope.hasIncidentContext)
          _statusBadge('Context', 'Pending', const Color(0xFFFBBF24)),
        if (scope.identityPolicyChipValue != null)
          _statusBadge(
            'Identity',
            scope.identityPolicyChipValue!,
            identityPolicyAccentColorForScope(scope),
          ),
        if (scope.clientDecisionChipValue != null)
          _statusBadge(
            'Client',
            scope.clientDecisionChipValue!,
            scope.clientDecisionChipValue == 'Approved'
                ? const Color(0xFF86EFAC)
                : scope.clientDecisionChipValue == 'Review'
                ? const Color(0xFFFDE68A)
                : const Color(0xFFFCA5A5),
          ),
        _statusBadge('Status', scope.statusLabel, statusColor),
        _statusBadge('Watch', scope.watchLabel, watchColor),
        _statusBadge(
          'Freshness',
          scope.freshnessLabel,
          _fleetFreshnessColor(scope),
        ),
        _statusBadge(
          'Events 6h',
          '${scope.recentEvents}',
          const Color(0xFF9AB1CF),
        ),
      ],
      secondaryChips: [
        if (scope.watchWindowLabel != null)
          _statusBadge(
            'Window',
            scope.watchWindowLabel!,
            const Color(0xFF86EFAC),
          ),
        if (scope.watchWindowStateLabel != null)
          _statusBadge('Phase', scope.watchWindowStateLabel!, phaseColor),
        if (scope.latestRiskScore != null)
          _statusBadge(
            'Risk',
            _fleetRiskLabel(scope.latestRiskScore!),
            _fleetRiskColor(scope.latestRiskScore!),
          ),
        if (scope.latestCameraLabel != null)
          _statusBadge(
            'Camera',
            scope.latestCameraLabel!,
            const Color(0xFF9AB1CF),
          ),
      ],
      actionChildren: [
        if (canRecoverCoverage)
          _fleetActionButton(
            key: ValueKey('dispatch-fleet-resync-${scope.siteId}'),
            label: 'Resync',
            color: const Color(0xFFF87171),
            onPressed: recoverFleetScope,
          ),
        if (hasTacticalLane)
          _fleetActionButton(
            key: ValueKey('dispatch-fleet-tactical-${scope.siteId}'),
            label: 'Tactical',
            color: const Color(0xFF67E8F9),
            onPressed: openFleetTactical,
          ),
        if (hasDispatchLane)
          _fleetActionButton(
            key: ValueKey('dispatch-fleet-dispatch-${scope.siteId}'),
            label: 'Dispatch',
            color: const Color(0xFFFBBF24),
            onPressed: openFleetDispatch,
          ),
        _fleetActionButton(
          key: ValueKey('dispatch-fleet-detail-${scope.siteId}'),
          label: 'Detail',
          color: const Color(0xFF8FD1FF),
          onPressed: openFleetDetail,
        ),
      ],
      statusDetailText: scope.limitedWatchStatusDetailText,
      noteText: scope.noteText,
      latestText: prominentLatestTextForWatchAction(
        scope,
        _activeWatchActionDrilldown,
      ),
      onLatestTap: openFleetDetail,
      onTap: canRecoverCoverage
          ? recoverFleetScope
          : hasDispatchLane
          ? openFleetDispatch
          : hasTacticalLane
          ? openFleetTactical
          : openFleetDetail,
      decoration: BoxDecoration(
        color: const Color(0xFF101924),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF243345)),
      ),
      constraints: const BoxConstraints(minWidth: 230, maxWidth: 320),
    );
  }

  Widget _fleetSummaryCommandDeck({
    required VideoFleetScopeHealthSections sections,
    required VideoFleetWatchActionDrilldown? activeWatchActionDrilldown,
    required void Function(VideoFleetWatchActionDrilldown drilldown)
    onFocusDrilldown,
    required VoidCallback? onClearFocus,
  }) {
    final recommendedDrilldown = _recommendedFleetSummaryDrilldown(sections);
    final primaryDrilldown = activeWatchActionDrilldown ?? recommendedDrilldown;
    final availableDrilldowns = _availableFleetSummaryDrilldowns(sections);
    final secondaryDrilldowns = availableDrilldowns
        .where((drilldown) => drilldown != primaryDrilldown)
        .take(3)
        .toList(growable: false);
    final accent = primaryDrilldown?.accentColor ?? const Color(0xFF8FD1FF);
    final detail = activeWatchActionDrilldown != null
        ? 'The watch rail is narrowed to ${activeWatchActionDrilldown.focusLabel.toLowerCase()}, so the fleet cards below stay scoped to that operating lane.'
        : primaryDrilldown != null
        ? 'Lead the dispatch watch rail through ${primaryDrilldown.focusLabel.toLowerCase()} first, then widen back to the full fleet surface as needed.'
        : 'All fleet scopes are visible and the system rail can widen across the full watch surface.';

    return Container(
      key: const ValueKey('dispatch-fleet-summary-command'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111826),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.36)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 160;
              final summary = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FLEET SUMMARY COMMAND',
                    style: GoogleFonts.inter(
                      color: accent,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    primaryDrilldown?.focusLabel ?? 'All fleet scopes visible',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFEAF4FF),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFCAD7E8),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ],
              );
              final modeCard = Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: accent.withValues(alpha: 0.42)),
                ),
                child: Column(
                  crossAxisAlignment: stacked
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.end,
                  children: [
                    Text(
                      'COMMAND MODE',
                      style: GoogleFonts.inter(
                        color: accent,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      activeWatchActionDrilldown != null
                          ? 'Focused'
                          : primaryDrilldown != null
                          ? 'Recommended'
                          : 'Overview',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFEAF4FF),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [summary, const SizedBox(height: 8), modeCard],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: summary),
                  const SizedBox(width: 12),
                  modeCard,
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (primaryDrilldown != null &&
                  activeWatchActionDrilldown == null)
                _fleetActionButton(
                  key: const ValueKey('dispatch-fleet-summary-primary-action'),
                  label: primaryDrilldown.focusLabel,
                  color: accent,
                  onPressed: () => onFocusDrilldown(primaryDrilldown),
                ),
              for (final drilldown in secondaryDrilldowns)
                _fleetActionButton(
                  key: ValueKey('dispatch-fleet-summary-${drilldown.name}'),
                  label: drilldown.focusLabel,
                  color: drilldown.accentColor,
                  onPressed: () => onFocusDrilldown(drilldown),
                ),
              if (onClearFocus != null)
                _fleetActionButton(
                  key: const ValueKey('dispatch-fleet-summary-clear'),
                  label: 'Clear focus',
                  color: const Color(0xFF9AB1CF),
                  onPressed: onClearFocus,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _fleetScopeCommandAccent(VideoFleetScopeHealthView scope) {
    if (scope.hasWatchActivationGap) {
      return const Color(0xFFFCA5A5);
    }
    if (scope.identityPolicyChipValue != null) {
      return identityPolicyAccentColorForScope(scope);
    }
    if (scope.escalationCount > 0) {
      return const Color(0xFFFCA5A5);
    }
    if (scope.alertCount > 0) {
      return const Color(0xFF67E8F9);
    }
    if (scope.repeatCount > 0) {
      return const Color(0xFFFDE68A);
    }
    if (scope.latestRiskScore != null) {
      return _fleetRiskColor(scope.latestRiskScore!);
    }
    return _fleetFreshnessColor(scope);
  }

  String _fleetScopeCommandHeadline(VideoFleetScopeHealthView scope) {
    if (scope.hasWatchActivationGap) {
      return 'Coverage resync needed';
    }
    if (scope.hasFlaggedIdentityPolicy) {
      return 'Flagged identity in watch lane';
    }
    if (scope.hasTemporaryIdentityPolicy) {
      return 'Temporary identity live';
    }
    if (scope.hasAllowlistedIdentityPolicy) {
      return 'Allowlisted identity cleared';
    }
    if (scope.escalationCount > 0) {
      return 'Escalation lane active';
    }
    if (scope.alertCount > 0) {
      return 'Alert lane active';
    }
    if (scope.repeatCount > 0) {
      return 'Repeat monitoring lane';
    }
    if (scope.hasIncidentContext) {
      return 'Incident-backed watch scope';
    }
    if (scope.hasRecentRecovery) {
      return 'Recovered watch stabilized';
    }
    return 'Monitoring scope ready';
  }

  String _fleetScopeCommandDetail(VideoFleetScopeHealthView scope) {
    final candidates = <String?>[
      scope.latestActionHistoryText,
      scope.identityMatchText,
      scope.sceneDecisionText,
      scope.sceneReviewText,
      scope.latestSummaryText,
      scope.latestSuppressedHistoryText,
      scope.identityPolicyText,
      scope.clientDecisionText,
      scope.noteText?.split('\n').first,
    ];
    for (final candidate in candidates) {
      final detail = (candidate ?? '').trim();
      if (detail.isNotEmpty) {
        return detail;
      }
    }
    if (scope.hasIncidentContext) {
      return 'Incident-linked watch context is available for ${scope.siteName}.';
    }
    if (scope.hasWatchActivationGap) {
      return 'The watch window missed its expected start and needs operator recovery.';
    }
    return 'Scope telemetry is stable and ready for drill-in.';
  }

  VideoFleetWatchActionDrilldown? _recommendedFleetSummaryDrilldown(
    VideoFleetScopeHealthSections sections,
  ) {
    for (final drilldown in _availableFleetSummaryDrilldowns(sections)) {
      return drilldown;
    }
    return null;
  }

  List<VideoFleetWatchActionDrilldown> _availableFleetSummaryDrilldowns(
    VideoFleetScopeHealthSections sections,
  ) {
    const ordered = [
      VideoFleetWatchActionDrilldown.alerts,
      VideoFleetWatchActionDrilldown.limited,
      VideoFleetWatchActionDrilldown.flaggedIdentity,
      VideoFleetWatchActionDrilldown.temporaryIdentity,
      VideoFleetWatchActionDrilldown.escalated,
      VideoFleetWatchActionDrilldown.repeat,
      VideoFleetWatchActionDrilldown.filtered,
      VideoFleetWatchActionDrilldown.allowlistedIdentity,
    ];
    return ordered
        .where(
          (drilldown) => _fleetSummaryDrilldownCount(sections, drilldown) > 0,
        )
        .toList(growable: false);
  }

  int _fleetSummaryDrilldownCount(
    VideoFleetScopeHealthSections sections,
    VideoFleetWatchActionDrilldown drilldown,
  ) {
    return switch (drilldown) {
      VideoFleetWatchActionDrilldown.limited => sections.limitedCount,
      VideoFleetWatchActionDrilldown.alerts => sections.alertActionCount,
      VideoFleetWatchActionDrilldown.repeat => sections.repeatActionCount,
      VideoFleetWatchActionDrilldown.escalated =>
        sections.escalationActionCount,
      VideoFleetWatchActionDrilldown.filtered => sections.suppressedActionCount,
      VideoFleetWatchActionDrilldown.flaggedIdentity =>
        sections.flaggedIdentityCount,
      VideoFleetWatchActionDrilldown.temporaryIdentity =>
        sections.temporaryIdentityCount,
      VideoFleetWatchActionDrilldown.allowlistedIdentity =>
        sections.allowlistedIdentityCount,
    };
  }

  List<Widget> _fleetSummaryChips({
    required VideoFleetScopeHealthSections sections,
    required void Function(VideoFleetWatchActionDrilldown drilldown)
    onOpenWatchActionDrilldown,
  }) {
    return [
      _fleetSummaryTile(
        'Active',
        '${sections.activeCount}',
        detail: 'Live or limited fleet watch lanes',
        accent: const Color(0xFF67E8F9),
        key: const ValueKey('dispatch-fleet-summary-tile-active'),
      ),
      _fleetSummaryTile(
        'Limited',
        '${sections.limitedCount}',
        detail: 'Coverage constrained or degraded',
        accent: const Color(0xFFF59E0B),
        isActive:
            _activeWatchActionDrilldown ==
            VideoFleetWatchActionDrilldown.limited,
        key: const ValueKey('dispatch-fleet-summary-tile-limited'),
        onTap: sections.limitedCount > 0
            ? () => onOpenWatchActionDrilldown(
                VideoFleetWatchActionDrilldown.limited,
              )
            : null,
      ),
      _fleetSummaryTile(
        'Gap',
        '${sections.gapCount}',
        detail: 'Watch starts missed or delayed',
        accent: const Color(0xFFF87171),
        key: const ValueKey('dispatch-fleet-summary-tile-gap'),
      ),
      _fleetSummaryTile(
        'High Risk',
        '${sections.highRiskCount}',
        detail: '70+ risk scopes in rail',
        accent: const Color(0xFFF87171),
        key: const ValueKey('dispatch-fleet-summary-tile-high-risk'),
      ),
      _fleetSummaryTile(
        'Recovered 6h',
        '${sections.recoveredCount}',
        detail: 'Recent operator recovery passes',
        accent: const Color(0xFF86EFAC),
        key: const ValueKey('dispatch-fleet-summary-tile-recovered'),
      ),
      _fleetSummaryTile(
        'Suppressed',
        '${sections.suppressedCount}',
        detail: 'Quiet filtered review holds',
        accent: const Color(0xFF9AB1CF),
        key: const ValueKey('dispatch-fleet-summary-tile-suppressed'),
      ),
      _fleetSummaryTile(
        'Alerts',
        '${sections.alertActionCount}',
        detail: 'Client alerts sent from rail',
        accent: const Color(0xFF67E8F9),
        isActive:
            _activeWatchActionDrilldown ==
            VideoFleetWatchActionDrilldown.alerts,
        key: const ValueKey('dispatch-fleet-summary-tile-alerts'),
        onTap: sections.alertActionCount > 0
            ? () => onOpenWatchActionDrilldown(
                VideoFleetWatchActionDrilldown.alerts,
              )
            : null,
      ),
      _fleetSummaryTile(
        'Repeat',
        '${sections.repeatActionCount}',
        detail: 'Monitoring loops still repeating',
        accent: const Color(0xFFFDE68A),
        isActive:
            _activeWatchActionDrilldown ==
            VideoFleetWatchActionDrilldown.repeat,
        key: const ValueKey('dispatch-fleet-summary-tile-repeat'),
        onTap: sections.repeatActionCount > 0
            ? () => onOpenWatchActionDrilldown(
                VideoFleetWatchActionDrilldown.repeat,
              )
            : null,
      ),
      _fleetSummaryTile(
        'Escalated',
        '${sections.escalationActionCount}',
        detail: 'Reviews pushed into escalation',
        accent: const Color(0xFFF87171),
        isActive:
            _activeWatchActionDrilldown ==
            VideoFleetWatchActionDrilldown.escalated,
        key: const ValueKey('dispatch-fleet-summary-tile-escalated'),
        onTap: sections.escalationActionCount > 0
            ? () => onOpenWatchActionDrilldown(
                VideoFleetWatchActionDrilldown.escalated,
              )
            : null,
      ),
      _fleetSummaryTile(
        'Filtered',
        '${sections.suppressedActionCount}',
        detail: 'Below-threshold review holds',
        accent: const Color(0xFF9AB1CF),
        isActive:
            _activeWatchActionDrilldown ==
            VideoFleetWatchActionDrilldown.filtered,
        key: const ValueKey('dispatch-fleet-summary-tile-filtered'),
        onTap: sections.suppressedActionCount > 0
            ? () => onOpenWatchActionDrilldown(
                VideoFleetWatchActionDrilldown.filtered,
              )
            : null,
      ),
      _fleetSummaryTile(
        'Flagged ID',
        '${sections.flaggedIdentityCount}',
        detail: 'Flagged face or plate matches',
        accent: VideoFleetWatchActionDrilldown.flaggedIdentity.accentColor,
        isActive:
            _activeWatchActionDrilldown ==
            VideoFleetWatchActionDrilldown.flaggedIdentity,
        key: const ValueKey('dispatch-fleet-summary-tile-flagged-id'),
        onTap: sections.flaggedIdentityCount > 0
            ? () => onOpenWatchActionDrilldown(
                VideoFleetWatchActionDrilldown.flaggedIdentity,
              )
            : null,
      ),
      _fleetSummaryTile(
        'Temporary ID',
        '${sections.temporaryIdentityCount}',
        detail: 'One-time approved identities',
        accent: temporaryIdentityAccentColorForScopes(widget.fleetScopeHealth),
        isActive:
            _activeWatchActionDrilldown ==
            VideoFleetWatchActionDrilldown.temporaryIdentity,
        key: const ValueKey('dispatch-fleet-summary-tile-temporary-id'),
        onTap: sections.temporaryIdentityCount > 0
            ? () => onOpenWatchActionDrilldown(
                VideoFleetWatchActionDrilldown.temporaryIdentity,
              )
            : null,
      ),
      _fleetSummaryTile(
        'Allowed ID',
        '${sections.allowlistedIdentityCount}',
        detail: 'Allowlisted identity clears',
        accent: VideoFleetWatchActionDrilldown.allowlistedIdentity.accentColor,
        isActive:
            _activeWatchActionDrilldown ==
            VideoFleetWatchActionDrilldown.allowlistedIdentity,
        key: const ValueKey('dispatch-fleet-summary-tile-allowed-id'),
        onTap: sections.allowlistedIdentityCount > 0
            ? () => onOpenWatchActionDrilldown(
                VideoFleetWatchActionDrilldown.allowlistedIdentity,
              )
            : null,
      ),
      _fleetSummaryTile(
        'Stale',
        '${sections.staleCount}',
        detail: 'Feeds aging beyond fresh window',
        accent: const Color(0xFFFBBF24),
        key: const ValueKey('dispatch-fleet-summary-tile-stale'),
      ),
      _fleetSummaryTile(
        'No Incident',
        '${sections.noIncidentCount}',
        detail: 'Telemetry without linked incident',
        accent: const Color(0xFF9AB1CF),
        key: const ValueKey('dispatch-fleet-summary-tile-no-incident'),
      ),
    ];
  }

  Widget _fleetActionButton({
    Key? key,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      key: key,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.45)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
      ),
      child: Text(label),
    );
  }

  Widget _fleetSummaryTile(
    String label,
    String value, {
    required String detail,
    required Color accent,
    bool isActive = false,
    VoidCallback? onTap,
    Key? key,
  }) {
    final title = '$label $value';
    final tile = Container(
      constraints: const BoxConstraints(minWidth: 150, maxWidth: 188),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isActive
            ? accent.withValues(alpha: 0.16)
            : const Color(0xFF111826),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive
              ? accent.withValues(alpha: 0.6)
              : accent.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    color: isActive ? accent : const Color(0xFFEAF4FF),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: accent.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    'FOCUSED',
                    style: GoogleFonts.inter(
                      color: accent,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) {
      return KeyedSubtree(key: key, child: tile);
    }
    return Material(
      key: key,
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: tile,
      ),
    );
  }

  Color _fleetRiskColor(int score) {
    if (score >= 85) {
      return const Color(0xFFF87171);
    }
    if (score >= 70) {
      return const Color(0xFFFBBF24);
    }
    if (score >= 40) {
      return const Color(0xFF67E8F9);
    }
    return const Color(0xFF9AB1CF);
  }

  String _fleetRiskLabel(int score) {
    if (score >= 85) {
      return 'Critical';
    }
    if (score >= 70) {
      return 'High';
    }
    if (score >= 40) {
      return 'Watch';
    }
    return 'Routine';
  }

  Color _fleetFreshnessColor(VideoFleetScopeHealthView scope) {
    return switch (scope.freshnessLabel) {
      'Fresh' => const Color(0xFF10B981),
      'Recent' => const Color(0xFF67E8F9),
      'Stale' => const Color(0xFFF87171),
      'Quiet' => const Color(0xFFFBBF24),
      _ => const Color(0xFF9AB1CF),
    };
  }

  Widget _statusBadge(
    String label,
    String value,
    Color color, {
    VoidCallback? onTap,
    bool isActive = false,
  }) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isActive ? 0.28 : 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: isActive ? 0.95 : 0.5),
        ),
      ),
      child: Text(
        '$label $value',
        style: GoogleFonts.inter(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    if (onTap == null) {
      return badge;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: badge,
    );
  }

  Widget _watchActionFocusBanner(VideoFleetScopeHealthView? focusedScope) {
    final active = _activeWatchActionDrilldown;
    if (active == null) {
      return const SizedBox.shrink();
    }
    final canMutateTemporaryApproval =
        active == VideoFleetWatchActionDrilldown.temporaryIdentity &&
        focusedScope != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: active.focusBannerBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: active.focusBannerBorderColor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stackActions = constraints.maxWidth < 300;
          final summary = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                active.focusBannerTitle,
                style: GoogleFonts.inter(
                  color: const Color(0xFFEAF4FF),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                focusDetailForWatchAction(widget.fleetScopeHealth, active),
                style: GoogleFonts.inter(
                  color: const Color(0xFF9AB1CF),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
          final actions = Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (canMutateTemporaryApproval &&
                  widget.onExtendTemporaryIdentityApproval != null)
                TextButton(
                  onPressed: () async {
                    final message = await widget
                        .onExtendTemporaryIdentityApproval!(focusedScope);
                    if (!mounted) {
                      return;
                    }
                    _showDispatchFeedback(
                      message,
                      label: 'TEMPORARY ID',
                      detail:
                          'The approval extension stays visible in the system rail while the focused watch scope remains selected.',
                      accent: temporaryIdentityAccentColorForScopes(
                        widget.fleetScopeHealth,
                      ),
                    );
                  },
                  child: Text(
                    'Extend 2h',
                    style: GoogleFonts.inter(
                      color: active.focusBannerActionColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (canMutateTemporaryApproval &&
                  widget.onExpireTemporaryIdentityApproval != null)
                TextButton(
                  onPressed: () async {
                    final confirmed =
                        await _confirmExpireTemporaryIdentityApproval(
                          focusedScope,
                        );
                    if (!confirmed) {
                      return;
                    }
                    final message = await widget
                        .onExpireTemporaryIdentityApproval!(focusedScope);
                    if (!mounted) {
                      return;
                    }
                    _showDispatchFeedback(
                      message,
                      label: 'TEMPORARY ID',
                      detail:
                          'The approval expiry stays pinned in the system rail while the watch-action focus remains in place.',
                      accent: const Color(0xFFFCA5A5),
                    );
                  },
                  child: Text(
                    'Expire now',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFFCA5A5),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              TextButton(
                onPressed: () => _setActiveWatchActionDrilldown(null),
                child: Text(
                  'Clear',
                  style: GoogleFonts.inter(
                    color: active.focusBannerActionColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );
          if (stackActions) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [summary, const SizedBox(height: 6), actions],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: summary),
              const SizedBox(width: 8),
              Flexible(child: actions),
            ],
          );
        },
      ),
    );
  }

  Future<bool> _confirmExpireTemporaryIdentityApproval(
    VideoFleetScopeHealthView scope,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF30363D)),
          ),
          title: Text(
            'Expire Temporary Approval?',
            style: GoogleFonts.inter(
              color: const Color(0xFFEAF4FF),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'This immediately removes the temporary identity approval for ${scope.siteName}. Future matches will no longer be treated as approved.',
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: const Color(0xFF9AB1CF),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB91C1C),
                foregroundColor: const Color(0xFFEAF4FF),
              ),
              child: Text(
                'Expire now',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  Widget _statePill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _panelButton({
    required String label,
    required String detail,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(34),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        foregroundColor: const Color(0xFF8FD1FF),
        side: const BorderSide(color: Color(0xFF35506F)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  detail,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8EA4C2),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _radioQueueActions() {
    final hasPending = widget.radioQueueHasPending;
    final retryAction = hasPending ? widget.onRetryRadioQueue : null;
    final clearAction = hasPending && widget.onClearRadioQueue != null
        ? () async {
            await _confirmClearQueue();
          }
        : null;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _inlineActionButton(
          label: 'Retry Now',
          icon: Icons.refresh_rounded,
          onPressed: retryAction,
        ),
        _inlineActionButton(
          label: 'Clear Queue',
          icon: Icons.clear_all_rounded,
          onPressed: clearAction,
          destructive: true,
        ),
      ],
    );
  }

  Widget _inlineActionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool destructive = false,
  }) {
    final enabled = onPressed != null;
    final foreground = destructive
        ? const Color(0xFFEF4444)
        : const Color(0xFF67E8F9);
    final border = destructive
        ? const Color(0xFF5B242C)
        : const Color(0xFF264A62);
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      style: OutlinedButton.styleFrom(
        foregroundColor: enabled ? foreground : const Color(0xFF5F7390),
        side: BorderSide(color: enabled ? border : const Color(0xFF2A3950)),
        minimumSize: const Size(130, 34),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      label: Text(
        label,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }

  Future<void> _confirmClearQueue() async {
    if (!widget.radioQueueHasPending || widget.onClearRadioQueue == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF30363D)),
          ),
          title: Text(
            'Clear Radio Queue?',
            style: GoogleFonts.inter(
              color: const Color(0xFFEAF4FF),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'This removes all pending automated radio responses from dispatch.',
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: const Color(0xFF9AB1CF),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB91C1C),
                foregroundColor: const Color(0xFFEAF4FF),
              ),
              child: Text(
                'Confirm Clear',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      widget.onClearRadioQueue!.call();
    }
  }

  void _handleDispatchAction(_DispatchItem dispatch) {
    if (dispatch.isSeededPlaceholder) {
      _showSignalSnack(
        'This lane is waiting for the live dispatch feed to catch up.',
      );
      return;
    }
    if (dispatch.status == _DispatchStatus.cleared) {
      widget.onOpenReportForDispatch?.call(dispatch.id);
      setState(() {
        _selectedDispatchId = dispatch.id;
      });
      widget.onSelectedDispatchChanged?.call(dispatch.id);
      return;
    }
    widget.onExecute(dispatch.id);
    setState(() {
      _dispatches = _dispatches
          .map((item) {
            if (item.id != dispatch.id) return item;
            switch (item.status) {
              case _DispatchStatus.pending:
                return item.copyWith(
                  status: _DispatchStatus.enRoute,
                  officer: 'RO-448 (Auto Assigned)',
                  eta: '6 min',
                  distance: '3.1 km',
                );
              case _DispatchStatus.enRoute:
                return item;
              case _DispatchStatus.onSite:
                return item.copyWith(
                  status: _DispatchStatus.cleared,
                  eta: null,
                );
              case _DispatchStatus.cleared:
                return item;
            }
          })
          .toList(growable: false);
      _selectedDispatchId = dispatch.id;
    });
    widget.onSelectedDispatchChanged?.call(dispatch.id);
  }

  void _projectDispatches({bool fromInit = false}) {
    final liveDispatches = _seedDispatches(widget.events);
    final focusResolution = _resolveFocusReference(
      widget.focusIncidentReference,
      widget.events,
      liveDispatches,
    );
    final focusReference = focusResolution.reference;
    final focusMatchedInLive =
        focusResolution.state != _DispatchFocusState.seeded &&
        focusResolution.state != _DispatchFocusState.none;
    final projected = _injectFocusedDispatchFallback(
      dispatches: liveDispatches,
      focusReference: focusReference,
      hasLiveMatch: focusMatchedInLive,
    );
    final previousSelectedDispatchId = _selectedDispatchId;

    void apply() {
      _dispatches = projected;
      _resolvedFocusReference = focusReference;
      _focusState = focusResolution.state;
      final visibleDispatches = _visibleDispatches(dispatches: _dispatches);
      if (_dispatches.isEmpty || visibleDispatches.isEmpty) {
        _selectedDispatchId = null;
      } else if (focusReference.isNotEmpty &&
          visibleDispatches.any((dispatch) => dispatch.id == focusReference)) {
        _selectedDispatchId = focusReference;
      } else if (visibleDispatches.every(
        (item) => item.id != _selectedDispatchId,
      )) {
        _selectedDispatchId = visibleDispatches.first.id;
      }
    }

    if (fromInit) {
      apply();
    } else {
      setState(apply);
    }
    if (previousSelectedDispatchId != _selectedDispatchId) {
      if (fromInit) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          widget.onSelectedDispatchChanged?.call(_selectedDispatchId);
        });
      } else {
        widget.onSelectedDispatchChanged?.call(_selectedDispatchId);
      }
    }
  }

  ({String reference, _DispatchFocusState state}) _resolveFocusReference(
    String rawFocusReference,
    List<DispatchEvent> events,
    List<_DispatchItem> liveDispatches,
  ) {
    final normalizedReference = rawFocusReference.trim();
    if (normalizedReference.isEmpty) {
      return (reference: '', state: _DispatchFocusState.none);
    }
    if (liveDispatches.any((dispatch) => dispatch.id == normalizedReference)) {
      return (reference: normalizedReference, state: _DispatchFocusState.exact);
    }

    String? matchedDispatchId;
    IntelligenceReceived? matchedIntel;
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
      if (event.eventId.trim() == normalizedReference &&
          dispatchId.isNotEmpty &&
          liveDispatches.any((dispatch) => dispatch.id == dispatchId)) {
        matchedDispatchId = dispatchId;
      }
      if (dispatchId == normalizedReference &&
          liveDispatches.any((dispatch) => dispatch.id == dispatchId)) {
        matchedDispatchId = dispatchId;
      }
      if (event is IntelligenceReceived &&
          (event.eventId.trim() == normalizedReference ||
              event.intelligenceId.trim() == normalizedReference)) {
        if (matchedIntel == null ||
            event.occurredAt.isAfter(matchedIntel.occurredAt)) {
          matchedIntel = event;
        }
      }
    }

    if (matchedDispatchId != null) {
      return (
        reference: matchedDispatchId,
        state: _DispatchFocusState.scopeBacked,
      );
    }

    if (matchedIntel != null) {
      final decision = events
          .whereType<DecisionCreated>()
          .where(
            (candidate) =>
                candidate.clientId.trim() == matchedIntel!.clientId.trim() &&
                candidate.siteId.trim() == matchedIntel.siteId.trim(),
          )
          .fold<DecisionCreated?>(
            null,
            (latest, candidate) =>
                latest == null ||
                    candidate.occurredAt.isAfter(latest.occurredAt)
                ? candidate
                : latest,
          );
      if (decision != null &&
          liveDispatches.any(
            (dispatch) => dispatch.id == decision.dispatchId,
          )) {
        return (
          reference: decision.dispatchId,
          state: _DispatchFocusState.scopeBacked,
        );
      }
    }

    return (reference: normalizedReference, state: _DispatchFocusState.seeded);
  }

  List<_DispatchItem> _injectFocusedDispatchFallback({
    required List<_DispatchItem> dispatches,
    required String focusReference,
    required bool hasLiveMatch,
  }) {
    if (focusReference.isEmpty || hasLiveMatch) {
      return dispatches;
    }
    return [
      _DispatchItem(
        id: focusReference,
        site: 'Focused Dispatch Lane',
        type: 'Live dispatch feed pending',
        priority: _DispatchPriority.p2High,
        status: _DispatchStatus.pending,
        officer: 'Awaiting assignment',
        dispatchTime: _clockLabel(DateTime.now().toLocal()),
        isSeededPlaceholder: true,
      ),
      ...dispatches,
    ];
  }

  _DispatchStatusStyle _statusStyle(_DispatchStatus status) {
    switch (status) {
      case _DispatchStatus.pending:
        return const _DispatchStatusStyle(
          label: 'PENDING',
          icon: Icons.error_outline_rounded,
          iconColor: Color(0xFFF59E0B),
          iconBg: Color(0x33F59E0B),
          chipFg: Color(0xFFF59E0B),
          chipBg: Color(0x1AF59E0B),
          chipBorder: Color(0x66F59E0B),
          actionLabel: 'ASSIGN OFFICER',
          actionColor: Color(0xFFF59E0B),
        );
      case _DispatchStatus.enRoute:
        return const _DispatchStatusStyle(
          label: 'EN ROUTE',
          icon: Icons.local_shipping_rounded,
          iconColor: Color(0xFF22D3EE),
          iconBg: Color(0x3322D3EE),
          chipFg: Color(0xFF22D3EE),
          chipBg: Color(0x1A22D3EE),
          chipBorder: Color(0x6622D3EE),
          actionLabel: 'TRACK LOCATION',
          actionColor: Color(0xFF22D3EE),
        );
      case _DispatchStatus.onSite:
        return const _DispatchStatusStyle(
          label: 'ON SITE',
          icon: Icons.verified_rounded,
          iconColor: Color(0xFF10B981),
          iconBg: Color(0x3310B981),
          chipFg: Color(0xFF10B981),
          chipBg: Color(0x1A10B981),
          chipBorder: Color(0x6610B981),
          actionLabel: 'MARK CLEARED',
          actionColor: Color(0xFF10B981),
        );
      case _DispatchStatus.cleared:
        return const _DispatchStatusStyle(
          label: 'CLEARED',
          icon: Icons.check_circle_outline_rounded,
          iconColor: Color(0xFF9AB1CF),
          iconBg: Color(0x339AB1CF),
          chipFg: Color(0xFF9AB1CF),
          chipBg: Color(0x1A9AB1CF),
          chipBorder: Color(0x669AB1CF),
          actionLabel: 'VIEW REPORT',
          actionColor: Color(0xFF8EA4C2),
        );
    }
  }

  _DispatchPriorityStyle _priorityStyle(_DispatchPriority priority) {
    return switch (priority) {
      _DispatchPriority.p1Critical => const _DispatchPriorityStyle(
        'P1-CRITICAL',
        Color(0xFFEF4444),
      ),
      _DispatchPriority.p2High => const _DispatchPriorityStyle(
        'P2-HIGH',
        Color(0xFFF59E0B),
      ),
      _DispatchPriority.p3Medium => const _DispatchPriorityStyle(
        'P3-MEDIUM',
        Color(0xFFFACC15),
      ),
    };
  }

  List<_DispatchItem> _seedDispatches(List<DispatchEvent> events) {
    final normalizedClientId = widget.clientId.trim();
    final normalizedSiteId = widget.siteId.trim();
    final hasClientScope = normalizedClientId.isNotEmpty;
    final decisions =
        events
            .whereType<DecisionCreated>()
            .where((decision) {
              if (!hasClientScope) {
                return true;
              }
              if (decision.clientId.trim() != normalizedClientId) {
                return false;
              }
              if (normalizedSiteId.isEmpty) {
                return true;
              }
              return decision.siteId.trim() == normalizedSiteId;
            })
            .toList(growable: false)
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    if (decisions.isEmpty) {
      return const [
        _DispatchItem(
          id: 'DSP-2441',
          site: 'North Residential Cluster',
          type: 'Priority response',
          priority: _DispatchPriority.p1Critical,
          status: _DispatchStatus.enRoute,
          officer: 'RO-441 (K. Dlamini)',
          dispatchTime: '22:14',
          eta: '4 min',
          distance: '2.3 km',
        ),
        _DispatchItem(
          id: 'DSP-2442',
          site: 'Central Access Gate',
          type: 'Emergency assist',
          priority: _DispatchPriority.p1Critical,
          status: _DispatchStatus.onSite,
          officer: 'RO-442 (J. van Wyk)',
          dispatchTime: '22:08',
          distance: '0 km',
        ),
        _DispatchItem(
          id: 'DSP-2439',
          site: 'East Patrol Sector',
          type: 'Alarm review',
          priority: _DispatchPriority.p2High,
          status: _DispatchStatus.cleared,
          officer: 'RO-443 (T. Nkosi)',
          dispatchTime: '21:45',
        ),
        _DispatchItem(
          id: 'DSP-2438',
          site: 'Midrand Operations Park',
          type: 'Perimeter check',
          priority: _DispatchPriority.p2High,
          status: _DispatchStatus.pending,
          officer: 'Unassigned',
          dispatchTime: '21:38',
        ),
      ];
    }

    final arrivedByDispatchId = {
      for (final response in events.whereType<ResponseArrived>())
        response.dispatchId: response,
    };
    final executedDispatchIds = {
      ...events
          .whereType<ExecutionCompleted>()
          .where((event) => event.success)
          .map((event) => event.dispatchId),
    };
    final partnerStatusByDispatchId = {
      for (final declaration
          in events.whereType<PartnerDispatchStatusDeclared>())
        declaration.dispatchId: declaration,
    };
    final closedDispatchIds = {
      ...events.whereType<ExecutionDenied>().map((event) => event.dispatchId),
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

    return decisions
        .take(8)
        .toList(growable: false)
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final decision = entry.value;
          final response = arrivedByDispatchId[decision.dispatchId];
          final partnerDeclaration =
              partnerStatusByDispatchId[decision.dispatchId];
          final status = closedDispatchIds.contains(decision.dispatchId)
              ? _DispatchStatus.cleared
              : response != null
              ? _DispatchStatus.onSite
              : partnerDeclaration?.status == PartnerDispatchStatus.onSite
              ? _DispatchStatus.onSite
              : partnerDeclaration?.status == PartnerDispatchStatus.accepted
              ? _DispatchStatus.enRoute
              : executedDispatchIds.contains(decision.dispatchId)
              ? _DispatchStatus.enRoute
              : index == 0
              ? _DispatchStatus.enRoute
              : index == 1
              ? _DispatchStatus.pending
              : _DispatchStatus.enRoute;

          final priority = switch (index % 3) {
            0 => _DispatchPriority.p1Critical,
            1 => _DispatchPriority.p2High,
            _ => _DispatchPriority.p3Medium,
          };
          final dispatchTime = _clockLabel(decision.occurredAt.toLocal());
          final officer = response != null
              ? response.guardId
              : partnerDeclaration != null
              ? partnerDeclaration.partnerLabel
              : status == _DispatchStatus.pending
              ? 'Unassigned'
              : 'RO-${441 + index}';

          return _DispatchItem(
            id: decision.dispatchId,
            site: decision.siteId,
            type: _typeForPriority(priority),
            priority: priority,
            status: status,
            officer: officer,
            dispatchTime: dispatchTime,
            eta: status == _DispatchStatus.enRoute ? '${4 + index} min' : null,
            distance: status == _DispatchStatus.enRoute
                ? '${(2.0 + (index * 0.6)).toStringAsFixed(1)} km'
                : status == _DispatchStatus.onSite
                ? '0 km'
                : null,
          );
        })
        .toList(growable: false);
  }

  String _typeForPriority(_DispatchPriority priority) {
    return switch (priority) {
      _DispatchPriority.p1Critical => 'Armed Response',
      _DispatchPriority.p2High => 'Perimeter Breach',
      _DispatchPriority.p3Medium => 'Alarm Activation',
    };
  }

  int _officersAvailable() {
    final guardIds = widget.events
        .whereType<ResponseArrived>()
        .map((event) => event.guardId)
        .toSet();
    if (guardIds.isEmpty) return 12;
    return (guardIds.length + 8).clamp(8, 24);
  }

  _PartnerDispatchProgressSummary? _partnerDispatchProgressSummary(
    String dispatchId,
  ) {
    final normalizedDispatchId = dispatchId.trim();
    if (normalizedDispatchId.isEmpty) {
      return null;
    }
    final declarations = widget.events
        .whereType<PartnerDispatchStatusDeclared>()
        .where((event) => event.dispatchId.trim() == normalizedDispatchId)
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
    return _PartnerDispatchProgressSummary(
      dispatchId: normalizedDispatchId,
      clientId: first.clientId,
      siteId: first.siteId,
      partnerLabel: first.partnerLabel,
      latestStatus: latest.status,
      latestOccurredAt: latest.occurredAt,
      declarationCount: ordered.length,
      firstOccurrenceByStatus: firstOccurrenceByStatus,
    );
  }

  _PartnerTrendSummary? _partnerTrendSummary(
    _PartnerDispatchProgressSummary progress,
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
        if (row.clientId.trim() != clientId ||
            row.siteId.trim() != siteId ||
            row.partnerLabel.trim().toUpperCase() != partnerLabel) {
          continue;
        }
        matchingRows.add(row);
        if (reportDate == latestDate) {
          currentRow = row;
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
        if (row.clientId.trim() != clientId ||
            row.siteId.trim() != siteId ||
            row.partnerLabel.trim().toUpperCase() != partnerLabel) {
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
    return _PartnerTrendSummary(
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

  String _averageResponseTimeLabel(List<DispatchEvent> events) {
    final decisions = {
      for (final decision in events.whereType<DecisionCreated>())
        decision.dispatchId: decision.occurredAt,
    };
    final durations = events
        .whereType<ResponseArrived>()
        .map((arrived) {
          final createdAt = decisions[arrived.dispatchId];
          if (createdAt == null) return null;
          final diff = arrived.occurredAt.difference(createdAt).inSeconds;
          return diff > 0 ? diff / 60.0 : null;
        })
        .whereType<double>()
        .toList(growable: false);

    if (durations.isEmpty) {
      return '6.2 min';
    }
    final avg = durations.reduce((a, b) => a + b) / durations.length;
    return '${avg.toStringAsFixed(1)} min';
  }

  String _clockLabel(DateTime timestamp) {
    final hh = timestamp.hour.toString().padLeft(2, '0');
    final mm = timestamp.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  void _showDispatchFeedback(
    String message, {
    String label = 'SYSTEM RAIL',
    String? detail,
    Color accent = const Color(0xFF8FD1FF),
  }) {
    if (_desktopWorkspaceActive) {
      setState(() {
        _commandReceipt = _DispatchCommandReceipt(
          label: label,
          headline: message,
          detail:
              detail ??
              'The latest dispatch workflow update stays pinned in the system rail while the mission board remains active.',
          accent: accent,
        );
      });
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F1419),
        behavior: SnackBarBehavior.floating,
        content: Text(
          message,
          style: GoogleFonts.inter(
            color: const Color(0xFFEAF4FF),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  void _showSignalSnack(String label) {
    _showDispatchFeedback(
      '$label queued',
      label: 'MISSION SIGNAL',
      detail:
          'The queued mission notice stays visible in the system rail while the selected dispatch board remains in focus.',
      accent: const Color(0xFFFDE68A),
    );
  }
}

class _KpiCardSpec {
  final String label;
  final String value;
  final IconData icon;
  final Color valueColor;
  final Color borderColor;

  const _KpiCardSpec({
    required this.label,
    required this.value,
    required this.icon,
    required this.valueColor,
    required this.borderColor,
  });
}

class _DispatchPriorityStyle {
  final String label;
  final Color color;

  const _DispatchPriorityStyle(this.label, this.color);
}

class _DispatchStatusStyle {
  final String label;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final Color chipFg;
  final Color chipBg;
  final Color chipBorder;
  final String actionLabel;
  final Color actionColor;

  const _DispatchStatusStyle({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.chipFg,
    required this.chipBg,
    required this.chipBorder,
    required this.actionLabel,
    required this.actionColor,
  });
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _MetricRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(0x99FFFFFF),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              color: valueColor ?? const Color(0xFFE5EFFF),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  final String title;
  final String detail;

  const _BulletLine({required this.title, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 3.5),
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFDDEBFF),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  detail,
                  style: GoogleFonts.inter(
                    color: const Color(0x99FFFFFF),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final String value;
  final double width;
  final Color color;

  const _BreakdownRow({
    required this.label,
    required this.value,
    required this.width,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  color: const Color(0x99FFFFFF),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              value,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 3,
            value: width,
            backgroundColor: const Color(0xFF0A0E14),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
