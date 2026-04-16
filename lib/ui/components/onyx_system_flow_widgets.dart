import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../application/event_sourcing_service.dart';
import '../../application/system_flow_service.dart';
import '../theme/onyx_design_tokens.dart';

class OnyxGlobalSystemStateChip extends StatelessWidget {
  final OnyxGlobalSystemState state;
  final String detail;
  final bool compact;

  const OnyxGlobalSystemStateChip({
    super.key,
    required this.state,
    required this.detail,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final (foreground, background, border) = switch (state) {
      OnyxGlobalSystemState.nominal => (
        OnyxColorTokens.accentGreen,
        OnyxColorTokens.accentGreen.withValues(alpha: 0.10),
        OnyxColorTokens.accentGreen.withValues(alpha: 0.22),
      ),
      OnyxGlobalSystemState.elevatedWatch => (
        OnyxColorTokens.accentAmber,
        OnyxColorTokens.accentAmber.withValues(alpha: 0.10),
        OnyxColorTokens.accentAmber.withValues(alpha: 0.22),
      ),
      OnyxGlobalSystemState.activeIncident => (
        OnyxColorTokens.accentPurple,
        OnyxColorTokens.accentPurple.withValues(alpha: 0.10),
        OnyxColorTokens.accentPurple.withValues(alpha: 0.22),
      ),
      OnyxGlobalSystemState.critical => (
        OnyxColorTokens.accentRed,
        OnyxColorTokens.accentRed.withValues(alpha: 0.10),
        OnyxColorTokens.accentRed.withValues(alpha: 0.24),
      ),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _OnyxPulseDot(
            color: foreground,
            animate: state != OnyxGlobalSystemState.nominal,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(
                  OnyxSystemStateService.stateLabel(state),
                  key: ValueKey<String>(
                    OnyxSystemStateService.stateLabel(state),
                  ),
                  style: GoogleFonts.inter(
                    color: foreground,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.textMuted,
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class OnyxFlowBreadcrumb extends StatelessWidget {
  final OnyxFlowBreadcrumbData flow;
  final Color accent;
  final EdgeInsetsGeometry padding;
  final bool compact;
  final bool showTitle;

  const OnyxFlowBreadcrumb({
    super.key,
    required this.flow,
    this.accent = OnyxColorTokens.accentPurple,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    this.compact = false,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final title = Text(
      compact ? 'FLOW' : 'INTELLIGENCE FLOW',
      style: GoogleFonts.inter(
        color: OnyxColorTokens.textDisabled,
        fontSize: compact ? 7.5 : 8,
        fontWeight: FontWeight.w700,
        letterSpacing: compact ? 0.7 : 0.9,
      ),
    );

    final pills = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _OnyxFlowPill(
          prefix: 'FLOW',
          text: flow.chainLabel,
          foreground: accent.withValues(alpha: 0.82),
          background: accent.withValues(alpha: 0.10),
          border: accent.withValues(alpha: 0.18),
          compact: compact,
        ),
        if (flow.sourceLabel != null && flow.sourceLabel!.trim().isNotEmpty)
          _OnyxFlowPill(
            prefix: 'SOURCE',
            text: flow.sourceLabel!,
            foreground: OnyxColorTokens.textSecondary,
            background: OnyxColorTokens.backgroundPrimary,
            border: OnyxColorTokens.divider,
            compact: compact,
          ),
        if (flow.nextActionLabel != null &&
            flow.nextActionLabel!.trim().isNotEmpty)
          _OnyxFlowPill(
            prefix: 'NEXT',
            text: flow.nextActionLabel!,
            foreground: accent.withValues(alpha: 0.78),
            background: accent.withValues(alpha: 0.10),
            border: accent.withValues(alpha: 0.18),
            compact: compact,
          ),
        if (flow.referenceLabel != null &&
            flow.referenceLabel!.trim().isNotEmpty)
          _OnyxFlowPill(
            prefix: 'REF',
            text: flow.referenceLabel!,
            foreground: accent.withValues(alpha: 0.78),
            background: accent.withValues(alpha: 0.08),
            border: accent.withValues(alpha: 0.16),
            compact: compact,
          ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(compact ? 8 : 6),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showTitle) ...[title, const SizedBox(height: 6)],
          pills,
        ],
      ),
    );
  }
}

class OnyxFlowIndicator extends StatelessWidget {
  final String? chainLabel;
  final String? sourceLabel;
  final String? nextActionLabel;
  final String? referenceLabel;
  final Color accent;
  final EdgeInsetsGeometry padding;
  final OnyxFlowBreadcrumbData? flow;

  const OnyxFlowIndicator({
    super.key,
    this.chainLabel,
    this.sourceLabel,
    this.nextActionLabel,
    this.referenceLabel,
    this.accent = OnyxColorTokens.accentPurple,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    this.flow,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedFlow =
        flow ??
        OnyxFlowBreadcrumbData(
          chainLabel: chainLabel ?? '',
          sourceLabel: sourceLabel,
          nextActionLabel: nextActionLabel,
          referenceLabel: referenceLabel,
        );
    return OnyxFlowBreadcrumb(
      flow: resolvedFlow,
      accent: accent,
      padding: padding,
    );
  }
}

class OnyxEventStoreStatusChip extends StatelessWidget {
  final OnyxEventSourcingSnapshot snapshot;
  final bool compact;

  const OnyxEventStoreStatusChip({
    super.key,
    required this.snapshot,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: OnyxColorTokens.accentPurple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: OnyxColorTokens.accentPurple.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _OnyxPulseDot(
            color: OnyxColorTokens.accentPurple,
            animate: snapshot.eventCount > 0,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'EVENTSTORE LIVE',
                style: GoogleFonts.inter(
                  color: OnyxColorTokens.accentPurple,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 2),
                Text(
                  '${snapshot.eventCount} events • ${snapshot.latestSemanticLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.textMuted,
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _OnyxFlowPill extends StatelessWidget {
  final String prefix;
  final String text;
  final Color foreground;
  final Color background;
  final Color border;
  final bool compact;

  const _OnyxFlowPill({
    required this.prefix,
    required this.text,
    required this.foreground,
    required this.background,
    required this.border,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 8,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$prefix · ',
              style: GoogleFonts.inter(
                color: OnyxColorTokens.textDisabled,
                fontSize: compact ? 7.5 : 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            TextSpan(
              text: text,
              style: GoogleFonts.inter(
                color: foreground,
                fontSize: compact ? 8 : 8.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnyxPulseDot extends StatefulWidget {
  final Color color;
  final bool animate;

  const _OnyxPulseDot({required this.color, required this.animate});

  @override
  State<_OnyxPulseDot> createState() => _OnyxPulseDotState();
}

class _OnyxPulseDotState extends State<_OnyxPulseDot> {
  Timer? _timer;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant _OnyxPulseDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) {
      _syncTicker();
    }
  }

  void _syncTicker() {
    _timer?.cancel();
    _visible = true;
    if (!widget.animate) {
      if (mounted) {
        setState(() {});
      }
      return;
    }
    _timer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _visible = !_visible;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 260),
      opacity: widget.animate ? (_visible ? 1 : 0.4) : 1,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
