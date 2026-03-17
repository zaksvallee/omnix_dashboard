import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/monitoring_watch_escalation_policy_service.dart';
import 'package:omnix_dashboard/application/monitoring_watch_scene_assessment_service.dart';

void main() {
  group('MonitoringWatchEscalationPolicyService', () {
    const service = MonitoringWatchEscalationPolicyService();

    test('suppresses low-significance assessment', () {
      final decision = service.decide(
        const MonitoringWatchSceneAssessment(
          objectLabel: 'animal',
          effectiveRiskScore: 32,
          confidence: MonitoringWatchSceneConfidence.low,
          postureLabel: 'monitored movement alert',
          shouldNotifyClient: false,
          shouldEscalate: false,
          repeatActivity: false,
        ),
      );

      expect(decision.kind, MonitoringWatchNotificationKind.suppressed);
      expect(decision.shouldNotifyClient, isFalse);
      expect(decision.decisionSummary, contains('Suppressed'));
    });

    test('routes repeated activity into repeat update', () {
      final decision = service.decide(
        const MonitoringWatchSceneAssessment(
          objectLabel: 'vehicle',
          effectiveRiskScore: 88,
          confidence: MonitoringWatchSceneConfidence.high,
          postureLabel: 'repeat monitored activity',
          shouldNotifyClient: true,
          shouldEscalate: false,
          repeatActivity: true,
        ),
      );

      expect(decision.kind, MonitoringWatchNotificationKind.repeat);
      expect(decision.incidentStatusLabel, 'Repeat Activity');
      expect(decision.shouldIncrementEscalation, isTrue);
      expect(decision.decisionSummary, contains('Repeat activity update sent'));
      expect(decision.decisionSummary, contains('vehicle activity was detected'));
    });

    test('routes escalation candidates into urgent review', () {
      final decision = service.decide(
        const MonitoringWatchSceneAssessment(
          objectLabel: 'person',
          effectiveRiskScore: 96,
          confidence: MonitoringWatchSceneConfidence.high,
          postureLabel: 'escalation candidate',
          shouldNotifyClient: true,
          shouldEscalate: true,
          repeatActivity: true,
        ),
      );

      expect(
        decision.kind,
        MonitoringWatchNotificationKind.escalationCandidate,
      );
      expect(decision.title, 'ONYX Escalation Review');
      expect(decision.shouldIncrementEscalation, isTrue);
      expect(decision.decisionSummary, contains('Escalated for urgent review'));
      expect(decision.decisionSummary, contains('person activity was detected'));
    });

    test('uses fire-specific escalation rationale for fire emergencies', () {
      final decision = service.decide(
        const MonitoringWatchSceneAssessment(
          objectLabel: 'smoke',
          effectiveRiskScore: 99,
          confidence: MonitoringWatchSceneConfidence.high,
          postureLabel: 'fire and smoke emergency',
          shouldNotifyClient: true,
          shouldEscalate: true,
          repeatActivity: false,
          fireSignal: true,
        ),
      );

      expect(
        decision.kind,
        MonitoringWatchNotificationKind.escalationCandidate,
      );
      expect(
        decision.decisionSummary,
        contains('fire or smoke indicators were detected'),
      );
      expect(decision.decisionSummary, isNot(contains('activity was detected')));
    });

    test('uses water-specific escalation rationale for flood or leak emergencies', () {
      final decision = service.decide(
        const MonitoringWatchSceneAssessment(
          objectLabel: 'water',
          effectiveRiskScore: 95,
          confidence: MonitoringWatchSceneConfidence.high,
          postureLabel: 'flood or leak emergency',
          shouldNotifyClient: true,
          shouldEscalate: true,
          repeatActivity: false,
          waterLeakSignal: true,
        ),
      );

      expect(
        decision.kind,
        MonitoringWatchNotificationKind.escalationCandidate,
      );
      expect(
        decision.decisionSummary,
        contains('water leak or flooding indicators were detected'),
      );
      expect(decision.decisionSummary, isNot(contains('activity was detected')));
    });

    test('includes boundary, loitering, grouping, and confidence in alert rationale', () {
      final decision = service.decide(
        const MonitoringWatchSceneAssessment(
          objectLabel: 'person',
          effectiveRiskScore: 82,
          confidence: MonitoringWatchSceneConfidence.high,
          postureLabel: 'boundary loitering concern',
          shouldNotifyClient: true,
          shouldEscalate: false,
          repeatActivity: false,
          boundaryConcern: true,
          loiteringConcern: true,
          groupedEventCount: 3,
        ),
      );

      expect(decision.kind, MonitoringWatchNotificationKind.incident);
      expect(
        decision.decisionSummary,
        contains('the scene suggested boundary proximity'),
      );
      expect(
        decision.decisionSummary,
        contains('the scene suggested possible loitering'),
      );
      expect(decision.decisionSummary, contains('3 correlated signals arrived'));
      expect(decision.decisionSummary, contains('confidence remained high'));
    });

    test('includes FR/LPR watchlist rationale in escalation summary', () {
      final decision = service.decide(
        const MonitoringWatchSceneAssessment(
          objectLabel: 'vehicle',
          effectiveRiskScore: 97,
          confidence: MonitoringWatchSceneConfidence.high,
          postureLabel: 'escalation candidate',
          shouldNotifyClient: true,
          shouldEscalate: true,
          repeatActivity: false,
          faceMatchId: 'PERSON-44',
          plateNumber: 'CA123456',
          identityRiskSignal: true,
        ),
      );

      expect(
        decision.kind,
        MonitoringWatchNotificationKind.escalationCandidate,
      );
      expect(
        decision.decisionSummary,
        contains('face match PERSON-44 was flagged'),
      );
      expect(decision.decisionSummary, contains('plate CA123456 was flagged'));
      expect(
        decision.decisionSummary,
        contains('the event metadata suggested an unauthorized or watchlist context'),
      );
    });

    test('uses allowlist-specific suppression summary for known identities', () {
      final decision = service.decide(
        const MonitoringWatchSceneAssessment(
          objectLabel: 'vehicle',
          effectiveRiskScore: 40,
          confidence: MonitoringWatchSceneConfidence.medium,
          postureLabel: 'known allowed identity',
          shouldNotifyClient: false,
          shouldEscalate: false,
          repeatActivity: false,
          faceMatchId: 'RESIDENT-01',
          plateNumber: 'CA111111',
          identityAllowedSignal: true,
        ),
      );

      expect(decision.kind, MonitoringWatchNotificationKind.suppressed);
      expect(
        decision.decisionSummary,
        'Suppressed because the matched identity is allowlisted for this site and the activity remained below the client notification threshold.',
      );
    });
  });
}
