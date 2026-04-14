import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'
    show
        FlutterMap,
        MapController,
        MapOptions,
        Marker,
        MarkerLayer,
        TileLayer,
        LatLngBounds;
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../application/admin/admin_directory_service.dart';
import '../application/monitoring_scene_review_store.dart';
import '../domain/events/decision_created.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/events/execution_completed.dart';
import '../domain/events/execution_denied.dart';
import '../domain/events/incident_closed.dart';
import '../domain/events/intelligence_received.dart';
import '../domain/events/partner_dispatch_status_declared.dart';
import '../domain/events/response_arrived.dart';
import '../domain/guard/guard_position_summary.dart';
import 'layout_breakpoints.dart';
import 'onyx_surface.dart';
import 'theme/onyx_design_tokens.dart';
import 'track_overview_board.dart';
import 'video_fleet_scope_health_card.dart';
import 'video_fleet_scope_health_panel.dart';
import 'video_fleet_scope_health_sections.dart';
import 'video_fleet_scope_health_view.dart';

enum _MarkerType { guard, vehicle, incident, site }

enum _MarkerStatus { active, responding, staticMarker, sos }

enum _FenceStatus { safe, breach, stationary }

enum _FocusLinkState { none, exact, scopeBacked, seeded }

enum _TacticalMapFilter { all, responding, incidents }

enum _VerificationQueueTab { anomalies, matches, assets }

const _tacticalSurfaceColor = OnyxDesignTokens.cardSurface;
const _tacticalAltSurfaceColor = OnyxDesignTokens.backgroundSecondary;
const _tacticalBorderColor = OnyxDesignTokens.borderSubtle;
const _tacticalStrongBorderColor = OnyxDesignTokens.borderStrong;
const _tacticalTitleColor = OnyxDesignTokens.textPrimary;
const _tacticalBodyColor = OnyxDesignTokens.textSecondary;
const _tacticalMutedColor = OnyxDesignTokens.textMuted;
const _tacticalAccentSky = OnyxDesignTokens.accentSky;
const _tacticalDesktopOverviewMinWidth = 820.0;
const _tacticalDetailedWorkspaceMinWidth = 1080.0;
const _tacticalDetailedWorkspaceMinHeight = 760.0;

class _MapMarker {
  final String id;
  final _MarkerType type;
  final LatLng point;
  final String label;
  final _MarkerStatus status;
  final String? lastPing;
  final int? battery;
  final String? eta;
  final String? priority;

  const _MapMarker({
    required this.id,
    required this.type,
    required this.point,
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
  final LatLng point;
  final _FenceStatus status;
  final int? stationaryTime;

  const _SafetyGeofence({
    required this.centerId,
    required this.point,
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

class _TacticalCommandReceipt {
  final String label;
  final String headline;
  final String detail;
  final Color accent;

  const _TacticalCommandReceipt({
    required this.label,
    required this.headline,
    required this.detail,
    required this.accent,
  });
}

class TacticalEvidenceReturnReceipt {
  final String auditId;
  final String label;
  final String headline;
  final String detail;
  final Color accent;

  const TacticalEvidenceReturnReceipt({
    required this.auditId,
    required this.label,
    required this.headline,
    required this.detail,
    required this.accent,
  });
}

class _TacticalDetailedWorkspaceHost extends StatefulWidget {
  final Widget Function(
    BuildContext context,
    bool showDetailedWorkspace,
    ValueChanged<bool> setDetailedWorkspace,
    void Function(
      String incidentReference,
      ValueChanged<String>? onConsume,
    )
    consumeAgentReturnIncidentReferenceOnce,
    void Function(
      TacticalEvidenceReturnReceipt receipt,
      ValueChanged<String>? onConsume,
    )
    consumeEvidenceReturnReceiptOnce,
    GlobalKey fleetPanelKey,
    GlobalKey suppressedPanelKey,
    MapController mapController,
  )
  builder;

  const _TacticalDetailedWorkspaceHost({required this.builder});

  @override
  State<_TacticalDetailedWorkspaceHost> createState() =>
      _TacticalDetailedWorkspaceHostState();
}

class _TacticalDetailedWorkspaceHostState
    extends State<_TacticalDetailedWorkspaceHost> {
  final GlobalKey _fleetPanelKey = GlobalKey();
  final GlobalKey _suppressedPanelKey = GlobalKey();
  final MapController _mapController = MapController();
  bool _showDetailedWorkspace = false;
  String? _lastConsumedAgentReturnIncidentReference;
  String? _lastConsumedEvidenceReturnAuditId;

  void _setDetailedWorkspace(bool value) {
    if (_showDetailedWorkspace == value) {
      return;
    }
    setState(() {
      _showDetailedWorkspace = value;
    });
  }

  void _consumeAgentReturnIncidentReferenceOnce(
    String incidentReference,
    ValueChanged<String>? onConsume,
  ) {
    final normalizedReference = incidentReference.trim();
    if (normalizedReference.isEmpty ||
        normalizedReference == _lastConsumedAgentReturnIncidentReference) {
      return;
    }
    _lastConsumedAgentReturnIncidentReference = normalizedReference;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      onConsume?.call(normalizedReference);
    });
  }

  void _consumeEvidenceReturnReceiptOnce(
    TacticalEvidenceReturnReceipt receipt,
    ValueChanged<String>? onConsume,
  ) {
    final auditId = receipt.auditId.trim();
    if (auditId.isEmpty || auditId == _lastConsumedEvidenceReturnAuditId) {
      return;
    }
    _lastConsumedEvidenceReturnAuditId = auditId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      onConsume?.call(auditId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      _showDetailedWorkspace,
      _setDetailedWorkspace,
      _consumeAgentReturnIncidentReferenceOnce,
      _consumeEvidenceReturnReceiptOnce,
      _fleetPanelKey,
      _suppressedPanelKey,
      _mapController,
    );
  }
}

class TacticalPage extends StatelessWidget {
  final List<DispatchEvent> events;
  final String focusIncidentReference;
  final String? agentReturnIncidentReference;
  final ValueChanged<String>? onConsumeAgentReturnIncidentReference;
  final TacticalEvidenceReturnReceipt? evidenceReturnReceipt;
  final ValueChanged<String>? onConsumeEvidenceReturnReceipt;
  final String? initialScopeClientId;
  final String? initialScopeSiteId;
  final String videoOpsLabel;
  final String cctvOpsReadiness;
  final String cctvOpsDetail;
  final String cctvProvider;
  final String cctvCapabilitySummary;
  final String cctvRecentSignalSummary;
  final List<VideoFleetScopeHealthView> fleetScopeHealth;
  final List<GuardPositionSummary> guardPositions;
  final List<AdminDirectorySiteRow> siteMarkers;
  final bool supabaseReady;
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
  final ValueChanged<String>? onOpenAgentForIncident;
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
    this.agentReturnIncidentReference,
    this.onConsumeAgentReturnIncidentReference,
    this.evidenceReturnReceipt,
    this.onConsumeEvidenceReturnReceipt,
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
    this.guardPositions = const <GuardPositionSummary>[],
    this.siteMarkers = const <AdminDirectorySiteRow>[],
    this.supabaseReady = true,
    this.sceneReviewByIntelligenceId =
        const <String, MonitoringSceneReviewRecord>{},
    this.onOpenFleetTacticalScope,
    this.onOpenFleetDispatchScope,
    this.onOpenAgentForIncident,
    this.onRecoverFleetWatchScope,
    this.onExtendTemporaryIdentityApproval,
    this.onExpireTemporaryIdentityApproval,
    this.initialWatchActionDrilldown,
    this.onWatchActionDrilldownChanged,
  });

  static const LatLng _johannesburgCenter = LatLng(-26.2041, 28.0473);

  static const List<_MapMarker> _markers = [
    _MapMarker(
      id: 'GUARD-ECHO-3',
      type: _MarkerType.guard,
      point: LatLng(-26.1068, 28.0559),
      label: 'Echo-3',
      status: _MarkerStatus.active,
      lastPing: '45s ago',
      battery: 82,
    ),
    _MapMarker(
      id: 'GUARD-ALPHA-1',
      type: _MarkerType.guard,
      point: LatLng(-26.1084, 28.0572),
      label: 'Alpha-1',
      status: _MarkerStatus.sos,
      lastPing: '12s ago',
      battery: 18,
    ),
    _MapMarker(
      id: 'VEHICLE-R12',
      type: _MarkerType.vehicle,
      point: LatLng(-26.1074, 28.0601),
      label: 'Vehicle R-12',
      status: _MarkerStatus.responding,
      eta: 'ETA 4m 12s',
    ),
    _MapMarker(
      id: 'SITE-NORTH',
      type: _MarkerType.site,
      point: LatLng(-26.1098, 28.0586),
      label: 'Sandton North',
      status: _MarkerStatus.staticMarker,
    ),
    _MapMarker(
      id: 'INC-8829-QX',
      type: _MarkerType.incident,
      point: LatLng(-26.1089, 28.0591),
      label: 'INC-8829-QX',
      status: _MarkerStatus.sos,
      priority: 'P1-CRITICAL',
    ),
  ];

  static const List<_SafetyGeofence> _geofences = [
    _SafetyGeofence(
      centerId: 'Echo-3',
      point: LatLng(-26.1068, 28.0559),
      status: _FenceStatus.safe,
    ),
    _SafetyGeofence(
      centerId: 'Alpha-1',
      point: LatLng(-26.1084, 28.0572),
      status: _FenceStatus.breach,
    ),
    _SafetyGeofence(
      centerId: 'Delta-6',
      point: LatLng(-26.1096, 28.0564),
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
    return _TacticalDetailedWorkspaceHost(
      builder: (
        context,
        showDetailedWorkspace,
        setDetailedWorkspace,
        consumeAgentReturnIncidentReferenceOnce,
        consumeEvidenceReturnReceiptOnce,
        fleetPanelKey,
        suppressedPanelKey,
        mapController,
      ) {
        final normalizedAgentReturnReference =
            (agentReturnIncidentReference ?? '').trim();
        var commandReceipt = _initialCommandReceipt(
          normalizedAgentReturnReference,
          evidenceReturnReceipt,
        );
        VideoFleetWatchActionDrilldown? activeWatchActionDrilldown =
            initialWatchActionDrilldown;
        var mapZoom = 1.0;
        var mapFilter = _TacticalMapFilter.all;
        String? selectedMarkerId = focusIncidentReference.trim().isEmpty
            ? null
            : focusIncidentReference.trim();
        var verificationQueueTab = _VerificationQueueTab.anomalies;
        final now = DateTime.now();
        return StatefulBuilder(
          builder: (context, setState) {
            if (normalizedAgentReturnReference.isNotEmpty) {
              consumeAgentReturnIncidentReferenceOnce(
                normalizedAgentReturnReference,
                onConsumeAgentReturnIncidentReference,
              );
            }
            final evidenceReceipt = evidenceReturnReceipt;
            if (evidenceReceipt != null) {
              consumeEvidenceReturnReceiptOnce(
                evidenceReceipt,
                onConsumeEvidenceReturnReceipt,
              );
            }
            var wide = false;
            final contentPadding = const EdgeInsets.fromLTRB(16, 16, 16, 16);
            void showTacticalFeedback(
              String message, {
              String label = 'VERIFICATION RAIL',
              String? detail,
              Color accent = _tacticalAccentSky,
            }) {
              if (wide) {
                setState(() {
                  commandReceipt = _TacticalCommandReceipt(
                    label: label,
                    headline: message,
                    detail:
                        detail ??
                        'The latest tactical workflow update stays pinned in the verification rail while the active map board remains in focus.',
                    accent: accent,
                  );
                });
                return;
              }
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(message)));
            }

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
              scopeClientId: scopeClientId,
              scopeSiteId: scopeSiteId,
            );
            final mapBounds = _mapBoundsForScope(
              markers: markers,
              scopeClientId: scopeClientId,
              scopeSiteId: scopeSiteId,
            );
            final visibleMarkers = _filteredMarkers(markers, mapFilter);
            if (selectedMarkerId == null ||
                !visibleMarkers.any(
                  (marker) => marker.id == selectedMarkerId,
                )) {
              selectedMarkerId = _preferredMarker(
                visibleMarkers,
                focusReference: focusReference,
              )?.id;
            }
            final activeMarker = _activeMarkerFor(
              markers: visibleMarkers,
              selectedMarkerId: selectedMarkerId,
              focusReference: focusReference,
            );
            final geofenceAlerts = _geofences
                .where(
                  (fence) =>
                      fence.status == _FenceStatus.breach ||
                      (fence.status == _FenceStatus.stationary &&
                          (fence.stationaryTime ?? 0) > 120),
                )
                .length;
            final sosAlerts = markers
                .where(
                  (marker) =>
                      marker.status == _MarkerStatus.sos &&
                      marker.type == _MarkerType.guard,
                )
                .length;
            final connectingToLiveData = !supabaseReady &&
                guardPositions.isEmpty &&
                siteMarkers.isEmpty;
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
            final headerAgentAction = _headerAgentAction(
              visibleFleetScopeHealth: visibleFleetScopeHealth,
              focusReference: focusReference,
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

            void focusFilteredSuppressedReviews() {
              if (activeWatchActionDrilldown !=
                  VideoFleetWatchActionDrilldown.filtered) {
                setActiveWatchActionDrilldown(
                  VideoFleetWatchActionDrilldown.filtered,
                );
              }
              final targetContext = suppressedPanelKey.currentContext;
              if (targetContext == null) {
                return;
              }
              Scrollable.ensureVisible(
                targetContext,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
              );
            }

            Widget buildWideWorkspace({required bool embedScroll}) {
              final workspaceBanner = _tacticalWorkspaceStatusBanner(
                activeMarker: activeMarker,
                activeFilter: mapFilter,
                focusReference: focusReference,
                focusState: focusState,
                verificationQueueTab: verificationQueueTab,
                headerDispatchAction: headerDispatchAction,
                headerAgentAction: headerAgentAction,
                onCycleFilter: () {
                  setState(() {
                    mapFilter = switch (mapFilter) {
                      _TacticalMapFilter.all => _TacticalMapFilter.responding,
                      _TacticalMapFilter.responding =>
                        _TacticalMapFilter.incidents,
                      _TacticalMapFilter.incidents => _TacticalMapFilter.all,
                    };
                  });
                },
                onCenterActive: () {
                  final targetMarker = _preferredMarker(
                    visibleMarkers,
                    focusReference: focusReference,
                  );
                  if (targetMarker == null) {
                    return;
                  }
                  setState(() {
                    selectedMarkerId = targetMarker.id;
                  });
                },
                onSetQueueTab: (_VerificationQueueTab value) {
                  setState(() {
                    verificationQueueTab = value;
                  });
                },
                onOpenFleetStatus: visibleFleetScopeHealth.isEmpty
                    ? null
                    : () {
                        final targetContext = fleetPanelKey.currentContext;
                        if (targetContext == null) {
                          return;
                        }
                        Scrollable.ensureVisible(
                          targetContext,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                        );
                      },
                summaryOnly: true,
                shellless: true,
              );

              Widget railChild() {
                final content = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _heroHeader(
                      dispatchAction: headerDispatchAction,
                      agentAction: headerAgentAction,
                      visibleFleetScopeHealth: visibleFleetScopeHealth,
                      workspaceBanner: workspaceBanner,
                    ),
                    const SizedBox(height: 5),
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
                      const SizedBox(height: 5),
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
                      const SizedBox(height: 5),
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
                      compactDetails: true,
                    ),
                    if (hasScopeFocus) ...[
                      const SizedBox(height: 5),
                      _scopeFocusBanner(
                        clientId: scopeClientId,
                        siteId: scopeSiteId,
                        hasFleetScope: visibleFleetScopeHealth.isNotEmpty,
                      ),
                    ],
                  ],
                );
                if (!embedScroll) {
                  return content;
                }
                return SingleChildScrollView(primary: false, child: content);
              }

              Widget mapBoardChild() {
                final content = _mapPanel(
                  buildContext: context,
                  markers: visibleMarkers,
                  mapBounds: mapBounds,
                  activeMarker: activeMarker,
                  zoom: mapZoom,
                  mapController: mapController,
                  activeFilter: mapFilter,
                  activeQueueTab: verificationQueueTab,
                  onSelectMarker: (markerId) {
                    setState(() {
                      selectedMarkerId = markerId;
                    });
                  },
                  onZoomIn: () {
                    final nextZoom = (mapZoom + 0.12).clamp(1.0, 1.6);
                    setState(() {
                      mapZoom = nextZoom;
                    });
                    mapController.move(
                      activeMarker?.point ?? _mapBoundsCenter(mapBounds),
                      _mapZoomLevelForBounds(
                        mapBounds: mapBounds,
                        zoomScale: nextZoom,
                      ),
                    );
                  },
                  onZoomOut: () {
                    final nextZoom = (mapZoom - 0.12).clamp(1.0, 1.6);
                    setState(() {
                      mapZoom = nextZoom;
                    });
                    mapController.move(
                      activeMarker?.point ?? _mapBoundsCenter(mapBounds),
                      _mapZoomLevelForBounds(
                        mapBounds: mapBounds,
                        zoomScale: nextZoom,
                      ),
                    );
                  },
                  onCenterActive: () {
                    final targetMarker = _preferredMarker(
                      visibleMarkers,
                      focusReference: focusReference,
                    );
                    if (targetMarker == null) {
                      return;
                    }
                    setState(() {
                      selectedMarkerId = targetMarker.id;
                    });
                  },
                  onCycleFilter: () {
                    setState(() {
                      mapFilter = switch (mapFilter) {
                        _TacticalMapFilter.all => _TacticalMapFilter.responding,
                        _TacticalMapFilter.responding =>
                          _TacticalMapFilter.incidents,
                        _TacticalMapFilter.incidents => _TacticalMapFilter.all,
                      };
                    });
                  },
                  onSetQueueTab: (value) {
                    setState(() {
                      verificationQueueTab = value;
                    });
                  },
                  onOpenDispatches: headerDispatchAction,
                  focusReference: focusReference,
                  focusState: focusState,
                  geofenceAlerts: geofenceAlerts,
                  sosAlerts: sosAlerts,
                  connectingToLiveData: connectingToLiveData,
                );
                if (!embedScroll) {
                  return content;
                }
                return SingleChildScrollView(primary: false, child: content);
              }

              Widget contextRailChild() {
                final content = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _tacticalWorkspaceCommandReceipt(commandReceipt),
                    const SizedBox(height: 8),
                    _verificationPanel(
                      normMode: normMode,
                      timestamp: _clockLabel(now),
                      telemetry: lensTelemetry,
                      activeMarker: activeMarker,
                      activeFilter: mapFilter,
                      activeQueueTab: verificationQueueTab,
                      onCenterActive: () {
                        final targetMarker = _preferredMarker(
                          visibleMarkers,
                          focusReference: focusReference,
                        );
                        if (targetMarker == null) {
                          return;
                        }
                        setState(() {
                          selectedMarkerId = targetMarker.id;
                        });
                      },
                      onQueueTabChanged: (value) {
                        setState(() {
                          verificationQueueTab = value;
                        });
                      },
                      onShowFeedback: showTacticalFeedback,
                      onOpenDispatches: headerDispatchAction,
                    ),
                    if (showSuppressedPrimary &&
                        suppressedEntries.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      KeyedSubtree(
                        key: suppressedPanelKey,
                        child: _suppressedReviewPanel(
                          entries: suppressedEntries,
                          onShowFeedback: showTacticalFeedback,
                          onFocusFilteredReviews:
                              focusFilteredSuppressedReviews,
                          onOpenLatestWatchActionDetail:
                              openLatestWatchActionDetail,
                        ),
                      ),
                    ],
                    if (visibleFleetScopeHealth.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      KeyedSubtree(
                        key: fleetPanelKey,
                        child: _fleetScopePanel(
                          context: context,
                          fleetScopeHealth: visibleFleetScopeHealth,
                          activeWatchActionDrilldown:
                              activeWatchActionDrilldown,
                          onShowFeedback: showTacticalFeedback,
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
                      const SizedBox(height: 8),
                      KeyedSubtree(
                        key: suppressedPanelKey,
                        child: _suppressedReviewPanel(
                          entries: suppressedEntries,
                          onShowFeedback: showTacticalFeedback,
                          onFocusFilteredReviews:
                              focusFilteredSuppressedReviews,
                          onOpenLatestWatchActionDetail:
                              openLatestWatchActionDetail,
                        ),
                      ),
                    ],
                  ],
                );
                if (!embedScroll) {
                  return content;
                }
                return SingleChildScrollView(primary: false, child: content);
              }

              final workspaceRow = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _tacticalWorkspacePanel(
                      key: const ValueKey('tactical-workspace-panel-rail'),
                      title: 'Tactical Rail',
                      subtitle:
                          'Scope posture, alerts, and monitoring context stay pinned on the left.',
                      shellless: true,
                      child: railChild(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    flex: 10,
                    child: _tacticalWorkspacePanel(
                      key: const ValueKey('tactical-workspace-panel-map'),
                      title: 'Map Board',
                      subtitle:
                          'Live tracks, geofences, and filter-driven tactical routing stay centered.',
                      shellless: true,
                      child: mapBoardChild(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    flex: 2,
                    child: _tacticalWorkspacePanel(
                      key: const ValueKey('tactical-workspace-panel-context'),
                      title: 'Verification Rail',
                      subtitle:
                          'Lens review, fleet health, and suppressed decisions stay visible.',
                      shellless: true,
                      child: contextRailChild(),
                    ),
                  ),
                ],
              );

              if (embedScroll) {
                return Expanded(child: workspaceRow);
              }
              return workspaceRow;
            }

            Widget buildSurfaceBody({
              required bool embedScroll,
              required bool showDesktopOverview,
            }) {
              if (showDesktopOverview && !showDetailedWorkspace) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TrackOverviewBoard(
                        onOpenDetailedWorkspace: () {
                          setDetailedWorkspace(true);
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    _trackWorkspaceToggle(
                      showDetailedWorkspace: showDetailedWorkspace,
                      canCollapse: showDesktopOverview,
                      onPressed: () {
                        setDetailedWorkspace(
                          !(showDetailedWorkspace && showDesktopOverview),
                        );
                      },
                    ),
                  ],
                );
              }
              if (wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildWideWorkspace(embedScroll: embedScroll),
                    if (showDesktopOverview) ...[
                      const SizedBox(height: 8),
                      _trackWorkspaceToggle(
                        showDetailedWorkspace: showDetailedWorkspace,
                        canCollapse: showDesktopOverview,
                        onPressed: () {
                          setDetailedWorkspace(
                            !(showDetailedWorkspace && showDesktopOverview),
                          );
                        },
                      ),
                    ],
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _heroHeader(
                    dispatchAction: headerDispatchAction,
                    agentAction: headerAgentAction,
                    visibleFleetScopeHealth: visibleFleetScopeHealth,
                  ),
                  const SizedBox(height: 6),
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
                    const SizedBox(height: 6),
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
                    const SizedBox(height: 6),
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
                    const SizedBox(height: 6),
                    _scopeFocusBanner(
                      clientId: scopeClientId,
                      siteId: scopeSiteId,
                      hasFleetScope: visibleFleetScopeHealth.isNotEmpty,
                    ),
                  ],
                  const SizedBox(height: 6),
                  _tacticalWorkspaceCommandReceipt(commandReceipt),
                  if (showSuppressedPrimary) ...[
                    const SizedBox(height: 6),
                    KeyedSubtree(
                      key: suppressedPanelKey,
                      child: _suppressedReviewPanel(
                        entries: suppressedEntries,
                        onShowFeedback: showTacticalFeedback,
                        onFocusFilteredReviews: focusFilteredSuppressedReviews,
                        onOpenLatestWatchActionDetail:
                            openLatestWatchActionDetail,
                      ),
                    ),
                  ],
                  if (visibleFleetScopeHealth.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    KeyedSubtree(
                      key: fleetPanelKey,
                      child: _fleetScopePanel(
                        context: context,
                        fleetScopeHealth: visibleFleetScopeHealth,
                        activeWatchActionDrilldown: activeWatchActionDrilldown,
                        onOpenWatchActionDrilldown: openWatchActionDrilldown,
                        onOpenLatestWatchActionDetail:
                            openLatestWatchActionDetail,
                        onClearWatchActionDrilldown: () {
                          setActiveWatchActionDrilldown(null);
                        },
                        onShowFeedback: showTacticalFeedback,
                      ),
                    ),
                  ],
                  if (!showSuppressedPrimary &&
                      suppressedEntries.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    KeyedSubtree(
                      key: suppressedPanelKey,
                      child: _suppressedReviewPanel(
                        entries: suppressedEntries,
                        onShowFeedback: showTacticalFeedback,
                        onFocusFilteredReviews: focusFilteredSuppressedReviews,
                        onOpenLatestWatchActionDetail:
                            openLatestWatchActionDetail,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  _mapPanel(
                    buildContext: context,
                    markers: visibleMarkers,
                    mapBounds: mapBounds,
                    activeMarker: activeMarker,
                    zoom: mapZoom,
                    mapController: mapController,
                    activeFilter: mapFilter,
                    activeQueueTab: verificationQueueTab,
                    onSelectMarker: (markerId) {
                      setState(() {
                        selectedMarkerId = markerId;
                      });
                    },
                    onZoomIn: () {
                      final nextZoom = (mapZoom + 0.12).clamp(1.0, 1.6);
                      setState(() {
                        mapZoom = nextZoom;
                      });
                      mapController.move(
                        activeMarker?.point ?? _mapBoundsCenter(mapBounds),
                        _mapZoomLevelForBounds(
                          mapBounds: mapBounds,
                          zoomScale: nextZoom,
                        ),
                      );
                    },
                    onZoomOut: () {
                      final nextZoom = (mapZoom - 0.12).clamp(1.0, 1.6);
                      setState(() {
                        mapZoom = nextZoom;
                      });
                      mapController.move(
                        activeMarker?.point ?? _mapBoundsCenter(mapBounds),
                        _mapZoomLevelForBounds(
                          mapBounds: mapBounds,
                          zoomScale: nextZoom,
                        ),
                      );
                    },
                    onCenterActive: () {
                      final targetMarker = _preferredMarker(
                        visibleMarkers,
                        focusReference: focusReference,
                      );
                      if (targetMarker == null) {
                        return;
                      }
                      setState(() {
                        selectedMarkerId = targetMarker.id;
                      });
                    },
                    onCycleFilter: () {
                      setState(() {
                        mapFilter = switch (mapFilter) {
                          _TacticalMapFilter.all =>
                            _TacticalMapFilter.responding,
                          _TacticalMapFilter.responding =>
                            _TacticalMapFilter.incidents,
                          _TacticalMapFilter.incidents =>
                            _TacticalMapFilter.all,
                        };
                      });
                    },
                    onSetQueueTab: (value) {
                      setState(() {
                        verificationQueueTab = value;
                      });
                    },
                    onOpenDispatches: headerDispatchAction,
                    focusReference: focusReference,
                    focusState: focusState,
                    geofenceAlerts: geofenceAlerts,
                    sosAlerts: sosAlerts,
                    connectingToLiveData: connectingToLiveData,
                  ),
                  const SizedBox(height: 8),
                  _verificationPanel(
                    normMode: normMode,
                    timestamp: _clockLabel(now),
                    telemetry: lensTelemetry,
                    activeMarker: activeMarker,
                    activeFilter: mapFilter,
                    activeQueueTab: verificationQueueTab,
                    onCenterActive: () {
                      final targetMarker = _preferredMarker(
                        visibleMarkers,
                        focusReference: focusReference,
                      );
                      if (targetMarker == null) {
                        return;
                      }
                      setState(() {
                        selectedMarkerId = targetMarker.id;
                      });
                    },
                    onQueueTabChanged: (value) {
                      setState(() {
                        verificationQueueTab = value;
                      });
                    },
                    onShowFeedback: showTacticalFeedback,
                    onOpenDispatches: headerDispatchAction,
                  ),
                ],
              );
            }

            return OnyxPageScaffold(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compactTacticalLane =
                      constraints.maxWidth < _tacticalDesktopOverviewMinWidth ||
                      math.min(constraints.maxWidth, constraints.maxHeight) <
                          700;
                  wide =
                      !compactTacticalLane &&
                      constraints.maxWidth >=
                          _tacticalDetailedWorkspaceMinWidth &&
                      constraints.maxHeight >=
                          _tacticalDetailedWorkspaceMinHeight;
                  final boundedDesktopSurface =
                      wide &&
                      constraints.hasBoundedHeight &&
                      constraints.maxHeight.isFinite;
                  final ultrawideSurface = isUltrawideLayout(
                    context,
                    viewportWidth: constraints.maxWidth,
                  );
                  final widescreenSurface = isWidescreenLayout(
                    context,
                    viewportWidth: constraints.maxWidth,
                  );
                  final showDesktopOverview =
                      !compactTacticalLane && constraints.maxHeight >= 540;
                  final surfaceMaxWidth = ultrawideSurface
                      ? constraints.maxWidth
                      : widescreenSurface
                      ? constraints.maxWidth * 0.94
                      : 1500.0;
                  return OnyxViewportWorkspaceLayout(
                    padding: contentPadding,
                    maxWidth: surfaceMaxWidth,
                    lockToViewport: boundedDesktopSurface,
                    spacing: 6,
                    header: const SizedBox.shrink(),
                    body: buildSurfaceBody(
                      embedScroll: boundedDesktopSurface,
                      showDesktopOverview: showDesktopOverview,
                    ),
                  );
                },
              ),
            );
          },
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
    final targetReference =
        targetScope.latestIncidentReference ?? focusReference;
    if (targetClientId.trim().isEmpty || targetSiteId.trim().isEmpty) {
      return null;
    }
    return () =>
        openDispatchScope(targetClientId, targetSiteId, targetReference);
  }

  String? _agentIncidentReference({
    required List<VideoFleetScopeHealthView> visibleFleetScopeHealth,
    required String focusReference,
  }) {
    final normalizedFocusReference = focusReference.trim();
    if (normalizedFocusReference.isNotEmpty) {
      return normalizedFocusReference;
    }
    for (final scope in visibleFleetScopeHealth) {
      final candidate = (scope.latestIncidentReference ?? '').trim();
      if (candidate.isNotEmpty) {
        return candidate;
      }
    }
    return null;
  }

  VoidCallback? _headerAgentAction({
    required List<VideoFleetScopeHealthView> visibleFleetScopeHealth,
    required String focusReference,
  }) {
    final callback = onOpenAgentForIncident;
    if (callback == null) {
      return null;
    }
    final incidentReference = _agentIncidentReference(
      visibleFleetScopeHealth: visibleFleetScopeHealth,
      focusReference: focusReference,
    );
    if (incidentReference == null || incidentReference.isEmpty) {
      return null;
    }
    return () => callback(incidentReference);
  }

  Widget _heroHeader({
    required VoidCallback? dispatchAction,
    required VoidCallback? agentAction,
    required List<VideoFleetScopeHealthView> visibleFleetScopeHealth,
    Widget? workspaceBanner,
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
        final dispatchButton = OutlinedButton.icon(
          key: const ValueKey('tactical-open-dispatches-button'),
          onPressed: dispatchAction,
          style: OutlinedButton.styleFrom(
            foregroundColor: OnyxDesignTokens.accentBlue,
            backgroundColor: _tacticalSurfaceColor,
            side: BorderSide(
              color: dispatchAction == null
                  ? _tacticalStrongBorderColor
                  : const Color(0xFF9DB9D9),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7),
            ),
          ),
          icon: const Icon(Icons.open_in_new_rounded, size: 13),
          label: Text(
            'Open Dispatches',
            style: GoogleFonts.inter(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
        final agentButton = OutlinedButton.icon(
          key: const ValueKey('tactical-open-agent-button'),
          onPressed: agentAction,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF6C4BD2),
            side: BorderSide(
              color: agentAction == null
                  ? _tacticalStrongBorderColor
                  : const Color(0xFFB7A5EE),
            ),
            backgroundColor: const Color(0xFFF6F1FF),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7),
            ),
          ),
          icon: const Icon(Icons.psychology_alt_rounded, size: 13),
          label: Text(
            'Ask Agent',
            style: GoogleFonts.inter(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
        final actionButtons = Wrap(
          spacing: 4,
          runSpacing: 4,
          alignment: WrapAlignment.end,
          children: [dispatchButton, if (agentAction != null) agentButton],
        );
        final titleBlock = Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF4338CA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x337C3AED),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.map_rounded,
                  size: 14,
                  color: OnyxDesignTokens.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tactical Command',
                      style: GoogleFonts.inter(
                        color: _tacticalTitleColor,
                        fontSize: compact ? 16 : 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'One map, one live track, one next move.',
                      style: GoogleFonts.inter(
                        color: _tacticalBodyColor,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 3,
                      runSpacing: 3,
                      children: [
                        _heroChip(
                          label:
                              '${visibleFleetScopeHealth.length} Fleet Scope${visibleFleetScopeHealth.length == 1 ? '' : 's'}',
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
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF8FBFF), Color(0xFFEDF4FB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _tacticalBorderColor),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120F172A),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [titleBlock]),
                    const SizedBox(height: 3),
                    actionButtons,
                    if (workspaceBanner != null) ...[
                      const SizedBox(height: 4),
                      workspaceBanner,
                    ],
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleBlock,
                        const SizedBox(width: 4),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 190),
                          child: Align(
                            alignment: Alignment.topRight,
                            child: actionButtons,
                          ),
                        ),
                      ],
                    ),
                    if (workspaceBanner != null) ...[
                      const SizedBox(height: 4),
                      workspaceBanner,
                    ],
                  ],
                ),
        );
      },
    );
  }

  Widget _trackWorkspaceToggle({
    required bool showDetailedWorkspace,
    required bool canCollapse,
    required VoidCallback onPressed,
  }) {
    return Align(
      alignment: Alignment.centerRight,
      child: OutlinedButton.icon(
        key: const ValueKey('tactical-toggle-detailed-workspace'),
        onPressed: onPressed,
        icon: Icon(
          showDetailedWorkspace && canCollapse
              ? Icons.visibility_off_rounded
              : Icons.open_in_new_rounded,
          size: 15,
        ),
        label: Text(
          showDetailedWorkspace && canCollapse
              ? 'Hide Workspace'
              : 'Open Workspace',
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: OnyxDesignTokens.accentBlue,
          side: const BorderSide(color: Color(0xFFBFD2E8)),
          backgroundColor: _tacticalSurfaceColor,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          textStyle: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _heroChip({
    required String label,
    required Color foreground,
    required Color background,
    required Color border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: foreground,
          fontSize: 8,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  _TacticalCommandReceipt _initialCommandReceipt(
    String agentReturnReference,
    TacticalEvidenceReturnReceipt? evidenceReturnReceipt,
  ) {
    if (evidenceReturnReceipt != null) {
      return _TacticalCommandReceipt(
        label: evidenceReturnReceipt.label,
        headline: evidenceReturnReceipt.headline,
        detail: evidenceReturnReceipt.detail,
        accent: evidenceReturnReceipt.accent,
      );
    }
    if (agentReturnReference.isEmpty) {
      return const _TacticalCommandReceipt(
        label: 'TRACK READY',
        headline: 'Map is live. Watch the next move.',
        detail:
            'Fleet-watch actions, lens review, and temporary identity updates stay visible while the live track stays pinned.',
        accent: _tacticalAccentSky,
      );
    }
    return _TacticalCommandReceipt(
      label: 'AGENT RETURN',
      headline: 'Returned from Agent for $agentReturnReference.',
      detail:
          'The scoped track board stayed pinned so controllers can continue from the same tactical focus without reopening the legacy workspace.',
      accent: const Color(0xFF8B5CF6),
    );
  }

  Widget _tacticalWorkspaceStatusBanner({
    required _MapMarker? activeMarker,
    required _TacticalMapFilter activeFilter,
    required String focusReference,
    required _FocusLinkState focusState,
    required _VerificationQueueTab verificationQueueTab,
    required VoidCallback? headerDispatchAction,
    required VoidCallback? headerAgentAction,
    required VoidCallback onCycleFilter,
    required VoidCallback onCenterActive,
    required ValueChanged<_VerificationQueueTab> onSetQueueTab,
    required VoidCallback? onOpenFleetStatus,
    bool summaryOnly = false,
    bool shellless = false,
  }) {
    final selectedTrackLabel = activeMarker == null
        ? 'No live track selected'
        : '${activeMarker.label} • ${_mapFilterLabel(activeFilter)} filter';
    final focusLabel = focusReference.trim().isEmpty
        ? 'No routed focus'
        : 'Focus ${_focusStateLabel(focusState)} • $focusReference';
    final bannerContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: const Color(0x1A7C3AED),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: const Color(0x664338CA)),
              ),
              child: const Icon(
                Icons.explore_rounded,
                color: Color(0xFFDCD4FF),
                size: 11,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'YOU ARE HERE',
                    style: GoogleFonts.inter(
                      color: _tacticalMutedColor,
                      fontSize: 7.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$selectedTrackLabel. ${_verificationQueueWorkspaceLabel(verificationQueueTab)} queue is live.',
                    style: GoogleFonts.inter(
                      color: _tacticalTitleColor,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    focusLabel,
                    style: GoogleFonts.inter(
                      color: _tacticalBodyColor,
                      fontSize: 7.5,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        if (summaryOnly)
          Text(
            onOpenFleetStatus != null
                ? 'Keep the map centered, keep the active queue live, and route dispatch or fleet actions from here.'
                : 'Keep the map centered and keep the active queue live from here.',
            style: GoogleFonts.inter(
              color: _tacticalBodyColor,
              fontSize: 7.5,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          )
        else
          Wrap(
            spacing: 3,
            runSpacing: 3,
            children: [
              if (headerDispatchAction != null)
                _tacticalWorkspaceActionChip(
                  key: const ValueKey('tactical-workspace-open-dispatches'),
                  label: 'Dispatches',
                  foreground: const Color(0xFFDCD4FF),
                  background: const Color(0x147C3AED),
                  border: const Color(0x667C3AED),
                  onTap: headerDispatchAction,
                ),
              if (headerAgentAction != null)
                _tacticalWorkspaceActionChip(
                  key: const ValueKey('tactical-workspace-open-agent'),
                  label: 'Ask Agent',
                  foreground: const Color(0xFFE9D5FF),
                  background: const Color(0x147C3AED),
                  border: const Color(0x667C3AED),
                  onTap: headerAgentAction,
                ),
              _tacticalWorkspaceActionChip(
                key: const ValueKey('tactical-workspace-cycle-filter'),
                label: 'Cycle',
                foreground: const Color(0xFF8FD1FF),
                background: const Color(0x148FD1FF),
                border: const Color(0x668FD1FF),
                onTap: onCycleFilter,
              ),
              _tacticalWorkspaceActionChip(
                key: const ValueKey('tactical-workspace-center-track'),
                label: 'Center track',
                foreground: const Color(0xFFFDE68A),
                background: const Color(0x14FDE68A),
                border: const Color(0x66FDE68A),
                onTap: onCenterActive,
              ),
              _tacticalWorkspaceActionChip(
                key: const ValueKey('tactical-workspace-queue-anomalies'),
                label: 'Anomalies',
                foreground: const Color(0xFFFF99A8),
                background: const Color(0x14FF99A8),
                border: const Color(0x66FF99A8),
                onTap: () => onSetQueueTab(_VerificationQueueTab.anomalies),
              ),
              _tacticalWorkspaceActionChip(
                key: const ValueKey('tactical-workspace-queue-matches'),
                label: 'Matches',
                foreground: const Color(0xFF8FD1FF),
                background: const Color(0x148FD1FF),
                border: const Color(0x668FD1FF),
                onTap: () => onSetQueueTab(_VerificationQueueTab.matches),
              ),
              _tacticalWorkspaceActionChip(
                key: const ValueKey('tactical-workspace-queue-assets'),
                label: 'Assets',
                foreground: const Color(0xFFA7F3D0),
                background: const Color(0x14A7F3D0),
                border: const Color(0x66A7F3D0),
                onTap: () => onSetQueueTab(_VerificationQueueTab.assets),
              ),
              if (onOpenFleetStatus != null)
                _tacticalWorkspaceActionChip(
                  key: const ValueKey('tactical-workspace-open-fleet'),
                  label: 'Fleet status',
                  foreground: const Color(0xFFEAF4FF),
                  background: const Color(0x143B82F6),
                  border: const Color(0x663B82F6),
                  onTap: onOpenFleetStatus,
                ),
            ],
          ),
      ],
    );
    if (shellless) {
      return KeyedSubtree(
        key: const ValueKey('tactical-workspace-status-banner'),
        child: bannerContent,
      );
    }
    return Container(
      key: const ValueKey('tactical-workspace-status-banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _tacticalAltSurfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _tacticalBorderColor),
      ),
      child: bannerContent,
    );
  }

  Widget _tacticalWorkspacePanel({
    required Key key,
    required String title,
    required String subtitle,
    required Widget child,
    bool shellless = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boundedHeight =
            constraints.hasBoundedHeight && constraints.maxHeight.isFinite;
        if (shellless) {
          return KeyedSubtree(key: key, child: child);
        }
        return Container(
          key: key,
          width: double.infinity,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: _tacticalSurfaceColor,
            border: Border.all(color: _tacticalBorderColor),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120F172A),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: GoogleFonts.inter(
                  color: _tacticalMutedColor,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  color: _tacticalBodyColor,
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              if (boundedHeight) Expanded(child: child) else child,
            ],
          ),
        );
      },
    );
  }

  Widget _tacticalWorkspaceActionChip({
    required Key key,
    required String label,
    required Color foreground,
    required Color background,
    required Color border,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            OnyxDesignTokens.glassSurface,
            background,
          ),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border.withValues(alpha: 0.44)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: Color.lerp(_tacticalTitleColor, foreground, 0.72),
            fontSize: 8,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _tacticalWorkspaceCommandReceipt(_TacticalCommandReceipt receipt) {
    return Container(
      key: const ValueKey('tactical-workspace-command-receipt'),
      width: double.infinity,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: _tacticalSurfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: receipt.accent.withValues(alpha: 0.42)),
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
          Text(
            'LAST MOVE',
            style: GoogleFonts.inter(
              color: _tacticalMutedColor,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: receipt.accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: receipt.accent.withValues(alpha: 0.45)),
            ),
            child: Text(
              receipt.label,
              style: GoogleFonts.inter(
                color: receipt.accent,
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            receipt.headline,
            style: GoogleFonts.inter(
              color: _tacticalTitleColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            receipt.detail,
            style: GoogleFonts.inter(
              color: _tacticalBodyColor,
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _verificationQueueWorkspaceLabel(_VerificationQueueTab tab) {
    return switch (tab) {
      _VerificationQueueTab.anomalies => 'Anomaly',
      _VerificationQueueTab.matches => 'Match',
      _VerificationQueueTab.assets => 'Asset',
    };
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final actionButton = FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: OnyxDesignTokens.textPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              actionLabel,
              style: GoogleFonts.inter(
                fontSize: 9,
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
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEAF4FF),
                    fontSize: 10,
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
                        Icon(icon, color: accent, size: 18),
                        const SizedBox(width: 6),
                        textColumn,
                      ],
                    ),
                    const SizedBox(height: 6),
                    actionButton,
                  ],
                )
              : Row(
                  children: [
                    Icon(icon, color: accent, size: 18),
                    const SizedBox(width: 6),
                    textColumn,
                    const SizedBox(width: 8),
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
    required void Function(
      String message, {
      String label,
      String? detail,
      Color accent,
    })
    onShowFeedback,
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
    final focusDrilldown =
        activeWatchActionDrilldown ??
        _recommendedFleetSummaryDrilldown(sections);
    final focusSections = focusDrilldown == null
        ? sections
        : VideoFleetScopeHealthSections.fromScopes(
            orderFleetScopesForWatchAction(
              filterFleetScopesForWatchAction(fleetScopeHealth, focusDrilldown),
              focusDrilldown,
            ),
          );
    final leadScope =
        primaryFleetScopeForWatchAction(focusSections, focusDrilldown) ??
        (sections.actionableScopes.isNotEmpty
            ? sections.actionableScopes.first
            : sections.watchOnlyScopes.isNotEmpty
            ? sections.watchOnlyScopes.first
            : fleetScopeHealth.first);
    final focusAccent =
        focusDrilldown?.accentColor ?? _fleetFreshnessColor(leadScope);
    final focusDetail = focusDrilldown == null
        ? 'Fleet health stays anchored across ${sections.actionableScopes.length} incident-backed scopes and ${sections.watchOnlyScopes.length} watch-only scopes.'
        : focusDetailForWatchAction(fleetScopeHealth, focusDrilldown);
    final focusLatest = prominentLatestTextForWatchAction(
      leadScope,
      focusDrilldown,
    );
    final hasTacticalLead =
        leadScope.hasIncidentContext && onOpenFleetTacticalScope != null;
    final hasDispatchLead =
        leadScope.hasIncidentContext && onOpenFleetDispatchScope != null;
    final canRecoverLead =
        leadScope.hasWatchActivationGap && onRecoverFleetWatchScope != null;
    final primaryActionLabel = hasTacticalLead
        ? 'OPEN TACTICAL TRACK'
        : hasDispatchLead
        ? 'OPEN DISPATCH BOARD'
        : canRecoverLead
        ? 'Resync coverage'
        : 'Open latest detail';
    final primaryActionColor = hasTacticalLead
        ? const Color(0xFF8FD1FF)
        : hasDispatchLead
        ? const Color(0xFFFDE68A)
        : canRecoverLead
        ? const Color(0xFFFCA5A5)
        : const Color(0xFF67E8F9);

    void focusFleetDrilldown(VideoFleetWatchActionDrilldown drilldown) {
      if (activeWatchActionDrilldown != drilldown) {
        onOpenWatchActionDrilldown(drilldown);
      }
      onShowFeedback(
        '${drilldown.focusLabel} foregrounded in fleet command rail.',
        label: 'FLEET DRILLDOWN',
        detail:
            'The fleet command rail is now centered on ${drilldown.focusLabel.toLowerCase()} while the lead scope stays anchored.',
        accent: drilldown.accentColor,
      );
    }

    void clearFleetFocus() {
      onClearWatchActionDrilldown();
      onShowFeedback(
        'Cleared focused fleet watch action.',
        label: 'FLEET FOCUS',
        detail:
            'The fleet command rail returned to the broader mixed-lane overview.',
        accent: const Color(0xFF9AB1CF),
      );
    }

    void openLeadDetail() {
      onOpenLatestWatchActionDetail(leadScope);
      onShowFeedback(
        'Focused lead fleet detail for ${leadScope.siteName}.',
        label: 'FLEET DETAIL',
        detail:
            '${leadScope.siteName} remains pinned while the fleet rail keeps the current watch lane in focus.',
        accent: const Color(0xFF67E8F9),
      );
    }

    void openLeadTactical() {
      if (!hasTacticalLead) {
        openLeadDetail();
        return;
      }
      onOpenFleetTacticalScope!.call(
        leadScope.clientId,
        leadScope.siteId,
        leadScope.latestIncidentReference,
      );
      onShowFeedback(
        'Opened lead fleet scope in tactical lane.',
        label: 'TACTICAL HANDOFF',
        detail:
            '${leadScope.siteName} is now foregrounded in the scoped tactical workspace.',
        accent: const Color(0xFF8FD1FF),
      );
    }

    void openLeadDispatch() {
      if (!hasDispatchLead) {
        openLeadDetail();
        return;
      }
      onOpenFleetDispatchScope!.call(
        leadScope.clientId,
        leadScope.siteId,
        leadScope.latestIncidentReference,
      );
      onShowFeedback(
        'Opened lead fleet scope in dispatch lane.',
        label: 'DISPATCH HANDOFF',
        detail:
            '${leadScope.siteName} is now foregrounded in the scoped dispatch workspace.',
        accent: const Color(0xFFFDE68A),
      );
    }

    void recoverLeadScope() {
      if (!canRecoverLead) {
        return;
      }
      onRecoverFleetWatchScope!.call(leadScope.clientId, leadScope.siteId);
      onShowFeedback(
        'Triggered coverage resync for ${leadScope.siteName}.',
        label: 'COVERAGE RESYNC',
        detail:
            '${leadScope.siteName} has been queued for watch-window recovery from the fleet rail.',
        accent: const Color(0xFFFCA5A5),
      );
    }

    final VoidCallback primaryAction = hasTacticalLead
        ? openLeadTactical
        : hasDispatchLead
        ? openLeadDispatch
        : canRecoverLead
        ? recoverLeadScope
        : openLeadDetail;
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
            onShowFeedback: onShowFeedback,
            onClear: onClearWatchActionDrilldown,
          ),
          const SizedBox(height: 8),
        ],
        Container(
          key: const ValueKey('tactical-fleet-focus-card'),
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _tacticalSurfaceColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: focusAccent.withValues(alpha: 0.42)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F0F172A),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
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
                          'Fleet Focus',
                          style: GoogleFonts.inter(
                            color: focusAccent,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          focusDrilldown?.focusLabel ?? 'Fleet coverage ready',
                          style: GoogleFonts.inter(
                            color: _tacticalTitleColor,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          focusDetail,
                          style: GoogleFonts.inter(
                            color: _tacticalBodyColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                        if (focusLatest != null) ...[
                          const SizedBox(height: 5),
                          Text(
                            focusLatest,
                            style: GoogleFonts.inter(
                              color: _tacticalMutedColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: primaryActionColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: primaryActionColor.withValues(alpha: 0.42),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'RECOMMENDED MOVE',
                          style: GoogleFonts.inter(
                            color: primaryActionColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          primaryActionLabel,
                          style: GoogleFonts.inter(
                            color: const Color(0xFFEAF4FF),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (focusDrilldown != null)
                    _topChip(
                      'Action lane',
                      focusDrilldown.focusLabel,
                      focusAccent,
                    ),
                  _topChip(
                    'Lead scope',
                    leadScope.siteName,
                    _fleetFreshnessColor(leadScope),
                  ),
                  _topChip(
                    'Actionable',
                    '${focusSections.actionableScopes.length}',
                    const Color(0xFF8FD1FF),
                  ),
                  _topChip(
                    'Watch only',
                    '${focusSections.watchOnlyScopes.length}',
                    const Color(0xFFFDE68A),
                  ),
                  if (leadScope.latestRiskScore != null)
                    _topChip(
                      'Risk lane',
                      _fleetRiskLabel(leadScope.latestRiskScore!),
                      _fleetRiskColor(leadScope.latestRiskScore!),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (focusDrilldown != null)
                    _tacticalWorkspaceActionChip(
                      key: const ValueKey(
                        'tactical-fleet-focus-open-drilldown',
                      ),
                      label: focusDrilldown.focusLabel,
                      foreground: focusAccent,
                      background: focusAccent.withValues(alpha: 0.12),
                      border: focusAccent.withValues(alpha: 0.52),
                      onTap: () => focusFleetDrilldown(focusDrilldown),
                    ),
                  _tacticalWorkspaceActionChip(
                    key: const ValueKey('tactical-fleet-focus-open-detail'),
                    label: 'Latest detail',
                    foreground: const Color(0xFF67E8F9),
                    background: const Color(0x1467E8F9),
                    border: const Color(0x6667E8F9),
                    onTap: openLeadDetail,
                  ),
                  if (hasTacticalLead)
                    _tacticalWorkspaceActionChip(
                      key: const ValueKey('tactical-fleet-focus-open-tactical'),
                      label: 'OPEN TACTICAL TRACK',
                      foreground: const Color(0xFF8FD1FF),
                      background: const Color(0x148FD1FF),
                      border: const Color(0x668FD1FF),
                      onTap: openLeadTactical,
                    ),
                  if (hasDispatchLead)
                    _tacticalWorkspaceActionChip(
                      key: const ValueKey('tactical-fleet-focus-open-dispatch'),
                      label: 'OPEN DISPATCH BOARD',
                      foreground: const Color(0xFFFDE68A),
                      background: const Color(0x14FDE68A),
                      border: const Color(0x66FDE68A),
                      onTap: openLeadDispatch,
                    ),
                  if (canRecoverLead)
                    _tacticalWorkspaceActionChip(
                      key: const ValueKey('tactical-fleet-focus-resync'),
                      label: 'Resync coverage',
                      foreground: const Color(0xFFFCA5A5),
                      background: const Color(0x14FCA5A5),
                      border: const Color(0x66FCA5A5),
                      onTap: recoverLeadScope,
                    ),
                  if (activeWatchActionDrilldown != null)
                    _tacticalWorkspaceActionChip(
                      key: const ValueKey('tactical-fleet-focus-clear'),
                      label: 'Clear focus',
                      foreground: const Color(0xFF9AB1CF),
                      background: const Color(0x149AB1CF),
                      border: const Color(0x669AB1CF),
                      onTap: clearFleetFocus,
                    ),
                  _tacticalWorkspaceActionChip(
                    key: const ValueKey('tactical-fleet-focus-primary-action'),
                    label: primaryActionLabel,
                    foreground: primaryActionColor,
                    background: primaryActionColor.withValues(alpha: 0.12),
                    border: primaryActionColor.withValues(alpha: 0.52),
                    onTap: primaryAction,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        VideoFleetScopeHealthPanel(
          title: 'DVR FLEET HEALTH',
          titleStyle: GoogleFonts.inter(
            color: _tacticalMutedColor,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
          sectionLabelStyle: GoogleFonts.inter(
            color: _tacticalMutedColor,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.9,
          ),
          sections: filteredSections,
          activeWatchActionDrilldown: activeWatchActionDrilldown,
          summaryHeader: _fleetSummaryCommandDeck(
            sections: sections,
            activeWatchActionDrilldown: activeWatchActionDrilldown,
            onFocusDrilldown: focusFleetDrilldown,
            onClearFocus: activeWatchActionDrilldown == null
                ? null
                : clearFleetFocus,
          ),
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
                  onShowFeedback: onShowFeedback,
                  onOpenLatestWatchActionDetail: onOpenLatestWatchActionDetail,
                ),
              )
              .toList(growable: false),
          watchOnlyChildren: filteredSections.watchOnlyScopes
              .map(
                (scope) => _fleetScopeCard(
                  scope: scope,
                  activeWatchActionDrilldown: activeWatchActionDrilldown,
                  onShowFeedback: onShowFeedback,
                  onOpenLatestWatchActionDetail: onOpenLatestWatchActionDetail,
                ),
              )
              .toList(growable: false),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _tacticalAltSurfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _tacticalBorderColor),
          ),
          cardSpacing: 10,
          runSpacing: 10,
        ),
      ],
    );
  }

  Widget _fleetSummaryCommandDeck({
    required VideoFleetScopeHealthSections sections,
    required VideoFleetWatchActionDrilldown? activeWatchActionDrilldown,
    required void Function(VideoFleetWatchActionDrilldown drilldown)
    onFocusDrilldown,
    required VoidCallback? onClearFocus,
  }) {
    final recommendedDrilldown = _recommendedFleetSummaryDrilldown(sections);
    final activeDrilldown = activeWatchActionDrilldown;
    final primaryDrilldown = activeDrilldown ?? recommendedDrilldown;
    final availableDrilldowns = _availableFleetSummaryDrilldowns(sections);
    final secondaryDrilldowns = availableDrilldowns
        .where((drilldown) => drilldown != primaryDrilldown)
        .take(3)
        .toList(growable: false);
    final accent = primaryDrilldown?.accentColor ?? const Color(0xFF9AB1CF);
    final headline = activeDrilldown != null
        ? 'Fleet lane in focus'
        : primaryDrilldown != null
        ? 'Recommended fleet lane'
        : 'Fleet overview steady';
    final detail = activeDrilldown != null
        ? activeDrilldown.focusDetail
        : primaryDrilldown != null
        ? 'Lead the fleet rail through ${primaryDrilldown.focusLabel.toLowerCase()} first, then widen back to the full watch surface as needed.'
        : 'All fleet scopes are visible with no single watch lane demanding priority right now.';

    return Container(
      key: const ValueKey('tactical-fleet-summary-command'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _tacticalSurfaceColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.36)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 220;
          final summary = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FLEET SUMMARY COMMAND',
                style: GoogleFonts.inter(
                  color: accent,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                primaryDrilldown?.focusLabel ?? 'All fleet scopes visible',
                style: GoogleFonts.inter(
                  color: _tacticalTitleColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: GoogleFonts.inter(
                  color: _tacticalBodyColor,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          );
          final modeCard = Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: accent.withValues(alpha: 0.42)),
            ),
            child: Column(
              crossAxisAlignment: compact
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: [
                Text(
                  'COMMAND MODE',
                  style: GoogleFonts.inter(
                    color: accent,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  headline,
                  style: GoogleFonts.inter(
                    color: _tacticalTitleColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compact) ...[
                summary,
                const SizedBox(height: 8),
                modeCard,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: summary),
                    const SizedBox(width: 12),
                    modeCard,
                  ],
                ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (primaryDrilldown != null)
                    _topChip(
                      'Primary lane',
                      primaryDrilldown.focusLabel,
                      accent,
                    ),
                  _topChip(
                    'Actionable',
                    '${sections.actionableScopes.length}',
                    const Color(0xFF8FD1FF),
                  ),
                  _topChip(
                    'Watch only',
                    '${sections.watchOnlyScopes.length}',
                    const Color(0xFFFDE68A),
                  ),
                  _topChip(
                    'High risk',
                    '${sections.highRiskCount}',
                    const Color(0xFFFCA5A5),
                  ),
                  _topChip(
                    'Gaps',
                    '${sections.gapCount}',
                    const Color(0xFFFCA5A5),
                  ),
                ],
              ),
              if (primaryDrilldown != null ||
                  secondaryDrilldowns.isNotEmpty ||
                  onClearFocus != null) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (primaryDrilldown != null)
                      _tacticalWorkspaceActionChip(
                        key: const ValueKey('tactical-fleet-summary-primary'),
                        label: primaryDrilldown.focusLabel,
                        foreground: accent,
                        background: accent.withValues(alpha: 0.12),
                        border: accent.withValues(alpha: 0.52),
                        onTap: () => onFocusDrilldown(primaryDrilldown),
                      ),
                    for (final drilldown in secondaryDrilldowns)
                      _tacticalWorkspaceActionChip(
                        key: ValueKey(
                          'tactical-fleet-summary-secondary-${drilldown.name}',
                        ),
                        label: drilldown.focusLabel,
                        foreground: drilldown.accentColor,
                        background: drilldown.accentColor.withValues(
                          alpha: 0.12,
                        ),
                        border: drilldown.accentColor.withValues(alpha: 0.52),
                        onTap: () => onFocusDrilldown(drilldown),
                      ),
                    if (onClearFocus != null)
                      _tacticalWorkspaceActionChip(
                        key: const ValueKey('tactical-fleet-summary-clear'),
                        label: 'All scopes',
                        foreground: const Color(0xFF9AB1CF),
                        background: const Color(0x149AB1CF),
                        border: const Color(0x669AB1CF),
                        onTap: onClearFocus,
                      ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
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

  Widget _suppressedReviewPanel({
    required List<_SuppressedFleetReviewEntry> entries,
    required void Function(
      String message, {
      String label,
      String? detail,
      Color accent,
    })
    onShowFeedback,
    required VoidCallback onFocusFilteredReviews,
    required void Function(VideoFleetScopeHealthView scope)
    onOpenLatestWatchActionDetail,
  }) {
    final focusEntry = entries.first;
    final focusScope = focusEntry.scope;
    final focusReview = focusEntry.review;
    final hasTacticalLane =
        focusScope.hasIncidentContext && onOpenFleetTacticalScope != null;
    final hasDispatchLane =
        focusScope.hasIncidentContext && onOpenFleetDispatchScope != null;
    final primaryActionLabel = hasTacticalLane
        ? 'OPEN TACTICAL TRACK'
        : hasDispatchLane
        ? 'OPEN DISPATCH BOARD'
        : 'Open latest detail';
    final primaryActionColor = hasTacticalLane
        ? const Color(0xFF8FD1FF)
        : hasDispatchLane
        ? const Color(0xFFFDE68A)
        : const Color(0xFF67E8F9);

    void openSuppressedDetail(_SuppressedFleetReviewEntry entry) {
      onOpenLatestWatchActionDetail(entry.scope);
      onShowFeedback(
        'Focused suppressed review detail for ${entry.scope.siteName}.',
        label: 'REVIEW DETAIL',
        detail:
            'Latest suppressed scene-review context stays pinned for ${entry.scope.siteName}.',
        accent: const Color(0xFF67E8F9),
      );
    }

    void openSuppressedTactical(_SuppressedFleetReviewEntry entry) {
      if (onOpenFleetTacticalScope == null || !entry.scope.hasIncidentContext) {
        openSuppressedDetail(entry);
        return;
      }
      onOpenFleetTacticalScope!.call(
        entry.scope.clientId,
        entry.scope.siteId,
        entry.scope.latestIncidentReference,
      );
      onShowFeedback(
        'Opened suppressed review in tactical lane.',
        label: 'TACTICAL HANDOFF',
        detail:
            '${entry.scope.siteName} is now foregrounded in the scoped tactical workspace.',
        accent: const Color(0xFF8FD1FF),
      );
    }

    void openSuppressedDispatch(_SuppressedFleetReviewEntry entry) {
      if (onOpenFleetDispatchScope == null || !entry.scope.hasIncidentContext) {
        openSuppressedDetail(entry);
        return;
      }
      onOpenFleetDispatchScope!.call(
        entry.scope.clientId,
        entry.scope.siteId,
        entry.scope.latestIncidentReference,
      );
      onShowFeedback(
        'Opened suppressed review in dispatch lane.',
        label: 'DISPATCH HANDOFF',
        detail:
            '${entry.scope.siteName} is now foregrounded in the scoped dispatch workspace.',
        accent: const Color(0xFFFDE68A),
      );
    }

    void focusFilteredLane() {
      onFocusFilteredReviews();
      onShowFeedback(
        'Focused filtered review lane in verification rail.',
        label: 'FILTERED REVIEWS',
        detail:
            'Suppressed scene reviews now stay foregrounded ahead of broader fleet health.',
        accent: const Color(0xFF9AB1CF),
      );
    }

    final VoidCallback primaryAction = hasTacticalLane
        ? () => openSuppressedTactical(focusEntry)
        : hasDispatchLane
        ? () => openSuppressedDispatch(focusEntry)
        : () => openSuppressedDetail(focusEntry);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF13131E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x269D4BFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 5,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'SUPPRESSED ${videoOpsLabel.toUpperCase()} REVIEWS',
                style: GoogleFonts.inter(
                  color: const Color(0xFF7A8FA4),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              _topChip(
                'Internal',
                '${entries.length}',
                const Color(0xFF9AB1CF),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'Recent ${videoOpsLabel.toUpperCase()} reviews ONYX held below the client-notification threshold across the active fleet.',
            style: GoogleFonts.inter(
              color: const Color(0xFF556B80),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            key: const ValueKey('tactical-suppressed-focus-card'),
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAFD),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFD6E1EC)),
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
                            'SUPPRESSED REVIEW FOCUS',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF7A8FA4),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            focusScope.siteName,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF172638),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            focusReview.decisionSummary.trim().isEmpty
                                ? 'Suppressed because the activity remained below the client threshold.'
                                : focusReview.decisionSummary.trim(),
                            style: GoogleFonts.inter(
                              color: const Color(0xFF556B80),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: primaryActionColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: primaryActionColor.withValues(alpha: 0.42),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'RECOMMENDED MOVE',
                            style: GoogleFonts.inter(
                              color: primaryActionColor,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            primaryActionLabel,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF172638),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _topChip(
                      'Internal',
                      '${entries.length}',
                      const Color(0xFF9AB1CF),
                    ),
                    _topChip(
                      'Action',
                      focusReview.decisionLabel.trim().isEmpty
                          ? 'Suppressed'
                          : focusReview.decisionLabel.trim(),
                      const Color(0xFFBFD7F2),
                    ),
                    _topChip(
                      'Posture',
                      focusReview.postureLabel.trim(),
                      const Color(0xFF86EFAC),
                    ),
                    if ((focusScope.latestCameraLabel ?? '').trim().isNotEmpty)
                      _topChip(
                        'Camera',
                        focusScope.latestCameraLabel!.trim(),
                        const Color(0xFF8FD1FF),
                      ),
                    _topChip(
                      'Reviewed',
                      _clockLabel(focusReview.reviewedAtUtc.toLocal()),
                      const Color(0xFF8EA4C2),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _tacticalWorkspaceActionChip(
                      key: const ValueKey(
                        'tactical-suppressed-focus-filtered-lane',
                      ),
                      label: 'Filtered lane',
                      foreground: const Color(0xFF9AB1CF),
                      background: const Color(0x149AB1CF),
                      border: const Color(0x669AB1CF),
                      onTap: focusFilteredLane,
                    ),
                    _tacticalWorkspaceActionChip(
                      key: const ValueKey(
                        'tactical-suppressed-focus-open-detail',
                      ),
                      label: 'Latest detail',
                      foreground: const Color(0xFF67E8F9),
                      background: const Color(0x1467E8F9),
                      border: const Color(0x6667E8F9),
                      onTap: () => openSuppressedDetail(focusEntry),
                    ),
                    if (hasTacticalLane)
                      _tacticalWorkspaceActionChip(
                        key: const ValueKey(
                          'tactical-suppressed-focus-open-tactical',
                        ),
                        label: 'OPEN TACTICAL TRACK',
                        foreground: const Color(0xFF8FD1FF),
                        background: const Color(0x148FD1FF),
                        border: const Color(0x668FD1FF),
                        onTap: () => openSuppressedTactical(focusEntry),
                      ),
                    if (hasDispatchLane)
                      _tacticalWorkspaceActionChip(
                        key: const ValueKey(
                          'tactical-suppressed-focus-open-dispatch',
                        ),
                        label: 'OPEN DISPATCH BOARD',
                        foreground: const Color(0xFFFDE68A),
                        background: const Color(0x14FDE68A),
                        border: const Color(0x66FDE68A),
                        onTap: () => openSuppressedDispatch(focusEntry),
                      ),
                    _tacticalWorkspaceActionChip(
                      key: const ValueKey(
                        'tactical-suppressed-focus-primary-action',
                      ),
                      label: primaryActionLabel,
                      foreground: primaryActionColor,
                      background: primaryActionColor.withValues(alpha: 0.12),
                      border: primaryActionColor.withValues(alpha: 0.52),
                      onTap: primaryAction,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: entries
                .map(
                  (entry) => _suppressedReviewCard(
                    entry: entry,
                    onOpenDetail: () => openSuppressedDetail(entry),
                    onOpenTactical:
                        entry.scope.hasIncidentContext &&
                            onOpenFleetTacticalScope != null
                        ? () => openSuppressedTactical(entry)
                        : null,
                    onOpenDispatch:
                        entry.scope.hasIncidentContext &&
                            onOpenFleetDispatchScope != null
                        ? () => openSuppressedDispatch(entry)
                        : null,
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  Widget _suppressedReviewCard({
    required _SuppressedFleetReviewEntry entry,
    required VoidCallback onOpenDetail,
    required VoidCallback? onOpenTactical,
    required VoidCallback? onOpenDispatch,
  }) {
    final scope = entry.scope;
    final review = entry.review;
    return Container(
      key: ValueKey<String>('tactical-suppressed-card-${scope.siteId}'),
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
                    color: OnyxDesignTokens.textPrimary,
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
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _tacticalWorkspaceActionChip(
                key: ValueKey<String>(
                  'tactical-suppressed-detail-${scope.siteId}',
                ),
                label: 'Detail',
                foreground: const Color(0xFF67E8F9),
                background: const Color(0x1467E8F9),
                border: const Color(0x6667E8F9),
                onTap: onOpenDetail,
              ),
              if (onOpenTactical != null)
                _tacticalWorkspaceActionChip(
                  key: ValueKey<String>(
                    'tactical-suppressed-tactical-${scope.siteId}',
                  ),
                  label: 'Tactical',
                  foreground: const Color(0xFF8FD1FF),
                  background: const Color(0x148FD1FF),
                  border: const Color(0x668FD1FF),
                  onTap: onOpenTactical,
                ),
              if (onOpenDispatch != null)
                _tacticalWorkspaceActionChip(
                  key: ValueKey<String>(
                    'tactical-suppressed-dispatch-${scope.siteId}',
                  ),
                  label: 'Dispatch',
                  foreground: const Color(0xFFFDE68A),
                  background: const Color(0x14FDE68A),
                  border: const Color(0x66FDE68A),
                  onTap: onOpenDispatch,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fleetScopeCard({
    required VideoFleetScopeHealthView scope,
    required VideoFleetWatchActionDrilldown? activeWatchActionDrilldown,
    required void Function(
      String message, {
      String label,
      String? detail,
      Color accent,
    })
    onShowFeedback,
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
    final hasTacticalLane =
        scope.hasIncidentContext && onOpenFleetTacticalScope != null;
    final hasDispatchLane =
        scope.hasIncidentContext && onOpenFleetDispatchScope != null;
    final canRecoverCoverage =
        scope.hasWatchActivationGap && onRecoverFleetWatchScope != null;
    final commandAccent = _fleetScopeCommandAccent(scope);
    final commandHeadline = _fleetScopeCommandHeadline(scope);
    final commandDetail = _fleetScopeCommandDetail(scope);
    final primaryActionLabel = canRecoverCoverage
        ? 'Resync coverage'
        : hasTacticalLane
        ? 'OPEN TACTICAL TRACK'
        : hasDispatchLane
        ? 'OPEN DISPATCH BOARD'
        : 'Latest detail';
    final primaryActionColor = canRecoverCoverage
        ? const Color(0xFFFCA5A5)
        : hasTacticalLane
        ? const Color(0xFF8FD1FF)
        : hasDispatchLane
        ? const Color(0xFFFDE68A)
        : const Color(0xFF67E8F9);

    void openFleetDetail() {
      onOpenLatestWatchActionDetail(scope);
      onShowFeedback(
        'Focused fleet scope detail for ${scope.siteName}.',
        label: 'FLEET DETAIL',
        detail:
            '${scope.siteName} stays pinned in the fleet rail while the latest watch context opens below it.',
        accent: const Color(0xFF67E8F9),
      );
    }

    void openFleetTactical() {
      if (!hasTacticalLane) {
        openFleetDetail();
        return;
      }
      onOpenFleetTacticalScope!.call(
        scope.clientId,
        scope.siteId,
        scope.latestIncidentReference,
      );
      onShowFeedback(
        'Opened ${scope.siteName} in tactical lane.',
        label: 'TACTICAL HANDOFF',
        detail:
            '${scope.siteName} is now foregrounded in the scoped tactical workspace.',
        accent: const Color(0xFF8FD1FF),
      );
    }

    void openFleetDispatch() {
      if (!hasDispatchLane) {
        openFleetDetail();
        return;
      }
      onOpenFleetDispatchScope!.call(
        scope.clientId,
        scope.siteId,
        scope.latestIncidentReference,
      );
      onShowFeedback(
        'Opened ${scope.siteName} in dispatch lane.',
        label: 'DISPATCH HANDOFF',
        detail:
            '${scope.siteName} is now foregrounded in the scoped dispatch workspace.',
        accent: const Color(0xFFFDE68A),
      );
    }

    void recoverFleetScope() {
      if (!canRecoverCoverage) {
        openFleetDetail();
        return;
      }
      onRecoverFleetWatchScope!.call(scope.clientId, scope.siteId);
      onShowFeedback(
        'Triggered coverage resync for ${scope.siteName}.',
        label: 'COVERAGE RESYNC',
        detail:
            '${scope.siteName} has been queued for watch-window recovery from the fleet scope card.',
        accent: const Color(0xFFFCA5A5),
      );
    }

    return VideoFleetScopeHealthCard(
      key: ValueKey('tactical-fleet-scope-card-${scope.siteId}'),
      headerChild: Container(
        key: ValueKey('tactical-fleet-scope-command-${scope.siteId}'),
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFFBFDFF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: commandAccent.withValues(alpha: 0.26)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SCOPE COMMAND',
                    style: GoogleFonts.inter(
                      color: commandAccent,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    commandHeadline,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFEAF4FF),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    commandDetail,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFCAD7E8),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Align(
                alignment: Alignment.topRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: primaryActionColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: primaryActionColor.withValues(alpha: 0.42),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'NEXT MOVE',
                        style: GoogleFonts.inter(
                          color: primaryActionColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        primaryActionLabel,
                        textAlign: TextAlign.end,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: const Color(0xFFEAF4FF),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      identityChild: Container(
        key: ValueKey('tactical-fleet-scope-identity-${scope.siteId}'),
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: commandAccent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: commandAccent.withValues(alpha: 0.24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SCOPE IDENTITY',
              style: GoogleFonts.inter(
                color: commandAccent,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _topChip(
                  'Endpoint',
                  scope.endpointLabel,
                  const Color(0xFF9AB1CF),
                ),
                _topChip(
                  'Last seen',
                  scope.lastSeenLabel,
                  _fleetFreshnessColor(scope),
                ),
                if ((scope.latestIncidentReference ?? '').trim().isNotEmpty)
                  _topChip(
                    'Reference',
                    scope.latestIncidentReference!,
                    const Color(0xFF8FD1FF),
                  ),
                if ((scope.latestCameraLabel ?? '').trim().isNotEmpty)
                  _topChip(
                    'Camera',
                    scope.latestCameraLabel!,
                    const Color(0xFF9AB1CF),
                  ),
                if (!scope.hasIncidentContext)
                  _topChip('Context', 'Pending', const Color(0xFFFDE68A)),
              ],
            ),
          ],
        ),
      ),
      hideDefaultEndpoint: true,
      hideDefaultLastSeen: true,
      title: scope.siteName,
      endpointLabel: scope.endpointLabel,
      lastSeenLabel: ': ${scope.lastSeenLabel}',
      titleStyle: GoogleFonts.inter(
        color: OnyxDesignTokens.textPrimary,
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
      primaryGroupLabel: 'COMMAND POSTURE',
      primaryGroupAccent: commandAccent,
      primaryGroupKey: ValueKey('tactical-fleet-scope-posture-${scope.siteId}'),
      contextGroupLabel: 'WATCH CONTEXT',
      contextGroupAccent: const Color(0xFFFDE68A),
      contextGroupKey: ValueKey('tactical-fleet-scope-context-${scope.siteId}'),
      latestGroupLabel: 'LATEST SIGNAL',
      latestGroupAccent: const Color(0xFF67E8F9),
      latestGroupKey: ValueKey('tactical-fleet-scope-latest-${scope.siteId}'),
      secondaryGroupLabel: 'LIVE FEED',
      secondaryGroupAccent: const Color(0xFF8FD1FF),
      secondaryGroupKey: ValueKey('tactical-fleet-scope-feed-${scope.siteId}'),
      actionsGroupLabel: 'COMMAND ACTIONS',
      actionsGroupAccent: primaryActionColor,
      actionsGroupKey: ValueKey('tactical-fleet-scope-actions-${scope.siteId}'),
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
        _fleetActionButton(
          key: ValueKey('tactical-fleet-detail-${scope.siteId}'),
          label: 'Latest detail',
          color: const Color(0xFF67E8F9),
          onPressed: openFleetDetail,
        ),
        if (canRecoverCoverage)
          _fleetActionButton(
            key: ValueKey('tactical-fleet-resync-${scope.siteId}'),
            label: 'Resync',
            color: const Color(0xFFFCA5A5),
            onPressed: recoverFleetScope,
          ),
        if (hasTacticalLane)
          _fleetActionButton(
            key: ValueKey('tactical-fleet-tactical-${scope.siteId}'),
            label: 'Tactical',
            color: const Color(0xFF8FD1FF),
            onPressed: openFleetTactical,
          ),
        if (hasDispatchLane)
          _fleetActionButton(
            key: ValueKey('tactical-fleet-dispatch-${scope.siteId}'),
            label: 'Dispatch',
            color: const Color(0xFFFDE68A),
            onPressed: openFleetDispatch,
          ),
      ],
      statusDetailText: scope.limitedWatchStatusDetailText,
      noteText: scope.noteText,
      latestText: prominentLatestTextForWatchAction(
        scope,
        activeWatchActionDrilldown,
      ),
      onLatestTap: openFleetDetail,
      onTap: hasTacticalLane
          ? openFleetTactical
          : hasDispatchLane
          ? openFleetDispatch
          : openFleetDetail,
      decoration: BoxDecoration(
        color: const Color(0xFF101D31),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF23344C)),
      ),
      constraints: const BoxConstraints(minWidth: 230, maxWidth: 320),
    );
  }

  Color _fleetScopeCommandAccent(VideoFleetScopeHealthView scope) {
    if (scope.hasWatchActivationGap) {
      return const Color(0xFFFCA5A5);
    }
    if (scope.identityPolicyChipValue != null) {
      return identityPolicyAccentColorForScope(scope);
    }
    if (scope.escalationCount > 0) {
      return const Color(0xFFFCA5A5);
    }
    if (scope.alertCount > 0) {
      return const Color(0xFF67E8F9);
    }
    if (scope.repeatCount > 0) {
      return const Color(0xFFFDE68A);
    }
    if (scope.latestRiskScore != null) {
      return _fleetRiskColor(scope.latestRiskScore!);
    }
    return _fleetFreshnessColor(scope);
  }

  String _fleetScopeCommandHeadline(VideoFleetScopeHealthView scope) {
    if (scope.hasWatchActivationGap) {
      return 'Coverage resync needed';
    }
    if (scope.hasFlaggedIdentityPolicy) {
      return 'Flagged identity in lane';
    }
    if (scope.hasTemporaryIdentityPolicy) {
      return 'Temporary identity live';
    }
    if (scope.hasAllowlistedIdentityPolicy) {
      return 'Allowlisted identity cleared';
    }
    if (scope.escalationCount > 0) {
      return 'Escalation lane active';
    }
    if (scope.alertCount > 0) {
      return 'Alert lane active';
    }
    if (scope.repeatCount > 0) {
      return 'Repeat monitoring lane';
    }
    if (scope.hasIncidentContext) {
      return 'Incident-backed watch scope';
    }
    if (scope.hasRecentRecovery) {
      return 'Recovered watch stabilized';
    }
    return 'Monitoring scope ready';
  }

  String _fleetScopeCommandDetail(VideoFleetScopeHealthView scope) {
    final candidates = <String?>[
      scope.latestActionHistoryText,
      scope.identityMatchText,
      scope.sceneDecisionText,
      scope.sceneReviewText,
      scope.latestSummaryText,
      scope.latestSuppressedHistoryText,
      scope.identityPolicyText,
      scope.clientDecisionText,
      scope.noteText?.split('\n').first,
    ];
    for (final candidate in candidates) {
      final detail = (candidate ?? '').trim();
      if (detail.isNotEmpty) {
        return detail;
      }
    }
    if (scope.hasIncidentContext) {
      return 'Incident-linked watch context is available for ${scope.siteName}.';
    }
    if (scope.hasWatchActivationGap) {
      return 'The watch window missed its expected start and needs operator recovery.';
    }
    return 'Scope telemetry is stable and ready for drill-in.';
  }

  VideoFleetWatchActionDrilldown? _recommendedFleetSummaryDrilldown(
    VideoFleetScopeHealthSections sections,
  ) {
    for (final drilldown in _availableFleetSummaryDrilldowns(sections)) {
      return drilldown;
    }
    return null;
  }

  List<VideoFleetWatchActionDrilldown> _availableFleetSummaryDrilldowns(
    VideoFleetScopeHealthSections sections,
  ) {
    const ordered = [
      VideoFleetWatchActionDrilldown.alerts,
      VideoFleetWatchActionDrilldown.limited,
      VideoFleetWatchActionDrilldown.flaggedIdentity,
      VideoFleetWatchActionDrilldown.temporaryIdentity,
      VideoFleetWatchActionDrilldown.escalated,
      VideoFleetWatchActionDrilldown.repeat,
      VideoFleetWatchActionDrilldown.filtered,
      VideoFleetWatchActionDrilldown.allowlistedIdentity,
    ];
    return ordered
        .where(
          (drilldown) => _fleetSummaryDrilldownCount(sections, drilldown) > 0,
        )
        .toList(growable: false);
  }

  int _fleetSummaryDrilldownCount(
    VideoFleetScopeHealthSections sections,
    VideoFleetWatchActionDrilldown drilldown,
  ) {
    return switch (drilldown) {
      VideoFleetWatchActionDrilldown.limited => sections.limitedCount,
      VideoFleetWatchActionDrilldown.alerts => sections.alertActionCount,
      VideoFleetWatchActionDrilldown.repeat => sections.repeatActionCount,
      VideoFleetWatchActionDrilldown.escalated =>
        sections.escalationActionCount,
      VideoFleetWatchActionDrilldown.filtered => sections.suppressedActionCount,
      VideoFleetWatchActionDrilldown.flaggedIdentity =>
        sections.flaggedIdentityCount,
      VideoFleetWatchActionDrilldown.temporaryIdentity =>
        sections.temporaryIdentityCount,
      VideoFleetWatchActionDrilldown.allowlistedIdentity =>
        sections.allowlistedIdentityCount,
    };
  }

  List<Widget> _fleetSummaryChips({
    required VideoFleetScopeHealthSections sections,
    required VideoFleetWatchActionDrilldown? activeWatchActionDrilldown,
    required void Function(VideoFleetWatchActionDrilldown drilldown)
    onOpenWatchActionDrilldown,
  }) {
    return [
      _fleetSummaryTile(
        key: const ValueKey('tactical-fleet-summary-tile-active'),
        'Active',
        '${sections.activeCount}',
        detail: 'Live or limited watch lanes',
        accent: const Color(0xFF8FD1FF),
      ),
      _fleetSummaryTile(
        key: const ValueKey('tactical-fleet-summary-tile-limited'),
        'Limited',
        '${sections.limitedCount}',
        detail: 'Remote monitoring constrained',
        accent: const Color(0xFFFBBF24),
        isActive:
            activeWatchActionDrilldown ==
            VideoFleetWatchActionDrilldown.limited,
        onTap: sections.limitedCount > 0
            ? () => onOpenWatchActionDrilldown(
                VideoFleetWatchActionDrilldown.limited,
              )
            : null,
      ),
      _fleetSummaryTile(
        key: const ValueKey('tactical-fleet-summary-tile-gap'),
        'Gap',
        '${sections.gapCount}',
        detail: 'Watch starts missed or delayed',
        accent: const Color(0xFFFCA5A5),
      ),
      _fleetSummaryTile(
        key: const ValueKey('tactical-fleet-summary-tile-high-risk'),
        'High Risk',
        '${sections.highRiskCount}',
        detail: '70+ risk scopes in rail',
        accent: const Color(0xFFFCA5A5),
      ),
      _fleetSummaryTile(
        key: const ValueKey('tactical-fleet-summary-tile-recovered'),
        'Recovered 6h',
        '${sections.recoveredCount}',
        detail: 'Recent operator recovery passes',
        accent: const Color(0xFF86EFAC),
      ),
      _fleetSummaryTile(
        key: const ValueKey('tactical-fleet-summary-tile-suppressed'),
        'Suppressed',
        '${sections.suppressedCount}',
        detail: 'Quiet filtered watch reviews',
        accent: const Color(0xFF9AB1CF),
      ),
      _fleetSummaryTile(
        key: const ValueKey('tactical-fleet-summary-tile-alerts'),
        'Alerts',
        '${sections.alertActionCount}',
        detail: 'Client alerts sent from rail',
        accent: const Color(0xFF67E8F9),
        isActive:
            activeWatchActionDrilldown == VideoFleetWatchActionDrilldown.alerts,
        onTap: sections.alertActionCount > 0
            ? () => onOpenWatchActionDrilldown(
                VideoFleetWatchActionDrilldown.alerts,
              )
            : null,
      ),
      _fleetSummaryTile(
        key: const ValueKey('tactical-fleet-summary-tile-repeat'),
        'Repeat',
        '${sections.repeatActionCount}',
        detail: 'Monitoring loops still repeating',
        accent: const Color(0xFFFDE68A),
        isActive:
            activeWatchActionDrilldown == VideoFleetWatchActionDrilldown.repeat,
        onTap: sections.repeatActionCount > 0
            ? () => onOpenWatchActionDrilldown(
                VideoFleetWatchActionDrilldown.repeat,
              )
            : null,
      ),
      _fleetSummaryTile(
        key: const ValueKey('tactical-fleet-summary-tile-escalated'),
        'Escalated',
        '${sections.escalationActionCount}',
        detail: 'Reviews pushed into escalation',
        accent: const Color(0xFFFCA5A5),
        isActive:
            activeWatchActionDrilldown ==
            VideoFleetWatchActionDrilldown.escalated,
        onTap: sections.escalationActionCount > 0
            ? () => onOpenWatchActionDrilldown(
                VideoFleetWatchActionDrilldown.escalated,
              )
            : null,
      ),
      _fleetSummaryTile(
        key: const ValueKey('tactical-fleet-summary-tile-filtered'),
        'Filtered',
        '${sections.suppressedActionCount}',
        detail: 'Below-threshold review holds',
        accent: const Color(0xFF9AB1CF),
        isActive:
            activeWatchActionDrilldown ==
            VideoFleetWatchActionDrilldown.filtered,
        onTap: sections.suppressedActionCount > 0
            ? () => onOpenWatchActionDrilldown(
                VideoFleetWatchActionDrilldown.filtered,
              )
            : null,
      ),
      _fleetSummaryTile(
        key: const ValueKey('tactical-fleet-summary-tile-flagged-id'),
        'Flagged ID',
        '${sections.flaggedIdentityCount}',
        detail: 'Flagged face or plate matches',
        accent: VideoFleetWatchActionDrilldown.flaggedIdentity.accentColor,
        isActive:
            activeWatchActionDrilldown ==
            VideoFleetWatchActionDrilldown.flaggedIdentity,
        onTap: sections.flaggedIdentityCount > 0
            ? () => onOpenWatchActionDrilldown(
                VideoFleetWatchActionDrilldown.flaggedIdentity,
              )
            : null,
      ),
      _fleetSummaryTile(
        key: const ValueKey('tactical-fleet-summary-tile-temporary-id'),
        'Temporary ID',
        '${sections.temporaryIdentityCount}',
        detail: 'One-time approved identities',
        accent: temporaryIdentityAccentColorForScopes(fleetScopeHealth),
        isActive:
            activeWatchActionDrilldown ==
            VideoFleetWatchActionDrilldown.temporaryIdentity,
        onTap: sections.temporaryIdentityCount > 0
            ? () => onOpenWatchActionDrilldown(
                VideoFleetWatchActionDrilldown.temporaryIdentity,
              )
            : null,
      ),
      _fleetSummaryTile(
        key: const ValueKey('tactical-fleet-summary-tile-allowed-id'),
        'Allowed ID',
        '${sections.allowlistedIdentityCount}',
        detail: 'Allowlisted identity clears',
        accent: VideoFleetWatchActionDrilldown.allowlistedIdentity.accentColor,
        isActive:
            activeWatchActionDrilldown ==
            VideoFleetWatchActionDrilldown.allowlistedIdentity,
        onTap: sections.allowlistedIdentityCount > 0
            ? () => onOpenWatchActionDrilldown(
                VideoFleetWatchActionDrilldown.allowlistedIdentity,
              )
            : null,
      ),
      _fleetSummaryTile(
        key: const ValueKey('tactical-fleet-summary-tile-stale'),
        'Stale',
        '${sections.staleCount}',
        detail: 'Feeds aging beyond fresh window',
        accent: const Color(0xFFFDE68A),
      ),
      _fleetSummaryTile(
        key: const ValueKey('tactical-fleet-summary-tile-no-incident'),
        'No Incident',
        '${sections.noIncidentCount}',
        detail: 'Telemetry without linked incident',
        accent: const Color(0xFF9AB1CF),
      ),
    ];
  }

  Widget _fleetSummaryTile(
    String label,
    String value, {
    required String detail,
    required Color accent,
    bool isActive = false,
    VoidCallback? onTap,
    Key? key,
  }) {
    final title = '$label • $value';
    final tile = Container(
      constraints: const BoxConstraints(minWidth: 144, maxWidth: 176),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isActive
            ? accent.withValues(alpha: 0.16)
            : _tacticalAltSurfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive
              ? accent.withValues(alpha: 0.6)
              : accent.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    color: isActive ? accent : _tacticalTitleColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: accent.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    'FOCUSED',
                    style: GoogleFonts.inter(
                      color: accent,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            detail,
            style: GoogleFonts.inter(
              color: _tacticalBodyColor,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
    if (onTap == null) {
      return KeyedSubtree(key: key, child: tile);
    }
    return Material(
      key: key,
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: tile,
      ),
    );
  }

  Widget _fleetActionButton({
    Key? key,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      key: key,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.45)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        textStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700),
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
    bool compactDetails = false,
  }) {
    final summaryLine = compactDetails
        ? '$videoOpsLabel: $cctvCapabilitySummary • $cctvRecentSignalSummary'
        : '$videoOpsLabel Caps: $cctvCapabilitySummary';
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compactDetails ? 5 : 6),
      decoration: BoxDecoration(
        color: _tacticalSurfaceColor,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _tacticalBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: compactDetails ? 4 : 5,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'TACTICAL OVERVIEW',
                style: GoogleFonts.inter(
                  color: _tacticalMutedColor,
                  fontSize: compactDetails ? 8 : 8.5,
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
          SizedBox(height: compactDetails ? 3 : 4),
          Text(
            summaryLine,
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontSize: compactDetails ? 8.5 : 9,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!compactDetails) ...[
            const SizedBox(height: 3),
            Text(
              '$videoOpsLabel Recent: $cctvRecentSignalSummary',
              style: GoogleFonts.inter(
                color: const Color(0xFF8EA4C2),
                fontSize: 8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0x141C3C57),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0x4435506F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Scope focus active',
            style: GoogleFonts.inter(
              color: const Color(0xFF8FD1FF),
              fontSize: 7.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            scopeLabel,
            style: GoogleFonts.inter(
              color: const Color(0xFFEAF4FF),
              fontSize: 7.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
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
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapPanel({
    required BuildContext buildContext,
    required List<_MapMarker> markers,
    required LatLngBounds mapBounds,
    required _MapMarker? activeMarker,
    required double zoom,
    required MapController mapController,
    required _TacticalMapFilter activeFilter,
    required _VerificationQueueTab activeQueueTab,
    required ValueChanged<String> onSelectMarker,
    required VoidCallback onZoomIn,
    required VoidCallback onZoomOut,
    required VoidCallback onCenterActive,
    required VoidCallback onCycleFilter,
    required ValueChanged<_VerificationQueueTab> onSetQueueTab,
    required VoidCallback? onOpenDispatches,
    required String focusReference,
    required _FocusLinkState focusState,
    required int geofenceAlerts,
    required int sosAlerts,
    bool connectingToLiveData = false,
  }) {
    final triggerSos = _geofences
        .where((fence) {
          return fence.status == _FenceStatus.breach ||
              (fence.stationaryTime ?? 0) > 120;
        })
        .toList(growable: false);
    final viewportWidth = MediaQuery.sizeOf(buildContext).width;
    final mapHeight = viewportWidth >= 1400
        ? 484.0
        : viewportWidth >= 1000
        ? 456.0
        : 400.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _tacticalSurfaceColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _tacticalBorderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TACTICAL MAP',
            style: GoogleFonts.inter(
              color: _tacticalMutedColor,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Guard pings, vehicle routes, incident markers, and 50m safety geofences.',
            style: GoogleFonts.inter(
              color: _tacticalBodyColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          if (activeMarker != null)
            _activeTrackSummaryCard(
              marker: activeMarker,
              activeFilter: activeFilter,
              activeQueueTab: activeQueueTab,
              onSetQueueTab: onSetQueueTab,
              onCenterActive: onCenterActive,
              onOpenDispatches: onOpenDispatches,
              focusReference: focusReference,
              focusState: focusState,
            ),
          const SizedBox(height: 6),
          SizedBox(
            height: mapHeight,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: FlutterMap(
                      mapController: mapController,
                      key: const ValueKey('tactical-map'),
                      options: MapOptions(
                        initialCenter:
                            activeMarker?.point ?? _mapBoundsCenter(mapBounds),
                        initialZoom: _mapZoomLevelForBounds(
                          mapBounds: mapBounds,
                          zoomScale: zoom,
                        ),
                        maxZoom: 18,
                        minZoom: 10,
                        backgroundColor: const Color(0xFF08101A),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'omnix_dashboard',
                        ),
                        MarkerLayer(
                          markers: markers
                              .where((marker) => marker.type == _MarkerType.site)
                              .map(
                                (marker) => _markerOverlay(
                                  marker: marker,
                                  selected: activeMarker?.id == marker.id,
                                  onTap: () => onSelectMarker(marker.id),
                                ),
                              )
                              .toList(growable: false),
                        ),
                        MarkerLayer(
                          markers: markers
                              .where(
                                (marker) =>
                                    marker.type == _MarkerType.guard ||
                                    marker.type == _MarkerType.vehicle,
                              )
                              .map(
                                (marker) => _markerOverlay(
                                  marker: marker,
                                  selected: activeMarker?.id == marker.id,
                                  onTap: () => onSelectMarker(marker.id),
                                ),
                              )
                              .toList(growable: false),
                        ),
                        MarkerLayer(
                          markers: markers
                              .where(
                                (marker) => marker.type == _MarkerType.incident,
                              )
                              .map(
                                (marker) => _markerOverlay(
                                  marker: marker,
                                  selected: activeMarker?.id == marker.id,
                                  onTap: () => onSelectMarker(marker.id),
                                ),
                              )
                              .toList(growable: false),
                        ),
                        MarkerLayer(
                          markers: _geofences
                              .map((fence) => _fenceOverlay(fence: fence))
                              .toList(growable: false),
                        ),
                      ],
                    ),
                  ),
                  if (focusReference.isNotEmpty)
                    Positioned(
                      right: 10,
                      top: triggerSos.isNotEmpty ? 52 : 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _focusStateColor(
                            focusState,
                          ).withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
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
                            fontSize: 9,
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
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x33EF4444),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0x99EF4444),
                          ),
                        ),
                        child: Text(
                          'SOS TRIGGER • ${triggerSos.length} geofence anomalies',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFFFB8C1),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  if (connectingToLiveData && markers.isEmpty)
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xCC08101A),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F1E2E),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _tacticalStrongBorderColor,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF8EC8FF),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Connecting to live data\u2026',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF8EC8FF),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (!connectingToLiveData && markers.isEmpty)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xF6FFFFFF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _tacticalStrongBorderColor,
                          ),
                        ),
                        child: Text(
                          'No markers match the ${_mapFilterLabel(activeFilter).toLowerCase()} filter.',
                          style: GoogleFonts.inter(
                            color: _tacticalBodyColor,
                            fontSize: 10,
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
                      spacing: 6,
                      runSpacing: 5,
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
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _MapControlChip(
                key: const ValueKey('tactical-map-zoom-in-button'),
                label: 'Zoom +',
                onTap: onZoomIn,
              ),
              _MapControlChip(
                key: const ValueKey('tactical-map-zoom-out-button'),
                label: 'Zoom -',
                onTap: onZoomOut,
              ),
              _MapControlChip(
                key: const ValueKey('tactical-map-center-button'),
                label: 'Center Active',
                active: activeMarker != null,
                onTap: onCenterActive,
              ),
              _MapControlChip(
                key: const ValueKey('tactical-map-filter-button'),
                label: 'Filter: ${_mapFilterLabel(activeFilter)}',
                active: activeFilter != _TacticalMapFilter.all,
                onTap: onCycleFilter,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'ACTIVE TRACKS',
            style: GoogleFonts.inter(
              color: _tacticalMutedColor,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          if (markers.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _tacticalAltSurfaceColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _tacticalBorderColor),
              ),
              child: Text(
                'Cycle the map filter or center on the active incident to restore tactical tracks.',
                style: GoogleFonts.inter(
                  color: _tacticalBodyColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: markers
                  .map(
                    (marker) => _markerLaneCard(
                      marker: marker,
                      selected: marker.id == activeMarker?.id,
                      onTap: () => onSelectMarker(marker.id),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }

  List<_MapMarker> _filteredMarkers(
    List<_MapMarker> markers,
    _TacticalMapFilter filter,
  ) {
    return markers
        .where((marker) {
          return switch (filter) {
            _TacticalMapFilter.all => true,
            _TacticalMapFilter.responding =>
              marker.status == _MarkerStatus.responding ||
                  marker.status == _MarkerStatus.sos,
            _TacticalMapFilter.incidents =>
              marker.type == _MarkerType.incident ||
                  marker.status == _MarkerStatus.sos,
          };
        })
        .toList(growable: false);
  }

  _MapMarker? _preferredMarker(
    List<_MapMarker> markers, {
    required String focusReference,
  }) {
    if (markers.isEmpty) {
      return null;
    }
    if (focusReference.isNotEmpty) {
      for (final marker in markers) {
        if (marker.id == focusReference) {
          return marker;
        }
      }
    }
    for (final marker in markers) {
      if (marker.type == _MarkerType.incident) {
        return marker;
      }
    }
    for (final marker in markers) {
      if (marker.status == _MarkerStatus.responding ||
          marker.status == _MarkerStatus.sos) {
        return marker;
      }
    }
    return markers.first;
  }

  _MapMarker? _activeMarkerFor({
    required List<_MapMarker> markers,
    required String? selectedMarkerId,
    required String focusReference,
  }) {
    for (final marker in markers) {
      if (marker.id == selectedMarkerId) {
        return marker;
      }
    }
    return _preferredMarker(markers, focusReference: focusReference);
  }

  LatLng _mapBoundsCenter(LatLngBounds bounds) {
    return LatLng(
      (bounds.south + bounds.north) / 2,
      (bounds.west + bounds.east) / 2,
    );
  }

  double _mapZoomLevelForBounds({
    required LatLngBounds mapBounds,
    required double zoomScale,
  }) {
    final span = math.max(
      (mapBounds.north - mapBounds.south).abs(),
      (mapBounds.east - mapBounds.west).abs(),
    );
    final baseZoom = switch (span) {
      <= 0.004 => 16.0,
      <= 0.008 => 15.0,
      <= 0.015 => 14.0,
      <= 0.04 => 13.0,
      <= 0.08 => 12.0,
      _ => 11.0,
    };
    return (baseZoom + (zoomScale - 1.0) * 5.0).clamp(10.0, 18.0);
  }

  String _mapFilterLabel(_TacticalMapFilter filter) {
    return switch (filter) {
      _TacticalMapFilter.all => 'All',
      _TacticalMapFilter.responding => 'Responding',
      _TacticalMapFilter.incidents => 'Incidents',
    };
  }

  Widget _activeTrackSummaryCard({
    required _MapMarker marker,
    required _TacticalMapFilter activeFilter,
    required _VerificationQueueTab activeQueueTab,
    required ValueChanged<_VerificationQueueTab> onSetQueueTab,
    required VoidCallback onCenterActive,
    required VoidCallback? onOpenDispatches,
    required String focusReference,
    required _FocusLinkState focusState,
  }) {
    final accent = _markerColor(marker.type, marker.status);
    final detail =
        marker.eta ??
        marker.priority ??
        (marker.lastPing == null
            ? 'Telemetry synced'
            : 'Ping ${marker.lastPing}');
    final focusLabel = focusReference.trim().isEmpty
        ? 'No routed focus'
        : '${_focusStateLabel(focusState)} • $focusReference';
    return Container(
      key: const ValueKey('tactical-active-track-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          accent.withValues(alpha: 0.08),
          _tacticalSurfaceColor,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.48)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: 0.45)),
                ),
                child: Icon(
                  switch (marker.type) {
                    _MarkerType.guard => Icons.person_pin_circle_rounded,
                    _MarkerType.vehicle => Icons.directions_car_filled_rounded,
                    _MarkerType.incident => Icons.warning_amber_rounded,
                    _MarkerType.site => Icons.apartment_rounded,
                  },
                  color: accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MAP FOCUS • ${_verificationQueueWorkspaceLabel(activeQueueTab).toUpperCase()} QUEUE',
                      style: GoogleFonts.inter(
                        color: accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      marker.label,
                      key: const ValueKey('tactical-active-track-label'),
                      style: GoogleFonts.inter(
                        color: _tacticalTitleColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_markerStatusLabel(marker)} • $detail',
                      style: GoogleFonts.inter(
                        color: _tacticalBodyColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'The selected track stays pinned while map routing, verification queues, and dispatch handoff remain one tap away.',
            style: GoogleFonts.inter(
              color: _tacticalBodyColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _topChip(
                _mapFilterLabel(activeFilter),
                _markerStatusLabel(marker),
                accent,
              ),
              _topChip(
                'Queue',
                _verificationQueueWorkspaceLabel(activeQueueTab),
                const Color(0xFF8FD1FF),
              ),
              _topChip('Focus', focusLabel, _focusStateColor(focusState)),
              if (marker.battery != null)
                _topChip(
                  'Battery',
                  '${marker.battery}%',
                  marker.battery! < 20
                      ? const Color(0xFFFACC15)
                      : const Color(0xFFA7F3D0),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _tacticalWorkspaceActionChip(
                key: const ValueKey('tactical-map-focus-center-track'),
                label: 'Center track',
                foreground: const Color(0xFFFDE68A),
                background: const Color(0x14FDE68A),
                border: const Color(0x66FDE68A),
                onTap: onCenterActive,
              ),
              _tacticalWorkspaceActionChip(
                key: const ValueKey('tactical-map-focus-queue-anomalies'),
                label: 'Anomalies',
                foreground: const Color(0xFFFF99A8),
                background: const Color(0x14FF99A8),
                border: const Color(0x66FF99A8),
                onTap: () => onSetQueueTab(_VerificationQueueTab.anomalies),
              ),
              _tacticalWorkspaceActionChip(
                key: const ValueKey('tactical-map-focus-queue-matches'),
                label: 'Matches',
                foreground: const Color(0xFF8FD1FF),
                background: const Color(0x148FD1FF),
                border: const Color(0x668FD1FF),
                onTap: () => onSetQueueTab(_VerificationQueueTab.matches),
              ),
              _tacticalWorkspaceActionChip(
                key: const ValueKey('tactical-map-focus-queue-assets'),
                label: 'Assets',
                foreground: const Color(0xFFA7F3D0),
                background: const Color(0x14A7F3D0),
                border: const Color(0x66A7F3D0),
                onTap: () => onSetQueueTab(_VerificationQueueTab.assets),
              ),
              if (onOpenDispatches != null)
                _tacticalWorkspaceActionChip(
                  key: const ValueKey('tactical-map-focus-open-dispatches'),
                  label: 'OPEN DISPATCH BOARD',
                  foreground: const Color(0xFFDCD4FF),
                  background: const Color(0x147C3AED),
                  border: const Color(0x667C3AED),
                  onTap: onOpenDispatches,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _markerLaneCard({
    required _MapMarker marker,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final accent = _markerColor(marker.type, marker.status);
    return InkWell(
      key: ValueKey<String>('tactical-marker-card-${marker.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 180,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? Color.alphaBlend(
                  accent.withValues(alpha: 0.1),
                  _tacticalSurfaceColor,
                )
              : _tacticalSurfaceColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.72)
                : _tacticalBorderColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              marker.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: _tacticalTitleColor,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _markerStatusLabel(marker),
              style: GoogleFonts.inter(
                color: accent,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              marker.eta ??
                  marker.priority ??
                  (marker.lastPing == null
                      ? 'Telemetry synced'
                      : marker.lastPing!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: const Color(0xFF9AB1CF),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
      final incidentDispatchReference = dispatchId.startsWith('INC-')
          ? dispatchId
          : dispatchId.isEmpty
          ? ''
          : 'INC-$dispatchId';
      if (event.eventId.trim() != normalizedReference &&
          dispatchId != normalizedReference &&
          incidentDispatchReference != normalizedReference &&
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
    required String scopeClientId,
    required String scopeSiteId,
  }) {
    final liveMarkers = <_MapMarker>[
      ..._resolvedSiteMarkers(
        scopeClientId: scopeClientId,
        scopeSiteId: scopeSiteId,
      ),
      ..._resolvedGuardMarkers(
        scopeClientId: scopeClientId,
        scopeSiteId: scopeSiteId,
      ),
      ..._resolvedIncidentMarkers(
        scopeClientId: scopeClientId,
        scopeSiteId: scopeSiteId,
      ),
    ];
    final baseMarkers = liveMarkers.isEmpty ? _markers : liveMarkers;
    if (focusReference.isEmpty || focusState != _FocusLinkState.seeded) {
      return baseMarkers;
    }
    return [
      _MapMarker(
        id: focusReference,
        type: _MarkerType.incident,
        point: _seededFocusPoint(baseMarkers),
        label: focusReference,
        status: _MarkerStatus.sos,
        priority: 'P2-SEEDED',
      ),
      ...baseMarkers,
    ];
  }

  List<_MapMarker> _resolvedSiteMarkers({
    required String scopeClientId,
    required String scopeSiteId,
  }) {
    final scoped = siteMarkers.where((site) {
      final siteClientId = site.clientId.trim();
      if (scopeClientId.isNotEmpty && siteClientId != scopeClientId) {
        return false;
      }
      if (scopeSiteId.isNotEmpty && site.id.trim() != scopeSiteId) {
        return false;
      }
      return true;
    }).toList(growable: false);
    return scoped
        .map(
          (site) => _MapMarker(
            id: site.id.trim().isEmpty ? site.code : site.id.trim(),
            type: _MarkerType.site,
            point: LatLng(site.lat, site.lng),
            label: site.name.trim().isEmpty ? site.code : site.name.trim(),
            status: _MarkerStatus.staticMarker,
          ),
        )
        .toList(growable: false);
  }

  List<_MapMarker> _resolvedGuardMarkers({
    required String scopeClientId,
    required String scopeSiteId,
  }) {
    final scoped = guardPositions.where((position) {
      if (scopeClientId.isNotEmpty &&
          position.clientId.trim() != scopeClientId) {
        return false;
      }
      if (scopeSiteId.isNotEmpty && position.siteId.trim() != scopeSiteId) {
        return false;
      }
      return true;
    });
    return scoped
        .map(
          (position) => _MapMarker(
            id: position.guardId,
            type: _MarkerType.guard,
            point: LatLng(position.latitude, position.longitude),
            label: position.guardId,
            status: _MarkerStatus.active,
            lastPing: _guardPositionTimestampLabel(position.recordedAtUtc),
          ),
        )
        .toList(growable: false);
  }

  List<_MapMarker> _resolvedIncidentMarkers({
    required String scopeClientId,
    required String scopeSiteId,
  }) {
    final sitePointByScope = <String, LatLng>{
      for (final site in siteMarkers)
        _siteScopeKey(site.clientId, site.id): LatLng(site.lat, site.lng),
    };
    final latestByReference = <String, DispatchEvent>{};
    for (final event in events) {
      final scope = _scopeForEvent(event);
      if (scope == null) {
        continue;
      }
      if (scopeClientId.isNotEmpty && scope.clientId != scopeClientId) {
        continue;
      }
      if (scopeSiteId.isNotEmpty && scope.siteId != scopeSiteId) {
        continue;
      }
      final reference = _eventIncidentReference(event);
      final existing = latestByReference[reference];
      if (existing == null || event.occurredAt.isAfter(existing.occurredAt)) {
        latestByReference[reference] = event;
      }
    }
    final orderedEvents = latestByReference.values.toList(growable: false)
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return orderedEvents.asMap().entries.map((entry) {
      final event = entry.value;
      final scope = _scopeForEvent(event)!;
      final sitePoint =
          sitePointByScope[_siteScopeKey(scope.clientId, scope.siteId)] ??
          _johannesburgCenter;
      final offsetPoint = _offsetIncidentPoint(sitePoint, entry.key);
      return _MapMarker(
        id: _eventIncidentReference(event),
        type: _MarkerType.incident,
        point: offsetPoint,
        label: _eventIncidentReference(event),
        status: event is IncidentClosed
            ? _MarkerStatus.staticMarker
            : _MarkerStatus.sos,
        priority: _eventIncidentPriority(event),
      );
    }).toList(growable: false);
  }

  String _siteScopeKey(String clientId, String siteId) =>
      '${clientId.trim()}::${siteId.trim()}';

  ({String clientId, String siteId})? _scopeForEvent(DispatchEvent event) {
    final clientId = switch (event) {
      DecisionCreated value => value.clientId.trim(),
      ResponseArrived value => value.clientId.trim(),
      PartnerDispatchStatusDeclared value => value.clientId.trim(),
      ExecutionCompleted value => value.clientId.trim(),
      ExecutionDenied value => value.clientId.trim(),
      IncidentClosed value => value.clientId.trim(),
      IntelligenceReceived value => value.clientId.trim(),
      _ => '',
    };
    final siteId = switch (event) {
      DecisionCreated value => value.siteId.trim(),
      ResponseArrived value => value.siteId.trim(),
      PartnerDispatchStatusDeclared value => value.siteId.trim(),
      ExecutionCompleted value => value.siteId.trim(),
      ExecutionDenied value => value.siteId.trim(),
      IncidentClosed value => value.siteId.trim(),
      IntelligenceReceived value => value.siteId.trim(),
      _ => '',
    };
    if (clientId.isEmpty || siteId.isEmpty) {
      return null;
    }
    return (clientId: clientId, siteId: siteId);
  }

  String _eventIncidentReference(DispatchEvent event) {
    return switch (event) {
      DecisionCreated value => _incidentReferenceFromDispatchId(
        value.dispatchId,
        fallback: value.eventId,
      ),
      ResponseArrived value => _incidentReferenceFromDispatchId(
        value.dispatchId,
        fallback: value.eventId,
      ),
      PartnerDispatchStatusDeclared value => _incidentReferenceFromDispatchId(
        value.dispatchId,
        fallback: value.eventId,
      ),
      ExecutionCompleted value => _incidentReferenceFromDispatchId(
        value.dispatchId,
        fallback: value.eventId,
      ),
      ExecutionDenied value => _incidentReferenceFromDispatchId(
        value.dispatchId,
        fallback: value.eventId,
      ),
      IncidentClosed value => _incidentReferenceFromDispatchId(
        value.dispatchId,
        fallback: value.eventId,
      ),
      IntelligenceReceived value => value.intelligenceId.trim().isEmpty
          ? value.eventId
          : value.intelligenceId.trim(),
      _ => event.eventId,
    };
  }

  String _incidentReferenceFromDispatchId(
    String dispatchId, {
    required String fallback,
  }) {
    final normalized = dispatchId.trim();
    if (normalized.isEmpty) {
      return fallback;
    }
    return normalized.startsWith('INC-') ? normalized : 'INC-$normalized';
  }

  String _eventIncidentPriority(DispatchEvent event) {
    return switch (event) {
      ExecutionDenied _ => 'P1-DENIED',
      DecisionCreated _ => 'P1-ACTIVE',
      ResponseArrived _ => 'P2-RESPONDING',
      PartnerDispatchStatusDeclared _ => 'P2-PARTNER',
      ExecutionCompleted _ => 'P3-COMPLETED',
      IncidentClosed _ => 'RESOLVED',
      IntelligenceReceived _ => 'P2-INTEL',
      _ => 'P2-ACTIVE',
    };
  }

  String _guardPositionTimestampLabel(DateTime recordedAtUtc) {
    final utc = recordedAtUtc.toUtc();
    final hour = utc.hour.toString().padLeft(2, '0');
    final minute = utc.minute.toString().padLeft(2, '0');
    return '$hour:$minute UTC';
  }

  LatLng _offsetIncidentPoint(LatLng point, int offsetIndex) {
    final delta = 0.00035 * ((offsetIndex % 3) + 1);
    final latShift = offsetIndex.isEven ? delta : -delta;
    final lngShift = offsetIndex % 3 == 0 ? delta : -delta;
    return LatLng(point.latitude + latShift, point.longitude + lngShift);
  }

  LatLng _seededFocusPoint(List<_MapMarker> baseMarkers) {
    final incident = baseMarkers.where((marker) => marker.type == _MarkerType.incident);
    if (incident.isNotEmpty) {
      return incident.first.point;
    }
    final site = baseMarkers.where((marker) => marker.type == _MarkerType.site);
    if (site.isNotEmpty) {
      return site.first.point;
    }
    if (baseMarkers.isNotEmpty) {
      return baseMarkers.first.point;
    }
    return _johannesburgCenter;
  }

  LatLngBounds _mapBoundsForScope({
    required List<_MapMarker> markers,
    required String scopeClientId,
    required String scopeSiteId,
  }) {
    final scopedSites = siteMarkers.where((site) {
      if (scopeClientId.isNotEmpty && site.clientId.trim() != scopeClientId) {
        return false;
      }
      if (scopeSiteId.isNotEmpty && site.id.trim() != scopeSiteId) {
        return false;
      }
      return true;
    }).toList(growable: false);
    final points = <LatLng>[
      ...scopedSites.map((site) => LatLng(site.lat, site.lng)),
      ...markers.map((marker) => marker.point),
      ..._geofences.map((fence) => fence.point),
    ];
    if (points.isEmpty) {
      return LatLngBounds(
        LatLng(_johannesburgCenter.latitude - 0.01, _johannesburgCenter.longitude - 0.01),
        LatLng(_johannesburgCenter.latitude + 0.01, _johannesburgCenter.longitude + 0.01),
      );
    }
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final point in points.skip(1)) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }
    const padding = 0.0035;
    return LatLngBounds(
      LatLng(minLat - padding, minLng - padding),
      LatLng(maxLat + padding, maxLng + padding),
    );
  }


  Widget _verificationPanel({
    required String normMode,
    required String timestamp,
    required _CctvLensTelemetry telemetry,
    required _MapMarker? activeMarker,
    required _TacticalMapFilter activeFilter,
    required _VerificationQueueTab activeQueueTab,
    required VoidCallback onCenterActive,
    required ValueChanged<_VerificationQueueTab> onQueueTabChanged,
    required void Function(
      String message, {
      String label,
      String? detail,
      Color accent,
    })
    onShowFeedback,
    required VoidCallback? onOpenDispatches,
  }) {
    final matchScore = telemetry.suggestedMatchScore;
    final scoreColor = matchScore >= 95
        ? const Color(0xFF10B981)
        : matchScore >= 60
        ? const Color(0xFFFACC15)
        : const Color(0xFFEF4444);
    final queueAccent = switch (activeQueueTab) {
      _VerificationQueueTab.anomalies => const Color(0xFFFF99A8),
      _VerificationQueueTab.matches => const Color(0xFF8FD1FF),
      _VerificationQueueTab.assets => const Color(0xFFA7F3D0),
    };
    final focusAccent = activeMarker == null
        ? queueAccent
        : _markerColor(activeMarker.type, activeMarker.status);
    final activeDetail = activeMarker == null
        ? '${_mapFilterLabel(activeFilter)} filter active with no pinned track.'
        : '${_markerStatusLabel(activeMarker)} • ${activeMarker.eta ?? activeMarker.priority ?? (activeMarker.lastPing == null ? 'Telemetry synced' : 'Ping ${activeMarker.lastPing}')}';
    final activeLabel = activeMarker?.label ?? 'Verification queue standing by';
    final focusSupport = activeMarker == null
        ? 'Use the rail to shift anomaly, match, or asset review without leaving the map surface.'
        : 'The selected track stays pinned while lens review, queue pivots, and dispatch recovery remain one tap away.';
    final queueCount = switch (activeQueueTab) {
      _VerificationQueueTab.anomalies => _anomalies.length,
      _VerificationQueueTab.matches => telemetry.frMatches + telemetry.lprHits,
      _VerificationQueueTab.assets =>
        telemetry.snapshotsReady + telemetry.clipsReady,
    };
    final queueHeadline = switch (activeQueueTab) {
      _VerificationQueueTab.anomalies =>
        queueCount == 0
            ? 'No anomaly overlays are staged right now.'
            : 'Anomaly overlays are leading the current review window.',
      _VerificationQueueTab.matches =>
        queueCount == 0
            ? 'No FR or LPR matches are waiting in the review lane.'
            : 'Identity and plate matches are leading the current review window.',
      _VerificationQueueTab.assets =>
        queueCount == 0
            ? 'No exportable assets are staged in the verification lane.'
            : 'Snapshots and clips are staged for operator export.',
    };
    final queueSupport = switch (activeQueueTab) {
      _VerificationQueueTab.anomalies =>
        'Flagged overlays, recent signals, and the pinned track stay aligned in one anomaly review lane.',
      _VerificationQueueTab.matches =>
        'Match confidence, watchlist hits, and dispatch continuity stay pinned together for fast review.',
      _VerificationQueueTab.assets =>
        'Exportable snapshots, playback clips, and track context stay anchored in one asset queue.',
    };

    void openQueueWithFeedback(_VerificationQueueTab tab) {
      onQueueTabChanged(tab);
      final accent = switch (tab) {
        _VerificationQueueTab.anomalies => const Color(0xFFFF99A8),
        _VerificationQueueTab.matches => const Color(0xFF8FD1FF),
        _VerificationQueueTab.assets => const Color(0xFFA7F3D0),
      };
      final label = switch (tab) {
        _VerificationQueueTab.anomalies => 'ANOMALY QUEUE',
        _VerificationQueueTab.matches => 'MATCH QUEUE',
        _VerificationQueueTab.assets => 'ASSET QUEUE',
      };
      final queueLabel = _verificationQueueWorkspaceLabel(tab).toLowerCase();
      onShowFeedback(
        '${_verificationQueueWorkspaceLabel(tab)} queue foregrounded in verification rail.',
        label: label,
        detail:
            'The $queueLabel queue now leads the right-rail review stack while the active map board stays pinned.',
        accent: accent,
      );
    }

    void centerTrackWithFeedback() {
      if (activeMarker == null) {
        return;
      }
      onCenterActive();
      onShowFeedback(
        'Centered ${activeMarker.label} for verification review.',
        label: 'TRACK FOCUS',
        detail:
            '${activeMarker.label} stays pinned while the ${_verificationQueueWorkspaceLabel(activeQueueTab).toLowerCase()} queue remains foregrounded.',
        accent: const Color(0xFFFDE68A),
      );
    }

    void openDispatchesWithFeedback() {
      final action = onOpenDispatches;
      if (action == null) {
        return;
      }
      action();
      onShowFeedback(
        'Opened scoped dispatches from verification rail.',
        label: 'DISPATCH HANDOFF',
        detail:
            'The current tactical focus handed off into the scoped dispatch workspace.',
        accent: const Color(0xFFDCD4FF),
      );
    }

    final primaryActionLabel = switch (activeQueueTab) {
      _VerificationQueueTab.anomalies =>
        activeMarker == null ? 'Open matches' : 'Center track',
      _VerificationQueueTab.matches =>
        onOpenDispatches == null ? 'Open anomalies' : 'OPEN DISPATCH BOARD',
      _VerificationQueueTab.assets =>
        activeMarker == null ? 'Open matches' : 'Center track',
    };
    final primaryActionDetail = switch (activeQueueTab) {
      _VerificationQueueTab.anomalies =>
        activeMarker == null
            ? 'Shift the rail into identity and plate hits when the overlay lane is quiet.'
            : 'Recenter the pinned track before you continue through anomaly overlays.',
      _VerificationQueueTab.matches =>
        onOpenDispatches == null
            ? 'Return to anomaly overlays when dispatch handoff is not available.'
            : 'Hand the active tactical focus into the scoped dispatch workspace.',
      _VerificationQueueTab.assets =>
        activeMarker == null
            ? 'Pivot back into live hits when the asset queue is quiet.'
            : 'Recenter the pinned track before export or playback review.',
    };
    final primaryActionColor = switch (activeQueueTab) {
      _VerificationQueueTab.anomalies =>
        activeMarker == null
            ? const Color(0xFF8FD1FF)
            : const Color(0xFFFDE68A),
      _VerificationQueueTab.matches =>
        onOpenDispatches == null
            ? const Color(0xFFFF99A8)
            : const Color(0xFFDCD4FF),
      _VerificationQueueTab.assets =>
        activeMarker == null
            ? const Color(0xFF8FD1FF)
            : const Color(0xFFFDE68A),
    };
    final VoidCallback primaryAction = switch (activeQueueTab) {
      _VerificationQueueTab.anomalies =>
        activeMarker == null
            ? () => openQueueWithFeedback(_VerificationQueueTab.matches)
            : centerTrackWithFeedback,
      _VerificationQueueTab.matches =>
        onOpenDispatches == null
            ? () => openQueueWithFeedback(_VerificationQueueTab.anomalies)
            : openDispatchesWithFeedback,
      _VerificationQueueTab.assets =>
        activeMarker == null
            ? () => openQueueWithFeedback(_VerificationQueueTab.matches)
            : centerTrackWithFeedback,
    };
    final comparisonPrimaryTab = _anomalies.isNotEmpty
        ? _VerificationQueueTab.anomalies
        : (telemetry.frMatches + telemetry.lprHits) > 0
        ? _VerificationQueueTab.matches
        : _VerificationQueueTab.assets;
    final comparisonPrimaryColor = switch (comparisonPrimaryTab) {
      _VerificationQueueTab.anomalies => const Color(0xFFFF99A8),
      _VerificationQueueTab.matches => const Color(0xFF8FD1FF),
      _VerificationQueueTab.assets => const Color(0xFFA7F3D0),
    };
    final comparisonPrimaryLabel = switch (comparisonPrimaryTab) {
      _VerificationQueueTab.anomalies => 'Review anomaly lane',
      _VerificationQueueTab.matches => 'Review match lane',
      _VerificationQueueTab.assets => 'Review asset lane',
    };
    final comparisonSummary = _anomalies.isNotEmpty
        ? 'Live capture is ahead of baseline by ${_anomalies.length} flagged overlay${_anomalies.length == 1 ? '' : 's'}.'
        : (telemetry.frMatches + telemetry.lprHits) > 0
        ? 'Baseline is clean while live capture is surfacing identity and plate hits.'
        : 'Baseline and live capture are aligned, so the rail is staging export-ready evidence.';
    final comparisonSupport = _anomalies.isNotEmpty
        ? 'Compare the baseline and live frames, then push straight into the anomaly queue without leaving the verification rail.'
        : (telemetry.frMatches + telemetry.lprHits) > 0
        ? 'The norm/live pair stays visible while the operator pivots into match review and dispatch continuity.'
        : 'Even in a quiet compare state, the lens board keeps the asset queue and track context one move away.';
    final comparisonDriftLabel = _anomalies.isEmpty
        ? 'Aligned'
        : '${_anomalies.length} drift';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _tacticalSurfaceColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _tacticalBorderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'VERIFICATION LENS',
            style: GoogleFonts.inter(
              color: _tacticalMutedColor,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Baseline vs live capture with anomaly detection overlays.',
            style: GoogleFonts.inter(
              color: _tacticalBodyColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '$videoOpsLabel Ops • $cctvOpsReadiness • $cctvOpsDetail',
            style: GoogleFonts.inter(
              color: _tacticalMutedColor,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            key: const ValueKey('tactical-verification-focus-card'),
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: focusAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: focusAccent.withValues(alpha: 0.48)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: focusAccent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: focusAccent.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Icon(
                        activeMarker == null
                            ? Icons.center_focus_strong_rounded
                            : switch (activeMarker.type) {
                                _MarkerType.guard =>
                                  Icons.person_pin_circle_rounded,
                                _MarkerType.vehicle =>
                                  Icons.directions_car_filled_rounded,
                                _MarkerType.incident =>
                                  Icons.warning_amber_rounded,
                                _MarkerType.site => Icons.apartment_rounded,
                              },
                        color: focusAccent,
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'VERIFICATION FOCUS • ${_verificationQueueWorkspaceLabel(activeQueueTab).toUpperCase()} QUEUE',
                            style: GoogleFonts.inter(
                              color: focusAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            activeLabel,
                            key: const ValueKey(
                              'tactical-verification-focus-label',
                            ),
                            style: GoogleFonts.inter(
                              color: _tacticalTitleColor,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            activeDetail,
                            style: GoogleFonts.inter(
                              color: _tacticalBodyColor,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  focusSupport,
                  style: GoogleFonts.inter(
                    color: _tacticalBodyColor,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _topChip(
                      'Filter',
                      _mapFilterLabel(activeFilter),
                      focusAccent,
                    ),
                    _topChip(
                      'Queue',
                      _verificationQueueWorkspaceLabel(activeQueueTab),
                      queueAccent,
                    ),
                    _topChip('Score', '$matchScore%', scoreColor),
                    _topChip(
                      'Signals',
                      '${telemetry.totalSignals}',
                      const Color(0xFF9AB1CF),
                    ),
                    if (activeMarker?.battery != null)
                      _topChip(
                        'Battery',
                        '${activeMarker!.battery}%',
                        activeMarker.battery! < 20
                            ? const Color(0xFFFACC15)
                            : const Color(0xFFA7F3D0),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (activeMarker != null)
                      _tacticalWorkspaceActionChip(
                        key: const ValueKey(
                          'tactical-verification-focus-center-track',
                        ),
                        label: 'Center track',
                        foreground: const Color(0xFFFDE68A),
                        background: const Color(0x14FDE68A),
                        border: const Color(0x66FDE68A),
                        onTap: centerTrackWithFeedback,
                      ),
                    _tacticalWorkspaceActionChip(
                      key: const ValueKey(
                        'tactical-verification-focus-queue-anomalies',
                      ),
                      label: 'Anomalies',
                      foreground: const Color(0xFFFF99A8),
                      background: const Color(0x14FF99A8),
                      border: const Color(0x66FF99A8),
                      onTap: () => openQueueWithFeedback(
                        _VerificationQueueTab.anomalies,
                      ),
                    ),
                    _tacticalWorkspaceActionChip(
                      key: const ValueKey(
                        'tactical-verification-focus-queue-matches',
                      ),
                      label: 'Matches',
                      foreground: const Color(0xFF8FD1FF),
                      background: const Color(0x148FD1FF),
                      border: const Color(0x668FD1FF),
                      onTap: () =>
                          openQueueWithFeedback(_VerificationQueueTab.matches),
                    ),
                    _tacticalWorkspaceActionChip(
                      key: const ValueKey(
                        'tactical-verification-focus-queue-assets',
                      ),
                      label: 'Assets',
                      foreground: const Color(0xFFA7F3D0),
                      background: const Color(0x14A7F3D0),
                      border: const Color(0x66A7F3D0),
                      onTap: () =>
                          openQueueWithFeedback(_VerificationQueueTab.assets),
                    ),
                    if (onOpenDispatches != null)
                      _tacticalWorkspaceActionChip(
                        key: const ValueKey(
                          'tactical-verification-focus-open-dispatches',
                        ),
                        label: 'OPEN DISPATCH BOARD',
                        foreground: const Color(0xFFDCD4FF),
                        background: const Color(0x147C3AED),
                        border: const Color(0x667C3AED),
                        onTap: openDispatchesWithFeedback,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Container(
            key: const ValueKey('tactical-lens-comparison-board'),
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _tacticalSurfaceColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _tacticalBorderColor),
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
                            'LENS COMPARISON BOARD',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF8FD1FF),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            comparisonSummary,
                            style: GoogleFonts.inter(
                              color: _tacticalTitleColor,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            comparisonSupport,
                            style: GoogleFonts.inter(
                              color: _tacticalBodyColor,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: comparisonPrimaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: comparisonPrimaryColor.withValues(alpha: 0.42),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'RECOMMENDED MOVE',
                            style: GoogleFonts.inter(
                              color: comparisonPrimaryColor,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            comparisonPrimaryLabel,
                            style: GoogleFonts.inter(
                              color: _tacticalTitleColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
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
                      'Baseline',
                      normMode.toUpperCase(),
                      const Color(0xFF8EA4C2),
                    ),
                    _topChip('Live', timestamp, const Color(0xFFEF4444)),
                    _topChip(
                      'Drift',
                      comparisonDriftLabel,
                      _anomalies.isEmpty
                          ? const Color(0xFFA7F3D0)
                          : const Color(0xFFFF99A8),
                    ),
                    _topChip(
                      'Queue',
                      _verificationQueueWorkspaceLabel(activeQueueTab),
                      queueAccent,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
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
                        children: [
                          normFrame,
                          const SizedBox(height: 5),
                          liveFrame,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: normFrame),
                        const SizedBox(width: 5),
                        Expanded(child: liveFrame),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _tacticalWorkspaceActionChip(
                      key: const ValueKey(
                        'tactical-lens-comparison-review-anomalies',
                      ),
                      label: 'Review anomalies',
                      foreground: const Color(0xFFFF99A8),
                      background: const Color(0x14FF99A8),
                      border: const Color(0x66FF99A8),
                      onTap: () => openQueueWithFeedback(
                        _VerificationQueueTab.anomalies,
                      ),
                    ),
                    _tacticalWorkspaceActionChip(
                      key: const ValueKey(
                        'tactical-lens-comparison-review-matches',
                      ),
                      label: 'Review matches',
                      foreground: const Color(0xFF8FD1FF),
                      background: const Color(0x148FD1FF),
                      border: const Color(0x668FD1FF),
                      onTap: () =>
                          openQueueWithFeedback(_VerificationQueueTab.matches),
                    ),
                    _tacticalWorkspaceActionChip(
                      key: const ValueKey(
                        'tactical-lens-comparison-review-assets',
                      ),
                      label: 'Review assets',
                      foreground: const Color(0xFFA7F3D0),
                      background: const Color(0x14A7F3D0),
                      border: const Color(0x66A7F3D0),
                      onTap: () =>
                          openQueueWithFeedback(_VerificationQueueTab.assets),
                    ),
                    if (activeMarker != null)
                      _tacticalWorkspaceActionChip(
                        key: const ValueKey(
                          'tactical-lens-comparison-center-track',
                        ),
                        label: 'Center track',
                        foreground: const Color(0xFFFDE68A),
                        background: const Color(0x14FDE68A),
                        border: const Color(0x66FDE68A),
                        onTap: centerTrackWithFeedback,
                      ),
                    if (onOpenDispatches != null)
                      _tacticalWorkspaceActionChip(
                        key: const ValueKey(
                          'tactical-lens-comparison-open-dispatches',
                        ),
                        label: 'OPEN DISPATCH BOARD',
                        foreground: const Color(0xFFDCD4FF),
                        background: const Color(0x147C3AED),
                        border: const Color(0x667C3AED),
                        onTap: openDispatchesWithFeedback,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$videoOpsLabel Signal Counters (6h)',
            style: GoogleFonts.inter(
              color: _tacticalMutedColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            key: const ValueKey('tactical-verification-signal-counters'),
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
          const SizedBox(height: 6),
          Container(
            key: const ValueKey('tactical-verification-queue-board'),
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _tacticalSurfaceColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: queueAccent.withValues(alpha: 0.42)),
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
                            'QUEUE BOARD • ${_verificationQueueWorkspaceLabel(activeQueueTab).toUpperCase()} REVIEW',
                            style: GoogleFonts.inter(
                              color: queueAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            queueHeadline,
                            style: GoogleFonts.inter(
                              color: _tacticalTitleColor,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            queueSupport,
                            style: GoogleFonts.inter(
                              color: _tacticalBodyColor,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      key: const ValueKey('tactical-verification-score-card'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: scoreColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: scoreColor.withValues(alpha: 0.42),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'MATCH SCORE',
                            style: GoogleFonts.inter(
                              color: _tacticalMutedColor,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$matchScore%',
                            style: GoogleFonts.inter(
                              color: scoreColor,
                              fontSize: 28,
                              height: 0.9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$queueCount ready',
                            style: GoogleFonts.inter(
                              color: _tacticalBodyColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
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
                      'Queue',
                      _verificationQueueWorkspaceLabel(activeQueueTab),
                      queueAccent,
                    ),
                    _topChip(
                      'Filter',
                      _mapFilterLabel(activeFilter),
                      const Color(0xFF8EA4C2),
                    ),
                    _topChip('Ready', '$queueCount', queueAccent),
                    _topChip(
                      'Pinned',
                      activeMarker?.label ?? 'None',
                      focusAccent,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: primaryActionColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: primaryActionColor.withValues(alpha: 0.42),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'RECOMMENDED NEXT MOVE',
                              style: GoogleFonts.inter(
                                color: primaryActionColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              primaryActionLabel,
                              style: GoogleFonts.inter(
                                color: _tacticalTitleColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              primaryActionDetail,
                              style: GoogleFonts.inter(
                                color: _tacticalBodyColor,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _tacticalWorkspaceActionChip(
                        key: const ValueKey(
                          'tactical-verification-queue-primary-action',
                        ),
                        label: primaryActionLabel,
                        foreground: primaryActionColor,
                        background: primaryActionColor.withValues(alpha: 0.12),
                        border: primaryActionColor.withValues(alpha: 0.52),
                        onTap: primaryAction,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (activeMarker != null)
                      _tacticalWorkspaceActionChip(
                        key: const ValueKey(
                          'tactical-verification-queue-center-track',
                        ),
                        label: 'Center track',
                        foreground: const Color(0xFFFDE68A),
                        background: const Color(0x14FDE68A),
                        border: const Color(0x66FDE68A),
                        onTap: centerTrackWithFeedback,
                      ),
                    _tacticalWorkspaceActionChip(
                      key: const ValueKey(
                        'tactical-verification-queue-anomalies',
                      ),
                      label: 'Anomalies',
                      foreground: const Color(0xFFFF99A8),
                      background: const Color(0x14FF99A8),
                      border: const Color(0x66FF99A8),
                      onTap: () => openQueueWithFeedback(
                        _VerificationQueueTab.anomalies,
                      ),
                    ),
                    _tacticalWorkspaceActionChip(
                      key: const ValueKey(
                        'tactical-verification-queue-matches',
                      ),
                      label: 'Matches',
                      foreground: const Color(0xFF8FD1FF),
                      background: const Color(0x148FD1FF),
                      border: const Color(0x668FD1FF),
                      onTap: () =>
                          openQueueWithFeedback(_VerificationQueueTab.matches),
                    ),
                    _tacticalWorkspaceActionChip(
                      key: const ValueKey('tactical-verification-queue-assets'),
                      label: 'Assets',
                      foreground: const Color(0xFFA7F3D0),
                      background: const Color(0x14A7F3D0),
                      border: const Color(0x66A7F3D0),
                      onTap: () =>
                          openQueueWithFeedback(_VerificationQueueTab.assets),
                    ),
                    if (onOpenDispatches != null)
                      _tacticalWorkspaceActionChip(
                        key: const ValueKey(
                          'tactical-verification-queue-open-dispatches',
                        ),
                        label: 'OPEN DISPATCH BOARD',
                        foreground: const Color(0xFFDCD4FF),
                        background: const Color(0x147C3AED),
                        border: const Color(0x667C3AED),
                        onTap: openDispatchesWithFeedback,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _verificationQueueChip(
                      tab: _VerificationQueueTab.anomalies,
                      label: 'Anomalies',
                      count: _anomalies.length,
                      active: activeQueueTab == _VerificationQueueTab.anomalies,
                      onTap: openQueueWithFeedback,
                    ),
                    _verificationQueueChip(
                      tab: _VerificationQueueTab.matches,
                      label: 'Matches',
                      count: telemetry.frMatches + telemetry.lprHits,
                      active: activeQueueTab == _VerificationQueueTab.matches,
                      onTap: openQueueWithFeedback,
                    ),
                    _verificationQueueChip(
                      tab: _VerificationQueueTab.assets,
                      label: 'Assets',
                      count: telemetry.snapshotsReady + telemetry.clipsReady,
                      active: activeQueueTab == _VerificationQueueTab.assets,
                      onTap: openQueueWithFeedback,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (activeQueueTab == _VerificationQueueTab.anomalies) ...[
                  if (_anomalies.isEmpty)
                    _verificationQueueRow(
                      label: 'No anomaly overlays',
                      detail:
                          'The active ${_mapFilterLabel(activeFilter).toLowerCase()} filter has no flagged overlays.',
                      accent: const Color(0xFF8EA4C2),
                    ),
                  for (final anomaly in _anomalies) ...[
                    _anomaly(anomaly.description, anomaly.confidence),
                    const SizedBox(height: 6),
                  ],
                ] else if (activeQueueTab == _VerificationQueueTab.matches) ...[
                  _verificationQueueRow(
                    label: 'FR watchlist matches',
                    detail:
                        '${telemetry.frMatches} match${telemetry.frMatches == 1 ? '' : 'es'} in the current 6h window.',
                    accent: const Color(0xFF8FD1FF),
                  ),
                  const SizedBox(height: 6),
                  _verificationQueueRow(
                    label: 'LPR recognition hits',
                    detail:
                        '${telemetry.lprHits} plate hit${telemetry.lprHits == 1 ? '' : 's'} staged for controller review.',
                    accent: const Color(0xFF86EFAC),
                  ),
                  const SizedBox(height: 6),
                  _verificationQueueRow(
                    label: 'Suggested match score',
                    detail:
                        '$matchScore% confidence across the ${_mapFilterLabel(activeFilter).toLowerCase()} queue.',
                    accent: scoreColor,
                  ),
                ] else ...[
                  _verificationQueueRow(
                    label: 'Snapshots ready',
                    detail:
                        '${telemetry.snapshotsReady} still image${telemetry.snapshotsReady == 1 ? '' : 's'} ready for export.',
                    accent: const Color(0xFF93C5FD),
                  ),
                  const SizedBox(height: 6),
                  _verificationQueueRow(
                    label: 'Clips ready',
                    detail:
                        '${telemetry.clipsReady} clip${telemetry.clipsReady == 1 ? '' : 's'} ready for operator playback.',
                    accent: const Color(0xFFA7F3D0),
                  ),
                  const SizedBox(height: 6),
                  _verificationQueueRow(
                    label: 'Queue context',
                    detail: activeMarker == null
                        ? '${_mapFilterLabel(activeFilter)} filter is active with no selected track.'
                        : '${activeMarker.label} is centered in the current ${_mapFilterLabel(activeFilter).toLowerCase()} review queue.',
                    accent: const Color(0xFFFACC15),
                  ),
                ],
              ],
            ),
          ),
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

  Marker _markerOverlay({
    required _MapMarker marker,
    required bool selected,
    required VoidCallback onTap,
  }) {
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
    return Marker(
      point: marker.point,
      width: 132,
      height: 86,
      alignment: Alignment.topCenter,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 132,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.18)
                : const Color(0xCC0A0D14),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.92)
                  : color.withValues(alpha: 0.68),
              width: selected ? 1.4 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
      ),
    );
  }

  Marker _fenceOverlay({
    required _SafetyGeofence fence,
  }) {
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
    return Marker(
      point: fence.point,
      width: 108,
      height: 108,
      child: IgnorePointer(
        child: Container(
          width: 108,
          height: 108,
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

  String _markerStatusLabel(_MapMarker marker) {
    return switch (marker.status) {
      _MarkerStatus.active => 'Active watch',
      _MarkerStatus.responding => 'Responding',
      _MarkerStatus.staticMarker => 'Static site',
      _MarkerStatus.sos => 'Priority SOS',
    };
  }

  Widget _verificationQueueChip({
    required _VerificationQueueTab tab,
    required String label,
    required int count,
    required bool active,
    required ValueChanged<_VerificationQueueTab> onTap,
  }) {
    final accent = switch (tab) {
      _VerificationQueueTab.anomalies => const Color(0xFFFF99A8),
      _VerificationQueueTab.matches => const Color(0xFF8FD1FF),
      _VerificationQueueTab.assets => const Color(0xFFA7F3D0),
    };
    return InkWell(
      key: ValueKey<String>('tactical-verification-tab-${tab.name}'),
      onTap: () => onTap(tab),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? Color.alphaBlend(
                  OnyxDesignTokens.glassSurface,
                  accent.withValues(alpha: 0.1),
                )
              : _tacticalAltSurfaceColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active
                ? accent.withValues(alpha: 0.48)
                : accent.withValues(alpha: 0.24),
          ),
        ),
        child: Text(
          '$label • $count',
          style: GoogleFonts.inter(
            color: Color.lerp(_tacticalTitleColor, accent, 0.72),
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _verificationQueueRow({
    required String label,
    required String detail,
    required Color accent,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _tacticalAltSurfaceColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.42)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: accent,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: GoogleFonts.inter(
              color: _tacticalBodyColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.35,
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? color.withValues(alpha: 0.09)
            : _tacticalAltSurfaceColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: isActive ? 0.62 : 0.34),
        ),
      ),
      child: Text(
        '$label • $value',
        style: GoogleFonts.inter(
          color: color,
          fontSize: 8.5,
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
    required void Function(
      String message, {
      String label,
      String? detail,
      Color accent,
    })
    onShowFeedback,
    required VoidCallback onClear,
  }) {
    final bannerBackground = Color.alphaBlend(
      OnyxDesignTokens.glassSurface,
      active.focusBannerBackgroundColor,
    );
    final bannerActionColor =
        Color.lerp(_tacticalTitleColor, active.focusBannerActionColor, 0.68) ??
        active.focusBannerActionColor;
    final canMutateTemporaryApproval =
        active == VideoFleetWatchActionDrilldown.temporaryIdentity &&
        focusedScope != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bannerBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: active.focusBannerBorderColor.withValues(alpha: 0.38),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 260;
          final actions = Wrap(
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
                    onShowFeedback(
                      message,
                      label: 'TEMPORARY ID',
                      detail:
                          'The approval extension stays visible in the verification rail while the focused watch scope remains selected.',
                      accent: temporaryIdentityAccentColorForScopes(
                        fleetScopeHealth,
                      ),
                    );
                  },
                  child: Text(
                    'Extend 2h',
                    style: GoogleFonts.inter(
                      color: bannerActionColor,
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
                    onShowFeedback(
                      message,
                      label: 'TEMPORARY ID',
                      detail:
                          'The approval expiry stays pinned in the verification rail while the watch-action focus remains in place.',
                      accent: const Color(0xFFFCA5A5),
                    );
                  },
                  child: Text(
                    'Expire now',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFB95D5D),
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
                    color: bannerActionColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );
          final summary = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                active.focusBannerTitle,
                style: GoogleFonts.inter(
                  color: _tacticalTitleColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                focusDetailForWatchAction(fleetScopeHealth, active),
                style: GoogleFonts.inter(
                  color: _tacticalBodyColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [summary, const SizedBox(height: 6), actions],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: summary),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 148),
                child: actions,
              ),
            ],
          );
        },
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
          backgroundColor: _tacticalSurfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: _tacticalBorderColor),
          ),
          title: Text(
            'Expire Temporary Approval?',
            style: GoogleFonts.inter(
              color: _tacticalTitleColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'This immediately removes the temporary identity approval for ${scope.siteName}. Future matches will no longer be treated as approved.',
            style: GoogleFonts.inter(
              color: _tacticalBodyColor,
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
                  color: _tacticalBodyColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFF1F1),
                foregroundColor: const Color(0xFFB42318),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Color(0xFFE8B6B6)),
                ),
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
        color: Color.alphaBlend(
          OnyxDesignTokens.glassSurface,
          color.withValues(alpha: 0.08),
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
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
              color: const Color(0xFF425D78),
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
  final VoidCallback? onTap;
  final bool active;

  const _MapControlChip({
    super.key,
    required this.label,
    this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0x1A22D3EE) : _tacticalAltSurfaceColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? const Color(0x8822D3EE) : _tacticalBorderColor,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: active ? const Color(0xFF0F6782) : _tacticalBodyColor,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
