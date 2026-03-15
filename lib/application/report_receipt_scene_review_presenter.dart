import 'package:flutter/material.dart';

import 'report_generation_service.dart';

class ReportReceiptSceneReviewPresenter {
  const ReportReceiptSceneReviewPresenter._();

  static Color accent(
    ReportReceiptSceneReviewSummary? summary, {
    required Color neutralColor,
    required Color reviewedColor,
    required Color escalationColor,
  }) {
    if (summary == null || !summary.includedInReceipt) {
      return neutralColor;
    }
    if (summary.escalationCandidates > 0) {
      return escalationColor;
    }
    if (summary.totalReviews > 0) {
      return reviewedColor;
    }
    return neutralColor;
  }

  static String? narrative(ReportReceiptSceneReviewSummary? summary) {
    if (summary == null) {
      return null;
    }
    if (!summary.includedInReceipt) {
      return 'Scene review metrics are not embedded in this receipt schema yet.';
    }
    if (summary.escalationCandidates > 0) {
      return 'Scene review flagged ${summary.escalationCandidates} escalation candidate${summary.escalationCandidates == 1 ? '' : 's'} in this report${_actionTail(summary)}.';
    }
    if (summary.totalReviews > 0) {
      final base =
          'Scene review stayed below escalation threshold across ${summary.totalReviews} reviewed CCTV event${summary.totalReviews == 1 ? '' : 's'}${_actionTail(summary)}.';
      final latestActionTaken = _latestActionTail(summary);
      if (latestActionTaken.isNotEmpty) {
        return '$base Latest action taken: $latestActionTaken';
      }
      final latestSuppressedPattern = _latestSuppressedTail(summary);
      if (latestSuppressedPattern.isEmpty) {
        return base;
      }
      return '$base Latest filtered pattern: $latestSuppressedPattern';
    }
    return null;
  }

  static String _actionTail(ReportReceiptSceneReviewSummary summary) {
    final parts = <String>[];
    if (summary.incidentAlerts > 0) {
      parts.add(
        '${summary.incidentAlerts} alert${summary.incidentAlerts == 1 ? '' : 's'}',
      );
    }
    if (summary.repeatUpdates > 0) {
      parts.add(
        '${summary.repeatUpdates} repeat update${summary.repeatUpdates == 1 ? '' : 's'}',
      );
    }
    if (summary.suppressedActions > 0) {
      parts.add(
        '${summary.suppressedActions} suppressed review${summary.suppressedActions == 1 ? '' : 's'}',
      );
    }
    if (parts.isEmpty) {
      return '';
    }
    return ' with ${_join(parts)}';
  }

  static String _latestActionTail(ReportReceiptSceneReviewSummary summary) {
    final latestActionTaken = summary.latestActionTaken.trim();
    if (latestActionTaken.isEmpty ||
        (summary.incidentAlerts <= 0 &&
            summary.repeatUpdates <= 0 &&
            summary.escalationCandidates <= 0)) {
      return '';
    }
    return latestActionTaken;
  }

  static String _latestSuppressedTail(ReportReceiptSceneReviewSummary summary) {
    final latestSuppressedPattern = summary.latestSuppressedPattern.trim();
    if (latestSuppressedPattern.isEmpty || summary.suppressedActions <= 0) {
      return '';
    }
    return latestSuppressedPattern;
  }

  static String _join(List<String> parts) {
    if (parts.length == 1) {
      return parts.first;
    }
    if (parts.length == 2) {
      return '${parts.first} and ${parts.last}';
    }
    return '${parts.take(parts.length - 1).join(', ')}, and ${parts.last}';
  }
}
