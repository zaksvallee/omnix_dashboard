import 'dispatch_event.dart';

class PatrolCompleted extends DispatchEvent {
  static const String auditTypeKey = 'patrol_completed';
  final String guardId;
  final String routeId;
  final String clientId;
  final String regionId;
  final String siteId;
  final int durationSeconds;

  const PatrolCompleted({
    required super.eventId,
    required super.sequence,
    required super.version,
    required super.occurredAt,
    required this.guardId,
    required this.routeId,
    required this.clientId,
    required this.regionId,
    required this.siteId,
    required this.durationSeconds,
  });

  @override
  PatrolCompleted copyWithSequence(int sequence) {
    return PatrolCompleted(
      eventId: eventId,
      sequence: sequence,
      version: version,
      occurredAt: occurredAt,
      guardId: guardId,
      routeId: routeId,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      durationSeconds: durationSeconds,
    );
  }

  @override
  String toAuditTypeKey() => auditTypeKey;
}
