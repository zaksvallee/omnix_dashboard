import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/monitoring_scene_review_store.dart';
import 'package:omnix_dashboard/application/monitoring_site_narrative_service.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';

void main() {
  const service = MonitoringSiteNarrativeService();

  test(
    'builds distributed routine-activity narrative when multi-camera people overlap with field telemetry',
    () {
      final snapshot = service.buildSnapshot(
        recentEvents: <IntelligenceReceived>[
          _intel(
            intelligenceId: 'intel-13',
            cameraId: 'channel-13',
            occurredAt: DateTime.utc(2026, 3, 18, 9, 47),
            objectLabel: 'person',
            summary: 'Front-yard movement detected.',
          ),
          _intel(
            intelligenceId: 'intel-12',
            cameraId: 'channel-12',
            occurredAt: DateTime.utc(2026, 3, 18, 9, 46),
            objectLabel: 'person',
            summary: 'Back-yard movement detected.',
          ),
          _intel(
            intelligenceId: 'intel-6',
            cameraId: 'channel-6',
            occurredAt: DateTime.utc(2026, 3, 18, 9, 45),
            objectLabel: 'person',
            summary: 'Driveway movement detected.',
          ),
          _intel(
            intelligenceId: 'intel-5',
            cameraId: 'channel-5',
            occurredAt: DateTime.utc(2026, 3, 18, 9, 44),
            objectLabel: 'vehicle',
            summary: 'Vehicle movement detected.',
          ),
        ],
        cameraLabelForId: (cameraId) {
          final match = RegExp(r'(\d+)$').firstMatch(cameraId ?? '');
          return match == null ? 'Camera 1' : 'Camera ${match.group(1)}';
        },
        fieldActivity: const MonitoringSiteNarrativeFieldActivity(
          count: 2,
          latestSource: 'Front Yard',
          latestSummary: 'A guard checkpoint scan landed at Front Yard.',
          activeSources: <String>['Front Yard', 'Back Yard'],
        ),
        sceneReviewsByIntelligenceId: <String, MonitoringSceneReviewRecord>{
          'intel-13': MonitoringSceneReviewRecord(
            intelligenceId: 'intel-13',
            sourceLabel: 'openai:gpt-4.1-mini',
            postureLabel: 'multi-camera activity under review',
            decisionLabel: 'Escalated',
            decisionSummary: 'Escalation candidate remains under verification.',
            summary: 'Distributed person movement remains visible.',
            reviewedAtUtc: DateTime.utc(2026, 3, 18, 9, 47),
          ),
        },
      );

      expect(snapshot, isNotNull);
      expect(
        snapshot!.assessment,
        'likely routine on-site team activity across front and back yard',
      );
      expect(
        snapshot.narrative,
        contains(
          'Recent camera review saw 3 person signals across Camera 12, Camera 13, and Camera 6, plus 1 vehicle signal across Camera 5.',
        ),
      );
      expect(
        snapshot.narrative,
        contains(
          'This overlaps with on-site team activity across Front Yard and Back Yard, so it looks routine.',
        ),
      );
      expect(snapshot.narrative, contains('Latest signal landed at 11:47.'));
    },
  );

  test('builds broad site-activity narrative without field telemetry', () {
    final snapshot = service.buildSnapshot(
      recentEvents: <IntelligenceReceived>[
        _intel(
          intelligenceId: 'intel-3',
          cameraId: 'channel-3',
          occurredAt: DateTime.utc(2026, 3, 18, 9, 45),
          objectLabel: 'person',
          summary: 'Gate movement detected.',
        ),
        _intel(
          intelligenceId: 'intel-6',
          cameraId: 'channel-6',
          occurredAt: DateTime.utc(2026, 3, 18, 9, 44),
          objectLabel: 'vehicle',
          summary: 'Driveway vehicle movement detected.',
        ),
      ],
      cameraLabelForId: (cameraId) {
        final match = RegExp(r'(\d+)$').firstMatch(cameraId ?? '');
        return match == null ? 'Camera 1' : 'Camera ${match.group(1)}';
      },
    );

    expect(snapshot, isNotNull);
    expect(snapshot!.assessment, 'broad mixed site activity under review');
    expect(
      snapshot.narrative,
      contains('People and vehicle movement are both active across the site.'),
    );
  });

  test(
    'falls back to latest field summary when only one telemetry source is known',
    () {
      final snapshot = service.buildSnapshot(
        recentEvents: <IntelligenceReceived>[
          _intel(
            intelligenceId: 'intel-13',
            cameraId: 'channel-13',
            occurredAt: DateTime.utc(2026, 3, 18, 9, 47),
            objectLabel: 'person',
            summary: 'Front-yard movement detected.',
          ),
          _intel(
            intelligenceId: 'intel-12',
            cameraId: 'channel-12',
            occurredAt: DateTime.utc(2026, 3, 18, 9, 46),
            objectLabel: 'person',
            summary: 'Back-yard movement detected.',
          ),
        ],
        cameraLabelForId: (cameraId) {
          final match = RegExp(r'(\d+)$').firstMatch(cameraId ?? '');
          return match == null ? 'Camera 1' : 'Camera ${match.group(1)}';
        },
        fieldActivity: const MonitoringSiteNarrativeFieldActivity(
          count: 1,
          latestSource: 'Front Yard',
          latestSummary: 'A guard checkpoint scan landed at Front Yard.',
          activeSources: <String>['Front Yard'],
        ),
      );

      expect(snapshot, isNotNull);
      expect(
        snapshot!.narrative,
        contains(
          'This overlaps with on-site team activity, so it looks routine.',
        ),
      );
    },
  );

  test(
    'keeps generic routine assessment when telemetry does not identify yard zones',
    () {
      final snapshot = service.buildSnapshot(
        recentEvents: <IntelligenceReceived>[
          _intel(
            intelligenceId: 'intel-13',
            cameraId: 'channel-13',
            occurredAt: DateTime.utc(2026, 3, 18, 9, 47),
            objectLabel: 'person',
            summary: 'Front-yard movement detected.',
          ),
          _intel(
            intelligenceId: 'intel-12',
            cameraId: 'channel-12',
            occurredAt: DateTime.utc(2026, 3, 18, 9, 46),
            objectLabel: 'person',
            summary: 'Back-yard movement detected.',
          ),
        ],
        cameraLabelForId: (cameraId) {
          final match = RegExp(r'(\d+)$').firstMatch(cameraId ?? '');
          return match == null ? 'Camera 1' : 'Camera ${match.group(1)}';
        },
        fieldActivity: const MonitoringSiteNarrativeFieldActivity(
          count: 2,
          latestSource: 'North Patrol Route',
          latestSummary: 'Patrol activity completed on North Patrol Route.',
          activeSources: <String>['North Patrol Route', 'South Patrol Route'],
        ),
      );

      expect(snapshot, isNotNull);
      expect(snapshot!.assessment, 'likely routine on-site team activity');
      expect(snapshot.narrative, isNot(contains('Front Yard and Back Yard')));
      expect(
        snapshot.narrative,
        contains(
          'This overlaps with on-site team activity at North Patrol Route and South Patrol Route, so it looks routine.',
        ),
      );
    },
  );
}

IntelligenceReceived _intel({
  required String intelligenceId,
  required String cameraId,
  required DateTime occurredAt,
  required String objectLabel,
  required String summary,
}) {
  return IntelligenceReceived(
    eventId: 'evt-$intelligenceId',
    sequence: 1,
    version: 1,
    occurredAt: occurredAt,
    intelligenceId: intelligenceId,
    provider: 'hikvision_dvr_monitor_only',
    sourceType: 'dvr',
    externalId: 'ext-$intelligenceId',
    clientId: 'CLIENT-MS-VALLEE',
    regionId: 'REGION-GAUTENG',
    siteId: 'SITE-MS-VALLEE-RESIDENCE',
    cameraId: cameraId,
    objectLabel: objectLabel,
    objectConfidence: 0.8,
    headline: 'Test movement',
    summary: summary,
    riskScore: 65,
    snapshotUrl: null,
    canonicalHash: 'hash-$intelligenceId',
  );
}
