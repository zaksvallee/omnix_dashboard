import 'dart:convert';

import 'dispatch_event.dart';

class DecisionCreated extends DispatchEvent {
  static const String auditTypeKey = 'decision_created';
  final String dispatchId;
  final String clientId;
  final String regionId;
  final String siteId;

  const DecisionCreated({
    required super.eventId,
    required super.sequence,
    required super.version,
    required super.occurredAt,
    required this.dispatchId,
    required this.clientId,
    required this.regionId,
    required this.siteId,
  });

  @override
  DecisionCreated copyWithSequence(int sequence) {
    return DecisionCreated(
      eventId: eventId,
      sequence: sequence,
      version: version,
      occurredAt: occurredAt,
      dispatchId: dispatchId,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
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
    };
  }

  @override
  String toString() => jsonEncode(toJson());
}
