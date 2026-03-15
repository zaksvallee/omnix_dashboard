import '../domain/events/report_generated.dart';
import 'report_generation_service.dart';
import 'report_entry_context.dart';
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
      'brandingConfiguration': receiptEvent.brandingConfiguration.toJson(),
      'brandingMode': receiptEvent.brandingUsesOverride
          ? 'custom_override'
          : receiptEvent.brandingConfiguration.isConfigured
          ? 'default_partner'
          : 'standard',
      'brandingSummary': _brandingSummary(receiptEvent),
      'sceneReviewIncluded':
          receiptEvent.reportSchemaVersion >= 2 &&
          receiptEvent.includeAiDecisionLog,
      'sectionConfiguration': receiptEvent.sectionConfiguration.toJson(),
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

  static String _brandingSummary(ReportGenerated receiptEvent) {
    final branding = receiptEvent.brandingConfiguration;
    if (!branding.isConfigured) {
      return 'Standard ONYX branding';
    }
    if (receiptEvent.brandingUsesOverride) {
      final source = branding.sourceLabel.trim();
      if (source.isNotEmpty) {
        return 'Custom branding override from $source';
      }
      return 'Custom branding override';
    }
    if (branding.sourceLabel.trim().isNotEmpty) {
      return 'Default partner branding from ${branding.sourceLabel.trim()}';
    }
    return 'Configured partner branding';
  }
}

class ReportReceiptExportPayload {
  static Map<String, Object?> buildSingle({
    required ReportReceiptExportEntry entry,
    required ReportReceiptSceneFilter filter,
    String? selectedReceiptEventId,
    String? previewReceiptEventId,
    Map<String, Object?>? activeSectionConfiguration,
    ReportEntryContext? entryContext,
  }) {
    return build(
      entries: [entry],
      filter: filter,
      selectedReceiptEventId: selectedReceiptEventId,
      previewReceiptEventId: previewReceiptEventId,
      activeSectionConfiguration: activeSectionConfiguration,
      entryContext: entryContext,
    );
  }

  static Map<String, Object?> build({
    required Iterable<ReportReceiptExportEntry> entries,
    required ReportReceiptSceneFilter filter,
    String? selectedReceiptEventId,
    String? previewReceiptEventId,
    ReportReceiptExportEntry? focusedReceipt,
    Map<String, Object?>? activeSectionConfiguration,
    ReportEntryContext? entryContext,
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
          : <String, Object?>{'selectedReceiptEventId': selectedReceiptEventId},
      ...?previewReceiptEventId == null
          ? null
          : <String, Object?>{'previewReceiptEventId': previewReceiptEventId},
      ...?activeSectionConfiguration == null
          ? null
          : <String, Object?>{
              'activeSectionConfiguration': activeSectionConfiguration,
            },
      ...?entryContext == null
          ? null
          : <String, Object?>{
              'entryContext': <String, Object?>{
                'key': entryContext.storageValue,
                'title': entryContext.bannerTitle,
                'detail': entryContext.bannerDetail,
              },
            },
    };
    if (filter.isLatestActionFilter && focusedReceipt != null) {
      context['focusedReceipt'] = focusedReceipt.focusedJson();
    }
    return <String, Object?>{
      'context': context,
      'receipts': entries
          .map((entry) => entry.toJson())
          .toList(growable: false),
    };
  }
}
