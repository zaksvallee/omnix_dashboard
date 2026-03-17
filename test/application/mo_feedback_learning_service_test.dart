import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/mo_feedback_learning_service.dart';
import 'package:omnix_dashboard/application/mo_promotion_decision_store.dart';
import 'package:omnix_dashboard/application/mo_runtime_matching_service.dart';

void main() {
  const decisionStore = MoPromotionDecisionStore();
  const service = MoFeedbackLearningService();

  setUp(() {
    decisionStore.reset();
  });

  test('builds default promotion guidance for repeated shadow matches', () {
    final guidance = service.buildShadowPromotionGuidance(
      matches: const [
        OnyxMoShadowMatch(
          moId: 'MO-1',
          title: 'Office impersonation pattern',
          incidentType: 'access_abuse',
          behaviorStage: 'entry',
          validationStatus: 'shadowMode',
          matchScore: 0.81,
        ),
      ],
      repeatedShadowCount: 1,
    );

    expect(guidance, isNotNull);
    expect(guidance!.confidenceBias, 'MEDIUM');
    expect(guidance.trendBias, '+0.12');
    expect(guidance.summary, contains('Promote MO-1 toward validated review'));
  });

  test('locks guidance after an accepted operator decision', () {
    decisionStore.accept(moId: 'MO-1', targetValidationStatus: 'validated');

    final guidance = service.buildShadowPromotionGuidance(
      matches: const [
        OnyxMoShadowMatch(
          moId: 'MO-1',
          title: 'Office impersonation pattern',
          incidentType: 'access_abuse',
          behaviorStage: 'entry',
          validationStatus: 'shadowMode',
          matchScore: 0.81,
        ),
      ],
      repeatedShadowCount: 1,
    );

    expect(guidance, isNotNull);
    expect(guidance!.confidenceBias, 'LOCKED');
    expect(guidance.trendBias, '+0.00');
    expect(guidance.summary, contains('Promotion accepted for MO-1'));
  });

  test('holds guidance after a rejected decision until pressure repeats', () {
    decisionStore.reject(moId: 'MO-1', targetValidationStatus: 'validated');

    final guidance = service.buildShadowPromotionGuidance(
      matches: const [
        OnyxMoShadowMatch(
          moId: 'MO-1',
          title: 'Office impersonation pattern',
          incidentType: 'access_abuse',
          behaviorStage: 'entry',
          validationStatus: 'shadowMode',
          matchScore: 0.81,
        ),
      ],
      repeatedShadowCount: 1,
    );

    expect(guidance, isNotNull);
    expect(guidance!.confidenceBias, 'HOLD');
    expect(guidance.trendBias, '+0.00');
    expect(guidance.summary, contains('Hold MO-1 after operator rejection'));
  });

  test('reopens guidance after repeated shadow pressure post-rejection', () {
    decisionStore.reject(moId: 'MO-1', targetValidationStatus: 'validated');

    final guidance = service.buildShadowPromotionGuidance(
      matches: const [
        OnyxMoShadowMatch(
          moId: 'MO-1',
          title: 'Office impersonation pattern',
          incidentType: 'access_abuse',
          behaviorStage: 'entry',
          validationStatus: 'shadowMode',
          matchScore: 0.81,
        ),
      ],
      repeatedShadowCount: 2,
    );

    expect(guidance, isNotNull);
    expect(guidance!.confidenceBias, 'HIGH');
    expect(guidance.trendBias, '+0.25');
    expect(
      guidance.summary,
      contains('Reopen MO-1 toward validated review after repeated shadow pressure'),
    );
  });
}
