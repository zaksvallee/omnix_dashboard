import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme/onyx_design_tokens.dart';

import '../application/export_coordinator.dart';
import '../application/morning_sovereign_report_service.dart';
import '../application/monitoring_global_posture_service.dart';
import '../application/monitoring_orchestrator_service.dart';
import '../application/mo_promotion_decision_store.dart';
import '../application/oversight_focus_formatter.dart';
import '../application/readiness_summary_formatter.dart';
import '../application/review_shortcut_contract.dart';
import '../application/shadow_mo_validation_summary.dart';
import '../application/shadow_mo_dossier_contract.dart';
import '../application/site_activity_intelligence_service.dart';
import '../application/synthetic_promotion_summary_formatter.dart';
import '../application/monitoring_synthetic_war_room_service.dart';
import '../application/monitoring_watch_action_plan.dart';
import '../domain/events/decision_created.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/events/execution_completed.dart';
import '../domain/events/execution_denied.dart';
import '../domain/events/guard_checked_in.dart';
import '../domain/events/incident_closed.dart';
import '../domain/events/intelligence_received.dart';
import '../domain/events/partner_dispatch_status_declared.dart';
import '../domain/events/patrol_completed.dart';
import '../domain/events/response_arrived.dart';
import '../domain/events/vehicle_visit_review_recorded.dart';
import '../application/monitoring_scene_review_store.dart';
import 'events_route_source.dart';
import 'layout_breakpoints.dart';
import 'onyx_surface.dart';
import 'ui_action_logger.dart';

class EventsReviewPage extends StatefulWidget {
  final List<DispatchEvent> events;
  final Map<String, MonitoringSceneReviewRecord> sceneReviewByIntelligenceId;
  final String? initialSourceFilter;
  final String? initialProviderFilter;
  final String? initialSelectedEventId;
  final List<String> initialScopedEventIds;
  final String? initialScopedMode;
  final List<SovereignReport> morningSovereignReportHistory;
  final String? currentMorningSovereignReportDate;
  final VoidCallback? onOpenGovernance;
  final void Function(String clientId, String siteId)? onOpenGovernanceForScope;
  final ValueChanged<String>? onOpenLedger;
  final ZaraEventsRouteSource initialRouteSource;
  final String initialOriginLabel;
  final VoidCallback? onReturnToOrigin;

  const EventsReviewPage({
    super.key,
    required this.events,
    this.sceneReviewByIntelligenceId = const {},
    this.initialSourceFilter,
    this.initialProviderFilter,
    this.initialSelectedEventId,
    this.initialScopedEventIds = const <String>[],
    this.initialScopedMode,
    this.morningSovereignReportHistory = const <SovereignReport>[],
    this.currentMorningSovereignReportDate,
    this.onOpenGovernance,
    this.onOpenGovernanceForScope,
    this.onOpenLedger,
    this.initialRouteSource = ZaraEventsRouteSource.navRail,
    this.initialOriginLabel = '',
    this.onReturnToOrigin,
  });

  @override
  State<EventsReviewPage> createState() => _EventsReviewPageState();
}

class _SeededDispatchEvent extends DispatchEvent {
  static const String auditTypeKey = 'seeded_dispatch_event';
  final String summary;
  final String clientId;
  final String regionId;
  final String siteId;

  const _SeededDispatchEvent({
    required super.eventId,
    required super.sequence,
    required super.version,
    required super.occurredAt,
    required this.summary,
    required this.clientId,
    required this.regionId,
    required this.siteId,
  });

  @override
  DispatchEvent copyWithSequence(int sequence) {
    return _SeededDispatchEvent(
      eventId: eventId,
      sequence: sequence,
      version: version,
      occurredAt: occurredAt,
      summary: summary,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
    );
  }

  @override
  String toAuditTypeKey() => auditTypeKey;
}

class _EventsReviewPageState extends State<EventsReviewPage> {
  static const _exportCoordinator = ExportCoordinator();
  static const _siteActivityService = SiteActivityIntelligenceService();
  static const _globalPostureService = MonitoringGlobalPostureService();
  static const _orchestratorService = MonitoringOrchestratorService();
  static const _syntheticWarRoomService = MonitoringSyntheticWarRoomService();
  static const _moPromotionDecisionStore = MoPromotionDecisionStore();
  static const String _filterAll = 'ALL';
  static const String _sourceFilterAll = 'ALL SOURCES';
  static const String _providerFilterAll = 'ALL PROVIDERS';
  static const String _identityPolicyFilterAll = 'ALL POLICIES';
  static const String _identityPolicyFilterFlagged = 'FLAGGED MATCH';
  static const String _identityPolicyFilterTemporary = 'TEMPORARY APPROVAL';
  static const String _identityPolicyFilterAllowlisted = 'ALLOWLISTED MATCH';
  static const List<String> _filterOptions = [
    'ALL',
    'INCIDENT CREATED',
    'DISPATCH SENT',
    'AI DECISION',
    'ALARM TRIGGERED',
  ];

  String _activeFilter = _filterAll;
  String _activeSourceFilter = _sourceFilterAll;
  String _activeProviderFilter = _providerFilterAll;
  String _activeIdentityPolicyFilter = _identityPolicyFilterAll;
  String _lastActionFeedback = '';
  DispatchEvent? _selectedEvent;
  final Map<String, GlobalKey> _rowKeys = <String, GlobalKey>{};
  String _lastAutoEnsuredEventId = '';
  bool _desktopWorkspaceActive = false;
  bool _selectedEventSyncQueued = false;
  DispatchEvent? _pendingSelectedEvent;
  bool _desktopWorkspaceSyncQueued = false;
  bool? _pendingDesktopWorkspaceActive;

  ({String clientId, String siteId})? _governanceScopeForEvents(
    List<DispatchEvent> events,
  ) {
    final clientIds = events
        .map(_eventClientId)
        .where((value) => value.trim().isNotEmpty)
        .map((value) => value.trim())
        .toSet();
    final siteIds = events
        .map(_eventSiteId)
        .where((value) => value.trim().isNotEmpty)
        .map((value) => value.trim())
        .toSet();
    if (clientIds.length != 1 || siteIds.length != 1) {
      return null;
    }
    return (clientId: clientIds.first, siteId: siteIds.first);
  }

  VoidCallback? _openGovernanceActionForEvents(List<DispatchEvent> events) {
    final scopedCallback = widget.onOpenGovernanceForScope;
    final scope = _governanceScopeForEvents(events);
    if (scopedCallback != null && scope != null) {
      return () => scopedCallback(scope.clientId, scope.siteId);
    }
    return widget.onOpenGovernance;
  }

  @override
  void initState() {
    super.initState();
    _activeSourceFilter = _normalizeSourceFilter(widget.initialSourceFilter);
    _activeProviderFilter = _normalizeProviderFilter(
      widget.initialProviderFilter,
    );
  }

  @override
  void didUpdateWidget(covariant EventsReviewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sourceChanged =
        oldWidget.initialSourceFilter != widget.initialSourceFilter;
    final providerChanged =
        oldWidget.initialProviderFilter != widget.initialProviderFilter;
    final selectedChanged =
        oldWidget.initialSelectedEventId != widget.initialSelectedEventId;
    final scopeChanged =
        oldWidget.initialScopedEventIds.length !=
            widget.initialScopedEventIds.length ||
        !_sameStringSet(
          oldWidget.initialScopedEventIds,
          widget.initialScopedEventIds,
        );
    if (sourceChanged || providerChanged || selectedChanged || scopeChanged) {
      final normalizedSource = _normalizeSourceFilter(
        widget.initialSourceFilter,
      );
      final normalizedProvider = _normalizeProviderFilter(
        widget.initialProviderFilter,
      );
      final nextSelectedId = (widget.initialSelectedEventId ?? '').trim();
      final nextSelectedEvent = nextSelectedId.isEmpty
          ? null
          : widget.events
                .where((event) => event.eventId == nextSelectedId)
                .fold<DispatchEvent?>(
                  null,
                  (current, event) => current ?? event,
                );
      if (normalizedSource != _activeSourceFilter ||
          normalizedProvider != _activeProviderFilter ||
          selectedChanged) {
        setState(() {
          _activeSourceFilter = normalizedSource;
          _activeProviderFilter = normalizedProvider;
          if (selectedChanged) {
            _selectedEvent = nextSelectedEvent;
          }
        });
      }
      if (selectedChanged &&
          (widget.initialSelectedEventId ?? '').trim().isNotEmpty) {
        _lastAutoEnsuredEventId = '';
      }
    }
  }

  void _queueSelectedEventSync(DispatchEvent? nextSelectedEvent) {
    _pendingSelectedEvent = nextSelectedEvent;
    if (_selectedEventSyncQueued) {
      return;
    }
    _selectedEventSyncQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _selectedEventSyncQueued = false;
      if (!mounted) {
        return;
      }
      final nextEvent = _pendingSelectedEvent;
      _pendingSelectedEvent = null;
      if ((_selectedEvent?.eventId ?? '') == (nextEvent?.eventId ?? '')) {
        return;
      }
      setState(() {
        _selectedEvent = nextEvent;
      });
    });
  }

  void _queueDesktopWorkspaceSync(bool desktopWorkspaceActive) {
    _pendingDesktopWorkspaceActive = desktopWorkspaceActive;
    if (_desktopWorkspaceSyncQueued) {
      return;
    }
    _desktopWorkspaceSyncQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _desktopWorkspaceSyncQueued = false;
      if (!mounted) {
        return;
      }
      final nextDesktopWorkspaceActive =
          _pendingDesktopWorkspaceActive ?? _desktopWorkspaceActive;
      _pendingDesktopWorkspaceActive = null;
      if (_desktopWorkspaceActive == nextDesktopWorkspaceActive) {
        return;
      }
      setState(() {
        _desktopWorkspaceActive = nextDesktopWorkspaceActive;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final requestedSelectedId = (widget.initialSelectedEventId ?? '').trim();
    final scopedEventIds = _normalizedScopedEventIds(
      widget.initialScopedEventIds,
    );
    final scopedBaseEvents = _scopedTimelineEvents(
      timeline: widget.events,
      scopedEventIds: scopedEventIds,
    );
    final focusedFallbackScope = _focusedFallbackScope(
      scopedEvents: scopedBaseEvents,
      allEvents: widget.events,
    );
    final focusedFallbackRegionId = _focusedFallbackRegionId(
      scopedEvents: scopedBaseEvents,
      allEvents: widget.events,
    );
    final hasFocusedFallback =
        requestedSelectedId.isNotEmpty &&
        !widget.events.any((event) => event.eventId == requestedSelectedId);
    final scopedEventIdsWithFocusedFallback = hasFocusedFallback
        ? <String>{...scopedEventIds, requestedSelectedId}
        : scopedEventIds;
    final timelineSource = _timelineWithFocusedFallback(
      baseEvents: widget.events,
      focusedEventId: requestedSelectedId,
      fallbackScope: focusedFallbackScope,
      fallbackRegionId: focusedFallbackRegionId,
    );
    final timeline = [...timelineSource]
      ..sort((a, b) => b.sequence.compareTo(a.sequence));
    final filteredByType = _activeFilter == _filterAll
        ? timeline
        : timeline
              .where((event) => _eventTypeLabel(event) == _activeFilter)
              .toList(growable: false);
    final filtered = _activeSourceFilter == _sourceFilterAll
        ? filteredByType
        : filteredByType
              .where((event) {
                if (event is! IntelligenceReceived) return false;
                return _normalizeSourceFilter(event.sourceType) ==
                    _activeSourceFilter;
              })
              .toList(growable: false);
    final scopedTimelineEvents = _scopedTimelineEvents(
      timeline: timeline,
      scopedEventIds: scopedEventIdsWithFocusedFallback,
    );
    final partnerScopeSummary = _partnerScopeSummary(scopedTimelineEvents);
    final tomorrowScopeSummary = _tomorrowPostureScopeSummary(
      scopedTimelineEvents,
    );
    final readinessScopeSummary = _readinessScopeSummary(scopedTimelineEvents);
    final syntheticScopeSummary = _syntheticScopeSummary(scopedTimelineEvents);
    final shadowScopeSummary = _shadowScopeSummary(scopedTimelineEvents);
    final activityScopeSummary = _activityScopeSummary(scopedTimelineEvents);
    final openGovernanceAction = _openGovernanceActionForEvents(
      scopedTimelineEvents,
    );
    final scopeFilteredBase = scopedEventIdsWithFocusedFallback.isEmpty
        ? filtered
        : filtered
              .where(
                (event) => scopedEventIdsWithFocusedFallback.contains(
                  event.eventId.trim(),
                ),
              )
              .toList(growable: false);
    final scopeFiltered = _preserveFocusedEvent(
      scopeFilteredBase,
      timeline: timeline,
      focusedEventId: requestedSelectedId,
    );
    final providerFiltered = _activeProviderFilter == _providerFilterAll
        ? scopeFiltered
        : scopeFiltered
              .where((event) {
                if (event is! IntelligenceReceived) return false;
                return _normalizeProviderFilter(event.provider) ==
                    _activeProviderFilter;
              })
              .toList(growable: false);
    final providerFocused = _preserveFocusedEvent(
      providerFiltered,
      timeline: timeline,
      focusedEventId: requestedSelectedId,
    );
    final identityPolicyOptions = _identityPolicyFilterOptions(providerFocused);
    final identityPolicyFiltered =
        _activeIdentityPolicyFilter == _identityPolicyFilterAll
        ? providerFocused
        : providerFocused
              .where((event) {
                if (event is! IntelligenceReceived) return false;
                return _eventIdentityPolicyFilterLabel(event) ==
                    _activeIdentityPolicyFilter;
              })
              .toList(growable: false);
    final focusedIdentityPolicyFiltered = _preserveFocusedEvent(
      identityPolicyFiltered,
      timeline: timeline,
      focusedEventId: requestedSelectedId,
    );
    final prioritizedEvents = _prioritizeEventsForScope(
      focusedIdentityPolicyFiltered,
      shadowScopeSummary: shadowScopeSummary,
    );
    DispatchEvent? requestedSelectedEvent;
    if (requestedSelectedId.isNotEmpty) {
      for (final event in prioritizedEvents) {
        if (event.eventId == requestedSelectedId) {
          requestedSelectedEvent = event;
          break;
        }
      }
    }
    final requestedSelectionFound = requestedSelectedEvent != null;
    final requestedSelectionMissing =
        requestedSelectedId.isNotEmpty && !requestedSelectionFound;

    final selected = prioritizedEvents.isEmpty
        ? null
        : _selectedEvent != null
        ? prioritizedEvents.firstWhere(
            (event) => event.eventId == _selectedEvent!.eventId,
            orElse: () => requestedSelectionFound
                ? requestedSelectedEvent!
                : prioritizedEvents.first,
          )
        : requestedSelectionFound
        ? requestedSelectedEvent
        : prioritizedEvents.first;
    if ((_selectedEvent?.eventId ?? '') != (selected?.eventId ?? '')) {
      _queueSelectedEventSync(selected);
    }
    final desktopWorkspace = MediaQuery.sizeOf(context).width >= 1240;
    if (selected != null && requestedSelectionFound && desktopWorkspace) {
      _scheduleEnsureVisible(selected.eventId);
    }

    final visibleEvents = prioritizedEvents.length;
    final totalEvents = timeline.length;
    final visitScopedEvents = _visitScopedEvents(timeline);

    Widget buildSurfaceBody({
      required bool embedScroll,
      required bool mergeWorkspaceBannerIntoHero,
    }) {
      final sections = <Widget>[
        if (hasFocusedFallback) ...[
          Container(
            key: const ValueKey('events-focused-fallback-banner'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: OnyxColorTokens.backgroundSecondary,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: OnyxColorTokens.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _focusedFallbackBannerText(
                    requestedSelectedId,
                    focusedFallbackScope,
                  ),
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _focusedFallbackBannerDetail(
                    requestedSelectedId,
                    focusedFallbackScope,
                  ),
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (requestedSelectionMissing)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: OnyxColorTokens.backgroundSecondary,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: OnyxColorTokens.divider),
            ),
            child: Text(
              'Focused reference $requestedSelectedId is outside the current filters. Clear filters to reopen the right scope.',
              style: GoogleFonts.inter(
                color: OnyxColorTokens.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        if (partnerScopeSummary != null)
          Container(
            key: const ValueKey('events-partner-scope-banner'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: OnyxColorTokens.cyanSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: OnyxColorTokens.cyanBorder),
            ),
            child: Text(
              partnerScopeSummary.bannerText,
              style: GoogleFonts.inter(
                color: OnyxColorTokens.accentSky,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        else if (readinessScopeSummary != null)
          Container(
            key: const ValueKey('events-readiness-scope-banner'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: OnyxColorTokens.greenSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: OnyxColorTokens.greenBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  readinessScopeSummary.bannerText,
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.accentSky,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  readinessScopeSummary.summaryLine,
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (readinessScopeSummary.focusSummary.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    readinessScopeSummary.focusSummary,
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.accentGreenTrue,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (readinessScopeSummary.posturalEchoSummary
                    .trim()
                    .isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Postural echo: ${readinessScopeSummary.posturalEchoSummary}',
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.accentGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (readinessScopeSummary.topIntentSummary
                    .trim()
                    .isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Top intent: ${readinessScopeSummary.topIntentSummary}',
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.accentGreenTrue,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (readinessScopeSummary.hazardSummary.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Hazard lane: ${readinessScopeSummary.hazardSummary}',
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.accentRed,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (readinessScopeSummary.reviewRefs.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Evidence refs: ${readinessScopeSummary.reviewRefs.join(', ')}',
                    style: GoogleFonts.robotoMono(
                      color: OnyxColorTokens.accentSky,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _outlineAction(
                      'COPY READINESS JSON',
                      actionKey: const ValueKey(
                        'events-readiness-casefile-json-action',
                      ),
                      onTap: () =>
                          _copyReadinessCaseFileJson(readinessScopeSummary),
                    ),
                    _outlineAction(
                      'COPY READINESS CSV',
                      actionKey: const ValueKey(
                        'events-readiness-casefile-csv-action',
                      ),
                      onTap: () =>
                          _copyReadinessCaseFileCsv(readinessScopeSummary),
                    ),
                    if (openGovernanceAction != null)
                      _outlineAction(
                        'OPEN GOVERNANCE DESK',
                        actionKey: const ValueKey(
                          'events-readiness-open-governance-action',
                        ),
                        onTap: openGovernanceAction,
                      ),
                  ],
                ),
              ],
            ),
          )
        else if (tomorrowScopeSummary != null)
          Container(
            key: const ValueKey('events-tomorrow-scope-banner'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: OnyxColorTokens.amberSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: OnyxColorTokens.amberBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tomorrowScopeSummary.bannerText,
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.accentSky,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tomorrowScopeSummary.summaryLine,
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.accentAmber,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (tomorrowScopeSummary.focusSummary.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    tomorrowScopeSummary.focusSummary,
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (tomorrowScopeSummary.leadDraftDescription
                    .trim()
                    .isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    tomorrowScopeSummary.leadDraftDescription,
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.accentAmber,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (tomorrowScopeSummary.learningSummary.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Learning: ${tomorrowScopeSummary.learningSummary}',
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (tomorrowScopeSummary.learningMemorySummary
                    .trim()
                    .isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    tomorrowScopeSummary.learningMemorySummary,
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.accentAmber,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (tomorrowScopeSummary.shadowSummary.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Shadow draft: ${tomorrowScopeSummary.shadowSummary}',
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.accentAmber,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (tomorrowScopeSummary.shadowPostureSummary
                    .trim()
                    .isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Shadow posture: ${tomorrowScopeSummary.shadowPostureSummary}',
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.accentSky,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (tomorrowScopeSummary.urgencySummary.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Urgency: ${tomorrowScopeSummary.urgencySummary}',
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.accentAmber,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (tomorrowScopeSummary.promotionPressureSummary
                    .trim()
                    .isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Promotion pressure: ${tomorrowScopeSummary.promotionPressureSummary}',
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.accentAmber,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (tomorrowScopeSummary.promotionExecutionSummary
                    .trim()
                    .isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Promotion execution: ${tomorrowScopeSummary.promotionExecutionSummary}',
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (tomorrowScopeSummary.hazardSummary.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Hazard draft: ${tomorrowScopeSummary.hazardSummary}',
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.accentRed,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (tomorrowScopeSummary.reviewRefs.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Evidence refs: ${tomorrowScopeSummary.reviewRefs.join(', ')}',
                    style: GoogleFonts.robotoMono(
                      color: OnyxColorTokens.accentSky,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (tomorrowScopeSummary.history != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: OnyxColorTokens.amberBorder),
                      color: OnyxColorTokens.amberSurface,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tomorrowScopeSummary.history!.headline,
                          style: GoogleFonts.inter(
                            color: OnyxColorTokens.accentAmber,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tomorrowScopeSummary.history!.summary,
                          style: GoogleFonts.inter(
                            color: OnyxColorTokens.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        for (final point
                            in tomorrowScopeSummary.history!.points) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${point.date} • ${point.summaryLine}'
                            '${point.shadowSummary.isEmpty ? '' : ' • shadow ${point.shadowSummary}'}'
                            '${point.shadowPostureSummary.isEmpty ? '' : ' • shadow posture ${point.shadowPostureSummary}'}'
                            '${point.urgencySummary.isEmpty ? '' : ' • urgency ${point.urgencySummary}'}'
                            '${point.promotionPressureSummary.isEmpty ? '' : ' • promotion ${point.promotionPressureSummary}'}'
                            '${point.promotionExecutionSummary.isEmpty ? '' : ' • execution ${point.promotionExecutionSummary}'}',
                            style: GoogleFonts.inter(
                              color: OnyxColorTokens.textPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _outlineAction(
                      'COPY TOMORROW JSON',
                      actionKey: const ValueKey(
                        'events-tomorrow-casefile-json-action',
                      ),
                      onTap: () =>
                          _copyTomorrowCaseFileJson(tomorrowScopeSummary),
                    ),
                    _outlineAction(
                      'COPY TOMORROW CSV',
                      actionKey: const ValueKey(
                        'events-tomorrow-casefile-csv-action',
                      ),
                      onTap: () =>
                          _copyTomorrowCaseFileCsv(tomorrowScopeSummary),
                    ),
                    if (openGovernanceAction != null)
                      _outlineAction(
                        'OPEN GOVERNANCE DESK',
                        actionKey: const ValueKey(
                          'events-tomorrow-open-governance-action',
                        ),
                        onTap: openGovernanceAction,
                      ),
                  ],
                ),
              ],
            ),
          )
        else if (syntheticScopeSummary != null)
          Container(
            key: const ValueKey('events-synthetic-scope-banner'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: OnyxColorTokens.purpleSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: OnyxColorTokens.purpleBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  syntheticScopeSummary.bannerText,
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.accentSky,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  syntheticScopeSummary.summaryLine,
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (syntheticScopeSummary.focusSummary.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    syntheticScopeSummary.focusSummary,
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.accentGreenTrue,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (syntheticScopeSummary.policySummary.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Policy: ${syntheticScopeSummary.policySummary}',
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.accentCyan,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (syntheticScopeSummary.topIntentSummary
                    .trim()
                    .isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Top intent: ${syntheticScopeSummary.topIntentSummary}',
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.accentPurple,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (syntheticScopeSummary.hazardSummary.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Hazard rehearsal: ${syntheticScopeSummary.hazardSummary}',
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.accentCyan,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (syntheticScopeSummary.reviewRefs.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Evidence refs: ${syntheticScopeSummary.reviewRefs.join(', ')}',
                    style: GoogleFonts.robotoMono(
                      color: OnyxColorTokens.accentSky,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (syntheticScopeSummary.learningSummary.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Learning: ${syntheticScopeSummary.learningSummary}',
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.accentCyan,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (syntheticScopeSummary.shadowLearningSummary.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Shadow learning: ${syntheticScopeSummary.shadowLearningSummary}',
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.accentSky,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (syntheticScopeSummary.shadowPostureSummary.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Shadow posture: ${syntheticScopeSummary.shadowPostureSummary}',
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.accentSky,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (syntheticScopeSummary
                    .shadowValidationSummary
                    .isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Shadow validation: ${syntheticScopeSummary.shadowValidationSummary}',
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.accentSky.withValues(alpha: 0.75),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (syntheticScopeSummary
                      .shadowValidationHistorySummary
                      .isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Shadow validation history: ${syntheticScopeSummary.shadowValidationHistorySummary}',
                      style: GoogleFonts.inter(
                        color: OnyxColorTokens.accentSky,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
                if (syntheticScopeSummary
                    .shadowTomorrowUrgencySummary
                    .isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Shadow tomorrow urgency: ${syntheticScopeSummary.shadowTomorrowUrgencySummary}',
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.accentAmber,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (syntheticScopeSummary
                    .previousShadowTomorrowUrgencySummary
                    .isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Previous shadow tomorrow urgency: ${syntheticScopeSummary.previousShadowTomorrowUrgencySummary}',
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.accentAmber,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (syntheticScopeSummary
                    .promotionPressureSummary
                    .isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Promotion pressure: ${syntheticScopeSummary.promotionPressureSummary}',
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.accentGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (syntheticScopeSummary
                    .promotionExecutionSummary
                    .isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Promotion execution: ${syntheticScopeSummary.promotionExecutionSummary}',
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.accentGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (syntheticScopeSummary.learningMemorySummary.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    syntheticScopeSummary.learningMemorySummary,
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.accentPurple,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (syntheticScopeSummary.shadowMemorySummary.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    syntheticScopeSummary.shadowMemorySummary,
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.accentSky.withValues(alpha: 0.75),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (syntheticScopeSummary.promotionSummary.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Promotion: ${syntheticScopeSummary.promotionSummary}',
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.accentGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (syntheticScopeSummary
                      .promotionDecisionSummary
                      .isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Decision: ${syntheticScopeSummary.promotionDecisionSummary}',
                      style: GoogleFonts.inter(
                        color:
                            syntheticScopeSummary.promotionDecisionStatus ==
                                'accepted'
                            ? OnyxColorTokens.accentGreen
                            : syntheticScopeSummary.promotionDecisionStatus ==
                                  'rejected'
                            ? OnyxColorTokens.accentRed
                            : OnyxColorTokens.accentAmber,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _outlineAction(
                        'ACCEPT PROMOTION',
                        actionKey: const ValueKey(
                          'events-synthetic-promotion-accept-action',
                        ),
                        onTap: () =>
                            _acceptSyntheticPromotion(syntheticScopeSummary),
                      ),
                      _outlineAction(
                        'REJECT PROMOTION',
                        actionKey: const ValueKey(
                          'events-synthetic-promotion-reject-action',
                        ),
                        onTap: () =>
                            _rejectSyntheticPromotion(syntheticScopeSummary),
                      ),
                    ],
                  ),
                ],
                if (syntheticScopeSummary.biasSummary.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Bias: ${syntheticScopeSummary.biasSummary}',
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.accentAmber,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (syntheticScopeSummary
                    .shadowPostureBiasSummary
                    .isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Shadow posture bias: ${syntheticScopeSummary.shadowPostureBiasSummary}',
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.accentAmber,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (syntheticScopeSummary.history != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: OnyxColorTokens.borderSubtle),
                      color: OnyxColorTokens.purpleSurface,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          syntheticScopeSummary.history!.headline,
                          style: GoogleFonts.inter(
                            color: OnyxColorTokens.accentPurple,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          syntheticScopeSummary.history!.summary,
                          style: GoogleFonts.inter(
                            color: OnyxColorTokens.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        for (final point
                            in syntheticScopeSummary.history!.points) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${point.date} • ${point.summaryLine}',
                            style: GoogleFonts.inter(
                              color: OnyxColorTokens.textPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (point.biasSummary.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              point.biasSummary,
                              style: GoogleFonts.inter(
                                color: OnyxColorTokens.accentAmber,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          if (point.shadowPostureBiasSummary.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Shadow posture bias: ${point.shadowPostureBiasSummary}',
                              style: GoogleFonts.inter(
                                color: OnyxColorTokens.accentAmber,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          if (point.shadowPostureSummary.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Shadow posture: ${point.shadowPostureSummary}',
                              style: GoogleFonts.inter(
                                color: OnyxColorTokens.accentSky,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          if (point.shadowValidationSummary.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Shadow validation: ${point.shadowValidationSummary}',
                              style: GoogleFonts.inter(
                                color: OnyxColorTokens.accentSky.withValues(alpha: 0.75),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          if (point
                              .shadowTomorrowUrgencySummary
                              .isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Shadow tomorrow urgency: ${point.shadowTomorrowUrgencySummary}',
                              style: GoogleFonts.inter(
                                color: OnyxColorTokens.accentAmber,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          if (point.promotionPressureSummary.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Promotion pressure: ${point.promotionPressureSummary}',
                              style: GoogleFonts.inter(
                                color: OnyxColorTokens.accentGreen,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          if (point.promotionExecutionSummary.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Promotion execution: ${point.promotionExecutionSummary}',
                              style: GoogleFonts.inter(
                                color: OnyxColorTokens.accentGreen,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          if (point.promotionSummary.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Promotion: ${point.promotionSummary}',
                              style: GoogleFonts.inter(
                                color: OnyxColorTokens.accentGreen,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          if (point.promotionDecisionSummary.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              point.promotionDecisionSummary,
                              style: GoogleFonts.inter(
                                color:
                                    point.promotionDecisionStatus == 'accepted'
                                    ? OnyxColorTokens.accentGreen
                                    : point.promotionDecisionStatus ==
                                          'rejected'
                                    ? OnyxColorTokens.accentRed
                                    : OnyxColorTokens.accentAmber,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _outlineAction(
                      'COPY SYNTHETIC JSON',
                      actionKey: const ValueKey(
                        'events-synthetic-casefile-json-action',
                      ),
                      onTap: () =>
                          _copySyntheticCaseFileJson(syntheticScopeSummary),
                    ),
                    _outlineAction(
                      'COPY SYNTHETIC CSV',
                      actionKey: const ValueKey(
                        'events-synthetic-casefile-csv-action',
                      ),
                      onTap: () =>
                          _copySyntheticCaseFileCsv(syntheticScopeSummary),
                    ),
                    if (openGovernanceAction != null)
                      _outlineAction(
                        'OPEN GOVERNANCE DESK',
                        actionKey: const ValueKey(
                          'events-synthetic-open-governance-action',
                        ),
                        onTap: openGovernanceAction,
                      ),
                  ],
                ),
              ],
            ),
          )
        else if (shadowScopeSummary != null)
          Container(
            key: const ValueKey('events-shadow-scope-banner'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: OnyxColorTokens.backgroundSecondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: OnyxColorTokens.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shadowScopeSummary.bannerText,
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.accentSky,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  shadowScopeSummary.summaryLine,
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.accentSky,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (shadowScopeSummary.focusSummary.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    shadowScopeSummary.focusSummary,
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.accentGreenTrue,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (shadowScopeSummary.validationSummary.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Validation: ${shadowScopeSummary.validationSummary}',
                    style: GoogleFonts.robotoMono(
                      color: OnyxColorTokens.accentSky,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (shadowScopeSummary.strengthSummary.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Strength: ${shadowScopeSummary.strengthSummary}',
                    style: GoogleFonts.robotoMono(
                      color: OnyxColorTokens.accentSky,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (shadowScopeSummary.tomorrowUrgencySummary
                    .trim()
                    .isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Tomorrow urgency: ${shadowScopeSummary.tomorrowUrgencySummary}',
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.accentAmber,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (shadowScopeSummary.previousTomorrowUrgencySummary
                    .trim()
                    .isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Previous tomorrow urgency: ${shadowScopeSummary.previousTomorrowUrgencySummary}',
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.accentAmber,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (shadowScopeSummary.history != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    shadowScopeSummary.history!.headline,
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.accentGreenTrue,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    shadowScopeSummary.history!.summary,
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (shadowScopeSummary.history!.strengthSummary
                      .trim()
                      .isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Strength drift: ${shadowScopeSummary.history!.strengthSummary}',
                      style: GoogleFonts.inter(
                        color: OnyxColorTokens.accentSky,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  for (final point in shadowScopeSummary.history!.points) ...[
                    const SizedBox(height: 3),
                    Text(
                      '${point.date} • ${point.summaryLine}',
                      style: GoogleFonts.inter(
                        color: OnyxColorTokens.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (point.validationSummary.trim().isNotEmpty)
                      Text(
                        'Validation ${point.validationSummary}',
                        style: GoogleFonts.robotoMono(
                          color: OnyxColorTokens.accentSky,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    if (point.strengthSummary.trim().isNotEmpty)
                      Text(
                        'Strength ${point.strengthSummary}',
                        style: GoogleFonts.robotoMono(
                          color: OnyxColorTokens.accentSky,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    if (point.tomorrowUrgencySummary.trim().isNotEmpty)
                      Text(
                        'Tomorrow urgency ${point.tomorrowUrgencySummary}',
                        style: GoogleFonts.inter(
                          color: OnyxColorTokens.accentAmber,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ],
                for (final site in shadowScopeSummary.sites) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${site.siteId} • ${site.moShadowSummary}',
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.accentSky,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  for (final match in site.moShadowMatches.take(3)) ...[
                    const SizedBox(height: 3),
                    Text(
                      '${match.title} • ${match.matchedIndicators.join(', ')}',
                      style: GoogleFonts.inter(
                        color: OnyxColorTokens.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (match.validationStatus.isNotEmpty)
                      Text(
                        'Strength ${shadowMoStrengthSummary(match)}',
                        style: GoogleFonts.robotoMono(
                          color: OnyxColorTokens.accentSky,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ],
                if (shadowScopeSummary.reviewRefs.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Evidence refs: ${shadowScopeSummary.reviewRefs.join(', ')}',
                    style: GoogleFonts.robotoMono(
                      color: OnyxColorTokens.accentSky,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _outlineAction(
                      'COPY SHADOW JSON',
                      actionKey: const ValueKey(
                        'events-shadow-casefile-json-action',
                      ),
                      onTap: () => _copyShadowCaseFileJson(shadowScopeSummary),
                    ),
                    _outlineAction(
                      'COPY SHADOW CSV',
                      actionKey: const ValueKey(
                        'events-shadow-casefile-csv-action',
                      ),
                      onTap: () => _copyShadowCaseFileCsv(shadowScopeSummary),
                    ),
                    if (openGovernanceAction != null)
                      _outlineAction(
                        'OPEN GOVERNANCE DESK',
                        actionKey: const ValueKey(
                          'events-shadow-open-governance-action',
                        ),
                        onTap: openGovernanceAction,
                      ),
                  ],
                ),
              ],
            ),
          )
        else if (activityScopeSummary != null)
          Container(
            key: const ValueKey('events-activity-scope-banner'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: OnyxColorTokens.accentCyan.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: OnyxColorTokens.accentCyan.withValues(alpha: 0.27)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activityScopeSummary.bannerText,
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.accentSky,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  activityScopeSummary.summaryLine,
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (activityScopeSummary.topFlaggedIdentitySummary
                    .trim()
                    .isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Flagged: ${activityScopeSummary.topFlaggedIdentitySummary}',
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.accentRed.withValues(alpha: 0.75),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (activityScopeSummary.topLongPresenceSummary
                    .trim()
                    .isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Long presence: ${activityScopeSummary.topLongPresenceSummary}',
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.accentAmber,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (activityScopeSummary.topGuardInteractionSummary
                    .trim()
                    .isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Guard note: ${activityScopeSummary.topGuardInteractionSummary}',
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.accentSky.withValues(alpha: 0.75),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (activityScopeSummary.reviewRefs.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Evidence refs: ${activityScopeSummary.reviewRefs.join(', ')}',
                    style: GoogleFonts.robotoMono(
                      color: OnyxColorTokens.accentSky,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (activityScopeSummary.history != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: OnyxColorTokens.accentCyan.withValues(alpha: 0.20)),
                      color: OnyxColorTokens.surfaceInset,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activityScopeSummary.history!.headline,
                          style: GoogleFonts.inter(
                            color: OnyxColorTokens.accentSky,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          activityScopeSummary.history!.summary,
                          style: GoogleFonts.inter(
                            color: OnyxColorTokens.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        for (final point
                            in activityScopeSummary.history!.points) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${point.date} • ${point.summaryLine}',
                            style: GoogleFonts.inter(
                              color: OnyxColorTokens.textPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _outlineAction(
                      'COPY ACTIVITY JSON',
                      actionKey: const ValueKey(
                        'events-activity-casefile-json-action',
                      ),
                      onTap: () =>
                          _copyActivityCaseFileJson(activityScopeSummary),
                    ),
                    _outlineAction(
                      'COPY ACTIVITY CSV',
                      actionKey: const ValueKey(
                        'events-activity-casefile-csv-action',
                      ),
                      onTap: () =>
                          _copyActivityCaseFileCsv(activityScopeSummary),
                    ),
                  ],
                ),
              ],
            ),
          )
        else if (scopedEventIds.isNotEmpty)
          Container(
            key: const ValueKey('events-visit-scope-banner'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: OnyxColorTokens.accentCyan.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: OnyxColorTokens.accentCyan.withValues(alpha: 0.27)),
            ),
            child: Text(
              'Events Scope narrowed to ${scopedEventIds.length} linked event${scopedEventIds.length == 1 ? '' : 's'} for this visit.',
              style: GoogleFonts.inter(
                color: OnyxColorTokens.accentSky,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        _reviewCommandWorkspace(
          prioritizedEvents: prioritizedEvents,
          selected: selected,
          visitScopedEvents: visitScopedEvents,
        ),
      ];

      if (!embedScroll) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < sections.length; index++) ...[
              if (index > 0) const SizedBox(height: 8),
              sections[index],
            ],
          ],
        );
      }

      final leadingSections = sections.take(sections.length - 1).toList();
      final workspaceSection = sections.last;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < leadingSections.length; index++) ...[
            if (index > 0) const SizedBox(height: 8),
            leadingSections[index],
          ],
          if (leadingSections.isNotEmpty) const SizedBox(height: 8),
          Expanded(child: workspaceSection),
        ],
      );
    }

    return OnyxPageScaffold(
      child: LayoutBuilder(
        builder: (context, viewport) {
          const contentPadding = EdgeInsets.all(16);
          final useScrollFallback =
              isHandsetLayout(context) ||
              viewport.maxHeight < 700 ||
              viewport.maxWidth < 980;
          final boundedDesktopSurface =
              !useScrollFallback &&
              viewport.hasBoundedHeight &&
              viewport.maxHeight.isFinite;
          final ultrawideSurface = isUltrawideLayout(
            context,
            viewportWidth: viewport.maxWidth,
          );
          final widescreenSurface = isWidescreenLayout(
            context,
            viewportWidth: viewport.maxWidth,
          );
          final surfaceMaxWidth = ultrawideSurface
              ? viewport.maxWidth
              : widescreenSurface
              ? viewport.maxWidth * 0.94
              : 1540.0;
          return OnyxViewportWorkspaceLayout(
            padding: contentPadding,
            maxWidth: surfaceMaxWidth,
            lockToViewport: boundedDesktopSurface,
            spacing: 6,
            header: _scopeRail(
              selected: selected,
              visibleEvents: visibleEvents,
              totalEvents: totalEvents,
              scopedEventCount: scopedEventIds.length,
              identityPolicyOptions: identityPolicyOptions,
              onReset: _resetFilters,
            ),
            body: buildSurfaceBody(
              embedScroll: boundedDesktopSurface,
              mergeWorkspaceBannerIntoHero: false,
            ),
          );
        },
      ),
    );
  }

  Widget _reviewCommandWorkspace({
    required List<DispatchEvent> prioritizedEvents,
    required DispatchEvent? selected,
    required List<DispatchEvent> visitScopedEvents,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktopWorkspace = constraints.maxWidth >= 1240;
        final boundedHeight =
            constraints.hasBoundedHeight && constraints.maxHeight.isFinite;
        if (_desktopWorkspaceActive != desktopWorkspace) {
          _queueDesktopWorkspaceSync(desktopWorkspace);
        }
        if (!desktopWorkspace) {
          return Column(
            children: [
              _timelinePane(events: prioritizedEvents, bounded: false),
              const SizedBox(height: 6),
              _detailPane(
                selected: selected,
                bounded: false,
                visitScopedEvents: visitScopedEvents,
              ),
            ],
          );
        }

        final opsRail = _reviewWorkspacePanel(
          key: const ValueKey('events-workspace-panel-ops'),
          title: 'PICK A SCOPE',
          subtitle:
              'Lock one lane, cut the noise, and keep the handoff path visible.',
          shellless: true,
          expandChild: true,
          child: SingleChildScrollView(
            child: _reviewOpsRail(selected: selected),
          ),
        );
        final timelineBoard = _reviewWorkspacePanel(
          key: const ValueKey('events-workspace-panel-timeline'),
          title: 'LIVE REVIEW',
          subtitle:
              'The live lane stays ranked so the top decision stays obvious.',
          shellless: true,
          expandChild: true,
          child: _timelinePane(events: prioritizedEvents, bounded: true),
        );
        final detailBoard = _reviewWorkspacePanel(
          key: const ValueKey('events-workspace-panel-detail'),
          title: 'Priority',
          subtitle:
              'Keep the selected event ready for Governance Desk, Sovereign Ledger, and export.',
          shellless: true,
          expandChild: true,
          child: _detailPane(
            selected: selected,
            bounded: true,
            visitScopedEvents: visitScopedEvents,
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (boundedHeight)
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: opsRail),
                    const SizedBox(width: 5),
                    Expanded(flex: 4, child: timelineBoard),
                    const SizedBox(width: 5),
                    Expanded(flex: 5, child: detailBoard),
                  ],
                ),
              )
            else
              SizedBox(
                height: 680,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: opsRail),
                    const SizedBox(width: 5),
                    Expanded(flex: 4, child: timelineBoard),
                    const SizedBox(width: 5),
                    Expanded(flex: 5, child: detailBoard),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _reviewWorkspacePanel({
    Key? key,
    required String title,
    required String subtitle,
    required Widget child,
    bool shellless = false,
    bool expandChild = false,
  }) {
    if (shellless) {
      return KeyedSubtree(key: key, child: child);
    }
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: OnyxColorTokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          if (expandChild) Expanded(child: child) else child,
        ],
      ),
    );
  }

  Widget _scopeRail({
    required DispatchEvent? selected,
    required int visibleEvents,
    required int totalEvents,
    required int scopedEventCount,
    required List<String> identityPolicyOptions,
    required VoidCallback onReset,
  }) {
    final items = <Widget>[
      if (_scopeRailShowsOrigin())
        _scopeRailOriginButton(),
      if (scopedEventCount > 0)
        _scopeRailInfoChip(
          label: 'Scoped',
          value: '$scopedEventCount linked',
          key: const ValueKey('events-scope-rail-scoped-count'),
        ),
      if (selected != null)
        _scopeRailEventIdChip(
          selected.eventId,
          key: const ValueKey('events-scope-rail-selected-event-id'),
        ),
      _scopeRailInfoChip(
        label: 'Visible',
        value: '$visibleEvents of $totalEvents',
        key: const ValueKey('events-scope-rail-visible-count'),
      ),
      _scopeRailDropdown<String>(
        buttonKey: const ValueKey('events-scope-rail-type-filter'),
        label: 'Type',
        activeValue: _activeFilter,
        options: _filterOptions,
        displayLabel: (value) => value,
        onSelected: (value) => setState(() => _activeFilter = value),
      ),
      _scopeRailDropdown<String>(
        buttonKey: const ValueKey('events-scope-rail-source-filter'),
        label: 'Source',
        activeValue: _activeSourceFilter,
        options: _sourceFilterOptions(),
        displayLabel: (value) => value,
        onSelected: (value) => setState(() {
          _activeSourceFilter = value;
          _activeProviderFilter = _providerFilterAll;
        }),
      ),
      if (_providerFilterOptions().length > 1 ||
          _activeProviderFilter != _providerFilterAll)
        _scopeRailDropdown<String>(
          buttonKey: const ValueKey('events-scope-rail-provider-filter'),
          label: 'Provider',
          activeValue: _activeProviderFilter,
          options: _providerFilterOptions(),
          displayLabel: (value) => value,
          onSelected: (value) => setState(
            () =>
                _activeProviderFilter = _normalizeProviderFilter(value),
          ),
        ),
      if (identityPolicyOptions.length > 1 ||
          _activeIdentityPolicyFilter != _identityPolicyFilterAll)
        _scopeRailDropdown<String>(
          buttonKey: const ValueKey('events-scope-rail-policy-filter'),
          label: 'Policy',
          activeValue: _activeIdentityPolicyFilter,
          options: identityPolicyOptions,
          displayLabel: (value) => value,
          onSelected: (value) =>
              setState(() => _activeIdentityPolicyFilter = value),
        ),
      _scopeRailResetButton(onReset),
    ];
    return Container(
      key: const ValueKey('events-scope-rail'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: OnyxColorTokens.divider),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: items,
      ),
    );
  }

  bool _scopeRailShowsOrigin() {
    final source = widget.initialRouteSource;
    return source != ZaraEventsRouteSource.navRail &&
        source != ZaraEventsRouteSource.unknown &&
        widget.onReturnToOrigin != null;
  }

  String _scopeRailOriginSourceLabel() {
    return switch (widget.initialRouteSource) {
      ZaraEventsRouteSource.ledger => 'LEDGER',
      ZaraEventsRouteSource.aiQueue => 'AI QUEUE',
      ZaraEventsRouteSource.dispatches => 'DISPATCHES',
      ZaraEventsRouteSource.reports => 'REPORTS',
      ZaraEventsRouteSource.governance => 'GOVERNANCE',
      ZaraEventsRouteSource.liveOps => 'LIVE OPS',
      ZaraEventsRouteSource.navRail => '',
      ZaraEventsRouteSource.unknown => '',
    };
  }

  Widget _scopeRailOriginButton() {
    final sourceLabel = _scopeRailOriginSourceLabel();
    final origin = widget.initialOriginLabel.trim();
    final detail = origin.isEmpty ? sourceLabel : '$sourceLabel: $origin';
    return InkWell(
      key: const ValueKey('events-scope-rail-origin-back'),
      borderRadius: BorderRadius.circular(999),
      onTap: widget.onReturnToOrigin,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: OnyxColorTokens.surfaceElevated,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: OnyxColorTokens.accentCyan),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.arrow_back_rounded,
              size: 14,
              color: OnyxColorTokens.accentCyan,
            ),
            const SizedBox(width: 6),
            Text(
              detail,
              style: GoogleFonts.inter(
                color: OnyxColorTokens.accentCyan,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scopeRailInfoChip({
    required String label,
    required String value,
    Key? key,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: OnyxColorTokens.surfaceElevated,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: OnyxColorTokens.divider),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: GoogleFonts.inter(
                color: OnyxColorTokens.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value,
              style: GoogleFonts.inter(
                color: OnyxColorTokens.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scopeRailEventIdChip(String eventId, {Key? key}) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: OnyxColorTokens.surfaceElevated,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: OnyxColorTokens.borderStrong),
      ),
      child: Text(
        eventId,
        style: GoogleFonts.robotoMono(
          color: OnyxColorTokens.textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _scopeRailDropdown<T>({
    required Key buttonKey,
    required String label,
    required T activeValue,
    required List<T> options,
    required String Function(T value) displayLabel,
    required ValueChanged<T> onSelected,
  }) {
    return PopupMenuButton<T>(
      key: buttonKey,
      tooltip: label,
      initialValue: activeValue,
      onSelected: onSelected,
      color: OnyxColorTokens.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: OnyxColorTokens.divider),
      ),
      itemBuilder: (context) => [
        for (final option in options)
          PopupMenuItem<T>(
            value: option,
            child: Text(
              displayLabel(option),
              style: GoogleFonts.inter(
                color: option == activeValue
                    ? OnyxColorTokens.accentCyan
                    : OnyxColorTokens.textPrimary,
                fontSize: 11,
                fontWeight: option == activeValue
                    ? FontWeight.w800
                    : FontWeight.w600,
              ),
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: OnyxColorTokens.surfaceElevated,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: OnyxColorTokens.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: ',
              style: GoogleFonts.inter(
                color: OnyxColorTokens.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              displayLabel(activeValue),
              style: GoogleFonts.inter(
                color: OnyxColorTokens.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.arrow_drop_down_rounded,
              size: 16,
              color: OnyxColorTokens.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _scopeRailResetButton(VoidCallback onReset) {
    return InkWell(
      key: const ValueKey('events-scope-rail-reset'),
      borderRadius: BorderRadius.circular(999),
      onTap: onReset,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: OnyxColorTokens.surfaceElevated,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: OnyxColorTokens.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.replay_rounded,
              size: 13,
              color: OnyxColorTokens.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              'RESET',
              style: GoogleFonts.inter(
                color: OnyxColorTokens.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reviewWorkspaceBannerAction({
    required Key key,
    required String label,
    required bool selected,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.18)
              : OnyxColorTokens.backgroundSecondary,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.5)
                : OnyxColorTokens.divider,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: selected ? accent : OnyxColorTokens.textSecondary,
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _reviewOpsRail({required DispatchEvent? selected}) {
    return Container(
      key: const ValueKey('events-workspace-selection-banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: OnyxColorTokens.divider),
      ),
      child: Text(
        selected == null ? 'Pick one event.' : _eventSummary(selected),
        style: GoogleFonts.inter(
          color: OnyxColorTokens.textPrimary,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _heroChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: OnyxColorTokens.surfaceElevated,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: OnyxColorTokens.divider),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: GoogleFonts.inter(
                color: OnyxColorTokens.textMuted,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value,
              style: GoogleFonts.inter(
                color: OnyxColorTokens.textPrimary,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<DispatchEvent> _timelineWithFocusedFallback({
    required List<DispatchEvent> baseEvents,
    required String focusedEventId,
    ({String clientId, String siteId})? fallbackScope,
    String? fallbackRegionId,
  }) {
    if (focusedEventId.trim().isEmpty ||
        baseEvents.any((event) => event.eventId == focusedEventId)) {
      return baseEvents;
    }
    if (fallbackScope == null && !kDebugMode) {
      return baseEvents;
    }
    var maxSequence = 0;
    for (final event in baseEvents) {
      if (event.sequence > maxSequence) {
        maxSequence = event.sequence;
      }
    }
    return [
      _SeededDispatchEvent(
        eventId: focusedEventId,
        sequence: maxSequence + 1,
        version: 2,
        occurredAt: DateTime.now().toUtc(),
        summary: _focusedFallbackSummary(fallbackScope),
        clientId: fallbackScope?.clientId ?? 'CLIENT-DEMO',
        regionId: _normalizedFocusedFallbackRegionId(fallbackRegionId),
        siteId: fallbackScope?.siteId ?? 'SITE-DEMO',
      ),
      ...baseEvents,
    ];
  }

  ({String clientId, String siteId})? _focusedFallbackScope({
    required List<DispatchEvent> scopedEvents,
    required List<DispatchEvent> allEvents,
  }) {
    final scopedSummary = _governanceScopeForEvents(scopedEvents);
    if (scopedSummary != null) {
      return scopedSummary;
    }
    return _governanceScopeForEvents(allEvents);
  }

  String? _focusedFallbackRegionId({
    required List<DispatchEvent> scopedEvents,
    required List<DispatchEvent> allEvents,
  }) {
    final scopedRegionId = _singleRegionIdForEvents(scopedEvents);
    if (scopedRegionId != null) {
      return scopedRegionId;
    }
    return _singleRegionIdForEvents(allEvents);
  }

  String? _singleRegionIdForEvents(List<DispatchEvent> events) {
    final regionIds = events
        .map(_eventRegionId)
        .where((value) => value.trim().isNotEmpty)
        .map((value) => value.trim())
        .toSet();
    if (regionIds.length != 1) {
      return null;
    }
    return regionIds.first;
  }

  String _normalizedFocusedFallbackRegionId(String? regionId) {
    final normalized = regionId?.trim() ?? '';
    if (normalized.isNotEmpty) {
      return normalized;
    }
    return 'REGION-DEMO';
  }

  String _focusedFallbackSummary(({String clientId, String siteId})? scope) {
    if (scope == null) {
      return 'Focused event reference awaiting live ingest.';
    }
    return 'Scoped event reference awaiting live ingest for ${scope.clientId}/${scope.siteId}.';
  }

  String _focusedFallbackBannerText(
    String focusedEventId,
    ({String clientId, String siteId})? scope,
  ) {
    if (scope == null) {
      return 'Requested evidence $focusedEventId was rebuilt in-page so triage can continue while live ingest catches up.';
    }
    return 'Requested evidence $focusedEventId was rebuilt for ${scope.clientId}/${scope.siteId}, keeping Events Scope live while live ingest catches up.';
  }

  String _focusedFallbackBannerDetail(
    String focusedEventId,
    ({String clientId, String siteId})? scope,
  ) {
    if (scope == null) {
      return 'The rebuilt row stays selectable so Governance Desk and Sovereign Ledger can reopen immediately.';
    }
    return 'The rebuilt row for $focusedEventId stays inside Events Scope for ${scope.clientId}/${scope.siteId}, so Governance Desk and Sovereign Ledger stay warm without waiting for replay.';
  }

  Set<String> _normalizedScopedEventIds(Iterable<String> eventIds) {
    return eventIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
  }

  List<DispatchEvent> _scopedTimelineEvents({
    required List<DispatchEvent> timeline,
    required Set<String> scopedEventIds,
  }) {
    if (scopedEventIds.isEmpty) {
      return const <DispatchEvent>[];
    }
    return timeline
        .where((event) => scopedEventIds.contains(event.eventId.trim()))
        .toList(growable: false);
  }

  List<DispatchEvent> _preserveFocusedEvent(
    List<DispatchEvent> events, {
    required List<DispatchEvent> timeline,
    required String focusedEventId,
  }) {
    final normalizedId = focusedEventId.trim();
    if (normalizedId.isEmpty ||
        events.any((event) => event.eventId == normalizedId)) {
      return events;
    }
    DispatchEvent? focusedEvent;
    for (final event in timeline) {
      if (event.eventId == normalizedId) {
        focusedEvent = event;
        break;
      }
    }
    if (focusedEvent == null) {
      return events;
    }
    final next = <DispatchEvent>[
      focusedEvent,
      ...events.where((event) => event.eventId != normalizedId),
    ];
    next.sort((left, right) => right.sequence.compareTo(left.sequence));
    return next;
  }

  List<DispatchEvent> _prioritizeEventsForScope(
    List<DispatchEvent> events, {
    _ShadowScopeSummary? shadowScopeSummary,
  }) {
    if (events.length < 2 || shadowScopeSummary == null) {
      return events;
    }
    final prioritized = events.toList(growable: true);
    final scopedSiteIds = shadowScopeSummary.sites
        .map((site) => site.siteId.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    final reviewRefs = shadowScopeSummary.reviewRefs
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    prioritized.sort((left, right) {
      final leftScore = _shadowScopePriorityScore(
        left,
        scopedSiteIds: scopedSiteIds,
        reviewRefs: reviewRefs,
      );
      final rightScore = _shadowScopePriorityScore(
        right,
        scopedSiteIds: scopedSiteIds,
        reviewRefs: reviewRefs,
      );
      final byScore = leftScore.compareTo(rightScore);
      if (byScore != 0) {
        return byScore;
      }
      return right.sequence.compareTo(left.sequence);
    });
    return prioritized;
  }

  int _shadowScopePriorityScore(
    DispatchEvent event, {
    required Set<String> scopedSiteIds,
    required Set<String> reviewRefs,
  }) {
    if (event is! IntelligenceReceived) {
      return 50;
    }
    final sourceType = event.sourceType.trim().toLowerCase();
    final provider = event.provider.trim().toLowerCase();
    final intelligenceId = event.intelligenceId.trim();
    final siteId = event.siteId.trim();
    final isReviewedEvidence = reviewRefs.contains(intelligenceId);
    final isScopedSite = scopedSiteIds.contains(siteId);
    final isLiveSensor =
        sourceType == 'cctv' ||
        sourceType == 'dvr' ||
        provider.contains('hikvision') ||
        provider.contains('frigate');
    final isExternalSeed = sourceType == 'news' || sourceType == 'community';
    if (isReviewedEvidence && isLiveSensor) {
      return 0;
    }
    if (isReviewedEvidence) {
      return 5;
    }
    if (isScopedSite && isLiveSensor) {
      return 10;
    }
    if (isScopedSite && isExternalSeed) {
      return 20;
    }
    if (isLiveSensor) {
      return 30;
    }
    if (isExternalSeed) {
      return 40;
    }
    return 45;
  }

  bool _sameStringSet(Iterable<String> left, Iterable<String> right) {
    final leftSet = _normalizedScopedEventIds(left);
    final rightSet = _normalizedScopedEventIds(right);
    if (leftSet.length != rightSet.length) {
      return false;
    }
    for (final value in leftSet) {
      if (!rightSet.contains(value)) {
        return false;
      }
    }
    return true;
  }

  List<DispatchEvent> _visitScopedEvents(List<DispatchEvent> timeline) {
    final scopedEventIds = _normalizedScopedEventIds(
      widget.initialScopedEventIds,
    );
    final visitEvents = [
      ..._scopedTimelineEvents(
        timeline: timeline,
        scopedEventIds: scopedEventIds,
      ),
    ];
    visitEvents.sort((a, b) {
      final occurredAtCompare = a.occurredAt.compareTo(b.occurredAt);
      if (occurredAtCompare != 0) {
        return occurredAtCompare;
      }
      return a.sequence.compareTo(b.sequence);
    });
    return visitEvents;
  }

  _PartnerScopeSummary? _partnerScopeSummary(List<DispatchEvent> scopedEvents) {
    if (scopedEvents.isEmpty ||
        scopedEvents.any((event) => event is! PartnerDispatchStatusDeclared)) {
      return null;
    }
    final partnerEvents = scopedEvents.cast<PartnerDispatchStatusDeclared>();
    final partnerLabels = partnerEvents
        .map((event) => event.partnerLabel.trim())
        .where((label) => label.isNotEmpty)
        .toSet();
    final siteIds = partnerEvents
        .map((event) => event.siteId.trim())
        .where((siteId) => siteId.isNotEmpty)
        .toSet();
    return _PartnerScopeSummary(
      eventCount: partnerEvents.length,
      partnerLabel: partnerLabels.length == 1 ? partnerLabels.first : null,
      siteId: siteIds.length == 1 ? siteIds.first : null,
    );
  }

  _ActivityScopeSummary? _activityScopeSummary(
    List<DispatchEvent> scopedEvents,
  ) {
    final activityEvents = scopedEvents
        .whereType<IntelligenceReceived>()
        .where((event) {
          final source = event.sourceType.trim().toLowerCase();
          return source == 'dvr' || source == 'cctv';
        })
        .toList(growable: false);
    if (activityEvents.isEmpty) {
      return null;
    }
    final snapshot = _siteActivityService.buildSnapshot(events: activityEvents);
    if (snapshot.totalSignals == 0) {
      return null;
    }
    final siteIds = activityEvents
        .map((event) => event.siteId.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final clientIds = activityEvents
        .map((event) => event.clientId.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    return _ActivityScopeSummary(
      eventCount: snapshot.totalSignals,
      reportDate: _readinessScopedReportDate(activityEvents) ?? '',
      liveReportDate: _liveMorningReportDate(
        _readinessScopedReportDate(activityEvents),
      ),
      siteId: siteIds.length == 1 ? siteIds.first : null,
      summaryLine: snapshot.summaryLine,
      topFlaggedIdentitySummary: snapshot.topFlaggedIdentitySummary,
      topLongPresenceSummary: snapshot.topLongPresenceSummary,
      topGuardInteractionSummary: snapshot.topGuardInteractionSummary,
      reviewRefs: snapshot.evidenceEventIds,
      history: clientIds.length == 1 && siteIds.length == 1
          ? _activityHistorySummary(
              clientId: clientIds.first,
              siteId: siteIds.first,
            )
          : null,
    );
  }

  _ReadinessScopeSummary? _readinessScopeSummary(
    List<DispatchEvent> scopedEvents,
  ) {
    if ((widget.initialScopedMode ?? '').trim().toLowerCase() != 'readiness') {
      return null;
    }
    final snapshot = _globalPostureService.buildSnapshot(
      events: scopedEvents,
      sceneReviewByIntelligenceId: widget.sceneReviewByIntelligenceId,
    );
    final intents = _orchestratorService.buildActionIntents(
      events: scopedEvents,
      sceneReviewByIntelligenceId: widget.sceneReviewByIntelligenceId,
      historicalShadowStrengthLabels: _shadowHistoricalStrengthLabels(
        _readinessScopedReportDate(scopedEvents),
      ),
    );
    if (snapshot.totalSites <= 0 && intents.isEmpty) {
      return null;
    }
    final leadRegion = snapshot.regions.isEmpty ? null : snapshot.regions.first;
    final leadSite = snapshot.sites.isEmpty ? null : snapshot.sites.first;
    final scopedReportDate = _readinessScopedReportDate(scopedEvents);
    final focusSummary = _readinessFocusSummary(scopedReportDate);
    final modeLabel = snapshot.criticalSiteCount > 0
        ? 'CRITICAL POSTURE'
        : snapshot.elevatedSiteCount > 0
        ? 'ELEVATED WATCH'
        : intents.isNotEmpty
        ? 'ACTIVE TENSION'
        : 'STABLE POSTURE';
    final summaryParts = <String>[
      'Critical ${snapshot.criticalSiteCount}',
      'Elevated ${snapshot.elevatedSiteCount}',
      'Intents ${intents.length}',
      if (leadRegion != null) 'region ${leadRegion.regionId}',
      if (leadSite != null) 'site ${leadSite.siteId}',
    ];
    final reviewRefs = scopedEvents
        .whereType<IntelligenceReceived>()
        .map((event) => event.intelligenceId.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final posturalEchoSummary = buildGlobalReadinessPosturalEchoSummary(
      intents: intents,
      includeLeadSites: false,
    );
    final topIntentSummary = buildGlobalReadinessTopIntentSummary(
      intents: intents,
      includeSiteId: false,
    );
    final hazardSummary = _hazardIntentSummary(intents);
    return _ReadinessScopeSummary(
      eventCount: scopedEvents.length,
      reportDate: scopedReportDate ?? '',
      liveReportDate: _liveMorningReportDate(scopedReportDate),
      leadRegionId: leadRegion?.regionId,
      leadSiteId: leadSite?.siteId,
      focusState: _readinessFocusState(scopedReportDate),
      historicalFocus: _isHistoricalReadinessFocus(scopedReportDate),
      modeLabel: modeLabel,
      summaryLine: summaryParts.join(' • '),
      focusSummary: focusSummary,
      posturalEchoSummary: posturalEchoSummary,
      topIntentSummary: topIntentSummary,
      hazardSummary: hazardSummary,
      reviewRefs: reviewRefs,
    );
  }

  _TomorrowPostureScopeSummary? _tomorrowPostureScopeSummary(
    List<DispatchEvent> scopedEvents,
  ) {
    if ((widget.initialScopedMode ?? '').trim().toLowerCase() != 'tomorrow') {
      return null;
    }
    final scopedReportDate = _readinessScopedReportDate(scopedEvents);
    final normalizedReportDate = (scopedReportDate ?? '').trim();
    if (normalizedReportDate.isEmpty) {
      return null;
    }
    final report = widget.morningSovereignReportHistory.firstWhere(
      (item) => item.date.trim() == normalizedReportDate,
      orElse: () => _emptySovereignReport(normalizedReportDate),
    );
    if (report.generatedAtUtc.millisecondsSinceEpoch == 0) {
      return null;
    }
    final drafts = _tomorrowPostureDraftsForReport(report);
    if (drafts.isEmpty) {
      return null;
    }
    final leadDraft = drafts.first;
    final reviewRefs = scopedEvents
        .whereType<IntelligenceReceived>()
        .map((event) => event.intelligenceId.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    return _TomorrowPostureScopeSummary(
      eventCount: scopedEvents.length,
      reportDate: report.date,
      liveReportDate: _liveMorningReportDate(report.date),
      focusState: _readinessFocusState(report.date),
      historicalFocus: _isHistoricalReadinessFocus(report.date),
      summaryLine: _tomorrowPostureSummary(drafts),
      focusSummary: _readinessFocusSummary(report.date),
      draftCount: drafts.length,
      leadDraftActionType: leadDraft.actionType,
      leadDraftDescription: leadDraft.description,
      learningSummary: (leadDraft.metadata['learning_label'] ?? '')
          .toString()
          .trim(),
      learningMemorySummary: _tomorrowPostureLearningMemorySummary(leadDraft),
      shadowSummary: _tomorrowPostureShadowSummary(report, leadDraft),
      shadowPostureSummary: _shadowPostureSummaryForReport(report),
      urgencySummary: _tomorrowPostureUrgencySummary(leadDraft),
      promotionPressureSummary: buildTomorrowPromotionPressureSummaryForDraft(
        draft: leadDraft,
      ),
      promotionExecutionSummary: buildTomorrowPromotionExecutionSummaryForDraft(
        draft: leadDraft,
      ),
      hazardSummary: _tomorrowPostureHazardSummary(leadDraft),
      reviewRefs: reviewRefs,
      history: _tomorrowPostureHistorySummary(report),
    );
  }

  _SyntheticScopeSummary? _syntheticScopeSummary(
    List<DispatchEvent> scopedEvents,
  ) {
    if ((widget.initialScopedMode ?? '').trim().toLowerCase() != 'synthetic') {
      return null;
    }
    final scopedReportDate = _readinessScopedReportDate(scopedEvents);
    final shadowValidationDriftSummary = _syntheticShadowValidationDriftSummary(
      scopedReportDate,
    );
    final plans = _syntheticWarRoomService.buildSimulationPlans(
      events: scopedEvents,
      sceneReviewByIntelligenceId: widget.sceneReviewByIntelligenceId,
      historicalLearningLabels: _syntheticHistoricalLearningLabels(
        scopedReportDate,
      ),
      historicalShadowMoLabels: _shadowHistoricalLabels(scopedReportDate),
      shadowValidationDriftSummary: shadowValidationDriftSummary,
    );
    if (plans.isEmpty) {
      return null;
    }
    final focusSummary = _readinessFocusSummary(scopedReportDate);
    final modeLabel = _syntheticWarRoomModeLabel(plans);
    final policySummary = plans
        .where((plan) => plan.actionType == 'POLICY RECOMMENDATION')
        .map(
          (plan) => (plan.metadata['recommendation'] ?? '').toString().trim(),
        )
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    final leadPlan = plans.first;
    final leadPolicyPlan = plans.firstWhere(
      (plan) => plan.actionType == 'POLICY RECOMMENDATION',
      orElse: () => const MonitoringWatchAutonomyActionPlan(
        id: '',
        incidentId: '',
        siteId: '',
        priority: MonitoringWatchAutonomyPriority.medium,
        actionType: '',
        description: '',
        countdownSeconds: 0,
      ),
    );
    final reviewRefs = scopedEvents
        .whereType<IntelligenceReceived>()
        .map((event) => event.intelligenceId.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final hazardSummary = _hazardSimulationSummary(plans);
    final currentReport = _reportForDate(scopedReportDate);
    final syntheticHistoryReports = [...widget.morningSovereignReportHistory]
      ..sort(
        (left, right) =>
            right.generatedAtUtc.toUtc().compareTo(left.generatedAtUtc.toUtc()),
      );
    final shadowValidationDrift = buildShadowMoValidationDriftSummary(
      currentSites: _shadowMoSitesForReport(currentReport),
      historySiteSets: syntheticHistoryReports
          .where(
            (report) => report.date.trim() != (scopedReportDate ?? '').trim(),
          )
          .take(3)
          .map(_shadowMoSitesForReport)
          .toList(growable: false),
    );
    final shadowTomorrowUrgencySummary = _syntheticShadowTomorrowUrgencySummary(
      scopedReportDate,
    );
    final previousShadowTomorrowUrgencySummary =
        widget.currentMorningSovereignReportDate == null ||
            widget.currentMorningSovereignReportDate!.trim().isEmpty ||
            widget.currentMorningSovereignReportDate!.trim() ==
                (scopedReportDate ?? '').trim()
        ? ''
        : _syntheticShadowTomorrowUrgencySummary(
            widget.currentMorningSovereignReportDate,
          );
    final promotionMoId = _syntheticWarRoomPromotionId(plans);
    final promotionShadowContext = _promotionShadowAnchorContext(
      moId: promotionMoId,
      sites: _shadowMoSitesForReport(currentReport),
      reportDate: (scopedReportDate ?? '').trim(),
    );
    final promotionAnchor = _promotionShadowAnchorSummary(
      promotionShadowContext,
    );
    return _SyntheticScopeSummary(
      eventCount: scopedEvents.length,
      reportDate: scopedReportDate ?? '',
      liveReportDate: _liveMorningReportDate(scopedReportDate),
      focusState: _readinessFocusState(scopedReportDate),
      historicalFocus: _isHistoricalReadinessFocus(scopedReportDate),
      modeLabel: modeLabel,
      summaryLine: buildSyntheticMetricDetailFromPlans(
        plans: plans,
        emptySummary: '',
        policyLabel: 'Policy',
        leadLabel: 'site',
        includeTopIntent: false,
        includeRecommendation: false,
        includeLearning: false,
        includeHazard: false,
      ),
      focusSummary: focusSummary,
      policySummary: policySummary,
      topIntentSummary: leadPlan.description,
      hazardSummary: hazardSummary,
      shadowPostureSummary: _shadowPostureSummaryForReport(currentReport),
      shadowValidationSummary: shadowValidationDrift.summary,
      shadowValidationHistorySummary: shadowValidationDrift.historySummary,
      shadowTomorrowUrgencySummary: shadowTomorrowUrgencySummary,
      previousShadowTomorrowUrgencySummary:
          previousShadowTomorrowUrgencySummary,
      shadowLearningSummary: _syntheticWarRoomShadowLearningSummary(plans),
      shadowMemorySummary: _syntheticWarRoomShadowMemorySummary(plans),
      promotionPressureSummary: _syntheticWarRoomPromotionPressureSummary(
        plans: plans,
        shadowTomorrowUrgencySummary: shadowTomorrowUrgencySummary,
        previousShadowTomorrowUrgencySummary:
            previousShadowTomorrowUrgencySummary,
        shadowPostureBiasSummary:
            _syntheticWarRoomShadowPostureBiasSummaryForPlan(
              leadPolicyPlan.id.isEmpty ? null : leadPolicyPlan,
            ),
      ),
      promotionExecutionSummary: _syntheticWarRoomPromotionExecutionSummary(
        plans,
      ),
      promotionSummary: _syntheticWarRoomPromotionSummary(
        plans,
        shadowTomorrowUrgencySummary: shadowTomorrowUrgencySummary,
        previousShadowTomorrowUrgencySummary:
            previousShadowTomorrowUrgencySummary,
        shadowPostureBiasSummary:
            _syntheticWarRoomShadowPostureBiasSummaryForPlan(
              leadPolicyPlan.id.isEmpty ? null : leadPolicyPlan,
            ),
      ),
      promotionMoId: _syntheticWarRoomPromotionId(plans),
      promotionTargetStatus: _syntheticWarRoomPromotionTargetStatus(plans),
      promotionDecisionStatus: _syntheticWarRoomPromotionDecisionStatus(plans),
      promotionDecisionSummary: _syntheticWarRoomPromotionDecisionSummary(
        plans,
        shadowTomorrowUrgencySummary: shadowTomorrowUrgencySummary,
        previousShadowTomorrowUrgencySummary:
            previousShadowTomorrowUrgencySummary,
        shadowPostureBiasSummary:
            _syntheticWarRoomShadowPostureBiasSummaryForPlan(
              leadPolicyPlan.id.isEmpty ? null : leadPolicyPlan,
            ),
      ),
      promotionAnchor: promotionAnchor,
      learningSummary: _syntheticWarRoomLearningSummary(plans),
      learningMemorySummary: _syntheticWarRoomLearningMemorySummary(
        currentLearningLabel: _syntheticWarRoomLearningLabel(plans),
        reportDate: scopedReportDate,
      ),
      biasSummary: _syntheticWarRoomBiasSummaryForPlan(
        leadPolicyPlan.id.isEmpty ? null : leadPolicyPlan,
      ),
      shadowPostureBiasSummary:
          _syntheticWarRoomShadowPostureBiasSummaryForPlan(
            leadPolicyPlan.id.isEmpty ? null : leadPolicyPlan,
          ),
      reviewRefs: reviewRefs,
      history: _syntheticHistorySummary(
        scopedEvents: scopedEvents,
        reportDate: scopedReportDate,
      ),
    );
  }

  _ShadowScopeSummary? _shadowScopeSummary(List<DispatchEvent> scopedEvents) {
    if ((widget.initialScopedMode ?? '').trim().toLowerCase() != 'shadow') {
      return null;
    }
    final scopedSiteIds = scopedEvents
        .whereType<IntelligenceReceived>()
        .map((event) => event.siteId.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    final snapshot = _globalPostureService.buildSnapshot(
      events: widget.events,
      sceneReviewByIntelligenceId: widget.sceneReviewByIntelligenceId,
    );
    final shadowSites = snapshot.sites
        .where(
          (site) =>
              site.moShadowMatchCount > 0 &&
              (scopedSiteIds.isEmpty || scopedSiteIds.contains(site.siteId)),
        )
        .toList(growable: false);
    if (shadowSites.isEmpty) {
      return null;
    }
    final scopedReportDate = _readinessScopedReportDate(scopedEvents);
    final reviewRefs = shadowSites
        .expand((site) => site.moShadowReviewRefs)
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final totalMatches = shadowSites.fold<int>(
      0,
      (current, site) => current + site.moShadowMatchCount,
    );
    final report = _reportForDate(scopedReportDate);
    final previousReports =
        widget.morningSovereignReportHistory
            .where(
              (item) => item.date.trim() != (scopedReportDate ?? '').trim(),
            )
            .toList(growable: false)
          ..sort(
            (left, right) => right.generatedAtUtc.toUtc().compareTo(
              left.generatedAtUtc.toUtc(),
            ),
          );
    final promotionMoId = _syntheticWarRoomPromotionId(
      _syntheticWarRoomService.buildSimulationPlans(
        events: _eventsForReportWindow(report),
        sceneReviewByIntelligenceId: widget.sceneReviewByIntelligenceId,
        historicalLearningLabels: _syntheticHistoricalLearningLabels(
          scopedReportDate,
        ),
        historicalShadowMoLabels: _shadowHistoricalLabels(scopedReportDate),
        shadowValidationDriftSummary: _syntheticShadowValidationDriftSummary(
          scopedReportDate,
        ),
      ),
    );
    final promotionShadowContext = _promotionShadowAnchorContext(
      moId: promotionMoId,
      sites: shadowSites,
      reportDate: (scopedReportDate ?? '').trim(),
    );
    final promotionAnchor = _promotionShadowAnchorSummary(
      promotionShadowContext,
    );
    return _ShadowScopeSummary(
      eventCount: scopedEvents.length,
      reportDate: scopedReportDate ?? '',
      liveReportDate: _liveMorningReportDate(scopedReportDate),
      focusState: _readinessFocusState(scopedReportDate),
      historicalFocus: _isHistoricalReadinessFocus(scopedReportDate),
      summaryLine:
          'Sites ${shadowSites.length} • Matches $totalMatches • ${shadowSites.first.siteId} • ${shadowSites.first.moShadowSummary}',
      focusSummary: _readinessFocusSummary(scopedReportDate),
      validationSummary: _shadowValidationSummaryForSites(shadowSites),
      strengthSummary: shadowMoStrengthSummaryForSites(shadowSites),
      tomorrowUrgencySummary: _shadowTomorrowUrgencySummaryForReport(report),
      previousTomorrowUrgencySummary: previousReports.isEmpty
          ? ''
          : _shadowTomorrowUrgencySummaryForReport(previousReports.first),
      promotionAnchor: promotionAnchor,
      reviewRefs: reviewRefs,
      sites: shadowSites,
      history: _shadowHistorySummary(
        currentSites: shadowSites,
        reportDate: scopedReportDate,
      ),
    );
  }

  _ShadowHistorySummary? _shadowHistorySummary({
    required List<MonitoringGlobalSitePosture> currentSites,
    required String? reportDate,
  }) {
    final normalizedReportDate = (reportDate ?? '').trim();
    if (normalizedReportDate.isEmpty ||
        widget.morningSovereignReportHistory.isEmpty) {
      return null;
    }
    final historyReports =
        widget.morningSovereignReportHistory
            .where((item) => item.date.trim() != normalizedReportDate)
            .toList(growable: false)
          ..sort(
            (left, right) => right.generatedAtUtc.toUtc().compareTo(
              left.generatedAtUtc.toUtc(),
            ),
          );
    final currentMatchCount = _shadowMatchCountForSites(currentSites);
    final baseline = historyReports
        .take(3)
        .map((item) => _shadowMatchCountForSites(_shadowMoSitesForReport(item)))
        .toList(growable: false);
    final baselineAverage = baseline.isEmpty
        ? null
        : baseline.reduce((left, right) => left + right) / baseline.length;
    final dayCount = baseline.isEmpty ? 1 : baseline.length + 1;
    late final String label;
    late final String reason;
    if (baselineAverage == null) {
      label = 'NEW';
      reason = 'No prior shadow-MO history is available yet.';
    } else if (currentMatchCount > baselineAverage) {
      label = 'RISING';
      reason = 'Shadow-MO match pressure is increasing against recent shifts.';
    } else if (currentMatchCount < baselineAverage) {
      label = 'EASING';
      reason = 'Shadow-MO match pressure eased against recent shifts.';
    } else {
      label = 'STABLE';
      reason =
          'Shadow-MO match pressure is holding close to the recent baseline.';
    }
    final points = <_ShadowHistoryPoint>[
      _ShadowHistoryPoint(
        date: normalizedReportDate,
        shadowSiteCount: currentSites.length,
        matchCount: currentMatchCount,
        summaryLine: _shadowScopeSummaryLineForSites(currentSites),
        validationSummary: _shadowValidationSummaryForSites(currentSites),
        strengthSummary: shadowMoStrengthSummaryForSites(currentSites),
        tomorrowUrgencySummary: _shadowTomorrowUrgencySummaryForReport(
          _reportForDate(normalizedReportDate),
        ),
      ),
      ...historyReports.take(2).map((item) {
        final itemSites = _shadowMoSitesForReport(item);
        return _ShadowHistoryPoint(
          date: item.date,
          shadowSiteCount: itemSites.length,
          matchCount: _shadowMatchCountForSites(itemSites),
          summaryLine: _shadowScopeSummaryLineForSites(itemSites),
          validationSummary: _shadowValidationSummaryForSites(itemSites),
          strengthSummary: shadowMoStrengthSummaryForSites(itemSites),
          tomorrowUrgencySummary: _shadowTomorrowUrgencySummaryForReport(item),
        );
      }),
    ];
    final strengthHistorySummary = buildShadowMoStrengthDriftSummary(
      currentSites: currentSites,
      historySiteSets: historyReports
          .take(3)
          .map(_shadowMoSitesForReport)
          .toList(growable: false),
    ).summary;
    return _ShadowHistorySummary(
      headline: '$label • ${dayCount}d',
      summary:
          'Current matches $currentMatchCount • Baseline ${baselineAverage?.toStringAsFixed(1) ?? 'n/a'} • $reason',
      strengthSummary: strengthHistorySummary,
      points: points,
    );
  }

  int _shadowMatchCountForSites(List<MonitoringGlobalSitePosture> sites) {
    return sites.fold<int>(
      0,
      (current, site) => current + site.moShadowMatchCount,
    );
  }

  String _shadowTomorrowUrgencySummaryForReport(SovereignReport report) {
    final drafts = _tomorrowPostureDraftsForReport(report);
    if (drafts.isEmpty) {
      return '';
    }
    return _tomorrowPostureUrgencySummary(drafts.first);
  }

  List<MonitoringGlobalSitePosture> _shadowMoSitesForReport(
    SovereignReport report,
  ) {
    final snapshot = _globalPostureService.buildSnapshot(
      events: _eventsForReportWindow(report),
      sceneReviewByIntelligenceId: widget.sceneReviewByIntelligenceId,
    );
    return snapshot.sites
        .where((site) => site.moShadowMatchCount > 0)
        .toList(growable: false);
  }

  String _shadowScopeSummaryLineForSites(
    List<MonitoringGlobalSitePosture> sites,
  ) {
    if (sites.isEmpty) {
      return 'No shadow-MO evidence matched this shift.';
    }
    final leadSite = sortShadowMoSites(sites).first;
    return 'Sites ${sites.length} • Matches ${_shadowMatchCountForSites(sites)} • ${leadSite.siteId} • ${leadSite.moShadowSummary}';
  }

  String _shadowValidationSummaryForSites(
    List<MonitoringGlobalSitePosture> sites,
  ) {
    if (sites.isEmpty) {
      return '';
    }
    final counts = <String, int>{};
    for (final site in sites) {
      for (final match in site.moShadowMatches) {
        final status = match.validationStatus.trim();
        if (status.isEmpty) {
          continue;
        }
        counts.update(status, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    if (counts.isEmpty) {
      return '';
    }
    const priority = <String>[
      'production',
      'validated',
      'shadowMode',
      'candidate',
    ];
    final ordered = counts.keys.toList(growable: false)
      ..sort((left, right) {
        final leftIndex = priority.indexOf(left);
        final rightIndex = priority.indexOf(right);
        if (leftIndex == -1 && rightIndex == -1) {
          return left.compareTo(right);
        }
        if (leftIndex == -1) {
          return 1;
        }
        if (rightIndex == -1) {
          return -1;
        }
        return leftIndex.compareTo(rightIndex);
      });
    final parts = ordered
        .map(
          (status) =>
              '${_humanizeShadowValidationStatus(status)} ${counts[status]}',
        )
        .toList(growable: false);
    return parts.join(' • ');
  }

  String _shadowPostureSummaryForReport(SovereignReport report) {
    return shadowMoPostureStrengthSummaryForSites(
      _shadowMoSitesForReport(report),
    );
  }

  String _humanizeShadowValidationStatus(String status) {
    switch (status.trim()) {
      case 'shadowMode':
        return 'Shadow mode';
      case 'validated':
        return 'Validated';
      case 'production':
        return 'Production';
      case 'candidate':
        return 'Candidate';
      default:
        final trimmed = status.trim();
        if (trimmed.isEmpty) {
          return '';
        }
        return trimmed[0].toUpperCase() + trimmed.substring(1);
    }
  }

  String? _readinessScopedReportDate(List<DispatchEvent> scopedEvents) {
    final intelligenceEvents = scopedEvents
        .whereType<IntelligenceReceived>()
        .toList(growable: false);
    if (intelligenceEvents.isEmpty) {
      return null;
    }
    final dates =
        intelligenceEvents
            .map((event) => _utcReportDateLabel(event.occurredAt))
            .toSet()
            .toList(growable: false)
          ..sort();
    return dates.length == 1 ? dates.first : dates.last;
  }

  SovereignReport _emptySovereignReport(String reportDate) {
    return SovereignReport(
      date: reportDate,
      generatedAtUtc: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      shiftWindowStartUtc: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      shiftWindowEndUtc: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      ledgerIntegrity: const SovereignReportLedgerIntegrity(
        totalEvents: 0,
        hashVerified: false,
        integrityScore: 0,
      ),
      aiHumanDelta: const SovereignReportAiHumanDelta(
        aiDecisions: 0,
        humanOverrides: 0,
        overrideReasons: <String, int>{},
      ),
      normDrift: const SovereignReportNormDrift(
        sitesMonitored: 0,
        driftDetected: 0,
        avgMatchScore: 0,
      ),
      complianceBlockage: const SovereignReportComplianceBlockage(
        psiraExpired: 0,
        pdpExpired: 0,
        totalBlocked: 0,
      ),
    );
  }

  SovereignReport _reportForDate(String? reportDate) {
    final normalizedReportDate = (reportDate ?? '').trim();
    return widget.morningSovereignReportHistory.firstWhere(
      (report) => report.date.trim() == normalizedReportDate,
      orElse: () => _emptySovereignReport(normalizedReportDate),
    );
  }

  String _activityReviewCommand(String reportDate) =>
      '/activityreview $reportDate';

  String _liveMorningReportDate(String? fallbackReportDate) {
    final current = (widget.currentMorningSovereignReportDate ?? '').trim();
    if (current.isNotEmpty) {
      return current;
    }
    return (fallbackReportDate ?? '').trim();
  }

  String _activityCaseFileCommand(String reportDate) =>
      '/activitycase json $reportDate';

  String _readinessReviewCommand(String reportDate) =>
      '/readinessreview $reportDate';

  String _readinessCaseFileCommand(String reportDate) =>
      '/readinesscase json $reportDate';

  String _shadowReviewCommand(String reportDate) => '/shadowreview $reportDate';

  String _shadowCaseFileCommand(String reportDate) =>
      '/shadowcase json $reportDate';

  String _tomorrowReviewCommand(String reportDate) =>
      '/tomorrowreview $reportDate';

  String _tomorrowCaseFileCommand(String reportDate) =>
      '/tomorrowcase json $reportDate';

  String _syntheticReviewCommand(String reportDate) =>
      '/syntheticreview $reportDate';

  String _syntheticCaseFileCommand(String reportDate) =>
      '/syntheticcase json $reportDate';

  List<String> _syntheticHistoricalLearningLabels(String? reportDate) {
    final normalizedReportDate = (reportDate ?? '').trim();
    final reports = [...widget.morningSovereignReportHistory]
      ..sort(
        (a, b) => b.generatedAtUtc.toUtc().compareTo(a.generatedAtUtc.toUtc()),
      );
    final currentReport = reports.firstWhere(
      (report) => report.date.trim() == normalizedReportDate,
      orElse: () => _emptySovereignReport(normalizedReportDate),
    );
    return reports
        .where(
          (report) =>
              report.date.trim() != normalizedReportDate &&
              currentReport.generatedAtUtc.millisecondsSinceEpoch > 0 &&
              report.generatedAtUtc.isBefore(currentReport.generatedAtUtc),
        )
        .take(3)
        .map(
          (report) => _syntheticWarRoomLearningLabel(
            _syntheticWarRoomService.buildSimulationPlans(
              events: _eventsForReportWindow(report),
              sceneReviewByIntelligenceId: widget.sceneReviewByIntelligenceId,
              shadowValidationDriftSummary:
                  _syntheticShadowValidationDriftSummary(report.date),
            ),
          ),
        )
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  String _syntheticShadowValidationDriftSummary(String? reportDate) {
    final currentReport = _reportForDate(reportDate);
    final normalizedReportDate = (reportDate ?? '').trim();
    final reports = [...widget.morningSovereignReportHistory]
      ..sort(
        (left, right) =>
            right.generatedAtUtc.toUtc().compareTo(left.generatedAtUtc.toUtc()),
      );
    return buildShadowMoValidationDriftSummary(
      currentSites: _shadowMoSitesForReport(currentReport),
      historySiteSets: reports
          .where((report) => report.date.trim() != normalizedReportDate)
          .take(3)
          .map(_shadowMoSitesForReport)
          .toList(growable: false),
    ).summary;
  }

  String _syntheticShadowTomorrowUrgencySummary(String? reportDate) {
    final report = _reportForDate(reportDate);
    final drafts = _tomorrowPostureDraftsForReport(report);
    if (drafts.isEmpty) {
      return '';
    }
    return _tomorrowPostureUrgencySummary(drafts.first);
  }

  Map<String, String> _promotionShadowAnchorContext({
    required String moId,
    required List<MonitoringGlobalSitePosture> sites,
    required String reportDate,
  }) {
    return buildPromotionShadowAnchorContext(
      moId: moId,
      sites: sites,
      reportDate: reportDate,
    );
  }

  _PromotionShadowAnchorSummary _promotionShadowAnchorSummary(
    Map<String, String> context,
  ) {
    return _PromotionShadowAnchorSummary(
      validationStatus: (context['validationStatus'] ?? '').trim(),
      strengthSummary: (context['strengthSummary'] ?? '').trim(),
      selectedEventId: (context['selectedEventId'] ?? '').trim(),
      reviewRefs: (context['reviewRefs'] ?? '').trim(),
      reviewCommand: (context['reviewCommand'] ?? '').trim(),
      caseFileCommand: (context['caseFileCommand'] ?? '').trim(),
    );
  }

  List<String> _shadowHistoricalLabels(String? reportDate) {
    final normalizedReportDate = (reportDate ?? '').trim();
    final reports = [...widget.morningSovereignReportHistory]
      ..sort(
        (a, b) => b.generatedAtUtc.toUtc().compareTo(a.generatedAtUtc.toUtc()),
      );
    final currentReport = reports.firstWhere(
      (report) => report.date.trim() == normalizedReportDate,
      orElse: () => _emptySovereignReport(normalizedReportDate),
    );
    return reports
        .where(
          (report) =>
              report.date.trim() != normalizedReportDate &&
              currentReport.generatedAtUtc.millisecondsSinceEpoch > 0 &&
              report.generatedAtUtc.isBefore(currentReport.generatedAtUtc),
        )
        .take(3)
        .map((report) {
          final snapshot = _globalPostureService.buildSnapshot(
            events: _eventsForReportWindow(report),
            sceneReviewByIntelligenceId: widget.sceneReviewByIntelligenceId,
          );
          final shadowSites = snapshot.sites
              .where((site) => site.moShadowMatchCount > 0)
              .toList(growable: false);
          if (shadowSites.isEmpty) {
            return '';
          }
          return _orchestratorService.shadowDraftLabelForSite(
            shadowSites.first,
          );
        })
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  String _shadowStrengthHandoffForReport(SovereignReport report) {
    final baseline =
        widget.morningSovereignReportHistory
            .where(
              (item) =>
                  item.date.trim() != report.date.trim() &&
                  item.generatedAtUtc.isBefore(report.generatedAtUtc),
            )
            .toList(growable: false)
          ..sort(
            (left, right) => right.generatedAtUtc.toUtc().compareTo(
              left.generatedAtUtc.toUtc(),
            ),
          );
    return buildShadowMoStrengthDriftSummary(
      currentSites: _shadowMoSitesForReport(report),
      historySiteSets: baseline
          .take(3)
          .map(_shadowMoSitesForReport)
          .toList(growable: false),
    ).handoffSummary;
  }

  List<String> _shadowHistoricalStrengthLabels(String? reportDate) {
    final normalizedReportDate = (reportDate ?? '').trim();
    final reports = [...widget.morningSovereignReportHistory]
      ..sort(
        (a, b) => b.generatedAtUtc.toUtc().compareTo(a.generatedAtUtc.toUtc()),
      );
    final currentReport = reports.firstWhere(
      (report) => report.date.trim() == normalizedReportDate,
      orElse: () => _emptySovereignReport(normalizedReportDate),
    );
    return reports
        .where(
          (report) =>
              report.date.trim() != normalizedReportDate &&
              currentReport.generatedAtUtc.millisecondsSinceEpoch > 0 &&
              report.generatedAtUtc.isBefore(currentReport.generatedAtUtc),
        )
        .take(3)
        .map(_shadowStrengthHandoffForReport)
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  String _syntheticWarRoomLearningMemorySummary({
    required String currentLearningLabel,
    required String? reportDate,
  }) {
    return buildSyntheticLearningMemorySummaryFromHistoryLabels(
      currentLearningLabel: currentLearningLabel,
      historicalLearningLabels: _syntheticHistoricalLearningLabels(reportDate),
    );
  }

  bool _isHistoricalReadinessFocus(String? reportDate) {
    return buildOversightFocusState(
          reportDate: reportDate ?? '',
          currentReportDate: widget.currentMorningSovereignReportDate ?? '',
        ) ==
        'historical_command_target';
  }

  String _readinessFocusState(String? reportDate) {
    return buildOversightFocusState(
      reportDate: reportDate ?? '',
      currentReportDate: widget.currentMorningSovereignReportDate ?? '',
    );
  }

  String _readinessFocusSummary(String? reportDate) {
    return buildOversightFocusSummary(
      reportDate: reportDate ?? '',
      currentReportDate: widget.currentMorningSovereignReportDate ?? '',
    );
  }

  String _syntheticWarRoomModeLabel(
    List<MonitoringWatchAutonomyActionPlan> plans,
  ) => buildSyntheticModeLabelFromPlans(plans: plans);

  String _syntheticWarRoomSummary(
    List<MonitoringWatchAutonomyActionPlan> plans,
  ) => buildSyntheticSummaryFromPlans(plans: plans);

  String _syntheticWarRoomLearningSummary(
    List<MonitoringWatchAutonomyActionPlan> plans,
  ) => buildSyntheticLearningSummaryFromPlans(plans: plans);

  String _syntheticWarRoomLearningLabel(
    List<MonitoringWatchAutonomyActionPlan> plans,
  ) => buildSyntheticLearningLabelFromPlans(plans: plans);

  String _syntheticWarRoomShadowLearningSummary(
    List<MonitoringWatchAutonomyActionPlan> plans,
  ) => buildSyntheticShadowLearningSummaryFromPlans(plans: plans);

  String _syntheticWarRoomShadowMemorySummary(
    List<MonitoringWatchAutonomyActionPlan> plans,
  ) => buildSyntheticShadowMemorySummaryFromPlans(plans: plans);

  String _syntheticWarRoomPromotionSummary(
    List<MonitoringWatchAutonomyActionPlan> plans, {
    String shadowTomorrowUrgencySummary = '',
    String previousShadowTomorrowUrgencySummary = '',
    String shadowPostureBiasSummary = '',
  }) {
    return buildSyntheticPromotionSummaryFromPlans(
      plans: plans,
      shadowTomorrowUrgencySummary: shadowTomorrowUrgencySummary,
      previousShadowTomorrowUrgencySummary:
          previousShadowTomorrowUrgencySummary,
      shadowPostureBiasSummary: shadowPostureBiasSummary,
    );
  }

  String _syntheticWarRoomPromotionPressureSummary({
    List<MonitoringWatchAutonomyActionPlan> plans =
        const <MonitoringWatchAutonomyActionPlan>[],
    String shadowTomorrowUrgencySummary = '',
    String previousShadowTomorrowUrgencySummary = '',
    String shadowPostureBiasSummary = '',
  }) {
    return buildSyntheticPromotionPressureSummaryFromPlans(
      plans: plans,
      shadowTomorrowUrgencySummary: shadowTomorrowUrgencySummary,
      previousShadowTomorrowUrgencySummary:
          previousShadowTomorrowUrgencySummary,
      shadowPostureBiasSummary: shadowPostureBiasSummary,
    );
  }

  String _syntheticWarRoomPromotionExecutionSummary(
    List<MonitoringWatchAutonomyActionPlan> plans,
  ) => buildSyntheticPromotionExecutionBiasSummaryFromPlans(plans: plans);

  String _syntheticWarRoomPromotionId(
    List<MonitoringWatchAutonomyActionPlan> plans,
  ) => buildSyntheticPromotionIdFromPlans(plans: plans);

  String _syntheticWarRoomPromotionTargetStatus(
    List<MonitoringWatchAutonomyActionPlan> plans,
  ) => buildSyntheticPromotionTargetStatusFromPlans(plans: plans);

  String _syntheticWarRoomPromotionDecisionStatus(
    List<MonitoringWatchAutonomyActionPlan> plans,
  ) => buildSyntheticPromotionDecisionStatusFromPlans(
    plans: plans,
    decisionStatusLookup: _moPromotionDecisionStore.decisionStatusFor,
  );

  String _syntheticWarRoomPromotionDecisionSummary(
    List<MonitoringWatchAutonomyActionPlan> plans, {
    String shadowTomorrowUrgencySummary = '',
    String previousShadowTomorrowUrgencySummary = '',
    String shadowPostureBiasSummary = '',
  }) {
    return buildSyntheticPromotionDecisionSummaryFromPlans(
      plans: plans,
      decisionSummaryLookup: (moId, targetStatus) => _moPromotionDecisionStore
          .decisionSummaryFor(moId: moId, targetValidationStatus: targetStatus),
      shadowTomorrowUrgencySummary: shadowTomorrowUrgencySummary,
      previousShadowTomorrowUrgencySummary:
          previousShadowTomorrowUrgencySummary,
      shadowPostureBiasSummary: shadowPostureBiasSummary,
    );
  }

  List<MonitoringWatchAutonomyActionPlan> _tomorrowPostureDraftsForReport(
    SovereignReport report,
  ) {
    return _orchestratorService
        .buildActionIntents(
          events: _eventsForReportWindow(report),
          sceneReviewByIntelligenceId: widget.sceneReviewByIntelligenceId,
          historicalSyntheticLearningLabels: _syntheticHistoricalLearningLabels(
            report.date,
          ),
          historicalShadowMoLabels: _shadowHistoricalLabels(report.date),
          historicalShadowStrengthLabels: _shadowHistoricalStrengthLabels(
            report.date,
          ),
        )
        .where((plan) => (plan.metadata['scope'] ?? '').trim() == 'NEXT_SHIFT')
        .toList(growable: false);
  }

  String _tomorrowPostureSummary(
    List<MonitoringWatchAutonomyActionPlan> drafts,
  ) => buildTomorrowPostureSummaryForDraft(
    draft: drafts.isEmpty ? null : drafts.first,
  );

  String _tomorrowPostureLearningMemorySummary(
    MonitoringWatchAutonomyActionPlan draft,
  ) => buildTomorrowLearningMemorySummaryForDraft(draft: draft);

  String _tomorrowPostureShadowStrengthHandoffSummary(SovereignReport report) {
    final historyReports =
        widget.morningSovereignReportHistory
            .where((item) => item.date.trim() != report.date.trim())
            .toList(growable: false)
          ..sort(
            (left, right) => right.generatedAtUtc.toUtc().compareTo(
              left.generatedAtUtc.toUtc(),
            ),
          );
    return buildShadowMoStrengthDriftSummary(
      currentSites: _shadowMoSitesForReport(report),
      historySiteSets: historyReports
          .take(3)
          .map(_shadowMoSitesForReport)
          .toList(growable: false),
    ).handoffSummary;
  }

  String _tomorrowPostureShadowSummary(
    SovereignReport report,
    MonitoringWatchAutonomyActionPlan draft,
  ) => buildTomorrowShadowSummaryForDraft(
    draft: draft,
    strengthHandoffSummary: _tomorrowPostureShadowStrengthHandoffSummary(
      report,
    ),
  );

  String _tomorrowPostureHazardSummary(
    MonitoringWatchAutonomyActionPlan draft,
  ) => buildTomorrowHazardSummaryForDraft(draft: draft);

  String _tomorrowPostureUrgencySummary(
    MonitoringWatchAutonomyActionPlan draft,
  ) => buildTomorrowUrgencySummaryForDraft(draft: draft);

  String _syntheticWarRoomBiasSummaryForPlan(
    MonitoringWatchAutonomyActionPlan? plan,
  ) => buildSyntheticBiasSummaryForPlan(plan: plan);

  String _syntheticWarRoomShadowPostureBiasSummaryForPlan(
    MonitoringWatchAutonomyActionPlan? plan,
  ) => buildSyntheticShadowPostureBiasSummaryForPlan(plan: plan);

  String _hazardIntentSummary(List<MonitoringWatchAutonomyActionPlan> intents) {
    return buildHazardIntentSummaryFromPlans(plans: intents);
  }

  String _hazardSimulationSummary(
    List<MonitoringWatchAutonomyActionPlan> plans,
  ) {
    return buildHazardSimulationSummaryFromPlans(plans: plans);
  }

  String _utcReportDateLabel(DateTime dateTime) {
    final utc = dateTime.toUtc();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${utc.year.toString().padLeft(4, '0')}-${two(utc.month)}-${two(utc.day)}';
  }

  _ActivityHistorySummary? _activityHistorySummary({
    required String clientId,
    required String siteId,
  }) {
    if (clientId.trim().isEmpty ||
        siteId.trim().isEmpty ||
        widget.morningSovereignReportHistory.isEmpty) {
      return null;
    }
    final reports = [...widget.morningSovereignReportHistory]
      ..sort(
        (a, b) => b.generatedAtUtc.toUtc().compareTo(a.generatedAtUtc.toUtc()),
      );
    if (reports.isEmpty) {
      return null;
    }
    final points = reports
        .map(
          (report) => _ActivityHistoryPoint(
            date: report.date,
            totalSignals: report.siteActivity.totalSignals,
            unknownSignals: report.siteActivity.unknownSignals,
            flaggedSignals: report.siteActivity.flaggedIdentitySignals,
            guardInteractions: report.siteActivity.guardInteractionSignals,
            summaryLine: report.siteActivity.summaryLine,
          ),
        )
        .toList(growable: false);
    if (points.isEmpty) {
      return null;
    }
    final current = points.first;
    final baseline = points.skip(1).take(3).toList(growable: false);
    final baselinePressure = baseline.isEmpty
        ? null
        : baseline
                  .map((point) => point.pressureScore)
                  .reduce((left, right) => left + right) /
              baseline.length;
    final currentPressure = current.pressureScore.toDouble();
    late final String label;
    late final String reason;
    if (baselinePressure == null) {
      label = 'NEW';
      reason = 'No prior site-activity history is available yet.';
    } else if (currentPressure >= baselinePressure + 1) {
      label = 'ACTIVITY RISING';
      reason =
          'Unknown, flagged, or guard-linked activity is above the recent baseline.';
    } else if (currentPressure <= baselinePressure - 1) {
      label = 'ACTIVITY EASING';
      reason =
          'Unknown, flagged, or guard-linked activity eased against recent shifts.';
    } else {
      label = 'STABLE';
      reason = 'Activity pressure is holding close to the recent baseline.';
    }
    final baselineLabel = baselinePressure == null
        ? 'n/a'
        : baselinePressure.toStringAsFixed(1);
    return _ActivityHistorySummary(
      headline: '$label • ${points.length}d',
      summary:
          'Current pressure ${current.pressureScore} • Baseline $baselineLabel • $reason',
      points: points.take(3).toList(growable: false),
    );
  }

  _SyntheticHistorySummary? _syntheticHistorySummary({
    required List<DispatchEvent> scopedEvents,
    required String? reportDate,
  }) {
    if (widget.morningSovereignReportHistory.isEmpty) {
      return null;
    }
    final normalizedReportDate = (reportDate ?? '').trim();
    final reports = [...widget.morningSovereignReportHistory]
      ..sort(
        (a, b) => b.generatedAtUtc.toUtc().compareTo(a.generatedAtUtc.toUtc()),
      );
    if (reports.isEmpty) {
      return null;
    }
    final points = <_SyntheticHistoryPoint>[];
    if (normalizedReportDate.isNotEmpty) {
      final currentReport = widget.morningSovereignReportHistory.firstWhere(
        (report) => report.date.trim() == normalizedReportDate,
        orElse: () => _emptySovereignReport(normalizedReportDate),
      );
      final currentPlans = _syntheticWarRoomService.buildSimulationPlans(
        events: scopedEvents,
        sceneReviewByIntelligenceId: widget.sceneReviewByIntelligenceId,
        historicalLearningLabels: _syntheticHistoricalLearningLabels(
          normalizedReportDate,
        ),
        historicalShadowMoLabels: _shadowHistoricalLabels(normalizedReportDate),
        shadowValidationDriftSummary: _syntheticShadowValidationDriftSummary(
          normalizedReportDate,
        ),
      );
      final currentPolicyPlan = currentPlans.firstWhere(
        (plan) => plan.actionType == 'POLICY RECOMMENDATION',
        orElse: () => const MonitoringWatchAutonomyActionPlan(
          id: '',
          incidentId: '',
          siteId: '',
          priority: MonitoringWatchAutonomyPriority.medium,
          actionType: '',
          description: '',
          countdownSeconds: 0,
        ),
      );
      points.add(
        _SyntheticHistoryPoint(
          date: normalizedReportDate,
          planCount: currentPlans.length,
          policyCount: currentPlans
              .where((plan) => plan.actionType == 'POLICY RECOMMENDATION')
              .length,
          modeLabel: _syntheticWarRoomModeLabel(currentPlans),
          summaryLine: _syntheticWarRoomSummary(currentPlans).isEmpty
              ? 'No synthetic rehearsal triggered.'
              : _syntheticWarRoomSummary(currentPlans),
          biasSummary: _syntheticWarRoomBiasSummaryForPlan(
            currentPolicyPlan.id.isEmpty ? null : currentPolicyPlan,
          ),
          shadowPostureBiasSummary:
              _syntheticWarRoomShadowPostureBiasSummaryForPlan(
                currentPolicyPlan.id.isEmpty ? null : currentPolicyPlan,
              ),
          shadowPostureSummary: _shadowPostureSummaryForReport(currentReport),
          shadowValidationSummary: _shadowValidationSummaryForSites(
            _shadowMoSitesForReport(currentReport),
          ),
          shadowTomorrowUrgencySummary: _syntheticShadowTomorrowUrgencySummary(
            normalizedReportDate,
          ),
          promotionPressureSummary: _syntheticWarRoomPromotionPressureSummary(
            plans: currentPlans,
            shadowTomorrowUrgencySummary:
                _syntheticShadowTomorrowUrgencySummary(normalizedReportDate),
            shadowPostureBiasSummary:
                _syntheticWarRoomShadowPostureBiasSummaryForPlan(
                  currentPolicyPlan.id.isEmpty ? null : currentPolicyPlan,
                ),
          ),
          promotionExecutionSummary: _syntheticWarRoomPromotionExecutionSummary(
            currentPlans,
          ),
          promotionSummary: _syntheticWarRoomPromotionSummary(
            currentPlans,
            shadowTomorrowUrgencySummary:
                _syntheticShadowTomorrowUrgencySummary(normalizedReportDate),
            shadowPostureBiasSummary:
                _syntheticWarRoomShadowPostureBiasSummaryForPlan(
                  currentPolicyPlan.id.isEmpty ? null : currentPolicyPlan,
                ),
          ),
          promotionDecisionStatus: _syntheticWarRoomPromotionDecisionStatus(
            currentPlans,
          ),
          promotionDecisionSummary: _syntheticWarRoomPromotionDecisionSummary(
            currentPlans,
            shadowTomorrowUrgencySummary:
                _syntheticShadowTomorrowUrgencySummary(normalizedReportDate),
            shadowPostureBiasSummary:
                _syntheticWarRoomShadowPostureBiasSummaryForPlan(
                  currentPolicyPlan.id.isEmpty ? null : currentPolicyPlan,
                ),
          ),
        ),
      );
    }
    for (final report in reports) {
      if (normalizedReportDate.isNotEmpty &&
          report.date.trim() == normalizedReportDate) {
        continue;
      }
      final reportEvents = _eventsForReportWindow(report);
      final plans = _syntheticWarRoomService.buildSimulationPlans(
        events: reportEvents,
        sceneReviewByIntelligenceId: widget.sceneReviewByIntelligenceId,
        historicalLearningLabels: _syntheticHistoricalLearningLabels(
          report.date,
        ),
        historicalShadowMoLabels: _shadowHistoricalLabels(report.date),
        shadowValidationDriftSummary: _syntheticShadowValidationDriftSummary(
          report.date,
        ),
      );
      final policyPlan = plans.firstWhere(
        (plan) => plan.actionType == 'POLICY RECOMMENDATION',
        orElse: () => const MonitoringWatchAutonomyActionPlan(
          id: '',
          incidentId: '',
          siteId: '',
          priority: MonitoringWatchAutonomyPriority.medium,
          actionType: '',
          description: '',
          countdownSeconds: 0,
        ),
      );
      points.add(
        _SyntheticHistoryPoint(
          date: report.date,
          planCount: plans.length,
          policyCount: plans
              .where((plan) => plan.actionType == 'POLICY RECOMMENDATION')
              .length,
          modeLabel: _syntheticWarRoomModeLabel(plans),
          summaryLine: _syntheticWarRoomSummary(plans).isEmpty
              ? 'No synthetic rehearsal triggered.'
              : _syntheticWarRoomSummary(plans),
          biasSummary: _syntheticWarRoomBiasSummaryForPlan(
            policyPlan.id.isEmpty ? null : policyPlan,
          ),
          shadowPostureBiasSummary:
              _syntheticWarRoomShadowPostureBiasSummaryForPlan(
                policyPlan.id.isEmpty ? null : policyPlan,
              ),
          shadowPostureSummary: _shadowPostureSummaryForReport(report),
          shadowValidationSummary: _shadowValidationSummaryForSites(
            _shadowMoSitesForReport(report),
          ),
          shadowTomorrowUrgencySummary: _syntheticShadowTomorrowUrgencySummary(
            report.date,
          ),
          promotionPressureSummary: _syntheticWarRoomPromotionPressureSummary(
            plans: plans,
            shadowTomorrowUrgencySummary:
                _syntheticShadowTomorrowUrgencySummary(report.date),
            shadowPostureBiasSummary:
                _syntheticWarRoomShadowPostureBiasSummaryForPlan(
                  policyPlan.id.isEmpty ? null : policyPlan,
                ),
          ),
          promotionExecutionSummary: _syntheticWarRoomPromotionExecutionSummary(
            plans,
          ),
          promotionSummary: _syntheticWarRoomPromotionSummary(
            plans,
            shadowTomorrowUrgencySummary:
                _syntheticShadowTomorrowUrgencySummary(report.date),
            shadowPostureBiasSummary:
                _syntheticWarRoomShadowPostureBiasSummaryForPlan(
                  policyPlan.id.isEmpty ? null : policyPlan,
                ),
          ),
          promotionDecisionStatus: _syntheticWarRoomPromotionDecisionStatus(
            plans,
          ),
          promotionDecisionSummary: _syntheticWarRoomPromotionDecisionSummary(
            plans,
            shadowTomorrowUrgencySummary:
                _syntheticShadowTomorrowUrgencySummary(report.date),
            shadowPostureBiasSummary:
                _syntheticWarRoomShadowPostureBiasSummaryForPlan(
                  policyPlan.id.isEmpty ? null : policyPlan,
                ),
          ),
        ),
      );
    }
    if (points.isEmpty) {
      return null;
    }
    final current = points.first;
    final baseline = points.skip(1).take(3).toList(growable: false);
    final baselinePressure = baseline.isEmpty
        ? null
        : baseline
                  .map((point) => point.pressureScore)
                  .reduce((left, right) => left + right) /
              baseline.length;
    final currentPressure = current.pressureScore.toDouble();
    late final String label;
    late final String reason;
    if (baselinePressure == null) {
      label = 'NEW';
      reason = 'No prior synthetic rehearsal history is available yet.';
    } else if (currentPressure >= baselinePressure + 1) {
      label = 'RISING';
      reason =
          'Synthetic rehearsal is recommending stronger action than recent shifts.';
    } else if (currentPressure <= baselinePressure - 1) {
      label = 'EASING';
      reason = 'Synthetic rehearsal pressure eased against recent shifts.';
    } else {
      label = 'STABLE';
      reason =
          'Synthetic rehearsal pressure is holding close to the recent baseline.';
    }
    final baselineLabel = baselinePressure == null
        ? 'n/a'
        : baselinePressure.toStringAsFixed(1);
    return _SyntheticHistorySummary(
      headline: '$label • ${points.length}d',
      summary:
          'Current pressure ${current.pressureScore} • Baseline $baselineLabel • $reason',
      points: points.take(3).toList(growable: false),
    );
  }

  _TomorrowPostureHistorySummary? _tomorrowPostureHistorySummary(
    SovereignReport currentReport,
  ) {
    final historyReports =
        widget.morningSovereignReportHistory
            .where((item) => item.date.trim() != currentReport.date.trim())
            .toList(growable: false)
          ..sort(
            (left, right) =>
                right.generatedAtUtc.compareTo(left.generatedAtUtc),
          );
    if (historyReports.isEmpty) {
      return null;
    }
    final currentDrafts = _tomorrowPostureDraftsForReport(currentReport);
    final baseline = historyReports
        .take(3)
        .map((item) => _tomorrowPostureDraftsForReport(item).length)
        .toList(growable: false);
    final baselineAverage = baseline.isEmpty
        ? 0.0
        : baseline.reduce((left, right) => left + right) / baseline.length;
    final currentCount = currentDrafts.length;
    final headline = currentCount > baselineAverage
        ? 'RISING • ${historyReports.length + 1}d'
        : currentCount < baselineAverage
        ? 'EASING • ${historyReports.length + 1}d'
        : 'STABLE • ${historyReports.length + 1}d';
    final summary =
        'Current drafts $currentCount • Baseline ${baselineAverage.toStringAsFixed(1)}';
    final points = <_TomorrowPostureHistoryPoint>[
      _TomorrowPostureHistoryPoint(
        date: currentReport.date,
        draftCount: currentCount,
        summaryLine: _tomorrowPostureSummary(currentDrafts).isEmpty
            ? 'No tomorrow-posture drafts triggered.'
            : _tomorrowPostureSummary(currentDrafts),
        shadowSummary: currentDrafts.isEmpty
            ? ''
            : _tomorrowPostureShadowSummary(currentReport, currentDrafts.first),
        shadowPostureSummary: _shadowPostureSummaryForReport(currentReport),
        urgencySummary: currentDrafts.isEmpty
            ? ''
            : _tomorrowPostureUrgencySummary(currentDrafts.first),
        promotionPressureSummary: currentDrafts.isEmpty
            ? ''
            : buildTomorrowPromotionPressureSummaryForDraft(
                draft: currentDrafts.first,
              ),
        promotionExecutionSummary: currentDrafts.isEmpty
            ? ''
            : buildTomorrowPromotionExecutionSummaryForDraft(
                draft: currentDrafts.first,
              ),
      ),
      ...historyReports.take(2).map((item) {
        final drafts = _tomorrowPostureDraftsForReport(item);
        return _TomorrowPostureHistoryPoint(
          date: item.date,
          draftCount: drafts.length,
          summaryLine: _tomorrowPostureSummary(drafts).isEmpty
              ? 'No tomorrow-posture drafts triggered.'
              : _tomorrowPostureSummary(drafts),
          shadowSummary: drafts.isEmpty
              ? ''
              : _tomorrowPostureShadowSummary(item, drafts.first),
          shadowPostureSummary: _shadowPostureSummaryForReport(item),
          urgencySummary: drafts.isEmpty
              ? ''
              : _tomorrowPostureUrgencySummary(drafts.first),
          promotionPressureSummary: drafts.isEmpty
              ? ''
              : buildTomorrowPromotionPressureSummaryForDraft(
                  draft: drafts.first,
                ),
          promotionExecutionSummary: drafts.isEmpty
              ? ''
              : buildTomorrowPromotionExecutionSummaryForDraft(
                  draft: drafts.first,
                ),
        );
      }),
    ];
    return _TomorrowPostureHistorySummary(
      headline: headline,
      summary: summary,
      points: points,
    );
  }

  List<DispatchEvent> _eventsForReportWindow(SovereignReport report) {
    final startUtc = report.shiftWindowStartUtc.toUtc();
    final endUtc = report.shiftWindowEndUtc.toUtc();
    return widget.events
        .where((event) {
          final occurredAt = event.occurredAt.toUtc();
          final atOrAfterStart = !occurredAt.isBefore(startUtc);
          final beforeEnd = occurredAt.isBefore(endUtc);
          return atOrAfterStart && beforeEnd;
        })
        .toList(growable: false);
  }

  _PartnerScopeDetail? _partnerScopeDetail(List<DispatchEvent> scopedEvents) {
    if (scopedEvents.isEmpty ||
        scopedEvents.any((event) => event is! PartnerDispatchStatusDeclared)) {
      return null;
    }
    final partnerEvents =
        [...scopedEvents.cast<PartnerDispatchStatusDeclared>()]..sort((a, b) {
          final occurredAtCompare = a.occurredAt.compareTo(b.occurredAt);
          if (occurredAtCompare != 0) {
            return occurredAtCompare;
          }
          return a.sequence.compareTo(b.sequence);
        });
    final firstEvent = partnerEvents.first;
    final firstOccurrenceByStatus = <PartnerDispatchStatus, DateTime>{};
    for (final event in partnerEvents) {
      firstOccurrenceByStatus.putIfAbsent(event.status, () => event.occurredAt);
    }
    return _PartnerScopeDetail(
      events: partnerEvents,
      dispatchId: firstEvent.dispatchId,
      clientId: firstEvent.clientId,
      partnerLabel: firstEvent.partnerLabel,
      siteId: firstEvent.siteId,
      latestStatus: partnerEvents.last.status,
      latestOccurredAt: partnerEvents.last.occurredAt,
      firstOccurrenceByStatus: firstOccurrenceByStatus,
    );
  }

  _VisitTimelineStatus _visitTimelineStatus(List<DispatchEvent> visitEvents) {
    if (visitEvents.isEmpty) {
      return _VisitTimelineStatus.active;
    }
    final hasExit = visitEvents.any(
      (event) =>
          _visitTimelineStageForEvent(
            event,
            eventIndex: visitEvents.indexOf(event),
          ) ==
          _VisitTimelineStage.exit,
    );
    if (hasExit) {
      return _VisitTimelineStatus.completed;
    }
    final lastSeenAtUtc = visitEvents.last.occurredAt.toUtc();
    if (DateTime.now().toUtc().difference(lastSeenAtUtc) >
        const Duration(minutes: 45)) {
      return _VisitTimelineStatus.incomplete;
    }
    return _VisitTimelineStatus.active;
  }

  _VisitTimelineStage _visitTimelineStageForEvent(
    DispatchEvent event, {
    required int eventIndex,
  }) {
    final text = <String>[
      if (event is IntelligenceReceived) event.zone ?? '',
      _eventSummary(event),
      if (event is IntelligenceReceived) event.summary,
    ].join(' ').toLowerCase();
    if (_containsAny(text, const [
      'entry',
      'ingress',
      'entrance',
      'gate in',
      'arrival lane',
      'arrivals',
      'boom in',
    ])) {
      return _VisitTimelineStage.entry;
    }
    if (_containsAny(text, const [
      'exit',
      'egress',
      'departure',
      'gate out',
      'exit lane',
      'boom out',
      'outbound',
    ])) {
      return _VisitTimelineStage.exit;
    }
    if (_containsAny(text, const [
      'wash',
      'bay',
      'service',
      'vacuum',
      'processing',
      'queue',
      'loading',
      'yard',
    ])) {
      return _VisitTimelineStage.service;
    }
    if (eventIndex == 0) {
      return _VisitTimelineStage.entry;
    }
    return _VisitTimelineStage.observed;
  }

  String _visitTimelineStageLabel(_VisitTimelineStage stage) {
    return switch (stage) {
      _VisitTimelineStage.entry => 'ENTRY',
      _VisitTimelineStage.service => 'SERVICE',
      _VisitTimelineStage.exit => 'EXIT',
      _VisitTimelineStage.observed => 'OBSERVED',
    };
  }

  String _visitTimelineStatusLabel(_VisitTimelineStatus status) {
    return switch (status) {
      _VisitTimelineStatus.completed => 'COMPLETED',
      _VisitTimelineStatus.active => 'ACTIVE',
      _VisitTimelineStatus.incomplete => 'INCOMPLETE',
    };
  }

  Color _visitTimelineStatusColor(_VisitTimelineStatus status) {
    return switch (status) {
      _VisitTimelineStatus.completed => OnyxColorTokens.accentGreen,
      _VisitTimelineStatus.active => OnyxColorTokens.accentCyan,
      _VisitTimelineStatus.incomplete => OnyxColorTokens.accentAmber,
    };
  }

  bool _containsAny(String text, List<String> needles) {
    for (final needle in needles) {
      if (text.contains(needle)) {
        return true;
      }
    }
    return false;
  }

  void _resetFilters() {
    setState(() {
      _activeFilter = _filterAll;
      _activeSourceFilter = _sourceFilterAll;
      _activeProviderFilter = _providerFilterAll;
      _activeIdentityPolicyFilter = _identityPolicyFilterAll;
    });
  }


  Widget _timelinePane({
    required List<DispatchEvent> events,
    required bool bounded,
  }) {
    final list = Column(
      children: [
        for (var i = 0; i < events.length; i++) ...[
          _timelineRow(
            event: events[i],
            selected: _selectedEvent?.eventId == events[i].eventId,
            showConnector: i < events.length - 1,
          ),
          const SizedBox(height: 8),
        ],
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: OnyxColorTokens.divider),
      ),
      child: events.isEmpty
          ? const OnyxEmptyState(label: 'No events match the current filters.')
          : bounded
          ? SingleChildScrollView(padding: const EdgeInsets.all(8), child: list)
          : Padding(padding: const EdgeInsets.all(8), child: list),
    );
  }

  Widget _timelineRow({
    required DispatchEvent event,
    required bool selected,
    required bool showConnector,
  }) {
    final typeColor = _eventColor(event);
    return InkWell(
      onTap: () => setState(() => _selectedEvent = event),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        key: _rowKeyForEvent(event.eventId),
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected
              ? typeColor.withValues(alpha: 0.12)
              : OnyxColorTokens.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? OnyxColorTokens.accentCyan : OnyxColorTokens.divider,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 34,
              child: Column(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: OnyxColorTokens.surfaceInset,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${event.sequence}',
                      style: GoogleFonts.inter(
                        color: OnyxColorTokens.textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (showConnector)
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      width: 1,
                      height: 26,
                      color: OnyxColorTokens.divider.withValues(alpha: 0.20),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_eventTypeLabel(event)}  •  ${event.eventId}',
                          style: GoogleFonts.inter(
                            color: typeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        _clock12(event.occurredAt),
                        style: GoogleFonts.inter(
                          color: OnyxColorTokens.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _eventSummary(event),
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _eventMetaLine(event),
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: selected
                  ? OnyxColorTokens.accentCyan
                  : OnyxColorTokens.textSecondary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailPane({
    required DispatchEvent? selected,
    required bool bounded,
    required List<DispatchEvent> visitScopedEvents,
  }) {
    final content = selected == null
        ? const OnyxEmptyState(label: 'Select an event to view details.')
        : _detailBody(selected, visitScopedEvents: visitScopedEvents);

    return Container(
      key: selected == null
          ? const ValueKey('events-detail-empty')
          : ValueKey('events-detail-${selected.eventId}'),
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OnyxColorTokens.divider),
      ),
      child: bounded
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: content,
            )
          : Padding(padding: const EdgeInsets.all(8), child: content),
    );
  }

  Widget _detailBody(
    DispatchEvent selected, {
    required List<DispatchEvent> visitScopedEvents,
  }) {
    final sceneReview = selected is IntelligenceReceived
        ? widget.sceneReviewByIntelligenceId[selected.intelligenceId.trim()]
        : null;
    final partnerScopeDetail = _partnerScopeDetail(visitScopedEvents);
    final partnerTrend = partnerScopeDetail == null
        ? null
        : _partnerTrendSummary(partnerScopeDetail);
    final visitStatus = _visitTimelineStatus(visitScopedEvents);
    final governanceAction = _openGovernanceActionForEvents([selected]);
    final linkedIntelligenceIds = visitScopedEvents
        .whereType<IntelligenceReceived>()
        .map((event) => event.intelligenceId.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'EVENT DETAIL',
          style: GoogleFonts.inter(
            color: OnyxColorTokens.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        _selectedEventFocusCard(
          selected: selected,
          sceneReview: sceneReview,
          linkedEventCount: visitScopedEvents.length,
          onOpenGovernanceScope: governanceAction,
        ),
        if (partnerScopeDetail != null) ...[
          const SizedBox(height: 8),
          _detailCard(
            child: Column(
              key: const ValueKey('events-partner-progress-card'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PARTNER DISPATCH CHAIN',
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _kvMini('DISPATCH', partnerScopeDetail.dispatchId),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: _kvMini(
                        'DECLARATIONS',
                        '${partnerScopeDetail.events.length}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      key: const ValueKey('events-partner-latest-status-pill'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _partnerStatusColor(
                          partnerScopeDetail.latestStatus,
                        ).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: _partnerStatusColor(
                            partnerScopeDetail.latestStatus,
                          ),
                        ),
                      ),
                      child: Text(
                        _partnerStatusLabel(partnerScopeDetail.latestStatus),
                        style: GoogleFonts.inter(
                          color: _partnerStatusColor(
                            partnerScopeDetail.latestStatus,
                          ),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _contextRow('Partner', partnerScopeDetail.partnerLabel),
                _contextRow('Site', partnerScopeDetail.siteId),
                _contextRow(
                  'Latest',
                  '${_partnerStatusLabel(partnerScopeDetail.latestStatus)} • ${_fullTimestamp(partnerScopeDetail.latestOccurredAt)}',
                ),
                if (partnerTrend != null) ...[
                  const SizedBox(height: 6),
                  _contextRow(
                    '7D Trend',
                    '${partnerTrend.trendLabel} • ${partnerTrend.reportDays}d • ${partnerTrend.currentScoreLabel}',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    partnerTrend.trendReason,
                    key: const ValueKey('events-partner-trend-reason'),
                    style: GoogleFonts.inter(
                      color: _partnerTrendColor(partnerTrend.trendLabel),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final status in PartnerDispatchStatus.values)
                      _partnerMilestoneBadge(
                        status: status,
                        timestamp:
                            partnerScopeDetail.firstOccurrenceByStatus[status],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
        if (visitScopedEvents.isNotEmpty) ...[
          const SizedBox(height: 8),
          _detailCard(
            child: Column(
              key: const ValueKey('events-visit-timeline-card'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VISIT TIMELINE',
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _kvMini(
                        'LINKED EVENTS',
                        '${visitScopedEvents.length}',
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: _kvMini(
                        'LINKED INTEL',
                        '${linkedIntelligenceIds.length}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      key: const ValueKey('events-visit-status-pill'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _visitTimelineStatusColor(
                          visitStatus,
                        ).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: _visitTimelineStatusColor(visitStatus),
                        ),
                      ),
                      child: Text(
                        _visitTimelineStatusLabel(visitStatus),
                        style: GoogleFonts.inter(
                          color: _visitTimelineStatusColor(visitStatus),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _contextRow(
                  'Start',
                  _fullTimestamp(visitScopedEvents.first.occurredAt),
                ),
                _contextRow(
                  'Last Seen',
                  _fullTimestamp(visitScopedEvents.last.occurredAt),
                ),
                const SizedBox(height: 6),
                for (var i = 0; i < visitScopedEvents.length; i++) ...[
                  _visitTimelineStep(
                    event: visitScopedEvents[i],
                    stage: _visitTimelineStageForEvent(
                      visitScopedEvents[i],
                      eventIndex: i,
                    ),
                    selected: visitScopedEvents[i].eventId == selected.eventId,
                    showConnector: i < visitScopedEvents.length - 1,
                  ),
                  if (i < visitScopedEvents.length - 1)
                    const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        _detailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CONTEXT',
                style: GoogleFonts.inter(
                  color: OnyxColorTokens.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 8),
              _contextRow('Site', _eventSiteId(selected)),
              if (selected is IntelligenceReceived) ...[
                _contextRow('Provider', selected.provider),
                _contextRow('Source', selected.sourceType),
                if ((selected.cameraId ?? '').trim().isNotEmpty)
                  _contextRow('Camera', selected.cameraId!.trim()),
                if ((selected.zone ?? '').trim().isNotEmpty)
                  _contextRow('Zone', selected.zone!.trim()),
                if ((selected.objectLabel ?? '').trim().isNotEmpty)
                  _contextRow(
                    'Detection',
                    _eventSignalLabel(
                      selected.objectLabel,
                      selected.objectConfidence,
                    ),
                  ),
                if ((selected.faceMatchId ?? '').trim().isNotEmpty)
                  _contextRow(
                    'Face Match',
                    _eventSignalLabel(
                      selected.faceMatchId,
                      selected.faceConfidence,
                    ),
                  ),
                if ((selected.plateNumber ?? '').trim().isNotEmpty)
                  _contextRow(
                    'Plate Match',
                    _eventSignalLabel(
                      selected.plateNumber,
                      selected.plateConfidence,
                    ),
                  ),
              ],
              if (_guardLabel(selected).isNotEmpty)
                _contextRow('Guard', _guardLabel(selected)),
              _contextRow('Summary', _eventSummary(selected)),
            ],
          ),
        ),
        if (sceneReview != null) ...[
          const SizedBox(height: 8),
          _detailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SCENE REVIEW',
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 8),
                _contextRow('Source', sceneReview.sourceLabel),
                _contextRow('Posture', sceneReview.postureLabel),
                if (_sceneReviewIdentityPolicy(sceneReview) != null)
                  _contextRow(
                    'Identity Policy',
                    _sceneReviewIdentityPolicy(sceneReview)!,
                  ),
                if (sceneReview.decisionLabel.trim().isNotEmpty)
                  _contextRow('Action', sceneReview.decisionLabel),
                _contextRow(
                  'Reviewed At',
                  _fullTimestamp(sceneReview.reviewedAtUtc),
                ),
                _contextRow('Summary', sceneReview.summary),
                if (sceneReview.decisionSummary.trim().isNotEmpty)
                  _contextRow('Decision Detail', sceneReview.decisionSummary),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        _detailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PAYLOAD DATA',
                style: GoogleFonts.inter(
                  color: OnyxColorTokens.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: OnyxColorTokens.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: OnyxColorTokens.divider),
                ),
                child: Text(
                  const JsonEncoder.withIndent(
                    '  ',
                  ).convert(_eventPayload(selected)),
                  style: GoogleFonts.robotoMono(
                    color: OnyxColorTokens.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _detailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VERSION INFO',
                style: GoogleFonts.inter(
                  color: OnyxColorTokens.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 8),
              _contextRow('Schema Version', _eventSchemaVersionLabel(selected)),
              _contextRow('Event Source', _eventSourceLabel(selected)),
              _contextRow(
                'Chain Position',
                'Verified',
                valueColor: OnyxColorTokens.accentGreen,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _outlineAction(
          'OPEN SOVEREIGN LEDGER',
          actionKey: const ValueKey('events-view-ledger-action'),
          onTap: () {
            logUiAction(
              'events.view_in_ledger',
              context: {'event_id': selected.eventId},
            );
            if (widget.onOpenLedger != null) {
              widget.onOpenLedger!.call(selected.eventId);
              return;
            }
            _showActionMessage(
              'Sovereign Ledger is ready for ${selected.eventId}.',
            );
          },
        ),
        const SizedBox(height: 6),
        _outlineAction(
          'EXPORT EVENT DATA',
          actionKey: const ValueKey('events-export-data-action'),
          onTap: () => _exportEventData(selected),
        ),
        const SizedBox(height: 6),
        Text(
          'Selected Event',
          style: GoogleFonts.inter(
            color: OnyxColorTokens.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (_lastActionFeedback.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            _lastActionFeedback,
            key: const ValueKey('events-last-action-feedback'),
            style: GoogleFonts.inter(
              color: OnyxColorTokens.accentSky,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }

  Widget _selectedEventFocusCard({
    required DispatchEvent selected,
    required MonitoringSceneReviewRecord? sceneReview,
    required int linkedEventCount,
    required VoidCallback? onOpenGovernanceScope,
  }) {
    final summaryOnly = _desktopWorkspaceActive;
    final accent = _eventColor(selected);
    final reviewLabel = sceneReview?.postureLabel;
    final providerLabel = selected is IntelligenceReceived
        ? selected.provider
        : null;
    return Container(
      key: const ValueKey('events-selected-focus-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: 0.12), OnyxColorTokens.backgroundSecondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.rule_folder_rounded, color: accent, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Priority',
                      style: GoogleFonts.inter(
                        color: accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      selected.eventId,
                      key: const ValueKey('events-selected-event-id'),
                      style: GoogleFonts.inter(
                        color: OnyxColorTokens.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        height: 0.95,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accent.withValues(alpha: 0.38)),
                ),
                child: Text(
                  _eventTypeLabel(selected),
                  style: GoogleFonts.inter(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _eventSummary(selected),
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_eventMetaLine(selected)}  •  ${_fullTimestamp(selected.occurredAt)}',
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _heroChip('Sequence', '#${selected.sequence}'),
              _heroChip('Linked', '$linkedEventCount'),
              if (providerLabel != null && providerLabel.trim().isNotEmpty)
                _heroChip('Provider', providerLabel),
              if (reviewLabel != null && reviewLabel.trim().isNotEmpty)
                _heroChip('Review', reviewLabel),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            sceneReview == null
                ? 'Governance Desk, Sovereign Ledger, and export are ready from this focused event.'
                : 'Scene evidence is attached, so Governance Desk and Sovereign Ledger can open directly from this event.',
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          if (summaryOnly)
            Text(
              'Governance Desk, Sovereign Ledger, and export stay pinned beside this focused event, so the card can stay loud on desktop.',
              style: GoogleFonts.inter(
                color: OnyxColorTokens.textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _reviewWorkspaceBannerAction(
                  key: const ValueKey('events-selected-focus-open-governance'),
                  label: 'GOVERNANCE DESK',
                  selected: onOpenGovernanceScope != null,
                  accent: onOpenGovernanceScope != null
                      ? OnyxColorTokens.accentCyan
                      : OnyxColorTokens.textMuted,
                  onTap:
                      onOpenGovernanceScope ??
                      () {
                        _showActionMessage(
                          'Open Governance Desk to continue review for ${selected.eventId}.',
                        );
                      },
                ),
                _reviewWorkspaceBannerAction(
                  key: const ValueKey('events-selected-focus-open-ledger'),
                  label: 'SOVEREIGN LEDGER',
                  selected: widget.onOpenLedger != null,
                  accent: widget.onOpenLedger != null
                      ? OnyxColorTokens.accentPurple
                      : OnyxColorTokens.textMuted,
                  onTap: () {
                    logUiAction(
                      'events.focus_card_open_ledger',
                      context: {'event_id': selected.eventId},
                    );
                    if (widget.onOpenLedger != null) {
                      widget.onOpenLedger!.call(selected.eventId);
                      return;
                    }
                    _showActionMessage(
                      'Sovereign Ledger is ready for ${selected.eventId}.',
                    );
                  },
                ),
                _reviewWorkspaceBannerAction(
                  key: const ValueKey('events-selected-focus-copy'),
                  label: 'Copy',
                  selected: false,
                  accent: OnyxColorTokens.accentSky,
                  onTap: () => _exportEventData(selected),
                ),
                _reviewWorkspaceBannerAction(
                  key: const ValueKey('events-selected-focus-export'),
                  label: 'Export',
                  selected: false,
                  accent: OnyxColorTokens.accentAmber,
                  onTap: () => _exportEventData(selected),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _detailCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: OnyxColorTokens.divider),
      ),
      child: child,
    );
  }

  Widget _kvMini(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: OnyxColorTokens.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            color: OnyxColorTokens.textPrimary,
            fontSize: 30,
            height: 0.95,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _contextRow(String key, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              key,
              style: GoogleFonts.inter(
                color: OnyxColorTokens.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                color: valueColor ?? OnyxColorTokens.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _outlineAction(
    String text, {
    required VoidCallback onTap,
    Key? actionKey,
  }) {
    return InkWell(
      key: actionKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: OnyxColorTokens.backgroundSecondary,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: OnyxColorTokens.divider),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: OnyxColorTokens.textPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  Widget _visitTimelineStep({
    required DispatchEvent event,
    required _VisitTimelineStage stage,
    required bool selected,
    required bool showConnector,
  }) {
    final typeColor = _eventColor(event);
    final zoneLabel = event is IntelligenceReceived
        ? (event.zone ?? '').trim()
        : '';
    final signalLabel = event is IntelligenceReceived
        ? _eventSignalLabel(event.objectLabel, event.objectConfidence)
        : '';
    return InkWell(
      key: ValueKey<String>('events-visit-step-${event.eventId}'),
      onTap: () => setState(() => _selectedEvent = event),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? typeColor.withValues(alpha: 0.12)
              : OnyxColorTokens.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? OnyxColorTokens.accentCyan : OnyxColorTokens.divider,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 38,
              child: Column(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: OnyxColorTokens.surfaceInset,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${event.sequence}',
                      style: GoogleFonts.inter(
                        color: OnyxColorTokens.textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (showConnector)
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      width: 1,
                      height: 22,
                      color: OnyxColorTokens.divider.withValues(alpha: 0.20),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _visitBadge(
                        _visitTimelineStageLabel(stage),
                        key: ValueKey<String>(
                          'events-visit-stage-${event.eventId}',
                        ),
                        textColor: _eventColor(event),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_eventTypeLabel(event)} • ${event.eventId}',
                          style: GoogleFonts.inter(
                            color: typeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        _clock12(event.occurredAt),
                        style: GoogleFonts.inter(
                          color: OnyxColorTokens.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _eventSummary(event),
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _visitBadge(_eventSiteId(event)),
                      if (zoneLabel.isNotEmpty) _visitBadge(zoneLabel),
                      if (signalLabel.isNotEmpty &&
                          signalLabel.toLowerCase() != 'unknown')
                        _visitBadge(signalLabel),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _visitBadge(
    String label, {
    Key? key,
    Color textColor = OnyxColorTokens.textSecondary,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: OnyxColorTokens.surfaceElevated,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: OnyxColorTokens.divider),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _partnerMilestoneBadge({
    required PartnerDispatchStatus status,
    required DateTime? timestamp,
  }) {
    final reached = timestamp != null;
    final color = reached
        ? _partnerStatusColor(status)
        : OnyxColorTokens.textMuted;
    return Container(
      key: ValueKey<String>('events-partner-milestone-${status.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: reached
            ? color.withValues(alpha: 0.14)
            : OnyxColorTokens.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: reached ? color : OnyxColorTokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _partnerStatusLabel(status),
            style: GoogleFonts.inter(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            reached ? _clock12(timestamp) : 'Pending',
            style: GoogleFonts.inter(
              color: reached
                  ? OnyxColorTokens.textPrimary
                  : OnyxColorTokens.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportEventData(DispatchEvent event) async {
    await _exportCoordinator.copyJson(
      _eventPayload(event),
      label: 'events.export_event_data',
    );
    _showActionMessage('Event payload copied for ${event.eventId}.');
  }

  Future<void> _copyActivityCaseFileJson(_ActivityScopeSummary summary) async {
    await _exportCoordinator.copyJson(
      _activityCaseFilePayload(summary),
      label: 'events.export_activity_casefile_json',
    );
    _showActionMessage('Activity case file JSON copied.');
  }

  Future<void> _copyReadinessCaseFileJson(
    _ReadinessScopeSummary summary,
  ) async {
    await _exportCoordinator.copyJson(
      _readinessCaseFilePayload(summary),
      label: 'events.export_readiness_casefile_json',
    );
    _showActionMessage('Readiness case file JSON copied.');
  }

  Future<void> _copyShadowCaseFileJson(_ShadowScopeSummary summary) async {
    await _exportCoordinator.copyJson(
      _shadowCaseFilePayload(summary),
      label: 'events.export_shadow_casefile_json',
    );
    _showActionMessage('Shadow MO case file JSON copied.');
  }

  Future<void> _copySyntheticCaseFileJson(
    _SyntheticScopeSummary summary,
  ) async {
    await _exportCoordinator.copyJson(
      _syntheticCaseFilePayload(summary),
      label: 'events.export_synthetic_casefile_json',
    );
    _showActionMessage('Synthetic case file JSON copied.');
  }

  Future<void> _copyActivityCaseFileCsv(_ActivityScopeSummary summary) async {
    final previousReportDate =
        summary.history != null && summary.history!.points.length > 1
        ? summary.history!.points[1].date
        : null;
    final lines = <String>[
      'metric,value',
      'report_date,${summary.reportDate}',
      'live_report_date,${summary.liveReportDate}',
      'site_id,${summary.siteId ?? ''}',
      'event_count,${summary.eventCount}',
      'summary_line,"${summary.summaryLine.replaceAll('"', '""')}"',
      'top_flagged_identity,"${summary.topFlaggedIdentitySummary.replaceAll('"', '""')}"',
      'top_long_presence,"${summary.topLongPresenceSummary.replaceAll('"', '""')}"',
      'top_guard_interaction,"${summary.topGuardInteractionSummary.replaceAll('"', '""')}"',
      'review_refs,"${summary.reviewRefs.join(', ').replaceAll('"', '""')}"',
      if (summary.reportDate.isNotEmpty)
        'current_review_command,${_activityReviewCommand(summary.reportDate)}',
      if (summary.reportDate.isNotEmpty)
        'current_case_file_command,${_activityCaseFileCommand(summary.reportDate)}',
      if ((previousReportDate ?? '').trim().isNotEmpty)
        'previous_review_command,${_activityReviewCommand(previousReportDate!.trim())}',
      if ((previousReportDate ?? '').trim().isNotEmpty)
        'previous_case_file_command,${_activityCaseFileCommand(previousReportDate!.trim())}',
    ];
    if (summary.history != null) {
      lines.add(
        'history_headline,"${summary.history!.headline.replaceAll('"', '""')}"',
      );
      lines.add(
        'history_summary,"${summary.history!.summary.replaceAll('"', '""')}"',
      );
      for (var index = 0; index < summary.history!.points.length; index += 1) {
        final point = summary.history!.points[index];
        final row = index + 1;
        lines.add('history_${row}_date,${point.date}');
        lines.add(
          'history_${row}_summary,"${point.summaryLine.replaceAll('"', '""')}"',
        );
        lines.addAll(
          buildHistoryReviewCommandCsvRows(
            row: row,
            reportDate: point.date,
            reviewCommandBuilder: _activityReviewCommand,
            caseFileCommandBuilder: _activityCaseFileCommand,
          ),
        );
      }
    }
    await _exportCoordinator.copyCsv(
      lines,
      label: 'events.export_activity_casefile_csv',
    );
    _showActionMessage('Activity case file CSV copied.');
  }

  Future<void> _copyReadinessCaseFileCsv(
    _ReadinessScopeSummary summary,
  ) async {
    final previousReportDate = summary.historicalFocus
        ? widget.currentMorningSovereignReportDate
        : null;
    final lines = <String>[
      'metric,value',
      'report_date,${summary.reportDate}',
      'live_report_date,${summary.liveReportDate}',
      'lead_region_id,${summary.leadRegionId ?? ''}',
      'lead_site_id,${summary.leadSiteId ?? ''}',
      'event_count,${summary.eventCount}',
      'focus_state,${summary.focusState}',
      'historical_focus,${summary.historicalFocus ? 'true' : 'false'}',
      'focus_summary,"${summary.focusSummary.replaceAll('"', '""')}"',
      'mode_label,"${summary.modeLabel.replaceAll('"', '""')}"',
      'summary_line,"${summary.summaryLine.replaceAll('"', '""')}"',
      'postural_echo_summary,"${summary.posturalEchoSummary.replaceAll('"', '""')}"',
      'top_intent_summary,"${summary.topIntentSummary.replaceAll('"', '""')}"',
      'hazard_summary,"${summary.hazardSummary.replaceAll('"', '""')}"',
      'review_refs,"${summary.reviewRefs.join(', ').replaceAll('"', '""')}"',
      if (summary.reportDate.isNotEmpty)
        'current_review_command,${_readinessReviewCommand(summary.reportDate)}',
      if (summary.reportDate.isNotEmpty)
        'current_case_file_command,${_readinessCaseFileCommand(summary.reportDate)}',
      if ((previousReportDate ?? '').trim().isNotEmpty)
        'previous_review_command,${_readinessReviewCommand(previousReportDate!.trim())}',
      if ((previousReportDate ?? '').trim().isNotEmpty)
        'previous_case_file_command,${_readinessCaseFileCommand(previousReportDate!.trim())}',
    ];
    await _exportCoordinator.copyCsv(
      lines,
      label: 'events.export_readiness_casefile_csv',
    );
    _showActionMessage('Readiness case file CSV copied.');
  }

  Future<void> _copyShadowCaseFileCsv(_ShadowScopeSummary summary) async {
    final previousReportDate = summary.historicalFocus
        ? widget.currentMorningSovereignReportDate
        : null;
    final orderedSites = sortShadowMoSites(summary.sites);
    final promotionAnchorPayload = buildPromotionShadowAnchorPayload(
      context: summary.promotionAnchor.asContext(),
    );
    final lines = <String>[
      'metric,value',
      'report_date,${summary.reportDate}',
      'live_report_date,${summary.liveReportDate}',
      'event_count,${summary.eventCount}',
      'focus_state,${summary.focusState}',
      'historical_focus,${summary.historicalFocus ? 'true' : 'false'}',
      'focus_summary,"${summary.focusSummary.replaceAll('"', '""')}"',
      'summary_line,"${summary.summaryLine.replaceAll('"', '""')}"',
      'validation_summary,"${summary.validationSummary.replaceAll('"', '""')}"',
      'strength_summary,"${summary.strengthSummary.replaceAll('"', '""')}"',
      'tomorrow_urgency_summary,"${summary.tomorrowUrgencySummary.replaceAll('"', '""')}"',
      'previous_tomorrow_urgency_summary,"${summary.previousTomorrowUrgencySummary.replaceAll('"', '""')}"',
      ...buildPromotionShadowAnchorCsvRows(
        payload: promotionAnchorPayload,
        includeMoId: false,
      ),
      'review_refs,"${summary.reviewRefs.join(', ').replaceAll('"', '""')}"',
      if (summary.history != null)
        'history_headline,"${summary.history!.headline.replaceAll('"', '""')}"',
      if (summary.history != null)
        'history_summary,"${summary.history!.summary.replaceAll('"', '""')}"',
      if (summary.history != null)
        'strength_history_summary,"${summary.history!.strengthSummary.replaceAll('"', '""')}"',
      if (summary.reportDate.isNotEmpty)
        'current_review_command,${_shadowReviewCommand(summary.reportDate)}',
      if (summary.reportDate.isNotEmpty)
        'current_case_file_command,${_shadowCaseFileCommand(summary.reportDate)}',
      if ((previousReportDate ?? '').trim().isNotEmpty)
        'previous_review_command,${_shadowReviewCommand(previousReportDate!.trim())}',
      if ((previousReportDate ?? '').trim().isNotEmpty)
        'previous_case_file_command,${_shadowCaseFileCommand(previousReportDate!.trim())}',
    ];
    for (var i = 0; i < orderedSites.length; i += 1) {
      final site = orderedSites[i];
      lines.add('site_${i + 1}_id,${site.siteId}');
      lines.add(
        'site_${i + 1}_summary,"${site.moShadowSummary.replaceAll('"', '""')}"',
      );
      lines.add('site_${i + 1}_match_count,${site.moShadowMatchCount}');
      lines.add(
        'site_${i + 1}_review_refs,"${site.moShadowReviewRefs.join(', ').replaceAll('"', '""')}"',
      );
    }
    if (summary.history != null) {
      for (var index = 0; index < summary.history!.points.length; index += 1) {
        final point = summary.history!.points[index];
        final row = index + 1;
        lines.add('history_${row}_date,${point.date}');
        lines.add('history_${row}_shadow_site_count,${point.shadowSiteCount}');
        lines.add('history_${row}_match_count,${point.matchCount}');
        lines.add(
          'history_${row}_summary,"${point.summaryLine.replaceAll('"', '""')}"',
        );
        lines.add(
          'history_${row}_validation_summary,"${point.validationSummary.replaceAll('"', '""')}"',
        );
        lines.add(
          'history_${row}_strength_summary,"${point.strengthSummary.replaceAll('"', '""')}"',
        );
        lines.add(
          'history_${row}_tomorrow_urgency_summary,"${point.tomorrowUrgencySummary.replaceAll('"', '""')}"',
        );
        lines.addAll(
          buildHistoryReviewCommandCsvRows(
            row: row,
            reportDate: point.date,
            reviewCommandBuilder: _shadowReviewCommand,
            caseFileCommandBuilder: _shadowCaseFileCommand,
          ),
        );
      }
    }
    await _exportCoordinator.copyCsv(
      lines,
      label: 'events.export_shadow_casefile_csv',
    );
    _showActionMessage('Shadow MO case file CSV copied.');
  }

  Future<void> _copySyntheticCaseFileCsv(
    _SyntheticScopeSummary summary,
  ) async {
    final previousReportDate =
        summary.history != null && summary.history!.points.length > 1
        ? summary.history!.points[1].date
        : null;
    final promotionAnchorPayload = buildPromotionShadowAnchorPayload(
      promotionMoId: summary.promotionMoId,
      context: summary.promotionAnchor.asContext(),
    );
    final lines = <String>[
      'metric,value',
      'report_date,${summary.reportDate}',
      'live_report_date,${summary.liveReportDate}',
      'event_count,${summary.eventCount}',
      'focus_state,${summary.focusState}',
      'historical_focus,${summary.historicalFocus ? 'true' : 'false'}',
      'focus_summary,"${summary.focusSummary.replaceAll('"', '""')}"',
      'mode_label,"${summary.modeLabel.replaceAll('"', '""')}"',
      'summary_line,"${summary.summaryLine.replaceAll('"', '""')}"',
      'policy_summary,"${summary.policySummary.replaceAll('"', '""')}"',
      'top_intent_summary,"${summary.topIntentSummary.replaceAll('"', '""')}"',
      'hazard_summary,"${summary.hazardSummary.replaceAll('"', '""')}"',
      'shadow_posture_summary,"${summary.shadowPostureSummary.replaceAll('"', '""')}"',
      'shadow_learning_summary,"${summary.shadowLearningSummary.replaceAll('"', '""')}"',
      'shadow_memory_summary,"${summary.shadowMemorySummary.replaceAll('"', '""')}"',
      'shadow_tomorrow_urgency_summary,"${summary.shadowTomorrowUrgencySummary.replaceAll('"', '""')}"',
      'previous_shadow_tomorrow_urgency_summary,"${summary.previousShadowTomorrowUrgencySummary.replaceAll('"', '""')}"',
      'promotion_pressure_summary,"${summary.promotionPressureSummary.replaceAll('"', '""')}"',
      'promotion_execution_summary,"${summary.promotionExecutionSummary.replaceAll('"', '""')}"',
      'promotion_summary,"${summary.promotionSummary.replaceAll('"', '""')}"',
      'promotion_target_status,${summary.promotionTargetStatus}',
      'promotion_decision_status,${summary.promotionDecisionStatus}',
      'promotion_decision_summary,"${summary.promotionDecisionSummary.replaceAll('"', '""')}"',
      ...buildPromotionShadowAnchorCsvRows(payload: promotionAnchorPayload),
      'shadow_validation_summary,"${summary.shadowValidationSummary.replaceAll('"', '""')}"',
      'shadow_validation_history_summary,"${summary.shadowValidationHistorySummary.replaceAll('"', '""')}"',
      'learning_summary,"${summary.learningSummary.replaceAll('"', '""')}"',
      'learning_memory_summary,"${summary.learningMemorySummary.replaceAll('"', '""')}"',
      'bias_summary,"${summary.biasSummary.replaceAll('"', '""')}"',
      'shadow_posture_bias_summary,"${summary.shadowPostureBiasSummary.replaceAll('"', '""')}"',
      'review_refs,"${summary.reviewRefs.join(', ').replaceAll('"', '""')}"',
      if (summary.reportDate.isNotEmpty)
        'current_review_command,${_syntheticReviewCommand(summary.reportDate)}',
      if (summary.reportDate.isNotEmpty)
        'current_case_file_command,${_syntheticCaseFileCommand(summary.reportDate)}',
      if ((previousReportDate ?? '').trim().isNotEmpty)
        'previous_review_command,${_syntheticReviewCommand(previousReportDate!.trim())}',
      if ((previousReportDate ?? '').trim().isNotEmpty)
        'previous_case_file_command,${_syntheticCaseFileCommand(previousReportDate!.trim())}',
    ];
    if (summary.history != null) {
      lines.add(
        'history_headline,"${summary.history!.headline.replaceAll('"', '""')}"',
      );
      lines.add(
        'history_summary,"${summary.history!.summary.replaceAll('"', '""')}"',
      );
      for (var index = 0; index < summary.history!.points.length; index += 1) {
        final point = summary.history!.points[index];
        final row = index + 1;
        lines.add('history_${row}_date,${point.date}');
        lines.add(
          'history_${row}_summary,"${point.summaryLine.replaceAll('"', '""')}"',
        );
        lines.add(
          'history_${row}_bias_summary,"${point.biasSummary.replaceAll('"', '""')}"',
        );
        lines.add(
          'history_${row}_shadow_posture_bias_summary,"${point.shadowPostureBiasSummary.replaceAll('"', '""')}"',
        );
        lines.add(
          'history_${row}_shadow_posture_summary,"${point.shadowPostureSummary.replaceAll('"', '""')}"',
        );
        lines.add(
          'history_${row}_shadow_validation_summary,"${point.shadowValidationSummary.replaceAll('"', '""')}"',
        );
        lines.add(
          'history_${row}_shadow_tomorrow_urgency_summary,"${point.shadowTomorrowUrgencySummary.replaceAll('"', '""')}"',
        );
        lines.add(
          'history_${row}_promotion_pressure_summary,"${point.promotionPressureSummary.replaceAll('"', '""')}"',
        );
        lines.add(
          'history_${row}_promotion_execution_summary,"${point.promotionExecutionSummary.replaceAll('"', '""')}"',
        );
        lines.add(
          'history_${row}_promotion_summary,"${point.promotionSummary.replaceAll('"', '""')}"',
        );
        lines.add(
          'history_${row}_promotion_decision_status,${point.promotionDecisionStatus}',
        );
        lines.add(
          'history_${row}_promotion_decision_summary,"${point.promotionDecisionSummary.replaceAll('"', '""')}"',
        );
        lines.addAll(
          buildHistoryReviewCommandCsvRows(
            row: row,
            reportDate: point.date,
            reviewCommandBuilder: _syntheticReviewCommand,
            caseFileCommandBuilder: _syntheticCaseFileCommand,
          ),
        );
      }
    }
    await _exportCoordinator.copyCsv(
      lines,
      label: 'events.export_synthetic_casefile_csv',
    );
    _showActionMessage('Synthetic case file CSV copied.');
  }

  Future<void> _copyTomorrowCaseFileJson(
    _TomorrowPostureScopeSummary summary,
  ) async {
    await _exportCoordinator.copyJson(
      _tomorrowCaseFilePayload(summary),
      label: 'events.export_tomorrow_casefile_json',
    );
    _showActionMessage('Tomorrow posture case file JSON copied.');
  }

  Future<void> _copyTomorrowCaseFileCsv(
    _TomorrowPostureScopeSummary summary,
  ) async {
    final previousReportDate =
        summary.history != null && summary.history!.points.length > 1
        ? summary.history!.points[1].date
        : null;
    final lines = <String>[
      'metric,value',
      'report_date,${summary.reportDate}',
      'live_report_date,${summary.liveReportDate}',
      'event_count,${summary.eventCount}',
      'focus_state,${summary.focusState}',
      'historical_focus,${summary.historicalFocus ? 'true' : 'false'}',
      'focus_summary,"${summary.focusSummary.replaceAll('"', '""')}"',
      'summary_line,"${summary.summaryLine.replaceAll('"', '""')}"',
      'draft_count,${summary.draftCount}',
      'lead_draft_action_type,"${summary.leadDraftActionType.replaceAll('"', '""')}"',
      'lead_draft_description,"${summary.leadDraftDescription.replaceAll('"', '""')}"',
      'learning_summary,"${summary.learningSummary.replaceAll('"', '""')}"',
      'learning_memory_summary,"${summary.learningMemorySummary.replaceAll('"', '""')}"',
      'shadow_summary,"${summary.shadowSummary.replaceAll('"', '""')}"',
      'shadow_posture_summary,"${summary.shadowPostureSummary.replaceAll('"', '""')}"',
      'urgency_summary,"${summary.urgencySummary.replaceAll('"', '""')}"',
      'promotion_pressure_summary,"${summary.promotionPressureSummary.replaceAll('"', '""')}"',
      'promotion_execution_summary,"${summary.promotionExecutionSummary.replaceAll('"', '""')}"',
      'hazard_summary,"${summary.hazardSummary.replaceAll('"', '""')}"',
      'review_refs,"${summary.reviewRefs.join(', ').replaceAll('"', '""')}"',
      if (summary.reportDate.isNotEmpty)
        'current_review_command,${_tomorrowReviewCommand(summary.reportDate)}',
      if (summary.reportDate.isNotEmpty)
        'current_case_file_command,${_tomorrowCaseFileCommand(summary.reportDate)}',
      if ((previousReportDate ?? '').trim().isNotEmpty)
        'previous_review_command,${_tomorrowReviewCommand(previousReportDate!.trim())}',
      if ((previousReportDate ?? '').trim().isNotEmpty)
        'previous_case_file_command,${_tomorrowCaseFileCommand(previousReportDate!.trim())}',
    ];
    if (summary.history != null) {
      lines.add(
        'history_headline,"${summary.history!.headline.replaceAll('"', '""')}"',
      );
      lines.add(
        'history_summary,"${summary.history!.summary.replaceAll('"', '""')}"',
      );
      for (var index = 0; index < summary.history!.points.length; index += 1) {
        final point = summary.history!.points[index];
        final row = index + 1;
        lines.add('history_${row}_date,${point.date}');
        lines.add('history_${row}_draft_count,${point.draftCount}');
        lines.add(
          'history_${row}_summary,"${point.summaryLine.replaceAll('"', '""')}"',
        );
        lines.add(
          'history_${row}_shadow_summary,"${point.shadowSummary.replaceAll('"', '""')}"',
        );
        lines.add(
          'history_${row}_shadow_posture_summary,"${point.shadowPostureSummary.replaceAll('"', '""')}"',
        );
        lines.add(
          'history_${row}_urgency_summary,"${point.urgencySummary.replaceAll('"', '""')}"',
        );
        lines.add(
          'history_${row}_promotion_pressure_summary,"${point.promotionPressureSummary.replaceAll('"', '""')}"',
        );
        lines.add(
          'history_${row}_promotion_execution_summary,"${point.promotionExecutionSummary.replaceAll('"', '""')}"',
        );
        lines.addAll(
          buildHistoryReviewCommandCsvRows(
            row: row,
            reportDate: point.date,
            reviewCommandBuilder: _tomorrowReviewCommand,
            caseFileCommandBuilder: _tomorrowCaseFileCommand,
          ),
        );
      }
    }
    await _exportCoordinator.copyCsv(
      lines,
      label: 'events.export_tomorrow_casefile_csv',
    );
    _showActionMessage('Tomorrow posture case file CSV copied.');
  }

  Map<String, Object?> _activityCaseFilePayload(_ActivityScopeSummary summary) {
    final previousReportDate =
        summary.history != null && summary.history!.points.length > 1
        ? summary.history!.points[1].date
        : null;
    return {
      'activityCaseFile': {
        'reportDate': summary.reportDate,
        'liveReportDate': summary.liveReportDate,
        'siteId': summary.siteId,
        'eventCount': summary.eventCount,
        'summaryLine': summary.summaryLine,
        'topFlaggedIdentitySummary': summary.topFlaggedIdentitySummary,
        'topLongPresenceSummary': summary.topLongPresenceSummary,
        'topGuardInteractionSummary': summary.topGuardInteractionSummary,
        'reviewRefs': summary.reviewRefs,
        'reviewShortcuts': buildReviewShortcuts(
          currentReportDate: summary.reportDate,
          previousReportDate: previousReportDate,
          reviewCommandBuilder: _activityReviewCommand,
          caseFileCommandBuilder: _activityCaseFileCommand,
        ),
        'history': summary.history == null
            ? null
            : {
                'headline': summary.history!.headline,
                'summary': summary.history!.summary,
                'points': summary.history!.points
                    .map(
                      (point) => {
                        'date': point.date,
                        'totalSignals': point.totalSignals,
                        'unknownSignals': point.unknownSignals,
                        'flaggedSignals': point.flaggedSignals,
                        'guardInteractions': point.guardInteractions,
                        'summaryLine': point.summaryLine,
                        ...buildReviewCommandPair(
                          reportDate: point.date,
                          reviewCommandBuilder: _activityReviewCommand,
                          caseFileCommandBuilder: _activityCaseFileCommand,
                        ),
                      },
                    )
                    .toList(growable: false),
              },
      },
    };
  }

  Map<String, Object?> _readinessCaseFilePayload(
    _ReadinessScopeSummary summary,
  ) {
    final previousReportDate = summary.historicalFocus
        ? widget.currentMorningSovereignReportDate
        : null;
    return {
      'readinessCaseFile': {
        'reportDate': summary.reportDate,
        'liveReportDate': summary.liveReportDate,
        'leadRegionId': summary.leadRegionId,
        'leadSiteId': summary.leadSiteId,
        'eventCount': summary.eventCount,
        'focusState': summary.focusState,
        'historicalFocus': summary.historicalFocus,
        'modeLabel': summary.modeLabel,
        'summaryLine': summary.summaryLine,
        'focusSummary': summary.focusSummary,
        'posturalEchoSummary': summary.posturalEchoSummary,
        'topIntentSummary': summary.topIntentSummary,
        'hazardSummary': summary.hazardSummary,
        'reviewRefs': summary.reviewRefs,
        'reviewShortcuts': buildReviewShortcuts(
          currentReportDate: summary.reportDate,
          previousReportDate: previousReportDate,
          reviewCommandBuilder: _readinessReviewCommand,
          caseFileCommandBuilder: _readinessCaseFileCommand,
        ),
      },
    };
  }

  Map<String, Object?> _shadowCaseFilePayload(_ShadowScopeSummary summary) {
    final previousReportDate = summary.historicalFocus
        ? widget.currentMorningSovereignReportDate
        : null;
    final promotionAnchorPayload = buildPromotionShadowAnchorPayload(
      context: summary.promotionAnchor.asContext(),
    );
    return {
      'shadowMoCaseFile': buildShadowMoDossierPayload(
        sites: summary.sites,
        countKey: 'shadowSiteCount',
        metadata: <String, Object?>{
          'reportDate': summary.reportDate,
          'liveReportDate': summary.liveReportDate,
          'eventCount': summary.eventCount,
          'focusState': summary.focusState,
          'historicalFocus': summary.historicalFocus,
          'focusSummary': summary.focusSummary,
          'summaryLine': summary.summaryLine,
          'validationSummary': summary.validationSummary,
          'strengthSummary': summary.strengthSummary,
          'tomorrowUrgencySummary': summary.tomorrowUrgencySummary,
          'previousTomorrowUrgencySummary':
              summary.previousTomorrowUrgencySummary,
          ...promotionAnchorPayload,
          'reviewRefs': summary.reviewRefs,
          'historyHeadline': summary.history?.headline,
          'historySummary': summary.history?.summary,
          'strengthHistorySummary': summary.history?.strengthSummary,
          'reviewShortcuts': buildReviewShortcuts(
            currentReportDate: summary.reportDate,
            previousReportDate: previousReportDate,
            reviewCommandBuilder: _shadowReviewCommand,
            caseFileCommandBuilder: _shadowCaseFileCommand,
          ),
          'history': summary.history == null
              ? null
              : {
                  'headline': summary.history!.headline,
                  'summary': summary.history!.summary,
                  'points': summary.history!.points
                      .map(
                        (point) => {
                          'date': point.date,
                          'shadowSiteCount': point.shadowSiteCount,
                          'matchCount': point.matchCount,
                          'summaryLine': point.summaryLine,
                          'validationSummary': point.validationSummary,
                          'strengthSummary': point.strengthSummary,
                          'tomorrowUrgencySummary':
                              point.tomorrowUrgencySummary,
                          ...buildReviewCommandPair(
                            reportDate: point.date,
                            reviewCommandBuilder: _shadowReviewCommand,
                            caseFileCommandBuilder: _shadowCaseFileCommand,
                          ),
                        },
                      )
                      .toList(growable: false),
                },
        },
      ),
    };
  }

  Map<String, Object?> _tomorrowCaseFilePayload(
    _TomorrowPostureScopeSummary summary,
  ) {
    final previousReportDate =
        summary.history != null && summary.history!.points.length > 1
        ? summary.history!.points[1].date
        : null;
    return {
      'tomorrowPostureCaseFile': {
        'reportDate': summary.reportDate,
        'liveReportDate': summary.liveReportDate,
        'eventCount': summary.eventCount,
        'focusState': summary.focusState,
        'historicalFocus': summary.historicalFocus,
        'summaryLine': summary.summaryLine,
        'focusSummary': summary.focusSummary,
        'draftCount': summary.draftCount,
        'leadDraftActionType': summary.leadDraftActionType,
        'leadDraftDescription': summary.leadDraftDescription,
        'learningSummary': summary.learningSummary,
        'learningMemorySummary': summary.learningMemorySummary,
        'shadowSummary': summary.shadowSummary,
        'shadowPostureSummary': summary.shadowPostureSummary,
        'urgencySummary': summary.urgencySummary,
        'promotionPressureSummary': summary.promotionPressureSummary,
        'promotionExecutionSummary': summary.promotionExecutionSummary,
        'hazardSummary': summary.hazardSummary,
        'reviewRefs': summary.reviewRefs,
        'reviewShortcuts': buildReviewShortcuts(
          currentReportDate: summary.reportDate,
          previousReportDate: previousReportDate,
          reviewCommandBuilder: _tomorrowReviewCommand,
          caseFileCommandBuilder: _tomorrowCaseFileCommand,
        ),
        'history': summary.history == null
            ? null
            : {
                'headline': summary.history!.headline,
                'summary': summary.history!.summary,
                'points': summary.history!.points
                    .map(
                      (point) => {
                        'date': point.date,
                        'draftCount': point.draftCount,
                        'summaryLine': point.summaryLine,
                        'shadowSummary': point.shadowSummary,
                        'shadowPostureSummary': point.shadowPostureSummary,
                        'urgencySummary': point.urgencySummary,
                        'promotionPressureSummary':
                            point.promotionPressureSummary,
                        'promotionExecutionSummary':
                            point.promotionExecutionSummary,
                        ...buildReviewCommandPair(
                          reportDate: point.date,
                          reviewCommandBuilder: _tomorrowReviewCommand,
                          caseFileCommandBuilder: _tomorrowCaseFileCommand,
                        ),
                      },
                    )
                    .toList(growable: false),
              },
      },
    };
  }

  Map<String, Object?> _syntheticCaseFilePayload(
    _SyntheticScopeSummary summary,
  ) {
    final previousReportDate =
        summary.history != null && summary.history!.points.length > 1
        ? summary.history!.points[1].date
        : null;
    final promotionAnchorPayload = buildPromotionShadowAnchorPayload(
      promotionMoId: summary.promotionMoId,
      context: summary.promotionAnchor.asContext(),
    );
    return {
      'syntheticCaseFile': {
        'reportDate': summary.reportDate,
        'liveReportDate': summary.liveReportDate,
        'eventCount': summary.eventCount,
        'focusState': summary.focusState,
        'historicalFocus': summary.historicalFocus,
        'modeLabel': summary.modeLabel,
        'summaryLine': summary.summaryLine,
        'focusSummary': summary.focusSummary,
        'policySummary': summary.policySummary,
        'topIntentSummary': summary.topIntentSummary,
        'hazardSummary': summary.hazardSummary,
        'shadowPostureSummary': summary.shadowPostureSummary,
        'shadowValidationSummary': summary.shadowValidationSummary,
        'shadowValidationHistorySummary':
            summary.shadowValidationHistorySummary,
        'shadowTomorrowUrgencySummary': summary.shadowTomorrowUrgencySummary,
        'previousShadowTomorrowUrgencySummary':
            summary.previousShadowTomorrowUrgencySummary,
        'shadowLearningSummary': summary.shadowLearningSummary,
        'shadowMemorySummary': summary.shadowMemorySummary,
        'promotionPressureSummary': summary.promotionPressureSummary,
        'promotionExecutionSummary': summary.promotionExecutionSummary,
        'promotionSummary': summary.promotionSummary,
        'promotionMoId': summary.promotionMoId,
        'promotionTargetStatus': summary.promotionTargetStatus,
        'promotionDecisionStatus': summary.promotionDecisionStatus,
        'promotionDecisionSummary': summary.promotionDecisionSummary,
        ...promotionAnchorPayload,
        'learningSummary': summary.learningSummary,
        'learningMemorySummary': summary.learningMemorySummary,
        'biasSummary': summary.biasSummary,
        'shadowPostureBiasSummary': summary.shadowPostureBiasSummary,
        'reviewRefs': summary.reviewRefs,
        'reviewShortcuts': buildReviewShortcuts(
          currentReportDate: summary.reportDate,
          previousReportDate: previousReportDate,
          reviewCommandBuilder: _syntheticReviewCommand,
          caseFileCommandBuilder: _syntheticCaseFileCommand,
        ),
        'history': summary.history == null
            ? null
            : {
                'headline': summary.history!.headline,
                'summary': summary.history!.summary,
                'points': summary.history!.points
                    .map(
                      (point) => {
                        'date': point.date,
                        'planCount': point.planCount,
                        'policyCount': point.policyCount,
                        'modeLabel': point.modeLabel,
                        'summaryLine': point.summaryLine,
                        'biasSummary': point.biasSummary,
                        'shadowPostureBiasSummary':
                            point.shadowPostureBiasSummary,
                        'shadowPostureSummary': point.shadowPostureSummary,
                        'shadowValidationSummary':
                            point.shadowValidationSummary,
                        'shadowTomorrowUrgencySummary':
                            point.shadowTomorrowUrgencySummary,
                        'promotionPressureSummary':
                            point.promotionPressureSummary,
                        'promotionExecutionSummary':
                            point.promotionExecutionSummary,
                        'promotionSummary': point.promotionSummary,
                        'promotionDecisionStatus':
                            point.promotionDecisionStatus,
                        'promotionDecisionSummary':
                            point.promotionDecisionSummary,
                        ...buildReviewCommandPair(
                          reportDate: point.date,
                          reviewCommandBuilder: _syntheticReviewCommand,
                          caseFileCommandBuilder: _syntheticCaseFileCommand,
                        ),
                      },
                    )
                    .toList(growable: false),
              },
      },
    };
  }

  void _acceptSyntheticPromotion(_SyntheticScopeSummary summary) {
    if (summary.promotionMoId.isEmpty ||
        summary.promotionTargetStatus.isEmpty) {
      return;
    }
    _moPromotionDecisionStore.accept(
      moId: summary.promotionMoId,
      targetValidationStatus: summary.promotionTargetStatus,
    );
    setState(() {});
    _showActionMessage(
      'MO promotion accepted toward ${summary.promotionTargetStatus} review.',
    );
  }

  void _rejectSyntheticPromotion(_SyntheticScopeSummary summary) {
    if (summary.promotionMoId.isEmpty ||
        summary.promotionTargetStatus.isEmpty) {
      return;
    }
    _moPromotionDecisionStore.reject(
      moId: summary.promotionMoId,
      targetValidationStatus: summary.promotionTargetStatus,
    );
    setState(() {});
    _showActionMessage(
      'MO promotion rejected for ${summary.promotionTargetStatus} review.',
    );
  }

  void _showActionMessage(String message) {
    if (mounted) {
      setState(() {
        _lastActionFeedback = message;
      });
    }
    if (_desktopWorkspaceActive) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: OnyxColorTokens.backgroundSecondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: OnyxColorTokens.divider),
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(
            color: OnyxColorTokens.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  GlobalKey _rowKeyForEvent(String eventId) {
    return _rowKeys.putIfAbsent(
      eventId,
      () => GlobalKey(debugLabel: 'event-row-$eventId'),
    );
  }

  void _scheduleEnsureVisible(String eventId) {
    if (_lastAutoEnsuredEventId == eventId) {
      return;
    }
    _lastAutoEnsuredEventId = eventId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = _rowKeys[eventId];
      final context = key?.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: 0.16,
      );
    });
  }

  List<String> _sourceFilterOptions() {
    final sources = widget.events
        .whereType<IntelligenceReceived>()
        .map((event) => _normalizeSourceFilter(event.sourceType))
        .where((source) => source != _sourceFilterAll)
        .toSet();
    final ordered = <String>[_sourceFilterAll];
    const preferred = <String>[
      'NEWS',
      'HARDWARE',
      'DVR',
      'RADIO',
      'WEARABLE',
      'COMMUNITY',
      'SYSTEM',
    ];
    for (final source in preferred) {
      if (sources.remove(source)) {
        ordered.add(source);
      }
    }
    final remaining = sources.toList()..sort();
    ordered.addAll(remaining);
    return ordered;
  }

  List<String> _providerFilterOptions() {
    final providersByKey = <String, String>{};
    for (final event in widget.events.whereType<IntelligenceReceived>()) {
      final source = _normalizeSourceFilter(event.sourceType);
      if (_activeSourceFilter != _sourceFilterAll &&
          source != _activeSourceFilter) {
        continue;
      }
      final provider = event.provider.trim();
      if (provider.isEmpty) continue;
      final key = _normalizeProviderFilter(provider);
      if (key == _providerFilterAll) continue;
      providersByKey.putIfAbsent(key, () => provider);
    }
    final orderedProviders = providersByKey.values.toList(growable: false)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return <String>[_providerFilterAll, ...orderedProviders];
  }

  List<String> _identityPolicyFilterOptions(List<DispatchEvent> events) {
    final policies =
        events
            .whereType<IntelligenceReceived>()
            .map(_eventIdentityPolicyFilterLabel)
            .whereType<String>()
            .where((policy) => policy != _identityPolicyFilterAll)
            .toSet()
            .toList(growable: false)
          ..sort();
    return <String>[_identityPolicyFilterAll, ...policies];
  }

  String _normalizeSourceFilter(String? sourceType) {
    final normalized = sourceType?.trim().toUpperCase() ?? '';
    if (normalized.isEmpty || normalized == 'ALL') {
      return _sourceFilterAll;
    }
    if (normalized == 'CCTV') {
      return 'HARDWARE';
    }
    if (normalized == 'DVR') {
      return 'DVR';
    }
    return normalized;
  }

  String _normalizeProviderFilter(String? provider) {
    final normalized = provider?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty || normalized == 'all') {
      return _providerFilterAll;
    }
    return normalized;
  }

  String? _eventIdentityPolicyFilterLabel(IntelligenceReceived event) {
    final review =
        widget.sceneReviewByIntelligenceId[event.intelligenceId.trim()];
    if (review == null) {
      return null;
    }
    final policy = _sceneReviewIdentityPolicy(review);
    if (policy == 'Flagged match') {
      return _identityPolicyFilterFlagged;
    }
    if (policy == 'Temporary approval') {
      return _identityPolicyFilterTemporary;
    }
    if (policy == 'Allowlisted match') {
      return _identityPolicyFilterAllowlisted;
    }
    return null;
  }

  _PartnerTrendSummary? _partnerTrendSummary(_PartnerScopeDetail detail) {
    final clientId = detail.clientId.trim();
    final siteId = detail.siteId.trim();
    final partnerLabel = detail.partnerLabel.trim().toUpperCase();
    if (clientId.isEmpty ||
        siteId.isEmpty ||
        partnerLabel.isEmpty ||
        widget.morningSovereignReportHistory.isEmpty) {
      return null;
    }
    final reports = [...widget.morningSovereignReportHistory]
      ..sort(
        (a, b) => b.generatedAtUtc.toUtc().compareTo(a.generatedAtUtc.toUtc()),
      );
    if (reports.isEmpty) {
      return null;
    }
    final latestDate = reports.first.date.trim();
    final matchingRows = <SovereignReportPartnerScoreboardRow>[];
    SovereignReportPartnerScoreboardRow? currentRow;
    for (final report in reports) {
      final reportDate = report.date.trim();
      for (final row in report.partnerProgression.scoreboardRows) {
        if (row.clientId.trim() != clientId ||
            row.siteId.trim() != siteId ||
            row.partnerLabel.trim().toUpperCase() != partnerLabel) {
          continue;
        }
        matchingRows.add(row);
        if (reportDate == latestDate) {
          currentRow = row;
        }
      }
    }
    currentRow ??= matchingRows.isEmpty ? null : matchingRows.first;
    if (currentRow == null) {
      return null;
    }
    final priorSeverityScores = <double>[];
    final priorAcceptedDelayMinutes = <double>[];
    final priorOnSiteDelayMinutes = <double>[];
    for (final report in reports) {
      if (report.date.trim() == latestDate) {
        continue;
      }
      for (final row in report.partnerProgression.scoreboardRows) {
        if (row.clientId.trim() != clientId ||
            row.siteId.trim() != siteId ||
            row.partnerLabel.trim().toUpperCase() != partnerLabel) {
          continue;
        }
        priorSeverityScores.add(_partnerSeverityScore(row));
        if (row.averageAcceptedDelayMinutes > 0) {
          priorAcceptedDelayMinutes.add(row.averageAcceptedDelayMinutes);
        }
        if (row.averageOnSiteDelayMinutes > 0) {
          priorOnSiteDelayMinutes.add(row.averageOnSiteDelayMinutes);
        }
      }
    }
    return _PartnerTrendSummary(
      reportDays: matchingRows.length,
      currentScoreLabel: _partnerDominantScoreLabel(currentRow),
      trendLabel: _partnerTrendLabel(currentRow, priorSeverityScores),
      trendReason: _partnerTrendReason(
        currentRow: currentRow,
        priorSeverityScores: priorSeverityScores,
        priorAcceptedDelayMinutes: priorAcceptedDelayMinutes,
        priorOnSiteDelayMinutes: priorOnSiteDelayMinutes,
      ),
    );
  }

  double _partnerSeverityScore(SovereignReportPartnerScoreboardRow row) {
    final dispatchCount = row.dispatchCount <= 0 ? 1 : row.dispatchCount;
    final rawScore = (row.criticalCount * 3) + row.watchCount - row.strongCount;
    return rawScore / dispatchCount;
  }

  String _partnerDominantScoreLabel(SovereignReportPartnerScoreboardRow row) {
    if (row.criticalCount > 0) {
      return 'CRITICAL';
    }
    if (row.watchCount > 0) {
      return 'WATCH';
    }
    if (row.onTrackCount > 0) {
      return 'ON TRACK';
    }
    if (row.strongCount > 0) {
      return 'STRONG';
    }
    return '';
  }

  String _partnerTrendLabel(
    SovereignReportPartnerScoreboardRow currentRow,
    List<double> priorSeverityScores,
  ) {
    if (priorSeverityScores.isEmpty) {
      return 'NEW';
    }
    final priorAverage =
        priorSeverityScores.reduce((left, right) => left + right) /
        priorSeverityScores.length;
    final currentScore = _partnerSeverityScore(currentRow);
    if (currentScore <= priorAverage - 0.35) {
      return 'IMPROVING';
    }
    if (currentScore >= priorAverage + 0.35) {
      return 'SLIPPING';
    }
    return 'STABLE';
  }

  String _partnerTrendReason({
    required SovereignReportPartnerScoreboardRow currentRow,
    required List<double> priorSeverityScores,
    required List<double> priorAcceptedDelayMinutes,
    required List<double> priorOnSiteDelayMinutes,
  }) {
    if (priorSeverityScores.isEmpty) {
      return 'First recorded shift in the 7-day partner window.';
    }
    final trendLabel = _partnerTrendLabel(currentRow, priorSeverityScores);
    final priorAcceptedAverage = priorAcceptedDelayMinutes.isEmpty
        ? null
        : priorAcceptedDelayMinutes.reduce((left, right) => left + right) /
              priorAcceptedDelayMinutes.length;
    final priorOnSiteAverage = priorOnSiteDelayMinutes.isEmpty
        ? null
        : priorOnSiteDelayMinutes.reduce((left, right) => left + right) /
              priorOnSiteDelayMinutes.length;
    switch (trendLabel) {
      case 'IMPROVING':
        if (priorAcceptedAverage != null &&
            currentRow.averageAcceptedDelayMinutes > 0 &&
            currentRow.averageAcceptedDelayMinutes <=
                priorAcceptedAverage - 2.0) {
          return 'Acceptance timing improved against the prior 7-day average.';
        }
        if (priorOnSiteAverage != null &&
            currentRow.averageOnSiteDelayMinutes > 0 &&
            currentRow.averageOnSiteDelayMinutes <= priorOnSiteAverage - 2.0) {
          return 'On-site timing improved against the prior 7-day average.';
        }
        return 'Current shift severity improved against the prior 7-day average.';
      case 'SLIPPING':
        if (priorAcceptedAverage != null &&
            currentRow.averageAcceptedDelayMinutes >=
                priorAcceptedAverage + 2.0) {
          return 'Acceptance timing slipped beyond the prior 7-day average.';
        }
        if (priorOnSiteAverage != null &&
            currentRow.averageOnSiteDelayMinutes >= priorOnSiteAverage + 2.0) {
          return 'On-site timing slipped beyond the prior 7-day average.';
        }
        return 'Current shift severity slipped against the prior 7-day average.';
      case 'STABLE':
      case 'NEW':
        return 'Current shift is holding close to the prior 7-day performance.';
    }
    return '';
  }

  Color _partnerTrendColor(String trendLabel) {
    return switch (trendLabel) {
      'IMPROVING' => OnyxColorTokens.accentGreen,
      'STABLE' => OnyxColorTokens.textSecondary,
      'SLIPPING' => OnyxColorTokens.accentAmber,
      'NEW' => OnyxColorTokens.accentCyan,
      _ => OnyxColorTokens.textSecondary,
    };
  }
}

enum _VisitTimelineStage { entry, service, exit, observed }

enum _VisitTimelineStatus { completed, active, incomplete }

class _PartnerScopeSummary {
  final int eventCount;
  final String? partnerLabel;
  final String? siteId;

  const _PartnerScopeSummary({
    required this.eventCount,
    required this.partnerLabel,
    required this.siteId,
  });

  String get bannerText {
    final actionWord = eventCount == 1 ? 'action' : 'actions';
    final detailParts = <String>[];
    if (partnerLabel != null && partnerLabel!.isNotEmpty) {
      detailParts.add(partnerLabel!);
    }
    if (siteId != null && siteId!.isNotEmpty) {
      detailParts.add(siteId!);
    }
    final detailSuffix = detailParts.isEmpty
        ? ''
        : ' ${detailParts.join(' • ')}';
    return 'Partner dispatch scope active for $eventCount declared $actionWord.$detailSuffix';
  }
}

class _ActivityScopeSummary {
  final int eventCount;
  final String reportDate;
  final String liveReportDate;
  final String? siteId;
  final String summaryLine;
  final String topFlaggedIdentitySummary;
  final String topLongPresenceSummary;
  final String topGuardInteractionSummary;
  final List<String> reviewRefs;
  final _ActivityHistorySummary? history;

  const _ActivityScopeSummary({
    required this.eventCount,
    required this.reportDate,
    required this.liveReportDate,
    required this.siteId,
    required this.summaryLine,
    required this.topFlaggedIdentitySummary,
    required this.topLongPresenceSummary,
    required this.topGuardInteractionSummary,
    required this.reviewRefs,
    required this.history,
  });

  String get bannerText {
    final signalWord = eventCount == 1 ? 'signal' : 'signals';
    final siteSuffix = siteId == null || siteId!.isEmpty ? '' : ' • ${siteId!}';
    return 'Activity investigation active for $eventCount linked CCTV $signalWord$siteSuffix.';
  }
}

class _ShadowScopeSummary {
  final int eventCount;
  final String reportDate;
  final String liveReportDate;
  final String focusState;
  final bool historicalFocus;
  final String summaryLine;
  final String focusSummary;
  final String validationSummary;
  final String strengthSummary;
  final String tomorrowUrgencySummary;
  final String previousTomorrowUrgencySummary;
  final _PromotionShadowAnchorSummary promotionAnchor;
  final List<String> reviewRefs;
  final List<MonitoringGlobalSitePosture> sites;
  final _ShadowHistorySummary? history;

  const _ShadowScopeSummary({
    required this.eventCount,
    required this.reportDate,
    required this.liveReportDate,
    required this.focusState,
    required this.historicalFocus,
    required this.summaryLine,
    required this.focusSummary,
    required this.validationSummary,
    required this.strengthSummary,
    required this.tomorrowUrgencySummary,
    required this.previousTomorrowUrgencySummary,
    required this.promotionAnchor,
    required this.reviewRefs,
    required this.sites,
    required this.history,
  });

  String get bannerText {
    final evidenceWord = eventCount == 1 ? 'signal' : 'signals';
    return 'Shadow MO investigation active for $eventCount linked $evidenceWord.';
  }
}

class _ReadinessScopeSummary {
  final int eventCount;
  final String reportDate;
  final String liveReportDate;
  final String? leadRegionId;
  final String? leadSiteId;
  final String focusState;
  final bool historicalFocus;
  final String modeLabel;
  final String summaryLine;
  final String focusSummary;
  final String posturalEchoSummary;
  final String topIntentSummary;
  final String hazardSummary;
  final List<String> reviewRefs;

  const _ReadinessScopeSummary({
    required this.eventCount,
    required this.reportDate,
    required this.liveReportDate,
    required this.leadRegionId,
    required this.leadSiteId,
    required this.focusState,
    required this.historicalFocus,
    required this.modeLabel,
    required this.summaryLine,
    required this.focusSummary,
    required this.posturalEchoSummary,
    required this.topIntentSummary,
    required this.hazardSummary,
    required this.reviewRefs,
  });

  String get bannerText {
    final evidenceWord = eventCount == 1 ? 'signal' : 'signals';
    final detailParts = <String>[
      if (leadRegionId != null && leadRegionId!.isNotEmpty) leadRegionId!,
      if (leadSiteId != null && leadSiteId!.isNotEmpty) leadSiteId!,
    ];
    final detailSuffix = detailParts.isEmpty
        ? ''
        : ' • ${detailParts.join(' • ')}';
    return 'Global readiness investigation active for $eventCount linked $evidenceWord$detailSuffix.';
  }
}

class _SyntheticScopeSummary {
  final int eventCount;
  final String reportDate;
  final String liveReportDate;
  final String focusState;
  final bool historicalFocus;
  final String modeLabel;
  final String summaryLine;
  final String focusSummary;
  final String policySummary;
  final String topIntentSummary;
  final String hazardSummary;
  final String shadowPostureSummary;
  final String shadowValidationSummary;
  final String shadowValidationHistorySummary;
  final String shadowTomorrowUrgencySummary;
  final String previousShadowTomorrowUrgencySummary;
  final String shadowLearningSummary;
  final String shadowMemorySummary;
  final String promotionPressureSummary;
  final String promotionExecutionSummary;
  final String promotionSummary;
  final String promotionMoId;
  final String promotionTargetStatus;
  final String promotionDecisionStatus;
  final String promotionDecisionSummary;
  final _PromotionShadowAnchorSummary promotionAnchor;
  final String learningSummary;
  final String learningMemorySummary;
  final String biasSummary;
  final String shadowPostureBiasSummary;
  final List<String> reviewRefs;
  final _SyntheticHistorySummary? history;

  const _SyntheticScopeSummary({
    required this.eventCount,
    required this.reportDate,
    required this.liveReportDate,
    required this.focusState,
    required this.historicalFocus,
    required this.modeLabel,
    required this.summaryLine,
    required this.focusSummary,
    required this.policySummary,
    required this.topIntentSummary,
    required this.hazardSummary,
    required this.shadowPostureSummary,
    required this.shadowValidationSummary,
    required this.shadowValidationHistorySummary,
    required this.shadowTomorrowUrgencySummary,
    required this.previousShadowTomorrowUrgencySummary,
    required this.shadowLearningSummary,
    required this.shadowMemorySummary,
    required this.promotionPressureSummary,
    required this.promotionExecutionSummary,
    required this.promotionSummary,
    required this.promotionMoId,
    required this.promotionTargetStatus,
    required this.promotionDecisionStatus,
    required this.promotionDecisionSummary,
    required this.promotionAnchor,
    required this.learningSummary,
    required this.learningMemorySummary,
    required this.biasSummary,
    required this.shadowPostureBiasSummary,
    required this.reviewRefs,
    required this.history,
  });

  String get bannerText {
    final evidenceWord = eventCount == 1 ? 'signal' : 'signals';
    return 'Synthetic war-room investigation active for $eventCount linked $evidenceWord.';
  }
}

class _PromotionShadowAnchorSummary {
  final String validationStatus;
  final String strengthSummary;
  final String selectedEventId;
  final String reviewRefs;
  final String reviewCommand;
  final String caseFileCommand;

  const _PromotionShadowAnchorSummary({
    this.validationStatus = '',
    this.strengthSummary = '',
    this.selectedEventId = '',
    this.reviewRefs = '',
    this.reviewCommand = '',
    this.caseFileCommand = '',
  });

  Map<String, String> asContext() {
    return <String, String>{
      'validationStatus': validationStatus,
      'strengthSummary': strengthSummary,
      'selectedEventId': selectedEventId,
      'reviewRefs': reviewRefs,
      'reviewCommand': reviewCommand,
      'caseFileCommand': caseFileCommand,
    };
  }
}

class _TomorrowPostureScopeSummary {
  final int eventCount;
  final String reportDate;
  final String liveReportDate;
  final String focusState;
  final bool historicalFocus;
  final String summaryLine;
  final String focusSummary;
  final int draftCount;
  final String leadDraftActionType;
  final String leadDraftDescription;
  final String learningSummary;
  final String learningMemorySummary;
  final String shadowSummary;
  final String shadowPostureSummary;
  final String urgencySummary;
  final String promotionPressureSummary;
  final String promotionExecutionSummary;
  final String hazardSummary;
  final List<String> reviewRefs;
  final _TomorrowPostureHistorySummary? history;

  const _TomorrowPostureScopeSummary({
    required this.eventCount,
    required this.reportDate,
    required this.liveReportDate,
    required this.focusState,
    required this.historicalFocus,
    required this.summaryLine,
    required this.focusSummary,
    required this.draftCount,
    required this.leadDraftActionType,
    required this.leadDraftDescription,
    required this.learningSummary,
    required this.learningMemorySummary,
    required this.shadowSummary,
    required this.shadowPostureSummary,
    required this.urgencySummary,
    required this.promotionPressureSummary,
    required this.promotionExecutionSummary,
    required this.hazardSummary,
    required this.reviewRefs,
    required this.history,
  });

  String get bannerText {
    final evidenceWord = eventCount == 1 ? 'signal' : 'signals';
    return 'Tomorrow posture investigation active for $eventCount linked $evidenceWord.';
  }
}

class _TomorrowPostureHistorySummary {
  final String headline;
  final String summary;
  final List<_TomorrowPostureHistoryPoint> points;

  const _TomorrowPostureHistorySummary({
    required this.headline,
    required this.summary,
    required this.points,
  });
}

class _TomorrowPostureHistoryPoint {
  final String date;
  final int draftCount;
  final String summaryLine;
  final String shadowSummary;
  final String shadowPostureSummary;
  final String urgencySummary;
  final String promotionPressureSummary;
  final String promotionExecutionSummary;

  const _TomorrowPostureHistoryPoint({
    required this.date,
    required this.draftCount,
    required this.summaryLine,
    required this.shadowSummary,
    required this.shadowPostureSummary,
    required this.urgencySummary,
    required this.promotionPressureSummary,
    required this.promotionExecutionSummary,
  });
}

class _ShadowHistorySummary {
  final String headline;
  final String summary;
  final String strengthSummary;
  final List<_ShadowHistoryPoint> points;

  const _ShadowHistorySummary({
    required this.headline,
    required this.summary,
    required this.strengthSummary,
    required this.points,
  });
}

class _ShadowHistoryPoint {
  final String date;
  final int shadowSiteCount;
  final int matchCount;
  final String summaryLine;
  final String validationSummary;
  final String strengthSummary;
  final String tomorrowUrgencySummary;

  const _ShadowHistoryPoint({
    required this.date,
    required this.shadowSiteCount,
    required this.matchCount,
    required this.summaryLine,
    required this.validationSummary,
    required this.strengthSummary,
    required this.tomorrowUrgencySummary,
  });
}

class _SyntheticHistorySummary {
  final String headline;
  final String summary;
  final List<_SyntheticHistoryPoint> points;

  const _SyntheticHistorySummary({
    required this.headline,
    required this.summary,
    required this.points,
  });
}

class _SyntheticHistoryPoint {
  final String date;
  final int planCount;
  final int policyCount;
  final String modeLabel;
  final String summaryLine;
  final String biasSummary;
  final String shadowPostureBiasSummary;
  final String shadowPostureSummary;
  final String shadowValidationSummary;
  final String shadowTomorrowUrgencySummary;
  final String promotionPressureSummary;
  final String promotionExecutionSummary;
  final String promotionSummary;
  final String promotionDecisionStatus;
  final String promotionDecisionSummary;

  const _SyntheticHistoryPoint({
    required this.date,
    required this.planCount,
    required this.policyCount,
    required this.modeLabel,
    required this.summaryLine,
    required this.biasSummary,
    required this.shadowPostureBiasSummary,
    required this.shadowPostureSummary,
    required this.shadowValidationSummary,
    required this.shadowTomorrowUrgencySummary,
    required this.promotionPressureSummary,
    required this.promotionExecutionSummary,
    required this.promotionSummary,
    required this.promotionDecisionStatus,
    required this.promotionDecisionSummary,
  });

  int get pressureScore => planCount + policyCount;
}

class _ActivityHistorySummary {
  final String headline;
  final String summary;
  final List<_ActivityHistoryPoint> points;

  const _ActivityHistorySummary({
    required this.headline,
    required this.summary,
    required this.points,
  });
}

class _ActivityHistoryPoint {
  final String date;
  final int totalSignals;
  final int unknownSignals;
  final int flaggedSignals;
  final int guardInteractions;
  final String summaryLine;

  const _ActivityHistoryPoint({
    required this.date,
    required this.totalSignals,
    required this.unknownSignals,
    required this.flaggedSignals,
    required this.guardInteractions,
    required this.summaryLine,
  });

  int get pressureScore => unknownSignals + flaggedSignals + guardInteractions;
}

class _PartnerScopeDetail {
  final List<PartnerDispatchStatusDeclared> events;
  final String dispatchId;
  final String clientId;
  final String partnerLabel;
  final String siteId;
  final PartnerDispatchStatus latestStatus;
  final DateTime latestOccurredAt;
  final Map<PartnerDispatchStatus, DateTime> firstOccurrenceByStatus;

  const _PartnerScopeDetail({
    required this.events,
    required this.dispatchId,
    required this.clientId,
    required this.partnerLabel,
    required this.siteId,
    required this.latestStatus,
    required this.latestOccurredAt,
    required this.firstOccurrenceByStatus,
  });
}

class _PartnerTrendSummary {
  final int reportDays;
  final String currentScoreLabel;
  final String trendLabel;
  final String trendReason;

  const _PartnerTrendSummary({
    required this.reportDays,
    required this.currentScoreLabel,
    required this.trendLabel,
    required this.trendReason,
  });
}

String _partnerStatusLabel(PartnerDispatchStatus status) {
  return switch (status) {
    PartnerDispatchStatus.unknown => 'UNKNOWN',
    PartnerDispatchStatus.accepted => 'ACCEPT',
    PartnerDispatchStatus.onSite => 'ON SITE',
    PartnerDispatchStatus.allClear => 'ALL CLEAR',
    PartnerDispatchStatus.cancelled => 'CANCELLED',
  };
}

Color _partnerStatusColor(PartnerDispatchStatus status) {
  return switch (status) {
    PartnerDispatchStatus.unknown => OnyxColorTokens.textMuted,
    PartnerDispatchStatus.accepted => OnyxColorTokens.accentCyan,
    PartnerDispatchStatus.onSite => OnyxColorTokens.accentAmber,
    PartnerDispatchStatus.allClear => OnyxColorTokens.accentGreen,
    PartnerDispatchStatus.cancelled => OnyxColorTokens.accentRed,
  };
}

Map<String, dynamic> _eventPayload(DispatchEvent event) {
  return {
    'eventId': event.eventId,
    'sequence': event.sequence,
    'version': event.version,
    'type': _eventTypeLabel(event),
    'clientId': _eventClientId(event),
    'regionId': _eventRegionId(event),
    'siteId': _eventSiteId(event),
    'occurredAt': event.occurredAt.toUtc().toIso8601String(),
    'summary': _eventSummary(event),
    if (event is IntelligenceReceived) ...{
      'provider': event.provider,
      'sourceType': event.sourceType,
      'cameraId': event.cameraId,
      'zone': event.zone,
      'objectLabel': event.objectLabel,
      'objectConfidence': event.objectConfidence,
      'faceMatchId': event.faceMatchId,
      'faceConfidence': event.faceConfidence,
      'plateNumber': event.plateNumber,
      'plateConfidence': event.plateConfidence,
      'headline': event.headline,
      'detailSummary': event.summary,
    },
  };
}

String _eventSignalLabel(String? label, double? confidence) {
  final normalized = (label ?? '').trim();
  if (normalized.isEmpty) {
    return 'unknown';
  }
  final confidenceLabel = _eventConfidenceLabel(confidence);
  if (confidenceLabel == null) {
    return normalized;
  }
  return '$normalized • $confidenceLabel';
}

String? _eventConfidenceLabel(double? confidence) {
  if (confidence == null) {
    return null;
  }
  return '${confidence.toStringAsFixed(1)}%';
}

String? _sceneReviewIdentityPolicy(MonitoringSceneReviewRecord review) {
  final posture = review.postureLabel.trim().toLowerCase();
  final decisionSummary = review.decisionSummary.trim().toLowerCase();
  if (decisionSummary.contains('one-time approval') ||
      decisionSummary.contains('one time approval')) {
    return 'Temporary approval';
  }
  if (posture.contains('known allowed identity') ||
      decisionSummary.contains('allowlisted for this site')) {
    return 'Allowlisted match';
  }
  if (posture.contains('identity match concern') ||
      decisionSummary.contains('was flagged') ||
      decisionSummary.contains('watchlist context') ||
      decisionSummary.contains('unauthorized or watchlist context')) {
    return 'Flagged match';
  }
  return null;
}

String _eventTypeLabel(DispatchEvent event) {
  if (event is _SeededDispatchEvent) return 'INCIDENT CREATED';
  if (event is IntelligenceReceived) return 'AI DECISION';
  if (event is DecisionCreated) return 'INCIDENT CREATED';
  if (event is ResponseArrived) return 'OFFICER ARRIVED';
  if (event is PartnerDispatchStatusDeclared) return 'PARTNER DECLARED';
  if (event is VehicleVisitReviewRecorded) return 'VISIT REVIEW';
  if (event is GuardCheckedIn) return 'CHECKPOINT COMPLETED';
  if (event is ExecutionDenied) return 'ALARM TRIGGERED';
  if (event is ExecutionCompleted) return 'DISPATCH SENT';
  if (event is PatrolCompleted) return 'PATROL COMPLETED';
  if (event is IncidentClosed) return 'INCIDENT CLOSED';
  return event.toAuditTypeKey().toUpperCase();
}

String _eventSummary(DispatchEvent event) {
  if (event is _SeededDispatchEvent) return event.summary;
  if (event is IntelligenceReceived) return event.headline;
  if (event is DecisionCreated) {
    return '${event.clientId}/${event.siteId} dispatch ${event.dispatchId} created';
  }
  if (event is ResponseArrived) {
    return '${event.guardId} arrived for ${event.dispatchId}';
  }
  if (event is PartnerDispatchStatusDeclared) {
    return '${event.partnerLabel} declared ${event.status.name} for ${event.dispatchId}';
  }
  if (event is VehicleVisitReviewRecorded) {
    if (!event.reviewed && event.statusOverride.trim().isEmpty) {
      return '${event.vehicleLabel} review cleared';
    }
    if (event.statusOverride.trim().isNotEmpty) {
      return '${event.vehicleLabel} marked ${event.effectiveStatusLabel}';
    }
    return '${event.vehicleLabel} marked reviewed';
  }
  if (event is GuardCheckedIn) {
    return '${event.guardId} checkpoint scan completed';
  }
  if (event is ExecutionCompleted) {
    return event.success
        ? 'Armed response dispatch initiated'
        : '${event.dispatchId} execution failed';
  }
  if (event is ExecutionDenied) {
    return 'Perimeter alarm activation detected';
  }
  if (event is PatrolCompleted) {
    return '${event.guardId} completed route ${event.routeId}';
  }
  if (event is IncidentClosed) {
    return '${event.dispatchId} closed for ${event.siteId}';
  }
  return event.eventId;
}

String _eventMetaLine(DispatchEvent event) {
  final site = _eventSiteId(event);
  final guard = _guardLabel(event);
  if (guard.isEmpty) {
    return '◎ $site';
  }
  return '◎ $site  •  ♢ $guard';
}

Color _eventColor(DispatchEvent event) {
  if (event is _SeededDispatchEvent) return OnyxColorTokens.accentSky;
  if (event is DecisionCreated) return OnyxColorTokens.accentRed;
  if (event is ExecutionCompleted) return OnyxColorTokens.accentGreen;
  if (event is ResponseArrived) return OnyxColorTokens.accentCyan;
  if (event is PartnerDispatchStatusDeclared) return OnyxColorTokens.accentCyan;
  if (event is VehicleVisitReviewRecorded) return OnyxColorTokens.accentCyan;
  if (event is GuardCheckedIn) return OnyxColorTokens.accentSky;
  if (event is ExecutionDenied) return OnyxColorTokens.accentAmber;
  if (event is IntelligenceReceived) return OnyxColorTokens.accentPurple;
  if (event is IncidentClosed) return OnyxColorTokens.accentGreen;
  return OnyxColorTokens.textMuted;
}

String _guardLabel(DispatchEvent event) {
  if (event is ResponseArrived) return event.guardId;
  if (event is PartnerDispatchStatusDeclared) return event.actorLabel;
  if (event is VehicleVisitReviewRecorded) return event.actorLabel;
  if (event is GuardCheckedIn) return event.guardId;
  if (event is PatrolCompleted) return event.guardId;
  return '';
}

String _eventSiteId(DispatchEvent event) {
  if (event is _SeededDispatchEvent) return event.siteId;
  if (event is DecisionCreated) return event.siteId;
  if (event is ResponseArrived) return event.siteId;
  if (event is PartnerDispatchStatusDeclared) return event.siteId;
  if (event is VehicleVisitReviewRecorded) return event.siteId;
  if (event is GuardCheckedIn) return event.siteId;
  if (event is ExecutionCompleted) return event.siteId;
  if (event is ExecutionDenied) return event.siteId;
  if (event is IntelligenceReceived) return event.siteId;
  if (event is PatrolCompleted) return event.siteId;
  if (event is IncidentClosed) return event.siteId;
  return 'SITE-UNKNOWN';
}

String _eventClientId(DispatchEvent event) {
  if (event is _SeededDispatchEvent) return event.clientId;
  if (event is DecisionCreated) return event.clientId;
  if (event is ResponseArrived) return event.clientId;
  if (event is PartnerDispatchStatusDeclared) return event.clientId;
  if (event is VehicleVisitReviewRecorded) return event.clientId;
  if (event is GuardCheckedIn) return event.clientId;
  if (event is ExecutionCompleted) return event.clientId;
  if (event is ExecutionDenied) return event.clientId;
  if (event is IntelligenceReceived) return event.clientId;
  if (event is PatrolCompleted) return event.clientId;
  if (event is IncidentClosed) return event.clientId;
  return 'CLIENT-UNKNOWN';
}

String _eventRegionId(DispatchEvent event) {
  if (event is _SeededDispatchEvent) return event.regionId;
  if (event is DecisionCreated) return event.regionId;
  if (event is ResponseArrived) return event.regionId;
  if (event is PartnerDispatchStatusDeclared) return event.regionId;
  if (event is VehicleVisitReviewRecorded) return event.regionId;
  if (event is GuardCheckedIn) return event.regionId;
  if (event is ExecutionCompleted) return event.regionId;
  if (event is ExecutionDenied) return event.regionId;
  if (event is IntelligenceReceived) return event.regionId;
  if (event is PatrolCompleted) return event.regionId;
  if (event is IncidentClosed) return event.regionId;
  return 'REGION-UNKNOWN';
}

String _eventSchemaVersionLabel(DispatchEvent event) {
  return 'v${event.version}';
}

String _eventSourceLabel(DispatchEvent event) {
  if (event is IntelligenceReceived) {
    final provider = event.provider.trim();
    if (provider.isNotEmpty) {
      return provider;
    }
    final sourceType = event.sourceType.trim();
    if (sourceType.isNotEmpty) {
      return sourceType;
    }
  }
  return event.toAuditTypeKey();
}

String _clock12(DateTime value) {
  final utc = value.toUtc();
  var hour = utc.hour;
  final minute = utc.minute.toString().padLeft(2, '0');
  final second = utc.second.toString().padLeft(2, '0');
  final suffix = hour >= 12 ? 'PM' : 'AM';
  hour = hour % 12;
  if (hour == 0) hour = 12;
  return '$hour:$minute:$second $suffix UTC';
}

String _fullTimestamp(DateTime value) {
  final utc = value.toUtc();
  final month = utc.month;
  final day = utc.day;
  final year = utc.year;
  return '$month/$day/$year, ${_clock12(utc)}';
}
