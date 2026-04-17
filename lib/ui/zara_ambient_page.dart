import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../domain/events/dispatch_event.dart';
import '../domain/projection/operations_health_projection.dart';
import 'onyx_surface.dart';
import 'theme/onyx_design_tokens.dart';

class ZaraAmbientPage extends StatefulWidget {
  final List<DispatchEvent> events;
  final String operatorLabel;
  final String siteLabel;
  final VoidCallback onOpenCommandCenter;
  final VoidCallback? onOpenAlarms;
  final VoidCallback? onOpenDispatches;
  final VoidCallback? onOpenGuards;
  final VoidCallback? onOpenCctv;

  const ZaraAmbientPage({
    super.key,
    required this.events,
    required this.operatorLabel,
    required this.siteLabel,
    required this.onOpenCommandCenter,
    this.onOpenAlarms,
    this.onOpenDispatches,
    this.onOpenGuards,
    this.onOpenCctv,
  });

  @override
  State<ZaraAmbientPage> createState() => _ZaraAmbientPageState();
}

class _ZaraAmbientPageState extends State<ZaraAmbientPage>
    with TickerProviderStateMixin {
  static const double _heartbeatChipHeight = 44;
  static const double _floatingCardCompactClearance = 220;
  static const double _floatingCardWideClearance = 192;

  late final AnimationController _fadeController;
  late final AnimationController _pulseController;
  late final AnimationController _surfaceController;
  late final Animation<double> _fadeIn;
  late final Animation<double> _pulseAnimation;
  late final Animation<Offset> _surfaceSlide;
  late final Animation<double> _surfaceFade;
  Timer? _clockTimer;
  Timer? _statementTimer;
  String _timeLabel = '';
  bool _actionCardVisible = false;
  int _previousIncidentCount = -1;
  int _previousDispatchCount = -1;
  int _statementIndex = 0;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeIn = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _surfaceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _surfaceSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _surfaceController,
            curve: Curves.easeInOutCubic,
          ),
        );
    _surfaceFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _surfaceController, curve: Curves.easeOut),
    );

    _updateTime();
    _clockTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _updateTime(),
    );
    _statementTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) setState(() => _statementIndex++);
    });
  }

  void _updateTime() {
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
        ? 'Good afternoon'
        : 'Good evening';
    if (mounted) setState(() => _timeLabel = greeting);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    _surfaceController.dispose();
    _clockTimer?.cancel();
    _statementTimer?.cancel();
    super.dispose();
  }

  void _evaluateEventSurface(int incidentCount, int dispatchCount) {
    if (_previousIncidentCount < 0) {
      _previousIncidentCount = incidentCount;
      _previousDispatchCount = dispatchCount;
      return;
    }
    final shouldSurface =
        incidentCount > _previousIncidentCount ||
        (dispatchCount > _previousDispatchCount && dispatchCount > 0);
    _previousIncidentCount = incidentCount;
    _previousDispatchCount = dispatchCount;

    if (shouldSurface && !_actionCardVisible) {
      setState(() => _actionCardVisible = true);
      _surfaceController.forward(from: 0.0);
    }
  }

  void _dismissActionCard() {
    _surfaceController.reverse().then((_) {
      if (mounted) setState(() => _actionCardVisible = false);
    });
  }

  double _bottomContentClearance({required bool compact}) {
    final actionCardClearance = _actionCardVisible
        ? (compact ? _floatingCardCompactClearance : _floatingCardWideClearance)
        : 0.0;
    return _heartbeatChipHeight + 36 + actionCardClearance;
  }

  double _heartbeatBottomOffset({required bool compact}) {
    final actionCardClearance = _actionCardVisible
        ? (compact ? _floatingCardCompactClearance : _floatingCardWideClearance)
        : 0.0;
    return 24 + actionCardClearance;
  }

  @override
  Widget build(BuildContext context) {
    final projection = OperationsHealthProjection.build(widget.events);
    final operatorName = widget.operatorLabel.trim().isEmpty
        ? 'Operator'
        : widget.operatorLabel.trim().split(' ').first;
    final siteCount = projection.totalSites;
    final activeDispatches =
        projection.totalDecisions -
        projection.totalExecuted -
        projection.totalDenied;
    final activeDispatchCount = activeDispatches.clamp(0, 999);
    final guardCount = projection.totalCheckIns;
    final incidentCount = projection.totalFailed;
    final highRiskIntel = projection.highRiskIntelligence;
    final pressure = projection.controllerPressureIndex;

    final allClear =
        activeDispatchCount == 0 && incidentCount == 0 && highRiskIntel == 0;

    final statusMessage = allClear
        ? 'All systems operational.\nNo incidents require your attention.'
        : incidentCount > 0
        ? '$incidentCount active incident${incidentCount == 1 ? '' : 's'} detected.\nHuman decision may be required.'
        : activeDispatchCount > 0
        ? '$activeDispatchCount dispatch${activeDispatchCount == 1 ? '' : 'es'} in progress.\nMonitoring autonomously.'
        : highRiskIntel > 0
        ? '$highRiskIntel high-risk intelligence signal${highRiskIntel == 1 ? '' : 's'}.\nArea threat elevated.'
        : 'All systems operational.';

    final statusAccent = allClear
        ? OnyxColorTokens.accentGreen
        : incidentCount > 0
        ? OnyxColorTokens.accentRed
        : activeDispatchCount > 0
        ? OnyxColorTokens.accentAmber
        : OnyxColorTokens.accentAmber;

    _evaluateEventSurface(incidentCount, activeDispatchCount);

    final autonomousOps = _buildAutonomousLog(projection);

    return OnyxPageScaffold(
      child: FadeTransition(
        opacity: _fadeIn,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 700;
            final horizontalPadding = compact ? 24.0 : 48.0;
            final surfacedCardWidth = compact ? 520.0 : 460.0;
            return Stack(
              children: [
                SizedBox.expand(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      32,
                      horizontalPadding,
                      32 + _bottomContentClearance(compact: compact),
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _zaraIdentity(),
                            const SizedBox(height: 32),
                            _greetingCard(
                              operatorName: operatorName,
                              siteLabel: widget.siteLabel,
                              statusMessage: statusMessage,
                              statusAccent: statusAccent,
                              allClear: allClear,
                            ),
                            const SizedBox(height: 24),
                            _zaraIntelligenceStatement(projection),
                            const SizedBox(height: 32),
                            _systemHealthBar(
                              siteCount: siteCount,
                              guardCount: guardCount,
                              dispatchCount: activeDispatchCount,
                              pressure: pressure,
                            ),
                            if (autonomousOps.isNotEmpty) ...[
                              const SizedBox(height: 32),
                              _autonomousOpsSection(autonomousOps),
                            ],
                            const SizedBox(height: 32),
                            if (projection.liveSignals.isNotEmpty) ...[
                              _liveSignalFeed(projection.liveSignals),
                              const SizedBox(height: 32),
                            ],
                            _quickActions(compact: compact),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: compact ? 16 : 24,
                  bottom: _heartbeatBottomOffset(compact: compact),
                  child: IgnorePointer(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: _zaraHeartbeatChip(),
                    ),
                  ),
                ),
                if (_actionCardVisible)
                  Positioned(
                    left: compact ? 16 : 32,
                    right: compact ? 16 : 32,
                    bottom: 24,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: surfacedCardWidth,
                        ),
                        child: SlideTransition(
                          position: _surfaceSlide,
                          child: FadeTransition(
                            opacity: _surfaceFade,
                            child: _surfacedActionCard(
                              incidentCount: incidentCount,
                              dispatchCount: activeDispatchCount,
                              dispatchFeed: projection.dispatchFeed,
                              statusAccent: statusAccent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Zara identity ─────────────────────────────────────────────────────────

  Widget _zaraIdentity() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    OnyxColorTokens.brand.withValues(
                      alpha: 0.3 * _pulseAnimation.value,
                    ),
                    OnyxColorTokens.brand.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
              child: Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: OnyxColorTokens.brand.withValues(alpha: 0.15),
                    border: Border.all(
                      color: OnyxColorTokens.brand.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: OnyxColorTokens.brand,
                    size: 24,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        Text(
          'Z A R A',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: OnyxColorTokens.brand,
            letterSpacing: 4.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'ONYX Security Intelligence',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: OnyxColorTokens.textMuted,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  // ── Greeting card ─────────────────────────────────────────────────────────

  Widget _greetingCard({
    required String operatorName,
    required String siteLabel,
    required String statusMessage,
    required Color statusAccent,
    required bool allClear,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusAccent.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: statusAccent.withValues(alpha: 0.06),
            blurRadius: 40,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '$_timeLabel, $operatorName.',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: OnyxColorTokens.textPrimary,
                    height: 1.3,
                  ),
                ),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusAccent,
                  boxShadow: [
                    BoxShadow(
                      color: statusAccent.withValues(alpha: 0.6),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$siteLabel ${allClear ? 'secure' : 'active'}.',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: OnyxColorTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            statusMessage,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: OnyxColorTokens.textSecondary,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  // ── Intelligence statement ─────────────────────────────────────────────────

  List<String> _intelligenceStatements(OperationsHealthSnapshot projection) {
    final statements = <String>[];
    final now = DateTime.now();
    final hour = now.hour;
    final minuteStr = now.minute.toString().padLeft(2, '0');

    if (projection.totalFailed > 0) {
      statements.add(
        'Monitoring ${projection.totalFailed} unresolved '
        'incident${projection.totalFailed == 1 ? '' : 's'}. '
        'Response chain analysis in progress.',
      );
    }
    if (projection.highRiskIntelligence > 0) {
      statements.add(
        '${projection.highRiskIntelligence} high-risk intelligence '
        'signal${projection.highRiskIntelligence == 1 ? '' : 's'} detected. '
        'Threat posture elevated for affected areas.',
      );
    }
    if (projection.totalPatrols > 0) {
      statements.add(
        '${projection.totalPatrols} patrol route'
        '${projection.totalPatrols == 1 ? '' : 's'} verified. '
        'All checkpoints confirmed — no anomalies.',
      );
    }
    statements.add(
      '${projection.totalSites} site'
      '${projection.totalSites == 1 ? '' : 's'} under continuous watch. '
      'Next system audit at ${(hour + 1) % 24}:$minuteStr.',
    );
    if (projection.averageResponseMinutes > 0) {
      statements.add(
        'Average response time: '
        '${projection.averageResponseMinutes.toStringAsFixed(1)} minutes. '
        '${projection.averageResponseMinutes < 10 ? 'Within operational target.' : 'Monitoring for improvement.'}',
      );
    }
    statements.add(
      'Event chain integrity maintained. '
      '${projection.totalDecisions} decisions processed, '
      '${projection.totalExecuted} confirmed.',
    );
    return statements;
  }

  Widget _zaraIntelligenceStatement(OperationsHealthSnapshot projection) {
    final statements = _intelligenceStatements(projection);
    if (statements.isEmpty) return const SizedBox.shrink();
    final current = statements[_statementIndex % statements.length];

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: Container(
        key: ValueKey<int>(_statementIndex % statements.length),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: OnyxColorTokens.brand.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: OnyxColorTokens.brand.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 14,
                color: OnyxColorTokens.brand.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                current,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: OnyxColorTokens.textSecondary,
                  height: 1.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── System health bar ─────────────────────────────────────────────────────

  Widget _systemHealthBar({
    required int siteCount,
    required int guardCount,
    required int dispatchCount,
    required double pressure,
  }) {
    final pressureLabel = pressure < 30
        ? 'LOW'
        : pressure < 65
        ? 'NORMAL'
        : 'ELEVATED';
    final pressureColor = pressure < 30
        ? OnyxColorTokens.accentGreen
        : pressure < 65
        ? OnyxColorTokens.accentCyanTrue
        : OnyxColorTokens.accentAmber;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        _healthPill(
          Icons.apartment_rounded,
          '$siteCount sites',
          OnyxColorTokens.accentCyanTrue,
        ),
        _healthPill(
          Icons.shield_rounded,
          '$guardCount guards',
          OnyxColorTokens.accentGreen,
        ),
        _healthPill(
          Icons.send_rounded,
          '$dispatchCount active',
          dispatchCount > 0
              ? OnyxColorTokens.accentAmber
              : OnyxColorTokens.textMuted,
        ),
        _healthPill(Icons.speed_rounded, pressureLabel, pressureColor),
      ],
    );
  }

  Widget _healthPill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Live signal feed ──────────────────────────────────────────────────────

  Widget _liveSignalFeed(List<String> signals) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RECENT ACTIVITY',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: OnyxColorTokens.textMuted,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 10),
        for (final signal in signals.take(5))
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: OnyxColorTokens.brand,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    signal,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: OnyxColorTokens.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Quick actions ─────────────────────────────────────────────────────────

  Widget _quickActions({required bool compact}) {
    final actions = <_ZaraAction>[
      _ZaraAction(
        icon: Icons.bolt_rounded,
        label: 'Command Center',
        onTap: widget.onOpenCommandCenter,
      ),
      if (widget.onOpenDispatches != null)
        _ZaraAction(
          icon: Icons.send_rounded,
          label: 'Dispatches',
          onTap: widget.onOpenDispatches!,
        ),
      if (widget.onOpenAlarms != null)
        _ZaraAction(
          icon: Icons.warning_amber_rounded,
          label: 'Alarms',
          onTap: widget.onOpenAlarms!,
        ),
      if (widget.onOpenCctv != null)
        _ZaraAction(
          icon: Icons.videocam_rounded,
          label: 'CCTV',
          onTap: widget.onOpenCctv!,
        ),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [for (final action in actions) _actionChip(action)],
    );
  }

  // ── Zara heartbeat ─────────────────────────────────────────────────────────

  Widget _zaraHeartbeatChip() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: 0.76 + 0.12 * _pulseAnimation.value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: OnyxColorTokens.backgroundSecondary.withValues(
                alpha: 0.94,
              ),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: OnyxColorTokens.brand.withValues(alpha: 0.18),
              ),
              boxShadow: [
                BoxShadow(
                  color: OnyxColorTokens.brand.withValues(
                    alpha: 0.18 * _pulseAnimation.value,
                  ),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: OnyxColorTokens.brand,
                    boxShadow: [
                      BoxShadow(
                        color: OnyxColorTokens.brand.withValues(
                          alpha: 0.4 * _pulseAnimation.value,
                        ),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Zara is watching',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: OnyxColorTokens.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _actionChip(_ZaraAction action) {
    return InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: OnyxColorTokens.backgroundSecondary,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: OnyxColorTokens.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(action.icon, size: 16, color: OnyxColorTokens.textMuted),
            const SizedBox(width: 8),
            Text(
              action.label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: OnyxColorTokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Autonomous operations log ─────────────────────────────────────────────

  List<String> _buildAutonomousLog(OperationsHealthSnapshot projection) {
    final log = <String>[];
    if (projection.totalPatrols > 0) {
      log.add(
        'Verified ${projection.totalPatrols} patrol'
        '${projection.totalPatrols == 1 ? '' : 's'} — all routes clear.',
      );
    }
    if (projection.totalCheckIns > 0) {
      log.add(
        'Processed ${projection.totalCheckIns} guard check-in'
        '${projection.totalCheckIns == 1 ? '' : 's'} autonomously.',
      );
    }
    if (projection.totalExecuted > 0) {
      log.add(
        'Confirmed ${projection.totalExecuted} dispatch'
        '${projection.totalExecuted == 1 ? '' : 'es'} — response chain intact.',
      );
    }
    if (projection.totalIntelligenceReceived > 0) {
      final lowRisk =
          projection.totalIntelligenceReceived -
          projection.highRiskIntelligence;
      if (lowRisk > 0) {
        log.add(
          'Processed $lowRisk low-risk intelligence signal'
          '${lowRisk == 1 ? '' : 's'} — no escalation required.',
        );
      }
    }
    if (projection.sites.isNotEmpty) {
      final strongSites = projection.sites
          .where(
            (s) => s.healthStatus == 'STRONG' || s.healthStatus == 'STABLE',
          )
          .length;
      if (strongSites > 0) {
        log.add(
          '$strongSites site${strongSites == 1 ? '' : 's'} maintaining '
          'healthy operational posture.',
        );
      }
    }
    return log;
  }

  Widget _autonomousOpsSection(List<String> ops) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 12,
              color: OnyxColorTokens.brand.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Text(
              'ZARA AUTONOMOUS OPERATIONS',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: OnyxColorTokens.textMuted,
                letterSpacing: 0.7,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: OnyxColorTokens.brand.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: OnyxColorTokens.brand.withValues(alpha: 0.12),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < ops.length; i++) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 5),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 12,
                        color: OnyxColorTokens.accentGreen,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ops[i],
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: OnyxColorTokens.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
                if (i < ops.length - 1) const SizedBox(height: 6),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Surfaced action card (cinematic slide-up) ─────────────────────────────

  Widget _surfacedActionCard({
    required int incidentCount,
    required int dispatchCount,
    required List<String> dispatchFeed,
    required Color statusAccent,
  }) {
    final isIncident = incidentCount > 0;
    final headline = isIncident
        ? 'Incident detected — human decision required'
        : 'New dispatch activity detected';
    final detail = dispatchFeed.isNotEmpty
        ? dispatchFeed.last
        : isIncident
        ? '$incidentCount active incident${incidentCount == 1 ? '' : 's'}'
        : '$dispatchCount dispatch${dispatchCount == 1 ? '' : 'es'} in progress';
    final actionLabel = isIncident ? 'OPEN DISPATCHES' : 'VIEW ACTIVITY';
    final actionCallback = isIncident
        ? widget.onOpenDispatches
        : widget.onOpenCommandCenter;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(color: statusAccent, width: 3),
          top: BorderSide(color: statusAccent.withValues(alpha: 0.3)),
          right: BorderSide(color: statusAccent.withValues(alpha: 0.3)),
          bottom: BorderSide(color: statusAccent.withValues(alpha: 0.3)),
        ),
        boxShadow: [
          BoxShadow(
            color: statusAccent.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusAccent,
                  boxShadow: [
                    BoxShadow(
                      color: statusAccent.withValues(alpha: 0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  headline,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: OnyxColorTokens.textPrimary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _dismissActionCard,
                child: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: OnyxColorTokens.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: OnyxColorTokens.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (actionCallback != null)
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _dismissActionCard();
                        actionCallback();
                      },
                      icon: Icon(
                        isIncident
                            ? Icons.warning_amber_rounded
                            : Icons.bolt_rounded,
                        size: 16,
                      ),
                      label: Text(actionLabel),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: statusAccent,
                        foregroundColor: OnyxColorTokens.textPrimary,
                        elevation: 0,
                        textStyle: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 10),
              SizedBox(
                height: 40,
                child: OutlinedButton(
                  onPressed: _dismissActionCard,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: OnyxColorTokens.textSecondary,
                    side: const BorderSide(color: OnyxColorTokens.divider),
                    textStyle: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Dismiss'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ZaraAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ZaraAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}
