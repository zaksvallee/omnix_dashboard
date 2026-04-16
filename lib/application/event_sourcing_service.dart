import '../domain/events/client_message_sent_event.dart';
import '../domain/events/decision_created.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/events/execution_completed.dart';
import '../domain/events/execution_denied.dart';
import '../domain/events/guard_checked_in.dart';
import '../domain/events/guard_status_changed_event.dart';
import '../domain/events/incident_closed.dart';
import '../domain/events/intelligence_received.dart';
import '../domain/events/listener_alarm_advisory_recorded.dart';
import '../domain/events/partner_dispatch_status_declared.dart';
import '../domain/events/patrol_completed.dart';
import '../domain/events/response_arrived.dart';
import 'system_flow_service.dart';

enum OnyxEventSemanticType {
  signalDetected,
  incidentApproved,
  officerDispatched,
  clientMessageSent,
  guardStatusChanged,
  incidentClosed,
  systemRecorded,
}

enum OnyxReplaySurface { intel, track, queue, dispatch, comms, guards, shell }

class OnyxEventSemanticRecord {
  final int sequence;
  final String eventId;
  final String auditTypeKey;
  final OnyxEventSemanticType semanticType;
  final String title;
  final String detail;
  final String reference;
  final DateTime occurredAtUtc;

  const OnyxEventSemanticRecord({
    required this.sequence,
    required this.eventId,
    required this.auditTypeKey,
    required this.semanticType,
    required this.title,
    required this.detail,
    required this.reference,
    required this.occurredAtUtc,
  });

  String get semanticLabel {
    return switch (semanticType) {
      OnyxEventSemanticType.signalDetected => 'SignalDetectedEvent',
      OnyxEventSemanticType.incidentApproved => 'IncidentApprovedEvent',
      OnyxEventSemanticType.officerDispatched => 'OfficerDispatchedEvent',
      OnyxEventSemanticType.clientMessageSent => 'ClientMessageSentEvent',
      OnyxEventSemanticType.guardStatusChanged => 'GuardStatusChangedEvent',
      OnyxEventSemanticType.incidentClosed => 'IncidentClosedEvent',
      OnyxEventSemanticType.systemRecorded => 'SystemRecordedEvent',
    };
  }
}

class EventDrivenPageState {
  final int sequence;
  final DateTime occurredAtUtc;
  final OnyxReplaySurface surface;
  final String question;
  final String primaryAnswer;
  final String supportingAnswer;
  final String reference;
  final OnyxGlobalSystemState state;
  final OnyxEventSemanticRecord record;

  const EventDrivenPageState({
    required this.sequence,
    required this.occurredAtUtc,
    required this.surface,
    required this.question,
    required this.primaryAnswer,
    required this.supportingAnswer,
    required this.reference,
    required this.state,
    required this.record,
  });
}

class OnyxEventSourcingSnapshot {
  final int eventCount;
  final int latestSequence;
  final bool live;
  final String deterministicSummary;
  final String latestSemanticLabel;
  final DateTime? latestOccurredAtUtc;
  final OnyxSystemStateSnapshot systemState;
  final OnyxIncidentLifecycleSnapshot lifecycle;
  final OnyxFlowBreadcrumbData shellFlow;
  final List<OnyxEventSemanticRecord> auditTrail;
  final List<EventDrivenPageState> replayFrames;

  const OnyxEventSourcingSnapshot({
    required this.eventCount,
    required this.latestSequence,
    required this.live,
    required this.deterministicSummary,
    required this.latestSemanticLabel,
    required this.latestOccurredAtUtc,
    required this.systemState,
    required this.lifecycle,
    required this.shellFlow,
    required this.auditTrail,
    required this.replayFrames,
  });

  factory OnyxEventSourcingSnapshot.standby() {
    final systemState = OnyxSystemStateService.deriveSnapshot(
      activeIncidentCount: 0,
      aiActionCount: 0,
      guardsOnlineCount: 0,
    );
    final lifecycle = OnyxIncidentLifecycleSnapshot.standby();
    return OnyxEventSourcingSnapshot(
      eventCount: 0,
      latestSequence: 0,
      live: true,
      deterministicSummary:
          'EventStore is live. No auditable operational events are in focus yet.',
      latestSemanticLabel: 'Standby',
      latestOccurredAtUtc: null,
      systemState: systemState,
      lifecycle: lifecycle,
      shellFlow: OnyxFlowIndicatorService.shellFlow(
        snapshot: systemState,
        incidentReference: lifecycle.incidentReference,
      ),
      auditTrail: const <OnyxEventSemanticRecord>[],
      replayFrames: const <EventDrivenPageState>[],
    );
  }
}

abstract final class EventSourcingService {
  static OnyxEventSourcingSnapshot rebuild({
    required List<DispatchEvent> events,
    required int guardsOnlineCount,
    int complianceIssuesCount = 0,
    int tacticalSosAlerts = 0,
  }) {
    final sortedEvents = _sortedEvents(events);
    if (sortedEvents.isEmpty) {
      return OnyxEventSourcingSnapshot.standby();
    }

    final activeIncidentCount = _activeIncidentCount(sortedEvents);
    final aiActionCount = _pendingAiActionCount(sortedEvents);
    final eventDrivenGuardsOnlineCount = _guardsOnlineCountFromEvents(
      sortedEvents,
      referenceTimeUtc: DateTime.now().toUtc(),
    );
    final systemState = OnyxSystemStateService.deriveSnapshot(
      activeIncidentCount: activeIncidentCount,
      aiActionCount: aiActionCount,
      guardsOnlineCount: guardsOnlineCount > eventDrivenGuardsOnlineCount
          ? guardsOnlineCount
          : eventDrivenGuardsOnlineCount,
      complianceIssuesCount: complianceIssuesCount,
      tacticalSosAlerts: tacticalSosAlerts,
      elevatedRiskCount: _elevatedRiskSignalCount(sortedEvents),
      liveAlarmCount: _liveMonitoringAlarmCount(sortedEvents),
    );
    final lifecycle = incidentLifecycleSnapshot(sortedEvents);
    final auditTrail = _semanticAuditTrail(sortedEvents);
    final replayFrames = _replayFrames(
      sortedEvents,
      auditTrail,
      complianceIssuesCount: complianceIssuesCount,
      tacticalSosAlerts: tacticalSosAlerts,
    );
    final latestRecord = auditTrail.isEmpty ? null : auditTrail.last;
    return OnyxEventSourcingSnapshot(
      eventCount: sortedEvents.length,
      latestSequence: sortedEvents.last.sequence,
      live: true,
      deterministicSummary: auditTrail.isEmpty
          ? 'EventStore is live and replayable. Awaiting the next auditable command or signal.'
          : 'EventStore is live and replayable across ${auditTrail.length} semantic checkpoint${auditTrail.length == 1 ? '' : 's'}. Every visible state can be reconstructed from the chain.',
      latestSemanticLabel: latestRecord?.semanticLabel ?? 'Standby',
      latestOccurredAtUtc: latestRecord?.occurredAtUtc,
      systemState: systemState,
      lifecycle: lifecycle,
      shellFlow: OnyxFlowIndicatorService.shellFlow(
        snapshot: systemState,
        incidentReference: lifecycle.incidentReference,
      ),
      auditTrail: auditTrail,
      replayFrames: replayFrames,
    );
  }

  static int activeIncidentCount(List<DispatchEvent> events) {
    return _activeIncidentCount(_sortedEvents(events));
  }

  static int pendingAiActionCount(List<DispatchEvent> events) {
    return _pendingAiActionCount(_sortedEvents(events));
  }

  static int elevatedRiskSignalCount(List<DispatchEvent> events) {
    return _elevatedRiskSignalCount(_sortedEvents(events));
  }

  static int liveMonitoringAlarmCount(List<DispatchEvent> events) {
    return _liveMonitoringAlarmCount(_sortedEvents(events));
  }

  static int guardsOnlineCount(List<DispatchEvent> events) {
    return _guardsOnlineCountFromEvents(
      _sortedEvents(events),
      referenceTimeUtc: DateTime.now().toUtc(),
    );
  }

  static OnyxIncidentLifecycleSnapshot incidentLifecycleSnapshot(
    List<DispatchEvent> events,
  ) {
    final sortedEvents = _sortedEvents(events);
    final decisions = sortedEvents.whereType<DecisionCreated>().toList(
      growable: false,
    )..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    if (decisions.isEmpty) {
      return OnyxIncidentLifecycleSnapshot.standby();
    }

    final closedDispatchIds = sortedEvents
        .whereType<IncidentClosed>()
        .map((event) => event.dispatchId.trim())
        .where((dispatchId) => dispatchId.isNotEmpty)
        .toSet();
    final selectedDecision = decisions.firstWhere(
      (decision) => !closedDispatchIds.contains(decision.dispatchId.trim()),
      orElse: () => decisions.first,
    );
    final dispatchId = selectedDecision.dispatchId.trim();
    final incidentReference = OnyxSystemFlowService.incidentReference(
      dispatchId,
    );
    final dispatchReference = OnyxSystemFlowService.dispatchReference(
      dispatchId,
    );
    final isActive = !closedDispatchIds.contains(dispatchId);

    final lifecycleEntries = <OnyxIncidentLifecycleEntry>[];
    final clientId = selectedDecision.clientId.trim();
    final siteId = selectedDecision.siteId.trim();
    final decisionTime = selectedDecision.occurredAt.toUtc();
    final relatedIntelligence =
        sortedEvents
            .whereType<IntelligenceReceived>()
            .where(
              (event) =>
                  event.clientId.trim() == clientId &&
                  event.siteId.trim() == siteId &&
                  event.occurredAt.toUtc().isAfter(
                    decisionTime.subtract(const Duration(hours: 2)),
                  ) &&
                  event.occurredAt.toUtc().isBefore(
                    decisionTime.add(const Duration(minutes: 20)),
                  ),
            )
            .toList(growable: false)
          ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    for (final intel in relatedIntelligence.take(2)) {
      lifecycleEntries.add(
        OnyxIncidentLifecycleEntry(
          stage: OnyxIncidentLifecycleStage.detection,
          actor: OnyxIncidentLifecycleActor.system,
          title: intel.headline.trim().isEmpty
              ? 'Signal detected for $siteId'
              : intel.headline.trim(),
          detail: intel.summary.trim().isEmpty
              ? 'Risk score ${intel.riskScore}. Zara carried this signal into Track.'
              : intel.summary.trim(),
          occurredAtUtc: intel.occurredAt.toUtc(),
          reference: incidentReference,
        ),
      );
    }

    lifecycleEntries.add(
      OnyxIncidentLifecycleEntry(
        stage: OnyxIncidentLifecycleStage.decision,
        actor: OnyxIncidentLifecycleActor.zara,
        title: 'Queue approved — dispatch created',
        detail:
            'Track verification carried forward into Queue and created $dispatchReference.',
        occurredAtUtc: decisionTime,
        reference: dispatchReference,
      ),
    );

    final matchingEvents =
        sortedEvents
            .where((event) {
              if (event is DecisionCreated) {
                return event.dispatchId.trim() == dispatchId;
              }
              if (event is ExecutionDenied) {
                return event.dispatchId.trim() == dispatchId;
              }
              if (event is ExecutionCompleted) {
                return event.dispatchId.trim() == dispatchId;
              }
              if (event is ResponseArrived) {
                return event.dispatchId.trim() == dispatchId;
              }
              if (event is PartnerDispatchStatusDeclared) {
                return event.dispatchId.trim() == dispatchId;
              }
              if (event is IncidentClosed) {
                return event.dispatchId.trim() == dispatchId;
              }
              if (event is ClientMessageSentEvent) {
                return event.clientId.trim() == clientId &&
                    event.siteId.trim() == siteId &&
                    event.occurredAt.toUtc().isAfter(
                      decisionTime.subtract(const Duration(minutes: 5)),
                    );
              }
              return false;
            })
            .toList(growable: false)
          ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));

    for (final event in matchingEvents) {
      if (event is DecisionCreated) {
        continue;
      }
      if (event is ExecutionDenied) {
        lifecycleEntries.add(
          OnyxIncidentLifecycleEntry(
            stage: OnyxIncidentLifecycleStage.decision,
            actor: OnyxIncidentLifecycleActor.dispatch,
            title: 'Dispatch override denied',
            detail: event.reason.trim().isEmpty
                ? 'Operator held the current response posture.'
                : event.reason.trim(),
            occurredAtUtc: event.occurredAt.toUtc(),
            reference: dispatchReference,
          ),
        );
      } else if (event is PartnerDispatchStatusDeclared) {
        final mapped = switch (event.status) {
          PartnerDispatchStatus.accepted => (
            OnyxIncidentLifecycleStage.dispatch,
            OnyxIncidentLifecycleActor.dispatch,
            'Dispatch accepted — ${event.partnerLabel}',
            'Partner dispatch channel accepted the task from ${event.sourceChannel}.',
          ),
          PartnerDispatchStatus.onSite => (
            OnyxIncidentLifecycleStage.confirmation,
            OnyxIncidentLifecycleActor.officer,
            'Officer on site — ${event.partnerLabel}',
            'Field confirmation came back through ${event.actorLabel}.',
          ),
          PartnerDispatchStatus.allClear => (
            OnyxIncidentLifecycleStage.resolution,
            OnyxIncidentLifecycleActor.officer,
            'All clear declared — ${event.partnerLabel}',
            'Field team signalled that the scene has stabilised.',
          ),
          PartnerDispatchStatus.cancelled => (
            OnyxIncidentLifecycleStage.resolution,
            OnyxIncidentLifecycleActor.dispatch,
            'Dispatch cancelled — ${event.partnerLabel}',
            'Partner flow cancelled the current response chain.',
          ),
          PartnerDispatchStatus.unknown => (
            OnyxIncidentLifecycleStage.confirmation,
            OnyxIncidentLifecycleActor.system,
            'Dispatch status updated',
            'Partner dispatch status changed without a resolved operator label.',
          ),
        };
        lifecycleEntries.add(
          OnyxIncidentLifecycleEntry(
            stage: mapped.$1,
            actor: mapped.$2,
            title: mapped.$3,
            detail: mapped.$4,
            occurredAtUtc: event.occurredAt.toUtc(),
            reference: dispatchReference,
            major: event.status != PartnerDispatchStatus.unknown,
          ),
        );
      } else if (event is ResponseArrived) {
        lifecycleEntries.add(
          OnyxIncidentLifecycleEntry(
            stage: OnyxIncidentLifecycleStage.resolution,
            actor: OnyxIncidentLifecycleActor.officer,
            title: 'Officer arrived on site',
            detail:
                'Response unit ${event.guardId.trim().isEmpty ? 'field unit' : event.guardId.trim()} reached the incident location.',
            occurredAtUtc: event.occurredAt.toUtc(),
            reference: dispatchReference,
          ),
        );
      } else if (event is ExecutionCompleted) {
        lifecycleEntries.add(
          OnyxIncidentLifecycleEntry(
            stage: event.success
                ? OnyxIncidentLifecycleStage.confirmation
                : OnyxIncidentLifecycleStage.resolution,
            actor: OnyxIncidentLifecycleActor.system,
            title: event.success
                ? 'Execution chain completed'
                : 'Execution chain closed with a failure marker',
            detail: event.success
                ? 'System execution completed without breaking the response chain.'
                : 'System execution closed without a successful completion flag.',
            occurredAtUtc: event.occurredAt.toUtc(),
            reference: dispatchReference,
            major: event.success,
          ),
        );
      } else if (event is ClientMessageSentEvent) {
        lifecycleEntries.add(
          OnyxIncidentLifecycleEntry(
            stage: OnyxIncidentLifecycleStage.confirmation,
            actor: OnyxIncidentLifecycleActor.client,
            title: 'Client communication logged',
            detail: event.summary.trim().isEmpty
                ? 'Client communication moved through ${event.channel}.'
                : event.summary.trim(),
            occurredAtUtc: event.occurredAt.toUtc(),
            reference: incidentReference,
            major: false,
          ),
        );
      } else if (event is IncidentClosed) {
        lifecycleEntries.add(
          OnyxIncidentLifecycleEntry(
            stage: OnyxIncidentLifecycleStage.recorded,
            actor: OnyxIncidentLifecycleActor.system,
            title: 'Incident closed — ${event.resolutionType}',
            detail:
                'Ledger sealed and the response record moved into historical truth.',
            occurredAtUtc: event.occurredAt.toUtc(),
            reference: incidentReference,
          ),
        );
      }
    }

    if (lifecycleEntries.isEmpty) {
      return OnyxIncidentLifecycleSnapshot.standby();
    }
    lifecycleEntries.sort((a, b) => a.occurredAtUtc.compareTo(b.occurredAtUtc));
    final summary = isActive
        ? 'Active incident reconstructed from EventStore. Every step in the response chain remains replayable.'
        : 'Resolved incident sealed into the ledger. The chain remains deterministic for review, training, and legal defense.';
    return OnyxIncidentLifecycleSnapshot(
      incidentReference: incidentReference,
      summary: summary,
      active: isActive,
      entries: lifecycleEntries,
    );
  }

  static List<DispatchEvent> _sortedEvents(List<DispatchEvent> events) {
    final sorted = List<DispatchEvent>.from(events);
    sorted.sort(_compareEvents);
    return sorted;
  }

  static int _compareEvents(DispatchEvent left, DispatchEvent right) {
    final timeCompare = left.occurredAt.compareTo(right.occurredAt);
    if (timeCompare != 0) {
      return timeCompare;
    }
    return left.sequence.compareTo(right.sequence);
  }

  static int _activeIncidentCount(List<DispatchEvent> events) {
    final decidedDispatchIds = events
        .whereType<DecisionCreated>()
        .map((event) => event.dispatchId.trim())
        .where((dispatchId) => dispatchId.isNotEmpty)
        .toSet();
    final closedDispatchIds = events
        .whereType<IncidentClosed>()
        .map((event) => event.dispatchId.trim())
        .where((dispatchId) => dispatchId.isNotEmpty)
        .toSet();
    return decidedDispatchIds.difference(closedDispatchIds).length;
  }

  static int _pendingAiActionCount(List<DispatchEvent> events) {
    final decidedDispatchIds = events
        .whereType<DecisionCreated>()
        .map((event) => event.dispatchId.trim())
        .where((dispatchId) => dispatchId.isNotEmpty)
        .toSet();
    final handledDispatchIds = <String>{
      ...events
          .whereType<ExecutionCompleted>()
          .map((event) => event.dispatchId.trim())
          .where((dispatchId) => dispatchId.isNotEmpty),
      ...events
          .whereType<ExecutionDenied>()
          .map((event) => event.dispatchId.trim())
          .where((dispatchId) => dispatchId.isNotEmpty),
      ...events
          .whereType<IncidentClosed>()
          .map((event) => event.dispatchId.trim())
          .where((dispatchId) => dispatchId.isNotEmpty),
    };
    return decidedDispatchIds.difference(handledDispatchIds).length;
  }

  static int _elevatedRiskSignalCount(List<DispatchEvent> events) {
    final windowStartUtc = DateTime.now().toUtc().subtract(
      const Duration(hours: 6),
    );
    return events
        .whereType<IntelligenceReceived>()
        .where(
          (event) =>
              event.occurredAt.toUtc().isAfter(windowStartUtc) &&
              event.riskScore >= 60,
        )
        .length;
  }

  static int _liveMonitoringAlarmCount(List<DispatchEvent> events) {
    final windowStartUtc = DateTime.now().toUtc().subtract(
      const Duration(hours: 4),
    );
    return events
        .whereType<ListenerAlarmAdvisoryRecorded>()
        .where((event) => event.occurredAt.toUtc().isAfter(windowStartUtc))
        .length;
  }

  static int _guardsOnlineCountFromEvents(
    List<DispatchEvent> events, {
    required DateTime referenceTimeUtc,
  }) {
    final windowStartUtc = referenceTimeUtc.subtract(const Duration(hours: 12));
    final guardIds = <String>{
      ...events
          .whereType<GuardCheckedIn>()
          .where((event) => event.occurredAt.toUtc().isAfter(windowStartUtc))
          .map((event) => event.guardId.trim())
          .where((guardId) => guardId.isNotEmpty),
      ...events
          .whereType<ResponseArrived>()
          .where((event) => event.occurredAt.toUtc().isAfter(windowStartUtc))
          .map((event) => event.guardId.trim())
          .where((guardId) => guardId.isNotEmpty),
      ...events
          .whereType<PatrolCompleted>()
          .where((event) => event.occurredAt.toUtc().isAfter(windowStartUtc))
          .map((event) => event.guardId.trim())
          .where((guardId) => guardId.isNotEmpty),
      ...events
          .whereType<GuardStatusChangedEvent>()
          .where((event) => event.occurredAt.toUtc().isAfter(windowStartUtc))
          .where((event) => event.status.trim().toLowerCase() != 'offline')
          .map((event) => event.guardId.trim())
          .where((guardId) => guardId.isNotEmpty),
    };
    return guardIds.length;
  }

  static List<OnyxEventSemanticRecord> _semanticAuditTrail(
    List<DispatchEvent> events,
  ) {
    final records = <OnyxEventSemanticRecord>[];
    for (final event in events) {
      final mapped = _semanticRecordFor(event);
      if (mapped != null) {
        records.add(mapped);
      }
    }
    records.sort((a, b) {
      final timeCompare = a.occurredAtUtc.compareTo(b.occurredAtUtc);
      if (timeCompare != 0) {
        return timeCompare;
      }
      return a.sequence.compareTo(b.sequence);
    });
    return records;
  }

  static OnyxEventSemanticRecord? _semanticRecordFor(DispatchEvent event) {
    switch (event) {
      case IntelligenceReceived():
        return OnyxEventSemanticRecord(
          sequence: event.sequence,
          eventId: event.eventId,
          auditTypeKey: event.toAuditTypeKey(),
          semanticType: OnyxEventSemanticType.signalDetected,
          title: event.headline.trim().isEmpty
              ? 'Signal detected'
              : event.headline.trim(),
          detail: event.summary.trim().isEmpty
              ? 'Risk score ${event.riskScore}.'
              : event.summary.trim(),
          reference: OnyxSystemFlowService.incidentReference(
            event.intelligenceId,
          ),
          occurredAtUtc: event.occurredAt.toUtc(),
        );
      case DecisionCreated():
        return OnyxEventSemanticRecord(
          sequence: event.sequence,
          eventId: event.eventId,
          auditTypeKey: event.toAuditTypeKey(),
          semanticType: OnyxEventSemanticType.incidentApproved,
          title: 'Incident approved in Queue',
          detail:
              'Queue approved the incident and created ${OnyxSystemFlowService.dispatchReference(event.dispatchId)}.',
          reference: OnyxSystemFlowService.dispatchReference(event.dispatchId),
          occurredAtUtc: event.occurredAt.toUtc(),
        );
      case PartnerDispatchStatusDeclared():
        if (event.status == PartnerDispatchStatus.accepted ||
            event.status == PartnerDispatchStatus.onSite) {
          return OnyxEventSemanticRecord(
            sequence: event.sequence,
            eventId: event.eventId,
            auditTypeKey: event.toAuditTypeKey(),
            semanticType: OnyxEventSemanticType.officerDispatched,
            title: event.status == PartnerDispatchStatus.onSite
                ? 'Officer arrived on site'
                : 'Officer dispatched',
            detail: event.status == PartnerDispatchStatus.onSite
                ? '${event.partnerLabel} confirmed on site through ${event.sourceChannel}.'
                : '${event.partnerLabel} accepted the task from ${event.sourceChannel}.',
            reference: OnyxSystemFlowService.dispatchReference(
              event.dispatchId,
            ),
            occurredAtUtc: event.occurredAt.toUtc(),
          );
        }
        return OnyxEventSemanticRecord(
          sequence: event.sequence,
          eventId: event.eventId,
          auditTypeKey: event.toAuditTypeKey(),
          semanticType: OnyxEventSemanticType.systemRecorded,
          title: 'Dispatch partner status updated',
          detail: '${event.partnerLabel} reported ${event.status.name}.',
          reference: OnyxSystemFlowService.dispatchReference(event.dispatchId),
          occurredAtUtc: event.occurredAt.toUtc(),
        );
      case ResponseArrived():
        return OnyxEventSemanticRecord(
          sequence: event.sequence,
          eventId: event.eventId,
          auditTypeKey: event.toAuditTypeKey(),
          semanticType: OnyxEventSemanticType.officerDispatched,
          title: 'Officer arrived on site',
          detail:
              '${event.guardId.trim().isEmpty ? 'Field unit' : event.guardId.trim()} arrived for ${OnyxSystemFlowService.dispatchReference(event.dispatchId)}.',
          reference: OnyxSystemFlowService.dispatchReference(event.dispatchId),
          occurredAtUtc: event.occurredAt.toUtc(),
        );
      case ClientMessageSentEvent():
        return OnyxEventSemanticRecord(
          sequence: event.sequence,
          eventId: event.eventId,
          auditTypeKey: event.toAuditTypeKey(),
          semanticType: OnyxEventSemanticType.clientMessageSent,
          title: 'Client communication recorded',
          detail:
              '${event.author} moved a ${event.channel} message through ${event.provider}.',
          reference: event.messageKey,
          occurredAtUtc: event.occurredAt.toUtc(),
        );
      case GuardStatusChangedEvent():
        return OnyxEventSemanticRecord(
          sequence: event.sequence,
          eventId: event.eventId,
          auditTypeKey: event.toAuditTypeKey(),
          semanticType: OnyxEventSemanticType.guardStatusChanged,
          title: 'Guard status changed',
          detail:
              '${event.guardId} is now ${event.status.toUpperCase()} for ${OnyxSystemFlowService.dispatchReference(event.dispatchId)}.',
          reference: event.assignmentId,
          occurredAtUtc: event.occurredAt.toUtc(),
        );
      case IncidentClosed():
        return OnyxEventSemanticRecord(
          sequence: event.sequence,
          eventId: event.eventId,
          auditTypeKey: event.toAuditTypeKey(),
          semanticType: OnyxEventSemanticType.incidentClosed,
          title: 'Incident sealed',
          detail: 'Resolution type: ${event.resolutionType}.',
          reference: OnyxSystemFlowService.incidentReference(event.dispatchId),
          occurredAtUtc: event.occurredAt.toUtc(),
        );
      case ExecutionCompleted():
        return OnyxEventSemanticRecord(
          sequence: event.sequence,
          eventId: event.eventId,
          auditTypeKey: event.toAuditTypeKey(),
          semanticType: OnyxEventSemanticType.systemRecorded,
          title: event.success
              ? 'Execution chain completed'
              : 'Execution chain failed',
          detail: event.success
              ? 'System execution completed successfully.'
              : 'System execution closed with a failure marker.',
          reference: OnyxSystemFlowService.dispatchReference(event.dispatchId),
          occurredAtUtc: event.occurredAt.toUtc(),
        );
      default:
        return null;
    }
  }

  static List<EventDrivenPageState> _replayFrames(
    List<DispatchEvent> sortedEvents,
    List<OnyxEventSemanticRecord> auditTrail, {
    required int complianceIssuesCount,
    required int tacticalSosAlerts,
  }) {
    if (auditTrail.isEmpty) {
      return const <EventDrivenPageState>[];
    }
    final trail = auditTrail.length <= 10
        ? auditTrail
        : auditTrail.sublist(auditTrail.length - 10);
    final frames = <EventDrivenPageState>[];
    for (final record in trail) {
      final replayEvents = sortedEvents
          .where((event) => event.sequence <= record.sequence)
          .toList(growable: false);
      final replaySystemState = OnyxSystemStateService.deriveSnapshot(
        activeIncidentCount: _activeIncidentCount(replayEvents),
        aiActionCount: _pendingAiActionCount(replayEvents),
        guardsOnlineCount: _guardsOnlineCountFromEvents(
          replayEvents,
          referenceTimeUtc: record.occurredAtUtc,
        ),
        complianceIssuesCount: complianceIssuesCount,
        tacticalSosAlerts: tacticalSosAlerts,
        elevatedRiskCount: _elevatedRiskSignalCount(replayEvents),
        liveAlarmCount: _liveMonitoringAlarmCount(replayEvents),
      );
      final mapped = _pageStateForRecord(record, replaySystemState.state);
      frames.add(mapped);
    }
    return frames;
  }

  static EventDrivenPageState _pageStateForRecord(
    OnyxEventSemanticRecord record,
    OnyxGlobalSystemState state,
  ) {
    switch (record.semanticType) {
      case OnyxEventSemanticType.signalDetected:
        return EventDrivenPageState(
          sequence: record.sequence,
          occurredAtUtc: record.occurredAtUtc,
          surface: OnyxReplaySurface.track,
          question: 'What is happening?',
          primaryAnswer: record.title,
          supportingAnswer:
              '${record.detail} Zara should verify this signal before escalation.',
          reference: record.reference,
          state: state,
          record: record,
        );
      case OnyxEventSemanticType.incidentApproved:
        return EventDrivenPageState(
          sequence: record.sequence,
          occurredAtUtc: record.occurredAtUtc,
          surface: OnyxReplaySurface.queue,
          question: 'What should I do?',
          primaryAnswer: record.title,
          supportingAnswer:
              '${record.detail} Queue converted verification into an actionable response.',
          reference: record.reference,
          state: state,
          record: record,
        );
      case OnyxEventSemanticType.officerDispatched:
        return EventDrivenPageState(
          sequence: record.sequence,
          occurredAtUtc: record.occurredAtUtc,
          surface: OnyxReplaySurface.dispatch,
          question: 'What happened?',
          primaryAnswer: record.title,
          supportingAnswer:
              '${record.detail} Dispatch remains the final narrative of record.',
          reference: record.reference,
          state: state,
          record: record,
        );
      case OnyxEventSemanticType.clientMessageSent:
        return EventDrivenPageState(
          sequence: record.sequence,
          occurredAtUtc: record.occurredAtUtc,
          surface: OnyxReplaySurface.comms,
          question: 'What are we saying?',
          primaryAnswer: record.title,
          supportingAnswer:
              '${record.detail} Client communication is now auditable inside EventStore.',
          reference: record.reference,
          state: state,
          record: record,
        );
      case OnyxEventSemanticType.guardStatusChanged:
        return EventDrivenPageState(
          sequence: record.sequence,
          occurredAtUtc: record.occurredAtUtc,
          surface: OnyxReplaySurface.guards,
          question: 'Who can act?',
          primaryAnswer: record.title,
          supportingAnswer:
              '${record.detail} Workforce readiness is now reconstructable from the event chain.',
          reference: record.reference,
          state: state,
          record: record,
        );
      case OnyxEventSemanticType.incidentClosed:
      case OnyxEventSemanticType.systemRecorded:
        return EventDrivenPageState(
          sequence: record.sequence,
          occurredAtUtc: record.occurredAtUtc,
          surface: OnyxReplaySurface.shell,
          question: 'What changed in the system?',
          primaryAnswer: record.title,
          supportingAnswer:
              '${record.detail} This checkpoint remains replayable from EventStore.',
          reference: record.reference,
          state: state,
          record: record,
        );
    }
  }
}
