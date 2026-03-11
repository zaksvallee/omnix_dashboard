import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../domain/events/decision_created.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/events/execution_completed.dart';
import '../domain/events/execution_denied.dart';
import '../domain/events/incident_closed.dart';
import '../domain/events/intelligence_received.dart';
import '../domain/events/response_arrived.dart';
import '../infrastructure/intelligence/news_intelligence_service.dart';
import 'dispatch_models.dart';
import 'layout_breakpoints.dart';
import 'onyx_surface.dart';

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
    );
  }
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
  final String cctvOpsReadiness;
  final String cctvOpsDetail;
  final String cctvCapabilitySummary;
  final String cctvRecentSignalSummary;
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
  final void Function(String dispatchId) onExecute;

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
    this.cctvOpsReadiness = 'UNCONFIGURED',
    this.cctvOpsDetail =
        'Configure ONYX_CCTV_PROVIDER and ONYX_CCTV_EVENTS_URL.',
    this.cctvCapabilitySummary = 'caps none',
    this.cctvRecentSignalSummary =
        'recent hardware intel 0 (6h) • intrusion 0 • line_crossing 0 • motion 0 • fr 0 • lpr 0',
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
    required this.onExecute,
  });

  @override
  State<DispatchPage> createState() => _DispatchPageState();
}

class _DispatchPageState extends State<DispatchPage> {
  late List<_DispatchItem> _dispatches;
  String? _selectedDispatchId;

  @override
  void initState() {
    super.initState();
    _dispatches = _seedDispatches(widget.events);
    _selectedDispatchId = _dispatches.isEmpty ? null : _dispatches.first.id;
  }

  @override
  void didUpdateWidget(covariant DispatchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.events != widget.events) {
      _dispatches = _seedDispatches(widget.events);
      if (_dispatches.every((item) => item.id != _selectedDispatchId)) {
        _selectedDispatchId = _dispatches.isEmpty ? null : _dispatches.first.id;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = allowEmbeddedPanelScroll(context);
    final activeDispatches = _dispatches
        .where(
          (dispatch) =>
              dispatch.status == _DispatchStatus.enRoute ||
              dispatch.status == _DispatchStatus.onSite,
        )
        .length;
    final pendingDispatches = _dispatches
        .where((dispatch) => dispatch.status == _DispatchStatus.pending)
        .length;

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
                          Expanded(flex: 5, child: _systemStatusPanel()),
                        ],
                      )
                    : Column(
                        children: [
                          _dispatchQueue(),
                          const SizedBox(height: 10),
                          _systemStatusPanel(),
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
        ],
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
                label: 'Ingest CCTV Events',
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

    return InkWell(
      onTap: () => setState(() => _selectedDispatchId = dispatch.id),
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

  Widget _systemStatusPanel() {
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
                  title: 'CCTV Ops • ${widget.cctvOpsReadiness}',
                  detail: widget.cctvOpsDetail,
                ),
                _BulletLine(
                  title: 'CCTV Capabilities',
                  detail: widget.cctvCapabilitySummary,
                ),
                _BulletLine(
                  title: 'CCTV Signals Recent',
                  detail: widget.cctvRecentSignalSummary,
                ),
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
    final closedDispatchIds = {
      ...events.whereType<ExecutionCompleted>().map(
        (event) => event.dispatchId,
      ),
      ...events.whereType<ExecutionDenied>().map((event) => event.dispatchId),
      ...events.whereType<IncidentClosed>().map((event) => event.dispatchId),
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

          final status = closedDispatchIds.contains(decision.dispatchId)
              ? _DispatchStatus.cleared
              : response != null
              ? _DispatchStatus.onSite
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
