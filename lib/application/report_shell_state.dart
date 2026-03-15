import 'report_partner_comparison_window.dart';
import 'report_output_mode.dart';
import 'report_preview_surface.dart';
import 'report_receipt_scene_filter.dart';

class ReportShellState {
  final ReportReceiptSceneFilter receiptFilter;
  final ReportOutputMode outputMode;
  final String? selectedReceiptEventId;
  final String? previewReceiptEventId;
  final ReportPreviewSurface previewSurface;
  final ReportPartnerComparisonWindow partnerComparisonWindow;

  const ReportShellState({
    this.receiptFilter = ReportReceiptSceneFilter.all,
    this.outputMode = ReportOutputMode.pdf,
    this.selectedReceiptEventId,
    this.previewReceiptEventId,
    this.previewSurface = ReportPreviewSurface.route,
    this.partnerComparisonWindow = ReportPartnerComparisonWindow.latestShift,
  });

  ReportShellState copyWith({
    ReportReceiptSceneFilter? receiptFilter,
    ReportOutputMode? outputMode,
    String? selectedReceiptEventId,
    bool clearSelectedReceiptEventId = false,
    String? previewReceiptEventId,
    bool clearPreviewReceiptEventId = false,
    ReportPreviewSurface? previewSurface,
    ReportPartnerComparisonWindow? partnerComparisonWindow,
  }) {
    final normalizedSelectedReceiptEventId = selectedReceiptEventId?.trim();
    final normalizedPreviewReceiptEventId = previewReceiptEventId?.trim();
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
      previewSurface: previewSurface ?? this.previewSurface,
      partnerComparisonWindow:
          partnerComparisonWindow ?? this.partnerComparisonWindow,
    );
  }
}
