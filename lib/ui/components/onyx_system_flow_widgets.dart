import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

    return Container(
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
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: foreground,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                OnyxSystemFlowService.stateLabel(state),
                style: GoogleFonts.inter(
                  color: foreground,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
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

class OnyxFlowIndicator extends StatelessWidget {
  final String chainLabel;
  final String? sourceLabel;
  final String? nextActionLabel;
  final Color accent;
  final EdgeInsetsGeometry padding;

  const OnyxFlowIndicator({
    super.key,
    required this.chainLabel,
    this.sourceLabel,
    this.nextActionLabel,
    this.accent = OnyxColorTokens.accentPurple,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INTELLIGENCE FLOW',
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textDisabled,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _OnyxFlowPill(
                prefix: 'FLOW',
                text: chainLabel,
                foreground: accent.withValues(alpha: 0.82),
                background: accent.withValues(alpha: 0.10),
                border: accent.withValues(alpha: 0.18),
              ),
              if (sourceLabel != null && sourceLabel!.trim().isNotEmpty)
                _OnyxFlowPill(
                  prefix: 'SOURCE',
                  text: sourceLabel!,
                  foreground: OnyxColorTokens.textSecondary,
                  background: OnyxColorTokens.backgroundPrimary,
                  border: OnyxColorTokens.divider,
                ),
              if (nextActionLabel != null && nextActionLabel!.trim().isNotEmpty)
                _OnyxFlowPill(
                  prefix: 'NEXT',
                  text: nextActionLabel!,
                  foreground: accent.withValues(alpha: 0.78),
                  background: accent.withValues(alpha: 0.10),
                  border: accent.withValues(alpha: 0.18),
                ),
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

  const _OnyxFlowPill({
    required this.prefix,
    required this.text,
    required this.foreground,
    required this.background,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            TextSpan(
              text: text,
              style: GoogleFonts.inter(
                color: foreground,
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
