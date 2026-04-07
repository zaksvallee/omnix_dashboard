part of '../main.dart';

extension _OnyxRouteCommandCenterBuilders on _OnyxAppState {
  void _openClientViewForClientScope(String clientId, String siteId) {
    _openClientViewForScope(
      clientId: clientId,
      siteId: siteId,
      routeHandoffTarget: ClientsRouteHandoffTarget.threadContext,
    );
  }

  void _openCommandCenterEventsForScope(
    List<String> eventIds,
    String? selectedEventId, {
    String scopeMode = '',
  }) {
    _openEventsForScopedEventIds(
      eventIds,
      selectedEventId: selectedEventId,
      scopeMode: scopeMode,
    );
  }

  void _openCommandCenterRoute(
    OnyxRoute route, {
    bool cancelDemoAutopilot = false,
  }) {
    if (cancelDemoAutopilot) {
      _cancelDemoAutopilot();
    }
    _applyRouteBuilderState(() {
      _route = route;
    });
  }

  void _recoverFleetWatchScopeForActor(
    String clientId,
    String siteId,
    String actor,
  ) {
    unawaited(
      _resyncMonitoringWatchForScope(
        clientId: clientId,
        siteId: siteId,
        actor: actor,
      ),
    );
  }

  Widget _buildDashboardRoute(
    List<DispatchEvent> events,
    String previousTomorrowUrgencySummary,
  ) {
    final routeClientId = _operationsRouteClientId.trim();
    final routeSiteId = _operationsRouteSiteId.trim();
    final operationsClientId = routeClientId.isNotEmpty
        ? routeClientId
        : _selectedClient;
    final operationsSiteId = routeSiteId.isNotEmpty
        ? routeSiteId
        : _selectedSite;
    final agentReturnIncidentReference =
        (_pendingOperationsAgentReturnIncidentReference ??
                _operationsAgentReturnIncidentReference)
            ?.trim();
    final initialScopeClientId = routeClientId.isEmpty ? null : routeClientId;
    final initialScopeSiteId = routeSiteId.isEmpty ? null : routeSiteId;
    return LiveOperationsPage(
      events: events,
      morningSovereignReportHistory: _morningSovereignReportHistory,
      historicalSyntheticLearningLabels: _recentSyntheticLearningLabels(),
      historicalShadowMoLabels: _recentShadowMoLabels(),
      historicalShadowStrengthLabels: _recentShadowStrengthLabels(),
      previousTomorrowUrgencySummary: previousTomorrowUrgencySummary,
      focusIncidentReference: _operationsFocusIncidentReference,
      agentReturnIncidentReference: agentReturnIncidentReference,
      onConsumeAgentReturnIncidentReference:
          _consumePendingOperationsAgentReturnIncidentReference,
      initialScopeClientId: initialScopeClientId,
      initialScopeSiteId: initialScopeSiteId,
      videoOpsLabel: _activeVideoOpsLabel,
      sceneReviewByIntelligenceId: _monitoringSceneReviewByIntelligenceId,
      clientCommsSnapshot: _liveClientCommsSnapshot(
        clientId: operationsClientId,
        siteId: operationsSiteId,
      ),
      onLoadCameraHealthFactPacketForScope: (clientId, siteId) =>
          _cameraHealthFactPacketForScope(
            clientId: clientId,
            siteId: siteId,
          ),
      controlInboxSnapshot: _liveControlInboxSnapshot(
        clientId: operationsClientId,
        siteId: operationsSiteId,
      ),
      clientDraftService: _buildOnyxAgentClientDraftService(),
      onOpenClientView: _openClientViewFromAdmin,
      onOpenClientViewForScope: _openClientViewForClientScope,
      onStageClientDraftForScope:
          ({
            required clientId,
            required siteId,
            required draftText,
            required originalDraftText,
            room = 'Residents',
            incidentReference = '',
          }) {
            _stageAgentClientDraftHandoff(
              clientId: clientId,
              siteId: siteId,
              draftText: draftText,
              originalDraftText: originalDraftText,
              room: room,
              incidentReference: incidentReference,
            );
          },
      onClearLearnedLaneStyleForScope: (clientId, siteId) async {
        await _clearTelegramAiApprovedRewriteExamplesForScope(
          clientId: clientId,
          siteId: siteId,
        );
      },
      onSetLaneVoiceProfileForScope: (clientId, siteId, profileSignal) async {
        await _setTelegramAiClientProfileOverrideFromAdmin(
          clientId: clientId,
          siteId: siteId,
          profileSignal: profileSignal,
        );
      },
      onUpdateClientReplyDraftText: _updateTelegramAiPendingDraftTextFromAdmin,
      onApproveClientReplyDraft: _approveTelegramAiDraftFromAdmin,
      onRejectClientReplyDraft: _rejectTelegramAiDraftFromAdmin,
      onOpenAlarms: _openDispatchesFromAdmin,
      onOpenAlarmsForIncident: _openDispatchesFromAdminIncident,
      onOpenAgentForIncident: _openAgentFromOperationsIncident,
      onOpenGuards: () =>
          _openCommandCenterRoute(OnyxRoute.guards, cancelDemoAutopilot: true),
      onOpenRosterPlanner: () => _openAdminGuardsTabForAction('edit-roster'),
      onOpenRosterAudit: _latestRosterPlannerLedgerEntry == null
          ? null
          : _openLedgerForRosterPlannerAudit,
      onOpenLatestAudit: _latestLiveOpsAuditLedgerEntry == null
          ? null
          : _openLedgerForLatestLiveOpsAudit,
      onAutoAuditAction: _auditLiveOpsActionFromRoute,
      latestAutoAuditReceipt: _latestLiveOpsAutoAuditReceipt,
      onOpenCctv: _openAiQueueFromAdmin,
      onOpenCctvForIncident: _openAiQueueFromAdminIncident,
      onOpenTrackForIncident: _openTacticalFromAgentIncident,
      onOpenVipProtection: () => _openCommandCenterRoute(OnyxRoute.vip),
      onOpenRiskIntel: () => _openCommandCenterRoute(OnyxRoute.intel),
      queueStateHintSeen: _liveOperationsQueueHintSeen,
      onQueueStateHintSeen: () => _setLiveOperationsQueueHintSeen(true),
      onQueueStateHintReset: () => _setLiveOperationsQueueHintSeen(false),
      onOpenEventsForScope: _openCommandCenterEventsForScope,
      guardRosterSignalLabel: _guardRosterSignalLabel,
      guardRosterSignalHeadline: _guardRosterSignalHeadline,
      guardRosterSignalDetail: _guardRosterSignalDetail,
      guardRosterSignalAccent: _guardRosterSignalAccent,
      guardRosterSignalNeedsAttention: _guardRosterSignalNeedsAttention,
    );
  }

  Widget _buildAgentRoute(List<DispatchEvent> events) {
    final sourceRoute = _resolvedAgentSourceRoute();
    final agentScope = _agentScope(sourceRoute);
    final scopeClientId = agentScope.clientId;
    final scopeSiteId = agentScope.siteId;
    final focusIncidentReference = _agentFocusIncidentReference(sourceRoute);
    final threadSessionScopeKey = _onyxAgentThreadSessionScopeKey(
      sourceRoute: sourceRoute,
      clientId: scopeClientId,
      siteId: scopeSiteId,
      incidentReference: focusIncidentReference,
    );
    final hasAgentScope = scopeClientId.isNotEmpty;
    final focusIncidentReferenceOrNull = focusIncidentReference.isEmpty
        ? null
        : focusIncidentReference;
    return OnyxAgentPage(
      scopeClientId: scopeClientId,
      scopeSiteId: scopeSiteId,
      focusIncidentReference: focusIncidentReference,
      operatorId: _routeBuilderOperatorId,
      sourceRouteLabel: sourceRoute.autopilotLabel,
      events: events,
      cloudAssistAvailable: _agentCloudAssistAvailable(),
      cameraBridgeStatus: _onyxAgentCameraBridgeStatus(),
      cameraBridgeHealthService: _buildOnyxAgentCameraBridgeHealthService(),
      cameraBridgeHealthSnapshot: _onyxAgentCameraBridgeHealthSnapshot,
      cameraProbeService: _buildOnyxAgentCameraProbeService(),
      cameraChangeService: _buildOnyxAgentCameraChangeService(
        clientId: scopeClientId,
        siteId: scopeSiteId,
      ),
      clientDraftService: _buildOnyxAgentClientDraftService(),
      localBrainService: _buildOnyxAgentLocalBrainService(),
      cloudBoostService: _buildOnyxAgentCloudBoostService(),
      initialThreadSessionState: _onyxAgentThreadSessionStateForScopeKey(
        threadSessionScopeKey,
      ),
      onThreadSessionStateChanged: (state) {
        _rememberOnyxAgentThreadSessionState(threadSessionScopeKey, state);
      },
      onCameraBridgeHealthSnapshotChanged:
          _rememberOnyxAgentCameraBridgeHealthSnapshot,
      onClearCameraBridgeHealthSnapshot:
          _clearOnyxAgentCameraBridgeHealthSnapshot,
      onOpenCctv: _openAiQueueFromAdmin,
      onOpenCctvForIncident: _openAiQueueFromAgentIncident,
      onOpenAlarms: () {
        if (hasAgentScope) {
          _openDispatchesForScope(scopeClientId, scopeSiteId);
          return;
        }
        _openDispatchesFromAdmin();
      },
      onOpenAlarmsForIncident: _openDispatchesFromAgentIncident,
      onOpenTrack: () {
        if (hasAgentScope) {
          _openTacticalForFleetScope(
            scopeClientId,
            scopeSiteId,
            focusIncidentReferenceOrNull,
          );
          return;
        }
        _openTacticalForFleetScope(_selectedClient, _selectedSite);
      },
      onOpenTrackForIncident: _openTacticalFromAgentIncident,
      onOpenOperationsForIncident: _openOperationsFromAgentIncident,
      onOpenComms: () {
        if (hasAgentScope) {
          _openClientViewForScope(
            clientId: scopeClientId,
            siteId: scopeSiteId,
            routeHandoffTarget: ClientsRouteHandoffTarget.threadContext,
          );
          return;
        }
        _openClientViewFromAdmin();
      },
      onOpenCommsForScope: _openClientViewForClientScope,
      onStageCommsDraft: (draftText, originalDraftText) {
        _stageAgentClientDraftHandoff(
          clientId: scopeClientId,
          siteId: scopeSiteId,
          draftText: draftText,
          originalDraftText: originalDraftText,
          room: 'Residents',
          incidentReference: focusIncidentReference,
        );
      },
      evidenceReturnReceipt: _pendingAgentEvidenceReturnReceipt,
      onConsumeEvidenceReturnReceipt: _consumePendingAgentEvidenceReturnReceipt,
    );
  }

  Widget _buildAiQueueRoute(
    List<DispatchEvent> events,
    String previousTomorrowUrgencySummary,
  ) {
    final focusIncidentReference = _aiQueueFocusIncidentReference;
    final agentReturnIncidentReference =
        (_pendingAiQueueAgentReturnIncidentReference ??
                _aiQueueAgentReturnIncidentReference)
            ?.trim();
    final initialSelectedFeedId = _aiQueueSelectedFeedId;
    return AIQueuePage(
      events: events,
      focusIncidentReference: focusIncidentReference,
      agentReturnIncidentReference: agentReturnIncidentReference,
      onConsumeAgentReturnIncidentReference:
          _consumePendingAiQueueAgentReturnIncidentReference,
      evidenceReturnReceipt: _pendingAiQueueEvidenceReturnReceipt,
      onConsumeEvidenceReturnReceipt:
          _consumePendingAiQueueEvidenceReturnReceipt,
      initialSelectedFeedId: initialSelectedFeedId,
      historicalSyntheticLearningLabels: _recentSyntheticLearningLabels(),
      historicalShadowMoLabels: _recentShadowMoLabels(),
      historicalShadowStrengthLabels: _recentShadowStrengthLabels(),
      previousTomorrowUrgencySummary: previousTomorrowUrgencySummary,
      videoOpsLabel: _activeVideoOpsLabel,
      sceneReviewByIntelligenceId: _monitoringSceneReviewByIntelligenceId,
      onOpenAlarmsForIncident: _openDispatchesFromAdminIncident,
      onOpenAgentForIncident: _openAgentFromAiQueueIncident,
      onOpenEventsForScope: (eventIds, selectedEventId) =>
          _openCommandCenterEventsForScope(
            eventIds,
            selectedEventId,
            scopeMode: 'shadow',
          ),
    );
  }

  Widget _buildTacticalRoute(List<DispatchEvent> events) {
    final routeClientId = _tacticalRouteClientId.trim();
    final routeSiteId = _tacticalRouteSiteId.trim();
    final agentReturnIncidentReference =
        (_pendingTacticalAgentReturnIncidentReference ??
                _tacticalAgentReturnIncidentReference)
            ?.trim();
    final initialScopeClientId = routeClientId.isEmpty ? null : routeClientId;
    final initialScopeSiteId = routeSiteId.isEmpty ? null : routeSiteId;
    final cctvCameraHealthSummary = _cctvCameraHealthSummary();
    final cctvRecentSignalSummary =
        '${_cctvRecentSignalSummary(events)}${cctvCameraHealthSummary.isEmpty ? '' : ' • $cctvCameraHealthSummary'}';
    return TacticalPage(
      events: events,
      focusIncidentReference: _operationsFocusIncidentReference,
      agentReturnIncidentReference: agentReturnIncidentReference,
      onConsumeAgentReturnIncidentReference:
          _consumePendingTacticalAgentReturnIncidentReference,
      evidenceReturnReceipt: _pendingTacticalEvidenceReturnReceipt,
      onConsumeEvidenceReturnReceipt:
          _consumePendingTacticalEvidenceReturnReceipt,
      initialScopeClientId: initialScopeClientId,
      initialScopeSiteId: initialScopeSiteId,
      videoOpsLabel: _activeVideoOpsLabel,
      sceneReviewByIntelligenceId: _monitoringSceneReviewByIntelligenceId,
      cctvOpsReadiness: _activeVideoProfile.readinessLabel,
      cctvOpsDetail: _cctvOpsDetailLabel(),
      cctvProvider: _activeVideoProfile.provider,
      cctvCapabilitySummary: _cctvCapabilitySummary(),
      cctvRecentSignalSummary: cctvRecentSignalSummary,
      fleetScopeHealth: _tacticalFleetScopeHealth(
        events,
        clientId: routeClientId,
        siteId: routeSiteId,
      ),
      initialWatchActionDrilldown: _tacticalWatchActionDrilldown,
      onWatchActionDrilldownChanged: _setTacticalWatchActionDrilldown,
      onOpenAgentForIncident: _openAgentFromTacticalIncident,
      onOpenFleetTacticalScope: _openTacticalForFleetScope,
      onOpenFleetDispatchScope: _openDispatchesForFleetScope,
      onRecoverFleetWatchScope: (clientId, siteId) =>
          _recoverFleetWatchScopeForActor(clientId, siteId, 'TACTICAL'),
      onExtendTemporaryIdentityApproval:
          _extendTemporaryIdentityApprovalForScope,
      onExpireTemporaryIdentityApproval:
          _expireTemporaryIdentityApprovalForScope,
    );
  }

  Widget _buildDispatchesRoute(List<DispatchEvent> events) {
    final routeClientId = _dispatchRouteClientId.trim();
    final routeSiteId = _dispatchRouteSiteId.trim();
    final dispatchRouteHasClientScope = routeClientId.isNotEmpty;
    final dispatchClientId = dispatchRouteHasClientScope
        ? routeClientId
        : _selectedClient;
    final dispatchSiteId = routeSiteId.isNotEmpty
        ? routeSiteId
        : dispatchRouteHasClientScope
        ? ''
        : _selectedSite;
    final radioQueueHasPending = _pendingRadioAutomatedResponses.isNotEmpty;
    final livePollingAvailable = _livePollingAvailable;
    final wearableProviderId = _OnyxAppState._wearableProviderEnv.trim();
    final wearableTelemetryReady =
        wearableProviderId.isNotEmpty && _wearableBridgeUri != null;
    final cctvCameraHealthSummary = _cctvCameraHealthSummary();
    final cctvRecentSignalSummary =
        '${_cctvRecentSignalSummary(events)}${cctvCameraHealthSummary.isEmpty ? '' : ' • $cctvCameraHealthSummary'}';
    return DispatchPage(
      clientId: dispatchClientId,
      regionId: _selectedRegion,
      siteId: dispatchSiteId,
      focusIncidentReference: _operationsFocusIncidentReference,
      onGenerate: () {
        _runDispatchDemoGenerationFromRoute(
          clientId: dispatchClientId,
          regionId: _selectedRegion,
          siteId: dispatchSiteId,
        );
        unawaited(
          _recordDispatchAutoAudit(
            dispatchId: '',
            action: 'dispatch_generation_requested',
            detail:
                'Requested dispatch generation for ${dispatchClientId.trim()} / ${dispatchSiteId.trim().isEmpty ? 'all sites' : dispatchSiteId.trim()}.',
            outcome: 'requested',
            clientId: dispatchClientId,
            siteId: dispatchSiteId,
          ),
        );
      },
      onIngestFeeds: () {
        unawaited(_ingestLiveFeedBatch());
      },
      onIngestRadioOps: () {
        unawaited(_ingestRadioOpsSignals());
      },
      onIngestCctvEvents: () {
        unawaited(_ingestCctvSignals());
      },
      onIngestWearableOps: () {
        unawaited(_ingestWearableSignals());
      },
      onIngestNews: () {
        unawaited(_ingestNewsSignals());
      },
      onRetryRadioQueue: !radioQueueHasPending
          ? null
          : () {
              unawaited(_retryPendingRadioQueueNow());
            },
      onClearRadioQueue: !radioQueueHasPending
          ? null
          : () {
              unawaited(_clearPendingRadioQueue());
            },
      onLoadFeedFile: () {
        _loadLiveFeedFile();
      },
      onEscalateIntelligence: _escalateIntelligence,
      configuredNewsSources: _newsIntel.configuredProviders,
      newsSourceRequirementsHint: _newsIntel.configurationHint,
      newsSourceDiagnostics: _newsSourceDiagnostics,
      onProbeNewsSource: _probeNewsSource,
      onStartLivePolling: livePollingAvailable ? _startLiveFeedPolling : null,
      onStopLivePolling: livePollingAvailable ? _stopLiveFeedPolling : null,
      livePolling: _livePolling,
      livePollingLabel: _livePollingLabel,
      runtimeConfigHint: _runtimeConfigHint,
      initialSelectedDispatchId: _dispatchSelectedDispatchId,
      agentReturnIncidentReference:
          _pendingDispatchAgentReturnIncidentReference,
      onConsumeAgentReturnIncidentReference:
          _consumePendingDispatchAgentReturnIncidentReference,
      onSelectedDispatchChanged: (value) {
        _applyRouteBuilderState(() {
          _dispatchSelectedDispatchId = value;
        });
      },
      supabaseReady: _routeBuilderSupabaseReady,
      guardSyncBackendEnabled: _guardSyncUsingBackend,
      telemetryProviderReadiness: _guardTelemetryReadiness.name,
      telemetryProviderActiveId: _guardTelemetryActiveProviderId,
      telemetryProviderExpectedId: _guardTelemetryRequiredProviderId,
      telemetryAdapterStubMode: _guardTelemetryAdapter.isStub,
      telemetryLiveReadyGateEnabled:
          _OnyxAppState._guardTelemetryEnforceLiveReady,
      telemetryLiveReadyGateViolation: _guardTelemetryLiveReadyGateViolated,
      telemetryLiveReadyGateReason: _guardTelemetryLiveReadyGateReason,
      radioOpsReadiness: _opsIntegrationProfile.radio.readinessLabel,
      radioOpsDetail: _opsIntegrationProfile.radio.detailLabel,
      radioOpsQueueHealth: _radioQueueHealthSummary(),
      radioQueueIntentMix: _radioQueueIntentMixSummary(),
      radioAckRecentSummary: _radioAckRecentSummary(events),
      radioQueueHasPending: radioQueueHasPending,
      radioQueueFailureDetail: _radioQueueFailureSummary(),
      radioQueueManualActionDetail: _radioQueueManualActionSummary(),
      radioAiAutoAllClearEnabled:
          _opsIntegrationProfile.radio.aiAutoAllClearEnabled,
      videoOpsLabel: _activeVideoOpsLabel,
      cctvOpsReadiness: _activeVideoProfile.readinessLabel,
      cctvOpsDetail: _cctvOpsDetailLabel(),
      cctvCapabilitySummary: _cctvCapabilitySummary(),
      cctvRecentSignalSummary: cctvRecentSignalSummary,
      fleetScopeHealth: _tacticalFleetScopeHealth(events),
      initialWatchActionDrilldown: _dispatchWatchActionDrilldown,
      onWatchActionDrilldownChanged: _setDispatchWatchActionDrilldown,
      onOpenFleetTacticalScope: _openTacticalForFleetScope,
      onOpenFleetDispatchScope: _openDispatchesForFleetScope,
      onRecoverFleetWatchScope: (clientId, siteId) =>
          _recoverFleetWatchScopeForActor(clientId, siteId, 'DISPATCH'),
      onExtendTemporaryIdentityApproval:
          _extendTemporaryIdentityApprovalForScope,
      onExpireTemporaryIdentityApproval:
          _expireTemporaryIdentityApprovalForScope,
      wearableOpsReadiness: wearableTelemetryReady ? 'ACTIVE' : 'UNCONFIGURED',
      wearableOpsDetail: wearableTelemetryReady
          ? '$wearableProviderId • wearable telemetry events'
          : 'Configure ONYX_WEARABLE_PROVIDER and ONYX_WEARABLE_EVENTS_URL.',
      livePollingHistory: _livePollingHistory,
      onRunStress: _runStressIntake,
      onRunSoak: _runSoakIntake,
      onRunBenchmarkSuite: _runBenchmarkSuite,
      initialProfile: _currentStressProfile,
      initialScenarioLabel: _currentScenarioLabel,
      initialScenarioTags: _currentScenarioTags,
      initialRunNote: _currentRunNote,
      initialFilterPresets: _savedFilterPresets,
      initialIntelligenceSourceFilter: _currentIntelligenceSourceFilter,
      initialIntelligenceActionFilter: _currentIntelligenceActionFilter,
      initialPinnedWatchIntelligenceIds: _pinnedWatchIntelligenceIds,
      initialDismissedIntelligenceIds: _dismissedIntelligenceIds,
      initialShowPinnedWatchIntelligenceOnly: _showPinnedWatchIntelligenceOnly,
      initialShowDismissedIntelligenceOnly: _showDismissedIntelligenceOnly,
      initialSelectedIntelligenceId: _selectedIntelligenceId,
      onProfileChanged: _persistStressProfile,
      onScenarioChanged: _persistScenarioDraft,
      onRunNoteChanged: _persistRunNoteDraft,
      onFilterPresetsChanged: _persistFilterPresets,
      onIntelligenceFiltersChanged: _persistIntelligenceFilters,
      onIntelligenceTriageChanged: _persistIntelligenceTriage,
      onIntelligenceViewModesChanged: _persistIntelligenceViewModes,
      onSelectedIntelligenceChanged: _persistSelectedIntelligence,
      onTelemetryImported: _importDispatchTelemetryFromRoute,
      onRerunLastProfile: _lastStressProfile == null ? null : _rerunLastProfile,
      onCancelStress: _cancelStressRun,
      onResetTelemetry: _resetTelemetry,
      onClearTelemetryPersistence: _clearTelemetryPersistence,
      onClearLivePollHealth: _clearLivePollHealth,
      onClearProfilePersistence: _clearProfilePersistence,
      onClearSavedViewsPersistence: _clearSavedViewsPersistence,
      stressRunning: _stressRunning,
      intakeStatus: _lastIntakeStatus,
      stressStatus: _lastStressStatus,
      intakeTelemetry: _intakeTelemetry,
      events: events,
      morningSovereignReportHistory: _morningSovereignReportHistory,
      onExecute: (dispatchId) {
        unawaited(_executeDispatchAndNotifyPartner(dispatchId));
      },
      onOpenTrackForDispatch: _openTacticalFromAdminIncident,
      onOpenCctvForDispatch: _openAiQueueFromAdminIncident,
      onOpenClientForDispatch: _openClientViewForIncidentReference,
      onOpenAgentForDispatch: _openAgentFromDispatchIncident,
      onOpenReportForDispatch: _openReportsForDispatchId,
      onOpenRosterPlanner: () => _openAdminGuardsTabForAction('edit-roster'),
      onOpenRosterAudit: _latestRosterPlannerLedgerEntry == null
          ? null
          : _openLedgerForRosterPlannerAudit,
      onOpenLatestAudit: _latestDispatchAuditLedgerEntry == null
          ? null
          : _openLedgerForLatestDispatchAudit,
      evidenceReturnReceipt: _pendingDispatchEvidenceReturnReceipt,
      onConsumeEvidenceReturnReceipt:
          _consumePendingDispatchEvidenceReturnReceipt,
      onAutoAuditAction: _auditDispatchActionFromRoute,
      latestAutoAuditReceipt: _latestDispatchAutoAuditReceipt,
      guardRosterSignalLabel: _guardRosterSignalLabel,
      guardRosterSignalHeadline: _guardRosterSignalHeadline,
      guardRosterSignalDetail: _guardRosterSignalDetail,
      guardRosterSignalAccent: _guardRosterSignalAccent,
      guardRosterSignalNeedsAttention: _guardRosterSignalNeedsAttention,
    );
  }
}
