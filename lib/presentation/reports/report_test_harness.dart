import 'package:flutter/material.dart';

import '../../domain/store/in_memory_event_store.dart';
import '../../domain/incidents/incident_event.dart';
import '../../domain/crm/crm_event.dart';
import '../../domain/crm/reporting/report_bundle.dart';
import '../../domain/crm/reporting/report_bundle_assembler.dart';
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
        .where((e) => e.aggregateId == widget.selectedClient)
        .toList();

    return ReportBundleAssembler.build(
      clientId: widget.selectedClient,
      currentMonth: currentMonth,
      previousMonth: previousMonth,
      incidentEvents: incidentEvents,
      crmEvents: crmEvents,
    );
  }

  void _generatePreview() {
    final now = DateTime.now().toUtc();
    final bundle = _buildBundle(now);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportPreviewPage(bundle: bundle),
      ),
    );
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
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _generatePreview,
              child: const Text("Preview Report"),
            ),
          ],
        ),
      ),
    );
  }
}
