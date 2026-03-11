import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/morning_sovereign_report_service.dart';
import 'package:omnix_dashboard/domain/events/decision_created.dart';
import 'package:omnix_dashboard/domain/events/execution_denied.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/domain/guard/guard_ops_event.dart';

void main() {
  group('MorningSovereignReportService', () {
    test('uses the latest completed 06:00 local shift boundary', () {
      final beforeSix = DateTime(2026, 3, 10, 4, 30);
      final afterSix = DateTime(2026, 3, 10, 8, 10);

      expect(
        MorningSovereignReportService.latestCompletedNightShiftEndLocal(
          beforeSix,
        ),
        DateTime(2026, 3, 9, 6, 0),
      );
      expect(
        MorningSovereignReportService.latestCompletedNightShiftEndLocal(
          afterSix,
        ),
        DateTime(2026, 3, 10, 6, 0),
      );
    });

    test('generates deterministic night-shift metrics and serializes', () {
      final service = const MorningSovereignReportService();
      final report = service.generate(
        nowUtc: DateTime.utc(2026, 3, 10, 8, 0),
        events: [
          DecisionCreated(
            eventId: 'DEC-1',
            sequence: 10,
            version: 1,
            occurredAt: DateTime.utc(2026, 3, 9, 22, 10),
            dispatchId: 'DSP-1',
            clientId: 'CLIENT-1',
            regionId: 'REGION-1',
            siteId: 'SITE-1',
          ),
          ExecutionDenied(
            eventId: 'DEN-1',
            sequence: 11,
            version: 1,
            occurredAt: DateTime.utc(2026, 3, 9, 23, 0),
            dispatchId: 'DSP-1',
            clientId: 'CLIENT-1',
            regionId: 'REGION-1',
            siteId: 'SITE-1',
            operatorId: 'OP-1',
            reason: 'PSIRA expired',
          ),
          IntelligenceReceived(
            eventId: 'INT-1',
            sequence: 12,
            version: 1,
            occurredAt: DateTime.utc(2026, 3, 10, 0, 30),
            intelligenceId: 'INT-1',
            provider: 'feed',
            sourceType: 'news',
            externalId: 'EXT-1',
            clientId: 'CLIENT-1',
            regionId: 'REGION-1',
            siteId: 'SITE-2',
            headline: 'Alert',
            summary: 'Summary',
            riskScore: 88,
            canonicalHash: 'hash',
          ),
        ],
        recentMedia: [
          GuardOpsMediaUpload(
            mediaId: 'MEDIA-1',
            eventId: 'EVT-1',
            guardId: 'GUARD-1',
            siteId: 'SITE-1',
            shiftId: 'SHIFT-1',
            bucket: 'guard-patrol-images',
            path: 'guards/GUARD-1/patrol/1.jpg',
            localPath: '/tmp/1.jpg',
            capturedAt: DateTime.utc(2026, 3, 10, 1, 0),
            status: GuardMediaUploadStatus.failed,
            visualNorm: const GuardVisualNormMetadata(
              mode: GuardVisualNormMode.night,
              baselineId: 'NORM-PATROL-1',
              captureProfile: 'patrol_verification',
              minMatchScore: 86,
              irRequired: false,
              combatWindow: true,
            ),
          ),
        ],
        guardOutcomePolicyDenied24h: 2,
      );

      final expectedWindowEndLocal = DateTime(2026, 3, 10, 6, 0);
      final expectedWindowStartUtc = expectedWindowEndLocal
          .subtract(const Duration(hours: 8))
          .toUtc();
      final expectedWindowEndUtc = expectedWindowEndLocal.toUtc();

      expect(report.date, '2026-03-10');
      expect(report.shiftWindowStartUtc, expectedWindowStartUtc);
      expect(report.shiftWindowEndUtc, expectedWindowEndUtc);
      expect(report.ledgerIntegrity.totalEvents, 3);
      expect(report.ledgerIntegrity.hashVerified, isTrue);
      expect(report.aiHumanDelta.aiDecisions, 1);
      expect(report.aiHumanDelta.humanOverrides, 1);
      expect(report.aiHumanDelta.overrideReasons['PSIRA expired'], 1);
      expect(report.normDrift.sitesMonitored, 2);
      expect(report.normDrift.driftDetected, 1);
      expect(report.complianceBlockage.psiraExpired, 1);
      expect(report.complianceBlockage.totalBlocked, 3);

      final restored = SovereignReport.fromJson(report.toJson());
      expect(restored.date, report.date);
      expect(restored.ledgerIntegrity.totalEvents, 3);
      expect(restored.aiHumanDelta.humanOverrides, 1);
    });
  });
}
