import 'package:flutter/material.dart';

import '../../application/report_preview_request.dart';
import '../../application/report_preview_surface.dart';
import '../../application/report_shell_state.dart';
import 'report_preview_presenter.dart';

class ReportPreviewController {
  const ReportPreviewController._();

  static ReportShellState syncPreviewSelection(
    ReportShellState shellState, {
    required String? receiptEventId,
  }) {
    final normalizedEventId = receiptEventId?.trim();
    if (normalizedEventId == null || normalizedEventId.isEmpty) {
      return shellState;
    }
    if (shellState.selectedReceiptEventId == normalizedEventId &&
        shellState.previewReceiptEventId == normalizedEventId) {
      return shellState;
    }
    return shellState.copyWith(
      selectedReceiptEventId: normalizedEventId,
      previewReceiptEventId: normalizedEventId,
    );
  }

  static bool usesDockSurface(ReportShellState shellState) {
    return shellState.previewSurface == ReportPreviewSurface.dock;
  }

  static Future<void> handleRequest({
    required BuildContext context,
    required ReportPreviewRequest request,
    required ReportShellState shellState,
    required ValueChanged<ReportShellState> onReportShellStateChanged,
  }) async {
    final nextShellState = syncPreviewSelection(
      shellState,
      receiptEventId: request.receiptEvent?.eventId,
    );
    if (nextShellState != shellState) {
      onReportShellStateChanged(nextShellState);
    }
    if (usesDockSurface(nextShellState)) {
      return;
    }
    await ReportPreviewPresenter.present(context, request);
  }
}
