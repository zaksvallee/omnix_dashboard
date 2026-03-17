import 'monitoring_watch_action_plan.dart';

String _firstSyntheticPlanMetadata(
  List<MonitoringWatchAutonomyActionPlan> plans,
  String key,
) {
  return plans
      .map((plan) => (plan.metadata[key] ?? '').trim())
      .firstWhere((value) => value.isNotEmpty, orElse: () => '');
}

String buildSyntheticPromotionIdFromPlans({
  required List<MonitoringWatchAutonomyActionPlan> plans,
}) => _firstSyntheticPlanMetadata(plans, 'mo_promotion_id');

String buildSyntheticPromotionTargetStatusFromPlans({
  required List<MonitoringWatchAutonomyActionPlan> plans,
}) => _firstSyntheticPlanMetadata(plans, 'mo_promotion_target');

String buildSyntheticPromotionDecisionStatusFromPlans({
  required List<MonitoringWatchAutonomyActionPlan> plans,
  required String Function(String moId) decisionStatusLookup,
}) {
  final moId = buildSyntheticPromotionIdFromPlans(plans: plans);
  if (moId.isEmpty) {
    return '';
  }
  return decisionStatusLookup(moId);
}

String buildSyntheticLearningSummaryFromPlans({
  required List<MonitoringWatchAutonomyActionPlan> plans,
}) => _firstSyntheticPlanMetadata(plans, 'learning_summary');

String buildSyntheticLearningLabelFromPlans({
  required List<MonitoringWatchAutonomyActionPlan> plans,
}) => _firstSyntheticPlanMetadata(plans, 'learning_label');

String buildSyntheticShadowLearningSummaryFromPlans({
  required List<MonitoringWatchAutonomyActionPlan> plans,
}) => _firstSyntheticPlanMetadata(plans, 'shadow_learning_summary');

String buildSyntheticShadowMemorySummaryFromPlans({
  required List<MonitoringWatchAutonomyActionPlan> plans,
}) => _firstSyntheticPlanMetadata(plans, 'shadow_memory_summary');

String buildSyntheticShadowPostureBiasSummaryForPlan({
  MonitoringWatchAutonomyActionPlan? plan,
}) {
  final prebuiltSummary =
      (plan?.metadata['shadow_posture_bias_summary'] ?? '').trim();
  if (prebuiltSummary.isNotEmpty) {
    return prebuiltSummary;
  }
  final postureBias = (plan?.metadata['shadow_posture_bias'] ?? '').trim();
  final posturePriority = (plan?.metadata['shadow_posture_priority'] ?? '')
      .trim();
  final postureCountdown = (plan?.metadata['shadow_posture_countdown'] ?? '')
      .trim();
  if (postureBias.isEmpty &&
      posturePriority.isEmpty &&
      postureCountdown.isEmpty) {
    return '';
  }
  final parts = <String>[
    if (postureBias.isNotEmpty) postureBias,
    if (posturePriority.isNotEmpty) posturePriority,
    if (postureCountdown.isNotEmpty) '${postureCountdown}s',
  ];
  return parts.join(' • ');
}

String buildSyntheticPromotionSummary({
  required String baseSummary,
  String shadowTomorrowUrgencySummary = '',
  String previousShadowTomorrowUrgencySummary = '',
  String shadowPostureBiasSummary = '',
}) {
  final normalizedBase = baseSummary.trim();
  if (normalizedBase.isEmpty) {
    return '';
  }
  final currentUrgency = shadowTomorrowUrgencySummary.trim();
  final previousUrgency = previousShadowTomorrowUrgencySummary.trim();
  final postureBias = shadowPostureBiasSummary.trim();
  final contextParts = <String>[];
  if (currentUrgency.isNotEmpty && previousUrgency.isNotEmpty) {
    contextParts.add(
      'pressure $currentUrgency (prev $previousUrgency)',
    );
  } else if (currentUrgency.isNotEmpty) {
    contextParts.add('pressure $currentUrgency');
  } else if (previousUrgency.isNotEmpty) {
    contextParts.add('prev pressure $previousUrgency');
  }
  if (postureBias.isNotEmpty) {
    contextParts.add('posture $postureBias');
  }
  if (contextParts.isEmpty) {
    return normalizedBase;
  }
  return '$normalizedBase • ${contextParts.join(' • ')}';
}

String buildSyntheticPromotionSummaryFromPlans({
  required List<MonitoringWatchAutonomyActionPlan> plans,
  String shadowTomorrowUrgencySummary = '',
  String previousShadowTomorrowUrgencySummary = '',
  String shadowPostureBiasSummary = '',
}) {
  return buildSyntheticPromotionSummary(
    baseSummary: _firstSyntheticPlanMetadata(plans, 'mo_promotion_summary'),
    shadowTomorrowUrgencySummary: shadowTomorrowUrgencySummary,
    previousShadowTomorrowUrgencySummary:
        previousShadowTomorrowUrgencySummary,
    shadowPostureBiasSummary: shadowPostureBiasSummary,
  );
}

String buildSyntheticPromotionDecisionSummary({
  required String baseSummary,
  String shadowTomorrowUrgencySummary = '',
  String previousShadowTomorrowUrgencySummary = '',
  String shadowPostureBiasSummary = '',
}) {
  final normalizedBase = baseSummary.trim();
  if (normalizedBase.isEmpty) {
    return '';
  }
  final currentUrgency = shadowTomorrowUrgencySummary.trim();
  final previousUrgency = previousShadowTomorrowUrgencySummary.trim();
  final postureBias = shadowPostureBiasSummary.trim();
  final contextParts = <String>[];
  if (currentUrgency.isNotEmpty && previousUrgency.isNotEmpty) {
    contextParts.add(
      'under $currentUrgency pressure (prev $previousUrgency)',
    );
  } else if (currentUrgency.isNotEmpty) {
    contextParts.add('under $currentUrgency pressure');
  } else if (previousUrgency.isNotEmpty) {
    contextParts.add('prev pressure $previousUrgency');
  }
  if (postureBias.isNotEmpty) {
    contextParts.add('posture $postureBias');
  }
  if (contextParts.isEmpty) {
    return normalizedBase;
  }
  return '$normalizedBase • ${contextParts.join(' • ')}';
}

String buildSyntheticPromotionDecisionSummaryFromPlans({
  required List<MonitoringWatchAutonomyActionPlan> plans,
  required String Function(String moId, String targetValidationStatus)
  decisionSummaryLookup,
  String shadowTomorrowUrgencySummary = '',
  String previousShadowTomorrowUrgencySummary = '',
  String shadowPostureBiasSummary = '',
}) {
  final moId = _firstSyntheticPlanMetadata(plans, 'mo_promotion_id');
  final targetStatus = _firstSyntheticPlanMetadata(plans, 'mo_promotion_target');
  if (moId.isEmpty || targetStatus.isEmpty) {
    return '';
  }
  return buildSyntheticPromotionDecisionSummary(
    baseSummary: decisionSummaryLookup(moId, targetStatus),
    shadowTomorrowUrgencySummary: shadowTomorrowUrgencySummary,
    previousShadowTomorrowUrgencySummary:
        previousShadowTomorrowUrgencySummary,
    shadowPostureBiasSummary: shadowPostureBiasSummary,
  );
}

String buildSyntheticPromotionPressureSummary({
  String shadowTomorrowUrgencySummary = '',
  String previousShadowTomorrowUrgencySummary = '',
  String shadowPostureBiasSummary = '',
}) {
  final currentUrgency = shadowTomorrowUrgencySummary.trim();
  final previousUrgency = previousShadowTomorrowUrgencySummary.trim();
  final postureBias = shadowPostureBiasSummary.trim();
  final parts = <String>[];
  if (currentUrgency.isNotEmpty && previousUrgency.isNotEmpty) {
    parts.add('$currentUrgency (prev $previousUrgency)');
  } else if (currentUrgency.isNotEmpty) {
    parts.add(currentUrgency);
  } else if (previousUrgency.isNotEmpty) {
    parts.add('prev $previousUrgency');
  }
  if (postureBias.isNotEmpty) {
    parts.add('posture $postureBias');
  }
  return parts.join(' • ');
}

String buildSyntheticPromotionPressureSummaryFromPlans({
  required List<MonitoringWatchAutonomyActionPlan> plans,
  String shadowTomorrowUrgencySummary = '',
  String previousShadowTomorrowUrgencySummary = '',
  String shadowPostureBiasSummary = '',
}) {
  final prebuiltSummary = _firstSyntheticPlanMetadata(
    plans,
    'mo_promotion_pressure_summary',
  );
  if (prebuiltSummary.isNotEmpty) {
    return prebuiltSummary;
  }
  return buildSyntheticPromotionPressureSummary(
    shadowTomorrowUrgencySummary: shadowTomorrowUrgencySummary,
    previousShadowTomorrowUrgencySummary:
        previousShadowTomorrowUrgencySummary,
    shadowPostureBiasSummary: shadowPostureBiasSummary,
  );
}
