import 'dispatch_event.dart';

class GuardCheckedIn extends DispatchEvent {
  final String guardId;
  final String clientId;
  final String regionId;
  final String siteId;

  const GuardCheckedIn({
    required super.eventId,
    required super.sequence,
    required super.version,
    required super.occurredAt,
    required this.guardId,
    required this.clientId,
    required this.regionId,
    required this.siteId,
  });

  @override
  GuardCheckedIn copyWithSequence(int sequence) {
    return GuardCheckedIn(
      eventId: eventId,
      sequence: sequence,
      version: version,
      occurredAt: occurredAt,
      guardId: guardId,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
    );
  }
}
