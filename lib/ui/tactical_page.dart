import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../application/monitoring_scene_review_store.dart';
import '../domain/events/decision_created.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/events/execution_completed.dart';
import '../domain/events/execution_denied.dart';
import '../domain/events/incident_closed.dart';
import '../domain/events/intelligence_received.dart';
import '../domain/events/partner_dispatch_status_declared.dart';
import '../domain/events/response_arrived.dart';
import 'layout_breakpoints.dart';
import 'onyx_surface.dart';
import 'video_fleet_scope_health_card.dart';
import 'video_fleet_scope_health_panel.dart';
import 'video_fleet_scope_health_sections.dart';
import 'video_fleet_scope_health_view.dart';

enum _MarkerType { guard, vehicle, incident, site }

enum _MarkerStatus { active, responding, staticMarker, sos }

enum _FenceStatus { safe, breach, stationary }

enum _FocusLinkState { none, exact, scopeBacked, seeded }

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

class _SuppressedFleetReviewEntry {
  final VideoFleetScopeHealthView scope;
  final MonitoringSceneReviewRecord review;

  const _SuppressedFleetReviewEntry({
    required this.scope,
    required this.review,
  });
}

class TacticalPage extends StatelessWidget {
  final List<DispatchEvent> events;
  final String focusIncidentReference;
  final String? initialScopeClientId;
  final String? initialScopeSiteId;
  final String videoOpsLabel;
  final String cctvOpsReadiness;
  final String cctvOpsDetail;
  final String cctvProvider;
  final String cctvCapabilitySummary;
  final String cctvRecentSignalSummary;
  final List<VideoFleetScopeHealthView> fleetScopeHealth;
  final Map<String, MonitoringSceneReviewRecord> sceneReviewByIntelligenceId;
  final void Function(
    String clientId,
    String siteId,
    String? incidentReference,
  )?
  onOpenFleetTacticalScope;
  final void Function(
    String clientId,
    String siteId,
    String? incidentReference,
  )?
  onOpenFleetDispatchScope;
  final void Function(String clientId, String siteId)? onRecoverFleetWatchScope;
  final Future<String> Function(VideoFleetScopeHealthView scope)?
  onExtendTemporaryIdentityApproval;
  final Future<String> Function(VideoFleetScopeHealthView scope)?
  onExpireTemporaryIdentityApproval;
  final VideoFleetWatchActionDrilldown? initialWatchActionDrilldown;
  final ValueChanged<VideoFleetWatchActionDrilldown?>?
  onWatchActionDrilldownChanged;

  const TacticalPage({
    super.key,
    required this.events,
    this.focusIncidentReference = '',
    this.initialScopeClientId,
    this.initialScopeSiteId,
    this.videoOpsLabel = 'CCTV',
    this.cctvOpsReadiness = 'UNCONFIGURED',
    this.cctvOpsDetail =
        'Configure ONYX_CCTV_PROVIDER and ONYX_CCTV_EVENTS_URL, or ONYX_DVR_PROVIDER and ONYX_DVR_EVENTS_URL.',
    this.cctvProvider = '',
    this.cctvCapabilitySummary = 'caps none',
    this.cctvRecentSignalSummary =
        'recent video intel 0 (6h) • intrusion 0 • line_crossing 0 • motion 0 • fr 0 • lpr 0',
    this.fleetScopeHealth = const [],
    this.sceneReviewByIntelligenceId =
        const <String, MonitoringSceneReviewRecord>{},
    this.onOpenFleetTacticalScope,
    this.onOpenFleetDispatchScope,
    this.onRecoverFleetWatchScope,
    this.onExtendTemporaryIdentityApproval,
    this.onExpireTemporaryIdentityApproval,
    this.initialWatchActionDrilldown,
    this.onWatchActionDrilldownChanged,
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
    VideoFleetWatchActionDrilldown? activeWatchActionDrilldown =
        initialWatchActionDrilldown;
    return StatefulBuilder(
      builder: (context, setState) {
        final fleetPanelKey = GlobalKey();
        final suppressedPanelKey = GlobalKey();
        final wide = allowEmbeddedPanelScroll(context);
        final now = DateTime.now();
        final isCombatWindow = now.hour >= 22 || now.hour < 6;
        final normMode = isCombatWindow ? 'night' : 'day';
        final focusReference = focusIncidentReference.trim();
        final scopeClientId = (initialScopeClientId ?? '').trim();
        final scopeSiteId = (initialScopeSiteId ?? '').trim();
        final hasScopeFocus = scopeClientId.isNotEmpty;
        final visibleFleetScopeHealth = hasScopeFocus
            ? fleetScopeHealth
                  .where((scope) {
                    if (scope.clientId.trim() != scopeClientId) {
                      return false;
                    }
                    if (scopeSiteId.isEmpty) {
                      return true;
                    }
                    return scope.siteId.trim() == scopeSiteId;
                  })
                  .toList(growable: false)
            : fleetScopeHealth;
        final focusState = _resolveFocusLinkState(
          focusReference: focusReference,
          visibleFleetScopeHealth: visibleFleetScopeHealth,
          events: events,
        );
        final markers = _resolvedMarkers(
          focusReference: focusReference,
          focusState: focusState,
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
        final suppressedEntries = _suppressedFleetReviewEntries(
          visibleFleetScopeHealth,
        );
        final headerDispatchAction = _headerDispatchAction(
          visibleFleetScopeHealth: visibleFleetScopeHealth,
          focusReference: focusReference,
          scopeClientId: scopeClientId,
          scopeSiteId: scopeSiteId,
        );
        final showSuppressedPrimary =
            activeWatchActionDrilldown ==
                VideoFleetWatchActionDrilldown.filtered &&
            suppressedEntries.isNotEmpty;
        void setActiveWatchActionDrilldown(
          VideoFleetWatchActionDrilldown? value,
        ) {
          if (activeWatchActionDrilldown == value) {
            return;
          }
          setState(() {
            activeWatchActionDrilldown = value;
          });
          onWatchActionDrilldownChanged?.call(value);
        }

        void openWatchActionDrilldown(
          VideoFleetWatchActionDrilldown drilldown,
        ) {
          if (activeWatchActionDrilldown == drilldown) {
            setActiveWatchActionDrilldown(null);
            return;
          }
          setActiveWatchActionDrilldown(drilldown);
          final targetContext =
              drilldown == VideoFleetWatchActionDrilldown.filtered &&
                  suppressedEntries.isNotEmpty
              ? suppressedPanelKey.currentContext
              : fleetPanelKey.currentContext;
          if (targetContext == null) {
            return;
          }
          Scrollable.ensureVisible(
            targetContext,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          );
        }

        void openLatestWatchActionDetail(VideoFleetScopeHealthView scope) {
          if (activeWatchActionDrilldown ==
                  VideoFleetWatchActionDrilldown.filtered &&
              suppressedEntries.isNotEmpty) {
            final targetContext = suppressedPanelKey.currentContext;
            if (targetContext != null) {
              Scrollable.ensureVisible(
                targetContext,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
              );
            }
            return;
          }
          final primaryOpenFleetScope = scope.hasIncidentContext
              ? (onOpenFleetTacticalScope ?? onOpenFleetDispatchScope)
              : null;
          if (primaryOpenFleetScope == null) {
            return;
          }
          primaryOpenFleetScope.call(
            scope.clientId,
            scope.siteId,
            scope.latestIncidentReference,
          );
        }

        return OnyxPageScaffold(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1500),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _heroHeader(
                      dispatchAction: headerDispatchAction,
                      visibleFleetScopeHealth: visibleFleetScopeHealth,
                    ),
                    const SizedBox(height: 12),
                    if (sosAlerts > 0) ...[
                      _tacticalAlertBanner(
                        key: const ValueKey('tactical-sos-banner'),
                        icon: Icons.warning_amber_rounded,
                        accent: const Color(0xFFEF4444),
                        label: 'ACTIVE SOS TRIGGER',
                        message:
                            '$sosAlerts guard ping${sosAlerts == 1 ? '' : 's'} need immediate tactical attention',
                        actionLabel: 'OPEN DISPATCHES',
                        onPressed: headerDispatchAction,
                      ),
                      const SizedBox(height: 12),
                    ] else if (geofenceAlerts > 0) ...[
                      _tacticalAlertBanner(
                        key: const ValueKey('tactical-geofence-banner'),
                        icon: Icons.report_gmailerrorred_rounded,
                        accent: const Color(0xFFF59E0B),
                        label: 'GEOFENCE BREACH DETECTED',
                        message:
                            '$geofenceAlerts perimeter alert${geofenceAlerts == 1 ? '' : 's'} need investigation',
                        actionLabel: 'INVESTIGATE',
                        onPressed: headerDispatchAction,
                      ),
                      const SizedBox(height: 12),
                    ],
                    _topBar(
                      geofenceAlerts: geofenceAlerts,
                      sosAlerts: sosAlerts,
                      mode: isCombatWindow ? 'Combat Window' : 'Day Window',
                      focusReference: focusReference,
                      focusState: focusState,
                      scopeClientId: scopeClientId,
                      scopeSiteId: scopeSiteId,
                      cctvReadiness: cctvOpsReadiness,
                      cctvCapabilitySummary: cctvCapabilitySummary,
                      cctvRecentSignalSummary: cctvRecentSignalSummary,
                    ),
                    if (hasScopeFocus) ...[
                      const SizedBox(height: 12),
                      _scopeFocusBanner(
                        clientId: scopeClientId,
                        siteId: scopeSiteId,
                        hasFleetScope: visibleFleetScopeHealth.isNotEmpty,
                      ),
                    ],
                    if (showSuppressedPrimary) ...[
                      const SizedBox(height: 12),
                      KeyedSubtree(
                        key: suppressedPanelKey,
                        child: _suppressedReviewPanel(suppressedEntries),
                      ),
                    ],
                    if (visibleFleetScopeHealth.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      KeyedSubtree(
                        key: fleetPanelKey,
                        child: _fleetScopePanel(
                          context: context,
                          fleetScopeHealth: visibleFleetScopeHealth,
                          activeWatchActionDrilldown:
                              activeWatchActionDrilldown,
                          onOpenWatchActionDrilldown: openWatchActionDrilldown,
                          onOpenLatestWatchActionDetail:
                              openLatestWatchActionDetail,
                          onClearWatchActionDrilldown: () {
                            setActiveWatchActionDrilldown(null);
                          },
                        ),
                      ),
                    ],
                    if (!showSuppressedPrimary &&
                        suppressedEntries.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      KeyedSubtree(
                        key: suppressedPanelKey,
                        child: _suppressedReviewPanel(suppressedEntries),
                      ),
                    ],
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
                                  focusState: focusState,
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
                                focusState: focusState,
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
      },
    );
  }

  VoidCallback? _headerDispatchAction({
    required List<VideoFleetScopeHealthView> visibleFleetScopeHealth,
    required String focusReference,
    required String scopeClientId,
    required String scopeSiteId,
  }) {
    final openDispatchScope = onOpenFleetDispatchScope;
    if (openDispatchScope == null) {
      return null;
    }
    VideoFleetScopeHealthView? targetScope;
    if (focusReference.isNotEmpty) {
      for (final scope in visibleFleetScopeHealth) {
        if (scope.latestIncidentReference == focusReference) {
          targetScope = scope;
          break;
        }
      }
    }
    targetScope ??= visibleFleetScopeHealth.firstWhere(
      (scope) => scope.hasIncidentContext,
      orElse: () => visibleFleetScopeHealth.isNotEmpty
          ? visibleFleetScopeHealth.first
          : const VideoFleetScopeHealthView(
              clientId: '',
              siteId: '',
              siteName: '',
              endpointLabel: '',
              statusLabel: '',
              watchLabel: '',
              recentEvents: 0,
              lastSeenLabel: '',
              freshnessLabel: '',
              isStale: false,
            ),
    );
    final targetClientId = targetScope.clientId.trim().isNotEmpty
        ? targetScope.clientId
        : scopeClientId;
    final targetSiteId = targetScope.siteId.trim().isNotEmpty
        ? targetScope.siteId
        : scopeSiteId;
    final targetReference = targetScope.latestIncidentReference ?? focusReference;
    if (targetClientId.trim().isEmpty || targetSiteId.trim().isEmpty) {
      return null;
    }
    return () =>
        openDispatchScope(targetClientId, targetSiteId, targetReference);
  }

  Widget _heroHeader({
    required VoidCallback? dispatchAction,
    required List<VideoFleetScopeHealthView> visibleFleetScopeHealth,
  }) {
    final limitedCount = visibleFleetScopeHealth
        .where((scope) => scope.watchLabel == 'LIMITED')
        .length;
    final unavailableCount = visibleFleetScopeHealth
        .where((scope) => scope.watchLabel == 'UNAVAILABLE')
        .length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 980;
        final actionButton = OutlinedButton.icon(
          key: const ValueKey('tactical-open-dispatches-button'),
          onPressed: dispatchAction,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFEAF4FF),
            side: BorderSide(
              color: dispatchAction == null
                  ? const Color(0xFF35506F)
                  : const Color(0xFF4B6B8F),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.open_in_new_rounded, size: 16),
          label: Text(
            'Open Dispatches',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        );
        final titleBlock = Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF4338CA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x337C3AED),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(Icons.map_rounded, size: 30, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tactical Command',
                      style: GoogleFonts.rajdhani(
                        color: const Color(0xFFEAF4FF),
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Fleet watch monitoring, responder tracking, and geofence verification',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF93A9C6),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _heroChip(
                          label: '${visibleFleetScopeHealth.length} Fleet Scope${visibleFleetScopeHealth.length == 1 ? '' : 's'}',
                          foreground: const Color(0xFF8FD1FF),
                          background: const Color(0x1A8FD1FF),
                          border: const Color(0x668FD1FF),
                        ),
                        _heroChip(
                          label: '$limitedCount Limited Watch',
                          foreground: limitedCount > 0
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF9AB1CF),
                          background: limitedCount > 0
                              ? const Color(0x1AF59E0B)
                              : const Color(0x1A94A3B8),
                          border: limitedCount > 0
                              ? const Color(0x66F59E0B)
                              : const Color(0x6694A3B8),
                        ),
                        _heroChip(
                          label: '$unavailableCount Unavailable',
                          foreground: unavailableCount > 0
                              ? const Color(0xFFF87171)
                              : const Color(0xFF9AB1CF),
                          background: unavailableCount > 0
                              ? const Color(0x1AF87171)
                              : const Color(0x1A94A3B8),
                          border: unavailableCount > 0
                              ? const Color(0x66F87171)
                              : const Color(0x6694A3B8),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF111722), Color(0xFF0D1117)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF223244)),
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [titleBlock]),
                    const SizedBox(height: 14),
                    actionButton,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleBlock,
                    const SizedBox(width: 16),
                    actionButton,
                  ],
                ),
        );
      },
    );
  }

  Widget _heroChip({
    required String label,
    required Color foreground,
    required Color background,
    required Color border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: foreground,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _tacticalAlertBanner({
    required Key key,
    required IconData icon,
    required Color accent,
    required String label,
    required String message,
    required String actionLabel,
    required VoidCallback? onPressed,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final actionButton = FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              actionLabel,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          );
          final textColumn = Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEAF4FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
          return compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: accent),
                        const SizedBox(width: 10),
                        textColumn,
                      ],
                    ),
                    const SizedBox(height: 10),
                    actionButton,
                  ],
                )
              : Row(
                  children: [
                    Icon(icon, color: accent),
                    const SizedBox(width: 10),
                    textColumn,
                    const SizedBox(width: 12),
                    actionButton,
                  ],
                );
        },
      ),
    );
  }

  Widget _fleetScopePanel({
    required BuildContext context,
    required List<VideoFleetScopeHealthView> fleetScopeHealth,
    required VideoFleetWatchActionDrilldown? activeWatchActionDrilldown,
    required void Function(VideoFleetWatchActionDrilldown drilldown)
    onOpenWatchActionDrilldown,
    required void Function(VideoFleetScopeHealthView scope)
    onOpenLatestWatchActionDetail,
    required VoidCallback onClearWatchActionDrilldown,
  }) {
    final sections = VideoFleetScopeHealthSections.fromScopes(fleetScopeHealth);
    final filteredSections = VideoFleetScopeHealthSections.fromScopes(
      orderFleetScopesForWatchAction(
        filterFleetScopesForWatchAction(
          fleetScopeHealth,
          activeWatchActionDrilldown,
        ),
        activeWatchActionDrilldown,
      ),
    );
    final primaryFocusedScope = primaryFleetScopeForWatchAction(
      filteredSections,
      activeWatchActionDrilldown,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (activeWatchActionDrilldown != null) ...[
          _watchActionFocusBanner(
            context,
            activeWatchActionDrilldown,
            focusedScope: primaryFocusedScope,
            onExtendTemporaryIdentityApproval:
                onExtendTemporaryIdentityApproval,
            onExpireTemporaryIdentityApproval:
                onExpireTemporaryIdentityApproval,
            onClear: onClearWatchActionDrilldown,
          ),
          const SizedBox(height: 8),
        ],
        VideoFleetScopeHealthPanel(
          title: 'DVR FLEET HEALTH',
          titleStyle: GoogleFonts.inter(
            color: const Color(0x66FFFFFF),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
          sectionLabelStyle: GoogleFonts.inter(
            color: const Color(0xFF8EA4C2),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.9,
          ),
          sections: filteredSections,
          activeWatchActionDrilldown: activeWatchActionDrilldown,
          summaryChildren: _fleetSummaryChips(
            sections: sections,
            activeWatchActionDrilldown: activeWatchActionDrilldown,
            onOpenWatchActionDrilldown: onOpenWatchActionDrilldown,
          ),
          actionableChildren: filteredSections.actionableScopes
              .map(
                (scope) => _fleetScopeCard(
                  scope: scope,
                  activeWatchActionDrilldown: activeWatchActionDrilldown,
                  onOpenLatestWatchActionDetail: onOpenLatestWatchActionDetail,
                ),
              )
              .toList(growable: false),
          watchOnlyChildren: filteredSections.watchOnlyScopes
              .map(
                (scope) => _fleetScopeCard(
                  scope: scope,
                  activeWatchActionDrilldown: activeWatchActionDrilldown,
                  onOpenLatestWatchActionDetail: onOpenLatestWatchActionDetail,
                ),
              )
              .toList(growable: false),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1A2B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF223244)),
          ),
          cardSpacing: 10,
          runSpacing: 10,
        ),
      ],
    );
  }

  List<_SuppressedFleetReviewEntry> _suppressedFleetReviewEntries(
    List<VideoFleetScopeHealthView> fleetScopeHealth,
  ) {
    final output = <_SuppressedFleetReviewEntry>[];
    for (final scope in fleetScopeHealth) {
      if (!scope.hasSuppressedSceneAction) {
        continue;
      }
      final intelligenceId = (scope.latestIncidentReference ?? '').trim();
      if (intelligenceId.isEmpty) {
        continue;
      }
      final review = sceneReviewByIntelligenceId[intelligenceId];
      if (review == null) {
        continue;
      }
      output.add(_SuppressedFleetReviewEntry(scope: scope, review: review));
    }
    output.sort(
      (a, b) => b.review.reviewedAtUtc.compareTo(a.review.reviewedAtUtc),
    );
    return output.take(4).toList(growable: false);
  }

  Widget _suppressedReviewPanel(List<_SuppressedFleetReviewEntry> entries) {
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
          Row(
            children: [
              Text(
                'SUPPRESSED ${videoOpsLabel.toUpperCase()} REVIEWS',
                style: GoogleFonts.inter(
                  color: const Color(0x66FFFFFF),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(width: 8),
              _topChip(
                'Internal',
                '${entries.length}',
                const Color(0xFF9AB1CF),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Recent ${videoOpsLabel.toUpperCase()} reviews ONYX held below the client-notification threshold across the active fleet.',
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: entries
                .map((entry) => _suppressedReviewCard(entry: entry))
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  Widget _suppressedReviewCard({required _SuppressedFleetReviewEntry entry}) {
    final scope = entry.scope;
    final review = entry.review;
    return Container(
      width: 280,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF101D31),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF23344C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  scope.siteName,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _clockLabel(review.reviewedAtUtc.toLocal()),
                style: GoogleFonts.robotoMono(
                  color: const Color(0xFF8EA4C2),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _topChip(
                'Action',
                review.decisionLabel.trim().isEmpty
                    ? 'Suppressed'
                    : review.decisionLabel.trim(),
                const Color(0xFFBFD7F2),
              ),
              if ((scope.latestCameraLabel ?? '').trim().isNotEmpty)
                _topChip(
                  'Camera',
                  scope.latestCameraLabel!.trim(),
                  const Color(0xFF8FD1FF),
                ),
              _topChip(
                'Posture',
                review.postureLabel.trim(),
                const Color(0xFF86EFAC),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            review.decisionSummary.trim().isEmpty
                ? 'Suppressed because the activity remained below threshold.'
                : review.decisionSummary.trim(),
            style: GoogleFonts.inter(
              color: const Color(0xFFD9E7F7),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Scene review: ${review.summary.trim()}',
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fleetScopeCard({
    required VideoFleetScopeHealthView scope,
    required VideoFleetWatchActionDrilldown? activeWatchActionDrilldown,
    required void Function(VideoFleetScopeHealthView scope)
    onOpenLatestWatchActionDetail,
  }) {
    final statusColor = switch (scope.statusLabel.toUpperCase()) {
      'LIVE' => const Color(0xFF86EFAC),
      'ACTIVE WATCH' => const Color(0xFF8FD1FF),
      'LIMITED WATCH' => const Color(0xFFFBBF24),
      'WATCH READY' => const Color(0xFFFDE68A),
      _ => const Color(0xFF9AB1CF),
    };
    final watchColor = scope.watchLabel == 'LIMITED'
        ? const Color(0xFFFBBF24)
        : const Color(0xFF8FD1FF);
    final phaseColor = (scope.watchWindowStateLabel ?? '').contains('LIMITED')
        ? const Color(0xFFFBBF24)
        : scope.watchWindowStateLabel == 'IN WINDOW'
        ? const Color(0xFF86EFAC)
        : const Color(0xFFFDE68A);
    final primaryOpenFleetScope = scope.hasIncidentContext
        ? (onOpenFleetTacticalScope ?? onOpenFleetDispatchScope)
        : null;
    return VideoFleetScopeHealthCard(
      title: scope.siteName,
      endpointLabel: scope.endpointLabel,
      lastSeenLabel: ': ${scope.lastSeenLabel}',
      titleStyle: GoogleFonts.inter(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      endpointStyle: GoogleFonts.inter(
        color: const Color(0xFF8EA4C2),
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
      lastSeenStyle: GoogleFonts.inter(
        color: const Color(0xFF9AB1CF),
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      statusDetailStyle: GoogleFonts.inter(
        color: const Color(0xFFFDE68A),
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
      noteStyle: GoogleFonts.inter(
        color: const Color(0xFF9AB1CF),
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
      latestStyle: GoogleFonts.inter(
        color: const Color(0xFFD9E7F7),
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      primaryChips: [
        if ((scope.operatorOutcomeLabel ?? '').trim().isNotEmpty)
          _topChip('Cue', scope.operatorOutcomeLabel!, const Color(0xFF67E8F9)),
        if ((scope.operatorOutcomeLabel ?? '').trim().isEmpty &&
            (scope.lastRecoveryLabel ?? '').trim().isNotEmpty)
          _topChip(
            'Recovery',
            scope.lastRecoveryLabel!,
            const Color(0xFF86EFAC),
          ),
        if (scope.hasWatchActivationGap)
          _topChip(
            'Gap',
            scope.watchActivationGapLabel!,
            const Color(0xFFFCA5A5),
          ),
        if (!scope.hasIncidentContext)
          _topChip('Context', 'Pending', const Color(0xFFFDE68A)),
        if (scope.identityPolicyChipValue != null)
          _topChip(
            'Identity',
            scope.identityPolicyChipValue!,
            identityPolicyAccentColorForScope(scope),
          ),
        if (scope.clientDecisionChipValue != null)
          _topChip(
            'Client',
            scope.clientDecisionChipValue!,
            scope.clientDecisionChipValue == 'Approved'
                ? const Color(0xFF86EFAC)
                : scope.clientDecisionChipValue == 'Review'
                ? const Color(0xFFFDE68A)
                : const Color(0xFFFCA5A5),
          ),
        _topChip('Status', scope.statusLabel, statusColor),
        _topChip('Watch', scope.watchLabel, watchColor),
        _topChip(
          'Freshness',
          scope.freshnessLabel,
          _fleetFreshnessColor(scope),
        ),
        _topChip('Events 6h', '${scope.recentEvents}', const Color(0xFF9AB1CF)),
      ],
      secondaryChips: [
        if (scope.watchWindowLabel != null)
          _topChip('Window', scope.watchWindowLabel!, const Color(0xFF86EFAC)),
        if (scope.watchWindowStateLabel != null)
          _topChip('Phase', scope.watchWindowStateLabel!, phaseColor),
        if (scope.latestRiskScore != null)
          _topChip(
            'Risk',
            _fleetRiskLabel(scope.latestRiskScore!),
            _fleetRiskColor(scope.latestRiskScore!),
          ),
        if (scope.latestCameraLabel != null)
          _topChip('Camera', scope.latestCameraLabel!, const Color(0xFF9AB1CF)),
      ],
      actionChildren: [
        if (onRecoverFleetWatchScope != null && scope.hasWatchActivationGap)
          _fleetActionButton(
            label: 'Resync',
            color: const Color(0xFFFCA5A5),
            onPressed: () =>
                onRecoverFleetWatchScope!.call(scope.clientId, scope.siteId),
          ),
        if (onOpenFleetTacticalScope != null && scope.hasIncidentContext)
          _fleetActionButton(
            label: 'Tactical',
            color: const Color(0xFF8FD1FF),
            onPressed: () => onOpenFleetTacticalScope!.call(
              scope.clientId,
              scope.siteId,
              scope.latestIncidentReference,
            ),
          ),
        if (onOpenFleetDispatchScope != null && scope.hasIncidentContext)
          _fleetActionButton(
            label: 'Dispatch',
            color: const Color(0xFFFDE68A),
            onPressed: () => onOpenFleetDispatchScope!.call(
              scope.clientId,
              scope.siteId,
              scope.latestIncidentReference,
            ),
          ),
      ],
      statusDetailText: scope.limitedWatchStatusDetailText,
      noteText: scope.noteText,
      latestText: prominentLatestTextForWatchAction(
        scope,
        activeWatchActionDrilldown,
      ),
      onLatestTap: () => onOpenLatestWatchActionDetail(scope),
      onTap: primaryOpenFleetScope == null
          ? null
          : () => primaryOpenFleetScope.call(
              scope.clientId,
              scope.siteId,
              scope.latestIncidentReference,
            ),
      decoration: BoxDecoration(
        color: const Color(0xFF101D31),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF23344C)),
      ),
      constraints: const BoxConstraints(minWidth: 230, maxWidth: 320),
    );
  }

  List<Widget> _fleetSummaryChips({
    required VideoFleetScopeHealthSections sections,
    required VideoFleetWatchActionDrilldown? activeWatchActionDrilldown,
    required void Function(VideoFleetWatchActionDrilldown drilldown)
    onOpenWatchActionDrilldown,
  }) {
    return [
      _topChip('Active', '${sections.activeCount}', const Color(0xFF8FD1FF)),
      _topChip(
        'Limited',
        '${sections.limitedCount}',
        const Color(0xFFFBBF24),
        isActive:
            activeWatchActionDrilldown ==
            VideoFleetWatchActionDrilldown.limited,
        onTap: sections.limitedCount > 0
            ? () => onOpenWatchActionDrilldown(
                VideoFleetWatchActionDrilldown.limited,
              )
            : null,
      ),
      _topChip('Gap', '${sections.gapCount}', const Color(0xFFFCA5A5)),
      _topChip(
        'High Risk',
        '${sections.highRiskCount}',
        const Color(0xFFFCA5A5),
      ),
      _topChip(
        'Recovered 6h',
        '${sections.recoveredCount}',
        const Color(0xFF86EFAC),
      ),
      _topChip(
        'Suppressed',
        '${sections.suppressedCount}',
        const Color(0xFF9AB1CF),
      ),
      _topChip(
        'Alerts',
        '${sections.alertActionCount}',
        const Color(0xFF67E8F9),
        isActive:
            activeWatchActionDrilldown == VideoFleetWatchActionDrilldown.alerts,
        onTap: sections.alertActionCount > 0
            ? () => onOpenWatchActionDrilldown(
                VideoFleetWatchActionDrilldown.alerts,
              )
            : null,
      ),
      _topChip(
        'Repeat',
        '${sections.repeatActionCount}',
        const Color(0xFFFDE68A),
        isActive:
            activeWatchActionDrilldown == VideoFleetWatchActionDrilldown.repeat,
        onTap: sections.repeatActionCount > 0
            ? () => onOpenWatchActionDrilldown(
                VideoFleetWatchActionDrilldown.repeat,
              )
            : null,
      ),
      _topChip(
        'Escalated',
        '${sections.escalationActionCount}',
        const Color(0xFFFCA5A5),
        isActive:
            activeWatchActionDrilldown ==
            VideoFleetWatchActionDrilldown.escalated,
        onTap: sections.escalationActionCount > 0
            ? () => onOpenWatchActionDrilldown(
                VideoFleetWatchActionDrilldown.escalated,
              )
            : null,
      ),
      _topChip(
        'Filtered',
        '${sections.suppressedActionCount}',
        const Color(0xFF9AB1CF),
        isActive:
            activeWatchActionDrilldown ==
            VideoFleetWatchActionDrilldown.filtered,
        onTap: sections.suppressedActionCount > 0
            ? () => onOpenWatchActionDrilldown(
                VideoFleetWatchActionDrilldown.filtered,
              )
            : null,
      ),
      _topChip(
        'Flagged ID',
        '${sections.flaggedIdentityCount}',
        VideoFleetWatchActionDrilldown.flaggedIdentity.accentColor,
        isActive:
            activeWatchActionDrilldown ==
            VideoFleetWatchActionDrilldown.flaggedIdentity,
        onTap: sections.flaggedIdentityCount > 0
            ? () => onOpenWatchActionDrilldown(
                VideoFleetWatchActionDrilldown.flaggedIdentity,
              )
            : null,
      ),
      _topChip(
        'Temporary ID',
        '${sections.temporaryIdentityCount}',
        temporaryIdentityAccentColorForScopes(fleetScopeHealth),
        isActive:
            activeWatchActionDrilldown ==
            VideoFleetWatchActionDrilldown.temporaryIdentity,
        onTap: sections.temporaryIdentityCount > 0
            ? () => onOpenWatchActionDrilldown(
                VideoFleetWatchActionDrilldown.temporaryIdentity,
              )
            : null,
      ),
      _topChip(
        'Allowed ID',
        '${sections.allowlistedIdentityCount}',
        VideoFleetWatchActionDrilldown.allowlistedIdentity.accentColor,
        isActive:
            activeWatchActionDrilldown ==
            VideoFleetWatchActionDrilldown.allowlistedIdentity,
        onTap: sections.allowlistedIdentityCount > 0
            ? () => onOpenWatchActionDrilldown(
                VideoFleetWatchActionDrilldown.allowlistedIdentity,
              )
            : null,
      ),
      _topChip('Stale', '${sections.staleCount}', const Color(0xFFFDE68A)),
      _topChip(
        'No Incident',
        '${sections.noIncidentCount}',
        const Color(0xFF9AB1CF),
      ),
    ];
  }

  Widget _fleetActionButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.45)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
      ),
      child: Text(label),
    );
  }

  Color _fleetRiskColor(int score) {
    if (score >= 85) {
      return const Color(0xFFFCA5A5);
    }
    if (score >= 70) {
      return const Color(0xFFFDE68A);
    }
    if (score >= 40) {
      return const Color(0xFF93C5FD);
    }
    return const Color(0xFF9AB1CF);
  }

  String _fleetRiskLabel(int score) {
    if (score >= 85) {
      return 'Critical';
    }
    if (score >= 70) {
      return 'High';
    }
    if (score >= 40) {
      return 'Watch';
    }
    return 'Routine';
  }

  Color _fleetFreshnessColor(VideoFleetScopeHealthView scope) {
    return switch (scope.freshnessLabel) {
      'Fresh' => const Color(0xFF86EFAC),
      'Recent' => const Color(0xFF8FD1FF),
      'Stale' => const Color(0xFFFCA5A5),
      'Quiet' => const Color(0xFFFDE68A),
      _ => const Color(0xFF9AB1CF),
    };
  }

  Widget _topBar({
    required int geofenceAlerts,
    required int sosAlerts,
    required String mode,
    required String focusReference,
    required _FocusLinkState focusState,
    required String scopeClientId,
    required String scopeSiteId,
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
                  '${_focusStateLabel(focusState)} $focusReference',
                  _focusStateColor(focusState),
                ),
              if (scopeClientId.isNotEmpty && scopeSiteId.isNotEmpty)
                _topChip(
                  'Scope',
                  '$scopeClientId/$scopeSiteId',
                  const Color(0xFF8FD1FF),
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

  Widget _scopeFocusBanner({
    required String clientId,
    required String siteId,
    required bool hasFleetScope,
  }) {
    final scopeLabel = siteId.trim().isEmpty
        ? '$clientId/all sites'
        : '$clientId/$siteId';
    return Container(
      key: const ValueKey('tactical-scope-banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0x141C3C57),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x4435506F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Scope focus active',
            style: GoogleFonts.inter(
              color: const Color(0xFF8FD1FF),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            scopeLabel,
            style: GoogleFonts.inter(
              color: const Color(0xFFEAF4FF),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasFleetScope
                ? (siteId.trim().isEmpty
                      ? 'Tactical is focused on this client-wide DVR roll-up.'
                      : 'Tactical is focused on this exact DVR lane.')
                : (siteId.trim().isEmpty
                      ? 'Tactical is locked to this client lane. Fleet DVR roll-up will appear once that client scope is linked.'
                      : 'Tactical is locked to this exact lane. Fleet DVR roll-up will appear once that scope is linked.'),
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontSize: 11,
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
    required _FocusLinkState focusState,
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
                              color: _focusStateColor(
                                focusState,
                              ).withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _focusStateColor(
                                  focusState,
                                ).withValues(alpha: 0.66),
                              ),
                            ),
                            child: Text(
                              'FOCUS ${_focusStateLabel(focusState).toUpperCase()} • $focusReference',
                              style: GoogleFonts.inter(
                                color: _focusStateTextColor(focusState),
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

  _FocusLinkState _resolveFocusLinkState({
    required String focusReference,
    required List<VideoFleetScopeHealthView> visibleFleetScopeHealth,
    required List<DispatchEvent> events,
  }) {
    final normalizedFocusReference = focusReference.trim();
    if (normalizedFocusReference.isEmpty) {
      return _FocusLinkState.none;
    }
    final exactLinked = _markers.any(
      (marker) =>
          marker.type == _MarkerType.incident &&
          marker.id == normalizedFocusReference,
    );
    if (exactLinked) {
      return _FocusLinkState.exact;
    }
    final scopeBacked = visibleFleetScopeHealth.any(
      (scope) =>
          (scope.latestIncidentReference ?? '').trim() ==
          normalizedFocusReference,
    );
    if (scopeBacked) {
      return _FocusLinkState.scopeBacked;
    }
    final focusScope = _scopeForFocusReference(
      normalizedFocusReference,
      events,
    );
    if (focusScope != null &&
        visibleFleetScopeHealth.any(
          (scope) =>
              scope.clientId.trim() == focusScope.clientId &&
              scope.siteId.trim() == focusScope.siteId,
        )) {
      return _FocusLinkState.scopeBacked;
    }
    return _FocusLinkState.seeded;
  }

  ({String clientId, String siteId})? _scopeForFocusReference(
    String focusReference,
    List<DispatchEvent> events,
  ) {
    final normalizedReference = focusReference.trim();
    if (normalizedReference.isEmpty) {
      return null;
    }
    DispatchEvent? matched;
    for (final event in events) {
      final dispatchId = switch (event) {
        DecisionCreated value => value.dispatchId.trim(),
        ResponseArrived value => value.dispatchId.trim(),
        PartnerDispatchStatusDeclared value => value.dispatchId.trim(),
        ExecutionCompleted value => value.dispatchId.trim(),
        ExecutionDenied value => value.dispatchId.trim(),
        IncidentClosed value => value.dispatchId.trim(),
        _ => '',
      };
      final intelligenceId = event is IntelligenceReceived
          ? event.intelligenceId.trim()
          : '';
      if (event.eventId.trim() != normalizedReference &&
          dispatchId != normalizedReference &&
          intelligenceId != normalizedReference) {
        continue;
      }
      if (matched == null || event.occurredAt.isAfter(matched.occurredAt)) {
        matched = event;
      }
    }
    if (matched == null) {
      return null;
    }
    final clientId = switch (matched) {
      DecisionCreated event => event.clientId.trim(),
      ResponseArrived event => event.clientId.trim(),
      PartnerDispatchStatusDeclared event => event.clientId.trim(),
      ExecutionCompleted event => event.clientId.trim(),
      ExecutionDenied event => event.clientId.trim(),
      IncidentClosed event => event.clientId.trim(),
      IntelligenceReceived event => event.clientId.trim(),
      _ => '',
    };
    final siteId = switch (matched) {
      DecisionCreated event => event.siteId.trim(),
      ResponseArrived event => event.siteId.trim(),
      PartnerDispatchStatusDeclared event => event.siteId.trim(),
      ExecutionCompleted event => event.siteId.trim(),
      ExecutionDenied event => event.siteId.trim(),
      IncidentClosed event => event.siteId.trim(),
      IntelligenceReceived event => event.siteId.trim(),
      _ => '',
    };
    if (clientId.isEmpty || siteId.isEmpty) {
      return null;
    }
    return (clientId: clientId, siteId: siteId);
  }

  String _focusStateLabel(_FocusLinkState state) {
    return switch (state) {
      _FocusLinkState.exact => 'Linked',
      _FocusLinkState.scopeBacked => 'Scope-backed',
      _FocusLinkState.seeded => 'Seeded',
      _FocusLinkState.none => 'Idle',
    };
  }

  Color _focusStateColor(_FocusLinkState state) {
    return switch (state) {
      _FocusLinkState.exact => const Color(0xFF86EFAC),
      _FocusLinkState.scopeBacked => const Color(0xFF8FD1FF),
      _FocusLinkState.seeded => const Color(0xFFFACC15),
      _FocusLinkState.none => const Color(0xFF9AB1CF),
    };
  }

  Color _focusStateTextColor(_FocusLinkState state) {
    return switch (state) {
      _FocusLinkState.exact => const Color(0xFFCCFFE8),
      _FocusLinkState.scopeBacked => const Color(0xFFE0F2FF),
      _FocusLinkState.seeded => const Color(0xFFFDE68A),
      _FocusLinkState.none => const Color(0xFFCAD6E5),
    };
  }

  List<_MapMarker> _resolvedMarkers({
    required String focusReference,
    required _FocusLinkState focusState,
  }) {
    if (focusReference.isEmpty || focusState != _FocusLinkState.seeded) {
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

  Widget _topChip(
    String label,
    String value,
    Color color, {
    VoidCallback? onTap,
    bool isActive = false,
  }) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? color.withValues(alpha: 0.16)
            : const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: isActive ? 0.95 : 0.55),
        ),
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
    if (onTap == null) {
      return chip;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: chip,
    );
  }

  Widget _watchActionFocusBanner(
    BuildContext context,
    VideoFleetWatchActionDrilldown active, {
    required VideoFleetScopeHealthView? focusedScope,
    required Future<String> Function(VideoFleetScopeHealthView scope)?
    onExtendTemporaryIdentityApproval,
    required Future<String> Function(VideoFleetScopeHealthView scope)?
    onExpireTemporaryIdentityApproval,
    required VoidCallback onClear,
  }) {
    final canMutateTemporaryApproval =
        active == VideoFleetWatchActionDrilldown.temporaryIdentity &&
        focusedScope != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: active.focusBannerBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: active.focusBannerBorderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active.focusBannerTitle,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEAF4FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  focusDetailForWatchAction(fleetScopeHealth, active),
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9AB1CF),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (canMutateTemporaryApproval &&
                  onExtendTemporaryIdentityApproval != null)
                TextButton(
                  onPressed: () async {
                    final message = await onExtendTemporaryIdentityApproval(
                      focusedScope,
                    );
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(message)));
                  },
                  child: Text(
                    'Extend 2h',
                    style: GoogleFonts.inter(
                      color: active.focusBannerActionColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (canMutateTemporaryApproval &&
                  onExpireTemporaryIdentityApproval != null)
                TextButton(
                  onPressed: () async {
                    final confirmed =
                        await _confirmExpireTemporaryIdentityApproval(
                          context,
                          focusedScope,
                        );
                    if (!confirmed) {
                      return;
                    }
                    final message = await onExpireTemporaryIdentityApproval(
                      focusedScope,
                    );
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(message)));
                  },
                  child: Text(
                    'Expire now',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFFCA5A5),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              TextButton(
                onPressed: onClear,
                child: Text(
                  'Clear',
                  style: GoogleFonts.inter(
                    color: active.focusBannerActionColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmExpireTemporaryIdentityApproval(
    BuildContext context,
    VideoFleetScopeHealthView scope,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF30363D)),
          ),
          title: Text(
            'Expire Temporary Approval?',
            style: GoogleFonts.inter(
              color: const Color(0xFFEAF4FF),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'This immediately removes the temporary identity approval for ${scope.siteName}. Future matches will no longer be treated as approved.',
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: const Color(0xFF9AB1CF),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB91C1C),
                foregroundColor: const Color(0xFFEAF4FF),
              ),
              child: Text(
                'Expire now',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
    return confirmed == true;
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
