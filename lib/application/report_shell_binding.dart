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
  final ReportPreviewSurface previewSurface;
  final ReportPartnerComparisonWindow partnerComparisonWindow;
  final String? partnerScopeClientId;
  final String? partnerScopeSiteId;
  final String? partnerScopePartnerLabel;

  const ReportShellBinding({
    required this.receiptFilter,
    required this.outputMode,
    required this.selectedReceiptEventId,
    required this.previewReceiptEventId,
    required this.previewSurface,
    required this.partnerComparisonWindow,
    required this.partnerScopeClientId,
    required this.partnerScopeSiteId,
    required this.partnerScopePartnerLabel,
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
    );
  }

  ReportShellBinding copyWith({
    ReportReceiptSceneFilter? receiptFilter,
    ReportOutputMode? outputMode,
    String? selectedReceiptEventId,
    bool clearSelectedReceiptEventId = false,
    String? previewReceiptEventId,
    bool clearPreviewReceiptEventId = false,
    ReportPreviewSurface? previewSurface,
    ReportPartnerComparisonWindow? partnerComparisonWindow,
    String? partnerScopeClientId,
    String? partnerScopeSiteId,
    String? partnerScopePartnerLabel,
    bool clearPartnerScopeFocus = false,
  }) {
    final normalizedSelectedReceiptEventId = selectedReceiptEventId?.trim();
    final normalizedPreviewReceiptEventId = previewReceiptEventId?.trim();
    final normalizedPartnerScopeClientId = partnerScopeClientId?.trim();
    final normalizedPartnerScopeSiteId = partnerScopeSiteId?.trim();
    final normalizedPartnerScopePartnerLabel = partnerScopePartnerLabel?.trim();
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
    return copyWith(
      partnerScopeClientId: clientId,
      partnerScopeSiteId: siteId,
      partnerScopePartnerLabel: partnerLabel,
    );
  }

  ReportShellBinding clearingPartnerScopeFocus() {
    return copyWith(clearPartnerScopeFocus: true);
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
      previewSurface: previewSurface,
      partnerComparisonWindow: partnerComparisonWindow,
      partnerScopeClientId: partnerScopeClientId,
      partnerScopeSiteId: partnerScopeSiteId,
      partnerScopePartnerLabel: partnerScopePartnerLabel,
      clearPartnerScopeFocus:
          partnerScopeClientId == null ||
          partnerScopeSiteId == null ||
          partnerScopePartnerLabel == null,
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
        other.previewSurface == previewSurface &&
        other.partnerComparisonWindow == partnerComparisonWindow &&
        other.partnerScopeClientId == partnerScopeClientId &&
        other.partnerScopeSiteId == partnerScopeSiteId &&
        other.partnerScopePartnerLabel == partnerScopePartnerLabel;
  }

  @override
  int get hashCode => Object.hash(
    receiptFilter,
    outputMode,
    selectedReceiptEventId,
    previewReceiptEventId,
    previewSurface,
    partnerComparisonWindow,
    partnerScopeClientId,
    partnerScopeSiteId,
    partnerScopePartnerLabel,
  );
}
