class ClientIncidentLog {
  final String incidentId;
  final String type;
  final String severity;
  final String status;

  final String detectedAt;
  final String? resolvedAt;

  final String geoScope;
  final List<String> actions;

  const ClientIncidentLog({
    required this.incidentId,
    required this.type,
    required this.severity,
    required this.status,
    required this.detectedAt,
    required this.geoScope,
    required this.actions,
    this.resolvedAt,
  });
}
