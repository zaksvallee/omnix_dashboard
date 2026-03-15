import 'package:flutter/widgets.dart';

import '../../application/report_generation_service.dart';
import '../../application/report_receipt_scene_filter.dart';

typedef ReportSceneReviewPillWidgetBuilder =
    Widget Function(String label, Color color, {bool isActive});

class ReportSceneReviewPillBuilder {
  const ReportSceneReviewPillBuilder._();

  static List<Widget> build({
    required ReportReceiptSceneReviewSummary? summary,
    required ReportSceneReviewPillWidgetBuilder pillBuilder,
    required Color sceneIncludedColor,
    required Color scenePendingColor,
    required Color postureColor,
    bool includeModelCount = false,
    Color? modelColor,
    bool includeEscalationCount = false,
    Color? escalationAlertColor,
    Color? escalationNeutralColor,
    bool includeActionCounts = false,
    Color? suppressedColor,
    Color? incidentAlertColor,
    Color? repeatUpdateColor,
    bool includeLatestAction = false,
    ValueChanged<ReportReceiptSceneFilter>? onLatestActionFilterTap,
    VoidCallback? onLatestActionActiveTap,
    ReportReceiptSceneFilter? activeLatestActionFilter,
    bool includePosture = false,
    bool uppercasePosture = false,
    String posturePrefix = '',
    String postureEmptyLabel = 'none',
  }) {
    if (summary == null) {
      return const [];
    }

    final widgets = <Widget>[
      pillBuilder(
        summary.includedInReceipt
            ? 'Scene ${summary.totalReviews}'
            : 'Scene Pending',
        summary.includedInReceipt ? sceneIncludedColor : scenePendingColor,
      ),
    ];

    if (summary.includedInReceipt && includeModelCount && modelColor != null) {
      widgets.add(pillBuilder('Model ${summary.modelReviews}', modelColor));
    }

    if (summary.includedInReceipt &&
        includeEscalationCount &&
        escalationAlertColor != null &&
        escalationNeutralColor != null) {
      widgets.add(
        pillBuilder(
          'Esc ${summary.escalationCandidates}',
          summary.escalationCandidates > 0
              ? escalationAlertColor
              : escalationNeutralColor,
        ),
      );
    }

    if (summary.includedInReceipt && includeActionCounts) {
      if (summary.suppressedActions > 0 && suppressedColor != null) {
        widgets.add(
          pillBuilder('Supp ${summary.suppressedActions}', suppressedColor),
        );
      }
      if (summary.incidentAlerts > 0 && incidentAlertColor != null) {
        widgets.add(
          pillBuilder('Alert ${summary.incidentAlerts}', incidentAlertColor),
        );
      }
      if (summary.repeatUpdates > 0 && repeatUpdateColor != null) {
        widgets.add(
          pillBuilder('Repeat ${summary.repeatUpdates}', repeatUpdateColor),
        );
      }
    }

    if (summary.includedInReceipt && includeLatestAction) {
      final latestActionFilter = ReportReceiptSceneFilter.forLatestActionBucket(
        summary.latestActionBucket,
      );
      final latestAction = switch (summary.latestActionBucket) {
        ReportReceiptLatestActionBucket.alerts when incidentAlertColor != null =>
          ('Latest Alert', incidentAlertColor),
        ReportReceiptLatestActionBucket.repeat when repeatUpdateColor != null =>
          ('Latest Repeat', repeatUpdateColor),
        ReportReceiptLatestActionBucket.escalation
            when escalationAlertColor != null =>
          ('Latest Esc', escalationAlertColor),
        ReportReceiptLatestActionBucket.suppressed
            when suppressedColor != null =>
          ('Latest Supp', suppressedColor),
        _ => null,
      };
      if (latestAction != null) {
        final isActive = latestActionFilter == activeLatestActionFilter;
        final latestActionColor = isActive && latestActionFilter != null
            ? latestActionFilter.activeBorderColor
            : latestAction.$2;
        final pill = pillBuilder(
          latestAction.$1,
          latestActionColor,
          isActive: isActive,
        );
        if (latestActionFilter != null && onLatestActionFilterTap != null) {
          widgets.add(
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: isActive && onLatestActionActiveTap != null
                  ? onLatestActionActiveTap
                  : () => onLatestActionFilterTap(latestActionFilter),
              child: pill,
            ),
          );
        } else {
          widgets.add(pill);
        }
      }
    }

    if (summary.includedInReceipt && includePosture) {
      final rawPosture = summary.topPosture.trim();
      final resolvedPosture = rawPosture.isEmpty ? postureEmptyLabel : rawPosture;
      final normalizedPosturePrefix = posturePrefix.trim();
      final postureLabel = uppercasePosture
          ? resolvedPosture.toUpperCase()
          : normalizedPosturePrefix.isEmpty
          ? resolvedPosture
          : '$normalizedPosturePrefix $resolvedPosture';
      widgets.add(pillBuilder(postureLabel, postureColor));
    }

    return widgets;
  }
}
