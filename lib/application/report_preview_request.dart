import 'dart:typed_data';

import 'report_entry_context.dart';
import '../domain/crm/reporting/report_bundle.dart';
import '../domain/events/report_generated.dart';

class ReportPreviewRequest {
  final ReportBundle bundle;
  final Uint8List? initialPdfBytes;
  final ReportGenerated? receiptEvent;
  final bool? replayMatches;
  final ReportEntryContext? entryContext;

  const ReportPreviewRequest({
    required this.bundle,
    this.initialPdfBytes,
    this.receiptEvent,
    this.replayMatches,
    this.entryContext,
  });
}
