import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../domain/store/in_memory_event_store.dart';
import '../../domain/incidents/incident_event.dart';
import '../../domain/crm/crm_event.dart';
import '../../domain/crm/reporting/report_bundle.dart';
import '../../domain/crm/reporting/report_bundle_assembler.dart';
import '../../domain/crm/export/plain_text_report_exporter.dart';
import '../../domain/events/report_generated.dart';
import 'report_preview_page.dart';

class ReportTestHarnessPage extends StatefulWidget {
  final InMemoryEventStore store;
  final String selectedClient;
  final String selectedSite;

  const ReportTestHarnessPage({
    super.key,
    required this.store,
    required this.selectedClient,
    required this.selectedSite,
  });

  @override
  State<ReportTestHarnessPage> createState() =>
      _ReportTestHarnessPageState();
}

class _ReportTestHarnessPageState
    extends State<ReportTestHarnessPage> {

  bool _loading = false;
  String? _error;

  String _currentMonth(DateTime now) =>
      "${now.year}-${now.month.toString().padLeft(2, '0')}";

  String _previousMonth(DateTime now) {
    final previous = DateTime(now.year, now.month - 1);
    return "${previous.year}-${previous.month.toString().padLeft(2, '0')}";
  }

  ReportBundle _buildBundle(DateTime now) {
    final currentMonth = _currentMonth(now);
    final previousMonth = _previousMonth(now);

    final allEvents = widget.store.allEvents();

    final incidentEvents = allEvents
        .whereType<IncidentEvent>()
        .where((e) =>
            e.metadata['clientId'] == widget.selectedClient &&
            e.metadata['siteId'] == widget.selectedSite)
        .toList();

    final crmEvents = allEvents
        .whereType<CRMEvent>()
        .where((e) =>
            e.payload['clientId'] == widget.selectedClient)
        .toList();

    return ReportBundleAssembler.build(
      clientId: widget.selectedClient,
      currentMonth: currentMonth,
      previousMonth: previousMonth,
      incidentEvents: incidentEvents,
      crmEvents: crmEvents,
    );
  }

  String _hashContent(String content) {
    final bytes = utf8.encode(content);
    return base64Url.encode(bytes).substring(0, 16);
  }

  void _appendAuditEvent(
    DateTime now,
    String month,
    String hash,
  ) {
    widget.store.append(
      ReportGenerated(
        eventId:
            "REPORT-${widget.selectedClient}-${widget.selectedSite}-$month-$hash",
        sequence: 0,
        version: 1,
        occurredAt: now,
        clientId: widget.selectedClient,
        month: month,
        contentHash: hash,
      ),
    );
  }

  void _generatePreview() {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final now = DateTime.now().toUtc();
      final bundle = _buildBundle(now);
      final export = PlainTextReportExporter.export(bundle);

      if (export.content.isEmpty) {
        throw Exception("Report content is empty");
      }

      final hash = _hashContent(export.content);
      _appendAuditEvent(now, export.month, hash);

      setState(() {
        _loading = false;
      });

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReportPreviewPage(bundle: bundle),
        ),
      );
    } catch (_) {
      setState(() {
        _loading = false;
        _error = "Failed to generate report";
      });
    }
  }

  Future<void> _downloadReport() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final now = DateTime.now().toUtc();
      final bundle = _buildBundle(now);
      final export = PlainTextReportExporter.export(bundle);

      if (export.content.isEmpty) {
        throw Exception("Report content is empty");
      }

      final hash = _hashContent(export.content);

      final filename =
          "report_${export.clientId}_${widget.selectedSite}_${export.month}_$hash.txt";

      final file = File(filename);
      await file.writeAsString(export.content);

      _appendAuditEvent(now, export.month, hash);

      setState(() {
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = "Failed to download report";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Monthly Intelligence Report"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Client: ${widget.selectedClient} | Site: ${widget.selectedSite}",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _generatePreview,
                    child: const Text("Preview Report"),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton(
                    onPressed: _downloadReport,
                    child: const Text("Download Report"),
                  ),
                ],
              ),
            if (_error != null) ...[
              const SizedBox(height: 24),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
