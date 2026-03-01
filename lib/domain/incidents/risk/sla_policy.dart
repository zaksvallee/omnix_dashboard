import '../incident_enums.dart';

class SLAPolicy {
  static int resolveSlaMinutes(IncidentSeverity severity) {
    switch (severity) {
      case IncidentSeverity.low:
        return 120;
      case IncidentSeverity.medium:
        return 60;
      case IncidentSeverity.high:
        return 30;
      case IncidentSeverity.critical:
        return 10;
    }
  }
}
