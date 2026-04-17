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
import 'report_generation_service.dart';

enum ChainGapSeverity { info, warning, critical }

class ChainIntegrityCheck {
  final String label;
  final String detail;
  final bool passed;

  const ChainIntegrityCheck({
    required this.label,
    required this.detail,
    required this.passed,
  });
}

class ChainGap {
  final ChainGapSeverity severity;
  final String detail;

  const ChainGap({required this.severity, required this.detail});
}

class ChainIntegrityReport {
  final int verifiedEventCount;
  final int totalEventCount;
  final bool dispatchTimelineComplete;
  final bool communicationsVerified;
  final bool guardTrackingValidated;
  final bool cameraSyncValidated;
  final List<ChainIntegrityCheck> checks;
  final List<ChainGap> gaps;

  const ChainIntegrityReport({
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
      gaps.every((gap) => gap.severity == ChainGapSeverity.info) &&
      checks.every((check) => check.passed);
}

class ChainIntegrityEngine {
  const ChainIntegrityEngine();

  ChainIntegrityReport verifyEventChain({
    required ReportGenerated receipt,
    required List<DispatchEvent> relatedEvents,
    required bool replayVerified,
    required ReportReceiptSceneReviewSummary? sceneReviewSummary,
  }) {
    final timelineEvents = relatedEvents.where(
      (event) =>
          event is DecisionCreated ||
          event is ResponseArrived ||
          event is IncidentClosed ||
          event is ExecutionCompleted ||
          event is ExecutionDenied,
    );
    final commEvents = relatedEvents.whereType<ClientMessageSentEvent>();
    final guardEvents = relatedEvents.where(
      (event) =>
          event is GuardCheckedIn ||
          event is PatrolCompleted ||
          event is GuardStatusChangedEvent ||
          event is ResponseArrived,
    );
    final intelligenceEvents = relatedEvents.whereType<IntelligenceReceived>();
    final cameraSyncValidated =
        (sceneReviewSummary?.includedInReceipt ?? false) ||
        (sceneReviewSummary?.totalReviews ?? 0) == 0 ||
        intelligenceEvents.any(
          (event) =>
              (event.snapshotUrl ?? '').trim().isNotEmpty ||
              (event.clipUrl ?? '').trim().isNotEmpty ||
              (event.evidenceRecordHash ?? '').trim().isNotEmpty,
        );
    final dispatchTimelineComplete =
        timelineEvents.isNotEmpty && receipt.includeTimeline;
    final communicationsVerified =
        commEvents.isNotEmpty || !receipt.includeDispatchSummary;
    final guardTrackingValidated =
        guardEvents.isNotEmpty || !receipt.includeGuardMetrics;
    final checks = <ChainIntegrityCheck>[
      ChainIntegrityCheck(
        label: 'Event chain',
        detail:
            '${receipt.eventCount}/${receipt.eventCount} events sealed and timestamped',
        passed: replayVerified,
      ),
      ChainIntegrityCheck(
        label: 'Dispatch timeline',
        detail: dispatchTimelineComplete
            ? 'Dispatch timeline complete with no visible gaps'
            : 'Dispatch timeline is incomplete or omitted from the proof pack',
        passed: dispatchTimelineComplete,
      ),
      ChainIntegrityCheck(
        label: 'Client communications',
        detail: communicationsVerified
            ? 'Client communications verified against the event chain'
            : 'Client communications could not be fully verified from the chain',
        passed: communicationsVerified,
      ),
      ChainIntegrityCheck(
        label: 'Guard GPS tracking',
        detail: guardTrackingValidated
            ? 'Guard tracking and response movement validated'
            : 'Guard movement evidence is still incomplete for this receipt',
        passed: guardTrackingValidated,
      ),
      ChainIntegrityCheck(
        label: 'Camera synchronization',
        detail: cameraSyncValidated
            ? 'Camera footage and scene review remain synchronized'
            : 'Camera verification is missing from the visible proof range',
        passed: cameraSyncValidated,
      ),
    ];
    final gaps = <ChainGap>[
      if (!replayVerified)
        const ChainGap(
          severity: ChainGapSeverity.critical,
          detail: 'Replay hash verification is still pending.',
        ),
      if (!dispatchTimelineComplete)
        const ChainGap(
          severity: ChainGapSeverity.warning,
          detail: 'Dispatch timeline is missing or incomplete for this report.',
        ),
      if (!communicationsVerified)
        const ChainGap(
          severity: ChainGapSeverity.warning,
          detail:
              'Client communication verification has not yet closed cleanly.',
        ),
      if (!guardTrackingValidated)
        const ChainGap(
          severity: ChainGapSeverity.warning,
          detail: 'Guard GPS tracking evidence is incomplete.',
        ),
      if (!cameraSyncValidated)
        const ChainGap(
          severity: ChainGapSeverity.warning,
          detail: 'Camera footage synchronization is still missing.',
        ),
      if ((sceneReviewSummary?.suppressedActions ?? 0) > 0)
        ChainGap(
          severity: ChainGapSeverity.info,
          detail:
              '${sceneReviewSummary!.suppressedActions} suppressed scene action${sceneReviewSummary.suppressedActions == 1 ? '' : 's'} remain visible for operator review.',
        ),
    ];
    final totalChecks = checks.length;
    final passedChecks = checks.where((check) => check.passed).length;
    final verifiedEventCount = totalChecks == 0
        ? receipt.eventCount
        : ((receipt.eventCount * passedChecks) / totalChecks).round();
    return ChainIntegrityReport(
      verifiedEventCount: verifiedEventCount.clamp(0, receipt.eventCount),
      totalEventCount: receipt.eventCount,
      dispatchTimelineComplete: dispatchTimelineComplete,
      communicationsVerified: communicationsVerified,
      guardTrackingValidated: guardTrackingValidated,
      cameraSyncValidated: cameraSyncValidated,
      checks: checks,
      gaps: gaps,
    );
  }

  List<ChainGap> detectChainGaps({
    required ReportGenerated receipt,
    required List<DispatchEvent> relatedEvents,
    required bool replayVerified,
    required ReportReceiptSceneReviewSummary? sceneReviewSummary,
  }) {
    final report = verifyEventChain(
      receipt: receipt,
      relatedEvents: relatedEvents,
      replayVerified: replayVerified,
      sceneReviewSummary: sceneReviewSummary,
    );
    return report.gaps;
  }

  bool validateEventSequence(List<DispatchEvent> events) {
    if (events.isEmpty) {
      return true;
    }
    final sorted = [...events]
      ..sort((left, right) {
        final timeCompare = left.occurredAt.compareTo(right.occurredAt);
        if (timeCompare != 0) {
          return timeCompare;
        }
        return left.sequence.compareTo(right.sequence);
      });
    for (var index = 1; index < sorted.length; index++) {
      final previous = sorted[index - 1];
      final current = sorted[index];
      if (current.sequence != 0 &&
          previous.sequence != 0 &&
          current.sequence < previous.sequence) {
        return false;
      }
      if (current.occurredAt.isBefore(previous.occurredAt) &&
          current.sequence == previous.sequence) {
        return false;
      }
    }
    return true;
  }

  Future<ChainIntegrityReport> verifyEventChainAsync({
    required ReportGenerated receipt,
    required List<DispatchEvent> relatedEvents,
    required bool replayVerified,
    required ReportReceiptSceneReviewSummary? sceneReviewSummary,
  }) async {
    return verifyEventChain(
      receipt: receipt,
      relatedEvents: relatedEvents,
      replayVerified: replayVerified,
      sceneReviewSummary: sceneReviewSummary,
    );
  }

  Future<List<ChainGap>> detectChainGapsAsync({
    required ReportGenerated receipt,
    required List<DispatchEvent> relatedEvents,
    required bool replayVerified,
    required ReportReceiptSceneReviewSummary? sceneReviewSummary,
  }) async {
    return detectChainGaps(
      receipt: receipt,
      relatedEvents: relatedEvents,
      replayVerified: replayVerified,
      sceneReviewSummary: sceneReviewSummary,
    );
  }

  Future<bool> validateEventSequenceAsync(List<DispatchEvent> events) async {
    return validateEventSequence(events);
  }
}
