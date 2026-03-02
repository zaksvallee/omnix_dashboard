import '../../crm/sla_profile.dart';
import '../incident_enums.dart';

class SLAPolicy {
  static int resolveSlaMinutes({
    required IncidentSeverity severity,
    required SLAProfile profile,
  }) {
    switch (severity) {
      case IncidentSeverity.low:
        return profile.lowMinutes;
      case IncidentSeverity.medium:
        return profile.mediumMinutes;
      case IncidentSeverity.high:
        return profile.highMinutes;
      case IncidentSeverity.critical:
        return profile.criticalMinutes;
    }
  }
}
