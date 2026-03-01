import 'incident_enums.dart';

class IncidentRecord {
  final String incidentId;
  final IncidentType type;
  final IncidentSeverity severity;
  final IncidentStatus status;

  final String detectedAt;
  final String classifiedAt;
  final String? resolvedAt;
  final String? closedAt;

  final String geoScopeRef;
  final String? linkedDispatchId;

  final String description;

  const IncidentRecord({
    required this.incidentId,
    required this.type,
    required this.severity,
    required this.status,
    required this.detectedAt,
    required this.classifiedAt,
    required this.geoScopeRef,
    required this.description,
    this.linkedDispatchId,
    this.resolvedAt,
    this.closedAt,
  });

  IncidentRecord transition({
    required IncidentStatus newStatus,
    String? linkedDispatchId,
    String? resolvedAt,
    String? closedAt,
  }) {
    return IncidentRecord(
      incidentId: incidentId,
      type: type,
      severity: severity,
      status: newStatus,
      detectedAt: detectedAt,
      classifiedAt: classifiedAt,
      geoScopeRef: geoScopeRef,
      description: description,
      linkedDispatchId: linkedDispatchId ?? this.linkedDispatchId,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      closedAt: closedAt ?? this.closedAt,
    );
  }
}
