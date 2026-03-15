import 'package:flutter/material.dart';

import '../../application/report_preview_request.dart';
import 'report_preview_page.dart';

class ReportPreviewPresenter {
  const ReportPreviewPresenter._();

  static Future<T?> present<T>(
    BuildContext context,
    ReportPreviewRequest request,
  ) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute(
        builder: (_) => ReportPreviewPage(
          bundle: request.bundle,
          initialPdfBytes: request.initialPdfBytes,
          receiptEvent: request.receiptEvent,
          replayMatches: request.replayMatches,
          entryContext: request.entryContext,
        ),
      ),
    );
  }
}
