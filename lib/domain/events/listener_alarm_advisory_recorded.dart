import 'dispatch_event.dart';

class ListenerAlarmAdvisoryRecorded extends DispatchEvent {
  final String clientId;
  final String regionId;
  final String siteId;
  final String externalAlarmId;
  final String accountNumber;
  final String partition;
  final String zone;
  final String zoneLabel;
  final String eventLabel;
  final String dispositionLabel;
  final String summary;
  final String recommendation;
  final int deliveredCount;
  final int failedCount;

  const ListenerAlarmAdvisoryRecorded({
    required super.eventId,
    required super.sequence,
    required super.version,
    required super.occurredAt,
    required this.clientId,
    required this.regionId,
    required this.siteId,
    required this.externalAlarmId,
    required this.accountNumber,
    required this.partition,
    required this.zone,
    required this.zoneLabel,
    required this.eventLabel,
    required this.dispositionLabel,
    required this.summary,
    required this.recommendation,
    required this.deliveredCount,
    required this.failedCount,
  });

  @override
  ListenerAlarmAdvisoryRecorded copyWithSequence(int sequence) {
    return ListenerAlarmAdvisoryRecorded(
      eventId: eventId,
      sequence: sequence,
      version: version,
      occurredAt: occurredAt,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      externalAlarmId: externalAlarmId,
      accountNumber: accountNumber,
      partition: partition,
      zone: zone,
      zoneLabel: zoneLabel,
      eventLabel: eventLabel,
      dispositionLabel: dispositionLabel,
      summary: summary,
      recommendation: recommendation,
      deliveredCount: deliveredCount,
      failedCount: failedCount,
    );
  }
}
