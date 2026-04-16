import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../application/system_flow_service.dart';
import 'components/onyx_system_flow_widgets.dart';
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

String _intelTitleCaseWords(String value) {
  final cleaned = value
      .trim()
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
  if (cleaned.isEmpty) {
    return 'Unknown';
  }
  return cleaned
      .split(' ')
      .map((segment) {
        if (segment.isEmpty) {
          return segment;
        }
        final lower = segment.toLowerCase();
        return '${lower[0].toUpperCase()}${lower.substring(1)}';
      })
      .join(' ');
}

class RiskIntelAreaSummary {
  final String title;
  final String level;
  final Color accent;
  final Color border;
  final int signalCount;
  final List<String> eventIds;
  final String? selectedEventId;
  final String clientId;
  final String siteId;
  final String? zoneLabel;

  const RiskIntelAreaSummary({
    required this.title,
    required this.level,
    required this.accent,
    required this.border,
    this.signalCount = 0,
    this.eventIds = const <String>[],
    this.selectedEventId,
    this.clientId = '',
    this.siteId = '',
    this.zoneLabel,
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
  final int confidenceScore;
  final String clientId;
  final String siteId;
  final String? zoneLabel;

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
    this.confidenceScore = 0,
    this.clientId = '',
    this.siteId = '',
    this.zoneLabel,
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
  final ValueChanged<RiskIntelAreaSummary>? onSendAreaToTrack;
  final ValueChanged<RiskIntelFeedItem>? onSendSignalToTrack;
  final List<RiskIntelAreaSummary> areas;
  final List<RiskIntelFeedItem> recentItems;
  final RiskIntelAutoAuditReceipt? latestAutoAuditReceipt;
  final VoidCallback? onOpenLatestAudit;

  const RiskIntelligencePage({
    super.key,
    this.onAddManualIntel,
    this.onViewAreaIntel,
    this.onViewRecentIntel,
    this.onSendAreaToTrack,
    this.onSendSignalToTrack,
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
      clientId: 'CLIENT-SANDTON',
      siteId: 'SITE-SANDTON-CBD',
      zoneLabel: 'Sandton Core',
    ),
    RiskIntelAreaSummary(
      title: 'Hyde Park',
      level: 'LOW',
      accent: OnyxColorTokens.accentGreen,
      border: OnyxColorTokens.greenBorder,
      clientId: 'CLIENT-HYDE-PARK',
      siteId: 'SITE-HYDE-PARK',
      zoneLabel: 'Hyde Park North',
    ),
    RiskIntelAreaSummary(
      title: 'Waterfall',
      level: 'MEDIUM',
      accent: OnyxColorTokens.accentAmber,
      border: OnyxColorTokens.amberBorder,
      signalCount: 2,
      clientId: 'CLIENT-WATERFALL',
      siteId: 'SITE-WATERFALL',
      zoneLabel: 'Business Park',
    ),
    RiskIntelAreaSummary(
      title: 'Rosebank',
      level: 'LOW',
      accent: OnyxColorTokens.accentGreen,
      border: OnyxColorTokens.greenBorder,
      clientId: 'CLIENT-ROSEBANK',
      siteId: 'SITE-ROSEBANK',
      zoneLabel: 'Rosebank Core',
    ),
  ];

  static const List<RiskIntelFeedItem> defaultRecentItems = [
    RiskIntelFeedItem(
      id: 'intel-twitter-rosebank',
      sourceType: 'community-feed',
      provider: 'twitter',
      timeLabel: '23:15',
      sourceLabel: 'COMMUNITY-FEED',
      icon: Icons.alternate_email_rounded,
      iconColor: OnyxColorTokens.accentAmber,
      summary: 'Protest planned near Rosebank Metro Station tomorrow at 10:00',
      confidenceScore: 72,
      clientId: 'CLIENT-ROSEBANK',
      siteId: 'SITE-ROSEBANK',
      zoneLabel: 'Rosebank Metro',
    ),
    RiskIntelFeedItem(
      id: 'intel-news24-loadshedding',
      sourceType: 'news-watch',
      provider: 'news24',
      timeLabel: '22:45',
      sourceLabel: 'NEWS-WATCH',
      icon: Icons.public_rounded,
      iconColor: OnyxColorTokens.accentSky,
      summary: 'Load shedding Stage 3 announced - affects all monitored areas',
      confidenceScore: 54,
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      zoneLabel: 'Grid Supply',
    ),
    RiskIntelFeedItem(
      id: 'intel-scanner-waterfall',
      sourceType: 'patrol-report',
      provider: 'police-scanner',
      timeLabel: '21:30',
      sourceLabel: 'PATROL-REPORT',
      icon: Icons.sensors_rounded,
      iconColor: OnyxColorTokens.accentRed,
      summary:
          'Armed robbery reported in Midrand - 5km from Waterfall Business Park',
      confidenceScore: 86,
      clientId: 'CLIENT-WATERFALL',
      siteId: 'SITE-WATERFALL',
      zoneLabel: 'Midrand Corridor',
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

  Color _sourceColor(String source) {
    return switch (source.toLowerCase()) {
      'twitter' => OnyxColorTokens.accentSky,
      'news24' || 'news' => OnyxColorTokens.accentGreen,
      'police scanner' ||
      'police-scanner' ||
      'police' => OnyxColorTokens.accentRed,
      'manual' => OnyxColorTokens.accentPurple,
      _ => OnyxColorTokens.textSecondary,
    };
  }

  int _areaSeverity(RiskIntelAreaSummary area) {
    return switch (area.level.trim().toUpperCase()) {
      'HIGH' || 'CRITICAL' => 3,
      'MEDIUM' || 'MED' => 2,
      _ => 1,
    };
  }

  bool get _allAreasStable =>
      areas.isEmpty || areas.every((area) => _areaSeverity(area) == 1);

  RiskIntelAreaSummary? _topRiskArea() {
    if (areas.isEmpty) {
      return null;
    }
    final ranked = [...areas]
      ..sort((left, right) {
        final severityCompare = _areaSeverity(
          right,
        ).compareTo(_areaSeverity(left));
        if (severityCompare != 0) {
          return severityCompare;
        }
        return right.signalCount.compareTo(left.signalCount);
      });
    return ranked.first;
  }

  RiskIntelFeedItem? _primarySignal() {
    if (recentItems.isEmpty) {
      return null;
    }
    final ranked = [...recentItems]
      ..sort((left, right) {
        final confidenceCompare = right.confidenceScore.compareTo(
          left.confidenceScore,
        );
        if (confidenceCompare != 0) {
          return confidenceCompare;
        }
        final leftTime = left.occurredAtUtc;
        final rightTime = right.occurredAtUtc;
        if (leftTime == null || rightTime == null) {
          return 0;
        }
        return rightTime.compareTo(leftTime);
      });
    return ranked.first;
  }

  String _displaySiteLabel(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Scope pending';
    }
    return _intelTitleCaseWords(trimmed);
  }

  String _zoneOrSiteLabel({required String siteId, String? zoneLabel}) {
    final trimmedZone = zoneLabel?.trim() ?? '';
    if (trimmedZone.isNotEmpty) {
      return _intelTitleCaseWords(trimmedZone);
    }
    return _displaySiteLabel(siteId);
  }

  String _areaStateLabel(RiskIntelAreaSummary area) {
    return switch (_areaSeverity(area)) {
      3 => 'HIGH ALERT',
      2 => 'ELEVATED WATCH',
      _ => 'STABLE',
    };
  }

  Color _areaStateAccent(RiskIntelAreaSummary area) {
    return switch (_areaSeverity(area)) {
      3 => OnyxColorTokens.accentRed,
      2 => OnyxColorTokens.accentAmber,
      _ => OnyxColorTokens.accentGreen,
    };
  }

  String _signalTypeBadge(RiskIntelFeedItem item) {
    final base = item.sourceType.trim().isNotEmpty
        ? item.sourceType
        : item.sourceLabel;
    return base.trim().replaceAll(RegExp(r'[_\s]+'), '-').toUpperCase();
  }

  String _signalAssessment(RiskIntelFeedItem item) {
    final threatType = _intelTitleCaseWords(
      item.sourceType.trim().isEmpty ? item.sourceLabel : item.sourceType,
    );
    if (item.confidenceScore > 70) {
      return 'Pattern may indicate $threatType activity. Recommend flagging for Track.';
    }
    if (item.confidenceScore >= 40) {
      return 'Unconfirmed. Continue monitoring.';
    }
    return 'Low confidence. Watch for repeat.';
  }

  String _signalTrendLabel(RiskIntelFeedItem item) {
    if (item.confidenceScore >= 70) {
      return '↑ Increasing';
    }
    if (item.confidenceScore >= 40) {
      return '→ Stable';
    }
    return '↓ Decreasing';
  }

  Color _signalTrendColor(RiskIntelFeedItem item) {
    if (item.confidenceScore >= 70) {
      return OnyxColorTokens.accentAmber;
    }
    if (item.confidenceScore >= 40) {
      return OnyxColorTokens.textMuted;
    }
    return OnyxColorTokens.accentGreen;
  }

  List<({String description, int count})> _activePatterns() {
    final patterns = <({String description, int count})>[];
    for (final area in areas.where((area) => area.signalCount >= 2)) {
      patterns.add((
        description: '${area.title} recurring activity cluster',
        count: area.signalCount,
      ));
    }

    final bySignalType = <String, int>{};
    for (final item in recentItems) {
      final key = _signalTypeBadge(item);
      bySignalType.update(key, (count) => count + 1, ifAbsent: () => 1);
    }
    for (final entry in bySignalType.entries) {
      if (entry.value >= 2) {
        patterns.add((
          description: '${entry.key} pattern emerging',
          count: entry.value,
        ));
      }
    }

    return patterns;
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: OnyxColorTokens.textDisabled,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.3,
        ),
      ),
    );
  }

  Widget _forecastLine({required Color dotColor, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 5),
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _forecastBlock() {
    final topArea = _topRiskArea();
    final signal = _primarySignal();
    final elevatedArea = topArea != null && _areaSeverity(topArea) >= 2;
    final signalLine = signal != null && signal.confidenceScore > 60
        ? '${_intelTitleCaseWords(signal.sourceType.isEmpty ? signal.sourceLabel : signal.sourceType)} emerging. Recommend increased monitoring.'
        : 'No hardening signal detected. Continue monitoring.';
    final continuity = OnyxZaraContinuityService.predictiveForecast(
      areaLabel: topArea?.title ?? 'All areas',
      elevatedArea: elevatedArea,
      signalLine: signalLine,
    );
    final flow = OnyxFlowIndicatorService.intelToTrack(
      sourceLabel: elevatedArea
          ? 'Predictive watch → ${topArea.title}'
          : 'Predictive watch → All areas stable',
      nextActionLabel: _forecastNextActionLabel(topArea, signal),
      referenceLabel: topArea == null ? null : _intelKeySegment(topArea.title),
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: OnyxColorTokens.accentPurple.withValues(alpha: 0.22),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 760;
          final postureChip = Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: _allAreasStable
                  ? OnyxColorTokens.accentGreen.withValues(alpha: 0.08)
                  : OnyxColorTokens.accentAmber.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: _allAreasStable
                    ? OnyxColorTokens.accentGreen.withValues(alpha: 0.18)
                    : OnyxColorTokens.accentAmber.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              _allAreasStable ? 'ALL AREAS STABLE' : 'ELEVATED WATCH',
              style: GoogleFonts.inter(
                color: _allAreasStable
                    ? OnyxColorTokens.accentGreen
                    : OnyxColorTokens.accentAmber,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          );

          final leftContent = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: OnyxColorTokens.accentPurple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: OnyxColorTokens.accentPurple.withValues(alpha: 0.35),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Z',
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.accentPurple,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      continuity.headline,
                      style: GoogleFonts.inter(
                        color: OnyxColorTokens.accentPurple.withValues(
                          alpha: 0.60,
                        ),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _forecastLine(
                      dotColor: elevatedArea
                          ? OnyxColorTokens.accentRed
                          : OnyxColorTokens.accentGreen,
                      text: continuity.lines[0],
                    ),
                    const SizedBox(height: 5),
                    _forecastLine(
                      dotColor: OnyxColorTokens.accentAmber,
                      text: continuity.lines[1],
                    ),
                    const SizedBox(height: 5),
                    _forecastLine(
                      dotColor: OnyxColorTokens.accentPurple,
                      text: continuity.lines[2],
                    ),
                  ],
                ),
              ),
            ],
          );

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leftContent,
                const SizedBox(height: 12),
                postureChip,
                const SizedBox(height: 10),
                OnyxFlowIndicator(flow: flow),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: leftContent),
                  const SizedBox(width: 12),
                  postureChip,
                ],
              ),
              const SizedBox(height: 10),
              OnyxFlowIndicator(flow: flow),
            ],
          );
        },
      ),
    );
  }

  Widget _areaStateCard(BuildContext context, RiskIntelAreaSummary area) {
    final accent = _areaStateAccent(area);
    final severity = _areaSeverity(area);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: OnyxColorTokens.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  area.title,
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.textPrimary.withValues(alpha: 0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Risk area · ${_zoneOrSiteLabel(siteId: area.siteId, zoneLabel: area.zoneLabel)}',
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.textDisabled,
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(
                    alpha: severity == 1
                        ? 0.10
                        : severity == 2
                        ? 0.10
                        : 0.12,
                  ),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: accent.withValues(
                      alpha: severity == 1
                          ? 0.22
                          : severity == 2
                          ? 0.25
                          : 0.30,
                    ),
                  ),
                ),
                child: Text(
                  _areaStateLabel(area),
                  style: GoogleFonts.inter(
                    color: accent,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => _viewAreaIntel(context, area),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OnyxColorTokens.textMuted,
                      side: const BorderSide(color: OnyxColorTokens.divider),
                      minimumSize: const Size(0, 28),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      textStyle: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('View intel'),
                  ),
                  OutlinedButton(
                    onPressed: onSendAreaToTrack == null
                        ? null
                        : () => onSendAreaToTrack!(area),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OnyxColorTokens.accentPurple.withValues(
                        alpha: 0.70,
                      ),
                      backgroundColor: OnyxColorTokens.accentPurple.withValues(
                        alpha: 0.10,
                      ),
                      side: BorderSide(
                        color: OnyxColorTokens.accentPurple.withValues(
                          alpha: 0.22,
                        ),
                      ),
                      minimumSize: const Size(0, 28),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      textStyle: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Send to Track →'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _forecastNextActionLabel(
    RiskIntelAreaSummary? topArea,
    RiskIntelFeedItem? signal,
  ) {
    if (signal != null && signal.confidenceScore > 60) {
      final label = signal.sourceType.isEmpty
          ? signal.sourceLabel
          : signal.sourceType;
      return 'Next → Send ${_intelTitleCaseWords(label)} to Track before shift change';
    }
    if (topArea != null) {
      return 'Next → Review ${topArea.title} before the next shift handoff';
    }
    return 'Next → Keep predictive monitoring active';
  }

  Widget _signalCard(BuildContext context, RiskIntelFeedItem item) {
    final source = item.sourceLabel.isNotEmpty
        ? item.sourceLabel
        : item.provider;
    final sourceColor = _sourceColor(source);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: OnyxColorTokens.divider),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 2,
                color: OnyxColorTokens.accentAmber.withValues(alpha: 0.50),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: OnyxColorTokens.backgroundPrimary,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: OnyxColorTokens.divider),
                        ),
                        child: Text(
                          _signalTypeBadge(item),
                          style: GoogleFonts.inter(
                            color: OnyxColorTokens.textMuted,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        item.timeLabel,
                        style: GoogleFonts.inter(
                          color: OnyxColorTokens.textDisabled,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          color: OnyxColorTokens.accentPurple.withValues(
                            alpha: 0.18,
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Z',
                          style: GoogleFonts.inter(
                            color: OnyxColorTokens.accentPurple,
                            fontSize: 7,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'ZARA: ${_signalAssessment(item)}',
                          style: GoogleFonts.inter(
                            color: OnyxColorTokens.accentPurple.withValues(
                              alpha: 0.60,
                            ),
                            fontSize: 9,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        _signalTrendLabel(item),
                        style: GoogleFonts.inter(
                          color: _signalTrendColor(item),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          OutlinedButton(
                            onPressed: onSendSignalToTrack == null
                                ? null
                                : () => onSendSignalToTrack!(item),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: OnyxColorTokens.accentPurple
                                  .withValues(alpha: 0.70),
                              backgroundColor: OnyxColorTokens.accentPurple
                                  .withValues(alpha: 0.10),
                              side: BorderSide(
                                color: OnyxColorTokens.accentPurple.withValues(
                                  alpha: 0.22,
                                ),
                              ),
                              minimumSize: const Size(0, 28),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              textStyle: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: const Text('Send to Track →'),
                          ),
                          OutlinedButton(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              foregroundColor: OnyxColorTokens.textDisabled,
                              side: const BorderSide(
                                color: OnyxColorTokens.divider,
                              ),
                              minimumSize: const Size(0, 28),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              textStyle: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: const Text('Dismiss'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _zoneOrSiteLabel(
                      siteId: item.siteId,
                      zoneLabel: item.zoneLabel,
                    ),
                    style: GoogleFonts.inter(
                      color: sourceColor.withValues(alpha: 0.55),
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
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

  @override
  Widget build(BuildContext context) {
    final patterns = _activePatterns();
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

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: surfaceMaxWidth),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _forecastBlock(),
                    _sectionLabel('AREA STATES'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          if (areas.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: OnyxColorTokens.backgroundSecondary,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: OnyxColorTokens.divider,
                                ),
                              ),
                              child: Text(
                                'No active area states.',
                                style: GoogleFonts.inter(
                                  color: OnyxColorTokens.textDisabled,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                          else
                            for (final area in areas)
                              _areaStateCard(context, area),
                        ],
                      ),
                    ),
                    _sectionLabel('ACTIVE SIGNALS'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          if (recentItems.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: OnyxColorTokens.backgroundSecondary,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: OnyxColorTokens.divider,
                                ),
                              ),
                              child: Text(
                                'No active signals.',
                                style: GoogleFonts.inter(
                                  color: OnyxColorTokens.textDisabled,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                          else
                            for (final item in recentItems)
                              _signalCard(context, item),
                        ],
                      ),
                    ),
                    if (patterns.isNotEmpty) ...[
                      _sectionLabel('ACTIVE PATTERNS'),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            for (final pattern in patterns)
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: OnyxColorTokens.backgroundSecondary,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: OnyxColorTokens.divider,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      margin: const EdgeInsets.only(top: 5),
                                      decoration: const BoxDecoration(
                                        color: OnyxColorTokens.accentAmber,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            pattern.description,
                                            style: GoogleFonts.inter(
                                              color: OnyxColorTokens.textMuted,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Ongoing — ${pattern.count} signals',
                                            style: GoogleFonts.inter(
                                              color:
                                                  OnyxColorTokens.textDisabled,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton(
                          onPressed: () => _addManualIntel(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: OnyxColorTokens.textMuted,
                            backgroundColor:
                                OnyxColorTokens.backgroundSecondary,
                            side: const BorderSide(
                              color: OnyxColorTokens.divider,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            minimumSize: const Size(0, 36),
                            textStyle: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: const Text('Add manual intel'),
                        ),
                      ),
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
