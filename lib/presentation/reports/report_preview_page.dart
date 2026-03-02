import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../domain/crm/reporting/report_bundle.dart';
import '../../domain/crm/export/pdf_report_exporter.dart';

class ReportPreviewPage extends StatefulWidget {
  final ReportBundle bundle;

  const ReportPreviewPage({
    super.key,
    required this.bundle,
  });

  @override
  State<ReportPreviewPage> createState() => _ReportPreviewPageState();
}

class _ReportPreviewPageState extends State<ReportPreviewPage> {
  Uint8List? _pdfBytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    final bytes = await PDFReportExporter.generate(widget.bundle);
    setState(() {
      _pdfBytes = bytes;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Operational Intelligence PDF"),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () async {
              await Printing.sharePdf(
                bytes: _pdfBytes!,
                filename: 'onyx_intelligence_report.pdf',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () async {
              await Printing.layoutPdf(
                onLayout: (format) async => _pdfBytes!,
              );
            },
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) async => _pdfBytes!,
      ),
    );
  }
}
