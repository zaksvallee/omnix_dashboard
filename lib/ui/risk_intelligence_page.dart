import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'layout_breakpoints.dart';
import 'onyx_surface.dart';
import 'theme/onyx_design_tokens.dart';

const _intelSurfaceColor = OnyxColorTokens.backgroundSecondary;
const _intelSurfaceAltColor = OnyxColorTokens.surfaceElevated;
const _intelBorderColor = OnyxColorTokens.borderSubtle;
const _intelTitleColor = OnyxColorTokens.textPrimary;
const _intelBodyColor = OnyxColorTokens.textSecondary;
const _intelMutedColor = OnyxColorTokens.textMuted;

String _intelKeySegment(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');

class RiskIntelAreaSummary {
  final String title;
  final String level;
  final Color accent;
  final Color border;
  final int signalCount;
  final List<String> eventIds;
  final String? selectedEventId;

  const RiskIntelAreaSummary({
    required this.title,
    required this.level,
    required this.accent,
    required this.border,
    this.signalCount = 0,
    this.eventIds = const <String>[],
    this.selectedEventId,
  });
}

class RiskIntelFeedItem {
  final String id;
  final String? eventId;
  final String sourceType;
  final String provider;
  final DateTime? occurredAtUtc;
  final String timeLabel;
  final String sourceLabel;
  final IconData icon;
  final Color iconColor;
  final String summary;

  const RiskIntelFeedItem({
    required this.id,
    this.eventId,
    required this.sourceType,
    required this.provider,
    this.occurredAtUtc,
    required this.timeLabel,
    required this.sourceLabel,
    required this.icon,
    required this.iconColor,
    required this.summary,
  });
}

class RiskIntelAutoAuditReceipt {
  final String auditId;
  final String label;
  final String headline;
  final String detail;
  final Color accent;

  const RiskIntelAutoAuditReceipt({
    required this.auditId,
    required this.label,
    required this.headline,
    required this.detail,
    required this.accent,
  });
}

class RiskIntelligencePage extends StatelessWidget {
  final VoidCallback? onAddManualIntel;
  final ValueChanged<RiskIntelAreaSummary>? onViewAreaIntel;
  final ValueChanged<RiskIntelFeedItem>? onViewRecentIntel;
  final List<RiskIntelAreaSummary> areas;
  final List<RiskIntelFeedItem> recentItems;
  final RiskIntelAutoAuditReceipt? latestAutoAuditReceipt;
  final VoidCallback? onOpenLatestAudit;

  const RiskIntelligencePage({
    super.key,
    this.onAddManualIntel,
    this.onViewAreaIntel,
    this.onViewRecentIntel,
    this.areas = kDebugMode ? defaultAreas : const <RiskIntelAreaSummary>[],
    this.recentItems = kDebugMode
        ? defaultRecentItems
        : const <RiskIntelFeedItem>[],
    this.latestAutoAuditReceipt,
    this.onOpenLatestAudit,
  });

  static const List<RiskIntelAreaSummary> defaultAreas = [
    RiskIntelAreaSummary(
      title: 'Sandton',
      level: 'LOW',
      accent: OnyxColorTokens.accentGreen,
      border: OnyxColorTokens.greenBorder,
    ),
    RiskIntelAreaSummary(
      title: 'Hyde Park',
      level: 'LOW',
      accent: OnyxColorTokens.accentGreen,
      border: OnyxColorTokens.greenBorder,
    ),
    RiskIntelAreaSummary(
      title: 'Waterfall',
      level: 'MEDIUM',
      accent: OnyxColorTokens.accentAmber,
      border: OnyxColorTokens.amberBorder,
    ),
    RiskIntelAreaSummary(
      title: 'Rosebank',
      level: 'LOW',
      accent: OnyxColorTokens.accentGreen,
      border: OnyxColorTokens.greenBorder,
    ),
  ];

  static const List<RiskIntelFeedItem> defaultRecentItems = [
    RiskIntelFeedItem(
      id: 'intel-twitter-rosebank',
      sourceType: 'community',
      provider: 'twitter',
      timeLabel: '23:15',
      sourceLabel: 'TWITTER',
      icon: Icons.alternate_email_rounded,
      iconColor: OnyxColorTokens.accentAmber,
      summary: 'Protest planned near Rosebank Metro Station tomorrow at 10:00',
    ),
    RiskIntelFeedItem(
      id: 'intel-news24-loadshedding',
      sourceType: 'news',
      provider: 'news24',
      timeLabel: '22:45',
      sourceLabel: 'NEWS24',
      icon: Icons.public_rounded,
      iconColor: OnyxColorTokens.accentSky,
      summary: 'Load shedding Stage 3 announced - affects all monitored areas',
    ),
    RiskIntelFeedItem(
      id: 'intel-scanner-waterfall',
      sourceType: 'radio',
      provider: 'police-scanner',
      timeLabel: '21:30',
      sourceLabel: 'POLICE SCANNER',
      icon: Icons.sensors_rounded,
      iconColor: OnyxColorTokens.accentRed,
      summary:
          'Armed robbery reported in Midrand - 5km from Waterfall Business Park',
    ),
  ];

  void _showManualIntelComposer(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return _IntelDialogFrame(
          dialogKey: const ValueKey('intel-add-manual-dialog'),
          title: 'Intel Intake',
          eyebrow: 'INTAKE CHECKLIST',
          accent: OnyxColorTokens.accentSky,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _IntelDialogSection(
                label: 'Capture',
                value: 'Area, source, confidence, affected client lane',
              ),
              const SizedBox(height: 12),
              _IntelDialogSection(
                label: 'Escalate',
                value:
                    'Open Events Scope or Dispatch once a source is verified',
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 12),
                _IntelDialogSection(
                  label: 'Operator Note',
                  value:
                      'Use this intake brief while the manual-intel workflow is being finalized.',
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showAreaIntelDialog(BuildContext context, RiskIntelAreaSummary area) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return _IntelDialogFrame(
          dialogKey: ValueKey(
            'intel-area-${_intelKeySegment(area.title)}-dialog',
          ),
          title: area.title,
          eyebrow: 'AREA POSTURE',
          accent: area.accent,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _IntelDialogSection(label: 'Risk Level', value: area.level),
              const SizedBox(height: 12),
              _IntelDialogSection(
                label: 'Operating Guidance',
                value: area.level == 'LOW'
                    ? 'Maintain passive monitoring and watch for transport or protest signals.'
                    : 'Elevate monitoring density, verify route risk, and keep dispatch ready.',
              ),
              const SizedBox(height: 12),
              _IntelDialogSection(
                label: 'Suggested Next Step',
                value:
                    'Review recent intelligence items and pivot to Events Review if the signal hardens.',
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRecentIntelDialog(BuildContext context, RiskIntelFeedItem item) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return _IntelDialogFrame(
          dialogKey: ValueKey(
            'intel-detail-${_intelKeySegment(item.provider)}-dialog',
          ),
          title: item.sourceLabel,
          eyebrow: item.timeLabel,
          accent: item.iconColor,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _IntelDialogSection(label: 'Summary', value: item.summary),
              const SizedBox(height: 12),
              _IntelDialogSection(
                label: 'Triage Guidance',
                value:
                    'Confirm source confidence, assess client proximity, and escalate to dispatch if posture changes.',
              ),
            ],
          ),
        );
      },
    );
  }

  void _addManualIntel(BuildContext context) {
    if (onAddManualIntel != null) {
      onAddManualIntel!.call();
      return;
    }
    _showManualIntelComposer(context);
  }

  void _viewAreaIntel(BuildContext context, RiskIntelAreaSummary area) {
    if (onViewAreaIntel != null && area.eventIds.isNotEmpty) {
      onViewAreaIntel!(area);
      return;
    }
    _showAreaIntelDialog(context, area);
  }

  void _viewIntelDetail(BuildContext context, RiskIntelFeedItem item) {
    if (onViewRecentIntel != null) {
      onViewRecentIntel!(item);
      return;
    }
    _showRecentIntelDialog(context, item);
  }

  Color _sourceColor(String source) {
    return switch (source.toLowerCase()) {
      'twitter' => OnyxColorTokens.accentSky,
      'news24' || 'news' => OnyxColorTokens.accentGreen,
      'police scanner' || 'police-scanner' || 'police' =>
          OnyxColorTokens.accentRed,
      'manual' => OnyxColorTokens.brand,
      _ => OnyxColorTokens.textSecondary,
    };
  }

  Widget _areaRiskCard(
      BuildContext context, RiskIntelAreaSummary area) {
    final level = area.level.trim().toUpperCase();
    final isHigh = level == 'CRITICAL' || level == 'HIGH';
    final isMed = level == 'MEDIUM' || level == 'MED';
    final dotColor = isHigh
        ? OnyxColorTokens.accentRed
        : isMed
            ? OnyxColorTokens.accentAmber
            : OnyxColorTokens.accentGreen;
    final borderColor = isHigh
        ? OnyxColorTokens.redBorder
        : isMed
            ? OnyxColorTokens.amberBorder
            : OnyxColorTokens.divider;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isHigh
                ? OnyxColorTokens.accentRed
                : isMed
                    ? OnyxColorTokens.accentAmber
                    : Colors.transparent,
            width: 2,
          ),
          bottom: BorderSide(color: OnyxColorTokens.divider),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  area.title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: OnyxColorTokens.textPrimary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: dotColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border:
                      Border.all(color: dotColor.withValues(alpha: 0.25)),
                ),
                child: Text(
                  level,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: dotColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'RISK LEVEL',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: OnyxColorTokens.textMuted,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _viewAreaIntel(context, area),
            style: OutlinedButton.styleFrom(
              foregroundColor: OnyxColorTokens.textSecondary,
              side: BorderSide(color: borderColor),
              minimumSize: const Size(double.infinity, 32),
              textStyle: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            child: const Text('View intel'),
          ),
        ],
      ),
    );
  }

  Widget _intelFeedCard(BuildContext context, RiskIntelFeedItem item) {
    final source = item.sourceLabel.isNotEmpty ? item.sourceLabel : item.provider;
    final sourceColor = _sourceColor(source);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: OnyxColorTokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                item.timeLabel,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: OnyxColorTokens.textMuted,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: sourceColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: sourceColor.withValues(alpha: 0.25)),
                ),
                child: Text(
                  source.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: sourceColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.summary,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: OnyxColorTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => _viewIntelDetail(context, item),
            style: OutlinedButton.styleFrom(
              foregroundColor: OnyxColorTokens.textSecondary,
              side: BorderSide(color: OnyxColorTokens.divider),
              minimumSize: const Size(0, 30),
              textStyle: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            child: const Text('View details'),
          ),
        ],
      ),
    );
  }

  Widget _buildAreaPanel(BuildContext context, {double? width}) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        border: Border.all(color: OnyxColorTokens.divider),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 14,
                  color: OnyxColorTokens.brand,
                ),
                const SizedBox(width: 6),
                Text(
                  'AREA RISK LEVELS',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: OnyxColorTokens.textMuted,
                    letterSpacing: 0.7,
                  ),
                ),
              ],
            ),
          ),
          Divider(color: OnyxColorTokens.divider, height: 1),
          for (final area in areas) _areaRiskCard(context, area),
          Divider(color: OnyxColorTokens.divider, height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Add manual intel'),
              style: OutlinedButton.styleFrom(
                foregroundColor: OnyxColorTokens.brand,
                side: BorderSide(color: OnyxColorTokens.borderSubtle),
                minimumSize: const Size(double.infinity, 36),
                textStyle: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onPressed: () => _addManualIntel(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedPanel(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.trending_up_rounded,
              size: 14,
              color: OnyxColorTokens.brand,
            ),
            const SizedBox(width: 6),
            Text(
              'RECENT INTELLIGENCE',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: OnyxColorTokens.textMuted,
                letterSpacing: 0.7,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final item in recentItems) _intelFeedCard(context, item),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnyxPageScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final ultrawideSurface = isUltrawideLayout(
            context,
            viewportWidth: constraints.maxWidth,
          );
          final surfaceMaxWidth = commandSurfaceMaxWidth(
            context,
            compactDesktopWidth: 1500,
            viewportWidth: constraints.maxWidth,
            widescreenFillFactor: ultrawideSurface ? 1 : 0.95,
          );
          final narrow = constraints.maxWidth < 900;

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: surfaceMaxWidth),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Risk intelligence',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: OnyxColorTokens.textPrimary,
                              ),
                            ),
                            Text(
                              'Area threat assessment and news monitoring',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: OnyxColorTokens.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (narrow) ...[
                      _buildAreaPanel(context),
                      const SizedBox(height: 18),
                      _buildFeedPanel(context),
                    ] else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAreaPanel(context, width: 320),
                          const SizedBox(width: 18),
                          Expanded(child: _buildFeedPanel(context)),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

}
class _IntelDialogFrame extends StatelessWidget {
  final Key? dialogKey;
  final String title;
  final String eyebrow;
  final Color accent;
  final Widget child;
  final List<Widget> actions;

  const _IntelDialogFrame({
    this.dialogKey,
    required this.title,
    required this.eyebrow,
    required this.accent,
    required this.child,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: dialogKey,
      backgroundColor: _intelSurfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: _intelBorderColor),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: GoogleFonts.inter(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: GoogleFonts.inter(
                  color: _intelTitleColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 0.96,
                ),
              ),
              const SizedBox(height: 16),
              child,
              const SizedBox(height: 18),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntelDialogSection extends StatelessWidget {
  final String label;
  final String value;

  const _IntelDialogSection({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: _intelSurfaceAltColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _intelBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: _intelMutedColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              color: _intelBodyColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
