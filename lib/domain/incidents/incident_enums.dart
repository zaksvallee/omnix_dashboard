enum IncidentType {
  intrusion,
  loitering,
  perimeterBreach,
  accessViolation,
  alarmTrigger,
  panicAlert,
  suspiciousActivity,
  guardMisconduct,
  equipmentFailure,
  systemAnomaly,
  civicRisk,
  other
}

enum IncidentSeverity {
  low,
  medium,
  high,
  critical
}

enum IncidentStatus {
  detected,
  classified,
  dispatchLinked,
  resolved,
  closed,
  escalated
}
