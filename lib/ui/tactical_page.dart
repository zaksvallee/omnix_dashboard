// ignore_for_file: unused_element

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
import '../application/system_flow_service.dart';
import '../domain/events/decision_created.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/events/execution_completed.dart';
import '../domain/events/execution_denied.dart';
import '../domain/events/incident_closed.dart';
import '../domain/events/intelligence_received.dart';
import '../domain/events/partner_dispatch_status_declared.dart';
import '../domain/events/response_arrived.dart';
import '../domain/guard/guard_position_summary.dart';
import 'components/onyx_system_flow_widgets.dart';
import 'layout_breakpoints.dart';
import 'onyx_surface.dart';
import 'theme/onyx_design_tokens.dart';
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

enum SignalSentState { unsent, sent }

enum _SignalFeedState { live, stale, noSignal }

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

class _TacticalSignalViewData {
  final String id;
  final String title;
  final int confidence;
  final DateTime occurredAtUtc;
  final String cameraLabel;
  final String zoneLabel;
  final String summary;
  final String contextLine;
  final String verdict;
  final String? snapshotUrl;
  final _MapMarker? marker;

  const _TacticalSignalViewData({
    required this.id,
    required this.title,
    required this.confidence,
    required this.occurredAtUtc,
    required this.cameraLabel,
    required this.zoneLabel,
    required this.summary,
    required this.contextLine,
    required this.verdict,
    this.snapshotUrl,
    this.marker,
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
    _TacticalDetailedWorkspaceHostState host,
    bool showDetailedWorkspace,
    ValueChanged<bool> setDetailedWorkspace,
    void Function(String incidentReference, ValueChanged<String>? onConsume)
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
  final ScrollController _signalScrollController = ScrollController();
  final Map<String, GlobalKey> _signalCardKeys = <String, GlobalKey>{};
  bool _showDetailedWorkspace = false;
  String? _expandedSignalId;
  bool _mapExpanded = false;
  final Map<String, SignalSentState> _signalSentStates =
      <String, SignalSentState>{};
  final Set<String> _dismissedSignalIds = <String>{};
  String? _lastConsumedAgentReturnIncidentReference;
  String? _lastConsumedEvidenceReturnAuditId;

  ScrollController get signalScrollController => _signalScrollController;
  String? get expandedSignalId => _expandedSignalId;
  bool get mapExpanded => _mapExpanded;
  Map<String, SignalSentState> get signalSentStates => _signalSentStates;
  Set<String> get dismissedSignalIds => _dismissedSignalIds;

  GlobalKey signalCardKeyFor(String signalId) =>
      _signalCardKeys.putIfAbsent(signalId, GlobalKey.new);

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

  void setExpandedSignalId(String? value) {
    if (_expandedSignalId == value) {
      return;
    }
    setState(() {
      _expandedSignalId = value;
    });
  }

  void setMapExpanded(bool value) {
    if (_mapExpanded == value) {
      return;
    }
    setState(() {
      _mapExpanded = value;
    });
  }

  void setSignalSentState(String signalId, SignalSentState state) {
    if (_signalSentStates[signalId] == state) {
      return;
    }
    setState(() {
      _signalSentStates[signalId] = state;
      if (_expandedSignalId == signalId) {
        _expandedSignalId = null;
      }
    });
  }

  void dismissSignal(String signalId) {
    if (_dismissedSignalIds.contains(signalId)) {
      return;
    }
    setState(() {
      _dismissedSignalIds.add(signalId);
      if (_expandedSignalId == signalId) {
        _expandedSignalId = null;
      }
    });
  }

  @override
  void dispose() {
    _signalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      this,
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
      builder:
          (
            context,
            host,
            unusedShowDetailedWorkspace,
            unusedSetDetailedWorkspace,
            consumeAgentReturnIncidentReferenceOnce,
            consumeEvidenceReturnReceiptOnce,
            unusedFleetPanelKey,
            unusedSuppressedPanelKey,
            mapController,
          ) {
            final normalizedAgentReturnReference =
                (agentReturnIncidentReference ?? '').trim();
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
                final contentPadding = const EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  16,
                );
                void showTacticalFeedback(
                  String message, {
                  String label = 'VERIFICATION RAIL',
                  String? detail,
                  Color accent = _tacticalAccentSky,
                }) {
                  final feedbackText = detail == null || detail.trim().isEmpty
                      ? '$label · $message'
                      : '$label · $message\n$detail';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: accent.withValues(alpha: 0.18),
                      content: Text(feedbackText),
                    ),
                  );
                }

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
                final connectingToLiveData =
                    !supabaseReady &&
                    guardPositions.isEmpty &&
                    siteMarkers.isEmpty;
                final lensTelemetry = _buildCctvLensTelemetry();
                final headerDispatchAction = _headerDispatchAction(
                  visibleFleetScopeHealth: visibleFleetScopeHealth,
                  focusReference: focusReference,
                  scopeClientId: scopeClientId,
                  scopeSiteId: scopeSiteId,
                );
                final signals = _resolvedTacticalSignals(
                  now: now,
                  markers: visibleMarkers,
                  visibleFleetScopeHealth: visibleFleetScopeHealth,
                  scopeSiteId: scopeSiteId,
                );

                Widget buildWideWorkspace({required bool embedScroll}) {
                  return _buildDetectionSurface(
                    context: context,
                    host: host,
                    embedScroll: embedScroll,
                    now: now,
                    signals: signals,
                    geofenceAlerts: geofenceAlerts,
                    sosAlerts: sosAlerts,
                    focusReference: focusReference,
                    focusState: focusState,
                    scopeClientId: scopeClientId,
                    scopeSiteId: scopeSiteId,
                    cctvReadiness: cctvOpsReadiness,
                    lensTelemetry: lensTelemetry,
                    visibleFleetScopeHealth: visibleFleetScopeHealth,
                    visibleMarkers: visibleMarkers,
                    mapBounds: mapBounds,
                    activeMarker: activeMarker,
                    mapZoom: mapZoom,
                    mapController: mapController,
                    mapFilter: mapFilter,
                    verificationQueueTab: verificationQueueTab,
                    connectingToLiveData: connectingToLiveData,
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
                    onShowFeedback: showTacticalFeedback,
                  );
                }

                return OnyxPageScaffold(
                  child: SizedBox.expand(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compactTacticalLane =
                            constraints.maxWidth <
                                _tacticalDesktopOverviewMinWidth ||
                            math.min(
                                  constraints.maxWidth,
                                  constraints.maxHeight,
                                ) <
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
                          body: buildWideWorkspace(
                            embedScroll: boundedDesktopSurface,
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            );
          },
    );
  }

  List<_TacticalSignalViewData> _resolvedTacticalSignals({
    required DateTime now,
    required List<_MapMarker> markers,
    required List<VideoFleetScopeHealthView> visibleFleetScopeHealth,
    required String scopeSiteId,
  }) {
    final intelligenceEvents =
        events
            .whereType<IntelligenceReceived>()
            .where(
              (event) =>
                  event.sourceType == 'hardware' || event.sourceType == 'dvr',
            )
            .toList(growable: false)
          ..sort((a, b) {
            final riskCompare = b.riskScore.compareTo(a.riskScore);
            if (riskCompare != 0) {
              return riskCompare;
            }
            return b.occurredAt.compareTo(a.occurredAt);
          });
    final sortedAnomalies = [..._anomalies]
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    final fallbackSiteLabel = _resolvedTrackSiteLabel(
      visibleFleetScopeHealth: visibleFleetScopeHealth,
      scopeSiteId: scopeSiteId,
    );
    return sortedAnomalies
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final anomaly = entry.value;
          final intelligence = index < intelligenceEvents.length
              ? intelligenceEvents[index]
              : null;
          final review = intelligence == null
              ? null
              : sceneReviewByIntelligenceId[intelligence.intelligenceId];
          final marker = markers.isEmpty
              ? null
              : markers[index % markers.length];
          final occurredAtUtc =
              intelligence?.occurredAt.toUtc() ??
              now.toUtc().subtract(Duration(minutes: 6 + (index * 4)));
          final cameraLabel = (intelligence?.cameraId ?? '').trim().isNotEmpty
              ? intelligence!.cameraId!.trim()
              : (visibleFleetScopeHealth.isNotEmpty &&
                    (visibleFleetScopeHealth.first.latestCameraLabel ?? '')
                        .trim()
                        .isNotEmpty)
              ? visibleFleetScopeHealth.first.latestCameraLabel!.trim()
              : 'CAM-${index + 1}';
          final zoneLabel = (intelligence?.zone ?? '').trim().isNotEmpty
              ? intelligence!.zone!.trim()
              : fallbackSiteLabel;
          final title = (intelligence?.headline ?? '').trim().isNotEmpty
              ? intelligence!.headline.trim()
              : anomaly.description;
          final summary = (review?.summary ?? intelligence?.summary ?? '')
              .trim();
          final contextLine = (review?.decisionSummary ?? '').trim().isNotEmpty
              ? review!.decisionSummary.trim()
              : (intelligence?.objectLabel ?? '').trim().isNotEmpty
              ? '${intelligence!.objectLabel!.trim()} correlation in $zoneLabel.'
              : 'Cross-checking live feed against recent baseline drift.';
          final verdict = (review?.decisionSummary ?? '').trim().isNotEmpty
              ? review!.decisionSummary.trim()
              : summary.isNotEmpty
              ? summary
              : 'Zara is holding this signal in detection until verification confirms intent.';
          return _TacticalSignalViewData(
            id: anomaly.id,
            title: title,
            confidence: anomaly.confidence,
            occurredAtUtc: occurredAtUtc,
            cameraLabel: cameraLabel,
            zoneLabel: zoneLabel,
            summary: summary.isEmpty ? anomaly.description : summary,
            contextLine: contextLine,
            verdict: verdict,
            snapshotUrl: (intelligence?.snapshotUrl ?? '').trim().isEmpty
                ? null
                : intelligence!.snapshotUrl!.trim(),
            marker: marker,
          );
        })
        .toList(growable: false);
  }

  String _resolvedTrackSiteLabel({
    required List<VideoFleetScopeHealthView> visibleFleetScopeHealth,
    required String scopeSiteId,
  }) {
    if (visibleFleetScopeHealth.isNotEmpty &&
        visibleFleetScopeHealth.first.siteName.trim().isNotEmpty) {
      return visibleFleetScopeHealth.first.siteName.trim();
    }
    for (final site in siteMarkers) {
      if (scopeSiteId.isNotEmpty && site.id.trim() != scopeSiteId) {
        continue;
      }
      if (site.name.trim().isNotEmpty) {
        return site.name.trim();
      }
    }
    return scopeSiteId.isEmpty ? 'Network Scope' : scopeSiteId;
  }

  _SignalFeedState _signalFeedStateFor(
    _TacticalSignalViewData signal,
    DateTime now,
  ) {
    if ((signal.snapshotUrl ?? '').trim().isEmpty) {
      return _SignalFeedState.noSignal;
    }
    final age = now.toUtc().difference(signal.occurredAtUtc);
    if (age.inMinutes >= 12) {
      return _SignalFeedState.stale;
    }
    return _SignalFeedState.live;
  }

  String _formatSignalTime(DateTime timestampUtc) {
    final hh = timestampUtc.hour.toString().padLeft(2, '0');
    final mm = timestampUtc.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _formatElapsedCompact(Duration duration) {
    if (duration.inHours >= 1) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    }
    return '${duration.inMinutes}m';
  }

  Color _signalAccentForConfidence(int confidence) {
    if (confidence > 85) {
      return OnyxColorTokens.accentRed;
    }
    if (confidence >= 70) {
      return OnyxColorTokens.accentAmber;
    }
    return OnyxColorTokens.textDisabled.withValues(alpha: 0.40);
  }

  Widget _buildDetectionSurface({
    required BuildContext context,
    required _TacticalDetailedWorkspaceHostState host,
    required bool embedScroll,
    required DateTime now,
    required List<_TacticalSignalViewData> signals,
    required int geofenceAlerts,
    required int sosAlerts,
    required String focusReference,
    required _FocusLinkState focusState,
    required String scopeClientId,
    required String scopeSiteId,
    required String cctvReadiness,
    required _CctvLensTelemetry lensTelemetry,
    required List<VideoFleetScopeHealthView> visibleFleetScopeHealth,
    required List<_MapMarker> visibleMarkers,
    required LatLngBounds mapBounds,
    required _MapMarker? activeMarker,
    required double mapZoom,
    required MapController mapController,
    required _TacticalMapFilter mapFilter,
    required _VerificationQueueTab verificationQueueTab,
    required bool connectingToLiveData,
    required ValueChanged<String> onSelectMarker,
    required VoidCallback onZoomIn,
    required VoidCallback onZoomOut,
    required VoidCallback onCenterActive,
    required VoidCallback onCycleFilter,
    required ValueChanged<_VerificationQueueTab> onSetQueueTab,
    required VoidCallback? onOpenDispatches,
    required void Function(
      String message, {
      String label,
      String? detail,
      Color accent,
    })
    onShowFeedback,
  }) {
    final visibleSignals = signals
        .where((signal) => !host.dismissedSignalIds.contains(signal.id))
        .toList(growable: false);
    final topSignal = visibleSignals.isEmpty ? null : visibleSignals.first;
    final reviewCount = visibleSignals
        .where(
          (signal) => host.signalSentStates[signal.id] != SignalSentState.sent,
        )
        .length;
    final queuedSignals = visibleSignals
        .where(
          (signal) => host.signalSentStates[signal.id] == SignalSentState.sent,
        )
        .toList(growable: false);
    final actionableCount = visibleSignals
        .where((signal) => signal.confidence >= 85)
        .length;
    final siteLabel = _resolvedTrackSiteLabel(
      visibleFleetScopeHealth: visibleFleetScopeHealth,
      scopeSiteId: scopeSiteId,
    );
    final respondersCount = visibleMarkers
        .where(
          (marker) =>
              marker.type == _MarkerType.vehicle ||
              marker.status == _MarkerStatus.responding ||
              marker.status == _MarkerStatus.sos,
        )
        .length;

    void scrollToSignal(_TacticalSignalViewData signal) {
      host.setExpandedSignalId(signal.id);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) {
          return;
        }
        final targetContext = host.signalCardKeyFor(signal.id).currentContext;
        if (targetContext != null) {
          Scrollable.ensureVisible(
            targetContext,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: 0.05,
          );
          return;
        }
        host.signalScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      });
    }

    void toggleSignalReview(_TacticalSignalViewData signal) {
      final nextValue = host.expandedSignalId == signal.id ? null : signal.id;
      host.setExpandedSignalId(nextValue);
      if (nextValue == signal.id) {
        scrollToSignal(signal);
      }
    }

    void sendSignalToQueue(_TacticalSignalViewData signal) {
      host.setSignalSentState(signal.id, SignalSentState.sent);
      onOpenDispatches?.call();
      onShowFeedback(
        '${signal.title} sent to Queue.',
        label: 'QUEUE HANDOFF',
        detail:
            'Track escalated the detection into the dispatch lane without changing the underlying incident workflow.',
        accent: OnyxColorTokens.accentAmber,
      );
    }

    void dismissSignal(_TacticalSignalViewData signal) {
      host.dismissSignal(signal.id);
      onShowFeedback(
        '${signal.title} marked as non-threat.',
        label: 'SIGNAL DISMISSED',
        detail:
            'The signal was cleared locally in Track and will not be pushed forward from this surface.',
        accent: OnyxColorTokens.textMuted,
      );
    }

    void openMap() {
      host.setMapExpanded(true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) {
          return;
        }
        host.signalScrollController.animateTo(
          host.signalScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      });
    }

    final surfaceBody = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sosAlerts > 0) ...[
          _tacticalAlertBanner(
            key: const ValueKey('tactical-sos-banner'),
            icon: Icons.warning_amber_rounded,
            accent: OnyxColorTokens.accentRed,
            label: 'ACTIVE SOS TRIGGER',
            message:
                '$sosAlerts guard ping${sosAlerts == 1 ? '' : 's'} need immediate tactical attention',
            actionLabel: 'OPEN DISPATCHES',
            onPressed: onOpenDispatches,
          ),
          const SizedBox(height: 14),
        ],
        _buildDetectionSummaryBlock(
          topSignal: topSignal,
          siteLabel: siteLabel,
          totalSignals: visibleSignals.length,
          reviewCount: reviewCount,
          geofenceAlerts: geofenceAlerts,
          sentCount: queuedSignals.length,
          latestQueueReference: queuedSignals.isEmpty
              ? null
              : _trackQueueReference(queuedSignals.first.id),
          onReviewTopSignal: topSignal == null
              ? null
              : () => scrollToSignal(topSignal),
        ),
        _buildSignalsHeaderRow(
          totalSignals: visibleSignals.length,
          actionableCount: actionableCount,
          onViewOnMap: openMap,
        ),
        if (visibleSignals.isEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: OnyxColorTokens.backgroundSecondary,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: OnyxColorTokens.divider),
            ),
            child: Text(
              'No active signals detected. Track is nominal and standing by for the next detection window.',
              style: GoogleFonts.inter(
                color: OnyxColorTokens.textDisabled,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (final entry in visibleSignals.asMap().entries) ...[
                  _buildSignalCard(
                    host: host,
                    now: now,
                    signal: entry.value,
                    isPriority: entry.key == 0,
                    onReview: () => toggleSignalReview(entry.value),
                    onSendToQueue: () => sendSignalToQueue(entry.value),
                    onDismiss: () => dismissSignal(entry.value),
                  ),
                  if (entry.key != visibleSignals.length - 1)
                    const SizedBox(height: 5),
                ],
              ],
            ),
          ),
        _buildTacticalMapBar(
          host: host,
          respondersCount: respondersCount,
          geofenceAlerts: geofenceAlerts,
          cctvReadiness: cctvReadiness,
          visibleMarkers: visibleMarkers,
          mapBounds: mapBounds,
          activeMarker: activeMarker,
          mapZoom: mapZoom,
          mapController: mapController,
          mapFilter: mapFilter,
          verificationQueueTab: verificationQueueTab,
          focusReference: focusReference,
          focusState: focusState,
          connectingToLiveData: connectingToLiveData,
          onSelectMarker: onSelectMarker,
          onZoomIn: onZoomIn,
          onZoomOut: onZoomOut,
          onCenterActive: onCenterActive,
          onCycleFilter: onCycleFilter,
          onSetQueueTab: onSetQueueTab,
          onOpenDispatches: onOpenDispatches,
        ),
      ],
    );

    return SingleChildScrollView(
      controller: host.signalScrollController,
      primary: !embedScroll,
      child: surfaceBody,
    );
  }

  Widget _buildDetectionSummaryBlock({
    required _TacticalSignalViewData? topSignal,
    required String siteLabel,
    required int totalSignals,
    required int reviewCount,
    required int geofenceAlerts,
    required int sentCount,
    required String? latestQueueReference,
    required VoidCallback? onReviewTopSignal,
  }) {
    final summaryTime = topSignal == null
        ? '--:--'
        : _formatSignalTime(topSignal.occurredAtUtc);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: OnyxColorTokens.accentPurple.withValues(alpha: 0.22),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 860;
          final leftColumn = Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: OnyxColorTokens.accentPurple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: OnyxColorTokens.accentPurple.withValues(
                        alpha: 0.35,
                      ),
                    ),
                  ),
                  child: Text(
                    'Z',
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.accentPurple,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Builder(
                        builder: (context) {
                          final continuity =
                              OnyxZaraContinuityService.trackDetection(
                                totalSignals: totalSignals,
                                reviewCount: reviewCount,
                                geofenceAlerts: geofenceAlerts,
                                topSignalTitle: topSignal?.title,
                                summaryTime: summaryTime,
                              );
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                continuity.headline,
                                style: GoogleFonts.inter(
                                  color: OnyxColorTokens.accentPurple
                                      .withValues(alpha: 0.60),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 5),
                              _summaryLine(
                                color: OnyxColorTokens.accentRed,
                                text: continuity.lines[0],
                              ),
                              const SizedBox(height: 4),
                              _summaryLine(
                                color: OnyxColorTokens.accentAmber,
                                text: continuity.lines[1],
                              ),
                              const SizedBox(height: 4),
                              _summaryLine(
                                color: OnyxColorTokens.accentPurple,
                                text: continuity.lines[2],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    '→',
                                    style: GoogleFonts.inter(
                                      color: OnyxColorTokens.accentPurple,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      topSignal == null
                                          ? 'Detection lanes are nominal.'
                                          : 'Predictive read: review ${topSignal.title} first before pushing the next queue handoff.',
                                      style: GoogleFonts.inter(
                                        color: OnyxColorTokens.accentPurple
                                            .withValues(alpha: 0.80),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
          final rightColumn = Column(
            crossAxisAlignment: compact
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: OnyxColorTokens.accentGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: OnyxColorTokens.accentGreen.withValues(alpha: 0.18),
                  ),
                ),
                child: Text(
                  'NOMINAL · $siteLabel',
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.accentGreen.withValues(alpha: 0.70),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: onReviewTopSignal,
                style: FilledButton.styleFrom(
                  backgroundColor: OnyxColorTokens.accentPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                child: Text(
                  'Review Top Signal',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );
          if (compact) {
            final flow = OnyxFlowIndicatorService.trackToQueue(
              sourceLabel: topSignal == null
                  ? 'Detection lane standing by'
                  : 'Strongest signal → ${topSignal.title}',
              nextActionLabel: sentCount > 0
                  ? 'Sent to Queue → ${latestQueueReference ?? 'INC-STANDBY'}'
                  : topSignal == null
                  ? 'Await the next verified anomaly'
                  : 'Next queue handoff → ${_trackQueueReference(topSignal.id)}',
              referenceLabel: sentCount > 0
                  ? latestQueueReference
                  : topSignal == null
                  ? null
                  : _trackQueueReference(topSignal.id),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [leftColumn]),
                const SizedBox(height: 12),
                rightColumn,
                const SizedBox(height: 10),
                OnyxFlowIndicator(flow: flow),
              ],
            );
          }
          final flow = OnyxFlowIndicatorService.trackToQueue(
            sourceLabel: topSignal == null
                ? 'Detection lane standing by'
                : 'Strongest signal → ${topSignal.title}',
            nextActionLabel: sentCount > 0
                ? 'Sent to Queue → ${latestQueueReference ?? 'INC-STANDBY'}'
                : topSignal == null
                ? 'Await the next verified anomaly'
                : 'Next queue handoff → ${_trackQueueReference(topSignal.id)}',
            referenceLabel: sentCount > 0
                ? latestQueueReference
                : topSignal == null
                ? null
                : _trackQueueReference(topSignal.id),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [leftColumn, const SizedBox(width: 16), rightColumn],
              ),
              const SizedBox(height: 10),
              OnyxFlowIndicator(flow: flow),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryLine({required Color color, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignalsHeaderRow({
    required int totalSignals,
    required int actionableCount,
    required VoidCallback onViewOnMap,
  }) {
    Widget buildChip(
      String label, {
      required Color color,
      required Color border,
      Color? background,
      VoidCallback? onTap,
    }) {
      final child = Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: background ?? OnyxColorTokens.backgroundSecondary,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      if (onTap == null) {
        return child;
      }
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: child,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              'ACTIVE SIGNALS',
              style: GoogleFonts.inter(
                color: OnyxColorTokens.textDisabled,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.3,
              ),
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              buildChip(
                'All · $totalSignals',
                color: OnyxColorTokens.textSecondary,
                border: OnyxColorTokens.divider,
              ),
              buildChip(
                'Actionable · $actionableCount',
                color: OnyxColorTokens.textSecondary,
                border: OnyxColorTokens.divider,
              ),
              buildChip(
                'View on Map',
                color: OnyxColorTokens.accentSky.withValues(alpha: 0.55),
                border: OnyxColorTokens.accentSky.withValues(alpha: 0.18),
                onTap: onViewOnMap,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSignalCard({
    required _TacticalDetailedWorkspaceHostState host,
    required DateTime now,
    required _TacticalSignalViewData signal,
    required bool isPriority,
    required VoidCallback onReview,
    required VoidCallback onSendToQueue,
    required VoidCallback onDismiss,
  }) {
    final sentState = host.signalSentStates[signal.id] == SignalSentState.sent;
    final expanded = host.expandedSignalId == signal.id && !sentState;
    final signalAccent = _signalAccentForConfidence(signal.confidence);
    final feedState = _signalFeedStateFor(signal, now);
    final elapsed = now.toUtc().difference(signal.occurredAtUtc);
    final borderColor = sentState
        ? OnyxColorTokens.accentGreen.withValues(alpha: 0.20)
        : isPriority
        ? signal.confidence > 85
              ? OnyxColorTokens.accentRed.withValues(alpha: 0.35)
              : OnyxColorTokens.accentAmber.withValues(alpha: 0.30)
        : OnyxColorTokens.divider;
    final contentOpacity = sentState
        ? 0.60
        : isPriority
        ? 1.0
        : 0.80;

    Widget confidenceBadge() {
      final (foreground, background, border) = signal.confidence > 85
          ? (
              OnyxColorTokens.accentRed,
              OnyxColorTokens.accentRed.withValues(alpha: 0.12),
              OnyxColorTokens.accentRed.withValues(alpha: 0.25),
            )
          : signal.confidence >= 70
          ? (
              OnyxColorTokens.accentAmber,
              OnyxColorTokens.accentAmber.withValues(alpha: 0.10),
              OnyxColorTokens.accentAmber.withValues(alpha: 0.20),
            )
          : (
              OnyxColorTokens.textMuted,
              OnyxColorTokens.backgroundPrimary,
              OnyxColorTokens.divider,
            );
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: border),
        ),
        child: Text(
          '${signal.confidence}% CONF',
          style: GoogleFonts.inter(
            color: foreground,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    Widget reviewButton() {
      final reviewing = expanded;
      return InkWell(
        onTap: onReview,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: OnyxColorTokens.accentPurple.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: OnyxColorTokens.accentPurple.withValues(alpha: 0.22),
            ),
          ),
          child: Text(
            reviewing ? 'Reviewing ↑' : 'Review',
            style: GoogleFonts.inter(
              color: OnyxColorTokens.accentPurple.withValues(alpha: 0.80),
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    Widget sendButton() {
      return InkWell(
        onTap: onSendToQueue,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: OnyxColorTokens.accentAmber.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: OnyxColorTokens.accentAmber.withValues(alpha: 0.40),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Send to Queue',
                style: GoogleFonts.inter(
                  color: OnyxColorTokens.accentAmber,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '→ Creates incident',
                style: GoogleFonts.inter(
                  color: OnyxColorTokens.accentAmber.withValues(alpha: 0.45),
                  fontSize: 7,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Opacity(
      opacity: contentOpacity,
      child: Container(
        key: host.signalCardKeyFor(signal.id),
        decoration: BoxDecoration(
          color: OnyxColorTokens.backgroundSecondary,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 860;
                final infoSection = Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        signal.title,
                        style: GoogleFonts.inter(
                          color: OnyxColorTokens.textPrimary.withValues(
                            alpha: isPriority ? 0.88 : 0.55,
                          ),
                          fontSize: isPriority ? 12 : 11,
                          fontWeight: isPriority
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          confidenceBadge(),
                          Text(
                            _formatSignalTime(signal.occurredAtUtc),
                            style: GoogleFonts.inter(
                              color: OnyxColorTokens.textDisabled,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            signal.zoneLabel,
                            style: GoogleFonts.inter(
                              color: OnyxColorTokens.textDisabled,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
                final actionSection = sentState
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: OnyxColorTokens.accentGreen.withValues(
                            alpha: 0.08,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: OnyxColorTokens.accentGreen.withValues(
                              alpha: 0.20,
                            ),
                          ),
                        ),
                        child: Text(
                          '✓ Sent to Queue',
                          style: GoogleFonts.inter(
                            color: OnyxColorTokens.accentGreen,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          reviewButton(),
                          sendButton(),
                          InkWell(
                            onTap: onReview,
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              width: 20,
                              height: 20,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: OnyxColorTokens.backgroundPrimary,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: OnyxColorTokens.divider,
                                ),
                              ),
                              child: Text(
                                expanded ? '↑' : '↓',
                                style: GoogleFonts.inter(
                                  color: OnyxColorTokens.textDisabled,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                if (compact) {
                  return Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 3,
                              height: 44,
                              decoration: BoxDecoration(
                                color: signalAccent,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 10),
                            infoSection,
                          ],
                        ),
                        const SizedBox(height: 10),
                        actionSection,
                      ],
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 3,
                        height: 44,
                        decoration: BoxDecoration(
                          color: signalAccent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      infoSection,
                      const SizedBox(width: 12),
                      actionSection,
                    ],
                  ),
                );
              },
            ),
            if (sentState)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: OnyxColorTokens.accentGreen.withValues(alpha: 0.04),
                  border: Border(
                    top: BorderSide(
                      color: OnyxColorTokens.accentGreen.withValues(
                        alpha: 0.08,
                      ),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: OnyxColorTokens.accentPurple.withValues(
                          alpha: 0.15,
                        ),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: OnyxColorTokens.accentPurple.withValues(
                            alpha: 0.22,
                          ),
                        ),
                      ),
                      child: Text(
                        'Z',
                        style: GoogleFonts.inter(
                          color: OnyxColorTokens.accentPurple,
                          fontSize: 6,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Sent to Queue → ${_trackQueueReference(signal.id)} · Awaiting decision.',
                        style: GoogleFonts.inter(
                          color: OnyxColorTokens.accentPurple.withValues(
                            alpha: 0.50,
                          ),
                          fontSize: 8,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOut,
                width: double.infinity,
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeInOut,
                  child: expanded
                      ? _buildSignalInlineContext(
                          now: now,
                          signal: signal,
                          feedState: feedState,
                          elapsed: elapsed,
                          onCollapse: onReview,
                          onDismiss: onDismiss,
                          onSendToQueue: onSendToQueue,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignalInlineContext({
    required DateTime now,
    required _TacticalSignalViewData signal,
    required _SignalFeedState feedState,
    required Duration elapsed,
    required VoidCallback onCollapse,
    required VoidCallback onDismiss,
    required VoidCallback onSendToQueue,
  }) {
    final feedLabelColor = switch (feedState) {
      _SignalFeedState.live => OnyxColorTokens.accentGreen,
      _SignalFeedState.stale => OnyxColorTokens.accentAmber,
      _SignalFeedState.noSignal => OnyxColorTokens.accentRed,
    };
    final liveLabel = switch (feedState) {
      _SignalFeedState.live =>
        'LIVE · ${signal.cameraLabel} · ${signal.zoneLabel}',
      _SignalFeedState.stale =>
        'FEED STALE — Last frame ${_formatSignalTime(signal.occurredAtUtc)} · ${signal.cameraLabel} · ${signal.zoneLabel}',
      _SignalFeedState.noSignal => 'NO SIGNAL',
    };
    final cameraStatus = feedState == _SignalFeedState.noSignal
        ? 'STALE'
        : 'READY';
    final cameraStatusColor = feedState == _SignalFeedState.live
        ? OnyxColorTokens.accentGreen
        : feedState == _SignalFeedState.stale
        ? OnyxColorTokens.accentAmber
        : OnyxColorTokens.accentRed;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundPrimary,
        border: Border(
          top: BorderSide(
            color: OnyxColorTokens.accentPurple.withValues(alpha: 0.10),
          ),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              children: [
                Text(
                  'Context · Zara verifying',
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.accentPurple.withValues(alpha: 0.35),
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: onCollapse,
                  child: Text(
                    'Collapse ↑',
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.textDisabled,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 780;
                final feedBlock = Expanded(
                  flex: compact ? 0 : 55,
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: OnyxColorTokens.surfaceInset,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: (signal.snapshotUrl ?? '').trim().isEmpty
                                ? Container(
                                    color: OnyxColorTokens.backgroundPrimary,
                                    alignment: Alignment.center,
                                    child: Text(
                                      'No camera snapshot available',
                                      style: GoogleFonts.inter(
                                        color: OnyxColorTokens.textDisabled,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  )
                                : Image.network(
                                    signal.snapshotUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (
                                          context,
                                          error,
                                          stackTrace,
                                        ) => Container(
                                          color:
                                              OnyxColorTokens.backgroundPrimary,
                                          alignment: Alignment.center,
                                          child: Text(
                                            'Snapshot unavailable',
                                            style: GoogleFonts.inter(
                                              color:
                                                  OnyxColorTokens.textDisabled,
                                              fontSize: 8,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                  ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: OnyxColorTokens.backgroundPrimary
                                    .withValues(alpha: 0.85),
                                border: Border(
                                  bottom: BorderSide(
                                    color: OnyxColorTokens.accentAmber
                                        .withValues(alpha: 0.15),
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  _PulseDot(
                                    color: feedLabelColor,
                                    size: 5,
                                    animated:
                                        feedState != _SignalFeedState.live,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      liveLabel,
                                      style: GoogleFonts.inter(
                                        color: feedLabelColor,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: OnyxColorTokens.backgroundPrimary
                                    .withValues(alpha: 0.88),
                                border: Border(
                                  top: BorderSide(
                                    color: OnyxColorTokens.accentPurple
                                        .withValues(alpha: 0.15),
                                  ),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 11,
                                    height: 11,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: OnyxColorTokens.accentPurple
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(
                                        color: OnyxColorTokens.accentPurple
                                            .withValues(alpha: 0.22),
                                      ),
                                    ),
                                    child: Text(
                                      'Z',
                                      style: GoogleFonts.inter(
                                        color: OnyxColorTokens.accentPurple,
                                        fontSize: 6,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          signal.summary,
                                          style: GoogleFonts.inter(
                                            color: OnyxColorTokens.accentPurple
                                                .withValues(alpha: 0.75),
                                            fontSize: 8,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          signal.contextLine,
                                          style: GoogleFonts.inter(
                                            color: OnyxColorTokens.accentPurple
                                                .withValues(alpha: 0.45),
                                            fontSize: 8,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
                final contextBlock = Expanded(
                  flex: compact ? 0 : 45,
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: OnyxColorTokens.backgroundSecondary,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: OnyxColorTokens.textPrimary.withValues(
                                  alpha: 0.03,
                                ),
                                border: Border(
                                  bottom: BorderSide(
                                    color: OnyxColorTokens.divider,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    'NORM',
                                    style: GoogleFonts.inter(
                                      color: OnyxColorTokens.textDisabled
                                          .withValues(alpha: 0.22),
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'LIVE · ${_formatSignalTime(signal.occurredAtUtc)}',
                                    style: GoogleFonts.inter(
                                      color: OnyxColorTokens.textDisabled
                                          .withValues(alpha: 0.22),
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              height: 38,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      color: OnyxColorTokens.surfaceInset,
                                      alignment: Alignment.center,
                                      child: Text(
                                        'Baseline',
                                        style: GoogleFonts.inter(
                                          color: OnyxColorTokens.textDisabled
                                              .withValues(alpha: 0.12),
                                          fontSize: 7,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 1,
                                    color: OnyxColorTokens.divider,
                                  ),
                                  Expanded(
                                    child: Container(
                                      color: OnyxColorTokens.surfaceInset,
                                      alignment: Alignment.center,
                                      child: Text(
                                        signal.zoneLabel,
                                        style: GoogleFonts.inter(
                                          color: OnyxColorTokens.textDisabled
                                              .withValues(alpha: 0.12),
                                          fontSize: 7,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 7),
                      _signalFactRow(
                        'Signal',
                        '${signal.confidence}%',
                        _signalAccentForConfidence(signal.confidence),
                      ),
                      const SizedBox(height: 5),
                      _signalFactRow('Camera', cameraStatus, cameraStatusColor),
                      const SizedBox(height: 5),
                      _signalFactRow(
                        'Last motion',
                        _formatElapsedCompact(elapsed),
                        OnyxColorTokens.accentAmber,
                      ),
                    ],
                  ),
                );
                if (compact) {
                  return Column(
                    children: [
                      Row(children: [feedBlock]),
                      const SizedBox(height: 10),
                      Row(children: [contextBlock]),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    feedBlock,
                    const SizedBox(width: 10),
                    contextBlock,
                  ],
                );
              },
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: OnyxColorTokens.accentPurple.withValues(alpha: 0.07),
              border: Border(
                top: BorderSide(
                  color: OnyxColorTokens.accentPurple.withValues(alpha: 0.10),
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: OnyxColorTokens.accentPurple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: OnyxColorTokens.accentPurple.withValues(
                        alpha: 0.22,
                      ),
                    ),
                  ),
                  child: Text(
                    'Z',
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.accentPurple,
                      fontSize: 7,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    signal.verdict,
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.textSecondary.withValues(
                        alpha: 0.55,
                      ),
                      fontSize: 9,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: OnyxColorTokens.accentAmber.withValues(alpha: 0.03),
              border: Border(
                top: BorderSide(
                  color: OnyxColorTokens.accentAmber.withValues(alpha: 0.08),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onDismiss,
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: OnyxColorTokens.backgroundPrimary,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: OnyxColorTokens.divider),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Mark as Non-Threat',
                        style: GoogleFonts.inter(
                          color: OnyxColorTokens.textMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 14,
                  child: InkWell(
                    onTap: onSendToQueue,
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: OnyxColorTokens.accentAmber.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: OnyxColorTokens.accentAmber.withValues(
                            alpha: 0.35,
                          ),
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          Text(
                            'Send to Queue',
                            style: GoogleFonts.inter(
                              color: OnyxColorTokens.accentAmber,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Ledger entry will be created',
                            style: GoogleFonts.inter(
                              color: OnyxColorTokens.accentAmber.withValues(
                                alpha: 0.45,
                              ),
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
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
        ],
      ),
    );
  }

  Widget _signalFactRow(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          Text(
            '$label:',
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textDisabled,
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.inter(
              color: valueColor,
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _trackQueueReference(String rawSignalId) {
    return OnyxSystemFlowService.incidentReference(rawSignalId);
  }

  Widget _buildTacticalMapBar({
    required _TacticalDetailedWorkspaceHostState host,
    required int respondersCount,
    required int geofenceAlerts,
    required String cctvReadiness,
    required List<_MapMarker> visibleMarkers,
    required LatLngBounds mapBounds,
    required _MapMarker? activeMarker,
    required double mapZoom,
    required MapController mapController,
    required _TacticalMapFilter mapFilter,
    required _VerificationQueueTab verificationQueueTab,
    required String focusReference,
    required _FocusLinkState focusState,
    required bool connectingToLiveData,
    required ValueChanged<String> onSelectMarker,
    required VoidCallback onZoomIn,
    required VoidCallback onZoomOut,
    required VoidCallback onCenterActive,
    required VoidCallback onCycleFilter,
    required ValueChanged<_VerificationQueueTab> onSetQueueTab,
    required VoidCallback? onOpenDispatches,
  }) {
    final toggleMapLabel = host.mapExpanded ? 'Close Map' : 'Open Map';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: OnyxColorTokens.backgroundSecondary,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: OnyxColorTokens.divider),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 880;
                final left = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: OnyxColorTokens.accentSky.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: OnyxColorTokens.accentSky.withValues(
                            alpha: 0.20,
                          ),
                        ),
                      ),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: OnyxColorTokens.accentSky.withValues(
                            alpha: 0.50,
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tactical Map',
                            style: GoogleFonts.inter(
                              color: OnyxColorTokens.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Guard positions · Geofence zones · Incident markers',
                            style: GoogleFonts.inter(
                              color: OnyxColorTokens.textDisabled,
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final right = Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _mapStatusChip(
                      '$respondersCount Responders',
                      border: OnyxColorTokens.divider,
                      color: OnyxColorTokens.textDisabled,
                    ),
                    _mapStatusChip(
                      '$geofenceAlerts Geofence anomalies',
                      border: geofenceAlerts > 0
                          ? OnyxColorTokens.accentAmber.withValues(alpha: 0.20)
                          : OnyxColorTokens.divider,
                      color: geofenceAlerts > 0
                          ? OnyxColorTokens.accentAmber.withValues(alpha: 0.55)
                          : OnyxColorTokens.textDisabled,
                    ),
                    _mapStatusChip(
                      cctvReadiness == 'ACTIVE'
                          ? 'DVR Active'
                          : 'DVR $cctvReadiness',
                      border: OnyxColorTokens.divider,
                      color: OnyxColorTokens.textDisabled,
                    ),
                    InkWell(
                      onTap: () => host.setMapExpanded(!host.mapExpanded),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: OnyxColorTokens.accentSky.withValues(
                            alpha: 0.10,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: OnyxColorTokens.accentSky.withValues(
                              alpha: 0.18,
                            ),
                          ),
                        ),
                        child: Text(
                          toggleMapLabel,
                          style: GoogleFonts.inter(
                            color: OnyxColorTokens.accentSky.withValues(
                              alpha: 0.60,
                            ),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [left, const SizedBox(height: 10), right],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: left),
                    const SizedBox(width: 12),
                    right,
                  ],
                );
              },
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            child: host.mapExpanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _mapPanel(
                      buildContext: host.context,
                      markers: visibleMarkers,
                      mapBounds: mapBounds,
                      activeMarker: activeMarker,
                      zoom: mapZoom,
                      mapController: mapController,
                      activeFilter: mapFilter,
                      activeQueueTab: verificationQueueTab,
                      onSelectMarker: onSelectMarker,
                      onZoomIn: onZoomIn,
                      onZoomOut: onZoomOut,
                      onCenterActive: onCenterActive,
                      onCycleFilter: onCycleFilter,
                      onSetQueueTab: onSetQueueTab,
                      onOpenDispatches: onOpenDispatches,
                      focusReference: focusReference,
                      focusState: focusState,
                      geofenceAlerts: geofenceAlerts,
                      sosAlerts: visibleMarkers
                          .where((marker) => marker.status == _MarkerStatus.sos)
                          .length,
                      connectingToLiveData: connectingToLiveData,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _mapStatusChip(
    String label, {
    required Color border,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundPrimary,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w700,
        ),
      ),
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
                  : OnyxColorTokens.textMuted,
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
            foregroundColor: OnyxColorTokens.accentPurple,
            side: BorderSide(
              color: agentAction == null
                  ? _tacticalStrongBorderColor
                  : OnyxColorTokens.accentPurple,
            ),
            backgroundColor: OnyxColorTokens.surfaceInset,
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
                    colors: [
                      OnyxColorTokens.accentPurple,
                      OnyxColorTokens.accentPurple,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: OnyxColorTokens.accentPurple.withValues(
                        alpha: 0.20,
                      ),
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
                          foreground: OnyxColorTokens.accentSky,
                          background: OnyxColorTokens.accentSky.withValues(
                            alpha: 0.10,
                          ),
                          border: OnyxColorTokens.accentSky.withValues(
                            alpha: 0.40,
                          ),
                        ),
                        _heroChip(
                          label: '$limitedCount Limited Watch',
                          foreground: limitedCount > 0
                              ? OnyxColorTokens.accentAmber
                              : OnyxColorTokens.textMuted,
                          background: limitedCount > 0
                              ? OnyxColorTokens.accentAmber.withValues(
                                  alpha: 0.10,
                                )
                              : OnyxColorTokens.textMuted.withValues(
                                  alpha: 0.10,
                                ),
                          border: limitedCount > 0
                              ? OnyxColorTokens.accentAmber.withValues(
                                  alpha: 0.40,
                                )
                              : OnyxColorTokens.textMuted.withValues(
                                  alpha: 0.40,
                                ),
                        ),
                        _heroChip(
                          label: '$unavailableCount Unavailable',
                          foreground: unavailableCount > 0
                              ? OnyxColorTokens.accentRed
                              : OnyxColorTokens.textMuted,
                          background: unavailableCount > 0
                              ? OnyxColorTokens.accentRed.withValues(
                                  alpha: 0.10,
                                )
                              : OnyxColorTokens.textMuted.withValues(
                                  alpha: 0.10,
                                ),
                          border: unavailableCount > 0
                              ? OnyxColorTokens.accentRed.withValues(
                                  alpha: 0.40,
                                )
                              : OnyxColorTokens.textMuted.withValues(
                                  alpha: 0.40,
                                ),
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
              colors: [
                OnyxColorTokens.surfaceInset,
                OnyxColorTokens.surfaceInset,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _tacticalBorderColor),
            boxShadow: [
              BoxShadow(
                color: OnyxColorTokens.backgroundPrimary.withValues(
                  alpha: 0.07,
                ),
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
          side: const BorderSide(color: OnyxColorTokens.textMuted),
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
      accent: OnyxColorTokens.accentPurple,
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
                color: OnyxColorTokens.accentPurple.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: OnyxColorTokens.accentPurple.withValues(alpha: 0.40),
                ),
              ),
              child: const Icon(
                Icons.explore_rounded,
                color: OnyxColorTokens.accentPurple,
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
                  foreground: OnyxColorTokens.accentPurple,
                  background: OnyxColorTokens.accentPurple.withValues(
                    alpha: 0.08,
                  ),
                  border: OnyxColorTokens.accentPurple.withValues(alpha: 0.40),
                  onTap: headerDispatchAction,
                ),
              if (headerAgentAction != null)
                _tacticalWorkspaceActionChip(
                  key: const ValueKey('tactical-workspace-open-agent'),
                  label: 'Ask Agent',
                  foreground: OnyxColorTokens.accentPurple,
                  background: OnyxColorTokens.accentPurple.withValues(
                    alpha: 0.08,
                  ),
                  border: OnyxColorTokens.accentPurple.withValues(alpha: 0.40),
                  onTap: headerAgentAction,
                ),
              _tacticalWorkspaceActionChip(
                key: const ValueKey('tactical-workspace-cycle-filter'),
                label: 'Cycle',
                foreground: OnyxColorTokens.accentSky,
                background: OnyxColorTokens.accentSky.withValues(alpha: 0.08),
                border: OnyxColorTokens.accentSky.withValues(alpha: 0.40),
                onTap: onCycleFilter,
              ),
              _tacticalWorkspaceActionChip(
                key: const ValueKey('tactical-workspace-center-track'),
                label: 'Center track',
                foreground: OnyxColorTokens.accentAmber.withValues(alpha: 0.5),
                background: OnyxColorTokens.accentAmber.withValues(alpha: 0.08),
                border: OnyxColorTokens.accentAmber.withValues(alpha: 0.40),
                onTap: onCenterActive,
              ),
              _tacticalWorkspaceActionChip(
                key: const ValueKey('tactical-workspace-queue-anomalies'),
                label: 'Anomalies',
                foreground: OnyxColorTokens.accentRed,
                background: OnyxColorTokens.accentRed.withValues(alpha: 0.08),
                border: OnyxColorTokens.accentRed.withValues(alpha: 0.40),
                onTap: () => onSetQueueTab(_VerificationQueueTab.anomalies),
              ),
              _tacticalWorkspaceActionChip(
                key: const ValueKey('tactical-workspace-queue-matches'),
                label: 'Matches',
                foreground: OnyxColorTokens.accentSky,
                background: OnyxColorTokens.accentSky.withValues(alpha: 0.08),
                border: OnyxColorTokens.accentSky.withValues(alpha: 0.40),
                onTap: () => onSetQueueTab(_VerificationQueueTab.matches),
              ),
              _tacticalWorkspaceActionChip(
                key: const ValueKey('tactical-workspace-queue-assets'),
                label: 'Assets',
                foreground: OnyxColorTokens.accentGreen,
                background: OnyxColorTokens.accentGreen.withValues(alpha: 0.08),
                border: OnyxColorTokens.accentGreen.withValues(alpha: 0.40),
                onTap: () => onSetQueueTab(_VerificationQueueTab.assets),
              ),
              if (onOpenFleetStatus != null)
                _tacticalWorkspaceActionChip(
                  key: const ValueKey('tactical-workspace-open-fleet'),
                  label: 'Fleet status',
                  foreground: OnyxColorTokens.surfaceInset,
                  background: OnyxColorTokens.accentSky.withValues(alpha: 0.08),
                  border: OnyxColorTokens.accentSky.withValues(alpha: 0.40),
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
            boxShadow: [
              BoxShadow(
                color: OnyxColorTokens.backgroundPrimary.withValues(
                  alpha: 0.07,
                ),
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
          color: Color.alphaBlend(OnyxDesignTokens.glassSurface, background),
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
        boxShadow: [
          BoxShadow(
            color: OnyxColorTokens.backgroundPrimary.withValues(alpha: 0.07),
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
                    color: OnyxColorTokens.surfaceInset,
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
        ? OnyxColorTokens.accentSky
        : hasDispatchLead
        ? OnyxColorTokens.accentAmber.withValues(alpha: 0.5)
        : canRecoverLead
        ? OnyxColorTokens.accentRed
        : OnyxColorTokens.accentCyan;

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
        accent: OnyxColorTokens.textMuted,
      );
    }

    void openLeadDetail() {
      onOpenLatestWatchActionDetail(leadScope);
      onShowFeedback(
        'Focused lead fleet detail for ${leadScope.siteName}.',
        label: 'FLEET DETAIL',
        detail:
            '${leadScope.siteName} remains pinned while the fleet rail keeps the current watch lane in focus.',
        accent: OnyxColorTokens.accentCyan,
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
        accent: OnyxColorTokens.accentSky,
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
        accent: OnyxColorTokens.accentAmber.withValues(alpha: 0.5),
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
        accent: OnyxColorTokens.accentRed,
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
            boxShadow: [
              BoxShadow(
                color: OnyxColorTokens.backgroundPrimary.withValues(
                  alpha: 0.06,
                ),
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
                            color: OnyxColorTokens.surfaceInset,
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
                    OnyxColorTokens.accentSky,
                  ),
                  _topChip(
                    'Watch only',
                    '${focusSections.watchOnlyScopes.length}',
                    OnyxColorTokens.accentAmber.withValues(alpha: 0.5),
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
                    foreground: OnyxColorTokens.accentCyan,
                    background: OnyxColorTokens.accentCyan.withValues(
                      alpha: 0.08,
                    ),
                    border: OnyxColorTokens.accentCyan.withValues(alpha: 0.40),
                    onTap: openLeadDetail,
                  ),
                  if (hasTacticalLead)
                    _tacticalWorkspaceActionChip(
                      key: const ValueKey('tactical-fleet-focus-open-tactical'),
                      label: 'OPEN TACTICAL TRACK',
                      foreground: OnyxColorTokens.accentSky,
                      background: OnyxColorTokens.accentSky.withValues(
                        alpha: 0.08,
                      ),
                      border: OnyxColorTokens.accentSky.withValues(alpha: 0.40),
                      onTap: openLeadTactical,
                    ),
                  if (hasDispatchLead)
                    _tacticalWorkspaceActionChip(
                      key: const ValueKey('tactical-fleet-focus-open-dispatch'),
                      label: 'OPEN DISPATCH BOARD',
                      foreground: OnyxColorTokens.accentAmber.withValues(
                        alpha: 0.5,
                      ),
                      background: OnyxColorTokens.accentAmber.withValues(
                        alpha: 0.08,
                      ),
                      border: OnyxColorTokens.accentAmber.withValues(
                        alpha: 0.40,
                      ),
                      onTap: openLeadDispatch,
                    ),
                  if (canRecoverLead)
                    _tacticalWorkspaceActionChip(
                      key: const ValueKey('tactical-fleet-focus-resync'),
                      label: 'Resync coverage',
                      foreground: OnyxColorTokens.accentRed,
                      background: OnyxColorTokens.accentRed.withValues(
                        alpha: 0.08,
                      ),
                      border: OnyxColorTokens.accentRed.withValues(alpha: 0.40),
                      onTap: recoverLeadScope,
                    ),
                  if (activeWatchActionDrilldown != null)
                    _tacticalWorkspaceActionChip(
                      key: const ValueKey('tactical-fleet-focus-clear'),
                      label: 'Clear focus',
                      foreground: OnyxColorTokens.textMuted,
                      background: OnyxColorTokens.textMuted.withValues(
                        alpha: 0.08,
                      ),
                      border: OnyxColorTokens.textMuted.withValues(alpha: 0.40),
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
    final accent = primaryDrilldown?.accentColor ?? OnyxColorTokens.textMuted;
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
        boxShadow: [
          BoxShadow(
            color: OnyxColorTokens.backgroundPrimary.withValues(alpha: 0.06),
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
                    OnyxColorTokens.accentSky,
                  ),
                  _topChip(
                    'Watch only',
                    '${sections.watchOnlyScopes.length}',
                    OnyxColorTokens.accentAmber.withValues(alpha: 0.5),
                  ),
                  _topChip(
                    'High risk',
                    '${sections.highRiskCount}',
                    OnyxColorTokens.accentRed,
                  ),
                  _topChip(
                    'Gaps',
                    '${sections.gapCount}',
                    OnyxColorTokens.accentRed,
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
                        foreground: OnyxColorTokens.textMuted,
                        background: OnyxColorTokens.textMuted.withValues(
                          alpha: 0.08,
                        ),
                        border: OnyxColorTokens.textMuted.withValues(
                          alpha: 0.40,
                        ),
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
        ? OnyxColorTokens.accentSky
        : hasDispatchLane
        ? OnyxColorTokens.accentAmber.withValues(alpha: 0.5)
        : OnyxColorTokens.accentCyan;

    void openSuppressedDetail(_SuppressedFleetReviewEntry entry) {
      onOpenLatestWatchActionDetail(entry.scope);
      onShowFeedback(
        'Focused suppressed review detail for ${entry.scope.siteName}.',
        label: 'REVIEW DETAIL',
        detail:
            'Latest suppressed scene-review context stays pinned for ${entry.scope.siteName}.',
        accent: OnyxColorTokens.accentCyan,
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
        accent: OnyxColorTokens.accentSky,
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
        accent: OnyxColorTokens.accentAmber.withValues(alpha: 0.5),
      );
    }

    void focusFilteredLane() {
      onFocusFilteredReviews();
      onShowFeedback(
        'Focused filtered review lane in verification rail.',
        label: 'FILTERED REVIEWS',
        detail:
            'Suppressed scene reviews now stay foregrounded ahead of broader fleet health.',
        accent: OnyxColorTokens.textMuted,
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
        color: OnyxColorTokens.backgroundSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: OnyxColorTokens.borderSubtle),
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
                  color: OnyxColorTokens.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              _topChip(
                'Internal',
                '${entries.length}',
                OnyxColorTokens.textMuted,
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'Recent ${videoOpsLabel.toUpperCase()} reviews ONYX held below the client-notification threshold across the active fleet.',
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textMuted,
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
              color: OnyxColorTokens.surfaceInset,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: OnyxColorTokens.divider),
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
                              color: OnyxColorTokens.textMuted,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            focusScope.siteName,
                            style: GoogleFonts.inter(
                              color: OnyxColorTokens.textPrimary,
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
                              color: OnyxColorTokens.textMuted,
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
                              color: OnyxColorTokens.textPrimary,
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
                      OnyxColorTokens.textMuted,
                    ),
                    _topChip(
                      'Action',
                      focusReview.decisionLabel.trim().isEmpty
                          ? 'Suppressed'
                          : focusReview.decisionLabel.trim(),
                      OnyxColorTokens.surfaceInset,
                    ),
                    _topChip(
                      'Posture',
                      focusReview.postureLabel.trim(),
                      OnyxColorTokens.accentGreen,
                    ),
                    if ((focusScope.latestCameraLabel ?? '').trim().isNotEmpty)
                      _topChip(
                        'Camera',
                        focusScope.latestCameraLabel!.trim(),
                        OnyxColorTokens.accentSky,
                      ),
                    _topChip(
                      'Reviewed',
                      _clockLabel(focusReview.reviewedAtUtc.toLocal()),
                      OnyxColorTokens.textMuted,
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
                      foreground: OnyxColorTokens.textMuted,
                      background: OnyxColorTokens.textMuted.withValues(
                        alpha: 0.08,
                      ),
                      border: OnyxColorTokens.textMuted.withValues(alpha: 0.40),
                      onTap: focusFilteredLane,
                    ),
                    _tacticalWorkspaceActionChip(
                      key: const ValueKey(
                        'tactical-suppressed-focus-open-detail',
                      ),
                      label: 'Latest detail',
                      foreground: OnyxColorTokens.accentCyan,
                      background: OnyxColorTokens.accentCyan.withValues(
                        alpha: 0.08,
                      ),
                      border: OnyxColorTokens.accentCyan.withValues(
                        alpha: 0.40,
                      ),
                      onTap: () => openSuppressedDetail(focusEntry),
                    ),
                    if (hasTacticalLane)
                      _tacticalWorkspaceActionChip(
                        key: const ValueKey(
                          'tactical-suppressed-focus-open-tactical',
                        ),
                        label: 'OPEN TACTICAL TRACK',
                        foreground: OnyxColorTokens.accentSky,
                        background: OnyxColorTokens.accentSky.withValues(
                          alpha: 0.08,
                        ),
                        border: OnyxColorTokens.accentSky.withValues(
                          alpha: 0.40,
                        ),
                        onTap: () => openSuppressedTactical(focusEntry),
                      ),
                    if (hasDispatchLane)
                      _tacticalWorkspaceActionChip(
                        key: const ValueKey(
                          'tactical-suppressed-focus-open-dispatch',
                        ),
                        label: 'OPEN DISPATCH BOARD',
                        foreground: OnyxColorTokens.accentAmber.withValues(
                          alpha: 0.5,
                        ),
                        background: OnyxColorTokens.accentAmber.withValues(
                          alpha: 0.08,
                        ),
                        border: OnyxColorTokens.accentAmber.withValues(
                          alpha: 0.40,
                        ),
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
        color: OnyxColorTokens.backgroundPrimary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: OnyxColorTokens.surfaceElevated),
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
                  color: OnyxColorTokens.textMuted,
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
                OnyxColorTokens.surfaceInset,
              ),
              if ((scope.latestCameraLabel ?? '').trim().isNotEmpty)
                _topChip(
                  'Camera',
                  scope.latestCameraLabel!.trim(),
                  OnyxColorTokens.accentSky,
                ),
              _topChip(
                'Posture',
                review.postureLabel.trim(),
                OnyxColorTokens.accentGreen,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            review.decisionSummary.trim().isEmpty
                ? 'Suppressed because the activity remained below threshold.'
                : review.decisionSummary.trim(),
            style: GoogleFonts.inter(
              color: OnyxColorTokens.surfaceInset,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Scene review: ${review.summary.trim()}',
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textMuted,
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
                foreground: OnyxColorTokens.accentCyan,
                background: OnyxColorTokens.accentCyan.withValues(alpha: 0.08),
                border: OnyxColorTokens.accentCyan.withValues(alpha: 0.40),
                onTap: onOpenDetail,
              ),
              if (onOpenTactical != null)
                _tacticalWorkspaceActionChip(
                  key: ValueKey<String>(
                    'tactical-suppressed-tactical-${scope.siteId}',
                  ),
                  label: 'Tactical',
                  foreground: OnyxColorTokens.accentSky,
                  background: OnyxColorTokens.accentSky.withValues(alpha: 0.08),
                  border: OnyxColorTokens.accentSky.withValues(alpha: 0.40),
                  onTap: onOpenTactical,
                ),
              if (onOpenDispatch != null)
                _tacticalWorkspaceActionChip(
                  key: ValueKey<String>(
                    'tactical-suppressed-dispatch-${scope.siteId}',
                  ),
                  label: 'Dispatch',
                  foreground: OnyxColorTokens.accentAmber.withValues(
                    alpha: 0.5,
                  ),
                  background: OnyxColorTokens.accentAmber.withValues(
                    alpha: 0.08,
                  ),
                  border: OnyxColorTokens.accentAmber.withValues(alpha: 0.40),
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
      'LIVE' => OnyxColorTokens.accentGreen,
      'ACTIVE WATCH' => OnyxColorTokens.accentSky,
      'LIMITED WATCH' => OnyxColorTokens.accentAmber,
      'WATCH READY' => OnyxColorTokens.accentAmber.withValues(alpha: 0.5),
      _ => OnyxColorTokens.textMuted,
    };
    final watchColor = scope.watchLabel == 'LIMITED'
        ? OnyxColorTokens.accentAmber
        : OnyxColorTokens.accentSky;
    final phaseColor = (scope.watchWindowStateLabel ?? '').contains('LIMITED')
        ? OnyxColorTokens.accentAmber
        : scope.watchWindowStateLabel == 'IN WINDOW'
        ? OnyxColorTokens.accentGreen
        : OnyxColorTokens.accentAmber.withValues(alpha: 0.5);
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
        ? OnyxColorTokens.accentRed
        : hasTacticalLane
        ? OnyxColorTokens.accentSky
        : hasDispatchLane
        ? OnyxColorTokens.accentAmber.withValues(alpha: 0.5)
        : OnyxColorTokens.accentCyan;

    void openFleetDetail() {
      onOpenLatestWatchActionDetail(scope);
      onShowFeedback(
        'Focused fleet scope detail for ${scope.siteName}.',
        label: 'FLEET DETAIL',
        detail:
            '${scope.siteName} stays pinned in the fleet rail while the latest watch context opens below it.',
        accent: OnyxColorTokens.accentCyan,
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
        accent: OnyxColorTokens.accentSky,
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
        accent: OnyxColorTokens.accentAmber.withValues(alpha: 0.5),
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
        accent: OnyxColorTokens.accentRed,
      );
    }

    return VideoFleetScopeHealthCard(
      key: ValueKey('tactical-fleet-scope-card-${scope.siteId}'),
      headerChild: Container(
        key: ValueKey('tactical-fleet-scope-command-${scope.siteId}'),
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: OnyxColorTokens.surfaceInset,
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
                      color: OnyxColorTokens.surfaceInset,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    commandDetail,
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.textMuted,
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
                          color: OnyxColorTokens.surfaceInset,
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
                  OnyxColorTokens.textMuted,
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
                    OnyxColorTokens.accentSky,
                  ),
                if ((scope.latestCameraLabel ?? '').trim().isNotEmpty)
                  _topChip(
                    'Camera',
                    scope.latestCameraLabel!,
                    OnyxColorTokens.textMuted,
                  ),
                if (!scope.hasIncidentContext)
                  _topChip(
                    'Context',
                    'Pending',
                    OnyxColorTokens.accentAmber.withValues(alpha: 0.5),
                  ),
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
        color: OnyxColorTokens.textMuted,
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
      lastSeenStyle: GoogleFonts.inter(
        color: OnyxColorTokens.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      statusDetailStyle: GoogleFonts.inter(
        color: OnyxColorTokens.accentAmber.withValues(alpha: 0.5),
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
      noteStyle: GoogleFonts.inter(
        color: OnyxColorTokens.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
      latestStyle: GoogleFonts.inter(
        color: OnyxColorTokens.surfaceInset,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      primaryGroupLabel: 'COMMAND POSTURE',
      primaryGroupAccent: commandAccent,
      primaryGroupKey: ValueKey('tactical-fleet-scope-posture-${scope.siteId}'),
      contextGroupLabel: 'WATCH CONTEXT',
      contextGroupAccent: OnyxColorTokens.accentAmber.withValues(alpha: 0.5),
      contextGroupKey: ValueKey('tactical-fleet-scope-context-${scope.siteId}'),
      latestGroupLabel: 'LATEST SIGNAL',
      latestGroupAccent: OnyxColorTokens.accentCyan,
      latestGroupKey: ValueKey('tactical-fleet-scope-latest-${scope.siteId}'),
      secondaryGroupLabel: 'LIVE FEED',
      secondaryGroupAccent: OnyxColorTokens.accentSky,
      secondaryGroupKey: ValueKey('tactical-fleet-scope-feed-${scope.siteId}'),
      actionsGroupLabel: 'COMMAND ACTIONS',
      actionsGroupAccent: primaryActionColor,
      actionsGroupKey: ValueKey('tactical-fleet-scope-actions-${scope.siteId}'),
      primaryChips: [
        if ((scope.operatorOutcomeLabel ?? '').trim().isNotEmpty)
          _topChip(
            'Cue',
            scope.operatorOutcomeLabel!,
            OnyxColorTokens.accentCyan,
          ),
        if ((scope.operatorOutcomeLabel ?? '').trim().isEmpty &&
            (scope.lastRecoveryLabel ?? '').trim().isNotEmpty)
          _topChip(
            'Recovery',
            scope.lastRecoveryLabel!,
            OnyxColorTokens.accentGreen,
          ),
        if (scope.hasWatchActivationGap)
          _topChip(
            'Gap',
            scope.watchActivationGapLabel!,
            OnyxColorTokens.accentRed,
          ),
        if (!scope.hasIncidentContext)
          _topChip(
            'Context',
            'Pending',
            OnyxColorTokens.accentAmber.withValues(alpha: 0.5),
          ),
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
                ? OnyxColorTokens.accentGreen
                : scope.clientDecisionChipValue == 'Review'
                ? OnyxColorTokens.accentAmber.withValues(alpha: 0.5)
                : OnyxColorTokens.accentRed,
          ),
        _topChip('Status', scope.statusLabel, statusColor),
        _topChip('Watch', scope.watchLabel, watchColor),
        _topChip(
          'Freshness',
          scope.freshnessLabel,
          _fleetFreshnessColor(scope),
        ),
        _topChip(
          'Events 6h',
          '${scope.recentEvents}',
          OnyxColorTokens.textMuted,
        ),
      ],
      secondaryChips: [
        if (scope.watchWindowLabel != null)
          _topChip(
            'Window',
            scope.watchWindowLabel!,
            OnyxColorTokens.accentGreen,
          ),
        if (scope.watchWindowStateLabel != null)
          _topChip('Phase', scope.watchWindowStateLabel!, phaseColor),
        if (scope.latestRiskScore != null)
          _topChip(
            'Risk',
            _fleetRiskLabel(scope.latestRiskScore!),
            _fleetRiskColor(scope.latestRiskScore!),
          ),
        if (scope.latestCameraLabel != null)
          _topChip(
            'Camera',
            scope.latestCameraLabel!,
            OnyxColorTokens.textMuted,
          ),
      ],
      actionChildren: [
        _fleetActionButton(
          key: ValueKey('tactical-fleet-detail-${scope.siteId}'),
          label: 'Latest detail',
          color: OnyxColorTokens.accentCyan,
          onPressed: openFleetDetail,
        ),
        if (canRecoverCoverage)
          _fleetActionButton(
            key: ValueKey('tactical-fleet-resync-${scope.siteId}'),
            label: 'Resync',
            color: OnyxColorTokens.accentRed,
            onPressed: recoverFleetScope,
          ),
        if (hasTacticalLane)
          _fleetActionButton(
            key: ValueKey('tactical-fleet-tactical-${scope.siteId}'),
            label: 'Tactical',
            color: OnyxColorTokens.accentSky,
            onPressed: openFleetTactical,
          ),
        if (hasDispatchLane)
          _fleetActionButton(
            key: ValueKey('tactical-fleet-dispatch-${scope.siteId}'),
            label: 'Dispatch',
            color: OnyxColorTokens.accentAmber.withValues(alpha: 0.5),
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
        color: OnyxColorTokens.backgroundPrimary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: OnyxColorTokens.surfaceElevated),
      ),
      constraints: const BoxConstraints(minWidth: 230, maxWidth: 320),
    );
  }

  Color _fleetScopeCommandAccent(VideoFleetScopeHealthView scope) {
    if (scope.hasWatchActivationGap) {
      return OnyxColorTokens.accentRed;
    }
    if (scope.identityPolicyChipValue != null) {
      return identityPolicyAccentColorForScope(scope);
    }
    if (scope.escalationCount > 0) {
      return OnyxColorTokens.accentRed;
    }
    if (scope.alertCount > 0) {
      return OnyxColorTokens.accentCyan;
    }
    if (scope.repeatCount > 0) {
      return OnyxColorTokens.accentAmber.withValues(alpha: 0.5);
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
        accent: OnyxColorTokens.accentSky,
      ),
      _fleetSummaryTile(
        key: const ValueKey('tactical-fleet-summary-tile-limited'),
        'Limited',
        '${sections.limitedCount}',
        detail: 'Remote monitoring constrained',
        accent: OnyxColorTokens.accentAmber,
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
        accent: OnyxColorTokens.accentRed,
      ),
      _fleetSummaryTile(
        key: const ValueKey('tactical-fleet-summary-tile-high-risk'),
        'High Risk',
        '${sections.highRiskCount}',
        detail: '70+ risk scopes in rail',
        accent: OnyxColorTokens.accentRed,
      ),
      _fleetSummaryTile(
        key: const ValueKey('tactical-fleet-summary-tile-recovered'),
        'Recovered 6h',
        '${sections.recoveredCount}',
        detail: 'Recent operator recovery passes',
        accent: OnyxColorTokens.accentGreen,
      ),
      _fleetSummaryTile(
        key: const ValueKey('tactical-fleet-summary-tile-suppressed'),
        'Suppressed',
        '${sections.suppressedCount}',
        detail: 'Quiet filtered watch reviews',
        accent: OnyxColorTokens.textMuted,
      ),
      _fleetSummaryTile(
        key: const ValueKey('tactical-fleet-summary-tile-alerts'),
        'Alerts',
        '${sections.alertActionCount}',
        detail: 'Client alerts sent from rail',
        accent: OnyxColorTokens.accentCyan,
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
        accent: OnyxColorTokens.accentAmber.withValues(alpha: 0.5),
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
        accent: OnyxColorTokens.accentRed,
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
        accent: OnyxColorTokens.textMuted,
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
        accent: OnyxColorTokens.accentAmber.withValues(alpha: 0.5),
      ),
      _fleetSummaryTile(
        key: const ValueKey('tactical-fleet-summary-tile-no-incident'),
        'No Incident',
        '${sections.noIncidentCount}',
        detail: 'Telemetry without linked incident',
        accent: OnyxColorTokens.textMuted,
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
      return OnyxColorTokens.accentRed;
    }
    if (score >= 70) {
      return OnyxColorTokens.accentAmber.withValues(alpha: 0.5);
    }
    if (score >= 40) {
      return OnyxColorTokens.accentSky.withValues(alpha: 0.75);
    }
    return OnyxColorTokens.textMuted;
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
      'Fresh' => OnyxColorTokens.accentGreen,
      'Recent' => OnyxColorTokens.accentSky,
      'Stale' => OnyxColorTokens.accentRed,
      'Quiet' => OnyxColorTokens.accentAmber.withValues(alpha: 0.5),
      _ => OnyxColorTokens.textMuted,
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
              _topChip('Active Responders', '8', OnyxColorTokens.accentSky),
              _topChip(
                'Geofence Alerts',
                geofenceAlerts.toString(),
                geofenceAlerts > 0
                    ? OnyxColorTokens.accentAmber
                    : OnyxColorTokens.textMuted,
              ),
              _topChip(
                'SOS',
                sosAlerts.toString(),
                sosAlerts > 0
                    ? OnyxColorTokens.accentRed
                    : OnyxColorTokens.textMuted,
              ),
              _topChip('Mode', mode, OnyxColorTokens.accentSky),
              _topChip(
                videoOpsLabel,
                cctvReadiness,
                cctvReadiness == 'ACTIVE'
                    ? OnyxColorTokens.accentGreen
                    : cctvReadiness == 'PARTIAL'
                    ? OnyxColorTokens.accentAmber.withValues(alpha: 0.5)
                    : OnyxColorTokens.textMuted,
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
                  OnyxColorTokens.accentSky,
                ),
            ],
          ),
          SizedBox(height: compactDetails ? 3 : 4),
          Text(
            summaryLine,
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textMuted,
              fontSize: compactDetails ? 8.5 : 9,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!compactDetails) ...[
            const SizedBox(height: 3),
            Text(
              '$videoOpsLabel Recent: $cctvRecentSignalSummary',
              style: GoogleFonts.inter(
                color: OnyxColorTokens.textMuted,
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
        color: OnyxColorTokens.textMuted.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: OnyxColorTokens.textMuted.withValues(alpha: 0.27),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Scope focus active',
            style: GoogleFonts.inter(
              color: OnyxColorTokens.accentSky,
              fontSize: 7.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            scopeLabel,
            style: GoogleFonts.inter(
              color: OnyxColorTokens.surfaceInset,
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
              color: OnyxColorTokens.textMuted,
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
        boxShadow: [
          BoxShadow(
            color: OnyxColorTokens.backgroundPrimary.withValues(alpha: 0.07),
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
                        backgroundColor: OnyxColorTokens.backgroundPrimary,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'omnix_dashboard',
                        ),
                        MarkerLayer(
                          markers: markers
                              .where(
                                (marker) => marker.type == _MarkerType.site,
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
                          color: OnyxColorTokens.accentRed.withValues(
                            alpha: 0.20,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: OnyxColorTokens.accentRed.withValues(
                              alpha: 0.60,
                            ),
                          ),
                        ),
                        child: Text(
                          'SOS TRIGGER • ${triggerSos.length} geofence anomalies',
                          style: GoogleFonts.inter(
                            color: OnyxColorTokens.accentRed,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  if (connectingToLiveData && markers.isEmpty)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: OnyxColorTokens.backgroundPrimary.withValues(
                            alpha: 0.80,
                          ),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: OnyxColorTokens.backgroundPrimary,
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
                                    color: OnyxColorTokens.accentSky,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Connecting to live data\u2026',
                                  style: GoogleFonts.inter(
                                    color: OnyxColorTokens.accentSky,
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
                          color: OnyxColorTokens.textPrimary.withValues(
                            alpha: 0.96,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _tacticalStrongBorderColor),
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
                        _legendPill('Guard Ping', OnyxColorTokens.accentSky),
                        _legendPill('Vehicle', OnyxColorTokens.accentGreen),
                        _legendPill('Incident', OnyxColorTokens.accentRed),
                        _legendPill('Geofence', OnyxColorTokens.accentCyan),
                        _legendPill(
                          'Geofence Alert',
                          geofenceAlerts > 0
                              ? OnyxColorTokens.accentAmber
                              : OnyxColorTokens.textMuted,
                        ),
                        _legendPill(
                          'SOS',
                          sosAlerts > 0
                              ? OnyxColorTokens.accentRed
                              : OnyxColorTokens.textMuted,
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
                OnyxColorTokens.accentSky,
              ),
              _topChip('Focus', focusLabel, _focusStateColor(focusState)),
              if (marker.battery != null)
                _topChip(
                  'Battery',
                  '${marker.battery}%',
                  marker.battery! < 20
                      ? OnyxColorTokens.accentAmber
                      : OnyxColorTokens.accentGreen,
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
                foreground: OnyxColorTokens.accentAmber.withValues(alpha: 0.5),
                background: OnyxColorTokens.accentAmber.withValues(alpha: 0.08),
                border: OnyxColorTokens.accentAmber.withValues(alpha: 0.40),
                onTap: onCenterActive,
              ),
              _tacticalWorkspaceActionChip(
                key: const ValueKey('tactical-map-focus-queue-anomalies'),
                label: 'Anomalies',
                foreground: OnyxColorTokens.accentRed,
                background: OnyxColorTokens.accentRed.withValues(alpha: 0.08),
                border: OnyxColorTokens.accentRed.withValues(alpha: 0.40),
                onTap: () => onSetQueueTab(_VerificationQueueTab.anomalies),
              ),
              _tacticalWorkspaceActionChip(
                key: const ValueKey('tactical-map-focus-queue-matches'),
                label: 'Matches',
                foreground: OnyxColorTokens.accentSky,
                background: OnyxColorTokens.accentSky.withValues(alpha: 0.08),
                border: OnyxColorTokens.accentSky.withValues(alpha: 0.40),
                onTap: () => onSetQueueTab(_VerificationQueueTab.matches),
              ),
              _tacticalWorkspaceActionChip(
                key: const ValueKey('tactical-map-focus-queue-assets'),
                label: 'Assets',
                foreground: OnyxColorTokens.accentGreen,
                background: OnyxColorTokens.accentGreen.withValues(alpha: 0.08),
                border: OnyxColorTokens.accentGreen.withValues(alpha: 0.40),
                onTap: () => onSetQueueTab(_VerificationQueueTab.assets),
              ),
              if (onOpenDispatches != null)
                _tacticalWorkspaceActionChip(
                  key: const ValueKey('tactical-map-focus-open-dispatches'),
                  label: 'OPEN DISPATCH BOARD',
                  foreground: OnyxColorTokens.accentPurple,
                  background: OnyxColorTokens.accentPurple.withValues(
                    alpha: 0.08,
                  ),
                  border: OnyxColorTokens.accentPurple.withValues(alpha: 0.40),
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
                color: OnyxColorTokens.textMuted,
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
      _FocusLinkState.exact => OnyxColorTokens.accentGreen,
      _FocusLinkState.scopeBacked => OnyxColorTokens.accentSky,
      _FocusLinkState.seeded => OnyxColorTokens.accentAmber,
      _FocusLinkState.none => OnyxColorTokens.textMuted,
    };
  }

  Color _focusStateTextColor(_FocusLinkState state) {
    return switch (state) {
      _FocusLinkState.exact => OnyxColorTokens.accentGreen.withValues(
        alpha: 0.3,
      ),
      _FocusLinkState.scopeBacked => OnyxColorTokens.surfaceInset,
      _FocusLinkState.seeded => OnyxColorTokens.accentAmber.withValues(
        alpha: 0.5,
      ),
      _FocusLinkState.none => OnyxColorTokens.textMuted,
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
    final scoped = siteMarkers
        .where((site) {
          final siteClientId = site.clientId.trim();
          if (scopeClientId.isNotEmpty && siteClientId != scopeClientId) {
            return false;
          }
          if (scopeSiteId.isNotEmpty && site.id.trim() != scopeSiteId) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
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
    return orderedEvents
        .asMap()
        .entries
        .map((entry) {
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
        })
        .toList(growable: false);
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
      IntelligenceReceived value =>
        value.intelligenceId.trim().isEmpty
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
    final incident = baseMarkers.where(
      (marker) => marker.type == _MarkerType.incident,
    );
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
    final scopedSites = siteMarkers
        .where((site) {
          if (scopeClientId.isNotEmpty &&
              site.clientId.trim() != scopeClientId) {
            return false;
          }
          if (scopeSiteId.isNotEmpty && site.id.trim() != scopeSiteId) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
    final points = <LatLng>[
      ...scopedSites.map((site) => LatLng(site.lat, site.lng)),
      ...markers.map((marker) => marker.point),
      ..._geofences.map((fence) => fence.point),
    ];
    if (points.isEmpty) {
      return LatLngBounds(
        LatLng(
          _johannesburgCenter.latitude - 0.01,
          _johannesburgCenter.longitude - 0.01,
        ),
        LatLng(
          _johannesburgCenter.latitude + 0.01,
          _johannesburgCenter.longitude + 0.01,
        ),
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
        ? OnyxColorTokens.accentGreen
        : matchScore >= 60
        ? OnyxColorTokens.accentAmber
        : OnyxColorTokens.accentRed;
    final queueAccent = switch (activeQueueTab) {
      _VerificationQueueTab.anomalies => OnyxColorTokens.accentRed,
      _VerificationQueueTab.matches => OnyxColorTokens.accentSky,
      _VerificationQueueTab.assets => OnyxColorTokens.accentGreen,
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
        _VerificationQueueTab.anomalies => OnyxColorTokens.accentRed,
        _VerificationQueueTab.matches => OnyxColorTokens.accentSky,
        _VerificationQueueTab.assets => OnyxColorTokens.accentGreen,
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
        accent: OnyxColorTokens.accentAmber.withValues(alpha: 0.5),
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
        accent: OnyxColorTokens.accentPurple,
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
            ? OnyxColorTokens.accentSky
            : OnyxColorTokens.accentAmber.withValues(alpha: 0.5),
      _VerificationQueueTab.matches =>
        onOpenDispatches == null
            ? OnyxColorTokens.accentRed
            : OnyxColorTokens.accentPurple,
      _VerificationQueueTab.assets =>
        activeMarker == null
            ? OnyxColorTokens.accentSky
            : OnyxColorTokens.accentAmber.withValues(alpha: 0.5),
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
      _VerificationQueueTab.anomalies => OnyxColorTokens.accentRed,
      _VerificationQueueTab.matches => OnyxColorTokens.accentSky,
      _VerificationQueueTab.assets => OnyxColorTokens.accentGreen,
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
        boxShadow: [
          BoxShadow(
            color: OnyxColorTokens.backgroundPrimary.withValues(alpha: 0.07),
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
                      OnyxColorTokens.textMuted,
                    ),
                    if (activeMarker?.battery != null)
                      _topChip(
                        'Battery',
                        '${activeMarker!.battery}%',
                        activeMarker.battery! < 20
                            ? OnyxColorTokens.accentAmber
                            : OnyxColorTokens.accentGreen,
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
                        foreground: OnyxColorTokens.accentAmber.withValues(
                          alpha: 0.5,
                        ),
                        background: OnyxColorTokens.accentAmber.withValues(
                          alpha: 0.08,
                        ),
                        border: OnyxColorTokens.accentAmber.withValues(
                          alpha: 0.40,
                        ),
                        onTap: centerTrackWithFeedback,
                      ),
                    _tacticalWorkspaceActionChip(
                      key: const ValueKey(
                        'tactical-verification-focus-queue-anomalies',
                      ),
                      label: 'Anomalies',
                      foreground: OnyxColorTokens.accentRed,
                      background: OnyxColorTokens.accentRed.withValues(
                        alpha: 0.08,
                      ),
                      border: OnyxColorTokens.accentRed.withValues(alpha: 0.40),
                      onTap: () => openQueueWithFeedback(
                        _VerificationQueueTab.anomalies,
                      ),
                    ),
                    _tacticalWorkspaceActionChip(
                      key: const ValueKey(
                        'tactical-verification-focus-queue-matches',
                      ),
                      label: 'Matches',
                      foreground: OnyxColorTokens.accentSky,
                      background: OnyxColorTokens.accentSky.withValues(
                        alpha: 0.08,
                      ),
                      border: OnyxColorTokens.accentSky.withValues(alpha: 0.40),
                      onTap: () =>
                          openQueueWithFeedback(_VerificationQueueTab.matches),
                    ),
                    _tacticalWorkspaceActionChip(
                      key: const ValueKey(
                        'tactical-verification-focus-queue-assets',
                      ),
                      label: 'Assets',
                      foreground: OnyxColorTokens.accentGreen,
                      background: OnyxColorTokens.accentGreen.withValues(
                        alpha: 0.08,
                      ),
                      border: OnyxColorTokens.accentGreen.withValues(
                        alpha: 0.40,
                      ),
                      onTap: () =>
                          openQueueWithFeedback(_VerificationQueueTab.assets),
                    ),
                    if (onOpenDispatches != null)
                      _tacticalWorkspaceActionChip(
                        key: const ValueKey(
                          'tactical-verification-focus-open-dispatches',
                        ),
                        label: 'OPEN DISPATCH BOARD',
                        foreground: OnyxColorTokens.accentPurple,
                        background: OnyxColorTokens.accentPurple.withValues(
                          alpha: 0.08,
                        ),
                        border: OnyxColorTokens.accentPurple.withValues(
                          alpha: 0.40,
                        ),
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
                              color: OnyxColorTokens.accentSky,
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
                      OnyxColorTokens.textMuted,
                    ),
                    _topChip('Live', timestamp, OnyxColorTokens.accentRed),
                    _topChip(
                      'Drift',
                      comparisonDriftLabel,
                      _anomalies.isEmpty
                          ? OnyxColorTokens.accentGreen
                          : OnyxColorTokens.accentRed,
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
                      accent: OnyxColorTokens.textMuted,
                      anomalies: const [],
                    );
                    final liveFrame = _lensFrame(
                      label: 'LIVE • $timestamp',
                      accent: OnyxColorTokens.accentRed,
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
                      foreground: OnyxColorTokens.accentRed,
                      background: OnyxColorTokens.accentRed.withValues(
                        alpha: 0.08,
                      ),
                      border: OnyxColorTokens.accentRed.withValues(alpha: 0.40),
                      onTap: () => openQueueWithFeedback(
                        _VerificationQueueTab.anomalies,
                      ),
                    ),
                    _tacticalWorkspaceActionChip(
                      key: const ValueKey(
                        'tactical-lens-comparison-review-matches',
                      ),
                      label: 'Review matches',
                      foreground: OnyxColorTokens.accentSky,
                      background: OnyxColorTokens.accentSky.withValues(
                        alpha: 0.08,
                      ),
                      border: OnyxColorTokens.accentSky.withValues(alpha: 0.40),
                      onTap: () =>
                          openQueueWithFeedback(_VerificationQueueTab.matches),
                    ),
                    _tacticalWorkspaceActionChip(
                      key: const ValueKey(
                        'tactical-lens-comparison-review-assets',
                      ),
                      label: 'Review assets',
                      foreground: OnyxColorTokens.accentGreen,
                      background: OnyxColorTokens.accentGreen.withValues(
                        alpha: 0.08,
                      ),
                      border: OnyxColorTokens.accentGreen.withValues(
                        alpha: 0.40,
                      ),
                      onTap: () =>
                          openQueueWithFeedback(_VerificationQueueTab.assets),
                    ),
                    if (activeMarker != null)
                      _tacticalWorkspaceActionChip(
                        key: const ValueKey(
                          'tactical-lens-comparison-center-track',
                        ),
                        label: 'Center track',
                        foreground: OnyxColorTokens.accentAmber.withValues(
                          alpha: 0.5,
                        ),
                        background: OnyxColorTokens.accentAmber.withValues(
                          alpha: 0.08,
                        ),
                        border: OnyxColorTokens.accentAmber.withValues(
                          alpha: 0.40,
                        ),
                        onTap: centerTrackWithFeedback,
                      ),
                    if (onOpenDispatches != null)
                      _tacticalWorkspaceActionChip(
                        key: const ValueKey(
                          'tactical-lens-comparison-open-dispatches',
                        ),
                        label: 'OPEN DISPATCH BOARD',
                        foreground: OnyxColorTokens.accentPurple,
                        background: OnyxColorTokens.accentPurple.withValues(
                          alpha: 0.08,
                        ),
                        border: OnyxColorTokens.accentPurple.withValues(
                          alpha: 0.40,
                        ),
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
                OnyxColorTokens.accentSky,
              ),
              _topChip(
                'Signals',
                '${telemetry.totalSignals}',
                OnyxColorTokens.textMuted,
              ),
              _topChip(
                'LPR Hits',
                '${telemetry.lprHits}',
                OnyxColorTokens.accentGreen,
              ),
              _topChip(
                'Anomalies',
                '${telemetry.anomalies}',
                OnyxColorTokens.accentRed,
              ),
              _topChip(
                'Snapshots',
                '${telemetry.snapshotsReady}',
                OnyxColorTokens.accentSky.withValues(alpha: 0.75),
              ),
              _topChip(
                'Clips',
                '${telemetry.clipsReady}',
                OnyxColorTokens.accentGreen,
              ),
              _topChip(
                'Trend',
                telemetry.anomalyTrend,
                OnyxColorTokens.accentAmber,
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
                      OnyxColorTokens.textMuted,
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
                        foreground: OnyxColorTokens.accentAmber.withValues(
                          alpha: 0.5,
                        ),
                        background: OnyxColorTokens.accentAmber.withValues(
                          alpha: 0.08,
                        ),
                        border: OnyxColorTokens.accentAmber.withValues(
                          alpha: 0.40,
                        ),
                        onTap: centerTrackWithFeedback,
                      ),
                    _tacticalWorkspaceActionChip(
                      key: const ValueKey(
                        'tactical-verification-queue-anomalies',
                      ),
                      label: 'Anomalies',
                      foreground: OnyxColorTokens.accentRed,
                      background: OnyxColorTokens.accentRed.withValues(
                        alpha: 0.08,
                      ),
                      border: OnyxColorTokens.accentRed.withValues(alpha: 0.40),
                      onTap: () => openQueueWithFeedback(
                        _VerificationQueueTab.anomalies,
                      ),
                    ),
                    _tacticalWorkspaceActionChip(
                      key: const ValueKey(
                        'tactical-verification-queue-matches',
                      ),
                      label: 'Matches',
                      foreground: OnyxColorTokens.accentSky,
                      background: OnyxColorTokens.accentSky.withValues(
                        alpha: 0.08,
                      ),
                      border: OnyxColorTokens.accentSky.withValues(alpha: 0.40),
                      onTap: () =>
                          openQueueWithFeedback(_VerificationQueueTab.matches),
                    ),
                    _tacticalWorkspaceActionChip(
                      key: const ValueKey('tactical-verification-queue-assets'),
                      label: 'Assets',
                      foreground: OnyxColorTokens.accentGreen,
                      background: OnyxColorTokens.accentGreen.withValues(
                        alpha: 0.08,
                      ),
                      border: OnyxColorTokens.accentGreen.withValues(
                        alpha: 0.40,
                      ),
                      onTap: () =>
                          openQueueWithFeedback(_VerificationQueueTab.assets),
                    ),
                    if (onOpenDispatches != null)
                      _tacticalWorkspaceActionChip(
                        key: const ValueKey(
                          'tactical-verification-queue-open-dispatches',
                        ),
                        label: 'OPEN DISPATCH BOARD',
                        foreground: OnyxColorTokens.accentPurple,
                        background: OnyxColorTokens.accentPurple.withValues(
                          alpha: 0.08,
                        ),
                        border: OnyxColorTokens.accentPurple.withValues(
                          alpha: 0.40,
                        ),
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
                      accent: OnyxColorTokens.textMuted,
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
                    accent: OnyxColorTokens.accentSky,
                  ),
                  const SizedBox(height: 6),
                  _verificationQueueRow(
                    label: 'LPR recognition hits',
                    detail:
                        '${telemetry.lprHits} plate hit${telemetry.lprHits == 1 ? '' : 's'} staged for controller review.',
                    accent: OnyxColorTokens.accentGreen,
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
                    accent: OnyxColorTokens.accentSky.withValues(alpha: 0.75),
                  ),
                  const SizedBox(height: 6),
                  _verificationQueueRow(
                    label: 'Clips ready',
                    detail:
                        '${telemetry.clipsReady} clip${telemetry.clipsReady == 1 ? '' : 's'} ready for operator playback.',
                    accent: OnyxColorTokens.accentGreen,
                  ),
                  const SizedBox(height: 6),
                  _verificationQueueRow(
                    label: 'Queue context',
                    detail: activeMarker == null
                        ? '${_mapFilterLabel(activeFilter)} filter is active with no selected track.'
                        : '${activeMarker.label} is centered in the current ${_mapFilterLabel(activeFilter).toLowerCase()} review queue.',
                    accent: OnyxColorTokens.accentAmber,
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
                : OnyxColorTokens.backgroundPrimary.withValues(alpha: 0.80),
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
                        color: OnyxColorTokens.surfaceInset,
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
                    color: OnyxColorTokens.textMuted,
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
                        ? OnyxColorTokens.accentAmber
                        : OnyxColorTokens.textMuted,
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

  Marker _fenceOverlay({required _SafetyGeofence fence}) {
    final color = switch (fence.status) {
      _FenceStatus.safe => OnyxColorTokens.accentCyan.withValues(alpha: 0.50),
      _FenceStatus.breach => OnyxColorTokens.accentRed.withValues(alpha: 0.80),
      _FenceStatus.stationary => OnyxColorTokens.accentAmber.withValues(
        alpha: 0.80,
      ),
    };
    final fill = switch (fence.status) {
      _FenceStatus.safe => OnyxColorTokens.accentCyan.withValues(alpha: 0.08),
      _FenceStatus.breach => OnyxColorTokens.accentRed.withValues(alpha: 0.13),
      _FenceStatus.stationary => OnyxColorTokens.accentAmber.withValues(
        alpha: 0.13,
      ),
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
        border: Border.all(
          color: OnyxColorTokens.textPrimary.withValues(alpha: 0.13),
        ),
        gradient: const LinearGradient(
          colors: [
            OnyxColorTokens.backgroundPrimary,
            OnyxColorTokens.backgroundPrimary,
          ],
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
                    color: OnyxColorTokens.backgroundPrimary.withValues(
                      alpha: 0.80,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.textPrimary.withValues(
                        alpha: 0.80,
                      ),
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
                      color: OnyxColorTokens.accentRed.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: OnyxColorTokens.accentRed.withValues(
                          alpha: 0.80,
                        ),
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
        color: OnyxColorTokens.accentRed.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: OnyxColorTokens.accentRed.withValues(alpha: 0.33),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: OnyxColorTokens.accentRed,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '$confidence%',
            style: GoogleFonts.robotoMono(
              color: OnyxColorTokens.accentRed,
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
      _VerificationQueueTab.anomalies => OnyxColorTokens.accentRed,
      _VerificationQueueTab.matches => OnyxColorTokens.accentSky,
      _VerificationQueueTab.assets => OnyxColorTokens.accentGreen,
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
                      accent: OnyxColorTokens.accentRed,
                    );
                  },
                  child: Text(
                    'Expire now',
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.accentRed,
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
                backgroundColor: OnyxColorTokens.surfaceInset,
                foregroundColor: OnyxColorTokens.accentRed,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: OnyxColorTokens.accentRed.withValues(alpha: 0.6),
                  ),
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
              color: OnyxColorTokens.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Color _markerColor(_MarkerType type, _MarkerStatus status) {
    if (status == _MarkerStatus.sos) return OnyxColorTokens.accentRed;
    return switch (type) {
      _MarkerType.guard => OnyxColorTokens.accentSky,
      _MarkerType.vehicle => OnyxColorTokens.accentGreen,
      _MarkerType.incident => OnyxColorTokens.accentRed,
      _MarkerType.site => OnyxColorTokens.textMuted,
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
          color: active
              ? OnyxColorTokens.accentCyan.withValues(alpha: 0.10)
              : _tacticalAltSurfaceColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active
                ? OnyxColorTokens.accentCyan.withValues(alpha: 0.53)
                : _tacticalBorderColor,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: active ? OnyxColorTokens.accentCyan : _tacticalBodyColor,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  final double size;
  final bool animated;

  const _PulseDot({
    required this.color,
    required this.size,
    this.animated = true,
  });

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );
  late final Animation<double> _opacity = Tween<double>(
    begin: 1,
    end: 0.3,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void initState() {
    super.initState();
    if (widget.animated) {
      _controller.repeat(reverse: true);
    } else {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant _PulseDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animated == widget.animated) {
      return;
    }
    if (widget.animated) {
      _controller.repeat(reverse: true);
    } else {
      _controller
        ..stop()
        ..value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    );
    if (!widget.animated) {
      return dot;
    }
    return FadeTransition(opacity: _opacity, child: dot);
  }
}
