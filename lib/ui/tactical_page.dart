import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../domain/events/dispatch_event.dart';
import '../domain/events/intelligence_received.dart';
import 'layout_breakpoints.dart';
import 'onyx_surface.dart';

enum _MarkerType { guard, vehicle, incident, site }

enum _MarkerStatus { active, responding, staticMarker, sos }

enum _FenceStatus { safe, breach, stationary }

class _MapMarker {
  final String id;
  final _MarkerType type;
  final double x;
  final double y;
  final String label;
  final _MarkerStatus status;
  final String? lastPing;
  final int? battery;
  final String? eta;
  final String? priority;

  const _MapMarker({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.label,
    required this.status,
    this.lastPing,
    this.battery,
    this.eta,
    this.priority,
  });
}

class _SafetyGeofence {
  final String centerId;
  final double x;
  final double y;
  final _FenceStatus status;
  final int? stationaryTime;

  const _SafetyGeofence({
    required this.centerId,
    required this.x,
    required this.y,
    required this.status,
    this.stationaryTime,
  });
}

class _LensAnomaly {
  final String id;
  final double x;
  final double y;
  final double w;
  final double h;
  final String description;
  final int confidence;

  const _LensAnomaly({
    required this.id,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.description,
    required this.confidence,
  });
}

class _CctvLensTelemetry {
  final int totalSignals;
  final int frMatches;
  final int lprHits;
  final int anomalies;
  final int snapshotsReady;
  final int clipsReady;
  final int suggestedMatchScore;
  final String anomalyTrend;

  const _CctvLensTelemetry({
    required this.totalSignals,
    required this.frMatches,
    required this.lprHits,
    required this.anomalies,
    required this.snapshotsReady,
    required this.clipsReady,
    required this.suggestedMatchScore,
    required this.anomalyTrend,
  });
}

class TacticalPage extends StatelessWidget {
  final List<DispatchEvent> events;
  final String focusIncidentReference;
  final String videoOpsLabel;
  final String cctvOpsReadiness;
  final String cctvOpsDetail;
  final String cctvProvider;
  final String cctvCapabilitySummary;
  final String cctvRecentSignalSummary;

  const TacticalPage({
    super.key,
    required this.events,
    this.focusIncidentReference = '',
    this.videoOpsLabel = 'CCTV',
    this.cctvOpsReadiness = 'UNCONFIGURED',
    this.cctvOpsDetail =
        'Configure ONYX_CCTV_PROVIDER and ONYX_CCTV_EVENTS_URL, or ONYX_DVR_PROVIDER and ONYX_DVR_EVENTS_URL.',
    this.cctvProvider = '',
    this.cctvCapabilitySummary = 'caps none',
    this.cctvRecentSignalSummary =
        'recent video intel 0 (6h) • intrusion 0 • line_crossing 0 • motion 0 • fr 0 • lpr 0',
  });

  static const List<_MapMarker> _markers = [
    _MapMarker(
      id: 'GUARD-ECHO-3',
      type: _MarkerType.guard,
      x: 0.20,
      y: 0.34,
      label: 'Echo-3',
      status: _MarkerStatus.active,
      lastPing: '45s ago',
      battery: 82,
    ),
    _MapMarker(
      id: 'GUARD-ALPHA-1',
      type: _MarkerType.guard,
      x: 0.47,
      y: 0.58,
      label: 'Alpha-1',
      status: _MarkerStatus.sos,
      lastPing: '12s ago',
      battery: 18,
    ),
    _MapMarker(
      id: 'VEHICLE-R12',
      type: _MarkerType.vehicle,
      x: 0.58,
      y: 0.26,
      label: 'Vehicle R-12',
      status: _MarkerStatus.responding,
      eta: 'ETA 4m 12s',
    ),
    _MapMarker(
      id: 'SITE-NORTH',
      type: _MarkerType.site,
      x: 0.76,
      y: 0.74,
      label: 'Sandton North',
      status: _MarkerStatus.staticMarker,
    ),
    _MapMarker(
      id: 'INC-8829-QX',
      type: _MarkerType.incident,
      x: 0.63,
      y: 0.54,
      label: 'INC-8829-QX',
      status: _MarkerStatus.sos,
      priority: 'P1-CRITICAL',
    ),
  ];

  static const List<_SafetyGeofence> _geofences = [
    _SafetyGeofence(
      centerId: 'Echo-3',
      x: 0.20,
      y: 0.34,
      status: _FenceStatus.safe,
    ),
    _SafetyGeofence(
      centerId: 'Alpha-1',
      x: 0.47,
      y: 0.58,
      status: _FenceStatus.breach,
    ),
    _SafetyGeofence(
      centerId: 'Delta-6',
      x: 0.36,
      y: 0.75,
      status: _FenceStatus.stationary,
      stationaryTime: 163,
    ),
  ];

  static const List<_LensAnomaly> _anomalies = [
    _LensAnomaly(
      id: 'ANOM-1',
      x: 0.14,
      y: 0.28,
      w: 0.22,
      h: 0.20,
      description: 'Gate status changed',
      confidence: 94,
    ),
    _LensAnomaly(
      id: 'ANOM-2',
      x: 0.56,
      y: 0.33,
      w: 0.28,
      h: 0.22,
      description: 'Perimeter breach line',
      confidence: 91,
    ),
    _LensAnomaly(
      id: 'ANOM-3',
      x: 0.44,
      y: 0.68,
      w: 0.25,
      h: 0.18,
      description: 'Unauthorized vehicle',
      confidence: 86,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = allowEmbeddedPanelScroll(context);
    final now = DateTime.now();
    final isCombatWindow = now.hour >= 22 || now.hour < 6;
    final normMode = isCombatWindow ? 'night' : 'day';
    final focusReference = focusIncidentReference.trim();
    final focusLinked =
        focusReference.isNotEmpty &&
        _markers.any(
          (marker) =>
              marker.type == _MarkerType.incident &&
              marker.id == focusReference,
        );
    final markers = _resolvedMarkers(
      focusReference: focusReference,
      linkedToLive: focusLinked,
    );
    final geofenceAlerts = _geofences
        .where(
          (fence) =>
              fence.status == _FenceStatus.breach ||
              (fence.status == _FenceStatus.stationary &&
                  (fence.stationaryTime ?? 0) > 120),
        )
        .length;
    final sosAlerts = _markers
        .where(
          (marker) =>
              marker.status == _MarkerStatus.sos &&
              marker.type == _MarkerType.guard,
        )
        .length;
    final lensTelemetry = _buildCctvLensTelemetry();

    return OnyxPageScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _topBar(
                  geofenceAlerts: geofenceAlerts,
                  sosAlerts: sosAlerts,
                  mode: isCombatWindow ? 'Combat Window' : 'Day Window',
                  focusReference: focusReference,
                  focusLinked: focusLinked,
                  cctvReadiness: cctvOpsReadiness,
                  cctvCapabilitySummary: cctvCapabilitySummary,
                  cctvRecentSignalSummary: cctvRecentSignalSummary,
                ),
                const SizedBox(height: 12),
                wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 8,
                            child: _mapPanel(
                              markers: markers,
                              focusReference: focusReference,
                              focusLinked: focusLinked,
                              geofenceAlerts: geofenceAlerts,
                              sosAlerts: sosAlerts,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 4,
                            child: _verificationPanel(
                              normMode: normMode,
                              timestamp: _clockLabel(now),
                              telemetry: lensTelemetry,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          _mapPanel(
                            markers: markers,
                            focusReference: focusReference,
                            focusLinked: focusLinked,
                            geofenceAlerts: geofenceAlerts,
                            sosAlerts: sosAlerts,
                          ),
                          const SizedBox(height: 12),
                          _verificationPanel(
                            normMode: normMode,
                            timestamp: _clockLabel(now),
                            telemetry: lensTelemetry,
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar({
    required int geofenceAlerts,
    required int sosAlerts,
    required String mode,
    required String focusReference,
    required bool focusLinked,
    required String cctvReadiness,
    required String cctvCapabilitySummary,
    required String cctvRecentSignalSummary,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'TACTICAL OVERVIEW',
                style: GoogleFonts.inter(
                  color: const Color(0x66FFFFFF),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              _topChip('Active Responders', '8', const Color(0xFF8FD1FF)),
              _topChip(
                'Geofence Alerts',
                geofenceAlerts.toString(),
                geofenceAlerts > 0
                    ? const Color(0xFFFFC37B)
                    : const Color(0xFF9AB1CF),
              ),
              _topChip(
                'SOS',
                sosAlerts.toString(),
                sosAlerts > 0
                    ? const Color(0xFFFF99A8)
                    : const Color(0xFF9AB1CF),
              ),
              _topChip('Mode', mode, const Color(0xFF8FD1FF)),
              _topChip(
                videoOpsLabel,
                cctvReadiness,
                cctvReadiness == 'ACTIVE'
                    ? const Color(0xFF86EFAC)
                    : cctvReadiness == 'PARTIAL'
                    ? const Color(0xFFFDE68A)
                    : const Color(0xFF9AB1CF),
              ),
              if (focusReference.isNotEmpty)
                _topChip(
                  'Focus',
                  '${focusLinked ? 'Linked' : 'Seeded'} $focusReference',
                  focusLinked
                      ? const Color(0xFF86EFAC)
                      : const Color(0xFFFACC15),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$videoOpsLabel Caps: $cctvCapabilitySummary',
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$videoOpsLabel Recent: $cctvRecentSignalSummary',
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapPanel({
    required List<_MapMarker> markers,
    required String focusReference,
    required bool focusLinked,
    required int geofenceAlerts,
    required int sosAlerts,
  }) {
    final triggerSos = _geofences
        .where((fence) {
          return fence.status == _FenceStatus.breach ||
              (fence.stationaryTime ?? 0) > 120;
        })
        .toList(growable: false);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TACTICAL MAP',
            style: GoogleFonts.inter(
              color: const Color(0x66FFFFFF),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Guard pings, vehicle routes, incident markers, and 50m safety geofences.',
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 430,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final height = constraints.maxHeight;
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(painter: _GridBackdropPainter()),
                      ),
                      Positioned.fill(
                        child: CustomPaint(painter: _RouteOverlayPainter()),
                      ),
                      Positioned(
                        left: width * 0.08,
                        top: height * 0.12,
                        child: Container(
                          width: width * 0.64,
                          height: height * 0.66,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0x3363A8FF),
                              width: 1.2,
                            ),
                            color: const Color(0x090E213B),
                          ),
                        ),
                      ),
                      for (final fence in _geofences)
                        _fenceOverlay(
                          fence: fence,
                          width: width,
                          height: height,
                        ),
                      for (final marker in markers)
                        _markerOverlay(
                          marker: marker,
                          width: width,
                          height: height,
                        ),
                      if (focusReference.isNotEmpty)
                        Positioned(
                          right: 10,
                          top: triggerSos.isNotEmpty ? 52 : 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: focusLinked
                                  ? const Color(0x2234D399)
                                  : const Color(0x33F59E0B),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: focusLinked
                                    ? const Color(0x6634D399)
                                    : const Color(0x66F59E0B),
                              ),
                            ),
                            child: Text(
                              'FOCUS ${focusLinked ? 'LINKED' : 'SEEDED'} • $focusReference',
                              style: GoogleFonts.inter(
                                color: focusLinked
                                    ? const Color(0xFFCCFFE8)
                                    : const Color(0xFFFDE68A),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      if (triggerSos.isNotEmpty)
                        Positioned(
                          right: 10,
                          top: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x33EF4444),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0x99EF4444),
                              ),
                            ),
                            child: Text(
                              'SOS TRIGGER • ${triggerSos.length} geofence anomalies',
                              style: GoogleFonts.inter(
                                color: const Color(0xFFFFB8C1),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        left: 10,
                        bottom: 10,
                        right: 10,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _legendPill('Guard Ping', const Color(0xFF3B82F6)),
                            _legendPill('Vehicle', const Color(0xFF10B981)),
                            _legendPill('Incident', const Color(0xFFEF4444)),
                            _legendPill('Geofence', const Color(0xFF22D3EE)),
                            _legendPill(
                              'Geofence Alert',
                              geofenceAlerts > 0
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF8EA4C2),
                            ),
                            _legendPill(
                              'SOS',
                              sosAlerts > 0
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF8EA4C2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _MapControlChip(label: 'Zoom +'),
              _MapControlChip(label: 'Zoom -'),
              _MapControlChip(label: 'Center Active'),
              _MapControlChip(label: 'Filter: Responding'),
            ],
          ),
        ],
      ),
    );
  }

  List<_MapMarker> _resolvedMarkers({
    required String focusReference,
    required bool linkedToLive,
  }) {
    if (focusReference.isEmpty || linkedToLive) {
      return _markers;
    }
    return [
      _MapMarker(
        id: focusReference,
        type: _MarkerType.incident,
        x: 0.67,
        y: 0.49,
        label: focusReference,
        status: _MarkerStatus.sos,
        priority: 'P2-SEEDED',
      ),
      ..._markers,
    ];
  }

  Widget _verificationPanel({
    required String normMode,
    required String timestamp,
    required _CctvLensTelemetry telemetry,
  }) {
    final matchScore = telemetry.suggestedMatchScore;
    final scoreColor = matchScore >= 95
        ? const Color(0xFF10B981)
        : matchScore >= 60
        ? const Color(0xFFFACC15)
        : const Color(0xFFEF4444);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'VERIFICATION LENS',
            style: GoogleFonts.inter(
              color: const Color(0x66FFFFFF),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Baseline vs live capture with anomaly detection overlays.',
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$videoOpsLabel Ops • $cctvOpsReadiness • $cctvOpsDetail',
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 420;
              final normFrame = _lensFrame(
                label: 'NORM (${normMode.toUpperCase()})',
                accent: const Color(0xFF8EA4C2),
                anomalies: const [],
              );
              final liveFrame = _lensFrame(
                label: 'LIVE • $timestamp',
                accent: const Color(0xFFEF4444),
                anomalies: _anomalies,
              );
              if (stacked) {
                return Column(
                  children: [normFrame, const SizedBox(height: 8), liveFrame],
                );
              }
              return Row(
                children: [
                  Expanded(child: normFrame),
                  const SizedBox(width: 8),
                  Expanded(child: liveFrame),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Text(
            '$videoOpsLabel Signal Counters (6h)',
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _topChip(
                'FR Matches',
                '${telemetry.frMatches}',
                const Color(0xFF8FD1FF),
              ),
              _topChip(
                'Signals',
                '${telemetry.totalSignals}',
                const Color(0xFF9AB1CF),
              ),
              _topChip(
                'LPR Hits',
                '${telemetry.lprHits}',
                const Color(0xFF86EFAC),
              ),
              _topChip(
                'Anomalies',
                '${telemetry.anomalies}',
                const Color(0xFFFF99A8),
              ),
              _topChip(
                'Snapshots',
                '${telemetry.snapshotsReady}',
                const Color(0xFF93C5FD),
              ),
              _topChip(
                'Clips',
                '${telemetry.clipsReady}',
                const Color(0xFFA7F3D0),
              ),
              _topChip(
                'Trend',
                telemetry.anomalyTrend,
                const Color(0xFFFACC15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Match Score',
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '$matchScore%',
            style: GoogleFonts.rajdhani(
              color: scoreColor,
              fontSize: 46,
              height: 0.9,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          for (final anomaly in _anomalies) ...[
            _anomaly(anomaly.description, anomaly.confidence),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  _CctvLensTelemetry _buildCctvLensTelemetry() {
    final nowUtc = DateTime.now().toUtc();
    final windowStartUtc = nowUtc.subtract(const Duration(hours: 6));
    final recentWindowStartUtc = nowUtc.subtract(const Duration(minutes: 30));
    final previousWindowStartUtc = nowUtc.subtract(const Duration(minutes: 60));
    final providerFilter = cctvProvider.trim().toLowerCase();

    var totalSignals = 0;
    var frMatches = 0;
    var lprHits = 0;
    var anomalies = 0;
    var snapshotsReady = 0;
    var clipsReady = 0;
    var anomalyRecentWindow = 0;
    var anomalyPreviousWindow = 0;

    for (final event in events.whereType<IntelligenceReceived>()) {
      if (event.sourceType != 'hardware' && event.sourceType != 'dvr') {
        continue;
      }
      if (providerFilter.isNotEmpty &&
          event.provider.trim().toLowerCase() != providerFilter) {
        continue;
      }
      final occurredAtUtc = event.occurredAt.toUtc();
      if (occurredAtUtc.isBefore(windowStartUtc)) {
        continue;
      }
      totalSignals += 1;
      final headline = event.headline.toLowerCase();
      final summary = event.summary.toLowerCase();

      final isFr = headline.contains('fr_match') || summary.contains('fr:');
      final isLpr = headline.contains('lpr_alert') || summary.contains('lpr:');
      if (isFr) {
        frMatches += 1;
      }
      if (isLpr) {
        lprHits += 1;
      }
      if ((event.snapshotUrl ?? '').trim().isNotEmpty) {
        snapshotsReady += 1;
      }
      if ((event.clipUrl ?? '').trim().isNotEmpty) {
        clipsReady += 1;
      }

      final isAnomaly =
          headline.contains('intrusion') ||
          headline.contains('line_crossing') ||
          headline.contains('tamper') ||
          summary.contains('breach') ||
          event.riskScore >= 80;
      if (!isAnomaly) {
        continue;
      }
      anomalies += 1;
      if (!occurredAtUtc.isBefore(recentWindowStartUtc)) {
        anomalyRecentWindow += 1;
      } else if (!occurredAtUtc.isBefore(previousWindowStartUtc)) {
        anomalyPreviousWindow += 1;
      }
    }

    final anomalyTrend = anomalyRecentWindow > anomalyPreviousWindow
        ? 'UP'
        : anomalyRecentWindow < anomalyPreviousWindow
        ? 'DOWN'
        : 'FLAT';
    final suggestedMatchScore = totalSignals == 0
        ? 58
        : (96 - (anomalies * 10) - (frMatches * 2) - (lprHits * 2)).clamp(
            35,
            98,
          );
    return _CctvLensTelemetry(
      totalSignals: totalSignals,
      frMatches: frMatches,
      lprHits: lprHits,
      anomalies: anomalies,
      snapshotsReady: snapshotsReady,
      clipsReady: clipsReady,
      suggestedMatchScore: suggestedMatchScore,
      anomalyTrend: anomalyTrend,
    );
  }

  Widget _markerOverlay({
    required _MapMarker marker,
    required double width,
    required double height,
  }) {
    final left = marker.x * width;
    final top = marker.y * height;
    final color = _markerColor(marker.type, marker.status);
    final icon = switch (marker.type) {
      _MarkerType.guard => Icons.person_pin_circle_rounded,
      _MarkerType.vehicle => Icons.directions_car_filled_rounded,
      _MarkerType.incident => Icons.warning_amber_rounded,
      _MarkerType.site => Icons.apartment_rounded,
    };
    final meta =
        marker.eta ??
        marker.priority ??
        (marker.lastPing == null ? null : 'Ping ${marker.lastPing}');
    final batteryLow = marker.battery != null && marker.battery! < 20;
    return Positioned(
      left: math.max(8, math.min(left - 60, width - 130)),
      top: math.max(8, math.min(top - 20, height - 68)),
      child: Container(
        width: 122,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xCC0A0D14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.68)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    marker.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFE8F1FF),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (meta != null) ...[
              const SizedBox(height: 4),
              Text(
                meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: const Color(0xFF9AB1CF),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (marker.battery != null) ...[
              const SizedBox(height: 3),
              Text(
                'Battery ${marker.battery}%',
                style: GoogleFonts.inter(
                  color: batteryLow
                      ? const Color(0xFFFACC15)
                      : const Color(0xFF9AB1CF),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _fenceOverlay({
    required _SafetyGeofence fence,
    required double width,
    required double height,
  }) {
    final left = fence.x * width;
    final top = fence.y * height;
    final radius = math.max(32.0, width * 0.075);
    final color = switch (fence.status) {
      _FenceStatus.safe => const Color(0x8022D3EE),
      _FenceStatus.breach => const Color(0xCCEF4444),
      _FenceStatus.stationary => const Color(0xCCF59E0B),
    };
    final fill = switch (fence.status) {
      _FenceStatus.safe => const Color(0x1422D3EE),
      _FenceStatus.breach => const Color(0x22EF4444),
      _FenceStatus.stationary => const Color(0x22F59E0B),
    };
    return Positioned(
      left: left - radius,
      top: top - radius,
      child: IgnorePointer(
        child: Container(
          width: radius * 2,
          height: radius * 2,
          alignment: Alignment.bottomCenter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fill,
            border: Border.all(color: color, width: 1.2),
          ),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              '${fence.centerId} • 50m',
              style: GoogleFonts.inter(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _lensFrame({
    required String label,
    required Color accent,
    required List<_LensAnomaly> anomalies,
  }) {
    return Container(
      height: 132,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x22FFFFFF)),
        gradient: const LinearGradient(
          colors: [Color(0xFF101C2C), Color(0xFF0C1220)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          return Stack(
            children: [
              Positioned(
                left: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xCC000000),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      color: const Color(0xCCFFFFFF),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              for (final anomaly in anomalies)
                Positioned(
                  left: anomaly.x * width,
                  top: anomaly.y * height,
                  child: Container(
                    width: anomaly.w * width,
                    height: anomaly.h * height,
                    decoration: BoxDecoration(
                      color: const Color(0x22EF4444),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: const Color(0xCCEF4444),
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  width: 26,
                  height: 3,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _anomaly(String label, int confidence) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0x22EF4444),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x55EF4444)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(0xFFFFB4BD),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '$confidence%',
            style: GoogleFonts.robotoMono(
              color: const Color(0xFFEF4444),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _topChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        '$label • $value',
        style: GoogleFonts.inter(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _legendPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xCC0A0D14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFFD8E7FA),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Color _markerColor(_MarkerType type, _MarkerStatus status) {
    if (status == _MarkerStatus.sos) return const Color(0xFFEF4444);
    return switch (type) {
      _MarkerType.guard => const Color(0xFF3B82F6),
      _MarkerType.vehicle => const Color(0xFF10B981),
      _MarkerType.incident => const Color(0xFFEF4444),
      _MarkerType.site => const Color(0xFF8EA4C2),
    };
  }

  String _clockLabel(DateTime now) {
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

class _MapControlChip extends StatelessWidget {
  final String label;

  const _MapControlChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF35506F)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: const Color(0xFFB9D2F1),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _GridBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF0C1220);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final fineLine = Paint()
      ..color = const Color(0x1E6F91BE)
      ..strokeWidth = 1;
    const step = 32.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), fineLine);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), fineLine);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RouteOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final route = Paint()
      ..color = const Color(0x4D10B981)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(size.width * 0.23, size.height * 0.36)
      ..lineTo(size.width * 0.40, size.height * 0.42)
      ..lineTo(size.width * 0.56, size.height * 0.30)
      ..lineTo(size.width * 0.63, size.height * 0.54);
    canvas.drawPath(path, route);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
