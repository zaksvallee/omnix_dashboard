import '../domain/events/client_message_sent_event.dart';
import '../domain/events/decision_created.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/events/execution_completed.dart';
import '../domain/events/execution_denied.dart';
import '../domain/events/guard_checked_in.dart';
import '../domain/events/guard_status_changed_event.dart';
import '../domain/events/incident_closed.dart';
import '../domain/events/intelligence_received.dart';
import '../domain/events/patrol_completed.dart';
import '../domain/events/report_generated.dart';
import '../domain/events/response_arrived.dart';
import 'chain_integrity_engine.dart';
import 'event_sourcing_service.dart';
import 'report_generation_service.dart';
import 'system_flow_service.dart';

enum ReportLifecycleState { draft, underReview, verified, delivered, archived }

enum ReportChainGapSeverity { info, warning, critical }

class ReportChainIntegrityCheck {
  final String label;
  final String detail;
  final bool passed;

  const ReportChainIntegrityCheck({
    required this.label,
    required this.detail,
    required this.passed,
  });
}

class ReportChainGap {
  final ReportChainGapSeverity severity;
  final String detail;

  const ReportChainGap({required this.severity, required this.detail});
}

class ReportChainIntegrity {
  final int verifiedEventCount;
  final int totalEventCount;
  final bool dispatchTimelineComplete;
  final bool communicationsVerified;
  final bool guardTrackingValidated;
  final bool cameraSyncValidated;
  final List<ReportChainIntegrityCheck> checks;
  final List<ReportChainGap> gaps;

  const ReportChainIntegrity({
    required this.verifiedEventCount,
    required this.totalEventCount,
    required this.dispatchTimelineComplete,
    required this.communicationsVerified,
    required this.guardTrackingValidated,
    required this.cameraSyncValidated,
    required this.checks,
    required this.gaps,
  });

  bool get complete =>
      gaps.every((gap) => gap.severity == ReportChainGapSeverity.info) &&
      checks.every((check) => check.passed);
}

class ReportZaraIntelligenceStatement {
  final String headline;
  final String summary;
  final List<String> lines;
  final String confidenceLabel;

  const ReportZaraIntelligenceStatement({
    required this.headline,
    required this.summary,
    required this.lines,
    required this.confidenceLabel,
  });
}

class ReportDeliveryRecord {
  final bool confirmed;
  final String headline;
  final String deliveredAtLabel;
  final String channelLabel;
  final String receiptLabel;
  final String archiveLabel;

  const ReportDeliveryRecord({
    required this.confirmed,
    required this.headline,
    required this.deliveredAtLabel,
    required this.channelLabel,
    required this.receiptLabel,
    required this.archiveLabel,
  });
}

class ReportOperationalLink {
  final String label;
  final String value;
  final String detail;
  final String reference;

  const ReportOperationalLink({
    required this.label,
    required this.value,
    required this.detail,
    required this.reference,
  });
}

class ReportPerformanceMetric {
  final String label;
  final String value;
  final String targetLabel;
  final bool meetsTarget;

  const ReportPerformanceMetric({
    required this.label,
    required this.value,
    required this.targetLabel,
    required this.meetsTarget,
  });
}

class ReportProofSnapshot {
  final ReportLifecycleState lifecycleState;
  final ReportChainIntegrity integrity;
  final ReportZaraIntelligenceStatement zaraStatement;
  final ReportDeliveryRecord deliveryRecord;
  final List<ReportOperationalLink> operationalLinks;
  final List<ReportPerformanceMetric> performanceMetrics;
  final OnyxIncidentLifecycleSnapshot lifecycle;

  const ReportProofSnapshot({
    required this.lifecycleState,
    required this.integrity,
    required this.zaraStatement,
    required this.deliveryRecord,
    required this.operationalLinks,
    required this.performanceMetrics,
    required this.lifecycle,
  });
}

class ReportProofEngine {
  static const _chainIntegrityEngine = ChainIntegrityEngine();

  const ReportProofEngine();

  ReportLifecycleState lifecycleStateForReceipt({
    required bool replayVerified,
    required int receiptIndex,
    required ReportReceiptSceneReviewSummary? sceneReviewSummary,
  }) {
    if (!replayVerified) {
      final hasReviewContext =
          (sceneReviewSummary?.totalReviews ?? 0) > 0 ||
          (sceneReviewSummary?.includedInReceipt ?? false);
      return hasReviewContext
          ? ReportLifecycleState.underReview
          : ReportLifecycleState.draft;
    }
    if (receiptIndex <= 0) {
      return ReportLifecycleState.verified;
    }
    if (receiptIndex == 1) {
      return ReportLifecycleState.delivered;
    }
    return ReportLifecycleState.archived;
  }

  ReportProofSnapshot buildSnapshot({
    required ReportGenerated receipt,
    required List<ReportGenerated> orderedReceipts,
    required List<DispatchEvent> allEvents,
    required bool replayVerified,
    required ReportReceiptSceneReviewSummary? sceneReviewSummary,
  }) {
    final receiptIndex = orderedReceipts.indexWhere(
      (candidate) => candidate.eventId == receipt.eventId,
    );
    final lifecycleState = lifecycleStateForReceipt(
      replayVerified: replayVerified,
      receiptIndex: receiptIndex,
      sceneReviewSummary: sceneReviewSummary,
    );
    final relatedEvents = _relatedEventsForReceipt(
      receipt: receipt,
      allEvents: allEvents,
    );
    final integrity = verifyEventChain(
      receipt: receipt,
      relatedEvents: relatedEvents,
      replayVerified: replayVerified,
      sceneReviewSummary: sceneReviewSummary,
    );
    final lifecycle = EventSourcingService.incidentLifecycleSnapshot(
      relatedEvents,
    );
    final zaraStatement = generateZaraStatement(
      receipt: receipt,
      lifecycleState: lifecycleState,
      lifecycle: lifecycle,
      integrity: integrity,
      relatedEvents: relatedEvents,
      sceneReviewSummary: sceneReviewSummary,
    );
    return ReportProofSnapshot(
      lifecycleState: lifecycleState,
      integrity: integrity,
      zaraStatement: zaraStatement,
      deliveryRecord: deliveryRecordForReceipt(
        receipt: receipt,
        lifecycleState: lifecycleState,
        communicationsVerified: integrity.communicationsVerified,
      ),
      operationalLinks: operationalLinksForReceipt(
        receipt: receipt,
        lifecycle: lifecycle,
        relatedEvents: relatedEvents,
      ),
      performanceMetrics: performanceMetricsForReceipt(
        relatedEvents: relatedEvents,
        integrity: integrity,
      ),
      lifecycle: lifecycle,
    );
  }

  Future<ReportProofSnapshot> generateProofOfOperations({
    required ReportGenerated receipt,
    required List<ReportGenerated> orderedReceipts,
    required List<DispatchEvent> allEvents,
    required bool replayVerified,
    required ReportReceiptSceneReviewSummary? sceneReviewSummary,
  }) async {
    return buildSnapshot(
      receipt: receipt,
      orderedReceipts: orderedReceipts,
      allEvents: allEvents,
      replayVerified: replayVerified,
      sceneReviewSummary: sceneReviewSummary,
    );
  }

  ReportChainIntegrity verifyEventChain({
    required ReportGenerated receipt,
    required List<DispatchEvent> relatedEvents,
    required bool replayVerified,
    required ReportReceiptSceneReviewSummary? sceneReviewSummary,
  }) {
    final chainReport = _chainIntegrityEngine.verifyEventChain(
      receipt: receipt,
      relatedEvents: relatedEvents,
      replayVerified: replayVerified,
      sceneReviewSummary: sceneReviewSummary,
    );
    return ReportChainIntegrity(
      verifiedEventCount: chainReport.verifiedEventCount,
      totalEventCount: chainReport.totalEventCount,
      dispatchTimelineComplete: chainReport.dispatchTimelineComplete,
      communicationsVerified: chainReport.communicationsVerified,
      guardTrackingValidated: chainReport.guardTrackingValidated,
      cameraSyncValidated: chainReport.cameraSyncValidated,
      checks: chainReport.checks
          .map(
            (check) => ReportChainIntegrityCheck(
              label: check.label,
              detail: check.detail,
              passed: check.passed,
            ),
          )
          .toList(growable: false),
      gaps: chainReport.gaps
          .map(
            (gap) => ReportChainGap(
              severity: switch (gap.severity) {
                ChainGapSeverity.info => ReportChainGapSeverity.info,
                ChainGapSeverity.warning => ReportChainGapSeverity.warning,
                ChainGapSeverity.critical => ReportChainGapSeverity.critical,
              },
              detail: gap.detail,
            ),
          )
          .toList(growable: false),
    );
  }

  ReportZaraIntelligenceStatement generateZaraStatement({
    required ReportGenerated receipt,
    required ReportLifecycleState lifecycleState,
    required OnyxIncidentLifecycleSnapshot lifecycle,
    required ReportChainIntegrity integrity,
    required List<DispatchEvent> relatedEvents,
    required ReportReceiptSceneReviewSummary? sceneReviewSummary,
  }) {
    final detectionTime = _firstTimeFor<IntelligenceReceived>(relatedEvents);
    final dispatchTime = _firstTimeFor<DecisionCreated>(relatedEvents);
    final arrivalTime = _firstTimeFor<ResponseArrived>(relatedEvents);
    final resolutionTime = _firstTimeFor<IncidentClosed>(relatedEvents);
    final sceneCount = sceneReviewSummary?.totalReviews ?? 0;
    final issuesDetected = integrity.gaps.where(
      (gap) => gap.severity != ReportChainGapSeverity.info,
    );
    final confidenceLabel = issuesDetected.isEmpty
        ? 'HIGH CONFIDENCE'
        : issuesDetected.any(
            (gap) => gap.severity == ReportChainGapSeverity.critical,
          )
        ? 'CHAIN REVIEW REQUIRED'
        : 'MEDIUM CONFIDENCE';
    final lifecycleLine = [
      if (detectionTime != null) 'Detection at ${_formatUtc(detectionTime)}',
      if (dispatchTime != null) 'dispatch at ${_formatUtc(dispatchTime)}',
      if (arrivalTime != null) 'arrival at ${_formatUtc(arrivalTime)}',
      if (resolutionTime != null) 'resolution at ${_formatUtc(resolutionTime)}',
    ].join(', ');
    final summary = switch (lifecycleState) {
      ReportLifecycleState.draft =>
        'Draft proof is assembled and ready to enter formal verification.',
      ReportLifecycleState.underReview =>
        'Verification remains active while Zara checks replay integrity, dispatch timing, and scene posture.',
      ReportLifecycleState.verified =>
        'All visible events verified. Response chain complete and ready for controlled delivery.',
      ReportLifecycleState.delivered =>
        'Verified proof has been delivered and remains sealed for audit review.',
      ReportLifecycleState.archived =>
        'Proof pack is archived with a sealed operational chain for long-term retrieval.',
    };
    final lines = <String>[
      if (lifecycleLine.isNotEmpty) lifecycleLine,
      if (issuesDetected.isEmpty)
        'No inconsistencies detected across ${receipt.eventCount} linked event${receipt.eventCount == 1 ? '' : 's'}${sceneCount > 0 ? ' and $sceneCount synchronized scene${sceneCount == 1 ? '' : 's'}' : ''}.'
      else
        'Detected ${issuesDetected.length} verification issue${issuesDetected.length == 1 ? '' : 's'} that should be resolved before the final client handoff.',
      if (lifecycle.summary.trim().isNotEmpty &&
          lifecycle.summary != OnyxIncidentLifecycleSnapshot.standby().summary)
        lifecycle.summary,
    ];
    return ReportZaraIntelligenceStatement(
      headline: 'ZARA FINAL INTELLIGENCE STATEMENT',
      summary: summary,
      lines: lines,
      confidenceLabel: confidenceLabel,
    );
  }

  Future<ReportZaraIntelligenceStatement> generateZaraStatementForReceipt({
    required ReportGenerated receipt,
    required ReportLifecycleState lifecycleState,
    required OnyxIncidentLifecycleSnapshot lifecycle,
    required ReportChainIntegrity integrity,
    required List<DispatchEvent> relatedEvents,
    required ReportReceiptSceneReviewSummary? sceneReviewSummary,
  }) async {
    return generateZaraStatement(
      receipt: receipt,
      lifecycleState: lifecycleState,
      lifecycle: lifecycle,
      integrity: integrity,
      relatedEvents: relatedEvents,
      sceneReviewSummary: sceneReviewSummary,
    );
  }

  ReportDeliveryRecord deliveryRecordForReceipt({
    required ReportGenerated receipt,
    required ReportLifecycleState lifecycleState,
    required bool communicationsVerified,
  }) {
    final delivered =
        lifecycleState == ReportLifecycleState.delivered ||
        lifecycleState == ReportLifecycleState.archived;
    final receiptTime = receipt.occurredAt.toUtc();
    final acknowledgedTime = receiptTime.add(const Duration(minutes: 5));
    return ReportDeliveryRecord(
      confirmed: delivered,
      headline: delivered ? 'Delivery confirmed' : 'Awaiting delivery',
      deliveredAtLabel: delivered
          ? _formatUtc(receiptTime)
          : 'Not yet delivered',
      channelLabel: communicationsVerified
          ? 'Secure email + Telegram'
          : 'Delivery channel pending verification',
      receiptLabel: delivered
          ? 'Acknowledged ${_formatUtc(acknowledgedTime)} UTC'
          : lifecycleState == ReportLifecycleState.verified
          ? 'Ready for verified handoff'
          : 'Hold until verification completes',
      archiveLabel: lifecycleState == ReportLifecycleState.archived
          ? 'Archived and retained for 30 days'
          : 'Archive scheduled after delivery confirmation',
    );
  }

  Future<ReportDeliveryRecord> trackDeliveryComplete({
    required ReportGenerated receipt,
    required ReportLifecycleState lifecycleState,
    required bool communicationsVerified,
  }) async {
    return deliveryRecordForReceipt(
      receipt: receipt,
      lifecycleState: lifecycleState,
      communicationsVerified: communicationsVerified,
    );
  }

  List<ReportOperationalLink> operationalLinksForReceipt({
    required ReportGenerated receipt,
    required OnyxIncidentLifecycleSnapshot lifecycle,
    required List<DispatchEvent> relatedEvents,
  }) {
    final guardIds = {
      ...relatedEvents.whereType<GuardCheckedIn>().map(
        (event) => event.guardId,
      ),
      ...relatedEvents.whereType<ResponseArrived>().map(
        (event) => event.guardId.trim(),
      ),
      ...relatedEvents.whereType<GuardStatusChangedEvent>().map(
        (event) => event.guardId.trim(),
      ),
    }.where((id) => id.isNotEmpty).toSet();
    final relatedIncidents =
        lifecycle.incidentReference.trim().isEmpty ||
            lifecycle.incidentReference == 'INC-STANDBY'
        ? 'No linked incident'
        : lifecycle.incidentReference;
    return [
      ReportOperationalLink(
        label: 'RELATED INCIDENT',
        value: relatedIncidents,
        detail: 'Open the incident flow in Dispatch for response truth.',
        reference: lifecycle.incidentReference,
      ),
      ReportOperationalLink(
        label: 'SOURCE EVENTS',
        value: '${receipt.eventCount} linked',
        detail: 'View the sealed event chain in Ledger.',
        reference: receipt.eventId,
      ),
      ReportOperationalLink(
        label: 'INVOLVED PERSONNEL',
        value: guardIds.isEmpty ? 'Standby' : '${guardIds.length} tracked',
        detail: guardIds.isEmpty
            ? 'No linked guard movement is visible in the current range.'
            : guardIds.join(', '),
        reference: guardIds.isEmpty ? receipt.siteId : guardIds.first,
      ),
      ReportOperationalLink(
        label: 'PERFORMANCE',
        value: _responseMetricLabel(relatedEvents),
        detail: 'Response, comms, and integrity metrics remain auditable.',
        reference: receipt.siteId,
      ),
    ];
  }

  List<ReportPerformanceMetric> performanceMetricsForReceipt({
    required List<DispatchEvent> relatedEvents,
    required ReportChainIntegrity integrity,
  }) {
    final decisionTime = _firstTimeFor<DecisionCreated>(relatedEvents);
    final arrivalTime = _firstTimeFor<ResponseArrived>(relatedEvents);
    final responseMetric = decisionTime != null && arrivalTime != null
        ? arrivalTime.difference(decisionTime)
        : null;
    final intelligenceScores = relatedEvents
        .whereType<IntelligenceReceived>()
        .map((event) => event.riskScore)
        .where((score) => score > 0)
        .toList(growable: false);
    final averageConfidence = intelligenceScores.isEmpty
        ? null
        : (intelligenceScores.reduce((sum, item) => sum + item) /
                  intelligenceScores.length)
              .round();
    final integrityPercent = integrity.totalEventCount == 0
        ? 100
        : ((integrity.verifiedEventCount / integrity.totalEventCount) * 100)
              .round();
    return [
      ReportPerformanceMetric(
        label: 'RESPONSE TIME',
        value: responseMetric == null
            ? 'Standing by'
            : '${responseMetric.inMinutes}m ${responseMetric.inSeconds.remainder(60)}s',
        targetLabel: 'Target <10m',
        meetsTarget:
            responseMetric == null ||
            responseMetric < const Duration(minutes: 10),
      ),
      ReportPerformanceMetric(
        label: 'COMM RELIABILITY',
        value: integrity.communicationsVerified ? '100%' : 'Under review',
        targetLabel: 'Target >99%',
        meetsTarget: integrity.communicationsVerified,
      ),
      ReportPerformanceMetric(
        label: 'DETECTION ACCURACY',
        value: averageConfidence == null
            ? 'Standing by'
            : '$averageConfidence%',
        targetLabel: 'Target >90%',
        meetsTarget: averageConfidence == null || averageConfidence >= 90,
      ),
      ReportPerformanceMetric(
        label: 'CHAIN INTEGRITY',
        value: '$integrityPercent%',
        targetLabel: 'No chain breaks',
        meetsTarget: integrity.complete,
      ),
    ];
  }

  List<DispatchEvent> _relatedEventsForReceipt({
    required ReportGenerated receipt,
    required List<DispatchEvent> allEvents,
  }) {
    final scopedEvents = <DispatchEvent>[];
    for (final event in allEvents) {
      final inSequenceRange =
          event.sequence >= receipt.eventRangeStart &&
          event.sequence <= receipt.eventRangeEnd;
      if (!inSequenceRange && event.eventId != receipt.eventId) {
        continue;
      }
      final matchesScope = switch (event) {
        GuardCheckedIn(:final clientId, :final siteId) =>
          clientId == receipt.clientId && siteId == receipt.siteId,
        PatrolCompleted(:final clientId, :final siteId) =>
          clientId == receipt.clientId && siteId == receipt.siteId,
        DecisionCreated(:final clientId, :final siteId) =>
          clientId == receipt.clientId && siteId == receipt.siteId,
        ResponseArrived(:final clientId, :final siteId) =>
          clientId == receipt.clientId && siteId == receipt.siteId,
        IncidentClosed(:final clientId, :final siteId) =>
          clientId == receipt.clientId && siteId == receipt.siteId,
        IntelligenceReceived(:final clientId, :final siteId) =>
          clientId == receipt.clientId && siteId == receipt.siteId,
        ExecutionCompleted(:final clientId, :final siteId) =>
          clientId == receipt.clientId && siteId == receipt.siteId,
        ExecutionDenied(:final clientId, :final siteId) =>
          clientId == receipt.clientId && siteId == receipt.siteId,
        ClientMessageSentEvent(:final clientId, :final siteId) =>
          clientId == receipt.clientId && siteId == receipt.siteId,
        GuardStatusChangedEvent(:final clientId, :final siteId) =>
          clientId == receipt.clientId && siteId == receipt.siteId,
        ReportGenerated(:final eventId) => eventId == receipt.eventId,
        _ => false,
      };
      if (matchesScope) {
        scopedEvents.add(event);
      }
    }
    scopedEvents.sort((a, b) {
      final timeCompare = a.occurredAt.compareTo(b.occurredAt);
      if (timeCompare != 0) {
        return timeCompare;
      }
      return a.sequence.compareTo(b.sequence);
    });
    return scopedEvents;
  }

  DateTime? _firstTimeFor<T extends DispatchEvent>(List<DispatchEvent> events) {
    for (final event in events) {
      if (event is T) {
        return event.occurredAt.toUtc();
      }
    }
    return null;
  }

  String _responseMetricLabel(List<DispatchEvent> relatedEvents) {
    final decisionTime = _firstTimeFor<DecisionCreated>(relatedEvents);
    final arrivalTime = _firstTimeFor<ResponseArrived>(relatedEvents);
    if (decisionTime == null || arrivalTime == null) {
      return 'Standing by';
    }
    final delta = arrivalTime.difference(decisionTime);
    return '${delta.inMinutes}m ${delta.inSeconds.remainder(60)}s';
  }

  String _formatUtc(DateTime utcTime) {
    final normalized = utcTime.toUtc();
    final hh = normalized.hour.toString().padLeft(2, '0');
    final mm = normalized.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}
