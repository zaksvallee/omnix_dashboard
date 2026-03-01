import 'package:flutter/material.dart';
import '../application/guard_performance_service.dart';
import '../domain/store/event_store.dart';

class DashboardPage extends StatelessWidget {
  final String selectedClient;
  final String selectedRegion;
  final String selectedSite;

  final ValueChanged<String> onClientChanged;
  final ValueChanged<String> onRegionChanged;
  final ValueChanged<String> onSiteChanged;

  final EventStore eventStore;

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
    final service = GuardPerformanceService(eventStore);

    final summary = service.siteSummary(
      clientId: selectedClient,
      regionId: selectedRegion,
      siteId: selectedSite,
    );

    final slaPercent = summary.slaCompliancePercent;
    final trendScore = summary.escalationTrendScore;

    Color slaBadgeColor;
    String slaBadgeLabel;

    if (slaPercent >= 95) {
      slaBadgeColor = Colors.green;
      slaBadgeLabel = "STABLE";
    } else if (slaPercent >= 85) {
      slaBadgeColor = Colors.orange;
      slaBadgeLabel = "WATCH";
    } else {
      slaBadgeColor = Colors.red;
      slaBadgeLabel = "ACTION REQUIRED";
    }

    Color trendColor;
    String trendLabel;

    if (trendScore < -0.1) {
      trendColor = Colors.green;
      trendLabel = "IMPROVING";
    } else if (trendScore > 0.1) {
      trendColor = Colors.red;
      trendLabel = "DEGRADING";
    } else {
      trendColor = Colors.orange;
      trendLabel = "STABLE";
    }

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Command Dashboard",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),

              DropdownButton<String>(
                value: selectedClient,
                onChanged: (value) {
                  if (value != null) onClientChanged(value);
                },
                items: const [
                  DropdownMenuItem(
                    value: 'CLIENT-001',
                    child: Text('CLIENT-001'),
                  ),
                  DropdownMenuItem(
                    value: 'CLIENT-002',
                    child: Text('CLIENT-002'),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              DropdownButton<String>(
                value: selectedRegion,
                onChanged: (value) {
                  if (value != null) onRegionChanged(value);
                },
                items: const [
                  DropdownMenuItem(
                    value: 'REGION-GAUTENG',
                    child: Text('REGION-GAUTENG'),
                  ),
                  DropdownMenuItem(
                    value: 'REGION-WESTERN-CAPE',
                    child: Text('REGION-WESTERN-CAPE'),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              DropdownButton<String>(
                value: selectedSite,
                onChanged: (value) {
                  if (value != null) onSiteChanged(value);
                },
                items: const [
                  DropdownMenuItem(
                    value: 'SITE-SANDTON',
                    child: Text('SITE-SANDTON'),
                  ),
                  DropdownMenuItem(
                    value: 'SITE-CAPE-TOWN',
                    child: Text('SITE-CAPE-TOWN'),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              const Text(
                "Operational Performance",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // SLA Status
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: slaBadgeColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "SLA STATUS: $slaBadgeLabel",
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Trend Indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: trendColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "ESCALATION TREND: $trendLabel",
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Text(
                        "SLA Compliance: "
                        "${slaPercent.toStringAsFixed(1)}%",
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Guard Compliance: "
                        "${summary.guardCompliancePercent.toStringAsFixed(1)}%",
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Average Response Time: "
                        "${summary.avgResponseMinutes.toStringAsFixed(2)} mins",
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Average Resolution Time: "
                        "${summary.avgResolutionMinutes.toStringAsFixed(2)} mins",
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Incidents: ${summary.incidentCount}",
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "SLA Breaches: ${summary.slaBreaches}",
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
