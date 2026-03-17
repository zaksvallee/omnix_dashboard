import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/monitoring_scene_review_store.dart';
import 'package:omnix_dashboard/application/monitoring_watch_autonomy_service.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';

void main() {
  group('MonitoringWatchAutonomyService', () {
    const service = MonitoringWatchAutonomyService();

    test('builds escalation-first plans from scene reviews', () {
      final events = <DispatchEvent>[
        _intel(
          id: 'intel-escalate',
          riskScore: 91,
          siteId: 'SITE-VALLEE',
          cameraId: 'gate-cam',
          faceMatchId: 'PERSON-44',
        ),
        _intel(
          id: 'intel-repeat',
          riskScore: 80,
          siteId: 'SITE-VALLEE',
          cameraId: 'driveway-cam',
        ),
        _intel(
          id: 'intel-sandton',
          riskScore: 54,
          siteId: 'SITE-SANDTON',
          cameraId: 'lobby-cam',
        ),
      ];
      final reviews = <String, MonitoringSceneReviewRecord>{
        'intel-escalate': MonitoringSceneReviewRecord(
          intelligenceId: 'intel-escalate',
          sourceLabel: 'openai:gpt-5.4-mini',
          postureLabel: 'boundary loitering concern',
          decisionLabel: 'Escalation Candidate',
          decisionSummary:
              'Escalated for urgent review because person activity was detected.',
          summary: 'Person visible near the front gate.',
          reviewedAtUtc: DateTime.utc(2026, 3, 16, 21, 15),
        ),
        'intel-repeat': MonitoringSceneReviewRecord(
          intelligenceId: 'intel-repeat',
          sourceLabel: 'openai:gpt-5.4-mini',
          postureLabel: 'repeat monitored activity',
          decisionLabel: 'Repeat Activity',
          decisionSummary:
              'Repeat activity update sent because vehicle activity repeated.',
          summary: 'Vehicle made multiple passes through the driveway.',
          reviewedAtUtc: DateTime.utc(2026, 3, 16, 21, 16),
        ),
        'intel-sandton': MonitoringSceneReviewRecord(
          intelligenceId: 'intel-sandton',
          sourceLabel: 'openai:gpt-5.4-mini',
          postureLabel: 'monitored boundary watch',
          decisionLabel: 'Monitoring Alert',
          decisionSummary: 'Routine perimeter watch remains active.',
          summary: 'Sandton remains under active watch.',
          reviewedAtUtc: DateTime.utc(2026, 3, 16, 21, 17),
        ),
      };

      final plans = service.buildPlans(
        events: events,
        sceneReviewByIntelligenceId: reviews,
        videoOpsLabel: 'Hikvision',
      );

      expect(
        plans.map((entry) => entry.actionType),
        containsAll(<String>[
          'PREPOSITION RESPONSE',
          'SYNTHETIC WAR-ROOM',
          'POSTURAL ECHO',
          'GLOBAL POSTURE SHIFT',
          'AUTO-DISPATCH HOLD',
          'PERSISTENCE SWEEP',
        ]),
      );
      final localEscalation = plans.firstWhere(
        (entry) => entry.actionType == 'AUTO-DISPATCH HOLD',
      );
      expect(localEscalation.description, contains('HIKVISION evidence lock'));
      expect(localEscalation.metadata['verdict'], 'Escalation Candidate');
      expect(localEscalation.metadata['camera'], 'gate-cam');
    });

    test('builds simulation posture plans from external pressure alone', () {
      final events = <DispatchEvent>[
        _intel(
          id: 'intel-news',
          riskScore: 79,
          siteId: 'SITE-VALLEE',
          cameraId: 'news-feed',
        ).copyWithSourceType('news', 'Regional pressure rises'),
        _intel(
          id: 'intel-community',
          riskScore: 76,
          siteId: 'SITE-SANDTON',
          cameraId: 'community-feed',
        ).copyWithSourceType('community', 'Suspicious vehicle probing estates'),
      ];

      final plans = service.buildPlans(
        events: events,
        sceneReviewByIntelligenceId: const <String, MonitoringSceneReviewRecord>{},
        videoOpsLabel: 'Hikvision',
      );

      expect(
        plans.map((entry) => entry.actionType),
        containsAll(<String>[
          'PREPOSITION RESPONSE',
          'POSTURAL ECHO',
          'GLOBAL POSTURE SHIFT',
          'SYNTHETIC WAR-ROOM',
        ]),
      );
      expect(
        plans.any((entry) => entry.metadata['scope'] == 'SIMULATION'),
        isTrue,
      );
    });

    test('builds hazard-local plans from the shared hazard policy voice', () {
      final events = <DispatchEvent>[
        _intel(
          id: 'intel-fire',
          riskScore: 88,
          siteId: 'SITE-FIRE',
          cameraId: 'generator-room-cam',
        ),
      ];
      final reviews = <String, MonitoringSceneReviewRecord>{
        'intel-fire': MonitoringSceneReviewRecord(
          intelligenceId: 'intel-fire',
          sourceLabel: 'openai:gpt-5.4-mini',
          postureLabel: 'fire and smoke emergency',
          decisionLabel: 'Escalation Candidate',
          decisionSummary:
              'Escalated for urgent review because fire or smoke indicators were detected.',
          summary: 'Smoke plume visible in the generator room.',
          reviewedAtUtc: DateTime.utc(2026, 3, 16, 21, 15),
        ),
      };

      final plans = service.buildPlans(
        events: events,
        sceneReviewByIntelligenceId: reviews,
        videoOpsLabel: 'Hikvision',
      );

      final localFire = plans.firstWhere(
        (entry) => entry.actionType == 'FIRE ESCALATION',
      );
      expect(
        localFire.description,
        'Promote immediate fire response, notify the partner lane, and preserve HIKVISION evidence for emergency escalation. Escalated for urgent review because fire or smoke indicators were detected.',
      );
    });

    test('builds next-shift fire drafts when synthetic learning repeats', () {
      final events = <DispatchEvent>[
        _intel(
          id: 'intel-fire',
          riskScore: 88,
          siteId: 'SITE-FIRE',
          cameraId: 'generator-room-cam',
        ),
      ];
      final reviews = <String, MonitoringSceneReviewRecord>{
        'intel-fire': MonitoringSceneReviewRecord(
          intelligenceId: 'intel-fire',
          sourceLabel: 'openai:gpt-5.4-mini',
          postureLabel: 'fire and smoke emergency',
          decisionLabel: 'Escalation Candidate',
          decisionSummary:
              'Escalated for urgent review because fire or smoke indicators were detected.',
          summary: 'Smoke plume visible in the generator room.',
          reviewedAtUtc: DateTime.utc(2026, 3, 16, 21, 15),
        ),
      };

      final plans = service.buildPlans(
        events: events,
        sceneReviewByIntelligenceId: reviews,
        videoOpsLabel: 'Hikvision',
        historicalSyntheticLearningLabels: const <String>['ADVANCE FIRE'],
      );

      final nextShiftDraft = plans.firstWhere(
        (entry) => entry.actionType == 'DRAFT NEXT-SHIFT FIRE READINESS',
      );
      expect(nextShiftDraft.metadata['scope'], 'NEXT_SHIFT');
      expect(nextShiftDraft.metadata['mode'], 'DRAFT');
      expect(nextShiftDraft.metadata['learning_label'], 'ADVANCE FIRE');
      expect(nextShiftDraft.description, contains('Prebuild next-shift fire readiness'));
    });
  });
}

IntelligenceReceived _intel({
  required String id,
  required int riskScore,
  required String siteId,
  required String cameraId,
  String faceMatchId = '',
}) {
  return IntelligenceReceived(
    eventId: 'evt-$id',
    sequence: 1,
    version: 1,
    occurredAt: DateTime.utc(2026, 3, 16, 21, 14),
    intelligenceId: id,
    provider: 'hikvision_dvr_monitor_only',
    sourceType: 'dvr',
    externalId: 'ext-$id',
    clientId: 'CLIENT-VALLEE',
    regionId: 'REGION-GAUTENG',
    siteId: siteId,
    cameraId: cameraId,
    faceMatchId: faceMatchId.isEmpty ? null : faceMatchId,
    objectLabel: 'person',
    objectConfidence: 0.92,
    headline: 'HIKVISION LINE CROSSING',
    summary: 'Boundary activity detected',
    riskScore: riskScore,
    snapshotUrl: 'https://edge.example.com/$id.jpg',
    canonicalHash: 'hash-$id',
  );
}

extension on IntelligenceReceived {
  IntelligenceReceived copyWithSourceType(String sourceType, String summary) {
    return IntelligenceReceived(
      eventId: eventId,
      sequence: sequence,
      version: version,
      occurredAt: occurredAt,
      intelligenceId: intelligenceId,
      provider: provider,
      sourceType: sourceType,
      externalId: externalId,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      cameraId: cameraId,
      faceMatchId: faceMatchId,
      objectLabel: objectLabel,
      objectConfidence: objectConfidence,
      headline: headline,
      summary: summary,
      riskScore: riskScore,
      snapshotUrl: snapshotUrl,
      canonicalHash: canonicalHash,
      plateNumber: plateNumber,
    );
  }
}
