import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/domain/guard/outcome_label_governance.dart';

void main() {
  group('OutcomeLabelGovernancePolicy', () {
    test('default policy enforces supervisor for true_threat', () {
      final policy = OutcomeLabelGovernancePolicy.defaultPolicy();

      expect(
        policy.allows(outcomeLabel: 'true_threat', confirmedBy: 'supervisor'),
        isTrue,
      );
      expect(
        policy.allows(outcomeLabel: 'true_threat', confirmedBy: 'control'),
        isFalse,
      );
      expect(
        policy.allows(outcomeLabel: 'false_alarm', confirmedBy: 'control'),
        isTrue,
      );
      expect(policy.policyVersion, 'v1');
      expect(
        policy.ruleIdFor('true_threat'),
        'outcome.true_threat.supervisor_required',
      );
    });

    test('fromJsonString parses incident-class confirmer matrix', () {
      final fallback = OutcomeLabelGovernancePolicy.defaultPolicy();
      final policy = OutcomeLabelGovernancePolicy.fromJsonString(
        '{"true_threat":["supervisor","control"],"false_alarm":["control"]}',
        fallback: fallback,
      );

      expect(
        policy.allows(outcomeLabel: 'true_threat', confirmedBy: 'control'),
        isTrue,
      );
      expect(
        policy.allows(outcomeLabel: 'false_alarm', confirmedBy: 'supervisor'),
        isFalse,
      );
      expect(policy.allowedConfirmers('false_alarm'), {'control'});
      expect(policy.ruleIdFor('false_alarm'), 'outcome.false_alarm.standard');
    });

    test('fromJsonString parses versioned rules with rule ids', () {
      final fallback = OutcomeLabelGovernancePolicy.defaultPolicy();
      final policy = OutcomeLabelGovernancePolicy.fromJsonString(
        '{"version":"pilot-2026-03","rules":{"true_threat":{"allowed_confirmers":["supervisor"],"rule_id":"pilot.true_threat.supervisor_only"},"false_alarm":{"allowed_confirmers":["control","supervisor"],"rule_id":"pilot.false_alarm.dual"}}}',
        fallback: fallback,
      );

      expect(policy.policyVersion, 'pilot-2026-03');
      expect(
        policy.allows(outcomeLabel: 'false_alarm', confirmedBy: 'control'),
        isTrue,
      );
      expect(
        policy.allows(outcomeLabel: 'false_alarm', confirmedBy: 'guard'),
        isFalse,
      );
      expect(
        policy.ruleIdFor('true_threat'),
        'pilot.true_threat.supervisor_only',
      );
      expect(policy.ruleIdFor('false_alarm'), 'pilot.false_alarm.dual');
    });
  });
}
