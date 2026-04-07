import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../application/morning_sovereign_report_service.dart';

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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFD7E2EE)),
      ),
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vehicle BI dashboard',
              style: GoogleFonts.inter(
                color: const Color(0xFF182638),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              scopeLabel,
              style: GoogleFonts.inter(
                color: const Color(0xFF66788B),
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
                  accent: const Color(0xFF0EA5E9),
                ),
                _VehicleBiMetricCard(
                  key: const ValueKey('vehicle-bi-average-dwell-card'),
                  label: 'Average dwell time',
                  value:
                      '${throughput.averageCompletedDwellMinutes.toStringAsFixed(1)} min',
                  detail: '${throughput.completedVisits} completed visits',
                  accent: const Color(0xFF10B981),
                ),
                _VehicleBiMetricCard(
                  key: const ValueKey('vehicle-bi-repeat-rate-card'),
                  label: 'Repeat customer rate',
                  value: '${repeatRate.toStringAsFixed(1)}%',
                  detail: '${throughput.repeatVehicles} repeat vehicles',
                  accent: const Color(0xFFF59E0B),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _VehicleBiSectionCard(
              title: 'Hourly bar chart',
              child: hourlyEntries.isEmpty
                  ? _VehicleBiEmptyState(
                      message: 'No hourly vehicle traffic recorded.',
                    )
                  : _VehicleBiHourlyChart(entries: hourlyEntries),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD7E2EE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F2235),
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
              color: const Color(0xFF51677D),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              color: const Color(0xFF182638),
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            style: GoogleFonts.inter(
              color: const Color(0xFF74879B),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD7E2EE)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: const Color(0xFF182638),
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
        color: const Color(0xFF74879B),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _VehicleBiHourlyChart extends StatelessWidget {
  final List<MapEntry<int, int>> entries;

  const _VehicleBiHourlyChart({required this.entries});

  @override
  Widget build(BuildContext context) {
    final maxValue = math.max(
      1,
      entries.map((entry) => entry.value).fold<int>(0, math.max),
    );
    return SizedBox(
      height: 168,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final entry in entries)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${entry.value}',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF51677D),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      key: ValueKey('vehicle-bi-hour-bar-${entry.key}'),
                      height: 108 * (entry.value / maxValue),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Color(0xFF0EA5E9),
                            Color(0xFF8FD1FF),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${entry.key.toString().padLeft(2, '0')}:00',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF74879B),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
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
                color: const Color(0xFF0EA5E9),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _VehicleBiFunnelStage(
                key: const ValueKey('vehicle-bi-funnel-service'),
                label: 'Service',
                value: serviceCount,
                ratio: serviceCount / peakCount,
                color: const Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _VehicleBiFunnelStage(
                key: const ValueKey('vehicle-bi-funnel-exit'),
                label: 'Exit',
                value: exitCount,
                ratio: exitCount / peakCount,
                color: const Color(0xFF10B981),
              ),
            ),
          ],
        ),
      ],
    );
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
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD7E2EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF51677D),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: GoogleFonts.inter(
              color: const Color(0xFF182638),
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
                  Container(color: const Color(0xFFE7EEF6)),
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
