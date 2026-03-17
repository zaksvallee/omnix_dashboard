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
