import 'dispatch_event.dart';

enum PartnerDispatchStatus { accepted, onSite, allClear, cancelled }

class PartnerDispatchStatusDeclared extends DispatchEvent {
  final String dispatchId;
  final String clientId;
  final String regionId;
  final String siteId;
  final String partnerLabel;
  final String actorLabel;
  final PartnerDispatchStatus status;
  final String sourceChannel;
  final String sourceMessageKey;

  const PartnerDispatchStatusDeclared({
    required super.eventId,
    required super.sequence,
    required super.version,
    required super.occurredAt,
    required this.dispatchId,
    required this.clientId,
    required this.regionId,
    required this.siteId,
    required this.partnerLabel,
    required this.actorLabel,
    required this.status,
    required this.sourceChannel,
    required this.sourceMessageKey,
  });

  @override
  PartnerDispatchStatusDeclared copyWithSequence(int sequence) {
    return PartnerDispatchStatusDeclared(
      eventId: eventId,
      sequence: sequence,
      version: version,
      occurredAt: occurredAt,
      dispatchId: dispatchId,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      partnerLabel: partnerLabel,
      actorLabel: actorLabel,
      status: status,
      sourceChannel: sourceChannel,
      sourceMessageKey: sourceMessageKey,
    );
  }
}
