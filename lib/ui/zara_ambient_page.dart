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
  late final AnimationController _fadeController;
  late final AnimationController _pulseController;
  late final Animation<double> _fadeIn;
  late final Animation<double> _pulseAnimation;
  Timer? _clockTimer;
  String _timeLabel = '';

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

    _updateTime();
    _clockTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _updateTime(),
    );
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
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projection = OperationsHealthProjection.build(widget.events);
    final operatorName = widget.operatorLabel.trim().isEmpty
        ? 'Operator'
        : widget.operatorLabel.trim().split(' ').first;
    final siteCount = projection.totalSites;
    final activeDispatches = projection.totalDecisions -
        projection.totalExecuted -
        projection.totalDenied;
    final activeDispatchCount = activeDispatches.clamp(0, 999);
    final guardCount = projection.totalCheckIns;
    final incidentCount = projection.totalFailed;
    final highRiskIntel = projection.highRiskIntelligence;
    final pressure = projection.controllerPressureIndex;

    final allClear = activeDispatchCount == 0 &&
        incidentCount == 0 &&
        highRiskIntel == 0;

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

    return OnyxPageScaffold(
      child: FadeTransition(
        opacity: _fadeIn,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 700;
            return Column(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 24 : 48,
                        vertical: 32,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
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
                            const SizedBox(height: 40),
                            _systemHealthBar(
                              siteCount: siteCount,
                              guardCount: guardCount,
                              dispatchCount: activeDispatchCount,
                              pressure: pressure,
                            ),
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
        border: Border.all(
          color: statusAccent.withValues(alpha: 0.25),
        ),
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
        _healthPill(Icons.apartment_rounded, '$siteCount sites',
            OnyxColorTokens.accentCyanTrue),
        _healthPill(Icons.shield_rounded, '$guardCount guards',
            OnyxColorTokens.accentGreen),
        _healthPill(Icons.send_rounded, '$dispatchCount active',
            dispatchCount > 0
                ? OnyxColorTokens.accentAmber
                : OnyxColorTokens.textMuted),
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
      children: [
        for (final action in actions)
          _actionChip(action),
      ],
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
