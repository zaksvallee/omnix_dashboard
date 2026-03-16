import 'dispatch_event.dart';

class ListenerAlarmFeedCycleRecorded extends DispatchEvent {
  final String sourceLabel;
  final int acceptedCount;
  final int mappedCount;
  final int unmappedCount;
  final int duplicateCount;
  final int rejectedCount;
  final int normalizationSkippedCount;
  final int deliveredCount;
  final int failedCount;
  final int clearCount;
  final int suspiciousCount;
  final int unavailableCount;
  final int pendingCount;
  final String rejectSummary;

  const ListenerAlarmFeedCycleRecorded({
    required super.eventId,
    required super.sequence,
    required super.version,
    required super.occurredAt,
    required this.sourceLabel,
    required this.acceptedCount,
    required this.mappedCount,
    required this.unmappedCount,
    required this.duplicateCount,
    required this.rejectedCount,
    required this.normalizationSkippedCount,
    required this.deliveredCount,
    required this.failedCount,
    required this.clearCount,
    required this.suspiciousCount,
    required this.unavailableCount,
    required this.pendingCount,
    required this.rejectSummary,
  });

  @override
  ListenerAlarmFeedCycleRecorded copyWithSequence(int sequence) {
    return ListenerAlarmFeedCycleRecorded(
      eventId: eventId,
      sequence: sequence,
      version: version,
      occurredAt: occurredAt,
      sourceLabel: sourceLabel,
      acceptedCount: acceptedCount,
      mappedCount: mappedCount,
      unmappedCount: unmappedCount,
      duplicateCount: duplicateCount,
      rejectedCount: rejectedCount,
      normalizationSkippedCount: normalizationSkippedCount,
      deliveredCount: deliveredCount,
      failedCount: failedCount,
      clearCount: clearCount,
      suspiciousCount: suspiciousCount,
      unavailableCount: unavailableCount,
      pendingCount: pendingCount,
      rejectSummary: rejectSummary,
    );
  }
}
