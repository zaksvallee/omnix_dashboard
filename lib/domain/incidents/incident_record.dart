import 'incident_enums.dart';

class IncidentRecord {
  static const String slaStatusBreached = 'breached';
  static const String slaStatusUnverifiableClockEvent =
      'unverifiable_clock_event';

  final String incidentId;
  final IncidentType type;
  final IncidentSeverity severity;
  final IncidentStatus status;
  final bool slaBreached;
  final String? slaEvaluationState;

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
    this.slaBreached = false,
    this.slaEvaluationState,
    required this.detectedAt,
    required this.classifiedAt,
    required this.geoScopeRef,
    required this.description,
    this.linkedDispatchId,
    this.resolvedAt,
    this.closedAt,
  });

  IncidentRecord transition({
    IncidentStatus? newStatus,
    bool? slaBreached,
    String? slaEvaluationState,
    String? linkedDispatchId,
    String? resolvedAt,
    String? closedAt,
  }) {
    return IncidentRecord(
      incidentId: incidentId,
      type: type,
      severity: severity,
      status: newStatus ?? status,
      slaBreached: slaBreached ?? this.slaBreached,
      slaEvaluationState: slaEvaluationState ?? this.slaEvaluationState,
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
