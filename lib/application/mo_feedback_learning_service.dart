import 'mo_runtime_matching_service.dart';
import 'mo_promotion_decision_store.dart';

class MoPromotionGuidance {
  final String moId;
  final String title;
  final String currentValidationStatus;
  final String targetValidationStatus;
  final String confidenceBias;
  final String trendBias;
  final String summary;

  const MoPromotionGuidance({
    required this.moId,
    required this.title,
    required this.currentValidationStatus,
    required this.targetValidationStatus,
    required this.confidenceBias,
    required this.trendBias,
    required this.summary,
  });
}

class MoFeedbackLearningService {
  final MoPromotionDecisionStore decisionStore;

  const MoFeedbackLearningService({
    this.decisionStore = const MoPromotionDecisionStore(),
  });

  MoPromotionGuidance? buildShadowPromotionGuidance({
    required List<OnyxMoShadowMatch> matches,
    required int repeatedShadowCount,
  }) {
    if (matches.isEmpty || repeatedShadowCount <= 0) {
      return null;
    }
    final lead = matches.first;
    final currentStatus = lead.validationStatus.trim();
    final targetStatus = _targetStatusFor(currentStatus);
    if (targetStatus.isEmpty) {
      return null;
    }
    final decision = decisionStore.decisionFor(lead.moId);
    final decisionStatus = decision?.status.name ?? 'pending';
    final confidenceBias = repeatedShadowCount >= 2 ? 'HIGH' : 'MEDIUM';
    final trendBias = repeatedShadowCount >= 2 ? '+0.25' : '+0.12';
    if (decisionStatus == 'rejected' && repeatedShadowCount <= 1) {
      return MoPromotionGuidance(
        moId: lead.moId,
        title: lead.title,
        currentValidationStatus: currentStatus,
        targetValidationStatus: targetStatus,
        confidenceBias: 'HOLD',
        trendBias: '+0.00',
        summary:
            'Hold ${lead.moId} after operator rejection • ${lead.title} • x$repeatedShadowCount',
      );
    }
    if (decisionStatus == 'accepted') {
      return MoPromotionGuidance(
        moId: lead.moId,
        title: lead.title,
        currentValidationStatus: currentStatus,
        targetValidationStatus: targetStatus,
        confidenceBias: 'LOCKED',
        trendBias: '+0.00',
        summary:
            'Promotion accepted for ${lead.moId} toward $targetStatus review • ${lead.title}',
      );
    }
    final summary = decisionStatus == 'rejected'
        ? 'Reopen ${lead.moId} toward $targetStatus review after repeated shadow pressure • ${lead.title} • x$repeatedShadowCount'
        : 'Promote ${lead.moId} toward $targetStatus review • ${lead.title} • x$repeatedShadowCount';
    return MoPromotionGuidance(
      moId: lead.moId,
      title: lead.title,
      currentValidationStatus: currentStatus,
      targetValidationStatus: targetStatus,
      confidenceBias: confidenceBias,
      trendBias: trendBias,
      summary: summary,
    );
  }

  String _targetStatusFor(String currentStatus) {
    return switch (currentStatus.trim()) {
      'candidate' => 'shadowMode',
      'canonicalized' => 'shadowMode',
      'shadowMode' => 'validated',
      'validated' => 'validated',
      _ => '',
    };
  }
}
