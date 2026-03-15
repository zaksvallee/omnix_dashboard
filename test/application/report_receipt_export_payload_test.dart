import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/report_generation_service.dart';
import 'package:omnix_dashboard/application/report_receipt_export_payload.dart';
import 'package:omnix_dashboard/application/report_receipt_scene_filter.dart';

import '../fixtures/report_test_receipt.dart';

void main() {
  test('build returns receipt export envelope for all filter', () {
    final receipt = buildTestReportGenerated(
      eventId: 'RPT-1',
      occurredAt: DateTime.utc(2026, 3, 14, 22, 0),
      reportSchemaVersion: 1,
    );

    final payload = ReportReceiptExportPayload.build(
      entries: [
        ReportReceiptExportEntry(receiptEvent: receipt, replayVerified: true),
      ],
      filter: ReportReceiptSceneFilter.all,
      selectedReceiptEventId: 'RPT-1',
    );

    expect(payload['context'], isA<Map<String, Object?>>());
    expect(payload['receipts'], isA<List<Object?>>());

    final context = payload['context']! as Map<String, Object?>;
    final filter = context['filter']! as Map<String, Object?>;
    final receipts = payload['receipts']! as List<Object?>;
    final firstReceipt = receipts.first! as Map<String, Object?>;

    expect(filter['key'], 'all');
    expect(filter['label'], 'All Receipts');
    expect(filter['statusLabel'], 'All receipts');
    expect(filter['viewingLabel'], 'Viewing All receipts');
    expect(context['selectedReceiptEventId'], 'RPT-1');
    expect(context.containsKey('focusedReceipt'), isFalse);
    expect(firstReceipt['eventId'], 'RPT-1');
    expect(firstReceipt['replayVerified'], true);
    expect(firstReceipt['sceneReviewIncluded'], false);
    expect(firstReceipt['sectionConfiguration'], isA<Map<String, Object?>>());
  });

  test('build includes focused receipt only for latest-action filters', () {
    final receipt = buildTestReportGenerated(
      eventId: 'RPT-ALERT-1',
      occurredAt: DateTime.utc(2026, 3, 14, 22, 0),
      reportSchemaVersion: 2,
    );
    const summary = ReportReceiptSceneReviewSummary(
      includedInReceipt: true,
      totalReviews: 1,
      modelReviews: 1,
      incidentAlerts: 1,
      escalationCandidates: 0,
      topPosture: 'reviewed',
      latestActionBucket: ReportReceiptLatestActionBucket.alerts,
      latestActionTaken:
          '2026-03-14T21:14:00.000Z • Camera 1 • Monitoring Alert • Vehicle remained visible in the monitored driveway.',
    );

    final payload = ReportReceiptExportPayload.build(
      entries: [
        ReportReceiptExportEntry(
          receiptEvent: receipt,
          replayVerified: true,
          sceneReviewSummary: summary,
        ),
      ],
      filter: ReportReceiptSceneFilter.latestAlerts,
      previewReceiptEventId: 'RPT-ALERT-1',
      focusedReceipt: ReportReceiptExportEntry(
        receiptEvent: receipt,
        replayVerified: true,
        sceneReviewSummary: summary,
      ),
    );

    final context = payload['context']! as Map<String, Object?>;
    final focusedReceipt = context['focusedReceipt']! as Map<String, Object?>;

    expect((context['filter']! as Map<String, Object?>)['key'], 'latestAlerts');
    expect(context['previewReceiptEventId'], 'RPT-ALERT-1');
    expect(focusedReceipt['eventId'], 'RPT-ALERT-1');
    expect(focusedReceipt['latestActionBucket'], 'alerts');
    expect(
      focusedReceipt['latestActionTaken'],
      '2026-03-14T21:14:00.000Z • Camera 1 • Monitoring Alert • Vehicle remained visible in the monitored driveway.',
    );
  });

  test(
    'build carries active section configuration and receipt section state',
    () {
      final receipt = buildTestReportGenerated(
        eventId: 'RPT-CONFIG-1',
        occurredAt: DateTime.utc(2026, 3, 14, 22, 0),
        reportSchemaVersion: 3,
        includeDispatchSummary: false,
        includeAiDecisionLog: false,
      );

      final payload = ReportReceiptExportPayload.build(
        entries: [
          ReportReceiptExportEntry(receiptEvent: receipt, replayVerified: true),
        ],
        filter: ReportReceiptSceneFilter.all,
        activeSectionConfiguration: const <String, Object?>{
          'includeTimeline': true,
          'includeDispatchSummary': false,
          'includeCheckpointCompliance': true,
          'includeAiDecisionLog': false,
          'includeGuardMetrics': false,
        },
      );

      final context = payload['context']! as Map<String, Object?>;
      final firstReceipt =
          (payload['receipts']! as List<Object?>).first!
              as Map<String, Object?>;
      final activeConfig =
          context['activeSectionConfiguration']! as Map<String, Object?>;
      final receiptConfig =
          firstReceipt['sectionConfiguration']! as Map<String, Object?>;

      expect(activeConfig['includeDispatchSummary'], false);
      expect(activeConfig['includeAiDecisionLog'], false);
      expect(firstReceipt['sceneReviewIncluded'], false);
      expect(receiptConfig['includeDispatchSummary'], false);
      expect(receiptConfig['includeAiDecisionLog'], false);
    },
  );

  test(
    'buildSingle returns the same envelope shape for single receipt exports',
    () {
      final receipt = buildTestReportGenerated(
        eventId: 'RPT-SINGLE-1',
        occurredAt: DateTime.utc(2026, 3, 14, 22, 0),
        reportSchemaVersion: 1,
      );

      final payload = ReportReceiptExportPayload.buildSingle(
        entry: ReportReceiptExportEntry(receiptEvent: receipt),
        filter: ReportReceiptSceneFilter.all,
        selectedReceiptEventId: 'RPT-SINGLE-1',
      );

      final context = payload['context']! as Map<String, Object?>;
      final receipts = payload['receipts']! as List<Object?>;

      expect((context['filter']! as Map<String, Object?>)['key'], 'all');
      expect(context['selectedReceiptEventId'], 'RPT-SINGLE-1');
      expect(receipts, hasLength(1));
      expect(
        (receipts.first! as Map<String, Object?>)['eventId'],
        'RPT-SINGLE-1',
      );
    },
  );
}
