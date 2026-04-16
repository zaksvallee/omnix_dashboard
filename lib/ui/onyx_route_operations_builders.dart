part of '../main.dart';

extension _OnyxRouteOperationsBuilders on _OnyxAppState {
  Widget _buildVipRoute() => VipProtectionPage(
    onCreateDetail: _openVipPackageBuilderFromRoute,
    scheduledDetails: const <VipScheduledDetail>[],
    onReviewScheduledDetail: _openVipPackageReviewFromRoute,
    latestAutoAuditReceipt: _latestVipAutoAuditReceipt,
    onOpenLatestAudit: _latestVipAuditLedgerEntry == null
        ? null
        : _openLedgerForLatestVipAudit,
  );

  void _openVipPackageBuilderFromRoute() {
    _auditVipActionFromRoute(
      'package_staging_opened',
      'Opened VIP package staging from VIP Protection.',
    );
    _openAdminSystemTabForVipPackage();
  }

  void _openVipPackageReviewFromRoute(VipScheduledDetail detail) {
    _auditVipActionFromRoute(
      'package_review_opened',
      'Opened VIP package review for ${detail.title}.',
      packageTitle: detail.title,
      packageSubtitle: detail.subtitle,
    );
    _openAdminSystemTabForVipPackageReview(detail);
  }

  Widget _buildIntelRoute(List<DispatchEvent> events) {
    final areas = _buildRiskIntelAreas(events);
    final recentItems = _buildRiskIntelFeedItems(events);
    return RiskIntelligencePage(
      onAddManualIntel: _openManualIntelFromRiskIntelRoute,
      onViewAreaIntel: _openEventsForRiskIntelAreaFromRoute,
      onViewRecentIntel: _openEventsForRiskIntelItemFromRoute,
      onSendAreaToTrack: _openTrackForRiskIntelAreaFromRoute,
      onSendSignalToTrack: _openTrackForRiskIntelItemFromRoute,
      areas: areas,
      recentItems: recentItems,
      latestAutoAuditReceipt: _latestRiskIntelAutoAuditReceipt,
      onOpenLatestAudit: _latestRiskIntelAuditLedgerEntry == null
          ? null
          : _openLedgerForLatestRiskIntelAudit,
    );
  }

  void _openManualIntelFromRiskIntelRoute() {
    _auditRiskIntelActionFromRoute(
      'manual_intel_opened',
      'Opened manual intel intake from Risk Intel.',
    );
    _openAdminSystemTab();
  }

  void _openEventsForRiskIntelItemFromRoute(RiskIntelFeedItem item) {
    final eventIds = item.eventId == null || item.eventId!.trim().isEmpty
        ? const <String>[]
        : <String>[item.eventId!.trim()];
    _auditRiskIntelActionFromRoute(
      'feed_item_opened',
      'Opened AI call from Risk Intel for ${item.id}.',
      selectedEventId: item.eventId,
      eventIds: eventIds,
    );
    _openEventsForRiskIntelItem(item);
  }

  void _openEventsForRiskIntelAreaFromRoute(RiskIntelAreaSummary area) {
    _auditRiskIntelActionFromRoute(
      'area_scope_opened',
      'Opened ${area.title} signals from Risk Intel.',
      selectedEventId: area.selectedEventId,
      eventIds: area.eventIds,
    );
    _openEventsForRiskIntelArea(area);
  }

  void _openTrackForRiskIntelAreaFromRoute(RiskIntelAreaSummary area) {
    _auditRiskIntelActionFromRoute(
      'area_sent_to_track',
      'Sent ${area.title} risk area to Track from Risk Intel.',
      selectedEventId: area.selectedEventId,
      eventIds: area.eventIds,
    );
    _openTrackForRiskIntelScope(clientId: area.clientId, siteId: area.siteId);
  }

  void _openTrackForRiskIntelItemFromRoute(RiskIntelFeedItem item) {
    final eventIds = item.eventId == null || item.eventId!.trim().isEmpty
        ? const <String>[]
        : <String>[item.eventId!.trim()];
    _auditRiskIntelActionFromRoute(
      'signal_sent_to_track',
      'Sent ${item.id} signal to Track from Risk Intel.',
      selectedEventId: item.eventId,
      eventIds: eventIds,
    );
    _openTrackForRiskIntelScope(clientId: item.clientId, siteId: item.siteId);
  }

  List<RiskIntelAreaSummary> _buildRiskIntelAreas(List<DispatchEvent> events) {
    final intelligenceEvents = events.whereType<IntelligenceReceived>().toList(
      growable: false,
    );
    if (intelligenceEvents.isEmpty) {
      return RiskIntelligencePage.defaultAreas;
    }
    return RiskIntelligencePage.defaultAreas
        .map(
          (area) => _riskIntelAreaSummaryFromEvents(area, intelligenceEvents),
        )
        .toList(growable: false);
  }

  RiskIntelAreaSummary _riskIntelAreaSummaryFromEvents(
    RiskIntelAreaSummary area,
    List<IntelligenceReceived> events,
  ) {
    final matched = events
        .where((event) => _matchesRiskIntelArea(area.title, event))
        .toList();
    if (matched.isEmpty) {
      return area;
    }
    matched.sort((left, right) => right.occurredAt.compareTo(left.occurredAt));
    final maxRiskScore = matched
        .map((event) => event.riskScore)
        .fold<int>(0, (current, value) => value > current ? value : current);
    final tone = _riskIntelAreaTone(maxRiskScore);
    return RiskIntelAreaSummary(
      title: area.title,
      level: tone.$1,
      accent: tone.$2,
      border: tone.$3,
      signalCount: matched.length,
      eventIds: matched.map((event) => event.eventId).toList(growable: false),
      selectedEventId: matched.first.eventId,
      clientId: matched.first.clientId,
      siteId: matched.first.siteId,
      zoneLabel: matched.first.zone,
    );
  }

  List<RiskIntelFeedItem> _buildRiskIntelFeedItems(List<DispatchEvent> events) {
    final intelligenceEvents = events.whereType<IntelligenceReceived>().toList(
      growable: false,
    );
    if (intelligenceEvents.isEmpty) {
      return const <RiskIntelFeedItem>[];
    }
    final sorted = intelligenceEvents.toList()
      ..sort((left, right) => right.occurredAt.compareTo(left.occurredAt));
    return sorted
        .take(3)
        .map(_riskIntelFeedItemFromEvent)
        .toList(growable: false);
  }

  RiskIntelFeedItem _riskIntelFeedItemFromEvent(IntelligenceReceived event) {
    final provider = event.provider.trim().toLowerCase();
    final sourceType = event.sourceType.trim().toLowerCase();
    return RiskIntelFeedItem(
      id: event.intelligenceId,
      eventId: event.eventId,
      sourceType: sourceType,
      provider: provider,
      occurredAtUtc: event.occurredAt.toUtc(),
      timeLabel: _formatRiskIntelTime(event.occurredAt.toUtc()),
      sourceLabel: _riskIntelSourceLabel(event),
      icon: _riskIntelIcon(event),
      iconColor: _riskIntelIconColor(event),
      summary: event.headline.trim().isEmpty ? event.summary : event.headline,
      confidenceScore: event.riskScore,
      clientId: event.clientId,
      siteId: event.siteId,
      zoneLabel: event.zone,
    );
  }

  String _formatRiskIntelTime(DateTime occurredAtUtc) {
    final hour = occurredAtUtc.hour.toString().padLeft(2, '0');
    final minute = occurredAtUtc.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _riskIntelSourceLabel(IntelligenceReceived event) {
    final provider = event.provider.trim();
    final sourceType = event.sourceType.trim();
    if (provider.isNotEmpty) {
      return provider.toUpperCase();
    }
    if (sourceType.isNotEmpty) {
      return sourceType.toUpperCase();
    }
    return 'INTEL';
  }

  IconData _riskIntelIcon(IntelligenceReceived event) {
    return switch (event.sourceType.trim().toLowerCase()) {
      'radio' => Icons.sensors_rounded,
      'community' => Icons.alternate_email_rounded,
      'wearable' => Icons.watch_outlined,
      'hardware' || 'cctv' || 'dvr' => Icons.videocam_outlined,
      _ => Icons.public_rounded,
    };
  }

  Color _riskIntelIconColor(IntelligenceReceived event) {
    if (event.riskScore >= 80) {
      return OnyxColorTokens.accentRed;
    }
    if (event.riskScore >= 55) {
      return OnyxColorTokens.accentAmber;
    }
    return OnyxColorTokens.accentSky;
  }

  bool _matchesRiskIntelArea(String areaTitle, IntelligenceReceived event) {
    final needle = areaTitle.trim().toLowerCase();
    if (needle.isEmpty) {
      return false;
    }
    final haystack = <String>[
      event.headline,
      event.summary,
      event.siteId,
      event.zone ?? '',
    ].join(' ').toLowerCase();
    return haystack.contains(needle);
  }

  (String, Color, Color) _riskIntelAreaTone(int maxRiskScore) {
    if (maxRiskScore >= 80) {
      return ('HIGH', OnyxColorTokens.accentRed, OnyxColorTokens.redBorder);
    }
    if (maxRiskScore >= 55) {
      return (
        'MEDIUM',
        OnyxColorTokens.accentAmber,
        OnyxColorTokens.amberBorder,
      );
    }
    return ('LOW', OnyxColorTokens.accentGreen, OnyxColorTokens.greenBorder);
  }

  void _openEventsForRiskIntelItem(RiskIntelFeedItem item) {
    _focusEventsFromTickerItem(
      OnyxIntelTickerItem(
        id: item.id,
        eventId: item.eventId,
        sourceType: item.sourceType,
        provider: item.provider,
        headline: item.summary,
        occurredAtUtc: item.occurredAtUtc ?? DateTime.now().toUtc(),
      ),
    );
  }

  void _openEventsForRiskIntelArea(RiskIntelAreaSummary area) {
    if (area.eventIds.isEmpty) {
      return;
    }
    _openEventsForScopedEventIds(
      area.eventIds,
      selectedEventId: area.selectedEventId,
      scopeMode: 'risk-intel',
    );
  }

  void _openTrackForRiskIntelScope({
    required String clientId,
    required String siteId,
  }) {
    final normalizedClientId = clientId.trim();
    final normalizedSiteId = siteId.trim();
    _openTacticalForRiskIntelScope(normalizedClientId, normalizedSiteId);
  }

  void _openClientRoomForScopeRoute(
    String room,
    String clientId,
    String siteId,
  ) {
    _openClientViewForScope(clientId: clientId, siteId: siteId, room: room);
  }

  void _openEventsForScopeRoute(
    List<String> eventIds,
    String? selectedEventId,
  ) {
    _openEventsForScopedEventIds(eventIds, selectedEventId: selectedEventId);
  }

  Widget _buildClientsRoute(List<DispatchEvent> events) {
    return _appMode == OnyxAppMode.controller
        ? ClientsPage(
            clientId: _controllerClientsRouteClientId,
            siteId: _controllerClientsRouteSiteId,
            events: events,
            usePlaceholderDataWhenEmpty: false,
            routeHandoffToken: _clientsRouteHandoffToken,
            routeHandoffTarget: _clientsRouteHandoffTarget,
            stagedAgentDraftHandoff:
                _pendingClientsAgentDraftHandoff != null &&
                    _pendingClientsAgentDraftHandoff!.matchesScope(
                      _controllerClientsRouteClientId,
                      _controllerClientsRouteSiteId,
                    )
                ? _pendingClientsAgentDraftHandoff!.handoff
                : null,
            onConsumeStagedAgentDraftHandoff:
                _consumePendingClientsAgentDraftHandoff,
            onRetryPushSync: _retryClientAppPushSync,
            onOpenAgentForIncident: _openAgentFromClientLaneIncident,
            onOpenClientRoomForScope: _openClientRoomForScopeRoute,
            onOpenEventsForScope: _openEventsForScopeRoute,
            evidenceReturnReceipt: _pendingClientsEvidenceReturnReceipt,
            onConsumeEvidenceReturnReceipt:
                _consumePendingClientsEvidenceReturnReceipt,
            liveFollowUpNotice: _latestLiveFollowUpNoticeForScope(
              _controllerClientsRouteClientId,
              _controllerClientsRouteSiteId,
            ),
            onSuggestLiveFollowUpReply: _draftClientsLiveFollowUpReplyForScope,
            onAiAssistQueueDraft: (clientId, siteId, room, currentDraftText) =>
                _draftClientComposerAiReplyForScope(
                  clientId: clientId,
                  siteId: siteId,
                  room: room,
                  currentDraftText: currentDraftText,
                ),
            onSendStagedAgentDraftHandoff:
                _sendClientsRouteStagedReplyToTelegram,
          )
        : _buildClientPage(events);
  }

  Widget _buildSitesRoute(List<DispatchEvent> events) {
    return SitesPage(events: events);
  }

  Widget _buildGuardsRoute(List<DispatchEvent> events) {
    return _appMode == OnyxAppMode.controller
        ? GuardsPage(
            events: events,
            initialSiteFilter: _guardsInitialSiteFilter,
            guardSyncRepositoryFuture: _guardSyncRepositoryFuture,
            evidenceReturnReceipt: _pendingGuardsEvidenceReturnReceipt,
            onConsumeEvidenceReturnReceipt:
                _consumePendingGuardsEvidenceReturnReceipt,
            onOpenGuardSchedule: _openAdminGuardsTab,
            onOpenGuardScheduleForAction: _openAdminGuardsTabForAction,
            onOpenGuardReportsForSite: _openReportsForSite,
            onOpenClientLaneForSite: _openClientViewForSite,
            onStageGuardVoipCall: _stageGuardVoipCall,
          )
        : _buildGuardPage();
  }

  Widget _buildEventsRoute(List<DispatchEvent> events) {
    return EventsReviewPage(
      events: events,
      morningSovereignReportHistory: _morningSovereignReportHistory,
      currentMorningSovereignReportDate: _morningSovereignReport?.date,
      sceneReviewByIntelligenceId: _monitoringSceneReviewByIntelligenceId,
      onOpenGovernance: _openGovernanceFromAdmin,
      onOpenGovernanceForScope: _openGovernanceForScope,
      onOpenLedger: _openLedgerForFocus,
      initialSourceFilter: _eventsSourceFilter.trim().isEmpty
          ? null
          : _eventsSourceFilter,
      initialProviderFilter: _eventsProviderFilter.trim().isEmpty
          ? null
          : _eventsProviderFilter,
      initialSelectedEventId: _eventsSelectedEventId.trim().isEmpty
          ? null
          : _eventsSelectedEventId,
      initialScopedEventIds: _eventsScopedEventIds,
      initialScopedMode: _eventsScopedMode.trim().isEmpty
          ? null
          : _eventsScopedMode,
    );
  }
}
