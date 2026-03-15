import 'report_entry_context.dart';
import 'report_partner_comparison_window.dart';
import 'report_output_mode.dart';
import 'report_preview_surface.dart';
import 'report_receipt_scene_filter.dart';

class ReportShellState {
  final ReportReceiptSceneFilter receiptFilter;
  final ReportOutputMode outputMode;
  final String? selectedReceiptEventId;
  final String? previewReceiptEventId;
  final ReportEntryContext? entryContext;
  final ReportPreviewSurface previewSurface;
  final ReportPartnerComparisonWindow partnerComparisonWindow;
  final String? partnerScopeClientId;
  final String? partnerScopeSiteId;
  final String? partnerScopePartnerLabel;
  final String? brandingPrimaryLabelOverride;
  final String? brandingEndorsementLineOverride;
  final bool includeTimeline;
  final bool includeDispatchSummary;
  final bool includeCheckpointCompliance;
  final bool includeAiDecisionLog;
  final bool includeGuardMetrics;

  const ReportShellState({
    this.receiptFilter = ReportReceiptSceneFilter.all,
    this.outputMode = ReportOutputMode.pdf,
    this.selectedReceiptEventId,
    this.previewReceiptEventId,
    this.entryContext,
    this.previewSurface = ReportPreviewSurface.route,
    this.partnerComparisonWindow = ReportPartnerComparisonWindow.latestShift,
    this.partnerScopeClientId,
    this.partnerScopeSiteId,
    this.partnerScopePartnerLabel,
    this.brandingPrimaryLabelOverride,
    this.brandingEndorsementLineOverride,
    this.includeTimeline = true,
    this.includeDispatchSummary = true,
    this.includeCheckpointCompliance = true,
    this.includeAiDecisionLog = false,
    this.includeGuardMetrics = false,
  });

  ReportShellState copyWith({
    ReportReceiptSceneFilter? receiptFilter,
    ReportOutputMode? outputMode,
    String? selectedReceiptEventId,
    bool clearSelectedReceiptEventId = false,
    String? previewReceiptEventId,
    bool clearPreviewReceiptEventId = false,
    ReportEntryContext? entryContext,
    bool clearEntryContext = false,
    ReportPreviewSurface? previewSurface,
    ReportPartnerComparisonWindow? partnerComparisonWindow,
    String? partnerScopeClientId,
    String? partnerScopeSiteId,
    String? partnerScopePartnerLabel,
    bool clearPartnerScopeFocus = false,
    String? brandingPrimaryLabelOverride,
    bool clearBrandingPrimaryLabelOverride = false,
    String? brandingEndorsementLineOverride,
    bool clearBrandingEndorsementLineOverride = false,
    bool? includeTimeline,
    bool? includeDispatchSummary,
    bool? includeCheckpointCompliance,
    bool? includeAiDecisionLog,
    bool? includeGuardMetrics,
  }) {
    final normalizedSelectedReceiptEventId = selectedReceiptEventId?.trim();
    final normalizedPreviewReceiptEventId = previewReceiptEventId?.trim();
    final normalizedPartnerScopeClientId = partnerScopeClientId?.trim();
    final normalizedPartnerScopeSiteId = partnerScopeSiteId?.trim();
    final normalizedPartnerScopePartnerLabel = partnerScopePartnerLabel?.trim();
    final normalizedBrandingPrimaryLabelOverride = brandingPrimaryLabelOverride
        ?.trim();
    final normalizedBrandingEndorsementLineOverride =
        brandingEndorsementLineOverride?.trim();
    final nextPartnerScopeClientId = clearPartnerScopeFocus
        ? null
        : normalizedPartnerScopeClientId == null
        ? this.partnerScopeClientId
        : normalizedPartnerScopeClientId.isEmpty
        ? null
        : normalizedPartnerScopeClientId;
    final nextPartnerScopeSiteId = clearPartnerScopeFocus
        ? null
        : normalizedPartnerScopeSiteId == null
        ? this.partnerScopeSiteId
        : normalizedPartnerScopeSiteId.isEmpty
        ? null
        : normalizedPartnerScopeSiteId;
    final nextPartnerScopePartnerLabel = clearPartnerScopeFocus
        ? null
        : normalizedPartnerScopePartnerLabel == null
        ? this.partnerScopePartnerLabel
        : normalizedPartnerScopePartnerLabel.isEmpty
        ? null
        : normalizedPartnerScopePartnerLabel;
    final hasCompletePartnerScope =
        nextPartnerScopeClientId != null &&
        nextPartnerScopeSiteId != null &&
        nextPartnerScopePartnerLabel != null;
    return ReportShellState(
      receiptFilter: receiptFilter ?? this.receiptFilter,
      outputMode: outputMode ?? this.outputMode,
      selectedReceiptEventId: clearSelectedReceiptEventId
          ? null
          : normalizedSelectedReceiptEventId == null
          ? this.selectedReceiptEventId
          : normalizedSelectedReceiptEventId.isEmpty
          ? null
          : normalizedSelectedReceiptEventId,
      previewReceiptEventId: clearPreviewReceiptEventId
          ? null
          : normalizedPreviewReceiptEventId == null
          ? this.previewReceiptEventId
          : normalizedPreviewReceiptEventId.isEmpty
          ? null
          : normalizedPreviewReceiptEventId,
      entryContext: clearEntryContext
          ? null
          : entryContext ?? this.entryContext,
      previewSurface: previewSurface ?? this.previewSurface,
      partnerComparisonWindow:
          partnerComparisonWindow ?? this.partnerComparisonWindow,
      partnerScopeClientId: hasCompletePartnerScope
          ? nextPartnerScopeClientId
          : null,
      partnerScopeSiteId: hasCompletePartnerScope
          ? nextPartnerScopeSiteId
          : null,
      partnerScopePartnerLabel: hasCompletePartnerScope
          ? nextPartnerScopePartnerLabel
          : null,
      brandingPrimaryLabelOverride:
          clearPartnerScopeFocus || clearBrandingPrimaryLabelOverride
          ? null
          : normalizedBrandingPrimaryLabelOverride == null
          ? this.brandingPrimaryLabelOverride
          : normalizedBrandingPrimaryLabelOverride.isEmpty
          ? null
          : normalizedBrandingPrimaryLabelOverride,
      brandingEndorsementLineOverride:
          clearPartnerScopeFocus || clearBrandingEndorsementLineOverride
          ? null
          : normalizedBrandingEndorsementLineOverride ??
                this.brandingEndorsementLineOverride,
      includeTimeline: includeTimeline ?? this.includeTimeline,
      includeDispatchSummary:
          includeDispatchSummary ?? this.includeDispatchSummary,
      includeCheckpointCompliance:
          includeCheckpointCompliance ?? this.includeCheckpointCompliance,
      includeAiDecisionLog: includeAiDecisionLog ?? this.includeAiDecisionLog,
      includeGuardMetrics: includeGuardMetrics ?? this.includeGuardMetrics,
    );
  }
}
