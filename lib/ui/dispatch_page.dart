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
    this.focusIncidentReference = '',
  });

  @override
  State<DispatchPage> createState() => _DispatchPageState();
}

class _DispatchPageState extends State<DispatchPage> {
  late List<_DispatchItem> _dispatches;
  String? _selectedDispatchId;
  bool _focusReferenceLinkedToLive = false;
  VideoFleetWatchActionDrilldown? _activeWatchActionDrilldown;

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

  @override
  Widget build(BuildContext context) {
    final fleetPanelKey = GlobalKey();
    final suppressedPanelKey = GlobalKey();
    final wide = allowEmbeddedPanelScroll(context);
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
    final suppressedEntries = _suppressedDispatchReviewEntries();
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

    return OnyxPageScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(),
                const SizedBox(height: 10),
                _kpiBand(
                  activeDispatches: activeDispatches,
                  pendingDispatches: pendingDispatches,
                ),
                const SizedBox(height: 10),
                _commandActions(),
                const SizedBox(height: 10),
                wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 7, child: _dispatchQueue()),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 5,
                            child: _systemStatusPanel(
                              fleetPanelKey: fleetPanelKey,
                              suppressedPanelKey: suppressedPanelKey,
                              suppressedEntries: suppressedEntries,
                              onOpenWatchActionDrilldown:
                                  openWatchActionDrilldown,
                              onOpenLatestWatchActionDetail:
                                  openLatestWatchActionDetail,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          _dispatchQueue(),
                          const SizedBox(height: 10),
                          _systemStatusPanel(
                            fleetPanelKey: fleetPanelKey,
                            suppressedPanelKey: suppressedPanelKey,
                            suppressedEntries: suppressedEntries,
                            onOpenWatchActionDrilldown:
                                openWatchActionDrilldown,
                            onOpenLatestWatchActionDetail:
                                openLatestWatchActionDetail,
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 3,
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'DISPATCH COMMAND',
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFE9F3FF),
              fontSize: 31,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.clientId} / ${widget.regionId} / ${widget.siteId}',
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (widget.focusIncidentReference.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _focusPill(widget.focusIncidentReference.trim()),
          ],
        ],
      ),
    );
  }

  Widget _focusPill(String focusReference) {
    final linked = _focusReferenceLinkedToLive;
    final color = linked ? const Color(0xFF22D3EE) : const Color(0xFFFACC15);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        'Focus ${linked ? 'Linked' : 'Seeded'}: $focusReference',
        style: GoogleFonts.inter(
          color: color,
          fontSize: 11,
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
                if (i != cards.length - 1) const SizedBox(height: 8),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              Expanded(child: _kpiCard(cards[i])),
              if (i != cards.length - 1) const SizedBox(width: 8),
            ],
          ],
        );
      },
    );
  }

  Widget _kpiCard(_KpiCardSpec spec) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: spec.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(spec.icon, size: 16, color: const Color(0xFF9AB1CF)),
              const SizedBox(width: 6),
              Text(
                spec.label,
                style: GoogleFonts.inter(
                  color: const Color(0x7FFFFFFF),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            spec.value,
            style: GoogleFonts.rajdhani(
              color: spec.valueColor,
              fontSize: 34,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COMMAND ACTIONS',
            style: GoogleFonts.inter(
              color: const Color(0x7FFFFFFF),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: widget.onGenerate,
            icon: const Icon(Icons.auto_awesome_rounded, size: 16),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2B5E93),
              foregroundColor: const Color(0xFFEAF4FF),
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            label: Text(
              'Generate Dispatch',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
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
      icon: Icon(icon, size: 16),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF8FD1FF),
        side: const BorderSide(color: Color(0xFF35506F)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      label: Text(
        label,
        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _dispatchQueue() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 420;
              final title = Text(
                'ACTIVE DISPATCH QUEUE',
                style: GoogleFonts.inter(
                  color: const Color(0x7FFFFFFF),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              );
              final action = TextButton.icon(
                onPressed: widget.onGenerate,
                icon: const Icon(Icons.send_rounded, size: 16),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF8FD1FF),
                ),
                label: Text(
                  'NEW DISPATCH',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, const SizedBox(height: 4), action],
                );
              }
              return Row(children: [title, const Spacer(), action]);
            },
          ),
          const SizedBox(height: 8),
          if (_dispatches.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0x33000000),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2A3D58)),
              ),
              child: Text(
                'No dispatches available.',
                style: GoogleFonts.inter(
                  color: const Color(0xFF9AB1CF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Column(
              children: [
                for (int i = 0; i < _dispatches.length; i++) ...[
                  _dispatchCard(_dispatches[i]),
                  if (i != _dispatches.length - 1) const SizedBox(height: 8),
                ],
              ],
            ),
        ],
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
        width: double.infinity,
        padding: const EdgeInsets.all(12),
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
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: statusStyle.iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                statusStyle.icon,
                color: statusStyle.iconColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
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
                            fontSize: 28,
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
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
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
                    const SizedBox(height: 10),
                    Container(
                      key: ValueKey<String>(
                        'dispatch-partner-progress-card-${dispatch.id}',
                      ),
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
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
                          const SizedBox(height: 6),
                          Text(
                            '${partnerProgress.partnerLabel} • Latest ${_partnerDispatchStatusLabel(partnerProgress.latestStatus)} • ${_clockLabel(partnerProgress.latestOccurredAt.toLocal())}',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFEAF4FF),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 10,
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
                            const SizedBox(height: 6),
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
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
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
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _handleDispatchAction(dispatch),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: statusStyle.actionColor,
                        side: BorderSide(color: statusStyle.actionColor),
                        padding: const EdgeInsets.symmetric(vertical: 10),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
    required List<_SuppressedDispatchReviewEntry> suppressedEntries,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SYSTEM STATUS',
            style: GoogleFonts.inter(
              color: const Color(0x7FFFFFFF),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          if (showEscalatedPrimary && widget.fleetScopeHealth.isNotEmpty) ...[
            const SizedBox(height: 8),
            KeyedSubtree(
              key: fleetPanelKey,
              child: _fleetScopePanel(
                onOpenWatchActionDrilldown: onOpenWatchActionDrilldown,
                onOpenLatestWatchActionDetail: onOpenLatestWatchActionDetail,
              ),
            ),
          ],
          const SizedBox(height: 8),
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
          const SizedBox(height: 8),
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
                const SizedBox(height: 8),
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
                  const SizedBox(height: 8),
                  KeyedSubtree(
                    key: suppressedPanelKey,
                    child: _suppressedReviewPanel(suppressedEntries),
                  ),
                ],
                if (!showEscalatedPrimary &&
                    widget.fleetScopeHealth.isNotEmpty) ...[
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 8),
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
          const SizedBox(height: 8),
          _statusSection(
            title: 'Command Actions',
            child: Column(
              children: [
                _panelButton(
                  label: 'BROADCAST TO ALL UNITS',
                  icon: Icons.radio_rounded,
                ),
                const SizedBox(height: 6),
                _panelButton(
                  label: 'VIEW FLEET STATUS',
                  icon: Icons.local_shipping_rounded,
                ),
                const SizedBox(height: 6),
                _panelButton(
                  label: 'DISPATCH ANALYTICS',
                  icon: Icons.analytics_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
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
                SizedBox(height: 8),
                _BreakdownRow(
                  label: 'P2 High',
                  value: '8.1 min avg',
                  width: 0.65,
                  color: Color(0xFFF59E0B),
                ),
                SizedBox(height: 8),
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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1117),
        borderRadius: BorderRadius.circular(9),
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
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              _statusBadge(
                'Internal',
                '${entries.length}',
                const Color(0xFF9AB1CF),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Recent ${widget.videoOpsLabel} reviews ONYX held below the client notification threshold while dispatch remained active.',
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...entries.asMap().entries.map((entry) {
            final item = entry.value;
            final scope = item.scope;
            final review = item.review;
            return Container(
              width: double.infinity,
              margin: EdgeInsets.only(
                bottom: entry.key == entries.length - 1 ? 0 : 8,
              ),
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFF101722),
                borderRadius: BorderRadius.circular(8),
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
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _clockLabel(review.reviewedAtUtc.toLocal()),
                        style: GoogleFonts.robotoMono(
                          color: const Color(0xFF8EA4C2),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
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
                  const SizedBox(height: 8),
                  Text(
                    review.decisionSummary.trim().isEmpty
                        ? 'Suppressed because the activity remained below threshold.'
                        : review.decisionSummary.trim(),
                    style: GoogleFonts.inter(
                      color: const Color(0xFFEAF4FF),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Scene review: ${review.summary.trim()}',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF9AB1CF),
                      fontSize: 11,
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1117),
        borderRadius: BorderRadius.circular(10),
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
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleWidget,
                    if (pill != null) ...[const SizedBox(height: 6), pill],
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
          const SizedBox(height: 8),
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
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF0C1117),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: const Color(0x332B425F)),
          ),
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
      'WATCH READY' => const Color(0xFFF59E0B),
      _ => const Color(0xFF8EA4C2),
    };
    final primaryOpenFleetScope = scope.hasIncidentContext
        ? (widget.onOpenFleetDispatchScope ?? widget.onOpenFleetTacticalScope)
        : null;
    return VideoFleetScopeHealthCard(
      title: scope.siteName,
      endpointLabel: scope.endpointLabel,
      lastSeenLabel: scope.lastSeenLabel,
      titleStyle: GoogleFonts.inter(
        color: const Color(0xFFEAF4FF),
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      endpointStyle: GoogleFonts.robotoMono(
        color: const Color(0xFF8EA4C2),
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
      lastSeenStyle: GoogleFonts.inter(
        color: const Color(0xFF9AB1CF),
        fontSize: 11,
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
        _statusBadge('Watch', scope.watchLabel, const Color(0xFF67E8F9)),
        _statusBadge(
          'Freshness',
          scope.freshnessLabel,
          _fleetFreshnessColor(scope),
        ),
        _statusBadge('6h', '${scope.recentEvents}', const Color(0xFF9AB1CF)),
      ],
      secondaryChips: [
        if (scope.watchWindowLabel != null)
          _statusBadge(
            'Window',
            scope.watchWindowLabel!,
            const Color(0xFF86EFAC),
          ),
        if (scope.watchWindowStateLabel != null)
          _statusBadge(
            'Phase',
            scope.watchWindowStateLabel!,
            scope.watchWindowStateLabel == 'IN WINDOW'
                ? const Color(0xFF86EFAC)
                : const Color(0xFFFBBF24),
          ),
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
        if (widget.onRecoverFleetWatchScope != null &&
            scope.hasWatchActivationGap)
          _fleetActionButton(
            label: 'Resync',
            color: const Color(0xFFF87171),
            onPressed: () => widget.onRecoverFleetWatchScope!.call(
              scope.clientId,
              scope.siteId,
            ),
          ),
        if (widget.onOpenFleetTacticalScope != null && scope.hasIncidentContext)
          _fleetActionButton(
            label: 'Tactical',
            color: const Color(0xFF67E8F9),
            onPressed: () => widget.onOpenFleetTacticalScope!.call(
              scope.clientId,
              scope.siteId,
              scope.latestIncidentReference,
            ),
          ),
        if (widget.onOpenFleetDispatchScope != null && scope.hasIncidentContext)
          _fleetActionButton(
            label: 'Dispatch',
            color: const Color(0xFFFBBF24),
            onPressed: () => widget.onOpenFleetDispatchScope!.call(
              scope.clientId,
              scope.siteId,
              scope.latestIncidentReference,
            ),
          ),
      ],
      noteText: scope.noteText,
      latestText: prominentLatestTextForWatchAction(
        scope,
        _activeWatchActionDrilldown,
      ),
      onLatestTap: () => onOpenLatestWatchActionDetail(scope),
      onTap: primaryOpenFleetScope == null
          ? null
          : () => primaryOpenFleetScope.call(
              scope.clientId,
              scope.siteId,
              scope.latestIncidentReference,
            ),
      decoration: BoxDecoration(
        color: const Color(0xFF101722),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x333A546E)),
      ),
      constraints: const BoxConstraints(minWidth: 210, maxWidth: 290),
    );
  }

  List<Widget> _fleetSummaryChips({
    required VideoFleetScopeHealthSections sections,
    required void Function(VideoFleetWatchActionDrilldown drilldown)
    onOpenWatchActionDrilldown,
  }) {
    return [
      _statusBadge(
        'Active',
        '${sections.activeCount}',
        const Color(0xFF67E8F9),
      ),
      _statusBadge('Gap', '${sections.gapCount}', const Color(0xFFF87171)),
      _statusBadge(
        'High Risk',
        '${sections.highRiskCount}',
        const Color(0xFFF87171),
      ),
      _statusBadge(
        'Recovered 6h',
        '${sections.recoveredCount}',
        const Color(0xFF86EFAC),
      ),
      _statusBadge(
        'Suppressed',
        '${sections.suppressedCount}',
        const Color(0xFF9AB1CF),
      ),
      _statusBadge(
        'Alerts',
        '${sections.alertActionCount}',
        const Color(0xFF67E8F9),
        isActive:
            _activeWatchActionDrilldown ==
            VideoFleetWatchActionDrilldown.alerts,
        onTap: sections.alertActionCount > 0
            ? () => onOpenWatchActionDrilldown(
                VideoFleetWatchActionDrilldown.alerts,
              )
            : null,
      ),
      _statusBadge(
        'Repeat',
        '${sections.repeatActionCount}',
        const Color(0xFFFDE68A),
        isActive:
            _activeWatchActionDrilldown ==
            VideoFleetWatchActionDrilldown.repeat,
        onTap: sections.repeatActionCount > 0
            ? () => onOpenWatchActionDrilldown(
                VideoFleetWatchActionDrilldown.repeat,
              )
            : null,
      ),
      _statusBadge(
        'Escalated',
        '${sections.escalationActionCount}',
        const Color(0xFFF87171),
        isActive:
            _activeWatchActionDrilldown ==
            VideoFleetWatchActionDrilldown.escalated,
        onTap: sections.escalationActionCount > 0
            ? () => onOpenWatchActionDrilldown(
                VideoFleetWatchActionDrilldown.escalated,
              )
            : null,
      ),
      _statusBadge(
        'Filtered',
        '${sections.suppressedActionCount}',
        const Color(0xFF9AB1CF),
        isActive:
            _activeWatchActionDrilldown ==
            VideoFleetWatchActionDrilldown.filtered,
        onTap: sections.suppressedActionCount > 0
            ? () => onOpenWatchActionDrilldown(
                VideoFleetWatchActionDrilldown.filtered,
              )
            : null,
      ),
      _statusBadge(
        'Flagged ID',
        '${sections.flaggedIdentityCount}',
        VideoFleetWatchActionDrilldown.flaggedIdentity.accentColor,
        isActive:
            _activeWatchActionDrilldown ==
            VideoFleetWatchActionDrilldown.flaggedIdentity,
        onTap: sections.flaggedIdentityCount > 0
            ? () => onOpenWatchActionDrilldown(
                VideoFleetWatchActionDrilldown.flaggedIdentity,
              )
            : null,
      ),
      _statusBadge(
        'Temporary ID',
        '${sections.temporaryIdentityCount}',
        temporaryIdentityAccentColorForScopes(widget.fleetScopeHealth),
        isActive:
            _activeWatchActionDrilldown ==
            VideoFleetWatchActionDrilldown.temporaryIdentity,
        onTap: sections.temporaryIdentityCount > 0
            ? () => onOpenWatchActionDrilldown(
                VideoFleetWatchActionDrilldown.temporaryIdentity,
              )
            : null,
      ),
      _statusBadge(
        'Allowed ID',
        '${sections.allowlistedIdentityCount}',
        VideoFleetWatchActionDrilldown.allowlistedIdentity.accentColor,
        isActive:
            _activeWatchActionDrilldown ==
            VideoFleetWatchActionDrilldown.allowlistedIdentity,
        onTap: sections.allowlistedIdentityCount > 0
            ? () => onOpenWatchActionDrilldown(
                VideoFleetWatchActionDrilldown.allowlistedIdentity,
              )
            : null,
      ),
      _statusBadge('Stale', '${sections.staleCount}', const Color(0xFFFBBF24)),
      _statusBadge(
        'No Incident',
        '${sections.noIncidentCount}',
        const Color(0xFF9AB1CF),
      ),
    ];
  }

  Widget _fleetActionButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
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
            ),
          ),
          const SizedBox(width: 8),
          Wrap(
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
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(message)));
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
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(message)));
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
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _panelButton({required String label, required IconData icon}) {
    return OutlinedButton.icon(
      onPressed: () => _showSignalSnack(label),
      icon: Icon(icon, size: 16),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(38),
        foregroundColor: const Color(0xFF8FD1FF),
        side: const BorderSide(color: Color(0xFF35506F)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      label: Text(
        label,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800),
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
        'Seeded focus reference is awaiting live dispatch ingest',
      );
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
    final focusReference = widget.focusIncidentReference.trim();
    final liveDispatches = _seedDispatches(widget.events);
    final focusMatchedInLive =
        focusReference.isNotEmpty &&
        liveDispatches.any((dispatch) => dispatch.id == focusReference);
    final projected = _injectFocusedDispatchFallback(
      dispatches: liveDispatches,
      focusReference: focusReference,
      hasLiveMatch: focusMatchedInLive,
    );
    final previousSelectedDispatchId = _selectedDispatchId;

    void apply() {
      _dispatches = projected;
      _focusReferenceLinkedToLive = focusMatchedInLive;
      if (_dispatches.isEmpty) {
        _selectedDispatchId = null;
      } else if (focusReference.isNotEmpty &&
          _dispatches.any((dispatch) => dispatch.id == focusReference)) {
        _selectedDispatchId = focusReference;
      } else if (_dispatches.every((item) => item.id != _selectedDispatchId)) {
        _selectedDispatchId = _dispatches.first.id;
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
        site: 'Seeded Demo Incident',
        type: 'Awaiting dispatch ingest',
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
    final decisions = events.whereType<DecisionCreated>().toList(
      growable: false,
    )..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    if (decisions.isEmpty) {
      return const [
        _DispatchItem(
          id: 'DSP-2441',
          site: 'Blue Ridge Security',
          type: 'Armed Response',
          priority: _DispatchPriority.p1Critical,
          status: _DispatchStatus.enRoute,
          officer: 'RO-441 (K. Dlamini)',
          dispatchTime: '22:14',
          eta: '4 min',
          distance: '2.3 km',
        ),
        _DispatchItem(
          id: 'DSP-2442',
          site: 'Waterfall Estate Main',
          type: 'Panic Button',
          priority: _DispatchPriority.p1Critical,
          status: _DispatchStatus.onSite,
          officer: 'RO-442 (J. van Wyk)',
          dispatchTime: '22:08',
          distance: '0 km',
        ),
        _DispatchItem(
          id: 'DSP-2439',
          site: 'Sandton Estate North',
          type: 'Alarm Activation',
          priority: _DispatchPriority.p2High,
          status: _DispatchStatus.cleared,
          officer: 'RO-443 (T. Nkosi)',
          dispatchTime: '21:45',
        ),
        _DispatchItem(
          id: 'DSP-2438',
          site: 'Midrand Industrial',
          type: 'Perimeter Breach',
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

  void _showSignalSnack(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F1419),
        behavior: SnackBarBehavior.floating,
        content: Text(
          '$label queued',
          style: GoogleFonts.inter(
            color: const Color(0xFFEAF4FF),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(0x99FFFFFF),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              color: valueColor ?? const Color(0xFFE5EFFF),
              fontSize: 12,
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
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 5),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFDDEBFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  detail,
                  style: GoogleFonts.inter(
                    color: const Color(0x99FFFFFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
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
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              value,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 5,
            value: width,
            backgroundColor: const Color(0xFF0A0E14),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
