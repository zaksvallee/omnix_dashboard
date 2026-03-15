import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'monitoring_scene_review_store.dart';
import 'report_scene_review_snapshot_builder.dart';
import '../domain/crm/reporting/report_section_configuration.dart';
import '../domain/crm/crm_event.dart';
import '../domain/crm/export/pdf_report_exporter.dart';
import '../domain/crm/reporting/report_bundle.dart';
import '../domain/crm/reporting/report_bundle_assembler.dart';
import '../domain/crm/reporting/report_bundle_canonicalizer.dart';
import '../domain/events/decision_created.dart';
import '../domain/events/execution_completed.dart';
import '../domain/events/execution_denied.dart';
import '../domain/events/guard_checked_in.dart';
import '../domain/events/intelligence_received.dart';
import '../domain/events/incident_closed.dart';
import '../domain/events/patrol_completed.dart';
import '../domain/events/report_generated.dart';
import '../domain/events/response_arrived.dart';
import '../domain/incidents/incident_event.dart';
import '../domain/store/event_store.dart';

typedef IncidentEventsProvider =
    List<IncidentEvent> Function({
      required String clientId,
      required String siteId,
    });

typedef CRMEventsProvider = List<CRMEvent> Function({required String clientId});

class GeneratedReportResult {
  final ReportBundle bundle;
  final Uint8List pdfBytes;
  final ReportGenerated receiptEvent;

  const GeneratedReportResult({
    required this.bundle,
    required this.pdfBytes,
    required this.receiptEvent,
  });
}

class ReportReceiptSceneReviewSummary {
  final bool includedInReceipt;
  final int totalReviews;
  final int modelReviews;
  final int suppressedActions;
  final int incidentAlerts;
  final int repeatUpdates;
  final int escalationCandidates;
  final String topPosture;
  final ReportReceiptLatestActionBucket latestActionBucket;
  final String latestActionTaken;
  final String latestSuppressedPattern;

  const ReportReceiptSceneReviewSummary({
    required this.includedInReceipt,
    required this.totalReviews,
    required this.modelReviews,
    this.suppressedActions = 0,
    this.incidentAlerts = 0,
    this.repeatUpdates = 0,
    required this.escalationCandidates,
    required this.topPosture,
    this.latestActionBucket = ReportReceiptLatestActionBucket.none,
    this.latestActionTaken = '',
    this.latestSuppressedPattern = '',
  });
}

enum ReportReceiptLatestActionBucket {
  none,
  alerts,
  repeat,
  escalation,
  suppressed,
}

class ReportGenerationService {
  static const int reportSchemaVersion = 3;
  static const int projectionVersion = 1;

  final EventStore store;
  final IncidentEventsProvider? incidentEventsProvider;
  final CRMEventsProvider? crmEventsProvider;
  final Map<String, MonitoringSceneReviewRecord> sceneReviewByIntelligenceId;

  const ReportGenerationService({
    required this.store,
    this.incidentEventsProvider,
    this.crmEventsProvider,
    this.sceneReviewByIntelligenceId = const {},
  });

  Future<GeneratedReportResult> generatePdfReport({
    required String clientId,
    required String siteId,
    required DateTime nowUtc,
    ReportSectionConfiguration sectionConfiguration =
        const ReportSectionConfiguration(),
  }) async {
    final currentMonth = _monthKey(nowUtc);
    final previousMonth = _monthKey(
      DateTime.utc(nowUtc.year, nowUtc.month - 1),
    );

    final allEvents = store.allEvents();

    final tenantEvents = allEvents
        .where((event) {
          if (event is GuardCheckedIn) {
            return event.clientId == clientId && event.siteId == siteId;
          }
          if (event is PatrolCompleted) {
            return event.clientId == clientId && event.siteId == siteId;
          }
          if (event is DecisionCreated) {
            return event.clientId == clientId && event.siteId == siteId;
          }
          if (event is ResponseArrived) {
            return event.clientId == clientId && event.siteId == siteId;
          }
          if (event is IncidentClosed) {
            return event.clientId == clientId && event.siteId == siteId;
          }
          if (event is IntelligenceReceived) {
            return event.clientId == clientId && event.siteId == siteId;
          }
          if (event is ExecutionCompleted) {
            return event.clientId == clientId && event.siteId == siteId;
          }
          if (event is ExecutionDenied) {
            return event.clientId == clientId && event.siteId == siteId;
          }
          return false;
        })
        .toList(growable: false);

    final incidentEvents =
        incidentEventsProvider?.call(clientId: clientId, siteId: siteId) ??
        const <IncidentEvent>[];
    final crmEvents =
        crmEventsProvider?.call(clientId: clientId) ?? const <CRMEvent>[];
    final sceneReview = const ReportSceneReviewSnapshotBuilder().build(
      month: currentMonth,
      intelligenceEvents: tenantEvents.whereType<IntelligenceReceived>(),
      sceneReviewByIntelligenceId: sceneReviewByIntelligenceId,
    );

    final bundle = ReportBundleAssembler.build(
      clientId: clientId,
      currentMonth: currentMonth,
      previousMonth: previousMonth,
      incidentEvents: incidentEvents,
      crmEvents: crmEvents,
      dispatchEvents: tenantEvents,
      sceneReview: sceneReview,
      sectionConfiguration: sectionConfiguration,
    );

    final monthEvents = tenantEvents
        .where((event) {
          return _monthKey(event.occurredAt) == currentMonth;
        })
        .toList(growable: false);

    final firstSequence = monthEvents.isEmpty
        ? 0
        : monthEvents.map((e) => e.sequence).reduce((a, b) => a < b ? a : b);
    final lastSequence = monthEvents.isEmpty
        ? 0
        : monthEvents.map((e) => e.sequence).reduce((a, b) => a > b ? a : b);
    final canonicalJson = ReportBundleCanonicalizer.canonicalJson(
      bundle: bundle,
      clientId: clientId,
      siteId: siteId,
      month: currentMonth,
      reportSchemaVersion: reportSchemaVersion,
      projectionVersion: projectionVersion,
      eventRangeStart: firstSequence,
      eventRangeEnd: lastSequence,
      eventCount: monthEvents.length,
    );
    final canonicalHash = sha256
        .convert(Uint8List.fromList(utf8.encode(canonicalJson)))
        .toString();
    final pdfBytes = await PDFReportExporter.generate(bundle);
    final pdfHash = sha256.convert(pdfBytes).toString();

    final receiptEvent = ReportGenerated(
      eventId: 'RPT-$clientId-$siteId-${nowUtc.millisecondsSinceEpoch}',
      sequence: 0,
      version: 1,
      occurredAt: nowUtc,
      clientId: clientId,
      siteId: siteId,
      month: currentMonth,
      contentHash: canonicalHash,
      pdfHash: pdfHash,
      eventRangeStart: firstSequence,
      eventRangeEnd: lastSequence,
      eventCount: monthEvents.length,
      reportSchemaVersion: reportSchemaVersion,
      projectionVersion: projectionVersion,
      includeTimeline: sectionConfiguration.includeTimeline,
      includeDispatchSummary: sectionConfiguration.includeDispatchSummary,
      includeCheckpointCompliance:
          sectionConfiguration.includeCheckpointCompliance,
      includeAiDecisionLog: sectionConfiguration.includeAiDecisionLog,
      includeGuardMetrics: sectionConfiguration.includeGuardMetrics,
    );

    store.append(receiptEvent);

    return GeneratedReportResult(
      bundle: bundle,
      pdfBytes: pdfBytes,
      receiptEvent: receiptEvent,
    );
  }

  Future<bool> verifyReportHash(ReportGenerated receipt) async {
    final bundle = _buildBundleForReceipt(receipt);
    final canonicalJson = ReportBundleCanonicalizer.canonicalJson(
      bundle: bundle,
      clientId: receipt.clientId,
      siteId: receipt.siteId,
      month: receipt.month,
      reportSchemaVersion: receipt.reportSchemaVersion,
      projectionVersion: receipt.projectionVersion,
      eventRangeStart: receipt.eventRangeStart,
      eventRangeEnd: receipt.eventRangeEnd,
      eventCount: receipt.eventCount,
    );
    final replayHash = sha256
        .convert(Uint8List.fromList(utf8.encode(canonicalJson)))
        .toString();
    return replayHash == receipt.contentHash;
  }

  Future<GeneratedReportResult> regenerateFromReceipt(
    ReportGenerated receipt,
  ) async {
    final bundle = _buildBundleForReceipt(receipt);
    final pdfBytes = await PDFReportExporter.generate(bundle);
    return GeneratedReportResult(
      bundle: bundle,
      pdfBytes: pdfBytes,
      receiptEvent: receipt,
    );
  }

  ReportReceiptSceneReviewSummary summarizeSceneReviewForReceipt(
    ReportGenerated receipt,
  ) {
    if (receipt.reportSchemaVersion < 2) {
      return const ReportReceiptSceneReviewSummary(
        includedInReceipt: false,
        totalReviews: 0,
        modelReviews: 0,
        suppressedActions: 0,
        incidentAlerts: 0,
        repeatUpdates: 0,
        escalationCandidates: 0,
        topPosture: 'none',
        latestActionBucket: ReportReceiptLatestActionBucket.none,
        latestActionTaken: '',
        latestSuppressedPattern: '',
      );
    }
    if (!receipt.includeAiDecisionLog) {
      return const ReportReceiptSceneReviewSummary(
        includedInReceipt: false,
        totalReviews: 0,
        modelReviews: 0,
        suppressedActions: 0,
        incidentAlerts: 0,
        repeatUpdates: 0,
        escalationCandidates: 0,
        topPosture: 'not included',
        latestActionBucket: ReportReceiptLatestActionBucket.none,
        latestActionTaken: '',
        latestSuppressedPattern: '',
      );
    }
    final bundle = _buildBundleForReceipt(receipt);
    return ReportReceiptSceneReviewSummary(
      includedInReceipt: true,
      totalReviews: bundle.sceneReview.totalReviews,
      modelReviews: bundle.sceneReview.modelReviews,
      suppressedActions: bundle.sceneReview.suppressedActions,
      incidentAlerts: bundle.sceneReview.incidentAlerts,
      repeatUpdates: bundle.sceneReview.repeatUpdates,
      escalationCandidates: bundle.sceneReview.escalationCandidates,
      topPosture: bundle.sceneReview.topPosture,
      latestActionBucket: _latestActionBucket(bundle),
      latestActionTaken: bundle.sceneReview.latestActionTaken,
      latestSuppressedPattern: bundle.sceneReview.latestSuppressedPattern,
    );
  }

  ReportReceiptLatestActionBucket _latestActionBucket(ReportBundle bundle) {
    if (bundle.sceneReview.highlights.isEmpty) {
      return ReportReceiptLatestActionBucket.none;
    }
    final latest = bundle.sceneReview.highlights.first;
    final decision = latest.decisionLabel.trim().toLowerCase();
    final posture = latest.postureLabel.trim().toLowerCase();
    if (decision.contains('suppress')) {
      return ReportReceiptLatestActionBucket.suppressed;
    }
    if (decision.contains('repeat')) {
      return ReportReceiptLatestActionBucket.repeat;
    }
    if (decision.contains('escalation')) {
      return ReportReceiptLatestActionBucket.escalation;
    }
    if (decision.contains('alert') || decision.contains('incident')) {
      return ReportReceiptLatestActionBucket.alerts;
    }
    if (posture.contains('escalation')) {
      return ReportReceiptLatestActionBucket.escalation;
    }
    if (posture.contains('repeat')) {
      return ReportReceiptLatestActionBucket.repeat;
    }
    if (bundle.sceneReview.latestSuppressedPattern.trim().isNotEmpty) {
      return ReportReceiptLatestActionBucket.suppressed;
    }
    if (posture.isNotEmpty) {
      return ReportReceiptLatestActionBucket.alerts;
    }
    return ReportReceiptLatestActionBucket.none;
  }

  ReportBundle _buildBundleForReceipt(ReportGenerated receipt) {
    final allEvents = store.allEvents();
    final scopedEvents = allEvents
        .where((event) {
          if (event.sequence < receipt.eventRangeStart ||
              event.sequence > receipt.eventRangeEnd) {
            return false;
          }

          if (event is GuardCheckedIn) {
            return event.clientId == receipt.clientId &&
                event.siteId == receipt.siteId;
          }
          if (event is PatrolCompleted) {
            return event.clientId == receipt.clientId &&
                event.siteId == receipt.siteId;
          }
          if (event is DecisionCreated) {
            return event.clientId == receipt.clientId &&
                event.siteId == receipt.siteId;
          }
          if (event is ResponseArrived) {
            return event.clientId == receipt.clientId &&
                event.siteId == receipt.siteId;
          }
          if (event is IncidentClosed) {
            return event.clientId == receipt.clientId &&
                event.siteId == receipt.siteId;
          }
          if (event is IntelligenceReceived) {
            return event.clientId == receipt.clientId &&
                event.siteId == receipt.siteId;
          }
          if (event is ExecutionCompleted) {
            return event.clientId == receipt.clientId &&
                event.siteId == receipt.siteId;
          }
          if (event is ExecutionDenied) {
            return event.clientId == receipt.clientId &&
                event.siteId == receipt.siteId;
          }
          return false;
        })
        .toList(growable: false);

    final incidentEvents =
        incidentEventsProvider?.call(
          clientId: receipt.clientId,
          siteId: receipt.siteId,
        ) ??
        const <IncidentEvent>[];
    final crmEvents =
        crmEventsProvider?.call(clientId: receipt.clientId) ??
        const <CRMEvent>[];
    final sceneReview = const ReportSceneReviewSnapshotBuilder().build(
      month: receipt.month,
      intelligenceEvents: scopedEvents.whereType<IntelligenceReceived>(),
      sceneReviewByIntelligenceId: sceneReviewByIntelligenceId,
    );

    final bundle = ReportBundleAssembler.build(
      clientId: receipt.clientId,
      currentMonth: receipt.month,
      previousMonth: _monthKey(
        DateTime.utc(
          int.parse(receipt.month.split('-')[0]),
          int.parse(receipt.month.split('-')[1]) - 1,
        ),
      ),
      incidentEvents: incidentEvents,
      crmEvents: crmEvents,
      dispatchEvents: scopedEvents,
      sceneReview: sceneReview,
      sectionConfiguration: receipt.sectionConfiguration,
    );
    return bundle;
  }

  static String _monthKey(DateTime utc) {
    final normalized = utc.toUtc();
    return '${normalized.year.toString().padLeft(4, '0')}-${normalized.month.toString().padLeft(2, '0')}';
  }
}
