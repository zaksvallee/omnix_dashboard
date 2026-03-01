import 'package:flutter/material.dart';
import '../../domain/crm/reporting/report_bundle.dart';
import '../../domain/crm/export/plain_text_report_exporter.dart';

class ReportPreviewPage extends StatelessWidget {
  final ReportBundle bundle;

  const ReportPreviewPage({
    super.key,
    required this.bundle,
  });

  @override
  Widget build(BuildContext context) {
    final export = PlainTextReportExporter.export(bundle);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Monthly Intelligence Report"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: SelectableText(
            export.content,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
