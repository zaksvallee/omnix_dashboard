import 'dispatch_event.dart';

class ListenerAlarmParityCycleRecorded extends DispatchEvent {
  static const String auditTypeKey = 'listener_alarm_parity_cycle_recorded';
  final String sourceLabel;
  final String legacySourceLabel;
  final String statusLabel;
  final int serialCount;
  final int legacyCount;
  final int matchedCount;
  final int unmatchedSerialCount;
  final int unmatchedLegacyCount;
  final int maxAllowedSkewSeconds;
  final int maxSkewSecondsObserved;
  final double averageSkewSeconds;
  final String driftSummary;
  final Map<String, int> driftReasonCounts;

  const ListenerAlarmParityCycleRecorded({
    required super.eventId,
    required super.sequence,
    required super.version,
    required super.occurredAt,
    required this.sourceLabel,
    required this.legacySourceLabel,
    required this.statusLabel,
    required this.serialCount,
    required this.legacyCount,
    required this.matchedCount,
    required this.unmatchedSerialCount,
    required this.unmatchedLegacyCount,
    required this.maxAllowedSkewSeconds,
    required this.maxSkewSecondsObserved,
    required this.averageSkewSeconds,
    required this.driftSummary,
    this.driftReasonCounts = const <String, int>{},
  });

  @override
  ListenerAlarmParityCycleRecorded copyWithSequence(int sequence) {
    return ListenerAlarmParityCycleRecorded(
      eventId: eventId,
      sequence: sequence,
      version: version,
      occurredAt: occurredAt,
      sourceLabel: sourceLabel,
      legacySourceLabel: legacySourceLabel,
      statusLabel: statusLabel,
      serialCount: serialCount,
      legacyCount: legacyCount,
      matchedCount: matchedCount,
      unmatchedSerialCount: unmatchedSerialCount,
      unmatchedLegacyCount: unmatchedLegacyCount,
      maxAllowedSkewSeconds: maxAllowedSkewSeconds,
      maxSkewSecondsObserved: maxSkewSecondsObserved,
      averageSkewSeconds: averageSkewSeconds,
      driftSummary: driftSummary,
      driftReasonCounts: driftReasonCounts,
    );
  }

  @override
  String toAuditTypeKey() => auditTypeKey;
}
