import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'video_fleet_scope_health_sections.dart';

class VideoFleetScopeHealthPanel extends StatelessWidget {
  final String title;
  final TextStyle titleStyle;
  final TextStyle sectionLabelStyle;
  final VideoFleetScopeHealthSections sections;
  final Widget? summaryHeader;
  final List<Widget> summaryChildren;
  final List<Widget> actionableChildren;
  final List<Widget> watchOnlyChildren;
  final VideoFleetWatchActionDrilldown? activeWatchActionDrilldown;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BoxDecoration decoration;
  final double sectionSpacing;
  final double cardSpacing;
  final double runSpacing;

  const VideoFleetScopeHealthPanel({
    super.key,
    required this.title,
    required this.titleStyle,
    required this.sectionLabelStyle,
    required this.sections,
    this.summaryHeader,
    required this.summaryChildren,
    required this.actionableChildren,
    required this.watchOnlyChildren,
    this.activeWatchActionDrilldown,
    required this.padding,
    required this.decoration,
    this.margin,
    this.sectionSpacing = 10,
    this.cardSpacing = 8,
    this.runSpacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: padding,
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: titleStyle),
          const SizedBox(height: 8),
          if (summaryHeader != null) ...[
            summaryHeader!,
            const SizedBox(height: 10),
          ],
          Wrap(spacing: 8, runSpacing: 8, children: summaryChildren),
          SizedBox(height: sectionSpacing),
          _sectionHeader(
            key: const ValueKey('video-fleet-panel-actionable-header'),
            activeWatchActionDrilldown?.actionableSectionTitle ?? 'ACTIONABLE',
            sections.actionableScopes.length,
            sections.actionableLabelFor(activeWatchActionDrilldown),
            accent:
                activeWatchActionDrilldown?.accentColor ??
                const Color(0xFF8FD1FF),
            supportingChips: [
              _supportChip(
                'Incident-linked',
                '${sections.actionableScopes.length}',
                const Color(0xFF8FD1FF),
              ),
              _supportChip(
                'High risk',
                '${sections.highRiskCount}',
                const Color(0xFFFCA5A5),
              ),
              _supportChip(
                'Alert lanes',
                '${sections.alertActionCount}',
                const Color(0xFF67E8F9),
              ),
            ],
          ),
          if (actionableChildren.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: cardSpacing,
              runSpacing: runSpacing,
              children: actionableChildren,
            ),
          ],
          SizedBox(height: sectionSpacing),
          _sectionHeader(
            key: const ValueKey('video-fleet-panel-watch-only-header'),
            activeWatchActionDrilldown?.watchOnlySectionTitle ?? 'WATCH-ONLY',
            sections.watchOnlyScopes.length,
            sections.watchOnlyLabelFor(activeWatchActionDrilldown),
            accent: const Color(0xFFFDE68A),
            supportingChips: [
              _supportChip(
                'Pending context',
                '${sections.noIncidentCount}',
                const Color(0xFFFDE68A),
              ),
              _supportChip(
                'Coverage gaps',
                '${sections.gapCount}',
                const Color(0xFFFCA5A5),
              ),
              _supportChip(
                'Recovered 6h',
                '${sections.recoveredCount}',
                const Color(0xFF86EFAC),
              ),
            ],
          ),
          if (watchOnlyChildren.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: cardSpacing,
              runSpacing: runSpacing,
              children: watchOnlyChildren,
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(
    String title,
    int count,
    String detail, {
    required Color accent,
    required List<Widget> supportingChips,
    Key? key,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFDFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
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
                      title,
                      style: GoogleFonts.inter(
                        color: accent,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('$title ($count) • $detail', style: sectionLabelStyle),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: accent.withValues(alpha: 0.42)),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF172638),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: supportingChips),
        ],
      ),
    );
  }

  Widget _supportChip(String label, String value, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.38)),
      ),
      child: Text(
        '$label • $value',
        style: GoogleFonts.inter(
          color: const Color(0xFF556B80),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
