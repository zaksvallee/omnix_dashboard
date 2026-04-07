import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/monitoring_watch_client_notification_gate_service.dart';
import 'package:omnix_dashboard/application/monitoring_watch_escalation_policy_service.dart';
import 'package:omnix_dashboard/application/monitoring_watch_runtime_store.dart';

void main() {
  group('MonitoringWatchClientNotificationGateService', () {
    const service = MonitoringWatchClientNotificationGateService();

    test('allows first automated watch notification', () {
      final runtime = MonitoringWatchRuntimeState(
        startedAtUtc: DateTime.utc(2026, 3, 18, 8),
      );
      const decision = MonitoringWatchEscalationDecision(
        kind: MonitoringWatchNotificationKind.escalationCandidate,
        title: 'ONYX Escalation Review',
        messageKeyPrefix: 'tg-watch-auto-escalation',
        incidentStatusLabel: 'Escalation Candidate',
        decisionSummary: 'Escalated for urgent review because person activity was detected.',
        shouldNotifyClient: true,
        shouldIncrementEscalation: true,
      );

      final result = service.decide(
        runtime: runtime,
        decision: decision,
        occurredAtUtc: DateTime.utc(2026, 3, 18, 9),
      );

      expect(result.shouldNotifyClient, isTrue);
    });

    test('suppresses repeated escalation inside cooldown', () {
      final runtime = MonitoringWatchRuntimeState(
        startedAtUtc: DateTime.utc(2026, 3, 18, 8),
        latestClientNotificationLabel: 'Escalation Candidate',
        latestClientNotificationSummary: 'Earlier escalation candidate sent.',
        latestClientNotificationAtUtc: DateTime.utc(2026, 3, 18, 9, 2),
      );
      const decision = MonitoringWatchEscalationDecision(
        kind: MonitoringWatchNotificationKind.escalationCandidate,
        title: 'ONYX Escalation Review',
        messageKeyPrefix: 'tg-watch-auto-escalation',
        incidentStatusLabel: 'Escalation Candidate',
        decisionSummary: 'Escalated for urgent review because person activity was detected.',
        shouldNotifyClient: true,
        shouldIncrementEscalation: true,
      );

      final result = service.decide(
        runtime: runtime,
        decision: decision,
        occurredAtUtc: DateTime.utc(2026, 3, 18, 9, 6),
      );

      expect(result.shouldNotifyClient, isFalse);
      expect(result.summary, contains('already sent'));
    });

    test('allows escalation when recent message was lower severity', () {
      final runtime = MonitoringWatchRuntimeState(
        startedAtUtc: DateTime.utc(2026, 3, 18, 8),
        latestClientNotificationLabel: 'Monitoring Alert',
        latestClientNotificationSummary: 'Earlier alert sent.',
        latestClientNotificationAtUtc: DateTime.utc(2026, 3, 18, 9, 2),
      );
      const decision = MonitoringWatchEscalationDecision(
        kind: MonitoringWatchNotificationKind.escalationCandidate,
        title: 'ONYX Escalation Review',
        messageKeyPrefix: 'tg-watch-auto-escalation',
        incidentStatusLabel: 'Escalation Candidate',
        decisionSummary: 'Escalated for urgent review because person activity was detected.',
        shouldNotifyClient: true,
        shouldIncrementEscalation: true,
      );

      final result = service.decide(
        runtime: runtime,
        decision: decision,
        occurredAtUtc: DateTime.utc(2026, 3, 18, 9, 4),
      );

      expect(result.shouldNotifyClient, isTrue);
      expect(result.summary, contains('posture escalated'));
    });

    test('suppresses first non-threat automated watch updates for client lane', () {
      final runtime = MonitoringWatchRuntimeState(
        startedAtUtc: DateTime.utc(2026, 3, 18, 8),
      );
      const decision = MonitoringWatchEscalationDecision(
        kind: MonitoringWatchNotificationKind.incident,
        title: 'ONYX Monitoring Alert',
        messageKeyPrefix: 'tg-watch-auto-alert',
        incidentStatusLabel: 'Monitoring Alert',
        decisionSummary:
            'Client alert sent because vehicle activity was detected.',
        shouldNotifyClient: true,
        shouldIncrementEscalation: false,
      );

      final result = service.decide(
        runtime: runtime,
        decision: decision,
        occurredAtUtc: DateTime.utc(2026, 3, 18, 9),
      );

      expect(result.shouldNotifyClient, isFalse);
      expect(result.summary, contains('client threat threshold'));
    });

    test('suppresses escalation candidate without usable visual evidence', () {
      final runtime = MonitoringWatchRuntimeState(
        startedAtUtc: DateTime.utc(2026, 3, 18, 8),
      );
      const decision = MonitoringWatchEscalationDecision(
        kind: MonitoringWatchNotificationKind.escalationCandidate,
        title: 'ONYX Escalation Review',
        messageKeyPrefix: 'tg-watch-auto-escalation',
        incidentStatusLabel: 'Escalation Candidate',
        decisionSummary:
            'Escalated for urgent review because person activity was detected.',
        shouldNotifyClient: true,
        shouldIncrementEscalation: true,
      );

      final result = service.decide(
        runtime: runtime,
        decision: decision,
        occurredAtUtc: DateTime.utc(2026, 3, 18, 9),
        hasUsableVisualEvidence: false,
      );

      expect(result.shouldNotifyClient, isFalse);
      expect(result.summary, contains('usable verification image'));
    });

    test('suppresses escalation candidate when monitoring path is unavailable', () {
      final runtime = MonitoringWatchRuntimeState(
        startedAtUtc: DateTime.utc(2026, 3, 18, 8),
        monitoringAvailable: false,
        monitoringAvailabilityDetail: 'Camera 11 is disconnected.',
      );
      const decision = MonitoringWatchEscalationDecision(
        kind: MonitoringWatchNotificationKind.escalationCandidate,
        title: 'ONYX Escalation Review',
        messageKeyPrefix: 'tg-watch-auto-escalation',
        incidentStatusLabel: 'Escalation Candidate',
        decisionSummary:
            'Escalated for urgent review because person activity was detected.',
        shouldNotifyClient: true,
        shouldIncrementEscalation: true,
      );

      final result = service.decide(
        runtime: runtime,
        decision: decision,
        occurredAtUtc: DateTime.utc(2026, 3, 18, 9),
        monitoringAvailable: false,
      );

      expect(result.shouldNotifyClient, isFalse);
      expect(result.summary, contains('live monitoring path'));
    });
  });
}
