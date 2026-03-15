import 'package:flutter/widgets.dart';

import '../../application/report_shell_binding.dart';
import '../../application/report_output_mode.dart';
import '../../application/report_partner_comparison_window.dart';
import '../../application/report_preview_request.dart';
import '../../application/report_preview_surface.dart';
import '../../application/report_receipt_scene_filter.dart';
import '../../application/report_shell_state.dart';
import 'report_preview_controller.dart';

mixin ReportShellBindingHost<T extends StatefulWidget> on State<T> {
  ReportShellBinding get reportShellBinding;
  set reportShellBinding(ReportShellBinding value);

  ReportShellState get reportShellBaseState;
  ValueChanged<ReportShellState>? get onReportShellStateChanged;
  ValueChanged<ReportPreviewRequest>? get onRequestPreview;

  ReportShellState projectReportShellState([ReportShellBinding? binding]) {
    return (binding ?? reportShellBinding).toShellState(reportShellBaseState);
  }

  void emitProjectedReportShellState([ReportShellBinding? binding]) {
    onReportShellStateChanged?.call(projectReportShellState(binding));
  }

  void mutateReportShellBinding(
    ReportShellBinding Function(ReportShellBinding current) mutate,
  ) {
    final previousBinding = reportShellBinding;
    final nextBinding = mutate(reportShellBinding);
    if (nextBinding == previousBinding) {
      return;
    }
    setState(() => reportShellBinding = nextBinding);
    emitProjectedReportShellState(nextBinding);
  }

  void syncPrunedReportShellBindingToReceiptIds({
    required Iterable<String> receiptEventIds,
    required VoidCallback mutateLocalState,
  }) {
    final previousBinding = reportShellBinding;
    final nextBinding = reportShellBinding.prunedToReceiptIds(receiptEventIds);
    setState(() {
      mutateLocalState();
      reportShellBinding = nextBinding;
    });
    if (nextBinding != previousBinding) {
      emitProjectedReportShellState(nextBinding);
    }
  }

  void setReportReceiptFilter(ReportReceiptSceneFilter value) {
    mutateReportShellBinding((binding) => binding.withReceiptFilter(value));
  }

  void toggleReportReceiptFilter(ReportReceiptSceneFilter value) {
    mutateReportShellBinding((binding) => binding.toggledReceiptFilter(value));
  }

  void setReportOutputMode(ReportOutputMode value) {
    mutateReportShellBinding((binding) => binding.withOutputMode(value));
  }

  void setReportPreviewSurface(ReportPreviewSurface value) {
    mutateReportShellBinding((binding) => binding.withPreviewSurface(value));
  }

  void setReportPartnerComparisonWindow(ReportPartnerComparisonWindow value) {
    mutateReportShellBinding(
      (binding) => binding.withPartnerComparisonWindow(value),
    );
  }

  void setReportPartnerScopeFocus({
    required String clientId,
    required String siteId,
    required String partnerLabel,
  }) {
    mutateReportShellBinding(
      (binding) => binding.withPartnerScopeFocus(
        clientId: clientId,
        siteId: siteId,
        partnerLabel: partnerLabel,
      ),
    );
  }

  void clearReportPartnerScopeFocus() {
    mutateReportShellBinding((binding) => binding.clearingPartnerScopeFocus());
  }

  void setReportSectionConfiguration({
    bool? includeTimeline,
    bool? includeDispatchSummary,
    bool? includeCheckpointCompliance,
    bool? includeAiDecisionLog,
    bool? includeGuardMetrics,
  }) {
    mutateReportShellBinding(
      (binding) => binding.withReportSectionConfiguration(
        includeTimeline: includeTimeline,
        includeDispatchSummary: includeDispatchSummary,
        includeCheckpointCompliance: includeCheckpointCompliance,
        includeAiDecisionLog: includeAiDecisionLog,
        includeGuardMetrics: includeGuardMetrics,
      ),
    );
  }

  void focusReportReceiptWorkspace(String? eventId) {
    mutateReportShellBinding(
      (binding) => binding.withReceiptWorkspaceFocus(eventId),
    );
  }

  void clearReportPreviewTarget() {
    mutateReportShellBinding((binding) => binding.clearingPreviewTarget());
  }

  void presentReportPreviewRequest(ReportPreviewRequest request) {
    final handler = onRequestPreview;
    if (handler != null) {
      handler(request);
      return;
    }
    ReportPreviewController.handleRequest(
      context: context,
      request: request,
      shellState: projectReportShellState(),
      onReportShellStateChanged: (state) {
        onReportShellStateChanged?.call(state);
      },
    );
  }
}
