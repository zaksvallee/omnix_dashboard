import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'components/onyx_status_banner.dart';
import 'layout_breakpoints.dart';
import 'onyx_surface.dart';

const _intelSurfaceColor = Color(0xFF13131E);
const _intelSurfaceAltColor = Color(0xFF1A1A2E);
const _intelSurfaceTintColor = Color(0x1A9D4BFF);
const _intelBorderColor = Color(0x269D4BFF);
const _intelStrongBorderColor = Color(0x4D9D4BFF);
const _intelTitleColor = Color(0xFFE8E8F0);
const _intelBodyColor = Color(0x80FFFFFF);
const _intelMutedColor = Color(0x4DFFFFFF);

String _intelKeySegment(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');

int _riskIntelLevelRank(String level) {
  switch (level.trim().toUpperCase()) {
    case 'CRITICAL':
      return 4;
    case 'HIGH':
      return 3;
    case 'MEDIUM':
      return 2;
    case 'LOW':
      return 1;
    default:
      return 0;
  }
}

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
      accent: Color(0xFF5BE2A3),
      border: Color(0xFF214A3B),
    ),
    RiskIntelAreaSummary(
      title: 'Hyde Park',
      level: 'LOW',
      accent: Color(0xFF5BE2A3),
      border: Color(0xFF214A3B),
    ),
    RiskIntelAreaSummary(
      title: 'Waterfall',
      level: 'MEDIUM',
      accent: Color(0xFFFFC533),
      border: Color(0xFF70511F),
    ),
    RiskIntelAreaSummary(
      title: 'Rosebank',
      level: 'LOW',
      accent: Color(0xFF5BE2A3),
      border: Color(0xFF214A3B),
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
      iconColor: Color(0xFFFFC533),
      summary: 'Protest planned near Rosebank Metro Station tomorrow at 10:00',
    ),
    RiskIntelFeedItem(
      id: 'intel-news24-loadshedding',
      sourceType: 'news',
      provider: 'news24',
      timeLabel: '22:45',
      sourceLabel: 'NEWS24',
      icon: Icons.public_rounded,
      iconColor: Color(0xFF54C8FF),
      summary: 'Load shedding Stage 3 announced - affects all monitored areas',
    ),
    RiskIntelFeedItem(
      id: 'intel-scanner-waterfall',
      sourceType: 'radio',
      provider: 'police-scanner',
      timeLabel: '21:30',
      sourceLabel: 'POLICE SCANNER',
      icon: Icons.sensors_rounded,
      iconColor: Color(0xFFFF7C7C),
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
          accent: const Color(0xFF54C8FF),
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

  @override
  Widget build(BuildContext context) {
    final hottestArea = _highestPriorityArea(areas);
    final leadItem = recentItems.isEmpty ? null : recentItems.first;

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
          final singleColumn = constraints.maxWidth < 1280;

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: surfaceMaxWidth),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OnyxPageHeader(
                      icon: Icons.radar_rounded,
                      iconColor: Colors.amber,
                      title: 'Risk Intelligence',
                      subtitle: 'Threat intelligence and risk.',
                    ),
                    const SizedBox(height: 10),
                    OnyxStatusBanner(
                      message: switch (hottestArea?.level
                              .trim()
                              .toUpperCase() ??
                          '') {
                        'CRITICAL' || 'HIGH' => 'THREAT LEVEL: HIGH',
                        'MEDIUM' || 'MED' => 'THREAT LEVEL: MED',
                        'LOW' => 'THREAT LEVEL: LOW',
                        _ => 'Threat level unknown',
                      },
                      severity: switch (hottestArea?.level
                              .trim()
                              .toUpperCase() ??
                          '') {
                        'CRITICAL' || 'HIGH' => OnyxSeverity.critical,
                        'MEDIUM' || 'MED' => OnyxSeverity.warning,
                        'LOW' => OnyxSeverity.info,
                        _ => OnyxSeverity.info,
                      },
                    ),
                    const SizedBox(height: 18),
                    _IntelStatusStrip(areas: areas),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F4FF),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFBED8F2)),
                      ),
                      child: Text(
                        'Command Board',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF2A6F8A),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Risk Intelligence',
                      style: GoogleFonts.inter(
                        color: _intelTitleColor,
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        height: 0.92,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'AI flags what can hurt tonight and points to the next check.',
                      style: GoogleFonts.inter(
                        color: _intelBodyColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _IntelPriorityPanel(
                      priorityArea: hottestArea,
                      priorityItem: leadItem,
                      onOpenArea: hottestArea == null
                          ? null
                          : () {
                              if (onViewAreaIntel != null &&
                                  hottestArea.eventIds.isNotEmpty) {
                                onViewAreaIntel!(hottestArea);
                                return;
                              }
                              _showAreaIntelDialog(context, hottestArea);
                            },
                      onOpenItem: leadItem == null
                          ? null
                          : () {
                              if (onViewRecentIntel != null) {
                                onViewRecentIntel!(leadItem);
                                return;
                              }
                              _showRecentIntelDialog(context, leadItem);
                            },
                    ),
                    if (latestAutoAuditReceipt != null) ...[
                      const SizedBox(height: 14),
                      _IntelAuditReceipt(
                        receipt: latestAutoAuditReceipt!,
                        onOpenLatestAudit: onOpenLatestAudit,
                      ),
                    ],
                    const SizedBox(height: 18),
                    if (singleColumn) ...[
                      _IntelAreaPanel(
                        areas: areas,
                        onAddManualIntel: () {
                          if (onAddManualIntel != null) {
                            onAddManualIntel!.call();
                            return;
                          }
                          _showManualIntelComposer(context);
                        },
                        onViewAreaIntel: (area) {
                          if (onViewAreaIntel != null &&
                              area.eventIds.isNotEmpty) {
                            onViewAreaIntel!(area);
                            return;
                          }
                          _showAreaIntelDialog(context, area);
                        },
                      ),
                      const SizedBox(height: 18),
                      _IntelRecentPanel(
                        items: recentItems,
                        onViewRecentIntel: (item) {
                          if (onViewRecentIntel != null) {
                            onViewRecentIntel!(item);
                            return;
                          }
                          _showRecentIntelDialog(context, item);
                        },
                      ),
                    ] else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 4,
                            child: _IntelAreaPanel(
                              areas: areas,
                              onAddManualIntel: () {
                                if (onAddManualIntel != null) {
                                  onAddManualIntel!.call();
                                  return;
                                }
                                _showManualIntelComposer(context);
                              },
                              onViewAreaIntel: (area) {
                                if (onViewAreaIntel != null &&
                                    area.eventIds.isNotEmpty) {
                                  onViewAreaIntel!(area);
                                  return;
                                }
                                _showAreaIntelDialog(context, area);
                              },
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            flex: 8,
                            child: _IntelRecentPanel(
                              items: recentItems,
                              onViewRecentIntel: (item) {
                                if (onViewRecentIntel != null) {
                                  onViewRecentIntel!(item);
                                  return;
                                }
                                _showRecentIntelDialog(context, item);
                              },
                            ),
                          ),
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

  RiskIntelAreaSummary? _highestPriorityArea(List<RiskIntelAreaSummary> areas) {
    final withSignals = areas
        .where((area) => area.signalCount > 0)
        .toList(growable: false);
    if (withSignals.isEmpty) {
      return null;
    }
    final sorted = withSignals.toList()
      ..sort((left, right) {
        final levelCompare =
            _riskIntelLevelRank(right.level) - _riskIntelLevelRank(left.level);
        if (levelCompare != 0) {
          return levelCompare;
        }
        return right.signalCount.compareTo(left.signalCount);
      });
    return sorted.first;
  }
}

class _IntelAuditReceipt extends StatelessWidget {
  final RiskIntelAutoAuditReceipt receipt;
  final VoidCallback? onOpenLatestAudit;

  const _IntelAuditReceipt({required this.receipt, this.onOpenLatestAudit});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('intel-latest-audit-panel'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: _intelSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _intelBorderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LATEST COMMAND',
            style: GoogleFonts.inter(
              color: _intelMutedColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: receipt.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: receipt.accent.withValues(alpha: 0.45)),
            ),
            child: Text(
              receipt.label,
              style: GoogleFonts.inter(
                color: receipt.accent,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            receipt.headline,
            style: GoogleFonts.inter(
              color: _intelTitleColor,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 0.96,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            receipt.detail,
            style: GoogleFonts.inter(
              color: _intelBodyColor,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
          if (onOpenLatestAudit != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('intel-view-latest-audit-button'),
              onPressed: onOpenLatestAudit,
              icon: const Icon(Icons.verified_rounded, size: 16),
              label: const Text('View Audit'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF63E6A1),
                side: const BorderSide(color: Color(0xFF63E6A1)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                textStyle: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IntelStatusStrip extends StatelessWidget {
  final List<RiskIntelAreaSummary> areas;

  const _IntelStatusStrip({required this.areas});

  @override
  Widget build(BuildContext context) {
    final highestRank = areas
        .map((area) => _riskIntelLevelRank(area.level))
        .fold<int>(0, (current, value) => value > current ? value : current);
    final status = switch (highestRank) {
      >= 3 => (
        'RED',
        'Check the hottest lane right now.',
        const Color(0xFFD9485F),
        const Color(0xFFFFE8EC),
        const Color(0xFFF1C5CD),
      ),
      2 => (
        'AMBER',
        'Keep dispatch and events ready.',
        const Color(0xFFB7791F),
        const Color(0xFFFFF4DE),
        const Color(0xFFF0D39A),
      ),
      _ => (
        'GREEN',
        'Board quiet. Hold watch.',
        const Color(0xFF218B5A),
        const Color(0xFFE9F8EF),
        const Color(0xFFC1E1CE),
      ),
    };

    return Container(
      key: const ValueKey('intel-status-strip'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: status.$4,
        border: Border.all(color: status.$5),
      ),
      child: Row(
        children: [
          Icon(Icons.trending_up_rounded, color: status.$3, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.$1,
                  style: GoogleFonts.inter(
                    color: _intelTitleColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status.$2,
                  style: GoogleFonts.inter(
                    color: _intelBodyColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IntelPriorityPanel extends StatelessWidget {
  final RiskIntelAreaSummary? priorityArea;
  final RiskIntelFeedItem? priorityItem;
  final VoidCallback? onOpenArea;
  final VoidCallback? onOpenItem;

  const _IntelPriorityPanel({
    required this.priorityArea,
    required this.priorityItem,
    this.onOpenArea,
    this.onOpenItem,
  });

  @override
  Widget build(BuildContext context) {
    final showArea = priorityArea != null;
    final accent = showArea
        ? priorityArea!.accent
        : (priorityItem?.iconColor ?? const Color(0xFF54C8FF));
    final title = showArea
        ? 'Watch ${priorityArea!.title} now'
        : 'Check the latest AI call';
    final summary = showArea
        ? priorityArea!.signalCount == 1
              ? '1 live signal is clustered in ${priorityArea!.title}.'
              : '${priorityArea!.signalCount} live signals are clustered in ${priorityArea!.title}.'
        : (priorityItem?.summary ?? 'Board quiet. Keep passive watch armed.');
    final actionLabel = showArea ? 'OPEN EVENTS SCOPE' : 'VIEW INTEL ITEM';
    final meta = showArea
        ? '${priorityArea!.level} RISK'
        : '${priorityItem?.sourceLabel ?? 'INTEL'}  ${priorityItem?.timeLabel ?? ''}'
              .trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: Color.lerp(_intelSurfaceColor, accent, 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI OPINION',
            style: GoogleFonts.inter(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.inter(
              color: _intelTitleColor,
              fontSize: 30,
              fontWeight: FontWeight.w700,
              height: 0.96,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            summary,
            style: GoogleFonts.inter(
              color: _intelBodyColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: _intelSurfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _intelStrongBorderColor),
            ),
            child: Row(
              children: [
                Text(
                  'Priority',
                  style: GoogleFonts.inter(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                Text(
                  meta,
                  style: GoogleFonts.inter(
                    color: _intelMutedColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('intel-priority-action-button'),
              onPressed: showArea ? onOpenArea : onOpenItem,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntelAreaPanel extends StatelessWidget {
  final List<RiskIntelAreaSummary> areas;
  final VoidCallback onAddManualIntel;
  final ValueChanged<RiskIntelAreaSummary> onViewAreaIntel;

  const _IntelAreaPanel({
    required this.areas,
    required this.onAddManualIntel,
    required this.onViewAreaIntel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('intel-area-panel'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: _intelSurfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _intelBorderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _intelBorderColor)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.place_outlined,
                  color: Color(0xFF54C8FF),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(
                  'WATCH HOTSPOTS',
                  style: GoogleFonts.inter(
                    color: _intelTitleColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                for (var i = 0; i < areas.length; i++) ...[
                  _IntelAreaCard(
                    area: areas[i],
                    onViewIntel: () => onViewAreaIntel(areas[i]),
                  ),
                  if (i != areas.length - 1) const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: OutlinedButton.icon(
              key: const ValueKey('intel-add-manual-button'),
              onPressed: onAddManualIntel,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('OPEN INTEL INTAKE'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2A6F8A),
                side: const BorderSide(color: Color(0xFFBED8F2)),
                backgroundColor: _intelSurfaceTintColor,
                minimumSize: const Size.fromHeight(48),
                textStyle: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntelAreaCard extends StatelessWidget {
  final RiskIntelAreaSummary area;
  final VoidCallback onViewIntel;

  const _IntelAreaCard({required this.area, required this.onViewIntel});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Color.lerp(_intelSurfaceColor, area.accent, 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: area.accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: area.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  area.signalCount == 0 ? 'WATCH' : 'HOT',
                  style: GoogleFonts.inter(
                    color: area.accent,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  area.title,
                  style: GoogleFonts.inter(
                    color: _intelTitleColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    height: 0.96,
                  ),
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: area.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'NOW',
                style: GoogleFonts.inter(
                  color: _intelMutedColor,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Text(
                area.level,
                style: GoogleFonts.inter(
                  color: area.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            area.signalCount == 0
                ? 'Board quiet here. Keep passive watch armed.'
                : area.signalCount == 1
                ? '1 live signal is pushing this lane.'
                : '${area.signalCount} live signals are pushing this lane.',
            style: GoogleFonts.inter(
              color: _intelBodyColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              key: ValueKey(
                'intel-area-${_intelKeySegment(area.title)}-button',
              ),
              onPressed: onViewIntel,
              style: FilledButton.styleFrom(
                foregroundColor: _intelTitleColor,
                backgroundColor: _intelSurfaceTintColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                area.signalCount == 0 ? 'CHECK AREA' : 'OPEN EVENTS SCOPE',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntelRecentPanel extends StatelessWidget {
  final List<RiskIntelFeedItem> items;
  final ValueChanged<RiskIntelFeedItem> onViewRecentIntel;

  const _IntelRecentPanel({
    required this.items,
    required this.onViewRecentIntel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('intel-recent-panel'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: _intelSurfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _intelBorderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _intelBorderColor)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.trending_up_rounded,
                  color: Color(0xFFC084FC),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(
                  'AI OPINION FEED',
                  style: GoogleFonts.inter(
                    color: _intelTitleColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  _IntelItemCard(
                    item: items[i],
                    onViewDetails: () => onViewRecentIntel(items[i]),
                  ),
                  if (i != items.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IntelItemCard extends StatelessWidget {
  final RiskIntelFeedItem item;
  final VoidCallback onViewDetails;

  const _IntelItemCard({required this.item, required this.onViewDetails});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Color.lerp(_intelSurfaceColor, item.iconColor, 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: item.iconColor.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _intelSurfaceTintColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: item.iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: item.iconColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'AI CALL',
                        style: GoogleFonts.inter(
                          color: item.iconColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    Text(
                      item.timeLabel,
                      style: GoogleFonts.robotoMono(
                        color: _intelMutedColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      item.sourceLabel,
                      style: GoogleFonts.inter(
                        color: _intelMutedColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.summary,
                  style: GoogleFonts.inter(
                    color: _intelTitleColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'NEXT MOVE',
                  style: GoogleFonts.inter(
                    color: item.iconColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Check the call, verify the source, then decide whether Events Scope or Dispatch moves next.',
                  style: GoogleFonts.inter(
                    color: _intelBodyColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  key: ValueKey(
                    'intel-detail-${_intelKeySegment(item.sourceLabel)}-button',
                  ),
                  onPressed: onViewDetails,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2A6F8A),
                    side: const BorderSide(color: Color(0xFFBED8F2)),
                    backgroundColor: _intelSurfaceTintColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    textStyle: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('OPEN EVENTS SCOPE'),
                ),
              ],
            ),
          ),
        ],
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
