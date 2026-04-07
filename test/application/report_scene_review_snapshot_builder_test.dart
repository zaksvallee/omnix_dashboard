import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/monitoring_scene_review_store.dart';
import 'package:omnix_dashboard/application/report_scene_review_snapshot_builder.dart';

import '../fixtures/report_test_bundle.dart';
import '../fixtures/report_test_intelligence.dart';

DateTime _reportSceneReviewOccurredAtUtc(int hour, int minute) =>
    DateTime.utc(2026, 3, 14, hour, minute);

DateTime _reportSceneReviewReviewedAtUtc(
  int hour,
  int minute, [
  int second = 0,
]) => DateTime.utc(2026, 3, 14, hour, minute, second);

DateTime _reportSceneReviewPreviousMonthOccurredAtUtc() =>
    DateTime.utc(2026, 2, 28, 23, 59);

DateTime _reportSceneReviewPreviousMonthReviewedAtUtc() =>
    DateTime.utc(2026, 2, 28, 23, 59, 10);

void main() {
  group('ReportSceneReviewSnapshotBuilder', () {
    const builder = ReportSceneReviewSnapshotBuilder();

    test('builds month-scoped scene review metrics and highlights', () {
      final snapshot = builder.build(
        month: '2026-03',
        intelligenceEvents: [
          buildTestIntelligenceReceived(
            eventId: 'evt-1',
            sequence: 1,
            occurredAt: _reportSceneReviewOccurredAtUtc(21, 14),
            intelligenceId: 'intel-1',
            cameraId: 'channel-1',
            headline: 'Vehicle movement',
            summary: 'Vehicle detected on Camera 1.',
            riskScore: 42,
          ),
          buildTestIntelligenceReceived(
            eventId: 'evt-1b',
            sequence: 4,
            occurredAt: _reportSceneReviewOccurredAtUtc(21, 16),
            intelligenceId: 'intel-1b',
            cameraId: 'channel-3',
            headline: 'Low significance motion',
            summary: 'Low significance motion on Camera 3.',
            riskScore: 18,
          ),
          buildTestIntelligenceReceived(
            eventId: 'evt-2',
            sequence: 2,
            occurredAt: _reportSceneReviewOccurredAtUtc(21, 18),
            intelligenceId: 'intel-2',
            externalId: 'ext-2',
            cameraId: 'channel-2',
            headline: 'Repeat movement',
            summary: 'Repeat movement detected on Camera 2.',
            riskScore: 63,
            canonicalHash: 'hash-2',
          ),
          buildTestIntelligenceReceived(
            eventId: 'evt-3',
            sequence: 3,
            occurredAt: _reportSceneReviewPreviousMonthOccurredAtUtc(),
            intelligenceId: 'intel-old',
            externalId: 'ext-old',
            cameraId: 'channel-9',
            headline: 'Old movement',
            summary: 'Old period review.',
            riskScore: 12,
            canonicalHash: 'hash-old',
          ),
        ],
        sceneReviewByIntelligenceId: {
          'intel-1': MonitoringSceneReviewRecord(
            intelligenceId: 'intel-1',
            evidenceRecordHash: 'evidence-1',
            sourceLabel: 'openai:gpt-4.1-mini',
            postureLabel: 'monitored movement alert',
            decisionLabel: 'Monitoring Alert',
            summary: 'Vehicle visible in the monitored driveway.',
            reviewedAtUtc: _reportSceneReviewReviewedAtUtc(21, 14, 10),
          ),
          'intel-1b': MonitoringSceneReviewRecord(
            intelligenceId: 'intel-1b',
            evidenceRecordHash: 'evidence-1b',
            sourceLabel: 'openai:gpt-4.1-mini',
            postureLabel: 'reviewed',
            decisionLabel: 'Suppressed Review',
            decisionSummary: reportTestSuppressedDecisionSummary,
            summary: reportTestSuppressedSummary,
            reviewedAtUtc: _reportSceneReviewReviewedAtUtc(21, 16, 5),
          ),
          'intel-2': MonitoringSceneReviewRecord(
            intelligenceId: 'intel-2',
            evidenceRecordHash: 'evidence-2',
            sourceLabel: 'metadata:fallback',
            postureLabel: 'escalation candidate',
            decisionLabel: 'Escalation Candidate',
            decisionSummary:
                'Escalated for urgent review because person activity was detected near the boundary.',
            summary: reportTestEscalationSummary,
            reviewedAtUtc: _reportSceneReviewReviewedAtUtc(21, 18, 8),
          ),
          'intel-old': MonitoringSceneReviewRecord(
            intelligenceId: 'intel-old',
            evidenceRecordHash: 'evidence-old',
            sourceLabel: 'openai:gpt-4.1-mini',
            postureLabel: 'monitored movement alert',
            summary: 'Should be excluded by month filter.',
            reviewedAtUtc: _reportSceneReviewPreviousMonthReviewedAtUtc(),
          ),
        },
      );

      expect(snapshot.totalReviews, 3);
      expect(snapshot.modelReviews, 2);
      expect(snapshot.metadataFallbackReviews, 1);
      expect(snapshot.suppressedActions, 1);
      expect(snapshot.incidentAlerts, 1);
      expect(snapshot.repeatUpdates, 0);
      expect(snapshot.escalationCandidates, 1);
      expect(
        snapshot.latestActionTaken,
        reportTestLatestActionTaken,
      );
      expect(
        snapshot.latestSuppressedPattern,
        reportTestLatestSuppressedPattern,
      );
      expect(snapshot.topPosture, 'escalation candidate');
      expect(snapshot.highlights, hasLength(3));
      expect(snapshot.highlights.first.intelligenceId, 'intel-2');
      expect(snapshot.highlights.first.cameraLabel, 'Camera 2');
      expect(snapshot.highlights.first.decisionLabel, 'Escalation Candidate');
      expect(
        snapshot.highlights.first.summary,
        reportTestEscalationSummary,
      );
    });

    test('returns empty snapshot when no matching reviews exist', () {
      final snapshot = builder.build(
        month: '2026-03',
        intelligenceEvents: const [],
      );

      expect(snapshot.totalReviews, 0);
      expect(snapshot.modelReviews, 0);
      expect(snapshot.metadataFallbackReviews, 0);
      expect(snapshot.suppressedActions, 0);
      expect(snapshot.incidentAlerts, 0);
      expect(snapshot.repeatUpdates, 0);
      expect(snapshot.escalationCandidates, 0);
      expect(snapshot.latestActionTaken, isEmpty);
      expect(snapshot.latestSuppressedPattern, isEmpty);
      expect(snapshot.topPosture, 'none');
      expect(snapshot.highlights, isEmpty);
    });

    test('treats hazard posture as escalation without explicit decision label', () {
      final snapshot = builder.build(
        month: '2026-03',
        intelligenceEvents: [
          buildTestIntelligenceReceived(
            eventId: 'evt-fire',
            sequence: 1,
            occurredAt: _reportSceneReviewOccurredAtUtc(22, 14),
            intelligenceId: 'intel-fire',
            cameraId: 'channel-4',
            headline: 'Fire alert',
            summary: 'Smoke visible in the generator room.',
            riskScore: 81,
          ),
        ],
        sceneReviewByIntelligenceId: {
          'intel-fire': MonitoringSceneReviewRecord(
            intelligenceId: 'intel-fire',
            evidenceRecordHash: 'evidence-fire',
            sourceLabel: 'openai:gpt-4.1-mini',
            postureLabel: 'fire and smoke emergency',
            summary: 'Smoke plume visible inside the generator room.',
            reviewedAtUtc: _reportSceneReviewReviewedAtUtc(22, 14, 6),
          ),
        },
      );

      expect(snapshot.incidentAlerts, 0);
      expect(snapshot.repeatUpdates, 0);
      expect(snapshot.escalationCandidates, 1);
      expect(snapshot.topPosture, 'fire and smoke emergency');
      expect(
        snapshot.latestActionTaken,
        '2026-03-14T22:14:00.000Z • Camera 4 • Smoke plume visible inside the generator room.',
      );
    });
  });
}
