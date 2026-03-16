import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/monitoring_global_posture_service.dart';
import 'package:omnix_dashboard/application/monitoring_scene_review_store.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';

void main() {
  group('MonitoringGlobalPostureService', () {
    const service = MonitoringGlobalPostureService();

    test('builds regional heat from site scene reviews', () {
      final events = <DispatchEvent>[
        _intel(
          id: 'intel-1',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-VALLEE',
          riskScore: 88,
          cameraId: 'gate-cam',
          faceMatchId: 'PERSON-1',
        ),
        _intel(
          id: 'intel-2',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-VALLEE',
          riskScore: 74,
          cameraId: 'driveway-cam',
        ),
        _intel(
          id: 'intel-3',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          riskScore: 48,
          cameraId: 'lobby-cam',
        ),
      ];

      final reviews = <String, MonitoringSceneReviewRecord>{
        'intel-1': MonitoringSceneReviewRecord(
          intelligenceId: 'intel-1',
          sourceLabel: 'openai:gpt-5.4-mini',
          postureLabel: 'boundary identity concern',
          decisionLabel: 'Escalation Candidate',
          decisionSummary: 'Person at the gate requires response review.',
          summary: 'Boundary concern near gate.',
          reviewedAtUtc: DateTime.utc(2026, 3, 16, 22, 0),
        ),
        'intel-2': MonitoringSceneReviewRecord(
          intelligenceId: 'intel-2',
          sourceLabel: 'openai:gpt-5.4-mini',
          postureLabel: 'repeat monitored activity',
          decisionLabel: 'Repeat Activity',
          decisionSummary: 'Vehicle activity repeated on driveway.',
          summary: 'Driveway activity repeated.',
          reviewedAtUtc: DateTime.utc(2026, 3, 16, 22, 1),
        ),
        'intel-3': MonitoringSceneReviewRecord(
          intelligenceId: 'intel-3',
          sourceLabel: 'openai:gpt-5.4-mini',
          postureLabel: 'monitored movement',
          decisionLabel: 'Suppressed',
          decisionSummary: 'Routine monitored movement only.',
          summary: 'No escalation needed.',
          reviewedAtUtc: DateTime.utc(2026, 3, 16, 22, 2),
        ),
      };

      final snapshot = service.buildSnapshot(
        events: events,
        sceneReviewByIntelligenceId: reviews,
        generatedAtUtc: DateTime.utc(2026, 3, 16, 22, 5),
      );

      expect(snapshot.totalSites, 2);
      expect(snapshot.criticalSiteCount, 1);
      expect(snapshot.regions, hasLength(1));
      expect(
        snapshot.regions.first.heatLevel,
        MonitoringGlobalHeatLevel.critical,
      );
      expect(snapshot.sites.first.siteId, 'SITE-VALLEE');
      expect(
        snapshot.sites.first.heatLevel,
        MonitoringGlobalHeatLevel.critical,
      );
      expect(snapshot.sites.first.dominantSignals, contains('boundary'));
    });
  });
}

IntelligenceReceived _intel({
  required String id,
  required String regionId,
  required String siteId,
  required int riskScore,
  required String cameraId,
  String faceMatchId = '',
}) {
  return IntelligenceReceived(
    eventId: 'evt-$id',
    sequence: 1,
    version: 1,
    occurredAt: DateTime.utc(2026, 3, 16, 21, 55),
    intelligenceId: id,
    provider: 'hikvision_dvr_monitor_only',
    sourceType: 'dvr',
    externalId: 'ext-$id',
    clientId: 'CLIENT-TEST',
    regionId: regionId,
    siteId: siteId,
    cameraId: cameraId,
    faceMatchId: faceMatchId.isEmpty ? null : faceMatchId,
    objectLabel: 'person',
    objectConfidence: 0.91,
    headline: 'HIKVISION ALERT',
    summary: 'Alert summary',
    riskScore: riskScore,
    snapshotUrl: 'https://edge.example.com/$id.jpg',
    canonicalHash: 'hash-$id',
  );
}
