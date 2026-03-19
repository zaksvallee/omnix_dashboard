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

enum _AiIncidentPriority { p1Critical, p2High, p3Medium }

enum _AiActionStatus { pending, executing, paused }

class _AiQueueAction {
  final String id;
  final String incidentId;
  final _AiIncidentPriority incidentPriority;
  final String site;
  final String actionType;
  final String description;
  final int timeUntilExecutionSeconds;
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

class AIQueuePage extends StatefulWidget {
  final List<DispatchEvent> events;
  final List<String> historicalSyntheticLearningLabels;
  final List<String> historicalShadowMoLabels;
  final List<String> historicalShadowStrengthLabels;
  final String previousTomorrowUrgencySummary;
  final String videoOpsLabel;
  final Map<String, MonitoringSceneReviewRecord> sceneReviewByIntelligenceId;
  final void Function(List<String> eventIds, String? selectedEventId)?
  onOpenEventsForScope;

  const AIQueuePage({
    super.key,
    required this.events,
    this.historicalSyntheticLearningLabels = const <String>[],
    this.historicalShadowMoLabels = const <String>[],
    this.historicalShadowStrengthLabels = const <String>[],
    this.previousTomorrowUrgencySummary = '',
    this.videoOpsLabel = 'CCTV',
    this.sceneReviewByIntelligenceId = const {},
    this.onOpenEventsForScope,
  });

  @override
  State<AIQueuePage> createState() => _AIQueuePageState();
}

class _AIQueuePageState extends State<AIQueuePage> {
  static const _autonomyService = MonitoringWatchAutonomyService();
  static const _globalPostureService = MonitoringGlobalPostureService();
  late List<_AiQueueAction> _actions;
  late final _AiQueueDailyStats _stats;
  Timer? _ticker;
  bool _queuePaused = false;

  @override
  void initState() {
    super.initState();
    _actions = List<_AiQueueAction>.from(
      _seedActions(widget.events, widget.sceneReviewByIntelligenceId),
    );
    _stats = _buildDailyStats(widget.events);
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
    final queuedActions = _queuedActions;
    final nextShiftDrafts = _nextShiftDrafts;
    final moShadowSites = _moShadowSites;
    final viewport = MediaQuery.sizeOf(context).width;
    final compact = viewport < 900 || isHandsetLayout(context);
    final contentPadding = compact
        ? const EdgeInsets.all(14)
        : const EdgeInsets.fromLTRB(24, 22, 24, 22);

    return OnyxPageScaffold(
      child: SingleChildScrollView(
        padding: contentPadding,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1320),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heroHeader(
                  context,
                  compact: compact,
                  totalQueueCount: _actions.length,
                  queuedCount: queuedActions.length,
                ),
                const SizedBox(height: 16),
                _queueSummaryBar(
                  totalQueueCount: _actions.length,
                  queuedCount: queuedActions.length,
                  paused: _queuePaused,
                ),
                const SizedBox(height: 16),
                _overviewGrid(
                  activeAction: activeAction,
                  queuedCount: queuedActions.length,
                  nextShiftCount: nextShiftDrafts.length,
                ),
                const SizedBox(height: 16),
                _header(compact: compact),
                const SizedBox(height: 16),
                if (moShadowSites.isNotEmpty) ...[
                  _moShadowCard(moShadowSites),
                  const SizedBox(height: 16),
                ],
                if (activeAction != null) _activeAutomationCard(activeAction),
                const SizedBox(height: 16),
                _queuedActionsCard(queuedActions),
                if (nextShiftDrafts.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _nextShiftDraftsCard(nextShiftDrafts),
                ],
                const SizedBox(height: 16),
                _todayPerformance(compact: compact),
              ],
            ),
          ),
        ),
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

  Widget _header({required bool compact}) {
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0x3322D3EE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.psychology_alt_rounded,
                  size: 30,
                  color: Color(0xFF22D3EE),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Automation Queue',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFEAF4FF),
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Human-parallel execution supervision',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8EA4C2),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF22D3EE),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'AI Engine Active',
                style: GoogleFonts.inter(
                  color: const Color(0xFF9AB5D7),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      );
    }
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0x3322D3EE),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.psychology_alt_rounded,
            size: 30,
            color: Color(0xFF22D3EE),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI Automation Queue',
                style: GoogleFonts.inter(
                  color: const Color(0xFFEAF4FF),
                  fontSize: compact ? 24 : 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Human-parallel execution supervision',
                style: GoogleFonts.inter(
                  color: const Color(0xFF8EA4C2),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Color(0xFF22D3EE),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'AI Engine Active',
          style: GoogleFonts.inter(
            color: const Color(0xFF9AB5D7),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _heroHeader(
    BuildContext context, {
    required bool compact,
    required int totalQueueCount,
    required int queuedCount,
  }) {
    final activeAction = _activeAction;
    final canOpenEvents =
        activeAction != null &&
        widget.onOpenEventsForScope != null &&
        _eventIdsForAction(activeAction).isNotEmpty;
    final openEventsAction = canOpenEvents ? activeAction : null;
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(
                Icons.psychology_alt_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Automation Queue',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFF6FBFF),
                      fontSize: compact ? 22 : 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Human-parallel execution supervision with live intervention windows.',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF95A9C7),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _heroChip('Engine', _queuePaused ? 'Paused' : 'Active'),
            _heroChip('Total Queue', '$totalQueueCount'),
            _heroChip('Queued', '$queuedCount'),
            _heroChip(
              'Active Site',
              activeAction?.site ?? 'Awaiting Automation',
            ),
          ],
        ),
      ],
    );
    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.end,
      children: [
        _heroActionButton(
          key: const ValueKey('ai-queue-view-events-button'),
          icon: Icons.open_in_new,
          label: 'View Events',
          accent: const Color(0xFF93C5FD),
          onPressed: openEventsAction == null
              ? null
              : () => _openEventsForAction(openEventsAction),
        ),
      ],
    );
    if (compact) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1433), Color(0xFF10172A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF2A3150)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleBlock,
            const SizedBox(height: 16),
            actions,
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1433), Color(0xFF10172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2A3150)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: titleBlock),
          const SizedBox(width: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: actions,
          ),
        ],
      ),
    );
  }

  Widget _heroChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x14000000),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x33000000)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: GoogleFonts.inter(
                color: const Color(0xFF8EA4C2),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value,
              style: GoogleFonts.inter(
                color: const Color(0xFFE8F1FF),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
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
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: accent.withValues(alpha: 0.12),
        foregroundColor: accent,
        disabledBackgroundColor: const Color(0x12000000),
        disabledForegroundColor: const Color(0x667A8CA8),
        side: BorderSide(color: accent.withValues(alpha: 0.28)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        textStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _queueSummaryBar({
    required int totalQueueCount,
    required int queuedCount,
    required bool paused,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131726),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A3150)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'QUEUE STATUS',
            style: GoogleFonts.inter(
              color: const Color(0x669BB0CE),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          _statusPill(
            icon: Icons.bolt_rounded,
            label: paused ? 'Engine Paused' : 'AI Engine Active',
            accent: paused
                ? const Color(0xFFF6C067)
                : const Color(0xFF34D399),
          ),
          _statusPill(
            icon: Icons.schedule_rounded,
            label: '$queuedCount Queued',
            accent: const Color(0xFF63BDFF),
          ),
          _statusPill(
            icon: Icons.list_alt_rounded,
            label: '$totalQueueCount Total',
            accent: const Color(0xFFA78BFA),
          ),
        ],
      ),
    );
  }

  Widget _statusPill({
    required IconData icon,
    required String label,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _overviewGrid({
    required _AiQueueAction? activeAction,
    required int queuedCount,
    required int nextShiftCount,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1200
            ? 4
            : constraints.maxWidth >= 760
            ? 2
            : 1;
        final aspectRatio = columns == 4
            ? 1.95
            : columns == 2
            ? 2.35
            : 2.55;
        return GridView.count(
          key: const ValueKey('ai-queue-overview-grid'),
          crossAxisCount: columns,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: aspectRatio,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _overviewCard(
              title: 'Active Automation',
              value: activeAction == null ? 'None' : '1',
              detail: activeAction == null
                  ? 'No active automation is executing right now.'
                  : '${activeAction.actionType} is currently inside the intervention window.',
              icon: Icons.bolt_rounded,
              accent: const Color(0xFF22D3EE),
            ),
            _overviewCard(
              title: 'Queued Actions',
              value: '$queuedCount',
              detail: 'Automation items waiting behind the active action.',
              icon: Icons.schedule_rounded,
              accent: const Color(0xFF63BDFF),
            ),
            _overviewCard(
              title: 'Next Shift Drafts',
              value: '$nextShiftCount',
              detail: 'Carry-forward posture and draft actions prepared for the next shift.',
              icon: Icons.history_toggle_off_rounded,
              accent: const Color(0xFFA78BFA),
            ),
            _overviewCard(
              title: 'Active Site',
              value: activeAction?.site ?? 'Standby',
              detail: activeAction == null
                  ? 'Awaiting live automation plans from the event stream.'
                  : 'Current automation focus for human-parallel supervision.',
              icon: Icons.place_outlined,
              accent: const Color(0xFF34D399),
            ),
          ],
        );
      },
    );
  }

  Widget _overviewCard({
    required String title,
    required String value,
    required String detail,
    required IconData icon,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: GoogleFonts.robotoMono(
                    color: const Color(0xFFF4F8FF),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              color: const Color(0xFF93A5BF),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: const Color(0xFFD5E1F2),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _activeAutomationCard(_AiQueueAction action) {
    final priority = _priorityStyle(action.incidentPriority);
    final countdownColor = action.timeUntilExecutionSeconds <= 10
        ? const Color(0xFFEF4444)
        : action.timeUntilExecutionSeconds <= 20
        ? const Color(0xFFF59E0B)
        : const Color(0xFF22D3EE);
    final progress = (action.timeUntilExecutionSeconds / 30).clamp(0.0, 1.0);
    final paused = action.status == _AiActionStatus.paused;
    final promotionPressureSummary = _promotionPressureSummary(action.metadata);
    final promotionExecutionSummary = _promotionExecutionSummary(
      action.metadata,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(border: const Color(0x6640A5D8), glow: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0x3322D3EE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Color(0xFF22D3EE),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      paused
                          ? 'Active Automation (Paused)'
                          : 'Active Automation',
                      style: GoogleFonts.rajdhani(
                        color: const Color(0xFFE8F3FF),
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      paused
                          ? 'Execution hold is active'
                          : 'AI is preparing to execute',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF9AB5D7),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
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
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0x55000000),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF283A53)),
            ),
            child: Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                _detailCell('Incident', action.incidentId, mono: true),
                _detailCell('Site', action.site),
                _detailCell('Action', action.actionType),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            action.description,
            style: GoogleFonts.inter(
              color: const Color(0xFFE6F0FF),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (promotionPressureSummary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Promotion pressure: $promotionPressureSummary',
              style: GoogleFonts.inter(
                color: const Color(0xFF86EFAC),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (promotionExecutionSummary.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Promotion execution: $promotionExecutionSummary',
              style: GoogleFonts.inter(
                color: const Color(0xFF86EFAC),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (action.metadata.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: action.metadata.entries
                  .map((entry) => _detailCell(entry.key, entry.value))
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      paused ? 'Paused at' : 'Auto-executes in',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFA1B7D5),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(action.timeUntilExecutionSeconds),
                      style: GoogleFonts.rajdhani(
                        color: countdownColor,
                        fontSize: 42,
                        height: 0.88,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Text(
                    paused ? 'Paused at' : 'Auto-executes in',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFA1B7D5),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatTime(action.timeUntilExecutionSeconds),
                    style: GoogleFonts.rajdhani(
                      color: countdownColor,
                      fontSize: 46,
                      height: 0.88,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: paused ? progress : progress,
              backgroundColor: const Color(0x66000000),
              valueColor: AlwaysStoppedAnimation<Color>(countdownColor),
            ),
          ),
          const SizedBox(height: 14),
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
                      background: const Color(0xFFEF4444),
                      onPressed: () => _cancelAction(action.id),
                    ),
                    const SizedBox(height: 8),
                    _actionButton(
                      label: paused ? 'RESUME' : 'PAUSE',
                      icon: paused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      background: const Color(0xFF24354E),
                      onPressed: () => _togglePause(action.id),
                    ),
                    const SizedBox(height: 8),
                    _actionButton(
                      label: 'APPROVE NOW',
                      icon: Icons.check_circle_rounded,
                      background: const Color(0xFF10B981),
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
                      background: const Color(0xFFEF4444),
                      onPressed: () => _cancelAction(action.id),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _actionButton(
                    label: paused ? 'RESUME' : 'PAUSE',
                    icon: paused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    background: const Color(0xFF24354E),
                    onPressed: () => _togglePause(action.id),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _actionButton(
                      label: 'APPROVE NOW',
                      icon: Icons.check_circle_rounded,
                      background: const Color(0xFF10B981),
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

  Widget _queuedActionsCard(List<_AiQueueAction> queuedActions) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(border: const Color(0xFF223A59)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(
                Icons.schedule_rounded,
                color: Color(0xFFA9BEDB),
                size: 20,
              ),
              Text(
                'Queued Actions',
                style: GoogleFonts.rajdhani(
                  color: const Color(0xFFE7F1FF),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(0x3322D3EE),
                  border: Border.all(color: const Color(0x6622D3EE)),
                ),
                child: Text(
                  '${queuedActions.length}',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF22D3EE),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (queuedActions.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: const Color(0x33000000),
                border: Border.all(color: const Color(0xFF2A3D58)),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    color: Color(0xFF6F84A3),
                    size: 30,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No actions queued',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF9AB1CF),
                      fontSize: 13,
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
                  if (i != queuedActions.length - 1) const SizedBox(height: 8),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _queuedRow({required int index, required _AiQueueAction action}) {
    final promotionPressureSummary = _promotionPressureSummary(action.metadata);
    final promotionExecutionSummary = _promotionExecutionSummary(
      action.metadata,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: const Color(0x33000000),
        border: Border.all(color: const Color(0xFF2A3E59)),
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
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: const Color(0x3322D3EE),
                      border: Border.all(color: const Color(0x6622D3EE)),
                    ),
                    child: Text(
                      '$index',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF22D3EE),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
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
                                color: const Color(0xFFE5EFFF),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '• ${action.incidentId}',
                              style: GoogleFonts.robotoMono(
                                color: const Color(0xFF22D3EE),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          action.description,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF9CB2D1),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (promotionPressureSummary.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Promotion pressure: $promotionPressureSummary',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF86EFAC),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        if (promotionExecutionSummary.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Promotion execution: $promotionExecutionSummary',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF86EFAC),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
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
                        color: const Color(0xFF7D92B2),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _formatTime(action.timeUntilExecutionSeconds),
                      style: GoogleFonts.robotoMono(
                        color: const Color(0xFF22D3EE),
                        fontSize: 17,
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
        color: const Color(0xFFE6F0FF),
        border: const Color(0xFF253B5A),
      ),
      (
        label: 'Executed',
        value: _stats.executed.toString(),
        color: const Color(0xFF10B981),
        border: const Color(0x5522C38E),
      ),
      (
        label: 'Overridden',
        value: _stats.overridden.toString(),
        color: const Color(0xFFF59E0B),
        border: const Color(0x55E8A635),
      ),
      (
        label: 'Approval Rate',
        value: '${_stats.approvalRate}%',
        color: const Color(0xFF22D3EE),
        border: const Color(0x5540BAD4),
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
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(border: const Color(0x665C7CFA)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(
                Icons.upcoming_rounded,
                color: Color(0xFFC8D2FF),
                size: 20,
              ),
              Text(
                'Next-Shift Drafts',
                style: GoogleFonts.rajdhani(
                  color: const Color(0xFFE7F1FF),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(0x225C7CFA),
                  border: Border.all(color: const Color(0x665C7CFA)),
                ),
                child: Text(
                  '${drafts.length}',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFC8D2FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            leadDraft.actionType,
            style: GoogleFonts.inter(
              color: const Color(0xFFE7F1FF),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            leadDraft.description,
            style: GoogleFonts.inter(
              color: const Color(0xFFDAE4FF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (leadDraft.metadata.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
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
          const SizedBox(height: 10),
          Column(
            children: [
              for (var i = 0; i < drafts.length; i++) ...[
                _queuedRow(index: i + 1, action: drafts[i]),
                if (i < drafts.length - 1) const SizedBox(height: 8),
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
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(border: const Color(0x665B9BD5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(
                Icons.visibility_rounded,
                color: Color(0xFFB8D7FF),
                size: 20,
              ),
              Text(
                'Shadow MO Intelligence',
                style: GoogleFonts.rajdhani(
                  color: const Color(0xFFE7F1FF),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(0x225B9BD5),
                  border: Border.all(color: const Color(0x665B9BD5)),
                ),
                child: Text(
                  '${sites.length}',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFB8D7FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${lead.siteId} • ${lead.moShadowSummary}',
            style: GoogleFonts.inter(
              color: const Color(0xFFE6F0FF),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
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
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              key: const ValueKey('ai-queue-mo-shadow-open-dossier'),
              onPressed: () => _showMoShadowDossier(sites),
              child: const Text('VIEW DOSSIER'),
            ),
          ),
          if (supporting.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Supporting sites: $supporting',
              style: GoogleFonts.inter(
                color: const Color(0xFF9AB5D7),
                fontSize: 11,
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
                key: const ValueKey('ai-queue-mo-shadow-dialog'),
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
                          final payload = _moShadowDossierPayload(sites);
                          Clipboard.setData(
                            ClipboardData(
                              text: const JsonEncoder.withIndent(
                                '  ',
                              ).convert(payload),
                            ),
                          );
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
                  Expanded(
                    child: ListView.separated(
                      itemCount: sites.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final site = sites[index];
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
                                '${site.siteId} • ${site.moShadowSummary}',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFEAF4FF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              for (final match in site.moShadowMatches) ...[
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
                                if (match
                                    .recommendedActionPlans
                                    .isNotEmpty) ...[
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
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(border: border),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA5C5),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.rajdhani(
              color: color,
              fontSize: 36,
              height: 0.9,
              fontWeight: FontWeight.w700,
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
            color: const Color(0xFF7F95B6),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
          ),
        ),
        Text(
          value,
          style: mono
              ? GoogleFonts.robotoMono(
                  color: const Color(0xFF22D3EE),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                )
              : GoogleFonts.inter(
                  color: const Color(0xFFE8F1FF),
                  fontSize: 12,
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
      icon: Icon(icon, size: 18),
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: const Color(0xFFF3F8FF),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
      label: Text(label),
    );
  }

  BoxDecoration _panelDecoration({required Color border, bool glow = false}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: const Color(0xFF0E1A2B),
      border: Border.all(color: border),
      boxShadow: glow
          ? const [
              BoxShadow(
                color: Color(0x3022D3EE),
                blurRadius: 18,
                spreadRadius: 1,
                offset: Offset(0, 0),
              ),
            ]
          : const [],
    );
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

  List<_AiQueueAction> get _nextShiftDrafts => _actions
      .where((action) => action.metadata['scope'] == 'NEXT_SHIFT')
      .toList(growable: false);

  List<MonitoringGlobalSitePosture> get _moShadowSites {
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
      }
      _ensureSingleExecuting();
    });
  }

  void _cancelAction(String actionId) {
    setState(() {
      _actions.removeWhere((action) => action.id == actionId);
      _queuePaused = false;
      _ensureSingleExecuting();
    });
  }

  void _approveAction(String actionId) {
    setState(() {
      _actions.removeWhere((action) => action.id == actionId);
      _queuePaused = false;
      _ensureSingleExecuting();
    });
  }

  void _togglePause(String actionId) {
    setState(() {
      _actions = _actions.map((action) {
        if (action.id != actionId) {
          return action;
        }
        if (action.status == _AiActionStatus.paused) {
          return action.copyWith(status: _AiActionStatus.executing);
        }
        if (action.status == _AiActionStatus.executing) {
          return action.copyWith(status: _AiActionStatus.paused);
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

  String _formatTime(int totalSeconds) {
    final bounded = totalSeconds < 0 ? 0 : totalSeconds;
    final mins = bounded ~/ 60;
    final secs = bounded % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  _AiQueuePriorityStyle _priorityStyle(_AiIncidentPriority priority) {
    return switch (priority) {
      _AiIncidentPriority.p1Critical => const _AiQueuePriorityStyle(
        label: 'P1-CRITICAL',
        foreground: Color(0xFFEF4444),
        background: Color(0x33EF4444),
        border: Color(0x66EF4444),
      ),
      _AiIncidentPriority.p2High => const _AiQueuePriorityStyle(
        label: 'P2-HIGH',
        foreground: Color(0xFFF59E0B),
        background: Color(0x33F59E0B),
        border: Color(0x66F59E0B),
      ),
      _AiIncidentPriority.p3Medium => const _AiQueuePriorityStyle(
        label: 'P3-MEDIUM',
        foreground: Color(0xFFFACC15),
        background: Color(0x33FACC15),
        border: Color(0x66FACC15),
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
    final prebuiltSummary =
        (metadata['mo_promotion_pressure_summary'] ?? '').trim();
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
      promotionPriorityBias:
          (metadata['mo_promotion_priority_bias'] ?? '').trim(),
      promotionCountdownBias:
          (metadata['mo_promotion_countdown_bias'] ?? '').trim(),
    );
  }

  String _shadowPostureBiasSummary(Map<String, String> metadata) {
    final prebuiltSummary =
        (metadata['shadow_posture_bias_summary'] ?? '').trim();
    if (prebuiltSummary.isNotEmpty) {
      return prebuiltSummary;
    }
    final postureBias = (metadata['shadow_posture_bias'] ?? '').trim();
    final posturePriority = (metadata['shadow_posture_priority'] ?? '').trim();
    final postureCountdown =
        (metadata['shadow_posture_countdown'] ?? '').trim();
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
