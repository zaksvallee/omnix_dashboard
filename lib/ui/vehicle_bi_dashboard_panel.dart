import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../application/morning_sovereign_report_service.dart';
import 'theme/onyx_design_tokens.dart';

const _vehicleBiPanelColor = OnyxColorTokens.backgroundSecondary;
const _vehicleBiSectionColor = OnyxColorTokens.surfaceElevated;
const _vehicleBiBorderColor = OnyxColorTokens.borderSubtle;
const _vehicleBiTitleColor = OnyxColorTokens.textPrimary;
const _vehicleBiBodyColor = OnyxColorTokens.textSecondary;
const _vehicleBiMutedColor = OnyxColorTokens.textMuted;
const _vehicleBiSky = OnyxColorTokens.accentCyanTrue;
const _vehicleBiSkyAlt = OnyxColorTokens.accentSky;
const _vehicleBiGreen = OnyxColorTokens.accentGreen;
const _vehicleBiAmber = OnyxColorTokens.accentAmber;
const _vehicleBiRed = OnyxColorTokens.accentRed;

class VehicleBiDashboardPanel extends StatelessWidget {
  final SovereignReportVehicleThroughput throughput;
  final String scopeLabel;

  const VehicleBiDashboardPanel({
    super.key,
    required this.throughput,
    this.scopeLabel = 'Current shift',
  });

  @override
  Widget build(BuildContext context) {
    final repeatRate = throughput.uniqueVehicles == 0
        ? 0.0
        : (throughput.repeatVehicles / throughput.uniqueVehicles) * 100;
    final hourlyEntries = throughput.hourlyBreakdown.entries.toList(
      growable: false,
    )..sort((left, right) => left.key.compareTo(right.key));
    final peakHourLabel = throughput.peakHourLabel.trim();
    final showPeakHourSummary =
        peakHourLabel.isNotEmpty &&
        peakHourLabel.toLowerCase() != 'none' &&
        throughput.peakHourVisitCount > 0;
    final exceptionVisits = throughput.exceptionVisits;
    return Container(
      decoration: BoxDecoration(
        color: _vehicleBiPanelColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _vehicleBiBorderColor),
      ),
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vehicle BI dashboard',
              style: GoogleFonts.inter(
                color: _vehicleBiTitleColor,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              scopeLabel,
              style: GoogleFonts.inter(
                color: _vehicleBiBodyColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _VehicleBiMetricCard(
                  key: const ValueKey('vehicle-bi-total-vehicles-card'),
                  label: 'Total vehicles',
                  value: '${throughput.totalVisits}',
                  detail: '${throughput.uniqueVehicles} unique seen',
                  accent: _vehicleBiSky,
                ),
                _VehicleBiMetricCard(
                  key: const ValueKey('vehicle-bi-average-dwell-card'),
                  label: 'Average dwell time',
                  value:
                      '${throughput.averageCompletedDwellMinutes.toStringAsFixed(1)} min',
                  detail: '${throughput.completedVisits} completed visits',
                  accent: _vehicleBiGreen,
                ),
                _VehicleBiMetricCard(
                  key: const ValueKey('vehicle-bi-repeat-rate-card'),
                  label: 'Repeat customer rate',
                  value: '${repeatRate.toStringAsFixed(1)}%',
                  detail: '${throughput.repeatVehicles} repeat vehicles',
                  accent: _vehicleBiAmber,
                ),
                _VehicleBiMetricCard(
                  key: const ValueKey('vehicle-bi-exception-visits-card'),
                  label: 'Exception visits',
                  value: '${exceptionVisits.length}',
                  detail: exceptionVisits.isEmpty
                      ? 'No flagged visits'
                      : '${throughput.loiteringVisitCount} loitering • ${throughput.suspiciousShortVisitCount} short stay',
                  accent: _vehicleBiRed,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _VehicleBiSectionCard(
              title: 'Hourly bar chart',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showPeakHourSummary) ...[
                    _VehicleBiPeakHourSummary(
                      peakHourLabel: peakHourLabel,
                      peakHourVisitCount: throughput.peakHourVisitCount,
                    ),
                    const SizedBox(height: 14),
                  ],
                  hourlyEntries.isEmpty
                      ? _VehicleBiEmptyState(
                          message: 'No hourly vehicle traffic recorded.',
                        )
                      : _VehicleBiHourlyChart(
                          entries: hourlyEntries,
                          peakHourLabel: peakHourLabel,
                          peakHourVisitCount: throughput.peakHourVisitCount,
                        ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _VehicleBiSectionCard(
              title: 'Entry -> Service -> Exit funnel',
              child: _VehicleBiFunnel(
                entryCount: throughput.entryCount,
                serviceCount: throughput.serviceCount,
                exitCount: throughput.exitCount,
              ),
            ),
            const SizedBox(height: 16),
            _VehicleBiSectionCard(
              title: 'Exception visits',
              child: exceptionVisits.isEmpty
                  ? _VehicleBiEmptyState(
                      message: 'No exception visits flagged for this shift.',
                    )
                  : _VehicleBiExceptionList(visits: exceptionVisits),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleBiMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String detail;
  final Color accent;

  const _VehicleBiMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.detail,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 176, maxWidth: 220),
      decoration: BoxDecoration(
        color: _vehicleBiSectionColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _vehicleBiBorderColor),
        boxShadow: [
          BoxShadow(
            color: OnyxColorTokens.backgroundPrimary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: GoogleFonts.inter(
              color: _vehicleBiBodyColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              color: _vehicleBiTitleColor,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            style: GoogleFonts.inter(
              color: _vehicleBiMutedColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleBiSectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _VehicleBiSectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _vehicleBiSectionColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _vehicleBiBorderColor),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: _vehicleBiTitleColor,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _VehicleBiEmptyState extends StatelessWidget {
  final String message;

  const _VehicleBiEmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: GoogleFonts.inter(
        color: _vehicleBiMutedColor,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _VehicleBiHourlyChart extends StatelessWidget {
  final List<MapEntry<int, int>> entries;
  final String peakHourLabel;
  final int peakHourVisitCount;

  const _VehicleBiHourlyChart({
    required this.entries,
    this.peakHourLabel = '',
    this.peakHourVisitCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final maxValue = math.max(
      1,
      entries.map((entry) => entry.value).fold<int>(0, math.max),
    );
    final resolvedPeakHourLabel = peakHourLabel.trim();
    final annotatePeakHour =
        resolvedPeakHourLabel.isNotEmpty &&
        resolvedPeakHourLabel.toLowerCase() != 'none' &&
        peakHourVisitCount > 0;
    final chartHeight = annotatePeakHour ? 184.0 : 168.0;
    final maxBarHeight = annotatePeakHour ? 92.0 : 108.0;
    return SizedBox(
      height: chartHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final entry in entries)
            Builder(
              builder: (context) {
                final entryHourRange = _vehicleBiHourRangeLabel(entry.key);
                final isPeakHour =
                    annotatePeakHour && entryHourRange == resolvedPeakHourLabel;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isPeakHour) ...[
                          Container(
                            key: ValueKey('vehicle-bi-peak-badge-${entry.key}'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: OnyxColorTokens.cyanSurface,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: OnyxColorTokens.cyanBorder,
                              ),
                            ),
                            child: Text(
                              'Peak',
                              style: GoogleFonts.inter(
                                color: _vehicleBiSky,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                        Text(
                          '${entry.value}',
                          style: GoogleFonts.inter(
                            color: isPeakHour
                                ? _vehicleBiSky
                                : _vehicleBiBodyColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          key: ValueKey('vehicle-bi-hour-bar-${entry.key}'),
                          height: maxBarHeight * (entry.value / maxValue),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: isPeakHour
                                ? Border.all(
                                    color: _vehicleBiSky,
                                    width: 2,
                                  )
                                : null,
                            boxShadow: isPeakHour
                                ? [
                                    BoxShadow(
                                      color: _vehicleBiSky.withValues(
                                        alpha: 0.15,
                                      ),
                                      blurRadius: 12,
                                      offset: Offset(0, 6),
                                    ),
                                  ]
                                : null,
                            gradient: const LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                _vehicleBiSky,
                                _vehicleBiSkyAlt,
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${entry.key.toString().padLeft(2, '0')}:00',
                          style: GoogleFonts.inter(
                            color: isPeakHour
                                ? _vehicleBiSky
                                : _vehicleBiMutedColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _VehicleBiPeakHourSummary extends StatelessWidget {
  final String peakHourLabel;
  final int peakHourVisitCount;

  const _VehicleBiPeakHourSummary({
    required this.peakHourLabel,
    required this.peakHourVisitCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('vehicle-bi-peak-hour-summary'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OnyxColorTokens.cyanSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OnyxColorTokens.cyanBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.insights_rounded, color: _vehicleBiSky, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Peak hour: $peakHourLabel • $peakHourVisitCount visit${peakHourVisitCount == 1 ? '' : 's'}',
              style: GoogleFonts.inter(
                color: _vehicleBiSkyAlt,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleBiExceptionList extends StatelessWidget {
  final List<SovereignReportVehicleVisitException> visits;

  const _VehicleBiExceptionList({required this.visits});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int index = 0; index < visits.length; index++) ...[
          if (index > 0) const SizedBox(height: 12),
          _VehicleBiExceptionCard(exception: visits[index]),
        ],
      ],
    );
  }
}

class _VehicleBiExceptionCard extends StatelessWidget {
  final SovereignReportVehicleVisitException exception;

  const _VehicleBiExceptionCard({required this.exception});

  @override
  Widget build(BuildContext context) {
    final accent = _vehicleBiExceptionAccent(exception.statusLabel);
    final reviewedLabel = exception.operatorReviewedAtUtc == null
        ? 'Awaiting review'
        : 'Reviewed ${_vehicleBiUtcLabel(exception.operatorReviewedAtUtc!)}';
    final workflowSummary = exception.workflowSummary.trim().isEmpty
        ? 'Workflow summary unavailable.'
        : exception.workflowSummary.trim();
    return Container(
      key: ValueKey('vehicle-bi-exception-visit-${exception.primaryEventId}'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _vehicleBiSectionColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _vehicleBiBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  exception.vehicleLabel,
                  style: GoogleFonts.inter(
                    color: _vehicleBiTitleColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accent.withValues(alpha: 0.32)),
                ),
                child: Text(
                  exception.statusLabel,
                  style: GoogleFonts.inter(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            exception.reasonLabel,
            style: GoogleFonts.inter(
              color: _vehicleBiTitleColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${exception.dwellMinutes.toStringAsFixed(0)} min dwell • $workflowSummary',
            style: GoogleFonts.inter(
              color: _vehicleBiBodyColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _VehicleBiDetailChip(
                label: reviewedLabel,
                accent: accent,
              ),
              if (exception.zoneLabels.isNotEmpty)
                _VehicleBiDetailChip(
                  label: exception.zoneLabels.join(' • '),
                  accent: _vehicleBiSky,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VehicleBiDetailChip extends StatelessWidget {
  final String label;
  final Color accent;

  const _VehicleBiDetailChip({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: accent,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _VehicleBiFunnel extends StatelessWidget {
  final int entryCount;
  final int serviceCount;
  final int exitCount;

  const _VehicleBiFunnel({
    required this.entryCount,
    required this.serviceCount,
    required this.exitCount,
  });

  @override
  Widget build(BuildContext context) {
    final peakCount = math.max(1, math.max(entryCount, math.max(serviceCount, exitCount)));
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _VehicleBiFunnelStage(
                key: const ValueKey('vehicle-bi-funnel-entry'),
                label: 'Entry',
                value: entryCount,
                ratio: entryCount / peakCount,
                color: _vehicleBiSky,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _VehicleBiFunnelStage(
                key: const ValueKey('vehicle-bi-funnel-service'),
                label: 'Service',
                value: serviceCount,
                ratio: serviceCount / peakCount,
                color: _vehicleBiAmber,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _VehicleBiFunnelStage(
                key: const ValueKey('vehicle-bi-funnel-exit'),
                label: 'Exit',
                value: exitCount,
                ratio: exitCount / peakCount,
                color: _vehicleBiGreen,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _vehicleBiHourRangeLabel(int hour) {
  final start = hour.toString().padLeft(2, '0');
  final end = ((hour + 1) % 24).toString().padLeft(2, '0');
  return '$start:00-$end:00';
}

String _vehicleBiUtcLabel(DateTime value) {
  final utc = value.toUtc();
  final hour = utc.hour.toString().padLeft(2, '0');
  final minute = utc.minute.toString().padLeft(2, '0');
  return '$hour:$minute UTC';
}

Color _vehicleBiExceptionAccent(String statusLabel) {
  switch (statusLabel.trim().toUpperCase()) {
    case 'RESOLVED':
    case 'CLEARED':
      return _vehicleBiGreen;
    case 'WATCH':
    case 'PENDING':
      return _vehicleBiAmber;
    default:
      return _vehicleBiRed;
  }
}

class _VehicleBiFunnelStage extends StatelessWidget {
  final String label;
  final int value;
  final double ratio;
  final Color color;

  const _VehicleBiFunnelStage({
    super.key,
    required this.label,
    required this.value,
    required this.ratio,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _vehicleBiSectionColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _vehicleBiBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: _vehicleBiBodyColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: GoogleFonts.inter(
              color: _vehicleBiTitleColor,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 10,
              child: Stack(
                children: [
                  Container(color: OnyxColorTokens.divider),
                  FractionallySizedBox(
                    widthFactor: ratio.clamp(0.0, 1.0),
                    child: Container(color: color),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
