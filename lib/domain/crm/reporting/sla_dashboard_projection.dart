import '../../incidents/incident_event.dart';
import '../../incidents/incident_enums.dart';
import '../../incidents/risk/sla_weighting_policy.dart';
import '../../crm/sla_profile.dart';
import 'sla_dashboard_summary.dart';

class SLADashboardProjection {
  static SLADashboardSummary build({
    required String clientId,
    required SLAProfile profile,
    required List<IncidentEvent> events,
    required DateTime fromUtc,
    required DateTime toUtc,
  }) {
    final incidents = <String, IncidentSeverity>{};
    final breaches = <String>{};
    final overrides = <String>{};

    for (final e in events) {
      final ts = DateTime.parse(e.timestamp).toUtc();
      if (ts.isBefore(fromUtc) || ts.isAfter(toUtc)) continue;

      if (e.type == IncidentEventType.incidentDetected) {
        final severityName = e.metadata['severity'] as String?;
        if (severityName != null) {
          final severity = _parseSeverity(severityName);
          if (severity != null) {
            incidents[e.incidentId] = severity;
          }
        }
      }

      if (e.type == IncidentEventType.incidentSlaBreached) {
        breaches.add(e.incidentId);
      }

      if (e.type == IncidentEventType.incidentSlaOverrideRecorded) {
        overrides.add(e.incidentId);
      }
    }

    double totalWeight = 0;
    double breachWeight = 0;

    final incidentsBySeverity = <String, int>{};
    final breachesBySeverity = <String, int>{};

    for (final entry in incidents.entries) {
      final severity = entry.value;
      final severityName = severity.name;
      final weight = SLAWeightingPolicy.weightFor(severity, profile);

      totalWeight += weight;

      incidentsBySeverity[severityName] =
          (incidentsBySeverity[severityName] ?? 0) + 1;

      if (breaches.contains(entry.key) && !overrides.contains(entry.key)) {
        breachWeight += weight;

        breachesBySeverity[severityName] =
            (breachesBySeverity[severityName] ?? 0) + 1;
      }
    }

    final total = incidents.length;
    final breached = breachesBySeverity.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );

    final compliance = totalWeight == 0
        ? 100.0
        : ((totalWeight - breachWeight) / totalWeight) * 100.0;

    return SLADashboardSummary(
      clientId: clientId,
      fromUtc: fromUtc.toUtc().toIso8601String(),
      toUtc: toUtc.toUtc().toIso8601String(),
      totalIncidents: total,
      breachedIncidents: breached,
      compliancePercentage: double.parse(compliance.toStringAsFixed(2)),
      incidentsBySeverity: incidentsBySeverity,
      breachesBySeverity: breachesBySeverity,
    );
  }

  static IncidentSeverity? _parseSeverity(String raw) {
    final normalized = raw.trim();
    for (final severity in IncidentSeverity.values) {
      if (severity.name == normalized) {
        return severity;
      }
    }
    return null;
  }
}
