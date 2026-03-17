String buildOversightFocusSummary({
  required String reportDate,
  required String currentReportDate,
}) {
  final normalizedReportDate = reportDate.trim();
  if (normalizedReportDate.isEmpty) {
    return 'Viewing current live oversight shift.';
  }
  final normalizedCurrentReportDate = currentReportDate.trim();
  if (normalizedCurrentReportDate.isEmpty ||
      normalizedCurrentReportDate == normalizedReportDate) {
    return 'Viewing live oversight shift $normalizedReportDate.';
  }
  return 'Viewing command-targeted shift $normalizedReportDate instead of live oversight $normalizedCurrentReportDate.';
}

String buildOversightFocusState({
  required String reportDate,
  required String currentReportDate,
}) {
  final normalizedReportDate = reportDate.trim();
  if (normalizedReportDate.isEmpty) {
    return 'live_current_shift';
  }
  final normalizedCurrentReportDate = currentReportDate.trim();
  return normalizedCurrentReportDate.isNotEmpty &&
          normalizedCurrentReportDate != normalizedReportDate
      ? 'historical_command_target'
      : 'live_current_shift';
}
