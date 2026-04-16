import 'dispatch_event.dart';

class GuardStatusChangedEvent extends DispatchEvent {
  static const String auditTypeKey = 'guard_status_changed';

  final String guardId;
  final String assignmentId;
  final String dispatchId;
  final String status;
  final String clientId;
  final String regionId;
  final String siteId;
  final String sourceLabel;

  const GuardStatusChangedEvent({
    required super.eventId,
    required super.sequence,
    required super.version,
    required super.occurredAt,
    required this.guardId,
    required this.assignmentId,
    required this.dispatchId,
    required this.status,
    required this.clientId,
    required this.regionId,
    required this.siteId,
    required this.sourceLabel,
  });

  @override
  GuardStatusChangedEvent copyWithSequence(int sequence) {
    return GuardStatusChangedEvent(
      eventId: eventId,
      sequence: sequence,
      version: version,
      occurredAt: occurredAt,
      guardId: guardId,
      assignmentId: assignmentId,
      dispatchId: dispatchId,
      status: status,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      sourceLabel: sourceLabel,
    );
  }

  @override
  String toAuditTypeKey() => auditTypeKey;
}
