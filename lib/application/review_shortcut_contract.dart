Map<String, Object?> buildReviewShortcuts({
  required String currentReportDate,
  String? previousReportDate,
  required String Function(String reportDate) reviewCommandBuilder,
  required String Function(String reportDate) caseFileCommandBuilder,
  bool? targetScopeRequired,
}) {
  final current = currentReportDate.trim();
  final previous = (previousReportDate ?? '').trim();
  final shortcuts = <String, Object?>{};
  if (current.isNotEmpty) {
    shortcuts['currentShiftReviewCommand'] = reviewCommandBuilder(current);
    shortcuts['currentShiftCaseFileCommand'] = caseFileCommandBuilder(current);
  }
  if (previous.isNotEmpty) {
    shortcuts['previousShiftReviewCommand'] = reviewCommandBuilder(previous);
    shortcuts['previousShiftCaseFileCommand'] = caseFileCommandBuilder(previous);
  }
  if (targetScopeRequired != null) {
    shortcuts['targetScopeRequired'] = targetScopeRequired;
  }
  return shortcuts;
}

List<String> buildReviewShortcutCsvRows({
  required String currentReportDate,
  String? previousReportDate,
  required String currentReviewMetric,
  required String currentCaseMetric,
  required String previousReviewMetric,
  required String previousCaseMetric,
  required String Function(String reportDate) reviewCommandBuilder,
  required String Function(String reportDate) caseFileCommandBuilder,
}) {
  final current = currentReportDate.trim();
  final previous = (previousReportDate ?? '').trim();
  return <String>[
    if (current.isNotEmpty)
      '$currentReviewMetric,${reviewCommandBuilder(current)}',
    if (current.isNotEmpty)
      '$currentCaseMetric,${caseFileCommandBuilder(current)}',
    if (previous.isNotEmpty)
      '$previousReviewMetric,${reviewCommandBuilder(previous)}',
    if (previous.isNotEmpty)
      '$previousCaseMetric,${caseFileCommandBuilder(previous)}',
  ];
}

Map<String, String> buildReviewCommandPair({
  required String reportDate,
  required String Function(String reportDate) reviewCommandBuilder,
  required String Function(String reportDate) caseFileCommandBuilder,
}) {
  final normalized = reportDate.trim();
  if (normalized.isEmpty) {
    return const <String, String>{};
  }
  return <String, String>{
    'reviewCommand': reviewCommandBuilder(normalized),
    'caseFileCommand': caseFileCommandBuilder(normalized),
  };
}

List<String> buildHistoryReviewCommandCsvRows({
  required int row,
  required String reportDate,
  required String Function(String reportDate) reviewCommandBuilder,
  required String Function(String reportDate) caseFileCommandBuilder,
}) {
  final normalized = reportDate.trim();
  if (normalized.isEmpty) {
    return const <String>[];
  }
  return <String>[
    'history_${row}_review_command,${reviewCommandBuilder(normalized)}',
    'history_${row}_case_file_command,${caseFileCommandBuilder(normalized)}',
  ];
}
