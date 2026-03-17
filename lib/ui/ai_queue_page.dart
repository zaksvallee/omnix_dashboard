import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../application/monitoring_global_posture_service.dart';
import '../application/monitoring_scene_review_store.dart';
import '../application/monitoring_watch_action_plan.dart';
import '../application/monitoring_watch_autonomy_service.dart';
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
  final String videoOpsLabel;
  final Map<String, MonitoringSceneReviewRecord> sceneReviewByIntelligenceId;

  const AIQueuePage({
    super.key,
    required this.events,
    this.historicalSyntheticLearningLabels = const <String>[],
    this.videoOpsLabel = 'CCTV',
    this.sceneReviewByIntelligenceId = const {},
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

  Widget _activeAutomationCard(_AiQueueAction action) {
    final priority = _priorityStyle(action.incidentPriority);
    final countdownColor = action.timeUntilExecutionSeconds <= 10
        ? const Color(0xFFEF4444)
        : action.timeUntilExecutionSeconds <= 20
        ? const Color(0xFFF59E0B)
        : const Color(0xFF22D3EE);
    final progress = (action.timeUntilExecutionSeconds / 30).clamp(0.0, 1.0);
    final paused = action.status == _AiActionStatus.paused;

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
                if ((leadDraft.metadata['learning_label'] ?? '').isNotEmpty)
                  _detailCell('Learning', leadDraft.metadata['learning_label']!),
                if ((leadDraft.metadata['learning_repeat_count'] ?? '').isNotEmpty)
                  _detailCell(
                    'Memory',
                    'x${leadDraft.metadata['learning_repeat_count']}',
                  ),
                if ((leadDraft.metadata['draft_countdown'] ?? '').isNotEmpty)
                  _detailCell(
                    'Countdown',
                    '${leadDraft.metadata['draft_countdown']}s',
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
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
    return <String, Object?>{
      'generatedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'siteCount': sites.length,
      'sites': sites
          .map(
            (site) => <String, Object?>{
              'siteId': site.siteId,
              'regionId': site.regionId,
              'heatLevel': site.heatLevel.name,
              'matchCount': site.moShadowMatchCount,
              'summary': site.moShadowSummary,
              'matches': site.moShadowMatches
                  .map(
                    (match) => <String, Object?>{
                      'moId': match.moId,
                      'title': match.title,
                      'incidentType': match.incidentType,
                      'behaviorStage': match.behaviorStage,
                      'matchScore': match.matchScore,
                      'matchedIndicators': match.matchedIndicators,
                      'recommendedActionPlans': match.recommendedActionPlans,
                    },
                  )
                  .toList(growable: false),
            },
          )
          .toList(growable: false),
    };
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
      _actions = _actions
          .map((action) {
            if (action.status != _AiActionStatus.executing) {
              return action;
            }
            if (action.timeUntilExecutionSeconds <= 0) {
              return action;
            }
            return action.copyWith(
              timeUntilExecutionSeconds: action.timeUntilExecutionSeconds - 1,
            );
          })
          .toList();

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
      _actions = _actions
          .map((action) {
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
          })
          .toList();
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
    final autonomyPlans = _autonomyService.buildPlans(
      events: events,
      sceneReviewByIntelligenceId: sceneReviewByIntelligenceId,
      videoOpsLabel: widget.videoOpsLabel,
      historicalSyntheticLearningLabels: widget.historicalSyntheticLearningLabels,
    );
    if (autonomyPlans.isNotEmpty) {
      return autonomyPlans.asMap().entries.map((entry) {
        final plan = entry.value;
        return _AiQueueAction(
          id: plan.id,
          incidentId: plan.incidentId,
          incidentPriority: switch (plan.priority) {
            MonitoringWatchAutonomyPriority.critical =>
              _AiIncidentPriority.p1Critical,
            MonitoringWatchAutonomyPriority.high => _AiIncidentPriority.p2High,
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
      }).toList(growable: false);
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

  _AiQueueDailyStats _buildDailyStats(List<DispatchEvent> events) {
    final nowUtc = DateTime.now().toUtc();
    final windowStart = nowUtc.subtract(const Duration(hours: 24));
    final decisions24h = events
        .whereType<DispatchEvent>()
        .where((event) => event is DecisionCreated || event is IntelligenceReceived)
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
