import '../../incidents/incident_event.dart';
import 'site_performance.dart';

class MultiSiteComparisonProjection {
  static List<SitePerformance> build({
    required String month,
    required List<IncidentEvent> incidentEvents,
  }) {
    final eventsInMonth = incidentEvents.where((e) {
      return e.timestamp.startsWith(month);
    }).toList();

    final Map<String, List<IncidentEvent>> grouped = {};

    for (final event in eventsInMonth) {
      final siteId = event.metadata['site_id'];
      if (siteId == null) continue;

      grouped.putIfAbsent(siteId, () => []);
      grouped[siteId]!.add(event);
    }

    final results = <SitePerformance>[];

    for (final entry in grouped.entries) {
      final siteId = entry.key;
      final events = entry.value;

      final totalIncidents = events
          .where((e) => e.type == IncidentEventType.incidentDetected)
          .length;

      final totalEscalations = events
          .where((e) =>
              e.type == IncidentEventType.incidentEscalated ||
              e.type == IncidentEventType.incidentSlaBreached)
          .length;

      final totalSlaBreaches = events
          .where((e) =>
              e.type == IncidentEventType.incidentSlaBreached)
          .length;

      final slaComplianceRate = totalIncidents == 0
          ? 1.0
          : 1.0 - (totalSlaBreaches / totalIncidents);

      results.add(
        SitePerformance(
          siteId: siteId,
          totalIncidents: totalIncidents,
          totalEscalations: totalEscalations,
          totalSlaBreaches: totalSlaBreaches,
          slaComplianceRate: slaComplianceRate,
        ),
      );
    }

    return results;
  }
}
