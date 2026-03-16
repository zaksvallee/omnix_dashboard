enum MonitoringWatchAutonomyPriority { critical, high, medium }

class MonitoringWatchAutonomyActionPlan {
  final String id;
  final String incidentId;
  final String siteId;
  final MonitoringWatchAutonomyPriority priority;
  final String actionType;
  final String description;
  final int countdownSeconds;
  final Map<String, String> metadata;

  const MonitoringWatchAutonomyActionPlan({
    required this.id,
    required this.incidentId,
    required this.siteId,
    required this.priority,
    required this.actionType,
    required this.description,
    required this.countdownSeconds,
    this.metadata = const <String, String>{},
  });
}
