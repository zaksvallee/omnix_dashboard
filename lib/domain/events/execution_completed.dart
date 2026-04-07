import 'dart:convert';

import 'dispatch_event.dart';

class ExecutionCompleted extends DispatchEvent {
  static const String auditTypeKey = 'execution_completed';
  final String dispatchId;
  final String clientId;
  final String regionId;
  final String siteId;
  final bool success;

  const ExecutionCompleted({
    required super.eventId,
    required super.sequence,
    required super.version,
    required super.occurredAt,
    required this.dispatchId,
    required this.clientId,
    required this.regionId,
    required this.siteId,
    required this.success,
  });

  @override
  ExecutionCompleted copyWithSequence(int sequence) {
    return ExecutionCompleted(
      eventId: eventId,
      sequence: sequence,
      version: version,
      occurredAt: occurredAt,
      dispatchId: dispatchId,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      success: success,
    );
  }

  @override
  String toAuditTypeKey() => auditTypeKey;

  Map<String, Object?> toJson() {
    return {
      'type': auditTypeKey,
      'eventId': eventId,
      'sequence': sequence,
      'version': version,
      'occurredAtUtc': occurredAt.toUtc().toIso8601String(),
      'dispatchId': dispatchId,
      'clientId': clientId,
      'regionId': regionId,
      'siteId': siteId,
      'success': success,
    };
  }

  @override
  String toString() => jsonEncode(toJson());
}
