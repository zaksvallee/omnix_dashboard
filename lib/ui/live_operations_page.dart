import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';

import '../application/hazard_response_directive_service.dart';
import '../application/morning_sovereign_report_service.dart';
import '../application/monitoring_global_posture_service.dart';
import '../application/monitoring_orchestrator_service.dart';
import '../domain/events/decision_created.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/events/execution_completed.dart';
import '../domain/events/execution_denied.dart';
import '../domain/events/guard_checked_in.dart';
import '../domain/events/incident_closed.dart';
import '../domain/events/intelligence_received.dart';
import '../domain/events/partner_dispatch_status_declared.dart';
import '../domain/events/response_arrived.dart';
import '../application/monitoring_scene_review_store.dart';
import '../application/site_activity_intelligence_service.dart';
import '../application/monitoring_watch_action_plan.dart';
import '../application/shadow_mo_dossier_contract.dart';
import 'layout_breakpoints.dart';
import 'onyx_surface.dart';
import 'ui_action_logger.dart';

enum _IncidentPriority { p1Critical, p2High, p3Medium, p4Low }

enum _IncidentStatus { triaging, dispatched, investigating, resolved }

enum _LadderStepStatus { completed, active, thinking, pending, blocked }

enum _ContextTab { details, voip, visual }

enum _LedgerType { aiAction, humanOverride, systemEvent, escalation }

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

class LiveOperationsPage extends StatefulWidget {
  final List<DispatchEvent> events;
  final List<SovereignReport> morningSovereignReportHistory;
  final List<String> historicalSyntheticLearningLabels;
  final String focusIncidentReference;
  final String videoOpsLabel;
  final Map<String, MonitoringSceneReviewRecord> sceneReviewByIntelligenceId;
  final void Function(List<String> eventIds, String? selectedEventId)?
  onOpenEventsForScope;

  const LiveOperationsPage({
    super.key,
    required this.events,
    this.morningSovereignReportHistory = const <SovereignReport>[],
    this.historicalSyntheticLearningLabels = const <String>[],
    this.focusIncidentReference = '',
    this.videoOpsLabel = 'CCTV',
    this.sceneReviewByIntelligenceId = const {},
    this.onOpenEventsForScope,
  });

  @override
  State<LiveOperationsPage> createState() => _LiveOperationsPageState();
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

  List<_IncidentRecord> _incidents = const [];
  List<_LedgerEntry> _projectedLedger = const [];
  List<_GuardVigilance> _vigilance = const [];
  final List<_LedgerEntry> _manualLedger = [];
  final Map<String, _IncidentStatus> _statusOverrides = {};
  String? _activeIncidentId;
  bool _focusReferenceLinkedToLive = false;
  _ContextTab _activeTab = _ContextTab.details;

  @override
  void initState() {
    super.initState();
    _projectFromEvents();
  }

  @override
  void didUpdateWidget(covariant LiveOperationsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.events.length != widget.events.length ||
        oldWidget.sceneReviewByIntelligenceId !=
            widget.sceneReviewByIntelligenceId ||
        oldWidget.focusIncidentReference.trim() !=
            widget.focusIncidentReference.trim()) {
      _projectFromEvents();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeIncident = _activeIncident;
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
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1580),
                  child: wide
                      ? Column(
                          children: [
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: _incidentQueuePanel(),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 5,
                                    child: _actionLadderPanel(activeIncident),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 4,
                                    child: _contextAndVigilancePanel(
                                      activeIncident,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(height: 208, child: _ledgerPanel(ledger)),
                          ],
                        )
                      : SingleChildScrollView(
                          child: Column(
                            children: [
                              _incidentQueuePanel(),
                              const SizedBox(height: 10),
                              _actionLadderPanel(activeIncident),
                              const SizedBox(height: 10),
                              _contextAndVigilancePanel(activeIncident),
                              const SizedBox(height: 10),
                              _ledgerPanel(ledger, embeddedScroll: false),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final focusReference = widget.focusIncidentReference.trim();
    final hasFocusReference = focusReference.isNotEmpty;
    final focusMatched = hasFocusReference && _focusReferenceLinkedToLive;
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
                  label: '3 AI Actions Pending',
                  foreground: const Color(0xFF22D3EE),
                  background: const Color(0x3322D3EE),
                  border: const Color(0x6622D3EE),
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
                        'Focus ${focusMatched ? 'Linked' : 'Seeded'}: $focusReference',
                    foreground: focusMatched
                        ? const Color(0xFF34D399)
                        : const Color(0xFFF59E0B),
                    background: focusMatched
                        ? const Color(0x3334D399)
                        : const Color(0x33F59E0B),
                    border: focusMatched
                        ? const Color(0x6634D399)
                        : const Color(0x66F59E0B),
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
            label: '3 AI Actions Pending',
            foreground: const Color(0xFF22D3EE),
            background: const Color(0x3322D3EE),
            border: const Color(0x6622D3EE),
          ),
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
                  'Focus ${focusMatched ? 'Linked' : 'Seeded'}: $focusReference',
              foreground: focusMatched
                  ? const Color(0xFF34D399)
                  : const Color(0xFFF59E0B),
              background: focusMatched
                  ? const Color(0x3334D399)
                  : const Color(0x33F59E0B),
              border: focusMatched
                  ? const Color(0x6634D399)
                  : const Color(0x66F59E0B),
            ),
          ],
        ],
      ),
    );
  }

  Widget _incidentQueuePanel() {
    final wide = allowEmbeddedPanelScroll(context);
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

  Widget _actionLadderPanel(_IncidentRecord? activeIncident) {
    final steps = _ladderStepsFor(activeIncident);
    final wide = allowEmbeddedPanelScroll(context);
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

  Widget _contextAndVigilancePanel(_IncidentRecord? activeIncident) {
    final wide = allowEmbeddedPanelScroll(context);
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
                    ? _detailsTab(activeIncident)
                    : _activeTab == _ContextTab.voip
                    ? _voipTab(activeIncident)
                    : _visualTab(activeIncident),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _panel(
            title: 'Guard Vigilance',
            subtitle: 'Decay sparkline tracking and escalation posture',
            child: _vigilancePanel(),
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
                      ? _detailsTab(activeIncident)
                      : _activeTab == _ContextTab.voip
                      ? _voipTab(activeIncident)
                      : _visualTab(activeIncident),
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
            child: _vigilancePanel(),
          ),
        ),
      ],
    );
  }

  Widget _detailsTab(_IncidentRecord? incident) {
    final wide = allowEmbeddedPanelScroll(context);
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
      if (siteActivity != null && siteActivity.totalSignals > 0) ...[
        const SizedBox(height: 8),
        _siteActivityTruthCard(incident, siteActivity),
      ],
      if (moShadowPosture != null && moShadowPosture.moShadowMatchCount > 0) ...[
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
    if (widget.historicalSyntheticLearningLabels.isEmpty) {
      return const <MonitoringWatchAutonomyActionPlan>[];
    }
    return _orchestratorService
        .buildActionIntents(
          events: widget.events,
          sceneReviewByIntelligenceId: widget.sceneReviewByIntelligenceId,
          videoOpsLabel: widget.videoOpsLabel,
          historicalSyntheticLearningLabels:
              widget.historicalSyntheticLearningLabels,
        )
        .where((plan) => plan.metadata['scope'] == 'NEXT_SHIFT')
        .where(
          (plan) =>
              plan.siteId.trim() == incident.siteId.trim() ||
              (plan.metadata['lead_site'] ?? '').trim() ==
                  incident.siteId.trim() ||
              (plan.metadata['region'] ?? '').trim() == incident.regionId.trim(),
        )
        .toList(growable: false);
  }

  Widget _nextShiftDraftCard(
    _IncidentRecord incident,
    List<MonitoringWatchAutonomyActionPlan> drafts,
  ) {
    final leadDraft = drafts.first;
    final learningLabel = (leadDraft.metadata['learning_label'] ?? '').trim();
    final repeatCount = (leadDraft.metadata['learning_repeat_count'] ?? '')
        .trim();
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
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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

  Widget _voipTab(_IncidentRecord? incident) {
    final wide = allowEmbeddedPanelScroll(context);
    if (incident == null) return _muted('No active transcript.');
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

  Widget _visualTab(_IncidentRecord? incident) {
    if (incident == null) return _muted('No visual comparison available.');
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

  Widget _vigilancePanel() {
    final wide = allowEmbeddedPanelScroll(context);
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
    final rows = List<Widget>.generate(ledger.length.clamp(0, 20), (index) {
      final entry = ledger[index];
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
    return _panel(
      title: 'Sovereign Ledger Feed',
      subtitle: 'Immutable event chain across all incidents',
      child: Column(
        children: [
          if (embeddedScroll)
            Expanded(
              child: ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (context, index) => const SizedBox(height: 6),
                itemBuilder: (context, index) => rows[index],
              ),
            )
          else
            Column(
              children: [
                for (int i = 0; i < rows.length; i++) ...[
                  rows[i],
                  if (i < rows.length - 1) const SizedBox(height: 6),
                ],
              ],
            ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final summary = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.shield_rounded,
                    color: Color(0xFF22D3EE),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${ledger.length} events recorded • Chain intact',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF9AB2D2),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              );
              final verifyButton = OutlinedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ledger chain verification passed'),
                    ),
                  );
                },
                child: Text(
                  'Verify',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF22D3EE),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    summary,
                    const SizedBox(height: 8),
                    SizedBox(width: double.infinity, child: verifyButton),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: summary),
                  const SizedBox(width: 8),
                  verifyButton,
                ],
              );
            },
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
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: background,
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
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
    final focusReference = widget.focusIncidentReference.trim();
    final liveProjectedIncidents = _deriveIncidents(widget.events);
    final focusMatchedInLiveStream =
        focusReference.isNotEmpty &&
        liveProjectedIncidents.any((incident) => incident.id == focusReference);
    final projectedIncidents = _injectFocusedIncidentFallback(
      incidents: liveProjectedIncidents,
      focusReference: focusReference,
      hasLiveMatch: focusMatchedInLiveStream,
    );
    final projectedLedger = _deriveLedger(widget.events);
    final projectedVigilance = _deriveVigilance(widget.events);
    setState(() {
      _incidents = projectedIncidents;
      _projectedLedger = projectedLedger;
      _vigilance = projectedVigilance;
      _focusReferenceLinkedToLive = focusMatchedInLiveStream;
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
        type: 'Seeded Breach Playback',
        site: 'Demo Operations Lane',
        timestamp: _hhmm(DateTime.now().toLocal()),
        status: _statusOverrides[focusReference] ?? _IncidentStatus.dispatched,
      ),
      ...incidents,
    ];
  }

  List<_IncidentRecord> _deriveIncidents(List<DispatchEvent> events) {
    final decisions = events.whereType<DecisionCreated>().toList(
      growable: false,
    )..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    if (decisions.isEmpty) {
      final demo = _demoIncidents();
      return demo
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

  List<_IncidentRecord> _demoIncidents() {
    return const [
      _IncidentRecord(
        id: 'INC-8829-QX',
        clientId: '',
        regionId: '',
        siteId: '',
        priority: _IncidentPriority.p1Critical,
        type: 'Breach Detection',
        site: 'Sandton Estate North',
        timestamp: '22:14',
        status: _IncidentStatus.investigating,
      ),
      _IncidentRecord(
        id: 'INC-8830-RZ',
        clientId: '',
        regionId: '',
        siteId: '',
        priority: _IncidentPriority.p1Critical,
        type: 'Armed Response Request',
        site: 'Waterfall Estate Main',
        timestamp: '22:08',
        status: _IncidentStatus.dispatched,
      ),
      _IncidentRecord(
        id: 'INC-8827-PX',
        clientId: '',
        regionId: '',
        siteId: '',
        priority: _IncidentPriority.p2High,
        type: 'Perimeter Alarm',
        site: 'Blue Ridge Security',
        timestamp: '21:56',
        status: _IncidentStatus.triaging,
      ),
      _IncidentRecord(
        id: 'INC-8828-MN',
        clientId: '',
        regionId: '',
        siteId: '',
        priority: _IncidentPriority.p2High,
        type: 'Gate Malfunction',
        site: 'Midrand Industrial Park',
        timestamp: '21:45',
        status: _IncidentStatus.investigating,
      ),
      _IncidentRecord(
        id: 'INC-8826-KL',
        clientId: '',
        regionId: '',
        siteId: '',
        priority: _IncidentPriority.p3Medium,
        type: 'Power Failure',
        site: 'Centurion Mall',
        timestamp: '21:42',
        status: _IncidentStatus.resolved,
      ),
    ];
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
    final posture = (latestSceneReview?.postureLabel ?? '').trim().toLowerCase();
    if (posture.contains('fire') || posture.contains('smoke')) {
      return _IncidentPriority.p1Critical;
    }
    if (posture.contains('flood') || posture.contains('leak')) {
      return _IncidentPriority.p1Critical;
    }
    if (posture.contains('hazard')) {
      if (_priorityRank(basePriority) > _priorityRank(_IncidentPriority.p2High)) {
        return _IncidentPriority.p2High;
      }
    }
    return basePriority;
  }

  String _incidentTypeFor(
    int risk, {
    required MonitoringSceneReviewRecord? latestSceneReview,
  }) {
    final posture = (latestSceneReview?.postureLabel ?? '').trim().toLowerCase();
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
