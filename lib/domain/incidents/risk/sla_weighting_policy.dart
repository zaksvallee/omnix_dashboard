import '../../crm/sla_profile.dart';
import '../incident_enums.dart';

class SLAWeightingPolicy {
  static double weightFor(
    IncidentSeverity severity,
    SLAProfile profile,
  ) {
    switch (severity) {
      case IncidentSeverity.low:
        return profile.lowWeight;
      case IncidentSeverity.medium:
        return profile.mediumWeight;
      case IncidentSeverity.high:
        return profile.highWeight;
      case IncidentSeverity.critical:
        return profile.criticalWeight;
    }
  }
}
