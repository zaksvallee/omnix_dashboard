import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/monitoring_watch_scene_assessment_service.dart';
import 'package:omnix_dashboard/application/telegram_client_approval_service.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';

void main() {
  const service = TelegramClientApprovalService();

  test('requires approval for unidentified person scenes that notify client', () {
    final requiresApproval = service.requiresClientApproval(
      event: _intel(objectLabel: 'person', faceMatchId: null, plateNumber: null),
      assessment: const MonitoringWatchSceneAssessment(
        objectLabel: 'person',
        effectiveRiskScore: 80,
        confidence: MonitoringWatchSceneConfidence.medium,
        postureLabel: 'boundary concern',
        shouldNotifyClient: true,
        shouldEscalate: false,
        repeatActivity: false,
      ),
    );

    expect(requiresApproval, isTrue);
  });

  test('does not require approval for escalated or flagged scenes', () {
    expect(
      service.requiresClientApproval(
        event: _intel(objectLabel: 'person'),
        assessment: const MonitoringWatchSceneAssessment(
          objectLabel: 'person',
          effectiveRiskScore: 96,
          confidence: MonitoringWatchSceneConfidence.high,
          postureLabel: 'escalation candidate',
          shouldNotifyClient: true,
          shouldEscalate: true,
          repeatActivity: false,
        ),
      ),
      isFalse,
    );

    expect(
      service.requiresClientApproval(
        event: _intel(objectLabel: 'person', faceMatchId: 'PERSON-44'),
        assessment: const MonitoringWatchSceneAssessment(
          objectLabel: 'person',
          effectiveRiskScore: 82,
          confidence: MonitoringWatchSceneConfidence.medium,
          postureLabel: 'identity match concern',
          shouldNotifyClient: true,
          shouldEscalate: false,
          repeatActivity: false,
          identityRiskSignal: true,
        ),
      ),
      isFalse,
    );
  });

  test('requires approval and can offer memory for unclassified identity match', () {
    final event = _intel(objectLabel: 'person', faceMatchId: 'PERSON-44');
    const assessment = MonitoringWatchSceneAssessment(
      objectLabel: 'person',
      effectiveRiskScore: 80,
      confidence: MonitoringWatchSceneConfidence.medium,
      postureLabel: 'identity match concern',
      shouldNotifyClient: true,
      shouldEscalate: false,
      repeatActivity: false,
    );

    expect(
      service.requiresClientApproval(event: event, assessment: assessment),
      isTrue,
    );
    expect(
      service.canOfferPersistentAllowance(event: event, assessment: assessment),
      isTrue,
    );
  });

  test('parses client decision replies and synonyms', () {
    expect(
      service.parseDecisionText('APPROVE'),
      TelegramClientApprovalDecision.approve,
    );
    expect(
      service.parseDecisionText('flag for review'),
      TelegramClientApprovalDecision.review,
    );
    expect(
      service.parseDecisionText('unapprove'),
      TelegramClientApprovalDecision.escalate,
    );
    expect(service.parseDecisionText('maybe later'), isNull);
  });

  test('parses allowance decision replies and synonyms', () {
    expect(
      service.parseAllowanceDecisionText('ALLOW ONCE'),
      TelegramClientAllowanceDecision.allowOnce,
    );
    expect(
      service.parseAllowanceDecisionText('always'),
      TelegramClientAllowanceDecision.allowAlways,
    );
    expect(service.parseAllowanceDecisionText('review later'), isNull);
  });
}

IntelligenceReceived _intel({
  String objectLabel = 'person',
  String? faceMatchId,
  String? plateNumber,
}) {
  return IntelligenceReceived(
    eventId: 'E-INTEL-1',
    sequence: 1,
    version: 1,
    occurredAt: DateTime.utc(2026, 3, 15, 18, 45),
    intelligenceId: 'INTEL-1',
    provider: 'hikvision',
    sourceType: 'dvr',
    externalId: 'ext-1',
    clientId: 'CLIENT-MS-VALLEE',
    regionId: 'REGION-GAUTENG',
    siteId: 'SITE-MS-VALLEE-RESIDENCE',
    cameraId: 'cam-1',
    objectLabel: objectLabel,
    faceMatchId: faceMatchId,
    plateNumber: plateNumber,
    headline: 'Monitoring person alert',
    summary: 'Unidentified person detected near the gate.',
    riskScore: 78,
    canonicalHash: 'hash',
  );
}
