import '../domain/intelligence/onyx_mo_record.dart';
import 'mo_knowledge_repository.dart';
import 'mo_promotion_decision_store.dart';

class MoPromotionApplicationService {
  final MoPromotionDecisionStore decisionStore;

  const MoPromotionApplicationService({
    this.decisionStore = const MoPromotionDecisionStore(),
  });

  int applyOperatorDecisions({
    required MoKnowledgeRepository repository,
    DateTime? appliedAtUtc,
  }) {
    final appliedAt = (appliedAtUtc ?? DateTime.now()).toUtc();
    var updatedCount = 0;
    for (final record in repository.readAll()) {
      final decision = decisionStore.decisionFor(record.moId);
      if (decision == null) {
        continue;
      }
      final nextRecord = _applyDecision(
        record: record,
        decision: decision,
        appliedAtUtc: appliedAt,
      );
      if (nextRecord == null) {
        continue;
      }
      repository.upsert(nextRecord);
      updatedCount += 1;
    }
    return updatedCount;
  }

  OnyxMoRecord? _applyDecision({
    required OnyxMoRecord record,
    required MoPromotionDecisionRecord decision,
    required DateTime appliedAtUtc,
  }) {
    final decisionStatus = decision.status.name;
    final targetStatus = _validationStatusFor(decision.targetValidationStatus);
    final metadata = <String, Object?>{
      ...record.metadata,
      'promotion_decision_status': decisionStatus,
      'promotion_target_status': decision.targetValidationStatus,
      'promotion_decided_at_utc': decision.decidedAtUtc.toIso8601String(),
      'promotion_applied_at_utc': appliedAtUtc.toIso8601String(),
    };
    if (decision.status == MoPromotionDecisionStatus.accepted &&
        targetStatus != null &&
        targetStatus != record.validationStatus) {
      return record.copyWith(
        validationStatus: targetStatus,
        lastSeenUtc: appliedAtUtc.isAfter(record.lastSeenUtc)
            ? appliedAtUtc
            : record.lastSeenUtc,
        metadata: <String, Object?>{
          ...metadata,
          'runtime_match_bias': _runtimeMatchBiasFor(targetStatus),
          'runtime_match_weight': _runtimeMatchWeightFor(targetStatus),
        },
      );
    }
    if (decision.status == MoPromotionDecisionStatus.rejected ||
        decision.status == MoPromotionDecisionStatus.accepted) {
      return record.copyWith(
        metadata: <String, Object?>{
          ...metadata,
          if (decision.status == MoPromotionDecisionStatus.rejected)
            'runtime_match_bias': 'REVIEW_HOLD',
          if (decision.status == MoPromotionDecisionStatus.rejected)
            'runtime_match_weight': 0.0,
        },
      );
    }
    return null;
  }

  OnyxMoValidationStatus? _validationStatusFor(String raw) {
    final normalized = raw.trim();
    for (final status in OnyxMoValidationStatus.values) {
      if (status.name == normalized) {
        return status;
      }
    }
    return null;
  }

  String _runtimeMatchBiasFor(OnyxMoValidationStatus status) {
    switch (status) {
      case OnyxMoValidationStatus.production:
        return 'PROMOTED_PRODUCTION';
      case OnyxMoValidationStatus.validated:
        return 'PROMOTED_VALIDATED';
      case OnyxMoValidationStatus.shadowMode:
        return 'PROMOTED_SHADOW';
      case OnyxMoValidationStatus.candidate:
      case OnyxMoValidationStatus.canonicalized:
        return 'PROMOTED_CANDIDATE';
    }
  }

  double _runtimeMatchWeightFor(OnyxMoValidationStatus status) {
    switch (status) {
      case OnyxMoValidationStatus.production:
        return 0.12;
      case OnyxMoValidationStatus.validated:
        return 0.08;
      case OnyxMoValidationStatus.shadowMode:
        return 0.04;
      case OnyxMoValidationStatus.candidate:
      case OnyxMoValidationStatus.canonicalized:
        return 0.02;
    }
  }
}
