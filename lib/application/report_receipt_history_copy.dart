import 'report_receipt_scene_filter.dart';

class ReportReceiptHistoryCopy {
  static String pageSubtitle({
    required String scopeLabel,
    required ReportReceiptSceneFilter filter,
  }) {
    final normalizedScopeLabel = scopeLabel.trim();
    if (filter == ReportReceiptSceneFilter.all) {
      return normalizedScopeLabel;
    }
    if (normalizedScopeLabel.isEmpty) {
      return filter.statusLabel;
    }
    return '$normalizedScopeLabel • ${filter.statusLabel}';
  }

  static String historySubtitle({
    required String base,
    required ReportReceiptSceneFilter filter,
  }) {
    final normalizedBase = base.trim();
    if (filter == ReportReceiptSceneFilter.all) {
      return normalizedBase;
    }
    if (normalizedBase.isEmpty) {
      return filter.viewingSentence;
    }
    return '$normalizedBase ${filter.viewingSentence}';
  }
}
