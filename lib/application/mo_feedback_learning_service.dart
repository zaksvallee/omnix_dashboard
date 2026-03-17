import 'mo_runtime_matching_service.dart';

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
  const MoFeedbackLearningService();

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
    final confidenceBias = repeatedShadowCount >= 2 ? 'HIGH' : 'MEDIUM';
    final trendBias = repeatedShadowCount >= 2 ? '+0.25' : '+0.12';
    final summary =
        'Promote ${lead.moId} toward $targetStatus review • ${lead.title} • x$repeatedShadowCount';
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
