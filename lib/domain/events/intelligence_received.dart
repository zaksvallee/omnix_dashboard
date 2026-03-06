import 'dispatch_event.dart';

class IntelligenceReceived extends DispatchEvent {
  final String intelligenceId;
  final String provider;
  final String sourceType;
  final String externalId;
  final String clientId;
  final String regionId;
  final String siteId;
  final String headline;
  final String summary;
  final int riskScore;
  final String canonicalHash;

  const IntelligenceReceived({
    required super.eventId,
    required super.sequence,
    required super.version,
    required super.occurredAt,
    required this.intelligenceId,
    required this.provider,
    required this.sourceType,
    required this.externalId,
    required this.clientId,
    required this.regionId,
    required this.siteId,
    required this.headline,
    required this.summary,
    required this.riskScore,
    required this.canonicalHash,
  });

  @override
  IntelligenceReceived copyWithSequence(int sequence) {
    return IntelligenceReceived(
      eventId: eventId,
      sequence: sequence,
      version: version,
      occurredAt: occurredAt,
      intelligenceId: intelligenceId,
      provider: provider,
      sourceType: sourceType,
      externalId: externalId,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      headline: headline,
      summary: summary,
      riskScore: riskScore,
      canonicalHash: canonicalHash,
    );
  }
}
