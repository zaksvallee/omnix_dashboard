import '../domain/events/decision_created.dart';
import '../domain/events/dispatch_decided_event.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/events/execution_completed.dart';
import '../domain/events/execution_denied.dart';
import '../domain/events/guard_checked_in.dart';
import '../domain/events/incident_closed.dart';
import '../domain/events/intelligence_received.dart';
import '../domain/events/partner_dispatch_status_declared.dart';
import '../domain/events/patrol_completed.dart';
import '../domain/events/report_generated.dart';
import '../domain/events/response_arrived.dart';

class OnyxAgentContextSnapshot {
  final String scopeLabel;
  final String incidentReference;
  final String sourceRouteLabel;
  final int totalScopedEvents;
  final int activeDispatchCount;
  final int dispatchesAwaitingResponseCount;
  final int responseCount;
  final int closedDispatchCount;
  final int patrolCount;
  final int guardCheckInCount;
  final int scopedSiteCount;
  final bool hasVisualSignal;
  final String latestIntelligenceHeadline;
  final String latestIntelligenceSourceType;
  final int? latestIntelligenceRiskScore;
  final String latestPartnerStatusLabel;
  final String latestResponderLabel;
  final String latestEventLabel;
  final DateTime? latestEventAt;
  final DateTime? latestDispatchCreatedAt;
  final DateTime? latestClosureAt;
  final String prioritySiteLabel;
  final String prioritySiteReason;
  final int? prioritySiteRiskScore;
  final List<String> rankedSiteSummaries;
  final int repeatedFalseAlarmCount;
  final bool hasHumanSafetySignal;
  final bool hasGuardWelfareRisk;
  final String guardWelfareSignalLabel;

  const OnyxAgentContextSnapshot({
    required this.scopeLabel,
    required this.incidentReference,
    required this.sourceRouteLabel,
    required this.totalScopedEvents,
    required this.activeDispatchCount,
    required this.dispatchesAwaitingResponseCount,
    required this.responseCount,
    required this.closedDispatchCount,
    required this.patrolCount,
    required this.guardCheckInCount,
    required this.scopedSiteCount,
    required this.hasVisualSignal,
    required this.latestIntelligenceHeadline,
    required this.latestIntelligenceSourceType,
    required this.latestIntelligenceRiskScore,
    required this.latestPartnerStatusLabel,
    required this.latestResponderLabel,
    required this.latestEventLabel,
    required this.latestEventAt,
    required this.latestDispatchCreatedAt,
    required this.latestClosureAt,
    required this.prioritySiteLabel,
    required this.prioritySiteReason,
    required this.prioritySiteRiskScore,
    required this.rankedSiteSummaries,
    required this.repeatedFalseAlarmCount,
    required this.hasHumanSafetySignal,
    required this.hasGuardWelfareRisk,
    required this.guardWelfareSignalLabel,
  });

  const OnyxAgentContextSnapshot.empty({
    this.scopeLabel = 'Global controller scope',
    this.incidentReference = '',
    this.sourceRouteLabel = 'Command',
  }) : totalScopedEvents = 0,
       activeDispatchCount = 0,
       dispatchesAwaitingResponseCount = 0,
       responseCount = 0,
       closedDispatchCount = 0,
       patrolCount = 0,
       guardCheckInCount = 0,
       scopedSiteCount = 0,
       hasVisualSignal = false,
       latestIntelligenceHeadline = '',
       latestIntelligenceSourceType = '',
       latestIntelligenceRiskScore = null,
       latestPartnerStatusLabel = '',
       latestResponderLabel = '',
       latestEventLabel = '',
       latestEventAt = null,
       latestDispatchCreatedAt = null,
       latestClosureAt = null,
       prioritySiteLabel = '',
       prioritySiteReason = '',
       prioritySiteRiskScore = null,
       rankedSiteSummaries = const <String>[],
       repeatedFalseAlarmCount = 0,
       hasHumanSafetySignal = false,
       hasGuardWelfareRisk = false,
       guardWelfareSignalLabel = '';

  bool get hasAnyOperationalSignal {
    return totalScopedEvents > 0 ||
        activeDispatchCount > 0 ||
        responseCount > 0 ||
        patrolCount > 0 ||
        hasVisualSignal ||
        hasHumanSafetySignal ||
        hasGuardWelfareRisk;
  }

  String toReasoningSummary() {
    final parts = <String>[
      'Scope: $scopeLabel.',
      if (incidentReference.trim().isNotEmpty)
        'Incident focus: ${incidentReference.trim()}.',
      'Origin route: ${sourceRouteLabel.trim().isEmpty ? 'Command' : sourceRouteLabel.trim()}.',
      if (!hasAnyOperationalSignal)
        'No scoped operational events are loaded yet.'
      else ...<String>[
        'Scoped events: $totalScopedEvents.',
        'Active dispatches: $activeDispatchCount.',
        'Awaiting response: $dispatchesAwaitingResponseCount.',
        'Responses moving: $responseCount.',
        'Patrol completions: $patrolCount.',
        'Guard check-ins: $guardCheckInCount.',
        'Closed incidents: $closedDispatchCount.',
        if (scopedSiteCount > 1 && prioritySiteLabel.trim().isNotEmpty)
          'Highest-priority site: ${prioritySiteLabel.trim()}'
              '${prioritySiteReason.trim().isEmpty ? '.' : ' because ${prioritySiteReason.trim()}.'}',
        if (rankedSiteSummaries.length > 1)
          'Site priority ladder: ${rankedSiteSummaries.join(' | ')}.',
        if (hasVisualSignal)
          'Latest visual signal: ${latestIntelligenceHeadline.trim().isEmpty ? 'visual intelligence present' : latestIntelligenceHeadline.trim()}'
              '${latestIntelligenceRiskScore == null ? '.' : ' (risk ${latestIntelligenceRiskScore!}).'}',
        if (repeatedFalseAlarmCount > 0)
          'Repeated false-alarm pattern count: $repeatedFalseAlarmCount.',
        if (hasHumanSafetySignal)
          'Human safety signal is active in the scoped context.',
        if (hasGuardWelfareRisk)
          'Guard welfare signal: ${guardWelfareSignalLabel.trim().isEmpty ? 'possible distress pattern detected' : guardWelfareSignalLabel.trim()}.',
        if (latestResponderLabel.trim().isNotEmpty)
          'Latest responder: ${latestResponderLabel.trim()}.',
        if (latestPartnerStatusLabel.trim().isNotEmpty)
          'Latest partner status: ${latestPartnerStatusLabel.trim()}.',
        if (latestEventLabel.trim().isNotEmpty)
          'Latest event: ${latestEventLabel.trim()}.',
      ],
    ];
    return parts.join(' ');
  }
}

abstract class OnyxAgentContextSnapshotService {
  const OnyxAgentContextSnapshotService();

  OnyxAgentContextSnapshot capture({
    required List<DispatchEvent> events,
    String clientId = '',
    String siteId = '',
    String incidentReference = '',
    String sourceRouteLabel = 'Command',
  });
}

class LocalOnyxAgentContextSnapshotService
    implements OnyxAgentContextSnapshotService {
  const LocalOnyxAgentContextSnapshotService();

  @override
  OnyxAgentContextSnapshot capture({
    required List<DispatchEvent> events,
    String clientId = '',
    String siteId = '',
    String incidentReference = '',
    String sourceRouteLabel = 'Command',
  }) {
    final resolvedClientId = clientId.trim();
    final resolvedSiteId = siteId.trim();
    final resolvedIncidentReference = incidentReference.trim();
    final filteredEvents = events
        .where(
          (event) => _matchesScope(
            event,
            clientId: resolvedClientId,
            siteId: resolvedSiteId,
            incidentReference: resolvedIncidentReference,
          ),
        )
        .toList(growable: false);
    if (filteredEvents.isEmpty) {
      return OnyxAgentContextSnapshot.empty(
        scopeLabel: _scopeLabel(resolvedClientId, resolvedSiteId),
        incidentReference: resolvedIncidentReference,
        sourceRouteLabel: sourceRouteLabel,
      );
    }

    final sortedEvents = filteredEvents.toList()
      ..sort((left, right) {
        final sequenceCompare = left.sequence.compareTo(right.sequence);
        if (sequenceCompare != 0) {
          return sequenceCompare;
        }
        return left.occurredAt.compareTo(right.occurredAt);
      });

    final createdDispatchIds = <String>{};
    final closedDispatchIds = <String>{};
    final respondedDispatchIds = <String>{};
    final patrolCount = sortedEvents.whereType<PatrolCompleted>().length;
    final guardCheckInCount = sortedEvents.whereType<GuardCheckedIn>().length;
    final siteAggregates = <String, _SiteSignalAccumulator>{};

    IntelligenceReceived? latestIntelligence;
    ResponseArrived? latestResponse;
    PartnerDispatchStatusDeclared? latestPartnerStatus;
    DispatchEvent? latestEvent;
    DateTime? latestDispatchCreatedAt;
    DateTime? latestClosureAt;
    var hasHumanSafetySignal = false;
    var hasGuardWelfareRisk = false;
    var latestGuardWelfareSignalLabel = '';

    for (final event in sortedEvents) {
      latestEvent = event;
      final siteLabel = _resolvedSiteLabel(event);
      final siteAggregate = siteAggregates.putIfAbsent(
        siteLabel,
        () => _SiteSignalAccumulator(siteLabel: siteLabel),
      );
      siteAggregate.ingest(
        event,
        eventLabel: _eventLabel(event),
        isVisualSignal: _isVisualSignal,
        isHumanSafetySignal: _isHumanSafetySignal,
        isGuardWelfareSignal: _isGuardWelfareSignal,
      );
      if (event is DecisionCreated) {
        createdDispatchIds.add(event.dispatchId.trim());
        latestDispatchCreatedAt = event.occurredAt;
        continue;
      }
      if (event is IncidentClosed) {
        closedDispatchIds.add(event.dispatchId.trim());
        latestClosureAt = event.occurredAt;
        continue;
      }
      if (event is ResponseArrived) {
        respondedDispatchIds.add(event.dispatchId.trim());
        latestResponse = event;
        continue;
      }
      if (event is PartnerDispatchStatusDeclared) {
        latestPartnerStatus = event;
        if (event.status == PartnerDispatchStatus.onSite ||
            event.status == PartnerDispatchStatus.allClear ||
            event.status == PartnerDispatchStatus.cancelled) {
          respondedDispatchIds.add(event.dispatchId.trim());
        }
        continue;
      }
      if (event is IntelligenceReceived) {
        latestIntelligence = event;
        if (_isHumanSafetySignal(event)) {
          hasHumanSafetySignal = true;
        }
        if (_isGuardWelfareSignal(event)) {
          hasGuardWelfareRisk = true;
          latestGuardWelfareSignalLabel = _guardWelfareSignalLabel(event);
        }
      }
    }

    final activeDispatchIds = createdDispatchIds
        .where((dispatchId) => !closedDispatchIds.contains(dispatchId))
        .toSet();
    final awaitingDispatchIds = activeDispatchIds
        .where((dispatchId) => !respondedDispatchIds.contains(dispatchId))
        .toSet();
    final latestResponderLabel = latestResponse?.guardId.trim() ?? '';
    final latestPartnerStatusLabel = latestPartnerStatus == null
        ? ''
        : '${latestPartnerStatus.partnerLabel.trim()} ${latestPartnerStatus.status.name}';
    final prioritizedSite = siteAggregates.values.isEmpty
        ? null
        : (siteAggregates.values.toList()..sort((left, right) {
                final scoreCompare = right.priorityScore.compareTo(
                  left.priorityScore,
                );
                if (scoreCompare != 0) {
                  return scoreCompare;
                }
                final timeCompare =
                    (right.latestEventAt ??
                            DateTime.fromMillisecondsSinceEpoch(0))
                        .compareTo(
                          left.latestEventAt ??
                              DateTime.fromMillisecondsSinceEpoch(0),
                        );
                if (timeCompare != 0) {
                  return timeCompare;
                }
                return left.siteLabel.compareTo(right.siteLabel);
              }))
              .first;
    final rankedSites = siteAggregates.values.toList()
      ..sort((left, right) {
        final scoreCompare = right.priorityScore.compareTo(left.priorityScore);
        if (scoreCompare != 0) {
          return scoreCompare;
        }
        final timeCompare =
            (right.latestEventAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(
                  left.latestEventAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                );
        if (timeCompare != 0) {
          return timeCompare;
        }
        return left.siteLabel.compareTo(right.siteLabel);
      });
    final repeatedFalseAlarmCount =
        _repeatedFalseAlarmCountForLatestIntelligence(
          sortedEvents,
          latestIntelligence,
        );

    return OnyxAgentContextSnapshot(
      scopeLabel: _scopeLabel(resolvedClientId, resolvedSiteId),
      incidentReference: resolvedIncidentReference,
      sourceRouteLabel: sourceRouteLabel,
      totalScopedEvents: sortedEvents.length,
      activeDispatchCount: activeDispatchIds.length,
      dispatchesAwaitingResponseCount: awaitingDispatchIds.length,
      responseCount: respondedDispatchIds.length,
      closedDispatchCount: closedDispatchIds.length,
      patrolCount: patrolCount,
      guardCheckInCount: guardCheckInCount,
      scopedSiteCount: siteAggregates.length,
      hasVisualSignal:
          latestIntelligence != null && _isVisualSignal(latestIntelligence),
      latestIntelligenceHeadline: latestIntelligence?.headline.trim() ?? '',
      latestIntelligenceSourceType: latestIntelligence?.sourceType.trim() ?? '',
      latestIntelligenceRiskScore: latestIntelligence?.riskScore,
      latestPartnerStatusLabel: latestPartnerStatusLabel.trim(),
      latestResponderLabel: latestResponderLabel,
      latestEventLabel: latestEvent == null ? '' : _eventLabel(latestEvent),
      latestEventAt: latestEvent?.occurredAt,
      latestDispatchCreatedAt: latestDispatchCreatedAt,
      latestClosureAt: latestClosureAt,
      prioritySiteLabel: prioritizedSite?.siteLabel ?? '',
      prioritySiteReason: prioritizedSite?.priorityReason ?? '',
      prioritySiteRiskScore: prioritizedSite?.priorityRiskScore,
      rankedSiteSummaries: rankedSites
          .take(3)
          .toList(growable: false)
          .asMap()
          .entries
          .map((entry) => '${entry.key + 1}. ${entry.value.summaryLine}')
          .toList(growable: false),
      repeatedFalseAlarmCount: repeatedFalseAlarmCount,
      hasHumanSafetySignal: hasHumanSafetySignal,
      hasGuardWelfareRisk: hasGuardWelfareRisk,
      guardWelfareSignalLabel: latestGuardWelfareSignalLabel.trim(),
    );
  }

  bool _matchesScope(
    DispatchEvent event, {
    required String clientId,
    required String siteId,
    required String incidentReference,
  }) {
    final hasScope = clientId.isNotEmpty || siteId.isNotEmpty;
    final hasIncident = incidentReference.isNotEmpty;
    if (!hasScope && !hasIncident) {
      return true;
    }

    if (hasScope) {
      final eventClientId = _eventClientId(event);
      final eventSiteId = _eventSiteId(event);
      if (clientId.isNotEmpty && eventClientId != clientId) {
        return false;
      }
      if (siteId.isNotEmpty && eventSiteId != siteId) {
        return false;
      }
    }

    if (!hasIncident) {
      return true;
    }

    final eventDispatchId = _eventDispatchId(event);
    if (eventDispatchId == null || eventDispatchId.isEmpty) {
      return hasScope;
    }
    return eventDispatchId == incidentReference;
  }

  String? _eventClientId(DispatchEvent event) {
    if (event is DecisionCreated) {
      return event.clientId.trim();
    }
    if (event is IntelligenceReceived) {
      return event.clientId.trim();
    }
    if (event is ResponseArrived) {
      return event.clientId.trim();
    }
    if (event is IncidentClosed) {
      return event.clientId.trim();
    }
    if (event is PatrolCompleted) {
      return event.clientId.trim();
    }
    if (event is GuardCheckedIn) {
      return event.clientId.trim();
    }
    if (event is PartnerDispatchStatusDeclared) {
      return event.clientId.trim();
    }
    if (event is ExecutionCompleted) {
      return event.clientId.trim();
    }
    if (event is ExecutionDenied) {
      return event.clientId.trim();
    }
    if (event is ReportGenerated) {
      return event.clientId.trim();
    }
    return null;
  }

  String? _eventSiteId(DispatchEvent event) {
    if (event is DecisionCreated) {
      return event.siteId.trim();
    }
    if (event is IntelligenceReceived) {
      return event.siteId.trim();
    }
    if (event is ResponseArrived) {
      return event.siteId.trim();
    }
    if (event is IncidentClosed) {
      return event.siteId.trim();
    }
    if (event is PatrolCompleted) {
      return event.siteId.trim();
    }
    if (event is GuardCheckedIn) {
      return event.siteId.trim();
    }
    if (event is PartnerDispatchStatusDeclared) {
      return event.siteId.trim();
    }
    if (event is ExecutionCompleted) {
      return event.siteId.trim();
    }
    if (event is ExecutionDenied) {
      return event.siteId.trim();
    }
    if (event is ReportGenerated) {
      return event.siteId.trim();
    }
    return null;
  }

  String? _eventDispatchId(DispatchEvent event) {
    if (event is DecisionCreated) {
      return event.dispatchId.trim();
    }
    if (event is ResponseArrived) {
      return event.dispatchId.trim();
    }
    if (event is IncidentClosed) {
      return event.dispatchId.trim();
    }
    if (event is PartnerDispatchStatusDeclared) {
      return event.dispatchId.trim();
    }
    if (event is ExecutionCompleted) {
      return event.dispatchId.trim();
    }
    if (event is ExecutionDenied) {
      return event.dispatchId.trim();
    }
    if (event is DispatchDecidedEvent) {
      return event.action.dispatchId.trim();
    }
    return null;
  }

  String _resolvedSiteLabel(DispatchEvent event) {
    final siteId = _eventSiteId(event)?.trim() ?? '';
    return siteId.isEmpty ? 'Unscoped site' : siteId;
  }

  bool _isVisualSignal(IntelligenceReceived event) {
    final sourceType = event.sourceType.trim().toLowerCase();
    return event.cameraId?.trim().isNotEmpty == true ||
        event.snapshotUrl?.trim().isNotEmpty == true ||
        event.clipUrl?.trim().isNotEmpty == true ||
        sourceType.contains('camera') ||
        sourceType.contains('cctv') ||
        sourceType.contains('video') ||
        sourceType.contains('vision') ||
        sourceType.contains('visual');
  }

  bool _isHumanSafetySignal(IntelligenceReceived event) {
    final signalText = _signalText(event);
    return signalText.contains('panic') ||
        signalText.contains('duress') ||
        signalText.contains('distress') ||
        signalText.contains('man down') ||
        signalText.contains('sos') ||
        signalText.contains('welfare') ||
        signalText.contains('emergency') ||
        signalText.contains('heart rate spike') ||
        signalText.contains('hr spike');
  }

  bool _isGuardWelfareSignal(IntelligenceReceived event) {
    final signalText = _signalText(event);
    return signalText.contains('wearable') ||
        signalText.contains('telemetry') ||
        signalText.contains('heart rate') ||
        signalText.contains('hr spike') ||
        signalText.contains('no movement') ||
        signalText.contains('inactivity') ||
        signalText.contains('distress') ||
        signalText.contains('man down');
  }

  String _guardWelfareSignalLabel(IntelligenceReceived event) {
    final headline = event.headline.trim();
    if (headline.isNotEmpty) {
      return headline;
    }
    final summary = event.summary.trim();
    if (summary.isNotEmpty) {
      return summary;
    }
    return 'possible guard distress pattern detected';
  }

  int _repeatedFalseAlarmCountForLatestIntelligence(
    List<DispatchEvent> sortedEvents,
    IntelligenceReceived? latestIntelligence,
  ) {
    if (latestIntelligence == null ||
        !_looksLikeFalseAlarmSignal(latestIntelligence)) {
      return 0;
    }
    final patternKey = _falseAlarmPatternKey(latestIntelligence);
    if (patternKey.isEmpty) {
      return 0;
    }
    return sortedEvents
        .whereType<IntelligenceReceived>()
        .where(
          (candidate) =>
              _looksLikeFalseAlarmSignal(candidate) &&
              _falseAlarmPatternKey(candidate) == patternKey,
        )
        .length;
  }

  bool _looksLikeFalseAlarmSignal(IntelligenceReceived event) {
    if (!_isVisualSignal(event) || event.riskScore > 35) {
      return false;
    }
    final signalText = _signalText(event);
    return signalText.contains('tree') ||
        signalText.contains('noise') ||
        signalText.contains('foliage') ||
        signalText.contains('wind') ||
        signalText.contains('animal');
  }

  String _falseAlarmPatternKey(IntelligenceReceived event) {
    final signalText = _signalText(event);
    for (final keyword in const <String>[
      'tree',
      'noise',
      'foliage',
      'wind',
      'animal',
    ]) {
      if (signalText.contains(keyword)) {
        return keyword;
      }
    }
    return '';
  }

  String _signalText(IntelligenceReceived event) {
    final parts = <String>[
      event.sourceType,
      event.headline,
      event.summary,
      event.objectLabel ?? '',
    ];
    return parts.join(' ').trim().toLowerCase();
  }

  String _eventLabel(DispatchEvent event) {
    if (event is IntelligenceReceived) {
      return 'Intelligence received';
    }
    if (event is ResponseArrived) {
      return 'Response arrived';
    }
    if (event is PatrolCompleted) {
      return 'Patrol completed';
    }
    if (event is GuardCheckedIn) {
      return 'Guard checked in';
    }
    if (event is IncidentClosed) {
      return 'Incident closed';
    }
    if (event is PartnerDispatchStatusDeclared) {
      return 'Partner ${event.status.name}';
    }
    if (event is ExecutionCompleted) {
      return event.success ? 'Execution completed' : 'Execution failed';
    }
    if (event is ExecutionDenied) {
      return 'Execution denied';
    }
    if (event is DecisionCreated) {
      return 'Dispatch decision created';
    }
    return event.toAuditTypeKey();
  }
}

class _SiteSignalAccumulator {
  final String siteLabel;
  final Set<String> _createdDispatchIds = <String>{};
  final Set<String> _closedDispatchIds = <String>{};
  final Set<String> _respondedDispatchIds = <String>{};
  var patrolCount = 0;
  var guardCheckInCount = 0;
  var highestVisualRiskScore = 0;
  var highestVisualHeadline = '';
  var hasHumanSafetySignal = false;
  var hasGuardWelfareRisk = false;
  var latestGuardWelfareLabel = '';
  DateTime? latestEventAt;
  String latestEventLabel = '';

  _SiteSignalAccumulator({required this.siteLabel});

  void ingest(
    DispatchEvent event, {
    required String eventLabel,
    required bool Function(IntelligenceReceived event) isVisualSignal,
    required bool Function(IntelligenceReceived event) isHumanSafetySignal,
    required bool Function(IntelligenceReceived event) isGuardWelfareSignal,
  }) {
    latestEventAt = event.occurredAt;
    latestEventLabel = eventLabel;
    if (event is DecisionCreated) {
      _createdDispatchIds.add(event.dispatchId.trim());
      return;
    }
    if (event is IncidentClosed) {
      _closedDispatchIds.add(event.dispatchId.trim());
      return;
    }
    if (event is ResponseArrived) {
      _respondedDispatchIds.add(event.dispatchId.trim());
      return;
    }
    if (event is PartnerDispatchStatusDeclared) {
      if (event.status == PartnerDispatchStatus.onSite ||
          event.status == PartnerDispatchStatus.allClear ||
          event.status == PartnerDispatchStatus.cancelled) {
        _respondedDispatchIds.add(event.dispatchId.trim());
      }
      return;
    }
    if (event is PatrolCompleted) {
      patrolCount += 1;
      return;
    }
    if (event is GuardCheckedIn) {
      guardCheckInCount += 1;
      return;
    }
    if (event is IntelligenceReceived) {
      if (isVisualSignal(event) && event.riskScore >= highestVisualRiskScore) {
        highestVisualRiskScore = event.riskScore;
        highestVisualHeadline = event.headline.trim();
      }
      if (isHumanSafetySignal(event)) {
        hasHumanSafetySignal = true;
      }
      if (isGuardWelfareSignal(event)) {
        hasGuardWelfareRisk = true;
        latestGuardWelfareLabel = event.headline.trim().isEmpty
            ? event.summary.trim()
            : event.headline.trim();
      }
    }
  }

  int get activeDispatchCount => _createdDispatchIds
      .where((id) => !_closedDispatchIds.contains(id))
      .length;

  int get awaitingResponseCount => _createdDispatchIds
      .where(
        (id) =>
            !_closedDispatchIds.contains(id) &&
            !_respondedDispatchIds.contains(id),
      )
      .length;

  int get responseCount => _respondedDispatchIds.length;

  int? get priorityRiskScore =>
      highestVisualRiskScore > 0 ? highestVisualRiskScore : null;

  String get priorityReason {
    if (hasHumanSafetySignal) {
      return 'a live human safety signal';
    }
    if (hasGuardWelfareRisk) {
      return latestGuardWelfareLabel.trim().isEmpty
          ? 'a possible guard distress pattern'
          : latestGuardWelfareLabel.trim();
    }
    if (highestVisualHeadline.trim().isNotEmpty) {
      return priorityRiskScore == null
          ? highestVisualHeadline.trim()
          : '${highestVisualHeadline.trim()} (risk ${priorityRiskScore!})';
    }
    if (awaitingResponseCount > 0) {
      return 'an active dispatch still waiting on response';
    }
    if (activeDispatchCount > 0) {
      return 'an active dispatch';
    }
    if (responseCount > 0) {
      return 'a responder already moving';
    }
    return latestEventLabel.trim().isEmpty
        ? 'scoped activity'
        : latestEventLabel;
  }

  String get summaryLine {
    final reason = priorityReason.trim();
    return reason.isEmpty ? siteLabel : '$siteLabel — $reason';
  }

  double get priorityScore {
    var score = 0.0;
    score += awaitingResponseCount * 6.0;
    score += activeDispatchCount * 4.0;
    score += responseCount * 2.5;
    score += patrolCount * 1.5;
    score += guardCheckInCount * 1.0;
    if (priorityRiskScore != null) {
      score += priorityRiskScore! / 18.0;
    }
    if (hasHumanSafetySignal) {
      score += 7.0;
    }
    if (hasGuardWelfareRisk) {
      score += 5.5;
    }
    if (latestEventLabel == 'Incident closed' && activeDispatchCount == 0) {
      score -= 3.0;
    }
    return score;
  }
}

String _scopeLabel(String clientId, String siteId) {
  if (clientId.isEmpty && siteId.isEmpty) {
    return 'Global controller scope';
  }
  if (clientId.isEmpty) {
    return siteId;
  }
  if (siteId.isEmpty) {
    return '$clientId • all sites';
  }
  return '$clientId • $siteId';
}
