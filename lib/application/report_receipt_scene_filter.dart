import 'package:flutter/material.dart';

import 'report_generation_service.dart';

enum ReportReceiptSceneFilter {
  all(label: 'All Receipts', statusLabel: 'All receipts'),
  alerts(label: 'Alerts', statusLabel: 'Alert receipts'),
  repeat(label: 'Repeat', statusLabel: 'Repeat receipts'),
  escalation(label: 'Escalation', statusLabel: 'Escalation receipts'),
  suppressed(label: 'Suppressed', statusLabel: 'Suppressed receipts'),
  latestAlerts(label: 'Latest Alert', statusLabel: 'Latest Alert receipts'),
  latestRepeat(label: 'Latest Repeat', statusLabel: 'Latest Repeat receipts'),
  latestEscalation(
    label: 'Latest Escalation',
    statusLabel: 'Latest Escalation receipts',
  ),
  latestSuppressed(
    label: 'Latest Suppressed',
    statusLabel: 'Latest Suppressed receipts',
  ),
  reviewed(label: 'Reviewed', statusLabel: 'Reviewed receipts'),
  pending(label: 'Pending', statusLabel: 'Scene Pending receipts');

  const ReportReceiptSceneFilter({
    required this.label,
    required this.statusLabel,
  });

  final String label;
  final String statusLabel;

  bool get isLatestActionFilter {
    switch (this) {
      case ReportReceiptSceneFilter.latestAlerts:
      case ReportReceiptSceneFilter.latestRepeat:
      case ReportReceiptSceneFilter.latestEscalation:
      case ReportReceiptSceneFilter.latestSuppressed:
        return true;
      case ReportReceiptSceneFilter.all:
      case ReportReceiptSceneFilter.alerts:
      case ReportReceiptSceneFilter.repeat:
      case ReportReceiptSceneFilter.escalation:
      case ReportReceiptSceneFilter.suppressed:
      case ReportReceiptSceneFilter.reviewed:
      case ReportReceiptSceneFilter.pending:
        return false;
    }
  }

  String get viewingLabel => 'Viewing ${statusLabel.trim()}';

  String get viewingSentence => '$viewingLabel.';

  Color get activeBackgroundColor {
    switch (this) {
      case ReportReceiptSceneFilter.all:
        return const Color(0xFF10233A);
      case ReportReceiptSceneFilter.alerts:
      case ReportReceiptSceneFilter.latestAlerts:
        return const Color(0xFF3D2B17);
      case ReportReceiptSceneFilter.repeat:
      case ReportReceiptSceneFilter.latestRepeat:
        return const Color(0xFF123B3E);
      case ReportReceiptSceneFilter.escalation:
      case ReportReceiptSceneFilter.latestEscalation:
        return const Color(0xFF3D1F24);
      case ReportReceiptSceneFilter.suppressed:
      case ReportReceiptSceneFilter.latestSuppressed:
        return const Color(0xFF26333B);
      case ReportReceiptSceneFilter.reviewed:
        return const Color(0xFF14314D);
      case ReportReceiptSceneFilter.pending:
        return const Color(0xFF233042);
    }
  }

  Color get activeBorderColor {
    switch (this) {
      case ReportReceiptSceneFilter.all:
        return const Color(0xFF2A4768);
      case ReportReceiptSceneFilter.alerts:
      case ReportReceiptSceneFilter.latestAlerts:
        return const Color(0xFFC68A3A);
      case ReportReceiptSceneFilter.repeat:
      case ReportReceiptSceneFilter.latestRepeat:
        return const Color(0xFF4CB8BE);
      case ReportReceiptSceneFilter.escalation:
      case ReportReceiptSceneFilter.latestEscalation:
        return const Color(0xFFD56A78);
      case ReportReceiptSceneFilter.suppressed:
      case ReportReceiptSceneFilter.latestSuppressed:
        return const Color(0xFF7D98A8);
      case ReportReceiptSceneFilter.reviewed:
        return const Color(0xFF4A74A0);
      case ReportReceiptSceneFilter.pending:
        return const Color(0xFF7C93AB);
    }
  }

  Color get bannerBackgroundColor {
    switch (this) {
      case ReportReceiptSceneFilter.all:
        return const Color(0xFF10233A);
      case ReportReceiptSceneFilter.alerts:
      case ReportReceiptSceneFilter.latestAlerts:
        return const Color(0xFF2B1F12);
      case ReportReceiptSceneFilter.repeat:
      case ReportReceiptSceneFilter.latestRepeat:
        return const Color(0xFF0F2A30);
      case ReportReceiptSceneFilter.escalation:
      case ReportReceiptSceneFilter.latestEscalation:
        return const Color(0xFF30171D);
      case ReportReceiptSceneFilter.suppressed:
      case ReportReceiptSceneFilter.latestSuppressed:
        return const Color(0xFF1D2A33);
      case ReportReceiptSceneFilter.reviewed:
        return const Color(0xFF102944);
      case ReportReceiptSceneFilter.pending:
        return const Color(0xFF1D2937);
    }
  }

  Color get bannerBorderColor {
    switch (this) {
      case ReportReceiptSceneFilter.all:
        return const Color(0xFF325173);
      case ReportReceiptSceneFilter.alerts:
      case ReportReceiptSceneFilter.latestAlerts:
        return const Color(0xFFB67A34);
      case ReportReceiptSceneFilter.repeat:
      case ReportReceiptSceneFilter.latestRepeat:
        return const Color(0xFF3EABB3);
      case ReportReceiptSceneFilter.escalation:
      case ReportReceiptSceneFilter.latestEscalation:
        return const Color(0xFFC55E6B);
      case ReportReceiptSceneFilter.suppressed:
      case ReportReceiptSceneFilter.latestSuppressed:
        return const Color(0xFF6F8A9A);
      case ReportReceiptSceneFilter.reviewed:
        return const Color(0xFF4B76A4);
      case ReportReceiptSceneFilter.pending:
        return const Color(0xFF6E859D);
    }
  }

  bool matches(ReportReceiptSceneReviewSummary? summary) {
    switch (this) {
      case ReportReceiptSceneFilter.all:
        return true;
      case ReportReceiptSceneFilter.alerts:
        return summary?.includedInReceipt == true &&
            (summary?.incidentAlerts ?? 0) > 0;
      case ReportReceiptSceneFilter.repeat:
        return summary?.includedInReceipt == true &&
            (summary?.repeatUpdates ?? 0) > 0;
      case ReportReceiptSceneFilter.escalation:
        return summary?.includedInReceipt == true &&
            (summary?.escalationCandidates ?? 0) > 0;
      case ReportReceiptSceneFilter.suppressed:
        return summary?.includedInReceipt == true &&
            (summary?.suppressedActions ?? 0) > 0;
      case ReportReceiptSceneFilter.latestAlerts:
        return summary?.includedInReceipt == true &&
            summary?.latestActionBucket == ReportReceiptLatestActionBucket.alerts;
      case ReportReceiptSceneFilter.latestRepeat:
        return summary?.includedInReceipt == true &&
            summary?.latestActionBucket == ReportReceiptLatestActionBucket.repeat;
      case ReportReceiptSceneFilter.latestEscalation:
        return summary?.includedInReceipt == true &&
            summary?.latestActionBucket ==
                ReportReceiptLatestActionBucket.escalation;
      case ReportReceiptSceneFilter.latestSuppressed:
        return summary?.includedInReceipt == true &&
            summary?.latestActionBucket ==
                ReportReceiptLatestActionBucket.suppressed;
      case ReportReceiptSceneFilter.reviewed:
        return summary?.includedInReceipt == true &&
            (summary?.totalReviews ?? 0) > 0;
      case ReportReceiptSceneFilter.pending:
        return summary?.includedInReceipt != true;
    }
  }

  String countLabel(Iterable<ReportReceiptSceneReviewSummary?> summaries) {
    final count = summaries.where(matches).length;
    return '$label ($count)';
  }

  static ReportReceiptSceneFilter? forLatestActionBucket(
    ReportReceiptLatestActionBucket bucket,
  ) {
    return switch (bucket) {
      ReportReceiptLatestActionBucket.alerts =>
        ReportReceiptSceneFilter.latestAlerts,
      ReportReceiptLatestActionBucket.repeat =>
        ReportReceiptSceneFilter.latestRepeat,
      ReportReceiptLatestActionBucket.escalation =>
        ReportReceiptSceneFilter.latestEscalation,
      ReportReceiptLatestActionBucket.suppressed =>
        ReportReceiptSceneFilter.latestSuppressed,
      ReportReceiptLatestActionBucket.none => null,
    };
  }
}
