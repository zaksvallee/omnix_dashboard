part of '../main.dart';

extension _OnyxRouteEvidenceBuilders on _OnyxAppState {
  void _openEventsForLedgerScope(
    List<String> eventIds,
    String? selectedEventId, {
    String originLabel = '',
  }) {
    _openEventsForScopedEventIds(
      eventIds,
      selectedEventId: selectedEventId,
      routeSource: ZaraEventsRouteSource.ledger,
      originLabel: originLabel,
    );
  }

  void _openEventsForReportsScope(
    List<String> eventIds,
    String? selectedEventId, {
    String originLabel = '',
  }) {
    _openEventsForScopedEventIds(
      eventIds,
      selectedEventId: selectedEventId,
      routeSource: ZaraEventsRouteSource.reports,
      originLabel: originLabel,
    );
  }

  Widget _buildLedgerRoute(List<DispatchEvent> events) {
    final ledgerRouteClientId = _ledgerRouteClientId.trim();
    final ledgerRouteSiteId = _ledgerRouteSiteId.trim();
    final focusReference = _operationsFocusIncidentReference.trim();
    final scopedClientId = ledgerRouteClientId.isNotEmpty
        ? ledgerRouteClientId
        : _selectedClient;
    SovereignLedgerPinnedAuditEntry? visiblePinnedAuditEntry;
    final candidatePinnedEntries = <SovereignLedgerPinnedAuditEntry?>[
      _activeLedgerPinnedAuditEntry,
      _latestSitesAuditLedgerEntry,
      _latestVipAuditLedgerEntry,
      _latestRiskIntelAuditLedgerEntry,
      _latestDispatchAuditLedgerEntry,
      _latestLiveOpsAuditLedgerEntry,
      _latestRosterPlannerLedgerEntry,
    ];
    for (final candidate in candidatePinnedEntries) {
      if (candidate == null ||
          candidate.clientId.trim() != scopedClientId ||
          (ledgerRouteSiteId.isNotEmpty &&
              candidate.siteId.trim() != ledgerRouteSiteId)) {
        continue;
      }
      if (focusReference.isNotEmpty && candidate.auditId == focusReference) {
        visiblePinnedAuditEntry = candidate;
        break;
      }
      visiblePinnedAuditEntry ??= candidate;
    }
    return SovereignLedgerPage(
      clientId: scopedClientId,
      initialScopeClientId: ledgerRouteClientId.isEmpty
          ? null
          : ledgerRouteClientId,
      initialScopeSiteId: ledgerRouteSiteId.isEmpty ? null : ledgerRouteSiteId,
      events: events,
      sceneReviewByIntelligenceId: _monitoringSceneReviewByIntelligenceId,
      initialFocusReference: focusReference,
      onOpenEventsForScope: _openEventsForLedgerScope,
      pinnedAuditEntry: visiblePinnedAuditEntry,
      onReturnToWarRoom: visiblePinnedAuditEntry == null
          ? null
          : _returnToWarRoomFromPinnedAudit,
      onOpenDispatchForIncident: _openDispatchesFromEvidenceAudit,
      onOpenReportForDispatchAudit: _openReportsFromEvidenceAudit,
      onOpenClientForIncident: _openClientViewFromEvidenceAudit,
      onOpenAgentForIncident: _openDispatchAgentFromEvidenceAudit,
      onOpenOperationsAgentForIncident: _openOperationsAgentFromEvidenceAudit,
      onOpenCctvForIncident: _openAiQueueFromEvidenceAudit,
      onOpenTrackForIncident: _openTacticalFromEvidenceAudit,
      onOpenManualIntelFromAudit: _openAdminSystemTabFromIntelAudit,
      onOpenVipPackageFromAudit: _openAdminSystemTabFromVipAudit,
      onOpenRosterPlannerFromAudit: _openAdminGuardsPlannerFromAudit,
      onOpenSitesActionFromAudit: _openSitesActionFromAudit,
    );
  }

  Widget _buildReportsRoute() {
    final reportsScopeClientId = _reportsScopeClientId.trim();
    final reportsScopeSiteId = _reportsScopeSiteId.trim();
    final reportsScopePartnerLabel = _reportsScopePartnerLabel.trim();
    return ClientIntelligenceReportsPage(
      store: store,
      selectedClient: reportsScopeClientId.isNotEmpty
          ? reportsScopeClientId
          : _selectedClient,
      selectedSite: reportsScopeSiteId.isNotEmpty
          ? reportsScopeSiteId
          : _selectedSite,
      sceneReviewByIntelligenceId: _monitoringSceneReviewByIntelligenceId,
      reportShellState: _reportShellState,
      morningSovereignReportHistory: _morningSovereignReportHistory,
      initialPartnerScopeClientId: reportsScopeClientId.isEmpty
          ? null
          : reportsScopeClientId,
      initialPartnerScopeSiteId: reportsScopeSiteId.isEmpty
          ? null
          : reportsScopeSiteId,
      initialPartnerScopePartnerLabel: reportsScopePartnerLabel.isEmpty
          ? null
          : reportsScopePartnerLabel,
      onOpenGovernanceForScope: _openGovernanceForScope,
      onOpenGovernanceForPartnerScope: _openGovernanceForPartnerScope,
      onOpenEventsForScope: _openEventsForReportsScope,
      onOpenDispatchesForScope: _openDispatchesForScope,
      onOpenGuards: () =>
          _openCommandCenterRoute(OnyxRoute.guards, cancelDemoAutopilot: true),
      evidenceReturnReceipt: _pendingReportsEvidenceReturnReceipt,
      onConsumeEvidenceReturnReceipt:
          _consumePendingReportsEvidenceReturnReceipt,
      onReportShellStateChanged: (value) => _reportShellState = value,
      onRequestPreview: _presentReportPreview,
    );
  }
}
