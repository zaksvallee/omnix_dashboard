import 'dispatch_event.dart';

class ReportGenerated extends DispatchEvent {
  final String clientId;
  final String siteId;
  final String month;
  final String contentHash;
  final String pdfHash;
  final int eventRangeStart;
  final int eventRangeEnd;
  final int eventCount;
  final int reportSchemaVersion;
  final int projectionVersion;

  const ReportGenerated({
    required super.eventId,
    required super.sequence,
    required super.version,
    required super.occurredAt,
    required this.clientId,
    required this.siteId,
    required this.month,
    required this.contentHash,
    required this.pdfHash,
    required this.eventRangeStart,
    required this.eventRangeEnd,
    required this.eventCount,
    required this.reportSchemaVersion,
    required this.projectionVersion,
  });

  @override
  ReportGenerated copyWithSequence(int sequence) {
    return ReportGenerated(
      eventId: eventId,
      sequence: sequence,
      version: version,
      occurredAt: occurredAt,
      clientId: clientId,
      siteId: siteId,
      month: month,
      contentHash: contentHash,
      pdfHash: pdfHash,
      eventRangeStart: eventRangeStart,
      eventRangeEnd: eventRangeEnd,
      eventCount: eventCount,
      reportSchemaVersion: reportSchemaVersion,
      projectionVersion: projectionVersion,
    );
  }
}
