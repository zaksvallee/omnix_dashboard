import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/mo_promotion_decision_store.dart';

void main() {
  const store = MoPromotionDecisionStore();

  setUp(() {
    store.reset();
  });

  test('defaults to pending before an operator decision exists', () {
    expect(store.decisionStatusFor('MO-1'), 'pending');
    expect(
      store.decisionSummaryFor(
        moId: 'MO-1',
        targetValidationStatus: 'validated',
      ),
      'Pending operator decision for validated review.',
    );
  });

  test('records accepted promotion decisions', () {
    store.accept(moId: 'MO-1', targetValidationStatus: 'validated');

    expect(store.decisionStatusFor('MO-1'), 'accepted');
    expect(
      store.decisionSummaryFor(
        moId: 'MO-1',
        targetValidationStatus: 'validated',
      ),
      'Accepted toward validated review.',
    );
  });

  test('records rejected promotion decisions', () {
    store.reject(moId: 'MO-1', targetValidationStatus: 'shadowMode');

    expect(store.decisionStatusFor('MO-1'), 'rejected');
    expect(
      store.decisionSummaryFor(
        moId: 'MO-1',
        targetValidationStatus: 'shadowMode',
      ),
      'Rejected for shadowMode review for now.',
    );
  });
}
