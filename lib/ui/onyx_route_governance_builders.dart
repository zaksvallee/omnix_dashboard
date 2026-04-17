part of '../main.dart';

extension _OnyxRouteGovernanceBuilders on _OnyxAppState {
  Widget _buildGovernanceRoute(List<DispatchEvent> events) {
    final focusedGovernanceReport =
        _morningSovereignReportForDate(_governanceReportFocusDate) ??
        _morningSovereignReport;
    return GovernancePage(
      events: events,
      sceneReviewByIntelligenceId: _monitoringSceneReviewByIntelligenceId,
      morningSovereignReport: focusedGovernanceReport,
      morningSovereignReportHistory: _governanceHistoryForFocusedReport(
        focusedGovernanceReport,
      ),
      morningSovereignReportAutoRunKey: _morningSovereignReportAutoRunKey,
      currentMorningSovereignReportDate: _morningSovereignReport?.date,
      initialReportFocusDate: _governanceReportFocusDate.trim().isEmpty
          ? null
          : _governanceReportFocusDate,
      initialScopeClientId: _governanceScopeClientId.trim().isEmpty
          ? null
          : _governanceScopeClientId,
      initialScopeSiteId: _governanceScopeSiteId.trim().isEmpty
          ? null
          : _governanceScopeSiteId,
      initialPartnerScopeClientId:
          _governancePartnerScopeClientId.trim().isEmpty
          ? null
          : _governancePartnerScopeClientId,
      initialPartnerScopeSiteId: _governancePartnerScopeSiteId.trim().isEmpty
          ? null
          : _governancePartnerScopeSiteId,
      initialPartnerScopePartnerLabel:
          _governancePartnerScopePartnerLabel.trim().isEmpty
          ? null
          : _governancePartnerScopePartnerLabel,
      onMorningSovereignReportChanged: _handleMorningSovereignReportChanged,
      onOpenVehicleExceptionEvent: _openEventsForEventId,
      onOpenReceiptPolicyEvent: _openEventsForEventId,
      onOpenReportsForReceiptEvent: _openReportsForReceiptEvent,
      onOpenVehicleExceptionVisit: _openEventsForVehicleVisit,
      onOpenReportsForScope: _openReportsForScope,
      onOpenEventsForScope: (eventIds, selectedEventId, {originLabel = ''}) {
        _openEventsForScopedEventIds(
          eventIds,
          selectedEventId: selectedEventId,
          scopeMode: 'shadow',
          routeSource: ZaraEventsRouteSource.governance,
          originLabel: originLabel,
        );
      },
      onOpenLedgerForScope: _openLedgerForScope,
      initialSceneActionFocus: _governanceSceneActionFocus,
      onSceneActionFocusChanged: (value) {
        _applyRouteBuilderState(() {
          _governanceSceneActionFocus = value;
        });
      },
      onGenerateMorningSovereignReport: () async {
        await _generateMorningSovereignReport();
      },
      onOpenReportsForPartnerScope: _openReportsForPartnerScope,
      operationalFeedsLoader: () =>
          _loadGovernanceOperationalFeeds(events: events),
    );
  }

  Future<GovernanceOperationalFeeds> _loadGovernanceOperationalFeeds({
    required List<DispatchEvent> events,
  }) async {
    final scope = _effectiveGovernanceOperationalScope();
    final scopeClientId = scope.clientId;
    final scopeSiteId = scope.siteId;
    final nowUtc = DateTime.now().toUtc();
    final persistence = await _persistenceServiceFuture;
    final guardSyncRepository = SharedPrefsGuardSyncRepository(persistence);

    final assignmentsFuture = guardSyncRepository.readAssignments();
    final guardOperationsFuture = persistence.readGuardSyncOperations();
    final directoryFuture = _loadGovernanceAdminDirectorySnapshot();

    final assignments = await assignmentsFuture;
    final guardOperations = await guardOperationsFuture;
    final directory = await directoryFuture;

    final compliance = directory == null
        ? null
        : _buildGovernanceComplianceFeeds(
            directory: directory,
            assignments: assignments,
            scopeClientId: scopeClientId,
            scopeSiteId: scopeSiteId,
            nowUtc: nowUtc,
          );
    final vigilance = _buildGovernanceVigilanceFeed(
      events: events,
      scopeClientId: scopeClientId,
      scopeSiteId: scopeSiteId,
    );
    final fleet = _buildGovernanceFleetStatusFeed(
      assignments: assignments,
      operations: guardOperations,
      scopeClientId: scopeClientId,
      scopeSiteId: scopeSiteId,
    );

    return GovernanceOperationalFeeds(
      complianceAvailable: compliance != null,
      compliance: compliance ?? const <GovernanceComplianceIssueFeed>[],
      vigilance: vigilance,
      fleet: fleet,
    );
  }

  ({String? clientId, String? siteId}) _effectiveGovernanceOperationalScope() {
    final partnerClientId = _governancePartnerScopeClientId.trim();
    final partnerSiteId = _governancePartnerScopeSiteId.trim();
    if (partnerClientId.isNotEmpty && partnerSiteId.isNotEmpty) {
      return (clientId: partnerClientId, siteId: partnerSiteId);
    }
    final governanceClientId = _governanceScopeClientId.trim();
    if (governanceClientId.isNotEmpty) {
      final governanceSiteId = _governanceScopeSiteId.trim();
      return (
        clientId: governanceClientId,
        siteId: governanceSiteId.isEmpty ? null : governanceSiteId,
      );
    }
    final selectedClientId = _selectedClient.trim();
    final selectedSiteId = _selectedSite.trim();
    return (
      clientId: selectedClientId.isEmpty ? null : selectedClientId,
      siteId: selectedSiteId.isEmpty ? null : selectedSiteId,
    );
  }

  Future<AdminDirectorySnapshot?>
  _loadGovernanceAdminDirectorySnapshot() async {
    if (!widget.supabaseReady) {
      return null;
    }
    try {
      return const AdminDirectoryService().loadDirectory(
        supabase: Supabase.instance.client,
      );
    } catch (error) {
      debugPrint(
        'Governance operational feeds could not load admin directory data: '
        '$error',
      );
      return null;
    }
  }

  List<GovernanceComplianceIssueFeed> _buildGovernanceComplianceFeeds({
    required AdminDirectorySnapshot directory,
    required List<GuardAssignment> assignments,
    required String? scopeClientId,
    required String? scopeSiteId,
    required DateTime nowUtc,
  }) {
    final scopedSiteIds = _governanceScopedSiteIds(
      directory: directory,
      scopeClientId: scopeClientId,
      scopeSiteId: scopeSiteId,
    );
    if (scopeClientId != null && scopedSiteIds.isEmpty) {
      return const <GovernanceComplianceIssueFeed>[];
    }
    final activeGuardIds = assignments
        .where(
          (assignment) => _governanceScopeMatches(
            rowClientId: assignment.clientId,
            rowSiteId: assignment.siteId,
            scopeClientId: scopeClientId,
            scopeSiteId: scopeSiteId,
          ),
        )
        .where(
          (assignment) =>
              assignment.status != GuardDutyStatus.clear &&
              assignment.status != GuardDutyStatus.offline,
        )
        .map((assignment) => assignment.guardId.trim())
        .where((guardId) => guardId.isNotEmpty)
        .toSet();

    final nowDateUtc = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
    final issues = <GovernanceComplianceIssueFeed>[];
    for (final guard in directory.guards) {
      final assignedSiteId = guard.assignedSite.trim();
      if (scopedSiteIds.isNotEmpty && !scopedSiteIds.contains(assignedSiteId)) {
        continue;
      }
      final psiraExpiry = _parseGovernanceDirectoryDate(guard.psiraExpiry);
      if (psiraExpiry == null) {
        continue;
      }
      final daysRemaining = psiraExpiry.difference(nowDateUtc).inDays;
      if (daysRemaining > 30) {
        continue;
      }
      final guardIdentifiers = <String>{
        guard.id.trim(),
        guard.employeeId.trim(),
      }..removeWhere((value) => value.isEmpty);
      issues.add(
        GovernanceComplianceIssueFeed(
          type: 'PSIRA',
          employeeName: guard.name,
          employeeId: guard.employeeId.trim().isEmpty
              ? guard.id.trim()
              : guard.employeeId.trim(),
          expiryDate: psiraExpiry,
          daysRemaining: daysRemaining,
          blockingDispatch: guardIdentifiers.any(activeGuardIds.contains),
        ),
      );
    }
    issues.sort((left, right) {
      if (left.blockingDispatch != right.blockingDispatch) {
        return left.blockingDispatch ? -1 : 1;
      }
      final daysCompare = left.daysRemaining.compareTo(right.daysRemaining);
      if (daysCompare != 0) {
        return daysCompare;
      }
      return left.employeeName.compareTo(right.employeeName);
    });
    return List<GovernanceComplianceIssueFeed>.unmodifiable(issues);
  }

  GovernanceVigilanceFeed? _buildGovernanceVigilanceFeed({
    required List<DispatchEvent> events,
    required String? scopeClientId,
    required String? scopeSiteId,
  }) {
    final scopedRuntimes = _monitoringWatchByScope.entries
        .where(
          (entry) => _governanceMonitoringScopeMatches(
            scopeKey: entry.key,
            scopeClientId: scopeClientId,
            scopeSiteId: scopeSiteId,
          ),
        )
        .map((entry) => entry.value)
        .toList(growable: false);
    if (scopedRuntimes.isEmpty) {
      return null;
    }

    final availableScopeCount = scopedRuntimes
        .where((runtime) => runtime.monitoringAvailable)
        .length;
    final degradedScopeCount = scopedRuntimes.length - availableScopeCount;
    final alertCount = scopedRuntimes.fold<int>(
      0,
      (sum, runtime) => sum + runtime.alertCount,
    );
    final escalationCount = scopedRuntimes.fold<int>(
      0,
      (sum, runtime) => sum + runtime.escalationCount,
    );
    final unresolvedActionCount = scopedRuntimes.fold<int>(
      0,
      (sum, runtime) => sum + runtime.unresolvedActionCount,
    );
    final availabilityDetails = scopedRuntimes
        .map((runtime) => runtime.monitoringAvailabilityDetail.trim())
        .where((detail) => detail.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final operationsHealth = OperationsHealthProjection.build(events);
    final scopedHealthSites = operationsHealth.sites
        .where(
          (site) => _governanceScopeMatches(
            rowClientId: site.clientId,
            rowSiteId: site.siteId,
            scopeClientId: scopeClientId,
            scopeSiteId: scopeSiteId,
          ),
        )
        .where((site) => site.averageResponseMinutes > 0)
        .toList(growable: false);
    final averageResponseMinutes = scopedHealthSites.isEmpty
        ? 0.0
        : scopedHealthSites
                  .map((site) => site.averageResponseMinutes)
                  .reduce((left, right) => left + right) /
              scopedHealthSites.length;
    final availabilityDetail = availabilityDetails.isNotEmpty
        ? availabilityDetails.join(' • ')
        : degradedScopeCount > 0
        ? '$availableScopeCount of ${scopedRuntimes.length} monitored scopes are live.'
        : 'All monitored scopes are live.';

    return GovernanceVigilanceFeed(
      monitoredScopeCount: scopedRuntimes.length,
      availableScopeCount: availableScopeCount,
      degradedScopeCount: degradedScopeCount,
      alertCount: alertCount,
      escalationCount: escalationCount,
      unresolvedActionCount: unresolvedActionCount,
      averageResponseMinutes: averageResponseMinutes,
      availabilityDetail: availabilityDetail,
    );
  }

  GovernanceFleetStatusFeed? _buildGovernanceFleetStatusFeed({
    required List<GuardAssignment> assignments,
    required List<GuardSyncOperation> operations,
    required String? scopeClientId,
    required String? scopeSiteId,
  }) {
    final scopedAssignments = assignments
        .where(
          (assignment) => _governanceScopeMatches(
            rowClientId: assignment.clientId,
            rowSiteId: assignment.siteId,
            scopeClientId: scopeClientId,
            scopeSiteId: scopeSiteId,
          ),
        )
        .toList(growable: false);
    final activeAssignments = scopedAssignments
        .where(
          (assignment) =>
              assignment.status != GuardDutyStatus.clear &&
              assignment.status != GuardDutyStatus.offline,
        )
        .toList(growable: false);
    final scopedOperations = operations
        .where(
          (operation) => _governanceOperationScopeMatches(
            operation: operation,
            scopeClientId: scopeClientId,
            scopeSiteId: scopeSiteId,
          ),
        )
        .toList(growable: false);
    if (scopedAssignments.isEmpty && scopedOperations.isEmpty) {
      return null;
    }
    return GovernanceFleetStatusFeed(
      activeOfficerCount: activeAssignments
          .map((assignment) => assignment.guardId.trim())
          .where((guardId) => guardId.isNotEmpty)
          .toSet()
          .length,
      activeAssignmentCount: activeAssignments.length,
      dispatchQueueDepth: scopedOperations
          .where(
            (operation) => operation.status == GuardSyncOperationStatus.queued,
          )
          .length,
      failedOperationCount: scopedOperations
          .where(
            (operation) => operation.status == GuardSyncOperationStatus.failed,
          )
          .length,
    );
  }

  Set<String> _governanceScopedSiteIds({
    required AdminDirectorySnapshot directory,
    required String? scopeClientId,
    required String? scopeSiteId,
  }) {
    if (scopeSiteId != null && scopeSiteId.trim().isNotEmpty) {
      return <String>{scopeSiteId.trim()};
    }
    if (scopeClientId == null || scopeClientId.trim().isEmpty) {
      return directory.sites
          .map((site) => site.id.trim())
          .where((siteId) => siteId.isNotEmpty)
          .toSet();
    }
    return directory.sites
        .where((site) => site.clientId.trim() == scopeClientId.trim())
        .map((site) => site.id.trim())
        .where((siteId) => siteId.isNotEmpty)
        .toSet();
  }

  bool _governanceScopeMatches({
    required String rowClientId,
    required String rowSiteId,
    required String? scopeClientId,
    required String? scopeSiteId,
  }) {
    if (scopeClientId == null || scopeClientId.trim().isEmpty) {
      return true;
    }
    if (rowClientId.trim() != scopeClientId.trim()) {
      return false;
    }
    if (scopeSiteId == null || scopeSiteId.trim().isEmpty) {
      return true;
    }
    return rowSiteId.trim() == scopeSiteId.trim();
  }

  bool _governanceMonitoringScopeMatches({
    required String scopeKey,
    required String? scopeClientId,
    required String? scopeSiteId,
  }) {
    final parts = scopeKey.split('|');
    if (parts.length != 2) {
      return false;
    }
    return _governanceScopeMatches(
      rowClientId: parts[0],
      rowSiteId: parts[1],
      scopeClientId: scopeClientId,
      scopeSiteId: scopeSiteId,
    );
  }

  bool _governanceOperationScopeMatches({
    required GuardSyncOperation operation,
    required String? scopeClientId,
    required String? scopeSiteId,
  }) {
    final payload = operation.payload;
    final clientId = (payload['client_id'] ?? payload['clientId'] ?? '')
        .toString()
        .trim();
    final siteId = (payload['site_id'] ?? payload['siteId'] ?? '')
        .toString()
        .trim();
    if (clientId.isEmpty || siteId.isEmpty) {
      return false;
    }
    return _governanceScopeMatches(
      rowClientId: clientId,
      rowSiteId: siteId,
      scopeClientId: scopeClientId,
      scopeSiteId: scopeSiteId,
    );
  }

  DateTime? _parseGovernanceDirectoryDate(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty || value == '-') {
      return null;
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return null;
    }
    return DateTime.utc(parsed.year, parsed.month, parsed.day);
  }
}
