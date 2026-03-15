import 'package:omnix_dashboard/application/monitoring_scene_review_store.dart';
import 'package:omnix_dashboard/domain/store/in_memory_event_store.dart';

import 'report_test_intelligence.dart';
import 'report_test_receipt.dart';

class ReportReviewedWorkspaceFixture {
  final InMemoryEventStore store;
  final Map<String, MonitoringSceneReviewRecord> sceneReviewByIntelligenceId;
  final String reviewedReceiptEventId;
  final String pendingReceiptEventId;

  const ReportReviewedWorkspaceFixture({
    required this.store,
    required this.sceneReviewByIntelligenceId,
    required this.reviewedReceiptEventId,
    required this.pendingReceiptEventId,
  });
}

class ReportReviewedGenerationFixture {
  final InMemoryEventStore store;
  final Map<String, MonitoringSceneReviewRecord> sceneReviewByIntelligenceId;
  final String intelligenceId;

  const ReportReviewedGenerationFixture({
    required this.store,
    required this.sceneReviewByIntelligenceId,
    required this.intelligenceId,
  });
}

ReportReviewedWorkspaceFixture buildReviewedReportWorkspaceFixture({
  String clientId = 'CLIENT-001',
  String siteId = 'SITE-SANDTON',
  String intelligenceEventId = 'INTEL-REVIEWED-1',
  String intelligenceId = 'intel-reviewed-1',
  String reviewedReceiptEventId = 'RPT-LIVE-REVIEWED-1',
  String pendingReceiptEventId = 'RPT-LIVE-PENDING-1',
}) {
  final store = InMemoryEventStore();
  store.append(
    buildTestIntelligenceReceived(
      eventId: intelligenceEventId,
      sequence: 5,
      occurredAt: DateTime.utc(2026, 3, 14, 21, 14),
      intelligenceId: intelligenceId,
      clientId: clientId,
      siteId: siteId,
      summary: 'Vehicle movement detected on Camera 1.',
    ),
  );
  store.append(
    buildTestReportGenerated(
      eventId: reviewedReceiptEventId,
      sequence: 11,
      occurredAt: DateTime.utc(2026, 3, 15, 0, 45),
      clientId: clientId,
      siteId: siteId,
      reportSchemaVersion: 2,
      projectionVersion: 2,
      eventRangeStart: 1,
      eventRangeEnd: 1,
      eventCount: 1,
    ),
  );
  store.append(
    buildTestReportGenerated(
      eventId: pendingReceiptEventId,
      sequence: 10,
      occurredAt: DateTime.utc(2026, 3, 15, 0, 30),
      clientId: clientId,
      siteId: siteId,
      reportSchemaVersion: 1,
      eventRangeStart: 0,
      eventRangeEnd: 0,
      eventCount: 0,
    ),
  );

  return ReportReviewedWorkspaceFixture(
    store: store,
    sceneReviewByIntelligenceId: {
      intelligenceId: MonitoringSceneReviewRecord(
        intelligenceId: intelligenceId,
        sourceLabel: 'openai:gpt-4.1-mini',
        postureLabel: 'reviewed',
        decisionLabel: 'Monitoring Alert',
        decisionSummary:
            'Client alert sent because vehicle activity was detected and confidence remained medium.',
        summary: 'Vehicle remained below escalation threshold.',
        reviewedAtUtc: DateTime.utc(2026, 3, 14, 21, 15),
      ),
    },
    reviewedReceiptEventId: reviewedReceiptEventId,
    pendingReceiptEventId: pendingReceiptEventId,
  );
}

ReportReviewedWorkspaceFixture buildSuppressedReportWorkspaceFixture({
  String clientId = 'CLIENT-001',
  String siteId = 'SITE-SANDTON',
  String intelligenceEventId = 'INTEL-SUPPRESSED-1',
  String intelligenceId = 'intel-suppressed-1',
  String suppressedReceiptEventId = 'RPT-LIVE-SUPPRESSED-1',
  String pendingReceiptEventId = 'RPT-LIVE-PENDING-1',
}) {
  final store = InMemoryEventStore();
  store.append(
    buildTestIntelligenceReceived(
      eventId: intelligenceEventId,
      sequence: 5,
      occurredAt: DateTime.utc(2026, 3, 14, 21, 16),
      intelligenceId: intelligenceId,
      clientId: clientId,
      siteId: siteId,
      cameraId: 'channel-3',
      summary: 'Low significance vehicle motion on Camera 3.',
    ),
  );
  store.append(
    buildTestReportGenerated(
      eventId: suppressedReceiptEventId,
      sequence: 11,
      occurredAt: DateTime.utc(2026, 3, 15, 0, 45),
      clientId: clientId,
      siteId: siteId,
      reportSchemaVersion: 2,
      projectionVersion: 2,
      eventRangeStart: 1,
      eventRangeEnd: 1,
      eventCount: 1,
    ),
  );
  store.append(
    buildTestReportGenerated(
      eventId: pendingReceiptEventId,
      sequence: 10,
      occurredAt: DateTime.utc(2026, 3, 15, 0, 30),
      clientId: clientId,
      siteId: siteId,
      reportSchemaVersion: 1,
      eventRangeStart: 0,
      eventRangeEnd: 0,
      eventCount: 0,
    ),
  );

  return ReportReviewedWorkspaceFixture(
    store: store,
    sceneReviewByIntelligenceId: {
      intelligenceId: MonitoringSceneReviewRecord(
        intelligenceId: intelligenceId,
        sourceLabel: 'metadata:fallback',
        postureLabel: 'reviewed',
        decisionLabel: 'Suppressed Review',
        decisionSummary: 'Vehicle remained below escalation threshold.',
        summary: 'Low significance vehicle motion remained internal.',
        reviewedAtUtc: DateTime.utc(2026, 3, 14, 21, 17),
      ),
    },
    reviewedReceiptEventId: suppressedReceiptEventId,
    pendingReceiptEventId: pendingReceiptEventId,
  );
}

ReportReviewedWorkspaceFixture buildRepeatReportWorkspaceFixture({
  String clientId = 'CLIENT-001',
  String siteId = 'SITE-SANDTON',
  String intelligenceEventId = 'INTEL-REPEAT-1',
  String intelligenceId = 'intel-repeat-1',
  String repeatReceiptEventId = 'RPT-LIVE-REPEAT-1',
  String pendingReceiptEventId = 'RPT-LIVE-PENDING-1',
}) {
  final store = InMemoryEventStore();
  store.append(
    buildTestIntelligenceReceived(
      eventId: intelligenceEventId,
      sequence: 5,
      occurredAt: DateTime.utc(2026, 3, 14, 21, 18),
      intelligenceId: intelligenceId,
      clientId: clientId,
      siteId: siteId,
      cameraId: 'channel-2',
      summary: 'Repeat vehicle movement on Camera 2.',
    ),
  );
  store.append(
    buildTestReportGenerated(
      eventId: repeatReceiptEventId,
      sequence: 11,
      occurredAt: DateTime.utc(2026, 3, 15, 0, 45),
      clientId: clientId,
      siteId: siteId,
      reportSchemaVersion: 2,
      projectionVersion: 2,
      eventRangeStart: 1,
      eventRangeEnd: 1,
      eventCount: 1,
    ),
  );
  store.append(
    buildTestReportGenerated(
      eventId: pendingReceiptEventId,
      sequence: 10,
      occurredAt: DateTime.utc(2026, 3, 15, 0, 30),
      clientId: clientId,
      siteId: siteId,
      reportSchemaVersion: 1,
      eventRangeStart: 0,
      eventRangeEnd: 0,
      eventCount: 0,
    ),
  );

  return ReportReviewedWorkspaceFixture(
    store: store,
    sceneReviewByIntelligenceId: {
      intelligenceId: MonitoringSceneReviewRecord(
        intelligenceId: intelligenceId,
        sourceLabel: 'openai:gpt-4.1-mini',
        postureLabel: 'repeat activity',
        decisionLabel: 'Repeat Activity Update',
        decisionSummary:
            'Repeat monitoring update sent after recurring vehicle movement.',
        summary: 'Vehicle returned to the same camera zone within minutes.',
        reviewedAtUtc: DateTime.utc(2026, 3, 14, 21, 19),
      ),
    },
    reviewedReceiptEventId: repeatReceiptEventId,
    pendingReceiptEventId: pendingReceiptEventId,
  );
}

ReportReviewedGenerationFixture buildReviewedReportGenerationFixture({
  String clientId = 'CLIENT-001',
  String siteId = 'SITE-SANDTON',
  String intelligenceEventId = 'INTEL-GENERATE-REVIEWED-1',
  String intelligenceId = 'intel-generate-reviewed-1',
}) {
  final store = InMemoryEventStore();
  store.append(
    buildTestIntelligenceReceived(
      eventId: intelligenceEventId,
      sequence: 5,
      occurredAt: DateTime.utc(2026, 3, 14, 21, 14),
      intelligenceId: intelligenceId,
      clientId: clientId,
      siteId: siteId,
      summary: 'Vehicle movement detected on Camera 1.',
    ),
  );

  return ReportReviewedGenerationFixture(
    store: store,
    sceneReviewByIntelligenceId: {
      intelligenceId: MonitoringSceneReviewRecord(
        intelligenceId: intelligenceId,
        sourceLabel: 'openai:gpt-4.1-mini',
        postureLabel: 'reviewed',
        decisionLabel: 'Monitoring Alert',
        decisionSummary:
            'Client alert sent because vehicle activity was detected and confidence remained medium.',
        summary: 'Vehicle remained below escalation threshold.',
        reviewedAtUtc: DateTime.utc(2026, 3, 14, 21, 15),
      ),
    },
    intelligenceId: intelligenceId,
  );
}
