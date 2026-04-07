part of '../main.dart';

extension _OnyxRouteSystemBuilders on _OnyxAppState {
  Future<void> Function() _wrapAdminPoll<T>(Future<T> Function() poll) {
    return () async {
      await poll();
    };
  }

  Widget _buildAdminRoute(List<DispatchEvent> events) {
    final activeClientScope = _activeClientRouteScope();
    final cameraScopeClientId = activeClientScope.clientId.trim().isEmpty
        ? _selectedClient
        : activeClientScope.clientId.trim();
    final cameraScopeSiteId = activeClientScope.siteId.trim().isEmpty
        ? _selectedSite
        : activeClientScope.siteId.trim();
    final resolvedAdminChatId = _resolvedTelegramAdminChatId();
    final resolvedClientChatId = _resolvedTelegramClientChatId();
    return AdministrationPage(
      events: events,
      morningSovereignReportHistory: _morningSovereignReportHistory,
      supabaseReady: _routeBuilderSupabaseReady,
      sceneReviewByIntelligenceId: _monitoringSceneReviewByIntelligenceId,
      monitoringIdentityPolicyService: _watchIdentityPolicyService,
      onMonitoringIdentityPolicyServiceChanged: (value) {
        _watchIdentityPolicyService = value;
        _rebuildWatchSceneAssessmentService();
        _applyRouteBuilderState(() {
          _monitoringIdentityRulesJsonOverride = value.toCanonicalJsonString();
        });
      },
      onRegisterTemporaryIdentityApprovalProfile:
          _rememberTemporaryAllowedIdentityProfile,
      onExtendTemporaryIdentityApproval:
          _extendTemporaryIdentityApprovalForScope,
      onExpireTemporaryIdentityApproval:
          _expireTemporaryIdentityApprovalForScope,
      initialMonitoringIdentityRuleAuditHistory:
          _monitoringIdentityRuleAuditHistory,
      onMonitoringIdentityRuleAuditHistoryChanged: (value) {
        _applyRouteBuilderState(() {
          _monitoringIdentityRuleAuditHistory = value;
        });
        unawaited(_persistMonitoringIdentityRuleAuditHistory());
      },
      initialMonitoringIdentityRuleAuditSourceFilter:
          _adminIdentityPolicyAuditSourceFilter,
      onMonitoringIdentityRuleAuditSourceFilterChanged: (value) {
        _applyRouteBuilderState(() {
          _adminIdentityPolicyAuditSourceFilter = value;
        });
        unawaited(_persistMonitoringIdentityRuleAuditSourceFilter());
      },
      initialMonitoringIdentityRuleAuditExpanded:
          _adminIdentityPolicyAuditExpanded,
      onMonitoringIdentityRuleAuditExpandedChanged: (value) {
        _applyRouteBuilderState(() {
          _adminIdentityPolicyAuditExpanded = value;
        });
        unawaited(_persistMonitoringIdentityRuleAuditExpanded());
      },
      initialTab: _adminPageTab,
      initialCommandLabel: _adminInitialCommandLabel,
      initialCommandHeadline: _adminInitialCommandHeadline,
      initialCommandDetail: _adminInitialCommandDetail,
      initialCommandAccent: _adminInitialCommandAccent,
      initialGuardsPlannerAction: _adminInitialGuardsPlannerAction,
      initialGuardsPlannerDate: _adminInitialGuardsPlannerDate,
      onGuardRosterSignalChanged:
          (label, headline, detail, accent, needsAttention) {
            _rememberGuardRosterWarRoomSignal(
              label: label,
              headline: headline,
              detail: detail,
              accent: accent,
              needsAttention: needsAttention,
            );
          },
      onTabChanged: (value) {
        _applyRouteBuilderState(() {
          _adminPageTab = value;
        });
        unawaited(_persistAdminPageTab());
      },
      initialWatchActionDrilldown: _adminWatchActionDrilldown,
      onWatchActionDrilldownChanged: (value) {
        _applyRouteBuilderState(() {
          _adminWatchActionDrilldown = value;
          if (value != null) {
            _adminPageTab = AdministrationPageTab.system;
          }
        });
        unawaited(_persistAdminPageTab());
        unawaited(_persistAdminWatchActionDrilldown());
      },
      onOpenOperationsForIncident: _openOperationsFromAdminIncident,
      onOpenOperationsForScope: _openOperationsForScope,
      onOpenTacticalForIncident: _openTacticalFromAdminIncident,
      onOpenEventsForIncident: _openEventsFromAdminIncident,
      onOpenEventsForScope: (eventIds, selectedEventId) {
        _openEventsForScopedEventIds(
          eventIds,
          selectedEventId: selectedEventId,
        );
      },
      onOpenLedgerForIncident: _openLedgerFromAdminIncident,
      onOpenDispatchesForIncident: _openDispatchesFromAdminIncident,
      onRunDemoAutopilotForIncident: _startDemoAutopilotFromAdminIncident,
      onRunFullDemoAutopilotForIncident:
          _startFullDemoAutopilotFromAdminIncident,
      onOpenGovernance: _openGovernanceFromAdmin,
      onOpenGovernanceForScope: _openGovernanceForScope,
      onOpenGovernanceForPartnerScope: _openGovernanceForPartnerScope,
      onOpenDispatches: _openDispatchesFromAdmin,
      onOpenDispatchesForScope: _openDispatchesForScope,
      onOpenClientView: _openClientViewFromAdmin,
      onOpenClientViewForScope: (clientId, siteId) =>
          _openClientViewForScope(clientId: clientId, siteId: siteId),
      onOpenReports: _openReportsFromAdmin,
      onOpenReportsForScope: _openReportsForScope,
      initialRadioIntentPhrasesJson: _radioIntentPhrasesJsonOverride,
      initialDemoRouteCuesJson: _demoRouteCueOverridesJson,
      initialMonitoringIdentityRulesJson: _monitoringIdentityRulesJsonOverride,
      onSaveRadioIntentPhrasesJson: _saveRadioIntentPhraseConfig,
      onResetRadioIntentPhrasesJson: _clearRadioIntentPhraseConfig,
      onSaveDemoRouteCuesJson: _saveDemoRouteCueOverridesConfig,
      onResetDemoRouteCuesJson: _clearDemoRouteCueOverridesConfig,
      onSaveMonitoringIdentityPolicyService: _saveMonitoringIdentityRulesConfig,
      onResetMonitoringIdentityPolicyService:
          _clearMonitoringIdentityRulesConfig,
      onRunOpsIntegrationPoll: _opsIntegrationPollingAvailable
          ? _pollOpsIntegrationOnce
          : null,
      onRunRadioPoll: _opsIntegrationProfile.radio.configured
          ? _wrapAdminPoll(_ingestRadioOpsSignals)
          : null,
      onRunCctvPoll: _activeVideoProfile.configured
          ? _wrapAdminPoll(_ingestCctvSignals)
          : null,
      onRunWearablePoll:
          (_OnyxAppState._wearableProviderEnv.trim().isNotEmpty &&
              _wearableBridgeUri != null)
          ? _wrapAdminPoll(_ingestWearableSignals)
          : null,
      onRunNewsPoll: _newsIntel.configuredProviders.isNotEmpty
          ? _wrapAdminPoll(_ingestNewsSignals)
          : null,
      onRetryRadioQueue: _pendingRadioAutomatedResponses.isEmpty
          ? null
          : _retryPendingRadioQueueNow,
      onClearRadioQueue: _pendingRadioAutomatedResponses.isEmpty
          ? null
          : _clearPendingRadioQueue,
      onClearRadioQueueFailureSnapshot:
          _radioQueueLastFailureSnapshot.trim().isEmpty
          ? null
          : _clearRadioQueueFailureSnapshotOnly,
      radioQueueHasPending: _pendingRadioAutomatedResponses.isNotEmpty,
      radioOpsPollHealth: _opsHealthSummary(_radioOpsHealth),
      radioOpsQueueHealth: _radioQueueHealthSummary(),
      radioOpsQueueIntentMix: _radioQueueIntentMixSummary(),
      radioOpsAckRecentSummary: _radioAckRecentSummary(events),
      radioOpsQueueStateDetail: _radioQueueStateChangeSummary(),
      radioOpsFailureDetail: _radioQueueLastFailureSnapshot.trim().isEmpty
          ? null
          : 'Last failure • ${_radioQueueLastFailureSnapshot.trim()}',
      radioOpsFailureAuditDetail: _radioQueueFailureAuditSummary(),
      radioOpsManualActionDetail: _radioQueueManualActionSummary(),
      videoOpsLabel: _activeVideoOpsLabel,
      cctvOpsPollHealth: _opsHealthSummary(_cctvOpsHealth),
      cctvCapabilitySummary: _cctvCapabilitySummary(),
      cctvRecentSignalSummary: _cctvRecentSignalSummary(events),
      cctvEvidenceHealthSummary: _cctvEvidenceSummary(),
      cctvCameraHealthSummary: _cctvCameraHealthSummary(),
      fleetScopeHealth: _tacticalFleetScopeHealth(events),
      onOpenFleetTacticalScope: _openTacticalForFleetScope,
      onOpenFleetDispatchScope: _openDispatchesForFleetScope,
      onRecoverFleetWatchScope: (clientId, siteId) {
        unawaited(
          _resyncMonitoringWatchForScope(
            clientId: clientId,
            siteId: siteId,
            actor: 'ADMIN',
          ),
        );
      },
      monitoringWatchAuditSummary: _monitoringWatchAuditSummary,
      monitoringWatchAuditHistory: _monitoringWatchAuditHistory,
      incidentSpoolHealthSummary: _offlineIncidentSpoolSummary(),
      incidentSpoolReplaySummary: _offlineIncidentSpoolReplaySummary(),
      videoIntegrityCertificateStatus: _videoIntegrityCertificateStatus(events),
      videoIntegrityCertificateSummary: _videoIntegrityCertificateSummary(
        events,
      ),
      videoIntegrityCertificateJsonPreview:
          _videoIntegrityCertificateJsonPreview(events),
      videoIntegrityCertificateMarkdownPreview:
          _videoIntegrityCertificateMarkdownPreview(events),
      wearableOpsPollHealth: _opsHealthSummary(_wearableOpsHealth),
      listenerAlarmOpsPollHealth: _opsHealthSummary(_listenerAlarmOpsHealth),
      newsOpsPollHealth: _opsHealthSummary(_newsOpsHealth),
      onyxAgentCameraBridgeStatus: _onyxAgentCameraBridgeStatus(),
      onyxAgentCameraBridgeHealthService:
          _buildOnyxAgentCameraBridgeHealthService(),
      onyxAgentCameraBridgeHealthSnapshot: _onyxAgentCameraBridgeHealthSnapshot,
      onyxAgentCameraBridgeStagingLabel: _cameraWorkerStagingLabelForScope(
        cameraScopeClientId,
        cameraScopeSiteId,
      ),
      onyxAgentCameraBridgeStagingDetail: _cameraWorkerStagingDetailForScope(
        cameraScopeClientId,
        cameraScopeSiteId,
      ),
      telegramBridgeHealthLabel: _telegramBridgeHealthLabel,
      telegramBridgeHealthDetail: _telegramBridgeHealthDetail,
      telegramBridgeFallbackActive: _telegramBridgeFallbackToInApp,
      telegramBridgeHealthUpdatedAtUtc: _telegramBridgeHealthUpdatedAtUtc,
      telegramWiringChecklist: TelegramWiringChecklistView(
        bridgeConfigured: _telegramBridge.isConfigured,
        bridgeHealthLabel: _telegramBridgeHealthLabel,
        adminChatId: resolvedAdminChatId,
        adminThreadId: _resolvedTelegramAdminThreadId(),
        adminChatInheritedFromClient:
            _OnyxAppState._telegramAdminChatIdEnv.trim().isEmpty &&
            resolvedAdminChatId.isNotEmpty &&
            resolvedAdminChatId == resolvedClientChatId,
        adminControlEnabled: _telegramAdminControlEnabled,
        adminAllowedUserCount: _telegramAdminAllowedUserIds.length,
        adminTargetClientId: _telegramAdminTargetClientId,
        adminTargetSiteId: _telegramAdminTargetSiteId,
        clientChatId: resolvedClientChatId,
        clientThreadId: _resolvedTelegramClientThreadId(),
        clientScopeClientId: activeClientScope.clientId,
        clientScopeSiteId: activeClientScope.siteId,
        partnerChatId: _resolvedTelegramPartnerChatId(),
        partnerThreadId: _resolvedTelegramPartnerThreadId(),
        partnerClientId: _resolvedTelegramPartnerClientId(),
        partnerSiteId: _resolvedTelegramPartnerSiteId(),
        recentHandledPrompts: _telegramRecentPromptAudit
            .map(
              (entry) => TelegramRecentPromptView(
                roomLabel: entry.roomLabel,
                scopeLabel: entry.scopeLabel,
                prompt: entry.prompt,
                outcomeLabel: entry.outcomeLabel,
                handledAtUtc: entry.handledAtUtc,
              ),
            )
            .toList(growable: false),
      ),
      telegramAiAssistantEnabled: _telegramAiAssistantEnabled,
      telegramAiApprovalRequired: _telegramAiApprovalRequired,
      telegramAiProviderChainLabel: _telegramAiProviderChainLabel,
      telegramAiFallbackOnly: _telegramAiFallbackOnly,
      telegramAiLastHandledAtUtc: _telegramAiLastHandledAtUtc,
      telegramAiLastHandledSummary: _telegramAiLastHandledSummary,
      telegramAiPendingDrafts: _telegramAiPendingDraftViews(),
      clientCommsAuditViews: _clientCommsAuditViews(),
      siteIdentityRegistryRepositoryBuilder: (client) =>
          SupabaseSiteIdentityRegistryRepository(client),
      clientMessagingBridgeRepositoryBuilder: (client) =>
          SupabaseClientMessagingBridgeRepository(client),
      directoryRefreshToken: _telegramAdminDirectoryRefreshToken,
      approvedTelegramClientSeeds: _telegramApprovedDirectoryClientSeeds,
      approvedTelegramSiteSeeds: _telegramApprovedDirectorySiteSeeds,
      approvedTelegramOnboardingPrefill: _telegramApprovedOnboardingPrefill,
      approvedTelegramBridgeRunbookProgress:
          _telegramApprovedBridgeRunbookProgress,
      approvedTelegramOnboardingFollowUpDismissed:
          _telegramApprovedOnboardingFollowUpDismissed,
      onDismissApprovedTelegramOnboardingFollowUp:
          _dismissApprovedTelegramOnboardingFollowUp,
      onUpdateApprovedTelegramBridgeRunbookProgress:
          _updateApprovedTelegramBridgeRunbookProgress,
      operatorId: _routeBuilderOperatorId,
      onSetOperatorId: _setOperatorIdentity,
      onBindPartnerTelegramEndpoint: _bindAdminPartnerTelegramEndpoint,
      onUnlinkPartnerTelegramEndpoint: _unlinkAdminPartnerTelegramEndpoint,
      onCheckPartnerTelegramEndpoint: _checkAdminPartnerTelegramEndpoint,
      onSetTelegramAiAssistantEnabled: _setTelegramAiAssistantEnabledFromAdmin,
      onSetTelegramAiApprovalRequired: _setTelegramAiApprovalRequiredFromAdmin,
      onSetTelegramAiClientProfileOverride:
          _setTelegramAiClientProfileOverrideFromAdmin,
      onClearTelegramAiLearnedStyleForScope:
          _clearTelegramAiApprovedRewriteExamplesForScope,
      onPinTelegramAiLearnedStyleForScope:
          _pinTelegramAiApprovedRewriteExampleForScope,
      onDemoteTelegramAiLearnedStyleForScope:
          _demoteTelegramAiApprovedRewriteExampleForScope,
      onPinTelegramAiLearnedStyleEntryForScope:
          _pinTelegramAiApprovedRewriteExampleEntryForScope,
      onDemoteTelegramAiLearnedStyleEntryForScope:
          _demoteTelegramAiApprovedRewriteExampleEntryForScope,
      onTagTelegramAiLearnedStyleEntryForScope:
          _setTelegramAiApprovedRewriteExampleTagForScope,
      onResetLiveOperationsQueueHint: () async {
        if (!_liveOperationsQueueHintSeen) {
          return;
        }
        _applyRouteBuilderState(() {
          _liveOperationsQueueHintSeen = false;
        });
        await _persistTelegramAdminRuntimeState();
      },
      onUpdateTelegramAiDraftText: _updateTelegramAiPendingDraftTextFromAdmin,
      onApproveTelegramAiDraft: _approveTelegramAiDraftFromAdmin,
      onRejectTelegramAiDraft: _rejectTelegramAiDraftFromAdmin,
      onRunSiteTelegramChatcheck: _runAdminSiteTelegramChatcheck,
      onSaveSiteCameraAuthConfig: _rememberSiteCameraAuthConfigFromAdmin,
      onOnyxAgentCameraBridgeHealthSnapshotChanged:
          _rememberOnyxAgentCameraBridgeHealthSnapshot,
      onClearOnyxAgentCameraBridgeHealthSnapshot:
          _clearOnyxAgentCameraBridgeHealthSnapshot,
    );
  }
}
