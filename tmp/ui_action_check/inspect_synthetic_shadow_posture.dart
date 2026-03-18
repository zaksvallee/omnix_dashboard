import 'package:omnix_dashboard/application/monitoring_scene_review_store.dart';
import 'package:omnix_dashboard/application/monitoring_synthetic_war_room_service.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';

IntelligenceReceived intel({required String id, required String regionId, required String siteId, required int riskScore, required String cameraId, String sourceType='dvr', String headline='HIKVISION ALERT', String summary='Boundary activity detected'}) {
  return IntelligenceReceived(
    eventId: 'evt-$id',
    sequence: 1,
    version: 1,
    occurredAt: DateTime.utc(2026, 3, 16, 22, 25),
    intelligenceId: id,
    provider: 'hikvision_dvr_monitor_only',
    sourceType: sourceType,
    externalId: 'ext-$id',
    clientId: 'CLIENT-VALLEE',
    regionId: regionId,
    siteId: siteId,
    cameraId: cameraId,
    objectLabel: 'person',
    objectConfidence: 0.94,
    headline: headline,
    summary: summary,
    riskScore: riskScore,
    snapshotUrl: 'https://edge.example.com/$id.jpg',
    canonicalHash: 'hash-$id',
  );
}

void main() {
  const service = MonitoringSyntheticWarRoomService();
  final events = <DispatchEvent>[
    intel(id: 'news-office-posture', regionId: 'REGION-GAUTENG', siteId: 'SITE-SEED', riskScore: 67, cameraId: 'news-feed', sourceType: 'news', headline: 'Contractors roamed office floors before device theft', summary: 'Suspects posed as maintenance contractors, moved floor to floor, and checked restricted office doors.'),
    intel(id: 'intel-office-posture-1', regionId: 'REGION-GAUTENG', siteId: 'SITE-VALLEE', riskScore: 86, cameraId: 'office-cam-1', headline: 'Maintenance contractor probing office doors', summary: 'Contractor-like person moved floor to floor and tried several restricted office doors.'),
    intel(id: 'intel-office-posture-2', regionId: 'REGION-GAUTENG', siteId: 'SITE-VALLEE', riskScore: 87, cameraId: 'office-cam-2', headline: 'Maintenance contractor repeating office sweep', summary: 'Contractor-like person moved floor to floor, returned to restricted office doors, and kept probing access.'),
    intel(id: 'intel-office-posture-3', regionId: 'REGION-GAUTENG', siteId: 'SITE-VALLEE', riskScore: 89, cameraId: 'office-cam-3', headline: 'Contractor-like person revisits office floors', summary: 'Service-looking person moved across multiple office zones and checked several restricted rooms again.'),
  ];
  final reviews = <String, MonitoringSceneReviewRecord>{
    'intel-office-posture-1': MonitoringSceneReviewRecord(
      intelligenceId: 'intel-office-posture-1',
      sourceLabel: 'openai:gpt-5.4-mini',
      postureLabel: 'service impersonation and roaming concern',
      decisionLabel: 'Escalation Candidate',
      decisionSummary: 'Likely spoofed service access with abnormal roaming.',
      summary: 'Likely maintenance impersonation moving across office zones.',
      reviewedAtUtc: DateTime.utc(2026, 3, 16, 22, 0),
    ),
    'intel-office-posture-2': MonitoringSceneReviewRecord(
      intelligenceId: 'intel-office-posture-2',
      sourceLabel: 'openai:gpt-5.4-mini',
      postureLabel: 'service impersonation and roaming concern',
      decisionLabel: 'Escalation Candidate',
      decisionSummary: 'Likely spoofed service access with abnormal roaming.',
      summary: 'Likely maintenance impersonation moving across office zones again.',
      reviewedAtUtc: DateTime.utc(2026, 3, 16, 22, 5),
    ),
    'intel-office-posture-3': MonitoringSceneReviewRecord(
      intelligenceId: 'intel-office-posture-3',
      sourceLabel: 'openai:gpt-5.4-mini',
      postureLabel: 'service impersonation and roaming concern',
      decisionLabel: 'Escalation Candidate',
      decisionSummary: 'Likely spoofed service access with abnormal roaming.',
      summary: 'Likely maintenance impersonation moving across office zones repeatedly.',
      reviewedAtUtc: DateTime.utc(2026, 3, 16, 22, 10),
    ),
  };

  final plans = service.buildSimulationPlans(events: events, sceneReviewByIntelligenceId: reviews, videoOpsLabel: 'Hikvision');
  for (final p in plans) {
    print('PLAN ${p.actionType} priority=${p.priority} countdown=${p.countdownSeconds}');
    print(p.metadata);
    print(p.description);
  }
}
