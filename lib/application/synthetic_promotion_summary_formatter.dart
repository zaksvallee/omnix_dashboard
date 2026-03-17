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

int buildSyntheticPolicyCountFromPlans({
  required List<MonitoringWatchAutonomyActionPlan> plans,
}) {
  return plans
      .where((plan) => plan.actionType == 'POLICY RECOMMENDATION')
      .length;
}

String buildSyntheticLeadRegionIdFromPlans({
  required List<MonitoringWatchAutonomyActionPlan> plans,
}) => _firstSyntheticPlanMetadata(plans, 'region');

String buildSyntheticLeadSiteIdFromPlans({
  required List<MonitoringWatchAutonomyActionPlan> plans,
}) => _firstSyntheticPlanMetadata(plans, 'lead_site');

String buildSyntheticActionBiasFromPlans({
  required List<MonitoringWatchAutonomyActionPlan> plans,
}) => _firstSyntheticPlanMetadata(plans, 'action_bias');

String buildSyntheticMemoryPriorityBoostFromPlans({
  required List<MonitoringWatchAutonomyActionPlan> plans,
}) => _firstSyntheticPlanMetadata(plans, 'memory_priority_boost');

String buildSyntheticMemoryCountdownBiasFromPlans({
  required List<MonitoringWatchAutonomyActionPlan> plans,
}) => _firstSyntheticPlanMetadata(plans, 'memory_countdown_bias');

String buildSyntheticPromotionPriorityBiasFromPlans({
  required List<MonitoringWatchAutonomyActionPlan> plans,
}) => _firstSyntheticPlanMetadata(plans, 'mo_promotion_priority_bias');

String buildSyntheticPromotionCountdownBiasFromPlans({
  required List<MonitoringWatchAutonomyActionPlan> plans,
}) => _firstSyntheticPlanMetadata(plans, 'mo_promotion_countdown_bias');

String buildSyntheticPromotionExecutionBiasSummary({
  String promotionPriorityBias = '',
  String promotionCountdownBias = '',
}) {
  final priority = promotionPriorityBias.trim();
  final countdown = promotionCountdownBias.trim();
  if (priority.isEmpty && countdown.isEmpty) {
    return '';
  }
  final parts = <String>[
    if (priority.isNotEmpty) priority,
    if (countdown.isNotEmpty) '${countdown}s',
  ];
  return parts.join(' • ');
}

String buildSyntheticPromotionExecutionBiasSummaryFromPlans({
  required List<MonitoringWatchAutonomyActionPlan> plans,
}) {
  return buildSyntheticPromotionExecutionBiasSummary(
    promotionPriorityBias: buildSyntheticPromotionPriorityBiasFromPlans(
      plans: plans,
    ),
    promotionCountdownBias: buildSyntheticPromotionCountdownBiasFromPlans(
      plans: plans,
    ),
  );
}

String buildSyntheticLearningLabelFromPlans({
  required List<MonitoringWatchAutonomyActionPlan> plans,
}) => _firstSyntheticPlanMetadata(plans, 'learning_label');

String buildSyntheticShadowLearningSummaryFromPlans({
  required List<MonitoringWatchAutonomyActionPlan> plans,
}) => _firstSyntheticPlanMetadata(plans, 'shadow_learning_summary');

String buildSyntheticShadowMemorySummaryFromPlans({
  required List<MonitoringWatchAutonomyActionPlan> plans,
}) => _firstSyntheticPlanMetadata(plans, 'shadow_memory_summary');

String buildSyntheticLearningMemorySummaryFromHistoryLabels({
  required String currentLearningLabel,
  required List<String> historicalLearningLabels,
  String latestMatchingReportDate = '',
}) {
  final label = currentLearningLabel.trim();
  if (label.isEmpty) {
    return '';
  }
  if (historicalLearningLabels.isEmpty) {
    return 'Memory: $label is the first tracked learning bias.';
  }
  final repeatCount =
      historicalLearningLabels.where((value) => value.trim() == label).length;
  if (repeatCount <= 0) {
    return 'Memory: $label is new against the last ${historicalLearningLabels.length} shifts.';
  }
  final latestDate = latestMatchingReportDate.trim();
  return 'Memory: $label repeated in ${repeatCount + 1} of the last ${historicalLearningLabels.length + 1} shifts'
      '${latestDate.isEmpty ? '.' : ' (latest $latestDate).'}';
}

String buildSyntheticShadowSummaryFromPlans({
  required List<MonitoringWatchAutonomyActionPlan> plans,
}) {
  final plan = plans.firstWhere(
    (entry) => (entry.metadata['shadow_mo_label'] ?? '').trim().isNotEmpty,
    orElse: () => const MonitoringWatchAutonomyActionPlan(
      id: '',
      incidentId: '',
      siteId: '',
      priority: MonitoringWatchAutonomyPriority.medium,
      actionType: '',
      description: '',
      countdownSeconds: 0,
    ),
  );
  if (plan.id.isEmpty) {
    return '';
  }
  final leadSite = (plan.metadata['lead_site'] ?? plan.siteId).trim();
  final shadowLabel = (plan.metadata['shadow_mo_label'] ?? '').trim();
  final shadowTitle = (plan.metadata['shadow_mo_title'] ?? '').trim();
  final repeatCount = (plan.metadata['shadow_mo_repeat_count'] ?? '').trim();
  final parts = <String>[
    if (shadowLabel.isNotEmpty) shadowLabel,
    if (leadSite.isNotEmpty) leadSite,
    if (shadowTitle.isNotEmpty) shadowTitle,
    if (repeatCount.isNotEmpty && repeatCount != '0') 'x$repeatCount',
  ];
  return parts.join(' • ');
}

String buildSyntheticPolicySummaryFromPlans({
  required List<MonitoringWatchAutonomyActionPlan> plans,
}) {
  return plans
      .where((plan) => plan.actionType == 'POLICY RECOMMENDATION')
      .map((plan) => (plan.metadata['recommendation'] ?? '').trim())
      .firstWhere((value) => value.isNotEmpty, orElse: () => '');
}

String buildTomorrowPostureSummaryForDraft({
  required MonitoringWatchAutonomyActionPlan? draft,
}) {
  final actionType = (draft?.actionType ?? '').trim();
  if (actionType.isEmpty) {
    return '';
  }
  final leadSite = ((draft?.metadata['lead_site'] ?? draft?.siteId) ?? '')
      .trim();
  final learningLabel = (draft?.metadata['learning_label'] ?? '').trim();
  final repeatCount = (draft?.metadata['learning_repeat_count'] ?? '').trim();
  final parts = <String>[
    actionType,
    if (leadSite.isNotEmpty) leadSite,
    if (learningLabel.isNotEmpty) learningLabel,
    if (repeatCount.isNotEmpty) 'x$repeatCount',
  ];
  return parts.join(' • ');
}

String buildSyntheticModeLabelFromPlans({
  required List<MonitoringWatchAutonomyActionPlan> plans,
}) {
  final policyCount = plans
      .where((plan) => plan.actionType == 'POLICY RECOMMENDATION')
      .length;
  if (policyCount > 0) {
    return 'POLICY SHIFT';
  }
  if (plans.isNotEmpty) {
    return 'SIMULATION ACTIVE';
  }
  return 'QUIET REHEARSAL';
}

String buildSyntheticSummaryFromPlans({
  required List<MonitoringWatchAutonomyActionPlan> plans,
}) {
  if (plans.isEmpty) {
    return '';
  }
  final lead = plans.first;
  final summary = <String>[
    'Plans ${plans.length}',
    if ((lead.metadata['region'] ?? '').trim().isNotEmpty)
      'region ${(lead.metadata['region'] ?? '').trim()}',
    if ((lead.metadata['lead_site'] ?? '').trim().isNotEmpty)
      'lead ${(lead.metadata['lead_site'] ?? '').trim()}',
    if ((lead.metadata['top_intent'] ?? '').trim().isNotEmpty &&
        (lead.metadata['top_intent'] ?? '').trim() != 'NONE')
      'top intent ${(lead.metadata['top_intent'] ?? '').trim()}',
  ];
  return summary.join(' • ');
}

String buildSyntheticMetricDetailFromPlans({
  required List<MonitoringWatchAutonomyActionPlan> plans,
  String emptySummary = 'No synthetic simulation recommendations were generated in this shift',
  String policyLabel = 'policy',
  String leadLabel = 'lead',
  bool includeTopIntent = true,
  bool includeRecommendation = true,
  bool includeLearning = true,
  bool includeHazard = true,
}) {
  if (plans.isEmpty) {
    return emptySummary;
  }
  final policyCount = buildSyntheticPolicyCountFromPlans(plans: plans);
  final region = buildSyntheticLeadRegionIdFromPlans(plans: plans);
  final leadSite = buildSyntheticLeadSiteIdFromPlans(plans: plans);
  final topIntent = _firstSyntheticPlanMetadata(plans, 'top_intent');
  final recommendation = buildSyntheticPolicySummaryFromPlans(plans: plans);
  final learning = buildSyntheticLearningSummaryFromPlans(plans: plans);
  final hazard = includeHazard
      ? buildHazardSimulationSummaryFromPlans(plans: plans)
      : '';
  final parts = <String>[
    'Plans ${plans.length}',
    '$policyLabel $policyCount',
    if (region.isNotEmpty) 'region $region',
    if (leadSite.isNotEmpty) '$leadLabel $leadSite',
    if (includeTopIntent && topIntent.isNotEmpty && topIntent != 'NONE')
      'top intent $topIntent',
    if (includeRecommendation && recommendation.isNotEmpty) recommendation,
    if (includeLearning && learning.isNotEmpty) learning,
    if (hazard.isNotEmpty) hazard,
  ];
  return parts.join(' • ');
}

String buildHazardSignalLabel(String signal) {
  return switch (signal.trim().toLowerCase()) {
    'fire' => 'fire',
    'water_leak' => 'leak',
    'environment_hazard' => 'hazard',
    _ => signal.trim().toLowerCase(),
  };
}

String buildHazardIntentSummaryFromPlans({
  required List<MonitoringWatchAutonomyActionPlan> plans,
}) {
  final signal = plans
      .map((plan) => (plan.metadata['hazard_signal'] ?? '').trim())
      .firstWhere((value) => value.isNotEmpty, orElse: () => '');
  if (signal.isEmpty) {
    return '';
  }
  return '${buildHazardSignalLabel(signal)} playbook active';
}

String buildHazardSimulationSummaryFromPlans({
  required List<MonitoringWatchAutonomyActionPlan> plans,
}) {
  final signal = plans
      .map((plan) => (plan.metadata['hazard_signal'] ?? '').trim())
      .firstWhere((value) => value.isNotEmpty, orElse: () => '');
  if (signal.isEmpty) {
    return '';
  }
  return '${buildHazardSignalLabel(signal)} rehearsal recommended';
}

String buildTomorrowShadowSummaryForDraft({
  required MonitoringWatchAutonomyActionPlan? draft,
  String strengthHandoffSummary = '',
}) {
  final shadowLabel = (draft?.metadata['shadow_mo_label'] ?? '').trim();
  if (shadowLabel.isEmpty) {
    return '';
  }
  final leadSite = ((draft?.metadata['lead_site'] ?? draft?.siteId) ?? '')
      .trim();
  final shadowTitle = (draft?.metadata['shadow_mo_title'] ?? '').trim();
  final repeatCount = (draft?.metadata['shadow_mo_repeat_count'] ?? '').trim();
  final strengthHandoff = strengthHandoffSummary.trim();
  final parts = <String>[
    shadowLabel,
    if (leadSite.isNotEmpty) leadSite,
    if (shadowTitle.isNotEmpty) shadowTitle,
    if (repeatCount.isNotEmpty) 'x$repeatCount',
    if (strengthHandoff.isNotEmpty) strengthHandoff,
  ];
  return parts.join(' • ');
}

String buildTomorrowHazardSummaryForDraft({
  required MonitoringWatchAutonomyActionPlan? draft,
}) {
  final signal = (draft?.metadata['hazard_signal'] ?? '').trim();
  if (signal.isEmpty) {
    return '';
  }
  return '${buildHazardSignalLabel(signal)} playbook draft active';
}

String buildTomorrowUrgencySummaryForDraft({
  required MonitoringWatchAutonomyActionPlan? draft,
}) {
  final strengthBias = (draft?.metadata['shadow_strength_bias'] ?? '').trim();
  if (strengthBias.isEmpty) {
    return '';
  }
  final strengthPriority = (draft?.metadata['shadow_strength_priority'] ?? '')
      .trim();
  final countdown =
      (draft?.metadata['draft_countdown'] ?? '').trim().isNotEmpty
      ? (draft?.metadata['draft_countdown'] ?? '').trim()
      : (draft?.countdownSeconds ?? 0) > 0
      ? draft!.countdownSeconds.toString()
      : '';
  final parts = <String>[
    strengthBias,
    if (strengthPriority.isNotEmpty) strengthPriority,
    if (countdown.isNotEmpty) '${countdown}s',
  ];
  return parts.join(' • ');
}

String buildTomorrowLearningMemorySummaryForDraft({
  required MonitoringWatchAutonomyActionPlan? draft,
}) {
  final learningLabel = (draft?.metadata['learning_label'] ?? '').trim();
  final repeatCount =
      int.tryParse((draft?.metadata['learning_repeat_count'] ?? '').trim());
  if (learningLabel.isEmpty || repeatCount == null || repeatCount <= 0) {
    return '';
  }
  return 'Memory: $learningLabel repeated across ${repeatCount + 1} linked shifts.';
}

String buildSyntheticBiasSummary({
  String actionBias = '',
  String priorityBoost = '',
  String countdownBias = '',
}) {
  final normalizedActionBias = actionBias.trim();
  final normalizedPriorityBoost = priorityBoost.trim();
  final normalizedCountdownBias = countdownBias.trim();
  if (normalizedActionBias.isEmpty &&
      normalizedPriorityBoost.isEmpty &&
      normalizedCountdownBias.isEmpty) {
    return '';
  }
  final parts = <String>[
    if (normalizedActionBias.isNotEmpty) normalizedActionBias,
    if (normalizedPriorityBoost.isNotEmpty &&
        normalizedPriorityBoost != 'NONE')
      '${normalizedPriorityBoost.toLowerCase()} priority',
    if (normalizedCountdownBias.isNotEmpty) 'T-$normalizedCountdownBias s',
  ];
  return parts.join(' • ');
}

String buildSyntheticBiasSummaryForPlan({
  MonitoringWatchAutonomyActionPlan? plan,
}) {
  return buildSyntheticBiasSummary(
    actionBias: plan?.metadata['action_bias'] ?? '',
    priorityBoost: plan?.metadata['memory_priority_boost'] ?? '',
    countdownBias: plan?.metadata['memory_countdown_bias'] ?? '',
  );
}

String buildGlobalReadinessShadowBiasSummaryFromPlans({
  required List<MonitoringWatchAutonomyActionPlan> plans,
}) {
  final bias = plans.firstWhere(
    (plan) =>
        plan.actionType.trim().toUpperCase() == 'SHADOW READINESS BIAS' ||
        (plan.metadata['readiness_bias'] ?? '').trim().toUpperCase() ==
            'ACTIVE',
    orElse: () => const MonitoringWatchAutonomyActionPlan(
      id: '',
      incidentId: '',
      siteId: '',
      priority: MonitoringWatchAutonomyPriority.medium,
      actionType: '',
      description: '',
      countdownSeconds: 0,
    ),
  );
  if (bias.actionType.trim().isEmpty) {
    return '';
  }
  final leadSite = (bias.metadata['lead_site'] ?? bias.siteId).trim();
  final shadowLabel = (bias.metadata['shadow_mo_label'] ?? '').trim();
  final shadowTitle = (bias.metadata['shadow_mo_title'] ?? '').trim();
  final repeatCount = (bias.metadata['shadow_mo_repeat_count'] ?? '').trim();
  final parts = <String>[
    if (shadowLabel.isNotEmpty) shadowLabel,
    if (leadSite.isNotEmpty) leadSite,
    if (shadowTitle.isNotEmpty) shadowTitle,
    if (repeatCount.isNotEmpty) 'x$repeatCount',
  ];
  return parts.join(' • ');
}

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
  String promotionExecutionBiasSummary = '',
}) {
  final normalizedBase = baseSummary.trim();
  if (normalizedBase.isEmpty) {
    return '';
  }
  final currentUrgency = shadowTomorrowUrgencySummary.trim();
  final previousUrgency = previousShadowTomorrowUrgencySummary.trim();
  final postureBias = shadowPostureBiasSummary.trim();
  final executionBias = promotionExecutionBiasSummary.trim();
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
  if (executionBias.isNotEmpty) {
    contextParts.add('execution $executionBias');
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
    promotionExecutionBiasSummary:
        buildSyntheticPromotionExecutionBiasSummaryFromPlans(plans: plans),
  );
}

String buildSyntheticPromotionDecisionSummary({
  required String baseSummary,
  String shadowTomorrowUrgencySummary = '',
  String previousShadowTomorrowUrgencySummary = '',
  String shadowPostureBiasSummary = '',
  String promotionExecutionBiasSummary = '',
}) {
  final normalizedBase = baseSummary.trim();
  if (normalizedBase.isEmpty) {
    return '';
  }
  final currentUrgency = shadowTomorrowUrgencySummary.trim();
  final previousUrgency = previousShadowTomorrowUrgencySummary.trim();
  final postureBias = shadowPostureBiasSummary.trim();
  final executionBias = promotionExecutionBiasSummary.trim();
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
  if (executionBias.isNotEmpty) {
    contextParts.add('execution $executionBias');
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
    promotionExecutionBiasSummary:
        buildSyntheticPromotionExecutionBiasSummaryFromPlans(plans: plans),
  );
}

String buildSyntheticPromotionPressureSummary({
  String shadowTomorrowUrgencySummary = '',
  String previousShadowTomorrowUrgencySummary = '',
  String shadowPostureBiasSummary = '',
  String promotionExecutionBiasSummary = '',
}) {
  final currentUrgency = shadowTomorrowUrgencySummary.trim();
  final previousUrgency = previousShadowTomorrowUrgencySummary.trim();
  final postureBias = shadowPostureBiasSummary.trim();
  final executionBias = promotionExecutionBiasSummary.trim();
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
  if (executionBias.isNotEmpty) {
    parts.add('execution $executionBias');
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
    promotionExecutionBiasSummary:
        buildSyntheticPromotionExecutionBiasSummaryFromPlans(plans: plans),
  );
}
