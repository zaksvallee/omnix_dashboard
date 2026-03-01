import 'package:flutter/material.dart';
import '../domain/store/in_memory_event_store.dart';
import '../presentation/reports/report_test_harness.dart';
import '../presentation/incidents/manual_incident_page.dart';

class DashboardPage extends StatelessWidget {
  final String selectedClient;
  final String selectedRegion;
  final String selectedSite;
  final void Function(String) onClientChanged;
  final void Function(String) onRegionChanged;
  final void Function(String) onSiteChanged;
  final InMemoryEventStore eventStore;

  const DashboardPage({
    super.key,
    required this.selectedClient,
    required this.selectedRegion,
    required this.selectedSite,
    required this.onClientChanged,
    required this.onRegionChanged,
    required this.onSiteChanged,
    required this.eventStore,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ONYX Command Dashboard"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Operations Overview",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ReportTestHarnessPage(
                      store: eventStore,
                      selectedClient: selectedClient,
                      selectedSite: selectedSite,
                    ),
                  ),
                );
              },
              child: const Text("Generate Monthly Client Report"),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ManualIncidentPage(
                      store: eventStore,
                      selectedClient: selectedClient,
                      selectedSite: selectedSite,
                    ),
                  ),
                );
              },
              child: const Text("Create Manual Incident"),
            ),
          ],
        ),
      ),
    );
  }
}
