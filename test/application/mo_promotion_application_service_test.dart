import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/mo_knowledge_repository.dart';
import 'package:omnix_dashboard/application/mo_promotion_application_service.dart';
import 'package:omnix_dashboard/application/mo_promotion_decision_store.dart';
import 'package:omnix_dashboard/domain/intelligence/onyx_mo_record.dart';

void main() {
  const decisionStore = MoPromotionDecisionStore();
  const service = MoPromotionApplicationService();

  setUp(() {
    decisionStore.reset();
  });

  test('promotes accepted MO records to the target validation status', () {
    final repository = InMemoryMoKnowledgeRepository(
      seedRecords: {
        'MO-1': OnyxMoRecord(
          moId: 'MO-1',
          title: 'Office impersonation',
          summary: 'Contractor impersonation pattern.',
          sourceType: OnyxMoSourceType.externalIncident,
          firstSeenUtc: DateTime.utc(2026, 3, 10),
          lastSeenUtc: DateTime.utc(2026, 3, 10),
          validationStatus: OnyxMoValidationStatus.shadowMode,
        ),
      },
    );
    decisionStore.accept(moId: 'MO-1', targetValidationStatus: 'validated');

    final count = service.applyOperatorDecisions(
      repository: repository,
      appliedAtUtc: DateTime.utc(2026, 3, 17, 6),
    );

    expect(count, 1);
    final record = repository.readAll().first;
    expect(record.validationStatus, OnyxMoValidationStatus.validated);
    expect(record.metadata['promotion_decision_status'], 'accepted');
    expect(record.metadata['promotion_target_status'], 'validated');
    expect(record.metadata['runtime_match_bias'], 'PROMOTED_VALIDATED');
    expect(record.metadata['runtime_match_weight'], 0.08);
  });

  test('records rejected decisions without promoting validation state', () {
    final repository = InMemoryMoKnowledgeRepository(
      seedRecords: {
        'MO-1': OnyxMoRecord(
          moId: 'MO-1',
          title: 'Office impersonation',
          summary: 'Contractor impersonation pattern.',
          sourceType: OnyxMoSourceType.externalIncident,
          firstSeenUtc: DateTime.utc(2026, 3, 10),
          lastSeenUtc: DateTime.utc(2026, 3, 10),
          validationStatus: OnyxMoValidationStatus.shadowMode,
        ),
      },
    );
    decisionStore.reject(moId: 'MO-1', targetValidationStatus: 'validated');

    final count = service.applyOperatorDecisions(
      repository: repository,
      appliedAtUtc: DateTime.utc(2026, 3, 17, 6),
    );

    expect(count, 1);
    final record = repository.readAll().first;
    expect(record.validationStatus, OnyxMoValidationStatus.shadowMode);
    expect(record.metadata['promotion_decision_status'], 'rejected');
    expect(record.metadata['promotion_target_status'], 'validated');
    expect(record.metadata['runtime_match_bias'], 'REVIEW_HOLD');
    expect(record.metadata['runtime_match_weight'], 0.0);
  });
}
