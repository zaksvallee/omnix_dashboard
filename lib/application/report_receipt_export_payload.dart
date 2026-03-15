import '../domain/events/report_generated.dart';
import 'report_generation_service.dart';
import 'report_receipt_scene_filter.dart';

class ReportReceiptExportEntry {
  final ReportGenerated receiptEvent;
  final bool? replayVerified;
  final ReportReceiptSceneReviewSummary? sceneReviewSummary;

  const ReportReceiptExportEntry({
    required this.receiptEvent,
    this.replayVerified,
    this.sceneReviewSummary,
  });

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'eventId': receiptEvent.eventId,
      'clientId': receiptEvent.clientId,
      'siteId': receiptEvent.siteId,
      'occurredAtUtc': receiptEvent.occurredAt.toUtc().toIso8601String(),
      'month': receiptEvent.month,
      'eventCount': receiptEvent.eventCount,
      'reportSchemaVersion': receiptEvent.reportSchemaVersion,
      'projectionVersion': receiptEvent.projectionVersion,
      'sceneReviewIncluded': receiptEvent.reportSchemaVersion >= 2,
      if (replayVerified != null) 'replayVerified': replayVerified,
    };
  }

  Map<String, Object?> focusedJson() {
    return <String, Object?>{
      'eventId': receiptEvent.eventId,
      'latestActionBucket': sceneReviewSummary?.latestActionBucket.name,
      'latestActionTaken': sceneReviewSummary?.latestActionTaken.trim(),
    };
  }
}

class ReportReceiptExportPayload {
  static Map<String, Object?> buildSingle({
    required ReportReceiptExportEntry entry,
    required ReportReceiptSceneFilter filter,
    String? selectedReceiptEventId,
    String? previewReceiptEventId,
  }) {
    return build(
      entries: [entry],
      filter: filter,
      selectedReceiptEventId: selectedReceiptEventId,
      previewReceiptEventId: previewReceiptEventId,
    );
  }

  static Map<String, Object?> build({
    required Iterable<ReportReceiptExportEntry> entries,
    required ReportReceiptSceneFilter filter,
    String? selectedReceiptEventId,
    String? previewReceiptEventId,
    ReportReceiptExportEntry? focusedReceipt,
  }) {
    final context = <String, Object?>{
      'filter': <String, Object?>{
        'key': filter.name,
        'label': filter.label,
        'statusLabel': filter.statusLabel,
        'viewingLabel': filter.viewingLabel,
      },
      ...?selectedReceiptEventId == null
          ? null
          : <String, Object?>{
              'selectedReceiptEventId': selectedReceiptEventId,
            },
      ...?previewReceiptEventId == null
          ? null
          : <String, Object?>{
              'previewReceiptEventId': previewReceiptEventId,
            },
    };
    if (filter.isLatestActionFilter && focusedReceipt != null) {
      context['focusedReceipt'] = focusedReceipt.focusedJson();
    }
    return <String, Object?>{
      'context': context,
      'receipts': entries.map((entry) => entry.toJson()).toList(growable: false),
    };
  }
}
