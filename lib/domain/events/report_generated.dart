import 'dispatch_event.dart';

class ReportGenerated extends DispatchEvent {
  final String clientId;
  final String month;
  final String contentHash;

  const ReportGenerated({
    required super.eventId,
    required super.sequence,
    required super.version,
    required super.occurredAt,
    required this.clientId,
    required this.month,
    required this.contentHash,
  });

  @override
  ReportGenerated copyWithSequence(int sequence) {
    return ReportGenerated(
      eventId: eventId,
      sequence: sequence,
      version: version,
      occurredAt: occurredAt,
      clientId: clientId,
      month: month,
      contentHash: contentHash,
    );
  }
}
