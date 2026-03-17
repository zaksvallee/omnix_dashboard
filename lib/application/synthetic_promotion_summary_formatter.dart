String buildSyntheticPromotionSummary({
  required String baseSummary,
  String shadowTomorrowUrgencySummary = '',
  String previousShadowTomorrowUrgencySummary = '',
}) {
  final normalizedBase = baseSummary.trim();
  if (normalizedBase.isEmpty) {
    return '';
  }
  final currentUrgency = shadowTomorrowUrgencySummary.trim();
  final previousUrgency = previousShadowTomorrowUrgencySummary.trim();
  if (currentUrgency.isEmpty && previousUrgency.isEmpty) {
    return normalizedBase;
  }
  if (currentUrgency.isNotEmpty && previousUrgency.isNotEmpty) {
    return '$normalizedBase • pressure $currentUrgency (prev $previousUrgency)';
  }
  if (currentUrgency.isNotEmpty) {
    return '$normalizedBase • pressure $currentUrgency';
  }
  return '$normalizedBase • prev pressure $previousUrgency';
}
