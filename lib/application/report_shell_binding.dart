import 'report_entry_context.dart';
import 'report_partner_comparison_window.dart';
import 'report_output_mode.dart';
import 'report_preview_surface.dart';
import 'report_receipt_scene_filter.dart';
import 'report_shell_state.dart';

class ReportShellBinding {
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

  const ReportShellBinding({
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

  factory ReportShellBinding.fromShellState(ReportShellState shellState) {
    final normalizedSelectedReceiptEventId = shellState.selectedReceiptEventId
        ?.trim();
    final normalizedPreviewReceiptEventId = shellState.previewReceiptEventId
        ?.trim();
    final normalizedPartnerScopeClientId = shellState.partnerScopeClientId
        ?.trim();
    final normalizedPartnerScopeSiteId = shellState.partnerScopeSiteId?.trim();
    final normalizedPartnerScopePartnerLabel = shellState
        .partnerScopePartnerLabel
        ?.trim();
    final normalizedBrandingPrimaryLabelOverride = shellState
        .brandingPrimaryLabelOverride
        ?.trim();
    final normalizedBrandingEndorsementLineOverride = shellState
        .brandingEndorsementLineOverride
        ?.trim();
    final hasCompletePartnerScope =
        normalizedPartnerScopeClientId != null &&
        normalizedPartnerScopeClientId.isNotEmpty &&
        normalizedPartnerScopeSiteId != null &&
        normalizedPartnerScopeSiteId.isNotEmpty &&
        normalizedPartnerScopePartnerLabel != null &&
        normalizedPartnerScopePartnerLabel.isNotEmpty;
    return ReportShellBinding(
      receiptFilter: shellState.receiptFilter,
      outputMode: shellState.outputMode,
      selectedReceiptEventId:
          normalizedSelectedReceiptEventId == null ||
              normalizedSelectedReceiptEventId.isEmpty
          ? null
          : normalizedSelectedReceiptEventId,
      previewReceiptEventId:
          normalizedPreviewReceiptEventId == null ||
              normalizedPreviewReceiptEventId.isEmpty
          ? null
          : normalizedPreviewReceiptEventId,
      entryContext: shellState.entryContext,
      previewSurface: shellState.previewSurface,
      partnerComparisonWindow: shellState.partnerComparisonWindow,
      partnerScopeClientId: hasCompletePartnerScope
          ? normalizedPartnerScopeClientId
          : null,
      partnerScopeSiteId: hasCompletePartnerScope
          ? normalizedPartnerScopeSiteId
          : null,
      partnerScopePartnerLabel: hasCompletePartnerScope
          ? normalizedPartnerScopePartnerLabel
          : null,
      brandingPrimaryLabelOverride:
          normalizedBrandingPrimaryLabelOverride == null ||
              normalizedBrandingPrimaryLabelOverride.isEmpty
          ? null
          : normalizedBrandingPrimaryLabelOverride,
      brandingEndorsementLineOverride:
          normalizedBrandingEndorsementLineOverride,
      includeTimeline: shellState.includeTimeline,
      includeDispatchSummary: shellState.includeDispatchSummary,
      includeCheckpointCompliance: shellState.includeCheckpointCompliance,
      includeAiDecisionLog: shellState.includeAiDecisionLog,
      includeGuardMetrics: shellState.includeGuardMetrics,
    );
  }

  ReportShellBinding copyWith({
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
    return ReportShellBinding(
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

  ReportShellBinding syncFromWidget({
    required ReportShellState oldShellState,
    required ReportShellState newShellState,
  }) {
    return copyWith(
      receiptFilter:
          oldShellState.receiptFilter != newShellState.receiptFilter &&
              newShellState.receiptFilter != receiptFilter
          ? newShellState.receiptFilter
          : null,
      outputMode:
          oldShellState.outputMode != newShellState.outputMode &&
              newShellState.outputMode != outputMode
          ? newShellState.outputMode
          : null,
      selectedReceiptEventId:
          oldShellState.selectedReceiptEventId !=
                  newShellState.selectedReceiptEventId &&
              newShellState.selectedReceiptEventId != selectedReceiptEventId
          ? newShellState.selectedReceiptEventId
          : null,
      clearSelectedReceiptEventId:
          oldShellState.selectedReceiptEventId !=
              newShellState.selectedReceiptEventId &&
          newShellState.selectedReceiptEventId == null,
      previewReceiptEventId:
          oldShellState.previewReceiptEventId !=
                  newShellState.previewReceiptEventId &&
              newShellState.previewReceiptEventId != previewReceiptEventId
          ? newShellState.previewReceiptEventId
          : null,
      clearPreviewReceiptEventId:
          oldShellState.previewReceiptEventId !=
              newShellState.previewReceiptEventId &&
          newShellState.previewReceiptEventId == null,
      entryContext:
          oldShellState.entryContext != newShellState.entryContext &&
              newShellState.entryContext != entryContext
          ? newShellState.entryContext
          : null,
      clearEntryContext:
          oldShellState.entryContext != newShellState.entryContext &&
          newShellState.entryContext == null,
      previewSurface:
          oldShellState.previewSurface != newShellState.previewSurface &&
              newShellState.previewSurface != previewSurface
          ? newShellState.previewSurface
          : null,
      partnerComparisonWindow:
          oldShellState.partnerComparisonWindow !=
                  newShellState.partnerComparisonWindow &&
              newShellState.partnerComparisonWindow != partnerComparisonWindow
          ? newShellState.partnerComparisonWindow
          : null,
      partnerScopeClientId:
          oldShellState.partnerScopeClientId !=
              newShellState.partnerScopeClientId
          ? newShellState.partnerScopeClientId
          : null,
      partnerScopeSiteId:
          oldShellState.partnerScopeSiteId != newShellState.partnerScopeSiteId
          ? newShellState.partnerScopeSiteId
          : null,
      partnerScopePartnerLabel:
          oldShellState.partnerScopePartnerLabel !=
              newShellState.partnerScopePartnerLabel
          ? newShellState.partnerScopePartnerLabel
          : null,
      brandingPrimaryLabelOverride:
          oldShellState.brandingPrimaryLabelOverride !=
                  newShellState.brandingPrimaryLabelOverride &&
              newShellState.brandingPrimaryLabelOverride !=
                  brandingPrimaryLabelOverride
          ? newShellState.brandingPrimaryLabelOverride
          : null,
      clearBrandingPrimaryLabelOverride:
          oldShellState.brandingPrimaryLabelOverride !=
              newShellState.brandingPrimaryLabelOverride &&
          newShellState.brandingPrimaryLabelOverride == null,
      brandingEndorsementLineOverride:
          oldShellState.brandingEndorsementLineOverride !=
                  newShellState.brandingEndorsementLineOverride &&
              newShellState.brandingEndorsementLineOverride !=
                  brandingEndorsementLineOverride
          ? newShellState.brandingEndorsementLineOverride
          : null,
      clearBrandingEndorsementLineOverride:
          oldShellState.brandingEndorsementLineOverride !=
              newShellState.brandingEndorsementLineOverride &&
          newShellState.brandingEndorsementLineOverride == null,
      clearPartnerScopeFocus:
          (oldShellState.partnerScopeClientId !=
                  newShellState.partnerScopeClientId ||
              oldShellState.partnerScopeSiteId !=
                  newShellState.partnerScopeSiteId ||
              oldShellState.partnerScopePartnerLabel !=
                  newShellState.partnerScopePartnerLabel) &&
          newShellState.partnerScopeClientId == null &&
          newShellState.partnerScopeSiteId == null &&
          newShellState.partnerScopePartnerLabel == null,
      includeTimeline:
          oldShellState.includeTimeline != newShellState.includeTimeline &&
              newShellState.includeTimeline != includeTimeline
          ? newShellState.includeTimeline
          : null,
      includeDispatchSummary:
          oldShellState.includeDispatchSummary !=
                  newShellState.includeDispatchSummary &&
              newShellState.includeDispatchSummary != includeDispatchSummary
          ? newShellState.includeDispatchSummary
          : null,
      includeCheckpointCompliance:
          oldShellState.includeCheckpointCompliance !=
                  newShellState.includeCheckpointCompliance &&
              newShellState.includeCheckpointCompliance !=
                  includeCheckpointCompliance
          ? newShellState.includeCheckpointCompliance
          : null,
      includeAiDecisionLog:
          oldShellState.includeAiDecisionLog !=
                  newShellState.includeAiDecisionLog &&
              newShellState.includeAiDecisionLog != includeAiDecisionLog
          ? newShellState.includeAiDecisionLog
          : null,
      includeGuardMetrics:
          oldShellState.includeGuardMetrics !=
                  newShellState.includeGuardMetrics &&
              newShellState.includeGuardMetrics != includeGuardMetrics
          ? newShellState.includeGuardMetrics
          : null,
    );
  }

  ReportShellBinding withReceiptFilter(ReportReceiptSceneFilter value) {
    return copyWith(receiptFilter: value);
  }

  ReportShellBinding toggledReceiptFilter(ReportReceiptSceneFilter value) {
    if (value == ReportReceiptSceneFilter.all) {
      return withReceiptFilter(value);
    }
    if (receiptFilter == value) {
      return withReceiptFilter(ReportReceiptSceneFilter.all);
    }
    return withReceiptFilter(value);
  }

  ReportShellBinding withOutputMode(ReportOutputMode value) {
    return copyWith(outputMode: value);
  }

  ReportShellBinding withPreviewSurface(ReportPreviewSurface value) {
    return copyWith(previewSurface: value);
  }

  ReportShellBinding withPartnerComparisonWindow(
    ReportPartnerComparisonWindow value,
  ) {
    return copyWith(partnerComparisonWindow: value);
  }

  ReportShellBinding withPartnerScopeFocus({
    required String clientId,
    required String siteId,
    required String partnerLabel,
  }) {
    final normalizedClientId = clientId.trim();
    final normalizedSiteId = siteId.trim();
    final normalizedPartnerLabel = partnerLabel.trim();
    final scopeChanged =
        normalizedClientId != partnerScopeClientId ||
        normalizedSiteId != partnerScopeSiteId ||
        normalizedPartnerLabel != partnerScopePartnerLabel;
    return copyWith(
      partnerScopeClientId: normalizedClientId,
      partnerScopeSiteId: normalizedSiteId,
      partnerScopePartnerLabel: normalizedPartnerLabel,
      clearBrandingPrimaryLabelOverride: scopeChanged,
      clearBrandingEndorsementLineOverride: scopeChanged,
    );
  }

  ReportShellBinding clearingPartnerScopeFocus() {
    return copyWith(clearPartnerScopeFocus: true);
  }

  ReportShellBinding withReportSectionConfiguration({
    bool? includeTimeline,
    bool? includeDispatchSummary,
    bool? includeCheckpointCompliance,
    bool? includeAiDecisionLog,
    bool? includeGuardMetrics,
  }) {
    return copyWith(
      includeTimeline: includeTimeline,
      includeDispatchSummary: includeDispatchSummary,
      includeCheckpointCompliance: includeCheckpointCompliance,
      includeAiDecisionLog: includeAiDecisionLog,
      includeGuardMetrics: includeGuardMetrics,
    );
  }

  ReportShellBinding withBrandingOverrides({
    String? primaryLabelOverride,
    bool clearPrimaryLabelOverride = false,
    String? endorsementLineOverride,
    bool clearEndorsementLineOverride = false,
  }) {
    return copyWith(
      brandingPrimaryLabelOverride: primaryLabelOverride,
      clearBrandingPrimaryLabelOverride: clearPrimaryLabelOverride,
      brandingEndorsementLineOverride: endorsementLineOverride,
      clearBrandingEndorsementLineOverride: clearEndorsementLineOverride,
    );
  }

  ReportShellBinding withReceiptWorkspaceFocus(String? value) {
    final normalizedValue = value?.trim();
    final shouldClear = normalizedValue == null || normalizedValue.isEmpty;
    return copyWith(
      selectedReceiptEventId: normalizedValue,
      clearSelectedReceiptEventId: shouldClear,
      previewReceiptEventId: normalizedValue,
      clearPreviewReceiptEventId: shouldClear,
    );
  }

  ReportShellBinding withEntryContext(ReportEntryContext? value) {
    return copyWith(entryContext: value, clearEntryContext: value == null);
  }

  ReportShellBinding clearingPreviewTarget() {
    return copyWith(clearPreviewReceiptEventId: true);
  }

  ReportShellBinding prunedToReceiptIds(Iterable<String> receiptEventIds) {
    final availableIds = receiptEventIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    final normalizedSelectedReceiptEventId = selectedReceiptEventId?.trim();
    final normalizedPreviewReceiptEventId = previewReceiptEventId?.trim();
    final shouldClearSelected =
        normalizedSelectedReceiptEventId != null &&
        normalizedSelectedReceiptEventId.isNotEmpty &&
        !availableIds.contains(normalizedSelectedReceiptEventId);
    final shouldClearPreview =
        normalizedPreviewReceiptEventId != null &&
        normalizedPreviewReceiptEventId.isNotEmpty &&
        !availableIds.contains(normalizedPreviewReceiptEventId);
    if (!shouldClearSelected && !shouldClearPreview) {
      return this;
    }
    return copyWith(
      clearSelectedReceiptEventId: shouldClearSelected,
      clearPreviewReceiptEventId: shouldClearPreview,
    );
  }

  ReportShellState toShellState(ReportShellState shellState) {
    return shellState.copyWith(
      receiptFilter: receiptFilter,
      outputMode: outputMode,
      selectedReceiptEventId: selectedReceiptEventId,
      clearSelectedReceiptEventId: selectedReceiptEventId == null,
      previewReceiptEventId: previewReceiptEventId,
      clearPreviewReceiptEventId: previewReceiptEventId == null,
      entryContext: entryContext,
      clearEntryContext: entryContext == null,
      previewSurface: previewSurface,
      partnerComparisonWindow: partnerComparisonWindow,
      partnerScopeClientId: partnerScopeClientId,
      partnerScopeSiteId: partnerScopeSiteId,
      partnerScopePartnerLabel: partnerScopePartnerLabel,
      brandingPrimaryLabelOverride: brandingPrimaryLabelOverride,
      clearBrandingPrimaryLabelOverride: brandingPrimaryLabelOverride == null,
      brandingEndorsementLineOverride: brandingEndorsementLineOverride,
      clearBrandingEndorsementLineOverride:
          brandingEndorsementLineOverride == null,
      clearPartnerScopeFocus:
          partnerScopeClientId == null ||
          partnerScopeSiteId == null ||
          partnerScopePartnerLabel == null,
      includeTimeline: includeTimeline,
      includeDispatchSummary: includeDispatchSummary,
      includeCheckpointCompliance: includeCheckpointCompliance,
      includeAiDecisionLog: includeAiDecisionLog,
      includeGuardMetrics: includeGuardMetrics,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ReportShellBinding &&
        other.receiptFilter == receiptFilter &&
        other.outputMode == outputMode &&
        other.selectedReceiptEventId == selectedReceiptEventId &&
        other.previewReceiptEventId == previewReceiptEventId &&
        other.entryContext == entryContext &&
        other.previewSurface == previewSurface &&
        other.partnerComparisonWindow == partnerComparisonWindow &&
        other.partnerScopeClientId == partnerScopeClientId &&
        other.partnerScopeSiteId == partnerScopeSiteId &&
        other.partnerScopePartnerLabel == partnerScopePartnerLabel &&
        other.brandingPrimaryLabelOverride == brandingPrimaryLabelOverride &&
        other.brandingEndorsementLineOverride ==
            brandingEndorsementLineOverride &&
        other.includeTimeline == includeTimeline &&
        other.includeDispatchSummary == includeDispatchSummary &&
        other.includeCheckpointCompliance == includeCheckpointCompliance &&
        other.includeAiDecisionLog == includeAiDecisionLog &&
        other.includeGuardMetrics == includeGuardMetrics;
  }

  @override
  int get hashCode => Object.hash(
    receiptFilter,
    outputMode,
    selectedReceiptEventId,
    previewReceiptEventId,
    entryContext,
    previewSurface,
    partnerComparisonWindow,
    partnerScopeClientId,
    partnerScopeSiteId,
    partnerScopePartnerLabel,
    brandingPrimaryLabelOverride,
    brandingEndorsementLineOverride,
    includeTimeline,
    includeDispatchSummary,
    includeCheckpointCompliance,
    includeAiDecisionLog,
    includeGuardMetrics,
  );
}
